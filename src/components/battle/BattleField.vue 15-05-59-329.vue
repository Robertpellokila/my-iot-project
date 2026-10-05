<script setup>
import PlayerField from "./PlayerField.vue";

const props = defineProps({
  player1Active: {
    type: Array,
    default: () => [],
  },
  player2Active: {
    type: Array,
    default: () => [],
  },
  player1Bench: {
    type: Array,
    default: () => [],
  },
  player2Bench: {
    type: Array,
    default: () => [],
  },
  selectedCard: {
    type: Object,
    default: null,
  },
  currentTurn: {
    type: String,
    default: null,
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

const forward =
  eventName =>
  (...args) =>
    emit(eventName, ...args);
</script>

<template>
  <main class="battle-field">
    <div class="center-line"></div>

    <div class="center-orb">
      ◆
    </div>

    <PlayerField
      player="p1"
      :active-cards="player1Active"
      :bench-cards="player1Bench"
      :selected-card="selectedCard"
      :current-turn="currentTurn"
      :battle-state="battleState"
      :winner="winner"
      :selected-turn-action="selectedTurnAction"
      :is-acting="isActing"
      :summon-mode="summonMode"
      :swap-mode="swapMode"
      :interactive="interactive"
      @active-card-click="
        forward('active-card-click')(
          ...$event
        )
      "
      @move-to-bench="
        forward('move-to-bench')(
          ...$event
        )
      "
      @return-from-bench="
        forward('return-from-bench')(
          ...$event
        )
      "
    />

    <PlayerField
      player="p2"
      :active-cards="player2Active"
      :bench-cards="player2Bench"
      :selected-card="selectedCard"
      :current-turn="currentTurn"
      :battle-state="battleState"
      :winner="winner"
      :selected-turn-action="selectedTurnAction"
      :is-acting="isActing"
      :summon-mode="summonMode"
      :swap-mode="swapMode"
      :interactive="interactive"
      @active-card-click="
        forward('active-card-click')(
          ...$event
        )
      "
      @move-to-bench="
        forward('move-to-bench')(
          ...$event
        )
      "
      @return-from-bench="
        forward('return-from-bench')(
          ...$event
        )
      "
    />
  </main>
</template>

<style scoped>
.battle-field {
  min-height: 0;
  flex: 1;
  position: relative;
  display: grid;
  grid-template-columns:
    minmax(0, 1fr)
    minmax(0, 1fr);
  overflow: hidden;
  background: #020817;
}

.center-line {
  width: 1px;
  height: 100%;
  position: absolute;
  top: 0;
  left: 50%;
  z-index: 8;
  background:
    linear-gradient(
      transparent,
      rgba(86, 198, 255, .35),
      rgba(255, 82, 116, .35),
      transparent
    );
}

.center-orb {
  width: 30px;
  height: 30px;
  position: absolute;
  left: 50%;
  top: 50%;
  z-index: 9;
  display: grid;
  place-items: center;
  transform: translate(-50%, -50%) rotate(45deg);
  border: 1px solid rgba(112, 210, 255, .22);
  border-radius: 7px;
  color: #9cecff;
  background: #071326;
  box-shadow:
    0 0 24px rgba(70, 199, 255, .12);
}

.center-orb {
  font-size: 9px;
}

@media (max-width: 900px) {
  .battle-field {
    grid-template-columns: 1fr;
    overflow-y: auto;
  }

  .center-line,
  .center-orb {
    display: none;
  }
}
</style>
