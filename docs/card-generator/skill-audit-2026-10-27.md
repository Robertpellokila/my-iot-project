# Skill, RFID and player UX audit — 2026-10-27

## Current account findings

The read-only account snapshot contains 203 cards (134 archived, 69 unarchived), 193 skill definitions (95 active, 98 inactive), and no recorded manual playtests. Archived cards are excluded from the card readiness count. Definitions and card artwork were not rewritten by this audit.

| Scope | Result |
| --- | --- |
| Saved pilot | All 42 cards / 84 skill slots are active and pass configuration checks, including the current customized Necro Recall. |
| All unarchived cards | 45 have complete skill configurations; 23 are missing at least one binding; Inferno Dragon has an incomplete description on Dead Strok. |
| Active legacy definitions | 10 execute their stored effects; `lurpy zxt` is rejected because its player target cannot supply the card required by its damage effect. |
| Inactive definitions | 98 remain inactive; the audit does not automatically activate old or incomplete skills. |

The per-card findings are in [skill-audit-2026-10-27.csv](skill-audit-2026-10-27.csv). `ready` in that file means configuration completeness, not proof of every possible battle interaction or print readiness.

Remaining legacy data issues are explicit: Dead Strok and lurpy zxt have no description. Worldtree Pulse's saved description says 15 HP while its stored effect heals 50 HP; the execution test verifies the stored 50, not the printed 15. These user-authored definitions were retained rather than choosing a balance change. Missing bindings on older/testing cards remain visible in **Skill & Catalog → Pemeriksaan katalog**.

## Server fixes installed

Migration **050** adds admin-only UID reassignment. **Hubungkan RFID** first previews the existing holder and requested destination. The explicit transfer atomically clears the old card's UID, disables scanning on that old record, and links a physical copy of the destination. The old card retains its data, design, skill bindings and existing battle snapshots. UID matching is case insensitive; stale confirmation and failed inserts roll back. Retry is idempotent. No actual user's UID was moved during this audit.

Migration **051** restores the missing `special_skill` branch in the legacy action dispatcher. Previously, the action could report success and debit AP while skipping `process_special_skill`, so neither effects nor usage were recorded. The branch now returns the executor's real result through the existing authorization, receipt and AP transaction. Explicit `consumes_turn` ends the turn even if AP remain. Both AP and legacy turn modes were tested. Both migrations were applied with the user's explicit permission; exact SQL source was read back from migration history.

## Verification evidence

- All 84 saved pilot skills were exercised through the installed server RPC: **89 activations** including alternative choices, plus two canonical QA template activations = **91 passing scenarios**. Assertions cover usage records, AP, attack/heal values, switching, revival HP/Bench placement, revival action lock and once-per-battle limits. Physical RFID copies inherit the explicit source's customized skill rules.
- The isolated Postgres suite executes the actual Studio SQL effect handler: **89 canonical cases across 84 slots**, then **89 cases from the 84 currently saved skills**. It checks HP, stats, statuses and zones, including each effect choice. Negative Necro tests reject Fusion cards, consumed materials and full Bench. The isolated fixture does not replace the remote credential/turn tests.
- All 11 active legacy definitions were exercised through the installed RPC: **10 passed**, and the malformed `lurpy zxt` configuration was rejected without spending AP or recording a use. Tests assert real player/card healing, damage, statuses, sacrifice/revival and gauge spending. Legacy effect amounts are tested as stored.
- Remote guard tests pass: AP overrides, zero-AP legacy override, two independent skills, persistent CD2, retry receipts, bad tokens, disabled skills, finished battles, teacher pause, opponent turn, explicit end turn and both non-AP modes. Applying the 051 patch twice in the preflight transaction is safe.
- Remote RFID tests pass: conflict preview, stale holder rejection, transfer preserving the old row/bindings, case-insensitive identity, retry, non-admin/anonymous denial. Local database tests additionally cover destination insert failure and stale unbound UID rollback.
- Ten targeted Node cases cover rule validation and readiness. Browser suites cover the guided editor, shortened Necro text, disabled bindings, transfer confirmation/retry, responsive layouts, skill readiness, pause, opponent turn and accessible disabled-action explanations. The complete related browser run passed 48 scenarios; the final focused run passed after the last validation change.
- Production build and `git diff --check` pass. Existing missing arena background references and large-chunk build warnings remain.
- Every remote test uses synthetic fixtures inside a rolled-back transaction. Read-back confirms zero QA battles/cards remain. Physical RFID reader hardware was not exercised.

## UI behavior

The skill editor separates **Teks pada kartu**, **Efek saat battle**, and **Biaya & batas pemakaian**. Its preview explains the actual effect, target, AP and cooldown. Choosing a pattern is explicit; changing printed text does not regenerate mechanics. Advanced JSON is optional. Activation validates the submitted data and restores an automatically disabled Studio binding while preserving deliberate deselection.

Player actions use blue **Summon**, green usable actions, and truly disabled unavailable actions. Explanations remain available through the information control. A brief contextual ready bubble names the usable skill. Readiness includes turn/pause/quiz/AP state, source status, attack allowance, cooldown/use limits, eligible targets, switch availability, revival capacity and mutually exclusive skill rules. Notices respect reduced motion and do not trigger actions.

Saved skill edits apply to new battle snapshots; existing battle skill snapshots retain their definitions. Refresh the application to load the updated UI. Configuration checks and automated tests are distinct from the manual playtest log shown in the Catalog; that log was not fabricated by this audit.

## Relevant checks

```sh
node --test tests/card-generator/skillEditor.test.js tests/battle/actionAvailability.test.js
node tests/card-generator/studioSkillOverridesDatabase.mjs
node tests/card-generator/studioBattleSkillDatabase.mjs
node tests/battle/skillDatabase.mjs
node tests/battle/studioSkillExecutionDatabase.mjs
npx playwright test -c playwright.card-generator.config.js tests/visual/album-flow.spec.js tests/visual/player-action-panel.spec.js tests/visual/battle-access-controls.spec.js tests/visual/studio-workflow.spec.js
npm run build
```

Remote opt-in SQL files: `tests/card-generator/rfidReassignmentRemoteSmoke.sql`, `tests/battle/remoteSkillSmoke.sql`, `tests/battle/specialSkillDispatchRemoteSmoke.sql`, `tests/battle/savedSkillDispatchSmoke.sql`, and `tests/battle/legacySavedSkillDispatchSmoke.sql`. Wrap the files that lack their own transaction in `BEGIN` / `ROLLBACK`; they intentionally create fixtures and never belong in production migration history. Account snapshots and detailed test output remain ignored under `test-results/skill-catalog/`.
