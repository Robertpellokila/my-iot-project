# TBC Card Generator · pilot v1.1

Open **Admin → Card Studio → Desain & cetak** (`/admin/cards`, or the existing `/admin/card-generator` link). Card Studio groups design/printing and **Registrasi kartu** in one menu. The registration tab uses the existing `/admin/game/register` workflow. Both tabs retain their in-progress state while switching; the RFID listener is active only on registration. Leaving Card Studio clears the cached registration form, while generator drafts retain their existing workspace persistence. The selected design is remembered per account in the browser session.

Latest skill/RFID verification: [2026-10-27 audit](skill-audit-2026-10-27.md) and [per-card findings](skill-audit-2026-10-27.csv). Migrations 050/051 are installed; all 84 saved pilot skills were exercised through the restored server dispatcher. The historical milestones below describe earlier stages.

## Repository audit and decisions

- Vue 3.5, Vite 8, Vue Router, JavaScript composition API; no existing central state store.
- Supabase Auth already protects the `/admin` route family. The generator inherits that guard, verifies the current user on mount, and verifies the user again before uploads. Existing admin routes use authenticated access; no new role or privilege model is invented.
- Production `game_cards.card_code` uses underscores. Source IDs use hyphens. `COB-006` maps to `COB_006`, and neither is an RFID UID. Existing physical copies retain their own `uid` and battle relationships.
- The older seed contains 110 base templates and 24 fusion results from another document. It must not be merged with this pilot.
- Read-only production audit returned 161 rows, including 42 matching pilot identities. **39 matching identities have differing printed fields.** Example: existing `COB_006.hp = 118`, official pilot HP = 120. See `production-comparison.json` for exact old/new values. No production rows were changed.
- Existing object storage: public `card-images`, raster PNG/JPEG/WebP, 1 MB output limit. Generator images use `card-generator/{authenticated-user}/pilot-v1.1/{card_code}/…` and unique versioned filenames.
- Existing catalog has 27 illustrations, mostly unrelated characters. The old Tochi Worldtree illustration is recorded as an identity reference only. None is approved as a final pilot variant artwork. The DOCX contains no embedded images. The approved full back image is now bundled at `public/images/tbc-back.png`; a separate logo upload is no longer used.
- The app has no server-side image generation provider. During the visual refinement, the built-in imagegen tool generated one reference-guided Tochi Sprout Keeper illustration. Its real local PNG, hash, provenance and final prompt are checked in; it is an unapproved draft. The remaining 41 illustrations still need assets. All 42 distinct briefs and upload, placement and review remain available.
- Added jsPDF and JSZip, loaded only when exporting. Playwright is a development dependency. The existing app, route conventions, auth client and image compressor are reused.

## Ordered implementation checklist

1. [x] Repository audit, integration points, production conflict report.
2. [x] Extract 30 Base + 12 Fusion definitions directly from DOCX tables, preserve original text and source row coordinates.
3. [x] Structured EXACT / ONE_OF / TAG recipes and narrow eligible card sets; full Necro Recall guardrails.
4. [x] Seven SVG masters with shared fixed `756 × 1056` coordinates, exact 63:88 ratio, and embedded reference decorations for the supplied rarities.
5. [x] 42 unique illustration briefs, species, pose, camera, environment, lighting and versioned asset status.
6. [x] Protected three-panel studio, filters, bulk review, frame studies, front/back, zoom, print-size and safe-area previews.
7. [x] Raster artwork upload, three independently positioned layers, two independent skill icon uploads, replacement, removal, review and the immutable shared back image.
8. [x] SVG, 300/600 DPI PNG with PNG density metadata, physically sized PDF, ZIP bulk export and A4 duplex test sheets.
9. [x] Dataset/recipe/security/readiness tests; seven master and five milestone visual proof baselines; browser export checks.
10. [ ] Supply/review **42 final unique character compositions**. The approved back image is already installed. See `missing-artwork.md`.
11. [ ] Resolve the NUL-006 long skill for print with an approved typography/layout decision. The canonical text remains intact; it is not shortened to hide this issue.
12. [ ] If account-based workspace sync is required, review/apply migration `027_card_generator_projects.sql`. It has **not** been applied to production. Local drafts, artwork storage, and workspace JSON exchange work independently of this new table.
13. [ ] Approve the resulting illustrated proofs and physically test duplex registration on the intended printer.

The first milestone cards (COB-003, TOC-005, COB-006, COB-008, F01) have verified source data and vector frame proofs. **Their character illustrations are still missing; the illustrated milestone is not claimed complete.** The master gallery uses the same Tochi illustration across all seven frame studies to compare materials and rarity badges. Non-Common examples are explicitly labeled studies outside the pilot pool, and their printed ID stays TOC-003 to avoid exposing internal study IDs on the card.

## Source and validation

Canonical file: `src/data/card-generator/pilot-v1.1.json`.

Source: `TBC_Pilot_Set_30_Base_12_Fusion_v1_1_Audited_Necromancer.docx`.

SHA-256: `4e06c23eafc69ca4b64cb45ac18b19760afd48477958cbb221cce0fa600a46c1`.

Rebuild from the supplied original document:

```sh
python3 scripts/card-generator/extract_pilot.py /path/to/TBC_Pilot_Set_30_Base_12_Fusion_v1_1_Audited_Necromancer.docx
npm run test:cards
npm run audit:cards
```

The pilot JSON is frozen at runtime. Stats and skill text are source-locked in the UI. All skill descriptions, cooldowns, explicit AP costs, effect clauses, once-per-battle limits and original strings are preserved. These are print/catalog data; no new battle effects are activated.

Fusion classification is distinct from rarity: F01 uses the Fusion frame while retaining official Legendary rarity. TAG slots check both the narrow named tag and explicit eligible codes. Combat Types never substitute for tags. A base card's compact partner list omits the entire material slot occupied by that card, so a ONE_OF alternative is never incorrectly shown as an additional required partner. Following the supplied visual template, cards with multiple recipes print the result IDs in the footer; cards with one recipe print its mode and partner codes. Full recipes remain available in properties.

NUL-006 is data-verified but fails the print text-space check. Its full skill remains in the source and properties, SVG description and text nodes; a proof explicitly identifies overflow and clean print export remains blocked. Changing official wording requires a reviewed source revision.

## Reference illustration draft

The studio initially opens TOC-003 with `public/images/card-generator/tochi-sprout-keeper-v1.png`. It was generated with the built-in imagegen tool from the user's armored chameleon reference. See [the exact prompt and provenance](tochi-artwork-prompt.md). This new illustration is a reference-guided recreation, not a pixel-for-pixel extraction from the supplied card. It remains `not_reviewed` / `draft`, cannot become print-ready automatically, and requires the existing asset and artwork review.

Untouched version-1 legacy workspaces receive this example once. Uploaded/repositioned artwork is preserved, and explicit removal increments the version so the example is not re-added on reload. The remaining 41 cards do not receive recycled Tochi artwork.

## Artwork and approval workflow

1. Open a card and read its creative brief. Supply approved character references where missing.
2. Upload PNG/WebP (up to 10 MB source). The existing compressor preserves alpha, limits dimensions to 2400 px and output to 1 MB. Character resolution is checked against the actual artwork area, cover/contain fit, zoom, physical print size and chosen DPI (300 by default). Standard and edition frames use their respective rendering geometry; there is no fixed 1200 × 800 px minimum.
3. Use background, character/full composition and optional foreground layers. Move/scale each layer within the fixed clipped art window. All stats/text sit above the art layers.
4. Review character identity, unique composition, framing and readability, then approve. A repeated character-file SHA across cards is rejected for approval and clean bulk export.
5. The shared back always uses the exact supplied `public/images/tbc-back.png` (SHA-256 `bbb872f65117aa57bef346a4953d351c0762cb1ee6d425f16a55ac24a70fd79e`). It cannot be replaced by a card, workspace import or logo upload. The full original image fills the existing 63 × 88 mm print area, with no cropping; its original 2:3 aspect is fitted to that print ratio.
6. Run **Periksa artwork & render** for one card, or open **Export / Cetak**, turn off proof, confirm the selected designs have been reviewed, then click **Setujui & periksa N kartu**. The batch checks actual asset bytes, hashes/dimensions and SVG text bounds, and commits approval/render receipts only for passing, unchanged designs. Failed cards are listed with a link to the editor. **Download N kartu yang lolos** explicitly exports only the passing cards; the normal download never silently skips failures.
7. Print readiness requires valid canonical data, artwork resolution and verified bytes, human artwork approval, hash-verified fixed back image, no text overflow, and a render receipt matching the exact current data, placement, asset hashes and layout version.

Uploads get new immutable storage paths. Changing artwork or placement resets its review and render receipt. Reloads/imports distrust cached asset/render verification; clean export automatically rechecks approved designs before downloading. Asset fetches are shared within each batch. Duplicate artwork blocks the affected cards, while unrelated duplicates do not block another selection. Artwork quality, species identity and genuinely different poses require a human reviewer; code cannot certify artistic approval.

### Uploading skill icons

Each skill in **Properties → Skills** has **Upload ikon**, **Ganti ikon**, **Hapus**, and a fit selector. These controls are also available in the new-card form. Supply PNG/WebP/JPEG, up to 10 MB, at least 128 × 128 px. Images are compressed to WebP, at most 768 px per side and 1 MB, with transparency preserved. **Isi lingkaran** crops to fill the circular badge; **Tampilkan gambar utuh** fits the entire image inside it. Removing an upload restores the automatic effect icon.

The two uploads belong to that card's `artwork.skill_icons` array, independently of its character layers and canonical skill definitions. They persist through local/account/JSON workspaces. Replacing, removing or changing an icon's fit resets artwork approval and its render receipt. Asset checks verify actual bytes, hashes and dimensions; SVG, PNG, PDF and ZIP exports embed the selected icons alongside the character and reference frame assets.

Metadata is autosaved locally under the authenticated user and dataset ID. Images are stored in object storage, never as database Base64. Download/import workspace JSON for transfer. The optional account table is owner-scoped by RLS. Account sync has not been verified against a live table; upload tests isolate Storage and use a labeled local image fixture.

## Export and print

- Finished size: 63 × 88 mm; default bleed: 3 mm per edge. Export media is 69 × 94 mm.
- Default PNG: 815 × 1110 px at 300 DPI, including `pHYs` density metadata. 600 DPI is also available.
- Width is configurable with height following 63:88. Bleed is configurable 0–10 mm. Invalid dimensions are rejected.
- Preview and all exports share `renderCardSvg`; external images are fetched, hash-verified and embedded in SVG before export. SVG keeps selectable source text and uses Arial/Helvetica/sans-serif. PDF/PNG rasterization freezes the browser's actual font appearance; PDF places it at explicit physical millimeter dimensions.
- PDF is a high-resolution raster composition in a correctly sized page, **not a fully vector PDF or CMYK/PDF-X prepress file**. Request the printer's color profile and prepress requirements before a large run.
- A4 sheets center a safe grid, leave 3 mm between bleed boxes, alternate front/back pages, and mirror columns for long-edge or rows for short-edge duplex. Default safe margins fit four cards per A4 page.
- Crop guides sit outside the trim boundary. Use actual-size/100% printing, disable fit-to-page, and print a test sheet before a production batch. Printer registration, device screen scale and color reproduction still require physical inspection.
- Proof export is available for incomplete cards and is visibly watermarked. Clean exports are blocked until ready.

## Production mapping plan

`Audit katalog existing` reads production rows and downloads a comparison; it never upserts `game_cards`, skill links, recipes or UIDs. The checked-in audit is an observation, not a deployment script.

Before any future catalog migration: review all 39 field conflicts and the skill/recipe rules, decide how old physical copies and battle history remain versioned, back up affected records, stage a new pilot catalog identity, and obtain explicit approval for the final reviewed migration. Do not apply the old 110-card seed as a shortcut.

Migration 027 adds only a generator workspace table with owner-based RLS. It does not migrate game cards. Review it independently; the repository warns that linked database migration history has not been reconciled, so do not run a blanket `supabase db push`.

## Tests and review artifacts

```sh
npm run test:cards
npm run test:cards:visual
npm run card:masters
npm run build
```

Visual tests need locally installed Chrome (Playwright `channel: chrome`) and the existing Vite Supabase configuration. They mock Auth/Storage and never write production. The unauthenticated route test uses the actual router guard. Tests cover frame snapshots, all 42 card bounds, custom card creation/editing, every rarity switch, draft restoration, exact back image hashes, search, complete Necro text, live positioning, draft/approval invalidation, actual asset bytes, independent skill icon upload/fit/removal/persistence, clean export gate, embedded SVG assets, PNG DPI, PDF MediaBox/pages, ZIP contents and duplex layout.

Baselines live under `tests/visual/card-generator.spec.js-snapshots`. They are **implementation proof baselines, not approval of missing illustrations**. To accept an intentional visual change, review the screenshots and then use `npm run test:cards:visual -- --update-snapshots=all`.

`docs/card-generator/masters/index.html` shows the seven self-contained SVG master proofs. `npm run audit:cards -- --require-print-ready` intentionally exits unsuccessfully while artwork/print issues remain.

## Fixed templates and new cards

Use **Buat kartu → choose rarity → fill card data → upload artwork**. Seven front masters share identical anchors: red sword/ATK at top left, element at top right, heart/HP and shield/DEF along the artwork bottom, character/variant name strip with ID and rarity, two skill panels with colored icons, then Fusion Data and TAG in two full-width stacked footer rows. The approved back is identical for all seven.

Layout v5 follows the user's ten supplied card references. Common and Uncommon use green/silver armor with distinct badges. Rare uses blue/silver/gold for Knight and Thunder, and green/silver/gold for Forest. Epic uses purple/gold armor and diamond crests. Original reference PNG bytes supply only clipped outer rails, fixed rarity badges and Epic crests; editable numeric, Type, name, skill and footer panels are SVG. Character artwork is uploaded separately. Legendary, Mythic and Fusion retain their existing gold, prism and Fusion masters because the supplied references do not define those rarities. See [reference frame provenance](reference-frames.md).

Every printed data field has its own inner text bounds, including Type, ATK/HP/DEF, ID, rarity, names, both skills and footer values. Browser font measurements determine wrapping and size; stored SVG text lengths preserve line widths in exports. Type and rarity labels use controlled condensed lettering. Long names without a variant may use two lines inside the identity ribbon. Cooldown/AP/HP units stay together, and short effects prefer one line when they fit at a readable size. Each field has a clip boundary as a last guard, while render validation checks the original un-clipped bounds and blocks clean export for overflow. The complete source text remains in the SVG. See [the v5 preview](previews/tochi-common-v5.png).

The form accepts the printed ID, character/Fusion name, variant, role, Type, ATK/HP/DEF, both skill names and complete effects, Fusion Data and tags. Choose another rarity at any time without changing the card data or anchors. **Salin sebagai kartu baru** starts a separate editable copy of an official card with fresh artwork review. Custom card skill metadata is derived from the entered full effect text, never written back into the pilot.

Custom cards are persisted in `workspace.custom_cards`, with stable internal `DRAFT-…` identities and independent printed IDs. They appear in the library, support the same preview/review/export gates, and travel with local/account/JSON workspaces. The frozen 30/12 pilot remains unchanged. Custom Fusion Data is print text; it does not install a gameplay recipe or alter live battles. Required-field errors and text overflow block clean export; missing artwork can still be exported as a labeled proof after the data is complete.

## Adding future versioned catalogs

Use the same card, skill, recipe and artwork shapes. Keep a new catalog in its own versioned dataset and supply `expected_counts`; the pilot profile remains fixed at 30/12. Core renderers, text layout, fusion matching, export layout and the workspace composable accept datasets/card arrays. `useCardGenerator(dataset)` scopes persistence by dataset ID; `sanitizeWorkspace` refuses cross-dataset imports.

For a future 110+ pool: add its source and provenance, register a separate dataset entry point/library count, update its explicit profile/recipe constraints, add distinct briefs and references, and run the same validations. Never append unreviewed master cards into the audited pilot JSON. Expansion must preserve stable source codes, exact slot eligibility and existing UID relationships.

## Library references

Export APIs follow [jsPDF documentation](https://github.com/parallax/jsPDF), [JSZip generateAsync](https://stuk.github.io/jszip/documentation/api_jszip/generate_async.html), and [Playwright visual comparisons](https://playwright.dev/docs/test-snapshots).
