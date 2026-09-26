import { supabase } from "../lib/supabase";

export const getBattleByCode =
  async (code) => {

    const {
      data,
      error,
    } =
      await supabase
        .from("battle_sessions")
        .select("*")
        .eq("code", code)
        .single();

    if (error) {
      throw error;
    }

    return data;
  };


export const getBattleCards =
  async (battleId) => {

    const {
      data,
      error,
    } =
      await supabase
        .from("battle_cards")
        .select("*")
        .eq("battle_id", battleId)
        .order("slot", {
          ascending: true,
        });

    if (error) {
      throw error;
    }

    return data || [];
  };


export const subscribeBattle =
  (
    battleId,
    onSessionChange,
    onCardChange,
    onEvent
  ) => {

    const channel =
      supabase
        .channel(
          `battle-${battleId}`
        )

        .on(
          "postgres_changes",
          {
            event: "UPDATE",
            schema: "public",
            table: "battle_sessions",
            filter:
              `id=eq.${battleId}`,
          },
          payload => {
            onSessionChange?.(
              payload.new
            );
          }
        )

        .on(
          "postgres_changes",
          {
            event: "*",
            schema: "public",
            table: "battle_cards",
            filter:
              `battle_id=eq.${battleId}`,
          },
          payload => {
            onCardChange?.(
              payload
            );
          }
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
            onEvent?.(
              payload.new
            );
          }
        )

        .subscribe();

    return channel;
  };