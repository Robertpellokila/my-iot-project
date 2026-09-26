import {
  ref,
  onMounted,
  onUnmounted,
} from "vue";


export const useBattleFullscreen =
  () => {

    const isFullscreen =
      ref(false);


    const syncFullscreenState =
      () => {

        isFullscreen.value =
          Boolean(
            document
              .fullscreenElement
          );

      };


    const toggleFullscreen =
      async () => {

        try {

          if (
            !document
              .fullscreenElement
          ) {

            await document
              .documentElement
              .requestFullscreen();

          }

          else {

            await document
              .exitFullscreen();

          }

        }

        catch (error) {

          console.error(
            "Fullscreen gagal:",
            error
          );

        }

      };


    onMounted(
      () => {

        syncFullscreenState();


        document
          .addEventListener(
            "fullscreenchange",
            syncFullscreenState
          );

      }
    );


    onUnmounted(
      () => {

        document
          .removeEventListener(
            "fullscreenchange",
            syncFullscreenState
          );

      }
    );


    return {

      isFullscreen,

      toggleFullscreen,

    };

  };