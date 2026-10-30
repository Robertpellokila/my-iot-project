import {normalizeTcgType} from '../../utils/tcgTypes.js';
export const SYNERGY_TYPES=['knight','fire','water','forest','thunder','light','dark','ice'];
export const EFFECTS={
 heal_percent:{label:'Pulihkan HP pemain (%)',unit:'% Max HP',max:100,describe:v=>`Pulihkan ${v}% Max HP pemainmu.`},
 heal_flat:{label:'Pulihkan HP pemain (nilai tetap)',unit:'HP',max:1000,describe:v=>`Pulihkan ${v} HP pemainmu.`},
 shield_percent:{label:'Shield serangan berikutnya',unit:'% pengurangan',max:95,describe:v=>`Kurangi damage berikutnya ke pemainmu sebesar ${v}%. Shield tidak ditumpuk; nilai terkuat dipertahankan.`},
 add_gauge:{label:'Tambah Ultimate Gauge',unit:'poin gauge',max:100,describe:v=>`Tambah ${v} poin Ultimate Gauge, maksimum 100.`},
 attack_debuff_percent:{label:'Kurangi serangan lawan berikutnya',unit:'% pengurangan',max:95,describe:v=>`Kurangi damage serangan lawan berikutnya sebesar ${v}%.`},
 power_strike:{label:'Power Strike (+50% serangan basic)',unit:'% tambahan',max:50,fixed:50,describe:()=> 'Serangan basic berikutnya +50% damage; habis setelah dipakai.'},
 defense:{label:'Bertahan (50% damage berikutnya)',unit:'% pengurangan',max:50,fixed:50,describe:()=> 'Aktifkan Defense: damage berikutnya ke pemainmu berkurang 50%. Efek yang mengabaikan Defense tetap berlaku.'},
 cleanse:{label:'Hapus debuff ATK pemain',unit:'',max:0,fixed:0,describe:()=> 'Hapus efek penurunan Attack pada pemainmu.'},
 burst:{label:'Serang HP pemain lawan dari ATK sumber',unit:'% ATK sumber',max:500,min:1,synergyOnly:true,describe:v=>`Damage ke HP pemain lawan sebesar ${v}% ATK kartu sumber; debuff ATK, Defense, dan Shield tetap berlaku.`},
 piercing_burst:{label:'Serangan sumber menembus Defense',unit:'% ATK sumber',max:500,min:1,synergyOnly:true,describe:v=>`Damage ke HP pemain lawan sebesar ${v}% ATK kartu sumber. Abaikan Defense; debuff ATK dan Shield tetap berlaku.`},
};
export const normalizeSynergyType=value=>String(value??'').trim().toLowerCase()==='ice'?'ice':normalizeTcgType(value);
export const effectSummary=(rule,tier=rule?.kind==='synergy'?2:1)=>EFFECTS[rule?.effect_type]?.describe(Number(rule?.effect_values?.[tier]??0))||'Aturan efek belum tersedia.';
export function synergyRuleState(rules,selected,cards=[],used={}){
 const element=normalizeSynergyType(selected?.element),rule=rules.find(item=>normalizeSynergyType(item.element)===element&&item.enabled!==false);
 const eligible=card=>card&&(!card.zone||card.zone==='active')&&!card.exhausted&&Number(card.current_hp??card.currentHp??card.hp??card.base_hp??0)>0;
 const points=cards.filter(card=>eligible(card)&&normalizeSynergyType(card.element)===element).length;
 const alreadyUsed=Object.entries(used).some(([key,value])=>normalizeSynergyType(key)===element&&value===true);
 const threshold=Number(rule?.min_cards??2),ready=Boolean(eligible(selected)&&rule&&points>=threshold&&!alreadyUsed);
 const label=element?element.charAt(0).toUpperCase()+element.slice(1):'';
 const reason=!selected?'Pilih satu kartu Active sebagai sumber Synergy.':!eligible(selected)?'Pilih kartu Active yang belum exhausted dan belum KO.':!rule?`Synergy ${label} belum diaktifkan pada aturan battle ini.`:alreadyUsed?`Synergy ${label} sudah dipakai pada match ini. Jatahnya sekali per tipe.`:points<threshold?`Baru ${points} dari ${threshold} kartu Active ${label} yang siap. Kartu Bench dan Graveyard tidak dihitung.`:'';
 return {icon:rule?.icon||'✧',name:rule?.name||'Synergy',element,points,threshold,reason,supported:!!rule,used:alreadyUsed,ready,
  summary:selected?`${points} kartu Active ${label} · minimal ${threshold}`:'Pilih kartu sumber untuk melihat jumlah dan efeknya.',
  status:!selected?'Pilih kartu':!eligible(selected)?'Kartu tidak siap':!rule?'Tidak diaktifkan':alreadyUsed?'Sudah dipakai':points<threshold?`${points}/${threshold} kartu`:'Siap',
  effect:!selected?'Pilih kartu Active untuk melihat Synergy.':!eligible(selected)?'Pilih kartu Active yang belum exhausted dan belum KO.':!rule?'Synergy tipe ini tidak diaktifkan pada battle ini.':effectSummary(rule,Math.max(2,Math.min(4,points))),
  detail:rule?`Hanya kartu Active yang hidup dan belum exhausted. Sekali per tipe dalam satu match. ${rule.description||''}`:'',
 };
}
export const ruleCode=name=>String(name??'').toLowerCase().normalize('NFKD').replace(/[^a-z0-9]+/g,'_').replace(/^_+|_+$/g,'').slice(0,64);
