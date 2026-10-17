class_name HuntMap
extends RefCounted

## One biome's world, as data. The shipped hunts are a single screen:
## one chunk, one spawn zone, boss at the top of that zone.
## A later explorable map is the same record with more chunks and zones
## (about 4 by 4 screens, sixteen times the area).

const VIEW := Vector2(720, 1280)
## The shipped hunt arena: about three times the old one-screen field, so the far
## follow camera (RunSim.VIEW_BOX) fits inside it with room for packs to
## appear just off screen and still inside the arena.
const ARENA := Vector2(1120, 2236)
const PLAY := Rect2(40, 168, 1040, 1900)
const CHUNK := Vector2(720, 1280)
## A zone this close to the hero (or holding the hero) is allowed to spawn.
const ZONE_REACH := 1100.0
## Extra world pixels kept alive past the view so a chunk is ready before it scrolls in.
const STREAM_MARGIN := 128.0


var id := "meadow"
var size := VIEW
var play := PLAY
var chunk_size := CHUNK
var chunks: Array = []
var zones: Array = []
## Top-center of the boss arena. The boss stands one radius below this point.
var boss_at := Vector2(360, 168)


static func for_biome(biome_id: String) -> HuntMap:
	var map := HuntMap.new()
	map.id = biome_id
	map.size = ARENA
	map.play = PLAY
	map.chunk_size = ARENA
	map.boss_at = Vector2(PLAY.get_center().x, PLAY.position.y)
	map.chunks = [{
		"col": 0,
		"row": 0,
		"ground": biome_id,
		"props": [],
	}]
	map.zones = [{
		"id": "wilds",
		"rect": PLAY,
	}]
	return map


## A 4x4-screen world for tests and for the next map. Not used by a live hunt.
static func explore(biome_id: String, screens_x: int = 4, screens_y: int = 4) -> HuntMap:
	var map := HuntMap.new()
	map.id = biome_id
	map.chunk_size = CHUNK
	map.size = Vector2(CHUNK.x * float(screens_x), CHUNK.y * float(screens_y))
	map.play = Rect2(Vector2.ZERO, map.size)
	map.chunks = []
	map.zones = []
	for row in screens_y:
		for col in screens_x:
			var origin := Vector2(float(col) * CHUNK.x, float(row) * CHUNK.y)
			map.chunks.append({
				"col": col,
				"row": row,
				"ground": biome_id,
				"props": [
					{"sprite": "gem", "pos": Vector2(160, 280), "scale": 0.35},
					{"sprite": "shadow", "pos": Vector2(420, 760), "scale": 0.45},
				],
			})
			map.zones.append({
				"id": "%d_%d" % [col, row],
				"rect": Rect2(origin + PLAY.position, PLAY.size),
			})
	var last: Vector2 = map.chunk_origin(screens_x - 1, screens_y - 1)
	map.boss_at = last + Vector2(PLAY.get_center().x, PLAY.position.y)
	return map


func boss_spawn(radius: float) -> Vector2:
	return boss_at + Vector2(0, radius + 8.0)


func chunk_origin(col: int, row: int) -> Vector2:
	return Vector2(float(col) * chunk_size.x, float(row) * chunk_size.y)


func chunk_rect(chunk: Dictionary) -> Rect2:
	return Rect2(chunk_origin(int(chunk["col"]), int(chunk["row"])), chunk_size)


func chunks_in(view: Rect2, margin: float = STREAM_MARGIN) -> Array:
	var area := view.grow(margin)
	var out: Array = []
	for chunk in chunks:
		if chunk_rect(chunk).intersects(area):
			out.append(chunk)
	return out


func zone_near(at: Vector2) -> Dictionary:
	var best: Dictionary = {}
	var best_d := 1.0e12
	var near: Dictionary = {}
	var near_d := 1.0e12
	for zone in zones:
		var rect: Rect2 = zone["rect"]
		var dist := _dist_to_rect(at, rect)
		if dist < best_d:
			best = zone
			best_d = dist
		if dist <= ZONE_REACH and dist < near_d:
			near = zone
			near_d = dist
	if not near.is_empty():
		return near
	if best.is_empty():
		return {"id": "wilds", "rect": play}
	return best


static func rim_point(rect: Rect2, rng: RandomNumberGenerator) -> Vector2:
	var side := rng.randi() % 4
	match side:
		0:
			return Vector2(rect.position.x + 8.0, rng.randf_range(rect.position.y, rect.end.y))
		1:
			return Vector2(rect.end.x - 8.0, rng.randf_range(rect.position.y, rect.end.y))
		2:
			return Vector2(rng.randf_range(rect.position.x, rect.end.x), rect.position.y + 8.0)
		_:
			return Vector2(rng.randf_range(rect.position.x, rect.end.x), rect.end.y - 8.0)


static func _dist_to_rect(at: Vector2, rect: Rect2) -> float:
	var x := clampf(at.x, rect.position.x, rect.end.x)
	var y := clampf(at.y, rect.position.y, rect.end.y)
	return at.distance_to(Vector2(x, y))


# --- Explore world ----------------------------------------------------------
# A biome as a place to explore (PoE/Diablo style): ~16x the old arena,
# assembled from a 4x7 grid of chunks. A winding main trail of clearings runs
# from the start (south) to the boss lair (north); side pockets branch off it
# with loot chests and elite packs. Camps sit in clearings and patrols walk the
# trails. Everything outside the clearings and corridors is forest.

const CELL := Vector2(1120, 1280)
const WORLD_COLS := 4
const WORLD_ROWS := 7
## Fog and pathing grid cell, in sim px.
const GRID := 80.0
const DX4 := [1, -1, 0, 0]
const DY4 := [0, 0, 1, -1]

var is_world := false
## Open areas: {pos: Vector2, r: float, kind: "start"|"clearing"|"pocket"|"lair"}
var nodes: Array = []
## Corridor segments: {a: Vector2, b: Vector2, w: float, trail: bool}
var segs: Array = []
## Camps: {pos, count, elite: bool, node: int}
var camps: Array = []
## Patrols: {a: Vector2, b: Vector2, count}
var patrols: Array = []
## Loot chests: {pos, tier: "common"|"rare"}
var loot: Array = []
## Landmarks: {pos, kind, r} (r is the solid radius in sim px)
var landmarks: Array = []
## Shrines: {pos, kind: "fury"|"haste"|"warding"|"greed"}. Claimed on contact.
var shrines: Array = []
## Where the treasure goblin hides, if the map rolled one. INF when none.
var goblin_at := Vector2.INF
var start := Vector2.ZERO
var lair := Vector2.ZERO
var lair_r := 680.0
var grid_w := 0
var grid_h := 0
## 1 where the pathing grid cell is open.
var open_cells := PackedByteArray()


## The seed this world was built from; the stage scatters its scenery from
## it too, so every load looks a little different (fixed only when asked).
var seed: int = 0

static func world(biome_id: String, seed: int) -> HuntMap:
	var m := HuntMap.new()
	m.id = biome_id
	m.seed = seed
	m.is_world = true
	m.size = Vector2(CELL.x * WORLD_COLS, CELL.y * WORLD_ROWS)
	m.play = Rect2(Vector2.ZERO, m.size)
	m.chunk_size = CELL
	var rng := RandomNumberGenerator.new()
	rng.seed = int(seed) * 7919 + hash(biome_id)
	for row in WORLD_ROWS:
		for col in WORLD_COLS:
			m.chunks.append({"col": col, "row": row, "ground": biome_id, "props": []})
	m._lay_trail(rng)
	m._lay_pockets(rng)
	m._populate(rng)
	m._bake_grid()
	# A landmark must never seal off a trail or pocket: drop any that do.
	while not m._all_reachable() and not m.landmarks.is_empty():
		m.landmarks.pop_back()
		m._bake_grid()
	m.boss_at = m.lair
	m.zones = [{"id": "world", "rect": m.play}]
	return m


func _cell_center(col: int, row: int) -> Vector2:
	return Vector2((float(col) + 0.5) * CELL.x, (float(row) + 0.5) * CELL.y)


func _add_node(pos: Vector2, r: float, kind: String) -> int:
	nodes.append({"pos": pos, "r": r, "kind": kind, "links": []})
	return nodes.size() - 1


## A corridor between two nodes, bent once at a jittered midpoint so trails wind.
func _link(a: int, b: int, w: float, rng: RandomNumberGenerator, trail: bool) -> void:
	var pa: Vector2 = nodes[a]["pos"]
	var pb: Vector2 = nodes[b]["pos"]
	var d := pb - pa
	var mid := pa + d * rng.randf_range(0.4, 0.6) + d.orthogonal().normalized() * d.length() * rng.randf_range(-0.22, 0.22)
	segs.append({"a": pa, "b": mid, "w": w, "trail": trail})
	segs.append({"a": mid, "b": pb, "w": w * rng.randf_range(0.85, 1.1), "trail": trail})
	nodes[a]["links"].append(mid - pa)
	nodes[b]["links"].append(mid - pb)


var _used := {}
var _main: Array = []


func _lay_trail(rng: RandomNumberGenerator) -> void:
	var col := rng.randi_range(1, 2)
	var prev := -1
	for row in range(WORLD_ROWS - 1, -1, -1):
		var steps := [col]
		if row > 0 and row < WORLD_ROWS - 1 and rng.randf() < 0.5:
			var side := col + (1 if rng.randf() < 0.5 else -1)
			if side < 0 or side >= WORLD_COLS:
				side = col - (side - col)
			steps.append(side)
			col = side
		for c in steps:
			var kind := "clearing"
			var r := rng.randf_range(360.0, 560.0)
			var jit := Vector2(rng.randf_range(-230.0, 230.0), rng.randf_range(-220.0, 220.0))
			if prev == -1:
				kind = "start"
				r = 380.0
			elif row == 0:
				kind = "lair"
				r = lair_r
				jit = Vector2(0, -60)
			var at: Vector2 = _cell_center(c, row) + jit
			at.x = clampf(at.x, r + 60.0, size.x - r - 60.0)
			at.y = clampf(at.y, r + 60.0, size.y - r - 60.0)
			var idx := _add_node(at, r, kind)
			_used[Vector2i(c, row)] = idx
			if prev >= 0:
				# Most trails are comfortable; one in three narrows to a chokepoint.
				var w := rng.randf_range(250.0, 300.0) if rng.randf() < 0.33 else rng.randf_range(340.0, 440.0)
				_link(prev, idx, w, rng, true)
			_main.append(idx)
			prev = idx
	start = nodes[_main[0]]["pos"]
	lair = nodes[_main[-1]]["pos"]


func _lay_pockets(rng: RandomNumberGenerator) -> void:
	var made := 0
	var tries := 0
	while made < 4 and tries < 60:
		tries += 1
		var from: int = _main[rng.randi_range(1, _main.size() - 2)]
		var cell := _cell_of(nodes[from]["pos"])
		var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
		var d: Vector2i = dirs[rng.randi() % 4]
		var to := cell + d
		if to.x < 0 or to.x >= WORLD_COLS or to.y < 1 or to.y >= WORLD_ROWS or _used.has(to):
			continue
		var r := rng.randf_range(280.0, 380.0)
		var at := _cell_center(to.x, to.y) + Vector2(rng.randf_range(-200.0, 200.0), rng.randf_range(-200.0, 200.0))
		at.x = clampf(at.x, r + 60.0, size.x - r - 60.0)
		at.y = clampf(at.y, r + 60.0, size.y - r - 60.0)
		var idx := _add_node(at, r, "pocket")
		_used[to] = idx
		_link(from, idx, rng.randf_range(230.0, 300.0), rng, false)
		made += 1


func _all_reachable() -> bool:
	var field := flow(start)
	for n in nodes:
		if field[cell_index(n["pos"])] < 0:
			return false
	for c in camps:
		if field[cell_index(c["pos"])] < 0:
			return false
	for c in loot:
		if field[cell_index(c["pos"])] < 0:
			return false
	return true


func _cell_of(p: Vector2) -> Vector2i:
	return Vector2i(clampi(int(p.x / CELL.x), 0, WORLD_COLS - 1), clampi(int(p.y / CELL.y), 0, WORLD_ROWS - 1))


func _populate(rng: RandomNumberGenerator) -> void:
	var pockets: Array = []
	var clearings: Array = []
	for i in nodes.size():
		match str(nodes[i]["kind"]):
			"pocket":
				pockets.append(i)
			"clearing":
				clearings.append(i)
	# Camps: one per clearing, two in the big ones.
	for i in clearings:
		var n: Dictionary = nodes[i]
		var r: float = n["r"]
		var count := 1 if r < 480.0 else 2
		for k in count:
			var off := Vector2.RIGHT.rotated(rng.randf() * TAU) * r * rng.randf_range(0.0, 0.35)
			camps.append({"pos": n["pos"] + off, "count": rng.randi_range(4, 6), "elite": false, "node": i})
	# Pockets: each holds a chest; two get an elite pack guarding it.
	_shuffle(pockets, rng)
	var elites := 0
	for i in pockets:
		var n: Dictionary = nodes[i]
		var away: Vector2 = -(n["links"][0] as Vector2).normalized() if not (n["links"] as Array).is_empty() else Vector2.UP
		loot.append({"pos": n["pos"] + away * n["r"] * 0.45, "tier": "rare" if elites < 2 else "common"})
		if elites < 2:
			camps.append({"pos": n["pos"], "count": 3, "elite": true, "node": i})
			elites += 1
	# If the map rolled few pockets, elites move into clearings.
	while elites < 2 and not clearings.is_empty():
		var i: int = clearings[rng.randi() % clearings.size()]
		camps.append({"pos": nodes[i]["pos"], "count": 3, "elite": true, "node": i})
		elites += 1
	# A chest out in the open too, tucked at a clearing's edge.
	if not clearings.is_empty():
		var i: int = clearings[rng.randi() % clearings.size()]
		var n: Dictionary = nodes[i]
		loot.append({"pos": n["pos"] + _open_dir(n, rng) * n["r"] * 0.7, "tier": "common"})
	# Patrols walk the middle of the main trail's corridors.
	var trail_segs: Array = []
	for s in segs:
		if bool(s["trail"]) and (s["a"] as Vector2).distance_to(start) > 900.0 and (s["b"] as Vector2).distance_to(start) > 900.0:
			trail_segs.append(s)
	_shuffle(trail_segs, rng)
	for k in mini(4, trail_segs.size()):
		var s: Dictionary = trail_segs[k]
		var a: Vector2 = s["a"]
		var b: Vector2 = s["b"]
		patrols.append({"a": a.lerp(b, 0.15), "b": a.lerp(b, 0.85), "count": rng.randi_range(2, 3)})
	# Landmarks: one per clearing, set off the trail mouths.
	var kinds := ["great_tree", "standing_stones", "ruin", "crystal", "great_tree", "hollow_log"]
	var ki := rng.randi() % kinds.size()
	for i in nodes.size():
		var n: Dictionary = nodes[i]
		if str(n["kind"]) != "clearing" or rng.randf() < 0.12:
			continue
		# Off to one side of the open direction (chests take the open side).
		var dir := _open_dir(n, rng).rotated(0.95 if rng.randf() < 0.5 else -0.95)
		var kind: String = kinds[ki % kinds.size()]
		ki += 1
		var solid := 70.0 if kind != "standing_stones" else 46.0
		var spot: Vector2 = n["pos"] + dir * n["r"] * 0.62
		var crowded := false
		for c in camps:
			crowded = crowded or spot.distance_to(c["pos"]) < 230.0
		for c in loot:
			crowded = crowded or spot.distance_to(c["pos"]) < 200.0
		if crowded:
			continue
		landmarks.append({"pos": n["pos"] + dir * n["r"] * 0.62, "kind": kind, "r": solid, "yaw": rng.randf() * TAU})
	# Map events last, so the camps, chests and landmarks above keep their
	# old placement (and the shipped balance) on a given seed.
	_shrines(rng)
	_affix_camps(rng)
	_goblin_haunt(rng)


## Shrines: two or three, standing in clearings or pockets well away from the
## start and the lair. Walking within reach claims one once.
func _shrines(rng: RandomNumberGenerator) -> void:
	var spots: Array = []
	for i in nodes.size():
		var n: Dictionary = nodes[i]
		var kind := str(n["kind"])
		if kind != "clearing" and kind != "pocket":
			continue
		var pos: Vector2 = n["pos"]
		if pos.distance_to(start) < 760.0 or pos.distance_to(lair) < 760.0:
			continue
		spots.append(i)
	if spots.size() < 2:
		# A cramped roll: fall back to any clearing or pocket off the ends.
		for i in nodes.size():
			var k := str(nodes[i]["kind"])
			if (k == "clearing" or k == "pocket") and not spots.has(i):
				spots.append(i)
	_shuffle(spots, rng)
	var kinds := ["fury", "haste", "warding", "greed"]
	_shuffle(kinds, rng)
	var count := mini(rng.randi_range(2, 3), spots.size())
	for s in count:
		var n: Dictionary = nodes[spots[s]]
		# Dead centre of the clearing/pocket: it sits on the route the hero
		# already walks to reach the camp or chest there.
		shrines.append({"pos": n["pos"], "kind": str(kinds[s % kinds.size()])})


## Elite packs carry one or two affixes; the odd normal camp does too.
func _affix_camps(rng: RandomNumberGenerator) -> void:
	var pool := ["fast", "shielded", "molten", "vampiric"]
	for c in camps:
		var chance := 1.0 if bool(c["elite"]) else 0.15
		if rng.randf() >= chance:
			continue
		_shuffle(pool, rng)
		var count := rng.randi_range(1, 2)
		var picked: Array = []
		for k in mini(count, pool.size()):
			picked.append(pool[k])
		c["affixes"] = picked


## The treasure goblin hides in one pocket, or a clearing on a pocket-poor map.
func _goblin_haunt(rng: RandomNumberGenerator) -> void:
	var places: Array = []
	for i in nodes.size():
		if str(nodes[i]["kind"]) == "pocket":
			places.append(i)
	if places.is_empty():
		for i in nodes.size():
			if str(nodes[i]["kind"]) == "clearing":
				places.append(i)
	if places.is_empty():
		return
	goblin_at = nodes[places[rng.randi() % places.size()]]["pos"]


## Fisher-Yates on the map's seeded rng; Array.shuffle() would use the global one.
func _shuffle(a: Array, rng: RandomNumberGenerator) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: Variant = a[i]
		a[i] = a[j]
		a[j] = tmp


## The direction from a node's centre that is furthest from its corridors.
func _open_dir(n: Dictionary, rng: RandomNumberGenerator) -> Vector2:
	var best := Vector2.RIGHT
	var best_s := -1e9
	for k in 16:
		var d := Vector2.RIGHT.rotated(TAU * float(k) / 16.0 + rng.randf_range(-0.1, 0.1))
		var s := 0.0
		var worst := 2.0
		for l in n["links"]:
			worst = minf(worst, 1.0 - d.dot((l as Vector2).normalized()))
		s = worst
		if s > best_s:
			best_s = s
			best = d
	return best


## How far inside the open ground a point is (px); negative is forest.
func depth(p: Vector2) -> float:
	var best := -1e9
	for n in nodes:
		best = maxf(best, float(n["r"]) - p.distance_to(n["pos"]))
	for s in segs:
		best = maxf(best, float(s["w"]) * 0.5 - _seg_dist(p, s["a"], s["b"]))
	return best


## Distance to the nearest trail centreline (px).
func trail_dist(p: Vector2) -> float:
	var best := 1e9
	for s in segs:
		best = minf(best, _seg_dist(p, s["a"], s["b"]))
	return best


static func _seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
	return p.distance_to(a + ab * t)


## Moves a body of `radius` back onto open ground, sliding along the edge.
## Each open shape offers its nearest valid spot; the closest one that is
## really open (depth >= radius in the union) wins, so junctions and trail
## mouths never trap a body between two shapes.
func push_inside(p: Vector2, radius: float) -> Vector2:
	var cands: Array = []
	for n in nodes:
		var c: Vector2 = n["pos"]
		var r: float = n["r"]
		var off := p - c
		var d := r - off.length()
		if d >= radius:
			return p
		cands.append(c + (off.normalized() if off.length() > 0.01 else Vector2.RIGHT) * maxf(r - radius, 0.0))
	for sg in segs:
		var a: Vector2 = sg["a"]
		var ab: Vector2 = (sg["b"] as Vector2) - a
		var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
		var q := a + ab * t
		var half: float = float(sg["w"]) * 0.5
		var off := p - q
		var d := half - off.length()
		if d >= radius:
			return p
		cands.append(q + (off.normalized() if off.length() > 0.01 else ab.orthogonal().normalized()) * maxf(half - radius, 0.0))
	cands.sort_custom(func(x: Vector2, y: Vector2) -> bool: return x.distance_squared_to(p) < y.distance_squared_to(p))
	for k in mini(4, cands.size()):
		if depth(cands[k]) >= radius - 0.5:
			return cands[k]
	return cands[0] if not cands.is_empty() else p


func _bake_grid() -> void:
	grid_w = int(ceil(size.x / GRID))
	grid_h = int(ceil(size.y / GRID))
	open_cells.resize(grid_w * grid_h)
	for y in grid_h:
		for x in grid_w:
			var c := Vector2((float(x) + 0.5) * GRID, (float(y) + 0.5) * GRID)
			var ok := depth(c) > 40.0
			for l in landmarks:
				if c.distance_to(l["pos"]) < float(l["r"]) + 46.0:
					ok = false
			open_cells[y * grid_w + x] = 1 if ok else 0


func cell_index(p: Vector2) -> int:
	var x := clampi(int(p.x / GRID), 0, grid_w - 1)
	var y := clampi(int(p.y / GRID), 0, grid_h - 1)
	return y * grid_w + x


func cell_center(i: int) -> Vector2:
	return Vector2((float(i % grid_w) + 0.5) * GRID, (float(i / grid_w) + 0.5) * GRID)


## Breadth-first step counts from `from` over open cells, out to `reach` cells.
## Unreached cells hold -1. Chasers and the test bot walk down this field.
func flow(from: Vector2, reach: int = 9999) -> PackedInt32Array:
	var dist := PackedInt32Array()
	dist.resize(grid_w * grid_h)
	dist.fill(-1)
	var s := cell_index(from)
	if open_cells[s] == 0:
		# Standing on an edge cell: start from the nearest open neighbour.
		for k in [1, -1, grid_w, -grid_w, grid_w + 1, grid_w - 1, -grid_w + 1, -grid_w - 1]:
			var j: int = s + int(k)
			if j >= 0 and j < open_cells.size() and open_cells[j] == 1:
				s = j
				break
	var queue := PackedInt32Array([s])
	dist[s] = 0
	var head := 0
	while head < queue.size():
		var i := queue[head]
		head += 1
		var d := dist[i]
		if d >= reach:
			continue
		var x := i % grid_w
		var y := i / grid_w
		for k in 4:
			var nx: int = x + DX4[k]
			var ny: int = y + DY4[k]
			if nx < 0 or ny < 0 or nx >= grid_w or ny >= grid_h:
				continue
			var j: int = ny * grid_w + nx
			if dist[j] != -1 or open_cells[j] == 0:
				continue
			dist[j] = d + 1
			queue.append(j)
	return dist


## The next waypoint toward the flow field's source from `at`.
func downhill(dist: PackedInt32Array, at: Vector2) -> Vector2:
	var i := cell_index(at)
	var here := dist[i]
	if here <= 0:
		return Vector2.INF
	var x := i % grid_w
	var y := i / grid_w
	var best := here
	var best_j := -1
	for oy in [-1, 0, 1]:
		for ox in [-1, 0, 1]:
			if ox == 0 and oy == 0:
				continue
			var nx: int = x + ox
			var ny: int = y + oy
			if nx < 0 or ny < 0 or nx >= grid_w or ny >= grid_h:
				continue
			var j := ny * grid_w + nx
			var d := dist[j]
			if d < 0:
				continue
			# Diagonals only when both side cells are open (no corner cutting).
			if ox != 0 and oy != 0 and (open_cells[y * grid_w + nx] == 0 or open_cells[ny * grid_w + x] == 0):
				continue
			if d < best:
				best = d
				best_j = j
	if best_j < 0:
		return Vector2.INF
	return cell_center(best_j)
