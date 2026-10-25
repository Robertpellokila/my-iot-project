<script setup>

import {

computed,

ref,

watch,

} from "vue";

import BattlePileViewer from "./BattlePileViewer.vue";

// =========================================================

// PROPS

// =========================================================

const props = defineProps({

zone: {

type: String,

required: true,

validator: (value) =>

  [

"bench",

"graveyard",

  ].includes(value),

},

cards: {

type: Array,

default: () => [],

},

max: {

type: Number,

default: null,

},

side: {

type: String,

default: "left",

validator: (value) =>

  [

"left",

"right",

  ].includes(value),

},

readonly: {

type: Boolean,

default: false,

},

allowDrop: {

type: Boolean,

default: false,

},

draggableCards: {

type: Boolean,

default: false,

},

showBenchAction: {

type: Boolean,

default: false,

},

benchActionEnabled: {

type: Boolean,

default: false,

},

benchActionLabel: {

type: String,

default: "KEMBALI KE ACTIVE",

},

benchActionHint: {

type: String,

default: "",

},

accent: {

type: String,

default: "blue",

},

disabled: {

type: Boolean,

default: false,

},

// =======================================================

// CONTROLLED LIVE VIEW

//

// null = gunakan local state.

//

// true/false = dikontrol parent.

//

// PublicBattle memakai controlled state dari realtime.

// =======================================================

viewerOpen: {

type: Boolean,

default: null,

},

viewerIndex: {

type: Number,

default: null,

},

/*

  * PublicBattleArena:

  *

  * mirrorOnly = true

  *

  * Stack tidak bisa dibuka manual oleh spectator.

  * Viewer hanya membuka jika Player membuka.

  */

mirrorOnly: {

type: Boolean,

default: false,

},

});

// =========================================================

// EMITS

// =========================================================

const emit = defineEmits([

"drop-card",

"card-select",

"drag-start",

"drag-end",

"drag-hover",

"viewer-open",

"viewer-close",

"viewer-index-change",

"bench-action",

]);

// =========================================================

// LOCAL STATE

// =========================================================

const localViewerOpen =

ref(false);

const localViewerIndex =

ref(0);

const dragOver =

ref(false);

// =========================================================

// CONTROLLED STATE

// =========================================================

const effectiveViewerOpen =

computed(() => {

if (

props.viewerOpen ===

null

  ) {

return (

localViewerOpen.value

  );

}

return props.viewerOpen;

});

const effectiveViewerIndex =

computed(() => {

if (

props.viewerIndex ===

null

  ) {

return (

localViewerIndex.value

  );

}

return Math.max(

0,

Number(

props.viewerIndex ??

0,

  ),

  );

});

// =========================================================

// COMPUTED

// =========================================================

const count = computed(

  () =>

props.cards?.length ?? 0,

);

const title = computed(() =>

props.zone === "graveyard"

? "GRAVEYARD"

: "BENCH",

);

const subtitle = computed(() =>

props.zone === "graveyard"

? "Destroyed Cards"

: "Reserve Cards",

);

const symbol = computed(() =>

props.zone === "graveyard"

? "☠"

: "◉",

);

const countLabel = computed(

  () => {

if (

props.max === null ||

props.max === undefined

  ) {

return String(

count.value,

  );

}

return `${count.value} / ${props.max}`;

},

);

// =========================================================

// CARD HELPERS

// =========================================================

const getCardId = (

card,

) =>

card?.battleId ??

  card?.battle_id ??

  card?.id ??

  card?.uid ??

  null;

const isFieldFusionUsed = (card) =>
Boolean(
  card?.field_fusion_used ??
  card?.fieldFusionUsed ??
  false,
);

const isNecroConsumed = (card) =>
Boolean(
  card?.necro_consumed ??
  card?.necroConsumed ??
  false,
);

const isNecroReadyAfterFusion = (card) =>
Boolean(
  isFieldFusionUsed(card) &&
  !isNecroConsumed(card),
);

const visibleCards =

computed(() => {

/*

  * Preview pile maksimal 4.

  */

return props.cards.slice(

-4,

  );

});

// =========================================================

// PILE STACK STYLE

// =========================================================

const stackStyle = (

index,

) => {

const total =

visibleCards.value.length;

const reverse =

total - 1 - index;

const direction =

props.side === "left"

? 1

: -1;

const x =

reverse *

5 *

direction;

const y =

reverse * -5;

const rotate =

reverse *

2.3 *

direction;

const scale =

1 -

reverse *

0.025;

return {

transform: `

  translate(

${x}px,

${y}px

  )

  rotate(

${rotate}deg

  )

  scale(

${scale}

  )

`,

zIndex:

20 -

reverse,

opacity:

1 -

reverse *

0.08,

};

};

// =========================================================

// VIEWER OPEN

// =========================================================

const openViewer = () => {

if (

props.disabled ||

props.mirrorOnly

  ) {

return;

}

localViewerIndex.value =

0;

localViewerOpen.value =

true;

emit(

"viewer-open",

{

zone:

props.zone,

index: 0,

},

  );

};

// =========================================================

// VIEWER CLOSE

// =========================================================

const closeViewer = () => {

if (

props.mirrorOnly

  ) {

return;

}

localViewerOpen.value =

false;

emit(

"viewer-close",

{

zone:

props.zone,

},

  );

};

// =========================================================

// VIEWER INDEX

// =========================================================

const updateViewerIndex = (

index,

) => {

if (

props.mirrorOnly

  ) {

return;

}

const nextIndex =

Math.max(

0,

Math.min(

Number(index) ||

0,

Math.max(

0,

count.value -

1,

  ),

  ),

  );

localViewerIndex.value =

nextIndex;

emit(

"viewer-index-change",

{

zone:

props.zone,

index:

nextIndex,

},

  );

};

// =========================================================

// KEEP LOCAL INDEX VALID

// =========================================================

watch(

count,

  (

  newCount,

  ) => {

if (

!newCount

  ) {

localViewerIndex.value =

  0;

return;

  }

if (

localViewerIndex.value >=

  newCount

  ) {

localViewerIndex.value =

  newCount - 1;

  }

  },

);

// =========================================================

// DROP TARGET

// =========================================================

const handleDragOver = (

event,

) => {

if (

props.readonly ||

props.disabled ||

!props.allowDrop

  ) {

return;

}

event.preventDefault();

event.dataTransfer.dropEffect =

"move";

if (!dragOver.value) {

dragOver.value =

true;

emit(

"drag-hover",

{

zone:

props.zone,

},

  );

}

};

// =========================================================

// DRAG LEAVE

// =========================================================

const handleDragLeave = (

event,

) => {

const element =

event.currentTarget;

const related =

event.relatedTarget;

/*

  * Masih di dalam BattleZoneStack.

  * Jangan dianggap leave.

  */

if (

element &&

related &&

element.contains(

related,

  )

  ) {

return;

}

if (

!dragOver.value

  ) {

return;

}

dragOver.value =

false;

emit(

"drag-hover",

{

zone: null,

},

  );

};

// =========================================================

// DROP PAYLOAD

// =========================================================

const getDropPayload = (

event,

) => {

const raw =

event.dataTransfer.getData(

"application/x-battle-card",

  ) ||

event.dataTransfer.getData(

"text/plain",

  );

if (!raw) {

return null;

}

try {

return JSON.parse(

raw,

  );

} catch {

return null;

}

};

// =========================================================

// DROP

// =========================================================

const handleDrop = (

event,

) => {

if (

props.readonly ||

props.disabled ||

!props.allowDrop

  ) {

return;

}

event.preventDefault();

dragOver.value =

false;

const payload =

getDropPayload(

event,

  );

if (

!payload?.cardId

  ) {

emit(

"drag-hover",

{

zone: null,

},

  );

return;

}

/*

  * Public mirror tahu player

  * melakukan drop ke zone ini.

  */

emit(

"drag-hover",

{

zone:

props.zone,

},

  );

emit(

"drop-card",

{

...payload,

toZone:

props.zone,

},

  );

};

// =========================================================

// CARD SELECT

// =========================================================

const handleCardSelect = (

card,

) => {

if (

props.mirrorOnly

  ) {

return;

}

emit(

"card-select",

card,

  );

};

// =========================================================

// VIEWER CARD DRAG START

// =========================================================

const handleDragStart = (

card,

) => {

if (

props.mirrorOnly

  ) {

return;

}

emit(

"drag-start",

card,

  );

};

// =========================================================

// VIEWER CARD DRAG END

// =========================================================

const handleDragEnd = (

card,

) => {

if (

props.mirrorOnly

  ) {

return;

}

emit(

"drag-end",

card,

  );

localViewerOpen.value = false;

emit("viewer-close", { zone: props.zone });

/*

  * Pastikan highlight drop target hilang.

  */

dragOver.value =

false;

emit(

"drag-hover",

{

zone: null,

},

  );

};

const handleBenchAction = (card) => {
  if (props.mirrorOnly || props.readonly || !card) return;
  emit("bench-action", card);
};

</script>

<template>

  <aside

class="battle-zone-stack"

  :class="[

  `zone-${zone}`,

  `side-${side}`,

  `accent-${accent}`,

  {

  'drag-over':

dragOver,

disabled,

  'mirror-only':

mirrorOnly,

  'viewer-live':

effectiveViewerOpen,

  },

  ]"

  @dragover="

handleDragOver

  "

  @dragleave="

handleDragLeave

  "

  @drop="

handleDrop

  "

  >

<!-- ===============================================

  HEADER

  ================================================ -->

  <header

class="zone-header"

  >

  <div>

  <span

class="zone-eyebrow"

  >

  {{ subtitle }}

  </span>

  <strong>

  {{ title }}

  </strong>

  </div>

  <span

class="zone-count"

  >

  {{ countLabel }}

  </span>

  </header>

<!-- ===============================================

  LIVE BADGE

  ================================================ -->

  <Transition name="zone-live">

  <div

v-if="

mirrorOnly &&

effectiveViewerOpen

  "

class="zone-live-badge"

  >

  <span />

  PLAYER VIEWING

  </div>

  </Transition>

<!-- ===============================================

  PILE BUTTON

  ================================================ -->

  <button

type="button"

class="card-pile"

  :class="{

empty:

!count,

  'pile-open':

effectiveViewerOpen,

  }"

  :disabled="

disabled ||

mirrorOnly

  "

  @click="

openViewer

  "

  >

<!-- EMPTY -->

  <template

v-if="!count"

  >

  <div

class="empty-pile-card"

  >

  <span>

  {{ symbol }}

  </span>

  <small>

  EMPTY

  </small>

  </div>

  </template>

<!-- CARDS -->

  <template v-else>

  <article

v-for="(

card,

index

  ) in visibleCards"

  :key="

getCardId(card) ??

index

  "

class="pile-card"

  :class="{
    'fusion-necro-ready-card':
      zone === 'graveyard' &&
      isNecroReadyAfterFusion(card),

    'fusion-necro-spent-card':
      zone === 'graveyard' &&
      isNecroConsumed(card),
  }"

  :style="

stackStyle(

index,

  )

  "

  >

  <img

v-if="

card.image_url

  "

  :src="

card.image_url

  "

  :alt="

card.name

  "

  />

  <div

v-else

class="

  pile-placeholder

  "

  >

  {{ symbol }}

  </div>

  <div

class="pile-overlay"

/>

  <span

v-if="

index ===

visibleCards.length -

  1

  "

class="top-card-name"

  >

  {{

card.name

  }}

  </span>

  <!-- Phase 3D.10: overlay only, does not change zone layout -->
  <span
    v-if="
      zone === 'graveyard' &&
      index === visibleCards.length - 1 &&
      isNecroConsumed(card)
    "
    class="fusion-lifecycle-mini spent"
  >
    ☠ SPENT
  </span>

  <span
    v-else-if="
      zone === 'graveyard' &&
      index === visibleCards.length - 1 &&
      isNecroReadyAfterFusion(card)
    "
    class="fusion-lifecycle-mini ready"
  >
    🧬→☠ READY
  </span>

  </article>

  </template>

<!-- COUNT -->

  <span

v-if="count"

class="pile-counter"

  >

  {{ count }}

  </span>

  </button>

<!-- ===============================================

  HINT

  ================================================ -->

  <div

class="zone-hint"

  >

<!-- DRAG -->

  <template

v-if="dragOver"

  >

  <span

class="drop-icon"

  >

  ↓

  </span>

  DROP CARD HERE

  </template>

<!-- LIVE -->

  <template

v-else-if="

mirrorOnly &&

effectiveViewerOpen

  "

  >

  <span

class="live-small-dot"

  >

  ●

  </span>

  LIVE PLAYER

  </template>

<!-- DROP ENABLE -->

  <template

v-else-if="

allowDrop &&

!readonly

  "

  >

  DRAG CARD HERE

  </template>

<!-- PUBLIC -->

  <template

v-else-if="

mirrorOnly

  "

  >

  LIVE MIRROR

  </template>

<!-- NORMAL -->

  <template v-else>

  CLICK TO VIEW

  </template>

  </div>

<!-- ===============================================

  DROP GLOW

  ================================================ -->

  <div

class="drop-glow"

/>

<!-- ===============================================

  VIEWER

  ================================================ -->

  <BattlePileViewer

  :open="

effectiveViewerOpen

  "

  :title="

title

  "

  :zone="

zone

  "

  :cards="

cards

  "

  :active-index="

effectiveViewerIndex

  "

  :readonly="

readonly

  "

  :draggable-cards="

draggableCards

  "

  :show-bench-action="showBenchAction"

  :bench-action-enabled="benchActionEnabled"

  :bench-action-label="benchActionLabel"

  :bench-action-hint="benchActionHint"

  :interactive="

!mirrorOnly

  "

  :accent="

accent

  "

  @close="

closeViewer

  "

  @update:active-index="

updateViewerIndex

  "

  @select="

handleCardSelect

  "

  @drag-start="

handleDragStart

  "

  @drag-end="

handleDragEnd

  "

  @bench-action="handleBenchAction"

  />

  </aside>

</template>

<style scoped>

* {

  box-sizing: border-box;

}

button {

  font: inherit;

}

/* =========================================================

  ROOT

========================================================= */

.battle-zone-stack {

--accent: #2db8ff;

--accent-soft: #9ce5ff;

  width: 158px;

  min-height: 390px;

  position: relative;

  display: flex;

  flex-direction: column;

  align-items: center;

  gap: 16px;

  padding:

  15px 10px 18px;

  border:

  1px solid

  rgba(

  44,

  155,

  206,

  0.16

  );

  border-radius: 24px;

  background:

  linear-gradient(

  180deg,

  rgba(

  255,

  255,

  255,

  0.52

  ),

  rgba(

  211,

  239,

  248,

  0.36

  )

  );

  box-shadow:

  0 16px 38px

  rgba(

  72,

  137,

  163,

  0.13

  ),

  inset

  0 1px 0

  rgba(

  255,

  255,

  255,

  0.8

  );

  backdrop-filter:

  blur(16px);

  transition:

  transform 0.22s ease,

  border-color 0.22s ease,

  box-shadow 0.22s ease;

}

/* =========================================================

  ACCENTS

========================================================= */

.battle-zone-stack.accent-red {

--accent: #ef5c7e;

--accent-soft: #ffafc0;

}

.battle-zone-stack.zone-graveyard {

--accent: #755acb;

--accent-soft: #baa9f8;

  border-color:

  rgba(

  106,

  82,

  170,

  0.18

  );

  background:

  linear-gradient(

  180deg,

  rgba(

  242,

  238,

  255,

  0.65

  ),

  rgba(

  209,

  200,

  232,

  0.44

  )

  );

}

.battle-zone-stack.disabled {

  opacity: 0.55;

  pointer-events: none;

}

.battle-zone-stack.viewer-live {

  border-color:

  color-mix(

  in srgb,

  var(--accent) 35%,

  transparent

  );

}

/* =========================================================

  HEADER

========================================================= */

.zone-header {

  width: 100%;

  display: flex;

  align-items: center;

  justify-content:

  space-between;

  gap: 7px;

}

.zone-header > div {

  min-width: 0;

  display: flex;

  flex-direction: column;

  gap: 2px;

}

.zone-eyebrow {

  color: #8297a9;

  font-size: 6px;

  font-weight: 900;

  letter-spacing:

  0.08em;

  text-transform:

  uppercase;

}

.zone-header strong {

  color: #24435a;

  font-size: 10px;

  font-weight: 950;

  letter-spacing:

  0.05em;

}

.zone-count {

  flex-shrink: 0;

  padding:

  4px 7px;

  border-radius:

  999px;

  color:

  var(--accent);

  background:

  color-mix(

  in srgb,

  var(--accent) 9%,

  white

  );

  font-size: 7px;

  font-weight: 950;

}

/* =========================================================

  LIVE BADGE

========================================================= */

.zone-live-badge {

  position: absolute;

  left: 50%;

  top: 52px;

  z-index: 100;

  transform:

  translateX(-50%);

  display: flex;

  align-items: center;

  gap: 5px;

  padding:

  4px 7px;

  border-radius:

  999px;

  color:

  var(--accent);

  background:

  rgba(

  255,

  255,

  255,

  0.88

  );

  box-shadow:

  0 5px 15px

  rgba(

  0,

  0,

  0,

  0.08

  );

  font-size: 6px;

  font-weight: 950;

  letter-spacing:

  0.07em;

  pointer-events: none;

}

.zone-live-badge span {

  width: 5px;

  height: 5px;

  border-radius: 50%;

  background:

  var(--accent);

  box-shadow:

  0 0 7px

  var(--accent);

  animation:

  zone-live-pulse

  1s ease

  infinite;

}

@keyframes zone-live-pulse {

  50% {

  opacity: 0.3;

  }

}

/* =========================================================

  PILE

========================================================= */

.card-pile {

  width: 122px;

  height: 230px;

  position: relative;

  padding: 0;

  border: 0;

  outline: none;

  background:

  transparent;

  cursor: pointer;

  perspective: 600px;

}

.card-pile:disabled {

  cursor: default;

}

.pile-card,

.empty-pile-card {

  width: 104px;

  height: 158px;

  position: absolute;

  left: 9px;

  top: 33px;

  overflow: hidden;

  border:

  2px solid

  rgba(

  255,

  255,

  255,

  0.8

  );

  border-radius: 13px;

  background:

  linear-gradient(

  145deg,

  #205b85,

  #12354e

  );

  box-shadow:

  0 10px 22px

  rgba(

  44,

  95,

  118,

  0.21

  );

  transition:

  transform

  0.25s ease,

  box-shadow

  0.25s ease;

}

.zone-graveyard

.pile-card {

  filter:

  saturate(0.6)

  brightness(0.82);

}

/* PLAYER HOVER ONLY */

.battle-zone-stack:not(

.mirror-only

)

.card-pile:hover

.pile-card:last-of-type {

  transform:

  translateY(-8px)

  rotate(0deg)

  scale(1.04) !important;

  box-shadow:

  0 15px 32px

  rgba(

  34,

  95,

  124,

  0.28

  );

}

/* LIVE OPEN */

.pile-open

.pile-card:last-of-type {

  box-shadow:

  0 13px 32px

  color-mix(

  in srgb,

  var(--accent) 22%,

  transparent

  );

}

.pile-card img {

  width: 100%;

  height: 100%;

  object-fit: cover;

}

.pile-placeholder {

  width: 100%;

  height: 100%;

  display: grid;

  place-items: center;

  color:

  rgba(

  255,

  255,

  255,

  0.45

  );

  font-size: 50px;

}

.pile-overlay {

  position: absolute;

  inset: 0;

  pointer-events: none;

  background:

  linear-gradient(

  180deg,

  transparent 48%,

  rgba(

  2,

  12,

  24,

  0.72

  )

  );

}

.top-card-name {

  max-width: 86px;

  position: absolute;

  left: 8px;

  bottom: 9px;

  overflow: hidden;

  color: white;

  font-size: 7px;

  font-weight: 900;

  text-overflow:

  ellipsis;

  white-space: nowrap;

}

/* =========================================================

  EMPTY

========================================================= */

.empty-pile-card {

  display: flex;

  flex-direction: column;

  align-items: center;

  justify-content: center;

  gap: 6px;

  border:

  2px dashed

  color-mix(

  in srgb,

  var(--accent) 25%,

  white

  );

  color:

  var(--accent);

  background:

  rgba(

  255,

  255,

  255,

  0.32

  );

  box-shadow: none;

}

.empty-pile-card span {

  font-size: 38px;

  opacity: 0.28;

}

.empty-pile-card small {

  font-size: 7px;

  font-weight: 950;

}

/* =========================================================

  COUNTER

========================================================= */

.pile-counter {

  min-width: 31px;

  height: 31px;

  position: absolute;

  right: -1px;

  bottom: 26px;

  z-index: 50;

  display: grid;

  place-items: center;

  padding:

  0 7px;

  border:

  3px solid

  rgba(

  255,

  255,

  255,

  0.92

  );

  border-radius:

  999px;

  color: white;

  background:

  var(--accent);

  box-shadow:

  0 6px 15px

  color-mix(

  in srgb,

  var(--accent) 28%,

  transparent

  );

  font-size: 9px;

  font-weight: 950;

}

/* =========================================================

  HINT

========================================================= */

.zone-hint {

  min-height: 25px;

  display: flex;

  align-items: center;

  justify-content: center;

  gap: 4px;

  color: #7b91a5;

  font-size: 6px;

  font-weight: 950;

  letter-spacing:

  0.08em;

}

.drop-icon {

  color:

  var(--accent);

  font-size: 12px;

}

.live-small-dot {

  color:

  var(--accent);

  font-size: 8px;

  text-shadow:

  0 0 8px

  var(--accent);

}

/* =========================================================

  DROP STATE

========================================================= */

.battle-zone-stack.drag-over {

  border-color:

  var(--accent);

  transform:

  translateY(-3px)

  scale(1.025);

  box-shadow:

  0 18px 44px

  color-mix(

  in srgb,

  var(--accent) 22%,

  transparent

  ),

  inset

  0 0 0 2px

  color-mix(

  in srgb,

  var(--accent) 16%,

  transparent

  );

}

.drop-glow {

  position: absolute;

  inset: 4px;

  z-index: -1;

  border-radius: 21px;

  opacity: 0;

  pointer-events: none;

  background:

  color-mix(

  in srgb,

  var(--accent) 14%,

  transparent

  );

  transition:

  opacity 0.2s ease;

}

.drag-over

.drop-glow {

  opacity: 1;

}

/* =========================================================

  LIVE TRANSITION

========================================================= */

.zone-live-enter-active,

.zone-live-leave-active {

  transition:

  opacity

  0.15s ease,

  transform

  0.15s ease;

}

.zone-live-enter-from,

.zone-live-leave-to {

  opacity: 0;

  transform:

  translateX(-50%)

  translateY(-5px)

  scale(0.9);

}

/* =========================================================

  MOBILE

========================================================= */

@media (

  max-width: 850px

) {

.battle-zone-stack {

  width: 125px;

  min-height: 320px;

  padding:

  12px 7px;

  }

.card-pile {

  width: 100px;

  height: 185px;

  }

.pile-card,

.empty-pile-card {

  width: 85px;

  height: 130px;

  left: 7px;

  top: 27px;

  }

.zone-live-badge {

  top: 48px;

  }

}



/* =========================================================
   LIGHT THEME OVERRIDES
   Source: latest uploaded BattleZoneStack.vue
   Logic / template tetap, hanya palette diubah.
========================================================= */

.battle-zone-stack {
  border-color: rgba(70, 140, 176, 0.18);

  background:
    linear-gradient(
      180deg,
      rgba(255, 255, 255, 0.96),
      rgba(231, 245, 251, 0.90)
    );

  box-shadow:
    0 16px 38px rgba(72, 137, 163, 0.13),
    inset 0 1px 0 rgba(255, 255, 255, 0.95);
}

.battle-zone-stack.zone-graveyard {
  border-color: rgba(112, 87, 189, 0.18);

  background:
    linear-gradient(
      180deg,
      rgba(255, 255, 255, 0.96),
      rgba(242, 238, 253, 0.92)
    );
}

.zone-eyebrow {
  color: #8397a6;
}

.zone-header strong {
  color: #244b64;
}

.zone-count {
  color: var(--accent);

  background:
    color-mix(
      in srgb,
      var(--accent) 8%,
      white
    );
}

.zone-live-badge {
  color: var(--accent);
  background: rgba(255, 255, 255, 0.92);
  box-shadow: 0 5px 15px rgba(67, 117, 144, 0.10);
}

.pile-card,
.empty-pile-card {
  border-color: rgba(255, 255, 255, 0.96);

  background:
    linear-gradient(
      145deg,
      #dff4fb,
      #bedfec
    );

  box-shadow: 0 10px 22px rgba(58, 111, 137, 0.16);
}

.battle-zone-stack:not(.mirror-only)
.card-pile:hover
.pile-card:last-of-type {
  box-shadow: 0 15px 32px rgba(58, 111, 137, 0.20);
}

.pile-placeholder {
  background:
    linear-gradient(
      145deg,
      #f8fdff,
      #dff1f8
    );
}

.zone-graveyard .pile-placeholder {
  background:
    linear-gradient(
      145deg,
      #fbfaff,
      #e7e0f6
    );
}

.pile-overlay {
  background:
    linear-gradient(
      180deg,
      transparent 52%,
      rgba(28, 68, 91, 0.42)
    );
}

.top-card-name {
  color: #ffffff;

  text-shadow:
    0 1px 5px rgba(23, 61, 81, 0.55);
}

.empty-pile-card {
  border-color:
    color-mix(
      in srgb,
      var(--accent) 28%,
      white
    );

  color: var(--accent);
  background: rgba(255, 255, 255, 0.58);
  box-shadow: none;
}

.pile-counter {
  border-color: rgba(255, 255, 255, 0.98);
  color: #ffffff;
  background: var(--accent);
}

.zone-hint {
  color: #7b91a2;
}

.battle-zone-stack.drag-over {
  border-color: var(--accent);

  box-shadow:
    0 18px 44px
      color-mix(
        in srgb,
        var(--accent) 18%,
        transparent
      ),
    inset
      0 0 0 2px
      color-mix(
        in srgb,
        var(--accent) 12%,
        transparent
      );
}

.drop-glow {
  background:
    color-mix(
      in srgb,
      var(--accent) 10%,
      transparent
    );
}


/* =========================================================
   PHASE 3D.10 — TWO-STAGE FUSION STATUS
   Layout-safe: overlay only.
   No width / height / gap / zone-header changes.
========================================================= */

.zone-graveyard .pile-card.fusion-necro-ready-card {
  box-shadow:
    0 0 0 1px rgba(13, 148, 136, 0.30),
    0 10px 22px rgba(13, 148, 136, 0.12);
}

.zone-graveyard .pile-card.fusion-necro-spent-card {
  filter:
    saturate(0.35)
    brightness(0.76);
}

.fusion-lifecycle-mini {
  position: absolute;
  z-index: 12;
  top: 6px;
  right: 6px;

  display: inline-flex;
  align-items: center;

  max-width:
    calc(100% - 12px);

  padding:
    4px 6px;

  border:
    1px solid
    rgba(255, 255, 255, 0.88);

  border-radius:
    999px;

  color:
    #ffffff;

  font-size:
    6px;

  font-weight:
    950;

  line-height:
    1;

  letter-spacing:
    0.045em;

  white-space:
    nowrap;

  box-shadow:
    0 5px 14px
    rgba(24, 52, 69, 0.18);

  pointer-events:
    none;
}

.fusion-lifecycle-mini.ready {
  background:
    rgba(15, 118, 110, 0.94);
}

.fusion-lifecycle-mini.spent {
  background:
    rgba(88, 62, 161, 0.94);
}

</style>
