# Reference frame assets · layouts v4–v5

The user supplied ten 1024 × 1536 PNG card examples on 2026-10-21. Six originals are bundled byte-for-byte under `public/images/card-generator/reference-frames/`. Repeated Common and Epic examples share their respective master. Source artwork, stats and effect wording are visual references; the audited pilot data remains unchanged.

| Bundled asset | Supplied original | SHA-256 |
| --- | --- | --- |
| `common.png` | `ChatGPT Image Oct 21, 2026, 10_51_58 AM-1.png` | `a16141ddd019f767c8f816025a09a2468725fc833fd274eeb84b507cb644555e` |
| `uncommon.png` | `ChatGPT Image Oct 21, 2026, 10_52_06 AM-8.png` | `d84a793dffa172f1a6333a3b91020aeb82194399d5d9f77462eb2f91173049c1` |
| `rare-knight.png` | `ChatGPT Image Oct 21, 2026, 10_52_03 AM-5.png` | `72921217f99cebe150cd5750bb1e65ebac6c8c114ef8927fd3fce0a35ed1bd25` |
| `rare-thunder.png` | `ChatGPT Image Oct 21, 2026, 10_52_04 AM-6.png` | `a8187f9df392547dfec2e154637f67b13242ef0de34b11cef8ec6cb78da2173a` |
| `rare-forest.png` | `ChatGPT Image Oct 21, 2026, 10_52_08 AM-9.png` | `1ae03ad13a0e39eb70f5709cc5c834f85ca256efc8092260da65ac77ed576821` |
| `epic.png` | `ChatGPT Image Oct 21, 2026, 10_52_09 AM-10.png` | `1a74ff6115be4f9b38e775121adcfa1ec2ddc6e8541a4645bd5cd816cdfc8814` |

`src/data/card-generator/reference-frames.json` records source names, hashes and dimensions. `cardReferenceFrames.js` selects the frame by rarity, with Type-specific Rare variants. Only decorative outer rails, fixed rarity badges and Epic diamonds are exposed through SVG clip paths. The rendered image height excludes the originals' bottom 72 px of paper (`trim_height: 1464`), fitting the card face to the established 756 × 1056 coordinate system and 63 × 88 mm print size.

The character window, ATK/HP/DEF, Type, identity ribbon, skill panels and footer values are rendered independently. The two skill badges accept optional per-card raster uploads. Preview and export use the same renderer. Export embeds hash-verified source PNGs and icon images, so downloaded files do not depend on the local server. `npm run card:masters` also embeds the frame bytes in standalone SVG proofs.

Reference hashes and the current layout version participate in render signatures. Layout v5 invalidates older render receipts and adds independent inner bounds for every printed data field. The immutable shared back remains `public/images/tbc-back.png` with its existing hash.
