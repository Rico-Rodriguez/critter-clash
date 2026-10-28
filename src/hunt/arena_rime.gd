extends RefCounted
## Rimehollow: a frozen lake under glacier cliffs. You land on the south shore
## by a beached longship, cross the ice (thin patches that crack, fishing holes
## that drown) and can break into the two ice caverns for their shrines. North of
## the lake the Glacier Throne rises, where the Frost Troll holds court.
## The floor is the terrain cell grid (src/hunt/terrain*.gd); the cliffs, pines,
## crystals, hut and ship are code-built low-poly meshes (kit_mesh.gd) until the
## art kit lands. Crisp PBR: no fog, no bloom, no tint.

const G := "res://assets/kaykit/graveyard/"
const Terrain := preload("res://src/hunt/terrain.gd")
const Kit := preload("res://src/hunt/kit_mesh.gd")
const KitModels := preload("res://src/data/kit_models.gd")
const COLD := Color(0.62, 0.86, 1.0)
const WARM := Color(1.0, 0.72, 0.38)

const LAKE := Vector3(0.0, 0.0, -0.5)   # centre x, z; rx and rz below
const LAKE_RX := 14.5
const LAKE_RZ := 10.0
const COURT := Vector3(0.0, 0.0, -21.0)
## Ice walls in a cavern mouth: cell centres. Behind each one is a shrine.
const CAVES := [
	{"at": Vector2(-17.8, -3.0), "r": 3.4, "mouth": [Vector2(-15, -4), Vector2(-15, -2)], "face": 0.0},
	{"at": Vector2(17.8, 3.0), "r": 3.4, "mouth": [Vector2(15, 2), Vector2(15, 4)], "face": PI},
]

static var _cliff_meshes: Array = []


static func build(a: Arena) -> void:
	a.start = Vector3(0, 0, 15)
	a.boss_spawn = COURT
	a.crypt_pos = Vector3(0, 0, -26.5)
	_ground(a)
	_ice_floor(a)
	_cliffs(a)
	_caverns(a)
	_throne(a)
	_shore(a)
	_pines(a)
	_crystals(a)
	_dressing(a)
	_spawn_spots(a)
	_foe_spots(a)


# --- The floor -----------------------------------------------------------------

static func _ground(a: Arena) -> void:
	# Snow on the shore is a soft blue-white; the lake is a deeper, glossier blue so
	# the two read apart at a glance.
	var look: Dictionary = {"dark": (a.zone_env["ground"] as Dictionary)["dark"],
		"base_a": Color(0.6, 0.67, 0.78), "base_b": Color(0.72, 0.78, 0.88),
		"ice_a": Color(0.24, 0.5, 0.78), "ice_b": Color(0.4, 0.68, 0.92), "crack_col": Color(0.12, 0.3, 0.58)}
	a.terrain_begin(look)


static func _ice_floor(a: Arena) -> void:
	var t: RefCounted = a.terrain
	t.fill_ellipse(Terrain.ICE, LAKE.x, LAKE.z, LAKE_RX, LAKE_RZ, -1, 0.14, 11)
	t.fill_ellipse(Terrain.ICE, COURT.x, COURT.z, 9.5, 7.2, -1, 0.1, 12)
	# The causeway between the lake and the court, a frozen stair.
	for z in range(-14, -8, 2):
		for x in range(-3, 4, 2):
			t.set_kind(t.cell_of(Vector3(x, 0, z)), Terrain.ICE)
	# Thin ice over parts of the lake: the sheen is the tell, the crack the cost.
	for p: Array in [[-6.5, -4.5, 2.4], [7.5, 2.5, 2.6], [-1.5, 5.0, 2.0], [9.0, -5.0, 1.9], [-10.0, 3.5, 2.0], [3.0, -7.0, 1.6]]:
		t.fill_ellipse(Terrain.THIN_ICE, p[0], p[1], p[2], p[2], Terrain.ICE, 0.12, int(p[0] * 7 + 5))
	# Fishing holes: open water with an ice rim, always.
	for h: Vector2 in [Vector2(3.0, -2.0), Vector2(-3.0, 1.0), Vector2(-8.0, -6.5), Vector2(10.0, 6.5), Vector2(-7.0, -6.5), Vector2(-3.0, 3.0)]:
		t.set_kind(t.cell_of(Vector3(h.x, 0, h.y)), Terrain.WATER)
	a.terrain_painted()


# --- Cliffs, the wall round the hollow -------------------------------------

## Three glacier chunk meshes, shared by every cliff in the zone.
static func _meshes() -> Array:
	if _cliff_meshes.is_empty():
		for i in 3:
			_cliff_meshes.append(KitModels.mesh("rime", "cliff_" + "abc"[i]))
	return _cliff_meshes


## Places chunks (each a Transform3D) as one MultiMesh per variant.
static func _batch(a: Arena, meshes: Array, material: Material, xfs: Array, shadow := true) -> void:
	var by: Array = []
	for i in meshes.size():
		by.append([])
	for i in xfs.size():
		(by[i % meshes.size()] as Array).append(xfs[i])
	for i in meshes.size():
		if not (by[i] as Array).is_empty():
			Kit.batch(a, meshes[i], material, by[i], shadow)


static func _cliffs(a: Arena) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 90210
	var xfs: Array = []
	var step := 3.1
	# A ring just outside the walls; the south edge keeps a little gap where the
	# shore opens to the ice road, filled with pines below.
	var pts: Array = []
	var x := a.min_x - 1.2
	while x <= a.max_x + 1.2:
		pts.append(Vector2(x, a.min_z - 1.5))
		pts.append(Vector2(x, a.max_z + 2.4))
		x += step
	var z := a.min_z
	while z <= a.max_z + 1.0:
		pts.append(Vector2(a.min_x - 2.2, z))
		pts.append(Vector2(a.max_x + 2.2, z))
		z += step
	for p: Vector2 in pts:
		var s := rng.randf_range(1.5, 2.3)
		var hgt := rng.randf_range(0.9, 1.6)
		xfs.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, hgt * s * 0.7, s)), Vector3(p.x + rng.randf_range(-0.5, 0.5), 0, p.y)))
	# A second, taller row behind it, and the great wall behind the throne.
	for i in 26:
		var side := -1.0 if i % 2 == 0 else 1.0
		var zz := a.min_z + 3.0 + float(i / 2) * 4.3
		xfs.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(3.0, 4.6, 3.0) * rng.randf_range(0.85, 1.25)), Vector3(side * (a.max_x + 5.5 + rng.randf() * 1.5), 0, zz)))
	for i in 9:
		var xx := -20.0 + float(i) * 5.0
		xfs.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(3.4, 5.5, 3.4) * rng.randf_range(0.85, 1.3)), Vector3(xx, 0, a.min_z - 4.8 - rng.randf() * 1.5)))
	_batch(a, _meshes(), null, xfs)
	# Glacier Gate: two big chunks flank the causeway to the throne.
	var gate: Array = []
	for sx in [-1.0, 1.0]:
		gate.append(Transform3D(Basis(Vector3.UP, 0.6 * sx).scaled(Vector3(2.7, 3.3, 2.7)), Vector3(sx * 6.3, 0, -12.2)))
		a.add_obstacle(Vector2(sx * 6.3, -12.2), 2.2)
		a.add_obstacle(Vector2(sx * 8.4, -11.4), 1.6)
		gate.append(Transform3D(Basis(Vector3.UP, 1.9 * sx).scaled(Vector3(1.9, 2.5, 1.9)), Vector3(sx * 8.8, 0, -11.6)))
	_batch(a, _meshes(), null, gate)


# --- Caverns, sealed behind breakable ice ----------------------------------

static func _caverns(a: Arena) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5150
	var xfs: Array = []
	for cave: Dictionary in CAVES:
		var at: Vector2 = cave["at"]
		var r: float = cave["r"]
		var face: float = cave["face"]
		# A horseshoe of chunks round the back of the cavern, open toward the lake.
		for k in 9:
			var ang := face + deg_to_rad(52.0 + float(k) * 32.0)
			var p := at + Vector2(cos(ang), sin(ang)) * (r + 0.7)
			var s := rng.randf_range(1.3, 1.7)
			xfs.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, rng.randf_range(1.4, 2.0) * s, s)), Vector3(p.x, 0, p.y)))
			a.add_obstacle(p, s * 0.92)
		# The mouth: ice walls on the lake edge, each a solid block you can break.
		for m: Vector2 in cave["mouth"]:
			var node := MeshInstance3D.new()
			node.mesh = KitModels.mesh("rime", "ice_block")
			node.position = Vector3(m.x, 0, m.y)
			node.rotation.y = rng.randf() * TAU
			a.add_child(node)
			a.add_ice_wall(a.terrain.cell_of(Vector3(m.x, 0, m.y)), node)
		# The shrine in the back.
		var sp := Vector3(at.x - cos(face) * (r - 1.3), 0, at.y)
		a.put(G + "shrine_candles.gltf", sp, face + PI * 0.5, 1.4, 1.0, true, 1.2)
		var sl := a._light(sp + Vector3(cos(face) * 1.0, 1.6, 0), Color(0.7, 0.9, 1.0), 1.8, 6.5)
		a.shrines.append({"pos": sp + Vector3(cos(face) * 1.9, 0, 0), "light": sl})
		a.terrain.set_kind(a.terrain.cell_of(Vector3(sp.x, 0, sp.z)), Terrain.DRY)
	_batch(a, _meshes(), null, xfs)


# --- The Glacier Throne ----------------------------------------------------

static func _throne(a: Arena) -> void:
	var xfs: Array = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 777
	var meshes: Array = [KitModels.mesh("rime", "crystal_c"), KitModels.mesh("rime", "crystal_a")]
	# A ring of tall ice pillars round the court, open on the south.
	for k in 10:
		var ang := deg_to_rad(-150.0 + float(k) * 32.0)
		var p := Vector2(COURT.x + cos(ang) * 9.2, COURT.z - 0.8 + sin(ang) * 7.6)
		if p.y > -12.0:
			continue
		var s := rng.randf_range(1.5, 2.0)
		xfs.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * 1.2, s)), Vector3(p.x, 0, p.y)))
		a.add_obstacle(p, 1.0 * s * 0.8)
	_batch(a, meshes, null, xfs)
	# The throne itself: a seat cut from three great blocks, spires rising behind.
	var blocks: Array = []
	var blk := KitModels.mesh("rime", "ice_block")
	for b: Array in [[-3.0, -27.6, 1.5, 1.3], [3.0, -27.6, 1.5, 1.3], [0.0, -29.2, 2.0, 2.3], [-1.6, -28.4, 1.1, 1.8], [1.6, -28.4, 1.1, 1.8]]:
		blocks.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(b[2], b[3], b[2])), Vector3(b[0], 0, b[1])))
	Kit.batch(a, blk, null, blocks)
	a.add_obstacle(Vector2(-3.0, -27.6), 1.5)
	a.add_obstacle(Vector2(3.0, -27.6), 1.5)
	a.add_obstacle(Vector2(0.0, -29.2), 2.0)
	a._light(COURT + Vector3(0, 4.0, -3.0), COLD, 3.0, 14.0, false)
	a._light(COURT + Vector3(-6.0, 2.5, 3.0), COLD, 1.4, 8.0, false)
	a._light(COURT + Vector3(6.0, 2.5, 3.0), COLD, 1.4, 8.0, false)


# --- The south shore ---------------------------------------------------------

static func _shore(a: Arena) -> void:
	# The beached longship, bow toward the lake.
	var ship := MeshInstance3D.new()
	ship.mesh = KitModels.mesh("rime", "longship")
	ship.position = Vector3(-11.5, -0.2, 14.0)
	ship.rotation = Vector3(0.06, PI + 0.5, 0.1)
	a.add_child(ship)
	for k in 4:
		var o := Vector2(-11.5, 14.0) + Vector2(sin(PI + 0.5), cos(PI + 0.5)) * (float(k) - 1.5) * 2.4
		a.add_obstacle(o, 1.5)
	# An ice-fisher's hut, a sled, and the first lanterns.
	var hut := MeshInstance3D.new()
	hut.mesh = KitModels.mesh("rime", "hut")
	hut.position = Vector3(11.0, 0, 15.5)
	hut.rotation.y = -0.3
	a.add_child(hut)
	a.add_box(Vector2(11.0, 15.5), Vector2(1.7, 1.4), -0.3)
	var sled := MeshInstance3D.new()
	sled.mesh = KitModels.mesh("rime", "sled")
	sled.position = Vector3(8.0, 0, 12.2)
	sled.rotation.y = 0.5
	a.add_child(sled)
	for lp in [Vector3(-3.4, 0, 12.5), Vector3(4.2, 0, 11.5), Vector3(7.5, 0, 15.8)]:
		a.put(G + "post_lantern.gltf", lp, a._rng.randf() * TAU, 1.35, 0.3, true, 0.6)
		a._light(lp + Vector3(0, 2.4, 0), WARM, 1.6, 7.5)
	# The third shrine, on the shore by the hut.
	var sp := Vector3(16.5, 0, 12.5)
	a.put(G + "shrine_candles.gltf", sp, -PI * 0.5, 1.4, 1.0, true, 1.2)
	var sl := a._light(sp + Vector3(-1.0, 1.6, 0), Color(0.7, 0.9, 1.0), 1.6, 6.5)
	a.shrines.append({"pos": sp + Vector3(-1.9, 0, 0), "light": sl})


# --- Pines and crystals ------------------------------------------------------

static func _pines(a: Arena) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2468
	var meshes: Array = [KitModels.mesh("rime", "pine_a"), KitModels.mesh("rime", "pine_b"), KitModels.mesh("rime", "pine_c")]
	var xfs: Array = []
	# Inside the hollow: pines on the shore flanks, solid cover.
	var inside: Array = [Vector2(-18.5, 10.5), Vector2(-16.0, 17.5), Vector2(-19.0, 15.5), Vector2(18.5, 18.0), Vector2(19.5, 8.5), Vector2(-4.5, 18.5),
		Vector2(5.0, 19.0), Vector2(-17.5, -12.5), Vector2(17.0, -14.5), Vector2(-14.5, -20.5), Vector2(14.0, -22.5), Vector2(-9.5, 12.0)]
	for p: Vector2 in inside:
		var s := rng.randf_range(1.2, 1.7)
		xfs.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s), Vector3(p.x, 0, p.y)))
		a.add_obstacle(p, 0.7 * s)
	# Outside the cliffs: a dark wood behind.
	for i in 70:
		var p := Vector2(rng.randf_range(-44.0, 44.0), rng.randf_range(-48.0, 36.0))
		if p.x > a.min_x - 9.0 and p.x < a.max_x + 9.0 and p.y > a.min_z - 8.0 and p.y < a.max_z + 6.0:
			continue
		var s2 := rng.randf_range(1.5, 2.6)
		xfs.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s2), Vector3(p.x, 0, p.y)))
	_batch(a, meshes, null, xfs)


static func _crystals(a: Arena) -> void:
	var meshes: Array = [KitModels.mesh("rime", "crystal_a"), KitModels.mesh("rime", "crystal_b"), KitModels.mesh("rime", "crystal_c"), KitModels.mesh("rime", "crystal_d")]
	var xfs: Array = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	# Cover on the lake and shore: some frozen in the ice, some by the cave walls.
	var spots: Array = [Vector2(-7.0, 0.5), Vector2(6.0, -5.5), Vector2(0.5, 8.0), Vector2(-12.0, -6.5), Vector2(12.0, -2.0), Vector2(-1.0, -9.0),
		Vector2(-14.0, 11.0), Vector2(13.5, 9.5), Vector2(-16.5, -9.0), Vector2(16.5, -8.5), Vector2(-20.0, 3.0), Vector2(19.5, -2.5),
		Vector2(-5.5, 15.0), Vector2(4.5, 17.5), Vector2(-9.0, -13.0), Vector2(9.0, -14.5), Vector2(-14.0, -27.0), Vector2(14.0, -27.0)]
	for p: Vector2 in spots:
		var s := rng.randf_range(0.8, 1.3)
		xfs.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * 1.15, s)), Vector3(p.x, 0, p.y)))
		a.add_obstacle(p, 0.95 * s)
	# Inside each cavern, a few more.
	for cave: Dictionary in CAVES:
		var at: Vector2 = cave["at"]
		for k in 2:
			var ang := float(cave["face"]) + PI + (float(k) * 2.0 - 1.0) * 1.0
			var p := at + Vector2(cos(ang), sin(ang)) * 2.1
			xfs.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(1.0, 1.25, 1.0) * rng.randf_range(0.7, 1.1)), Vector3(p.x, 0, p.y)))
	_batch(a, meshes, null, xfs)


## Boulders and stacked ice blocks: something to fight round on the
## open shore and the court.
static func _dressing(a: Arena) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1357
	var rocks: Array = []
	for p: Vector2 in [Vector2(-5.5, 11.5), Vector2(12.5, 9.0), Vector2(-14.5, 6.5), Vector2(15.0, -6.5), Vector2(-3.5, -12.8), Vector2(6.5, -17.5), Vector2(-10.5, -17.0), Vector2(16.5, -19.5), Vector2(-17.0, -22.5), Vector2(1.5, 19.0), Vector2(-19.0, 18.5), Vector2(9.5, 4.5)]:
		var s := rng.randf_range(0.55, 0.85)
		rocks.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s * 1.2, s * 1.3, s)), Vector3(p.x, 0, p.y)))
		a.add_obstacle(p, 0.95 * s)
	_batch(a, [KitModels.mesh("rime", "boulder_a"), KitModels.mesh("rime", "boulder_b")], null, rocks)
	# Cut ice stacked by the hut: the fisher's harvest.
	var cubes: Array = []
	for o: Array in [[14.6, 17.4, 0.0, 0.5], [15.9, 17.0, 0.0, 0.42], [15.2, 18.2, 1.2, 0.46], [-6.5, 18.0, 0.0, 0.5], [-5.4, 18.7, 0.0, 0.4]]:
		cubes.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(o[3], o[3] * 0.63, o[3])), Vector3(o[0], o[2] * 0.0, o[1])))
	Kit.batch(a, KitModels.mesh("rime", "ice_block"), null, cubes)
	a.add_obstacle(Vector2(15.2, 17.4), 1.3)
	a.add_obstacle(Vector2(-6.0, 18.3), 1.1)


## Where the frozen dead come up: ice and snow, never over thin ice or water,
## never inside a cavern (the walls are the lock) or on the landing shore.
static func _spawn_spots(a: Arena) -> void:
	var n := 0
	var tries := 0
	while n < 16 and tries < 400:
		tries += 1
		var p := Vector3(a._rng.randf_range(-17.5, 17.5), 0, a._rng.randf_range(-26.0, 12.0))
		var k: int = a.terrain.kind_at(p)
		if k != Terrain.ICE and k != Terrain.DRY:
			continue
		if a.blocked(p, 1.2):
			continue
		if p.distance_to(a.start) < 7.0:
			continue
		var caved := false
		for cave: Dictionary in CAVES:
			if Vector2(p.x, p.z).distance_to(cave["at"]) < float(cave["r"]) + 3.0:
				caved = true
		if caved:
			continue
		a.graves.append(p)
		n += 1


## Perches for the wraiths (the lake rim, in the open) and holes where the Winter Caller's
## imps rise (cracks round the court and along the causeway). Ice or snow, never blocked.
static func _foe_spots(a: Arena) -> void:
	for i in 18:
		var ang := TAU * float(i) / 18.0
		var p := LAKE + Vector3(cos(ang) * (LAKE_RX + 2.2), 0, sin(ang) * (LAKE_RZ + 2.2))
		if _open(a, p):
			a.perches.append(p)
	for i in 10:
		var ang := TAU * float(i) / 10.0
		var p := COURT + Vector3(cos(ang) * 6.5, 0, sin(ang) * 4.5)
		if _open(a, p):
			a.spawn_holes.append(p)
	for z in [-9.0, -13.5, -16.5]:
		for x in [-1.8, 1.8]:
			var p := Vector3(x, 0, z)
			if _open(a, p):
				a.spawn_holes.append(p)


static func _open(a: Arena, p: Vector3) -> bool:
	var k: int = a.terrain.kind_at(p)
	return (k == Terrain.ICE or k == Terrain.DRY) and not a.blocked(p, 0.8)
