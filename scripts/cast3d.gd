class_name Cast3D
extends RefCounted

## Which licensed model plays each critter, and which clip covers each action.
## Heroes keep the meshes the owner already liked: dragon, fox, otter, owl,
## frog, cactus-hog. Minions and bosses reuse that same rigged cast, tinted.


static func model(id: String) -> String:
	var file := "ember_base"
	match id:
		"ember", "cindling", "cinder":
			file = "ember_lava" if id != "ember" else "ember_base"
		"juniper", "snowpup":
			file = "juniper_base"
		"nimbus":
			file = "juniper_forest"
		"pebble", "boarlet":
			file = "pebble_base"
		"puddle":
			file = "pebble_water"
		"lumen", "moth", "ashbat":
			file = "lumen_base"
		"glowmoth":
			file = "lumen_forest"
		"icewisp":
			file = "lumen_water"
		"pip", "beetle", "spore", "shard", "skink":
			file = "pip_base"
		"caplet":
			file = "pip_water"
		"bramble", "sprout", "thistle", "capling", "yeti":
			file = "bramble_base"
		"magmash":
			file = "bramble_lava"
		_:
			file = "bramble_forest"
	return "res://assets/models/%s.glb" % file


static func clips(id: String) -> Dictionary:
	var path := model(id)
	if "ember_" in path or "lumen_" in path:
		return {"idle": "Flying_Idle" if "ember_" in path else "Idle", "run": "Fly", "attack": "Fly", "hit": "", "death": ""}
	if "juniper_" in path or "pebble_" in path:
		return {"idle": "idle", "run": "walk", "attack": "gesture", "hit": "", "death": ""}
	return {"idle": "Idle", "run": "Run", "attack": "Punch", "hit": "HitReact", "death": "Death"}


static func tint(id: String) -> Color:
	# The hero GLBs are already painted. Everyone else takes the catalog color
	# so a shared mesh still reads as that critter.
	if id in ["ember", "juniper", "pebble", "lumen", "pip", "bramble"]:
		return Color.WHITE
	var info := Catalog.critter(id)
	if info.is_empty():
		return Color.WHITE
	return Color(str(info.get("color", "ffffff"))).lerp(Color.WHITE, 0.42)
