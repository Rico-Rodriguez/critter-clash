class_name GearDB
extends RefCounted
## What every piece of gear looks like. Gear is class-specific (each hero has
## its own line, like Diablo) and has seven material tiers (like Old School:
## bronze to dragon). A piece is {slot, cls, mat, rarity, ...}; its look comes
## from here, never from the save, so art changes never touch saves.
##
## Parts are meshes lifted from the KayKit characters. They all share one
## skeleton, so a Knight can wear the Mage's hat: "Mage/Hat". A "T:Knight" is
## that character's torso set (body + both arms), "L:Knight" its legs.

const TIERS := 7
## Skill level needed to wear a tier (skill depends on the hero and the slot).
const REQ := [1, 5, 12, 20, 30, 40, 55]
## What a hero wears with nothing equipped: a plain man in a tunic.
const BASIC_DYE := Color(0.72, 0.62, 0.48, 0.92)

const METAL := [
	Color(0.78, 0.5, 0.26), Color(0.56, 0.57, 0.62), Color(0.8, 0.84, 0.9), Color(0.28, 0.4, 0.9),
	Color(0.2, 0.62, 0.34), Color(0.25, 0.82, 0.92), Color(0.82, 0.14, 0.12),
]
const HIDE := [
	Color(0.55, 0.38, 0.22), Color(0.4, 0.27, 0.16), Color(0.58, 0.55, 0.5), Color(0.25, 0.6, 0.28),
	Color(0.22, 0.4, 0.85), Color(0.8, 0.2, 0.16), Color(0.14, 0.13, 0.15),
]
const CLOTH := [
	Color(0.55, 0.52, 0.48), Color(0.28, 0.4, 0.8), Color(0.2, 0.62, 0.62), Color(0.5, 0.28, 0.8),
	Color(0.78, 0.22, 0.5), Color(0.95, 0.75, 0.25), Color(0.16, 0.1, 0.28),
]
## How fine each material tier looks, per kind of line (char.gdshader `grade`):
## polish, shimmer, veins, vein heat. Low tiers are dull and dirty; from the
## fourth up a band of light runs over the piece; the top tier glows from
## within. Metal gleams most, hide takes a sheen, cloth carries the light.
const GRADES := {
	"metal": [
		Vector4(0.0, 0.0, 0.0, 0.0), Vector4(0.2, 0.0, 0.0, 0.0), Vector4(0.5, 0.0, 0.0, 0.0), Vector4(0.7, 0.3, 0.0, 0.0),
		Vector4(0.8, 0.6, 0.0, 0.0), Vector4(0.9, 0.9, 0.35, 0.0), Vector4(0.9, 0.6, 1.0, 0.25),
	],
	"hide": [
		Vector4(0.0, 0.0, 0.0, 0.0), Vector4(0.05, 0.0, 0.0, 0.0), Vector4(0.2, 0.0, 0.0, 0.0), Vector4(0.35, 0.25, 0.0, 0.0),
		Vector4(0.45, 0.5, 0.0, 0.0), Vector4(0.5, 0.75, 0.3, 0.0), Vector4(0.55, 0.5, 0.9, 0.1),
	],
	"cloth": [
		Vector4(0.0, 0.0, 0.0, 0.0), Vector4(0.0, 0.0, 0.0, 0.0), Vector4(0.05, 0.15, 0.0, 0.0), Vector4(0.1, 0.35, 0.0, 0.0),
		Vector4(0.15, 0.55, 0.3, 0.0), Vector4(0.2, 0.8, 0.6, 0.0), Vector4(0.25, 0.6, 1.0, 0.3),
	],
}
## Glow colors where a material's dye is too dark to glow in its own color.
const ACCENTS := {"cloth": {6: Color(0.72, 0.35, 1.0)}, "hide": {6: Color(0.3, 0.85, 0.55)}}
## From this material tier a weapon or offhand gives off sparks, and a hero
## wearing it in all five slots stands in an aura.
const ENCHANT_FROM := 4

const METAL_NAMES := ["Bronze", "Iron", "Steel", "Mithril", "Adamant", "Rune", "Dragon"]
const HIDE_NAMES := ["Leather", "Hard Leather", "Studded", "Green Dragonhide", "Blue Dragonhide", "Red Dragonhide", "Black Dragonhide"]
const CLOTH_NAMES := ["Novice", "Apprentice", "Adept", "Mystic", "Arcane", "Infinity", "Eldritch"]

## Per hero: material names and dyes, the skills that gate its gear, what is in
## the hand when nothing is equipped, and the look stages of every slot. A
## stage applies from its `from` tier upward (the last matching one wins).
const LINES := {
	"knight": {
		"names": METAL_NAMES, "dye": METAL, "weapon_skill": "attack", "armor_skill": "defence",
		"starter": "dagger.gltf", "offhand_bone": "handslot.l",
		"weapon": [
			{"from": 0, "name": "Shortsword", "model": "sword_1handed.gltf"},
			{"from": 3, "name": "Longsword", "model": "sword_2handed.gltf"},
			{"from": 5, "name": "Greatsword", "model": "sword_2handed_color.gltf", "scale": 1.08},
		],
		"helm": [
			{"from": 0, "name": "Med Helm", "parts": ["Knight/Helmet"]},
			{"from": 2, "name": "Full Helm", "parts": ["Knight/Helmet", "Knight/HelmetVisor"]},
		],
		"chest": [
			{"from": 0, "name": "Chainbody", "parts": ["T:Ranger"]},
			{"from": 2, "name": "Platebody", "parts": ["T:Knight"]},
			{"from": 5, "name": "Platebody", "parts": ["T:Knight", "Knight/Cape"]},
		],
		"legs": [
			{"from": 0, "name": "Chainlegs", "parts": ["L:Ranger"]},
			{"from": 2, "name": "Platelegs", "parts": ["L:Knight"]},
		],
		"trinket": [
			{"from": 0, "name": "Buckler", "model": "shield_round.gltf"},
			{"from": 2, "name": "Kite Shield", "model": "shield_badge.gltf"},
			{"from": 4, "name": "Spiked Shield", "model": "shield_spikes.gltf"},
			{"from": 6, "name": "Dragon Shield", "model": "shield_square_color.gltf"},
		],
	},
	"barbarian": {
		"names": METAL_NAMES, "dye": METAL, "weapon_skill": "attack", "armor_skill": "defence",
		"starter": "axe_1handed.gltf", "offhand_bone": "back",
		"weapon": [
			{"from": 0, "name": "Hatchet", "model": "axe_1handed.gltf", "scale": 1.35},
			{"from": 2, "name": "Battleaxe", "model": "axe_2handed.gltf"},
			{"from": 5, "name": "Great Axe", "model": "axe_2handed.gltf", "scale": 1.18},
		],
		"helm": [
			{"from": 0, "name": "Horned Cap", "parts": ["Skeleton_Warrior/Helmet"]},
			{"from": 3, "name": "Bear Helm", "parts": ["Barbarian/BearHat"]},
		],
		"chest": [
			{"from": 0, "name": "Hide Vest", "parts": ["T:Ranger"]},
			{"from": 1, "name": "Fur Armour", "parts": ["T:Barbarian"]},
			{"from": 5, "name": "Warlord Armour", "parts": ["T:Barbarian", "Knight/Cape"]},
		],
		"legs": [
			{"from": 0, "name": "Hide Chaps", "parts": ["L:Ranger"]},
			{"from": 1, "name": "Fur Legs", "parts": ["L:Barbarian"]},
		],
		"trinket": [
			{"from": 0, "name": "Round Shield", "model": "shield_round_barbarian.gltf"},
			{"from": 4, "name": "Spiked Shield", "model": "shield_spikes.gltf"},
		],
	},
	"mage": {
		"names": CLOTH_NAMES, "dye": CLOTH, "weapon_skill": "magic", "armor_skill": "magic",
		"starter": "wand.gltf", "offhand_bone": "handslot.l",
		"weapon": [
			{"from": 0, "name": "Wand", "model": "wand.gltf", "scale": 1.15},
			{"from": 2, "name": "Staff", "model": "staff.gltf"},
			{"from": 5, "name": "Skull Staff", "model": "Skeleton_Staff.gltf", "scale": 1.1},
		],
		"helm": [
			{"from": 0, "name": "Hat", "parts": ["Mage/Hat"]},
		],
		"chest": [
			{"from": 0, "name": "Robe Top", "parts": ["T:Ranger"]},
			{"from": 1, "name": "Robe Top", "parts": ["T:Mage"]},
			{"from": 4, "name": "Robe Top", "parts": ["T:Mage", "Mage/Cape"]},
		],
		"legs": [
			{"from": 0, "name": "Robe Bottom", "parts": ["L:Ranger"]},
			{"from": 1, "name": "Robe Bottom", "parts": ["L:Mage"]},
		],
		"trinket": [
			{"from": 0, "name": "Tome", "model": "spellbook_closed.gltf"},
			{"from": 3, "name": "Grimoire", "model": "spellbook_open.gltf"},
		],
	},
	"ranger": {
		"names": HIDE_NAMES, "dye": HIDE, "weapon_skill": "ranged", "armor_skill": "ranged",
		"starter": "bow.gltf", "offhand_bone": "back",
		"weapon": [
			{"from": 0, "name": "Shortbow", "model": "bow.gltf"},
			{"from": 3, "name": "Longbow", "model": "bow_withString.gltf"},
			{"from": 5, "name": "Warbow", "model": "bow_withString.gltf", "scale": 1.15},
		],
		"helm": [
			{"from": 0, "name": "Mask", "parts": ["Rogue_Hooded/Mask"]},
			{"from": 3, "name": "Hood", "parts": ["Rogue_Hooded/Head"], "hood": true},
		],
		"chest": [
			{"from": 0, "name": "Body", "parts": ["T:Ranger"]},
			{"from": 3, "name": "Body", "parts": ["T:Rogue_Hooded"]},
			{"from": 5, "name": "Body", "parts": ["T:Rogue_Hooded", "Ranger/Cape"]},
		],
		"legs": [
			{"from": 0, "name": "Chaps", "parts": ["L:Ranger"]},
			{"from": 3, "name": "Chaps", "parts": ["L:Rogue_Hooded"]},
		],
		"trinket": [
			{"from": 0, "name": "Quiver", "parts": ["Ranger/Quiver"]},
		],
	},
}

## Icon per hero and slot (game-icons names), tinted by the material's dye.
const ICONS := {
	"knight": {"weapon": "broadsword", "helm": "visored-helm", "chest": "breastplate", "legs": "leg-armor", "trinket": "shield"},
	"barbarian": {"weapon": "battle-axe", "helm": "wolf-head", "chest": "breastplate", "legs": "leg-armor", "trinket": "checked-shield"},
	"mage": {"weapon": "wizard-staff", "helm": "moon", "chest": "cloak-dagger", "legs": "boots", "trinket": "book-cover"},
	"ranger": {"weapon": "pocket-bow", "helm": "arrow-scope", "chest": "cloak-dagger", "legs": "boots", "trinket": "arrow-flights"},
}


static func icon(cls: String, slot: String) -> String:
	return ICONS[cls][slot]


## An item's icon: a unique's own, else the class-and-slot one.
static func item_icon(it: Dictionary) -> String:
	var u := str(it.get("unique", ""))
	if u != "" and DB.UNIQUES.has(u):
		return DB.UNIQUES[u]["icon"]
	return icon(str(it.get("cls", "knight")), str(it["slot"]))


## Item icon tint: the material's dye, lifted so it reads on dark frames.
static func item_color(it: Dictionary) -> Color:
	var u := str(it.get("unique", ""))
	if u != "" and DB.UNIQUES.has(u) and DB.UNIQUES[u].has("dye"):
		return Color(DB.UNIQUES[u]["dye"]).lightened(0.25)
	return dye(str(it.get("cls", "knight")), int(it.get("mat", 0))).lightened(0.2)


## The Old School skill that gates a slot for a hero.
static func skill_for(cls: String, slot: String) -> String:
	var line: Dictionary = LINES[cls]
	return line["weapon_skill"] if slot == "weapon" else line["armor_skill"]


static func req_for(it: Dictionary) -> int:
	return int(REQ[clampi(int(it.get("mat", 0)), 0, TIERS - 1)])


## The stage of `slot` for material tier `mat`.
static func stage(cls: String, slot: String, mat: int) -> Dictionary:
	var out: Dictionary = {}
	for st: Dictionary in LINES[cls][slot]:
		if int(st["from"]) <= mat:
			out = st
	return out


static func kind(cls: String) -> String:
	return {"mage": "cloth", "ranger": "hide"}.get(cls, "metal")


## The shader grade of a worn piece. Legendaries and uniques shimmer at least
## a little whatever their metal.
static func grade(it: Dictionary) -> Vector4:
	if it.is_empty():
		return Vector4.ZERO
	var g: Vector4 = GRADES[kind(str(it.get("cls", "knight")))][clampi(int(it.get("mat", 0)), 0, TIERS - 1)]
	if str(it.get("rarity", "")) == "legendary" or str(it.get("unique", "")) != "":
		g = Vector4(maxf(g.x, 0.5), maxf(g.y, 0.45), g.z, g.w)
	return g


## What a piece's grade glows in: a line's own accent, else its dye brought
## up to full brightness (a uniques's dye for uniques).
static func accent(it: Dictionary) -> Color:
	if it.is_empty():
		return Color(1, 1, 1)
	var cls := str(it.get("cls", "knight"))
	var mat := clampi(int(it.get("mat", 0)), 0, TIERS - 1)
	var u := str(it.get("unique", ""))
	if u == "" and ACCENTS.get(kind(cls), {}).has(mat):
		return ACCENTS[kind(cls)][mat]
	var c := item_color(it)
	var m := maxf(maxf(c.r, c.g), maxf(c.b, 0.05))
	return Color(c.r / m, c.g / m, c.b / m)


## Sparks off a weapon or offhand: the color, alpha = how many (0 = none).
static func enchant(it: Dictionary) -> Color:
	if it.is_empty():
		return Color(0, 0, 0, 0)
	var mat := int(it.get("mat", 0))
	var c := accent(it)
	var a := clampf((mat - ENCHANT_FROM + 1) / 3.0, 0.0, 1.0)
	if str(it.get("rarity", "")) == "legendary" or str(it.get("unique", "")) != "":
		a = maxf(a, 0.5)
	return Color(c, a)


## The aura of a hero in a full set of fine gear: the color of its weakest
## piece, alpha by how fine (0 = no aura).
static func aura(worn: Dictionary, cls: String) -> Color:
	var low := TIERS
	for slot in DB.SLOTS:
		var it: Dictionary = worn.get(slot, {})
		if it.is_empty():
			return Color(0, 0, 0, 0)
		low = mini(low, int(it.get("mat", 0)))
	if low < ENCHANT_FROM:
		return Color(0, 0, 0, 0)
	return Color(accent({"cls": cls, "mat": low}), (low - ENCHANT_FROM + 1) / float(TIERS - ENCHANT_FROM))


static func material_name(cls: String, mat: int) -> String:
	return LINES[cls]["names"][clampi(mat, 0, TIERS - 1)]


static func dye(cls: String, mat: int) -> Color:
	return LINES[cls]["dye"][clampi(mat, 0, TIERS - 1)]


## "Mithril Platebody" for a hero's tier-3 chest.
static func base_name(cls: String, slot: String, mat: int) -> String:
	return "%s %s" % [material_name(cls, mat), stage(cls, slot, mat)["name"]]


## Look of an item: {parts, model, dye (rgb + mix), scale, hood}. Uniques may
## override the dye with their own color.
static func look(it: Dictionary) -> Dictionary:
	var cls: String = it["cls"]
	var slot: String = it["slot"]
	var mat := int(it.get("mat", 0))
	var st := stage(cls, slot, mat)
	var c: Color = dye(cls, mat)
	var u := str(it.get("unique", ""))
	var amount := 0.5 if slot in ["weapon", "trinket"] else 0.72
	if u != "" and DB.UNIQUES[u].has("dye"):
		c = DB.UNIQUES[u]["dye"]
		amount = 0.8
	return {
		"parts": expand(st.get("parts", [])), "model": str(st.get("model", "")), "dye": Color(c, amount),
		"scale": float(st.get("scale", 1.0)), "hood": bool(st.get("hood", false)),
	}


## "T:Knight" -> its body and arms; "L:Knight" -> its legs.
static func expand(parts: Array) -> Array:
	var out := []
	for p: String in parts:
		if p.begins_with("T:"):
			for m in ["Body", "ArmLeft", "ArmRight"]:
				out.append(p.substr(2) + "/" + m)
		elif p.begins_with("L:"):
			for m in ["LegLeft", "LegRight"]:
				out.append(p.substr(2) + "/" + m)
		else:
			out.append(p)
	return out


## Mesh node name inside a KayKit character file: "Rogue_Hooded/Mask" ->
## "RogueHooded_Mask".
static func mesh_name(part: String) -> String:
	var src := part.get_slice("/", 0)
	var what := part.get_slice("/", 1)
	return "%s_%s" % [src.replace("Rogue_Hooded", "RogueHooded"), what]


## Rolls the material tier of a drop: harder content drops better metal.
## `bonus` is zone/depth/boss shift in tiers.
## `base_mat` is the tier's material (DB.TIERS[i]["mat"]).
static func roll_mat(base_mat: int, bonus: int, rng: RandomNumberGenerator) -> int:
	var base := base_mat + bonus
	var r := rng.randf()
	var shift := -1 if r < 0.22 else (0 if r < 0.62 else (1 if r < 0.9 else 2))
	return clampi(base + shift, 0, TIERS - 1)
