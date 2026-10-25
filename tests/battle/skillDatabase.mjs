import {readFile} from 'node:fs/promises';
import assert from 'node:assert/strict';
const {PGlite}=await import(process.env.PGLITE_MODULE || '@electric-sql/pglite');
const db=new PGlite();let passed=0;
try {
 await db.exec('CREATE ROLE anon; CREATE ROLE authenticated; CREATE ROLE service_role;');
 await db.exec(await readFile(new URL('./schema.sql',import.meta.url),'utf8'));
 await db.exec(`CREATE FUNCTION tcg_snapshot_battle_card_special_skills() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN PERFORM 'ss.priority'; RETURN NEW; END $$;
 CREATE FUNCTION tcg_try_uuid(text) RETURNS uuid LANGUAGE plpgsql AS $$ BEGIN RETURN $1::uuid; EXCEPTION WHEN others THEN RETURN NULL; END $$;
 CREATE FUNCTION tcg_apply_effects(uuid,text,uuid,jsonb,jsonb) RETURNS jsonb LANGUAGE plpgsql AS $$ BEGIN RETURN '{"ok":true,"results":[]}'; END $$;`);
 const migration=await readFile(new URL('../../supabase/migrations/029_dual_skill_authority.sql',import.meta.url),'utf8');
 await db.exec(migration);
 const b='10000000-0000-0000-0000-000000000001',c='20000000-0000-0000-0000-000000000001',s1='30000000-0000-0000-0000-000000000001',s2='30000000-0000-0000-0000-000000000002';
 await db.query(`INSERT INTO battle_sessions(id,code,ruleset,status,current_turn,round,special_card_skills_enabled,player1_token,player2_token) VALUES($1,'UNIT','tcg_v1','battle','p1',1,true,'a','b')`,[b]);
 await db.query(`INSERT INTO battle_cards(id,battle_id,player,zone,current_hp,base_hp) VALUES($1,$2,'p1','active',100,100)`,[c,b]);
 for(const id of [s1,s2]) await db.query(`INSERT INTO battle_card_skills(id,battle_id,battle_card_id,player,name,skill_code,activation_timing,limits,target_spec,cost_spec,effects,source_zones,disabled) VALUES($1::uuid,$2,$3,'p1','Test',$1::uuid::text,'main_phase','{"cooldown_turns":2}','{"type":"self_card"}','{"type":"none"}','[{"type":"heal_card"}]',ARRAY['active'],false)`,[id,b,c]);
 const use=async id=>(await db.query('SELECT process_special_skill($1,$2,$3,$4) r',[b,'p1',c,{skill_id:id}])).rows[0].r;
 const check=async(name,fn)=>{await fn();passed++;console.log('PASS',name);};
 await check('two skills execute independently and block repeat',async()=>{assert.equal((await use(s1)).ok,true);assert.equal((await use(s1)).ok,false);assert.equal((await use(s2)).ok,true);});
 await check('CD2 blocks next two owner turns, ignores intra-turn transitions',async()=>{
  await db.exec("SELECT set_config('tcg.intra_turn_action','on',false); UPDATE battle_sessions SET current_turn='p2'; UPDATE battle_sessions SET current_turn='p1'; SELECT set_config('tcg.intra_turn_action','off',false);");
  assert.equal((await db.query('SELECT player1_owner_turn n FROM battle_sessions')).rows[0].n,1);
  for(let turn=2;turn<=4;turn++){await db.exec("UPDATE battle_sessions SET current_turn='p2'; UPDATE battle_sessions SET current_turn='p1';");assert.equal((await use(s1)).ok,turn===4);}
 });
 await check('disabled, wrong owner, unknown skill and bench rejected',async()=>{
  await db.query('UPDATE battle_card_skills SET disabled=true,cooldown_until_owner_turn=NULL WHERE id=$1',[s1]);assert.equal((await use(s1)).ok,false);
  await db.query('UPDATE battle_card_skills SET disabled=false WHERE id=$1',[s1]);await db.exec("UPDATE battle_cards SET zone='bench'");assert.equal((await use(s1)).ok,false);await db.exec("UPDATE battle_cards SET zone='active'");
  assert.equal((await use('30000000-0000-0000-0000-000000000099')).ok,false);
 });
 // Isolate the wrapper's atomicity/idempotency contract from the large legacy combat engine.
 await db.exec(`CREATE OR REPLACE FUNCTION tcg_submit_battle_action_core_v2(p_code text,p_player text,p_token text,p_action text,p_card_id uuid DEFAULT NULL,p_payload jsonb DEFAULT '{}') RETURNS jsonb LANGUAGE plpgsql AS $$ BEGIN UPDATE battle_sessions SET player1_action_points=coalesce(player1_action_points,3)-1 WHERE code=$1; RETURN jsonb_build_object('ok',NOT coalesce(($6->>'reject')::boolean,false)); END $$;`);
 const action=async(id,payload={},token='a')=>(await db.query('SELECT submit_battle_action($1,$2,$3,$4,$5,$6) r',['UNIT','p1',token,'special_skill',c,{skill_id:s1,action_id:id,...payload}])).rows[0].r;
 await check('duplicate action returns receipt without another AP debit',async()=>{await db.exec('UPDATE battle_sessions SET player1_action_points=3');const id='40000000-0000-0000-0000-000000000001';assert.equal((await action(id)).ok,true);assert.equal((await action(id)).replayed,true);assert.equal((await db.query('SELECT player1_action_points n FROM battle_sessions')).rows[0].n,2);assert.equal((await action(id,{},'wrong')).ok,false);assert.equal((await action(id,{target_card_id:c})).ok,false);});
 await check('rejected result rolls back AP and creates no receipt',async()=>{const id='40000000-0000-0000-0000-000000000002';assert.equal((await action(id,{reject:true})).ok,false);assert.equal((await db.query('SELECT player1_action_points n FROM battle_sessions')).rows[0].n,2);assert.equal((await db.query('SELECT count(*)::int n FROM battle_action_receipts')).rows[0].n,1);});
 await check('anonymous cannot bypass guarded action entry',async()=>{assert.equal((await db.query("SELECT has_function_privilege('anon','process_special_skill(uuid,text,uuid,jsonb)','execute') allowed")).rows[0].allowed,false);});
 console.log(`${passed} SQL checks passed`);
} catch(error) { console.error(error.message, error.where ?? "", error.position, error.query?.slice(Math.max(0,Number(error.position)-160),Number(error.position)+80)); process.exitCode=1; } finally {await db.close();}
