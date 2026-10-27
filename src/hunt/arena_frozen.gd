extends RefCounted
## The Frozen Crypt: the barrow's graveyard under a hard winter. The same
## KayKit pieces, recoloured to frost-rimed stone, snow-capped pines and
## white ground; ice crystals for cover, snow drifts that drag at your feet,
## and cold blue light. Unmodified PBR, no fog, no bloom.

const G := "res://assets/kaykit/graveyard/"
const F := "res://assets/kaykit/forest/"
const Art := preload("res://src/hunt/biome_art.gd")
const COLD := Color(0.62, 0.86, 1.0)


static func build(a: Arena) -> void:
	a.start = Vector3(0, 0, 15)
	a.boss_spawn = Vector3(0, 0, -21.0)
	a.crypt_pos = Vector3(0, 0, -26.5)
	_lair(a)
	_perimeter(a)
	_plots(a)
	_shrines(a)
	_lanterns(a)
	_dressing(a)
	_ice(a)
	Art.snow_caps(a)
	Art.ice_sheets(a, [Vector3(-4, 0, 6), Vector3(3, 0, 12), Vector3(-15, 0, 2), Vector3(14, 0, -1), Vector3(5, 0, -20), Vector3(-9, 0, -11), Vector3(15.5, 0, 13), Vector3(-1, 0, -17)])
	_spawn_spots(a)
	a._forest([G + "tree_pine_orange_large.gltf", G + "tree_pine_yellow_large.gltf", G + "tree_pine_orange_medium.gltf",
		G + "tree_pine_yellow_medium.gltf", G + "tree_dead_large.gltf", F + "Tree_Bare_1_A_Color1.gltf", F + "Tree_Bare_2_A_Color1.gltf"])


## The Regent's hall: a rimed crypt under a cold light.
static func _lair(a: Arena) -> void:
	var c := a.crypt_pos
	a.put(G + "crypt.gltf", c, 0.0, 1.9, -1.0, true, 2.4)
	a._light(c + Vector3(0, 2.5, 3.6), COLD, 2.6, 9.5, false)
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


## Snowed-over grave plots: headstones with the odd open grave.
static func _plots(a: Arena) -> void:
	a._plot(Vector3(-12, 0, 8), 3, 4, 0.0)
	a._plot(Vector3(11, 0, 10), 3, 3, 0.0)
	a._plot(Vector3(-12.5, 0, -14), 4, 3, 0.0)
	a._plot(Vector3(12, 0, -14), 4, 3, 0.0)
	a._plot(Vector3(-6, 0, -24), 2, 2, 0.0)
	a._plot(Vector3(8, 0, -24), 2, 2, 0.0)


static func _shrines(a: Arena) -> void:
	for sp in [[Vector3(17.5, 0, -6), -PI * 0.5], [Vector3(-17.5, 0, 6.0), PI * 0.5], [Vector3(17.5, 0, 9.0), -PI * 0.5]]:
		var at: Vector3 = sp[0]
		a.put(G + "shrine_candles.gltf", at, sp[1], 1.4, 1.0, true, 1.2)
		var inward := -signf(at.x)
		var sl := a._light(at + Vector3(inward * 1.0, 1.6, 0), Color(0.7, 0.9, 1.0), 1.6, 6.5)
		a.shrines.append({"pos": at + Vector3(inward * 1.9, 0, 0), "light": sl})
	a.put(G + "bench_decorated.gltf", Vector3(-6, 0, -9.6), 0.0, 1.3, 0.7)
	a.put(G + "bench.gltf", Vector3(7, 0, -10), 0.2, 1.3, 0.7)


static func _lanterns(a: Arena) -> void:
	for lp in [Vector3(-2.6, 0, 9), Vector3(4.2, 0, -1.5), Vector3(-5, 0, -2)]:
		a.put(G + "post_lantern.gltf", lp, a._rng.randf() * TAU, 1.35, 0.3, true, 0.6)
		a._light(lp + Vector3(0, 2.4, 0), Color(0.8, 0.93, 1.0), 1.4, 7.5)


static func _dressing(a: Arena) -> void:
	for tp in [Vector3(-17, 0, -2), Vector3(16, 0, 3), Vector3(-17.5, 0, 17), Vector3(17, 0, 17.5), Vector3(-2, 0, -12.5), Vector3(-18, 0, -27), Vector3(18, 0, -27)]:
		var tn: String = ["tree_dead_large.gltf", "tree_dead_large_decorated.gltf", "tree_dead_medium.gltf"][a._rng.randi() % 3]
		a.put(G + tn, tp, a._rng.randf() * TAU, a._rng.randf_range(1.3, 1.7), 0.45, true, 1.2)
	for i in 22:
		var bn: String = ["bone_A.gltf", "bone_B.gltf", "bone_C.gltf", "skull.gltf", "ribcage.gltf", "skull.gltf"][a._rng.randi() % 6]
		a.put(G + bn, a._free_spot(0.5), a._rng.randf() * TAU, a._rng.randf_range(0.8, 1.1), -1.0, false)
	for cp in [Vector3(5.5, 0, 14), Vector3(-15.5, 0, -8), Vector3(14.5, 0, -20)]:
		a.put(G + ("coffin_decorated.gltf" if a._rng.randf() < 0.5 else "coffin.gltf"), cp, a._rng.randf() * TAU, 1.3, 0.8)
	for i in 8:
		var rn := "Rock_%d_%s_Color1.gltf" % [a._rng.randi_range(1, 3), "ABCDEFGH"[a._rng.randi() % 8]]
		a.put(F + rn, a._free_spot(1.0), a._rng.randf() * TAU, a._rng.randf_range(0.9, 1.5), 0.55)


## Ice crystals (solid cover, some by the cross paths, a ring round the lair)
## and snow drifts (walkable, but they drag).
static func _ice(a: Arena) -> void:
	var spires: Array = []
	for p in [Vector3(-8, 0, 3), Vector3(9, 0, 1), Vector3(-15, 0, -4), Vector3(15.5, 0, -9), Vector3(-3.5, 0, -14), Vector3(5, 0, 15.5), Vector3(-9, 0, 15), Vector3(17, 0, -17), Vector3(-18, 0, -18), Vector3(0, 0, -9)]:
		spires.append(p)
	for sx in [-1.0, 1.0]:
		spires.append(a.crypt_pos + Vector3(10.5 * sx, 0, 3.5))
	Art.crystals(a, spires, 1.0)
	var drifts: Array = [Vector3(-6, 0, 10), Vector3(6.5, 0, 5), Vector3(0, 0, -4.5), Vector3(-10.5, 0, -8), Vector3(10, 0, -4), Vector3(-3.5, 0, 17), Vector3(8, 0, -17), Vector3(-9, 0, -19)]
	Art.mounds(a, "disc", "snow", drifts, 2.6)


## Where the frozen dead climb out: thawed earth by the graves and among the crystals.
static func _spawn_spots(a: Arena) -> void:
	for i in 14:
		var p := a._free_spot(0.8)
		a.graves.append(p)
