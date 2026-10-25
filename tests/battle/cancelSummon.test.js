import test from 'node:test';
import assert from 'node:assert/strict';
import {describePublicAction} from '../../src/utils/publicBattleActions.js';
test('public cancellation notification identifies player without claiming a card was summoned',()=>{
 const battle={player1_name:'Alya',player2_name:'Raka'};
 const event={type:'action_request',source_player:'p2',payload:{action:'cancel_summon',action_points_refunded:2,message:'Summon dibatalkan sebelum kartu terbaca.'}};
 const notice=describePublicAction(event,battle);
 assert.equal(notice.title,'SUMMON DIBATALKAN');assert.equal(notice.playerName,'Raka');assert.equal(notice.player,'p2');assert.match(notice.message,/sebelum kartu terbaca/);
 assert.equal(describePublicAction({...event,payload:{action:'unknown'}},battle),null);
});
