import { computed, onMounted, reactive, ref, watch } from 'vue';
import { supabase } from '../lib/supabase.js';
import { PILOT } from '../lib/card-generator/cardSchema.js';
import { initialArtwork, emptyBack, sanitizeWorkspace } from '../lib/card-generator/cardArtworkService.js';

export function useCardGenerator(dataset = PILOT) {
  const owner = ref(null), loading = ref(true), message = ref(''), error = ref(''), cloudBusy = ref(false);
  const workspace = reactive({ dataset_id: dataset.id, custom_cards: [], artworks: Object.fromEntries(dataset.cards.map(card => [card.card_code, initialArtwork(card.card_code)])), back: emptyBack() });
  const storageKey = computed(() => owner.value ? `tbc:card-generator:${owner.value}:${dataset.id}` : null);
  const cloudUpdatedAt = ref(null);
  const catalogLinks = ref({});
  const readLinks = async () => {
    const {data,error:err}=await supabase.from('card_studio_entries').select('card_key,game_card_id').eq('owner_id',owner.value).eq('dataset_id',dataset.id);
    if(!err)catalogLinks.value=Object.fromEntries((data??[]).map(row=>[row.card_key,row.game_card_id]));
  };
  const replace = data => Object.assign(workspace, sanitizeWorkspace(data, dataset.cards, dataset.id));
  onMounted(async () => {
    try {
      const { data: { user }, error: authError } = await supabase.auth.getUser();
      if (authError || !user) throw new Error('Login diperlukan untuk membuka generator.');
      owner.value = user.id;
      const saved = localStorage.getItem(storageKey.value);
      if (saved) replace(JSON.parse(saved));
      const {data:remote,error:cloudError}=await supabase.from('card_generator_projects').select('workspace,updated_at').eq('owner_id',user.id).eq('dataset_id',dataset.id).maybeSingle();
      const localTime=saved?JSON.parse(saved).local_updated_at:null;
      if(!cloudError&&remote&&(!saved||(localTime&&Date.parse(remote.updated_at)>Date.parse(localTime))))replace(remote.workspace);
      cloudUpdatedAt.value=remote?.updated_at??null;
      await readLinks();
    } catch (err) { error.value = err.message; }
    finally { loading.value = false; }
  });
  watch(workspace, () => {
    if (!storageKey.value || loading.value) return;
    try { localStorage.setItem(storageKey.value, JSON.stringify({...workspace,local_updated_at:new Date().toISOString()})); }
    catch { error.value = 'Draft lokal tidak tersimpan. Unduh workspace untuk menyimpan perubahan.'; }
  }, { deep: true });

  const saveCloud = async entries => {
    if (!owner.value || cloudBusy.value) return;
    cloudBusy.value = true; error.value = '';
    try {
      const { data,error: saveError } = await supabase.rpc('save_card_studio',{p_dataset:dataset.id,p_workspace:JSON.parse(JSON.stringify(workspace)),p_entries:entries});
      if (saveError) throw saveError;
      const keys=(data.entries??[]).map(entry=>entry.card_key).filter(Boolean);
      const {data:sync,error:syncError}=await supabase.rpc('sync_card_studio_battle_skills',{p_dataset:dataset.id,p_card_keys:keys});
      // During a rolling deployment the save RPC may arrive before the battle
      // sync endpoint. Never report a successfully saved card as failed.
      const syncUnavailable = syncError && /sync_card_studio_battle_skills|PGRST202/i.test(`${syncError.code ?? ''} ${syncError.message ?? ''}`);
      if (syncError && !syncUnavailable) throw syncError;
      for(const entry of data.entries??[])catalogLinks.value[entry.card_key]=entry.game_card_id;
      cloudUpdatedAt.value=data.saved_at;
      message.value = syncUnavailable
        ? `${data.entries.length} kartu tersimpan ke akun. Sinkronisasi skill battle akan aktif setelah migrasi battle dipasang.`
        : `${data.entries.length} kartu tersimpan ke akun. ${sync?.synced_slots ?? 0} skill battle tersinkron untuk Album dan RFID.${sync?.pending_slots ? ` ${sync.pending_slots} skill perlu aturan efek yang didukung.` : ''}`;
      return true;
    } catch (err) { error.value = `Kartu belum tersimpan ke akun. ${err.message || 'Periksa koneksi lalu coba lagi.'} Draft lokal tetap tersedia.`; return false; }
    finally { cloudBusy.value = false; }
  };
  const loadCloud = async () => {
    if (!owner.value || cloudBusy.value) return;
    cloudBusy.value = true; error.value = '';
    try {
      const { data, error: loadError } = await supabase.from('card_generator_projects').select('workspace,updated_at').eq('owner_id', owner.value).eq('dataset_id', dataset.id).maybeSingle();
      if (loadError) throw loadError;
      if (!data) { message.value = 'Belum ada workspace tersimpan di akun.'; return; }
      replace(data.workspace); cloudUpdatedAt.value = data.updated_at;
      await readLinks();
      message.value = 'Workspace akun dimuat. Periksa kembali artwork sebelum mencetak.';
    } catch { error.value = 'Workspace akun belum dapat dimuat. Draft perangkat ini tetap tersedia.'; }
    finally { cloudBusy.value = false; }
  };
  return { workspace, owner, loading, message, error, cloudBusy, cloudUpdatedAt, catalogLinks, replace, saveCloud, loadCloud };
}
