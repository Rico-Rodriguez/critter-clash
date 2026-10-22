extends RefCounted
## Turns the camp into the app icon set: the hero alone in the dark, holding
## the light, graves behind. Used by `--capture --shots=appicon` (main.gd);
## tools/dev/icon.sh renders it and writes assets/icon.png.

const G := "res://assets/kaykit/graveyard/"


static func stage(lob: Node3D) -> Camera3D:
	lob.ui.visible = false
	# Keep the hero, drop the camp: props, lights, fire, the moon.
	for c in lob.get_children():
		if c == lob.hero or c is WorldEnvironment or c is CanvasItem or c is CanvasLayer:
			continue
		if c is Node3D:
			c.visible = false
	for c in lob.get_children():
		if c is WorldEnvironment:
			var env: Environment = c.environment
			env.background_mode = Environment.BG_COLOR
			env.background_color = Color(0.02, 0.05, 0.08)
			env.ambient_light_color = Color(0.25, 0.4, 0.55)
			env.ambient_light_energy = 0.15
			env.fog_enabled = true
			env.fog_light_color = Color(0.05, 0.12, 0.16)
			env.fog_density = 0.06
			env.glow_enabled = true
			env.glow_intensity = 1.1
			env.glow_bloom = 0.15
			env.glow_hdr_threshold = 0.8
	var root := Node3D.new()
	root.name = "IconStage"
	lob.add_child(root)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(40, 40)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.09, 0.1, 0.11)
	gm.roughness = 1.0
	ground.material_override = gm
	root.add_child(ground)
	# Graves behind, left and right of the hero, half lost in the fog.
	for spec in [["gravestone.gltf", Vector3(-2.2, 0, -3.5), 0.3, 1.3], ["grave_A.gltf", Vector3(2.3, 0, -4.5), -0.35, 1.4],
			["gravemarker_A.gltf", Vector3(-3.6, 0, -7.0), 0.1, 1.6], ["tree_dead_large.gltf", Vector3(3.8, 0, -9.5), 1.0, 2.2],
			["gravestone.gltf", Vector3(0.9, 0, -8.0), -0.1, 1.4]]:
		var n := KK.prop(G + str(spec[0]))
		n.position = spec[1]
		n.rotation.y = spec[2]
		n.scale = Vector3.ONE * float(spec[3])
		root.add_child(n)
	# The light the game is named for: a lantern at the hero's feet, close to
	# the lens, lighting the face from below.
	var lantern := KK.prop(G + "lantern_standing.gltf")
	lantern.position = Vector3(0.8, 0, 0.55)
	lantern.rotation.y = -0.5
	lantern.scale = Vector3.ONE * 0.85
	root.add_child(lantern)
	var flame := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.07
	sm.height = 0.12
	flame.mesh = sm
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.albedo_color = Color(1.0, 0.85, 0.5)
	fm.emission_enabled = true
	fm.emission = Color(1.0, 0.7, 0.3)
	fm.emission_energy_multiplier = 8.0
	# Drawn through the lantern's frame: the glow is the point of the picture.
	fm.no_depth_test = true
	fm.render_priority = 10
	flame.material_override = fm
	root.add_child(flame)
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.66, 0.3)
	lamp.light_energy = 5.0
	lamp.omni_range = 5.0
	lamp.omni_attenuation = 0.8
	flame.add_child(lamp)
	# A soft halo around the flame, so it reads as light even at 60 px.
	var halo := MeshInstance3D.new()
	var hq := QuadMesh.new()
	hq.size = Vector2(1.1, 1.1)
	halo.mesh = hq
	var hm := StandardMaterial3D.new()
	hm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	hm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	hm.no_depth_test = true
	hm.render_priority = 9
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 0.75, 0.4, 0.9))
	grad.set_color(1, Color(1.0, 0.5, 0.2, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(0.5, 0.0)
	hm.albedo_texture = gt
	halo.material_override = hm
	flame.add_child(halo)
	# Find the glass: the flame sits at the middle of the lantern's bounds.
	var box := AABB()
	for mi in KK.meshes(lantern):
		var mb: AABB = mi.global_transform * mi.get_aabb()
		box = mb if box.size == Vector3.ZERO else box.merge(mb)
	flame.global_position = box.get_center() + Vector3(0, box.size.y * 0.12, 0)
	# A cold rim from behind so the silhouette reads against the dark.
	var rim := DirectionalLight3D.new()
	rim.light_color = Color(0.45, 0.75, 1.0)
	rim.light_energy = 1.2
	rim.rotation_degrees = Vector3(-25, 160, 0)
	root.add_child(rim)
	var cam := Camera3D.new()
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.fov = 34.0
	root.add_child(cam)
	cam.look_at_from_position(Vector3(0.3, 1.0, 3.9), Vector3(0.15, 1.1, 0), Vector3.UP)
	lob.hero.rotation.y = -0.35
	cam.current = true
	return cam
