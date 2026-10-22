class_name TrialLayout
extends RefCounted
## The Long Road: a long dungeon generated from a seed, a string of rooms
## divided by low walls with a gap in each (the gap moves from room to room).
## Each room holds an encounter that grows meaner with depth, the last room is
## the boss hall. Everything here is data on `arena.trial`; the hunt reads it
## to decide what to spawn and when to close the gates.
##
## Room kinds: start (safe), ambush, elite (a champion with an escort),
## hunters (ranged), horde (a big swarm), brutes (heavy hitters), shrine (a
## breather with a blessing), treasure (a chest guarded by a few).

const D := "res://assets/kaykit/dungeon/"
const G := "res://assets/kaykit/graveyard/"
const ROOM_DEPTH := 34.0
const START_DEPTH := 26.0
const BOSS_DEPTH := 44.0
const GAP := 12.0 # three wall pieces, so the gap meets the wall with no hole beside it

const KINDS_EARLY := ["ambush", "ambush", "hunters", "treasure"]
const KINDS_MID := ["ambush", "elite", "hunters", "horde", "brutes", "shrine", "treasure"]
const KINDS_LATE := ["elite", "horde", "brutes", "hunters", "elite", "shrine"]

static var _mats := {}


static func build(a: Arena, seed_: int, rooms: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_
	a._rng.seed = seed_
	a.start = Vector3(0, 0, 15)
	var length := START_DEPTH + rooms * ROOM_DEPTH + BOSS_DEPTH
	a.min_z = a.max_z - length
	a.crypt_pos = Vector3(0, 0, a.min_z + 3.0)
	a.boss_spawn = Vector3(0, 0, a.min_z + 14.0)
	var layout := {"rooms": [], "boss_z": 0.0, "boss_gate": {}, "length": length}
	# Room 0 is the start; 1..rooms are fights; the boss hall follows.
	var z_hi := a.max_z
	var z_lo := a.max_z - START_DEPTH
	var walls: Array = []
	var gap_x := 0.0
	for i in rooms + 1:
		var depth := START_DEPTH if i == 0 else ROOM_DEPTH
		z_lo = z_hi - depth
		# Snap to the wall-piece grid (pieces are 4 wide from min_x - 1).
		var g0: float = a.min_x - 1.0 + 4.0 * roundf((rng.randf_range(-9.0, 9.0) - GAP * 0.5 - (a.min_x - 1.0)) / 4.0)
		gap_x = g0 + GAP * 0.5
		var kind := "start"
		if i > 0:
			kind = _kind_for(i, rooms, rng)
		var room := {"index": i, "hi": z_hi, "lo": z_lo, "gap_x": gap_x, "kind": kind, "state": "idle", "foes": [], "gate": {}, "depth": float(i) / rooms}
		# The divider at the room's north end, with a gap the player walks through.
		_divider(a, z_lo, gap_x, walls)
		room["gate"] = a.add_gate(gap_x - GAP * 0.5, gap_x + GAP * 0.5, z_lo)
		a.set_gate(room["gate"], false, true)
		layout["rooms"].append(room)
		_dress_room(a, room, rng)
		z_hi = z_lo
	# The boss hall: z_hi .. min_z. Its entrance gate seals behind the hero.
	layout["boss_z"] = z_hi - 6.0
	var last: Dictionary = layout["rooms"][rooms]
	layout["boss_gate"] = last["gate"]
	_boss_hall(a, z_hi)
	_floor(a)
	_side_walls(a, walls)
	a.trial = layout
	a.follow_radius = 60.0
	_shrine_spots(a, layout)


static func _kind_for(i: int, rooms: int, rng: RandomNumberGenerator) -> String:
	var f := float(i) / rooms
	var pool: Array = KINDS_EARLY if f < 0.34 else (KINDS_MID if f < 0.7 else KINDS_LATE)
	var k: String = pool[rng.randi() % pool.size()]
	# Never two breathers in a row, and the room before the boss is a real fight.
	if i == rooms and k in ["shrine", "treasure"]:
		k = "elite"
	return k


# --- Floor, walls, dividers -------------------------------------------------

static func _floor(a: Arena) -> void:
	var kinds := {"floor_tile_large": [], "floor_tile_large_rocks": [], "floor_dirt_large": []}
	var z := a.max_z + 3.0
	while z > a.min_z - 2.0:
		for ix in range(-5, 6):
			var r := a._rng.randf()
			var k := "floor_tile_large" if r < 0.74 else ("floor_dirt_large" if r < 0.88 else "floor_tile_large_rocks")
			kinds[k].append(Vector3(ix * 4.0, 0, z))
		z -= 4.0
	for k in kinds:
		_multi(a, D + k + ".gltf", kinds[k], true)


## Many copies of one prop in a single draw: walls and floor tiles by the hundred.
static func _multi(a: Arena, path: String, spots: Array, random_yaw: bool, yaw := 0.0, scale_ := 1.0) -> void:
	if spots.is_empty():
		return
	var src := KK.prop(path)
	var mesh: Mesh = null
	var xf := Transform3D.IDENTITY
	for mi in src.find_children("*", "MeshInstance3D", true, false):
		mesh = (mi as MeshInstance3D).mesh
		xf = (mi as MeshInstance3D).transform
		break
	src.free()
	if mesh == null:
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = spots.size()
	for i in spots.size():
		var yw: float = (PI * 0.5 * (a._rng.randi() % 4)) if random_yaw else yaw
		var p: Vector3 = spots[i]
		mm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, yw).scaled(Vector3.ONE * scale_), p) * xf)
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if random_yaw else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	a.add_child(mmi)


static func _side_walls(a: Arena, _walls: Array) -> void:
	var kinds := {"wall": [], "wall_cracked": [], "wall_arched": [], "wall_window_closed": [], "wall_broken": []}
	var weights := ["wall", "wall", "wall", "wall", "wall_cracked", "wall_arched", "wall_window_closed", "wall_broken", "wall"]
	var west := a.min_x - 1.0
	var east := a.max_x + 1.0
	var z := a.max_z - 2.0
	var west_by_k := {}
	var east_by_k := {}
	for k in kinds:
		west_by_k[k] = []
		east_by_k[k] = []
	while z > a.min_z + 1.0:
		var kw: String = weights[a._rng.randi() % weights.size()]
		var ke: String = weights[a._rng.randi() % weights.size()]
		west_by_k[kw].append(Vector3(west, 0, z))
		east_by_k[ke].append(Vector3(east, 0, z))
		z -= 4.0
	for k in kinds:
		_multi(a, D + k + ".gltf", west_by_k[k], false, PI * 0.5)
		_multi(a, D + k + ".gltf", east_by_k[k], false, -PI * 0.5)
	var north: Array = []
	for i in 11:
		north.append(Vector3(-20.0 + i * 4.0, 0, a.min_z - 1.0))
	_multi(a, D + "wall.gltf", north, false, 0.0)
	# The start room's south edge: a low balustrade like the Crypt.
	var south: Array = []
	for x in [-18.0, -14.0, -10.0, -6.0, 6.0, 10.0, 14.0, 18.0]:
		south.append(Vector3(x, 0, a.max_z + 1.0))
	_multi(a, D + "barrier.gltf", south, false, 0.0)


## A low wall across the hall at `z` with a gap at `gap_x`. Blocks as circles.
static func _divider(a: Arena, z: float, gap_x: float, _walls: Array) -> void:
	var pieces: Array = []
	var x := a.min_x - 1.0
	var gap0 := gap_x - GAP * 0.5
	var gap1 := gap_x + GAP * 0.5
	while x < a.max_x + 1.0:
		var cx := x + 2.0
		if cx + 2.0 <= gap0 + 0.01 or cx - 2.0 >= gap1 - 0.01:
			pieces.append(Vector3(cx, 0, z))
		x += 4.0
	# Collision is its own dense run of circles so no sliver is left open.
	var bx := a.min_x - 2.0
	while bx <= a.max_x + 2.0:
		if bx <= gap0 or bx >= gap1:
			a.add_obstacle(Vector2(bx, z), 0.8)
		bx += 1.0
	_multi(a, D + "barrier.gltf", pieces, false, 0.0)
	# A pillar either side of the gap, taller than the wall, to read as a door.
	for gx in [gap0 - 0.4, gap1 + 0.4]:
		a.put(D + "pillar.gltf", Vector3(gx, 0, z), 0.0, 0.85, 0.7, true, 0.9)


# --- Rooms -------------------------------------------------------------------

static func _dress_room(a: Arena, room: Dictionary, rng: RandomNumberGenerator) -> void:
	var hi: float = room["hi"]
	var lo: float = room["lo"]
	var mid := (hi + lo) * 0.5
	# Torches on both walls.
	for sgn in [-1.0, 1.0]:
		_torch(a, Vector3(sgn * (a.max_x + 0.5), 2.3, mid + rng.randf_range(-6.0, 6.0)), -PI * 0.5 * sgn)
	var kind: String = room["kind"]
	# Pillars scattered through the room make the fight a real space.
	var pillars := rng.randi_range(2, 4)
	for p in pillars:
		var at := Vector3(rng.randf_range(-15.0, 15.0), 0, rng.randf_range(lo + 7.0, hi - 6.0))
		if absf(at.x - float(room["gap_x"])) < 7.0 and at.z < lo + 9.0:
			continue
		a.put(D + "pillar_decorated.gltf", at, 0.0, 0.9, 1.0, true, 1.2)
	# Clutter by kind.
	var clusters := rng.randi_range(2, 4)
	for c in clusters:
		var at2 := Vector3((1.0 if rng.randf() < 0.5 else -1.0) * rng.randf_range(12.0, 18.0), 0, rng.randf_range(lo + 5.0, hi - 4.0))
		a.put(D + "barrel_large.gltf", at2, rng.randf() * TAU, 1.0, 1.0, true, 1.0)
		a.put(D + ["crates_stacked.gltf", "barrel_small_stack.gltf", "box_stacked.gltf"][rng.randi() % 3], at2 + Vector3(0, 0, 2.3), rng.randf() * TAU, 1.0, 1.1, true, 1.1)
	for i in 8:
		var bp := Vector3(rng.randf_range(-18.0, 18.0), 0, rng.randf_range(lo + 3.0, hi - 3.0))
		a.put(G + ["bone_A.gltf", "bone_B.gltf", "skull.gltf", "ribcage.gltf", "skull.gltf"][rng.randi() % 5], bp, rng.randf() * TAU, rng.randf_range(0.8, 1.1), -1.0, false)
	match kind:
		"shrine":
			a.put(D + "candle_triple.gltf", Vector3(0, 0, mid), 0.0, 2.0, -1.0, false)
		"treasure":
			room["chest_at"] = Vector3(rng.randf_range(-12.0, 12.0), 0, mid - 3.0)
			a.put(D + "chest_gold.gltf", room["chest_at"], rng.randf() * TAU, 1.2, 1.0)
		"elite", "brutes":
			a.put(D + "banner_patternA_red.gltf", Vector3(-8.0, 0.4, lo + 0.5), 0.0, 1.2, -1.0, false)
			a.put(D + "banner_patternA_red.gltf", Vector3(8.0, 0.4, lo + 0.5), 0.0, 1.2, -1.0, false)


static func _torch(a: Arena, at: Vector3, yaw: float) -> void:
	a.put(D + "torch_mounted.gltf", at, yaw, 1.6, -1.0, false)
	var inward := Vector3(sin(yaw), 0, cos(yaw))
	a._light(at + inward * 1.1 + Vector3(0, 0.3, 0), Color(1.0, 0.62, 0.3), 2.0, 9.5)


static func _boss_hall(a: Arena, z_hi: float) -> void:
	var cz := a.boss_spawn.z + 2.0
	a.put(D + "floor_tile_extralarge_grates.gltf", Vector3(0, 0, cz), 0.0, 1.0, -1.0, false)
	var cl := a._light(Vector3(0, 2.2, cz), Color(0.7, 0.35, 1.0), 2.6, 11.0, false)
	cl.set_meta("flicker", 0.18)
	for k in 8:
		var ang := TAU * k / 8.0
		a.put(D + ("candle_triple.gltf" if k % 2 == 0 else "candle_lit.gltf"), Vector3(sin(ang), 0, cos(ang)) * 5.2 + Vector3(0, 0, cz), ang, 1.5, -1.0, false)
	for p in [Vector3(-9, 0, cz + 6), Vector3(9, 0, cz + 6), Vector3(-9, 0, cz - 6), Vector3(9, 0, cz - 6)]:
		a.put(D + "pillar_decorated.gltf", p, 0.0, 0.9, 1.0, true, 1.2)
	for sgn in [-1.0, 1.0]:
		_torch(a, Vector3(sgn * (a.max_x + 0.5), 2.3, cz + 8.0), -PI * 0.5 * sgn)
		a.put(D + "banner_patternB_blue.gltf" if sgn < 0 else D + "banner_patternA_red.gltf", Vector3(sgn * 8.0, 0.4, a.min_z + 0.6), 0.0, 1.2, -1.0, false)


## Up to three shrines, in the quiet rooms and the start.
static func _shrine_spots(a: Arena, layout: Dictionary) -> void:
	var spots: Array = []
	for r: Dictionary in layout["rooms"]:
		if r["kind"] in ["shrine", "start"]:
			spots.append(r)
	for r2: Dictionary in layout["rooms"]:
		if spots.size() >= 3:
			break
		if r2["kind"] == "treasure" and not spots.has(r2):
			spots.append(r2)
	for r3: Dictionary in spots.slice(0, 3):
		var sgn: float = 1.0 if int(r3["index"]) % 2 == 0 else -1.0
		var z: float = (float(r3["hi"]) + float(r3["lo"])) * 0.5 + 4.0
		var at := Vector3(sgn * 17.5, 0, z)
		a.put(D + "column.gltf", at, 0.0, 1.5, 1.0, true, 0.8)
		a.put(D + "candle_triple.gltf", at + Vector3(0, 2.1, 0), 0.0, 1.6, -1.0, false)
		var inward := -signf(at.x)
		var sl := a._light(at + Vector3(inward * 1.0, 2.0, 0), Color(1.0, 0.65, 0.3), 1.8, 6.5)
		a.shrines.append({"pos": at + Vector3(inward * 1.9, 0, 0), "light": sl})
