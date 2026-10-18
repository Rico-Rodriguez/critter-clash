extends SceneTree
## Bakes licensed prop GLBs (res://_src, not committed) into compact gear
## meshes: one ArrayMesh per item, in centimetres in socket space, textures
## downscaled to 512 px. Run twice: "export" (meshes + PNGs), import, "bind".
##   godot --headless --path . -s res://tools/bake_gear.gd -- export|bind
## Conventions: swords grip at the origin, blade +Y; shields centred, face +Z.

const OUT := "res://assets/models/gear/"
const ITEMS := {
	# id: [source, basis fix (euler deg), size cm along +Y, anchor ("center" or grip fraction along +Y)]
	"shield_round": ["res://_src/gear_20a4a5.glb", Vector3(0, 0, 0), 64.0, "center"],
	"shield_heater": ["res://_src/gear_2a3aba.glb", Vector3(0, 0, 0), 84.0, "center"],
	"shield_tower": ["res://_src/gear_0ae0f6.glb", Vector3(0, 0, 0), 104.0, "center"],
	"blade_oarimaar": ["res://_src/gear_d84a41.glb", Vector3(0, 0, -90), 124.0, "grip:0.08"],
	# Ancient Pauldron (Ciarán Wilson, CC-BY): rune-tier shoulder plate.
	"pauldron_ancient": ["res://_src/gear_8c5cd2.glb", Vector3(0, 0, 0), 34.0, "center"],
}


func _init() -> void:
	var mode := OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(OUT + "tex")
	var only := OS.get_cmdline_user_args()[1] if OS.get_cmdline_user_args().size() > 1 else ""
	for id in ITEMS.keys():
		if only != "" and id != only:
			continue
		if mode == "export":
			_export(id)
		else:
			_bind(id)
	quit()


func _export(id: String) -> void:
	var spec: Array = ITEMS[id]
	var r: Node3D = load(spec[0]).instantiate()
	root.add_child(r)
	var fix := Basis.from_euler(spec[1] * PI / 180.0)
	var st_list := []
	var mats := []
	var box := AABB()
	var first := true
	for m: MeshInstance3D in r.find_children("*", "MeshInstance3D", true, false):
		var xf := Transform3D(fix, Vector3.ZERO) * _global(m)
		for s in m.mesh.get_surface_count():
			var arr := m.mesh.surface_get_arrays(s)
			var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var nrm: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
			for i in v.size():
				v[i] = xf * v[i]
				if nrm.size() > i:
					nrm[i] = (xf.basis * nrm[i]).normalized()
				if first:
					box = AABB(v[i], Vector3.ZERO)
					first = false
				else:
					box = box.expand(v[i])
			arr[Mesh.ARRAY_VERTEX] = v
			arr[Mesh.ARRAY_NORMAL] = nrm
			if arr[Mesh.ARRAY_TANGENT] != null:
				var tg: PackedFloat32Array = arr[Mesh.ARRAY_TANGENT]
				for i in range(0, tg.size(), 4):
					var t3 := (xf.basis * Vector3(tg[i], tg[i + 1], tg[i + 2])).normalized()
					tg[i] = t3.x; tg[i + 1] = t3.y; tg[i + 2] = t3.z
				arr[Mesh.ARRAY_TANGENT] = tg
			st_list.append(arr)
			mats.append(m.get_active_material(s))
	var k: float = spec[2] / maxf(box.size.y, 0.0001)
	var anchor := box.get_center()
	if str(spec[3]).begins_with("grip:"):
		var f := float(str(spec[3]).split(":")[1])
		anchor = Vector3(box.get_center().x, box.position.y + box.size.y * f, box.get_center().z)
	var mesh := ArrayMesh.new()
	var info := []
	for i in st_list.size():
		var arr: Array = st_list[i]
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		for j in v.size():
			v[j] = (v[j] - anchor) * k
		arr[Mesh.ARRAY_VERTEX] = v
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		var mat: BaseMaterial3D = mats[i] as BaseMaterial3D
		var d := {}
		if mat:
			d["albedo_color"] = mat.albedo_color.to_html()
			d["metallic"] = mat.metallic
			d["roughness"] = mat.roughness
			for slot in ["albedo", "normal", "orm", "metallic", "roughness", "emission"]:
				var tex: Texture2D = null
				match slot:
					"albedo": tex = mat.albedo_texture
					"normal": tex = mat.normal_texture if mat.normal_enabled else null
					"metallic": tex = mat.metallic_texture
					"roughness": tex = mat.roughness_texture
					"emission": tex = mat.emission_texture if mat.emission_enabled else null
				if tex == null:
					continue
				var img := tex.get_image()
				if img.is_compressed():
					img.decompress()
				var size := 512 if slot == "albedo" else 256
				if img.get_width() > size:
					img.resize(size, size * img.get_height() / img.get_width(), Image.INTERPOLATE_LANCZOS)
				var file := "%s_%d_%s.png" % [id, i, slot]
				img.save_png(ProjectSettings.globalize_path(OUT + "tex/" + file))
				d[slot] = file
				if slot == "roughness":
					d["rough_ch"] = mat.roughness_texture_channel
				if slot == "metallic":
					d["metal_ch"] = mat.metallic_texture_channel
		info.append(d)
	mesh.set_meta("mats", info)
	ResourceSaver.save(mesh, OUT + id + ".res")
	print(id, " k=", k, " box=", box, " surfaces=", st_list.size())
	r.queue_free()


func _bind(id: String) -> void:
	var mesh: ArrayMesh = load(OUT + id + ".res")
	var info: Array = mesh.get_meta("mats", [])
	for i in info.size():
		var d: Dictionary = info[i]
		var mat := StandardMaterial3D.new()
		mat.resource_name = "%s_%d" % [id, i]
		mat.albedo_color = Color.html(str(d.get("albedo_color", "ffffff")))
		mat.metallic = float(d.get("metallic", 0.0))
		mat.roughness = float(d.get("roughness", 1.0))
		if d.has("albedo"):
			mat.albedo_texture = load(OUT + "tex/" + str(d["albedo"]))
		if d.has("normal"):
			mat.normal_enabled = true
			mat.normal_texture = load(OUT + "tex/" + str(d["normal"]))
		if d.has("roughness"):
			mat.roughness_texture = load(OUT + "tex/" + str(d["roughness"]))
			mat.roughness_texture_channel = int(d.get("rough_ch", 0))
		if d.has("metallic"):
			mat.metallic_texture = load(OUT + "tex/" + str(d["metallic"]))
			mat.metallic_texture_channel = int(d.get("metal_ch", 0))
		if d.has("emission"):
			mat.emission_enabled = true
			mat.emission_texture = load(OUT + "tex/" + str(d["emission"]))
		mesh.surface_set_material(i, mat)
	ResourceSaver.save(mesh, OUT + id + ".res")
	print("bound ", id, " ", info.size())


func _global(n: Node3D) -> Transform3D:
	var xf := n.transform
	var p := n.get_parent()
	while p is Node3D:
		xf = (p as Node3D).transform * xf
		p = p.get_parent()
	return xf
