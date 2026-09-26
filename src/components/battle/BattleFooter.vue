<script setup>
import PlayerActions from "./PlayerActions.vue";

defineProps({
  player1Hand: {
    type: Array,
    default: () => [],
  },
  player2Hand: {
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
  selectedSkill: {
    type: Object,
    default: null,
  },
  selectedTurnAction: {
    type: String,
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
  turnText: {
    type: String,
    default: "",
  },
  round: {
    type: Number,
    default: 1,
  },
  questionIntervalRounds: {
    type: Number,
    default: 5,
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
  player1UltimateUsed: {
    type: Boolean,
    default: false,
  },
  player2UltimateUsed: {
    type: Boolean,
    default: false,
  },
  player1HealUsed: {
    type: Boolean,
    default: false,
  },
  player2HealUsed: {
    type: Boolean,
    default: false,
  },
  player1CanUltimate: {
    type: Boolean,
    default: false,
  },
  player2CanUltimate: {
    type: Boolean,
    default: false,
  },
  player1CanHeal: {
    type: Boolean,
    default: false,
  },
  player2CanHeal: {
    type: Boolean,
    default: false,
  },
  player1Skill: {
    type: Number,
    default: 0,
  },
  player2Skill: {
    type: Number,
    default: 0,
  },
  player1CanSummon: {
    type: Boolean,
    default: false,
  },
  player2CanSummon: {
    type: Boolean,
    default: false,
  },
  player1ActiveCount: {
    type: Number,
    default: 0,
  },
  player2ActiveCount: {
    type: Number,
    default: 0,
  },
  player1SynergyInfo: {
    type: Object,
    default: null,
  },
  player2SynergyInfo: {
    type: Object,
    default: null,
  },
  canUseSkill: {
    type: Function,
    required: true,
  },
});

const emit = defineEmits([
  "play-skill",
  "play-synergy",
  "cancel-swap",
  "cancel-summon",
  "choose-summon",
]);
</script>

<template>
  <footer class="battle-footer">
    <PlayerActions
      player="p1"
      :hand="player1Hand"
      :selected-card="selectedCard"
      :selected-skill="selectedSkill"
      :current-turn="currentTurn"
      :battle-state="battleState"
      :ultimate-used="player1UltimateUsed"
      :heal-used="player1HealUsed"
      :can-ultimate="player1CanUltimate"
      :can-heal="player1CanHeal"
      :skill-gauge="player1Skill"
      :selected-turn-action="selectedTurnAction"
      :is-acting="isActing"
      :swap-mode="swapMode"
      :selected-synergy-info="player1SynergyInfo"
      :can-use-skill="canUseSkill"
      @play-skill="
        (...args) =>
          emit(
            'play-skill',
            ...args
          )
      "
      @play-synergy="
        (...args) =>
          emit(
            'play-synergy',
            ...args
          )
      "
    />

    <div class="turn-action-panel">
      <!-- INITIAL RFID -->
      <template
        v-if="
          battleState !==
          'battle_ready'
        "
      >
        <div class="scanner-symbol">
          📡
        </div>

        <strong>
          SCAN RFID
        </strong>

        <small>
          {{ turnText }}
        </small>
      </template>

      <!-- SWAP -->
      <template
        v-else-if="
          swapMode &&
          !winner
        "
      >
        <div class="swap-main-icon">
          ⇄
        </div>

        <strong>
          SELECT ACTIVE CARD
        </strong>

        <small>
          {{ selectedBenchCard?.name }}
          will replace it
        </small>

        <button
          type="button"
          class="cancel-summon"
          @click="
            emit('cancel-swap')
          "
        >
          CANCEL SWAP
        </button>
      </template>

      <!-- SUMMON -->
      <template
        v-else-if="
          summonMode &&
          !winner
        "
      >
        <div
          class="
            scanner-symbol
            scanner-active
          "
        >
          📡
        </div>

        <strong>
          SCAN CARD NOW
        </strong>

        <small>
          Summon consumes this turn
        </small>

        <button
          type="button"
          class="cancel-summon"
          @click="
            emit('cancel-summon')
          "
        >
          CANCEL
        </button>
      </template>

      <!-- NORMAL TURN -->
      <template
        v-else-if="
          !winner
        "
      >
        <div
          class="turn-badge"
          :class="
            currentTurn === 'p1'
              ? 'turn-blue'
              : 'turn-red'
          "
        >
          {{
            currentTurn === "p1"
              ? "P1"
              : "P2"
          }}
        </div>

        <strong>
          CHOOSE 1 ACTION
        </strong>

        <div class="round-indicator">
          ROUND {{ round }}

          <span>
            • QUESTION EVERY
            {{ questionIntervalRounds }}
          </span>
        </div>

        <small>
          Move / Return / Swap is free
        </small>

        <small>
          Then Skill / Synergy / Summon
        </small>

        <button
          type="button"
          class="summon-button"
          :class="
            currentTurn === 'p1'
              ? 'summon-blue'
              : 'summon-red'
          "
          :disabled="
            !!selectedTurnAction ||
            (
              currentTurn === 'p1'
                ? !player1CanSummon
                : !player2CanSummon
            )
          "
          @click="
            emit(
              'choose-summon',
              currentTurn
            )
          "
        >
          ✨ SUMMON

          <span>
            {{
              currentTurn === "p1"
                ? `${player1ActiveCount}/4`
                : `${player2ActiveCount}/4`
            }}
          </span>
        </button>
      </template>
    </div>

    <PlayerActions
      player="p2"
      :hand="player2Hand"
      :selected-card="selectedCard"
      :selected-skill="selectedSkill"
      :current-turn="currentTurn"
      :battle-state="battleState"
      :ultimate-used="player2UltimateUsed"
      :heal-used="player2HealUsed"
      :can-ultimate="player2CanUltimate"
      :can-heal="player2CanHeal"
      :skill-gauge="player2Skill"
      :selected-turn-action="selectedTurnAction"
      :is-acting="isActing"
      :swap-mode="swapMode"
      :selected-synergy-info="player2SynergyInfo"
      :can-use-skill="canUseSkill"
      @play-skill="
        (...args) =>
          emit(
            'play-skill',
            ...args
          )
      "
      @play-synergy="
        (...args) =>
          emit(
            'play-synergy',
            ...args
          )
      "
    />
  </footer>
</template>

<style scoped>
.battle-footer {
  height:
    205px;
  flex-shrink:
    0;
  display:
    grid;
  grid-template-columns:
    minmax(390px,1fr)
    230px
    minmax(390px,1fr);
  gap:
    12px;
  align-items:
    center;
  padding:
    10px 15px;
  position:
    relative;
  z-index:
    60;
  background:
    linear-gradient(
      #061328,
      #020713
    );
  border-top:
    2px solid
    rgba(70,174,255,.32);
}

.turn-action-panel {
  height:
    170px;
  display:
    flex;
  flex-direction:
    column;
  align-items:
    center;
  justify-content:
    center;
  gap:
    5px;
  padding:
    10px;
  text-align:
    center;
  border-radius:
    14px;
  border:
    2px dashed
    rgba(68,195,255,.65);
  background:
    radial-gradient(
      circle,
      rgba(0,92,150,.3),
      rgba(4,18,39,.82)
    );
}

.turn-action-panel strong {
  color:
    #8ce5ff;
  font-size:
    10px;
  font-weight:
    1000;
}

.turn-action-panel small {
  color:
    #8594ac;
  font-size:
    6px;
  text-transform:
    uppercase;
}

.turn-badge {
  width:
    39px;
  height:
    39px;
  display:
    grid;
  place-items:
    center;
  border-radius:
    50%;
  font-size:
    12px;
  font-weight:
    1000;
}

.turn-blue {
  border:
    2px solid
    #54dcff;
  background:
    #0767be;
}

.turn-red {
  border:
    2px solid
    #ff8296;
  background:
    #ad1231;
}

.scanner-symbol {
  font-size:
    27px;
}

.scanner-active {
  animation:
    scannerPulse
    .6s alternate infinite;
}

@keyframes scannerPulse {
  to {
    transform:
      scale(1.15);
  }
}

.swap-main-icon {
  font-size:
    34px;
  color:
    #ffe451;
}

.summon-button {
  width:
    135px;
  margin-top:
    5px;
  padding:
    7px 10px;
  display:
    flex;
  justify-content:
    space-between;
  border:
    none;
  border-radius:
    7px;
  color:
    white;
  cursor:
    pointer;
  font-size:
    8px;
  font-weight:
    1000;
}

.summon-blue {
  background:
    linear-gradient(
      90deg,
      #087cd4,
      #08bce0
    );
}

.summon-red {
  background:
    linear-gradient(
      90deg,
      #cc173d,
      #ff4c53
    );
}

.summon-button:disabled {
  opacity:
    .3;
  cursor:
    not-allowed;
}

.cancel-summon {
  margin-top:
    4px;
  padding:
    5px 14px;
  border:
    1px solid
    #ff6681;
  border-radius:
    5px;
  background:
    rgba(255,26,66,.12);
  color:
    #ff9aad;
  cursor:
    pointer;
  font-size:
    7px;
  font-weight:
    900;
}

.round-indicator {
  margin: 2px 0;
  color: #ffe867;
  font-size: 7px;
  font-weight: 1000;
}

.round-indicator span {
  color: #7f92ad;
  font-size: 5px;
}

@media (max-width: 1400px) {
  .battle-footer {
    grid-template-columns:
      minmax(330px,1fr)
      190px
      minmax(330px,1fr);
    height:
      195px;
  }
}
</style>
