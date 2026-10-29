import test from 'node:test';
import assert from 'node:assert/strict';
import { publicFeaturedCard, publicTurnSeconds } from '../../src/utils/publicBattlePresentation.js';

const battle = { status:'battle', current_turn:'p1', turn_index:5 };
const own = [{battleId:'a'},{battleId:'b'}], enemy = [{battleId:'c'},{battleId:'d'}];
const focus = (cardId, turn = 5) => ({cardId, turn, at:Date.now()});
test('both featured cards follow only the current player, never the newest off-turn click', () => {
  const states = {p1:{focus:{selected:focus('b'),target:focus('d')}},p2:{focus:{selected:focus('c'),target:focus('a')}}};
  assert.equal(publicFeaturedCard(battle,states,'p1',own).battleId,'b');
  assert.equal(publicFeaturedCard(battle,states,'p2',enemy).battleId,'d');
  const next = {...battle,current_turn:'p2',turn_index:6};
  assert.equal(publicFeaturedCard(next,states,'p1',own).battleId,'a');
  assert.equal(publicFeaturedCard(next,states,'p2',enemy).battleId,'c');
  states.p2.focus = {selected:focus('d',6),target:focus('b',6)};
  assert.equal(publicFeaturedCard(next,states,'p1',own).battleId,'b');
  assert.equal(publicFeaturedCard(next,states,'p2',enemy).battleId,'d');
});
test('accepted combat retains its target; removed cards and stale focus fall back safely', () => {
  const states={p1:{focus:{selected:focus('removed')}}};
  assert.equal(publicFeaturedCard(battle,states,'p1',own).battleId,'a');
  assert.equal(publicFeaturedCard(battle,states,'p1',[]),null);
  assert.equal(publicFeaturedCard(battle,states,'p2',enemy,{active:true,targetPlayer:'p2',targetCardId:'d'}).battleId,'d');
  assert.equal(publicFeaturedCard({...battle,status:'question'}, {p1:{focus:{selected:focus('b')}}}, 'p1', own).battleId,'a');
});
test('spectator clock follows the deadline, freezes on Host pause, and never shows negative or fabricated time', () => {
  const now=Date.parse('2026-10-28T00:00:00Z');
  const active={...battle,turn_deadline_at:new Date(now+10000).toISOString()};
  assert.equal(publicTurnSeconds(active,now),10);
  assert.equal(publicTurnSeconds(active,now+15000),0);
  assert.equal(publicTurnSeconds({...active,teacher_paused:true,teacher_paused_at:new Date(now+2000).toISOString()},now+30000),8);
  for (const patch of [{status:'finished'},{question_active:true},{winner:'p1'},{turn_deadline_at:null},{teacher_paused:true,teacher_paused_at:null}]) assert.equal(publicTurnSeconds({...active,...patch},now),null);
});
