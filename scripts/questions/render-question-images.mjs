// Uses local Blockly's real SVG renderer. No image generation or remote assets.
import {chromium} from '@playwright/test';
import {spawn} from 'node:child_process';
import {writeFile} from 'node:fs/promises';
import {generateSeed,imageUrl} from './build-question-seed.mjs';
const rows=await generateSeed(),origin='http://127.0.0.1:5188';
const server=spawn('npm',['run','dev','--','--host','127.0.0.1','--port','5188','--strictPort'],{stdio:'ignore'});
let browser;
try {
 let ready=false;
 for(let i=0;i<100;i++){if(server.exitCode!==null)throw new Error('Vite renderer gagal dimulai (port 5188 mungkin sedang dipakai).');try{if((await fetch(origin)).ok){ready=true;break;}}catch{}await new Promise(r=>setTimeout(r,150));}
 if(!ready)throw new Error('Vite renderer belum siap.');
 browser=await chromium.launch({channel:'chrome',headless:true});const page=await browser.newPage();
 await page.goto(`${origin}/scripts/questions/render-blocks.html`);await page.waitForFunction(()=>typeof window.renderProgram==='function');
 for(const q of rows.filter(q=>q.diagram?.kind==='scratch')){
  const svg=await page.evaluate(async program=>window.renderProgram(program),q.diagram.program);
  await writeFile(`public${imageUrl(q)}`,svg+'\n'); console.log(`Rendered ${q.key}`);
 }
} finally {await browser?.close();server.kill('SIGTERM');}
