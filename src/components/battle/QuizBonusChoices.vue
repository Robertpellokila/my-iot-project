<script setup>
import { nextTick, onMounted, onBeforeUnmount, ref } from "vue";
import SkillIcon from "./SkillIcon.vue";
const props = defineProps({
  options: { type: Array, required: true },
  busy: Boolean,
  paused: Boolean,
  selectedCode: String,
  playerName: String,
  explanation: String,
  readonly: Boolean,
});
const emit = defineEmits(["choose"]);
const panel = ref(null);
let previousFocus;
onMounted(async () => {
  if (props.readonly) return;
  previousFocus = document.activeElement;
  await nextTick();
  panel.value?.showModal();
  panel.value?.querySelector("h2")?.focus();
});
onBeforeUnmount(() => {
  if (previousFocus?.isConnected) previousFocus.focus({ preventScroll: true });
});
function choose(option) {
  if (!props.busy && !props.paused && !props.readonly)
    emit("choose", option.code);
}
</script>
<template>
  <component
    :is="readonly ? 'section' : 'dialog'"
    ref="panel"
    class="quiz-bonus-award"
    :class="{ 'is-public': readonly }"
    aria-labelledby="quiz-bonus-award-title"
    :aria-busy="busy"
    @cancel.prevent
  >
    <header>
      <span class="award-kicker">{{
        readonly ? "BONUS KUIS" : "JAWABAN BENAR"
      }}</span>
      <h2 id="quiz-bonus-award-title" tabindex="-1">
        {{
          readonly
            ? `${playerName || "Pemenang kuis"} memilih bonus`
            : "Pilih satu bonus untukmu"
        }}
      </h2>
      <p>
        {{
          readonly
            ? "Pilihan bonus ditampilkan mengikuti aturan match."
            : `${playerName ? `${playerName}, ` : ""}pilih satu dari ${options.length} bonus berikut. Battle berlanjut setelah pilihan tersimpan.`
        }}
      </p>
    </header>
    <div
      class="award-options"
      :style="{ '--award-columns': Math.min(3, options.length) }"
    >
      <button
        v-for="option in options"
        :key="option.code"
        type="button"
        class="award-option"
        :class="{ chosen: selectedCode === option.code }"
        :disabled="busy || paused || readonly"
        @click="choose(option)"
      >
        <span class="award-medallion"
          ><SkillIcon :icon="option.icon" :name="option.name" /><span
            v-if="busy && selectedCode === option.code"
            class="award-saving"
            >Menyimpan…</span
          ></span
        >
        <strong>{{ option.name }}</strong
        ><span class="award-effect">{{ option.summary }}</span
        ><small v-if="option.description">{{ option.description }}</small
        ><span class="award-select">{{
          selectedCode === option.code
            ? "Terpilih"
            : readonly
              ? ""
              : busy
                ? "Tunggu…"
                : "Pilih bonus ini"
        }}</span>
      </button>
    </div>
    <p v-if="paused" class="award-status" role="status">
      Pertandingan dijeda Host. Pilihan dapat dilanjutkan setelah jeda.
    </p>
    <p v-else-if="busy" class="award-status" role="status">
      Menyimpan pilihanmu. Bonus belum dipakai; gunakan nanti saat giliranmu.
    </p>
    <details v-if="explanation" class="award-explanation">
      <summary>Kenapa jawabannya benar?</summary>
      <p>{{ explanation }}</p>
    </details>
    <footer>
      {{
        readonly
          ? "Satu bonus hanya dapat digunakan sekali."
          : "Bonus masuk ke panel Bonus Skills. Gunakan sekali saat giliranmu, tanpa biaya AP."
      }}
    </footer>
  </component>
</template>
<style scoped>
.quiz-bonus-award {
  position: fixed;
  inset: 0;
  margin: auto;
  width: min(1040px, calc(100% - 32px));
  max-height: 90dvh;
  overflow: auto;
  border: 1px solid #c8dfc1;
  border-radius: 24px;
  padding: 32px;
  background: #fbfdf7;
  color: #214531;
  box-shadow: 0 25px 90px #17382c40;
  font-family: Inter, Arial, sans-serif;
  overscroll-behavior: contain;
  box-sizing: border-box;
}
.quiz-bonus-award:not([open]):not(.is-public) {
  display: none;
}
.quiz-bonus-award::backdrop {
  background: #142f236e;
  backdrop-filter: blur(6px);
}
.quiz-bonus-award * {
  box-sizing: border-box;
}
.quiz-bonus-award header {
  text-align: center;
  max-width: 700px;
  margin: 0 auto 28px;
}
.quiz-bonus-award h2:focus {
  outline: none;
}
.award-kicker {
  font-size: 11px;
  font-weight: 850;
  letter-spacing: 0.2em;
  color: #538343;
}
.quiz-bonus-award h2 {
  font:
    750 clamp(25px, 3vw, 36px)/1.2 "Space Grotesk",
    Inter,
    sans-serif;
  letter-spacing: -1px;
  margin: 12px 0;
}
.quiz-bonus-award header p {
  font-size: 13px;
  line-height: 1.8;
  color: #6b8169;
  margin: 0;
}
.award-options {
  display: grid;
  grid-template-columns: repeat(var(--award-columns), minmax(0, 1fr));
  gap: 22px;
  max-width: 920px;
  margin: auto;
}
.award-option {
  display: flex;
  align-items: center;
  flex-direction: column;
  min-width: 0;
  border: 1px solid #dce8d2;
  border-radius: 17px;
  padding: 23px 18px;
  background: #fff;
  color: #254c31;
  font-family: inherit;
  cursor: pointer;
  transition:
    transform 0.15s,
    border-color 0.15s;
}
.award-option:hover:not(:disabled) {
  transform: translateY(-4px);
  border-color: #5c9c5a;
}
.award-medallion {
  position: relative;
  display: grid;
  place-items: center;
  width: 142px;
  height: 142px;
  border-radius: 50%;
  border: 5px solid #f0d47a;
  outline: 2px solid #bc8e29;
  background: radial-gradient(circle at 40% 32%, #fffdd9, #def2c9 65%, #a6cc8c);
  box-shadow:
    inset 0 0 0 5px #fffaf1,
    0 9px 20px #72843a25;
  margin: 4px 0 23px;
}
.award-medallion > :first-child {
  width: 80px;
  height: 80px;
  font-size: 65px;
}
.award-option > strong {
  font-size: 19px;
  line-height: 1.3;
  text-align: center;
  margin-bottom: 12px;
  overflow-wrap: anywhere;
}
.award-effect {
  font-size: 12px;
  line-height: 1.8;
  text-align: center;
  color: #526f53;
}
.award-option > small {
  font-size: 11px;
  line-height: 1.6;
  color: #788975;
  text-align: center;
  margin-top: 8px;
}
.award-select {
  font-size: 11px;
  font-weight: 800;
  color: #2d773f;
  padding-top: 17px;
  margin-top: auto;
}
.award-saving {
  position: absolute;
  inset: auto -4px 10px;
  background: #1b7046;
  color: #fff;
  border-radius: 20px;
  padding: 7px;
  font-size: 10px;
  font-weight: 750;
}
.award-option.chosen {
  border-color: #4c9650;
  background: #edf6e6;
}
.award-option:disabled {
  cursor: default;
}
.award-option:focus-visible,
.award-explanation summary:focus-visible {
  outline: 3px solid #277c91;
  outline-offset: 5px;
}
.award-status {
  font-size: 12px;
  text-align: center;
  color: #377346;
  margin: 20px 0 0;
}
.award-explanation {
  margin: 24px auto 0;
  max-width: 800px;
  border-top: 1px solid #dce6d4;
  padding-top: 18px;
  font-size: 13px;
  line-height: 1.8;
  color: #617b60;
}
.award-explanation summary {
  cursor: pointer;
  font-weight: 700;
}
.quiz-bonus-award footer {
  text-align: center;
  font-size: 11px;
  line-height: 1.8;
  color: #70836b;
  margin-top: 25px;
}
.quiz-bonus-award.is-public {
  position: relative;
  width: 100%;
  max-height: none;
  box-shadow: none;
}
.is-public .award-option {
  opacity: 1;
}
@media (max-width: 680px) {
  .quiz-bonus-award {
    padding: 24px 17px;
    border-radius: 18px;
    width: calc(100% - 20px);
    max-height: 92dvh;
  }
  .award-options {
    grid-template-columns: repeat(2, minmax(0, 1fr));
    gap: 12px;
  }
  .award-options:has(> .award-option:only-child) {
    grid-template-columns: 1fr;
    max-width: 300px;
  }
  .award-option {
    padding: 18px 12px;
  }
  .award-medallion {
    width: 105px;
    height: 105px;
    border-width: 4px;
    margin-bottom: 18px;
  }
  .award-medallion > :first-child {
    width: 58px;
    height: 58px;
    font-size: 48px;
  }
  .award-option > strong {
    font-size: 16px;
  }
  .award-effect {
    font-size: 11px;
  }
  .quiz-bonus-award header {
    margin-bottom: 22px;
  }
  .quiz-bonus-award header p {
    font-size: 12px;
  }
}
@media (prefers-reduced-motion: reduce) {
  .award-option {
    transition: none;
  }
}
</style>
