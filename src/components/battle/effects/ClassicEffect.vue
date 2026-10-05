<script setup>
/**
 * Compatibility visuals for existing non-Fire statuses. These keep the
 * earlier Phase 3D.22 visual vocabulary in BOTH screens, while each can be
 * replaced later with FreezeEffect.vue, ShieldEffect.vue, etc. by editing
 * effectRegistry.js ONLY. No labels or status calculations are generated.
 */
defineProps({
  kind: { type: String, required: true },
});
</script>

<template>
  <i class="classic-effect" :class="`classic-effect--${kind}`" aria-hidden="true" />
</template>

<style scoped>
.classic-effect {
  position: absolute;
  inset: 0;
  display: block;
  border-radius: inherit;
  pointer-events: none;
}
.classic-effect--fusion {
  background: conic-gradient(from 0deg, transparent, rgba(75,219,255,.15), rgba(151,82,255,.26), transparent, rgba(244,91,205,.16), transparent);
  filter: blur(12px);
  animation: fusion-rotate 7s linear infinite;
}
.classic-effect--necro {
  background: radial-gradient(circle at 15% 90%,rgba(121,36,190,.28),transparent 34%),radial-gradient(circle at 85% 16%,rgba(78,24,145,.22),transparent 30%),radial-gradient(circle at 50% 110%,rgba(38,7,75,.32),transparent 46%);
  animation: necro-breathe 2.8s ease-in-out infinite;
}
.classic-effect--defense {
  inset: 5px;
  border: 2px solid rgba(70,176,255,.65);
  box-shadow: inset 0 0 18px rgba(76,184,255,.13),0 0 14px rgba(50,168,255,.21);
  animation: defense-glow 1.55s ease-in-out infinite;
}
.classic-effect--shield {
  background: linear-gradient(135deg,rgba(186,239,255,.13),rgba(255,255,255,.025) 42%,rgba(109,209,245,.12));
  box-shadow: inset 0 0 0 2px rgba(190,239,255,.40),inset 0 0 26px rgba(91,207,255,.12);
  backdrop-filter: blur(1px) saturate(1.08);
}
.classic-effect--shield::before {
  content: "";
  position: absolute;
  top:-35%; left:-55%; width:46%; height:175%;
  transform:rotate(20deg);
  background:linear-gradient(to right,transparent,rgba(255,255,255,.30),transparent);
  animation:shield-sweep 2.7s ease-in-out infinite;
}
.classic-effect--freeze {
  background: linear-gradient(135deg,rgba(177,233,255,.20),transparent 32%,rgba(113,193,239,.14) 72%,rgba(220,249,255,.18)),radial-gradient(circle at 0 0,rgba(233,252,255,.35),transparent 28%),radial-gradient(circle at 100% 100%,rgba(186,231,255,.28),transparent 30%);
  box-shadow:inset 0 0 24px rgba(133,212,255,.24);
}
.classic-effect--poison {
  background:radial-gradient(circle at 20% 78%,rgba(101,194,77,.20),transparent 25%),radial-gradient(circle at 72% 22%,rgba(137,57,173,.20),transparent 28%),radial-gradient(circle at 82% 86%,rgba(79,164,61,.18),transparent 22%);
  animation:poison-drift 2.4s ease-in-out infinite alternate;
}
.classic-effect--stun {
  background:repeating-linear-gradient(118deg,transparent 0 24px,rgba(255,217,73,.16) 25px 27px,transparent 28px 52px);
  mix-blend-mode:multiply;
  animation:stun-flash .72s steps(2,end) infinite;
}
.classic-effect--curse {
  background: radial-gradient(ellipse at 50% 100%,rgba(80,35,111,.35),transparent 62%),linear-gradient(145deg,rgba(31,17,43,.16),transparent 55%);
  box-shadow:inset 0 0 22px rgba(105,47,138,.2);
  animation:curse-breathe 2.6s ease-in-out infinite alternate;
}
@keyframes fusion-rotate { to { transform: rotate(360deg); } }
@keyframes necro-breathe { 0%,100% {opacity:.62} 50% {opacity:1} }
@keyframes defense-glow { 0%,100% {opacity:.62} 50% {opacity:1} }
@keyframes shield-sweep { 0% {transform:translateX(0) rotate(20deg);opacity:0} 20% {opacity:.8} 100% {transform:translateX(360%) rotate(20deg);opacity:0} }
@keyframes poison-drift { from {transform:translate3d(-2px,2px,0);opacity:.62} to {transform:translate3d(3px,-3px,0);opacity:.92} }
@keyframes stun-flash { 0%,100% {opacity:.22} 50% {opacity:.82} }
@keyframes curse-breathe { from {opacity:.4} to {opacity:.85} }
@media(prefers-reduced-motion:reduce) {
  .classic-effect,.classic-effect::before { animation:none!important; }
}
</style>
