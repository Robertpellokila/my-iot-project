import { supabase } from "../lib/supabase";

export const getBattleByCode=async(code,access=null)=>{
 const {data,error}=await supabase.rpc(access?'get_battle_player_state':'get_public_battle_state',access?{p_code:code,p_player:access.player,p_token:access.token}:{p_code:code});
 if(error)throw error;
 if(!data?.ok){const failure=new Error(data?.message||'Battle belum dapat dimuat.');failure.code=data?.code;throw failure;}
 return data.battle;
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