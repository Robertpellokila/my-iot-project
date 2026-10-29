import {test} from 'node:test';import assert from 'node:assert/strict';
import {playerBattleAvatar,playerSetupPhoto,isPlayerPhoto} from '../../src/utils/playerBattleAvatar.js';
test('setup photo takes precedence over chosen avatar independently for each player',()=>{
 const battle={player1_setup_photo_url:'https://example.invalid/p1.webp',player1_avatar_url:'🐻',player2_setup_photo_url:'/images/p2.webp',player2_avatar_url:'🐼'};
 assert.equal(playerBattleAvatar(battle,'p1'),battle.player1_setup_photo_url);assert.equal(playerBattleAvatar(battle,'p2'),battle.player2_setup_photo_url);
});
test('legacy setup image, emoji and empty identities still work',()=>{assert.equal(playerSetupPhoto({player1_avatar_url:'/images/old.webp'},'p1'),'/images/old.webp');assert.equal(playerBattleAvatar({player2_avatar_url:'🐱'},'p2'),'🐱');assert.equal(playerSetupPhoto({player1_avatar_url:'🐻'},'p1'),'');assert.equal(playerBattleAvatar(null,'p1'),'');});
test('invalid setup URL does not override the safe fallback',()=>{assert.equal(playerBattleAvatar({player1_setup_photo_url:'javascript:alert(1)',player1_avatar_url:'🐻'},'p1'),'🐻');assert.equal(isPlayerPhoto('//example.invalid/x'),false);});
