extends RefCounted
## The Cinder Mire: a drowned wood alight on its own gas. You land on the south
## island, and the way north is a boardwalk of planks over black bog that drags at
## your feet, between dry islands of soot and ash. The planks and the bog burn:
## a methane vent or a marsh fire lights one cell and the fire runs along the
## wood, a burnt plank drops into the bog, and burnt bog turns to ash that floods
## back after a while. North, a plank deck rings the Cinder Warlord's platform,
## braziers on it and the Pyre Tree, his den, behind.
## The floor is the terrain cell grid (src/hunt/terrain*.gd); planks, piles, the
## shacks, the Pyre Tree, braziers, reeds and stones are code-built low-poly
## meshes (mire_kit.gd) until the art kit lands. Crisp PBR: no fog, no bloom, no tint.

const G := "res://assets/kaykit/graveyard/"
const Terrain := preload("res://src/hunt/terrain.gd")
const Kit := preload("res://src/hunt/mire_kit.gd")
const KitMesh := preload("res://src/hunt/kit_mesh.gd")
const Art := preload("res://src/hunt/biome_art.gd")
const Plank := preload("res://src/hunt/mire_plank.gd")
const FIRE := Color(1.0, 0.55, 0.2)

const DECK := Vector3(0.0, 0.0, -21.0)
const DECK_RX := 7.5
const DECK_RZ := 5.0
## Dry islands: x, z, rx, rz. The first is where you land.
const ISLANDS := [
	[0.0, 16.5, 9.0, 4.2], [-12.0, 7.0, 5.0, 4.0], [12.5, 5.0, 5.5, 4.0], [-1.0, -2.0, 5.0, 3.5],
	[-14.0, -9.0, 4.5, 3.5], [14.0, -10.0, 4.5, 3.5],
]
## Soot and ash, burnt long ago: firm and never flammable.
const ASH := [
	[-6.0, 10.0, 2.5, 2.0], [7.0, -8.0, 3.0, 2.0], [-16.0, -2.0, 2.5, 2.0], [18.0, -1.0, 2.0, 2.5],
	[-8.0, -14.0, 2.5, 2.0], [8.0, -15.0, 2.0, 2.2],
]
## Boardwalks, each a run of plank cells from one island to the next.
const WALKS := [
	[Vector2(-6, 13), Vector2(-10, 9.5)], [Vector2(6, 13), Vector2(10, 9)], [Vector2(0, 12), Vector2(-1, 0.5)],
	[Vector2(-8, 5), Vector2(-4, -1)], [Vector2(9, 3), Vector2(3, -1)], [Vector2(-1, -4), Vector2(0, -17)],
	[Vector2(-13, 3), Vector2(-14, -6)], [Vector2(-11, -11), Vector2(-5, -18)],
	[Vector2(14, 1), Vector2(14, -7)], [Vector2(11, -12), Vector2(5, -18)],
]
const VENTS := [Vector3(-4, 0, -1), Vector3(14, 0, -9), Vector3(-14.5, 0, 8.5), Vector3(15, 0, 3.5), Vector3(-7, 0, 18.5)]
## Shrines: position, yaw. The hero stands a step inward.
const SHRINES := [[Vector3(-17.0, 0, 7.5), PI * 0.5], [Vector3(17.5, 0, 4.5), -PI * 0.5], [Vector3(17.5, 0, -11.0), -PI * 0.5]]
const PYRE := Vector3(0.0, 0, -27.5)


static func build(a: Arena) -> void:
	a.start = Vector3(0, 0, 15)
	a.boss_spawn = DECK
	a.crypt_pos = PYRE
	_ground(a)
	_floor(a)
	_boardwalk(a)
	_pyre(a)
	_shacks(a)
	_perimeter(a)
	_shrines(a)
	_vents(a)
	_braziers(a)
	_scenery(a)
	_spawn_spots(a)
	_foe_spots(a)


# --- The floor -------------------------------------------------------------------

static func _ground(a: Arena) -> void:
	# Scorched soil on the islands; the bog is near black and glossy so the two read
	# apart at a glance.
	var look: Dictionary = {"dark": (a.zone_env["ground"] as Dictionary)["dark"],
		"base_a": Color(0.17, 0.15, 0.125), "base_b": Color(0.27, 0.235, 0.185), "bog_col": Color(0.04, 0.043, 0.035)}
	a.terrain_begin(look)


static func _floor(a: Arena) -> void:
	var t: RefCounted = a.terrain
	for z in t.h:
		for x in t.w:
			t.set_kind(Vector2i(x, z), Terrain.BOG)
	var i := 0
	for p: Array in ASH:
		i += 1
		t.fill_ellipse(Terrain.ASH, p[0], p[1], p[2], p[3], -1, 0.1, 20 + i)
	for p: Array in ISLANDS:
		i += 1
		t.fill_ellipse(Terrain.DRY, p[0], p[1], p[2], p[3], -1, 0.12, 40 + i)
	# The Warlord's platform: dry ground inside a ring of deck, the Pyre Tree on its own apron.
	t.fill_ellipse(Terrain.PLANK, DECK.x, DECK.z, DECK_RX, DECK_RZ, -1, 0.0, 70)
	t.fill_ellipse(Terrain.DRY, DECK.x, DECK.z, DECK_RX * 0.7, DECK_RZ * 0.68, -1, 0.0, 71)
	t.fill_ellipse(Terrain.DRY, PYRE.x, PYRE.z + 0.8, 6.0, 3.4, -1, 0.0, 72)
	for w: Array in WALKS:
		t.fill_line(Terrain.PLANK, w[0], w[1], [Terrain.DRY, Terrain.ASH])
	# Firm footing for what stands on the bog's edge: shrines, vents, the shacks.
	for s: Array in SHRINES:
		var at: Vector3 = s[0]
		t.fill_ellipse(Terrain.DRY, at.x, at.z, 2.6, 2.6, -1, 0.0, 80)
	for v: Vector3 in VENTS:
		t.fill_ellipse(Terrain.ASH, v.x, v.z, 2.3, 2.3, -1, 0.1, 90)
	t.fill_ellipse(Terrain.DRY, PYRE.x, PYRE.z, 3.0, 3.0, -1, 0.0, 91)
	a.terrain_painted()


## One boardwalk piece on every plank cell, registered so fire and collapse find it,
## with piles driven in beside the runs.
static func _boardwalk(a: Arena) -> void:
	var t: RefCounted = a.terrain
	var wood := Kit.mat("wood")
	var burnt := Kit.charred_mat()
	var decks: Array = [Kit.plank_deck(1), Kit.plank_deck(2), Kit.plank_deck(3)]
	var piles: Array = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 6061
	for z in t.h:
		for x in t.w:
			var c := Vector2i(x, z)
			if t.kind_of(c) != Terrain.PLANK:
				continue
			var at: Vector3 = t.center_of(c)
			var along_x: bool = t.kind_of(c + Vector2i(1, 0)) == Terrain.PLANK or t.kind_of(c + Vector2i(-1, 0)) == Terrain.PLANK
			var along_z: bool = t.kind_of(c + Vector2i(0, 1)) == Terrain.PLANK or t.kind_of(c + Vector2i(0, -1)) == Terrain.PLANK
			# Boards lie across the way: for a run along x they turn a quarter.
			var yaw := PI * 0.5 if along_x and not along_z else 0.0
			var n: Node3D = Plank.new()
			n.setup(decks[(x * 3 + z) % 3], wood, burnt)
			n.position = at
			n.rotation.y = yaw + rng.randf_range(-0.03, 0.03)
			a.add_child(n)
			a.plank_nodes[t.idx(c)] = n
			if (x + z) % 2 == 0:
				for s in [-1.0, 1.0]:
					piles.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU), at + _pile_off(yaw, s)))
	KitMesh.batch(a, Kit.pile(7), Kit.mat("wood"), piles)


static func _pile_off(yaw: float, s: float) -> Vector3:
	# Beside the boards' ends: the sides the walkway runs along.
	return Vector3(s * 1.02, 0.0, 0.0) if yaw == 0.0 else Vector3(0.0, 0.0, s * 1.02)


# --- Landmarks ---------------------------------------------------------------------

## The Warlord's den: the Pyre Tree, burning without end, behind the platform, skull
## posts and pillars at its feet, an unburnt giant dead tree each side.
static func _pyre(a: Arena) -> void:
	var tree := MeshInstance3D.new()
	tree.mesh = Kit.pyre_tree(13)
	tree.material_override = Kit.mat("pyre", 0.95)
	tree.position = PYRE
	tree.rotation.y = 0.4
	tree.scale = Vector3.ONE * 1.3
	a.add_child(tree)
	a.add_obstacle(Vector2(PYRE.x, PYRE.z), 2.0)
	for o: Vector3 in [Vector3(0.6, 7.2, 0.4), Vector3(3.0, 9.0, 1.8), Vector3(-2.5, 8.5, -1.7)]:
		Art.flame(a, PYRE + o, 1.5)
	a._light(PYRE + Vector3(0, 6.5, 4.0), FIRE, 3.0, 13.0, true)
	for sx in [-1.0, 1.0]:
		a.put(G + "post_skull.gltf", PYRE + Vector3(4.6 * sx, 0, 2.2), 0.0, 1.3, 0.3, true, 0.8)
		a.put(G + "pillar.gltf", PYRE + Vector3(7.5 * sx, 0, 1.0), 0.0, 1.4, 0.5, true, 1.0)
		a.put(G + "tree_dead_large_decorated.gltf", Vector3(14.0 * sx, 0, -25.0), 1.1 + sx, 1.9, 0.45, true, 1.4)


## Two stilt shacks on the landing island, a lantern each.
static func _shacks(a: Arena) -> void:
	var wood := Kit.mat("wood")
	for s: Array in [[Vector3(-10.5, 0, 17.5), 0.35], [Vector3(11.0, 0, 18.0), -0.4]]:
		var at: Vector3 = s[0]
		var mi := MeshInstance3D.new()
		mi.mesh = Kit.shack(int(at.x))
		mi.material_override = wood
		mi.position = at
		mi.rotation.y = s[1]
		a.add_child(mi)
		a.add_box(Vector2(at.x, at.z), Vector2(1.6, 1.3), s[1])
	for lp in [Vector3(-3.4, 0, 12.4), Vector3(3.4, 0, 12.4)]:
		a.put(G + "lantern_standing.gltf", lp, 0.0, 1.3, 0.3, true, 0.6)
	a._light(Vector3(0, 2.4, 12.4), Color(1.0, 0.6, 0.3), 1.4, 8.0)


static func _perimeter(a: Arena) -> void:
	a._fence_line(Vector3(a.min_x - 0.6, 0, a.max_z + 0.6), Vector3(-3.2, 0, a.max_z + 0.6))
	a._fence_line(Vector3(3.2, 0, a.max_z + 0.6), Vector3(a.max_x + 0.6, 0, a.max_z + 0.6))
	a._fence_line(Vector3(a.min_x - 0.6, 0, a.min_z - 0.6), Vector3(a.max_x + 0.6, 0, a.min_z - 0.6))
	a._fence_line(Vector3(a.min_x - 0.6, 0, a.min_z - 0.6), Vector3(a.min_x - 0.6, 0, a.max_z + 0.6))
	a._fence_line(Vector3(a.max_x + 0.6, 0, a.min_z - 0.6), Vector3(a.max_x + 0.6, 0, a.max_z + 0.6))
	a.put(G + "arch_gate.gltf", Vector3(0, 0, a.max_z + 0.6), 0.0, 1.6, -1.0, true, 3.0)
	a._forest([G + "tree_dead_large.gltf", G + "tree_dead_medium.gltf", G + "tree_dead_large_decorated.gltf", G + "tree_dead_medium.gltf"])


static func _shrines(a: Arena) -> void:
	for sp: Array in SHRINES:
		var at: Vector3 = sp[0]
		a.put(G + "shrine_candles.gltf", at, sp[1], 1.4, 1.0, true, 1.2)
		var inward := -signf(at.x)
		var sl := a._light(at + Vector3(inward * 1.0, 1.6, 0), Color(1.0, 0.7, 0.4), 1.6, 6.5)
		a.shrines.append({"pos": at + Vector3(inward * 1.9, 0, 0), "light": sl})


## Methane vents on pads of ash. They erupt (biome.gd), and an eruption lights the
## bog and planks beside it.
static func _vents(a: Arena) -> void:
	Art.vents(a, VENTS)
	for v: Vector3 in [VENTS[0], VENTS[1]]:
		a._light(v + Vector3(0, 1.2, 0), Color(1.0, 0.45, 0.12), 1.2, 6.0)


## Braziers on the deck round the Warlord's platform: his firelight.
static func _braziers(a: Arena) -> void:
	var iron := Kit.mat("iron", 0.7)
	var xfs: Array = []
	for deg in [165.0, 200.0, 240.0, 300.0, 340.0, 15.0]:
		var ang := deg_to_rad(deg)
		var p := DECK + Vector3(cos(ang) * DECK_RX * 0.84, 0, sin(ang) * DECK_RZ * 0.84)
		xfs.append(Transform3D(Basis(Vector3.UP, ang), p))
		a.add_obstacle(Vector2(p.x, p.z), 0.5)
		Art.flame(a, p + Vector3(0, 1.0, 0), 0.8)
	KitMesh.batch(a, Kit.brazier(5), iron, xfs)
	for p: Vector3 in [DECK + Vector3(-6.0, 1.6, -2.0), DECK + Vector3(6.0, 1.6, -2.0)]:
		a._light(p, FIRE, 1.8, 8.0, true)


# --- Dressing -----------------------------------------------------------------------

## Firm ground (dry or ash) with no plank within a cell, clear of obstacles.
static func _firm(a: Arena, r: float, min_start := 5.0) -> Variant:
	for i in 60:
		var p := Vector3(a._rng.randf_range(a.min_x + 2.0, a.max_x - 2.0), 0, a._rng.randf_range(a.min_z + 3.0, a.max_z - 2.0))
		if not _stands(a, p) or a.blocked(p, r) or p.distance_to(a.start) < min_start:
			continue
		# The shrines and the vents keep their room.
		var crowded := false
		for sp: Array in SHRINES:
			if Vector2(p.x - float((sp[0] as Vector3).x), p.z - float((sp[0] as Vector3).z)).length() < 4.8:
				crowded = true
		for v: Vector3 in VENTS:
			if p.distance_to(v) < 3.2:
				crowded = true
		if crowded:
			continue
		# The platform stays clear for the fight.
		if Vector2((p.x - DECK.x) / (DECK_RX + 1.5), (p.z - DECK.z) / (DECK_RZ + 1.5)).length() < 1.0:
			continue
		var near := false
		for dz in range(-1, 2):
			for dx in range(-1, 2):
				if a.terrain.kind_at(p + Vector3(dx * 2.0, 0, dz * 2.0)) == Terrain.PLANK:
					near = true
		if near:
			continue
		return p
	return null


static func _stands(a: Arena, p: Vector3) -> bool:
	var k: int = a.terrain.kind_at(p)
	return k == Terrain.DRY or k == Terrain.ASH


static func _scenery(a: Arena) -> void:
	# Dead trees on the islands: cover that does not burn.
	for i in 11:
		var p = _firm(a, 1.4)
		if p == null:
			continue
		var tn: String = ["tree_dead_large.gltf", "tree_dead_large_decorated.gltf", "tree_dead_medium.gltf"][a._rng.randi() % 3]
		a.put(G + tn, p, a._rng.randf() * TAU, a._rng.randf_range(1.3, 1.7), 0.45, true, 1.2)
	# Bog stones, solid cover on the firm ground, batched.
	var rocks: Array = []
	for i in 12:
		var p = _firm(a, 1.0)
		if p == null:
			continue
		var s := a._rng.randf_range(0.9, 1.5)
		rocks.append(Transform3D(Basis(Vector3.UP, a._rng.randf() * TAU).scaled(Vector3(s * 1.2, s, s)), p))
		a.add_obstacle(Vector2(p.x, p.z), 0.85 * s)
	KitMesh.batch(a, Kit.stone(3), Kit.mat("stone", 0.9), rocks)
	# Reeds standing in the bog, no collision, one draw.
	var reeds: Array = []
	var tries := 0
	while reeds.size() < 70 and tries < 600:
		tries += 1
		var p := Vector3(a._rng.randf_range(a.min_x, a.max_x), 0, a._rng.randf_range(a.min_z, a.max_z))
		if a.terrain.kind_at(p) != Terrain.BOG:
			continue
		var s := a._rng.randf_range(0.8, 1.4)
		reeds.append(Transform3D(Basis(Vector3.UP, a._rng.randf() * TAU).scaled(Vector3(s, s, s)), p))
	KitMesh.batch(a, Kit.reeds(4), Kit.mat("reeds", 0.95), reeds, false)
	# Bones where the dead lay down.
	for i in 16:
		var p = _firm(a, 0.5, 3.0)
		if p == null:
			continue
		var bn: String = ["bone_A.gltf", "bone_B.gltf", "bone_C.gltf", "skull.gltf", "ribcage.gltf", "skull.gltf"][a._rng.randi() % 6]
		a.put(G + bn, p, a._rng.randf() * TAU, a._rng.randf_range(0.8, 1.1), -1.0, false)


## Where the drowned and the dead come up: firm ground, never on the landing, never
## in front of the tree's roots.
static func _spawn_spots(a: Arena) -> void:
	var n := 0
	var tries := 0
	while n < 16 and tries < 600:
		tries += 1
		var p = _firm(a, 0.8, 7.0)
		if p == null:
			continue
		if p.z > 12.0:
			continue
		a.graves.append(p)
		n += 1


## Perches for the shooters (the shores of the islands, in the open) and holes where
## the bog's foes rise (open bog away from the boardwalk).
static func _foe_spots(a: Arena) -> void:
	for isl: Array in ISLANDS:
		for k in 6:
			var ang := TAU * float(k) / 6.0 + 0.3
			var p := Vector3(float(isl[0]) + cos(ang) * float(isl[2]) * 0.75, 0, float(isl[1]) + sin(ang) * float(isl[3]) * 0.75)
			if _stands(a, p) and not a.blocked(p, 0.8) and p.distance_to(a.start) > 6.0:
				a.perches.append(p)
	var tries := 0
	while a.spawn_holes.size() < 14 and tries < 800:
		tries += 1
		var p := Vector3(a._rng.randf_range(a.min_x + 2.0, a.max_x - 2.0), 0, a._rng.randf_range(a.min_z + 3.0, a.max_z - 3.0))
		if a.terrain.kind_at(p) != Terrain.BOG or a.blocked(p, 0.8) or p.distance_to(a.start) < 9.0:
			continue
		a.spawn_holes.append(p)
