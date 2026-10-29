BEGIN;
CREATE TABLE public.battle_player_ui_state(battle_id uuid NOT NULL REFERENCES public.battle_sessions(id) ON DELETE CASCADE,player text NOT NULL CHECK(player IN ('p1','p2')),state jsonb NOT NULL DEFAULT '{}',updated_at timestamptz NOT NULL DEFAULT now(),PRIMARY KEY(battle_id,player));
ALTER TABLE public.battle_player_ui_state ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.battle_player_ui_state FROM PUBLIC,anon,authenticated;
GRANT SELECT ON public.battle_player_ui_state TO anon,authenticated;
CREATE POLICY battle_ui_read ON public.battle_player_ui_state FOR SELECT TO anon,authenticated USING(true);
CREATE FUNCTION public.publish_battle_player_ui(p_code text,p_player text,p_token text,p_state jsonb) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE b public.battle_sessions;clean jsonb;
BEGIN
 SELECT * INTO b FROM public.battle_sessions WHERE upper(code)=upper(trim(p_code)) FOR UPDATE;
 IF b.id IS NULL OR coalesce(p_player,'') NOT IN ('p1','p2') OR p_token IS NULL OR p_token IS DISTINCT FROM public.tcg_battle_player_token(b.id,p_player) THEN RETURN jsonb_build_object('ok',false,'code','PLAYER_ACCESS_REQUIRED','message','Akses pemain tidak valid.');END IF;
 IF jsonb_typeof(p_state) IS DISTINCT FROM 'object' OR octet_length(p_state::text)>32768 THEN RETURN jsonb_build_object('ok',false,'message','Status tampilan tidak valid.');END IF;
 SELECT coalesce(jsonb_object_agg(key,value),'{}') INTO clean FROM jsonb_each(p_state) WHERE key=ANY(ARRAY['focus','skillIntent','viewerZone','viewerIndex','viewerCardId','viewerTurn','draggingCardId','draggingCardName','dragFromZone','dragTarget','updatedAt']);
 INSERT INTO public.battle_player_ui_state(battle_id,player,state) VALUES(b.id,p_player,clean) ON CONFLICT(battle_id,player) DO UPDATE SET state=excluded.state,updated_at=clock_timestamp();
 RETURN jsonb_build_object('ok',true);
END $$;
REVOKE ALL ON FUNCTION public.publish_battle_player_ui(text,text,text,jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.publish_battle_player_ui(text,text,text,jsonb) TO anon,authenticated;
CREATE FUNCTION public.tcg_clear_rotated_ui() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN DELETE FROM public.battle_player_ui_state WHERE battle_id=NEW.battle_id AND player=NEW.player;RETURN NEW;END $$;
CREATE TRIGGER clear_rotated_battle_ui AFTER UPDATE ON tbc_private.battle_player_access FOR EACH ROW EXECUTE FUNCTION public.tcg_clear_rotated_ui();
REVOKE ALL ON FUNCTION public.tcg_clear_rotated_ui() FROM PUBLIC,anon,authenticated;
DO $$ BEGIN IF EXISTS(SELECT 1 FROM pg_publication WHERE pubname='supabase_realtime') AND NOT EXISTS(SELECT 1 FROM pg_publication_tables WHERE pubname='supabase_realtime' AND schemaname='public' AND tablename='battle_player_ui_state') THEN ALTER PUBLICATION supabase_realtime ADD TABLE public.battle_player_ui_state;END IF;END $$;
NOTIFY pgrst,'reload schema';
COMMIT;
