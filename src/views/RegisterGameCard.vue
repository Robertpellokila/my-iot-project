<script setup>
import {useAdminFeedback} from '../composables/useAdminToast.js';
import SearchableSelect from "../components/SearchableSelect.vue";
import SkillIcon from '../components/battle/SkillIcon.vue';
import { splitSkillIcon, skillMediaValue, skillLimitLabel, skillOptionLabel, describeBasicSkill } from '../lib/battle/skillPresentation.js';

import { ref, computed, watch, onMounted, onUnmounted, onActivated, onDeactivated } from "vue";

import { useRouter, useRoute } from "vue-router";

import { supabase } from "../lib/supabase"; // Sesuaikan path Supabase kamu
import { compressImageFile, IMAGE_UPLOAD_LIMITS } from "../lib/compressImage";

const router = useRouter();
const route = useRoute();

// State Form Pendaftaran/Edit Kartu Game

const cardName = ref("");

const cardLevel = ref(1);

const cardRarity = ref("common");

const cardLore = ref("");

const cardMetadata = ref({});

const element = ref("Fire");

const hp = ref(120);

const attack = ref(45);

const defense = ref(30);

const imageUrl = ref("🔥");
const compressedCardImage = ref(null);
const compressedImagePreview = ref("");
const compressingImage = ref(false);
const cardImageInput = ref(null);
const cardImagePreviewUrl = computed(() => compressedImagePreview.value || imageUrl.value);
const physicalCardImageUrl = ref("");
const compressedPhysicalCardImage = ref(null);
const physicalCardImagePreview = ref("");
const physicalCardImageInput = ref(null);
const avatarImageFile = ref(null);
const avatarImagePreview = ref("");
const avatarImageInput = ref(null);
const physicalCardPreviewUrl = computed(() => physicalCardImagePreview.value || physicalCardImageUrl.value);
const avatarPreviewUrl = computed(() => avatarImagePreview.value || avatarUrl.value);
const compressedSizeLabel = computed(() => compressedCardImage.value
  ? `${(compressedCardImage.value.size / 1024).toFixed(0)} KB WebP setelah kompres`
  : "JPG/PNG/WebP · maks. 10 MB · hasil WebP maks. 1 MB");

const uid = ref("");


const avatarUrl = ref("");


// =========================================================
// REGISTER CARD UX / BENTO HELPERS
// =========================================================

// Code fields start in automatic mode for new content. When editing existing
// records we preserve the stored code until "Gunakan Auto Code" is enabled.
const cardCodeAuto = ref(true);
const fusionRecipeCodeAuto = ref(true);
const skillCodeAuto = ref(true);

// Element is stored as text in game_cards, so the UI can safely discover
// existing values and add new ones without a schema migration.
const DEFAULT_ELEMENTS = [
  "Knight",
  "Fire",
  "Water",
  "Forest",
  "Thunder",
  "Light",
  "Dark",
];

const customElements = ref([]);
const newElementName = ref("");

const normalizeElementLabel = (value) =>
  String(value ?? "")
    .trim()
    .replace(/\s+/g, " ")
    .replace(/\b\w/g, (char) => char.toUpperCase());

const elementOptions = computed(() => {
  const values = new Map();

  const add = (value) => {
    const normalized = normalizeElementLabel(value);
    if (!normalized) return;
    const key = normalized.toLowerCase();
    if (!values.has(key)) values.set(key, normalized);
  };

  DEFAULT_ELEMENTS.forEach(add);
  gameCardCatalog.value.forEach((card) => add(card?.element));
  customElements.value.forEach(add);
  add(element.value);

  return [...values.values()].sort((a, b) => a.localeCompare(b));
});

const synergySupportedElements = new Set([
  "knight",
  "fire",
  "water",
  "forest",
  "thunder",
  "light",
  "dark",
]);

const canonicalElement = (value) => {
  const aliases = {
    electric: "thunder",
    lightning: "thunder",
    wind: "thunder",
    ice: "water",
    grass: "forest",
    nature: "forest",
    holy: "light",
    warrior: "knight",
    shadow: "dark",
  };
  const key = String(value ?? "").trim().toLowerCase();
  return aliases[key] ?? key;
};

const elementSupportsSynergy = computed(() =>
  synergySupportedElements.has(canonicalElement(element.value)),
);

const persistCustomElements = () => {
  if (typeof window === "undefined") return;

  try {
    window.localStorage.setItem(
      "tcg_custom_elements",
      JSON.stringify(customElements.value),
    );
  } catch (error) {
    console.warn("Tidak dapat menyimpan custom element ke localStorage:", error);
  }
};

const loadStoredElements = () => {
  if (typeof window === "undefined") return;

  try {
    const parsed = JSON.parse(
      window.localStorage.getItem("tcg_custom_elements") || "[]",
    );

    customElements.value = Array.isArray(parsed)
      ? parsed.map(normalizeElementLabel).filter(Boolean)
      : [];
  } catch {
    customElements.value = [];
  }
};

const addElementOption = () => {
  const nextElement = normalizeElementLabel(newElementName.value);

  if (!nextElement) {
    errorMessage.value = "Nama element baru tidak boleh kosong.";
    return;
  }

  const exists = elementOptions.value.some(
    (item) => item.toLowerCase() === nextElement.toLowerCase(),
  );

  if (!exists) {
    customElements.value = [...customElements.value, nextElement];
    persistCustomElements();
  }

  element.value = nextElement;
  newElementName.value = "";
  errorMessage.value = "";
  successMessage.value = `Element "${nextElement}" siap digunakan.`;
};

const enableAutoCardCode = () => {
  if (cardMode.value === "copy") return;
  cardCodeAuto.value = true;
  cardCode.value = slugifyCardCode(cardName.value);
};

const enableAutoFusionRecipeCode = () => {
  fusionRecipeCodeAuto.value = true;
  fusionRecipeCode.value = slugifyFusionRecipeCode(fusionRecipeName.value);
};

const enableAutoSkillCode = () => {
  skillCodeAuto.value = true;
  skillCode.value = slugifySkillCode(skillName.value);
};



// =========================================================
// PHASE 3D.1 - CARD MODE / IDENTITY
// =========================================================

// new    = Physical Card baru / edit Physical Card lewat scan RFID
// copy   = Physical Card baru dengan UID baru, data dicopy dari card type lama
// fusion = Virtual Fusion Card, tanpa RFID
const cardMode = ref("new");

const cardCode = ref("");
const tagsInput = ref("");

const gameCardCatalog = ref([]);
const copySourceCardId = ref("");
const selectedFusionCardId = ref("");


// =========================================================
// PHASE 3D.6 - FUSION RECIPE UI
// =========================================================

const fusionRecipeEnabled = ref(false);
const fusionRecipes = ref([]);
const selectedFusionRecipeId = ref("");

const fusionRecipeCode = ref("");
const fusionRecipeName = ref("");
const fusionRecipeDescription = ref("");
const fusionRecipeIcon = ref("🔥");
const fusionConsumesTurn = ref(true);
const fusionOncePerBattle = ref(true);
const fusionMaxUses = ref(1);

const fusionHpMode = ref("material_sum_percent");
const fusionHpValue = ref(0.8);
const fusionAttackMode = ref("material_sum_percent");
const fusionAttackValue = ref(0.8);
const fusionDefenseMode = ref("material_sum_percent");
const fusionDefenseValue = ref(0.8);

let fusionRequirementKey = 0;

const createFusionRequirement = () => ({
  _key: ++fusionRequirementKey,
  material_type: "exact_card",
  quantity: 1,
  card_code: "",
  card_codes: [],
  tag: "",
  allowed_zones: ["active", "bench"],
});

const fusionRequirements = ref([createFusionRequirement()]);


// =========================================================
// SPECIAL SKILL
// =========================================================

// Phase 3C UI awal:
// satu Special Skill aktif per Card.
// Database tetap mendukung banyak skill per card.
const specialSkillMode = ref("none"); // none | existing | new | edit
const specialSkills = ref([]);
const catalogSkills = ref([]);
const allSkillDefinitions = ref([]);
const selectedSpecialSkillId = ref("");
const existingRelationId = ref(null);
const existingCardSkillRelations = ref([]);
const builtinSkillSelections = ref({});

// Form pembuatan Special Skill baru
const skillName = ref("");
const skillCode = ref("");
const skillDescription = ref("");
const skillIcon = ref("✨");
const skillImageUrl = ref('');
const skillActionPoints = ref(1);
const skillType = ref("active");
const activationTiming = ref("main_phase");
const skillTargetType = ref("enemy_active");
const skillCostType = ref("none");
const skillCostValue = ref(0);
const skillCooldownRounds = ref(0);
const skillCooldownUnit = ref("owner");
const skillMaxUses = ref(0);
const skillOncePerBattle = ref(false);
const skillConsumesTurn = ref(true);

// Simple Effect Builder
const skillEffectType = ref("damage_card");
const skillEffectAmount = ref(30);
const skillAdvancedMode = ref(false);

const DEFAULT_EFFECTS_JSON = `[
  {
    "type": "damage_card",
    "target": "target_card",
    "owner": "enemy",
    "allowed_zones": ["active"],
    "amount": {
      "mode": "fixed",
      "value": 30
    }
  }
]`;

const skillEffectsJson = ref(DEFAULT_EFFECTS_JSON);



// Mode penanda apakah kartu sudah terdaftar sebelumnya

const isExistingCard = ref(false);

const recordId = ref(null);



const loading = ref(false);

const errorMessage = ref("");

const successMessage = ref("");



const isImageUrl = (str) =>

  str && (str.startsWith("http") || str.startsWith("/") || str.startsWith("blob:"));



let realtimeChannel;
let registrationActive = true;
let registrationLoaded = false;
const stopRegistrationListener = () => {
  if (realtimeChannel) supabase.removeChannel(realtimeChannel);
  realtimeChannel = null;
};


// =========================================================
// CARD IDENTITY HELPERS
// =========================================================

const slugifyCardCode = (value) =>
  String(value ?? "")
    .trim()
    .toUpperCase()
    .replace(/[^A-Z0-9]+/g, "_")
    .replace(/^_+|_+$/g, "");


const parseTags = (value) =>
  [...new Set(
    String(value ?? "")
      .split(/[,\n]/)
      .map((tag) => tag.trim().toLowerCase())
      .filter(Boolean),
  )];


const formatTagsInput = (tags) =>
  Array.isArray(tags) ? tags.join(", ") : "";


const physicalCopySources = computed(() => {
  const templates=gameCardCatalog.value.filter(card=>!card.fusion_only&&!card.uid);
  const codes=new Set(templates.map(card=>card.card_code)),physical=[];
  for(const card of gameCardCatalog.value){if(card.fusion_only||!card.uid||codes.has(card.card_code))continue;codes.add(card.card_code);physical.push(card);}
  return [...templates,...physical].sort((a, b) =>
    String(a?.name ?? "").localeCompare(String(b?.name ?? "")),
  );
});


const fusionCardOptions = computed(() =>
  gameCardCatalog.value
    .filter((card) => Boolean(card?.fusion_only))
    .sort((a, b) =>
      String(a?.name ?? "").localeCompare(String(b?.name ?? "")),
    ),
);


// Material Fusion boleh berasal dari Physical Card maupun Fusion Result
// (mendukung Fusion chain / evolution chain). Dedupe berdasarkan card_code.
const fusionMaterialCardOptions = computed(() => {
  const byCode = new Map();

  for (const card of gameCardCatalog.value) {
    const code = String(card?.card_code ?? "").trim();
    if (!code || byCode.has(code)) continue;
    byCode.set(code, card);
  }

  return [...byCode.values()].sort((a, b) =>
    String(a?.name ?? "").localeCompare(String(b?.name ?? "")),
  );
});


const loadGameCardCatalog = async () => {
  const { data, error } = await supabase
    .from("game_cards")
    .select("*")
    .order("name", { ascending: true });

  if (error) {
    console.error("Load Game Card Catalog:", error);
    return;
  }

  gameCardCatalog.value = data ?? [];
};


const clearCardFields = ({ keepUid = false } = {}) => {
  clearCardImage();
  clearAdditionalCardImages();
  if (!keepUid) {
    uid.value = "";
  }

  cardName.value = "";
  cardLevel.value = 1;
  cardRarity.value = "common";
  cardLore.value = "";
  cardMetadata.value = {};
  cardCodeAuto.value = true;
  cardCode.value = "";
  tagsInput.value = "";
  element.value = "Fire";
  hp.value = 120;
  attack.value = 45;
  defense.value = 30;
  imageUrl.value = "🔥";
  avatarUrl.value = "";
  physicalCardImageUrl.value = "";

  isExistingCard.value = false;
  recordId.value = null;
  resetSpecialSkillState();
};


const applyCardDataToForm = async (card, { keepUid = false } = {}) => {
  if (!card) return;
  clearCardImage();
  clearAdditionalCardImages();

  if (!keepUid) {
    uid.value = card.uid ?? "";
  }

  cardName.value = card.name ?? "";
  cardLevel.value = Number(card.level ?? 1);
  cardRarity.value = card.rarity ?? "common";
  cardLore.value = card.lore ?? "";
  cardMetadata.value = card.metadata ?? {};
  cardCode.value = card.card_code ?? slugifyCardCode(card.name);
  cardCodeAuto.value = false;
  tagsInput.value = formatTagsInput(card.tags);
  element.value = card.element ?? "Fire";
  hp.value = Number(card.hp ?? 120);
  attack.value = Number(card.attack ?? 45);
  defense.value = Number(card.defense ?? 30);
  imageUrl.value = card.image_url || "🔥";
  avatarUrl.value = card.avatar_url || "";
  avatarImagePreview.value = "";
  physicalCardImageUrl.value = card.physical_card_image_url || "";
  physicalCardImagePreview.value = "";

  await loadCardSpecialSkill(card.id);
};


const handleCardModeChange = async () => {
  errorMessage.value = "";
  successMessage.value = "";
  copySourceCardId.value = "";
  selectedFusionCardId.value = "";

  if (cardMode.value === "fusion") {
    clearCardFields();
    resetFusionRecipeState({ enabled: true });
    uid.value = "";
    successMessage.value =
      "Mode Fusion Card aktif. RFID tidak diperlukan. Kamu juga bisa membuat Fusion Recipe di form ini.";
    return;
  }

  const scannedUid = uid.value;
  clearCardFields({ keepUid: true });
  uid.value = scannedUid;

  if (cardMode.value === "copy") {
    successMessage.value = uid.value
      ? "UID baru siap. Pilih Existing Card Type yang ingin dicopy."
      : "Pilih kartu tersimpan, lalu scan RFID baru untuk menghubungkannya.";
  } else {
    successMessage.value = uid.value
      ? "Mode New Physical Card aktif."
      : "Scan RFID untuk membuat Physical Card baru.";
  }
};


const loadCopySourceCard = async () => {
  errorMessage.value = "";

  const source = gameCardCatalog.value.find(
    (card) => card.id === copySourceCardId.value,
  );

  if (!source) {
    return;
  }

  const newUid = uid.value;

  await applyCardDataToForm(source, { keepUid: true });
  cardMetadata.value={...cardMetadata.value,catalog_source_id:source.id,studio_template:false};

  uid.value = newUid;
  cardCode.value = source.card_code ?? slugifyCardCode(source.name);
  cardCodeAuto.value = false;
  isExistingCard.value = false;
  recordId.value = null;
  existingRelationId.value = null;

  successMessage.value =
    `Data ${source.name} dicopy. UID RFID baru tetap ${newUid || "belum discan"}.`;
};


const loadFusionCardForEdit = async () => {
  errorMessage.value = "";

  if (!selectedFusionCardId.value) {
    clearCardFields();
    resetFusionRecipeState({ enabled: true });
    uid.value = "";
    cardMode.value = "fusion";
    successMessage.value = "Membuat Fusion Card dan Fusion Recipe baru.";
    return;
  }

  const card = gameCardCatalog.value.find(
    (item) => item.id === selectedFusionCardId.value && item.fusion_only,
  );

  if (!card) {
    errorMessage.value = "Fusion Card tidak ditemukan.";
    return;
  }

  await applyCardDataToForm(card);
  uid.value = "";
  recordId.value = card.id;
  isExistingCard.value = true;

  await loadFusionRecipesForCard(card.id);

  successMessage.value = `Fusion Card "${card.name}" beserta Fusion Recipe dimuat dalam Mode Edit.`;
};


// =========================================================
// FUSION RECIPE HELPERS
// =========================================================

const slugifyFusionRecipeCode = (value) =>
  String(value ?? "")
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "_")
    .replace(/^_+|_+$/g, "");


const resetFusionRecipeState = ({ enabled = false } = {}) => {
  fusionRecipeEnabled.value = enabled;
  fusionRecipes.value = [];
  selectedFusionRecipeId.value = "";

  fusionRecipeCodeAuto.value = true;
  fusionRecipeCode.value = "";
  fusionRecipeName.value = "";
  fusionRecipeDescription.value = "";
  fusionRecipeIcon.value = "🔥";
  fusionConsumesTurn.value = true;
  fusionOncePerBattle.value = true;
  fusionMaxUses.value = 1;

  fusionHpMode.value = "material_sum_percent";
  fusionHpValue.value = 0.8;
  fusionAttackMode.value = "material_sum_percent";
  fusionAttackValue.value = 0.8;
  fusionDefenseMode.value = "material_sum_percent";
  fusionDefenseValue.value = 0.8;

  fusionRequirements.value = [createFusionRequirement()];
};


const prepareNewFusionRecipe = () => {
  const currentRecipes = fusionRecipes.value;
  resetFusionRecipeState({ enabled: true });
  fusionRecipeCodeAuto.value = true;
  fusionRecipes.value = currentRecipes;

  const baseName = cardName.value.trim();
  const baseCode = cardCode.value.trim() || slugifyCardCode(baseName);

  fusionRecipeName.value = baseName
    ? `${baseName} Fusion`
    : "";

  fusionRecipeCode.value = baseCode
    ? slugifyFusionRecipeCode(`${baseCode}_fusion`)
    : "";
};


const addFusionRequirement = () => {
  fusionRequirements.value.push(createFusionRequirement());
};


const removeFusionRequirement = (index) => {
  if (fusionRequirements.value.length <= 1) {
    errorMessage.value = "Fusion Recipe minimal memiliki 1 requirement.";
    return;
  }

  fusionRequirements.value.splice(index, 1);
};


const normalizeLoadedRequirement = (row) => ({
  _key: ++fusionRequirementKey,
  material_type:
    row?.material_type === "specific_card"
      ? "exact_card"
      : row?.material_type || "exact_card",
  quantity: Number(row?.quantity ?? 1),
  card_code: row?.card_code ?? "",
  card_codes: Array.isArray(row?.card_codes) ? row.card_codes : [],
  tag: row?.tag ?? "",
  allowed_zones:
    Array.isArray(row?.allowed_zones) && row.allowed_zones.length
      ? row.allowed_zones
      : ["active", "bench"],
});


const loadSelectedFusionRecipe = async () => {
  errorMessage.value = "";

  if (!selectedFusionRecipeId.value) {
    prepareNewFusionRecipe();
    return;
  }

  const recipe = fusionRecipes.value.find(
    (item) => item.id === selectedFusionRecipeId.value,
  );

  if (!recipe) {
    errorMessage.value = "Fusion Recipe tidak ditemukan.";
    return;
  }

  fusionRecipeEnabled.value = true;
  fusionRecipeCode.value = recipe.code ?? "";
  fusionRecipeCodeAuto.value = false;
  fusionRecipeName.value = recipe.name ?? "";
  fusionRecipeDescription.value = recipe.description ?? "";
  fusionRecipeIcon.value = recipe.icon ?? "🔥";
  fusionConsumesTurn.value = Boolean(recipe.consumes_turn ?? true);
  fusionOncePerBattle.value = Boolean(recipe.limits?.once_per_battle ?? false);
  fusionMaxUses.value = Number(recipe.limits?.max_uses ?? 0);

  fusionHpMode.value = recipe.result_stat_spec?.hp?.mode ?? "material_sum_percent";
  fusionHpValue.value = Number(recipe.result_stat_spec?.hp?.value ?? 0.8);
  fusionAttackMode.value = recipe.result_stat_spec?.attack?.mode ?? "material_sum_percent";
  fusionAttackValue.value = Number(recipe.result_stat_spec?.attack?.value ?? 0.8);
  fusionDefenseMode.value = recipe.result_stat_spec?.defense?.mode ?? "material_sum_percent";
  fusionDefenseValue.value = Number(recipe.result_stat_spec?.defense?.value ?? 0.8);

  const { data, error } = await supabase
    .from("fusion_recipe_materials")
    .select("*")
    .eq("recipe_id", recipe.id)
    .order("sort_order", { ascending: true });

  if (error) throw error;

  fusionRequirements.value = (data ?? []).length
    ? data.map(normalizeLoadedRequirement)
    : [createFusionRequirement()];
};


const loadFusionRecipesForCard = async (gameCardId) => {
  if (!gameCardId) {
    resetFusionRecipeState({ enabled: true });
    return;
  }

  const { data, error } = await supabase
    .from("fusion_recipes")
    .select("*")
    .eq("result_game_card_id", gameCardId)
    .order("priority", { ascending: true })
    .order("created_at", { ascending: true });

  if (error) throw error;

  fusionRecipes.value = data ?? [];
  fusionRecipeEnabled.value = true;

  if (fusionRecipes.value.length) {
    selectedFusionRecipeId.value = fusionRecipes.value[0].id;
    await loadSelectedFusionRecipe();
  } else {
    selectedFusionRecipeId.value = "";
    prepareNewFusionRecipe();
  }
};


const validateFusionRequirements = () => {
  if (!fusionRequirements.value.length) {
    throw new Error("Fusion Recipe minimal mempunyai 1 material requirement.");
  }

  for (let index = 0; index < fusionRequirements.value.length; index += 1) {
    const req = fusionRequirements.value[index];
    const label = `Material #${index + 1}`;

    if (!Number.isFinite(Number(req.quantity)) || Number(req.quantity) < 1) {
      throw new Error(`${label}: Quantity minimal 1.`);
    }

    if (!Array.isArray(req.allowed_zones) || req.allowed_zones.length === 0) {
      throw new Error(`${label}: pilih minimal satu zone.`);
    }

    if (req.material_type === "exact_card" && !String(req.card_code ?? "").trim()) {
      throw new Error(`${label}: pilih Exact Card.`);
    }

    if (req.material_type === "one_of" && (!Array.isArray(req.card_codes) || req.card_codes.length === 0)) {
      throw new Error(`${label}: pilih minimal satu alternatif Card.`);
    }

    if (req.material_type === "tag" && !String(req.tag ?? "").trim()) {
      throw new Error(`${label}: Tag wajib diisi.`);
    }
  }
};


const syncFusionRecipe = async (resultGameCardId) => {
  if (cardMode.value !== "fusion" || !fusionRecipeEnabled.value) {
    return null;
  }

  const finalRecipeCode = slugifyFusionRecipeCode(
    fusionRecipeCode.value.trim() || `${cardCode.value}_fusion`,
  );

  const finalRecipeName =
    fusionRecipeName.value.trim() ||
    `${cardName.value.trim() || "Fusion Card"} Fusion`;

  if (!finalRecipeCode) {
    throw new Error("Fusion Recipe Code wajib diisi.");
  }

  if (!finalRecipeName) {
    throw new Error("Nama Fusion Recipe wajib diisi.");
  }

  validateFusionRequirements();

  const recipePayload = {
    code: finalRecipeCode,
    name: finalRecipeName,
    description: fusionRecipeDescription.value.trim() || null,
    icon: fusionRecipeIcon.value.trim() || "🔥",
    result_game_card_id: resultGameCardId,
    result_zone: "active",
    material_destination: "graveyard",
    requirements: {},
    result_overrides: {},
    consumes_turn: Boolean(fusionConsumesTurn.value),
    is_active: true,
    cost_spec: { type: "none", value: 0 },
    limits: {
      once_per_battle: Boolean(fusionOncePerBattle.value),
      max_uses: Math.max(0, Number(fusionMaxUses.value ?? 0)),
    },
    conditions: {},
    result_stat_spec: {
      hp: {
        mode: fusionHpMode.value,
        value: Number(fusionHpValue.value ?? 0),
      },
      attack: {
        mode: fusionAttackMode.value,
        value: Number(fusionAttackValue.value ?? 0),
      },
      defense: {
        mode: fusionDefenseMode.value,
        value: Number(fusionDefenseValue.value ?? 0),
      },
    },
    priority: 100,
    metadata: { configured_from: "register_card_fusion_ui_v1" },
  };

  let recipeId = selectedFusionRecipeId.value || null;

  if (recipeId) {
    const { error } = await supabase
      .from("fusion_recipes")
      .update(recipePayload)
      .eq("id", recipeId);

    if (error) throw error;
  } else {
    const { data, error } = await supabase
      .from("fusion_recipes")
      .insert(recipePayload)
      .select("id")
      .single();

    if (error) throw error;
    recipeId = data.id;
    selectedFusionRecipeId.value = recipeId;
  }

  const { error: deleteError } = await supabase
    .from("fusion_recipe_materials")
    .delete()
    .eq("recipe_id", recipeId);

  if (deleteError) throw deleteError;

  const materialRows = fusionRequirements.value.map((req, index) => ({
    recipe_id: recipeId,
    group_key: "main",
    material_type: req.material_type,
    game_card_id: null,
    element: null,
    rarity: null,
    min_level: null,
    max_level: null,
    quantity: Math.max(1, Number(req.quantity ?? 1)),
    allowed_zones: [...req.allowed_zones],
    optional: false,
    metadata: {},
    card_code:
      req.material_type === "exact_card"
        ? slugifyCardCode(req.card_code)
        : null,
    card_codes:
      req.material_type === "one_of"
        ? [...new Set(req.card_codes.map(slugifyCardCode).filter(Boolean))]
        : [],
    tag:
      req.material_type === "tag"
        ? String(req.tag ?? "").trim().toLowerCase()
        : null,
    sort_order: (index + 1) * 10,
  }));

  const { error: materialError } = await supabase
    .from("fusion_recipe_materials")
    .insert(materialRows);

  if (materialError) throw materialError;

  fusionRecipeCode.value = finalRecipeCode;
  await loadFusionRecipesForCard(resultGameCardId);

  const savedRecipe = fusionRecipes.value.find((item) => item.id === recipeId);
  if (savedRecipe) {
    selectedFusionRecipeId.value = recipeId;
    await loadSelectedFusionRecipe();
  }

  return recipeId;
};


// =========================================================
// SPECIAL SKILL HELPERS
// =========================================================

const resetNewSkillForm = () => {
  skillCodeAuto.value = true;
  skillName.value = "";
  skillCode.value = "";
  skillDescription.value = "";
  skillIcon.value = "✨";
  skillImageUrl.value = '';
  skillActionPoints.value = 1;
  skillType.value = "active";
  activationTiming.value = "main_phase";
  skillTargetType.value = "enemy_active";
  skillCostType.value = "none";
  skillCostValue.value = 0;
  skillCooldownRounds.value = 0;
  skillCooldownUnit.value = "owner";
  skillMaxUses.value = 0;
  skillOncePerBattle.value = false;
  skillConsumesTurn.value = true;
  skillEffectType.value = "damage_card";
  skillEffectAmount.value = 30;
  skillAdvancedMode.value = false;
  skillEffectsJson.value = DEFAULT_EFFECTS_JSON;
};


const resetSpecialSkillState = () => {
  specialSkillMode.value = "none";
  selectedSpecialSkillId.value = "";
  existingRelationId.value = null;
  existingCardSkillRelations.value = [];
  builtinSkillSelections.value = {};
  resetNewSkillForm();
};


const slugifySkillCode = (value) =>
  String(value ?? "")
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "_")
    .replace(/^_+|_+$/g, "");


// =========================================================
// AUTO CODE WATCHERS
// =========================================================

watch(cardName, (value) => {
  if (cardMode.value === "copy" || !cardCodeAuto.value) return;
  cardCode.value = slugifyCardCode(value);
});

watch(fusionRecipeName, (value) => {
  if (!fusionRecipeCodeAuto.value) return;
  fusionRecipeCode.value = slugifyFusionRecipeCode(value);
});

watch(skillName, (value) => {
  if (!skillCodeAuto.value) return;
  skillCode.value = slugifySkillCode(value);
});


const selectedSpecialSkill = computed(() =>
  allSkillDefinitions.value.find(
    (skill) => skill.id === selectedSpecialSkillId.value,
  ) ?? null,
);
const selectedSkillIsActiveOption = computed(() =>
  specialSkills.value.some((skill) => skill.id === selectedSpecialSkillId.value),
);

const normalizeSkillIdentity = (value) => String(value ?? "")
  .trim()
  .toLocaleLowerCase()
  .replace(/\s+/g, " ");

const builtinCardSkills = computed(() => {
  const metadataSkills = Array.isArray(cardMetadata.value?.skills)
    ? cardMetadata.value.skills
    : [];
  const seen = new Set();

  return metadataSkills.flatMap((entry, index) => {
    const name = String(entry?.name ?? "").trim();
    const identity = normalizeSkillIdentity(entry?.code || name);
    if (!identity || seen.has(identity)) return [];
    seen.add(identity);

    const bound = existingCardSkillRelations.value.find(relation =>
      Number(relation.sort_order) === Number(entry?.slot ?? index + 1)
      && allSkillDefinitions.value.some(skill => skill.id === relation.special_skill_id && skill.metadata?.studio_generated),
    );
    const definition = (bound && allSkillDefinitions.value.find(skill => skill.id === bound.special_skill_id)) || allSkillDefinitions.value.find((skill) => {
      const codeMatches = entry?.code && normalizeSkillIdentity(skill.code) === normalizeSkillIdentity(entry.code);
      return codeMatches || normalizeSkillIdentity(skill.name) === normalizeSkillIdentity(name);
    }) || null;
    const relation = definition
      ? existingCardSkillRelations.value.find((item) => String(item.special_skill_id) === String(definition.id))
      : null;
    const battleReady = Boolean(
      definition?.is_active
      && definition?.catalog_status === "active"
      && String(definition?.metadata?.catalog_only ?? "false").toLowerCase() !== "true",
    );
    const hasSelection = definition
      && Object.prototype.hasOwnProperty.call(builtinSkillSelections.value, definition.id);

    return [{
      key: `${identity}-${entry?.slot ?? index + 1}`,
      name: definition?.name || name || "Skill kartu",
      icon: definition?.icon || entry?.icon || '✦',
      description: definition?.description ?? entry?.description ?? entry?.effect ?? "",
      slot: Number(entry?.slot ?? index + 1),
      definition,
      relation,
      battleReady,
      enabled: battleReady && (hasSelection
        ? Boolean(builtinSkillSelections.value[definition.id])
        : Boolean(relation?.enabled)),
    }];
  }).sort((a, b) => a.slot - b.slot);
});

const setBuiltinSkillEnabled = (item, event) => {
  if (!item?.definition || !item.battleReady) return;
  const enabled = Boolean(event?.target?.checked);
  if (cardMetadata.value?.studio_card) {
    const update = skills => (skills ?? []).map((skill,index) => Number(skill.slot ?? index+1) === item.slot ? {...skill,battle:{...(skill.battle ?? {}),enabled,selection_enabled:enabled}} : skill);
    cardMetadata.value = {...cardMetadata.value,skills:update(cardMetadata.value.skills),studio_card:{...cardMetadata.value.studio_card,skills:update(cardMetadata.value.studio_card.skills)}};
  }
  builtinSkillSelections.value = {
    ...builtinSkillSelections.value,
    [item.definition.id]: enabled,
  };

  if (enabled) {
    specialSkillMode.value = "existing";
    selectedSpecialSkillId.value = item.definition.id;
  }
};

const handleSpecialSkillModeChange = (mode) => {
  if (mode !== "none") return;
  selectedSpecialSkillId.value = "";
  builtinSkillSelections.value = Object.fromEntries(
    builtinCardSkills.value
      .filter((item) => item.definition)
      .map((item) => [item.definition.id, false]),
  );
};

const soulRebirthSkill = computed(() =>
  specialSkills.value.find(
    (skill) => String(skill?.code ?? "").toLowerCase() === "soul_rebirth",
  ) ?? null,
);


const STATUS_SKILL_PRESETS = [
  { code: "scorch_mark", icon: "🔥", label: "BURN", hint: "10 damage • 2 turn • max 3 stack" },
  { code: "frost_lock", icon: "🧊", label: "FREEZE", hint: "Block Attack + Ultimate • 1 turn" },
  { code: "toxic_spore", icon: "☠", label: "POISON", hint: "8 damage • 3 turn • max 3 stack" },
  { code: "thunder_stun", icon: "💫", label: "STUN", hint: "Block card actions • 1 turn" },
];

const statusSkillPresetCards = computed(() =>
  STATUS_SKILL_PRESETS.map((preset) => ({
    ...preset,
    skill:
      specialSkills.value.find(
        (skill) => String(skill?.code ?? "").toLowerCase() === preset.code,
      ) ?? null,
  })),
);

const assignStatusSkillPreset = (preset) => {
  const skill = preset?.skill;

  if (!skill) {
    errorMessage.value =
      `Master skill "${preset?.code ?? "status"}" belum ada. Jalankan SQL Phase 3D.19 terlebih dahulu.`;
    successMessage.value = "";
    return;
  }

  specialSkillMode.value = "existing";
  selectedSpecialSkillId.value = skill.id;
  existingRelationId.value = null;
  errorMessage.value = "";
  successMessage.value =
    `${preset.icon} ${skill.name} dipilih. Simpan Card untuk memasang preset status ini.`;
};

const assignSoulRebirthPreset = () => {
  const skill = soulRebirthSkill.value;

  if (!skill) {
    errorMessage.value =
      'Master skill "soul_rebirth" belum ada. Jalankan SQL Phase 3C.1 Necro Resurrection terlebih dahulu.';
    successMessage.value = "";
    return;
  }

  const currentTags = parseTags(tagsInput.value);
  if (!currentTags.some((tag) => String(tag).toLowerCase() === "necro")) {
    tagsInput.value = [...currentTags, "necro"].join(", ");
  }

  specialSkillMode.value = "existing";
  selectedSpecialSkillId.value = skill.id;
  existingRelationId.value = null;
  errorMessage.value = "";
  successMessage.value =
    "☠ Soul Rebirth dipilih. Simpan Card untuk memasang skill Necro Resurrection ini.";
};


const humanTargetLabel = (value) => {
  const labels = {
    enemy_active: "Enemy Active Card",
    ally_active: "Ally Active Card",
    ally_field: "Kartu milikmu di Active atau Bench",
    self_card: "Kartu ini sendiri",
    self_player: "Player sendiri",
    enemy_player: "Player lawan",
    ally_graveyard: "Card sendiri di Graveyard",
    enemy_graveyard: "Card lawan di Graveyard",
  };

  return labels[value] ?? value ?? "-";
};


const humanEffectLabel = (value) => {
  const labels = {
    damage_card: "Damage ke Card",
    heal_card: "Heal Card",
    damage_player: "Damage langsung ke Player",
    heal_player: "Heal Player",
    add_skill_gauge: "Tambah Skill Gauge",
  };

  return labels[value] ?? value ?? "-";
};


const resolveTargetTypeFromSkill = (skill) => {
  return (
    skill?.target_spec?.type ??
    skill?.target_spec?.target ??
    skill?.target_spec?.mode ??
    "enemy_active"
  );
};


const populateSkillForm = (skill) => {
  if (!skill) {
    return;
  }

  skillName.value = skill.name ?? "";
  skillCode.value = skill.code ?? "";
  skillCodeAuto.value = false;
  skillDescription.value = skill.description ?? "";
  const media = splitSkillIcon(skill.icon);
  skillIcon.value = media.symbol;
  skillImageUrl.value = media.imageUrl;
  skillActionPoints.value = Number(skill.limits?.action_points ?? 1);
  skillType.value = skill.skill_type ?? "active";
  activationTiming.value = skill.activation_timing ?? "main_phase";
  skillTargetType.value = resolveTargetTypeFromSkill(skill);
  skillCostType.value = skill.cost_spec?.type ?? "none";
  skillCostValue.value = Number(
    skill.cost_spec?.value ?? skill.cost_spec?.amount ?? 0,
  );
  skillCooldownUnit.value = Object.hasOwn(skill.limits ?? {}, "cooldown_turns") ? "owner" : "round";
  skillCooldownRounds.value = Number(
    skill.limits?.cooldown_turns ?? skill.limits?.cooldown_rounds ?? skill.limits?.cooldown ?? 0,
  );
  skillMaxUses.value = Number(skill.limits?.max_uses ?? 0);
  skillOncePerBattle.value = Boolean(skill.limits?.once_per_battle);
  skillConsumesTurn.value = Boolean(skill.consumes_turn ?? true);

  const effects = Array.isArray(skill.effects) ? skill.effects : [];
  skillEffectsJson.value = JSON.stringify(effects, null, 2);

  if (effects.length === 0) {
    const description = String(skill.description ?? "");
    const healAmount = description.match(/\bheal\s*(\d+)\b/i);
    const describesAllyCard = /\b(rekan|teman|sekutu|ally)\b/i.test(description);
    const isWorldtreePulse = String(skill.name ?? "").trim().toLowerCase() === "worldtree pulse";

    // Draft skill katalog dapat belum memiliki effects. Biarkan admin memilih
    // efek sederhana; untuk Worldtree Pulse isi konfigurasi Heal ke kartu ally
    // dari deskripsi master plan agar dropdown tidak terkunci pada Advanced.
    skillAdvancedMode.value = false;
    skillEffectType.value = healAmount && describesAllyCard ? "heal_card" : "";
    skillEffectAmount.value = healAmount && describesAllyCard
      ? Number(healAmount[1])
      : 0;

    if (healAmount && describesAllyCard) {
      skillTargetType.value = "ally_active";
    }

    if (/sekali\s*\/\s*battle|once per battle/i.test(description)) {
      skillOncePerBattle.value = true;
      skillMaxUses.value = 1;
    }

    const cooldown = description.match(/\bcd\.?\s*(\d+)\b/i);
    if (cooldown) {
      skillCooldownRounds.value = Number(cooldown[1]);
    }

    if (isWorldtreePulse && healAmount && describesAllyCard) {
      skillDescription.value =
        `Sekali per battle, pulihkan ${healAmount[1]} HP pada satu kartu Active milikmu; cooldown ${cooldown?.[1] ?? 3} ronde.`;
    }

    if (skillEffectType.value) {
      skillEffectsJson.value = JSON.stringify(buildSimpleEffects(), null, 2);
    }

    return;
  }

  const firstEffect = effects[0];
  const simpleTypes = [
    "damage_card",
    "heal_card",
    "damage_player",
    "heal_player",
    "add_skill_gauge",
  ];

  if (
    effects.length === 1 &&
    firstEffect &&
    simpleTypes.includes(firstEffect.type) &&
    (firstEffect.amount?.mode ?? "fixed") === "fixed"
  ) {
    skillEffectType.value = firstEffect.type;
    skillEffectAmount.value = Number(firstEffect.amount?.value ?? 0);
    skillAdvancedMode.value = false;
  } else {
    skillAdvancedMode.value = true;
  }
};


const startEditSelectedSkill = () => {
  if (!selectedSpecialSkill.value) {
    errorMessage.value = "Pilih Special Skill yang ingin diedit.";
    return;
  }

  populateSkillForm(selectedSpecialSkill.value);
  specialSkillMode.value = "edit";
  errorMessage.value = "";
};


const cancelSkillEdit = () => {
  specialSkillMode.value = selectedSpecialSkillId.value
    ? "existing"
    : "none";
  resetNewSkillForm();
};


const loadSpecialSkills = async () => {
  const { data, error } = await supabase
    .from("special_skills")
    .select(`
      id,
      code,
      name,
      description,
      icon,
      skill_type,
      activation_timing,
      source_zones,
      target_spec,
      cost_spec,
      limits,
      effects,
      consumes_turn,
      priority,
      is_active,
      catalog_status,
      metadata
    `)
    .order("name");

  if (error) {
    console.error("Load Special Skills:", error);
    return;
  }

  allSkillDefinitions.value = data ?? [];
  specialSkills.value = allSkillDefinitions.value.filter((skill) => skill.is_active && !skill.metadata?.catalog_only);
  catalogSkills.value = allSkillDefinitions.value.filter((skill) => skill.metadata?.catalog_only);
};


const loadCardSpecialSkill = async (gameCardId) => {
  resetSpecialSkillState();

  if (!gameCardId) {
    return;
  }

  const { data, error } = await supabase
    .from("game_card_special_skills")
    .select(`
      id,
      game_card_id,
      special_skill_id,
      sort_order,
      enabled,
      overrides
    `)
    .eq("game_card_id", gameCardId)
    .order("sort_order", { ascending: true });

  if (error) {
    console.error("Load Card Special Skill:", error);
    throw error;
  }

  existingCardSkillRelations.value = data ?? [];
  const activeRelation = existingCardSkillRelations.value.find((relation) => {
    const skill = allSkillDefinitions.value.find(
      (item) => String(item.id) === String(relation.special_skill_id),
    );
    return relation.enabled && skill?.is_active && !skill?.metadata?.catalog_only;
  });

  if (activeRelation) {
    existingRelationId.value = activeRelation.id;
    selectedSpecialSkillId.value = activeRelation.special_skill_id;
    specialSkillMode.value = "existing";
  }
};


const buildTargetSpec = () => {
  const cardTargetTypes = new Set([
    "enemy_active",
    "ally_active",
    "any_active",
    "enemy_graveyard",
    "ally_graveyard",
    "any_card",
  ]);

  return {
    ...(specialSkillMode.value === 'edit' && resolveTargetTypeFromSkill(selectedSpecialSkill.value) === skillTargetType.value ? selectedSpecialSkill.value?.target_spec ?? {} : {}),
    type: skillTargetType.value,
    required: cardTargetTypes.has(skillTargetType.value) || skillTargetType.value === 'ally_field',
  };
};


const buildCostSpec = () => ({
  type: skillCostType.value,
  value:
    skillCostType.value === "none"
      ? 0
      : Math.max(0, Number(skillCostValue.value) || 0),
});


const buildLimits = () => {
  const limits = {
    ...(specialSkillMode.value === 'edit' ? selectedSpecialSkill.value?.limits ?? {} : {}),
    action_points: Number(skillActionPoints.value),
    once_per_battle: Boolean(skillOncePerBattle.value),
    [skillCooldownUnit.value === "owner" ? "cooldown_turns" : "cooldown_rounds"]: Math.max(
      0,
      Number(skillCooldownRounds.value) || 0,
    ),
  };

  if (Number(skillMaxUses.value) > 0) {
    limits.max_uses = Number(skillMaxUses.value);
  } else {
    delete limits.max_uses;
  }

  if (skillOncePerBattle.value) {
    limits.max_uses = 1;
  }

  delete limits[skillCooldownUnit.value === 'owner' ? 'cooldown_rounds' : 'cooldown_turns'];
  delete limits.cooldown;
  return limits;
};


const buildSimpleEffects = () => {
  if (!skillEffectType.value) {
    throw new Error("Pilih Jenis Efek sebelum menyimpan Special Skill.");
  }

  const amount = {
    mode: "fixed",
    value: Math.max(0, Number(skillEffectAmount.value) || 0),
  };

  if (skillEffectType.value === "damage_card") {
    return [
      {
        type: "damage_card",
        target: "target_card",
        owner: skillTargetType.value.startsWith("enemy") ? "enemy" : "self",
        allowed_zones: skillTargetType.value.includes("graveyard")
          ? ["graveyard"]
          : ["active"],
        amount,
      },
    ];
  }

  if (skillEffectType.value === "heal_card") {
    return [
      {
        type: "heal_card",
        target:
          skillTargetType.value === "self_card"
            ? "source_card"
            : "target_card",
        owner: skillTargetType.value.startsWith("enemy") ? "enemy" : "self",
        allowed_zones: ["active"],
        amount,
      },
    ];
  }

  if (skillEffectType.value === "damage_player") {
    return [
      {
        type: "damage_player",
        target:
          skillTargetType.value === "self_player"
            ? "self_player"
            : "enemy_player",
        amount,
      },
    ];
  }

  if (skillEffectType.value === "heal_player") {
    return [
      {
        type: "heal_player",
        target:
          skillTargetType.value === "enemy_player"
            ? "enemy_player"
            : "self_player",
        amount,
      },
    ];
  }

  if (skillEffectType.value === "add_skill_gauge") {
    return [
      {
        type: "add_skill_gauge",
        target:
          skillTargetType.value === "enemy_player"
            ? "enemy_player"
            : "self_player",
        amount,
      },
    ];
  }

  throw new Error("Jenis effect sederhana belum didukung.");
};


const getEffectsForSave = () => {
  if (!skillAdvancedMode.value) {
    return buildSimpleEffects();
  }

  let parsedEffects;

  try {
    parsedEffects = JSON.parse(skillEffectsJson.value);
  } catch {
    throw new Error("Advanced Effects JSON tidak valid.");
  }

  if (!Array.isArray(parsedEffects) || parsedEffects.length === 0) {
    throw new Error("Effects harus berupa JSON array dan minimal satu effect.");
  }

  return parsedEffects;
};


const buildSkillPayload = () => {
  if (!skillName.value.trim()) {
    throw new Error("Nama Special Skill wajib diisi.");
  }
  if (/^(?:https?:\/\/|data:|\/)/i.test(skillName.value.trim())) throw new Error('Nama skill harus berupa nama kemampuan. Masukkan URL di bagian Gambar skill.');
  if (!skillDescription.value.trim()) throw new Error('Penjelasan skill wajib diisi sesuai aturan efeknya.');
  if (skillType.value !== 'active' || activationTiming.value !== 'main_phase') throw new Error('Registrasi kartu memakai skill aktif manual pada Main phase. Simpan rancangan pasif atau terpicu di Skill & Catalog.');
  if (!Number.isInteger(Number(skillActionPoints.value)) || Number(skillActionPoints.value)<1 || Number(skillActionPoints.value)>2) throw new Error('Biaya skill harus 1 atau 2 AP.');

  const finalCode =
    skillCode.value.trim() || slugifySkillCode(skillName.value);

  if (!finalCode) {
    throw new Error("Skill Code tidak valid.");
  }

  return {
    code: finalCode,
    name: skillName.value.trim(),
    description: skillDescription.value.trim() || null,
    icon: skillMediaValue(skillImageUrl.value, skillIcon.value),
    category: "special",
    skill_type: skillType.value,
    activation_timing: activationTiming.value,
    trigger_spec: {
      type: activationTiming.value,
      label: activationTiming.value === "main_phase" ? "Aktif manual pada main phase" : "Pemicu event katalog",
    },
    source_zones: ["active"],
    target_spec: buildTargetSpec(),
    cost_spec: buildCostSpec(),
    limits: buildLimits(),
    effects: getEffectsForSave(),
    consumes_turn: Boolean(skillConsumesTurn.value),
    priority: 100,
    catalog_status: "active",
    is_active: true,
    change_note: "Disimpan dari Register Card",
    metadata: specialSkillMode.value === 'edit' ? {...(selectedSpecialSkill.value?.metadata ?? {}),catalog_only:false} : {},
  };
};

const suggestSkillCopy = () => {
  if (skillAdvancedMode.value) return;
  const copy = describeBasicSkill({type:skillEffectType.value,amount:skillEffectAmount.value,target:skillTargetType.value,actionPoints:skillActionPoints.value,cooldown:skillCooldownRounds.value,cooldownUnit:skillCooldownUnit.value,once:skillOncePerBattle.value,endsTurn:skillConsumesTurn.value});
  if (!copy) return;
  if (!skillName.value.trim()) skillName.value = copy.name;
  skillDescription.value = copy.description;
};


const syncCardSpecialSkill = async (gameCardId) => {
  if (!gameCardId) {
    throw new Error("Game Card ID tidak tersedia.");
  }

  // =====================================================
  // MODE: NONE
  // Hapus relasi Card -> Skill, master skill tetap aman.
  // =====================================================
  if (specialSkillMode.value === "none") {
    const { error } = await supabase
      .from("game_card_special_skills")
      .delete()
      .eq("game_card_id", gameCardId);

    if (error) {
      throw error;
    }

    existingRelationId.value = null;
    selectedSpecialSkillId.value = "";
    return;
  }

  // =====================================================
  // MODE: EXISTING
  // =====================================================
  if (specialSkillMode.value === "existing") {
    if (!selectedSpecialSkillId.value) {
      throw new Error("Pilih Special Skill terlebih dahulu.");
    }

    const preserveCardSkills = Boolean(
      existingCardSkillRelations.value.length > 1 &&
      existingCardSkillRelations.value.some(
        (relation) => String(relation.special_skill_id) === String(selectedSpecialSkillId.value),
      ),
    );
    const relationsToSave = preserveCardSkills
      ? existingCardSkillRelations.value.map((relation) => ({
          game_card_id: gameCardId,
          special_skill_id: relation.special_skill_id,
          sort_order: relation.sort_order,
          enabled: relation.enabled,
          overrides: relation.overrides ?? {},
        }))
      : [{
          game_card_id: gameCardId,
          special_skill_id: selectedSpecialSkillId.value,
          sort_order: 0,
          enabled: true,
          overrides: {},
        }];

    // A seeded template can carry two catalog abilities. Preserve both when
    // its skill is copied to a freshly scanned physical card.
    const { error: deleteError } = await supabase
      .from("game_card_special_skills")
      .delete()
      .eq("game_card_id", gameCardId);

    if (deleteError) {
      throw deleteError;
    }

    const { data: relations, error: insertError } = await supabase
      .from("game_card_special_skills")
      .insert(relationsToSave)
      .select("id");

    if (insertError) {
      throw insertError;
    }

    existingRelationId.value = relations?.[0]?.id ?? null;
    return;
  }

  // =====================================================
  // MODE: NEW
  // =====================================================
  if (specialSkillMode.value === "new") {
    const payload = buildSkillPayload();

    const { data: createdSkill, error: skillError } = await supabase
      .from("special_skills")
      .insert(payload)
      .select("id, code, name")
      .single();

    if (skillError) {
      if (skillError.code === "23505") {
        throw new Error(
          `Skill Code "${payload.code}" sudah digunakan. Gunakan code lain atau pilih Existing Skill.`,
        );
      }

      throw skillError;
    }

    const { error: deleteError } = await supabase
      .from("game_card_special_skills")
      .delete()
      .eq("game_card_id", gameCardId);

    if (deleteError) {
      throw deleteError;
    }

    const { data: relation, error: relationError } = await supabase
      .from("game_card_special_skills")
      .insert({
        game_card_id: gameCardId,
        special_skill_id: createdSkill.id,
        sort_order: 0,
        enabled: true,
        overrides: {},
      })
      .select("id")
      .single();

    if (relationError) {
      throw relationError;
    }

    existingRelationId.value = relation.id;
    selectedSpecialSkillId.value = createdSkill.id;
    specialSkillMode.value = "existing";

    await loadSpecialSkills();
    return;
  }

  // =====================================================
  // MODE: EDIT EXISTING MASTER SKILL
  // Perubahan berlaku ke semua Card yang memakai master
  // Special Skill yang sama.
  // =====================================================
  if (specialSkillMode.value === "edit") {
    if (!selectedSpecialSkillId.value) {
      throw new Error("Special Skill yang akan diedit tidak ditemukan.");
    }

    const payload = buildSkillPayload();

    const { error: updateError } = await supabase
      .from("special_skills")
      .update({
        ...payload,
        updated_at: new Date().toISOString(),
      })
      .eq("id", selectedSpecialSkillId.value);

    if (updateError) {
      if (updateError.code === "23505") {
        throw new Error(
          `Skill Code "${payload.code}" sudah digunakan Special Skill lain.`,
        );
      }

      throw updateError;
    }

    // Pastikan Card tetap terhubung ke skill yang diedit.
    const { error: deleteError } = await supabase
      .from("game_card_special_skills")
      .delete()
      .eq("game_card_id", gameCardId);

    if (deleteError) {
      throw deleteError;
    }

    const { data: relation, error: relationError } = await supabase
      .from("game_card_special_skills")
      .insert({
        game_card_id: gameCardId,
        special_skill_id: selectedSpecialSkillId.value,
        sort_order: 0,
        enabled: true,
        overrides: {},
      })
      .select("id")
      .single();

    if (relationError) {
      throw relationError;
    }

    existingRelationId.value = relation.id;
    await loadSpecialSkills();
    specialSkillMode.value = "existing";
    return;
  }

  throw new Error("Mode Special Skill tidak dikenali.");
};

const syncBuiltinCardSkillToggles = async (gameCardId) => {
  const toggleableSkills = builtinCardSkills.value.filter((item) => item.definition);
  if (!gameCardId || !toggleableSkills.length) return;

  const { data: relations, error: loadError } = await supabase
    .from("game_card_special_skills")
    .select("id, special_skill_id, enabled")
    .eq("game_card_id", gameCardId);

  if (loadError) throw loadError;

  for (const item of toggleableSkills) {
    const relation = (relations ?? []).find(
      (row) => String(row.special_skill_id) === String(item.definition.id),
    );
    const shouldEnable = Boolean(item.battleReady && item.enabled);

    if (relation) {
      if (Boolean(relation.enabled) !== shouldEnable) {
        const { error } = await supabase
          .from("game_card_special_skills")
          .update({ enabled: shouldEnable })
          .eq("id", relation.id);
        if (error) throw error;
      }
    } else if (shouldEnable) {
      const { error } = await supabase
        .from("game_card_special_skills")
        .insert({
          game_card_id: gameCardId,
          special_skill_id: item.definition.id,
          sort_order: item.slot,
          enabled: true,
          overrides: {},
        });
      if (error) throw error;
    }
  }
};



// ==========================================

// CEK APAKAH UID SUDAH TERDAFTAR DI DATABASE

// ==========================================

const checkExistingCard = async (scannedUid) => {
  try {
    const normalizedUid = String(scannedUid ?? "").trim();

    if (!normalizedUid) {
      return;
    }

    // Fusion Card bersifat virtual dan tidak menerima UID RFID.
    if (cardMode.value === "fusion") {
      return;
    }

    const { data, error } = await supabase
      .from("game_cards")
      .select("*")
      .eq("uid", normalizedUid)
      .maybeSingle();

    if (error) throw error;

    uid.value = normalizedUid;

    if (data) {
      // UID yang sudah terdaftar selalu dibuka sebagai edit Physical Card.
      cardMode.value = "new";
      copySourceCardId.value = "";
      selectedFusionCardId.value = "";

      isExistingCard.value = true;
      recordId.value = data.id;

      await applyCardDataToForm(data);
      uid.value = normalizedUid;

      successMessage.value =
        `Kartu terdeteksi! Memuat data "${data.name}" (Mode Edit Physical Card).`;
    } else {
      isExistingCard.value = false;
      recordId.value = null;

      if (cardMode.value === "copy") {
        const currentSource = copySourceCardId.value;
        clearCardFields({ keepUid: true });
        uid.value = normalizedUid;
        copySourceCardId.value = currentSource;

        if (currentSource) {
          await loadCopySourceCard();
        }

        successMessage.value = currentSource
          ? "UID baru terdeteksi dan data Card Type sudah dicopy."
          : "UID baru terdeteksi! Pilih Existing Card Type yang ingin dicopy.";
      } else {
        clearCardFields({ keepUid: true });
        uid.value = normalizedUid;
        successMessage.value =
          "Physical Card baru terdeteksi! Silakan lengkapi data.";
      }
    }

    errorMessage.value = "";
  } catch (err) {
    console.error(err);
    errorMessage.value = "Gagal memeriksa status kartu di database.";
  }
};


// ==========================================

// SUPABASE REALTIME LISTENER (AUTO-FILL & CHECK)

// ==========================================

const setupRealtimeListener = () => {
  if (!registrationActive || realtimeChannel) return;

  realtimeChannel = supabase

    .channel("game_card_register_listener")

    .on(

      "postgres_changes",

      {

        event: "INSERT",

        schema: "public",

        table: "scan_events",

      },

      async (payload) => {

        const scannedUid = payload.new.uid;

        // Fusion Card tidak memakai RFID. Scan yang masuk saat mode Fusion
        // sengaja diabaikan supaya form virtual card tidak tertimpa.
        if (!registrationActive || cardMode.value === "fusion") {
          return;
        }

        await checkExistingCard(scannedUid);

      },

    )

    .subscribe();

};



// ==========================================

// SIMPAN ATAU PERBARUI DATA (UPSERT / EDIT)

// ==========================================

const handleSubmit = async () => {
  errorMessage.value = "";
  successMessage.value = "";

  if (compressingImage.value) {
    errorMessage.value = "Tunggu sampai semua gambar selesai dikompres.";
    return;
  }

  const isFusionCard = cardMode.value === "fusion";

  if (!isFusionCard && !uid.value.trim()) {
    errorMessage.value =
      "UID RFID wajib diisi untuk Physical Card. Tap kartu pada hardware RC522.";
    return;
  }

  if (cardMode.value === "copy" && !copySourceCardId.value) {
    errorMessage.value = "Pilih Existing Card Type yang ingin dicopy.";
    return;
  }

  if (!cardName.value.trim()) {
    errorMessage.value = "Nama karakter/kartu wajib diisi.";
    return;
  }

    const finalCardCode = slugifyCardCode(
      cardCode.value.trim() || cardName.value,
    );

  if (!finalCardCode) {
    errorMessage.value = "Card Code tidak valid.";
    return;
  }

  if (
    specialSkillMode.value === "existing" &&
    !selectedSpecialSkillId.value
  ) {
    errorMessage.value = "Pilih Existing Special Skill terlebih dahulu.";
    return;
  }

  loading.value = true;

  try {
    let savedImageUrl = imageUrl.value.trim();
    if (compressedCardImage.value) {
      savedImageUrl = await uploadCompressedCardImage(compressedCardImage.value, "cover");
    }
    let savedPhysicalCardImageUrl = physicalCardImageUrl.value.trim();
    if (compressedPhysicalCardImage.value) {
      savedPhysicalCardImageUrl = await uploadCompressedCardImage(compressedPhysicalCardImage.value, "physical");
    }
    let savedAvatarUrl = avatarUrl.value.trim();
    if (avatarImageFile.value) {
      savedAvatarUrl = await uploadCompressedCardImage(avatarImageFile.value, "avatar");
    }

    let savedCardId = null;
    const wasExisting = Boolean(isExistingCard.value && recordId.value);
    const metadataForSave = {
      ...(cardMetadata.value && typeof cardMetadata.value === "object" && !Array.isArray(cardMetadata.value)
        ? cardMetadata.value
        : {}),
    };

    // timedoor_seed_key hanya milik satu baris master katalog. Kartu fisik
    // dengan UID adalah instance terpisah, sehingga key master tidak boleh ikut
    // terkirim saat insert maupun update. Simpan asalnya sebagai metadata biasa.
    if (!isFusionCard && metadataForSave.timedoor_seed_key) {
      metadataForSave.catalog_source_seed_key ??= metadataForSave.timedoor_seed_key;
      delete metadataForSave.timedoor_seed_key;
    }

    const payload = {
      uid: isFusionCard ? null : uid.value.trim(),
      card_code: finalCardCode,
      tags: parseTags(tagsInput.value),
      level: Number(cardLevel.value ?? 1),
      rarity: cardRarity.value || "common",
      lore: cardLore.value || null,
      metadata: metadataForSave,
      physical_scan_enabled: !isFusionCard,
      fusion_only: isFusionCard,
      name: cardName.value.trim(),
      element: element.value,
      hp: parseInt(hp.value),
      attack: parseInt(attack.value),
      defense: parseInt(defense.value),
      image_url: savedImageUrl,
      physical_card_image_url: savedPhysicalCardImageUrl || null,
      avatar_url: savedAvatarUrl || null,
    };

    if (wasExisting) {
      const { data, error } = await supabase
        .from("game_cards")
        .update(payload)
        .eq("id", recordId.value)
        .select("id")
        .single();

      if (error) throw error;
      savedCardId = data.id;
    } else {
      const { data, error } = await supabase
        .from("game_cards")
        .insert(payload)
        .select("id")
        .single();

      if (error) throw error;

      savedCardId = data.id;
      recordId.value = data.id;
      isExistingCard.value = true;
    }

    // Special Skill tetap memakai sistem Phase 3C yang sudah works.
    if (!metadataForSave.studio_card) {
      await syncCardSpecialSkill(savedCardId);
      await syncBuiltinCardSkillToggles(savedCardId);
    }

    cardCode.value = finalCardCode;

    // Fusion Recipe hanya disimpan untuk Virtual Fusion Card.
    // Physical / Copy Card tidak disentuh.
    if (isFusionCard && fusionRecipeEnabled.value) {
      await syncFusionRecipe(savedCardId);
    }

    await loadGameCardCatalog();

    successMessage.value = wasExisting
      ? `${isFusionCard ? "Fusion Card, Fusion Recipe" : "Physical Card"} dan Special Skill berhasil diperbarui!`
      : cardMode.value === "copy"
        ? "Copy Physical Card baru berhasil dibuat dengan RFID berbeda dan Card Code yang sama!"
        : `${isFusionCard ? "Fusion Card virtual + Fusion Recipe" : "Physical Card"} dan Special Skill berhasil didaftarkan!`;

    setTimeout(() => {
      router.push({ name: "album-card" });
    }, 1500);
  } catch (error) {
    console.error("Save Card:", error);

    if (error?.code === "23505") {
      const conflict = [error?.message, error?.details, error?.hint]
        .filter(Boolean)
        .join(" ")
        .toLowerCase();

      if (conflict.includes("timedoor_seed_key")) {
        errorMessage.value =
          "Identitas kartu katalog tidak boleh dipakai ulang. Coba simpan ulang kartu salinan.";
      } else if (conflict.includes("game_cards_uid_key") || conflict.includes("(uid)")) {
        errorMessage.value =
          "UID RFID ini sudah terdaftar. Scan UID lain atau buka kartu yang sudah ada untuk mengeditnya.";
      } else if (conflict.includes("game_cards_unique_fusion_template_code_idx")) {
        errorMessage.value =
          "Card Code Fusion tersebut sudah digunakan. Pilih Card Code lain atau edit kartu Fusion yang ada.";
      } else {
        errorMessage.value =
          "Data kartu bentrok dengan data unik lain. Periksa UID RFID dan Card Code, lalu coba lagi.";
      }
    } else {
      errorMessage.value =
        error?.message || "Gagal menyimpan data kartu.";
    }
  } finally {
    loading.value = false;
  }
};

const handleCardImage = async (event) => {
  const file = event.target.files?.[0];
  if (!file) return;
  compressingImage.value = true;
  errorMessage.value = "";
  successMessage.value = "";
  try {
    const compressed = await compressImageFile(file, {
      maxSourceBytes: IMAGE_UPLOAD_LIMITS.sourceBytes,
      maxOutputBytes: IMAGE_UPLOAD_LIMITS.outputBytes,
      maxDimension: IMAGE_UPLOAD_LIMITS.maxDimension,
    });
    if (compressedImagePreview.value.startsWith("blob:")) URL.revokeObjectURL(compressedImagePreview.value);
    compressedCardImage.value = compressed;
    compressedImagePreview.value = URL.createObjectURL(compressed);
    successMessage.value = `Gambar otomatis dikompres menjadi ${Math.ceil(compressed.size / 1024)} KB.`;
  } catch (error) {
    errorMessage.value = error?.message ?? "Gagal mengompres gambar.";
    event.target.value = "";
  } finally {
    compressingImage.value = false;
  }
};

const clearCardImage = () => {
  if (compressedImagePreview.value.startsWith("blob:")) URL.revokeObjectURL(compressedImagePreview.value);
  compressedCardImage.value = null;
  compressedImagePreview.value = "";
  if (cardImageInput.value) cardImageInput.value.value = "";
};

const handleAuxiliaryCardImage = async (event, fileState, previewState, label) => {
  const file = event.target.files?.[0];
  if (!file) return;
  compressingImage.value = true;
  errorMessage.value = "";
  successMessage.value = "";
  if (previewState.value.startsWith("blob:")) URL.revokeObjectURL(previewState.value);
  fileState.value = null;
  previewState.value = "";
  try {
    const compressed = await compressImageFile(file, {
      maxSourceBytes: IMAGE_UPLOAD_LIMITS.sourceBytes,
      maxOutputBytes: IMAGE_UPLOAD_LIMITS.outputBytes,
      maxDimension: IMAGE_UPLOAD_LIMITS.maxDimension,
    });
    fileState.value = compressed;
    previewState.value = URL.createObjectURL(compressed);
    successMessage.value = `${label} dikompres menjadi ${Math.ceil(compressed.size / 1024)} KB WebP.`;
  } catch (error) {
    errorMessage.value = error?.message ?? `Gagal mengompres ${label.toLowerCase()}.`;
    event.target.value = "";
  } finally {
    compressingImage.value = false;
  }
};

const handlePhysicalCardImage = (event) => handleAuxiliaryCardImage(
  event,
  compressedPhysicalCardImage,
  physicalCardImagePreview,
  "Gambar kartu fisik",
);

const handleAvatarImage = (event) => handleAuxiliaryCardImage(
  event,
  avatarImageFile,
  avatarImagePreview,
  "Avatar",
);

const clearAuxiliaryCardImage = (fileState, previewState, inputState) => {
  if (previewState.value.startsWith("blob:")) URL.revokeObjectURL(previewState.value);
  fileState.value = null;
  previewState.value = "";
  if (inputState.value) inputState.value.value = "";
};

const clearAdditionalCardImages = () => {
  clearAuxiliaryCardImage(compressedPhysicalCardImage, physicalCardImagePreview, physicalCardImageInput);
  clearAuxiliaryCardImage(avatarImageFile, avatarImagePreview, avatarImageInput);
};

const clearPhysicalCardImage = () => clearAuxiliaryCardImage(
  compressedPhysicalCardImage,
  physicalCardImagePreview,
  physicalCardImageInput,
);

const clearAvatarImage = () => clearAuxiliaryCardImage(
  avatarImageFile,
  avatarImagePreview,
  avatarImageInput,
);

const uploadCompressedCardImage = async (file, folder) => {
  const path = `${folder}/${crypto.randomUUID()}.webp`;
  const { error: uploadError } = await supabase.storage
    .from("card-images")
    .upload(path, file, {
      cacheControl: "31536000",
      upsert: false,
      contentType: "image/webp",
    });
  if (uploadError) throw uploadError;
  return supabase.storage.from("card-images").getPublicUrl(path).data.publicUrl;
};



const resetForm = () => {
  clearCardImage();
  clearAdditionalCardImages();
  cardMode.value = "new";
  copySourceCardId.value = "";
  selectedFusionCardId.value = "";
  uid.value = "";
  cardName.value = "";
  cardCodeAuto.value = true;
  cardCode.value = "";
  tagsInput.value = "";
  element.value = "Fire";
  hp.value = 120;
  attack.value = 45;
  defense.value = 30;
  imageUrl.value = "🔥";
  avatarUrl.value = "";
  physicalCardImageUrl.value = "";

  isExistingCard.value = false;
  recordId.value = null;

  resetFusionRecipeState();
  resetSpecialSkillState();

  errorMessage.value = "";
  successMessage.value = "";
};


let appliedStudioSource='';
const useStudioSource=async()=>{
  const source=String(route.query.source??'');
  if(!source||route.name!=='register-card')return;
  const card=gameCardCatalog.value.find(item=>item.id===source);
  if(!card){errorMessage.value='Kartu sumber belum ditemukan. Buka kembali dari Studio atau Album.';return;}
  const signature=JSON.stringify(card);
  if(appliedStudioSource===signature)return;
  appliedStudioSource=signature;
  try{
    if(card.fusion_only){cardMode.value='fusion';selectedFusionCardId.value=source;await loadFusionCardForEdit();}
    else{cardMode.value='copy';copySourceCardId.value=source;await loadCopySourceCard();}
  }catch(error){appliedStudioSource='';errorMessage.value=error?.message||'Data kartu belum dapat dimuat.';}
};
watch(()=>route.query.source,()=>{if(registrationLoaded)loadGameCardCatalog().then(useStudioSource);});

onMounted(async () => {
  loadStoredElements();

  await Promise.all([
    loadSpecialSkills(),
    loadGameCardCatalog(),
  ]);

  registrationLoaded = true;
  await useStudioSource();
  if (registrationActive) setupRealtimeListener();
});

onActivated(() => {
  registrationActive = true;
  if (registrationLoaded) { setupRealtimeListener(); loadGameCardCatalog().then(useStudioSource); }
});

onDeactivated(() => {
  registrationActive = false;
  stopRegistrationListener();
});


onUnmounted(() => {

  if (compressedImagePreview.value.startsWith("blob:")) URL.revokeObjectURL(compressedImagePreview.value);
  if (physicalCardImagePreview.value.startsWith("blob:")) URL.revokeObjectURL(physicalCardImagePreview.value);
  if (avatarImagePreview.value.startsWith("blob:")) URL.revokeObjectURL(avatarImagePreview.value);

  registrationActive = false;
  stopRegistrationListener();

});

const adminToast=useAdminFeedback({error:errorMessage,message:successMessage,scope:'RegisterGameCard'});
</script>



<template>

  <div class="register-container ide-builder-page">

    <header class="ide-toolbar">
      <div class="toolbar-left">
        <span class="brand-mark toolbar-logo" aria-hidden="true">t</span>
        <div class="toolbar-heading">
          <span class="toolbar-kicker">TIMEDOOR · CARD STUDIO</span>
          <h1 class="toolbar-title">
            {{ isExistingCard ? "Edit kartu terdaftar" : "Registrasi kartu" }}
          </h1>
          <span class="toolbar-subtitle">
            {{ uid ? `RFID ${uid}` : cardMode === "fusion" ? "Virtual fusion card" : "Menunggu kartu RFID" }}
          </span>
        </div>
      </div>

      <div class="toolbar-center" role="radiogroup" aria-label="Mode kartu">
        <div class="ide-segmented-control">
          <label :class="{ active: cardMode === 'new' }">
            <input v-model="cardMode" type="radio" value="new" @change="handleCardModeChange" />
            Fisik
          </label>
          <label :class="{ active: cardMode === 'copy' }">
            <input v-model="cardMode" type="radio" value="copy" @change="handleCardModeChange" />
            Salin kartu
          </label>
          <label :class="{ active: cardMode === 'fusion', fusion: cardMode === 'fusion' }">
            <input v-model="cardMode" type="radio" value="fusion" @change="handleCardModeChange" />
            Fusion
          </label>
        </div>
      </div>

      <div class="toolbar-right">
        <button type="button" class="ide-btn outline" @click="resetForm">Reset</button>
        <button type="submit" form="register-game-card-form" class="ide-btn primary" :disabled="loading || compressingImage">
          <span v-if="loading || compressingImage" class="ide-spinner" aria-hidden="true"></span>
          {{ loading ? "Menyimpan…" : compressingImage ? "Mengompres gambar…" : isExistingCard ? "Simpan perubahan" : "Simpan kartu" }}
        </button>
      </div>
    </header>

    <div v-if="errorMessage" class="alert error" role="alert">{{ errorMessage }}</div>
    <div v-if="successMessage" class="alert success" role="status">{{ successMessage }}</div>

    <div class="form-grid-layout ide-main-grid">

      <!-- FORM INPUT -->

      <div class="panel-card">

        <form id="register-game-card-form" class="bento-form" @submit.prevent="handleSubmit">

          <!-- =====================================================
               QUICK BENTO: SOURCE / IDENTITY / STATS / MEDIA
          ====================================================== -->
          <div class="register-bento-grid">

            <!-- SOURCE / RFID -->
            <section class="bento-card bento-source">
              <div class="bento-card-head">
                <div>
                  <span class="section-eyebrow">01 • SOURCE</span>
                  <h3>{{ cardMode === "fusion" ? "Virtual Card Source" : "RFID Source" }}</h3>
                </div>
                <span
                  class="status-dot"
                  :class="{
                    ready: cardMode === 'fusion' || Boolean(uid),
                    waiting: cardMode !== 'fusion' && !uid,
                  }"
                ></span>
              </div>

              <template v-if="cardMode !== 'fusion'">
                <div class="rfid-display">
                  <span class="rfid-icon">📡</span>
                  <div>
                    <small>RFID UID</small>
                    <strong>{{ uid || "Menunggu kartu..." }}</strong>
                  </div>
                  <span
                    class="status-pill"
                    :class="isExistingCard ? 'info' : uid ? 'success' : 'muted'"
                  >
                    {{
                      isExistingCard
                        ? "EDIT"
                        : uid
                          ? "READY"
                          : "WAITING"
                    }}
                  </span>
                </div>

                <div v-if="cardMode === 'copy'" class="input-group compact-field">
                  <label for="copySourceCard">Pilih kartu dari akun / katalog</label>
                  <SearchableSelect
                    id="copySourceCard"
                    v-model="copySourceCardId"
                    @change="loadCopySourceCard"
                  >
                    <option value="">-- Pilih kartu tersimpan --</option>
                    <option
                      v-for="card in physicalCopySources"
                      :key="card.id"
                      :value="card.id"
                    >
                      {{ card.name }} — {{ card.metadata?.source_card_code || card.card_code }}{{ card.metadata?.studio_card ? " · Studio" : "" }}
                    </option>
                  </SearchableSelect>
                  <small class="help-text">
                    Stats, element, media, tags, Card Code, dan Special Skill ikut dicopy.
                    UID tetap memakai RFID baru.
                  </small>
                </div>
              </template>

              <template v-else>
                <div class="virtual-source">
                  <span class="virtual-orb">🧬</span>
                  <div>
                    <strong>Fusion Virtual Card</strong>
                    <p>Tidak memakai RFID. UID akan disimpan sebagai <code>NULL</code>.</p>
                  </div>
                </div>

                <div class="input-group compact-field">
                  <label for="fusionExistingCard">Edit Existing Fusion Card</label>
                  <SearchableSelect
                    id="fusionExistingCard"
                    v-model="selectedFusionCardId"
                    @change="loadFusionCardForEdit"
                  >
                    <option value="">+ Buat Fusion Card Baru</option>
                    <option
                      v-for="card in fusionCardOptions"
                      :key="card.id"
                      :value="card.id"
                    >
                      {{ card.name }} — {{ card.card_code }}
                    </option>
                  </SearchableSelect>
                </div>
              </template>
            </section>

            <section class="bento-card"><h3>Desain &amp; publikasi</h3><p>Gunakan data kartu ini di Studio. Pilih kartu yang ditampilkan ke publik melalui Album.</p><RouterLink v-if="recordId || copySourceCardId" :to="{name:'card-generator',query:{catalog:recordId || copySourceCardId}}">Edit desain di Studio →</RouterLink><RouterLink :to="{name:'album-card'}">Kelola publikasi di Album →</RouterLink></section>

            <!-- IDENTITY -->
            <section class="bento-card bento-identity-card">
              <div class="bento-card-head">
                <div>
                  <span class="section-eyebrow">02 • IDENTITY</span>
                  <h3>Card Identity</h3>
                </div>
                <span class="status-pill accent">
                  {{ cardMode === "fusion" ? "FUSION" : cardMode === "copy" ? "COPY" : "PHYSICAL" }}
                </span>
              </div>

              <div class="input-group">
                <label for="name">Nama Karakter / Monster</label>
                <input
                  id="name"
                  v-model="cardName"
                  type="text"
                  placeholder="e.g. Thunder Beast"
                  autocomplete="off"
                  required
                />
              </div>

              <div class="input-group">
                <div class="field-label-row">
                  <label for="cardCode">Card Code</label>
                  <span v-if="cardMode === 'copy'" class="auto-code-pill locked">LOCKED</span>
                  <button
                    v-else-if="!cardCodeAuto"
                    type="button"
                    class="auto-code-button"
                    @click="enableAutoCardCode"
                  >
                    ↻ Gunakan Auto Code
                  </button>
                  <button
                    v-else
                    type="button"
                    class="auto-code-button auto-on"
                    @click="cardCodeAuto = false"
                  >
                    AUTO • Edit manual
                  </button>
                </div>

                <div class="code-input-wrap">
                  <input
                    id="cardCode"
                    v-model="cardCode"
                    type="text"
                    :readonly="cardMode === 'copy' || cardCodeAuto"
                    placeholder="THUNDER_BEAST"
                    @input="cardCodeAuto = false"
                  />
                  <span class="code-preview">{{ cardCode || "AUTO_FROM_NAME" }}</span>
                </div>

                <small class="help-text">
                  {{
                    cardMode === "copy"
                      ? "Copy selalu mempertahankan Card Code card sumber."
                      : cardCodeAuto
                        ? "Otomatis mengikuti Card Name seperti slug."
                        : "Manual mode aktif. Klik Gunakan Auto Code untuk sinkron lagi."
                  }}
                </small>
              </div>

              <div class="input-group">
                <label for="tags">Fusion Tags</label>
                <input
                  id="tags"
                  v-model="tagsInput"
                  type="text"
                  placeholder="dragon, beast, mage"
                />
                <div v-if="parseTags(tagsInput).length" class="tag-chip-row">
                  <span
                    v-for="tag in parseTags(tagsInput)"
                    :key="tag"
                    class="tag-chip"
                  >
                    #{{ tag }}
                  </span>
                </div>
                <small class="help-text">
                  Digunakan Fusion matcher berbasis tag. Pisahkan dengan koma.
                </small>
              </div>
            </section>

            <!-- ELEMENT -->
            <section class="bento-card bento-element-card">
              <div class="bento-card-head">
                <div>
                  <span class="section-eyebrow">03 • ELEMENT</span>
                  <h3>Element</h3>
                </div>
                <span
                  class="status-pill"
                  :class="elementSupportsSynergy ? 'success' : 'warning'"
                >
                  {{ elementSupportsSynergy ? "SYNERGY READY" : "CUSTOM" }}
                </span>
              </div>

              <div class="element-hero">
                <span class="element-symbol">
                  {{
                    {
                      knight: "🛡️",
                      fire: "🔥",
                      water: "💧",
                      forest: "🌿",
                      thunder: "⚡",
                      light: "✨",
                      dark: "🌑",
                    }[canonicalElement(element)] || "✦"
                  }}
                </span>
                <div>
                  <small>Selected Element</small>
                  <strong>{{ element || "Belum dipilih" }}</strong>
                </div>
              </div>

              <div class="input-group compact-field">
                <label for="element">Pilih Element</label>
                <SearchableSelect id="element" v-model="element">
                  <option
                    v-for="item in elementOptions"
                    :key="item"
                    :value="item"
                  >
                    {{ item }}
                  </option>
                </SearchableSelect>
              </div>

              <div class="inline-element-add">
                <input
                  v-model="newElementName"
                  type="text"
                  placeholder="Element baru, e.g. Earth"
                  @keyup.enter.prevent="addElementOption"
                />
                <button type="button" class="btn-add-element" @click="addElementOption">
                  + Add
                </button>
              </div>

              <small class="help-text">
                Element baru langsung bisa disimpan ke Card. Synergy engine saat ini
                tetap hanya mengenali Fire, Water, Grass, Electric, Ice, dan Dark.
              </small>
            </section>

            <!-- STATS -->
            <section class="bento-card bento-stats-card">
              <div class="bento-card-head">
                <div>
                  <span class="section-eyebrow">04 • POWER</span>
                  <h3>Battle Stats</h3>
                </div>
                <span class="status-pill muted">BASE STATS</span>
              </div>

              <div class="stat-input-grid">
                <label class="stat-input-card hp-stat">
                  <span>HP</span>
                  <input
                    id="hp"
                    v-model.number="hp"
                    type="number"
                    min="10"
                    max="999"
                    required
                  />
                  <small>Health</small>
                </label>

                <label class="stat-input-card attack-stat">
                  <span>ATK</span>
                  <input
                    id="attack"
                    v-model.number="attack"
                    type="number"
                    min="1"
                    max="999"
                    required
                  />
                  <small>Attack</small>
                </label>

                <label class="stat-input-card defense-stat">
                  <span>DEF</span>
                  <input
                    id="defense"
                    v-model.number="defense"
                    type="number"
                    min="0"
                    max="999"
                    required
                  />
                  <small>Defense</small>
                </label>
              </div>
            </section>

            <!-- MEDIA -->
            <section class="bento-card bento-media-card">
              <div class="bento-card-head">
                <div>
                  <span class="section-eyebrow">05 • MEDIA</span>
                  <h3>Card Artwork</h3>
                </div>
                <span class="status-pill muted">OPTIONAL AVATAR</span>
              </div>

              <div class="input-group">
                <label for="image">Emoji fallback atau URL cover kartu</label>
                <input
                  id="image"
                  v-model="imageUrl"
                  type="text"
                  placeholder="🔥 atau https://.../cover.webp"
                  required
                />
              </div>

              <div class="input-group card-image-upload">
                <label for="card-image-file">Upload cover kartu</label>
                <input
                  id="card-image-file"
                  ref="cardImageInput"
                  type="file"
                  accept="image/jpeg,image/png,image/webp"
                  :disabled="compressingImage || loading"
                  @change="handleCardImage"
                />
                <small>{{ compressingImage ? "Mengompres ke WebP…" : compressedSizeLabel }}</small>
                <button v-if="compressedCardImage" type="button" class="clear-card-image" @click="clearCardImage">Pakai gambar sebelumnya</button>
              </div>

              <div class="input-group card-image-upload auxiliary-image-upload">
                <label for="physical-card-image-file">Upload gambar kartu fisik</label>
                <input
                  id="physical-card-image-file"
                  ref="physicalCardImageInput"
                  type="file"
                  accept="image/jpeg,image/png,image/webp"
                  :disabled="compressingImage || loading"
                  @change="handlePhysicalCardImage"
                />
                <small>{{ compressingImage ? "Mengompres ke WebP…" : compressedPhysicalCardImage ? `${Math.ceil(compressedPhysicalCardImage.size / 1024)} KB WebP setelah kompres` : "Opsional · maks. 10 MB · hasil WebP maks. 1 MB" }}</small>
                <input v-model="physicalCardImageUrl" type="url" placeholder="URL kartu fisik yang sudah tersimpan (opsional)" aria-label="URL gambar kartu fisik" />
                <img v-if="isImageUrl(physicalCardPreviewUrl)" class="media-image-preview physical-media-preview" :src="physicalCardPreviewUrl" alt="Preview kartu fisik" />
                <button v-if="compressedPhysicalCardImage" type="button" class="clear-card-image" @click="clearPhysicalCardImage">Gunakan gambar fisik tersimpan</button>
              </div>

              <div class="input-group">
                <label for="avatarUrl">Avatar URL</label>
                <input
                  id="avatarUrl"
                  v-model="avatarUrl"
                  type="text"
                  placeholder="PNG / WebP transparan untuk battle animation"
                />
              </div>

              <div class="input-group card-image-upload auxiliary-image-upload">
                <label for="avatar-image-file">Upload avatar</label>
                <input
                  id="avatar-image-file"
                  ref="avatarImageInput"
                  type="file"
                  accept="image/jpeg,image/png,image/webp"
                  :disabled="compressingImage || loading"
                  @change="handleAvatarImage"
                />
                <small>{{ compressingImage ? "Mengompres ke WebP…" : avatarImageFile ? `${Math.ceil(avatarImageFile.size / 1024)} KB WebP setelah kompres` : "Opsional · transparansi PNG/WebP tetap dijaga · hasil maks. 1 MB" }}</small>
                <img v-if="isImageUrl(avatarPreviewUrl)" class="media-image-preview avatar-media-preview" :src="avatarPreviewUrl" alt="Preview avatar" />
                <button v-if="avatarImageFile" type="button" class="clear-card-image" @click="clearAvatarImage">Gunakan avatar URL tersimpan</button>
              </div>

              <div class="media-hint">
                <span>🖼️</span>
                <p>
                  Sebaiknya unggah ilustrasi cover tanpa teks tetap. Nama, statistik,
                  badge, dan skill dirender dari data kartu agar selalu sinkron; avatar
                  transparan dipakai untuk animasi battle.
                </p>
              </div>
            </section>

          </div>

          <div class="ide-advanced-column">
          <!-- =====================================================
               FUSION RECIPE - PHASE 3D.6
          ====================================================== -->
          <div v-if="cardMode === 'fusion'" class="fusion-recipe-section">
            <div class="section-heading">
              <div>
                <span class="section-eyebrow fusion-accent">PHASE 3D.6</span>
                <h3>Fusion Recipe</h3>
                <p>
                  Tentukan material yang harus tersedia untuk memanggil
                  <b>{{ cardName || "Fusion Card ini" }}</b>. Matcher memakai
                  Card Code / Tags, bukan UID RFID.
                </p>
              </div>
            </div>

            <label class="checkbox-option recipe-enable-toggle">
              <input v-model="fusionRecipeEnabled" type="checkbox" />
              Aktifkan Fusion Recipe untuk card ini
            </label>

            <template v-if="fusionRecipeEnabled">
              <div v-if="isExistingCard && fusionRecipes.length" class="input-group">
                <label for="fusionRecipeSelector">Recipe Existing</label>
                <SearchableSelect
                  id="fusionRecipeSelector"
                  v-model="selectedFusionRecipeId"
                  @change="loadSelectedFusionRecipe"
                >
                  <option value="">+ Buat Recipe Baru</option>
                  <option
                    v-for="recipe in fusionRecipes"
                    :key="recipe.id"
                    :value="recipe.id"
                  >
                    {{ recipe.icon || "🔥" }} {{ recipe.name }} — {{ recipe.code }}
                  </option>
                </SearchableSelect>
              </div>

              <div class="recipe-grid">
                <div class="input-group">
                  <label for="fusionRecipeName">Nama Recipe</label>
                  <input
                    id="fusionRecipeName"
                    v-model="fusionRecipeName"
                    type="text"
                    placeholder="e.g. Inferno Awakening"
                  />
                </div>

                <div class="input-group">
                  <div class="field-label-row">
                    <label for="fusionRecipeCode">Recipe Code</label>
                    <button
                      v-if="!fusionRecipeCodeAuto"
                      type="button"
                      class="auto-code-button"
                      @click="enableAutoFusionRecipeCode"
                    >
                      ↻ Gunakan Auto Code
                    </button>
                    <button
                      v-else
                      type="button"
                      class="auto-code-button auto-on"
                      @click="fusionRecipeCodeAuto = false"
                    >
                      AUTO • Edit manual
                    </button>
                  </div>

                  <div class="code-input-wrap">
                    <input
                      id="fusionRecipeCode"
                      v-model="fusionRecipeCode"
                      type="text"
                      :readonly="fusionRecipeCodeAuto"
                      placeholder="inferno_awakening"
                      @input="fusionRecipeCodeAuto = false"
                    />
                    <span class="code-preview">
                      {{ fusionRecipeCode || "auto_recipe_code" }}
                    </span>
                  </div>

                  <small class="help-text">
                    Saat AUTO aktif, Recipe Code langsung mengikuti Recipe Name.
                  </small>
                </div>

                <div class="input-group mini-field">
                  <label for="fusionRecipeIcon">Icon</label>
                  <input
                    id="fusionRecipeIcon"
                    v-model="fusionRecipeIcon"
                    type="text"
                    placeholder="🔥"
                  />
                </div>
              </div>

              <div class="input-group">
                <label for="fusionRecipeDescription">Deskripsi Recipe</label>
                <textarea
                  id="fusionRecipeDescription"
                  v-model="fusionRecipeDescription"
                  rows="3"
                  placeholder="Contoh: Fusion Charizard dan Moltres untuk memanggil Inferno Dragon."
                ></textarea>
              </div>

              <div class="fusion-fixed-rules">
                <span><b>Result Zone:</b> Active</span>
                <span><b>Material Destination:</b> Graveyard</span>
                <span><b>Cost:</b> None</span>
              </div>

              <div class="recipe-subsection">
                <div class="recipe-subsection-head">
                  <div>
                    <span class="section-eyebrow">MATERIAL MATCHER</span>
                    <h4>Material Requirements</h4>
                    <p>
                      Gunakan Graveyard sebagai allowed zone untuk membuat
                      Necro Fusion. Satu Battle Card tidak dapat dipakai dua kali.
                    </p>
                  </div>

                  <button
                    type="button"
                    class="btn-mini fusion-add-btn"
                    @click="addFusionRequirement"
                  >
                    + Material
                  </button>
                </div>

                <div
                  v-for="(req, index) in fusionRequirements"
                  :key="req._key"
                  class="fusion-material-card"
                >
                  <div class="fusion-material-title">
                    <strong>Material #{{ index + 1 }}</strong>
                    <button
                      v-if="fusionRequirements.length > 1"
                      type="button"
                      class="material-remove-btn"
                      @click="removeFusionRequirement(index)"
                    >
                      Hapus
                    </button>
                  </div>

                  <div class="input-row">
                    <div class="input-group">
                      <label>Requirement Type</label>
                      <SearchableSelect v-model="req.material_type">
                        <option value="exact_card">Exact Card</option>
                        <option value="one_of">One Of</option>
                        <option value="tag">Tag</option>
                      </SearchableSelect>
                    </div>

                    <div class="input-group">
                      <label>Quantity</label>
                      <input
                        v-model.number="req.quantity"
                        type="number"
                        min="1"
                        max="20"
                      />
                      <small class="help-text">
                        Contoh PIKACHU ×3 → Quantity = 3.
                      </small>
                    </div>
                  </div>

                  <div v-if="req.material_type === 'exact_card'" class="input-group">
                    <label>Exact Logical Card</label>
                    <SearchableSelect v-model="req.card_code">
                      <option value="">-- Pilih Card --</option>
                      <option
                        v-for="card in fusionMaterialCardOptions"
                        :key="`exact-${req._key}-${card.card_code}`"
                        :value="card.card_code"
                      >
                        {{ card.fusion_only ? "🧬 " : "" }}{{ card.name }} — {{ card.card_code }}
                      </option>
                    </SearchableSelect>
                  </div>

                  <div v-else-if="req.material_type === 'one_of'" class="input-group">
                    <label>One Of Cards</label>
                    <SearchableSelect v-model="req.card_codes" multiple class="multi-select">
                      <option
                        v-for="card in fusionMaterialCardOptions"
                        :key="`oneof-${req._key}-${card.card_code}`"
                        :value="card.card_code"
                      >
                        {{ card.fusion_only ? "🧬 " : "" }}{{ card.name }} — {{ card.card_code }}
                      </option>
                    </SearchableSelect>
                    <small class="help-text">
                      Pilih beberapa alternatif. Contoh: Moltres ATAU Blaziken.
                      Gunakan Ctrl/Cmd untuk memilih lebih dari satu di desktop.
                    </small>
                  </div>

                  <div v-else class="input-group">
                    <label>Required Tag</label>
                    <input
                      v-model="req.tag"
                      type="text"
                      placeholder="e.g. dragon"
                    />
                    <small class="help-text">
                      Tag bersifat lowercase. Contoh: dragon, mage, beast.
                    </small>
                  </div>

                  <div class="zone-picker">
                    <span class="zone-picker-label">Allowed Zones</span>

                    <label class="zone-option">
                      <input
                        v-model="req.allowed_zones"
                        type="checkbox"
                        value="active"
                      />
                      Active
                    </label>

                    <label class="zone-option">
                      <input
                        v-model="req.allowed_zones"
                        type="checkbox"
                        value="bench"
                      />
                      Bench
                    </label>

                    <label class="zone-option necro-zone">
                      <input
                        v-model="req.allowed_zones"
                        type="checkbox"
                        value="graveyard"
                      />
                      ☠ Graveyard
                    </label>
                  </div>
                </div>
              </div>

              <div class="recipe-subsection">
                <div class="recipe-subsection-head">
                  <div>
                    <span class="section-eyebrow">RESULT POWER</span>
                    <h4>Fusion Stat Formula</h4>
                    <p>
                      Base stats material digunakan, bukan HP material yang
                      sudah berkurang saat battle.
                    </p>
                  </div>
                </div>

                <div class="fusion-stat-grid">
                  <div class="fusion-stat-card">
                    <strong>HP</strong>
                    <SearchableSelect v-model="fusionHpMode">
                      <option value="material_sum_percent">Sum × Multiplier</option>
                      <option value="highest_material_percent">Highest × Multiplier</option>
                      <option value="fixed">Fixed</option>
                    </SearchableSelect>
                    <input v-model.number="fusionHpValue" type="number" min="0" step="0.05" />
                    <small>{{ fusionHpMode === 'fixed' ? 'Nilai HP tetap.' : '0.8 = 80%.' }}</small>
                  </div>

                  <div class="fusion-stat-card">
                    <strong>ATK</strong>
                    <SearchableSelect v-model="fusionAttackMode">
                      <option value="material_sum_percent">Sum × Multiplier</option>
                      <option value="highest_material_percent">Highest × Multiplier</option>
                      <option value="fixed">Fixed</option>
                    </SearchableSelect>
                    <input v-model.number="fusionAttackValue" type="number" min="0" step="0.05" />
                    <small>{{ fusionAttackMode === 'fixed' ? 'Nilai ATK tetap.' : '0.8 = 80%.' }}</small>
                  </div>

                  <div class="fusion-stat-card">
                    <strong>DEF</strong>
                    <SearchableSelect v-model="fusionDefenseMode">
                      <option value="material_sum_percent">Sum × Multiplier</option>
                      <option value="highest_material_percent">Highest × Multiplier</option>
                      <option value="fixed">Fixed</option>
                    </SearchableSelect>
                    <input v-model.number="fusionDefenseValue" type="number" min="0" step="0.05" />
                    <small>{{ fusionDefenseMode === 'fixed' ? 'Nilai DEF tetap.' : '0.8 = 80%.' }}</small>
                  </div>
                </div>
              </div>

              <div class="recipe-subsection">
                <div class="recipe-subsection-head">
                  <div>
                    <span class="section-eyebrow">LIMITS</span>
                    <h4>Usage Rules</h4>
                  </div>
                </div>

                <div class="skill-check-row">
                  <label class="checkbox-option">
                    <input v-model="fusionOncePerBattle" type="checkbox" />
                    Once Per Battle
                  </label>

                  <label class="checkbox-option">
                    <input v-model="fusionConsumesTurn" type="checkbox" />
                    Consumes Turn
                  </label>
                </div>

                <div class="input-group fusion-max-uses">
                  <label for="fusionMaxUses">Max Uses</label>
                  <input
                    id="fusionMaxUses"
                    v-model.number="fusionMaxUses"
                    type="number"
                    min="0"
                  />
                  <small class="help-text">0 = unlimited. Jika Once Per Battle aktif, gunakan 1.</small>
                </div>
              </div>
            </template>
          </div>


          <!-- =====================================================
               SPECIAL SKILL
          ====================================================== -->
          <div class="special-skill-section">
            <div class="section-heading">
              <div>
                <span class="section-eyebrow">TCG V1</span>
                <h3>Special Skill</h3>
                <p>
                  Kemampuan bawaan kartu. Special Skill berbeda dengan Bonus
                  Skill dari Coding Question.
                </p>
              </div>
            </div>

            <section v-if="builtinCardSkills.length" class="builtin-skill-toggle-list" aria-label="Skill bawaan kartu">
              <header>
                <div>
                  <strong>Skill bawaan kartu</strong>
                  <small>Aktifkan skill yang sudah memiliki aturan battle. Perubahan disimpan bersama kartu.</small>
                </div>
                <span>{{ builtinCardSkills.filter((item) => item.enabled).length }} aktif</span>
              </header>

              <article v-for="item in builtinCardSkills" :key="item.key" class="builtin-skill-toggle-row">
                <div class="builtin-skill-toggle-copy">
                  <div class="registration-skill-heading"><span class="registration-skill-art"><SkillIcon :icon="item.icon" :name="item.name" /></span><strong>{{ item.name }}</strong></div>
                  <small>{{ item.description || "Belum ada deskripsi skill." }}</small>
                  <em v-if="!item.battleReady">
                    {{ item.definition ? "Belum aktif di Skill Catalog; lengkapi efek dan aturan battle terlebih dahulu." : "Skill ini belum terdaftar di Skill Catalog." }}
                  </em>
                  <RouterLink v-if="!item.battleReady" class="skill-catalog-link" to="/admin/game/catalog">
                    Atur aturan skill →
                  </RouterLink>
                </div>
                <label class="skill-toggle" :class="{ disabled: !item.battleReady }">
                  <input
                    type="checkbox"
                    :checked="item.enabled"
                    :disabled="!item.battleReady"
                    :aria-label="`${item.enabled ? 'Nonaktifkan' : 'Aktifkan'} skill ${item.name}`"
                    @change="setBuiltinSkillEnabled(item, $event)"
                  />
                  <span aria-hidden="true"></span>
                </label>
              </article>
            </section>

            <div class="input-group">
              <label for="specialSkillMode">Special Skill</label>

              <SearchableSelect
                id="specialSkillMode"
                v-model="specialSkillMode"
                @change="handleSpecialSkillModeChange"
              >
                <option value="none">
                  Tidak Memiliki Special Skill
                </option>

                <option value="existing">
                  Pilih Existing Skill
                </option>

                <option value="new">
                  Buat Special Skill Baru
                </option>
              </SearchableSelect>
            </div>

            <div class="necro-skill-preset">
              <div>
                <strong>☠ NECRO PRESET • SOUL REBIRTH</strong>
                <small>Korbankan kartu ini untuk membangkitkan 1 kartu milikmu dari Graveyard ke Active dengan 50% Base HP.</small>
              </div>

              <button
                type="button"
                class="btn-necro-preset"
                :disabled="!soulRebirthSkill"
                @click="assignSoulRebirthPreset"
              >
                {{ soulRebirthSkill ? "PAKAI SOUL REBIRTH" : "JALANKAN SQL PRESET" }}
              </button>
            </div>

            <div class="status-skill-presets">
              <div class="status-preset-heading">
                <strong>STATUS EFFECT PRESETS • PHASE 3D.19</strong>
                <small>Effect tidak otomatis hanya karena element. Pasang preset ini ke Card yang memang memiliki skill tersebut.</small>
              </div>

              <div class="status-preset-grid">
                <button
                  v-for="preset in statusSkillPresetCards"
                  :key="preset.code"
                  type="button"
                  class="status-preset-card"
                  :disabled="!preset.skill"
                  @click="assignStatusSkillPreset(preset)"
                >
                  <span>{{ preset.icon }}</span>
                  <div>
                    <strong>{{ preset.label }}</strong>
                    <small>{{ preset.hint }}</small>
                  </div>
                  <b>{{ preset.skill ? "USE" : "SQL" }}</b>
                </button>
              </div>
            </div>

            <!-- EXISTING SPECIAL SKILL -->
            <template v-if="specialSkillMode === 'existing'">
              <div class="input-group">
                <label for="existingSkill">Pilih Skill</label>

                <SearchableSelect
                  id="existingSkill"
                  v-model="selectedSpecialSkillId"
                >
                  <option value="">
                    -- Pilih Special Skill --
                  </option>

                  <option
                    v-if="selectedSpecialSkill?.metadata?.catalog_only && !selectedSkillIsActiveOption"
                    :value="selectedSpecialSkill.id"
                  >
                    {{ selectedSpecialSkill.name }} (Katalog, belum aktif di battle)
                  </option>

                  <option
                    v-for="skill in specialSkills"
                    :key="skill.id"
                    :value="skill.id"
                  >
                    {{ skillOptionLabel(skill) }}
                  </option>
                </SearchableSelect>
              </div>

              <div
                v-if="selectedSpecialSkill"
                class="skill-summary-card"
              >
                <div class="skill-summary-head">
                  <div class="skill-summary-icon">
                    <SkillIcon :icon="selectedSpecialSkill.icon" :name="selectedSpecialSkill.name" />
                  </div>

                  <div>
                    <strong>{{ selectedSpecialSkill.name }}</strong>
                    <span>{{ selectedSpecialSkill.skill_type === 'active' ? 'Skill aktif · dipakai saat giliranmu' : 'Skill kartu' }}</span>
                  </div>
                </div>

                <p>
                  {{ selectedSpecialSkill.description || "Tidak ada deskripsi." }}
                </p>
                <label v-if="splitSkillIcon(selectedSpecialSkill.icon).imageUrl" class="registration-skill-source">Gambar skill
                  <input :value="splitSkillIcon(selectedSpecialSkill.icon).imageUrl" type="text" readonly aria-label="URL gambar skill tersimpan" />
                </label>

                <small v-if="selectedSpecialSkill.metadata?.catalog_only" class="help-text">
                  Skill ini sudah tertaut ke kartu sebagai data katalog. Efek battle-nya belum diaktifkan karena dokumen sumber menandainya perlu playtest.
                </small>

                <div class="skill-summary-grid">
                  <span>
                    Target:
                    <strong>{{ humanTargetLabel(resolveTargetTypeFromSkill(selectedSpecialSkill)) }}</strong>
                  </span>

                  <span>
                    Cooldown:
                    <strong>{{ skillLimitLabel(selectedSpecialSkill) }}</strong>
                  </span>

                  <span>
                    Max Uses:
                    <strong>{{ selectedSpecialSkill.limits?.once_per_battle ? '1× per battle' : selectedSpecialSkill.limits?.max_uses || 'Tidak terbatas' }}</strong>
                  </span>

                  <span>
                    Poin giliran:
                    <strong>{{ selectedSpecialSkill.limits?.action_points ?? 1 }} AP{{ selectedSpecialSkill.consumes_turn ? ' · mengakhiri giliran' : '' }}</strong>
                  </span>
                </div>

                <RouterLink v-if="cardMetadata?.studio_card" class="btn-edit-skill" :to="{name:'skill-catalog',query:{skill:selectedSpecialSkill.id}}">Edit nama, gambar &amp; aturan skill →</RouterLink>
                <button v-else
                  type="button"
                  class="btn-edit-skill"
                  @click="startEditSelectedSkill"
                >
                  ✏️ Edit Skill Ini
                </button>

                <small class="master-warning">
                  Catatan: Edit akan mengubah master Special Skill. Jika skill yang sama dipakai Card lain, Card tersebut ikut memakai versi terbaru pada battle baru.
                </small>
              </div>
            </template>

            <!-- CREATE NEW SPECIAL SKILL -->
            <template v-if="specialSkillMode === 'new' || specialSkillMode === 'edit'">
              <div v-if="specialSkillMode === 'edit'" class="edit-mode-banner">
                <div>
                  <strong>✏️ Mode Edit Special Skill</strong>
                  <span>Kamu sedang mengubah {{ selectedSpecialSkill?.name }}.</span>
                </div>

                <button type="button" class="btn-mini" @click="cancelSkillEdit">
                  Batal Edit
                </button>
              </div>

              <div class="input-row">
                <div class="input-group">
                  <label for="skillName">Nama Skill</label>

                  <input
                    id="skillName"
                    v-model="skillName"
                    type="text"
                    placeholder="e.g. Flame Burst"
                  />
                </div>

                <div class="input-group">
                  <div class="field-label-row">
                    <label for="skillCode">Skill Code</label>

                    <button
                      v-if="!skillCodeAuto"
                      type="button"
                      class="auto-code-button"
                      @click="enableAutoSkillCode"
                    >
                      ↻ Gunakan Auto Code
                    </button>

                    <button
                      v-else
                      type="button"
                      class="auto-code-button auto-on"
                      @click="skillCodeAuto = false"
                    >
                      AUTO • Edit manual
                    </button>
                  </div>

                  <div class="code-input-wrap">
                    <input
                      id="skillCode"
                      v-model="skillCode"
                      type="text"
                      :readonly="skillCodeAuto"
                      placeholder="flame_burst"
                      @input="skillCodeAuto = false"
                    />

                    <span class="code-preview">
                      {{ skillCode || "auto_skill_code" }}
                    </span>
                  </div>

                  <small class="help-text">
                    Skill Code otomatis mengikuti Nama Skill ketika AUTO aktif.
                  </small>
                </div>
              </div>

              <div class="input-group">
                <label for="skillDescription">Penjelasan skill</label>

                <textarea
                  id="skillDescription"
                  v-model="skillDescription"
                  rows="3"
                  placeholder="Jelaskan mekanik Special Skill..."
                ></textarea>
              </div>

              <div class="input-row">
                <div class="input-group">
                  <label for="skillIcon">Simbol pengganti</label>

                  <input
                    id="skillIcon"
                    v-model="skillIcon"
                    type="text"
                    placeholder="🔥"
                    maxlength="32"
                  />
                </div>
                <div class="input-group">
                  <label for="skillActionPoints">Biaya poin giliran (AP)</label>
                  <select id="skillActionPoints" v-model.number="skillActionPoints"><option :value="1">1 AP</option><option :value="2">2 AP</option></select>
                </div>

              </div>
              <section class="registration-skill-media" aria-label="Gambar skill">
                <span class="registration-skill-art"><SkillIcon :icon="skillImageUrl || skillIcon" :name="skillName" /></span>
                <div class="input-group"><label for="skillImageUrl">URL gambar skill</label><input id="skillImageUrl" v-model="skillImageUrl" type="text" inputmode="url" placeholder="https://…/skill.webp" /><small class="help-text">Gambar ditampilkan sebagai ikon. Nama dan penjelasan skill tetap diisi terpisah.</small></div>
              </section>
              <div class="input-row">

                <div class="input-group">
                  <label for="skillTargetType">Target</label>

                  <SearchableSelect
                    id="skillTargetType"
                    v-model="skillTargetType"
                  >
                    <option value="enemy_active">
                      Enemy Active Card
                    </option>

                    <option value="ally_active">
                      Ally Active Card
                    </option>
                    <option v-if="skillTargetType === 'ally_field'" value="ally_field">Kartu milikmu di Active atau Bench</option>

                    <option value="self_card">
                      Self Card
                    </option>

                    <option value="self_player">
                      Self Player
                    </option>

                    <option value="enemy_player">
                      Enemy Player
                    </option>

                    <option value="ally_graveyard">
                      Ally Graveyard
                    </option>

                    <option value="enemy_graveyard">
                      Enemy Graveyard
                    </option>
                  </SearchableSelect>
                </div>
              </div>

              <div class="input-row">
                <div class="input-group">
                  <label for="skillCostType">Cost</label>

                  <SearchableSelect
                    id="skillCostType"
                    v-model="skillCostType"
                  >
                    <option value="none">
                      Free / None
                    </option>

                    <option value="skill_gauge">
                      Skill Gauge
                    </option>
                  </SearchableSelect>
                </div>

                <div
                  v-if="skillCostType !== 'none'"
                  class="input-group"
                >
                  <label for="skillCostValue">Cost Value</label>

                  <input
                    id="skillCostValue"
                    v-model.number="skillCostValue"
                    type="number"
                    min="0"
                    max="100"
                  />
                </div>
              </div>

              <div class="input-row">
                <div class="input-group">
                  <label for="skillCooldownUnit">Hitung cooldown per</label><select id="skillCooldownUnit" v-model="skillCooldownUnit"><option value="owner">Giliran pemilik</option><option value="round">Round (aturan lama)</option></select>
                  <label for="skillCooldownRounds">
                    Cooldown
                  </label>

                  <input
                    id="skillCooldownRounds"
                    v-model.number="skillCooldownRounds"
                    type="number"
                    min="0"
                  />
                </div>

                <div class="input-group">
                  <label for="skillMaxUses">Max Uses</label>

                  <input
                    id="skillMaxUses"
                    v-model.number="skillMaxUses"
                    type="number"
                    min="0"
                  />

                  <small class="help-text">
                    0 = unlimited.
                  </small>
                </div>
              </div>

              <div class="skill-check-row">
                <label class="checkbox-option">
                  <input
                    v-model="skillOncePerBattle"
                    type="checkbox"
                  />

                  Once Per Battle
                </label>

                <label class="checkbox-option">
                  <input
                    v-model="skillConsumesTurn"
                    type="checkbox"
                  />

                  Consumes Turn
                </label>
              </div>

              <div class="effect-builder">
                <div class="section-heading compact">
                  <span class="section-eyebrow">EFEK SKILL</span>
                  <h4>Efek yang dilakukan</h4>
                  <p>
                    Untuk skill sederhana, kamu tidak perlu menulis JSON.
                    Pilih jenis efek dan nilai di bawah ini.
                  </p>
                </div>

                <div class="input-row">
                  <div class="input-group">
                    <label for="skillEffectType">Jenis Efek</label>

                    <SearchableSelect
                      id="skillEffectType"
                      v-model="skillEffectType"
                      :disabled="skillAdvancedMode"
                    >
                      <option value="" disabled>-- Pilih jenis efek --</option>
                      <option value="damage_card">Damage ke Card</option>
                      <option value="heal_card">Heal Card</option>
                      <option value="damage_player">Damage langsung ke Player</option>
                      <option value="heal_player">Heal Player</option>
                      <option value="add_skill_gauge">Tambah Skill Gauge</option>
                    </SearchableSelect>

                    <small v-if="skillAdvancedMode" class="help-text">
                      Advanced Mode aktif. Matikan centangnya di bawah untuk mengubah satu jenis efek sederhana.
                    </small>
                  </div>

                  <div class="input-group">
                    <label for="skillEffectAmount">Nilai Efek</label>

                    <input
                      id="skillEffectAmount"
                      v-model.number="skillEffectAmount"
                      type="number"
                      min="0"
                      :disabled="skillAdvancedMode"
                    />

                    <small class="help-text">
                      Contoh: 30 berarti Damage 30 / Heal 30 / Gauge +30.
                    </small>
                  </div>
                </div>

                <div class="effect-example" v-if="!skillAdvancedMode">
                  <strong>Skill ini akan:</strong>
                  {{ humanEffectLabel(skillEffectType) }}
                  sebesar <b>{{ skillEffectAmount }}</b>
                  ke <b>{{ humanTargetLabel(skillTargetType) }}</b>.
                </div>
                <button v-if="!skillAdvancedMode" type="button" class="btn-edit-skill" @click="suggestSkillCopy">Isi nama &amp; penjelasan dari aturan</button>

                <label class="checkbox-option advanced-toggle">
                  <input
                    v-model="skillAdvancedMode"
                    type="checkbox"
                  />

                  Advanced Mode — edit Generic Effects JSON
                </label>

                <div v-if="skillAdvancedMode" class="input-group">
                  <label for="skillEffectsJson">
                    Generic Effects JSON (Advanced)
                  </label>

                  <textarea
                    id="skillEffectsJson"
                    v-model="skillEffectsJson"
                    rows="14"
                    class="json-editor"
                    spellcheck="false"
                  ></textarea>

                  <small class="help-text">
                    Gunakan Advanced Mode hanya untuk multi-effect seperti damage + lifesteal, revive, status, sacrifice, dan kombinasi kompleks lainnya.
                  </small>
                </div>
              </div>
            </template>
          </div>

          </div>

        </form>

      </div>



      <!-- LIVE PREVIEW KARTU -->

      <!-- LIVE PREVIEW KARTU -->

      <div class="panel-card preview-panel">

        <h3>Preview Kartu</h3>

        <p class="preview-desc">

          Tampilan kartu saat nanti dipanggil di Arena.

        </p>



        <div class="preview-card-box" :class="slugifyFusionRecipeCode(element)">

          <div class="preview-header">

            <span class="p-name">{{ cardName || "Nama Karakter" }}</span>

            <span class="p-hp">HP {{ hp }}</span>

          </div>



          <!-- ARTBOX PREVIEW DIPERBAIKI -->

          <div class="preview-artbox">

            <img

              v-if="isImageUrl(cardImagePreviewUrl)"

              :src="cardImagePreviewUrl"

              class="preview-img-asset"

            />

            <span v-else>{{ imageUrl }}</span>

          </div>



          <div class="preview-footer">

            <div class="p-stat">

              ATK: <strong>{{ attack }}</strong>

            </div>

            <div class="p-stat">

              DEF: <strong>{{ defense }}</strong>

            </div>

          </div>

          <div class="preview-identity-tags">
            <span>CODE: {{ cardCode || slugifyCardCode(cardName) || "—" }}</span>
            <span v-if="cardMode === 'fusion'" class="fusion-badge">FUSION ONLY</span>
          </div>

          <div class="preview-uid-tag">
            {{ cardMode === "fusion" ? "UID: VIRTUAL / NONE" : `UID: ${uid || "— — — —"}` }}
          </div>

        </div>

      </div>

    </div>

  </div>

</template>



<style scoped>
.landing-toggle{display:flex;align-items:center;gap:10px}.landing-toggle input{width:18px!important;height:18px}.landing-fields{display:grid;gap:14px;margin-top:16px}.landing-fields label{display:grid;gap:6px}.landing-fields .landing-toggle{display:flex}.landing-card-preview{display:flex;align-items:center;gap:12px;padding:14px;background:#f2f7ef;border:1px solid #d7e3d4;border-radius:12px}.landing-card-preview img{width:70px;height:90px;object-fit:contain}.landing-card-preview div{display:grid;gap:6px}.landing-fields p{font-size:13px;color:#526458}


.register-container {

  padding: 30px;

  color: white;

  background-color: #0b132b;

  min-height: 85vh;

  border-radius: 12px;

  border: 1px solid #1e293b;

  font-family: "Segoe UI", Tahoma, Geneva, Verdana, sans-serif;

}

.header-section {

  margin-bottom: 25px;

}

.eyebrow {

  font-size: 10px;

  font-weight: bold;

  color: #38bdf8;

  letter-spacing: 2px;

  text-transform: uppercase;

}

.header-section h2 {

  font-size: 24px;

  font-weight: 900;

  margin: 4px 0;

}

.header-section p {

  font-size: 13px;

  color: #94a3b8;

}



.alert {

  padding: 12px 16px;

  border-radius: 8px;

  margin-bottom: 20px;

  font-size: 13px;

  font-weight: bold;

}

.alert.error {

  background-color: rgba(239, 68, 68, 0.2);

  border: 1px solid #ef4444;

  color: #fca5a5;

}

.alert.success {

  background-color: rgba(34, 197, 94, 0.2);

  border: 1px solid #22c55e;

  color: #86efac;

}



.form-grid-layout {

  display: grid;

  grid-template-columns: 1.2fr 0.8fr;

  gap: 30px;

}

.panel-card {

  background: #0f172a;

  border: 1px solid #1e293b;

  padding: 25px;

  border-radius: 12px;

  box-shadow: 0 4px 20px rgba(0, 0, 0, 0.3);

}



.input-group {

  display: flex;

  flex-direction: column;

  gap: 6px;

  margin-bottom: 15px;

}

.input-row {

  display: grid;

  grid-template-columns: 1fr 1fr;

  gap: 15px;

}



label {

  font-size: 11px;

  font-weight: bold;

  color: #cbd5e1;

  text-transform: uppercase;

  letter-spacing: 0.5px;

}

input,

select,

textarea {

  background: #1e293b;

  border: 1px solid #334155;

  padding: 10px 14px;

  border-radius: 6px;

  color: white;

  font-size: 14px;

  outline: none;

  transition: border-color 0.2s;

}

input:focus,

select:focus,

textarea:focus {

  border-color: #38bdf8;

}

.input-highlight {

  background-color: rgba(56, 189, 248, 0.1);

  border-color: #38bdf8;

  color: #7dd3fc;

  font-weight: bold;

  cursor: not-allowed;

}

.help-text {

  font-size: 10px;

  color: #64748b;

  margin-top: 2px;

}



.button-actions {

  display: flex;

  justify-content: flex-end;

  gap: 12px;

  margin-top: 25px;

}

.btn-secondary {

  background: #334155;

  color: #cbd5e1;

  border: none;

  padding: 10px 20px;

  border-radius: 6px;

  font-weight: bold;

  cursor: pointer;

}

.btn-primary {

  background: #2563eb;

  color: white;

  border: none;

  padding: 10px 24px;

  border-radius: 6px;

  font-weight: bold;

  cursor: pointer;

  transition: background 0.2s;

}

.btn-primary:hover {

  background: #1d4ed8;

}

.btn-primary:disabled {

  background: #475569;

  cursor: not-allowed;

}



/* PREVIEW KARTU */

.preview-panel {

  display: flex;

  flex-direction: column;

  align-items: center;

  text-align: center;

}

.preview-desc {

  font-size: 12px;

  color: #94a3b8;

  margin-bottom: 20px;

}



.preview-card-box {

  width: 220px;

  height: 310px;

  background: #fcd34d;

  border-radius: 14px;

  padding: 10px;

  display: flex;

  flex-direction: column;

  box-shadow: 0 10px 25px rgba(0, 0, 0, 0.5);

  position: relative;

}

.preview-card-box.fire {

  background: linear-gradient(135deg, #f87171, #991b1b);

}

.preview-card-box.water {

  background: linear-gradient(135deg, #60a5fa, #1e3a8a);

}

.preview-card-box.forest {
  background: linear-gradient(135deg, #4ade80, #14532d);
}
.preview-card-box.thunder {
  color: #152333;
  background: linear-gradient(135deg, #fde047, #854d0e);
}
.preview-card-box.knight {
  background: linear-gradient(135deg, #dbe5e9, #526874);
}
.preview-card-box.light {
  color: #493b14;
  background: linear-gradient(135deg, #fff3b0, #e8bf45);
}

.preview-card-box.grass {

  background: linear-gradient(135deg, #4ade80, #14532d);

}

.preview-card-box.electric {

  background: linear-gradient(135deg, #fde047, #854d0e);

}



.preview-header {

  display: flex;

  justify-content: space-between;

  align-items: center;

  color: white;

  font-weight: bold;

  font-size: 12px;

  margin-bottom: 6px;

}

.preview-artbox {

  width: 100%;

  height: 140px;

  background: #1e293b;

  border: 3px solid #cbd5e1;

  border-radius: 6px;

  display: flex;

  align-items: center;

  justify-content: center;

  font-size: 50px;

  box-shadow: inset 0 0 10px rgba(0, 0, 0, 0.8);

  overflow: hidden;

}

.preview-footer {

  display: flex;

  justify-content: space-around;

  background: rgba(0, 0, 0, 0.4);

  border-radius: 6px;

  padding: 6px;

  margin-top: auto;

  font-size: 11px;

  color: white;

}

.preview-uid-tag {

  font-size: 9px;

  color: rgba(255, 255, 255, 0.7);

  margin-top: 6px;

  font-family: monospace;

}



.preview-artbox {

  width: 100%;

  height: 140px;

  background: #1e293b;

  border: 3px solid #cbd5e1;

  border-radius: 6px;

  display: flex;

  align-items: center;

  justify-content: center;

  font-size: 50px;

  box-shadow: inset 0 0 10px rgba(0, 0, 0, 0.8);

  overflow: hidden;

  position: relative;

}



.preview-img-asset {

  position: absolute;

  top: 0;

  left: 0;

  width: 100%;

  height: 100%;

  object-fit: cover;

}


/* =========================================================
   SPECIAL SKILL
========================================================= */

.special-skill-section {
  margin-top: 28px;
  padding-top: 22px;
  border-top: 1px solid #334155;
}

.section-heading {
  margin-bottom: 18px;
}

.section-heading h3 {
  margin: 4px 0;
  font-size: 18px;
}

.section-heading p {
  margin: 0;
  font-size: 12px;
  color: #94a3b8;
  line-height: 1.5;
}

.section-eyebrow {
  font-size: 9px;
  font-weight: 800;
  letter-spacing: 1.5px;
  color: #a78bfa;
  text-transform: uppercase;
}

.skill-check-row {
  display: flex;
  flex-wrap: wrap;
  gap: 20px;
  margin: 10px 0 20px;
}

.checkbox-option {
  display: flex;
  align-items: center;
  gap: 8px;
  text-transform: none;
  letter-spacing: normal;
  cursor: pointer;
}

.checkbox-option input {
  width: auto;
  margin: 0;
}

.json-editor {
  min-height: 260px;
  resize: vertical;
  font-family: "SFMono-Regular", Consolas, "Liberation Mono", monospace;
  line-height: 1.5;
  white-space: pre;
}

textarea {
  width: 100%;
  box-sizing: border-box;
}

@media (max-width: 860px) {
  .form-grid-layout {
    grid-template-columns: 1fr;
  }

  .input-row {
    grid-template-columns: 1fr;
  }
}



.skill-summary-card {
  margin-top: 8px;
  padding: 16px;
  border: 1px solid #334155;
  border-radius: 10px;
  background: rgba(15, 23, 42, 0.8);
}

.skill-summary-head {
  display: flex;
  align-items: center;
  gap: 12px;
}

.skill-summary-head > div:last-child {
  display: flex;
  flex-direction: column;
  gap: 2px;
}

.skill-summary-head span {
  font-size: 11px;
  color: #94a3b8;
  font-family: monospace;
}

.skill-summary-icon {
  width: 42px;
  height: 42px;
  display: grid;
  place-items: center;
  border-radius: 10px;
  background: #1e293b;
  font-size: 22px;
}

.skill-summary-card p {
  margin: 12px 0;
  color: #cbd5e1;
  font-size: 12px;
  line-height: 1.5;
}

.skill-summary-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 8px;
  margin-bottom: 14px;
}

.skill-summary-grid span {
  font-size: 11px;
  color: #94a3b8;
}

.skill-summary-grid strong {
  color: #e2e8f0;
}

.btn-edit-skill,
.btn-mini {
  border: 1px solid #6366f1;
  background: rgba(99, 102, 241, 0.15);
  color: #c7d2fe;
  border-radius: 7px;
  padding: 9px 14px;
  font-weight: 700;
  cursor: pointer;
}

.btn-edit-skill:hover,
.btn-mini:hover {
  background: rgba(99, 102, 241, 0.28);
}

.master-warning {
  display: block;
  margin-top: 10px;
  color: #fbbf24;
  line-height: 1.45;
}

.edit-mode-banner {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 16px;
  padding: 12px 14px;
  margin-bottom: 16px;
  border: 1px solid #6366f1;
  border-radius: 9px;
  background: rgba(79, 70, 229, 0.12);
}

.edit-mode-banner > div {
  display: flex;
  flex-direction: column;
  gap: 3px;
}

.edit-mode-banner span {
  font-size: 11px;
  color: #a5b4fc;
}

.effect-builder {
  margin-top: 18px;
  padding: 16px;
  border: 1px solid #334155;
  border-radius: 10px;
  background: rgba(2, 6, 23, 0.28);
}

.section-heading.compact {
  margin-bottom: 14px;
}

.section-heading.compact h4 {
  margin: 3px 0 4px;
  font-size: 14px;
}

.effect-example {
  padding: 11px 13px;
  margin-bottom: 14px;
  border-radius: 8px;
  background: rgba(34, 197, 94, 0.08);
  border: 1px solid rgba(34, 197, 94, 0.3);
  color: #bbf7d0;
  font-size: 12px;
}

.advanced-toggle {
  margin: 8px 0 14px;
  color: #cbd5e1;
}

@media (max-width: 900px) {
  .skill-summary-grid {
    grid-template-columns: 1fr;
  }

  .edit-mode-banner {
    align-items: flex-start;
    flex-direction: column;
  }
}
/* =========================================================
   PHASE 3D.1 - CARD MODE / IDENTITY
========================================================= */

.card-mode-panel {
  margin-bottom: 18px;
  padding: 16px;
  border: 1px solid rgba(56, 189, 248, 0.18);
  border-radius: 14px;
  background: rgba(15, 23, 42, 0.78);
}

.card-mode-heading {
  display: flex;
  align-items: flex-end;
  justify-content: space-between;
  gap: 12px;
  margin-bottom: 12px;
}

.card-mode-heading h3 {
  margin: 2px 0 0;
}

.identity-note {
  color: #94a3b8;
  font-size: 11px;
}

.card-mode-grid {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 10px;
}

.card-mode-option {
  position: relative;
  min-height: 105px;
  display: flex;
  flex-direction: column;
  justify-content: center;
  gap: 5px;
  padding: 14px;
  border: 1px solid rgba(148, 163, 184, 0.2);
  border-radius: 12px;
  background: rgba(2, 6, 23, 0.38);
  cursor: pointer;
  transition: border-color 0.18s ease, transform 0.18s ease, background 0.18s ease;
}

.card-mode-option:hover {
  transform: translateY(-2px);
  border-color: rgba(56, 189, 248, 0.48);
}

.card-mode-option.active {
  border-color: #38bdf8;
  background: rgba(14, 165, 233, 0.12);
  box-shadow: 0 0 0 1px rgba(56, 189, 248, 0.08);
}

.card-mode-option.fusion.active {
  border-color: #c084fc;
  background: rgba(168, 85, 247, 0.12);
}

.card-mode-option input {
  position: absolute;
  top: 10px;
  right: 10px;
}

.card-mode-option strong {
  color: #f8fafc;
}

.card-mode-option small {
  color: #94a3b8;
  line-height: 1.45;
}

.mode-icon {
  font-size: 22px;
}

.copy-source-box,
.identity-section {
  margin-bottom: 18px;
  padding: 14px;
  border: 1px solid rgba(56, 189, 248, 0.15);
  border-radius: 12px;
  background: rgba(15, 23, 42, 0.45);
}

.fusion-virtual-banner {
  display: flex;
  align-items: flex-start;
  gap: 12px;
  margin-bottom: 16px;
  padding: 14px;
  border: 1px solid rgba(192, 132, 252, 0.35);
  border-radius: 12px;
  background: rgba(126, 34, 206, 0.12);
}

.fusion-virtual-banner strong {
  color: #e9d5ff;
}

.fusion-virtual-banner p {
  margin: 4px 0 0;
  color: #cbd5e1;
  font-size: 12px;
  line-height: 1.55;
}

.fusion-virtual-banner code {
  color: #f0abfc;
}

.fusion-virtual-icon {
  font-size: 24px;
}

.preview-identity-tags {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 8px;
  padding: 6px 8px 0;
  color: rgba(255, 255, 255, 0.8);
  font-size: 8px;
  font-weight: 800;
}

.fusion-badge {
  padding: 3px 6px;
  border: 1px solid rgba(255, 255, 255, 0.34);
  border-radius: 999px;
  background: rgba(126, 34, 206, 0.28);
}

@media (max-width: 780px) {
  .card-mode-grid {
    grid-template-columns: 1fr;
  }

  .card-mode-heading {
    align-items: flex-start;
    flex-direction: column;
  }
}


/* =========================================================
   PHASE 3D.6 - FUSION RECIPE UI
========================================================= */

.fusion-recipe-section {
  margin-top: 22px;
  margin-bottom: 22px;
  padding: 18px;
  border: 1px solid rgba(192, 132, 252, 0.3);
  border-radius: 14px;
  background: linear-gradient(180deg, rgba(88, 28, 135, 0.14), rgba(15, 23, 42, 0.46));
}

.fusion-accent {
  color: #c084fc;
}

.recipe-enable-toggle {
  margin-bottom: 16px;
  padding: 11px 12px;
  border: 1px solid rgba(192, 132, 252, 0.22);
  border-radius: 9px;
  background: rgba(126, 34, 206, 0.08);
}

.recipe-grid {
  display: grid;
  grid-template-columns: minmax(0, 1fr) minmax(0, 1fr) 90px;
  gap: 12px;
}

.mini-field input {
  text-align: center;
}

.fusion-fixed-rules {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
  margin: 12px 0 18px;
}

.fusion-fixed-rules span {
  padding: 7px 10px;
  border: 1px solid rgba(148, 163, 184, 0.18);
  border-radius: 999px;
  background: rgba(2, 6, 23, 0.36);
  color: #cbd5e1;
  font-size: 11px;
}

.recipe-subsection {
  margin-top: 16px;
  padding: 14px;
  border: 1px solid rgba(148, 163, 184, 0.16);
  border-radius: 12px;
  background: rgba(2, 6, 23, 0.3);
}

.recipe-subsection-head {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 12px;
  margin-bottom: 12px;
}

.recipe-subsection-head h4 {
  margin: 3px 0 4px;
  font-size: 14px;
}

.recipe-subsection-head p {
  margin: 0;
  color: #94a3b8;
  font-size: 11px;
  line-height: 1.5;
}

.fusion-add-btn {
  flex: 0 0 auto;
}

.fusion-material-card {
  margin-top: 10px;
  padding: 14px;
  border: 1px solid rgba(192, 132, 252, 0.18);
  border-radius: 11px;
  background: rgba(15, 23, 42, 0.55);
}

.fusion-material-title {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 10px;
  margin-bottom: 10px;
  color: #e9d5ff;
}

.material-remove-btn {
  border: 1px solid rgba(248, 113, 113, 0.32);
  border-radius: 7px;
  padding: 5px 8px;
  background: rgba(127, 29, 29, 0.18);
  color: #fca5a5;
  cursor: pointer;
  font-size: 10px;
  font-weight: 700;
}

.multi-select {
  min-height: 120px;
}

.zone-picker {
  display: flex;
  align-items: center;
  flex-wrap: wrap;
  gap: 8px;
  margin-top: 4px;
}

.zone-picker-label {
  width: 100%;
  color: #94a3b8;
  font-size: 11px;
  font-weight: 700;
}

.zone-option {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  padding: 7px 9px;
  border: 1px solid rgba(56, 189, 248, 0.18);
  border-radius: 8px;
  background: rgba(14, 165, 233, 0.06);
  color: #cbd5e1;
  font-size: 11px;
}

.zone-option.necro-zone {
  border-color: rgba(167, 139, 250, 0.3);
  background: rgba(109, 40, 217, 0.1);
  color: #ddd6fe;
}

.fusion-stat-grid {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 10px;
}

.fusion-stat-card {
  display: flex;
  flex-direction: column;
  gap: 8px;
  padding: 12px;
  border: 1px solid rgba(56, 189, 248, 0.14);
  border-radius: 10px;
  background: rgba(15, 23, 42, 0.52);
}

.fusion-stat-card strong {
  color: #f8fafc;
}

.fusion-stat-card small {
  color: #94a3b8;
  font-size: 10px;
}

.fusion-max-uses {
  max-width: 220px;
  margin-top: 12px;
}

@media (max-width: 900px) {
  .recipe-grid,
  .fusion-stat-grid {
    grid-template-columns: 1fr;
  }

  .recipe-subsection-head {
    flex-direction: column;
  }
}


/* =========================================================
   REGISTER CARD UX V2 — BENTO / AUTO CODE / CUSTOM ELEMENT
   ========================================================= */

.register-container {
  max-width: 1520px;
  margin: 0 auto;
  padding: 24px;
  background:
    radial-gradient(circle at 12% 0%, rgba(14, 165, 233, 0.08), transparent 34%),
    radial-gradient(circle at 88% 8%, rgba(139, 92, 246, 0.08), transparent 30%),
    #08111f;
}

.header-section {
  padding: 8px 2px 2px;
}

.header-section h2 {
  font-size: clamp(24px, 3vw, 34px);
  letter-spacing: -0.035em;
}

.card-mode-panel,
.panel-card {
  border-color: rgba(148, 163, 184, 0.14);
  box-shadow: 0 20px 60px rgba(2, 6, 23, 0.28);
}

.card-mode-panel {
  background:
    linear-gradient(135deg, rgba(15, 23, 42, 0.96), rgba(15, 23, 42, 0.76));
}

.card-mode-option {
  min-height: 116px;
  border-radius: 16px;
  transition:
    transform 0.18s ease,
    border-color 0.18s ease,
    background 0.18s ease;
}

.card-mode-option:hover {
  transform: translateY(-2px);
}

.card-mode-option.active {
  box-shadow: inset 0 0 0 1px rgba(56, 189, 248, 0.16);
}

.form-grid-layout {
  grid-template-columns: minmax(0, 1fr) 350px;
  gap: 20px;
  align-items: start;
}

.form-panel {
  padding: 18px;
  background: rgba(8, 17, 31, 0.58);
}

.bento-form {
  display: flex;
  flex-direction: column;
  gap: 18px;
}

.register-bento-grid {
  display: grid;
  grid-template-columns: repeat(12, minmax(0, 1fr));
  gap: 14px;
}

.bento-card {
  position: relative;
  overflow: hidden;
  padding: 18px;
  border: 1px solid rgba(148, 163, 184, 0.14);
  border-radius: 18px;
  background:
    linear-gradient(145deg, rgba(15, 23, 42, 0.95), rgba(15, 23, 42, 0.72));
  box-shadow:
    inset 0 1px 0 rgba(255, 255, 255, 0.025),
    0 16px 36px rgba(2, 6, 23, 0.2);
}

.bento-card::after {
  content: "";
  position: absolute;
  inset: auto -70px -90px auto;
  width: 170px;
  height: 170px;
  border-radius: 50%;
  pointer-events: none;
  background: rgba(56, 189, 248, 0.035);
  filter: blur(1px);
}

.bento-source {
  grid-column: span 5;
}

.bento-identity-card {
  grid-column: span 7;
}

.bento-element-card {
  grid-column: span 5;
}

.bento-stats-card {
  grid-column: span 7;
}

.bento-media-card {
  grid-column: span 12;
}

.bento-card-head {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 12px;
  margin-bottom: 16px;
}

.bento-card-head h3 {
  margin: 3px 0 0;
  color: #f8fafc;
  font-size: 16px;
  letter-spacing: -0.02em;
}

.status-dot {
  width: 10px;
  height: 10px;
  margin-top: 7px;
  border-radius: 999px;
  box-shadow: 0 0 0 5px rgba(100, 116, 139, 0.09);
}

.status-dot.ready {
  background: #22c55e;
  box-shadow: 0 0 0 5px rgba(34, 197, 94, 0.1);
}

.status-dot.waiting {
  background: #f59e0b;
  box-shadow: 0 0 0 5px rgba(245, 158, 11, 0.1);
}

.status-pill {
  display: inline-flex;
  align-items: center;
  min-height: 24px;
  padding: 4px 8px;
  border: 1px solid rgba(148, 163, 184, 0.14);
  border-radius: 999px;
  background: rgba(51, 65, 85, 0.26);
  color: #94a3b8;
  font-size: 9px;
  font-weight: 900;
  letter-spacing: 0.08em;
  white-space: nowrap;
}

.status-pill.success {
  border-color: rgba(34, 197, 94, 0.28);
  background: rgba(34, 197, 94, 0.1);
  color: #86efac;
}

.status-pill.info,
.status-pill.accent {
  border-color: rgba(56, 189, 248, 0.3);
  background: rgba(56, 189, 248, 0.1);
  color: #7dd3fc;
}

.status-pill.warning {
  border-color: rgba(245, 158, 11, 0.28);
  background: rgba(245, 158, 11, 0.09);
  color: #fcd34d;
}

.status-pill.muted {
  color: #94a3b8;
}

.rfid-display,
.virtual-source,
.element-hero,
.media-hint {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 13px;
  margin-bottom: 14px;
  border: 1px solid rgba(56, 189, 248, 0.12);
  border-radius: 14px;
  background: rgba(2, 6, 23, 0.26);
}

.rfid-display {
  justify-content: flex-start;
}

.rfid-display > div,
.virtual-source > div,
.element-hero > div {
  min-width: 0;
  display: flex;
  flex: 1;
  flex-direction: column;
  gap: 2px;
}

.rfid-display small,
.element-hero small {
  color: #64748b;
  font-size: 9px;
  font-weight: 800;
  letter-spacing: 0.12em;
  text-transform: uppercase;
}

.rfid-display strong,
.element-hero strong {
  overflow: hidden;
  color: #e2e8f0;
  font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
  font-size: 13px;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.rfid-icon,
.virtual-orb,
.element-symbol {
  display: grid;
  flex: 0 0 auto;
  width: 42px;
  height: 42px;
  place-items: center;
  border: 1px solid rgba(56, 189, 248, 0.18);
  border-radius: 13px;
  background: rgba(14, 165, 233, 0.08);
  font-size: 20px;
}

.virtual-source p,
.media-hint p {
  margin: 2px 0 0;
  color: #94a3b8;
  font-size: 11px;
  line-height: 1.45;
}

.compact-field {
  margin-bottom: 0;
}

.field-label-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 10px;
}

.auto-code-pill,
.auto-code-button {
  border: 1px solid rgba(56, 189, 248, 0.22);
  border-radius: 999px;
  background: rgba(14, 165, 233, 0.08);
  color: #7dd3fc;
  font-size: 9px;
  font-weight: 900;
  letter-spacing: 0.06em;
}

.auto-code-pill {
  padding: 4px 7px;
}

.auto-code-pill.locked {
  border-color: rgba(148, 163, 184, 0.16);
  background: rgba(51, 65, 85, 0.2);
  color: #94a3b8;
}

.auto-code-button {
  padding: 5px 8px;
  cursor: pointer;
}

.auto-code-button:hover {
  background: rgba(14, 165, 233, 0.16);
}

.auto-code-button.auto-on {
  border-color: rgba(34, 197, 94, 0.24);
  background: rgba(34, 197, 94, 0.08);
  color: #86efac;
}

.code-input-wrap {
  position: relative;
}

.code-input-wrap input {
  padding-right: 150px;
  font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
}

.code-input-wrap input[readonly] {
  border-color: rgba(56, 189, 248, 0.16);
  background: rgba(14, 165, 233, 0.045);
  color: #bae6fd;
}

.code-preview {
  position: absolute;
  top: 50%;
  right: 9px;
  max-width: 135px;
  overflow: hidden;
  transform: translateY(-50%);
  color: #475569;
  font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
  font-size: 8px;
  text-overflow: ellipsis;
  white-space: nowrap;
  pointer-events: none;
}

.tag-chip-row {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
}

.tag-chip {
  padding: 4px 7px;
  border: 1px solid rgba(168, 85, 247, 0.2);
  border-radius: 999px;
  background: rgba(168, 85, 247, 0.07);
  color: #d8b4fe;
  font-size: 9px;
  font-weight: 800;
}

.inline-element-add {
  display: grid;
  grid-template-columns: minmax(0, 1fr) auto;
  gap: 8px;
  margin-top: 2px;
  margin-bottom: 8px;
}

.btn-add-element {
  border: 1px solid rgba(56, 189, 248, 0.3);
  border-radius: 9px;
  padding: 0 14px;
  background: rgba(14, 165, 233, 0.1);
  color: #bae6fd;
  font-size: 11px;
  font-weight: 900;
  cursor: pointer;
}

.btn-add-element:hover {
  background: rgba(14, 165, 233, 0.18);
}

.stat-input-grid {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 10px;
}

.stat-input-card {
  display: flex;
  flex-direction: column;
  gap: 7px;
  min-width: 0;
  padding: 13px;
  border: 1px solid rgba(148, 163, 184, 0.13);
  border-radius: 13px;
  background: rgba(2, 6, 23, 0.24);
  text-transform: none;
  letter-spacing: 0;
}

.stat-input-card > span {
  font-size: 10px;
  font-weight: 900;
  letter-spacing: 0.08em;
}

.stat-input-card input {
  width: 100%;
  border: 0;
  border-bottom: 1px solid rgba(148, 163, 184, 0.16);
  border-radius: 0;
  padding: 5px 0;
  background: transparent;
  color: #f8fafc;
  font-size: 24px;
  font-weight: 900;
}

.stat-input-card small {
  color: #64748b;
  font-size: 9px;
  font-weight: 700;
}

.hp-stat > span {
  color: #4ade80;
}

.attack-stat > span {
  color: #fb7185;
}

.defense-stat > span {
  color: #60a5fa;
}

.bento-media-card {
  display: grid;
  grid-template-columns: 1fr 1fr;
  column-gap: 14px;
}

.bento-media-card .bento-card-head,
.bento-media-card .media-hint {
  grid-column: 1 / -1;
}

.media-hint {
  margin-bottom: 0;
  color: #94a3b8;
}

.preview-panel {
  position: sticky;
  top: 18px;
  border-radius: 18px;
  background:
    linear-gradient(145deg, rgba(15, 23, 42, 0.96), rgba(15, 23, 42, 0.82));
}

.preview-panel h3 {
  margin-top: 0;
}

.preview-card-box {
  box-shadow:
    0 26px 60px rgba(2, 6, 23, 0.45),
    inset 0 1px 0 rgba(255, 255, 255, 0.05);
}

.fusion-recipe-section,
.special-skill-section {
  border-radius: 18px;
}

.button-actions {
  position: sticky;
  bottom: 10px;
  z-index: 8;
  margin-top: 0;
  padding: 12px;
  border: 1px solid rgba(148, 163, 184, 0.14);
  border-radius: 15px;
  background: rgba(8, 17, 31, 0.92);
  box-shadow: 0 14px 44px rgba(2, 6, 23, 0.36);
  backdrop-filter: blur(14px);
}

.button-actions .btn-primary,
.button-actions .btn-secondary {
  min-height: 44px;
  border-radius: 10px;
}

@media (max-width: 1180px) {
  .form-grid-layout {
    grid-template-columns: 1fr;
  }

  .preview-panel {
    position: static;
  }

  .bento-source,
  .bento-identity-card,
  .bento-element-card,
  .bento-stats-card {
    grid-column: span 6;
  }
}

@media (max-width: 760px) {
  .register-container {
    padding: 14px;
  }

  .register-bento-grid {
    grid-template-columns: 1fr;
  }

  .bento-source,
  .bento-identity-card,
  .bento-element-card,
  .bento-stats-card,
  .bento-media-card {
    grid-column: 1;
  }

  .bento-media-card {
    grid-template-columns: 1fr;
  }

  .bento-media-card .bento-card-head,
  .bento-media-card .media-hint {
    grid-column: 1;
  }

  .stat-input-grid {
    grid-template-columns: 1fr;
  }

  .code-input-wrap input {
    padding-right: 14px;
  }

  .code-preview {
    display: none;
  }

  .button-actions {
    position: static;
    display: grid;
    grid-template-columns: 1fr 1fr;
  }
}



/* =========================================================
   PHASE 3C.1 • NECRO RESURRECTION PRESET
========================================================= */
.necro-skill-preset {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 14px;
  margin: 14px 0 18px;
  padding: 14px 16px;
  border: 1px solid rgba(118, 72, 176, 0.22);
  border-radius: 16px;
  background: linear-gradient(135deg, rgba(250, 247, 255, 0.98), rgba(240, 232, 252, 0.88));
  box-shadow: 0 12px 28px rgba(72, 46, 105, 0.08);
}

.necro-skill-preset > div {
  display: grid;
  gap: 4px;
}

.necro-skill-preset strong {
  color: #56347d;
  font-size: 12px;
  letter-spacing: 0.04em;
}

.necro-skill-preset small {
  max-width: 620px;
  color: #76668a;
  font-size: 11px;
  line-height: 1.5;
}

.btn-necro-preset {
  flex: 0 0 auto;
  padding: 10px 14px;
  border: 0;
  border-radius: 11px;
  color: #fff;
  background: linear-gradient(135deg, #5f3b86, #8b4fb4);
  font-weight: 900;
  cursor: pointer;
  box-shadow: 0 10px 20px rgba(89, 51, 125, 0.18);
}

.btn-necro-preset:disabled {
  cursor: not-allowed;
  opacity: 0.45;
}

@media (max-width: 720px) {
  .necro-skill-preset {
    align-items: stretch;
    flex-direction: column;
  }

  .btn-necro-preset {
    width: 100%;
  }
}


/* =========================================================
   PHASE 3D.19 • STATUS SKILL PRESETS
========================================================= */
.status-skill-presets {
  margin-top: 12px;
  padding: 14px;
  border: 1px solid rgba(88, 116, 146, 0.16);
  border-radius: 16px;
  background: rgba(246, 251, 255, 0.76);
}
.status-preset-heading { display:flex; flex-direction:column; gap:4px; margin-bottom:10px; }
.status-preset-heading strong { color:#23425a; font-size:12px; font-weight:950; }
.status-preset-heading small { color:#6d8395; font-size:10px; line-height:1.45; }
.status-preset-grid { display:grid; grid-template-columns:repeat(2,minmax(0,1fr)); gap:8px; }
.status-preset-card { min-height:62px; display:grid; grid-template-columns:34px minmax(0,1fr) auto; align-items:center; gap:9px; padding:9px 10px; border:1px solid rgba(76,126,160,.18); border-radius:13px; background:#fff; color:#26465f; text-align:left; cursor:pointer; }
.status-preset-card:hover:not(:disabled) { transform:translateY(-1px); border-color:rgba(46,150,214,.42); box-shadow:0 8px 18px rgba(55,105,140,.10); }
.status-preset-card > span { font-size:23px; }
.status-preset-card > div { min-width:0; display:flex; flex-direction:column; gap:3px; }
.status-preset-card strong { font-size:10px; font-weight:950; }
.status-preset-card small { color:#718798; font-size:8px; line-height:1.35; }
.status-preset-card > b { padding:4px 6px; border-radius:999px; background:#edf6fb; color:#2b83b7; font-size:7px; }
.status-preset-card:disabled { opacity:.45; cursor:not-allowed; }
@media(max-width:720px){.status-preset-grid{grid-template-columns:1fr}}

.card-image-upload input[type="file"] { width: 100%; padding: 10px; border: 1px dashed #a8d5ad; border-radius: 9px; background: #f5fbf4; color: #48664e; font-size: 10px; }
.card-image-upload input[type="file"]::file-selector-button { margin-right: 10px; border: 0; border-radius: 7px; padding: 8px 11px; background: #0caf25; color: #fff; font: 800 10px 'DM Sans',sans-serif; cursor: pointer; }
.card-image-upload input[type="file"]:disabled { opacity: .65; cursor: progress; }
.card-image-upload small { color: #527359; font-size: 9px; line-height: 1.5; }
.clear-card-image { align-self: flex-start; border: 1px solid #b9d9ba; border-radius: 7px; padding: 7px 9px; background: #f2faf1; color: #287a35; font-size: 9px; font-weight: 800; cursor: pointer; }
.clear-card-image:hover { background: #e4f5e4; }
.auxiliary-image-upload{gap:8px}
.auxiliary-image-upload>input[type="url"]{width:100%;border:1px solid #d8e8d8;border-radius:8px;padding:9px 10px;background:#fff;color:#284b30;font-size:10px}
.media-image-preview{display:block;max-width:100%;max-height:190px;object-fit:contain;align-self:flex-start;border:1px solid #d9e9d9;border-radius:9px;background:#f6faf5}
.physical-media-preview{width:min(170px,100%);aspect-ratio:2/3}
.avatar-media-preview{width:96px;height:96px;padding:6px}

.builtin-skill-toggle-list{display:grid;gap:9px;margin:12px 0 18px;padding:14px;border:1px solid #d8ead8;border-radius:13px;background:#f7fbf5}
.builtin-skill-toggle-list>header{display:flex;align-items:center;justify-content:space-between;gap:12px;margin-bottom:2px}
.builtin-skill-toggle-list>header>div,.builtin-skill-toggle-copy{display:grid;gap:4px;min-width:0}
.builtin-skill-toggle-list>header strong{color:#21472a;font-size:12px;font-weight:900}
.builtin-skill-toggle-list>header small,.builtin-skill-toggle-copy small{color:#718575;font-size:9px;line-height:1.5}
.builtin-skill-toggle-list>header>span{flex:none;border-radius:999px;padding:5px 8px;background:#e4f4e2;color:#287d36;font-size:8px;font-weight:900}
.builtin-skill-toggle-row{display:flex;align-items:center;justify-content:space-between;gap:16px;padding:10px 11px;border:1px solid #deebdd;border-radius:10px;background:#fff}
.builtin-skill-toggle-copy strong{color:#284b30;font-size:10px;font-weight:900}
.builtin-skill-toggle-copy em{color:#9a6a1b;font-size:8px;font-style:normal;line-height:1.4}
.skill-catalog-link{color:#267b34;font-size:8px;font-weight:900;text-decoration:none}
.skill-catalog-link:hover{text-decoration:underline}
.skill-toggle{position:relative;display:inline-flex;flex:none;align-items:center;cursor:pointer}
.skill-toggle input{position:absolute;width:1px;height:1px;opacity:0}
.skill-toggle>span{position:relative;width:39px;height:22px;border-radius:999px;background:#c8d5c8;transition:background .18s ease,box-shadow .18s ease}
.skill-toggle>span::after{position:absolute;top:3px;left:3px;width:16px;height:16px;border-radius:50%;background:white;box-shadow:0 1px 4px #173b2230;content:"";transition:transform .18s ease}
.skill-toggle input:checked+span{background:#16a52b}
.skill-toggle input:checked+span::after{transform:translateX(17px)}
.skill-toggle input:focus-visible+span{outline:3px solid #a3ddb0;outline-offset:2px}
.skill-toggle.disabled{cursor:not-allowed;opacity:.55}
@media(max-width:620px){.builtin-skill-toggle-list{padding:10px}.builtin-skill-toggle-row{align-items:flex-start;padding:9px}.builtin-skill-toggle-list>header{align-items:flex-start}}

/* Timedoor Card Studio: fixed tool rail, editable properties, live card canvas, and advanced rules. */
.register-container.ide-builder-page {
  --studio-green: #0ca52c;
  --studio-green-dark: #087b27;
  --studio-ink: #173c25;
  --studio-muted: #718675;
  --studio-border: #dcebdd;
  --studio-canvas: #f1f8f1;
  width: 100%;
  max-width: none;
  height: calc(100dvh - 76px);
  min-height: calc(100dvh - 76px);
  display: flex;
  flex-direction: column;
  margin: 0;
  padding: 0;
  overflow: visible;
  border: 1px solid var(--studio-border);
  border-radius: 16px;
  color: var(--studio-ink);
  background: var(--studio-canvas);
  font-family: Inter, ui-sans-serif, system-ui, sans-serif;
}
.ide-builder-page .ide-toolbar {
  position: sticky;
  top: 0;
  z-index: 35;
  display: grid;
  grid-template-columns: minmax(220px, 1fr) auto minmax(250px, 1fr);
  align-items: center;
  gap: 18px;
  min-height: 76px;
  flex: 0 0 76px;
  padding: 10px 18px;
  border-bottom: 1px solid var(--studio-border);
  background: rgba(255,255,255,.97);
  box-shadow: 0 5px 18px rgba(20,70,35,.06);
  backdrop-filter: blur(14px);
}
.ide-builder-page .toolbar-left { display:flex; align-items:center; gap:11px; min-width:0; }
.ide-builder-page .toolbar-logo { width:38px; height:38px; flex:0 0 38px; border-radius:4px 14px 4px 14px; border:1px solid #ffffffaa; background:transparent; color:#fff; font-family:"Space Grotesk",sans-serif; font-size:20px; font-weight:700; }
.ide-builder-page .toolbar-logo.brand-mark { border-color:rgba(12,165,44,.55)!important; color:#0ca52c!important; background:#eff8ef!important; }
.ide-builder-page .toolbar-heading { display:grid; min-width:0; gap:1px; }
.ide-builder-page .toolbar-kicker { color:var(--studio-green-dark); font-size:8px; font-weight:950; letter-spacing:.16em; }
.ide-builder-page .toolbar-title { margin:0; color:var(--studio-ink); font-size:16px; font-weight:900; line-height:1.2; }
.ide-builder-page .toolbar-subtitle { max-width:230px; overflow:hidden; color:var(--studio-muted); font:10px ui-monospace,SFMono-Regular,Menlo,monospace; text-overflow:ellipsis; white-space:nowrap; }
.ide-builder-page .toolbar-center { justify-self:center; }
.ide-builder-page .ide-segmented-control { display:grid; grid-template-columns:repeat(3,minmax(0,1fr)); gap:4px; min-width:min(390px,100%); padding:5px; border:1px solid rgba(198,222,198,.8); border-radius:15px; background:rgba(239,248,238,.62); box-shadow:inset 0 1px 2px rgba(37,87,43,.05),0 7px 22px rgba(40,93,45,.08); backdrop-filter:blur(14px); }
.ide-builder-page .ide-segmented-control label { display:flex; align-items:center; justify-content:center; gap:7px; min-width:0; padding:9px 12px; border:1px solid transparent; border-radius:11px; color:#66806a; font-size:11px; font-weight:800; white-space:nowrap; transition:background .18s ease,border-color .18s ease,box-shadow .18s ease,color .18s ease; }
.ide-builder-page .ide-segmented-control label.active { border-color:rgba(255,255,255,.82); color:var(--studio-green-dark); background:rgba(255,255,255,.88); box-shadow:0 3px 11px rgba(25,90,39,.12); backdrop-filter:blur(14px); }
.ide-builder-page .ide-segmented-control label.fusion.active { color:#7044a0; }
.ide-builder-page .toolbar-right { display:flex; justify-content:flex-end; gap:8px; }
.ide-builder-page .ide-btn { min-height:38px; border-radius:9px; font-size:11px; }
.ide-builder-page .ide-btn.primary { background:var(--studio-green); }
.ide-builder-page .ide-btn.primary:hover:not(:disabled) { background:var(--studio-green-dark); }
.ide-builder-page .ide-btn.outline { border-color:#d4e5d4; color:#47634b; }
.ide-builder-page .ide-btn.outline:hover { background:#eff8ef; }
.ide-spinner { width:13px; height:13px; border:2px solid rgba(255,255,255,.45); border-top-color:#fff; border-radius:50%; animation:studio-spin .7s linear infinite; }
@keyframes studio-spin { to { transform:rotate(360deg); } }
.ide-builder-page > .alert { position:relative; z-index:2; margin:10px 14px 0; padding:10px 13px; border-radius:10px; }
.ide-builder-page > .alert.error { color:#9b2c2c; border-color:#f1baba; background:#fff1f0; }
.ide-builder-page > .alert.success { color:#247438; border-color:#bde2c3; background:#effaf0; }
.form-grid-layout.ide-main-grid {
  display:grid;
  grid-template-columns:minmax(285px, 330px) minmax(330px, 1fr) minmax(330px, 390px);
  grid-template-rows:minmax(0,1fr);
  gap:0;
  align-items:stretch;
  flex:1 1 auto;
  height:auto;
  min-height:0;
  max-height:none;
  margin:0;
  overflow:hidden;
  border-radius:0 0 15px 15px;
}
.ide-main-grid > .panel-card,
.ide-main-grid > .panel-card > .bento-form { display:contents; }
.ide-main-grid .register-bento-grid {
  grid-column:1;
  grid-row:1;
  display:flex;
  flex-direction:column;
  gap:0;
  min-width:0;
  min-height:0;
  height:100%;
  padding:10px;
  overflow:auto;
  border-right:1px solid var(--studio-border);
  background:#fff;
  overscroll-behavior:contain;
}
.ide-main-grid .bento-card {
  flex:none;
  width:100%;
  padding:15px;
  overflow:visible;
  border:0;
  border-bottom:1px solid #e8f0e7;
  border-radius:0;
  background:#fff;
  box-shadow:none;
}
.ide-main-grid .bento-card::after { display:none; }
.ide-main-grid .bento-card-head { margin-bottom:12px; }
.ide-main-grid .bento-card-head h3 { color:var(--studio-ink); font-size:14px; }
.ide-main-grid .section-eyebrow { color:#4b9c58; }
.ide-main-grid .bento-card label { color:#38563d; }
.ide-main-grid .bento-card input:not([type="checkbox"]):not([type="radio"]),
.ide-main-grid .bento-card textarea,
.ide-main-grid .bento-card select,
.ide-main-grid .inline-element-add input {
  min-width:0;
  border:1px solid #d7e7d6;
  border-radius:8px;
  background:#fbfdfb;
  color:#23492c;
  box-shadow:none;
}
.ide-main-grid .input-group,
.ide-main-grid .code-input-wrap { width:100%; min-width:0; }
.ide-main-grid .input-group > input:not([type="checkbox"]):not([type="radio"]),
.ide-main-grid .input-group > select,
.ide-main-grid .input-group > textarea,
.ide-main-grid .code-input-wrap > input { display:block; width:100%; max-width:100%; min-width:0; box-sizing:border-box; }
.ide-main-grid .bento-card input:focus,
.ide-main-grid .bento-card textarea:focus,
.ide-main-grid .inline-element-add input:focus { border-color:#55b765; outline:3px solid rgba(29,161,53,.12); }
.ide-main-grid .rfid-display,
.ide-main-grid .virtual-source,
.ide-main-grid .element-hero { border-color:#dcebdd; background:#f5faf4; }
.ide-main-grid .rfid-display strong,
.ide-main-grid .element-hero strong { color:#22492c; }
.ide-main-grid .rfid-display small,
.ide-main-grid .element-hero small { color:#78907a; }
.ide-main-grid .auto-code-button,
.ide-main-grid .auto-code-pill { border-color:#cce5cd; background:#eff9ee; color:#378246; }
.ide-main-grid .auto-code-pill.locked { border-color:#dce6dc; background:#f4f7f3; color:#728374; }
.ide-main-grid .code-input-wrap input[readonly] { border-color:#d7e7d6; background:#f5faf4; color:#6c806f; }
.ide-main-grid .code-preview { color:#628269; }
.ide-main-grid .code-input-wrap input { padding-right:112px; }
.ide-main-grid .code-preview { right:10px; max-width:min(98px,34%); font-size:7px; }
.ide-main-grid .tag-chip { border-color:#cce8ce; background:#f0faf0; color:#398448; }
.ide-main-grid .stat-input-card { border-color:#e0ebdf; background:#f7fbf6; }
.ide-main-grid .stat-input-card input { background:transparent; color:#1e492a; }
.ide-main-grid .stat-input-card small { color:#708774; }
.ide-main-grid .status-pill { border-color:#dce8db; background:#f3f7f1; color:#718375; }
.ide-main-grid .status-pill.success { border-color:#bce3c0; background:#eff9ef; color:#368449; }
.ide-main-grid .status-pill.info,
.ide-main-grid .status-pill.accent { border-color:#c9e3d0; background:#edf8ef; color:#287c3b; }
.ide-main-grid .status-pill.warning { border-color:#f0deaf; background:#fff9e9; color:#987326; }
.ide-main-grid .help-text,
.ide-main-grid .virtual-source p { color:#758a78; }
.ide-main-grid .btn-add-element { border-color:#bdddbe; background:#eff8ef; color:#2e7c3b; }
.ide-main-grid .bento-media-card { display:flex; flex-direction:column; }
.ide-main-grid .media-hint { border-color:#dcebdd; background:#f6faf5; color:#66806a; }
.ide-main-grid .media-hint p { color:#718675; }
.ide-main-grid .ide-advanced-column {
  grid-column:3;
  grid-row:1;
  display:flex;
  flex-direction:column;
  gap:12px;
  min-width:0;
  min-height:0;
  height:100%;
  padding:12px;
  overflow:auto;
  border-left:1px solid var(--studio-border);
  background:#fbfdfb;
  overscroll-behavior:contain;
}
.ide-main-grid .fusion-recipe-section,
.ide-main-grid .special-skill-section {
  flex:none;
  min-width:0;
  padding:16px;
  border:1px solid #dcebdd;
  border-radius:13px;
  background:#fff;
  box-shadow:0 5px 16px rgba(22,76,34,.035);
}
.ide-main-grid .fusion-recipe-section h3,
.ide-main-grid .special-skill-section h3,
.ide-main-grid .fusion-recipe-section h4,
.ide-main-grid .special-skill-section h4 { color:#21482b; }
.ide-main-grid .fusion-recipe-section p,
.ide-main-grid .special-skill-section p { color:#718675; }
.ide-main-grid .fusion-material-card,
.ide-main-grid .fusion-stat-card { border-color:#dcebdd; background:#f7fbf6; }
.ide-main-grid .fusion-material-title,
.ide-main-grid .fusion-stat-card strong { color:#274c30; }
.ide-main-grid .material-remove-btn { border-color:#efcccc; background:#fff5f3; color:#a34c45; }
.ide-main-grid .zone-option { border-color:#dcebdd; background:#f5faf4; color:#4c6851; }
.ide-main-grid .zone-option.necro-zone { border-color:#e1d8ef; background:#f7f3fc; color:#725492; }
.ide-main-grid .fusion-fixed-rules { color:#59745e; }
.ide-main-grid .necro-skill-preset { align-items:stretch; flex-direction:column; gap:10px; padding:14px; border:1px solid rgba(164,128,199,.34); border-radius:15px; background:rgba(250,247,255,.72); box-shadow:0 8px 20px rgba(72,46,105,.07); backdrop-filter:blur(12px); }
.ide-main-grid .necro-skill-preset > div { width:100%; }
.ide-main-grid .necro-skill-preset strong { color:#56347d; line-height:1.35; }
.ide-main-grid .necro-skill-preset small { max-width:none; color:#76668a; }
.ide-main-grid .btn-necro-preset { width:100%; align-self:stretch; border:1px solid rgba(87,54,128,.18); border-radius:10px; }
.ide-main-grid .preview-panel {
  grid-column:2;
  grid-row:1;
  position:relative;
  top:auto;
  display:flex;
  flex-direction:column;
  align-items:center;
  justify-content:center;
  min-width:0;
  min-height:0;
  height:100%;
  padding:26px;
  overflow:hidden;
  border:0;
  border-radius:0;
  background-color:#f1f8f1;
  background-image:radial-gradient(#cfe2cf 1px, transparent 1px);
  background-size:22px 22px;
  box-shadow:none;
}
.ide-main-grid .preview-panel::before { content:"LIVE CARD PREVIEW"; position:absolute; top:17px; left:18px; color:#4b9c58; font-size:9px; font-weight:950; letter-spacing:.16em; }
.ide-main-grid .preview-panel h3 { position:absolute; top:34px; left:18px; margin:0; color:#1d4729; font-size:16px; text-align:left; }
.ide-main-grid .preview-desc { position:absolute; top:58px; left:18px; margin:0; color:#758a78; font-size:10px; text-align:left; }
.ide-main-grid .preview-card-box {
  width:min(320px, 84%);
  height:auto;
  min-height:440px;
  aspect-ratio: .72;
  padding:16px;
  border-radius:19px;
  box-shadow:0 28px 55px rgba(24,71,35,.18), 0 5px 14px rgba(24,71,35,.1);
}
.ide-main-grid .preview-header .p-name { max-width:70%; overflow:hidden; text-overflow:ellipsis; white-space:nowrap; }
.ide-main-grid .preview-artbox { flex:1; min-height:0; }
.ide-main-grid .preview-img-asset { width:100%; height:100%; object-fit:cover; }
.ide-main-grid .preview-identity-tags,
.ide-main-grid .preview-uid-tag { color:#617864; }
.ide-main-grid .alert { grid-column:1/-1; }

@media (max-width: 1320px) {
  .form-grid-layout.ide-main-grid { grid-template-columns:minmax(280px, 330px) minmax(320px,1fr); }
  .ide-main-grid .ide-advanced-column { grid-column:1/-1; grid-row:2; display:grid; grid-template-columns:repeat(2,minmax(0,1fr)); height:auto; max-height:520px; border-top:1px solid var(--studio-border); border-left:0; }
  .ide-main-grid .preview-panel { grid-column:2; grid-row:1; }
  .ide-main-grid .register-bento-grid { grid-column:1; grid-row:1; }
}
@media (max-width: 820px) {
  .register-container.ide-builder-page { height:auto; min-height:calc(100dvh - 76px); }
  .ide-builder-page .ide-toolbar { position:relative; grid-template-columns:1fr; gap:10px; }
  .ide-builder-page .toolbar-center { justify-self:stretch; overflow-x:auto; }
  .ide-builder-page .ide-segmented-control { width:max-content; max-width:100%; }
  .ide-builder-page .toolbar-right { justify-content:stretch; }
  .ide-builder-page .toolbar-right .ide-btn { flex:1; }
  .form-grid-layout.ide-main-grid { display:flex; flex-direction:column; height:auto; max-height:none; min-height:0; overflow:visible; }
  .ide-main-grid > .panel-card,
  .ide-main-grid > .panel-card > .bento-form { display:contents; }
  .ide-main-grid .register-bento-grid { order:1; height:auto; max-height:none; overflow:visible; border-right:0; }
  .ide-main-grid .preview-panel { order:2; min-height:590px; height:auto; }
  .ide-main-grid .ide-advanced-column { order:3; display:flex; height:auto; max-height:none; overflow:visible; border-top:1px solid var(--studio-border); }
  .ide-main-grid .preview-card-box { width:min(320px,90%); min-height:430px; }
  .ide-main-grid .bento-card { padding:14px 10px; }
}
@media (prefers-reduced-motion: reduce) {
  .ide-spinner { animation:none; }
  .ide-builder-page *, .ide-builder-page *::before, .ide-builder-page *::after { scroll-behavior:auto !important; transition-duration:.01ms !important; }
}

.registration-skill-heading{display:flex;align-items:center;gap:10px;min-width:0}
.registration-skill-art{display:grid;place-items:center;flex:none;width:48px;height:48px;overflow:hidden;border:1px solid #cfe0d0;border-radius:12px;background:#edf7ed;font-size:25px}
.registration-skill-heading>strong{min-width:0;overflow-wrap:anywhere}
.ide-main-grid .builtin-skill-toggle-copy{flex:1;min-width:0}
.ide-main-grid .builtin-skill-toggle-copy small{font-size:11px;line-height:1.6;overflow-wrap:anywhere}
.ide-main-grid .builtin-skill-toggle-copy strong{font-size:13px;line-height:1.4}
.ide-main-grid .builtin-skill-toggle-list>header>div{min-width:0}
.ide-main-grid .builtin-skill-toggle-list>header small{white-space:normal;line-height:1.5}
.ide-main-grid .skill-summary-head>div:last-child{min-width:0;flex:1;overflow-wrap:anywhere}
.ide-main-grid .skill-summary-icon{width:56px;height:56px;flex:none;overflow:hidden;border-radius:12px;background:#edf7ed}
.ide-main-grid .skill-summary-head strong{font-size:16px;line-height:1.3}
.ide-main-grid .skill-summary-card>p{font-size:12px;line-height:1.65;overflow-wrap:anywhere}
.registration-skill-source{display:grid;gap:6px;color:#52725a;font-size:10px;font-weight:700}
.ide-main-grid .registration-skill-source>input{box-sizing:border-box;width:100%;min-width:0;padding:9px;border:1px solid #d8e8d8;border-radius:7px;background:#f8fbf6;color:#637d69;font:10px/1.5 ui-monospace,monospace;text-overflow:ellipsis}
.registration-skill-media{display:flex;align-items:center;gap:12px;min-width:0;margin:12px 0;padding:12px;border:1px solid #d8e8d8;border-radius:12px;background:#f7fbf5}
.ide-main-grid .registration-skill-media .input-group{flex:1;min-width:0;margin:0}
.ide-main-grid .registration-skill-media input{width:100%;min-width:0;box-sizing:border-box}
.ide-main-grid a.btn-edit-skill{display:block;box-sizing:border-box;white-space:normal;text-decoration:none;text-align:center;background:#edf7ed;border-color:#c7dfc9;color:#21693c;line-height:1.5}
.ide-main-grid a.btn-edit-skill:hover{background:#dfeede;color:#164d2a}
</style>
