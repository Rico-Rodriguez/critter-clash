class_name Cast3D
extends RefCounted

## Which licensed model plays each critter, and which clip covers each action.
## Heroes keep the meshes the owner already liked: dragon, fox, otter, owl,
## frog, cactus-hog. Minions and bosses reuse that same rigged cast, tinted.
##
## Drop a CC0 or CC-BY Sketchfab GLB on top of a family to replace it:
##   assets/models/sketchfab/ember.glb    Stylized Dragon
##   assets/models/sketchfab/juniper.glb  KAI or GIGI fox
##   assets/models/sketchfab/pebble.glb   otter, when one is licensed
##   assets/models/sketchfab/lumen.glb    owl
##   assets/models/sketchfab/pip.glb      frog
##   assets/models/sketchfab/bramble.glb  hedgehog
##   assets/models/sketchfab/thistle.glb  Mushroom Boss
## Rim plants from a vegetation pack go in assets/models/sketchfab/nature/.


static func model(id: String) -> String:
	var over := "res://assets/models/sketchfab/%s.glb" % family(id)
	if ResourceLoader.exists(over):
		return over
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
		"thistle":
			file = "thistle_boss"
		"bramble", "sprout", "capling", "yeti":
			file = "bramble_base"
		"magmash":
			file = "bramble_lava"
		_:
			file = "bramble_forest"
	if file == "thistle_boss":
		return "res://assets/models/thistle_boss.gltf"
	return "res://assets/models/%s.glb" % file


static func family(id: String) -> String:
	match id:
		"ember", "cindling", "cinder":
			return "ember"
		"juniper", "snowpup", "nimbus":
			return "juniper"
		"pebble", "boarlet", "puddle":
			return "pebble"
		"lumen", "moth", "ashbat", "glowmoth", "icewisp":
			return "lumen"
		"pip", "beetle", "spore", "shard", "skink", "caplet":
			return "pip"
		"thistle":
			return "thistle"
		_:
			return "bramble"


static func clips(id: String) -> Dictionary:
	var path := model(id)
	if "/sketchfab/" in path:
		return {"idle": "Idle", "run": "Run", "attack": "Attack", "hit": "Hit", "death": "Death"}
	if "ember_" in path or "lumen_" in path:
		return {"idle": "Flying_Idle" if "ember_" in path else "Idle", "run": "Fly", "attack": "Fly", "hit": "", "death": ""}
	if "juniper_" in path or "pebble_" in path:
		return {"idle": "idle", "run": "walk", "attack": "gesture", "hit": "", "death": ""}
	return {"idle": "Idle", "run": "Run", "attack": "Punch", "hit": "HitReact", "death": "Death"}


static func tint(id: String) -> Color:
	# The hero GLBs are already painted. Everyone else takes the catalog color
	# so a shared mesh still reads as that critter.
	if id in ["ember", "juniper", "pebble", "lumen", "pip", "bramble", "thistle"]:
		return Color.WHITE
	var info := Catalog.critter(id)
	if info.is_empty():
		return Color.WHITE
	return Color(str(info.get("color", "ffffff"))).lerp(Color.WHITE, 0.42)
