import {
  ref,
} from "vue";


export const useBattleQuestions = ({
  supabase,

  questionTable =
    "coding_questions",

  playSound = null,
} = {}) => {


  // =========================================================
  // STATE
  // =========================================================

  const questionMode =
    ref(false);


  const questionLoading =
    ref(false);


  const questionError =
    ref(null);


  const currentQuestion =
    ref(null);


  const selectedQuestionAnswer =
    ref(null);


  const questionResult =
    ref(null);


  const lastQuestionId =
    ref(null);


  // =========================================================
  // NORMALIZE QUESTION
  // =========================================================

  const normalizeQuestion =
    row => {

      if (
        !row
      ) {

        return null;

      }


      let options =
        [];


      // =====================================================
      // FORMAT 1:
      // options = []
      // =====================================================

      if (
        Array.isArray(
          row.options
        )
      ) {

        options =
          row.options;

      }


      // =====================================================
      // FORMAT 2:
      // options = {}
      // =====================================================

      else if (
        row.options
        &&
        typeof row.options ===
          "object"
      ) {

        options =
          Object.values(
            row.options
          );

      }


      // =====================================================
      // FORMAT 3:
      // option_a
      // option_b
      // option_c
      // option_d
      // =====================================================

      else {

        options = [

          row.option_a ??
            row.a,

          row.option_b ??
            row.b,

          row.option_c ??
            row.c,

          row.option_d ??
            row.d,

        ].filter(
          value =>

            value !==
              undefined

            &&

            value !==
              null

            &&

            String(
              value
            ).trim() !==
              ""
        );

      }


      // =====================================================
      // CORRECT ANSWER
      // =====================================================

      const rawCorrect =

        row.correct_answer ??

        row.correct_option ??

        row.answer ??

        row.correct_index;


      let correctIndex =
        -1;


      // =====================================================
      // NUMBER FORMAT
      // =====================================================

      if (
        typeof rawCorrect ===
        "number"
      ) {

        /*
         * Support:
         *
         * 0,1,2,3
         *
         * maupun:
         *
         * 1,2,3,4
         */

        correctIndex =
          rawCorrect >=
            1

          &&

          rawCorrect <=
            options.length

            ? rawCorrect - 1

            : rawCorrect;

      }


      // =====================================================
      // STRING FORMAT
      // =====================================================

      else {

        const text =
          String(
            rawCorrect ??
            ""
          ).trim();


        const upper =
          text.toUpperCase();


        // ===================================================
        // A / B / C / D
        // ===================================================

        if (
          [
            "A",
            "B",
            "C",
            "D",
          ].includes(
            upper
          )
        ) {

          correctIndex =
            upper.charCodeAt(
              0
            ) - 65;

        }


        // ===================================================
        // CORRECT ANSWER BERISI TEXT OPTION
        // ===================================================

        else {

          correctIndex =
            options.findIndex(
              option =>

                String(
                  option
                ).trim() ===
                text
            );

        }

      }


      // =====================================================
      // NORMALIZED QUESTION
      // =====================================================

      return {

        id:
          row.id ??
          row.question_id ??
          `${Date.now()}`,


        question:

          row.question ??

          row.question_text ??

          row.pertanyaan ??

          "Coding Question",


        options,


        correctIndex,


        explanation:

          row.explanation ??

          row.penjelasan ??

          "",

      };

    };


  // =========================================================
  // FETCH CODING QUESTION
  // =========================================================

  const fetchCodingQuestion =
    async () => {

      questionLoading.value =
        true;


      questionError.value =
        null;


      currentQuestion.value =
        null;


      selectedQuestionAnswer.value =
        null;


      questionResult.value =
        null;


      try {

        const {
          data,
          error,
        } =
          await supabase
            .from(
              questionTable
            )
            .select("*")
            .limit(100);


        if (
          error
        ) {

          throw error;

        }


        if (
          !data
          ||
          data.length ===
            0
        ) {

          throw new Error(
            `Tabel ${questionTable} belum memiliki question.`
          );

        }


        // ===================================================
        // HINDARI QUESTION YANG SAMA LANGSUNG TERULANG
        // ===================================================

        let candidates =
          data;


        if (
          data.length >
            1
          &&
          lastQuestionId.value !==
            null
        ) {

          candidates =
            data.filter(
              row =>

                (
                  row.id ??
                  row.question_id
                ) !==
                lastQuestionId.value
            );


          if (
            candidates.length ===
              0
          ) {

            candidates =
              data;

          }

        }


        // ===================================================
        // RANDOM QUESTION
        // ===================================================

        const randomIndex =
          Math.floor(
            Math.random() *
            candidates.length
          );


        const row =
          candidates[
            randomIndex
          ];


        const normalized =
          normalizeQuestion(
            row
          );


        // ===================================================
        // VALIDATION
        // ===================================================

        if (
          !normalized
          ||
          normalized.options.length <
            2
          ||
          normalized.correctIndex <
            0
          ||
          normalized.correctIndex >=
            normalized.options.length
        ) {

          throw new Error(
            "Format coding question tidak valid."
          );

        }


        currentQuestion.value =
          normalized;


        lastQuestionId.value =
          normalized.id;

      }


      catch (
        error
      ) {

        console.error(
          "Gagal mengambil coding question:",
          error
        );


        questionError.value =
          error?.message ||
          "Gagal mengambil pertanyaan dari database.";

      }


      finally {

        questionLoading.value =
          false;

      }

    };


  // =========================================================
  // START QUESTION BREAK
  // =========================================================

  const startQuestionBreak =
    async () => {

      questionMode.value =
        true;


      selectedQuestionAnswer.value =
        null;


      questionResult.value =
        null;


      questionError.value =
        null;


      if (
        typeof playSound ===
        "function"
      ) {

        void playSound(
          "question"
        );

      }


      await fetchCodingQuestion();

    };


  // =========================================================
  // ANSWER QUESTION
  // =========================================================

  const answerCodingQuestion =
    index => {

      if (
        questionLoading.value
        ||
        questionResult.value
        ||
        !currentQuestion.value
      ) {

        return false;

      }


      selectedQuestionAnswer.value =
        index;


      const correct =
        index ===
        currentQuestion.value
          .correctIndex;


      questionResult.value =
        correct
          ? "correct"
          : "wrong";


      if (
        typeof playSound ===
        "function"
      ) {

        void playSound(
          correct
            ? "correct"
            : "wrong"
        );

      }


      return correct;

    };


  // =========================================================
  // CONTINUE AFTER QUESTION
  // =========================================================

  const continueAfterQuestion =
    () => {

      questionMode.value =
        false;


      questionLoading.value =
        false;


      questionError.value =
        null;


      currentQuestion.value =
        null;


      selectedQuestionAnswer.value =
        null;


      questionResult.value =
        null;

    };


  // =========================================================
  // RESET QUESTIONS
  // =========================================================

  const resetQuestions =
    () => {

      questionMode.value =
        false;


      questionLoading.value =
        false;


      questionError.value =
        null;


      currentQuestion.value =
        null;


      selectedQuestionAnswer.value =
        null;


      questionResult.value =
        null;


      lastQuestionId.value =
        null;

    };


  // =========================================================
  // RETURN
  // =========================================================

  return {

    questionMode,

    questionLoading,

    questionError,

    currentQuestion,

    selectedQuestionAnswer,

    questionResult,

    lastQuestionId,


    normalizeQuestion,

    fetchCodingQuestion,

    startQuestionBreak,

    answerCodingQuestion,

    continueAfterQuestion,

    resetQuestions,

  };

};