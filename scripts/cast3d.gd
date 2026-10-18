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

## Grimdark Knights (2026-10-18): humanoid heroes on the DJMaesen knight rig
## (CC-BY), clips retargeted from KayKit (CC0) by tools/retarget.gd, gear
## tiers from Gear3D. The id stays for saves; the name is in Catalog.
const HEROES := {
	"pebble": "res://assets/models/heroes/paladin/paladin.tscn",
	"bramble": "res://assets/models/heroes/boneknight/boneknight.tscn",
	"lumen": "res://assets/models/heroes/ghoul/ghoul.tscn",
}
const HERO_CLIPS := {"idle": "idle", "walk": "walk", "run": "run", "attack": "attack", "hit": "hit", "death": "death", "perch": "idle", "cast": "cast", "block": "block", "bash": "bash", "dodge": "dodge"}


static func knight(id: String) -> bool:
	return HEROES.has(id)


## Wild critters and bosses wear their own species (Quaternius Ultimate
## Monsters, CC0), never a playable hero's mesh.
const MONSTERS := {
	"beetle": "armabee", "capling": "mushnub_evolved",
	"spore": "spiky_blob", "puddle": "glub", "yeti": "yeti2", "cindling": "demon",
}
## Monsters that fly (no walk cycle): they hover on Flying_Idle and dart on Fast_Flying.
const FLYERS := ["armabee", "hywirl", "ghost", "ghost_skull", "goleling", "goleling_evolved", "demon", "squidle", "glub"]
## Monsters whose rig has the short clip set (Walk, Bite_Front, HitRecieve).
const BITERS := ["mushnub", "mushnub_evolved", "spiky_blob"]


## Higher-detail, hand-painted PBR creatures from Sketchfab (CC-BY 4.0,
## see CREDITS.md). One rig serves a few species, graded per biome.
const SKETCH_MON := {
	"snowpup": "boar", "magmash": "boar",
	"moth": "batlord", "glowmoth": "batlord", "ashbat": "batlord", "icewisp": "batlord",
	"skink": "scorpion", "shard": "scorpion",
	"cinder": "golem", "nimbus": "golem",
}
const SKETCH_CLIPS := {
	"boar": {"idle": "idle", "run": "run", "walk": "walk", "attack": "Attack01", "hit": "hit", "death": "Death"},
	"batlord": {"idle": "Fly Forward In Place", "run": "Fly Forward In Place", "attack": "Bite Attack", "hit": "", "death": "Die"},
	"scorpion": {"idle": "idle", "run": "walkForward", "attack": "clawAttackLeft", "hit": "", "death": "death"},
	"golem": {"idle": "idle", "run": "walk", "attack": "hit", "hit": "damage", "death": "die"},
}
## Biome grade multiplied over each painted hide: frost goes pale and cold,
## volcano charred, the mushroom wood dim violet.
const SKETCH_TINT := {
	"snowpup": Color(0.82, 0.95, 1.1), "magmash": Color(0.55, 0.42, 0.38),
	"glowmoth": Color(0.72, 0.8, 0.95), "ashbat": Color(0.6, 0.45, 0.42), "icewisp": Color(0.8, 0.95, 1.15),
	"shard": Color(0.7, 0.9, 1.1), "skink": Color(0.75, 0.5, 0.42),
	"nimbus": Color(1, 1, 1), "cinder": Color(0.8, 0.72, 0.68),
}


## Species that fly: hovered and pitched in the motion layer.
static func flies(id: String) -> bool:
	return monster(id) in FLYERS or sketch_mon(id) == "batlord"


## Dark-fantasy pass (art direction 2026-10-17): realistic, worn creatures.
## Heroes keep their animal and wear Armor3D kit; enemies are feral beasts.
## Files in assets/models/sketchfab/dark/ (CC-BY 4.0, see CREDITS.md).
const DARK := {"juniper": "fox", "sprout": "badger", "boarlet": "bear", "spirit_wolf": "fox"}
const DARK_CLIPS := {
	"fox": {"idle": "A5_StandAngry_Breathing_01", "walk": "Loco_Walk", "run": "Run", "attack": "Attack_StandAngry_02_High", "hit": "Hit_Stand_R01", "death": "Death_Stand_L01", "perch": "A3_Stand_Idle_01"},
	"badger": {"idle": "Badger|european_badger_aggressive_idle_01", "walk": "Badger|european_badger_trot_fwd_01", "run": "Badger|european_badger_sprint_fwd_01", "attack": "Badger|european_badger_aggressive_attack_fwd_01", "hit": "Badger|european_badger_hit_chest_front_01", "death": "Badger|european_badger_dead_run_01"},
	"bear": {"idle": "Armature|stand angry breathing", "walk": "Armature|walk", "run": "Armature|run", "attack": "Armature|atk run", "hit": "Armature|stand angry breathing", "death": "Armature|stand to lying"},
}


## Corruption colour of a feral enemy: its eye embers and the fresnel
## glow round its silhouette, so species read apart at the far camera.
static func feral_color(id: String) -> Color:
	if id == "spirit_wolf":
		return Color(0.55, 0.85, 1.0)
	match dark(id):
		"badger":
			return Color(0.55, 1.0, 0.25)
		"bear":
			return Color(1.0, 0.36, 0.08)
	return Color(1.0, 0.45, 0.12)


static func dark(id: String) -> String:
	return str(DARK.get(id, ""))


## Armour kit Armor3D builds onto a hero rig ("" for none).
static func armor(id: String) -> String:
	return "fox_ranger" if id == "juniper" else ""


static func sketch_mon(id: String) -> String:
	return str(SKETCH_MON.get(id, ""))


static func monster(id: String) -> String:
	return str(MONSTERS.get(id, ""))


static func model(id: String) -> String:
	if HEROES.has(id):
		return HEROES[id]
	var dk := dark(id)
	if dk != "" and ResourceLoader.exists("res://assets/models/sketchfab/dark/%s.glb" % dk):
		return "res://assets/models/sketchfab/dark/%s.glb" % dk
	if id == "caplet" and ResourceLoader.exists("res://assets/models/sketchfab/thistle.glb"):
		# The mushroom wood's lord: the Mushroom Boss rig, dyed violet.
		return "res://assets/models/sketchfab/thistle.glb"
	var sk := sketch_mon(id)
	if sk != "" and ResourceLoader.exists("res://assets/models/sketchfab/mon/%s.glb" % sk):
		return "res://assets/models/sketchfab/mon/%s.glb" % sk
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
	if HEROES.has(id):
		return HERO_CLIPS
	var path := model(id)
	if "/sketchfab/dark/" in path:
		return DARK_CLIPS[dark(id)]
	if "/sketchfab/mon/" in path:
		return SKETCH_CLIPS[sketch_mon(id)]
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
	if HEROES.has(id):
		# Gear3D owns the knights' materials (tier finish shader).
		return {}
	var path := model(id)
	if "/sketchfab/dark/" in path:
		# Real fur and hide maps: matte, desaturated and a shade darker, a
		# cold rim. Enemies get burning eyes via the motion layer's glow.
		var d := {"roughness": 0.86, "specular": 0.28, "rim": 0.22, "rim_tint": 0.8, "grade": 0.72, "fur_cut": 0.5}
		if id == "sprout":
			d["albedo"] = Color(0.42, 0.43, 0.33)
		elif id == "boarlet":
			d["albedo"] = Color(0.5, 0.46, 0.44)
		elif id == "spirit_wolf":
			d["albedo"] = Color(0.48, 0.6, 0.78)
		else:
			d["albedo"] = Color(0.74, 0.66, 0.6)
		return d
	if "/sketchfab/mon/" in path:
		# Painted PBR hides: matte, a cool rim, a little backlight. Bosses'
		# cores glow through (golem cracks), set per biome.
		var o := {"roughness": 0.78, "specular": 0.3, "rim": 0.3, "rim_tint": 0.7}
		if id == "cinder":
			o["backlight"] = Color(0.25, 0.06, 0.01)
			o["glow_core"] = Color(1.0, 0.35, 0.06)
			o["glow_tex"] = "res://assets/models/sketchfab/mon/golem_glow.png"
		elif id == "nimbus":
			o["backlight"] = Color(0.05, 0.15, 0.25)
			o["glow_core"] = Color(0.35, 0.85, 1.0)
			o["glow_tex"] = "res://assets/models/sketchfab/mon/golem_glow.png"
			# Ice repaint: grey-blue stone with cyan veins (golem_ice.png).
			o["albedo_tex"] = "res://assets/models/sketchfab/mon/golem_ice.png"
		return o
	if monster(id) != "":
		# Flat toy colours: take the gloss off, add grain, rim and a little
		# subsurface so they sit in the painted world.
		# Menace grade: the googly white eyes become dark sockets lit by a
		# biome-coloured glow, and the candy hides are muted and darkened.
		var glow := Color(1.0, 0.62, 0.18)
		if id in ["capling", "spore", "glowmoth", "puddle", "caplet"]:
			glow = Color(0.62, 1.0, 0.3)
		elif id in ["snowpup", "shard", "icewisp", "yeti", "nimbus"]:
			glow = Color(0.35, 0.85, 1.0)
		elif id in ["cindling", "skink", "ashbat", "magmash", "cinder"]:
			glow = Color(1.0, 0.3, 0.08)
		return {"roughness": 0.8, "specular": 0.28, "rim": 0.35, "rim_tint": 0.75, "paint": true, "subsurface": 0.1, "menace": glow}
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
	# Dark quadrupeds are sized by height, so long low bodies need a nudge:
	# the fox reads oversized next to mobs, the rot-bear must loom over it.
	match dark(id):
		"fox":
			return 0.82
		"bear":
			return 1.55
		"badger":
			return 1.05
	return 1.0


static func tint(id: String) -> Color:
	# Multiply the painted texture. Heroes stay recognizable: Ember orange-red,
	# Juniper russet, Pebble a teal-brown otter. Shared meshes still take the
	# catalog color.
	var path := model(id)
	if HEROES.has(id) or "/sketchfab/dark/" in path:
		return Color.WHITE
	if "/sketchfab/mon/" in path:
		return SKETCH_TINT.get(id, Color.WHITE)
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
		return Color(0.74, 0.66, 0.6)
	var info := Catalog.critter(id)
	if info.is_empty():
		return Color.WHITE
	return Color(str(info.get("color", "ffffff"))).lerp(Color.WHITE, 0.42)


static func nose(id: String) -> float:
	# Sketchfab rigs have no Forward marker. Mixamo and these FBX exports
	# face +Z. Returning a negative value keeps the old "nose is -Z" default.
	var path := model(id)
	if HEROES.has(id):
		return 0.0
	if dark(id) == "badger":
		# Measured from the rig (pelvis -> head) at spawn; the badger's rest
		# pose matches its clips. The AnimalMesh3D fox and bear face +Z.
		return -2.0
	if dark(id) != "":
		return 0.0
	if monster(id) != "" or "/sketchfab/mon/" in path or "/sketchfab/dark/" in path:
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


## Yaw for the head close-up: quadrupeds look almost straight at the camera.
static func head_turn(id: String) -> float:
	return 0.25 if dark(id) != "" else 0.55


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
		# Head plus a wing and horns, so the medallion reads "dragon" and
		# not a big-eyed chick.
		return Rect2(0.22, 0.0, 0.78, 0.82)
	if dark(id) != "":
		# Side-on quadrupeds face right in the 3/4 render: head top right.
		# Head crops render near-frontal (head_turn), so the face is the
		# upper middle of the body box.
		return Rect2(0.18, 0.28, 0.64, 0.72)
	if id == "pebble":
		# The otter stands side-on: its head sits top right of the body box.
		return Rect2(0.36, 0.0, 0.64, 0.62)
	return Rect2()


## Share of the body height that is head, for the medallion close-up.
static func head_share(id: String) -> float:
	if HEROES.has(id):
		# Horned great helm: the top fifth reads as the knight's face.
		return 0.24
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

