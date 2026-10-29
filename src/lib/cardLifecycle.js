// Matches the server's source-chain availability check. Publication is independent.
export function cardBattleState(card, records = []) {
 if(!card)return {enabled:false,reason:'missing'};
 const index=records instanceof Map?records:new Map(records.map(item=>[item.id,item]));
 const seen=new Set();let current=card;
 for(let depth=0;depth<32;depth++){
  if(!current||seen.has(current.id))return {enabled:false,reason:'source',source:current};
  seen.add(current.id);
  if(current.archived_at||current.battle_enabled===false)return {enabled:false,reason:current.id===card.id?(current.archived_at?'archived':'disabled'):'source',source:current};
  const parent=current.metadata?.catalog_source_id;if(!parent)return {enabled:true,reason:'active'};
  current=index.get(parent);
 }
 return {enabled:false,reason:'source',source:current};
}
export function cardLifecycleLabel(card,records){const state=cardBattleState(card,records);return state.enabled?'Aktif di battle':state.reason==='archived'?'Di Sampah':state.reason==='source'?'Sumber nonaktif':'Nonaktif di battle';}
