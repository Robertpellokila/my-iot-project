import {
  reactive,
  ref,
} from "vue";

import {
  supabase,
} from "../../lib/supabase";

// =========================================================
// STATE HELPERS
// =========================================================

const emptyPlayerState = () => ({
  viewerZone: null,
  viewerIndex: 0,

  draggingCardId: null,
  draggingCardName: "",
  dragFromZone: null,
  dragTarget: null,

  updatedAt: 0,
});

const cloneState = (
  state,
) => ({
  viewerZone:
    state?.viewerZone ??
    null,

  viewerIndex:
    Number(
      state?.viewerIndex ??
      0,
    ) || 0,

  draggingCardId:
    state?.draggingCardId ??
    null,

  draggingCardName:
    state?.draggingCardName ??
    "",

  dragFromZone:
    state?.dragFromZone ??
    null,

  dragTarget:
    state?.dragTarget ??
    null,

  updatedAt:
    Number(
      state?.updatedAt ??
      0,
    ) || 0,
});

const randomId = () => {
  if (
    typeof crypto !==
      "undefined" &&
    typeof crypto.randomUUID ===
      "function"
  ) {
    return crypto.randomUUID();
  }

  return `${Date.now()}-${Math.random()
    .toString(36)
    .slice(2)}`;
};

// =========================================================
// COMPOSABLE
// =========================================================

export function useBattleUiSync() {
  // =======================================================
  // CONNECTION
  // =======================================================

  const channel =
    ref(null);

  const connected =
    ref(false);

  const battleId =
    ref(null);

  const role =
    ref("spectator");

  const ownPlayer =
    ref(null);

  const clientId =
    ref(
      randomId(),
    );

  // =======================================================
  // LOCAL PLAYER STATE
  // =======================================================

  const localState =
    reactive(
      emptyPlayerState(),
    );

  // =======================================================
  // REMOTE PLAYER STATES
  // =======================================================

  const players =
    reactive({
      p1:
        emptyPlayerState(),

      p2:
        emptyPlayerState(),
    });

  // =======================================================
  // DEBUG
  // =======================================================

  const debug = (
    ...args
  ) => {
    console.debug(
      "[BattleUiSync]",
      ...args,
    );
  };

  // =======================================================
  // RESET
  // =======================================================

  const resetState = (
    target,
  ) => {
    Object.assign(
      target,
      emptyPlayerState(),
    );
  };

  const resetRemote =
    () => {
      resetState(
        players.p1,
      );

      resetState(
        players.p2,
      );
    };

  // =======================================================
  // APPLY REMOTE PLAYER STATE
  // =======================================================

  const applyRemoteState = (
    player,
    state,
  ) => {
    if (
      ![
        "p1",
        "p2",
      ].includes(
        player,
      )
    ) {
      return;
    }

    const next =
      cloneState(
        state,
      );

    if (
      Number(
        next.updatedAt ??
        0,
      ) <
      Number(
        players[player]
          .updatedAt ??
        0,
      )
    ) {
      return;
    }

    Object.assign(
      players[player],
      next,
    );
  };

  // =======================================================
  // READ PRESENCE SNAPSHOT
  // =======================================================

  const syncPresence =
    () => {
      if (
        !channel.value
      ) {
        return;
      }

      const state =
        channel.value
          .presenceState();

      const newest = {
        p1: null,
        p2: null,
      };

      for (
        const entries of
        Object.values(
          state ?? {},
        )
      ) {
        for (
          const meta of
          entries ?? []
        ) {
          if (
            meta?.role !==
              "player" ||
            ![
              "p1",
              "p2",
            ].includes(
              meta?.player,
            )
          ) {
            continue;
          }

          const player =
            meta.player;

          if (
            !newest[player] ||
            Number(
              meta.updatedAt ??
              0,
            ) >
              Number(
                newest[player]
                  ?.updatedAt ??
                0,
              )
          ) {
            newest[player] =
              meta;
          }
        }
      }

      for (
        const player of
        [
          "p1",
          "p2",
        ]
      ) {
        if (
          newest[player]
        ) {
          applyRemoteState(
            player,
            newest[player],
          );
        } else {
          resetState(
            players[player],
          );
        }
      }

      debug(
        "presence sync",
        {
          p1:
            cloneState(
              players.p1,
            ),

          p2:
            cloneState(
              players.p2,
            ),
        },
      );
    };

  // =======================================================
  // BROADCAST
  // =======================================================

  const broadcastState =
    async () => {
      if (
        !channel.value ||
        !connected.value ||
        role.value !==
          "player" ||
        !ownPlayer.value
      ) {
        return;
      }

      try {
        await channel.value.send(
          {
            type:
              "broadcast",

            event:
              "ui_state",

            payload: {
              battleId:
                battleId.value,

              player:
                ownPlayer.value,

              state:
                cloneState(
                  localState,
                ),
            },
          },
        );
      } catch (
        error
      ) {
        console.error(
          "Battle UI Broadcast:",
          error,
        );
      }
    };

  // =======================================================
  // PRESENCE TRACK
  // =======================================================

  const trackCurrentState =
    async () => {
      if (
        !channel.value ||
        !connected.value
      ) {
        return;
      }

      try {
        if (
          role.value ===
            "player" &&
          ownPlayer.value
        ) {
          await channel.value.track(
            {
              role:
                "player",

              player:
                ownPlayer.value,

              clientId:
                clientId.value,

              ...cloneState(
                localState,
              ),
            },
          );
        } else {
          await channel.value.track(
            {
              role:
                "spectator",

              player:
                null,

              clientId:
                clientId.value,

              updatedAt:
                Date.now(),
            },
          );
        }
      } catch (
        error
      ) {
        console.error(
          "Battle UI Presence Track:",
          error,
        );
      }
    };

  // =======================================================
  // PUBLISH PLAYER UI STATE
  // =======================================================

  const publish =
    async (
      patch = {},
    ) => {
      Object.assign(
        localState,
        patch,
      );

      localState.updatedAt =
        Date.now();

      if (
        !connected.value ||
        !channel.value ||
        role.value !==
          "player" ||
        !ownPlayer.value
      ) {
        debug(
          "publish queued locally",
          cloneState(
            localState,
          ),
        );

        return;
      }

      await Promise.allSettled(
        [
          trackCurrentState(),
          broadcastState(),
        ],
      );

      debug(
        "published",
        ownPlayer.value,
        cloneState(
          localState,
        ),
      );
    };

  // =======================================================
  // DISCONNECT
  // =======================================================

  async function disconnect() {
    connected.value =
      false;

    if (
      channel.value
    ) {
      try {
        await channel.value
          .untrack();
      } catch {
        // ignore
      }

      try {
        await supabase
          .removeChannel(
            channel.value,
          );
      } catch {
        // ignore
      }
    }

    channel.value =
      null;

    battleId.value =
      null;

    role.value =
      "spectator";

    ownPlayer.value =
      null;

    resetRemote();

    resetState(
      localState,
    );
  }

  // =======================================================
  // CONNECT
  // =======================================================

  const connect =
    async ({
      battleId:
        newBattleId,

      role:
        newRole =
          "spectator",

      player = null,
    }) => {
      if (
        !newBattleId
      ) {
        return;
      }

      await disconnect();

      battleId.value =
        String(
          newBattleId,
        );

      role.value =
        newRole ===
          "player"
          ? "player"
          : "spectator";

      ownPlayer.value =
        [
          "p1",
          "p2",
        ].includes(
          player,
        )
          ? player
          : null;

      clientId.value =
        randomId();

      const presenceKey =
        `${role.value}:${ownPlayer.value ?? "viewer"}:${clientId.value}`;

      const nextChannel =
        supabase.channel(
          `battle-ui-${battleId.value}`,
          {
            config: {
              presence: {
                key:
                  presenceKey,
              },
            },
          },
        );

      // ---------------------------------------------------
      // PRESENCE
      // ---------------------------------------------------

      nextChannel.on(
        "presence",
        {
          event:
            "sync",
        },
        () => {
          syncPresence();
        },
      );

      nextChannel.on(
        "presence",
        {
          event:
            "join",
        },
        () => {
          syncPresence();
        },
      );

      nextChannel.on(
        "presence",
        {
          event:
            "leave",
        },
        () => {
          syncPresence();
        },
      );

      // ---------------------------------------------------
      // BROADCAST
      // ---------------------------------------------------

      nextChannel.on(
        "broadcast",
        {
          event:
            "ui_state",
        },
        ({
          payload,
        }) => {
          if (
            !payload ||
            String(
              payload.battleId ??
              "",
            ) !==
              String(
                battleId.value ??
                "",
              )
          ) {
            return;
          }

          const player =
            payload.player;

          if (
            ![
              "p1",
              "p2",
            ].includes(
              player,
            )
          ) {
            return;
          }

          applyRemoteState(
            player,
            payload.state,
          );

          debug(
            "broadcast received",
            player,
            payload.state,
          );
        },
      );

      channel.value =
        nextChannel;

      await new Promise(
        (
          resolve,
          reject,
        ) => {
          let settled =
            false;

          nextChannel.subscribe(
            async (
              status,
            ) => {
              debug(
                "channel status",
                status,
                battleId.value,
                role.value,
                ownPlayer.value,
              );

              if (
                status ===
                  "SUBSCRIBED" &&
                !settled
              ) {
                settled =
                  true;

                connected.value =
                  true;

                await trackCurrentState();

                if (
                  role.value ===
                    "player" &&
                  ownPlayer.value
                ) {
                  await broadcastState();
                }

                syncPresence();

                resolve();

                return;
              }

              if (
                (
                  status ===
                    "CHANNEL_ERROR" ||
                  status ===
                    "TIMED_OUT" ||
                  status ===
                    "CLOSED"
                ) &&
                !settled
              ) {
                settled =
                  true;

                reject(
                  new Error(
                    `Battle UI channel: ${status}`,
                  ),
                );
              }
            },
          );
        },
      );
    };

  // =======================================================
  // VIEWER
  // =======================================================

  const openViewer =
    async (
      zone,
      index = 0,
    ) => {
      await publish(
        {
          viewerZone:
            zone,

          viewerIndex:
            Math.max(
              0,
              Number(
                index,
              ) || 0,
            ),
        },
      );
    };

  const closeViewer =
    async () => {
      await publish(
        {
          viewerZone:
            null,

          viewerIndex:
            0,
        },
      );
    };

  const setViewerIndex =
    async (
      index,
    ) => {
      const value =
        Math.max(
          0,
          Number(
            index,
          ) || 0,
        );

      if (
        localState
          .viewerIndex ===
        value
      ) {
        return;
      }

      await publish(
        {
          viewerIndex:
            value,
        },
      );
    };

  // =======================================================
  // DRAG
  // =======================================================

  const startDrag =
    async (
      card,
      fromZone,
    ) => {
      await publish(
        {
          draggingCardId:
            card?.battleId ??
            card?.battle_id ??
            card?.id ??
            card?.uid ??
            null,

          draggingCardName:
            card?.name ??
            "",

          dragFromZone:
            fromZone,

          dragTarget:
            null,
        },
      );
    };

  const setDragTarget =
    async (
      target,
    ) => {
      if (
        localState
          .dragTarget ===
        target
      ) {
        return;
      }

      await publish(
        {
          dragTarget:
            target,
        },
      );
    };

  const endDrag =
    async () => {
      await publish(
        {
          draggingCardId:
            null,

          draggingCardName:
            "",

          dragFromZone:
            null,

          dragTarget:
            null,
        },
      );
    };

  // =======================================================
  // RETURN
  // =======================================================

  return {
    connected,

    players,

    connect,
    disconnect,

    openViewer,
    closeViewer,
    setViewerIndex,

    startDrag,
    setDragTarget,
    endDrag,
  };
}