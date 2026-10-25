import { compressImageFile } from '../compressImage.js';
import { imageUrl, placement } from './cardRenderer.js';
import { FIXED_BACK } from './cardBack.js';
import { normalizeDraft } from './cardDrafts.js';
import starterArtwork from '../../data/card-generator/starter-artwork.json' with { type: 'json' };

export const emptyArtwork = () => ({ production_status: 'artwork_required', approval_status: 'not_reviewed', version: 1,
  asset_status: 'unchecked', background: null, character: null, foreground: null, skill_icons: [null, null], render_receipt: null });
export const initialArtwork = code => starterArtwork[code]
  ? { ...emptyArtwork(), character: { ...starterArtwork[code] }, production_status: 'draft' }
  : emptyArtwork();
export const emptyBack = () => ({ id: FIXED_BACK.id, asset_status: 'unchecked' });
export const invalidateArtwork = art => { art.approval_status = 'not_reviewed'; art.render_receipt = null; art.production_status = art.character?.url ? 'draft' : 'artwork_required'; };
export const skillIconIndex = layer => /^skill-[12]-icon$/.test(layer) ? Number(layer[6]) - 1 : -1;
export function setArtworkAsset(art, layer, asset) {
  const index = skillIconIndex(layer);
  if (index >= 0) { art.skill_icons ??= [null, null]; art.skill_icons[index] = asset; }
  else if (['background','character','foreground'].includes(layer)) art[layer] = asset;
  else throw new Error('Layer artwork tidak valid.');
}
export const artworkAssets = art => [art.background, art.character, art.foreground, ...(art.skill_icons ?? [])].filter(Boolean);

export async function digestBlob(blob) {
  const bytes = await blob.arrayBuffer();
  return [...new Uint8Array(await crypto.subtle.digest('SHA-256', bytes))].map(byte => byte.toString(16).padStart(2, '0')).join('');
}
export async function uploadArtwork(file, code, layer) {
  const isIcon = skillIconIndex(layer) >= 0;
  if (!isIcon && !['background','character','foreground'].includes(layer)) throw new Error('Layer artwork tidak valid.');
  if (!(isIcon ? ['image/png','image/webp','image/jpeg'] : ['image/png', 'image/webp']).includes(file?.type)) throw new Error(isIcon ? 'Pilih ikon PNG, WebP, atau JPG.' : 'Upload artwork PNG atau WebP.');
  const { supabase } = await import('../supabase.js');
  const { data: { user }, error: authError } = await supabase.auth.getUser();
  if (authError || !user) throw new Error('Login kembali untuk mengunggah artwork.');
  const compressed = await compressImageFile(file, { maxDimension: isIcon ? 768 : 2400 });
  const bitmap = await createImageBitmap(compressed);
  const dimensions = { width: bitmap.width, height: bitmap.height }; bitmap.close();
  const sha256 = await digestBlob(compressed);
  const path = `card-generator/${user.id}/pilot-v1.1/${code}/${layer}-${crypto.randomUUID()}.webp`;
  const { error } = await supabase.storage.from('card-images').upload(path, compressed, { contentType: 'image/webp', upsert: false, cacheControl: '31536000' });
  if (error) throw new Error('Artwork belum tersimpan. Periksa koneksi dan izin upload gambar.');
  return { url: supabase.storage.from('card-images').getPublicUrl(path).data.publicUrl, path, sha256,
    ...dimensions, x: 0, y: 0, scale: 1, fit: layer === 'character' || isIcon ? 'cover' : 'contain' };
}

export async function verifyAsset(asset) {
  if (!imageUrl(asset?.url)) throw new Error('URL artwork tidak valid.');
  const response = await fetch(asset.url, { credentials: 'omit', referrerPolicy: 'no-referrer' });
  if (!response.ok) throw new Error('Artwork tidak dapat dimuat.');
  const blob = await response.blob();
  if (!['image/png', 'image/webp', 'image/jpeg'].includes(blob.type) || blob.size > 10 * 1024 * 1024) throw new Error('Asset bukan gambar raster yang didukung.');
  const hash = await digestBlob(blob);
  if (hash !== asset.sha256) throw new Error('Isi artwork berubah; upload dan review ulang diperlukan.');
  const bitmap = await createImageBitmap(blob);
  const valid = bitmap.width === asset.width && bitmap.height === asset.height; bitmap.close();
  if (!valid) throw new Error('Ukuran artwork berubah.');
  return blob;
}

export function sanitizeWorkspace(input, cards, datasetId = 'tbc-pilot-v1.1-audited-necromancer') {
  if (!input || input.dataset_id !== datasetId || typeof input.artworks !== 'object' || !input.artworks) throw new Error('Workspace bukan untuk dataset yang sedang dibuka.');
  const sanitizeLayer = layer => {
    if (!layer || !imageUrl(layer.url) || !/^[a-f0-9]{64}$/.test(layer.sha256 ?? '')) return null;
    return { url: layer.url, path: String(layer.path ?? ''), sha256: layer.sha256,
      width: Number(layer.width) || 0, height: Number(layer.height) || 0, ...placement(layer), fit: layer.fit === 'contain' ? 'contain' : 'cover' };
  };
  if (input.custom_cards && (!Array.isArray(input.custom_cards) || input.custom_cards.length > 200)) throw new Error('Maksimal 200 kartu baru per workspace.');
  const custom_cards = (input.custom_cards ?? []).map(normalizeDraft);
  if (new Set(custom_cards.map(card => card.card_code)).size !== custom_cards.length) throw new Error('Identitas kartu baru duplikat.');
  const artworks = Object.fromEntries([...cards, ...custom_cards].map(card => {
    const incoming = input.artworks[card.card_code] ?? {};
    // Add the new example to untouched legacy drafts. Explicit removal increments
    // version, so removing or replacing it is respected on the next reload.
    if (starterArtwork[card.card_code] && !incoming.character && !incoming.background && !incoming.foreground && (!incoming.version || incoming.version === 1) && incoming.approval_status !== 'approved') {
      return [card.card_code, { ...initialArtwork(card.card_code), skill_icons: [0,1].map(index => sanitizeLayer(incoming.skill_icons?.[index])) }];
    }
    return [card.card_code, { ...emptyArtwork(), version: Math.max(1, Math.min(9999, Number(incoming.version) || 1)),
      approval_status: incoming.approval_status === 'approved' ? 'approved' : 'not_reviewed',
      production_status: incoming.character ? 'draft' : 'artwork_required',
      background: sanitizeLayer(incoming.background), character: sanitizeLayer(incoming.character), foreground: sanitizeLayer(incoming.foreground),
      skill_icons: [0,1].map(index => sanitizeLayer(incoming.skill_icons?.[index])),
      // Imports and reloads must verify remote content and rendering again.
      asset_status: 'unchecked', render_receipt: null }];
  }));
  return { dataset_id: input.dataset_id, custom_cards, artworks, back: emptyBack() };
}
