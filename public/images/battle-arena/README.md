# Player arena artwork

Created on 2026-10-27 with imagegen from the user's supplied arena and action-panel references. These are decorative illustrations; card artwork, portraits, names, stats, skills and AP are rendered separately from live battle data.

- `stadium-v1.webp`: clean stadium background, 1672 × 941.
- `action-atlas-v1.webp`: 1254 × 1254, nine equal tiles. Rows: Summon / Attack / Skill; More / End turn / Combo; Fusion / Ultimate / Heal. `BattleActionArtwork.vue` clips each tile without additional downloads.
- `synergy-v1.webp`: group illustration, 1881 × 836.
- `panel-frame.svg`: code-native blue and gold nine-slice frame. Explicit dimensions are needed for consistent browser border slicing.

WebP copies retain the generated dimensions and were encoded at quality 0.9 using Chrome Canvas. The original PNGs are retained in the local generated-image session `01a17776-5e2a-7553-a313-d90b28d26efe`. Together the three served illustrations are about 1.28 MB (the PNGs were 7.54 MB).

Layout and interactions are covered by `tests/visual/player-arena.spec.js`, alongside the existing battle action, access and opponent-inspection suites. Its card artwork is a local test fixture, not a replacement for players' saved artwork.
