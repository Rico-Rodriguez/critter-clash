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
			{"from": 0, "name": "Shortsword", "model": "sword_1handed.gltf", "alts": [
				{"name": "War Axe", "model": "axe_1handed.gltf", "scale": 1.2, "icon": "battle-axe"},
			]},
			{"from": 3, "name": "Longsword", "model": "sword_2handed.gltf", "alts": [
				{"name": "Battleaxe", "model": "axe_2handed.gltf", "scale": 0.9, "icon": "battle-axe"},
			]},
			{"from": 5, "name": "Greatsword", "model": "sword_2handed_color.gltf", "scale": 1.08},
		],
		"helm": [
			{"from": 0, "name": "Med Helm", "parts": ["Knight/Helmet"]},
			{"from": 2, "name": "Full Helm", "parts": ["Knight/Helmet", "Knight/HelmetVisor"], "alts": [
				{"name": "Horned Helm", "parts": ["Skeleton_Warrior/Helmet"]},
			]},
		],
		"chest": [
			{"from": 0, "name": "Chainbody", "parts": ["T:Ranger"]},
			{"from": 2, "name": "Platebody", "parts": ["T:Knight"]},
			{"from": 4, "name": "Platebody", "parts": ["T:Knight", "Rogue_Hooded/Cape"], "alts": [
				{"name": "Platebody", "parts": ["T:Knight", "Skeleton_Warrior/Cloak"]},
			]},
			{"from": 5, "name": "Platebody", "parts": ["T:Knight", "Knight/Cape"]},
		],
		"legs": [
			{"from": 0, "name": "Chainlegs", "parts": ["L:Ranger"]},
			{"from": 2, "name": "Platelegs", "parts": ["L:Knight"]},
		],
		"trinket": [
			{"from": 0, "name": "Buckler", "model": "shield_round.gltf"},
			{"from": 2, "name": "Kite Shield", "model": "shield_badge.gltf", "alts": [
				{"name": "Heater Shield", "model": "shield_badge_color.gltf"},
				{"name": "Tower Shield", "model": "shield_square.gltf"},
			]},
			{"from": 4, "name": "Spiked Shield", "model": "shield_spikes.gltf", "alts": [
				{"name": "Heraldic Shield", "model": "shield_round_color.gltf"},
			]},
			{"from": 6, "name": "Dragon Shield", "model": "shield_square_color.gltf"},
		],
	},
	"barbarian": {
		"names": METAL_NAMES, "dye": METAL, "weapon_skill": "attack", "armor_skill": "defence",
		"starter": "axe_1handed.gltf", "offhand_bone": "back",
		"weapon": [
			{"from": 0, "name": "Hatchet", "model": "axe_1handed.gltf", "scale": 1.35, "alts": [
				{"name": "Cudgel", "model": "kit:bone_club", "icon": "bone-gnawer"},
			]},
			{"from": 2, "name": "Battleaxe", "model": "axe_2handed.gltf", "alts": [
				{"name": "Greatsword", "model": "sword_2handed.gltf", "scale": 1.1, "icon": "broadsword"},
			]},
			{"from": 5, "name": "Great Axe", "model": "axe_2handed.gltf", "scale": 1.18},
		],
		"helm": [
			{"from": 0, "name": "Horned Cap", "parts": ["Skeleton_Warrior/Helmet"]},
			{"from": 3, "name": "Bear Helm", "parts": ["Barbarian/BearHat"], "alts": [
				{"name": "Great Helm", "parts": ["Knight/Helmet"]},
			]},
		],
		"chest": [
			{"from": 0, "name": "Hide Vest", "parts": ["T:Ranger"]},
			{"from": 1, "name": "Fur Armour", "parts": ["T:Barbarian"]},
			{"from": 4, "name": "Fur Armour", "parts": ["T:Barbarian", "Ranger/Cape"]},
			{"from": 5, "name": "Warlord Armour", "parts": ["T:Barbarian", "Knight/Cape"], "alts": [
				{"name": "Warlord Armour", "parts": ["T:Barbarian", "Skeleton_Warrior/Cloak"]},
			]},
		],
		"legs": [
			{"from": 0, "name": "Hide Chaps", "parts": ["L:Ranger"]},
			{"from": 1, "name": "Fur Legs", "parts": ["L:Barbarian"]},
		],
		"trinket": [
			{"from": 0, "name": "Round Shield", "model": "shield_round_barbarian.gltf", "alts": [
				{"name": "Painted Shield", "model": "shield_round_color.gltf"},
			]},
			{"from": 4, "name": "Spiked Shield", "model": "shield_spikes.gltf", "alts": [
				{"name": "Boss Shield", "model": "Skeleton_Shield_Small_B.gltf", "scale": 1.2},
			]},
		],
	},
	"mage": {
		"names": CLOTH_NAMES, "dye": CLOTH, "weapon_skill": "magic", "armor_skill": "magic",
		"starter": "wand.gltf", "offhand_bone": "handslot.l",
		"weapon": [
			{"from": 0, "name": "Wand", "model": "wand.gltf", "scale": 1.15},
			{"from": 2, "name": "Staff", "model": "staff.gltf", "alts": [
				{"name": "Lantern Staff", "model": "kit:lantern_staff"},
			]},
			{"from": 4, "name": "Bone Staff", "model": "kit:bone_staff"},
			{"from": 5, "name": "Skull Staff", "model": "Skeleton_Staff.gltf", "scale": 1.1, "alts": [
				{"name": "Deathlight Staff", "model": "kit:deathlight"},
			]},
		],
		"helm": [
			{"from": 0, "name": "Hat", "parts": ["Mage/Hat"], "alts": [
				{"name": "Cowl", "parts": ["Rogue_Hooded/Head"], "hood": true},
			]},
			{"from": 3, "name": "Hat", "parts": ["Mage/Hat"], "alts": [
				{"name": "Witch Hat", "parts": ["Skeleton_Mage/Hat"]},
			]},
		],
		"chest": [
			{"from": 0, "name": "Robe Top", "parts": ["T:Ranger"]},
			{"from": 1, "name": "Robe Top", "parts": ["T:Mage"]},
			{"from": 3, "name": "Robe Top", "parts": ["T:Mage"], "alts": [
				{"name": "Ragged Robe", "parts": ["Skeleton_Mage/Body", "Mage/ArmLeft", "Mage/ArmRight"]},
			]},
			{"from": 4, "name": "Robe Top", "parts": ["T:Mage", "Mage/Cape"], "alts": [
				{"name": "Ragged Robe", "parts": ["Skeleton_Mage/Body", "Mage/ArmLeft", "Mage/ArmRight", "Skeleton_Minion/Cloak"]},
			]},
		],
		"legs": [
			{"from": 0, "name": "Robe Bottom", "parts": ["L:Ranger"]},
			{"from": 1, "name": "Robe Bottom", "parts": ["L:Mage"]},
		],
		"trinket": [
			{"from": 0, "name": "Tome", "model": "spellbook_closed.gltf"},
			{"from": 3, "name": "Grimoire", "model": "spellbook_open.gltf", "alts": [
				{"name": "Skull Orb", "model": "kit:skull_orb", "icon": "crowned-skull"},
			]},
			{"from": 5, "name": "Grimoire", "model": "spellbook_open.gltf", "alts": [
				{"name": "Candelabra", "model": "kit:candelabra", "icon": "flame"},
				{"name": "Phylactery", "model": "kit:phylactery", "icon": "gems"},
			]},
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
			{"from": 3, "name": "Hood", "parts": ["Rogue_Hooded/Head"], "hood": true, "alts": [
				{"name": "Mask", "parts": ["Rogue_Hooded/Mask", "Mage/Hat"]},
			]},
		],
		"chest": [
			{"from": 0, "name": "Body", "parts": ["T:Ranger"]},
			{"from": 3, "name": "Body", "parts": ["T:Rogue_Hooded"]},
			{"from": 5, "name": "Body", "parts": ["T:Rogue_Hooded", "Ranger/Cape"], "alts": [
				{"name": "Body", "parts": ["T:Rogue_Hooded", "Rogue_Hooded/Cape"]},
			]},
		],
		"legs": [
			{"from": 0, "name": "Chaps", "parts": ["L:Ranger"]},
			{"from": 3, "name": "Chaps", "parts": ["L:Rogue_Hooded"]},
		],
		"trinket": [
			{"from": 0, "name": "Quiver", "parts": ["Ranger/Quiver"]},
			{"from": 4, "name": "Quiver", "parts": ["Ranger/Quiver"], "alts": [
				{"name": "Bone Quiver", "model": "Skeleton_Quiver.gltf"},
			]},
		],
	},
}

## Boss sets wear their own look, whatever the metal: one per hero and slot.
## `dye` replaces the metal's color (alpha = how much), `accent` is what the
## grade glows in, `grade` the least finish a set piece shows, `icon` the tint
## of its icon. Pieces name the look: "Mithril Blackguard Helm".
const SET_LOOKS := {
	# The Barrow King's bones: bleached bone and grave-green fire.
	"gravemaw": {"dye": Color(1.0, 0.97, 0.86, 0.85), "accent": Color(0.4, 1.0, 0.55), "icon": Color(0.85, 0.95, 0.8), "grade": Vector4(0.35, 0.3, 0.45, 0.0), "cls": {
		"knight": {
			"weapon": {"name": "Barrow Blade", "model": "Skeleton_Blade.gltf", "scale": 1.1, "icon": "dripping-sword"},
			"helm": {"name": "Barrow Helm", "parts": ["Skeleton_Warrior/Helmet"]},
			"chest": {"name": "Barrow Plate", "parts": ["T:Knight", "Skeleton_Warrior/Cloak"]},
			"legs": {"name": "Barrow Greaves", "parts": ["L:Knight"]},
			"trinket": {"name": "Skull Shield", "model": "Skeleton_Shield_Large_A.gltf", "icon": "skull-crossed-bones"},
		},
		"barbarian": {
			"weapon": {"name": "Gravecleaver", "model": "Skeleton_Axe.gltf", "icon": "crossed-axes"},
			"helm": {"name": "Barrow Horns", "parts": ["Skeleton_Warrior/Helmet"]},
			"chest": {"name": "Ribcage Harness", "parts": ["Skeleton_Warrior/Body", "Barbarian/ArmLeft", "Barbarian/ArmRight", "Skeleton_Warrior/Cloak"]},
			"legs": {"name": "Barrow Legs", "parts": ["L:Barbarian"]},
			"trinket": {"name": "Bone Shield", "model": "Skeleton_Shield_Small_A.gltf", "scale": 1.2},
		},
		"mage": {
			"weapon": {"name": "Bone Staff", "model": "kit:bone_staff"},
			"helm": {"name": "Gravecaller Hat", "parts": ["Skeleton_Mage/Hat"]},
			"chest": {"name": "Gravecaller Robe", "parts": ["Skeleton_Mage/Body", "Mage/ArmLeft", "Mage/ArmRight", "Skeleton_Minion/Cloak"]},
			"legs": {"name": "Gravecaller Skirt", "parts": ["L:Mage"]},
			"trinket": {"name": "Skull Orb", "model": "kit:skull_orb", "icon": "crowned-skull"},
		},
		"ranger": {
			"weapon": {"name": "Bone Bow", "model": "bow_withString.gltf", "scale": 1.15},
			"helm": {"name": "Barrow Hood", "parts": ["Skeleton_Rogue/Hood"]},
			"chest": {"name": "Barrow Hide", "parts": ["T:Rogue_Hooded", "Skeleton_Rogue/Cape"]},
			"legs": {"name": "Barrow Chaps", "parts": ["L:Rogue_Hooded"]},
			"trinket": {"name": "Bone Quiver", "model": "Skeleton_Quiver.gltf"},
		},
	}},
	# The Crypt Queen's: blackened plate and robes with violet fire in the seams.
	"hexer": {"dye": Color(0.045, 0.04, 0.06, 1.0), "accent": Color(0.75, 0.35, 1.0), "icon": Color(0.78, 0.6, 1.0), "grade": Vector4(0.75, 0.25, 0.55, 0.0), "cls": {
		"knight": {
			"weapon": {"name": "Blackguard Blade", "model": "sword_2handed.gltf", "scale": 1.05},
			"helm": {"name": "Blackguard Helm", "parts": ["Knight/Helmet", "Knight/HelmetVisor"]},
			"chest": {"name": "Blackguard Plate", "parts": ["T:Knight", "Knight/Cape"]},
			"legs": {"name": "Blackguard Legs", "parts": ["L:Knight"]},
			"trinket": {"name": "Blackguard Shield", "model": "shield_spikes.gltf"},
		},
		"barbarian": {
			"weapon": {"name": "Dread Axe", "model": "axe_2handed.gltf", "scale": 1.12},
			"helm": {"name": "Dread Horns", "parts": ["Skeleton_Warrior/Helmet"]},
			"chest": {"name": "Dread Hide", "parts": ["T:Barbarian", "Rogue_Hooded/Cape"]},
			"legs": {"name": "Dread Legs", "parts": ["L:Barbarian"]},
			"trinket": {"name": "Dread Shield", "model": "Skeleton_Shield_Large_B.gltf"},
		},
		"mage": {
			"weapon": {"name": "Deathlight Staff", "model": "kit:deathlight"},
			"helm": {"name": "Necromancer Hat", "parts": ["Skeleton_Mage/Hat"]},
			"chest": {"name": "Necromancer Robe", "parts": ["Skeleton_Mage/Body", "Mage/ArmLeft", "Mage/ArmRight", "Mage/Cape"]},
			"legs": {"name": "Necromancer Skirt", "parts": ["L:Mage"]},
			"trinket": {"name": "Phylactery", "model": "kit:phylactery", "icon": "gems"},
		},
		"ranger": {
			"weapon": {"name": "Shade Bow", "model": "bow_withString.gltf", "scale": 1.2},
			"helm": {"name": "Shade Hood", "parts": ["Skeleton_Rogue/Hood"]},
			"chest": {"name": "Shade Garb", "parts": ["T:Rogue_Hooded", "Skeleton_Rogue/Cape"]},
			"legs": {"name": "Shade Legs", "parts": ["L:Rogue_Hooded"]},
			"trinket": {"name": "Shade Quiver", "model": "Skeleton_Quiver.gltf"},
		},
	}},
	# The Thornmother's: living bark with green sap in the grain.
	"thorn": {"dye": Color(0.36, 0.25, 0.14, 0.85), "accent": Color(0.55, 1.0, 0.3), "icon": Color(0.7, 0.95, 0.5), "grade": Vector4(0.1, 0.2, 0.6, 0.0), "cls": {
		"knight": {
			"weapon": {"name": "Thornblade", "model": "sword_1handed.gltf", "scale": 1.15},
			"helm": {"name": "Grove Helm", "parts": ["Knight/Helmet"]},
			"chest": {"name": "Barkplate", "parts": ["T:Knight", "Ranger/Cape"]},
			"legs": {"name": "Bark Greaves", "parts": ["L:Knight"]},
			"trinket": {"name": "Grove Shield", "model": "shield_round.gltf", "scale": 1.1},
		},
		"barbarian": {
			"weapon": {"name": "Root Club", "model": "kit:bone_club", "icon": "bone-gnawer"},
			"helm": {"name": "Bear Mask", "parts": ["Barbarian/BearHat"]},
			"chest": {"name": "Bark Hide", "parts": ["T:Barbarian", "Ranger/Cape"]},
			"legs": {"name": "Bark Legs", "parts": ["L:Barbarian"]},
			"trinket": {"name": "Bark Shield", "model": "shield_round_barbarian.gltf"},
		},
		"mage": {
			"weapon": {"name": "Grove Lantern", "model": "kit:lantern_staff"},
			"helm": {"name": "Druid Cowl", "parts": ["Rogue_Hooded/Head"], "hood": true},
			"chest": {"name": "Druid Robe", "parts": ["T:Mage", "Ranger/Cape"]},
			"legs": {"name": "Druid Skirt", "parts": ["L:Mage"]},
			"trinket": {"name": "Seed Tome", "model": "spellbook_closed.gltf"},
		},
		"ranger": {
			"weapon": {"name": "Thornbow", "model": "bow_withString.gltf", "scale": 1.15},
			"helm": {"name": "Grove Hood", "parts": ["Rogue_Hooded/Head"], "hood": true},
			"chest": {"name": "Grove Garb", "parts": ["T:Ranger", "Ranger/Cape"]},
			"legs": {"name": "Grove Chaps", "parts": ["L:Ranger"]},
			"trinket": {"name": "Grove Quiver", "parts": ["Ranger/Quiver"]},
		},
	}},
}

## Rigid parts made for the skeletons' taller skulls sit lower on a living head.
const PART_NUDGE := {"Skeleton_Mage/Hat": Vector3(0, -0.13, 0)}

## Uniques with a model of their own (the rest wear their set's look).
const UNIQUE_LOOKS := {
	"crown": {"parts": ["Skeleton_Warrior/Helmet"]},
	"cleaver": {"model": "Skeleton_Axe.gltf", "scale": 1.1},
	"scepter": {"model": "kit:deathlight"},
	"emberheart": {"model": "kit:candelabra"},
	"gown": {"parts": ["Skeleton_Mage/Body", "Mage/ArmLeft", "Mage/ArmRight", "Mage/Cape"]},
	"shroud": {"parts": ["T:Rogue_Hooded", "Skeleton_Rogue/Cape"]},
	"barkplate": {"parts": ["T:Barbarian", "Ranger/Cape"]},
	"thornbow": {"model": "bow_withString.gltf", "scale": 1.2},
	"seedheart": {"model": "shield_round_color.gltf"},
	"greaves": {"parts": ["L:Knight"]},
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
## look, then its unique's own model. Every later one replaces the shape.
static func piece(it: Dictionary) -> Dictionary:
	var cls := str(it.get("cls", "knight"))
	var slot := str(it["slot"])
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


## "Mithril Platebody" for a hero's tier-3 chest; "Mithril Horned Helm" for
## an alternative, "Mithril Blackguard Helm" for a set piece.
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
