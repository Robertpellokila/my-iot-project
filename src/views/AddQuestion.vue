<script setup>
import SearchableSelect from "../components/SearchableSelect.vue";
import { ref, computed } from 'vue';
import { supabase } from '../lib/supabase';
import { compressImageFile, IMAGE_UPLOAD_LIMITS } from '../lib/compressImage';

const form = ref({
  question: '',
  question_type: 'choice',
  blocks_text: '',
  code_snippet: '',
  bug_line: 0,
  hint_1: '',
  hint_2: '',
  learning_topic: '',
  learning_url: '',
  option_a: '',
  option_b: '',
  option_c: '',
  option_d: '',
  correct_answer: 'A',
  explanation: '',
  category: 'programming',
  difficulty: 'easy',
  is_active: true,
});

const isSubmitting = ref(false);
const successMessage = ref('');
const errorMessage = ref('');
const selectedImage = ref(null);
const imagePreview = ref('');
const currentImageUrl = ref('');
const compressingImage = ref(false);
const questionImageStatus = computed(() => selectedImage.value
  ? `${Math.ceil(selectedImage.value.size / 1024)} KB WebP setelah kompres`
  : 'JPG/PNG/WebP · maks. 10 MB · hasil WebP maks. 1 MB');

const categories = [
  'programming',
  'javascript',
  'html',
  'css',
  'database',
  'algorithm',
  'scratch',
  'block_coding',
  'programming_basics',
  'general',
];

const difficulties = [
  'easy',
  'medium',
  'hard',
];

const answerOptions = [
  {
    value: 'A',
    label: 'Option A',
  },
  {
    value: 'B',
    label: 'Option B',
  },
  {
    value: 'C',
    label: 'Option C',
  },
  {
    value: 'D',
    label: 'Option D',
  },
];

const isFormValid = computed(() => {
  if (!form.value.question.trim()) return false;
  if (form.value.question_type === 'block_order') {
    return form.value.blocks_text.split('\n').map((line) => line.trim()).filter(Boolean).length >= 2;
  }
  if (form.value.question_type === 'find_bug') {
    const lineCount = form.value.code_snippet.split('\n').filter((line) => line.trim()).length;
    return lineCount >= 2 && lineCount <= 4 && Number(form.value.bug_line) < lineCount;
  }
  return (
    form.value.option_a.trim() &&
    form.value.option_b.trim() &&
    form.value.option_c.trim() &&
    form.value.option_d.trim() &&
    form.value.correct_answer
  );
});

const resetForm = () => {
  if (imagePreview.value.startsWith('blob:')) URL.revokeObjectURL(imagePreview.value);
  selectedImage.value = null;
  imagePreview.value = '';
  currentImageUrl.value = '';
  form.value = {
    question: '',
    question_type: 'choice',
    blocks_text: '',
    code_snippet: '',
    bug_line: 0,
    hint_1: '',
    hint_2: '',
    learning_topic: '',
    learning_url: '',
    option_a: '',
    option_b: '',
    option_c: '',
    option_d: '',
    correct_answer: 'A',
    explanation: '',
    category: 'programming',
    difficulty: 'easy',
    is_active: true,
  };
};

const selectQuestionImage = async (event) => {
  const file = event.target.files?.[0] ?? null;
  errorMessage.value = '';
  if (imagePreview.value.startsWith('blob:')) URL.revokeObjectURL(imagePreview.value);
  selectedImage.value = null;
  imagePreview.value = currentImageUrl.value;
  if (!file) return;
  compressingImage.value = true;
  try {
    const compressed = await compressImageFile(file, {
      maxSourceBytes: IMAGE_UPLOAD_LIMITS.sourceBytes,
      maxOutputBytes: IMAGE_UPLOAD_LIMITS.outputBytes,
      maxDimension: IMAGE_UPLOAD_LIMITS.maxDimension,
    });
    selectedImage.value = compressed;
    imagePreview.value = URL.createObjectURL(compressed);
  } catch (error) {
    errorMessage.value = error?.message ?? 'Gagal mengompres gambar.';
    event.target.value = '';
  } finally {
    compressingImage.value = false;
  }
};

const submitQuestion = async () => {
  if (compressingImage.value || isSubmitting.value) return;
  if (!isFormValid.value) {
    errorMessage.value =
      'Lengkapi pertanyaan dan bahan interaktif sesuai jenis soal.';
    return;
  }

  isSubmitting.value = true;

  successMessage.value = '';
  errorMessage.value = '';

  try {
    let imageUrl = currentImageUrl.value || null;
    if (selectedImage.value) {
      const file = selectedImage.value;
      const path = `${crypto.randomUUID()}.webp`;
      const { error: uploadError } = await supabase.storage
        .from('quiz-images')
        .upload(path, file, { cacheControl: '3600', upsert: false, contentType: 'image/webp' });
      if (uploadError) throw uploadError;
      imageUrl = supabase.storage.from('quiz-images').getPublicUrl(path).data.publicUrl;
    }
    const orderedBlocks = form.value.blocks_text
      .split('\n').map((line) => line.trim()).filter(Boolean);
    const codeLines = form.value.code_snippet
      .split('\n').map((line) => line.trim()).filter(Boolean);
    const isBlockOrder = form.value.question_type === 'block_order';
    const isFindBug = form.value.question_type === 'find_bug';
    const answerLetter = isBlockOrder
      ? 'A'
      : isFindBug
        ? String.fromCharCode(65 + Number(form.value.bug_line))
        : form.value.correct_answer;
    const payload = {
      question:
        form.value.question.trim(),

      question_type:
        form.value.question_type,

      blocks:
        isBlockOrder ? orderedBlocks : [],

      correct_sequence:
        isBlockOrder ? orderedBlocks.map((_, index) => index) : [],

      code_snippet:
        isFindBug ? codeLines.join('\n') : null,

      bug_line:
        isFindBug ? Number(form.value.bug_line) : null,

      image_url: imageUrl,

      option_a:
        isBlockOrder ? 'Urutan sudah benar' : isFindBug ? 'Baris 1' : form.value.option_a.trim(),

      option_b:
        isBlockOrder ? 'Urutan belum benar' : isFindBug ? 'Baris 2' : form.value.option_b.trim(),

      option_c:
        isBlockOrder ? 'Coba lagi' : isFindBug ? 'Baris 3' : form.value.option_c.trim(),

      option_d:
        isBlockOrder ? 'Belum disusun' : isFindBug ? 'Baris 4' : form.value.option_d.trim(),

      correct_answer:
        answerLetter,

      explanation:
        form.value.explanation.trim() ||
        null,

      hint_1: form.value.hint_1.trim() || null,
      hint_2: form.value.hint_2.trim() || null,
      learning_topic: form.value.learning_topic.trim() || form.value.category,
      learning_url: form.value.learning_url.trim() || null,

      category:
        form.value.category,

      difficulty:
        form.value.difficulty,

      // Keep both level columns aligned: battle setup and older question
      // pickers read different columns in existing installations.
      level:
        form.value.difficulty,

      is_active:
        form.value.is_active,
    };

    const {
      data,
      error,
    } = await supabase
      .from('coding_questions')
      .insert(payload)
      .select()
      .single();

    if (error) {
      throw error;
    }

    console.log(
      'Question created:',
      data
    );

    successMessage.value =
      'Question berhasil ditambahkan.';

    resetForm();
  } catch (error) {
    console.error(error);

    errorMessage.value =
      error.message ||
      'Gagal menambahkan question.';
  } finally {
    isSubmitting.value = false;
  }
};
</script>

<template>
  <div class="question-page">

    <div class="page-background" />

    <div class="question-container">

      <!-- HEADER -->

      <header class="page-header">

        <div>
          <span class="eyebrow">
            BATTLE ARENA ADMIN
          </span>

          <h1>
            Add Coding Question
          </h1>

          <p>
            Tambahkan question baru
            untuk Coding Challenge
            pada Battle Arena.
          </p>
        </div>

        <div class="header-icon">
          🧠
        </div>

      </header>

      <!-- ALERT -->

      <Transition name="alert">
        <div
          v-if="successMessage"
          class="alert alert-success"
        >
          <span>✓</span>

          {{ successMessage }}
        </div>
      </Transition>

      <Transition name="alert">
        <div
          v-if="errorMessage"
          class="alert alert-error"
        >
          <span>!</span>

          {{ errorMessage }}
        </div>
      </Transition>

      <!-- FORM -->

      <form
        class="question-form"
        @submit.prevent="submitQuestion"
      >

        <!-- QUESTION -->

        <section class="form-section">

          <div class="section-heading">
            <span class="step">
              01
            </span>

            <div>
              <h2>
                Question
              </h2>

              <p>
                Masukkan pertanyaan coding.
              </p>
            </div>
          </div>

          <div class="field-group">

            <label for="question-type">Question format</label>
            <SearchableSelect id="question-type" v-model="form.question_type">
              <option value="choice">Pilihan ganda</option>
              <option value="block_order">Susun blok Scratch</option>
              <option value="find_bug">Temukan baris bermasalah</option>
            </SearchableSelect>

            <small class="field-help">
              Pilihan ganda tetap tersedia untuk soal biasa. Format interaktif divalidasi di server.
            </small>

            <label for="question">
              Question Text
            </label>

            <textarea
              id="question"
              v-model="form.question"
              placeholder="Contoh: Apa output dari console.log(2 + 3)?"
              rows="4"
            />

          </div>

          <div v-if="form.question_type === 'block_order'" class="field-group interactive-authoring">
            <label for="scratch-blocks">Urutan blok yang benar</label>
            <textarea id="scratch-blocks" v-model="form.blocks_text" rows="5" placeholder="Ketika bendera hijau diklik&#10;Ulangi 3 kali&#10;Gerak 10 langkah" />
            <small class="field-help">Tulis satu blok per baris dalam urutan yang benar. Saat bermain, urutannya akan diacak.</small>
          </div>

          <div v-else-if="form.question_type === 'find_bug'" class="field-group interactive-authoring">
            <label for="question-code">Potongan blok / kode</label>
            <textarea id="question-code" v-model="form.code_snippet" rows="5" placeholder="when green flag clicked&#10;repeat 5&#10;move -10 steps&#10;say Done" />
            <label for="bug-line">Baris yang bermasalah</label>
            <SearchableSelect id="bug-line" v-model.number="form.bug_line">
              <option v-for="(line, index) in form.code_snippet.split('\n').filter((item) => item.trim())" :key="index" :value="index">Baris {{ index + 1 }} · {{ line }}</option>
            </SearchableSelect>
            <small class="field-help">Maksimal empat baris supaya pemain dapat memilih satu baris secara langsung.</small>
          </div>

          <div class="field-group image-upload-group">
            <label for="question-image">Question Image <span class="optional-label">OPSIONAL · WEBP OTOMATIS</span></label>
            <input id="question-image" type="file" accept="image/png,image/jpeg,image/webp" :disabled="compressingImage || isSubmitting" @change="selectQuestionImage" />
            <small>{{ compressingImage ? 'Mengompres gambar ke WebP…' : questionImageStatus }}</small>
            <img v-if="imagePreview" class="question-image-preview" :src="imagePreview" alt="Preview gambar soal" />
          </div>

        </section>

        <!-- OPTIONS -->

        <section v-if="form.question_type === 'choice'" class="form-section">

          <div class="section-heading">

            <span class="step">
              02
            </span>

            <div>
              <h2>
                Answer Options
              </h2>

              <p>
                Isi empat pilihan jawaban.
              </p>
            </div>

          </div>

          <div class="options-grid">

            <div class="field-group option-field">

              <label>
                <span class="option-badge">
                  A
                </span>

                Option A
              </label>

              <input
                v-model="form.option_a"
                type="text"
                placeholder="Jawaban A"
              >

            </div>

            <div class="field-group option-field">

              <label>
                <span class="option-badge">
                  B
                </span>

                Option B
              </label>

              <input
                v-model="form.option_b"
                type="text"
                placeholder="Jawaban B"
              >

            </div>

            <div class="field-group option-field">

              <label>
                <span class="option-badge">
                  C
                </span>

                Option C
              </label>

              <input
                v-model="form.option_c"
                type="text"
                placeholder="Jawaban C"
              >

            </div>

            <div class="field-group option-field">

              <label>
                <span class="option-badge">
                  D
                </span>

                Option D
              </label>

              <input
                v-model="form.option_d"
                type="text"
                placeholder="Jawaban D"
              >

            </div>

          </div>

        </section>

        <!-- CORRECT ANSWER -->

        <section v-if="form.question_type === 'choice'" class="form-section">

          <div class="section-heading">

            <span class="step">
              03
            </span>

            <div>

              <h2>
                Correct Answer
              </h2>

              <p>
                Tentukan jawaban yang benar.
              </p>

            </div>

          </div>

          <div class="answer-selector">

            <label
              v-for="answer in answerOptions"
              :key="answer.value"
              class="answer-card"
              :class="{
                selected:
                  form.correct_answer ===
                  answer.value
              }"
            >

              <input
                v-model="form.correct_answer"
                type="radio"
                :value="answer.value"
              >

              <span class="answer-letter">
                {{ answer.value }}
              </span>

              <span>
                {{ answer.label }}
              </span>

              <span
                v-if="
                  form.correct_answer ===
                  answer.value
                "
                class="check"
              >
                ✓
              </span>

            </label>

          </div>

        </section>

        <!-- EXPLANATION -->

        <section class="form-section">

          <div class="section-heading">

            <span class="step">
              04
            </span>

            <div>

              <h2>
                Explanation
              </h2>

              <p>
                Jelaskan kenapa jawaban
                tersebut benar.
              </p>

            </div>

          </div>

          <div class="field-group">

            <textarea
              v-model="form.explanation"
              rows="4"
              placeholder="Contoh: Operator + menjumlahkan dua nilai bertipe number."
            />

          </div>

        </section>

        <section class="form-section">
          <div class="section-heading">
            <span class="step">05</span>
            <div>
              <h2>Petunjuk & materi belajar</h2>
              <p>Petunjuk muncul bertahap. Materi ini direkomendasikan setelah jawaban keliru.</p>
            </div>
          </div>
          <div class="settings-grid">
            <div class="field-group">
              <label for="hint-1">Petunjuk pertama</label>
              <textarea id="hint-1" v-model="form.hint_1" rows="2" placeholder="Arahkan siswa ke konsep yang perlu diperhatikan." />
            </div>
            <div class="field-group">
              <label for="hint-2">Petunjuk kedua</label>
              <textarea id="hint-2" v-model="form.hint_2" rows="2" placeholder="Berikan petunjuk yang lebih spesifik." />
            </div>
            <div class="field-group">
              <label for="learning-topic">Nama materi</label>
              <input id="learning-topic" v-model="form.learning_topic" type="text" placeholder="Contoh: Scratch · perulangan" />
            </div>
            <div class="field-group">
              <label for="learning-url">Tautan materi (opsional)</label>
              <input id="learning-url" v-model="form.learning_url" type="url" placeholder="https://..." />
            </div>
          </div>
        </section>

        <!-- SETTINGS -->

        <section class="form-section">

          <div class="section-heading">

            <span class="step">
              06
            </span>

            <div>

              <h2>
                Question Settings
              </h2>

              <p>
                Atur kategori dan tingkat
                kesulitan.
              </p>

            </div>

          </div>

          <div class="settings-grid">

            <!-- CATEGORY -->

            <div class="field-group">

              <label>
                Category
              </label>

              <SearchableSelect
                v-model="form.category"
              >
                <option
                  v-for="category in categories"
                  :key="category"
                  :value="category"
                >
                  {{ category }}
                </option>
              </SearchableSelect>

            </div>

            <!-- DIFFICULTY -->

            <div class="field-group">

              <label>
                Difficulty
              </label>

              <SearchableSelect
                v-model="form.difficulty"
              >
                <option
                  v-for="difficulty in difficulties"
                  :key="difficulty"
                  :value="difficulty"
                >
                  {{ difficulty }}
                </option>
              </SearchableSelect>

            </div>

          </div>

          <!-- ACTIVE -->

          <label class="active-toggle">

            <input
              v-model="form.is_active"
              type="checkbox"
            >

            <span class="toggle">
              <span />
            </span>

            <div>

              <strong>
                Active Question
              </strong>

              <small>
                Question dapat digunakan
                oleh Battle Arena.
              </small>

            </div>

          </label>

        </section>

        <!-- PREVIEW -->

        <section class="preview-section">

          <div class="preview-title">

            <span>
              LIVE PREVIEW
            </span>

            <strong>
              🧠 Coding Challenge
            </strong>

          </div>

          <div class="preview-question">

            {{
              form.question ||
              'Question akan tampil di sini...'
            }}

          </div>

          <img v-if="imagePreview" class="preview-image" :src="imagePreview" alt="Gambar pada preview soal" />

          <div class="preview-options">

            <div
              v-for="letter in ['A', 'B', 'C', 'D']"
              :key="letter"
              class="preview-option"
              :class="{
                correct:
                  form.correct_answer ===
                  letter
              }"
            >

              <span>
                {{ letter }}
              </span>

              <p>
                {{
                  form[
                    `option_${letter.toLowerCase()}`
                  ] ||
                  `Option ${letter}`
                }}
              </p>

            </div>

          </div>

          <div class="preview-meta">

            <span>
              {{ form.category }}
            </span>

            <span>
              {{ form.difficulty }}
            </span>

            <span
              :class="{
                active:
                  form.is_active
              }"
            >
              {{
                form.is_active
                  ? 'ACTIVE'
                  : 'DISABLED'
              }}
            </span>

          </div>

        </section>

        <!-- ACTION -->

        <div class="form-actions">

          <button
            type="button"
            class="reset-button"
            :disabled="isSubmitting || compressingImage"
            @click="resetForm"
          >
            RESET
          </button>

          <button
            type="submit"
            class="submit-button"
            :disabled="
              !isFormValid ||
              isSubmitting || compressingImage
            "
          >

            <template
              v-if="isSubmitting || compressingImage"
            >
              <span class="spinner" />

              {{ compressingImage ? 'COMPRESSING IMAGE…' : 'SAVING...' }}
            </template>

            <template v-else>
              + ADD QUESTION
            </template>

          </button>

        </div>

      </form>

    </div>

  </div>
</template>

<style scoped>
* {
  box-sizing: border-box;
}

.question-page {
  width: 100%;
  min-height: 100vh;

  position: relative;

  padding: 50px 24px;

  overflow: hidden;

  color: white;

  background:
    #030816;

  font-family:
    Inter,
    ui-sans-serif,
    system-ui,
    sans-serif;
}

.page-background {
  position: fixed;

  inset: 0;

  pointer-events: none;

  background:
    radial-gradient(
      circle at 15% 10%,
      rgba(0, 157, 255, .18),
      transparent 35%
    ),
    radial-gradient(
      circle at 85% 20%,
      rgba(139, 40, 255, .13),
      transparent 32%
    ),
    radial-gradient(
      circle at 50% 100%,
      rgba(0, 225, 190, .08),
      transparent 40%
    );
}

.question-container {
  width: 100%;

  max-width: 1100px;

  margin: 0 auto;

  position: relative;

  z-index: 2;
}

.page-header {
  display: flex;

  justify-content: space-between;
  align-items: center;

  gap: 30px;

  margin-bottom: 32px;

  padding: 28px 32px;

  border:
    1px solid
    rgba(81, 188, 255, .25);

  border-radius: 20px;

  background:
    linear-gradient(
      135deg,
      rgba(12, 33, 66, .94),
      rgba(5, 13, 31, .95)
    );

  box-shadow:
    0 30px 70px
    rgba(0, 0, 0, .35);
}

.eyebrow {
  color: #59d5ff;

  font-size: 11px;

  font-weight: 900;

  letter-spacing: .2em;
}

.page-header h1 {
  margin:
    7px 0 7px;

  font-size: 34px;
}

.page-header p {
  margin: 0;

  color: #94a6c1;

  font-size: 14px;
}

.header-icon {
  width: 80px;
  height: 80px;

  flex-shrink: 0;

  display: grid;

  place-items: center;

  border:
    1px solid
    rgba(98, 217, 255, .35);

  border-radius: 20px;

  background:
    rgba(29, 131, 193, .13);

  font-size: 40px;

  box-shadow:
    inset 0 0 35px
    rgba(54, 192, 255, .1);
}

/* ALERT */

.alert {
  margin-bottom: 20px;

  padding: 15px 18px;

  display: flex;

  gap: 10px;

  align-items: center;

  border-radius: 12px;

  font-size: 13px;

  font-weight: 800;
}

.alert-success {
  border:
    1px solid
    rgba(69, 255, 149, .35);

  color: #72ffac;

  background:
    rgba(20, 134, 72, .14);
}

.alert-error {
  border:
    1px solid
    rgba(255, 72, 102, .4);

  color: #ff91a5;

  background:
    rgba(166, 20, 51, .14);
}

.alert-enter-active,
.alert-leave-active {
  transition: all .25s ease;
}

.alert-enter-from,
.alert-leave-to {
  opacity: 0;

  transform:
    translateY(-10px);
}

/* FORM */

.question-form {
  display: flex;

  flex-direction: column;

  gap: 18px;
}

.form-section {
  padding: 26px;

  border:
    1px solid
    rgba(255, 255, 255, .08);

  border-radius: 18px;

  background:
    rgba(6, 17, 38, .88);

  box-shadow:
    0 18px 45px
    rgba(0, 0, 0, .22);
}

.section-heading {
  display: flex;

  gap: 14px;

  align-items: center;

  margin-bottom: 22px;
}

.step {
  width: 40px;
  height: 40px;

  flex-shrink: 0;

  display: grid;

  place-items: center;

  border-radius: 10px;

  color: #62ddff;

  background:
    rgba(40, 161, 221, .12);

  border:
    1px solid
    rgba(88, 210, 255, .25);

  font-size: 10px;

  font-weight: 1000;
}

.section-heading h2 {
  margin: 0;

  font-size: 17px;
}

.section-heading p {
  margin:
    3px 0 0;

  color: #7e91ad;

  font-size: 11px;
}

/* FIELD */

.field-group {
  display: flex;

  flex-direction: column;

  gap: 8px;
}

.field-group label {
  color: #bcc9dc;

  font-size: 11px;

  font-weight: 800;
}
.optional-label { margin-left: 8px; color: #7187a2; font-size: 8px; letter-spacing: .1em; }
.image-upload-group input[type="file"] { width: 100%; padding: 10px; border: 1px dashed #a8d5ad; border-radius: 10px; background: #f5fbf4; color: #48664e; letter-spacing: 0; font-size: 10px; }
.image-upload-group>label { color: #24472c; }
.image-upload-group .optional-label { color: #4c9254; }
.image-upload-group input[type="file"]::file-selector-button { margin-right: 10px; border: 0; border-radius: 7px; padding: 8px 11px; background: #0caf25; color: #fff; font: 800 10px 'DM Sans',sans-serif; cursor: pointer; }
.image-upload-group input[type="file"]:disabled { opacity: .65; cursor: progress; }
.image-upload-group small { color: #5f7963; font-size: 10px; }
.question-image-preview,.preview-image { display: block; max-width: min(100%, 440px); max-height: 260px; object-fit: contain; border: 1px solid #d4e8d4; border-radius: 10px; background: #f1f8ef; }
.preview-image { margin: 0 0 16px; }

input,
textarea,
select {
  width: 100%;

  outline: none;

  border:
    1px solid
    rgba(124, 164, 206, .18);

  border-radius: 10px;

  padding:
    12px 14px;

  color: #f5f9ff;

  background:
    #071126;

  font-size: 13px;

  transition:
    border .2s,
    box-shadow .2s;
}

textarea {
  resize: vertical;

  min-height: 100px;
}

input:focus,
textarea:focus,
select:focus {
  border-color:
    #39cfff;

  box-shadow:
    0 0 0 3px
    rgba(55, 204, 255, .08);
}

.options-grid,
.settings-grid {
  display: grid;

  grid-template-columns:
    repeat(2, minmax(0, 1fr));

  gap: 16px;
}

.option-field label {
  display: flex;

  gap: 7px;

  align-items: center;
}

.option-badge {
  width: 22px;
  height: 22px;

  display: grid;

  place-items: center;

  border-radius: 6px;

  color: #07111f;

  background: #68dcff;

  font-size: 9px;

  font-weight: 1000;
}

/* ANSWER */

.answer-selector {
  display: grid;

  grid-template-columns:
    repeat(4, minmax(0, 1fr));

  gap: 12px;
}

.answer-card {
  min-height: 75px;

  position: relative;

  display: flex;

  align-items: center;

  justify-content: center;

  gap: 8px;

  cursor: pointer;

  border:
    1px solid
    rgba(255, 255, 255, .1);

  border-radius: 12px;

  background:
    rgba(255, 255, 255, .025);

  color: #aabbd1;

  font-size: 11px;

  font-weight: 800;

  transition: all .2s ease;
}

.answer-card input {
  display: none;
}

.answer-card:hover {
  border-color:
    rgba(79, 213, 255, .4);
}

.answer-card.selected {
  color: white;

  border-color:
    #52daff;

  background:
    rgba(40, 167, 220, .13);

  box-shadow:
    0 0 20px
    rgba(44, 190, 255, .08);
}

.answer-letter {
  width: 29px;
  height: 29px;

  display: grid;

  place-items: center;

  border-radius: 8px;

  background:
    #10233e;

  font-weight: 1000;
}

.answer-card.selected
.answer-letter {
  color: #04111d;

  background: #61ddff;
}

.check {
  position: absolute;

  top: 8px;
  right: 9px;

  color: #55f5aa;
}

/* ACTIVE */

.active-toggle {
  margin-top: 18px;

  display: flex;

  align-items: center;

  gap: 12px;

  cursor: pointer;
}

.active-toggle input {
  display: none;
}

.toggle {
  width: 48px;
  height: 27px;

  flex-shrink: 0;

  position: relative;

  border-radius: 999px;

  background: #26354b;

  transition:
    background .2s;
}

.toggle span {
  width: 21px;
  height: 21px;

  position: absolute;

  left: 3px;
  top: 3px;

  border-radius: 50%;

  background: white;

  transition:
    transform .2s;
}

.active-toggle
input:checked +
.toggle {
  background: #14bd7c;
}

.active-toggle
input:checked +
.toggle span {
  transform:
    translateX(21px);
}

.active-toggle strong {
  display: block;

  font-size: 11px;
}

.active-toggle small {
  display: block;

  margin-top: 3px;

  color: #778ba8;

  font-size: 9px;
}

/* PREVIEW */

.preview-section {
  padding: 26px;

  border:
    1px solid
    rgba(242, 210, 72, .18);

  border-radius: 18px;

  background:
    linear-gradient(
      145deg,
      rgba(30, 30, 13, .84),
      rgba(9, 14, 30, .94)
    );
}

.preview-title {
  display: flex;

  justify-content: space-between;

  align-items: center;

  margin-bottom: 18px;
}

.preview-title span {
  color: #eacb4e;

  font-size: 9px;

  font-weight: 1000;

  letter-spacing: .15em;
}

.preview-title strong {
  font-size: 12px;
}

.preview-question {
  margin-bottom: 16px;

  color: white;

  font-size: 18px;

  font-weight: 850;

  line-height: 1.5;
}

.preview-options {
  display: grid;

  grid-template-columns:
    repeat(2, minmax(0, 1fr));

  gap: 10px;
}

.preview-option {
  display: flex;

  align-items: center;

  gap: 9px;

  padding: 11px;

  border:
    1px solid
    rgba(255, 255, 255, .08);

  border-radius: 10px;

  background:
    rgba(255, 255, 255, .025);
}

.preview-option span {
  width: 27px;
  height: 27px;

  flex-shrink: 0;

  display: grid;

  place-items: center;

  border-radius: 7px;

  color: #0b1523;

  background: #9fb0c9;

  font-size: 9px;

  font-weight: 1000;
}

.preview-option p {
  margin: 0;

  color: #b8c3d4;

  font-size: 11px;
}

.preview-option.correct {
  border-color:
    rgba(63, 235, 145, .35);

  background:
    rgba(29, 164, 94, .08);
}

.preview-option.correct span {
  background: #4df19a;
}

.preview-meta {
  margin-top: 17px;

  display: flex;

  gap: 8px;
}

.preview-meta span {
  padding:
    5px 9px;

  border-radius: 999px;

  color: #92a5bd;

  background:
    rgba(255, 255, 255, .05);

  font-size: 8px;

  font-weight: 800;

  text-transform: uppercase;
}

.preview-meta span.active {
  color: #6cffab;

  background:
    rgba(49, 193, 116, .1);
}

/* ACTIONS */

.form-actions {
  display: flex;

  justify-content: flex-end;

  gap: 12px;

  margin-top: 4px;
}

.form-actions button {
  min-width: 145px;

  height: 48px;

  border-radius: 10px;

  cursor: pointer;

  font-size: 10px;

  font-weight: 1000;

  letter-spacing: .05em;
}

.reset-button {
  color: #99acc4;

  border:
    1px solid
    rgba(255, 255, 255, .12);

  background:
    rgba(255, 255, 255, .04);
}

.submit-button {
  border: none;

  color: #04111d;

  background:
    linear-gradient(
      90deg,
      #4ad4ff,
      #66f5cc
    );

  box-shadow:
    0 10px 28px
    rgba(65, 216, 255, .14);
}

.submit-button:disabled,
.reset-button:disabled {
  opacity: .4;

  cursor: not-allowed;
}

.spinner {
  width: 13px;
  height: 13px;

  display: inline-block;

  margin-right: 8px;

  vertical-align: middle;

  border:
    2px solid
    rgba(5, 15, 25, .3);

  border-top-color:
    #06111d;

  border-radius: 50%;

  animation:
    spin .7s linear infinite;
}

@keyframes spin {
  to {
    transform:
      rotate(360deg);
  }
}

/* RESPONSIVE */

@media (
  max-width: 760px
) {

  .question-page {
    padding:
      22px 14px;
  }

  .page-header {
    padding: 22px;

    align-items:
      flex-start;
  }

  .header-icon {
    width: 58px;
    height: 58px;

    font-size: 29px;
  }

  .page-header h1 {
    font-size: 25px;
  }

  .options-grid,
  .settings-grid,
  .preview-options {
    grid-template-columns: 1fr;
  }

  .answer-selector {
    grid-template-columns:
      repeat(2, 1fr);
  }

  .form-actions {
    flex-direction: column;
  }

  .form-actions button {
    width: 100%;
  }
}
</style>
