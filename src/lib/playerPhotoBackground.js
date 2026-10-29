// Selfie segmentation runs on-device. Vite ships matching, pinned WASM assets;
// no user photograph is sent to the model provider.
let segmenterPromise;
const paint=()=>new Promise(resolve=>requestAnimationFrame(()=>resolve()));
export const foregroundAlpha=value=>{
 const x=Math.max(0,Math.min(1,(Number(value)-0.15)/0.7));
 return Math.round(x*x*(3-2*x)*255);
};
async function segmenter(){
 if(!segmenterPromise)segmenterPromise=(async()=>{
  const {FilesetResolver,ImageSegmenter}=await import('@mediapipe/tasks-vision');
  const simd=await FilesetResolver.isSimdSupported();
  const [loader,binary]=await (simd?Promise.all([
   import('@mediapipe/tasks-vision/vision_wasm_internal.js?url'),
   import('@mediapipe/tasks-vision/vision_wasm_internal.wasm?url'),
  ]):Promise.all([
   import('@mediapipe/tasks-vision/vision_wasm_nosimd_internal.js?url'),
   import('@mediapipe/tasks-vision/vision_wasm_nosimd_internal.wasm?url'),
  ]));
  return ImageSegmenter.createFromOptions({wasmLoaderPath:loader.default,wasmBinaryPath:binary.default},{baseOptions:{modelAssetPath:`${import.meta.env.BASE_URL}models/player-photo/selfie_segmenter.tflite`,delegate:'CPU'},runningMode:'IMAGE',outputConfidenceMasks:true,outputCategoryMask:false});
 })().catch(error=>{segmenterPromise=null;throw error;});
 return segmenterPromise;
}
export async function removePlayerPhotoBackground(file,{onStage=()=>{},isCancelled=()=>false}={}){
 onStage('Menyiapkan penghapus background…');await paint();
 const engine=await segmenter();if(isCancelled())return null;
 onStage('Memisahkan orang dari background…');await paint();
 const bitmap=await createImageBitmap(file);let result;
 try{
  if(isCancelled())return null;
  result=engine.segment(bitmap);
  // Square SelfieSegmenter outputs person confidence; two-channel versions
  // expose it at category 1. Copy/use the mask before closing the result.
  const mask=result.confidenceMasks?.[1]??result.confidenceMasks?.[0];
  if(!mask)throw new Error('Background belum dapat dipisahkan.');
  const confidence=mask.getAsFloat32Array();
  let foreground=0;for(const value of confidence)if(value>.6)foreground++;
  if(foreground/confidence.length<.01){const error=new Error('Orang belum terdeteksi jelas. Coba foto dengan wajah dan tubuh lebih dekat.');error.code='NO_PERSON';throw error;}
  const maskCanvas=document.createElement('canvas');maskCanvas.width=mask.width;maskCanvas.height=mask.height;
  const maskContext=maskCanvas.getContext('2d');const alpha=maskContext.createImageData(mask.width,mask.height);
  for(let i=0;i<confidence.length;i++){alpha.data[i*4]=255;alpha.data[i*4+1]=255;alpha.data[i*4+2]=255;alpha.data[i*4+3]=foregroundAlpha(confidence[i]);}
  maskContext.putImageData(alpha,0,0);
  const output=document.createElement('canvas');output.width=bitmap.width;output.height=bitmap.height;
  const context=output.getContext('2d',{alpha:true});context.drawImage(bitmap,0,0);context.globalCompositeOperation='destination-in';context.imageSmoothingEnabled=true;context.imageSmoothingQuality='high';context.drawImage(maskCanvas,0,0,output.width,output.height);
  const blob=await new Promise((resolve,reject)=>output.toBlob(value=>value?resolve(value):reject(new Error('Hasil foto belum dapat dibuat.')),'image/webp',.93));
  if(isCancelled())return null;
  return new File([blob],'player-cutout.webp',{type:blob.type,lastModified:Date.now()});
 }finally{result?.close();bitmap.close();}
}
