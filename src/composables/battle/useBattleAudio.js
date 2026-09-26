import {
  ref,
  onUnmounted,
} from "vue";


const SOUND_FILES = {
  attack:
    "/sounds/attack.mp3",

  hit:
    "/sounds/hit.mp3",

  defense:
    "/sounds/defense.mp3",

  heal:
    "/sounds/heal.mp3",

  ultimate:
    "/sounds/ultimate.mp3",

  synergy:
    "/sounds/synergy.mp3",

  summon:
    "/sounds/summon.mp3",

  bench:
    "/sounds/bench.mp3",

  swap:
    "/sounds/swap.mp3",

  warning:
    "/sounds/warning.mp3",

  question:
    "/sounds/question.mp3",

  correct:
    "/sounds/correct.mp3",

  wrong:
    "/sounds/wrong.mp3",

  win:
    "/sounds/win.mp3",

  lose:
    "/sounds/lose.mp3",
};


export const useBattleAudio = () => {

  const soundEnabled =
    ref(true);

  const audioUnlocked =
    ref(false);


  const audioCache =
    new Map();


  let endSoundPlayed =
    false;


  // =====================================================
  // CLAMP
  // =====================================================

  const clampVolume =
    value => {

      return Math.max(
        0,
        Math.min(
          1,
          Number(value) || 0
        )
      );

    };


  // =====================================================
  // GET AUDIO
  // =====================================================

  const getAudio =
    name => {

      if (
        typeof Audio ===
        "undefined"
      ) {
        return null;
      }


      const file =
        SOUND_FILES[name];


      if (!file) {

        console.warn(
          `Sound "${name}" tidak ditemukan.`
        );

        return null;

      }


      if (
        !audioCache.has(
          name
        )
      ) {

        const audio =
          new Audio(file);


        audio.preload =
          "auto";


        audioCache.set(
          name,
          audio
        );

      }


      return audioCache.get(
        name
      );

    };


  // =====================================================
  // UNLOCK AUDIO
  // =====================================================

  const unlockAudio =
    () => {

      if (
        audioUnlocked.value
      ) {
        return;
      }


      audioUnlocked.value =
        true;

    };


  // =====================================================
  // PLAY SOUND
  // =====================================================

  const playSound =
    async (
      name,
      volume = 0.85
    ) => {

      if (
        !soundEnabled.value ||
        !audioUnlocked.value
      ) {
        return;
      }


      const audio =
        getAudio(name);


      if (!audio) {
        return;
      }


      try {

        audio.pause();

        audio.currentTime =
          0;

        audio.volume =
          clampVolume(
            volume
          );


        await audio.play();

      }

      catch (error) {

        console.warn(
          `Sound ${name} gagal diputar:`,
          error
        );

      }

    };


  // =====================================================
  // TOGGLE
  // =====================================================

  const toggleSound =
    () => {

      soundEnabled.value =
        !soundEnabled.value;


      unlockAudio();


      if (
        soundEnabled.value
      ) {

        void playSound(
          "question",
          0.35
        );

      }

    };


  // =====================================================
  // BATTLE END SOUND
  // =====================================================

  const playBattleEndSounds =
    async () => {

      if (
        endSoundPlayed
      ) {
        return;
      }


      endSoundPlayed =
        true;


      void playSound(
        "win",
        0.95
      );


      setTimeout(
        () => {

          void playSound(
            "lose",
            0.65
          );

        },
        900
      );

    };


  const resetEndSound =
    () => {

      endSoundPlayed =
        false;

    };


  // =====================================================
  // CLEANUP
  // =====================================================

  onUnmounted(
    () => {

      for (
        const audio
        of audioCache.values()
      ) {

        audio.pause();

        audio.src =
          "";

      }


      audioCache.clear();

    }
  );


  return {

    soundEnabled,

    audioUnlocked,

    unlockAudio,

    playSound,

    toggleSound,

    playBattleEndSounds,

    resetEndSound,

  };

};