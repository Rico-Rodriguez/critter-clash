extends SceneTree
## Boss look check: the dressed boss (BossLook) beside a hero-height marker,
## dark ground, one clip frame per column.
##   xvfb-run -a godot --path . --rendering-driver vulkan -s res://tools/boss_preview.gd -- <boss_id> <out.png> [clip@t,...]
func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var id: String = args[0]
	var out: String = args[1]
	var shots: PackedStringArray = (args[2] if args.size() > 2 else "idle@0.5,attack@1.4,hit@0.3,death@0.79").split(",")
	var W := 400
	var H := 560
	var sheet := Image.create(W * shots.size(), H, false, Image.FORMAT_RGBA8)
	var vp := SubViewport.new()
	vp.size = Vector2i(W, H)
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.msaa_3d = Viewport.MSAA_4X
	root.add_child(vp)
	var we := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.07, 0.07, 0.08)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.5, 0.52, 0.6)
	e.ambient_light_energy = 0.6
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.glow_enabled = true
	we.environment = e
	vp.add_child(we)
	var l := DirectionalLight3D.new()
	l.rotation_degrees = Vector3(-50, -30, 0)
	l.light_energy = 1.3
	vp.add_child(l)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(60, 60)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.18, 0.17, 0.15)
	ground.material_override = gm
	vp.add_child(ground)
	var hero := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.height = 3.6 * 1.18
	cap.radius = 0.6
	hero.mesh = cap
	hero.position = Vector3(-7.0, cap.height * 0.5, 2.0)
	vp.add_child(hero)
	var meters := 14.5
	var body := Node3D.new()
	body.set_meta("meters", meters)
	vp.add_child(body)
	var model: Node3D = (load(Cast3D.model(id)) as PackedScene).instantiate()
	body.add_child(model)
	var sk: Skeleton3D = model.find_children("*", "Skeleton3D", true, false)[0]
	await process_frame
	var lo := 1e9
	var hi := -1e9
	for b in sk.get_bone_count():
		var y := (sk.global_transform * sk.get_bone_global_pose(b).origin).y
		lo = minf(lo, y)
		hi = maxf(hi, y)
	var f := meters / maxf(hi - lo, 0.001)
	model.scale *= f
	model.position.y -= lo * f
	BossLook.dress(model, id)
	body.rotation.y = 0.5
	var cam := Camera3D.new()
	cam.fov = 40
	vp.add_child(cam)
	cam.position = Vector3(-2, meters * 1.0, meters * 2.1)
	cam.look_at(Vector3(-2, meters * 0.42, 0))
	var ap: AnimationPlayer = model.find_children("*", "AnimationPlayer", true, false)[0]
	var clips := Cast3D.clips(id)
	for i in shots.size():
		var parts := shots[i].split("@")
		var clip := str(clips.get(parts[0], parts[0]))
		ap.play(clip)
		ap.seek(minf(float(parts[1]), ap.current_animation_length), true)
		ap.pause()
		for k in 6:
			await process_frame
		var img := vp.get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		sheet.blit_rect(img, Rect2i(0, 0, W, H), Vector2i(i * W, 0))
	sheet.save_png(out)
	print("PREVIEW ", out)
	quit()
