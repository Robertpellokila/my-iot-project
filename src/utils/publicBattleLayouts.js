export const PUBLIC_BATTLE_LAYOUTS = Object.freeze([
  { id: 'center_duel', name: 'Center Duel', description: 'Dua kartu utama di tengah, tim di kedua sisi.', detail: 'Tampilan duel klasik' },
  { id: 'top_bottom', name: 'Top vs Bottom', description: 'Dua baris tim saling berhadapan dari atas dan bawah.', detail: 'Seluruh formasi terlihat' },
  { id: 'side_panel', name: 'Side Panel HUD', description: 'Info pemain dan tim di panel samping arena.', detail: 'Mudah mengikuti strategi' },
  { id: 'stadium', name: 'Stadium Scoreboard', description: 'Papan skor besar di atas, kartu tim di tepi bawah.', detail: 'Untuk layar acara & penonton' },
]);

export const isPublicBattleLayout = (value) =>
  typeof value === 'string' && PUBLIC_BATTLE_LAYOUTS.some(layout => layout.id === value);

export const normalizePublicBattleLayout = (value) =>
  isPublicBattleLayout(value) ? value : 'center_duel';
