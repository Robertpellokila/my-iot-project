# Studio skill verification — 25 October 2026

Migration 036 is deployed with explicit user approval. The previous 24 October audit remains historical: its 0/84 binding finding is resolved for the 42 currently saved Studio cards.

- 42 cards / 84 enabled skill bindings, no pending Studio definitions.
- All 84 descriptions compile identically in the editor and server registry.
- 89 successful skill/choice scenarios cover every slot and each mutually exclusive effect branch.
- 30 physical Base copies create both runtime skills when loaded into battle.
- Native attack tests verify actual HP with Shield, DEF-until-hit, flat guard, marks and outgoing damage reduction. Negative condition checks omit the bonus. Stat restoration and delayed healing match owner-turn boundaries.
- Thunder Chain was also activated against two distinct targets on the installed backend: each received 0.65× ATK minus DEF; duplicate target IDs reject before HP/AP changes.
- Rejected missing choices, invalid owners, repeated targets, silenced Skill 2 and Root movement preserve AP/state. Existing token, CD2, idempotency and once-per-battle guards still pass.
- Necro Recall rejects Fusion results, consumed materials and a full Bench; restores 40% of the target's Max HP to Bench without sacrificing its source; locks Attack/Skill until the next owner turn; retains previous cooldown/usage.
- Build and Chrome tests pass for effect choice, Bench selection, two-target requests, account/Album/RFID navigation, and cinematic effects across all four public layouts.

Tests: `tests/battle/studioExecutableSmoke.sql`, `tests/battle/studioRulesSmoke.sql`, `tests/battle/remoteSkillSmoke.sql`, `tests/card-generator/studioBattleSkillDatabase.mjs`, `tests/card-generator/studioBattleRules.test.js`, and the targeted `tests/visual/studio-workflow.spec.js` / `album-flow.spec.js` scenarios.

Database fixtures were rolled back and no QA battles remain. Existing in-progress battles retain their snapshots: start a new battle to load the newly activated definitions. RFID source data and bindings were verified; a physical reader was not exercised. Free-form new descriptions outside supported complete patterns remain inactive until their mechanics are configured.
