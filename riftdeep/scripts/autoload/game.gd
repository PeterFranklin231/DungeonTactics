extends Node
## Global game state: party, gold, inventory, recruits, the portal and dungeon progress.

const MAX_PARTY := 10
## Jobs for units left at home: resources they produce for every dungeon floor the party clears.
const JOBS := {"": {"name": "Resting", "res": "", "per_floor": 0}, "wood": {"name": "Chopping wood", "res": "wood", "per_floor": 1}}
const BUILD := {
	"wood_block": {"name": "Wood Block", "cost": {"wood": 1}, "desc": "A sturdy block. Stack them to make walls (up to 4 high). You can step up one block."},
	"door": {"name": "Door", "cost": {"wood": 2}, "desc": "A wooden door between walls. Anyone can walk through it."},
}
const MAX_HIRELINGS := 4
const CLASSES := {
	"Warrior": {"bias": {"str": 2, "con": 1, "dex": 0, "int": -1}, "weights": {"str": 3.0, "con": 2.0}, "arm": "warrior",
		"gear": [["sword", "main"], ["shield_str", "off"], ["body_str", "body"], ["helm_str", "helm"]]},
	"Ranger": {"bias": {"str": 0, "con": 0, "dex": 3, "int": -1}, "weights": {"dex": 3.0, "str": 1.0}, "arm": "ranger",
		"gear": [["bow", "main"], ["body_dex", "body"], ["boots_dex", "boots"]]},
	"Mage": {"bias": {"str": -1, "con": -1, "dex": 0, "int": 4}, "weights": {"int": 3.0}, "arm": "mage",
		"gear": [["wand", "main"], ["body_int", "body"], ["helm_int", "helm"]]},
	"Cleric": {"bias": {"str": -1, "con": 2, "dex": -1, "int": 2}, "weights": {"int": 2.0, "con": 2.0}, "arm": "healer",
		"gear": [["staff", "main"], ["body_int", "body"], ["gloves_int", "gloves"]]},
}
const BOAT_HOLD := 10

var main: Node
var party: Array = []
var gold := 100
var inventory := {}       # consumables: id -> count
var bag: Array = []       # equipment items (Dictionaries, see Loot)
var hirelings: Array = []   # wanderers at the campfire who could join
var town: Array = []        # your people who stay at home (and can work)
var resources := {"wood": 0}
var home := {"blocks": {}, "doors": {}}   # "x,y" -> stack height / door axis
var has_boat := false                       # (unused here; the shared trade window still asks)
var boat_hold := {"items": {}, "gear": []}
var shops := {}           # shop id -> merchant state
var stash := {"gold": 0, "items": {}, "gear": []}   # shared by every town's stash chest
var stash_rows := 3
var flags := {}
# The portal and its dungeons
var depth := 0             # floor of the current dungeon run (0 = at home)
var deepest := 0           # deepest floor ever reached
var portal := {"flavour": "basic"}   # what the portal was built with for this run
const STASH_COLS := 8
var seen := {}            # bestiary: enemy ids the party has fought
var world_seed := 1337
var busy_count := 0

var ui_busy: bool:
	get:
		return busy_count > 0

func _ready() -> void:
	_add_action("move_up", [KEY_UP, KEY_W])
	_add_action("move_down", [KEY_DOWN, KEY_S])
	_add_action("move_left", [KEY_LEFT, KEY_A])
	_add_action("move_right", [KEY_RIGHT, KEY_D])
	_add_action("menu", [KEY_TAB, KEY_M])
	load_settings()
	_add_action("interact", [KEY_ENTER, KEY_SPACE, KEY_E, KEY_KP_ENTER])
	# WASD drives menus exactly like the arrow keys.
	_add_action("ui_up", [KEY_W])
	_add_action("ui_down", [KEY_S])
	_add_action("ui_left", [KEY_A])
	_add_action("ui_right", [KEY_D])

func _add_action(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)

# ---------------------------------------------------------------------------
# Settings (kept in their own file, separate from save games)
# ---------------------------------------------------------------------------
const SETTINGS_PATH := "user://settings.cfg"
const CHEAT_STEPS := [1, 2, 3, 5]
## Testing multipliers: xp, gold, item_qty (how many items drop), item_quality (rarity odds).
var cheats := {"xp": 1, "gold": 1, "item_qty": 1, "item_quality": 1}

func cheat(key: String) -> float:
	return float(cheats.get(key, 1))

func set_cheat(key: String, v: int) -> void:
	cheats[key] = v
	save_settings()

func load_settings() -> void:
	var cf := ConfigFile.new()
	if cf.load(SETTINGS_PATH) != OK:
		return
	for k in cheats:
		var v := int(cf.get_value("testing", k, 1))
		cheats[k] = v if v in CHEAT_STEPS else 1

func save_settings() -> void:
	var cf := ConfigFile.new()
	for k in cheats:
		cf.set_value("testing", k, cheats[k])
	cf.save(SETTINGS_PATH)

## How many times a chance-based drop happens with the item quantity multiplier (chance x mult, overflow = extra drops).
func drop_rolls(chance: float) -> int:
	var c := chance * cheat("item_qty")
	var n := int(floor(c))
	if randf() < c - n:
		n += 1
	return n

func push_busy() -> void:
	busy_count += 1

func pop_busy() -> void:
	busy_count = max(0, busy_count - 1)

func new_game(hero_name: String) -> void:
	var hero := Unit.make_hero(hero_name, "Hero")
	hero.look = look_for_class("Hero", hero_name)
	party = [hero]
	gold = 150
	inventory = {"potion": 4, "ether": 2}
	bag = []
	hero.equip_item(Loot.make_normal("sword_1"), "main")
	hero.equip_item(Loot.make_normal("body_dex_0"), "body")
	hero.full_restore()
	hirelings.clear()
	town = []
	resources = {"wood": 10}
	home = {"blocks": {}, "doors": {}}
	seen = {}
	stash = {"gold": 0, "items": {}, "gear": []}
	stash_rows = 3
	flags = {}
	depth = 0
	deepest = 0
	# two wanderers share your fire from the start
	for i in 2:
		var cls: String = ["Warrior", "Cleric"][i]
		var c := make_hireling(cls)
		c.level = 1
		party.append(c)
	refresh_hirelings()
	refresh_shops()
	busy_count = 0

func look_for_class(c: String, seed_name: String) -> Dictionary:
	var h := absi(seed_name.hash())
	var skins := [Color(0.98, 0.84, 0.7), Color(0.88, 0.7, 0.55), Color(0.7, 0.5, 0.36), Color(0.5, 0.35, 0.25)]
	var hairs := [Color(0.3, 0.2, 0.1), Color(0.1, 0.08, 0.06), Color(0.85, 0.7, 0.35), Color(0.65, 0.25, 0.12), Color(0.8, 0.8, 0.8)]
	var look := {"skin": skins[h % skins.size()], "hair": hairs[(h / 7) % hairs.size()]}
	match c:
		"Hero":
			look.merge({"tunic": Color(0.22, 0.42, 0.85), "weapon": "sword"})
		"Warrior":
			look.merge({"tunic": Color(0.75, 0.2, 0.18), "weapon": "sword"})
		"Ranger":
			look.merge({"tunic": Color(0.22, 0.55, 0.25), "weapon": "bow"})
		"Mage":
			look.merge({"tunic": Color(0.48, 0.25, 0.7), "weapon": "staff", "hood": true, "orb": Color(1.0, 0.5, 0.15)})
		"Cleric":
			look.merge({"tunic": Color(0.92, 0.9, 0.82), "weapon": "staff", "orb": Color(1.0, 0.95, 0.55)})
		_:
			look.merge({"tunic": Color(0.6, 0.55, 0.45), "weapon": "none"})
	return look

func make_hireling(force_cls: String = "") -> Unit:
	var cls_name: String = force_cls if force_cls != "" else CLASSES.keys().pick_random()
	var cd: Dictionary = CLASSES[cls_name]
	var taken: Array = []
	for u in party + hirelings:
		taken.append(u.name)
	var nm: String = DB.FIRST_NAMES.pick_random()
	for i in 10:
		if not taken.has(nm):
			break
		nm = DB.FIRST_NAMES.pick_random()
	var u := Unit.make_hero(nm, cls_name)
	for s in Unit.STATS:
		u.base[s] = max(2, 5 + int(cd["bias"][s]) + randi_range(-1, 1))
	var lvl := 1 if force_cls != "" else clampi(randi_range(maxi(1, avg_level() - 2), avg_level() + 1), 1, 99)
	for i in lvl - 1:
		u.level_up()
	u.recalc()
	u.auto_allocate(cd["weights"], cd.get("arm", ""))
	for g in cd["gear"]:
		# the best piece of this kind they can wear at their level
		var best := ""
		for bid in Loot.BASES:
			var b: Dictionary = Loot.BASES[bid]
			if bid.begins_with(g[0] + "_") and bid.trim_prefix(g[0] + "_").is_valid_int() and int(b["lvl"]) <= lvl:
				if best == "" or int(b["lvl"]) > int(Loot.BASES[best]["lvl"]):
					best = bid
		if best != "":
			var it := Loot.make_normal(best)
			if u.can_equip(it, g[1]) == "":
				u.equip_item(it, g[1])
	u.full_restore()
	u.look = look_for_class(cls_name, nm)
	u.hire_cost = 40 + lvl * 40 + randi_range(0, 3) * 5
	u.quote = DB.HIRE_QUOTES.pick_random()
	return u

## Can we pay this build cost?
func can_afford(cost: Dictionary) -> bool:
	for k in cost:
		if int(resources.get(k, 0)) < int(cost[k]):
			return false
	return true

func pay(cost: Dictionary) -> bool:
	if not can_afford(cost):
		return false
	for k in cost:
		resources[k] = int(resources.get(k, 0)) - int(cost[k])
	return true

func refund(cost: Dictionary) -> void:
	for k in cost:
		resources[k] = int(resources.get(k, 0)) + int(cost[k])

## Everyone working at home produces for each floor cleared. Returns {resource: amount}.
func work_floor_cleared() -> Dictionary:
	var made := {}
	for u in town:
		var j: Dictionary = JOBS.get(u.job, JOBS[""])
		if j["res"] != "":
			made[j["res"]] = int(made.get(j["res"], 0)) + int(j["per_floor"])
	for k in made:
		resources[k] = int(resources.get(k, 0)) + int(made[k])
	return made

func avg_level() -> int:
	if party.is_empty():
		return 1
	var t := 0
	for u in party:
		t += u.level
	return maxi(1, t / party.size())

## Fills empty hireling seats. Called on new game and every rest.
func refresh_hirelings() -> void:
	# Sometimes someone leaves the pub overnight.
	if hirelings.size() > 0 and randf() < 0.4:
		hirelings.remove_at(randi() % hirelings.size())
	while hirelings.size() < MAX_HIRELINGS:
		hirelings.append(make_hireling())

func rest_party() -> void:
	for u in party:
		u.full_restore()

func item_count(id: String) -> int:
	return int(inventory.get(id, 0))

func add_item(id: String, n: int = 1) -> void:
	inventory[id] = item_count(id) + n

func remove_item(id: String, n: int = 1) -> void:
	inventory[id] = max(0, item_count(id) - n)
	if inventory[id] == 0:
		inventory.erase(id)

func has_any_items() -> bool:
	return inventory.size() > 0

# ---------------------------------------------------------------------------
# Carry capacity: every party member adds slots. Each equipment piece takes one slot;
# consumables stack up to STACK_SIZE per slot. Equipped items don't count.
# ---------------------------------------------------------------------------
const STACK_SIZE := 10

func capacity() -> int:
	var c := 0
	for u in party:
		c += u.carry_slots()
	return c

func stacks_for(count: int) -> int:
	return int(ceil(float(count) / STACK_SIZE))

func used_slots() -> int:
	var n := bag.size()
	for id in inventory:
		n += stacks_for(int(inventory[id]))
	return n

func free_slots() -> int:
	return capacity() - used_slots()

func can_carry_gear(n: int = 1) -> bool:
	return used_slots() + n <= capacity()

func can_carry_item(id: String, n: int = 1) -> bool:
	var extra := stacks_for(item_count(id) + n) - stacks_for(item_count(id))
	return used_slots() + extra <= capacity()

## Merchants: their own gold, consumable stock and equipment stock. Refreshed on every rest.
##   gear: [min tier, max tier, count, magic chance, rare chance] or [] for none
const MERCHANTS := {
	"trader": {"name": "Wandering Trader", "greeting": "Potions, steel and odds and ends - whatever the portal coughs up, I'll buy.",
		"gold": 1500, "items": {"potion": 20, "bandage": 20, "ether": 10, "hi_potion": 6, "phoenix_down": 4, "fire_bomb": 5}, "gear": [0, 1, 12, 0.3, 0.04]},
}
const SELL_RATE_GEAR := 0.25
const SELL_RATE_ITEMS := 0.5

func refresh_shops() -> void:
	for id in MERCHANTS:
		var m: Dictionary = MERCHANTS[id]
		var g: Array = m["gear"]
		# the trader's steel keeps pace with the party
		var lvl := maxi(1, maxi(avg_level(), deepest))
		shops[id] = {"gold": int(m["gold"]) + lvl * 60, "items": m["items"].duplicate(),
			"gear": Loot.shop_stock(lvl, g[2], g[3], g[4]) if g.size() > 0 else []}

func buy_price(e) -> int:
	return int(DB.ITEMS[e]["price"]) if e is String else Loot.value_of(e)

func sell_price(e) -> int:
	if e is String:
		return maxi(1, int(DB.ITEMS[e]["price"] * SELL_RATE_ITEMS))
	return maxi(1, int(Loot.value_of(e) * SELL_RATE_GEAR))

func add_gear(item: Dictionary) -> void:
	bag.append(item)

func remove_gear(item: Dictionary) -> void:
	var i := bag.find(item)
	if i >= 0:
		bag.remove_at(i)

func hold_stacks() -> int:
	return boat_hold["items"].size() + boat_hold["gear"].size()

func can_access_hold() -> bool:
	return false

## Applies a non-damage item to a unit. Returns a log line ("" if it had no effect).
func apply_item(id: String, u: Unit) -> String:
	var it: Dictionary = DB.ITEMS[id]
	match it["effect"]:
		"heal":
			if not u.is_alive() or u.hp >= u.max_hp():
				return ""
			var before := u.hp
			u.hp = min(u.max_hp(), u.hp + int(it["amount"]))
			return "%s recovers %d HP." % [u.name, u.hp - before]
		"mp":
			if not u.is_alive() or u.mp >= u.max_mp():
				return ""
			var b := u.mp
			u.mp = min(u.max_mp(), u.mp + int(it["amount"]))
			return "%s recovers %d MP." % [u.name, u.mp - b]
		"hot":
			if not u.is_alive():
				return ""
			u.add_regen(int(it["amount"]), float(it["rounds"]))
			return "%s is bandaged: {regen:%d:%s}." % [u.name, int(it["amount"]), str(it["rounds"])]
		"revive":
			if u.is_alive():
				return ""
			u.hp = max(1, int(u.max_hp() * float(it["amount"]) / 100.0))
			return "%s is revived!" % u.name
	return ""

## Defeat in the dungeon: everyone is carried home. You keep your gear, gold and levels.
func on_defeat() -> void:
	depth = 0
	rest_party()

# ---------------------------------------------------------------------------
# Money: carried gold is spent first, then the stash.
# ---------------------------------------------------------------------------
func funds() -> int:
	return gold + int(stash["gold"])

func spend(n: int) -> bool:
	if n <= 0:
		return true
	if funds() < n:
		return false
	var from_purse := mini(gold, n)
	gold -= from_purse
	stash["gold"] = int(stash["gold"]) - (n - from_purse)
	return true

func gold_text() -> String:
	if int(stash["gold"]) > 0:
		return "%d gold (+%d in stash)" % [gold, int(stash["gold"])]
	return "%d gold" % gold

func stash_capacity() -> int:
	return stash_rows * STASH_COLS

func stash_used() -> int:
	var n: int = stash["gear"].size()
	for id in stash["items"]:
		n += stacks_for(int(stash["items"][id]))
	return n

func stash_row_cost() -> int:
	return 150 * stash_rows

# ---------------------------------------------------------------------------
# Save / load (characters, gold and inventory only - you always wake at the inn)
# ---------------------------------------------------------------------------
const SAVE_PATH := "user://save.json"

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func save_game() -> void:
	var data := {"version": 2, "gold": gold, "inventory": inventory.duplicate(), "party": [], "seen": seen.keys(),
		"bag": bag.duplicate(true), "stash": stash.duplicate(true), "stash_rows": stash_rows, "flags": flags.duplicate(),
		"deepest": deepest, "hirelings": [], "town": [], "resources": resources.duplicate(), "home": home.duplicate(true)}
	for h in hirelings:
		data["hirelings"].append(h.to_dict())
	for tu in town:
		data["town"].append(tu.to_dict())
	for u in party:
		data["party"].append(u.to_dict())
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_error("Could not write save: %s" % FileAccess.get_open_error())
		return
	f.store_string(JSON.stringify(data, "\t"))

func load_game() -> bool:
	if not has_save():
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return false
	var data = JSON.parse_string(f.get_as_text())
	if not (data is Dictionary) or (data.get("party", []) as Array).is_empty():
		return false
	party = []
	for d in data["party"]:
		party.append(Unit.from_dict(d))
	gold = int(data.get("gold", 0))
	# Saves from before equipment existed: give the hero their starter kit.
	if int(data.get("version", 1)) < 2 and party[0].equip.is_empty():
		party[0].equip_item(Loot.make_normal("sword_1"), "main")
		party[0].equip_item(Loot.make_normal("body_dex_0"), "body")
	inventory = {}
	var inv: Dictionary = data.get("inventory", {})
	for k in inv:
		if DB.ITEMS.has(k) and int(inv[k]) > 0:
			inventory[k] = int(inv[k])
	seen = {}
	for id in data.get("seen", []):
		seen[id] = true
	bag = _clean_gear(data.get("bag", []))
	var st: Dictionary = data.get("stash", {})
	stash = {"gold": int(st.get("gold", 0)), "items": {}, "gear": _clean_gear(st.get("gear", []))}
	var sti: Dictionary = st.get("items", {})
	for k2 in sti:
		if DB.ITEMS.has(k2) and int(sti[k2]) > 0:
			stash["items"][k2] = int(sti[k2])
	stash_rows = int(data.get("stash_rows", 3))
	flags = data.get("flags", {})
	deepest = int(data.get("deepest", 0))
	town = []
	for td in data.get("town", []):
		town.append(Unit.from_dict(td))
	resources = {"wood": 0}
	var rs: Dictionary = data.get("resources", {})
	for rk in rs:
		resources[rk] = int(rs[rk])
	var hm: Dictionary = data.get("home", {})
	home = {"blocks": hm.get("blocks", {}), "doors": hm.get("doors", {})}
	depth = 0
	hirelings.clear()
	for hd in data.get("hirelings", []):
		var hu := Unit.from_dict(hd)
		hu.hire_cost = int(hd.get("hire_cost", 60))
		hirelings.append(hu)
	refresh_hirelings()
	refresh_shops()
	busy_count = 0
	return true

func _clean_gear(arr: Array) -> Array:
	var out: Array = []
	for it in arr:
		if it is Dictionary and Loot.BASES.has(it.get("base", "")):
			out.append(Unit._clean_item(it))
	return out

## Best value of a modifier across the party.
func party_best(key: String) -> float:
	var b := 0.0
	for u in party:
		b = maxf(b, u.mod(key))
	return b

func party_has_insight() -> bool:
	return false

func blight_active() -> bool:
	return false

func quest_state(_id: String) -> String:
	return ""
