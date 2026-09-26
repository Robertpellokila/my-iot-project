<script setup>
const props = defineProps({
  visible: {
    type: Boolean,
    default: false,
  },
  round: {
    type: Number,
    default: 1,
  },
  loading: {
    type: Boolean,
    default: false,
  },
  error: {
    type: String,
    default: null,
  },
  question: {
    type: Object,
    default: null,
  },
  selectedAnswer: {
    type: Number,
    default: null,
  },
  result: {
    type: String,
    default: null,
  },
  allowAnswer: {
    type: Boolean,
    default: true,
  },
  allowContinue: {
    type: Boolean,
    default: true,
  },
});

const emit = defineEmits([
  "answer",
  "continue",
]);
</script>

<template>
  <Transition name="question">
    <div
      v-if="visible"
      class="question-overlay"
    >
      <section class="question-panel">
        <div class="question-kicker">
          🧠 CODING CHALLENGE • ROUND {{ round }}
        </div>

        <h2>
          QUESTION BREAK
        </h2>

        <div
          v-if="loading"
          class="question-loading"
        >
          Loading question from database...
        </div>

        <div
          v-else-if="error"
          class="question-error"
        >
          <strong>
            Question unavailable
          </strong>

          <span>
            {{ error }}
          </span>

          <button
            v-if="allowContinue"
            type="button"
            @click="
              emit('continue')
            "
          >
            CONTINUE BATTLE
          </button>
        </div>

        <template
          v-else-if="question"
        >
          <p class="question-text">
            {{ question.question }}
          </p>

          <div class="question-options">
            <button
              v-for="
                (option, index)
                in question.options
              "
              :key="
                `${question.id}-${index}`
              "
              type="button"
              class="question-option"
              :class="{
                selected:
                  selectedAnswer ===
                  index,

                correct:
                  result &&
                  index ===
                    question.correctIndex,

                wrong:
                  result ===
                    'wrong' &&
                  selectedAnswer ===
                    index,
              }"
              :disabled="
                !!result ||
                !allowAnswer
              "
              @click="
                emit(
                  'answer',
                  index
                )
              "
            >
              <span
                class="
                  option-letter
                "
              >
                {{
                  String
                    .fromCharCode(
                      65 + index
                    )
                }}
              </span>

              <span>
                {{ option }}
              </span>
            </button>
          </div>

          <div
            v-if="result"
            class="question-result"
            :class="result"
          >
            <strong>
              {{
                result ===
                  "correct"
                  ? "✅ CORRECT!"
                  : "❌ WRONG!"
              }}
            </strong>

            <p
              v-if="
                question.explanation
              "
            >
              {{
                question.explanation
              }}
            </p>

            <button
              v-if="allowContinue"
              type="button"
              @click="
                emit('continue')
              "
            >
              CONTINUE BATTLE
            </button>
          </div>
        </template>
      </section>
    </div>
  </Transition>
</template>

<style scoped>
.question-overlay {
  position: absolute;
  inset: 0;
  z-index: 500;
  display: grid;
  place-items: center;
  padding: 30px;
  background: rgba(0, 5, 16, .86);
  backdrop-filter: blur(10px);
}

.question-panel {
  width: min(760px, 88vw);
  max-height: 86vh;
  overflow-y: auto;
  padding: 28px;
  border: 2px solid rgba(77, 210, 255, .72);
  border-radius: 20px;
  background:
    radial-gradient(circle at top, rgba(18, 105, 170, .25), transparent 45%),
    linear-gradient(145deg, #0a1830, #030817);
  box-shadow: 0 0 55px rgba(0, 171, 255, .25);
}

.question-kicker {
  color: #ffe767;
  text-align: center;
  font-size: 9px;
  font-weight: 1000;
  letter-spacing: .12em;
}

.question-panel h2 {
  margin: 7px 0 20px;
  text-align: center;
  font-size: 29px;
}

.question-text {
  margin: 0 0 18px;
  text-align: center;
  color: #eef8ff;
  font-size: 18px;
  font-weight: 800;
  line-height: 1.45;
}

.question-options {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 10px;
}

.question-option {
  min-height: 62px;
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 11px 13px;
  text-align: left;
  border: 1px solid rgba(117, 196, 255, .35);
  border-radius: 11px;
  color: #eaf7ff;
  background: rgba(12, 41, 70, .78);
  cursor: pointer;
  font-size: 12px;
  font-weight: 750;
  transition: .18s ease;
}

.question-option:hover:not(:disabled) {
  border-color: #6addff;
  transform: translateY(-2px);
  background: rgba(17, 77, 119, .9);
}

.question-option.selected {
  border-color: #ffe45f;
}

.question-option.correct {
  border-color: #55ff9c;
  background: rgba(18, 112, 67, .56);
}

.question-option.wrong {
  border-color: #ff5c76;
  background: rgba(137, 20, 45, .58);
}

.option-letter {
  width: 30px;
  height: 30px;
  flex: 0 0 30px;
  display: grid;
  place-items: center;
  border-radius: 50%;
  color: #05101d;
  background: #7cddff;
  font-size: 11px;
  font-weight: 1000;
}

.question-result,
.question-error,
.question-loading {
  margin-top: 18px;
  padding: 14px;
  text-align: center;
  border-radius: 11px;
}

.question-loading {
  color: #92ddff;
  background: rgba(17, 73, 109, .38);
}

.question-error {
  display: flex;
  flex-direction: column;
  gap: 8px;
  color: #ff9cad;
  background: rgba(105, 16, 35, .45);
}

.question-result.correct {
  color: #75ffae;
  background: rgba(21, 108, 65, .38);
}

.question-result.wrong {
  color: #ff8ca0;
  background: rgba(118, 20, 43, .38);
}

.question-result p {
  margin: 7px 0 0;
  color: #d7e6f5;
  font-size: 10px;
  line-height: 1.5;
}

.question-result button,
.question-error button {
  margin-top: 10px;
  padding: 9px 18px;
  border: none;
  border-radius: 7px;
  color: #05101d;
  background: #ffe35b;
  cursor: pointer;
  font-size: 9px;
  font-weight: 1000;
}

.question-enter-active,
.question-leave-active {
  transition: opacity .25s ease;
}

.question-enter-from,
.question-leave-to {
  opacity: 0;
}

@media (max-width: 900px) {
  .question-options {
    grid-template-columns: 1fr;
  }
}
</style>
