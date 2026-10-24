extends RefCounted
## The Gilded Vault: the Barrow King's treasury, from the KayKit dungeon tiles.
## The Crypt's walls and floor, then rows of columns instead of barriers (wide
## lanes for the horde), the King's hoard at the north end and treasure piled
## along the walls. Props are unmodified KayKit models.

const D := "res://assets/kaykit/dungeon/"


static func build(a: Arena) -> void:
	a.start = Vector3(0, 0, 15)
	a.boss_spawn = Vector3(0, 0, -22.0)
	a.crypt_pos = Vector3(0, 0, -28.0)
	DepthsLayout._floor(a)
	DepthsLayout._walls(a)
	_columns(a)
	_hoard(a)
	DepthsLayout._shrines(a)
	_treasure(a)
	DepthsLayout._spawn_spots(a)


## Two rows of columns down each side: cover to kite around, lanes between.
static func _columns(a: Arena) -> void:
	for z in [8.0, 0.0, -8.0, -16.0]:
		for x in [-12.0, 12.0]:
			a.put(D + "pillar_decorated.gltf", Vector3(x, 0, z), 0.0, 0.9, 1.0, true, 1.2)
	for x in [-18.0, -6.0, 6.0, 18.0]:
		a.put(D + "banner_patternA_yellow.gltf", Vector3(x, 0.4, a.min_z - 0.5), 0.0, 1.2, -1.0, false)


## The King's hoard: a gold chest on the grate, coins in a ring, a warm light.
static func _hoard(a: Arena) -> void:
	a.put(D + "floor_tile_extralarge_grates.gltf", Vector3(0, 0, -24.0), 0.0, 1.0, -1.0, false)
	a.put(D + "chest_gold.gltf", Vector3(0, 0, -27.0), 0.0, 1.4, 1.0)
	a._light(Vector3(0, 2.4, -24.0), Color(1.0, 0.8, 0.45), 2.4, 11.0, false)
	for k in 8:
		var ang := TAU * k / 8.0
		var p := Vector3(sin(ang), 0, cos(ang)) * 5.2 + Vector3(0, 0, -24.0)
		a.put(D + ("coin_stack_large.gltf" if k % 2 == 0 else "coin_stack_medium.gltf"), p, ang, 1.4, -1.0, false)


## Treasure along the walls: chests, coin piles, gilded arms, a few crates.
static func _treasure(a: Arena) -> void:
	for c in [Vector3(-18.5, 0, 16.5), Vector3(18.5, 0, 17.5), Vector3(-18.8, 0, -1.0), Vector3(19.0, 0, -21.0), Vector3(-19.0, 0, -20.0)]:
		a.put(D + "chest_gold.gltf", c, -signf(c.x) * PI * 0.5, 1.1, 0.9)
		a.put(D + "coin_stack_large.gltf", c + Vector3(0, 0, 1.8), a._rng.randf() * TAU, 1.2, -1.0, false)
		a.put(D + "sword_shield_gold.gltf", c + Vector3(0, 0, -1.8), -signf(c.x) * PI * 0.5, 1.0, -1.0, false)
	for c in [Vector3(19.0, 0, -28.5), Vector3(-18.5, 0, -28.5), Vector3(18.8, 0, 6.0)]:
		a.put(D + "crates_stacked.gltf", c, a._rng.randf() * TAU, 1.0, 1.1, true, 1.1)
	for i in 18:
		a.put(D + ["coin.gltf", "coin_stack_small.gltf", "coin_stack_small.gltf"][a._rng.randi() % 3], a._free_spot(0.4), a._rng.randf() * TAU, 1.2, -1.0, false)
