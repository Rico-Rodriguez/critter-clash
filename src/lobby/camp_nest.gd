extends Node3D
## The Nest: the thatched hatchery at the edge of camp. Eggs sit in the straw
## (one per hatchery slot, glowing and rocking when ready), a gold "!" floats
## over it when something can hatch, and tapping it walks the hero in to the
## Pets tab. Pure scenery plus a few tweens; the camp (lobby.gd) owns the walk.

const D := "res://assets/kaykit/dungeon/"
const G := "res://assets/kaykit/graveyard/"
const F := "res://assets/kaykit/forest/"
const SDB := preload("res://src/data/sidekick_db.gd")
const SKS := preload("res://src/autoload/sidekicks.gd")
const FONT := preload("res://assets/fonts/Cinzel-Variable.ttf")
const STRAW := Color(0.80, 0.62, 0.30)
## Local slots for the eggs: a ring around the middle, a lone egg in the heart.
const EGG_SPOTS := [Vector3(0, 0, 0.05), Vector3(0.48, 0, 0.2), Vector3(-0.48, 0, 0.2), Vector3(0.3, 0, -0.42), Vector3(-0.3, 0, -0.42), Vector3(0, 0, 0.62)]

var _eggs: Array[Node3D] = []
var _ready_eggs := 0
var _badge: Label3D
var _glow: OmniLight3D
var _t := 0.0
var _bump: Tween
var body: Node3D


func _init() -> void:
	body = Node3D.new()
	add_child(body)
	_build()


func _build() -> void:
	# The bed: packed earth, straw, and a ring of logs around it.
	var earth := _disc(1.55, 0.04, Color(0.17, 0.12, 0.09), 0.0)
	body.add_child(earth)
	body.add_child(_disc(1.02, 0.12, STRAW.darkened(0.12), 0.06))
	body.add_child(_disc(0.8, 0.15, STRAW, 0.08))
	for i in 11:
		var a := TAU * i / 11.0
		var log := KK.prop(D + "trunk_small_%s.gltf" % "ABC"[i % 3])
		log.position = Vector3(sin(a), 0.0, cos(a)) * 1.12
		log.rotation.y = a + PI * 0.5
		log.scale = Vector3(0.62, 0.62, 0.62)
		body.add_child(log)
	# Straw tufts poking over the logs.
	for i in 6:
		var a := TAU * (i + 0.5) / 6.0
		var tuft := KK.prop(F + "Grass_2_%s_Color1.gltf" % "ABCD"[i % 4])
		tuft.position = Vector3(sin(a), 0.0, cos(a)) * 0.92
		tuft.rotation.y = a * 2.0
		tuft.scale = Vector3.ONE * 0.5
		body.add_child(tuft)
	# Four posts and a thatched roof: the hut you walk into.
	var wood := _mat(Color(0.34, 0.22, 0.13), 0.9)
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			var post := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.075
			cm.bottom_radius = 0.1
			cm.height = 1.9
			cm.radial_segments = 8
			post.mesh = cm
			post.material_override = wood
			post.position = Vector3(sx * 1.12, 0.95, sz * 0.95)
			body.add_child(post)
	var beam_w := _box(Vector3(2.4, 0.1, 0.1), wood, Vector3(0, 1.86, 0.95))
	body.add_child(beam_w)
	body.add_child(_box(Vector3(2.4, 0.1, 0.1), wood, Vector3(0, 1.86, -0.95)))
	body.add_child(_roof())
	# The sign on the front beam.
	var board := _box(Vector3(1.05, 0.34, 0.07), _mat(Color(0.28, 0.17, 0.1), 0.85), Vector3(0, 1.58, 1.0))
	body.add_child(board)
	for sx in [-1, 1]:
		body.add_child(_box(Vector3(0.025, 0.2, 0.025), wood, Vector3(sx * 0.4, 1.76, 1.0)))
	var name_l := Label3D.new()
	name_l.text = "NEST"
	name_l.font = FONT
	name_l.font_size = 72
	name_l.pixel_size = 0.0042
	name_l.outline_size = 16
	name_l.outline_modulate = Color(0.12, 0.07, 0.03)
	name_l.modulate = Color(1.0, 0.86, 0.45)
	name_l.position = Vector3(0, 1.58, 1.05)
	name_l.shaded = false
	body.add_child(name_l)
	# A hanging lantern and a pennant pole give it a warm, lived-in look.
	var lan := KK.prop(G + "lantern_hanging.gltf")
	lan.position = Vector3(0.0, 1.78, 0.2)
	lan.scale = Vector3.ONE * 0.9
	body.add_child(lan)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.78, 0.45)
	l.light_energy = 1.6
	l.omni_range = 4.2
	l.position = Vector3(0, 1.5, 0.35)
	body.add_child(l)
	_glow = OmniLight3D.new()
	_glow.light_color = Color(1.0, 0.85, 0.5)
	_glow.light_energy = 0.0
	_glow.omni_range = 3.2
	_glow.position = Vector3(0, 0.7, 0.3)
	body.add_child(_glow)
	_badge = Label3D.new()
	_badge.text = "!"
	_badge.font = FONT
	_badge.font_size = 120
	_badge.pixel_size = 0.0075
	_badge.outline_size = 28
	_badge.outline_modulate = Color(0.35, 0.18, 0.02)
	_badge.modulate = Color(1.0, 0.85, 0.3)
	_badge.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_badge.no_depth_test = true
	_badge.render_priority = 5
	_badge.shaded = false
	_badge.position = Vector3(0, 3.0, 0.2)
	_badge.visible = false
	add_child(_badge)
	_fireflies()


func _roof() -> Node3D:
	var roof := Node3D.new()
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.05
	noise.seed = 7
	var nt := NoiseTexture2D.new()
	nt.noise = noise
	nt.seamless = true
	nt.width = 256
	nt.height = 256
	var ramp := Gradient.new()
	ramp.set_color(0, STRAW.darkened(0.45))
	ramp.set_color(1, STRAW.lightened(0.25))
	nt.color_ramp = ramp
	for spec in [[2.0, 1.6, 0.0], [1.55, 1.3, 0.45]]:
		var m := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.0
		cm.bottom_radius = float(spec[0]) * 0.92
		cm.height = float(spec[1]) * 0.62
		cm.radial_segments = 8
		cm.rings = 1
		m.mesh = cm
		var sm := StandardMaterial3D.new()
		sm.albedo_texture = nt
		sm.uv1_scale = Vector3(5.0, 1.0, 1.0)
		sm.roughness = 1.0
		sm.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.material_override = sm
		m.position = Vector3(0, 1.9 + cm.height * 0.5 + float(spec[2]) * 0.22, 0)
		roof.add_child(m)
	# A little finial on the point.
	var fin := MeshInstance3D.new()
	var sp := SphereMesh.new()
	sp.radius = 0.1
	sp.height = 0.2
	fin.mesh = sp
	fin.material_override = _mat(Color(0.95, 0.75, 0.3), 0.35)
	fin.position = Vector3(0, 1.9 + 1.0 + 0.12, 0)
	roof.add_child(fin)
	return roof


func _fireflies() -> void:
	var p := GPUParticles3D.new()
	p.amount = 12
	p.lifetime = 3.0
	p.local_coords = false
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 1.3
	pm.direction = Vector3.UP
	pm.spread = 60.0
	pm.initial_velocity_min = 0.08
	pm.initial_velocity_max = 0.25
	pm.gravity = Vector3(0, 0.05, 0)
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.35
	pm.color = Color(1.0, 0.9, 0.5)
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 0))
	ramp.add_point(0.3, Color(1, 1, 1, 1))
	ramp.set_color(ramp.get_point_count() - 1, Color(1, 0.8, 0.4, 0))
	var rt := GradientTexture1D.new()
	rt.gradient = ramp
	pm.color_ramp = rt
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.07, 0.07)
	var m := ShaderMaterial.new()
	m.shader = Fx.SOFT
	m.set_shader_parameter("intensity", 3.5)
	q.material = m
	p.draw_pass_1 = q
	p.position = Vector3(0, 0.9, 0)
	body.add_child(p)


func _mat(c: Color, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	return m


func _box(size: Vector3, m: Material, at: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = m
	mi.position = at
	return mi


func _disc(r: float, h: float, c: Color, y: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r * 1.03
	cm.height = h
	cm.radial_segments = 24
	mi.mesh = cm
	mi.material_override = _mat(c, 1.0)
	mi.position = Vector3(0, y + h * 0.5 - 0.01, 0)
	return mi


## Re-reads the hatchery: one egg per slot in use, ready ones rock and glow.
func refresh() -> void:
	for e in _eggs:
		e.queue_free()
	_eggs.clear()
	_ready_eggs = 0
	var now := int(Time.get_unix_time_from_system())
	var list: Array = SKS.hatchery(Game.data)
	for i in mini(list.size(), EGG_SPOTS.size()):
		var e: Dictionary = list[i]
		var ready := SKS.egg_ready(e, now)
		if ready:
			_ready_eggs += 1
		var col: Color = SDB.EGGS[str(e["kind"])]["color"]
		var egg := _egg(col, ready, SKS.egg_frac(e, now))
		egg.position = EGG_SPOTS[i] + Vector3(0, 0.12, 0)
		egg.rotation.y = i * 1.7
		body.add_child(egg)
		_eggs.append(egg)
	_badge.visible = _ready_eggs > 0


func _egg(col: Color, ready: bool, warm: float) -> Node3D:
	var root := Node3D.new()
	root.set_meta("ready", ready)
	var m := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	sm.radial_segments = 20
	sm.rings = 12
	m.mesh = sm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col.lerp(Color.WHITE, 0.12)
	mat.roughness = 0.28
	mat.rim_enabled = true
	mat.rim = 0.6
	mat.rim_tint = 0.5
	mat.emission_enabled = true
	mat.emission = col
	mat.emission_energy_multiplier = 1.1 if ready else 0.12 + 0.25 * warm
	m.material_override = mat
	m.scale = Vector3(0.32, 0.42, 0.32)
	m.position.y = 0.2
	root.add_child(m)
	# Speckles: a few dark dots so it reads as an egg, not a ball.
	for i in 5:
		var dot := MeshInstance3D.new()
		var ds := SphereMesh.new()
		ds.radius = 0.5
		ds.height = 1.0
		ds.radial_segments = 8
		ds.rings = 4
		dot.mesh = ds
		dot.material_override = _mat(col.darkened(0.45), 0.6)
		var a := i * 2.4
		var yy := -0.35 + 0.5 * float(i % 3) - 0.1
		var r := 0.16 * sqrt(maxf(1.0 - yy * yy, 0.0))
		dot.position = Vector3(sin(a) * r, 0.2 + yy * 0.21, cos(a) * r)
		dot.scale = Vector3(0.05, 0.035, 0.05)
		root.add_child(dot)
	if ready:
		var gl := OmniLight3D.new()
		gl.light_color = col
		gl.light_energy = 1.1
		gl.omni_range = 1.6
		gl.position = Vector3(0, 0.45, 0.15)
		root.add_child(gl)
	return root


func _process(dt: float) -> void:
	_t += dt
	var k := 0
	for e in _eggs:
		if bool(e.get_meta("ready")):
			# A rock every few seconds, like it is about to crack.
			var ph := fmod(_t * 0.5 + k * 0.37, 1.0)
			e.rotation.z = sin(ph * TAU * 3.0) * 0.16 * clampf(1.0 - ph * 1.6, 0.0, 1.0)
			e.position.y = 0.12 + 0.02 * sin(_t * 3.0 + k)
		k += 1
	if _badge.visible:
		_badge.position.y = 3.0 + 0.12 * sin(_t * 3.2)
		_badge.scale = Vector3.ONE * (1.0 + 0.06 * sin(_t * 6.4))
	_glow.light_energy = (0.8 + 0.4 * sin(_t * 3.0)) if _ready_eggs > 0 else 0.0


func tap_point() -> Vector3:
	return global_position + Vector3(0, 1.1, 0)


## Where you stand to knock: in front of the hut, on the camera side.
func door_point() -> Vector3:
	return global_transform * Vector3(0, 0, 1.35)


## The middle of the straw, where the hero ends up on the way in.
func inside_point() -> Vector3:
	return global_transform * Vector3(0, 0, 0.2)


## A quick squash when tapped.
func bump() -> void:
	if _bump:
		_bump.kill()
	body.scale = Vector3.ONE
	_bump = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_bump.tween_property(body, "scale", Vector3(1.05, 0.93, 1.05), 0.08)
	_bump.tween_property(body, "scale", Vector3.ONE, 0.25)
