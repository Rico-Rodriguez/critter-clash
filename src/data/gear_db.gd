class_name GearDB
extends RefCounted
## What every piece of gear looks like. Gear is class-specific (each hero has
## its own line, like Diablo) and comes in five named sets, Gravedigger to
## Gravelight, that every hero has its own cut of. A piece is {slot, cls, mat,
## rarity, ...} (`mat` is the set's index); its look comes from here, never
## from the save, so art changes never touch saves.
##
## Parts are meshes lifted from the KayKit characters. They all share one
## skeleton, so a Knight can wear the Mage's hat: "Mage/Hat". A "T:Knight" is
## that character's torso set (body + both arms), "L:Knight" its legs. A
## "P:file@bone" is a rigid prop of ours (assets/kaykit/gear/) pinned to a bone.

const TIERS := 5
## Skill level needed to wear a set (skill depends on the hero and the slot).
const REQ := [1, 10, 25, 40, 60]
## What a hero wears with nothing equipped: a plain man in a tunic.
const BASIC_DYE := Color(0.72, 0.62, 0.48, 0.92)

## The five sets, shared by every hero. Each step adds a new kind of flash:
## scavenged scraps, a matching kit, a heavy engraved silhouette, glowing
## veins and embers, then pale soul fire and a full-set aura.
const SET_NAMES := ["Gravedigger", "Warden", "Barrowsteel", "Bloodiron", "Gravelight"]

const METAL := [
	Color(0.62, 0.42, 0.26), Color(0.6, 0.64, 0.72), Color(0.34, 0.36, 0.42), Color(0.2, 0.06, 0.07), Color(0.86, 0.95, 0.9),
]
const HIDE := [
	Color(0.5, 0.36, 0.22), Color(0.3, 0.42, 0.26), Color(0.2, 0.2, 0.24), Color(0.3, 0.07, 0.08), Color(0.8, 0.9, 0.84),
]
const CLOTH := [
	Color(0.52, 0.48, 0.42), Color(0.28, 0.38, 0.72), Color(0.32, 0.18, 0.5), Color(0.42, 0.06, 0.1), Color(0.82, 0.94, 0.88),
]
## How fine each set looks, per kind of line (char.gdshader `grade`): polish,
## shimmer, veins, vein heat. Gravedigger is dull and dirty; Barrowsteel takes
## a band of light; Bloodiron glows in its seams; Gravelight burns from within.
## Metal gleams most, hide takes a sheen, cloth carries the light.
const GRADES := {
	"metal": [
		Vector4(0.0, 0.0, 0.0, 0.0), Vector4(0.45, 0.0, 0.0, 0.0), Vector4(0.75, 0.35, 0.0, 0.0), Vector4(0.8, 0.3, 1.0, 0.3), Vector4(0.9, 0.8, 1.0, 0.45),
	],
	"hide": [
		Vector4(0.0, 0.0, 0.0, 0.0), Vector4(0.15, 0.0, 0.0, 0.0), Vector4(0.35, 0.3, 0.0, 0.0), Vector4(0.45, 0.3, 0.9, 0.2), Vector4(0.55, 0.7, 1.0, 0.35),
	],
	"cloth": [
		Vector4(0.0, 0.0, 0.0, 0.0), Vector4(0.05, 0.1, 0.0, 0.0), Vector4(0.1, 0.35, 0.0, 0.0), Vector4(0.15, 0.4, 0.9, 0.25), Vector4(0.25, 0.8, 1.0, 0.4),
	],
}
## What the top sets glow in, whatever the dye: Bloodiron's embers and
## Gravelight's soul fire.
const SET_ACCENT := {3: Color(1.0, 0.22, 0.1), 4: Color(0.55, 1.0, 0.75)}
## From this set a weapon or offhand gives off sparks, and a hero wearing it
## in all five slots stands in an aura.
const ENCHANT_FROM := 3

## Per hero: material names and dyes, the skills that gate its gear, what is in
## the hand when nothing is equipped, and the look stages of every slot. A
## stage applies from its `from` tier upward (the last matching one wins).
const LINES := {
	"knight": {
		"dye": METAL, "weapon_skill": "attack", "armor_skill": "defence",
		"starter": "knight_sword_0.gltf", "offhand_bone": "handslot.l", "shield": true,
		"weapon": [
			{"from": 0, "name": "Shortsword", "model": "sword_1handed.gltf", "alts": [
				{"name": "War Axe", "model": "axe_1handed.gltf", "scale": 1.2, "icon": "battle-axe"},
				{"name": "Arming Sword", "model": "sword_B.gltf"},
				{"name": "Morning Star", "model": "hammer_B.gltf", "scale": 1.15, "icon": "round-star"},
			]},
			{"from": 2, "name": "Longsword", "model": "sword_2handed.gltf", "alts": [
				{"name": "Battleaxe", "model": "axe_2handed.gltf", "scale": 0.9, "icon": "battle-axe"},
				{"name": "Warhammer", "model": "hammer_A.gltf", "scale": 1.1, "icon": "anvil"},
				{"name": "Rapier", "model": "sword_D.gltf", "scale": 0.95},
			]},
			{"from": 3, "name": "Greatsword", "model": "sword_2handed_color.gltf", "scale": 1.08, "alts": [
				{"name": "Claymore", "model": "sword_E.gltf", "scale": 0.62},
				{"name": "Halberd", "model": "halberd.gltf", "scale": 0.72, "icon": "battle-axe"},
			]},
		],
		# Helm, chest and legs are our own skinned models, one per set
		# (tools/art/make_dark_knight.py), worn on DarkKnight's body.
		"helm": [
			{"from": 0, "name": "Kettle Hat", "parts": ["DarkKnight_Helm0/Mesh"]},
			{"from": 1, "name": "Bascinet", "parts": ["DarkKnight_Helm1/Mesh"], "hood": true},
			{"from": 2, "name": "Beaked Helm", "parts": ["DarkKnight_Helm2/Mesh"], "hood": true},
			{"from": 3, "name": "Horned Helm", "parts": ["DarkKnight_Helm3/Mesh"], "hood": true},
			{"from": 4, "name": "Seraph Helm", "parts": ["DarkKnight_Helm4/Mesh"], "hood": true},
		],
		"chest": [
			{"from": 0, "name": "Hauberk", "parts": ["DarkKnight_Chest0/Mesh"]},
			{"from": 1, "name": "Cuirass", "parts": ["DarkKnight_Chest1/Mesh"]},
			{"from": 2, "name": "Plated Cuirass", "parts": ["DarkKnight_Chest2/Mesh"]},
			{"from": 3, "name": "Dread Cuirass", "parts": ["DarkKnight_Chest3/Mesh"]},
			{"from": 4, "name": "Seraph Cuirass", "parts": ["DarkKnight_Chest4/Mesh"]},
		],
		"legs": [
			{"from": 0, "name": "Chausses", "parts": ["DarkKnight_Legs0/Mesh"]},
			{"from": 1, "name": "Greaves", "parts": ["DarkKnight_Legs1/Mesh"]},
			{"from": 2, "name": "Plated Greaves", "parts": ["DarkKnight_Legs2/Mesh"]},
			{"from": 3, "name": "Dread Greaves", "parts": ["DarkKnight_Legs3/Mesh"]},
			{"from": 4, "name": "Seraph Greaves", "parts": ["DarkKnight_Legs4/Mesh"]},
		],
		# Our own offhands, one per set (tools/art/make_dark_offhands.py).
		"trinket": [
			{"from": 0, "name": "Buckler", "model": "knight_off_0.gltf"},
			{"from": 1, "name": "Heater Shield", "model": "knight_off_1.gltf"},
			{"from": 2, "name": "Barrow Heater", "model": "knight_off_2.gltf"},
			{"from": 3, "name": "Dread Heater", "model": "knight_off_3.gltf"},
			{"from": 4, "name": "Seraph Shield", "model": "knight_off_4.gltf"},
		],
	},
	"barbarian": {
		"dye": METAL, "weapon_skill": "attack", "armor_skill": "defence",
		"starter": "barb_axe_0.gltf", "offhand_bone": "back", "shield": true,
		"weapon": [
			{"from": 0, "name": "Hatchet", "model": "axe_1handed.gltf", "scale": 1.35, "alts": [
				{"name": "Cudgel", "model": "kit:bone_club", "icon": "bone-gnawer"},
				{"name": "Spiked Club", "model": "hammer_C.gltf", "scale": 1.1, "icon": "bone-gnawer"},
				{"name": "Bearded Axe", "model": "axe_C.gltf", "scale": 1.2},
			]},
			{"from": 1, "name": "Battleaxe", "model": "axe_2handed.gltf", "alts": [
				{"name": "Greatsword", "model": "sword_2handed.gltf", "scale": 1.1, "icon": "broadsword"},
				{"name": "Double Axe", "model": "axe_A.gltf", "scale": 1.35, "icon": "crossed-axes"},
			]},
			{"from": 3, "name": "Great Axe", "model": "axe_2handed.gltf", "scale": 1.18, "alts": [
				{"name": "Labrys", "model": "axe_B.gltf", "scale": 1.05, "icon": "crossed-axes"},
				{"name": "Maul", "model": "hammer_A.gltf", "scale": 1.3, "icon": "anvil"},
			]},
		],
		# Helm, chest and legs are our own skinned models, one per set
		# (tools/art/make_dark_heroes.py), worn on DarkBarbarian's body.
		"helm": [
			{"from": 0, "name": "Skullcap", "parts": ["DarkBarbarian_Helm0/Mesh"], "hood": true},
			{"from": 1, "name": "Horned Helm", "parts": ["DarkBarbarian_Helm1/Mesh"], "hood": true},
			{"from": 2, "name": "Crested Helm", "parts": ["DarkBarbarian_Helm2/Mesh"], "hood": true},
			{"from": 3, "name": "Spiked Helm", "parts": ["DarkBarbarian_Helm3/Mesh"], "hood": true},
			{"from": 4, "name": "Soul Crown", "parts": ["DarkBarbarian_Helm4/Mesh"], "hood": true},
		],
		"chest": [
			{"from": 0, "name": "Hide Vest", "parts": ["DarkBarbarian_Chest0/Mesh"]},
			{"from": 1, "name": "War Harness", "parts": ["DarkBarbarian_Chest1/Mesh"]},
			{"from": 2, "name": "Plated Harness", "parts": ["DarkBarbarian_Chest2/Mesh"]},
			{"from": 3, "name": "Warlord Harness", "parts": ["DarkBarbarian_Chest3/Mesh"]},
			{"from": 4, "name": "Soul Harness", "parts": ["DarkBarbarian_Chest4/Mesh"]},
		],
		"legs": [
			{"from": 0, "name": "Hide Chaps", "parts": ["DarkBarbarian_Legs0/Mesh"]},
			{"from": 1, "name": "Fur Legs", "parts": ["DarkBarbarian_Legs1/Mesh"]},
			{"from": 2, "name": "Iron Greaves", "parts": ["DarkBarbarian_Legs2/Mesh"]},
			{"from": 3, "name": "Spiked Greaves", "parts": ["DarkBarbarian_Legs3/Mesh"]},
			{"from": 4, "name": "Soul Greaves", "parts": ["DarkBarbarian_Legs4/Mesh"]},
		],
		# Our own offhands, one per set (tools/art/make_dark_offhands.py).
		"trinket": [
			{"from": 0, "name": "Round Shield", "model": "barb_off_0.gltf"},
			{"from": 1, "name": "Bound Shield", "model": "barb_off_1.gltf"},
			{"from": 2, "name": "Studded Shield", "model": "barb_off_2.gltf"},
			{"from": 3, "name": "Spiked Shield", "model": "barb_off_3.gltf"},
			{"from": 4, "name": "Sun Shield", "model": "barb_off_4.gltf"},
		],
	},
	# The Rogue: KayKit's hooded rogue, daggers in both hands.
	"rogue": {
		"dye": HIDE, "weapon_skill": "attack", "armor_skill": "defence",
		"starter": "rogue_daggers_0.gltf", "offhand_bone": "handslot.l",
		"weapon": [
			{"from": 0, "name": "Dagger", "model": "dagger.gltf"},
			{"from": 2, "name": "Kris", "model": "dagger_A.gltf", "alts": [
				{"name": "Stiletto", "model": "dagger_B.gltf"},
			]},
		],
		# Helm, chest and legs are our own skinned models, one per set
		# (tools/art/make_dark_heroes.py), worn on DarkRogue's body.
		"helm": [
			{"from": 0, "name": "Rag Hood", "parts": ["DarkRogue_Helm0/Mesh"], "hood": true},
			{"from": 1, "name": "Masked Hood", "parts": ["DarkRogue_Helm1/Mesh"], "hood": true},
			{"from": 2, "name": "Deep Cowl", "parts": ["DarkRogue_Helm2/Mesh"], "hood": true},
			{"from": 3, "name": "Horned Cowl", "parts": ["DarkRogue_Helm3/Mesh"], "hood": true},
			{"from": 4, "name": "Gilded Mask", "parts": ["DarkRogue_Helm4/Mesh"], "hood": true},
		],
		"chest": [
			{"from": 0, "name": "Jerkin", "parts": ["DarkRogue_Chest0/Mesh"]},
			{"from": 1, "name": "Scarfed Jerkin", "parts": ["DarkRogue_Chest1/Mesh"]},
			{"from": 2, "name": "Cloaked Jerkin", "parts": ["DarkRogue_Chest2/Mesh"]},
			{"from": 3, "name": "Dread Jerkin", "parts": ["DarkRogue_Chest3/Mesh"]},
			{"from": 4, "name": "Seraph Jerkin", "parts": ["DarkRogue_Chest4/Mesh"]},
		],
		"legs": [
			{"from": 0, "name": "Leggings", "parts": ["DarkRogue_Legs0/Mesh"]},
			{"from": 1, "name": "Wrapped Leggings", "parts": ["DarkRogue_Legs1/Mesh"]},
			{"from": 2, "name": "Guarded Leggings", "parts": ["DarkRogue_Legs2/Mesh"]},
			{"from": 3, "name": "Dread Leggings", "parts": ["DarkRogue_Legs3/Mesh"]},
			{"from": 4, "name": "Seraph Leggings", "parts": ["DarkRogue_Legs4/Mesh"]},
		],
		# Our own offhands, one per set (tools/art/make_dark_offhands.py).
		"trinket": [
			{"from": 0, "name": "Parrying Dagger", "model": "rogue_off_0.gltf"},
			{"from": 1, "name": "Main Gauche", "model": "rogue_off_1.gltf"},
			{"from": 2, "name": "Hooked Dagger", "model": "rogue_off_2.gltf"},
			{"from": 3, "name": "Dread Dagger", "model": "rogue_off_3.gltf"},
			{"from": 4, "name": "Seraph Dagger", "model": "rogue_off_4.gltf"},
		],
	},
	"mage": {
		"dye": CLOTH, "weapon_skill": "magic", "armor_skill": "magic",
		"starter": "mage_staff_0.gltf", "offhand_bone": "handslot.l",
		"weapon": [
			{"from": 0, "name": "Wand", "model": "wand.gltf", "scale": 1.15, "alts": [
				{"name": "Crystal Wand", "model": "wand_A.gltf", "icon": "fairy-wand"},
			]},
			{"from": 1, "name": "Staff", "model": "staff.gltf", "alts": [
				{"name": "Lantern Staff", "model": "kit:lantern_staff"},
				{"name": "Crystal Staff", "model": "staff_B.gltf", "icon": "crystal-shine"},
			]},
			{"from": 2, "name": "Bone Staff", "model": "kit:bone_staff"},
			{"from": 3, "name": "Skull Staff", "model": "Skeleton_Staff.gltf", "scale": 1.1, "alts": [
				{"name": "Deathlight Staff", "model": "kit:deathlight"},
			]},
		],
		# Helm, chest and legs are our own skinned models, one per set
		# (tools/art/make_dark_heroes.py), worn on DarkMage's body.
		"helm": [
			{"from": 0, "name": "Wide Hat", "parts": ["DarkMage_Helm0/Mesh"], "hood": true},
			{"from": 1, "name": "Pointed Hat", "parts": ["DarkMage_Helm1/Mesh"], "hood": true},
			{"from": 2, "name": "Star Hood", "parts": ["DarkMage_Helm2/Mesh"], "hood": true},
			{"from": 3, "name": "Horned Cowl", "parts": ["DarkMage_Helm3/Mesh"], "hood": true},
			{"from": 4, "name": "Crowned Mitre", "parts": ["DarkMage_Helm4/Mesh"], "hood": true},
		],
		"chest": [
			{"from": 0, "name": "Hide Robe", "parts": ["DarkMage_Chest0/Mesh"]},
			{"from": 1, "name": "Mantled Robe", "parts": ["DarkMage_Chest1/Mesh"]},
			{"from": 2, "name": "Star Robe", "parts": ["DarkMage_Chest2/Mesh"]},
			{"from": 3, "name": "Dread Robe", "parts": ["DarkMage_Chest3/Mesh"]},
			{"from": 4, "name": "Archmage Robe", "parts": ["DarkMage_Chest4/Mesh"]},
		],
		"legs": [
			{"from": 0, "name": "Robe Skirt", "parts": ["DarkMage_Legs0/Mesh"]},
			{"from": 1, "name": "Wine Skirt", "parts": ["DarkMage_Legs1/Mesh"]},
			{"from": 2, "name": "Star Skirt", "parts": ["DarkMage_Legs2/Mesh"]},
			{"from": 3, "name": "Dread Skirt", "parts": ["DarkMage_Legs3/Mesh"]},
			{"from": 4, "name": "Archmage Skirt", "parts": ["DarkMage_Legs4/Mesh"]},
		],
		# Our own offhands, one per set (tools/art/make_dark_offhands.py).
		"trinket": [
			{"from": 0, "name": "Tome", "model": "mage_off_0.gltf"},
			{"from": 1, "name": "Bound Tome", "model": "mage_off_1.gltf"},
			{"from": 2, "name": "Star Grimoire", "model": "mage_off_2.gltf", "alts": [
				{"name": "Skull Orb", "model": "uniq_skull_orb.gltf", "icon": "crowned-skull"},
			]},
			{"from": 3, "name": "Blood Grimoire", "model": "mage_off_3.gltf", "alts": [
				{"name": "Candelabra", "model": "uniq_candelabra.gltf", "icon": "flame"},
				{"name": "Phylactery", "model": "uniq_phylactery.gltf", "icon": "gems"},
			]},
			{"from": 4, "name": "Sun Grimoire", "model": "mage_off_4.gltf"},
		],
	},
	"ranger": {
		"dye": HIDE, "weapon_skill": "ranged", "armor_skill": "ranged",
		"starter": "ranger_shortbow_0.gltf", "offhand_bone": "back",
		"weapon": [
			{"from": 0, "name": "Shortbow", "model": "bow.gltf", "alts": [
				{"name": "Hunting Bow", "model": "kit:hunting_bow"},
			]},
			{"from": 2, "name": "Longbow", "model": "bow_withString.gltf", "alts": [
				{"name": "Recurve Bow", "model": "kit:recurve"},
			]},
			{"from": 3, "name": "Warbow", "model": "bow_withString.gltf", "scale": 1.15, "alts": [
				{"name": "Recurve Bow", "model": "kit:recurve", "scale": 1.15},
			]},
		],
		# Helm, chest and legs are our own skinned models, one per set
		# (tools/art/make_dark_heroes.py), worn on DarkRanger's body.
		"helm": [
			{"from": 0, "name": "Leather Cap", "parts": ["DarkRanger_Helm0/Mesh"], "hood": true},
			{"from": 1, "name": "Warden Hood", "parts": ["DarkRanger_Helm1/Mesh"], "hood": true},
			{"from": 2, "name": "Circlet Hood", "parts": ["DarkRanger_Helm2/Mesh"], "hood": true},
			{"from": 3, "name": "Antler Hood", "parts": ["DarkRanger_Helm3/Mesh"], "hood": true},
			{"from": 4, "name": "Stag Crown", "parts": ["DarkRanger_Helm4/Mesh"], "hood": true},
		],
		"chest": [
			{"from": 0, "name": "Hide Jerkin", "parts": ["DarkRanger_Chest0/Mesh"]},
			{"from": 1, "name": "Brigandine", "parts": ["DarkRanger_Chest1/Mesh"]},
			{"from": 2, "name": "Plated Brigandine", "parts": ["DarkRanger_Chest2/Mesh"]},
			{"from": 3, "name": "Dread Brigandine", "parts": ["DarkRanger_Chest3/Mesh"]},
			{"from": 4, "name": "Seraph Brigandine", "parts": ["DarkRanger_Chest4/Mesh"]},
		],
		"legs": [
			{"from": 0, "name": "Hide Chaps", "parts": ["DarkRanger_Legs0/Mesh"]},
			{"from": 1, "name": "Leather Chaps", "parts": ["DarkRanger_Legs1/Mesh"]},
			{"from": 2, "name": "Greaved Chaps", "parts": ["DarkRanger_Legs2/Mesh"]},
			{"from": 3, "name": "Dread Chaps", "parts": ["DarkRanger_Legs3/Mesh"]},
			{"from": 4, "name": "Seraph Chaps", "parts": ["DarkRanger_Legs4/Mesh"]},
		],
		# Our own offhands, one per set (tools/art/make_dark_offhands.py).
		"trinket": [
			{"from": 0, "name": "Quiver", "model": "ranger_off_0.gltf"},
			{"from": 1, "name": "Banded Quiver", "model": "ranger_off_1.gltf"},
			{"from": 2, "name": "Star Quiver", "model": "ranger_off_2.gltf"},
			{"from": 3, "name": "Dread Quiver", "model": "ranger_off_3.gltf"},
			{"from": 4, "name": "Seraph Quiver", "model": "ranger_off_4.gltf"},
		],
	},
}

## Boss sets wear their own look, whatever the metal: one per hero and slot.
## `dye` replaces the metal's color (alpha = how much), `accent` is what the
## grade glows in, `grade` the least finish a set piece shows, `icon` the tint
## of its icon. Pieces name the look: "Cobalt Blackguard Helm".
const SET_LOOKS := {
	# The Barrow King's bones: bleached bone and grave-green fire.
	"gravemaw": {"dye": Color(1.0, 0.97, 0.86, 0.85), "accent": Color(0.4, 1.0, 0.55), "icon": Color(0.85, 0.95, 0.8), "grade": Vector4(0.35, 0.3, 0.45, 0.0), "cls": {
		"knight": {
			"weapon": {"name": "Barrow Blade", "model": "Skeleton_Blade.gltf", "scale": 1.1, "icon": "dripping-sword"},
			"helm": {"name": "Barrow Helm", "parts": ["DarkKnight_Helm3/Mesh"], "hood": true},
			"chest": {"name": "Barrow Plate", "parts": ["DarkKnight_Chest3/Mesh"]},
			"legs": {"name": "Barrow Greaves", "parts": ["DarkKnight_Legs3/Mesh"]},
			"trinket": {"name": "Skull Shield", "model": "knight_off_3.gltf", "icon": "skull-crossed-bones"},
		},
		"barbarian": {
			"weapon": {"name": "Gravecleaver", "model": "Skeleton_Axe.gltf", "icon": "crossed-axes"},
			"helm": {"name": "Barrow Horns", "parts": ["DarkBarbarian_Helm3/Mesh"], "hood": true},
			"chest": {"name": "Ribcage Harness", "parts": ["DarkBarbarian_Chest3/Mesh"]},
			"legs": {"name": "Barrow Legs", "parts": ["DarkBarbarian_Legs3/Mesh"]},
			"trinket": {"name": "Bone Shield", "model": "barb_off_3.gltf"},
		},
		"mage": {
			"weapon": {"name": "Bone Staff", "model": "kit:bone_staff"},
			"helm": {"name": "Gravecaller Hat", "parts": ["DarkMage_Helm3/Mesh"], "hood": true},
			"chest": {"name": "Gravecaller Robe", "parts": ["DarkMage_Chest3/Mesh"]},
			"legs": {"name": "Gravecaller Skirt", "parts": ["DarkMage_Legs3/Mesh"]},
			"trinket": {"name": "Skull Orb", "model": "mage_off_3.gltf", "icon": "crowned-skull"},
		},
		"rogue": {
			"weapon": {"name": "Barrow Shiv", "model": "Skeleton_Blade.gltf"},
			"helm": {"name": "Barrow Cowl", "parts": ["DarkRogue_Helm3/Mesh"], "hood": true},
			"chest": {"name": "Barrow Garb", "parts": ["DarkRogue_Chest3/Mesh"]},
			"legs": {"name": "Barrow Shiv Legs", "parts": ["DarkRogue_Legs3/Mesh"]},
			"trinket": {"name": "Barrow Shiv Offhand", "model": "rogue_off_3.gltf"},
		},
		"ranger": {
			"weapon": {"name": "Bone Bow", "model": "bow_withString.gltf", "scale": 1.15},
			"helm": {"name": "Barrow Hood", "parts": ["DarkRanger_Helm3/Mesh"], "hood": true},
			"chest": {"name": "Barrow Hide", "parts": ["DarkRanger_Chest3/Mesh"]},
			"legs": {"name": "Barrow Chaps", "parts": ["DarkRanger_Legs3/Mesh"]},
			"trinket": {"name": "Bone Quiver", "model": "ranger_off_3.gltf"},
		},
	}},
	# The Crypt Queen's: blackened plate and robes with violet fire in the seams.
	"hexer": {"dye": Color(0.045, 0.04, 0.06, 1.0), "accent": Color(0.75, 0.35, 1.0), "icon": Color(0.78, 0.6, 1.0), "grade": Vector4(0.75, 0.25, 0.55, 0.0), "cls": {
		"knight": {
			"weapon": {"name": "Blackguard Blade", "model": "sword_E.gltf", "scale": 0.66, "icon": "dripping-sword"},
			"helm": {"name": "Blackguard Helm", "parts": ["DarkKnight_Helm2/Mesh"], "hood": true},
			"chest": {"name": "Blackguard Plate", "parts": ["DarkKnight_Chest2/Mesh"]},
			"legs": {"name": "Blackguard Legs", "parts": ["DarkKnight_Legs2/Mesh"]},
			"trinket": {"name": "Blackguard Shield", "model": "knight_off_2.gltf"},
		},
		"barbarian": {
			"weapon": {"name": "Dread Axe", "model": "axe_B.gltf", "scale": 1.1, "icon": "crossed-axes"},
			"helm": {"name": "Dread Horns", "parts": ["DarkBarbarian_Helm2/Mesh"], "hood": true},
			"chest": {"name": "Dread Hide", "parts": ["DarkBarbarian_Chest2/Mesh"]},
			"legs": {"name": "Dread Legs", "parts": ["DarkBarbarian_Legs2/Mesh"]},
			"trinket": {"name": "Dread Shield", "model": "barb_off_2.gltf"},
		},
		"mage": {
			"weapon": {"name": "Deathlight Staff", "model": "kit:deathlight"},
			"helm": {"name": "Necromancer Hat", "parts": ["DarkMage_Helm2/Mesh"], "hood": true},
			"chest": {"name": "Necromancer Robe", "parts": ["DarkMage_Chest2/Mesh"]},
			"legs": {"name": "Necromancer Skirt", "parts": ["DarkMage_Legs2/Mesh"]},
			"trinket": {"name": "Phylactery", "model": "mage_off_2.gltf", "icon": "gems"},
		},
		"rogue": {
			"weapon": {"name": "Hexfang", "model": "dagger_B.gltf"},
			"helm": {"name": "Hex Cowl", "parts": ["DarkRogue_Helm2/Mesh"], "hood": true},
			"chest": {"name": "Hex Garb", "parts": ["DarkRogue_Chest2/Mesh"]},
			"legs": {"name": "Hexfang Legs", "parts": ["DarkRogue_Legs2/Mesh"]},
			"trinket": {"name": "Hexfang Offhand", "model": "rogue_off_2.gltf"},
		},
		"ranger": {
			"weapon": {"name": "Shade Bow", "model": "kit:recurve", "scale": 1.15},
			"helm": {"name": "Shade Hood", "parts": ["DarkRanger_Helm2/Mesh"], "hood": true},
			"chest": {"name": "Shade Garb", "parts": ["DarkRanger_Chest2/Mesh"]},
			"legs": {"name": "Shade Legs", "parts": ["DarkRanger_Legs2/Mesh"]},
			"trinket": {"name": "Shade Quiver", "model": "ranger_off_2.gltf"},
		},
	}},
	# The Thornmother's: living bark with green sap in the grain.
	"thorn": {"dye": Color(0.36, 0.25, 0.14, 0.85), "accent": Color(0.55, 1.0, 0.3), "icon": Color(0.7, 0.95, 0.5), "grade": Vector4(0.1, 0.2, 0.6, 0.0), "cls": {
		"knight": {
			"weapon": {"name": "Thornblade", "model": "sword_C.gltf", "scale": 1.0},
			"helm": {"name": "Grove Helm", "parts": ["DarkKnight_Helm1/Mesh"], "hood": true},
			"chest": {"name": "Barkplate", "parts": ["DarkKnight_Chest4/Mesh"]},
			"legs": {"name": "Bark Greaves", "parts": ["DarkKnight_Legs1/Mesh"]},
			"trinket": {"name": "Grove Shield", "model": "knight_off_1.gltf"},
		},
		"barbarian": {
			"weapon": {"name": "Root Club", "model": "hammer_C.gltf", "scale": 1.15, "icon": "bone-gnawer"},
			"helm": {"name": "Bear Mask", "parts": ["DarkBarbarian_Helm1/Mesh"], "hood": true},
			"chest": {"name": "Bark Hide", "parts": ["DarkBarbarian_Chest4/Mesh"]},
			"legs": {"name": "Bark Legs", "parts": ["DarkBarbarian_Legs1/Mesh"]},
			"trinket": {"name": "Bark Shield", "model": "barb_off_1.gltf"},
		},
		"mage": {
			"weapon": {"name": "Grove Lantern", "model": "kit:lantern_staff"},
			"helm": {"name": "Druid Cowl", "parts": ["DarkMage_Helm1/Mesh"], "hood": true},
			"chest": {"name": "Druid Robe", "parts": ["DarkMage_Chest4/Mesh"]},
			"legs": {"name": "Druid Skirt", "parts": ["DarkMage_Legs1/Mesh"]},
			"trinket": {"name": "Seed Tome", "model": "mage_off_1.gltf"},
		},
		"rogue": {
			"weapon": {"name": "Thorn Shiv", "model": "dagger_A.gltf"},
			"helm": {"name": "Grove Cowl", "parts": ["DarkRogue_Helm1/Mesh"], "hood": true},
			"chest": {"name": "Grove Garb", "parts": ["DarkRogue_Chest4/Mesh"]},
			"legs": {"name": "Thorn Shiv Legs", "parts": ["DarkRogue_Legs1/Mesh"]},
			"trinket": {"name": "Thorn Shiv Offhand", "model": "rogue_off_1.gltf"},
		},
		"ranger": {
			"weapon": {"name": "Thornbow", "model": "kit:hunting_bow", "scale": 1.15},
			"helm": {"name": "Grove Hood", "parts": ["DarkRanger_Helm1/Mesh"], "hood": true},
			"chest": {"name": "Grove Garb", "parts": ["DarkRanger_Chest4/Mesh"]},
			"legs": {"name": "Grove Chaps", "parts": ["DarkRanger_Legs1/Mesh"]},
			"trinket": {"name": "Grove Quiver", "model": "ranger_off_1.gltf"},
		},
	}},
}

## Weapons by family (DB.FAMILIES): one model per set, Gravedigger first,
## built by tools/art/make_barbarian_arms.py. They carry their own colors, so
## no dye goes over them; a boss set's piece keeps its family's shape.
const FAMILY_PREFIX := {"barbarian": "barb", "knight": "knight", "ranger": "ranger", "mage": "mage", "rogue": "rogue"}
## How big a family sits in the hand (1 when not listed).
const FAMILY_SCALE := {"twin": 1.1, "halberd": 0.72, "throwing": 1.1, "rapier": 0.9, "nightblade": 0.9}


## A family weapon's look in a set: <prefix>_<family>_<set>.gltf.
static func family_look(fam: String, mat: int) -> Dictionary:
	var fd: Dictionary = DB.FAMILIES[fam]
	return {"name": fd["name"], "model": "%s_%s_%d.gltf" % [FAMILY_PREFIX[fd["hero"]], fam, clampi(mat, 0, TIERS - 1)], "scale": float(FAMILY_SCALE.get(fam, 1.0))}

## Where "P:" props live (built by tools/art/make_barbarian_armor.py).
const GEAR_DIR := "res://assets/kaykit/gear/"
## Rigid parts made for the skeletons' taller skulls sit lower on a living head.
const PART_NUDGE := {"Skeleton_Mage/Hat": Vector3(0, -0.13, 0)}

## Uniques with a model of their own, in their own colors, so no dye goes
## over them (tools/art/make_dark_uniques.py, make_unique_arms.py).
const UNIQUE_LOOKS := {
	"crown": {"parts": ["DarkUnique_crown/Mesh"], "hood": true},
	"greaves": {"parts": ["DarkUnique_greaves/Mesh"]},
	"hoardplate": {"parts": ["DarkUnique_hoardplate/Mesh"]},
	"cinder_plate": {"parts": ["DarkUnique_cinder_plate/Mesh"]},
	"shroud": {"parts": ["DarkUnique_shroud/Mesh"]},
	"rime_cowl": {"parts": ["DarkUnique_rime_cowl/Mesh"], "hood": true},
	"gown": {"parts": ["DarkUnique_gown/Mesh"]},
	"rime_robe": {"parts": ["DarkUnique_rime_robe/Mesh"]},
	"barkplate": {"parts": ["DarkUnique_barkplate/Mesh"]},
	"cinder_boots": {"parts": ["DarkUnique_cinder_boots/Mesh"]},
	"cleaver": {"model": "uniq_cleaver.gltf"},
	"scepter": {"model": "uniq_scepter.gltf"},
	"thornbow": {"model": "uniq_thornbow.gltf"},
	"gilded_fang": {"model": "uniq_gilded_fang.gltf"},
	"rime_maul": {"model": "uniq_rime_maul.gltf"},
	"cinder_maul": {"model": "uniq_cinder_maul.gltf"},
	"emberheart": {"model": "uniq_emberheart.gltf"},
	"seedheart": {"model": "uniq_seedheart.gltf"},
}

## Weapons and offhands put together from several KayKit props: "kit:name".
## Each part is [file under assets/kaykit, position, rotation (degrees), scale
## (a number, or per axis before the rotation)]; the origin is the grip.
const KITS := {
	# A long bone for a shaft, a skull on top.
	"bone_staff": [
		["graveyard/bone_C.gltf", Vector3(0, 0.12, 0), Vector3(0, 0, 90), Vector3(1.55, 0.5, 0.5)],
		["graveyard/skull.gltf", Vector3(0, 0.84, 0), Vector3(0, 0, 0), 0.36],
		["graveyard/bone_A.gltf", Vector3(0, 0.8, 0.02), Vector3(0, 0, 0), Vector3(0.6, 0.45, 0.45)],
	],
	# A bone shaft crowned with a skull that holds a burning candle.
	"deathlight": [
		["graveyard/bone_C.gltf", Vector3(0, 0.12, 0), Vector3(0, 0, 90), Vector3(1.55, 0.5, 0.5)],
		["graveyard/skull_candle.gltf", Vector3(0, 0.82, 0), Vector3(0, 0, 0), 0.4],
	],
	# A staff with a lantern swinging from a hook at the top.
	"lantern_staff": [
		["weapons/staff.gltf", Vector3.ZERO, Vector3.ZERO, 1.0],
		["graveyard/lantern_hanging.gltf", Vector3(0.22, 1.2, 0), Vector3.ZERO, 0.38],
	],
	"bone_club": [
		["graveyard/bone_A.gltf", Vector3(0, 0.42, 0), Vector3(0, 0, 90), Vector3(1.7, 1.2, 1.2)],
	],
	"skull_orb": [
		["graveyard/skull.gltf", Vector3(0, -0.1, 0.05), Vector3(0, 180, 0), 0.3],
	],
	"candelabra": [
		["dungeon/candle_triple.gltf", Vector3(-0.05, -0.05, 0), Vector3.ZERO, 0.6],
	],
	"phylactery": [
		["dungeon/bottle_A_green.gltf", Vector3(0, -0.1, 0.04), Vector3.ZERO, 0.42],
	],
	# Weapons Bits bows lie along X; the hero's bow poses expect the old bows' Z.
	"hunting_bow": [
		["weapons/bow_A_withString.gltf", Vector3.ZERO, Vector3(0, 90, 0), 1.0],
	],
	"recurve": [
		["weapons/bow_B_withString.gltf", Vector3.ZERO, Vector3(0, 90, 0), 1.0],
	],
}

## Icon per hero and slot (game-icons names), tinted by the material's dye.
const ICONS := {
	"knight": {"weapon": "broadsword", "helm": "visored-helm", "chest": "breastplate", "legs": "leg-armor", "trinket": "shield"},
	"barbarian": {"weapon": "battle-axe", "helm": "horned-helm", "chest": "leather-vest", "legs": "trousers", "trinket": "checked-shield"},
	"mage": {"weapon": "wizard-staff", "helm": "pointy-hat", "chest": "robe", "legs": "boots", "trinket": "book-cover"},
	"rogue": {"weapon": "cloak-dagger", "helm": "hood", "chest": "leather-vest", "legs": "boots", "trinket": "cloak-dagger"},
	"ranger": {"weapon": "pocket-bow", "helm": "hood", "chest": "leather-vest", "legs": "boots", "trinket": "arrow-flights"},
}


static func icon(cls: String, slot: String) -> String:
	return ICONS[cls][slot]


## An item's icon: a unique's own, else its look's, else the class-and-slot one.
static func item_icon(it: Dictionary) -> String:
	var u := str(it.get("unique", ""))
	if u != "" and DB.UNIQUES.has(u):
		return DB.UNIQUES[u]["icon"]
	if it.has("cls") and str(it["slot"]) in DB.SLOTS:
		var pc := piece(it)
		if pc.has("icon"):
			return str(pc["icon"])
	return icon(str(it.get("cls", "knight")), str(it["slot"]))


## Item icon tint: the material's dye (a set's own tint), lifted so it reads
## on dark frames.
static func item_color(it: Dictionary) -> Color:
	var u := str(it.get("unique", ""))
	if u != "" and DB.UNIQUES.has(u) and DB.UNIQUES[u].has("dye"):
		return Color(DB.UNIQUES[u]["dye"]).lightened(0.25)
	var sl := set_look(it)
	if not sl.is_empty():
		return sl["icon"]
	return dye(str(it.get("cls", "knight")), int(it.get("mat", 0))).lightened(0.2)


## The skill that gates a slot for a hero.
static func skill_for(cls: String, slot: String) -> String:
	var line: Dictionary = LINES[cls]
	return line["weapon_skill"] if slot == "weapon" else line["armor_skill"]


## The skill level a piece needs: its set's, or its weapon family's if higher.
static func req_for(it: Dictionary) -> int:
	var need := int(REQ[clampi(int(it.get("mat", 0)), 0, TIERS - 1)])
	var fam := str(it.get("fam", ""))
	if str(it.get("slot", "")) == "weapon" and DB.FAMILIES.has(fam):
		need = maxi(need, int(DB.FAMILIES[fam]["level"]))
	return need


## The stage of `slot` for material tier `mat`.
static func stage(cls: String, slot: String, mat: int) -> Dictionary:
	var out: Dictionary = {}
	for st: Dictionary in LINES[cls][slot]:
		if int(st["from"]) <= mat:
			out = st
	return out


## The set a piece belongs to: its tag, or its unique's boss ("" for none).
static func set_of(it: Dictionary) -> String:
	if it.has("set"):
		return str(it["set"])
	var u := str(it.get("unique", ""))
	if u != "" and DB.UNIQUES.has(u):
		return str(DB.SOURCE_BOSS.get(DB.UNIQUES[u]["source"], ""))
	return ""


## A set piece's look entry ({} for none).
static func set_look(it: Dictionary) -> Dictionary:
	var sl: Dictionary = SET_LOOKS.get(set_of(it), {})
	if sl.is_empty() or not sl["cls"].has(str(it.get("cls", ""))):
		return {}
	return sl


## What a piece is: its stage, then its rolled alternative, then its set's
## look, then its unique's own model. Every later one replaces the shape. A
## family weapon is its family's look for its set, whatever else it is.
static func piece(it: Dictionary) -> Dictionary:
	var cls := str(it.get("cls", "knight"))
	var slot := str(it["slot"])
	var fam := str(it.get("fam", ""))
	if slot == "weapon" and DB.FAMILIES.has(fam):
		var fl := family_look(fam, int(it.get("mat", 0)))
		fl["icon"] = DB.FAMILIES[fam]["icon"]
		if UNIQUE_LOOKS.has(str(it.get("unique", ""))):
			_over(fl, UNIQUE_LOOKS[str(it["unique"])])
		return fl
	var st := stage(cls, slot, int(it.get("mat", 0))).duplicate()
	var alts: Array = st.get("alts", [])
	var pick := posmod(int(it.get("look", 0)), alts.size() + 1)
	if pick > 0:
		_over(st, alts[pick - 1])
	var sl := set_look(it)
	if not sl.is_empty():
		_over(st, sl["cls"][cls][slot])
	var u := str(it.get("unique", ""))
	if UNIQUE_LOOKS.has(u):
		_over(st, UNIQUE_LOOKS[u])
	st.erase("alts")
	return st


static func _over(st: Dictionary, o: Dictionary) -> void:
	if o.has("parts") or o.has("model"):
		for k in ["parts", "model", "scale", "hood", "icon"]:
			st.erase(k)
	st.merge(o, true)


static func kind(cls: String) -> String:
	return {"mage": "cloth", "ranger": "hide"}.get(cls, "metal")


## The shader grade of a worn piece. Legendaries and uniques shimmer at least
## a little whatever their metal.
static func grade(it: Dictionary) -> Vector4:
	if it.is_empty():
		return Vector4.ZERO
	var g: Vector4 = GRADES[kind(str(it.get("cls", "knight")))][clampi(int(it.get("mat", 0)), 0, TIERS - 1)]
	var sl := set_look(it)
	if not sl.is_empty():
		var m: Vector4 = sl["grade"]
		g = Vector4(maxf(g.x, m.x), maxf(g.y, m.y), maxf(g.z, m.z), maxf(g.w, m.w))
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
	var sl := set_look(it)
	if u == "" and not sl.is_empty():
		return sl["accent"]
	if u == "" and SET_ACCENT.has(mat):
		return SET_ACCENT[mat]
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


static func material_name(_cls: String, mat: int) -> String:
	return SET_NAMES[clampi(mat, 0, TIERS - 1)]


static func dye(cls: String, mat: int) -> Color:
	return LINES[cls]["dye"][clampi(mat, 0, TIERS - 1)]


## "Bloodiron Cuirass" for a hero's fourth-set chest; "Bloodiron Horned Helm"
## for an alternative, "Bloodiron Blackguard Helm" for a boss set piece.
static func base_name(it: Dictionary) -> String:
	var cls := str(it["cls"])
	return "%s %s" % [material_name(cls, int(it.get("mat", 0))), piece(it)["name"]]


## Look of an item: {parts, model, dye (rgb + mix), scale, hood}. Uniques may
## override the dye with their own color.
static func look(it: Dictionary) -> Dictionary:
	var cls: String = it["cls"]
	var slot: String = it["slot"]
	var mat := int(it.get("mat", 0))
	var st := piece(it)
	var c: Color = dye(cls, mat)
	var u := str(it.get("unique", ""))
	var amount := 0.5 if slot in ["weapon", "trinket"] else 0.72
	var sl := set_look(it)
	if not sl.is_empty():
		c = sl["dye"]
		amount = c.a
	if slot == "weapon" and DB.FAMILIES.has(str(it.get("fam", ""))):
		amount = 0.0
	if u != "" and DB.UNIQUES[u].has("dye"):
		c = DB.UNIQUES[u]["dye"]
		amount = 0.0 if UNIQUE_LOOKS.has(u) else 0.8
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


## Rolls the set of a drop: harder content drops better sets. Sets are wide
## steps, so a drop is at most one set above its base.
## `bonus` is zone/depth/boss shift in sets.
## `base_mat` is the tier's set (DB.TIERS[i]["mat"]).
static func roll_mat(base_mat: int, bonus: int, rng: RandomNumberGenerator) -> int:
	var base := base_mat + bonus
	var r := rng.randf()
	var shift := -1 if r < 0.22 else (0 if r < 0.72 else 1)
	return clampi(base + shift, 0, TIERS - 1)


# --- How it is held ------------------------------------------------------

## How each family's weapon sits in the hand, where KayKit's own grip (the
## model's origin on the hand slot, its length along +Y) doesn't suit it.
## `rot` turns the model in the hand (degrees), `at` moves it (model units)
## so the hand closes on the right spot; `rot_l` is the left of a pair.
const HOLDS := {
	# Staves stand up beside the mage, foot near the ground, head overhead.
	"staff": {"rot": Vector3(15, 0, 70), "at": Vector3(0, 0.35, 0)},
	"skullstaff": {"rot": Vector3(15, 0, 70), "at": Vector3(0, 0.35, 0)},
	"soulstaff": {"rot": Vector3(15, 0, 70), "at": Vector3(0, 0.35, 0)},
	# The tome floats open at the mage's right shoulder; the hand casts from it.
	"tome": {"bone": "chest", "rot": Vector3(-20, -35, 0), "at": Vector3(-0.62, 0.05, 0.3)},
	# KayKit crossbows point back down the arm.
	"crossbow": {"rot": Vector3(0, 180, 0)},
	"repeater": {"rot": Vector3(0, 180, 0), "rot_l": Vector3(0, 180, 0)},
	# Take both hands: no shield with them (Game.two_hands). Pairs (twin
	# axes, repeaters) fill both hands too.
	"warhammer": {"two_hand": true},
	"axe": {"two_hand": true},
	"maul": {"two_hand": true},
	"scythe": {"two_hand": true},
	"halberd": {"two_hand": true},
}

## Offhands by model, where the line's own bone doesn't suit them: a book
## floats at the mage's left shoulder rather than through the hand.
const OFF_HOLDS := {
	"spellbook_open.gltf": {"bone": "chest", "rot": Vector3(-20, 35, 0), "at": Vector3(0.55, 0.15, 0.4), "scale": 0.8},
	"spellbook_closed.gltf": {"bone": "chest", "rot": Vector3(-20, 35, 0), "at": Vector3(0.55, 0.15, 0.4)},
	"mage_off_0.gltf": {"bone": "chest", "rot": Vector3(-20, 35, 0), "at": Vector3(0.55, 0.15, 0.4)},
	"mage_off_1.gltf": {"bone": "chest", "rot": Vector3(-20, 35, 0), "at": Vector3(0.55, 0.15, 0.4)},
	"mage_off_2.gltf": {"bone": "chest", "rot": Vector3(-20, 35, 0), "at": Vector3(0.55, 0.15, 0.4)},
	"mage_off_3.gltf": {"bone": "chest", "rot": Vector3(-20, 35, 0), "at": Vector3(0.55, 0.15, 0.4)},
	"mage_off_4.gltf": {"bone": "chest", "rot": Vector3(-20, 35, 0), "at": Vector3(0.55, 0.15, 0.4)},
	# These shields face the arm, and the plank one hangs low off the hand.
	"shield_A.gltf": {"rot": Vector3(0, 180, 0), "at": Vector3(0, 0.3, 0)},
	"shield_B.gltf": {"rot": Vector3(0, 180, 0)},
}

## A shield carried on the back: flat to the shoulders, face out.
const BACK_XF := Transform3D(Basis(Vector3.UP, PI), Vector3(0, -0.05, -0.3))


## How a hero holds a weapon of family `fam`: the hand bone, and where the
## model sits in it (`xf`, and `xf_l` for the second of a pair).
static func weapon_hold(hero_id: String, fam: String) -> Dictionary:
	var d: Dictionary = DB.HEROES[hero_id]
	var fd: Dictionary = DB.FAMILIES.get(fam, {})
	# A family may hold its weapon in the other hand (a crossbow, knives).
	var bone := str(fd.get("bone", d["weapon_bone"]))
	# KayKit bows face the string away from the hand that holds them; turned
	# half round, the string comes back to the archer as in the aim pose.
	var xf := Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO) if str(d["style"]) == "bow" and not fd.has("bone") else Transform3D.IDENTITY
	var g: Dictionary = HOLDS.get(fam, {})
	bone = str(g.get("bone", bone))
	if g.has("rot") or g.has("at"):
		xf = _grip_xf(g.get("rot", Vector3.ZERO), g.get("at", Vector3.ZERO))
	var xf_l := xf
	if g.has("rot_l"):
		xf_l = _grip_xf(g["rot_l"], g.get("at", Vector3.ZERO))
	return {"bone": bone, "xf": xf, "xf_l": xf_l, "dual": bool(fd.get("dual", false))}


## A grip as rotation (degrees, applied X then Y then Z) and an offset of the
## model in the hand, so the hand holds it where it should (a staff mid-shaft).
static func _grip_xf(rot: Vector3, at: Vector3) -> Transform3D:
	var b := Basis.from_euler(rot * PI / 180.0)
	return Transform3D(b, b * at)


## Whether family `fam` takes both hands, leaving none for a shield.
static func two_handed(_hero_id: String, fam: String) -> bool:
	return bool(HOLDS.get(fam, {}).get("two_hand", false)) or bool(DB.FAMILIES.get(fam, {}).get("dual", false))


## Where a hero carries its offhand `model` (a shield, a book, a quiver).
static func offhand_hold(hero_id: String, model: String) -> Dictionary:
	var bone := str(LINES[hero_id]["offhand_bone"])
	var xf := Transform3D.IDENTITY
	var g: Dictionary = OFF_HOLDS.get(model, {})
	if g.has("rot") or g.has("at"):
		xf = _grip_xf(g.get("rot", Vector3.ZERO), g.get("at", Vector3.ZERO))
	bone = str(g.get("bone", bone))
	if bone == "back":
		bone = "chest"
		xf = BACK_XF
	return {"bone": bone, "xf": xf, "scale": float(g.get("scale", 1.0))}


## The hero's idle, run, attack and super clips with weapon family `fam`.
static func anims(hero_id: String, fam: String) -> Dictionary:
	var a: Dictionary = DB.HEROES[hero_id]["anim"].duplicate(true)
	var fd: Dictionary = DB.FAMILIES.get(fam, {})
	if not fd.is_empty():
		a["attack"] = fd["clips"]
		a.merge(fd.get("anims", {}), true)
	return a
