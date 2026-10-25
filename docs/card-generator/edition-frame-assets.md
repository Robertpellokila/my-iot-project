# Trial Join and Winning frame assets

Mode: built-in `image_gen`, transparent PNG edits derived from the two card references supplied by the user. No CLI image generation was used. These are reference-derived renderings, not pixel-identical source extractions.

Saved assets (1024 × 1536):
- `public/images/card-generator/edition-frames/trial-join-v2.png`
- `public/images/card-generator/edition-frames/winning-v2.png`

Prompt specifications (summary of the edit requests):
- **Trial Join:** Preserve the portrait frame, Timedoor logo, gold/ivory edging, laurel ribbon, two skill columns and footer panels from the reference. Remove the character illustration, editable names, numbers, descriptions and skill pictures; retain fixed panel labels. Leave the central artwork window and skill medallion interiors transparent for editable layers.
- **Winning:** Preserve the ornate champion frame, gold crowns, prismatic foil rails, header, two horizontal skill panels and footer from the reference. Remove the character illustration and editable name, type, stats, descriptions, rarity value, serial and skill pictures. Keep fixed labels and ornamental geometry, with transparent artwork and skill windows.

SHA-256 and dimensions are recorded in `src/data/card-generator/edition-frames.json`. Export embeds the verified frame bytes. Layout v7.1.0 renders ATK/HP/DEF with the same SVG symbols on all nine templates and derives the Type icon from the selected type. Trial's fixed emblems are covered by ivory SVG wells inside their original panels; the source PNGs remain unchanged.
