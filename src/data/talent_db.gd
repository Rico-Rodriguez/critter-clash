class_name TalentDB
extends RefCounted
## Talent trees: three paths per hero, eight nodes each, laid out in five rows
## (SLOTS). One point per five combat levels (Game.talent_earned). A row opens
## once enough points sit in the rows above it in that path (GATES), so depth
## is a commitment. Points can be refunded one rank at a time (Game).
##
## Node kinds: "m" minor (a stat, up to `max` ranks), "n" notable (changes a
## rule), "c" choice (pick one of two `opts`), "k" keystone (the end of a path;
## one keystone at a time per hero, and each has a `cost`). Effects sit on the
## node (or on the chosen option), per rank:
##   dmg hp rate speed gold xp super   fractions (0.05 = +5%)
##   crit armor                        added (0.03 = +3 points)
##   regen                             fraction of max health a second
##   dash                              dash recharge, fraction faster
##   cards                             cards the hunt starts with
##   flags                             rules the hunt reads (see Hero.flags)
##   sp                                super perks, added to the super rank's (DB.SUPER_PERKS)
##   always / never                    cards always / never in the level-up offer
## Flags: execute (+x damage to foes under 30% health), mark (+x damage to
## champions), bloodlust (kills in a row speed attacks up, to x stacks),
## second_wind (once a hunt, heal x of max health when dropping low),
## critdmg (crits hit x harder; adds up), dodge_heal (perfect dodges heal x).
##
## Every path also has an attunement: each point spent in it adds `per` of
## `stat` (Diablo II's synergies, kept to one number).

## Points in a path needed to open each row.
const GATES := [0, 3, 6, 10, 13]
## Where each of a path's eight nodes sits: [row, column of three].
const SLOTS := [[0, 0], [0, 2], [1, 0], [1, 2], [2, 1], [3, 0], [3, 2], [4, 1]]
## The lines drawn between nodes (index pairs). Only gates decide what opens.
const LINKS := [[0, 2], [1, 3], [2, 4], [3, 4], [4, 5], [4, 6], [5, 7], [6, 7]]

const STAT_ICON := {"dmg": "strong", "hp": "heart-organ", "armor": "checked-shield", "crit": "bullseye", "rate": "lightning-tear", "speed": "running-shoe", "dash": "sprint", "super": "explosion-rays", "gold": "two-coins", "regen": "health-normal", "xp": "skull-crossed-bones", "critdmg": "sword-wound"}
const STAT_WORD := {"dmg": "damage", "hp": "health", "rate": "attack speed", "speed": "move speed", "gold": "gold", "super": "super charge", "xp": "souls", "dash": "dash recharge", "critdmg": "crit damage"}

const PATHS := {
	"knight": [
		{"name": "Bulwark", "icon": "shield", "blurb": "Wards, thorns, armor", "attune": {"stat": "armor", "per": 0.01}, "nodes": [
			{"name": "Tough Hide", "k": "m", "max": 3, "hp": 0.04},
			{"name": "Plate Training", "k": "m", "max": 3, "armor": 0.01},
			{"name": "Stalwart", "k": "n", "icon": "heart-plus", "flags": {"second_wind": 0.3}, "desc": "Once a hunt, heal 30% when you drop below 30% health"},
			{"name": "Steady Breath", "k": "m", "max": 3, "regen": 0.001},
			{"name": "Shield Craft", "k": "c", "opts": [
				{"name": "Spiked Aegis", "icon": "slashed-shield", "cards": ["thorns"], "desc": "Start every hunt with Thorns"},
				{"name": "Warded", "icon": "bolt-shield", "cards": ["ward"], "desc": "Start every hunt with Bone Ward"}]},
			{"name": "Heavy Plate", "k": "m", "max": 2, "armor": 0.02},
			{"name": "Shield Slam", "k": "n", "icon": "checked-shield", "sp": {"stun": 1.0, "lock": -2.0}, "desc": "Judgement stuns 1 s longer and its lockout is 2 s shorter"},
			{"name": "Bastion", "k": "k", "icon": "castle", "cards": ["ward", "ward"], "armor": 0.15, "speed": -0.1, "desc": "Start with a double Bone Ward, +15 armor", "cost": "-10% move speed"},
		]},
		{"name": "Crusader", "icon": "sun", "blurb": "Smite, crits, Judgement", "attune": {"stat": "critdmg", "per": 0.02}, "nodes": [
			{"name": "Zeal", "k": "m", "max": 3, "dmg": 0.03},
			{"name": "Keen Edge", "k": "m", "max": 3, "crit": 0.01},
			{"name": "Smiter", "k": "n", "icon": "sun", "cards": ["smite"], "desc": "Start every hunt with Holy Smite"},
			{"name": "Oathkeeper", "k": "m", "max": 3, "super": 0.04},
			{"name": "Judgement", "k": "c", "opts": [
				{"name": "Thunder Leap", "icon": "lightning-helix", "sp": {"trail": 1}, "desc": "Lightning strikes all along Judgement's leap"},
				{"name": "Aftershock", "icon": "fist", "sp": {"echo": 1}, "desc": "A second, smaller slam lands after the first"}]},
			{"name": "Sharpened Faith", "k": "m", "max": 2, "crit": 0.02},
			{"name": "Righteous", "k": "n", "icon": "sword-wound", "flags": {"critdmg": 0.5}, "desc": "Crits hit 50% harder"},
			{"name": "Heavenly Host", "k": "k", "icon": "round-star", "cards": ["smite", "might"], "always": ["smite"], "hp": -0.1, "desc": "Start with Holy Smite and Grave Strength; Holy Smite is in every card offer until maxed", "cost": "-10% health"},
		]},
		{"name": "Vanguard", "icon": "sprint", "blurb": "Dash, charge, sword waves", "attune": {"stat": "speed", "per": 0.01}, "nodes": [
			{"name": "Light Step", "k": "m", "max": 3, "speed": 0.02},
			{"name": "Quick Dodge", "k": "m", "max": 3, "dash": 0.05},
			{"name": "Cutting Wind", "k": "n", "icon": "crossed-swords", "cards": ["wave"], "desc": "Start every hunt with Sword Wave"},
			{"name": "Drill", "k": "m", "max": 3, "rate": 0.03},
			{"name": "Bloodied Steel", "k": "c", "opts": [
				{"name": "Run Them Down", "icon": "dripping-sword", "flags": {"execute": 0.3}, "desc": "+30% damage to foes under 30% health"},
				{"name": "Champion's Bane", "icon": "crowned-skull", "flags": {"mark": 0.25}, "desc": "+25% damage to champions"}]},
			{"name": "Brute Force", "k": "m", "max": 2, "dmg": 0.03},
			{"name": "Riposte", "k": "n", "icon": "sprint", "flags": {"dodge_heal": 0.08}, "desc": "Perfect dodges heal 8% health"},
			{"name": "Warlord", "k": "k", "icon": "sword-spin", "cards": ["wave", "reach"], "rate": 0.1, "armor": -0.2, "desc": "Start with Sword Wave and Long Reach, +10% attack speed", "cost": "-20 armor"},
		]},
	],
	"ranger": [
		{"name": "Deadeye", "icon": "bullseye", "blurb": "Crits, pierce, marks", "attune": {"stat": "critdmg", "per": 0.02}, "nodes": [
			{"name": "Steady Aim", "k": "m", "max": 3, "crit": 0.01},
			{"name": "Fletching", "k": "m", "max": 3, "dmg": 0.03},
			{"name": "Hunter's Mark", "k": "n", "icon": "crowned-skull", "flags": {"mark": 0.25}, "desc": "Champions take 25% more damage from you"},
			{"name": "Eagle Eye", "k": "m", "max": 3, "crit": 0.01},
			{"name": "Arrowheads", "k": "c", "opts": [
				{"name": "Barbed", "icon": "barbed-arrow", "cards": ["pierce"], "desc": "Start every hunt with Barbed Arrows"},
				{"name": "Finisher", "icon": "dripping-sword", "flags": {"execute": 0.3}, "desc": "+30% damage to foes under 30% health"}]},
			{"name": "Broadheads", "k": "m", "max": 2, "dmg": 0.03},
			{"name": "Killer Instinct", "k": "n", "icon": "sword-wound", "flags": {"critdmg": 0.4}, "desc": "Crits hit 40% harder"},
			{"name": "Marksman", "k": "k", "icon": "high-shot", "cards": ["crit"], "flags": {"critdmg": 0.75}, "never": ["multishot"], "desc": "Start with Deathmark, crits hit 75% harder", "cost": "Split Shot is never offered"},
		]},
		{"name": "Stormcaller", "icon": "arrow-cluster", "blurb": "Arrow Storm and volleys", "attune": {"stat": "super", "per": 0.01}, "nodes": [
			{"name": "Quick Draw", "k": "m", "max": 3, "rate": 0.03},
			{"name": "Wind Reader", "k": "m", "max": 3, "speed": 0.02},
			{"name": "Storm Warden", "k": "n", "icon": "arrow-cluster", "cards": ["barrage"], "desc": "Start every hunt with Arrow Storm"},
			{"name": "Quiver Boost", "k": "m", "max": 3, "super": 0.04},
			{"name": "Hail of Arrows", "k": "c", "opts": [
				{"name": "Twin Volley", "icon": "arrow-cluster", "sp": {"echo": 1}, "desc": "A second fan follows the first"},
				{"name": "Pinning Rain", "icon": "barbed-arrow", "sp": {"stun": 0.6}, "desc": "The arrow rain pins foes in place"}]},
			{"name": "Gale", "k": "m", "max": 2, "rate": 0.03},
			{"name": "Twin Strings", "k": "n", "icon": "arrow-cluster", "cards": ["multishot"], "desc": "Start every hunt with Split Shot"},
			{"name": "Skyfall", "k": "k", "icon": "meteor-impact", "cards": ["barrage", "multishot"], "super": 0.25, "hp": -0.15, "desc": "Start with Arrow Storm and another Split Shot, +25% super charge", "cost": "-15% health"},
		]},
		{"name": "Trapper", "icon": "fireball", "blurb": "Explosives, speed, kiting", "attune": {"stat": "gold", "per": 0.02}, "nodes": [
			{"name": "Fleet", "k": "m", "max": 3, "speed": 0.02},
			{"name": "Quick Roll", "k": "m", "max": 3, "dash": 0.05},
			{"name": "Blasting Powder", "k": "n", "icon": "fireball", "cards": ["explosive"], "desc": "Start every hunt with Explosive Arrows"},
			{"name": "Salvager", "k": "m", "max": 3, "gold": 0.05},
			{"name": "Escape Plan", "k": "c", "opts": [
				{"name": "Slip the Net", "icon": "sprint", "flags": {"dodge_heal": 0.08}, "desc": "Perfect dodges heal 8% health"},
				{"name": "Finisher", "icon": "dripping-sword", "flags": {"execute": 0.3}, "desc": "+30% damage to foes under 30% health"}]},
			{"name": "Ghost Step", "k": "m", "max": 2, "dash": 0.05},
			{"name": "Poacher's Eye", "k": "n", "icon": "crowned-skull", "flags": {"mark": 0.25}, "desc": "Champions take 25% more damage from you"},
			{"name": "Poacher", "k": "k", "icon": "two-coins", "cards": ["explosive", "swift"], "gold": 0.25, "dmg": -0.1, "desc": "Start with Explosive Arrows and Fleetfoot, +25% gold", "cost": "-10% damage"},
		]},
	],
	"mage": [
		{"name": "Pyromancer", "icon": "fire-ring", "blurb": "Fire Nova and meteors", "attune": {"stat": "dmg", "per": 0.01}, "nodes": [
			{"name": "Kindling", "k": "m", "max": 3, "dmg": 0.03},
			{"name": "Searing Focus", "k": "m", "max": 3, "crit": 0.01},
			{"name": "Nova Core", "k": "n", "icon": "fire-ring", "cards": ["nova"], "desc": "Start every hunt with Fire Nova"},
			{"name": "Wide Flames", "k": "m", "max": 3, "rate": 0.03},
			{"name": "Meteor Storm", "k": "c", "opts": [
				{"name": "Meteor Swarm", "icon": "meteor-impact", "sp": {"count": 3}, "desc": "Meteor Storm drops 3 more meteors"},
				{"name": "Great Meteor", "icon": "meteor-impact", "sp": {"echo": 1}, "desc": "A great meteor falls last on the nearest foe"}]},
			{"name": "Hot Hands", "k": "m", "max": 2, "dmg": 0.03},
			{"name": "Falling Stars", "k": "n", "icon": "meteor-impact", "cards": ["meteor"], "desc": "Start every hunt with Meteor Shower"},
			{"name": "Glass Cannon", "k": "k", "icon": "flame", "dmg": 0.3, "hp": -0.25, "desc": "+30% damage", "cost": "-25% health"},
		]},
		{"name": "Frostweaver", "icon": "frozen-orb", "blurb": "Frost Ring, storms, control", "attune": {"stat": "armor", "per": 0.01}, "nodes": [
			{"name": "Cold Snap", "k": "m", "max": 3, "speed": 0.02},
			{"name": "Rime", "k": "m", "max": 3, "armor": 0.01},
			{"name": "Frost Ring", "k": "n", "icon": "frozen-orb", "cards": ["frost"], "desc": "Start every hunt with Frost Ring"},
			{"name": "Icy Veins", "k": "m", "max": 3, "super": 0.04},
			{"name": "Deep Cold", "k": "c", "opts": [
				{"name": "Shatter", "icon": "ice-bolt", "flags": {"execute": 0.3}, "desc": "+30% damage to foes under 30% health"},
				{"name": "Frozen Sky", "icon": "meteor-impact", "sp": {"stun": 0.8}, "desc": "Meteor Storm stuns what it hits"}]},
			{"name": "Permafrost", "k": "m", "max": 2, "hp": 0.04},
			{"name": "Storm Call", "k": "n", "icon": "lightning-helix", "cards": ["storm"], "desc": "Start every hunt with Storm Call"},
			{"name": "Glacier", "k": "k", "icon": "frozen-orb", "cards": ["frost", "storm"], "armor": 0.15, "rate": -0.1, "desc": "Start with Frost Ring and Storm Call, +15 armor", "cost": "-10% attack speed"},
		]},
		{"name": "Hexbinder", "icon": "magic-swirl", "blurb": "Leech, wards, endurance", "attune": {"stat": "hp", "per": 0.01}, "nodes": [
			{"name": "Bind", "k": "m", "max": 3, "hp": 0.04},
			{"name": "Soul Sip", "k": "m", "max": 3, "regen": 0.001},
			{"name": "Hex Ward", "k": "n", "icon": "bolt-shield", "cards": ["ward"], "desc": "Start every hunt with Bone Ward"},
			{"name": "Cursed Tongue", "k": "m", "max": 3, "xp": 0.04},
			{"name": "Dark Bargain", "k": "c", "opts": [
				{"name": "Bloodthirst", "icon": "dripping-sword", "cards": ["leech"], "desc": "Start every hunt with Bloodthirst"},
				{"name": "Dark Pact", "icon": "magic-swirl", "dmg": 0.08, "super": 0.08, "desc": "+8% damage and +8% super charge"}]},
			{"name": "Siphon", "k": "m", "max": 2, "regen": 0.001},
			{"name": "Undying Pact", "k": "n", "icon": "ghost", "flags": {"second_wind": 0.4}, "desc": "Once a hunt, heal 40% when you drop below 30% health"},
			{"name": "Lich", "k": "k", "icon": "skull-staff", "cards": ["leech", "ward"], "hp": 0.2, "speed": -0.15, "desc": "Start with Bloodthirst and Bone Ward, +20% health", "cost": "-15% move speed"},
		]},
	],
	"barbarian": [
		{"name": "Berserker", "icon": "muscle-up", "blurb": "Attack speed and rage", "attune": {"stat": "rate", "per": 0.01}, "nodes": [
			{"name": "Rage", "k": "m", "max": 3, "rate": 0.03},
			{"name": "Thick Skull", "k": "m", "max": 3, "hp": 0.04},
			{"name": "Bloodlust", "k": "n", "icon": "muscle-up", "flags": {"bloodlust": 10}, "desc": "Each kill within a second adds 5% attack speed, up to 10 stacks"},
			{"name": "Fury", "k": "m", "max": 3, "dmg": 0.03},
			{"name": "Whirlwind", "k": "c", "opts": [
				{"name": "Long Spin", "icon": "whirlwind", "sp": {"dur": 0.8}, "desc": "Whirlwind lasts 0.8 s longer"},
				{"name": "Blood Spin", "icon": "dripping-sword", "sp": {"heal": 0.01}, "desc": "Each spin that cuts a foe heals 1% health"}]},
			{"name": "Gore", "k": "m", "max": 2, "crit": 0.02},
			{"name": "Last Stand", "k": "n", "icon": "heart-plus", "flags": {"second_wind": 0.35}, "desc": "Once a hunt, heal 35% when you drop below 30% health"},
			{"name": "Warcry", "k": "k", "icon": "lightning-tear", "cards": ["haste", "haste"], "flags": {"bloodlust": 15}, "armor": -0.15, "desc": "Start with two Bloodrush; rage stacks to 15", "cost": "-15 armor"},
		]},
		{"name": "Earthbreaker", "icon": "fist", "blurb": "Earthshaker and Faultline", "attune": {"stat": "super", "per": 0.01}, "nodes": [
			{"name": "Heavy Hands", "k": "m", "max": 3, "dmg": 0.03},
			{"name": "Stone Skin", "k": "m", "max": 3, "armor": 0.01},
			{"name": "Earthshaker", "k": "n", "icon": "fist", "cards": ["quake"], "desc": "Start every hunt with Earthshaker"},
			{"name": "Tremor", "k": "m", "max": 3, "super": 0.04},
			{"name": "Broken Ground", "k": "c", "opts": [
				{"name": "Fault Line", "icon": "sword-spin", "cards": ["reach"], "desc": "Start every hunt with Long Reach"},
				{"name": "Granite", "icon": "checked-shield", "hp": 0.12, "armor": 0.04, "desc": "+12% health and +4 armor"}]},
			{"name": "Boulder Arms", "k": "m", "max": 2, "dmg": 0.03},
			{"name": "Molten Finale", "k": "n", "icon": "flame", "sp": {"finale": 1}, "desc": "Whirlwind ends in a fire blast"},
			{"name": "Cataclysm", "k": "k", "icon": "meteor-impact", "cards": ["quake", "might"], "super": 0.2, "rate": -0.1, "desc": "Start with Earthshaker and Grave Strength, +20% super charge", "cost": "-10% attack speed"},
		]},
		{"name": "Axethrower", "icon": "crossed-axes", "blurb": "Thrown axes, whirlwind", "attune": {"stat": "dmg", "per": 0.01}, "nodes": [
			{"name": "Ranged Grip", "k": "m", "max": 3, "speed": 0.02},
			{"name": "Balanced Haft", "k": "m", "max": 3, "crit": 0.01},
			{"name": "Axe Toss", "k": "n", "icon": "crossed-axes", "cards": ["axes"], "desc": "Start every hunt with Thrown Axes"},
			{"name": "Spin Up", "k": "m", "max": 3, "super": 0.04},
			{"name": "Edge Work", "k": "c", "opts": [
				{"name": "Executioner", "icon": "dripping-sword", "flags": {"execute": 0.35}, "desc": "+35% damage to foes under 30% health"},
				{"name": "Orbit", "icon": "spinning-blades", "cards": ["blades"], "desc": "Start every hunt with Orbiting Blades"}]},
			{"name": "Hurl", "k": "m", "max": 2, "dmg": 0.03},
			{"name": "Headhunter", "k": "n", "icon": "crowned-skull", "flags": {"mark": 0.25}, "desc": "Champions take 25% more damage from you"},
			{"name": "Axe Storm", "k": "k", "icon": "tomahawk", "cards": ["axes", "blades"], "hp": -0.15, "desc": "Start with Thrown Axes and Orbiting Blades", "cost": "-15% health"},
		]},
	],
	"rogue": [
		{"name": "Assassin", "icon": "cloak-dagger", "blurb": "Crits and executions", "attune": {"stat": "critdmg", "per": 0.02}, "nodes": [
			{"name": "Keen Edge", "k": "m", "max": 3, "crit": 0.01},
			{"name": "Poisoned Blades", "k": "m", "max": 3, "dmg": 0.03},
			{"name": "Cut Throat", "k": "n", "icon": "dripping-sword", "flags": {"execute": 0.3}, "desc": "+30% damage to foes under 30% health"},
			{"name": "Vital Spots", "k": "m", "max": 3, "crit": 0.01},
			{"name": "Shadowstep", "k": "c", "opts": [
				{"name": "Chain Blink", "icon": "two-shadows", "sp": {"marks": 3}, "desc": "Shadowstep blinks to 3 more foes"},
				{"name": "Crippling Stabs", "icon": "thrown-daggers", "sp": {"stun": 1.0}, "desc": "Shadowstep's stabs stun for 1 s"}]},
			{"name": "Quick Hands", "k": "m", "max": 2, "rate": 0.03},
			{"name": "Killer Instinct", "k": "n", "icon": "sword-wound", "flags": {"critdmg": 0.4}, "desc": "Crits hit 40% harder"},
			{"name": "Death Mark", "k": "k", "icon": "skull-crossed-bones", "cards": ["crit"], "flags": {"critdmg": 0.6}, "hp": -0.15, "desc": "Start with Deathmark, crits hit 60% harder", "cost": "-15% health"},
		]},
		{"name": "Shadow", "icon": "hood", "blurb": "Dashes and Shadowstep", "attune": {"stat": "dash", "per": 0.01}, "nodes": [
			{"name": "Slip Away", "k": "m", "max": 3, "dash": 0.05},
			{"name": "Thin Shadow", "k": "m", "max": 3, "hp": 0.04},
			{"name": "Shadow Hunger", "k": "n", "icon": "explosion-rays", "super": 0.15, "desc": "+15% super charge"},
			{"name": "Footwork", "k": "m", "max": 3, "speed": 0.02},
			{"name": "Vanish", "k": "c", "opts": [
				{"name": "Escape Artist", "icon": "ghost", "flags": {"second_wind": 0.3}, "desc": "Once a hunt, heal 30% when you drop below 30% health"},
				{"name": "Smoke Dancer", "icon": "sprint", "flags": {"dodge_heal": 0.08}, "desc": "Perfect dodges heal 8% health"}]},
			{"name": "Darkness", "k": "m", "max": 2, "super": 0.04},
			{"name": "Smoke Burst", "k": "n", "icon": "two-shadows", "sp": {"finale": 1}, "desc": "Shadowstep ends in a smoke burst"},
			{"name": "Nightfall", "k": "k", "icon": "moon", "super": 0.25, "dash": 0.2, "dmg": -0.1, "desc": "+25% super charge, dash recharges 20% faster", "cost": "-10% damage"},
		]},
		{"name": "Duelist", "icon": "crossed-swords", "blurb": "Champions and bosses", "attune": {"stat": "dmg", "per": 0.01}, "nodes": [
			{"name": "Steady Hand", "k": "m", "max": 3, "dmg": 0.03},
			{"name": "Leather Guard", "k": "m", "max": 3, "armor": 0.01},
			{"name": "Champion Hunter", "k": "n", "icon": "crowned-skull", "flags": {"mark": 0.25}, "desc": "Champions take 25% more damage from you"},
			{"name": "Riposte", "k": "m", "max": 3, "rate": 0.03},
			{"name": "Tempo", "k": "c", "opts": [
				{"name": "Flurry", "icon": "lightning-tear", "flags": {"bloodlust": 8}, "desc": "Each kill within a second adds 5% attack speed, up to 8 stacks"},
				{"name": "Toughness", "icon": "heart-organ", "hp": 0.12, "desc": "+12% health"}]},
			{"name": "Precision", "k": "m", "max": 2, "dmg": 0.03},
			{"name": "Bleeding Edge", "k": "n", "icon": "dripping-sword", "cards": ["leech"], "desc": "Start every hunt with Bloodthirst"},
			{"name": "Bladedance", "k": "k", "icon": "spinning-blades", "cards": ["blades"], "rate": 0.15, "armor": -0.15, "desc": "Start with Orbiting Blades, +15% attack speed", "cost": "-15 armor"},
		]},
	],
}

const KIND_NAME := {"m": "Minor", "n": "Notable", "c": "Choose one", "k": "Keystone"}


static func paths(hero: String) -> Array:
	return PATHS[hero]


static func node(hero: String, path: int, idx: int) -> Dictionary:
	return PATHS[hero][path]["nodes"][idx]


static func valid(hero: String, path: int, idx: int) -> bool:
	return PATHS.has(hero) and path >= 0 and path < PATHS[hero].size() and idx >= 0 and idx < PATHS[hero][path]["nodes"].size()


## A node is saved as "path.index" ("1.4").
static func key(path: int, idx: int) -> String:
	return "%d.%d" % [path, idx]


static func row(idx: int) -> int:
	return int(SLOTS[idx][0])


static func max_rank(n: Dictionary) -> int:
	return int(n.get("max", 1))


## The icon for a node, or for its chosen option (`pick`, -1 = none yet).
static func icon(n: Dictionary, pick := -1) -> String:
	if n["k"] == "c":
		return str(n["opts"][maxi(pick, 0)]["icon"])
	if n.has("icon"):
		return str(n["icon"])
	for k: String in STAT_ICON:
		if n.has(k):
			return STAT_ICON[k]
	return "round-star"


## The effects a node gives at `rank` ranks: a minor's numbers times its rank,
## a choice's chosen option, anything else as written.
static func effects(n: Dictionary, rank: int, pick := 0) -> Dictionary:
	if rank <= 0:
		return {}
	if n["k"] == "c":
		return n["opts"][clampi(pick, 0, n["opts"].size() - 1)]
	if n["k"] != "m":
		return n
	var out := {}
	for k: String in ["dmg", "hp", "rate", "speed", "gold", "super", "xp", "crit", "armor", "regen", "dash"]:
		if n.has(k):
			out[k] = float(n[k]) * rank
	return out


## One line for a stat amount (`stat` as in STAT_ICON).
static func stat_text(stat: String, v: float) -> String:
	match stat:
		"armor":
			return "%+d armor" % int(round(v * 100.0))
		"crit":
			return "%+d%% crit chance" % int(round(v * 100.0))
		"regen":
			return "Regen %.1f%%/s" % (v * 100.0)
		"dash":
			return "Dash %d%% faster" % int(round(v * 100.0))
		"critdmg":
			return "Crits hit %d%% harder" % int(round(v * 100.0))
	return "%+d%% %s" % [int(round(v * 100.0)), STAT_WORD[stat]]


## What a node does at `rank` (a minor counts its ranks; other kinds have text).
static func describe(n: Dictionary, rank := 1, pick := 0) -> String:
	if n["k"] == "c":
		return str(n["opts"][clampi(pick, 0, n["opts"].size() - 1)]["desc"])
	if n.has("desc"):
		return str(n["desc"])
	var parts: PackedStringArray = []
	var fx := effects(n, maxi(rank, 1))
	for k: String in fx:
		parts.append(stat_text(k, float(fx[k])))
	return ", ".join(parts)


## The attunement a path gives for `points` spent in it.
static func attune_text(path: Dictionary, points: int) -> String:
	var a: Dictionary = path["attune"]
	return stat_text(str(a["stat"]), float(a["per"]) * points)
