extends RefCounted
## Zone prop kits: static meshes built in Blender (tools/art/make_*_kit.py), one glb per kit with
## every piece sharing one palette texture and up to three glTF materials (matte, ice, crystal).
## The meshes keep their own materials: batch them with MultiMesh and NO material_override.
## Feet at y = 0, modelled at the size the code-built pieces in kit_mesh.gd / mire_kit.gd used, so the
## same transforms and obstacle circles apply. `SPECS[kit][name]` lists each piece's height (m), the
## ground circle to give add_obstacle (r, 0 = none), and its triangle cap.
## Preloaded by path, no class_name.

const PATHS := {"rime": "res://assets/kits/rime/rime_kit.glb"}

## Per piece: h = height in metres, r = the ground circle to give add_obstacle (0 = walkable or Lead's
## own placement), tris = the cap the test holds it to. Props batched as MultiMesh stay far under
## the 1k-triangle budget; the single set pieces (longship, throne) use most of it.
const SPECS := {
	"rime": {
		"cliff_a": {"h": 4.0, "r": 1.1, "tris": 350}, "cliff_b": {"h": 4.0, "r": 1.1, "tris": 350},
		"cliff_c": {"h": 4.0, "r": 1.1, "tris": 350},
		"boulder_a": {"h": 1.1, "r": 0.8, "tris": 100}, "boulder_b": {"h": 1.0, "r": 0.8, "tris": 100},
		"crystal_a": {"h": 2.9, "r": 0.9, "tris": 200}, "crystal_b": {"h": 2.6, "r": 0.8, "tris": 200},
		"crystal_c": {"h": 3.2, "r": 1.1, "tris": 200}, "crystal_d": {"h": 2.3, "r": 0.8, "tris": 200},
		"ice_block": {"h": 2.84, "r": 1.0, "tris": 100}, "ice_block_broken": {"h": 1.5, "r": 1.0, "tris": 100},
		"pine_a": {"h": 3.9, "r": 0.35, "tris": 260}, "pine_b": {"h": 4.4, "r": 0.35, "tris": 260},
		"pine_c": {"h": 3.5, "r": 0.35, "tris": 260},
		"longship": {"h": 5.6, "r": 1.5, "tris": 900}, "hut": {"h": 2.9, "r": 1.5, "tris": 600},
		"sled": {"h": 0.54, "r": 0.8, "tris": 300},
		"snow_bank_a": {"h": 1.2, "r": 0.0, "tris": 100}, "snow_bank_b": {"h": 1.0, "r": 0.0, "tris": 100},
		"hole_rim": {"h": 0.3, "r": 0.0, "tris": 120},
		"ice_arch": {"h": 3.6, "r": 0.0, "tris": 300},
		"effigy": {"h": 2.85, "r": 0.8, "tris": 300},
		"throne": {"h": 6.6, "r": 3.0, "tris": 900},
	},
}

static var _cache := {}


## The piece `name` of `kit` as an ArrayMesh (cached). Null for an unknown name.
static func mesh(kit: String, name: String) -> Mesh:
	if not _cache.has(kit):
		_load(kit)
	return _cache[kit].get(name) as Mesh


static func names(kit: String) -> Array:
	if not _cache.has(kit):
		_load(kit)
	return (_cache[kit] as Dictionary).keys()


static func _load(kit: String) -> void:
	var out := {}
	var scene := load(PATHS[kit]) as PackedScene
	if scene != null:
		var root := scene.instantiate()
		var stack: Array = [root]
		while not stack.is_empty():
			var n: Node = stack.pop_back()
			stack.append_array(n.get_children())
			if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
				out[String(n.name)] = (n as MeshInstance3D).mesh
		root.free()
	_cache[kit] = out
