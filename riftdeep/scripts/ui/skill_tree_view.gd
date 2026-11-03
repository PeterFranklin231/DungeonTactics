class_name SkillTreeView
extends Control
## Pannable / zoomable passive skill tree. Hover a node for a quick tooltip; click it to open
## a large pinned panel (hover its key terms) with Purchase / Close. Drag to pan, wheel to zoom.

signal allocated

var unit: Unit
var pan := Vector2.ZERO
var zoom := 0.75
var hover := ""
var _tip_shown := false
var dragging := false
var drag_dist := 0.0
var mouse := Vector2.ZERO
var t := 0.0
var detail: Control = null          # the pinned node panel, while open
var detail_id := ""

const RADIUS := {"origin": 18.0, "minor": 8.0, "major": 17.0, "notable": 14.0, "skill": 13.0, "passive": 11.0, "keystone": 19.0, "mastery": 12.0}
const TYPE_LABEL := {"origin": "Start", "minor": "Minor node", "major": "Major node - per level growth", "notable": "Notable", "skill": "Skill", "passive": "Passive", "keystone": "Keystone", "mastery": "Mastery"}

func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL

func _process(delta: float) -> void:
	if is_visible_in_tree():
		t += delta
		queue_redraw()
	else:
		if detail != null:
			close_detail()
		if _tip_shown:
			hover = ""
			_update_tip()

func to_screen(p: Vector2) -> Vector2:
	return size * 0.5 + (p + pan) * zoom

func _node_at(sp: Vector2) -> String:
	for id in DB.TREE:
		var n: Dictionary = DB.TREE[id]
		var r: float = RADIUS[n["type"]] * zoom + 4.0
		if to_screen(n["pos"]).distance_to(sp) <= r:
			return id
	return ""

func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		hover = ""
		_update_tip()

func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion:
		mouse = e.position
		if dragging:
			pan += e.relative / zoom
			drag_dist += e.relative.length()
		hover = _node_at(e.position)
	elif e is InputEventMouseButton:
		if e.pressed and e.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom = minf(zoom * 1.12, 2.2)
		elif e.pressed and e.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom = maxf(zoom / 1.12, 0.3)
		elif e.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
			if e.pressed:
				dragging = true
				drag_dist = 0.0
			else:
				dragging = false
				if e.button_index == MOUSE_BUTTON_LEFT and drag_dist < 6.0:
					var id := _node_at(e.position)
					if id != "" and unit != null:
						open_detail(id)
	elif e is InputEventKey and e.pressed:
		var step := 40.0 / zoom
		match e.keycode:
			KEY_LEFT, KEY_A:
				pan.x += step
			KEY_RIGHT, KEY_D:
				pan.x -= step
			KEY_UP, KEY_W:
				pan.y += step
			KEY_DOWN, KEY_S:
				pan.y -= step
			KEY_EQUAL, KEY_KP_ADD:
				zoom = minf(zoom * 1.12, 2.2)
			KEY_MINUS, KEY_KP_SUBTRACT:
				zoom = maxf(zoom / 1.12, 0.3)
			_:
				return
		accept_event()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.06, 0.09))
	# faint grid
	for i in range(-20, 21):
		var a := to_screen(Vector2(i * 64, -1400))
		var b := to_screen(Vector2(i * 64, 1400))
		draw_line(a, b, Color(1, 1, 1, 0.025), 1)
		var c := to_screen(Vector2(-1400, i * 64))
		var d := to_screen(Vector2(1400, i * 64))
		draw_line(c, d, Color(1, 1, 1, 0.025), 1)
	if unit == null:
		return
	var font := get_theme_default_font()
	# Branch titles
	for b in [["STRENGTH", Vector2(0, -1060), "str"], ["DEXTERITY", Vector2(1080, -40), "dex"], ["INTELLIGENCE", Vector2(0, 1100), "int"], ["CONSTITUTION", Vector2(-1080, -40), "con"]]:
		draw_string(font, to_screen(b[1]) - Vector2(150, 0), b[0], HORIZONTAL_ALIGNMENT_CENTER, 300, int(22 * zoom) + 6, DB.BRANCH_COLORS[b[2]].darkened(0.2))
	# class regions (rough guides, not real classes)
	for aid in DB.ARMS:
		var arm: Dictionary = DB.ARMS[aid]
		var lp: Vector2 = DB._polar(float(arm["ang"]), 10.6) + DB._polar(float(arm["ang"]) + 90.0, 0.9)
		draw_string(font, to_screen(lp) - Vector2(120, 0), str(arm["name"]).to_upper(), HORIZONTAL_ALIGNMENT_CENTER, 240, int(15 * zoom) + 5, Color(DB.BRANCH_COLORS[aid], 0.55))
	for did in DB.DIAGONALS:
		var dg: Dictionary = DB.DIAGONALS[did]
		var dp: Vector2 = DB._polar(float(dg["ang"]), 14.2)
		draw_string(font, to_screen(dp) - Vector2(120, 0), str(dg["name"]).to_upper(), HORIZONTAL_ALIGNMENT_CENTER, 240, int(15 * zoom) + 5, Color(DB.BRANCH_COLORS[did], 0.55))
	# Links
	for id in DB.TREE:
		var n: Dictionary = DB.TREE[id]
		for l in n["links"]:
			if l < id:
				continue
			var a1: bool = unit.nodes.has(id)
			var b1: bool = unit.nodes.has(l)
			var col := Color(0.22, 0.22, 0.26)
			var wd := 3.0
			if a1 and b1:
				col = Color(0.95, 0.82, 0.45)
				wd = 5.0
			elif a1 or b1:
				col = Color(0.5, 0.48, 0.42)
			draw_line(to_screen(n["pos"]), to_screen(DB.TREE[l]["pos"]), col, wd * zoom + 1.0, true)
	# Nodes
	var pulse := 0.5 + 0.5 * sin(t * 4.0)
	for id in DB.TREE:
		var n: Dictionary = DB.TREE[id]
		var p := to_screen(n["pos"])
		var typ: String = n["type"]
		var r: float = RADIUS[typ] * zoom
		var bc: Color = DB.BRANCH_COLORS[n["branch"]]
		var alloc: bool = unit.nodes.has(id)
		var linked: bool = unit.is_linked(id)
		var fill := bc if alloc else bc.darkened(0.78)
		if linked and not alloc:
			var glow := Color(1, 0.95, 0.6, 0.25 + 0.35 * pulse) if unit.skill_points > 0 else Color(1, 1, 1, 0.12)
			draw_circle(p, r + 6.0 * zoom + 2, glow)
		if typ == "skill":
			var q := Art.pts([p + Vector2(0, -r * 1.25), p + Vector2(r * 1.25, 0), p + Vector2(0, r * 1.25), p + Vector2(-r * 1.25, 0)])
			draw_colored_polygon(q, fill)
			q.append(q[0])
			draw_polyline(q, Color(1, 1, 1, 0.85) if alloc else bc.darkened(0.3), 2.0)
		else:
			draw_circle(p, r, fill)
			draw_arc(p, r, 0, TAU, 24, Color(1, 1, 1, 0.85) if alloc else bc.darkened(0.3), 2.0, true)
			if typ == "major":
				draw_arc(p, r + 4.0 * zoom, 0, TAU, 28, Color(0.95, 0.82, 0.45) if alloc else Color(0.5, 0.45, 0.3), 2.0, true)
			if typ == "notable":
				draw_arc(p, r - 4.0 * zoom, 0, TAU, 20, Color(1, 1, 1, 0.35), 1.5, true)
		if id == hover:
			draw_arc(p, r + 3, 0, TAU, 24, Color(1, 1, 1), 2.0, true)
		if typ != "minor" and zoom > 0.45:
			var fs := int(11 * zoom) + 3
			draw_string_outline(font, p + Vector2(-80, r + fs + 2), n["name"], HORIZONTAL_ALIGNMENT_CENTER, 160, fs, 4, Color(0, 0, 0, 0.9))
			draw_string(font, p + Vector2(-80, r + fs + 2), n["name"], HORIZONTAL_ALIGNMENT_CENTER, 160, fs, Color(0.92, 0.92, 0.95) if alloc or linked else Color(0.55, 0.55, 0.6))
	# Tooltip
	_update_tip()

func _update_tip() -> void:
	if Game.main == null:
		return
	if hover == "" or not is_visible_in_tree() or unit == null or detail != null:
		if _tip_shown:
			Game.main.tip.hide_tip()
			_tip_shown = false
		return
	var n: Dictionary = DB.TREE[hover]
	var lines: Array = [[n["name"], Color(1, 0.9, 0.55), false], [TYPE_LABEL[n["type"]], Color(0.65, 0.68, 0.8), false]]
	var eff: Dictionary = n["effects"]
	if eff.has("skill"):
		var al := DB.ability_lines(eff["skill"], unit)
		lines.append(["Grants skill:", Color(0.92, 0.94, 1.0), false])
		lines.append_array(al)
	else:
		var desc := DB.describe_effects(eff)
		for para in desc.split("\n"):
			if para != "":
				lines.append(para)
	var status := "Click for details"
	if unit.nodes.has(hover):
		status = "[Allocated]"
	elif not unit.is_linked(hover):
		status = "Not connected to your tree yet"
	elif unit.skill_points <= 0:
		status = "No skill points available"
	lines.append([status, Color(0.65, 0.68, 0.8), false])
	Game.main.tip.show_lines(lines, Rect2(get_global_transform() * mouse, Vector2.ZERO), DB.BRANCH_COLORS[n["branch"]])
	_tip_shown = true


# ---------------------------------------------------------------------------
# Pinned detail panel
# ---------------------------------------------------------------------------
func _status(id: String) -> String:
	if unit.nodes.has(id):
		return "Already allocated"
	if not unit.is_linked(id):
		return "Not connected to your tree yet"
	if unit.skill_points <= 0:
		return "No skill points available"
	return ""

func _detail_bbcode(id: String) -> String:
	var n: Dictionary = DB.TREE[id]
	var bc: Color = DB.BRANCH_COLORS[n["branch"]]
	var out := "[font_size=26][color=#%s]%s[/color][/font_size]\n" % [bc.lightened(0.3).to_html(false), n["name"]]
	out += "[color=#a6abc8]%s%s[/color]\n\n" % [TYPE_LABEL[n["type"]], ("   -   " + str(n["class"])) if n.has("class") else ""]
	var eff: Dictionary = n["effects"]
	if eff.has("skill"):
		out += "[color=#a6abc8]Grants skill:[/color]\n"
		var first := true
		for l in DB.ability_lines(eff["skill"], unit):
			var text: String = l[0] if l is Array else str(l)
			var col: Color = l[1] if l is Array and l.size() > 1 else Color(0.92, 0.94, 1.0)
			if first:
				out += "[font_size=20][color=#%s]%s[/color][/font_size]\n" % [col.to_html(false), text.replace("[", "[lb]")]
				first = false
			else:
				out += "[color=#%s]%s[/color]\n" % [col.to_html(false), Glossary.bbcode(text)]
	else:
		for para in DB.describe_effects(eff).split("\n"):
			if para != "":
				out += Glossary.bbcode(para) + "\n"
	return out

func open_detail(id: String) -> void:
	close_detail()
	if Game.main == null:
		return
	detail_id = id
	hover = ""
	_update_tip()
	Game.main.tip.hide_tip()
	_tip_shown = false
	var n: Dictionary = DB.TREE[id]
	# backdrop: click anywhere outside the panel to close
	var back := Control.new()
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_STOP
	back.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed:
			close_detail())
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.35)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.add_child(center)
	var panel := PanelContainer.new()
	var st := UiKit.panel_style(Color(0.04, 0.05, 0.12, 0.98))
	st.border_color = DB.BRANCH_COLORS[n["branch"]]
	st.set_border_width_all(3)
	st.content_margin_left = 22
	st.content_margin_right = 22
	st.content_margin_top = 18
	st.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", st)
	panel.custom_minimum_size = Vector2(560, 0)
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)
	var body := RichTextLabel.new()
	Glossary.hook(body)
	body.fit_content = true
	body.scroll_active = false
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(516, 0)
	body.add_theme_font_size_override("normal_font_size", 18)
	body.text = _detail_bbcode(id)
	v.add_child(body)
	var why := _status(id)
	if why != "":
		v.add_child(UiKit.label(why, 15, Color(0.65, 0.68, 0.8)))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 12)
	v.add_child(row)
	var buy := Button.new()
	buy.text = "Purchase  (1 point)"
	buy.custom_minimum_size = Vector2(190, 40)
	buy.disabled = not unit.can_allocate(id)
	buy.pressed.connect(func():
		if unit.can_allocate(detail_id):
			unit.allocate(detail_id)
			allocated.emit()
		close_detail())
	row.add_child(buy)
	var close := Button.new()
	close.text = "Close"
	close.custom_minimum_size = Vector2(120, 40)
	close.pressed.connect(close_detail)
	row.add_child(close)
	Game.main.ui_root.add_child(back)
	detail = back
	(buy if not buy.disabled else close).grab_focus.call_deferred()

func close_detail() -> void:
	if detail != null and is_instance_valid(detail):
		detail.queue_free()
	detail = null
	detail_id = ""
	Glossary.hide_term()

func _input(e: InputEvent) -> void:
	if detail != null and e is InputEventKey and e.pressed and e.is_action_pressed("ui_cancel"):
		close_detail()
		get_viewport().set_input_as_handled()

func _exit_tree() -> void:
	close_detail()
