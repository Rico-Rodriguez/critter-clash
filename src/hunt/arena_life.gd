extends RefCounted
## Living-world details for an Arena: wind-swayed, trampled grass, footprints
## on the path, props that wobble when fought near, bats overhead and beetles
## that scatter. Everything is instanced (one MultiMesh or one material each)
## so the whole layer costs a handful of draws; nothing allocates per frame.
## No class_name (see CLAUDE.md): Arena preloads this file.

const GRASS := preload("res://src/fx/grass.gdshader")
const PRINT := preload("res://src/fx/footprint.gdshader")
const BAT := preload("res://src/fx/bat.gdshader")

const PRINTS := 40
const PRINT_GAP := 0.8
const PRINT_LIFE := 5.0
const REACT_K := 260.0
const REACT_C := 9.0
const SCARE_R := 2.3
## Prop file names (without extension) that get knocked about.
const REACT := ["gravestone", "grave_A", "grave_B", "gravemarker_A", "gravemarker_B", "grave_A_destroyed", "candle_triple", "skull_candle", "candle_melted", "bone_A", "bone_B", "bone_C", "skull", "ribcage", "pumpkin_orange_jackolantern"]
const BUG_COLORS := [Color(0.08, 0.3, 0.26), Color(0.4, 0.16, 0.08), Color(0.24, 0.11, 0.3), Color(0.28, 0.3, 0.09)]

var arena: Node3D
var grass_mat: ShaderMaterial
var _now := 0.0
var _push: Array[Vector4] = [Vector4(), Vector4(), Vector4(), Vector4()]
# footprints
var _print_mm: MultiMesh
var _print_mat: ShaderMaterial
var _print_i := 0
var _print_n := PRINTS
var _print_last := Vector3(1e6, 0, 1e6)
var _print_side := 1.0
# bats and beetles
var bats: MultiMeshInstance3D
var _bug_mm: MultiMesh
var _bugs: Array = []
var _bug_n := 14
# reactive props
var _react: Array = []
var _moving: Array = []


func _init(a: Node3D) -> void:
	arena = a


## Graphics quality: everything is built at full count and low shows a subset,
## so the setting can flip either way in a running hunt.
func set_low(on: bool) -> void:
	_print_n = 24 if on else PRINTS
	_print_i = 0
	if _print_mm:
		_print_mm.visible_instance_count = _print_n
	if bats:
		bats.multimesh.visible_instance_count = 4 if on else 7
	if _bug_mm:
		_bug_n = 7 if on else 14
		_bug_mm.visible_instance_count = _bug_n


# --- Grass ---------------------------------------------------------------

## The grass material: the stock texture and roughness with a wind shader.
func grass_material(src: BaseMaterial3D) -> ShaderMaterial:
	grass_mat = ShaderMaterial.new()
	grass_mat.shader = GRASS
	grass_mat.set_shader_parameter("albedo_tex", src.albedo_texture)
	return grass_mat


# --- Setup (after the arena is built and its statics baked) ---------------

func setup(outdoor: bool) -> void:
	_setup_prints()
	_setup_react()
	if outdoor:
		_setup_bats()
		_setup_bugs()
	set_low(arena.low)


func _setup_prints() -> void:
	_print_mm = MultiMesh.new()
	_print_mm.transform_format = MultiMesh.TRANSFORM_3D
	_print_mm.use_colors = true
	_print_mm.use_custom_data = true
	var pm := PlaneMesh.new()
	pm.size = Vector2(0.26, 0.4)
	_print_mm.mesh = pm
	_print_mm.instance_count = PRINTS
	var gone := Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO), Vector3.ZERO)
	for i in _print_mm.instance_count:
		_print_mm.set_instance_transform(i, gone)
		_print_mm.set_instance_color(i, Color(0, 0, 0, 0))
	_print_mat = ShaderMaterial.new()
	_print_mat.shader = PRINT
	_print_mat.set_shader_parameter("life", PRINT_LIFE)
	_print_mat.render_priority = -1
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Footprints"
	mmi.multimesh = _print_mm
	mmi.material_override = _print_mat
	mmi.custom_aabb = _world_aabb(1.0)
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	arena.add_child(mmi)


func _world_aabb(height: float) -> AABB:
	var lo := Vector3(arena.min_x - 12.0, -1.0, arena.min_z - 12.0)
	var hi := Vector3(arena.max_x + 12.0, height + 12.0, arena.max_z + 12.0)
	return AABB(lo, hi - lo)


## Stamps a boot print (alternating feet) when the hero has moved a step on
## the dirt path.
func _step(pos: Vector3, vel: Vector3) -> void:
	var flat := Vector3(pos.x, 0, pos.z)
	if flat.distance_squared_to(_print_last) < PRINT_GAP * PRINT_GAP:
		return
	_print_last = flat
	_print_side = -_print_side
	var dir := Vector3(vel.x, 0, vel.z).normalized()
	var p := flat + Vector3(dir.z, 0, -dir.x) * 0.17 * _print_side
	if arena.on_path(p) < 0.3:
		return
	var yaw := atan2(dir.x, dir.z)
	_print_mm.set_instance_transform(_print_i, Transform3D(Basis(Vector3.UP, yaw), Vector3(p.x, 0.045, p.z)))
	_print_mm.set_instance_color(_print_i, Color(0.04, 0.03, 0.025, 0.4))
	_print_mm.set_instance_custom_data(_print_i, Color(_now, 0, 0, 0))
	_print_i = (_print_i + 1) % _print_n


# --- Bats ----------------------------------------------------------------

func _setup_bats() -> void:
	var m := ArrayMesh.new()
	var v := PackedVector3Array()
	# A bat seen from above, nose to +Z: body, then two wings with scalloped edges.
	var body := [Vector3(0, 0, 0.14), Vector3(-0.045, 0, -0.07), Vector3(0.045, 0, -0.07)]
	v.append_array(body)
	for side in [-1.0, 1.0]:
		var pts := [Vector3(0.03, 0, 0.07), Vector3(0.34, 0, 0.14), Vector3(0.28, 0, 0.0), Vector3(0.21, 0, 0.04), Vector3(0.15, 0, -0.08), Vector3(0.03, 0, -0.06)]
		for i in range(1, pts.size() - 1):
			for q in [pts[0], pts[i], pts[i + 1]]:
				var qq: Vector3 = q
				v.append(Vector3(qq.x * side, qq.y, qq.z))
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = m
	var n := 7
	mm.instance_count = n
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var cx: float = (arena.min_x + arena.max_x) * 0.5
	var cz: float = (arena.min_z + arena.max_z) * 0.5
	for i in n:
		var c := Vector3(cx + rng.randf_range(-12.0, 12.0), rng.randf_range(5.5, 8.5), cz + rng.randf_range(-22.0, 22.0))
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * rng.randf_range(2.0, 2.6)), c))
		mm.set_instance_custom_data(i, Color(rng.randf() * TAU, rng.randf_range(0.25, 0.5) * (1.0 if rng.randf() < 0.5 else -1.0), rng.randf_range(5.0, 12.0), 0))
	bats = MultiMeshInstance3D.new()
	bats.name = "Bats"
	bats.multimesh = mm
	var mat := ShaderMaterial.new()
	mat.shader = BAT
	bats.material_override = mat
	bats.custom_aabb = _world_aabb(10.0)
	bats.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	arena.add_child(bats)


# --- Beetles -------------------------------------------------------------

func _setup_bugs() -> void:
	_bug_mm = MultiMesh.new()
	_bug_mm.transform_format = MultiMesh.TRANSFORM_3D
	_bug_mm.use_colors = true
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	sm.radial_segments = 8
	sm.rings = 4
	_bug_mm.mesh = sm
	var n := 14
	_bug_mm.instance_count = n
	var rng := RandomNumberGenerator.new()
	rng.seed = 909
	for i in n:
		var p: Vector3 = arena._free_spot(0.3)
		var b := {"p": p, "yaw": rng.randf() * TAU, "v": 0.0, "run": 0.0, "wait": rng.randf_range(0.5, 4.0), "s": rng.randf_range(0.8, 1.2)}
		_bugs.append(b)
		_bug_mm.set_instance_color(i, BUG_COLORS[i % BUG_COLORS.size()])
		_place_bug(i)
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Beetles"
	mmi.multimesh = _bug_mm
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.3
	mmi.material_override = mat
	mmi.custom_aabb = _world_aabb(1.0)
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	arena.add_child(mmi)


func _place_bug(i: int) -> void:
	var b: Dictionary = _bugs[i]
	var p: Vector3 = b["p"]
	var wob := sin(_now * 38.0 + float(i)) * 0.18 if float(b["v"]) > 0.0 else 0.0
	var s: float = b["s"]
	var basis := Basis(Vector3.UP, float(b["yaw"]) + wob).scaled(Vector3(0.16, 0.1, 0.24) * s)
	_bug_mm.set_instance_transform(i, Transform3D(basis, Vector3(p.x, 0.04, p.z)))


## Beetles near `pos` bolt away from it.
func scare(pos: Vector3, radius: float) -> void:
	for b in _bugs:
		var p: Vector3 = b["p"]
		var d := Vector2(p.x - pos.x, p.z - pos.z)
		if d.length() < radius:
			_flee(b, d)


func _flee(b: Dictionary, away: Vector2) -> void:
	b["yaw"] = atan2(away.x, away.y) + randf_range(-0.6, 0.6)
	b["v"] = 3.2
	b["run"] = randf_range(0.5, 1.1)


func _tick_bugs(dt: float, hero: Vector3) -> void:
	for i in _bug_n:
		var b: Dictionary = _bugs[i]
		var p: Vector3 = b["p"]
		if float(b["run"]) <= 0.0:
			var d := Vector2(p.x - hero.x, p.z - hero.z)
			if d.length_squared() < SCARE_R * SCARE_R:
				_flee(b, d)
			else:
				b["wait"] = float(b["wait"]) - dt
				if float(b["wait"]) <= 0.0:
					b["wait"] = randf_range(1.5, 4.5)
					if randf() < 0.45:
						b["yaw"] = randf() * TAU
						b["v"] = 0.8
						b["run"] = randf_range(0.4, 0.9)
			continue
		b["run"] = float(b["run"]) - dt
		var yaw: float = b["yaw"]
		var np := p + Vector3(sin(yaw), 0, cos(yaw)) * float(b["v"]) * dt
		if np.x < arena.min_x + 0.5 or np.x > arena.max_x - 0.5 or np.z < arena.min_z + 0.5 or np.z > arena.max_z - 0.5 or arena.blocked(np, 0.12):
			b["yaw"] = yaw + PI * 0.75
		else:
			b["p"] = np
		if float(b["run"]) <= 0.0:
			b["v"] = 0.0
		_place_bug(i)


# --- Props that react -----------------------------------------------------

func _setup_react() -> void:
	var nodes: Array = arena._put_nodes
	for i in nodes.size():
		var n: Node3D = nodes[i]
		if not is_instance_valid(n) or i >= arena.props.size():
			continue
		var pr: Dictionary = arena.props[i]
		var stem := str(pr["path"]).get_file().get_basename()
		if stem not in REACT:
			continue
		var h: float = arena.size_of(str(pr["path"])).y * float(pr["scale"])
		_react.append({
			"n": n, "base": n.transform, "slots": arena.baked_slots.get(n, []),
			"x": n.position.x, "z": n.position.z, "small": h < 0.7, "rad": 0.5 if h < 0.7 else 0.7,
			"tilt": Vector2.ZERO, "vel": Vector2.ZERO, "cool": 0.0, "on": false,
		})


## A blow at `pos` (reach `radius`, `power` ~1 for a solid hit) shakes the props
## around it and scares the beetles. Returns the positions of props it hit hard
## enough to shed dust and chips (at most two, rate-limited per prop).
func nudge(pos: Vector3, radius: float, power: float) -> Array:
	var hard: Array = []
	scare(pos, radius + 2.0)
	for r in _react:
		var dx: float = float(r["x"]) - pos.x
		var dz: float = float(r["z"]) - pos.z
		var reach: float = radius + float(r["rad"])
		var d2 := dx * dx + dz * dz
		if d2 >= reach * reach:
			continue
		var d := sqrt(d2)
		var k := (1.0 - d / reach) * power
		var dir := Vector2(dx, dz) / maxf(d, 0.05)
		# Tip away: x rotates about X (leans +z), z about Z (leans -x).
		var v: Vector2 = r["vel"] + Vector2(dir.y, -dir.x) * 2.4 * k * (1.4 if r["small"] else 1.0)
		r["vel"] = v.limit_length(4.5)
		if not r["on"]:
			r["on"] = true
			_moving.append(r)
		if k > 0.45 and float(r["cool"]) <= 0.0 and hard.size() < 2 and not r["small"]:
			r["cool"] = 0.3
			hard.append(Vector3(r["x"], 0.0, r["z"]))
	return hard


func _tick_react(dt: float) -> void:
	var h := minf(dt, 1.0 / 30.0)
	var i := _moving.size() - 1
	while i >= 0:
		var r: Dictionary = _moving[i]
		var t: Vector2 = r["tilt"]
		var v: Vector2 = r["vel"]
		v += (-REACT_K * t - REACT_C * v) * h
		t += v * h
		r["cool"] = maxf(float(r["cool"]) - dt, 0.0)
		var done := t.length_squared() + v.length_squared() * 0.004 < 0.000002
		if done:
			t = Vector2.ZERO
			v = Vector2.ZERO
			r["on"] = false
			_moving.remove_at(i)
		r["tilt"] = t
		r["vel"] = v
		_apply_tilt(r)
		i -= 1


func _apply_tilt(r: Dictionary) -> void:
	var t: Vector2 = r["tilt"]
	var n: Node3D = r["n"]
	var rot := Basis.from_euler(Vector3(t.x, 0.0, t.y))
	var piv := Vector3(r["x"], 0.0, r["z"])
	var xf := Transform3D(rot, piv - rot * piv)
	if is_instance_valid(n):
		n.transform = xf * (r["base"] as Transform3D)
	for s in r["slots"]:
		(s[0] as MultiMesh).set_instance_transform(s[1], xf * (s[2] as Transform3D))


# --- Per frame ------------------------------------------------------------

## `foes`: the live enemies (Actor nodes). The hero and the three nearest foes
## press the grass down.
func tick(dt: float, hero_pos: Vector3, hero_vel: Vector3, hero_alive: bool, foes: Array) -> void:
	_now += dt
	if grass_mat:
		_push[0] = Vector4(hero_pos.x, 0.0, hero_pos.z, 1.3 if hero_alive else 0.0)
		_push[1] = Vector4()
		_push[2] = Vector4()
		_push[3] = Vector4()
		var d1 := 1e9
		var d2 := 1e9
		var d3 := 1e9
		for f in foes:
			if not is_instance_valid(f) or not f.alive:
				continue
			var p: Vector3 = f.position
			var d := Vector2(p.x - hero_pos.x, p.z - hero_pos.z).length_squared()
			var v := Vector4(p.x, 0.0, p.z, 0.9 + f.radius)
			if d < d1:
				_push[3] = _push[2]
				_push[2] = _push[1]
				_push[1] = v
				d3 = d2
				d2 = d1
				d1 = d
			elif d < d2:
				_push[3] = _push[2]
				_push[2] = v
				d3 = d2
				d2 = d
			elif d < d3:
				_push[3] = v
				d3 = d
		for i in 4:
			grass_mat.set_shader_parameter("push%d" % i, _push[i])
	if _print_mat:
		_print_mat.set_shader_parameter("now", _now)
		if hero_alive and hero_vel.length_squared() > 1.2:
			_step(hero_pos, hero_vel)
	if hero_alive and hero_vel.length_squared() > 1.0:
		_brush(hero_pos, hero_vel)
	if not _moving.is_empty():
		_tick_react(dt)
	if not _bugs.is_empty():
		_tick_bugs(dt, hero_pos)


## Walking through small props (bones, candles) knocks them about.
func _brush(pos: Vector3, vel: Vector3) -> void:
	for r in _react:
		if not r["small"] or float(r["cool"]) > 0.0:
			continue
		var dx: float = float(r["x"]) - pos.x
		var dz: float = float(r["z"]) - pos.z
		if dx * dx + dz * dz < 0.36:
			r["cool"] = 0.35
			var dir := Vector2(vel.x, vel.z).normalized()
			r["vel"] = (r["vel"] as Vector2) + Vector2(dir.y, -dir.x) * 2.6
			if not r["on"]:
				r["on"] = true
				_moving.append(r)
