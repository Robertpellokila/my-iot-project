<script setup>
import SearchableSelect from "../components/SearchableSelect.vue";
import SkillIcon from '../components/battle/SkillIcon.vue';
import { splitSkillIcon, skillMediaValue, describeBasicSkill } from '../lib/battle/skillPresentation.js';
import { computed, defineAsyncComponent, onMounted, ref, watch } from "vue";
const BattleRuleCatalog=defineAsyncComponent(()=>import('../components/battle/BattleRuleCatalog.vue'));
import { useRoute } from 'vue-router';
import { supabase } from "../lib/supabase";
const props=defineProps({embedded:Boolean,cardId:String});
const emit=defineEmits(['saved','saving']);

const cards = ref([]);
const route = useRoute();
const skills = ref([]);
const links = ref([]);
const recipes = ref([]);
const materials = ref([]);
const playtests = ref([]);
const revisions = ref([]);
const loading = ref(true);
const saving = ref(false);
watch(saving,value=>emit('saving',value));
const savingPlaytest = ref(false);
const errorMessage = ref("");
const successMessage = ref("");
const selectedSkillId = ref("");
const activeTab = ref("skills");
const historyTab = ref("playtests");
const search = ref("");
const statusFilter = ref("all");
const ruleAdvanced = ref(false);
const rulesJson = ref("[]");
const playtestForm = ref({ outcome: "observation", scenario: "", observed_result: "", change_summary: "" });

const blankDraft = () => ({
  name: "", code: "", description: "", icon: "✦", image_url: '', catalog_status: "draft",
  skill_type: "active", trigger_type: "main_phase", activation_timing: "main_phase",
  target_type: "enemy_active", target_required: true,
  cost_type: "none", cost_value: 0, action_points: 1, cooldown_unit: "owner", cooldown_rounds: 0, max_uses: 0,
  once_per_battle: false, consumes_turn: true,
  effect_type: "damage_card", effect_amount: 30, effect_status: "burn", effect_duration: 1,
  change_note: "",
});
const draft = ref(blankDraft());
const basicRuleSnapshot = ref('');
const basicRuleKey = row => JSON.stringify([row.effect_type,row.effect_amount,row.effect_status,row.effect_duration,row.target_type]);

const cardById = computed(() => new Map(cards.value.map((card) => [String(card.id), card])));
const selectedSkill = computed(() => skills.value.find((skill) => String(skill.id) === String(selectedSkillId.value)) ?? null);
const skillsForCard = (cardId) => links.value
  .filter((link) => String(link.game_card_id) === String(cardId) && link.enabled !== false)
  .sort((a, b) => Number(a.sort_order ?? 0) - Number(b.sort_order ?? 0))
  .map((link) => skills.value.find((skill) => String(skill.id) === String(link.special_skill_id)))
  .filter(Boolean);
const cardNamesForSkill = (skillId) => links.value
  .filter((link) => String(link.special_skill_id) === String(skillId) && link.enabled !== false)
  .map((link) => cardById.value.get(String(link.game_card_id))?.name)
  .filter(Boolean);

const ruleIssues = (skill, { fromDraft = false } = {}) => {
  const row = fromDraft ? draft.value : skill;
  const target = fromDraft ? { type: row.target_type } : row.target_spec ?? {};
  const cost = fromDraft ? { type: row.cost_type } : row.cost_spec ?? {};
  const limits = fromDraft ? { action_points: row.action_points } : row.limits ?? {};
  let trigger = fromDraft ? row.trigger_type : row.trigger_spec?.type;
  if (!trigger) trigger = row.activation_timing;
  let effects = [];
  try {
    effects = fromDraft && ruleAdvanced.value ? JSON.parse(rulesJson.value) : fromDraft ? buildBasicEffect(row) : row.effects;
  } catch {
    return ["Format JSON efek tidak valid."];
  }

  const issues = [];
  if (!String(row.name ?? "").trim()) issues.push("Nama skill belum diisi.");
  else if (/^(?:https?:\/\/|data:|\/)/i.test(String(row.name).trim())) issues.push('Nama skill harus berupa nama kemampuan; pindahkan URL ke Gambar skill.');
  if ((fromDraft ? row.catalog_status === 'active' : row.is_active) && !String(row.description ?? '').trim()) issues.push('Penjelasan skill aktif wajib diisi.');
  if (fromDraft) { try { skillMediaValue(row.image_url,row.icon); } catch(error) { issues.push(error.message); } }
  if (String(row.skill_type ?? "") !== "active") issues.push("Battle saat ini hanya menjalankan skill aktif manual; pasif/terpicu tetap di Draft atau Playtest.");
  if (!trigger) issues.push("Pemicu skill belum dipilih.");
  else if (trigger !== "main_phase") issues.push("Pemicu otomatis belum didukung saat battle; gunakan Main phase untuk aktivasi.");
  if (!String(target.type ?? target.target ?? target.mode ?? "").trim()) issues.push("Target skill belum ditentukan.");
  if (!String(cost.type ?? "").trim()) issues.push("Biaya skill belum ditentukan.");
  if (![1, 2].includes(Number(limits.action_points ?? 1))) issues.push("Biaya poin giliran harus 1 atau 2.");
  if (!Array.isArray(effects) || !effects.length || effects.some((effect) => !String(effect?.type ?? "").trim())) {
    issues.push("Tambahkan minimal satu efek dengan jenis yang valid.");
  }
  if (Array.isArray(effects) && effects.some((effect) => effect?.type === "add_status" && Number(effect.duration_turns ?? 0) < 1)) {
    issues.push("Efek status memerlukan durasi minimal satu turn.");
  }
  return issues;
};

const effectLabels = {
  damage_card: "Damage ke kartu",
  heal_card: "Pulihkan HP kartu",
  damage_player: "Damage ke pemain",
  heal_player: "Pulihkan HP pemain",
  add_skill_gauge: "Tambah skill gauge",
  add_status: "Terapkan status",
};
const statusChoices = [
  { value: "burn", label: "Burn", icon: "🔥" },
  { value: "freeze", label: "Freeze", icon: "🧊" },
  { value: "stun", label: "Stun", icon: "💫" },
  { value: "poison", label: "Poison", icon: "☠" },
  { value: "curse", label: "Curse", icon: "🌑" },
  { value: "shield", label: "Shield", icon: "🛡" },
];

const buildBasicEffect = (row = draft.value) => {
  const amount = { mode: "fixed", value: Math.max(0, Number(row.effect_amount) || 0) };
  const type = row.effect_type;
  const owner = String(row.target_type).startsWith("enemy") ? "enemy" : "self";
  if (type === "damage_card" || type === "heal_card") {
    return [{ type, target: row.target_type === "self_card" && type === "heal_card" ? "source_card" : "target_card", owner, allowed_zones: ["active"], amount }];
  }
  if (type === "damage_player" || type === "heal_player" || type === "add_skill_gauge") {
    const target = row.target_type === "enemy_player" ? "enemy_player" : "self_player";
    return [{ type, target, amount }];
  }
  if (type === "add_status") {
    const choice = statusChoices.find((item) => item.value === row.effect_status);
    return [{
      type: "add_status", target: "target_card", owner, scope: "card", status_key: row.effect_status,
      value: amount.value, stacks: 1, max_stacks: 1, stack_mode: "replace", duration_turns: Math.max(1, Number(row.effect_duration) || 1),
      allowed_zones: ["active"],
      metadata: { label: row.effect_status.toUpperCase(), icon: choice?.icon ?? "✦", tone: row.effect_status, source_trigger: "special_skill", tick_damage: amount.value },
    }];
  }
  return [{ type, target: "target_card", owner, amount }];
};

const readiness = computed(() => ruleIssues(null, { fromDraft: true }));
const canActivate = computed(() => readiness.value.length === 0);
const statusCounts = computed(() => Object.fromEntries(["draft", "playtest", "active", "archived"].map((status) => [status, skills.value.filter((skill) => skill.catalog_status === status).length])));

const filteredSkills = computed(() => {
  const query = search.value.trim().toLocaleLowerCase();
  return skills.value.filter((skill) => {
    if(props.embedded && !links.value.some(link=>link.game_card_id===props.cardId && link.special_skill_id===skill.id))return false;
    const statusMatch = statusFilter.value === "all" || skill.catalog_status === statusFilter.value;
    const cardNames = cardNamesForSkill(skill.id).join(" ");
    const queryMatch = !query || `${skill.name} ${skill.code} ${skill.description ?? ""} ${cardNames}`.toLocaleLowerCase().includes(query);
    return statusMatch && queryMatch;
  });
});

const cardsByName = computed(() => {
  const unique = new Map();
  for (const card of cards.value.filter((row) => !row.fusion_only)) {
    const key = String(card.name ?? "").trim().toLocaleLowerCase();
    const linkedCount = skillsForCard(card.id).length;
    const metadataCount = Array.isArray(card.metadata?.skills) ? card.metadata.skills.length : 0;
    const current = unique.get(key);
    const currentScore = current ? Math.max(skillsForCard(current.id).length, current.metadata?.skills?.length ?? 0) : -1;
    if (key && Math.max(linkedCount, metadataCount) > currentScore) unique.set(key, card);
  }
  return [...unique.values()];
});
const cardsMissingSkills = computed(() => cardsByName.value.filter((card) =>
  skillsForCard(card.id).length === 0 && !(Array.isArray(card.metadata?.skills) && card.metadata.skills.length),
));
const incompleteSkills = computed(() => skills.value.filter((skill) =>
  skill.catalog_status !== "archived" && ruleIssues(skill).length > 0,
));
const recipeHealth = computed(() => recipes.value.map((recipe) => {
  const result = cardById.value.get(String(recipe.result_game_card_id));
  const recipeMaterials = materials.value.filter((item) => String(item.recipe_id) === String(recipe.id));
  const issues = [];
  if (!recipe.is_active) issues.push("Belum diaktifkan");
  if (!result) issues.push("Kartu hasil tidak ditemukan");
  if (!recipeMaterials.length) issues.push("Belum ada material resep");
  if (recipeMaterials.some((item) => item.material_type === "exact_card" && !item.card_code)) issues.push("Kode material kosong");
  if (recipeMaterials.some((item) => item.material_type === "one_of" && !(item.card_codes ?? []).length)) issues.push("Pilihan material kosong");
  return { ...recipe, result_name: result?.name ?? "Hasil tidak ditemukan", issues, ready: issues.length === 0 };
}));
const incompleteRecipes = computed(() => recipeHealth.value.filter((recipe) => !recipe.ready));

const syncDraftFromSkill = (skill) => {
  if (!skill) return;
  const target = skill.target_spec ?? {};
  const cost = skill.cost_spec ?? {};
  const limits = skill.limits ?? {};
  const effects = Array.isArray(skill.effects) ? skill.effects : [];
  const first = effects[0] ?? {};
  const simpleTypes = ["damage_card", "heal_card", "damage_player", "heal_player", "add_skill_gauge", "add_status"];
  ruleAdvanced.value = effects.length !== 1 || !simpleTypes.includes(first.type);
  rulesJson.value = JSON.stringify(effects, null, 2);
  draft.value = {
    ...blankDraft(),
    name: skill.name ?? "",
    code: skill.code ?? "",
    description: skill.description ?? "",
    icon: splitSkillIcon(skill.icon).symbol,
    image_url: splitSkillIcon(skill.icon).imageUrl,
    catalog_status: skill.catalog_status ?? (skill.is_active ? "active" : "draft"),
    skill_type: skill.skill_type ?? "active",
    trigger_type: skill.trigger_spec?.type ?? skill.activation_timing ?? "main_phase",
    activation_timing: skill.activation_timing ?? "main_phase",
    target_type: target.type ?? target.target ?? target.mode ?? "enemy_active",
    target_required: target.required ?? true,
    cost_type: cost.type ?? "none",
    cost_value: Number(cost.value ?? cost.amount ?? 0),
    action_points: Number(limits.action_points ?? 1),
    cooldown_unit: Object.hasOwn(limits, "cooldown_turns") ? "owner" : "round",
    cooldown_rounds: Number(limits.cooldown_turns ?? limits.cooldown_rounds ?? limits.cooldown ?? 0),
    max_uses: Number(limits.max_uses ?? 0),
    once_per_battle: Boolean(limits.once_per_battle),
    consumes_turn: Boolean(skill.consumes_turn ?? true),
    effect_type: first.type ?? "damage_card",
    effect_amount: Number(first.amount?.value ?? first.value ?? first.metadata?.tick_damage ?? 0),
    effect_status: first.status_key ?? "burn",
    effect_duration: Number(first.duration_turns ?? 1),
  };
  basicRuleSnapshot.value = basicRuleKey(draft.value);
};

const selectSkill = async (id) => {
  selectedSkillId.value = id;
  successMessage.value = "";
  errorMessage.value = "";
  const skill = skills.value.find((item) => String(item.id) === String(id));
  syncDraftFromSkill(skill);
  playtests.value = [];
  revisions.value = [];
  if (!skill) return;
  const [playtestResult, revisionResult] = await Promise.all([
    supabase.from("special_skill_playtest_logs").select("*").eq("special_skill_id", id).order("created_at", { ascending: false }).limit(30),
    supabase.from("special_skill_revisions").select("*").eq("special_skill_id", id).order("skill_version", { ascending: false }).limit(30),
  ]);
  if (!playtestResult.error) playtests.value = playtestResult.data ?? [];
  if (!revisionResult.error) revisions.value = revisionResult.data ?? [];
};

const loadCatalog = async () => {
  loading.value = true;
  errorMessage.value = "";
  const results = await Promise.all([
    supabase.from("game_cards").select("id,name,element,level,rarity,fusion_only,metadata").order("name"),
    supabase.from("special_skills").select("*").order("name"),
    supabase.from("game_card_special_skills").select("game_card_id,special_skill_id,sort_order,enabled"),
    supabase.from("fusion_recipes").select("id,name,code,result_game_card_id,is_active,result_stat_spec").order("name"),
    supabase.from("fusion_recipe_materials").select("id,recipe_id,material_type,card_code,card_codes,quantity,tag,element,metadata"),
  ]);
  const [cardResult, skillResult, linkResult, recipeResult, materialResult] = results;
  const failed = results.find((item) => item.error);
  if (failed) errorMessage.value = failed.error.message;
  cards.value = cardResult.data ?? [];
  skills.value = skillResult.data ?? [];
  links.value = linkResult.data ?? [];
  recipes.value = recipeResult.data ?? [];
  materials.value = materialResult.data ?? [];
  if(props.embedded){const available=filteredSkills.value;await selectSkill(available.some(skill=>skill.id===selectedSkillId.value)?selectedSkillId.value:available[0]?.id);}
  else if (route.query.skill && skills.value.some(skill => skill.id === route.query.skill)) await selectSkill(String(route.query.skill));
  else if (!selectedSkillId.value && skills.value.length) await selectSkill(skills.value[0].id);
  else if (selectedSkillId.value) await selectSkill(selectedSkillId.value);
  loading.value = false;
};

const saveSkill = async () => {
  if (!selectedSkill.value) return;
  errorMessage.value = "";
  successMessage.value = "";
  let effects;
  try { effects = (() => {
    if (ruleAdvanced.value) {
      try {
        const parsed = JSON.parse(rulesJson.value);
        if (!Array.isArray(parsed)) throw new Error("Efek harus berupa JSON array.");
        return parsed;
      } catch (error) {
        throw new Error(error?.message || "JSON efek tidak valid.");
      }
    }
    return basicRuleKey(draft.value) === basicRuleSnapshot.value ? selectedSkill.value.effects : buildBasicEffect();
  })(); } catch(error) { errorMessage.value=error.message; return; }
  const updatedRule = {
    ...draft.value,
    target_spec: { ...(draft.value.target_type === selectedSkill.value.target_spec?.type ? selectedSkill.value.target_spec : {}), type: draft.value.target_type, required: Boolean(draft.value.target_required) },
    cost_spec: { type: draft.value.cost_type, value: draft.value.cost_type === "none" ? 0 : Math.max(0, Number(draft.value.cost_value) || 0) },
    limits: {
      ...(selectedSkill.value.limits ?? {}),
      action_points: Math.max(1, Math.min(2, Number(draft.value.action_points) || 1)),
      [draft.value.cooldown_unit === "owner" ? "cooldown_turns" : "cooldown_rounds"]: Math.max(0, Number(draft.value.cooldown_rounds) || 0),
      once_per_battle: Boolean(draft.value.once_per_battle),
      max_uses: draft.value.once_per_battle ? 1 : Math.max(0, Number(draft.value.max_uses) || 0),
    },
    effects,
  };
  delete updatedRule.limits[draft.value.cooldown_unit === 'owner' ? 'cooldown_rounds' : 'cooldown_turns'];
  delete updatedRule.limits.cooldown;
  const issues = ruleIssues(updatedRule, { fromDraft: true });
  if (draft.value.catalog_status === "active" && issues.length) {
    errorMessage.value = `Skill belum dapat diaktifkan: ${issues.join(" ")}`;
    return;
  }
  if (!updatedRule.name.trim() || !updatedRule.code.trim()) {
    errorMessage.value = "Nama dan kode skill wajib diisi.";
    return;
  }

  saving.value = true;
  try {
    const payload = {
      name: updatedRule.name.trim(),
      code: updatedRule.code.trim().toLowerCase(),
      description: updatedRule.description.trim() || null,
      icon: skillMediaValue(updatedRule.image_url, updatedRule.icon),
      skill_type: updatedRule.skill_type,
      activation_timing: updatedRule.trigger_type,
      trigger_spec: { ...(selectedSkill.value.trigger_spec?.type === updatedRule.trigger_type ? selectedSkill.value.trigger_spec : {}), type: updatedRule.trigger_type, label: updatedRule.trigger_type === "main_phase" ? "Aktif manual pada main phase" : "Pemicu event katalog" },
      target_spec: updatedRule.target_spec,
      cost_spec: updatedRule.cost_spec,
      limits: updatedRule.limits,
      effects: updatedRule.effects,
      consumes_turn: Boolean(updatedRule.consumes_turn),
      catalog_status: updatedRule.catalog_status,
      is_active: updatedRule.catalog_status === "active",
      change_note: draft.value.change_note?.trim() || null,
      metadata: {...(selectedSkill.value.metadata ?? {}),...(selectedSkill.value.metadata?.studio_generated ? {studio_customized:true} : {}),...(updatedRule.catalog_status === 'active' ? {catalog_only:false} : {})},
    };
    const { error } = await supabase.from("special_skills").update(payload).eq("id", selectedSkillId.value);
    if (error) throw error;
    successMessage.value = "Skill tersimpan. Versi dan riwayat perubahan tercatat otomatis.";
    emit('saved',{...selectedSkill.value,...payload});
    await loadCatalog();
  } catch (error) {
    errorMessage.value = error?.message ?? "Gagal menyimpan skill.";
  } finally {
    saving.value = false;
  }
};

const addPlaytest = async () => {
  if (!selectedSkill.value || !playtestForm.value.observed_result.trim()) {
    errorMessage.value = "Catatan hasil uji wajib diisi.";
    return;
  }
  savingPlaytest.value = true;
  errorMessage.value = "";
  successMessage.value = "";
  try {
    const { error } = await supabase.from("special_skill_playtest_logs").insert({
      special_skill_id: selectedSkillId.value,
      skill_version: selectedSkill.value.skill_version ?? 1,
      outcome: playtestForm.value.outcome,
      scenario: playtestForm.value.scenario.trim() || null,
      observed_result: playtestForm.value.observed_result.trim(),
      change_summary: playtestForm.value.change_summary.trim() || null,
    });
    if (error) throw error;
    playtestForm.value = { outcome: "observation", scenario: "", observed_result: "", change_summary: "" };
    const { data } = await supabase.from("special_skill_playtest_logs").select("*").eq("special_skill_id", selectedSkillId.value).order("created_at", { ascending: false }).limit(30);
    playtests.value = data ?? [];
    successMessage.value = "Hasil playtest tersimpan untuk skill versi ini.";
  } catch (error) {
    errorMessage.value = error?.message ?? "Gagal menyimpan hasil playtest.";
  } finally {
    savingPlaytest.value = false;
  }
};

const statusLabel = (status) => ({ draft: "Draft", playtest: "Playtest", active: "Aktif", archived: "Arsip" }[status] ?? "Draft");
const suggestSkillCopy = () => {
  if (ruleAdvanced.value) return;
  const row=draft.value,copy=describeBasicSkill({type:row.effect_type,amount:row.effect_amount,target:row.target_type,actionPoints:row.action_points,cooldown:row.cooldown_rounds,cooldownUnit:row.cooldown_unit,once:row.once_per_battle,endsTurn:row.consumes_turn});
  if (copy) {if(!row.name.trim())row.name=copy.name;row.description=copy.description;}
};
watch(()=>route.query.skill,id=>{if(id && skills.value.some(skill=>skill.id===id))selectSkill(String(id));});
const issueLabel = (issues) => issues[0] ?? "Aturan belum lengkap";

onMounted(loadCatalog);
</script>

<template>
  <main class="skill-catalog-page" :class="{'skill-catalog-embedded':embedded}">
    <header v-if="!embedded" class="catalog-heading">
      <div>
        <span class="eyebrow">TIMEDOOR · CARD WORKSHOP</span>
        <h1>Skill & kelengkapan katalog</h1>
        <p>Susun aturan skill, catat hasil playtest, dan lihat data kartu atau fusion yang masih perlu dilengkapi.</p>
      </div>
      <button class="refresh-button" type="button" @click="loadCatalog">↻ Muat ulang</button>
    </header>

    <div v-if="errorMessage" class="notice notice-error" role="alert">{{ errorMessage }}</div>
    <div v-if="successMessage" class="notice notice-success" role="status">{{ successMessage }}</div>

    <section v-if="!embedded" class="metric-row" aria-label="Ringkasan skill">
      <button type="button" class="metric" @click="statusFilter = 'draft'; activeTab = 'skills'"><span>Draft</span><strong>{{ statusCounts.draft ?? 0 }}</strong></button>
      <button type="button" class="metric" @click="statusFilter = 'playtest'; activeTab = 'skills'"><span>Playtest</span><strong>{{ statusCounts.playtest ?? 0 }}</strong></button>
      <button type="button" class="metric metric-active" @click="statusFilter = 'active'; activeTab = 'skills'"><span>Aktif</span><strong>{{ statusCounts.active ?? 0 }}</strong></button>
      <button type="button" class="metric metric-warning" @click="activeTab = 'audit'"><span>Temuan katalog</span><strong>{{ cardsMissingSkills.length + incompleteSkills.length + incompleteRecipes.length }}</strong></button>
    </section>

    <nav v-if="!embedded" class="catalog-tabs" aria-label="Bagian katalog">
      <button type="button" :class="{ selected: activeTab === 'skills' }" @click="activeTab = 'skills'">Skill</button>
      <button type="button" :class="{ selected: activeTab === 'synergy' }" @click="activeTab = 'synergy'">Synergy per tipe</button>
      <button type="button" :class="{ selected: activeTab === 'quiz_bonus' }" @click="activeTab = 'quiz_bonus'">Bonus kuis</button>
      <button type="button" :class="{ selected: activeTab === 'audit' }" @click="activeTab = 'audit'">Pemeriksaan katalog</button>
    </nav>

    <BattleRuleCatalog v-if="!embedded && ['synergy','quiz_bonus'].includes(activeTab)" :kind="activeTab"/>
    <section v-if="activeTab === 'skills'" class="skill-workspace">
      <aside class="skill-list-panel">
        <div v-if="!embedded" class="list-tools">
          <input v-model="search" type="search" placeholder="Cari skill atau nama kartu…" aria-label="Cari skill atau kartu">
          <SearchableSelect v-model="statusFilter" aria-label="Filter status skill">
            <option value="all">Semua status</option>
            <option value="draft">Draft</option>
            <option value="playtest">Playtest</option>
            <option value="active">Aktif</option>
            <option value="archived">Arsip</option>
          </SearchableSelect>
        </div>
        <div v-if="loading" class="empty-list">Memuat katalog…</div>
        <button
          v-for="skill in filteredSkills"
          :key="skill.id"
          type="button"
          class="skill-list-item"
          :class="{ selected: String(skill.id) === String(selectedSkillId) }"
          @click="selectSkill(skill.id)"
        >
          <span class="skill-item-icon"><SkillIcon :icon="skill.icon" :name="skill.name" /></span>
          <span class="skill-item-copy"><strong>{{ skill.name }}</strong><small>{{ cardNamesForSkill(skill.id).slice(0, 2).join(' · ') || 'Belum terpasang pada kartu' }}</small></span>
          <span class="status-chip" :class="skill.catalog_status">{{ statusLabel(skill.catalog_status) }}</span>
        </button>
        <p v-if="!loading && !filteredSkills.length" class="empty-list">Skill tidak ditemukan. Coba ubah pencarian atau filternya.</p>
      </aside>

      <section v-if="selectedSkill" class="skill-editor-panel">
        <div class="editor-heading">
          <div><span class="eyebrow">ATURAN SKILL · V{{ selectedSkill.skill_version ?? 1 }}</span><h2>{{ selectedSkill.name }}</h2></div>
          <span class="status-chip" :class="draft.catalog_status">{{ statusLabel(draft.catalog_status) }}</span>
        </div>
        <div class="linked-cards"><span>TERPASANG PADA</span><b v-for="name in cardNamesForSkill(selectedSkill.id)" :key="name">{{ name }}</b><em v-if="!cardNamesForSkill(selectedSkill.id).length">Belum ditautkan ke kartu</em></div>
        <p v-if="selectedSkill.metadata?.studio_generated" class="studio-rule-note">{{ selectedSkill.metadata?.studio_customized ? 'Aturan kustom' : 'Aturan dari template' }} · Menyimpan perubahan di sini menjadikannya aturan kustom yang dipertahankan saat Studio disimpan ulang. Salinan RFID baru mengikuti aturan tersimpan ini.</p>

        <form class="skill-form" @submit.prevent="saveSkill">
          <section class="catalog-skill-media" aria-label="Gambar skill">
            <span class="catalog-skill-art"><SkillIcon :icon="draft.image_url || draft.icon" :name="draft.name" /></span>
            <div><label>URL gambar skill<input v-model="draft.image_url" type="text" inputmode="url" placeholder="https://…/skill.webp"></label><p>Gambar digunakan sebagai ikon. Nama, penjelasan, dan aturan battle diisi pada bagiannya masing-masing.</p></div>
          </section>
          <div class="form-grid">
            <label>Nama skill<input v-model="draft.name" required placeholder="Contoh: Shell Brace"></label>
            <label>Kode internal<input v-model="draft.code" required></label>
            <label>Simbol pengganti<input v-model="draft.icon" maxlength="32" placeholder="✦"><small>Ditampilkan jika gambar tidak tersedia.</small></label>
            <label class="span-two">Deskripsi kartu<textarea v-model="draft.description" rows="2" placeholder="Jelaskan efek yang dibaca pemain"></textarea></label>
            <label>Status katalog<SearchableSelect v-model="draft.catalog_status"><option value="draft">Draft</option><option value="playtest">Playtest</option><option value="active">Aktif</option><option value="archived">Arsip</option></SearchableSelect></label>
            <label>Tipe skill<SearchableSelect v-model="draft.skill_type"><option value="active">Aktif</option><option value="passive">Pasif</option><option value="triggered">Terpicu event</option></SearchableSelect></label>
            <label>Pemicu<SearchableSelect v-model="draft.trigger_type"><option value="main_phase">Main phase · manual</option><option value="on_summon">Saat dipanggil</option><option value="on_attack">Saat menyerang</option><option value="on_hit">Saat serangan mengenai</option><option value="on_damage">Saat menerima damage</option><option value="turn_start">Awal turn</option><option value="turn_end">Akhir turn</option><option value="passive">Selalu pasif</option></SearchableSelect><small v-if="draft.trigger_type !== 'main_phase'">Pemicu event masih dicatat sebagai rancangan dan belum berjalan otomatis di battle.</small></label>
            <label>Target<SearchableSelect v-model="draft.target_type"><option value="enemy_active">Kartu lawan aktif</option><option value="enemy_active_or_bench">Kartu lawan aktif / bench</option><option value="ally_active">Kartu teman aktif</option><option value="ally_field">Kartu milikmu di Active / Bench</option><option value="self_card">Kartu ini</option><option value="self_player">Pemain sendiri</option><option value="enemy_player">Pemain lawan</option><option value="ally_graveyard">Kartu sendiri di graveyard</option></SearchableSelect></label>
            <label>Biaya<SearchableSelect v-model="draft.cost_type"><option value="none">Gratis</option><option value="skill_gauge">Skill gauge</option></SearchableSelect></label>
            <label v-if="draft.cost_type !== 'none'">Nilai biaya<input v-model.number="draft.cost_value" type="number" min="0"></label>
            <label>Poin Giliran<input v-model.number="draft.action_points" type="number" min="1" max="2"><small>Aktivasi skill memakai 1 atau 2 poin giliran.</small></label>
            <label>Satuan cooldown<select v-model="draft.cooldown_unit"><option value="owner">Giliran pemilik</option><option value="round">Round (legacy)</option></select></label><label>Cooldown<input v-model.number="draft.cooldown_rounds" type="number" min="0"><small>Isi 0 jika tidak ada cooldown.</small></label>
            <label>Batas penggunaan<input v-model.number="draft.max_uses" type="number" min="0"><small>Isi 0 jika tidak terbatas.</small></label>
          </div>

          <div class="check-row"><label><input v-model="draft.once_per_battle" type="checkbox"> Maksimal sekali per battle</label><label><input v-model="draft.consumes_turn" type="checkbox"> Menghabiskan turn</label><label><input v-model="draft.target_required" type="checkbox"> Wajib pilih target</label></div>

          <section class="effect-editor">
            <div class="subheading"><div><span class="eyebrow">HASIL SKILL</span><h3>Efek yang dijalankan</h3></div><label class="advanced-toggle"><input v-model="ruleAdvanced" type="checkbox"> JSON lanjutan</label></div>
            <template v-if="!ruleAdvanced">
              <div class="form-grid effect-grid">
                <label>Jenis efek<SearchableSelect v-model="draft.effect_type"><option v-for="(label, type) in effectLabels" :key="type" :value="type">{{ label }}</option></SearchableSelect></label>
                <label v-if="draft.effect_type === 'add_status'">Status<SearchableSelect v-model="draft.effect_status"><option v-for="status in statusChoices" :key="status.value" :value="status.value">{{ status.icon }} {{ status.label }}</option></SearchableSelect></label>
                <label v-if="draft.effect_type !== 'move_zone' && draft.effect_type !== 'revive' && draft.effect_type !== 'set_card_exhausted'">Nilai efek<input v-model.number="draft.effect_amount" type="number" min="0"></label>
                <label v-if="draft.effect_type === 'add_status'">Durasi (turn)<input v-model.number="draft.effect_duration" type="number" min="1"></label>
              </div>
              <p class="form-hint">Durasi berlaku untuk efek status. Efek langsung seperti damage atau heal selesai saat digunakan.</p>
              <button class="secondary-button" type="button" @click="suggestSkillCopy">Isi nama &amp; penjelasan dari aturan</button>
            </template>
            <label v-else class="json-field">Daftar efek JSON<textarea v-model="rulesJson" rows="9" spellcheck="false"></textarea></label>
          </section>

          <section class="readiness-panel" :class="{ ready: canActivate }">
            <div><span>{{ canActivate ? '✓' : '!' }}</span><div><strong>{{ canActivate ? 'Aturan lengkap untuk aktivasi' : 'Masih ada aturan yang perlu dilengkapi' }}</strong><small v-if="draft.catalog_status === 'active' && !canActivate">Skill Aktif akan ditolak sampai semua aturan valid.</small></div></div>
            <ul v-if="readiness.length"><li v-for="issue in readiness" :key="issue">{{ issue }}</li></ul>
          </section>

          <label class="change-note">Catatan perubahan versi<input v-model="draft.change_note" placeholder="Contoh: damage diturunkan dari 30 ke 24 setelah playtest"></label>
          <p class="runtime-note">Hanya status Aktif yang disalin ke battle. Saat ini battle menjalankan skill manual pada Main phase; pemicu otomatis tetap terkunci sampai engine mendukungnya.</p>
          <div class="form-actions"><button class="primary-button" type="submit" :disabled="saving">{{ saving ? 'Menyimpan…' : `Simpan skill · versi berikutnya` }}</button></div>
        </form>

        <div v-if="!embedded" class="history-block">
          <nav class="history-tabs"><button type="button" :class="{ selected: historyTab === 'playtests' }" @click="historyTab = 'playtests'">Playtest ({{ playtests.length }})</button><button type="button" :class="{ selected: historyTab === 'revisions' }" @click="historyTab = 'revisions'">Riwayat versi ({{ revisions.length }})</button></nav>
          <section v-if="historyTab === 'playtests'" class="playtest-area">
            <form class="playtest-form" @submit.prevent="addPlaytest">
              <label>Hasil<SearchableSelect v-model="playtestForm.outcome"><option value="observation">Observasi</option><option value="pass">Sesuai harapan</option><option value="needs_changes">Perlu balance</option><option value="fail">Gagal</option></SearchableSelect></label>
              <label>Skenario<input v-model="playtestForm.scenario" placeholder="Contoh: dipakai melawan kartu Water"></label>
              <label class="span-two">Hasil yang terlihat<textarea v-model="playtestForm.observed_result" rows="2" required placeholder="Catat yang terjadi saat skill diuji"></textarea></label>
              <label class="span-two">Perubahan yang disarankan<textarea v-model="playtestForm.change_summary" rows="2" placeholder="Damage, cooldown, target, atau durasi yang perlu diubah"></textarea></label>
              <button class="secondary-button" type="submit" :disabled="savingPlaytest">{{ savingPlaytest ? 'Menyimpan…' : 'Simpan hasil playtest' }}</button>
            </form>
            <div v-if="!playtests.length" class="empty-history">Belum ada catatan playtest untuk skill ini.</div>
            <article v-for="test in playtests" :key="test.id" class="history-entry"><div><strong>{{ { pass: 'Sesuai harapan', needs_changes: 'Perlu balance', fail: 'Gagal', observation: 'Observasi' }[test.outcome] }}</strong><small>Versi {{ test.skill_version }} · {{ new Date(test.created_at).toLocaleDateString('id-ID') }}</small></div><p v-if="test.scenario"><b>Skenario:</b> {{ test.scenario }}</p><p>{{ test.observed_result }}</p><p v-if="test.change_summary"><b>Perubahan:</b> {{ test.change_summary }}</p></article>
          </section>
          <section v-else class="revision-list"><article v-for="revision in revisions" :key="revision.id" class="history-entry"><div><strong>Versi {{ revision.skill_version }}</strong><small>{{ new Date(revision.created_at).toLocaleString('id-ID') }}</small></div><p>{{ revision.change_note || 'Perubahan skill disimpan' }}</p><details><summary>Lihat aturan versi ini</summary><pre>{{ JSON.stringify(revision.snapshot, null, 2) }}</pre></details></article><div v-if="!revisions.length" class="empty-history">Belum ada riwayat versi.</div></section>
        </div>
      </section>
      <div v-else class="empty-editor">Pilih skill di daftar untuk mengatur aturan dan playtest-nya.</div>
    </section>

    <section v-else-if="activeTab === 'audit'" class="audit-view">
      <div class="audit-intro"><span class="eyebrow">PEMERIKSAAN KATALOG</span><h2>Yang perlu dibereskan sebelum rilis</h2><p>Skill katalog lama masih tercatat sebagai Draft karena efeknya belum memiliki aturan battle final.</p></div>
      <div class="audit-grid">
        <section class="audit-panel"><header><span>DATA KARTU</span><b>{{ cardsMissingSkills.length }} perlu skill</b></header><p>Kartu non-fusion tanpa skill tertaut maupun deskripsi skill di metadata.</p><button v-for="card in cardsMissingSkills.slice(0, 12)" :key="card.id" type="button" class="audit-row">{{ card.name }} <small>{{ card.element || 'Tanpa elemen' }}</small></button><div v-if="!cardsMissingSkills.length" class="audit-ok">✓ Semua kartu memiliki skill.</div><small v-if="cardsMissingSkills.length > 12" class="more-note">dan {{ cardsMissingSkills.length - 12 }} kartu lainnya</small></section>
        <section class="audit-panel"><header><span>ATURAN SKILL</span><b>{{ incompleteSkills.length }} belum lengkap</b></header><p>Lengkapi pemicu, target, biaya, dan efek sebelum status Aktif dipilih.</p><button v-for="skill in incompleteSkills.slice(0, 12)" :key="skill.id" type="button" class="audit-row" @click="activeTab = 'skills'; selectSkill(skill.id)">{{ skill.name }} <small>{{ issueLabel(ruleIssues(skill)) }}</small></button><div v-if="!incompleteSkills.length" class="audit-ok">✓ Semua aturan siap.</div><small v-if="incompleteSkills.length > 12" class="more-note">dan {{ incompleteSkills.length - 12 }} skill lainnya</small></section>
        <section class="audit-panel"><header><span>RESEP FUSION</span><b>{{ incompleteRecipes.length }} belum siap</b></header><p>Resep harus aktif, memiliki kartu hasil, dan mempunyai material yang bisa diperiksa.</p><div v-for="recipe in incompleteRecipes.slice(0, 12)" :key="recipe.id" class="audit-row static">{{ recipe.result_name }}<small>{{ recipe.issues.join(' · ') }}</small></div><div v-if="!incompleteRecipes.length" class="audit-ok">✓ Semua resep siap.</div><small v-if="incompleteRecipes.length > 12" class="more-note">dan {{ incompleteRecipes.length - 12 }} resep lainnya</small></section>
      </div>
    </section>
  </main>
</template>

<style scoped>
.skill-catalog-page{--td-green:#0caf25;--td-deep:#087f1d;--td-pale:#eaf7e9;--td-ink:#183b24;--td-muted:#718575;min-height:100vh;padding:28px clamp(18px,3vw,42px) 48px;background:#f4f9f2;color:var(--td-ink);font-family:'DM Sans',sans-serif}
.catalog-heading{display:flex;align-items:flex-start;justify-content:space-between;gap:18px;margin:0 0 22px}.catalog-heading h1{margin:8px 0 6px;font:700 clamp(25px,3vw,37px)/1.05 'Space Grotesk',sans-serif;letter-spacing:-.045em}.catalog-heading p,.audit-intro p{margin:0;max-width:680px;color:var(--td-muted);font-size:12px;line-height:1.6}.eyebrow{color:#24923a;font-size:9px;font-weight:900;letter-spacing:.15em}.refresh-button,.secondary-button{border:1px solid #cfe4cf;border-radius:8px;padding:10px 13px;background:#fff;color:#277638;font-size:11px;font-weight:800;cursor:pointer}.notice{margin:10px 0;padding:11px 14px;border-radius:8px;font-size:11px}.notice-error{border:1px solid #f0c9bf;background:#fff4f0;color:#a43f2a}.notice-success{border:1px solid #cce8cb;background:#eef9ec;color:#2a7734}.metric-row{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:12px;margin-bottom:18px}.metric{display:flex;align-items:center;justify-content:space-between;min-height:72px;padding:14px 17px;border:1px solid #dce9dc;border-radius:10px;background:white;color:#55715b;text-align:left;cursor:pointer}.metric span{font-size:10px;font-weight:800}.metric strong{color:#21472a;font:700 25px 'Space Grotesk',sans-serif}.metric-active strong{color:var(--td-green)}.metric-warning strong{color:#bb7b19}.catalog-tabs,.history-tabs{display:flex;gap:6px;border-bottom:1px solid #dce8db;margin-bottom:14px}.catalog-tabs button,.history-tabs button{border:0;border-bottom:2px solid transparent;padding:10px 13px;background:transparent;color:#718575;font-size:11px;font-weight:800;cursor:pointer}.catalog-tabs button.selected,.history-tabs button.selected{border-bottom-color:var(--td-green);color:var(--td-deep)}.skill-workspace{display:grid;grid-template-columns:minmax(265px,340px) minmax(0,1fr);align-items:start;gap:16px}.skill-list-panel,.skill-editor-panel,.audit-panel{border:1px solid #dce9dc;border-radius:12px;background:white;box-shadow:0 5px 20px #1b50200a}.skill-list-panel{max-height:calc(100vh - 255px);min-height:550px;overflow:auto;padding:10px}.list-tools{position:sticky;z-index:2;top:-10px;display:grid;gap:7px;padding:0 0 10px;background:white}.list-tools input,.list-tools select,.skill-form input,.skill-form select,.skill-form textarea,.playtest-form input,.playtest-form select,.playtest-form textarea{width:100%;min-width:0;border:1px solid #d7e5d7;border-radius:7px;padding:9px 10px;background:#fff;color:#25462c;font:inherit;font-size:11px;outline-color:#5cbd64}.skill-list-item{display:flex;width:100%;align-items:center;gap:9px;margin:3px 0;padding:9px 7px;border:1px solid transparent;border-radius:8px;background:white;color:var(--td-ink);text-align:left;cursor:pointer}.skill-list-item:hover,.skill-list-item.selected{border-color:#cfe8ce;background:#f3faf1}.skill-item-icon{display:grid;place-items:center;width:30px;height:30px;flex:none;border-radius:7px;background:#e9f6e8;font-size:16px}.skill-item-copy{display:grid;flex:1;min-width:0;gap:3px}.skill-item-copy strong{overflow:hidden;font-size:10px;text-overflow:ellipsis;white-space:nowrap}.skill-item-copy small{overflow:hidden;color:#819184;font-size:8px;text-overflow:ellipsis;white-space:nowrap}.status-chip{flex:none;border-radius:999px;padding:4px 7px;background:#eef2ed;color:#687b69;font-size:8px;font-weight:900}.status-chip.draft{background:#fff3d6;color:#8a6412}.status-chip.playtest{background:#e8f4ff;color:#2e6d9c}.status-chip.active{background:#e2f5e3;color:#268139}.status-chip.archived{background:#f0eeee;color:#787574}.skill-editor-panel{min-width:0;padding:18px}.editor-heading{display:flex;align-items:flex-start;justify-content:space-between;gap:10px}.editor-heading h2{margin:5px 0 12px;font:700 22px 'Space Grotesk',sans-serif;letter-spacing:-.035em}.linked-cards{display:flex;flex-wrap:wrap;align-items:center;gap:6px;margin:0 0 16px;padding:10px;border-radius:8px;background:#f3f8f1}.linked-cards span{margin-right:3px;color:#829183;font-size:8px;font-weight:900;letter-spacing:.1em}.linked-cards b{border-radius:999px;padding:5px 8px;background:#e3f2e2;color:#327540;font-size:8px}.linked-cards em{color:#879388;font-size:9px;font-style:normal}.form-grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:11px 13px}.skill-form label,.playtest-form label{display:flex;flex-direction:column;gap:5px;color:#516b55;font-size:9px;font-weight:900}.skill-form label small{color:#a07831;font-size:8px;font-weight:600;line-height:1.4}.skill-form input,.skill-form select,.skill-form textarea,.playtest-form input,.playtest-form select,.playtest-form textarea{font-size:10px;font-weight:500}.skill-form textarea,.playtest-form textarea{resize:vertical;line-height:1.45}.span-two{grid-column:span 2}.check-row{display:flex;flex-wrap:wrap;gap:14px;margin:13px 0}.check-row label,.advanced-toggle{display:flex;align-items:center;gap:6px;color:#667d68;font-size:9px;font-weight:700}.check-row input,.advanced-toggle input{accent-color:var(--td-green)}.effect-editor{margin-top:7px;padding:13px;border:1px solid #deeadc;border-radius:9px;background:#f8fbf7}.subheading{display:flex;justify-content:space-between;align-items:center;gap:10px;margin-bottom:10px}.subheading h3{margin:4px 0 0;font:700 15px 'Space Grotesk',sans-serif}.effect-grid{grid-template-columns:repeat(3,minmax(0,1fr))}.form-hint,.runtime-note{margin:8px 0 0;color:#819184;font-size:9px;line-height:1.5}.json-field{display:flex;flex-direction:column;gap:5px;color:#516b55;font-size:9px;font-weight:900}.json-field textarea,.history-entry pre{font:10px/1.5 ui-monospace,SFMono-Regular,Menlo,monospace}.readiness-panel{margin-top:12px;padding:11px 13px;border:1px solid #f0deac;border-radius:8px;background:#fff9e9}.readiness-panel.ready{border-color:#cde6ca;background:#eff9ee}.readiness-panel>div{display:flex;align-items:center;gap:9px}.readiness-panel>div>span{display:grid;place-items:center;width:23px;height:23px;border-radius:50%;background:#f6e8ba;color:#876311;font-weight:900}.readiness-panel.ready>div>span{background:#d4efd2;color:#2a843b}.readiness-panel strong{display:block;font-size:10px}.readiness-panel small{display:block;margin-top:3px;color:#9a7730;font-size:8px}.readiness-panel ul{margin:9px 0 0;padding-left:18px;color:#876c2b;font-size:9px;line-height:1.6}.change-note{display:flex;flex-direction:column;gap:5px;margin-top:12px;color:#526d57;font-size:9px;font-weight:900}.form-actions{display:flex;justify-content:flex-end;margin-top:11px}.primary-button{border:0;border-radius:8px;padding:11px 15px;background:var(--td-green);color:white;font-size:10px;font-weight:900;cursor:pointer}.primary-button:disabled,.secondary-button:disabled{opacity:.55;cursor:wait}.history-block{margin-top:20px;padding-top:14px;border-top:1px solid #e1ebdf}.history-tabs{margin-bottom:11px}.playtest-form{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:9px}.playtest-form .secondary-button{justify-self:start}.history-entry{margin:8px 0;padding:11px 12px;border:1px solid #e5eee4;border-radius:8px;background:#fcfefb}.history-entry>div{display:flex;justify-content:space-between;gap:10px}.history-entry>div strong{color:#376d3c;font-size:10px}.history-entry>div small{color:#8a998b;font-size:8px}.history-entry p{margin:7px 0 0;color:#5f7362;font-size:9px;line-height:1.5}.history-entry details{margin-top:8px;color:#408044;font-size:9px}.history-entry pre{max-height:260px;overflow:auto;padding:10px;border-radius:7px;background:#eff6ed;color:#456148}.empty-history,.empty-list,.empty-editor{padding:25px;color:#8a998b;text-align:center;font-size:10px}.audit-intro{margin:0 0 16px}.audit-intro h2{margin:6px 0;font:700 21px 'Space Grotesk',sans-serif}.audit-grid{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));align-items:start;gap:13px}.audit-panel{padding:14px}.audit-panel>header{display:flex;align-items:center;justify-content:space-between;gap:8px}.audit-panel>header span{color:#718675;font-size:8px;font-weight:900;letter-spacing:.1em}.audit-panel>header b{color:#33803e;font-size:9px}.audit-panel>p{min-height:43px;margin:8px 0;color:#829084;font-size:9px;line-height:1.45}.audit-row{display:flex;width:100%;justify-content:space-between;gap:9px;margin:5px 0;padding:8px;border:1px solid #e5eee4;border-radius:7px;background:#fbfdf9;color:#355a3a;text-align:left;font-size:9px;cursor:pointer}.audit-row small{max-width:54%;overflow:hidden;color:#8a937e;text-align:right;text-overflow:ellipsis;white-space:nowrap}.audit-row.static{cursor:default}.audit-ok{padding:16px 5px;color:#398245;font-size:10px;font-weight:800}.more-note{display:block;margin:8px;color:#849286;font-size:8px}.skill-list-panel::-webkit-scrollbar{width:8px}.skill-list-panel::-webkit-scrollbar-thumb{border-radius:999px;background:#dceadb}.skill-list-panel::-webkit-scrollbar-track{background:#f6faf5}
@media(max-width:1100px){.skill-workspace{grid-template-columns:minmax(230px,290px) minmax(0,1fr)}.audit-grid{grid-template-columns:1fr}.audit-panel>p{min-height:0}}
@media(max-width:800px){.skill-workspace{grid-template-columns:1fr}.skill-list-panel{max-height:330px;min-height:0}.metric-row{grid-template-columns:repeat(2,minmax(0,1fr))}.skill-editor-panel{padding:14px}}
@media(max-width:560px){.catalog-heading{align-items:stretch;flex-direction:column}.refresh-button{align-self:flex-start}.form-grid,.effect-grid,.playtest-form{grid-template-columns:1fr}.span-two{grid-column:auto}.check-row{flex-direction:column;gap:8px}.metric{min-height:60px;padding:10px}.metric strong{font-size:21px}.skill-list-item{gap:6px}.status-chip{font-size:7px;padding:4px 5px}.editor-heading h2{font-size:19px}}
.catalog-skill-media{display:flex;align-items:center;gap:16px;margin:0 0 18px;padding:14px;border:1px solid #d7e5d7;border-radius:12px;background:#f4faf2}
.studio-rule-note{margin:0 22px 18px;padding:12px 14px;border:1px solid #d7e5d7;border-radius:10px;background:#f4faf2;color:#42664a;font-size:12px;line-height:1.6}
.skill-catalog-embedded{padding:12px;min-height:0;background:white}.skill-catalog-embedded .skill-workspace{display:block}.skill-catalog-embedded .skill-list-panel{display:flex;flex-wrap:wrap;position:static;max-height:none;padding:6px;gap:6px;margin-bottom:12px}.skill-catalog-embedded .skill-list-item{flex:1;min-width:140px;padding:10px;min-height:68px}.skill-catalog-embedded .skill-item-icon{width:32px;height:32px;flex:none}.skill-catalog-embedded .skill-item-copy{min-width:0}.skill-catalog-embedded .skill-item-copy small,.skill-catalog-embedded .linked-cards{display:none}.skill-catalog-embedded .editor-heading{padding:14px}.skill-catalog-embedded .editor-heading h2{font-size:20px}.skill-catalog-embedded .form-grid{grid-template-columns:1fr}.skill-catalog-embedded .span-two{grid-column:auto}.skill-catalog-embedded .skill-form{padding:12px}.skill-catalog-embedded .studio-rule-note{margin:0 12px 12px;font-size:11px}.skill-catalog-embedded .skill-form :is(input,textarea,select){font-size:12px}.skill-catalog-embedded .catalog-skill-media{padding:10px;gap:10px}.skill-catalog-embedded .catalog-skill-art{width:48px;height:48px}.skill-catalog-embedded .form-actions{position:sticky;bottom:0;background:#fff;padding:10px 0}.skill-catalog-embedded .form-actions button{width:100%}
.skill-catalog-embedded .skill-list-panel{min-height:0;align-items:start}.skill-catalog-embedded .skill-editor-panel{padding:0}.skill-catalog-embedded .skill-form label{font-size:11px;font-weight:650}.skill-catalog-embedded .skill-form label small{font-size:10px}
.catalog-skill-art{display:grid;place-items:center;flex:none;width:76px;height:76px;overflow:hidden;border:1px solid #ccdfcc;border-radius:16px;background:#fff;font-size:36px}
.catalog-skill-media>div{flex:1;min-width:0}
.catalog-skill-media p{margin:8px 0 0;color:#657d69;font-size:11px;line-height:1.5}
.skill-item-icon{overflow:hidden}
.skill-form .catalog-skill-media label{font-size:11px}
.skill-form .catalog-skill-media input{font-size:12px}
@media(max-width:520px){.catalog-skill-media{align-items:flex-start;gap:10px;padding:10px}.catalog-skill-art{width:52px;height:52px;border-radius:10px}}
</style>
