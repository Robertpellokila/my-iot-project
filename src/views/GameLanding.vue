<script setup>
import SearchableSelect from "../components/SearchableSelect.vue";
import SkillIcon from "../components/battle/SkillIcon.vue";
import BattleGuide from "../components/BattleGuide.vue";
import { computed, onMounted, onBeforeUnmount, ref, watch } from "vue";
import { useRoute, useRouter } from "vue-router";
import { savePlayerAccess } from "../lib/battle/playerAccess.js";
import { supabase } from "../lib/supabase";
import { normalizeTcgType } from "../utils/tcgTypes";

const route = useRoute();
const router = useRouter();
const page = computed(() => ({ "/": "home", "/cards": "cards", "/fusion": "fusion", "/skills": "skills", "/play": "play" }[route.path] ?? "home"));
const cards = ref([]);
const featuredCards = ref([]);
const featuredLoading = ref(true);
const featuredError = ref(false);
const homeFeaturedCards = computed(() => featuredCards.value.slice(0, 8));
const featuredGroups = computed(() => [...new Set(homeFeaturedCards.value.map(card => card.landing_group || 'Pilihan Timedoor'))].map(name => ({name,cards:homeFeaturedCards.value.filter(card => (card.landing_group || 'Pilihan Timedoor') === name)})));
const recipes = ref([]);
const materials = ref([]);
const skills = ref([]);
const loading = ref(true);
const loadError = ref("");
const search = ref("");
const selectedType = ref("All");
const selectedRarity = ref("All");
const selectedSkill = ref("All");
const selectedLearningArc = ref("All");
const currentPage = ref(1);
const pageSize = 12;
const tcgTypeOptions = ["Knight", "Fire", "Water", "Forest", "Thunder", "Light", "Dark"];
const fusionSearch = ref("");
const fusionElement = ref("All");
const fusionRarity = ref("All");
const fusionAvailability = ref("All");
const fusionCurrentPage = ref(1);
const fusionPageSize = 9;
const expandedFusionRecipes = ref(new Set());
const joinMode = ref("player");
const accessCode = ref("");

const joining = ref(false);
const joinError = ref("");
const selectedCard = ref(null);
function showGuide() {
  document.getElementById('panduan')?.scrollIntoView({ block: 'start', behavior: window.matchMedia('(prefers-reduced-motion: reduce)').matches ? 'auto' : 'smooth' });
}

const cardById = computed(() => new Map(cards.value.map((card) => [String(card.id), card])));
const canonicalCardCode = (value) => String(value ?? "").trim().replace(/[-_]/g, "").toLowerCase();
const cardByCode = computed(() => {
  const index = new Map();
  for (const card of cards.value) {
    for (const code of [card.card_code, card.metadata?.studio_card?.display_code, card.metadata?.source_card_code]) {
      const key = canonicalCardCode(code);
      if (key) index.set(key, card);
    }
  }
  return index;
});
const activeSkills = computed(() => skills.value.filter((skill) =>
  skill.is_active === true
  && skill.catalog_status === "active"
  && String(skill.metadata?.catalog_only ?? "false").toLowerCase() !== "true",
));
const skillCurrentPage = ref(1);
const skillPageSize = 12;
const skillPageCount = computed(() => Math.max(1, Math.ceil(activeSkills.value.length / skillPageSize)));
const visibleSkills = computed(() => activeSkills.value.slice((skillCurrentPage.value - 1) * skillPageSize, skillCurrentPage.value * skillPageSize));
const setSkillPage = pageNumber => { skillCurrentPage.value = Math.max(1, Math.min(skillPageCount.value, pageNumber)); };
// Refreshes temporarily clear skill rows; clamp only after the load completes.
watch([skillPageCount, loading], ([count, waiting]) => { if (!waiting && skillCurrentPage.value > count) skillCurrentPage.value = count; });
const fusionResultIds = computed(() => new Set(recipes.value.map((recipe) => String(recipe.result_game_card_id))));
const normalCards = computed(() => cards.value.filter(card => !card.fusion_only && !fusionResultIds.value.has(String(card.id))));
const typeFilters = computed(() => ["All", ...tcgTypeOptions]);
const uniqueCardValues = (readValue, compare = (a, b) => a.localeCompare(b)) => {
  const values = new Map();
  for (const card of normalCards.value) {
    const label = String(readValue(card) ?? "").trim();
    const key = label.toLocaleLowerCase();
    if (label && !values.has(key)) values.set(key, label);
  }
  return [...values.values()].sort(compare);
};
const rarityFilters = computed(() => ["All", ...uniqueCardValues((card) => card.rarity)]);
const learningArcFilters = computed(() => ["All", ...uniqueCardValues((card) => card.metadata?.learning_arc)]);
const skillFilters = computed(() => {
  const values = new Map();
  for (const card of normalCards.value) {
    for (const skill of skillsForCard(card)) {
      const label = String(skill.name ?? "").trim();
      const key = label.toLocaleLowerCase();
      if (label && !values.has(key)) values.set(key, label);
    }
  }
  return ["All", ...[...values.values()].sort((a, b) => a.localeCompare(b))];
});
const filteredCards = computed(() => {
  const term = search.value.trim().toLocaleLowerCase();
  return normalCards.value.filter((card) => {
    const cardSkills = skillsForCard(card);
    return (selectedType.value === "All" || normalizeTcgType(card.element) === normalizeTcgType(selectedType.value))
      && (selectedRarity.value === "All" || String(card.rarity ?? "").toLowerCase() === selectedRarity.value.toLowerCase())
      && (selectedSkill.value === "All" || cardSkills.some((skill) => String(skill.name ?? "").toLowerCase() === selectedSkill.value.toLowerCase()))
      && (selectedLearningArc.value === "All" || String(card.metadata?.learning_arc ?? "").toLowerCase() === selectedLearningArc.value.toLowerCase())
      && (!term || `${card.name} ${card.element} ${card.card_code}`.toLocaleLowerCase().includes(term));
  });
});
const pageCount = computed(() => Math.max(1, Math.ceil(filteredCards.value.length / pageSize)));
const visibleCards = computed(() => filteredCards.value.slice((currentPage.value - 1) * pageSize, currentPage.value * pageSize));
const setPage = (pageNumber) => { currentPage.value = Math.max(1, Math.min(pageCount.value, pageNumber)); };
watch([search, selectedType, selectedRarity, selectedSkill, selectedLearningArc], () => { currentPage.value = 1; });
watch(pageCount, (count) => { if (currentPage.value > count) currentPage.value = count; });
const skillsForCard = card => Array.isArray(card.skills) ? card.skills : [];
const skillForCard = (card) => skillsForCard(card)[0] ?? null;
const recipesForCard = (card) => recipes.value.filter((recipe) => {
  const result = cardById.value.get(String(recipe.result_game_card_id));
  return String(recipe.result_game_card_id) === String(card.id) ||
    (result && String(result.name ?? "").trim().toLocaleLowerCase() === String(card.name ?? "").trim().toLocaleLowerCase());
});
const fusionEntries = computed(() => cards.value
  .filter(card => card.fusion_only || fusionResultIds.value.has(String(card.id)))
  .map(card => ({card,recipes:recipes.value.filter(recipe=>String(recipe.result_game_card_id)===String(card.id))})));
const recipeParts = (recipe) => materials.value.filter((item) => String(item.recipe_id) === String(recipe.id)).map((item) => {
  const qty = Math.max(1, Number(item.quantity ?? 1));
  if (item.material_type === "exact_card") return {
    quantityLabel: `${qty}×`,
    title: cardByCode.value.get(canonicalCardCode(item.card_code))?.name ?? item.card_code ?? "Kartu",
    detail: "Kartu ini wajib digunakan",
  };
  if (item.material_type === "one_of") {
    const codes = Array.isArray(item.card_codes) ? item.card_codes : [];
    const options = codes.map((code) => cardByCode.value.get(canonicalCardCode(code))?.name ?? code);
    return {
      quantityLabel: `PILIH ${qty}`,
      title: "Kartu dari pilihan berikut",
      detail: options.join(" atau ") || "Belum ada pilihan kartu",
    };
  }
  if (item.material_type === "element") return {
    quantityLabel: `${qty}×`,
    title: `Kartu elemen ${item.element ?? "apa saja"}`,
    detail: "Kartu dengan elemen ini dapat digunakan",
  };
  if (item.material_type === "tag") {
    const sourceCodes = Array.isArray(item.metadata?.source_candidate_codes)
      ? item.metadata.source_candidate_codes
      : [];
    const sourceNames = sourceCodes.map((code) => {
      return cardByCode.value.get(canonicalCardCode(code))?.name ?? code;
    });
    return {
      quantityLabel: `PILIH ${qty}`,
      title: `Kartu dengan tag “${item.tag ?? "khusus"}”`,
      detail: sourceNames.length ? `Contoh kartu: ${sourceNames.join(" atau ")}` : "Gunakan kartu yang memiliki tag ini",
    };
  }
  return {
    quantityLabel: `${qty}×`,
    title: `Material ${item.material_type ?? "kartu"}`,
    detail: "Ikuti aturan material pada battle",
  };
});
const fusionRecipeLines = (entry) => entry.recipes.map((recipe, index) => ({
  id: recipe.id,
  label: entry.recipes.length > 1 ? `Resep ${index + 1}` : "Material",
  parts: recipeParts(recipe),
}));
const primaryRecipeParts = (entry) => recipeParts(entry.recipes[0] ?? {});
const isFusionRecipeExpanded = (cardId) => expandedFusionRecipes.value.has(String(cardId));
const toggleFusionRecipe = (cardId) => {
  const key = String(cardId);
  const next = new Set(expandedFusionRecipes.value);
  if (next.has(key)) next.delete(key);
  else next.add(key);
  expandedFusionRecipes.value = next;
};
const fusionElementFilters = computed(() => ["All", ...tcgTypeOptions]);
const fusionRarityFilters = computed(() => ["All", ...[...new Set(fusionEntries.value.map(({ card }) => String(card.rarity ?? "").trim()).filter(Boolean))].sort((a, b) => a.localeCompare(b))]);
const filteredFusionEntries = computed(() => {
  const term = fusionSearch.value.trim().toLocaleLowerCase();
  return fusionEntries.value.filter((entry) => {
    const parts = entry.recipes.flatMap((recipe) => recipeParts(recipe));
    const searchText = [
      entry.card.name,
      entry.card.card_code,
      entry.card.element,
      entry.card.rarity,
      ...entry.recipes.flatMap((recipe) => [recipe.name, recipe.code]),
      ...parts.flatMap((part) => [part.title, part.detail]),
    ].join(" ").toLocaleLowerCase();
    const availabilityMatch = fusionAvailability.value === "All"
      || (fusionAvailability.value === "active" && entry.recipes.some((recipe) => recipe.is_active))
      || (fusionAvailability.value === "preview" && entry.recipes.every((recipe) => !recipe.is_active));
    return (fusionElement.value === "All" || normalizeTcgType(entry.card.element) === normalizeTcgType(fusionElement.value))
      && (fusionRarity.value === "All" || String(entry.card.rarity ?? "").toLowerCase() === fusionRarity.value.toLowerCase())
      && availabilityMatch
      && (!term || searchText.includes(term));
  });
});
const fusionPageCount = computed(() => Math.max(1, Math.ceil(filteredFusionEntries.value.length / fusionPageSize)));
const visibleFusionEntries = computed(() => filteredFusionEntries.value.slice((fusionCurrentPage.value - 1) * fusionPageSize, fusionCurrentPage.value * fusionPageSize));
const setFusionPage = (pageNumber) => { fusionCurrentPage.value = Math.max(1, Math.min(fusionPageCount.value, pageNumber)); };
watch([fusionSearch, fusionElement, fusionRarity, fusionAvailability], () => { fusionCurrentPage.value = 1; });
watch(fusionPageCount, (count) => { if (fusionCurrentPage.value > count) fusionCurrentPage.value = count; });
const recipeSummary = (recipe) => recipeParts(recipe)
  .map((part) => `${part.quantityLabel} ${part.title}${part.detail ? ` (${part.detail})` : ""}`)
  .join(" · ");
const visualToken = (value) => String(value ?? "")
  .trim()
  .toLocaleLowerCase()
  .normalize("NFD")
  .replace(/[\u0300-\u036f]/g, "")
  .replace(/[^a-z0-9]+/g, "-")
  .replace(/^-|-$/g, "") || "unknown";
const canonicalElement = (element) => ({
  electric: "thunder", lightning: "thunder", wind: "thunder",
  grass: "forest", nature: "forest", ice: "water", holy: "light",
  warrior: "knight", shadow: "dark",
}[visualToken(element)] ?? visualToken(element));
const elementClass = (element) => `element-${canonicalElement(element)}`;
const rarityClass = (rarity) => `rarity-${visualToken(rarity)}`;
const elementIcon = (element) => ({
  knight: "🛡️", fire: "🔥", water: "💧", forest: "🌿", thunder: "⚡",
  light: "✨", dark: "🌑", neutral: "◉",
}[canonicalElement(element)] ?? "✦");
const rarityIcon = (rarity) => ({
  common: "●", uncommon: "◆", rare: "★", epic: "✦", legendary: "✹", mythic: "◈",
}[visualToken(rarity)] ?? "◇");
const isImageUrl = (value) => /^https?:|^\//i.test(String(value ?? "").trim());
const physicalCardImageUrl = (card) => isImageUrl(card?.physical_card_image_url)
  ? String(card.physical_card_image_url).trim()
  : "";

// Every public route uses the same opt-in publication RPC. No fallback to the full catalog.
let catalogRequest=0, refreshTimer;
const publicFusionRecipeKey = (card) => [
  canonicalCardCode(card?.metadata?.studio_card?.display_code || card?.card_code),
  String(card?.name ?? '').trim().toLowerCase(),
].filter(Boolean);
const loadPublicFusionRecipes = async (published) => {
  const projection = await supabase.rpc('get_landing_fusion_recipes');
  if (!projection.error) return Array.isArray(projection.data) ? projection.data : [];

  // Migration 035 adds the narrower projection above. This compatibility path
  // keeps already-published Studio Fusion cards usable until every environment
  // has the migration, then discards every recipe without a public match.
  const publicFusion = published.filter(card => card.fusion_only);
  if (!publicFusion.length) return [];
  const byKey = new Map(publicFusion.flatMap(card => publicFusionRecipeKey(card).map(key => [key, card])));
  const candidates = await supabase.from('fusion_recipes')
    .select('id,name,code,result_game_card_id,is_active,priority,result_card:game_cards!fusion_recipes_result_game_card_id_fkey(name,card_code)')
    .order('priority');
  if (candidates.error) throw projection.error;
  const matched = (candidates.data ?? []).flatMap(recipe => {
    const source = recipe.result_card;
    const card = byKey.get(canonicalCardCode(source?.card_code)) || byKey.get(String(source?.name ?? '').trim().toLowerCase());
    return card ? [{...recipe,result_game_card_id:card.id}] : [];
  });
  const recipeIds = matched.map(recipe => recipe.id);
  if (!recipeIds.length) return matched;
  const materialResult = await supabase.from('fusion_recipe_materials')
    .select('id,recipe_id,material_type,quantity,card_code,card_codes,element,tag,metadata')
    .in('recipe_id',recipeIds);
  if (materialResult.error) throw materialResult.error;
  const materialByRecipe = new Map();
  for (const material of materialResult.data ?? []) {
    const items = materialByRecipe.get(material.recipe_id) ?? [];
    items.push(material); materialByRecipe.set(material.recipe_id, items);
  }
  return matched.map(recipe => ({...recipe,materials:materialByRecipe.get(recipe.id) ?? []}));
};
const loadFeatured = async () => {
 const request=++catalogRequest;
 loading.value=true;featuredLoading.value=true;featuredError.value=false;loadError.value='';
 try {
  const {data,error}=await supabase.rpc('get_landing_cards');if(error)throw error;
  if(request!==catalogRequest)return;
  const published=Array.isArray(data)?data:[];
  cards.value=published;featuredCards.value=published;
  if(selectedCard.value)selectedCard.value=published.find(card=>card.id===selectedCard.value.id)??null;
  recipes.value=[];materials.value=[];skills.value=[];
  const ids=published.map(card=>card.id);
  const skillIds=[...new Set(published.flatMap(card=>(card.skills??[]).filter(skill=>skill.id&&!skill.metadata?.catalog_only).map(skill=>skill.id)))];
  const [recipeData,skillResult]=await Promise.all([
   loadPublicFusionRecipes(published),
   skillIds.length?supabase.from('special_skills').select('id,name,description,icon,skill_type,activation_timing,cost_spec,limits,is_active,catalog_status,metadata').in('id',skillIds).order('name'):Promise.resolve({data:[]}),
  ]);
  if(request!==catalogRequest)return;
  if(skillResult.error)throw skillResult.error;
  recipes.value=recipeData.filter(recipe=>ids.includes(recipe.result_game_card_id));
  skills.value=(skillResult.data??[]).filter(skill=>skillIds.includes(skill.id));
  materials.value=recipes.value.flatMap(recipe=>Array.isArray(recipe.materials)?recipe.materials:[]);
 } catch(error){
  if(request!==catalogRequest)return;
  // Drop stale cards after a failed refresh; a revoked publication must not linger.
  cards.value=[];featuredCards.value=[];recipes.value=[];materials.value=[];skills.value=[];selectedCard.value=null;
  loadError.value='Katalog publik belum dapat dimuat. Coba lagi.';featuredError.value=true;
 } finally {if(request===catalogRequest){loading.value=false;featuredLoading.value=false;}}
};
const refreshVisible=()=>{if(document.visibilityState==='visible')loadFeatured();};
watch(page,()=>{skillCurrentPage.value=1;loadFeatured();});
onMounted(()=>{loadFeatured();window.addEventListener('focus',refreshVisible);document.addEventListener('visibilitychange',refreshVisible);refreshTimer=setInterval(refreshVisible,30000);});
onBeforeUnmount(()=>{catalogRequest++;clearInterval(refreshTimer);window.removeEventListener('focus',refreshVisible);document.removeEventListener('visibilitychange',refreshVisible);});

const openCard = (card) => { selectedCard.value = card; };
const playNow = () => router.push("/play");
const joinGame = async () => {
  const entered = accessCode.value.trim();
  if (!entered) { joinError.value = "Masukkan kode untuk melanjutkan."; return; }
  joining.value = true;
  joinError.value = "";
  try {
    if (joinMode.value === "battle") {
      const {data,error}=await supabase.rpc('get_public_battle_state',{p_code:entered.toUpperCase()});
      if(error)throw error;if(!data?.ok)throw new Error(data?.message||'Battle tidak tersedia.');
      await router.push(`/battle/${encodeURIComponent(data.battle.code)}`);return;
    }
    const {data,error}=await supabase.rpc('redeem_battle_player_code',{p_access_code:entered});
    if(error)throw error;if(!data?.ok)throw new Error(data?.message||'Kode pribadi tidak valid.');
    savePlayerAccess(data.code,data.player,data.token);
    await router.push({name:'player-battle',params:{code:data.code,player:data.player}});
  } catch (error) { joinError.value = error?.message ?? "Tidak dapat membuka battle."; }
  finally { joining.value = false; }
};
</script>

<template>
  <main class="timedoor-site">
    <header class="site-nav">
      <RouterLink class="wordmark" to="/"><span class="td-symbol">t</span><span>timedoor<small>BATTLE CARD</small></span></RouterLink>
      <nav aria-label="Navigasi utama"><RouterLink to="/" :class="{ active: page === 'home' }">Home</RouterLink><RouterLink to="/cards" :class="{ active: page === 'cards' }">Kartu</RouterLink><RouterLink to="/fusion" :class="{ active: page === 'fusion' }">Fusion</RouterLink><RouterLink to="/skills" :class="{ active: page === 'skills' }">Skill</RouterLink></nav>
      <RouterLink class="nav-play" to="/play">Masuk battle <span>↗</span></RouterLink>
    </header>

    <section v-if="page === 'home'" class="hero">
      <div class="hero-copy"><span class="eyebrow">TIMEDOOR ACADEMY · CARD BATTLE</span><h1>Belajar strategi.<br><em>Menangkan battle.</em></h1><p>Kumpulkan kartu, temukan resep fusion, dan susun langkahmu. Pilih kartu favorit sebelum masuk arena.</p><div class="hero-actions"><button @click="playNow">Mainkan battle <span>→</span></button><button type="button" class="guide-link" @click="showGuide">Panduan bermain ↓</button><RouterLink to="/cards">Lihat semua kartu <b>↗</b></RouterLink></div><div class="hero-counts"><span><b>{{ normalCards.length }}</b> kartu</span><i></i><span><b>{{ recipes.length }}</b> fusion</span><i></i><span><b>{{ activeSkills.length }}</b> skill battle</span></div></div>
      <div class="hero-scene" aria-hidden="true"><div class="scene-shape shape-star">✦</div><div class="scene-shape shape-code">‹ ›</div><div class="scene-card card-shadow">TD</div><div class="scene-card card-main"><span>✦</span><b>TIMEDOOR<br>CHAMPION</b><small>STRATEGY STARTS HERE</small></div><div class="scene-chip chip-yellow">PLAY SMART</div><div class="scene-chip chip-blue">FUSION READY</div></div>
      <div class="hero-bottom">ONE-STOP EDUTECH CENTER FOR KIDS AND TEENS <span>✦</span></div>
    </section>

    <section v-if="page === 'home'" class="featured-section" aria-labelledby="featured-title">
      <header><div><span class="eyebrow">THE CARD COLLECTION</span><h2 id="featured-title">Temukan kartu andalanmu.</h2></div><RouterLink to="/cards">Jelajahi katalog ↗</RouterLink></header>
      <p v-if="!featuredLoading && !featuredError && featuredCards.length" class="featured-limit-note">Menampilkan {{ homeFeaturedCards.length }} kartu pilihan. Jelajahi menu Kartu dan Fusion untuk koleksi lainnya.</p>
      <p v-if="featuredLoading" role="status">Memuat kartu pilihan…</p>
      <div v-else-if="featuredError" role="status">Kartu pilihan belum dapat dimuat. <button @click="loadFeatured">Coba lagi</button></div>
      <p v-else-if="!featuredCards.length">Koleksi pilihan sedang disiapkan.</p>
      <section v-for="group in featuredGroups" v-else :key="group.name" class="featured-group"><h3>{{ group.name }}</h3><div class="featured-grid">
        <button v-for="card in group.cards" :key="card.id" class="featured-card" @click="openCard(card)">
          <div class="featured-art"><img v-if="isImageUrl(card.physical_card_image_url || card.image_url)" :src="card.physical_card_image_url || card.image_url" :alt="card.name" loading="lazy"><span v-else aria-hidden="true">✦</span><b v-if="card.fusion_only">FUSION</b></div>
          <div class="featured-copy"><small>{{ card.rarity }} · {{ card.element }}</small><h4>{{ card.name }}</h4><div class="featured-stats"><span>HP <b>{{ card.hp }}</b></span><span>ATK <b>{{ card.attack }}</b></span><span>DEF <b>{{ card.defense }}</b></span></div><p v-for="skill in card.skills" :key="skill.id">✦ {{ skill.name }}</p><span class="featured-detail">Lihat kartu →</span></div>
        </button>
      </div></section>
    </section>

    <BattleGuide v-if="page === 'home'" />

    <section v-if="page === 'play'" class="play-page"><div class="play-aside"><span class="eyebrow">READY PLAYER?</span><h1>Masuk ke<br><em>battle-mu.</em></h1><p>Gunakan kode pribadi dari guru untuk bermain. Kode battle hanya membuka layar penonton.</p><div class="play-mark">T<span>×</span>D</div></div><div id="join-game" class="join-card"><span class="eyebrow">PLAYER ACCESS</span><h2>Masukkan kode</h2><p>Kode pemain pribadi langsung memilih akun Player 1 atau Player 2.</p><form @submit.prevent="joinGame"><div class="mode-tabs"><button type="button" :class="{ active: joinMode === 'battle' }" @click="joinMode = 'battle'">Tonton battle</button><button type="button" :class="{ active: joinMode === 'player' }" @click="joinMode = 'player'">Kode pribadi pemain</button></div><label class="form-field"><span>{{ joinMode === 'battle' ? 'KODE BATTLE' : 'KODE PEMAIN' }}</span><input v-model="accessCode" :placeholder="joinMode === 'battle' ? 'Contoh: A7K9Q2' : 'Masukkan kode akses pemain'" autocomplete="off" required></label><button class="submit-play" :disabled="joining">{{ joining ? 'Membuka battle…' : joinMode === 'battle' ? 'Tonton pertandingan →' : 'Masuk ke game →' }}</button><p v-if="joinError" class="form-error" role="alert">{{ joinError }}</p></form><small class="privacy-note">Kode pemain bersifat pribadi. Minta kode Player 1 atau Player 2 dari penyelenggara.</small></div></section>

    <section v-if="page === 'cards'" class="catalog-page"><div class="page-intro"><span class="eyebrow">KATALOG KARTU · {{ filteredCards.length }} KARTU</span><h1>Kenali timmu.</h1><p>Pilih kartu untuk melihat statistik, skill, elemen, dan cerita lengkapnya. Kartu hasil fusion ada di halaman Fusion.</p></div><label class="search"><span>⌕</span><input v-model="search" placeholder="Cari nama, kode, atau elemen"></label><div class="type-filters" aria-label="Filter tipe kartu"><button v-for="type in typeFilters" :key="type" type="button" :class="[{ active: selectedType === type }, type !== 'All' ? elementClass(type) : '']" @click="selectedType = type">{{ type === 'All' ? 'Semua tipe' : `${elementIcon(type)} ${type}` }}</button></div><div class="catalog-select-filters" aria-label="Filter katalog kartu"><label><span>RARITY</span><SearchableSelect v-model="selectedRarity"><option v-for="rarity in rarityFilters" :key="rarity" :value="rarity">{{ rarity === 'All' ? 'Semua rarity' : rarity }}</option></SearchableSelect></label><label><span>SKILL</span><SearchableSelect v-model="selectedSkill"><option v-for="skill in skillFilters" :key="skill" :value="skill">{{ skill === 'All' ? 'Semua skill' : skill }}</option></SearchableSelect></label><label><span>LEARNING ARC</span><SearchableSelect v-model="selectedLearningArc"><option v-for="arc in learningArcFilters" :key="arc" :value="arc">{{ arc === 'All' ? 'Semua arc' : arc }}</option></SearchableSelect></label></div><div v-if="!loading && !loadError" class="catalog-legend" aria-label="Panduan warna tipe dan rarity"><div class="legend-group"><b>TIPE</b><span v-for="type in typeFilters.slice(1)" :key="type" class="legend-chip" :class="elementClass(type)"><i>{{ elementIcon(type) }}</i>{{ type }}</span></div><div class="legend-group rarity-legend"><b>RARITY</b><span v-for="rarity in rarityFilters.slice(1)" :key="rarity" class="legend-chip" :class="rarityClass(rarity)"><i>{{ rarityIcon(rarity) }}</i>{{ rarity }}</span></div></div><div v-if="loading" class="empty-state">Memuat kartu…</div><div v-else-if="loadError" class="empty-state" role="alert">{{ loadError }} <button @click="loadFeatured">Coba lagi</button></div><div v-else class="unit-grid"><button v-for="card in visibleCards" :key="card.id" class="unit-card" :class="physicalCardImageUrl(card) ? 'physical-only' : [rarityClass(card.rarity), elementClass(card.element)]" type="button" :aria-label="physicalCardImageUrl(card) ? `Lihat kartu fisik ${card.name}` : `Lihat detail ${card.name}`" @click="openCard(card)"><img v-if="physicalCardImageUrl(card)" class="physical-card-image" :src="physicalCardImageUrl(card)" :alt="`Kartu fisik ${card.name}`" loading="lazy"><template v-else><div class="unit-art"><img v-if="card.image_url && /^https?:|^\//.test(card.image_url)" :src="card.image_url" :alt="card.name" loading="lazy"><span v-else>{{ card.image_url || card.avatar_url || '✦' }}</span><b :class="elementClass(card.element)"><i>{{ elementIcon(card.element) }}</i>{{ card.element || 'NEUTRAL' }}</b><i class="rarity-chip" :class="rarityClass(card.rarity)"><span>{{ rarityIcon(card.rarity) }}</span>{{ card.rarity || 'CARD' }}</i></div><div class="unit-info"><small>{{ card.card_code || 'TIMEDOOR CARD' }}</small><h2>{{ card.name }}</h2><div class="unit-stats"><span>HP <b>{{ card.hp ?? '—' }}</b></span><span>ATK <b>{{ card.attack ?? '—' }}</b></span><span>DEF <b>{{ card.defense ?? '—' }}</b></span></div><div class="unit-skills-preview"><span v-for="(skill, skillIndex) in skillsForCard(card).slice(0, 2)" :key="skill.id || skillIndex" :title="skill.description || skill.effect || skill.name">✦ {{ skill.name }}</span><span v-if="!skillsForCard(card).length">Kartu strategi</span></div></div></template></button><div v-if="!visibleCards.length && !loading" class="empty-state">Kartu tidak ditemukan.</div></div><nav v-if="pageCount > 1" class="catalog-pagination" aria-label="Halaman kartu"><button type="button" :disabled="currentPage === 1" @click="setPage(currentPage - 1)">← Sebelumnya</button><span>Halaman <b>{{ currentPage }}</b> dari {{ pageCount }}</span><button type="button" :disabled="currentPage === pageCount" @click="setPage(currentPage + 1)">Berikutnya →</button></nav></section>

    <section v-if="page === 'fusion'" class="catalog-page fusion-page">
      <div class="page-intro"><span class="eyebrow">HASIL FUSION · {{ filteredFusionEntries.length }} DARI {{ fusionEntries.length }} KARTU</span><h1>Satukan kekuatan.</h1><p>Cari kartu hasil, pilih elemen atau rarity, lalu ikuti bahan pada setiap resep.</p></div>
      <div class="fusion-tools">
        <label class="fusion-search"><span>⌕</span><input v-model="fusionSearch" type="search" placeholder="Cari hasil, nama bahan, atau kode resep"></label>
        <div class="fusion-filters" aria-label="Filter fusion">
          <label><span>ELEMEN</span><SearchableSelect v-model="fusionElement"><option v-for="element in fusionElementFilters" :key="element" :value="element">{{ element === 'All' ? 'Semua elemen' : element }}</option></SearchableSelect></label>
          <label><span>RARITY</span><SearchableSelect v-model="fusionRarity"><option v-for="rarity in fusionRarityFilters" :key="rarity" :value="rarity">{{ rarity === 'All' ? 'Semua rarity' : rarity }}</option></SearchableSelect></label>
          <label><span>STATUS RESEP</span><SearchableSelect v-model="fusionAvailability"><option value="All">Semua resep</option><option value="active">Resep aktif</option><option value="preview">Preview saja</option></SearchableSelect></label>
        </div>
      </div>
      <div v-if="!loading" class="catalog-legend fusion-legend" aria-label="Panduan warna tipe dan rarity"><div class="legend-group"><b>TIPE</b><span v-for="element in fusionElementFilters.slice(1)" :key="element" class="legend-chip" :class="elementClass(element)"><i>{{ elementIcon(element) }}</i>{{ element }}</span></div><div class="legend-group rarity-legend"><b>RARITY</b><span v-for="rarity in fusionRarityFilters.slice(1)" :key="rarity" class="legend-chip" :class="rarityClass(rarity)"><i>{{ rarityIcon(rarity) }}</i>{{ rarity }}</span></div></div>
      <div v-if="loading" class="empty-state">Memuat resep…</div>
      <div v-else-if="loadError" class="empty-state" role="alert">{{ loadError }} <button @click="loadFeatured">Coba lagi</button></div><div v-else class="fusion-grid">
        <article v-for="entry in visibleFusionEntries" :key="entry.card.id" class="fusion-recipe">
          <header class="recipe-heading" :class="[rarityClass(entry.card.rarity), elementClass(entry.card.element)]">
            <div class="recipe-meta"><span class="recipe-kicker">FUSION FORGE</span><span class="recipe-badge">{{ entry.recipes.length }} resep</span><span v-if="entry.recipes.some(recipe => !recipe.is_active)" class="recipe-badge preview-label">Preview</span></div>
            <h2 class="recipe-title" :title="entry.card.name">{{ entry.card.name }}</h2>
            <div class="identity-chips"><span class="identity-chip" :class="elementClass(entry.card.element)"><i>{{ elementIcon(entry.card.element) }}</i>{{ entry.card.element || 'Netral' }}</span><span class="identity-chip" :class="rarityClass(entry.card.rarity)"><i>{{ rarityIcon(entry.card.rarity) }}</i>{{ entry.card.rarity || 'Rarity belum diatur' }}</span></div>
          </header>
          <div class="fusion-flow">
            <section class="fusion-ingredients">
              <span class="fusion-stage-label">BAHAN YANG DIPERLUKAN</span>
              <ul v-if="primaryRecipeParts(entry).length" class="material-list material-list--compact"><li v-for="(part, index) in primaryRecipeParts(entry).slice(0, 3)" :key="index"><b class="material-quantity">{{ part.quantityLabel }}</b><span><strong>{{ part.title }}</strong><small>{{ part.detail }}</small></span></li></ul>
              <p v-else class="no-materials">Bahan resep belum tersedia.</p>
            </section>
            <span class="fusion-transform" aria-hidden="true"><i>+</i><b>FUSE</b><em>→</em></span>
            <button class="fusion-result-card" :class="[rarityClass(entry.card.rarity), elementClass(entry.card.element)]" type="button" @click="openCard(entry.card)">
              <span class="result-art"><img v-if="physicalCardImageUrl(entry.card) || isImageUrl(entry.card.image_url)" :src="physicalCardImageUrl(entry.card) || entry.card.image_url" :alt="entry.card.name" loading="lazy"><span v-else class="result-emoji">{{ entry.card.image_url || '✦' }}</span></span>
              <span class="result-copy"><small>HASIL FUSION</small><strong>{{ entry.card.name }}</strong><span class="result-stats"><b>HP {{ entry.card.hp ?? '—' }}</b><b>ATK {{ entry.card.attack ?? '—' }}</b><b>DEF {{ entry.card.defense ?? '—' }}</b></span><em>Lihat kartu lengkap →</em></span>
            </button>
          </div>
          <button
            class="recipe-disclosure"
            type="button"
            :aria-expanded="isFusionRecipeExpanded(entry.card.id)"
            :aria-controls="`fusion-material-${entry.card.id}`"
            @click="toggleFusionRecipe(entry.card.id)"
          >
            <span>{{ isFusionRecipeExpanded(entry.card.id) ? 'Sembunyikan rincian resep' : 'Lihat seluruh resep & material' }}</span>
            <small>{{ entry.recipes.length }} resep</small>
            <b :class="{ expanded: isFusionRecipeExpanded(entry.card.id) }" aria-hidden="true">⌄</b>
          </button>
          <div v-if="isFusionRecipeExpanded(entry.card.id)" :id="`fusion-material-${entry.card.id}`" class="fusion-material-list">
            <section v-for="recipeLine in fusionRecipeLines(entry)" :key="recipeLine.id" class="recipe-option">
              <div class="recipe-option-heading"><strong>{{ recipeLine.label }}</strong><span v-if="entry.recipes.length > 1">Gunakan semua bahan di resep ini</span><span v-else>Yang perlu disiapkan</span></div>
              <ul v-if="recipeLine.parts.length" class="material-list"><li v-for="(part, index) in recipeLine.parts" :key="index"><b class="material-quantity">{{ part.quantityLabel }}</b><span><strong>{{ part.title }}</strong><small>{{ part.detail }}</small></span></li></ul>
              <p v-else class="no-materials">Belum ada bahan yang tercatat.</p>
            </section>
          </div>
        </article>
        <div v-if="!visibleFusionEntries.length && !loading" class="empty-state fusion-empty">Tidak ada hasil yang cocok. Coba kata kunci atau filter lain.</div>
      </div>
      <nav v-if="fusionPageCount > 1" class="catalog-pagination" aria-label="Halaman fusion"><button type="button" :disabled="fusionCurrentPage === 1" @click="setFusionPage(fusionCurrentPage - 1)">← Sebelumnya</button><span>Halaman <b>{{ fusionCurrentPage }}</b> dari {{ fusionPageCount }}</span><button type="button" :disabled="fusionCurrentPage === fusionPageCount" @click="setFusionPage(fusionCurrentPage + 1)">Berikutnya →</button></nav>
    </section>

    <section v-if="page === 'skills'" class="catalog-page">
      <div class="page-intro"><span class="eyebrow">TAKTIK DAN KEMAMPUAN</span><h1>Gunakan skill-mu.</h1><p>Pelajari efek dan biaya setiap skill sebelum battle dimulai.</p></div>
      <div v-if="loading" class="empty-state">Memuat skill…</div>
      <div v-else-if="loadError" class="empty-state" role="alert">{{ loadError }} <button @click="loadFeatured">Coba lagi</button></div>
      <template v-else>
        <div class="skills-grid"><article v-for="skill in visibleSkills" :key="skill.id" class="skill-card"><span class="skill-icon"><SkillIcon :icon="skill.icon" :name="skill.name" /></span><div><small>{{ skill.skill_type || 'SPECIAL SKILL' }}</small><h2>{{ skill.name }}</h2><p>{{ skill.description || 'Skill khusus untuk mengubah jalannya battle.' }}</p><div class="skill-details"><span>{{ skill.activation_timing || 'Saat giliranmu' }}</span><span v-if="skill.cost_spec?.type">Biaya: {{ skill.cost_spec.type }} {{ skill.cost_spec.value ?? '' }}</span><span v-if="skill.limits?.cooldown_turns">Cooldown {{ skill.limits.cooldown_turns }} giliran pemilik</span><span v-else-if="skill.limits?.cooldown_rounds">Cooldown {{ skill.limits.cooldown_rounds }} ronde</span></div></div></article><div v-if="!activeSkills.length" class="empty-state">Belum ada skill aktif.</div></div>
        <nav v-if="skillPageCount > 1" class="catalog-pagination" aria-label="Halaman skill">
          <button type="button" :disabled="skillCurrentPage === 1" @click="setSkillPage(skillCurrentPage - 1)">← Sebelumnya</button>
          <span aria-live="polite">Halaman <b>{{ skillCurrentPage }}</b> dari {{ skillPageCount }} · {{ activeSkills.length }} skill</span>
          <button type="button" :disabled="skillCurrentPage === skillPageCount" @click="setSkillPage(skillCurrentPage + 1)">Berikutnya →</button>
        </nav>
      </template>
    </section>

    <footer class="site-footer"><RouterLink class="wordmark" to="/"><span class="td-symbol">t</span><span>timedoor<small>BATTLE CARD</small></span></RouterLink><span>One-stop Edutech Center for Kids and Teens</span><RouterLink to="/play">Masuk battle →</RouterLink></footer>

    <div v-if="selectedCard" class="modal-backdrop" role="presentation" @click.self="selectedCard = null" @keydown.esc="selectedCard = null">
      <section class="card-modal" role="dialog" aria-modal="true" :aria-label="`Detail ${selectedCard.name}`">
        <button class="modal-close" aria-label="Tutup" @click="selectedCard = null">×</button>
        <div class="modal-art">
          <img v-if="isImageUrl(selectedCard.image_url)" :src="selectedCard.image_url" :alt="selectedCard.name">
          <span v-else>{{ selectedCard.image_url || selectedCard.avatar_url || '✦' }}</span>
        </div>
        <div class="modal-body">
          <span class="eyebrow">{{ selectedCard.rarity || 'TIMEDOOR BATTLE CARD' }} · {{ selectedCard.element || 'NEUTRAL' }}</span>
          <h2>{{ selectedCard.name }}</h2>
          <p class="modal-description">{{ selectedCard.description || selectedCard.lore || 'Kartu petarung Timedoor Battle Card. Atur strategi dan kombinasikan dengan kartu lain untuk membangun tim yang kuat.' }}</p>
          <div class="modal-stats">
            <div><small>HP</small><b>{{ selectedCard.hp ?? '—' }}</b></div>
            <div><small>ATTACK</small><b>{{ selectedCard.attack ?? '—' }}</b></div>
            <div><small>DEFENSE</small><b>{{ selectedCard.defense ?? '—' }}</b></div>
          </div>
          <div v-if="selectedCard.metadata?.prototype_stat_preview" class="modal-detail">
            <small>STATISTIK PROTOTIPE</small><p>Angka referensi dari formula dokumen; resep belum aktif dan batas maksimum statistik belum ditentukan.</p>
          </div>
          <div v-for="(skill, index) in skillsForCard(selectedCard)" :key="skill.id || index" class="modal-detail modal-skill">
            <div class="modal-skill-icon"><SkillIcon :icon="skill.icon" :name="skill.name" /></div>
            <div>
              <small>SKILL {{ index + 1 }} <span v-if="skill.metadata?.catalog_only">· BELUM AKTIF DI BATTLE</span></small>
              <h3>{{ skill.name }}</h3>
              <p>{{ skill.description || skill.effect }}</p>
            </div>
          </div>
          <div v-if="selectedCard.metadata?.learning_mission || selectedCard.metadata?.education_theme" class="modal-detail">
            <small>{{ selectedCard.metadata.learning_arc || 'FUSION LAB' }} · {{ selectedCard.metadata.lesson_topic || 'PEMBELAJARAN' }}</small>
            <p>{{ selectedCard.metadata.learning_mission || selectedCard.metadata.education_theme }}</p>
          </div>
          <div v-if="recipesForCard(selectedCard).length" class="modal-detail">
            <small>RESEP FUSION</small><p v-for="recipe in recipesForCard(selectedCard)" :key="recipe.id">{{ recipeSummary(recipe) || 'Resep khusus' }}<span v-if="!recipe.is_active"> · Preview, belum aktif</span></p>
          </div>
          <div class="modal-code">CARD CODE <b>{{ selectedCard.metadata?.source_card_code || selectedCard.card_code || '—' }}</b></div>
        </div>
      </section>
    </div>
  </main>
</template>

<style scoped>
@import url('https://fonts.googleapis.com/css2?family=DM+Sans:wght@400;500;600;700;800&family=Space+Grotesk:wght@500;600;700&display=swap');
.hero-actions{flex-wrap:wrap}.hero-actions .guide-link{background:transparent;color:white;border:1px solid #ffffff8c}.featured-limit-note{color:#60796a;font-size:12px;line-height:1.7;margin:0 0 26px}
.featured-section{max-width:1200px;margin:76px auto;padding:0 28px}.featured-section>header{display:flex;align-items:end;justify-content:space-between;gap:20px;margin-bottom:28px}.featured-section h2{font-size:clamp(26px,4vw,42px);letter-spacing:-1.4px;margin:8px 0 0}.featured-section>p,.featured-section>div{padding:24px;background:#f2f7ee;border-radius:14px}.featured-group h3{font-size:15px;letter-spacing:.06em;margin:28px 0 16px;text-transform:uppercase;color:#4c6850}.featured-grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(220px,1fr));gap:22px}.featured-card{text-align:left;overflow:hidden;border:1px solid #d5dfd0;border-radius:18px;background:#fff;color:#173a29;cursor:pointer;transition:transform .2s,border-color .2s}.featured-card:hover{transform:translateY(-4px);border-color:#468955}.featured-card:focus-visible{outline:3px solid #148442;outline-offset:4px}.featured-art{position:relative;height:260px;background:#edf3e8;display:grid;place-items:center}.featured-art img{width:100%;height:100%;object-fit:contain}.featured-art>span{font-size:60px;color:#557c54}.featured-art>b{position:absolute;top:12px;left:12px;background:#173c2d;color:#fbdf76;border-radius:5px;padding:5px 9px;font-size:11px;letter-spacing:.1em}.featured-copy{padding:20px}.featured-copy small{text-transform:uppercase;font-size:11px;letter-spacing:.08em;color:#54785c}.featured-copy h4{font-size:22px;line-height:1.15;margin:10px 0 16px}.featured-stats{display:flex;justify-content:space-between;font-size:12px;border-block:1px solid #e5ebe0;padding:12px 0}.featured-copy p{font-size:13px;margin:12px 0 0}.featured-detail{display:block;margin-top:18px;font-size:12px;font-weight:700}@media(max-width:600px){.featured-section{padding:0 18px;margin:48px auto}.featured-section>header{align-items:start;flex-direction:column}.featured-grid{grid-template-columns:repeat(2,minmax(0,1fr));gap:12px}.featured-art{height:210px}.featured-copy{padding:12px}.featured-copy h4{font-size:18px}.featured-stats{font-size:10px}}


*{box-sizing:border-box}.timedoor-site{--green:#0caf25;--green-deep:#087f1d;--green-pale:#e8f8e9;--navy:#1d347e;--yellow:#ffdb45;--ink:#173623;--muted:#60796a;min-height:100vh;background:#f8fbf7;color:var(--ink);font-family:'DM Sans',sans-serif}.site-nav{height:78px;padding:0 clamp(20px,6vw,90px);display:flex;justify-content:space-between;align-items:center;background:#0caf25;color:white}.wordmark{display:flex;align-items:center;gap:10px;color:white;text-decoration:none;font-family:'Space Grotesk',sans-serif;font-size:22px;font-weight:700;line-height:.88;letter-spacing:-.06em}.wordmark small{display:block;margin-top:7px;font:700 8px 'DM Sans',sans-serif;letter-spacing:.2em}.td-symbol{width:34px;height:34px;display:grid;place-items:center;border:2px solid white;border-radius:4px 14px 4px 14px;font-size:25px;font-weight:700;font-style:italic}.site-nav nav{display:flex;gap:36px}.site-nav nav a{color:#d7f6d8;text-decoration:none;font-size:13px;font-weight:700}.site-nav nav a.active,.site-nav nav a:hover{color:white;text-decoration:underline;text-underline-offset:8px}.nav-play{border:0;border-radius:999px;padding:12px 17px;color:var(--green-deep);background:#fff;font-size:12px;font-weight:800;text-decoration:none}.nav-play span{margin-left:10px;color:var(--green)}.hero{position:relative;min-height:620px;overflow:hidden;padding:clamp(60px,9vw,115px) clamp(24px,10vw,150px) 100px;background:var(--green)}.hero:before,.hero:after{content:'✦';position:absolute;color:#ffffff18;font-size:250px;line-height:1;pointer-events:none}.hero:before{left:-62px;top:42%;transform:rotate(-17deg)}.hero:after{right:5%;top:8%;font-size:190px;transform:rotate(15deg)}.hero-copy{position:relative;z-index:2;max-width:580px;color:white}.eyebrow{font-size:10px;font-weight:800;letter-spacing:.19em;color:var(--green-deep)}.hero .eyebrow{color:#c9f3ca}.hero h1,.play-aside h1,.page-intro h1{font:700 clamp(47px,6.5vw,82px)/.99 'Space Grotesk',sans-serif;letter-spacing:-.075em;margin:20px 0}.hero h1 em,.play-aside h1 em{font-style:normal;color:var(--yellow)}.hero-copy>p,.play-aside>p{max-width:450px;color:#e0f6e2;font-size:15px;line-height:1.75}.hero-actions{display:flex;align-items:center;gap:25px;margin-top:28px}.hero-actions button,.submit-play{border:0;border-radius:9px;background:var(--yellow);color:#193d23;padding:14px 19px;font-weight:800;cursor:pointer}.hero-actions button span{margin-left:16px}.hero-actions a{color:white;text-decoration:none;font-size:12px;font-weight:700}.hero-actions a b{margin-left:5px}.hero-counts{display:flex;align-items:center;gap:16px;margin-top:48px;color:#d8f2d9;font-size:11px}.hero-counts b{color:white;font:700 18px 'Space Grotesk',sans-serif;margin-right:4px}.hero-counts i{height:21px;border-left:1px solid #ffffff55}.hero-scene{position:absolute;right:8%;top:10%;width:39%;height:80%;display:grid;place-items:center}.scene-card{position:absolute;width:220px;height:310px;border:2px solid #ffffffa0;border-radius:18px;box-shadow:0 24px 40px #075e1d55;display:flex;flex-direction:column;align-items:center;justify-content:center}.card-shadow{background:#16812b;transform:translate(-62px,8px) rotate(-13deg);color:#9ce9a1;font:700 66px 'Space Grotesk',sans-serif}.card-main{transform:translate(32px,-10px) rotate(7deg);background:linear-gradient(155deg,#fffedb,#c8f4a8 58%,#60c65b);color:#164b25}.card-main>span{position:absolute;top:20px;right:20px;color:#e4ae14;font-size:23px}.card-main b{text-align:center;font:700 25px/1.1 'Space Grotesk',sans-serif;letter-spacing:-.05em}.card-main small{margin-top:16px;color:#4a8554;font-size:8px;font-weight:800;letter-spacing:.17em}.scene-shape{position:absolute;color:#ffffff36;font-size:180px;font-weight:700}.shape-star{left:-5%;top:3%}.shape-code{right:-10%;bottom:-7%;font-size:125px;color:#18347b}.scene-chip{position:absolute;z-index:2;border-radius:999px;background:#fff;padding:10px 13px;color:#25502c;box-shadow:0 6px 18px #075e1d38;font-size:9px;font-weight:900;letter-spacing:.1em}.chip-yellow{top:15%;right:1%;background:var(--yellow)}.chip-blue{bottom:14%;left:0;background:#24377e;color:white}.hero-bottom{position:absolute;right:5%;bottom:26px;max-width:210px;text-align:right;color:white;font-size:10px;font-weight:800;line-height:1.5;letter-spacing:.06em}.hero-bottom span{display:inline-block;margin-left:7px;color:var(--yellow);font-size:17px}.catalog-page{max-width:1220px;margin:auto;padding:66px 30px 90px;min-height:calc(100vh - 155px)}.page-intro{max-width:690px;margin-bottom:28px}.page-intro h1{font-size:clamp(42px,5vw,61px);color:#173b22;margin:13px 0}.page-intro p{color:#6b7f70;line-height:1.65;font-size:14px}.search{display:flex;gap:10px;align-items:center;max-width:390px;margin:24px 0}.search span{font-size:22px;color:var(--green)}.search input,.form-field input,.form-field select{width:100%;border:1px solid #d8e5d9;border-radius:8px;padding:12px 13px;background:white;font:inherit;font-size:13px;color:#203d29;outline-color:#60bf67}.unit-grid{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:18px}.unit-card{height:390px;display:flex;flex-direction:column;text-align:left;overflow:hidden;padding:0;border:1px solid #deeadf;border-radius:14px;background:white;color:inherit;box-shadow:0 5px 16px #26492e0a;cursor:pointer;transition:transform .2s,box-shadow .2s}.unit-card:hover{transform:translateY(-4px);box-shadow:0 14px 30px #16452317}.unit-art{height:220px;flex:none;position:relative;display:grid;place-items:center;overflow:hidden;background:#e8f4e6}.unit-art img{width:100%;height:100%;object-fit:contain}.unit-art>span{font-size:76px;color:#3d8b45}.unit-art b,.unit-art i{position:absolute;top:12px;left:12px;background:#ffffffdf;border-radius:5px;padding:6px 8px;color:#236b31;font-size:8px;font-style:normal;font-weight:900;letter-spacing:.08em}.unit-art i{left:auto;right:12px;color:#916e00}.unit-info{display:flex;flex:1;flex-direction:column;padding:14px}.unit-info>small,.skill-card small{font-size:8px;letter-spacing:.14em;color:#889b89;font-weight:800}.unit-info h2{overflow:hidden;text-overflow:ellipsis;white-space:nowrap;margin:5px 0 10px;font:700 16px 'Space Grotesk',sans-serif}.unit-stats{display:flex;justify-content:space-between;padding:9px 0;border-top:1px solid #edf2ed;border-bottom:1px solid #edf2ed;color:#819184;font-size:9px}.unit-stats b{color:#25422b;font-size:11px}.unit-info>p{display:flex;justify-content:space-between;gap:8px;margin:auto 0 0;padding-top:10px;color:#31833c;font-size:10px;font-weight:800}.unit-info>p span{font-size:14px}.empty-state{padding:35px;color:#718475;text-align:center}.fusion-page{max-width:none;padding-left:max(30px,calc((100% - 1160px)/2));padding-right:max(30px,calc((100% - 1160px)/2));background:#eff8ef}.fusion-grid{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:17px}.fusion-recipe{padding:17px;border:1px solid #dce9dc;border-radius:13px;background:white}.recipe-heading{display:flex;justify-content:space-between;align-items:center;color:#778b79;font-size:8px;font-weight:900;letter-spacing:.16em}.recipe-heading b{display:grid;place-items:center;width:30px;height:30px;border-radius:8px;background:#e8f6e8;color:#29883a;font-size:15px}.fusion-material-list{min-height:76px;padding:12px 0 3px}.fusion-material-list div{display:flex;gap:7px;margin:5px 0;color:#425f48;font-size:11px}.fusion-material-list div span{font-weight:900;color:#31a242}.fusion-material-list p{color:#879889;font-size:10px}.recipe-connector{text-align:center;color:#25a33a;font-size:18px}.fusion-result-card{width:100%;min-height:205px;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:6px;padding:12px;border:1px solid #d8ebd9;border-radius:10px;background:#f6fbf4;color:#21472a;cursor:pointer}.fusion-result-card:hover{border-color:#47b555;box-shadow:0 6px 16px #16852b17}.fusion-result-card .result-label{font-size:8px;letter-spacing:.16em;color:#3e934b;font-weight:900}.fusion-result-card img{width:78px;height:78px;object-fit:cover;border-radius:9px}.result-emoji{display:grid;place-items:center;width:78px;height:78px;border-radius:9px;background:#e6f4e5;font-size:35px;color:#388e44}.fusion-result-card strong{font:700 14px 'Space Grotesk',sans-serif}.fusion-result-card small{color:#708574;font-size:9px}.fusion-result-card em{color:#348641;font-size:9px;font-style:normal;font-weight:800}.missing-result{padding:18px;text-align:center;color:#9a7770;font-size:11px}.skills-grid{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:15px}.skill-card{min-height:170px;display:flex;gap:14px;padding:18px;border:1px solid #dfebdf;border-radius:12px;background:white}.skill-icon{flex:none;width:40px;height:40px;display:grid;place-items:center;border-radius:10px;background:#eaf7e9;color:#27a13a;font-size:20px}.skill-card h2{margin:5px 0;font:700 16px 'Space Grotesk',sans-serif}.skill-card p{margin:0;color:#728273;font-size:11px;line-height:1.6}.skill-details{display:flex;flex-wrap:wrap;gap:6px;margin-top:13px}.skill-details span{padding:5px 7px;border-radius:5px;background:#f0f7ee;color:#597460;font-size:8px;font-weight:700}.play-page{max-width:1100px;min-height:calc(100vh - 160px);margin:auto;padding:75px 30px;display:grid;grid-template-columns:1fr .8fr;align-items:center;gap:60px}.play-aside{position:relative;min-height:400px;padding:35px;border-radius:18px;background:#0caf25;color:white;overflow:hidden}.play-aside .eyebrow{color:#d7f6d8}.play-aside h1{font-size:59px}.play-aside>p{font-size:13px}.play-mark{position:absolute;right:20px;bottom:-57px;color:#ffffff26;font:700 190px 'Space Grotesk',sans-serif;letter-spacing:-.14em}.play-mark span{color:#17347e}.join-card{padding:27px;border:1px solid #dce9dc;border-radius:14px;background:white;box-shadow:0 14px 35px #1e48200d}.join-card h2{margin:10px 0 6px;font:700 25px 'Space Grotesk',sans-serif}.join-card>p{color:#708273;font-size:11px;line-height:1.55}.mode-tabs{display:flex;gap:5px;margin:20px 0 16px}.mode-tabs button{border:0;border-radius:6px;padding:9px 12px;background:#f1f5f1;color:#728273;font-size:10px;font-weight:800;cursor:pointer}.mode-tabs button.active{background:#dff4df;color:#238534}.form-field{display:flex;flex-direction:column;gap:7px;margin:12px 0}.form-field>span{font-size:9px;letter-spacing:.12em;color:#6f8371;font-weight:900}.submit-play{width:100%;margin-top:6px;background:var(--green);color:white}.submit-play:disabled{opacity:.6}.form-error{color:#b23931;font-size:11px}.privacy-note{display:block;margin-top:15px;color:#879588;font-size:9px;line-height:1.5}.site-footer{min-height:82px;padding:17px clamp(20px,6vw,90px);display:flex;justify-content:space-between;align-items:center;background:#087f1d;color:#d5f0d6;font-size:10px}.site-footer .wordmark{font-size:18px}.site-footer .td-symbol{width:29px;height:29px;font-size:21px}.site-footer>a:last-child{color:white;text-decoration:none;font-weight:800}.modal-backdrop{position:fixed;z-index:1000;inset:0;display:grid;place-items:center;padding:20px;background:#09220fc7;backdrop-filter:blur(5px)}.card-modal{position:relative;width:min(960px,100%);max-height:92dvh;display:grid;grid-template-columns:minmax(0,.95fr) minmax(0,1.05fr);overflow:auto;border-radius:16px;background:#fff;box-shadow:0 28px 90px #00120755}.modal-close{position:absolute;z-index:2;right:12px;top:12px;width:34px;height:34px;border:0;border-radius:50%;background:#ffffffdf;color:#23452b;font-size:24px;cursor:pointer}.modal-art{min-width:0;min-height:420px;display:flex;align-items:center;justify-content:center;padding:20px;background:#edf5e9}.modal-art img{display:block;width:100%;height:auto;max-height:82dvh;object-fit:contain;border-radius:10px}.modal-art span{font-size:100px;color:#329342}.modal-body{min-width:0;padding:40px 30px 30px;overflow-wrap:anywhere}.modal-body h2{margin:9px 0;font:700 29px 'Space Grotesk',sans-serif;letter-spacing:-.05em}.modal-description,.modal-detail p{color:#708173;font-size:12px;line-height:1.7}.modal-stats{display:grid;grid-template-columns:repeat(3,1fr);gap:8px;margin:19px 0}.modal-stats div{display:flex;flex-direction:column;gap:5px;padding:12px;border-radius:8px;background:#eff8ee}.modal-stats small,.modal-detail small{color:#78907a;font-size:8px;font-weight:900;letter-spacing:.12em}.modal-stats b{font:700 19px 'Space Grotesk',sans-serif}.modal-detail{margin-top:18px;padding-top:15px;border-top:1px solid #e8efe8}.modal-detail h3{margin:7px 0;font-size:14px}.modal-detail p{margin:6px 0}.modal-skill{display:grid;grid-template-columns:64px minmax(0,1fr);gap:14px;align-items:start}.modal-skill-icon{width:64px;height:64px;display:grid;place-items:center;border:1px solid #d9e8d5;border-radius:50%;background:#eff8ee;font-size:28px;overflow:hidden}.modal-code{display:flex;justify-content:space-between;margin-top:19px;padding-top:12px;border-top:1px solid #e8efe8;color:#91a092;font-size:8px;font-weight:900;letter-spacing:.1em}.modal-code b{color:#3a5e3d;font-size:10px}
.unit-card:focus-visible,.fusion-result-card:focus-visible,.site-nav a:focus-visible,button:focus-visible{outline:3px solid #ffdb45;outline-offset:3px}
.unit-skills-preview{display:flex;flex-direction:column;gap:3px;min-height:31px;margin:auto 0 0;padding-top:8px}.unit-skills-preview span{overflow:hidden;color:#31833c;font-size:8px;font-weight:800;text-overflow:ellipsis;white-space:nowrap}
.type-filters{display:flex;flex-wrap:wrap;gap:8px;margin:0 0 14px}.type-filters button{border:1px solid #d6e6d5;border-radius:999px;padding:8px 13px;background:#fff;color:#59715d;font:700 10px 'DM Sans',sans-serif;cursor:pointer}.type-filters button.active{border-color:#16952a;background:#16952a;color:#fff}.catalog-select-filters{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:10px;margin:0 0 24px}.catalog-select-filters label{display:flex;flex-direction:column;gap:6px}.catalog-select-filters label>span{color:#728675;font-size:8px;font-weight:900;letter-spacing:.13em}.catalog-select-filters select{min-width:0;width:100%;border:1px solid #d8e5d9;border-radius:8px;padding:10px 11px;background:#fff;color:#294630;font:700 11px 'DM Sans',sans-serif;outline-color:#60bf67}.catalog-pagination{display:flex;justify-content:center;align-items:center;gap:18px;margin-top:30px;color:#667b69;font-size:11px}.catalog-pagination button{border:1px solid #d5e4d4;border-radius:7px;padding:9px 12px;background:#fff;color:#347341;font-size:10px;font-weight:800;cursor:pointer}.catalog-pagination button:disabled{opacity:.4;cursor:default}.catalog-pagination b{color:#173b22}.recipe-heading{gap:8px}.recipe-heading span{display:flex;align-items:center;gap:7px;min-width:0}.recipe-heading span small{flex:none;border-radius:999px;padding:4px 6px;background:#eaf6e9;color:#398448;font-size:7px;letter-spacing:.04em}.recipe-heading span .preview-label{background:#fff4d6;color:#85650a}.recipe-heading>b{display:block;min-width:0;max-width:115px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;padding:7px 9px;border-radius:8px;background:#e8f6e8;color:#29883a;font-size:10px;letter-spacing:0}.recipe-line{margin:3px 0 8px}.recipe-line>small{color:#869788;font-size:8px;font-weight:800;letter-spacing:.06em}.recipe-line p{display:flex;gap:7px;margin:5px 0;color:#425f48;font-size:10px}.recipe-line p span{font-weight:900;color:#31a242}.fusion-result-card{height:220px;min-height:220px;flex:none}.fusion-result-card img,.fusion-result-card .result-emoji{width:78px;height:78px;flex:none}.fusion-recipe{min-width:0;overflow:hidden}.fusion-material-list{overflow-wrap:anywhere}
@media(max-width:900px){.hero{padding-left:8%;}.hero-scene{right:2%;width:40%;transform:scale(.84)}.unit-grid{grid-template-columns:repeat(3,minmax(0,1fr))}.fusion-grid,.skills-grid{grid-template-columns:repeat(2,minmax(0,1fr))}.play-page{gap:25px}}
@media(max-width:900px){.catalog-select-filters{grid-template-columns:repeat(2,minmax(0,1fr))}}
@media(max-width:620px){.site-nav{height:68px;padding:0 16px}.wordmark{font-size:18px}.td-symbol{width:29px;height:29px}.site-nav nav{gap:13px}.site-nav nav a{font-size:10px}.nav-play{padding:10px;font-size:10px}.nav-play span{margin:0}.hero{min-height:740px;padding:64px 23px 90px}.hero h1{font-size:53px}.hero-copy>p{font-size:13px}.hero-counts{gap:10px;margin-top:34px}.hero-counts b{font-size:15px}.hero-scene{top:375px;right:0;width:100%;height:330px;transform:scale(.78)}.hero-bottom{right:19px;bottom:15px;font-size:8px}.catalog-page{padding:45px 16px 65px}.page-intro h1{font-size:43px}.page-intro p{font-size:12px}.unit-grid{grid-template-columns:repeat(2,minmax(0,1fr));gap:10px}.unit-card{height:330px}.unit-art{height:180px}.unit-info{padding:11px}.unit-info h2{font-size:13px}.fusion-page{padding-left:16px;padding-right:16px}.fusion-grid,.skills-grid{grid-template-columns:1fr}.fusion-recipe{padding:14px}.play-page{display:flex;flex-direction:column;align-items:stretch;gap:18px;padding:28px 15px 44px}.play-aside{min-height:255px;padding:25px}.play-aside h1{font-size:45px;margin:13px 0}.play-aside>p{max-width:350px}.play-mark{font-size:130px;bottom:-40px}.join-card{padding:21px}.site-footer{gap:11px;flex-wrap:wrap;padding:18px 16px}.site-footer>span{order:3;width:100%}.card-modal{display:flex;flex-direction:column;max-height:92dvh}.modal-art{min-height:0;flex:none;padding:20px 40px 12px}.modal-art img{height:auto;max-height:50dvh}.modal-art span{font-size:62px}.modal-body{padding:22px}.modal-body h2{font-size:24px}}
.timedoor-site{padding-top:78px}.site-nav{position:fixed;inset:0 0 auto;z-index:100;box-shadow:0 5px 18px #075e1d20}.site-nav nav a.router-link-active{color:#fff;text-decoration:underline;text-underline-offset:8px}
.fusion-tools{display:grid;grid-template-columns:minmax(260px,1.1fr) minmax(0,2fr);gap:14px;align-items:end;margin:0 0 25px;padding:15px;border:1px solid #dce9dc;border-radius:13px;background:#fff}.fusion-search{display:flex;align-items:center;gap:9px;min-width:0}.fusion-search>span{color:#24943a;font-size:23px}.fusion-search input,.fusion-filters select{min-width:0;width:100%;border:1px solid #d7e5d7;border-radius:8px;padding:11px 12px;background:#fff;color:#294630;font:600 11px 'DM Sans',sans-serif;outline-color:#60bf67}.fusion-filters{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:9px}.fusion-filters label{display:flex;min-width:0;flex-direction:column;gap:5px}.fusion-filters label>span{color:#7b8d7d;font-size:8px;font-weight:900;letter-spacing:.1em}.fusion-grid{align-items:stretch}.fusion-recipe{display:flex;min-width:0;flex-direction:column;gap:11px;padding:17px}.recipe-heading{display:block;min-width:0;padding-bottom:10px;border-bottom:1px solid #edf2ed}.recipe-meta{display:flex;flex-wrap:wrap;align-items:center;gap:6px}.recipe-kicker{color:#7d907f;font-size:8px;font-weight:900;letter-spacing:.12em}.recipe-badge{max-width:100%;border-radius:999px;padding:4px 8px;background:#e9f6e8;color:#398448;font-size:8px;font-weight:900;white-space:nowrap}.recipe-badge.preview-label{background:#fff4d6;color:#85650a}.recipe-title{margin:9px 0 3px;color:#204529;font:700 19px/1.2 'Space Grotesk',sans-serif;letter-spacing:-.035em;overflow-wrap:anywhere}.recipe-subtitle{margin:0;color:#809080;font-size:9px;font-weight:700}.fusion-material-list{display:grid;align-content:start;gap:9px;min-height:0;padding:0;overflow-wrap:normal}.recipe-option{min-width:0;padding:11px;border:1px solid #e2eee1;border-radius:9px;background:#f8fbf7}.recipe-option-heading{display:flex;flex-wrap:wrap;align-items:baseline;justify-content:space-between;gap:4px 8px;margin-bottom:8px}.recipe-option-heading strong{color:#42684a;font-size:9px;font-weight:900}.recipe-option-heading span{color:#8a988b;font-size:8px}.material-list{display:grid;gap:7px;margin:0;padding:0;list-style:none}.material-list li{display:grid;grid-template-columns:auto minmax(0,1fr);align-items:start;gap:8px;min-width:0}.material-quantity{max-width:74px;border-radius:6px;padding:5px 6px;background:#e4f3e3;color:#31743b;font-size:8px;font-weight:900;white-space:nowrap}.material-list li>span{display:grid;min-width:0;gap:2px}.material-list li strong{color:#35573b;font-size:10px;line-height:1.4;overflow-wrap:anywhere}.material-list li small{color:#819082;font-size:8px;line-height:1.45;overflow-wrap:anywhere}.no-materials{margin:0;color:#8a988b;font-size:9px}.recipe-connector{margin:auto 0 0;padding-top:1px;line-height:1}.fusion-result-card{height:220px;min-height:220px;flex:none}.tutorial-section{max-width:1180px;margin:0 auto;padding:68px 30px 82px}.tutorial-heading{max-width:650px;margin-bottom:24px}.tutorial-heading h2{margin:9px 0;font:700 clamp(29px,4vw,42px)/1.1 'Space Grotesk',sans-serif;letter-spacing:-.05em;color:#173b22}.tutorial-heading p{margin:0;color:#728575;font-size:12px;line-height:1.6}.tutorial-steps{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:12px}.tutorial-steps article{display:flex;gap:12px;min-height:150px;padding:16px;border:1px solid #dce9dc;border-radius:12px;background:#fff}.tutorial-steps article>span{flex:none;color:#a7d8a6;font:700 22px 'Space Grotesk',sans-serif}.tutorial-steps h3{margin:1px 0 7px;color:#285033;font:700 13px 'Space Grotesk',sans-serif}.tutorial-steps p{margin:0;color:#748578;font-size:10px;line-height:1.6}.tutorial-link{display:inline-flex;align-items:center;gap:14px;margin-top:19px;border-radius:8px;padding:12px 15px;background:#0caf25;color:#fff;text-decoration:none;font-size:10px;font-weight:900}.tutorial-link span{font-size:14px}
@media(max-width:900px){.fusion-tools{grid-template-columns:1fr}.tutorial-steps{grid-template-columns:repeat(2,minmax(0,1fr))}}
@media(max-width:620px){.timedoor-site{padding-top:68px}.site-nav{gap:8px}.site-nav nav{flex:1;justify-content:center;gap:10px}.nav-play{flex:none;padding:9px}.fusion-tools{padding:11px}.fusion-filters{grid-template-columns:1fr}.recipe-title{font-size:17px}.fusion-recipe{padding:13px}.tutorial-section{padding:48px 16px 58px}.tutorial-steps{grid-template-columns:1fr}.tutorial-steps article{min-height:0}.tutorial-link{width:100%;justify-content:space-between}}
@media(prefers-reduced-motion:reduce){*,*::before,*::after{scroll-behavior:auto!important;transition:none!important}}
.tutorial-heading{max-width:760px;margin-bottom:28px}.tutorial-heading h2{max-width:730px}.guide-deck-panel,.guide-actions-panel{margin:0 0 34px;padding:22px;border:1px solid #dce9dc;border-radius:15px;background:#fff;box-shadow:0 12px 35px #1e482008}.guide-section-title{display:flex;align-items:flex-start;gap:12px;margin-bottom:18px}.guide-icon{width:38px;height:38px;flex:none;display:grid;place-items:center;border-radius:11px;background:#e7f6e6;font-size:18px}.guide-section-title .eyebrow{font-size:8px}.guide-section-title h3{margin:4px 0 0;color:#204529;font:700 20px/1.2 'Space Grotesk',sans-serif;letter-spacing:-.035em}.guide-section-title p{margin:6px 0 0;color:#718374;font-size:10px;line-height:1.6}.guide-flow{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:10px}.guide-flow article{display:flex;gap:10px;min-width:0;padding:14px;border:1px solid #e5eee4;border-radius:10px;background:#f9fcf8}.guide-flow article>b{flex:none;color:#83c988;font:700 18px 'Space Grotesk',sans-serif}.guide-flow h4,.guide-card h4{margin:1px 0 7px;color:#285033;font:700 13px/1.3 'Space Grotesk',sans-serif}.guide-flow p,.guide-card p,.guide-actions-panel .guide-action-grid p{margin:0;color:#718174;font-size:10px;line-height:1.65}.guide-note{margin:12px 0 0;padding:12px 14px;border-left:3px solid #e6b947;border-radius:7px;background:#fff9e9;color:#705f32;font-size:10px;line-height:1.65}.guide-board-title{margin:0 0 16px}.guide-board-grid{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:11px;margin-bottom:34px}.guide-card{min-width:0;padding:17px;border:1px solid #dce9dc;border-radius:12px;background:#fff}.guide-card-number{display:inline-flex;align-items:center;min-height:21px;margin-bottom:10px;padding:3px 7px;border-radius:6px;background:#e9f6e8;color:#27853a;font-size:8px;font-weight:900;letter-spacing:.1em}.guide-actions-panel .guide-section-title{margin-bottom:16px}.guide-action-grid{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:9px}.guide-action-grid article{min-width:0;padding:13px;border:1px solid #e4eee3;border-radius:9px;background:#fbfdfb}.guide-action-grid article>b{display:block;margin-bottom:7px;color:#277c37;font-size:9px;font-weight:900;letter-spacing:.04em}.guide-action-grid p{font-size:9px!important;line-height:1.65}.guide-learning-grid{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:11px}.guide-feature-card{display:flex;flex-direction:column}.guide-inline-links{display:flex;flex-wrap:wrap;gap:12px;margin-top:14px}.guide-inline-links a{color:#16852c;font-size:9px;font-weight:900;text-decoration:none}.guide-inline-links a:hover{text-decoration:underline;text-underline-offset:3px}.guide-public-note{margin:17px 0 0;padding:13px 15px;border:1px solid #dce9dc;border-radius:9px;background:#f4faf3;color:#597060;font-size:10px;line-height:1.65}
@media(max-width:900px){.guide-flow{grid-template-columns:repeat(2,minmax(0,1fr))}.guide-action-grid{grid-template-columns:repeat(2,minmax(0,1fr))}.guide-board-grid,.guide-learning-grid{grid-template-columns:1fr}}
.guide-board-grid{grid-template-columns:repeat(4,minmax(0,1fr))}@media(max-width:900px){.guide-board-grid{grid-template-columns:repeat(2,minmax(0,1fr))}}
@media(max-width:620px){.guide-deck-panel,.guide-actions-panel{padding:15px}.guide-flow,.guide-action-grid,.guide-board-grid{grid-template-columns:1fr}.guide-flow article{padding:12px}.guide-section-title h3{font-size:17px}.guide-card{padding:15px}.guide-public-note{font-size:9px}.guide-inline-links{flex-direction:column;gap:8px}}
.guide-details{margin-top:9px;padding-top:8px;border-top:1px solid #e3eee2}.guide-details summary{color:#178331;font-size:9px;font-weight:900;cursor:pointer}.guide-details ul{display:grid;gap:5px;margin:9px 0;padding-left:15px;color:#617566;font-size:9px;line-height:1.45}.guide-details li b{color:#315b39}.guide-details small{display:block;color:#859286;font-size:8px;line-height:1.5}
.guide-media-panel{margin-top:18px;padding:16px;border:1px solid #e1ece0;border-radius:12px;background:#f9fcf8}.guide-media-heading{display:flex;align-items:end;justify-content:space-between;gap:12px;margin-bottom:12px}.guide-media-heading .eyebrow{font-size:8px}.guide-media-heading h4{margin:4px 0 0;color:#285033;font:700 15px 'Space Grotesk',sans-serif}.guide-media-heading p{margin:0;color:#78897a;font-size:9px}.guide-media-grid{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:9px}.guide-media-card{min-width:0;margin:0;overflow:hidden;border:1px solid #dce9dc;border-radius:10px;background:#fff}.guide-media-screen{position:relative;aspect-ratio:16/9;display:grid;place-items:center;overflow:hidden;background:linear-gradient(145deg,#e7f5e6,#f5faf3)}.guide-media-screen img{display:block;width:100%;height:100%;object-fit:cover}.guide-media-placeholder{display:grid;justify-items:center;gap:5px;padding:8px;text-align:center}.guide-media-placeholder>span{font-size:24px}.guide-media-placeholder>b{color:#347344;font-size:9px}.guide-media-placeholder code{max-width:100%;overflow-wrap:anywhere;color:#728675;font:8px ui-monospace,monospace}.guide-media-card figcaption{display:grid;gap:4px;padding:9px 10px}.guide-media-card figcaption b{color:#2c5434;font-size:9px}.guide-media-card figcaption span{color:#78897a;font-size:8px;line-height:1.5}.guide-media-note{margin:10px 0 0;color:#758777;font-size:9px;line-height:1.6}.guide-media-note code{color:#328242;font-size:9px;font-weight:700}
@media(max-width:900px){.guide-media-grid{grid-template-columns:repeat(2,minmax(0,1fr))}}
@media(max-width:620px){.guide-media-panel{padding:12px}.guide-media-heading{align-items:flex-start;flex-direction:column}.guide-media-grid{grid-template-columns:1fr}.guide-media-card figcaption span{font-size:9px}}
.fusion-grid{align-items:start}
.fusion-recipe{min-height:472px;gap:10px}
.recipe-heading{display:flex;flex:none;flex-direction:column;justify-content:flex-start;gap:4px;min-height:104px;padding-bottom:9px}
.recipe-meta{min-height:18px}
.recipe-title{display:-webkit-box;min-height:2.35em;margin:3px 0 0;overflow:hidden;-webkit-box-orient:vertical;-webkit-line-clamp:2}
.recipe-subtitle{min-height:1.3em}
.recipe-disclosure{width:100%;min-height:40px;display:flex;align-items:center;gap:8px;padding:9px 11px;border:1px solid #dbeadb;border-radius:9px;color:#28783a;text-align:left;background:#f7fcf6;cursor:pointer;transition:background .16s ease,border-color .16s ease}
.recipe-disclosure:hover{border-color:#9dcfa1;background:#eff9ee}
.recipe-disclosure>span{flex:1;font-size:10px;font-weight:800}
.recipe-disclosure small{flex:none;border-radius:999px;padding:4px 7px;color:#397b42;background:#e5f4e4;font-size:8px;font-weight:800}
.recipe-disclosure>b{flex:none;color:#16852c;font-size:16px;line-height:1;transition:transform .16s ease}
.recipe-disclosure>b.expanded{transform:rotate(180deg)}
.fusion-material-list{width:100%;display:grid;flex:none;align-content:start;gap:9px;min-height:0}
.recipe-connector{height:18px;display:grid;flex:none;place-items:center;margin:auto 0 0;padding:0;color:#26a33e}
.fusion-result-card{width:100%;margin-top:0}
@media(max-width:620px){.fusion-recipe{min-height:450px}.recipe-heading{min-height:98px}.recipe-title{font-size:17px}}
.catalog-legend{display:flex;flex-direction:column;gap:9px;margin:-5px 0 23px;padding:12px 14px;border:1px solid #dfeadf;border-radius:10px;background:#fff}
.legend-group{display:flex;align-items:center;flex-wrap:wrap;gap:6px}
.legend-group>b{min-width:67px;color:#829184;font-size:8px;font-weight:900;letter-spacing:.12em}
.legend-chip{display:inline-flex;align-items:center;gap:5px;min-height:23px;padding:4px 8px;border:1px solid var(--legend-border,#dce8dc);border-radius:999px;background:var(--legend-bg,#f8fbf7);color:var(--legend-ink,#45634a);font-size:8px;font-weight:800;text-transform:capitalize;white-space:nowrap}
.legend-chip i,.identity-chip i{font-style:normal}
.legend-chip i{font-size:9px}
.legend-chip.element-fire,.unit-art b.element-fire,.identity-chip.element-fire{--legend-bg:#fff0e9;--legend-border:#ffd1bd;--legend-ink:#b54e24}
.legend-chip.element-water,.unit-art b.element-water,.identity-chip.element-water{--legend-bg:#e9f5ff;--legend-border:#c6e3ff;--legend-ink:#2373b4}
.legend-chip.element-forest,.unit-art b.element-forest,.identity-chip.element-forest{--legend-bg:#edf8e9;--legend-border:#cde8c2;--legend-ink:#4b8738}
.legend-chip.element-thunder,.unit-art b.element-thunder,.identity-chip.element-thunder{--legend-bg:#fff9dc;--legend-border:#f4e49a;--legend-ink:#8d7100}
.legend-chip.element-knight,.unit-art b.element-knight,.identity-chip.element-knight{--legend-bg:#eef2f4;--legend-border:#cbd8de;--legend-ink:#45616d}
.legend-chip.element-grass,.unit-art b.element-grass,.identity-chip.element-grass{--legend-bg:#edf8e9;--legend-border:#cde8c2;--legend-ink:#4b8738}
.legend-chip.element-electric,.unit-art b.element-electric,.identity-chip.element-electric{--legend-bg:#fff9dc;--legend-border:#f4e49a;--legend-ink:#8d7100}
.legend-chip.element-ice,.unit-art b.element-ice,.identity-chip.element-ice{--legend-bg:#e8fbfb;--legend-border:#c1ebeb;--legend-ink:#237e83}
.legend-chip.element-dark,.unit-art b.element-dark,.identity-chip.element-dark{--legend-bg:#f0edfa;--legend-border:#d7ccef;--legend-ink:#654c9b}
.legend-chip.element-wind,.unit-art b.element-wind,.identity-chip.element-wind{--legend-bg:#edf5f1;--legend-border:#d1e5d9;--legend-ink:#397254}
.legend-chip.element-light,.unit-art b.element-light,.identity-chip.element-light{--legend-bg:#fff8df;--legend-border:#f0e1aa;--legend-ink:#917322}
.legend-chip.element-neutral,.unit-art b.element-neutral,.identity-chip.element-neutral{--legend-bg:#f2f4f2;--legend-border:#dfe4df;--legend-ink:#68756a}
.unit-card{position:relative;border-color:var(--rarity-border,#dce8dc);box-shadow:0 0 0 1px var(--rarity-border,#dce8dc),0 5px 16px #26492e0a}
.unit-card::before{position:absolute;z-index:3;inset:0 0 auto;height:5px;background:var(--rarity-accent,#8d9a8e);content:""}
.unit-card:hover{box-shadow:0 0 0 2px var(--rarity-accent,#8d9a8e),0 14px 30px #1645231c}
.rarity-legend .legend-chip,.identity-chip.rarity-common,.unit-art .rarity-common{--legend-bg:#f1f3f1;--legend-border:#d5dcd6;--legend-ink:#627067}
.rarity-legend .rarity-uncommon,.identity-chip.rarity-uncommon,.unit-art .rarity-uncommon{--legend-bg:#ebf8ed;--legend-border:#c4e8c9;--legend-ink:#328247}
.rarity-legend .rarity-rare,.identity-chip.rarity-rare,.unit-art .rarity-rare{--legend-bg:#edf4ff;--legend-border:#cbdcff;--legend-ink:#3766ad}
.rarity-legend .rarity-epic,.identity-chip.rarity-epic,.unit-art .rarity-epic{--legend-bg:#f5efff;--legend-border:#dfd0fa;--legend-ink:#7951aa}
.rarity-legend .rarity-legendary,.identity-chip.rarity-legendary,.unit-art .rarity-legendary{--legend-bg:#fff7e3;--legend-border:#f1d99c;--legend-ink:#9a6e13}
.rarity-legend .rarity-mythic,.identity-chip.rarity-mythic,.unit-art .rarity-mythic{--legend-bg:#fff0f5;--legend-border:#f2c7d7;--legend-ink:#ad4264}
.unit-card.rarity-common,.fusion-recipe.rarity-common,.fusion-result-card.rarity-common{--rarity-accent:#89978d;--rarity-border:#d8dfda}
.unit-card.rarity-uncommon,.fusion-recipe.rarity-uncommon,.fusion-result-card.rarity-uncommon{--rarity-accent:#42a65a;--rarity-border:#c6e7cb}
.unit-card.rarity-rare,.fusion-recipe.rarity-rare,.fusion-result-card.rarity-rare{--rarity-accent:#4386d6;--rarity-border:#c9dcf6}
.unit-card.rarity-epic,.fusion-recipe.rarity-epic,.fusion-result-card.rarity-epic{--rarity-accent:#9560cf;--rarity-border:#decdf2}
.unit-card.rarity-legendary,.fusion-recipe.rarity-legendary,.fusion-result-card.rarity-legendary{--rarity-accent:#d7a22e;--rarity-border:#f0dda9}
.unit-card.rarity-mythic,.fusion-recipe.rarity-mythic,.fusion-result-card.rarity-mythic{--rarity-accent:#d85b81;--rarity-border:#f0c8d5}
.unit-art b,.unit-art i.rarity-chip{display:inline-flex;align-items:center;gap:5px;border:1px solid var(--legend-border,#d9e7da);background:var(--legend-bg,#fff);color:var(--legend-ink,#42664a);box-shadow:0 2px 8px #17362318}
.unit-art b{left:11px;top:11px;text-transform:uppercase}
.unit-art b i{position:static;display:inline;padding:0;border:0;border-radius:0;background:transparent;color:inherit;font-size:10px;box-shadow:none}
.unit-art i.rarity-chip{right:11px;top:11px;left:auto;font-style:normal;color:var(--legend-ink,#637067);text-transform:capitalize}
.rarity-chip span{color:var(--rarity-accent,#89978d);font-size:10px}
.identity-chips{display:flex;flex-wrap:wrap;gap:6px;min-height:23px}
.identity-chip{display:inline-flex;align-items:center;gap:5px;max-width:100%;padding:4px 8px;border:1px solid var(--legend-border,#dce8dc);border-radius:999px;background:var(--legend-bg,#f8fbf7);color:var(--legend-ink,#45634a);font-size:8px;font-weight:900;line-height:1.2;text-transform:capitalize}
.identity-chip.rarity-common,.identity-chip.rarity-uncommon,.identity-chip.rarity-rare,.identity-chip.rarity-epic,.identity-chip.rarity-legendary,.identity-chip.rarity-mythic{color:var(--legend-ink)}
.fusion-recipe{position:relative;overflow:hidden;border-color:var(--rarity-border,#dce9dc);box-shadow:0 0 0 1px var(--rarity-border,#dce9dc),0 5px 16px #26492e08}
.fusion-recipe::before{position:absolute;inset:0 0 auto;height:4px;background:var(--rarity-accent,#8d9a8e);content:""}
.recipe-heading{min-height:0;padding-top:2px}
.recipe-title{margin:5px 0 3px}
.fusion-result-card{position:relative;overflow:hidden;border-color:var(--rarity-border,#d8ebd9);border-top:4px solid var(--rarity-accent,#8d9a8e);background:linear-gradient(180deg,var(--legend-bg,#f6fbf4),#fff 72%)}
.fusion-result-card.rarity-common,.fusion-result-card.rarity-uncommon,.fusion-result-card.rarity-rare,.fusion-result-card.rarity-epic,.fusion-result-card.rarity-legendary,.fusion-result-card.rarity-mythic{--legend-bg:#f7fbf7}
.result-identity{justify-content:center;min-height:23px}
.fusion-legend{margin-top:0}
@media(max-width:620px){.catalog-legend{gap:8px;padding:10px}.legend-group{gap:5px}.legend-group>b{width:100%;min-width:0}.legend-chip{min-height:22px;padding:4px 7px}.unit-art b,.unit-art i.rarity-chip{top:8px;max-width:47%;overflow:hidden;text-overflow:ellipsis;font-size:7px}.unit-art i.rarity-chip{right:8px}.unit-art b{left:8px}}
.unit-card.physical-only{display:block;width:100%;height:auto;aspect-ratio:2/3;padding:0;overflow:hidden;border:0;border-radius:15px;background:transparent;box-shadow:0 8px 24px #1736231c}
.unit-card.physical-only::before{display:none}
.unit-card.physical-only:hover{box-shadow:0 16px 34px #17362332}
.physical-card-image{display:block;width:100%;height:100%;object-fit:contain;border-radius:inherit}
.fusion-result-card.physical-result-only{width:min(100%,172px);height:auto;min-height:0;aspect-ratio:2/3;align-self:center;padding:0;overflow:hidden;border:0;border-radius:10px;background:transparent;box-shadow:0 6px 18px #17362318}
.fusion-result-card.physical-result-only:hover{border:0;box-shadow:0 11px 24px #17362330}
.physical-result-image{display:block;width:100%;height:100%;object-fit:contain;border-radius:inherit}

/* Fusion Forge: recipes read as a single transformation, not an empty stack. */
.fusion-grid{grid-template-columns:repeat(2,minmax(0,1fr));gap:22px}
.fusion-recipe{gap:14px;min-height:0;padding:21px;background:linear-gradient(145deg,#fff 0%,#fbfdf9 100%)}
.fusion-recipe::after{position:absolute;right:-34px;bottom:-45px;width:150px;height:150px;border:22px solid color-mix(in srgb,var(--rarity-accent,#75a67d) 12%,transparent);border-radius:50%;content:"";pointer-events:none}
.recipe-heading{position:relative;z-index:1;min-height:0;padding:5px 0 14px}
.recipe-title{font-size:21px;line-height:1.05}
.fusion-flow{position:relative;z-index:1;display:grid;grid-template-columns:minmax(0,1fr) 42px minmax(130px,.88fr);align-items:center;gap:8px;min-height:205px}
.fusion-ingredients{align-self:stretch;display:flex;min-width:0;flex-direction:column;justify-content:center;padding:15px 12px;border:1px dashed color-mix(in srgb,var(--rarity-accent,#75a67d) 45%,#cfe1ce);border-radius:13px;background:#fff}
.fusion-stage-label{margin-bottom:10px;color:#718b74;font-size:8px;font-weight:900;letter-spacing:.13em}
.material-list--compact{gap:9px}
.material-list--compact li{gap:6px}
.material-list--compact .material-quantity{min-width:30px;text-align:center}
.fusion-transform{display:grid;place-items:center;gap:0;color:var(--rarity-accent,#38964a);text-align:center}
.fusion-transform i{display:grid;place-items:center;width:28px;height:28px;border:1px solid currentColor;border-radius:50%;background:#fff;font-size:17px;font-style:normal;line-height:1;box-shadow:0 3px 12px #2851321c}
.fusion-transform b{margin-top:5px;font-size:7px;letter-spacing:.09em}
.fusion-transform em{font-size:18px;font-style:normal;line-height:.9}
.fusion-result-card{z-index:1;width:100%;height:205px;min-height:205px;display:grid;grid-template-rows:1fr auto;align-self:stretch;justify-content:stretch;gap:0;padding:0;border:1px solid var(--rarity-border,#d8ebd9);border-top:4px solid var(--rarity-accent,#8d9a8e);border-radius:13px;background:#fff;text-align:left;box-shadow:0 10px 22px #1d442712}
.fusion-result-card:hover{transform:translateY(-3px);border-color:var(--rarity-accent,#47b555);box-shadow:0 15px 28px #1d442725}
.result-art{position:relative;display:block;min-height:0;overflow:hidden;background:linear-gradient(135deg,#e8f4e5,#fff)}
.result-art::after{position:absolute;inset:auto 0 0;height:46%;background:linear-gradient(transparent,#17362318);content:"";pointer-events:none}
.result-art img{display:block;width:100%;height:100%;object-fit:cover;border:0;border-radius:0}
.result-art .result-emoji{display:grid;width:100%;height:100%;place-items:center;color:var(--rarity-accent,#348641);font-size:48px}
.result-copy{display:grid;gap:3px;padding:9px 10px 10px;background:#fff}
.result-copy>small{color:var(--rarity-accent,#3e934b);font-size:7px;font-weight:900;letter-spacing:.13em}
.result-copy>strong{overflow:hidden;color:#21472a;font:700 13px/1.05 'Space Grotesk',sans-serif;text-overflow:ellipsis;white-space:nowrap}
.result-stats{display:flex;gap:5px;margin-top:2px;color:#718771;font-size:7px}
.result-stats b{padding-right:5px;border-right:1px solid #dce8da}.result-stats b:last-child{padding-right:0;border:0}
.result-copy em{color:#388646;font-size:8px;font-style:normal;font-weight:900}
.recipe-disclosure{position:relative;z-index:1}
.fusion-material-list{position:relative;z-index:1}
@media(max-width:760px){.fusion-grid{grid-template-columns:1fr}.fusion-flow{grid-template-columns:minmax(0,1fr) 34px minmax(116px,.8fr)}.fusion-recipe{padding:16px}.recipe-title{font-size:18px}}
@media(max-width:520px){.fusion-flow{grid-template-columns:1fr;gap:10px}.fusion-transform{grid-template-columns:auto auto auto;gap:7px;justify-content:center}.fusion-transform b{margin:0}.fusion-transform em{transform:rotate(90deg)}.fusion-result-card{height:240px;min-height:240px}.fusion-ingredients{min-height:110px}.recipe-title{font-size:19px}}
@media(max-width:620px){.unit-card.physical-only{border-radius:11px}.fusion-result-card.physical-result-only{width:min(100%,190px)}}
</style>
