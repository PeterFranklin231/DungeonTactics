class_name Portrait
extends Control
## A clickable headshot of a party member (used in the party menu header).

signal picked(index: int)

var unit: Unit
var index := 0
var selected := false
var hovered := false

func _init() -> void:
	custom_minimum_size = Vector2(64, 78)
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_entered.connect(func():
		hovered = true
		queue_redraw())
	mouse_exited.connect(func():
		hovered = false
		queue_redraw())

func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		picked.emit(index)

func _draw() -> void:
	if unit == null:
		return
	var box := Rect2(Vector2(4, 2), Vector2(56, 56))
	var bg := Color(0.12, 0.16, 0.38) if selected else Color(0.06, 0.08, 0.2)
	draw_rect(box, bg)
	# headshot: draw the character big and let the box crop it to head and shoulders
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# head-to-waist bust so helm, armour, gloves and weapons all show
	Art.person(self, Vector2(30, 17 + 1.75 * 32), 1.75, unit.visual_look(), 1, 1.0 if unit.is_alive() else 0.45)
	# re-cover what spilled outside the frame
	draw_rect(Rect2(0, 58, size.x, size.y - 58), Color(0.07, 0.1, 0.3))
	draw_rect(Rect2(0, 0, 4, 58), Color(0.07, 0.1, 0.3))
	draw_rect(Rect2(60, 0, size.x - 60, 58), Color(0.07, 0.1, 0.3))
	draw_rect(Rect2(0, 0, size.x, 2), Color(0.07, 0.1, 0.3))
	var border := Color(1, 0.85, 0.35) if selected else (Color(0.8, 0.85, 1) if hovered else Color(0.35, 0.4, 0.6))
	draw_rect(box, border, false, 3.0 if selected else 1.5)
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(0, 72), unit.name, HORIZONTAL_ALIGNMENT_CENTER, size.x, 12, Color(1, 0.95, 0.7) if selected else Color(0.8, 0.82, 0.9))
	if unit.skill_points > 0:
		draw_circle(Vector2(54, 9), 6, Color(1, 0.8, 0.2))
		draw_string(font, Vector2(48, 13), str(unit.skill_points), HORIZONTAL_ALIGNMENT_CENTER, 12, 11, Color(0.2, 0.1, 0))
	if not unit.is_alive():
		draw_string(font, Vector2(4, 54), "KO", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 0.4, 0.35))
