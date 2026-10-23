extends SceneTree
## Contact sheet of weapon models: one row per name, one column per set.
## tools/dev/godot-gpu.sh -s res://tools/weapon_sheet.gd -- --rows=axe,maul --prefix=barb_ --out=/abs/path.png

func _init() -> void:
	var out := "/tmp/weapons.png"
	var rows := ["axe", "maul", "scythe", "twin", "halberd", "throwing"]
	var prefix := "barb_"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--rows="):
			rows.assign(a.substr(7).split(","))
		elif a.begins_with("--prefix="):
			prefix = a.substr(9)
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
	var i := 0
	for r in rows:
		for k in 5:
			var path := "res://assets/kaykit/weapons/%s%s_%d.gltf" % [prefix, r, k]
			if not ResourceLoader.exists(path):
				continue
			var p: Node3D = load(path).instantiate()
			world.add_child(p)
			p.position = Vector3(k * 2.2 - 4.4, -i * 2.9 + (rows.size() - 1) * 1.45 - 0.6, 0)
		i += 1
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.keep_aspect = Camera3D.KEEP_WIDTH
	cam.size = 11.2
	world.add_child(cam)
	cam.position = Vector3(0, 0, 10)
	for f in 8:
		await process_frame
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(out)
	print("wrote ", out, " ", img.get_size())
	quit()
