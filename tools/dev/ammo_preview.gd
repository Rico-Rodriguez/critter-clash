extends SceneTree
## The dark ammo models side by side next to the KayKit ones they replace.
## tools/dev/godot-gpu.sh -s res://tools/dev/ammo_preview.gd -- out.png
func _init() -> void:
	var out := "/tmp/ammo_preview.png"
	for a in OS.get_cmdline_user_args():
		out = a
	var W := "res://assets/kaykit/weapons/"
	# [old, new, new rotation, scale]
	var rows := [
		[W + "arrow_bow.gltf", W + "ammo_arrow.gltf", Vector3(0, 90, 0), 1.3],
		[W + "Skeleton_Arrow.gltf", W + "ammo_bolt.gltf", Vector3(0, 90, 0), 1.3],
		[W + "dagger.gltf", W + "ammo_knife.gltf", Vector3(0, 0, 0), 1.2],
		[W + "axe_1handed.gltf", W + "ammo_axe.gltf", Vector3(0, 0, 0), 1.2],
		["res://assets/kaykit/graveyard/bone_A.gltf", W + "ammo_bone.gltf", Vector3(0, 90, 0), 1.3],
		["res://assets/kaykit/dungeon/coin.gltf", W + "ammo_coin.gltf", Vector3(60, 0, 0), 2.0],
	]
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.fov = 30
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, -25, 0)
	root.add_child(sun)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.2, 0.22, 0.26)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.8, 0.8, 0.9)
	we.environment = env
	root.add_child(we)
	for i in rows.size():
		var old := KK.prop(rows[i][0])
		old.scale = Vector3.ONE * float(rows[i][3])
		old.position = Vector3(-1.6, (2.5 - i) * 1.1, 0)
		if i != 2 and i != 3 and i != 5:
			old.rotation_degrees = Vector3(0, 90, 0)
		root.add_child(old)
		var nw := KK.prop(rows[i][1])
		nw.scale = Vector3.ONE * float(rows[i][3])
		nw.rotation_degrees = rows[i][2]
		nw.position = Vector3(1.6, (2.5 - i) * 1.1, 0)
		root.add_child(nw)
	cam.look_at_from_position(Vector3(0, 0, 16), Vector3(0, 0, 0), Vector3.UP)
	for i in 8:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(out)
	quit()
