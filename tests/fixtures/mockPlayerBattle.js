import { readFileSync } from 'node:fs';
import { randomUUID } from 'node:crypto';
import { createBattleDemo, createDemoSkills } from '../../scripts/lib/battle-demo.mjs';

const env = ['.env', '.env.local'].map(path => { try { return readFileSync(path, 'utf8'); } catch { return ''; } }).join('\n');
export const battleEndpoint = env.match(/^VITE_SUPABASE_URL\s*=\s*["']?([^\s"']+)/m)[1];

export async function mockPlayerBattle(page, overrides = {}) {
  const art = JSON.parse(readFileSync('src/data/card-generator/starter-artwork.json', 'utf8'));
  const { battle, cards } = createBattleDemo(new Map(), art);
  Object.assign(battle, {turn_deadline_at: new Date(Date.now() + 300000).toISOString(), direct_attack_enabled: true,pending_summon_request_id:null,pending_summon_ap_cost:0,pending_summon_turn_index:null}, overrides);
  const source = cards[0], target = cards.find(card => card.player === 'p2' && card.zone === 'active');
  const skills = createDemoSkills(battle, source);
  skills[0].icon='/images/tutorial/player-battle-guide.jpg';
  const submissions = [], cancellations=[], clients = [];
  let delay = 200, rejectNext = false;
  await page.routeWebSocket('**', socket => {
    const client = {socket, channels:[]}; clients.push(client);
    socket.onMessage(raw => {
      // realtime-js sends user broadcasts as a compact binary frame.
      if (typeof raw !== 'string') {
        const bytes=Buffer.from(raw);
        if(bytes[0]===3){
          let offset=7;
          const field=size=>{const text=bytes.subarray(offset,offset+size).toString('utf8');offset+=size;return text;};
          const join=field(bytes[1]),ref=field(bytes[2]),topic=field(bytes[3]);
          socket.send(JSON.stringify([join,ref,topic,'phx_reply',{status:'ok',response:{}}]));
        }
        return;
      }
      const value = JSON.parse(String(raw));
      const array = Array.isArray(value);
      const message = array ? {join_ref:value[0],ref:value[1],topic:value[2],event:value[3],payload:value[4]} : value;
      const send = (event, payload) => socket.send(JSON.stringify(array ? [message.join_ref,message.ref,message.topic,event,payload] : {topic:message.topic,ref:message.ref,event,payload}));
      if (message.event === 'phx_join') {
        const changes = (message.payload?.config?.postgres_changes ?? []).map((change, index) => ({...change,id:index+1}));
        client.channels.push({topic:message.topic,changes,array,join_ref:message.join_ref});
        send('phx_reply',{status:'ok',response:{postgres_changes:changes}});
      } else if (message.event === 'heartbeat' || message.event === 'broadcast' || message.event === 'phx_leave') send('phx_reply',{status:'ok',response:{}});
    });
  });
  function publish(table, record) {
    for (const {socket,channels} of clients) for (const channel of channels) {
      const ids = channel.changes.filter(change => change.table === table).map(change => change.id);
      if (!ids.length) continue;
      const payload = {ids,data:{schema:'public',table,type:'UPDATE',columns:[],record,old_record:{id:record.id},errors:null,commit_timestamp:new Date().toISOString()}};
      try { socket.send(JSON.stringify(channel.array ? [channel.join_ref,null,channel.topic,'postgres_changes',payload] : {topic:channel.topic,event:'postgres_changes',payload})); } catch { /* Closed test page. */ }
    }
  }
  await page.route(`${battleEndpoint}/**`, async route => {
    const url = new URL(route.request().url()), resource = url.pathname.split('/').at(-1);
    if (resource === 'battle_sessions') return route.fulfill({json:battle});
    if (resource === 'battle_cards') {
      let rows = url.searchParams.has('zone') ? cards : cards.filter(card => card.zone !== 'graveyard');
      for (const field of ['player','zone']) { const match = url.searchParams.get(field); if (match?.startsWith('eq.')) rows = rows.filter(card => card[field] === match.slice(3)); }
      return route.fulfill({json:rows,headers:{'content-range':`0-${Math.max(0,rows.length-1)}/${rows.length}`}});
    }
    if (resource === 'battle_card_skills') return route.fulfill({json:skills.filter(skill => url.searchParams.get('battle_card_id') === `eq.${skill.battle_card_id}`)});
    if (resource === 'tcg_sync_battle_turn') return route.fulfill({json:{ok:true,server_now:new Date().toISOString()}});
    if (resource === 'cancel_battle_summon') {
      const body=route.request().postDataJSON();cancellations.push(body);
      await new Promise(resolve=>setTimeout(resolve,delay));
      if(battle.pending_action!=='summon' || body.p_request_id!==battle.pending_summon_request_id) return route.fulfill({json:{ok:false,code:'NO_PENDING_SUMMON',message:'Tidak ada Summon yang menunggu. Kartu mungkin sudah terbaca.'}});
      const refund=battle.pending_summon_ap_cost;
      battle.player1_action_points+=refund;battle.pending_action=null;battle.pending_action_player=null;battle.pending_summon_request_id=null;battle.pending_summon_ap_cost=0;
      publish('battle_sessions',structuredClone(battle));
      return route.fulfill({json:{ok:true,action_points_refunded:refund,action_points:battle.player1_action_points}});
    }
    if (resource === 'submit_battle_action') {
      const body = route.request().postDataJSON(); submissions.push(body);
      await new Promise(resolve => setTimeout(resolve,delay));
      if (rejectNext) { rejectNext=false; return route.fulfill({json:{ok:false,message:'Kondisi kartu berubah. Periksa target dan coba lagi.'}}); }
      const cost = body.p_action === 'special_skill' ? skills.find(skill => skill.id === body.p_payload.skill_id)?.limits.action_points ?? 1 : battle.action_costs?.[body.p_action] ?? ({fusion:2,ultimate:2,combo_attack:2,end_turn:0}[body.p_action] ?? 1);
      if (battle.action_points_enabled) battle.player1_action_points = Math.max(0,battle.player1_action_points-cost);
      if (body.p_action === 'summon') { battle.pending_action='summon';battle.pending_action_player='p1';battle.pending_summon_request_id=randomUUID();battle.pending_summon_ap_cost=battle.action_points_enabled?cost:0;battle.pending_summon_turn_index=battle.turn_index; }
      if (body.p_action === 'attack') { source.attack_turn_index=battle.turn_index;source.attacks_this_turn=1; }
      if (body.p_action === 'end_turn') { battle.current_turn='p2';battle.turn_index++;battle.player1_action_points=0;battle.player2_action_points=3; }
      if (body.p_action === 'special_skill') skills.find(skill => skill.id === body.p_payload.skill_id).cooldown_until_owner_turn = battle.player1_owner_turn + 2;
      publish('battle_sessions',structuredClone(battle));publish('battle_cards',structuredClone(source));
      return route.fulfill({json:{ok:true,waiting_rfid:body.p_action==='summon',ends_turn:false,damage:body.p_action==='attack'?22:0,message:'Aksi berhasil.'}});
    }
    return route.fulfill({json:[]});
  });
  return {
    battle,cards,skills,source,target,submissions,cancellations,
    setDelay(value) { delay=value; },
    rejectNext() { rejectNext=true; },
    patch(values) { Object.assign(battle,values);publish('battle_sessions',structuredClone(battle)); },
    refreshCards() { publish('battle_cards',structuredClone(source)); },
    async open() { await page.goto('/play/GUIDEDEMO/p1?token=demo-player-one');await page.locator('.player-action-panel').waitFor(); },
  };
}
