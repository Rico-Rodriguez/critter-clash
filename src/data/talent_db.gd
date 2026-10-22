class_name TalentDB
extends RefCounted
## Talent trees: three paths per hero, eight nodes down each, one point per
## five combat levels (Game.talent_earned). A node needs the one above it. Free respec.
##
## Node kinds: "m" minor (a small stat), "n" notable (changes a rule), "k"
## keystone (the end of a path). Effects sit on the node itself:
##   dmg hp rate speed gold magnet xp super   fractions (0.05 = +5%)
##   crit armor                               added (0.03 = +3 points)
##   regen                                    fraction of max health a second
##   dash                                     dash recharge, fraction faster
##   cards                                    cards the hunt starts with
##   flags                                    rules the hunt reads (see Hero.flag)
## Flags: execute (+x damage to foes under 30% health), mark (+x damage to
## champions), bloodlust (kills in a row speed attacks up, to x stacks),
## second_wind (once a hunt, heal x of max health when dropping low),
## critdmg (crits hit x harder).

const POINT_LEVELS := 20

const PATHS := {
	"knight": [
		{"name": "Bulwark", "icon": "shield", "blurb": "Wards, thorns, armor", "nodes": [
			{"name": "Tough Hide", "k": "m", "hp": 0.08},
			{"name": "Plate Training", "k": "m", "armor": 0.03},
			{"name": "Stalwart", "k": "n", "flags": {"second_wind": 0.3}, "desc": "Once a hunt, heal 30% when you drop low"},
			{"name": "Deep Reserves", "k": "m", "hp": 0.1},
			{"name": "Heavy Plate", "k": "m", "armor": 0.04},
			{"name": "Spiked Aegis", "k": "n", "cards": ["thorns"], "desc": "Start with Thorns"},
			{"name": "Steady Breath", "k": "m", "regen": 0.004},
			{"name": "Bastion", "k": "k", "cards": ["ward", "ward"], "armor": 0.05, "desc": "Start with a double Bone Ward and +5% armor"},
		]},
		{"name": "Crusader", "icon": "sun", "blurb": "Smite, crits, Judgement", "nodes": [
			{"name": "Zeal", "k": "m", "dmg": 0.05},
			{"name": "Keen Edge", "k": "m", "crit": 0.03},
			{"name": "Smiter", "k": "n", "cards": ["smite"], "desc": "Start with Holy Smite"},
			{"name": "Righteous Fury", "k": "m", "dmg": 0.05},
			{"name": "Oathkeeper", "k": "m", "super": 0.12},
			{"name": "Judgement", "k": "n", "flags": {"critdmg": 0.5}, "super": 0.15, "desc": "Crits hit 50% harder, super +15%"},
			{"name": "Sharpened Faith", "k": "m", "crit": 0.03},
			{"name": "Heavenly Host", "k": "k", "cards": ["smite", "might"], "desc": "Start with Holy Smite and Grave Strength"},
		]},
		{"name": "Vanguard", "icon": "sprint", "blurb": "Dash, charge, sword waves", "nodes": [
			{"name": "Light Step", "k": "m", "speed": 0.04},
			{"name": "Quick Dodge", "k": "m", "dash": 0.1},
			{"name": "Cutting Wind", "k": "n", "cards": ["wave"], "desc": "Start with Sword Wave"},
			{"name": "Drill", "k": "m", "rate": 0.05},
			{"name": "Brute Force", "k": "m", "dmg": 0.05},
			{"name": "Run Them Down", "k": "n", "flags": {"execute": 0.3}, "desc": "+30% damage to foes under 30% health"},
			{"name": "Second Wind", "k": "m", "dash": 0.1},
			{"name": "Warlord", "k": "k", "cards": ["wave", "reach"], "rate": 0.08, "desc": "Start with Sword Wave and Long Reach, +8% attack speed"},
		]},
	],
	"ranger": [
		{"name": "Deadeye", "icon": "bullseye", "blurb": "Crits, pierce, marks", "nodes": [
			{"name": "Steady Aim", "k": "m", "crit": 0.03},
			{"name": "Fletching", "k": "m", "dmg": 0.05},
			{"name": "Hunter's Mark", "k": "n", "flags": {"mark": 0.25}, "desc": "Champions take 25% more damage from you"},
			{"name": "Eagle Eye", "k": "m", "crit": 0.03},
			{"name": "Broadheads", "k": "m", "dmg": 0.05},
			{"name": "Piercing Shot", "k": "n", "cards": ["pierce"], "desc": "Start with Barbed Arrows"},
			{"name": "Killer Instinct", "k": "m", "flags": {"critdmg": 0.25}},
			{"name": "Marksman", "k": "k", "cards": ["pierce", "crit"], "flags": {"critdmg": 0.5}, "desc": "Start with Barbed Arrows and Deathmark, crits hit 50% harder"},
		]},
		{"name": "Stormcaller", "icon": "arrow-cluster", "blurb": "Arrow Storm and volleys", "nodes": [
			{"name": "Quick Draw", "k": "m", "rate": 0.05},
			{"name": "Wind Reader", "k": "m", "speed": 0.04},
			{"name": "Storm Warden", "k": "n", "cards": ["barrage"], "desc": "Start with Arrow Storm"},
			{"name": "Rapid Volley", "k": "m", "rate": 0.05},
			{"name": "Quiver Boost", "k": "m", "super": 0.12},
			{"name": "Twin Strings", "k": "n", "cards": ["multishot"], "desc": "Start with Split Shot"},
			{"name": "Gale", "k": "m", "rate": 0.05},
			{"name": "Skyfall", "k": "k", "cards": ["barrage", "multishot"], "super": 0.15, "desc": "Start with Arrow Storm and a second Split Shot, super +15%"},
		]},
		{"name": "Trapper", "icon": "fireball", "blurb": "Explosives, speed, kiting", "nodes": [
			{"name": "Fleet", "k": "m", "speed": 0.05},
			{"name": "Quick Roll", "k": "m", "dash": 0.1},
			{"name": "Blasting Powder", "k": "n", "cards": ["explosive"], "desc": "Start with Explosive Arrows"},
			{"name": "Lighter Pack", "k": "m", "speed": 0.04},
			{"name": "Salvager", "k": "m", "gold": 0.15},
			{"name": "Finisher", "k": "n", "flags": {"execute": 0.3}, "desc": "+30% damage to foes under 30% health"},
			{"name": "Ghost Step", "k": "m", "dash": 0.1},
			{"name": "Poacher", "k": "k", "cards": ["explosive", "swift"], "gold": 0.2, "desc": "Start with Explosive Arrows and Fleetfoot, +20% gold"},
		]},
	],
	"mage": [
		{"name": "Pyromancer", "icon": "fire-ring", "blurb": "Fire Nova and meteors", "nodes": [
			{"name": "Kindling", "k": "m", "dmg": 0.05},
			{"name": "Ember Skin", "k": "m", "hp": 0.06},
			{"name": "Nova Core", "k": "n", "cards": ["nova"], "desc": "Start with Fire Nova"},
			{"name": "Hot Hands", "k": "m", "dmg": 0.06},
			{"name": "Wide Flames", "k": "m", "rate": 0.05},
			{"name": "Falling Stars", "k": "n", "cards": ["meteor"], "desc": "Start with Meteor Shower"},
			{"name": "Searing Focus", "k": "m", "crit": 0.03},
			{"name": "Glass Cannon", "k": "k", "dmg": 0.3, "hp": -0.2, "desc": "+30% damage, -20% health"},
		]},
		{"name": "Frostweaver", "icon": "frozen-orb", "blurb": "Frost Ring, storms, control", "nodes": [
			{"name": "Cold Snap", "k": "m", "speed": 0.04},
			{"name": "Rime", "k": "m", "armor": 0.03},
			{"name": "Frost Ring", "k": "n", "cards": ["frost"], "desc": "Start with Frost Ring"},
			{"name": "Brittle", "k": "m", "crit": 0.03},
			{"name": "Icy Veins", "k": "m", "super": 0.12},
			{"name": "Shatter", "k": "n", "flags": {"execute": 0.3}, "desc": "+30% damage to foes under 30% health"},
			{"name": "Permafrost", "k": "m", "hp": 0.08},
			{"name": "Glacier", "k": "k", "cards": ["frost", "storm"], "desc": "Start with Frost Ring and Storm Call"},
		]},
		{"name": "Hexbinder", "icon": "magic-swirl", "blurb": "Leech, wards, endurance", "nodes": [
			{"name": "Bind", "k": "m", "hp": 0.06},
			{"name": "Soul Sip", "k": "m", "regen": 0.003},
			{"name": "Hex Ward", "k": "n", "cards": ["ward"], "desc": "Start with Bone Ward"},
			{"name": "Dark Pact", "k": "m", "dmg": 0.05},
			{"name": "Siphon", "k": "m", "regen": 0.003},
			{"name": "Bloodthirst", "k": "n", "cards": ["leech"], "desc": "Start with Bloodthirst"},
			{"name": "Cursed Tongue", "k": "m", "xp": 0.1},
			{"name": "Lich", "k": "k", "cards": ["leech", "ward"], "flags": {"second_wind": 0.4}, "desc": "Start with Bloodthirst and Bone Ward; once a hunt heal 40% when low"},
		]},
	],
	"barbarian": [
		{"name": "Berserker", "icon": "muscle-up", "blurb": "Attack speed and rage", "nodes": [
			{"name": "Rage", "k": "m", "rate": 0.05},
			{"name": "Thick Skull", "k": "m", "hp": 0.06},
			{"name": "Bloodlust", "k": "n", "flags": {"bloodlust": 10}, "desc": "Each kill within a second adds 5% attack speed, up to 10 stacks"},
			{"name": "Fury", "k": "m", "dmg": 0.05},
			{"name": "Battle Trance", "k": "m", "rate": 0.05},
			{"name": "Last Stand", "k": "n", "flags": {"second_wind": 0.35}, "desc": "Once a hunt, heal 35% when you drop low"},
			{"name": "Gore", "k": "m", "crit": 0.03},
			{"name": "Warcry", "k": "k", "cards": ["haste", "haste"], "rate": 0.05, "desc": "Start with two Bloodrush and +5% attack speed"},
		]},
		{"name": "Earthbreaker", "icon": "fist", "blurb": "Earthshaker and Faultline", "nodes": [
			{"name": "Heavy Hands", "k": "m", "dmg": 0.05},
			{"name": "Stone Skin", "k": "m", "armor": 0.03},
			{"name": "Earthshaker", "k": "n", "cards": ["quake"], "desc": "Start with Earthshaker"},
			{"name": "Tremor", "k": "m", "super": 0.12},
			{"name": "Granite", "k": "m", "hp": 0.08},
			{"name": "Fault Line", "k": "n", "cards": ["reach"], "desc": "Start with Long Reach"},
			{"name": "Boulder Arms", "k": "m", "dmg": 0.06},
			{"name": "Cataclysm", "k": "k", "cards": ["quake", "might"], "super": 0.15, "desc": "Start with Earthshaker and Grave Strength, super +15%"},
		]},
		{"name": "Axethrower", "icon": "crossed-axes", "blurb": "Thrown axes, whirlwind", "nodes": [
			{"name": "Ranged Grip", "k": "m", "speed": 0.04},
			{"name": "Balanced Haft", "k": "m", "crit": 0.03},
			{"name": "Axe Toss", "k": "n", "cards": ["axes"], "desc": "Start with Thrown Axes"},
			{"name": "Spin Up", "k": "m", "super": 0.12},
			{"name": "Hurl", "k": "m", "dmg": 0.05},
			{"name": "Executioner", "k": "n", "flags": {"execute": 0.35}, "desc": "+35% damage to foes under 30% health"},
			{"name": "Whirl", "k": "m", "dash": 0.1},
			{"name": "Axe Storm", "k": "k", "cards": ["axes", "blades"], "desc": "Start with Thrown Axes and Orbiting Blades"},
		]},
	],
}

const KIND_NAME := {"m": "Minor", "n": "Notable", "k": "Keystone"}


static func paths(hero: String) -> Array:
	return PATHS[hero]


static func node(hero: String, path: int, idx: int) -> Dictionary:
	return PATHS[hero][path]["nodes"][idx]


## Talents are saved as "path.index" strings ("1.4").
static func key(path: int, idx: int) -> String:
	return "%d.%d" % [path, idx]


## One line for a node: its own text, or the stats it adds.
static func describe(n: Dictionary) -> String:
	if n.has("desc"):
		return str(n["desc"])
	var parts: PackedStringArray = []
	for k: String in ["dmg", "hp", "rate", "speed", "gold", "super", "xp"]:
		if n.has(k):
			parts.append("%+d%% %s" % [int(round(float(n[k]) * 100.0)), {"dmg": "damage", "hp": "health", "rate": "attack speed", "speed": "move speed", "gold": "gold", "super": "super charge", "xp": "souls"}[k]])
	if n.has("crit"):
		parts.append("+%d%% crit chance" % int(round(float(n["crit"]) * 100.0)))
	if n.has("armor"):
		parts.append("+%d armor" % int(round(float(n["armor"]) * 100.0)))
	if n.has("regen"):
		parts.append("Regen %.1f%%/s" % (float(n["regen"]) * 100.0))
	if n.has("dash"):
		parts.append("Dash %d%% faster" % int(round(float(n["dash"]) * 100.0)))
	if n.has("flags") and (n["flags"] as Dictionary).has("critdmg"):
		parts.append("Crits hit %d%% harder" % int(round(float(n["flags"]["critdmg"]) * 100.0)))
	return ", ".join(parts)
