class_name InfoTip
extends Control
## Shared floating tooltip. Lines are [text, color, colorize_keywords] (or plain Strings).
## Keywords such as Hit / Melee / Shoot / Cast / Fire / Ice are coloured everywhere.

const MAX_W := 340.0
const FS := 15
const PAD := 12.0


var entries: Array = []      # wrapped: [[words:[[text,color]...]], ...]
var border := Color(0.86, 0.9, 1.0)

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	z_index = 100
	top_level = true

static func keyword_color(word: String):
	return Glossary.color_of_word(word)

## BBCode version of text with keywords as hoverable links (for RichTextLabels; see Glossary.hook).
static func bbcode(text: String) -> String:
	return Glossary.bbcode(text)

func _font() -> Font:
	return ThemeDB.fallback_font

func _wrap_line(text: String, col: Color, colorize: bool) -> Array:
	var font := _font()
	var space := font.get_string_size(" ", HORIZONTAL_ALIGNMENT_LEFT, -1, FS).x
	var rows: Array = []
	var row: Array = []
	var x := 0.0
	for word in text.split(" "):
		var ww := font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, FS).x
		if row.size() > 0 and x + space + ww > MAX_W:
			rows.append(row)
			row = []
			x = 0.0
		var c := col
		if colorize:
			var kc = keyword_color(word)
			if kc != null:
				c = kc
		row.append([word, c, ww])
		x += (space if row.size() > 1 else 0.0) + ww
	rows.append(row)
	return rows

## anchor: screen-space rect to sit beside (e.g. a button), or a point (size 0).
func show_lines(lines: Array, anchor: Rect2, border_col: Color = Color(0.86, 0.9, 1.0)) -> void:
	border = border_col
	entries.clear()
	for l in lines:
		var text: String
		var col := Color(0.92, 0.94, 1.0)
		var colorize := true
		if l is String:
			text = l
		else:
			text = l[0]
			if l.size() > 1:
				col = l[1]
			if l.size() > 2:
				colorize = l[2]
		entries.append_array(_wrap_line(Glossary.plain(text), col, colorize))
	var font := _font()
	var space := font.get_string_size(" ", HORIZONTAL_ALIGNMENT_LEFT, -1, FS).x
	var wmax := 0.0
	for row in entries:
		var x := 0.0
		for i in row.size():
			x += row[i][2] + (space if i > 0 else 0.0)
		wmax = maxf(wmax, x)
	size = Vector2(wmax + PAD * 2, entries.size() * (FS + 6) + PAD * 1.5)
	var vp := get_viewport_rect().size
	var pos: Vector2
	if anchor.size == Vector2.ZERO:
		pos = anchor.position + Vector2(18, 14)
	else:
		pos = Vector2(anchor.end.x + 8, anchor.position.y)
	if pos.x + size.x > vp.x - 4:
		pos.x = (anchor.position.x - size.x - 8) if anchor.size != Vector2.ZERO else (anchor.position.x - size.x - 18)
		if pos.x < 4 and anchor.size != Vector2.ZERO:
			# No room either side: go below (or above) the anchor instead.
			pos.x = anchor.position.x + 30
			pos.y = anchor.end.y + 4
			if pos.y + size.y > vp.y - 4:
				pos.y = anchor.position.y - size.y - 4
	pos.x = clampf(pos.x, 4, maxf(4, vp.x - size.x - 4))
	pos.y = clampf(pos.y, 4, maxf(4, vp.y - size.y - 4))
	position = pos
	visible = true
	queue_redraw()

func hide_tip() -> void:
	visible = false

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.04, 0.05, 0.12, 0.96))
	draw_rect(Rect2(Vector2.ZERO, size), border, false, 2.0)
	var font := _font()
	var space := font.get_string_size(" ", HORIZONTAL_ALIGNMENT_LEFT, -1, FS).x
	for r in entries.size():
		var x := PAD
		var y := PAD * 0.75 + (r + 1) * (FS + 6) - 6
		for word in entries[r]:
			draw_string(font, Vector2(x, y), word[0], HORIZONTAL_ALIGNMENT_LEFT, -1, FS, word[1])
			x += word[2] + space
