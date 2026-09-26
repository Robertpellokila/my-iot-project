<script setup>
import {
  ref,
  watch,
  nextTick,
  onUnmounted,
} from "vue";

import PlayerField from "./PlayerField.vue";


// =========================================================
// PROPS
// =========================================================

const props =
  defineProps({

    player1Active: {
      type:
        Array,

      default:
        () => [],
    },

    player2Active: {
      type:
        Array,

      default:
        () => [],
    },

    player1Bench: {
      type:
        Array,

      default:
        () => [],
    },

    player2Bench: {
      type:
        Array,

      default:
        () => [],
    },

    selectedCard: {
      type:
        Object,

      default:
        null,
    },

    selectedBenchCard: {
      type:
        Object,

      default:
        null,
    },

    currentTurn: {
      type:
        String,

      default:
        "p1",
    },

    battleState: {
      type:
        String,

      default:
        "waiting_p1",
    },

    winner: {
      type:
        String,

      default:
        null,
    },

    selectedTurnAction: {
      type:
        String,

      default:
        null,
    },

    isActing: {
      type:
        Boolean,

      default:
        false,
    },

    summonMode: {
      type:
        Boolean,

      default:
        false,
    },

    swapMode: {
      type:
        Boolean,

      default:
        false,
    },

    interactive: {
      type:
        Boolean,

      default:
        true,
    },

    // =====================================================
    // REALTIME BATTLE EVENT
    //
    // Dipakai hanya untuk visual effect.
    // Tidak mengubah battle logic.
    // =====================================================

    latestBattleEvent: {
      type:
        Object,

      default:
        null,
    },

  });


// =========================================================
// EMITS
// =========================================================

const emit =
  defineEmits([
    "active-card-click",
    "move-to-bench",
    "return-from-bench",
  ]);


// =========================================================
// ARENA DOM
// =========================================================

const arenaRef =
  ref(null);


// =========================================================
// ATTACK FX
// =========================================================

const attackFx =
  ref({
    visible:
      false,

    key:
      0,

    player:
      null,

    image:
      "",

    name:
      "",

    x:
      0,

    y:
      0,

    width:
      150,

    height:
      150,

    rotate:
      0,

    scale:
      1,

    opacity:
      0,
  });


let attackTimer =
  null;

let impactTimer =
  null;


// =========================================================
// IMPACT FX
// =========================================================

const impactFx =
  ref({
    visible:
      false,

    key:
      0,

    x:
      0,

    y:
      0,

    player:
      null,
  });


// =========================================================
// CARD HELPERS
// =========================================================

const getCardKey =
  card => {

    if (
      !card
    ) {

      return null;

    }


    return (
      card.id
      ??
      card.battleId
      ??
      card.battle_id
      ??
      card.card_id
      ??
      card.uid
      ??
      null
    );

  };


const getCardImage =
  card => {

    if (
      !card
    ) {

      return "";

    }


    return (
      card.image_url
      ??
      card.image
      ??
      ""
    );

  };


const isImageUrl =
  value => {

    if (
      !value
    ) {

      return false;

    }


    const url =
      String(
        value
      );


    return (
      url.startsWith(
        "http://"
      )
      ||
      url.startsWith(
        "https://"
      )
      ||
      url.startsWith(
        "/"
      )
    );

  };


// =========================================================
// FIND ATTACK CARD
// =========================================================

const findAttackingCard =
  (
    player,
    cardId,
  ) => {

    const cards =
      player ===
        "p2"

        ? props.player2Active

        : props.player1Active;


    if (
      !cards?.length
    ) {

      return {
        card:
          null,

        index:
          -1,
      };

    }


    // =====================================================
    // TRY EXACT EVENT CARD ID
    // =====================================================

    if (
      cardId
    ) {

      const index =
        cards.findIndex(
          card => {

            const possibleIds = [
              card?.id,
              card?.battleId,
              card?.battle_id,
              card?.card_id,
              card?.uid,
            ]
              .filter(
                Boolean
              )
              .map(
                String
              );


            return possibleIds.includes(
              String(
                cardId
              )
            );

          }
        );


      if (
        index !==
        -1
      ) {

        return {
          card:
            cards[
              index
            ],

          index,
        };

      }

    }


    // =====================================================
    // FALLBACK
    //
    // Jika event lama belum mengirim card_id,
    // gunakan selected card bila cocok.
    // =====================================================

    if (
      props.selectedCard
    ) {

      const selectedKey =
        getCardKey(
          props.selectedCard
        );


      const index =
        cards.findIndex(
          card =>
            String(
              getCardKey(
                card
              )
            ) ===
            String(
              selectedKey
            )
        );


      if (
        index !==
        -1
      ) {

        return {
          card:
            cards[
              index
            ],

          index,
        };

      }

    }


    return {
      card:
        null,

      index:
        -1,
    };

  };


// =========================================================
// FIND SOURCE CARD DOM
//
// PlayerField.vue merender Active Card berurutan
// menggunakan .pokemon-card.
// Jadi index array = index DOM Active Card.
// =========================================================

const getSourceCardElement =
  (
    player,
    cardIndex,
  ) => {

    if (
      !arenaRef.value
      ||
      cardIndex <
        0
    ) {

      return null;

    }


    const fieldSelector =
      player ===
        "p2"

        ? ".field-red"

        : ".field-blue";


    const cards =
      arenaRef.value
        .querySelectorAll(
          `${fieldSelector} .pokemon-row .pokemon-card`
        );


    return (
      cards[
        cardIndex
      ]
      ??
      null
    );

  };


// =========================================================
// TARGET POSITION
//
// Serangan pada sistem battle kamu menyerang PLAYER,
// bukan kartu lawan tertentu.
//
// Karena itu target diarahkan ke tengah area Active Deck
// lawan, bukan ke salah satu Pokémon secara acak.
// =========================================================

const getTargetPosition =
  player => {

    if (
      !arenaRef.value
    ) {

      return null;

    }


    const arenaRect =
      arenaRef.value
        .getBoundingClientRect();


    const enemySelector =
      player ===
        "p1"

        ? ".field-red .pokemon-row"

        : ".field-blue .pokemon-row";


    const enemyRow =
      arenaRef.value
        .querySelector(
          enemySelector
        );


    if (
      enemyRow
    ) {

      const targetRect =
        enemyRow
          .getBoundingClientRect();


      return {
        x:
          targetRect.left
          -
          arenaRect.left
          +
          (
            targetRect.width /
            2
          ),

        y:
          targetRect.top
          -
          arenaRect.top
          +
          (
            targetRect.height /
            2
          ),
      };

    }


    // =====================================================
    // FALLBACK
    // =====================================================

    return {
      x:
        player ===
          "p1"

          ? arenaRect.width *
            0.75

          : arenaRect.width *
            0.25,

      y:
        arenaRect.height *
        0.30,
    };

  };


// =========================================================
// CLEAR ATTACK FX
// =========================================================

const clearAttackFx =
  () => {

    if (
      attackTimer
    ) {

      clearTimeout(
        attackTimer
      );

      attackTimer =
        null;

    }


    if (
      impactTimer
    ) {

      clearTimeout(
        impactTimer
      );

      impactTimer =
        null;

    }


    attackFx.value.visible =
      false;

    impactFx.value.visible =
      false;

  };


// =========================================================
// PLAY REALISTIC ATTACK
// =========================================================

const playAttackAnimation =
  async ({
    player,
    cardId,
    imageUrl,
  }) => {

    if (
      !player
      ||
      !arenaRef.value
    ) {

      return;

    }


    clearAttackFx();


    await nextTick();


    // =====================================================
    // FIND CARD
    // =====================================================

    const {
      card,
      index,
    } =
      findAttackingCard(
        player,
        cardId
      );


    if (
      !card
    ) {

      console.warn(
        "Attack FX: attacking card not found",
        {
          player,
          cardId,
        }
      );


      return;

    }


    // =====================================================
    // IMAGE
    // =====================================================

    const image =
      imageUrl
      ||
      getCardImage(
        card
      );


    if (
      !isImageUrl(
        image
      )
    ) {

      console.warn(
        "Attack FX: image_url tidak valid",
        {
          image,
          card,
        }
      );


      return;

    }


    // =====================================================
    // SOURCE ELEMENT
    // =====================================================

    const sourceElement =
      getSourceCardElement(
        player,
        index
      );


    if (
      !sourceElement
    ) {

      console.warn(
        "Attack FX: source card DOM tidak ditemukan",
        {
          player,
          index,
        }
      );


      return;

    }


    const sourceImageElement =
      sourceElement
        .querySelector(
          "img"
        );


    const sourceRect =
      (
        sourceImageElement
        ??
        sourceElement
      )
        .getBoundingClientRect();


    const arenaRect =
      arenaRef.value
        .getBoundingClientRect();


    // =====================================================
    // SOURCE CENTER
    // =====================================================

    const sourceX =
      sourceRect.left
      -
      arenaRect.left
      +
      (
        sourceRect.width /
        2
      );


    const sourceY =
      sourceRect.top
      -
      arenaRect.top
      +
      (
        sourceRect.height /
        2
      );


    // =====================================================
    // TARGET
    // =====================================================

    const target =
      getTargetPosition(
        player
      );


    if (
      !target
    ) {

      return;

    }


    // =====================================================
    // IMAGE SIZE
    // =====================================================

    const fxSize =
      Math.max(
        115,

        Math.min(
          190,
          sourceRect.width *
          1.18
        )
      );


    // =====================================================
    // START
    // =====================================================

    attackFx.value = {
      visible:
        true,

      key:
        attackFx.value.key +
        1,

      player,

      image,

      name:
        card.name
        ??
        "",

      x:
        sourceX,

      y:
        sourceY,

      width:
        fxSize,

      height:
        fxSize,

      rotate:
        player ===
          "p1"

          ? -4

          : 4,

      scale:
        0.72,

      opacity:
        0,
    };


    await nextTick();


    // =====================================================
    // PHASE 1
    //
    // Monster keluar sedikit dari kartunya.
    // =====================================================

    requestAnimationFrame(
      () => {

        attackFx.value = {
          ...attackFx.value,

          x:
            sourceX
            +
            (
              player ===
                "p1"

                ? 55

                : -55
            ),

          y:
            sourceY -
            22,

          rotate:
            player ===
              "p1"

              ? 4

              : -4,

          scale:
            1.02,

          opacity:
            1,
        };

      }
    );


    // =====================================================
    // PHASE 2
    //
    // Dash menuju sisi lawan dengan sedikit arc ke atas.
    // =====================================================

    attackTimer =
      setTimeout(
        () => {

          attackFx.value = {
            ...attackFx.value,

            x:
              target.x,

            y:
              target.y -
              28,

            rotate:
              player ===
                "p1"

                ? 10

                : -10,

            scale:
              1.18,

            opacity:
              1,
          };

        },
        120
      );


    // =====================================================
    // IMPACT
    // =====================================================

    impactTimer =
      setTimeout(
        () => {

          impactFx.value = {
            visible:
              true,

            key:
              impactFx.value.key +
              1,

            x:
              target.x,

            y:
              target.y,

            player:
              player ===
                "p1"

                ? "p2"

                : "p1",
          };


          attackFx.value = {
            ...attackFx.value,

            x:
              target.x
              +
              (
                player ===
                  "p1"

                  ? 50

                  : -50
              ),

            y:
              target.y,

            scale:
              0.88,

            opacity:
              0,
          };

        },
        540
      );


    // =====================================================
    // CLEAN UP
    // =====================================================

    setTimeout(
      () => {

        attackFx.value.visible =
          false;

        impactFx.value.visible =
          false;

      },
      820
    );

  };


// =========================================================
// WATCH REALTIME ATTACK EVENT
// =========================================================

watch(
  () =>
    props.latestBattleEvent,

  event => {

    if (
      !event
    ) {

      return;

    }


    const type =
      String(
        event.type
        ??
        ""
      )
        .trim()
        .toLowerCase();


    // =====================================================
    // BASIC ATTACK ONLY
    //
    // Ultimate / synergy tetap menggunakan effect lama.
    // =====================================================

    if (
      type !==
      "attack"
    ) {

      return;

    }


    const payload =
      event.payload
      ??
      {};


    const player =
      event.source_player
      ??
      payload.source_player
      ??
      null;


    const cardId =
      event.card_id
      ??
      payload.card_id
      ??
      payload.battle_card_id
      ??
      null;


    const imageUrl =
      payload.image_url
      ??
      payload.card_image
      ??
      null;


    if (
      player !==
        "p1"
      &&
      player !==
        "p2"
    ) {

      return;

    }


    void playAttackAnimation({
      player,
      cardId,
      imageUrl,
    });

  },
  {
    deep:
      true,
  }
);


// =========================================================
// CLEANUP
// =========================================================

onUnmounted(
  () => {

    clearAttackFx();

  }
);

</script>


<template>

  <main
    ref="arenaRef"
    class="arena"
  >

    <!-- ===================================================
         CENTER
    ==================================================== -->

    <div class="center-line" />


    <div class="center-orb">
      ◆
    </div>


    <!-- ===================================================
         PLAYER 1
    ==================================================== -->

    <PlayerField
      player="p1"

      :active-cards="
        player1Active
      "

      :bench-cards="
        player1Bench
      "

      :selected-card="
        selectedCard
      "

      :selected-bench-card="
        selectedBenchCard
      "

      :current-turn="
        currentTurn
      "

      :battle-state="
        battleState
      "

      :winner="
        winner
      "

      :selected-turn-action="
        selectedTurnAction
      "

      :is-acting="
        isActing
      "

      :summon-mode="
        summonMode
      "

      :swap-mode="
        swapMode
      "

      :interactive="
        interactive
      "

      @active-card-click="
        (...args) =>
          emit(
            'active-card-click',
            ...args
          )
      "

      @move-to-bench="
        (...args) =>
          emit(
            'move-to-bench',
            ...args
          )
      "

      @return-from-bench="
        (...args) =>
          emit(
            'return-from-bench',
            ...args
          )
      "
    />


    <!-- ===================================================
         PLAYER 2
    ==================================================== -->

    <PlayerField
      player="p2"

      :active-cards="
        player2Active
      "

      :bench-cards="
        player2Bench
      "

      :selected-card="
        selectedCard
      "

      :selected-bench-card="
        selectedBenchCard
      "

      :current-turn="
        currentTurn
      "

      :battle-state="
        battleState
      "

      :winner="
        winner
      "

      :selected-turn-action="
        selectedTurnAction
      "

      :is-acting="
        isActing
      "

      :summon-mode="
        summonMode
      "

      :swap-mode="
        swapMode
      "

      :interactive="
        interactive
      "

      @active-card-click="
        (...args) =>
          emit(
            'active-card-click',
            ...args
          )
      "

      @move-to-bench="
        (...args) =>
          emit(
            'move-to-bench',
            ...args
          )
      "

      @return-from-bench="
        (...args) =>
          emit(
            'return-from-bench',
            ...args
          )
      "
    />


    <!-- ===================================================
         ATTACK IMAGE FX
         
         HANYA gambar monster/card artwork.
         Tidak ada border/frame kartu.
    ==================================================== -->

    <div
      class="attack-fx-layer"
      aria-hidden="true"
    >

      <img
        v-if="
          attackFx.visible &&
          attackFx.image
        "

        :key="
          attackFx.key
        "

        :src="
          attackFx.image
        "

        :alt="
          attackFx.name
        "

        class="attack-monster-image"

        :class="{
          'attack-from-p1':
            attackFx.player ===
            'p1',

          'attack-from-p2':
            attackFx.player ===
            'p2',
        }"

        :style="{
          width:
            `${attackFx.width}px`,

          height:
            `${attackFx.height}px`,

          left:
            `${attackFx.x}px`,

          top:
            `${attackFx.y}px`,

          opacity:
            attackFx.opacity,

          transform:
            `
              translate(-50%, -50%)
              scale(${attackFx.scale})
              rotate(${attackFx.rotate}deg)
            `,
        }"
      />


      <!-- ===============================================
           IMPACT
      ================================================ -->

      <div
        v-if="
          impactFx.visible
        "

        :key="
          impactFx.key
        "

        class="attack-impact"

        :class="
          impactFx.player ===
            'p1'

            ? 'impact-blue'

            : 'impact-red'
        "

        :style="{
          left:
            `${impactFx.x}px`,

          top:
            `${impactFx.y}px`,
        }"
      >

        <span />

        <span />

        <span />

      </div>

    </div>


    <!-- ===================================================
         ORIGINAL SLOT
    ==================================================== -->

    <slot />

  </main>

</template>


<style scoped>

/* =========================================================
   ARENA
========================================================= */

.arena {
  flex:
    1;

  min-height:
    0;

  display:
    flex;

  position:
    relative;

  overflow:
    hidden;
}


/* =========================================================
   CENTER LINE
========================================================= */

.center-line {
  width:
    6px;

  position:
    absolute;

  left:
    50%;

  top:
    0;

  bottom:
    0;

  z-index:
    30;

  transform:
    translateX(
      -50%
    );

  background:
    linear-gradient(
      #30c8ff,
      white,
      #ff3d60
    );

  box-shadow:
    -8px
    0
    20px
    #009dff,

    8px
    0
    20px
    #ff244d;
}


/* =========================================================
   CENTER ORB
========================================================= */

.center-orb {
  width:
    70px;

  height:
    70px;

  position:
    absolute;

  left:
    50%;

  top:
    50%;

  z-index:
    35;

  transform:
    translate(
      -50%,
      -50%
    );

  display:
    grid;

  place-items:
    center;

  border-radius:
    50%;

  border:
    4px solid
    white;

  background:
    linear-gradient(
      90deg,
      #075cb6 50%,
      #b21131 50%
    );

  font-size:
    20px;
}


/* =========================================================
   ATTACK FX LAYER
========================================================= */

.attack-fx-layer {
  position:
    absolute;

  inset:
    0;

  z-index:
    100;

  overflow:
    hidden;

  pointer-events:
    none;
}


/* =========================================================
   MONSTER IMAGE
========================================================= */

.attack-monster-image {
  position:
    absolute;

  z-index:
    105;

  object-fit:
    contain;

  pointer-events:
    none;

  user-select:
    none;

  will-change:
    left,
    top,
    transform,
    opacity;

  transition:
    left
      420ms
      cubic-bezier(
        .18,
        .82,
        .22,
        1
      ),

    top
      420ms
      cubic-bezier(
        .18,
        .82,
        .22,
        1
      ),

    transform
      420ms
      cubic-bezier(
        .18,
        .82,
        .22,
        1
      ),

    opacity
      150ms
      ease;

  filter:
    drop-shadow(
      0
      10px
      12px
      rgba(
        0,
        0,
        0,
        .48
      )
    )

    drop-shadow(
      0
      0
      16px
      rgba(
        255,
        255,
        255,
        .23
      )
    );
}


/* =========================================================
   P1 ATTACK GLOW
========================================================= */

.attack-monster-image.attack-from-p1 {
  filter:
    drop-shadow(
      0
      10px
      12px
      rgba(
        0,
        0,
        0,
        .5
      )
    )

    drop-shadow(
      0
      0
      18px
      rgba(
        32,
        199,
        255,
        .85
      )
    );
}


/* =========================================================
   P2 ATTACK GLOW
========================================================= */

.attack-monster-image.attack-from-p2 {
  filter:
    drop-shadow(
      0
      10px
      12px
      rgba(
        0,
        0,
        0,
        .5
      )
    )

    drop-shadow(
      0
      0
      18px
      rgba(
        255,
        61,
        96,
        .85
      )
    );
}


/* =========================================================
   IMPACT
========================================================= */

.attack-impact {
  width:
    90px;

  height:
    90px;

  position:
    absolute;

  z-index:
    104;

  transform:
    translate(
      -50%,
      -50%
    );

  display:
    grid;

  place-items:
    center;

  border:
    3px solid
    rgba(
      255,
      255,
      255,
      .92
    );

  border-radius:
    50%;

  animation:
    impactBurst
    300ms
    ease-out
    forwards;
}


.attack-impact::before {
  content:
    "";

  width:
    32px;

  height:
    32px;

  border-radius:
    50%;

  background:
    white;

  box-shadow:
    0
    0
    30px
    white;

  animation:
    impactCore
    300ms
    ease-out
    forwards;
}


.attack-impact span {
  width:
    115px;

  height:
    3px;

  position:
    absolute;

  border-radius:
    50%;

  background:
    white;
}


.attack-impact span:nth-child(1) {
  transform:
    rotate(
      0deg
    );
}


.attack-impact span:nth-child(2) {
  transform:
    rotate(
      60deg
    );
}


.attack-impact span:nth-child(3) {
  transform:
    rotate(
      -60deg
    );
}


/* =========================================================
   BLUE IMPACT
========================================================= */

.impact-blue {
  box-shadow:
    0
    0
    38px
    rgba(
      32,
      199,
      255,
      .95
    );

  border-color:
    #49d8ff;
}


/* =========================================================
   RED IMPACT
========================================================= */

.impact-red {
  box-shadow:
    0
    0
    38px
    rgba(
      255,
      61,
      96,
      .95
    );

  border-color:
    #ff5575;
}


/* =========================================================
   IMPACT ANIMATION
========================================================= */

@keyframes impactBurst {

  0% {
    opacity:
      1;

    transform:
      translate(
        -50%,
        -50%
      )
      scale(
        .25
      );
  }


  60% {
    opacity:
      1;

    transform:
      translate(
        -50%,
        -50%
      )
      scale(
        1.15
      );
  }


  100% {
    opacity:
      0;

    transform:
      translate(
        -50%,
        -50%
      )
      scale(
        1.55
      );
  }

}


@keyframes impactCore {

  from {
    opacity:
      1;

    transform:
      scale(
        .2
      );
  }


  to {
    opacity:
      0;

    transform:
      scale(
        2.1
      );
  }

}


/* =========================================================
   REDUCED MOTION
========================================================= */

@media (
  prefers-reduced-motion:
  reduce
) {

  .attack-monster-image {
    transition:
      opacity
      150ms
      ease;
  }


  .attack-impact {
    animation:
      none;
  }

}

</style>