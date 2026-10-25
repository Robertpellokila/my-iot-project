import {readFile} from 'node:fs/promises';
import assert from 'node:assert/strict';
import {PGlite} from '@electric-sql/pglite';
const db=new PGlite();let passed=0;
const id='42000000-0000-4000-8000-000000000001';
try {
 await db.exec('CREATE ROLE anon;CREATE ROLE authenticated;CREATE ROLE service_role;');
 await db.exec(await readFile(new URL('./schema.sql',import.meta.url),'utf8'));
 await db.exec(`CREATE FUNCTION tcg_sync_battle_turn(text,text,text) RETURNS jsonb LANGUAGE plpgsql AS $$
 BEGIN
  UPDATE battle_sessions SET current_turn='p2',turn_index=turn_index+1,pending_action=NULL,pending_action_player=NULL,player1_action_points=0
   WHERE code=$1 AND turn_deadline_at<=now() AND current_turn='p1';
  RETURN '{"ok":true}';
 END $$;
 INSERT INTO battle_sessions(id,code,ruleset,status,current_turn,round,turn_index,player1_token,player2_token,
  player1_action_points,player2_action_points,action_points_enabled,action_points_per_turn,turn_started_at,turn_deadline_at,pending_action,pending_action_player)
 VALUES('${id}','CANCEL','tcg_v1','battle','p1',3,5,'one','two',1,0,true,3,now()-interval '1 minute',now()+interval '5 minutes','summon','p1');
 INSERT INTO battle_events(battle_id,type,source_player,payload,created_at)
 VALUES('${id}','action_request','p1','{"action":"summon","action_points_spent":2}',now());`);
 await db.exec(await readFile(new URL('../../supabase/migrations/042_cancel_pending_summon.sql',import.meta.url),'utf8'));
 const state=async()=>(await db.query('SELECT * FROM battle_sessions WHERE id=$1',[id])).rows[0];
 const cancel=async(request,player='p1',token='one')=>(await db.query('SELECT cancel_battle_summon($1,$2,$3,$4) r',['CANCEL',player,token,request])).rows[0].r;
 const start=async(cost=1)=>{
  await db.query(`UPDATE battle_sessions SET pending_action=NULL,pending_action_player=NULL,status='battle',question_active=false,winner=NULL,current_turn='p1',turn_index=5,
    player1_action_points=3,action_points_enabled=true,ruleset='tcg_v1',turn_deadline_at=now()+interval '5 minutes' WHERE id=$1`,[id]);
  await db.query(`UPDATE battle_sessions SET pending_action='summon',pending_action_player='p1',player1_action_points=3-$2 WHERE id=$1`,[id,cost]);
  return (await state()).pending_summon_request_id;
 };
 const check=async(name,fn)=>{await fn();passed++;console.log('PASS',name);};
 await check('existing verified reservation backfills actual ledger cost',async()=>{
  const pending=await state();assert.equal(pending.pending_summon_ap_cost,2);assert.ok(pending.pending_summon_request_id);
  const result=await cancel(pending.pending_summon_request_id);assert.equal(result.ok,true);assert.equal(result.action_points_refunded,2);assert.equal((await state()).player1_action_points,3);
 });
 await check('zero remaining AP can cancel and duplicate cancellation never refunds twice',async()=>{
  const request=await start(3);assert.equal((await state()).player1_action_points,0);assert.equal((await cancel(request)).action_points_refunded,3);
  assert.equal((await cancel(request)).ok,false);assert.equal((await state()).player1_action_points,3);
 });
 await check('cost changes do not change original refund; reservation fields are immutable',async()=>{
  const request=await start(2);
  await db.exec(`UPDATE battle_sessions SET action_costs='{"summon":1}',pending_summon_ap_cost=10,pending_summon_request_id=gen_random_uuid(),pending_summon_turn_index=99`);
  assert.equal((await state()).pending_summon_request_id,request);assert.equal((await cancel(request)).action_points_refunded,2);
 });
 await check('old request cannot cancel a new summon in the same turn',async()=>{
  const old=await start();await cancel(old);const current=await start();assert.notEqual(current,old);
  assert.equal((await cancel(old)).code,'SUMMON_CHANGED');assert.equal((await state()).pending_summon_request_id,current);assert.equal((await state()).player1_action_points,2);
 });
 await check('wrong token, owner, request and turn cannot clear pending or credit AP',async()=>{
  const request=await start();assert.equal((await cancel(request,'p1','wrong')).code,'INVALID_PLAYER');
  assert.equal((await cancel(request,'p2','two')).ok,false);assert.equal((await cancel(null)).code,'SUMMON_CHANGED');
  await db.exec("UPDATE battle_sessions SET turn_index=7");assert.equal((await cancel(request)).code,'TURN_CHANGED');assert.equal((await state()).player1_action_points,2);
 });
 await check('quiz, finished battle and timeout reject cancellation',async()=>{
  let request=await start();await db.exec('UPDATE battle_sessions SET question_active=true');assert.equal((await cancel(request)).ok,false);
  request=await start();await db.exec("UPDATE battle_sessions SET status='finished',winner='p2'");assert.equal((await cancel(request)).ok,false);
  request=await start();await db.exec("UPDATE battle_sessions SET turn_deadline_at=now()-interval '1 second'");assert.equal((await cancel(request)).code,'TURN_CHANGED');assert.equal((await state()).current_turn,'p2');assert.equal((await state()).player1_action_points,0);
 });
 await check('zero-cost and Classic pending requests never mint AP',async()=>{
  let request=await start(0);assert.equal((await cancel(request)).action_points_refunded,0);assert.equal((await state()).player1_action_points,3);
  await db.exec("UPDATE battle_sessions SET ruleset='classic',action_points_enabled=false,player1_action_points=0,pending_action='summon',pending_action_player='p1'");
  request=(await state()).pending_summon_request_id;assert.equal((await cancel(request)).action_points_refunded,0);assert.equal((await state()).player1_action_points,0);
 });
 // Match the scanner's existing session row-lock and pending-request guard.
 await db.exec(`CREATE FUNCTION simulate_scan() RETURNS boolean LANGUAGE plpgsql AS $$ DECLARE b battle_sessions; BEGIN
  SELECT * INTO b FROM battle_sessions WHERE code='CANCEL' FOR UPDATE;
  IF b.pending_action IS DISTINCT FROM 'summon' THEN RETURN false; END IF;
  INSERT INTO battle_cards(battle_id,player,zone,name,hp,current_hp) VALUES(b.id,'p1','active','Scanned',100,100);
  UPDATE battle_sessions SET pending_action=NULL,pending_action_player=NULL WHERE id=b.id;RETURN true;
 END $$;`);
 await check('cancel first prevents late placement; scan first prevents refund or card deletion',async()=>{
  let request=await start();assert.equal((await cancel(request)).ok,true);assert.equal((await db.query('SELECT simulate_scan() ok')).rows[0].ok,false);
  request=await start();assert.equal((await db.query('SELECT simulate_scan() ok')).rows[0].ok,true);assert.equal((await cancel(request)).code,'NO_PENDING_SUMMON');
  assert.equal((await db.query('SELECT count(*)::int n FROM battle_cards')).rows[0].n,1);assert.equal((await state()).player1_action_points,2);assert.equal((await state()).pending_summon_request_id,null);
 });
 await check('refund preserves timer, turn, deck and slots and logs only accepted cancellations',async()=>{
  const request=await start();const before=await state();const logs=(await db.query("SELECT count(*)::int n FROM battle_events WHERE payload->>'action'='cancel_summon'")).rows[0].n;await cancel(request);const after=await state();
  for(const key of ['round','turn_index','turn_deadline_at','turn_started_at','player1_deck_remaining','player2_deck_remaining'])assert.deepEqual(after[key],before[key]);
  assert.equal((await db.query("SELECT count(*)::int n FROM battle_events WHERE payload->>'action'='cancel_summon'")).rows[0].n,logs+1);
 });
 await check('RPC is granted, internal trigger cannot be invoked by anonymous clients',async()=>{
  assert.equal((await db.query("SELECT has_function_privilege('anon','cancel_battle_summon(text,text,text,uuid)','execute') ok")).rows[0].ok,true);
  assert.equal((await db.query("SELECT has_function_privilege('anon','tcg_track_pending_summon()','execute') ok")).rows[0].ok,false);
 });
 console.log(`${passed} cancellation SQL checks passed`);
} catch(error){console.error(error.message,error.where??'',error.position??'');process.exitCode=1;} finally {await db.close();}
