import { BLOCK_TYPES,EMPTY_WORKSPACE,DEFAULT_GRADING } from './scratchBlocks.js';
export function normalizeWorkspace(workspace,config={}) {
 let count=0;const allowed=new Set([...(config.allowed_types??BLOCK_TYPES),'tbc_number','tbc_text']);
 function chain(block,depth=0){const result=[];while(block){if(++count>100||depth>24)throw new Error('Workspace maksimal 100 blok dan 24 tingkat.');if(!allowed.has(block.type))throw new Error(`Blok tidak diizinkan: ${block.type}`);if(block.extraState)throw new Error('Mutasi blok tidak didukung.');
  const fields=Object.fromEntries(Object.entries(block.fields??{}).map(([key,value])=>{if(!['string','number','boolean'].includes(typeof value)||String(value).length>500)throw new Error('Nilai input blok tidak valid.');return[key,value];}));
  const inputs=Object.fromEntries(Object.entries(block.inputs??{}).map(([key,input])=>[key,chain(input.block??input.shadow,depth+1)]));
  result.push({type:block.type,fields,inputs});block=block.next?.block;
 }return result;}
 if(!workspace||typeof workspace!=='object'||JSON.stringify(workspace).length>120000)throw new Error('Workspace tidak valid.');
 const blocks=workspace.blocks?.blocks??[];if(!Array.isArray(blocks))throw new Error('Struktur workspace tidak valid.');
 return blocks.map(block=>chain(block));
}
function match(a,b,rules,top=false){
 if(Array.isArray(b)){
  if(!Array.isArray(a)||(!rules.allow_extra&&a.length!==b.length)||a.length<b.length)return 0;
  if(!b.length)return a.length&&!rules.allow_extra?0:1;
  if(top||!rules.strict_order){const used=new Set();let score=0;for(const wanted of b){let best=-1,value=-1;for(let i=0;i<a.length;i++){if(used.has(i))continue;const n=match(a[i],wanted,rules);if(n>value){best=i;value=n;}}used.add(best);score+=Math.max(0,value);}return score/b.length;}
  return b.reduce((sum,wanted,i)=>sum+match(a[i],wanted,rules),0)/b.length;
 }
 if(b&&typeof b==='object'){
  if(!a||typeof a!=='object'||Array.isArray(a))return 0;
  if(b.type&&a.type!==b.type)return 0;
  const keys=Object.keys(b).filter(key=>rules.check_values||key!=='fields');
  if(!rules.allow_extra&&Object.keys(a).some(key=>!Object.hasOwn(b,key)))return 0;
  return keys.length?keys.reduce((sum,key)=>sum+match(a[key],b[key],rules),0)/keys.length:1;
 }
 if(a===b)return 1;
 if(rules.numeric_tolerance>0 && String(a??'').trim() && String(b??'').trim() && Number.isFinite(Number(a))&&Number.isFinite(Number(b)))return Math.abs(Number(a)-Number(b))<=rules.numeric_tolerance?1:0;
 return 0;
}
export function gradeWorkspace(answer,solutions,config={},rules={}){
 const settings={...DEFAULT_GRADING,...rules};const actual=normalizeWorkspace(answer,config);
 const variants=solutions?.length?solutions:[EMPTY_WORKSPACE];
 const fraction=Math.max(...variants.map(solution=>match(actual,normalizeWorkspace(solution,config),settings,true)));
 return {correct:fraction===1,score:(settings.partial_credit?fraction:fraction===1?1:0)*settings.weight};
}
