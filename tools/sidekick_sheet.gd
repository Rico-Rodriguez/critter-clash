extends SceneTree
## Sidekick review sheet: every companion (plus evolved forms) in a 3x4 grid
## under bright, clean showcase lighting, and a stats line per model
## (triangles, surfaces, largest texture). Run through a render-capable Godot:
## godot-gpu.sh --resolution 1179x2556 -s res://tools/sidekick_sheet.gd -- --out=/abs/sheet.png [--clip=idle|move|attack]

const SDB := preload("res://src/data/sidekick_db.gd")
const Look := preload("res://src/core/sidekick_look.gd")


func _init() -> void:
	var out := "/tmp/sidekicks.png"
	var clip := "idle"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--clip="):
			clip = a.substr(7)
	var world := Node3D.new()
	root.add_child(world)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.20, 0.22, 0.26)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.85, 0.88, 0.95)
	e.ambient_light_energy = 0.55
	e.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.environment = e
	world.add_child(env)
	var key := DirectionalLight3D.new()
	key.light_energy = 1.6
	key.shadow_enabled = true
	key.rotation_degrees = Vector3(-45, -30, 0)
	world.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.light_energy = 0.8
	rim.rotation_degrees = Vector3(-20, 160, 0)
	world.add_child(rim)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(60, 60)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.32, 0.33, 0.33)
	ground.material_override = gm
	world.add_child(ground)
	var cast: Array = []
	for id: String in SDB.ORDER:
		cast.append([id, false])
		if SDB.ROSTER[id].has("evolved_model"):
			cast.append([id, true])
	var cam := Camera3D.new()
	cam.fov = 30
	world.add_child(cam)
	for c in cast:
		var look: Dictionary = Look.build(c[0], c[1])
		var n: Node3D = look["root"]
		world.add_child(n)
		n.rotation_degrees.y = 30.0
		Look.play(look, clip)
		var label := str(c[0]) + ("_evolved" if c[1] else "")
		_stats(label, n)
		await process_frame
		var h := _height(n)
		cam.look_at_from_position(Vector3(0, h * 0.75, h * 2.6 + 0.6), Vector3(0, h * 0.45, 0))
		for f in 30:
			await process_frame
		var img := root.get_viewport().get_texture().get_image()
		img.save_png(out.replace(".png", "_%s.png" % label))
		print("wrote ", label)
		n.queue_free()
		await process_frame
	quit()


func _stats(label: String, n: Node) -> void:
	var tris := 0
	var surf := 0
	var tex := 0
	var mats := {}
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m: Mesh = (mi as MeshInstance3D).mesh
		if m == null:
			continue
		for s in m.get_surface_count():
			surf += 1
			var arr := m.surface_get_arrays(s)
			var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
			var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			tris += idx.size() / 3 if idx.size() > 0 else v.size() / 3
			var mat := (mi as MeshInstance3D).get_active_material(s)
			if mat:
				mats[mat.get_instance_id()] = true
			if mat is BaseMaterial3D and (mat as BaseMaterial3D).albedo_texture:
				var t: Texture2D = (mat as BaseMaterial3D).albedo_texture
				tex = maxi(tex, maxi(t.get_width(), t.get_height()))
	print("SIDEKICK %s tris=%d surfaces=%d materials=%d tex=%d" % [label, tris, surf, mats.size(), tex])


func _height(n: Node3D) -> float:
	var top := 0.3
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var mesh: Mesh = m.bake_mesh_from_current_skeleton_pose() if m.skin else m.mesh
		if mesh:
			var b: AABB = m.global_transform * mesh.get_aabb()
			top = maxf(top, maxf(b.end.y, maxf(b.size.x, b.size.z) * 0.8))
	return top
