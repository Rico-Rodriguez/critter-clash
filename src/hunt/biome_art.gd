extends RefCounted
## Art helpers shared by the Frozen Crypt and the Burning Swamp (preloaded by path,
## no class_name): methane vents, flames and the weather particles. Everything here
## is built for a clean, crisp read: opaque PBR meshes batched into MultiMeshes,
## hard-edged particles, no fog and no bloom. The zones' own pieces are in
## kit_mesh.gd and the art kits (kit_models.gd).

const SOFT := preload("res://src/fx/soft.gdshader")
static var _mats := {}
static var _meshes := {}


static func mat(id: String) -> StandardMaterial3D:
	if _mats.has(id):
		return _mats[id]
	var m := StandardMaterial3D.new()
	match id:
		"char":
			m.albedo_color = Color(0.09, 0.08, 0.075)
			m.roughness = 0.9
		"vent":
			m.albedo_color = Color(0.2, 0.05, 0.0)
			m.roughness = 0.6
			m.emission_enabled = true
			m.emission = Color(1.0, 0.4, 0.05)
			m.emission_energy_multiplier = 1.6
	_mats[id] = m
	return m


static func mesh(id: String) -> Mesh:
	if _meshes.has(id):
		return _meshes[id]
	var out: Mesh
	match id:
		"lump":
			var u := SphereMesh.new()
			u.radius = 1.0
			u.height = 2.0
			u.radial_segments = 10
			u.rings = 5
			out = u
		"disc":
			var d := CylinderMesh.new()
			d.top_radius = 1.0
			d.bottom_radius = 1.0
			d.height = 0.04
			d.radial_segments = 24
			d.rings = 1
			out = d
	_meshes[id] = out
	return out


## One MultiMesh node (one draw) from a list of transforms.
static func batch(a: Node3D, id: String, material: Material, xfs: Array, shadow := false) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh(id)
	mm.instance_count = xfs.size()
	for i in xfs.size():
		mm.set_instance_transform(i, xfs[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Biome_" + id
	mmi.multimesh = mm
	mmi.material_override = material
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	a.add_child(mmi)
	return mmi


## Methane vents: a charred rim around a glowing mouth, registered as hazards.
static func vents(a: Arena, spots: Array) -> void:
	var rims: Array = []
	var mouths: Array = []
	for p: Vector3 in spots:
		for k in 10:
			var ang := TAU * k / 10.0 + a._rng.randf_range(-0.12, 0.12)
			var s := a._rng.randf_range(0.34, 0.5)
			rims.append(Transform3D(Basis(Vector3.UP, ang).scaled(Vector3(s * 1.3, s * 0.7, s)), p + Vector3(sin(ang), 0.06, cos(ang)) * 1.12))
		mouths.append(Transform3D(Basis.IDENTITY.scaled(Vector3(0.95, 1, 0.95)), p + Vector3(0, 0.0, 0)))
		a.hazard_spots.append(Vector3(p.x, 0, p.z))
	if not spots.is_empty():
		batch(a, "lump", mat("char"), rims)
		batch(a, "disc", mat("vent"), mouths)


## A small standing fire (burning stump, brazier): a few soft flame particles.
static func flame(a: Arena, at: Vector3, size := 0.5) -> void:
	var p := GPUParticles3D.new()
	p.amount = 14
	p.lifetime = 0.9
	p.local_coords = false
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visibility_aabb = AABB(Vector3(-2, 0, -2), Vector3(4, 4, 4))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.18
	pm.direction = Vector3.UP
	pm.spread = 14.0
	pm.initial_velocity_min = 0.9
	pm.initial_velocity_max = 1.6
	pm.gravity = Vector3(0, 0.6, 0)
	pm.scale_min = 0.7
	pm.scale_max = 1.2
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.85, 0.35, 0.0))
	ramp.add_point(0.15, Color(1.0, 0.7, 0.2, 1.0))
	ramp.add_point(0.6, Color(1.0, 0.35, 0.08, 0.8))
	ramp.set_color(ramp.get_point_count() - 1, Color(0.4, 0.08, 0.02, 0.0))
	var rt := GradientTexture1D.new()
	rt.gradient = ramp
	pm.color_ramp = rt
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	var m := ShaderMaterial.new()
	m.shader = SOFT
	m.set_shader_parameter("intensity", 2.2)
	q.material = m
	p.draw_pass_1 = q
	p.position = at + Vector3(0, 0.2, 0)
	a.add_child(p)


## A hard-edged round dot (white, alpha cut at the rim) for crisp particles.
static func _dot() -> Texture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.add_point(0.82, Color(1, 1, 1, 1))
	g.set_color(g.get_point_count() - 1, Color(1, 1, 1, 0))
	g.set_offset(g.get_point_count() - 1, 0.9)
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 32
	t.height = 32
	return t


## Falling snow or rising embers over the arena: hard little quads, never a
## haze. Returns the emitter (Arena follows it along the Long Road).
static func weather(a: Arena, kind: String, span_z: float) -> GPUParticles3D:
	var snow := kind == "snow"
	var p := GPUParticles3D.new()
	p.name = "Weather"
	p.amount = 520 if snow else 150
	p.lifetime = 3.6 if snow else 4.5
	p.preprocess = p.lifetime
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3(-40, -2, -50), Vector3(80, 14, 90))
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3((a.max_x - a.min_x) * 0.58, 0.3, span_z * 0.55)
	if snow:
		pm.direction = Vector3(0.18, -1.0, 0.05)
		pm.spread = 6.0
		pm.initial_velocity_min = 2.3
		pm.initial_velocity_max = 3.3
		pm.gravity = Vector3.ZERO
		pm.turbulence_enabled = true
		pm.turbulence_noise_strength = 0.35
		pm.turbulence_noise_scale = 2.5
		pm.scale_min = 0.7
		pm.scale_max = 1.5
	else:
		pm.direction = Vector3.UP
		pm.spread = 28.0
		pm.initial_velocity_min = 0.7
		pm.initial_velocity_max = 1.7
		pm.gravity = Vector3(0.1, 0.35, 0)
		pm.turbulence_enabled = true
		pm.turbulence_noise_strength = 0.5
		pm.turbulence_noise_scale = 3.0
		pm.scale_min = 0.6
		pm.scale_max = 1.3
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 0))
	ramp.add_point(0.12, Color(1, 1, 1, 1))
	ramp.add_point(0.8, Color(1, 1, 1, 1))
	ramp.set_color(ramp.get_point_count() - 1, Color(1, 1, 1, 0))
	var rt := GradientTexture1D.new()
	rt.gradient = ramp
	pm.color_ramp = rt
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.09, 0.09) if snow else Vector2(0.08, 0.08)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(1, 1, 1) if snow else Color(1.0, 0.58, 0.18)
	m.albedo_texture = _dot()
	q.material = m
	p.draw_pass_1 = q
	p.position = Vector3((a.min_x + a.max_x) * 0.5, 9.0 if snow else 0.3, (a.min_z + a.max_z) * 0.5)
	a.add_child(p)
	return p
