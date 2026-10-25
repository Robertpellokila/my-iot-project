-- Field Fusion materials remain consumed after moving to Graveyard. The old
-- trigger kept only necro_consumed there, allowing field materials to reappear
-- in Recall and graveyard-material matching despite a completed Fusion.
BEGIN;
CREATE OR REPLACE FUNCTION public.tcg_sync_fusion_consumption_state()
RETURNS trigger LANGUAGE plpgsql SET search_path=public,pg_temp AS $$
BEGIN
 IF TG_OP='UPDATE' AND coalesce(NEW.fusion_consumed,false) AND (
   NOT (coalesce(OLD.fusion_consumed,false) OR coalesce(OLD.field_fusion_used,false) OR coalesce(OLD.necro_consumed,false) OR OLD.consumed_by_fusion_id IS NOT NULL)
   OR NEW.consumed_by_fusion_id IS DISTINCT FROM OLD.consumed_by_fusion_id
 ) THEN
   IF lower(coalesce(OLD.zone,''))='graveyard' THEN NEW.necro_consumed:=true;
   ELSE NEW.field_fusion_used:=true; END IF;
 END IF;
 NEW.fusion_consumed:=coalesce(NEW.field_fusion_used,false) OR coalesce(NEW.necro_consumed,false) OR NEW.consumed_by_fusion_id IS NOT NULL;
 IF NEW.fusion_consumed AND NEW.zone='graveyard' THEN
   NEW.graveyard_reason:='fusion_consumed';
   NEW.graveyard_at:=coalesce(NEW.graveyard_at,now());
 END IF;
 RETURN NEW;
END $$;
COMMIT;
