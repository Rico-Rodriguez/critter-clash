class_name Chest3D
extends Node3D

## The game's treasure chest: the CC0 Kenney Pirate Kit chest restyled with
## plank-wood and forged-metal PBR, a gilt lock and corner brackets, and a
## hoard inside that glows when the lid lifts. One model serves the chest
## screen (live) and the home slots (baked icons).

const MODEL := "res://assets/models/chest_kenney.glb"

const TONES := {
	"wood": {"wood": Color(0.5, 0.32, 0.22), "band": Color(0.24, 0.22, 0.2), "metal": 0.8, "rough": 0.55, "trim": Color(0.9, 0.68, 0.3)},
	"silver": {"wood": Color(0.7, 0.52, 0.38), "band": Color(0.72, 0.74, 0.78), "metal": 0.95, "rough": 0.32, "trim": Color(0.82, 0.84, 0.88)},
	"gold": {"wood": Color(0.55, 0.3, 0.22), "band": Color(0.95, 0.72, 0.32), "metal": 1.0, "rough": 0.3, "trim": Color(1.0, 0.8, 0.4)},
	"magic": {"wood": Color(0.42, 0.3, 0.55), "band": Color(0.62, 0.55, 0.8), "metal": 0.9, "rough": 0.35, "trim": Color(0.85, 0.75, 1.0)},
}

var lid: Node3D
var hoard: Node3D
var inner_light: OmniLight3D
var _mats: Array[ShaderMaterial] = []
var _hoard_mat: StandardMaterial3D
var _open := 0.0


func _init(tone: String = "wood") -> void:
	var scene: PackedScene = load(MODEL)
	var model := scene.instantiate()
	add_child(model)
	# Wider than deep, like a proper strongbox.
	model.scale = Vector3(1.32, 1.0, 1.0)
	var base_mesh := model.find_child("chest", true, false) as MeshInstance3D
	if base_mesh == null and model is MeshInstance3D:
		base_mesh = model
	lid = model.find_child("lid", true, false) as Node3D
	for node in [base_mesh, lid]:
		if node is MeshInstance3D:
			var mat := ShaderMaterial.new()
			mat.shader = load("res://shaders/chest.gdshader")
			mat.set_shader_parameter("atlas", load("res://assets/models/Textures/colormap.png"))
			mat.set_shader_parameter("wood_tex", load("res://assets/textures/wood_color.jpg"))
			mat.set_shader_parameter("wood_nrm", load("res://assets/textures/wood_normal.jpg"))
			mat.set_shader_parameter("wood_rgh", load("res://assets/textures/wood_rough.jpg"))
			mat.set_shader_parameter("metal_nrm", load("res://assets/textures/metal_normal.jpg"))
			mat.set_shader_parameter("metal_rgh", load("res://assets/textures/metal_rough.jpg"))
			(node as MeshInstance3D).material_override = mat
			_mats.append(mat)
	_trim(base_mesh, tone)
	_build_hoard(base_mesh)
	set_tone(tone)


func set_tone(tone: String) -> void:
	var t: Dictionary = TONES.get(tone, TONES["wood"])
	for mat in _mats:
		mat.set_shader_parameter("wood_tint", t["wood"])
		mat.set_shader_parameter("band_col", t["band"])
		mat.set_shader_parameter("band_metal", float(t["metal"]))
		mat.set_shader_parameter("band_rough", float(t["rough"]))
		var glow := Color(0.25, 0.12, 0.45) * 0.25 if tone == "magic" else Color.BLACK
		mat.set_shader_parameter("glow_col", glow)


## 0 closed .. 1 fully open (lid swung back ~105 degrees).
func set_open(f: float) -> void:
	_open = f
	if lid:
		lid.rotation.x = -deg_to_rad(105.0) * f
	if hoard:
		hoard.visible = f > 0.02
	if inner_light:
		inner_light.light_energy = 2.2 * clampf(f * 1.5, 0.0, 1.0)


func set_flash(f: float) -> void:
	for mat in _mats:
		mat.set_shader_parameter("flash", f)
	if _hoard_mat:
		_hoard_mat.emission_energy_multiplier = 0.9 * f


## Environment for any stage showing the chest: transparent background but a
## warm dusky sky for metal reflections, so iron and gilt read as metal.
static func stage_env(ambient: float = 0.45) -> Environment:
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("8a7470")
	sky_mat.sky_horizon_color = Color("ffd8a0")
	sky_mat.ground_horizon_color = Color("8a6040")
	sky_mat.ground_bottom_color = Color("1a120c")
	sky_mat.sun_angle_max = 30.0
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = ambient
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.0
	env.tonemap_white = 6.0
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 1.1
	return env


func _metal(col: Color, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.metallic = 1.0
	m.roughness = rough
	m.metallic_specular = 0.7
	m.normal_enabled = true
	m.normal_texture = load("res://assets/textures/metal_normal.jpg")
	m.normal_scale = 0.4
	m.uv1_triplanar = true
	m.uv1_scale = Vector3(3, 3, 3)
	return m


## Gilt lock plate and hasp on the front, brackets on the corners.
func _trim(base_mesh: Node3D, tone: String) -> void:
	var gold := _metal(Color(1.0, 0.78, 0.4), 0.22)
	var t: Dictionary = TONES.get(tone, TONES["wood"])
	var bracket := _metal(t["trim"], 0.32)
	var plate := MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(0.26, 0.28, 0.05)
	plate.mesh = pm
	plate.material_override = gold
	plate.position = Vector3(0, 0.38, 0.655)
	add_child(plate)
	var hole := MeshInstance3D.new()
	var hm := CylinderMesh.new()
	hm.top_radius = 0.03
	hm.bottom_radius = 0.03
	hm.height = 0.02
	hole.mesh = hm
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.03, 0.02, 0.01)
	hole.material_override = dark
	hole.rotation.x = PI * 0.5
	hole.position = Vector3(0, 0.35, 0.68)
	add_child(hole)
	if lid:
		# The hasp rides on the lid, so it swings with it.
		var hasp := MeshInstance3D.new()
		var hb := BoxMesh.new()
		hb.size = Vector3(0.14, 0.22, 0.045)
		hasp.mesh = hb
		hasp.material_override = gold
		hasp.position = Vector3(0, 0.0, 1.17)
		lid.add_child(hasp)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var b := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(0.12, 0.14, 0.12)
			b.mesh = bm
			b.material_override = bracket
			b.position = Vector3(sx * 0.8, 0.07, sz * 0.6)
			add_child(b)
	# Gilt rivets studding the front and back of each end band.
	var rivet := SphereMesh.new()
	rivet.radius = 0.035
	rivet.height = 0.05
	rivet.radial_segments = 8
	rivet.rings = 4
	var rm := MultiMesh.new()
	rm.transform_format = MultiMesh.TRANSFORM_3D
	rm.mesh = rivet
	rm.instance_count = 16
	var n := 0
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			for y in [0.24, 0.4]:
				for dx in [0.0, 0.0]:
					rm.set_instance_transform(n, Transform3D(Basis.IDENTITY, Vector3(sx * 0.75 + dx, y, sz * 0.645)))
					n += 1
	var rivets := MultiMeshInstance3D.new()
	rivets.multimesh = rm
	rivets.material_override = gold
	add_child(rivets)
	# Hidden from shadows they would only cost draws.
	for c in get_children():
		if c is GeometryInstance3D and c != base_mesh:
			(c as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## A heap of coins and gems that fills the top of the box; visible only when
## the lid lifts, lit from within. Coins are instanced metallic discs piled
## over a dark gold core, with faceted gems and a few twinkling glints.
func _build_hoard(_base: Node3D) -> void:
	hoard = Node3D.new()
	add_child(hoard)
	var metal_n := load("res://assets/textures/metal_normal.jpg") as Texture2D
	_hoard_mat = StandardMaterial3D.new()
	_hoard_mat.albedo_color = Color(1.0, 0.86, 0.52)
	_hoard_mat.vertex_color_use_as_albedo = true
	_hoard_mat.metallic = 1.0
	_hoard_mat.roughness = 0.34
	_hoard_mat.metallic_specular = 0.7
	if metal_n:
		_hoard_mat.normal_enabled = true
		_hoard_mat.normal_texture = metal_n
		_hoard_mat.normal_scale = 0.25
	_hoard_mat.rim_enabled = true
	_hoard_mat.rim = 0.25
	_hoard_mat.rim_tint = 0.8
	_hoard_mat.emission_enabled = true
	_hoard_mat.emission = Color(0.55, 0.32, 0.08)
	_hoard_mat.emission_energy_multiplier = 0.0
	# Core: a dark, rough gold lump so gaps between coins read as depth.
	var core_mat := StandardMaterial3D.new()
	core_mat.albedo_color = Color(0.42, 0.28, 0.1)
	core_mat.metallic = 1.0
	core_mat.roughness = 0.55
	var mound := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 0.26
	mound.mesh = sm
	mound.scale = Vector3(1.5, 1.0, 1.05)
	mound.position = Vector3(0, 0.49, 0)
	mound.material_override = core_mat
	hoard.add_child(mound)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var coin := CylinderMesh.new()
	coin.top_radius = 0.054
	coin.bottom_radius = 0.054
	coin.height = 0.014
	coin.radial_segments = 18
	coin.rings = 1
	var golds := [Color(1.0, 0.86, 0.5), Color(0.98, 0.8, 0.42), Color(1.0, 0.9, 0.62), Color(0.92, 0.74, 0.4)]
	var xf: Array[Transform3D] = []
	var tints: Array[Color] = []
	# Two layers: a dense bed hugging the mound and a scatter of tilted coins
	# on top, so the heap silhouette is lumpy rather than a smooth dome.
	for i in 460:
		var x := rng.randf_range(-0.7, 0.7)
		var z := rng.randf_range(-0.47, 0.47)
		var dome := maxf(0.0, (1.0 - pow(x / 0.76, 2.0)) * (1.0 - pow(z / 0.53, 2.0)))
		var top := i >= 340
		var y := 0.49 + 0.135 * dome + (rng.randf_range(0.012, 0.05) if top else rng.randf_range(-0.012, 0.012))
		var tilt := 0.8 if top else 0.3
		var basis := Basis.from_euler(Vector3(rng.randf_range(-tilt, tilt), rng.randf() * TAU, rng.randf_range(-tilt, tilt)))
		xf.append(Transform3D(basis, Vector3(x, y, z)))
		tints.append(golds[rng.randi() % golds.size()])
	# A couple of short stacks for scale and silhouette.
	for st in [[Vector3(0.5, 0.52, 0.22), 6], [Vector3(-0.56, 0.5, -0.18), 4]]:
		for k in int(st[1]):
			var off := Vector3(rng.randf_range(-0.006, 0.006), 0.015 * k, rng.randf_range(-0.006, 0.006))
			xf.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU), st[0] + off))
			tints.append(golds[rng.randi() % golds.size()])
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = coin
	mm.instance_count = xf.size()
	for i in xf.size():
		mm.set_instance_transform(i, xf[i])
		mm.set_instance_color(i, tints[i])
	var coins := MultiMeshInstance3D.new()
	coins.multimesh = mm
	coins.material_override = _hoard_mat
	hoard.add_child(coins)
	# Faceted gems: low-poly so each facet catches a highlight.
	var gems := [
		[Vector3(-0.3, 0.66, 0.08), Color(0.85, 0.06, 0.14), 0.075],
		[Vector3(0.33, 0.645, -0.12), Color(0.1, 0.65, 0.3), 0.065],
		[Vector3(0.05, 0.67, 0.22), Color(0.16, 0.32, 0.95), 0.06],
		[Vector3(-0.08, 0.68, -0.2), Color(0.85, 0.06, 0.14), 0.05],
		[Vector3(0.52, 0.6, 0.02), Color(0.62, 0.2, 0.85), 0.055],
	]
	for g in gems:
		var gem_mat := StandardMaterial3D.new()
		gem_mat.albedo_color = (g[1] as Color).darkened(0.25)
		gem_mat.roughness = 0.04
		gem_mat.metallic = 0.25
		gem_mat.metallic_specular = 1.0
		gem_mat.rim_enabled = true
		gem_mat.rim = 0.6
		gem_mat.rim_tint = 1.0
		gem_mat.emission_enabled = true
		gem_mat.emission = g[1]
		gem_mat.emission_energy_multiplier = 0.3
		var gem := MeshInstance3D.new()
		gem.mesh = _brilliant(float(g[2]) * 1.35)
		gem_mat.vertex_color_use_as_albedo = true
		gem.position = g[0]
		gem.rotation = Vector3(rng.randf_range(-0.5, 0.5), rng.randf() * TAU, rng.randf_range(-0.5, 0.5))
		gem.material_override = gem_mat
		hoard.add_child(gem)
	_build_glints(rng)
	inner_light = OmniLight3D.new()
	inner_light.light_color = Color(1.0, 0.85, 0.6)
	inner_light.omni_range = 3.5
	inner_light.light_energy = 0.0
	inner_light.position = Vector3(0, 0.95, 0.2)
	add_child(inner_light)
	for c in hoard.get_children():
		(c as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	hoard.visible = false


## Star-shaped additive glints that twinkle over the coins.
func _build_glints(rng: RandomNumberGenerator) -> void:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
varying float phase;
varying float speed;
void vertex() {
	phase = INSTANCE_CUSTOM.r * 6.2831;
	speed = 1.6 + INSTANCE_CUSTOM.b;
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	VERTEX *= (0.6 + 0.4 * INSTANCE_CUSTOM.g);
}
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float star = max(0.0, 1.0 - abs(p.x) * 9.0 - abs(p.y) * 1.1) + max(0.0, 1.0 - abs(p.y) * 9.0 - abs(p.x) * 1.1);
	float core = exp(-dot(p, p) * 14.0);
	float tw = pow(max(0.0, sin(TIME * speed + phase)), 6.0);
	float a = (star * 0.8 + core) * tw;
	ALBEDO = vec3(1.0, 0.9, 0.62) * a * 2.2;
	ALPHA = clamp(a, 0.0, 1.0);
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	var q := QuadMesh.new()
	q.size = Vector2(0.22, 0.22)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = q
	mm.instance_count = 9
	for i in 9:
		var x := rng.randf_range(-0.6, 0.6)
		var z := rng.randf_range(-0.38, 0.38)
		var dome := maxf(0.0, (1.0 - pow(x / 0.76, 2.0)) * (1.0 - pow(z / 0.53, 2.0)))
		mm.set_instance_transform(i, Transform3D(Basis(), Vector3(x, 0.52 + 0.14 * dome + 0.03, z)))
		mm.set_instance_custom_data(i, Color(float(i) / 9.0, rng.randf(), rng.randf_range(0.0, 1.4), 0.0))
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = mat
	hoard.add_child(mi)


## A brilliant-cut gem: octagonal table, a crown of 16 facets and a
## pavilion down to a point, with flat normals so every facet catches its
## own highlight. Alternate facets are tinted lighter or darker to fake
## the internal fire a real stone shows.
static func _brilliant(r: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 8
	var table: Array[Vector3] = []
	var girdle: Array[Vector3] = []
	for i in n:
		var a := TAU * float(i) / float(n)
		table.append(Vector3(cos(a), 0, sin(a)) * r * 0.55 + Vector3(0, r * 0.42, 0))
	for i in n * 2:
		var a := TAU * (float(i) + 0.5) / float(n * 2)
		girdle.append(Vector3(cos(a), 0, sin(a)) * r)
	var apex := Vector3(0, -r * 0.95, 0)
	var top := Vector3(0, r * 0.42, 0)
	var tris: Array = []
	for i in n:
		tris.append([top, table[(i + 1) % n], table[i], 1.15])
		var g0 := girdle[i * 2]
		var g1 := girdle[i * 2 + 1]
		var g2 := girdle[(i * 2 + 2) % (n * 2)]
		var gprev := girdle[(i * 2 - 1 + n * 2) % (n * 2)]
		# Crown: star and kite facets between table and girdle.
		tris.append([table[i], table[(i + 1) % n], g1, 1.0])
		tris.append([table[i], g1, g0, 0.82])
		tris.append([table[i], g0, gprev, 0.95])
		tris.append([table[(i + 1) % n], g2, g1, 0.88])
	for i in n * 2:
		tris.append([girdle[i], girdle[(i + 1) % (n * 2)], apex, 0.62 if i % 2 == 0 else 0.45])
	for t in tris:
		var a: Vector3 = t[0]
		var b: Vector3 = t[1]
		var c: Vector3 = t[2]
		var nrm := (b - a).cross(c - a).normalized()
		if nrm.dot((a + b + c) / 3.0) < 0.0:
			var tmp := b
			b = c
			c = tmp
			nrm = -nrm
		var k := float(t[3])
		st.set_color(Color(k, k, k))
		st.set_normal(nrm)
		# Godot front faces wind clockwise.
		st.add_vertex(a)
		st.add_vertex(c)
		st.add_vertex(b)
	return st.commit()
