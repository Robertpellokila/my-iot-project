<script setup>
import {
  computed,
  nextTick,
  onMounted,
  onUpdated,
  ref,
} from "vue";

import BattleCard from "./BattleCard.vue";

const props = defineProps({
  battle: {
    type: Object,
    required: true,
  },

  player1Active: {
    type: Array,
    default: () => [],
  },

  player2Active: {
    type: Array,
    default: () => [],
  },

  player1BenchCount: {
    type: Number,
    default: 0,
  },

  player2BenchCount: {
    type: Number,
    default: 0,
  },

  combatFx: {
    type: Object,

    default: () => ({
      active: false,

      attackMode: null,

      phase: "idle",

      sourcePlayer: null,

      targetPlayer: null,

      attackerCardId: null,

      targetCardId: null,

      destroyed: false,

      powerStrikeApplied: false,

      attackDebuffApplied: false,

      attackDebuffPercent: 0,

      defenseApplied: false,

      waterShieldApplied: false,

      waterShieldPercent: 0,
    }),
  },
});

/* =========================================================
   HELPERS
========================================================= */

const getCardId = (card) =>
  card?.battleId ??
  card?.battle_id ??
  card?.id ??
  null;

const clampRatio = (value) =>
  Math.max(
    0,
    Math.min(
      1,
      Number(value) || 0,
    ),
  );

const ratioPercent = (value) =>
  Math.round(
    clampRatio(value) * 100,
  );

/* =========================================================
   DOM REFERENCES
========================================================= */

const p1HudRef = ref(null);
const p2HudRef = ref(null);

const p1AvatarRef = ref(null);
const p2AvatarRef = ref(null);

const p1FieldRef = ref(null);
const p2FieldRef = ref(null);

const cardElements =
  new Map();

const cardRectCache =
  new Map();

const rectToPlainObject = (
  rect,
) => {
  if (!rect) {
    return null;
  }

  return {
    left: rect.left,

    top: rect.top,

    right: rect.right,

    bottom: rect.bottom,

    width: rect.width,

    height: rect.height,

    x: rect.x,

    y: rect.y,

    centerX:
      rect.left +
      rect.width / 2,

    centerY:
      rect.top +
      rect.height / 2,
  };
};

const cardElementKey = (
  player,
  cardId,
) =>
  `${player}:${String(
    cardId,
  )}`;

const registerCardElement = (
  player,
  card,
  element,
) => {
  const cardId =
    getCardId(card);

  if (!cardId) {
    return;
  }

  const key =
    cardElementKey(
      player,
      cardId,
    );

  if (!element) {
    cardElements.delete(
      key,
    );

    return;
  }

  cardElements.set(
    key,
    element,
  );

  const rect =
    element.getBoundingClientRect();

  if (
    rect.width > 0 &&
    rect.height > 0
  ) {
    cardRectCache.set(
      key,

      rectToPlainObject(
        rect,
      ),
    );
  }
};

const captureCardRects =
  () => {
    for (
      const [
        key,
        element,
      ]
      of cardElements.entries()
    ) {
      if (
        !element ||
        typeof element
          .getBoundingClientRect !==
          "function"
      ) {
        continue;
      }

      const rect =
        element.getBoundingClientRect();

      if (
        rect.width <= 0 ||
        rect.height <= 0
      ) {
        continue;
      }

      cardRectCache.set(
        key,

        rectToPlainObject(
          rect,
        ),
      );
    }
  };

const getCardRect = (
  player,
  cardId,
) => {
  if (
    !player ||
    !cardId
  ) {
    return null;
  }

  const key =
    cardElementKey(
      player,
      cardId,
    );

  const element =
    cardElements.get(
      key,
    );

  if (
    element &&
    typeof element
      .getBoundingClientRect ===
      "function"
  ) {
    const rect =
      element.getBoundingClientRect();

    if (
      rect.width > 0 &&
      rect.height > 0
    ) {
      const plain =
        rectToPlainObject(
          rect,
        );

      cardRectCache.set(
        key,
        plain,
      );

      return plain;
    }
  }

  return (
    cardRectCache.get(
      key,
    ) ??
    null
  );
};

const getPlayerTargetRect =
  (player) => {
    const avatar =
      player === "p1"
        ? p1AvatarRef.value
        : p2AvatarRef.value;

    if (
      avatar &&
      typeof avatar
        .getBoundingClientRect ===
        "function"
    ) {
      return rectToPlainObject(
        avatar.getBoundingClientRect(),
      );
    }

    const hud =
      player === "p1"
        ? p1HudRef.value
        : p2HudRef.value;

    if (
      hud &&
      typeof hud
        .getBoundingClientRect ===
        "function"
    ) {
      return rectToPlainObject(
        hud.getBoundingClientRect(),
      );
    }

    return null;
  };

defineExpose({
  captureCardRects,

  getCardRect,

  getPlayerTargetRect,
});

/* =========================================================
   BATTLE CONFIG
========================================================= */

const maxActive =
  computed(() =>
    Math.max(
      1,

      Number(
        props.battle
          ?.max_active ??
          4,
      ) || 4,
    ),
  );

const maxBench =
  computed(() =>
    Math.max(
      0,

      Number(
        props.battle
          ?.max_bench ??
          4,
      ) || 4,
    ),
  );

/* =========================================================
   ACTIVE SLOTS
========================================================= */

const player1Slots =
  computed(() =>
    Array.from(
      {
        length:
          maxActive.value,
      },

      (_, index) =>
        props.player1Active[
          index
        ] ?? null,
    ),
  );

const player2Slots =
  computed(() =>
    Array.from(
      {
        length:
          maxActive.value,
      },

      (_, index) =>
        props.player2Active[
          index
        ] ?? null,
    ),
  );

/* =========================================================
   FORMATION
========================================================= */

const formationColumns =
  computed(() => {
    const count =
      maxActive.value;

    if (count <= 2) {
      return 1;
    }

    if (count <= 4) {
      return 2;
    }

    if (count <= 6) {
      return 3;
    }

    if (count <= 8) {
      return 4;
    }

    return Math.ceil(
      Math.sqrt(count),
    );
  });

const formationRows =
  computed(() =>
    Math.ceil(
      maxActive.value /
        formationColumns.value,
    ),
  );

const formationClass =
  computed(
    () =>
      `formation-${Math.min(
        maxActive.value,
        8,
      )}`,
  );

const formationStyle =
  computed(() => ({
    "--formation-columns":
      formationColumns.value,

    "--formation-rows":
      formationRows.value,
  }));

/* =========================================================
   PLAYER INFO
========================================================= */

const p1Name =
  computed(
    () =>
      props.battle
        ?.player1_name ??
      "Player 1",
  );

const p2Name =
  computed(
    () =>
      props.battle
        ?.player2_name ??
      "Player 2",
  );

/* =========================================================
   HP
========================================================= */

const p1Hp =
  computed(() =>
    Number(
      props.battle
        ?.player1_hp ??
        0,
    ) || 0,
  );

const p2Hp =
  computed(() =>
    Number(
      props.battle
        ?.player2_hp ??
        0,
    ) || 0,
  );

const p1MaxHp =
  computed(() =>
    Math.max(
      1,

      Number(
        props.battle
          ?.player1_max_hp ??
          props.battle
            ?.player_starting_hp ??
          200,
      ) || 200,
    ),
  );

const p2MaxHp =
  computed(() =>
    Math.max(
      1,

      Number(
        props.battle
          ?.player2_max_hp ??
          props.battle
            ?.player_starting_hp ??
          200,
      ) || 200,
    ),
  );

const p1HpPercent =
  computed(() =>
    Math.max(
      0,

      Math.min(
        100,

        (
          p1Hp.value /
          p1MaxHp.value
        ) * 100,
      ),
    ),
  );

const p2HpPercent =
  computed(() =>
    Math.max(
      0,

      Math.min(
        100,

        (
          p2Hp.value /
          p2MaxHp.value
        ) * 100,
      ),
    ),
  );

/* =========================================================
   ULTIMATE
========================================================= */

const p1Skill =
  computed(() =>
    Math.max(
      0,

      Math.min(
        100,

        Number(
          props.battle
            ?.player1_skill ??
            0,
        ) || 0,
      ),
    ),
  );

const p2Skill =
  computed(() =>
    Math.max(
      0,

      Math.min(
        100,

        Number(
          props.battle
            ?.player2_skill ??
            0,
        ) || 0,
      ),
    ),
  );

/* =========================================================
   PERSISTENT MODIFIER STATE
========================================================= */

const p1PowerStrikeReady =
  computed(() =>
    Boolean(
      props.battle
        ?.player1_power_strike_ready,
    ),
  );

const p2PowerStrikeReady =
  computed(() =>
    Boolean(
      props.battle
        ?.player2_power_strike_ready,
    ),
  );

const p1Defending =
  computed(() =>
    Boolean(
      props.battle
        ?.player1_defending,
    ),
  );

const p2Defending =
  computed(() =>
    Boolean(
      props.battle
        ?.player2_defending,
    ),
  );

const p1WaterShieldPercent =
  computed(() =>
    ratioPercent(
      props.battle
        ?.player1_synergy_shield,
    ),
  );

const p2WaterShieldPercent =
  computed(() =>
    ratioPercent(
      props.battle
        ?.player2_synergy_shield,
    ),
  );

const p1AttackDebuffPercent =
  computed(() =>
    ratioPercent(
      props.battle
        ?.player1_attack_debuff,
    ),
  );

const p2AttackDebuffPercent =
  computed(() =>
    ratioPercent(
      props.battle
        ?.player2_attack_debuff,
    ),
  );

/* =========================================================
   STATUS ITEMS
========================================================= */

const buildStatusItems = (
  player,
) => {
  const items = [];

  const powerStrike =
    player === "p1"
      ? p1PowerStrikeReady.value
      : p2PowerStrikeReady.value;

  const defending =
    player === "p1"
      ? p1Defending.value
      : p2Defending.value;

  const shieldPercent =
    player === "p1"
      ? p1WaterShieldPercent.value
      : p2WaterShieldPercent.value;

  const debuffPercent =
    player === "p1"
      ? p1AttackDebuffPercent.value
      : p2AttackDebuffPercent.value;

  if (powerStrike) {
    items.push({
      type:
        "power",

      icon:
        "⚡",

      title:
        "POWER STRIKE READY",

      detail:
        "NEXT ATTACK ×1.50 DAMAGE (+50%)",
    });
  }

  if (defending) {
    items.push({
      type:
        "defense",

      icon:
        "🛡",

      title:
        "DEFENSE ACTIVE",

      detail:
        "NEXT INCOMING DAMAGE ×0.50 (-50%)",
    });
  }

  if (
    shieldPercent >
    0
  ) {
    items.push({
      type:
        "water",

      icon:
        "💧",

      title:
        "WATER SHIELD",

      detail:
        `NEXT INCOMING DAMAGE -${shieldPercent}%`,
    });
  }

  if (
    debuffPercent >
    0
  ) {
    items.push({
      type:
        "debuff",

      icon:
        "❄",

      title:
        "ATTACK DEBUFF",

      detail:
        `NEXT ATTACK DAMAGE -${debuffPercent}%`,
    });
  }

  return items;
};

const p1StatusItems =
  computed(() =>
    buildStatusItems(
      "p1",
    ),
  );

const p2StatusItems =
  computed(() =>
    buildStatusItems(
      "p2",
    ),
  );

/* =========================================================
   COMBAT HELPERS
========================================================= */

const combatCardMatches = (
  card,
  id,
) => {
  if (
    !card ||
    !id
  ) {
    return false;
  }

  return (
    String(
      getCardId(card),
    ) ===
    String(id)
  );
};

const getCombatSlotClasses = (
  player,
  card,
) => {
  if (
    !props.combatFx
      ?.active ||
    !card
  ) {
    return {};
  }

  const attacker =
    player ===
      props.combatFx
        .sourcePlayer &&
    combatCardMatches(
      card,

      props.combatFx
        .attackerCardId,
    );

  const target =
    player ===
      props.combatFx
        .targetPlayer &&
    combatCardMatches(
      card,

      props.combatFx
        .targetCardId,
    );

  return {
    "combat-attacker-slot":
      attacker,

    "combat-target-slot":
      target,

    "combat-charge":
      attacker &&
      props.combatFx
        .phase ===
        "charge",

    "combat-power-strike":
      attacker &&
      props.combatFx
        .powerStrikeApplied,

    "combat-attack-debuff":
      attacker &&
      props.combatFx
        .attackDebuffApplied,

    "combat-defense-target":
      target &&
      props.combatFx
        .defenseApplied,

    "combat-water-target":
      target &&
      props.combatFx
        .waterShieldApplied,

    "combat-impact":
      target &&
      props.combatFx
        .phase ===
        "impact",

    "combat-damaged":
      target &&
      [
        "result",
        "destroyed",
      ].includes(
        props.combatFx
          .phase,
      ),

    "combat-destroyed":
      target &&
      props.combatFx
        .destroyed &&
      [
        "destroyed",
        "exit",
      ].includes(
        props.combatFx
          .phase,
      ),
  };
};

/* =========================================================
   BARRIERS
========================================================= */

const showDefenseBarrier = (
  player,
) => {
  const persistent =
    player === "p1"
      ? p1Defending.value
      : p2Defending.value;

  const combat =
    props.combatFx
      ?.active &&
    props.combatFx
      ?.targetPlayer ===
      player &&
    props.combatFx
      ?.defenseApplied;

  return (
    persistent ||
    combat
  );
};

const showWaterBarrier = (
  player,
) => {
  const persistent =
    player === "p1"
      ? p1WaterShieldPercent.value >
        0
      : p2WaterShieldPercent.value >
        0;

  const combat =
    props.combatFx
      ?.active &&
    props.combatFx
      ?.targetPlayer ===
      player &&
    props.combatFx
      ?.waterShieldApplied;

  return (
    persistent ||
    combat
  );
};

const defenseBreaking = (
  player,
) =>
  props.combatFx
    ?.active &&
  props.combatFx
    ?.targetPlayer ===
    player &&
  props.combatFx
    ?.defenseApplied &&
  props.combatFx
    ?.phase ===
    "impact";

const waterBreaking = (
  player,
) =>
  props.combatFx
    ?.active &&
  props.combatFx
    ?.targetPlayer ===
    player &&
  props.combatFx
    ?.waterShieldApplied &&
  props.combatFx
    ?.phase ===
    "impact";

/* =========================================================
   TURN
========================================================= */

const currentTurn =
  computed(
    () =>
      props.battle
        ?.current_turn ??
      "p1",
  );

const turnText =
  computed(() => {
    if (
      props.battle
        ?.winner
    ) {
      if (
        props.battle
          .winner ===
        "draw"
      ) {
        return "BATTLE DRAW";
      }

      return `${
        props.battle
          .winner ===
        "p1"
          ? p1Name.value
          : p2Name.value
      } WINS`;
    }

    if (
      props.battle
        ?.status ===
      "question"
    ) {
      return "CODING CHALLENGE";
    }

    return (
      currentTurn.value ===
      "p2"
        ? `${p2Name.value} TURN`
        : `${p1Name.value} TURN`
    );
  });

/* =========================================================
   AVATAR
========================================================= */

const p1Avatar =
  computed(
    () =>
      props.battle
        ?.player1_avatar_url ??
      "",
  );

const p2Avatar =
  computed(
    () =>
      props.battle
        ?.player2_avatar_url ??
      "",
  );

/* =========================================================
   POSITION CAPTURE
========================================================= */

const scheduleCapture =
  async () => {
    await nextTick();

    requestAnimationFrame(
      () => {
        captureCardRects();
      },
    );
  };

onMounted(() => {
  void scheduleCapture();
});

onUpdated(() => {
  void scheduleCapture();
});
</script>

<template>
  <section class="public-active-field">

    <!-- ===================================================
         HEADER
    ==================================================== -->

    <header class="battle-header">

      <!-- PLAYER 1 -->

      <section
        ref="p1HudRef"
        class="player-hud p1"
        :class="{
          current:
            currentTurn ===
            'p1',

          'defense-active':
            p1Defending,

          'water-active':
            p1WaterShieldPercent >
            0,

          'debuff-active':
            p1AttackDebuffPercent >
            0,

          'power-active':
            p1PowerStrikeReady,
        }"
      >
        <div
          ref="p1AvatarRef"
          class="avatar blue"
        >
          <img
            v-if="p1Avatar"
            :src="p1Avatar"
            :alt="p1Name"
          />

          <span v-else>
            👦🏻
          </span>
        </div>

        <div class="player-info">

          <div class="player-name-row">
            <div>
              <span>
                PLAYER 1
              </span>

              <strong>
                {{ p1Name }}
              </strong>
            </div>

            <small>
              Active
              {{ player1Active.length }}
              /
              {{ maxActive }}

              • Bench
              {{ player1BenchCount }}
              /
              {{ maxBench }}
            </small>
          </div>

          <div class="health-line">

            <div class="health-track">
              <div
                class="health-fill blue"
                :style="{
                  width:
                    `${p1HpPercent}%`,
                }"
              />
            </div>

            <strong>
              HP {{ p1Hp }}
              /
              {{ p1MaxHp }}
            </strong>

          </div>

          <div class="skill-heading">

            <span>
              ULTIMATE
            </span>

            <strong>
              {{ p1Skill }}%
            </strong>

          </div>

          <div class="skill-track">
            <div
              class="skill-fill blue"
              :style="{
                width:
                  `${p1Skill}%`,
              }"
            />
          </div>

        </div>
      </section>

      <!-- CENTER -->

      <section class="center-brand">

        <span class="brand-top">
          CARD BATTLE
        </span>

        <strong>
          NEXUS
        </strong>

        <span class="brand-bottom">
          BATTLE ARENA
        </span>

        <div
          class="turn-chip"
          :class="currentTurn"
        >
          <span>
            ●
          </span>

          {{ turnText }}
        </div>

        <div class="battle-meta">

          <span>
            ROUND
            {{ battle.round ?? 1 }}
            /
            {{
              battle.total_rounds ??
              "-"
            }}
          </span>

          <span>
            MAX ACTIVE
            {{ maxActive }}
          </span>

          <span>
            {{
              String(
                battle.ruleset ??
                  "classic",
              ).toUpperCase()
            }}
          </span>

        </div>

      </section>

      <!-- PLAYER 2 -->

      <section
        ref="p2HudRef"
        class="player-hud p2"
        :class="{
          current:
            currentTurn ===
            'p2',

          'defense-active':
            p2Defending,

          'water-active':
            p2WaterShieldPercent >
            0,

          'debuff-active':
            p2AttackDebuffPercent >
            0,

          'power-active':
            p2PowerStrikeReady,
        }"
      >
        <div class="player-info">

          <div
            class="
              player-name-row
              right
            "
          >
            <small>
              Active
              {{ player2Active.length }}
              /
              {{ maxActive }}

              • Bench
              {{ player2BenchCount }}
              /
              {{ maxBench }}
            </small>

            <div>
              <span>
                PLAYER 2
              </span>

              <strong>
                {{ p2Name }}
              </strong>
            </div>

          </div>

          <div class="health-line">

            <strong>
              HP {{ p2Hp }}
              /
              {{ p2MaxHp }}
            </strong>

            <div class="health-track">
              <div
                class="health-fill red"
                :style="{
                  width:
                    `${p2HpPercent}%`,
                }"
              />
            </div>

          </div>

          <div class="skill-heading">

            <span>
              ULTIMATE
            </span>

            <strong>
              {{ p2Skill }}%
            </strong>

          </div>

          <div class="skill-track">
            <div
              class="skill-fill red"
              :style="{
                width:
                  `${p2Skill}%`,
              }"
            />
          </div>

        </div>

        <div
          ref="p2AvatarRef"
          class="avatar red"
        >
          <img
            v-if="p2Avatar"
            :src="p2Avatar"
            :alt="p2Name"
          />

          <span v-else>
            🧑🏽‍🦱
          </span>
        </div>

      </section>

    </header>

    <!-- ===================================================
         BATTLEFIELD
    ==================================================== -->

    <section class="battlefield">

      <!-- PLAYER 1 -->

      <section
        ref="p1FieldRef"
        class="field-side p1-field"
      >

        <div class="field-background">
          <div class="giant-symbol">
            ◉
          </div>
        </div>

        <!-- DEFENSE BARRIER -->

        <div
          v-if="
            showDefenseBarrier(
              'p1',
            )
          "
          class="
            field-barrier
            defense-barrier
          "
          :class="{
            breaking:
              defenseBreaking(
                'p1',
              ),
          }"
        >
          <span>
            🛡
          </span>
        </div>

        <!-- WATER BARRIER -->

        <div
          v-if="
            showWaterBarrier(
              'p1',
            )
          "
          class="
            field-barrier
            water-barrier
          "
          :class="{
            breaking:
              waterBreaking(
                'p1',
              ),
          }"
        >
          <span>
            💧
          </span>
        </div>

        <div class="field-top">

          <header class="field-title">

            <div>
              <span>
                PLAYER 1
              </span>

              <strong>
                ACTIVE DECK
              </strong>
            </div>

            <em>
              ATTACK ›››
            </em>

          </header>

          <div
            v-if="
              p1StatusItems.length
            "
            class="
              status-strip
              left
            "
          >
            <div
              v-for="
                item in
                  p1StatusItems
              "
              :key="
                item.type
              "
              class="battle-status-chip"
              :class="
                item.type
              "
            >
              <span class="status-icon">
                {{ item.icon }}
              </span>

              <div>
                <strong>
                  {{ item.title }}
                </strong>

                <small>
                  {{ item.detail }}
                </small>
              </div>

            </div>
          </div>

        </div>

        <!-- FORMATION -->

        <div class="formation-stage">

          <div
            class="
              formation-grid
              p1-formation
            "
            :class="
              formationClass
            "
            :style="
              formationStyle
            "
          >

            <div
              v-for="(
                card,
                index
              ) in
                player1Slots"
              :key="
                card?.battleId ??
                card?.battle_id ??
                card?.id ??
                `p1-empty-${index}`
              "
              :ref="
                (element) =>
                  registerCardElement(
                    'p1',
                    card,
                    element,
                  )
              "
              class="formation-slot"
              :class="[
                `slot-${index + 1}`,

                {
                  'has-card':
                    Boolean(card),

                  'empty-slot':
                    !card,
                },

                getCombatSlotClasses(
                  'p1',
                  card,
                ),
              ]"
            >
              <BattleCard
                :card="card"
                player="p1"
                facing="right"
                :empty-label="
                  `POKÉMON ${
                    index + 1
                  }`
                "
              />
            </div>

          </div>

        </div>

        <div class="attack-lane p1">

          <div class="lane-line" />

          <span>
            ›
          </span>

          <span>
            ›
          </span>

          <span>
            ›
          </span>

        </div>

      </section>

      <!-- PLAYER 2 -->

      <section
        ref="p2FieldRef"
        class="field-side p2-field"
      >

        <div class="field-background">
          <div class="giant-symbol">
            ◉
          </div>
        </div>

        <!-- DEFENSE BARRIER -->

        <div
          v-if="
            showDefenseBarrier(
              'p2',
            )
          "
          class="
            field-barrier
            defense-barrier
          "
          :class="{
            breaking:
              defenseBreaking(
                'p2',
              ),
          }"
        >
          <span>
            🛡
          </span>
        </div>

        <!-- WATER BARRIER -->

        <div
          v-if="
            showWaterBarrier(
              'p2',
            )
          "
          class="
            field-barrier
            water-barrier
          "
          :class="{
            breaking:
              waterBreaking(
                'p2',
              ),
          }"
        >
          <span>
            💧
          </span>
        </div>

        <div class="field-top">

          <header
            class="
              field-title
              right
            "
          >
            <em>
              ‹‹‹ ATTACK
            </em>

            <div>
              <span>
                PLAYER 2
              </span>

              <strong>
                ACTIVE DECK
              </strong>
            </div>

          </header>

          <div
            v-if="
              p2StatusItems.length
            "
            class="
              status-strip
              right
            "
          >
            <div
              v-for="
                item in
                  p2StatusItems
              "
              :key="
                item.type
              "
              class="battle-status-chip"
              :class="
                item.type
              "
            >
              <span class="status-icon">
                {{ item.icon }}
              </span>

              <div>
                <strong>
                  {{ item.title }}
                </strong>

                <small>
                  {{ item.detail }}
                </small>
              </div>

            </div>
          </div>

        </div>

        <!-- FORMATION -->

        <div class="formation-stage">

          <div
            class="
              formation-grid
              p2-formation
            "
            :class="
              formationClass
            "
            :style="
              formationStyle
            "
          >

            <div
              v-for="(
                card,
                index
              ) in
                player2Slots"
              :key="
                card?.battleId ??
                card?.battle_id ??
                card?.id ??
                `p2-empty-${index}`
              "
              :ref="
                (element) =>
                  registerCardElement(
                    'p2',
                    card,
                    element,
                  )
              "
              class="formation-slot"
              :class="[
                `slot-${index + 1}`,

                {
                  'has-card':
                    Boolean(card),

                  'empty-slot':
                    !card,
                },

                getCombatSlotClasses(
                  'p2',
                  card,
                ),
              ]"
            >
              <BattleCard
                :card="card"
                player="p2"
                facing="left"
                :empty-label="
                  `POKÉMON ${
                    index + 1
                  }`
                "
              />
            </div>

          </div>

        </div>

        <div class="attack-lane p2">

          <span>
            ‹
          </span>

          <span>
            ‹
          </span>

          <span>
            ‹
          </span>

          <div class="lane-line" />

        </div>

      </section>

      <!-- CENTER -->

      <div class="center-line" />

      <div class="center-orb">

        <span class="blue-half" />

        <span class="red-half" />

        <i />

      </div>

    </section>

  </section>
</template>

<style scoped>
* {
  box-sizing: border-box;
}

/* =========================================================
   ROOT
========================================================= */

.public-active-field {
  width: 100%;
  height: 100%;

  min-width: 0;
  min-height: 0;

  display: grid;

  grid-template-rows:
    126px
    minmax(0, 1fr);

  overflow: hidden;

  border:
    1px solid
    rgba(
      75,
      129,
      160,
      0.16
    );

  border-radius:
    18px;

  background:
    #ffffff;

  box-shadow:
    0
    18px
    46px
    rgba(
      55,
      94,
      119,
      0.14
    );

  font-family:
    Inter,
    ui-sans-serif,
    system-ui,
    sans-serif;
}

/* =========================================================
   HEADER
========================================================= */

.battle-header {
  min-width: 0;

  display: grid;

  grid-template-columns:
    minmax(0, 1fr)
    235px
    minmax(0, 1fr);

  overflow: hidden;

  background:
    linear-gradient(
      180deg,
      #ffffff,
      #eef8fc
    );

  box-shadow:
    0
    7px
    22px
    rgba(
      53,
      94,
      119,
      0.08
    );

  z-index: 20;
}

/* =========================================================
   HUD
========================================================= */

.player-hud {
  min-width: 0;

  position: relative;

  display: flex;

  align-items: center;

  gap: 12px;

  padding:
    12px
    18px;

  background:
    rgba(
      255,
      255,
      255,
      0.7
    );

  transition:
    box-shadow
    0.2s
    ease;
}

.player-hud.p1 {
  border-bottom:
    3px solid
    #28b3ec;

  background:
    linear-gradient(
      90deg,
      rgba(
        36,
        172,
        235,
        0.12
      ),
      rgba(
        255,
        255,
        255,
        0.72
      )
    );
}

.player-hud.p2 {
  border-bottom:
    3px solid
    #ed567c;

  background:
    linear-gradient(
      270deg,
      rgba(
        237,
        86,
        124,
        0.11
      ),
      rgba(
        255,
        255,
        255,
        0.72
      )
    );
}

.player-hud.power-active {
  box-shadow:
    inset
    0
    0
    26px
    rgba(
      245,
      181,
      42,
      0.14
    );
}

.player-hud.defense-active {
  box-shadow:
    inset
    0
    0
    26px
    rgba(
      60,
      139,
      218,
      0.14
    );
}

.player-hud.water-active {
  box-shadow:
    inset
    0
    0
    28px
    rgba(
      27,
      188,
      221,
      0.16
    );
}

.player-hud.debuff-active {
  filter:
    saturate(
      0.9
    );
}

/* =========================================================
   AVATAR
========================================================= */

.avatar {
  width: 62px;
  height: 62px;

  flex:
    0
    0
    62px;

  display: grid;

  place-items: center;

  overflow: hidden;

  border:
    4px solid;

  border-radius:
    50%;

  background:
    linear-gradient(
      145deg,
      #ffffff,
      #e9f5fa
    );

  box-shadow:
    0
    8px
    21px
    rgba(
      50,
      91,
      116,
      0.13
    );

  font-size:
    28px;
}

.avatar.blue {
  border-color:
    #25ace8;
}

.avatar.red {
  border-color:
    #ed4e72;
}

.avatar img {
  width: 100%;
  height: 100%;

  object-fit:
    cover;
}

/* =========================================================
   PLAYER INFO
========================================================= */

.player-info {
  min-width: 0;

  flex: 1;
}

.player-name-row {
  display: flex;

  align-items:
    flex-start;

  justify-content:
    space-between;

  gap: 9px;

  margin-bottom:
    7px;
}

.player-name-row.right {
  text-align:
    right;
}

.player-name-row span {
  display: block;

  color:
    #278ebf;

  font-size:
    6px;

  font-weight:
    950;

  letter-spacing:
    0.1em;
}

.player-hud.p2
.player-name-row span {
  color:
    #d54d6b;
}

.player-name-row strong {
  display: block;

  margin-top:
    2px;

  color:
    #17324a;

  font-size:
    17px;

  font-weight:
    950;
}

.player-name-row small {
  color:
    #6e899c;

  font-size:
    6.5px;

  font-weight:
    850;
}

/* =========================================================
   HEALTH
========================================================= */

.health-line {
  display: flex;

  align-items: center;

  gap: 8px;
}

.health-line strong {
  flex-shrink: 0;

  color:
    #264861;

  font-size:
    8px;

  font-weight:
    950;
}

.health-track {
  height: 12px;

  flex: 1;

  overflow: hidden;

  border:
    1px solid
    rgba(
      68,
      118,
      148,
      0.15
    );

  border-radius:
    999px;

  background:
    #dfeaf0;
}

.health-fill {
  height: 100%;

  border-radius:
    inherit;
}

.health-fill.blue {
  background:
    linear-gradient(
      90deg,
      #18a8ef,
      #40d5e3
    );
}

.health-fill.red {
  margin-left:
    auto;

  background:
    linear-gradient(
      90deg,
      #ff718b,
      #ef476f
    );
}

/* =========================================================
   ULTIMATE
========================================================= */

.skill-heading {
  display: flex;

  justify-content:
    space-between;

  margin-top:
    5px;

  color:
    #70899b;

  font-size:
    5.5px;

  font-weight:
    900;
}

.skill-track {
  height: 5px;

  margin-top:
    3px;

  overflow: hidden;

  border-radius:
    999px;

  background:
    #dce8ef;
}

.skill-fill {
  height: 100%;
}

.skill-fill.blue {
  background:
    linear-gradient(
      90deg,
      #715eff,
      #2eb7ff
    );
}

.skill-fill.red {
  margin-left:
    auto;

  background:
    linear-gradient(
      90deg,
      #ff8d5c,
      #ff4e77
    );
}

/* =========================================================
   CENTER BRAND
========================================================= */

.center-brand {
  display: flex;

  flex-direction:
    column;

  align-items:
    center;

  justify-content:
    center;

  text-align:
    center;
}

.brand-top {
  color:
    #c3941d;

  font-size:
    6px;

  font-weight:
    1000;

  letter-spacing:
    0.28em;
}

.center-brand > strong {
  color:
    #28516c;

  font-size:
    29px;

  font-weight:
    1000;

  letter-spacing:
    0.16em;
}

.brand-bottom {
  color:
    #63869c;

  font-size:
    6px;

  font-weight:
    950;

  letter-spacing:
    0.25em;
}

.turn-chip {
  min-width:
    155px;

  margin-top:
    7px;

  padding:
    5px
    10px;

  border:
    1px solid
    rgba(
      45,
      149,
      203,
      0.28
    );

  border-radius:
    999px;

  color:
    #20739f;

  background:
    #e8f7fd;

  font-size:
    7px;

  font-weight:
    950;
}

.battle-meta {
  display: flex;

  gap: 4px;

  margin-top:
    4px;
}

.battle-meta span {
  padding:
    2px
    4px;

  border-radius:
    4px;

  color:
    #71899b;

  background:
    #eef5f8;

  font-size:
    4.6px;

  font-weight:
    900;
}

/* =========================================================
   BATTLEFIELD
========================================================= */

.battlefield {
  position: relative;

  display: grid;

  grid-template-columns:
    1fr
    1fr;

  min-height: 0;

  overflow:
    hidden;
}

.field-side {
  position: relative;

  min-width: 0;
  min-height: 0;

  display: grid;

  grid-template-rows:
    auto
    minmax(0, 1fr)
    42px;

  padding:
    18px
    12px
    12px;

  overflow:
    hidden;
}

.p1-field {
  background:
    linear-gradient(
      145deg,
      #d8f3ff,
      #bde9fb
    );
}

.p2-field {
  background:
    linear-gradient(
      215deg,
      #ffe4eb,
      #ffcfdc
    );
}

.field-background {
  position: absolute;

  inset: 0;
}

.giant-symbol {
  position:
    absolute;

  left: 50%;
  top: 55%;

  transform:
    translate(
      -50%,
      -50%
    );

  color:
    rgba(
      35,
      113,
      151,
      0.08
    );

  font-size:
    min(
      31vw,
      390px
    );
}

.p2-field
.giant-symbol {
  color:
    rgba(
      184,
      57,
      86,
      0.07
    );
}

/* =========================================================
   FIELD TOP
========================================================= */

.field-top {
  position:
    relative;

  z-index: 8;
}

.field-title {
  display: flex;

  align-items:
    center;

  justify-content:
    space-between;
}

.field-title.right {
  text-align:
    right;
}

.field-title span {
  display:
    block;

  color:
    #6d8c9e;

  font-size:
    5.5px;

  font-weight:
    900;
}

.field-title strong {
  color:
    #247aa4;

  font-size:
    10px;

  font-weight:
    1000;
}

.p2-field
.field-title strong {
  color:
    #bd4b67;
}

.field-title em {
  color:
    rgba(
      36,
      122,
      164,
      0.58
    );

  font-size:
    7px;

  font-style:
    normal;

  font-weight:
    950;
}

/* =========================================================
   STATUS
========================================================= */

.status-strip {
  display: flex;

  flex-wrap:
    wrap;

  gap: 5px;

  margin-top:
    7px;
}

.status-strip.right {
  justify-content:
    flex-end;
}

.battle-status-chip {
  display: flex;

  align-items:
    center;

  gap: 5px;

  max-width:
    220px;

  padding:
    5px
    7px;

  border-radius:
    8px;

  background:
    rgba(
      255,
      255,
      255,
      0.88
    );

  box-shadow:
    0
    5px
    13px
    rgba(
      50,
      84,
      104,
      0.08
    );
}

.status-icon {
  font-size:
    13px;
}

.battle-status-chip div {
  display: flex;

  flex-direction:
    column;
}

.battle-status-chip strong {
  font-size:
    5.7px;

  font-weight:
    1000;
}

.battle-status-chip small {
  margin-top:
    1px;

  font-size:
    5px;

  font-weight:
    850;
}

.battle-status-chip.power {
  color:
    #976600;

  border:
    1px solid
    rgba(
      239,
      179,
      33,
      0.4
    );

  background:
    #fff8df;
}

.battle-status-chip.defense {
  color:
    #266fa6;

  border:
    1px solid
    rgba(
      55,
      145,
      216,
      0.35
    );

  background:
    #eaf6ff;
}

.battle-status-chip.water {
  color:
    #087c9e;

  border:
    1px solid
    rgba(
      20,
      184,
      220,
      0.35
    );

  background:
    #e8fbff;
}

.battle-status-chip.debuff {
  color:
    #4f70a6;

  border:
    1px solid
    rgba(
      117,
      154,
      218,
      0.38
    );

  background:
    #eff5ff;
}

/* =========================================================
   BARRIERS
========================================================= */

.field-barrier {
  position:
    absolute;

  left: 8%;
  right: 8%;

  top: 19%;
  bottom: 13%;

  z-index: 3;

  display: grid;

  place-items:
    center;

  border-radius:
    44%;

  pointer-events:
    none;
}

.field-barrier span {
  font-size:
    clamp(
      70px,
      9vw,
      140px
    );

  opacity:
    0.12;
}

.defense-barrier {
  border:
    4px solid
    rgba(
      64,
      145,
      220,
      0.2
    );

  box-shadow:
    inset
    0
    0
    45px
    rgba(
      65,
      151,
      225,
      0.09
    ),
    0
    0
    34px
    rgba(
      65,
      151,
      225,
      0.1
    );
}

.water-barrier {
  border:
    4px solid
    rgba(
      21,
      190,
      220,
      0.24
    );

  box-shadow:
    inset
    0
    0
    55px
    rgba(
      21,
      190,
      220,
      0.12
    ),
    0
    0
    42px
    rgba(
      21,
      190,
      220,
      0.13
    );
}

.field-barrier.breaking {
  animation:
    barrierBreak
    0.48s
    ease-out;
}

@keyframes barrierBreak {
  0% {
    opacity: 1;

    transform:
      scale(
        1
      );
  }

  30% {
    opacity: 1;

    transform:
      scale(
        1.05
      );

    filter:
      brightness(
        1.65
      );
  }

  100% {
    opacity: 0;

    transform:
      scale(
        1.17
      );
  }
}

/* =========================================================
   FORMATION
========================================================= */

.formation-stage {
  position:
    relative;

  z-index: 5;

  display: flex;

  align-items:
    center;

  min-height: 0;
}

.formation-grid {
  width:
    fit-content;

  max-width:
    100%;

  display: grid;

  align-items:
    center;

  justify-items:
    center;

  row-gap:
    clamp(
      8px,
      1vh,
      12px
    );

  column-gap:
    clamp(
      8px,
      0.7vw,
      12px
    );
}

.p1-formation {
  margin-left:
    auto;

  margin-right:
    clamp(
      4px,
      0.5vw,
      8px
    );
}

.p2-formation {
  margin-left:
    clamp(
      4px,
      0.5vw,
      8px
    );

  margin-right:
    auto;
}

.formation-slot {
  position:
    relative;

  display: flex;

  align-items:
    center;

  justify-content:
    center;

  transition:
    transform
    0.22s
    ease,
    filter
    0.22s
    ease;
}

/* =========================================================
   FORMATION LAYOUTS
========================================================= */

.formation-1 {
  grid-template-columns:
    1fr;
}

.formation-2 {
  grid-template-columns:
    1fr;
}

.formation-3,
.formation-4 {
  grid-template-columns:
    repeat(
      2,
      1fr
    );
}

.formation-3
.slot-3 {
  grid-column:
    1 / 3;
}

.formation-5 {
  grid-template-columns:
    repeat(
      6,
      1fr
    );
}

.formation-5
.slot-1 {
  grid-column:
    1 / 3;
}

.formation-5
.slot-2 {
  grid-column:
    3 / 5;
}

.formation-5
.slot-3 {
  grid-column:
    5 / 7;
}

.formation-5
.slot-4 {
  grid-column:
    2 / 4;
}

.formation-5
.slot-5 {
  grid-column:
    4 / 6;
}

.formation-6 {
  grid-template-columns:
    repeat(
      3,
      1fr
    );
}

.formation-7 {
  grid-template-columns:
    repeat(
      8,
      1fr
    );
}

.formation-7
.slot-1 {
  grid-column:
    1 / 3;
}

.formation-7
.slot-2 {
  grid-column:
    3 / 5;
}

.formation-7
.slot-3 {
  grid-column:
    5 / 7;
}

.formation-7
.slot-4 {
  grid-column:
    7 / 9;
}

.formation-7
.slot-5 {
  grid-column:
    2 / 4;
}

.formation-7
.slot-6 {
  grid-column:
    4 / 6;
}

.formation-7
.slot-7 {
  grid-column:
    6 / 8;
}

.formation-8 {
  grid-template-columns:
    repeat(
      4,
      1fr
    );
}

/* =========================================================
   CARD SIZES
========================================================= */

/* 1 CARD */

.formation-1
:deep(.battle-card) {
  width:
    clamp(
      240px,
      16vw,
      280px
    );

  height:
    clamp(
      440px,
      49vh,
      500px
    );
}

/* 2 CARDS */

.formation-2
:deep(.battle-card) {
  width:
    clamp(
      205px,
      14vw,
      235px
    );

  height:
    clamp(
      380px,
      43vh,
      430px
    );
}

/* 3 - 4 */

.formation-3
:deep(.battle-card),

.formation-4
:deep(.battle-card) {
  width:
    clamp(
      175px,
      11.8vw,
      200px
    );

  height:
    clamp(
      325px,
      37vh,
      370px
    );
}

/* =========================================================
   5 - 6
   FILLED CARDS = TALLER
========================================================= */

.formation-5
.formation-slot.has-card
:deep(.battle-card),

.formation-6
.formation-slot.has-card
:deep(.battle-card) {
  width:
    clamp(
      158px,
      10.9vw,
      178px
    );

  height:
    clamp(
      325px,
      34vh,
      355px
    );
}

/* =========================================================
   5 - 6
   EMPTY SLOT = SMALLER
========================================================= */

.formation-5
.formation-slot.empty-slot
:deep(.battle-card),

.formation-6
.formation-slot.empty-slot
:deep(.battle-card) {
  width:
    clamp(
      145px,
      10vw,
      162px
    );

  height:
    clamp(
      240px,
      26vh,
      265px
    );
}

/* 7 - 8 */

.formation-7
:deep(.battle-card),

.formation-8
:deep(.battle-card) {
  width:
    clamp(
      108px,
      7.2vw,
      126px
    );

  height:
    clamp(
      215px,
      25vh,
      245px
    );
}

/* =========================================================
   BATTLE CARD CONTENT SAFETY
========================================================= */

.formation-slot
:deep(.stat) {
  min-width:
    0;
}

.formation-slot
:deep(.stat strong) {
  width:
    100%;

  overflow:
    visible !important;

  text-overflow:
    clip !important;

  white-space:
    nowrap !important;

  font-size:
    clamp(
      18px,
      1.55vw,
      30px
    ) !important;

  letter-spacing:
    -0.045em;
}

.formation-slot
:deep(.card-title strong) {
  white-space:
    normal !important;

  overflow:
    hidden !important;

  text-overflow:
    clip !important;

  display:
    -webkit-box !important;

  -webkit-box-orient:
    vertical;

  -webkit-line-clamp:
    2;

  line-clamp:
    2;
}

/* =========================================================
   COMBAT FX
========================================================= */

.combat-power-strike
:deep(.battle-card) {
  animation:
    powerStrikeAura
    0.75s
    ease-in-out
    infinite
    alternate;

  filter:
    drop-shadow(
      0
      0
      11px
      #ffc83b
    )
    drop-shadow(
      0
      0
      25px
      rgba(
        255,
        172,
        27,
        0.75
      )
    );
}

@keyframes powerStrikeAura {
  from {
    transform:
      scale(
        1.02
      );
  }

  to {
    transform:
      scale(
        1.07
      );
  }
}

.combat-attack-debuff
:deep(.battle-card) {
  box-shadow:
    0
    0
    0
    4px
    rgba(
      124,
      178,
      255,
      0.28
    );

  filter:
    saturate(
      0.72
    )
    hue-rotate(
      8deg
    )
    drop-shadow(
      0
      0
      14px
      rgba(
        106,
        174,
        255,
        0.8
      )
    );
}

.combat-attack-debuff::before {
  content:
    "❄ ATK DOWN";

  position:
    absolute;

  left: 50%;
  top: -17px;

  z-index: 20;

  transform:
    translateX(
      -50%
    );

  padding:
    4px
    7px;

  border-radius:
    999px;

  color:
    #3f659d;

  background:
    #eff6ff;

  font-size:
    6px;

  font-weight:
    1000;

  white-space:
    nowrap;
}

.combat-defense-target::after {
  content:
    "🛡 DEFENSE -50%";

  position:
    absolute;

  left: 50%;
  top: -20px;

  z-index: 20;

  transform:
    translateX(
      -50%
    );

  padding:
    4px
    7px;

  border-radius:
    999px;

  color:
    #236b9e;

  background:
    #e9f6ff;

  font-size:
    6px;

  font-weight:
    1000;

  white-space:
    nowrap;
}

.combat-water-target::before {
  content:
    "💧 WATER SHIELD";

  position:
    absolute;

  left: 50%;
  bottom: -19px;

  z-index: 20;

  transform:
    translateX(
      -50%
    );

  padding:
    4px
    7px;

  border-radius:
    999px;

  color:
    #087b9d;

  background:
    #e7fbff;

  font-size:
    6px;

  font-weight:
    1000;

  white-space:
    nowrap;
}

.combat-impact {
  animation:
    targetHit
    0.42s
    ease;
}

@keyframes targetHit {
  20% {
    transform:
      translateX(
        -12px
      );

    filter:
      brightness(
        1.6
      );
  }

  45% {
    transform:
      translateX(
        9px
      );
  }

  70% {
    transform:
      translateX(
        -5px
      );
  }
}

.combat-destroyed {
  animation:
    destroyedCard
    0.55s
    ease
    forwards;
}

@keyframes destroyedCard {
  to {
    opacity:
      0.15;

    filter:
      grayscale(
        1
      );

    transform:
      scale(
        0.83
      )
      translateY(
        18px
      );
  }
}

/* =========================================================
   ATTACK LANE
========================================================= */

.attack-lane {
  display: flex;

  align-items:
    center;

  gap: 6px;

  opacity:
    0.5;
}

.attack-lane.p1 {
  justify-content:
    flex-end;
}

.attack-lane.p2 {
  justify-content:
    flex-start;
}

.lane-line {
  width: 38%;

  height: 2px;

  background:
    currentColor;
}

.attack-lane span {
  font-size:
    20px;

  font-weight:
    1000;
}

/* =========================================================
   CENTER DIVIDER
========================================================= */

.center-line {
  width: 5px;

  position:
    absolute;

  left: 50%;
  top: 0;
  bottom: 0;

  z-index: 10;

  transform:
    translateX(
      -50%
    );

  background:
    linear-gradient(
      #31b6e9,
      #ffffff,
      #e85474
    );
}

.center-orb {
  width: 74px;
  height: 74px;

  position:
    absolute;

  left: 50%;
  top: 50%;

  z-index: 12;

  transform:
    translate(
      -50%,
      -50%
    );

  overflow:
    hidden;

  border:
    4px solid
    #ffffff;

  border-radius:
    50%;
}

.blue-half,
.red-half {
  width: 50%;
  height: 100%;

  position:
    absolute;
}

.blue-half {
  left: 0;

  background:
    #238fc7;
}

.red-half {
  right: 0;

  background:
    #c82d4e;
}

.center-orb i {
  width: 17px;
  height: 17px;

  position:
    absolute;

  left: 50%;
  top: 50%;

  z-index: 4;

  transform:
    translate(
      -50%,
      -50%
    )
    rotate(
      45deg
    );

  background:
    #ffffff;
}

/* =========================================================
   RESPONSIVE
========================================================= */

@media (
  max-height: 820px
) {

  .public-active-field {
    grid-template-rows:
      108px
      minmax(
        0,
        1fr
      );
  }

  .field-side {
    padding:
      14px
      10px
      10px;
  }

  .formation-grid {
    row-gap:
      7px;

    column-gap:
      9px;
  }

  .formation-3
  :deep(.battle-card),

  .formation-4
  :deep(.battle-card) {
    width:
      clamp(
        150px,
        10.4vw,
        172px
      );

    height:
      clamp(
        270px,
        31vh,
        305px
      );
  }

  .formation-5
  .formation-slot.has-card
  :deep(.battle-card),

  .formation-6
  .formation-slot.has-card
  :deep(.battle-card) {
    width:
      clamp(
        145px,
        10vw,
        162px
      );

    height:
      clamp(
        285px,
        33vh,
        320px
      );
  }

  .formation-5
  .formation-slot.empty-slot
  :deep(.battle-card),

  .formation-6
  .formation-slot.empty-slot
  :deep(.battle-card) {
    width:
      clamp(
        132px,
        9.2vw,
        150px
      );

    height:
      clamp(
        220px,
        25vh,
        245px
      );
  }

  .formation-7
  :deep(.battle-card),

  .formation-8
  :deep(.battle-card) {
    width:
      clamp(
        98px,
        6.6vw,
        112px
      );

    height:
      clamp(
        195px,
        23vh,
        220px
      );
  }

  .battle-status-chip {
    padding:
      3px
      5px;
  }
}
</style>