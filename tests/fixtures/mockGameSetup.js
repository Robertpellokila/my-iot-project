import {battleEndpoint} from './mockPlayerBattle.js';
export async function mockGameSetup(page){
 const user={id:'00000000-0000-4000-8000-000000000001',aud:'authenticated',role:'authenticated',email:'photo-tools@example.invalid',app_metadata:{provider:'email'},user_metadata:{},created_at:'2026-01-01T00:00:00Z'};
 const token=`${Buffer.from(JSON.stringify({alg:'HS256',typ:'JWT'})).toString('base64url')}.${Buffer.from(JSON.stringify({sub:user.id,role:'authenticated',exp:Math.floor(Date.now()/1000)+3600})).toString('base64url')}.test`;
 await page.addInitScript(({key,user,token})=>localStorage.setItem(key,JSON.stringify({access_token:token,refresh_token:'test',expires_at:Math.floor(Date.now()/1000)+3600,user})),{key:`sb-${new URL(battleEndpoint).hostname.split('.')[0]}-auth-token`,user,token});
 const saved=[],uploads=[];
 await page.route(`${battleEndpoint}/**`,async route=>{
  const request=route.request(),url=new URL(request.url()),resource=url.pathname.split('/').at(-1);
  if(resource==='user')return route.fulfill({json:user});if(resource==='profiles')return route.fulfill({json:{...user,role:'admin'}});
  if(url.pathname.startsWith('/storage/v1/object/card-images/')){let bytes=request.postDataBuffer();if(request.headers()['content-type']?.startsWith('multipart/form-data')){const form=await new Request('http://photo.test',{method:'POST',headers:{'content-type':request.headers()['content-type']},body:bytes}).formData();const image=[...form.values()].find(value=>typeof value?.arrayBuffer==='function');bytes=Buffer.from(await image.arrayBuffer());}uploads.push({path:url.pathname,bytes});return route.fulfill({json:{Key:url.pathname.split('/object/')[1]}});}
  if(resource==='coding_questions')return route.fulfill({json:[],headers:{'content-range':'0-0/10','access-control-expose-headers':'content-range'}});
  if(resource==='battle_sessions'&&request.method()==='POST'){const body=request.postDataJSON();saved.push(body);return route.fulfill({json:{...body,id:'10000000-0000-4000-8000-000000000044',player1_token:'qa-one',player2_token:'qa-two'}});}
  if(resource==='admin_battle_access')return route.fulfill({json:{player1_access_code:'K7M4Q9',player2_access_code:'D6M8R9'}});
  if(resource==='bind_battle_readers')return route.fulfill({json:{ok:true}});return route.fulfill({json:[]});
 });return {saved,uploads};
}
