ALTER TABLE public.coding_questions ADD COLUMN IF NOT EXISTS block_config jsonb;
ALTER TABLE public.coding_questions ADD COLUMN IF NOT EXISTS duration_seconds integer CHECK(duration_seconds BETWEEN 10 AND 600);
-- Extend only the question-type check, leaving the existing data and other constraints intact.
DO $$ DECLARE c record; BEGIN
 FOR c IN SELECT conname FROM pg_constraint WHERE conrelid='public.coding_questions'::regclass AND contype='c' AND pg_get_constraintdef(oid) LIKE '%question_type%' LOOP
  EXECUTE format('ALTER TABLE public.coding_questions DROP CONSTRAINT %I',c.conname);
 END LOOP;
END $$;
ALTER TABLE public.coding_questions ADD CONSTRAINT coding_question_modes CHECK(question_type IN ('choice','block_order','find_bug','scratch_blocks'));
CREATE TABLE IF NOT EXISTS public.coding_question_block_keys (
 question_id uuid PRIMARY KEY REFERENCES public.coding_questions(id) ON DELETE CASCADE,
 solutions jsonb NOT NULL, grading jsonb NOT NULL, updated_at timestamptz NOT NULL DEFAULT now());
ALTER TABLE public.coding_question_block_keys ENABLE ROW LEVEL SECURITY;
CREATE POLICY block_keys_admin ON public.coding_question_block_keys FOR ALL TO authenticated USING(public.is_admin()) WITH CHECK(public.is_admin());
REVOKE ALL ON public.coding_question_block_keys FROM anon;
GRANT SELECT,INSERT,UPDATE,DELETE ON public.coding_question_block_keys TO authenticated;
CREATE TABLE IF NOT EXISTS public.battle_block_answers (
 round_id uuid NOT NULL REFERENCES public.battle_question_rounds(id) ON DELETE CASCADE,
 player text NOT NULL CHECK(player IN ('p1','p2')), workspace jsonb NOT NULL, score numeric NOT NULL,
 PRIMARY KEY(round_id,player));
ALTER TABLE public.battle_block_answers ENABLE ROW LEVEL SECURITY;
CREATE POLICY block_answers_admin ON public.battle_block_answers FOR SELECT TO authenticated USING(public.is_admin());
GRANT SELECT ON public.battle_block_answers TO authenticated;
REVOKE ALL ON public.battle_block_answers FROM anon;

CREATE OR REPLACE FUNCTION public.tcg_block_chain(b jsonb, allowed jsonb, depth integer DEFAULT 0) RETURNS jsonb
LANGUAGE plpgsql IMMUTABLE SET search_path=public,pg_temp AS $$
DECLARE result jsonb:='[]'; inputs jsonb; pair record; n integer:=0;
BEGIN
 IF depth>24 THEN RAISE EXCEPTION 'Workspace terlalu dalam'; END IF;
 WHILE b IS NOT NULL AND b<>'null'::jsonb LOOP
  n:=n+1;
  IF n>100 OR NOT (allowed ? (b->>'type')) OR b ? 'extraState' THEN RAISE EXCEPTION 'Blok tidak diizinkan'; END IF;
  IF jsonb_typeof(coalesce(b->'fields','{}'))<>'object' OR jsonb_typeof(coalesce(b->'inputs','{}'))<>'object' THEN RAISE EXCEPTION 'Input blok tidak valid'; END IF;
  FOR pair IN SELECT * FROM jsonb_each(coalesce(b->'fields','{}')) LOOP
   IF jsonb_typeof(pair.value) NOT IN ('string','number','boolean') OR length(pair.value::text)>502 THEN RAISE EXCEPTION 'Nilai input tidak valid'; END IF;
  END LOOP;
  inputs:='{}';
  FOR pair IN SELECT * FROM jsonb_each(coalesce(b->'inputs','{}')) LOOP
   inputs:=inputs||jsonb_build_object(pair.key,public.tcg_block_chain(coalesce(pair.value->'block',pair.value->'shadow'),allowed,depth+1));
  END LOOP;
  result:=result||jsonb_build_array(jsonb_build_object('type',b->>'type','fields',coalesce(b->'fields','{}'),'inputs',inputs));
  b:=b->'next'->'block';
 END LOOP;
 RETURN result;
END $$;

CREATE OR REPLACE FUNCTION public.tcg_normalize_workspace(w jsonb, config jsonb) RETURNS jsonb
LANGUAGE plpgsql IMMUTABLE SET search_path=public,pg_temp AS $$
DECLARE result jsonb:='[]'; b jsonb; allowed jsonb; known jsonb := '["tbc_move","tbc_turn","tbc_goto","tbc_glide","tbc_bounce","tbc_position","tbc_say","tbc_costume","tbc_backdrop","tbc_visible","tbc_play_sound","tbc_volume","tbc_stop_sound","tbc_flag","tbc_key","tbc_clicked","tbc_backdrop_event","tbc_loudness_event","tbc_receive","tbc_broadcast","tbc_wait","tbc_repeat","tbc_forever","tbc_if","tbc_if_else","tbc_until","tbc_wait_until","tbc_stop","tbc_touching","tbc_key_pressed","tbc_ask","tbc_answer","tbc_timer","tbc_number","tbc_text","tbc_math","tbc_compare","tbc_boolean","tbc_not","tbc_join","tbc_random","tbc_set","tbc_change","tbc_value","tbc_define","tbc_call"]';
BEGIN
 IF jsonb_typeof(w) IS DISTINCT FROM 'object' OR length(w::text)>120000 OR jsonb_typeof(coalesce(w->'blocks'->'blocks','[]'))<>'array' THEN RAISE EXCEPTION 'Workspace tidak valid'; END IF;
 SELECT coalesce(jsonb_agg(value),'[]') INTO allowed FROM jsonb_array_elements(coalesce(config->'allowed_types',known)) WHERE known ? (value#>>'{}');
 allowed:=allowed||'["tbc_number","tbc_text"]'::jsonb;
 FOR b IN SELECT value FROM jsonb_array_elements(coalesce(w->'blocks'->'blocks','[]')) LOOP
  result:=result||jsonb_build_array(public.tcg_block_chain(b,allowed));
 END LOOP;
 IF jsonb_array_length(jsonb_path_query_array(result,'strict $.**.type'))>100 THEN RAISE EXCEPTION 'Maksimal 100 blok'; END IF;
 RETURN result;
END $$;

CREATE OR REPLACE FUNCTION public.tcg_block_match(a jsonb,b jsonb,r jsonb,top_level boolean DEFAULT false) RETURNS numeric
LANGUAGE plpgsql IMMUTABLE SET search_path=public,pg_temp AS $$
DECLARE n integer; i integer; j integer; k text; total numeric:=0; best numeric; score numeric; best_index integer; used integer[]:='{}';
 extra boolean:=coalesce((r->>'allow_extra')::boolean,false); strict_order boolean:=coalesce((r->>'strict_order')::boolean,true);
 tolerance numeric:=coalesce((r->>'numeric_tolerance')::numeric,0);
BEGIN
 IF jsonb_typeof(b)='array' THEN
  IF jsonb_typeof(a) IS DISTINCT FROM 'array' THEN RETURN 0; END IF;
  n:=jsonb_array_length(b);
  IF (NOT extra AND jsonb_array_length(a)<>n) OR jsonb_array_length(a)<n THEN RETURN 0; END IF;
  IF n=0 THEN RETURN 1; END IF;
  FOR i IN 0..n-1 LOOP
   IF top_level OR NOT strict_order THEN
    best:=-1; best_index:=-1;
    FOR j IN 0..jsonb_array_length(a)-1 LOOP
     IF NOT j=ANY(used) THEN score:=public.tcg_block_match(a->j,b->i,r); IF score>best THEN best:=score;best_index:=j; END IF; END IF;
    END LOOP;
    used:=array_append(used,best_index); total:=total+greatest(0,best);
   ELSE total:=total+public.tcg_block_match(a->i,b->i,r); END IF;
  END LOOP;
  RETURN total/n;
 ELSIF jsonb_typeof(b)='object' THEN
  IF jsonb_typeof(a) IS DISTINCT FROM 'object' THEN RETURN 0; END IF;
  IF b ? 'type' AND a->'type' IS DISTINCT FROM b->'type' THEN RETURN 0; END IF;
  IF NOT extra AND EXISTS(SELECT 1 FROM jsonb_object_keys(a) key WHERE NOT b ? key) THEN RETURN 0; END IF;
  n:=0;
  FOR k IN SELECT jsonb_object_keys(b) LOOP
   IF k='fields' AND NOT coalesce((r->>'check_values')::boolean,true) THEN CONTINUE; END IF;
   total:=total+public.tcg_block_match(a->k,b->k,r);n:=n+1;
  END LOOP;
  RETURN CASE WHEN n=0 THEN 1 ELSE total/n END;
 END IF;
 IF a=b THEN RETURN 1; END IF;
 IF tolerance>0 AND (a#>>'{}') ~ '^-?[0-9]+(\.[0-9]+)?$' AND (b#>>'{}') ~ '^-?[0-9]+(\.[0-9]+)?$' THEN
  RETURN CASE WHEN abs((a#>>'{}')::numeric-(b#>>'{}')::numeric)<=tolerance THEN 1 ELSE 0 END;
 END IF;
 RETURN 0;
END $$;

CREATE OR REPLACE FUNCTION public.save_block_question(p_id uuid,p_question jsonb,p_solutions jsonb,p_grading jsonb) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE q public.coding_questions%rowtype; id uuid:=coalesce(p_id,gen_random_uuid()); solution jsonb; normalized jsonb;
BEGIN
 IF NOT public.is_admin() THEN RAISE EXCEPTION 'Admin diperlukan' USING ERRCODE='42501'; END IF;
 IF jsonb_typeof(p_solutions)<>'array' OR jsonb_array_length(p_solutions) NOT BETWEEN 1 AND 4 THEN RAISE EXCEPTION 'Isi 1–4 kunci'; END IF;
 IF jsonb_typeof(p_grading)<>'object' OR coalesce((p_grading->>'weight')::numeric,1) NOT BETWEEN 1 AND 100 OR coalesce((p_grading->>'numeric_tolerance')::numeric,0) NOT BETWEEN 0 AND 1000 THEN RAISE EXCEPTION 'Aturan penilaian tidak valid'; END IF;
 PERFORM public.tcg_normalize_workspace(p_question->'block_config'->'initial',p_question->'block_config');
 FOR solution IN SELECT value FROM jsonb_array_elements(p_solutions) LOOP
  normalized:=public.tcg_normalize_workspace(solution,p_question->'block_config');
  IF jsonb_array_length(normalized)=0 THEN RAISE EXCEPTION 'Kunci kosong'; END IF;
 END LOOP;
 q:=jsonb_populate_record(NULL::public.coding_questions,p_question);
 IF p_id IS NOT NULL AND NOT EXISTS(SELECT 1 FROM public.coding_questions WHERE coding_questions.id=p_id) THEN RAISE EXCEPTION 'Soal tidak ditemukan'; END IF;
 INSERT INTO public.coding_questions(id,question,question_type,image_url,block_config,duration_seconds,category,difficulty,is_active,explanation,hint_1,hint_2,learning_topic,learning_url,correct_answer,option_a,option_b,option_c,option_d)
 VALUES(id,q.question,'scratch_blocks',q.image_url,q.block_config,q.duration_seconds,q.category,q.difficulty,coalesce(q.is_active,true),q.explanation,q.hint_1,q.hint_2,q.learning_topic,q.learning_url,'A','Program benar','Program belum sesuai','','')
 ON CONFLICT ON CONSTRAINT coding_questions_pkey DO UPDATE SET question=excluded.question,question_type=excluded.question_type,image_url=excluded.image_url,block_config=excluded.block_config,duration_seconds=excluded.duration_seconds,category=excluded.category,difficulty=excluded.difficulty,is_active=excluded.is_active,explanation=excluded.explanation,hint_1=excluded.hint_1,hint_2=excluded.hint_2,learning_topic=excluded.learning_topic,learning_url=excluded.learning_url,correct_answer='A';
 INSERT INTO public.coding_question_block_keys(question_id,solutions,grading) VALUES(id,p_solutions,p_grading) ON CONFLICT(question_id) DO UPDATE SET solutions=excluded.solutions,grading=excluded.grading,updated_at=now();
 RETURN id;
END $$;
REVOKE ALL ON FUNCTION public.save_block_question(uuid,jsonb,jsonb,jsonb) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.save_block_question(uuid,jsonb,jsonb,jsonb) TO authenticated;

DO $patch$ DECLARE s text; BEGIN
 s:=pg_get_functiondef('public.tcg_validate_question_content()'::regprocedure);
 s:=replace(s,'IF NEW.question_type=''block_order'' THEN', 'IF NEW.question_type=''scratch_blocks'' THEN
   PERFORM public.tcg_normalize_workspace(NEW.block_config->''initial'',NEW.block_config);
   NEW.correct_answer:=''A'';
  ELSIF NEW.question_type=''block_order'' THEN');
 EXECUTE s;
 s:=pg_get_functiondef('public.tcg_validate_quiz_submission(text,text,text,uuid,jsonb,boolean)'::regprocedure);
 s:=replace(s,'v_lines integer;', 'v_lines integer; v_key public.coding_question_block_keys%rowtype; v_actual jsonb; v_solution jsonb; v_fraction numeric:=0; v_response jsonb;');
 s:=replace(s,'IF v_type=''block_order'' THEN','IF v_type=''scratch_blocks'' THEN
  SELECT * INTO v_key FROM public.coding_question_block_keys WHERE question_id=v_question.id;
  IF NOT FOUND THEN RETURN jsonb_build_object(''ok'',false,''message'',''Kunci soal belum tersedia.''); END IF;
  BEGIN
   v_actual:=public.tcg_normalize_workspace(p_answer->''workspace'',v_question.block_config);
   FOR v_solution IN SELECT value FROM jsonb_array_elements(v_key.solutions) LOOP
    v_fraction:=greatest(v_fraction,public.tcg_block_match(v_actual,public.tcg_normalize_workspace(v_solution,v_question.block_config),v_key.grading,true));
   END LOOP;
  EXCEPTION WHEN others THEN RETURN jsonb_build_object(''ok'',false,''message'',''Workspace jawaban tidak valid.''); END;
  v_answer_index:=CASE WHEN v_fraction=1 THEN 0 ELSE 1 END;
 ELSIF v_type=''block_order'' THEN');
 s:=replace(s,'RETURN public.tcg_grade_battle_question_answer(p_code,v_player,p_token,p_question_round_id,v_answer_index);','v_response:=public.tcg_grade_battle_question_answer(p_code,v_player,p_token,p_question_round_id,v_answer_index);
 IF v_type=''scratch_blocks'' AND coalesce((v_response->>''ok'')::boolean,false) AND NOT coalesce((v_response->>''already_finished'')::boolean,false) AND NOT coalesce((v_response->>''timed_out'')::boolean,false) THEN
  v_fraction:=CASE WHEN coalesce((v_key.grading->>''partial_credit'')::boolean,false) THEN v_fraction WHEN v_fraction=1 THEN 1 ELSE 0 END * coalesce((v_key.grading->>''weight'')::numeric,1);
  INSERT INTO public.battle_block_answers(round_id,player,workspace,score) VALUES(p_question_round_id,v_player,p_answer->''workspace'',v_fraction) ON CONFLICT DO NOTHING;
  v_response:=v_response||jsonb_build_object(''score'',round(v_fraction,2));
 END IF;
 RETURN v_response;');
 EXECUTE s;
 s:=pg_get_functiondef('public.tcg_expire_battle_question(uuid,uuid)'::regprocedure);
 s:=replace(s,'coalesce(v_battle.question_time_limit_seconds,0)','coalesce((SELECT duration_seconds FROM public.coding_questions WHERE id=v_round.question_id),v_battle.question_time_limit_seconds,0)');
 EXECUTE s;
END $patch$;
DROP TRIGGER IF EXISTS validate_question_content ON public.coding_questions;
CREATE TRIGGER validate_question_content BEFORE INSERT OR UPDATE ON public.coding_questions FOR EACH ROW EXECUTE FUNCTION public.tcg_validate_question_content();
REVOKE ALL ON FUNCTION public.tcg_block_chain(jsonb,jsonb,integer), public.tcg_normalize_workspace(jsonb,jsonb), public.tcg_block_match(jsonb,jsonb,jsonb,boolean) FROM PUBLIC,anon,authenticated;
ALTER FUNCTION public.tcg_validate_question_content() SECURITY DEFINER;
NOTIFY pgrst,'reload schema';
