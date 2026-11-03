class_name TacticsBattle
extends Node2D
## A dungeon floor fought FF Tactics style: units take turns by charge time (CT). On its turn a unit
## may Move once and Act once, in either order, then Wait and choose which way to face.
## Attacks from the side or behind land more often and hit harder; high ground helps; friends next
## to your target flank it.

signal finished(result: String)   # "victory" | "defeat"
signal picked(value)

const FRONT_BONUS := 0.0
const SIDE_BONUS := 0.15
const BACK_BONUS := 0.35
const FLANK_BONUS := 0.15
const HEIGHT_STEP := 0.08
const EXCLUDE := ["reef_crab", "lash_eel", "sea_serpent", "spiderling"]

var depth := 1                 # floor number of this run
var dungeon_level := 1         # monster level on this floor
var world_name := ""           # the item whose world this is ("" = an empty portal)
var boss_floor := false
var board: Board
var heroes: Array = []
var enemies: Array = []
var vis := {}          # Unit -> {home (feet, board coords), off, hop, flash, alpha}
var popups: Array = []
var fx: Array = []
var active: Unit = null
var ended := false
var t := 0.0
var rng := RandomNumberGenerator.new()
var turn_moved := false
var turn_acted := false
var ct_after = null
var summon_count := 0
var start_enemies := 1
var highlight: Unit = null

# board selection
var selecting := false
var valid_cells := {}
var area_fn := Callable()        # cell -> Array of cells (area preview)
var target_ctx := {}             # {u, aid} while choosing a target, for previews

# UI
var layer: CanvasLayer
var msg_label: RichTextLabel
var msg_panel: PanelContainer
var cmd_title: Label
var cmd_box: VBoxContainer
var cmd_panel: PanelContainer
var hint_label: Label
var floor_label: Label
var order_box: VBoxContainer
var party_rows: Array = []
var unit_tip: InfoTip

# Battle log (top bar + drop-down)
static var log_lines := 1
static var log_height := 260.0
var event_log: Array = []
var transient := ""
var clock := 0.0
var log_drop: PanelContainer
var log_text: RichTextLabel
var log_bottom_btn: Button
var lines_btn: Button
var drop_btn: Button
var resizing := false

func setup(d: int, lvl: int, world: String) -> void:
	depth = d
	dungeon_level = lvl
	world_name = world
	boss_floor = d % 2 == 0
	heroes = Game.party

func _ready() -> void:
	rng.randomize()
	board = Board.new()
	board.battle = self
	add_child(board)
	board.generate(rng)
	enemies = _roll_enemies()
	start_enemies = enemies.size()
	var hc := board.spawn_cells("near", heroes.size(), rng)
	for i in heroes.size():
		var hu: Unit = heroes[i]
		hu.cell = hc[i] if i < hc.size() else hc[0]
		hu.facing = Vector2i(0, -1)
		hu.ct = rng.randf_range(10.0, 60.0)
		hu.buffs.clear()
		hu.protector = null
		_add_vis(hu)
	var ec := board.spawn_cells("far", enemies.size(), rng)
	for i in enemies.size():
		var e: Unit = enemies[i]
		e.cell = ec[i] if i < ec.size() else ec[ec.size() - 1]
		e.facing = Vector2i(0, 1)
		e.ct = rng.randf_range(0.0, 50.0)
		_add_vis(e)
	_layout_camera()
	_build_ui()
	var names: Array = []
	for e in enemies:
		names.append(e.name)
	msg("Floor %d%s: %s" % [depth, "  (Boss floor)" if boss_floor else "", ", ".join(names)])
	_run.call_deferred()

func _add_vis(u: Unit) -> void:
	vis[u] = {"g": Vector2(u.cell), "gh": float(board.height_at(u.cell)), "home": board.ground_pos(u.cell), "off": Vector2.ZERO, "hop": 0.0, "flash": 0.0, "alpha": 1.0}

## Enemies for this floor: monsters around the dungeon level, scaled up without limit the deeper you go.
## Every second floor holds a boss - a real one when its level fits, otherwise an Elite champion.
func _roll_enemies() -> Array:
	var lvl_target := dungeon_level
	var pool: Array = []
	var all: Array = []
	for id in DB.ENEMIES:
		var d: Dictionary = DB.ENEMIES[id]
		if d.get("boss", false) or id in EXCLUDE:
			continue
		all.append(id)
		var lv := int(d.get("lvl", 1))
		if lv <= lvl_target + 1 and lv >= lvl_target - 6:
			pool.append(id)
	if pool.is_empty():
		all.sort_custom(func(a, b): return int(DB.ENEMIES[a]["lvl"]) > int(DB.ENEMIES[b]["lvl"]))
		pool = all.slice(0, 6) if lvl_target > 5 else ["slime"]
	var out: Array = []
	var n := 3 + mini(3, depth / 3)
	if boss_floor:
		n = 2 + mini(2, depth / 5)
		var boss_id := ""
		for id in DB.ENEMIES:
			var bd: Dictionary = DB.ENEMIES[id]
			if bd.get("boss", false) and absi(int(bd["lvl"]) - lvl_target) <= 3:
				boss_id = id
		var b: Unit
		if boss_id != "":
			b = Unit.make_enemy(boss_id)
			b.scale_to(lvl_target)
		else:
			var best: String = pool[0]
			for id in pool:
				if int(DB.ENEMIES[id]["lvl"]) > int(DB.ENEMIES[best]["lvl"]):
					best = id
			b = Unit.make_enemy(best)
			b.scale_to(lvl_target + 1)
			b.make_elite()
		out.append(b)
	var counts := {}
	for i in n:
		var id: String = pool[rng.randi() % pool.size()]
		var e := Unit.make_enemy(id)
		e.scale_to(lvl_target)
		out.append(e)
		counts[e.name] = int(counts.get(e.name, 0)) + 1
	var seen := {}
	for e in out:
		Game.seen[e.enemy_id] = true
		if int(counts.get(e.name, 0)) > 1:
			var k: int = seen.get(e.name, 0)
			seen[e.name] = k + 1
			e.name = "%s %s" % [e.name, "ABCDEFGH"[k]]
	return out

func _layout_camera() -> void:
	var vp := get_viewport_rect().size
	var avail := Vector2(vp.x - 300.0, vp.y - 290.0)
	var ps := board.pixel_size()
	var s := clampf(minf(avail.x / ps.x, avail.y / ps.y), 0.55, 1.5)
	board.scale = Vector2(s, s)
	board.position = Vector2(vp.x * 0.46, 70.0 + avail.y * 0.5 + 10.0) - board.center_offset() * s
	cam_home = [board.position, board.scale, board.yaw]

# ---------------------------------------------------------------------------
# UI
# ---------------------------------------------------------------------------
func _build_ui() -> void:
	layer = CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UiKit.theme()
	layer.add_child(root)
	_build_log_ui(root)

	floor_label = UiKit.label("Floor %d" % depth, 20, Color(1, 0.88, 0.5))
	floor_label.position = Vector2(16, 14)
	root.add_child(floor_label)
	var where := ("Inside %s" % world_name) if world_name != "" else "Empty portal"
	var fsub := UiKit.label("%s\nBasic dungeon  -  monster level %d%s" % [where, dungeon_level, "\nBOSS FLOOR" if boss_floor else ""], 14, Color(0.7, 0.75, 0.92))
	fsub.position = Vector2(16, 42)
	root.add_child(fsub)
	var cam_hint := UiKit.label("Camera: left-drag pan  -  right-drag rotate  -  wheel zoom  -  Q / E turn 45 degrees  -  R reset", 12, Color(0.6, 0.64, 0.8))
	cam_hint.set_anchors_preset(Control.PRESET_CENTER_TOP)
	cam_hint.offset_left = -380
	cam_hint.offset_right = 380
	cam_hint.offset_top = 62
	cam_hint.offset_bottom = 80
	cam_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(cam_hint)

	# turn order
	var op := PanelContainer.new()
	op.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	op.offset_left = -200
	op.offset_right = -12
	op.offset_top = 70
	root.add_child(op)
	var ov := VBoxContainer.new()
	ov.add_theme_constant_override("separation", 2)
	op.add_child(ov)
	ov.add_child(UiKit.label("Turn order", 14, Color(1, 0.88, 0.5)))
	order_box = VBoxContainer.new()
	order_box.add_theme_constant_override("separation", 1)
	ov.add_child(order_box)

	var bottom := HBoxContainer.new()
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top = -200
	bottom.offset_bottom = -10
	bottom.offset_left = 10
	bottom.offset_right = -10
	bottom.add_theme_constant_override("separation", 10)
	root.add_child(bottom)
	cmd_panel = PanelContainer.new()
	cmd_panel.custom_minimum_size = Vector2(330, 0)
	bottom.add_child(cmd_panel)
	var cv := VBoxContainer.new()
	cmd_panel.add_child(cv)
	cmd_title = UiKit.label("", 15, Color(1, 0.9, 0.55))
	cv.add_child(cmd_title)
	var cscroll := ScrollContainer.new()
	cscroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	cv.add_child(cscroll)
	cmd_box = VBoxContainer.new()
	cmd_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cscroll.add_child(cmd_box)
	cmd_panel.visible = false

	var party_panel := PanelContainer.new()
	party_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(party_panel)
	var pscroll := ScrollContainer.new()
	pscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	party_panel.add_child(pscroll)
	var pv := VBoxContainer.new()
	pv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pv.add_theme_constant_override("separation", 2 if heroes.size() > 5 else 6)
	pscroll.add_child(pv)
	for u in heroes:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var nm := UiKit.label(u.name, 16)
		nm.custom_minimum_size = Vector2(110, 0)
		row.add_child(nm)
		var hpl := UiKit.label("", 14)
		hpl.custom_minimum_size = Vector2(100, 0)
		row.add_child(hpl)
		var hpb := UiKit.bar(Color(0.3, 0.85, 0.35), 100)
		row.add_child(hpb)
		var mpl := UiKit.label("", 14, Color(0.7, 0.8, 1.0))
		mpl.custom_minimum_size = Vector2(70, 0)
		row.add_child(mpl)
		var info := UiKit.label("", 13, Color(0.7, 0.74, 0.88))
		info.custom_minimum_size = Vector2(130, 0)
		row.add_child(info)
		var ctb := UiKit.bar(Color(1.0, 0.85, 0.25), 100)
		ctb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(ctb)
		pv.add_child(row)
		party_rows.append({"unit": u, "name": nm, "hp": hpl, "hpb": hpb, "mp": mpl, "info": info, "ct": ctb})

	hint_label = UiKit.label("", 14, Color(0.85, 0.88, 1.0))
	hint_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	hint_label.offset_left = 16
	hint_label.offset_top = -232
	hint_label.offset_right = 900
	hint_label.offset_bottom = -208
	root.add_child(hint_label)

func _update_party_ui() -> void:
	for r in party_rows:
		var u: Unit = r["unit"]
		r["hp"].text = "HP %d/%d" % [u.hp, u.max_hp()]
		r["hpb"].max_value = u.max_hp()
		r["hpb"].value = u.hp
		r["mp"].text = "MP %d" % u.mp
		r["info"].text = "Move %d  Jump %d" % [u.move_range(), u.jump_height()]
		r["ct"].value = minf(100.0, u.ct)
		var col := Color(1, 1, 0.6) if u == active else (Color(0.6, 0.6, 0.65) if not u.is_alive() else Color(0.95, 0.96, 1.0))
		r["name"].add_theme_color_override("font_color", col)
		r["hp"].add_theme_color_override("font_color", Color(1, 0.5, 0.45) if u.hp < u.max_hp() * 0.3 else Color(0.95, 0.96, 1.0))

func _update_order() -> void:
	for c in order_box.get_children():
		order_box.remove_child(c)
		c.queue_free()
	var cts := {}
	for u in _alive_all():
		cts[u] = u.ct
	var list: Array = []
	if active != null:
		list.append(active)
	var guard := 0
	while list.size() < 10 and guard < 3000 and not cts.is_empty():
		guard += 1
		var best = null
		for u in cts:
			if cts[u] >= 100.0 and (best == null or cts[u] > cts[best]):
				best = u
		if best != null:
			if best != active or list.size() > 1:
				list.append(best)
			cts[best] = cts[best] - 100.0
			continue
		for u in cts:
			cts[u] = cts[u] + u.speed() * 0.1
	for i in list.size():
		var u2: Unit = list[i]
		var l := UiKit.label(("> " if i == 0 else "   ") + u2.name, 14, Color(1.0, 0.6, 0.55) if u2.is_enemy else Color(0.6, 0.85, 1.0))
		if i == 0:
			l.add_theme_color_override("font_color", Color(1, 1, 0.6))
		order_box.add_child(l)

func _clear_cmds() -> void:
	for c in cmd_box.get_children():
		cmd_box.remove_child(c)
		c.queue_free()

## A list of choices; returns the chosen value (null = back).
func _choose(title: String, opts: Array, allow_back: bool) -> Variant:
	_clear_cmds()
	cmd_title.text = title
	cmd_panel.visible = true
	var first: Button = null
	for o in opts:
		var b := Button.new()
		b.text = o["text"]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.disabled = o.get("disabled", false)
		var val = o["value"]
		var tip = o.get("tip", "")
		b.pressed.connect(func(): picked.emit(val))
		b.focus_entered.connect(func():
			if tip is Array:
				Game.main.tip.show_lines(tip, b.get_global_rect())
			else:
				Game.main.tip.hide_tip()
				if tip != "":
					msg(tip, false))
		b.mouse_entered.connect(func():
			if not b.disabled:
				b.grab_focus()
			elif tip is Array:
				Game.main.tip.show_lines(tip, b.get_global_rect()))
		cmd_box.add_child(b)
		if first == null and not b.disabled:
			first = b
	if allow_back:
		var bb := Button.new()
		bb.text = "< Back"
		bb.alignment = HORIZONTAL_ALIGNMENT_LEFT
		bb.pressed.connect(func(): picked.emit(null))
		bb.focus_entered.connect(func(): Game.main.tip.hide_tip())
		cmd_box.add_child(bb)
		if first == null:
			first = bb
	await get_tree().process_frame
	if first:
		first.grab_focus()
	var v = await picked
	transient = ""
	_refresh_bar()
	Game.main.tip.hide_tip()
	_clear_cmds()
	cmd_panel.visible = false
	return v

## Lets the player click one of the valid cells (null = cancelled).
func _pick_cell(cells: Dictionary, col: Color, hint: String, area: Callable = Callable(), extra: Dictionary = {}) -> Variant:
	board.highlights = {}
	for c in cells:
		board.highlights[c] = col
	for c in extra:
		board.highlights[c] = extra[c]
	valid_cells = cells
	area_fn = area
	selecting = true
	hint_label.text = hint + "     (right-click / Esc to cancel)"
	var v = await picked
	selecting = false
	valid_cells = {}
	area_fn = Callable()
	board.highlights = {}
	board.marks = {}
	hint_label.text = ""
	return v

# ---------------------------------------------------------------------------
# Camera: left-drag (or middle-drag) pans, right-drag rotates to any angle, wheel zooms
# towards the cursor. A click without dragging still selects / cancels. R resets the view.
# ---------------------------------------------------------------------------
const DRAG_START := 6.0
const ZOOM_MIN := 0.45
const ZOOM_MAX := 2.8
var cam_home: Array = []
var press_btn := -1
var press_pos := Vector2.ZERO
var dragged := false

func _unhandled_input(event: InputEvent) -> void:
	if ended:
		return
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
				if not dragged:
					if mb.button_index == MOUSE_BUTTON_LEFT and selecting and valid_cells.has(board.hover):
						picked.emit(board.hover)
					elif mb.button_index == MOUSE_BUTTON_RIGHT and (selecting or _has_back()):
						picked.emit(null)
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
	if event is InputEventKey and event.pressed and not event.echo:
		if deploying and event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
			get_viewport().set_input_as_handled()
			picked.emit("start")
			return
		match event.keycode:
			KEY_R:
				_reset_view()
				return
			KEY_Q:
				_rotate_view(PI / 4.0)
				return
			KEY_E:
				_rotate_view(-PI / 4.0)
				return
	if event.is_action_pressed("ui_cancel") and (selecting or _has_back()):
		get_viewport().set_input_as_handled()
		picked.emit(null)

func _refresh_hover() -> void:
	var c := board.cell_at(board.get_local_mouse_position())
	if c != board.hover:
		board.hover = c
		_update_preview()

func _zoom_at(screen_p: Vector2, f: float) -> void:
	var local := board.get_global_transform().affine_inverse() * screen_p
	var s := clampf(board.scale.x * f, ZOOM_MIN, ZOOM_MAX)
	board.scale = Vector2(s, s)
	board.position = screen_p - local * s
	_refresh_hover()

## Turns the view around the point of the board at the middle of the screen.
func _rotate_view(da: float) -> void:
	var vp := get_viewport_rect().size
	var pivot_screen := Vector2(vp.x * 0.46, (vp.y - 210.0) * 0.5 + 40.0)
	var local := board.get_global_transform().affine_inverse() * pivot_screen
	var hgt := 1.0
	# grid point under the pivot (inverse of the projection at a typical height)
	var q := Vector2((local.x / (Board.TW * 0.5) + (local.y + hgt * Board.HZ) / (Board.TH * 0.5)) * 0.5,
		((local.y + hgt * Board.HZ) / (Board.TH * 0.5) - local.x / (Board.TW * 0.5)) * 0.5)
	var g := q.rotated(-board.yaw) + Vector2((board.w - 1) * 0.5, (board.h - 1) * 0.5)
	board.set_yaw(board.yaw + da)
	var after := board.project(g, hgt)
	board.position = pivot_screen - after * board.scale.x
	_refresh_hover()

func _reset_view() -> void:
	if cam_home.size() == 3:
		board.yaw = cam_home[2]
		board.scale = cam_home[1]
		board.position = cam_home[0]
		_refresh_hover()

func _has_back() -> bool:
	return cmd_panel != null and cmd_panel.visible and cmd_box.get_children().any(func(c): return c is Button and c.text == "< Back")

func _update_preview() -> void:
	board.marks = {}
	if selecting and area_fn.is_valid() and valid_cells.has(board.hover):
		for c in area_fn.call(board.hover):
			board.marks[c] = Color(1.0, 0.85, 0.3)

func _process(delta: float) -> void:
	t += delta
	clock += delta
	for p in popups:
		p["life"] -= delta
		p["oy"] = p["oy"] - 26.0 * delta
	popups = popups.filter(func(p): return p["life"] > 0.0)
	for f in fx:
		f["t"] += delta
	fx = fx.filter(func(f): return f["t"] < f["life"])
	for u in vis:
		vis[u]["flash"] = maxf(0.0, vis[u]["flash"] - delta * 3.0)
		vis[u]["home"] = board.project(vis[u]["g"], vis[u]["gh"])
	if party_rows.size() > 0:
		_update_party_ui()
	_update_unit_tip()
	if log_drop != null and log_drop.visible:
		var vb := log_text.get_v_scroll_bar()
		log_bottom_btn.visible = vb.visible and vb.value < vb.max_value - vb.page - 4.0

# ---------------------------------------------------------------------------
# Drawing (called by the board in painter's order)
# ---------------------------------------------------------------------------
func _face_sign(u: Unit) -> int:
	return 1 if board.screen_dir(Vector2(u.facing)).x > 0.0 else -1

func draw_units_at(ci: CanvasItem, c: Vector2i) -> void:
	for u in heroes + enemies:
		if u.cell != c or not vis.has(u):
			continue
		var v: Dictionary = vis[u]
		var alpha: float = v["alpha"]
		if alpha <= 0.01:
			continue
		if float(v["flash"]) > 0.0 and int(t * 30.0) % 2 == 0:
			alpha *= 0.45
		var pos: Vector2 = v["home"] + v["off"] + Vector2(0, -float(v["hop"]))
		var fs := _face_sign(u)
		if u == active:
			Art.ellipse(ci, pos + Vector2(0, 2), 22, 9, Color(1, 1, 0.5, 0.35 + 0.15 * sin(t * 5.0)))
		if u.is_enemy:
			var d: Dictionary = u.def()
			var sc := _enemy_draw_scale(u)
			Art.enemy(ci, d, pos, sc, fs, alpha, t + pos.x)
			if u.elite and u.is_alive():
				Art.ellipse(ci, pos + Vector2(0, 2), 26, 10, Color(1.0, 0.3, 0.2, 0.25 + 0.1 * sin(t * 3.0)))
		elif u.is_alive():
			var bob := sin(t * 3.0 + pos.y) * 1.0 if u == active else 0.0
			Art.person(ci, pos, 1.25, u.visual_look(), fs, alpha, bob)
		else:
			ci.draw_set_transform(pos + Vector2(-14, -3), -PI / 2, Vector2.ONE)
			Art.person(ci, Vector2.ZERO, 1.1, u.visual_look(), -1, 0.55)
			ci.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
		if u.is_alive():
			var bw := 34.0
			var top_y := -62.0 if not u.is_enemy else -14.0 - _enemy_draw_scale(u) * 30.0
			var bp := pos + Vector2(-bw / 2, top_y)
			ci.draw_rect(Rect2(bp, Vector2(bw, 4)), Color(0, 0, 0, 0.6 * alpha))
			var hc := Color(0.9, 0.25, 0.2, alpha) if u.is_enemy else Color(0.3, 0.85, 0.35, alpha)
			ci.draw_rect(Rect2(bp, Vector2(bw * float(u.hp) / maxf(1.0, u.max_hp()), 4)), hc)
			if u.buffs.size() > 0 or u.poison_left > 0:
				ci.draw_circle(bp + Vector2(bw + 5, 2), 3, Color(0.8, 0.5, 1.0) if u.buffs.any(func(b): return b.get("debuff", false)) or u.poison_left > 0 else Color(1, 0.85, 0.3))
			if u == active:
				var ay := top_y - 14.0 + sin(t * 5.0) * 3.0
				ci.draw_colored_polygon(Art.pts([pos + Vector2(-6, ay), pos + Vector2(6, ay), pos + Vector2(0, ay + 8)]), Color(1, 1, 0.55))

func _enemy_draw_scale(u: Unit) -> float:
	return clampf(float(u.def()["scale"]) * 0.75, 0.9, 2.4) * (1.3 if u.elite else 1.0)

func draw_overlays(ci: CanvasItem) -> void:
	# facing arrow of the active unit (and the hovered unit)
	for u in [active, _unit_on(board.hover)]:
		if u == null or not u.is_alive():
			continue
		var p: Vector2 = vis[u]["home"]
		var dirv := board.screen_dir(Vector2(u.facing))
		var tip := p + dirv * 26.0
		var side := Vector2(-dirv.y, dirv.x) * 6.0
		ci.draw_colored_polygon(Art.pts([tip, p + dirv * 14.0 + side, p + dirv * 14.0 - side]), Color(1, 0.95, 0.5, 0.85))
	for f in fx:
		var k: float = f["t"] / f["life"]
		var fp: Vector2 = board.project(f["g"], f["gh"]) + Vector2(0, f["oy"])
		ci.draw_arc(fp, 10.0 + 30.0 * k, 0, TAU, 24, Color(f["col"], 1.0 - k), 3.0)
		ci.draw_circle(fp, 14.0 * (1.0 - k), Color(f["col"], 0.35 * (1.0 - k)))
	var font := ThemeDB.fallback_font
	for p in popups:
		p["pos"] = board.project(p["g"], p["gh"]) + Vector2(p["dx"], p["oy"])
		var a: float = clampf(p["life"] * 2.0, 0.0, 1.0)
		var fsz := 22 if p["big"] else 16
		ci.draw_string_outline(font, p["pos"] - Vector2(60, 0), p["text"], HORIZONTAL_ALIGNMENT_CENTER, 120, fsz, 4, Color(0, 0, 0, a))
		ci.draw_string(font, p["pos"] - Vector2(60, 0), p["text"], HORIZONTAL_ALIGNMENT_CENTER, 120, fsz, Color(p["col"], a))

# ---------------------------------------------------------------------------
# Board helpers
# ---------------------------------------------------------------------------
func _alive(arr: Array) -> Array:
	return arr.filter(func(x): return x.is_alive())

func _alive_all() -> Array:
	return _alive(heroes) + _alive(enemies)

func _occupied() -> Dictionary:
	var occ := {}
	for u in _alive_all():
		occ[u.cell] = u
	return occ

func _unit_on(c: Vector2i) -> Unit:
	for u in _alive_all():
		if u.cell == c:
			return u
	for u in heroes:
		if u.cell == c:
			return u     # a fallen hero lying there
	return null

func _foes_of(u: Unit) -> Array:
	return enemies if not u.is_enemy else heroes

func _friends_of(u: Unit) -> Array:
	return heroes if not u.is_enemy else enemies

func _dir_to(from: Vector2i, to: Vector2i) -> Vector2i:
	var d := to - from
	if d == Vector2i.ZERO:
		return Vector2i.ZERO
	if absi(d.x) >= absi(d.y):
		return Vector2i(signi(d.x), 0)
	return Vector2i(0, signi(d.y))

func _screen_dir(from: Vector2i, to: Vector2i) -> Vector2:
	return (board.ground_pos(to) - board.ground_pos(from)).normalized()

## Front / side / back, high ground and flanking for an attack on tg from a cell.
func _pos_info(attacker: Unit, from: Vector2i, tg: Unit, is_hit: bool) -> Dictionary:
	var mult := 1.0
	var ev := 1.0
	var parts: Array = []
	var d := Vector2(from - tg.cell)
	if is_hit and d.length() > 0.0:
		var dot := d.normalized().dot(Vector2(tg.facing))
		if dot < -0.5:
			mult += BACK_BONUS
			ev = 0.0
			parts.append("Back")
		elif dot <= 0.5:
			mult += SIDE_BONUS
			ev = 0.5
			parts.append("Side")
	var dh := board.height_at(from) - board.height_at(tg.cell)
	if dh != 0:
		mult += clampf(dh * HEIGHT_STEP, -0.24, 0.24)
		parts.append("High ground" if dh > 0 else "Low ground")
	if is_hit:
		for o in _friends_of(attacker):
			if o != attacker and o.is_alive() and Board.dist(o.cell, tg.cell) == 1:
				mult += FLANK_BONUS
				parts.append("Flank")
				break
	return {"mult": mult, "evade": ev, "label": " + ".join(parts)}

# ---------------------------------------------------------------------------
# Targeting rules
#   modes: unit (one unit in range), area (radius around a tile in range), nova (around yourself),
#          self, tile (empty tile in range: traps)
# ---------------------------------------------------------------------------
func target_spec(u: Unit, aid: String, is_item: bool = false) -> Dictionary:
	if is_item:
		var it: Dictionary = DB.ITEMS[aid]
		match it["target"]:
			"enemies":
				return {"mode": "area", "rmin": 1, "rmax": 4, "radius": 1, "who": "foe"}
			"ally_dead":
				return {"mode": "unit", "rmin": 1, "rmax": 2, "who": "dead"}
		return {"mode": "unit", "rmin": 0, "rmax": 2, "who": "friend"}
	var ab: Dictionary = DB.resolve_ability(aid)
	var tags := DB.tags_for(aid, u)
	var kind: String = ab["kind"]
	if kind == "trap":
		return {"mode": "tile", "rmin": 1, "rmax": 3}
	if kind == "summon":
		return {"mode": "self"}
	match ab["target"]:
		"self":
			return {"mode": "self"}
		"enemy":
			if tags.has("shoot") or (u.is_enemy and aid == "attack" and u.def().has("range")):
				return {"mode": "unit", "rmin": 2, "rmax": int(u.def().get("range", 5)) if u.is_enemy else 5, "who": "foe"}
			if tags.has("melee") or (kind == "phys" and not tags.has("cast")):
				return {"mode": "unit", "rmin": 1, "rmax": 1, "who": "foe", "vert": 3}
			return {"mode": "unit", "rmin": 1, "rmax": 4, "who": "foe"}
		"ally":
			return {"mode": "unit", "rmin": 0, "rmax": 4, "who": "friend"}
		"ally_other":
			return {"mode": "unit", "rmin": 1, "rmax": 1, "who": "friend"}
		"ally_dead":
			return {"mode": "unit", "rmin": 1, "rmax": 3, "who": "dead"}
		"enemies":
			if tags.has("melee"):
				return {"mode": "nova", "radius": 1, "who": "foe"}
			if tags.has("hit"):
				return {"mode": "nova", "radius": 2, "who": "foe"}
			return {"mode": "area", "rmin": 0, "rmax": 4, "radius": 1, "who": "foe"}
		"random3":
			return {"mode": "area", "rmin": 2, "rmax": 5, "radius": 1, "who": "foe", "random": 3}
		"allies":
			return {"mode": "nova", "radius": 2, "who": "friend", "self": true}
	return {"mode": "self"}

func _cells_within(center: Vector2i, rmin: int, rmax: int) -> Array:
	var out: Array = []
	for y in range(center.y - rmax, center.y + rmax + 1):
		for x in range(center.x - rmax, center.x + rmax + 1):
			var c := Vector2i(x, y)
			var dd := Board.dist(c, center)
			if dd >= rmin and dd <= rmax and board.in_bounds(c) and not board.blocked(c):
				out.append(c)
	return out

func _who_ok(u: Unit, spec: Dictionary, x: Unit) -> bool:
	match spec.get("who", "foe"):
		"foe":
			return x.is_alive() and x.is_enemy != u.is_enemy
		"friend":
			return x.is_alive() and x.is_enemy == u.is_enemy
		"dead":
			return not x.is_alive() and not x.is_enemy and x.is_enemy == u.is_enemy
	return false

## Cells the player may click for this spec from a position, and which of them hold valid targets.
func _range_cells(u: Unit, from: Vector2i, spec: Dictionary) -> Array:
	match spec["mode"]:
		"nova":
			return _cells_within(from, 0, int(spec["radius"]))
		"self":
			return [from]
	return _cells_within(from, int(spec.get("rmin", 0)), int(spec.get("rmax", 1)))

func _area_cells(u: Unit, from: Vector2i, spec: Dictionary, cell: Vector2i) -> Array:
	match spec["mode"]:
		"area":
			return _cells_within(cell, 0, int(spec["radius"]))
		"nova":
			return _cells_within(from, 0, int(spec["radius"]))
	return [cell]

func targets_at(u: Unit, from: Vector2i, spec: Dictionary, cell: Vector2i) -> Array:
	var out: Array = []
	match spec["mode"]:
		"self":
			return [u]
		"tile":
			return []
		"unit":
			var x := _unit_on(cell)
			if x != null and _who_ok(u, spec, x):
				if spec.has("vert") and absi(board.height_at(from) - board.height_at(cell)) > int(spec["vert"]):
					return []
				out.append(x)
		_:
			for c in _area_cells(u, from, spec, cell):
				var y := _unit_on(c)
				if y != null and _who_ok(u, spec, y) and (y != u or spec.get("self", false) or spec.get("who", "foe") == "friend"):
					out.append(y)
			if spec.has("random") and out.size() > 0:
				var picks: Array = []
				for i in int(spec["random"]):
					picks.append(out[rng.randi() % out.size()])
				return picks
	return out

# ---------------------------------------------------------------------------
# Deployment: before the fight, arrange the party anywhere in the start area.
# ---------------------------------------------------------------------------
var deploying := false

func _deploy() -> void:
	deploying = true
	var zone := {}
	for c in board.zone_cells("near"):
		zone[c] = true
	var sel: Unit = null
	msg("Position your party in the start area, then start the battle.", false)
	while true:
		# side panel: start button + the party (click a name to pick that unit)
		_clear_cmds()
		cmd_title.text = "Deployment"
		cmd_panel.visible = true
		var sb := Button.new()
		sb.text = "Start battle  (Enter)"
		sb.alignment = HORIZONTAL_ALIGNMENT_LEFT
		sb.pressed.connect(func(): picked.emit("start"))
		cmd_box.add_child(sb)
		for hu in heroes:
			var hb := Button.new()
			hb.text = ("> " if hu == sel else "   ") + "%s  (Lv %d %s)" % [hu.name, hu.level, hu.cls]
			hb.alignment = HORIZONTAL_ALIGNMENT_LEFT
			hb.focus_mode = Control.FOCUS_NONE
			hb.pressed.connect(func(): picked.emit(hu))
			cmd_box.add_child(hb)
		var extra := {}
		if sel != null:
			extra[sel.cell] = Color(1.0, 0.9, 0.35, 0.6)
		var hint := "Click a unit to pick it up." if sel == null else "Click a tile in the start area to move %s there (or another unit to swap places)." % sel.name
		var v = await _pick_cell(zone, Color(0.35, 0.65, 1.0, 0.3), hint, Callable(), extra)
		if v is String and v == "start":
			break
		if v is Unit:
			sel = null if v == sel else v
			continue
		if v == null:
			sel = null
			continue
		var other := _unit_on(v)
		if sel == null:
			sel = other
		elif other == sel:
			sel = null
		elif other != null and not other.is_enemy:
			var c0 := sel.cell
			sel.cell = other.cell
			other.cell = c0
			_snap_vis(sel)
			_snap_vis(other)
			sel = null
		elif other == null:
			sel.cell = v
			_snap_vis(sel)
			sel = null
	_clear_cmds()
	cmd_panel.visible = false
	board.highlights = {}
	deploying = false
	msg("The battle begins!")

func _snap_vis(u: Unit) -> void:
	vis[u]["g"] = Vector2(u.cell)
	vis[u]["gh"] = float(board.height_at(u.cell))
	vis[u]["home"] = board.ground_pos(u.cell)
	vis[u]["flash"] = 0.4

# ---------------------------------------------------------------------------
# Turn loop
# ---------------------------------------------------------------------------
func _run() -> void:
	await get_tree().process_frame
	_update_order()
	await _deploy()
	while not ended:
		var u := _next_actor()
		if u == null:
			break
		await _take_turn(u)
		if ended:
			break
		await _check_end()

func _next_actor() -> Unit:
	for guard in 20000:
		var best: Unit = null
		for u in _alive_all():
			if u.ct >= 100.0 and (best == null or u.ct > best.ct or (u.ct == best.ct and not u.is_enemy)):
				best = u
		if best != null:
			return best
		for u in _alive_all():
			u.ct += u.speed() * 0.1
	return null

func _take_turn(u: Unit) -> void:
	active = u
	turn_moved = false
	turn_acted = false
	ct_after = null
	_update_order()
	for b in u.buffs:
		b["turns"] -= 1
	u.buffs = u.buffs.filter(func(b): return b["turns"] > 0)
	for h in heroes:
		if h.protector == u:
			h.protector = null
	# Regeneration: four ticks at the start of each turn
	var healed := 0
	for i in 4:
		healed += u.regen_tick()
	if healed > 0:
		_popup(u, "+%d" % healed, Color(0.45, 1.0, 0.6), false, "%s regenerates %d HP" % [u.name, healed])
	var poisoned := u.tick_dots()
	if poisoned > 0:
		note("%s takes %d Poison damage" % [u.name, poisoned], false)
		_popup(u, "-%d poison" % poisoned, Color(0.6, 0.95, 0.3), false, false)
		if not u.is_alive():
			_hurt(u, 0, false, "phys", false)
			_popup(u, "Succumbed to poison", Color(0.6, 0.95, 0.3), false, "%s succumbs to Poison!" % u.name)
			_end_turn(u)
			return
	var dot := 0
	for b in u.buffs:
		dot += int(b.get("dot", 0))
	if dot > 0:
		note("%s steps on caltrops" % u.name, false)
		_hurt(u, dot, false, "phys")
		if not u.is_alive():
			_end_turn(u)
			return
	if u.buffs.any(func(b): return b.get("stun", false)):
		u.buffs = u.buffs.filter(func(b): return not b.get("stun", false))
		msg("%s is stunned and can't act!" % u.name)
		_popup(u, "Stunned", Color(1.0, 0.85, 0.4))
		await get_tree().create_timer(0.7).timeout
		turn_moved = true
		turn_acted = true
		_end_turn(u)
		return
	if u.is_enemy:
		await _enemy_turn(u)
	else:
		await _hero_turn(u)
	_end_turn(u)

func _end_turn(u: Unit) -> void:
	var keep := (20.0 if not turn_moved else 0.0) + (20.0 if not turn_acted else 0.0)
	u.ct = maxf(0.0, u.ct - 100.0) + keep
	if ct_after != null:
		u.ct = float(ct_after) + keep
	active = null

func _check_end() -> void:
	if ended:
		return
	if _alive(enemies).is_empty():
		ended = true
		await _victory()
	elif _alive(heroes).is_empty():
		ended = true
		msg("Your party has fallen...")
		await get_tree().create_timer(1.6).timeout
		finished.emit("defeat")

# ---------------------------------------------------------------------------
# Hero turn: Move / Act / Wait
# ---------------------------------------------------------------------------
func _hero_turn(u: Unit) -> void:
	msg("%s's turn" % u.name)
	while not ended and u.is_alive() and not (turn_moved and turn_acted):
		var opts := [
			{"text": "Move", "value": "move", "disabled": turn_moved, "tip": "Move up to %d tiles (climb or drop %d)" % [u.move_range(), u.jump_height()]},
			{"text": "Act", "value": "act", "disabled": turn_acted, "tip": "Attack, use a skill or an item"},
			{"text": "Wait", "value": "wait", "tip": "End the turn and choose which way to face"},
		]
		var cmd = await _choose(u.name, opts, false)
		match cmd:
			"move":
				if await _do_move(u):
					turn_moved = true
			"act":
				if await _do_act(u):
					turn_acted = true
				await _check_end()
			"wait":
				break
	if u.is_alive() and not ended:
		await _choose_facing(u)

func _do_move(u: Unit) -> bool:
	var reach := board.reachable(u, _occupied())
	var cells := {}
	for c in reach:
		if c is Vector2i and c != u.cell:
			cells[c] = true
	if cells.is_empty():
		msg("%s can't move anywhere." % u.name, false)
		return false
	var path_preview := func(c: Vector2i) -> Array: return board.path_to(reach, c, u.cell)
	var dest = await _pick_cell(cells, Color(0.3, 0.6, 1.0, 0.45), "Click a blue tile to move there.", path_preview)
	if dest == null:
		return false
	await _walk(u, board.path_to(reach, dest, u.cell))
	return true

func _walk(u: Unit, path: Array) -> void:
	for i in range(1, path.size()):
		var a: Vector2i = path[i - 1]
		var b: Vector2i = path[i]
		u.facing = _dir_to(a, b)
		var ga := Vector2(a)
		var gb := Vector2(b)
		var ha := float(board.height_at(a))
		var hb := float(board.height_at(b))
		var lift := maxf(0.0, (hb - ha) * Board.HZ) + 8.0
		if board.depth_of(gb) > board.depth_of(ga):
			u.cell = b
		var tw := create_tween()
		tw.tween_method(func(k: float):
			vis[u]["g"] = ga.lerp(gb, k)
			vis[u]["gh"] = lerpf(ha, hb, k)
			vis[u]["hop"] = sin(k * PI) * lift, 0.0, 1.0, 0.16)
		await tw.finished
		u.cell = b
		vis[u]["g"] = gb
		vis[u]["gh"] = hb
		vis[u]["hop"] = 0.0
		# a trap set by the other side springs
		if board.traps.has(b) and board.traps[b]["owner"].is_enemy != u.is_enemy:
			var trap: Dictionary = board.traps[b]
			board.traps.erase(b)
			msg("%s springs a trap!" % u.name)
			_hurt(u, int(trap["dmg"]), false, "phys")
			u.ct = maxf(0.0, u.ct - 50.0)
			await get_tree().create_timer(0.4).timeout
			break

func _choose_facing(u: Unit) -> void:
	var cells := {}
	for y in board.h:
		for x in board.w:
			var c := Vector2i(x, y)
			if c != u.cell:
				cells[c] = true
	var near := {}
	for d in Board.DIRS:
		if board.in_bounds(u.cell + d):
			near[u.cell + d] = Color(1.0, 0.85, 0.3, 0.55)
	var face_area := func(c: Vector2i) -> Array: return [u.cell + _dir_to(u.cell, c)]
	board.highlights = near
	var c2 = await _pick_cell(cells, Color(0, 0, 0, 0), "Choose a facing: click any tile in that direction (Esc keeps the current facing).", face_area, near)
	if c2 != null:
		var d2 := _dir_to(u.cell, c2)
		if d2 != Vector2i.ZERO:
			u.facing = d2

func _do_act(u: Unit) -> bool:
	while true:
		var has_skills := u.abilities().size() > 1
		var cmd = await _choose(u.name + " - Act", [
			{"text": "Attack", "value": "attack", "tip": DB.ability_lines("attack", u)},
			{"text": "Skills", "value": "skill", "disabled": not has_skills, "tip": "Use a skill or spell"},
			{"text": "Items", "value": "item", "disabled": not Game.has_any_items(), "tip": "Use an item from the bag"},
		], true)
		if cmd == null:
			return false
		match cmd:
			"attack":
				if await _target_and_perform(u, "attack", false):
					return true
			"skill":
				var opts: Array = []
				for a0 in u.abilities():
					if a0 == "attack":
						continue
					for a in ([a0, a0 + "#all"] if u.masteries.has(a0) else [a0]):
						var ab: Dictionary = DB.resolve_ability(a)
						var prob := DB.ability_problem(a, u)
						var label := "%s   %d MP" % [ab["name"], ab["mp"]]
						if prob in ["needs bow", "needs shield", "needs fists", "silenced"]:
							label += "   (%s)" % prob
						opts.append({"text": label, "value": a, "disabled": prob != "", "tip": DB.ability_lines(a, u)})
				var aid = await _choose("Skills  (MP %d/%d)" % [u.mp, u.max_mp()], opts, true)
				if aid != null and await _target_and_perform(u, aid, false):
					return true
			"item":
				var iopts: Array = []
				for iid in Game.inventory:
					var it: Dictionary = DB.ITEMS[iid]
					iopts.append({"text": "%s  x%d" % [it["name"], Game.item_count(iid)], "value": iid, "tip": [[it["name"], Color(1, 0.9, 0.55), false], it["desc"]]})
				var iid2 = await _choose("Items", iopts, true)
				if iid2 != null and await _target_and_perform(u, iid2, true):
					return true
	return false

func _target_and_perform(u: Unit, aid: String, is_item: bool) -> bool:
	var spec := target_spec(u, aid, is_item)
	if spec["mode"] == "self":
		if is_item:
			await _use_item(u, aid, [u])
		else:
			await _perform(u, aid, [u], u.cell)
		return true
	var cells := {}
	var good := {}
	for c in _range_cells(u, u.cell, spec):
		if spec["mode"] == "tile":
			if _unit_on(c) == null and not board.traps.has(c):
				cells[c] = true
		elif spec["mode"] == "unit":
			if not targets_at(u, u.cell, spec, c).is_empty():
				cells[c] = true
			else:
				good[c] = Color(1.0, 0.4, 0.35, 0.18)
		else:
			cells[c] = true
	if cells.is_empty():
		msg("No targets in range.", false)
		return false
	var col := Color(1.0, 0.35, 0.3, 0.5) if spec.get("who", "foe") == "foe" else Color(0.4, 1.0, 0.5, 0.45)
	target_ctx = {"u": u, "aid": aid, "item": is_item, "spec": spec}
	var area := func(c: Vector2i) -> Array: return _area_cells(u, u.cell, spec, c)
	var name_s: String = DB.ITEMS[aid]["name"] if is_item else DB.resolve_ability(aid)["name"]
	var cell = await _pick_cell(cells, col, "%s: choose a target." % name_s, area, good)
	target_ctx = {}
	if cell == null:
		return false
	var tg := targets_at(u, u.cell, spec, cell)
	if tg.is_empty() and spec["mode"] != "tile":
		msg("Nobody there to target.", false)
		return false
	if cell != u.cell:
		u.facing = _dir_to(u.cell, cell)
	if is_item:
		await _use_item(u, aid, tg)
	else:
		await _perform(u, aid, tg, cell)
	return true

# ---------------------------------------------------------------------------
# Enemy turn: a simple tactician. Tries every reachable tile with every skill, scores the results
# (damage, kills, attacking from behind, high ground), otherwise closes in.
# ---------------------------------------------------------------------------
func _enemy_turn(u: Unit) -> void:
	var reach := board.reachable(u, _occupied())
	var cells: Array = []
	for c in reach:
		if c is Vector2i:
			cells.append(c)
	if u.buffs.any(func(b): return b.get("ensnare", false)):
		cells = [u.cell]
	var silenced := u.buffs.any(func(b): return b.get("silence", false))
	var ensnared := u.buffs.any(func(b): return b.get("ensnare", false))
	var abil: Array = []
	for a in u.def()["abilities"]:
		if abil.has(a) or int(DB.ABILITIES[a]["mp"]) > u.mp:
			continue
		var tags: Array = DB.ABILITIES[a].get("tags", [])
		if silenced and tags.has("cast"):
			continue
		if ensnared and tags.has("melee"):
			continue
		abil.append(a)
	var best := {"score": 0.0}
	for a in abil:
		var ab: Dictionary = DB.ABILITIES[a]
		if ab["kind"] == "summon":
			if _alive(enemies).size() < summon_cap(ab) and rng.randf() < 0.6:
				var s0 := 25.0 + rng.randf() * 20.0
				if s0 > best["score"]:
					best = {"score": s0, "cell": u.cell, "aid": a, "targets": [u], "tcell": u.cell}
			continue
		if ab["kind"] == "buff":
			if u.buffs.is_empty() and rng.randf() < 0.5:
				var tb := targets_at(u, u.cell, target_spec(u, a), u.cell)
				if ab["target"] == "self":
					tb = [u]
				var s1 := 8.0 + 4.0 * tb.size()
				if s1 > best["score"]:
					best = {"score": s1, "cell": u.cell, "aid": a, "targets": tb, "tcell": u.cell}
			continue
		var spec := target_spec(u, a)
		for c in cells:
			var opts: Array = []
			match spec["mode"]:
				"unit":
					for tg in _foes_of(u) if spec["who"] == "foe" else _friends_of(u):
						if _who_ok(u, spec, tg) and Board.dist(c, tg.cell) >= int(spec["rmin"]) and Board.dist(c, tg.cell) <= int(spec["rmax"]):
							opts.append(tg.cell)
				"area":
					for tg in _foes_of(u):
						if tg.is_alive() and Board.dist(c, tg.cell) <= int(spec["rmax"]) and Board.dist(c, tg.cell) >= int(spec.get("rmin", 0)):
							opts.append(tg.cell)
				"nova":
					opts.append(c)
				"self":
					opts.append(c)
			for tc in opts:
				var tgs := targets_at(u, c, spec, tc)
				if spec.get("who", "foe") == "foe":
					tgs = tgs.filter(func(x): return not x.buffs.any(func(b): return b.get("hidden", false))) if spec["mode"] == "unit" else tgs
				if tgs.is_empty():
					continue
				var s := 0.0
				for tg in tgs:
					s += _score_hit(u, a, ab, tg, c)
				if spec.get("rmin", 1) >= 2:
					for f in _alive(heroes):
						if Board.dist(c, f.cell) <= 1:
							s -= 8.0
				s += rng.randf() * 3.0
				if s > best["score"]:
					best = {"score": s, "cell": c, "aid": a, "targets": tgs, "tcell": tc}
	if best["score"] > 0.0:
		if best["cell"] != u.cell:
			await _walk(u, board.path_to(reach, best["cell"], u.cell))
			turn_moved = true
			if not u.is_alive():
				return
		if best["tcell"] != u.cell:
			u.facing = _dir_to(u.cell, best["tcell"])
		vis[u]["flash"] = 0.5
		await get_tree().create_timer(0.25).timeout
		var ab2: Dictionary = DB.ABILITIES[best["aid"]]
		if ab2["kind"] == "summon":
			await _summon(u, ab2)
		else:
			var tg2: Array = best["targets"]
			# Protect: single attacks on a protected hero hit the protector instead
			if target_spec(u, best["aid"])["mode"] == "unit" and tg2.size() == 1 and not tg2[0].is_enemy:
				var pr = tg2[0].protector
				if pr != null and pr.is_alive() and pr != tg2[0]:
					msg("%s steps in front of %s!" % [pr.name, tg2[0].name])
					tg2 = [pr]
			await _perform(u, best["aid"], tg2, best["tcell"])
		turn_acted = true
		return
	# nothing in reach: close in on the nearest hero
	if not turn_moved and cells.size() > 1:
		var goals: Array = []
		for h in _alive(heroes):
			for d in Board.DIRS:
				goals.append(h.cell + d)
		var df := board.dist_field(goals, u.jump_height() if not u.flies() else 9)
		var bc: Vector2i = u.cell
		var bd := int(df.get(u.cell, 999))
		for c in cells:
			var dd := int(df.get(c, 999))
			if dd < bd:
				bd = dd
				bc = c
		if bc != u.cell:
			await _walk(u, board.path_to(reach, bc, u.cell))
			turn_moved = true
	var near_h: Unit = null
	for h in _alive(heroes):
		if near_h == null or Board.dist(u.cell, h.cell) < Board.dist(u.cell, near_h.cell):
			near_h = h
	if near_h != null:
		u.facing = _dir_to(u.cell, near_h.cell)

func _score_hit(u: Unit, aid: String, ab: Dictionary, tg: Unit, from: Vector2i) -> float:
	match ab["kind"]:
		"phys", "magic":
			var tags := DB.tags_for(aid, u)
			var pi := _pos_info(u, from, tg, tags.has("hit"))
			var ab2 := ab.duplicate()
			ab2["pos_mult"] = pi["mult"]
			ab2["evade_mult"] = pi["evade"]
			var e := Combat.expected_damage(u, tg, ab2, tags) * Combat.hit_chance(u, tg, ab2)
			if e >= tg.hp:
				e += 40.0
			return e + 5.0
		"debuff":
			return 0.0 if tg.buffs.any(func(b): return b.get("name", "") == ab.get("buff_name", ab["name"])) else 14.0
		"poison_cloud":
			return 10.0
		"heal":
			return float(tg.max_hp() - tg.hp) * 0.5 if tg.is_enemy == u.is_enemy else 0.0
	return 0.0

## Monsters summon up to their own fixed limit.
func summon_cap(ab: Dictionary) -> int:
	return int(ab.get("max_enemies", 4))

func _summon(u: Unit, ab: Dictionary) -> void:
	msg("%s uses %s!" % [u.name, ab["name"]])
	vis[u]["flash"] = 0.8
	await get_tree().create_timer(0.4).timeout
	var cnt := randi_range(int(ab["count"][0]), int(ab["count"][1]))
	var occ := _occupied()
	for i in cnt:
		if _alive(enemies).size() >= summon_cap(ab):
			break
		var spot = null
		for c in _cells_within(u.cell, 1, 2):
			if not occ.has(c):
				spot = c
				break
		if spot == null:
			break
		var e2 := Unit.make_enemy(ab["summon"])
		e2.scale_to(dungeon_level)
		e2.summoned = true
		summon_count += 1
		e2.name = "%s %d" % [e2.name, summon_count]
		e2.cell = spot
		e2.facing = u.facing
		e2.ct = randf_range(0.0, 30.0)
		occ[spot] = e2
		enemies.append(e2)
		_add_vis(e2)
		vis[e2]["flash"] = 1.0
		_spawn_fx(e2, Color(0.6, 0.3, 0.3))
		_popup(e2, "Summoned!", Color(1.0, 0.6, 0.5))
	await get_tree().create_timer(0.5).timeout

# ---------------------------------------------------------------------------
# Actions
# ---------------------------------------------------------------------------
func _lunge(u: Unit, toward: Vector2i) -> void:
	var dir := _screen_dir(u.cell, toward) if toward != u.cell else Vector2.ZERO
	var tw := create_tween()
	tw.tween_method(func(v): vis[u]["off"] = v, Vector2.ZERO, dir * 18.0, 0.1)
	tw.tween_method(func(v): vis[u]["off"] = v, dir * 18.0, Vector2.ZERO, 0.14)
	await get_tree().create_timer(0.12).timeout

func _spawn_fx(u: Unit, col: Color) -> void:
	fx.append({"g": vis[u]["g"], "gh": vis[u]["gh"], "oy": -24.0, "t": 0.0, "col": col, "life": 0.5})

func _cast(u: Unit, ab: Dictionary) -> void:
	var col := _el_color(ab.get("element", ""))
	if ab.get("kind", "") in ["heal", "hot"]:
		col = Color(0.5, 1.0, 0.6)
	elif ab.get("kind", "") == "buff":
		col = Color(1.0, 0.85, 0.4)
	_spawn_fx(u, col)
	await get_tree().create_timer(0.3).timeout

func _perform(u: Unit, aid: String, targets: Array, tcell: Vector2i = Vector2i(-1, -1)) -> void:
	var ab: Dictionary = DB.resolve_ability(aid).duplicate()
	ab["id"] = DB.base_id(aid)
	u.mp -= int(ab["mp"])
	var on := ""
	if targets.size() == 1 and targets[0] != u and ab["target"] != "random3":
		on = " on %s" % targets[0].name
	if aid != "attack":
		msg("%s uses %s%s!" % [u.name, ab["name"], on])
	elif on != "":
		msg("%s attacks %s!" % [u.name, targets[0].name])
	else:
		msg("%s attacks!" % u.name)
	var kind: String = ab["kind"]
	if tcell == Vector2i(-1, -1):
		tcell = targets[0].cell if targets.size() > 0 else u.cell
	if kind == "phys":
		await _lunge(u, tcell)
	else:
		await _cast(u, ab)
	var tags := DB.tags_for(aid, u)
	var sid: String = ab["id"]
	var power := 1.0 + u.mod("sk_%s_pow" % sid)
	var extra_turns := int(u.mod("sk_%s_turns" % sid))
	var int_scale := 1.0 + u.stat("int") * 0.02
	for tg in targets:
		if not tg.is_alive():
			continue
		match kind:
			"phys", "magic":
				var strikes := int(ab.get("strikes", 1))
				for si in strikes:
					if not tg.is_alive():
						break
					if si > 0:
						await get_tree().create_timer(0.12).timeout
						await _lunge(u, tg.cell)
					_strike(u, tg, ab, tags, false)
				# Off-hand strike when dual wielding a basic attack
				if aid == "attack" and u.dual_wielding() and tg.is_alive():
					await get_tree().create_timer(0.15).timeout
					await _lunge(u, tg.cell)
					_strike(u, tg, ab, tags, true)
				# Twin Dragon Style: the basic Attack lands twice with fists
				if aid == "attack" and u.fists() and u.mod("attack_twice") > 0.0 and tg.is_alive():
					await get_tree().create_timer(0.12).timeout
					await _lunge(u, tg.cell)
					_strike(u, tg, ab, tags, false)
				# Chance to hit twice with melee
				var dh := u.mod("double_hit") + (u.mod("fist_double") if u.fists() else 0.0)
				if tags.has("melee") and tags.has("hit") and tg.is_alive() and randf() < dh:
					await get_tree().create_timer(0.15).timeout
					_popup(u, "Double Hit!", Color(1.0, 0.8, 0.35))
					await _lunge(u, tg.cell)
					_strike(u, tg, ab, tags, false)
			"heal":
				var amt: int = Combat.heal_amount(u, ab)
				var before: int = tg.hp
				tg.hp = mini(tg.max_hp(), tg.hp + amt)
				_popup(tg, "+%d" % (tg.hp - before), Color(0.45, 1.0, 0.5))
				_spawn_fx(tg, Color(0.5, 1.0, 0.6))
			"buff":
				_apply_buff(u, tg, ab, power, extra_turns)
				_spawn_fx(tg, Color(1.0, 0.85, 0.4))
			"shield":
				var amt2 := Combat.shield_amount(u, ab)
				tg.buffs.append({"mods": {"def": float(amt2)}, "turns": int(ab.get("turns", 3)) + 1, "name": "Shield"})
				_popup(tg, "+%d Armour" % amt2, Color(0.7, 0.85, 1.0))
				_spawn_fx(tg, Color(0.7, 0.85, 1.0))
			"ward":
				var wamt := int(round((u.stat("int") * 2.0 + u.level * 3.0 + 10.0) * power * (1.0 + u.mod("heal_pow"))))
				tg.buffs = tg.buffs.filter(func(b): return not b.has("ward"))
				tg.buffs.append({"name": "Ward", "mods": {}, "turns": int(ab.get("turns", 3)) + 1 + extra_turns, "ward": wamt})
				_popup(tg, "Ward %d" % wamt, Color(0.75, 0.88, 1.0), false, "%s gains a Ward of %d" % [tg.name, wamt])
				_spawn_fx(tg, Color(0.75, 0.88, 1.0))
			"hot":
				var hamt := maxi(1, int(round((u.stat("int") * 0.15 + u.level * 0.25 + 1.0) * power * (1.0 + u.mod("heal_pow")))))
				var rounds := float(ab.get("rounds", 4)) + extra_turns
				tg.add_regen(hamt, rounds)
				_popup(tg, "Regeneration +%d" % hamt, Color(0.45, 1.0, 0.6), false, "%s gains {regen:%d:%s}" % [tg.name, hamt, str(int(rounds))])
				_spawn_fx(tg, Color(0.5, 1.0, 0.6))
			"imbue":
				var el: String = ab["element"]
				var bs: Array = ab["base"]
				var lo := (float(bs[0]) + u.level * 0.5) * int_scale * power
				var hi := (float(bs[1]) + u.level * 0.5) * int_scale * power
				tg.buffs = tg.buffs.filter(func(b): return not b.has("imbue"))
				tg.buffs.append({"name": ab["name"], "mods": {"add_%s_min" % el: lo, "add_%s_max" % el: hi},
					"turns": int(ab.get("turns", 3)) + 1 + extra_turns, "imbue": el})
				_popup(tg, ab["name"] + "!", _el_color(el), false, "%s's Hits add %d-%d %s damage" % [tg.name, int(lo), int(round(hi)), el.capitalize()])
				_spawn_fx(tg, _el_color(el))
			"meditate":
				var mpg := mini(maxi(0, tg.max_mp() - tg.mp), int(round(u.stat("int") + u.level * 2.0 + 5.0)))
				tg.mp += mpg
				var mr := maxi(1, int(round(u.stat("con") * 0.2 + u.level * 0.3 + 1.0)))
				tg.add_regen(mr, 2.0)
				_popup(tg, "+%d MP" % mpg, Color(0.5, 0.75, 1.0), false, "%s restores %d MP and gains {regen:%d:2}" % [tg.name, mpg, mr])
				_spawn_fx(tg, Color(0.6, 0.8, 1.0))
			"cure":
				var n: int = tg.cleanse()
				_popup(tg, "Cured!" if n > 0 else "Clean", Color(0.6, 1.0, 0.7))
				_spawn_fx(tg, Color(0.6, 1.0, 0.7))
			"protect":
				tg.protector = u
				var arm: float = u.base_armour() * (0.5 + u.mod("shield_share"))
				u.buffs.append({"mods": {"def": arm, "fire_res": 0.1, "ice_res": 0.1, "lightning_res": 0.1, "magic_res": 0.1}, "turns": 1, "name": "Protecting"})
				_popup(u, "Protecting %s (+%d Armour)" % [tg.name, int(arm)], Color(0.7, 0.85, 1.0))
				_spawn_fx(tg, Color(0.7, 0.85, 1.0))
			"debuff":
				_apply_debuff(u, tg, ab, power, extra_turns)
				_spawn_fx(tg, Color(0.6, 0.4, 0.9))
			"poison_cloud":
				var pa: int = tg.poison(int(ab.get("amount", 10)))
				_popup(tg, "Poison %d" % pa if pa > 0 else "Resisted", Color(0.6, 0.95, 0.3))
				_spawn_fx(tg, Color(0.55, 0.8, 0.3))
			"trap":
				pass
		if targets.size() > 1:
			await get_tree().create_timer(0.12).timeout
	# Hunter's Trap: set on the chosen tile
	if kind == "trap":
		var mine := board.traps.keys().filter(func(c): return board.traps[c]["owner"] == u)
		if mine.size() >= 3:
			board.traps.erase(mine[0])
		board.traps[tcell] = {"dmg": Combat.trap_damage(u), "owner": u}
		note("%s sets a trap" % u.name)
	# War Cry: knock back every opponent's time bar
	if ab.has("enemy_atb"):
		for e in _alive(enemies if not u.is_enemy else heroes):
			e.ct = maxf(0.0, e.ct + float(ab["enemy_atb"]))
	# Empowered / Shadow Strike are spent by the Hit they boosted
	if kind == "phys" and tags.has("hit"):
		u.buffs = u.buffs.filter(func(b): return not b.get("consume_on_hit", false))
	if ab.has("atb_after"):
		ct_after = float(ab["atb_after"])
	await get_tree().create_timer(0.45).timeout

func _el_color(el: String) -> Color:
	match el:
		"fire":
			return Color(1.0, 0.55, 0.25)
		"ice":
			return Color(0.6, 0.88, 1.0)
		"lightning":
			return Color(1.0, 0.95, 0.4)
	return Color(1.0, 0.85, 0.4)


## A buff skill on one target (a fresh cast replaces the same buff instead of stacking).
func _apply_buff(u: Unit, tg: Unit, ab: Dictionary, power: float, extra_turns: int) -> void:
	if ab.has("buff_list"):
		for bd in ab["buff_list"]:
			var b0: Dictionary = bd.duplicate(true)
			tg.buffs = tg.buffs.filter(func(x): return x.get("name", "") != b0["name"])
			tg.buffs.append(b0)
		_popup(tg, ab["name"] + "!", Color(1.0, 0.85, 0.4))
		return
	var mods := {}
	for k in ab.get("buff", {}):
		mods[k] = float(ab["buff"][k]) * power
	var nm: String = ab.get("buff_name", ab["name"])
	var turns: int = int(ab["raw_turns"]) if ab.has("raw_turns") else int(ab.get("turns", 3)) + 1 + extra_turns
	var b := {"name": nm, "mods": mods, "turns": turns}
	var flags: Dictionary = ab.get("flags", {})
	for k in flags:
		b[k] = flags[k]
	if flags.has("envenom"):
		b["envenom"] = maxi(1, int(round(Combat.poison_amount(u, flags["envenom"]) * (1.0 + u.mod("sk_envenom_poison")))))
	tg.buffs = tg.buffs.filter(func(x): return x.get("name", "") != nm)
	tg.buffs.append(b)
	_popup(tg, nm + "!", Color(1.0, 0.85, 0.4))

func _apply_debuff(u: Unit, tg: Unit, ab: Dictionary, power: float, extra_turns: int) -> void:
	var mods := {}
	for k in ab.get("debuff", {}):
		mods[k] = float(ab["debuff"][k]) * power
	var nm: String = ab.get("buff_name", ab["name"])
	var b := {"name": nm, "mods": mods, "turns": int(ab.get("turns", 3)) + 1 + extra_turns, "debuff": true}
	if ab.has("dot"):
		var dd: Dictionary = ab["dot"]
		b["dot"] = maxi(1, int(round((u.stat(dd.get("stat", "dex")) * float(dd.get("mult", 0.3)) + u.level * float(dd.get("lvl", 1.0)) + float(dd.get("base", 2.0))) * power)))
	tg.buffs = tg.buffs.filter(func(x): return x.get("name", "") != nm)
	tg.buffs.append(b)
	_popup(tg, nm + "!", Color(0.8, 0.5, 1.0))


func _strike(u: Unit, tg: Unit, ab: Dictionary, tags: Array, off: bool, counter: bool = false) -> void:
	var sid: String = ab.get("id", "")
	var use := ab
	# Execute: double damage on a badly wounded target
	if ab.has("execute") and tg.hp < tg.max_hp() * float(ab["execute"]):
		use = use.duplicate()
		use["mult"] = float(use.get("mult", 1.0)) * 2.0
	# Backstab: easier crits on a weakened target
	if ab.has("crit_vs_weak") and (tg.poison_left > 0 or tg.buffs.any(func(b): return b.get("debuff", false))):
		use = use.duplicate()
		use["crit_bonus"] = float(use.get("crit_bonus", 0.0)) + float(ab["crit_vs_weak"])
	# position on the board: facing, height and flanking
	var pi := _pos_info(u, u.cell, tg, tags.has("hit"))
	use = use.duplicate()
	use["pos_mult"] = float(pi["mult"]) if tags.has("hit") or ab["kind"] == "magic" else 1.0
	use["evade_mult"] = pi["evade"]
	if pi["label"].contains("Back") and ab.has("crit_vs_weak"):
		use["crit_bonus"] = float(use.get("crit_bonus", 0.0)) + float(ab["crit_vs_weak"])
	var r: Dictionary = Combat.damage(u, tg, use, tags, off)
	if not r["miss"] and pi["label"] != "" and pi["label"] != "Front":
		_popup(tg, pi["label"], Color(1.0, 0.8, 0.45), false, false)
	if r["miss"]:
		_popup(tg, "Miss", Color(0.8, 0.8, 0.9), false, "%s misses %s" % [u.name, tg.name])
		# Riposte: a dodged Hit is answered at once
		if not counter and tags.has("hit") and tg.is_alive() and u.is_alive() and Board.dist(u.cell, tg.cell) == 1 and tg.buffs.any(func(b): return b.get("riposte", false)):
			_popup(tg, "Counter!", Color(1.0, 0.85, 0.4), false, "%s Counters!" % tg.name)
			var atk: Dictionary = DB.ABILITIES["attack"].duplicate()
			atk["id"] = "attack"
			_strike(tg, u, atk, DB.tags_for("attack", tg), false, true)
		return
	_hurt(tg, r["dmg"], r["crit"], r["element"], true, pi["label"] if tags.has("hit") else "")
	if ab.has("drain") and u.is_alive():
		var heal := int(r["dmg"] * float(ab["drain"]))
		u.hp = mini(u.max_hp(), u.hp + heal)
		_popup(u, "+%d" % heal, Color(0.45, 1.0, 0.5), false, "%s drains %d HP" % [u.name, heal])
	if ab.has("atb_hit") and tg.is_alive():
		tg.ct = maxf(0.0, tg.ct + float(ab["atb_hit"]))
	# Eviscerate: cash in the whole Poison pool at once
	if ab.has("eviscerate") and tg.is_alive() and tg.poison_left > 0:
		var total := 0
		var v := tg.poison_left
		while v > 0:
			total += v
			v /= 2
		tg.poison_left = 0
		var edmg := int(round(total * float(ab["eviscerate"])))
		_hurt(tg, edmg, false, "poison")
	var pois := 0
	if ab.has("poison") and tg.is_alive():
		pois += int(round(Combat.poison_amount(u, ab["poison"]) * (1.0 + u.mod("sk_%s_poison" % sid))))
	# Envenom: the next few Hits carry Poison
	if tags.has("hit") and tg.is_alive():
		var spent := false
		for b in u.buffs:
			if b.has("envenom") and int(b.get("charges", 0)) > 0:
				pois += int(b["envenom"])
				b["charges"] = int(b["charges"]) - 1
				spent = true
		if spent:
			u.buffs = u.buffs.filter(func(b): return not b.has("charges") or int(b["charges"]) > 0)
	if tags.has("hit") and tags.has("melee") and tg.is_alive() and randf() < u.mod("ensnare_chance"):
		tg.buffs = tg.buffs.filter(func(b): return not b.get("ensnare", false))
		tg.buffs.append({"name": "Ensnared", "mods": {"speed": -0.5}, "turns": 2, "debuff": true, "ensnare": true})
		_popup(tg, "Ensnared!", Color(0.5, 0.85, 0.35))
	if tags.has("hit") and u.mod("poison_on_hit") > 0.0 and tg.is_alive():
		pois += int(u.mod("poison_on_hit"))
	if pois > 0:
		var applied := tg.poison(pois)
		if applied > 0:
			_popup(tg, "Poison %d" % applied, Color(0.6, 0.95, 0.3), false, "%s: Poison +%d (now %d)" % [tg.name, applied, tg.poison_left])
	var stunned: bool = ab.get("stun", false)
	if ab.has("stun_chance") and randf() < float(ab["stun_chance"]) + u.mod("sk_%s_stun" % sid):
		stunned = true
	if stunned and tg.is_alive():
		tg.buffs = tg.buffs.filter(func(b): return not b.get("stun", false))
		tg.buffs.append({"name": "Stunned", "mods": {}, "turns": 2, "debuff": true, "stun": true})
		tg.ct = 0.0
		_popup(tg, "Grabbed!" if ab.get("stun", false) else "Stunned!", Color(1.0, 0.85, 0.4))
	if ab.has("on_hit_debuff") and tg.is_alive():
		var dbf: Dictionary = ab["on_hit_debuff"]
		var nb := {"mods": dbf["mods"].duplicate(), "turns": int(dbf["turns"]) + 1 + int(u.mod("sk_%s_turns" % sid)), "name": dbf["name"], "debuff": true}
		for k in dbf:
			if not nb.has(k):
				nb[k] = dbf[k]
		tg.buffs = tg.buffs.filter(func(b): return b.get("name", "") != dbf["name"])
		tg.buffs.append(nb)
		_popup(tg, dbf["name"] + "!", Color(0.8, 0.5, 1.0))
	# Mug: pick the target's pocket (once per enemy)
	if ab.get("mug", false) and tg.is_enemy and not tg.has_meta("mugged"):
		tg.set_meta("mugged", true)
		if randf() < 0.5:
			var g := int(round((float(tg.def().get("gold", 5)) * randf_range(1.0, 2.0) + 2.0) * Game.cheat("gold")))
			Game.gold += g
			_popup(u, "+%d gold" % g, Color(1.0, 0.85, 0.3), false, "%s steals %d gold!" % [u.name, g])
		elif randf() < 0.3:
			var iid: String = ["potion", "potion", "bandage", "ether", "hi_potion"].pick_random()
			Game.add_item(iid)
			_popup(u, "Stole %s!" % DB.ITEMS[iid]["name"], Color(1.0, 0.85, 0.3), false, "%s steals a %s!" % [u.name, DB.ITEMS[iid]["name"]])
		else:
			_popup(u, "Nothing to steal", Color(0.75, 0.75, 0.8))


func _hurt(tg: Unit, dmg: int, crit: bool, element: String, logged: bool = true, how: String = "") -> void:
	# a Ward soaks up damage first
	var absorbed := 0
	for b in tg.buffs:
		if int(b.get("ward", 0)) > 0 and dmg > 0:
			var take := mini(int(b["ward"]), dmg)
			b["ward"] = int(b["ward"]) - take
			dmg -= take
			absorbed += take
	if absorbed > 0:
		tg.buffs = tg.buffs.filter(func(b): return not b.has("ward") or int(b["ward"]) > 0)
		_popup(tg, "Ward -%d" % absorbed, Color(0.75, 0.88, 1.0), false, "%s's Ward absorbs %d damage" % [tg.name, absorbed])
		if dmg <= 0:
			vis[tg]["flash"] = 0.5
			return
	tg.hp = maxi(0, tg.hp - dmg)
	vis[tg]["flash"] = 1.0
	var col := Color(1, 1, 1)
	if element == "fire":
		col = Color(1.0, 0.6, 0.3)
	elif element == "ice":
		col = Color(0.6, 0.85, 1.0)
	elif element == "lightning":
		col = Color(1.0, 0.95, 0.4)
	elif element == "shadow":
		col = Color(0.75, 0.5, 1.0)
	elif element == "poison":
		col = Color(0.6, 0.95, 0.3)
	var el_name: String = {"phys": "Physical", "fire": "Fire", "ice": "Ice", "lightning": "Lightning", "shadow": "Shadow", "poison": "Poison"}.get(element, "")
	var line := "%s takes %d %s damage%s%s" % [tg.name, dmg, el_name, " (Critical!)" if crit else "", (" [%s]" % how) if how != "" and how != "Front" else ""]
	if not tg.is_alive():
		line += " and falls!" if not tg.is_enemy else " and is defeated!"
	_popup(tg, ("%d!" % dmg) if crit else str(dmg), Color(1.0, 0.95, 0.3) if crit else col, crit, line.replace("  ", " ") if logged else false)
	if not tg.is_alive():
		tg.ct = 0.0
		tg.buffs.clear()
		if tg.is_enemy:
			var tw := create_tween()
			tw.tween_method(func(v): vis[tg]["alpha"] = v, 1.0, 0.0, 0.45)


## Floating text over a unit. note_text: true = also log "Name: text", a String = log that, false = don't log.
func _popup(u: Unit, text: String, col: Color, big: bool = false, note_text: Variant = true) -> void:
	if note_text is String:
		note(note_text)
	elif note_text:
		note("%s: %s" % [u.name, text])
	popups.append({"text": text, "g": vis[u]["g"], "gh": vis[u]["gh"], "dx": randf_range(-10, 10), "oy": -64.0 - 14.0 * popups.filter(func(q): return q["life"] > 0.7).size(), "col": col, "life": 1.0, "big": big})


func _use_item(u: Unit, iid: String, targets: Array) -> void:
	var it: Dictionary = DB.ITEMS[iid]
	Game.remove_item(iid)
	msg("%s uses %s!" % [u.name, it["name"]])
	await _cast(u, {"element": it.get("element", "heal")})
	for tg in targets:
		if it["effect"] == "damage":
			if tg.is_alive():
				var dmg: int = int(round(float(it["amount"]) * (1.0 - tg.resist(it.get("element", "phys"))) * randf_range(0.9, 1.1)))
				_hurt(tg, max(1, dmg), false, it.get("element", "phys"))
				await get_tree().create_timer(0.1).timeout
		else:
			var hp0: int = tg.hp
			var mp0: int = tg.mp
			var line := Game.apply_item(iid, tg)
			if line == "":
				_popup(tg, "No effect", Color(0.8, 0.8, 0.8))
			elif it["effect"] == "revive":
				_popup(tg, "Revived!", Color(0.45, 1.0, 0.5))
			elif it["effect"] == "hot":
				_popup(tg, "Regeneration +%d" % int(it["amount"]), Color(0.45, 1.0, 0.5))
			elif it["effect"] == "mp":
				_popup(tg, "+%d MP" % (tg.mp - mp0), Color(0.5, 0.75, 1.0))
			else:
				_popup(tg, "+%d" % (tg.hp - hp0), Color(0.45, 1.0, 0.5))
			_spawn_fx(tg, Color(0.5, 1.0, 0.6))
	await get_tree().create_timer(0.5).timeout


func _victory() -> void:
	msg("Floor %d cleared!" % depth)
	await get_tree().create_timer(0.7).timeout
	var xp := 0
	var gold := 0
	var drops: Array = []
	var gear: Array = []
	for e in enemies:
		var d: Dictionary = e.def()
		if e.summoned:
			xp += int(round(e.xp_value() / 4.0 * Game.cheat("xp")))
			continue
		xp += int(round(e.xp_value() * Game.cheat("xp")))
		gold += int(round(e.gold_value() * Game.cheat("gold")))
		for di in Game.drop_rolls(float(d.get("drop", 0.0))):
			drops.append("potion" if randf() < 0.75 else "ether")
		for gi in Game.drop_rolls(float(d.get("gear", 0.0)) + 0.1):
			gear.append(Loot.roll_drop(e.level))
		if d.get("boss", false) or e.elite:
			if d.has("unique"):
				gear.append(Loot.make_unique(d["unique"]))
			if d.has("unique_pool"):
				gear.append(Loot.make_unique((d["unique_pool"] as Array).pick_random()))
			for bi in randi_range(2, 3) * int(Game.cheat("item_qty")):
				gear.append(Loot.roll_drop(e.level, true))
			drops.append("hi_potion")
	Game.gold += gold
	# Everyone still standing shares the XP (with a bonus for fighting together).
	var survivors := _alive(heroes).size()
	var share := int(ceil(float(xp) * (1.0 + 0.25 * (survivors - 1)) / maxi(1, survivors)))
	var lines: Array = ["Floor %d cleared!   +%d XP each,  +%d gold." % [depth, share, gold]]
	var leveled := false
	for h in heroes:
		h.protector = null
		h.poison_left = 0
		h.buffs.clear()
		if h.is_alive():
			var lv: Array = h.gain_xp(share)
			leveled = leveled or lv.size() > 0
			lines.append_array(lv)
	if drops.size() + gear.size() > 0:
		lines.append("The enemies dropped %d item%s." % [drops.size() + gear.size(), "" if drops.size() + gear.size() == 1 else "s"])
	if leveled:
		lines.append("(Open the party menu with Tab to spend skill points.)")
	await Game.main.dialog.ask("\n".join(lines), ["Continue"])
	if drops.size() + gear.size() > 0:
		var spoils := {}
		for iid in drops:
			spoils[iid] = int(spoils.get(iid, 0)) + 1
		await Game.main.trade.open_loot(spoils, gear)
	finished.emit("victory")

## Hover a unit for its status; while targeting, also the expected result of the attack.
func _update_unit_tip() -> void:
	if unit_tip == null:
		return
	var hovered_gui := get_viewport().gui_get_hovered_control()
	var u: Unit = _unit_on(board.hover) if hovered_gui == null else null
	if u == null:
		unit_tip.hide_tip()
		return
	var lines := _unit_lines(u)
	lines.insert(1, ["Height %d   Move %d   Jump %d" % [board.height_at(u.cell), u.move_range(), u.jump_height()], Color(0.7, 0.75, 0.9), false])
	if not target_ctx.is_empty() and valid_cells.has(board.hover) and not target_ctx["item"]:
		var au: Unit = target_ctx["u"]
		var aid: String = target_ctx["aid"]
		var ab: Dictionary = DB.resolve_ability(aid)
		if ab["kind"] in ["phys", "magic"] and u.is_enemy != au.is_enemy:
			var tags := DB.tags_for(aid, au)
			var pi := _pos_info(au, au.cell, u, tags.has("hit"))
			var ab2 := ab.duplicate()
			ab2["id"] = DB.base_id(aid)
			ab2["pos_mult"] = pi["mult"] if tags.has("hit") or ab["kind"] == "magic" else 1.0
			ab2["evade_mult"] = pi["evade"]
			var hit := Combat.hit_chance(au, u, ab2)
			var dmg := Combat.expected_damage(au, u, ab2, tags) * float(ab.get("strikes", 1))
			lines.append(["", Color.WHITE, false])
			lines.append(["%s:  ~%d damage,  %d%% to hit" % [ab["name"], int(dmg), int(round(hit * 100.0))], Color(1.0, 0.9, 0.55), false])
			if pi["label"] != "":
				lines.append(["  " + str(pi["label"]) + ("  (x%.2f)" % float(pi["mult"]) if float(pi["mult"]) != 1.0 else ""), Color(1.0, 0.8, 0.45), false])
	var mp := get_viewport().get_mouse_position()
	unit_tip.show_lines(lines, Rect2(mp, Vector2.ZERO), Color(1.0, 0.6, 0.55) if u.is_enemy else Color(0.6, 0.85, 1.0))

## Top bar (latest events, click to open the log) + drop-down log with scrollbar and resize grip.
func _build_log_ui(root: Control) -> void:
	var top := VBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_CENTER_TOP)
	top.offset_left = -380
	top.offset_right = 380
	top.offset_top = 12
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_theme_constant_override("separation", 3)
	root.add_child(top)

	msg_panel = PanelContainer.new()
	msg_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	msg_panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	msg_panel.gui_input.connect(_on_bar_input)
	top.add_child(msg_panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	msg_panel.add_child(row)
	msg_label = RichTextLabel.new()
	Glossary.hook(msg_label)
	msg_label.bbcode_enabled = true
	msg_label.fit_content = true
	msg_label.scroll_active = false
	msg_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	msg_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	msg_label.mouse_filter = Control.MOUSE_FILTER_PASS
	msg_label.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	msg_label.gui_input.connect(_on_bar_input)
	row.add_child(msg_label)
	# lines button: cycles the bar between 1, 2 and 3 lines
	lines_btn = _icon_button(func(c: Control):
		for i in 3:
			var y := 7.0 + i * 6.0
			var lit := i < log_lines
			c.draw_rect(Rect2(8, y, c.size.x - 16, 3), Color(1, 0.9, 0.55) if lit else Color(0.4, 0.43, 0.55)))
	lines_btn.tooltip_text = "Lines shown in this bar (1-3)"
	lines_btn.pressed.connect(func():
		log_lines = log_lines % 3 + 1
		for ch in lines_btn.get_children():
			ch.queue_redraw()
		_refresh_bar())
	row.add_child(lines_btn)
	# drop button: opens / closes the full log
	drop_btn = _icon_button(func(c: Control):
		var cx := c.size.x / 2.0
		var cy := c.size.y / 2.0
		var pts: PackedVector2Array
		if log_drop != null and log_drop.visible:
			pts = PackedVector2Array([Vector2(cx - 6, cy + 3), Vector2(cx + 6, cy + 3), Vector2(cx, cy - 4)])
		else:
			pts = PackedVector2Array([Vector2(cx - 6, cy - 3), Vector2(cx + 6, cy - 3), Vector2(cx, cy + 4)])
		c.draw_colored_polygon(pts, Color(0.92, 0.94, 1.0)))
	drop_btn.tooltip_text = "Battle log"
	drop_btn.pressed.connect(_toggle_log)
	row.add_child(drop_btn)

	# the drop-down log
	log_drop = PanelContainer.new()
	log_drop.custom_minimum_size = Vector2(0, log_height)
	log_drop.mouse_filter = Control.MOUSE_FILTER_STOP
	log_drop.visible = false
	top.add_child(log_drop)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 2)
	log_drop.add_child(body)
	var holder := Control.new()
	holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(holder)
	log_text = RichTextLabel.new()
	Glossary.hook(log_text)
	log_text.bbcode_enabled = true
	log_text.scroll_active = true
	log_text.scroll_following = true
	log_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	log_text.set_anchors_preset(Control.PRESET_FULL_RECT)
	log_text.add_theme_font_size_override("normal_font_size", 15)
	holder.add_child(log_text)
	# "go to bottom" arrow, shown while scrolled up
	log_bottom_btn = _icon_button(func(c: Control):
		var cx := c.size.x / 2.0
		var cy := c.size.y / 2.0
		c.draw_colored_polygon(PackedVector2Array([Vector2(cx - 7, cy - 5), Vector2(cx + 7, cy - 5), Vector2(cx, cy + 3)]), Color(1, 0.9, 0.55))
		c.draw_rect(Rect2(cx - 7, cy + 5, 14, 2), Color(1, 0.9, 0.55)))
	log_bottom_btn.tooltip_text = "Go to latest"
	log_bottom_btn.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	log_bottom_btn.offset_left = -54
	log_bottom_btn.offset_top = -38
	log_bottom_btn.offset_right = -22
	log_bottom_btn.offset_bottom = -6
	log_bottom_btn.visible = false
	log_bottom_btn.pressed.connect(func():
		var vb := log_text.get_v_scroll_bar()
		vb.value = vb.max_value
		log_text.scroll_following = true)
	holder.add_child(log_bottom_btn)
	# resize grip along the bottom edge
	var grip := Control.new()
	grip.custom_minimum_size = Vector2(0, 12)
	grip.mouse_filter = Control.MOUSE_FILTER_STOP
	grip.mouse_default_cursor_shape = Control.CURSOR_VSIZE
	grip.tooltip_text = "Drag to resize"
	grip.draw.connect(func():
		var cx := grip.size.x / 2.0
		for i in 3:
			grip.draw_rect(Rect2(cx - 24, 3 + i * 3, 48, 1), Color(0.6, 0.64, 0.8, 0.8)))
	grip.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
			resizing = ev.pressed
			grip.accept_event()
		elif ev is InputEventMouseMotion and resizing:
			var vp := get_viewport_rect().size
			log_height = clampf(log_height + ev.relative.y, 110.0, maxf(140.0, vp.y - 330.0))
			log_drop.custom_minimum_size.y = log_height
			grip.accept_event())
	body.add_child(grip)

	unit_tip = InfoTip.new()
	root.add_child(unit_tip)
	_refresh_bar()

func _icon_button(painter: Callable) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(34, 30)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.focus_mode = Control.FOCUS_NONE
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(func(): painter.call(c))
	b.add_child(c)
	return b

func _on_bar_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		_toggle_log()
		msg_panel.accept_event()

func _toggle_log() -> void:
	log_drop.visible = not log_drop.visible
	if log_drop.visible:
		log_drop.custom_minimum_size.y = log_height
		_rebuild_log()
	for ch in drop_btn.get_children():
		ch.queue_redraw()

## One log entry as BBCode.
func _entry_bb(e: Dictionary) -> String:
	if e["sub"]:
		return "        [color=#b4bad2]%s[/color]" % InfoTip.bbcode(e["text"])
	return "[color=#6f7696]%3d[/color]   %s" % [int(e["round"]), InfoTip.bbcode(e["text"])]

func _rebuild_log() -> void:
	log_text.clear()
	var lines: Array = []
	for e in event_log:
		lines.append(_entry_bb(e))
	log_text.append_text("\n".join(lines))
	log_text.scroll_following = true
	await get_tree().process_frame
	var vb := log_text.get_v_scroll_bar()
	vb.value = vb.max_value

## Records an event in the battle log (sub = a detail line under the last headline).
func note(text: String, sub: bool = true) -> void:
	if not sub and not event_log.is_empty() and not event_log[-1]["sub"] and event_log[-1]["text"] == text:
		return    # same headline again (e.g. backing out of a menu)
	var e := {"text": text, "sub": sub, "round": int(clock) + 1}
	event_log.append(e)
	if log_drop != null and log_drop.visible:
		log_text.append_text(("\n" if event_log.size() > 1 else "") + _entry_bb(e))
	_refresh_bar()

func _refresh_bar() -> void:
	if msg_label == null:
		return
	var shown: Array = []
	for e in event_log:
		shown.append("[color=#b4bad2]%s[/color]" % InfoTip.bbcode(e["text"]) if e["sub"] else InfoTip.bbcode(e["text"]))
	if transient != "":
		shown.append("[color=#ffe9a6]%s[/color]" % InfoTip.bbcode(transient))
	shown = shown.slice(maxi(0, shown.size() - log_lines))
	var body := "\n".join(shown)
	msg_label.text = ("[center]%s[/center]" % body) if log_lines == 1 else body

## Headline message: shown in the top bar and recorded in the battle log.
## record = false shows it as a passing hint only (menu tips, prompts).
func msg(text: String, record: bool = true) -> void:
	if record:
		transient = ""
		note(text, false)
	else:
		transient = text
		_refresh_bar()


## Status tooltip for a unit: health, time bar, poison, regeneration, buffs and debuffs.
func _unit_lines(u: Unit) -> Array:
	var head := Color(1.0, 0.6, 0.55) if u.is_enemy else Color(0.6, 0.85, 1.0)
	var lv: int = int(u.def().get("lvl", u.level)) if u.is_enemy else u.level
	var lines: Array = [["%s   Lv %d" % [u.name, lv], head, false]]
	if not u.is_alive():
		lines.append(["Knocked out", Color(0.7, 0.7, 0.75), false])
		return lines
	var hp_line := "HP %d / %d" % [u.hp, u.max_hp()]
	if u.max_mp() > 0:
		hp_line += "     MP %d / %d" % [u.mp, u.max_mp()]
	lines.append([hp_line, Color(0.92, 0.94, 1.0), false])
	lines.append(["Acting now" if u == active else ("CT %d / 100" % int(minf(u.ct, 100.0))), Color(1.0, 0.88, 0.45), false])
	if u.protector != null and u.protector.is_alive():
		lines.append(["Protected by %s" % u.protector.name, Color(0.7, 0.85, 1.0), false])
	var effects: Array = []
	if u.poison_left > 0:
		effects.append(["{poison:%d}" % u.poison_left, Glossary.TERMS["poison"]["color"], false])
	var const_regen := int(u.mod("hp_regen"))
	if const_regen > 0:
		effects.append(["{regen:%d}" % const_regen, Glossary.TERMS["regen"]["color"], false])
	for h in u.hots:
		var rounds := float(int(h["ticks"])) / 4.0
		var rtxt := str(snappedf(rounds, 0.25)).trim_suffix(".0")
		effects.append(["Regeneration +%d  (%s round%s left)" % [int(h["amount"]), rtxt, "" if rtxt == "1" else "s"], Glossary.TERMS["regen"]["color"], false])
	if int(u.mod("mp_regen")) > 0:
		effects.append(["MP regeneration +%d" % int(u.mod("mp_regen")), Color(0.55, 0.75, 1.0), false])
	var buffs: Array = []
	var debuffs: Array = []
	for b in u.buffs:
		var left := maxi(1, int(b["turns"]) - 1)
		var when := "until its next turn" if int(b["turns"]) <= 1 else ("%d turn%s" % [left, "" if left == 1 else "s"])
		var nm: String = b.get("name", "Effect")
		var desc := _mods_text(b.get("mods", {}))
		if b.get("stun", false):
			nm = "Stun"
			desc = "loses its next turn"
		elif b.get("ensnare", false):
			nm = "Ensnare"
			desc = ""
		elif b.get("silence", false):
			nm = "Silence"
			desc = ""
		elif b.has("ward"):
			desc = "absorbs %d more damage" % int(b["ward"])
		elif b.has("imbue"):
			var el: String = b["imbue"]
			desc = "Hits add %d-%d %s damage" % [int(b["mods"].get("add_%s_min" % el, 0.0)), int(round(b["mods"].get("add_%s_max" % el, 0.0))), el.capitalize()]
		elif b.get("hidden", false):
			desc = "can't be singled out"
		elif b.has("envenom"):
			desc = "next %d Hit%s add Poison %d" % [int(b.get("charges", 0)), "" if int(b.get("charges", 0)) == 1 else "s", int(b["envenom"])]
		elif b.get("riposte", false):
			desc += ", Counters dodged Hits"
		elif b.has("dot"):
			desc = "%d Physical damage when acting%s" % [int(b["dot"]), (", " + desc) if desc != "" else ""]
		var line := "%s%s  (%s)" % [nm, (": " + desc) if desc != "" else "", when]
		if b.get("debuff", false):
			debuffs.append(line)
		else:
			buffs.append(line)
	lines.append_array(effects)
	if not buffs.is_empty():
		lines.append(["Buffs", Color(0.55, 1.0, 0.6), false])
		for l in buffs:
			lines.append(["  " + l, Color(0.85, 0.95, 0.88), true])
	if not debuffs.is_empty():
		lines.append(["Debuffs", Color(0.85, 0.55, 1.0), false])
		for l in debuffs:
			lines.append(["  " + l, Color(0.92, 0.86, 0.98), true])
	if effects.is_empty() and buffs.is_empty() and debuffs.is_empty():
		lines.append(["No effects", Color(0.6, 0.62, 0.72), false])
	return lines

const MOD_TEXT := {
	"def": ["%+d Armour", 1.0], "def_pct": ["%+d%% Physical damage reduction", 100.0],
	"speed": ["%+d%% time bar speed", 100.0], "phys_dmg": ["%+d%% Physical damage", 100.0],
	"spell_dmg": ["%+d%% spell damage", 100.0], "accuracy": ["%+d%% accuracy", 100.0],
	"fire_res": ["%+d%% Fire resistance", 100.0], "ice_res": ["%+d%% Ice resistance", 100.0],
	"lightning_res": ["%+d%% Lightning resistance", 100.0], "magic_res": ["%+d%% Magic resistance", 100.0],
	"evasion": ["%+d%% Evasion", 100.0], "crit": ["%+d%% Critical chance", 100.0],
	"empower": ["%+d%% damage on the next Hit", 100.0], "mp_regen": ["%+d MP regeneration", 1.0],
}

func _mods_text(m: Dictionary) -> String:
	var parts: Array = []
	var res_keys := ["fire_res", "ice_res", "lightning_res", "magic_res"]
	var res_all := res_keys.all(func(k): return m.has(k) and is_equal_approx(float(m[k]), float(m.get("fire_res", 0.0))))
	for k in m:
		if res_all and k in res_keys:
			continue
		var v := float(m[k])
		if k == "assured_crit":
			parts.append("next Hit is a guaranteed Critical")
		elif k == "def_pct":
			parts.append("%d%% %s Physical damage taken" % [absi(int(round(v * 100.0))), "less" if v > 0.0 else "more"])
		elif MOD_TEXT.has(k):
			parts.append(MOD_TEXT[k][0] % int(round(v * MOD_TEXT[k][1])))
		else:
			parts.append("%s %+.2f" % [str(k).capitalize(), v])
	if res_all:
		parts.append("%+d%% all resistances" % int(round(float(m["fire_res"]) * 100.0)))
	return ", ".join(parts)

