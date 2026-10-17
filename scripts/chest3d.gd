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
		_hoard_mat.emission_energy_multiplier = 0.12 + 0.8 * f


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
## the lid lifts, lit from within.
func _build_hoard(_base: Node3D) -> void:
	hoard = Node3D.new()
	add_child(hoard)
	_hoard_mat = StandardMaterial3D.new()
	_hoard_mat.albedo_color = Color(0.95, 0.76, 0.42)
	_hoard_mat.metallic = 1.0
	_hoard_mat.roughness = 0.3
	_hoard_mat.emission_enabled = true
	_hoard_mat.emission = Color(0.9, 0.5, 0.15)
	_hoard_mat.emission_energy_multiplier = 0.12
	var mound := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 0.3
	mound.mesh = sm
	mound.scale = Vector3(1.55, 1.0, 1.1)
	mound.position = Vector3(0, 0.5, 0)
	mound.material_override = _hoard_mat
	hoard.add_child(mound)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var coin := CylinderMesh.new()
	coin.top_radius = 0.07
	coin.bottom_radius = 0.07
	coin.height = 0.018
	coin.radial_segments = 16
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = coin
	mm.instance_count = 60
	for i in 60:
		var x := rng.randf_range(-0.65, 0.65)
		var z := rng.randf_range(-0.45, 0.45)
		var y := 0.5 + 0.15 * (1.0 - pow(x / 0.75, 2.0)) * (1.0 - pow(z / 0.55, 2.0)) + 0.01
		var basis := Basis.from_euler(Vector3(rng.randf_range(-0.6, 0.6), rng.randf(), rng.randf_range(-0.6, 0.6)))
		mm.set_instance_transform(i, Transform3D(basis, Vector3(x, y, z)))
	var coins := MultiMeshInstance3D.new()
	coins.multimesh = mm
	coins.material_override = _hoard_mat
	hoard.add_child(coins)
	var gem_mat := StandardMaterial3D.new()
	gem_mat.albedo_color = Color(0.9, 0.12, 0.2)
	gem_mat.roughness = 0.1
	gem_mat.metallic_specular = 1.0
	gem_mat.emission_enabled = true
	gem_mat.emission = Color(0.8, 0.05, 0.15)
	gem_mat.emission_energy_multiplier = 0.8
	for g in [Vector3(-0.3, 0.64, 0.1), Vector3(0.35, 0.62, -0.1)]:
		var gem := MeshInstance3D.new()
		var gm := SphereMesh.new()
		gm.radius = 0.07
		gm.height = 0.14
		gm.radial_segments = 6
		gm.rings = 3
		gem.mesh = gm
		gem.position = g
		gem.material_override = gem_mat
		hoard.add_child(gem)
	inner_light = OmniLight3D.new()
	inner_light.light_color = Color(1.0, 0.85, 0.6)
	inner_light.omni_range = 3.5
	inner_light.light_energy = 0.0
	inner_light.position = Vector3(0, 0.95, 0.2)
	add_child(inner_light)
	for c in hoard.get_children():
		(c as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	hoard.visible = false
