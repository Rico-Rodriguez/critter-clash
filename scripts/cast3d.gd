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
	# Names are the clips inside each Sketchfab file. The dragon has no Idle
	# or Run, and the mushroom's death clip is "Die".
	if path.ends_with("sketchfab/ember.glb"):
		return {
			"idle": "Wing flaps",
			"run": "Wing flaps",
			"attack": "head turn_wing flaps",
			"hit": "head turn",
			"death": "",
			# Pedestal pose: the head-turn clip.
			"perch": "head turn",
		}
	if path.ends_with("sketchfab/juniper.glb"):
		return {"idle": "Idle", "run": "Run", "attack": "Punch", "hit": "", "death": ""}
	if path.ends_with("sketchfab/thistle.glb"):
		return {"idle": "Idle", "run": "Walk", "attack": "Attack", "hit": "", "death": "Die"}
	if "/sketchfab/" in path:
		return {"idle": "Idle", "run": "Run", "attack": "Attack", "hit": "Hit", "death": "Death"}
	if "ember_" in path or "lumen_" in path:
		return {"idle": "Flying_Idle" if "ember_" in path else "Idle", "run": "Fly", "attack": "Fly", "hit": "", "death": ""}
	if "juniper_" in path or "pebble_" in path:
		return {"idle": "idle", "run": "walk", "attack": "gesture", "hit": "", "death": ""}
	return {"idle": "Idle", "run": "Run", "attack": "Punch", "hit": "HitReact", "death": "Death"}


## Material fixes for licensed meshes whose PBR maps import badly.
## Empty means "leave the file's materials alone".
static func pbr(id: String) -> Dictionary:
	var path := model(id)
	if path.ends_with("sketchfab/ember.glb"):
		# The source base color is flat red. tools/paint_ember.py bakes AO,
		# cavities and scales into ember_paint.png. The packed ORM reads as
		# full metal, so only the normal map stays live.
		return {"roughness": 0.58, "specular": 0.5, "drop_ao": true, "albedo_tex": "res://assets/models/sketchfab/ember_paint.png", "rim": 0.18}
	if path.ends_with("sketchfab/thistle.glb"):
		return {"roughness": 0.68, "specular": 0.4, "rim": 0.25}
	if path.ends_with("sketchfab/juniper.glb"):
		return {"roughness": 0.7, "specular": 0.35, "rim": 0.3}
	return {"roughness": 0.72, "specular": 0.4}


## Extra scale for models whose bounds overstate what you see. The dragon's
## rest pose spreads its wings flat, but it flies with them raised, so it
## came out about half the height of the ring under it.
static func size_boost(id: String) -> float:
	if model(id).ends_with("sketchfab/ember.glb"):
		return 1.6
	return 1.0


static func tint(id: String) -> Color:
	# Multiply the painted texture. Heroes stay recognizable: Ember orange-red,
	# Juniper russet, Pebble a teal-brown otter. Shared meshes still take the
	# catalog color.
	var path := model(id)
	if id == "juniper" and path.ends_with("sketchfab/juniper.glb"):
		return Color(1.0, 0.90, 0.78)
	if id == "pebble":
		return Color(0.68, 0.90, 0.84)
	if id in ["ember", "juniper", "lumen", "pip", "bramble", "thistle"]:
		return Color.WHITE
	var info := Catalog.critter(id)
	if info.is_empty():
		return Color.WHITE
	return Color(str(info.get("color", "ffffff"))).lerp(Color.WHITE, 0.42)


static func nose(id: String) -> float:
	# Sketchfab rigs have no Forward marker. Mixamo and these FBX exports
	# face +Z. Returning a negative value keeps the old "nose is -Z" default.
	var path := model(id)
	# The dragon, KAI, and the mushroom all face +Z. A turntable render
	# showed KAI's back under the old "nose is -Z" default.
	if path.ends_with("sketchfab/ember.glb") or path.ends_with("sketchfab/thistle.glb") or path.ends_with("sketchfab/juniper.glb"):
		return 0.0
	return -1.0


## Yaw added to a portrait so the face reads in 3/4.
static func portrait_turn(id: String) -> float:
	return 0.55


## Clip time to freeze for a portrait. The dragon's wings are spread mid-flap.
static func portrait_time(id: String) -> float:
	if model(id).ends_with("sketchfab/ember.glb"):
		return 0.35
	return 0.2


## Share of the body height that is head, for the medallion close-up.
static func head_share(id: String) -> float:
	match family(id):
		"ember":
			return 0.3
		"thistle":
			return 0.6
		"juniper":
			return 0.42
	return 0.55

