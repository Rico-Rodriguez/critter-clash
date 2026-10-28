extends RefCounted
## The Long Road in a rebuilt biome. arena_trial.gd lays out the rooms, the
## dividers and their gaps, and the encounters; in Rimehollow and the Cinder Mire
## this file dresses them from the zone's own kit instead of the dungeon's:
## the floor is the terrain cell grid (a tall one, the length of the road), the
## walls are glacier chunks or bog rock, the dividers are rock ramparts or
## palisades, and every room gets the zone's hazards, scaled by how deep it is.
## Every prop is the zone's Art kit (KitModels: rime_kit.glb, mire_kit.glb).
## A walkable line always runs gap to gap (never thin ice, open water or bog), so
## the road can be crossed on foot. Preloaded by arena_trial.gd, no class_name.
## Crisp PBR: no fog, no bloom, no tint.

const G := "res://assets/kaykit/graveyard/"
const Terrain := preload("res://src/hunt/terrain.gd")
const Kit := preload("res://src/hunt/kit_mesh.gd")
const KitModels := preload("res://src/data/kit_models.gd")
const MireLayout := preload("res://src/hunt/arena_mire.gd")
const Art := preload("res://src/hunt/biome_art.gd")
const COLD := Color(0.62, 0.86, 1.0)
const FIRE := Color(1.0, 0.55, 0.2)
const ZONES := ["frost", "swamp"]
## Width of the road in cells (2 m each), x -22 .. 22.
const COLS := 22
## Half the width of the line that is kept firm gap to gap.
const WAY := 2.6

static var _rock: Array = []


static func covers(zone: String) -> bool:
	return zone in ZONES


static func build(a: Arena, layout: Dictionary, z_hi: float) -> void:
	_floor(a, layout, z_hi)
	_walls(a, layout)
	for room: Dictionary in layout["rooms"]:
		_dress(a, layout, room)
	_boss_hall(a, layout)
	_shrines(a, layout)
	if a.zone == "swamp":
		MireLayout.boardwalk(a)


## The line to keep firm through room `i`: where you walk in, where you walk out.
static func way(a: Arena, layout: Dictionary, i: int) -> Array:
	var rooms: Array = layout["rooms"]
	var room: Dictionary = rooms[i]
	var from := Vector2(a.start.x, a.start.z) if i == 0 else Vector2(float(rooms[i - 1]["gap_x"]), float(room["hi"]))
	return [from, Vector2(float(room["gap_x"]), float(room["lo"]))]


static func _near(p: Vector2, w: Array) -> float:
	var a: Vector2 = w[0]
	var b: Vector2 = w[1]
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
	return p.distance_to(a + ab * t)


# --- The floor -----------------------------------------------------------------

static func _floor(a: Arena, layout: Dictionary, z_hi: float) -> void:
	var frost := a.zone == "frost"
	var oz := floorf(a.min_z / 2.0) * 2.0 - 2.0
	var rows := int(ceilf((a.max_z + 2.0 - oz) / 2.0))
	var t: RefCounted = Terrain.make(COLS, rows, Vector2(-22.0, oz))
	var look: Dictionary
	if frost:
		look = {"dark": (a.zone_env["ground"] as Dictionary)["dark"],
			"base_a": Color(0.6, 0.67, 0.78), "base_b": Color(0.72, 0.78, 0.88),
			"ice_a": Color(0.24, 0.5, 0.78), "ice_b": Color(0.4, 0.68, 0.92), "crack_col": Color(0.12, 0.3, 0.58)}
	else:
		look = {"dark": (a.zone_env["ground"] as Dictionary)["dark"],
			"base_a": Color(0.36, 0.31, 0.24), "base_b": Color(0.5, 0.43, 0.33), "bog_col": Color(0.085, 0.1, 0.085)}
	a.terrain_begin(look, t, Vector2(110.0, a.max_z - a.min_z + 60.0), Vector3(0, 0, (a.min_z + a.max_z) * 0.5))
	var rng := RandomNumberGenerator.new()
	rng.seed = int(layout["seed"]) + 77
	for room: Dictionary in layout["rooms"]:
		var i := int(room["index"])
		if frost:
			_frost_room(t, room, way(a, layout, i), rng)
		else:
			_mire_room(t, room, way(a, layout, i), rng)
	if frost:
		_frost_hall(a, t, rng)
	else:
		_mire_hall(a, t, layout, z_hi)
	a.terrain_painted()


## Snow, a frozen pond in most rooms: thin ice from the second room, open water
## deep in the road. The way across stays solid.
static func _frost_room(t: RefCounted, room: Dictionary, w: Array, rng: RandomNumberGenerator) -> void:
	var kind: String = room["kind"]
	if kind in ["start", "shrine", "treasure"]:
		return
	var f: float = room["depth"]
	var hi: float = room["hi"]
	var lo: float = room["lo"]
	var cx := rng.randf_range(-7.0, 7.0)
	var cz := (hi + lo) * 0.5 + rng.randf_range(-3.0, 3.0)
	var rx := rng.randf_range(9.0, 13.5)
	var rz := rng.randf_range(7.5, 11.0)
	t.fill_ellipse(Terrain.ICE, cx, cz, rx, rz, -1, 0.14, rng.randi())
	for k in 1 + int(f * 3.0):
		var p := Vector2(cx + rng.randf_range(-0.55, 0.55) * rx, cz + rng.randf_range(-0.55, 0.55) * rz)
		var r := rng.randf_range(1.8, 2.7)
		t.fill_ellipse(Terrain.THIN_ICE, p.x, p.y, r, r, Terrain.ICE, 0.12, rng.randi())
	var holes := 0 if f < 0.35 else 1 + int(f * 2.0)
	for k in holes:
		var p2 := Vector3(cx + rng.randf_range(-0.5, 0.5) * rx, 0.0, cz + rng.randf_range(-0.5, 0.5) * rz)
		var c: Vector2i = t.cell_of(p2)
		if t.kind_of(c) == Terrain.ICE and _near(Vector2(p2.x, p2.z), w) > WAY + 1.5:
			t.set_kind(c, Terrain.WATER)
	_clear_way(t, room, w)


## No thin ice or open water on the line between the gaps, and open water always
## has ice all round it.
static func _clear_way(t: RefCounted, room: Dictionary, w: Array) -> void:
	for z in range(t.cell_of(Vector3(0, 0, float(room["lo"]) - 2.0)).y, t.cell_of(Vector3(0, 0, float(room["hi"]) + 2.0)).y + 1):
		for x in t.w:
			var c := Vector2i(x, z)
			var k: int = t.kind_of(c)
			var o: Vector3 = t.center_of(c)
			if (k == Terrain.THIN_ICE or k == Terrain.WATER) and _near(Vector2(o.x, o.z), w) < WAY:
				t.set_kind(c, Terrain.ICE)
			if k == Terrain.WATER:
				for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					if t.kind_of(c + d) in [Terrain.DRY, Terrain.THIN_ICE]:
						t.set_kind(c + d, Terrain.ICE)


## The throne court: a frozen floor, a plain of snow before it.
static func _frost_hall(a: Arena, t: RefCounted, rng: RandomNumberGenerator) -> void:
	t.fill_ellipse(Terrain.ICE, 0.0, a.boss_spawn.z, 9.5, 7.2, -1, 0.1, rng.randi())


## Soot-dark ground with bog pools that grow with depth; a boardwalk of planks
## runs gap to gap over the wet, and an ash patch to fight beside.
static func _mire_room(t: RefCounted, room: Dictionary, w: Array, rng: RandomNumberGenerator) -> void:
	var kind: String = room["kind"]
	if kind == "start":
		return
	var f: float = room["depth"]
	var hi: float = room["hi"]
	var lo: float = room["lo"]
	if kind not in ["shrine", "treasure"]:
		for k in 2 + int(f * 3.0):
			var rx := rng.randf_range(4.5, 7.0 + f * 2.5)
			var rz := rng.randf_range(3.5, 5.5)
			t.fill_ellipse(Terrain.BOG, rng.randf_range(-15.0, 15.0), rng.randf_range(lo + 7.0, hi - 6.0), rx, rz, -1, 0.14, rng.randi())
		var ash := Vector2(rng.randf_range(-14.0, 14.0), rng.randf_range(lo + 7.0, hi - 6.0))
		t.fill_ellipse(Terrain.ASH, ash.x, ash.y, 2.6, 2.1, -1, 0.1, rng.randi())
	# The gaps open on firm ground: a hand of dry before each divider.
	for gz: float in [hi, lo]:
		var gx: float = (w[0] as Vector2).x if gz == hi else (w[1] as Vector2).x
		t.fill_ellipse(Terrain.DRY, gx, gz, 4.5, 3.0, -1, 0.05, 5)
	t.fill_line(Terrain.PLANK, w[0], w[1], [Terrain.DRY, Terrain.ASH])


## The Warlord's deck: a ring of planks round dry ground, standing in the bog.
static func _mire_hall(a: Arena, t: RefCounted, layout: Dictionary, z_hi: float) -> void:
	var c := Vector3(0, 0, a.boss_spawn.z)
	t.fill_ellipse(Terrain.BOG, c.x, c.z, 12.5, 9.5, -1, 0.1, 31)
	t.fill_ellipse(Terrain.PLANK, c.x, c.z, 7.5, 5.0, -1, 0.0, 32)
	t.fill_ellipse(Terrain.DRY, c.x, c.z, 5.2, 3.4, -1, 0.0, 33)
	t.fill_ellipse(Terrain.DRY, a.crypt_pos.x, a.crypt_pos.z + 0.8, 6.0, 3.4, -1, 0.0, 34)
	var rooms: Array = layout["rooms"]
	var from := Vector2(float(rooms[rooms.size() - 1]["gap_x"]), z_hi)
	t.fill_ellipse(Terrain.DRY, from.x, from.y, 4.5, 3.0, -1, 0.05, 35)
	t.fill_line(Terrain.PLANK, from, Vector2(0.0, c.z + 4.6), [Terrain.DRY, Terrain.ASH])


# --- Walls and dividers --------------------------------------------------------------

## Three chunk meshes shared by every rock in the road: glacier or bog rock.
static func _rocks(frost: bool) -> Array:
	var out: Array = []
	for i in 3:
		out.append(KitModels.mesh("rime", "cliff_" + "abc"[i]) if frost else KitModels.mesh("mire", "stone_" + "abc"[i]))
	return out


## Adds `xf` to the batch of a 40 m stretch of road: so far stretches are culled.
static func _bin(bins: Dictionary, a: Arena, xf: Transform3D, variant: int) -> void:
	var key := int(floorf((a.max_z - xf.origin.z) / 40.0)) * 3 + variant % 3
	if not bins.has(key):
		bins[key] = []
	(bins[key] as Array).append(xf)


static func _flush(a: Arena, bins: Dictionary, meshes: Array) -> void:
	for key: int in bins:
		Kit.batch(a, meshes[key % 3], null, bins[key])


## The side walls, a south wall behind the landing, and the far wall behind the
## boss hall: a row of big rocks, and a taller row behind.
static func _walls(a: Arena, layout: Dictionary) -> void:
	var frost := a.zone == "frost"
	var rng := RandomNumberGenerator.new()
	rng.seed = int(layout["seed"]) + 5
	var meshes := _rocks(frost)
	var bins := {}
	var tall := Vector3(3.0, 4.6, 3.0) if frost else Vector3(4.2, 5.0, 4.2)
	var z := a.max_z + 1.0
	while z > a.min_z - 2.0:
		for sgn in [-1.0, 1.0]:
			var s := rng.randf_range(1.5, 2.3)
			var hgt := rng.randf_range(0.9, 1.6) * (0.7 if frost else 1.6)
			var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, hgt * s, s) * (1.0 if frost else 1.4)), Vector3(sgn * (a.max_x + 1.6 + rng.randf() * 0.5), 0, z))
			_bin(bins, a, xf, rng.randi())
			var big := tall * rng.randf_range(0.85, 1.25)
			_bin(bins, a, Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(big), Vector3(sgn * (a.max_x + 5.2 + rng.randf() * 1.5), 0, z + rng.randf_range(-1.0, 1.0))), rng.randi())
		z -= 3.2
	var x := a.min_x - 1.0
	while x <= a.max_x + 1.0:
		var s2 := rng.randf_range(1.6, 2.4)
		_bin(bins, a, Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(tall * rng.randf_range(0.9, 1.3)), Vector3(x, 0, a.min_z - 2.5)), rng.randi())
		_bin(bins, a, Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s2, s2 * 0.9, s2)), Vector3(x, 0, a.max_z + 1.8)), rng.randi())
		x += 3.4
	_flush(a, bins, meshes)


## The divider across a room's north end: a low rampart of rock, or a palisade of
## piles, with a gate of two taller posts at the gap. Collision is arena_trial's.
static func divider(a: Arena, z: float, gap_x: float, gap: float) -> void:
	var frost := a.zone == "frost"
	var rng := RandomNumberGenerator.new()
	rng.seed = int(z * 31.0) + 9
	var gap0 := gap_x - gap * 0.5
	var gap1 := gap_x + gap * 0.5
	var xfs: Array = []
	var x := a.min_x - 1.5
	var step := 2.4 if frost else 0.8
	while x <= a.max_x + 1.5:
		if x < gap0 or x > gap1:
			if frost:
				var s := rng.randf_range(1.35, 1.8)
				xfs.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * 0.85, s)), Vector3(x, 0, z)))
			else:
				var s2 := rng.randf_range(1.1, 1.5)
				xfs.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s2, s2, s2)), Vector3(x + rng.randf_range(-0.1, 0.1), 0, z + rng.randf_range(-0.2, 0.2))))
		x += step
	if frost:
		Kit.batch(a, KitModels.mesh("rime", "cliff_a"), null, xfs)
		var posts: Array = []
		for gx in [gap0 - 0.6, gap1 + 0.6]:
			posts.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(1.5, 2.1, 1.5)), Vector3(gx, 0, z)))
			a.add_obstacle(Vector2(gx, z), 1.0)
		Kit.batch(a, KitModels.mesh("rime", "crystal_c"), null, posts)
	else:
		Kit.batch(a, KitModels.mesh("mire", "pile_a"), null, xfs)
		var posts2: Array = []
		for gx2 in [gap0 - 0.6, gap1 + 0.6]:
			posts2.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(1.0, 1.0, 1.0) * 1.7), Vector3(gx2, 0, z)))
			a.add_obstacle(Vector2(gx2, z), 0.6)
			Art.flame(a, Vector3(gx2, 2.7, z), 0.7)
		Kit.batch(a, KitModels.mesh("mire", "pile_b"), null, posts2)


# --- Rooms ---------------------------------------------------------------------

## A spot in the room, clear of the line between the gaps, the walls and the
## landing, on ground that is not water or wet bog (when `dry`).
static func _spot(a: Arena, rng: RandomNumberGenerator, room: Dictionary, w: Array, from_x: float, to_x: float, dry := true) -> Variant:
	for i in 24:
		var p := Vector3(rng.randf_range(from_x, to_x), 0, rng.randf_range(float(room["lo"]) + 6.0, float(room["hi"]) - 5.0))
		if _near(Vector2(p.x, p.z), w) < WAY + 2.0 or a.blocked(p, 1.2) or p.distance_to(a.start) < 8.0:
			continue
		var k: int = a.terrain.kind_at(p)
		if dry and k not in [Terrain.DRY, Terrain.ICE, Terrain.ASH]:
			continue
		return p
	return null


static func _dress(a: Arena, layout: Dictionary, room: Dictionary) -> void:
	var frost := a.zone == "frost"
	var i := int(room["index"])
	var rng := RandomNumberGenerator.new()
	rng.seed = int(layout["seed"]) * 7 + i
	var w := way(a, layout, i)
	var lo: float = room["lo"]
	var hi: float = room["hi"]
	var mid := (hi + lo) * 0.5
	var kind: String = room["kind"]
	var stones: Array = []
	var stone_mesh: Mesh = KitModels.mesh("rime", "ice_block") if frost else KitModels.mesh("mire", "stone_a")
	# Cover to fight round: ice pillars, or bog stones.
	for k in rng.randi_range(2, 4):
		var p = _spot(a, rng, room, w, -15.0, 15.0)
		if p == null:
			continue
		var s := rng.randf_range(0.9, 1.4)
		stones.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s, s) * (1.0 if frost else 1.3)), p))
		a.add_obstacle(Vector2(p.x, p.z), (1.2 if frost else 0.95) * s)
	if not stones.is_empty():
		Kit.batch(a, stone_mesh, null, stones)
	if frost:
		_frost_props(a, rng, room, w)
	else:
		_mire_props(a, rng, room, w)
	for k in 2:
		var bp = _spot(a, rng, room, w, -18.0, 18.0)
		if bp != null:
			a.put(G + ["bone_A.gltf", "skull.gltf", "ribcage.gltf", "bone_B.gltf"][rng.randi() % 4], bp, rng.randf() * TAU, rng.randf_range(0.8, 1.1), -1.0, false)
	if kind == "treasure":
		var cp = _spot(a, rng, room, w, -12.0, 12.0)
		room["chest_at"] = cp if cp != null else Vector3(0, 0, mid - 3.0)
		a.put("res://assets/kaykit/dungeon/chest_gold.gltf", room["chest_at"], rng.randf() * TAU, 1.2, 1.0)


static func _frost_props(a: Arena, rng: RandomNumberGenerator, room: Dictionary, w: Array) -> void:
	var lo: float = room["lo"]
	var hi: float = room["hi"]
	var crystals: Array = []
	for k in 2:
		var p = _spot(a, rng, room, w, -17.0, 17.0, false)
		if p == null:
			continue
		var s := rng.randf_range(0.8, 1.3)
		crystals.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * 1.15, s)), p))
		a.add_obstacle(Vector2(p.x, p.z), 0.95 * s)
		if k == 0:
			a._light(p + Vector3(0, 1.4, 0), COLD, 1.8, 10.0)
	if not crystals.is_empty():
		Kit.batch(a, KitModels.mesh("rime", "crystal_" + "abcd"[int(room["index"]) % 4]), null, crystals)
	var pines: Array = []
	for k in 6:
		var sgn := -1.0 if k % 2 == 0 else 1.0
		var p2 := Vector3(sgn * rng.randf_range(16.5, 19.5), 0, rng.randf_range(lo + 5.0, hi - 4.0))
		var s2 := rng.randf_range(1.2, 1.7)
		pines.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s2), p2))
		a.add_obstacle(Vector2(p2.x, p2.z), 0.7 * s2)
	Kit.batch(a, KitModels.mesh("rime", "pine_" + "abc"[int(room["index"]) % 3]), null, pines)


static func _mire_props(a: Arena, rng: RandomNumberGenerator, room: Dictionary, w: Array) -> void:
	var lo: float = room["lo"]
	var hi: float = room["hi"]
	for k in 2:
		var p = _spot(a, rng, room, w, -17.0, 17.0)
		if p == null:
			continue
		a.put(G + ["tree_dead_large.gltf", "tree_dead_medium.gltf", "tree_dead_large_decorated.gltf"][rng.randi() % 3], p, rng.randf() * TAU, rng.randf_range(1.3, 1.7), 0.45, true, 1.2)
	var pots: Array = []
	for k in 2:
		var sgn := -1.0 if k == 0 else 1.0
		var p2 := Vector3(sgn * 18.0, 0, rng.randf_range(lo + 6.0, hi - 5.0))
		pots.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU), p2))
		a.add_obstacle(Vector2(p2.x, p2.z), 0.5)
		Art.flame(a, p2 + Vector3(0, 1.0, 0), 0.8)
		if k == 0:
			a._light(p2 + Vector3(sgn * -1.5, 1.6, 0), FIRE, 1.8, 9.0, true)
	Kit.batch(a, KitModels.mesh("mire", "brazier"), null, pots)
	var reeds: Array = []
	var tries := 0
	while reeds.size() < 16 and tries < 120:
		tries += 1
		var p3 := Vector3(rng.randf_range(a.min_x, a.max_x), 0, rng.randf_range(lo + 2.0, hi - 2.0))
		if a.terrain.kind_at(p3) != Terrain.BOG:
			continue
		var s := rng.randf_range(0.8, 1.4)
		reeds.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s, s)), p3))
	if not reeds.is_empty():
		Kit.batch(a, KitModels.mesh("mire", "reeds_" + "abc"[int(room["index"]) % 3]), null, reeds, false)


# --- The boss hall -------------------------------------------------------------

static func _boss_hall(a: Arena, layout: Dictionary) -> void:
	var c := a.boss_spawn
	if a.zone == "frost":
		var rng := RandomNumberGenerator.new()
		rng.seed = int(layout["seed"]) + 21
		var pillars: Array = []
		# A ring of tall ice, open toward the road.
		for k in 10:
			var ang := deg_to_rad(-150.0 + float(k) * 32.0)
			var p := Vector2(c.x + cos(ang) * 9.6, c.z - 0.8 + sin(ang) * 7.6)
			if p.y > c.z + 9.0:
				continue
			var s := rng.randf_range(1.5, 2.0)
			pillars.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * 1.2, s)), Vector3(p.x, 0, p.y)))
			a.add_obstacle(p, s * 0.8)
		Kit.batch(a, KitModels.mesh("rime", "crystal_c"), null, pillars)
		a._light(c + Vector3(0, 3.0, 5.0), COLD, 2.6, 13.0, false)
	else:
		var tree := MeshInstance3D.new()
		tree.mesh = KitModels.mesh("mire", "pyre_tree")
		tree.position = a.crypt_pos
		tree.rotation.y = 0.4
		tree.scale = Vector3.ONE * 1.3
		a.add_child(tree)
		a.add_obstacle(Vector2(a.crypt_pos.x, a.crypt_pos.z), 2.0)
		for o: Vector3 in [Vector3(0.6, 7.2, 0.4), Vector3(3.0, 9.0, 1.8), Vector3(-2.5, 8.5, -1.7)]:
			Art.flame(a, a.crypt_pos + o, 1.5)
		a._light(a.crypt_pos + Vector3(0, 6.5, 4.0), FIRE, 3.0, 13.0, true)
		var pots: Array = []
		for deg in [165.0, 200.0, 340.0, 15.0]:
			var ang2 := deg_to_rad(deg)
			var bp := Vector3(c.x + cos(ang2) * 6.3, 0, c.z + sin(ang2) * 4.2)
			pots.append(Transform3D(Basis(Vector3.UP, ang2), bp))
			a.add_obstacle(Vector2(bp.x, bp.z), 0.5)
			Art.flame(a, bp + Vector3(0, 1.0, 0), 0.8)
		Kit.batch(a, KitModels.mesh("mire", "brazier"), null, pots)


## Up to three shrines, on firm pads against the side walls, in the quiet rooms.
static func _shrines(a: Arena, layout: Dictionary) -> void:
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
		a.terrain.fill_ellipse(Terrain.DRY, at.x, at.z, 3.0, 3.0, -1, 0.0, 80)
		a.put(G + "shrine_candles.gltf", at, -PI * 0.5 * sgn, 1.4, 1.0, true, 1.2)
		var inward := -signf(at.x)
		var sl := a._light(at + Vector3(inward * 1.0, 1.6, 0), COLD if a.zone == "frost" else Color(1.0, 0.7, 0.4), 1.7, 6.5)
		a.shrines.append({"pos": at + Vector3(inward * 1.9, 0, 0), "light": sl})
	a.terrain_painted()
