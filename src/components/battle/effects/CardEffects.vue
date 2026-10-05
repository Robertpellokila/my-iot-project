<script setup>
import { computed } from "vue";
import { resolveCardEffectLayers } from "./effectRegistry.js";

/**
 * Shared VFX orchestrator for PlayerBattle + PublicActiveField.
 * Pass the exact card's ACTIVE status objects (with battle_cards.id matching
 * target_card_id). The server decides if/when an effect exists and expires.
 * No text overlays, no health calculations and no Supabase subscriptions here.
 */
const props = defineProps({
  statuses: { type: Array, default: () => [] },
  mode: { type: String, default: "player" }, // player | public
});

const layers = computed(() => resolveCardEffectLayers(props.statuses));
</script>

<template>
  <div class="card-effects" :class="`card-effects--${mode}`" aria-hidden="true">
    <component
      :is="effect.component"
      v-for="effect in layers"
      :key="effect.id"
      v-bind="effect.props"
      class="card-effects__layer"
      :style="{ zIndex: effect.layer }"
    />
  </div>
</template>

<style scoped>
/* The parent decides the card-sized rectangle. Never size to the entire slot.
 * Its existing .card-fx-stack / .public-card-fx-stack CSS positions this root. */
.card-effects {
  position: absolute;
  display: block;
  overflow: hidden;
  isolation: isolate;
  pointer-events: none;
  border-radius: inherit;
  contain: paint;
}
.card-effects__layer {
  position: absolute;
  inset: 0;
  display: block;
  pointer-events: none;
  border-radius: inherit;
}
@media (prefers-reduced-motion: reduce) {
  .card-effects__layer { animation-duration: 0.01ms !important; }
}
</style>
