<script setup>
import { revivalCardReason } from "../../lib/battle/pilotRules.js";
import {
  computed,
  onMounted,
  onUnmounted,
} from "vue";

const props = defineProps({
  arena: Boolean,
  unlimitedBenchReturns: Boolean,
  benchCardReason: Function,
  open: {
    type: Boolean,
    default: false,
  },

  title: {
    type: String,
    default: "CARDS",
  },

  zone: {
    type: String,
    default: "bench",
  },

  cards: {
    type: Array,
    default: () => [],
  },

  activeIndex: {
    type: Number,
    default: 0,
  },

  readonly: {
    type: Boolean,
    default: false,
  },

  draggableCards: {
    type: Boolean,
    default: false,
  },

  interactive: {
    type: Boolean,
    default: true,
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
});

const emit = defineEmits([
  "close",
  "select",
  "update:activeIndex",
  "drag-start",
  "drag-end",
  "bench-action",
]);

const cardCount = computed(
  () => props.cards?.length ?? 0,
);

const safeIndex = computed(() => {
  if (!cardCount.value) {
    return 0;
  }

  return Math.max(
    0,
    Math.min(
      Number(props.activeIndex ?? 0),
      cardCount.value - 1,
    ),
  );
});

const activeCard = computed(
  () =>
    props.cards[
      safeIndex.value
    ] ?? null,
);

const getCardId = (card) =>
  card?.battleId ??
  card?.battle_id ??
  card?.id ??
  card?.uid ??
  null;


const isNecroConsumed = card => Boolean(revivalCardReason(card));


const getCardHp = (card) =>
  Number(
    card?.current_hp ??
      card?.currentHp ??
      card?.hp ??
      0,
  );

const getCardBaseHp = (card) =>
  Number(
    card?.base_hp ??
      card?.baseHp ??
      card?.hp ??
      0,
  );

const getBenchReturnCount = (
  card,
) =>
  Number(
    card?.bench_return_count ??
      card?.benchReturnCount ??
      0,
  );

const setIndex = (index) => {
  if (
    !props.interactive ||
    !cardCount.value
  ) {
    return;
  }

  const next =
    Math.max(
      0,
      Math.min(
        Number(index) || 0,
        cardCount.value - 1,
      ),
    );

  if (
    next ===
    safeIndex.value
  ) {
    return;
  }

  emit(
    "update:activeIndex",
    next,
  );
};

const previousCard = () => {
  if (
    !props.interactive ||
    safeIndex.value <= 0
  ) {
    return;
  }

  setIndex(
    safeIndex.value - 1,
  );
};

const nextCard = () => {
  if (
    !props.interactive ||
    safeIndex.value >=
      cardCount.value - 1
  ) {
    return;
  }

  setIndex(
    safeIndex.value + 1,
  );
};

const getRelativePosition = (
  index,
) =>
  index -
  safeIndex.value;

const getCardStyle = (
  index,
) => {
  const position =
    getRelativePosition(
      index,
    );

  const distance =
    Math.abs(
      position,
    );

  if (
    distance > 4
  ) {
    return {
      opacity: 0,

      pointerEvents:
        "none",

      transform:
        "translate(-50%, -50%) scale(.45)",

      zIndex: 0,
    };
  }

  const x =
    position * 108;

  const y =
    distance * 17;

  const rotate =
    position * 7;

  const scale =
    position === 0
      ? 1.12
      : Math.max(
          0.72,
          1 -
            distance *
              0.1,
        );

  const opacity =
    Math.max(
      0.22,
      1 -
        distance *
          0.17,
    );

  return {
    transform: `
      translate(
        calc(-50% + ${x}px),
        calc(-50% + ${y}px)
      )
      rotate(${rotate}deg)
      scale(${scale})
    `,

    opacity,

    zIndex:
      100 -
      distance * 10,
  };
};

let wheelLocked = false;
let wheelTimer = null;

const onWheel = (
  event,
) => {
  if (
    !props.open ||
    !props.interactive ||
    cardCount.value <= 1
  ) {
    return;
  }

  event.preventDefault();

  if (wheelLocked) {
    return;
  }

  const atFirst =
    safeIndex.value <= 0;

  const atLast =
    safeIndex.value >=
    cardCount.value - 1;

  if (
    event.deltaY < 0 &&
    atFirst
  ) {
    return;
  }

  if (
    event.deltaY > 0 &&
    atLast
  ) {
    return;
  }

  wheelLocked = true;

  if (
    event.deltaY > 0
  ) {
    nextCard();
  } else {
    previousCard();
  }

  if (wheelTimer) {
    clearTimeout(
      wheelTimer,
    );
  }

  wheelTimer =
    setTimeout(
      () => {
        wheelLocked =
          false;
      },
      120,
    );
};

const onKeydown = (
  event,
) => {
  if (
    !props.open ||
    !props.interactive
  ) {
    return;
  }

  if (
    event.key ===
    "Escape"
  ) {
    emit("close");

    return;
  }

  if (
    event.key ===
    "ArrowLeft"
  ) {
    previousCard();

    return;
  }

  if (
    event.key ===
    "ArrowRight"
  ) {
    nextCard();
  }
};

const closeViewer = () => {
  if (
    !props.interactive
  ) {
    return;
  }

  emit("close");
};

const onBackdropClick = (
  event,
) => {
  if (
    !props.interactive
  ) {
    return;
  }

  if (
    event.target ===
    event.currentTarget
  ) {
    closeViewer();
  }
};

const handleCardClick = (
  index,
) => {
  if (
    !props.interactive
  ) {
    return;
  }

  setIndex(
    index,
  );
};

const selectCard = (
  card,
) => {
  if (
    !props.interactive ||
    !card
  ) {
    return;
  }

  emit(
    "select",
    card,
  );
};

const startCardDrag = (
  event,
  card,
) => {
  if (
    !props.interactive ||
    props.readonly ||
    !props.draggableCards ||
    !card
  ) {
    event.preventDefault();

    return;
  }

  const payload = {
    cardId:
      getCardId(
        card,
      ),

    uid:
      card?.uid ??
      null,

    name:
      card?.name ??
      "",

    fromZone:
      props.zone,
  };

  event.dataTransfer.effectAllowed =
    "move";

  document.body.classList.add(
    "tcg-card-dragging",
  );

  event.dataTransfer.setData(
    "application/x-battle-card",
    JSON.stringify(
      payload,
    ),
  );

  event.dataTransfer.setData(
    "text/plain",
    JSON.stringify(
      payload,
    ),
  );

  emit(
    "drag-start",
    card,
  );
};

const endCardDrag = (
  card,
) => {
  document.body.classList.remove(
    "tcg-card-dragging",
  );

  if (
    !props.interactive
  ) {
    return;
  }

  emit(
    "drag-end",
    card,
  );
};

onMounted(() => {
  window.addEventListener(
    "keydown",
    onKeydown,
  );
});

onUnmounted(() => {
  document.body.classList.remove(
    "tcg-card-dragging",
  );

  window.removeEventListener(
    "keydown",
    onKeydown,
  );

  if (wheelTimer) {
    clearTimeout(
      wheelTimer,
    );
  }
});
</script>

<template>
  <Teleport to="body">
    <Transition
      name="pile-viewer"
    >
      <div
        v-if="open"
        class="pile-viewer-overlay"
        :class="[
          `zone-${zone}`,
          `accent-${accent}`,
          {
            'mirror-viewer':
              !interactive,
          },
        ]"
        @click="onBackdropClick"
        @wheel="onWheel"
      >
        <div
          class="pile-viewer-backdrop"
        />

        <div
          class="pile-viewer-glow"
        />

        <section
          class="pile-viewer-panel"
          :class="{'arena-frame': arena}"
        >
          <header
            class="viewer-header"
          >
            <div>
              <span
                class="viewer-eyebrow"
              >
                {{
                  zone ===
                  "graveyard"
                    ? "DESTROYED CARDS"
                    : "RESERVE CARDS"
                }}
              </span>

              <h2>
                {{ title }}
              </h2>

              <p>
                {{ cardCount }}
                CARD{{
                  cardCount === 1
                    ? ""
                    : "S"
                }}
              </p>
            </div>

            <button
              v-if="interactive"
              type="button"
              class="close-button"
              @click="closeViewer"
            >
              ✕
            </button>

            <div
              v-else
              class="live-indicator"
            >
              <span />

              LIVE
            </div>
          </header>

          <div
            v-if="!cardCount"
            class="empty-viewer"
          >
            <div
              class="empty-symbol"
            >
              {{
                zone ===
                "graveyard"
                  ? "☠"
                  : "◉"
              }}
            </div>

            <strong>
              {{
                zone ===
                "graveyard"
                  ? "GRAVEYARD EMPTY"
                  : "BENCH EMPTY"
              }}
            </strong>

            <span>
              Belum ada card di
              zone ini.
            </span>
          </div>

          <template v-else>
            <div
              class="wheel-instruction"
            >
              <template
                v-if="interactive"
              >
                <span>
                  ← →
                </span>

                SCROLL / ARROW KEY
              </template>

              <template v-else>
                <span
                  class="live-dot"
                >
                  ●
                </span>

                LIVE PLAYER VIEW
              </template>
            </div>

            <div
              class="card-wheel"
            >
              <button
                v-if="
                  cardCount > 1 &&
                  interactive
                "
                type="button"
                class="wheel-nav left"
                :disabled="
                  safeIndex === 0
                "
                @click="
                  previousCard
                "
              >
                ‹
              </button>

              <div
                class="wheel-stage"
              >
                <article
                  v-for="(
                    card,
                    index
                  ) in cards"
                  :key="
                    getCardId(
                      card,
                    ) ?? index
                  "
                  class="wheel-card"
                  :class="{
                    active:
                      index ===
                      safeIndex,

                    draggable:
                      interactive &&
                      draggableCards &&
                      !readonly,

                    'fusion-necro-spent':
                      zone === 'graveyard' &&
                      isNecroConsumed(card),
                  }"
                  :style="
                    getCardStyle(
                      index,
                    )
                  "
                  :draggable="
                    interactive &&
                    draggableCards &&
                    !readonly
                  "
                  @click="
                    handleCardClick(
                      index,
                    )
                  "
                  @dblclick="
                    selectCard(
                      card,
                    )
                  "
                  @dragstart="
                    startCardDrag(
                      $event,
                      card,
                    )
                  "
                  @dragend="
                    endCardDrag(
                      card,
                    )
                  "
                >
                  <div
                    class="wheel-card-image"
                  >
                    <img
                      v-if="
                        card.image_url
                      "
                      draggable="false"
                      :src="
                        card.image_url
                      "
                      :alt="
                        card.name
                      "
                    />

                    <div
                      v-else
                      class="image-placeholder"
                    >
                      ◉
                    </div>

                    <div
                      class="image-shine"
                    />

                    <span
                      class="card-zone-badge"
                    >
                      {{
                        zone ===
                        "graveyard"
                          ? "GY"
                          : "BENCH"
                      }}
                    </span>

                    <span
                      v-if="
                        zone === 'graveyard' &&
                        isNecroConsumed(card)
                      "
                      class="fusion-lifecycle-badge spent"
                    >
                      {{ revivalCardReason(card) }}
                    </span>



                    <span
                      v-else-if="
                        zone === 'graveyard'
                      "
                      class="fusion-lifecycle-badge natural"
                    >
                      Base KO • cek skill Revive
                    </span>
                  </div>

                  <div
                    class="wheel-card-content"
                  >
                    <header>
                      <strong>
                        {{
                          card.name
                        }}
                      </strong>

                      <span>
                        {{
                          card.element ||
                          "neutral"
                        }}
                      </span>
                    </header>

                    <div
                      class="card-hp"
                    >
                      <span>
                        HP
                      </span>

                      <strong>
                        {{
                          getCardHp(
                            card,
                          )
                        }}

                        /

                        {{
                          getCardBaseHp(
                            card,
                          )
                        }}
                      </strong>
                    </div>

                    <div
                      class="card-stats"
                    >
                      <div>
                        <span>
                          ATK
                        </span>

                        <strong>
                          {{
                            card.attack ??
                            0
                          }}
                        </strong>
                      </div>

                      <div>
                        <span>
                          DEF
                        </span>

                        <strong>
                          {{
                            card.defense ??
                            0
                          }}
                        </strong>
                      </div>
                    </div>

                    <div
                      v-if="
                        zone ===
                          'bench' &&
                        showBenchAction &&
                        interactive &&
                        !readonly
                      "
                      class="bench-action-block"
                    >
                      <span v-if="!unlimitedBenchReturns" class="bench-return-count">
                        RETURN {{ getBenchReturnCount(card) }} / 1
                      </span>
                      <p v-if="benchCardReason?.(card) || benchActionHint">
                        {{ benchCardReason?.(card) || benchActionHint }}
                      </p>
                      <button
                        type="button"
                        class="bench-action-button"
                        :disabled="
                          !benchActionEnabled ||
                          (!unlimitedBenchReturns && getBenchReturnCount(card) >= 1) ||
                          Boolean(benchCardReason?.(card)) ||
                          getCardHp(card) <= 0 ||
                          card.exhausted
                        "
                        @click.stop="emit('bench-action', card)"
                      >
                        {{ benchActionLabel }}
                      </button>
                    </div>

                    <div
                      v-else-if="zone === 'bench' && !unlimitedBenchReturns"
                      class="bench-return"
                    >
                      RETURN {{ getBenchReturnCount(card) }} / 1
                    </div>

                    <div
                      v-if="
                        zone ===
                        'graveyard'
                      "
                      class="graveyard-reason"
                      :class="{
                        'necro-ready':
                          !isNecroConsumed(card),

                        'necro-spent':
                          isNecroConsumed(card),
                      }"
                    >
                      {{
                        isNecroConsumed(card)
                          ? revivalCardReason(card)
                          : "Base KO • gunakan skill Revive jika tersedia"
                      }}
                    </div>
                  </div>
                </article>
              </div>

              <button
                v-if="
                  cardCount > 1 &&
                  interactive
                "
                type="button"
                class="wheel-nav right"
                :disabled="
                  safeIndex ===
                  cardCount - 1
                "
                @click="
                  nextCard
                "
              >
                ›
              </button>
            </div>

            <div
              v-if="activeCard"
              class="selected-card-details"
            >
              <div>
                <span>
                  SELECTED
                </span>

                <strong>
                  {{
                    activeCard.name
                  }}
                </strong>
              </div>

              <small
                v-if="
                  interactive &&
                  draggableCards &&
                  !readonly
                "
              >
                DRAG CARD TO ACTIVE FIELD
              </small>

              <small
                v-else-if="
                  !interactive
                "
                class="live-view-text"
              >
                PLAYER VIEWING

                {{
                  safeIndex + 1
                }}

                /

                {{ cardCount }}
              </small>

              <small v-else>
                {{
                  safeIndex + 1
                }}

                /

                {{ cardCount }}
              </small>
            </div>

            <div
              v-if="
                cardCount > 1
              "
              class="wheel-dots"
            >
              <button
                v-for="(
                  card,
                  index
                ) in cards"
                :key="
                  `dot-${
                    getCardId(
                      card,
                    ) ??
                    index
                  }`
                "
                type="button"
                :class="{
                  active:
                    index ===
                    safeIndex,
                }"
                :disabled="
                  !interactive
                "
                @click="
                  setIndex(
                    index,
                  )
                "
              />
            </div>
          </template>
        </section>
      </div>
    </Transition>
  </Teleport>
</template>

<style scoped>
* {
  box-sizing: border-box;
}

button {
  font: inherit;
}

.pile-viewer-overlay {
  --accent: #1ba9dc;
  --accent-soft: #4d8da8;

  position: fixed;
  inset: 0;

  z-index: 9999;

  display: grid;
  place-items: center;

  padding: 24px;

  overflow: hidden;

  color: #21465d;

  font-family:
    Inter,
    ui-sans-serif,
    system-ui,
    sans-serif;
}

.pile-viewer-overlay.accent-red {
  --accent: #e75a77;
  --accent-soft: #aa5a6b;
}

.pile-viewer-overlay.zone-graveyard {
  --accent: #7357c7;
  --accent-soft: #766998;
}

.pile-viewer-backdrop {
  position: absolute;
  inset: 0;

  background:
    rgba(
      232,
      246,
      252,
      0.82
    );

  backdrop-filter:
    blur(16px);
}

.mirror-viewer
.pile-viewer-backdrop {
  background:
    rgba(
      236,
      248,
      253,
      0.74
    );
}

.pile-viewer-glow {
  width:
    min(
      900px,
      90vw
    );

  height: 550px;

  position: absolute;

  left: 50%;
  top: 50%;

  transform:
    translate(
      -50%,
      -50%
    );

  border-radius: 50%;

  background:
    radial-gradient(
      circle,
      color-mix(
        in srgb,
        var(--accent)
          12%,
        transparent
      ),
      transparent 68%
    );

  filter:
    blur(30px);

  pointer-events: none;
}

.pile-viewer-panel {
  width:
    min(
      100%,
      1060px
    );

  min-height: 650px;

  position: relative;
  z-index: 2;

  overflow: hidden;

  padding: 24px;

  border:
    1px solid
    color-mix(
      in srgb,
      var(--accent)
        22%,
      transparent
    );

  border-radius: 26px;

  background:
    linear-gradient(
      145deg,
      rgba(
        255,
        255,
        255,
        0.98
      ),
      rgba(
        237,
        247,
        252,
        0.98
      )
    );

  box-shadow:
    0 28px 70px
      rgba(
        64,
        117,
        145,
        0.20
      ),
    inset
    0 1px 0
      rgba(
        255,
        255,
        255,
        0.96
      );
}

.viewer-header {
  position: relative;
  z-index: 20;

  display: flex;

  align-items:
    flex-start;

  justify-content:
    space-between;

  gap: 20px;
}

.viewer-eyebrow {
  color: var(--accent);

  font-size: 9px;

  font-weight: 950;

  letter-spacing:
    0.18em;
}

.viewer-header h2 {
  margin:
    4px 0 0;

  color: #234d67;

  font-size: 27px;

  letter-spacing:
    0.04em;
}

.viewer-header p {
  margin:
    7px 0 0;

  color: #7e94a4;

  font-size: 10px;

  font-weight: 850;
}

.close-button {
  width: 42px;
  height: 42px;

  display: grid;
  place-items: center;

  border:
    1px solid
    rgba(
      79,
      130,
      158,
      0.16
    );

  border-radius: 12px;

  color: #71899a;

  background:
    rgba(
      255,
      255,
      255,
      0.78
    );

  cursor: pointer;

  transition:
    0.2s ease;
}

.close-button:hover {
  color: #244c65;

  border-color:
    var(--accent);

  background:
    #ffffff;
}

.live-indicator {
  display: flex;

  align-items: center;

  gap: 7px;

  padding:
    7px 10px;

  border:
    1px solid
    color-mix(
      in srgb,
      var(--accent)
        22%,
      transparent
    );

  border-radius: 999px;

  color:
    var(--accent-soft);

  background:
    color-mix(
      in srgb,
      var(--accent)
        8%,
      white
    );

  font-size: 8px;

  font-weight: 950;

  letter-spacing:
    0.12em;
}

.live-indicator span {
  width: 7px;
  height: 7px;

  border-radius: 50%;

  background:
    var(--accent);

  box-shadow:
    0 0 12px
    var(--accent);

  animation:
    live-pulse
    1s ease-in-out
    infinite;
}

@keyframes live-pulse {
  50% {
    opacity: 0.35;
  }
}

.empty-viewer {
  min-height: 480px;

  display: flex;

  flex-direction: column;

  align-items: center;

  justify-content: center;

  gap: 9px;

  color: #7b91a2;
}

.empty-symbol {
  margin-bottom: 12px;

  color:
    var(--accent);

  font-size: 90px;

  opacity: 0.14;
}

.empty-viewer strong {
  color: #5b7486;

  font-size: 15px;
}

.empty-viewer span {
  font-size: 10px;
}

.wheel-instruction {
  position: absolute;

  left: 50%;
  top: 98px;

  transform:
    translateX(
      -50%
    );

  z-index: 20;

  color: #8094a4;

  font-size: 8px;

  font-weight: 900;

  letter-spacing:
    0.12em;
}

.wheel-instruction span {
  margin-right: 7px;

  color:
    var(--accent);
}

.live-dot {
  font-size: 9px;

  text-shadow:
    0 0 8px
    var(--accent);
}

.card-wheel {
  height: 490px;

  position: relative;

  display: flex;

  align-items: center;

  justify-content: center;
}

.wheel-stage {
  width:
    calc(
      100% - 110px
    );

  height: 100%;

  position: relative;

  perspective: 1200px;
}

.wheel-card {
  width: 210px;

  height: 330px;

  position: absolute;

  left: 50%;
  top: 50%;

  overflow: hidden;

  border:
    1px solid
    rgba(
      65,
      120,
      151,
      0.16
    );

  border-radius: 18px;

  color: #294f69;

  background:
    linear-gradient(
      145deg,
      #ffffff,
      #eef7fb
    );

  box-shadow:
    0 18px 38px
      rgba(
        68,
        112,
        139,
        0.16
      );

  cursor: pointer;

  transition:
    transform
    0.33s
    cubic-bezier(
      .2,
      .8,
      .2,
      1
    ),
    opacity
    0.25s ease,
    border-color
    0.2s ease,
    box-shadow
    0.25s ease;

  transform-origin:
    center;
}

.mirror-viewer
.wheel-card {
  cursor: default;
}

.wheel-card.active {
  border-color:
    color-mix(
      in srgb,
      var(--accent)
        58%,
      white
    );

  box-shadow:
    0 24px 54px
      rgba(
        64,
        109,
        135,
        0.20
      ),
    0 0 0 3px
      color-mix(
        in srgb,
        var(--accent)
          9%,
        transparent
      );
}

.wheel-card.draggable.active {
  cursor: grab;
}

.wheel-card.draggable.active:active {
  cursor: grabbing;
}

.wheel-card.draggable {
  -webkit-user-select: none;
  user-select: none;
  -webkit-user-drag: element;
}

.wheel-card.draggable * {
  -webkit-user-select: none;
  user-select: none;
  -webkit-user-drag: none;
}

:global(body.tcg-card-dragging .pile-viewer-overlay) {
  pointer-events: none;
  opacity: 0.12;
  transition: opacity 120ms ease;
}

.wheel-card-image {
  height: 185px;

  position: relative;

  overflow: hidden;

  background:
    #e7f2f7;
}

.wheel-card-image img {
  width: 100%;
  height: 100%;

  object-fit: cover;
}

.image-placeholder {
  width: 100%;
  height: 100%;

  display: grid;

  place-items: center;

  color:
    var(--accent);

  font-size: 70px;

  opacity: 0.22;
}

.image-shine {
  position: absolute;

  inset: 0;

  pointer-events: none;

  background:
    linear-gradient(
      135deg,
      rgba(
        255,
        255,
        255,
        0.35
      ),
      transparent
        35%
    );
}

.card-zone-badge {
  position: absolute;

  right: 9px;
  top: 9px;

  padding:
    4px 7px;

  border-radius: 999px;

  color: #244c65;

  background:
    rgba(
      255,
      255,
      255,
      0.86
    );

  box-shadow:
    0 4px 12px
    rgba(
      62,
      103,
      127,
      0.12
    );

  backdrop-filter:
    blur(8px);

  font-size: 7px;

  font-weight: 950;

  letter-spacing:
    0.08em;
}

.wheel-card-content {
  padding: 12px;
}

.wheel-card-content
> header {
  display: flex;

  align-items:
    flex-start;

  justify-content:
    space-between;

  gap: 8px;
}

.wheel-card-content
header strong {
  max-width: 130px;

  overflow: hidden;

  color: #254d67;

  font-size: 12px;

  text-overflow:
    ellipsis;

  white-space:
    nowrap;
}

.wheel-card-content
header span {
  color:
    var(--accent);

  font-size: 7px;

  font-weight: 900;

  text-transform:
    uppercase;
}

.card-hp {
  display: flex;

  align-items: center;

  justify-content:
    space-between;

  margin-top: 10px;

  padding:
    7px 9px;

  border-radius: 8px;

  background:
    rgba(
      221,
      239,
      247,
      0.66
    );
}

.card-hp span {
  color: #71899b;

  font-size: 7px;

  font-weight: 900;
}

.card-hp strong {
  color: #244d67;

  font-size: 10px;
}

.card-stats {
  display: grid;

  grid-template-columns:
    1fr 1fr;

  gap: 7px;

  margin-top: 8px;
}

.card-stats > div {
  display: flex;

  flex-direction: column;

  gap: 2px;

  padding: 7px;

  border-radius: 8px;

  background:
    rgba(
      228,
      241,
      247,
      0.72
    );
}

.card-stats span {
  color: #72899b;

  font-size: 6px;

  font-weight: 900;
}

.card-stats strong {
  color: #244d67;

  font-size: 11px;
}

.bench-return,
.graveyard-reason {
  margin-top: 8px;

  padding:
    6px 8px;

  border-radius: 7px;

  color:
    var(--accent-soft);

  background:
    color-mix(
      in srgb,
      var(--accent)
        7%,
      white
    );

  font-size: 7px;

  font-weight: 900;

  text-align: center;

  text-transform:
    uppercase;
}

.bench-action-block {
  display: grid;
  gap: 6px;
  margin-top: 9px;
}

.bench-return-count {
  color: #70889a;
  font-size: 7px;
  font-weight: 900;
  text-align: center;
  letter-spacing: 0.06em;
}

.bench-action-block p {
  margin: 0;
  color: #647f91;
  font-size: 8px;
  line-height: 1.35;
  text-align: center;
}

.bench-action-button {
  width: 100%;
  min-height: 34px;
  padding: 7px 10px;
  border: 1px solid color-mix(in srgb, var(--accent) 25%, white);
  border-radius: 10px;
  color: white;
  background: var(--accent);
  box-shadow: 0 5px 12px color-mix(in srgb, var(--accent) 18%, transparent);
  font-size: 8px;
  font-weight: 950;
  line-height: 1.25;
  text-align: center;
  cursor: pointer;
  transition: transform 0.16s ease, filter 0.16s ease, opacity 0.16s ease;
}

.bench-action-button:not(:disabled):hover {
  filter: brightness(1.05);
  transform: translateY(-1px);
}

.bench-action-button:disabled {
  color: #718497;
  background: #e8eff2;
  border-color: #d8e3e8;
  box-shadow: none;
  cursor: not-allowed;
}

.wheel-nav {
  width: 48px;

  height: 82px;

  position: absolute;

  top: 50%;

  z-index: 200;

  transform:
    translateY(
      -50%
    );

  display: grid;

  place-items: center;

  border:
    1px solid
    rgba(
      64,
      119,
      149,
      0.14
    );

  border-radius: 14px;

  color:
    var(--accent);

  background:
    rgba(
      255,
      255,
      255,
      0.82
    );

  box-shadow:
    0 8px 18px
    rgba(
      62,
      104,
      127,
      0.10
    );

  cursor: pointer;

  font-size: 40px;

  transition:
    0.2s ease;
}

.wheel-nav:hover:not(:disabled) {
  border-color:
    var(--accent);

  background:
    white;
}

.wheel-nav:disabled {
  opacity: 0.18;

  cursor: default;

  pointer-events: none;
}

.wheel-nav.left {
  left: 0;
}

.wheel-nav.right {
  right: 0;
}

.selected-card-details {
  display: flex;

  align-items: center;

  justify-content:
    space-between;

  gap: 20px;

  min-height: 57px;

  padding:
    10px 15px;

  border:
    1px solid
    color-mix(
      in srgb,
      var(--accent)
        14%,
      transparent
    );

  border-radius: 12px;

  background:
    color-mix(
      in srgb,
      var(--accent)
        4%,
      white
    );
}

.selected-card-details > div {
  display: flex;

  flex-direction: column;

  gap: 2px;
}

.selected-card-details span {
  color: #71899b;

  font-size: 7px;

  font-weight: 900;
}

.selected-card-details strong {
  color: #244d67;

  font-size: 12px;
}

.selected-card-details small {
  color:
    var(--accent);

  font-size: 8px;

  font-weight: 850;
}

.live-view-text {
  letter-spacing:
    0.08em;
}

.wheel-dots {
  display: flex;

  justify-content: center;

  gap: 7px;

  margin-top: 13px;
}

.wheel-dots button {
  width: 6px;
  height: 6px;

  padding: 0;

  border: 0;

  border-radius: 50%;

  background:
    #bfd1dc;

  cursor: pointer;

  transition:
    0.2s ease;
}

.wheel-dots button:disabled {
  cursor: default;
}

.wheel-dots button.active {
  width: 19px;

  border-radius:
    999px;

  background:
    var(--accent);

  box-shadow:
    0 0 8px
    color-mix(
      in srgb,
      var(--accent)
        25%,
      transparent
    );
}

.pile-viewer-enter-active,
.pile-viewer-leave-active {
  transition:
    opacity
    0.25s ease;
}

.pile-viewer-enter-active
.pile-viewer-panel,
.pile-viewer-leave-active
.pile-viewer-panel {
  transition:
    transform
    0.28s ease,
    opacity
    0.25s ease;
}

.pile-viewer-enter-from,
.pile-viewer-leave-to {
  opacity: 0;
}

.pile-viewer-enter-from
.pile-viewer-panel {
  opacity: 0;

  transform:
    scale(0.92)
    translateY(25px);
}

.pile-viewer-leave-to
.pile-viewer-panel {
  opacity: 0;

  transform:
    scale(0.95)
    translateY(20px);
}

@media (
  max-width: 720px
) {
  .pile-viewer-overlay {
    padding: 10px;
  }

  .pile-viewer-panel {
    min-height: 600px;

    padding: 17px;
  }

  .wheel-stage {
    width:
      calc(
        100% -
        60px
      );
  }

  .wheel-card {
    width: 175px;

    height: 290px;
  }

  .wheel-card-image {
    height: 150px;
  }

  .wheel-nav {
    width: 36px;

    height: 62px;

    font-size: 30px;
  }

  .viewer-header h2 {
    font-size: 21px;
  }

  .wheel-instruction {
    top: 90px;
  }
}

/* =========================================================
   PHASE 3D.10 — TWO-STAGE FUSION VIEWER STATUS
   Overlay/status only; original wheel geometry is untouched.
========================================================= */

.wheel-card.fusion-necro-ready {
  border-color:
    rgba(13, 148, 136, 0.34);
}

.wheel-card.fusion-necro-spent {
  border-color:
    rgba(117, 90, 203, 0.36);
}

.wheel-card.fusion-necro-spent
.wheel-card-image img {
  filter:
    grayscale(0.45)
    saturate(0.55)
    brightness(0.84);
}

.fusion-lifecycle-badge {
  position: absolute;
  z-index: 10;
  left: 10px;
  bottom: 10px;

  display: inline-flex;
  align-items: center;

  max-width:
    calc(100% - 20px);

  padding:
    6px 9px;

  border:
    1px solid
    rgba(255, 255, 255, 0.82);

  border-radius:
    999px;

  color:
    #ffffff;

  font-size:
    7px;

  font-weight:
    950;

  line-height:
    1;

  letter-spacing:
    0.035em;

  white-space:
    nowrap;

  box-shadow:
    0 7px 18px
    rgba(30, 60, 78, 0.18);

  pointer-events:
    none;
}

.fusion-lifecycle-badge.ready {
  background:
    rgba(15, 118, 110, 0.94);
}

.fusion-lifecycle-badge.natural {
  background:
    rgba(55, 65, 81, 0.90);
}

.fusion-lifecycle-badge.spent {
  background:
    rgba(88, 62, 161, 0.94);
}

.graveyard-reason.necro-ready {
  border-color:
    rgba(13, 148, 136, 0.20);

  background:
    rgba(13, 148, 136, 0.08);

  color:
    #0f766e;
}

.graveyard-reason.necro-spent {
  border-color:
    rgba(117, 90, 203, 0.20);

  background:
    rgba(117, 90, 203, 0.08);

  color:
    #6d50b9;
}

</style>
