class_name Dialog
extends PanelContainer
## Message box with optional choices.  var i = await dialog.ask("text", ["A", "B"])
## A choice may also be a Dictionary: {text, tip: Array (InfoTip lines), disabled, color}.
## Keywords in the message are colour coded.

signal chosen(i: int)

var label: RichTextLabel
var scroll: ScrollContainer
var box: VBoxContainer

func _init() -> void:
	set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	offset_left = -420
	offset_right = 420
	offset_top = -250
	offset_bottom = -20
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	add_child(v)
	label = RichTextLabel.new()
	Glossary.hook(label)
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(800, 0)
	label.add_theme_font_size_override("normal_font_size", 17)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(label)
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	box = VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	visible = false

func _tip() -> InfoTip:
	return Game.main.tip if Game.main != null else null

func ask(text: String, choices: Array = []) -> int:
	if choices.is_empty():
		choices = ["OK"]
	Game.push_busy()
	label.text = InfoTip.bbcode(text)
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()
	var any_tip := false
	for ch0 in choices:
		if ch0 is Dictionary and ch0.has("tip"):
			any_tip = true
	# Leave room on the right for item tooltips.
	offset_left = -620 if any_tip else -420
	offset_right = 160 if any_tip else 420
	label.custom_minimum_size = Vector2(756 if any_tip else 800, 0)
	var first: Button = null
	for i in choices.size():
		var ch = choices[i]
		var b := Button.new()
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		var tip: Array = []
		if ch is Dictionary:
			b.text = str(ch.get("text", ""))
			b.disabled = ch.get("disabled", false)
			tip = ch.get("tip", [])
			if ch.has("color"):
				b.add_theme_color_override("font_color", ch["color"])
				b.add_theme_color_override("font_focus_color", (ch["color"] as Color).lightened(0.3))
				b.add_theme_color_override("font_hover_color", (ch["color"] as Color).lightened(0.3))
		else:
			b.text = str(ch)
		b.pressed.connect(func(): chosen.emit(i))
		b.mouse_entered.connect(func():
			if not b.disabled:
				b.grab_focus()
			elif tip.size() > 0 and _tip():
				_tip().show_lines(tip, b.get_global_rect()))
		b.focus_entered.connect(func():
			if _tip():
				if tip.size() > 0:
					_tip().show_lines(tip, b.get_global_rect())
				else:
					_tip().hide_tip())
		box.add_child(b)
		if first == null and not b.disabled:
			first = b
	scroll.custom_minimum_size = Vector2(0, mini(choices.size() * 36, 330))
	offset_top = -20
	reset_size()
	visible = true
	await get_tree().create_timer(0.12).timeout
	if first:
		first.grab_focus()
	var r: int = await chosen
	visible = false
	if _tip():
		_tip().hide_tip()
	Game.pop_busy()
	return r

func cancel() -> void:
	if visible and box.get_child_count() > 0:
		chosen.emit(box.get_child_count() - 1)
