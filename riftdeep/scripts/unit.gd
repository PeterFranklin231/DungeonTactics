class_name Unit
extends RefCounted
## A combatant: the player, a hireling, or an enemy.

const STATS := ["str", "dex", "con", "int"]

var name := "Hero"
var cls := "Hero"
var is_enemy := false
var enemy_id := ""
var level := 1
var xp := 0
var base := {"str": 5, "dex": 5, "con": 5, "int": 5}
var nodes := {"origin": true}     # allocated skill tree node ids
var skill_points := 0
var hp := 1
var mp := 0
var mods := {}                     # summed effects from the skill tree
var learned: Array = []            # ability ids granted by the tree
var buffs: Array = []              # [{mods:{}, turns:int, name:String}]
var hots: Array = []               # timed Regeneration effects [{amount, ticks}] - they stack (4 ticks per round)
var poison_left := 0               # one poison pool: deals its amount each turn, then halves (rounded down); new poison adds to it
var masteries: Array = []          # spell ids whose Target All version is unlocked
var protector = null               # Unit taking hits for this one (Protect)
var atb := 0.0
var look := {}                     # appearance for Art.person
var hire_cost := 0
var quote := ""
var equip := {}                    # slot -> item Dictionary (see Loot)
var natural_wd: Array = []         # weapon range for stand-in units (see Combat.typical_enemy)
var summoned := false              # enemies raised mid-battle: little XP, no loot
# --- Tactics board state
var cell := Vector2i.ZERO          # tile the unit stands on
var facing := Vector2i(1, 0)       # grid direction it faces (front / side / back attacks)
var ct := 0.0                      # charge time: acts at 100
var power_hp := 1.0                # enemies: depth scaling of health
var power_dmg := 1.0               # enemies: depth scaling of damage
var elite := false                 # boss-floor champion
var job := ""                      # work while staying at home ("" = idle, "wood" = chopping)
var field_buffs: Array = []        # exploring-only effects: [{name, mods, secs}] - timed in seconds, ignored in battle
const FIELD_TURN := 2.0            # seconds per "turn" while exploring

const SLOTS := ["main", "off", "helm", "body", "gloves", "boots", "amulet", "ring1", "ring2"]
const SLOT_NAMES := {"main": "Main Hand", "off": "Off Hand", "helm": "Helm", "body": "Body", "gloves": "Gloves",
	"boots": "Boots", "amulet": "Amulet", "ring1": "Ring", "ring2": "Ring"}

static func make_hero(n: String, c: String) -> Unit:
	var u := Unit.new()
	u.name = n
	u.cls = c
	u.skill_points = 1
	u.recalc()
	u.full_restore()
	return u

static func make_enemy(id: String) -> Unit:
	var u := Unit.new()
	var d: Dictionary = DB.ENEMIES[id]
	u.is_enemy = true
	u.enemy_id = id
	u.name = d["name"]
	u.cls = id
	for s in STATS:
		u.base[s] = int(d[s])
	u.level = int(d.get("lvl", 1))
	u.recalc()
	u.full_restore()
	return u

# ---------------------------------------------------------------------------
# Monster stat curves (levels 1 to infinity). Each monster keeps how tough it was
# relative to others of its level (rel_*), measured against a fit of the old data.
# ---------------------------------------------------------------------------
static func hp_curve(lv: float) -> float:
	return 16.0 + 2.3 * lv + 0.13 * lv * lv

static func dmg_curve(lv: float) -> float:
	return 3.0 + 2.1 * lv + 0.001 * lv * lv

static func xp_curve(lv: float) -> float:
	return 3.0 * lv * lv + 5.0

static func gold_curve(lv: float) -> float:
	return 3.0 + 2.0 * lv

func _rel(key: String, a: float, b: float) -> float:
	var lv := float(maxi(1, int(def().get("lvl", 1))))
	return clampf(float(def().get(key, 1.0)) / (a * pow(lv, b)), 0.05, 30.0)

func rel_hp() -> float:
	return _rel("hp", 8.242, 1.164)

func rel_dmg() -> float:
	var wd: Array = def().get("wd", [1, 3])
	var lv := float(maxi(1, int(def().get("lvl", 1))))
	return clampf((wd[0] + wd[1]) * 0.5 / (1.931 * pow(lv, 0.913)), 0.05, 30.0)

func xp_value() -> int:
	return int(round(xp_curve(level) * _rel("xp", 6.582, 1.326) * (power_hp + power_dmg) * 0.5))

func gold_value() -> int:
	return int(round(gold_curve(level) * _rel("gold", 2.537, 0.699) * (power_hp + power_dmg) * 0.5))

## Puts an enemy at a dungeon level (no cap: the deeper, the stronger).
func scale_to(target_level: int) -> void:
	level = maxi(int(def().get("lvl", 1)), target_level)
	full_restore()

## Boss-floor champion: a much tougher, bigger version of a normal monster.
func make_elite() -> void:
	elite = true
	power_hp *= 5.0
	power_dmg *= 1.35
	name = "Elite " + name
	full_restore()

# --- Movement on the board (FF Tactics style)
const MOVE_BY_CLASS := {"Hero": 4, "Warrior": 4, "Ranger": 4, "Mage": 3, "Cleric": 3}
const MOVE_BY_SHAPE := {"slime": 3, "boar": 4, "wolf": 5, "bandit": 4, "bandit_mage": 3, "bandit_archer": 4, "bat": 5, "spider": 4,
	"fungus": 2, "zombie": 3, "necromancer": 3, "crab": 3, "hermit": 3, "bear": 4}
const FLYERS := ["bat"]

func move_range() -> int:
	var base_mv: int = int(def().get("move", MOVE_BY_SHAPE.get(def().get("shape", ""), 4))) if is_enemy else int(MOVE_BY_CLASS.get(cls, 4))
	return maxi(1, base_mv + int(mod("move")))

func jump_height() -> int:
	if is_enemy:
		return 9 if flies() else int(def().get("jump", 2))
	return (3 if cls == "Ranger" else 2) + int(mod("jump"))

func flies() -> bool:
	return is_enemy and def().get("shape", "") in FLYERS

func def() -> Dictionary:
	return DB.ENEMIES[enemy_id] if is_enemy else {}

func recalc() -> void:
	mods = {}
	learned = []
	masteries = []
	for id in nodes:
		var n: Dictionary = DB.TREE[id]
		var eff: Dictionary = n["effects"]
		for k in eff:
			if k == "skill":
				learned.append(eff[k])
			elif k == "mastery":
				masteries.append(eff[k])
			else:
				mods[k] = float(mods.get(k, 0.0)) + float(eff[k])
	for slot in equip:
		for kv in Loot.item_stats(equip[slot]):
			mods[kv[0]] = float(mods.get(kv[0], 0.0)) + float(kv[1])

func mod(key: String) -> float:
	var v := float(mods.get(key, 0.0))
	for b in buffs:
		v += float(b["mods"].get(key, 0.0))
	if not field_buffs.is_empty() and not (Game.main != null and Game.main.in_battle):
		for fb in field_buffs:
			v += float(fb["mods"].get(key, 0.0))
	return v

## Adds an exploring-only effect lasting `secs` real seconds (refreshes one of the same name).
func add_field_buff(buff_name: String, buff_mods: Dictionary, secs: float) -> void:
	field_buffs = field_buffs.filter(func(fb): return fb["name"] != buff_name)
	field_buffs.append({"name": buff_name, "mods": buff_mods, "secs": secs})

func tick_field_buffs(delta: float) -> void:
	if field_buffs.is_empty():
		return
	for fb in field_buffs:
		fb["secs"] = float(fb["secs"]) - delta
	field_buffs = field_buffs.filter(func(fb): return float(fb["secs"]) > 0.0)

## One exploring turn (every FIELD_TURN seconds): poison and turn-based buffs.
func field_turn() -> void:
	if not is_alive():
		return
	for b in buffs:
		b["turns"] = int(b["turns"]) - 1
	buffs = buffs.filter(func(b): return int(b["turns"]) > 0)
	tick_dots()

func stat(s: String) -> int:
	return int(base[s]) + int(mods.get(s, 0.0)) + growth_bonus(s)

## Number of "per level" major nodes taken for this stat.
func growth_nodes(s: String) -> int:
	return int(mods.get(s + "_pl", 0.0))

## Retroactive bonus from growth nodes: +1 per 2 character levels, per node.
func growth_bonus(s: String) -> int:
	return growth_nodes(s) * (level / 2)

func max_hp() -> int:
	if is_enemy:
		return maxi(1, int(round(hp_curve(level) * rel_hp() * power_hp)))
	return int((20 + stat("con") * 5 + level * 6 + mods.get("hp", 0.0)) * (1.0 + mod("hp_pct")))

func max_mp() -> int:
	if is_enemy:
		return int(def().get("mp", 0))
	return 4 + stat("int") * 3 + level * 2 + int(mods.get("mp", 0.0))

func speed() -> float:
	var sm := float(def().get("speed_mult", 1.0)) if is_enemy else 1.0
	return (22.0 + stat("dex") * 2.0) * (1.0 + mod("speed")) * sm

func resist(element: String) -> float:
	if element == "phys":
		return 0.0
	var r := mod(element + "_res")
	if is_enemy:
		r += float(def()["res"].get(element, 0.0))
	return clampf(r, -1.0, 0.9)

## Applies one turn of poison. Returns damage taken.
func tick_dots() -> int:
	if poison_left <= 0 or not is_alive():
		return 0
	var total := poison_left
	poison_left = poison_left / 2
	var before := hp
	hp = maxi(0, hp - total)
	return before - hp

## Adds to the poison pool, reduced by poison resistance. Returns the amount applied.
func poison(amount: int) -> int:
	var a := int(floor(amount * (1.0 - resist("poison"))))
	if a > 0 and is_alive():
		poison_left += a
	return a

func poison_total() -> int:
	return poison_left

func cleanse() -> int:
	var n := 1 if poison_left > 0 else 0
	poison_left = 0
	var keep: Array = []
	for b in buffs:
		if b.get("debuff", false):
			n += 1
		else:
			keep.append(b)
	buffs = keep
	return n

func abilities() -> Array:
	if is_enemy:
		var out: Array = []
		for a in def()["abilities"]:
			if not out.has(a):
				out.append(a)
		return out
	return ["attack"] + learned

func is_alive() -> bool:
	return hp > 0

func full_restore() -> void:
	hp = max_hp()
	mp = max_mp()
	buffs.clear()
	hots.clear()
	poison_left = 0
	field_buffs.clear()
	protector = null

## Applies one turn of every heal-over-time effect. Returns HP healed.
## One Regeneration tick: 4 per round in battle, 1 per second while exploring.
## Applies gear / passive regen and timed Regeneration effects. Returns HP restored.
func regen_tick() -> int:
	if not is_alive():
		hots.clear()
		return 0
	var total := int(mod("hp_regen"))
	for h in hots:
		total += int(h["amount"])
		h["ticks"] = int(h.get("ticks", 0)) - 1
	hots = hots.filter(func(h): return int(h["ticks"]) > 0)
	var mr := int(mod("mp_regen"))
	if mr > 0:
		mp = mini(max_mp(), mp + mr)
	var before := hp
	hp = mini(max_hp(), hp + total)
	return hp - before

## Adds a timed Regeneration effect: +amount per tick for `rounds` rounds (4 ticks each).
func add_regen(amount: int, rounds: float) -> void:
	hots.append({"amount": amount, "ticks": int(round(rounds * 4.0))})

func xp_to_next() -> int:
	return 12 * level * level + 18

## Returns log lines describing level ups.
func gain_xp(amount: int) -> Array:
	var lines: Array = []
	xp += amount
	while xp >= xp_to_next():
		xp -= xp_to_next()
		var gains := level_up()
		lines.append("%s reached level %d! (%s, +1 skill point)" % [name, level, gains])
	return lines

func level_up() -> String:
	var old_hp := max_hp()
	var old_mp := max_mp()
	var old := {}
	for s in STATS:
		old[s] = stat(s)
	level += 1
	var parts: Array = []
	for s in STATS:
		base[s] += 1
		parts.append("+%d %s" % [stat(s) - int(old[s]), DB.STAT_NAMES[s]])
	skill_points += 1
	hp += max_hp() - old_hp
	mp += max_mp() - old_mp
	return " ".join(parts)

func is_linked(id: String) -> bool:
	for l in DB.TREE[id]["links"]:
		if nodes.has(l):
			return true
	return false

func can_allocate(id: String) -> bool:
	return skill_points > 0 and not nodes.has(id) and is_linked(id)

func allocate(id: String) -> void:
	if not can_allocate(id):
		return
	var old_hp := max_hp()
	var old_mp := max_mp()
	nodes[id] = true
	skill_points -= 1
	recalc()
	hp = clampi(hp + max(0, max_hp() - old_hp), 0, max_hp())
	mp = clampi(mp + max(0, max_mp() - old_mp), 0, max_mp())

## Spends all points greedily, preferring branches by weight (and a class arm, if given).
func auto_allocate(weights: Dictionary, arm: String = "") -> void:
	while skill_points > 0:
		var best := ""
		var best_score := -INF
		for id in DB.TREE:
			if not can_allocate(id):
				continue
			var n: Dictionary = DB.TREE[id]
			var aff: Dictionary = n.get("aff", {})
			var wsum := 0.0
			for st in aff:
				wsum += float(weights.get(st, 0.0)) * float(aff[st])
			var score := wsum * 10.0 + randf() * 6.0
			if arm != "" and n.get("branch", "") == arm:
				score += 30.0
				if id.contains("_ice_") or id.contains("_bolt_"):
					score -= 25.0   # casters specialise in one school (Fire)
			if n["type"] == "skill" or n["type"] == "major":
				score += 4.0
			if score > best_score:
				best_score = score
				best = id
		if best == "":
			break
		allocate(best)

func stat_line() -> String:
	return "STR %d  DEX %d  CON %d  INT %d" % [stat("str"), stat("dex"), stat("con"), stat("int")]

func skill_names() -> String:
	var a: Array = []
	for s in learned:
		a.append(DB.ABILITIES[s]["name"])
	return ", ".join(a) if a.size() > 0 else "none"

func bonus_lines() -> Array:
	var out: Array = []
	for k in mods:
		if DB.EFFECT_NAMES.has(k):
			out.append("+%d%% %s" % [int(round(float(mods[k]) * 100.0)), DB.EFFECT_NAMES[k]])
	return out

# ---------------------------------------------------------------------------
# Equipment
# ---------------------------------------------------------------------------
func weapon():
	return equip.get("main")

## Appearance with the weapon actually equipped.
func visual_look() -> Dictionary:
	var l := {"skin": look.get("skin", Color(0.95, 0.8, 0.65)), "hair": look.get("hair", Color(0.3, 0.2, 0.1)), "gear": {}}
	var g := {}
	for slot in ["helm", "body", "gloves", "boots", "main", "off"]:
		var it = equip.get(slot)
		if it == null:
			continue
		var b := Loot.base_of(it)
		g[slot] = {"kind": b.get("kind", ""), "style": b.get("style", "none"), "tier": int(b.get("tier", 0)),
			"rarity": it.get("rarity", "normal")}
	l["gear"] = g
	return l

const CARRY_BASE := {"Hero": 10, "Warrior": 9, "Ranger": 8, "Cleric": 7, "Mage": 6}

## Inventory slots this character adds to the party's packs.
func carry_slots() -> int:
	return int(CARRY_BASE.get(cls, 6)) + stat("str") / 6

## Fighting with fist weapons or bare hands (monk techniques).
func fists() -> bool:
	if is_enemy or natural_wd.size() == 2:
		return false
	var it = equip.get("main")
	return it == null or Loot.base_of(it).get("kind", "") == "fist"

func has_shield() -> bool:
	var it = equip.get("off")
	return it != null and Loot.base_of(it).get("kind", "") == "shield"

func has_bow() -> bool:
	return Loot.is_bow(equip.get("main")) or Loot.is_bow(equip.get("off"))

## Armour including temporary buffs (Shield, Protect).
func armour() -> float:
	var a := mod("def")
	if is_enemy:
		a += float(def().get("armour", 0.0)) * (3.0 + level) / (3.0 + int(def().get("lvl", 1)))
	return maxf(0.0, a)

## Armour from gear and passives only (what shield sharing copies).
func base_armour() -> float:
	return float(mods.get("def", 0.0))

## One physical damage roll of the main (or off) hand: weapon dice, a monster's natural hit, or bare hands.
func weapon_roll(use_off: bool, avg: bool) -> float:
	if natural_wd.size() == 2 or is_enemy:
		var r := weapon_range(use_off)
		return (r[0] + r[1]) * 0.5 if avg else randf_range(r[0], r[1])
	var it = equip.get("off" if use_off else "main")
	if it != null and Loot.is_weapon(it):
		return Loot.weapon_roll(it, avg)
	return 2.0 if avg else randf_range(1, 3)

## Physical damage range of the main hand (or off hand if use_off). Unarmed 1-3.
func weapon_range(use_off: bool = false) -> Array:
	if natural_wd.size() == 2:
		return natural_wd
	if is_enemy:
		var wd: Array = def().get("wd", [1, 3])
		var avg := dmg_curve(level) * rel_dmg() * power_dmg
		var mid := maxf(0.5, (wd[0] + wd[1]) * 0.5)
		return [maxi(1, int(round(avg * wd[0] / mid))), maxi(1, int(round(avg * wd[1] / mid)))]
	var it = equip.get("off" if use_off else "main")
	if it != null and Loot.is_weapon(it):
		return Loot.weapon_dmg(it)
	return [1, 3]

func dual_wielding() -> bool:
	return Loot.is_weapon(equip.get("main")) and Loot.is_weapon(equip.get("off"))

## Which slots an item may go in.
func slots_for(item: Dictionary) -> Array:
	var b := Loot.base_of(item)
	match b.get("cat", ""):
		"weapon":
			return ["main"] if b["two"] else ["main", "off"]
		"shield":
			return ["off"]
		"ring":
			return ["ring1", "ring2"]
		"amulet":
			return ["amulet"]
		_:
			return [b.get("cat", "")]

func can_equip(item: Dictionary, slot: String) -> String:
	if not slots_for(item).has(slot):
		return "Doesn't fit that slot"
	return Loot.req_problem(item, self)

## Equips an item, returning any items pushed back to the bag.
func equip_item(item: Dictionary, slot: String) -> Array:
	var out: Array = []
	if equip.has(slot):
		out.append(equip[slot])
	equip[slot] = item
	if slot == "main" and Loot.is_two_handed(item) and equip.has("off"):
		out.append(equip["off"])
		equip.erase("off")
	if slot == "off" and Loot.is_two_handed(equip.get("main")):
		out.append(equip["main"])
		equip.erase("main")
	recalc()
	out.append_array(validate_equipment())
	hp = mini(hp, max_hp())
	mp = mini(mp, max_mp())
	return out

func unequip(slot: String) -> Array:
	var out: Array = []
	if equip.has(slot):
		out.append(equip[slot])
		equip.erase(slot)
	recalc()
	out.append_array(validate_equipment())
	hp = mini(hp, max_hp())
	mp = mini(mp, max_mp())
	return out

## Removes items whose requirements are no longer met (e.g. after losing stat bonuses).
func validate_equipment() -> Array:
	var out: Array = []
	var changed := true
	while changed:
		changed = false
		for slot in equip.keys():
			if Loot.req_problem(equip[slot], self) != "":
				out.append(equip[slot])
				equip.erase(slot)
				recalc()
				changed = true
				break
	return out

## Equips the item in the first free (or first valid) slot. Returns displaced items.
func auto_equip(item: Dictionary) -> Array:
	var slots := slots_for(item)
	for sl in slots:
		if not equip.has(sl) and can_equip(item, sl) == "":
			return equip_item(item, sl)
	if can_equip(item, slots[0]) == "":
		return equip_item(item, slots[0])
	return [item]

# ---------------------------------------------------------------------------
# Save / load
# ---------------------------------------------------------------------------
func to_dict() -> Dictionary:
	var lk := {}
	for k in look:
		var v = look[k]
		lk[k] = {"c": v.to_html()} if v is Color else v
	return {"name": name, "cls": cls, "level": level, "xp": xp, "base": base.duplicate(),
		"nodes": nodes.keys(), "skill_points": skill_points, "hp": hp, "mp": mp,
		"look": lk, "hire_cost": hire_cost, "quote": quote, "equip": equip.duplicate(true), "job": job}

static func from_dict(d: Dictionary) -> Unit:
	var u := Unit.new()
	u.name = d.get("name", "Hero")
	u.cls = d.get("cls", "Hero")
	u.job = str(d.get("job", ""))
	u.quote = str(d.get("quote", ""))
	u.level = int(d.get("level", 1))
	u.xp = int(d.get("xp", 0))
	for s in STATS:
		u.base[s] = int(d.get("base", {}).get(s, 5))
	u.nodes = {"origin": true}
	var refund := 0
	for id in d.get("nodes", []):
		if DB.TREE.has(id):   # tolerate tree changes between versions
			u.nodes[id] = true
		elif id != "origin":
			refund += 1       # node no longer exists: give the point back
	# nodes cut off from the Origin by a tree change are refunded too
	var reach := {"origin": true}
	var stack: Array = ["origin"]
	while not stack.is_empty():
		var cur: String = stack.pop_back()
		for l in DB.TREE[cur]["links"]:
			if u.nodes.has(l) and not reach.has(l):
				reach[l] = true
				stack.append(l)
	for id2 in u.nodes.keys():
		if not reach.has(id2):
			u.nodes.erase(id2)
			refund += 1
	u.skill_points = int(d.get("skill_points", 0)) + refund
	var eq: Dictionary = d.get("equip", {})
	for slot in eq:
		if slot in SLOTS and eq[slot] is Dictionary and Loot.BASES.has(eq[slot].get("base", "")):
			u.equip[slot] = _clean_item(eq[slot])
	u.recalc()
	u.hp = clampi(int(d.get("hp", 1)), 0, u.max_hp())
	u.mp = clampi(int(d.get("mp", 0)), 0, u.max_mp())
	var lk: Dictionary = d.get("look", {})
	for k in lk:
		var v = lk[k]
		u.look[k] = Color.html(v["c"]) if v is Dictionary and v.has("c") else v
	u.hire_cost = int(d.get("hire_cost", 0))
	u.quote = d.get("quote", "")
	return u


## JSON turns ints into floats; tidy an item read from a save.
static func _clean_item(it: Dictionary) -> Dictionary:
	var out := it.duplicate(true)
	out["ilvl"] = int(out.get("ilvl", 1))
	var mods: Array = []
	for m in out.get("mods", []):
		var mm: Dictionary = m.duplicate()
		mm["v"] = int(mm.get("v", 0))
		if mm.has("v2"):
			mm["v2"] = int(mm["v2"])
		if mm.has("t"):
			mm["t"] = int(mm["t"])
		mods.append(mm)
	out["mods"] = mods
	return out
