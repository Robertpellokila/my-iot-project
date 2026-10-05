-- Timedoor Battle Cards catalog from the supplied Master Plan v2.2.
-- Card templates intentionally have NULL UIDs; attach each scanned RFID by copying
-- the corresponding seeded card type in the Admin Register Card screen.
-- Skills are catalog metadata until their rules are playtested and implemented.
-- Fusion recipes are seeded inactive because the source labels them prototype data.
BEGIN;

-- Catalog templates are non-fusion cards without RFID UIDs. They are not
-- scannable themselves; physical copies created from them receive unique UIDs.
ALTER TABLE public.game_cards
  DROP CONSTRAINT IF EXISTS game_cards_physical_fusion_uid_check;
ALTER TABLE public.game_cards
  ADD CONSTRAINT game_cards_physical_fusion_uid_check CHECK (
    (fusion_only = true AND uid IS NULL)
    OR (
      fusion_only = false
      AND (
        (uid IS NOT NULL AND trim(uid) <> '')
        OR (uid IS NULL AND physical_scan_enabled = false)
      )
    )
  );

-- Keep this seed repeatable without relying on non-unique card_code values.
CREATE UNIQUE INDEX IF NOT EXISTS game_cards_timedoor_seed_key_uidx
  ON public.game_cards ((metadata ->> 'timedoor_seed_key'))
  WHERE (metadata ->> 'timedoor_seed_key') IS NOT NULL;

WITH seed_rows AS (
  SELECT *
  FROM jsonb_to_recordset($timedoor_cards$[
  {
    "uid": null,
    "name": "Coby — First Spark",
    "element": "Electric",
    "hp": 96,
    "attack": 26,
    "defense": 8,
    "image_url": null,
    "avatar_url": null,
    "level": 1,
    "rarity": "common",
    "card_kind": "normal",
    "fusion_only": false,
    "physical_scan_enabled": false,
    "virtual_key": null,
    "lore": "Coby belajar memimpin tim dan menyalakan semangat bertarung.",
    "metadata": {
      "timedoor_seed_key": "master_plan_v2_2:COB-001",
      "source_card_code": "COB-001",
      "seed_version": "2.2-learning-arcs-fusion",
      "source_document": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion.docx",
      "family_name": "Coby",
      "variant_name": "First Spark",
      "display_name": "Coby — First Spark",
      "learning_arc": "Discovery",
      "lesson_topic": "CODING",
      "learning_mission": "Urutkan 4 instruksi untuk mengaktifkan bendera tim tanpa melewati satu langkah.",
      "skills": [
        {
          "name": "Spark Tap",
          "effect": "Serangan normal; +3 damage bila Coby baru disummon.",
          "slot": 1
        },
        {
          "name": "Cheer Up",
          "effect": "Pulihkan 8 HP satu rekan; CD 2.",
          "slot": 2
        }
      ],
      "fusion_tags": [],
      "catalog_status": "reference_data_pending_skill_playtest"
    },
    "card_code": "COB_001",
    "tags": []
  },
  {
    "uid": null,
    "name": "Coby — Flag Rookie",
    "element": "Electric",
    "hp": 102,
    "attack": 28,
    "defense": 8,
    "image_url": null,
    "avatar_url": null,
    "level": 2,
    "rarity": "common",
    "card_kind": "normal",
    "fusion_only": false,
    "physical_scan_enabled": false,
    "virtual_key": null,
    "lore": "Pembawa bendera muda yang membuka serangan untuk rekannya.",
    "metadata": {
      "timedoor_seed_key": "master_plan_v2_2:COB-002",
      "source_card_code": "COB-002",
      "seed_version": "2.2-learning-arcs-fusion",
      "source_document": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion.docx",
      "family_name": "Coby",
      "variant_name": "Flag Rookie",
      "display_name": "Coby — Flag Rookie",
      "learning_arc": "Discovery",
      "lesson_topic": "CODING",
      "learning_mission": "Gunakan satu variabel team_energy untuk menyimpan dan memperbarui nilai energi.",
      "skills": [
        {
          "name": "Flag Jab",
          "effect": "Serangan normal; +3 damage jika rekan ada di Bench.",
          "slot": 1
        },
        {
          "name": "Cheer Up",
          "effect": "Pulihkan 8 HP satu rekan; CD 2.",
          "slot": 2
        }
      ],
      "fusion_tags": [],
      "catalog_status": "reference_data_pending_skill_playtest"
    },
    "card_code": "COB_002",
    "tags": []
  },
  {
    "uid": null,
    "name": "Coby — Circuit Buddy",
    "element": "Electric",
    "hp": 108,
    "attack": 30,
    "defense": 9,
    "image_url": null,
    "avatar_url": null,
    "level": 3,
    "rarity": "common",
    "card_kind": "normal",
    "fusion_only": false,
    "physical_scan_enabled": false,
    "virtual_key": null,
    "lore": "Rekan ceria yang menghubungkan formasi tim lewat listrik.",
    "metadata": {
      "timedoor_seed_key": "master_plan_v2_2:COB-003",
      "source_card_code": "COB-003",
      "seed_version": "2.2-learning-arcs-fusion",
      "source_document": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion.docx",
      "family_name": "Coby",
      "variant_name": "Circuit Buddy",
      "display_name": "Coby — Circuit Buddy",
      "learning_arc": "Discovery",
      "lesson_topic": "CODING",
      "learning_mission": "Buat event saat rekan masuk arena yang memanggil fungsi penyemangat satu kali.",
      "skills": [
        {
          "name": "Spark Tap",
          "effect": "Serangan normal; +3 damage bila Coby baru disummon.",
          "slot": 1
        },
        {
          "name": "Banner Cover",
          "effect": "Beri Shield 9 kepada satu rekan; CD 2.",
          "slot": 2
        }
      ],
      "fusion_tags": [],
      "catalog_status": "reference_data_pending_skill_playtest"
    },
    "card_code": "COB_003",
    "tags": []
  },
  {
    "uid": null,
    "name": "Coby — Spark Captain",
    "element": "Electric",
    "hp": 108,
    "attack": 29,
    "defense": 9,
    "image_url": null,
    "avatar_url": null,
    "level": 4,
    "rarity": "uncommon",
    "card_kind": "normal",
    "fusion_only": false,
    "physical_scan_enabled": false,
    "virtual_key": null,
    "lore": "Kapten pemula yang menjaga tempo saat rekan berganti.",
    "metadata": {
      "timedoor_seed_key": "master_plan_v2_2:COB-004",
      "source_card_code": "COB-004",
      "seed_version": "2.2-learning-arcs-fusion",
      "source_document": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion.docx",
      "family_name": "Coby",
      "variant_name": "Spark Captain",
      "display_name": "Coby — Spark Captain",
      "learning_arc": "Strategy",
      "lesson_topic": "MATH",
      "learning_mission": "Hitung jumlah putaran dan bonus daya jika tiga rekan bergerak dalam pola 2-3-2.",
      "skills": [
        {
          "name": "Flag Jab",
          "effect": "Serangan normal; +3 damage jika rekan ada di Bench.",
          "slot": 1
        },
        {
          "name": "Banner Cover",
          "effect": "Beri Shield 9 kepada satu rekan; CD 2.",
          "slot": 2
        }
      ],
      "fusion_tags": [],
      "catalog_status": "reference_data_pending_skill_playtest"
    },
    "card_code": "COB_004",
    "tags": []
  },
  {
    "uid": null,
    "name": "Coby — Bright Banner",
    "element": "Electric",
    "hp": 116,
    "attack": 33,
    "defense": 11,
    "image_url": null,
    "avatar_url": null,
    "level": 5,
    "rarity": "uncommon",
    "card_kind": "normal",
    "fusion_only": false,
    "physical_scan_enabled": false,
    "virtual_key": null,
    "lore": "Benderanya membantu tim tetap bertahan di medan sulit.",
    "metadata": {
      "timedoor_seed_key": "master_plan_v2_2:COB-005",
      "source_card_code": "COB-005",
      "seed_version": "2.2-learning-arcs-fusion",
      "source_document": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion.docx",
      "family_name": "Coby",
      "variant_name": "Bright Banner",
      "display_name": "Coby — Bright Banner",
      "learning_arc": "Strategy",
      "lesson_topic": "MATH",
      "learning_mission": "Pilih urutan aksi yang memberi poin tertinggi tanpa melampaui anggaran 10 energi.",
      "skills": [
        {
          "name": "Spark Tap",
          "effect": "Serangan normal; +3 damage bila Coby baru disummon.",
          "slot": 1
        },
        {
          "name": "Arc Rally",
          "effect": "Serangan normal +6 setelah summon rekan; CD 2.",
          "slot": 2
        }
      ],
      "fusion_tags": [],
      "catalog_status": "reference_data_pending_skill_playtest"
    },
    "card_code": "COB_005",
    "tags": []
  },
  {
    "uid": null,
    "name": "Coby — Arc Vanguard",
    "element": "Electric",
    "hp": 118,
    "attack": 33,
    "defense": 11,
    "image_url": null,
    "avatar_url": null,
    "level": 6,
    "rarity": "rare",
    "card_kind": "normal",
    "fusion_only": false,
    "physical_scan_enabled": false,
    "virtual_key": null,
    "lore": "Memimpin serangan terukur setelah pemanggilan rekan.",
    "metadata": {
      "timedoor_seed_key": "master_plan_v2_2:COB-006",
      "source_card_code": "COB-006",
      "seed_version": "2.2-learning-arcs-fusion",
      "source_document": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion.docx",
      "family_name": "Coby",
      "variant_name": "Arc Vanguard",
      "display_name": "Coby — Arc Vanguard",
      "learning_arc": "Communication",
      "lesson_topic": "ENGLISH",
      "learning_mission": "Tulis 3 instruksi bahasa Inggris yang sopan untuk memberi arahan kepada rekan.",
      "skills": [
        {
          "name": "Arc Rally",
          "effect": "Serangan normal +6 setelah summon rekan; CD 2.",
          "slot": 1
        },
        {
          "name": "Team Spirit",
          "effect": "Pulihkan 15 HP satu rekan ATAU beri +5 DEF hingga 1 hit; CD 2.",
          "slot": 2
        }
      ],
      "fusion_tags": [],
      "catalog_status": "reference_data_pending_skill_playtest"
    },
    "card_code": "COB_006",
    "tags": []
  },
  {
    "uid": null,
    "name": "Coby — Volt Commander",
    "element": "Electric",
    "hp": 130,
    "attack": 37,
    "defense": 13,
    "image_url": null,
    "avatar_url": null,
    "level": 7,
    "rarity": "rare",
    "card_kind": "normal",
    "fusion_only": false,
    "physical_scan_enabled": false,
    "virtual_key": null,
    "lore": "Mengatur giliran agar serangan tim lebih efektif.",
    "metadata": {
      "timedoor_seed_key": "master_plan_v2_2:COB-007",
      "source_card_code": "COB-007",
      "seed_version": "2.2-learning-arcs-fusion",
      "source_document": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion.docx",
      "family_name": "Coby",
      "variant_name": "Volt Commander",
      "display_name": "Coby — Volt Commander",
      "learning_arc": "Communication",
      "lesson_topic": "ENGLISH",
      "learning_mission": "Jelaskan dalam bahasa Inggris alasan pembagian peran lead, guard dan attack.",
      "skills": [
        {
          "name": "Flag Jab",
          "effect": "Serangan normal; +3 damage jika rekan ada di Bench.",
          "slot": 1
        },
        {
          "name": "Team Spirit",
          "effect": "Pulihkan 15 HP satu rekan ATAU beri +5 DEF hingga 1 hit; CD 2.",
          "slot": 2
        }
      ],
      "fusion_tags": [],
      "catalog_status": "reference_data_pending_skill_playtest"
    },
    "card_code": "COB_007",
    "tags": []
  },
  {
    "uid": null,
    "name": "Coby — Thunder Standard",
    "element": "Electric",
    "hp": 139,
    "attack": 40,
    "defense": 14,
    "image_url": null,
    "avatar_url": null,
    "level": 8,
    "rarity": "epic",
    "card_kind": "normal",
    "fusion_only": false,
    "physical_scan_enabled": false,
    "virtual_key": null,
    "lore": "Mengangkat panji petir untuk membuka kombinasi taktis.",
    "metadata": {
      "timedoor_seed_key": "master_plan_v2_2:COB-008",
      "source_card_code": "COB-008",
      "seed_version": "2.2-learning-arcs-fusion",
      "source_document": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion.docx",
      "family_name": "Coby",
      "variant_name": "Thunder Standard",
      "display_name": "Coby — Thunder Standard",
      "learning_arc": "Creation",
      "lesson_topic": "SKILL LAB",
      "learning_mission": "Rancang prototipe dashboard tim yang menampilkan status tiga pemain secara real-time.",
      "skills": [
        {
          "name": "Charge Formation",
          "effect": "Serangan normal +8 saat rekan melakukan Switch legal; CD 2.",
          "slot": 1
        },
        {
          "name": "Banner Cover",
          "effect": "Beri Shield 9 kepada satu rekan; CD 2.",
          "slot": 2
        }
      ],
      "fusion_tags": [
        "fusion:academy_lead"
      ],
      "catalog_status": "reference_data_pending_skill_playtest"
    },
    "card_code": "COB_008",
    "tags": [
      "fusion:academy_lead"
    ]
  },
  {
    "uid": null,
    "name": "Coby — Golden Rally",
    "element": "Electric",
    "hp": 154,
    "attack": 44,
    "defense": 17,
    "image_url": null,
    "avatar_url": null,
    "level": 9,
    "rarity": "legendary",
    "card_kind": "normal",
    "fusion_only": false,
    "physical_scan_enabled": false,
    "virtual_key": null,
    "lore": "Pemimpin elit yang mengutamakan keselamatan seluruh tim.",
    "metadata": {
      "timedoor_seed_key": "master_plan_v2_2:COB-009",
      "source_card_code": "COB-009",
      "seed_version": "2.2-learning-arcs-fusion",
      "source_document": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion.docx",
      "family_name": "Coby",
      "variant_name": "Golden Rally",
      "display_name": "Coby — Golden Rally",
      "learning_arc": "Creation",
      "lesson_topic": "SKILL LAB",
      "learning_mission": "Uji dashboard dengan 3 skenario kerusakan; catat data dan buat presentasi singkat.",
      "skills": [
        {
          "name": "Golden Standard",
          "effect": "Sekali/battle, serangan normal rekan berikutnya +8; tidak memberi aksi.",
          "slot": 1
        },
        {
          "name": "Team Spirit",
          "effect": "Pulihkan 15 HP satu rekan ATAU beri +5 DEF hingga 1 hit; CD 2.",
          "slot": 2
        }
      ],
      "fusion_tags": [],
      "catalog_status": "reference_data_pending_skill_playtest"
    },
    "card_code": "COB_009",
    "tags": []
  },
  {
    "uid": null,
    "name": "Coby — Academy Stormbear",
    "element": "Electric",
    "hp": 166,
    "attack": 48,
    "defense": 19,
    "image_url": null,
    "avatar_url": null,
    "level": 10,
    "rarity": "mythic",
    "card_kind": "normal",
    "fusion_only": false,
    "physical_scan_enabled": false,
    "virtual_key": null,
    "lore": "Wujud puncak Coby yang menyatukan semangat dan petir.",
    "metadata": {
      "timedoor_seed_key": "master_plan_v2_2:COB-010",
      "source_card_code": "COB-010",
      "seed_version": "2.2-learning-arcs-fusion",
      "source_document": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion.docx",
      "family_name": "Coby",
      "variant_name": "Academy Stormbear",
      "display_name": "Coby — Academy Stormbear",
      "learning_arc": "Creation",
      "lesson_topic": "SKILL LAB",
      "learning_mission": "Presentasikan solusi tim dengan demo kode, perhitungan keputusan, dan penjelasan bahasa Inggris.",
      "skills": [
        {
          "name": "Storm Command",
          "effect": "Sekali/battle, pilih heal 18 satu rekan ATAU Shield 16; CD 3.",
          "slot": 1
        },
        {
          "name": "Charge Formation",
          "effect": "Serangan normal +8 saat rekan melakukan Switch legal; CD 2.",
          "slot": 2
        }
      ],
      "fusion_tags": [],
      "catalog_status": "reference_data_pending_skill_playtest"
    },
    "card_code": "COB_010",
    "tags": []
  },
  {
    "uid": null,
    "name": "Tochi — Leaf Explorer",
    "element": "Grass",
    "hp": 99,
    "attack": 25,
    "defense": 9,
    "image_url": null,
    "avatar_url": null,
    "level": 1,
    "rarity": "common",
    "card_kind": "normal",
    "fusion_only": false,
    "physical_scan_enabled": false,
    "virtual_key": null,
    "lore": "Tochi menjelajah hutan digital dan mengenali jalur tanaman.",
    "metadata": {
      "timedoor_seed_key": "master_plan_v2_2:TOC-001",
      "source_card_code": "TOC-001",
      "seed_version": "2.2-learning-arcs-fusion",
      "source_document": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion.docx",
      "family_name": "Tochi",
      "variant_name": "Leaf Explorer",
      "display_name": "Tochi — Leaf Explorer",
      "learning_arc": "Discovery",
      "lesson_topic": "CODING",
      "learning_mission": "Susun algoritma langkah demi langkah agar tanaman digital tumbuh dari satu benih.",
      "skills": [
        {
          "name": "Leaf Swipe",
          "effect": "Serangan normal; jika diri punya Shield, +3 damage.",
          "slot": 1
        },
        {
          "name": "Sprout Rest",
          "effect": "Pulihkan diri 7 HP di akhir turn berikutnya; CD 2.",
          "slot": 2
        }
      ],
      "fusion_tags": [],
      "catalog_status": "reference_data_pending_skill_playtest"
    },
    "card_code": "TOC_001",
    "tags": []
  },
  {
    "uid": null,
    "name": "Tochi — Moss Scout",
    "element": "Grass",
    "hp": 105,
    "attack": 27,
    "defense": 9,
    "image_url": null,
    "avatar_url": null,
    "level": 2,
    "rarity": "common",
    "card_kind": "normal",
    "fusion_only": false,
    "physical_scan_enabled": false,
    "virtual_key": null,
    "lore": "Penyamar lincah yang memburu ruang aman di antara lumut.",
    "metadata": {
      "timedoor_seed_key": "master_plan_v2_2:TOC-002",
      "source_card_code": "TOC-002",
      "seed_version": "2.2-learning-arcs-fusion",
      "source_document": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion.docx",
      "family_name": "Tochi",
      "variant_name": "Moss Scout",
      "display_name": "Tochi — Moss Scout",
      "learning_arc": "Discovery",
      "lesson_topic": "CODING",
      "learning_mission": "Buat loop yang menyiram empat petak kebun tanpa menulis perintah berulang.",
      "skills": [
        {
          "name": "Moss Jab",
          "effect": "Serangan normal; +3 damage saat diri di HP penuh.",
          "slot": 1
        },
        {
          "name": "Sprout Rest",
          "effect": "Pulihkan diri 7 HP di akhir turn berikutnya; CD 2.",
          "slot": 2
        }
      ],
      "fusion_tags": [],
      "catalog_status": "reference_data_pending_skill_playtest"
    },
    "card_code": "TOC_002",
    "tags": []
  },
  {
    "uid": null,
    "name": "Tochi — Sprout Keeper",
    "element": "Grass",
    "hp": 110,
    "attack": 29,
    "defense": 10,
    "image_url": null,
    "avatar_url": null,
    "level": 3,
    "rarity": "common",
    "card_kind": "normal",
    "fusion_only": false,
    "physical_scan_enabled": false,
    "virtual_key": null,
    "lore": "Penjaga tunas yang membantu rekan bertahan lebih lama.",
    "metadata": {
      "timedoor_seed_key": "master_plan_v2_2:TOC-003",
      "source_card_code": "TOC-003",
      "seed_version": "2.2-learning-arcs-fusion",
      "source_document": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion.docx",
      "family_name": "Tochi",
      "variant_name": "Sprout Keeper",
      "display_name": "Tochi — Sprout Keeper",
      "learning_arc": "Discovery",
      "lesson_topic": "CODING",
      "learning_mission": "Gunakan if/else untuk menyiram hanya saat kelembapan di bawah ambang batas.",
      "skills": [
        {
          "name": "Leaf Swipe",
          "effect": "Serangan normal; jika diri punya Shield, +3 damage.",
          "slot": 1
        },
        {
          "name": "Camo Guard",
          "effect": "Beri +4 DEF pada diri hingga satu pukulan; CD 2.",
          "slot": 2
        }
      ],
      "fusion_tags": [],
      "catalog_status": "reference_data_pending_skill_playtest"
    },
    "card_code": "TOC_003",
    "tags": []
  },
  {
    "uid": null,
    "name": "Tochi — Camo Ranger",
    "element": "Grass",
    "hp": 111,
    "attack": 28,
    "defense": 10,
    "image_url": null,
    "avatar_url": null,
    "level": 4,
    "rarity": "uncommon",
    "card_kind": "normal",
    "fusion_only": false,
    "physical_scan_enabled": false,
    "virtual_key": null,
    "lore": "Menyatu dengan warna hutan untuk menghindari ancaman.",
    "metadata": {
      "timedoor_seed_key": "master_plan_v2_2:TOC-004",
      "source_card_code": "TOC-004",
      "seed_version": "2.2-learning-arcs-fusion",
      "source_document": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion.docx",
      "family_name": "Tochi",
      "variant_name": "Camo Ranger",
      "display_name": "Tochi — Camo Ranger",
      "learning_arc": "Strategy",
      "lesson_topic": "MATH",
      "learning_mission": "Temukan pola 3, 6, 12, 24 dan perkirakan pertumbuhan tahap berikutnya.",
      "skills": [
        {
          "name": "Moss Jab",
          "effect": "Serangan normal; +3 damage saat diri di HP penuh.",
          "slot": 1
        },
        {
          "name": "Camo Guard",
          "effect": "Beri +4 DEF pada diri hingga satu pukulan; CD 2.",
          "slot": 2
        }
      ],
      "fusion_tags": [],
      "catalog_status": "reference_data_pending_skill_playtest"
    },
    "card_code": "TOC_004",
    "tags": []
  },
  {
    "uid": null,
    "name": "Tochi — Vine Tactician",
    "element": "Grass",
    "hp": 119,
    "attack": 32,
    "defense": 12,
    "image_url": null,
    "avatar_url": null,
    "level": 5,
    "rarity": "uncommon",
    "card_kind": "normal",
    "fusion_only": false,
    "physical_scan_enabled": false,
    "virtual_key": null,
    "lore": "Menggunakan sulur untuk memaksa lawan berhitung.",
    "metadata": {
      "timedoor_seed_key": "master_plan_v2_2:TOC-005",
      "source_card_code": "TOC-005",
      "seed_version": "2.2-learning-arcs-fusion",
      "source_document": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion.docx",
      "family_name": "Tochi",
      "variant_name": "Vine Tactician",
      "display_name": "Tochi — Vine Tactician",
      "learning_arc": "Strategy",
      "lesson_topic": "MATH",
      "learning_mission": "Hitung luas kebun digital dari susunan petak berbentuk persegi panjang.",
      "skills": [
        {
          "name": "Leaf Swipe",
          "effect": "Serangan normal; jika diri punya Shield, +3 damage.",
          "slot": 1
        },
        {
          "name": "Vine Trick",
          "effect": "Damage normal dan Root satu aksi Switch sukarela; CD 2.",
          "slot": 2
        }
      ],
      "fusion_tags": [
        "fusion:root_control"
      ],
      "catalog_status": "reference_data_pending_skill_playtest"
    },
    "card_code": "TOC_005",
    "tags": [
      "fusion:root_control"
    ]
  },
  {
    "uid": null,
    "name": "Tochi — Forest Scout",
    "element": "Grass",
    "hp": 121,
    "attack": 32,
    "defense": 12,
    "image_url": null,
    "avatar_url": null,
    "level": 6,
    "rarity": "rare",
    "card_kind": "normal",
    "fusion_only": false,
    "physical_scan_enabled": false,
    "virtual_key": null,
    "lore": "Pengintai andal yang menahan pergantian lawan sesaat.",
    "metadata": {
      "timedoor_seed_key": "master_plan_v2_2:TOC-006",
      "source_card_code": "TOC-006",
      "seed_version": "2.2-learning-arcs-fusion",
      "source_document": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion.docx",
      "family_name": "Tochi",
      "variant_name": "Forest Scout",
      "display_name": "Tochi — Forest Scout",
      "learning_arc": "Communication",
      "lesson_topic": "ENGLISH",
      "learning_mission": "Tuliskan 3 kalimat deskripsi berbahasa Inggris tentang habitat Tochi.",
      "skills": [
        {
          "name": "Vine Trick",
          "effect": "Damage normal dan Root satu aksi Switch sukarela; CD 2.",
          "slot": 1
        },
        {
          "name": "Green Recovery",
          "effect": "Pulihkan diri 10 HP pada akhir turn berikutnya; CD 2.",
          "slot": 2
        }
      ],
      "fusion_tags": [
        "fusion:root_control"
      ],
      "catalog_status": "reference_data_pending_skill_playtest"
    },
    "card_code": "TOC_006",
    "tags": [
      "fusion:root_control"
    ]
  },
  {
    "uid": null,
    "name": "Tochi — Wildroot Guardian",
    "element": "Grass",
    "hp": 133,
    "attack": 36,
    "defense": 14,
    "image_url": null,
    "avatar_url": null,
    "level": 7,
    "rarity": "rare",
    "card_kind": "normal",
    "fusion_only": false,
    "physical_scan_enabled": false,
    "virtual_key": null,
    "lore": "Melindungi jalur tim dengan akar dan regenerasi.",
    "metadata": {
      "timedoor_seed_key": "master_plan_v2_2:TOC-007",
      "source_card_code": "TOC-007",
      "seed_version": "2.2-learning-arcs-fusion",
      "source_document": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion.docx",
      "family_name": "Tochi",
      "variant_name": "Wildroot Guardian",
      "display_name": "Tochi — Wildroot Guardian",
      "learning_arc": "Communication",
      "lesson_topic": "ENGLISH",
      "learning_mission": "Jelaskan petunjuk arah dalam bahasa Inggris untuk melewati labirin taman.",
      "skills": [
        {
          "name": "Moss Jab",
          "effect": "Serangan normal; +3 damage saat diri di HP penuh.",
          "slot": 1
        },
        {
          "name": "Green Recovery",
          "effect": "Pulihkan diri 10 HP pada akhir turn berikutnya; CD 2.",
          "slot": 2
        }
      ],
      "fusion_tags": [],
      "catalog_status": "reference_data_pending_skill_playtest"
    },
    "card_code": "TOC_007",
    "tags": []
  },
  {
    "uid": null,
    "name": "Tochi — Emerald Illusion",
    "element": "Grass",
    "hp": 142,
    "attack": 39,
    "defense": 15,
    "image_url": null,
    "avatar_url": null,
    "level": 8,
    "rarity": "epic",
    "card_kind": "normal",
    "fusion_only": false,
    "physical_scan_enabled": false,
    "virtual_key": null,
    "lore": "Ilusi dedaunan yang mengecoh serangan berikutnya.",
    "metadata": {
      "timedoor_seed_key": "master_plan_v2_2:TOC-008",
      "source_card_code": "TOC-008",
      "seed_version": "2.2-learning-arcs-fusion",
      "source_document": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion.docx",
      "family_name": "Tochi",
      "variant_name": "Emerald Illusion",
      "display_name": "Tochi — Emerald Illusion",
      "learning_arc": "Creation",
      "lesson_topic": "SKILL LAB",
      "learning_mission": "Rancang Smart Garden sederhana dengan aturan sensor dan gambar alur.",
      "skills": [
        {
          "name": "Thorn Circuit",
          "effect": "Damage normal +5 ke target yang sedang Root; CD 2.",
          "slot": 1
        },
        {
          "name": "Camo Guard",
          "effect": "Beri +4 DEF pada diri hingga satu pukulan; CD 2.",
          "slot": 2
        }
      ],
      "fusion_tags": [
        "fusion:academy_lead"
      ],
      "catalog_status": "reference_data_pending_skill_playtest"
    },
    "card_code": "TOC_008",
    "tags": [
      "fusion:academy_lead"
    ]
  },
  {
    "uid": null,
    "name": "Tochi — Ancient Canopy",
    "element": "Grass",
    "hp": 157,
    "attack": 43,
    "defense": 18,
    "image_url": null,
    "avatar_url": null,
    "level": 9,
    "rarity": "legendary",
    "card_kind": "normal",
    "fusion_only": false,
    "physical_scan_enabled": false,
    "virtual_key": null,
    "lore": "Pelindung kanopi tua dengan kontrol yang penuh perhitungan.",
    "metadata": {
      "timedoor_seed_key": "master_plan_v2_2:TOC-009",
      "source_card_code": "TOC-009",
      "seed_version": "2.2-learning-arcs-fusion",
      "source_document": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion.docx",
      "family_name": "Tochi",
      "variant_name": "Ancient Canopy",
      "display_name": "Tochi — Ancient Canopy",
      "learning_arc": "Creation",
      "lesson_topic": "SKILL LAB",
      "learning_mission": "Ukur hasil tiga simulasi kelembapan dan sajikan hasilnya dalam grafik.",
      "skills": [
        {
          "name": "Ancient Root",
          "effect": "Sekali/battle, Root satu Switch sukarela tanpa damage; CD 3.",
          "slot": 1
        },
        {
          "name": "Green Recovery",
          "effect": "Pulihkan diri 10 HP pada akhir turn berikutnya; CD 2.",
          "slot": 2
        }
      ],
      "fusion_tags": [],
      "catalog_status": "reference_data_pending_skill_playtest"
    },
    "card_code": "TOC_009",
    "tags": []
  },
  {
    "uid": null,
    "name": "Tochi — Worldtree Tochi",
    "element": "Grass",
    "hp": 169,
    "attack": 47,
    "defense": 20,
    "image_url": null,
    "avatar_url": null,
    "level": 10,
    "rarity": "mythic",
    "card_kind": "normal",
    "fusion_only": false,
    "physical_scan_enabled": false,
    "virtual_key": null,
    "lore": "Wujud legenda hutan yang memulihkan dan menahan tempo.",
    "metadata": {
      "timedoor_seed_key": "master_plan_v2_2:TOC-010",
      "source_card_code": "TOC-010",
      "seed_version": "2.2-learning-arcs-fusion",
      "source_document": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion.docx",
      "family_name": "Tochi",
      "variant_name": "Worldtree Tochi",
      "display_name": "Tochi — Worldtree Tochi",
      "learning_arc": "Creation",
      "lesson_topic": "SKILL LAB",
      "learning_mission": "Demokan taman pintar: kode if/else, kalkulasi air, dan penjelasan Inggris.",
      "skills": [
        {
          "name": "Worldtree Pulse",
          "effect": "Sekali per battle, pulihkan 15 HP pada satu kartu Active milikmu; cooldown 3 ronde.",
          "slot": 1
        },
        {
          "name": "Thorn Circuit",
          "effect": "Damage normal +5 ke target yang sedang Root; CD 2.",
          "slot": 2
        }
      ],
      "fusion_tags": [],
      "catalog_status": "reference_data_pending_skill_playtest"
    },
    "card_code": "TOC_010",
    "tags": []
  },
  {
    "uid": null,
    "name": "Falcon — Sky Cadet",
    "element": "Wind",
    "hp": 91,
    "attack": 29,
    "defense": 7,
    "image_url": null,
    "avatar_url": null,
    "level": 1,
    "rarity": "common",
    "card_kind": "normal",
    "fusion_only": false,
    "physical_scan_enabled": false,
    "virtual_key": null,
    "lore": "Falcon berlatih mengepak dan mengenali arus udara.",
    "metadata": {
      "timedoor_seed_key": "master_plan_v2_2:FAL-001",
      "source_card_code": "FAL-001",
      "seed_version": "2.2-learning-arcs-fusion",
      "source_document": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion.docx",
      "family_name": "Falcon",
      "variant_name": "Sky Cadet",
      "display_name": "Falcon — Sky Cadet",
      "learning_arc": "Discovery",
      "lesson_topic": "CODING",
      "learning_mission": "Urutkan perintah takeoff, steer, land untuk penerbangan aman.",
      "skills": [
        {
          "name": "Wing Tap",
          "effect": "Serangan normal; +3 damage pada aksi pertama sejak summon.",
          "slot": 1
        },
        {
          "name": "Safe Draft",
          "effect": "Berikan +4 DEF satu rekan hingga 1 hit; CD 2.",
          "slot": 2
        }
      ],
      "fusion_tags": [],
      "catalog_status": "reference_data_pending_skill_playtest"
    },
    "card_code": "FAL_001",
    "tags": []
  },
  {
    "uid": null,
    "name": "Falcon — Cloud Scout",
    "element": "Wind",
    "hp": 97,
    "attack": 31,
    "defense": 7,
    "image_url": null,
    "avatar_url": null,
    "level": 2,
    "rarity": "common",
    "card_kind": "normal",
    "fusion_only": false,
    "physical_scan_enabled": false,
    "virtual_key": null,
    "lore": "Pengamat langit yang mencari kesempatan membuka duel.",
    "metadata": {
      "timedoor_seed_key": "master_plan_v2_2:FAL-002",
      "source_card_code": "FAL-002",
      "seed_version": "2.2-learning-arcs-fusion",
      "source_document": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion.docx",
      "family_name": "Falcon",
      "variant_name": "Cloud Scout",
      "display_name": "Falcon — Cloud Scout",
      "learning_arc": "Discovery",
      "lesson_topic": "CODING",
      "learning_mission": "Gunakan event tombol untuk mengubah arah Falcon saat dimainkan.",
      "skills": [
        {
          "name": "Cloud Dive",
          "effect": "Serangan normal; +3 damage setelah Switch yang legal.",
          "slot": 1
        },
        {
          "name": "Safe Draft",
          "effect": "Berikan +4 DEF satu rekan hingga 1 hit; CD 2.",
          "slot": 2
        }
      ],
      "fusion_tags": [],
      "catalog_status": "reference_data_pending_skill_playtest"
    },
    "card_code": "FAL_002",
    "tags": []
  },
  {
    "uid": null,
    "name": "Falcon — Draft Glider",
    "element": "Wind",
    "hp": 103,
    "attack": 33,
    "defense": 8,
    "image_url": null,
    "avatar_url": null,
    "level": 3,
    "rarity": "common",
    "card_kind": "normal",
    "fusion_only": false,
    "physical_scan_enabled": false,
    "virtual_key": null,
    "lore": "Memanfaatkan hembusan pendek untuk mendahului lawan.",
    "metadata": {
      "timedoor_seed_key": "master_plan_v2_2:FAL-003",
      "source_card_code": "FAL-003",
      "seed_version": "2.2-learning-arcs-fusion",
      "source_document": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion.docx",
      "family_name": "Falcon",
      "variant_name": "Draft Glider",
      "display_name": "Falcon — Draft Glider",
      "learning_arc": "Discovery",
      "lesson_topic": "CODING",
      "learning_mission": "Buat loop pemeriksaan batas arena agar Falcon tidak keluar peta.",
      "skills": [
        {
          "name": "Wing Tap",
          "effect": "Serangan normal; +3 damage pada aksi pertama sejak summon.",
          "slot": 1
        },
        {
          "name": "Wind Relay",
          "effect": "Switch satu rekan sebagai aksi, tanpa draw; CD 2.",
          "slot": 2
        }
      ],
      "fusion_tags": [],
      "catalog_status": "reference_data_pending_skill_playtest"
    },
    "card_code": "FAL_003",
    "tags": []
  },
  {
    "uid": null,
    "name": "Falcon — Gust Patrol",
    "element": "Wind",
    "hp": 103,
    "attack": 32,
    "defense": 8,
    "image_url": null,
    "avatar_url": null,
    "level": 4,
    "rarity": "uncommon",
    "card_kind": "normal",
    "fusion_only": false,
    "physical_scan_enabled": false,
    "virtual_key": null,
    "lore": "Penjaga udara yang membantu rekan berganti posisi.",
    "metadata": {
      "timedoor_seed_key": "master_plan_v2_2:FAL-004",
      "source_card_code": "FAL-004",
      "seed_version": "2.2-learning-arcs-fusion",
      "source_document": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion.docx",
      "family_name": "Falcon",
      "variant_name": "Gust Patrol",
      "display_name": "Falcon — Gust Patrol",
      "learning_arc": "Strategy",
      "lesson_topic": "MATH",
      "learning_mission": "Hitung jarak lintasan dari tiga segmen pada grid koordinat.",
      "skills": [
        {
          "name": "Cloud Dive",
          "effect": "Serangan normal; +3 damage setelah Switch yang legal.",
          "slot": 1
        },
        {
          "name": "Wind Relay",
          "effect": "Switch satu rekan sebagai aksi, tanpa draw; CD 2.",
          "slot": 2
        }
      ],
      "fusion_tags": [],
      "catalog_status": "reference_data_pending_skill_playtest"
    },
    "card_code": "FAL_004",
    "tags": []
  },
  {
    "uid": null,
    "name": "Falcon — Aerial Ranger",
    "element": "Wind",
    "hp": 111,
    "attack": 36,
    "defense": 10,
    "image_url": null,
    "avatar_url": null,
    "level": 5,
    "rarity": "uncommon",
    "card_kind": "normal",
    "fusion_only": false,
    "physical_scan_enabled": false,
    "virtual_key": null,
    "lore": "Penyerang cepat yang unggul saat baru masuk arena.",
    "metadata": {
      "timedoor_seed_key": "master_plan_v2_2:FAL-005",
      "source_card_code": "FAL-005",
      "seed_version": "2.2-learning-arcs-fusion",
      "source_document": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion.docx",
      "family_name": "Falcon",
      "variant_name": "Aerial Ranger",
      "display_name": "Falcon — Aerial Ranger",
      "learning_arc": "Strategy",
      "lesson_topic": "MATH",
      "learning_mission": "Bandingkan waktu dua rute penerbangan dan pilih rute yang paling efisien.",
      "skills": [
        {
          "name": "Wing Tap",
          "effect": "Serangan normal; +3 damage pada aksi pertama sejak summon.",
          "slot": 1
        },
        {
          "name": "Gale Dive",
          "effect": "Serangan normal +5 pada aksi pertama sejak summon; CD 1.",
          "slot": 2
        }
      ],
      "fusion_tags": [],
      "catalog_status": "reference_data_pending_skill_playtest"
    },
    "card_code": "FAL_005",
    "tags": []
  },
  {
    "uid": null,
    "name": "Falcon — Gale Diver",
    "element": "Wind",
    "hp": 113,
    "attack": 36,
    "defense": 10,
    "image_url": null,
    "avatar_url": null,
    "level": 6,
    "rarity": "rare",
    "card_kind": "normal",
    "fusion_only": false,
    "physical_scan_enabled": false,
    "virtual_key": null,
    "lore": "Menyelam dari angin kencang untuk serangan pembuka.",
    "metadata": {
      "timedoor_seed_key": "master_plan_v2_2:FAL-006",
      "source_card_code": "FAL-006",
      "seed_version": "2.2-learning-arcs-fusion",
      "source_document": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion.docx",
      "family_name": "Falcon",
      "variant_name": "Gale Diver",
      "display_name": "Falcon — Gale Diver",
      "learning_arc": "Communication",
      "lesson_topic": "ENGLISH",
      "learning_mission": "Tulis 4 kalimat instruksi arah berbahasa Inggris memakai left/right/forward.",
      "skills": [
        {
          "name": "Gale Dive",
          "effect": "Serangan normal +5 pada aksi pertama sejak summon; CD 1.",
          "slot": 1
        },
        {
          "name": "Tailwind",
          "effect": "Switch satu rekan dan +4 DEF sampai 1 hit; tanpa draw; CD 2.",
          "slot": 2
        }
      ],
      "fusion_tags": [],
      "catalog_status": "reference_data_pending_skill_playtest"
    },
    "card_code": "FAL_006",
    "tags": []
  },
  {
    "uid": null,
    "name": "Falcon — Storm Navigator",
    "element": "Wind",
    "hp": 125,
    "attack": 40,
    "defense": 12,
    "image_url": null,
    "avatar_url": null,
    "level": 7,
    "rarity": "rare",
    "card_kind": "normal",
    "fusion_only": false,
    "physical_scan_enabled": false,
    "virtual_key": null,
    "lore": "Membaca arah angin dan mengatur rotasi satu tim.",
    "metadata": {
      "timedoor_seed_key": "master_plan_v2_2:FAL-007",
      "source_card_code": "FAL-007",
      "seed_version": "2.2-learning-arcs-fusion",
      "source_document": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion.docx",
      "family_name": "Falcon",
      "variant_name": "Storm Navigator",
      "display_name": "Falcon — Storm Navigator",
      "learning_arc": "Communication",
      "lesson_topic": "ENGLISH",
      "learning_mission": "Lakukan simulasi radio: satu siswa memberi instruksi, lainnya menavigasi.",
      "skills": [
        {
          "name": "Cloud Dive",
          "effect": "Serangan normal; +3 damage setelah Switch yang legal.",
          "slot": 1
        },
        {
          "name": "Tailwind",
          "effect": "Switch satu rekan dan +4 DEF sampai 1 hit; tanpa draw; CD 2.",
          "slot": 2
        }
      ],
      "fusion_tags": [],
      "catalog_status": "reference_data_pending_skill_playtest"
    },
    "card_code": "FAL_007",
    "tags": []
  },
  {
    "uid": null,
    "name": "Falcon — Tempest Ace",
    "element": "Wind",
    "hp": 134,
    "attack": 43,
    "defense": 13,
    "image_url": null,
    "avatar_url": null,
    "level": 8,
    "rarity": "epic",
    "card_kind": "normal",
    "fusion_only": false,
    "physical_scan_enabled": false,
    "virtual_key": null,
    "lore": "Ahli manuver dengan serangan cepat namun tubuh ringkih.",
    "metadata": {
      "timedoor_seed_key": "master_plan_v2_2:FAL-008",
      "source_card_code": "FAL-008",
      "seed_version": "2.2-learning-arcs-fusion",
      "source_document": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion.docx",
      "family_name": "Falcon",
      "variant_name": "Tempest Ace",
      "display_name": "Falcon — Tempest Ace",
      "learning_arc": "Creation",
      "lesson_topic": "SKILL LAB",
      "learning_mission": "Buat mini game navigasi dengan rintangan dan sistem skor.",
      "skills": [
        {
          "name": "Tempest Feint",
          "effect": "Serangan normal +6 setelah tim Switch; CD 2.",
          "slot": 1
        },
        {
          "name": "Wind Relay",
          "effect": "Switch satu rekan sebagai aksi, tanpa draw; CD 2.",
          "slot": 2
        }
      ],
      "fusion_tags": [
        "fusion:advanced_wind"
      ],
      "catalog_status": "reference_data_pending_skill_playtest"
    },
    "card_code": "FAL_008",
    "tags": [
      "fusion:advanced_wind"
    ]
  },
  {
    "uid": null,
    "name": "Falcon — Azure Sky Marshal",
    "element": "Wind",
    "hp": 149,
    "attack": 47,
    "defense": 16,
    "image_url": null,
    "avatar_url": null,
    "level": 9,
    "rarity": "legendary",
    "card_kind": "normal",
    "fusion_only": false,
    "physical_scan_enabled": false,
    "virtual_key": null,
    "lore": "Komandan langit yang mengubah posisi jadi peluang.",
    "metadata": {
      "timedoor_seed_key": "master_plan_v2_2:FAL-009",
      "source_card_code": "FAL-009",
      "seed_version": "2.2-learning-arcs-fusion",
      "source_document": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion.docx",
      "family_name": "Falcon",
      "variant_name": "Azure Sky Marshal",
      "display_name": "Falcon — Azure Sky Marshal",
      "learning_arc": "Creation",
      "lesson_topic": "SKILL LAB",
      "learning_mission": "Uji kecepatan Falcon pada tiga rute; visualisasikan hasil pengukuran.",
      "skills": [
        {
          "name": "Sky Marshal",
          "effect": "Sekali/battle, kurangi 10 damage hit berikutnya pada rekan.",
          "slot": 1
        },
        {
          "name": "Tailwind",
          "effect": "Switch satu rekan dan +4 DEF sampai 1 hit; tanpa draw; CD 2.",
          "slot": 2
        }
      ],
      "fusion_tags": [],
      "catalog_status": "reference_data_pending_skill_playtest"
    },
    "card_code": "FAL_009",
    "tags": []
  },
  {
    "uid": null,
    "name": "Falcon — Celestial Falcon",
    "element": "Wind",
    "hp": 161,
    "attack": 51,
    "defense": 18,
    "image_url": null,
    "avatar_url": null,
    "level": 10,
    "rarity": "mythic",
    "card_kind": "normal",
    "fusion_only": false,
    "physical_scan_enabled": false,
    "virtual_key": null,
    "lore": "Wujud puncak yang menguasai tempo, bukan aksi tambahan.",
    "metadata": {
      "timedoor_seed_key": "master_plan_v2_2:FAL-010",
      "source_card_code": "FAL-010",
      "seed_version": "2.2-learning-arcs-fusion",
      "source_document": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion.docx",
      "family_name": "Falcon",
      "variant_name": "Celestial Falcon",
      "display_name": "Falcon — Celestial Falcon",
      "learning_arc": "Creation",
      "lesson_topic": "SKILL LAB",
      "learning_mission": "Presentasikan demo game penerbangan yang menggabungkan coding, vektor, dan English.",
      "skills": [
        {
          "name": "Celestial Draft",
          "effect": "Sekali/battle, Switch aman dan beri Shield 12; tanpa extra action.",
          "slot": 1
        },
        {
          "name": "Tempest Feint",
          "effect": "Serangan normal +6 setelah tim Switch; CD 2.",
          "slot": 2
        }
      ],
      "fusion_tags": [],
      "catalog_status": "reference_data_pending_skill_playtest"
    },
    "card_code": "FAL_010",
    "tags": []
  },
  {
    "uid": null,
    "name": "Byte Fox — Byte Cub",
    "element": "Wind",
    "hp": 90,
    "attack": 31,
    "defense": 7,
    "image_url": null,
    "avatar_url": null,
    "level": 1,
    "rarity": "common",
    "card_kind": "normal",
    "fusion_only": false,
    "physical_scan_enabled": false,
    "virtual_key": null,
    "lore": "Rubah kecil penasaran yang mencoba lompatan digital.",
    "metadata": {
      "timedoor_seed_key": "master_plan_v2_2:FOX-001",
      "source_card_code": "FOX-001",
      "seed_version": "2.2-learning-arcs-fusion",
      "source_document": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion.docx",
      "family_name": "Byte Fox",
      "variant_name": "Byte Cub",
      "display_name": "Byte Fox — Byte Cub",
      "learning_arc": "Discovery",
      "lesson_topic": "CODING",
      "learning_mission": "Tulis urutan aksi berulang agar Byte Fox melompati rintangan.",
      "skills": [
        {
          "name": "Byte Swipe",
          "effect": "Serangan normal; +3 damage bila baru masuk Active.",
          "slot": 1
        },
        {
          "name": "Quick Step",
          "effect": "Beri +4 DEF diri sampai 1 hit; CD 2.",
          "slot": 2
        }
      ],
      "fusion_tags": [],
      "catalog_status": "reference_data_pending_skill_playtest"
    },
    "card_code": "FOX_001",
    "tags": []
  },
  {
    "uid": null,
    "name": "Byte Fox — Pixel Dash",
    "element": "Wind",
    "hp": 94,
    "attack": 33,
    "defense": 7,
    "image_url": null,
    "avatar_url": null,
    "level": 2,
    "rarity": "common",
    "card_kind": "normal",
    "fusion_only": false,
    "physical_scan_enabled": false,
    "virtual_key": null,
    "lore": "Pelari sirkuit yang selalu mencari jalur paling singkat.",
    "metadata": {
      "timedoor_seed_key": "master_plan_v2_2:FOX-002",
      "source_card_code": "FOX-002",
      "seed_version": "2.2-learning-arcs-fusion",
      "source_document": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion.docx",
      "family_name": "Byte Fox",
      "variant_name": "Pixel Dash",
      "display_name": "Byte Fox — Pixel Dash",
      "learning_arc": "Discovery",
      "lesson_topic": "CODING",
      "learning_mission": "Gunakan variabel speed dan ubah nilainya saat karakter memperoleh boost.",
      "skills": [
        {
          "name": "Dash Strike",
          "effect": "Serangan normal +3 setelah Switch legal; CD 1.",
          "slot": 1
        },
        {
          "name": "Quick Step",
          "effect": "Beri +4 DEF diri sampai 1 hit; CD 2.",
          "slot": 2
        }
      ],
      "fusion_tags": [],
      "catalog_status": "reference_data_pending_skill_playtest"
    },
    "card_code": "FOX_002",
    "tags": []
  },
  {
    "uid": null,
    "name": "Byte Fox — Quick Cache",
    "element": "Wind",
    "hp": 100,
    "attack": 33,
    "defense": 7,
    "image_url": null,
    "avatar_url": null,
    "level": 3,
    "rarity": "common",
    "card_kind": "normal",
    "fusion_only": false,
    "physical_scan_enabled": false,
    "virtual_key": null,
    "lore": "Menyimpan momentum sebelum menerjang lawan.",
    "metadata": {
      "timedoor_seed_key": "master_plan_v2_2:FOX-003",
      "source_card_code": "FOX-003",
      "seed_version": "2.2-learning-arcs-fusion",
      "source_document": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion.docx",
      "family_name": "Byte Fox",
      "variant_name": "Quick Cache",
      "display_name": "Byte Fox — Quick Cache",
      "learning_arc": "Discovery",
      "lesson_topic": "CODING",
      "learning_mission": "Buat kondisi if agar Fox memilih jalur aman saat gerbang tertutup.",
      "skills": [
        {
          "name": "Byte Swipe",
          "effect": "Serangan normal; +3 damage bila baru masuk Active.",
          "slot": 1
        },
        {
          "name": "Smoke Pixel",
          "effect": "Kurangi 7 damage dari hit berikutnya; CD 2.",
          "slot": 2
        }
      ],
      "fusion_tags": [],
      "catalog_status": "reference_data_pending_skill_playtest"
    },
    "card_code": "FOX_003",
    "tags": []
  },
  {
    "uid": null,
    "name": "Byte Fox — Circuit Jumper",
    "element": "Wind",
    "hp": 100,
    "attack": 34,
    "defense": 8,
    "image_url": null,
    "avatar_url": null,
    "level": 4,
    "rarity": "uncommon",
    "card_kind": "normal",
    "fusion_only": false,
    "physical_scan_enabled": false,
    "virtual_key": null,
    "lore": "Memadukan kelincahan dan timing agar sulit ditebak.",
    "metadata": {
      "timedoor_seed_key": "master_plan_v2_2:FOX-004",
      "source_card_code": "FOX-004",
      "seed_version": "2.2-learning-arcs-fusion",
      "source_document": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion.docx",
      "family_name": "Byte Fox",
      "variant_name": "Circuit Jumper",
      "display_name": "Byte Fox — Circuit Jumper",
      "learning_arc": "Strategy",
      "lesson_topic": "MATH",
      "learning_mission": "Hitung panjang tiga jalur di grid dan temukan rute terpendek.",
      "skills": [
        {
          "name": "Dash Strike",
          "effect": "Serangan normal +3 setelah Switch legal; CD 1.",
          "slot": 1
        },
        {
          "name": "Smoke Pixel",
          "effect": "Kurangi 7 damage dari hit berikutnya; CD 2.",
          "slot": 2
        }
      ],
      "fusion_tags": [],
      "catalog_status": "reference_data_pending_skill_playtest"
    },
    "card_code": "FOX_004",
    "tags": []
  },
  {
    "uid": null,
    "name": "Byte Fox — Wind Runner",
    "element": "Wind",
    "hp": 108,
    "attack": 36,
    "defense": 9,
    "image_url": null,
    "avatar_url": null,
    "level": 5,
    "rarity": "uncommon",
    "card_kind": "normal",
    "fusion_only": false,
    "physical_scan_enabled": false,
    "virtual_key": null,
    "lore": "Pelari angin yang menguasai pergantian posisi.",
    "metadata": {
      "timedoor_seed_key": "master_plan_v2_2:FOX-005",
      "source_card_code": "FOX-005",
      "seed_version": "2.2-learning-arcs-fusion",
      "source_document": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion.docx",
      "family_name": "Byte Fox",
      "variant_name": "Wind Runner",
      "display_name": "Byte Fox — Wind Runner",
      "learning_arc": "Strategy",
      "lesson_topic": "MATH",
      "learning_mission": "Bandingkan strategi tercepat dengan jumlah langkah paling sedikit.",
      "skills": [
        {
          "name": "Byte Swipe",
          "effect": "Serangan normal; +3 damage bila baru masuk Active.",
          "slot": 1
        },
        {
          "name": "Byte Dash",
          "effect": "Serangan normal +5 setelah Switch legal; CD 1.",
          "slot": 2
        }
      ],
      "fusion_tags": [],
      "catalog_status": "reference_data_pending_skill_playtest"
    },
    "card_code": "FOX_005",
    "tags": []
  },
  {
    "uid": null,
    "name": "Byte Fox — Byte Raider",
    "element": "Wind",
    "hp": 110,
    "attack": 38,
    "defense": 10,
    "image_url": null,
    "avatar_url": null,
    "level": 6,
    "rarity": "rare",
    "card_kind": "normal",
    "fusion_only": false,
    "physical_scan_enabled": false,
    "virtual_key": null,
    "lore": "Menyerang ketika tim berhasil melakukan Switch.",
    "metadata": {
      "timedoor_seed_key": "master_plan_v2_2:FOX-006",
      "source_card_code": "FOX-006",
      "seed_version": "2.2-learning-arcs-fusion",
      "source_document": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion.docx",
      "family_name": "Byte Fox",
      "variant_name": "Byte Raider",
      "display_name": "Byte Fox — Byte Raider",
      "learning_arc": "Communication",
      "lesson_topic": "ENGLISH",
      "learning_mission": "Buat instruksi English singkat untuk membantu pemain melewati obstacle.",
      "skills": [
        {
          "name": "Byte Dash",
          "effect": "Serangan normal +5 setelah Switch legal; CD 1.",
          "slot": 1
        },
        {
          "name": "Quick Loop",
          "effect": "Serang hingga 2 target, masing-masing 0,8× ATK; CD 3.",
          "slot": 2
        }
      ],
      "fusion_tags": [
        "fusion:agile_code"
      ],
      "catalog_status": "reference_data_pending_skill_playtest"
    },
    "card_code": "FOX_006",
    "tags": [
      "fusion:agile_code"
    ]
  },
  {
    "uid": null,
    "name": "Byte Fox — Turbo Fox",
    "element": "Wind",
    "hp": 122,
    "attack": 40,
    "defense": 11,
    "image_url": null,
    "avatar_url": null,
    "level": 7,
    "rarity": "rare",
    "card_kind": "normal",
    "fusion_only": false,
    "physical_scan_enabled": false,
    "virtual_key": null,
    "lore": "Lincah tetapi wajib memilih waktu menyerang.",
    "metadata": {
      "timedoor_seed_key": "master_plan_v2_2:FOX-007",
      "source_card_code": "FOX-007",
      "seed_version": "2.2-learning-arcs-fusion",
      "source_document": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion.docx",
      "family_name": "Byte Fox",
      "variant_name": "Turbo Fox",
      "display_name": "Byte Fox — Turbo Fox",
      "learning_arc": "Communication",
      "lesson_topic": "ENGLISH",
      "learning_mission": "Jelaskan bug dan perbaikan algoritma Fox dalam dua kalimat English.",
      "skills": [
        {
          "name": "Dash Strike",
          "effect": "Serangan normal +3 setelah Switch legal; CD 1.",
          "slot": 1
        },
        {
          "name": "Quick Loop",
          "effect": "Serang hingga 2 target, masing-masing 0,8× ATK; CD 3.",
          "slot": 2
        }
      ],
      "fusion_tags": [
        "fusion:agile_code",
        "fusion:fast_algorithm"
      ],
      "catalog_status": "reference_data_pending_skill_playtest"
    },
    "card_code": "FOX_007",
    "tags": [
      "fusion:agile_code",
      "fusion:fast_algorithm"
    ]
  },
  {
    "uid": null,
    "name": "Byte Fox — Quantum Pouncer",
    "element": "Wind",
    "hp": 131,
    "attack": 44,
    "defense": 12,
    "image_url": null,
    "avatar_url": null,
    "level": 8,
    "rarity": "epic",
    "card_kind": "normal",
    "fusion_only": false,
    "physical_scan_enabled": false,
    "virtual_key": null,
    "lore": "Mengerahkan rangkaian dash untuk memburu target.",
    "metadata": {
      "timedoor_seed_key": "master_plan_v2_2:FOX-008",
      "source_card_code": "FOX-008",
      "seed_version": "2.2-learning-arcs-fusion",
      "source_document": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion.docx",
      "family_name": "Byte Fox",
      "variant_name": "Quantum Pouncer",
      "display_name": "Byte Fox — Quantum Pouncer",
      "learning_arc": "Creation",
      "lesson_topic": "SKILL LAB",
      "learning_mission": "Bangun obstacle course digital dengan satu jalur optimal dan satu jebakan.",
      "skills": [
        {
          "name": "Turbo Followup",
          "effect": "Serangan normal +8 pada target yang terkena ally terakhir; CD 2.",
          "slot": 1
        },
        {
          "name": "Smoke Pixel",
          "effect": "Kurangi 7 damage dari hit berikutnya; CD 2.",
          "slot": 2
        }
      ],
      "fusion_tags": [
        "fusion:advanced_wind",
        "fusion:fast_algorithm"
      ],
      "catalog_status": "reference_data_pending_skill_playtest"
    },
    "card_code": "FOX_008",
    "tags": [
      "fusion:advanced_wind",
      "fusion:fast_algorithm"
    ]
  },
  {
    "uid": null,
    "name": "Byte Fox — Prism Afterimage",
    "element": "Wind",
    "hp": 146,
    "attack": 48,
    "defense": 15,
    "image_url": null,
    "avatar_url": null,
    "level": 9,
    "rarity": "legendary",
    "card_kind": "normal",
    "fusion_only": false,
    "physical_scan_enabled": false,
    "virtual_key": null,
    "lore": "Bayangan cepat yang mengecoh satu serangan balik.",
    "metadata": {
      "timedoor_seed_key": "master_plan_v2_2:FOX-009",
      "source_card_code": "FOX-009",
      "seed_version": "2.2-learning-arcs-fusion",
      "source_document": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion.docx",
      "family_name": "Byte Fox",
      "variant_name": "Prism Afterimage",
      "display_name": "Byte Fox — Prism Afterimage",
      "learning_arc": "Creation",
      "lesson_topic": "SKILL LAB",
      "learning_mission": "Ukur keberhasilan tiga pemain; olah rata-rata waktu penyelesaian.",
      "skills": [
        {
          "name": "Prism Echo",
          "effect": "Sekali/battle, kurangi 12 damage pada hit berikutnya.",
          "slot": 1
        },
        {
          "name": "Quick Loop",
          "effect": "Serang hingga 2 target, masing-masing 0,8× ATK; CD 3.",
          "slot": 2
        }
      ],
      "fusion_tags": [],
      "catalog_status": "reference_data_pending_skill_playtest"
    },
    "card_code": "FOX_009",
    "tags": []
  },
  {
    "uid": null,
    "name": "Byte Fox — Infinity Byte",
    "element": "Wind",
    "hp": 158,
    "attack": 52,
    "defense": 17,
    "image_url": null,
    "avatar_url": null,
    "level": 10,
    "rarity": "mythic",
    "card_kind": "normal",
    "fusion_only": false,
    "physical_scan_enabled": false,
    "virtual_key": null,
    "lore": "Puncak kecepatan dengan kombo terbatas dan terukur.",
    "metadata": {
      "timedoor_seed_key": "master_plan_v2_2:FOX-010",
      "source_card_code": "FOX-010",
      "seed_version": "2.2-learning-arcs-fusion",
      "source_document": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion.docx",
      "family_name": "Byte Fox",
      "variant_name": "Infinity Byte",
      "display_name": "Byte Fox — Infinity Byte",
      "learning_arc": "Creation",
      "lesson_topic": "SKILL LAB",
      "learning_mission": "Demokan level buatan sendiri, logika pathfinding, statistik, dan panduan English.",
      "skills": [
        {
          "name": "Infinity Loop",
          "effect": "Sekali/battle, serang 2 target 0,75× ATK; tidak memberi extra action.",
          "slot": 1
        },
        {
          "name": "Turbo Followup",
          "effect": "Serangan normal +8 pada target yang terkena ally terakhir; CD 2.",
          "slot": 2
        }
      ],
      "fusion_tags": [],
      "catalog_status": "reference_data_pending_skill_playtest"
    },
    "card_code": "FOX_010",
    "tags": []
  },
  {
    "uid": null,
    "name": "Pixel Rabbit — Pixel Seedling",
    "element": "Grass",
    "hp": 104,
    "attack": 25,
    "defense": 9,
    "image_url": null,
    "avatar_url": null,
    "level": 1,
    "rarity": "common",
    "card_kind": "normal",
    "fusion_only": false,
    "physical_scan_enabled": false,
    "virtual_key": null,
    "lore": "Kelinci perakit muda yang membuat dinding pertama.",
    "metadata": {
      "timedoor_seed_key": "master_plan_v2_2:RAB-001",
      "source_card_code": "RAB-001",
      "seed_version": "2.2-learning-arcs-fusion",
      "source_document": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion.docx",
      "family_name": "Pixel Rabbit",
      "variant_name": "Pixel Seedling",
      "display_name": "Pixel Rabbit — Pixel Seedling",
      "learning_arc": "Discovery",
      "lesson_topic": "CODING",
      "learning_mission": "Susun blok perintah untuk membangun dinding pelindung secara berurutan.",
      "skills": [
        {
          "name": "Block Bonk",
          "effect": "Serangan normal; +3 damage jika diri punya Shield.",
          "slot": 1
        },
        {
          "name": "Mini Wall",
          "effect": "Beri Shield 7 satu rekan; CD 2.",
          "slot": 2
        }
      ],
      "fusion_tags": [],
      "catalog_status": "reference_data_pending_skill_playtest"
    },
    "card_code": "RAB_001",
    "tags": []
  },
  {
    "uid": null,
    "name": "Pixel Rabbit — Block Jumper",
    "element": "Grass",
    "hp": 110,
    "attack": 26,
    "defense": 9,
    "image_url": null,
    "avatar_url": null,
    "level": 2,
    "rarity": "common",
    "card_kind": "normal",
    "fusion_only": false,
    "physical_scan_enabled": false,
    "virtual_key": null,
    "lore": "Melompat sambil membawa blok perlindungan sederhana.",
    "metadata": {
      "timedoor_seed_key": "master_plan_v2_2:RAB-002",
      "source_card_code": "RAB-002",
      "seed_version": "2.2-learning-arcs-fusion",
      "source_document": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion.docx",
      "family_name": "Pixel Rabbit",
      "variant_name": "Block Jumper",
      "display_name": "Pixel Rabbit — Block Jumper",
      "learning_arc": "Discovery",
      "lesson_topic": "CODING",
      "learning_mission": "Buat fungsi build_wall yang dipakai ulang pada dua lokasi arena.",
      "skills": [
        {
          "name": "Leaf Block",
          "effect": "Serangan normal; +3 damage jika target sedang Root.",
          "slot": 1
        },
        {
          "name": "Mini Wall",
          "effect": "Beri Shield 7 satu rekan; CD 2.",
          "slot": 2
        }
      ],
      "fusion_tags": [],
      "catalog_status": "reference_data_pending_skill_playtest"
    },
    "card_code": "RAB_002",
    "tags": []
  },
  {
    "uid": null,
    "name": "Pixel Rabbit — Patch Bunny",
    "element": "Grass",
    "hp": 110,
    "attack": 28,
    "defense": 10,
    "image_url": null,
    "avatar_url": null,
    "level": 3,
    "rarity": "common",
    "card_kind": "normal",
    "fusion_only": false,
    "physical_scan_enabled": false,
    "virtual_key": null,
    "lore": "Menguji perbaikan kecil untuk melindungi rekan.",
    "metadata": {
      "timedoor_seed_key": "master_plan_v2_2:RAB-003",
      "source_card_code": "RAB-003",
      "seed_version": "2.2-learning-arcs-fusion",
      "source_document": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion.docx",
      "family_name": "Pixel Rabbit",
      "variant_name": "Patch Bunny",
      "display_name": "Pixel Rabbit — Patch Bunny",
      "learning_arc": "Discovery",
      "lesson_topic": "CODING",
      "learning_mission": "Gunakan if untuk mengaktifkan perbaikan hanya ketika shield berkurang.",
      "skills": [
        {
          "name": "Block Bonk",
          "effect": "Serangan normal; +3 damage jika diri punya Shield.",
          "slot": 1
        },
        {
          "name": "Patch Kit",
          "effect": "Pulihkan 7 HP satu rekan; CD 2.",
          "slot": 2
        }
      ],
      "fusion_tags": [],
      "catalog_status": "reference_data_pending_skill_playtest"
    },
    "card_code": "RAB_003",
    "tags": []
  },
  {
    "uid": null,
    "name": "Pixel Rabbit — Garden Builder",
    "element": "Grass",
    "hp": 116,
    "attack": 28,
    "defense": 10,
    "image_url": null,
    "avatar_url": null,
    "level": 4,
    "rarity": "uncommon",
    "card_kind": "normal",
    "fusion_only": false,
    "physical_scan_enabled": false,
    "virtual_key": null,
    "lore": "Menyusun blok dan tanaman menjadi zona aman.",
    "metadata": {
      "timedoor_seed_key": "master_plan_v2_2:RAB-004",
      "source_card_code": "RAB-004",
      "seed_version": "2.2-learning-arcs-fusion",
      "source_document": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion.docx",
      "family_name": "Pixel Rabbit",
      "variant_name": "Garden Builder",
      "display_name": "Pixel Rabbit — Garden Builder",
      "learning_arc": "Strategy",
      "lesson_topic": "MATH",
      "learning_mission": "Hitung keliling benteng piksel berbentuk persegi dan persegi panjang.",
      "skills": [
        {
          "name": "Leaf Block",
          "effect": "Serangan normal; +3 damage jika target sedang Root.",
          "slot": 1
        },
        {
          "name": "Patch Kit",
          "effect": "Pulihkan 7 HP satu rekan; CD 2.",
          "slot": 2
        }
      ],
      "fusion_tags": [],
      "catalog_status": "reference_data_pending_skill_playtest"
    },
    "card_code": "RAB_004",
    "tags": []
  },
  {
    "uid": null,
    "name": "Pixel Rabbit — Green Architect",
    "element": "Grass",
    "hp": 120,
    "attack": 31,
    "defense": 12,
    "image_url": null,
    "avatar_url": null,
    "level": 5,
    "rarity": "uncommon",
    "card_kind": "normal",
    "fusion_only": false,
    "physical_scan_enabled": false,
    "virtual_key": null,
    "lore": "Membuat benteng sementara yang tidak bisa ditumpuk.",
    "metadata": {
      "timedoor_seed_key": "master_plan_v2_2:RAB-005",
      "source_card_code": "RAB-005",
      "seed_version": "2.2-learning-arcs-fusion",
      "source_document": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion.docx",
      "family_name": "Pixel Rabbit",
      "variant_name": "Green Architect",
      "display_name": "Pixel Rabbit — Green Architect",
      "learning_arc": "Strategy",
      "lesson_topic": "MATH",
      "learning_mission": "Rancang bentuk pelindung dengan luas tetap tetapi keliling berbeda.",
      "skills": [
        {
          "name": "Block Bonk",
          "effect": "Serangan normal; +3 damage jika diri punya Shield.",
          "slot": 1
        },
        {
          "name": "Block Wall",
          "effect": "Beri Shield 12 satu rekan; CD 2, tidak menumpuk.",
          "slot": 2
        }
      ],
      "fusion_tags": [],
      "catalog_status": "reference_data_pending_skill_playtest"
    },
    "card_code": "RAB_005",
    "tags": []
  },
  {
    "uid": null,
    "name": "Pixel Rabbit — Pixel Medic",
    "element": "Grass",
    "hp": 126,
    "attack": 32,
    "defense": 12,
    "image_url": null,
    "avatar_url": null,
    "level": 6,
    "rarity": "rare",
    "card_kind": "normal",
    "fusion_only": false,
    "physical_scan_enabled": false,
    "virtual_key": null,
    "lore": "Teknisi lapangan yang menggabungkan perisai dan patch.",
    "metadata": {
      "timedoor_seed_key": "master_plan_v2_2:RAB-006",
      "source_card_code": "RAB-006",
      "seed_version": "2.2-learning-arcs-fusion",
      "source_document": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion.docx",
      "family_name": "Pixel Rabbit",
      "variant_name": "Pixel Medic",
      "display_name": "Pixel Rabbit — Pixel Medic",
      "learning_arc": "Communication",
      "lesson_topic": "ENGLISH",
      "learning_mission": "Berikan deskripsi English singkat mengenai fungsi tiga bagian benteng.",
      "skills": [
        {
          "name": "Block Wall",
          "effect": "Beri Shield 12 satu rekan; CD 2, tidak menumpuk.",
          "slot": 1
        },
        {
          "name": "Pixel Patch",
          "effect": "Heal 16 satu rekan ATAU hapus satu debuff biasa; CD 2.",
          "slot": 2
        }
      ],
      "fusion_tags": [
        "fusion:build_shield"
      ],
      "catalog_status": "reference_data_pending_skill_playtest"
    },
    "card_code": "RAB_006",
    "tags": [
      "fusion:build_shield"
    ]
  },
  {
    "uid": null,
    "name": "Pixel Rabbit — Canopy Constructor",
    "element": "Grass",
    "hp": 135,
    "attack": 35,
    "defense": 14,
    "image_url": null,
    "avatar_url": null,
    "level": 7,
    "rarity": "rare",
    "card_kind": "normal",
    "fusion_only": false,
    "physical_scan_enabled": false,
    "virtual_key": null,
    "lore": "Membangun struktur daun untuk menahan satu serangan.",
    "metadata": {
      "timedoor_seed_key": "master_plan_v2_2:RAB-007",
      "source_card_code": "RAB-007",
      "seed_version": "2.2-learning-arcs-fusion",
      "source_document": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion.docx",
      "family_name": "Pixel Rabbit",
      "variant_name": "Canopy Constructor",
      "display_name": "Pixel Rabbit — Canopy Constructor",
      "learning_arc": "Communication",
      "lesson_topic": "ENGLISH",
      "learning_mission": "Latih presentasi 30 detik dalam English untuk menjelaskan desain tim.",
      "skills": [
        {
          "name": "Leaf Block",
          "effect": "Serangan normal; +3 damage jika target sedang Root.",
          "slot": 1
        },
        {
          "name": "Pixel Patch",
          "effect": "Heal 16 satu rekan ATAU hapus satu debuff biasa; CD 2.",
          "slot": 2
        }
      ],
      "fusion_tags": [
        "fusion:build_shield"
      ],
      "catalog_status": "reference_data_pending_skill_playtest"
    },
    "card_code": "RAB_007",
    "tags": [
      "fusion:build_shield"
    ]
  },
  {
    "uid": null,
    "name": "Pixel Rabbit — Emerald Fortress",
    "element": "Grass",
    "hp": 147,
    "attack": 38,
    "defense": 15,
    "image_url": null,
    "avatar_url": null,
    "level": 8,
    "rarity": "epic",
    "card_kind": "normal",
    "fusion_only": false,
    "physical_scan_enabled": false,
    "virtual_key": null,
    "lore": "Spesialis pertahanan yang mengorbankan tekanan serangan.",
    "metadata": {
      "timedoor_seed_key": "master_plan_v2_2:RAB-008",
      "source_card_code": "RAB-008",
      "seed_version": "2.2-learning-arcs-fusion",
      "source_document": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion.docx",
      "family_name": "Pixel Rabbit",
      "variant_name": "Emerald Fortress",
      "display_name": "Pixel Rabbit — Emerald Fortress",
      "learning_arc": "Creation",
      "lesson_topic": "SKILL LAB",
      "learning_mission": "Buat prototipe benteng blok digital yang dapat dibangun lewat tombol.",
      "skills": [
        {
          "name": "Fortress Frame",
          "effect": "Beri Shield 16 satu rekan; CD 3.",
          "slot": 1
        },
        {
          "name": "Patch Kit",
          "effect": "Pulihkan 7 HP satu rekan; CD 2.",
          "slot": 2
        }
      ],
      "fusion_tags": [],
      "catalog_status": "reference_data_pending_skill_playtest"
    },
    "card_code": "RAB_008",
    "tags": []
  },
  {
    "uid": null,
    "name": "Pixel Rabbit — Royal Patchmaker",
    "element": "Grass",
    "hp": 162,
    "attack": 42,
    "defense": 18,
    "image_url": null,
    "avatar_url": null,
    "level": 9,
    "rarity": "legendary",
    "card_kind": "normal",
    "fusion_only": false,
    "physical_scan_enabled": false,
    "virtual_key": null,
    "lore": "Arsitek elit yang menghapus satu gangguan berbahaya.",
    "metadata": {
      "timedoor_seed_key": "master_plan_v2_2:RAB-009",
      "source_card_code": "RAB-009",
      "seed_version": "2.2-learning-arcs-fusion",
      "source_document": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion.docx",
      "family_name": "Pixel Rabbit",
      "variant_name": "Royal Patchmaker",
      "display_name": "Pixel Rabbit — Royal Patchmaker",
      "learning_arc": "Creation",
      "lesson_topic": "SKILL LAB",
      "learning_mission": "Uji tiga desain shield dan catat kebutuhan material masing-masing.",
      "skills": [
        {
          "name": "Royal Repair",
          "effect": "Sekali/battle, hapus satu debuff biasa dan heal 8 satu rekan.",
          "slot": 1
        },
        {
          "name": "Pixel Patch",
          "effect": "Heal 16 satu rekan ATAU hapus satu debuff biasa; CD 2.",
          "slot": 2
        }
      ],
      "fusion_tags": [],
      "catalog_status": "reference_data_pending_skill_playtest"
    },
    "card_code": "RAB_009",
    "tags": []
  },
  {
    "uid": null,
    "name": "Pixel Rabbit — World Builder",
    "element": "Grass",
    "hp": 174,
    "attack": 46,
    "defense": 20,
    "image_url": null,
    "avatar_url": null,
    "level": 10,
    "rarity": "mythic",
    "card_kind": "normal",
    "fusion_only": false,
    "physical_scan_enabled": false,
    "virtual_key": null,
    "lore": "Wujud puncak perakit dengan satu pertahanan penentu.",
    "metadata": {
      "timedoor_seed_key": "master_plan_v2_2:RAB-010",
      "source_card_code": "RAB-010",
      "seed_version": "2.2-learning-arcs-fusion",
      "source_document": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion.docx",
      "family_name": "Pixel Rabbit",
      "variant_name": "World Builder",
      "display_name": "Pixel Rabbit — World Builder",
      "learning_arc": "Creation",
      "lesson_topic": "SKILL LAB",
      "learning_mission": "Pamerkan benteng terpilih dengan kode, perhitungan geometri, dan pitch English.",
      "skills": [
        {
          "name": "World Block",
          "effect": "Sekali/battle, beri Shield 20 ke satu rekan; tidak menumpuk.",
          "slot": 1
        },
        {
          "name": "Fortress Frame",
          "effect": "Beri Shield 16 satu rekan; CD 3.",
          "slot": 2
        }
      ],
      "fusion_tags": [],
      "catalog_status": "reference_data_pending_skill_playtest"
    },
    "card_code": "RAB_010",
    "tags": []
  },
  {
    "uid": null,
    "name": "Null Cat — Little Glitch",
    "element": "Dark",
    "hp": 94,
    "attack": 29,
    "defense": 7,
    "image_url": null,
    "avatar_url": null,
    "level": 1,
    "rarity": "common",
    "card_kind": "normal",
    "fusion_only": false,
    "physical_scan_enabled": false,
    "virtual_key": null,
    "lore": "Kucing misterius yang mempelajari celah dunia digital.",
    "metadata": {
      "timedoor_seed_key": "master_plan_v2_2:NUL-001",
      "source_card_code": "NUL-001",
      "seed_version": "2.2-learning-arcs-fusion",
      "source_document": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion.docx",
      "family_name": "Null Cat",
      "variant_name": "Little Glitch",
      "display_name": "Null Cat — Little Glitch",
      "learning_arc": "Discovery",
      "lesson_topic": "CODING",
      "learning_mission": "Temukan dan perbaiki satu kesalahan urutan pada algoritma portal digital.",
      "skills": [
        {
          "name": "Shade Tap",
          "effect": "Serangan normal; +3 damage ke target tanpa Shield.",
          "slot": 1
        },
        {
          "name": "Night Veil",
          "effect": "Kurangi 6 damage dari hit berikutnya pada diri; CD 2.",
          "slot": 2
        }
      ],
      "fusion_tags": [],
      "catalog_status": "reference_data_pending_skill_playtest"
    },
    "card_code": "NUL_001",
    "tags": []
  },
  {
    "uid": null,
    "name": "Null Cat — Shadow Paw",
    "element": "Dark",
    "hp": 100,
    "attack": 31,
    "defense": 7,
    "image_url": null,
    "avatar_url": null,
    "level": 2,
    "rarity": "common",
    "card_kind": "normal",
    "fusion_only": false,
    "physical_scan_enabled": false,
    "virtual_key": null,
    "lore": "Mencoba serangan bayangan tanpa menguasai necromancy.",
    "metadata": {
      "timedoor_seed_key": "master_plan_v2_2:NUL-002",
      "source_card_code": "NUL-002",
      "seed_version": "2.2-learning-arcs-fusion",
      "source_document": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion.docx",
      "family_name": "Null Cat",
      "variant_name": "Shadow Paw",
      "display_name": "Null Cat — Shadow Paw",
      "learning_arc": "Discovery",
      "lesson_topic": "CODING",
      "learning_mission": "Identifikasi perbedaan bug sintaks dan bug logika pada dua contoh sederhana.",
      "skills": [
        {
          "name": "Glitch Scratch",
          "effect": "Serangan normal; target mendapat -3 DEF untuk 1 hit; CD 2.",
          "slot": 1
        },
        {
          "name": "Night Veil",
          "effect": "Kurangi 6 damage dari hit berikutnya pada diri; CD 2.",
          "slot": 2
        }
      ],
      "fusion_tags": [],
      "catalog_status": "reference_data_pending_skill_playtest"
    },
    "card_code": "NUL_002",
    "tags": []
  },
  {
    "uid": null,
    "name": "Null Cat — Night Packet",
    "element": "Dark",
    "hp": 106,
    "attack": 33,
    "defense": 8,
    "image_url": null,
    "avatar_url": null,
    "level": 3,
    "rarity": "common",
    "card_kind": "normal",
    "fusion_only": false,
    "physical_scan_enabled": false,
    "virtual_key": null,
    "lore": "Menyusup ke sirkuit untuk melemahkan pertahanan lawan.",
    "metadata": {
      "timedoor_seed_key": "master_plan_v2_2:NUL-003",
      "source_card_code": "NUL-003",
      "seed_version": "2.2-learning-arcs-fusion",
      "source_document": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion.docx",
      "family_name": "Null Cat",
      "variant_name": "Night Packet",
      "display_name": "Null Cat — Night Packet",
      "learning_arc": "Discovery",
      "lesson_topic": "CODING",
      "learning_mission": "Buat variabel health_backup yang aman dan uji proses restore saat simulasi gagal.",
      "skills": [
        {
          "name": "Shade Tap",
          "effect": "Serangan normal; +3 damage ke target tanpa Shield.",
          "slot": 1
        },
        {
          "name": "Dark Mask",
          "effect": "Beri +4 DEF diri hingga 1 hit; CD 2.",
          "slot": 2
        }
      ],
      "fusion_tags": [],
      "catalog_status": "reference_data_pending_skill_playtest"
    },
    "card_code": "NUL_003",
    "tags": []
  },
  {
    "uid": null,
    "name": "Null Cat — Void Tracker",
    "element": "Dark",
    "hp": 106,
    "attack": 32,
    "defense": 8,
    "image_url": null,
    "avatar_url": null,
    "level": 4,
    "rarity": "uncommon",
    "card_kind": "normal",
    "fusion_only": false,
    "physical_scan_enabled": false,
    "virtual_key": null,
    "lore": "Menandai kelemahan target sebelum menyerang.",
    "metadata": {
      "timedoor_seed_key": "master_plan_v2_2:NUL-004",
      "source_card_code": "NUL-004",
      "seed_version": "2.2-learning-arcs-fusion",
      "source_document": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion.docx",
      "family_name": "Null Cat",
      "variant_name": "Void Tracker",
      "display_name": "Null Cat — Void Tracker",
      "learning_arc": "Strategy",
      "lesson_topic": "MATH",
      "learning_mission": "Selesaikan tabel kebenaran AND/OR untuk dua kunci gerbang.",
      "skills": [
        {
          "name": "Glitch Scratch",
          "effect": "Serangan normal; target mendapat -3 DEF untuk 1 hit; CD 2.",
          "slot": 1
        },
        {
          "name": "Dark Mask",
          "effect": "Beri +4 DEF diri hingga 1 hit; CD 2.",
          "slot": 2
        }
      ],
      "fusion_tags": [],
      "catalog_status": "reference_data_pending_skill_playtest"
    },
    "card_code": "NUL_004",
    "tags": []
  },
  {
    "uid": null,
    "name": "Null Cat — Dark Debugger",
    "element": "Dark",
    "hp": 114,
    "attack": 36,
    "defense": 10,
    "image_url": null,
    "avatar_url": null,
    "level": 5,
    "rarity": "uncommon",
    "card_kind": "normal",
    "fusion_only": false,
    "physical_scan_enabled": false,
    "virtual_key": null,
    "lore": "Menghilangkan perlindungan kecil lewat trik gelap.",
    "metadata": {
      "timedoor_seed_key": "master_plan_v2_2:NUL-005",
      "source_card_code": "NUL-005",
      "seed_version": "2.2-learning-arcs-fusion",
      "source_document": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion.docx",
      "family_name": "Null Cat",
      "variant_name": "Dark Debugger",
      "display_name": "Null Cat — Dark Debugger",
      "learning_arc": "Strategy",
      "lesson_topic": "MATH",
      "learning_mission": "Pilih langkah pemulihan terbaik dari diagram keputusan dengan tiga cabang.",
      "skills": [
        {
          "name": "Shade Tap",
          "effect": "Serangan normal; +3 damage ke target tanpa Shield.",
          "slot": 1
        },
        {
          "name": "Void Claw",
          "effect": "Damage normal dan -4 DEF target untuk 1 hit; CD 2.",
          "slot": 2
        }
      ],
      "fusion_tags": [],
      "catalog_status": "reference_data_pending_skill_playtest"
    },
    "card_code": "NUL_005",
    "tags": []
  },
  {
    "uid": null,
    "name": "Null Cat — Void Claw",
    "element": "Dark",
    "hp": 116,
    "attack": 36,
    "defense": 10,
    "image_url": null,
    "avatar_url": null,
    "level": 6,
    "rarity": "rare",
    "card_kind": "normal",
    "fusion_only": false,
    "physical_scan_enabled": false,
    "virtual_key": null,
    "lore": "Menyerang satu musuh sambil menurunkan DEF sesaat.",
    "metadata": {
      "timedoor_seed_key": "master_plan_v2_2:NUL-006",
      "source_card_code": "NUL-006",
      "seed_version": "2.2-learning-arcs-fusion",
      "source_document": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion.docx",
      "family_name": "Null Cat",
      "variant_name": "Void Claw",
      "display_name": "Null Cat — Void Claw",
      "learning_arc": "Communication",
      "lesson_topic": "ENGLISH",
      "learning_mission": "Jelaskan dalam English arti bug, backup, restore dan safe access.",
      "skills": [
        {
          "name": "Void Claw",
          "effect": "Damage normal dan -4 DEF target untuk 1 hit; CD 2.",
          "slot": 1
        },
        {
          "name": "Night Disable",
          "effect": "30% peluang Silence special target berikutnya; CD 3.",
          "slot": 2
        }
      ],
      "fusion_tags": [
        "fusion:dark_control"
      ],
      "catalog_status": "reference_data_pending_skill_playtest"
    },
    "card_code": "NUL_006",
    "tags": [
      "fusion:dark_control"
    ]
  },
  {
    "uid": null,
    "name": "Null Cat — Night Disabler",
    "element": "Dark",
    "hp": 128,
    "attack": 40,
    "defense": 12,
    "image_url": null,
    "avatar_url": null,
    "level": 7,
    "rarity": "rare",
    "card_kind": "normal",
    "fusion_only": false,
    "physical_scan_enabled": false,
    "virtual_key": null,
    "lore": "Menahan special lawan dengan peluang terbatas.",
    "metadata": {
      "timedoor_seed_key": "master_plan_v2_2:NUL-007",
      "source_card_code": "NUL-007",
      "seed_version": "2.2-learning-arcs-fusion",
      "source_document": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion.docx",
      "family_name": "Null Cat",
      "variant_name": "Night Disabler",
      "display_name": "Null Cat — Night Disabler",
      "learning_arc": "Communication",
      "lesson_topic": "ENGLISH",
      "learning_mission": "Buat pesan peringatan English yang jelas saat data tidak dapat dipulihkan.",
      "skills": [
        {
          "name": "Glitch Scratch",
          "effect": "Serangan normal; target mendapat -3 DEF untuk 1 hit; CD 2.",
          "slot": 1
        },
        {
          "name": "Night Disable",
          "effect": "30% peluang Silence special target berikutnya; CD 3.",
          "slot": 2
        }
      ],
      "fusion_tags": [
        "fusion:dark_control"
      ],
      "catalog_status": "reference_data_pending_skill_playtest"
    },
    "card_code": "NUL_007",
    "tags": [
      "fusion:dark_control"
    ]
  },
  {
    "uid": null,
    "name": "Null Cat — Soul Apprentice",
    "element": "Dark",
    "hp": 137,
    "attack": 43,
    "defense": 13,
    "image_url": null,
    "avatar_url": null,
    "level": 8,
    "rarity": "epic",
    "card_kind": "normal",
    "fusion_only": false,
    "physical_scan_enabled": false,
    "virtual_key": null,
    "lore": "Mulai menguasai revival dengan pengorbanan diri.",
    "metadata": {
      "timedoor_seed_key": "master_plan_v2_2:NUL-008",
      "source_card_code": "NUL-008",
      "seed_version": "2.2-learning-arcs-fusion",
      "source_document": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion.docx",
      "family_name": "Null Cat",
      "variant_name": "Soul Apprentice",
      "display_name": "Null Cat — Soul Apprentice",
      "learning_arc": "Creation",
      "lesson_topic": "SKILL LAB",
      "learning_mission": "Rancang simulasi restore berbasis snapshot yang tidak mengubah data asli.",
      "skills": [
        {
          "name": "Soul Rebirth",
          "effect": "Sekali/battle, sacrifice diri untuk revive satu ally legal di 50% HP.",
          "slot": 1
        },
        {
          "name": "Dark Mask",
          "effect": "Beri +4 DEF diri hingga 1 hit; CD 2.",
          "slot": 2
        }
      ],
      "fusion_tags": [],
      "catalog_status": "reference_data_pending_skill_playtest"
    },
    "card_code": "NUL_008",
    "tags": []
  },
  {
    "uid": null,
    "name": "Null Cat — Soul Reaper",
    "element": "Dark",
    "hp": 152,
    "attack": 47,
    "defense": 16,
    "image_url": null,
    "avatar_url": null,
    "level": 9,
    "rarity": "legendary",
    "card_kind": "normal",
    "fusion_only": false,
    "physical_scan_enabled": false,
    "virtual_key": null,
    "lore": "Necromancer elit yang membayar nyawa untuk penyelamatan.",
    "metadata": {
      "timedoor_seed_key": "master_plan_v2_2:NUL-009",
      "source_card_code": "NUL-009",
      "seed_version": "2.2-learning-arcs-fusion",
      "source_document": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion.docx",
      "family_name": "Null Cat",
      "variant_name": "Soul Reaper",
      "display_name": "Null Cat — Soul Reaper",
      "learning_arc": "Creation",
      "lesson_topic": "SKILL LAB",
      "learning_mission": "Uji tiga skenario recovery dan dokumentasikan kondisi yang ditolak sistem.",
      "skills": [
        {
          "name": "Reaper Bargain",
          "effect": "Sekali/battle, sacrifice diri untuk revive satu ally legal di 50% HP.",
          "slot": 1
        },
        {
          "name": "Night Disable",
          "effect": "30% peluang Silence special target berikutnya; CD 3.",
          "slot": 2
        }
      ],
      "fusion_tags": [],
      "catalog_status": "reference_data_pending_skill_playtest"
    },
    "card_code": "NUL_009",
    "tags": []
  },
  {
    "uid": null,
    "name": "Null Cat — Eternal Null",
    "element": "Dark",
    "hp": 164,
    "attack": 51,
    "defense": 18,
    "image_url": null,
    "avatar_url": null,
    "level": 10,
    "rarity": "mythic",
    "card_kind": "normal",
    "fusion_only": false,
    "physical_scan_enabled": false,
    "virtual_key": null,
    "lore": "Wujud mythic dengan satu revival dan kontrol bersyarat.",
    "metadata": {
      "timedoor_seed_key": "master_plan_v2_2:NUL-010",
      "source_card_code": "NUL-010",
      "seed_version": "2.2-learning-arcs-fusion",
      "source_document": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion.docx",
      "family_name": "Null Cat",
      "variant_name": "Eternal Null",
      "display_name": "Null Cat — Eternal Null",
      "learning_arc": "Creation",
      "lesson_topic": "SKILL LAB",
      "learning_mission": "Demokan praktik backup-restore yang etis, logika validasi, dan presentasi English.",
      "skills": [
        {
          "name": "Eternal Pact",
          "effect": "Sekali/battle, sacrifice diri untuk revive satu ally legal di 50% HP; tidak reset on-summon.",
          "slot": 1
        },
        {
          "name": "Night Disable",
          "effect": "30% peluang Silence special target berikutnya; CD 3.",
          "slot": 2
        }
      ],
      "fusion_tags": [],
      "catalog_status": "reference_data_pending_skill_playtest"
    },
    "card_code": "NUL_010",
    "tags": []
  },
  {
    "uid": null,
    "name": "Script Otter — Little Stream",
    "element": "Water",
    "hp": 96,
    "attack": 25,
    "defense": 8,
    "image_url": null,
    "avatar_url": null,
    "level": 1,
    "rarity": "common",
    "card_kind": "normal",
    "fusion_only": false,
    "physical_scan_enabled": false,
    "virtual_key": null,
    "lore": "Berang-berang coder yang mempelajari aliran pertama.",
    "metadata": {
      "timedoor_seed_key": "master_plan_v2_2:OTT-001",
      "source_card_code": "OTT-001",
      "seed_version": "2.2-learning-arcs-fusion",
      "source_document": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion.docx",
      "family_name": "Script Otter",
      "variant_name": "Little Stream",
      "display_name": "Script Otter — Little Stream",
      "learning_arc": "Discovery",
      "lesson_topic": "CODING",
      "learning_mission": "Urutkan aliran data sensor air: read, validate, process, display.",
      "skills": [
        {
          "name": "Bubble Tap",
          "effect": "Serangan normal; +3 damage ke target yang sedang Burn.",
          "slot": 1
        },
        {
          "name": "Quick Splash",
          "effect": "Pulihkan 8 HP satu rekan; CD 2.",
          "slot": 2
        }
      ],
      "fusion_tags": [],
      "catalog_status": "reference_data_pending_skill_playtest"
    },
    "card_code": "OTT_001",
    "tags": []
  },
  {
    "uid": null,
    "name": "Script Otter — Wave Reader",
    "element": "Water",
    "hp": 102,
    "attack": 26,
    "defense": 8,
    "image_url": null,
    "avatar_url": null,
    "level": 2,
    "rarity": "common",
    "card_kind": "normal",
    "fusion_only": false,
    "physical_scan_enabled": false,
    "virtual_key": null,
    "lore": "Membaca arus data untuk menghindari kondisi berbahaya.",
    "metadata": {
      "timedoor_seed_key": "master_plan_v2_2:OTT-002",
      "source_card_code": "OTT-002",
      "seed_version": "2.2-learning-arcs-fusion",
      "source_document": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion.docx",
      "family_name": "Script Otter",
      "variant_name": "Wave Reader",
      "display_name": "Script Otter — Wave Reader",
      "learning_arc": "Discovery",
      "lesson_topic": "CODING",
      "learning_mission": "Gunakan fungsi water_level untuk mengubah data bacaan menjadi status.",
      "skills": [
        {
          "name": "Wave Pulse",
          "effect": "Serangan normal; +3 damage jika HP diri di atas 50%.",
          "slot": 1
        },
        {
          "name": "Quick Splash",
          "effect": "Pulihkan 8 HP satu rekan; CD 2.",
          "slot": 2
        }
      ],
      "fusion_tags": [],
      "catalog_status": "reference_data_pending_skill_playtest"
    },
    "card_code": "OTT_002",
    "tags": []
  },
  {
    "uid": null,
    "name": "Script Otter — Bubble Helper",
    "element": "Water",
    "hp": 108,
    "attack": 28,
    "defense": 9,
    "image_url": null,
    "avatar_url": null,
    "level": 3,
    "rarity": "common",
    "card_kind": "normal",
    "fusion_only": false,
    "physical_scan_enabled": false,
    "virtual_key": null,
    "lore": "Membuat gelembung pertolongan untuk seorang rekan.",
    "metadata": {
      "timedoor_seed_key": "master_plan_v2_2:OTT-003",
      "source_card_code": "OTT-003",
      "seed_version": "2.2-learning-arcs-fusion",
      "source_document": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion.docx",
      "family_name": "Script Otter",
      "variant_name": "Bubble Helper",
      "display_name": "Script Otter — Bubble Helper",
      "learning_arc": "Discovery",
      "lesson_topic": "CODING",
      "learning_mission": "Buat kondisi untuk membersihkan input tidak valid tanpa merusak data lama.",
      "skills": [
        {
          "name": "Bubble Tap",
          "effect": "Serangan normal; +3 damage ke target yang sedang Burn.",
          "slot": 1
        },
        {
          "name": "Clean Stream",
          "effect": "Hapus 1 stack Burn satu rekan; CD 2.",
          "slot": 2
        }
      ],
      "fusion_tags": [],
      "catalog_status": "reference_data_pending_skill_playtest"
    },
    "card_code": "OTT_003",
    "tags": []
  },
  {
    "uid": null,
    "name": "Script Otter — River Coder",
    "element": "Water",
    "hp": 108,
    "attack": 28,
    "defense": 9,
    "image_url": null,
    "avatar_url": null,
    "level": 4,
    "rarity": "uncommon",
    "card_kind": "normal",
    "fusion_only": false,
    "physical_scan_enabled": false,
    "virtual_key": null,
    "lore": "Menggabungkan kode bersih dengan percikan air.",
    "metadata": {
      "timedoor_seed_key": "master_plan_v2_2:OTT-004",
      "source_card_code": "OTT-004",
      "seed_version": "2.2-learning-arcs-fusion",
      "source_document": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion.docx",
      "family_name": "Script Otter",
      "variant_name": "River Coder",
      "display_name": "Script Otter — River Coder",
      "learning_arc": "Strategy",
      "lesson_topic": "MATH",
      "learning_mission": "Hitung rata-rata lima sampel ketinggian air dari sensor simulasi.",
      "skills": [
        {
          "name": "Wave Pulse",
          "effect": "Serangan normal; +3 damage jika HP diri di atas 50%.",
          "slot": 1
        },
        {
          "name": "Clean Stream",
          "effect": "Hapus 1 stack Burn satu rekan; CD 2.",
          "slot": 2
        }
      ],
      "fusion_tags": [],
      "catalog_status": "reference_data_pending_skill_playtest"
    },
    "card_code": "OTT_004",
    "tags": []
  },
  {
    "uid": null,
    "name": "Script Otter — Tidal Debugger",
    "element": "Water",
    "hp": 116,
    "attack": 31,
    "defense": 11,
    "image_url": null,
    "avatar_url": null,
    "level": 5,
    "rarity": "uncommon",
    "card_kind": "normal",
    "fusion_only": false,
    "physical_scan_enabled": false,
    "virtual_key": null,
    "lore": "Menyingkirkan gangguan Burn dan Root secara tepat.",
    "metadata": {
      "timedoor_seed_key": "master_plan_v2_2:OTT-005",
      "source_card_code": "OTT-005",
      "seed_version": "2.2-learning-arcs-fusion",
      "source_document": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion.docx",
      "family_name": "Script Otter",
      "variant_name": "Tidal Debugger",
      "display_name": "Script Otter — Tidal Debugger",
      "learning_arc": "Strategy",
      "lesson_topic": "MATH",
      "learning_mission": "Buat grafik perubahan volume dan identifikasi nilai tertinggi.",
      "skills": [
        {
          "name": "Bubble Tap",
          "effect": "Serangan normal; +3 damage ke target yang sedang Burn.",
          "slot": 1
        },
        {
          "name": "Aqua Script",
          "effect": "Damage normal dan hapus Burn/Root satu rekan; CD 2.",
          "slot": 2
        }
      ],
      "fusion_tags": [],
      "catalog_status": "reference_data_pending_skill_playtest"
    },
    "card_code": "OTT_005",
    "tags": []
  },
  {
    "uid": null,
    "name": "Script Otter — Aqua Scripter",
    "element": "Water",
    "hp": 118,
    "attack": 32,
    "defense": 11,
    "image_url": null,
    "avatar_url": null,
    "level": 6,
    "rarity": "rare",
    "card_kind": "normal",
    "fusion_only": false,
    "physical_scan_enabled": false,
    "virtual_key": null,
    "lore": "Mencampur serangan air dan pemulihan yang efisien.",
    "metadata": {
      "timedoor_seed_key": "master_plan_v2_2:OTT-006",
      "source_card_code": "OTT-006",
      "seed_version": "2.2-learning-arcs-fusion",
      "source_document": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion.docx",
      "family_name": "Script Otter",
      "variant_name": "Aqua Scripter",
      "display_name": "Script Otter — Aqua Scripter",
      "learning_arc": "Communication",
      "lesson_topic": "ENGLISH",
      "learning_mission": "Tulis petunjuk English tentang kapan sistem menampilkan peringatan air.",
      "skills": [
        {
          "name": "Aqua Script",
          "effect": "Damage normal dan hapus Burn/Root satu rekan; CD 2.",
          "slot": 1
        },
        {
          "name": "River Recovery",
          "effect": "Pulihkan 22 HP satu rekan tanpa overheal; CD 2.",
          "slot": 2
        }
      ],
      "fusion_tags": [],
      "catalog_status": "reference_data_pending_skill_playtest"
    },
    "card_code": "OTT_006",
    "tags": []
  },
  {
    "uid": null,
    "name": "Script Otter — Coral Physician",
    "element": "Water",
    "hp": 130,
    "attack": 35,
    "defense": 13,
    "image_url": null,
    "avatar_url": null,
    "level": 7,
    "rarity": "rare",
    "card_kind": "normal",
    "fusion_only": false,
    "physical_scan_enabled": false,
    "virtual_key": null,
    "lore": "Penolong tim yang tidak boleh melakukan overheal.",
    "metadata": {
      "timedoor_seed_key": "master_plan_v2_2:OTT-007",
      "source_card_code": "OTT-007",
      "seed_version": "2.2-learning-arcs-fusion",
      "source_document": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion.docx",
      "family_name": "Script Otter",
      "variant_name": "Coral Physician",
      "display_name": "Script Otter — Coral Physician",
      "learning_arc": "Communication",
      "lesson_topic": "ENGLISH",
      "learning_mission": "Jelaskan hasil grafik air dalam tiga kalimat English yang ringkas.",
      "skills": [
        {
          "name": "Wave Pulse",
          "effect": "Serangan normal; +3 damage jika HP diri di atas 50%.",
          "slot": 1
        },
        {
          "name": "River Recovery",
          "effect": "Pulihkan 22 HP satu rekan tanpa overheal; CD 2.",
          "slot": 2
        }
      ],
      "fusion_tags": [
        "fusion:water_research"
      ],
      "catalog_status": "reference_data_pending_skill_playtest"
    },
    "card_code": "OTT_007",
    "tags": [
      "fusion:water_research"
    ]
  },
  {
    "uid": null,
    "name": "Script Otter — Ocean Compiler",
    "element": "Water",
    "hp": 139,
    "attack": 38,
    "defense": 14,
    "image_url": null,
    "avatar_url": null,
    "level": 8,
    "rarity": "epic",
    "card_kind": "normal",
    "fusion_only": false,
    "physical_scan_enabled": false,
    "virtual_key": null,
    "lore": "Mengolah aliran besar menjadi pilihan heal atau serangan.",
    "metadata": {
      "timedoor_seed_key": "master_plan_v2_2:OTT-008",
      "source_card_code": "OTT-008",
      "seed_version": "2.2-learning-arcs-fusion",
      "source_document": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion.docx",
      "family_name": "Script Otter",
      "variant_name": "Ocean Compiler",
      "display_name": "Script Otter — Ocean Compiler",
      "learning_arc": "Creation",
      "lesson_topic": "SKILL LAB",
      "learning_mission": "Buat dashboard pemantau ketinggian air dengan data simulasi.",
      "skills": [
        {
          "name": "Tidal Control",
          "effect": "Damage normal +6 pada target bershield; CD 2.",
          "slot": 1
        },
        {
          "name": "Clean Stream",
          "effect": "Hapus 1 stack Burn satu rekan; CD 2.",
          "slot": 2
        }
      ],
      "fusion_tags": [
        "fusion:research_core",
        "fusion:water_research"
      ],
      "catalog_status": "reference_data_pending_skill_playtest"
    },
    "card_code": "OTT_008",
    "tags": [
      "fusion:research_core",
      "fusion:water_research"
    ]
  },
  {
    "uid": null,
    "name": "Script Otter — Royal Tidekeeper",
    "element": "Water",
    "hp": 154,
    "attack": 42,
    "defense": 17,
    "image_url": null,
    "avatar_url": null,
    "level": 9,
    "rarity": "legendary",
    "card_kind": "normal",
    "fusion_only": false,
    "physical_scan_enabled": false,
    "virtual_key": null,
    "lore": "Penjaga air yang memberi solusi sekali per duel.",
    "metadata": {
      "timedoor_seed_key": "master_plan_v2_2:OTT-009",
      "source_card_code": "OTT-009",
      "seed_version": "2.2-learning-arcs-fusion",
      "source_document": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion.docx",
      "family_name": "Script Otter",
      "variant_name": "Royal Tidekeeper",
      "display_name": "Script Otter — Royal Tidekeeper",
      "learning_arc": "Creation",
      "lesson_topic": "SKILL LAB",
      "learning_mission": "Uji dashboard menggunakan sampel normal, kosong dan ekstrem.",
      "skills": [
        {
          "name": "Royal Cleanse",
          "effect": "Sekali/battle, hapus satu debuff dari satu rekan dan heal 8.",
          "slot": 1
        },
        {
          "name": "River Recovery",
          "effect": "Pulihkan 22 HP satu rekan tanpa overheal; CD 2.",
          "slot": 2
        }
      ],
      "fusion_tags": [],
      "catalog_status": "reference_data_pending_skill_playtest"
    },
    "card_code": "OTT_009",
    "tags": []
  },
  {
    "uid": null,
    "name": "Script Otter — Abyssal Source",
    "element": "Water",
    "hp": 166,
    "attack": 46,
    "defense": 19,
    "image_url": null,
    "avatar_url": null,
    "level": 10,
    "rarity": "mythic",
    "card_kind": "normal",
    "fusion_only": false,
    "physical_scan_enabled": false,
    "virtual_key": null,
    "lore": "Wujud puncak healer dengan keputusan taktis terbatas.",
    "metadata": {
      "timedoor_seed_key": "master_plan_v2_2:OTT-010",
      "source_card_code": "OTT-010",
      "seed_version": "2.2-learning-arcs-fusion",
      "source_document": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion.docx",
      "family_name": "Script Otter",
      "variant_name": "Abyssal Source",
      "display_name": "Script Otter — Abyssal Source",
      "learning_arc": "Creation",
      "lesson_topic": "SKILL LAB",
      "learning_mission": "Presentasikan prototipe sensor air dengan fungsi, statistik, dan English.",
      "skills": [
        {
          "name": "Source of Life",
          "effect": "Sekali/battle, pulihkan 22 HP satu rekan ATAU hapus 2 stack debuff biasa.",
          "slot": 1
        },
        {
          "name": "Tidal Control",
          "effect": "Damage normal +6 pada target bershield; CD 2.",
          "slot": 2
        }
      ],
      "fusion_tags": [],
      "catalog_status": "reference_data_pending_skill_playtest"
    },
    "card_code": "OTT_010",
    "tags": []
  },
  {
    "uid": null,
    "name": "Vector Wolf — Ember Pup",
    "element": "Fire",
    "hp": 93,
    "attack": 30,
    "defense": 8,
    "image_url": null,
    "avatar_url": null,
    "level": 1,
    "rarity": "common",
    "card_kind": "normal",
    "fusion_only": false,
    "physical_scan_enabled": false,
    "virtual_key": null,
    "lore": "Serigala muda yang belajar menjaga bara tetap menyala.",
    "metadata": {
      "timedoor_seed_key": "master_plan_v2_2:WLF-001",
      "source_card_code": "WLF-001",
      "seed_version": "2.2-learning-arcs-fusion",
      "source_document": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion.docx",
      "family_name": "Vector Wolf",
      "variant_name": "Ember Pup",
      "display_name": "Vector Wolf — Ember Pup",
      "learning_arc": "Discovery",
      "lesson_topic": "CODING",
      "learning_mission": "Buat event pemicu yang mengaktifkan serangan hanya saat target valid.",
      "skills": [
        {
          "name": "Ember Bite",
          "effect": "Serangan normal; menerapkan Burn standar pada hit.",
          "slot": 1
        },
        {
          "name": "Heat Focus",
          "effect": "Beri +4 DEF diri hingga 1 hit; CD 2.",
          "slot": 2
        }
      ],
      "fusion_tags": [],
      "catalog_status": "reference_data_pending_skill_playtest"
    },
    "card_code": "WLF_001",
    "tags": []
  },
  {
    "uid": null,
    "name": "Vector Wolf — Fire Tracer",
    "element": "Fire",
    "hp": 99,
    "attack": 32,
    "defense": 8,
    "image_url": null,
    "avatar_url": null,
    "level": 2,
    "rarity": "common",
    "card_kind": "normal",
    "fusion_only": false,
    "physical_scan_enabled": false,
    "virtual_key": null,
    "lore": "Melacak target lewat jejak panas di arena.",
    "metadata": {
      "timedoor_seed_key": "master_plan_v2_2:WLF-002",
      "source_card_code": "WLF-002",
      "seed_version": "2.2-learning-arcs-fusion",
      "source_document": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion.docx",
      "family_name": "Vector Wolf",
      "variant_name": "Fire Tracer",
      "display_name": "Vector Wolf — Fire Tracer",
      "learning_arc": "Discovery",
      "lesson_topic": "CODING",
      "learning_mission": "Gunakan if/else untuk membedakan target bertanda dan target biasa.",
      "skills": [
        {
          "name": "Flare Claw",
          "effect": "Serangan normal +3 ke target dengan Burn; terapkan Burn sesuai aturan.",
          "slot": 1
        },
        {
          "name": "Heat Focus",
          "effect": "Beri +4 DEF diri hingga 1 hit; CD 2.",
          "slot": 2
        }
      ],
      "fusion_tags": [],
      "catalog_status": "reference_data_pending_skill_playtest"
    },
    "card_code": "WLF_002",
    "tags": []
  },
  {
    "uid": null,
    "name": "Vector Wolf — Flare Hunter",
    "element": "Fire",
    "hp": 105,
    "attack": 33,
    "defense": 9,
    "image_url": null,
    "avatar_url": null,
    "level": 3,
    "rarity": "common",
    "card_kind": "normal",
    "fusion_only": false,
    "physical_scan_enabled": false,
    "virtual_key": null,
    "lore": "Memburu lawan yang sudah mendapat tanda panas.",
    "metadata": {
      "timedoor_seed_key": "master_plan_v2_2:WLF-003",
      "source_card_code": "WLF-003",
      "seed_version": "2.2-learning-arcs-fusion",
      "source_document": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion.docx",
      "family_name": "Vector Wolf",
      "variant_name": "Flare Hunter",
      "display_name": "Vector Wolf — Flare Hunter",
      "learning_arc": "Discovery",
      "lesson_topic": "CODING",
      "learning_mission": "Buat timer sederhana yang menghentikan efek Burn setelah durasi tertentu.",
      "skills": [
        {
          "name": "Ember Bite",
          "effect": "Serangan normal; menerapkan Burn standar pada hit.",
          "slot": 1
        },
        {
          "name": "Trail Guard",
          "effect": "Kurangi 7 damage hit berikutnya pada diri; CD 2.",
          "slot": 2
        }
      ],
      "fusion_tags": [],
      "catalog_status": "reference_data_pending_skill_playtest"
    },
    "card_code": "WLF_003",
    "tags": []
  },
  {
    "uid": null,
    "name": "Vector Wolf — Redline Runner",
    "element": "Fire",
    "hp": 105,
    "attack": 33,
    "defense": 9,
    "image_url": null,
    "avatar_url": null,
    "level": 4,
    "rarity": "uncommon",
    "card_kind": "normal",
    "fusion_only": false,
    "physical_scan_enabled": false,
    "virtual_key": null,
    "lore": "Melompat di jalur lava dengan serangan terukur.",
    "metadata": {
      "timedoor_seed_key": "master_plan_v2_2:WLF-004",
      "source_card_code": "WLF-004",
      "seed_version": "2.2-learning-arcs-fusion",
      "source_document": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion.docx",
      "family_name": "Vector Wolf",
      "variant_name": "Redline Runner",
      "display_name": "Vector Wolf — Redline Runner",
      "learning_arc": "Strategy",
      "lesson_topic": "MATH",
      "learning_mission": "Hitung selisih damage untuk dua variasi ATK dan DEF dalam simulasi.",
      "skills": [
        {
          "name": "Flare Claw",
          "effect": "Serangan normal +3 ke target dengan Burn; terapkan Burn sesuai aturan.",
          "slot": 1
        },
        {
          "name": "Trail Guard",
          "effect": "Kurangi 7 damage hit berikutnya pada diri; CD 2.",
          "slot": 2
        }
      ],
      "fusion_tags": [],
      "catalog_status": "reference_data_pending_skill_playtest"
    },
    "card_code": "WLF_004",
    "tags": []
  },
  {
    "uid": null,
    "name": "Vector Wolf — Vector Igniter",
    "element": "Fire",
    "hp": 113,
    "attack": 36,
    "defense": 11,
    "image_url": null,
    "avatar_url": null,
    "level": 5,
    "rarity": "uncommon",
    "card_kind": "normal",
    "fusion_only": false,
    "physical_scan_enabled": false,
    "virtual_key": null,
    "lore": "Menyusun serangan cepat untuk memicu Burn tepat waktu.",
    "metadata": {
      "timedoor_seed_key": "master_plan_v2_2:WLF-005",
      "source_card_code": "WLF-005",
      "seed_version": "2.2-learning-arcs-fusion",
      "source_document": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion.docx",
      "family_name": "Vector Wolf",
      "variant_name": "Vector Igniter",
      "display_name": "Vector Wolf — Vector Igniter",
      "learning_arc": "Strategy",
      "lesson_topic": "MATH",
      "learning_mission": "Gunakan pecahan dan peluang sederhana untuk membandingkan dua strategi.",
      "skills": [
        {
          "name": "Ember Bite",
          "effect": "Serangan normal; menerapkan Burn standar pada hit.",
          "slot": 1
        },
        {
          "name": "Ignition Mark",
          "effect": "Serangan skill biasa; tandai satu target hingga hit berikutnya; CD 2.",
          "slot": 2
        }
      ],
      "fusion_tags": [],
      "catalog_status": "reference_data_pending_skill_playtest"
    },
    "card_code": "WLF_005",
    "tags": []
  },
  {
    "uid": null,
    "name": "Vector Wolf — Blaze Tracker",
    "element": "Fire",
    "hp": 115,
    "attack": 37,
    "defense": 11,
    "image_url": null,
    "avatar_url": null,
    "level": 6,
    "rarity": "rare",
    "card_kind": "normal",
    "fusion_only": false,
    "physical_scan_enabled": false,
    "virtual_key": null,
    "lore": "Memfokuskan api ke satu sasaran alih-alih serangan luas.",
    "metadata": {
      "timedoor_seed_key": "master_plan_v2_2:WLF-006",
      "source_card_code": "WLF-006",
      "seed_version": "2.2-learning-arcs-fusion",
      "source_document": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion.docx",
      "family_name": "Vector Wolf",
      "variant_name": "Blaze Tracker",
      "display_name": "Vector Wolf — Blaze Tracker",
      "learning_arc": "Communication",
      "lesson_topic": "ENGLISH",
      "learning_mission": "Buat laporan English dua kalimat tentang urutan serangan yang aman.",
      "skills": [
        {
          "name": "Ignition Mark",
          "effect": "Serangan skill biasa; tandai satu target hingga hit berikutnya; CD 2.",
          "slot": 1
        },
        {
          "name": "Heat Rend",
          "effect": "Serangan normal +8 pada target bertanda; hapus Mark; CD 2.",
          "slot": 2
        }
      ],
      "fusion_tags": [],
      "catalog_status": "reference_data_pending_skill_playtest"
    },
    "card_code": "WLF_006",
    "tags": []
  },
  {
    "uid": null,
    "name": "Vector Wolf — Inferno Duelist",
    "element": "Fire",
    "hp": 127,
    "attack": 40,
    "defense": 13,
    "image_url": null,
    "avatar_url": null,
    "level": 7,
    "rarity": "rare",
    "card_kind": "normal",
    "fusion_only": false,
    "physical_scan_enabled": false,
    "virtual_key": null,
    "lore": "Memenangkan duel melalui rangkaian penandaan dan timing.",
    "metadata": {
      "timedoor_seed_key": "master_plan_v2_2:WLF-007",
      "source_card_code": "WLF-007",
      "seed_version": "2.2-learning-arcs-fusion",
      "source_document": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion.docx",
      "family_name": "Vector Wolf",
      "variant_name": "Inferno Duelist",
      "display_name": "Vector Wolf — Inferno Duelist",
      "learning_arc": "Communication",
      "lesson_topic": "ENGLISH",
      "learning_mission": "Latih diskusi English untuk memberi saran strategi dan menerima koreksi.",
      "skills": [
        {
          "name": "Flare Claw",
          "effect": "Serangan normal +3 ke target dengan Burn; terapkan Burn sesuai aturan.",
          "slot": 1
        },
        {
          "name": "Heat Rend",
          "effect": "Serangan normal +8 pada target bertanda; hapus Mark; CD 2.",
          "slot": 2
        }
      ],
      "fusion_tags": [],
      "catalog_status": "reference_data_pending_skill_playtest"
    },
    "card_code": "WLF_007",
    "tags": []
  },
  {
    "uid": null,
    "name": "Vector Wolf — Magma Striker",
    "element": "Fire",
    "hp": 136,
    "attack": 44,
    "defense": 14,
    "image_url": null,
    "avatar_url": null,
    "level": 8,
    "rarity": "epic",
    "card_kind": "normal",
    "fusion_only": false,
    "physical_scan_enabled": false,
    "virtual_key": null,
    "lore": "Mengubah kondisi Burn menjadi serangan bersyarat.",
    "metadata": {
      "timedoor_seed_key": "master_plan_v2_2:WLF-008",
      "source_card_code": "WLF-008",
      "seed_version": "2.2-learning-arcs-fusion",
      "source_document": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion.docx",
      "family_name": "Vector Wolf",
      "variant_name": "Magma Striker",
      "display_name": "Vector Wolf — Magma Striker",
      "learning_arc": "Creation",
      "lesson_topic": "SKILL LAB",
      "learning_mission": "Bangun simulator digital Fire Mark dan Burn yang memiliki cooldown.",
      "skills": [
        {
          "name": "Magma Pounce",
          "effect": "Serangan normal +7 jika target Burn; konsumsi 1 stack Burn; CD 2.",
          "slot": 1
        },
        {
          "name": "Trail Guard",
          "effect": "Kurangi 7 damage hit berikutnya pada diri; CD 2.",
          "slot": 2
        }
      ],
      "fusion_tags": [],
      "catalog_status": "reference_data_pending_skill_playtest"
    },
    "card_code": "WLF_008",
    "tags": []
  },
  {
    "uid": null,
    "name": "Vector Wolf — Crimson Overlord",
    "element": "Fire",
    "hp": 151,
    "attack": 48,
    "defense": 17,
    "image_url": null,
    "avatar_url": null,
    "level": 9,
    "rarity": "legendary",
    "card_kind": "normal",
    "fusion_only": false,
    "physical_scan_enabled": false,
    "virtual_key": null,
    "lore": "Pemburu api elit yang tetap memerlukan target setup.",
    "metadata": {
      "timedoor_seed_key": "master_plan_v2_2:WLF-009",
      "source_card_code": "WLF-009",
      "seed_version": "2.2-learning-arcs-fusion",
      "source_document": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion.docx",
      "family_name": "Vector Wolf",
      "variant_name": "Crimson Overlord",
      "display_name": "Vector Wolf — Crimson Overlord",
      "learning_arc": "Creation",
      "lesson_topic": "SKILL LAB",
      "learning_mission": "Uji 3 komposisi pertarungan; hitung damage tanpa stacking ilegal.",
      "skills": [
        {
          "name": "Crimson Hunt",
          "effect": "Sekali/battle, serangan normal +10 jika target Burn; konsumsi 1 stack.",
          "slot": 1
        },
        {
          "name": "Heat Rend",
          "effect": "Serangan normal +8 pada target bertanda; hapus Mark; CD 2.",
          "slot": 2
        }
      ],
      "fusion_tags": [],
      "catalog_status": "reference_data_pending_skill_playtest"
    },
    "card_code": "WLF_009",
    "tags": []
  },
  {
    "uid": null,
    "name": "Vector Wolf — Solar Fang",
    "element": "Fire",
    "hp": 163,
    "attack": 52,
    "defense": 19,
    "image_url": null,
    "avatar_url": null,
    "level": 10,
    "rarity": "mythic",
    "card_kind": "normal",
    "fusion_only": false,
    "physical_scan_enabled": false,
    "virtual_key": null,
    "lore": "Wujud puncak dengan finisher kuat dan jeda panjang.",
    "metadata": {
      "timedoor_seed_key": "master_plan_v2_2:WLF-010",
      "source_card_code": "WLF-010",
      "seed_version": "2.2-learning-arcs-fusion",
      "source_document": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion.docx",
      "family_name": "Vector Wolf",
      "variant_name": "Solar Fang",
      "display_name": "Vector Wolf — Solar Fang",
      "learning_arc": "Creation",
      "lesson_topic": "SKILL LAB",
      "learning_mission": "Demokan simulator dengan kode trigger, perhitungan efek, dan penjelasan English.",
      "skills": [
        {
          "name": "Solar Fang",
          "effect": "Sekali/battle, serangan normal +12 pada target bertanda; hapus Mark; CD 3.",
          "slot": 1
        },
        {
          "name": "Magma Pounce",
          "effect": "Serangan normal +7 jika target Burn; konsumsi 1 stack Burn; CD 2.",
          "slot": 2
        }
      ],
      "fusion_tags": [],
      "catalog_status": "reference_data_pending_skill_playtest"
    },
    "card_code": "WLF_010",
    "tags": []
  },
  {
    "uid": null,
    "name": "Cache Turtle — Pond Hatchling",
    "element": "Water",
    "hp": 106,
    "attack": 25,
    "defense": 10,
    "image_url": null,
    "avatar_url": null,
    "level": 1,
    "rarity": "common",
    "card_kind": "normal",
    "fusion_only": false,
    "physical_scan_enabled": false,
    "virtual_key": null,
    "lore": "Kura-kura kecil yang menyimpan air di tempurungnya.",
    "metadata": {
      "timedoor_seed_key": "master_plan_v2_2:TUR-001",
      "source_card_code": "TUR-001",
      "seed_version": "2.2-learning-arcs-fusion",
      "source_document": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion.docx",
      "family_name": "Cache Turtle",
      "variant_name": "Pond Hatchling",
      "display_name": "Cache Turtle — Pond Hatchling",
      "learning_arc": "Discovery",
      "lesson_topic": "CODING",
      "learning_mission": "Urutkan tahap save, validate dan load untuk menyimpan data cadangan.",
      "skills": [
        {
          "name": "Shell Bump",
          "effect": "Serangan normal; +3 damage jika diri punya Shield.",
          "slot": 1
        },
        {
          "name": "Bubble Guard",
          "effect": "Beri Shield 8 pada diri; CD 2.",
          "slot": 2
        }
      ],
      "fusion_tags": [],
      "catalog_status": "reference_data_pending_skill_playtest"
    },
    "card_code": "TUR_001",
    "tags": []
  },
  {
    "uid": null,
    "name": "Cache Turtle — Bubble Shell",
    "element": "Water",
    "hp": 110,
    "attack": 25,
    "defense": 10,
    "image_url": null,
    "avatar_url": null,
    "level": 2,
    "rarity": "common",
    "card_kind": "normal",
    "fusion_only": false,
    "physical_scan_enabled": false,
    "virtual_key": null,
    "lore": "Belajar bertahan lewat lapisan gelembung kuat.",
    "metadata": {
      "timedoor_seed_key": "master_plan_v2_2:TUR-002",
      "source_card_code": "TUR-002",
      "seed_version": "2.2-learning-arcs-fusion",
      "source_document": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion.docx",
      "family_name": "Cache Turtle",
      "variant_name": "Bubble Shell",
      "display_name": "Cache Turtle — Bubble Shell",
      "learning_arc": "Discovery",
      "lesson_topic": "CODING",
      "learning_mission": "Buat variabel shield_capacity yang bertambah dan berkurang secara aman.",
      "skills": [
        {
          "name": "Tide Bump",
          "effect": "Serangan normal; +3 damage saat HP diri di atas 50%.",
          "slot": 1
        },
        {
          "name": "Bubble Guard",
          "effect": "Beri Shield 8 pada diri; CD 2.",
          "slot": 2
        }
      ],
      "fusion_tags": [],
      "catalog_status": "reference_data_pending_skill_playtest"
    },
    "card_code": "TUR_002",
    "tags": []
  },
  {
    "uid": null,
    "name": "Cache Turtle — Stream Keeper",
    "element": "Water",
    "hp": 110,
    "attack": 27,
    "defense": 10,
    "image_url": null,
    "avatar_url": null,
    "level": 3,
    "rarity": "common",
    "card_kind": "normal",
    "fusion_only": false,
    "physical_scan_enabled": false,
    "virtual_key": null,
    "lore": "Menjaga arus agar rekan tidak kehilangan momentum.",
    "metadata": {
      "timedoor_seed_key": "master_plan_v2_2:TUR-003",
      "source_card_code": "TUR-003",
      "seed_version": "2.2-learning-arcs-fusion",
      "source_document": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion.docx",
      "family_name": "Cache Turtle",
      "variant_name": "Stream Keeper",
      "display_name": "Cache Turtle — Stream Keeper",
      "learning_arc": "Discovery",
      "lesson_topic": "CODING",
      "learning_mission": "Gunakan kondisi agar aksi guard tidak melebihi kapasitas maksimum.",
      "skills": [
        {
          "name": "Shell Bump",
          "effect": "Serangan normal; +3 damage jika diri punya Shield.",
          "slot": 1
        },
        {
          "name": "Clear Water",
          "effect": "Hapus satu stack Burn dari diri; CD 2.",
          "slot": 2
        }
      ],
      "fusion_tags": [],
      "catalog_status": "reference_data_pending_skill_playtest"
    },
    "card_code": "TUR_003",
    "tags": []
  },
  {
    "uid": null,
    "name": "Cache Turtle — Aqua Bulwark",
    "element": "Water",
    "hp": 118,
    "attack": 28,
    "defense": 11,
    "image_url": null,
    "avatar_url": null,
    "level": 4,
    "rarity": "uncommon",
    "card_kind": "normal",
    "fusion_only": false,
    "physical_scan_enabled": false,
    "virtual_key": null,
    "lore": "Membangun benteng air yang menyerap satu pukulan.",
    "metadata": {
      "timedoor_seed_key": "master_plan_v2_2:TUR-004",
      "source_card_code": "TUR-004",
      "seed_version": "2.2-learning-arcs-fusion",
      "source_document": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion.docx",
      "family_name": "Cache Turtle",
      "variant_name": "Aqua Bulwark",
      "display_name": "Cache Turtle — Aqua Bulwark",
      "learning_arc": "Strategy",
      "lesson_topic": "MATH",
      "learning_mission": "Hitung persentase daya shield yang tersisa sesudah dua serangan.",
      "skills": [
        {
          "name": "Tide Bump",
          "effect": "Serangan normal; +3 damage saat HP diri di atas 50%.",
          "slot": 1
        },
        {
          "name": "Clear Water",
          "effect": "Hapus satu stack Burn dari diri; CD 2.",
          "slot": 2
        }
      ],
      "fusion_tags": [],
      "catalog_status": "reference_data_pending_skill_playtest"
    },
    "card_code": "TUR_004",
    "tags": []
  },
  {
    "uid": null,
    "name": "Cache Turtle — Deep Cache",
    "element": "Water",
    "hp": 120,
    "attack": 30,
    "defense": 12,
    "image_url": null,
    "avatar_url": null,
    "level": 5,
    "rarity": "uncommon",
    "card_kind": "normal",
    "fusion_only": false,
    "physical_scan_enabled": false,
    "virtual_key": null,
    "lore": "Tempurungnya menjadi penyimpan energi air cadangan.",
    "metadata": {
      "timedoor_seed_key": "master_plan_v2_2:TUR-005",
      "source_card_code": "TUR-005",
      "seed_version": "2.2-learning-arcs-fusion",
      "source_document": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion.docx",
      "family_name": "Cache Turtle",
      "variant_name": "Deep Cache",
      "display_name": "Cache Turtle — Deep Cache",
      "learning_arc": "Strategy",
      "lesson_topic": "MATH",
      "learning_mission": "Bandingkan kebutuhan sumber daya dua desain tank air melalui tabel.",
      "skills": [
        {
          "name": "Shell Bump",
          "effect": "Serangan normal; +3 damage jika diri punya Shield.",
          "slot": 1
        },
        {
          "name": "Tide Guard",
          "effect": "Beri +8 DEF diri hingga 1 hit; CD 2.",
          "slot": 2
        }
      ],
      "fusion_tags": [],
      "catalog_status": "reference_data_pending_skill_playtest"
    },
    "card_code": "TUR_005",
    "tags": []
  },
  {
    "uid": null,
    "name": "Cache Turtle — Tidal Defender",
    "element": "Water",
    "hp": 128,
    "attack": 32,
    "defense": 13,
    "image_url": null,
    "avatar_url": null,
    "level": 6,
    "rarity": "rare",
    "card_kind": "normal",
    "fusion_only": false,
    "physical_scan_enabled": false,
    "virtual_key": null,
    "lore": "Tank yang memperlambat lawan dengan gelombang singkat.",
    "metadata": {
      "timedoor_seed_key": "master_plan_v2_2:TUR-006",
      "source_card_code": "TUR-006",
      "seed_version": "2.2-learning-arcs-fusion",
      "source_document": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion.docx",
      "family_name": "Cache Turtle",
      "variant_name": "Tidal Defender",
      "display_name": "Cache Turtle — Tidal Defender",
      "learning_arc": "Communication",
      "lesson_topic": "ENGLISH",
      "learning_mission": "Tuliskan 3 instruksi English untuk prosedur penggunaan shield yang aman.",
      "skills": [
        {
          "name": "Tide Guard",
          "effect": "Beri +8 DEF diri hingga 1 hit; CD 2.",
          "slot": 1
        },
        {
          "name": "Undertow Slam",
          "effect": "Damage normal; kurangi damage dari serangan target berikutnya sebesar 5; CD 2.",
          "slot": 2
        }
      ],
      "fusion_tags": [
        "fusion:water_guard"
      ],
      "catalog_status": "reference_data_pending_skill_playtest"
    },
    "card_code": "TUR_006",
    "tags": [
      "fusion:water_guard"
    ]
  },
  {
    "uid": null,
    "name": "Cache Turtle — Reef Fortress",
    "element": "Water",
    "hp": 135,
    "attack": 34,
    "defense": 14,
    "image_url": null,
    "avatar_url": null,
    "level": 7,
    "rarity": "rare",
    "card_kind": "normal",
    "fusion_only": false,
    "physical_scan_enabled": false,
    "virtual_key": null,
    "lore": "Menjadi pelindung terumbu digital bagi tim.",
    "metadata": {
      "timedoor_seed_key": "master_plan_v2_2:TUR-007",
      "source_card_code": "TUR-007",
      "seed_version": "2.2-learning-arcs-fusion",
      "source_document": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion.docx",
      "family_name": "Cache Turtle",
      "variant_name": "Reef Fortress",
      "display_name": "Cache Turtle — Reef Fortress",
      "learning_arc": "Communication",
      "lesson_topic": "ENGLISH",
      "learning_mission": "Jelaskan kepada rekan kapan harus guard atau memberi perlindungan.",
      "skills": [
        {
          "name": "Tide Bump",
          "effect": "Serangan normal; +3 damage saat HP diri di atas 50%.",
          "slot": 1
        },
        {
          "name": "Undertow Slam",
          "effect": "Damage normal; kurangi damage dari serangan target berikutnya sebesar 5; CD 2.",
          "slot": 2
        }
      ],
      "fusion_tags": [
        "fusion:water_guard"
      ],
      "catalog_status": "reference_data_pending_skill_playtest"
    },
    "card_code": "TUR_007",
    "tags": [
      "fusion:water_guard"
    ]
  },
  {
    "uid": null,
    "name": "Cache Turtle — Ocean Bastion",
    "element": "Water",
    "hp": 149,
    "attack": 37,
    "defense": 16,
    "image_url": null,
    "avatar_url": null,
    "level": 8,
    "rarity": "epic",
    "card_kind": "normal",
    "fusion_only": false,
    "physical_scan_enabled": false,
    "virtual_key": null,
    "lore": "Pertahanan laut yang memberi perlindungan terukur.",
    "metadata": {
      "timedoor_seed_key": "master_plan_v2_2:TUR-008",
      "source_card_code": "TUR-008",
      "seed_version": "2.2-learning-arcs-fusion",
      "source_document": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion.docx",
      "family_name": "Cache Turtle",
      "variant_name": "Ocean Bastion",
      "display_name": "Cache Turtle — Ocean Bastion",
      "learning_arc": "Creation",
      "lesson_topic": "SKILL LAB",
      "learning_mission": "Buat prototipe pengatur persediaan air digital berbatas kapasitas.",
      "skills": [
        {
          "name": "Reef Cover",
          "effect": "Beri Shield 16 satu rekan; CD 3.",
          "slot": 1
        },
        {
          "name": "Clear Water",
          "effect": "Hapus satu stack Burn dari diri; CD 2.",
          "slot": 2
        }
      ],
      "fusion_tags": [],
      "catalog_status": "reference_data_pending_skill_playtest"
    },
    "card_code": "TUR_008",
    "tags": []
  },
  {
    "uid": null,
    "name": "Cache Turtle — Leviathan Shell",
    "element": "Water",
    "hp": 164,
    "attack": 41,
    "defense": 19,
    "image_url": null,
    "avatar_url": null,
    "level": 9,
    "rarity": "legendary",
    "card_kind": "normal",
    "fusion_only": false,
    "physical_scan_enabled": false,
    "virtual_key": null,
    "lore": "Benteng legendaris yang melindungi satu rekan kritis.",
    "metadata": {
      "timedoor_seed_key": "master_plan_v2_2:TUR-009",
      "source_card_code": "TUR-009",
      "seed_version": "2.2-learning-arcs-fusion",
      "source_document": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion.docx",
      "family_name": "Cache Turtle",
      "variant_name": "Leviathan Shell",
      "display_name": "Cache Turtle — Leviathan Shell",
      "learning_arc": "Creation",
      "lesson_topic": "SKILL LAB",
      "learning_mission": "Uji simulasi kebocoran dan tentukan tindakan penyelamatan terbaik.",
      "skills": [
        {
          "name": "Leviathan Shield",
          "effect": "Sekali/battle, beri Shield 18 satu rekan; tak menumpuk.",
          "slot": 1
        },
        {
          "name": "Undertow Slam",
          "effect": "Damage normal; kurangi damage dari serangan target berikutnya sebesar 5; CD 2.",
          "slot": 2
        }
      ],
      "fusion_tags": [],
      "catalog_status": "reference_data_pending_skill_playtest"
    },
    "card_code": "TUR_009",
    "tags": []
  },
  {
    "uid": null,
    "name": "Cache Turtle — Abyss Guardian",
    "element": "Water",
    "hp": 175,
    "attack": 45,
    "defense": 21,
    "image_url": null,
    "avatar_url": null,
    "level": 10,
    "rarity": "mythic",
    "card_kind": "normal",
    "fusion_only": false,
    "physical_scan_enabled": false,
    "virtual_key": null,
    "lore": "Wujud puncak tank air, kuat namun tanpa burst ekstrem.",
    "metadata": {
      "timedoor_seed_key": "master_plan_v2_2:TUR-010",
      "source_card_code": "TUR-010",
      "seed_version": "2.2-learning-arcs-fusion",
      "source_document": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion.docx",
      "family_name": "Cache Turtle",
      "variant_name": "Abyss Guardian",
      "display_name": "Cache Turtle — Abyss Guardian",
      "learning_arc": "Creation",
      "lesson_topic": "SKILL LAB",
      "learning_mission": "Presentasikan solusi hemat air dengan kode validasi, persen, dan English.",
      "skills": [
        {
          "name": "Abyss Shelter",
          "effect": "Sekali/battle, pilih Shield 20 satu rekan ATAU cleanse 1 debuff biasa.",
          "slot": 1
        },
        {
          "name": "Reef Cover",
          "effect": "Beri Shield 16 satu rekan; CD 3.",
          "slot": 2
        }
      ],
      "fusion_tags": [],
      "catalog_status": "reference_data_pending_skill_playtest"
    },
    "card_code": "TUR_010",
    "tags": []
  },
  {
    "uid": null,
    "name": "Spark Panda — Tiny Zap",
    "element": "Electric",
    "hp": 92,
    "attack": 30,
    "defense": 7,
    "image_url": null,
    "avatar_url": null,
    "level": 1,
    "rarity": "common",
    "card_kind": "normal",
    "fusion_only": false,
    "physical_scan_enabled": false,
    "virtual_key": null,
    "lore": "Panda imut yang menyalakan percikan sirkuit pertama.",
    "metadata": {
      "timedoor_seed_key": "master_plan_v2_2:PAN-001",
      "source_card_code": "PAN-001",
      "seed_version": "2.2-learning-arcs-fusion",
      "source_document": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion.docx",
      "family_name": "Spark Panda",
      "variant_name": "Tiny Zap",
      "display_name": "Spark Panda — Tiny Zap",
      "learning_arc": "Discovery",
      "lesson_topic": "CODING",
      "learning_mission": "Susun instruksi untuk menyalakan LED virtual dengan urutan benar.",
      "skills": [
        {
          "name": "Zap Tap",
          "effect": "Serangan normal; +3 damage bila rekan Electric di Bench.",
          "slot": 1
        },
        {
          "name": "Static Coat",
          "effect": "Beri +4 DEF diri hingga 1 hit; CD 2.",
          "slot": 2
        }
      ],
      "fusion_tags": [],
      "catalog_status": "reference_data_pending_skill_playtest"
    },
    "card_code": "PAN_001",
    "tags": []
  },
  {
    "uid": null,
    "name": "Spark Panda — Bolt Tinkerer",
    "element": "Electric",
    "hp": 98,
    "attack": 32,
    "defense": 7,
    "image_url": null,
    "avatar_url": null,
    "level": 2,
    "rarity": "common",
    "card_kind": "normal",
    "fusion_only": false,
    "physical_scan_enabled": false,
    "virtual_key": null,
    "lore": "Menghubungkan komponen listrik untuk melatih refleks.",
    "metadata": {
      "timedoor_seed_key": "master_plan_v2_2:PAN-002",
      "source_card_code": "PAN-002",
      "seed_version": "2.2-learning-arcs-fusion",
      "source_document": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion.docx",
      "family_name": "Spark Panda",
      "variant_name": "Bolt Tinkerer",
      "display_name": "Spark Panda — Bolt Tinkerer",
      "learning_arc": "Discovery",
      "lesson_topic": "CODING",
      "learning_mission": "Gunakan variabel power untuk menjaga batas penggunaan energi.",
      "skills": [
        {
          "name": "Bolt Punch",
          "effect": "Serangan normal +3 pada target tanpa Shield.",
          "slot": 1
        },
        {
          "name": "Static Coat",
          "effect": "Beri +4 DEF diri hingga 1 hit; CD 2.",
          "slot": 2
        }
      ],
      "fusion_tags": [],
      "catalog_status": "reference_data_pending_skill_playtest"
    },
    "card_code": "PAN_002",
    "tags": []
  },
  {
    "uid": null,
    "name": "Spark Panda — Static Runner",
    "element": "Electric",
    "hp": 104,
    "attack": 33,
    "defense": 8,
    "image_url": null,
    "avatar_url": null,
    "level": 3,
    "rarity": "common",
    "card_kind": "normal",
    "fusion_only": false,
    "physical_scan_enabled": false,
    "virtual_key": null,
    "lore": "Bergerak cepat untuk mengisi energi serangan.",
    "metadata": {
      "timedoor_seed_key": "master_plan_v2_2:PAN-003",
      "source_card_code": "PAN-003",
      "seed_version": "2.2-learning-arcs-fusion",
      "source_document": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion.docx",
      "family_name": "Spark Panda",
      "variant_name": "Static Runner",
      "display_name": "Spark Panda — Static Runner",
      "learning_arc": "Discovery",
      "lesson_topic": "CODING",
      "learning_mission": "Buat event ganda yang mengaktifkan dua lampu tanpa menjalankan aksi dua kali.",
      "skills": [
        {
          "name": "Zap Tap",
          "effect": "Serangan normal; +3 damage bila rekan Electric di Bench.",
          "slot": 1
        },
        {
          "name": "Power Save",
          "effect": "Kurangi 7 damage hit berikutnya ke diri; CD 2.",
          "slot": 2
        }
      ],
      "fusion_tags": [],
      "catalog_status": "reference_data_pending_skill_playtest"
    },
    "card_code": "PAN_003",
    "tags": []
  },
  {
    "uid": null,
    "name": "Spark Panda — Circuit Juggler",
    "element": "Electric",
    "hp": 104,
    "attack": 33,
    "defense": 8,
    "image_url": null,
    "avatar_url": null,
    "level": 4,
    "rarity": "uncommon",
    "card_kind": "normal",
    "fusion_only": false,
    "physical_scan_enabled": false,
    "virtual_key": null,
    "lore": "Mengelola percikan agar tidak membebani tim.",
    "metadata": {
      "timedoor_seed_key": "master_plan_v2_2:PAN-004",
      "source_card_code": "PAN-004",
      "seed_version": "2.2-learning-arcs-fusion",
      "source_document": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion.docx",
      "family_name": "Spark Panda",
      "variant_name": "Circuit Juggler",
      "display_name": "Spark Panda — Circuit Juggler",
      "learning_arc": "Strategy",
      "lesson_topic": "MATH",
      "learning_mission": "Ubah bilangan biner sederhana menjadi desimal menggunakan tabel.",
      "skills": [
        {
          "name": "Bolt Punch",
          "effect": "Serangan normal +3 pada target tanpa Shield.",
          "slot": 1
        },
        {
          "name": "Power Save",
          "effect": "Kurangi 7 damage hit berikutnya ke diri; CD 2.",
          "slot": 2
        }
      ],
      "fusion_tags": [],
      "catalog_status": "reference_data_pending_skill_playtest"
    },
    "card_code": "PAN_004",
    "tags": []
  },
  {
    "uid": null,
    "name": "Spark Panda — Spark Linker",
    "element": "Electric",
    "hp": 112,
    "attack": 36,
    "defense": 10,
    "image_url": null,
    "avatar_url": null,
    "level": 5,
    "rarity": "uncommon",
    "card_kind": "normal",
    "fusion_only": false,
    "physical_scan_enabled": false,
    "virtual_key": null,
    "lore": "Menjalin kombo listrik dengan rekan Electric.",
    "metadata": {
      "timedoor_seed_key": "master_plan_v2_2:PAN-005",
      "source_card_code": "PAN-005",
      "seed_version": "2.2-learning-arcs-fusion",
      "source_document": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion.docx",
      "family_name": "Spark Panda",
      "variant_name": "Spark Linker",
      "display_name": "Spark Panda — Spark Linker",
      "learning_arc": "Strategy",
      "lesson_topic": "MATH",
      "learning_mission": "Hitung total kebutuhan daya dari rangkaian kecil berbasis angka simulasi.",
      "skills": [
        {
          "name": "Zap Tap",
          "effect": "Serangan normal; +3 damage bila rekan Electric di Bench.",
          "slot": 1
        },
        {
          "name": "Spark Link",
          "effect": "Damage normal +5 bila ally Electric di Bench; CD 1.",
          "slot": 2
        }
      ],
      "fusion_tags": [],
      "catalog_status": "reference_data_pending_skill_playtest"
    },
    "card_code": "PAN_005",
    "tags": []
  },
  {
    "uid": null,
    "name": "Spark Panda — Volt Engineer",
    "element": "Electric",
    "hp": 114,
    "attack": 37,
    "defense": 10,
    "image_url": null,
    "avatar_url": null,
    "level": 6,
    "rarity": "rare",
    "card_kind": "normal",
    "fusion_only": false,
    "physical_scan_enabled": false,
    "virtual_key": null,
    "lore": "Teknisi serangan rantai yang berbasis syarat.",
    "metadata": {
      "timedoor_seed_key": "master_plan_v2_2:PAN-006",
      "source_card_code": "PAN-006",
      "seed_version": "2.2-learning-arcs-fusion",
      "source_document": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion.docx",
      "family_name": "Spark Panda",
      "variant_name": "Volt Engineer",
      "display_name": "Spark Panda — Volt Engineer",
      "learning_arc": "Communication",
      "lesson_topic": "ENGLISH",
      "learning_mission": "Jelaskan English fungsi input, output, signal dan circuit.",
      "skills": [
        {
          "name": "Spark Link",
          "effect": "Damage normal +5 bila ally Electric di Bench; CD 1.",
          "slot": 1
        },
        {
          "name": "Thunder Chain",
          "effect": "Serang maksimum 2 target masing-masing 0,75× ATK; CD 3.",
          "slot": 2
        }
      ],
      "fusion_tags": [],
      "catalog_status": "reference_data_pending_skill_playtest"
    },
    "card_code": "PAN_006",
    "tags": []
  },
  {
    "uid": null,
    "name": "Spark Panda — Chain Caster",
    "element": "Electric",
    "hp": 126,
    "attack": 40,
    "defense": 12,
    "image_url": null,
    "avatar_url": null,
    "level": 7,
    "rarity": "rare",
    "card_kind": "normal",
    "fusion_only": false,
    "physical_scan_enabled": false,
    "virtual_key": null,
    "lore": "Membagi daya listrik agar menjangkau dua target.",
    "metadata": {
      "timedoor_seed_key": "master_plan_v2_2:PAN-007",
      "source_card_code": "PAN-007",
      "seed_version": "2.2-learning-arcs-fusion",
      "source_document": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion.docx",
      "family_name": "Spark Panda",
      "variant_name": "Chain Caster",
      "display_name": "Spark Panda — Chain Caster",
      "learning_arc": "Communication",
      "lesson_topic": "ENGLISH",
      "learning_mission": "Berikan instruksi English untuk memasang rangkaian LED simulasi.",
      "skills": [
        {
          "name": "Bolt Punch",
          "effect": "Serangan normal +3 pada target tanpa Shield.",
          "slot": 1
        },
        {
          "name": "Thunder Chain",
          "effect": "Serang maksimum 2 target masing-masing 0,75× ATK; CD 3.",
          "slot": 2
        }
      ],
      "fusion_tags": [],
      "catalog_status": "reference_data_pending_skill_playtest"
    },
    "card_code": "PAN_007",
    "tags": []
  },
  {
    "uid": null,
    "name": "Spark Panda — Overcharge Panda",
    "element": "Electric",
    "hp": 135,
    "attack": 44,
    "defense": 13,
    "image_url": null,
    "avatar_url": null,
    "level": 8,
    "rarity": "epic",
    "card_kind": "normal",
    "fusion_only": false,
    "physical_scan_enabled": false,
    "virtual_key": null,
    "lore": "Mengerahkan lonjakan daya dengan cooldown panjang.",
    "metadata": {
      "timedoor_seed_key": "master_plan_v2_2:PAN-008",
      "source_card_code": "PAN-008",
      "seed_version": "2.2-learning-arcs-fusion",
      "source_document": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion.docx",
      "family_name": "Spark Panda",
      "variant_name": "Overcharge Panda",
      "display_name": "Spark Panda — Overcharge Panda",
      "learning_arc": "Creation",
      "lesson_topic": "SKILL LAB",
      "learning_mission": "Buat program LED interaktif yang merespons tombol atau sensor simulasi.",
      "skills": [
        {
          "name": "Overcharge",
          "effect": "Serangan normal +8 bila rekan Electric di Bench; CD 2.",
          "slot": 1
        },
        {
          "name": "Power Save",
          "effect": "Kurangi 7 damage hit berikutnya ke diri; CD 2.",
          "slot": 2
        }
      ],
      "fusion_tags": [
        "fusion:research_core"
      ],
      "catalog_status": "reference_data_pending_skill_playtest"
    },
    "card_code": "PAN_008",
    "tags": [
      "fusion:research_core"
    ]
  },
  {
    "uid": null,
    "name": "Spark Panda — Plasma Conductor",
    "element": "Electric",
    "hp": 150,
    "attack": 48,
    "defense": 16,
    "image_url": null,
    "avatar_url": null,
    "level": 9,
    "rarity": "legendary",
    "card_kind": "normal",
    "fusion_only": false,
    "physical_scan_enabled": false,
    "virtual_key": null,
    "lore": "Konduktor elit yang memerlukan penempatan Bench tepat.",
    "metadata": {
      "timedoor_seed_key": "master_plan_v2_2:PAN-009",
      "source_card_code": "PAN-009",
      "seed_version": "2.2-learning-arcs-fusion",
      "source_document": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion.docx",
      "family_name": "Spark Panda",
      "variant_name": "Plasma Conductor",
      "display_name": "Spark Panda — Plasma Conductor",
      "learning_arc": "Creation",
      "lesson_topic": "SKILL LAB",
      "learning_mission": "Uji tiga pola nyala dan hitung kebutuhan energi masing-masing.",
      "skills": [
        {
          "name": "Plasma Web",
          "effect": "Sekali/battle, serang maksimum 2 target masing-masing 0,75× ATK.",
          "slot": 1
        },
        {
          "name": "Thunder Chain",
          "effect": "Serang maksimum 2 target masing-masing 0,75× ATK; CD 3.",
          "slot": 2
        }
      ],
      "fusion_tags": [],
      "catalog_status": "reference_data_pending_skill_playtest"
    },
    "card_code": "PAN_009",
    "tags": []
  },
  {
    "uid": null,
    "name": "Spark Panda — Supernova Spark",
    "element": "Electric",
    "hp": 162,
    "attack": 52,
    "defense": 18,
    "image_url": null,
    "avatar_url": null,
    "level": 10,
    "rarity": "mythic",
    "card_kind": "normal",
    "fusion_only": false,
    "physical_scan_enabled": false,
    "virtual_key": null,
    "lore": "Wujud puncak listrik dengan satu kombo penentu.",
    "metadata": {
      "timedoor_seed_key": "master_plan_v2_2:PAN-010",
      "source_card_code": "PAN-010",
      "seed_version": "2.2-learning-arcs-fusion",
      "source_document": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion.docx",
      "family_name": "Spark Panda",
      "variant_name": "Supernova Spark",
      "display_name": "Spark Panda — Supernova Spark",
      "learning_arc": "Creation",
      "lesson_topic": "SKILL LAB",
      "learning_mission": "Presentasikan demo elektronika interaktif serta algoritma dan perhitungannya.",
      "skills": [
        {
          "name": "Supernova Circuit",
          "effect": "Sekali/battle, serangan normal berikutnya rekan +8; tanpa extra action.",
          "slot": 1
        },
        {
          "name": "Overcharge",
          "effect": "Serangan normal +8 bila rekan Electric di Bench; CD 2.",
          "slot": 2
        }
      ],
      "fusion_tags": [],
      "catalog_status": "reference_data_pending_skill_playtest"
    },
    "card_code": "PAN_010",
    "tags": []
  },
  {
    "uid": null,
    "name": "Pico Cat — Little Ember",
    "element": "Fire",
    "hp": 90,
    "attack": 29,
    "defense": 7,
    "image_url": null,
    "avatar_url": null,
    "level": 1,
    "rarity": "common",
    "card_kind": "normal",
    "fusion_only": false,
    "physical_scan_enabled": false,
    "virtual_key": null,
    "lore": "Kucing kecil usil yang menemukan percikan pertamanya.",
    "metadata": {
      "timedoor_seed_key": "master_plan_v2_2:PIC-001",
      "source_card_code": "PIC-001",
      "seed_version": "2.2-learning-arcs-fusion",
      "source_document": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion.docx",
      "family_name": "Pico Cat",
      "variant_name": "Little Ember",
      "display_name": "Pico Cat — Little Ember",
      "learning_arc": "Discovery",
      "lesson_topic": "CODING",
      "learning_mission": "Urutkan frame animasi supaya Pico bergerak dengan mulus.",
      "skills": [
        {
          "name": "Ember Tap",
          "effect": "Serangan normal; menerapkan Burn standar pada hit.",
          "slot": 1
        },
        {
          "name": "Tiny Decoy",
          "effect": "Kurangi 6 damage pada hit berikutnya ke diri; CD 2.",
          "slot": 2
        }
      ],
      "fusion_tags": [],
      "catalog_status": "reference_data_pending_skill_playtest"
    },
    "card_code": "PIC_001",
    "tags": []
  },
  {
    "uid": null,
    "name": "Pico Cat — Flame Skipper",
    "element": "Fire",
    "hp": 96,
    "attack": 31,
    "defense": 7,
    "image_url": null,
    "avatar_url": null,
    "level": 2,
    "rarity": "common",
    "card_kind": "normal",
    "fusion_only": false,
    "physical_scan_enabled": false,
    "virtual_key": null,
    "lore": "Melompat menghindari api sambil memberi tekanan.",
    "metadata": {
      "timedoor_seed_key": "master_plan_v2_2:PIC-002",
      "source_card_code": "PIC-002",
      "seed_version": "2.2-learning-arcs-fusion",
      "source_document": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion.docx",
      "family_name": "Pico Cat",
      "variant_name": "Flame Skipper",
      "display_name": "Pico Cat — Flame Skipper",
      "learning_arc": "Discovery",
      "lesson_topic": "CODING",
      "learning_mission": "Gunakan loop untuk mengulang gerakan api digital tanpa jeda aneh.",
      "skills": [
        {
          "name": "Flame Hop",
          "effect": "Serangan normal +3 saat baru masuk Active; terapkan Burn.",
          "slot": 1
        },
        {
          "name": "Tiny Decoy",
          "effect": "Kurangi 6 damage pada hit berikutnya ke diri; CD 2.",
          "slot": 2
        }
      ],
      "fusion_tags": [],
      "catalog_status": "reference_data_pending_skill_playtest"
    },
    "card_code": "PIC_002",
    "tags": []
  },
  {
    "uid": null,
    "name": "Pico Cat — Soot Sneaker",
    "element": "Fire",
    "hp": 102,
    "attack": 33,
    "defense": 8,
    "image_url": null,
    "avatar_url": null,
    "level": 3,
    "rarity": "common",
    "card_kind": "normal",
    "fusion_only": false,
    "physical_scan_enabled": false,
    "virtual_key": null,
    "lore": "Menyelinap lewat kepulan asap untuk membantu tim.",
    "metadata": {
      "timedoor_seed_key": "master_plan_v2_2:PIC-003",
      "source_card_code": "PIC-003",
      "seed_version": "2.2-learning-arcs-fusion",
      "source_document": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion.docx",
      "family_name": "Pico Cat",
      "variant_name": "Soot Sneaker",
      "display_name": "Pico Cat — Soot Sneaker",
      "learning_arc": "Discovery",
      "lesson_topic": "CODING",
      "learning_mission": "Buat event keyboard yang menyalakan efek animasi hanya saat aksi valid.",
      "skills": [
        {
          "name": "Ember Tap",
          "effect": "Serangan normal; menerapkan Burn standar pada hit.",
          "slot": 1
        },
        {
          "name": "Soot Screen",
          "effect": "Beri +4 DEF satu rekan hingga satu hit; CD 2.",
          "slot": 2
        }
      ],
      "fusion_tags": [],
      "catalog_status": "reference_data_pending_skill_playtest"
    },
    "card_code": "PIC_003",
    "tags": []
  },
  {
    "uid": null,
    "name": "Pico Cat — Fire Dancer",
    "element": "Fire",
    "hp": 102,
    "attack": 32,
    "defense": 8,
    "image_url": null,
    "avatar_url": null,
    "level": 4,
    "rarity": "uncommon",
    "card_kind": "normal",
    "fusion_only": false,
    "physical_scan_enabled": false,
    "virtual_key": null,
    "lore": "Memakai gerak gesit demi mencuri tempo lawan.",
    "metadata": {
      "timedoor_seed_key": "master_plan_v2_2:PIC-004",
      "source_card_code": "PIC-004",
      "seed_version": "2.2-learning-arcs-fusion",
      "source_document": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion.docx",
      "family_name": "Pico Cat",
      "variant_name": "Fire Dancer",
      "display_name": "Pico Cat — Fire Dancer",
      "learning_arc": "Strategy",
      "lesson_topic": "MATH",
      "learning_mission": "Hitung sudut putar karakter pada empat arah dalam grid.",
      "skills": [
        {
          "name": "Flame Hop",
          "effect": "Serangan normal +3 saat baru masuk Active; terapkan Burn.",
          "slot": 1
        },
        {
          "name": "Soot Screen",
          "effect": "Beri +4 DEF satu rekan hingga satu hit; CD 2.",
          "slot": 2
        }
      ],
      "fusion_tags": [],
      "catalog_status": "reference_data_pending_skill_playtest"
    },
    "card_code": "PIC_004",
    "tags": []
  },
  {
    "uid": null,
    "name": "Pico Cat — Ember Dash",
    "element": "Fire",
    "hp": 110,
    "attack": 36,
    "defense": 10,
    "image_url": null,
    "avatar_url": null,
    "level": 5,
    "rarity": "uncommon",
    "card_kind": "normal",
    "fusion_only": false,
    "physical_scan_enabled": false,
    "virtual_key": null,
    "lore": "Menyerang cepat dan mengurangi balasan berikutnya.",
    "metadata": {
      "timedoor_seed_key": "master_plan_v2_2:PIC-005",
      "source_card_code": "PIC-005",
      "seed_version": "2.2-learning-arcs-fusion",
      "source_document": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion.docx",
      "family_name": "Pico Cat",
      "variant_name": "Ember Dash",
      "display_name": "Pico Cat — Ember Dash",
      "learning_arc": "Strategy",
      "lesson_topic": "MATH",
      "learning_mission": "Bandingkan durasi animasi pada 6, 8 dan 10 frame secara proporsional.",
      "skills": [
        {
          "name": "Ember Tap",
          "effect": "Serangan normal; menerapkan Burn standar pada hit.",
          "slot": 1
        },
        {
          "name": "Ember Dash",
          "effect": "Serangan normal; +4 DEF diri hingga 1 hit; CD 2.",
          "slot": 2
        }
      ],
      "fusion_tags": [],
      "catalog_status": "reference_data_pending_skill_playtest"
    },
    "card_code": "PIC_005",
    "tags": []
  },
  {
    "uid": null,
    "name": "Pico Cat — Blaze Decoy",
    "element": "Fire",
    "hp": 112,
    "attack": 36,
    "defense": 10,
    "image_url": null,
    "avatar_url": null,
    "level": 6,
    "rarity": "rare",
    "card_kind": "normal",
    "fusion_only": false,
    "physical_scan_enabled": false,
    "virtual_key": null,
    "lore": "Mengalihkan satu serangan agar rekan bertahan.",
    "metadata": {
      "timedoor_seed_key": "master_plan_v2_2:PIC-006",
      "source_card_code": "PIC-006",
      "seed_version": "2.2-learning-arcs-fusion",
      "source_document": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion.docx",
      "family_name": "Pico Cat",
      "variant_name": "Blaze Decoy",
      "display_name": "Pico Cat — Blaze Decoy",
      "learning_arc": "Communication",
      "lesson_topic": "ENGLISH",
      "learning_mission": "Tulis cerita English empat kalimat tentang misi Pico Cat.",
      "skills": [
        {
          "name": "Ember Dash",
          "effect": "Serangan normal; +4 DEF diri hingga 1 hit; CD 2.",
          "slot": 1
        },
        {
          "name": "Flare Feint",
          "effect": "Kurangi 8 damage hit berikutnya yang menarget rekan lain; CD 2.",
          "slot": 2
        }
      ],
      "fusion_tags": [
        "fusion:fire_feint"
      ],
      "catalog_status": "reference_data_pending_skill_playtest"
    },
    "card_code": "PIC_006",
    "tags": [
      "fusion:fire_feint"
    ]
  },
  {
    "uid": null,
    "name": "Pico Cat — Cinder Scout",
    "element": "Fire",
    "hp": 124,
    "attack": 40,
    "defense": 12,
    "image_url": null,
    "avatar_url": null,
    "level": 7,
    "rarity": "rare",
    "card_kind": "normal",
    "fusion_only": false,
    "physical_scan_enabled": false,
    "virtual_key": null,
    "lore": "Mengacaukan targeting tanpa hard stun.",
    "metadata": {
      "timedoor_seed_key": "master_plan_v2_2:PIC-007",
      "source_card_code": "PIC-007",
      "seed_version": "2.2-learning-arcs-fusion",
      "source_document": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion.docx",
      "family_name": "Pico Cat",
      "variant_name": "Cinder Scout",
      "display_name": "Pico Cat — Cinder Scout",
      "learning_arc": "Communication",
      "lesson_topic": "ENGLISH",
      "learning_mission": "Buat dialog singkat English yang menjelaskan pilihan karakter saat misi.",
      "skills": [
        {
          "name": "Flame Hop",
          "effect": "Serangan normal +3 saat baru masuk Active; terapkan Burn.",
          "slot": 1
        },
        {
          "name": "Flare Feint",
          "effect": "Kurangi 8 damage hit berikutnya yang menarget rekan lain; CD 2.",
          "slot": 2
        }
      ],
      "fusion_tags": [
        "fusion:fire_feint"
      ],
      "catalog_status": "reference_data_pending_skill_playtest"
    },
    "card_code": "PIC_007",
    "tags": [
      "fusion:fire_feint"
    ]
  },
  {
    "uid": null,
    "name": "Pico Cat — Flare Illusion",
    "element": "Fire",
    "hp": 133,
    "attack": 43,
    "defense": 13,
    "image_url": null,
    "avatar_url": null,
    "level": 8,
    "rarity": "epic",
    "card_kind": "normal",
    "fusion_only": false,
    "physical_scan_enabled": false,
    "virtual_key": null,
    "lore": "Ilusi api yang mengatur posisi untuk kombo Burn.",
    "metadata": {
      "timedoor_seed_key": "master_plan_v2_2:PIC-008",
      "source_card_code": "PIC-008",
      "seed_version": "2.2-learning-arcs-fusion",
      "source_document": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion.docx",
      "family_name": "Pico Cat",
      "variant_name": "Flare Illusion",
      "display_name": "Pico Cat — Flare Illusion",
      "learning_arc": "Creation",
      "lesson_topic": "SKILL LAB",
      "learning_mission": "Bangun game cerita interaktif dengan dua keputusan dan animasi Pico.",
      "skills": [
        {
          "name": "Cinder Chase",
          "effect": "Serangan normal +6 jika target punya Burn; CD 2.",
          "slot": 1
        },
        {
          "name": "Soot Screen",
          "effect": "Beri +4 DEF satu rekan hingga satu hit; CD 2.",
          "slot": 2
        }
      ],
      "fusion_tags": [],
      "catalog_status": "reference_data_pending_skill_playtest"
    },
    "card_code": "PIC_008",
    "tags": []
  },
  {
    "uid": null,
    "name": "Pico Cat — Phoenix Trickster",
    "element": "Fire",
    "hp": 148,
    "attack": 47,
    "defense": 16,
    "image_url": null,
    "avatar_url": null,
    "level": 9,
    "rarity": "legendary",
    "card_kind": "normal",
    "fusion_only": false,
    "physical_scan_enabled": false,
    "virtual_key": null,
    "lore": "Pengelabuan elit dengan batas penggunaan ketat.",
    "metadata": {
      "timedoor_seed_key": "master_plan_v2_2:PIC-009",
      "source_card_code": "PIC-009",
      "seed_version": "2.2-learning-arcs-fusion",
      "source_document": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion.docx",
      "family_name": "Pico Cat",
      "variant_name": "Phoenix Trickster",
      "display_name": "Pico Cat — Phoenix Trickster",
      "learning_arc": "Creation",
      "lesson_topic": "SKILL LAB",
      "learning_mission": "Uji cerita pada tiga teman; perbaiki instruksi yang membingungkan.",
      "skills": [
        {
          "name": "Phoenix Misdirect",
          "effect": "Sekali/battle, kurangi 12 damage hit berikutnya ke satu rekan.",
          "slot": 1
        },
        {
          "name": "Flare Feint",
          "effect": "Kurangi 8 damage hit berikutnya yang menarget rekan lain; CD 2.",
          "slot": 2
        }
      ],
      "fusion_tags": [],
      "catalog_status": "reference_data_pending_skill_playtest"
    },
    "card_code": "PIC_009",
    "tags": []
  },
  {
    "uid": null,
    "name": "Pico Cat — Starlight Ember",
    "element": "Fire",
    "hp": 160,
    "attack": 51,
    "defense": 18,
    "image_url": null,
    "avatar_url": null,
    "level": 10,
    "rarity": "mythic",
    "card_kind": "normal",
    "fusion_only": false,
    "physical_scan_enabled": false,
    "virtual_key": null,
    "lore": "Wujud puncak pemburu cepat yang mengandalkan timing.",
    "metadata": {
      "timedoor_seed_key": "master_plan_v2_2:PIC-010",
      "source_card_code": "PIC-010",
      "seed_version": "2.2-learning-arcs-fusion",
      "source_document": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion.docx",
      "family_name": "Pico Cat",
      "variant_name": "Starlight Ember",
      "display_name": "Pico Cat — Starlight Ember",
      "learning_arc": "Creation",
      "lesson_topic": "SKILL LAB",
      "learning_mission": "Demokan game, kalkulasi animasi, alur cerita, dan presentasi English.",
      "skills": [
        {
          "name": "Starlight Ember",
          "effect": "Sekali/battle, serangan normal +10 jika target Burn; konsumsi 1 stack.",
          "slot": 1
        },
        {
          "name": "Cinder Chase",
          "effect": "Serangan normal +6 jika target punya Burn; CD 2.",
          "slot": 2
        }
      ],
      "fusion_tags": [],
      "catalog_status": "reference_data_pending_skill_playtest"
    },
    "card_code": "PIC_010",
    "tags": []
  },
  {
    "uid": null,
    "name": "Circuit Grove Guardian",
    "element": "Fusion",
    "hp": 137,
    "attack": 37,
    "defense": 13,
    "image_url": null,
    "avatar_url": null,
    "level": 6,
    "rarity": "rare",
    "card_kind": "normal",
    "fusion_only": true,
    "physical_scan_enabled": false,
    "virtual_key": null,
    "lore": "Benteng sirkuit-hutan; memberi Shield pada satu rekan dan regen kecil, tanpa heal massal.",
    "metadata": {
      "timedoor_seed_key": "master_plan_v2_2:F01",
      "seed_version": "2.2-learning-arcs-fusion",
      "source_document": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion.docx",
      "fusion_id": "F01",
      "material_family": "Coby (Electric) + Tochi (Grass)",
      "fusion_level": 6,
      "fusion_concept": "Benteng sirkuit-hutan; memberi Shield pada satu rekan dan regen kecil, tanpa heal massal.",
      "education_theme": "Coding x English: event rally dan panduan penjagaan.",
      "catalog_status": "prototype_preview_pending_playtest",
      "prototype_stat_preview": true,
      "stat_formula_note": "Preview estimates from Appendix B/D; 2 slots: HP/ATK 1.15x mean and DEF 1.10x mean; 3 slots: 1.20x mean. No cap was provided in the source."
    },
    "card_code": "F01",
    "tags": [
      "timedoor_fusion",
      "f01"
    ]
  },
  {
    "uid": null,
    "name": "Tempest Flag Marshal",
    "element": "Fusion",
    "hp": 149,
    "attack": 45,
    "defense": 14,
    "image_url": null,
    "avatar_url": null,
    "level": 6,
    "rarity": "rare",
    "card_kind": "normal",
    "fusion_only": true,
    "physical_scan_enabled": false,
    "virtual_key": null,
    "lore": "Komandan angin-petir; serangan pembuka mendapat bonus jika rekan baru melakukan Switch.",
    "metadata": {
      "timedoor_seed_key": "master_plan_v2_2:F02",
      "seed_version": "2.2-learning-arcs-fusion",
      "source_document": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion.docx",
      "fusion_id": "F02",
      "material_family": "Coby (Electric) + Falcon (Wind)",
      "fusion_level": 6,
      "fusion_concept": "Komandan angin-petir; serangan pembuka mendapat bonus jika rekan baru melakukan Switch.",
      "education_theme": "Math x English: pilih rute/timing dan koordinasi.",
      "catalog_status": "prototype_preview_pending_playtest",
      "prototype_stat_preview": true,
      "stat_formula_note": "Preview estimates from Appendix B/D; 2 slots: HP/ATK 1.15x mean and DEF 1.10x mean; 3 slots: 1.20x mean. No cap was provided in the source."
    },
    "card_code": "F02",
    "tags": [
      "timedoor_fusion",
      "f02"
    ]
  },
  {
    "uid": null,
    "name": "Byte Sprout Hacker",
    "element": "Fusion",
    "hp": 142,
    "attack": 42,
    "defense": 13,
    "image_url": null,
    "avatar_url": null,
    "level": 6,
    "rarity": "rare",
    "card_kind": "normal",
    "fusion_only": true,
    "physical_scan_enabled": false,
    "virtual_key": null,
    "lore": "Perakit gesit; memasang Shield kecil lalu memperoleh damage bersyarat setelah Switch.",
    "metadata": {
      "timedoor_seed_key": "master_plan_v2_2:F03",
      "seed_version": "2.2-learning-arcs-fusion",
      "source_document": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion.docx",
      "fusion_id": "F03",
      "material_family": "Byte Fox (Wind) + Pixel Rabbit (Grass)",
      "fusion_level": 6,
      "fusion_concept": "Perakit gesit; memasang Shield kecil lalu memperoleh damage bersyarat setelah Switch.",
      "education_theme": "Coding x Skill Lab: algoritma obstacle dan perisai.",
      "catalog_status": "prototype_preview_pending_playtest",
      "prototype_stat_preview": true,
      "stat_formula_note": "Preview estimates from Appendix B/D; 2 slots: HP/ATK 1.15x mean and DEF 1.10x mean; 3 slots: 1.20x mean. No cap was provided in the source."
    },
    "card_code": "F03",
    "tags": [
      "timedoor_fusion",
      "f03"
    ]
  },
  {
    "uid": null,
    "name": "Eclipse Signal",
    "element": "Fusion",
    "hp": 146,
    "attack": 46,
    "defense": 13,
    "image_url": null,
    "avatar_url": null,
    "level": 8,
    "rarity": "epic",
    "card_kind": "normal",
    "fusion_only": true,
    "physical_scan_enabled": false,
    "virtual_key": null,
    "lore": "Sinyal gelap-petir; peluang Silence satu target, cooldown panjang, tanpa AoE.",
    "metadata": {
      "timedoor_seed_key": "master_plan_v2_2:F04",
      "seed_version": "2.2-learning-arcs-fusion",
      "source_document": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion.docx",
      "fusion_id": "F04",
      "material_family": "Null Cat (Dark) + Spark Panda (Electric)",
      "fusion_level": 8,
      "fusion_concept": "Sinyal gelap-petir; peluang Silence satu target, cooldown panjang, tanpa AoE.",
      "education_theme": "Coding x Math: validasi sinyal dan tabel logika.",
      "catalog_status": "prototype_preview_pending_playtest",
      "prototype_stat_preview": true,
      "stat_formula_note": "Preview estimates from Appendix B/D; 2 slots: HP/ATK 1.15x mean and DEF 1.10x mean; 3 slots: 1.20x mean. No cap was provided in the source."
    },
    "card_code": "F04",
    "tags": [
      "timedoor_fusion",
      "f04"
    ]
  },
  {
    "uid": null,
    "name": "Aqua Vector Sentinel",
    "element": "Fusion",
    "hp": 137,
    "attack": 41,
    "defense": 13,
    "image_url": null,
    "avatar_url": null,
    "level": 7,
    "rarity": "rare",
    "card_kind": "normal",
    "fusion_only": true,
    "physical_scan_enabled": false,
    "virtual_key": null,
    "lore": "Sentinel uap; pilih cleanse satu rekan ATAU aktifkan Mark satu target untuk kombo api.",
    "metadata": {
      "timedoor_seed_key": "master_plan_v2_2:F05",
      "seed_version": "2.2-learning-arcs-fusion",
      "source_document": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion.docx",
      "fusion_id": "F05",
      "material_family": "Script Otter (Water) + Vector Wolf (Fire)",
      "fusion_level": 7,
      "fusion_concept": "Sentinel uap; pilih cleanse satu rekan ATAU aktifkan Mark satu target untuk kombo api.",
      "education_theme": "English x Coding: instruksi kontrol dan trigger Fire.",
      "catalog_status": "prototype_preview_pending_playtest",
      "prototype_stat_preview": true,
      "stat_formula_note": "Preview estimates from Appendix B/D; 2 slots: HP/ATK 1.15x mean and DEF 1.10x mean; 3 slots: 1.20x mean. No cap was provided in the source."
    },
    "card_code": "F05",
    "tags": [
      "timedoor_fusion",
      "f05"
    ]
  },
  {
    "uid": null,
    "name": "Steam Fortress",
    "element": "Fusion",
    "hp": 143,
    "attack": 41,
    "defense": 13,
    "image_url": null,
    "avatar_url": null,
    "level": 7,
    "rarity": "rare",
    "card_kind": "normal",
    "fusion_only": true,
    "physical_scan_enabled": false,
    "virtual_key": null,
    "lore": "Benteng uap; Guard dan serangan api kecil, Burn tetap mematuhi stack global.",
    "metadata": {
      "timedoor_seed_key": "master_plan_v2_2:F06",
      "seed_version": "2.2-learning-arcs-fusion",
      "source_document": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion.docx",
      "fusion_id": "F06",
      "material_family": "Cache Turtle (Water) + Pico Cat (Fire)",
      "fusion_level": 7,
      "fusion_concept": "Benteng uap; Guard dan serangan api kecil, Burn tetap mematuhi stack global.",
      "education_theme": "Math x English: kapasitas guard dan aba-aba tim.",
      "catalog_status": "prototype_preview_pending_playtest",
      "prototype_stat_preview": true,
      "stat_formula_note": "Preview estimates from Appendix B/D; 2 slots: HP/ATK 1.15x mean and DEF 1.10x mean; 3 slots: 1.20x mean. No cap was provided in the source."
    },
    "card_code": "F06",
    "tags": [
      "timedoor_fusion",
      "f06"
    ]
  },
  {
    "uid": null,
    "name": "Skybyte Runner",
    "element": "Fusion",
    "hp": 128,
    "attack": 43,
    "defense": 11,
    "image_url": null,
    "avatar_url": null,
    "level": 6,
    "rarity": "rare",
    "card_kind": "normal",
    "fusion_only": true,
    "physical_scan_enabled": false,
    "virtual_key": null,
    "lore": "Pengendali Switch; menukar posisi untuk membuka serangan, dengan HP rendah.",
    "metadata": {
      "timedoor_seed_key": "master_plan_v2_2:F07",
      "seed_version": "2.2-learning-arcs-fusion",
      "source_document": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion.docx",
      "fusion_id": "F07",
      "material_family": "Falcon (Wind) + Byte Fox (Wind)",
      "fusion_level": 6,
      "fusion_concept": "Pengendali Switch; menukar posisi untuk membuka serangan, dengan HP rendah.",
      "education_theme": "English x English: komunikasi navigasi dan rotasi.",
      "catalog_status": "prototype_preview_pending_playtest",
      "prototype_stat_preview": true,
      "stat_formula_note": "Preview estimates from Appendix B/D; 2 slots: HP/ATK 1.15x mean and DEF 1.10x mean; 3 slots: 1.20x mean. No cap was provided in the source."
    },
    "card_code": "F07",
    "tags": [
      "timedoor_fusion",
      "f07"
    ]
  },
  {
    "uid": null,
    "name": "Phantom Bloom",
    "element": "Fusion",
    "hp": 139,
    "attack": 40,
    "defense": 13,
    "image_url": null,
    "avatar_url": null,
    "level": 8,
    "rarity": "epic",
    "card_kind": "normal",
    "fusion_only": true,
    "physical_scan_enabled": false,
    "virtual_key": null,
    "lore": "Ilusi akar; Root singkat atau debuff ringan bergantian, tidak keduanya sekaligus.",
    "metadata": {
      "timedoor_seed_key": "master_plan_v2_2:F08",
      "seed_version": "2.2-learning-arcs-fusion",
      "source_document": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion.docx",
      "fusion_id": "F08",
      "material_family": "Null Cat (Dark) + Tochi (Grass)",
      "fusion_level": 8,
      "fusion_concept": "Ilusi akar; Root singkat atau debuff ringan bergantian, tidak keduanya sekaligus.",
      "education_theme": "Coding x Math: logika kondisi dan pola akar.",
      "catalog_status": "prototype_preview_pending_playtest",
      "prototype_stat_preview": true,
      "stat_formula_note": "Preview estimates from Appendix B/D; 2 slots: HP/ATK 1.15x mean and DEF 1.10x mean; 3 slots: 1.20x mean. No cap was provided in the source."
    },
    "card_code": "F08",
    "tags": [
      "timedoor_fusion",
      "f08"
    ]
  },
  {
    "uid": null,
    "name": "Hydro Cache Engine",
    "element": "Fusion",
    "hp": 147,
    "attack": 38,
    "defense": 14,
    "image_url": null,
    "avatar_url": null,
    "level": 7,
    "rarity": "rare",
    "card_kind": "normal",
    "fusion_only": true,
    "physical_scan_enabled": false,
    "virtual_key": null,
    "lore": "Mesin air; pilih heal tunggal atau Shield; tidak melakukan double heal.",
    "metadata": {
      "timedoor_seed_key": "master_plan_v2_2:F09",
      "seed_version": "2.2-learning-arcs-fusion",
      "source_document": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion.docx",
      "fusion_id": "F09",
      "material_family": "Script Otter (Water) + Cache Turtle (Water)",
      "fusion_level": 7,
      "fusion_concept": "Mesin air; pilih heal tunggal atau Shield; tidak melakukan double heal.",
      "education_theme": "Water Data x Math: pilih heal atau shield, bukan keduanya.",
      "catalog_status": "prototype_preview_pending_playtest",
      "prototype_stat_preview": true,
      "stat_formula_note": "Preview estimates from Appendix B/D; 2 slots: HP/ATK 1.15x mean and DEF 1.10x mean; 3 slots: 1.20x mean. No cap was provided in the source."
    },
    "card_code": "F09",
    "tags": [
      "timedoor_fusion",
      "f09"
    ]
  },
  {
    "uid": null,
    "name": "Pixel Ember Pack",
    "element": "Fusion",
    "hp": 151,
    "attack": 43,
    "defense": 15,
    "image_url": null,
    "avatar_url": null,
    "level": 7,
    "rarity": "rare",
    "card_kind": "normal",
    "fusion_only": true,
    "physical_scan_enabled": false,
    "virtual_key": null,
    "lore": "Perisai api; perlindungan satu rekan dan Mark satu target, bukan buff ganda.",
    "metadata": {
      "timedoor_seed_key": "master_plan_v2_2:F10",
      "seed_version": "2.2-learning-arcs-fusion",
      "source_document": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion.docx",
      "fusion_id": "F10",
      "material_family": "Pixel Rabbit (Grass) + Vector Wolf (Fire)",
      "fusion_level": 7,
      "fusion_concept": "Perisai api; perlindungan satu rekan dan Mark satu target, bukan buff ganda.",
      "education_theme": "English x English: koordinasi formasi dan kontrol api.",
      "catalog_status": "prototype_preview_pending_playtest",
      "prototype_stat_preview": true,
      "stat_formula_note": "Preview estimates from Appendix B/D; 2 slots: HP/ATK 1.15x mean and DEF 1.10x mean; 3 slots: 1.20x mean. No cap was provided in the source."
    },
    "card_code": "F10",
    "tags": [
      "timedoor_fusion",
      "f10"
    ]
  },
  {
    "uid": null,
    "name": "Spirit Current",
    "element": "Fusion",
    "hp": 143,
    "attack": 42,
    "defense": 13,
    "image_url": null,
    "avatar_url": null,
    "level": 7,
    "rarity": "rare",
    "card_kind": "normal",
    "fusion_only": true,
    "physical_scan_enabled": false,
    "virtual_key": null,
    "lore": "Arus api-air; memilih timing Burn atau cleanse, tidak menambah extra action.",
    "metadata": {
      "timedoor_seed_key": "master_plan_v2_2:F11",
      "seed_version": "2.2-learning-arcs-fusion",
      "source_document": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion.docx",
      "fusion_id": "F11",
      "material_family": "Pico Cat (Fire) + Script Otter (Water)",
      "fusion_level": 7,
      "fusion_concept": "Arus api-air; memilih timing Burn atau cleanse, tidak menambah extra action.",
      "education_theme": "English x Coding: timing api dan validasi cleanse.",
      "catalog_status": "prototype_preview_pending_playtest",
      "prototype_stat_preview": true,
      "stat_formula_note": "Preview estimates from Appendix B/D; 2 slots: HP/ATK 1.15x mean and DEF 1.10x mean; 3 slots: 1.20x mean. No cap was provided in the source."
    },
    "card_code": "F11",
    "tags": [
      "timedoor_fusion",
      "f11"
    ]
  },
  {
    "uid": null,
    "name": "Academy Nexus",
    "element": "Fusion",
    "hp": 168,
    "attack": 47,
    "defense": 17,
    "image_url": null,
    "avatar_url": null,
    "level": 9,
    "rarity": "legendary",
    "card_kind": "normal",
    "fusion_only": true,
    "physical_scan_enabled": false,
    "virtual_key": null,
    "lore": "Tiga pilar dukungan; sekali per battle pilih satu buff kecil tim, tanpa AoE heal berlebihan.",
    "metadata": {
      "timedoor_seed_key": "master_plan_v2_2:F12",
      "seed_version": "2.2-learning-arcs-fusion",
      "source_document": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion.docx",
      "fusion_id": "F12",
      "material_family": "Coby (Electric) + Tochi (Grass) + Script Otter (Water)",
      "fusion_level": 9,
      "fusion_concept": "Tiga pilar dukungan; sekali per battle pilih satu buff kecil tim, tanpa AoE heal berlebihan.",
      "education_theme": "Skill Lab x3: prototipe tim lintas kemampuan.",
      "catalog_status": "prototype_preview_pending_playtest",
      "prototype_stat_preview": true,
      "stat_formula_note": "Preview estimates from Appendix B/D; 2 slots: HP/ATK 1.15x mean and DEF 1.10x mean; 3 slots: 1.20x mean. No cap was provided in the source."
    },
    "card_code": "F12",
    "tags": [
      "timedoor_fusion",
      "f12"
    ]
  },
  {
    "uid": null,
    "name": "Solar Circuit",
    "element": "Fusion",
    "hp": 154,
    "attack": 50,
    "defense": 14,
    "image_url": null,
    "avatar_url": null,
    "level": 8,
    "rarity": "epic",
    "card_kind": "normal",
    "fusion_only": true,
    "physical_scan_enabled": false,
    "virtual_key": null,
    "lore": "Kombo ledakan terkendali; bonus Electric pada target Burn dengan cooldown panjang.",
    "metadata": {
      "timedoor_seed_key": "master_plan_v2_2:F13",
      "seed_version": "2.2-learning-arcs-fusion",
      "source_document": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion.docx",
      "fusion_id": "F13",
      "material_family": "Spark Panda (Electric) + Pico Cat (Fire)",
      "fusion_level": 8,
      "fusion_concept": "Kombo ledakan terkendali; bonus Electric pada target Burn dengan cooldown panjang.",
      "education_theme": "Skill Lab: interaksi LED dan game cerita.",
      "catalog_status": "prototype_preview_pending_playtest",
      "prototype_stat_preview": true,
      "stat_formula_note": "Preview estimates from Appendix B/D; 2 slots: HP/ATK 1.15x mean and DEF 1.10x mean; 3 slots: 1.20x mean. No cap was provided in the source."
    },
    "card_code": "F13",
    "tags": [
      "timedoor_fusion",
      "f13"
    ]
  },
  {
    "uid": null,
    "name": "Windleaf Scout",
    "element": "Fusion",
    "hp": 154,
    "attack": 45,
    "defense": 15,
    "image_url": null,
    "avatar_url": null,
    "level": 8,
    "rarity": "epic",
    "card_kind": "normal",
    "fusion_only": true,
    "physical_scan_enabled": false,
    "virtual_key": null,
    "lore": "Pengintai daun-angin; Switch aman atau Root singkat, pilih satu.",
    "metadata": {
      "timedoor_seed_key": "master_plan_v2_2:F14",
      "seed_version": "2.2-learning-arcs-fusion",
      "source_document": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion.docx",
      "fusion_id": "F14",
      "material_family": "Falcon (Wind) + Tochi (Grass)",
      "fusion_level": 8,
      "fusion_concept": "Pengintai daun-angin; Switch aman atau Root singkat, pilih satu.",
      "education_theme": "English x Skill Lab: navigasi rute hijau.",
      "catalog_status": "prototype_preview_pending_playtest",
      "prototype_stat_preview": true,
      "stat_formula_note": "Preview estimates from Appendix B/D; 2 slots: HP/ATK 1.15x mean and DEF 1.10x mean; 3 slots: 1.20x mean. No cap was provided in the source."
    },
    "card_code": "F14",
    "tags": [
      "timedoor_fusion",
      "f14"
    ]
  },
  {
    "uid": null,
    "name": "Digital Tidal Fox",
    "element": "Fusion",
    "hp": 150,
    "attack": 45,
    "defense": 14,
    "image_url": null,
    "avatar_url": null,
    "level": 8,
    "rarity": "epic",
    "card_kind": "normal",
    "fusion_only": true,
    "physical_scan_enabled": false,
    "virtual_key": null,
    "lore": "Rubah arus; setelah Switch pilih serangan cepat atau cleanse pendamping.",
    "metadata": {
      "timedoor_seed_key": "master_plan_v2_2:F15",
      "seed_version": "2.2-learning-arcs-fusion",
      "source_document": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion.docx",
      "fusion_id": "F15",
      "material_family": "Byte Fox (Wind) + Script Otter (Water)",
      "fusion_level": 8,
      "fusion_concept": "Rubah arus; setelah Switch pilih serangan cepat atau cleanse pendamping.",
      "education_theme": "English x Skill Lab: optimasi dashboard bergerak.",
      "catalog_status": "prototype_preview_pending_playtest",
      "prototype_stat_preview": true,
      "stat_formula_note": "Preview estimates from Appendix B/D; 2 slots: HP/ATK 1.15x mean and DEF 1.10x mean; 3 slots: 1.20x mean. No cap was provided in the source."
    },
    "card_code": "F15",
    "tags": [
      "timedoor_fusion",
      "f15"
    ]
  },
  {
    "uid": null,
    "name": "Abyssal Shadow Sentinel",
    "element": "Fusion",
    "hp": 164,
    "attack": 46,
    "defense": 16,
    "image_url": null,
    "avatar_url": null,
    "level": 8,
    "rarity": "epic",
    "card_kind": "normal",
    "fusion_only": true,
    "physical_scan_enabled": false,
    "virtual_key": null,
    "lore": "Penjaga jurang; Shield air plus debuff Dark terbatas, tidak menghidupkan kartu tanpa biaya.",
    "metadata": {
      "timedoor_seed_key": "master_plan_v2_2:F16",
      "seed_version": "2.2-learning-arcs-fusion",
      "source_document": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion.docx",
      "fusion_id": "F16",
      "material_family": "Null Cat (Dark) + Cache Turtle (Water)",
      "fusion_level": 8,
      "fusion_concept": "Penjaga jurang; Shield air plus debuff Dark terbatas, tidak menghidupkan kartu tanpa biaya.",
      "education_theme": "Skill Lab: simulasi backup dan perlindungan data.",
      "catalog_status": "prototype_preview_pending_playtest",
      "prototype_stat_preview": true,
      "stat_formula_note": "Preview estimates from Appendix B/D; 2 slots: HP/ATK 1.15x mean and DEF 1.10x mean; 3 slots: 1.20x mean. No cap was provided in the source."
    },
    "card_code": "F16",
    "tags": [
      "timedoor_fusion",
      "f16"
    ]
  },
  {
    "uid": null,
    "name": "Thunder Canopy",
    "element": "Fusion",
    "hp": 162,
    "attack": 47,
    "defense": 15,
    "image_url": null,
    "avatar_url": null,
    "level": 8,
    "rarity": "epic",
    "card_kind": "normal",
    "fusion_only": true,
    "physical_scan_enabled": false,
    "virtual_key": null,
    "lore": "Kanopi listrik; perlindungan rekan menyiapkan chain hit yang dibatasi target.",
    "metadata": {
      "timedoor_seed_key": "master_plan_v2_2:F17",
      "seed_version": "2.2-learning-arcs-fusion",
      "source_document": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion.docx",
      "fusion_id": "F17",
      "material_family": "Spark Panda (Electric) + Pixel Rabbit (Grass)",
      "fusion_level": 8,
      "fusion_concept": "Kanopi listrik; perlindungan rekan menyiapkan chain hit yang dibatasi target.",
      "education_theme": "Skill Lab: sensor dan benteng responsif.",
      "catalog_status": "prototype_preview_pending_playtest",
      "prototype_stat_preview": true,
      "stat_formula_note": "Preview estimates from Appendix B/D; 2 slots: HP/ATK 1.15x mean and DEF 1.10x mean; 3 slots: 1.20x mean. No cap was provided in the source."
    },
    "card_code": "F17",
    "tags": [
      "timedoor_fusion",
      "f17"
    ]
  },
  {
    "uid": null,
    "name": "Coded Eclipse",
    "element": "Fusion",
    "hp": 161,
    "attack": 51,
    "defense": 16,
    "image_url": null,
    "avatar_url": null,
    "level": 9,
    "rarity": "legendary",
    "card_kind": "normal",
    "fusion_only": true,
    "physical_scan_enabled": false,
    "virtual_key": null,
    "lore": "Gerhana bara; tanda target memicu serangan api dan satu debuff non-AoE.",
    "metadata": {
      "timedoor_seed_key": "master_plan_v2_2:F18",
      "seed_version": "2.2-learning-arcs-fusion",
      "source_document": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion.docx",
      "fusion_id": "F18",
      "material_family": "Vector Wolf (Fire) + Null Cat (Dark)",
      "fusion_level": 9,
      "fusion_concept": "Gerhana bara; tanda target memicu serangan api dan satu debuff non-AoE.",
      "education_theme": "Skill Lab: simulasi status dan prosedur recovery.",
      "catalog_status": "prototype_preview_pending_playtest",
      "prototype_stat_preview": true,
      "stat_formula_note": "Preview estimates from Appendix B/D; 2 slots: HP/ATK 1.15x mean and DEF 1.10x mean; 3 slots: 1.20x mean. No cap was provided in the source."
    },
    "card_code": "F18",
    "tags": [
      "timedoor_fusion",
      "f18"
    ]
  },
  {
    "uid": null,
    "name": "Arc Guard",
    "element": "Fusion",
    "hp": 163,
    "attack": 43,
    "defense": 16,
    "image_url": null,
    "avatar_url": null,
    "level": 8,
    "rarity": "epic",
    "card_kind": "normal",
    "fusion_only": true,
    "physical_scan_enabled": false,
    "virtual_key": null,
    "lore": "Perisai konduktor; tahan satu pukulan dan bantu tempo tim tanpa draw gratis.",
    "metadata": {
      "timedoor_seed_key": "master_plan_v2_2:F19",
      "seed_version": "2.2-learning-arcs-fusion",
      "source_document": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion.docx",
      "fusion_id": "F19",
      "material_family": "Coby (Electric) + Cache Turtle (Water)",
      "fusion_level": 8,
      "fusion_concept": "Perisai konduktor; tahan satu pukulan dan bantu tempo tim tanpa draw gratis.",
      "education_theme": "English x Skill Lab: command center dan guard.",
      "catalog_status": "prototype_preview_pending_playtest",
      "prototype_stat_preview": true,
      "stat_formula_note": "Preview estimates from Appendix B/D; 2 slots: HP/ATK 1.15x mean and DEF 1.10x mean; 3 slots: 1.20x mean. No cap was provided in the source."
    },
    "card_code": "F19",
    "tags": [
      "timedoor_fusion",
      "f19"
    ]
  },
  {
    "uid": null,
    "name": "Rabbit Afterimage",
    "element": "Fusion",
    "hp": 157,
    "attack": 46,
    "defense": 15,
    "image_url": null,
    "avatar_url": null,
    "level": 8,
    "rarity": "epic",
    "card_kind": "normal",
    "fusion_only": true,
    "physical_scan_enabled": false,
    "virtual_key": null,
    "lore": "Bayangan pembangun; Shield kecil serta bonus dash bersyarat.",
    "metadata": {
      "timedoor_seed_key": "master_plan_v2_2:F20",
      "seed_version": "2.2-learning-arcs-fusion",
      "source_document": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion.docx",
      "fusion_id": "F20",
      "material_family": "Pixel Rabbit (Grass) + Byte Fox (Wind)",
      "fusion_level": 8,
      "fusion_concept": "Bayangan pembangun; Shield kecil serta bonus dash bersyarat.",
      "education_theme": "Skill Lab: visualisasi obstacle dengan perlindungan.",
      "catalog_status": "prototype_preview_pending_playtest",
      "prototype_stat_preview": true,
      "stat_formula_note": "Preview estimates from Appendix B/D; 2 slots: HP/ATK 1.15x mean and DEF 1.10x mean; 3 slots: 1.20x mean. No cap was provided in the source."
    },
    "card_code": "F20",
    "tags": [
      "timedoor_fusion",
      "f20"
    ]
  },
  {
    "uid": null,
    "name": "Skyline Guardian",
    "element": "Fusion",
    "hp": 155,
    "attack": 50,
    "defense": 15,
    "image_url": null,
    "avatar_url": null,
    "level": 8,
    "rarity": "epic",
    "card_kind": "normal",
    "fusion_only": true,
    "physical_scan_enabled": false,
    "virtual_key": null,
    "lore": "Pemburu langit api; serangan setelah Switch dan Burn normal yang tidak menumpuk gratis.",
    "metadata": {
      "timedoor_seed_key": "master_plan_v2_2:F21",
      "seed_version": "2.2-learning-arcs-fusion",
      "source_document": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion.docx",
      "fusion_id": "F21",
      "material_family": "Falcon (Wind) + Vector Wolf (Fire)",
      "fusion_level": 8,
      "fusion_concept": "Pemburu langit api; serangan setelah Switch dan Burn normal yang tidak menumpuk gratis.",
      "education_theme": "Skill Lab: simulasi navigasi dan cooldown api.",
      "catalog_status": "prototype_preview_pending_playtest",
      "prototype_stat_preview": true,
      "stat_formula_note": "Preview estimates from Appendix B/D; 2 slots: HP/ATK 1.15x mean and DEF 1.10x mean; 3 slots: 1.20x mean. No cap was provided in the source."
    },
    "card_code": "F21",
    "tags": [
      "timedoor_fusion",
      "f21"
    ]
  },
  {
    "uid": null,
    "name": "Pico Overclock",
    "element": "Fusion",
    "hp": 154,
    "attack": 50,
    "defense": 14,
    "image_url": null,
    "avatar_url": null,
    "level": 8,
    "rarity": "epic",
    "card_kind": "normal",
    "fusion_only": true,
    "physical_scan_enabled": false,
    "virtual_key": null,
    "lore": "Overclock gerak; serangan listrik-api kuat jika target sudah Burn, CD 3.",
    "metadata": {
      "timedoor_seed_key": "master_plan_v2_2:F22",
      "seed_version": "2.2-learning-arcs-fusion",
      "source_document": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion.docx",
      "fusion_id": "F22",
      "material_family": "Pico Cat (Fire) + Spark Panda (Electric)",
      "fusion_level": 8,
      "fusion_concept": "Overclock gerak; serangan listrik-api kuat jika target sudah Burn, CD 3.",
      "education_theme": "Skill Lab: kontrol LED dan animasi responsif.",
      "catalog_status": "prototype_preview_pending_playtest",
      "prototype_stat_preview": true,
      "stat_formula_note": "Preview estimates from Appendix B/D; 2 slots: HP/ATK 1.15x mean and DEF 1.10x mean; 3 slots: 1.20x mean. No cap was provided in the source."
    },
    "card_code": "F22",
    "tags": [
      "timedoor_fusion",
      "f22"
    ]
  },
  {
    "uid": null,
    "name": "Revival Circuit",
    "element": "Fusion",
    "hp": 159,
    "attack": 47,
    "defense": 15,
    "image_url": null,
    "avatar_url": null,
    "level": 9,
    "rarity": "legendary",
    "card_kind": "normal",
    "fusion_only": true,
    "physical_scan_enabled": false,
    "virtual_key": null,
    "lore": "Fusion necromancer; sacrifice atau bahan Graveyard legal dan 1 revive pada 50% HP, 1×/battle.",
    "metadata": {
      "timedoor_seed_key": "master_plan_v2_2:F23",
      "seed_version": "2.2-learning-arcs-fusion",
      "source_document": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion.docx",
      "fusion_id": "F23",
      "material_family": "Null Cat (Dark) + Script Otter (Water)",
      "fusion_level": 9,
      "fusion_concept": "Fusion necromancer; sacrifice atau bahan Graveyard legal dan 1 revive pada 50% HP, 1×/battle.",
      "education_theme": "Skill Lab: konsep snapshot/recovery; 1 revive legal.",
      "catalog_status": "prototype_preview_pending_playtest",
      "prototype_stat_preview": true,
      "stat_formula_note": "Preview estimates from Appendix B/D; 2 slots: HP/ATK 1.15x mean and DEF 1.10x mean; 3 slots: 1.20x mean. No cap was provided in the source."
    },
    "card_code": "F23",
    "tags": [
      "timedoor_fusion",
      "f23"
    ]
  },
  {
    "uid": null,
    "name": "Grand Academy Union",
    "element": "Fusion",
    "hp": 164,
    "attack": 50,
    "defense": 16,
    "image_url": null,
    "avatar_url": null,
    "level": 10,
    "rarity": "mythic",
    "card_kind": "normal",
    "fusion_only": true,
    "physical_scan_enabled": false,
    "virtual_key": null,
    "lore": "Tiga keluarga kerja sama; sekali/battle pilih utility tim, bukan tiga skill sekaligus.",
    "metadata": {
      "timedoor_seed_key": "master_plan_v2_2:F24",
      "seed_version": "2.2-learning-arcs-fusion",
      "source_document": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion.docx",
      "fusion_id": "F24",
      "material_family": "1 Coby/Tochi + 1 Falcon/Byte Fox + 1 Script Otter/Spark Panda",
      "fusion_level": 10,
      "fusion_concept": "Tiga keluarga kerja sama; sekali/battle pilih utility tim, bukan tiga skill sekaligus.",
      "education_theme": "Skill Lab capstone: koding, data matematika, dan presentasi English.",
      "catalog_status": "prototype_preview_pending_playtest",
      "prototype_stat_preview": true,
      "stat_formula_note": "Preview estimates from Appendix B/D; 2 slots: HP/ATK 1.15x mean and DEF 1.10x mean; 3 slots: 1.20x mean. No cap was provided in the source."
    },
    "card_code": "F24",
    "tags": [
      "timedoor_fusion",
      "f24"
    ]
  }
]$timedoor_cards$::jsonb) AS s(
    uid text, name text, element text, hp integer, attack integer, defense integer,
    image_url text, avatar_url text, level integer, rarity text, card_kind text,
    fusion_only boolean, physical_scan_enabled boolean, virtual_key text,
    lore text, metadata jsonb, card_code text, tags text[]
  )
)
INSERT INTO public.game_cards (
  uid, name, element, hp, attack, defense, image_url, avatar_url, level, rarity,
  card_kind, fusion_only, physical_scan_enabled, virtual_key, lore, metadata,
  card_code, tags
)
SELECT
  uid, name, element, hp, attack, defense, image_url, avatar_url, level, rarity,
  card_kind, fusion_only, physical_scan_enabled, virtual_key, lore, metadata,
  card_code, tags
FROM seed_rows
ON CONFLICT ((metadata ->> 'timedoor_seed_key'))
  WHERE (metadata ->> 'timedoor_seed_key') IS NOT NULL
DO UPDATE SET
  name = EXCLUDED.name,
  element = EXCLUDED.element,
  hp = EXCLUDED.hp,
  attack = EXCLUDED.attack,
  defense = EXCLUDED.defense,
  image_url = coalesce(EXCLUDED.image_url, public.game_cards.image_url),
  avatar_url = coalesce(EXCLUDED.avatar_url, public.game_cards.avatar_url),
  level = EXCLUDED.level,
  rarity = EXCLUDED.rarity,
  card_kind = EXCLUDED.card_kind,
  fusion_only = EXCLUDED.fusion_only,
  physical_scan_enabled = EXCLUDED.physical_scan_enabled,
  lore = EXCLUDED.lore,
  metadata = public.game_cards.metadata || EXCLUDED.metadata,
  card_code = EXCLUDED.card_code,
  tags = ARRAY(
    SELECT DISTINCT tag_value
    FROM unnest(public.game_cards.tags || EXCLUDED.tags) AS tag_rows(tag_value)
    ORDER BY tag_value
  );

WITH recipe_seed AS (
  SELECT *
  FROM jsonb_to_recordset($timedoor_recipes$[
  {
    "code": "timedoor_f01_circuit_grove_guardian",
    "name": "Circuit Grove Guardian",
    "description": "Benteng sirkuit-hutan; memberi Shield pada satu rekan dan regen kecil, tanpa heal massal.",
    "icon": "🧬",
    "result_card_key": "master_plan_v2_2:F01",
    "result_zone": "active",
    "material_destination": "graveyard",
    "min_materials": 2,
    "max_materials": 2,
    "requirements": {},
    "result_overrides": {},
    "consumes_turn": true,
    "is_active": false,
    "cost_spec": {
      "type": "none",
      "value": 0
    },
    "limits": {
      "once_per_battle": true,
      "max_uses": 1
    },
    "conditions": {},
    "result_stat_spec": {
      "hp": {
        "mode": "material_sum_percent",
        "value": 0.575
      },
      "attack": {
        "mode": "material_sum_percent",
        "value": 0.575
      },
      "defense": {
        "mode": "material_sum_percent",
        "value": 0.55
      }
    },
    "priority": 50,
    "metadata": {
      "timedoor_seed_source": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion",
      "seed_version": "2.2-learning-arcs-fusion",
      "fusion_id": "F01",
      "education_theme": "Coding x English: event rally dan panduan penjagaan.",
      "source_material_expression": "COB-006 + TOC-006",
      "source_legal_zones": [
        "active",
        "bench",
        "hand"
      ],
      "requires_at_least_one_field_material": true,
      "playtest_status": "pending",
      "stat_cap_pending": true
    }
  },
  {
    "code": "timedoor_f02_tempest_flag_marshal",
    "name": "Tempest Flag Marshal",
    "description": "Komandan angin-petir; serangan pembuka mendapat bonus jika rekan baru melakukan Switch.",
    "icon": "🧬",
    "result_card_key": "master_plan_v2_2:F02",
    "result_zone": "active",
    "material_destination": "graveyard",
    "min_materials": 2,
    "max_materials": 2,
    "requirements": {},
    "result_overrides": {},
    "consumes_turn": true,
    "is_active": false,
    "cost_spec": {
      "type": "none",
      "value": 0
    },
    "limits": {
      "once_per_battle": true,
      "max_uses": 1
    },
    "conditions": {},
    "result_stat_spec": {
      "hp": {
        "mode": "material_sum_percent",
        "value": 0.575
      },
      "attack": {
        "mode": "material_sum_percent",
        "value": 0.575
      },
      "defense": {
        "mode": "material_sum_percent",
        "value": 0.55
      }
    },
    "priority": 50,
    "metadata": {
      "timedoor_seed_source": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion",
      "seed_version": "2.2-learning-arcs-fusion",
      "fusion_id": "F02",
      "education_theme": "Math x English: pilih rute/timing dan koordinasi.",
      "source_material_expression": "1 dari [COB-007, COB-008] + FAL-007",
      "source_legal_zones": [
        "active",
        "bench",
        "hand"
      ],
      "requires_at_least_one_field_material": true,
      "playtest_status": "pending",
      "stat_cap_pending": true
    }
  },
  {
    "code": "timedoor_f03_byte_sprout_hacker",
    "name": "Byte Sprout Hacker",
    "description": "Perakit gesit; memasang Shield kecil lalu memperoleh damage bersyarat setelah Switch.",
    "icon": "🧬",
    "result_card_key": "master_plan_v2_2:F03",
    "result_zone": "active",
    "material_destination": "graveyard",
    "min_materials": 2,
    "max_materials": 2,
    "requirements": {},
    "result_overrides": {},
    "consumes_turn": true,
    "is_active": false,
    "cost_spec": {
      "type": "none",
      "value": 0
    },
    "limits": {
      "once_per_battle": true,
      "max_uses": 1
    },
    "conditions": {},
    "result_stat_spec": {
      "hp": {
        "mode": "material_sum_percent",
        "value": 0.575
      },
      "attack": {
        "mode": "material_sum_percent",
        "value": 0.575
      },
      "defense": {
        "mode": "material_sum_percent",
        "value": 0.55
      }
    },
    "priority": 50,
    "metadata": {
      "timedoor_seed_source": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion",
      "seed_version": "2.2-learning-arcs-fusion",
      "fusion_id": "F03",
      "education_theme": "Coding x Skill Lab: algoritma obstacle dan perisai.",
      "source_material_expression": "fusion:AGILE_CODE (FOX-006/007) + fusion:BUILD_SHIELD (RAB-006/007)",
      "source_legal_zones": [
        "active",
        "bench",
        "hand"
      ],
      "requires_at_least_one_field_material": true,
      "playtest_status": "pending",
      "stat_cap_pending": true
    }
  },
  {
    "code": "timedoor_f04_eclipse_signal",
    "name": "Eclipse Signal",
    "description": "Sinyal gelap-petir; peluang Silence satu target, cooldown panjang, tanpa AoE.",
    "icon": "🧬",
    "result_card_key": "master_plan_v2_2:F04",
    "result_zone": "active",
    "material_destination": "graveyard",
    "min_materials": 2,
    "max_materials": 2,
    "requirements": {},
    "result_overrides": {},
    "consumes_turn": true,
    "is_active": false,
    "cost_spec": {
      "type": "none",
      "value": 0
    },
    "limits": {
      "once_per_battle": true,
      "max_uses": 1
    },
    "conditions": {},
    "result_stat_spec": {
      "hp": {
        "mode": "material_sum_percent",
        "value": 0.575
      },
      "attack": {
        "mode": "material_sum_percent",
        "value": 0.575
      },
      "defense": {
        "mode": "material_sum_percent",
        "value": 0.55
      }
    },
    "priority": 50,
    "metadata": {
      "timedoor_seed_source": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion",
      "seed_version": "2.2-learning-arcs-fusion",
      "fusion_id": "F04",
      "education_theme": "Coding x Math: validasi sinyal dan tabel logika.",
      "source_material_expression": "NUL-007 + PAN-007",
      "source_legal_zones": [
        "active",
        "bench",
        "hand"
      ],
      "requires_at_least_one_field_material": true,
      "playtest_status": "pending",
      "stat_cap_pending": true
    }
  },
  {
    "code": "timedoor_f05_aqua_vector_sentinel",
    "name": "Aqua Vector Sentinel",
    "description": "Sentinel uap; pilih cleanse satu rekan ATAU aktifkan Mark satu target untuk kombo api.",
    "icon": "🧬",
    "result_card_key": "master_plan_v2_2:F05",
    "result_zone": "active",
    "material_destination": "graveyard",
    "min_materials": 2,
    "max_materials": 2,
    "requirements": {},
    "result_overrides": {},
    "consumes_turn": true,
    "is_active": false,
    "cost_spec": {
      "type": "none",
      "value": 0
    },
    "limits": {
      "once_per_battle": true,
      "max_uses": 1
    },
    "conditions": {},
    "result_stat_spec": {
      "hp": {
        "mode": "material_sum_percent",
        "value": 0.575
      },
      "attack": {
        "mode": "material_sum_percent",
        "value": 0.575
      },
      "defense": {
        "mode": "material_sum_percent",
        "value": 0.55
      }
    },
    "priority": 50,
    "metadata": {
      "timedoor_seed_source": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion",
      "seed_version": "2.2-learning-arcs-fusion",
      "fusion_id": "F05",
      "education_theme": "English x Coding: instruksi kontrol dan trigger Fire.",
      "source_material_expression": "1 dari [OTT-006, OTT-007] + WLF-006",
      "source_legal_zones": [
        "active",
        "bench",
        "hand"
      ],
      "requires_at_least_one_field_material": true,
      "playtest_status": "pending",
      "stat_cap_pending": true
    }
  },
  {
    "code": "timedoor_f06_steam_fortress",
    "name": "Steam Fortress",
    "description": "Benteng uap; Guard dan serangan api kecil, Burn tetap mematuhi stack global.",
    "icon": "🧬",
    "result_card_key": "master_plan_v2_2:F06",
    "result_zone": "active",
    "material_destination": "graveyard",
    "min_materials": 2,
    "max_materials": 2,
    "requirements": {},
    "result_overrides": {},
    "consumes_turn": true,
    "is_active": false,
    "cost_spec": {
      "type": "none",
      "value": 0
    },
    "limits": {
      "once_per_battle": true,
      "max_uses": 1
    },
    "conditions": {},
    "result_stat_spec": {
      "hp": {
        "mode": "material_sum_percent",
        "value": 0.575
      },
      "attack": {
        "mode": "material_sum_percent",
        "value": 0.575
      },
      "defense": {
        "mode": "material_sum_percent",
        "value": 0.55
      }
    },
    "priority": 50,
    "metadata": {
      "timedoor_seed_source": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion",
      "seed_version": "2.2-learning-arcs-fusion",
      "fusion_id": "F06",
      "education_theme": "Math x English: kapasitas guard dan aba-aba tim.",
      "source_material_expression": "fusion:WATER_GUARD (TUR-006/007) + fusion:FIRE_FEINT (PIC-006/007)",
      "source_legal_zones": [
        "active",
        "bench",
        "hand"
      ],
      "requires_at_least_one_field_material": true,
      "playtest_status": "pending",
      "stat_cap_pending": true
    }
  },
  {
    "code": "timedoor_f07_skybyte_runner",
    "name": "Skybyte Runner",
    "description": "Pengendali Switch; menukar posisi untuk membuka serangan, dengan HP rendah.",
    "icon": "🧬",
    "result_card_key": "master_plan_v2_2:F07",
    "result_zone": "active",
    "material_destination": "graveyard",
    "min_materials": 2,
    "max_materials": 2,
    "requirements": {},
    "result_overrides": {},
    "consumes_turn": true,
    "is_active": false,
    "cost_spec": {
      "type": "none",
      "value": 0
    },
    "limits": {
      "once_per_battle": true,
      "max_uses": 1
    },
    "conditions": {},
    "result_stat_spec": {
      "hp": {
        "mode": "material_sum_percent",
        "value": 0.575
      },
      "attack": {
        "mode": "material_sum_percent",
        "value": 0.575
      },
      "defense": {
        "mode": "material_sum_percent",
        "value": 0.55
      }
    },
    "priority": 50,
    "metadata": {
      "timedoor_seed_source": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion",
      "seed_version": "2.2-learning-arcs-fusion",
      "fusion_id": "F07",
      "education_theme": "English x English: komunikasi navigasi dan rotasi.",
      "source_material_expression": "FAL-006 + FOX-006",
      "source_legal_zones": [
        "active",
        "bench",
        "hand"
      ],
      "requires_at_least_one_field_material": true,
      "playtest_status": "pending",
      "stat_cap_pending": true
    }
  },
  {
    "code": "timedoor_f08_phantom_bloom",
    "name": "Phantom Bloom",
    "description": "Ilusi akar; Root singkat atau debuff ringan bergantian, tidak keduanya sekaligus.",
    "icon": "🧬",
    "result_card_key": "master_plan_v2_2:F08",
    "result_zone": "active",
    "material_destination": "graveyard",
    "min_materials": 2,
    "max_materials": 2,
    "requirements": {},
    "result_overrides": {},
    "consumes_turn": true,
    "is_active": false,
    "cost_spec": {
      "type": "none",
      "value": 0
    },
    "limits": {
      "once_per_battle": true,
      "max_uses": 1
    },
    "conditions": {},
    "result_stat_spec": {
      "hp": {
        "mode": "material_sum_percent",
        "value": 0.575
      },
      "attack": {
        "mode": "material_sum_percent",
        "value": 0.575
      },
      "defense": {
        "mode": "material_sum_percent",
        "value": 0.55
      }
    },
    "priority": 50,
    "metadata": {
      "timedoor_seed_source": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion",
      "seed_version": "2.2-learning-arcs-fusion",
      "fusion_id": "F08",
      "education_theme": "Coding x Math: logika kondisi dan pola akar.",
      "source_material_expression": "fusion:DARK_CONTROL (NUL-006/007) + fusion:ROOT_CONTROL (TOC-005/006)",
      "source_legal_zones": [
        "active",
        "bench",
        "hand"
      ],
      "requires_at_least_one_field_material": true,
      "playtest_status": "pending",
      "stat_cap_pending": true
    }
  },
  {
    "code": "timedoor_f09_hydro_cache_engine",
    "name": "Hydro Cache Engine",
    "description": "Mesin air; pilih heal tunggal atau Shield; tidak melakukan double heal.",
    "icon": "🧬",
    "result_card_key": "master_plan_v2_2:F09",
    "result_zone": "active",
    "material_destination": "graveyard",
    "min_materials": 2,
    "max_materials": 2,
    "requirements": {},
    "result_overrides": {},
    "consumes_turn": true,
    "is_active": false,
    "cost_spec": {
      "type": "none",
      "value": 0
    },
    "limits": {
      "once_per_battle": true,
      "max_uses": 1
    },
    "conditions": {},
    "result_stat_spec": {
      "hp": {
        "mode": "material_sum_percent",
        "value": 0.575
      },
      "attack": {
        "mode": "material_sum_percent",
        "value": 0.575
      },
      "defense": {
        "mode": "material_sum_percent",
        "value": 0.55
      }
    },
    "priority": 50,
    "metadata": {
      "timedoor_seed_source": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion",
      "seed_version": "2.2-learning-arcs-fusion",
      "fusion_id": "F09",
      "education_theme": "Water Data x Math: pilih heal atau shield, bukan keduanya.",
      "source_material_expression": "1 dari [OTT-006, OTT-007] + 1 dari [TUR-006, TUR-007]",
      "source_legal_zones": [
        "active",
        "bench",
        "hand"
      ],
      "requires_at_least_one_field_material": true,
      "playtest_status": "pending",
      "stat_cap_pending": true
    }
  },
  {
    "code": "timedoor_f10_pixel_ember_pack",
    "name": "Pixel Ember Pack",
    "description": "Perisai api; perlindungan satu rekan dan Mark satu target, bukan buff ganda.",
    "icon": "🧬",
    "result_card_key": "master_plan_v2_2:F10",
    "result_zone": "active",
    "material_destination": "graveyard",
    "min_materials": 2,
    "max_materials": 2,
    "requirements": {},
    "result_overrides": {},
    "consumes_turn": true,
    "is_active": false,
    "cost_spec": {
      "type": "none",
      "value": 0
    },
    "limits": {
      "once_per_battle": true,
      "max_uses": 1
    },
    "conditions": {},
    "result_stat_spec": {
      "hp": {
        "mode": "material_sum_percent",
        "value": 0.575
      },
      "attack": {
        "mode": "material_sum_percent",
        "value": 0.575
      },
      "defense": {
        "mode": "material_sum_percent",
        "value": 0.55
      }
    },
    "priority": 50,
    "metadata": {
      "timedoor_seed_source": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion",
      "seed_version": "2.2-learning-arcs-fusion",
      "fusion_id": "F10",
      "education_theme": "English x English: koordinasi formasi dan kontrol api.",
      "source_material_expression": "RAB-007 + WLF-007",
      "source_legal_zones": [
        "active",
        "bench",
        "hand"
      ],
      "requires_at_least_one_field_material": true,
      "playtest_status": "pending",
      "stat_cap_pending": true
    }
  },
  {
    "code": "timedoor_f11_spirit_current",
    "name": "Spirit Current",
    "description": "Arus api-air; memilih timing Burn atau cleanse, tidak menambah extra action.",
    "icon": "🧬",
    "result_card_key": "master_plan_v2_2:F11",
    "result_zone": "active",
    "material_destination": "graveyard",
    "min_materials": 2,
    "max_materials": 2,
    "requirements": {},
    "result_overrides": {},
    "consumes_turn": true,
    "is_active": false,
    "cost_spec": {
      "type": "none",
      "value": 0
    },
    "limits": {
      "once_per_battle": true,
      "max_uses": 1
    },
    "conditions": {},
    "result_stat_spec": {
      "hp": {
        "mode": "material_sum_percent",
        "value": 0.575
      },
      "attack": {
        "mode": "material_sum_percent",
        "value": 0.575
      },
      "defense": {
        "mode": "material_sum_percent",
        "value": 0.55
      }
    },
    "priority": 50,
    "metadata": {
      "timedoor_seed_source": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion",
      "seed_version": "2.2-learning-arcs-fusion",
      "fusion_id": "F11",
      "education_theme": "English x Coding: timing api dan validasi cleanse.",
      "source_material_expression": "PIC-007 + 1 dari [OTT-006, OTT-007]",
      "source_legal_zones": [
        "active",
        "bench",
        "hand"
      ],
      "requires_at_least_one_field_material": true,
      "playtest_status": "pending",
      "stat_cap_pending": true
    }
  },
  {
    "code": "timedoor_f12_academy_nexus",
    "name": "Academy Nexus",
    "description": "Tiga pilar dukungan; sekali per battle pilih satu buff kecil tim, tanpa AoE heal berlebihan.",
    "icon": "🧬",
    "result_card_key": "master_plan_v2_2:F12",
    "result_zone": "active",
    "material_destination": "graveyard",
    "min_materials": 3,
    "max_materials": 3,
    "requirements": {},
    "result_overrides": {},
    "consumes_turn": true,
    "is_active": false,
    "cost_spec": {
      "type": "none",
      "value": 0
    },
    "limits": {
      "once_per_battle": true,
      "max_uses": 1
    },
    "conditions": {},
    "result_stat_spec": {
      "hp": {
        "mode": "material_sum_percent",
        "value": 0.4
      },
      "attack": {
        "mode": "material_sum_percent",
        "value": 0.4
      },
      "defense": {
        "mode": "material_sum_percent",
        "value": 0.4
      }
    },
    "priority": 50,
    "metadata": {
      "timedoor_seed_source": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion",
      "seed_version": "2.2-learning-arcs-fusion",
      "fusion_id": "F12",
      "education_theme": "Skill Lab x3: prototipe tim lintas kemampuan.",
      "source_material_expression": "COB-008 + TOC-008 + OTT-008",
      "source_legal_zones": [
        "active",
        "bench",
        "hand"
      ],
      "requires_at_least_one_field_material": true,
      "playtest_status": "pending",
      "stat_cap_pending": true
    }
  },
  {
    "code": "timedoor_f13_solar_circuit",
    "name": "Solar Circuit",
    "description": "Kombo ledakan terkendali; bonus Electric pada target Burn dengan cooldown panjang.",
    "icon": "🧬",
    "result_card_key": "master_plan_v2_2:F13",
    "result_zone": "active",
    "material_destination": "graveyard",
    "min_materials": 2,
    "max_materials": 2,
    "requirements": {},
    "result_overrides": {},
    "consumes_turn": true,
    "is_active": false,
    "cost_spec": {
      "type": "none",
      "value": 0
    },
    "limits": {
      "once_per_battle": true,
      "max_uses": 1
    },
    "conditions": {},
    "result_stat_spec": {
      "hp": {
        "mode": "material_sum_percent",
        "value": 0.575
      },
      "attack": {
        "mode": "material_sum_percent",
        "value": 0.575
      },
      "defense": {
        "mode": "material_sum_percent",
        "value": 0.55
      }
    },
    "priority": 50,
    "metadata": {
      "timedoor_seed_source": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion",
      "seed_version": "2.2-learning-arcs-fusion",
      "fusion_id": "F13",
      "education_theme": "Skill Lab: interaksi LED dan game cerita.",
      "source_material_expression": "PAN-008 + PIC-008",
      "source_legal_zones": [
        "active",
        "bench",
        "hand"
      ],
      "requires_at_least_one_field_material": true,
      "playtest_status": "pending",
      "stat_cap_pending": true
    }
  },
  {
    "code": "timedoor_f14_windleaf_scout",
    "name": "Windleaf Scout",
    "description": "Pengintai daun-angin; Switch aman atau Root singkat, pilih satu.",
    "icon": "🧬",
    "result_card_key": "master_plan_v2_2:F14",
    "result_zone": "active",
    "material_destination": "graveyard",
    "min_materials": 2,
    "max_materials": 2,
    "requirements": {},
    "result_overrides": {},
    "consumes_turn": true,
    "is_active": false,
    "cost_spec": {
      "type": "none",
      "value": 0
    },
    "limits": {
      "once_per_battle": true,
      "max_uses": 1
    },
    "conditions": {},
    "result_stat_spec": {
      "hp": {
        "mode": "material_sum_percent",
        "value": 0.575
      },
      "attack": {
        "mode": "material_sum_percent",
        "value": 0.575
      },
      "defense": {
        "mode": "material_sum_percent",
        "value": 0.55
      }
    },
    "priority": 50,
    "metadata": {
      "timedoor_seed_source": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion",
      "seed_version": "2.2-learning-arcs-fusion",
      "fusion_id": "F14",
      "education_theme": "English x Skill Lab: navigasi rute hijau.",
      "source_material_expression": "1 dari [FAL-007, FAL-008] + 1 dari [TOC-007, TOC-008]",
      "source_legal_zones": [
        "active",
        "bench",
        "hand"
      ],
      "requires_at_least_one_field_material": true,
      "playtest_status": "pending",
      "stat_cap_pending": true
    }
  },
  {
    "code": "timedoor_f15_digital_tidal_fox",
    "name": "Digital Tidal Fox",
    "description": "Rubah arus; setelah Switch pilih serangan cepat atau cleanse pendamping.",
    "icon": "🧬",
    "result_card_key": "master_plan_v2_2:F15",
    "result_zone": "active",
    "material_destination": "graveyard",
    "min_materials": 2,
    "max_materials": 2,
    "requirements": {},
    "result_overrides": {},
    "consumes_turn": true,
    "is_active": false,
    "cost_spec": {
      "type": "none",
      "value": 0
    },
    "limits": {
      "once_per_battle": true,
      "max_uses": 1
    },
    "conditions": {},
    "result_stat_spec": {
      "hp": {
        "mode": "material_sum_percent",
        "value": 0.575
      },
      "attack": {
        "mode": "material_sum_percent",
        "value": 0.575
      },
      "defense": {
        "mode": "material_sum_percent",
        "value": 0.55
      }
    },
    "priority": 50,
    "metadata": {
      "timedoor_seed_source": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion",
      "seed_version": "2.2-learning-arcs-fusion",
      "fusion_id": "F15",
      "education_theme": "English x Skill Lab: optimasi dashboard bergerak.",
      "source_material_expression": "fusion:FAST_ALGORITHM (FOX-007/008) + fusion:WATER_RESEARCH (OTT-007/008)",
      "source_legal_zones": [
        "active",
        "bench",
        "hand"
      ],
      "requires_at_least_one_field_material": true,
      "playtest_status": "pending",
      "stat_cap_pending": true
    }
  },
  {
    "code": "timedoor_f16_abyssal_shadow_sentinel",
    "name": "Abyssal Shadow Sentinel",
    "description": "Penjaga jurang; Shield air plus debuff Dark terbatas, tidak menghidupkan kartu tanpa biaya.",
    "icon": "🧬",
    "result_card_key": "master_plan_v2_2:F16",
    "result_zone": "active",
    "material_destination": "graveyard",
    "min_materials": 2,
    "max_materials": 2,
    "requirements": {},
    "result_overrides": {},
    "consumes_turn": true,
    "is_active": false,
    "cost_spec": {
      "type": "none",
      "value": 0
    },
    "limits": {
      "once_per_battle": true,
      "max_uses": 1
    },
    "conditions": {},
    "result_stat_spec": {
      "hp": {
        "mode": "material_sum_percent",
        "value": 0.575
      },
      "attack": {
        "mode": "material_sum_percent",
        "value": 0.575
      },
      "defense": {
        "mode": "material_sum_percent",
        "value": 0.55
      }
    },
    "priority": 50,
    "metadata": {
      "timedoor_seed_source": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion",
      "seed_version": "2.2-learning-arcs-fusion",
      "fusion_id": "F16",
      "education_theme": "Skill Lab: simulasi backup dan perlindungan data.",
      "source_material_expression": "NUL-008 + TUR-008",
      "source_legal_zones": [
        "active",
        "bench",
        "hand"
      ],
      "requires_at_least_one_field_material": true,
      "playtest_status": "pending",
      "stat_cap_pending": true
    }
  },
  {
    "code": "timedoor_f17_thunder_canopy",
    "name": "Thunder Canopy",
    "description": "Kanopi listrik; perlindungan rekan menyiapkan chain hit yang dibatasi target.",
    "icon": "🧬",
    "result_card_key": "master_plan_v2_2:F17",
    "result_zone": "active",
    "material_destination": "graveyard",
    "min_materials": 2,
    "max_materials": 2,
    "requirements": {},
    "result_overrides": {},
    "consumes_turn": true,
    "is_active": false,
    "cost_spec": {
      "type": "none",
      "value": 0
    },
    "limits": {
      "once_per_battle": true,
      "max_uses": 1
    },
    "conditions": {},
    "result_stat_spec": {
      "hp": {
        "mode": "material_sum_percent",
        "value": 0.575
      },
      "attack": {
        "mode": "material_sum_percent",
        "value": 0.575
      },
      "defense": {
        "mode": "material_sum_percent",
        "value": 0.55
      }
    },
    "priority": 50,
    "metadata": {
      "timedoor_seed_source": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion",
      "seed_version": "2.2-learning-arcs-fusion",
      "fusion_id": "F17",
      "education_theme": "Skill Lab: sensor dan benteng responsif.",
      "source_material_expression": "PAN-008 + RAB-008",
      "source_legal_zones": [
        "active",
        "bench",
        "hand"
      ],
      "requires_at_least_one_field_material": true,
      "playtest_status": "pending",
      "stat_cap_pending": true
    }
  },
  {
    "code": "timedoor_f18_coded_eclipse",
    "name": "Coded Eclipse",
    "description": "Gerhana bara; tanda target memicu serangan api dan satu debuff non-AoE.",
    "icon": "🧬",
    "result_card_key": "master_plan_v2_2:F18",
    "result_zone": "active",
    "material_destination": "graveyard",
    "min_materials": 2,
    "max_materials": 2,
    "requirements": {},
    "result_overrides": {},
    "consumes_turn": true,
    "is_active": false,
    "cost_spec": {
      "type": "none",
      "value": 0
    },
    "limits": {
      "once_per_battle": true,
      "max_uses": 1
    },
    "conditions": {},
    "result_stat_spec": {
      "hp": {
        "mode": "material_sum_percent",
        "value": 0.575
      },
      "attack": {
        "mode": "material_sum_percent",
        "value": 0.575
      },
      "defense": {
        "mode": "material_sum_percent",
        "value": 0.55
      }
    },
    "priority": 50,
    "metadata": {
      "timedoor_seed_source": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion",
      "seed_version": "2.2-learning-arcs-fusion",
      "fusion_id": "F18",
      "education_theme": "Skill Lab: simulasi status dan prosedur recovery.",
      "source_material_expression": "1 dari [WLF-008, WLF-009] + NUL-008",
      "source_legal_zones": [
        "active",
        "bench",
        "hand"
      ],
      "requires_at_least_one_field_material": true,
      "playtest_status": "pending",
      "stat_cap_pending": true
    }
  },
  {
    "code": "timedoor_f19_arc_guard",
    "name": "Arc Guard",
    "description": "Perisai konduktor; tahan satu pukulan dan bantu tempo tim tanpa draw gratis.",
    "icon": "🧬",
    "result_card_key": "master_plan_v2_2:F19",
    "result_zone": "active",
    "material_destination": "graveyard",
    "min_materials": 2,
    "max_materials": 2,
    "requirements": {},
    "result_overrides": {},
    "consumes_turn": true,
    "is_active": false,
    "cost_spec": {
      "type": "none",
      "value": 0
    },
    "limits": {
      "once_per_battle": true,
      "max_uses": 1
    },
    "conditions": {},
    "result_stat_spec": {
      "hp": {
        "mode": "material_sum_percent",
        "value": 0.575
      },
      "attack": {
        "mode": "material_sum_percent",
        "value": 0.575
      },
      "defense": {
        "mode": "material_sum_percent",
        "value": 0.55
      }
    },
    "priority": 50,
    "metadata": {
      "timedoor_seed_source": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion",
      "seed_version": "2.2-learning-arcs-fusion",
      "fusion_id": "F19",
      "education_theme": "English x Skill Lab: command center dan guard.",
      "source_material_expression": "1 dari [COB-007, COB-008] + TUR-008",
      "source_legal_zones": [
        "active",
        "bench",
        "hand"
      ],
      "requires_at_least_one_field_material": true,
      "playtest_status": "pending",
      "stat_cap_pending": true
    }
  },
  {
    "code": "timedoor_f20_rabbit_afterimage",
    "name": "Rabbit Afterimage",
    "description": "Bayangan pembangun; Shield kecil serta bonus dash bersyarat.",
    "icon": "🧬",
    "result_card_key": "master_plan_v2_2:F20",
    "result_zone": "active",
    "material_destination": "graveyard",
    "min_materials": 2,
    "max_materials": 2,
    "requirements": {},
    "result_overrides": {},
    "consumes_turn": true,
    "is_active": false,
    "cost_spec": {
      "type": "none",
      "value": 0
    },
    "limits": {
      "once_per_battle": true,
      "max_uses": 1
    },
    "conditions": {},
    "result_stat_spec": {
      "hp": {
        "mode": "material_sum_percent",
        "value": 0.575
      },
      "attack": {
        "mode": "material_sum_percent",
        "value": 0.575
      },
      "defense": {
        "mode": "material_sum_percent",
        "value": 0.55
      }
    },
    "priority": 50,
    "metadata": {
      "timedoor_seed_source": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion",
      "seed_version": "2.2-learning-arcs-fusion",
      "fusion_id": "F20",
      "education_theme": "Skill Lab: visualisasi obstacle dengan perlindungan.",
      "source_material_expression": "RAB-008 + 1 dari [FOX-007, FOX-008]",
      "source_legal_zones": [
        "active",
        "bench",
        "hand"
      ],
      "requires_at_least_one_field_material": true,
      "playtest_status": "pending",
      "stat_cap_pending": true
    }
  },
  {
    "code": "timedoor_f21_skyline_guardian",
    "name": "Skyline Guardian",
    "description": "Pemburu langit api; serangan setelah Switch dan Burn normal yang tidak menumpuk gratis.",
    "icon": "🧬",
    "result_card_key": "master_plan_v2_2:F21",
    "result_zone": "active",
    "material_destination": "graveyard",
    "min_materials": 2,
    "max_materials": 2,
    "requirements": {},
    "result_overrides": {},
    "consumes_turn": true,
    "is_active": false,
    "cost_spec": {
      "type": "none",
      "value": 0
    },
    "limits": {
      "once_per_battle": true,
      "max_uses": 1
    },
    "conditions": {},
    "result_stat_spec": {
      "hp": {
        "mode": "material_sum_percent",
        "value": 0.575
      },
      "attack": {
        "mode": "material_sum_percent",
        "value": 0.575
      },
      "defense": {
        "mode": "material_sum_percent",
        "value": 0.55
      }
    },
    "priority": 50,
    "metadata": {
      "timedoor_seed_source": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion",
      "seed_version": "2.2-learning-arcs-fusion",
      "fusion_id": "F21",
      "education_theme": "Skill Lab: simulasi navigasi dan cooldown api.",
      "source_material_expression": "FAL-008 + WLF-008",
      "source_legal_zones": [
        "active",
        "bench",
        "hand"
      ],
      "requires_at_least_one_field_material": true,
      "playtest_status": "pending",
      "stat_cap_pending": true
    }
  },
  {
    "code": "timedoor_f22_pico_overclock",
    "name": "Pico Overclock",
    "description": "Overclock gerak; serangan listrik-api kuat jika target sudah Burn, CD 3.",
    "icon": "🧬",
    "result_card_key": "master_plan_v2_2:F22",
    "result_zone": "active",
    "material_destination": "graveyard",
    "min_materials": 2,
    "max_materials": 2,
    "requirements": {},
    "result_overrides": {},
    "consumes_turn": true,
    "is_active": false,
    "cost_spec": {
      "type": "none",
      "value": 0
    },
    "limits": {
      "once_per_battle": true,
      "max_uses": 1
    },
    "conditions": {},
    "result_stat_spec": {
      "hp": {
        "mode": "material_sum_percent",
        "value": 0.575
      },
      "attack": {
        "mode": "material_sum_percent",
        "value": 0.575
      },
      "defense": {
        "mode": "material_sum_percent",
        "value": 0.55
      }
    },
    "priority": 50,
    "metadata": {
      "timedoor_seed_source": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion",
      "seed_version": "2.2-learning-arcs-fusion",
      "fusion_id": "F22",
      "education_theme": "Skill Lab: kontrol LED dan animasi responsif.",
      "source_material_expression": "PIC-008 + PAN-008",
      "source_legal_zones": [
        "active",
        "bench",
        "hand"
      ],
      "requires_at_least_one_field_material": true,
      "playtest_status": "pending",
      "stat_cap_pending": true
    }
  },
  {
    "code": "timedoor_f23_revival_circuit",
    "name": "Revival Circuit",
    "description": "Fusion necromancer; sacrifice atau bahan Graveyard legal dan 1 revive pada 50% HP, 1×/battle.",
    "icon": "🧬",
    "result_card_key": "master_plan_v2_2:F23",
    "result_zone": "active",
    "material_destination": "graveyard",
    "min_materials": 2,
    "max_materials": 2,
    "requirements": {},
    "result_overrides": {},
    "consumes_turn": true,
    "is_active": false,
    "cost_spec": {
      "type": "none",
      "value": 0
    },
    "limits": {
      "once_per_battle": true,
      "max_uses": 1
    },
    "conditions": {},
    "result_stat_spec": {
      "hp": {
        "mode": "material_sum_percent",
        "value": 0.575
      },
      "attack": {
        "mode": "material_sum_percent",
        "value": 0.575
      },
      "defense": {
        "mode": "material_sum_percent",
        "value": 0.55
      }
    },
    "priority": 50,
    "metadata": {
      "timedoor_seed_source": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion",
      "seed_version": "2.2-learning-arcs-fusion",
      "fusion_id": "F23",
      "education_theme": "Skill Lab: konsep snapshot/recovery; 1 revive legal.",
      "source_material_expression": "NUL-008 + OTT-008 (lokasi Graveyard bila dinyatakan resep)",
      "source_legal_zones": [
        "active",
        "bench",
        "hand",
        "graveyard"
      ],
      "requires_at_least_one_field_material": true,
      "playtest_status": "pending",
      "stat_cap_pending": true,
      "requires_necromancer_condition": true,
      "revive_hp_percent": 50,
      "revival_once_per_battle": true,
      "excludes_fusion_consumed_materials": true
    }
  },
  {
    "code": "timedoor_f24_grand_academy_union",
    "name": "Grand Academy Union",
    "description": "Tiga keluarga kerja sama; sekali/battle pilih utility tim, bukan tiga skill sekaligus.",
    "icon": "🧬",
    "result_card_key": "master_plan_v2_2:F24",
    "result_zone": "active",
    "material_destination": "graveyard",
    "min_materials": 3,
    "max_materials": 3,
    "requirements": {},
    "result_overrides": {},
    "consumes_turn": true,
    "is_active": false,
    "cost_spec": {
      "type": "none",
      "value": 0
    },
    "limits": {
      "once_per_battle": true,
      "max_uses": 1
    },
    "conditions": {},
    "result_stat_spec": {
      "hp": {
        "mode": "material_sum_percent",
        "value": 0.4
      },
      "attack": {
        "mode": "material_sum_percent",
        "value": 0.4
      },
      "defense": {
        "mode": "material_sum_percent",
        "value": 0.4
      }
    },
    "priority": 50,
    "metadata": {
      "timedoor_seed_source": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion",
      "seed_version": "2.2-learning-arcs-fusion",
      "fusion_id": "F24",
      "education_theme": "Skill Lab capstone: koding, data matematika, dan presentasi English.",
      "source_material_expression": "fusion:ACADEMY_LEAD (COB-008/TOC-008) + fusion:ADVANCED_WIND (FAL-008/FOX-008) + fusion:RESEARCH_CORE (OTT-008/PAN-008)",
      "source_legal_zones": [
        "active",
        "bench",
        "hand"
      ],
      "requires_at_least_one_field_material": true,
      "playtest_status": "pending",
      "stat_cap_pending": true
    }
  }
]$timedoor_recipes$::jsonb) AS s(
    code text, name text, description text, icon text, result_card_key text,
    result_zone text, material_destination text, min_materials integer,
    max_materials integer, requirements jsonb, result_overrides jsonb,
    consumes_turn boolean, is_active boolean, cost_spec jsonb, limits jsonb,
    conditions jsonb, result_stat_spec jsonb, priority integer, metadata jsonb
  )
)
INSERT INTO public.fusion_recipes (
  code, name, description, icon, result_game_card_id, result_zone,
  material_destination, min_materials, max_materials, requirements,
  result_overrides, consumes_turn, is_active, cost_spec, limits, conditions,
  result_stat_spec, priority, metadata
)
SELECT
  seed.code, seed.name, seed.description, seed.icon, card.id, seed.result_zone,
  seed.material_destination, seed.min_materials, seed.max_materials,
  seed.requirements, seed.result_overrides, seed.consumes_turn, seed.is_active,
  seed.cost_spec, seed.limits, seed.conditions, seed.result_stat_spec,
  seed.priority, seed.metadata
FROM recipe_seed AS seed
JOIN public.game_cards AS card
  ON card.metadata ->> 'timedoor_seed_key' = seed.result_card_key
ON CONFLICT (code) DO UPDATE SET
  name = EXCLUDED.name,
  description = EXCLUDED.description,
  icon = EXCLUDED.icon,
  result_game_card_id = EXCLUDED.result_game_card_id,
  result_zone = EXCLUDED.result_zone,
  material_destination = EXCLUDED.material_destination,
  min_materials = EXCLUDED.min_materials,
  max_materials = EXCLUDED.max_materials,
  requirements = EXCLUDED.requirements,
  result_overrides = EXCLUDED.result_overrides,
  consumes_turn = EXCLUDED.consumes_turn,
  cost_spec = EXCLUDED.cost_spec,
  limits = EXCLUDED.limits,
  conditions = EXCLUDED.conditions,
  result_stat_spec = EXCLUDED.result_stat_spec,
  priority = EXCLUDED.priority,
  metadata = public.fusion_recipes.metadata || EXCLUDED.metadata,
  updated_at = now();

-- Replace only material rows created by this seed; hand-authored rows survive.
DELETE FROM public.fusion_recipe_materials AS material
USING public.fusion_recipes AS recipe
WHERE material.recipe_id = recipe.id
  AND recipe.code LIKE 'timedoor_f%'
  AND material.metadata ->> 'timedoor_seed_source' = 'Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion';

WITH material_seed AS (
  SELECT *
  FROM jsonb_to_recordset($timedoor_materials$[
  {
    "recipe_code": "timedoor_f01_circuit_grove_guardian",
    "group_key": "main",
    "material_type": "exact_card",
    "card_code": "COB_006",
    "card_codes": [],
    "tag": null,
    "quantity": 1,
    "allowed_zones": [
      "active",
      "bench"
    ],
    "optional": false,
    "metadata": {
      "timedoor_seed_source": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion",
      "seed_version": "2.2-learning-arcs-fusion",
      "fusion_id": "F01",
      "slot_number": 1,
      "source_candidate_codes": [
        "COB-006"
      ]
    },
    "sort_order": 10
  },
  {
    "recipe_code": "timedoor_f01_circuit_grove_guardian",
    "group_key": "main",
    "material_type": "exact_card",
    "card_code": "TOC_006",
    "card_codes": [],
    "tag": null,
    "quantity": 1,
    "allowed_zones": [
      "active",
      "bench"
    ],
    "optional": false,
    "metadata": {
      "timedoor_seed_source": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion",
      "seed_version": "2.2-learning-arcs-fusion",
      "fusion_id": "F01",
      "slot_number": 2,
      "source_candidate_codes": [
        "TOC-006"
      ]
    },
    "sort_order": 20
  },
  {
    "recipe_code": "timedoor_f02_tempest_flag_marshal",
    "group_key": "main",
    "material_type": "one_of",
    "card_code": null,
    "card_codes": [
      "COB_007",
      "COB_008"
    ],
    "tag": null,
    "quantity": 1,
    "allowed_zones": [
      "active",
      "bench"
    ],
    "optional": false,
    "metadata": {
      "timedoor_seed_source": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion",
      "seed_version": "2.2-learning-arcs-fusion",
      "fusion_id": "F02",
      "slot_number": 1,
      "source_candidate_codes": [
        "COB-007",
        "COB-008"
      ]
    },
    "sort_order": 10
  },
  {
    "recipe_code": "timedoor_f02_tempest_flag_marshal",
    "group_key": "main",
    "material_type": "exact_card",
    "card_code": "FAL_007",
    "card_codes": [],
    "tag": null,
    "quantity": 1,
    "allowed_zones": [
      "active",
      "bench"
    ],
    "optional": false,
    "metadata": {
      "timedoor_seed_source": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion",
      "seed_version": "2.2-learning-arcs-fusion",
      "fusion_id": "F02",
      "slot_number": 2,
      "source_candidate_codes": [
        "FAL-007"
      ]
    },
    "sort_order": 20
  },
  {
    "recipe_code": "timedoor_f03_byte_sprout_hacker",
    "group_key": "main",
    "material_type": "tag",
    "card_code": null,
    "card_codes": [],
    "tag": "fusion:agile_code",
    "quantity": 1,
    "allowed_zones": [
      "active",
      "bench"
    ],
    "optional": false,
    "metadata": {
      "timedoor_seed_source": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion",
      "seed_version": "2.2-learning-arcs-fusion",
      "fusion_id": "F03",
      "slot_number": 1,
      "source_candidate_codes": [
        "FOX-006",
        "FOX-007"
      ]
    },
    "sort_order": 10
  },
  {
    "recipe_code": "timedoor_f03_byte_sprout_hacker",
    "group_key": "main",
    "material_type": "tag",
    "card_code": null,
    "card_codes": [],
    "tag": "fusion:build_shield",
    "quantity": 1,
    "allowed_zones": [
      "active",
      "bench"
    ],
    "optional": false,
    "metadata": {
      "timedoor_seed_source": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion",
      "seed_version": "2.2-learning-arcs-fusion",
      "fusion_id": "F03",
      "slot_number": 2,
      "source_candidate_codes": [
        "RAB-006",
        "RAB-007"
      ]
    },
    "sort_order": 20
  },
  {
    "recipe_code": "timedoor_f04_eclipse_signal",
    "group_key": "main",
    "material_type": "exact_card",
    "card_code": "NUL_007",
    "card_codes": [],
    "tag": null,
    "quantity": 1,
    "allowed_zones": [
      "active",
      "bench"
    ],
    "optional": false,
    "metadata": {
      "timedoor_seed_source": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion",
      "seed_version": "2.2-learning-arcs-fusion",
      "fusion_id": "F04",
      "slot_number": 1,
      "source_candidate_codes": [
        "NUL-007"
      ]
    },
    "sort_order": 10
  },
  {
    "recipe_code": "timedoor_f04_eclipse_signal",
    "group_key": "main",
    "material_type": "exact_card",
    "card_code": "PAN_007",
    "card_codes": [],
    "tag": null,
    "quantity": 1,
    "allowed_zones": [
      "active",
      "bench"
    ],
    "optional": false,
    "metadata": {
      "timedoor_seed_source": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion",
      "seed_version": "2.2-learning-arcs-fusion",
      "fusion_id": "F04",
      "slot_number": 2,
      "source_candidate_codes": [
        "PAN-007"
      ]
    },
    "sort_order": 20
  },
  {
    "recipe_code": "timedoor_f05_aqua_vector_sentinel",
    "group_key": "main",
    "material_type": "one_of",
    "card_code": null,
    "card_codes": [
      "OTT_006",
      "OTT_007"
    ],
    "tag": null,
    "quantity": 1,
    "allowed_zones": [
      "active",
      "bench"
    ],
    "optional": false,
    "metadata": {
      "timedoor_seed_source": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion",
      "seed_version": "2.2-learning-arcs-fusion",
      "fusion_id": "F05",
      "slot_number": 1,
      "source_candidate_codes": [
        "OTT-006",
        "OTT-007"
      ]
    },
    "sort_order": 10
  },
  {
    "recipe_code": "timedoor_f05_aqua_vector_sentinel",
    "group_key": "main",
    "material_type": "exact_card",
    "card_code": "WLF_006",
    "card_codes": [],
    "tag": null,
    "quantity": 1,
    "allowed_zones": [
      "active",
      "bench"
    ],
    "optional": false,
    "metadata": {
      "timedoor_seed_source": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion",
      "seed_version": "2.2-learning-arcs-fusion",
      "fusion_id": "F05",
      "slot_number": 2,
      "source_candidate_codes": [
        "WLF-006"
      ]
    },
    "sort_order": 20
  },
  {
    "recipe_code": "timedoor_f06_steam_fortress",
    "group_key": "main",
    "material_type": "tag",
    "card_code": null,
    "card_codes": [],
    "tag": "fusion:water_guard",
    "quantity": 1,
    "allowed_zones": [
      "active",
      "bench"
    ],
    "optional": false,
    "metadata": {
      "timedoor_seed_source": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion",
      "seed_version": "2.2-learning-arcs-fusion",
      "fusion_id": "F06",
      "slot_number": 1,
      "source_candidate_codes": [
        "TUR-006",
        "TUR-007"
      ]
    },
    "sort_order": 10
  },
  {
    "recipe_code": "timedoor_f06_steam_fortress",
    "group_key": "main",
    "material_type": "tag",
    "card_code": null,
    "card_codes": [],
    "tag": "fusion:fire_feint",
    "quantity": 1,
    "allowed_zones": [
      "active",
      "bench"
    ],
    "optional": false,
    "metadata": {
      "timedoor_seed_source": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion",
      "seed_version": "2.2-learning-arcs-fusion",
      "fusion_id": "F06",
      "slot_number": 2,
      "source_candidate_codes": [
        "PIC-006",
        "PIC-007"
      ]
    },
    "sort_order": 20
  },
  {
    "recipe_code": "timedoor_f07_skybyte_runner",
    "group_key": "main",
    "material_type": "exact_card",
    "card_code": "FAL_006",
    "card_codes": [],
    "tag": null,
    "quantity": 1,
    "allowed_zones": [
      "active",
      "bench"
    ],
    "optional": false,
    "metadata": {
      "timedoor_seed_source": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion",
      "seed_version": "2.2-learning-arcs-fusion",
      "fusion_id": "F07",
      "slot_number": 1,
      "source_candidate_codes": [
        "FAL-006"
      ]
    },
    "sort_order": 10
  },
  {
    "recipe_code": "timedoor_f07_skybyte_runner",
    "group_key": "main",
    "material_type": "exact_card",
    "card_code": "FOX_006",
    "card_codes": [],
    "tag": null,
    "quantity": 1,
    "allowed_zones": [
      "active",
      "bench"
    ],
    "optional": false,
    "metadata": {
      "timedoor_seed_source": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion",
      "seed_version": "2.2-learning-arcs-fusion",
      "fusion_id": "F07",
      "slot_number": 2,
      "source_candidate_codes": [
        "FOX-006"
      ]
    },
    "sort_order": 20
  },
  {
    "recipe_code": "timedoor_f08_phantom_bloom",
    "group_key": "main",
    "material_type": "tag",
    "card_code": null,
    "card_codes": [],
    "tag": "fusion:dark_control",
    "quantity": 1,
    "allowed_zones": [
      "active",
      "bench"
    ],
    "optional": false,
    "metadata": {
      "timedoor_seed_source": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion",
      "seed_version": "2.2-learning-arcs-fusion",
      "fusion_id": "F08",
      "slot_number": 1,
      "source_candidate_codes": [
        "NUL-006",
        "NUL-007"
      ]
    },
    "sort_order": 10
  },
  {
    "recipe_code": "timedoor_f08_phantom_bloom",
    "group_key": "main",
    "material_type": "tag",
    "card_code": null,
    "card_codes": [],
    "tag": "fusion:root_control",
    "quantity": 1,
    "allowed_zones": [
      "active",
      "bench"
    ],
    "optional": false,
    "metadata": {
      "timedoor_seed_source": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion",
      "seed_version": "2.2-learning-arcs-fusion",
      "fusion_id": "F08",
      "slot_number": 2,
      "source_candidate_codes": [
        "TOC-005",
        "TOC-006"
      ]
    },
    "sort_order": 20
  },
  {
    "recipe_code": "timedoor_f09_hydro_cache_engine",
    "group_key": "main",
    "material_type": "one_of",
    "card_code": null,
    "card_codes": [
      "OTT_006",
      "OTT_007"
    ],
    "tag": null,
    "quantity": 1,
    "allowed_zones": [
      "active",
      "bench"
    ],
    "optional": false,
    "metadata": {
      "timedoor_seed_source": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion",
      "seed_version": "2.2-learning-arcs-fusion",
      "fusion_id": "F09",
      "slot_number": 1,
      "source_candidate_codes": [
        "OTT-006",
        "OTT-007"
      ]
    },
    "sort_order": 10
  },
  {
    "recipe_code": "timedoor_f09_hydro_cache_engine",
    "group_key": "main",
    "material_type": "one_of",
    "card_code": null,
    "card_codes": [
      "TUR_006",
      "TUR_007"
    ],
    "tag": null,
    "quantity": 1,
    "allowed_zones": [
      "active",
      "bench"
    ],
    "optional": false,
    "metadata": {
      "timedoor_seed_source": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion",
      "seed_version": "2.2-learning-arcs-fusion",
      "fusion_id": "F09",
      "slot_number": 2,
      "source_candidate_codes": [
        "TUR-006",
        "TUR-007"
      ]
    },
    "sort_order": 20
  },
  {
    "recipe_code": "timedoor_f10_pixel_ember_pack",
    "group_key": "main",
    "material_type": "exact_card",
    "card_code": "RAB_007",
    "card_codes": [],
    "tag": null,
    "quantity": 1,
    "allowed_zones": [
      "active",
      "bench"
    ],
    "optional": false,
    "metadata": {
      "timedoor_seed_source": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion",
      "seed_version": "2.2-learning-arcs-fusion",
      "fusion_id": "F10",
      "slot_number": 1,
      "source_candidate_codes": [
        "RAB-007"
      ]
    },
    "sort_order": 10
  },
  {
    "recipe_code": "timedoor_f10_pixel_ember_pack",
    "group_key": "main",
    "material_type": "exact_card",
    "card_code": "WLF_007",
    "card_codes": [],
    "tag": null,
    "quantity": 1,
    "allowed_zones": [
      "active",
      "bench"
    ],
    "optional": false,
    "metadata": {
      "timedoor_seed_source": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion",
      "seed_version": "2.2-learning-arcs-fusion",
      "fusion_id": "F10",
      "slot_number": 2,
      "source_candidate_codes": [
        "WLF-007"
      ]
    },
    "sort_order": 20
  },
  {
    "recipe_code": "timedoor_f11_spirit_current",
    "group_key": "main",
    "material_type": "exact_card",
    "card_code": "PIC_007",
    "card_codes": [],
    "tag": null,
    "quantity": 1,
    "allowed_zones": [
      "active",
      "bench"
    ],
    "optional": false,
    "metadata": {
      "timedoor_seed_source": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion",
      "seed_version": "2.2-learning-arcs-fusion",
      "fusion_id": "F11",
      "slot_number": 1,
      "source_candidate_codes": [
        "PIC-007"
      ]
    },
    "sort_order": 10
  },
  {
    "recipe_code": "timedoor_f11_spirit_current",
    "group_key": "main",
    "material_type": "one_of",
    "card_code": null,
    "card_codes": [
      "OTT_006",
      "OTT_007"
    ],
    "tag": null,
    "quantity": 1,
    "allowed_zones": [
      "active",
      "bench"
    ],
    "optional": false,
    "metadata": {
      "timedoor_seed_source": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion",
      "seed_version": "2.2-learning-arcs-fusion",
      "fusion_id": "F11",
      "slot_number": 2,
      "source_candidate_codes": [
        "OTT-006",
        "OTT-007"
      ]
    },
    "sort_order": 20
  },
  {
    "recipe_code": "timedoor_f12_academy_nexus",
    "group_key": "main",
    "material_type": "exact_card",
    "card_code": "COB_008",
    "card_codes": [],
    "tag": null,
    "quantity": 1,
    "allowed_zones": [
      "active",
      "bench"
    ],
    "optional": false,
    "metadata": {
      "timedoor_seed_source": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion",
      "seed_version": "2.2-learning-arcs-fusion",
      "fusion_id": "F12",
      "slot_number": 1,
      "source_candidate_codes": [
        "COB-008"
      ]
    },
    "sort_order": 10
  },
  {
    "recipe_code": "timedoor_f12_academy_nexus",
    "group_key": "main",
    "material_type": "exact_card",
    "card_code": "TOC_008",
    "card_codes": [],
    "tag": null,
    "quantity": 1,
    "allowed_zones": [
      "active",
      "bench"
    ],
    "optional": false,
    "metadata": {
      "timedoor_seed_source": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion",
      "seed_version": "2.2-learning-arcs-fusion",
      "fusion_id": "F12",
      "slot_number": 2,
      "source_candidate_codes": [
        "TOC-008"
      ]
    },
    "sort_order": 20
  },
  {
    "recipe_code": "timedoor_f12_academy_nexus",
    "group_key": "main",
    "material_type": "exact_card",
    "card_code": "OTT_008",
    "card_codes": [],
    "tag": null,
    "quantity": 1,
    "allowed_zones": [
      "active",
      "bench"
    ],
    "optional": false,
    "metadata": {
      "timedoor_seed_source": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion",
      "seed_version": "2.2-learning-arcs-fusion",
      "fusion_id": "F12",
      "slot_number": 3,
      "source_candidate_codes": [
        "OTT-008"
      ]
    },
    "sort_order": 30
  },
  {
    "recipe_code": "timedoor_f13_solar_circuit",
    "group_key": "main",
    "material_type": "exact_card",
    "card_code": "PAN_008",
    "card_codes": [],
    "tag": null,
    "quantity": 1,
    "allowed_zones": [
      "active",
      "bench"
    ],
    "optional": false,
    "metadata": {
      "timedoor_seed_source": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion",
      "seed_version": "2.2-learning-arcs-fusion",
      "fusion_id": "F13",
      "slot_number": 1,
      "source_candidate_codes": [
        "PAN-008"
      ]
    },
    "sort_order": 10
  },
  {
    "recipe_code": "timedoor_f13_solar_circuit",
    "group_key": "main",
    "material_type": "exact_card",
    "card_code": "PIC_008",
    "card_codes": [],
    "tag": null,
    "quantity": 1,
    "allowed_zones": [
      "active",
      "bench"
    ],
    "optional": false,
    "metadata": {
      "timedoor_seed_source": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion",
      "seed_version": "2.2-learning-arcs-fusion",
      "fusion_id": "F13",
      "slot_number": 2,
      "source_candidate_codes": [
        "PIC-008"
      ]
    },
    "sort_order": 20
  },
  {
    "recipe_code": "timedoor_f14_windleaf_scout",
    "group_key": "main",
    "material_type": "one_of",
    "card_code": null,
    "card_codes": [
      "FAL_007",
      "FAL_008"
    ],
    "tag": null,
    "quantity": 1,
    "allowed_zones": [
      "active",
      "bench"
    ],
    "optional": false,
    "metadata": {
      "timedoor_seed_source": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion",
      "seed_version": "2.2-learning-arcs-fusion",
      "fusion_id": "F14",
      "slot_number": 1,
      "source_candidate_codes": [
        "FAL-007",
        "FAL-008"
      ]
    },
    "sort_order": 10
  },
  {
    "recipe_code": "timedoor_f14_windleaf_scout",
    "group_key": "main",
    "material_type": "one_of",
    "card_code": null,
    "card_codes": [
      "TOC_007",
      "TOC_008"
    ],
    "tag": null,
    "quantity": 1,
    "allowed_zones": [
      "active",
      "bench"
    ],
    "optional": false,
    "metadata": {
      "timedoor_seed_source": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion",
      "seed_version": "2.2-learning-arcs-fusion",
      "fusion_id": "F14",
      "slot_number": 2,
      "source_candidate_codes": [
        "TOC-007",
        "TOC-008"
      ]
    },
    "sort_order": 20
  },
  {
    "recipe_code": "timedoor_f15_digital_tidal_fox",
    "group_key": "main",
    "material_type": "tag",
    "card_code": null,
    "card_codes": [],
    "tag": "fusion:fast_algorithm",
    "quantity": 1,
    "allowed_zones": [
      "active",
      "bench"
    ],
    "optional": false,
    "metadata": {
      "timedoor_seed_source": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion",
      "seed_version": "2.2-learning-arcs-fusion",
      "fusion_id": "F15",
      "slot_number": 1,
      "source_candidate_codes": [
        "FOX-007",
        "FOX-008"
      ]
    },
    "sort_order": 10
  },
  {
    "recipe_code": "timedoor_f15_digital_tidal_fox",
    "group_key": "main",
    "material_type": "tag",
    "card_code": null,
    "card_codes": [],
    "tag": "fusion:water_research",
    "quantity": 1,
    "allowed_zones": [
      "active",
      "bench"
    ],
    "optional": false,
    "metadata": {
      "timedoor_seed_source": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion",
      "seed_version": "2.2-learning-arcs-fusion",
      "fusion_id": "F15",
      "slot_number": 2,
      "source_candidate_codes": [
        "OTT-007",
        "OTT-008"
      ]
    },
    "sort_order": 20
  },
  {
    "recipe_code": "timedoor_f16_abyssal_shadow_sentinel",
    "group_key": "main",
    "material_type": "exact_card",
    "card_code": "NUL_008",
    "card_codes": [],
    "tag": null,
    "quantity": 1,
    "allowed_zones": [
      "active",
      "bench"
    ],
    "optional": false,
    "metadata": {
      "timedoor_seed_source": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion",
      "seed_version": "2.2-learning-arcs-fusion",
      "fusion_id": "F16",
      "slot_number": 1,
      "source_candidate_codes": [
        "NUL-008"
      ]
    },
    "sort_order": 10
  },
  {
    "recipe_code": "timedoor_f16_abyssal_shadow_sentinel",
    "group_key": "main",
    "material_type": "exact_card",
    "card_code": "TUR_008",
    "card_codes": [],
    "tag": null,
    "quantity": 1,
    "allowed_zones": [
      "active",
      "bench"
    ],
    "optional": false,
    "metadata": {
      "timedoor_seed_source": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion",
      "seed_version": "2.2-learning-arcs-fusion",
      "fusion_id": "F16",
      "slot_number": 2,
      "source_candidate_codes": [
        "TUR-008"
      ]
    },
    "sort_order": 20
  },
  {
    "recipe_code": "timedoor_f17_thunder_canopy",
    "group_key": "main",
    "material_type": "exact_card",
    "card_code": "PAN_008",
    "card_codes": [],
    "tag": null,
    "quantity": 1,
    "allowed_zones": [
      "active",
      "bench"
    ],
    "optional": false,
    "metadata": {
      "timedoor_seed_source": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion",
      "seed_version": "2.2-learning-arcs-fusion",
      "fusion_id": "F17",
      "slot_number": 1,
      "source_candidate_codes": [
        "PAN-008"
      ]
    },
    "sort_order": 10
  },
  {
    "recipe_code": "timedoor_f17_thunder_canopy",
    "group_key": "main",
    "material_type": "exact_card",
    "card_code": "RAB_008",
    "card_codes": [],
    "tag": null,
    "quantity": 1,
    "allowed_zones": [
      "active",
      "bench"
    ],
    "optional": false,
    "metadata": {
      "timedoor_seed_source": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion",
      "seed_version": "2.2-learning-arcs-fusion",
      "fusion_id": "F17",
      "slot_number": 2,
      "source_candidate_codes": [
        "RAB-008"
      ]
    },
    "sort_order": 20
  },
  {
    "recipe_code": "timedoor_f18_coded_eclipse",
    "group_key": "main",
    "material_type": "one_of",
    "card_code": null,
    "card_codes": [
      "WLF_008",
      "WLF_009"
    ],
    "tag": null,
    "quantity": 1,
    "allowed_zones": [
      "active",
      "bench"
    ],
    "optional": false,
    "metadata": {
      "timedoor_seed_source": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion",
      "seed_version": "2.2-learning-arcs-fusion",
      "fusion_id": "F18",
      "slot_number": 1,
      "source_candidate_codes": [
        "WLF-008",
        "WLF-009"
      ]
    },
    "sort_order": 10
  },
  {
    "recipe_code": "timedoor_f18_coded_eclipse",
    "group_key": "main",
    "material_type": "exact_card",
    "card_code": "NUL_008",
    "card_codes": [],
    "tag": null,
    "quantity": 1,
    "allowed_zones": [
      "active",
      "bench"
    ],
    "optional": false,
    "metadata": {
      "timedoor_seed_source": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion",
      "seed_version": "2.2-learning-arcs-fusion",
      "fusion_id": "F18",
      "slot_number": 2,
      "source_candidate_codes": [
        "NUL-008"
      ]
    },
    "sort_order": 20
  },
  {
    "recipe_code": "timedoor_f19_arc_guard",
    "group_key": "main",
    "material_type": "one_of",
    "card_code": null,
    "card_codes": [
      "COB_007",
      "COB_008"
    ],
    "tag": null,
    "quantity": 1,
    "allowed_zones": [
      "active",
      "bench"
    ],
    "optional": false,
    "metadata": {
      "timedoor_seed_source": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion",
      "seed_version": "2.2-learning-arcs-fusion",
      "fusion_id": "F19",
      "slot_number": 1,
      "source_candidate_codes": [
        "COB-007",
        "COB-008"
      ]
    },
    "sort_order": 10
  },
  {
    "recipe_code": "timedoor_f19_arc_guard",
    "group_key": "main",
    "material_type": "exact_card",
    "card_code": "TUR_008",
    "card_codes": [],
    "tag": null,
    "quantity": 1,
    "allowed_zones": [
      "active",
      "bench"
    ],
    "optional": false,
    "metadata": {
      "timedoor_seed_source": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion",
      "seed_version": "2.2-learning-arcs-fusion",
      "fusion_id": "F19",
      "slot_number": 2,
      "source_candidate_codes": [
        "TUR-008"
      ]
    },
    "sort_order": 20
  },
  {
    "recipe_code": "timedoor_f20_rabbit_afterimage",
    "group_key": "main",
    "material_type": "exact_card",
    "card_code": "RAB_008",
    "card_codes": [],
    "tag": null,
    "quantity": 1,
    "allowed_zones": [
      "active",
      "bench"
    ],
    "optional": false,
    "metadata": {
      "timedoor_seed_source": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion",
      "seed_version": "2.2-learning-arcs-fusion",
      "fusion_id": "F20",
      "slot_number": 1,
      "source_candidate_codes": [
        "RAB-008"
      ]
    },
    "sort_order": 10
  },
  {
    "recipe_code": "timedoor_f20_rabbit_afterimage",
    "group_key": "main",
    "material_type": "one_of",
    "card_code": null,
    "card_codes": [
      "FOX_007",
      "FOX_008"
    ],
    "tag": null,
    "quantity": 1,
    "allowed_zones": [
      "active",
      "bench"
    ],
    "optional": false,
    "metadata": {
      "timedoor_seed_source": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion",
      "seed_version": "2.2-learning-arcs-fusion",
      "fusion_id": "F20",
      "slot_number": 2,
      "source_candidate_codes": [
        "FOX-007",
        "FOX-008"
      ]
    },
    "sort_order": 20
  },
  {
    "recipe_code": "timedoor_f21_skyline_guardian",
    "group_key": "main",
    "material_type": "exact_card",
    "card_code": "FAL_008",
    "card_codes": [],
    "tag": null,
    "quantity": 1,
    "allowed_zones": [
      "active",
      "bench"
    ],
    "optional": false,
    "metadata": {
      "timedoor_seed_source": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion",
      "seed_version": "2.2-learning-arcs-fusion",
      "fusion_id": "F21",
      "slot_number": 1,
      "source_candidate_codes": [
        "FAL-008"
      ]
    },
    "sort_order": 10
  },
  {
    "recipe_code": "timedoor_f21_skyline_guardian",
    "group_key": "main",
    "material_type": "exact_card",
    "card_code": "WLF_008",
    "card_codes": [],
    "tag": null,
    "quantity": 1,
    "allowed_zones": [
      "active",
      "bench"
    ],
    "optional": false,
    "metadata": {
      "timedoor_seed_source": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion",
      "seed_version": "2.2-learning-arcs-fusion",
      "fusion_id": "F21",
      "slot_number": 2,
      "source_candidate_codes": [
        "WLF-008"
      ]
    },
    "sort_order": 20
  },
  {
    "recipe_code": "timedoor_f22_pico_overclock",
    "group_key": "main",
    "material_type": "exact_card",
    "card_code": "PIC_008",
    "card_codes": [],
    "tag": null,
    "quantity": 1,
    "allowed_zones": [
      "active",
      "bench"
    ],
    "optional": false,
    "metadata": {
      "timedoor_seed_source": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion",
      "seed_version": "2.2-learning-arcs-fusion",
      "fusion_id": "F22",
      "slot_number": 1,
      "source_candidate_codes": [
        "PIC-008"
      ]
    },
    "sort_order": 10
  },
  {
    "recipe_code": "timedoor_f22_pico_overclock",
    "group_key": "main",
    "material_type": "exact_card",
    "card_code": "PAN_008",
    "card_codes": [],
    "tag": null,
    "quantity": 1,
    "allowed_zones": [
      "active",
      "bench"
    ],
    "optional": false,
    "metadata": {
      "timedoor_seed_source": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion",
      "seed_version": "2.2-learning-arcs-fusion",
      "fusion_id": "F22",
      "slot_number": 2,
      "source_candidate_codes": [
        "PAN-008"
      ]
    },
    "sort_order": 20
  },
  {
    "recipe_code": "timedoor_f23_revival_circuit",
    "group_key": "main",
    "material_type": "exact_card",
    "card_code": "NUL_008",
    "card_codes": [],
    "tag": null,
    "quantity": 1,
    "allowed_zones": [
      "active",
      "bench",
      "graveyard"
    ],
    "optional": false,
    "metadata": {
      "timedoor_seed_source": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion",
      "seed_version": "2.2-learning-arcs-fusion",
      "fusion_id": "F23",
      "slot_number": 1,
      "source_candidate_codes": [
        "NUL-008"
      ]
    },
    "sort_order": 10
  },
  {
    "recipe_code": "timedoor_f23_revival_circuit",
    "group_key": "main",
    "material_type": "exact_card",
    "card_code": "OTT_008",
    "card_codes": [],
    "tag": null,
    "quantity": 1,
    "allowed_zones": [
      "active",
      "bench",
      "graveyard"
    ],
    "optional": false,
    "metadata": {
      "timedoor_seed_source": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion",
      "seed_version": "2.2-learning-arcs-fusion",
      "fusion_id": "F23",
      "slot_number": 2,
      "source_candidate_codes": [
        "OTT-008"
      ]
    },
    "sort_order": 20
  },
  {
    "recipe_code": "timedoor_f24_grand_academy_union",
    "group_key": "main",
    "material_type": "tag",
    "card_code": null,
    "card_codes": [],
    "tag": "fusion:academy_lead",
    "quantity": 1,
    "allowed_zones": [
      "active",
      "bench"
    ],
    "optional": false,
    "metadata": {
      "timedoor_seed_source": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion",
      "seed_version": "2.2-learning-arcs-fusion",
      "fusion_id": "F24",
      "slot_number": 1,
      "source_candidate_codes": [
        "COB-008",
        "TOC-008"
      ]
    },
    "sort_order": 10
  },
  {
    "recipe_code": "timedoor_f24_grand_academy_union",
    "group_key": "main",
    "material_type": "tag",
    "card_code": null,
    "card_codes": [],
    "tag": "fusion:advanced_wind",
    "quantity": 1,
    "allowed_zones": [
      "active",
      "bench"
    ],
    "optional": false,
    "metadata": {
      "timedoor_seed_source": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion",
      "seed_version": "2.2-learning-arcs-fusion",
      "fusion_id": "F24",
      "slot_number": 2,
      "source_candidate_codes": [
        "FAL-008",
        "FOX-008"
      ]
    },
    "sort_order": 20
  },
  {
    "recipe_code": "timedoor_f24_grand_academy_union",
    "group_key": "main",
    "material_type": "tag",
    "card_code": null,
    "card_codes": [],
    "tag": "fusion:research_core",
    "quantity": 1,
    "allowed_zones": [
      "active",
      "bench"
    ],
    "optional": false,
    "metadata": {
      "timedoor_seed_source": "Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion",
      "seed_version": "2.2-learning-arcs-fusion",
      "fusion_id": "F24",
      "slot_number": 3,
      "source_candidate_codes": [
        "OTT-008",
        "PAN-008"
      ]
    },
    "sort_order": 30
  }
]$timedoor_materials$::jsonb) AS s(
    recipe_code text, group_key text, material_type text, card_code text,
    card_codes text[], tag text, quantity integer, allowed_zones text[],
    optional boolean, metadata jsonb, sort_order integer
  )
)
INSERT INTO public.fusion_recipe_materials (
  recipe_id, group_key, material_type, game_card_id, element, rarity,
  min_level, max_level, quantity, allowed_zones, optional, metadata,
  card_code, card_codes, tag, sort_order
)
SELECT
  recipe.id, seed.group_key, seed.material_type, NULL, NULL, NULL,
  NULL, NULL, seed.quantity, seed.allowed_zones, seed.optional,
  seed.metadata, seed.card_code, coalesce(seed.card_codes, '{}'::text[]),
  seed.tag, seed.sort_order
FROM material_seed AS seed
JOIN public.fusion_recipes AS recipe ON recipe.code = seed.recipe_code;

-- Put each source skill in the shared skill catalog and attach it to its card.
-- The master plan gives names and descriptions, but marks combat rules as
-- unfinalized, so these catalog entries remain inactive until playtested.
WITH source_skills AS (
  SELECT
    trim(skill.value ->> 'name') AS skill_name,
    trim(coalesce(skill.value ->> 'effect', skill.value ->> 'description', '')) AS skill_description,
    coalesce((skill.value ->> 'slot')::integer, 1) AS skill_slot
  FROM public.game_cards AS card
  CROSS JOIN LATERAL jsonb_array_elements(card.metadata -> 'skills') AS skill(value)
  WHERE card.metadata ->> 'seed_version' = '2.2-learning-arcs-fusion'
    AND jsonb_typeof(card.metadata -> 'skills') = 'array'
), unique_skills AS (
  SELECT
    skill_name,
    skill_description,
    min(skill_slot) AS skill_slot,
    md5(lower(skill_name) || '|' || skill_description) AS stable_key
  FROM source_skills
  WHERE skill_name <> ''
  GROUP BY skill_name, skill_description
)
INSERT INTO public.special_skills (
  code, name, description, icon, category, skill_type, activation_timing,
  source_zones, target_spec, cost_spec, limits, effects, consumes_turn,
  priority, is_active, metadata
)
SELECT
  'timedoor_catalog_' || stable_key,
  skill_name,
  nullif(skill_description, ''),
  '✦',
  'card_catalog',
  'active',
  'main_phase',
  ARRAY['active']::text[],
  '{}'::jsonb,
  '{}'::jsonb,
  '{}'::jsonb,
  '[]'::jsonb,
  true,
  skill_slot * 10,
  false,
  jsonb_build_object(
    'catalog_only', true,
    'source_document', 'Timedoor_Battle_Cards_Master_Plan_v2_2_Learning_Arcs_Fusion.docx',
    'rules_status', 'description_only_pending_playtest'
  )
FROM unique_skills
ON CONFLICT (code) DO NOTHING;

WITH source_skills AS (
  SELECT
    card.id AS game_card_id,
    trim(skill.value ->> 'name') AS skill_name,
    trim(coalesce(skill.value ->> 'effect', skill.value ->> 'description', '')) AS skill_description,
    coalesce((skill.value ->> 'slot')::integer, 1) AS skill_slot
  FROM public.game_cards AS card
  CROSS JOIN LATERAL jsonb_array_elements(card.metadata -> 'skills') AS skill(value)
  WHERE card.metadata ->> 'seed_version' = '2.2-learning-arcs-fusion'
    AND jsonb_typeof(card.metadata -> 'skills') = 'array'
)
INSERT INTO public.game_card_special_skills (
  game_card_id, special_skill_id, sort_order, enabled, overrides
)
SELECT
  source.game_card_id,
  catalog.id,
  source.skill_slot * 10,
  true,
  '{}'::jsonb
FROM source_skills AS source
JOIN public.special_skills AS catalog
  ON catalog.code = 'timedoor_catalog_' || md5(
    lower(source.skill_name) || '|' || source.skill_description
  )
WHERE source.skill_name <> ''
ON CONFLICT (game_card_id, special_skill_id)
DO UPDATE SET
  sort_order = excluded.sort_order,
  enabled = true;

COMMIT;
