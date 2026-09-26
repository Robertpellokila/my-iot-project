<script setup>

const props = defineProps({

  winner: {
    type: String,
    default: null,
  },

  player1Name: {
    type: String,
    default: "Player 1",
  },

  player2Name: {
    type: String,
    default: "Player 2",
  },

  showReset: {
    type: Boolean,
    default: true,
  },

});


const emit = defineEmits([
  "reset",
]);

</script>


<template>

  <Transition name="displayWinner">

    <div
      v-if="winner"
      class="displayWinner-overlay"
    >

      <div class="displayWinner-panel">

        <span>
          BATTLE FINISHED
        </span>


        <h2>

          {{
            winner === "p1"
              ? player1Name
              : winner === "p2"
                ? player2Name
                : "DRAW"
          }}

        </h2>


        <h1>

          {{
            winner === "draw"
              ? "DRAW!"
              : "WINS!"
          }}

        </h1>


        <button
          v-if="showReset"
          type="button"
          @click="
            emit('reset')
          "
        >
          PLAY AGAIN
        </button>

      </div>

    </div>

  </Transition>

</template>


<style scoped>

.displayWinner-overlay {
  position:
    absolute;

  inset:
    0;

  z-index:
    200;

  display:
    grid;

  place-items:
    center;

  background:
    rgba(
      0,
      0,
      0,
      .65
    );

  backdrop-filter:
    blur(
      6px
    );
}


.displayWinner-panel {
  min-width:
    330px;

  padding:
    34px
    45px;

  text-align:
    center;

  border-radius:
    20px;

  border:
    2px solid
    #ffdf46;

  background:
    linear-gradient(
      145deg,
      #101d38,
      #040817
    );
}


.displayWinner-panel span {
  color:
    #9dacbf;

  font-size:
    8px;

  font-weight:
    900;
}


.displayWinner-panel h2 {
  margin:
    8px
    0
    0;

  font-size:
    32px;
}


.displayWinner-panel h1 {
  margin:
    0;

  color:
    #ffe34d;

  font-size:
    44px;
}


.displayWinner-panel button {
  margin-top:
    20px;

  padding:
    9px
    25px;

  border:
    none;

  border-radius:
    7px;

  background:
    #ffe14b;

  color:
    #071020;

  cursor:
    pointer;

  font-size:
    9px;

  font-weight:
    1000;
}

</style>