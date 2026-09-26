<script setup>
defineProps({
  turnText: {
    type: String,
    default: "",
  },
  currentTurn: {
    type: String,
    default: "p1",
  },
  soundEnabled: {
    type: Boolean,
    default: true,
  },
  isFullscreen: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits([
  "toggle-sound",
  "toggle-fullscreen",
]);
</script>

<template>
  <section class="center-header">
    <div class="game-logo">
      <span class="logo-mini">
        CARD BATTLE
      </span>

      <strong>
        NEXUS
      </strong>

      <span class="logo-bottom">
        BATTLE ARENA
      </span>
    </div>

    <div
      class="turn-indicator"
      :class="{
        blue: currentTurn === 'p1',
        red: currentTurn === 'p2',
      }"
    >
      ● {{ turnText }}
    </div>

    <div class="header-game-controls">
      <button
        type="button"
        class="header-control-button"
        :title="
          soundEnabled
            ? 'Mute sound'
            : 'Enable sound'
        "
        @click="
          emit('toggle-sound')
        "
      >
        {{
          soundEnabled
            ? "🔊"
            : "🔇"
        }}
      </button>

      <button
        type="button"
        class="
          header-control-button
          fullscreen-button
        "
        @click="
          emit('toggle-fullscreen')
        "
      >
        {{
          isFullscreen
            ? "⛶ EXIT"
            : "⛶ FULL"
        }}
      </button>
    </div>
  </section>
</template>

<style scoped>
.center-header {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
}

.game-logo {
  text-align:
    center;
  line-height:
    .95;
}

.game-logo strong {
  display:
    block;
  font-size:
    27px;
  letter-spacing:
    .2em;
  background:
    linear-gradient(
      #fff,
      #9fc9ff
    );
  -webkit-background-clip:
    text;
  color:
    transparent;
}

.logo-mini {
  display:
    block;
  color:
    #ffd943;
  font-size:
    7px;
  font-weight:
    900;
  letter-spacing:
    .3em;
}

.logo-bottom {
  display:
    block;
  margin-top:
    5px;
  color:
    #92beef;
  font-size:
    8px;
  font-weight:
    800;
  letter-spacing:
    .35em;
}

.turn-indicator {
  min-width:
    200px;
  margin-top:
    11px;
  padding:
    6px 14px;
  text-align:
    center;
  border-radius:
    999px;
  border:
    1px solid
    #3a77ac;
  background:
    #071934;
  font-size:
    8px;
  font-weight:
    1000;
}

.turn-indicator.blue {
  color:
    #63ddff;
}

.turn-indicator.red {
  color:
    #ff8196;
}

.header-game-controls {
  display: flex;
  gap: 5px;
  margin-top: 6px;
}

.header-control-button {
  border: 1px solid rgba(120, 203, 255, .4);
  border-radius: 6px;
  padding: 4px 7px;
  color: #dff7ff;
  background: rgba(4, 20, 42, .85);
  cursor: pointer;
  font-size: 7px;
  font-weight: 900;
  transition: .2s ease;
}

.header-control-button:hover {
  border-color: #7ee7ff;
  background: rgba(17, 93, 145, .72);
  transform: translateY(-1px);
}

.fullscreen-button {
  min-width: 58px;
}
</style>
