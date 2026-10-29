-- Paginated owner history and explicit, bounded deletion of inactive matches.
-- Installing this migration does not delete any history.
BEGIN;
CREATE INDEX IF NOT EXISTS battle_sessions_owner_history_idx
 ON public.battle_sessions(created_by,created_at DESC,id DESC);

CREATE OR REPLACE FUNCTION tbc_private.battle_history_deletable(b public.battle_sessions)
RETURNS boolean LANGUAGE sql STABLE SET search_path=public,pg_temp AS $$
 SELECT coalesce(b.status='finished',false) OR nullif(b.winner,'') IS NOT NULL
   OR b.is_active IS FALSE OR coalesce(b.active_until<=now(),false)
$$;
REVOKE ALL ON FUNCTION tbc_private.battle_history_deletable(public.battle_sessions) FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION public.admin_battle_history(
 p_search text DEFAULT '',p_status text DEFAULT 'all',p_access text DEFAULT 'all',
 p_page integer DEFAULT 1,p_page_size integer DEFAULT 10)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE result jsonb;
BEGIN
 IF auth.uid() IS NULL OR NOT public.is_admin() THEN RAISE EXCEPTION 'Login admin diperlukan.' USING ERRCODE='42501'; END IF;
 IF p_page IS NULL OR p_page<1 OR p_page_size IS NULL OR p_page_size NOT IN (10,25,50)
   OR p_status IS NULL OR p_status NOT IN ('all','waiting','ready','battle','question','finished')
   OR p_access IS NULL OR p_access NOT IN ('all','active','inactive')
   OR length(coalesce(p_search,''))>120 THEN RAISE EXCEPTION 'Filter riwayat tidak valid.'; END IF;
 WITH owned AS MATERIALIZED (
   SELECT b.id,b.code,b.created_at,b.status,b.player1_name,b.player2_name,b.winner,
     b.round,b.total_rounds,b.is_active,b.active_until,b.starting_player,
     b.question_enabled,b.question_level,b.question_every_rounds,b.turn_duration_seconds,
     b.teacher_paused,tbc_private.battle_history_deletable(b) AS can_delete
   FROM public.battle_sessions b WHERE b.created_by=auth.uid()
 ), filtered AS MATERIALIZED (
   SELECT * FROM owned b WHERE (p_status='all' OR b.status=p_status)
     AND (p_access='all' OR (p_access='active' AND NOT b.can_delete) OR (p_access='inactive' AND b.can_delete))
     AND (nullif(trim(p_search),'') IS NULL OR strpos(lower(concat_ws(' ',b.code,b.player1_name,b.player2_name,b.status,b.question_level)),lower(trim(p_search)))>0)
 ), totals AS (SELECT count(*) AS total FROM filtered), paging AS (
   SELECT total,least(p_page,greatest(1,ceil(total::numeric/p_page_size)::integer)) AS page FROM totals
 ), page_rows AS (
   SELECT b.* FROM filtered b ORDER BY created_at DESC,id DESC
   LIMIT p_page_size OFFSET (SELECT (page-1)*p_page_size FROM paging)
 ) SELECT jsonb_build_object(
   'rows',coalesce((SELECT jsonb_agg(to_jsonb(r) ORDER BY r.created_at DESC,r.id DESC) FROM page_rows r),'[]'::jsonb),
   'total',p.total,'page',p.page,'page_size',p_page_size,
   'summary',(SELECT jsonb_build_object('total',count(*),'active',count(*) FILTER(WHERE NOT can_delete),
     'finished',count(*) FILTER(WHERE status='finished'),'deletable',count(*) FILTER(WHERE can_delete)) FROM owned)
 ) INTO result FROM paging p;
 RETURN result;
END $$;

CREATE OR REPLACE FUNCTION public.admin_battle_history_cleanup(p_before timestamptz DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE result jsonb;
BEGIN
 IF auth.uid() IS NULL OR NOT public.is_admin() THEN RAISE EXCEPTION 'Login admin diperlukan.' USING ERRCODE='42501'; END IF;
 WITH eligible AS MATERIALIZED (
   SELECT b.id,b.code,b.created_at,b.player1_name,b.player2_name FROM public.battle_sessions b
   WHERE b.created_by=auth.uid() AND tbc_private.battle_history_deletable(b)
     AND (p_before IS NULL OR b.created_at<p_before)
 ), batch AS (SELECT * FROM eligible ORDER BY created_at,id LIMIT 100)
 SELECT jsonb_build_object('total',(SELECT count(*) FROM eligible),
   'rows',coalesce((SELECT jsonb_agg(to_jsonb(b) ORDER BY b.created_at,b.id) FROM batch b),'[]'::jsonb)) INTO result;
 RETURN result;
END $$;

CREATE OR REPLACE FUNCTION public.admin_delete_battle_history(p_ids uuid[])
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE ids uuid[]; b public.battle_sessions; found_count integer:=0; deleted_count integer;
BEGIN
 IF auth.uid() IS NULL OR NOT public.is_admin() THEN RAISE EXCEPTION 'Login admin diperlukan.' USING ERRCODE='42501'; END IF;
 IF coalesce(cardinality(p_ids),0) NOT BETWEEN 1 AND 100 OR array_position(p_ids,NULL) IS NOT NULL
   THEN RAISE EXCEPTION 'Pilih 1–100 pertandingan untuk dihapus.'; END IF;
 SELECT array_agg(DISTINCT id) INTO ids FROM unnest(p_ids) id;
 -- Row locks serialize with activation and gameplay. Revalidate after waiting
 -- for a concurrent update; stale confirmations never delete an active match.
 FOR b IN SELECT * FROM public.battle_sessions WHERE id=ANY(ids) AND created_by=auth.uid() ORDER BY id FOR UPDATE LOOP
   found_count:=found_count+1;
   IF NOT tbc_private.battle_history_deletable(b) THEN
     RAISE EXCEPTION 'Battle % masih aktif. Akhiri atau nonaktifkan dahulu, lalu periksa ulang pilihan.',b.code USING ERRCODE='55000';
   END IF;
 END LOOP;
 IF found_count<>cardinality(ids) THEN RAISE EXCEPTION 'Pilihan riwayat sudah berubah atau bukan milikmu. Muat ulang dan pilih kembali.' USING ERRCODE='42501'; END IF;
 -- Scan logs without a registration-session link belong exclusively to this
 -- battle. Shared registration scans and skill playtest notes retain their own
 -- history; their battle_id is cleared by the existing SET NULL foreign keys.
 DELETE FROM public.scan_events WHERE battle_id=ANY(ids) AND session_id IS NULL;
 DELETE FROM public.battle_sessions WHERE id=ANY(ids) AND created_by=auth.uid();
 GET DIAGNOSTICS deleted_count=ROW_COUNT;
 -- Existing FKs cascade battle cards, events, skills, quizzes, fusion records,
 -- status effects, reader bindings, UI state, receipts and private access.
 RETURN jsonb_build_object('deleted',deleted_count);
END $$;
REVOKE ALL ON FUNCTION public.admin_battle_history(text,text,text,integer,integer) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.admin_battle_history_cleanup(timestamptz) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.admin_delete_battle_history(uuid[]) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.admin_battle_history(text,text,text,integer,integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_battle_history_cleanup(timestamptz) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_delete_battle_history(uuid[]) TO authenticated;
NOTIFY pgrst,'reload schema';
COMMIT;
