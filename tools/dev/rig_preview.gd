extends SceneTree
## Foreign-rig foes side by side in the game's own foe shader, for a look.
## xvfb-run -a godot --path . --rendering-method gl_compatibility -s res://tools/dev/rig_preview.gd -- out.png
func _init() -> void:
	var out := "/tmp/rig_preview.png"
	for a in OS.get_cmdline_user_args():
		out = a
	var specs := [["glb:res://assets/quaternius/wyrm.glb", {"fit": 1.6}], ["glb:res://assets/sidekicks/bat.tscn", {"fit": 1.2}], ["proc:res://assets/kaykit/weapons/Skeleton_Arrow.gltf", {"fit": 1.2, "proc": {"hover": 0.5}}], ["Skeleton_Warrior", {}]]
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.fov = 30
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, -25, 0)
	root.add_child(sun)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.35, 0.37, 0.42)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.8, 0.8, 0.9)
	we.environment = env
	root.add_child(we)
	var actors := []
	for i in specs.size():
		var a := Actor.new()
		root.add_child(a)
		var w: Dictionary = {"handslot.r": "Skeleton_Axe.gltf"} if specs[i][0] == "Skeleton_Warrior" else {}
		a.build_model(specs[i][0], w, Color(0.5, 0.6, 1.0), 0.3, Color(0, 0, 0, 0), 0.8, specs[i][1])
		a.position = Vector3((i - 1.5) * 2.2, 0, 0)
		a.rotation_degrees.y = -20
		a.play("Skeletons_Idle")
		a.anim.seek(0.3, true)
		actors.append(a)
	actors[1].hit_flash()
	cam.look_at_from_position(Vector3(0, 1.4, 11), Vector3(0, 0.9, 0), Vector3.UP)
	for i in 8:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(out)
	quit()
