<script setup>
import { computed } from "vue";

const props = defineProps({
  player: {
    type: String,
    required: true,
    validator: value => ["p1", "p2"].includes(value),
  },
  hand: {
    type: Array,
    default: () => [],
  },
  selectedCard: {
    type: Object,
    default: null,
  },
  selectedSkill: {
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
  ultimateUsed: {
    type: Boolean,
    default: false,
  },
  healUsed: {
    type: Boolean,
    default: false,
  },
  canUltimate: {
    type: Boolean,
    default: false,
  },
  canHeal: {
    type: Boolean,
    default: false,
  },
  skillGauge: {
    type: Number,
    default: 0,
  },
  selectedTurnAction: {
    type: String,
    default: null,
  },
  isActing: {
    type: Boolean,
    default: false,
  },
  swapMode: {
    type: Boolean,
    default: false,
  },
  selectedSynergyInfo: {
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
]);

const active = computed(() =>
  props.currentTurn ===
    props.player &&
  props.battleState ===
    "battle_ready"
);

const label = computed(() =>
  props.player === "p1"
    ? "PLAYER 1"
    : "PLAYER 2"
);

const skillIsUsed = skill => {
  return (
    (
      skill.type ===
        "ultimate" &&
      props.ultimateUsed
    ) ||
    (
      skill.type ===
        "heal" &&
      props.healUsed
    )
  );
};
</script>

<template>
  <div
    class="action-side"
    :class="{
      active,
    }"
  >
    <div class="action-header">
      <span>
        {{ label }}
      </span>

      <strong
        v-if="
          currentTurn === player &&
          !selectedCard
        "
      >
        SELECT ACTIVE CARD
      </strong>

      <strong
        v-else-if="
          currentTurn === player &&
          selectedCard
        "
      >
        {{ selectedCard.name }}
      </strong>
    </div>

    <div class="skill-hand">
      <button
        v-for="skill in hand"
        :key="skill.id"
        type="button"
        class="skill-card"
        :class="[
          skill.className,
          {
            disabled:
              !canUseSkill(
                player,
                skill
              ),

            selected:
              selectedSkill?.id ===
              skill.id,

            used:
              skillIsUsed(
                skill
              ),

            ready:
              skill.type ===
                'ultimate' &&
              canUltimate,
          },
        ]"
        :disabled="
          !canUseSkill(
            player,
            skill
          )
        "
        @click="
          emit(
            'play-skill',
            player,
            skill
          )
        "
      >
        <div class="skill-title">
          {{ skill.name }}
        </div>

        <div class="skill-icon">
          {{ skill.icon }}
        </div>

        <div class="skill-detail">
          <template
            v-if="
              skill.type ===
              'attack'
            "
          >
            ATK
            {{
              selectedCard?.attack ||
              0
            }}

            <br>

            Unlimited
          </template>

          <template
            v-else-if="
              skill.type ===
              'defense'
            "
          >
            Next DMG -50%

            <br>

            Unlimited
          </template>

          <template
            v-else-if="
              skill.type ===
              'ultimate'
            "
          >
            <span
              v-if="
                ultimateUsed
              "
            >
              USED
            </span>

            <span
              v-else-if="
                canUltimate
              "
            >
              READY!

              <br>

              ATK ×2
            </span>

            <span v-else>
              {{ skillGauge }}/100
            </span>
          </template>

          <template v-else>
            <span
              v-if="
                healUsed
              "
            >
              USED
            </span>

            <span
              v-else-if="
                canHeal
              "
            >
              READY!

              <br>

              HEAL 35%
            </span>

            <span v-else>
              HP ≤ 50%
            </span>
          </template>
        </div>
      </button>
    </div>

    <button
      type="button"
      class="synergy-button"
      :class="{
        ready:
          currentTurn === player &&
          selectedSynergyInfo?.canUse,

        used:
          currentTurn === player &&
          selectedSynergyInfo?.used,
      }"
      :disabled="
        currentTurn !== player ||
        !selectedSynergyInfo?.canUse ||
        !!selectedTurnAction ||
        isActing ||
        swapMode
      "
      @click="
        emit(
          'play-synergy',
          player
        )
      "
    >
      <template
        v-if="
          currentTurn === player &&
          selectedSynergyInfo
        "
      >
        <span class="synergy-icon">
          {{
            selectedSynergyInfo.icon
          }}
        </span>

        <span>
          {{
            selectedSynergyInfo.name
          }}
        </span>

        <strong>
          {{
            selectedSynergyInfo.points
          }}x

          {{
            selectedSynergyInfo.element
          }}
        </strong>

        <small>
          {{
            selectedSynergyInfo.used
              ? "USED"
              : selectedSynergyInfo.canUse
                ? "READY"
                : "NEED 2 SAME ELEMENT"
          }}
        </small>
      </template>

      <template v-else>
        SYNERGY
      </template>
    </button>
  </div>
</template>

<style scoped>
.action-side {
  height:
    180px;
  padding:
    8px;
  border-radius:
    13px;
  border:
    1px solid
    rgba(255,255,255,.09);
  background:
    rgba(0,0,0,.15);
  opacity:
    .5;
}

.action-side.active {
  opacity:
    1;
}

.action-header {
  height:
    24px;
  display:
    flex;
  justify-content:
    space-between;
  align-items:
    center;
  color:
    #9cafc7;
  font-size:
    7px;
}

.action-header strong {
  color:
    white;
}

.skill-hand {
  display:
    grid;
  grid-template-columns:
    repeat(4,1fr);
  gap:
    6px;
}

.skill-card {
  height:
    107px;
  min-width:
    0;
  padding:
    5px;
  position:
    relative;
  border:
    2px solid
    rgba(255,255,255,.82);
  border-radius:
    7px;
  color:
    #101318;
  cursor:
    pointer;
  box-shadow:
    0 5px 10px
    rgba(0,0,0,.4);
}

.skill-basic {
  background:
    linear-gradient(
      145deg,
      #eef3ff,
      #95aad0
    );
}

.skill-defense {
  background:
    linear-gradient(
      145deg,
      #ecfbff,
      #63cbe8
    );
}

.skill-ultimate {
  background:
    linear-gradient(
      145deg,
      #ffe9a6,
      #ff7750
    );
}

.skill-heal {
  background:
    linear-gradient(
      145deg,
      #e7ffe9,
      #68cf72
    );
}

.skill-title {
  overflow:
    hidden;
  white-space:
    nowrap;
  text-overflow:
    ellipsis;
  font-size:
    6px;
  font-weight:
    1000;
}

.skill-icon {
  height:
    47px;
  margin-top:
    2px;
  display:
    grid;
  place-items:
    center;
  border-radius:
    4px;
  background:
    rgba(255,255,255,.42);
  font-size:
    25px;
}

.skill-detail {
  margin-top:
    4px;
  font-size:
    5.5px;
  line-height:
    1.35;
  font-weight:
    800;
}

.skill-card.disabled {
  opacity:
    .3;
  filter:
    grayscale(.65);
  cursor:
    not-allowed;
}

.skill-card.used {
  opacity:
    .22;
  filter:
    grayscale(1);
}

.skill-card.used::after {
  content:
    'USED';
  position:
    absolute;
  inset:
    0;
  display:
    grid;
  place-items:
    center;
  border-radius:
    inherit;
  color:
    white;
  background:
    rgba(0,0,0,.55);
  font-size:
    13px;
  font-weight:
    1000;
}

.skill-card.ready {
  opacity:
    1;
  filter:
    none;
  animation:
    ultimateReady
    .8s alternate infinite;
}

@keyframes ultimateReady {
  from {
    box-shadow:
      0 0 7px
      rgba(255,210,50,.4);
  }

  to {
    box-shadow:
      0 0 22px
      rgba(255,205,40,.95);
  }
}

.synergy-button {
  width:
    100%;
  height:
    35px;
  margin-top:
    5px;
  display:
    flex;
  align-items:
    center;
  justify-content:
    center;
  gap:
    7px;
  border:
    1px solid
    rgba(255,255,255,.18);
  border-radius:
    7px;
  color:
    #77869b;
  background:
    rgba(255,255,255,.05);
  font-size:
    6px;
  font-weight:
    900;
}

.synergy-button.ready {
  color:
    #ffe96a;
  border-color:
    rgba(255,226,70,.65);
  background:
    rgba(255,180,0,.12);
  cursor:
    pointer;
}

.synergy-button.used {
  opacity:
    .35;
}

.synergy-icon {
  font-size:
    15px;
}

@media (max-width: 1400px) {
  .action-side {
    height:
      170px;
  }

  .skill-card {
    height:
      100px;
  }

  .skill-icon {
    height:
      41px;
    font-size:
      22px;
  }
}
</style>
