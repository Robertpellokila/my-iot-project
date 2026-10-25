BEGIN;

-- Bind every pending scan to an opaque request and its actual AP debit.
ALTER TABLE public.battle_sessions
  ADD COLUMN IF NOT EXISTS pending_summon_request_id uuid,
  ADD COLUMN IF NOT EXISTS pending_summon_ap_cost integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS pending_summon_turn_index bigint;

-- Existing pending requests can be cancelled too. Refund only a verified ledger
-- entry from the current turn; never infer the old debit from today's settings.
WITH pending AS (
 SELECT s.id, (
   SELECT e.payload FROM public.battle_events e
   WHERE e.battle_id=s.id AND e.source_player=s.pending_action_player
     AND e.type='action_request' AND e.payload->>'action'='summon'
     AND e.created_at>=coalesce(s.turn_started_at,s.started_at,s.created_at,'infinity'::timestamptz)
   ORDER BY e.created_at DESC,e.id DESC LIMIT 1
 ) AS request
 FROM public.battle_sessions s
 WHERE s.pending_action='summon' AND s.pending_action_player IN ('p1','p2')
   AND s.pending_summon_request_id IS NULL
)
UPDATE public.battle_sessions s
 SET pending_summon_request_id=gen_random_uuid(),
     pending_summon_ap_cost=CASE WHEN s.ruleset='tcg_v1' AND s.action_points_enabled
       AND pending.request->>'action_points_spent' ~ '^(0|[1-9]|10)$'
       THEN (pending.request->>'action_points_spent')::integer ELSE 0 END,
     pending_summon_turn_index=coalesce(s.turn_index,s.round,0)
 FROM pending WHERE s.id=pending.id;

CREATE OR REPLACE FUNCTION public.tcg_track_pending_summon()
RETURNS trigger LANGUAGE plpgsql SET search_path=public,pg_temp AS $$
DECLARE before_ap integer; after_ap integer;
BEGIN
 IF NEW.pending_action IS DISTINCT FROM 'summon' OR NEW.pending_action_player NOT IN ('p1','p2')
    OR NEW.pending_action_player IS NULL THEN
   NEW.pending_summon_request_id:=NULL;
   NEW.pending_summon_ap_cost:=0;
   NEW.pending_summon_turn_index:=NULL;
 ELSIF TG_OP='INSERT' THEN
   NEW.pending_summon_request_id:=gen_random_uuid();
   NEW.pending_summon_ap_cost:=0;
   NEW.pending_summon_turn_index:=coalesce(NEW.turn_index,NEW.round,0);
 ELSIF OLD.pending_action IS DISTINCT FROM 'summon'
       OR OLD.pending_action_player IS DISTINCT FROM NEW.pending_action_player THEN
   NEW.pending_summon_request_id:=gen_random_uuid();
   before_ap:=CASE WHEN NEW.pending_action_player='p1' THEN OLD.player1_action_points ELSE OLD.player2_action_points END;
   after_ap:=CASE WHEN NEW.pending_action_player='p1' THEN NEW.player1_action_points ELSE NEW.player2_action_points END;
   NEW.pending_summon_ap_cost:=CASE WHEN NEW.ruleset='tcg_v1' AND NEW.action_points_enabled
     THEN greatest(0,coalesce(before_ap,0)-coalesce(after_ap,0)) ELSE 0 END;
   NEW.pending_summon_turn_index:=coalesce(NEW.turn_index,NEW.round,0);
 ELSE
   -- Clients cannot edit a reservation's refund or identity in place.
   NEW.pending_summon_request_id:=OLD.pending_summon_request_id;
   NEW.pending_summon_ap_cost:=OLD.pending_summon_ap_cost;
   NEW.pending_summon_turn_index:=OLD.pending_summon_turn_index;
 END IF;
 RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION public.tcg_track_pending_summon() FROM PUBLIC,anon,authenticated;
DROP TRIGGER IF EXISTS tbc_track_pending_summon ON public.battle_sessions;
CREATE TRIGGER tbc_track_pending_summon BEFORE INSERT OR UPDATE ON public.battle_sessions
 FOR EACH ROW EXECUTE FUNCTION public.tcg_track_pending_summon();

CREATE OR REPLACE FUNCTION public.cancel_battle_summon(p_code text,p_player text,p_token text,p_request_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE b public.battle_sessions; guard jsonb; current_ap integer; restored_ap integer; refund integer;
BEGIN
 p_player:=lower(trim(coalesce(p_player,'')));
 -- The scanner also holds this row lock through placement (migration 024).
 -- Whichever operation commits first wins; cancellation never removes a card.
 SELECT * INTO b FROM public.battle_sessions WHERE upper(code)=upper(trim(p_code)) FOR UPDATE;
 IF b.id IS NULL OR p_player NOT IN ('p1','p2') OR p_token IS NULL
    OR p_token IS DISTINCT FROM (CASE WHEN p_player='p1' THEN b.player1_token ELSE b.player2_token END) THEN
   RETURN jsonb_build_object('ok',false,'code','INVALID_PLAYER','message','Battle atau token pemain tidak valid.');
 END IF;
 IF b.pending_action IS DISTINCT FROM 'summon' OR b.pending_action_player IS DISTINCT FROM p_player THEN
   RETURN jsonb_build_object('ok',false,'code','NO_PENDING_SUMMON','message','Tidak ada Summon yang menunggu. Kartu mungkin sudah terbaca.');
 END IF;
 IF p_request_id IS NULL OR p_request_id IS DISTINCT FROM b.pending_summon_request_id THEN
   RETURN jsonb_build_object('ok',false,'code','SUMMON_CHANGED','message','Permintaan Summon sudah berubah. Muat ulang kondisi battle.');
 END IF;
 guard:=public.tcg_sync_battle_turn(p_code,p_player,p_token);
 IF NOT coalesce((guard->>'ok')::boolean,false) THEN RETURN guard; END IF;
 SELECT * INTO b FROM public.battle_sessions WHERE id=b.id;
 IF b.status IS DISTINCT FROM 'battle' OR b.winner IS NOT NULL OR coalesce(b.question_active,false)
    OR b.current_turn IS DISTINCT FROM p_player
    OR b.pending_summon_turn_index IS DISTINCT FROM coalesce(b.turn_index,b.round,0)
    OR b.pending_summon_request_id IS DISTINCT FROM p_request_id
    OR b.pending_action IS DISTINCT FROM 'summon' OR b.pending_action_player IS DISTINCT FROM p_player
    OR (b.turn_deadline_at IS NOT NULL AND b.turn_deadline_at<=now()) THEN
   RETURN jsonb_build_object('ok',false,'code','TURN_CHANGED','message','Kondisi giliran sudah berubah; Summon ini tidak dapat dibatalkan.');
 END IF;
 current_ap:=coalesce(CASE WHEN p_player='p1' THEN b.player1_action_points ELSE b.player2_action_points END,0);
 refund:=CASE WHEN b.ruleset='tcg_v1' AND b.action_points_enabled THEN b.pending_summon_ap_cost ELSE 0 END;
 restored_ap:=least(greatest(1,coalesce(b.action_points_per_turn,3)),current_ap+refund);
 refund:=greatest(0,restored_ap-current_ap);
 UPDATE public.battle_sessions SET pending_action=NULL,pending_action_player=NULL,
   player1_action_points=CASE WHEN p_player='p1' AND b.action_points_enabled THEN restored_ap ELSE player1_action_points END,
   player2_action_points=CASE WHEN p_player='p2' AND b.action_points_enabled THEN restored_ap ELSE player2_action_points END
 WHERE id=b.id;
 INSERT INTO public.battle_events(battle_id,type,source_player,payload)
 VALUES(b.id,'action_request',p_player,jsonb_build_object('action','cancel_summon','request_id',p_request_id,
   'action_points_refunded',refund,'message','Summon dibatalkan sebelum kartu terbaca.'));
 RETURN jsonb_build_object('ok',true,'action','cancel_summon','action_points',restored_ap,
   'action_points_refunded',refund,'request_id',p_request_id,'message','Summon dibatalkan.');
END $$;
REVOKE ALL ON FUNCTION public.cancel_battle_summon(text,text,text,uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.cancel_battle_summon(text,text,text,uuid) TO anon,authenticated;

NOTIFY pgrst,'reload schema';
COMMIT;
