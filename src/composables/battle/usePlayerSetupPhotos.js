import {computed,onUnmounted,reactive} from 'vue';
import {compressImageFile} from '../../lib/compressImage.js';
import {supabase} from '../../lib/supabase.js';
const limits={maxSourceBytes:5*1024*1024,maxOutputBytes:1024*1024,maxDimension:800};
const emptyPhoto=()=>({file:null,originalFile:null,cutoutFile:null,preview:'',processing:false,stage:'',error:'',warning:'',removeBackground:true,backgroundRemoved:false,uploadUrl:'',uploadOwner:'',revision:0});
export function usePlayerSetupPhotos(){
 const photos=reactive({p1:emptyPhoto(),p2:emptyPhoto()});
 const processingPhotos=computed(()=>photos.p1.processing||photos.p2.processing);let disposed=false;
 const replaceFile=(photo,file,removed)=>{
  if(photo.preview)URL.revokeObjectURL(photo.preview);
  photo.file=file;photo.preview=URL.createObjectURL(file);photo.backgroundRemoved=removed;photo.uploadUrl='';photo.uploadOwner='';
 };
 const clearPhoto=player=>{const photo=photos[player],preference=photo.removeBackground;if(photo.preview)URL.revokeObjectURL(photo.preview);Object.assign(photo,emptyPhoto(),{revision:photo.revision+1,removeBackground:preference});};
 async function applyBackground(player,revision){
  const photo=photos[player],original=photo.originalFile;
  const cancelled=()=>disposed||revision!==photo.revision;
  try{
   if(!photo.removeBackground){replaceFile(photo,original,false);return;}
   if(photo.cutoutFile){replaceFile(photo,photo.cutoutFile,true);return;}
   const {removePlayerPhotoBackground}=await import('../../lib/playerPhotoBackground.js');if(cancelled())return;
   const cutout=await removePlayerPhotoBackground(original,{onStage:stage=>{if(!cancelled())photo.stage=stage;},isCancelled:cancelled});
   if(cancelled()||!cutout)return;
   photo.stage='Menyiapkan hasil foto…';const ready=await compressImageFile(cutout,limits);if(cancelled())return;
   photo.cutoutFile=ready;replaceFile(photo,ready,true);
  }catch(error){
   if(!cancelled()){replaceFile(photo,original,false);photo.warning=`${error?.code==='NO_PERSON'?error.message:'Background belum dapat dihapus.'} Foto asli tetap tersedia. Kamu bisa mencoba lagi atau memakainya.`;}
  }finally{if(!cancelled()){photo.processing=false;photo.stage='';}}
 }
 async function selectPhoto(player,file){
  if(!file)return;const photo=photos[player],revision=++photo.revision;
  photo.processing=true;photo.error='';photo.warning='';photo.stage='Menyiapkan foto…';
  try{
   const original=await compressImageFile(file,limits);if(disposed||revision!==photo.revision)return;
   photo.originalFile=original;photo.cutoutFile=null;replaceFile(photo,original,false);
   await applyBackground(player,revision);
  }catch(error){if(!disposed&&revision===photo.revision){photo.error=error?.message??'Foto tidak dapat diproses. Pilih foto lain.';photo.processing=false;photo.stage='';}}
 }
 async function setRemoveBackground(player,enabled){
  const photo=photos[player];photo.removeBackground=enabled;
  if(!photo.originalFile)return;
  const revision=++photo.revision;photo.processing=true;photo.warning='';photo.error='';photo.stage='Menyiapkan foto…';await applyBackground(player,revision);
 }
 const retryBackground=player=>setRemoveBackground(player,true);
 async function uploadPhotos(userId){
  if(processingPhotos.value)throw new Error('Tunggu foto selesai diproses sebelum menyimpan battle.');
  const result={};
  for(const [index,player] of ['p1','p2'].entries()){
   const photo=photos[player];if(!photo.file)continue;photo.error='';
   if(!photo.uploadUrl||photo.uploadOwner!==userId){
    try{
     const path=`player-avatars/${userId}/${crypto.randomUUID()}.webp`;
     const {error}=await supabase.storage.from('card-images').upload(path,photo.file,{cacheControl:'31536000',contentType:'image/webp',upsert:false});if(error)throw error;
     photo.uploadUrl=supabase.storage.from('card-images').getPublicUrl(path).data.publicUrl;photo.uploadOwner=userId;
    }catch{photo.error=`Foto Player ${index+1} belum berhasil diunggah. Coba lagi atau hapus foto untuk memakai avatar bawaan.`;throw new Error(photo.error);}
   }
   result[`player${index+1}_setup_photo_url`]=photo.uploadUrl;result[`player${index+1}_avatar_url`]=photo.uploadUrl;
  }return result;
 }
 const clearPhotos=()=>{clearPhoto('p1');clearPhoto('p2');};onUnmounted(()=>{disposed=true;clearPhotos();});
 return {photos,processingPhotos,selectPhoto,clearPhoto,clearPhotos,uploadPhotos,setRemoveBackground,retryBackground};
}
