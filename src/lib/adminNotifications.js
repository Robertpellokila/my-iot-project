const defaults={success:4500,danger:9000,warning:7000,info:5000,loading:0};
const titles={success:'Berhasil',danger:'Gagal',warning:'Periksa kembali',info:'Informasi',loading:'Memproses'};
export function createAdminToastStore({now=Date.now,schedule=setTimeout,cancel=clearTimeout,limit=4}={}){
 let sequence=0,items=[];const listeners=new Set(),timers=new Map(),globalPauses=new Set();
 const snapshot=()=>items.map(({reasons,...item})=>({...item,paused:reasons.size>0}));
 const emit=()=>{const state=snapshot();for(const listener of listeners)listener(state);};
 const clearTimer=id=>{if(timers.has(id))cancel(timers.get(id));timers.delete(id);};
 function dismiss(id){clearTimer(id);items=items.filter(item=>item.id!==id);emit();}
 function arm(item){clearTimer(item.id);if(item.remaining>0&&!item.reasons.size){item.started=now();timers.set(item.id,schedule(()=>dismiss(item.id),item.remaining));}}
 function add(options={}){
  const type=Object.hasOwn(defaults,options.type)?options.type:'info';const message=String(options.message??'').trim().slice(0,700);if(!message)return null;
  const title=String(options.title??titles[type]).trim().slice(0,100);const stamp=now();
  const existing=options.id!=null?items.find(item=>item.id===options.id):type==='loading'?null:items.find(item=>item.type===type&&item.title===title&&item.message===message||options.key&&item.key===options.key&&stamp-item.updatedAt<350);
  const duration=Number.isFinite(options.duration)?Math.max(0,options.duration):defaults[type];
  if(existing){Object.assign(existing,{type,title,message,duration,remaining:duration,updatedAt:stamp,revision:existing.revision+1});arm(existing);emit();return existing.id;}
  if(items.length>=limit)dismiss((items.find(item=>!['danger','loading'].includes(item.type))??items[0]).id);
  const item={id:++sequence,key:options.key,type,title,message,duration,remaining:duration,updatedAt:stamp,revision:0,reasons:new Set(globalPauses)};
  items.push(item);arm(item);emit();return item.id;
 }
 function pause(id,reason='pointer'){const item=items.find(item=>item.id===id);if(!item||item.reasons.has(reason))return;if(!item.reasons.size&&timers.has(id))item.remaining=Math.max(1,item.remaining-(now()-item.started));item.reasons.add(reason);clearTimer(id);emit();}
 function resume(id,reason='pointer'){const item=items.find(item=>item.id===id);if(!item||!item.reasons.has(reason))return;item.reasons.delete(reason);arm(item);emit();}
 function pauseAll(reason){globalPauses.add(reason);for(const item of items)pause(item.id,reason);}
 function resumeAll(reason){globalPauses.delete(reason);for(const item of items)resume(item.id,reason);}
 return {add,dismiss,pause,resume,pauseAll,resumeAll,get:snapshot,update(id,changes){const item=items.find(item=>item.id===id);if(!item)return null;return add({...item,...changes,id,duration:changes.duration??(changes.type&&changes.type!==item.type?defaults[changes.type]:item.duration)});},
  clear(){for(const id of timers.keys())clearTimer(id);items=[];emit();},subscribe(listener){listeners.add(listener);listener(snapshot());return()=>listeners.delete(listener);}};
}
export const adminToastStore=createAdminToastStore();
