import {test,expect} from '@playwright/test';
import {mockGameSetup} from '../fixtures/mockGameSetup.js';
test.use({launchOptions:{args:['--use-fake-device-for-media-stream','--use-fake-ui-for-media-stream']}});
const portrait='tests/fixtures/player-portrait.jpg';
async function transparency(page,selector='.setup-player-photo.p1 .setup-photo-preview img'){
 return page.locator(selector).evaluate(async img=>{
  await img.decode();const canvas=document.createElement('canvas');canvas.width=img.naturalWidth;canvas.height=img.naturalHeight;const context=canvas.getContext('2d');context.drawImage(img,0,0);const data=context.getImageData(0,0,canvas.width,canvas.height).data;
  let transparent=0,opaque=0;for(let i=3;i<data.length;i+=4){if(data[i]<10)transparent++;if(data[i]>245)opaque++;}return {transparent:transparent/(data.length/4),opaque:opaque/(data.length/4),width:canvas.width,height:canvas.height};
 });
}
test('real segmentation removes background automatically, preserves the person and uploads a transparent WebP',async({page})=>{
 const errors=[];page.on('pageerror',e=>errors.push(e.message));const api=await mockGameSetup(page);await page.goto('/admin/setup');
 const p1=page.locator('.setup-player-photo.p1');await expect(page.getByLabel('Hapus background otomatis Player 1',{exact:true})).toBeChecked();
 await page.getByLabel('Upload foto Player 1',{exact:true}).setInputFiles(portrait);await expect(p1.locator('.setup-photo-preview')).toHaveClass(/cutout/,{timeout:45000});await expect(p1).toHaveAttribute('aria-busy','false');
 const alpha=await transparency(page);expect(alpha.transparent).toBeGreaterThan(.2);expect(alpha.opaque).toBeGreaterThan(.25);expect(Math.max(alpha.width,alpha.height)).toBeLessThanOrEqual(800);expect(api.uploads).toHaveLength(0);
 await p1.screenshot({path:'test-results/player-photo-cutout-panel.png'});await page.screenshot({path:'test-results/player-photo-cutout.png',fullPage:true});await page.locator('button.create-button').click();await expect.poll(()=>api.uploads.length).toBe(1);await expect.poll(()=>api.saved.length).toBe(1);expect(api.uploads[0].bytes.subarray(0,4).toString()).toBe('RIFF');expect(api.uploads[0].bytes.subarray(8,12).toString()).toBe('WEBP');expect(api.uploads[0].bytes.length).toBeLessThan(1024*1024);
 const uploaded=await page.evaluate(async bytes=>{const bitmap=await createImageBitmap(new Blob([new Uint8Array(bytes)],{type:'image/webp'}));const canvas=document.createElement('canvas');canvas.width=bitmap.width;canvas.height=bitmap.height;const context=canvas.getContext('2d');context.drawImage(bitmap,0,0);const pixels=context.getImageData(0,0,canvas.width,canvas.height).data;bitmap.close();let transparent=0;for(let i=3;i<pixels.length;i+=4)if(pixels[i]<10)transparent++;return transparent/(pixels.length/4);},[...api.uploads[0].bytes]);expect(uploaded).toBeGreaterThan(.2);expect(errors).toEqual([]);
});
test('original/cutout toggles reuse the photo and keep the two players independent',async({page})=>{
 await mockGameSetup(page);await page.goto('/admin/setup');await page.getByLabel('Upload foto Player 1',{exact:true}).setInputFiles(portrait);const p1=page.locator('.setup-player-photo.p1');await expect(p1.locator('.setup-photo-preview')).toHaveClass(/cutout/,{timeout:45000});
 await p1.getByRole('button',{name:'Pakai foto asli',exact:true}).click();await expect(p1.locator('.setup-photo-preview')).not.toHaveClass(/cutout/);expect((await transparency(page)).transparent).toBe(0);await page.getByLabel('Hapus background otomatis Player 1',{exact:true}).check();await expect(p1.locator('.setup-photo-preview')).toHaveClass(/cutout/);
 await page.getByLabel('Hapus background otomatis Player 2',{exact:true}).uncheck();await page.getByLabel('Upload foto Player 2',{exact:true}).setInputFiles(portrait);await expect(page.locator('.setup-player-photo.p2')).toHaveAttribute('aria-busy','false');expect((await transparency(page,'.setup-player-photo.p2 .setup-photo-preview img')).transparent).toBe(0);await expect(p1.locator('.setup-photo-preview')).toHaveClass(/cutout/);
});
test('unavailable model keeps the original and offers a working retry',async({page})=>{
 await mockGameSetup(page);let blocked=true;await page.route('**/models/player-photo/selfie_segmenter.tflite',route=>blocked?route.fulfill({status:503,body:'Unavailable'}):route.continue());await page.goto('/admin/setup');await page.getByLabel('Upload foto Player 1',{exact:true}).setInputFiles(portrait);const p1=page.locator('.setup-player-photo.p1');await expect(p1.locator('.setup-photo-warning')).toContainText('Foto asli tetap tersedia',{timeout:30000});expect((await transparency(page)).transparent).toBe(0);
 blocked=false;await p1.getByRole('button',{name:'Coba hapus background lagi'}).click();await expect(p1.locator('.setup-photo-preview')).toHaveClass(/cutout/,{timeout:45000});await expect(p1.locator('.setup-photo-warning')).toHaveCount(0);
});
async function camera(page,{denied=false}={}){
 await page.route('**/__camera-portrait.jpg',route=>route.fulfill({path:portrait}));
 await page.addInitScript(({denied})=>{
  window.photoCameraTracks=[];window.photoCameraRequests=[];
  Object.defineProperty(navigator.mediaDevices,'getUserMedia',{value:async constraints=>{
   window.photoCameraRequests.push(constraints);
   if(denied)throw new DOMException('Permission denied','NotAllowedError');
   const image=new Image();image.src='/__camera-portrait.jpg';await image.decode();const canvas=document.createElement('canvas');canvas.width=640;canvas.height=800;canvas.getContext('2d').drawImage(image,0,0,640,800);const stream=canvas.captureStream(12);window.photoCameraTracks.push(...stream.getTracks());return stream;
  }});
  Object.defineProperty(navigator.mediaDevices,'enumerateDevices',{value:async()=>[{kind:'videoinput',deviceId:'front'},{kind:'videoinput',deviceId:'back'}]});
 },{denied});
}
test('camera capture uses the same automatic cutout flow and releases every camera track',async({page})=>{
 await mockGameSetup(page);await camera(page);await page.goto('/admin/setup');const p1=page.locator('.setup-player-photo.p1');await p1.getByRole('button',{name:'Ambil foto',exact:true}).click();const dialog=page.getByRole('dialog',{name:'Ambil foto Player 1',exact:true});
 await expect(dialog).toBeVisible();await expect(dialog.getByRole('button',{name:'Ambil foto',exact:true})).toBeEnabled();await dialog.getByRole('button',{name:'Ambil foto',exact:true}).click();await expect(dialog).toHaveCount(0);await expect(p1.locator('.setup-photo-preview')).toHaveClass(/cutout/,{timeout:45000});expect((await transparency(page)).transparent).toBeGreaterThan(.2);
 expect(await page.evaluate(()=>photoCameraRequests.length)).toBe(1);expect(await page.evaluate(()=>photoCameraTracks.every(track=>track.readyState==='ended'))).toBe(true);
});
test('switching camera and cancelling stop streams and do not replace the existing photo',async({page})=>{
 await mockGameSetup(page);await camera(page);await page.goto('/admin/setup');await page.getByLabel('Hapus background otomatis Player 1',{exact:true}).uncheck();await page.getByLabel('Upload foto Player 1',{exact:true}).setInputFiles(portrait);const p1=page.locator('.setup-player-photo.p1');await expect(p1).toHaveAttribute('aria-busy','false');const previous=await p1.locator('img').getAttribute('src');
 await p1.getByRole('button',{name:'Ambil foto',exact:true}).click();const dialog=page.getByRole('dialog',{name:'Ambil foto Player 1',exact:true});await dialog.getByRole('button',{name:'Ganti kamera'}).click();await expect.poll(()=>page.evaluate(()=>photoCameraRequests.length)).toBe(2);await expect(dialog.getByRole('button',{name:'Ambil foto',exact:true})).toBeEnabled();expect(await page.evaluate(()=>photoCameraTracks[0].readyState)).toBe('ended');await page.keyboard.press('Escape');await expect(dialog).toHaveCount(0);expect(await page.evaluate(()=>photoCameraTracks.every(track=>track.readyState==='ended'))).toBe(true);await expect(p1.locator('img')).toHaveAttribute('src',previous);
});
test('denied camera permission gives recovery choices and phone capture fallback',async({page})=>{
 await mockGameSetup(page);await camera(page,{denied:true});await page.goto('/admin/setup');await page.locator('.setup-player-photo.p1').getByRole('button',{name:'Ambil foto',exact:true}).click();const dialog=page.getByRole('dialog',{name:'Ambil foto Player 1',exact:true});await expect(dialog.getByRole('alert')).toContainText('Izin kamera');await expect(dialog.getByRole('button',{name:'Ambil foto',exact:true})).toBeDisabled();
 await dialog.getByLabel('Ambil foto Player 1 dengan kamera ponsel',{exact:true}).setInputFiles(portrait);await expect(dialog).toHaveCount(0);await expect(page.locator('.setup-player-photo.p1 .setup-photo-preview')).toHaveClass(/cutout/,{timeout:45000});
});
test('clearing while segmentation loads cannot resurrect a removed photo',async({page})=>{
 await mockGameSetup(page);let release;const wait=new Promise(resolve=>release=resolve);await page.route('**/models/player-photo/selfie_segmenter.tflite',async route=>{await wait;await route.continue();});await page.goto('/admin/setup');await page.getByLabel('Upload foto Player 1',{exact:true}).setInputFiles(portrait);const p1=page.locator('.setup-player-photo.p1');await expect(p1.locator('.setup-photo-note')).toContainText('Menyiapkan penghapus');
 const modelDone=page.waitForResponse(response=>response.url().includes('models/player-photo/selfie_segmenter.tflite'));await p1.getByRole('button',{name:'Hapus foto Player 1'}).click();release();await modelDone;await expect(p1).toHaveAttribute('aria-busy','false');await expect(p1.locator('.setup-photo-preview img')).toHaveCount(0);await expect(p1.locator('.setup-photo-warning')).toHaveCount(0);
});
test('mobile photo tools and camera dialog fit the viewport',async({page})=>{
 await page.setViewportSize({width:390,height:844});await mockGameSetup(page);await camera(page);await page.goto('/admin/setup');const p1=page.locator('.setup-player-photo.p1');await p1.scrollIntoViewIfNeeded();await page.screenshot({path:'test-results/player-photo-tools-mobile.png'});
 await p1.getByRole('button',{name:'Ambil foto',exact:true}).click();const dialog=page.getByRole('dialog',{name:'Ambil foto Player 1',exact:true});await expect(dialog.getByRole('button',{name:'Ambil foto',exact:true})).toBeEnabled();expect(await dialog.evaluate(el=>el.scrollWidth<=el.clientWidth+1)).toBe(true);await page.screenshot({path:'test-results/player-camera-mobile.png'});await dialog.getByRole('button',{name:'Batal',exact:true}).click();
});
test('choosing the original while the model loads cancels the cutout without losing the photo',async({page})=>{
 await mockGameSetup(page);let release;const wait=new Promise(resolve=>release=resolve);await page.route('**/models/player-photo/selfie_segmenter.tflite',async route=>{await wait;await route.continue();});await page.goto('/admin/setup');await page.getByLabel('Upload foto Player 1',{exact:true}).setInputFiles(portrait);const p1=page.locator('.setup-player-photo.p1');await expect(p1.locator('.setup-photo-note')).toContainText('Menyiapkan penghapus');
 const modelDone=page.waitForResponse(response=>response.url().includes('models/player-photo/selfie_segmenter.tflite'));await p1.getByRole('button',{name:'Pakai foto asli',exact:true}).click();await expect(p1).toHaveAttribute('aria-busy','false');release();await modelDone;await expect(page.getByLabel('Hapus background otomatis Player 1',{exact:true})).not.toBeChecked();await expect(p1.locator('.setup-photo-preview')).not.toHaveClass(/cutout/);expect((await transparency(page)).transparent).toBe(0);
});
test('backgrounding the page stops the camera but retains the phone capture input',async({page})=>{
 await mockGameSetup(page);await camera(page);await page.goto('/admin/setup');await page.locator('.setup-player-photo.p1').getByRole('button',{name:'Ambil foto',exact:true}).click();const dialog=page.getByRole('dialog',{name:'Ambil foto Player 1',exact:true});await expect(dialog.getByRole('button',{name:'Ambil foto',exact:true})).toBeEnabled();
 await page.evaluate(()=>{Object.defineProperty(document,'visibilityState',{configurable:true,value:'hidden'});document.dispatchEvent(new Event('visibilitychange'));});await expect(dialog).toBeVisible();expect(await page.evaluate(()=>photoCameraTracks.every(track=>track.readyState==='ended'))).toBe(true);
 await page.evaluate(()=>Object.defineProperty(document,'visibilityState',{configurable:true,value:'visible'}));await dialog.getByLabel('Ambil foto Player 1 dengan kamera ponsel',{exact:true}).setInputFiles(portrait);await expect(dialog).toHaveCount(0);await expect(page.locator('.setup-player-photo.p1 .setup-photo-preview')).toHaveClass(/cutout/,{timeout:45000});
});
test.describe('native browser camera integration',()=>{
 test('getUserMedia captures a native video frame and closes the camera',async({page,context})=>{
  await context.grantPermissions(['camera']);await mockGameSetup(page);await page.goto('/admin/setup');await page.getByLabel('Hapus background otomatis Player 1',{exact:true}).uncheck();const p1=page.locator('.setup-player-photo.p1');await p1.getByRole('button',{name:'Ambil foto',exact:true}).click();const dialog=page.getByRole('dialog',{name:'Ambil foto Player 1',exact:true});await expect(dialog.getByRole('button',{name:'Ambil foto',exact:true})).toBeEnabled();await page.evaluate(()=>window.nativePhotoTracks=[...document.querySelector('.photo-camera video').srcObject.getTracks()]);await dialog.getByRole('button',{name:'Ambil foto',exact:true}).click();await expect(dialog).toHaveCount(0);await expect(p1.locator('.setup-photo-preview img')).toBeVisible();await expect(p1).toHaveAttribute('aria-busy','false');expect(await page.evaluate(()=>nativePhotoTracks.every(track=>track.readyState==='ended'))).toBe(true);
 });
});
