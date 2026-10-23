class_name GroveLayout
extends RefCounted
## The Hollow Grove: an autumn clearing ringed by the wood. Stands of trees
## break the field into lanes, the cult's lanterns mark the paths, and the
## Thornmother waits in a ring of standing stones at the north end. Same
## bounds as the Barrow, so every mode plays here unchanged.

const F := "res://assets/kaykit/forest/"
const G := "res://assets/kaykit/graveyard/"


static func build(a: Arena) -> void:
	a.start = Vector3(0, 0, 15)
	a.boss_spawn = Vector3(0, 0, -21.0)
	a.crypt_pos = Vector3(0, 0, -26.0)
	_stones(a)
	_stands(a)
	_shrines(a)
	_lanterns(a)
	_dressing(a)
	_spawn_spots(a)
	a._forest()
	a._grass()


## The Mother's ring: standing stones around her clearing, lit green.
static func _stones(a: Arena) -> void:
	var c := Vector3(0, 0, -25.0)
	for k in 9:
		var ang := PI * 0.15 + (PI * 1.7) * k / 8.0
		var p := c + Vector3(sin(ang), 0, cos(ang)) * 6.5
		# Leave the south side open: the way in.
		if p.z > c.z + 4.0:
			continue
		var rn := "Rock_%d_%s_Color1.gltf" % [3, "ABCDEFGHIJ"[a._rng.randi() % 10]]
		a.put(F + rn, p, a._rng.randf() * TAU, a._rng.randf_range(1.6, 2.1), 0.8, true, 1.2)
	var gl := a._light(c + Vector3(0, 2.6, 2.0), Color(0.55, 1.0, 0.4), 2.6, 11.0)
	gl.set_meta("flicker", 0.12)
	a.put(G + "shrine.gltf", c + Vector3(0, 0, -3.5), 0.0, 1.6, 1.2, true, 1.4)


## Stands of trees that split the field: cover to kite around, and the dead
## come around them.
static func _stands(a: Arena) -> void:
	var trees := ["Tree_1_A_Color1.gltf", "Tree_2_A_Color1.gltf", "Tree_3_A_Color1.gltf", "Tree_Bare_1_A_Color1.gltf", "Tree_Bare_2_A_Color1.gltf"]
	var pines := ["tree_pine_orange_medium.gltf", "tree_pine_yellow_medium.gltf", "tree_pine_orange_small.gltf"]
	for c in [Vector3(-12, 0, 9), Vector3(11, 0, 11), Vector3(-13, 0, -13), Vector3(12.5, 0, -14), Vector3(-3, 0, -11), Vector3(7, 0, -1)]:
		var n := 2 if absf(c.x) < 6.0 else 3
		for i in n:
			var p: Vector3 = c + Vector3(a._rng.randf_range(-2.2, 2.2), 0, a._rng.randf_range(-2.2, 2.2))
			if a._rng.randf() < 0.6:
				a.put(F + trees[a._rng.randi() % trees.size()], p, a._rng.randf() * TAU, a._rng.randf_range(1.0, 1.4), 0.6)
			else:
				a.put(G + pines[a._rng.randi() % pines.size()], p, a._rng.randf() * TAU, a._rng.randf_range(1.2, 1.6), 0.55)
		for i in 3:
			var bp: Vector3 = c + Vector3(a._rng.randf_range(-3.0, 3.0), 0, a._rng.randf_range(-3.0, 3.0))
			a.put(F + "Bush_%d_%s_Color1.gltf" % [a._rng.randi_range(1, 2), "ABC"[a._rng.randi() % 3]], bp, a._rng.randf() * TAU, a._rng.randf_range(1.1, 1.5), -1.0, false)


static func _shrines(a: Arena) -> void:
	for sp in [[Vector3(17.5, 0, -6), -PI * 0.5], [Vector3(-17.5, 0, 6.0), PI * 0.5], [Vector3(17.5, 0, 9.0), -PI * 0.5]]:
		var at: Vector3 = sp[0]
		a.put(G + "shrine_candles.gltf", at, sp[1], 1.4, 1.0, true, 1.2)
		var inward := -signf(at.x)
		var sl := a._light(at + Vector3(inward * 1.0, 1.6, 0), Color(1.0, 0.7, 0.35), 1.6, 6.5)
		a.shrines.append({"pos": at + Vector3(inward * 1.9, 0, 0), "light": sl})


## The cult keeps lanterns lit along its paths.
static func _lanterns(a: Arena) -> void:
	for lp in [Vector3(-2.6, 0, 9), Vector3(4.2, 0, -1.5), Vector3(-6, 0, -3), Vector3(2.8, 0, -17), Vector3(-3.4, 0, 19.5), Vector3(3.4, 0, 19.5)]:
		a.put(G + "post_lantern.gltf", lp, a._rng.randf() * TAU, 1.35, 0.3, true, 0.6)
		a._light(lp + Vector3(0, 2.4, 0), Color(1.0, 0.62, 0.32), 1.5, 7.5)


static func _dressing(a: Arena) -> void:
	# Pumpkin patches: the Grove's harvest, glowing.
	for i in 6:
		var pp := a._free_spot(1.2)
		for j in 3:
			var q := pp + Vector3(a._rng.randf_range(-1.0, 1.0), 0, a._rng.randf_range(-1.0, 1.0))
			a.put(G + ["pumpkin_orange.gltf", "pumpkin_yellow_small.gltf", "pumpkin_orange_jackolantern.gltf"][j], q, a._rng.randf() * TAU, 1.3, 0.35 if j == 0 else -1.0, false)
		a._light(pp + Vector3(0, 0.8, 0), Color(1.0, 0.5, 0.15), 0.9, 3.5)
	# Rocks.
	for i in 8:
		var rp := a._free_spot(1.0)
		var rn := "Rock_%d_%s_Color1.gltf" % [a._rng.randi_range(1, 2), "ABCDEFGH"[a._rng.randi() % 8]]
		a.put(F + rn, rp, a._rng.randf() * TAU, a._rng.randf_range(0.9, 1.4), 0.55)
	# Fallen leaves of a kind: low bushes everywhere, no collision.
	for i in 20:
		a.put(F + "Bush_%d_%s_Color1.gltf" % [a._rng.randi_range(3, 4), "ABC"[a._rng.randi() % 3]], a._free_spot(0.5), a._rng.randf() * TAU, a._rng.randf_range(0.8, 1.2), -1.0, false)


## Where the cult and its dead come up: turned earth among the roots.
static func _spawn_spots(a: Arena) -> void:
	for i in 16:
		var p := a._free_spot(0.8)
		# Round patches of soil, not KayKit's square dirt tile: its rim sat
		# flush with the ground and flickered, and squares read as glitches.
		a.earth_patch(p, a._rng.randf_range(1.1, 1.5))
		a.graves.append(p)
