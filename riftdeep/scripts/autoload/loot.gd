extends Node
## Equipment: base items, affixes, rarities, uniques, drop and shop generation.
## Item instances are plain Dictionaries so they save straight to JSON:
##   {"base": id, "rarity": "normal|magic|rare|unique", "ilvl": int, "name": String,
##    "mods": [{"k": stat, "v": int, "v2": int (ranges only)}], "flavor": String}

# Tier tables and drop rules are loaded from res://data/items.json (see load_data()).
var REQ_LVL: Array = [0, 5, 10, 15, 20]
var REQ_STAT: Array = [0, 10, 18, 26, 34]
var ILVL_T: Array = [1, 5, 10, 15, 20]
var VALUE_T: Array = [12, 45, 110, 220, 380]
var RARITY_MULT := {"normal": 1.0, "magic": 2.5, "rare": 6.0, "unique": 12.0}
var SETTINGS := {}
const RARITY_COLORS := {
	"normal": Color(0.92, 0.92, 0.9),
	"magic": Color(0.45, 0.6, 1.0),
	"rare": Color(1.0, 0.9, 0.35),
	"unique": Color(1.0, 0.55, 0.15),
}
const STYLE_NAMES := {"str": "Strength", "dex": "Dexterity", "int": "Intelligence"}
const CAT_NAMES := {"body": "Body Armour", "helm": "Helm", "gloves": "Gloves", "boots": "Boots", "shield": "Shield", "ring": "Ring", "amulet": "Amulet"}
const ARMOUR_CATS := ["body", "helm", "gloves", "boots", "shield"]

const STAT_TEXT := {
	"str": "+%d Strength", "dex": "+%d Dexterity", "int": "+%d Intelligence", "con": "+%d Constitution",
	"all_attr": "+%d to all Attributes", "hp": "+%d Maximum HP", "mp": "+%d Maximum MP", "def": "+%d Armour",
	"evasion": "+%d%% Evasion", "speed": "+%d%% Speed", "crit": "+%d%% Critical Chance",
	"accuracy": "+%d%% Chance to Hit", "double_hit": "+%d%% chance to Hit twice with Melee attacks",
	"phys_dmg": "+%d%% Physical Damage", "spell_dmg": "+%d%% Spell Damage", "fire_dmg": "+%d%% Fire Damage",
	"ice_dmg": "+%d%% Ice Damage", "heal_pow": "+%d%% Healing Power", "fire_res": "+%d%% Fire Resistance",
	"ice_res": "+%d%% Ice Resistance", "magic_res": "+%d%% Magic Resistance", "all_res": "+%d%% to all Resistances",
	"hp_regen": "{regen:%d}", "mp_regen": "+%d MP Regeneration",
	"ow_freeze": "+%s s monster freeze after victory", "ow_flee_freeze": "+%s s monster freeze after fleeing", "ow_radius": "+%d tiles post-battle freeze radius",
	"ensnare_chance": "+%d%% chance to Ensnare on Melee Hit",
	"def_pct": "%d%% less Physical damage taken",
	"poison_res": "+%d%% Poison Resistance", "poison_on_hit": "Hits inflict {poison:%d}",
	"add_phys": "Adds %d-%d Physical damage to Hits", "add_fire": "Adds %d-%d Fire damage to Hits", "add_ice": "Adds %d-%d Ice damage to Hits",
}
## Stats stored as whole percentages on items, converted to fractions on units.
## Stats stored as tenths (seconds) on items.
const TENTHS_KEYS := ["ow_freeze", "ow_flee_freeze"]
const PCT_KEYS := ["def_pct", "ensnare_chance", "poison_res", "evasion", "speed", "crit", "accuracy", "double_hit", "phys_dmg", "spell_dmg", "fire_dmg", "ice_dmg", "heal_pow", "fire_res", "ice_res", "magic_res"]

const RARE_A := ["Grim", "Storm", "Doom", "Blood", "Bone", "Raven", "Dread", "Wraith", "Gale", "Ember", "Frost", "Viper", "Iron", "Shadow", "Thunder", "Hollow", "Ash", "Rune", "Sorrow", "Night"]
const RARE_B := {
	"weapon": ["Bite", "Song", "Edge", "Reaver", "Fang", "Thirst", "Spire", "Wail"],
	"body": ["Shell", "Hide", "Carapace", "Mantle", "Coat", "Ward"],
	"helm": ["Visage", "Crown", "Cowl", "Brow", "Mask", "Horn"],
	"gloves": ["Grasp", "Fist", "Claw", "Touch", "Hold", "Grip"],
	"boots": ["Stride", "Tread", "Track", "Trail", "Pace", "Spur"],
	"shield": ["Bulwark", "Wall", "Aegis", "Guard", "Bastion", "Rampart"],
	"ring": ["Loop", "Band", "Coil", "Circle", "Spiral", "Knot"],
	"amulet": ["Charm", "Talisman", "Heart", "Eye", "Locket", "Star"],
}

## Preset uniques.  base must exist in BASES.
# ---------------------------------------------------------------------------
# Item data: everything below is loaded from res://data/items.json, which is
# generated from (and converted back into) the balance spreadsheet by
# tools/items_sheet.py.
# ---------------------------------------------------------------------------
const DATA_PATH := "res://data/items.json"
var BASES := {}      # id -> {name, cat, kind, style, tier (0-4), lvl, req, imp, two, dmg?, label, drop}
var AFFIXES := {}    # id -> {type, k, w, range, only, mult, names[], tiers[{min_ilvl, min, max}]}
var UNIQUES := {}    # id -> {name, base, boss_only, drop, flavor, mods[]}

func _ready() -> void:
	load_data()

func load_data() -> void:
	var text := FileAccess.get_file_as_string(DATA_PATH)
	var data = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY:
		push_error("Could not read %s" % DATA_PATH)
		return
	SETTINGS = data.get("settings", {})
	var tiers: Dictionary = SETTINGS.get("tiers", {})
	REQ_LVL = _ints(tiers.get("req_level", REQ_LVL))
	REQ_STAT = _ints(tiers.get("req_stat", REQ_STAT))
	ILVL_T = _ints(tiers.get("affix_min_ilvl", ILVL_T))
	VALUE_T = _ints(tiers.get("value", VALUE_T))
	RARITY_MULT = SETTINGS.get("rarity_value_mult", RARITY_MULT)
	BASES.clear()
	for r in data.get("bases", []):
		var req := {}
		if int(r.get("req_stat", 0)) > 0 and r["style"] != "none":
			req[r["style"]] = int(r["req_stat"])
		var imp := {}
		for k in r.get("imp", {}):
			imp[k] = int(r["imp"][k])
		var b := {"name": r["name"], "cat": r["cat"], "kind": r["kind"], "style": r["style"], "tier": int(r["tier"]) - 1,
			"lvl": int(r["req_level"]), "req": req, "imp": imp, "two": bool(r.get("two_handed", false)),
			"label": str(r.get("label", "")), "drop": float(r.get("drop_weight", 1.0))}
		if r.has("dmg_min"):
			b["dmg"] = [int(r["dmg_min"]), int(r["dmg_max"])]
		if str(r.get("dice", "")) != "":
			b["dice"] = _parse_dice(str(r["dice"]))
			b["flat"] = int(r.get("dmg_flat", 0))
		BASES[r["id"]] = b
	_index_families()
	AFFIXES.clear()
	for r in data.get("affixes", []):
		var names: Array = []
		var trs: Array = []
		for t in r["tiers"]:
			names.append(t["name"])
			trs.append({"min_ilvl": int(t["min_ilvl"]), "min": int(t["min"]), "max": int(t["max"])})
		AFFIXES[r["id"]] = {"type": r["type"], "k": r["stat"], "w": float(r["weight"]), "range": bool(r.get("range", false)),
			"only": r.get("only", []), "mult": r.get("mult", {}), "names": names, "tiers": trs}
	UNIQUES.clear()
	for r in data.get("uniques", []):
		var mods: Array = []
		for m in r.get("mods", []):
			var mm := {"k": m["k"], "v": int(m["v"])}
			if m.has("v2"):
				mm["v2"] = int(m["v2"])
			mods.append(mm)
		UNIQUES[r["id"]] = {"name": r["name"], "base": r["base"], "boss_only": bool(r.get("boss_only", false)),
			"drop": float(r.get("drop_weight", 1.0)), "flavor": str(r.get("flavor", "")), "mods": mods}

## "2d8" -> [2, 8]
func _parse_dice(s: String) -> Array:
	var p := s.to_lower().split("d")
	var n := int(p[0]) if p[0] != "" else 1
	return [maxi(1, n), maxi(2, int(p[1]) if p.size() > 1 else 6)]

## Bases grouped by family (category + kind + style), each list sorted by level.
var FAMILIES := {}
func _index_families() -> void:
	FAMILIES.clear()
	for id in BASES:
		var b: Dictionary = BASES[id]
		var key := "%s|%s|%s" % [b["cat"], b["kind"], b["style"]]
		if not FAMILIES.has(key):
			FAMILIES[key] = []
		FAMILIES[key].append(id)
	for key in FAMILIES:
		FAMILIES[key].sort_custom(func(a, c): return int(BASES[a]["lvl"]) < int(BASES[c]["lvl"]))

## A base fit for a level: each family offers its best piece at or below level + 2 (sometimes one
## a little older), and families are picked by drop weight.
func base_for_level(lvl: int, cat_filter: String = "") -> String:
	var pool: Array = []
	for key in FAMILIES:
		var ids: Array = FAMILIES[key]
		var best := -1
		for i in ids.size():
			if int(BASES[ids[i]]["lvl"]) <= lvl + 2:
				best = i
		if best < 0:
			continue
		var b0: Dictionary = BASES[ids[best]]
		if cat_filter != "" and b0["cat"] != cat_filter:
			continue
		if float(b0.get("drop", 1.0)) <= 0.0:
			continue
		var step := 1 if b0["cat"] != "weapon" else 3
		var pick: int = best if randf() < 0.65 else maxi(0, best - randi_range(1, step))
		pool.append([ids[pick], float(b0.get("drop", 1.0))])
	var p = _weighted(pool)
	return p if p != null else BASES.keys()[0]

func _ints(a: Array) -> Array:
	return a.map(func(x): return int(x))

func setting(key: String, default):
	return SETTINGS.get(key, default)

func _weighted(pool: Array):
	var total := 0.0
	for p in pool:
		total += float(p[1])
	if total <= 0.0:
		return null
	var r := randf() * total
	for p in pool:
		r -= float(p[1])
		if r <= 0.0:
			return p[0]
	return pool[-1][0]

# ---------------------------------------------------------------------------
# Queries
# ---------------------------------------------------------------------------
func base_of(item: Dictionary) -> Dictionary:
	return BASES.get(item.get("base", ""), {})

func group_of(cat: String) -> String:
	if cat == "weapon":
		return "weapon"
	if cat in ARMOUR_CATS:
		return "armour"
	return "jewel"

func is_weapon(item) -> bool:
	return item != null and base_of(item).get("cat", "") == "weapon"

func is_two_handed(item) -> bool:
	return item != null and base_of(item).get("two", false)

func is_bow(item) -> bool:
	return item != null and base_of(item).get("kind", "") == "bow"

func color_of(item: Dictionary) -> Color:
	return RARITY_COLORS.get(item.get("rarity", "normal"), Color.WHITE)

func value_of(item: Dictionary) -> int:
	var b := base_of(item)
	var lv := float(maxi(1, int(b.get("lvl", 1))))
	var v := (10.0 + 3.0 * lv + 0.15 * lv * lv) * float(RARITY_MULT.get(item.get("rarity", "normal"), 1.0)) * wlv_mult(item)
	if b.get("cat", "") in ["ring", "amulet"]:
		v *= float(setting("jewel_value_mult", 1.2))
	return int(v)

func type_line(item: Dictionary) -> String:
	var b := base_of(item)
	if b["cat"] == "weapon":
		return str(b.get("label", b["kind"].capitalize()))
	if b["style"] == "none":
		return CAT_NAMES[b["cat"]]
	return "%s (%s)" % [CAT_NAMES[b["cat"]], STYLE_NAMES[b["style"]]]

# ---------------------------------------------------------------------------
# Item World: every floor cleared inside an item levels it up (+1), strengthening
# its damage and every stat on it by 6% of the original per level. No cap.
# ---------------------------------------------------------------------------
const WLV_STEP := 0.06

func wlv(item) -> int:
	return int(item.get("wlv", 0)) if item is Dictionary else 0

func wlv_mult(item) -> float:
	return 1.0 + WLV_STEP * wlv(item)

## Weapon damage range including Item World levels.
func weapon_dmg(item: Dictionary) -> Array:
	var d: Array = base_of(item).get("dmg", [1, 3])
	var m := wlv_mult(item)
	return [int(round(d[0] * m)), int(round(d[1] * m))]

## One weapon damage roll: dice + flat (x Item World level). avg = the expected value.
func weapon_roll(item: Dictionary, avg: bool) -> float:
	var b := base_of(item)
	var m := wlv_mult(item)
	if b.has("dice"):
		var n: int = b["dice"][0]
		var sides: int = b["dice"][1]
		if avg:
			return (n * (sides + 1) * 0.5 + int(b["flat"])) * m
		var tot := int(b["flat"])
		for i in n:
			tot += randi_range(1, sides)
		return tot * m
	var d: Array = b.get("dmg", [1, 3])
	return (float(d[0] + d[1]) * 0.5 if avg else randf_range(d[0], d[1])) * m

## "2d8+5" for weapons with dice.
func dice_text(item: Dictionary) -> String:
	var b := base_of(item)
	if not b.has("dice"):
		return ""
	var n: int = b["dice"][0]
	return "%sd%d+%d" % [str(n) if n > 1 else "", b["dice"][1], int(b["flat"])]

## Raises an item's Item World level and renames it ("Steel Sword +2 (Lv 3)").
func level_item(item: Dictionary, n: int = 1) -> void:
	item["wlv"] = wlv(item) + n
	var nm: String = item.get("name", base_of(item).get("name", "Item"))
	var rx := RegEx.new()
	rx.compile(" \\(Lv \\d+\\)$")
	nm = rx.sub(nm, "")
	item["name"] = "%s (Lv %d)" % [nm, wlv(item)]

## The dungeon level of an item's world at its first floor.
func world_level(item: Dictionary) -> int:
	return maxi(1, int(item.get("ilvl", 1)) + wlv(item))

## All stat contributions of an item, implicit + affixes: Array of [key, value]
## with ranges split into key_min / key_max and percentages already converted.
func item_stats(item: Dictionary) -> Array:
	var out: Array = []
	var b := base_of(item)
	var all: Array = []
	for k in b.get("imp", {}):
		all.append({"k": k, "v": b["imp"][k]})
	all.append_array(item.get("mods", []))
	for m in all:
		var k: String = m["k"]
		var v = m["v"]
		if k.begins_with("add_"):
			out.append([k + "_min", float(v)])
			out.append([k + "_max", float(m.get("v2", v))])
		elif k == "all_attr":
			for s in ["str", "dex", "con", "int"]:
				out.append([s, float(v)])
		elif k == "all_res":
			for r in ["fire_res", "ice_res", "magic_res"]:
				out.append([r, float(v) / 100.0])
		elif k in TENTHS_KEYS:
			out.append([k, float(v) / 10.0])
		elif k in PCT_KEYS:
			out.append([k, float(v) / 100.0])
		else:
			out.append([k, float(v)])
	var wm := wlv_mult(item)
	if wm != 1.0:
		for e in out:
			e[1] = float(e[1]) * wm
	return out

func _wscaled(m: Dictionary, item: Dictionary) -> Dictionary:
	var wm := wlv_mult(item)
	if wm == 1.0:
		return m
	var out := m.duplicate()
	out["v"] = int(round(float(m["v"]) * wm))
	if m.has("v2"):
		out["v2"] = int(round(float(m["v2"]) * wm))
	return out

func stat_text(m: Dictionary) -> String:
	var k: String = m["k"]
	var fmt: String = STAT_TEXT.get(k, k + " %d")
	var s: String
	if k.begins_with("add_"):
		s = fmt % [int(m["v"]), int(m.get("v2", m["v"]))]
	elif k in TENTHS_KEYS:
		s = fmt % ("%.1f" % (float(m["v"]) / 10.0))
	else:
		s = fmt % int(m["v"])
	return s.replace("+-", "-")

## Reason this unit can't use the item, or "" if it can.
func req_problem(item: Dictionary, u) -> String:
	var b := base_of(item)
	if u == null:
		return ""
	if u.level < int(b.get("lvl", 0)):
		return "Requires level %d" % int(b["lvl"])
	for s in b.get("req", {}):
		if u.stat(s) < int(b["req"][s]):
			return "Requires %d %s" % [int(b["req"][s]), STYLE_NAMES[s]]
	return ""

## Tooltip lines: Array of [text, color, colorize_keywords]
func describe(item: Dictionary, u = null, show_value: String = "") -> Array:
	var b := base_of(item)
	var rc := color_of(item)
	var lines: Array = []
	lines.append([item.get("name", b["name"]), rc, false])
	if item.get("rarity", "normal") != "normal":
		lines.append([b["name"], Color(0.7, 0.7, 0.72), false])
	lines.append([type_line(item), Color(0.62, 0.65, 0.78), true])
	if wlv(item) > 0:
		lines.append(["Item World level +%d  (all stats x%.2f)" % [wlv(item), wlv_mult(item)], Color(0.6, 0.95, 1.0), false])
	if b.has("dmg"):
		var wd := weapon_dmg(item)
		var dt := dice_text(item)
		lines.append(["Physical Damage: %s%d-%d  (avg %.1f)" % [(dt + " = ") if dt != "" else "", wd[0], wd[1], weapon_roll(item, true)], Color(0.95, 0.95, 0.95), true])
		if u != null and not u.is_enemy:
			lines.append([_hit_with(item, u), Color(0.95, 0.95, 0.95), true])
			var est := _attack_estimate(item, u)
			lines.append(["Basic attack vs a typical level %d enemy: ~%d per turn (now ~%d)" % [u.level, est[1], est[0]], Color(0.75, 0.85, 1.0), true])
	for k in b.get("imp", {}):
		lines.append([stat_text(_wscaled({"k": k, "v": b["imp"][k]}, item)), Color(0.95, 0.95, 0.95), true])
	var mods: Array = item.get("mods", [])
	if mods.size() > 0:
		lines.append(["", Color.WHITE, false])
		var mc := Color(0.55, 0.68, 1.0) if item.get("rarity") != "unique" else Color(1.0, 0.7, 0.4)
		for m in mods:
			lines.append([stat_text(_wscaled(m, item)), mc, true])
	var reqs: Array = []
	if int(b.get("lvl", 0)) > 0:
		reqs.append("Level %d" % int(b["lvl"]))
	for s in b.get("req", {}):
		reqs.append("%d %s" % [int(b["req"][s]), STYLE_NAMES[s]])
	if reqs.size() > 0:
		var bad := req_problem(item, u) != ""
		lines.append(["Requires " + ", ".join(reqs), Color(1.0, 0.4, 0.35) if bad else Color(0.62, 0.65, 0.78), false])
	if item.get("flavor", "") != "":
		lines.append([item["flavor"], Color(0.85, 0.55, 0.3), false])
	if show_value != "":
		lines.append([show_value, Color(1.0, 0.85, 0.35), false])
	return lines

## "Your Hit with this: 44-52 Physical + 3-9 Fire (avg 58)" - after stats and modifiers.
func _hit_with(item: Dictionary, u) -> String:
	var saved: Dictionary = u.equip.duplicate()
	var worn: bool = u.equip.get("main") == item or u.equip.get("off") == item
	if not worn:
		u.equip["main"] = item
		if is_two_handed(item):
			u.equip.erase("off")
		u.recalc()
	var off: bool = worn and u.equip.get("off") == item
	var rg: Dictionary = Combat.hit_ranges(u, off)
	if not worn:
		u.equip = saved
		u.recalc()
	var parts: Array = []
	var tot := 0.0
	for el in [["phys", "Physical"], ["fire", "Fire"], ["ice", "Ice"]]:
		if rg.has(el[0]):
			parts.append("%d-%d %s" % [int(round(rg[el[0]][0])), int(round(rg[el[0]][1])), el[1]])
			tot += (rg[el[0]][0] + rg[el[0]][1]) * 0.5
	return "Your Hit with this: %s (avg %d)" % [" + ".join(parts), int(round(tot))]

## [current, with this weapon] expected basic-attack damage per turn for u.
func _attack_estimate(item: Dictionary, u) -> Array:
	var foe := Combat.typical_enemy(u.level)
	var now: float = Combat.expected_attack_turn(u, foe)["turn"]
	var saved: Dictionary = u.equip.duplicate()
	if u.equip.get("main") == item:
		return [int(round(now)), int(round(now))]
	u.equip["main"] = item
	if Loot.is_two_handed(item):
		u.equip.erase("off")
	u.recalc()
	var with_it: float = Combat.expected_attack_turn(u, foe)["turn"]
	u.equip = saved
	u.recalc()
	return [int(round(now)), int(round(with_it))]

# ---------------------------------------------------------------------------
# Generation
# ---------------------------------------------------------------------------
func make_normal(base_id: String) -> Dictionary:
	return {"base": base_id, "rarity": "normal", "ilvl": 1, "name": BASES[base_id]["name"], "mods": []}

func make_unique(uid: String) -> Dictionary:
	var u: Dictionary = UNIQUES[uid]
	return {"base": u["base"], "rarity": "unique", "ilvl": 1, "name": u["name"], "mods": u["mods"].duplicate(true), "flavor": u["flavor"]}

func _affix_weight(a: Dictionary, b: Dictionary) -> float:
	var cat: String = b["cat"]
	var grp := group_of(cat)
	if a.has("only"):
		var ok := false
		for o in a["only"]:
			if o == cat or o == grp:
				ok = true
		if not ok:
			return 0.0
	var w: float = a["w"]
	var mult: Dictionary = a.get("mult", {})
	var seen := {}
	for key in [cat, b["kind"], b["style"], grp]:
		if seen.has(key):
			continue
		seen[key] = true
		w *= float(mult.get(key, 1.0))
	return w

func _pick_affix(b: Dictionary, type: String, taken: Array) -> String:
	var pool: Array = []
	var total := 0.0
	for id in AFFIXES:
		var a: Dictionary = AFFIXES[id]
		if a["type"] != type or taken.has(id):
			continue
		var w := _affix_weight(a, b)
		if w <= 0.0:
			continue
		pool.append([id, w])
		total += w
	if pool.is_empty():
		return ""
	var r := randf() * total
	for p in pool:
		r -= p[1]
		if r <= 0.0:
			return p[0]
	return pool[-1][0]

func _roll_mod(aid: String, ilvl: int) -> Dictionary:
	var a: Dictionary = AFFIXES[aid]
	var trs: Array = a["tiers"]
	var avail := 1
	for i in trs.size():
		if ilvl >= int(trs[i]["min_ilvl"]):
			avail = i + 1
	# one of the two best tiers this item level allows
	var t := randi_range(maxi(0, avail - 2), avail - 1)
	var tr: Dictionary = trs[t]
	var m := {"a": aid, "t": t, "k": a["k"]}
	if a["range"]:
		# "Adds X-Y": each end wobbles a little
		var v1 := maxi(1, int(tr["min"]) + randi_range(-1, 0))
		m["v"] = v1
		m["v2"] = maxi(v1 + 1, int(tr["max"]) + randi_range(-1, 1))
	else:
		m["v"] = randi_range(mini(int(tr["min"]), int(tr["max"])), int(tr["max"]))
	return m

func make_item(base_id: String, rarity: String, ilvl: int) -> Dictionary:
	var b: Dictionary = BASES[base_id]
	var item := {"base": base_id, "rarity": rarity, "ilvl": ilvl, "name": b["name"], "mods": []}
	if rarity == "normal":
		return item
	var n_pre := 0
	var n_suf := 0
	if rarity == "magic":
		if randf() < float(setting("magic_two_affix_chance", 0.5)):
			n_pre = 1
			n_suf = 1
		elif randf() < 0.5:
			n_pre = 1
		else:
			n_suf = 1
	else:
		var count := randi_range(int(setting("rare_affix_min", 3)), int(setting("rare_affix_max", 5)))
		n_pre = randi_range(maxi(0, count - 3), mini(3, count))
		n_suf = count - n_pre
	var taken: Array = []
	var pre_name := ""
	var suf_name := ""
	for i in n_pre:
		var id := _pick_affix(b, "prefix", taken)
		if id == "":
			break
		taken.append(id)
		var m := _roll_mod(id, ilvl)
		item["mods"].append(m)
		if pre_name == "":
			pre_name = AFFIXES[id]["names"][m["t"]]
	for i in n_suf:
		var id2 := _pick_affix(b, "suffix", taken)
		if id2 == "":
			break
		taken.append(id2)
		var m2 := _roll_mod(id2, ilvl)
		item["mods"].append(m2)
		if suf_name == "":
			suf_name = AFFIXES[id2]["names"][m2["t"]]
	if rarity == "magic":
		var nm: String = b["name"]
		if pre_name != "":
			nm = pre_name + " " + nm
		if suf_name != "":
			nm = nm + " " + suf_name
		item["name"] = nm
	else:
		var key: String = "weapon" if b["cat"] == "weapon" else b["cat"]
		item["name"] = "%s %s" % [RARE_A.pick_random(), RARE_B[key].pick_random()]
	return item

func max_tier_for(ilvl: int) -> int:
	var t := 0
	for i in REQ_LVL.size():
		if REQ_LVL[i] <= ilvl + 2:
			t = i
	return t

## A random base of a tier between min_t and max_t (0-based), weighted by each base's drop weight.
func random_base(min_t: int, max_t: int, cat_filter: String = "") -> String:
	var t := randi_range(min_t, max_t)
	var pool: Array = []
	for id in BASES:
		var b: Dictionary = BASES[id]
		if int(b["tier"]) == t and (cat_filter == "" or b["cat"] == cat_filter):
			pool.append([id, float(b.get("drop", 1.0))])
	var pick = _weighted(pool)
	return pick if pick != null else BASES.keys()[0]

func roll_rarity(magic_ch: float, rare_ch: float, unique_ch: float) -> String:
	var r := randf()
	if r < unique_ch:
		return "unique"
	if r < unique_ch + rare_ch:
		return "rare"
	if r < unique_ch + rare_ch + magic_ch:
		return "magic"
	return "normal"

## A random drop from a monster of the given level.
func roll_drop(ilvl: int, boss: bool = false) -> Dictionary:
	var ch: Dictionary = setting("drop_chances", {}).get("boss" if boss else "normal", {})
	var q := Game.cheat("item_quality")   # testing multiplier: better rarity odds
	var rarity := roll_rarity(float(ch.get("magic", 0.32)) * q, float(ch.get("rare", 0.1)) * q, float(ch.get("unique", 0.015)) * q)
	if rarity == "unique":
		var pool: Array = []
		for uid in UNIQUES:
			if UNIQUES[uid].get("boss_only", false):
				continue
			if BASES.has(UNIQUES[uid]["base"]) and int(BASES[UNIQUES[uid]["base"]]["lvl"]) <= ilvl + 2:
				pool.append([uid, UNIQUES[uid].get("drop", 1.0)])
		var pick = _weighted(pool)
		if pick != null:
			return make_unique(pick)
		rarity = "rare"
	return make_item(base_for_level(ilvl), rarity, ilvl)

## Shop stock: Array of items.
func shop_stock(lvl: int, n: int, magic_ch: float, rare_ch: float) -> Array:
	var out: Array = []
	for i in n:
		var rarity := roll_rarity(magic_ch, rare_ch, 0.0)
		out.append(make_item(base_for_level(lvl), rarity, lvl))
	return out
