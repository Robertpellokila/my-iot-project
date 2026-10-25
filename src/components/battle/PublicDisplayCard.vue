<script setup>
import { computed, ref, watch } from "vue";
import { publicCardStats } from '../../utils/publicCardStats.js';

const props = defineProps({
  card: { type: Object, default: null },
  compact: { type: Boolean, default: false },
  statuses: { type: Array, default: () => [] },
});

const name = computed(() => props.card?.name ?? props.card?.card_name ?? "Waiting for a card");
const element = computed(() => {
  const value = String(props.card?.element ?? props.card?.type ?? "neutral").toLowerCase().trim();
  return {
    grass: "forest", nature: "forest", ice: "water", electric: "thunder",
    lightning: "thunder", wind: "thunder", holy: "light", warrior: "knight",
    shadow: "dark", necro: "dark",
  }[value] ?? value;
});
const numericValue = (value, fallback = 0) => {
  const number = Number(value);
  return Number.isFinite(number) ? Math.max(0, number) : fallback;
};
const currentHp = computed(() => numericValue(props.card?.current_hp ?? props.card?.currentHp ?? props.card?.hp));
const maxHp = computed(() => Math.max(1, numericValue(props.card?.base_hp ?? props.card?.baseHp ?? props.card?.max_hp ?? props.card?.hp, currentHp.value)));
const hpPercent = computed(() => Math.min(100, currentHp.value / maxHp.value * 100));
const hasHp = computed(() => [props.card?.current_hp, props.card?.currentHp, props.card?.hp].some((value) => value != null));
const stats = computed(() => publicCardStats(props.card));
const description = computed(() => props.card
  ? `${name.value}. ${element.value}. HP ${currentHp.value}/${maxHp.value}. ATK ${stats.value.attack ?? '—'}. DEF ${stats.value.defense ?? '—'}.`
  : "Waiting for a card");

// The catalog's physical image is the complete printed card; image_url is its illustration.
const isImageUrl = (value) => /^(https?:\/\/|\/|\.\.?\/|data:image\/|blob:)/i.test(String(value ?? "").trim());
const imageSources = computed(() => [
  { url: props.card?.physical_card_image_url, complete: true },
  { url: props.card?.image_url ?? props.card?.imageUrl ?? props.card?.image, complete: false },
  { url: props.card?.avatar_url, complete: false },
].filter((source) => isImageUrl(source.url)));
const imageIndex = ref(0);
watch(imageSources, () => { imageIndex.value = 0; });
const imageSource = computed(() => imageSources.value[imageIndex.value]);
const fallbackGlyph = computed(() => {
  const image = props.card?.image_url;
  return typeof image === "string" && !isImageUrl(image) && image.length < 8 ? image : "✦";
});

const elementPaths = computed(() => ({
  fire: ["M18 2c1 8-7 9-5 15 2-1 3-3 4-5 0 5 8 6 7 12-1 5-5 7-9 6C5 29 4 20 9 14c0 4 2 5 3 5C10 12 18 10 18 2Z"],
  water: ["M16 2C14 9 5 14 5 21a11 11 0 0 0 22 0C27 14 18 9 16 2Z", "M11 19c-3 5 1 8 5 8"],
  forest: ["M27 4C8 2 2 12 8 22c9 10 21 2 19-18Z", "M6 29 23 10M12 23l-1-8M16 19l8-1"],
  thunder: ["m19 2-14 17h10l-2 12 14-19H17Z"],
  light: ["m16 2 4 10 10 4-10 4-4 10-4-10-10-4 10-4Z"],
  dark: ["M23 3A14 14 0 1 0 29 23 12 12 0 0 1 23 3Z"],
  knight: ["m16 3 11 4v10c0 6-7 11-11 13C12 28 5 23 5 17V7Z", "M16 8v16M10 14h12"],
  neutral: ["m16 3 12 13-12 13L4 16Z", "m16 10 5 6-5 6-5-6Z"],
}[element.value] ?? ["m16 3 12 13-12 13L4 16Z"]));
</script>

<template>
  <article
    class="tbc-card"
    :class="[
      `tbc-card-${element}`,
      { 'tbc-card-compact': compact, 'tbc-card-empty': !card, 'tbc-card-printed': imageSource?.complete, 'tbc-card-fallen': card?.zone === 'graveyard' },
    ]"
    :aria-label="description"
    :title="description"
  >
    <div class="tbc-card-illustration">
      <img
        v-if="imageSource"
        class="tbc-card-image"
        :src="imageSource.url"
        :alt="name"
        draggable="false"
        @error="imageIndex += 1"
      />
      <div v-else class="tbc-card-placeholder" aria-hidden="true">{{ fallbackGlyph }}</div>
    </div>

    <template v-if="!imageSource?.complete">
      <div class="tbc-card-shading" aria-hidden="true"></div>
      <div class="tbc-card-inner-frame" aria-hidden="true"></div>
      <span v-for="corner in ['tl', 'tr', 'bl', 'br']" :key="corner" class="tbc-card-corner" :class="`tbc-card-corner-${corner}`" aria-hidden="true">❧</span>
      <header class="tbc-card-heading">
        <span class="tbc-card-top-emblem" aria-hidden="true">
          <svg viewBox="0 0 32 32"><path v-for="(path, index) in elementPaths" :key="index" :d="path" /></svg>
        </span>
        <strong class="tbc-card-name">{{ name }}</strong>
      </header>
      <span class="tbc-card-element" :title="element" aria-hidden="true">
        <svg viewBox="0 0 32 32"><path v-for="(path, index) in elementPaths" :key="index" :d="path" /></svg>
      </span>
    </template>

    <div v-if="card && !compact" class="tbc-card-vitality">
      <div class="tbc-card-type-label">{{ element }}</div>
      <template v-if="hasHp">
        <div class="tbc-card-hp-label"><span>HP</span><strong>{{ currentHp }}<small>/{{ maxHp }}</small></strong></div>
        <div class="tbc-card-hp-track" aria-hidden="true"><span :style="{ width: `${hpPercent}%` }"></span></div>
      </template>
      <dl class="tbc-card-combat-stats">
        <div class="stat-atk"><dt>ATK</dt><dd>{{ stats.attack ?? '—' }}</dd></div>
        <div class="stat-def"><dt>DEF</dt><dd>{{ stats.defense ?? '—' }}</dd></div>
      </dl>
      <div v-if="statuses.length" class="tbc-card-status-labels"><span v-for="status in statuses.slice(0, 2)" :key="status.key" :title="`${status.label} ${status.valueText || ''}`">{{ status.label }} {{ status.valueText }}</span><span v-if="statuses.length > 2">+{{ statuses.length - 2 }}</span></div>
    </div>
    <span v-if="card?.zone === 'graveyard'" class="tbc-card-defeated">KO</span>
  </article>
</template>

<style scoped>
.tbc-card {
  --tbc-card-accent: #55dfff;
  --tbc-card-deep: #063ba3;
  --tbc-card-gold: #fff094;
  position: relative;
  isolation: isolate;
  container-type: inline-size;
  width: 100%;
  height: 100%;
  min-width: 0;
  min-height: 0;
  aspect-ratio: 0.7;
  overflow: hidden;
  border: 3px solid #f4d364;
  border-radius: 5% / 3.5%;
  color: #fff;
  background: #06122d;
  box-shadow: 0 0 0 2px #38230c, inset 0 0 0 3px #031c42, 0 0 8px #ffdf79, 0 0 23px color-mix(in srgb, var(--tbc-card-accent) 65%, transparent);
  font-family: "Arial Narrow", "Trebuchet MS", sans-serif;
}
.tbc-card-fire { --tbc-card-accent: #ffb331; --tbc-card-deep: #9d1907; }
.tbc-card-forest { --tbc-card-accent: #9ff17a; --tbc-card-deep: #125423; }
.tbc-card-thunder { --tbc-card-accent: #ffe460; --tbc-card-deep: #6255ab; }
.tbc-card-light { --tbc-card-accent: #fff3a6; --tbc-card-deep: #8a762d; }
.tbc-card-dark { --tbc-card-accent: #d5a1ff; --tbc-card-deep: #491776; }
.tbc-card-knight { --tbc-card-accent: #d6e9ff; --tbc-card-deep: #375173; }
.tbc-card-neutral { --tbc-card-accent: #e8e4d0; --tbc-card-deep: #3d4860; }
.tbc-card-illustration, .tbc-card-image, .tbc-card-shading, .tbc-card-placeholder {
  position: absolute;
  inset: 0;
  width: 100%;
  height: 100%;
}
.tbc-card-image { display: block; object-fit: cover; object-position: center; }
.tbc-card-placeholder {
  display: grid;
  place-items: center;
  font-size: 43cqw;
  color: var(--tbc-card-accent);
  background: radial-gradient(ellipse at 50% 45%, color-mix(in srgb, var(--tbc-card-accent) 40%, transparent), transparent 62%), linear-gradient(150deg, var(--tbc-card-deep), #020b20);
  text-shadow: 0 0 25px var(--tbc-card-accent);
}
.tbc-card-shading { background: linear-gradient(180deg, #02091c66, transparent 32%, transparent 60%, #02091ca6); pointer-events: none; }
.tbc-card-inner-frame {
  position: absolute;
  inset: 2.1%;
  border: 1.5px solid var(--tbc-card-gold);
  border-radius: 3%;
  box-shadow: inset 0 0 0 2px #07244a, 0 0 0 1px #624215;
  pointer-events: none;
}
.tbc-card-heading {
  position: absolute;
  inset: 3.7% 3.8% auto;
  display: flex;
  align-items: center;
  gap: 2%;
  min-height: 12%;
  padding: 1.5% 4% 2% 2%;
  border-bottom: 1px solid color-mix(in srgb, var(--tbc-card-accent) 70%, transparent);
  background: linear-gradient(90deg, #031533f5, color-mix(in srgb, var(--tbc-card-deep) 85%, #01040f) 65%, #031533dd);
  box-shadow: 0 3px 8px #01050f44;
}
.tbc-card-name {
  display: -webkit-box;
  -webkit-box-orient: vertical;
  -webkit-line-clamp: 2;
  overflow: hidden;
  flex: 1;
  text-align: center;
  font-size: 9.1cqw;
  line-height: 1.08;
  font-weight: 800;
  letter-spacing: -0.04em;
  text-shadow: 0 2px 2px #010613;
}
.tbc-card-top-emblem {
  flex: 0 0 15%;
  display: grid;
  place-items: center;
  align-self: flex-start;
  aspect-ratio: 1;
  color: var(--tbc-card-accent);
  border: 1px solid #ffec93;
  border-radius: 50%;
  background: #020c26;
  box-shadow: 0 0 0 1px #01030c, 0 0 5px var(--tbc-card-accent);
}
.tbc-card-top-emblem svg { width: 76%; height: 76%; }
.tbc-card-element {
  position: absolute;
  bottom: 4%;
  left: 5%;
  display: grid;
  place-items: center;
  width: 21%;
  aspect-ratio: 1;
  border: 2px solid var(--tbc-card-accent);
  border-radius: 50%;
  color: var(--tbc-card-accent);
  background: #011126ed;
  box-shadow: 0 0 0 2px #03182e, 0 0 0 3px var(--tbc-card-accent), 0 0 9px var(--tbc-card-deep);
}
.tbc-card-element svg { width: 75%; height: 75%; }
.tbc-card-top-emblem path, .tbc-card-element path { fill: currentColor; stroke: currentColor; stroke-width: 1; stroke-linecap: round; stroke-linejoin: round; }
.tbc-card-water path + path, .tbc-card-forest path + path, .tbc-card-knight path + path { fill: none; stroke: var(--tbc-card-deep); stroke-width: 2; }
.tbc-card-corner { position: absolute; z-index: 2; font-size: 12cqw; line-height: 1; color: #ffef9e; text-shadow: 0 1px #443003; pointer-events: none; }
.tbc-card-corner-tl { top: 0; left: 0; transform: rotate(130deg); }
.tbc-card-corner-tr { top: 0; right: 0; transform: rotate(220deg); }
.tbc-card-corner-bl { bottom: 0; left: 0; transform: rotate(40deg); }
.tbc-card-corner-br { bottom: 0; right: 0; transform: rotate(-50deg); }
.tbc-card-vitality {
  position: absolute;
  right: 5%;
  bottom: 4%;
  width: 90%;
  padding: 3% 4%;
  border: 1px solid #c8def1;
  border-radius: 5px;
  color: #142c45;
  background: #f0f8fff5;
  box-shadow: 0 2px 6px #0006;
}
.tbc-card-hp-label { display: flex; justify-content: space-between; align-items: baseline; gap: 4%; font-size: 5.7cqw; line-height: 1; }
.tbc-card-hp-label > span { font-size: 4.9cqw; color: #245941; font-weight: 800; }
.tbc-card-hp-label strong { font-size: 7cqw; }
.tbc-card-hp-label small { font-size: 4.7cqw; }
.tbc-card-hp-track { height: 2cqw; margin-top: 3%; overflow: hidden; border-radius: 4px; background: #c9d9df; }
.tbc-card-type-label { color:#34536b; font-size:4.2cqw; font-weight:800; letter-spacing:.09em; text-transform:uppercase; margin-bottom:3%; }
.tbc-card-combat-stats { display:grid; grid-template-columns:1fr 1fr; gap:4%; margin:4% 0 0; }
.tbc-card-combat-stats > div { display:flex; align-items:center; justify-content:space-between; gap:5%; padding:3% 7%; border-radius:3px; }
.tbc-card-combat-stats dt { font-size:5.2cqw; font-weight:900; }
.tbc-card-combat-stats dd { margin:0; font-size:9cqw; line-height:1; font-weight:900; font-variant-numeric:tabular-nums; }
.stat-atk { background:#ffe7db; color:#8a321b; }.stat-def { background:#dcefff; color:#124b79; }
.tbc-card-status-labels { display:flex; flex-wrap:wrap; gap:2%; margin-top:3%; color:#59421e; font-size:3.6cqw; font-weight:800; }
.tbc-card-status-labels span { background:#ffecba; border-radius:2px; padding:1% 2%; }
.tbc-card:not(.tbc-card-compact) .tbc-card-element { display:none; }
.tbc-card-hp-track > span { display: block; height: 100%; border-radius: inherit; background: linear-gradient(90deg, #25d655, #b7ff87); transition: width 400ms ease; }
.tbc-card-compact { border-width: 2px; box-shadow: 0 0 0 1px #33290d, 0 0 5px #f4d36455; }
.tbc-card-compact .tbc-card-name { font-size: 9.4cqw; }
.tbc-card-compact .tbc-card-heading { min-height: 13%; }
.tbc-card-compact .tbc-card-inner-frame { border-width: 1px; }
.tbc-card-compact .tbc-card-element { border-width: 1px; box-shadow: 0 0 0 1px #03182e, 0 0 0 2px var(--tbc-card-accent); }
.tbc-card-fallen .tbc-card-illustration { filter: grayscale(0.9) brightness(0.6); }
.tbc-card-defeated { position: absolute; inset: 35% 0 auto; text-align: center; color: #fff0db; font-size: 27cqw; font-weight: 900; text-shadow: 0 0 8px #ff4400; }
.tbc-card-empty { opacity: 0.42; }
@media (prefers-reduced-motion: reduce) { .tbc-card-hp-track > span { transition: none; } }
</style>
