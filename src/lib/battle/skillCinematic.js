// Presence is presentation intent only. Resolution must come from battle_events.
export const CINEMATIC_TIMINGS = { intro:500, selected:300, centering:500, activating:800, resolving:1200, outro:350, stale:45000 };
export const EFFECT_VISUALS = {
 damage:{symbol:'⚔',label:'Damage',color:'#ff765c'},heal:{symbol:'+',label:'Heal',color:'#80efab'},
 shield:{symbol:'⬡',label:'Shield',color:'#69d9ff'},burn:{symbol:'♨',label:'Burn',color:'#ffae48'},
 stun:{symbol:'ϟ',label:'Stun',color:'#fff18c'},buff:{symbol:'↑',label:'Buff',color:'#9cecc4'},
 debuff:{symbol:'↓',label:'Debuff',color:'#d4a1ff'},fusion:{symbol:'✧',label:'Fusion',color:'#f9d67e'},
 generic:{symbol:'✦',label:'Skill aktif',color:'#addfff'},
};
export function normalizeSkillIntent(value) {
 if(!value || !['choosing','selected'].includes(value.phase)) return null;
 const {id,cardId,skillId,phase}=value,turn=Number(value.turn),at=Number(value.at);
 if(!id || !cardId || String(id).length>128 || String(cardId).length>128 || !Number.isSafeInteger(turn) || turn<0 || !Number.isFinite(at))return null;
 return {id:String(id),cardId:String(cardId),skillId:skillId?String(skillId).slice(0,128):null,phase,turn,at};
}
export function createSkillCinematic({onChange,timings={},schedule=setTimeout,unschedule=clearTimeout,reducedMotion=false}) {
 const durations={...CINEMATIC_TIMINGS,...timings};let state={phase:'idle'},timer=null,stale=null,disposed=false;
 const seen=new Set(),queue=[];
 const stop=()=>{unschedule(timer);unschedule(stale);timer=null;stale=null;};
 const emit=(phase,data={})=>{if(disposed)return;state={...state,...data,phase};onChange({...state});};
 const later=(phase,callback)=>{unschedule(timer);timer=schedule(callback,reducedMotion?Math.min(phase==='resolving'?900:80,durations[phase]):durations[phase]);};
 const idle=()=>{stop();state={phase:'idle'};emit('idle');if(queue.length)play(queue.shift());};
 const resolve=(data)=>{stop();emit('selected',{...data,authoritative:true});later('selected',()=>{emit('centering');later('centering',()=>{emit('activating');later('activating',()=>{
  let index=0;const effects=data.effects?.length?data.effects:[{kind:'generic'}];
  const next=()=>{if(index>=effects.length){emit('outro');later('outro',idle);return;}emit('resolving',{effect:effects[index++],effectIndex:index,effectCount:effects.length});later('resolving',next);};next();
 });});});};
 const play=data=>{resolve(data);};
 return {
  get state(){return state;},
  intent(data){
   if(disposed||state.authoritative)return;
   const same=state.intent?.id===data.intent.id;
   stop();emit(same?'choosing':'intro',{...data,authoritative:false});
   if(!same)later('intro',()=>emit('choosing'));
   stale=schedule(()=>this.cancel(),durations.stale);
  },
  accepted(data){
   if(disposed||!data.eventId||seen.has(String(data.eventId)))return false;
   seen.add(String(data.eventId));if(seen.size>256)seen.delete(seen.values().next().value);
   if(state.authoritative)queue.push(data);else play(data);return true;
  },
  cancel(){if(!state.authoritative)idle();},
  reset(){queue.length=0;seen.clear();idle();},
  dispose(){stop();queue.length=0;disposed=true;},
 };
}

export function cinematicEffects(event) {
 const payload=event?.payload??{};
 const results=payload.effect_result?.ok===false?[]:payload.effect_result?.results??[];
 const output=results.filter(item=>item?.ok!==false).map(item=>{
  const result=item.result??item,type=String(result.effect_type??item.type??'').toLowerCase(),status=String(result.status_key??'').toLowerCase();
  let kind='generic',amount=null;
  if(type.startsWith('damage')){kind='damage';amount=result.actual_damage;}
  else if(type.startsWith('heal')||type==='revive'){kind='heal';amount=result.actual_heal??result.restored_hp;}
  else if(type==='add_status'||type==='apply_status'){
   kind=status.includes('shield')?'shield':status.includes('burn')?'burn':/stun|freeze/.test(status)?'stun':/debuff|weak|poison|root|silence|mark|attack_reduction/.test(status)?'debuff':'buff';
   amount=result.value?.amount??result.value?.shield_amount??null;
  } else if(type==='remove_status'){kind='buff';}
  else if(type==='add_skill_gauge'){kind='buff';amount=result.actual_gain;}
  else if(type.includes('fusion'))kind='fusion';
  return {kind,amount:amount!=null&&Number.isFinite(Number(amount))?Number(amount):null,status,targetCardId:result.target_card_id??payload.target_card_id,targetPlayer:result.target_player??payload.target_player,hpAfter:result.hp_after};
 });
 if(!output.length){
  if(Number(payload.damage)>0)output.push({kind:'damage',amount:Number(payload.damage),targetCardId:payload.target_card_id,targetPlayer:payload.target_player});
  if(Number(payload.heal)>0)output.push({kind:'heal',amount:Number(payload.heal),targetCardId:payload.target_card_id,targetPlayer:payload.target_player});
 }
 return output.length?output:[{kind:event?.type==='fusion'?'fusion':'generic',targetCardId:payload.target_card_id,targetPlayer:payload.target_player}];
}
