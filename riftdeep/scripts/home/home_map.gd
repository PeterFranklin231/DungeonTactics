class_name HomeMap
extends Node2D
## Home base, drawn on the same freely rotating board as the battles.
## Click a tile to walk there, click something to use it. Build walls and doors with wood (B),
## manage who travels and who stays home to work (T).

const W := 18
const H := 16
const FIRE := Vector2i(9, 8)
const PORTAL := Vector2i(9, 4)
const TRADER := Vector2i(13, 7)
const CHEST := Vector2i(5, 7)
const SPAWN := Vector2i(9, 11)
const MAX_STACK := 4
const BLOCKING := ["tree", "pine", "campfire", "portal", "trader", "chest"]

var location_name := "Home"
var board: Board
var ground := PackedInt32Array()
var props := {}            # Vector2i -> {type, ...}
var player_cell := SPAWN
var leader_vis := {}       # {g, gh, hop, facing}
var seats := {}            # Unit -> Vector2i (party members resting by the fire)
var workers := {}          # Unit -> Vector2i (town folk at work or idle)
var t := 0.0
var walking := false

# build mode
var building := false
var tool := "wood_block"

# UI
var layer: CanvasLayer
var res_label: Label
var hint_label: Label
var build_panel: PanelContainer
var build_buttons := {}
var roster: RosterWindow

func _ready() -> void:
	board = Board.new()
	board.battle = self
	board.w = W
	board.h = H
	board.heights.resize(W * H)
	board.kind.resize(W * H)
	add_child(board)
	_lay_out_meadow()
	_apply_blocks()
	leader_vis = {"g": Vector2(player_cell), "gh": float(board.height_at(player_cell)), "hop": 0.0, "facing": Vector2i(0, -1)}
	_place_people()
	_layout_camera()
	_build_ui()

func _lay_out_meadow() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	ground.resize(W * H)
	for y in H:
		for x in W:
			var c := Vector2i(x, y)
			var i := board.idx(c)
			ground[i] = Board.K_MEADOW if rng.randf() < 0.2 else Board.K_GRASS
			var edge := mini(mini(x, y), mini(W - 1 - x, H - 1 - y))
			if edge <= 1 or (edge == 2 and rng.randf() < 0.45):
				props[c] = {"type": "tree" if rng.randf() < 0.65 else "pine", "s": rng.randf_range(0.85, 1.15)}
	for y in range(PORTAL.y + 1, FIRE.y):
		ground[board.idx(Vector2i(FIRE.x, y))] = Board.K_DIRT
	for d in Board.DIRS:
		ground[board.idx(FIRE + d)] = Board.K_DIRT
		props.erase(FIRE + d)
	props[FIRE] = {"type": "campfire"}
	props[PORTAL] = {"type": "portal"}
	props[TRADER] = {"type": "trader", "look": {"skin": Color(0.85, 0.68, 0.52), "hair": Color(0.8, 0.8, 0.8), "tunic": Color(0.55, 0.38, 0.2), "weapon": "none", "hood": true}}
	props[CHEST] = {"type": "chest"}

static func key(c: Vector2i) -> String:
	return "%d,%d" % [c.x, c.y]

func stack_at(c: Vector2i) -> int:
	return int(Game.home["blocks"].get(key(c), 0))

func door_at(c: Vector2i) -> String:
	return str(Game.home["doors"].get(key(c), ""))

## Built blocks become the board's heights; their tops are wood.
func _apply_blocks() -> void:
	for y in H:
		for x in W:
			var c := Vector2i(x, y)
			var i := board.idx(c)
			var s := stack_at(c)
			board.heights[i] = s
			board.kind[i] = Board.K_WOOD if s > 0 else ground[i]

func _layout_camera() -> void:
	var vp := get_viewport_rect().size
	board.scale = Vector2(1.05, 1.05)
	board.position = Vector2(vp.x * 0.5, vp.y * 0.48)
	cam_home = [board.position, board.scale, board.yaw]

# ---------------------------------------------------------------------------
# People: party members rest by the fire, town folk work (or idle) around the meadow.
# ---------------------------------------------------------------------------
func _free_for_person(c: Vector2i, taken: Dictionary) -> bool:
	return board.in_bounds(c) and not props.has(c) and stack_at(c) == 0 and door_at(c) == "" and not taken.has(c) and c != player_cell

func _place_people() -> void:
	seats.clear()
	workers.clear()
	var taken := {}
	var ring: Array = []
	for y in H:
		for x in W:
			var c := Vector2i(x, y)
			var d := Board.dist(c, FIRE)
			if d >= 1 and d <= 4:
				ring.append(c)
	ring.sort_custom(func(a, b): return Board.dist(a, FIRE) < Board.dist(b, FIRE) or (Board.dist(a, FIRE) == Board.dist(b, FIRE) and a.y > b.y))
	for i in range(1, Game.party.size()):
		for c in ring:
			if _free_for_person(c, taken):
				seats[Game.party[i]] = c
				taken[c] = true
				break
	# choppers stand next to the trees; idle folk near the stash
	var by_trees: Array = []
	for c in props:
		if props[c]["type"] in ["tree", "pine"]:
			for d in Board.DIRS:
				if _free_for_person(c + d, {}) and not by_trees.has(c + d):
					by_trees.append(c + d)
	by_trees.sort_custom(func(a, b): return Board.dist(a, FIRE) < Board.dist(b, FIRE))
	var idle_spots: Array = ring.duplicate()
	idle_spots.reverse()
	for u in Game.town:
		var pool: Array = by_trees if u.job == "wood" else idle_spots
		for c in pool:
			if _free_for_person(c, taken):
				workers[u] = c
				taken[c] = true
				break

# ---------------------------------------------------------------------------
# Drawing (the board calls these in painter's order)
# ---------------------------------------------------------------------------
func draw_units_at(ci: CanvasItem, c: Vector2i) -> void:
	var p := board.ground_pos(c)
	if props.has(c):
		_draw_prop(ci, c, p, props[c])
	if door_at(c) != "":
		_draw_door(ci, c)
	for u in seats:
		if seats[u] == c:
			var fs := 1 if board.screen_dir(Vector2(FIRE - c)).x > 0.0 else -1
			Art.person(ci, p + Vector2(0, 3), 1.05, u.visual_look(), fs, 1.0, 0.0)
	for u2 in workers:
		if workers[u2] == c:
			_draw_worker(ci, c, p, u2)
	if c == _leader_draw_cell() and not Game.party.is_empty():
		var lp := board.project(leader_vis["g"], leader_vis["gh"]) + Vector2(0, -float(leader_vis["hop"]))
		var fs2 := 1 if board.screen_dir(Vector2(leader_vis["facing"])).x > 0.0 else -1
		Art.ellipse(ci, lp + Vector2(0, 2), 16, 6, Color(1, 1, 0.6, 0.25))
		Art.person(ci, lp, 1.1, Game.party[0].visual_look(), fs2, 1.0, absf(sin(t * 12.0)) * 2.0 if walking else 0.0)

func _leader_draw_cell() -> Vector2i:
	var g: Vector2 = leader_vis.get("g", Vector2(player_cell))
	return Vector2i(int(round(g.x)), int(round(g.y)))

func _draw_worker(ci: CanvasItem, c: Vector2i, p: Vector2, u: Unit) -> void:
	var look := u.visual_look()
	var tree_dir := Vector2.ZERO
	for d in Board.DIRS:
		if props.has(c + d) and props[c + d]["type"] in ["tree", "pine"]:
			tree_dir = Vector2(d)
	var fs := 1 if board.screen_dir(tree_dir if tree_dir != Vector2.ZERO else Vector2(FIRE - c)).x > 0.0 else -1
	if u.job == "wood":
		var swing := maxf(0.0, sin(t * 5.0 + c.x))
		Art.person(ci, p + Vector2(0, 2), 1.0, look, fs, 1.0, swing * 2.0)
		# axe
		var hand := p + Vector2(fs * 9, -20 - swing * 6)
		ci.draw_line(hand, hand + Vector2(fs * 6, -8 + swing * 10), Color(0.5, 0.33, 0.18), 2.0)
		ci.draw_colored_polygon(Art.pts([hand + Vector2(fs * 5, -10 + swing * 10), hand + Vector2(fs * 10, -8 + swing * 10), hand + Vector2(fs * 7, -4 + swing * 10)]), Color(0.75, 0.78, 0.82))
		# a little log pile
		for i in 3:
			ci.draw_circle(p + Vector2(-fs * (12 + i * 4), 4 - (i % 2) * 3), 2.5, Color(0.55, 0.36, 0.18))
	else:
		Art.person(ci, p + Vector2(0, 2), 1.0, look, fs, 1.0, 0.0)

func _draw_prop(ci: CanvasItem, c: Vector2i, p: Vector2, pr: Dictionary) -> void:
	var hv := absi((c.x * 73856093) ^ (c.y * 19349663))
	match pr["type"]:
		"tree":
			Art.tree(ci, p + Vector2((hv % 9) - 4, (hv / 9 % 5) - 2), float(pr.get("s", 1.0)), hv)
		"pine":
			Art.pine(ci, p + Vector2(-6, -2), 0.8 * float(pr.get("s", 1.0)), hv)
			Art.pine(ci, p + Vector2(7, 3), 0.9 * float(pr.get("s", 1.0)), hv / 3)
		"trader":
			Art.person(ci, p + Vector2(0, 2), 1.05, pr["look"], -1, 1.0, 0.0)
		"chest":
			Art.shadow(ci, p + Vector2(0, 3), 18, 6)
			Art.iso_box(ci, p, 16, Color(0.55, 0.34, 0.16), Color(0.45, 0.27, 0.12), Color(0.38, 0.22, 0.1), true, true, 18, 9)
			ci.draw_rect(Rect2(p + Vector2(-3, -10), Vector2(6, 6)), Color(0.95, 0.8, 0.3))
		"campfire":
			var tt := t
			Art.ellipse(ci, p + Vector2(0, 2), 20, 8, Color(0.25, 0.2, 0.18))
			for i in 6:
				var a := i * TAU / 6.0 + board.yaw
				ci.draw_circle(p + Vector2(cos(a) * 15, sin(a) * 6), 3.5, Color(0.45, 0.43, 0.42))
			ci.draw_line(p + Vector2(-10, 2), p + Vector2(10, -3), Color(0.4, 0.25, 0.12), 4)
			ci.draw_line(p + Vector2(-9, -3), p + Vector2(9, 2), Color(0.35, 0.22, 0.1), 4)
			for i in 4:
				var fx := p + Vector2(-9 + i * 6, -2)
				var hgt := 14.0 + sin(tt * 10.0 + i * 1.9) * 4.0
				ci.draw_colored_polygon(Art.pts([fx + Vector2(-5, 0), fx + Vector2(0, -hgt), fx + Vector2(5, 0)]), Color(1.0, 0.45, 0.1, 0.9))
				ci.draw_colored_polygon(Art.pts([fx + Vector2(-2.5, 0), fx + Vector2(0, -hgt * 0.6), fx + Vector2(2.5, 0)]), Color(1.0, 0.88, 0.35))
			ci.draw_circle(p + Vector2(0, -8), 40, Color(1.0, 0.6, 0.2, 0.08))
		"portal":
			var tt2 := t
			Art.iso_box(ci, p, 8, Color(0.5, 0.5, 0.55), Color(0.4, 0.4, 0.45), Color(0.33, 0.33, 0.38), true, true, 28, 14)
			var ctr := p + Vector2(0, -40)
			ci.draw_arc(ctr, 26, 0, TAU, 40, Color(0.42, 0.42, 0.48), 7.0)
			ci.draw_arc(ctr, 26, 0, TAU, 40, Color(0.6, 0.6, 0.68), 2.0)
			for i in 6:
				var a2 := i * TAU / 6.0 + tt2 * 0.2
				ci.draw_circle(ctr + Vector2(cos(a2), sin(a2)) * 26, 3.0, Color(0.5, 0.85, 1.0))
			for i in 5:
				var r := 20.0 - i * 3.5
				var a3 := tt2 * (1.5 + i * 0.4)
				ci.draw_arc(ctr, r, a3, a3 + PI * 1.3, 18, Color(0.45, 0.6, 1.0, 0.4), 2.5)
			ci.draw_circle(ctr, 8, Color(0.75, 0.85, 1.0, 0.5 + 0.2 * sin(tt2 * 3.0)))
			ci.draw_circle(ctr, 34, Color(0.4, 0.6, 1.0, 0.06))

## A door stands on the grid line through its tile, between the walls either side.
func _draw_door(ci: CanvasItem, c: Vector2i) -> void:
	var axis := Vector2(1, 0) if door_at(c) == "x" else Vector2(0, 1)
	var g := Vector2(c)
	var up := Vector2(0, -2.2 * Board.HZ)
	var a := board.project(g - axis * 0.5, 0.0)
	var b := board.project(g + axis * 0.5, 0.0)
	var a2 := board.project(g - axis * 0.36, 0.0)
	var b2 := board.project(g + axis * 0.36, 0.0)
	var wood := Color(0.5, 0.32, 0.17)
	ci.draw_colored_polygon(PackedVector2Array([a, b, b + up, a + up]), wood.darkened(0.45))
	ci.draw_colored_polygon(PackedVector2Array([a2, b2, b2 + up * 0.92, a2 + up * 0.92]), wood)
	for f in [0.33, 0.66]:
		ci.draw_line(a2.lerp(b2, f), a2.lerp(b2, f) + up * 0.92, wood.darkened(0.25), 1.0)
	ci.draw_circle(a2.lerp(b2, 0.8) + up * 0.45, 1.8, Color(0.9, 0.78, 0.35))

func draw_overlays(_ci: CanvasItem) -> void:
	pass

func _process(delta: float) -> void:
	t += delta
	if res_label != null:
		res_label.text = "Wood %d     Gold %d     Party %d / %d     Town %d" % [int(Game.resources.get("wood", 0)), Game.gold, Game.party.size(), Game.MAX_PARTY, Game.town.size()]

# ---------------------------------------------------------------------------
# UI
# ---------------------------------------------------------------------------
func _build_ui() -> void:
	layer = CanvasLayer.new()
	layer.layer = 4
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UiKit.theme()
	layer.add_child(root)
	var top := PanelContainer.new()
	top.position = Vector2(12, 12)
	root.add_child(top)
	var tv := VBoxContainer.new()
	top.add_child(tv)
	tv.add_child(UiKit.label("Home", 20, Color(1, 0.88, 0.5)))
	res_label = UiKit.label("", 15)
	tv.add_child(res_label)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	tv.add_child(row)
	for b in [["Party (Tab)", func(): Game.main.menu.open_menu()], ["Roster (T)", open_roster], ["Build (B)", toggle_build]]:
		var bt := Button.new()
		bt.text = b[0]
		bt.focus_mode = Control.FOCUS_NONE
		bt.pressed.connect(b[1])
		row.add_child(bt)
	hint_label = UiKit.label("", 14, Color(0.85, 0.88, 1.0))
	hint_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	hint_label.offset_left = 16
	hint_label.offset_top = -34
	hint_label.offset_right = 900
	hint_label.offset_bottom = -10
	root.add_child(hint_label)
	var cam_hint := UiKit.label("Click to walk / use   -   left-drag pan   -   right-drag rotate   -   wheel zoom   -   Q / E turn   -   R reset", 12, Color(0.6, 0.64, 0.8))
	cam_hint.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	cam_hint.offset_left = -700
	cam_hint.offset_right = -14
	cam_hint.offset_top = -30
	cam_hint.offset_bottom = -10
	cam_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(cam_hint)

	build_panel = PanelContainer.new()
	build_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	build_panel.offset_left = -330
	build_panel.offset_right = 330
	build_panel.offset_top = -120
	build_panel.offset_bottom = -44
	build_panel.visible = false
	root.add_child(build_panel)
	var bv := VBoxContainer.new()
	build_panel.add_child(bv)
	bv.add_child(UiKit.label("Build  -  click a tile to place, right-click or B to finish", 14, Color(1, 0.88, 0.5)))
	var brow := HBoxContainer.new()
	brow.add_theme_constant_override("separation", 6)
	bv.add_child(brow)
	for id in Game.BUILD:
		var bd: Dictionary = Game.BUILD[id]
		var cost := ", ".join(bd["cost"].keys().map(func(k): return "%d %s" % [int(bd["cost"][k]), k]))
		var bb := Button.new()
		bb.text = "%s  (%s)" % [bd["name"], cost]
		bb.tooltip_text = bd["desc"]
		bb.focus_mode = Control.FOCUS_NONE
		bb.pressed.connect(func(): _set_tool(id))
		brow.add_child(bb)
		build_buttons[id] = bb
	var rb := Button.new()
	rb.text = "Remove (refund)"
	rb.focus_mode = Control.FOCUS_NONE
	rb.pressed.connect(func(): _set_tool("remove"))
	brow.add_child(rb)
	build_buttons["remove"] = rb
	var db := Button.new()
	db.text = "Done"
	db.focus_mode = Control.FOCUS_NONE
	db.pressed.connect(toggle_build)
	brow.add_child(db)

	roster = RosterWindow.new()
	roster.home = self
	root.add_child(roster)

func open_roster() -> void:
	if building:
		toggle_build()
	roster.open()

func toggle_build() -> void:
	building = not building
	build_panel.visible = building
	board.highlights = {}
	if building:
		_set_tool(tool)
	else:
		hint_label.text = ""

func _set_tool(id: String) -> void:
	tool = id
	for k in build_buttons:
		build_buttons[k].add_theme_color_override("font_color", Color(1, 0.88, 0.45) if k == id else Color(0.9, 0.92, 1.0))
	_update_build_preview()

# ---------------------------------------------------------------------------
# Building
# ---------------------------------------------------------------------------
func _build_problem(c: Vector2i) -> String:
	if not board.in_bounds(c):
		return "out"
	if tool == "remove":
		return "" if stack_at(c) > 0 or door_at(c) != "" else "Nothing built here."
	var cost: Dictionary = Game.BUILD[tool]["cost"]
	if props.has(c):
		return "Something is in the way."
	if c == player_cell or seats.values().has(c) or workers.values().has(c):
		return "Someone is standing there."
	if door_at(c) != "":
		return "There's a door here."
	if tool == "wood_block" and stack_at(c) >= MAX_STACK:
		return "Walls can only be %d blocks high." % MAX_STACK
	if tool == "door" and stack_at(c) > 0:
		return "Doors go on the ground."
	if not Game.can_afford(cost):
		return "Not enough wood."
	return ""

func _update_build_preview() -> void:
	if not building:
		return
	board.highlights = {}
	var c := board.hover
	if board.in_bounds(c):
		var prob := _build_problem(c)
		board.highlights[c] = Color(0.4, 1.0, 0.45, 0.5) if prob == "" else Color(1.0, 0.35, 0.3, 0.45)
		var label: String = "Remove" if tool == "remove" else Game.BUILD[tool]["name"]
		hint_label.text = label + ("" if prob == "" else ":  " + prob)
	else:
		hint_label.text = ""

func _place(c: Vector2i) -> void:
	if _build_problem(c) != "":
		return
	var k := key(c)
	match tool:
		"wood_block":
			Game.pay(Game.BUILD["wood_block"]["cost"])
			Game.home["blocks"][k] = stack_at(c) + 1
		"door":
			Game.pay(Game.BUILD["door"]["cost"])
			var walls_x := stack_at(c + Vector2i(1, 0)) > 0 or stack_at(c - Vector2i(1, 0)) > 0
			var walls_y := stack_at(c + Vector2i(0, 1)) > 0 or stack_at(c - Vector2i(0, 1)) > 0
			Game.home["doors"][k] = "y" if walls_y and not walls_x else "x"
		"remove":
			if door_at(c) != "":
				Game.home["doors"].erase(k)
				Game.refund(Game.BUILD["door"]["cost"])
			elif stack_at(c) > 0:
				var n := stack_at(c) - 1
				if n <= 0:
					Game.home["blocks"].erase(k)
				else:
					Game.home["blocks"][k] = n
				Game.refund(Game.BUILD["wood_block"]["cost"])
	_apply_blocks()
	_place_people()
	_update_build_preview()

# ---------------------------------------------------------------------------
# Walking & using things
# ---------------------------------------------------------------------------
func _walkable(c: Vector2i) -> bool:
	if not board.in_bounds(c):
		return false
	if props.has(c) and props[c]["type"] in BLOCKING:
		return false
	return true

func _path(from: Vector2i, goals: Dictionary) -> Array:
	var prev := {from: from}
	var q: Array = [from]
	while not q.is_empty():
		var c: Vector2i = q.pop_front()
		if goals.has(c):
			var path: Array = [c]
			while c != from:
				c = prev[c]
				path.push_front(c)
			return path
		for d in Board.DIRS:
			var nb: Vector2i = c + d
			if prev.has(nb) or not _walkable(nb):
				continue
			if absi(stack_at(nb) - stack_at(c)) > 1:
				continue
			prev[nb] = c
			q.append(nb)
	return []

func _click(c: Vector2i) -> void:
	if not board.in_bounds(c) or walking or Game.ui_busy:
		return
	var target_use := Callable()
	var goals := {}
	if props.has(c) and props[c]["type"] in ["campfire", "portal", "trader", "chest"]:
		target_use = _use.bind(c)
		for d in Board.DIRS:
			if _walkable(c + d):
				goals[c + d] = true
	else:
		var person = _person_at(c)
		if person != null:
			target_use = _talk.bind(person)
			for d in Board.DIRS:
				if _walkable(c + d):
					goals[c + d] = true
		elif _walkable(c):
			goals[c] = true
	if goals.has(player_cell) and target_use.is_valid():
		leader_vis["facing"] = c - player_cell
		target_use.call()
		return
	var path := _path(player_cell, goals)
	if path.is_empty():
		hint_label.text = "Can't get there."
		return
	await _walk(path)
	if target_use.is_valid():
		leader_vis["facing"] = c - player_cell
		target_use.call()

func _person_at(c: Vector2i):
	for u in seats:
		if seats[u] == c:
			return u
	for u2 in workers:
		if workers[u2] == c:
			return u2
	return null

func _walk(path: Array) -> void:
	walking = true
	for i in range(1, path.size()):
		var a: Vector2i = path[i - 1]
		var b: Vector2i = path[i]
		leader_vis["facing"] = b - a
		var ga := Vector2(a)
		var gb := Vector2(b)
		var ha := float(stack_at(a))
		var hb := float(stack_at(b))
		var tw := create_tween()
		tw.tween_method(func(k: float):
			leader_vis["g"] = ga.lerp(gb, k)
			leader_vis["gh"] = lerpf(ha, hb, k)
			leader_vis["hop"] = sin(k * PI) * (4.0 + maxf(0.0, hb - ha) * Board.HZ), 0.0, 1.0, 0.14)
		await tw.finished
		player_cell = b
	leader_vis["hop"] = 0.0
	walking = false

func _talk(u: Unit) -> void:
	var where: String = "resting by the fire" if seats.has(u) else Game.JOBS.get(u.job, Game.JOBS[""])["name"].to_lower()
	var q := u.quote if u.quote != "" else "Ready when you are."
	await Game.main.dialog.ask("%s (Lv %d %s, %s): \"%s\"" % [u.name, u.level, u.cls, where, q])

func _use(c: Vector2i) -> void:
	match props[c]["type"]:
		"campfire":
			await _campfire()
		"portal":
			await _portal()
		"trader":
			await Game.main.open_shop("trader")
		"chest":
			await Game.main.open_stash()

func say(text: String, choices: Array = []) -> int:
	return await Game.main.dialog.ask(text, choices)

func _campfire() -> void:
	while true:
		var r := await say("The fire crackles. Your companions are resting.", ["Rest and save the game", "Recruit wanderers", "Roster: party and town", "Leave"])
		match r:
			0:
				Game.rest_party()
				for tu in Game.town:
					tu.full_restore()
				Game.refresh_hirelings()
				Game.refresh_shops()
				Game.save_game()
				await say("Everyone rests by the fire. HP and MP restored. Game saved.\nNew wanderers have drifted in, and the trader has fresh stock.")
			1:
				await _recruit()
			2:
				open_roster()
				return
			_:
				return

func _recruit() -> void:
	while true:
		if Game.hirelings.is_empty():
			await say("Nobody else is at the fire tonight.")
			return
		var opts: Array = []
		for hu in Game.hirelings:
			var tip: Array = [["%s - Lv %d %s" % [hu.name, hu.level, hu.cls], Color(1, 0.9, 0.55), false], "\"%s\"" % hu.quote,
				hu.stat_line(), "Move %d   Jump %d" % [hu.move_range(), hu.jump_height()], "Skills: " + hu.skill_names()]
			opts.append({"text": "%s  (Lv %d %s)  -  %d gold" % [hu.name, hu.level, hu.cls, hu.hire_cost], "tip": tip, "disabled": Game.funds() < hu.hire_cost})
		opts.append("Back")
		var r := await say("Wanderers by the fire will settle in your town for a fee. Use the Roster to bring them along on runs, or put them to work at home.   %s" % Game.gold_text(), opts)
		if r < 0 or r >= Game.hirelings.size():
			return
		var hu2: Unit = Game.hirelings[r]
		if Game.spend(hu2.hire_cost):
			Game.hirelings.remove_at(r)
			hu2.full_restore()
			hu2.job = "wood"
			Game.town.append(hu2)
			_place_people()
			await say("%s joins your town and heads off to chop wood. (Change their job in the Roster.)" % hu2.name)

## The portal device: empty for a blank dungeon, or an item to dive into its Item World.
func _portal() -> void:
	var deep := "Deepest floor reached through an empty portal: %d." % Game.deepest if Game.deepest > 0 else "Nobody has gone through yet."
	var r := await say("The portal device hums. Place an item in the ring and the rift opens into that item's world - every floor you clear inside makes the item stronger. Open it empty and it leads into a plain dungeon.\n\n" + deep,
		["Open the portal empty", "Place an item in the portal", "Leave"])
	match r:
		0:
			Game.main.start_run(null)
		1:
			await _pick_item()

func _pick_item() -> void:
	var items: Array = []
	for u in Game.party:
		for slot in u.equip:
			items.append([u.equip[slot], u.name])
	for it in Game.bag:
		items.append([it, "bag"])
	if items.is_empty():
		await say("You have no items to place in the portal.")
		return
	var opts: Array = []
	for e in items:
		var it: Dictionary = e[0]
		var tip: Array = Loot.describe(it, null)
		tip.append(["Item World starts at monster level %d" % Loot.world_level(it), Color(0.6, 0.95, 1.0), false])
		opts.append({"text": "%s   (%s, world level %d)" % [it.get("name", "?"), e[1], Loot.world_level(it)], "tip": tip})
	opts.append("Back")
	var r := await say("Which item goes into the portal?", opts)
	if r < 0 or r >= items.size():
		return
	Game.main.start_run(items[r][0])

# ---------------------------------------------------------------------------
# Camera and mouse (same controls as battles)
# ---------------------------------------------------------------------------
const DRAG_START := 6.0
var cam_home: Array = []
var press_btn := -1
var press_pos := Vector2.ZERO
var dragged := false

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			_zoom_at(mb.position, 1.12 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.12)
			get_viewport().set_input_as_handled()
			return
		if mb.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
			if mb.pressed:
				press_btn = mb.button_index
				press_pos = mb.position
				dragged = false
			elif mb.button_index == press_btn:
				press_btn = -1
				get_viewport().set_input_as_handled()
				if not dragged and not Game.ui_busy:
					if mb.button_index == MOUSE_BUTTON_LEFT:
						if building:
							_place(board.hover)
						else:
							_click(board.hover)
					elif mb.button_index == MOUSE_BUTTON_RIGHT and building:
						toggle_build()
				dragged = false
		return
	if event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if press_btn != -1:
			if not dragged and mm.position.distance_to(press_pos) > DRAG_START:
				dragged = true
			if dragged:
				if press_btn == MOUSE_BUTTON_RIGHT:
					_rotate_view(-mm.relative.x * 0.008)
				else:
					board.position += mm.relative
		_refresh_hover()
		return
	if event is InputEventKey and event.pressed and not event.echo and not Game.ui_busy:
		match event.keycode:
			KEY_R:
				_reset_view()
			KEY_Q:
				_rotate_view(PI / 4.0)
			KEY_E:
				_rotate_view(-PI / 4.0)
			KEY_B:
				toggle_build()
			KEY_T:
				open_roster()

func _refresh_hover() -> void:
	var c := board.cell_at(board.get_local_mouse_position())
	if c != board.hover:
		board.hover = c
		_update_build_preview()

func _zoom_at(screen_p: Vector2, f: float) -> void:
	var local := board.get_global_transform().affine_inverse() * screen_p
	var s := clampf(board.scale.x * f, 0.45, 2.8)
	board.scale = Vector2(s, s)
	board.position = screen_p - local * s
	_refresh_hover()

func _rotate_view(da: float) -> void:
	var vp := get_viewport_rect().size
	var pivot_screen := vp * 0.5
	var local := board.get_global_transform().affine_inverse() * pivot_screen
	var q := Vector2((local.x / (Board.TW * 0.5) + local.y / (Board.TH * 0.5)) * 0.5,
		(local.y / (Board.TH * 0.5) - local.x / (Board.TW * 0.5)) * 0.5)
	var g := q.rotated(-board.yaw) + Vector2((W - 1) * 0.5, (H - 1) * 0.5)
	board.set_yaw(board.yaw + da)
	board.position = pivot_screen - board.project(g, 0.0) * board.scale.x
	_refresh_hover()

func _reset_view() -> void:
	if cam_home.size() == 3:
		board.yaw = cam_home[2]
		board.scale = cam_home[1]
		board.position = cam_home[0]
		_refresh_hover()
