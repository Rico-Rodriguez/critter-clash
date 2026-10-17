class_name Cast3D
extends RefCounted

## Which licensed model plays each critter, and which clip covers each action.
## Heroes keep the meshes the owner already liked: dragon, fox, otter, owl,
## frog, cactus-hog. Minions and bosses reuse that same rigged cast, tinted.
##
## Drop a CC0 or CC-BY Sketchfab GLB on top of a family to replace it:
##   assets/models/sketchfab/ember_cute.glb  Cute Dragon (Ember only)
##   assets/models/sketchfab/ember.glb    Stylized Dragon (volcano dragons)
##   assets/models/sketchfab/juniper.glb  KAI or GIGI fox
##   assets/models/sketchfab/pebble.glb   otter, when one is licensed
##   assets/models/sketchfab/lumen.glb    owl
##   assets/models/sketchfab/pip.glb      frog
##   assets/models/sketchfab/bramble.glb  Swinecone, pinecone boar (bramble family)
##   assets/models/sketchfab/thistle.glb  Mushroom Boss
## Rim plants from a vegetation pack go in assets/models/sketchfab/nature/.


const EMBER_CUTE := "res://assets/models/sketchfab/ember_cute.glb"
## Volcano lair boss: "Drugdör The Golem Animated" by Phons (CC-BY 4.0), a
## rune-hearted rock golem, graded to basalt so the heart reads as magma.
## Nimbus (frost lair) wears the same golem repainted as glacier ice.
const CINDER_GOLEM := "res://assets/models/sketchfab/cinder_golem.glb"


## Wild critters and bosses wear their own species (Quaternius Ultimate
## Monsters, CC0), never a playable hero's mesh.
const MONSTERS := {
	"sprout": "mushnub", "beetle": "armabee", "moth": "hywirl", "boarlet": "monkroose",
	"capling": "mushnub_evolved", "spore": "spiky_blob", "glowmoth": "ghost", "puddle": "glub",
	"caplet": "mushroom_king",
	"snowpup": "bunny", "shard": "goleling", "icewisp": "ghost_skull", "yeti": "yeti2",
	"nimbus": "goleling_evolved",
	"cindling": "demon", "skink": "dino", "ashbat": "squidle", "magmash": "blue_demon",
	"cinder": "demon2",
}
## Monsters that fly (no walk cycle): they hover on Flying_Idle and dart on Fast_Flying.
const FLYERS := ["armabee", "hywirl", "ghost", "ghost_skull", "goleling", "goleling_evolved", "demon", "squidle", "glub"]
## Monsters whose rig has the short clip set (Walk, Bite_Front, HitRecieve).
const BITERS := ["mushnub", "mushnub_evolved", "spiky_blob"]


static func monster(id: String) -> String:
	return str(MONSTERS.get(id, ""))


static func model(id: String) -> String:
	if id in ["cinder", "nimbus"] and ResourceLoader.exists(CINDER_GOLEM):
		return CINDER_GOLEM
	var mon := monster(id)
	if mon != "":
		return "res://assets/models/monsters/%s.glb" % mon
	if id == "ember" and ResourceLoader.exists(EMBER_CUTE):
		return EMBER_CUTE
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
	if path == CINDER_GOLEM:
		return {"idle": "Idle", "run": "Walk", "attack": "Attack1", "hit": "Defence3", "death": ""}
	var mon := monster(id)
	if mon != "":
		var a := "CharacterArmature|"
		if mon in FLYERS:
			return {"idle": a + "Flying_Idle", "run": a + "Fast_Flying", "attack": a + "Headbutt", "hit": a + "HitReact", "death": a + "Death"}
		if mon in BITERS:
			return {"idle": a + "Idle", "run": a + "Walk", "attack": a + "Bite_Front", "hit": a + "HitRecieve", "death": a + "Death"}
		return {"idle": a + "Idle", "run": a + "Run", "attack": a + "Punch", "hit": a + "HitReact", "death": a + "Death"}
	# Names are the clips inside each Sketchfab file. The dragon has no Idle
	# or Run, and the mushroom's death clip is "Die".
	if path == EMBER_CUTE:
		return {"idle": "Take 001", "run": "Take 001", "attack": "Take 001", "hit": "", "death": "", "perch": "Take 001"}
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
	if path.ends_with("sketchfab/bramble.glb"):
		return {"idle": "Idle1", "run": "Move1 (jump)", "attack": "Attack2 (tusks)", "hit": "", "death": ""}
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
	if path == CINDER_GOLEM:
		# The blue rock hide is regraded to basalt with glowing seams
		# (assets/models/sketchfab/cinder_golem_paint.png).
		return {"roughness": 0.86, "specular": 0.3, "rim": 0.3, "rim_tint": 0.9, "backlight": Color(0.5, 0.12, 0.02), "albedo_tex": "res://assets/models/sketchfab/cinder_golem_paint.png"} if id == "cinder" else {"roughness": 0.55, "specular": 0.5, "rim": 0.35, "rim_tint": 0.4, "clearcoat": 0.25, "subsurface": 0.15, "backlight": Color(0.1, 0.35, 0.5), "albedo_tex": "res://assets/models/sketchfab/frost_golem_paint.png"}
	if monster(id) != "" and path != CINDER_GOLEM:
		# Flat toy colours: take the gloss off, add grain, rim and a little
		# subsurface so they sit in the painted world.
		return {"roughness": 0.72, "specular": 0.3, "rim": 0.45, "rim_tint": 0.6, "paint": true, "subsurface": 0.15}
	if path.ends_with("sketchfab/bramble.glb"):
		# Hand-painted pinecone hide: matte with a soft rim, no plastic sheen.
		return {"roughness": 0.78, "specular": 0.3, "rim": 0.3, "rim_tint": 0.7}
	if path == EMBER_CUTE:
		# Hand-painted scale albedo ships in the file; just take the plastic
		# sheen off and add a warm rim so it reads from the hunt camera.
		return {"roughness": 0.62, "specular": 0.32, "rim": 0.55, "rim_tint": 0.15}
	if path.ends_with("sketchfab/ember.glb"):
		# The source albedo is one flat red. tools/paint_ember.py paints a
		# multi-tone hide from it by body region (back, belly, wings, horns).
		# The packed ORM's metal channel is bogus (full metal), so roughness
		# (G) and AO (R) are bound and metal is forced off.
		# tools/bake_ember_normal.py adds hex scales to the source normal map.
		return {"roughness": 0.58, "specular": 0.4, "backlight": Color(0.9, 0.16, 0.04), "albedo_tex": "res://assets/models/sketchfab/ember_paint.png", "rough_tex": "res://assets/models/sketchfab/ember_1.png", "ao_tex": "res://assets/models/sketchfab/ember_1.png", "normal_tex": "res://assets/models/sketchfab/ember_normal_scales.png", "normal_scale": 1.8, "rim": 0.45, "rim_tint": 0.85}
	if path.ends_with("sketchfab/thistle.glb"):
		# tools/paint_thistle.py repaints the pastel toy hide in bone and
		# oxblood, with a damp, matte roughness map.
		return {"roughness": 0.8, "specular": 0.3, "rim": 0.2, "albedo_tex": "res://assets/models/sketchfab/thistle_paint.png", "rough_tex": "res://assets/models/sketchfab/thistle_rough.png", "normal_tex": "res://assets/models/sketchfab/thistle_normal_spots.png", "normal_scale": 1.6, "subsurface": 0.45, "backlight": Color(0.32, 0.1, 0.06)}
	if path.ends_with("sketchfab/juniper.glb"):
		return {"roughness": 0.7, "specular": 0.35, "rim": 0.3, "paint": true}
	# The kit critters (frog, fox, otter, hedgehog, owl) ship flat atlas
	# colours: "paint" adds a triplanar fur/skin grain and normal, rim light
	# and a little subsurface so they sit beside Ember instead of looking
	# like vinyl toys. Frogs get a wet clearcoat.
	var opts := {"roughness": 0.6, "specular": 0.45, "rim": 0.4, "rim_tint": 0.7, "paint": true, "subsurface": 0.18}
	if family(id) == "pip":
		# Damp, not lacquered: a faint clearcoat over a satin skin, and a
		# pale throat and belly (tools: assets/models/pip_paint.png) in place
		# of the atlas's near-black swatch.
		opts["clearcoat"] = 0.12
		opts["roughness"] = 0.62
		opts["specular"] = 0.35
		opts["albedo_tex"] = "res://assets/models/pip_paint.png"
		opts["rim"] = 0.22
	return opts


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
	if path == CINDER_GOLEM:
		return Color.WHITE
	if monster(id) != "":
		return Color.WHITE
	if id == "juniper" and path.ends_with("sketchfab/juniper.glb"):
		return Color(1.0, 0.90, 0.78)
	if id == "pebble":
		return Color(0.68, 0.90, 0.84)
	if id in ["ember", "juniper", "lumen", "pip", "bramble", "thistle"]:
		return Color.WHITE
	# The swinecone's hide is painted: biome tints stay a light wash
	# (frost goes pale, lava goes ashen) instead of a dye.
	if path.ends_with("sketchfab/bramble.glb"):
		match id:
			"yeti":
				return Color(0.8, 0.92, 1.12)
			"magmash":
				return Color(0.55, 0.45, 0.42)
			"capling":
				return Color(0.82, 0.86, 0.72)
		return Color(0.86, 0.8, 0.74)
	var info := Catalog.critter(id)
	if info.is_empty():
		return Color.WHITE
	return Color(str(info.get("color", "ffffff"))).lerp(Color.WHITE, 0.42)


static func nose(id: String) -> float:
	# Sketchfab rigs have no Forward marker. Mixamo and these FBX exports
	# face +Z. Returning a negative value keeps the old "nose is -Z" default.
	var path := model(id)
	if monster(id) != "" or path == CINDER_GOLEM:
		return 0.0
	# The dragon, KAI, and the mushroom all face +Z. A turntable render
	# showed KAI's back under the old "nose is -Z" default.
	if path.ends_with("sketchfab/bramble.glb") or path == EMBER_CUTE or path.ends_with("sketchfab/ember.glb") or path.ends_with("sketchfab/thistle.glb") or path.ends_with("sketchfab/juniper.glb"):
		return 0.0
	return -1.0


## Yaw added to a portrait so the face reads in 3/4.
static func portrait_turn(id: String) -> float:
	# The dragon's raised wings make a tall, narrow box; a deeper turn shows
	# its long body and fills the square card.
	if model(id).ends_with("sketchfab/ember.glb"):
		return 1.0
	return 0.55


## Clip time to freeze for a portrait. The dragon's wings are spread mid-flap.
static func portrait_time(id: String) -> float:
	if model(id).ends_with("sketchfab/ember.glb"):
		return 0.35
	return 0.2


## Medallion crop as fractions of the full-body bounds (x, y, w, h), for
## models whose head is not simply the top band (the baby dragon's horns,
## tail, and wings widen that band). Empty uses head_share.
static func head_window(id: String) -> Rect2:
	if model(id) == EMBER_CUTE:
		return Rect2(0.4, 0.1, 0.6, 0.6)
	return Rect2()


## Share of the body height that is head, for the medallion close-up.
static func head_share(id: String) -> float:
	if model(id) == EMBER_CUTE:
		return 0.6
	match family(id):
		"ember":
			return 0.3
		"thistle":
			return 0.6
		"juniper":
			return 0.42
	return 0.55

