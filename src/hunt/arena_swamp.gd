extends RefCounted
## The Burning Swamp: a drowned graveyard set alight. Soot-black stone and
## charred trees, bog pools that suck at your feet, glowing methane vents that
## erupt, and burning stumps for light. Unmodified PBR, no fog, no bloom: the
## fire is small hard particles and lit surfaces, never haze.

const G := "res://assets/kaykit/graveyard/"
const F := "res://assets/kaykit/forest/"
const Art := preload("res://src/hunt/biome_art.gd")
const FIRE := Color(1.0, 0.55, 0.2)


static func build(a: Arena) -> void:
	a.start = Vector3(0, 0, 15)
	a.boss_spawn = Vector3(0, 0, -21.0)
	a.crypt_pos = Vector3(0, 0, -26.5)
	_lair(a)
	_perimeter(a)
	_shrines(a)
	_bog(a)
	_fires(a)
	_dressing(a)
	Art.scorch(a, [Vector3(-14, 0, 1), Vector3(14.5, 0, 5), Vector3(-9.5, 0, -22), Vector3(15, 0, -22), Vector3(-6.5, 0, 14.5), Vector3(6, 0, -3), Vector3(a.crypt_pos.x, 0, a.crypt_pos.z + 5.5)], 1.6)
	_spawn_spots(a)
	a._forest([G + "tree_dead_large.gltf", G + "tree_dead_medium.gltf", G + "tree_dead_large_decorated.gltf",
		F + "Tree_Bare_1_A_Color1.gltf", F + "Tree_Bare_2_A_Color1.gltf", F + "Tree_Bare_1_A_Color1.gltf", G + "tree_dead_medium.gltf"])


## The Ogre's den: a scorched crypt with a red glow in its doorway.
static func _lair(a: Arena) -> void:
	var c := a.crypt_pos
	a.put(G + "crypt.gltf", c, 0.0, 1.9, -1.0, true, 2.4)
	a._light(c + Vector3(0, 2.2, 3.6), FIRE, 2.8, 10.0, true)
	for sx in [-1.0, 1.0]:
		a.put(G + "post_skull.gltf", c + Vector3(4.6 * sx, 0, 3.2), 0.0, 1.3, 0.3, true, 0.8)
		a.put(G + "pillar.gltf", c + Vector3(6.5 * sx, 0, 4.5), 0.0, 1.4, 0.5, true, 1.0)


static func _perimeter(a: Arena) -> void:
	a._fence_line(Vector3(a.min_x - 0.6, 0, a.max_z + 0.6), Vector3(-3.2, 0, a.max_z + 0.6))
	a._fence_line(Vector3(3.2, 0, a.max_z + 0.6), Vector3(a.max_x + 0.6, 0, a.max_z + 0.6))
	a._fence_line(Vector3(a.min_x - 0.6, 0, a.min_z - 0.6), Vector3(a.max_x + 0.6, 0, a.min_z - 0.6))
	a._fence_line(Vector3(a.min_x - 0.6, 0, a.min_z - 0.6), Vector3(a.min_x - 0.6, 0, a.max_z + 0.6))
	a._fence_line(Vector3(a.max_x + 0.6, 0, a.min_z - 0.6), Vector3(a.max_x + 0.6, 0, a.max_z + 0.6))
	a.put(G + "arch_gate.gltf", Vector3(0, 0, a.max_z + 0.6), 0.0, 1.6, -1.0, true, 3.0)


static func _shrines(a: Arena) -> void:
	for sp in [[Vector3(17.5, 0, -6), -PI * 0.5], [Vector3(-17.5, 0, 6.0), PI * 0.5], [Vector3(17.5, 0, 9.0), -PI * 0.5]]:
		var at: Vector3 = sp[0]
		a.put(G + "shrine_candles.gltf", at, sp[1], 1.4, 1.0, true, 1.2)
		var inward := -signf(at.x)
		var sl := a._light(at + Vector3(inward * 1.0, 1.6, 0), Color(1.0, 0.7, 0.4), 1.6, 6.5)
		a.shrines.append({"pos": at + Vector3(inward * 1.9, 0, 0), "light": sl})
	a.put(G + "bench_decorated.gltf", Vector3(-6, 0, -9.6), 0.0, 1.3, 0.7)


## Bog pools (they drag, and the drowned climb out of them) and methane vents.
static func _bog(a: Arena) -> void:
	var pools: Array = [Vector3(-8, 0, 6), Vector3(7, 0, 8.5), Vector3(-11.5, 0, -6), Vector3(11, 0, -3), Vector3(0, 0, -6), Vector3(-5, 0, -16.5), Vector3(9.5, 0, -16), Vector3(-2, 0, 17.5)]
	Art.mounds(a, "disc", "mud", pools, 2.6)
	for p: Vector3 in pools:
		a.graves.append(p)
	var vents: Array = [Vector3(-3.5, 0, 2), Vector3(4.5, 0, -10.5), Vector3(-14, 0, 12), Vector3(14.5, 0, 14), Vector3(-15, 0, -16)]
	Art.vents(a, vents)
	for v: Vector3 in [vents[0], vents[1]]:
		a._light(v + Vector3(0, 1.2, 0), Color(1.0, 0.45, 0.12), 1.2, 6.0)


## Burning stumps and braziers: the swamp's firelight.
static func _fires(a: Arena) -> void:
	for sp in [Vector3(-14, 0, 1), Vector3(14.5, 0, 5), Vector3(-9.5, 0, -22), Vector3(15, 0, -22), Vector3(-6.5, 0, 14.5), Vector3(6, 0, -3)]:
		a.put(G + "tree_dead_small.gltf", sp, a._rng.randf() * TAU, 1.0, 0.5, true, 0.8)
		Art.flame(a, sp + Vector3(0, 1.1, 0), 0.7)
	for lp in [Vector3(-3.4, 0, a.max_z - 0.6), Vector3(3.4, 0, a.max_z - 0.6)]:
		a.put(G + "lantern_standing.gltf", lp, 0.0, 1.3, 0.3, true, 0.6)
	a._light(Vector3(0, 2.4, a.max_z - 0.6), Color(1.0, 0.6, 0.3), 1.4, 8.0)


static func _dressing(a: Arena) -> void:
	for tp in [Vector3(-17, 0, -2), Vector3(16, 0, 3), Vector3(-17.5, 0, 17), Vector3(17, 0, 17.5), Vector3(-2, 0, -12.5), Vector3(-18, 0, -27), Vector3(18, 0, -27), Vector3(-12, 0, -2), Vector3(12.5, 0, -10)]:
		var tn: String = ["tree_dead_large.gltf", "tree_dead_large_decorated.gltf", "tree_dead_medium.gltf"][a._rng.randi() % 3]
		a.put(G + tn, tp, a._rng.randf() * TAU, a._rng.randf_range(1.3, 1.7), 0.45, true, 1.2)
	a._plot(Vector3(-12.5, 0, -17), 3, 2, 0.0)
	a._plot(Vector3(13, 0, 12), 2, 2, 0.0)
	for i in 20:
		var bn: String = ["bone_A.gltf", "bone_B.gltf", "bone_C.gltf", "skull.gltf", "ribcage.gltf", "skull.gltf"][a._rng.randi() % 6]
		a.put(G + bn, a._free_spot(0.5), a._rng.randf() * TAU, a._rng.randf_range(0.8, 1.1), -1.0, false)
	for i in 10:
		var rn := "Rock_%d_%s_Color1.gltf" % [a._rng.randi_range(1, 3), "ABCDEFGH"[a._rng.randi() % 8]]
		a.put(F + rn, a._free_spot(1.0), a._rng.randf() * TAU, a._rng.randf_range(0.9, 1.5), 0.55)
	for i in 7:
		a.put(F + "Bush_%d_%s_Color1.gltf" % [a._rng.randi_range(3, 4), "ABC"[a._rng.randi() % 3]], a._free_spot(0.5), a._rng.randf() * TAU, a._rng.randf_range(0.8, 1.2), -1.0, false)


## More places for the drowned to rise: scorched earth between the pools.
static func _spawn_spots(a: Arena) -> void:
	for i in 8:
		var p := a._free_spot(0.8)
		a.earth_patch(p, a._rng.randf_range(1.1, 1.5))
		a.graves.append(p)
