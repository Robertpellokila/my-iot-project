import {getCurrentInstance,onActivated,onDeactivated,ref,toValue,watch} from 'vue';
import {useRoute} from 'vue-router';
import {adminToastStore} from '../lib/adminNotifications.js';
export function useAdminToast(){
 const send=type=>(message,options={})=>adminToastStore.add({type,message,...options});
 return {success:send('success'),danger:send('danger'),warning:send('warning'),info:send('info'),loading:send('loading'),dismiss:adminToastStore.dismiss,update:adminToastStore.update,clear:adminToastStore.clear};
}
export function studioNoticeType(message){
 if(/belum|perlu aturan|setelah migrasi|gagal/i.test(message))return 'warning';
 return /template dipilih|dibuka|draft|sebagai draft|tidak memakai RFID|workspace.*dimuat/i.test(message)?'info':'success';
}
// Bridge existing feedback refs so every admin page uses one host. Inline form
// feedback stays available; there is no network or DOM-message interception.
export function adminErrorType(message){return /tersimpan.*(?:tetapi|namun|tapi)|sudah berubah|UID.*sudah (?:terdaftar|terhubung|digunakan)/i.test(message)?'warning':'danger';}
export function useAdminFeedback({error,success,warning,info,message,messageType=studioNoticeType,errorType=adminErrorType,scope='admin',enabled}={}){
 const instance=getCurrentInstance(),route=instance?useRoute():null,active=ref(true);
 if(instance){onActivated(()=>active.value=true);onDeactivated(()=>active.value=false);}
 const allowed=()=>active.value&&(enabled?toValue(enabled):!route||route.path.startsWith('/admin')||route.name==='login');
 for(const [source,type] of [[error,'danger'],[success,'success'],[warning,'warning'],[info,'info'],[message,null]]){
  if(!source)continue;
  watch(()=>toValue(source),value=>{if(!value||!allowed())return;adminToastStore.add({type:type==='danger'?errorType(String(value)):type??messageType(String(value)),message:value,key:`${scope}:${type??'message'}`});},{flush:'sync'});
 }
 return useAdminToast();
}
