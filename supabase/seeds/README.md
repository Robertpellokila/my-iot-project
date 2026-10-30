# Seeds

## Coding questions — pilot v2

`coding_questions_pilot_v2.sql` adds 60 questions across Easy, Medium, Hard and all five quiz authoring modes. Includes Scratch/code illustrations, private workspace keys, hints and explanations. Reruns preserve teacher edits and archives. See [the question seeder guide](../../docs/question-seeder.md) for installation, durations, authoring and validation.

## Timedoor card catalog seed

`timedoor_card_catalog.sql` is the catalog seed generated from the supplied
Timedoor Battle Cards Master Plan v2.2. It contains 110 base card templates,
24 virtual fusion results, 24 fusion recipes, and 50 recipe material slots.

All card art URLs and physical UIDs start empty because the document does not
provide individual artwork or RFID UIDs. To register a physical card, scan its
RFID in Admin → Register Card, choose **Copy Existing Card**, then select the
seeded card type. The new physical row receives the scanned UID and copies the
catalog card's stats, level, rarity, lore, tags, and skill metadata. Fusion
results stay virtual and cannot be assigned RFID UIDs.

The seed adjusts the existing UID constraint to allow a non-fusion template only
when `uid` is empty and `physical_scan_enabled` is false. The registration form
offers those templates as copy sources and keeps newly scanned physical copies
scan-enabled.

The document writes source IDs with hyphens (for example, `COB-001`). This
project's existing database constraint requires underscores in `card_code`,
so internal codes use `COB_001`; the original source ID remains in
`metadata.source_card_code` for reference.

The two skills for each base card are stored both in its catalog metadata and
as links in `game_card_special_skills` to reusable `special_skills` catalog
rows. Those skill rows stay `is_active = false`: the source provides skill
descriptions, but marks their combat rules as subject to playtesting and
finalization. They are visible on each card and remain out of battle until
their effects are reviewed. Fusion recipe entries are also inserted with
`is_active = false`; their names, materials, educational themes, and prototype
stat formulas are available for review. The source does not define dedicated
skills for the fusion results. Fusion preview stats are estimates because the
document does not define the caps mentioned in its formula.

The seed uses its own idempotency key in `game_cards.metadata`, so it can be
rerun without assigning or replacing any RFID UID. Apply it with:

```sh
supabase db query --linked --file supabase/seeds/timedoor_card_catalog.sql
```

Use that command for this seed. The linked project does not currently record the
existing local migrations, so `supabase db push` would try to run those older
migrations again; reconcile that migration history before using `db push`.
