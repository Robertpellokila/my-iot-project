<script setup>
import { computed } from "vue";

const props = defineProps({
  player: {
    type: String,
    required: true,
    validator: value => ["p1", "p2"].includes(value),
  },
  name: {
    type: String,
    required: true,
  },
  avatar: {
    type: String,
    default: "👤",
  },
  hp: {
    type: Number,
    default: 0,
  },
  maxHp: {
    type: Number,
    default: 1,
  },
  skill: {
    type: Number,
    default: 0,
  },
  activeCount: {
    type: Number,
    default: 0,
  },
  benchCount: {
    type: Number,
    default: 0,
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
  ultimateUsed: {
    type: Boolean,
    default: false,
  },
  canUltimate: {
    type: Boolean,
    default: false,
  },
  defending: {
    type: Boolean,
    default: false,
  },
  synergyShield: {
    type: Number,
    default: 0,
  },
  attackDebuff: {
    type: Number,
    default: 0,
  },
  effect: {
    type: String,
    default: null,
  },
  popup: {
    type: String,
    default: null,
  },
});

const isP1 = computed(() => props.player === "p1");

const hpPercent = computed(() => {
  return Math.min(
    Math.max(
      (
        Number(props.hp || 0) /
        Math.max(1, Number(props.maxHp || 1))
      ) * 100,
      0
    ),
    100
  );
});

const isCurrent = computed(() => {
  return (
    props.battleState === "battle_ready" &&
    props.currentTurn === props.player &&
    !props.winner
  );
});

const shieldPercent = computed(() =>
  Math.round(Number(props.synergyShield || 0) * 100)
);

const debuffPercent = computed(() =>
  Math.round(Number(props.attackDebuff || 0) * 100)
);
</script>

<template>
  <section
    class="player-hud"
    :class="[
      isP1 ? 'hud-blue' : 'hud-red',
      {
        'hud-current-blue': isP1 && isCurrent,
        'hud-current-red': !isP1 && isCurrent,
      },
      effect ? `profile-${effect}` : '',
    ]"
  >
    <!-- P1: avatar berada di kiri seperti source asli -->
    <div
      v-if="isP1"
      class="player-avatar avatar-blue"
    >
      {{ avatar }}
    </div>

    <Transition name="profile-popup">
      <div
        v-if="popup"
        class="profile-effect-popup"
        :class="effect"
      >
        {{ popup }}
      </div>
    </Transition>

    <div
      class="player-status"
      :class="{
        'player-status-right': !isP1,
      }"
    >
      <div class="player-name">
        <template v-if="isP1">
          <span>{{ name }}</span>

          <span class="pokemon-count">
            Active {{ activeCount }}/4
            •
            Bench {{ benchCount }}/4
          </span>
        </template>

        <template v-else>
          <span class="pokemon-count">
            Active {{ activeCount }}/4
            •
            Bench {{ benchCount }}/4
          </span>

          <span>{{ name }}</span>
        </template>
      </div>

      <!-- P1 HP: bar lalu angka -->
      <div
        v-if="isP1"
        class="status-line"
      >
        <div class="hp-track">
          <div
            class="hp-fill hp-blue"
            :style="{
              width: `${hpPercent}%`,
            }"
          />
        </div>

        <span class="hp-value">
          HP {{ hp }} / {{ maxHp }}
        </span>
      </div>

      <!-- P2 HP: angka lalu bar -->
      <div
        v-else
        class="status-line"
      >
        <span class="hp-value">
          HP {{ hp }} / {{ maxHp }}
        </span>

        <div class="hp-track">
          <div
            class="hp-fill hp-red"
            :style="{
              width: `${hpPercent}%`,
            }"
          />
        </div>
      </div>

      <div class="skill-status">
        <div class="skill-status-label">
          <span>ULTIMATE</span>

          <span>
            {{
              ultimateUsed
                ? "USED"
                : `${skill}%`
            }}
          </span>
        </div>

        <div class="skill-track">
          <div
            class="skill-fill"
            :class="[
              isP1
                ? 'skill-blue'
                : 'skill-red',
              {
                'skill-ready': canUltimate,
              },
            ]"
            :style="{
              width: `${ultimateUsed ? 0 : skill}%`,
            }"
          />
        </div>
      </div>

      <div
        class="status-badges"
        :class="{
          right: !isP1,
        }"
      >
        <span
          v-if="defending"
          class="status-chip"
          :class="isP1 ? 'blue-chip' : 'red-chip'"
        >
          🛡 Defense
        </span>

        <span
          v-if="synergyShield > 0"
          class="status-chip"
          :class="isP1 ? 'blue-chip' : 'red-chip'"
        >
          💧 Shield {{ shieldPercent }}%
        </span>

        <span
          v-if="attackDebuff > 0"
          class="status-chip debuff-chip"
        >
          ❄️ ATK - {{ debuffPercent }}%
        </span>
      </div>
    </div>

    <!-- P2: avatar berada di kanan seperti source asli -->
    <div
      v-if="!isP1"
      class="player-avatar avatar-red"
    >
      {{ avatar }}
    </div>
  </section>
</template>

<style scoped>
.player-hud {
  display: flex;
  align-items: center;
  gap: 15px;
  padding:
    13px
    25px;
  position: relative;
  overflow: visible;
}

.hud-blue {
  border-bottom:
    3px solid
    #159dff;
  background:
    linear-gradient(
      90deg,
      rgba(0,124,255,.23),
      transparent
    );
}

.hud-red {
  justify-content:
    flex-end;
  border-bottom:
    3px solid
    #ff3156;
  background:
    linear-gradient(
      270deg,
      rgba(255,23,66,.22),
      transparent
    );
}

.hud-current-blue {
  box-shadow:
    inset 0 0 35px
    rgba(0,178,255,.18);
}

.hud-current-red {
  box-shadow:
    inset 0 0 35px
    rgba(255,24,60,.18);
}

.player-avatar {
  width: 68px;
  height: 68px;
  flex-shrink: 0;
  display: grid;
  place-items: center;
  border-radius: 50%;
  font-size: 34px;
  background:
    #101a30;
}

.avatar-blue {
  border:
    4px solid
    #20c7ff;
  box-shadow:
    0 0 22px
    rgba(0,180,255,.75);
}

.avatar-red {
  border:
    4px solid
    #ff3d60;
  box-shadow:
    0 0 22px
    rgba(255,30,70,.7);
}

.player-status {
  width: 100%;
  max-width: 500px;
}

.player-status-right {
  text-align: right;
}

.player-name {
  display: flex;
  justify-content:
    space-between;
  margin-bottom: 6px;
  font-size: 15px;
  font-weight: 900;
}

.pokemon-count {
  color:
    #9fb1ca;
  font-size: 8px;
  font-weight: 700;
}

.status-line {
  display: flex;
  align-items: center;
  gap: 9px;
}

.hp-track {
  flex: 1;
  height: 17px;
  padding: 3px;
  overflow: hidden;
  border-radius:
    999px;
  border:
    1px solid
    rgba(255,255,255,.17);
  background:
    #060c19;
}

.hp-fill {
  height: 100%;
  border-radius:
    inherit;
  transition:
    width .55s ease;
}

.hp-blue {
  background:
    linear-gradient(
      90deg,
      #0784ff,
      #19e3ff
    );
  box-shadow:
    0 0 12px
    #00bfff;
}

.hp-red {
  margin-left:
    auto;
  background:
    linear-gradient(
      90deg,
      #ff3655,
      #ff003d
    );
  box-shadow:
    0 0 12px
    #ff204c;
}

.hp-value {
  min-width:
    115px;
  white-space:
    nowrap;
  font-size:
    10px;
  font-weight:
    900;
}

.skill-status {
  margin-top: 6px;
}

.skill-status-label {
  display: flex;
  justify-content:
    space-between;
  margin-bottom: 3px;
  color:
    #aebbd0;
  font-size:
    7px;
  font-weight:
    900;
  letter-spacing:
    .12em;
}

.skill-track {
  height: 6px;
  overflow: hidden;
  border-radius:
    999px;
  background:
    rgba(255,255,255,.12);
}

.skill-fill {
  height: 100%;
  border-radius:
    inherit;
  transition:
    width .45s ease;
}

.skill-blue {
  background:
    linear-gradient(
      90deg,
      #238aff,
      #35e2ff
    );
}

.skill-red {
  margin-left:
    auto;
  background:
    linear-gradient(
      90deg,
      #ff3654,
      #ff993c
    );
}

.skill-ready {
  background:
    linear-gradient(
      90deg,
      #ffe146,
      #ff8800
    ) !important;
  box-shadow:
    0 0 12px
    rgba(255,210,30,.9);
  animation:
    gaugePulse
    .7s alternate infinite;
}

@keyframes gaugePulse {
  from {
    filter:
      brightness(1);
  }

  to {
    filter:
      brightness(1.8);
  }
}

.status-badges {
  min-height:
    16px;
  margin-top:
    5px;
  display:
    flex;
  gap:
    5px;
  flex-wrap:
    wrap;
}

.status-badges.right {
  justify-content:
    flex-end;
}

.status-chip {
  padding:
    2px 6px;
  border-radius:
    999px;
  font-size:
    6px;
  font-weight:
    900;
}

.blue-chip {
  color:
    #7fe6ff;
  border:
    1px solid
    rgba(65,211,255,.5);
  background:
    rgba(0,112,170,.25);
}

.red-chip {
  color:
    #ff9eb0;
  border:
    1px solid
    rgba(255,83,112,.5);
  background:
    rgba(161,11,47,.25);
}

.debuff-chip {
  color:
    #d9eeff;
  border:
    1px solid
    rgba(184,221,255,.5);
  background:
    rgba(94,133,170,.22);
}

.profile-effect-popup {
  position: absolute;
  left: 50%;
  top: 12px;
  transform:
    translateX(-50%);
  z-index: 200;
  padding:
    5px 11px;
  border-radius:
    999px;
  font-size:
    19px;
  font-weight:
    1000;
  white-space:
    nowrap;
  pointer-events:
    none;
}

.profile-effect-popup.damage {
  color:
    #ffe44d;
  text-shadow:
    0 2px 0
    #9a0000,
    0 0 15px red;
}

.profile-effect-popup.heal {
  color:
    #57ff9d;
  text-shadow:
    0 0 15px
    #00b85c;
}

.profile-effect-popup.defense {
  color:
    #71e5ff;
  text-shadow:
    0 0 15px
    #009bd2;
}

.profile-effect-popup.summon {
  color:
    #ffe75e;
  text-shadow:
    0 0 15px
    #e4a800;
}

.profile-effect-popup.ultimate {
  color:
    #ffce44;
  text-shadow:
    0 0 18px
    #ff4d00;
}

.profile-effect-popup.synergy {
  color:
    white;
  text-shadow:
    0 0 15px
    #39cfff;
}

.profile-effect-popup.info,
.profile-effect-popup.warning {
  color:
    white;
  text-shadow:
    0 0 14px
    #428cff;
}

.profile-damage {
  animation:
    profileDamage
    .55s ease;
}

@keyframes profileDamage {
  0% {
    transform:
      translateX(0);
    filter:
      brightness(1);
  }

  20% {
    transform:
      translateX(-9px);
    filter:
      brightness(2.5);
  }

  40% {
    transform:
      translateX(10px);
  }

  60% {
    transform:
      translateX(-6px);
  }

  80% {
    transform:
      translateX(4px);
  }

  100% {
    transform:
      translateX(0);
    filter:
      brightness(1);
  }
}

.profile-heal {
  animation:
    profileHeal
    .8s ease;
}

@keyframes profileHeal {
  50% {
    box-shadow:
      inset 0 0 45px
      rgba(40,255,130,.38);
    filter:
      brightness(1.5);
  }
}

.profile-defense {
  animation:
    profileDefense
    .8s ease;
}

@keyframes profileDefense {
  50% {
    box-shadow:
      inset 0 0 50px
      rgba(50,210,255,.45);
  }
}

.profile-summon {
  animation:
    profileSummon
    .8s ease;
}

@keyframes profileSummon {
  40% {
    filter:
      brightness(2);
  }
}

.profile-ultimate {
  animation:
    profileUltimate
    .8s ease;
}

@keyframes profileUltimate {
  40% {
    filter:
      brightness(2.3);
  }
}

.profile-synergy {
  animation:
    profileSynergy
    .85s ease;
}

@keyframes profileSynergy {
  50% {
    filter:
      brightness(1.8);
  }
}

.profile-popup-enter-active {
  animation:
    profilePopup
    .75s ease-out;
}

.profile-popup-leave-active {
  opacity:
    0;
}

@keyframes profilePopup {
  0% {
    opacity:
      0;
    transform:
      translate(-50%,15px)
      scale(.5);
  }

  30% {
    opacity:
      1;
    transform:
      translate(-50%,-5px)
      scale(1.25);
  }

  100% {
    opacity:
      0;
    transform:
      translate(-50%,-35px)
      scale(1);
  }
}

@media (max-width: 1400px) {
  .player-hud {
    padding:
      10px 14px;
  }

  .player-avatar {
    width:
      56px;
    height:
      56px;
    font-size:
      27px;
  }
}
</style>
