class_name SystemMenu
extends Control
## The Esc menu: pauses the game. Resume, testing multipliers, controls, quit to title, quit game.

var panel: PanelContainer
var main_box: VBoxContainer
var settings_box: VBoxContainer
var controls_box: VBoxContainer
var confirm_box: VBoxContainer
var confirm_label: Label
var confirm_action := Callable()
var resume_btn: Button
var from_title := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	z_index = 90
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var c := CenterContainer.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(c)
	panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(420, 0)
	c.add_child(panel)
	var holder := VBoxContainer.new()
	panel.add_child(holder)

	# --- main page
	main_box = VBoxContainer.new()
	main_box.add_theme_constant_override("separation", 10)
	holder.add_child(main_box)
	var t := UiKit.label("Paused", 26, Color(1, 0.88, 0.5))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_box.add_child(t)
	resume_btn = _button(main_box, "Resume", close_menu)
	_button(main_box, "Testing Multipliers", func(): _show(settings_box))
	_button(main_box, "Controls", func(): _show(controls_box))
	_button(main_box, "Quit to Title", func(): _ask("Return to the title screen?\nProgress since you last rested at the campfire will be lost.", _quit_to_title))
	_button(main_box, "Quit Game", func(): _ask("Quit the game?\nProgress since you last rested at the campfire will be lost.", func(): get_tree().quit()))

	# --- testing multipliers
	settings_box = VBoxContainer.new()
	settings_box.add_theme_constant_override("separation", 10)
	holder.add_child(settings_box)
	var st := UiKit.label("Testing Multipliers", 22, Color(1, 0.88, 0.5))
	st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	settings_box.add_child(st)
	var note := UiKit.label("Cheats for testing. Saved separately from your game.", 13, Color(0.7, 0.74, 0.9))
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	settings_box.add_child(note)
	for row in [["xp", "Experience"], ["gold", "Gold"], ["item_qty", "Item quantity"], ["item_quality", "Item quality"]]:
		settings_box.add_child(_cheat_row(row[0], row[1]))
	_button(settings_box, "Reset all to 1x", func():
		for k in Game.cheats:
			Game.set_cheat(k, 1)
		_refresh_cheats())
	_button(settings_box, "< Back", func():
		if from_title:
			close_menu()
		else:
			_show(main_box))

	# --- controls
	controls_box = VBoxContainer.new()
	controls_box.add_theme_constant_override("separation", 8)
	holder.add_child(controls_box)
	var ct := UiKit.label("Controls", 22, Color(1, 0.88, 0.5))
	ct.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controls_box.add_child(ct)
	for l in [["Walk / use (home)", "Click"], ["Party menu", "Tab / M"], ["Build (home)", "B"], ["Roster (home)", "T"], ["Camera", "Drag pan, right-drag rotate, wheel zoom"],
			["Pause menu", "Esc"], ["Battle: back / cancel", "Esc / right click"], ["Battle: move, target", "Click a tile"],
			["Battle: facing", "Click a tile in that direction"],
			["Battle log", "Click the top bar"], ["Skill tree", "Drag to pan, wheel to zoom"]]:
		var h := HBoxContainer.new()
		var a := UiKit.label(l[0], 15, Color(0.75, 0.8, 0.95))
		a.custom_minimum_size = Vector2(170, 0)
		h.add_child(a)
		h.add_child(UiKit.label(l[1], 15))
		controls_box.add_child(h)
	_button(controls_box, "< Back", func(): _show(main_box))

	# --- confirmation
	confirm_box = VBoxContainer.new()
	confirm_box.add_theme_constant_override("separation", 12)
	holder.add_child(confirm_box)
	confirm_label = UiKit.label("", 16)
	confirm_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	confirm_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	confirm_box.add_child(confirm_label)
	_button(confirm_box, "Yes", func(): confirm_action.call())
	_button(confirm_box, "No", func(): _show(main_box))
	_show(main_box)

func _button(box: Container, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 38)
	b.pressed.connect(cb)
	box.add_child(b)
	return b

var cheat_buttons := {}   # key -> {value: Button}

func _cheat_row(key: String, label: String) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	var l := UiKit.label(label, 16)
	l.custom_minimum_size = Vector2(140, 0)
	h.add_child(l)
	cheat_buttons[key] = {}
	for v in Game.CHEAT_STEPS:
		var b := Button.new()
		b.text = "%dx" % v
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(52, 32)
		b.pressed.connect(func():
			Game.set_cheat(key, v)
			_refresh_cheats())
		h.add_child(b)
		cheat_buttons[key][v] = b
	return h

func _refresh_cheats() -> void:
	for key in cheat_buttons:
		for v in cheat_buttons[key]:
			var b: Button = cheat_buttons[key][v]
			b.set_pressed_no_signal(int(Game.cheats.get(key, 1)) == v)
			b.add_theme_color_override("font_color", Color(1, 0.88, 0.45) if b.button_pressed else Color(0.85, 0.87, 0.95))

func _show(box: Control) -> void:
	for b in [main_box, settings_box, controls_box, confirm_box]:
		b.visible = b == box
	_refresh_cheats()
	await get_tree().process_frame
	for ch in box.get_children():
		if ch is Button:
			ch.grab_focus()
			break

func _ask(text: String, action: Callable) -> void:
	confirm_label.text = text
	confirm_action = action
	_show(confirm_box)

## From the title screen only the multipliers page is offered.
func open_settings_only() -> void:
	from_title = true
	visible = true
	_show(settings_box)

func open_menu() -> void:
	from_title = false
	visible = true
	get_tree().paused = true
	Game.main.tip.hide_tip()
	Game.main.kwtip.hide_tip()
	_show(main_box)

func close_menu() -> void:
	visible = false
	if not from_title:
		get_tree().paused = false

func _quit_to_title() -> void:
	get_tree().paused = false
	Game.busy_count = 0
	get_tree().reload_current_scene()

func _input(e: InputEvent) -> void:
	if not visible:
		return
	if e is InputEventKey and e.pressed and not e.echo and e.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		if from_title or main_box.visible:
			close_menu()
		else:
			_show(main_box)
