extends RefCounted
## Low-poly pieces for the zone kits, built in code: flat-shaded, opaque,
## coloured per vertex (snow on whatever faces up, rock or wood on the rest).
## Each builder returns an ArrayMesh; the zone batches them with MultiMesh.
## Preloaded by path, no class_name. Crisp PBR: the material only carries
## roughness and, for crystal, a faint glow; there is no tint or fog.

static var _mats := {}

const SNOW := Color(0.93, 0.96, 1.0)
const ROCK := Color(0.36, 0.45, 0.58)
const ROCK_DARK := Color(0.24, 0.31, 0.42)


## A vertex-coloured opaque material. `id` caches it.
static func mat(id: String, rough := 0.8, metal := 0.0, glow := Color(0, 0, 0), glow_e := 0.0, spec := 0.5) -> StandardMaterial3D:
	if _mats.has(id):
		return _mats[id]
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.roughness = rough
	m.metallic = metal
	m.metallic_specular = spec
	if glow_e > 0.0:
		m.emission_enabled = true
		m.emission = glow
		m.emission_energy_multiplier = glow_e
	_mats[id] = m
	return m


## Flat-shaded mesh from a triangle list and per-vertex colours.
static func finish(vs: PackedVector3Array, cs: PackedColorArray) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in vs.size():
		st.set_color(cs[i])
		st.add_vertex(vs[i])
	st.generate_normals()
	return st.commit()


static func _tri(vs: PackedVector3Array, cs: PackedColorArray, a: Vector3, b: Vector3, c: Vector3, ca: Color, cb: Color, cc: Color) -> void:
	vs.append(a)
	vs.append(b)
	vs.append(c)
	cs.append(ca)
	cs.append(cb)
	cs.append(cc)


## A triangle coloured by what it faces: `top` where it points up, else `side`
## darkened a little toward the ground, with a touch of per-face variation.
static func _faced(vs: PackedVector3Array, cs: PackedColorArray, rng: RandomNumberGenerator, a: Vector3, b: Vector3, c: Vector3, top: Color, side: Color, side_low: Color, snow_at := 0.55) -> void:
	var n := (b - a).cross(c - a).normalized()
	var base: Color
	if absf(n.y) > snow_at:
		base = top
	else:
		var h := clampf(((a.y + b.y + c.y) / 3.0) / 4.0, 0.0, 1.0)
		base = side_low.lerp(side, h)
	var v := rng.randf_range(0.9, 1.08)
	var col := Color(minf(base.r * v, 1.0), minf(base.g * v, 1.0), minf(base.b * v, 1.0))
	_tri(vs, cs, a, b, c, col, col, col)


## A ring of `n` points at height `y`, radius `r` jittered by `jit`, offset in xz.
static func _ring(rng: RandomNumberGenerator, n: int, r: float, jit: float, y: float, off := Vector2.ZERO, phase := 0.0) -> Array:
	var out: Array = []
	for i in n:
		var ang := phase + TAU * float(i) / n
		var rr := r * (1.0 + rng.randf_range(-jit, jit))
		out.append(Vector3(off.x + cos(ang) * rr, y, off.y + sin(ang) * rr))
	return out


## Joins two same-length rings with quads.
static func _band(vs: PackedVector3Array, cs: PackedColorArray, rng: RandomNumberGenerator, lo: Array, hi: Array, top: Color, side: Color, side_low: Color) -> void:
	var n := lo.size()
	for i in n:
		var j := (i + 1) % n
		_faced(vs, cs, rng, lo[i], lo[j], hi[j], top, side, side_low)
		_faced(vs, cs, rng, lo[i], hi[j], hi[i], top, side, side_low)


## A glacier chunk: three jagged rings narrowing to a snowy crown. About 1 unit
## wide at `size` 1; tall and angular. `peak` offsets the crown for a leaning top.
static func cliff(seed_: int, size := 1.0, height := 1.0, sides := 9) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_
	var vs := PackedVector3Array()
	var cs := PackedColorArray()
	var r0 := _ring(rng, sides, 1.0 * size, 0.18, 0.0)
	var r1 := _ring(rng, sides, 0.86 * size, 0.2, 1.8 * height, Vector2(rng.randf_range(-0.12, 0.12), rng.randf_range(-0.12, 0.12)) * size, 0.15)
	var r2 := _ring(rng, sides, 0.62 * size, 0.22, 3.2 * height, Vector2(rng.randf_range(-0.2, 0.2), rng.randf_range(-0.2, 0.2)) * size, 0.3)
	_band(vs, cs, rng, r0, r1, SNOW, ROCK, ROCK_DARK)
	_band(vs, cs, rng, r1, r2, SNOW, ROCK, ROCK_DARK)
	var crown := Vector3(rng.randf_range(-0.25, 0.25) * size, 3.9 * height, rng.randf_range(-0.25, 0.25) * size)
	for i in sides:
		var j := (i + 1) % sides
		var a: Vector3 = r2[i]
		var b: Vector3 = r2[j]
		_faced(vs, cs, rng, a, b, crown, SNOW, ROCK, ROCK_DARK, 0.2)
	return finish(vs, cs)


## A cluster of leaning six-sided crystals around one tall spire. Pale tips,
## teal bases; the whole mesh is one draw.
static func crystals(seed_: int, size := 1.0) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_
	var vs := PackedVector3Array()
	var cs := PackedColorArray()
	_crystal(vs, cs, rng, Vector3.ZERO, 0.0, 0.0, 0.42 * size, 3.0 * size)
	var n := rng.randi_range(3, 5)
	var yaw0 := rng.randf() * TAU
	for k in n:
		var ang := yaw0 + TAU * k / n + rng.randf_range(-0.3, 0.3)
		var s := size * rng.randf_range(0.45, 0.8)
		var at := Vector3(cos(ang), 0, sin(ang)) * 0.5 * size
		_crystal(vs, cs, rng, at, ang, rng.randf_range(0.3, 0.55), 0.34 * s, 2.4 * s)
	return finish(vs, cs)


static func _crystal(vs: PackedVector3Array, cs: PackedColorArray, rng: RandomNumberGenerator, at: Vector3, yaw: float, lean: float, r: float, h: float) -> void:
	var sides := 6
	var bas := Basis(Vector3(sin(yaw), 0, -cos(yaw)), lean) if lean != 0.0 else Basis.IDENTITY
	var base: Array = []
	var mid: Array = []
	for i in sides:
		var ang := TAU * i / sides
		base.append(at + bas * Vector3(cos(ang) * r, -0.15, sin(ang) * r))
		mid.append(at + bas * Vector3(cos(ang) * r * 0.92, h * 0.68, sin(ang) * r * 0.92))
	var tip := at + bas * Vector3(0, h, 0)
	var c_base := Color(0.36, 0.7, 0.86)
	var c_mid := Color(0.7, 0.9, 1.0)
	var c_tip := Color(0.95, 0.99, 1.0)
	for i in sides:
		var j := (i + 1) % sides
		var v := rng.randf_range(0.9, 1.06)
		var cb := Color(c_base.r * v, c_base.g * v, c_base.b * v)
		var cm := Color(minf(c_mid.r * v, 1.0), minf(c_mid.g * v, 1.0), minf(c_mid.b * v, 1.0))
		var ct := Color(minf(c_tip.r * v, 1.0), minf(c_tip.g * v, 1.0), minf(c_tip.b * v, 1.0))
		_tri(vs, cs, base[i], base[j], mid[j], cb, cb, cm)
		_tri(vs, cs, base[i], mid[j], mid[i], cb, cm, cm)
		_tri(vs, cs, mid[i], mid[j], tip, cm, cm, ct)


## A block of ice for walls: five faces of clear ice with a ragged top.
static func ice_block(seed_: int, w := 2.0, h := 2.8) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_
	var vs := PackedVector3Array()
	var cs := PackedColorArray()
	var lo := _ring(rng, 6, w * 0.62, 0.06, 0.0)
	var hi := _ring(rng, 6, w * 0.5, 0.12, h * 0.85, Vector2.ZERO, 0.2)
	var top := Vector3(rng.randf_range(-0.2, 0.2), h, rng.randf_range(-0.2, 0.2))
	var low := Color(0.45, 0.75, 0.92)
	var up := Color(0.88, 0.96, 1.0)
	var n := lo.size()
	for i in n:
		var j := (i + 1) % n
		var v := rng.randf_range(0.92, 1.06)
		var cl := Color(low.r * v, low.g * v, low.b * v)
		var cu := Color(minf(up.r * v, 1.0), minf(up.g * v, 1.0), minf(up.b * v, 1.0))
		_tri(vs, cs, lo[i], lo[j], hi[j], cl, cl, cu)
		_tri(vs, cs, lo[i], hi[j], hi[i], cl, cu, cu)
		_tri(vs, cs, hi[i], hi[j], top, cu, cu, Color(1, 1, 1))
	return finish(vs, cs)


## A snowy pine: stacked skirts of dark green, white on the faces that look up.
static func pine(seed_: int, height := 1.0) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_
	var vs := PackedVector3Array()
	var cs := PackedColorArray()
	var green := Color(0.1, 0.24, 0.17)
	var green_low := Color(0.07, 0.17, 0.13)
	var trunk := Color(0.22, 0.15, 0.1)
	# Trunk.
	var t0 := _ring(rng, 5, 0.22, 0.05, 0.0)
	var t1 := _ring(rng, 5, 0.18, 0.05, 1.2 * height)
	_band(vs, cs, rng, t0, t1, trunk, trunk, trunk)
	var tiers := 4
	for k in tiers:
		var f := float(k) / tiers
		var y0 := (0.9 + f * 2.5) * height
		var r := (1.55 - f * 1.05)
		var rim := _ring(rng, 8, r, 0.1, y0, Vector2.ZERO, rng.randf() * 0.5)
		var under := Vector3(0, y0 + 0.25 * height, 0)
		var tip := Vector3(0, y0 + 1.55 * height * (1.0 - 0.15 * f), 0)
		var n := rim.size()
		for i in n:
			var j := (i + 1) % n
			_faced(vs, cs, rng, rim[i], rim[j], tip, SNOW, green, green_low, 0.72)
			_faced(vs, cs, rng, rim[j], rim[i], under, green_low, green_low, green_low)
	return finish(vs, cs)


## A low hut: plank walls, a snow roof and a dark door. About 3 x 2.4 x 2.2.
static func hut(seed_: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_
	var vs := PackedVector3Array()
	var cs := PackedColorArray()
	var wood := Color(0.34, 0.22, 0.14)
	var wood2 := Color(0.27, 0.17, 0.11)
	var hw := 1.5
	var hd := 1.2
	var wh := 1.5
	var rh := 2.5
	var p := [Vector3(-hw, 0, -hd), Vector3(hw, 0, -hd), Vector3(hw, 0, hd), Vector3(-hw, 0, hd)]
	var q := [Vector3(-hw, wh, -hd), Vector3(hw, wh, -hd), Vector3(hw, wh, hd), Vector3(-hw, wh, hd)]
	for i in 4:
		var j := (i + 1) % 4
		var cc := wood if i % 2 == 0 else wood2
		_tri(vs, cs, p[i], p[j], q[j], cc, cc, cc)
		_tri(vs, cs, p[i], q[j], q[i], cc, cc, cc)
	var ridge0 := Vector3(-hw - 0.3, rh, 0)
	var ridge1 := Vector3(hw + 0.3, rh, 0)
	var e0 := [Vector3(-hw - 0.3, wh - 0.15, -hd - 0.35), Vector3(hw + 0.3, wh - 0.15, -hd - 0.35)]
	var e1 := [Vector3(-hw - 0.3, wh - 0.15, hd + 0.35), Vector3(hw + 0.3, wh - 0.15, hd + 0.35)]
	_tri(vs, cs, e0[0], e0[1], ridge1, SNOW, SNOW, SNOW)
	_tri(vs, cs, e0[0], ridge1, ridge0, SNOW, SNOW, SNOW)
	_tri(vs, cs, e1[1], e1[0], ridge0, SNOW, SNOW, SNOW)
	_tri(vs, cs, e1[1], ridge0, ridge1, SNOW, SNOW, SNOW)
	# Gable ends.
	_tri(vs, cs, q[0], q[3], ridge0, wood2, wood2, wood2)
	_tri(vs, cs, q[1], ridge1, q[2], wood2, wood2, wood2)
	# Door, a dark square on the south face.
	var door := Color(0.05, 0.04, 0.04)
	var d0 := Vector3(-0.4, 0, hd + 0.02)
	var d1 := Vector3(0.4, 0, hd + 0.02)
	var d2 := Vector3(0.4, 1.15, hd + 0.02)
	var d3 := Vector3(-0.4, 1.15, hd + 0.02)
	_tri(vs, cs, d0, d1, d2, door, door, door)
	_tri(vs, cs, d0, d2, d3, door, door, door)
	return finish(vs, cs)


## A beached longship, lofted from cross-sections: a V hull with a rising prow
## and stern, a broken mast, ribs showing. About 9 long, bow toward +z.
static func longship(seed_: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_
	var vs := PackedVector3Array()
	var cs := PackedColorArray()
	var plank := Color(0.3, 0.19, 0.12)
	var plank2 := Color(0.38, 0.25, 0.15)
	var inner := Color(0.16, 0.1, 0.07)
	var n := 14
	var length := 9.0
	var rows: Array = []
	for i in n + 1:
		var t := float(i) / n
		var z := (t - 0.5) * length
		var beam := pow(sin(PI * clampf(t * 0.96 + 0.02, 0.0, 1.0)), 0.55) * 1.7
		var u := absf(2.0 * t - 1.0)
		var gun := 1.15 + 1.9 * pow(u, 4.0)
		var keel := 0.0 + 0.6 * pow(u, 3.0)
		rows.append([Vector3(-beam, gun, z), Vector3(-beam * 0.45, keel + 0.1, z), Vector3(beam * 0.45, keel + 0.1, z), Vector3(beam, gun, z)])
	for i in n:
		for k in 3:
			var a: Vector3 = rows[i][k]
			var b: Vector3 = rows[i][k + 1]
			var c: Vector3 = rows[i + 1][k + 1]
			var d: Vector3 = rows[i + 1][k]
			var col := plank if (i + k) % 2 == 0 else plank2
			_tri(vs, cs, a, b, c, col, col, col)
			_tri(vs, cs, a, c, d, col, col, col)
			# Inside face, so the open deck reads from above.
			var ia := a + Vector3(0, 0.06, 0)
			_tri(vs, cs, ia, c + Vector3(0, 0.06, 0), b + Vector3(0, 0.06, 0), inner, inner, inner)
			_tri(vs, cs, ia, d + Vector3(0, 0.06, 0), c + Vector3(0, 0.06, 0), inner, inner, inner)
	# Ribs: thin boxes standing from the keel, some broken.
	for i in range(2, n - 1, 2):
		var r: Array = rows[i]
		for side in [-1.0, 1.0]:
			var top: Vector3 = r[3] if side > 0.0 else r[0]
			var foot: Vector3 = r[2] if side > 0.0 else r[1]
			if rng.randf() < 0.3:
				top = foot.lerp(top, 0.5)
			var a := foot + Vector3(0, 0.05, 0)
			var b := top + Vector3(0, 0.55, 0)
			var w := Vector3(0, 0, 0.1)
			_tri(vs, cs, a - w, a + w, b + w, plank2, plank2, plank2)
			_tri(vs, cs, a - w, b + w, b - w, plank2, plank2, plank2)
	# The mast, snapped at head height and leaning.
	var m0 := Vector3(0.1, 0.2, -0.4)
	var m1 := Vector3(0.9, 3.4, -0.1)
	var side_w := Vector3(0.18, 0, 0.18)
	_tri(vs, cs, m0 - side_w, m0 + side_w, m1 + side_w * 0.7, plank, plank, plank2)
	_tri(vs, cs, m0 - side_w, m1 + side_w * 0.7, m1 - side_w * 0.7, plank, plank2, plank2)
	return finish(vs, cs)


## A sled: two runners and a deck. About 2 x 0.5 x 0.9.
static func sled() -> ArrayMesh:
	var vs := PackedVector3Array()
	var cs := PackedColorArray()
	var wood := Color(0.32, 0.2, 0.12)
	var iron := Color(0.3, 0.32, 0.36)
	for s in [-0.4, 0.4]:
		var a := Vector3(-1.0, 0.0, s)
		var b := Vector3(1.0, 0.0, s)
		var c := Vector3(1.25, 0.4, s)
		var d := Vector3(-1.0, 0.18, s)
		var w := Vector3(0, 0, 0.05)
		_tri(vs, cs, a - w, b - w, c - w, iron, iron, iron)
		_tri(vs, cs, a - w, c - w, d - w, iron, iron, iron)
		_tri(vs, cs, a + w, c + w, b + w, iron, iron, iron)
		_tri(vs, cs, a + w, d + w, c + w, iron, iron, iron)
	var p0 := Vector3(-0.9, 0.2, -0.5)
	var p1 := Vector3(0.9, 0.2, -0.5)
	var p2 := Vector3(0.9, 0.2, 0.5)
	var p3 := Vector3(-0.9, 0.2, 0.5)
	_tri(vs, cs, p0, p3, p2, wood, wood, wood)
	_tri(vs, cs, p0, p2, p1, wood, wood, wood)
	return finish(vs, cs)


## One MultiMesh node (one draw) of `xfs` copies of `mesh`.
static func batch(parent: Node3D, mesh: Mesh, material: Material, xfs: Array, shadow := true) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xfs.size()
	for i in xfs.size():
		mm.set_instance_transform(i, xfs[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = material
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mmi)
	return mmi
