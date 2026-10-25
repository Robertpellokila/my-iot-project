import {readFile} from 'node:fs/promises';
import assert from 'node:assert/strict';
import {randomUUID} from 'node:crypto';
import {PGlite} from '@electric-sql/pglite';
const db=new PGlite();let passed=0;
const read=name=>readFile(new URL(`../../supabase/migrations/${name}`,import.meta.url),'utf8');
try {
 await db.exec('CREATE ROLE anon;CREATE ROLE authenticated;CREATE ROLE service_role;CREATE SCHEMA auth;');
 await db.exec(await readFile(new URL('./schema.sql',import.meta.url),'utf8'));
 await db.exec(`CREATE FUNCTION is_admin() RETURNS boolean LANGUAGE sql AS $$ SELECT coalesce(current_setting('test.admin',true),'false')='true' $$;
 CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql AS $$ SELECT CASE WHEN public.is_admin() THEN '01000000-0000-4000-8000-000000000001'::uuid ELSE NULL END $$;
 CREATE TABLE battle_bonus_skills(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),battle_id uuid REFERENCES battle_sessions(id),player text,skill_type text,used boolean DEFAULT false,source text,created_at timestamptz DEFAULT now());
 CREATE TABLE coding_questions(id uuid PRIMARY KEY,question text DEFAULT 'Quiz',correct_answer text,option_a text,option_b text,option_c text,option_d text,question_type text DEFAULT 'choice',blocks jsonb,correct_sequence jsonb,code_snippet text,bug_line integer);
 CREATE TABLE battle_question_rounds(id uuid PRIMARY KEY,battle_id uuid REFERENCES battle_sessions(id),question_id uuid REFERENCES coding_questions(id),status text,created_at timestamptz DEFAULT now(),winner_player text,winner_answer integer,won_at timestamptz);
 CREATE TABLE battle_question_answers(battle_question_id uuid,player text,answer_index integer,is_correct boolean,answered_at timestamptz,UNIQUE(battle_question_id,player));
 CREATE FUNCTION tcg_expire_battle_question(uuid,uuid) RETURNS jsonb LANGUAGE sql AS $$ SELECT '{"ok":true}'::jsonb $$;
 CREATE FUNCTION tcg_sync_battle_turn(text,text,text) RETURNS jsonb LANGUAGE sql AS $$ SELECT '{"ok":true}'::jsonb $$;
 CREATE FUNCTION submit_battle_action_core_3d15(p_code text,p_player text,p_token text,p_action text,p_card_id uuid,p_payload jsonb) RETURNS jsonb LANGUAGE plpgsql AS $$
 DECLARE v_battle battle_sessions;v_response jsonb;v_damage integer;v_actual_heal integer;v_synergy_points integer;
 BEGIN SELECT * INTO v_battle FROM battle_sessions WHERE code=p_code;
  if p_action='noop' then NULL;
  elsif p_action =
    'synergy'
  then RETURN '{"ok":false}';
  elsif p_action = 'summon' THEN RETURN '{}';END IF;
  RETURN v_catalog_result;
 END $$;`);
 await db.exec(await read('013_quiz_bonus_skill_choice.sql'));
 await db.exec(await read('028_validate_interactive_quiz_answers.sql'));
 await db.exec(await read('043_configurable_synergy_quiz_rewards.sql'));
 const check=async(name,fn)=>{await fn();passed++;console.log('PASS',name);};
 const catalog=async code=>(await db.query('SELECT to_jsonb(r) r FROM battle_effect_catalog r WHERE code=$1',[code])).rows[0].r;
 const setup=async(element='Forest',count=2)=>{
  const id=randomUUID(),code=`R-${id}`;
  await db.query(`INSERT INTO battle_sessions(id,code,status,current_turn,ruleset,round,turn_index,player1_token,player2_token,player1_hp,player2_hp,player1_max_hp,player2_max_hp,player1_skill,player2_skill,player1_action_points,player2_action_points,action_points_per_turn,action_points_enabled,player1_synergy_used,player2_synergy_used,player1_defending,player2_defending,player1_attack_debuff,player2_attack_debuff,player1_synergy_shield,player2_synergy_shield,question_active,turn_deadline_at)
   VALUES($1,$2,'battle','p1','tcg_v1',1,1,'a','b',50,200,200,200,0,0,3,0,3,true,'{}','{}',false,false,0,0,0,0,false,now()+interval '1 minute')`,[id,code]);
  const cards=[];for(let i=0;i<count;i++){const c=randomUUID();cards.push(c);await db.query("INSERT INTO battle_cards(id,battle_id,player,zone,element,attack,current_hp,base_hp,hp,exhausted) VALUES($1,$2,'p1','active',$3,40,100,100,100,false)",[c,id,element]);}
  return {id,code,cards};
 };
 const synergy=async fixture=>(await db.query("SELECT submit_battle_action_core_3d15($1,'p1','a','synergy',$2,'{}') r",[fixture.code,fixture.cards[0]])).rows[0].r;
 const state=async id=>(await db.query('SELECT * FROM battle_sessions WHERE id=$1',[id])).rows[0];
 const save=async rule=>(await db.query('SELECT save_battle_effect_rule($1) r',[rule])).rows[0].r;
 await check('all seven TCG types and legacy Ice execute every 2/3/4-card tier',async()=>{
  for(const element of ['Knight','Fire','Water','Forest','Thunder','Light','Dark','Ice']) for(const count of [2,3,4]){
   const f=await setup(element,count),r=await synergy(f),row=await state(f.id),rule=await catalog(`synergy_${element.toLowerCase()}`);
   assert.equal(r.ok,true,`${element} tier ${count}`);assert.equal(r.value,rule.effect_values[count]);assert.equal(r.synergy_points,count);
   if(rule.effect_type==='heal_percent')assert.equal(row.player1_hp,50+Math.round(200*r.value/100));
   if(rule.effect_type==='add_gauge')assert.equal(row.player1_skill,r.value);
   if(rule.effect_type==='shield_percent')assert.equal(Number(row.player1_synergy_shield),r.value/100);
   if(rule.effect_type==='attack_debuff_percent')assert.equal(Number(row.player2_attack_debuff),r.value/100);
   if(rule.effect_type.includes('burst'))assert.equal(row.player2_hp,200-Math.round(40*r.value/100));
   assert.equal((await synergy(f)).ok,false);
  }
 });
 await check('legacy aliases count together and previously-used aliases cannot bypass once-per-battle',async()=>{
  const f=await setup('Grass');await db.query("UPDATE battle_cards SET element='Forest' WHERE id=$1",[f.cards[1]]);assert.equal((await synergy(f)).ok,true);
  const g=await setup('Thunder');await db.query("UPDATE battle_cards SET element='Electric' WHERE id=$1",[g.cards[1]]);assert.equal((await synergy(g)).ok,true);
  const h=await setup('Forest');await db.query("UPDATE battle_sessions SET player1_synergy_used='{"+'"grass":true'+"}' WHERE id=$1",[h.id]);assert.equal((await synergy(h)).ok,false);
 });
 await check('Bench, exhausted, KO and foreign cards cannot satisfy Synergy',async()=>{
  for(const change of ["zone='bench'","exhausted=true","current_hp=0","player='p2'"]){const f=await setup();await db.query(`UPDATE battle_cards SET ${change} WHERE id=$1`,[f.cards[1]]);assert.equal((await synergy(f)).ok,false);}
 });
 await check('admin edits apply only to future matches; snapshots cannot be replaced by clients',async()=>{
  await assert.rejects(save({...await catalog('synergy_forest'),name:'Blocked'}),/Admin/);
  await db.exec("SELECT set_config('test.admin','true',false)");
  const old=await setup(),rule=await catalog('synergy_forest');await save({...rule,effect_values:{2:10,3:20,4:30},name:'Edited Forest'});
  assert.equal((await synergy(old)).heal,60);const fresh=await setup();assert.equal((await synergy(fresh)).heal,20);
  await db.query("UPDATE battle_sessions SET synergy_rules_snapshot='[]' WHERE id=$1",[fresh.id]);assert.equal((await state(fresh.id)).synergy_rules_snapshot.length,8);
  await assert.rejects(save({...rule,name:'Stale'}),/berubah/);
 });
 await check('unsupported effects, URL names and invalid values never activate',async()=>{
  for(const change of [{name:'https://invalid/image.png'},{effect_type:'execute_code'},{effect_values:{2:900,3:1,4:1}},{min_cards:1}])await assert.rejects(save({...await catalog('synergy_forest'),...change}));
 });
 let custom;
 await check('admin can add a custom bonus with an executable bounded effect',async()=>{
  custom=await save({code:'quick_patch',kind:'quiz_bonus',name:'Quick Patch',icon:'💚',description:'Heal custom',effect_type:'heal_flat',effect_values:{1:22},enabled:true});assert.equal(custom.code,'quick_patch');
 });
 async function quiz(count){
  const settings=(await db.query('SELECT to_jsonb(s) s FROM battle_reward_settings s')).rows[0].s;
  await db.query('SELECT save_battle_reward_settings($1,$2)',[count,settings.updated_at]);
  const f=await setup();const q=randomUUID(),round=randomUUID();
  await db.query("INSERT INTO coding_questions(id,correct_answer,option_a,option_b,option_c,option_d) VALUES($1,'A','True','False','Other','None')",[q]);
  await db.query("INSERT INTO battle_question_rounds(id,battle_id,question_id,status) VALUES($1,$2,$3,'active')",[round,f.id,q]);
  await db.query("UPDATE battle_sessions SET status='question',question_active=true,question_bonus_enabled=true,current_question_id=$2,current_question_round_id=$3 WHERE id=$1",[f.id,q,round]);
  return {...f,q,round,grade:async()=>(await db.query("SELECT tcg_grade_battle_question_answer($1,'p1','a',$2,0) r",[f.code,round])).rows[0].r};
 }
 await check('correct answers offer the configured 1–6 distinct bonuses from the match snapshot',async()=>{
  for(const count of [1,2,3,4,6]){const f=await quiz(count),result=await f.grade();assert.equal(result.correct,true);assert.equal(result.reward_choices.length,count);assert.equal(new Set(result.reward_choices).size,count);}
 });
 await check('winner chooses exactly one offered bonus and gets a frozen runtime rule',async()=>{
  const f=await quiz(6),answer=await f.grade();assert.ok(answer.reward_choices.includes('quick_patch'));
  const choose=async(code,player='p1',token='a')=>(await db.query('SELECT choose_battle_question_bonus($1,$2,$3,$4,$5) r',[f.code,player,token,f.round,code])).rows[0].r;
  assert.equal((await choose('quick_patch','p2','b')).ok,false);assert.equal((await choose('not_offered')).ok,false);assert.equal((await choose('quick_patch')).ok,true);
  assert.equal((await choose('quick_patch')).already_selected,true);assert.equal((await choose('recovery')).ok,false);
  const bonus=(await db.query('SELECT * FROM battle_bonus_skills WHERE battle_id=$1',[f.id])).rows[0];assert.equal(bonus.rule_snapshot.name,'Quick Patch');
  const before=await state(f.id),result=(await db.query("SELECT use_battle_bonus_skill($1,'p1','a',$2) r",[f.code,bonus.id])).rows[0].r;
  assert.equal(result.heal,22);assert.equal((await state(f.id)).player1_action_points,before.player1_action_points);assert.equal((await state(f.id)).player1_hp,before.player1_hp+22);
  assert.equal((await db.query("SELECT use_battle_bonus_skill($1,'p1','a',$2) r",[f.code,bonus.id])).rows[0].r.ok,false);
 });
 await check('all default rewards execute once without AP and reject wrong turn, pending action and invalid player',async()=>{
  const effects={power_strike:row=>row.player1_power_strike_ready,iron_guard:row=>row.player1_defending,recovery:row=>row.player1_hp===100,overcharge:row=>row.player1_skill===50,cleanse:row=>Number(row.player1_attack_debuff)===0};
  for(const [code,valid] of Object.entries(effects)){
   const f=await setup();await db.query('UPDATE battle_sessions SET player1_attack_debuff=.4 WHERE id=$1',[f.id]);
   const bonus=(await db.query("INSERT INTO battle_bonus_skills(battle_id,player,skill_type) VALUES($1,'p1',$2) RETURNING id",[f.id,code])).rows[0].id;
   const use=async(player='p1',token='a')=>(await db.query('SELECT use_battle_bonus_skill($1,$2,$3,$4) r',[f.code,player,token,bonus])).rows[0].r;
   assert.equal((await use(null,'b')).ok,false);assert.equal((await use('p1','bad')).ok,false);
   await db.query("UPDATE battle_sessions SET current_turn='p2' WHERE id=$1",[f.id]);assert.equal((await use()).ok,false);
   await db.query("UPDATE battle_sessions SET current_turn='p1',pending_action='summon' WHERE id=$1",[f.id]);assert.equal((await use()).ok,false);
   await db.query('UPDATE battle_sessions SET pending_action=NULL WHERE id=$1',[f.id]);assert.equal((await use()).ok,true);
   assert.ok(valid(await state(f.id)),code);assert.equal((await state(f.id)).player1_action_points,3);assert.equal((await use()).ok,false);
  }
 });
 await check('public reward projection is round-scoped and never exposes tokens or correct answers',async()=>{
  const f=await quiz(6);await f.grade();let projection=(await db.query('SELECT get_public_battle_bonus_choice($1) r',[f.code])).rows[0].r;
  assert.equal(projection.options.length,6);assert.equal(projection.player,'p1');assert.equal(projection.question_round_id,f.round);assert.deepEqual(Object.keys(projection).sort(),['ok','options','pending','player','question_round_id','selected_code'].sort());
  await db.query('UPDATE battle_sessions SET is_active=false WHERE id=$1',[f.id]);projection=(await db.query('SELECT get_public_battle_bonus_choice($1) r',[f.code])).rows[0].r;assert.equal(projection.pending,false);assert.equal(projection.options.length,0);
 });
 await check('smaller or empty bonus pools never fabricate choices or leave the quiz paused',async()=>{
  const saved=(await db.query("SELECT to_jsonb(r) r FROM battle_effect_catalog r WHERE kind='quiz_bonus'")).rows.map(row=>row.r);
  for(const rule of saved)await save({...rule,enabled:rule.code==='recovery'});
  let f=await quiz(6),r=await f.grade();assert.deepEqual(r.reward_choices,['recovery']);
  await save({...await catalog('recovery'),enabled:false});f=await quiz(6);r=await f.grade();assert.equal(r.correct,true);assert.deepEqual(r.reward_choices,[]);assert.equal((await state(f.id)).question_active,false);
 });
 await check('read APIs validate tokens and effect executors cannot be called by players',async()=>{
  const f=await setup();assert.equal((await db.query("SELECT get_battle_rule_catalog($1,'p1','bad') r",[f.code])).rows[0].r.ok,false);assert.equal((await db.query("SELECT get_battle_rule_catalog($1,NULL,'b') r",[f.code])).rows[0].r.ok,false);
  assert.equal((await db.query("SELECT has_function_privilege('anon','tcg_execute_catalog_synergy(uuid,text,uuid)','execute') ok")).rows[0].ok,false);
  assert.equal((await db.query("SELECT has_function_privilege('authenticated','save_battle_effect_rule(jsonb)','execute') ok")).rows[0].ok,true);
 });
 console.log(`${passed} rule catalog SQL checks passed`);
}catch(error){console.error(error.message,error.where??'',error.position??'');process.exitCode=1;}finally{await db.close();}
