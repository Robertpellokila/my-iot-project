BEGIN;
-- Only the authoritative action engine may write legacy visual status rows.
-- This helper takes public battle/card IDs and does not validate a player token.
REVOKE ALL ON FUNCTION public.tcg_sync_legacy_card_visual_status(uuid,text,text,uuid) FROM PUBLIC,anon,authenticated;
NOTIFY pgrst,'reload schema';
COMMIT;
