#!/usr/bin/env python3
"""Item balance spreadsheet <-> game data.

    python3 tools/items_sheet.py export [data/items.json] [item_balance.xlsx]
    python3 tools/items_sheet.py import item_balance.xlsx [data/items.json]

`export` writes a formatted workbook from the game's item data.
`import` reads an edited workbook back, checks it, and rewrites data/items.json
(the file the game loads at startup - see scripts/autoload/loot.gd).
"""
import json
import re
import sys
from openpyxl import Workbook, load_workbook
from openpyxl.comments import Comment
from openpyxl.styles import Alignment, Border, Font, PatternFill, Side
from openpyxl.utils import get_column_letter
from openpyxl.worksheet.datavalidation import DataValidation

FONT = "Arial"
HEAD_FILL = PatternFill("solid", fgColor="1F2A44")
HEAD_FONT = Font(name=FONT, bold=True, color="FFFFFF", size=10)
BODY_FONT = Font(name=FONT, size=10)
REF_FONT = Font(name=FONT, size=10, color="6B7280", italic=True)
REF_FILL = PatternFill("solid", fgColor="EEF0F4")
TITLE_FONT = Font(name=FONT, bold=True, size=14, color="1F2A44")
THIN = Side(style="thin", color="D5D9E2")
GRID = Border(bottom=THIN)

IMP_KEYS = ["def", "evasion", "mp", "magic_res", "crit", "spell_dmg", "all_res", "all_attr"]
IMP_HEAD = {"def": "armour", "evasion": "evasion_pct", "mp": "max_mp", "magic_res": "magic_res_pct", "crit": "crit_pct",
            "spell_dmg": "spell_dmg_pct", "all_res": "all_res_pct", "all_attr": "all_attributes"}
CATS = ["weapon", "body", "helm", "gloves", "boots", "shield", "ring", "amulet"]
KINDS = ["sword", "axe", "dagger", "fist", "bow", "wand", "staff", "body", "helm", "gloves", "boots", "shield", "ring", "amulet"]
STYLES = ["str", "dex", "int", "none"]
GROUPS = ["weapon", "armour", "jewel"]
MAX_MODS = 6


# ---------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------
def table(ws, headers, rows, widths, ref_cols=(), start_row=1, notes=None):
    """Writes a header row + data rows. ref_cols = header names that are reference / formulas (greyed)."""
    for c, h in enumerate(headers, 1):
        cell = ws.cell(row=start_row, column=c, value=h)
        cell.font = HEAD_FONT
        cell.fill = HEAD_FILL
        cell.alignment = Alignment(horizontal="center", vertical="center", wrap_text=True)
        if notes and h in notes:
            cell.comment = Comment(notes[h], "item_balance")
    for r, row in enumerate(rows, start_row + 1):
        for c, h in enumerate(headers, 1):
            v = row.get(h)
            cell = ws.cell(row=r, column=c, value=v)
            cell.font = REF_FONT if h in ref_cols else BODY_FONT
            if h in ref_cols:
                cell.fill = REF_FILL
            cell.border = GRID
    for c, wdt in enumerate(widths, 1):
        ws.column_dimensions[get_column_letter(c)].width = wdt
    ws.row_dimensions[start_row].height = 30
    ws.freeze_panes = ws.cell(row=start_row + 1, column=2)
    last = get_column_letter(len(headers))
    ws.auto_filter.ref = f"A{start_row}:{last}{start_row + max(1, len(rows))}"


def add_list_validation(ws, col_letter, options, first_row, last_row):
    dv = DataValidation(type="list", formula1='"' + ",".join(options) + '"', allow_blank=True)
    dv.error = "Pick one of: " + ", ".join(options)
    ws.add_data_validation(dv)
    dv.add(f"{col_letter}{first_row}:{col_letter}{last_row}")


def col_of(headers, name):
    return get_column_letter(headers.index(name) + 1)


def fmt_mult(d):
    return ", ".join(f"{k}={_num(v)}" for k, v in d.items())


def _num(v):
    if isinstance(v, float) and v.is_integer():
        return int(v)
    return v


# ---------------------------------------------------------------------------
# export
# ---------------------------------------------------------------------------
def export(json_path, xlsx_path):
    data = json.load(open(json_path))
    wb = Workbook()

    # --- Read me
    ws = wb.active
    ws.title = "Read me"
    lines = [
        ("Item balance workbook", TITLE_FONT),
        ("Every item number the game uses lives in this workbook. Edit it, then hand it back and it is converted into data/items.json, which the game loads.", BODY_FONT),
        ("", BODY_FONT),
        ("How to edit", Font(name=FONT, bold=True, size=11)),
        ("- White cells are yours to change. Grey cells are reference or formulas and are ignored when the workbook is read back.", BODY_FONT),
        ("- Don't rename sheets or header cells. You can reorder or add columns of your own notes to the right; unknown columns are ignored.", BODY_FONT),
        ("- Add a row to add an item, affix tier or unique; delete a row to remove one. ids must be unique and use letters, digits and underscores.", BODY_FONT),
        ("- Changing an id breaks items players already own that use it, so prefer changing names and numbers instead.", BODY_FONT),
        ("- Hover a header for what the column means.", BODY_FONT),
        ("", BODY_FONT),
        ("Sheets", Font(name=FONT, bold=True, size=11)),
        ("Settings - tier requirements, item values, rarity drop chances, affix counts.", BODY_FONT),
        ("Bases - every base item: weapons, armour, shields, rings, amulets, with damage, implicit stats and drop weight.", BODY_FONT),
        ("Affixes - each prefix and suffix: the stat it rolls, how common it is, and which items it can appear on.", BODY_FONT),
        ("Affix Tiers - the name, minimum item level and roll range of each affix tier.", BODY_FONT),
        ("Uniques - fixed named items and their mods.", BODY_FONT),
        ("Stat Keys - every stat a mod can use and how it reads in game. Categories - valid category, kind, style and group keys.", BODY_FONT),
        ("", BODY_FONT),
        ("How drops work", Font(name=FONT, bold=True, size=11)),
        ("1. A monster of level L drops from every item family (category + kind + style): each family offers its best base whose req_level is at most L + 2, sometimes a slightly older one.", BODY_FONT),
        ("2. One family is picked at random, weighted by drop_weight (so a weight of 10 is twice as common as 5). Weapons with dice roll dice + dmg_flat.", BODY_FONT),
        ("3. Rarity is rolled from the drop chances on Settings. Magic items get 1-2 affixes, rares get rare_affix_min..max.", BODY_FONT),
        ("4. Each affix is picked by weight x the multipliers that match the item (its category, kind, style and group). An 'allowed on' list restricts it entirely.", BODY_FONT),
        ("5. The affix rolls one of the two best tiers the item level allows, then a value between that tier's min and max.", BODY_FONT),
        ("   For 'Adds X-Y damage' affixes (range = yes) min is the low end and max the high end; each end wobbles by about 1.", BODY_FONT),
        ("Percent stats are entered as whole numbers: 8 means 8%.", BODY_FONT),
    ]
    for i, (text, font) in enumerate(lines, 1):
        c = ws.cell(row=i, column=1, value=text)
        c.font = font
        c.alignment = Alignment(wrap_text=True, vertical="top")
    ws.column_dimensions["A"].width = 130

    # --- Settings
    ws = wb.create_sheet("Settings")
    s = data["settings"]
    t = s["tiers"]
    ws["A1"] = "Tiers"
    ws["A1"].font = Font(name=FONT, bold=True, size=12, color="1F2A44")
    n_tiers = len(t["req_level"])
    headers = ["setting"] + [f"tier_{i + 1}" for i in range(n_tiers)] + ["notes"]
    rows = [
        {"setting": "req_level", "notes": "Character level needed to equip a base of this tier."},
        {"setting": "req_stat", "notes": "STR / DEX / INT needed for styled gear of this tier (0 = none)."},
        {"setting": "affix_min_ilvl", "notes": "Default minimum item level for each affix tier (Affix Tiers can override per tier)."},
        {"setting": "value", "notes": "Base sell value in gold before rarity."},
    ]
    for r in rows:
        for i in range(n_tiers):
            r[f"tier_{i + 1}"] = t[r["setting"]][i]
    table(ws, headers, rows, [20, 10, 10, 10, 10, 10, 70], ref_cols=("notes",), start_row=2)
    ws["A8"] = "Rules"
    ws["A8"].font = Font(name=FONT, bold=True, size=12, color="1F2A44")
    rules = [
        ("normal_magic_chance", s["drop_chances"]["normal"]["magic"], "Monster drop: chance an item is magic (0.32 = 32%)."),
        ("normal_rare_chance", s["drop_chances"]["normal"]["rare"], "Monster drop: chance an item is rare."),
        ("normal_unique_chance", s["drop_chances"]["normal"]["unique"], "Monster drop: chance an item is unique."),
        ("boss_magic_chance", s["drop_chances"]["boss"]["magic"], "Boss drop: chance magic."),
        ("boss_rare_chance", s["drop_chances"]["boss"]["rare"], "Boss drop: chance rare."),
        ("boss_unique_chance", s["drop_chances"]["boss"]["unique"], "Boss drop: chance unique."),
        ("magic_two_affix_chance", s["magic_two_affix_chance"], "Chance a magic item gets both a prefix and a suffix (otherwise one)."),
        ("rare_affix_min", s["rare_affix_min"], "Fewest affixes on a rare item."),
        ("rare_affix_max", s["rare_affix_max"], "Most affixes on a rare item (max 3 prefixes + 3 suffixes)."),
        ("value_mult_normal", s["rarity_value_mult"]["normal"], "Sell value multiplier for normal items."),
        ("value_mult_magic", s["rarity_value_mult"]["magic"], "Sell value multiplier for magic items."),
        ("value_mult_rare", s["rarity_value_mult"]["rare"], "Sell value multiplier for rare items."),
        ("value_mult_unique", s["rarity_value_mult"]["unique"], "Sell value multiplier for uniques."),
        ("jewel_value_mult", s.get("jewel_value_mult", 1.2), "Extra sell value multiplier for rings and amulets."),
    ]
    table(ws, ["setting", "value", "notes"], [{"setting": a, "value": b, "notes": c} for a, b, c in rules],
          [24, 10, 70], ref_cols=("notes",), start_row=9)
    ws.freeze_panes = None

    # --- Bases
    ws = wb.create_sheet("Bases")
    headers = ["id", "name", "category", "kind", "style", "tier", "req_level", "req_stat", "two_handed", "dice", "dmg_flat", "dmg_min", "dmg_max", "avg_dmg"] + \
              [IMP_HEAD[k] for k in IMP_KEYS] + ["drop_weight", "type_label"]
    rows = []
    for b in sorted(data["bases"], key=lambda b: (CATS.index(b["cat"]), KINDS.index(b["kind"]) if b["kind"] in KINDS else 99, b["style"], b["tier"])):
        r = {"id": b["id"], "name": b["name"], "category": b["cat"], "kind": b["kind"], "style": b["style"], "tier": b["tier"],
             "req_level": b["req_level"], "req_stat": b["req_stat"], "two_handed": "yes" if b["two_handed"] else "no",
             "dice": b.get("dice"), "dmg_flat": b.get("dmg_flat"),
             "dmg_min": b.get("dmg_min"), "dmg_max": b.get("dmg_max"), "drop_weight": _num(b["drop_weight"]), "type_label": b.get("label") or None}
        for k in IMP_KEYS:
            r[IMP_HEAD[k]] = b["imp"].get(k)
        rows.append(r)
    notes = {
        "id": "Unique key. Saved items refer to it - avoid changing existing ids.",
        "category": "weapon, body, helm, gloves, boots, shield, ring or amulet.",
        "kind": "Weapon type (sword, axe, dagger, fist, bow, wand, staff) or the same as category for other gear.",
        "style": "str / dex / int - which stat it needs and which gear family it belongs to. none for rings and amulets.",
        "tier": "1-8. Material tier (weapons) or armour tier.",
        "dice": "Weapons: damage dice, e.g. d8, 2d8, 4d12. When set, dmg_min / dmg_max are worked out from dice + dmg_flat.",
        "dmg_flat": "Weapons: flat damage added to the dice roll (the Damage Scale).",
        "req_level": "Level needed to equip.",
        "req_stat": "STR / DEX / INT needed (the style's stat).",
        "two_handed": "yes = uses both hands.",
        "dmg_min": "Weapons: physical damage roll before stats.",
        "avg_dmg": "Formula: average of the roll. Ignored on import.",
        "armour": "Implicit Armour.", "evasion_pct": "Implicit Evasion, in %.", "max_mp": "Implicit maximum MP.",
        "magic_res_pct": "Implicit magic resistance, %.", "crit_pct": "Implicit critical chance, %.",
        "spell_dmg_pct": "Implicit spell damage, %.", "all_res_pct": "Implicit all resistances, %.", "all_attributes": "Implicit +STR/DEX/CON/INT.",
        "drop_weight": "Relative chance within its tier. 10 drops twice as often as 5. 0 = never drops.",
        "type_label": "Weapons: the type line shown on the item.",
    }
    table(ws, headers, rows, [16, 22, 10, 9, 7, 6, 9, 9, 9, 7, 8, 8, 8, 8] + [10] * len(IMP_KEYS) + [10, 30], ref_cols=("avg_dmg",), notes=notes)
    a, b_ = col_of(headers, "dmg_min"), col_of(headers, "dmg_max")
    avg = col_of(headers, "avg_dmg")
    for r in range(2, len(rows) + 2):
        ws[f"{avg}{r}"] = f'=IF({a}{r}="","",({a}{r}+{b_}{r})/2)'
        ws[f"{avg}{r}"].number_format = "0.0"
    n = len(rows) + 200
    add_list_validation(ws, col_of(headers, "category"), CATS, 2, n)
    add_list_validation(ws, col_of(headers, "style"), STYLES, 2, n)
    add_list_validation(ws, col_of(headers, "two_handed"), ["yes", "no"], 2, n)

    # --- Affixes
    ws = wb.create_sheet("Affixes")
    stat_text = data.get("stat_text", {})
    headers = ["id", "type", "stat", "reads_as", "range", "weight", "allowed_on", "weight_multipliers"]
    rows = []
    for af in sorted(data["affixes"], key=lambda a: (a["type"] != "prefix", a["id"])):
        rows.append({"id": af["id"], "type": af["type"], "stat": af["stat"], "reads_as": stat_text.get(af["stat"], ""),
                     "range": "yes" if af["range"] else "no", "weight": _num(af["weight"]),
                     "allowed_on": ", ".join(af.get("only", [])) or None, "weight_multipliers": fmt_mult(af.get("mult", {})) or None})
    notes = {
        "type": "prefix or suffix. Items get up to 3 of each.",
        "stat": "Stat key it adds (see Stat Keys).",
        "reads_as": "How the stat reads in game. Reference only.",
        "range": "yes = 'Adds X-Y damage' style (two numbers). no = one number.",
        "weight": "Base chance to be picked, relative to other affixes of the same type.",
        "allowed_on": "Blank = any item. Otherwise a comma list of categories or groups (weapon, armour, jewel, body, ring...).",
        "weight_multipliers": "key=multiplier pairs, e.g. 'int=2, wand=2.5, armour=0.03'. Keys can be a category, weapon kind, style or group. 0 = never on that.",
    }
    table(ws, headers, rows, [14, 9, 14, 40, 7, 8, 22, 70], ref_cols=("reads_as",), notes=notes)
    add_list_validation(ws, "B", ["prefix", "suffix"], 2, len(rows) + 100)
    add_list_validation(ws, "E", ["yes", "no"], 2, len(rows) + 100)

    # --- Affix Tiers
    ws = wb.create_sheet("Affix Tiers")
    headers = ["affix_id", "tier", "name", "min_item_level", "min", "max", "average"]
    rows = []
    for af in sorted(data["affixes"], key=lambda a: (a["type"] != "prefix", a["id"])):
        for i, tr in enumerate(af["tiers"], 1):
            rows.append({"affix_id": af["id"], "tier": i, "name": tr["name"], "min_item_level": tr["min_ilvl"], "min": tr["min"], "max": tr["max"]})
    notes = {
        "affix_id": "Which affix (Affixes sheet id).",
        "tier": "1 = weakest. Tiers are used in order.",
        "name": "Prefix name (Sharp Sword) or suffix name (Sword of the Bear) for magic items.",
        "min_item_level": "Lowest item level that can roll this tier.",
        "min": "Lowest roll. For range affixes: the low end of 'Adds X-Y'.",
        "max": "Highest roll. For range affixes: the high end.",
        "average": "Formula. Ignored on import.",
    }
    table(ws, headers, rows, [14, 6, 20, 14, 8, 8, 9], ref_cols=("average",), notes=notes)
    for r in range(2, len(rows) + 2):
        ws[f"G{r}"] = f"=(E{r}+F{r})/2"
        ws[f"G{r}"].number_format = "0.0"

    # --- Uniques
    ws = wb.create_sheet("Uniques")
    headers = ["id", "name", "base", "base_name", "boss_only", "drop_weight", "flavor"]
    for i in range(1, MAX_MODS + 1):
        headers += [f"mod{i}_stat", f"mod{i}_value", f"mod{i}_value2"]
    rows = []
    for u in data["uniques"]:
        r = {"id": u["id"], "name": u["name"], "base": u["base"], "boss_only": "yes" if u["boss_only"] else "no",
             "drop_weight": _num(u.get("drop_weight", 1)), "flavor": u["flavor"]}
        for i, m in enumerate(u["mods"][:MAX_MODS], 1):
            r[f"mod{i}_stat"] = m["k"]
            r[f"mod{i}_value"] = m["v"]
            r[f"mod{i}_value2"] = m.get("v2")
        rows.append(r)
    notes = {
        "base": "Bases sheet id the unique is built on (its damage / implicits / requirements come from there).",
        "base_name": "Formula: the base's name. Ignored on import.",
        "boss_only": "yes = only from a boss's guaranteed drop or a quest, never random.",
        "drop_weight": "Relative chance among uniques that can drop at that level.",
        "mod1_stat": "Stat key (see Stat Keys).", "mod1_value": "Value (percent stats as whole numbers).",
        "mod1_value2": "Only for 'Adds X-Y' stats: the high end.",
    }
    table(ws, headers, rows, [20, 26, 14, 18, 9, 9, 44] + [12, 8, 8] * MAX_MODS, ref_cols=("base_name",), notes=notes)
    for r in range(2, len(rows) + 2):
        ws[f"D{r}"] = f'=IFERROR(INDEX(Bases!$B:$B,MATCH(C{r},Bases!$A:$A,0)),"unknown base!")'
    add_list_validation(ws, "E", ["yes", "no"], 2, len(rows) + 100)

    # --- Stat Keys (reference)
    ws = wb.create_sheet("Stat Keys")
    pct = set(data.get("pct_keys", []))
    tenths = set(data.get("tenths_keys", []))
    rows = []
    for k, txt in stat_text.items():
        unit = "percent" if k in pct else ("tenths of a second" if k in tenths else ("range (two numbers)" if k.startswith("add_") else "flat"))
        rows.append({"stat_key": k, "reads_as": txt, "unit": unit})
    table(ws, ["stat_key", "reads_as", "unit"], rows, [18, 50, 20])

    # --- Categories (reference)
    ws = wb.create_sheet("Categories")
    rows = []
    for c in CATS:
        rows.append({"key": c, "kind_of_key": "category", "meaning": "Item category"})
    for k in ["sword", "axe", "dagger", "fist", "bow", "wand", "staff"]:
        rows.append({"key": k, "kind_of_key": "kind", "meaning": "Weapon type"})
    for st, m in [("str", "Strength gear"), ("dex", "Dexterity gear"), ("int", "Intelligence gear"), ("none", "No style (jewellery)")]:
        rows.append({"key": st, "kind_of_key": "style", "meaning": m})
    for g, m in [("weapon", "All weapons"), ("armour", "Body, helm, gloves, boots, shield"), ("jewel", "Rings and amulets")]:
        rows.append({"key": g, "kind_of_key": "group", "meaning": m})
    table(ws, ["key", "kind_of_key", "meaning"], rows, [12, 14, 40])

    for sh in wb.worksheets:
        sh.sheet_view.zoomScale = 110
    wb.save(xlsx_path)
    print(f"wrote {xlsx_path}: {len(data['bases'])} bases, {len(data['affixes'])} affixes, {len(data['uniques'])} uniques")


# ---------------------------------------------------------------------------
# import
# ---------------------------------------------------------------------------
def rows_of(ws, header_row=1):
    headers = [str(c.value).strip() if c.value is not None else "" for c in ws[header_row]]
    out = []
    for row in ws.iter_rows(min_row=header_row + 1, values_only=True):
        if all(v is None or str(v).strip() == "" for v in row):
            continue
        out.append({headers[i]: row[i] for i in range(min(len(headers), len(row))) if headers[i]})
    return out


def _yes(v):
    return str(v).strip().lower() in ("yes", "y", "true", "1")


def _int(v, default=0):
    if v is None or str(v).strip() == "":
        return default
    try:
        return int(round(float(v)))
    except ValueError:
        raise ValueError(f"'{v}' isn't a number")


def _float(v, default=0.0):
    if v is None or str(v).strip() == "":
        return default
    try:
        return float(v)
    except ValueError:
        raise ValueError(f"'{v}' isn't a number")


def _list(v):
    if v is None:
        return []
    return [x.strip() for x in str(v).replace(";", ",").split(",") if x.strip()]


def _mult(v):
    out = {}
    for part in _list(v):
        if "=" not in part:
            raise ValueError(f"weight multiplier '{part}' should look like key=number")
        k, n = part.split("=", 1)
        out[k.strip()] = float(n)
    return out


def do_import(xlsx_path, json_path):
    try:
        _do_import(xlsx_path, json_path)
    except _RowError as e:
        print("ERROR:", e)
        print("\ndata/items.json was NOT changed.")
        sys.exit(1)


class _RowError(Exception):
    pass


def _do_import(xlsx_path, json_path):
    old = json.load(open(json_path))
    wb = load_workbook(xlsx_path, data_only=True)
    errors, warnings = [], []

    # settings
    ws = wb["Settings"]
    tiers = {}
    for r in rows_of(ws, 2):
        key = str(r.get("setting") or "").strip()
        if key in ("req_level", "req_stat", "affix_min_ilvl", "value"):
            tiers[key] = [_int(r.get(f"tier_{i}")) for i in range(1, 21) if r.get(f"tier_{i}") not in (None, "")]
    rules = {str(r.get("setting")).strip(): r.get("value") for r in rows_of(ws, 9) if r.get("setting")}
    settings = dict(old["settings"])
    settings["tiers"] = {**old["settings"]["tiers"], **tiers}
    settings["drop_chances"] = {
        "normal": {"magic": _float(rules.get("normal_magic_chance")), "rare": _float(rules.get("normal_rare_chance")), "unique": _float(rules.get("normal_unique_chance"))},
        "boss": {"magic": _float(rules.get("boss_magic_chance")), "rare": _float(rules.get("boss_rare_chance")), "unique": _float(rules.get("boss_unique_chance"))},
    }
    settings["magic_two_affix_chance"] = _float(rules.get("magic_two_affix_chance"), 0.5)
    settings["rare_affix_min"] = _int(rules.get("rare_affix_min"), 3)
    settings["rare_affix_max"] = min(6, _int(rules.get("rare_affix_max"), 5))
    settings["rarity_value_mult"] = {k: _float(rules.get(f"value_mult_{k}"), 1.0) for k in ("normal", "magic", "rare", "unique")}
    settings["jewel_value_mult"] = _float(rules.get("jewel_value_mult"), 1.2)
    for which in ("normal", "boss"):
        tot = sum(settings["drop_chances"][which].values())
        if tot > 1.0:
            errors.append(f"Settings: {which} drop chances add up to more than 100% ({tot:.0%}).")

    # bases
    bases, seen = [], set()
    for i, r in enumerate(rows_of(wb["Bases"]), 2):
        try:
            bid = str(r.get("id") or "").strip()
            if not bid:
                errors.append(f"Bases row {i}: missing id.")
                continue
            if bid in seen:
                errors.append(f"Bases row {i}: duplicate id '{bid}'.")
            seen.add(bid)
            cat = str(r.get("category") or "").strip()
            if cat not in CATS:
                errors.append(f"Bases row {i} ({bid}): unknown category '{cat}'.")
            tier = _int(r.get("tier"), 1)
            if not 1 <= tier <= 8:
                errors.append(f"Bases row {i} ({bid}): tier must be 1-8.")
            imp = {}
            for k in IMP_KEYS:
                v = r.get(IMP_HEAD[k])
                if v is not None and str(v).strip() != "":
                    imp[k] = _int(v)
            row = {"id": bid, "name": str(r.get("name") or bid), "cat": cat, "kind": str(r.get("kind") or cat).strip(),
                   "style": str(r.get("style") or "none").strip(), "tier": tier, "req_level": _int(r.get("req_level")),
                   "req_stat": _int(r.get("req_stat")), "two_handed": _yes(r.get("two_handed")), "drop_weight": _float(r.get("drop_weight"), 1.0),
                   "imp": imp, "label": str(r.get("type_label") or "")}
            dice = str(r.get("dice") or "").strip().lower()
            if cat == "weapon" and dice:
                m = re.fullmatch(r"(\d*)d(\d+)", dice)
                if not m:
                    errors.append(f"Bases row {i} ({bid}): dice should look like d8 or 2d8.")
                else:
                    n, sides, flat = int(m.group(1) or 1), int(m.group(2)), _int(r.get("dmg_flat"))
                    row.update({"dice": dice, "dmg_flat": flat, "dmg_min": n + flat, "dmg_max": n * sides + flat})
            elif cat == "weapon":
                if r.get("dmg_min") in (None, "") or r.get("dmg_max") in (None, ""):
                    errors.append(f"Bases row {i} ({bid}): weapons need dmg_min and dmg_max.")
                else:
                    row["dmg_min"], row["dmg_max"] = _int(r["dmg_min"]), _int(r["dmg_max"])
                    if row["dmg_min"] > row["dmg_max"]:
                        errors.append(f"Bases row {i} ({bid}): dmg_min is bigger than dmg_max.")
            bases.append(row)
        except ValueError as e:
            errors.append(f"Bases row {i}: {e}")
    old_ids = {b["id"] for b in old["bases"]}
    gone = sorted(old_ids - seen)
    if gone:
        warnings.append("Removed bases (items players own on these will vanish): " + ", ".join(gone))

    # affixes + tiers
    affixes, aids = [], {}
    for i, r in enumerate(rows_of(wb["Affixes"]), 2):
        try:
            aid = str(r.get("id") or "").strip()
            if not aid:
                continue
            if aid in aids:
                errors.append(f"Affixes row {i}: duplicate id '{aid}'.")
            typ = str(r.get("type") or "").strip()
            if typ not in ("prefix", "suffix"):
                errors.append(f"Affixes row {i} ({aid}): type must be prefix or suffix.")
            try:
                mult = _mult(r.get("weight_multipliers"))
            except ValueError as e:
                errors.append(f"Affixes row {i} ({aid}): {e}")
                mult = {}
            af = {"id": aid, "type": typ, "stat": str(r.get("stat") or "").strip(), "range": _yes(r.get("range")),
                  "weight": _float(r.get("weight"), 1.0), "only": _list(r.get("allowed_on")), "mult": mult, "tiers": []}
            aids[aid] = af
            affixes.append(af)
        except ValueError as e:
            errors.append(f"Affixes row {i}: {e}")
    tier_rows = {}
    for i, r in enumerate(rows_of(wb["Affix Tiers"]), 2):
        aid = str(r.get("affix_id") or "").strip()
        if aid not in aids:
            errors.append(f"Affix Tiers row {i}: affix '{aid}' isn't on the Affixes sheet.")
            continue
        try:
            lo, hi = _int(r.get("min")), _int(r.get("max"))
            _int(r.get("min_item_level"), 1), _int(r.get("tier"), 1)
        except ValueError as e:
            errors.append(f"Affix Tiers row {i} ({aid}): {e}")
            continue
        if lo > hi:
            errors.append(f"Affix Tiers row {i} ({aid} tier {r.get('tier')}): min is bigger than max.")
        tier_rows.setdefault(aid, []).append((_int(r.get("tier"), 1), {"name": str(r.get("name") or ""), "min_ilvl": _int(r.get("min_item_level"), 1), "min": lo, "max": hi}))
    for aid, af in aids.items():
        trs = sorted(tier_rows.get(aid, []), key=lambda x: x[0])
        if not trs:
            errors.append(f"Affix '{aid}' has no tiers on the Affix Tiers sheet.")
        af["tiers"] = [t for _, t in trs]
        ilvls = [t["min_ilvl"] for t in af["tiers"]]
        if ilvls != sorted(ilvls):
            warnings.append(f"Affix '{aid}': tier minimum item levels aren't in increasing order.")

    # uniques
    uniques, uids = [], set()
    for i, r in enumerate(rows_of(wb["Uniques"]), 2):
        try:
            uid = str(r.get("id") or "").strip()
            if not uid:
                continue
            if uid in uids:
                errors.append(f"Uniques row {i}: duplicate id '{uid}'.")
            uids.add(uid)
            base = str(r.get("base") or "").strip()
            if base not in seen:
                errors.append(f"Uniques row {i} ({uid}): base '{base}' isn't on the Bases sheet.")
            mods = []
            for k in range(1, MAX_MODS + 1):
                st = r.get(f"mod{k}_stat")
                if st is None or str(st).strip() == "":
                    continue
                m = {"k": str(st).strip(), "v": _int(r.get(f"mod{k}_value"))}
                if r.get(f"mod{k}_value2") not in (None, ""):
                    m["v2"] = _int(r.get(f"mod{k}_value2"))
                mods.append(m)
            uniques.append({"id": uid, "name": str(r.get("name") or uid), "base": base, "boss_only": _yes(r.get("boss_only")),
                            "drop_weight": _float(r.get("drop_weight"), 1.0), "flavor": str(r.get("flavor") or ""), "mods": mods})
        except ValueError as e:
            errors.append(f"Uniques row {i}: {e}")

    # unknown stat keys
    known = set(old.get("stat_text", {}).keys()) | set(IMP_KEYS)
    for af in affixes:
        if af["stat"] not in known:
            errors.append(f"Affix '{af['id']}': unknown stat '{af['stat']}' (see Stat Keys).")
    for u in uniques:
        for m in u["mods"]:
            if m["k"] not in known:
                errors.append(f"Unique '{u['id']}': unknown stat '{m['k']}' (see Stat Keys).")

    for w in warnings:
        print("warning:", w)
    if errors:
        for e in errors:
            print("ERROR:", e)
        print(f"\n{len(errors)} problem(s) - data/items.json was NOT changed.")
        sys.exit(1)
    out = dict(old)
    out.update({"settings": settings, "bases": bases, "affixes": affixes, "uniques": uniques})
    json.dump(out, open(json_path, "w"), indent="\t")
    print(f"updated {json_path}: {len(bases)} bases, {len(affixes)} affixes, {len(uniques)} uniques")


if __name__ == "__main__":
    if len(sys.argv) < 2 or sys.argv[1] not in ("export", "import"):
        print(__doc__)
        sys.exit(1)
    if sys.argv[1] == "export":
        export(sys.argv[2] if len(sys.argv) > 2 else "data/items.json", sys.argv[3] if len(sys.argv) > 3 else "item_balance.xlsx")
    else:
        do_import(sys.argv[2], sys.argv[3] if len(sys.argv) > 3 else "data/items.json")
