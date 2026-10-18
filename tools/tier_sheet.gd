extends SceneTree
## Gear tier comparison sheet: tiers 0-3 side by side, front and 3/4 views.
## xvfb-run -a godot --path . --rendering-driver vulkan -s res://tools/tier_sheet.gd -- <hero_id> <out.png> [clip@frac]
func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var id: String = args[0] if args.size() > 0 else "pebble"
	var out: String = args[1] if args.size() > 1 else "/tmp/tiers.png"
	var shot: PackedStringArray = (args[2] if args.size() > 2 else "idle@0.3").split("@")
	var W := 360
	var H := 540
	var sheet := Image.create(W * 4, H * 2, false, Image.FORMAT_RGBA8)
	for t in 4:
		var vp := SubViewport.new()
		vp.size = Vector2i(W, H)
		vp.own_world_3d = true
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		vp.msaa_3d = Viewport.MSAA_4X
		root.add_child(vp)
		var we := WorldEnvironment.new()
		var e := Environment.new()
		e.background_mode = Environment.BG_COLOR
		e.background_color = Color(0.16, 0.16, 0.18)
		e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		e.ambient_light_color = Color(0.55, 0.58, 0.68)
		e.ambient_light_energy = 0.7
		e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
		e.glow_enabled = true
		we.environment = e
		vp.add_child(we)
		var l := DirectionalLight3D.new()
		l.rotation_degrees = Vector3(-40, -35, 0)
		l.light_energy = 1.7
		vp.add_child(l)
		await process_frame
		var r: Node3D = load(Cast3D.HEROES[id]).instantiate()
		vp.add_child(r)
		Gear3D.hide_own(r, id)
		Gear3D.dress(r, id, {"weapon": t, "armor": t})
		# Normalise to ~180 units tall (rigs come in cm or m).
		var hgt := 0.0
		for mi: MeshInstance3D in r.find_children("*", "MeshInstance3D", true, false):
			if mi.skin != null:
				hgt = maxf(hgt, (mi.global_transform * mi.get_aabb()).size.y)
		if hgt > 0.0 and (hgt < 150.0 or hgt > 230.0):
			r.scale = Vector3.ONE * (180.0 / hgt)
		var ap: AnimationPlayer = r.find_children("*", "AnimationPlayer", true, false)[0]
		ap.play(shot[0])
		ap.seek(ap.get_animation(shot[0]).length * float(shot[1]), true)
		ap.pause()
		var cam := Camera3D.new()
		vp.add_child(cam)
		cam.fov = 30
		for v in 2:
			var yaw: float = [0.25, -0.75][v]
			cam.position = Vector3(sin(yaw) * 430, 160, cos(yaw) * 430)
			await process_frame
			cam.look_at(Vector3(0, 100, 0))
			for k in 3:
				await process_frame
			await RenderingServer.frame_post_draw
			var img := vp.get_texture().get_image()
			img.convert(Image.FORMAT_RGBA8)
			sheet.blit_rect(img, Rect2i(0, 0, W, H), Vector2i(W * t, H * v))
		vp.queue_free()
	sheet.save_png(out)
	quit()
