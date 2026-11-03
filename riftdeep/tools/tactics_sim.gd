extends Node
## Headless balance check (dev only): heroes vs same-level monsters on the new curves.
##   godot --headless --path . res://tools/tactics_sim.tscn
const ROLES := ["Warrior", "Ranger", "Mage"]
const GEAR := {
	"Warrior": [["sword", "main"], ["shield_str", "off"], ["body_str", "body"], ["helm_str", "helm"], ["gloves_str", "gloves"], ["boots_str", "boots"]],
	"Ranger": [["bow", "main"], ["body_dex", "body"], ["helm_dex", "helm"], ["gloves_dex", "gloves"], ["boots_dex", "boots"]],
	"Mage": [["wand", "main"], ["body_int", "body"], ["helm_int", "helm"], ["gloves_int", "gloves"], ["boots_int", "boots"]],
}

func best_base(prefix: String, lvl: int) -> String:
	var best := ""
	for id in Loot.BASES:
		if id.begins_with(prefix + "_") and id.trim_prefix(prefix + "_").is_valid_int() and int(Loot.BASES[id]["lvl"]) <= lvl:
			if best == "" or int(Loot.BASES[id]["lvl"]) > int(Loot.BASES[best]["lvl"]):
				best = id
	return best

func make_member(role: String, level: int) -> Unit:
	var cd: Dictionary = Game.CLASSES[role]
	var u := Unit.make_hero(role, role)
	for s in Unit.STATS:
		u.base[s] = max(2, 5 + int(cd["bias"][s]))
	for i in level - 1:
		u.level_up()
	u.recalc()
	u.auto_allocate(cd["weights"], cd.get("arm", ""))
	for g in GEAR[role]:
		var bid := best_base(g[0], level)
		if bid == "":
			continue
		var it: Dictionary = Loot.make_item(bid, "magic", level) if g[1] in ["main", "body"] else Loot.make_normal(bid)
		if u.can_equip(it, g[1]) == "":
			u.equip_item(it, g[1])
	u.recalc()
	u.full_restore()
	return u

func pool_for(lvl: int) -> Array:
	var p: Array = []
	for id in DB.ENEMIES:
		var d: Dictionary = DB.ENEMIES[id]
		if d.get("boss", false) or id in ["reef_crab", "lash_eel", "sea_serpent", "spiderling"]:
			continue
		var lv := int(d["lvl"])
		if lv <= lvl + 1 and lv >= lvl - 6:
			p.append(id)
	if p.is_empty():
		var all: Array = DB.ENEMIES.keys().filter(func(x): return not DB.ENEMIES[x].get("boss", false) and not x in ["reef_crab", "lash_eel", "sea_serpent", "spiderling"])
		all.sort_custom(func(a, b): return int(DB.ENEMIES[a]["lvl"]) > int(DB.ENEMIES[b]["lvl"]))
		p = all.slice(0, 6) if lvl > 5 else ["slime"]
	return p

func best_spell(u: Unit) -> String:
	var best := ""
	var bb := -1.0
	for aid in u.learned:
		var ab: Dictionary = DB.ABILITIES[aid]
		if ab["kind"] == "magic" and u.mp >= int(ab["mp"]):
			var b: Array = ab.get("base", [0, 0])
			if b[0] + b[1] > bb:
				bb = b[0] + b[1]
				best = aid
	return best

func _ready() -> void:
	seed(4242)
	print("lvl | hero HP W/R/M | hero hit W/R/M (vs same-lvl mob) | mob HP | hits to kill | mob hit on W/M | hits to kill W/M | win% 3v4 | rounds")
	for lvl in [1, 3, 5, 10, 15, 20, 30, 45, 60, 75, 90]:
		var party: Array = []
		for r in ROLES:
			party.append(make_member(r, lvl))
		var pool := pool_for(lvl)
		var mob_hp := 0.0
		var mob_hit_w := 0.0
		var mob_hit_m := 0.0
		var hits := [0.0, 0.0, 0.0]
		var n := 0
		for id in pool:
			var e := Unit.make_enemy(id)
			e.scale_to(lvl)
			n += 1
			mob_hp += e.max_hp()
			mob_hit_w += Combat.expected_damage(e, party[0], DB.ABILITIES["attack"], ["hit", "melee"])
			mob_hit_m += Combat.expected_damage(e, party[2], DB.ABILITIES["attack"], ["hit", "melee"])
			for i in 3:
				var h: Unit = party[i]
				var sp := best_spell(h) if h.cls == "Mage" else ""
				var ab: Dictionary = DB.ABILITIES[sp] if sp != "" else DB.ABILITIES["attack"]
				var tags := DB.tags_for(sp if sp != "" else "attack", h)
				hits[i] += Combat.expected_damage(h, e, ab, tags) * Combat.hit_chance(h, e, ab)
		mob_hp /= n
		mob_hit_w /= n
		mob_hit_m /= n
		for i in 3:
			hits[i] /= n
		var avg_hit: float = (hits[0] + hits[1] + hits[2]) / 3.0
		# quick fights: 3 heroes vs 4 monsters, everyone trades basic hits, 1.15x for positioning
		var wins := 0
		var rounds := 0.0
		for f in 200:
			var hhp: Array = party.map(func(h): return float(h.max_hp()))
			var ehp: Array = []
			var eh: Array = []
			for k in 4:
				var e2 := Unit.make_enemy(pool.pick_random())
				e2.scale_to(lvl)
				ehp.append(float(e2.max_hp()))
				eh.append(Combat.expected_damage(e2, party[randi() % 3], DB.ABILITIES["attack"], ["hit", "melee"]) * 0.9)
			var r := 0
			while r < 60:
				r += 1
				for i in 3:
					if hhp[i] <= 0.0:
						continue
					for k in 4:
						if ehp[k] > 0.0:
							ehp[k] -= hits[i] * 1.15 * randf_range(0.8, 1.2)
							break
				if ehp.all(func(x): return x <= 0.0):
					break
				for k in 4:
					if ehp[k] <= 0.0:
						continue
					var alive: Array = []
					for i in 3:
						if hhp[i] > 0.0:
							alive.append(i)
					if alive.is_empty():
						break
					hhp[alive.pick_random()] -= eh[k] * randf_range(0.8, 1.2)
				if hhp.all(func(x): return x <= 0.0):
					break
			if ehp.all(func(x): return x <= 0.0):
				wins += 1
			rounds += r
		print("%3d | %4d %4d %4d | %5.1f %5.1f %5.1f | %5d | %4.1f | %5.1f %5.1f | %4.1f %4.1f | %3d%% | %4.1f" % [lvl, party[0].max_hp(), party[1].max_hp(), party[2].max_hp(),
			hits[0], hits[1], hits[2], int(mob_hp), mob_hp / maxf(1.0, avg_hit), mob_hit_w, mob_hit_m, party[0].max_hp() / maxf(1.0, mob_hit_w), party[2].max_hp() / maxf(1.0, mob_hit_m), wins / 2, rounds / 200.0])
	get_tree().quit()
