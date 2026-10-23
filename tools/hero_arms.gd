extends SceneTree
## A hero holding each weapon family, frozen mid-swing: how the models sit in
## the hand. tools/dev/godot-gpu.sh -s res://tools/hero_arms.gd -- --hero=barbarian --mat=3 --t=0.5 --out=/abs/path.png
## --t is how far into the family's first swing clip (0 = the idle pose).

func _init() -> void:
	var out := "/tmp/arms.png"
	var hero := "barbarian"
	var mat := 3
	var t := 0.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--hero="):
			hero = a.substr(7)
		elif a.begins_with("--mat="):
			mat = int(a.substr(6))
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
	var fams: Array = DB.HERO_FAMILIES[hero]
	var i := 0
	for fam: String in fams:
		var lk := GearDB.family_look(fam, mat)
		var ch := KK.character(DB.HEROES[hero]["model"])
		world.add_child(ch)
		ch.position = Vector3((i % 3) * 2.2 - 2.2, 0, (i / 3) * -2.6)
		var skel: Skeleton3D = ch.find_child("Skeleton3D", true, false)
		var hands := ["handslot.r", "handslot.l"] if bool(DB.FAMILIES[fam].get("dual", false)) else ["handslot.r"]
		for bone: String in hands:
			var att := BoneAttachment3D.new()
			att.bone_name = bone
			skel.add_child(att)
			var p := KK.prop(KK.WEAPON_DIR + str(lk["model"]))
			p.scale = Vector3.ONE * float(lk["scale"])
			att.add_child(p)
		var ap := KK.anim_player(ch)
		var clip: String = DB.FAMILIES[fam]["clips"][0] if t > 0.0 else str(DB.HEROES[hero]["anim"]["idle"])
		ap.play(clip)
		ap.seek(ap.current_animation_length * t if t > 0.0 else 0.0, true)
		ap.pause()
		i += 1
	var cam := Camera3D.new()
	cam.fov = 38
	world.add_child(cam)
	cam.look_at_from_position(Vector3(0, 4.2, 6.5), Vector3(0, 0.9, -1.3))
	for f in 10:
		await process_frame
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(out)
	print("wrote ", out, " ", img.get_size())
	quit()
