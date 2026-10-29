export function createDemoSkills(battle, source) {
  const skills = [
    {id:'30000000-0000-4000-8000-000000000001',battle_id:battle.id,battle_card_id:source.id,player:'p1',name:'Arc Rally',skill_code:'arc_rally',icon:'⚔',description:'Serangan normal +6 setelah Summon. CD 2.',priority:1,activation_timing:'main_phase',target_spec:{type:'enemy_active',required:true},cost_spec:{type:'none'},limits:{cooldown_turns:2,action_points:1},effects:[],consumes_turn:false,metadata:{master_metadata:{slot:1}}},
    {id:'30000000-0000-4000-8000-000000000002',battle_id:battle.id,battle_card_id:source.id,player:'p1',name:'Team Spirit',skill_code:'team_spirit',icon:'🛡',description:'Pulihkan 12 HP pada satu ally. CD 2.',priority:2,activation_timing:'main_phase',target_spec:{type:'ally_active',required:true},cost_spec:{type:'none'},limits:{cooldown_turns:2,action_points:2},effects:[],consumes_turn:false,metadata:{master_metadata:{slot:2}}},
  ];
  // Demo readiness uses the same concrete mechanics as a saved battle skill.
  skills[0].effects = [{type:'studio_skill',program:{version:2,target:'enemy_active',operations:[{type:'attack',amount:6,condition:'ally_summoned',multiplier:1}],choices:[],attacks:true,max_targets:1,exclusive:false}}];
  skills[1].effects = [{type:'heal_card',target:'target_card',owner:'self',allowed_zones:['active'],amount:{mode:'fixed',value:12}}];
  return skills;
}

export function createBattleDemo(publicImages = new Map(), artwork = {}) {
 const battle={id:'10000000-0000-4000-8000-000000000001',code:'GUIDEDEMO',ruleset:'tcg_v1',status:'battle',current_turn:'p1',round:3,total_rounds:10,turn_index:5,player1_token:'demo-player-one',player2_token:'demo-player-two',player1_name:'Alya',player2_name:'Raka',player1_avatar_url:'🐻',player2_avatar_url:'🦊',player1_hp:170,player2_hp:150,player1_max_hp:200,player2_max_hp:200,player1_owner_turn:3,player2_owner_turn:2,player1_skill:40,player2_skill:25,player1_action_points:3,player2_action_points:0,action_points_per_turn:3,action_points_enabled:true,special_card_skills_enabled:true,fusion_enabled:true,combo_enabled:true,question_enabled:true,question_active:false,is_active:true,active_until:'2099-01-01T00:00:00Z',turn_duration_seconds:60,turn_started_at:new Date().toISOString(),turn_deadline_at:new Date(Date.now()+30000).toISOString(),max_active:4,max_bench:4,max_attacks_per_card:1,player1_deck_remaining:16,player2_deck_remaining:17,player1_deck_size:20,player2_deck_size:20};
 battle.deck_size=20;
 const entries=[['p1','active',1,'Coby','Knight','COB-006',120,100,33,11],['p1','active',2,'Tochi','Forest','TOC-003',110,90,29,10],['p1','bench',null,'Falcon','Light','FAL-003',102,102,31,8],['p1','graveyard',null,'Pico Cat','Fire','PIC-003',102,0,31,8],['p2','active',1,'Byte Fox','Thunder','FOX-003',100,85,32,8],['p2','bench',null,'Cache Turtle','Water','TUR-006',130,130,28,14]];
 const cards=entries.map(([player,zone,slot,name,element,code,hp,current_hp,attack,defense],i)=>({id:`20000000-0000-4000-8000-${String(i+1).padStart(12,'0')}`,battle_id:battle.id,player,zone,slot,name,element,card_code:code,uid:`DEMO-${i}`,base_hp:hp,hp,current_hp,attack,defense,image_url:publicImages.get(code)??artwork[code]?.url,origin_type:'rfid',card_kind:'normal',rarity:'common'}));

 return {battle,cards};
}
