extends SceneTree
## Fidelity check: the hero with its ORIGINAL imported materials (no Gear3D)
## vs legacy tint-shader T2 vs clean bare / iron / steel / rune, same camera and light.
## xvfb-run -a godot --path . --rendering-driver vulkan -s res://tools/orig_vs_gear.gd -- <hero> <out.png>
func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var id: String = args[0] if args.size() > 0 else "pebble"
	var out: String = args[1] if args.size() > 1 else "/tmp/ovg.png"
	# Third arg "slots": bare, then each of the 8 slots alone at steel (T2).
	var slots_mode := args.size() > 2 and args[2] == "slots"
	var ncol := 9 if slots_mode else 6
	var W := 400 if not slots_mode else 340
	var H := 720
	var sheet := Image.create(W * ncol, H, false, Image.FORMAT_RGBA8)
	for col in ncol:
		var vp := SubViewport.new()
		vp.size = Vector2i(W, H)
		vp.own_world_3d = true
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		vp.msaa_3d = Viewport.MSAA_4X
		root.add_child(vp)
		var we := WorldEnvironment.new()
		var e := Environment.new()
		e.background_mode = Environment.BG_COLOR
		e.background_color = Color(0.13, 0.13, 0.14)
		e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		e.ambient_light_color = Color(0.6, 0.62, 0.7)
		e.ambient_light_energy = 0.55
		e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
		we.environment = e
		vp.add_child(we)
		var key := DirectionalLight3D.new()
		key.rotation_degrees = Vector3(-35, -30, 0)
		key.light_energy = 2.2
		vp.add_child(key)
		var rim := DirectionalLight3D.new()
		rim.rotation_degrees = Vector3(-15, 160, 0)
		rim.light_energy = 2.4
		rim.light_color = Color("cfe0ff")
		vp.add_child(rim)
		await process_frame
		var r: Node3D = load(Cast3D.HEROES[id]).instantiate()
		vp.add_child(r)
		# 0 original import | 1 legacy tint shader T2 | 2..5 clean bare/iron/steel/rune
		Gear3D.CLEAN = slots_mode or col != 1
		if slots_mode:
			var tt := {}
			for sl in Gear3D.SLOTS:
				tt[sl] = 0
			if col > 0:
				tt[Gear3D.SLOTS[col - 1]] = 2
			Gear3D.hide_own(r, id)
			Gear3D.dress(r, id, tt)
		elif col == 1:
			Gear3D.hide_own(r, id)
			Gear3D.dress(r, id, {"weapon": 2, "armor": 2})
		elif col >= 2:
			Gear3D.hide_own(r, id)
			Gear3D.dress(r, id, {"weapon": col - 2, "armor": col - 2})
		for ap: AnimationPlayer in r.find_children("*", "AnimationPlayer", true, false):
			for nm in ap.get_animation_list():
				if "idle" in nm.to_lower():
					ap.play(nm)
					ap.seek(ap.get_animation(nm).length * 0.3, true)
					ap.pause()
					break
		var sk0: Skeleton3D = r.find_children("*", "Skeleton3D", true, false)[0]
		var lo := 1e9
		var hi := -1e9
		for b in sk0.get_bone_count():
			var y := (sk0.global_transform * sk0.get_bone_global_pose(b).origin).y
			lo = minf(lo, y)
			hi = maxf(hi, y)
		var hgt := (hi - lo) * 1.08
		r.scale = Vector3.ONE * (180.0 / maxf(hgt, 0.001))
		r.position.y = -lo * r.scale.y
		var cam := Camera3D.new()
		vp.add_child(cam)
		cam.fov = 30
		# Heroes-screen angle (hero turned ~0.45 rad to camera) so the shield
		# and blade read face-on rather than edge-on.
		var ang := float(OS.get_environment("OVG_ANG")) if OS.get_environment("OVG_ANG") != "" else -0.45
		cam.position = Vector3(sin(ang) * 420, 140, cos(ang) * 420)
		await process_frame
		cam.look_at(Vector3(0, 95, 0))
		for k in 4:
			await process_frame
		await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		sheet.blit_rect(img, Rect2i(0, 0, W, H), Vector2i(W * col, 0))
		vp.queue_free()
	sheet.save_png(out)
	quit()
