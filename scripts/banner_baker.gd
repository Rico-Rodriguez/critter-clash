class_name BannerBaker
extends Node

## Renders each biome's map banner from the real hunt scene: the biome's
## ground, foliage, and props with its boss standing in the clearing, shot
## low and cinematic. Run after the hunt look changes:
##   godot --path . -- --bake-banners
## Writes assets/sprites/arenas/<biome>_banner.png (1080x480).

const SIZE := Vector2i(1080, 480)
const OUT := "res://assets/sprites/arenas"


func run() -> void:
	for entry in Catalog.BIOMES:
		await _bake(entry)


func _bake(entry: Dictionary) -> void:
	var id := str(entry["id"])
	var stage := Stage3D.new()
	stage.fixed_px = SIZE
	stage.size = Vector2(SIZE)
	add_child(stage)
	stage.viewport.msaa_3d = Viewport.MSAA_8X
	stage.bind_hunt(id)
	var look := stage._to3(Vector2(360, 640))
	# Fixed banner scale: the hunt boss grew to 11 m, which pushed the
	# flying dragon's head out of frame.
	var boss := stage._spawn_model(str(entry["boss"]), 3.7)
	boss.position = look + Vector3(1.2, 0, -1.0)
	boss.rotation.y = -float(boss.get_meta("face", PI)) + 0.5
	stage.world_root.add_child(boss)
	stage._outline(boss, Color("2a0c08"), 0.008)
	stage._play(boss, "idle")
	# A few of the biome's critters around the boss for scale and life.
	var skins: Array = entry.get("skins", [])
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(id)
	for i in mini(3, skins.size()):
		var m := stage._spawn_model(str(skins[i]), Stage3D.HERO_METERS * 0.55)
		m.position = look + Vector3(-2.6 + i * 1.3, 0, 0.6 + rng.randf() * 0.8)
		m.rotation.y = -float(m.get_meta("face", PI)) + rng.randf_range(-0.6, 0.6)
		stage.world_root.add_child(m)
		stage._play(m, "idle")
	# Low three-quarter shot across the clearing toward the boss.
	stage._mode = "banner"
	stage.camera.fov = 34.0
	stage.camera.position = look + Vector3(-1.2, 3.2, 10.5)
	stage.camera.look_at(look + Vector3(0.4, 2.0, -1.0), Vector3.UP)
	if id == "volcano":
		# The dragon hovers: step back and tilt up so the wing tips clear
		# the top edge with air to spare.
		stage.camera.position = look + Vector3(-1.4, 3.4, 13.0)
		stage.camera.look_at(look + Vector3(0.4, 2.9, -1.0), Vector3.UP)
	# Thicker air for the banner so the field edge melts into the sky.
	var holder := stage.world_root.get_node_or_null("World") as WorldEnvironment
	if holder != null:
		holder.environment.fog_density *= 4.0
		holder.environment.fog_sky_affect = 0.85
		holder.environment.adjustment_enabled = true
		holder.environment.adjustment_contrast = 1.12
		holder.environment.glow_enabled = true
		holder.environment.glow_intensity = 0.3
	# Cinematic grade: a low sun raking across the clearing from behind the
	# boss (rim light on every silhouette), and the far field softly defocused.
	stage.sun.rotation_degrees = Vector3(-16, 160, 0)
	stage.sun.light_energy *= 1.25
	stage.sun.shadow_enabled = true
	if id == "meadow":
		stage.sun.light_color = Color("ffb26a")
		if holder != null:
			var env := holder.environment
			env.fog_light_color = Color(0.86, 0.62, 0.42)
			env.ambient_light_color = Color("b8a07e")
			env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
			env.ambient_light_energy = 0.85
			env.fog_sky_affect = 0.4
			env.background_energy_multiplier = 0.55
			env.adjustment_saturation = 1.05
			env.tonemap_exposure = 0.95
	# Front fill from over the camera so faces are not lost against the sun.
	stage._lamp(Color("ffe2c0"), 3.0, stage.camera.position + Vector3(0.0, 1.0, -4.0), false, 14.0)
	if id == "meadow":
		# Cool rim from behind the boss so Thistle's cap and shoulders lift
		# off the tree trunks instead of melting into them.
		stage._lamp(Color("cfe0ff"), 9.0, boss.position + Vector3(0.6, 3.6, -2.6), false, 7.0)
		stage._lamp(Color("ffd9a8"), 4.0, boss.position + Vector3(-1.8, 2.2, -2.0), false, 5.0)
	match id:
		"meadow":
			# A fuller glade: bushes and flowers framing both sides, tall grass
			# in the foreground, a tree line closing off the horizon.
			var frng := RandomNumberGenerator.new()
			frng.seed = 11
			for i in 26:
				var side := -1.0 if i % 2 == 0 else 1.0
				var at := look + Vector3(side * frng.randf_range(3.2, 7.5), 0, frng.randf_range(-6.0, 5.5))
				stage._place_prop(["bush_flower", "fern", "fern", "flower_warm", "grass_tall"][i % 5], at, frng.randf_range(0.8, 1.6), true)
			for i in 40:
				var at := look + Vector3(frng.randf_range(-6.0, 6.0), 0, frng.randf_range(2.6, 6.0))
				stage._place_prop(["grass_tall", "grass_wispy", "flower_a", "flower_b", "clover"][i % 5], at, frng.randf_range(0.6, 1.0), false)
			for i in 14:
				var at := look + Vector3(lerpf(-14.0, 14.0, i / 13.0) + frng.randf_range(-0.8, 0.8), 0, -11.0 - frng.randf_range(0.0, 5.0))
				stage._place_prop(["tree_a", "tree_b", "tree_pine", "tree_pine_b"][i % 4], at, frng.randf_range(2.6, 3.6), true)
		"mushroom":
			# A glowing mushroom forest at violet dusk: giant caps framing the
			# clearing, cool teal spores drifting, a deep plum horizon.
			if holder != null:
				var sky_mat := ProceduralSkyMaterial.new()
				sky_mat.sky_top_color = Color("120c26")
				sky_mat.sky_horizon_color = Color("5a3a6e")
				sky_mat.sky_curve = 0.16
				sky_mat.ground_horizon_color = Color("4a3058")
				sky_mat.ground_bottom_color = Color("201628")
				sky_mat.sun_angle_max = 6.0
				holder.environment.sky.sky_material = sky_mat
				holder.environment.background_energy_multiplier = 0.85
				holder.environment.fog_light_color = Color(0.36, 0.3, 0.5)
				holder.environment.fog_sky_affect = 0.5
				holder.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
				holder.environment.ambient_light_color = Color("7a6aa8")
				holder.environment.ambient_light_energy = 0.7
				holder.environment.adjustment_saturation = 1.1
				holder.environment.glow_intensity = 0.6
				holder.environment.glow_bloom = 0.12
			stage.sun.light_color = Color("ffb08a")
			stage.sun.light_energy *= 0.8
			var mrng := RandomNumberGenerator.new()
			mrng.seed = 5
			for i in 12:
				var side := -1.0 if i % 2 == 0 else 1.0
				var at := look + Vector3(side * mrng.randf_range(4.0, 9.0), 0, mrng.randf_range(-12.0, 2.0))
				stage._place_prop(["mushroom_tall", "mushroom", "mushroom_tall"][i % 3], at, mrng.randf_range(3.0, 5.5), true)
			for i in 30:
				var at := look + Vector3(mrng.randf_range(-6.0, 6.0), 0, mrng.randf_range(1.5, 6.0))
				stage._place_prop(["mushroom", "fern", "grass_tall", "mushroom_shelf"][i % 4], at, mrng.randf_range(0.5, 1.0), false)
			# Bioluminescent pools of light under the caps.
			for i in 6:
				var lp := look + Vector3(mrng.randf_range(-6.0, 6.0), 0.6, mrng.randf_range(-8.0, 3.0))
				stage._lamp(Color("6fe0d0") if i % 2 == 0 else Color("c08aff"), 2.5, lp, false, 4.0)
			_motes(stage, look + Vector3(0, 2.0, -1.0), Vector3(9, 2.5, 6), Color(0.5, 1.0, 0.85), 160, 0.07, 0.05)
		"frost":
			# Cold clear air: a steel-blue sky, pale ice horizon, cool key,
			# and fine snow in the air.
			if holder != null:
				var sky_mat := ProceduralSkyMaterial.new()
				sky_mat.sky_top_color = Color("3a5a88")
				sky_mat.sky_horizon_color = Color("bcd2ea")
				sky_mat.sky_curve = 0.14
				sky_mat.ground_horizon_color = Color("bcd2ea")
				sky_mat.ground_bottom_color = Color("6a7e98")
				holder.environment.sky.sky_material = sky_mat
				holder.environment.background_energy_multiplier = 1.0
				holder.environment.fog_light_color = Color(0.7, 0.8, 0.94)
				holder.environment.fog_sky_affect = 0.35
				holder.environment.adjustment_saturation = 1.08
			stage.sun.light_color = Color("dfeaff")
			_motes(stage, look + Vector3(0, 3.0, -1.0), Vector3(10, 3.5, 7), Color(0.95, 0.97, 1.0), 260, 0.05, -0.35)
		"volcano":
			# Dark basalt, ash haze, ember-lit undersides, embers rising.
			if holder != null:
				var env := holder.environment
				var sky_mat := ProceduralSkyMaterial.new()
				sky_mat.sky_top_color = Color("120a0a")
				sky_mat.sky_horizon_color = Color("5a2a18")
				sky_mat.sky_curve = 0.2
				sky_mat.ground_horizon_color = Color("3a1a12")
				sky_mat.ground_bottom_color = Color("120a08")
				env.sky.sky_material = sky_mat
				env.background_energy_multiplier = 0.9
				env.fog_light_color = Color(0.42, 0.22, 0.14)
				env.fog_density *= 1.3
				env.fog_sky_affect = 0.6
				env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
				env.ambient_light_color = Color("6a4a40")
				env.ambient_light_energy = 0.55
				env.adjustment_saturation = 0.95
				env.adjustment_contrast = 1.18
				env.tonemap_exposure = 0.95
				env.glow_intensity = 0.7
				env.glow_bloom = 0.15
				env.glow_hdr_threshold = 0.9
			stage.sun.light_color = Color("ff9a5a")
			stage.sun.light_energy *= 0.75
			# Lava glow from below lights the dragon's belly and the rocks.
			stage._lamp(Color("ff5a1a"), 5.0, boss.position + Vector3(0, 0.4, 1.5), false, 7.0)
			stage._lamp(Color("ff6a2a"), 3.0, look + Vector3(-4.0, 0.3, 2.0), false, 5.0)
			_motes(stage, look + Vector3(0, 1.8, -1.0), Vector3(9, 2.5, 6), Color(1.0, 0.5, 0.15), 180, 0.06, 0.6)
	# Clean silhouettes: no tall prop directly behind the boss (Thistle was
	# lost against a red tree) and none filling the lens up front.
	var cam_at := stage.camera.global_position
	for prop in stage._props:
		if not is_instance_valid(prop) or not prop is Node3D:
			continue
		var n := prop as Node3D
		var tall := stage._measure(n).size.y * n.scale.y > 1.4
		if not tall:
			continue
		var p := n.global_position
		var clear := 5.5 if id == "meadow" else 3.2
		var behind_boss := absf(p.x - boss.position.x) < clear and p.z < boss.position.z - 0.5
		var in_lens := p.distance_to(cam_at) < 8.0
		if behind_boss or in_lens:
			n.visible = false
	# No engine DOF: on this renderer it softened the whole banner.
	stage.camera.attributes = null
	for i in 12:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := stage.viewport.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.save_png(ProjectSettings.globalize_path("%s/%s_banner.png" % [OUT, id]))
	print("BANNER ", id)
	stage.queue_free()
	await get_tree().process_frame


## Drifting particles for atmosphere: spores, snow, or rising embers.
## rise > 0 floats up, < 0 falls. Pre-simulated so a still frame is full.
func _motes(stage: Stage3D, at: Vector3, extents: Vector3, color: Color, amount: int, size: float, rise: float) -> void:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = 6.0
	p.preprocess = 6.0
	p.position = at
	p.visibility_aabb = AABB(-extents * 2.0, extents * 4.0)
	var proc := ParticleProcessMaterial.new()
	proc.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	proc.emission_box_extents = extents
	proc.gravity = Vector3(0, rise, 0)
	proc.initial_velocity_min = 0.02
	proc.initial_velocity_max = 0.15
	proc.direction = Vector3(0, signf(rise), 0)
	proc.spread = 60.0
	proc.turbulence_enabled = true
	proc.turbulence_noise_strength = 0.5
	proc.turbulence_noise_scale = 3.0
	proc.scale_min = 0.5
	proc.scale_max = 1.4
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0))
	fade.set_color(1, Color(1, 1, 1, 0))
	fade.add_point(0.15, Color(1, 1, 1, 1))
	fade.add_point(0.8, Color(1, 1, 1, 1))
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	proc.color_ramp = ramp
	p.process_material = proc
	var dot := QuadMesh.new()
	dot.size = Vector2(size, size)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_color = color
	m.albedo_texture = _soft_dot()
	dot.material = m
	p.draw_pass_1 = dot
	stage.world_root.add_child(p)


var _dot_tex: Texture2D


func _soft_dot() -> Texture2D:
	if _dot_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 32
		t.height = 32
		_dot_tex = t
	return _dot_tex
