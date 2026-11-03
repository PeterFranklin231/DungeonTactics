class_name Board
extends Node2D
## The isometric battle board: tiles with heights, dungeon generation, drawing (painter's order,
## with units drawn between tiles so tall blocks hide what's behind them), tile picking and pathfinding.

const TW := 64.0
const TH := 32.0
const HZ := 14.0          # screen pixels per height step
const BASE := 12.0        # how far the board's sides drop below height 0
const K_FLOOR := 0
const K_MOSS := 1
const K_RUBBLE := 2
const K_PILLAR := 3       # impassable
const K_GRASS := 4        # home meadow
const K_DIRT := 5
const K_WOOD := 6         # built wood blocks
const K_MEADOW := 7

var w := 12
var h := 12
var heights := PackedInt32Array()
var kind := PackedInt32Array()
var highlights := {}      # Vector2i -> Color (filled overlay)
var marks := {}           # Vector2i -> Color (outlined, e.g. area of effect)
var hover := Vector2i(-1, -1)
var traps := {}           # Vector2i -> {dmg, owner}
var battle = null         # TacticsBattle: draws units and effects
var palette := {
	K_FLOOR: Color(0.42, 0.39, 0.36), K_MOSS: Color(0.33, 0.42, 0.3), K_RUBBLE: Color(0.47, 0.43, 0.38), K_PILLAR: Color(0.3, 0.28, 0.3),
	K_GRASS: Color(0.42, 0.66, 0.3), K_DIRT: Color(0.6, 0.47, 0.3), K_WOOD: Color(0.62, 0.42, 0.24), K_MEADOW: Color(0.5, 0.72, 0.33)}
var t := 0.0

const DIRS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

func idx(c: Vector2i) -> int:
	return c.y * w + c.x

func in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < w and c.y < h

func height_at(c: Vector2i) -> int:
	return heights[idx(c)] if in_bounds(c) else 0

func blocked(c: Vector2i) -> bool:
	return not in_bounds(c) or kind[idx(c)] == K_PILLAR

static func dist(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)

# ---------------------------------------------------------------------------
# Generation: the basic dungeon. Rolling stone floors with raised ledges and a few pillars.
# Party deploys along the near (bottom) edge, enemies along the far edge.
# ---------------------------------------------------------------------------
func generate(rng: RandomNumberGenerator) -> void:
	for attempt in 30:
		w = rng.randi_range(10, 13)
		h = rng.randi_range(10, 12)
		heights.resize(w * h)
		kind.resize(w * h)
		var n := FastNoiseLite.new()
		n.seed = rng.randi()
		n.frequency = rng.randf_range(0.09, 0.16)
		for y in h:
			for x in w:
				var v := n.get_noise_2d(x, y)
				var c := Vector2i(x, y)
				heights[idx(c)] = clampi(int(round((v + 0.6) * 2.6)), 0, 4)
				var r := rng.randf()
				kind[idx(c)] = K_MOSS if r < 0.12 else (K_RUBBLE if r < 0.2 else K_FLOOR)
		# deployment edges are flatter
		for x in w:
			for y in [0, 1, h - 2, h - 1]:
				var c2 := Vector2i(x, y)
				heights[idx(c2)] = mini(heights[idx(c2)], 2)
		# pillars in the middle band
		for i in rng.randi_range(3, 7):
			var pc := Vector2i(rng.randi_range(1, w - 2), rng.randi_range(3, h - 4))
			kind[idx(pc)] = K_PILLAR
			heights[idx(pc)] = heights[idx(pc)] + 4
		if _connected(2):
			return
	# give up being fancy: flat board
	for i in w * h:
		heights[i] = 0
		kind[i] = K_FLOOR

func _connected(jump: int) -> bool:
	var start := Vector2i(w / 2, h - 1)
	if blocked(start):
		return false
	var seen := {start: true}
	var q: Array = [start]
	while not q.is_empty():
		var c: Vector2i = q.pop_front()
		for d in DIRS:
			var nb: Vector2i = c + d
			if blocked(nb) or seen.has(nb) or absi(height_at(nb) - height_at(c)) > jump:
				continue
			seen[nb] = true
			q.append(nb)
	var walkable := 0
	for y in h:
		for x in w:
			if not blocked(Vector2i(x, y)):
				walkable += 1
	# most of the board must be reachable, including the far edge
	var far := 0
	for x in w:
		if seen.has(Vector2i(x, 0)) or seen.has(Vector2i(x, 1)):
			far += 1
	return seen.size() >= walkable * 0.85 and far >= 4

## Every free cell of the near start area (the bottom three rows).
func zone_cells(side: String) -> Array:
	var rows: Array = [h - 1, h - 2, h - 3] if side == "near" else [0, 1, 2]
	var out: Array = []
	for r in rows:
		for x in w:
			var c := Vector2i(x, r)
			if not blocked(c):
				out.append(c)
	return out

## Free cells along an edge for deployment ("near" = bottom of the screen, "far" = top).
func spawn_cells(side: String, n: int, rng: RandomNumberGenerator) -> Array:
	var rows: Array = [h - 1, h - 2, h - 3] if side == "near" else [0, 1, 2]
	var out: Array = []
	for r in rows:
		var row: Array = []
		for x in w:
			var c := Vector2i(x, r)
			if not blocked(c):
				row.append(c)
		row.sort_custom(func(a, b): return absi(a.x - w / 2) < absi(b.x - w / 2))
		for c in row:
			if out.size() < n and rng.randf() < 0.85:
				out.append(c)
	return out

# ---------------------------------------------------------------------------
# Pathfinding
# ---------------------------------------------------------------------------
## Tiles a unit can move to: {cell: previous cell}. Enemies of the unit block the way;
## friends can be walked through but not stood on.
func reachable(u: Unit, occupied: Dictionary) -> Dictionary:
	var mv := u.move_range()
	var jp := u.jump_height()
	var prev := {u.cell: u.cell}
	var dist_to := {u.cell: 0}
	var q: Array = [u.cell]
	while not q.is_empty():
		var c: Vector2i = q.pop_front()
		if int(dist_to[c]) >= mv:
			continue
		for d in DIRS:
			var nb: Vector2i = c + d
			if blocked(nb) or dist_to.has(nb):
				continue
			if absi(height_at(nb) - height_at(c)) > jp:
				continue
			var occ = occupied.get(nb)
			if occ != null and occ.is_enemy != u.is_enemy and not u.flies():
				continue
			dist_to[nb] = int(dist_to[c]) + 1
			prev[nb] = c
			q.append(nb)
	var out := {}
	for c in prev:
		var occ2 = occupied.get(c)
		if c == u.cell or occ2 == null:
			out[c] = prev[c]
	# keep the chain for paths through friends
	out["_prev"] = prev
	return out

func path_to(reach: Dictionary, target: Vector2i, start: Vector2i) -> Array:
	var prev: Dictionary = reach["_prev"]
	var path: Array = [target]
	var c := target
	var guard := 0
	while c != start and guard < 64:
		c = prev[c]
		path.push_front(c)
		guard += 1
	return path

## Walking distance from goal cells (ignoring units), for monsters closing in.
func dist_field(goals: Array, jump: int) -> Dictionary:
	var dd := {}
	var q: Array = []
	for g in goals:
		dd[g] = 0
		q.append(g)
	while not q.is_empty():
		var c: Vector2i = q.pop_front()
		for d in DIRS:
			var nb: Vector2i = c + d
			if blocked(nb) or dd.has(nb) or absi(height_at(nb) - height_at(c)) > jump:
				continue
			dd[nb] = int(dd[c]) + 1
			q.append(nb)
	return dd

# ---------------------------------------------------------------------------
# Camera: the board can be viewed from any angle. Grid positions are rotated by yaw
# around the board's centre, then projected isometrically (y squashed to half).
# The node's own position / scale give pan and zoom.
# ---------------------------------------------------------------------------
var yaw := 0.0
var order: Array = []          # cells back-to-front for the current yaw
var _order_yaw := INF

func set_yaw(a: float) -> void:
	yaw = wrapf(a, -PI, PI)

func _rot(g: Vector2) -> Vector2:
	return (g - Vector2((w - 1) * 0.5, (h - 1) * 0.5)).rotated(yaw)

## Screen position (board-local) of a grid point at a height.
func project(g: Vector2, hgt: float) -> Vector2:
	var q := _rot(g)
	return Vector2((q.x - q.y) * TW * 0.5, (q.x + q.y) * TH * 0.5 - hgt * HZ)

func depth_of(g: Vector2) -> float:
	var q := _rot(g)
	return q.x + q.y

func ground_pos(c: Vector2i) -> Vector2:
	return project(Vector2(c), height_at(c))

## The four top corners of a tile.
func corners(c: Vector2i, hgt: float, inset: float = 0.0) -> PackedVector2Array:
	var e := 0.5 - inset
	var g := Vector2(c)
	return PackedVector2Array([project(g + Vector2(-e, -e), hgt), project(g + Vector2(e, -e), hgt),
		project(g + Vector2(e, e), hgt), project(g + Vector2(-e, e), hgt)])

## A grid direction as a screen direction (for facing arrows and sprite flips).
func screen_dir(d: Vector2) -> Vector2:
	return (project(d, 0.0) - project(Vector2.ZERO, 0.0)).normalized()

func _refresh_order() -> void:
	if is_equal_approx(_order_yaw, yaw) and order.size() == w * h:
		return
	_order_yaw = yaw
	order.clear()
	for y in h:
		for x in w:
			order.append(Vector2i(x, y))
	order.sort_custom(func(a, b): return depth_of(Vector2(a)) < depth_of(Vector2(b)))

func cell_at(p: Vector2) -> Vector2i:
	_refresh_order()
	for i in range(order.size() - 1, -1, -1):
		var c: Vector2i = order[i]
		if Geometry2D.is_point_in_polygon(p, corners(c, height_at(c))):
			return c
	return Vector2i(-1, -1)

func pixel_size() -> Vector2:
	return Vector2((w + h) * TW * 0.5, (w + h) * TH * 0.5 + 6 * HZ + BASE)

func center_offset() -> Vector2:
	return Vector2(0, -2 * HZ)

# ---------------------------------------------------------------------------
# Drawing
# ---------------------------------------------------------------------------
func _process(delta: float) -> void:
	t += delta
	queue_redraw()

func _draw() -> void:
	_refresh_order()
	for c in order:
		_draw_tile(c)
		if battle != null:
			battle.draw_units_at(self, c)
	if battle != null:
		battle.draw_overlays(self)

const EDGES := [[Vector2i(0, -1), 0, 1], [Vector2i(1, 0), 1, 2], [Vector2i(0, 1), 2, 3], [Vector2i(-1, 0), 3, 0]]

func _draw_tile(c: Vector2i) -> void:
	var hgt := height_at(c)
	var k := kind[idx(c)]
	var hv := absi((c.x * 73856093) ^ (c.y * 19349663))
	var col: Color = palette[k]
	col = col.lightened(hgt * 0.035 + (hv % 7) * 0.006)
	var top := corners(c, hgt)
	# side faces that look towards the camera, where the neighbour is lower
	for e in EDGES:
		var n: Vector2i = e[0]
		var nq := Vector2(n).rotated(yaw)
		if nq.x + nq.y <= 0.05:
			continue
		var nb: Vector2i = c + n
		var low := -BASE / HZ if not in_bounds(nb) else float(height_at(nb))
		if low >= hgt:
			continue
		var a: Vector2 = top[e[1]]
		var b: Vector2 = top[e[2]]
		var dp := (hgt - low) * HZ
		var shade := clampf(0.3 + 0.18 * (nq.y - nq.x), 0.15, 0.5)
		var fc := col.darkened(shade)
		draw_colored_polygon(PackedVector2Array([a, b, b + Vector2(0, dp), a + Vector2(0, dp)]), fc)
		for si in range(1, int(dp / HZ) + 1):
			draw_line(a + Vector2(0, si * HZ), b + Vector2(0, si * HZ), fc.darkened(0.15), 1.0)
	draw_colored_polygon(top, col)
	var ctr := ground_pos(c)
	match k:
		K_FLOOR:
			if hv % 3 == 0:
				draw_line(ctr + Vector2(-10, -2), ctr + Vector2(4, 4), col.darkened(0.18), 1.0)
		K_MOSS:
			for i in 3:
				var o := Vector2(((hv >> i) % 24) - 12, ((hv >> (i + 3)) % 10) - 5)
				draw_circle(ctr + o, 3.0, Color(0.28, 0.48, 0.25, 0.8))
		K_RUBBLE:
			for i in 3:
				var o2 := Vector2(((hv >> (i * 2)) % 26) - 13, ((hv >> (i + 4)) % 10) - 5)
				draw_circle(ctr + o2, 2.2, col.lightened(0.15))
		K_GRASS, K_MEADOW:
			if hv % 3 == 0:
				var og := Vector2((hv % 25) - 12, ((hv / 25) % 11) - 5)
				draw_line(ctr + og, ctr + og + Vector2(-2, -4), col.darkened(0.2), 1.2)
				draw_line(ctr + og, ctr + og + Vector2(2, -5), col.darkened(0.2), 1.2)
			if k == K_MEADOW and hv % 4 == 0:
				draw_circle(ctr + Vector2((hv % 17) - 8, ((hv / 17) % 7) - 3), 2.0, [Color(1, 0.88, 0.3), Color(1, 0.55, 0.7), Color(0.95, 0.95, 1)][hv % 3])
		K_DIRT:
			if hv % 2 == 0:
				draw_circle(ctr + Vector2((hv % 21) - 10, ((hv / 21) % 9) - 4), 1.6, col.darkened(0.2))
		K_WOOD:
			# plank seams across the top, aligned with the grid
			var g := Vector2(c)
			for f in [-0.25, 0.0, 0.25]:
				draw_line(project(g + Vector2(f, -0.5), hgt), project(g + Vector2(f, 0.5), hgt), col.darkened(0.22), 1.0)
	draw_polyline(top + PackedVector2Array([top[0]]), col.darkened(0.3), 1.0)
	if highlights.has(c):
		var hc: Color = highlights[c]
		var pulse := 0.75 + 0.25 * sin(t * 4.0)
		draw_colored_polygon(corners(c, hgt, 0.04), Color(hc, hc.a * pulse))
	if marks.has(c):
		var mk := corners(c, hgt, 0.06)
		draw_polyline(mk + PackedVector2Array([mk[0]]), marks[c], 2.5)
	if traps.has(c):
		draw_circle(ctr, 6, Color(0.55, 0.42, 0.25))
		for i in 6:
			var a2 := i * TAU / 6.0
			draw_line(ctr, ctr + Vector2(cos(a2), sin(a2) * 0.5) * 9, Color(0.8, 0.8, 0.85), 1.5)
	if c == hover:
		var hk := corners(c, hgt, 0.02)
		draw_polyline(hk + PackedVector2Array([hk[0]]), Color(1, 1, 0.75, 0.95), 2.0)
