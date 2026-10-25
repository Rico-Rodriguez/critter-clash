class_name DepthsLayout
extends RefCounted
## The Sunken Crypt: a torchlit dungeon built from the KayKit dungeon tiles.
## Three halls divided by low barriers (wide gaps — the horde needs room), the
## Hexer Queen's ritual floor at the north end. The south wall is a low
## balustrade so the camera never looks at the back of a wall.

const D := "res://assets/kaykit/dungeon/"
const G := "res://assets/kaykit/graveyard/"


static func build(a: Arena) -> void:
	a.start = Vector3(0, 0, 15)
	a.boss_spawn = Vector3(0, 0, -22.0)
	a.crypt_pos = Vector3(0, 0, -28.0)
	_floor(a)
	_walls(a)
	_barriers(a)
	_ritual(a)
	_shrines(a)
	_clutter(a)
	_spawn_spots(a)


# --- Floor ---------------------------------------------------------------

static func _floor(a: Arena) -> void:
	var kinds := {"floor_tile_large": [], "floor_tile_large_rocks": [], "floor_dirt_large": []}
	for ix in range(-5, 6):
		for iz in 14:
			var x := ix * 4.0
			var z := -30.0 + iz * 4.0
			# The ritual grate sits where four tiles would be.
			if absf(x) < 3.0 and z > -27.0 and z < -21.0:
				continue
			var r := a._rng.randf()
			var k := "floor_tile_large" if r < 0.74 else ("floor_dirt_large" if r < 0.88 else "floor_tile_large_rocks")
			kinds[k].append(Vector3(x, 0, z))
	for k in kinds:
		var src := KK.prop(D + k + ".gltf")
		var mesh: Mesh = null
		var xf := Transform3D.IDENTITY
		for mi in src.find_children("*", "MeshInstance3D", true, false):
			mesh = (mi as MeshInstance3D).mesh
			xf = (mi as MeshInstance3D).transform
			break
		src.free()
		var spots: Array = kinds[k]
		if mesh == null or spots.is_empty():
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = spots.size()
		for i in spots.size():
			mm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, PI * 0.5 * (a._rng.randi() % 4)), spots[i]) * xf)
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		a.add_child(mmi)


# --- Walls ---------------------------------------------------------------

static func _walls(a: Arena) -> void:
	var kinds := ["wall", "wall", "wall", "wall", "wall_cracked", "wall_arched", "wall_window_closed", "wall_broken", "wall"]
	var west_x := a.min_x - 1.0
	var east_x := a.max_x + 1.0
	var north_z := a.min_z - 1.0
	# North wall and the long sides, four metres a piece.
	for i in 11:
		var x := -20.0 + i * 4.0
		a.put(D + kinds[a._rng.randi() % kinds.size()] + ".gltf", Vector3(x, 0, north_z), 0.0, 1.0, -1.0, true, 2.2)
	for i in 14:
		var z := -30.0 + i * 4.0
		a.put(D + kinds[a._rng.randi() % kinds.size()] + ".gltf", Vector3(west_x, 0, z), PI * 0.5, 1.0, -1.0, true, 2.2)
		a.put(D + kinds[a._rng.randi() % kinds.size()] + ".gltf", Vector3(east_x, 0, z), -PI * 0.5, 1.0, -1.0, true, 2.2)
	for c in [Vector3(west_x, 0, north_z), Vector3(east_x, 0, north_z)]:
		a.put(D + "pillar.gltf", c, 0.0, 1.0, -1.0, true, 1.0)
	# South: a low balustrade with a pillar at each end and a gap at the stairs.
	var z_s := a.max_z + 1.0
	for x in [-18.0, -14.0, -10.0, -6.0, 6.0, 10.0, 14.0, 18.0]:
		a.put(D + "barrier.gltf", Vector3(x, 0, z_s), 0.0)
	for x in [-22.0, -4.0, 4.0, 22.0]:
		a.put(D + "pillar.gltf", Vector3(x, 0, z_s), 0.0, 1.0, -1.0, true, 1.0)
	# Torches on the walls, each with a warm light. Twelve lights in all.
	for z in [10.0, -2.0, -14.0]:
		_torch(a, Vector3(west_x + 0.5, 2.3, z), PI * 0.5)
		_torch(a, Vector3(east_x - 0.5, 2.3, z), -PI * 0.5)
	_torch(a, Vector3(-9.0, 2.3, north_z + 0.5), 0.0)
	_torch(a, Vector3(9.0, 2.3, north_z + 0.5), 0.0)
	# Banners behind the Queen.
	var i := 0
	for x in [-14.0, -6.0, 6.0, 14.0]:
		a.put(D + ("banner_patternA_red.gltf" if i % 2 == 0 else "banner_patternB_blue.gltf"), Vector3(x, 0.4, north_z + 0.5), 0.0, 1.2, -1.0, false)
		i += 1


static func _torch(a: Arena, at: Vector3, yaw: float) -> void:
	a.put(D + "torch_mounted.gltf", at, yaw, 1.6, -1.0, false)
	var inward := Vector3(sin(yaw), 0, cos(yaw))
	a._light(at + inward * 1.1 + Vector3(0, 0.3, 0), Color(1.0, 0.62, 0.3), 2.0, 9.0)


# --- Divisions -----------------------------------------------------------

## Low barriers split the crypt into halls. Each piece blocks as a box (PropShapes).
static func _barrier_run(a: Arena, x0: float, x1: float, z: float) -> void:
	var x := x0 + 2.0
	while x <= x1 - 1.9:
		a.put(D + "barrier.gltf", Vector3(x, 0, z), 0.0)
		x += 4.0
	for e in [x0, x1]:
		a.put(D + "pillar.gltf", Vector3(e, 0, z), 0.0, 0.8, 0.8, true, 0.8)


static func _barriers(a: Arena) -> void:
	_barrier_run(a, a.min_x - 1.0, -8.0, 4.0)
	_barrier_run(a, 8.0, a.max_x + 1.0, 4.0)
	_barrier_run(a, a.min_x - 1.0, -6.0, -12.0)
	_barrier_run(a, 10.0, a.max_x + 1.0, -12.0)
	# Pillars flanking the way to the Queen's floor.
	for p in [Vector3(-8, 0, -20), Vector3(8, 0, -20), Vector3(-8, 0, -26), Vector3(8, 0, -26)]:
		a.put(D + "pillar_decorated.gltf", p, 0.0, 0.9, 1.0, true, 1.2)


# --- The Queen's floor ---------------------------------------------------

static func _ritual(a: Arena) -> void:
	a.put(D + "floor_tile_extralarge_grates.gltf", Vector3(0, 0, -24.0), 0.0, 1.0, -1.0, false)
	var cl := a._light(Vector3(0, 2.2, -24.0), Color(0.7, 0.35, 1.0), 2.6, 11.0, false)
	cl.set_meta("flicker", 0.18)
	for k in 8:
		var ang := TAU * k / 8.0
		var p := Vector3(sin(ang), 0, cos(ang)) * 5.2 + Vector3(0, 0, -24.0)
		a.put(D + ("candle_triple.gltf" if k % 2 == 0 else "candle_lit.gltf"), p, ang, 1.5, -1.0, false)


# --- Shrines -------------------------------------------------------------

static func _shrines(a: Arena) -> void:
	for sp in [Vector3(17.5, 0, -6), Vector3(-17.5, 0, 6.0), Vector3(17.5, 0, 9.0)]:
		var inward := -signf(sp.x)
		a.put(D + "column.gltf", sp, 0.0, 1.5, 1.0, true, 0.8)
		a.put(D + "candle_triple.gltf", sp + Vector3(0, 2.1, 0), 0.0, 1.6, -1.0, false)
		var sl := a._light(sp + Vector3(inward * 1.0, 2.0, 0), Color(1.0, 0.65, 0.3), 1.8, 6.5)
		a.shrines.append({"pos": sp + Vector3(inward * 1.9, 0, 0), "light": sl})


# --- Clutter -------------------------------------------------------------

static func _clutter(a: Arena) -> void:
	for c in [Vector3(-18.5, 0, 16.5), Vector3(18.5, 0, 17.5), Vector3(-18.8, 0, -1.0), Vector3(19.0, 0, -21.0), Vector3(-19.0, 0, -20.0), Vector3(19.0, 0, -28.5), Vector3(-18.5, 0, -28.5)]:
		a.put(D + "barrel_large.gltf", c, a._rng.randf() * TAU, 1.0, 1.0, true, 1.0)
		a.put(D + "crates_stacked.gltf", c + Vector3(0.0, 0, 2.4) * (1.0 if a._rng.randf() < 0.5 else -1.0), a._rng.randf() * TAU, 1.0, 1.1, true, 1.1)
		a.put(D + "barrel_small_stack.gltf", c + Vector3(-signf(c.x) * -1.6, 0, 0.8), a._rng.randf() * TAU, 1.0, 0.9, true, 0.9)
	a.put(D + "chest.gltf", Vector3(-13.5, 0, 18.5), 0.4, 1.0, 0.9)
	a.put(D + "chest.gltf", Vector3(13.0, 0, -9.0), -0.6, 1.0, 0.9)
	for i in 24:
		var p := a._free_spot(0.5)
		var bn: String = ["bone_A.gltf", "bone_B.gltf", "bone_C.gltf", "skull.gltf", "ribcage.gltf", "skull.gltf"][a._rng.randi() % 6]
		a.put(G + bn, p, a._rng.randf() * TAU, a._rng.randf_range(0.8, 1.1), -1.0, false)
	for i in 6:
		a.put(D + ["rubble_half.gltf", "rubble_large.gltf"][a._rng.randi() % 2], a._free_spot(1.6), a._rng.randf() * TAU, 0.4, 1.0, false)


## Places the dead can rise from: scattered bone heaps.
static func _spawn_spots(a: Arena) -> void:
	for i in 16:
		var p := a._free_spot(0.8)
		a.put(G + "ribcage.gltf", p, a._rng.randf() * TAU, 1.2, -1.0, false)
		a.put(G + "skull_candle.gltf", p + Vector3(0.6, 0, 0.3), 0.0, 1.2, -1.0, false)
		a.graves.append(p + Vector3(0, 0, 0.8))
