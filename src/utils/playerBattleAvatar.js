// Setup photos take priority over the optional emoji identity.
export const isPlayerPhoto=value=>/^(https?:\/\/|\/(?!\/)|data:image\/(png|jpeg|webp);base64,)/i.test(String(value??'').trim());
export function playerBattleAvatar(battle,side){
 const prefix=side==='p2'?'player2':'player1';
 const setup=String(battle?.[`${prefix}_setup_photo_url`]??'').trim();
 const avatar=String(battle?.[`${prefix}_avatar_url`]??'').trim();
 return isPlayerPhoto(setup)?setup:avatar;
}
export function playerSetupPhoto(battle,side){
 const value=playerBattleAvatar(battle,side);
 return isPlayerPhoto(value)?value:'';
}
