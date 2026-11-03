class_name UiKit
extends RefCounted
## Shared UI theme (classic blue RPG windows).

static var _theme: Theme

static func panel_style(bg: Color = Color(0.07, 0.1, 0.3, 0.95)) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = Color(0.86, 0.9, 1.0)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(12)
	sb.shadow_color = Color(0, 0, 0, 0.4)
	sb.shadow_size = 4
	return sb

static func _btn(bg: Color, border: Color = Color(0, 0, 0, 0)) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(1 if border.a > 0 else 0)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	return sb

static func theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font_size = 16
	t.set_stylebox("panel", "PanelContainer", panel_style())
	t.set_stylebox("panel", "Panel", panel_style())
	t.set_stylebox("normal", "Button", _btn(Color(1, 1, 1, 0.04)))
	t.set_stylebox("hover", "Button", _btn(Color(0.3, 0.42, 0.85, 0.6)))
	t.set_stylebox("pressed", "Button", _btn(Color(0.4, 0.55, 1.0, 0.8)))
	t.set_stylebox("focus", "Button", _btn(Color(0.3, 0.42, 0.85, 0.35), Color(1, 0.95, 0.6)))
	t.set_stylebox("disabled", "Button", _btn(Color(0, 0, 0, 0.0)))
	t.set_color("font_color", "Button", Color(0.95, 0.96, 1.0))
	t.set_color("font_hover_color", "Button", Color(1, 1, 0.85))
	t.set_color("font_focus_color", "Button", Color(1, 1, 0.75))
	t.set_color("font_disabled_color", "Button", Color(0.55, 0.57, 0.68))
	t.set_color("font_color", "Label", Color(0.95, 0.96, 1.0))
	t.set_stylebox("panel", "TabContainer", panel_style())
	t.set_stylebox("tab_selected", "TabContainer", _btn(Color(0.3, 0.42, 0.85, 0.9)))
	t.set_stylebox("tab_unselected", "TabContainer", _btn(Color(0.1, 0.13, 0.35, 0.9)))
	t.set_stylebox("tab_hovered", "TabContainer", _btn(Color(0.2, 0.3, 0.7, 0.9)))
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.5)
	bg.set_corner_radius_all(3)
	t.set_stylebox("background", "ProgressBar", bg)
	t.set_stylebox("normal", "LineEdit", _btn(Color(0, 0, 0, 0.4), Color(0.8, 0.85, 1.0)))
	_theme = t
	return t

static func bar(col: Color, min_w: float = 90.0) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.custom_minimum_size = Vector2(min_w, 10)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var fill := StyleBoxFlat.new()
	fill.bg_color = col
	fill.set_corner_radius_all(3)
	b.add_theme_stylebox_override("fill", fill)
	return b

static func label(text: String, size: int = 16, col: Color = Color(0.95, 0.96, 1.0)) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l
