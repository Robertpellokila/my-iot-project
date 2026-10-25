import test from 'node:test';
import assert from 'node:assert/strict';
import { publicBattleActivity } from '../../src/utils/publicBattleActivity.js';
const battle = { status:'battle', current_turn:'p1', turn_index:11, player1_name:'Tari', player2_name:'Obe' };
const fields = { p1:{ active:[{battleId:'a',name:'Jolteon'}], bench:[{battleId:'b',name:'Tochi'},{battleId:'c',name:'Coby'}], graveyard:[] }, p2:{ active:[{battleId:'d',name:'Lapras'}], bench:[], graveyard:[{battleId:'g',name:'Pico'}] } };
const focus = (cardId,at=1,turn=11) => ({cardId,at,turn});
test('live selection follows the current player and selected opponent target',()=>{
 const state={p1:{focus:{selected:focus('a'),target:focus('d',2)}},p2:{focus:{selected:focus('d',3)}}};
 let result=publicBattleActivity(battle,state,fields);assert.equal(result.kind,'target');assert.equal(result.card.name,'Lapras');assert.equal(result.playerName,'Tari');
 state.p1.focus.selected=focus('a',4);result=publicBattleActivity(battle,state,fields);assert.equal(result.kind,'selected');assert.equal(result.card.name,'Jolteon');
 state.p1.focus.target=focus('d',4);assert.equal(publicBattleActivity(battle,state,fields).kind,'target');
});
test('viewer tracks identity when pile order changes and clamps missing indices',()=>{
 const state={p1:{viewerZone:'bench',viewerTurn:11,viewerIndex:0,viewerCardId:'c'}};
 let result=publicBattleActivity(battle,state,fields);assert.equal(result.index,1);assert.equal(result.card.name,'Coby');
 state.p1.viewerCardId='removed';state.p1.viewerIndex=999;assert.equal(publicBattleActivity(battle,state,fields).index,1);
 state.p1.viewerIndex=-1;assert.equal(publicBattleActivity(battle,state,fields).index,0);
});
test('off-turn, stale turn, quiz and finished battles cannot open a live viewer',()=>{
 const state={p1:{viewerZone:'bench',viewerTurn:11},p2:{viewerZone:'graveyard',viewerTurn:11}};
 assert.equal(publicBattleActivity(battle,state,fields).zone,'bench');
 assert.equal(publicBattleActivity({...battle,current_turn:'p2',turn_index:12},state,fields),null);
 assert.equal(publicBattleActivity({...battle,turn_index:13},state,fields),null);
 for(const change of [{status:'finished'},{question_active:true},{winner:'p1'},{current_turn:'other'}])assert.equal(publicBattleActivity({...battle,...change},state,fields),null);
});
test('graveyard and empty bench remain visible, closing restores selection',()=>{
 const state={p2:{viewerZone:'graveyard',viewerTurn:12,viewerIndex:0,focus:{selected:focus('d',1,12)}}};
 const turn={...battle,current_turn:'p2',turn_index:12};
 assert.equal(publicBattleActivity(turn,state,fields).card.name,'Pico');
 state.p2.viewerZone='bench';assert.equal(publicBattleActivity(turn,state,fields).cards.length,0);
 state.p2.viewerZone=null;assert.equal(publicBattleActivity(turn,state,fields).kind,'selected');
});
test('removed active cards do not leave stale live activity',()=>{
 const state={p1:{focus:{selected:focus('removed')}}};assert.equal(publicBattleActivity(battle,state,fields),null);
});
