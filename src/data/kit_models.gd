extends RefCounted
## Zone prop kits: static meshes built in Blender (tools/art/make_*_kit.py), one glb per kit with
## every piece sharing one palette texture and up to three glTF materials (matte, ice, crystal; the Mire uses the third for coals).
## The meshes keep their own materials: batch them with MultiMesh and NO material_override.
## Feet at y = 0, modelled at the size the code-built pieces they replaced were, so the
## same transforms and obstacle circles apply. `SPECS[kit][name]` lists each piece's height (m), the
## ground circle to give add_obstacle (r, 0 = none), and its triangle cap.
## Preloaded by path, no class_name.

const PATHS := {"rime": "res://assets/kits/rime/rime_kit.glb", "mire": "res://assets/kits/mire/mire_kit.glb"}

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
	"mire": {
		"plank_a": {"h": 0.23, "r": 0.0, "tris": 130}, "plank_b": {"h": 0.24, "r": 0.0, "tris": 130},
		"plank_c": {"h": 0.23, "r": 0.0, "tris": 130}, "plank_end": {"h": 0.9, "r": 0.0, "tris": 180},
		"plank_corner": {"h": 0.24, "r": 0.0, "tris": 130}, "plank_tee": {"h": 0.23, "r": 0.0, "tris": 160},
		"pile_a": {"h": 1.65, "r": 0.2, "tris": 70}, "pile_b": {"h": 1.5, "r": 0.2, "tris": 70},
		"pile_tall": {"h": 2.55, "r": 0.2, "tris": 70},
		"rail": {"h": 1.05, "r": 0.0, "tris": 60},
		"rope_bridge": {"h": 1.53, "r": 0.0, "tris": 460},
		"jetty": {"h": 1.5, "r": 0.0, "tris": 340},
		"boat_shed": {"h": 3.11, "r": 1.6, "tris": 500},
		"shack": {"h": 2.86, "r": 1.4, "tris": 540}, "shack_burnt": {"h": 2.88, "r": 1.4, "tris": 560},
		"pyre_tree": {"h": 8.56, "r": 2.0, "tris": 640},
		"forge": {"h": 6.1, "r": 2.4, "tris": 740},
		"cauldron": {"h": 3.21, "r": 0.9, "tris": 300},
		"hook_post": {"h": 3.0, "r": 0.3, "tris": 100},
		"brazier": {"h": 1.08, "r": 0.5, "tris": 100},
		"reeds_a": {"h": 1.12, "r": 0.0, "tris": 80}, "reeds_b": {"h": 1.13, "r": 0.0, "tris": 60},
		"reeds_c": {"h": 1.17, "r": 0.0, "tris": 85},
		"stone_a": {"h": 0.73, "r": 0.55, "tris": 90}, "stone_b": {"h": 0.59, "r": 0.55, "tris": 90},
		"stone_c": {"h": 0.87, "r": 0.55, "tris": 90},
		"mangrove_a": {"h": 4.28, "r": 1.1, "tris": 500}, "mangrove_b": {"h": 4.39, "r": 1.1, "tris": 450},
		"mangrove_c": {"h": 3.5, "r": 1.1, "tris": 540},
		"stump_a": {"h": 1.08, "r": 0.6, "tris": 70}, "stump_b": {"h": 0.68, "r": 0.5, "tris": 70},
		"wrecked_boat": {"h": 3.75, "r": 1.5, "tris": 340},
		"skull_totem": {"h": 2.96, "r": 0.5, "tris": 250},
	},
}

static var _cache := {}


## The piece `name` of `kit` as an ArrayMesh (cached). Null for an unknown name.
static func mesh(kit: String, name: String) -> Mesh:
	if not _cache.has(kit):
		_load(kit)
	return _cache[kit].get(name) as Mesh


## The kit's matte material, burnt: darker with an ember glow, to pass as the `burnt` override of
## Plank.setup so a burning boardwalk cell still reads as the same wood (the texture shows through).
static func charred(kit: String) -> Material:
	var src := mesh(kit, "plank_a" if kit == "mire" else "")
	if src == null or src.get_surface_count() == 0:
		return null
	var m := src.surface_get_material(0).duplicate() as StandardMaterial3D
	m.albedo_color = Color(0.46, 0.4, 0.4)
	m.emission_enabled = true
	m.emission = Color(1.0, 0.35, 0.06)
	m.emission_energy_multiplier = 0.55
	m.roughness = 0.95
	return m


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
