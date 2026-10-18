extends SceneTree
## Clip contact sheet for a rigged model: one row per animation, N frames per row.
## CLIPS=a,b limits the rows.
## xvfb-run -a godot --path . --rendering-driver vulkan -s res://tools/clip_sheet.gd -- <res://model.glb> <out.png> [frames] [yaw_deg]
func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var path: String = args[0]
	var out: String = args[1]
	var n: int = int(args[2]) if args.size() > 2 else 5
	var yaw: float = float(args[3]) if args.size() > 3 else 35.0
	var W := 220
	var H := 260
	var vp := SubViewport.new()
	vp.size = Vector2i(W, H)
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var we := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.16, 0.16, 0.18)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.6, 0.62, 0.7)
	e.ambient_light_energy = 0.8
	e.glow_enabled = true
	we.environment = e
	vp.add_child(we)
	var l := DirectionalLight3D.new()
	l.rotation_degrees = Vector3(-40, -35, 0)
	l.light_energy = 1.6
	vp.add_child(l)
	var model: Node3D = (load(path) as PackedScene).instantiate()
	model.rotation_degrees.y = yaw
	vp.add_child(model)
	var cam := Camera3D.new()
	vp.add_child(cam)
	var ap: AnimationPlayer = model.find_children("*", "AnimationPlayer", true, false)[0]
	var names := ap.get_animation_list()
	if OS.get_environment("CLIPS") != "":
		names = PackedStringArray(OS.get_environment("CLIPS").split(","))
	var sheet := Image.create(W * n, H * names.size(), false, Image.FORMAT_RGBA8)
	await process_frame
	# Frame on the skeleton joints (skinned mesh AABBs report bind space,
	# which lies on rigs with scaled armatures).
	var box := AABB()
	var first := true
	for sk in model.find_children("*", "Skeleton3D", true, false):
		var s3 := sk as Skeleton3D
		for b in s3.get_bone_count():
			var p := s3.global_transform * s3.get_bone_global_pose(b).origin
			if first:
				box = AABB(p, Vector3.ZERO)
				first = false
			else:
				box = box.expand(p)
	box = box.grow(box.size.length() * 0.08)
	var c := box.get_center()
	var r := box.size.length() * 0.62
	cam.fov = 50.0
	cam.position = c + Vector3(0, r * 0.25, r * 1.9)
	cam.look_at(c)
	for row in names.size():
		var a := ap.get_animation(names[row])
		print("CLIP %d %s len=%.2f" % [row, names[row], a.length])
		ap.play(names[row])
		for i in n:
			ap.seek(a.length * (float(i) + 0.5) / float(n), true)
			await process_frame
			await process_frame
			var img := vp.get_texture().get_image()
			img.convert(Image.FORMAT_RGBA8)
			sheet.blit_rect(img, Rect2i(0, 0, W, H), Vector2i(i * W, row * H))
	sheet.save_png(out)
	print("SHEET ", out)
	quit()
