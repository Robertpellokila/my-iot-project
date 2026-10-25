export const MATERIAL_MODES=[['exact_card','EXACT · kartu tertentu'],['tag','ONE TAG · satu tag'],['one_of','ONE OF · salah satu kartu']];
export const STAT_MODES=[['fixed','Statistik tetap'],['material_sum_percent','Persentase total material'],['highest_material_percent','Persentase material tertinggi']];
export const materialDraft=(row={})=>({...row,key:row.id??crypto.randomUUID(),material_type:row.material_type==='one_tag'?'tag':row.material_type==='specific_card'?'exact_card':row.material_type??'exact_card',quantity:Number(row.quantity??1),card_code:row.card_code??'',card_codes:[...(row.card_codes??[])],tag:row.tag??'',allowed_zones:[...(row.allowed_zones??['active','bench'])],optional:row.optional??false,group_key:row.group_key??'main',metadata:row.metadata??{}});
export function recipeDraft(card,recipe={}){
 return {...recipe,id:recipe.id??crypto.randomUUID(),code:recipe.code??`fusion_${card.id.replaceAll('-','').slice(0,20)}_${crypto.randomUUID().slice(0,8)}`,name:recipe.name??`${card.name} Fusion`,description:recipe.description??'',icon:recipe.icon??'✦',is_active:recipe.is_active??true,consumes_turn:recipe.consumes_turn??false,limits:{once_per_battle:true,max_uses:1,...recipe.limits},cost_spec:recipe.cost_spec??{type:'none',value:0},conditions:recipe.conditions??{},requirements:recipe.requirements??{},result_overrides:recipe.result_overrides??{},result_zone:recipe.result_zone??'active',material_destination:recipe.material_destination??'graveyard',priority:recipe.priority??100,result_stat_spec:JSON.parse(JSON.stringify(recipe.result_stat_spec??Object.fromEntries([['hp',card.hp],['attack',card.attack],['defense',card.defense]].map(([key,value])=>[key,{mode:'fixed',value:Number(value)||0}]))))};
}
export function normalizeRecipeMaterials(rows){
 if(!Array.isArray(rows)||!rows.length||rows.length>20)throw new Error('Tambahkan 1–20 baris material.');
 let total=0;
 return rows.map((row,i)=>{
  const type=row.material_type==='one_tag'?'tag':row.material_type;
  const quantity=Number(row.quantity),zones=[...new Set(row.allowed_zones??[])];
  if(!MATERIAL_MODES.some(([value])=>value===type))throw new Error(`Material ${i+1}: pilih EXACT, ONE TAG, atau ONE OF.`);
  if(!Number.isInteger(quantity)||quantity<1||quantity>20)throw new Error(`Material ${i+1}: jumlah harus 1–20.`);
  total+=quantity;if(total>20)throw new Error('Jumlah seluruh material maksimal 20 kartu.');
  if(!zones.length||zones.some(zone=>!['active','bench'].includes(zone)))throw new Error(`Material ${i+1}: pilih Active atau Bench.`);
  const code=String(row.card_code??'').trim().toUpperCase(),codes=[...new Set((row.card_codes??[]).map(v=>String(v).trim().toUpperCase()).filter(Boolean))],tag=String(row.tag??'').trim().toLowerCase();
  if(type==='exact_card'&&!code)throw new Error(`Material ${i+1}: pilih kartu EXACT.`);
  if(type==='one_of'&&!codes.length)throw new Error(`Material ${i+1}: pilih minimal satu alternatif ONE OF.`);
  if(type==='tag'&&!tag)throw new Error(`Material ${i+1}: isi tag ONE TAG.`);
  return {...row,key:undefined,id:undefined,recipe_id:undefined,created_at:undefined,material_type:type,quantity,allowed_zones:zones,card_code:type==='exact_card'?code:null,card_codes:type==='one_of'?codes:[],tag:type==='tag'?tag:null,sort_order:(i+1)*10};
 });
}
export const materialSummary=row=>`${row.quantity} × ${row.material_type==='tag'?`tag ${row.tag||'…'}`:row.material_type==='one_of'?row.card_codes.join(' / ')||'pilih alternatif':row.card_code||'pilih kartu'}`;
