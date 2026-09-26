import {
  supabase,
} from "../lib/supabase";


// =========================================================
// SUBSCRIBE BATTLE EVENTS
// =========================================================

export const subscribeBattleEvents =
  (
    battleId,
    callback
  ) => {

    if (!battleId) {
      throw new Error(
        "battleId wajib diisi."
      );
    }

    const channel =
      supabase
        .channel(
          `battle-events-${battleId}-${Date.now()}`
        )

        .on(
          "postgres_changes",

          {
            event: "INSERT",
            schema: "public",
            table: "battle_events",

            filter:
              `battle_id=eq.${battleId}`,
          },

          payload => {

            callback?.(
              payload.new
            );

          }
        )

        .subscribe(
          status => {

            console.log(
              "Battle event channel:",
              status
            );

            if (
              status ===
                "CHANNEL_ERROR" ||
              status ===
                "TIMED_OUT"
            ) {

              console.error(
                "Battle events realtime error:",
                status
              );

            }

          }
        );


    return channel;
  };


// =========================================================
// UNSUBSCRIBE
// =========================================================

export const unsubscribeBattleEvents =
  async channel => {

    if (!channel) {
      return;
    }

    try {

      await supabase
        .removeChannel(
          channel
        );

    } catch (error) {

      console.error(
        "Gagal remove battle event channel:",
        error
      );

    }
  };


// =========================================================
// SUBMIT PLAYER ACTION
// =========================================================

export const submitBattleAction =
  async ({
    code,
    player,
    token,
    action,
    cardId = null,
    payload = {},
  }) => {

    if (!code) {
      throw new Error(
        "Battle code tidak ditemukan."
      );
    }

    if (
      player !== "p1" &&
      player !== "p2"
    ) {

      throw new Error(
        "Player tidak valid."
      );

    }

    if (!token) {
      throw new Error(
        "Player token tidak ditemukan."
      );
    }

    if (!action) {
      throw new Error(
        "Action wajib diisi."
      );
    }


    const {
      data,
      error,
    } =
      await supabase.rpc(
        "submit_battle_action",

        {
          p_code:
            code,

          p_player:
            player,

          p_token:
            token,

          p_action:
            action,

          p_card_id:
            cardId,

          p_payload:
            payload,
        }
      );


    if (error) {

      console.error(
        "submitBattleAction:",
        error
      );

      throw error;
    }


    if (
      data?.ok === false
    ) {

      throw new Error(
        data.message ||
        "Action ditolak."
      );

    }


    return data;
  };


// =========================================================
// GET EVENT HISTORY
// =========================================================

export const getBattleEvents =
  async (
    battleId,
    limit = 50
  ) => {

    const {
      data,
      error,
    } =
      await supabase
        .from(
          "battle_events"
        )

        .select("*")

        .eq(
          "battle_id",
          battleId
        )

        .order(
          "created_at",
          {
            ascending: false,
          }
        )

        .limit(
          limit
        );


    if (error) {
      throw error;
    }


    return data || [];
  };


// =========================================================
// HELPERS
// =========================================================

export const isEventForPlayer =
  (
    event,
    player
  ) => {

    if (
      !event ||
      !player
    ) {

      return false;

    }


    return (
      event.source_player ===
        player
      ||
      event.target_player ===
        player
    );
  };


export const getEventAction =
  event => {

    return (
      event?.payload?.action ||
      event?.type ||
      null
    );

  };


export const getEventMessage =
  event => {

    return (
      event?.payload?.message ||
      null
    );

  };