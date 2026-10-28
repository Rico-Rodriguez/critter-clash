extends RefCounted
## Low-poly pieces for the Cinder Mire, built in code like kit_mesh.gd: flat-shaded,
## opaque, vertex-coloured, batched with MultiMesh. Weathered boardwalk planks,
## piles, a stilt shack, the Pyre Tree, braziers, reeds and bog stones.
## Preloaded by path, no class_name. Crisp PBR: no tint, no fog.

const Kit := preload("res://src/hunt/kit_mesh.gd")

const WOOD := Color(0.24, 0.16, 0.105)
const WOOD2 := Color(0.19, 0.13, 0.09)
const GREY := Color(0.2, 0.19, 0.18)
const CHAR := Color(0.1, 0.09, 0.085)
const EMBER := Color(1.0, 0.42, 0.08)
const IRON := Color(0.16, 0.16, 0.17)


static func mat(id: String, rough := 0.88) -> StandardMaterial3D:
	return Kit.mat("mire_" + id, rough)


## The same wood, burnt: darker, with an ember glow underneath.
static func charred_mat() -> StandardMaterial3D:
	var m := Kit.mat("mire_charred", 0.95, 0.0, Color(1.0, 0.35, 0.06), 0.55)
	m.albedo_color = Color(0.32, 0.3, 0.3)
	return m


static func _box(vs: PackedVector3Array, cs: PackedColorArray, c: Vector3, half: Vector3, col: Color) -> void:
	var p: Array = []
	for i in 8:
		p.append(c + Vector3(half.x * (1.0 if i & 1 else -1.0), half.y * (1.0 if i & 2 else -1.0), half.z * (1.0 if i & 4 else -1.0)))
	for f: Array in [[0, 1, 3, 2], [4, 6, 7, 5], [0, 2, 6, 4], [1, 5, 7, 3], [2, 3, 7, 6], [0, 4, 5, 1]]:
		Kit._tri(vs, cs, p[f[0]], p[f[1]], p[f[2]], col, col, col)
		Kit._tri(vs, cs, p[f[0]], p[f[2]], p[f[3]], col, col, col)


## A tapered prism from `a` to `b`: a limb, a pile, a post.
static func _limb(vs: PackedVector3Array, cs: PackedColorArray, rng: RandomNumberGenerator, a: Vector3, b: Vector3, ra: float, rb: float, ca: Color, cb: Color, sides := 4) -> void:
	var axis := (b - a).normalized()
	var side := axis.cross(Vector3.UP if absf(axis.y) < 0.95 else Vector3.RIGHT).normalized()
	var fwd := axis.cross(side)
	var lo: Array = []
	var hi: Array = []
	for i in sides:
		var ang := TAU * float(i) / sides + rng.randf_range(-0.15, 0.15)
		var d := side * cos(ang) + fwd * sin(ang)
		lo.append(a + d * ra)
		hi.append(b + d * rb)
	for i in sides:
		var j := (i + 1) % sides
		var v := rng.randf_range(0.9, 1.1)
		var c0 := Color(ca.r * v, ca.g * v, ca.b * v).lerp(cb, 0.0)
		var c1 := Color(cb.r * v, cb.g * v, cb.b * v)
		Kit._tri(vs, cs, lo[i], lo[j], hi[j], c0, c0, c1)
		Kit._tri(vs, cs, lo[i], hi[j], hi[i], c0, c1, c1)


## One 2 x 2 m piece of boardwalk: four boards on two bearers, a hand's breadth
## above the bog. Boards run along x; rotate the node for the other way.
static func plank_deck(seed_: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_
	var vs := PackedVector3Array()
	var cs := PackedColorArray()
	for i in 4:
		var z := -0.75 + float(i) * 0.5
		var col := WOOD if (i + seed_) % 2 == 0 else WOOD2
		var len := 1.0 - rng.randf_range(0.0, 0.05)
		_box(vs, cs, Vector3(rng.randf_range(-0.03, 0.03), 0.17, z), Vector3(len, 0.045, 0.22), col)
	for sx in [-0.62, 0.62]:
		_box(vs, cs, Vector3(sx, 0.09, 0.0), Vector3(0.1, 0.07, 1.0), CHAR)
	return Kit.finish(vs, cs)


## A pile driven into the bog, about 1.5 m, tapering, with a worn head.
static func pile(seed_: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_
	var vs := PackedVector3Array()
	var cs := PackedColorArray()
	_limb(vs, cs, rng, Vector3(0, -0.2, 0), Vector3(rng.randf_range(-0.05, 0.05), 1.5, 0), 0.13, 0.1, CHAR, WOOD2, 5)
	return Kit.finish(vs, cs)


## A stilt shack: four piles, a floor, plank walls, a sheet-iron roof, a dark door.
## About 3 x 3.2 x 2.2, door toward +z.
static func shack(seed_: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_
	var vs := PackedVector3Array()
	var cs := PackedColorArray()
	for sx in [-1.2, 1.2]:
		for sz in [-1.0, 1.0]:
			_limb(vs, cs, rng, Vector3(sx, -0.1, sz), Vector3(sx, 0.9, sz), 0.12, 0.1, CHAR, WOOD2, 5)
	_box(vs, cs, Vector3(0, 0.95, 0), Vector3(1.5, 0.06, 1.25), WOOD2)
	var wall := WOOD
	_box(vs, cs, Vector3(-1.4, 1.65, 0), Vector3(0.05, 0.7, 1.15), wall)
	_box(vs, cs, Vector3(1.4, 1.65, 0), Vector3(0.05, 0.7, 1.15), wall)
	_box(vs, cs, Vector3(0, 1.65, -1.15), Vector3(1.4, 0.7, 0.05), WOOD2)
	_box(vs, cs, Vector3(-0.85, 1.65, 1.15), Vector3(0.55, 0.7, 0.05), wall)
	_box(vs, cs, Vector3(0.85, 1.65, 1.15), Vector3(0.55, 0.7, 0.05), wall)
	_box(vs, cs, Vector3(0, 2.0, 1.14), Vector3(0.32, 0.35, 0.03), Color(0.04, 0.035, 0.03))
	# A pitched roof of rusted sheets, overhanging.
	var r0 := Vector3(-1.75, 2.0, -1.5)
	var r1 := Vector3(1.75, 2.0, -1.5)
	var r2 := Vector3(1.75, 2.0, 1.5)
	var r3 := Vector3(-1.75, 2.0, 1.5)
	var m0 := Vector3(-1.75, 2.55, 0)
	var m1 := Vector3(1.75, 2.55, 0)
	var rust := Color(0.34, 0.2, 0.14)
	var rust2 := Color(0.26, 0.17, 0.13)
	Kit._tri(vs, cs, r0, r1, m1, rust, rust, rust2)
	Kit._tri(vs, cs, r0, m1, m0, rust, rust2, rust2)
	Kit._tri(vs, cs, r3, m0, m1, rust, rust2, rust2)
	Kit._tri(vs, cs, r3, m1, r2, rust, rust2, rust)
	# A ladder up to the door.
	for sx in [-0.3, 0.3]:
		_limb(vs, cs, rng, Vector3(sx, 0, 1.9), Vector3(sx, 0.95, 1.3), 0.04, 0.04, WOOD2, WOOD2, 4)
	return Kit.finish(vs, cs)


## The Pyre Tree: a huge dead tree, bark black, limbs splayed like fingers, a seam of
## ember in the trunk. About 9 m tall. The flames on it are particles, added by the arena.
static func pyre_tree(seed_: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_
	var vs := PackedVector3Array()
	var cs := PackedColorArray()
	var base := Vector3.ZERO
	var tops: Array = []
	var prev := base
	var r := 1.05
	for k in 4:
		var f := float(k + 1) / 4.0
		var nxt := Vector3(sin(f * 2.1) * 0.55, f * 5.2, cos(f * 1.7) * 0.35)
		_limb(vs, cs, rng, prev, nxt, r, r * 0.74, CHAR, GREY, 7)
		prev = nxt
		r *= 0.74
		tops.append(nxt)
	# Root flares.
	for i in 6:
		var ang := TAU * float(i) / 6.0 + rng.randf() * 0.4
		var d := Vector3(cos(ang), 0, sin(ang))
		_limb(vs, cs, rng, d * 0.5 + Vector3(0, 1.0, 0), d * 2.1 + Vector3(0, -0.1, 0), 0.4, 0.14, GREY, CHAR, 4)
	# Limbs: out and up from the upper trunk, each forking once.
	for i in 7:
		var ang := TAU * float(i) / 7.0 + rng.randf() * 0.5
		var d := Vector3(cos(ang), 0, sin(ang))
		var from: Vector3 = tops[2 + (i % 2)]
		var mid := from + d * rng.randf_range(1.4, 2.0) + Vector3(0, rng.randf_range(0.8, 1.4), 0)
		var tip := mid + d * rng.randf_range(1.2, 1.8) + Vector3(0, rng.randf_range(1.2, 2.2), 0)
		_limb(vs, cs, rng, from, mid, 0.34, 0.2, GREY, CHAR, 4)
		_limb(vs, cs, rng, mid, tip, 0.2, 0.06, CHAR, GREY, 4)
		var side := d.cross(Vector3.UP) * rng.randf_range(-1.0, 1.0)
		_limb(vs, cs, rng, mid, mid + side * 1.2 + Vector3(0, 1.4, 0), 0.14, 0.04, CHAR, GREY, 3)
	# The ember seam: a few thin glowing wedges up the trunk's front.
	for k in 3:
		var y0 := 0.6 + float(k) * 1.5
		var a := Vector3(0.0, y0, 1.0 - 0.04 * k)
		var b := Vector3(0.12, y0 + 1.0, 0.86)
		var w := Vector3(0.1, 0, 0)
		Kit._tri(vs, cs, a - w, a + w, b, EMBER, EMBER, EMBER)
	return Kit.finish(vs, cs)


## A standing iron brazier: three legs and a bowl of coals. About 1.1 m.
static func brazier(seed_: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_
	var vs := PackedVector3Array()
	var cs := PackedColorArray()
	for i in 3:
		var ang := TAU * float(i) / 3.0 + 0.4
		var d := Vector3(cos(ang), 0, sin(ang))
		_limb(vs, cs, rng, d * 0.42, d * 0.16 + Vector3(0, 0.75, 0), 0.04, 0.04, IRON, IRON, 4)
	var rim := Kit._ring(rng, 8, 0.46, 0.04, 0.9)
	var low := Kit._ring(rng, 8, 0.2, 0.0, 0.62)
	Kit._band(vs, cs, rng, low, rim, IRON, IRON, IRON)
	var coals := Kit._ring(rng, 8, 0.4, 0.05, 0.86)
	var mid := Vector3(0, 0.98, 0)
	for i in 8:
		var j := (i + 1) % 8
		Kit._tri(vs, cs, coals[i], coals[j], mid, EMBER, EMBER, Color(1.0, 0.7, 0.2))
	return Kit.finish(vs, cs)


## A tuft of reeds, burnt to brown: thin leaning blades and a few seed heads. About 1.1 m.
static func reeds(seed_: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_
	var vs := PackedVector3Array()
	var cs := PackedColorArray()
	for i in 9:
		var ang := rng.randf() * TAU
		var foot := Vector3(cos(ang), 0, sin(ang)) * rng.randf_range(0.05, 0.4)
		var lean := Vector3(rng.randf_range(-0.3, 0.3), 0, rng.randf_range(-0.3, 0.3))
		var tip := foot + lean + Vector3(0, rng.randf_range(0.7, 1.2), 0)
		var w := Vector3(cos(ang + 1.6), 0, sin(ang + 1.6)) * 0.035
		var col := Color(0.27, 0.22, 0.12).lerp(Color(0.38, 0.3, 0.16), rng.randf())
		Kit._tri(vs, cs, foot - w, foot + w, tip, col, col, col.darkened(0.2))
		if i % 3 == 0:
			_limb(vs, cs, rng, tip - Vector3(0, 0.22, 0), tip, 0.04, 0.03, Color(0.2, 0.12, 0.08), Color(0.2, 0.12, 0.08), 4)
	return Kit.finish(vs, cs)


## A bog stone: low, lumpy, soot-dark with a paler crown. About 1 m.
static func stone(seed_: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_
	var vs := PackedVector3Array()
	var cs := PackedColorArray()
	var rock := Color(0.2, 0.2, 0.21)
	var rock_low := Color(0.12, 0.115, 0.12)
	var crown := Color(0.3, 0.29, 0.28)
	var r0 := Kit._ring(rng, 8, 0.55, 0.18, 0.0)
	var r1 := Kit._ring(rng, 8, 0.46, 0.2, 0.42, Vector2.ZERO, 0.3)
	var r2 := Kit._ring(rng, 8, 0.2, 0.2, 0.62, Vector2(0.04, -0.03), 0.6)
	Kit._band(vs, cs, rng, r0, r1, rock, rock, rock_low)
	Kit._band(vs, cs, rng, r1, r2, crown, rock, rock_low)
	var top := Vector3(0.04, 0.66, -0.03)
	for i in 8:
		var j := (i + 1) % 8
		Kit._faced(vs, cs, rng, r2[i], r2[j], top, crown, crown, crown)
	return Kit.finish(vs, cs)

