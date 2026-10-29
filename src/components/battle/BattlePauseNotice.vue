<script setup>
defineProps({ battle: Object });
</script>
<template>
  <aside
    v-if="battle?.teacher_paused"
    class="battle-pause-notice"
    role="status"
    aria-live="polite"
  >
    <b>Ⅱ Pertandingan dijeda Host</b
    ><span>{{
      battle.teacher_pause_reason ||
      "Tunggu instruksi guru. Waktu giliran dan kuis dihentikan sementara."
    }}</span>
  </aside>
</template>
<style scoped>
.battle-pause-notice {
  position: fixed;
  top: 12px;
  left: 50%;
  transform: translateX(-50%);
  z-index: 2147483647;
  width: min(620px, calc(100% - 24px));
  box-sizing: border-box;
  border: 2px solid #d7ac4b;
  border-radius: 12px;
  background: #fff8df;
  color: #594119;
  padding: 13px 20px;
  box-shadow: 0 8px 35px #142b252b;
  text-align: center;
  font:
    14px/1.5 Inter,
    Arial,
    sans-serif;
  pointer-events: none;
}
.battle-pause-notice b,
.battle-pause-notice span {
  display: block;
}
.battle-pause-notice span {
  font-size: 12px;
  overflow-wrap: anywhere;
}
</style>
