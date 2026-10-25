"""Rebuild the isolated pilot dataset from the audited DOCX; never writes Supabase."""
import argparse
import hashlib
import json
import re
from pathlib import Path
from xml.etree import ElementTree as ET
from zipfile import ZipFile

ROOT = Path(__file__).resolve().parents[2]
NS = {"w": "http://schemas.openxmlformats.org/wordprocessingml/2006/main"}


def extract(path):
    with ZipFile(path) as archive:
        document = ET.fromstring(archive.read("word/document.xml"))
    tables = []
    for table in document.findall(".//w:tbl", NS):
        tables.append([
            ["\n".join("".join(t.text or "" for t in p.findall(".//w:t", NS))
                       for p in cell.findall(".//w:p", NS)).strip()
             for cell in row.findall("w:tc", NS)]
            for row in table.findall("w:tr", NS)
        ])
    cards, recipes = [], []
    for table_index in range(2, 7):
        for row_index, row in enumerate(tables[table_index][1:], 1):
            fusion = table_index >= 5
            code, name, type_, rarity, role, stats = row[:6]
            hp, attack, defense = map(int, re.findall(r"\d+", stats))
            skill_texts = row[7:9] if fusion else row[6:8]
            skills = []
            for text in skill_texts:
                title, description = text.split(" — ", 1)
                cooldown = re.search(r"CD (\d+)", description)
                ap = re.search(r"(\d+) AP", description)
                skills.append({"name": title, "description": description, "source_text": text,
                               "cooldown_turns": int(cooldown[1]) if cooldown else None,
                               "ap_cost": int(ap[1]) if ap else None,
                               "once_per_battle": "Sekali/battle" in description,
                               "effect_clauses": re.split(r";\s*", description)})
            card = {"card_code": code, "name": name, "kind": "fusion" if fusion else "base",
                    "type": type_, "rarity": rarity, "role": role,
                    "stats": {"hp": hp, "attack": attack, "defense": defense},
                    "skills": skills, "tags": [],
                    "source_fusions": [] if fusion else re.findall(r"F\d{2}", row[8]),
                    "source": {"table": table_index, "row": row_index},
                    "production_mapping": {"card_code": code.replace("-", "_"), "rfid_uid": None}}
            if code == "NUL-006":
                card["necro_recall"] = {"once_per_battle": True, "ap_cost": 2,
                    "requires_caster_zone": "active", "material_kind": "base", "allow_fusion": False,
                    "allow_fusion_consumed": False, "destination": "bench", "max_hp_ratio": 0.4,
                    "attack_skill_locked_until_next_turn": True, "reset_once_per_battle": False}
            cards.append(card)
            if fusion:
                raw = row[6]
                mode = "TAG" if raw.startswith("[TAG]") else "ONE_OF" if raw.startswith("[ONE_OF]") else "EXACT"
                slots = []
                if mode == "TAG":
                    for tag, eligible in re.findall(r"(fusion:\w+)\s*\[([^]]+)\]", raw):
                        slots.append({"mode": "TAG", "tag": tag, "eligible_codes": re.findall(r"[A-Z]{3}-\d{3}", eligible)})
                else:
                    for part in re.sub(r"^\[[^]]+\]\s*", "", raw).split(" + "):
                        eligible = re.findall(r"[A-Z]{3}-\d{3}", part)
                        slots.append({"mode": "ONE_OF" if len(eligible) > 1 else "EXACT", "eligible_codes": eligible})
                recipes.append({"id": code, "result_code": code, "mode": mode,
                                "source_text": raw, "slots": slots, "ap_cost": 2,
                                "consumed_reason": "fusion_consumed", "attack_locked_on_summon": True})
    by_code = {card["card_code"]: card for card in cards}
    for recipe in recipes:
        for slot in recipe["slots"]:
            if slot["mode"] == "TAG":
                for code in slot["eligible_codes"]:
                    if slot["tag"] not in by_code[code]["tags"]:
                        by_code[code]["tags"].append(slot["tag"])
    assert len(cards) == 42 and len(recipes) == 12
    assert sum(card["kind"] == "base" for card in cards) == 30
    assert len(by_code) == 42
    return {"id": "tbc-pilot-v1.1-audited-necromancer", "version": "1.1.0",
            "expected_counts": {"base": 30, "fusion": 12},
            "source_document": path.name, "source_sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
            "types": [row[0] for row in tables[1][1:]],
            "rules": {"fusion_ap": 2, "signature_fusions_active_per_player": 1,
                      "shield_stacks": False, "heal_cap": "max_hp", "root_blocks": "voluntary_switch_only"},
            "cards": cards, "recipes": recipes}


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("docx", type=Path)
    args = parser.parse_args()
    data = extract(args.docx)
    target = ROOT / "src/data/card-generator/pilot-v1.1.json"
    target.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n")
    print(f"Extracted {len(data['cards'])} cards and {len(data['recipes'])} recipes → {target}")
