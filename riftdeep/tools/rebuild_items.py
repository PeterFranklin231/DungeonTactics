#!/usr/bin/env python3
"""Rebuilds data/items.json for the FF3 / Disgaea style progression (levels 1-90).

Weapons come from the "Base Working" sheet of the balance workbook (the left block only):
41 steps per weapon type, each with a tier (1-8), a step (the "+N" in the name, from the
Slots column), flat Damage Scale, Damage Dice and a minimum level. Fists copy the dagger line.
Armour, shields and jewellery are stretched from 5 to 8 tiers on the same level curve.
Affix tiers are spread to level 95 and gain three stronger tiers. Uniques move onto the
new bases nearest their old level.

    python3 tools/rebuild_items.py workbook.xlsx [data/items.json]
"""
import json
import re
import sys

import openpyxl

ARMOUR_LEVELS = [1, 10, 20, 30, 45, 60, 75, 90]
OLD_LEVELS = [1, 5, 10, 15, 20]
AFFIX_OLD_TO_NEW = [1, 12, 25, 40, 55]
AFFIX_EXTRA_LEVELS = [70, 82, 95]
FLAT_GROWTH = [1.35, 1.75, 2.2]
PCT_GROWTH = [1.15, 1.3, 1.45]

MATERIALS = {
    "sword": ["Bronze", "Iron", "Steel", "Silver", "Mithril", "Adamant", "Runic", "Celestial"],
    "axe": ["Bronze", "Iron", "Steel", "Silver", "Mithril", "Adamant", "Runic", "Celestial"],
    "dagger": ["Bronze", "Iron", "Steel", "Silver", "Mithril", "Adamant", "Runic", "Celestial"],
    "fist": ["Leather", "Iron", "Steel", "Silver", "Mithril", "Adamant", "Runic", "Celestial"],
    "bow": ["Ash", "Yew", "Horn", "Elven", "Wyrmhorn", "Stormwood", "Runic", "Celestial"],
    "wand": ["Driftwood", "Bone", "Crystal", "Runed", "Moonsilver", "Starlit", "Archon", "Celestial"],
    "staff": ["Driftwood", "Bone", "Crystal", "Runed", "Moonsilver", "Starlit", "Archon", "Celestial"],
}
NOUNS = {"sword": "Sword", "axe": "Greataxe", "dagger": "Dagger", "fist": "Knuckles", "bow": "Bow", "wand": "Wand", "staff": "Staff"}
LABELS = {"sword": "One-Handed Sword", "axe": "Two-Handed Axe", "dagger": "Dagger", "fist": "Fist Weapon",
          "bow": "Bow (two-handed, needed to Shoot)", "wand": "Wand", "staff": "Two-Handed Staff"}
STYLES = {"sword": "str", "axe": "str", "dagger": "dex", "fist": "dex", "bow": "dex", "wand": "int", "staff": "int"}
TWO_HANDED = {"axe", "bow", "staff"}

EXTRA_NAMES = {
    ("body", "str"): ["Dragonplate", "Runeplate", "Celestial Plate"],
    ("body", "dex"): ["Nightweave Coat", "Phantom Garb", "Celestial Leathers"],
    ("body", "int"): ["Starweave Robe", "Astral Raiment", "Celestial Robe"],
    ("helm", "str"): ["Dragon Helm", "Rune Helm", "Celestial Helm"],
    ("helm", "dex"): ["Nightweave Hood", "Phantom Mask", "Celestial Hood"],
    ("helm", "int"): ["Starweave Circlet", "Astral Crown", "Celestial Crown"],
    ("gloves", "str"): ["Dragon Gauntlets", "Rune Gauntlets", "Celestial Gauntlets"],
    ("gloves", "dex"): ["Nightweave Gloves", "Phantom Grips", "Celestial Gloves"],
    ("gloves", "int"): ["Starweave Gloves", "Astral Wraps", "Celestial Handwraps"],
    ("boots", "str"): ["Dragon Greaves", "Rune Sabatons", "Celestial Greaves"],
    ("boots", "dex"): ["Nightweave Boots", "Phantom Treads", "Celestial Boots"],
    ("boots", "int"): ["Starweave Slippers", "Astral Treads", "Celestial Slippers"],
    ("shield", "str"): ["Dragon Aegis", "Rune Bulwark", "Celestial Aegis"],
    ("shield", "dex"): ["Nightweave Targe", "Phantom Targe", "Celestial Targe"],
    ("shield", "int"): ["Starweave Ward", "Astral Ward", "Celestial Ward"],
    ("ring", "none"): ["Mithril Ring", "Runic Ring", "Celestial Ring"],
    ("amulet", "none"): ["Ruby Amulet", "Runic Amulet", "Celestial Amulet"],
}


def dmg_curve(lv):
    """Typical monster hit at a level - armour keeps pace with it."""
    return 3 + 1.3 * lv + 0.002 * lv * lv


def req_stat(lv):
    return 0 if lv <= 1 else int(round(lv * 0.8))


def parse_dice(s):
    s = str(s).strip().lower()
    m = re.fullmatch(r"(\d*)d(\d+)", s)
    if not m:
        raise ValueError("bad dice " + s)
    return int(m.group(1) or 1), int(m.group(2))


def lerp_old(vals, f):
    """vals at old tiers 0..4, f in 0..1 across the old range."""
    x = f * 4.0
    i = min(3, int(x))
    return vals[i] + (vals[i + 1] - vals[i]) * (x - i)


def weapons_from_sheet(xlsx, old_bases):
    wb = openpyxl.load_workbook(xlsx, data_only=True)
    ws = wb["Base Working"]
    rows = []
    for r in ws.iter_rows(min_row=2, values_only=True):
        if not r[0] or not r[2]:
            continue
        rows.append({"id": str(r[0]).strip(), "kind": str(r[2]).strip(), "tier": int(r[4]), "step": int(r[5] or 0),
                     "flat": int(float(r[6])), "dice": str(r[7]).strip(), "min_level": int(r[8])})
    by_kind = {}
    for r in rows:
        by_kind.setdefault(r["kind"], []).append(r)
    # fists follow the dagger line
    by_kind["fist"] = [dict(r, id=r["id"].replace("dagger", "fist"), kind="fist") for r in by_kind["dagger"]]
    old_imp = {}
    for b in old_bases:
        if b["cat"] == "weapon":
            old_imp.setdefault(b["kind"], [None] * 5)[b["tier"] - 1] = b.get("imp", {})
    out = []
    for kind, lst in by_kind.items():
        for r in lst:
            n, sides = parse_dice(r["dice"])
            lv = r["min_level"]
            f = (lv - 1) / 89.0
            imp = {}
            oi = old_imp.get(kind)
            if oi:
                for k in oi[0]:
                    v0, v4 = oi[0][k], oi[4][k]
                    if k == "mp":    # flat: grows with level like the old curve did
                        imp[k] = int(round(v0 + (v4 - v0) * (lv - 1) / 19.0))
                    else:            # percentages: 1.5x the old spread at the top
                        imp[k] = int(round(v0 + (v4 - v0) * 1.5 * f))
            name = "%s %s" % (MATERIALS[kind][r["tier"] - 1], NOUNS[kind])
            if r["step"] > 0:
                name += " +%d" % r["step"]
            out.append({"id": r["id"], "name": name, "cat": "weapon", "kind": kind, "style": STYLES[kind], "tier": r["tier"],
                        "req_level": lv, "req_stat": req_stat(lv), "two_handed": kind in TWO_HANDED,
                        "drop_weight": 4.0 if kind == "fist" else 5.0, "imp": imp, "label": LABELS[kind],
                        "dice": r["dice"], "dmg_flat": r["flat"], "dmg_min": n + r["flat"], "dmg_max": n * sides + r["flat"]})
    return out


def armour_eight(old_bases):
    fam = {}
    for b in old_bases:
        if b["cat"] != "weapon":
            fam.setdefault((b["cat"], b["style"]), [None] * 5)[b["tier"] - 1] = b
    out = []
    pct_keys = {"evasion", "magic_res", "all_res", "crit", "spell_dmg"}
    s1, s20 = dmg_curve(1), dmg_curve(20)
    for (cat, style), tiers in fam.items():
        names = [t["name"] for t in tiers] + EXTRA_NAMES[(cat, style)]
        for k in range(8):
            lv = ARMOUR_LEVELS[k]
            f = k / 7.0
            imp = {}
            for key in tiers[0].get("imp", {}):
                v0 = tiers[0]["imp"][key]
                v4 = tiers[4]["imp"][key]
                if key == "def":
                    v = v0 + (v4 - v0) * (dmg_curve(lv) - s1) / (s20 - s1)
                elif key in ("mp", "all_attr"):
                    v = v0 + (v4 - v0) * (lv - 1) / 19.0
                else:
                    v = v0 + (v4 - v0) * 1.5 * f
                imp[key] = max(1, int(round(v)))
            prefix = "%s_%s" % (cat, style) if style != "none" else cat
            base = dict(tiers[min(k, 4)])
            base.update({"id": "%s_%d" % (prefix, k), "name": names[k], "tier": k + 1, "req_level": lv,
                         "req_stat": req_stat(lv) if style != "none" else 0, "imp": imp})
            out.append(base)
    return out


def affixes_extended(affixes, pct_keys):
    out = []
    for a in affixes:
        a = json.loads(json.dumps(a))
        trs = a["tiers"]
        for i, tr in enumerate(trs[:5]):
            tr["min_ilvl"] = AFFIX_OLD_TO_NEW[min(i, 4)]
        is_pct = a["stat"] in pct_keys
        is_range = bool(a.get("range", False))
        if is_range:
            # "Adds X-Y damage": weapons hit softer on this curve, so these are scaled down to ~40% of a weapon
            for tr in trs:
                tr["min"] = max(1, int(round(tr["min"] * 0.65)))
                tr["max"] = max(tr["min"] + 1, int(round(tr["max"] * 0.65)))
        top = trs[-1]
        growth = PCT_GROWTH if (is_pct or is_range) else FLAT_GROWTH
        for j, adj in enumerate(["Greater", "Elder", "Eternal"]):
            nm = top["name"]
            if nm.startswith("of the "):
                nm = "of the %s %s" % (adj, nm[7:])
            elif nm.startswith("of "):
                nm = "of %s %s" % (adj, nm[3:])
            else:
                nm = "%s %s" % (adj, nm)
            lo = max(1, int(round(top["min"] * growth[j])))
            hi = max(lo, int(round(top["max"] * growth[j])))
            trs.append({"name": nm, "min_ilvl": AFFIX_EXTRA_LEVELS[j], "min": lo, "max": hi})
        out.append(a)
    return out


def main():
    xlsx = sys.argv[1]
    path = sys.argv[2] if len(sys.argv) > 2 else "data/items.json"
    data = json.load(open(path))
    old_bases = data["bases"]
    old_by_id = {b["id"]: b for b in old_bases}
    weapons = weapons_from_sheet(xlsx, old_bases)
    armour = armour_eight(old_bases)
    new_bases = weapons + armour
    # uniques: move onto the new base nearest the old base's level
    for u in data["uniques"]:
        ob = old_by_id.get(u["base"])
        if ob is None:
            continue
        old_lv = max(1, ob["req_level"])
        cands = [b for b in new_bases if b["cat"] == ob["cat"] and b["kind"] == ob["kind"] and b["style"] == ob["style"]]
        if ob["cat"] == "weapon":
            cands = [b for b in cands if "+" not in b["name"]] or cands
        best = min(cands, key=lambda b: (abs(b["req_level"] - old_lv), b["req_level"]))
        u["base"] = best["id"]
    data["bases"] = new_bases
    data["affixes"] = affixes_extended(data["affixes"], set(data.get("pct_keys", [])))
    st = data["settings"]["tiers"]
    st["req_level"] = ARMOUR_LEVELS[:]
    st["req_stat"] = [req_stat(l) for l in ARMOUR_LEVELS]
    st["affix_min_ilvl"] = AFFIX_OLD_TO_NEW + AFFIX_EXTRA_LEVELS
    st["value"] = [int(10 + 3 * l + 0.15 * l * l) for l in ARMOUR_LEVELS]
    data["settings"]["max_level"] = 90
    json.dump(data, open(path, "w"), indent="\t")
    print("wrote %s: %d bases (%d weapons), %d affixes, %d uniques" % (path, len(new_bases), len(weapons), len(data["affixes"]), len(data["uniques"])))


if __name__ == "__main__":
    main()
