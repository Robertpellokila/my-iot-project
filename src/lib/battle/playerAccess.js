export const BATTLE_PLAYER_ACCESS=Symbol('battle-player-access');
export const playerAccessKey=(code,player)=>`tbc:player:${String(code).trim().toUpperCase()}:${player==='p2'?'p2':'p1'}`;
export function readPlayerAccess(code,player){try{const data=JSON.parse(sessionStorage.getItem(playerAccessKey(code,player))??'null');return typeof data?.token==='string'&&data.token?data:null;}catch{return null;}}
export function savePlayerAccess(code,player,token){sessionStorage.setItem(playerAccessKey(code,player),JSON.stringify({token}));}
export function clearPlayerAccess(code,player){sessionStorage.removeItem(playerAccessKey(code,player));}
export const privatePlayerPath=(code,player)=>`/play/${encodeURIComponent(code)}/${player==='p2'?'p2':'p1'}`;
