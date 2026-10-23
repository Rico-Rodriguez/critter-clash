class_name Fx
extends Node3D
## Pooled visual effects for the hunt. Everything here is cosmetic: gameplay
## never waits on an effect. Particle bursts go through a handful of shared
## GPUParticles3D emitters (emit_particle), so a hundred hits cost nothing.

const SLASH := preload("res://src/fx/slash.gdshader")
const RING := preload("res://src/fx/ring.gdshader")
const TELE := preload("res://src/fx/telegraph.gdshader")
const BEAM := preload("res://src/fx/beam.gdshader")
const SOFT := preload("res://src/fx/soft.gdshader")
const SMOKE := preload("res://src/fx/smoke.gdshader")
const TORNADO := preload("res://src/fx/tornado.gdshader")
const FLAME_RING := preload("res://src/fx/flame_ring.gdshader")
const FLAME_WALL := preload("res://src/fx/flame_wall.gdshader")
const SCORCH := preload("res://src/fx/scorch.gdshader")

const FLAGS := GPUParticles3D.EMIT_FLAG_POSITION | GPUParticles3D.EMIT_FLAG_VELOCITY | GPUParticles3D.EMIT_FLAG_COLOR | GPUParticles3D.EMIT_FLAG_CUSTOM

var _live: Array = []
var _pools := {}
var _arc_meshes := {}
var _slash_mat: ShaderMaterial
var _ring_mat: ShaderMaterial
var _tele_mat: ShaderMaterial
var _beam_mat: ShaderMaterial
var _flame_mat: ShaderMaterial
var _wall_mat: ShaderMaterial
var _scorch_mat: ShaderMaterial
var _wall_mesh: CylinderMesh
var _quad: PlaneMesh
var sparks: GPUParticles3D
var embers: GPUParticles3D
var dust: GPUParticles3D
var bones: GPUParticles3D
var glow: GPUParticles3D
var _numbers: Array[Label3D] = []
var _num_i := 0
var _lights: Array[OmniLight3D] = []
var _light_i := 0
var title_font: FontVariation
var quality_low := false
var _merge := {}
var _serial := 0


func _init() -> void:
	name = "Fx"


func _ready() -> void:
	_slash_mat = ShaderMaterial.new()
	_slash_mat.shader = SLASH
	_ring_mat = ShaderMaterial.new()
	_ring_mat.shader = RING
	_tele_mat = ShaderMaterial.new()
	_tele_mat.shader = TELE
	_tele_mat.render_priority = -1
	_beam_mat = ShaderMaterial.new()
	_beam_mat.shader = BEAM
	_flame_mat = ShaderMaterial.new()
	_flame_mat.shader = FLAME_RING
	_wall_mat = ShaderMaterial.new()
	_wall_mat.shader = FLAME_WALL
	_scorch_mat = ShaderMaterial.new()
	_scorch_mat.shader = SCORCH
	_scorch_mat.render_priority = -1
	_wall_mesh = CylinderMesh.new()
	_wall_mesh.top_radius = 1.0
	_wall_mesh.bottom_radius = 1.0
	_wall_mesh.height = 1.0
	_wall_mesh.cap_top = false
	_wall_mesh.cap_bottom = false
	_wall_mesh.radial_segments = 28
	_wall_mesh.rings = 1
	_quad = PlaneMesh.new()
	_quad.size = Vector2(2, 2)
	title_font = FontVariation.new()
	title_font.base_font = load("res://assets/fonts/Cinzel-Variable.ttf")
	title_font.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 900}
	sparks = _emitter(220, 0.45, _soft_mesh(0.16), Vector3(0, -14, 0), 2.5)
	embers = _emitter(160, 1.4, _soft_mesh(0.12), Vector3(0, 1.5, 0), 1.2)
	glow = _emitter(60, 0.35, _soft_mesh(1.4), Vector3.ZERO, 0.0)
	dust = _emitter(140, 0.9, _smoke_mesh(1.1), Vector3(0, 0.8, 0), 2.2)
	var bone_mesh := _first_mesh("res://assets/kaykit/graveyard/bone_A.gltf")
	bones = _emitter(150, 1.1, bone_mesh, Vector3(0, -16, 0), 0.6, true)
	for i in 36:
		var l := Label3D.new()
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.no_depth_test = true
		l.fixed_size = false
		l.pixel_size = 0.0082
		l.font = title_font
		l.font_size = 64
		l.outline_size = 18
		l.outline_modulate = Color(0.05, 0.02, 0.02, 0.95)
		l.render_priority = 10
		l.outline_render_priority = 9
		l.visible = false
		add_child(l)
		_numbers.append(l)
	for i in 4:
		var o := OmniLight3D.new()
		o.visible = false
		o.shadow_enabled = false
		add_child(o)
		_lights.append(o)


## A translucent shield bubble (used by warded champions).
static func make_ward(radius: float) -> MeshInstance3D:
	var sh := Shader.new()
	sh.code = "shader_type spatial;\nrender_mode blend_add, unshaded, cull_back, depth_draw_never, shadows_disabled;\nvoid fragment(){ float f = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.5); ALBEDO = vec3(0.55, 0.5, 1.0) * 2.0; ALPHA = clamp(f * 0.9 + 0.05, 0.0, 1.0); }"
	var m := ShaderMaterial.new()
	m.shader = sh
	var mi := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = radius
	sph.height = radius * 2.0
	mi.mesh = sph
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


func _first_mesh(path: String) -> Mesh:
	var n: Node = load(path).instantiate()
	var mi: MeshInstance3D = n as MeshInstance3D
	if mi == null:
		for c in n.find_children("*", "MeshInstance3D", true, false):
			mi = c
			break
	var m: Mesh = mi.mesh
	n.free()
	return m


func _soft_mesh(size: float) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	var m := ShaderMaterial.new()
	m.shader = SOFT
	q.material = m
	return q


func _smoke_mesh(size: float) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	var m := ShaderMaterial.new()
	m.shader = SMOKE
	var nt := NoiseTexture2D.new()
	nt.width = 128
	nt.height = 128
	nt.seamless = true
	var fn := FastNoiseLite.new()
	fn.frequency = 0.03
	nt.noise = fn
	m.set_shader_parameter("noise", nt)
	q.material = m
	return q


func _emitter(amount: int, life: float, mesh: Mesh, gravity: Vector3, damping: float, spin := false) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	p.explosiveness = 0.0
	p.local_coords = false
	p.emitting = true
	p.amount_ratio = 0.0
	p.visibility_aabb = AABB(Vector3(-80, -10, -80), Vector3(160, 40, 160))
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if not spin else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var pm := ParticleProcessMaterial.new()
	pm.gravity = gravity
	pm.damping_min = damping
	pm.damping_max = damping
	pm.initial_velocity_min = 0.0
	pm.initial_velocity_max = 0.0
	pm.direction = Vector3.ZERO
	pm.spread = 0.0
	var curve := CurveTexture.new()
	var c := Curve.new()
	c.add_point(Vector2(0, 1))
	c.add_point(Vector2(0.6, 0.8))
	c.add_point(Vector2(1, 0))
	curve.curve = c
	pm.scale_curve = curve
	if spin:
		pm.angular_velocity_min = -720.0
		pm.angular_velocity_max = 720.0
		pm.particle_flag_rotate_y = true
		pm.scale_min = 0.8
		pm.scale_max = 1.3
		var sc := Curve.new()
		sc.add_point(Vector2(0, 1))
		sc.add_point(Vector2(0.8, 1))
		sc.add_point(Vector2(1, 0))
		var sct := CurveTexture.new()
		sct.curve = sc
		pm.scale_curve = sct
	else:
		var alpha := Gradient.new()
		alpha.set_color(0, Color(1, 1, 1, 1))
		alpha.set_color(1, Color(1, 1, 1, 0))
		var gt := GradientTexture1D.new()
		gt.gradient = alpha
		pm.color_ramp = gt
	p.process_material = pm
	p.draw_pass_1 = mesh
	if spin:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.93, 0.88, 0.78)
		m.roughness = 0.8
		p.material_override = m
	add_child(p)
	return p


func _process(delta: float) -> void:
	var i := _live.size() - 1
	while i >= 0:
		var e: Dictionary = _live[i]
		e["t"] += delta
		var k: float = clampf(e["t"] / e["dur"], 0.0, 1.0)
		var n: Node3D = e["node"]
		if not is_instance_valid(n):
			_live.remove_at(i)
			i -= 1
			continue
		match str(e["kind"]):
			"slash", "ring", "flame", "scorch":
				(n as GeometryInstance3D).set_instance_shader_parameter("progress", k)
			"wall":
				# The wall rides the flame front out, shrinking as it goes.
				var grow := 1.0 - pow(1.0 - k, 2.4)
				var rr: float = float(e["r"]) * lerpf(0.15, 0.9, grow)
				var hh: float = float(e["h"]) * (1.0 - 0.5 * k)
				n.scale = Vector3(rr, hh, rr)
				n.position.y = hh * 0.5
				(n as GeometryInstance3D).set_instance_shader_parameter("progress", k)
			"tele":
				(n as GeometryInstance3D).set_instance_shader_parameter("progress", k)
				var fade_in: float = clampf(e["t"] / 0.12, 0.0, 1.0)
				(n as GeometryInstance3D).set_instance_shader_parameter("fade", fade_in)
			"num":
				var l := n as Label3D
				var base: Vector3 = e["from"]
				var pop: float = 1.0 + 0.6 * pow(1.0 - minf(k * 5.0, 1.0), 2.0)
				l.scale = Vector3.ONE * pop * float(e["size"])
				l.position = base + Vector3(e["dx"] * k, 1.1 * (1.0 - pow(1.0 - k, 2.0)), 0)
				l.modulate.a = 1.0 - smoothstep(0.65, 1.0, k)
				l.outline_modulate.a = l.modulate.a * 0.95
			"light":
				var o := n as OmniLight3D
				o.light_energy = float(e["energy"]) * pow(1.0 - k, 2.0)
			"beam":
				pass
			"tornado":
				if is_instance_valid(e["follow"]):
					n.position = (e["follow"] as Actor).flat_pos()
				n.rotation.y -= delta * 9.0
				var fade: float = smoothstep(0.0, 0.12, k) * (1.0 - smoothstep(0.85, 1.0, k))
				(n.get_child(0) as GeometryInstance3D).set_instance_shader_parameter("fade", fade)
		if k >= 1.0:
			if e["kind"] == "num" or e["kind"] == "light":
				n.visible = false
			elif e["kind"] != "beam":
				_release(str(e["kind"]), n)
			_live.remove_at(i)
		i -= 1


func _take(kind: String, make: Callable) -> Node3D:
	var pool: Array = _pools.get(kind, [])
	_pools[kind] = pool
	var n: Node3D = pool.pop_back() if not pool.is_empty() else make.call()
	if n.get_parent() == null:
		add_child(n)
	n.visible = true
	return n


func _release(kind: String, n: Node3D) -> void:
	n.visible = false
	var key := kind
	if n.has_meta("pool"):
		key = str(n.get_meta("pool"))
	_pools[key] = _pools.get(key, [])
	_pools[key].append(n)


## A flat arc mesh around +Z, inner/outer radius 0.55/1.0 (scale it).
func _arc(deg: int) -> ArrayMesh:
	if _arc_meshes.has(deg):
		return _arc_meshes[deg]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var seg := 24
	var half := deg_to_rad(deg) * 0.5
	for s in seg:
		var a0 := -half + (2.0 * half) * s / seg
		var a1 := -half + (2.0 * half) * (s + 1) / seg
		var u0 := float(s) / seg
		var u1 := float(s + 1) / seg
		var pts := [
			[Vector3(sin(a0), 0, cos(a0)) * 0.45, Vector2(u0, 0)],
			[Vector3(sin(a0), 0, cos(a0)), Vector2(u0, 1)],
			[Vector3(sin(a1), 0, cos(a1)), Vector2(u1, 1)],
			[Vector3(sin(a1), 0, cos(a1)) * 0.45, Vector2(u1, 0)],
		]
		for idx in [0, 1, 2, 0, 2, 3]:
			st.set_uv(pts[idx][1])
			st.set_normal(Vector3.UP)
			st.add_vertex(pts[idx][0])
	var m := st.commit()
	_arc_meshes[deg] = m
	return m


## A sword swing: arc of `deg` around the facing angle `yaw`.
func slash(pos: Vector3, yaw: float, radius: float, deg: float, color: Color, mirror := false, dur := 0.2) -> void:
	var d := int(clampf(roundf(deg / 10.0) * 10.0, 30.0, 360.0))
	var kind := "slash%d" % d
	var n := _take(kind, func():
		var mi := MeshInstance3D.new()
		mi.mesh = _arc(d)
		mi.material_override = _slash_mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.set_meta("pool", kind)
		return mi)
	n.position = pos + Vector3(0, 0.9, 0)
	n.rotation = Vector3(0, yaw, 0)
	n.scale = Vector3(-radius if mirror else radius, 1, radius)
	(n as GeometryInstance3D).set_instance_shader_parameter("tint", color)
	(n as GeometryInstance3D).set_instance_shader_parameter("progress", 0.0)
	_live.append({"node": n, "t": 0.0, "dur": dur, "kind": "slash"})


## Expanding ground ring (shockwaves, novas, landings).
func ring(pos: Vector3, radius: float, color: Color, dur := 0.45, width := 0.12) -> void:
	var n := _take("ring", func():
		var mi := MeshInstance3D.new()
		mi.mesh = _quad
		mi.material_override = _ring_mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.set_meta("pool", "ring")
		return mi)
	n.position = pos + Vector3(0, 0.06, 0)
	n.rotation = Vector3.ZERO
	n.scale = Vector3(radius, 1, radius)
	(n as GeometryInstance3D).set_instance_shader_parameter("tint", color)
	(n as GeometryInstance3D).set_instance_shader_parameter("progress", 0.0)
	_live.append({"node": n, "t": 0.0, "dur": dur, "kind": "ring"})


## A burst of fire: a torn ring of flame racing out over the ground, a wall
## of flame tongues riding it (skip with `wall` false for small, frequent
## bursts), sparks, embers, smoke, a flash, and a scorch left behind.
func flame_burst(pos: Vector3, radius: float, wall := true, color := Color(1.0, 0.45, 0.12)) -> void:
	var dur := clampf(0.38 + radius * 0.06, 0.42, 0.8)
	var f := _take("flame", func():
		var mi := MeshInstance3D.new()
		mi.mesh = _quad
		mi.material_override = _flame_mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.set_meta("pool", "flame")
		return mi)
	f.position = pos + Vector3(0, 0.09, 0)
	f.rotation = Vector3(0, randf() * TAU, 0)
	f.scale = Vector3(radius * 1.15, 1, radius * 1.15)
	var gf := f as GeometryInstance3D
	gf.set_instance_shader_parameter("tint", color)
	gf.set_instance_shader_parameter("seed", randf() * 40.0)
	gf.set_instance_shader_parameter("progress", 0.0)
	_live.append({"node": f, "t": 0.0, "dur": dur, "kind": "flame"})
	if wall and not quality_low:
		var w := _take("wall", func():
			var mi := MeshInstance3D.new()
			mi.mesh = _wall_mesh
			mi.material_override = _wall_mat
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.set_meta("pool", "wall")
			return mi)
		w.position = pos
		w.scale = Vector3(0.1, 0.1, 0.1)
		var gw := w as GeometryInstance3D
		gw.set_instance_shader_parameter("tint", color)
		gw.set_instance_shader_parameter("seed", randf() * 40.0)
		gw.set_instance_shader_parameter("progress", 0.0)
		_live.append({"node": w, "t": 0.0, "dur": dur * 1.15, "kind": "wall", "r": radius * 1.05, "h": clampf(radius * 0.6, 1.0, 2.6)})
	scorch(pos, radius * 0.85)
	burst(pos, Color(1.0, 0.72, 0.3), int(clampf(radius * 5.0, 6.0, 22.0)), 6.0 + radius * 1.5, 0.9)
	embers_at(pos, color, int(clampf(radius * 4.0, 4.0, 16.0)), radius * 0.6)
	if not quality_low:
		puff(pos, Color(0.12, 0.1, 0.09, 0.5), 4, radius * 0.4, 1.6)
	flash_light(pos, Color(1.0, 0.55, 0.25), 3.5, radius * 3.0, 0.3)


## Burnt ground that glows, cools and fades over `dur` seconds.
func scorch(pos: Vector3, radius: float, dur := 2.6) -> void:
	var n := _take("scorch", func():
		var mi := MeshInstance3D.new()
		mi.mesh = _quad
		mi.material_override = _scorch_mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.set_meta("pool", "scorch")
		return mi)
	n.position = pos + Vector3(0, 0.05, 0)
	n.rotation = Vector3(0, randf() * TAU, 0)
	n.scale = Vector3(radius, 1, radius)
	(n as GeometryInstance3D).set_instance_shader_parameter("seed", randf() * 40.0)
	(n as GeometryInstance3D).set_instance_shader_parameter("progress", 0.0)
	_live.append({"node": n, "t": 0.0, "dur": dur, "kind": "scorch"})


## The Hellfire Wisp: a white-hot core in a flickering shell of fire, lit.
## The caller owns the node (adds it to the world, moves it, frees it).
func make_wisp() -> Node3D:
	var root := Node3D.new()
	var core := MeshInstance3D.new()
	var cs := SphereMesh.new()
	cs.radius = 0.17
	cs.height = 0.34
	cs.radial_segments = 12
	cs.rings = 6
	core.mesh = cs
	var cm := StandardMaterial3D.new()
	cm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cm.albedo_color = Color(1.0, 0.95, 0.75)
	core.material_override = cm
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(core)
	var shell := MeshInstance3D.new()
	var ss := SphereMesh.new()
	ss.radius = 0.42
	ss.height = 0.95
	ss.radial_segments = 16
	ss.rings = 8
	shell.mesh = ss
	shell.position.y = 0.12
	var sh := Shader.new()
	sh.code = "shader_type spatial;\nrender_mode blend_add, unshaded, cull_back, depth_draw_never, shadows_disabled;\nvoid fragment(){ float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 1.4); float lick = 0.6 + 0.4 * sin(UV.x * 37.7 + UV.y * 9.0 - TIME * 11.0); ALBEDO = mix(vec3(1.0, 0.75, 0.3), vec3(1.0, 0.3, 0.06), rim) * 2.4; ALPHA = clamp((1.0 - rim) * 0.55 * lick + rim * 0.25, 0.0, 1.0) * smoothstep(0.0, 0.35, UV.y); }"
	var sm := ShaderMaterial.new()
	sm.shader = sh
	shell.material_override = sm
	shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(shell)
	var o := OmniLight3D.new()
	o.light_color = Color(1.0, 0.55, 0.2)
	o.light_energy = 1.4
	o.omni_range = 4.5
	o.shadow_enabled = false
	root.add_child(o)
	return root


## Ground warning. shape: 0 circle (size = radius), 1 cone (size = radius,
## cone = half angle), 2 lane (size = Vector2 half width, length). The fill
## completes after `dur`. Returns the node so the caller can cancel it.
func telegraph(shape: int, pos: Vector3, yaw: float, size: Vector2, dur: float, cone := 0.6) -> MeshInstance3D:
	var n := _take("tele", func():
		var mi := MeshInstance3D.new()
		mi.mesh = _quad
		mi.material_override = _tele_mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.set_meta("pool", "tele")
		return mi)
	n.rotation = Vector3(0, yaw, 0)
	if shape == 2:
		# Lane from pos forward along yaw.
		var fwd := Vector3(sin(yaw), 0, cos(yaw))
		n.position = pos + fwd * size.y * 0.5 + Vector3(0, 0.04, 0)
		n.scale = Vector3(size.x, 1, size.y * 0.5)
	else:
		n.position = pos + Vector3(0, 0.04, 0)
		n.scale = Vector3(size.x, 1, size.x)
	var gi := n as GeometryInstance3D
	gi.set_instance_shader_parameter("shape", float(shape))
	gi.set_instance_shader_parameter("cone", cone)
	gi.set_instance_shader_parameter("progress", 0.0)
	gi.set_instance_shader_parameter("fade", 0.0)
	_live.append({"node": n, "t": 0.0, "dur": dur, "kind": "tele"})
	return n


func cancel(n: Node3D) -> void:
	if n == null or not is_instance_valid(n):
		return
	for i in _live.size():
		if _live[i]["node"] == n:
			_live.remove_at(i)
			break
	_release("tele", n)


## Loot pillar. Lives until the caller frees it with release_beam.
func beam(pos: Vector3, color: Color, height := 7.0) -> MeshInstance3D:
	var n := _take("beam", func():
		var mi := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.28
		cyl.bottom_radius = 0.42
		cyl.height = 1.0
		cyl.cap_top = false
		cyl.cap_bottom = false
		cyl.radial_segments = 12
		mi.mesh = cyl
		mi.material_override = _beam_mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.set_meta("pool", "beam")
		return mi)
	n.position = pos + Vector3(0, height * 0.5, 0)
	n.scale = Vector3(1, height, 1)
	(n as GeometryInstance3D).set_instance_shader_parameter("tint", color)
	(n as GeometryInstance3D).set_instance_shader_parameter("strength", 1.0)
	return n


## A column of fire spinning around `follow` for `dur` seconds (the
## Barbarian's whirlwind). One cone, reused.
func tornado(follow: Actor, color: Color, dur: float) -> void:
	var n := _take("tornado", func():
		var mi := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 2.4
		cyl.bottom_radius = 0.9
		cyl.height = 3.4
		cyl.cap_top = false
		cyl.cap_bottom = false
		cyl.radial_segments = 24
		cyl.rings = 4
		mi.mesh = cyl
		var m := ShaderMaterial.new()
		m.shader = TORNADO
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.set_meta("pool", "tornado")
		# The mesh is centred: lift it so the narrow end sits on the ground.
		var holder := Node3D.new()
		holder.add_child(mi)
		mi.position.y = 1.7
		holder.set_meta("pool", "tornado")
		return holder)
	n.position = follow.flat_pos()
	var cone := n.get_child(0) as GeometryInstance3D
	cone.set_instance_shader_parameter("tint", color)
	cone.set_instance_shader_parameter("fade", 0.0)
	_live.append({"node": n, "t": 0.0, "dur": dur, "kind": "tornado", "follow": follow})


func release_beam(n: Node3D) -> void:
	if n and is_instance_valid(n):
		_release("beam", n)


## Damage number. Pass `key` (the target) and rapid hits on it merge into one
## growing number instead of stacking a pile of them.
func number(pos: Vector3, amount: int, color: Color, size := 1.0, key: Object = null) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if key != null:
		var m: Dictionary = _merge.get(key.get_instance_id(), {})
		if not m.is_empty() and now < float(m["until"]):
			var ml: Label3D = m["label"]
			if ml.visible and ml.get_meta("serial", -1) == m["serial"]:
				m["total"] = int(m["total"]) + amount
				m["until"] = now + 0.3
				ml.text = str(m["total"])
				for e in _live:
					if e["node"] == ml:
						e["t"] = minf(float(e["t"]), 0.12)
				return
	var l := _numbers[_num_i]
	_num_i = (_num_i + 1) % _numbers.size()
	for e in _live:
		if e["node"] == l:
			_live.erase(e)
			break
	l.text = str(amount)
	l.modulate = color
	l.visible = true
	var from := pos + Vector3(randf_range(-0.3, 0.3), 1.9, 0)
	l.position = from
	_serial += 1
	l.set_meta("serial", _serial)
	if key != null:
		_merge[key.get_instance_id()] = {"label": l, "total": amount, "until": now + 0.3, "serial": _serial}
	_live.append({"node": l, "t": 0.0, "dur": 0.75, "kind": "num", "from": from, "size": size, "dx": randf_range(-0.5, 0.5)})


func text(pos: Vector3, s: String, color: Color, size := 0.8, dur := 1.1) -> void:
	var l := _numbers[_num_i]
	_num_i = (_num_i + 1) % _numbers.size()
	for e in _live:
		if e["node"] == l:
			_live.erase(e)
			break
	l.text = s
	l.modulate = color
	l.visible = true
	var from := pos + Vector3(0, 2.4, 0)
	l.position = from
	_live.append({"node": l, "t": 0.0, "dur": dur, "kind": "num", "from": from, "size": size, "dx": 0.0})


func flash_light(pos: Vector3, color: Color, energy := 3.0, radius := 6.0, dur := 0.25) -> void:
	if quality_low:
		return
	var o := _lights[_light_i]
	_light_i = (_light_i + 1) % _lights.size()
	for e in _live:
		if e["node"] == o:
			_live.erase(e)
			break
	o.visible = true
	o.position = pos + Vector3(0, 1.2, 0)
	o.light_color = color
	o.omni_range = radius
	o.light_energy = energy
	_live.append({"node": o, "t": 0.0, "dur": dur, "kind": "light", "energy": energy})


# --- Particle bursts -----------------------------------------------------

func burst(pos: Vector3, color: Color, count := 10, speed := 6.0, up := 0.5) -> void:
	for i in count:
		var dir := Vector3(randf_range(-1, 1), randf_range(0.2, 1.0) * up + 0.15, randf_range(-1, 1)).normalized()
		sparks.emit_particle(Transform3D(Basis(), pos + Vector3(0, 0.9, 0)), dir * speed * randf_range(0.4, 1.0), color, Color(randf(), randf(), 0, 0), FLAGS)


func embers_at(pos: Vector3, color: Color, count := 6, radius := 0.6) -> void:
	for i in count:
		var off := Vector3(randf_range(-radius, radius), randf_range(0.2, 1.4), randf_range(-radius, radius))
		embers.emit_particle(Transform3D(Basis(), pos + off), Vector3(randf_range(-0.4, 0.4), randf_range(0.5, 1.8), randf_range(-0.4, 0.4)), color, Color(randf(), randf(), 0, 0), FLAGS)


func puff(pos: Vector3, color := Color(0.32, 0.27, 0.22, 0.55), count := 6, spread := 0.8, speed := 1.4) -> void:
	for i in count:
		var dir := Vector3(randf_range(-1, 1), 0.0, randf_range(-1, 1)).normalized()
		dust.emit_particle(Transform3D(Basis(), pos + dir * randf() * spread + Vector3(0, 0.25, 0)), dir * speed * randf_range(0.5, 1.0) + Vector3(0, randf_range(0.2, 0.8), 0), color, Color(randf(), randf(), 0, 0), FLAGS)


func flare(pos: Vector3, color: Color) -> void:
	glow.emit_particle(Transform3D(Basis(), pos + Vector3(0, 0.9, 0)), Vector3.ZERO, color, Color(), FLAGS)


func bone_burst(pos: Vector3, count := 6, force := 5.0) -> void:
	if quality_low:
		count = mini(count, 3)
	for i in count:
		var dir := Vector3(randf_range(-1, 1), randf_range(0.8, 1.6), randf_range(-1, 1)).normalized()
		var b := Basis(Vector3(randf(), randf(), randf()).normalized(), randf() * TAU)
		bones.emit_particle(Transform3D(b, pos + Vector3(0, 0.8, 0)), dir * force * randf_range(0.6, 1.1), Color.WHITE, Color(), FLAGS)


## Chain lightning: a jagged additive ribbon between points that flickers out.
func lightning(points: PackedVector3Array, color := Color(0.6, 0.8, 1.0)) -> void:
	var im := ImmediateMesh.new()
	var mi := MeshInstance3D.new()
	mi.mesh = im
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(color.r * 2.5, color.g * 2.5, color.b * 2.5)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for s in points.size() - 1:
		var a := points[s]
		var b := points[s + 1]
		var steps := 6
		for j in steps + 1:
			var t := float(j) / steps
			var p := a.lerp(b, t)
			if j > 0 and j < steps:
				p += Vector3(randf_range(-0.35, 0.35), randf_range(-0.2, 0.3), randf_range(-0.35, 0.35))
			var side := (b - a).cross(Vector3.UP).normalized() * 0.07
			im.surface_add_vertex(p - side)
			im.surface_add_vertex(p + side)
	im.surface_end()
	var tw := mi.create_tween()
	tw.tween_property(m, "albedo_color:a", 0.0, 0.22).from(1.0)
	tw.tween_callback(mi.queue_free)
	for p in points:
		flare(p - Vector3(0, 0.9, 0), color)


# --- Sky effects: lightning strikes, meteors, falling arrows ---------------

static var _bolt_mat: StandardMaterial3D
static var _fall_cache := {}


## A bolt of lightning from the sky onto `at`: jagged column, ground flash,
## shockwave ring and sparks. Pass the strike color (gold for holy, blue for storm).
func sky_bolt(at: Vector3, color := Color(1.0, 0.9, 0.55), width := 0.2, height := 15.0) -> void:
	if _bolt_mat == null:
		_bolt_mat = StandardMaterial3D.new()
		_bolt_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_bolt_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_bolt_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_bolt_mat.vertex_color_use_as_albedo = true
		_bolt_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var im := ImmediateMesh.new()
	var mi := MeshInstance3D.new()
	mi.mesh = im
	mi.material_override = _bolt_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	var hot := Color(color.r * 1.35, color.g * 1.35, color.b * 1.35, 1.0)
	var steps := 9
	var path: Array[Vector3] = []
	for j in steps + 1:
		var t := float(j) / steps
		var p := at + Vector3(0, height * (1.0 - t), 0)
		if j > 0 and j < steps:
			p += Vector3(randf_range(-0.7, 0.7), 0, randf_range(-0.7, 0.7)) * (1.0 - t * 0.5)
		path.append(p)
	for side in [Vector3.RIGHT, Vector3.BACK]:
		im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
		for j in path.size():
			var w := width * (0.5 + 0.5 * float(j) / steps)
			im.surface_set_color(hot)
			im.surface_add_vertex(path[j] - side * w)
			im.surface_set_color(hot)
			im.surface_add_vertex(path[j] + side * w)
		im.surface_end()
	var tw := mi.create_tween()
	tw.tween_property(mi, "transparency", 1.0, 0.28).from(0.0).set_ease(Tween.EASE_IN)
	tw.tween_callback(mi.queue_free)
	flare(at, color)
	flash_light(at, color, 5.0, 8.0, 0.3)
	ring(at, 1.8, color, 0.3, 0.2)
	burst(at, color, 12, 7.0, 1.0)


## Something falling onto `to` after `delay`, taking `dur` to arrive: a "meteor"
## or an "arrow". `land` runs on impact.
func fall(kind: String, to: Vector3, delay: float, dur: float, land: Callable) -> void:
	var n := _take("fall_" + kind, func(): return _make_faller(kind))
	var from := to + (Vector3(-9.0, 16.0, -10.0) if kind == "meteor" else Vector3(0.4, 12.0, 0.8))
	n.visible = false
	n.position = from
	n.look_at(to, Vector3.UP)
	var tw := n.create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_callback(func():
		n.visible = true)
	tw.tween_property(n, "position", to, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		_release("fall_" + kind, n)
		if land.is_valid():
			land.call())


func _make_faller(kind: String) -> Node3D:
	var root := Node3D.new()
	root.set_meta("pool", "fall_" + kind)
	if kind == "meteor":
		var rock := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.55
		sm.height = 1.1
		sm.radial_segments = 10
		sm.rings = 6
		rock.mesh = sm
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color(1.0, 0.8, 0.45)
		m.emission_enabled = true
		m.emission = Color(1.0, 0.4, 0.08)
		m.emission_energy_multiplier = 4.0
		rock.material_override = m
		rock.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(rock)
		for rot in [0.0, PI * 0.5]:
			var tr := MeshInstance3D.new()
			var q := QuadMesh.new()
			q.size = Vector2(0.9, 5.0)
			q.orientation = PlaneMesh.FACE_Y
			tr.mesh = q
			tr.material_override = _trail_material(Color(1.0, 0.45, 0.12))
			tr.position = Vector3(0, 0, 2.5)
			tr.rotation.z = rot
			tr.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(tr)
	else:
		var a := KK.prop("res://assets/kaykit/weapons/arrow_bow.gltf")
		a.scale = Vector3.ONE * 2.2
		a.rotation = Vector3(0, 0, 0)
		root.add_child(a)
		var tr2 := MeshInstance3D.new()
		var q2 := QuadMesh.new()
		q2.size = Vector2(0.18, 2.2)
		q2.orientation = PlaneMesh.FACE_Y
		tr2.mesh = q2
		tr2.material_override = _trail_material(Color(1.0, 0.9, 0.6))
		tr2.position = Vector3(0, 0, 1.2)
		root.add_child(tr2)
	return root


func _trail_material(color: Color) -> StandardMaterial3D:
	var key := color.to_html()
	if _fall_cache.has(key):
		return _fall_cache[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(color.r, color.g, color.b, 0.5)
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0.5, 1.0)
	gt.fill_to = Vector2(0.5, 0.0)
	gt.width = 8
	gt.height = 64
	m.albedo_texture = gt
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_fall_cache[key] = m
	return m
