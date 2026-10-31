extends SceneTree
## Prints GEN.REGION_COLOR as read off the models: each species' average
## albedo (sRGB hex) over each of its GRAFT regions, sampled at the region's
## vertices. Paste the output into src/data/pet_gen.gd after changing a pet.
## Run: tools/dev/godot.sh -s res://tools/dev/region_colours.gd

const GEN := preload("res://src/data/pet_gen.gd")
const PG := preload("res://src/core/pet_graft.gd")


func _init() -> void:
	print("const REGION_COLOR := {")
	for sp: String in GEN.GRAFT:
		var model := PG._instance(sp)
		if model == null:
			continue
		var cols := []
		for slot: String in GEN.PART_SLOTS:
			if (GEN.GRAFT[sp] as Dictionary).has(slot):
				cols.append('"%s": "%s"' % [slot, _average(model, GEN.GRAFT[sp][slot]).to_html(false)])
		model.free()
		print('\t"%s": {%s},' % [sp, ", ".join(cols)])
	print("}")
	quit()


func _average(model: Node3D, spec: Dictionary) -> Color:
	# The region's main colour: the commonest colour by surface area (an
	# average would let eyes, teeth and horns drag it off).
	var bins := {}
	var images := {}
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var mat := mi.get_active_material(s) as BaseMaterial3D
			if mat == null:
				continue
			var arrays := mi.mesh.surface_get_arrays(s)
			var vd := PG._vertex_data(model, mi, arrays, spec)
			var sel: PackedByteArray = vd["sel"]
			var pos: PackedVector3Array = vd["pos"]
			var uvs: Variant = arrays[Mesh.ARRAY_TEX_UV]
			var idx := PG._indices(arrays, sel.size())
			var img: Image = null
			if mat.albedo_texture != null:
				var key := mat.albedo_texture.get_instance_id()
				if not images.has(key):
					var im := mat.albedo_texture.get_image()
					if im != null and im.is_compressed():
						im.decompress()
					images[key] = im
				img = images[key]
			for t in idx.size() / 3:
				var a := idx[3 * t]
				var b := idx[3 * t + 1]
				var c := idx[3 * t + 2]
				if sel[a] + sel[b] + sel[c] < 2:
					continue
				var area := (pos[b] - pos[a]).cross(pos[c] - pos[a]).length()
				var col := mat.albedo_color
				if img != null and uvs != null:
					var uv: Vector2 = ((uvs as PackedVector2Array)[a] + (uvs as PackedVector2Array)[b] + (uvs as PackedVector2Array)[c]) / 3.0
					col *= img.get_pixel(clampi(int(fposmod(uv.x, 1.0) * img.get_width()), 0, img.get_width() - 1), clampi(int(fposmod(uv.y, 1.0) * img.get_height()), 0, img.get_height() - 1))
				var k := "%d,%d,%d" % [int(col.r * 8.0), int(col.g * 8.0), int(col.b * 8.0)]
				var bn: Array = bins.get(k, [0.0, Vector3.ZERO])
				bn[0] += area
				bn[1] += Vector3(col.r, col.g, col.b) * area
				bins[k] = bn
	var best: Array = [0.0, Vector3.ZERO]
	for k: String in bins:
		if float(bins[k][0]) > float(best[0]):
			best = bins[k]
	if float(best[0]) <= 0.0:
		return Color.BLACK
	var v: Vector3 = best[1] / float(best[0])
	return Color(v.x, v.y, v.z)
