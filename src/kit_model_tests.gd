extends RefCounted
## The zone prop kits (assets/kits, src/data/kit_models.gd): every piece of a kit loads, stays inside its
## triangle cap and the 1k-per-prop budget, stands on y = 0 at the height its spec says, and the whole
## kit shares at most three materials on one small texture, with no dependence on vertex colours,
## so a piece batches into one MultiMesh with no material_override.

const KitModels := preload("res://src/data/kit_models.gd")
const MAX_PROP_TRIS := 1000
const MAX_KIT_TRIS := {"rime": 6000, "mire": 8000}
const MAX_TEX := 1024


static func run(ok: Callable) -> void:
	for kit: String in KitModels.SPECS:
		var specs: Dictionary = KitModels.SPECS[kit]
		var names: Array = KitModels.names(kit)
		names.sort()
		var want: Array = specs.keys()
		want.sort()
		ok.call("kit %s: the glb holds exactly the specced pieces %s" % [kit, names if names != want else ""], names == want)
		var total := 0
		var mats := {}
		var texs := {}
		for n: String in want:
			var sp: Dictionary = specs[n]
			var m: Mesh = KitModels.mesh(kit, n)
			var tag := "kit %s/%s" % [kit, n]
			ok.call("%s: loads" % tag, m != null)
			if m == null:
				continue
			var tris := 0
			var colours := false
			for s in m.get_surface_count():
				var arr := m.surface_get_arrays(s)
				tris += (arr[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
				var mat := m.surface_get_material(s) as BaseMaterial3D
				colours = colours or mat == null or mat.vertex_color_use_as_albedo
				if mat != null:
					mats[mat] = true
					if mat.albedo_texture != null:
						texs[mat.albedo_texture] = true
			total += tris
			ok.call("%s: %d tris, cap %d and under %d" % [tag, tris, sp["tris"], MAX_PROP_TRIS], tris > 8 and tris <= int(sp["tris"]) and tris <= MAX_PROP_TRIS)
			ok.call("%s: at most two surfaces, textured and not vertex-coloured" % tag, m.get_surface_count() <= 2 and not colours)
			var b := m.get_aabb()
			ok.call("%s: feet on y = 0 (%.2f), %.2f m tall against %.2f" % [tag, b.position.y, b.size.y, sp["h"]], absf(b.position.y) < 0.25 and absf(b.size.y - float(sp["h"])) < 0.3)
			ok.call("%s: obstacle circle %.1f sits inside its footprint" % [tag, sp["r"]], float(sp["r"]) <= maxf(b.size.x, b.size.z) * 0.5 + 0.01)
		ok.call("kit %s: %d tris in all, at most %d" % [kit, total, MAX_KIT_TRIS[kit]], total <= int(MAX_KIT_TRIS[kit]))
		ok.call("kit %s: %d materials shared by every piece, at most 3" % [kit, mats.size()], mats.size() >= 1 and mats.size() <= 3)
		var small := texs.size() == 1
		for t: Texture2D in texs:
			small = small and t.get_width() <= MAX_TEX and t.get_height() <= MAX_TEX
		ok.call("kit %s: one albedo texture, %d px at most" % [kit, MAX_TEX], small)
	var burnt := KitModels.charred("mire") as StandardMaterial3D
	ok.call("kit mire: the charred override keeps the palette texture and glows", burnt != null and burnt.albedo_texture != null and burnt.emission_enabled)
