BEGIN;
DO $smoke$
DECLARE b uuid:=gen_random_uuid();r jsonb;photo1 text:='https://example.invalid/qa44-p1.webp';photo2 text:='https://example.invalid/qa44-p2.webp';row battle_sessions;
BEGIN
 INSERT INTO battle_sessions(id,code,ruleset,status,player1_token,player2_token,player1_setup_photo_url,player2_avatar_url)
 VALUES(b,'QA44-'||b,'tcg_v1','waiting','qa44-one','qa44-two',photo1,photo2);
 SELECT * INTO row FROM battle_sessions WHERE id=b;
 IF row.player1_avatar_url IS DISTINCT FROM photo1 OR row.player2_setup_photo_url IS DISTINCT FROM photo2 THEN RAISE EXCEPTION 'Setup photo insert failed';END IF;
 r:=set_battle_player_avatar('QA44-'||b,'p1','qa44-one','🐱');
 IF NOT coalesce((r->>'ok')::boolean,false) OR r->>'avatar' IS DISTINCT FROM photo1 THEN RAISE EXCEPTION 'Photo was replaced by emoji';END IF;
 IF coalesce((set_battle_player_avatar('QA44-'||b,'p1','wrong','🐱')->>'ok')::boolean,false) THEN RAISE EXCEPTION 'Invalid token accepted';END IF;
 UPDATE battle_sessions SET player1_avatar_url='🐻' WHERE id=b;
 SELECT * INTO row FROM battle_sessions WHERE id=b;
 IF row.player1_avatar_url IS DISTINCT FROM photo1 OR row.player2_avatar_url IS DISTINCT FROM photo2 THEN RAISE EXCEPTION 'Photo overwrite/side isolation failed';END IF;
 UPDATE battle_sessions SET player1_setup_photo_url=NULL WHERE id=b;
 r:=set_battle_player_avatar('QA44-'||b,'p1','qa44-one','🐼');
 SELECT * INTO row FROM battle_sessions WHERE id=b;
 IF NOT coalesce((r->>'ok')::boolean,false) OR row.player1_avatar_url IS DISTINCT FROM '🐼' OR row.player2_avatar_url IS DISTINCT FROM photo2 THEN RAISE EXCEPTION 'No-photo fallback failed';END IF;
 BEGIN
  UPDATE battle_sessions SET player1_setup_photo_url='javascript:alert(1)' WHERE id=b;
  RAISE EXCEPTION 'unsafe photo accepted';
 EXCEPTION WHEN OTHERS THEN IF SQLERRM='unsafe photo accepted' THEN RAISE;END IF;END;
END $smoke$;
SELECT 'setup/legacy photo inheritance, token guard, emoji overwrite prevention, side isolation, removal/fallback and unsafe URL rejection passed' AS checks;
ROLLBACK;
