<script setup>
import { computed } from "vue";

const props = defineProps({
  player: {
    type: String,
    required: true,
    validator: value => ["p1", "p2"].includes(value),
  },
  activeCards: {
    type: Array,
    default: () => [],
  },
  benchCards: {
    type: Array,
    default: () => [],
  },
  selectedCard: {
    type: Object,
    default: null,
  },
  selectedBenchCard: {
    type: Object,
    default: null,
  },
  currentTurn: {
    type: String,
    default: "p1",
  },
  battleState: {
    type: String,
    default: "waiting_p1",
  },
  winner: {
    type: String,
    default: null,
  },
  selectedTurnAction: {
    type: String,
    default: null,
  },
  isActing: {
    type: Boolean,
    default: false,
  },
  summonMode: {
    type: Boolean,
    default: false,
  },
  swapMode: {
    type: Boolean,
    default: false,
  },
  interactive: {
    type: Boolean,
    default: true,
  },
});

const emit = defineEmits([
  "active-card-click",
  "move-to-bench",
  "return-from-bench",
]);

const isP1 = computed(() =>
  props.player === "p1"
);

const normalizeElement = element =>
  String(element || "")
    .trim()
    .toLowerCase();

const isImageUrl = value =>
  value &&
  (
    String(value).startsWith("http") ||
    String(value).startsWith("/")
  );

const cardKey = card =>
  card?.battleId ??
  card?.battle_id ??
  card?.id ??
  card?.uid;

const isSelected = card =>
  cardKey(props.selectedCard) ===
  cardKey(card);

const isBenchSelected = card =>
  cardKey(props.selectedBenchCard) ===
  cardKey(card);

const canMoveToBench = card => {
  return (
    props.interactive &&
    props.currentTurn === props.player &&
    props.battleState === "battle_ready" &&
    !props.winner &&
    !props.selectedTurnAction &&
    !props.isActing &&
    !props.summonMode &&
    !props.swapMode &&
    card?.zone !== "bench"
  );
};

const canReturn = card => {
  return (
    props.interactive &&
    props.currentTurn === props.player &&
    props.battleState === "battle_ready" &&
    !props.selectedTurnAction &&
    !props.isActing &&
    !props.summonMode &&
    !card?.exhausted
  );
};
</script>

<template>
  <section
    class="field"
    :class="
      isP1
        ? 'field-blue'
        : 'field-red'
    "
  >
    <div
      class="field-background"
      :class="
        isP1
          ? 'bg-blue-arena'
          : 'bg-red-arena'
      "
    />

    <div
      class="giant-symbol"
      :class="
        isP1
          ? 'giant-blue'
          : 'giant-red'
      "
    />

    <div class="field-layout">
      <!-- ACTIVE -->
      <div class="field-section">
        <div
          class="section-title"
          :class="
            isP1
              ? 'blue-title'
              : 'red-title'
          "
        >
          ACTIVE DECK

          <span
            v-if="
              swapMode &&
              currentTurn === player
            "
            class="swap-help"
          >
            CLICK CARD TO SWAP
          </span>
        </div>

        <div class="pokemon-row">
          <div
            v-for="slot in 4"
            :key="`${player}-active-${slot}`"
            class="pokemon-slot"
            :class="
              isP1
                ? 'pokemon-slot-blue'
                : 'pokemon-slot-red'
            "
          >
            <template
              v-if="
                activeCards[
                  slot - 1
                ]
              "
            >
              <div
                class="pokemon-card"
                :class="[
                  isP1
                    ? 'pokemon-card-blue'
                    : 'pokemon-card-red',
                  {
                    selected:
                      isSelected(
                        activeCards[
                          slot - 1
                        ]
                      ),

                    'swap-target':
                      swapMode &&
                      currentTurn ===
                        player,
                  },
                ]"
                @click="
                  interactive &&
                  emit(
                    'active-card-click',
                    player,
                    activeCards[
                      slot - 1
                    ]
                  )
                "
              >
                <img
                  v-if="
                    isImageUrl(
                      activeCards[
                        slot - 1
                      ].image_url
                    )
                  "
                  :src="
                    activeCards[
                      slot - 1
                    ].image_url
                  "
                  :alt="
                    activeCards[
                      slot - 1
                    ].name
                  "
                >

                <div
                  class="
                    pokemon-card-overlay
                  "
                />

                <div
                  class="
                    pokemon-card-info
                  "
                >
                  <div class="card-top">
                    <span class="card-name">
                      {{
                        activeCards[
                          slot - 1
                        ].name
                      }}
                    </span>

                    <span
                      class="
                        element-pill
                      "
                    >
                      {{
                        normalizeElement(
                          activeCards[
                            slot - 1
                          ].element
                        ) || "?"
                      }}
                    </span>
                  </div>

                  <div class="card-hp">
                    CARD HP
                    {{
                      activeCards[
                        slot - 1
                      ].hp
                    }}
                  </div>

                  <div class="card-attack">
                    ATTACK

                    <strong>
                      {{
                        activeCards[
                          slot - 1
                        ].attack
                      }}
                    </strong>
                  </div>

                  <button
                    v-if="
                      canMoveToBench(
                        activeCards[
                          slot - 1
                        ]
                      )
                    "
                    type="button"
                    class="
                      move-bench-button
                    "
                    @click.stop="
                      emit(
                        'move-to-bench',
                        player,
                        activeCards[
                          slot - 1
                        ]
                      )
                    "
                  >
                    ↓ MOVE TO BENCH
                  </button>
                </div>

                <div
                  v-if="
                    isSelected(
                      activeCards[
                        slot - 1
                      ]
                    )
                  "
                  class="
                    selected-card-label
                  "
                >
                  SELECTED
                </div>

                <div
                  v-if="
                    swapMode &&
                    currentTurn === player
                  "
                  class="
                    swap-target-label
                  "
                >
                  SWAP WITH THIS
                </div>
              </div>
            </template>

            <template v-else>
              <div class="empty-slot">
                <div
                  class="
                    pokeball-symbol
                  "
                >
                  ◉
                </div>

                Pokémon {{ slot }}
              </div>
            </template>
          </div>
        </div>
      </div>

      <!-- BENCH -->
      <div class="field-section">
        <div
          class="section-title"
          :class="
            isP1
              ? 'blue-title'
              : 'red-title'
          "
        >
          BENCH
        </div>

        <div class="bench-row">
          <div
            v-for="slot in 4"
            :key="`${player}-bench-${slot}`"
            class="bench-slot"
            :class="
              isP1
                ? 'pokemon-slot-blue'
                : 'pokemon-slot-red'
            "
          >
            <template
              v-if="
                benchCards[
                  slot - 1
                ]
              "
            >
              <div
                class="bench-card"
                :class="{
                  exhausted:
                    benchCards[
                      slot - 1
                    ].exhausted,

                  'swap-selected':
                    isBenchSelected(
                      benchCards[
                        slot - 1
                      ]
                    ),
                }"
              >
                <img
                  v-if="
                    isImageUrl(
                      benchCards[
                        slot - 1
                      ].image_url
                    )
                  "
                  :src="
                    benchCards[
                      slot - 1
                    ].image_url
                  "
                  :alt="
                    benchCards[
                      slot - 1
                    ].name
                  "
                >

                <div
                  class="bench-overlay"
                />

                <div
                  class="bench-info"
                >
                  <strong>
                    {{
                      benchCards[
                        slot - 1
                      ].name
                    }}
                  </strong>

                  <span>
                    {{
                      normalizeElement(
                        benchCards[
                          slot - 1
                        ].element
                      ) || "?"
                    }}
                  </span>

                  <div
                    v-if="
                      benchCards[
                        slot - 1
                      ].exhausted
                    "
                    class="
                      exhausted-label
                    "
                  >
                    ☠ UNUSABLE
                  </div>

                  <button
                    v-else-if="
                      canReturn(
                        benchCards[
                          slot - 1
                        ]
                      )
                    "
                    type="button"
                    class="return-button"
                    @click="
                      emit(
                        'return-from-bench',
                        player,
                        benchCards[
                          slot - 1
                        ]
                      )
                    "
                  >
                    {{
                      activeCards.length <
                      4
                        ? "↥ RETURN"
                        : "⇄ SWAP"
                    }}
                  </button>

                  <div
                    v-if="
                      !benchCards[
                        slot - 1
                      ].exhausted
                    "
                    class="
                      return-counter
                    "
                  >
                    Return:
                    {{
                      benchCards[
                        slot - 1
                      ].benchReturnCount ??
                      benchCards[
                        slot - 1
                      ].bench_return_count ??
                      0
                    }}/1
                  </div>
                </div>

                <div
                  v-if="
                    benchCards[
                      slot - 1
                    ].exhausted
                  "
                  class="
                    exhausted-overlay
                  "
                >
                  <div>☠</div>

                  <strong>
                    EXHAUSTED
                  </strong>

                  <small>
                    Cannot return
                  </small>
                </div>
              </div>
            </template>

            <template v-else>
              <div class="empty-slot">
                <div class="small-ball">
                  ◉
                </div>

                Bench {{ slot }}
              </div>
            </template>
          </div>
        </div>
      </div>
    </div>
  </section>
</template>

<style scoped>
.field {
  width:
    50%;
  height:
    100%;
  position:
    relative;
  overflow:
    hidden;
}

.field-background {
  position:
    absolute;
  inset:
    0;
  background-position:
    center;
  background-size:
    cover;
}

.bg-blue-arena {
  background-image:
    linear-gradient(
      rgba(0,103,174,.24),
      rgba(0,42,88,.42)
    ),
    url('/images/arena-blue.jpg');
  background-color:
    #0877a5;
}

.bg-red-arena {
  background-image:
    linear-gradient(
      rgba(143,0,26,.2),
      rgba(73,0,14,.48)
    ),
    url('/images/arena-red.jpg');
  background-color:
    #861529;
}

.giant-symbol {
  width:
    270px;
  height:
    270px;
  position:
    absolute;
  left:
    50%;
  top:
    50%;
  transform:
    translate(-50%,-50%);
  opacity:
    .12;
  border-radius:
    50%;
  border:
    24px solid
    currentColor;
}

.giant-symbol::before {
  content:
    '';
  position:
    absolute;
  left:
    -24px;
  top:
    50%;
  width:
    calc(100% + 48px);
  height:
    24px;
  transform:
    translateY(-50%);
  background:
    currentColor;
}

.giant-symbol::after {
  content:
    '';
  width:
    85px;
  height:
    85px;
  position:
    absolute;
  left:
    50%;
  top:
    50%;
  transform:
    translate(-50%,-50%);
  border-radius:
    50%;
  border:
    18px solid
    currentColor;
}

.giant-blue {
  color:
    #a8ecff;
}

.giant-red {
  color:
    #ffb2c0;
}

.field-layout {
  height:
    100%;
  position:
    relative;
  z-index:
    5;
  padding:
    17px
    28px;
  display:
    flex;
  flex-direction:
    column;
  justify-content:
    space-around;
  gap:
    10px;
}

.field-section {
  display:
    flex;
  flex-direction:
    column;
  gap:
    6px;
}

.section-title {
  display:
    flex;
  justify-content:
    space-between;
  align-items:
    center;
  min-height:
    13px;
  font-size:
    7px;
  font-weight:
    1000;
  letter-spacing:
    .15em;
}

.blue-title {
  color:
    #9ce8ff;
}

.red-title {
  color:
    #ffabb9;
}

.swap-help {
  padding:
    3px 7px;
  border-radius:
    999px;
  color:
    #101520;
  background:
    #ffe65e;
  font-size:
    5px;
}

.pokemon-row,
.bench-row {
  display:
    grid;
  grid-template-columns:
    repeat(4,1fr);
  gap:
    11px;
}

.pokemon-slot,
.bench-slot {
  position:
    relative;
  justify-self:
    center;
  width:
    100%;
  max-width:
    114px;
  aspect-ratio:
    .73;
  border-radius:
    8px;
  overflow:
    visible;
}

.pokemon-slot-blue {
  border:
    3px solid
    #33d2ff;
  background:
    rgba(0,44,82,.56);
  box-shadow:
    0 0 15px
    rgba(0,190,255,.35);
}

.pokemon-slot-red {
  border:
    3px solid
    #ff4967;
  background:
    rgba(77,4,20,.58);
  box-shadow:
    0 0 15px
    rgba(255,34,65,.35);
}

.bench-slot {
  max-width:
    100px;
}

.empty-slot {
  width:
    100%;
  height:
    100%;
  display:
    flex;
  flex-direction:
    column;
  justify-content:
    center;
  align-items:
    center;
  gap:
    10px;
  color:
    rgba(255,255,255,.65);
  font-size:
    8px;
}

.pokeball-symbol {
  font-size:
    36px;
  opacity:
    .3;
}

.small-ball {
  font-size:
    28px;
  opacity:
    .3;
}

.pokemon-card {
  position:
    absolute;
  inset:
    4px;
  overflow:
    hidden;
  border-radius:
    6px;
  background:
    #101827;
  border:
    2px solid
    #ffe14f;
  cursor:
    pointer;
  z-index:
    6;
  transition:
    .2s ease;
}

.pokemon-card:hover {
  transform:
    translateY(-3px);
}

.pokemon-card.selected {
  border-color:
    white;
  transform:
    translateY(-4px)
    scale(1.035);
  box-shadow:
    0 0 23px
    white;
}

.pokemon-card.swap-target {
  border-color:
    #ffe552;
  animation:
    swapTargetPulse
    .65s alternate infinite;
}

@keyframes swapTargetPulse {
  from {
    box-shadow:
      0 0 8px
      #ffe552;
  }

  to {
    box-shadow:
      0 0 24px
      #ffe552;
  }
}

.pokemon-card-blue {
  box-shadow:
    0 0 18px
    rgba(0,202,255,.65);
}

.pokemon-card-red {
  box-shadow:
    0 0 18px
    rgba(255,44,71,.65);
}

.pokemon-card img {
  position:
    absolute;
  inset:
    0;
  width:
    100%;
  height:
    100%;
  object-fit:
    cover;
}

.pokemon-card-overlay {
  position:
    absolute;
  inset:
    0;
  background:
    linear-gradient(
      transparent 25%,
      rgba(0,0,0,.95)
    );
}

.pokemon-card-info {
  height:
    100%;
  position:
    relative;
  z-index:
    2;
  padding:
    7px;
  display:
    flex;
  flex-direction:
    column;
}

.card-top {
  display:
    flex;
  gap:
    3px;
}

.card-name {
  flex:
    1;
  min-width:
    0;
  overflow:
    hidden;
  white-space:
    nowrap;
  text-overflow:
    ellipsis;
  font-size:
    8px;
  font-weight:
    1000;
}

.element-pill {
  padding:
    2px 4px;
  border-radius:
    999px;
  background:
    rgba(0,0,0,.55);
  font-size:
    5px;
  text-transform:
    uppercase;
}

.card-hp {
  margin-top:
    3px;
  color:
    #ffe65d;
  font-size:
    6px;
  font-weight:
    900;
}

.card-attack {
  margin-top:
    auto;
  color:
    #bbc8dd;
  font-size:
    6px;
}

.card-attack strong {
  display:
    block;
  color:
    white;
  font-size:
    13px;
}

.move-bench-button {
  width:
    100%;
  margin-top:
    4px;
  padding:
    4px 2px;
  border:
    1px solid
    rgba(255,255,255,.3);
  border-radius:
    4px;
  background:
    rgba(2,9,20,.83);
  color:
    white;
  cursor:
    pointer;
  font-size:
    5px;
  font-weight:
    1000;
}

.move-bench-button:hover {
  border-color:
    #70ddff;
  background:
    rgba(15,100,158,.88);
}

.selected-card-label,
.swap-target-label {
  position:
    absolute;
  left:
    50%;
  transform:
    translateX(-50%);
  z-index:
    20;
  padding:
    2px 6px;
  border-radius:
    999px;
  font-size:
    5px;
  font-weight:
    1000;
  white-space:
    nowrap;
}

.selected-card-label {
  top:
    -9px;
  color:
    #07101e;
  background:
    white;
}

.swap-target-label {
  bottom:
    -9px;
  color:
    #171200;
  background:
    #ffe552;
}

.bench-card {
  position:
    absolute;
  inset:
    4px;
  overflow:
    hidden;
  border-radius:
    5px;
  background:
    #101827;
  transition:
    .2s ease;
}

.bench-card.swap-selected {
  border:
    2px solid
    #ffe34d;
  box-shadow:
    0 0 20px
    #ffe34d;
}

.bench-card img {
  position:
    absolute;
  inset:
    0;
  width:
    100%;
  height:
    100%;
  object-fit:
    cover;
}

.bench-overlay {
  position:
    absolute;
  inset:
    0;
  background:
    linear-gradient(
      transparent,
      rgba(0,0,0,.96)
    );
}

.bench-info {
  position:
    relative;
  z-index:
    2;
  height:
    100%;
  padding:
    6px;
  display:
    flex;
  flex-direction:
    column;
  justify-content:
    flex-end;
}

.bench-info strong {
  overflow:
    hidden;
  white-space:
    nowrap;
  text-overflow:
    ellipsis;
  font-size:
    7px;
}

.bench-info span {
  color:
    #ffe173;
  font-size:
    5px;
  text-transform:
    uppercase;
}

.return-button {
  margin-top:
    5px;
  padding:
    4px;
  border:
    none;
  border-radius:
    4px;
  background:
    #53d2ff;
  color:
    #04121e;
  cursor:
    pointer;
  font-size:
    6px;
  font-weight:
    1000;
}

.return-counter {
  margin-top:
    3px;
  color:
    rgba(255,255,255,.55);
  font-size:
    4.5px;
}

.bench-card.exhausted {
  filter:
    grayscale(1)
    brightness(.45);
}

.exhausted-label {
  margin-top:
    4px;
  padding:
    4px;
  text-align:
    center;
  border-radius:
    4px;
  color:
    #ff9aa9;
  background:
    rgba(100,0,20,.7);
  font-size:
    5px;
  font-weight:
    1000;
}

.exhausted-overlay {
  position:
    absolute;
  inset:
    0;
  z-index:
    20;
  display:
    flex;
  flex-direction:
    column;
  align-items:
    center;
  justify-content:
    center;
  gap:
    3px;
  background:
    rgba(8,8,12,.58);
  color:
    #ff879a;
  pointer-events:
    none;
}

.exhausted-overlay div {
  font-size:
    24px;
}

.exhausted-overlay strong {
  font-size:
    8px;
}

.exhausted-overlay small {
  font-size:
    5px;
}

@media (max-width: 1400px) {
  .pokemon-slot {
    max-width:
      97px;
  }

  .bench-slot {
    max-width:
      86px;
  }
}
</style>
