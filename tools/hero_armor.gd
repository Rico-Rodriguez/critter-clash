extends SceneTree
## The Barbarian in each set's helm and pauldrons, front and three-quarter:
## how the rigid armor props sit on the rig. Builds the props straight from
## assets/kaykit/gear, so it needs no save.
## tools/dev/godot-gpu.sh -s res://tools/hero_armor.gd -- --out=/abs/path.png [--t=0.3]

func _init() -> void:
	var out := "/tmp/armor.png"
	var t := 0.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--t="):
			t = float(a.substr(4))
	var world := Node3D.new()
	root.add_child(world)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.09, 0.09, 0.11)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.6, 0.62, 0.7)
	e.ambient_light_energy = 0.8
	env.environment = e
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.light_energy = 1.3
	sun.rotation_degrees = Vector3(-35, -25, 0)
	world.add_child(sun)
	for row in 2:
		for k in 5:
			var ch := KK.character("Barbarian")
			world.add_child(ch)
			ch.position = Vector3(k * 2.0 - 4.0, 0, row * -2.8)
			ch.rotation_degrees.y = 0.0 if row == 0 else 40.0
			var skel: Skeleton3D = ch.find_child("Skeleton3D", true, false)
			var hat := skel.get_node_or_null("Barbarian_BearHat") as MeshInstance3D
			if hat:
				hat.visible = false
			for spec in [["barb_helm_%d.gltf" % k, "head"], ["barb_pauldron_%d.gltf" % k, "upperarm.l"], ["barb_pauldron_%d.gltf" % k, "upperarm.r"]]:
				if k == 0 and spec[1] == "upperarm.r":
					continue
				var att := BoneAttachment3D.new()
				att.bone_name = spec[1]
				skel.add_child(att)
				att.add_child(KK.prop("res://assets/kaykit/gear/" + str(spec[0])))
			var ap := KK.anim_player(ch)
			ap.play("Melee_2H_Attack_Chop" if t > 0.0 else "Idle_A")
			ap.seek(ap.current_animation_length * t, true)
			ap.pause()
	var cam := Camera3D.new()
	cam.fov = 34
	world.add_child(cam)
	cam.look_at_from_position(Vector3(0, 3.6, 8.0), Vector3(0, 1.0, -1.4))
	for f in 10:
		await process_frame
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(out)
	print("wrote ", out, " ", img.get_size())
	quit()
