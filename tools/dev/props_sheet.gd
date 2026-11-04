extends SceneTree
## Contact sheet of the plate props, for review: tools/dev/godot-gpu.sh -s res://tools/dev/props_sheet.gd -- --out=/abs/p.png

const NAMES := ["coffin", "coffin_decorated", "skull", "skull_candle", "lantern_standing", "lantern_hanging", "post_lantern", "post_skull", "chest", "chest_gold", "coin", "coin_stack_small", "coin_stack_medium", "coin_stack_large"]

func _init() -> void:
	var out := "/tmp/props.png"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	var vp := SubViewport.new()
	vp.size = Vector2i(1600, 900)
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.05, 0.055, 0.08)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.5, 0.55, 0.7)
	e.ambient_light_energy = 0.7
	e.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.environment = e
	vp.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.light_energy = 1.1
	sun.rotation_degrees = Vector3(-50, -30, 0)
	vp.add_child(sun)
	var warm := OmniLight3D.new()
	warm.light_color = Color(1, 0.6, 0.3)
	warm.omni_range = 40
	warm.light_energy = 2.0
	warm.position = Vector3(0, 6, 8)
	vp.add_child(warm)
	var x := 0.0
	var per_row := 7
	for i in NAMES.size():
		var p: Node3D = (load("res://assets/props/%s.gltf" % NAMES[i]) as PackedScene).instantiate()
		var col := i % per_row
		var row := i / per_row
		p.position = Vector3(col * 3.4 - 10.2, -row * 4.2 + 1.5, 0)
		p.rotation.y = -0.6
		if NAMES[i].begins_with("post"):
			p.scale = Vector3.ONE * 0.45
			p.position.y -= 0.0
		vp.add_child(p)
	var cam := Camera3D.new()
	cam.fov = 38
	vp.add_child(cam)
	cam.look_at_from_position(Vector3(0, 1.5, 27), Vector3(0, -0.8, 0))
	await process_frame
	await process_frame
	await process_frame
	vp.get_texture().get_image().save_png(out)
	quit()
