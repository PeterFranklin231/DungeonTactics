class_name Combat
extends RefCounted
## Damage / healing formulas. Tune here.
##
## Diablo-style model:
##   Hits   = (weapon roll + "adds X damage") x (1 + 2% per point of the weapon's stat) x skill multiplier
##   Spells = (spell base + 0.8 per character level) x (1 + 2.5% per INT) x skill multiplier
##   then % modifiers, then the target's Armour (physical) or Resistances (elements).
## Monsters don't use stats for damage: their hits are their natural weapon roll ("wd").
## CON gives HP; it no longer shaves flat damage off incoming hits.

const ARMOUR_K := 6.0          # reduction = armour / (armour + K x hit)
const ARMOUR_CAP := 0.75
const CRIT_MULT := 1.6
const CRIT_PER_DEX := 0.003
const SPELL_PER_LEVEL := 0.3
const SPELL_PER_INT := 0.01

## Monsters (and stand-ins like typical_enemy) skip stat scaling.
static func is_monster(u: Unit) -> bool:
	return u.is_enemy or u.natural_wd.size() == 2

## [[stat, % per point], ...] scaling a Hit for this unit and ability.
static func stat_weights(user: Unit, ab: Dictionary) -> Array:
	var st: String = ab.get("stat", "atk")
	if st == "str" or st == "dex":
		return [[st, 0.02]]
	var kind: String = Loot.base_of(user.weapon()).get("kind", "") if user.weapon() != null else ""
	match kind:
		"bow":
			return [["dex", 0.02], ["str", 0.005]]
		"dagger":
			return [["dex", 0.015], ["str", 0.01]]
		"fist":
			return [["dex", 0.015], ["str", 0.01], ["con", user.mod("fist_con")]]
		"wand", "staff":
			return [["str", 0.01], ["int", 0.005]]
	if user.fists():   # bare hands
		return [["str", 0.02], ["dex", 0.005], ["con", user.mod("fist_con")]]
	return [["str", 0.02], ["dex", 0.005]]

## Damage multiplier from stats for a Hit (1.0 for monsters).
static func stat_mult(user: Unit, ab: Dictionary) -> float:
	if is_monster(user):
		return 1.0
	var m := 1.0
	for w in stat_weights(user, ab):
		m += user.stat(w[0]) * float(w[1])
	return m

## Which stats feed stat_mult, as readable text.
static func stat_bonus_text(user: Unit, ab: Dictionary = {}) -> String:
	var parts: Array = []
	for w in stat_weights(user, ab if not ab.is_empty() else DB.ABILITIES["attack"]):
		parts.append("%s%% per %s" % [str(snappedf(float(w[1]) * 100.0, 0.1)).trim_suffix(".0"), DB.STAT_NAMES[w[0]]])
	return ", ".join(parts)

static func crit_chance(user: Unit, ab: Dictionary = {}) -> float:
	if ab.get("kind", "") == "phys" and user.mod("assured_crit") > 0.0:
		return 1.0
	var sk := user.mod("sk_%s_crit" % ab.get("id", "")) if ab.has("id") else 0.0
	return clampf(0.05 + user.stat("dex") * CRIT_PER_DEX + user.mod("crit") + float(ab.get("crit_bonus", 0.0)) + sk, 0.0, 0.95)

static func _roll(lo: float, hi: float, avg: bool) -> float:
	return (lo + hi) * 0.5 if avg else randf_range(lo, hi)

## "Adds X-Y damage to Hits" from gear, passives and buffs (e.g. Flame Weapon).
static func _added(user: Unit, key: String, avg: bool) -> float:
	var hi := user.mod(key + "_max")
	if hi <= 0.0:
		return 0.0
	return _roll(user.mod(key + "_min"), hi, avg)

## Spell base before modifiers, INT included (monsters: their natural weapon roll).
static func spell_base(user: Unit, ab: Dictionary, avg: bool) -> float:
	if is_monster(user):
		var r := user.weapon_range()
		return _roll(float(r[0]), float(r[1]), avg)
	var b: Array = ab.get("base", [4, 6])
	var lv := user.level * SPELL_PER_LEVEL
	return _roll(float(b[0]) + lv, float(b[1]) + lv, avg) * (1.0 + user.stat("int") * SPELL_PER_INT)

## Raw damage by element before the target's defences and crits.
static func raw_parts(user: Unit, ab: Dictionary, tags: Array, use_off: bool, avg: bool) -> Dictionary:
	var parts := {"phys": 0.0, "fire": 0.0, "ice": 0.0, "lightning": 0.0, "shadow": 0.0}
	var el: String = ab.get("element", "phys")
	if not parts.has(el):
		el = "phys"
	var mult := float(ab.get("mult", 1.0))
	if ab["kind"] == "phys":
		var core := user.weapon_roll(use_off, avg)
		var sm := stat_mult(user, ab)
		if tags.has("hit"):
			core += _added(user, "add_phys", avg)
			parts["fire"] += _added(user, "add_fire", avg) * mult * sm
			parts["ice"] += _added(user, "add_ice", avg) * mult * sm
			parts["lightning"] += _added(user, "add_lightning", avg) * mult * sm
			if user.fists():
				core += _added(user, "fist_add_phys", avg)
				for fe in ["fire", "ice", "lightning"]:
					parts[fe] += _added(user, "fist_add_" + fe, avg) * mult * sm
		parts[el] += core * mult * sm
		# monk techniques: extra elemental chi damage (INT scaled, not weapon scaled)
		if ab.has("chi") and not is_monster(user):
			var chi: Dictionary = ab["chi"]
			var cb: Array = chi["base"]
			var lv := user.level * 0.6
			parts[chi["element"]] += _roll(float(cb[0]) + lv, float(cb[1]) + lv, avg) * (1.0 + user.stat("int") * 0.02)
		if use_off:
			for k in parts:
				parts[k] *= 0.7
	else:
		parts[el] += spell_base(user, ab, avg) * mult
	# Empowered (Wind Up) and passives that improve this one skill
	var bonus := 1.0
	if tags.has("hit"):
		bonus += user.mod("empower")
		if user.fists():
			bonus += user.mod("fist_dmg")
	if ab.has("id"):
		bonus += user.mod("sk_%s_dmg" % ab["id"])
	if bonus != 1.0:
		for k in parts:
			parts[k] *= bonus
	return parts

## Applies % modifiers and the target's defences to raw parts. Returns [total, biggest element].
static func _mitigate(user: Unit, target: Unit, ab: Dictionary, parts: Dictionary) -> Array:
	var total := 0.0
	var biggest := 0.0
	var big_el := "phys"
	for part in parts:
		var d: float = parts[part]
		if d <= 0.0:
			continue
		if part == "phys":
			d *= 1.0 + user.mod("phys_dmg")
			var arm := target.armour()
			if arm > 0.0:
				d *= 1.0 - minf(arm / (arm + ARMOUR_K * d), ARMOUR_CAP)
			d *= 1.0 - minf(target.mod("def_pct"), 0.75)
		else:
			d *= 1.0 + user.mod(part + "_dmg")
			d *= 1.0 - target.resist(part)
		if ab["kind"] == "magic":
			d *= 1.0 + user.mod("spell_dmg")
			d *= 1.0 - clampf(target.mod("magic_res"), 0.0, 0.75)
		d = maxf(d, 0.0)
		total += d
		if d > biggest:
			biggest = d
			big_el = part
	return [total, big_el]

static func _evade_chance(user: Unit, target: Unit) -> float:
	var ev := 0.03 + maxi(0, target.stat("dex") - user.stat("dex")) * 0.012 + target.mod("evasion") - user.mod("accuracy")
	return clampf(ev, 0.0, 0.5)

## Returns {dmg, crit, miss, element}.  use_off = off-hand strike when dual wielding.
static func damage(user: Unit, target: Unit, ab: Dictionary, tags: Array = [], use_off: bool = false) -> Dictionary:
	var res := {"dmg": 0, "crit": false, "miss": false, "element": ab.get("element", "phys")}
	# On the board: attacks from the side / behind are harder to dodge (evade_mult) and hit harder (pos_mult)
	if ab["kind"] == "phys" and randf() < _evade_chance(user, target) * float(ab.get("evade_mult", 1.0)):
		res["miss"] = true
		return res
	var m := _mitigate(user, target, ab, raw_parts(user, ab, tags, use_off, false))
	var total: float = m[0] * float(ab.get("pos_mult", 1.0))
	res["element"] = m[1]
	if randf() < crit_chance(user, ab):
		total *= CRIT_MULT
		res["crit"] = true
	total *= randf_range(0.95, 1.05)
	res["dmg"] = maxi(1, int(round(total)))
	return res

## Damage range of one basic Attack Hit per element, after stats and % modifiers,
## before the target's defences and crits.  {"phys": [lo, hi], "fire": [...], "ice": [...]}
static func hit_ranges(user: Unit, use_off: bool = false) -> Dictionary:
	var ab: Dictionary = DB.ABILITIES["attack"]
	var r := user.weapon_range(use_off)
	var sm := stat_mult(user, ab) * (0.7 if use_off else 1.0)
	var out := {}
	var pm := sm * (1.0 + user.mod("phys_dmg"))
	var fist := user.fists()
	var fb := 1.0 + (user.mod("fist_dmg") if fist else 0.0)
	pm *= fb
	var fp := 1.0 if fist else 0.0
	out["phys"] = [(float(r[0]) + float(user.mods.get("add_phys_min", 0.0)) + fp * user.mod("fist_add_phys_min")) * pm,
		(float(r[1]) + float(user.mods.get("add_phys_max", 0.0)) + fp * user.mod("fist_add_phys_max")) * pm]
	for el in ["fire", "ice", "lightning"]:
		var hi := float(user.mods.get("add_%s_max" % el, 0.0)) + fp * user.mod("fist_add_%s_max" % el)
		if hi > 0.0:
			var em := sm * (1.0 + user.mod(el + "_dmg")) * fb
			out[el] = [(float(user.mods.get("add_%s_min" % el, 0.0)) + fp * user.mod("fist_add_%s_min" % el)) * em, hi * em]
	return out

static func heal_amount(user: Unit, ab: Dictionary) -> int:
	var st: String = ab.get("stat", "int")
	var amt := (user.stat(st) * 2.0 + user.level * 2.0 + 8.0) * float(ab.get("mult", 1.0)) * (1.0 + user.mod("heal_pow"))
	return int(round(amt * randf_range(0.95, 1.05)))

static func flee_chance(heroes: Array, enemies: Array) -> float:
	var hd := 0.0
	var hn := 0
	for u in heroes:
		if u.is_alive():
			hd += u.stat("dex")
			hn += 1
	var ed := 0.0
	var en := 0
	for u in enemies:
		if u.is_alive():
			ed += u.stat("dex")
			en += 1
	if hn == 0 or en == 0:
		return 1.0
	return clampf(0.55 + (hd / hn - ed / en) * 0.03, 0.1, 0.95)


# ---------------------------------------------------------------------------
# Estimates for the UI ("what does this actually do against a normal enemy?")
# ---------------------------------------------------------------------------
## A stand-in "standard" monster of the given level, matching the bestiary curve
## (DB.ENEMIES are built around: hit ~ 4 + 1.7 x level, armour ~ 1.5 x level, DEX ~ 3 + level).
static func typical_enemy(level: int) -> Unit:
	var e := Unit.new()
	e.name = "Typical level %d enemy" % level
	e.level = level
	e.base = {"str": 3 + level, "dex": 3 + level, "con": 3 + level, "int": 1 + level / 2}
	var avg := Unit.dmg_curve(level)
	e.natural_wd = [int(round(avg * 0.8)), int(round(avg * 1.2))]
	e.recalc()
	e.mods["def"] = 0.4 * (3.0 + level)
	return e

## Chance a physical hit lands (spells always land).
static func hit_chance(user: Unit, target: Unit, ab: Dictionary) -> float:
	if ab["kind"] != "phys":
		return 1.0
	return 1.0 - _evade_chance(user, target) * float(ab.get("evade_mult", 1.0))

## Average damage of one landed hit (average rolls, crits averaged in). Mirrors damage().
static func expected_damage(user: Unit, target: Unit, ab: Dictionary, tags: Array = [], use_off: bool = false) -> float:
	var m := _mitigate(user, target, ab, raw_parts(user, ab, tags, use_off, true))
	return float(m[0]) * float(ab.get("pos_mult", 1.0)) * (1.0 + (CRIT_MULT - 1.0) * crit_chance(user, ab))

## Expected damage of a basic Attack per turn, including misses, off-hand strike and double hits.
static func expected_attack_turn(user: Unit, target: Unit) -> Dictionary:
	var ab: Dictionary = DB.ABILITIES["attack"]
	var tags := DB.tags_for("attack", user)
	var per_hit := expected_damage(user, target, ab, tags)
	var hc := hit_chance(user, target, ab)
	var turn := per_hit * hc
	if user.dual_wielding():
		turn += expected_damage(user, target, ab, tags, true) * hc
	if user.fists() and user.mod("attack_twice") > 0.0:
		turn += per_hit * hc
	if tags.has("melee"):
		var dh := user.mod("double_hit") + (user.mod("fist_double") if user.fists() else 0.0)
		turn += per_hit * hc * clampf(dh, 0.0, 1.0)
	return {"per_hit": per_hit, "hit": hc, "turn": turn}

## How much a typical enemy's basic hit is reduced by this unit's defences.
static func incoming_estimate(defender: Unit, level: int) -> Dictionary:
	var e := typical_enemy(level)
	var ab: Dictionary = DB.ABILITIES["attack"]
	var bare := Unit.new()   # same enemy hitting nothing at all, for comparison
	bare.base = {"str": 0, "dex": defender.stat("dex"), "con": 0, "int": 0}
	bare.recalc()
	var raw := expected_damage(e, bare, ab, ["hit", "melee"])
	var taken := expected_damage(e, defender, ab, ["hit", "melee"])
	return {"raw": raw, "taken": taken, "reduction": 1.0 - taken / maxf(raw, 0.01), "dodge": 1.0 - hit_chance(e, defender, ab)}

## Armour granted by a Shield spell from this caster (INT scaled, plus shield sharing).
static func shield_amount(caster: Unit, ab: Dictionary) -> int:
	var base := (caster.stat("int") * 1.5 + caster.level * 2.0) * float(ab.get("mult", 1.0)) + (4.0 if ab.get("target", "") == "ally" else 3.0)
	return int(round(base + caster.base_armour() * caster.mod("shield_share")))

## Poison added by an ability's "poison" block. Heroes: stat scaled; monsters: from their natural weapon.
static func poison_amount(user: Unit, pdef: Dictionary) -> int:
	if is_monster(user):
		var r := user.weapon_range()
		return int(round((r[0] + r[1]) * 0.5 * float(pdef.get("mult", 0.5)) + float(pdef.get("base", 2))))
	return int(round(user.stat(pdef.get("stat", "dex")) * float(pdef.get("mult", 0.5)) + user.level + float(pdef.get("base", 2))))

## Damage of a Hunter's Trap set by this unit.
static func trap_damage(user: Unit) -> int:
	return int(round((6.0 + user.level * 1.0) * (1.0 + user.stat("dex") * 0.02)))
