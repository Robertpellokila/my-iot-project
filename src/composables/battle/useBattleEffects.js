import {
  ref,
  onUnmounted,
} from "vue";


/**
 * ============================================================
 * BATTLE EFFECTS
 * ============================================================
 *
 * Semua visual effect battle ditangani di sini.
 *
 * PENTING:
 * Effect TIDAK menahan game logic.
 *
 * Jadi ketika:
 *
 * setProfileEffect(...)
 *
 * dipanggil dengan await sekalipun,
 * function langsung selesai.
 *
 * Timer visual berjalan sendiri di background.
 *
 * Ini mencegah:
 * - attack terasa delay
 * - nextTurn lambat
 * - HP baru berubah setelah animation selesai
 * - RFID terasa lag
 * ============================================================
 */

export const useBattleEffects = ({
  playSound = null,
} = {}) => {


  // =========================================================
  // EFFECT STATE
  // =========================================================

  const player1ProfileEffect =
    ref(null);

  const player2ProfileEffect =
    ref(null);


  const player1ProfilePopup =
    ref(null);

  const player2ProfilePopup =
    ref(null);


  // =========================================================
  // BACKWARD COMPATIBILITY
  //
  // Nama ini dipakai oleh beberapa component/wrapper
  // sebelumnya.
  // =========================================================

  const player1Effect =
    player1ProfileEffect;

  const player2Effect =
    player2ProfileEffect;


  const player1Popup =
    player1ProfilePopup;

  const player2Popup =
    player2ProfilePopup;


  // =========================================================
  // TIMERS
  // =========================================================

  const timers = {
    p1: null,
    p2: null,
  };


  // =========================================================
  // NORMALIZE PLAYER
  // =========================================================

  const normalizePlayer =
    player => {

      return (
        player === "p2"
          ? "p2"
          : "p1"
      );

    };


  // =========================================================
  // GET PLAYER EFFECT REFS
  // =========================================================

  const getRefs =
    player => {

      const target =
        normalizePlayer(
          player
        );


      if (
        target === "p1"
      ) {

        return {

          effect:
            player1ProfileEffect,

          popup:
            player1ProfilePopup,

        };

      }


      return {

        effect:
          player2ProfileEffect,

        popup:
          player2ProfilePopup,

      };

    };


  // =========================================================
  // CLEAR PLAYER EFFECT
  // =========================================================

  const clearPlayerEffect =
    player => {

      const target =
        normalizePlayer(
          player
        );


      if (
        timers[target]
      ) {

        clearTimeout(
          timers[target]
        );


        timers[target] =
          null;

      }


      const {
        effect,
        popup,
      } =
        getRefs(
          target
        );


      effect.value =
        null;


      popup.value =
        null;

    };


  // =========================================================
  // PLAY EFFECT SOUND
  // =========================================================

  const playEffectSound =
    (
      sound,
      volume = 0.85
    ) => {

      if (
        !sound ||
        typeof playSound !==
          "function"
      ) {

        return;

      }


      /*
       * Jangan await.
       *
       * Audio tidak boleh
       * menghentikan game logic.
       */

      void playSound(
        sound,
        volume
      );

    };


  // =========================================================
  // SET PROFILE EFFECT
  //
  // API utama yang dipakai engine.
  //
  // IMPORTANT:
  // function TIDAK await duration.
  //
  // Jadi ini aman walaupun composable lain menulis:
  //
  // await setProfileEffect(...)
  //
  // await tersebut langsung selesai.
  // =========================================================

  const setProfileEffect =
    (
      player,
      effectName,
      popupText = null,
      duration = 700
    ) => {

      const target =
        normalizePlayer(
          player
        );


      /*
       * Bersihkan effect sebelumnya.
       */

      clearPlayerEffect(
        target
      );


      const {
        effect,
        popup,
      } =
        getRefs(
          target
        );


      effect.value =
        effectName;


      popup.value =
        popupText;


      /*
       * Visual timer berjalan sendiri.
       */

      timers[target] =
        setTimeout(
          () => {

            effect.value =
              null;


            popup.value =
              null;


            timers[target] =
              null;

          },
          duration
        );

    };


  // =========================================================
  // SHOW EFFECT
  //
  // API versi sebelumnya.
  // Tetap tersedia supaya wrapper lama tidak error.
  // =========================================================

  const showEffect =
    (
      player,
      effectName,
      popupText = null,
      duration = 700,
      {
        sound = null,
        soundVolume = 0.85,
      } = {}
    ) => {

      setProfileEffect(
        player,
        effectName,
        popupText,
        duration
      );


      playEffectSound(
        sound,
        soundVolume
      );

    };


  // =========================================================
  // PROFILE MESSAGE
  // =========================================================

  const showProfileMessage =
    (
      player,
      message,
      duration = 800
    ) => {

      showEffect(
        player,

        "info",

        message,

        duration
      );

    };


  // =========================================================
  // DAMAGE
  // =========================================================

  const showDamage =
    (
      player,
      damage,
      duration = 750
    ) => {

      showEffect(
        player,

        "damage",

        `💥 -${damage} HP`,

        duration,

        {
          sound:
            "hit",

          soundVolume:
            0.85,
        }
      );

    };


  // =========================================================
  // HEAL
  // =========================================================

  const showHeal =
    (
      player,
      amount,
      duration = 900
    ) => {

      showEffect(
        player,

        "heal",

        `💚 +${amount} HP`,

        duration,

        {
          sound:
            "heal",

          soundVolume:
            0.85,
        }
      );

    };


  // =========================================================
  // DEFENSE
  // =========================================================

  const showDefense =
    (
      player,
      duration = 800
    ) => {

      showEffect(
        player,

        "defense",

        "🛡 DEFENSE ACTIVE",

        duration,

        {
          sound:
            "defense",

          soundVolume:
            0.85,
        }
      );

    };


  // =========================================================
  // SUMMON
  // =========================================================

  const showSummon =
    (
      player,
      hpGain,
      duration = 900
    ) => {

      showEffect(
        player,

        "summon",

        `✨ SUMMON +${hpGain} HP`,

        duration,

        {
          sound:
            "summon",

          soundVolume:
            0.9,
        }
      );

    };


  // =========================================================
  // ULTIMATE
  // =========================================================

  const showUltimate =
    (
      player,
      duration = 800
    ) => {

      showEffect(
        player,

        "ultimate",

        "💥 ULTIMATE!",

        duration,

        {
          sound:
            "ultimate",

          soundVolume:
            0.95,
        }
      );

    };


  // =========================================================
  // SYNERGY
  // =========================================================

  const showSynergy =
    (
      player,
      text = "✨ SYNERGY",
      duration = 900
    ) => {

      showEffect(
        player,

        "synergy",

        text,

        duration,

        {
          sound:
            "synergy",

          soundVolume:
            0.9,
        }
      );

    };


  // =========================================================
  // WARNING
  // =========================================================

  const showWarning =
    (
      player,
      text,
      duration = 950
    ) => {

      showEffect(
        player,

        "warning",

        text,

        duration,

        {
          sound:
            "warning",

          soundVolume:
            0.85,
        }
      );

    };


  // =========================================================
  // RESET EFFECTS
  // =========================================================

  const resetEffects =
    () => {

      clearPlayerEffect(
        "p1"
      );


      clearPlayerEffect(
        "p2"
      );

    };


  // =========================================================
  // CLEANUP
  // =========================================================

  onUnmounted(
    () => {

      resetEffects();

    }
  );


  // =========================================================
  // RETURN
  // =========================================================

  return {

    // =======================================================
    // NEW / ORIGINAL-NAME API
    // =======================================================

    player1ProfileEffect,

    player2ProfileEffect,

    player1ProfilePopup,

    player2ProfilePopup,


    setProfileEffect,

    showProfileMessage,


    // =======================================================
    // COMPATIBILITY API
    // =======================================================

    player1Effect,

    player2Effect,

    player1Popup,

    player2Popup,


    showEffect,


    // =======================================================
    // EFFECT HELPERS
    // =======================================================

    showDamage,

    showHeal,

    showDefense,

    showSummon,

    showUltimate,

    showSynergy,

    showWarning,


    // =======================================================
    // UTILITIES
    // =======================================================

    clearPlayerEffect,

    resetEffects,

  };

};