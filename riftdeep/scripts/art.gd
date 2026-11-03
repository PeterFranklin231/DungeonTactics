class_name Art
extends RefCounted
## Procedural drawing helpers (placeholder art - swap for sprites later).

static func pts(arr: Array) -> PackedVector2Array:
	return PackedVector2Array(arr)

static func ellipse_pts(c: Vector2, rx: float, ry: float, seg: int = 20, a0: float = 0.0, a1: float = TAU) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in seg + 1:
		var a := lerpf(a0, a1, float(i) / seg)
		out.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return out

static func ellipse(ci: CanvasItem, c: Vector2, rx: float, ry: float, col: Color) -> void:
	var p := ellipse_pts(c, rx, ry, 20)
	p.remove_at(p.size() - 1)
	ci.draw_colored_polygon(p, col)

static func shadow(ci: CanvasItem, c: Vector2, rx: float, ry: float, alpha: float = 1.0) -> void:
	ellipse(ci, c, rx, ry, Color(0, 0, 0, 0.28 * alpha))

static func a(col: Color, alpha: float) -> Color:
	return Color(col.r, col.g, col.b, col.a * alpha)

# ---------------------------------------------------------------------------
# Characters
# ---------------------------------------------------------------------------
static func person(ci: CanvasItem, feet: Vector2, s: float, look: Dictionary, facing: int = 1, alpha: float = 1.0, bob: float = 0.0) -> void:
	if look.has("gear"):
		geared(ci, feet, s, look, facing, alpha, bob)
		return
	var tunic: Color = a(look.get("tunic", Color(0.5, 0.5, 0.5)), alpha)
	var skin: Color = a(look.get("skin", Color(0.95, 0.8, 0.65)), alpha)
	var hair: Color = a(look.get("hair", Color(0.3, 0.2, 0.1)), alpha)
	var dark := a(tunic.darkened(0.45), 1.0)
	var f := float(facing)
	shadow(ci, feet, 10 * s, 4 * s, alpha)
	var by := feet + Vector2(0, -bob * s)
	# legs
	var leg_col := a(Color(0.25, 0.2, 0.18), alpha)
	var step := sin(bob * 3.0) * 2.0 * s if bob != 0.0 else 0.0
	ci.draw_rect(Rect2(by + Vector2(-5 * s + step, -12 * s), Vector2(4 * s, 12 * s)), leg_col)
	ci.draw_rect(Rect2(by + Vector2(1 * s - step, -12 * s), Vector2(4 * s, 12 * s)), leg_col)
	# body
	if look.get("robe", false) or look.get("hood", false):
		ci.draw_colored_polygon(pts([by + Vector2(-7 * s, -27 * s), by + Vector2(7 * s, -27 * s), by + Vector2(10 * s, -3 * s), by + Vector2(-10 * s, -3 * s)]), tunic)
	else:
		ci.draw_colored_polygon(pts([by + Vector2(-7 * s, -27 * s), by + Vector2(7 * s, -27 * s), by + Vector2(8 * s, -11 * s), by + Vector2(-8 * s, -11 * s)]), tunic)
		ci.draw_rect(Rect2(by + Vector2(-8 * s, -14 * s), Vector2(16 * s, 3 * s)), dark)
	# back arm
	ci.draw_line(by + Vector2(-f * 6 * s, -25 * s), by + Vector2(-f * 8 * s, -15 * s), dark, 3.5 * s)
	# head
	var head := by + Vector2(0, -32 * s)
	if look.get("hood", false):
		ci.draw_circle(head + Vector2(0, -1 * s), 7.5 * s, tunic.darkened(0.15))
		ci.draw_circle(head + Vector2(f * 1.5 * s, 1 * s), 5.0 * s, skin)
	else:
		ci.draw_circle(head, 6.3 * s, hair)
		ci.draw_circle(head + Vector2(f * 1.2 * s, 1.2 * s), 5.4 * s, skin)
	if look.get("bandana", false):
		ci.draw_rect(Rect2(head + Vector2(-6 * s, -4 * s), Vector2(12 * s, 3 * s)), a(Color(0.8, 0.12, 0.1), alpha))
		ci.draw_rect(Rect2(head + Vector2(-f * 3 * s - 3 * s, 1 * s), Vector2(6 * s, 4 * s)), a(Color(0.2, 0.15, 0.15), alpha))
	ci.draw_circle(head + Vector2(f * 3.2 * s, 0.5 * s), 0.9 * s, a(Color(0.1, 0.1, 0.1), alpha))
	# weapon + front arm
	var hand := by + Vector2(f * 8 * s, -16 * s)
	match look.get("weapon", "none"):
		"sword":
			ci.draw_line(hand, hand + Vector2(f * 6 * s, -18 * s), a(Color(0.85, 0.87, 0.92), alpha), 2.2 * s)
			ci.draw_line(hand + Vector2(-f * 3 * s, -2 * s), hand + Vector2(f * 3 * s, 1 * s), a(Color(0.55, 0.42, 0.2), alpha), 2.0 * s)
		"dagger":
			ci.draw_line(hand, hand + Vector2(f * 6 * s, -7 * s), a(Color(0.8, 0.82, 0.85), alpha), 2.0 * s)
		"fist":
			ci.draw_circle(hand, 2.8 * s, a(Color(0.85, 0.8, 0.7), alpha))
		"bow":
			var bc := hand + Vector2(f * 3 * s, -6 * s)
			var arc := ellipse_pts(bc, 5 * s, 13 * s, 10, -PI / 2, PI / 2) if facing > 0 else ellipse_pts(bc, 5 * s, 13 * s, 10, PI / 2, PI * 1.5)
			ci.draw_polyline(arc, a(Color(0.55, 0.35, 0.15), alpha), 2.0 * s)
			ci.draw_line(arc[0], arc[arc.size() - 1], a(Color(0.9, 0.9, 0.85), alpha), 1.0)
		"staff":
			ci.draw_line(hand + Vector2(0, 14 * s), hand + Vector2(0, -24 * s), a(Color(0.5, 0.33, 0.18), alpha), 2.2 * s)
			ci.draw_circle(hand + Vector2(0, -26 * s), 3.2 * s, a(look.get("orb", Color(0.6, 0.8, 1.0)), alpha))
	ci.draw_line(by + Vector2(f * 6 * s, -25 * s), hand, tunic.darkened(0.15), 3.5 * s)
	ci.draw_circle(hand, 1.8 * s, skin)

static func slime(ci: CanvasItem, feet: Vector2, s: float, col: Color, alpha: float = 1.0, t: float = 0.0) -> void:
	shadow(ci, feet, 16 * s, 5 * s, alpha)
	var squash := 1.0 + sin(t * 4.0) * 0.06
	var c := a(col, alpha)
	var dome := ellipse_pts(feet, 16 * s / squash, 15 * s * squash, 16, PI, TAU)
	dome.append(feet + Vector2(16 * s / squash, 0))
	ci.draw_colored_polygon(dome, c)
	ellipse(ci, feet + Vector2(-5 * s, -10 * s * squash), 4 * s, 3 * s, a(Color(1, 1, 1, 0.45), alpha))
	for ex in [-5.0, 4.0]:
		ci.draw_circle(feet + Vector2(ex * s + 3 * s, -7 * s * squash), 2.6 * s, a(Color.WHITE, alpha))
		ci.draw_circle(feet + Vector2(ex * s + 4 * s, -7 * s * squash), 1.4 * s, a(Color(0.05, 0.1, 0.05), alpha))

static func boar(ci: CanvasItem, feet: Vector2, s: float, col: Color, facing: int = 1, alpha: float = 1.0) -> void:
	var f := float(facing)
	shadow(ci, feet, 22 * s, 5 * s, alpha)
	var c := a(col, alpha)
	var dk := a(col.darkened(0.35), alpha)
	for lx in [-14.0, -7.0, 8.0, 14.0]:
		ci.draw_rect(Rect2(feet + Vector2(lx * f * s - 2 * s, -9 * s), Vector2(4 * s, 9 * s)), dk)
	ellipse(ci, feet + Vector2(0, -15 * s), 21 * s, 11 * s, c)
	# bristles
	ci.draw_colored_polygon(pts([feet + Vector2(-12 * f * s, -23 * s), feet + Vector2(8 * f * s, -26 * s), feet + Vector2(12 * f * s, -21 * s)]), dk)
	var head := feet + Vector2(19 * f * s, -14 * s)
	ellipse(ci, head, 9 * s, 8 * s, c)
	ellipse(ci, head + Vector2(7 * f * s, 3 * s), 4 * s, 3.4 * s, a(Color(0.85, 0.6, 0.55), alpha))
	ci.draw_colored_polygon(pts([head + Vector2(4 * f * s, 5 * s), head + Vector2(9 * f * s, -1 * s), head + Vector2(6 * f * s, 6 * s)]), a(Color(0.97, 0.95, 0.88), alpha))
	ci.draw_colored_polygon(pts([head + Vector2(-4 * f * s, -6 * s), head + Vector2(-1 * f * s, -13 * s), head + Vector2(1 * f * s, -6 * s)]), dk)
	ci.draw_circle(head + Vector2(3 * f * s, -2 * s), 1.3 * s, a(Color(0.1, 0.05, 0.02), alpha))

static func wolf(ci: CanvasItem, feet: Vector2, s: float, col: Color, facing: int = 1, alpha: float = 1.0) -> void:
	var f := float(facing)
	shadow(ci, feet, 22 * s, 5 * s, alpha)
	var c := a(col, alpha)
	var dk := a(col.darkened(0.4), alpha)
	for lx in [-13.0, -8.0, 9.0, 14.0]:
		ci.draw_line(feet + Vector2(lx * f * s, -12 * s), feet + Vector2(lx * f * s, 0), dk, 3.0 * s)
	ci.draw_colored_polygon(pts([feet + Vector2(-17 * f * s, -18 * s), feet + Vector2(-30 * f * s, -26 * s), feet + Vector2(-26 * f * s, -14 * s)]), c)
	ellipse(ci, feet + Vector2(0, -18 * s), 19 * s, 8 * s, c)
	ellipse(ci, feet + Vector2(-2 * f * s, -14 * s), 14 * s, 4 * s, a(col.lightened(0.25), alpha))
	var head := feet + Vector2(19 * f * s, -25 * s)
	ci.draw_circle(head, 7 * s, c)
	ci.draw_colored_polygon(pts([head + Vector2(3 * f * s, -3 * s), head + Vector2(14 * f * s, 2 * s), head + Vector2(3 * f * s, 5 * s)]), c)
	ci.draw_circle(head + Vector2(14 * f * s, 2 * s), 1.5 * s, a(Color(0.08, 0.08, 0.08), alpha))
	for ex in [-3.0, 2.0]:
		ci.draw_colored_polygon(pts([head + Vector2((ex - 2.5) * f * s, -4 * s), head + Vector2(ex * f * s, -13 * s), head + Vector2((ex + 2.5) * f * s, -4 * s)]), dk)
	ci.draw_circle(head + Vector2(3 * f * s, -1 * s), 1.4 * s, a(Color(1.0, 0.85, 0.2), alpha))

# ---------------------------------------------------------------------------
# Scenery
# ---------------------------------------------------------------------------
static func tree(ci: CanvasItem, p: Vector2, s: float, variant: int) -> void:
	shadow(ci, p + Vector2(0, 2), 13 * s, 5 * s)
	ci.draw_rect(Rect2(p + Vector2(-2.5 * s, -14 * s), Vector2(5 * s, 15 * s)), Color(0.4, 0.27, 0.15))
	var greens := [Color(0.22, 0.55, 0.22), Color(0.28, 0.6, 0.2), Color(0.2, 0.48, 0.25)]
	var g: Color = greens[variant % greens.size()]
	ci.draw_circle(p + Vector2(0, -24 * s), 12 * s, g.darkened(0.15))
	ci.draw_circle(p + Vector2(-6 * s, -20 * s), 8 * s, g)
	ci.draw_circle(p + Vector2(6 * s, -21 * s), 8 * s, g)
	ci.draw_circle(p + Vector2(-2 * s, -30 * s), 7 * s, g.lightened(0.12))

static func pine(ci: CanvasItem, p: Vector2, s: float, variant: int) -> void:
	shadow(ci, p + Vector2(0, 2), 11 * s, 4 * s)
	ci.draw_rect(Rect2(p + Vector2(-2 * s, -8 * s), Vector2(4 * s, 9 * s)), Color(0.35, 0.22, 0.12))
	var g := Color(0.13, 0.36, 0.2) if variant % 2 == 0 else Color(0.16, 0.4, 0.22)
	for i in 3:
		var y := -8.0 - i * 9.0
		var wd := 12.0 - i * 3.0
		ci.draw_colored_polygon(pts([p + Vector2(-wd * s, y * s), p + Vector2(wd * s, y * s), p + Vector2(0, (y - 16.0) * s)]), g.lightened(i * 0.05))

static func mountain(ci: CanvasItem, p: Vector2, s: float, variant: int) -> void:
	var hgt := (44.0 + (variant % 3) * 10.0) * s
	var base_w := 34.0 * s
	var peak := p + Vector2((variant % 5 - 2) * 2.0, -hgt)
	ci.draw_colored_polygon(pts([p + Vector2(-base_w, 4), peak, p + Vector2(0, 8)]), Color(0.52, 0.5, 0.47))
	ci.draw_colored_polygon(pts([p + Vector2(0, 8), peak, p + Vector2(base_w, 4)]), Color(0.38, 0.36, 0.34))
	var snow := 0.3
	ci.draw_colored_polygon(pts([peak.lerp(p + Vector2(-base_w, 4), snow), peak, peak.lerp(p + Vector2(base_w, 4), snow), peak.lerp(p + Vector2(0, 8), snow)]), Color(0.95, 0.96, 1.0))

static func iso_box(ci: CanvasItem, p: Vector2, hgt: float, top: Color, left: Color, right: Color, sx: bool, sy: bool, hw: float = 32.0, hh: float = 16.0) -> void:
	var T := p + Vector2(0, -hh)
	var R := p + Vector2(hw, 0)
	var B := p + Vector2(0, hh)
	var L := p + Vector2(-hw, 0)
	var up := Vector2(0, -hgt)
	if sx:
		ci.draw_colored_polygon(pts([R, B, B + up, R + up]), right)
	if sy:
		ci.draw_colored_polygon(pts([B, L, L + up, B + up]), left)
	ci.draw_colored_polygon(pts([T + up, R + up, B + up, L + up]), top)

## A quad on the +x (right-front) or +y (left-front) face of a tile box.
static func face_quad(p: Vector2, face: String, u0: float, u1: float, v0: float, v1: float, hw: float = 32.0, hh: float = 16.0) -> PackedVector2Array:
	var a0: Vector2
	var a1: Vector2
	if face == "x":
		a0 = p + Vector2(hw, 0)
		a1 = p + Vector2(0, hh)
	else:
		a0 = p + Vector2(0, hh)
		a1 = p + Vector2(-hw, 0)
	var b0 := a0.lerp(a1, u0)
	var b1 := a0.lerp(a1, u1)
	return pts([b0 + Vector2(0, -v0), b1 + Vector2(0, -v0), b1 + Vector2(0, -v1), b0 + Vector2(0, -v1)])

static func bat(ci: CanvasItem, feet: Vector2, s: float, col: Color, facing: int = 1, alpha: float = 1.0, t: float = 0.0) -> void:
	var f := float(facing)
	shadow(ci, feet, 12 * s, 4 * s, alpha * 0.7)
	var body := feet + Vector2(0, -26 * s + sin(t * 6.0) * 3.0 * s)
	var c := a(col, alpha)
	var dk := a(col.darkened(0.35), alpha)
	var flap := sin(t * 14.0) * 8.0 * s
	for side in [-1.0, 1.0]:
		var tip := body + Vector2(side * 22 * s, -6 * s - flap)
		ci.draw_colored_polygon(pts([body + Vector2(side * 3 * s, -3 * s), tip, body + Vector2(side * 16 * s, 2 * s - flap * 0.4), body + Vector2(side * 9 * s, 6 * s), body + Vector2(side * 3 * s, 3 * s)]), dk)
	ellipse(ci, body, 7 * s, 8 * s, c)
	for side2 in [-1.0, 1.0]:
		ci.draw_colored_polygon(pts([body + Vector2(side2 * 2 * s, -6 * s), body + Vector2(side2 * 5 * s, -13 * s), body + Vector2(side2 * 6 * s, -5 * s)]), c)
	ci.draw_circle(body + Vector2(-2.5 * s + f, -2 * s), 1.4 * s, a(Color(1, 0.3, 0.2), alpha))
	ci.draw_circle(body + Vector2(2.5 * s + f, -2 * s), 1.4 * s, a(Color(1, 0.3, 0.2), alpha))

static func spider(ci: CanvasItem, feet: Vector2, s: float, col: Color, facing: int = 1, alpha: float = 1.0, t: float = 0.0) -> void:
	var f := float(facing)
	shadow(ci, feet, 22 * s, 6 * s, alpha)
	var c := a(col, alpha)
	var leg := a(col.darkened(0.3), alpha)
	var body := feet + Vector2(-4 * f * s, -11 * s)
	for i in 4:
		var wig := sin(t * 8.0 + i) * 1.5 * s
		for side in [-1.0, 1.0]:
			var root := body + Vector2((i - 1.5) * 4 * s, 0)
			var knee := root + Vector2((i - 1.5) * 7 * s, -10 * s + wig) + Vector2(0, side * 2 * s)
			var foot := root + Vector2((i - 1.5) * 12 * s + side * 3 * s, 11 * s)
			ci.draw_polyline(pts([root, knee, foot]), leg, 2.2 * s)
	ellipse(ci, body + Vector2(-8 * f * s, -2 * s), 12 * s, 9 * s, c)
	ci.draw_line(body + Vector2(-12 * f * s, -8 * s), body + Vector2(-5 * f * s, -9 * s), a(Color(0.7, 0.15, 0.1), alpha), 2.0 * s)
	ellipse(ci, body + Vector2(7 * f * s, 0), 6 * s, 5 * s, c)
	for e in 3:
		ci.draw_circle(body + Vector2((9 + e * 1.6) * f * s, -2 * s + (e % 2) * 1.5 * s), 1.1 * s, a(Color(0.95, 0.2, 0.15), alpha))

static func boat(ci: CanvasItem, p: Vector2, s: float, facing: int = 1, alpha: float = 1.0) -> void:
	var f := float(facing)
	ellipse(ci, p + Vector2(0, 2), 26 * s, 8 * s, Color(1, 1, 1, 0.18 * alpha))
	var hull := a(Color(0.5, 0.32, 0.17), alpha)
	ci.draw_colored_polygon(pts([p + Vector2(-22 * f * s, -10 * s), p + Vector2(24 * f * s, -12 * s), p + Vector2(16 * f * s, 2 * s), p + Vector2(-16 * f * s, 2 * s)]), hull)
	ci.draw_line(p + Vector2(-22 * f * s, -10 * s), p + Vector2(24 * f * s, -12 * s), a(Color(0.35, 0.2, 0.1), alpha), 2.0 * s)
	ci.draw_line(p + Vector2(-2 * f * s, -10 * s), p + Vector2(-2 * f * s, -46 * s), a(Color(0.4, 0.27, 0.14), alpha), 2.5 * s)
	ci.draw_colored_polygon(pts([p + Vector2(-1 * f * s, -44 * s), p + Vector2(18 * f * s, -16 * s), p + Vector2(-1 * f * s, -15 * s)]), a(Color(0.96, 0.94, 0.86), alpha))

## Draws any enemy by its DB definition.
static func enemy(ci: CanvasItem, d: Dictionary, p: Vector2, s: float, facing: int = 1, alpha: float = 1.0, t: float = 0.0) -> void:
	var col: Color = d["color"]
	if d.get("aura", false):
		# corrupted by the darkness: a pulsing violet-black haze underfoot
		var pu := 0.5 + 0.5 * sin(t * 2.5)
		ellipse(ci, p + Vector2(0, -2 * s), 26 * s, 9 * s, Color(0.25, 0.05, 0.35, (0.28 + pu * 0.12) * alpha))
		ellipse(ci, p + Vector2(0, -2 * s), 16 * s, 5 * s, Color(0.05, 0.0, 0.08, 0.35 * alpha))
	match d["shape"]:
		"slime":
			slime(ci, p, s, col, alpha, t)
		"boar":
			boar(ci, p, s, col, facing, alpha)
		"wolf":
			wolf(ci, p, s, col, facing, alpha)
		"bat":
			bat(ci, p, s, col, facing, alpha, t)
			if d.get("spark", false) and fmod(t * 1.7, 1.0) < 0.35:
				var bp := p + Vector2(0, -26 * s + sin(t * 6.0) * 3.0 * s)
				for side in [-1.0, 1.0]:
					ci.draw_polyline(pts([bp + Vector2(side * 10 * s, -4 * s), bp + Vector2(side * 16 * s, -10 * s), bp + Vector2(side * 13 * s, -14 * s), bp + Vector2(side * 20 * s, -20 * s)]), a(Color(1.0, 0.95, 0.45), alpha), 1.4 * s)
		"fungus":
			fungus(ci, p, s, col, facing, alpha, t)
		"spider":
			spider(ci, p, s, col, facing, alpha, t)
		"bandit":
			person(ci, p, s * 1.1, {"tunic": col, "skin": Color(0.85, 0.68, 0.52), "hair": Color(0.15, 0.1, 0.05), "weapon": "dagger", "bandana": true}, facing, alpha)
		"bandit_mage":
			person(ci, p, s * 1.1, {"tunic": col, "skin": Color(0.85, 0.68, 0.52), "weapon": "staff", "hood": true, "orb": Color(1.0, 0.45, 0.1)}, facing, alpha)
		"zombie":
			zombie(ci, p, s, col, facing, alpha, t)
		"bear":
			bear(ci, p, s, col, facing, alpha, t)
		"bandit_archer":
			person(ci, p, s * 1.1, {"tunic": col, "skin": Color(0.85, 0.68, 0.52), "hair": Color(0.25, 0.15, 0.08), "weapon": "bow", "hood": true}, facing, alpha)
		"necromancer":
			necromancer(ci, p, s, col, facing, alpha, t)
		"crab":
			crab(ci, p, s, col, facing, alpha, t)
		"hermit":
			hermit(ci, p, s, col, facing, alpha, t)
		"eel":
			eel(ci, p, s, col, facing, alpha, t)
		"serpent":
			serpent(ci, p, s, col, facing, alpha, t)


# ---------------------------------------------------------------------------
# Party members: bare body + white underpants, with every worn piece drawn on top.
# ---------------------------------------------------------------------------
const RARITY_TRIM := {"magic": Color(0.45, 0.6, 1.0), "rare": Color(1.0, 0.88, 0.3), "unique": Color(1.0, 0.55, 0.15)}

## Base colour of a gear piece from its style and tier.
static func gear_color(style: String, tier: int) -> Color:
	match style:
		"str":   # iron -> polished steel
			return [Color(0.42, 0.43, 0.46), Color(0.55, 0.57, 0.6), Color(0.66, 0.68, 0.72), Color(0.78, 0.8, 0.84), Color(0.9, 0.92, 0.97)][tier]
		"dex":   # rough leather -> dark wyrmhide
			return [Color(0.5, 0.35, 0.2), Color(0.45, 0.3, 0.17), Color(0.36, 0.26, 0.17), Color(0.22, 0.24, 0.2), Color(0.18, 0.36, 0.28)][tier]
		"int":   # linen -> arcane silk
			return [Color(0.82, 0.77, 0.62), Color(0.55, 0.35, 0.7), Color(0.3, 0.35, 0.75), Color(0.45, 0.2, 0.65), Color(0.95, 0.92, 0.98)][tier]
	return Color(0.6, 0.6, 0.6)

static func _trim(piece: Dictionary, base: Color) -> Color:
	return RARITY_TRIM.get(piece.get("rarity", "normal"), base.darkened(0.35))

static func geared(ci: CanvasItem, feet: Vector2, s: float, look: Dictionary, facing: int = 1, alpha: float = 1.0, bob: float = 0.0) -> void:
	var g: Dictionary = look["gear"]
	var skin: Color = a(look.get("skin", Color(0.95, 0.8, 0.65)), alpha)
	var skin_dk := a(look.get("skin", Color(0.95, 0.8, 0.65)).darkened(0.18), alpha)
	var hair: Color = a(look.get("hair", Color(0.3, 0.2, 0.1)), alpha)
	var show_weapons: bool = look.get("weapon", "") != "none"
	var f := float(facing)
	shadow(ci, feet, 10 * s, 4 * s, alpha)
	var by := feet + Vector2(0, -bob * s)
	var step := sin(bob * 3.0) * 2.0 * s if bob != 0.0 else 0.0
	# --- legs (bare, or trousers matching the body armour)
	var legs := [[-4.5 + step / s, 0.0], [0.5 - step / s, 0.0]]
	var pants := Color(0, 0, 0, 0)
	var pants_style := ""
	if g.has("body"):
		pants_style = g["body"]["style"]
		var bcol := gear_color(pants_style, g["body"]["tier"])
		match pants_style:
			"str":   # chain leggings
				pants = a(bcol.darkened(0.18), alpha)
			"dex":   # leather trousers, a shade darker than the jerkin
				pants = a(bcol.darkened(0.3), alpha)
			_:       # soft cloth trousers under the robe
				pants = a(bcol.lerp(Color(0.35, 0.3, 0.28), 0.45), alpha)
	for l in legs:
		var left_leg: bool = l[0] < 0
		if pants.a > 0.0:
			var pc := pants.darkened(0.12) if left_leg else pants
			ci.draw_rect(Rect2(_pp(by, s, l[0], -12.5), Vector2(4 * s, 11.5 * s)), pc)
			ci.draw_rect(Rect2(_pp(by, s, l[0], -1.2), Vector2(4 * s, 1.2 * s)), skin_dk if left_leg else skin)
			match pants_style:
				"str":   # chain rings
					for yy in [-10.0, -7.5, -5.0, -2.5]:
						ci.draw_line(_pp(by, s, l[0], yy), _pp(by, s, l[0] + 4, yy), pc.lightened(0.18), 0.6 * s)
					ci.draw_circle(_pp(by, s, l[0] + 2, -6.5), 1.3 * s, pc.lightened(0.3))
				"dex":   # seam
					ci.draw_line(_pp(by, s, l[0] + 2, -12), _pp(by, s, l[0] + 2, -2), pc.darkened(0.25), 0.6 * s)
		else:
			ci.draw_rect(Rect2(_pp(by, s, l[0], -12), Vector2(4 * s, 12 * s)), skin_dk if left_leg else skin)
	# --- boots
	if g.has("boots"):
		var bp: Dictionary = g["boots"]
		var bc := a(gear_color(bp["style"], bp["tier"]), alpha)
		var top := -5.0 if bp["style"] == "int" else (-8.0 if bp["style"] == "str" else -7.0)
		for l in legs:
			ci.draw_rect(Rect2(_pp(by, s, l[0] - 0.5, top), Vector2(5 * s, (-top) * s)), bc)
			ci.draw_rect(Rect2(_pp(by, s, l[0] + (1.5 if facing > 0 else -1.5), -2), Vector2(4 * s, 2 * s)), bc.darkened(0.15))
			ci.draw_line(_pp(by, s, l[0] - 0.5, top), _pp(by, s, l[0] + 4.5, top), a(_trim(bp, bc), alpha), 1.2 * s)
	# --- torso (bare) + underpants
	ci.draw_colored_polygon(pts([_pp(by, s, -6, -27), _pp(by, s, 6, -27), _pp(by, s, 6.5, -13), _pp(by, s, -6.5, -13)]), skin)
	ci.draw_line(_pp(by, s, -2, -21), _pp(by, s, 2, -21), skin_dk, 0.8 * s)
	if pants.a > 0.0:
		# trouser seat covers the hips instead of the underpants
		ci.draw_colored_polygon(pts([_pp(by, s, -7, -14.5), _pp(by, s, 7, -14.5), _pp(by, s, 6.5, -9.5), _pp(by, s, -6.5, -9.5)]), pants)
	else:
		ci.draw_colored_polygon(pts([_pp(by, s, -7, -14.5), _pp(by, s, 7, -14.5), _pp(by, s, 6, -9), _pp(by, s, 0.8, -10), _pp(by, s, -0.8, -10), _pp(by, s, -6, -9)]), a(Color(0.97, 0.97, 0.95), alpha))
		ci.draw_line(_pp(by, s, -7, -14.5), _pp(by, s, 7, -14.5), a(Color(0.8, 0.8, 0.82), alpha), 0.9 * s)
	# --- body armour
	var sleeve := skin
	if g.has("body"):
		var bd: Dictionary = g["body"]
		var c := a(gear_color(bd["style"], bd["tier"]), alpha)
		var tr := a(_trim(bd, c), alpha)
		sleeve = c.darkened(0.08)
		match bd["style"]:
			"str":
				ci.draw_colored_polygon(pts([_pp(by, s, -8, -28), _pp(by, s, 8, -28), _pp(by, s, 8.5, -12), _pp(by, s, -8.5, -12)]), c)
				ci.draw_colored_polygon(pts([_pp(by, s, -8, -12), _pp(by, s, 8, -12), _pp(by, s, 7, -7.5), _pp(by, s, -7, -7.5)]), c.darkened(0.2))
				ci.draw_line(_pp(by, s, 0, -27), _pp(by, s, 0, -13), c.lightened(0.25), 1.2 * s)
				for sx in [-1.0, 1.0]:
					ci.draw_circle(_pp(by, s, sx * 7.5, -26.5), 3.4 * s, c.lightened(0.1))
				ci.draw_line(_pp(by, s, -8, -28), _pp(by, s, 8, -28), tr, 1.3 * s)
				if bd["tier"] >= 3:
					ci.draw_circle(_pp(by, s, 0, -22), 1.6 * s, a(Color(0.95, 0.8, 0.3), alpha))
			"dex":
				ci.draw_colored_polygon(pts([_pp(by, s, -7.5, -27.5), _pp(by, s, 7.5, -27.5), _pp(by, s, 8, -11), _pp(by, s, -8, -11)]), c)
				ci.draw_line(_pp(by, s, -6, -27), _pp(by, s, 6, -14), c.darkened(0.35), 1.2 * s)
				ci.draw_rect(Rect2(_pp(by, s, -8, -14), Vector2(16 * s, 2.5 * s)), c.darkened(0.4))
				ci.draw_rect(Rect2(_pp(by, s, -1, -14), Vector2(2 * s, 2.5 * s)), a(Color(0.85, 0.75, 0.4), alpha))
				ci.draw_line(_pp(by, s, -7.5, -27.5), _pp(by, s, 7.5, -27.5), tr, 1.2 * s)
				if bd["tier"] >= 2:
					for st in [-20.0, -17.0]:
						ci.draw_line(_pp(by, s, -7, st), _pp(by, s, 7, st), c.darkened(0.2), 0.8 * s)
			"int":
				ci.draw_colored_polygon(pts([_pp(by, s, -7, -28), _pp(by, s, 7, -28), _pp(by, s, 10.5, -1.5), _pp(by, s, -10.5, -1.5)]), c)
				ci.draw_line(_pp(by, s, -10.3, -2), _pp(by, s, 10.3, -2), tr, 1.5 * s)
				ci.draw_line(_pp(by, s, 0, -27), _pp(by, s, 0, -3), c.darkened(0.25), 0.9 * s)
				ci.draw_rect(Rect2(_pp(by, s, -8, -15), Vector2(16 * s, 2 * s)), c.darkened(0.35))
				ci.draw_colored_polygon(pts([_pp(by, s, -3.5, -28), _pp(by, s, 3.5, -28), _pp(by, s, 0, -23)]), tr)
	# --- off hand item (on the far side of the body)
	var back_hand := _pp(by, s, -f * 8, -15)
	ci.draw_line(_pp(by, s, -f * 6, -25), back_hand, sleeve.darkened(0.15), 3.5 * s)
	if show_weapons and g.has("off"):
		var off: Dictionary = g["off"]
		if off["kind"] == "shield":
			var sc := a(gear_color(off["style"], off["tier"]), alpha)
			var c0 := back_hand + Vector2(-f * 1.5 * s, -2 * s)
			match off["style"]:
				"str":
					ci.draw_colored_polygon(pts([c0 + Vector2(-6, -8) * s, c0 + Vector2(6, -8) * s, c0 + Vector2(6, 2) * s, c0 + Vector2(0, 10) * s, c0 + Vector2(-6, 2) * s]), sc)
					ci.draw_line(c0 + Vector2(0, -7) * s, c0 + Vector2(0, 8) * s, a(_trim(off, sc), alpha), 1.5 * s)
				"dex":
					ci.draw_circle(c0, 6.5 * s, sc)
					ci.draw_circle(c0, 2 * s, a(Color(0.7, 0.7, 0.72), alpha))
					ci.draw_arc(c0, 6.5 * s, 0, TAU, 16, a(_trim(off, sc), alpha), 1.2 * s)
				_:
					ci.draw_colored_polygon(pts([c0 + Vector2(0, -9) * s, c0 + Vector2(6, -2) * s, c0 + Vector2(0, 9) * s, c0 + Vector2(-6, -2) * s]), sc)
					ci.draw_circle(c0, 2.2 * s, a(Color(0.5, 0.85, 1.0), alpha))
		else:
			_weapon(ci, back_hand, s, off, -facing, alpha)
	if g.has("gloves"):
		var gl: Dictionary = g["gloves"]
		ci.draw_circle(back_hand, 2.2 * s, a(gear_color(gl["style"], gl["tier"]), alpha).darkened(0.1))
	else:
		ci.draw_circle(back_hand, 1.8 * s, skin_dk)
	# --- head
	var head := _pp(by, s, 0, -32)
	var helm_kind := ""
	if g.has("helm"):
		helm_kind = g["helm"]["style"]
	if helm_kind != "str":
		ci.draw_circle(head, 6.3 * s, hair)
	ci.draw_circle(head + Vector2(f * 1.2 * s, 1.2 * s), 5.4 * s, skin)
	ci.draw_circle(head + Vector2(f * 3.2 * s, 0.5 * s), 0.9 * s, a(Color(0.1, 0.1, 0.1), alpha))
	if g.has("helm"):
		var hp: Dictionary = g["helm"]
		var hc := a(gear_color(hp["style"], hp["tier"]), alpha)
		var htr := a(_trim(hp, hc), alpha)
		match hp["style"]:
			"str":
				ci.draw_colored_polygon(ellipse_pts(head + Vector2(0, 0.5 * s), 7 * s, 7.5 * s, 14, PI, TAU), hc)
				ci.draw_rect(Rect2(head + Vector2(-7 * s, 0), Vector2(14 * s, 2 * s)), hc.darkened(0.15))
				ci.draw_rect(Rect2(head + Vector2(f * 2 * s - 0.8 * s, 0), Vector2(1.6 * s, 4.5 * s)), hc.darkened(0.2))
				ci.draw_line(head + Vector2(-7 * s, 0), head + Vector2(7 * s, 0), htr, 1.0 * s)
				if hp["tier"] >= 3:
					ci.draw_colored_polygon(pts([head + Vector2(-f * 2, -7) * s, head + Vector2(-f * 9, -12) * s, head + Vector2(-f * 4, -5) * s]), a(Color(0.95, 0.95, 0.9), alpha))
			"dex":
				ci.draw_colored_polygon(ellipse_pts(head + Vector2(-f * 0.5 * s, 0), 7 * s, 7 * s, 14, PI, TAU), hc)
				ci.draw_colored_polygon(pts([head + Vector2(-f * 6, 0) * s, head + Vector2(-f * 7.5, 0) * s, head + Vector2(-f * 5, 6) * s]), hc)
				ci.draw_line(head + Vector2(-7 * s, 0), head + Vector2(6 * s, 0), htr, 1.0 * s)
			_:
				if hp["tier"] == 0:
					ci.draw_colored_polygon(ellipse_pts(head + Vector2(0, -0.5 * s), 7.5 * s, 7.5 * s, 14, PI * 0.95, TAU * 1.02), hc)
				else:
					ci.draw_line(head + Vector2(-6 * s, -2.5 * s), head + Vector2(6 * s, -2.5 * s), a(Color(0.95, 0.8, 0.3), alpha), 1.6 * s)
					ci.draw_circle(head + Vector2(f * 3 * s, -3 * s), 1.5 * s, htr if hp["rarity"] != "normal" else a(Color(0.5, 0.8, 1.0), alpha))
					if hp["tier"] >= 3:
						ci.draw_colored_polygon(pts([head + Vector2(-2, -3) * s, head + Vector2(0, -8) * s, head + Vector2(2, -3) * s]), a(Color(0.95, 0.8, 0.3), alpha))
	# --- main weapon and front arm
	var hand := _pp(by, s, f * 8, -16)
	if show_weapons and g.has("main"):
		_weapon(ci, hand, s, g["main"], facing, alpha)
	ci.draw_line(_pp(by, s, f * 6, -25), hand, sleeve, 3.5 * s)
	if g.has("gloves"):
		var gl2: Dictionary = g["gloves"]
		var gc := a(gear_color(gl2["style"], gl2["tier"]), alpha)
		ci.draw_line(hand + Vector2(-f * 2.5 * s, -2.5 * s), hand, gc, 3.8 * s)
		ci.draw_circle(hand, 2.3 * s, gc)
		ci.draw_circle(hand + Vector2(-f * 2.4 * s, -2.4 * s), 1.0 * s, a(_trim(gl2, gc), alpha))
	else:
		ci.draw_circle(hand, 1.8 * s, skin)

static func _pp(by: Vector2, s: float, x: float, y: float) -> Vector2:
	return by + Vector2(x * s, y * s)

## Weapon held at a hand position. piece: {kind, style, tier, rarity}
static func _weapon(ci: CanvasItem, hand: Vector2, s: float, piece: Dictionary, facing: int, alpha: float) -> void:
	var f := float(facing)
	var t: int = piece.get("tier", 0)
	var steel := a(Color(0.78, 0.8, 0.86).lightened(t * 0.04), alpha)
	var wood := a(Color(0.5, 0.33, 0.18), alpha)
	var tr := a(RARITY_TRIM.get(piece.get("rarity", "normal"), Color(0.7, 0.55, 0.2)), alpha)
	match piece.get("kind", ""):
		"sword":
			var ln := 16.0 + t * 1.5
			ci.draw_line(hand, hand + Vector2(f * 6, -ln) * s, steel, 2.2 * s)
			ci.draw_line(hand + Vector2(-f * 3, -2) * s, hand + Vector2(f * 3, 1) * s, tr, 2.0 * s)
		"axe":
			ci.draw_line(hand + Vector2(0, 6) * s, hand + Vector2(f * 4, -20) * s, wood, 2.4 * s)
			ci.draw_colored_polygon(pts([hand + Vector2(f * 3, -19) * s, hand + Vector2(f * 11, -22) * s, hand + Vector2(f * 10, -12) * s, hand + Vector2(f * 4, -14) * s]), steel)
			ci.draw_line(hand + Vector2(f * 11, -22) * s, hand + Vector2(f * 10, -12) * s, tr, 1.0 * s)
		"dagger":
			ci.draw_line(hand, hand + Vector2(f * 6, -7) * s, steel, 2.0 * s)
			ci.draw_line(hand + Vector2(-f * 1.5, -1.5) * s, hand + Vector2(f * 1.5, 1.5) * s, tr, 1.6 * s)
		"fist":
			ci.draw_circle(hand, (2.6 + t * 0.15) * s, steel)
			for kn in 3:
				ci.draw_circle(hand + Vector2(f * 2.2, -1.8 + kn * 1.8) * s, 0.9 * s, tr)
		"bow":
			var bc := hand + Vector2(f * 3, -6) * s
			var arc := ellipse_pts(bc, 5 * s, 13 * s, 10, -PI / 2, PI / 2) if facing > 0 else ellipse_pts(bc, 5 * s, 13 * s, 10, PI / 2, PI * 1.5)
			ci.draw_polyline(arc, wood.lightened(t * 0.05), 2.0 * s)
			ci.draw_line(arc[0], arc[arc.size() - 1], a(Color(0.9, 0.9, 0.85), alpha), 1.0)
			ci.draw_circle(arc[arc.size() / 2], 1.2 * s, tr)
		"wand":
			ci.draw_line(hand + Vector2(0, 2) * s, hand + Vector2(f * 4, -10) * s, wood.lightened(0.15), 1.8 * s)
			ci.draw_circle(hand + Vector2(f * 4.5, -11) * s, 2.0 * s, tr if piece.get("rarity", "normal") != "normal" else a(Color(0.6, 0.85, 1.0), alpha))
		"staff":
			ci.draw_line(hand + Vector2(0, 14) * s, hand + Vector2(0, -24) * s, wood, 2.2 * s)
			ci.draw_circle(hand + Vector2(0, -26) * s, 3.2 * s, tr if piece.get("rarity", "normal") != "normal" else a(Color(1.0, 0.6, 0.2), alpha))


static func fungus(ci: CanvasItem, feet: Vector2, s: float, col: Color, facing: int = 1, alpha: float = 1.0, t: float = 0.0) -> void:
	var f := float(facing)
	var breathe := 1.0 + sin(t * 1.6) * 0.04
	shadow(ci, feet, 20 * s, 6 * s, alpha)
	# stubby fat stalk with a sleepy face
	var stalk := a(Color(0.9, 0.86, 0.74), alpha)
	ci.draw_colored_polygon(pts([feet + Vector2(-13, 0) * s, feet + Vector2(13, 0) * s, feet + Vector2(11, -20) * s * breathe, feet + Vector2(-11, -20) * s * breathe]), stalk)
	ellipse(ci, feet + Vector2(0, -1) * s, 13 * s, 4 * s, stalk.darkened(0.12))
	for ex in [-4.0, 4.0]:
		ci.draw_line(feet + Vector2(ex - 2 + f, -12) * s, feet + Vector2(ex + 2 + f, -12) * s, a(Color(0.2, 0.15, 0.15), alpha), 1.4 * s)
	ci.draw_arc(feet + Vector2(f, -8) * s, 3 * s, 0.2, PI - 0.2, 8, a(Color(0.3, 0.15, 0.15), alpha), 1.2 * s)
	# big domed cap with spots
	var cap := a(col, alpha)
	var dome := ellipse_pts(feet + Vector2(0, -20) * s * breathe, 24 * s, 17 * s, 18, PI, TAU)
	ci.draw_colored_polygon(dome, cap)
	ci.draw_colored_polygon(ellipse_pts(feet + Vector2(0, -20) * s * breathe, 24 * s, 4 * s, 14, 0, PI), cap.darkened(0.3))
	for sp in [Vector2(-12, -28), Vector2(2, -33), Vector2(13, -26), Vector2(-3, -24), Vector2(-17, -22)]:
		ellipse(ci, feet + sp * s * breathe, 3.2 * s, 2.2 * s, a(Color(0.96, 0.92, 0.6), alpha))
	# drifting spores
	for k in 4:
		var ph := fmod(t * 0.5 + k * 0.25, 1.0)
		ci.draw_circle(feet + Vector2(sin(k * 2.1 + t) * 16, -36 - ph * 20) * s, (1.6 - ph) * s, a(Color(0.6, 0.9, 0.35, 0.7 * (1.0 - ph)), alpha))


# ---------------------------------------------------------------------------
# The Blight
# ---------------------------------------------------------------------------
static func dead_tree(ci: CanvasItem, p: Vector2, s: float, variant: int) -> void:
	shadow(ci, p + Vector2(0, 2), 10 * s, 4 * s)
	var bark := Color(0.3, 0.27, 0.27).darkened((variant % 3) * 0.08)
	var lean := float(variant % 5 - 2) * 1.5
	var top := p + Vector2(lean * s, -34 * s)
	ci.draw_colored_polygon(pts([p + Vector2(-3.5 * s, 0), p + Vector2(3.5 * s, 0), top + Vector2(1.2 * s, 0), top + Vector2(-1.2 * s, 0)]), bark)
	var branches := [[0.45, -1.0, 12.0, -9.0], [0.6, 1.0, 11.0, -12.0], [0.8, -1.0, 8.0, -8.0], [0.92, 1.0, 7.0, -6.0]]
	for b in branches:
		var root := p.lerp(top, b[0])
		var side: float = b[1] * (1.0 if variant % 2 == 0 else -1.0)
		var tip := root + Vector2(side * b[2] * s, b[3] * s)
		ci.draw_line(root, tip, bark, 2.0 * s)
		ci.draw_line(tip, tip + Vector2(side * 3 * s, -4 * s), bark, 1.2 * s)
		ci.draw_line(root.lerp(tip, 0.6), root.lerp(tip, 0.6) + Vector2(side * -1 * s, -5 * s), bark, 1.0 * s)

static func gravestone(ci: CanvasItem, p: Vector2, s: float, variant: int) -> void:
	shadow(ci, p + Vector2(0, 2), 8 * s, 3 * s)
	var st := Color(0.5, 0.5, 0.52).darkened((variant % 3) * 0.1)
	var tilt := float(variant % 3 - 1) * 2.0 * s
	ci.draw_colored_polygon(pts([p + Vector2(-5 * s, 0), p + Vector2(5 * s, 0), p + Vector2(5 * s + tilt, -10 * s), p + Vector2(-5 * s + tilt, -10 * s)]), st)
	ellipse(ci, p + Vector2(tilt, -10 * s), 5 * s, 4 * s, st)
	ci.draw_line(p + Vector2(tilt, -12 * s), p + Vector2(tilt * 0.6, -5 * s), st.darkened(0.35), 1.0 * s)
	ci.draw_line(p + Vector2(-2.5 * s + tilt, -9.5 * s), p + Vector2(2.5 * s + tilt, -9.5 * s), st.darkened(0.35), 1.0 * s)

static func zombie(ci: CanvasItem, feet: Vector2, s: float, col: Color, facing: int = 1, alpha: float = 1.0, t: float = 0.0) -> void:
	var f := float(facing)
	shadow(ci, feet, 10 * s, 4 * s, alpha)
	var sway := sin(t * 2.5) * 1.5 * s
	var skin := a(col, alpha)
	var skin_dk := a(col.darkened(0.25), alpha)
	var rag := a(Color(0.35, 0.3, 0.32), alpha)
	var by := feet + Vector2(sway * 0.3, 0)
	# legs (one dragging)
	ci.draw_rect(Rect2(by + Vector2(-5 * s, -12 * s), Vector2(4 * s, 12 * s)), skin_dk)
	ci.draw_rect(Rect2(by + Vector2(1 * s, -12 * s), Vector2(4 * s, 11 * s)), rag)
	# torso, hunched forward
	var lean := Vector2(3 * f * s, 0)
	ci.draw_colored_polygon(pts([by + Vector2(-6.5 * s, -13 * s), by + Vector2(6.5 * s, -13 * s), by + lean + Vector2(6 * s, -27 * s), by + lean + Vector2(-6 * s, -27 * s)]), rag)
	ci.draw_colored_polygon(pts([by + Vector2(-2 * s, -14 * s), by + Vector2(3 * s, -14 * s), by + lean + Vector2(2 * s, -22 * s)]), skin_dk)
	ci.draw_line(by + lean + Vector2(-5 * s, -18 * s), by + lean + Vector2(4 * s, -20 * s), a(Color(0.2, 0.15, 0.15), alpha), 1.0 * s)
	# arms reaching forward
	for side in [0.0, 1.0]:
		var sh := by + lean + Vector2((-3 + side * 5) * s, -25 * s)
		var hand := sh + Vector2(13 * f * s, (2 + side * 3) * s + sway)
		ci.draw_line(sh, hand, skin if side > 0 else skin_dk, 3.2 * s)
		ci.draw_circle(hand, 2.0 * s, skin)
	# head, tilted
	var head := by + lean + Vector2(2 * f * s, -32 * s)
	ci.draw_circle(head, 5.5 * s, skin)
	ci.draw_line(head + Vector2(-4 * s, -3 * s), head + Vector2(3 * s, -5 * s), a(Color(0.25, 0.2, 0.15), alpha), 1.5 * s)
	ci.draw_circle(head + Vector2(2 * f * s, -1 * s), 1.3 * s, a(Color(0.95, 0.9, 0.4), alpha))
	ci.draw_circle(head + Vector2(-1 * f * s, -1.5 * s), 1.0 * s, a(Color(0.95, 0.9, 0.4), alpha))
	ci.draw_line(head + Vector2(-1 * s, 2.5 * s), head + Vector2(3 * f * s, 2 * s), a(Color(0.2, 0.05, 0.05), alpha), 1.2 * s)

static func necromancer(ci: CanvasItem, feet: Vector2, s: float, col: Color, facing: int = 1, alpha: float = 1.0, t: float = 0.0) -> void:
	var f := float(facing)
	var hover := sin(t * 2.0) * 1.5 * s
	shadow(ci, feet, 10 * s, 4 * s, alpha)
	var robe := a(col, alpha)
	var robe_lt := a(col.lightened(0.15), alpha)
	var by := feet + Vector2(0, -hover)
	# tattered robe
	ci.draw_colored_polygon(pts([by + Vector2(-9 * s, 0), by + Vector2(-6 * s, -2 * s), by + Vector2(-3 * s, 0), by + Vector2(0, -2 * s), by + Vector2(3 * s, 0), by + Vector2(6 * s, -2 * s), by + Vector2(9 * s, 0), by + Vector2(6 * s, -28 * s), by + Vector2(-6 * s, -28 * s)]), robe)
	ci.draw_line(by + Vector2(0, -26 * s), by + Vector2(0, -3 * s), robe_lt, 1.0 * s)
	# bone trim
	ci.draw_line(by + Vector2(-6 * s, -27 * s), by + Vector2(6 * s, -27 * s), a(Color(0.9, 0.88, 0.8), alpha), 1.4 * s)
	# hood with a skull face
	var head := by + Vector2(1 * f * s, -33 * s)
	ci.draw_colored_polygon(pts([head + Vector2(-7 * s, 4 * s), head + Vector2(7 * s, 4 * s), head + Vector2(5 * s, -5 * s), head + Vector2(-1 * f * s, -10 * s), head + Vector2(-5 * s, -5 * s)]), robe)
	ellipse(ci, head + Vector2(1 * f * s, 0), 3.8 * s, 4.2 * s, a(Color(0.88, 0.86, 0.78), alpha))
	var glow := a(Color(0.4, 1.0, 0.55), alpha)
	ci.draw_circle(head + Vector2((1 * f - 1.5) * s, -0.5 * s), 1.0 * s, glow)
	ci.draw_circle(head + Vector2((1 * f + 1.5) * s, -0.5 * s), 1.0 * s, glow)
	# staff with a skull and green flame
	var hand := by + Vector2(9 * f * s, -18 * s)
	ci.draw_line(hand + Vector2(0, 18 * s), hand + Vector2(0, -22 * s), a(Color(0.25, 0.2, 0.18), alpha), 2.0 * s)
	ci.draw_circle(hand + Vector2(0, -24 * s), 3.2 * s, a(Color(0.88, 0.86, 0.78), alpha))
	var fl := 3.0 + sin(t * 9.0) * 1.0
	ci.draw_circle(hand + Vector2(0, -29 * s), fl * s, a(Color(0.35, 1.0, 0.5, 0.35), alpha))
	ci.draw_circle(hand + Vector2(0, -29 * s), fl * 0.5 * s, a(Color(0.7, 1.0, 0.75), alpha))
	ci.draw_line(by + Vector2(4 * f * s, -24 * s), hand, robe, 3.0 * s)

# ---------------------------------------------------------------------------
# Sea creatures (drawn half in the water)
# ---------------------------------------------------------------------------
static func _ripples(ci: CanvasItem, p: Vector2, rx: float, s: float, alpha: float, t: float) -> void:
	for i in 2:
		var k := fposmod(t * 0.6 + i * 0.5, 1.0)
		var r := rx * (0.8 + k * 0.6)
		ci.draw_arc(p, r * s, 0, TAU, 24, Color(1, 1, 1, 0.35 * (1.0 - k) * alpha), 1.2 * s)
	ellipse(ci, p, rx * s, rx * 0.32 * s, Color(0.1, 0.25, 0.45, 0.35 * alpha))

static func crab(ci: CanvasItem, feet: Vector2, s: float, col: Color, facing: int = 1, alpha: float = 1.0, t: float = 0.0) -> void:
	var f := float(facing)
	shadow(ci, feet, 16 * s, 5 * s, alpha)
	var c := a(col, alpha)
	var dk := a(col.darkened(0.3), alpha)
	var body := feet + Vector2(0, -9 * s)
	for i in 3:
		for side in [-1.0, 1.0]:
			var root := body + Vector2(side * 8 * s, (i - 1) * 2 * s)
			var knee := root + Vector2(side * 6 * s, -4 * s + sin(t * 7.0 + i) * s)
			ci.draw_polyline(pts([root, knee, knee + Vector2(side * 3 * s, 9 * s)]), dk, 1.8 * s)
	ellipse(ci, body, 13 * s, 8 * s, c)
	ellipse(ci, body + Vector2(0, -2 * s), 10 * s, 5 * s, a(col.lightened(0.12), alpha))
	# claws
	var snip := absf(sin(t * 3.0)) * 3.0 * s
	for side2 in [-1.0, 1.0]:
		var arm := body + Vector2(side2 * 6 * s + f * 8 * s, -6 * s)
		var claw := arm + Vector2(f * 8 * s, -6 * s)
		ci.draw_line(arm, claw, c, 3.0 * s)
		ellipse(ci, claw, 5 * s, 3.5 * s, c)
		ci.draw_line(claw + Vector2(f * 3 * s, 0), claw + Vector2(f * 8 * s, -2 * s - snip), dk, 2.0 * s)
		ci.draw_line(claw + Vector2(f * 3 * s, 1 * s), claw + Vector2(f * 8 * s, 2 * s), dk, 2.0 * s)
	# eye stalks
	for e in [-2.5, 2.5]:
		var base := body + Vector2(e * s + f * 4 * s, -7 * s)
		ci.draw_line(base, base + Vector2(0, -5 * s), dk, 1.2 * s)
		ci.draw_circle(base + Vector2(0, -6 * s), 1.6 * s, a(Color(0.1, 0.08, 0.08), alpha))

static func eel(ci: CanvasItem, feet: Vector2, s: float, col: Color, facing: int = 1, alpha: float = 1.0, t: float = 0.0) -> void:
	var f := float(facing)
	_ripples(ci, feet, 14, s, alpha, t)
	var c := a(col, alpha)
	var belly := a(col.lightened(0.35), alpha)
	var pts_arr := PackedVector2Array()
	for i in 9:
		var k := float(i) / 8.0
		pts_arr.append(feet + Vector2((-6 + k * 10) * f * s + sin(t * 4.0 + k * 5.0) * 4 * s * (1.0 - k), -k * 34 * s))
	ci.draw_polyline(pts_arr, c, 7 * s)
	ci.draw_polyline(pts_arr, belly, 2 * s)
	var head := pts_arr[pts_arr.size() - 1]
	ellipse(ci, head + Vector2(3 * f * s, -1 * s), 7 * s, 4.5 * s, c)
	ci.draw_circle(head + Vector2(5 * f * s, -3 * s), 1.4 * s, a(Color(1, 0.95, 0.3), alpha))
	ci.draw_line(head + Vector2(4 * f * s, 1.5 * s), head + Vector2(10 * f * s, 0.5 * s), a(Color(0.1, 0.1, 0.1), alpha), 1.0 * s)
	# fin and a crackle of lightning
	ci.draw_colored_polygon(pts([head + Vector2(-2 * f * s, -4 * s), head + Vector2(-8 * f * s, -9 * s), head + Vector2(-7 * f * s, -2 * s)]), a(col.darkened(0.2), alpha))
	if fmod(t, 1.4) < 0.25:
		ci.draw_polyline(pts([head + Vector2(0, -8 * s), head + Vector2(3 * s, -12 * s), head + Vector2(-1 * s, -15 * s), head + Vector2(2 * s, -19 * s)]), a(Color(1, 0.95, 0.4), alpha), 1.3 * s)

static func serpent(ci: CanvasItem, feet: Vector2, s: float, col: Color, facing: int = 1, alpha: float = 1.0, t: float = 0.0) -> void:
	var f := float(facing)
	var c := a(col, alpha)
	var dk := a(col.darkened(0.3), alpha)
	# a coil breaking the surface behind
	var coil := feet + Vector2(-18 * f * s, -2 * s)
	_ripples(ci, coil, 12, s, alpha, t + 0.3)
	ci.draw_arc(coil + Vector2(0, -2 * s), 9 * s, PI, TAU, 16, c, 6 * s)
	_ripples(ci, feet, 16, s, alpha, t)
	# neck rising from the water
	var neck := PackedVector2Array()
	for i in 10:
		var k := float(i) / 9.0
		neck.append(feet + Vector2((sin(k * 2.6) * 8 + k * 6) * f * s + sin(t * 2.0 + k * 3.0) * 2 * s, -k * 46 * s))
	ci.draw_polyline(neck, c, 10 * s)
	ci.draw_polyline(neck, a(col.lightened(0.3), alpha), 3 * s)
	var head := neck[neck.size() - 1]
	# crest
	for i in 3:
		ci.draw_colored_polygon(pts([head + Vector2((-4 - i * 4) * f * s, -4 * s), head + Vector2((-6 - i * 4) * f * s, -12 * s), head + Vector2((-9 - i * 4) * f * s, -3 * s)]), dk)
	ellipse(ci, head + Vector2(5 * f * s, 0), 10 * s, 6 * s, c)
	ci.draw_colored_polygon(pts([head + Vector2(8 * f * s, 2 * s), head + Vector2(17 * f * s, 3 * s), head + Vector2(9 * f * s, 6 * s)]), dk)
	ci.draw_circle(head + Vector2(7 * f * s, -2 * s), 1.8 * s, a(Color(1, 0.4, 0.2), alpha))


static func bear(ci: CanvasItem, feet: Vector2, s: float, col: Color, facing: int = 1, alpha: float = 1.0, t: float = 0.0) -> void:
	var f := float(facing)
	shadow(ci, feet, 24 * s, 6 * s, alpha)
	var c := a(col, alpha)
	var dk := a(col.darkened(0.3), alpha)
	var breathe := sin(t * 2.0) * 0.6 * s
	# legs
	for lx in [-12.0, -5.0, 6.0, 12.0]:
		ci.draw_rect(Rect2(feet + Vector2(lx * f * s - 3 * s, -10 * s), Vector2(6 * s, 10 * s)), dk if lx < 0 else c)
	# body with a shoulder hump
	ellipse(ci, feet + Vector2(-2 * f * s, -17 * s), 19 * s, 11 * s + breathe, c)
	ellipse(ci, feet + Vector2(6 * f * s, -23 * s), 9 * s, 7 * s, c)
	# head and snout
	var head := feet + Vector2(17 * f * s, -19 * s)
	ellipse(ci, head, 8 * s, 7 * s, c)
	ellipse(ci, head + Vector2(6 * f * s, 2 * s), 5 * s, 3.5 * s, a(col.lightened(0.15), alpha))
	ci.draw_circle(head + Vector2(10 * f * s, 1.5 * s), 1.6 * s, a(Color(0.08, 0.06, 0.05), alpha))
	ci.draw_circle(head + Vector2(-4 * f * s, -6 * s), 2.6 * s, c)
	ci.draw_circle(head + Vector2(3 * f * s, -6.5 * s), 2.6 * s, c)
	ci.draw_circle(head + Vector2(3 * f * s, -2 * s), 1.2 * s, a(Color(0.08, 0.05, 0.05), alpha))


## Malgrave's fortress, raised over fallen Riverbend.
static func fortress(ci: CanvasItem, p: Vector2, s: float, t: float = 0.0) -> void:
	shadow(ci, p + Vector2(0, 4), 34 * s, 10 * s)
	var stone := Color(0.2, 0.18, 0.22)
	var stone_lt := Color(0.3, 0.27, 0.32)
	var glow := Color(0.4, 1.0, 0.55, 0.9)
	# curtain wall
	ci.draw_colored_polygon(pts([p + Vector2(-30 * s, 2 * s), p + Vector2(0, 14 * s), p + Vector2(30 * s, 2 * s), p + Vector2(30 * s, -16 * s), p + Vector2(0, -4 * s), p + Vector2(-30 * s, -16 * s)]), stone)
	ci.draw_colored_polygon(pts([p + Vector2(0, 14 * s), p + Vector2(30 * s, 2 * s), p + Vector2(30 * s, -16 * s), p + Vector2(0, -4 * s)]), stone_lt.darkened(0.2))
	for i in 5:
		var k := float(i) / 4.0
		var a1 := p + Vector2(-30 * s, -16 * s).lerp(Vector2(0, -4 * s), k)
		ci.draw_rect(Rect2(a1 + Vector2(-2 * s, -4 * s), Vector2(4 * s, 4 * s)), stone)
		var a2 := p + Vector2(0, -4 * s).lerp(Vector2(30 * s, -16 * s), k)
		ci.draw_rect(Rect2(a2 + Vector2(-2 * s, -4 * s), Vector2(4 * s, 4 * s)), stone_lt.darkened(0.2))
	# corner towers
	for tx in [-30.0, 30.0]:
		var base := p + Vector2(tx * s, -6 * s)
		ci.draw_rect(Rect2(base + Vector2(-6 * s, -30 * s), Vector2(12 * s, 34 * s)), stone if tx < 0 else stone_lt.darkened(0.2))
		ci.draw_colored_polygon(pts([base + Vector2(-8 * s, -30 * s), base + Vector2(8 * s, -30 * s), base + Vector2(0, -44 * s)]), Color(0.12, 0.08, 0.14))
		ci.draw_rect(Rect2(base + Vector2(-1.5 * s, -22 * s), Vector2(3 * s, 5 * s)), glow)
	# the keep, with a green flame at the top
	var keep := p + Vector2(0, -8 * s)
	ci.draw_rect(Rect2(keep + Vector2(-9 * s, -46 * s), Vector2(18 * s, 46 * s)), stone_lt)
	ci.draw_rect(Rect2(keep + Vector2(0, -46 * s), Vector2(9 * s, 46 * s)), stone)
	ci.draw_colored_polygon(pts([keep + Vector2(-11 * s, -46 * s), keep + Vector2(11 * s, -46 * s), keep + Vector2(0, -64 * s)]), Color(0.1, 0.06, 0.12))
	for wy in [-36.0, -24.0]:
		ci.draw_rect(Rect2(keep + Vector2(-5 * s, wy * s), Vector2(3 * s, 5 * s)), glow)
		ci.draw_rect(Rect2(keep + Vector2(3 * s, wy * s), Vector2(3 * s, 5 * s)), glow)
	var fl := 4.0 + sin(t * 9.0) * 1.0
	ci.draw_circle(keep + Vector2(0, -68 * s), fl * 1.8 * s, Color(0.35, 1.0, 0.5, 0.25))
	ci.draw_circle(keep + Vector2(0, -68 * s), fl * 0.7 * s, Color(0.7, 1.0, 0.75))
	# gate
	ci.draw_colored_polygon(pts([p + Vector2(-5 * s, 11 * s), p + Vector2(5 * s, 9 * s), p + Vector2(5 * s, -1 * s), p + Vector2(0, -4 * s), p + Vector2(-5 * s, 0)]), Color(0.05, 0.03, 0.06))


## A town ship: twice the size of a boat, two masts, Saltmarsh's blue-and-white sails.
static func ship(ci: CanvasItem, p: Vector2, s: float, facing: int = 1, alpha: float = 1.0) -> void:
	var f := float(facing)
	ellipse(ci, p + Vector2(0, 3), 50 * s, 13 * s, Color(1, 1, 1, 0.2 * alpha))
	var hull := a(Color(0.42, 0.26, 0.14), alpha)
	var trim := a(Color(0.25, 0.15, 0.08), alpha)
	ci.draw_colored_polygon(pts([p + Vector2(-44 * f * s, -18 * s), p + Vector2(48 * f * s, -22 * s), p + Vector2(32 * f * s, 4 * s), p + Vector2(-34 * f * s, 4 * s)]), hull)
	ci.draw_colored_polygon(pts([p + Vector2(-44 * f * s, -18 * s), p + Vector2(48 * f * s, -22 * s), p + Vector2(46 * f * s, -16 * s), p + Vector2(-42 * f * s, -13 * s)]), a(Color(0.55, 0.36, 0.2), alpha))
	ci.draw_line(p + Vector2(-44 * f * s, -18 * s), p + Vector2(48 * f * s, -22 * s), trim, 2.5 * s)
	for i in 4:
		ci.draw_circle(p + Vector2((-20 + i * 14) * f * s, -8 * s), 2.0 * s, trim)
	for m in [[-14.0, 64.0], [18.0, 72.0]]:
		var base := p + Vector2(m[0] * f * s, -18 * s)
		ci.draw_line(base, base + Vector2(0, -m[1] * s), a(Color(0.35, 0.22, 0.12), alpha), 3.0 * s)
		for sy in [[-0.92, -0.58, 14.0], [-0.52, -0.2, 17.0]]:
			var top: Vector2 = base + Vector2(0, sy[0] * m[1] * s)
			var bot: Vector2 = base + Vector2(0, sy[1] * m[1] * s)
			var wd: float = sy[2] * s
			var sail := pts([top + Vector2(-wd, 0), top + Vector2(wd, 0), bot + Vector2(wd * 1.1, 0), bot + Vector2(-wd * 1.1, 0)])
			ci.draw_colored_polygon(sail, a(Color(0.95, 0.94, 0.88), alpha))
			ci.draw_colored_polygon(pts([top.lerp(bot, 0.4) + Vector2(-wd * 1.04, 0), top.lerp(bot, 0.4) + Vector2(wd * 1.04, 0), top.lerp(bot, 0.6) + Vector2(wd * 1.06, 0), top.lerp(bot, 0.6) + Vector2(-wd * 1.06, 0)]), a(Color(0.25, 0.45, 0.7), alpha))
	# pennant
	var tip := p + Vector2(18 * f * s, -90 * s)
	ci.draw_colored_polygon(pts([tip, tip + Vector2(14 * f * s, 3 * s), tip + Vector2(0, 6 * s)]), a(Color(0.25, 0.45, 0.7), alpha))


static func hermit(ci: CanvasItem, feet: Vector2, s: float, col: Color, facing: int = 1, alpha: float = 1.0, t: float = 0.0) -> void:
	var f := float(facing)
	shadow(ci, feet, 16 * s, 5 * s, alpha)
	var c := a(col, alpha)
	var dk := a(col.darkened(0.3), alpha)
	# legs and claws poking out from under the shell
	for i in 3:
		var root := feet + Vector2((3 + i * 3) * f * s, -6 * s)
		ci.draw_polyline(pts([root, root + Vector2(5 * f * s, -3 * s + sin(t * 7.0 + i) * s), root + Vector2(7 * f * s, 6 * s)]), dk, 1.8 * s)
	var claw := feet + Vector2(14 * f * s, -9 * s)
	ellipse(ci, claw, 5 * s, 3.5 * s, c)
	ci.draw_line(claw + Vector2(3 * f * s, 0), claw + Vector2(8 * f * s, -2 * s - absf(sin(t * 3.0)) * 2.0 * s), dk, 2.0 * s)
	for e in [-1.5, 1.5]:
		var base := feet + Vector2((10 + e) * f * s, -11 * s)
		ci.draw_line(base, base + Vector2(0, -5 * s), dk, 1.2 * s)
		ci.draw_circle(base + Vector2(0, -6 * s), 1.5 * s, a(Color(0.1, 0.08, 0.08), alpha))
	# the spiral shell
	var shell := feet + Vector2(-4 * f * s, -14 * s)
	var sc := a(Color(0.86, 0.78, 0.62), alpha)
	ellipse(ci, shell, 13 * s, 11 * s, sc)
	ellipse(ci, shell + Vector2(-2 * f * s, -2 * s), 8 * s, 7 * s, a(Color(0.78, 0.68, 0.52), alpha))
	ellipse(ci, shell + Vector2(-3 * f * s, -3 * s), 4 * s, 3.5 * s, a(Color(0.7, 0.58, 0.44), alpha))
	ci.draw_arc(shell, 13 * s, PI * 0.9, PI * 1.9, 14, a(Color(0.55, 0.45, 0.35), alpha), 1.4 * s)
