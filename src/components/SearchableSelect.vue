<script setup>
import { computed, nextTick, onBeforeUnmount, onMounted, ref, useAttrs, useSlots, watch } from "vue";

defineOptions({ inheritAttrs: false });

const props = defineProps({
  modelValue: { default: "" },
  multiple: { type: Boolean, default: false },
  disabled: { type: Boolean, default: false },
  placeholder: { type: String, default: "Pilih opsi" },
  searchable: { type: Boolean, default: true },
  modelModifiers: { type: Object, default: () => ({}) },
});

const emit = defineEmits(["update:modelValue", "change"]);
const attrs = useAttrs();
const slots = useSlots();
const root = ref(null);
const trigger = ref(null);
const menu = ref(null);
const searchInput = ref(null);
const isOpen = ref(false);
const query = ref("");
const menuStyle = ref({});

function textFromChildren(children) {
  if (typeof children === "string" || typeof children === "number") return String(children);
  if (Array.isArray(children)) return children.map((child) => textFromChildren(typeof child === "object" ? child?.children : child)).join("");
  return "";
}

function collectOptions(nodes, result = []) {
  for (const node of nodes || []) {
    if (!node || typeof node !== "object") continue;
    if (node.type === "option") {
      const label = textFromChildren(node.children).trim();
      const value = node.props && Object.prototype.hasOwnProperty.call(node.props, "value")
        ? node.props.value
        : label;
      result.push({ value, label, disabled: Boolean(node.props?.disabled) });
    } else if (Array.isArray(node.children)) {
      collectOptions(node.children, result);
    }
  }
  return result;
}

// Keep the native <option> slot syntax at call sites so existing v-model values
// and dynamic option lists continue to work while the visible control is custom.
function readOptions() {
  return collectOptions(slots.default?.() || []);
}

const options = computed(() => readOptions());
const selectedValues = computed(() => props.multiple
  ? (Array.isArray(props.modelValue) ? props.modelValue : [])
  : [props.modelValue]);
const selectedOptions = computed(() => selectedValues.value
  .map((value) => options.value.find((option) => option.value === value || String(option.value) === String(value)))
  .filter(Boolean));
const displayText = computed(() => {
  if (props.multiple) {
    if (!selectedOptions.value.length) return "";
    if (selectedOptions.value.length <= 2) return selectedOptions.value.map((option) => option.label).join(", ");
    return `${selectedOptions.value.length} dipilih`;
  }
  return selectedOptions.value[0]?.label || "";
});
const filteredOptions = computed(() => {
  const needle = query.value.trim().toLocaleLowerCase("id");
  if (!needle) return options.value;
  return options.value.filter((option) => option.label.toLocaleLowerCase("id").includes(needle));
});

async function openMenu() {
  if (props.disabled) return;
  isOpen.value = !isOpen.value;
  query.value = "";
  if (isOpen.value && props.searchable) {
    await nextTick();
    updatePosition();
    searchInput.value?.focus();
  } else if (isOpen.value) {
    await nextTick();
    updatePosition();
  }
}

function closeMenu() {
  isOpen.value = false;
  query.value = "";
}

function choose(option) {
  if (option.disabled || props.disabled) return;
  let nextValue;
  if (props.multiple) {
    const current = Array.isArray(props.modelValue) ? [...props.modelValue] : [];
    const index = current.findIndex((value) => value === option.value || String(value) === String(option.value));
    if (index >= 0) current.splice(index, 1);
    else current.push(option.value);
    nextValue = current;
  } else {
    nextValue = option.value;
  }
  emit("update:modelValue", nextValue);
  emit("change", nextValue);
  if (!props.multiple) closeMenu();
}

function isSelected(option) {
  return selectedValues.value.some((value) => value === option.value || String(value) === String(option.value));
}

function handleOutsideClick(event) {
  const clickedTrigger = root.value?.contains(event.target);
  const clickedMenu = menu.value?.contains(event.target);
  if (!clickedTrigger && !clickedMenu) closeMenu();
}

function updatePosition() {
  if (!isOpen.value || !trigger.value) return;
  const rect = trigger.value.getBoundingClientRect();
  const viewportWidth = window.innerWidth;
  const viewportHeight = window.innerHeight;
  const width = Math.min(Math.max(rect.width, 230), viewportWidth - 16);
  const left = Math.max(8, Math.min(rect.left, viewportWidth - width - 8));
  const gap = 5;
  const spaceBelow = Math.max(0, viewportHeight - rect.bottom - gap - 8);
  const spaceAbove = Math.max(0, rect.top - gap - 8);
  const openAbove = spaceBelow < 250 && spaceAbove > spaceBelow;
  const availableSpace = openAbove ? spaceAbove : spaceBelow;
  const maxHeight = Math.max(120, Math.min(360, availableSpace));
  const top = openAbove
    ? Math.max(8, rect.top - gap - maxHeight)
    : Math.min(viewportHeight - maxHeight - 8, rect.bottom + gap);

  menuStyle.value = {
    top: `${top}px`,
    left: `${left}px`,
    width: `${width}px`,
    maxHeight: `${maxHeight}px`,
  };
}

function handleViewportChange() {
  updatePosition();
}

function handleKeydown(event) {
  if (event.key === "Escape") closeMenu();
  if (event.key === "Enter") {
    event.preventDefault();
    if (filteredOptions.value.length === 1) choose(filteredOptions.value[0]);
  }
}

const controlAttrs = computed(() => {
  const { class: _class, style: _style, ...rest } = attrs;
  return rest;
});

onMounted(() => document.addEventListener("pointerdown", handleOutsideClick));
watch(isOpen, async (open) => {
  if (!open) {
    window.removeEventListener("resize", handleViewportChange);
    window.removeEventListener("scroll", handleViewportChange, true);
    return;
  }
  await nextTick();
  updatePosition();
  window.addEventListener("resize", handleViewportChange);
  window.addEventListener("scroll", handleViewportChange, true);
});
onBeforeUnmount(() => {
  document.removeEventListener("pointerdown", handleOutsideClick);
  window.removeEventListener("resize", handleViewportChange);
  window.removeEventListener("scroll", handleViewportChange, true);
});
</script>

<template>
  <div
    ref="root"
    class="searchable-select"
    :class="[{ 'is-open': isOpen, 'is-disabled': disabled, 'is-multiple': multiple }, attrs.class]"
    :style="attrs.style"
  >
    <button
      ref="trigger"
      type="button"
      class="searchable-select__trigger"
      v-bind="controlAttrs"
      :disabled="disabled"
      role="combobox"
      :aria-expanded="isOpen"
      aria-haspopup="listbox"
      @click="openMenu"
    >
      <span class="searchable-select__value" :class="{ 'is-placeholder': !displayText }">
        {{ displayText || placeholder }}
      </span>
      <span class="searchable-select__chevron" aria-hidden="true">⌄</span>
    </button>

    <Teleport to="body">
      <div v-if="isOpen" ref="menu" class="searchable-select__menu" :style="menuStyle">
        <label v-if="searchable" class="searchable-select__search-wrap">
          <span aria-hidden="true">⌕</span>
          <input
            ref="searchInput"
            v-model="query"
            type="search"
            class="searchable-select__search"
            placeholder="Cari pilihan..."
            autocomplete="off"
            @keydown="handleKeydown"
          />
        </label>
        <div class="searchable-select__options" role="listbox" :aria-multiselectable="multiple">
          <button
            v-for="(option, index) in filteredOptions"
            :key="`${String(option.value)}-${index}`"
            type="button"
            class="searchable-select__option"
            :class="{ selected: isSelected(option), disabled: option.disabled }"
            :disabled="option.disabled"
            role="option"
            :aria-selected="isSelected(option)"
            @click="choose(option)"
          >
            <span class="searchable-select__check">{{ isSelected(option) ? "✓" : "" }}</span>
            <span>{{ option.label || "(tanpa label)" }}</span>
          </button>
          <p v-if="!filteredOptions.length" class="searchable-select__empty">Tidak ada pilihan yang cocok.</p>
        </div>
      </div>
    </Teleport>
  </div>
</template>

<style scoped>
.searchable-select{position:relative;display:block;min-width:0;width:100%;color:#21472b;font:inherit;color-scheme:light;z-index:1}
.searchable-select.is-open{z-index:40}
.searchable-select__trigger{display:flex;align-items:center;justify-content:space-between;gap:10px;width:100%;min-height:42px;padding:9px 12px;border:1px solid #d4e5d3;border-radius:9px;background:#fff;color:#24452a;text-align:left;font:inherit;font-size:inherit;cursor:pointer;transition:border-color .16s ease,box-shadow .16s ease,background .16s ease}
.searchable-select__trigger:hover:not(:disabled){border-color:#79bd7e;background:#fcfffb}
.searchable-select__trigger:focus-visible{outline:3px solid #0caf2533;border-color:#0caf25}
.searchable-select__trigger:disabled{background:#f1f5f0;color:#91a293;cursor:not-allowed}
.searchable-select__value{display:block;min-width:0;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
.searchable-select__value.is-placeholder{color:#829483}
.searchable-select__chevron{flex:none;color:#43894d;font-size:16px;line-height:1;transition:transform .16s ease}
.is-open .searchable-select__chevron{transform:rotate(180deg)}
.searchable-select__menu{position:fixed;z-index:2147483647;display:flex;flex-direction:column;min-width:230px;overflow:hidden;border:1px solid #d3e4d1;border-radius:11px;background:#fff;box-shadow:0 16px 40px #153d1c38;color:#25482b}
.searchable-select__search-wrap{display:flex;align-items:center;gap:8px;margin:8px;padding:0 10px;border:1px solid #dce9da;border-radius:8px;background:#f7fbf5;color:#55805b}
.searchable-select__search{width:100%;min-width:0;height:36px;padding:0;border:0!important;outline:0!important;background:transparent!important;color:#24452a!important;box-shadow:none!important;font:inherit;font-size:12px}
.searchable-select__search::placeholder{color:#8b9d8d}
.searchable-select__options{flex:1;min-height:0;overflow:auto;padding:3px 5px 6px;overscroll-behavior:contain}
.searchable-select__option{display:flex;align-items:center;gap:8px;width:100%;min-height:35px;padding:7px 8px;border:0;border-radius:7px;background:#fff;color:#35583a;text-align:left;font:inherit;font-size:12px;cursor:pointer}
.searchable-select__option:hover{background:#f0f8ee;color:#1d6e2c}
.searchable-select__option.selected{background:#e9f7e8;color:#167b2a;font-weight:800}
.searchable-select__option.disabled{opacity:.45;cursor:not-allowed}
.searchable-select__check{display:grid;place-items:center;flex:none;width:18px;height:18px;border:1px solid #d9e8d7;border-radius:5px;color:#0b9c27;font-size:11px}
.searchable-select__option.selected .searchable-select__check{border-color:#93d398;background:#fff}
.searchable-select__empty{margin:0;padding:13px 10px;color:#7b8d7d;font-size:11px;text-align:center}
.searchable-select.is-multiple .searchable-select__trigger{min-height:42px}
</style>
