extends SceneTree
## Wraps each licensed sidekick import (assets/sidekicks/<name>_src.glb) in
## <name>.tscn, scaled to 1 m tall with its feet at the origin. Skinned
## Sketchfab imports keep bind-space mesh bounds, so the size is measured on
## the posed mesh (first frame of the idle clip). Re-run after replacing a glb:
## tools/dev/godot-gpu.sh -s res://tools/art/wrap_sidekicks.gd (needs a renderer: skins)
const DIR := "res://assets/sidekicks/"


func _init() -> void:
	for f in DirAccess.get_files_at(DIR):
		if not f.ends_with("_src.glb"):
			continue
		var model: Node3D = (load(DIR + f) as PackedScene).instantiate()
		root.add_child(model)
		var ap: AnimationPlayer = model.find_child("AnimationPlayer", true, false)
		if ap and ap.get_animation_list().size() > 0:
			ap.play(ap.get_animation_list()[0])
			ap.seek(0.0, true)
		await process_frame
		await process_frame
		var box := AABB()
		var first := true
		# Skinned meshes are culled by their bind-space AABB, which can sit far
		# from the posed mesh; keep the posed bounds so sidekick_look can set them.
		var culls := {}
		for mi in model.find_children("*", "MeshInstance3D", true, false):
			var m := mi as MeshInstance3D
			var mesh: Mesh = m.bake_mesh_from_current_skeleton_pose() if m.skin else m.mesh
			if mesh == null:
				continue
			var b: AABB = m.global_transform * mesh.get_aabb()
			if m.skin:
				var local: AABB = mesh.get_aabb()
				culls[str(model.get_path_to(m))] = local.grow(local.size.length() * 0.5)
			box = b if first else box.merge(b)
			first = false
		root.remove_child(model)
		if first or box.size.y <= 0.0001:
			push_error("WRAP skipped %s: no mesh with height" % f)
			model.free()
			continue
		var k := 1.0 / box.size.y
		var wrap := Node3D.new()
		wrap.name = f.get_basename().trim_suffix("_src")
		wrap.set_meta("cull_aabbs", culls)
		# Posed bounds after wrapping (1 m tall, feet at 0); src/tests.gd checks them.
		var c := Vector3(box.get_center().x, box.position.y, box.get_center().z)
		wrap.set_meta("posed_aabb", AABB((box.position - c) * k, box.size * k))
		wrap.add_child(model)
		model.owner = wrap
		model.scale = Vector3.ONE * k
		model.position = Vector3(-box.get_center().x * k, -box.position.y * k, -box.get_center().z * k)
		var ps := PackedScene.new()
		ps.pack(wrap)
		var out := DIR + wrap.name + ".tscn"
		ResourceSaver.save(ps, out)
		print("WRAP ", out, " raw_height=", box.size.y, " k=", k)
	quit()
