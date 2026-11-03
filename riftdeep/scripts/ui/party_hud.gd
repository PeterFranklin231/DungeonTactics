class_name PartyHud
extends PanelContainer
## Top-left overworld HUD: location, money, then a compact row per character
## (headshot, stacked HP / MP bars of fixed length, current/max numbers).

const BAR_W := 96.0

class Face extends Control:
	var unit: Unit
	func _init() -> void:
		custom_minimum_size = Vector2(34, 34)
		clip_contents = true
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		if unit == null:
			return
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.08, 0.11, 0.3))
		Art.person(self, Vector2(16, 10 + 1.05 * 32), 1.05, unit.visual_look(), 1, 1.0 if unit.is_alive() else 0.4)
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.55, 0.6, 0.8), false, 1.0)
		if unit.skill_points > 0:
			draw_circle(Vector2(size.x - 5, 5), 4, Color(1, 0.8, 0.2))

var location: Label
var money: Label
var rows: VBoxContainer
var row_units: Array = []

func _init() -> void:
	position = Vector2(12, 12)
	add_theme_stylebox_override("panel", UiKit.panel_style(Color(0.05, 0.08, 0.25, 0.82)))
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	add_child(v)
	location = UiKit.label("", 15, Color(1, 0.9, 0.55))
	v.add_child(location)
	money = UiKit.label("", 13, Color(1, 0.85, 0.35))
	v.add_child(money)
	rows = VBoxContainer.new()
	rows.add_theme_constant_override("separation", 4)
	v.add_child(rows)

func _bar(col: Color) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.custom_minimum_size = Vector2(BAR_W, 7)
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.55)
	bg.set_corner_radius_all(2)
	b.add_theme_stylebox_override("background", bg)
	var fill := StyleBoxFlat.new()
	fill.bg_color = col
	fill.set_corner_radius_all(2)
	b.add_theme_stylebox_override("fill", fill)
	return b

func _small(text: String, col: Color) -> Label:
	var l := UiKit.label(text, 11, col)
	l.custom_minimum_size = Vector2(52, 0)
	return l

func _rebuild_rows() -> void:
	for c in rows.get_children():
		rows.remove_child(c)
		c.queue_free()
	row_units = Game.party.duplicate()
	for u in row_units:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var face := Face.new()
		face.unit = u
		row.add_child(face)
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 1)
		row.add_child(col)
		var name_l := UiKit.label(u.name, 11, Color(0.85, 0.88, 1.0))
		col.add_child(name_l)
		for kind in ["hp", "mp"]:
			var line := HBoxContainer.new()
			line.add_theme_constant_override("separation", 5)
			var bar := _bar(Color(0.3, 0.85, 0.35) if kind == "hp" else Color(0.35, 0.55, 1.0))
			bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			line.add_child(bar)
			line.add_child(_small("", Color(0.9, 0.92, 1.0) if kind == "hp" else Color(0.7, 0.8, 1.0)))
			col.add_child(line)
		rows.add_child(row)

func refresh(loc_name: String) -> void:
	if row_units != Game.party:
		_rebuild_rows()
	location.text = loc_name
	var m := "Gold %d" % Game.gold
	if int(Game.stash["gold"]) > 0:
		m += "   (stash %d)" % int(Game.stash["gold"])
	m += "     Packs %d/%d" % [Game.used_slots(), Game.capacity()]
	money.text = m
	for i in row_units.size():
		var u: Unit = row_units[i]
		var row: HBoxContainer = rows.get_child(i)
		row.get_child(0).queue_redraw()
		var col: VBoxContainer = row.get_child(1)
		(col.get_child(0) as Label).text = u.name + ("   KO" if not u.is_alive() else "")
		var hp_line: HBoxContainer = col.get_child(1)
		var mp_line: HBoxContainer = col.get_child(2)
		var hb: ProgressBar = hp_line.get_child(0)
		hb.max_value = maxi(1, u.max_hp())
		hb.value = u.hp
		var low := u.hp < u.max_hp() * 0.3
		(hb.get_theme_stylebox("fill") as StyleBoxFlat).bg_color = Color(0.9, 0.3, 0.25) if low else Color(0.3, 0.85, 0.35)
		(hp_line.get_child(1) as Label).text = "%d/%d" % [u.hp, u.max_hp()]
		var mb: ProgressBar = mp_line.get_child(0)
		mb.max_value = maxi(1, u.max_mp())
		mb.value = u.mp
		(mp_line.get_child(1) as Label).text = "%d/%d" % [u.mp, u.max_mp()]
	reset_size()
