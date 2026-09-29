<script setup>
import { computed } from "vue";

const props = defineProps({
  card: {
    type: Object,
    default: null,
  },

  player: {
    type: String,
    default: "p1",
    validator: (value) =>
      ["p1", "p2"].includes(value),
  },

  emptyLabel: {
    type: String,
    default: "EMPTY",
  },

  facing: {
    type: String,
    default: "right",
    validator: (value) =>
      ["left", "right"].includes(value),
  },

  large: {
    type: Boolean,
    default: true,
  },
});

/* =========================================================
   CARD DATA
========================================================= */

const cardName = computed(
  () =>
    props.card?.name ??
    props.card?.card_name ??
    "Unknown Card",
);

const cardElement = computed(() =>
  String(
    props.card?.element ??
      props.card?.type ??
      "neutral",
  ).toUpperCase(),
);

const imageUrl = computed(
  () =>
    props.card?.image_url ??
    props.card?.avatar_url ??
    props.card?.image ??
    "",
);

const attack = computed(() =>
  Math.max(
    0,
    Number(
      props.card?.attack ??
        0,
    ) || 0,
  ),
);

const defense = computed(() =>
  Math.max(
    0,
    Number(
      props.card?.defense ??
        0,
    ) || 0,
  ),
);

const currentHp = computed(() =>
  Math.max(
    0,
    Number(
      props.card?.current_hp ??
        props.card?.currentHp ??
        props.card?.hp ??
        0,
    ) || 0,
  ),
);

const baseHp = computed(() =>
  Math.max(
    1,
    Number(
      props.card?.base_hp ??
        props.card?.baseHp ??
        props.card?.hp ??
        currentHp.value ??
        1,
    ) || 1,
  ),
);

const hpPercent = computed(() =>
  Math.max(
    0,
    Math.min(
      100,
      (
        currentHp.value /
        Math.max(
          1,
          baseHp.value,
        )
      ) * 100,
    ),
  ),
);

const exhausted = computed(() =>
  Boolean(
    props.card?.exhausted,
  ),
);

const destroyed = computed(
  () =>
    props.card?.zone ===
      "graveyard" ||
    currentHp.value <= 0,
);

const isFusionResult =
  computed(() =>
    Boolean(
      props.card
        ?.is_fusion_result ??
        props.card
          ?.isFusionResult ??
        false,
    ),
  );
</script>

<template>
  <article
    class="battle-card"
    :class="[
      player,
      `face-${facing}`,
      {
        empty: !card,
        large,
        exhausted,
        destroyed,
        'fusion-result':
          isFusionResult,
      },
    ]"
  >
    <!-- ===================================================
         EMPTY SLOT
    ==================================================== -->

    <template v-if="!card">
      <div class="empty-content">
        <div class="empty-orb">
          ◉
        </div>

        <strong>
          {{ emptyLabel }}
        </strong>

        <span>
          ACTIVE SLOT
        </span>
      </div>
    </template>

    <!-- ===================================================
         CARD
    ==================================================== -->

    <template v-else>
      <div class="card-shell">

        <!-- IMAGE -->

        <div class="card-image">
          <img
            v-if="imageUrl"
            :src="imageUrl"
            :alt="cardName"
          />

          <div
            v-else
            class="image-placeholder"
          >
            ◉
          </div>

          <div class="image-shade"></div>

          <!-- ELEMENT -->

          <span class="element-badge">
            {{ cardElement }}
          </span>

          <!-- FUSION -->

          <span
            v-if="isFusionResult"
            class="fusion-badge"
          >
            🧬 FUSION
          </span>

          <!-- EXHAUSTED -->

          <span
            v-if="exhausted"
            class="
              status-badge
              exhausted-badge
            "
          >
            EXHAUSTED
          </span>

          <!-- DESTROYED -->

          <span
            v-if="destroyed"
            class="
              status-badge
              destroyed-badge
            "
          >
            DESTROYED
          </span>
        </div>

        <!-- INFO -->

        <section class="card-info">

          <!-- TITLE -->

          <header class="card-title">
            <span>
              ACTIVE CARD
            </span>

            <strong
              :title="cardName"
            >
              {{ cardName }}
            </strong>
          </header>

          <!-- HP -->

          <div class="hp-section">
            <div class="hp-heading">
              <span>
                CARD HP
              </span>

              <strong>
                {{ currentHp }}
                /
                {{ baseHp }}
              </strong>
            </div>

            <div class="hp-track">
              <div
                class="hp-fill"
                :style="{
                  width:
                    `${hpPercent}%`,
                }"
              ></div>
            </div>
          </div>

          <!-- STATS -->

          <div class="stat-grid">

            <div class="stat attack">
              <span>
                ATTACK
              </span>

              <strong>
                {{ attack }}
              </strong>
            </div>

            <div class="stat defense">
              <span>
                DEFENSE
              </span>

              <strong>
                {{ defense }}
              </strong>
            </div>
          </div>

          <!-- ATTACK DIRECTION -->

          <div class="attack-direction">

            <template
              v-if="
                facing === 'right'
              "
            >
              ATTACK

              <span>
                ›››
              </span>
            </template>

            <template v-else>
              <span>
                ‹‹‹
              </span>

              ATTACK
            </template>

          </div>
        </section>
      </div>
    </template>
  </article>
</template>

<style scoped>
* {
  box-sizing: border-box;
}

/* =========================================================
   ROOT
========================================================= */

.battle-card {
  /*
    PENTING:
    BattleCard tidak menentukan ukuran sendiri lagi.

    PublicActiveField sekarang menjadi parent
    yang menentukan width dan height.
  */
  width: 100%;
  height: 100%;

  min-width: 0;
  min-height: 0;

  position: relative;

  overflow: visible;

  color: #17324a;

  font-family:
    Inter,
    ui-sans-serif,
    system-ui,
    sans-serif;

  transition:
    transform 0.22s ease,
    filter 0.22s ease;

  /*
    Semua isi card sekarang bisa menggunakan
    cqw = ukuran relatif terhadap lebar card.
  */
  container-type:
    inline-size;

  container-name:
    battle-card;
}

/* =========================================================
   DIRECTION
========================================================= */

.battle-card.face-right {
  transform:
    translateX(2px)
    rotate(0.45deg);
}

.battle-card.face-left {
  transform:
    translateX(-2px)
    rotate(-0.45deg);
}

/* =========================================================
   SHELL
========================================================= */

.card-shell {
  width: 100%;
  height: 100%;

  min-width: 0;
  min-height: 0;

  display: grid;

  /*
    Gambar mengambil bagian terbesar.
    Info menyesuaikan sisa parent.
  */
  grid-template-rows:
    minmax(0, 1.42fr)
    minmax(0, 1fr);

  overflow: hidden;

  border:
    clamp(
      1px,
      1.4cqw,
      2px
    )
    solid
    #e5c857;

  border-radius:
    clamp(
      11px,
      10cqw,
      17px
    );

  background:
    #ffffff;

  box-shadow:
    0
    clamp(
      7px,
      8cqw,
      14px
    )
    clamp(
      15px,
      18cqw,
      30px
    )
    rgba(
      54,
      89,
      110,
      0.16
    ),
    inset
    0
    0
    0
    1px
    rgba(
      255,
      255,
      255,
      0.85
    );
}

.battle-card.p1
.card-shell {
  box-shadow:
    0
    clamp(
      7px,
      8cqw,
      14px
    )
    clamp(
      15px,
      18cqw,
      30px
    )
    rgba(
      36,
      156,
      215,
      0.17
    ),
    inset
    0
    0
    0
    1px
    rgba(
      255,
      255,
      255,
      0.9
    );
}

.battle-card.p2
.card-shell {
  box-shadow:
    0
    clamp(
      7px,
      8cqw,
      14px
    )
    clamp(
      15px,
      18cqw,
      30px
    )
    rgba(
      222,
      76,
      110,
      0.15
    ),
    inset
    0
    0
    0
    1px
    rgba(
      255,
      255,
      255,
      0.9
    );
}

/* =========================================================
   FUSION RESULT
========================================================= */

.battle-card.fusion-result
.card-shell {
  border-color:
    #d6a93b;

  box-shadow:
    0
    10px
    28px
    rgba(
      215,
      163,
      48,
      0.23
    ),
    0
    0
    0
    2px
    rgba(
      255,
      214,
      89,
      0.08
    );
}

/* =========================================================
   IMAGE
========================================================= */

.card-image {
  min-width: 0;
  min-height: 0;

  position: relative;

  overflow: hidden;

  background:
    linear-gradient(
      145deg,
      #edf7fb,
      #dbeaf1
    );
}

.card-image img {
  width: 100%;
  height: 100%;

  display: block;

  object-fit: cover;

  object-position:
    center center;
}

.image-placeholder {
  width: 100%;
  height: 100%;

  display: grid;

  place-items: center;

  color:
    rgba(
      60,
      115,
      145,
      0.36
    );

  font-size:
    clamp(
      32px,
      35cqw,
      60px
    );
}

.image-shade {
  position: absolute;

  inset: 0;

  background:
    linear-gradient(
      180deg,
      rgba(
        255,
        255,
        255,
        0
      )
      55%,

      rgba(
        15,
        42,
        59,
        0.28
      )
      100%
    );

  pointer-events: none;
}

/* =========================================================
   ELEMENT BADGE
========================================================= */

.element-badge {
  position: absolute;

  top:
    clamp(
      5px,
      5cqw,
      8px
    );

  right:
    clamp(
      5px,
      5cqw,
      8px
    );

  max-width:
    calc(
      100% -
      12px
    );

  padding:
    clamp(
      3px,
      2.5cqw,
      4px
    )
    clamp(
      5px,
      4.5cqw,
      7px
    );

  overflow: hidden;

  border:
    1px solid
    rgba(
      255,
      255,
      255,
      0.68
    );

  border-radius:
    999px;

  color: #244b64;

  background:
    rgba(
      255,
      255,
      255,
      0.92
    );

  box-shadow:
    0
    3px
    10px
    rgba(
      43,
      70,
      88,
      0.12
    );

  font-size:
    clamp(
      5px,
      4.6cqw,
      7px
    );

  font-weight: 950;

  line-height: 1;

  letter-spacing:
    0.05em;

  text-overflow:
    ellipsis;

  white-space:
    nowrap;

  backdrop-filter:
    blur(6px);
}

/* =========================================================
   FUSION BADGE
========================================================= */

.fusion-badge {
  position: absolute;

  left:
    clamp(
      5px,
      5cqw,
      8px
    );

  top:
    clamp(
      5px,
      5cqw,
      8px
    );

  padding:
    clamp(
      3px,
      2.4cqw,
      4px
    )
    clamp(
      5px,
      4cqw,
      7px
    );

  border:
    1px solid
    rgba(
      255,
      255,
      255,
      0.72
    );

  border-radius:
    999px;

  background:
    rgba(
      115,
      77,
      183,
      0.92
    );

  color:
    #ffffff;

  box-shadow:
    0
    4px
    12px
    rgba(
      79,
      48,
      137,
      0.22
    );

  font-size:
    clamp(
      4.5px,
      4.2cqw,
      6.5px
    );

  font-weight: 950;

  line-height: 1;

  letter-spacing:
    0.04em;

  white-space:
    nowrap;
}

/* =========================================================
   STATUS
========================================================= */

.status-badge {
  position: absolute;

  left:
    clamp(
      5px,
      5cqw,
      8px
    );

  bottom:
    clamp(
      5px,
      5cqw,
      8px
    );

  padding:
    clamp(
      3px,
      2.5cqw,
      4px
    )
    clamp(
      5px,
      4.5cqw,
      7px
    );

  border-radius:
    999px;

  color:
    #ffffff;

  font-size:
    clamp(
      5px,
      4.4cqw,
      7px
    );

  font-weight: 950;

  line-height: 1;

  letter-spacing:
    0.05em;
}

.exhausted-badge {
  background:
    rgba(
      109,
      116,
      128,
      0.92
    );
}

.destroyed-badge {
  background:
    rgba(
      198,
      49,
      77,
      0.94
    );
}

/* =========================================================
   CARD INFO
========================================================= */

.card-info {
  min-width: 0;
  min-height: 0;

  display: flex;

  flex-direction: column;

  padding:
    clamp(
      6px,
      5.5cqw,
      10px
    )
    clamp(
      6px,
      6cqw,
      11px
    )
    clamp(
      5px,
      5cqw,
      9px
    );

  background:
    linear-gradient(
      180deg,
      #ffffff,
      #f5fafc
    );
}

/* =========================================================
   TITLE
========================================================= */

.card-title {
  min-width: 0;

  margin-bottom:
    clamp(
      4px,
      4.5cqw,
      7px
    );
}

.card-title span {
  display: block;

  color:
    #8399a8;

  font-size:
    clamp(
      4.5px,
      4.2cqw,
      6px
    );

  font-weight: 900;

  line-height: 1;

  letter-spacing:
    0.08em;
}

.card-title strong {
  display:
    -webkit-box;

  margin-top:
    clamp(
      2px,
      1.8cqw,
      3px
    );

  overflow: hidden;

  color:
    #17324a;

  font-size:
    clamp(
      10px,
      9cqw,
      16px
    );

  font-weight: 950;

  line-height:
    1.05;

  /*
    PENTING:
    Nama panjang tidak lagi 1 baris.
  */
  white-space: normal;

  overflow-wrap:
    anywhere;

  -webkit-box-orient:
    vertical;

  -webkit-line-clamp:
    2;

  line-clamp:
    2;
}

/* =========================================================
   HP
========================================================= */

.hp-section {
  margin-bottom:
    clamp(
      4px,
      4.5cqw,
      7px
    );
}

.hp-heading {
  display: flex;

  align-items: center;

  justify-content:
    space-between;

  gap:
    clamp(
      3px,
      3cqw,
      5px
    );

  margin-bottom:
    clamp(
      3px,
      3cqw,
      4px
    );
}

.hp-heading span {
  color:
    #6e8799;

  font-size:
    clamp(
      4.5px,
      4.4cqw,
      6.5px
    );

  font-weight: 900;

  line-height: 1;
}

.hp-heading strong {
  flex-shrink: 0;

  color:
    #214760;

  font-size:
    clamp(
      6px,
      6cqw,
      9px
    );

  font-weight: 950;

  line-height: 1;
}

.hp-track {
  width: 100%;

  height:
    clamp(
      4px,
      4cqw,
      7px
    );

  overflow: hidden;

  border-radius:
    999px;

  background:
    #dce8ee;
}

.hp-fill {
  height: 100%;

  border-radius:
    inherit;

  background:
    linear-gradient(
      90deg,
      #42c981,
      #77dda5
    );

  transition:
    width 0.3s ease;
}

/* =========================================================
   STATS
========================================================= */

.stat-grid {
  display: grid;

  grid-template-columns:
    repeat(
      2,
      minmax(
        0,
        1fr
      )
    );

  gap:
    clamp(
      4px,
      4cqw,
      7px
    );

  margin-top: auto;
}

.stat {
  min-width: 0;

  padding:
    clamp(
      5px,
      4.5cqw,
      7px
    )
    clamp(
      5px,
      5cqw,
      8px
    );

  overflow: hidden;

  border-radius:
    clamp(
      6px,
      6cqw,
      9px
    );

  background:
    #edf5f8;
}

.stat span {
  display: block;

  overflow: hidden;

  color:
    #718a9b;

  font-size:
    clamp(
      4.5px,
      4.2cqw,
      6px
    );

  font-weight: 900;

  line-height: 1;

  letter-spacing:
    0.04em;

  text-overflow:
    ellipsis;

  white-space:
    nowrap;
}

.stat strong {
  display: block;

  margin-top:
    clamp(
      2px,
      2cqw,
      3px
    );

  overflow: hidden;

  color:
    #17324a;

  font-size:
    clamp(
      16px,
      17cqw,
      28px
    );

  font-weight: 1000;

  line-height:
    0.95;

  text-overflow:
    ellipsis;

  white-space:
    nowrap;
}

.stat.attack {
  border-left:
    clamp(
      2px,
      2cqw,
      3px
    )
    solid
    #e75970;
}

.stat.defense {
  border-left:
    clamp(
      2px,
      2cqw,
      3px
    )
    solid
    #399ad1;
}

/* =========================================================
   ATTACK DIRECTION
========================================================= */

.attack-direction {
  min-height:
    clamp(
      10px,
      9cqw,
      15px
    );

  display: flex;

  align-items: center;

  justify-content:
    center;

  gap:
    clamp(
      2px,
      2.5cqw,
      4px
    );

  margin-top:
    clamp(
      3px,
      3.5cqw,
      5px
    );

  color:
    #8095a5;

  font-size:
    clamp(
      4.5px,
      4.2cqw,
      6px
    );

  font-weight: 950;

  line-height: 1;

  letter-spacing:
    0.06em;
}

.battle-card.p1
.attack-direction span {
  color:
    #27a7df;
}

.battle-card.p2
.attack-direction span {
  color:
    #dc5572;
}

/* =========================================================
   EMPTY CARD
========================================================= */

.battle-card.empty {
  overflow: hidden;

  border:
    clamp(
      2px,
      2cqw,
      3px
    )
    solid
    rgba(
      50,
      158,
      209,
      0.34
    );

  border-radius:
    clamp(
      11px,
      10cqw,
      17px
    );

  background:
    rgba(
      255,
      255,
      255,
      0.28
    );

  box-shadow:
    inset
    0
    0
    0
    1px
    rgba(
      255,
      255,
      255,
      0.48
    );
}

.battle-card.empty.p2 {
  border-color:
    rgba(
      224,
      77,
      109,
      0.32
    );
}

.empty-content {
  width: 100%;
  height: 100%;

  display: flex;

  flex-direction: column;

  align-items: center;

  justify-content:
    center;

  gap:
    clamp(
      5px,
      5cqw,
      8px
    );

  color:
    #6b899e;
}

.empty-orb {
  width:
    clamp(
      34px,
      34cqw,
      52px
    );

  aspect-ratio:
    1 / 1;

  display: grid;

  place-items: center;

  border:
    clamp(
      2px,
      2.2cqw,
      3px
    )
    solid
    currentColor;

  border-radius:
    50%;

  opacity:
    0.30;

  font-size:
    clamp(
      17px,
      17cqw,
      26px
    );
}

.empty-content strong {
  font-size:
    clamp(
      6px,
      6cqw,
      9px
    );

  font-weight: 950;

  text-align:
    center;
}

.empty-content span {
  font-size:
    clamp(
      4.5px,
      4cqw,
      6px
    );

  font-weight: 850;

  letter-spacing:
    0.07em;

  opacity:
    0.75;
}

/* =========================================================
   STATES
========================================================= */

.battle-card.exhausted {
  filter:
    grayscale(0.5)
    saturate(0.7);

  opacity:
    0.72;
}

.battle-card.destroyed {
  filter:
    grayscale(0.9);

  opacity:
    0.5;
}

/* =========================================================
   VERY SMALL CARD
========================================================= */

@container battle-card (
  max-width: 118px
) {
  .card-shell {
    grid-template-rows:
      minmax(0, 1.35fr)
      minmax(0, 1fr);
  }

  .card-info {
    padding:
      6px
      7px
      5px;
  }

  .card-title {
    margin-bottom:
      4px;
  }

  .card-title strong {
    font-size:
      clamp(
        9px,
        9cqw,
        11px
      );
  }

  .hp-section {
    margin-bottom:
      4px;
  }

  .stat-grid {
    gap: 4px;
  }

  .stat {
    padding:
      5px;
  }

  .attack-direction {
    margin-top:
      3px;
  }

  .fusion-badge {
    font-size:
      4.5px;
  }
}

/* =========================================================
   MEDIUM / LARGE CARD
========================================================= */

@container battle-card (
  min-width: 150px
) {
  .card-shell {
    grid-template-rows:
      minmax(0, 1.5fr)
      minmax(0, 1fr);
  }

  .card-title strong {
    font-size:
      clamp(
        13px,
        8.5cqw,
        17px
      );
  }

  .stat strong {
    font-size:
      clamp(
        22px,
        16cqw,
        30px
      );
  }
}
</style>