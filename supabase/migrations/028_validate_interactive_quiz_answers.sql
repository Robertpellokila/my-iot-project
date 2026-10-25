-- Route every answer through authenticated, current-round validation.
-- Keep the existing reward/one-attempt transaction as an internal grader.
DO $$
BEGIN
  IF to_regprocedure('public.tcg_grade_battle_question_answer(text,text,text,uuid,integer)') IS NULL THEN
    ALTER FUNCTION public.submit_battle_question_answer(text,text,text,uuid,integer)
      RENAME TO tcg_grade_battle_question_answer;
  END IF;
END $$;
REVOKE ALL ON FUNCTION public.tcg_grade_battle_question_answer(text,text,text,uuid,integer) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.tcg_validate_quiz_submission(
  p_code text, p_player text, p_token text, p_question_round_id uuid,
  p_answer jsonb, p_interactive boolean
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $$
DECLARE
  v_battle public.battle_sessions%ROWTYPE;
  v_round public.battle_question_rounds%ROWTYPE;
  v_question public.coding_questions%ROWTYPE;
  v_player text := lower(trim(coalesce(p_player,'')));
  v_token text;
  v_type text;
  v_order jsonb;
  v_item jsonb;
  v_index integer;
  v_seen integer[] := ARRAY[]::integer[];
  v_answer_index integer;
  v_count integer;
  v_lines integer;
BEGIN
  IF v_player NOT IN ('p1','p2') THEN RETURN jsonb_build_object('ok',false,'message','Player tidak valid.'); END IF;
  SELECT * INTO v_battle FROM public.battle_sessions WHERE upper(code)=upper(trim(p_code)) FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'message','Battle tidak ditemukan.'); END IF;
  v_token := CASE WHEN v_player='p1' THEN v_battle.player1_token ELSE v_battle.player2_token END;
  IF v_token IS NULL OR p_token IS NULL OR v_token<>p_token THEN RETURN jsonb_build_object('ok',false,'message','Player token tidak valid.'); END IF;
  IF NOT coalesce(v_battle.question_active,false) OR v_battle.current_question_round_id IS DISTINCT FROM p_question_round_id THEN
    RETURN jsonb_build_object('ok',false,'message','Ronde quiz ini sudah tidak aktif.');
  END IF;
  SELECT * INTO v_round FROM public.battle_question_rounds WHERE id=p_question_round_id AND battle_id=v_battle.id FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'message','Ronde quiz tidak ditemukan.'); END IF;
  IF v_round.winner_player IS NOT NULL THEN RETURN jsonb_build_object('ok',true,'already_finished',true,'correct',false,'winner',v_round.winner_player); END IF;
  IF v_round.status<>'active' THEN RETURN jsonb_build_object('ok',false,'message','Ronde quiz sudah selesai.'); END IF;
  SELECT * INTO v_question FROM public.coding_questions WHERE id=v_round.question_id;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'message','Soal tidak ditemukan.'); END IF;
  v_type := lower(coalesce(v_question.question_type,'choice'));
  IF (v_type='choice' AND p_interactive) OR (v_type<>'choice' AND NOT p_interactive) THEN
    RETURN jsonb_build_object('ok',false,'message','Format jawaban tidak sesuai mode quiz.');
  END IF;
  IF jsonb_typeof(p_answer) IS DISTINCT FROM 'object' THEN RETURN jsonb_build_object('ok',false,'message','Jawaban tidak valid.'); END IF;
  IF v_type='block_order' THEN
    v_order := p_answer->'order';
    IF jsonb_typeof(v_order) IS DISTINCT FROM 'array' OR jsonb_typeof(v_question.blocks) IS DISTINCT FROM 'array' THEN
      RETURN jsonb_build_object('ok',false,'message','Kirim urutan blok yang lengkap.');
    END IF;
    v_count := jsonb_array_length(v_question.blocks);
    IF v_count<2 OR v_count>12 OR jsonb_array_length(v_order)<>v_count THEN RETURN jsonb_build_object('ok',false,'message','Jumlah blok tidak sesuai soal.'); END IF;
    FOR v_item IN SELECT value FROM jsonb_array_elements(v_order) LOOP
      IF jsonb_typeof(v_item)<>'number' OR v_item::text !~ '^(0|[1-9][0-9]*)$' OR length(v_item::text)>2 THEN
        RETURN jsonb_build_object('ok',false,'message','Identitas blok tidak valid.');
      END IF;
      v_index := (v_item::text)::integer;
      IF v_index<0 OR v_index>=v_count OR v_index=ANY(v_seen) THEN RETURN jsonb_build_object('ok',false,'message','Setiap blok harus digunakan tepat satu kali.'); END IF;
      v_seen := array_append(v_seen,v_index);
    END LOOP;
    v_answer_index := CASE WHEN v_order=v_question.correct_sequence THEN 0 ELSE 1 END;
  ELSIF v_type IN ('choice','find_bug') THEN
    v_item := p_answer->(CASE WHEN v_type='find_bug' THEN 'line_index' ELSE 'answer_index' END);
    IF jsonb_typeof(v_item) IS DISTINCT FROM 'number' OR v_item::text !~ '^[0-3]$' THEN RETURN jsonb_build_object('ok',false,'message','Pilih jawaban yang tersedia.'); END IF;
    v_answer_index := (v_item::text)::integer;
    IF v_type='find_bug' THEN
      SELECT count(*) INTO v_lines FROM regexp_split_to_table(replace(coalesce(v_question.code_snippet,''),E'\\n',E'\n'),E'\n') line WHERE trim(line)<>'';
      IF v_answer_index>=v_lines THEN RETURN jsonb_build_object('ok',false,'message','Baris kode tidak ditemukan.'); END IF;
    END IF;
  ELSE RETURN jsonb_build_object('ok',false,'message','Mode quiz tidak dikenal.');
  END IF;
  -- The internal grader locks the session, enforces the server deadline and
  -- one attempt per player, and issues exactly one winner/reward.
  RETURN public.tcg_grade_battle_question_answer(p_code,v_player,p_token,p_question_round_id,v_answer_index);
END $$;
REVOKE ALL ON FUNCTION public.tcg_validate_quiz_submission(text,text,text,uuid,jsonb,boolean) FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION public.submit_battle_question_answer(
 p_code text,p_player text,p_token text,p_question_round_id uuid,p_answer_index integer
) RETURNS jsonb LANGUAGE sql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $$
 SELECT public.tcg_validate_quiz_submission(p_code,p_player,p_token,p_question_round_id,jsonb_build_object('answer_index',p_answer_index),false);
$$;
CREATE OR REPLACE FUNCTION public.submit_battle_interactive_question_answer(
 p_code text,p_player text,p_token text,p_question_round_id uuid,p_interactive_answer jsonb
) RETURNS jsonb LANGUAGE sql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $$
 SELECT public.tcg_validate_quiz_submission(p_code,p_player,p_token,p_question_round_id,p_interactive_answer,true);
$$;
REVOKE ALL ON FUNCTION public.submit_battle_question_answer(text,text,text,uuid,integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.submit_battle_interactive_question_answer(text,text,text,uuid,jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.submit_battle_question_answer(text,text,text,uuid,integer) TO anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.submit_battle_interactive_question_answer(text,text,text,uuid,jsonb) TO anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION public.tcg_validate_question_content() RETURNS trigger
LANGUAGE plpgsql SET search_path TO 'public','pg_temp' AS $$
DECLARE v_count integer; v_order jsonb; v_unique integer; v_lines integer;
BEGIN
  IF nullif(trim(NEW.question),'') IS NULL THEN RAISE EXCEPTION 'Pertanyaan wajib diisi.'; END IF;
  IF NEW.question_type='block_order' THEN
    IF jsonb_typeof(NEW.blocks) IS DISTINCT FROM 'array' OR jsonb_typeof(NEW.correct_sequence) IS DISTINCT FROM 'array' THEN RAISE EXCEPTION 'Blok dan kunci urutan harus berupa array.'; END IF;
    v_count := jsonb_array_length(NEW.blocks);
    IF v_count<2 OR v_count>12 THEN RAISE EXCEPTION 'Gunakan 2–12 blok.'; END IF;
    IF EXISTS(SELECT 1 FROM jsonb_array_elements(NEW.blocks) item WHERE jsonb_typeof(item)<>'string' OR length(trim(item#>>'{}')) NOT BETWEEN 1 AND 180) THEN RAISE EXCEPTION 'Teks blok tidak valid.'; END IF;
    SELECT count(DISTINCT trim(value)) INTO v_unique FROM jsonb_array_elements_text(NEW.blocks);
    IF v_unique<>v_count THEN RAISE EXCEPTION 'Teks setiap blok harus berbeda.'; END IF;
    SELECT jsonb_agg(value ORDER BY value) INTO v_order FROM jsonb_array_elements(NEW.correct_sequence);
    IF v_order IS DISTINCT FROM (SELECT jsonb_agg(i) FROM generate_series(0,v_count-1) i) THEN RAISE EXCEPTION 'Kunci urutan harus memakai seluruh blok tepat satu kali.'; END IF;
    NEW.correct_answer := 'A';
  ELSIF NEW.question_type='find_bug' THEN
    SELECT count(*) INTO v_lines FROM regexp_split_to_table(coalesce(NEW.code_snippet,''),E'\n') line WHERE trim(line)<>'';
    IF v_lines NOT BETWEEN 2 AND 4 OR NEW.bug_line IS NULL OR NEW.bug_line<0 OR NEW.bug_line>=v_lines THEN RAISE EXCEPTION 'Pilih baris salah dari 2–4 baris kode.'; END IF;
    NEW.correct_answer := chr(65+NEW.bug_line);
  ELSIF coalesce(NEW.question_type,'choice')='choice' THEN
    IF nullif(trim(NEW.option_a),'') IS NULL OR nullif(trim(NEW.option_b),'') IS NULL OR nullif(trim(NEW.option_c),'') IS NULL OR nullif(trim(NEW.option_d),'') IS NULL OR coalesce(NEW.correct_answer,'') NOT IN ('A','B','C','D') THEN RAISE EXCEPTION 'Isi empat pilihan dan kunci jawaban A–D.'; END IF;
  ELSE RAISE EXCEPTION 'Mode quiz tidak tersedia.';
  END IF;
  RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS validate_question_content ON public.coding_questions;
CREATE TRIGGER validate_question_content BEFORE INSERT OR UPDATE OF question,question_type,blocks,correct_sequence,code_snippet,bug_line,option_a,option_b,option_c,option_d,correct_answer ON public.coding_questions FOR EACH ROW EXECUTE FUNCTION public.tcg_validate_question_content();
ALTER TABLE public.battle_sessions ALTER COLUMN question_time_limit_seconds SET DEFAULT 30;
NOTIFY pgrst,'reload schema';
