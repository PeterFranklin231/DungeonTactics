class_name ItemIcon
extends Control
## A square inventory cell: draws an item (equipment Dictionary or consumable id) with a
## rarity-coloured frame. Supports hover tooltips, clicks and drag & drop.
##   drag_payload: Dictionary sent when dragged ({} = not draggable)
##   drop_check / drop_do: Callables (payload) -> bool / void for accepting drops

signal clicked(icon: ItemIcon, button: int)

var item = null              # equipment Dictionary
var consumable := ""         # consumable id
var count := 0
var placeholder := ""        # empty-slot label, e.g. "Helm"
var unit: Unit = null        # for requirement colouring in tooltips
var drag_payload := {}
var drop_check: Callable
var drop_do: Callable
var dim := false             # can't be equipped by the current character
var pending := ""            # "buy" / "sell" highlight in the trade window
var price_text := ""         # small price label (trade window)
var hovered := false

const STYLE_TINT := {"str": Color(0.75, 0.72, 0.7), "dex": Color(0.62, 0.45, 0.28), "int": Color(0.45, 0.4, 0.75), "none": Color(0.85, 0.75, 0.35)}

func _init(sz: float = 56.0) -> void:
	custom_minimum_size = Vector2(sz, sz)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	mouse_entered.connect(func():
		hovered = true
		_show_tip()
		queue_redraw())
	mouse_exited.connect(func():
		hovered = false
		Game.main.tip.hide_tip()
		queue_redraw())
	focus_entered.connect(func():
		_show_tip()
		queue_redraw())
	focus_exited.connect(func():
		Game.main.tip.hide_tip()
		queue_redraw())

func tip_lines() -> Array:
	if item != null:
		return Loot.describe(item, unit)
	if consumable != "":
		var d: Dictionary = DB.ITEMS[consumable]
		return [[d["name"], Color(1, 0.9, 0.55), false], ["Consumable  x%d" % count, Color(0.65, 0.68, 0.8), false], d["desc"]]
	return []

func _show_tip() -> void:
	var l := tip_lines()
	if l.size() > 0:
		Game.main.tip.show_lines(l, get_global_rect())

func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and (e.button_index == MOUSE_BUTTON_LEFT or e.button_index == MOUSE_BUTTON_RIGHT):
		if e.double_click:
			return
		accept_event()
		clicked.emit(self, e.button_index)
	elif e.is_action_pressed("ui_accept"):
		accept_event()
		clicked.emit(self, MOUSE_BUTTON_LEFT)

func _get_drag_data(_pos: Vector2):
	if drag_payload.is_empty():
		return null
	var prev := ItemIcon.new(size.x)
	prev.item = item
	prev.consumable = consumable
	prev.count = count
	prev.modulate.a = 0.8
	var holder := Control.new()
	holder.add_child(prev)
	prev.position = -size * 0.5
	set_drag_preview(holder)
	Game.main.tip.hide_tip()
	return drag_payload

func _can_drop_data(_pos: Vector2, data) -> bool:
	return drop_check.is_valid() and data is Dictionary and drop_check.call(data)

func _drop_data(_pos: Vector2, data) -> void:
	if drop_do.is_valid():
		drop_do.call(data)

func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var frame := Color(0.35, 0.38, 0.55)
	if item != null:
		frame = Loot.color_of(item)
	elif consumable != "":
		frame = Color(0.6, 0.8, 0.6)
	draw_rect(r, Color(0.03, 0.04, 0.1, 0.9))
	if item != null and item.get("rarity", "normal") != "normal":
		draw_rect(r.grow(-2), Color(frame.r, frame.g, frame.b, 0.12))
	var hl := hovered or has_focus()
	draw_rect(r, frame.lightened(0.3) if hl else frame.darkened(0.25), false, 2.0 if hl else 1.5)
	var c := size * 0.5
	var s := size.x / 56.0
	if item != null:
		_draw_item(c, s * (0.95 if size.x > 40 else 1.0))
		if dim:
			draw_rect(r.grow(-2), Color(0.5, 0.0, 0.0, 0.35))
	elif consumable != "":
		_draw_consumable(c, s)
		var font := ThemeDB.fallback_font
		var txt := str(count)
		draw_string_outline(font, Vector2(size.x - 4 - font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x, size.y - 4), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 4, Color.BLACK)
		draw_string(font, Vector2(size.x - 4 - font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x, size.y - 4), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
	elif placeholder != "":
		pass
	if pending != "":
		var pc := Color(0.35, 1.0, 0.45) if pending in ["buy", "take"] else Color(1.0, 0.75, 0.25)
		draw_rect(r.grow(-1), Color(pc.r, pc.g, pc.b, 0.16))
		draw_rect(r, pc, false, 3.0)
		var f3 := ThemeDB.fallback_font
		var tag: String = {"buy": "BUY", "sell": "SELL", "take": "TAKE"}.get(pending, "")
		draw_rect(Rect2(Vector2(2, 2), Vector2(f3.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + 6, 14)), pc.darkened(0.45))
		draw_string(f3, Vector2(5, 13), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)
	if price_text != "":
		var f4 := ThemeDB.fallback_font
		draw_string_outline(f4, Vector2(4, size.y - 4), price_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, 4, Color.BLACK)
		draw_string(f4, Vector2(4, size.y - 4), price_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 0.85, 0.35))
	if item == null and consumable == "" and placeholder != "":
		var font2 := ThemeDB.fallback_font
		draw_string(font2, Vector2(0, c.y + 5), placeholder, HORIZONTAL_ALIGNMENT_CENTER, size.x, 12, Color(0.45, 0.48, 0.62))

func _draw_consumable(c: Vector2, s: float) -> void:
	var col := Color(0.85, 0.2, 0.2)
	match consumable:
		"hi_potion":
			col = Color(1.0, 0.45, 0.15)
		"ether":
			col = Color(0.3, 0.5, 1.0)
		"bandage":
			draw_circle(c + Vector2(-4, 2) * s, 11 * s, Color(0.93, 0.9, 0.82))
			draw_circle(c + Vector2(-4, 2) * s, 4 * s, Color(0.75, 0.7, 0.62))
			draw_colored_polygon(Art.pts([c + Vector2(4, -9) * s, c + Vector2(18, -4) * s, c + Vector2(16, 4) * s, c + Vector2(4, 13) * s]), Color(0.93, 0.9, 0.82))
			draw_line(c + Vector2(10, -4) * s, c + Vector2(10, 6) * s, Color(0.85, 0.2, 0.2), 2.5 * s)
			draw_line(c + Vector2(5, 1) * s, c + Vector2(15, 1) * s, Color(0.85, 0.2, 0.2), 2.5 * s)
			return
		"phoenix_down":
			# a feather
			draw_colored_polygon(Art.pts([c + Vector2(-12, 14) * s, c + Vector2(10, -16) * s, c + Vector2(14, -12) * s, c + Vector2(-8, 16) * s]), Color(1.0, 0.6, 0.2))
			draw_line(c + Vector2(-14, 18) * s, c + Vector2(12, -14) * s, Color(1, 0.9, 0.6), 1.5)
			return
		"fire_bomb":
			draw_circle(c + Vector2(0, 4) * s, 13 * s, Color(0.2, 0.2, 0.22))
			draw_line(c + Vector2(6, -8) * s, c + Vector2(12, -16) * s, Color(0.8, 0.7, 0.5), 2)
			draw_circle(c + Vector2(13, -17) * s, 3.5 * s, Color(1, 0.6, 0.1))
			return
	# potion bottle
	draw_rect(Rect2(c + Vector2(-4, -18) * s, Vector2(8, 8) * s), Color(0.8, 0.75, 0.65))
	draw_circle(c + Vector2(0, 4) * s, 13 * s, col)
	draw_circle(c + Vector2(-4, 0) * s, 4 * s, Color(1, 1, 1, 0.4))

func _draw_item(c: Vector2, s: float) -> void:
	var b := Loot.base_of(item)
	var tint: Color = STYLE_TINT.get(b.get("style", "none"), Color.WHITE)
	var rc := Loot.color_of(item)
	var steel := Color(0.82, 0.85, 0.9)
	var wood := Color(0.55, 0.36, 0.18)
	match b.get("kind", ""):
		"sword":
			draw_line(c + Vector2(-14, 14) * s, c + Vector2(14, -14) * s, steel, 4 * s)
			draw_line(c + Vector2(-14, 2) * s, c + Vector2(-2, 14) * s, Color(0.7, 0.55, 0.2), 3.5 * s)
			draw_line(c + Vector2(-19, 19) * s, c + Vector2(-12, 12) * s, wood, 4 * s)
		"axe":
			draw_line(c + Vector2(-14, 18) * s, c + Vector2(10, -14) * s, wood, 4 * s)
			draw_colored_polygon(Art.pts([c + Vector2(2, -18) * s, c + Vector2(18, -6) * s, c + Vector2(8, 4) * s, c + Vector2(4, -8) * s]), steel)
		"dagger":
			draw_line(c + Vector2(-8, 10) * s, c + Vector2(10, -10) * s, steel, 3.5 * s)
			draw_line(c + Vector2(-10, 2) * s, c + Vector2(-2, 10) * s, Color(0.7, 0.55, 0.2), 3 * s)
			draw_line(c + Vector2(-13, 15) * s, c + Vector2(-7, 9) * s, wood, 3.5 * s)
		"fist":
			var wrap := Color(0.85, 0.8, 0.68)
			draw_rect(Rect2(c + Vector2(-12, -6) * s, Vector2(22, 18) * s), wrap)
			for kn in 4:
				draw_circle(c + Vector2(-8.5 + kn * 5.5, -7) * s, 3.2 * s, steel)
			draw_rect(Rect2(c + Vector2(-12, 4) * s, Vector2(22, 3) * s), rc.lerp(Color(0.6, 0.35, 0.2), 0.5))
			draw_rect(Rect2(c + Vector2(-8, 12) * s, Vector2(14, 8) * s), wrap.darkened(0.15))
		"bow":
			draw_arc(c + Vector2(-6, 0) * s, 18 * s, -1.2, 1.2, 16, wood, 3.5 * s)
			draw_line(c + Vector2(0, -17) * s, c + Vector2(0, 17) * s, Color(0.9, 0.9, 0.85), 1.2)
			draw_line(c + Vector2(-14, 0) * s, c + Vector2(14, 0) * s, Color(0.75, 0.65, 0.5), 1.8 * s)
		"wand":
			draw_line(c + Vector2(-12, 14) * s, c + Vector2(8, -8) * s, wood.lightened(0.15), 3.5 * s)
			draw_circle(c + Vector2(10, -10) * s, 5 * s, rc.lerp(Color(0.6, 0.8, 1), 0.5))
		"staff":
			draw_line(c + Vector2(-14, 20) * s, c + Vector2(10, -14) * s, wood, 4 * s)
			draw_circle(c + Vector2(12, -16) * s, 6 * s, rc.lerp(Color(1, 0.6, 0.2), 0.5))
		"shield":
			var pts := Art.pts([c + Vector2(-14, -16) * s, c + Vector2(14, -16) * s, c + Vector2(14, 0) * s, c + Vector2(0, 18) * s, c + Vector2(-14, 0) * s])
			draw_colored_polygon(pts, tint)
			draw_line(c + Vector2(0, -14) * s, c + Vector2(0, 14) * s, tint.darkened(0.35), 3 * s)
		"body":
			draw_colored_polygon(Art.pts([c + Vector2(-10, -16) * s, c + Vector2(10, -16) * s, c + Vector2(18, -8) * s, c + Vector2(12, -2) * s, c + Vector2(11, 17) * s, c + Vector2(-11, 17) * s, c + Vector2(-12, -2) * s, c + Vector2(-18, -8) * s]), tint)
			draw_line(c + Vector2(-5, -16) * s, c + Vector2(0, -8) * s, tint.darkened(0.4), 2)
			draw_line(c + Vector2(5, -16) * s, c + Vector2(0, -8) * s, tint.darkened(0.4), 2)
		"helm":
			draw_colored_polygon(Art.ellipse_pts(c + Vector2(0, 4) * s, 15 * s, 16 * s, 14, PI, TAU), tint)
			draw_rect(Rect2(c + Vector2(-15, 4) * s, Vector2(30, 6) * s), tint.darkened(0.25))
		"gloves":
			draw_colored_polygon(Art.pts([c + Vector2(-9, 16) * s, c + Vector2(-10, -6) * s, c + Vector2(-6, -14) * s, c + Vector2(6, -14) * s, c + Vector2(10, -4) * s, c + Vector2(16, -8) * s, c + Vector2(12, 4) * s, c + Vector2(9, 16) * s]), tint)
			draw_rect(Rect2(c + Vector2(-10, 10) * s, Vector2(20, 6) * s), tint.darkened(0.3))
		"boots":
			draw_colored_polygon(Art.pts([c + Vector2(-8, -16) * s, c + Vector2(4, -16) * s, c + Vector2(4, 6) * s, c + Vector2(16, 10) * s, c + Vector2(16, 16) * s, c + Vector2(-8, 16) * s]), tint)
			draw_rect(Rect2(c + Vector2(-9, -16) * s, Vector2(14, 5) * s), tint.darkened(0.3))
		"ring":
			draw_arc(c + Vector2(0, 3) * s, 11 * s, 0, TAU, 20, Color(0.9, 0.78, 0.35), 4 * s)
			draw_circle(c + Vector2(0, -9) * s, 5 * s, rc.lerp(Color(0.6, 0.9, 1), 0.4))
		"amulet":
			draw_arc(c + Vector2(0, -8) * s, 13 * s, 0.2, PI - 0.2, 16, Color(0.9, 0.78, 0.35), 2 * s)
			draw_colored_polygon(Art.pts([c + Vector2(0, 2) * s, c + Vector2(8, 10) * s, c + Vector2(0, 19) * s, c + Vector2(-8, 10) * s]), rc.lerp(Color(0.4, 0.9, 0.6), 0.4))
