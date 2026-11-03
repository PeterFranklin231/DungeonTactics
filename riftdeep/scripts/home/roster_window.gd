class_name RosterWindow
extends PanelContainer
## Who goes through the portal (the party, up to 10) and who stays home in town to work.

var home: HomeMap
var party_box: VBoxContainer
var town_box: VBoxContainer
var party_title: Label
var town_title: Label
var info: Label

func _ready() -> void:
	visible = false
	set_anchors_preset(Control.PRESET_CENTER)
	offset_left = -470
	offset_right = 470
	offset_top = -280
	offset_bottom = 280
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	var t := UiKit.label("Roster", 24, Color(1, 0.88, 0.5))
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var close := Button.new()
	close.text = "Close (Esc)"
	close.pressed.connect(close_window)
	head.add_child(close)
	info = UiKit.label("The party goes through the portal. Everyone else stays in town and works: each worker produces their resource for every dungeon floor the party clears.", 14, Color(0.72, 0.76, 0.92))
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(info)
	var cols := HBoxContainer.new()
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_theme_constant_override("separation", 14)
	v.add_child(cols)
	for side in ["party", "town"]:
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cols.add_child(col)
		var lab := UiKit.label("", 18, Color(0.6, 0.85, 1.0) if side == "party" else Color(0.75, 0.95, 0.6))
		col.add_child(lab)
		var sc := ScrollContainer.new()
		sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
		sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		col.add_child(sc)
		var box := VBoxContainer.new()
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.add_theme_constant_override("separation", 4)
		sc.add_child(box)
		if side == "party":
			party_title = lab
			party_box = box
		else:
			town_title = lab
			town_box = box

func open() -> void:
	if visible:
		return
	Game.push_busy()
	visible = true
	refresh()

func close_window() -> void:
	if not visible:
		return
	visible = false
	Game.pop_busy()
	Game.main.tip.hide_tip()
	if home != null:
		home._place_people()

func _input(e: InputEvent) -> void:
	if visible and e is InputEventKey and e.pressed and not e.echo and e.keycode in [KEY_ESCAPE, KEY_T]:
		get_viewport().set_input_as_handled()
		close_window()

func _unit_tip(u: Unit) -> Array:
	return [["%s - Lv %d %s" % [u.name, u.level, u.cls], Color(1, 0.9, 0.55), false],
		"HP %d/%d   MP %d/%d" % [u.hp, u.max_hp(), u.mp, u.max_mp()], u.stat_line(),
		"Move %d   Jump %d" % [u.move_range(), u.jump_height()], "Skills: " + u.skill_names()]

func refresh() -> void:
	for b in [party_box, town_box]:
		for c in b.get_children():
			b.remove_child(c)
			c.queue_free()
	party_title.text = "Party  (%d / %d)" % [Game.party.size(), Game.MAX_PARTY]
	var made := {}
	for u in Game.town:
		var j: Dictionary = Game.JOBS.get(u.job, Game.JOBS[""])
		if j["res"] != "":
			made[j["res"]] = int(made.get(j["res"], 0)) + int(j["per_floor"])
	var prod := ", ".join(made.keys().map(func(k): return "+%d %s" % [made[k], k])) if not made.is_empty() else "nothing yet"
	town_title.text = "Town  (%d)   -   per floor cleared: %s" % [Game.town.size(), prod]
	for i in Game.party.size():
		var u: Unit = Game.party[i]
		var row := _row(u)
		var b := Button.new()
		b.text = "Stay home  >"
		b.disabled = i == 0
		b.tooltip_text = "The leader always goes." if i == 0 else ""
		b.pressed.connect(func():
			Game.party.erase(u)
			if u.job == "":
				u.job = "wood"
			Game.town.append(u)
			refresh())
		row.add_child(b)
		party_box.add_child(row)
	if Game.town.is_empty():
		town_box.add_child(UiKit.label("Nobody lives here yet. Recruit wanderers at the campfire.", 14, Color(0.65, 0.68, 0.8)))
	for u2 in Game.town:
		var row2 := _row(u2)
		var job := OptionButton.new()
		var ids: Array = Game.JOBS.keys()
		for k in ids:
			job.add_item(Game.JOBS[k]["name"])
		job.selected = maxi(0, ids.find(u2.job))
		job.item_selected.connect(func(idx: int):
			u2.job = ids[idx]
			refresh())
		row2.add_child(job)
		var b2 := Button.new()
		b2.text = "<  Join party"
		b2.disabled = Game.party.size() >= Game.MAX_PARTY
		b2.pressed.connect(func():
			Game.town.erase(u2)
			Game.party.append(u2)
			refresh())
		row2.add_child(b2)
		town_box.add_child(row2)

func _row(u: Unit) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var l := UiKit.label("%s   Lv %d %s" % [u.name, u.level, u.cls], 15)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.mouse_filter = Control.MOUSE_FILTER_STOP
	l.mouse_entered.connect(func(): Game.main.tip.show_lines(_unit_tip(u), l.get_global_rect()))
	l.mouse_exited.connect(func(): Game.main.tip.hide_tip())
	row.add_child(l)
	return row
