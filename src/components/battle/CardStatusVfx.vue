<script setup>
import { computed } from 'vue';

const props = defineProps({
  shield: { type: Boolean, default: false },
  defense: { type: Boolean, default: false },
  burn: { type: Boolean, default: false },
  freeze: { type: Boolean, default: false },
  stun: { type: Boolean, default: false },
  poison: { type: Boolean, default: false },
  curse: { type: Boolean, default: false },
});

const protectedCard = computed(() => props.shield || props.defense);
const hasStatus = computed(() =>
  protectedCard.value || props.burn || props.freeze || props.stun || props.poison || props.curse,
);
</script>

<template>
  <div
    v-if="hasStatus"
    class="tcg-status-vfx"
    :class="{
      'has-shield': protectedCard,
      'has-burn': burn,
      'has-freeze': freeze,
      'has-stun': stun,
      'has-poison': poison,
      'has-curse': curse,
    }"
    aria-hidden="true"
  >
    <div v-if="protectedCard" class="tcg-shield-glass"><i></i></div>

    <div v-if="burn" class="tcg-burn-wash">
      <i class="burn-ember ember-one"></i>
      <i class="burn-ember ember-two"></i>
      <i class="burn-ember ember-three"></i>
    </div>

    <div v-if="freeze" class="tcg-element-vfx tcg-freeze-vfx">
      <i class="tcg-frost-corner top-left"></i><i class="tcg-frost-corner top-right"></i>
      <i class="tcg-frost-corner bottom-left"></i><i class="tcg-frost-corner bottom-right"></i>
      <i class="tcg-frost-glint glint-one"></i><i class="tcg-frost-glint glint-two"></i>
      <i class="tcg-frost-crack crack-one"></i><i class="tcg-frost-crack crack-two"></i>
    </div>

    <div v-if="stun" class="tcg-element-vfx tcg-stun-vfx">
      <svg viewBox="0 0 300 430" preserveAspectRatio="none" focusable="false">
        <path d="M18 105 31 119 23 132 43 149M282 202 267 218 277 232 257 248M52 407 65 391 57 377 76 359M242 34 230 51 240 64 221 80"/>
      </svg>
      <i class="tcg-stun-spark spark-one"></i><i class="tcg-stun-spark spark-two"></i>
    </div>

    <div v-if="poison" class="tcg-element-vfx tcg-poison-vfx">
      <i class="tcg-poison-bubble bubble-one"></i><i class="tcg-poison-bubble bubble-two"></i>
      <i class="tcg-poison-bubble bubble-three"></i><i class="tcg-poison-bubble bubble-four"></i>
    </div>

    <div v-if="curse" class="tcg-element-vfx tcg-curse-vfx">
      <i class="tcg-curse-rune rune-one">✦</i><i class="tcg-curse-rune rune-two">◇</i>
      <i class="tcg-curse-rune rune-three">✧</i>
    </div>
  </div>
</template>

<style scoped>
.tcg-status-vfx {
  position: absolute;
  inset: -2% -1.5%;
  z-index: 60;
  overflow: visible;
  border-radius: inherit;
  pointer-events: none;
  user-select: none;
}
.tcg-status-vfx * { box-sizing: border-box; pointer-events: none; }
.tcg-element-vfx { position: absolute; inset: 2%; overflow: hidden; border-radius: inherit; }

/* A quiet glass sheen that follows the card edge, without a crest or cage. */
.tcg-shield-glass {
  position: absolute;
  inset: 2%;
  overflow: hidden;
  border: 1px solid rgba(168, 224, 255, .48);
  border-radius: inherit;
  background: linear-gradient(135deg, rgba(198, 239, 255, .10), transparent 34%, rgba(128, 207, 255, .035) 70%, rgba(196, 238, 255, .12));
  box-shadow: inset 0 0 14px rgba(120, 205, 255, .12), 0 0 10px rgba(77, 173, 232, .12);
  animation: shield-breathe 3.8s ease-in-out infinite;
}
.tcg-shield-glass::before {
  content: "";
  position: absolute;
  top: -30%;
  left: -70%;
  width: 34%;
  height: 160%;
  transform: rotate(18deg);
  background: linear-gradient(90deg, transparent, rgba(235, 250, 255, .16), transparent);
  animation: shield-reflection 5.4s ease-in-out infinite;
}
.tcg-shield-glass::after {
  content: "";
  position: absolute;
  inset: 5px;
  border: 1px solid rgba(214, 244, 255, .16);
  border-radius: inherit;
}

/* Fire stays close to the lower edge: warm reflected light and a few embers. */
.tcg-burn-wash {
  position: absolute;
  inset: 1%;
  overflow: hidden;
  border-radius: inherit;
  background:
    radial-gradient(ellipse at 5% 100%, rgba(255, 83, 24, .48), transparent 34%),
    radial-gradient(ellipse at 50% 102%, rgba(255, 143, 35, .42), transparent 38%),
    radial-gradient(ellipse at 95% 100%, rgba(255, 72, 28, .48), transparent 34%),
    linear-gradient(0deg, rgba(232, 71, 25, .18), transparent 43%);
  box-shadow: inset 0 -42px 48px -38px rgba(255, 76, 24, .94), inset 0 -1px 0 rgba(255, 176, 82, .48);
  animation: burn-flicker 1.1s ease-in-out infinite alternate;
}
.tcg-burn-wash::before {
  content: "";
  position: absolute;
  inset: auto 5% 0;
  height: 28%;
  background: radial-gradient(ellipse at 15% 100%, rgba(255, 112, 35, .65), transparent 58%), radial-gradient(ellipse at 52% 100%, rgba(255, 165, 55, .48), transparent 62%), radial-gradient(ellipse at 86% 100%, rgba(255, 91, 30, .62), transparent 58%);
  filter: blur(5px);
  animation: burn-flame 1.35s ease-in-out infinite alternate;
}
.burn-ember {
  position: absolute;
  bottom: 10%;
  width: 4px;
  height: 4px;
  border-radius: 50%;
  background: #ffe4a0;
  box-shadow: 0 0 7px 3px rgba(255, 106, 35, .78);
  animation: ember-rise 1.9s ease-out infinite;
}
.ember-one { left: 17%; }.ember-two { left: 55%; animation-delay: -.8s; }.ember-three { right: 16%; width: 3px; height: 3px; animation-delay: -.3s; }

.tcg-freeze-vfx {
  background: linear-gradient(135deg, rgba(211, 249, 255, .36), transparent 28%, transparent 66%, rgba(102, 203, 255, .30)), radial-gradient(ellipse at 50% 100%, rgba(62, 164, 238, .28), transparent 54%);
  box-shadow: inset 0 0 0 2px rgba(181, 239, 255, .72), inset 0 0 30px rgba(89, 198, 255, .34), 0 0 16px rgba(75, 183, 255, .36);
  animation: frost-pulse 2.2s ease-in-out infinite;
}
.tcg-frost-corner { position: absolute; width: 27px; height: 27px; border-color: rgba(244, 255, 255, .98); border-style: solid; filter: drop-shadow(0 0 5px #53d4ff); }
.tcg-frost-corner.top-left { top: 2px; left: 2px; border-width: 3px 0 0 3px; border-radius: 12px 0 0; }
.tcg-frost-corner.top-right { top: 2px; right: 2px; border-width: 3px 3px 0 0; border-radius: 0 12px 0 0; }
.tcg-frost-corner.bottom-left { bottom: 2px; left: 2px; border-width: 0 0 3px 3px; border-radius: 0 0 0 12px; }
.tcg-frost-corner.bottom-right { right: 2px; bottom: 2px; border-width: 0 3px 3px 0; border-radius: 0 0 12px; }
.tcg-frost-glint { position: absolute; width: 6px; height: 6px; border-radius: 50%; background: #fff; box-shadow: 0 0 10px 4px #70dcff; animation: glint 1.7s ease-in-out infinite alternate; }
.glint-one { top: 18%; left: 8%; }.glint-two { right: 9%; bottom: 25%; animation-delay: -.9s; }
.tcg-frost-crack { position: absolute; width: 42px; height: 34px; opacity: .8; background: linear-gradient(145deg, transparent 46%, rgba(230, 252, 255, .92) 48%, transparent 52%), linear-gradient(35deg, transparent 48%, rgba(202, 245, 255, .78) 50%, transparent 53%); filter: drop-shadow(0 0 3px #60cfff); }
.crack-one { top: 6%; right: 6%; }.crack-two { bottom: 7%; left: 6%; transform: rotate(180deg); }

/* Stun: keep the clear lightning flicker already used in battle. */
.tcg-stun-vfx { background: radial-gradient(ellipse at 50% 0, rgba(255, 231, 120, .24), transparent 48%), radial-gradient(ellipse at 50% 100%, rgba(255, 204, 65, .2), transparent 45%); }
.tcg-stun-vfx svg { position: absolute; inset: 0; width: 100%; height: 100%; overflow: visible; }
.tcg-stun-vfx path { fill: none; stroke: #fff4a9; stroke-width: 3; stroke-linecap: round; stroke-linejoin: round; filter: drop-shadow(0 0 4px #ffbd28) drop-shadow(0 0 8px #ff8d00); stroke-dasharray: 48; animation: lightning .9s ease-in-out infinite; }
.tcg-stun-vfx path:nth-child(2) { animation-delay: -.38s; }
.tcg-stun-spark { position: absolute; width: 6px; height: 6px; border-radius: 50%; background: #fff8c2; box-shadow: 0 0 10px 5px #ffc52c; animation: glint .46s steps(2, end) infinite alternate; }
.spark-one { top: 20%; right: 10%; }.spark-two { bottom: 21%; left: 11%; animation-delay: -.2s; }

.tcg-poison-vfx {
  background: radial-gradient(ellipse at 5% 80%, rgba(91, 214, 84, .40), transparent 43%), radial-gradient(ellipse at 94% 18%, rgba(164, 91, 205, .36), transparent 43%), linear-gradient(0deg, rgba(73, 169, 73, .14), transparent 52%);
  box-shadow: inset 0 -24px 32px -24px rgba(120, 239, 103, .9), inset 0 0 0 1px rgba(179, 239, 143, .25);
  animation: poison-breathe 2.7s ease-in-out infinite alternate;
}
.tcg-poison-bubble { position: absolute; bottom: 8%; width: 9px; height: 9px; border: 1px solid rgba(226, 255, 190, .96); border-radius: 50%; background: rgba(115, 213, 93, .54); box-shadow: 0 0 11px rgba(124, 242, 110, .9); animation: bubble-rise 2.35s ease-in infinite; }
.bubble-one { left: 17%; }.bubble-two { left: 78%; width: 6px; height: 6px; animation-delay: -1.2s; }.bubble-three { left: 52%; width: 5px; height: 5px; animation-delay: -.5s; }.bubble-four { left: 34%; width: 4px; height: 4px; animation-delay: -1.65s; }

.tcg-curse-vfx { background: radial-gradient(ellipse at 50% 100%, rgba(82, 38, 137, .42), transparent 57%), linear-gradient(145deg, rgba(51, 25, 77, .18), transparent 58%); box-shadow: inset 0 0 0 1px rgba(181, 129, 230, .56), inset 0 -22px 28px -23px rgba(143, 82, 210, .94), 0 0 12px rgba(110, 63, 170, .30); animation: curse-breathe 2.6s ease-in-out infinite alternate; }
.tcg-curse-rune { position: absolute; color: rgba(235, 210, 255, .96); font-style: normal; text-shadow: 0 0 9px #a65bff, 0 0 16px #8d3ee5; animation: rune-float 3.3s ease-in-out infinite alternate; }
.rune-one { top: 17%; left: 8%; font-size: 17px; }.rune-two { top: 42%; right: 8%; font-size: 21px; animation-delay: -1.2s; }.rune-three { bottom: 11%; left: 42%; font-size: 15px; animation-delay: -2s; }

@keyframes shield-breathe { 0%, 100% { opacity: .72; } 50% { opacity: 1; } }
@keyframes shield-reflection { 0%, 22% { transform: translateX(0) rotate(18deg); opacity: 0; } 42% { opacity: .68; } 75%, 100% { transform: translateX(430%) rotate(18deg); opacity: 0; } }
@keyframes burn-flicker { from { opacity: .78; filter: saturate(.95) brightness(.96); } to { opacity: 1; filter: saturate(1.18) brightness(1.1); } }
@keyframes burn-flame { from { transform: scaleY(.82); opacity: .68; } to { transform: scaleY(1.15); opacity: 1; } }
@keyframes ember-rise { 0% { transform: translateY(6px) scale(.6); opacity: 0; } 20% { opacity: 1; } 100% { transform: translateY(-52px) scale(.2); opacity: 0; } }
@keyframes frost-pulse { 0%, 100% { opacity: .78; } 50% { opacity: 1; } }
@keyframes glint { from { opacity: .4; transform: scale(.7); } to { opacity: 1; transform: scale(1.18); } }
@keyframes lightning { 0%, 100% { opacity: .45; stroke-dashoffset: 48; } 35% { opacity: 1; stroke-dashoffset: 0; } 58% { opacity: .38; } }
@keyframes poison-breathe { from { opacity: .7; } to { opacity: 1; } }
@keyframes bubble-rise { 0% { transform: translateY(10px) scale(.55); opacity: 0; } 22% { opacity: .9; } 100% { transform: translateY(-88px) scale(1.2); opacity: 0; } }
@keyframes curse-breathe { from { opacity: .64; } to { opacity: 1; } }
@keyframes rune-float { from { transform: translateY(4px) rotate(-8deg); opacity: .58; } to { transform: translateY(-5px) rotate(10deg); opacity: 1; } }
@media (prefers-reduced-motion: reduce) { .tcg-status-vfx * { animation: none !important; } }
</style>
