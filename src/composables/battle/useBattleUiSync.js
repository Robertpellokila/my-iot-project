import {
  reactive,
  ref,
  shallowRef,
  toRaw,
} from "vue";

import {
  supabase,
} from "../../lib/supabase";
import { normalizeSkillIntent } from '../../lib/battle/skillCinematic.js';
import { clonePlayerFocus, newerSpotlight, normalizeSpotlight } from '../../utils/battleSpotlight.js';

// =========================================================
// STATE HELPERS
// =========================================================

const emptyPlayerState = () => ({
  focus: { selected: null, target: null },
  skillIntent: null,
  viewerZone: null,
  viewerIndex: 0,
  viewerCardId: null,
  viewerTurn: null,

  draggingCardId: null,
  draggingCardName: "",
  dragFromZone: null,
  dragTarget: null,

  updatedAt: 0,
});

const cloneState = (
  state,
) => ({
  focus: clonePlayerFocus(state?.focus),
  skillIntent: normalizeSkillIntent(state?.skillIntent),
  viewerCardId: state?.viewerCardId == null ? null : String(state.viewerCardId).slice(0, 128),
  viewerTurn: Number.isSafeInteger(state?.viewerTurn) && state.viewerTurn >= 0 ? state.viewerTurn : null,
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

  const channel = shallowRef(null);
  let reconnectTimer = null;
  let reconnectAttempt = 0;
  const clearReconnect = () => {
    clearTimeout(reconnectTimer);
    reconnectTimer = null;
  };

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

  // This stays latched when a selection is cleared by an action or a player leaves.
  const spotlight = reactive({ p1: null, p2: null });
  const storageKey = suffix => `tbc:battle-spotlight:${battleId.value}:${suffix}`;
  const readSaved = suffix => {
    try { return JSON.parse(sessionStorage.getItem(storageKey(suffix)) || 'null'); }
    catch { return null; }
  };
  const saveState = (suffix, state) => {
    if (!battleId.value) return;
    try { sessionStorage.setItem(storageKey(suffix), JSON.stringify(state)); }
    catch { /* Realtime remains available when browser storage is disabled. */ }
  };
  const rememberFocus = (player, focus) => {
    const opposite = player === 'p1' ? 'p2' : 'p1';
    const next = clonePlayerFocus(focus);
    for (const [side, record] of [[player, next.selected], [opposite, next.target]]) {
      if (newerSpotlight(record, spotlight[side])) spotlight[side] = record;
    }
    saveState('display', spotlight);
  };

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

    rememberFocus(player, next.focus);

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
        Math.max(Date.now(), localState.updatedAt + 1);

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
    clearReconnect();
    connected.value =
      false;

    const previousChannel = channel.value;
    channel.value = null;
    if (previousChannel) {
      try {
        await previousChannel.untrack();
      } catch {
        // ignore
      }

      try {
        await supabase
          .removeChannel(
            previousChannel,
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

    spotlight.p1 = null;
    spotlight.p2 = null;

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
      resumeState = null,
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

      const savedDisplay = readSaved('display');
      spotlight.p1 = normalizeSpotlight(savedDisplay?.p1);
      spotlight.p2 = normalizeSpotlight(savedDisplay?.p2);
      if (role.value === 'player' && ownPlayer.value) {
        localState.focus = clonePlayerFocus(readSaved(`player:${ownPlayer.value}`));
        rememberFocus(ownPlayer.value, localState.focus);
      }
      if (resumeState) Object.assign(localState, cloneState(resumeState));

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
              if (toRaw(channel.value) !== nextChannel) return;
              debug(
                "channel status",
                status,
                battleId.value,
                role.value,
                ownPlayer.value,
              );

              if (status === "SUBSCRIBED") {
                clearReconnect();
                reconnectAttempt = 0;
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
                )
              ) {
                connected.value = false;
                if (!reconnectTimer) {
                  const retry = { battleId: battleId.value, role: role.value, player: ownPlayer.value };
                  reconnectTimer = setTimeout(() => {
                    reconnectTimer = null;
                    if (toRaw(channel.value) !== nextChannel || connected.value) return;
                    // Retain actions queued while disconnected, including an opened pile.
                    void connect({ ...retry, resumeState: cloneState(localState) }).catch(error => {
                      console.debug('[BattleUiSync] reconnect pending:', error.message);
                    });
                  }, Math.min(15000, (status === 'CLOSED' ? 1000 : 5000) * 2 ** Math.min(reconnectAttempt++, 3)));
                }
                if (settled) return;
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
      turn = null,
      cardId = null,
    ) => {
      await publish(
        {
          viewerTurn: turn,
          viewerCardId: cardId,
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
          viewerTurn: null,
          viewerCardId: null,
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
      cardId = null,
      turn = null,
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
        value && localState.viewerCardId === cardId && localState.viewerTurn === turn
      ) {
        return;
      }

      await publish(
        {
          viewerCardId: cardId,
          viewerTurn: turn,
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

  const focusCards = async ({ selectedCardId, targetCardId, turn }) => {
    if (selectedCardId == null && targetCardId == null) return;
    const at = Math.max(Date.now(), localState.updatedAt + 1,
      (localState.focus.selected?.at ?? 0) + 1, (localState.focus.target?.at ?? 0) + 1);
    const focus = clonePlayerFocus(localState.focus);
    // Null is deliberately ignored: clearing an action picker must not reset TV focus.
    if (selectedCardId != null) focus.selected = normalizeSpotlight({ cardId: selectedCardId, turn, at });
    if (targetCardId != null) focus.target = normalizeSpotlight({ cardId: targetCardId, turn, at });
    if (ownPlayer.value) {
      saveState(`player:${ownPlayer.value}`, focus);
      rememberFocus(ownPlayer.value, focus);
    }
    await publish({ focus });
  };

  return {
    connected,

    spotlight,
    focusCards,
    skillIntent: value => publish({ skillIntent: normalizeSkillIntent(value) }),

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
