BEGIN;
ALTER TABLE public.battle_sessions ADD COLUMN teacher_paused boolean NOT NULL DEFAULT false,ADD COLUMN teacher_paused_at timestamptz,ADD COLUMN teacher_pause_reason text;
ALTER TABLE public.battle_question_rounds ADD COLUMN timer_started_at timestamptz,ADD COLUMN timer_paused_at timestamptz;
CREATE FUNCTION public.tcg_battle_control_guard(p_code text) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE b public.battle_sessions;
BEGIN
 SELECT * INTO b FROM public.battle_sessions WHERE upper(code)=upper(trim(p_code)) FOR UPDATE;
 IF b.teacher_paused THEN RETURN jsonb_build_object('ok',false,'code','BATTLE_PAUSED','message','Pertandingan dijeda guru. Tunggu sampai dilanjutkan.');END IF;
 RETURN jsonb_build_object('ok',true);
END $$;
REVOKE ALL ON FUNCTION public.tcg_battle_control_guard(text) FROM PUBLIC,anon,authenticated;
-- Lock the same session before every action/answer/timeout; old core behavior is retained.
DO $patch$ DECLARE f record;s text;guard text; BEGIN
 FOR f IN SELECT p.oid,p.proname FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace JOIN pg_language l ON l.oid=p.prolang
  WHERE n.nspname='public' AND l.lanname='plpgsql' AND p.prokind='f' AND (
   (p.prosrc~'tcg_battle_player_token' AND p.proname NOT LIKE 'get_%' AND p.proname<>'set_battle_player_avatar')
   OR p.proname IN ('process_multiplayer_rfid_scan','tcg_expire_battle_question','tcg_expire_battle_turn_if_due','start_battle_question')) LOOP
  s:=pg_get_functiondef(f.oid);
  guard:=CASE WHEN f.proname='process_multiplayer_rfid_scan' THEN '(SELECT s.code FROM public.battle_reader_bindings r JOIN public.battle_sessions s ON s.id=r.battle_id WHERE r.device_id=p_device_id AND r.active LIMIT 1)'
   WHEN f.proname IN ('tcg_expire_battle_question','tcg_expire_battle_turn_if_due','start_battle_question') THEN '(SELECT code FROM public.battle_sessions WHERE id=p_battle_id)' ELSE 'p_code' END;
  s:=regexp_replace(s,'(?i)(declare[[:space:]]+)',E'\\1 tbc_control jsonb;\n');
  s:=regexp_replace(s,'(?i)(begin[[:space:]]+)',E'\\1 tbc_control := public.tcg_battle_control_guard('||guard||E'); IF NOT coalesce((tbc_control->>''ok'')::boolean,false) THEN RETURN tbc_control; END IF;\n');
  EXECUTE s;
 END LOOP;
 -- Quiz grading/expiry now use a movable timer anchor; original created_at stays an audit timestamp.
 FOR f IN SELECT p.oid FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.prokind='f' AND p.prosrc LIKE '%v_round.created_at%' LOOP
  s:=pg_get_functiondef(f.oid);s:=replace(s,'v_round.created_at','coalesce(v_round.timer_started_at,v_round.created_at)');EXECUTE s;
 END LOOP;
 s:=pg_get_functiondef('public.tcg_set_battle_turn_clock()'::regprocedure);
 s:=regexp_replace(s,'(?i)(begin[[:space:]]+)',E'\\1 IF TG_OP=''UPDATE'' AND NEW.status<>''finished'' AND (NEW.teacher_paused OR OLD.teacher_paused) THEN RETURN NEW; END IF;\n');EXECUTE s;
END $patch$;
CREATE FUNCTION public.teacher_control_battle(p_code text,p_action text,p_reason text DEFAULT '',p_winner text DEFAULT 'draw') RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE b public.battle_sessions;elapsed interval;reason text:=left(trim(coalesce(p_reason,'')),300);r jsonb;
BEGIN
 IF auth.uid() IS NULL OR NOT public.is_admin() THEN RAISE EXCEPTION 'Login guru diperlukan.' USING ERRCODE='42501';END IF;
 SELECT * INTO b FROM public.battle_sessions WHERE upper(code)=upper(trim(p_code)) FOR UPDATE;
 IF b.id IS NULL THEN RAISE EXCEPTION 'Battle tidak ditemukan.';END IF;
 IF p_action NOT IN ('pause','resume','finish') OR p_action IS NULL THEN RAISE EXCEPTION 'Aksi guru tidak valid.';END IF;
 IF b.status='finished' OR b.winner IS NOT NULL THEN RETURN jsonb_build_object('ok',false,'message','Pertandingan sudah selesai.');END IF;
 IF p_action='pause' THEN
  IF b.teacher_paused THEN RETURN jsonb_build_object('ok',true,'already_applied',true,'battle',(public.get_public_battle_state(b.code)->'battle'));END IF;
  -- Expiry that predates the teacher click still follows the existing server rule.
  r:=public.tcg_expire_battle_turn_if_due(b.id);
  SELECT * INTO b FROM public.battle_sessions WHERE id=b.id;
  IF b.question_active AND b.current_question_round_id IS NOT NULL THEN PERFORM public.tcg_expire_battle_question(b.id,b.current_question_round_id);END IF;
  SELECT * INTO b FROM public.battle_sessions WHERE id=b.id;
  IF b.status='finished' OR b.winner IS NOT NULL THEN RETURN jsonb_build_object('ok',false,'message','Pertandingan sudah selesai.');END IF;
  UPDATE public.battle_sessions SET teacher_paused=true,teacher_paused_at=clock_timestamp(),teacher_pause_reason=nullif(reason,'') WHERE id=b.id RETURNING * INTO b;
  UPDATE public.battle_question_rounds SET timer_paused_at=b.teacher_paused_at WHERE id=b.current_question_round_id AND battle_id=b.id;
 ELSIF p_action='resume' THEN
  IF NOT b.teacher_paused THEN RETURN jsonb_build_object('ok',true,'already_applied',true,'battle',(public.get_public_battle_state(b.code)->'battle'));END IF;
  elapsed:=greatest(interval '0',clock_timestamp()-b.teacher_paused_at);
  UPDATE public.battle_question_rounds SET timer_started_at=coalesce(timer_started_at,created_at)+elapsed,timer_paused_at=NULL WHERE id=b.current_question_round_id AND battle_id=b.id;
  UPDATE public.battle_sessions SET teacher_paused=false,teacher_paused_at=NULL,teacher_pause_reason=NULL,turn_started_at=turn_started_at+elapsed,turn_deadline_at=turn_deadline_at+elapsed WHERE id=b.id;
 ELSE
  IF p_winner IS NULL OR p_winner NOT IN ('p1','p2','draw') OR reason='' THEN RAISE EXCEPTION 'Pilih hasil dan isi alasan mengakhiri pertandingan.';END IF;
  UPDATE public.battle_question_rounds SET status='cancelled',timer_paused_at=NULL WHERE id=b.current_question_round_id AND battle_id=b.id AND winner_player IS NULL;
  UPDATE public.battle_sessions SET status='finished',winner=p_winner,finished_at=clock_timestamp(),teacher_paused=false,teacher_paused_at=NULL,teacher_pause_reason=NULL,question_active=false,current_question_id=NULL,current_question_round_id=NULL,pending_action=NULL,pending_action_player=NULL,pending_summon_request_id=NULL,pending_summon_ap_cost=0,pending_summon_turn_index=NULL WHERE id=b.id;
 END IF;
 INSERT INTO public.battle_events(battle_id,type,payload) VALUES(b.id,'teacher_'||p_action,jsonb_build_object('teacher_id',auth.uid(),'reason',reason,'winner',CASE WHEN p_action='finish' THEN p_winner END,'message',CASE p_action WHEN 'pause' THEN 'Pertandingan dijeda guru' WHEN 'resume' THEN 'Pertandingan dilanjutkan guru' ELSE 'Pertandingan diakhiri guru' END));
 RETURN jsonb_build_object('ok',true,'battle',(public.get_public_battle_state(b.code)->'battle'));
END $$;
CREATE FUNCTION public.teacher_reset_battle_access(p_code text,p_player text) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE b public.battle_sessions;
BEGIN
 IF auth.uid() IS NULL OR NOT public.is_admin() THEN RAISE EXCEPTION 'Login guru diperlukan.' USING ERRCODE='42501';END IF;
 IF coalesce(p_player,'') NOT IN ('p1','p2') THEN RAISE EXCEPTION 'Pemain tidak valid.';END IF;
 SELECT * INTO b FROM public.battle_sessions WHERE upper(code)=upper(trim(p_code)) FOR UPDATE;IF b.id IS NULL THEN RAISE EXCEPTION 'Battle tidak ditemukan.';END IF;
 UPDATE tbc_private.battle_player_access SET token=encode(extensions.gen_random_bytes(24),'hex'),access_code=upper(encode(extensions.gen_random_bytes(6),'hex')),updated_at=clock_timestamp() WHERE battle_id=b.id AND player=p_player;
 INSERT INTO public.battle_events(battle_id,type,target_player,payload) VALUES(b.id,'teacher_reset_access',p_player,jsonb_build_object('teacher_id',auth.uid(),'message','Guru memperbarui akses pemain. Gunakan kode pribadi terbaru.'));
 RETURN public.admin_battle_access(b.code)||jsonb_build_object('ok',true,'player',p_player);
END $$;
REVOKE ALL ON FUNCTION public.teacher_control_battle(text,text,text,text),public.teacher_reset_battle_access(text,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.teacher_control_battle(text,text,text,text),public.teacher_reset_battle_access(text,text) TO authenticated;
NOTIFY pgrst,'reload schema';
COMMIT;
