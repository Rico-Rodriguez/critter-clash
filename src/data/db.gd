class_name DB
extends RefCounted
## All tunable game data in one place: heroes, enemies, upgrade cards, loot,
## difficulty tiers and the OSRS skill curve. Nothing here touches the scene.

# --- Rarity --------------------------------------------------------------

const RARITIES := ["common", "magic", "rare", "legendary"]
const RARITY_NAME := {"common": "Common", "magic": "Magic", "rare": "Rare", "legendary": "Legendary", "epic": "Epic"}
const RARITY_COLOR := {
	"common": Color(0.86, 0.84, 0.80),
	"magic": Color(0.42, 0.62, 1.0),
	"rare": Color(1.0, 0.84, 0.32),
	"epic": Color(0.74, 0.46, 1.0),
	"legendary": Color(1.0, 0.52, 0.16),
}

static func rarity_color(r: String) -> Color:
	return RARITY_COLOR.get(r, Color.WHITE)

# --- Heroes --------------------------------------------------------------
# style: melee (arc swing), bow (projectile), magic (splash projectile).
# super: the charged ability on the right thumb.

const HEROES := {
	"knight": {
		"name": "Knight", "title": "The Oathsworn", "role": "Tank",
		"model": "Knight",
		"weapons": {"handslot.r": "sword_1handed.gltf", "handslot.l": "shield_badge_color.gltf"},
		"weapon_bone": "handslot.r", "weapon_looks": ["", "", "sword_2handed_color.gltf", "sword_2handed_color.gltf"],
		"style": "melee", "hp": 430.0, "speed": 5.3, "dmg": 26.0, "rate": 1.15,
		"range": 2.5, "arc": 130.0, "armor": 0.15,
		"super": "slam", "super_name": "Judgement", "super_desc": "Leap and smash the ground as lightning falls around you.",
		"anim": {"idle": "Idle_A", "run": "Running_A", "attack": ["Melee_1H_Attack_Slice_Diagonal", "Melee_1H_Attack_Slice_Horizontal", "Melee_1H_Attack_Chop"], "super": "Melee_1H_Attack_Jump_Chop"},
		"color": Color(0.36, 0.56, 0.95), "icon": "visored-helm",
		"blurb": "Sword and shield. Stands in the crowd and does not fall.",
		"skill": "melee", "unlock": "start",
	},
	"ranger": {
		"name": "Ranger", "title": "The Grave Warden", "role": "Marksman",
		"model": "Ranger",
		"weapons": {"handslot.l": "bow_withString.gltf"},
		"weapon_bone": "handslot.l", "weapon_looks": [],
		"style": "bow", "hp": 360.0, "speed": 5.8, "dmg": 16.0, "rate": 1.9, "pierce": 1, "shots": 2,
		"range": 9.5, "proj_speed": 26.0, "armor": 0.0,
		"super": "volley", "super_name": "Hail of Arrows", "super_desc": "A wide fan of piercing arrows, and a storm of arrows from above.",
		"anim": {"idle": "Ranged_Bow_Idle", "run": "Running_HoldingBow", "attack": ["Ranged_Bow_Release"], "super": "Ranged_Bow_Release_Up"},
		"color": Color(0.36, 0.78, 0.45), "icon": "pocket-bow",
		"blurb": "Kites the dead and never stops shooting.",
		"skill": "ranged", "unlock": "start",
	},
	"mage": {
		"name": "Mage", "title": "The Ember Witch", "role": "Caster",
		"model": "Mage",
		"weapons": {"handslot.r": "staff.gltf"},
		"weapon_bone": "handslot.r", "weapon_looks": [],
		"style": "magic", "hp": 300.0, "speed": 5.4, "dmg": 25.0, "rate": 1.15,
		"range": 8.5, "proj_speed": 16.0, "splash": 2.2, "armor": 0.0,
		"super": "meteor", "super_name": "Meteor Storm", "super_desc": "Call down a barrage of meteors on the horde.",
		"anim": {"idle": "Idle_B", "run": "Running_B", "attack": ["Ranged_Magic_Shoot"], "super": "Ranged_Magic_Summon"},
		"color": Color(0.85, 0.42, 0.95), "icon": "wizard-staff",
		"blurb": "Fireballs that burst through packs.",
		"skill": "magic", "unlock": "start",
	},
	"barbarian": {
		"name": "Barbarian", "title": "The Bonebreaker", "role": "Bruiser",
		"model": "Barbarian",
		"weapons": {"handslot.r": "axe_2handed.gltf"},
		"weapon_bone": "handslot.r", "weapon_looks": [],
		"style": "melee", "hp": 500.0, "speed": 5.1, "dmg": 40.0, "rate": 0.82,
		"range": 2.9, "arc": 190.0, "armor": 0.08,
		"super": "whirlwind", "super_name": "Whirlwind", "super_desc": "Spin through the horde, cutting everything you touch.",
		"anim": {"idle": "Melee_2H_Idle", "run": "Running_A", "attack": ["Melee_2H_Attack_Slice", "Melee_2H_Attack_Chop"], "super": "Melee_2H_Attack_Spinning"},
		"color": Color(0.95, 0.45, 0.3), "icon": "battle-axe",
		"blurb": "Huge swings. Clears a circle around him.",
		"skill": "melee", "unlock": "veteran",
	},
}
const HERO_ORDER := ["knight", "ranger", "mage", "barbarian"]

## Past level 10 a level is worth less raw power (LEVEL_POWER_LATE) but still
## gives a talent point (see TalentDB).
const HERO_MAX_LEVEL := 20
## Shards and gold to go from level n to n+1 (index = current level).
const UPGRADE_SHARDS := [0, 6, 12, 20, 32, 48, 70, 100, 140, 200, 240, 280, 330, 390, 460, 540, 630, 730, 840, 960]
const UPGRADE_GOLD := [0, 60, 140, 280, 500, 800, 1200, 1800, 2700, 4000, 5500, 7000, 9000, 11500, 14500, 18000, 22000, 27000, 33000, 40000]
const LEVEL_POWER := 0.09
const LEVEL_POWER_LATE := 0.04

# --- Enemies -------------------------------------------------------------
# ai: melee (walk up, wind up, swing), ranged (keep distance, aimed bolt),
# caster (drops a telegraphed circle on the hero).

const ENEMIES := {
	"minion": {
		"name": "Risen Bones", "model": "Skeleton_Minion", "weapons": {"handslot.r": "Skeleton_Blade.gltf"},
		"ai": "melee", "hp": 32.0, "dmg": 9.0, "speed": 3.5, "radius": 0.42, "reach": 1.25,
		"windup": 0.38, "cooldown": 1.1, "mass": 1.0, "xp": 1, "scale": 1.0,
		"anim": {"idle": "Skeletons_Idle", "run": "Running_A", "attack": "Melee_1H_Attack_Chop", "spawn": "Skeletons_Awaken_Standing", "die": "Skeletons_Death", "hit": "Hit_B"},
	},
	"warrior": {
		"name": "Barrow Guard", "model": "Skeleton_Warrior", "weapons": {"handslot.r": "Skeleton_Axe.gltf", "handslot.l": "Skeleton_Shield_Large_A.gltf"},
		"ai": "melee", "hp": 125.0, "dmg": 19.0, "speed": 2.6, "radius": 0.6, "reach": 1.55,
		"windup": 0.6, "cooldown": 1.6, "mass": 3.5, "xp": 3, "scale": 1.12,
		"anim": {"idle": "Skeletons_Idle", "run": "Skeletons_Walking", "attack": "Melee_1H_Attack_Slice_Diagonal", "spawn": "Skeletons_Awaken_Standing", "die": "Skeletons_Death", "hit": "Hit_A"},
	},
	"rogue": {
		"name": "Crypt Stalker", "model": "Skeleton_Rogue", "weapons": {"handslot.r": "Skeleton_Crossbow.gltf"},
		"ai": "ranged", "hp": 46.0, "dmg": 12.0, "speed": 3.1, "radius": 0.45, "reach": 8.0,
		"windup": 0.75, "cooldown": 2.4, "mass": 1.0, "xp": 2, "scale": 1.0, "proj_speed": 13.0,
		"anim": {"idle": "Ranged_1H_Aiming", "run": "Running_A", "attack": "Ranged_1H_Shoot", "spawn": "Skeletons_Awaken_Standing", "die": "Skeletons_Death", "hit": "Hit_B"},
	},
	"mage": {
		"name": "Bone Hexer", "model": "Skeleton_Mage", "weapons": {"handslot.r": "Skeleton_Staff.gltf"},
		"ai": "caster", "hp": 60.0, "dmg": 24.0, "speed": 2.7, "radius": 0.45, "reach": 9.0,
		"windup": 1.15, "cooldown": 4.0, "mass": 1.2, "xp": 3, "scale": 1.0, "blast": 1.9,
		"anim": {"idle": "Skeletons_Idle", "run": "Skeletons_Walking", "attack": "Ranged_Magic_Spellcasting", "spawn": "Skeletons_Awaken_Standing", "die": "Skeletons_Death", "hit": "Hit_B"},
	},
}

## Added foes. bomber: runs in and detonates (hurts other skeletons too).
## necro: keeps its distance and raises minions. robber: the treasure goblin.
const ENEMIES_EXTRA := {
	"bomber": {
		"name": "Pumpkin Bomber", "model": "Skeleton_Minion", "weapons": {"handslot.r": "res://assets/kaykit/graveyard/pumpkin_orange_jackolantern.gltf"},
		"ai": "bomb", "hp": 22.0, "dmg": 38.0, "speed": 4.3, "radius": 0.42, "reach": 1.7,
		"windup": 0.75, "cooldown": 9.0, "mass": 1.0, "xp": 2, "scale": 1.0, "blast": 2.4, "tint": Color(1.0, 0.5, 0.1, 0.4),
		"anim": {"idle": "Skeletons_Idle", "run": "Running_A", "attack": "Melee_1H_Attack_Chop", "spawn": "Skeletons_Awaken_Standing", "die": "Skeletons_Death", "hit": "Hit_B"},
	},
	"necro": {
		"name": "Grave Caller", "model": "Skeleton_Mage", "weapons": {"handslot.r": "Skeleton_Staff.gltf"},
		"ai": "necro", "hp": 90.0, "dmg": 0.0, "speed": 2.6, "radius": 0.5, "reach": 9.0,
		"windup": 1.3, "cooldown": 7.0, "mass": 1.5, "xp": 5, "scale": 1.18, "blast": 3.0, "tint": Color(0.7, 0.3, 1.0, 0.45),
		"anim": {"idle": "Skeletons_Idle", "run": "Skeletons_Walking", "attack": "Ranged_Magic_Summon", "spawn": "Skeletons_Awaken_Standing", "die": "Skeletons_Death", "hit": "Hit_B"},
	},
	"hound": {
		"name": "Grave Hound", "model": "Skeleton_Rogue", "weapons": {"handslot.r": "Skeleton_Blade.gltf"},
		"ai": "charge", "hp": 58.0, "dmg": 17.0, "speed": 3.9, "radius": 0.45, "reach": 1.4,
		"windup": 0.6, "cooldown": 2.8, "mass": 1.0, "xp": 2, "scale": 0.95, "tint": Color(1.0, 0.3, 0.25, 0.4),
		"anim": {"idle": "Skeletons_Idle", "run": "Running_A", "attack": "Melee_1H_Attack_Chop", "spawn": "Skeletons_Awaken_Standing", "die": "Skeletons_Death", "hit": "Hit_B"},
	},
	"brute": {
		"name": "Bone Brute", "model": "Skeleton_Warrior", "weapons": {"handslot.r": "axe_2handed.gltf"},
		"ai": "slam", "hp": 520.0, "dmg": 36.0, "speed": 2.2, "radius": 0.85, "reach": 2.8,
		"windup": 1.0, "cooldown": 3.4, "mass": 6.0, "xp": 8, "scale": 1.55, "blast": 3.2, "tint": Color(0.7, 0.45, 0.3, 0.3),
		"anim": {"idle": "Skeletons_Idle", "run": "Skeletons_Walking", "attack": "Melee_2H_Attack_Chop", "spawn": "Skeletons_Awaken_Standing", "die": "Skeletons_Death", "hit": "Hit_B"},
	},
	"robber": {
		"name": "Grave Robber", "model": "Skeleton_Rogue", "weapons": {},
		"ai": "flee", "hp": 260.0, "dmg": 0.0, "speed": 6.2, "radius": 0.45, "reach": 0.0,
		"windup": 1.0, "cooldown": 99.0, "mass": 1.0, "xp": 10, "scale": 1.1, "tint": Color(1.0, 0.8, 0.2, 0.55),
		"anim": {"idle": "Skeletons_Idle", "run": "Running_A", "attack": "Melee_1H_Attack_Chop", "spawn": "Skeletons_Awaken_Standing", "die": "Skeletons_Death", "hit": "Hit_B"},
	},
}

const BOSSES := {
	"gravemaw": {
		"name": "Gravemaw", "title": "the Barrow King", "wake": "the Barrow King wakes", "fall": "Gravemaw falls. Take what is yours.",
		"model": "Skeleton_Warrior", "weapons": {"handslot.r": "axe_2handed.gltf", "handslot.l": "Skeleton_Shield_Large_B.gltf"},
		"hp": 3400.0, "dmg": 26.0, "speed": 3.0, "radius": 1.5, "scale": 2.6, "mass": 40.0,
		"color": Color(0.4, 1.0, 0.75), "source": "boss", "occluder": Vector2(1.8, 5.0), "summon_line": "The King calls his dead!",
	},
	"hexer": {
		"name": "Hexer Queen", "title": "of the Sunken Crypt", "wake": "the Queen of the Crypt rises", "fall": "The Hexer Queen unravels. Take what is yours.",
		"model": "Skeleton_Mage", "weapons": {"handslot.r": "Skeleton_Staff.gltf"},
		"hp": 3900.0, "dmg": 23.0, "speed": 3.3, "radius": 1.25, "scale": 2.3, "mass": 30.0,
		"color": Color(0.75, 0.4, 1.0), "source": "hexer", "occluder": Vector2(1.4, 4.6), "summon_line": "The Queen calls her cult!",
	},
}

## The places a hunt can happen. `weights` scale how often each foe is drawn.
## `env` drives the arena's light; `unlock` is a human line for the locked card.
const ZONES := {
	"barrow": {
		"name": "The Barrow", "boss": "gravemaw", "blurb": "A walled graveyard under a cold moon.",
		"wake": "Gather %d souls to wake the King", "defeat": "The Barrow keeps you", "enter": "Enter the Barrow",
		"weights": {}, "souls_mult": 1.0, "unlock": "",
		"env": {"bg": Color(0.015, 0.02, 0.035), "ambient": Color(0.32, 0.38, 0.58), "ambient_e": 0.3, "fog": Color(0.09, 0.11, 0.17), "fog_d": 0.012,
			"sun": Color(0.62, 0.7, 1.0), "sun_e": 0.5, "sun_rot": Vector3(-58, -32, 0), "mist": Color(0.55, 0.62, 0.8, 0.13), "motes": Color(0.55, 1.0, 0.7, 0.9)},
	},
	"depths": {
		"name": "The Sunken Crypt", "boss": "hexer", "blurb": "Torchlit halls under the barrow. The Queen's cult waits.",
		"wake": "Gather %d souls to wake the Queen", "defeat": "The Crypt keeps you", "enter": "Descend into the Crypt",
		"loot_bonus": 1, "weights": {"minion": 0.8, "warrior": 0.8, "rogue": 1.4, "mage": 1.8, "necro": 1.5, "hound": 1.4, "brute": 1.6}, "souls_mult": 1.0, "unlock": "Clear Veteran in the Barrow",
		"env": {"bg": Color(0.02, 0.012, 0.03), "ambient": Color(0.4, 0.3, 0.55), "ambient_e": 0.34, "fog": Color(0.1, 0.06, 0.14), "fog_d": 0.016,
			"sun": Color(0.7, 0.62, 1.0), "sun_e": 0.28, "sun_rot": Vector3(-78, -20, 0), "mist": Color(0.6, 0.45, 0.8, 0.09), "motes": Color(1.0, 0.65, 0.35, 0.9)},
	},
}
const ZONE_ORDER := ["barrow", "depths"]

## How a hunt is played. horde: the soul meter fills, the boss wakes. trial:
## the Long Road, a generated dungeon of rooms to fight through, boss at the
## end. `rooms` is per difficulty tier.
const MODES := {
	"horde": {"name": "Horde Hunt", "short": "Horde", "blurb": "Hold the graveyard against the rising dead."},
	"trial": {"name": "The Long Road", "short": "Long Road", "blurb": "Fight room by room down a new dungeon to the boss.", "rooms": [5, 6, 7]},
	"descent": {"name": "Endless Descent", "short": "Descent", "blurb": "The dead never stop. Each minute goes a level deeper; a boss every fifth. How deep can you go?", "unlock": "Win on Normal to open"},
	"wild": {"name": "The Wilderness", "short": "Wilderness", "blurb": "A closing ring and rival bands hunting you. Be the last band standing.", "unlock": "Win on Normal to open"},
	"rush": {"name": "Boss Rush", "short": "Boss Rush", "blurb": "Both bosses, twice, back to back. A card and a breath between each.", "unlock": "Win on Normal to open"},
}
## Endless Descent: the horde never stops. Every DESCENT_TIME seconds the depth
## rises (foes grow tougher, a champion arrives); every fifth depth a boss.
## Chests by depth reached; foes scale by DESCENT_HP / DESCENT_DMG per depth.
const DESCENT_TIME := 60.0
const DESCENT_BOSS_EVERY := 5
const DESCENT_HP := 0.16
const DESCENT_DMG := 0.08
const DESCENT_CHESTS := [[15, "crypt"], [10, "gold"], [5, "silver"]]
## Boss Rush: the zone's bosses in turn, each empowered on the second lap.
const RUSH_ORDER := [["gravemaw", 1.0], ["hexer", 1.0], ["gravemaw", 1.5], ["hexer", 1.5]]
const RUSH_GAP := 7.0
## The Wilderness: a royale on a closing ring. Rival bands (hero-built foes)
## hunt you while the dead rise; the last band standing wins. Ring radius by
## time: [seconds, radius] keyframes, linear between. Rivals per tier.
const WILD_CENTER := Vector3(0, 0, -5)
const WILD_RING := [[0.0, 34.0], [35.0, 34.0], [60.0, 22.0], [95.0, 22.0], [120.0, 14.0], [150.0, 14.0], [170.0, 8.0], [200.0, 8.0], [225.0, 4.5]]
const WILD_RIVALS := [5, 6, 7]
const WILD_PVE := 0.5

static func wild_ring(t: float) -> float:
	for i in range(1, WILD_RING.size()):
		var a: Array = WILD_RING[i - 1]
		var b: Array = WILD_RING[i]
		if t <= float(b[0]):
			return lerpf(float(a[1]), float(b[1]), clampf((t - float(a[0])) / maxf(float(b[0]) - float(a[0]), 0.01), 0.0, 1.0))
	return float(WILD_RING[WILD_RING.size() - 1][1])


## A rival band member built from a hero: the same model and weapons, fought
## with the foe AI that matches its style. Tuned a little under the player.
static func rival_def(hero_id: String) -> Dictionary:
	var h: Dictionary = HEROES[hero_id]
	var anim: Dictionary = {"idle": h["anim"]["idle"], "run": h["anim"]["run"], "attack": h["anim"]["attack"][0], "spawn": "Spawn_Ground", "die": "Death_A", "hit": "Hit_A"}
	var d: Dictionary = {"name": "Rival %s" % h["name"], "model": h["model"], "weapons": h["weapons"], "rival": true, "tint": Color(1.0, 0.35, 0.3, 0.22), "anim": anim, "radius": 0.5, "mass": 3.0, "xp": 14, "scale": 1.0}
	match hero_id:
		"knight":
			d.merge({"ai": "melee", "hp": 560.0, "dmg": 22.0, "speed": 4.4, "reach": 2.3, "windup": 0.45, "cooldown": 1.0})
		"barbarian":
			d.merge({"ai": "melee", "hp": 700.0, "dmg": 32.0, "speed": 4.1, "reach": 2.7, "windup": 0.6, "cooldown": 1.4})
		"ranger":
			d.merge({"ai": "ranged", "hp": 400.0, "dmg": 18.0, "speed": 4.2, "reach": 9.0, "windup": 0.55, "cooldown": 1.5, "proj_speed": 15.0})
		_:
			d.merge({"ai": "caster", "hp": 360.0, "dmg": 28.0, "speed": 3.9, "reach": 8.5, "windup": 1.0, "cooldown": 3.0, "blast": 2.0})
	return d

const MODE_ORDER := ["horde", "trial", "descent", "rush", "wild"]

static func zone(id: String) -> Dictionary:
	return ZONES[id] if ZONES.has(id) else ZONES["barrow"]


static func boss_def(id: String) -> Dictionary:
	return BOSSES[id] if BOSSES.has(id) else BOSSES["gravemaw"]

## Elite affixes: Diablo-style champions. Each multiplies or adds a trait.
const ELITE_AFFIXES := {
	"vampiric": {"name": "Vampiric", "color": Color(0.9, 0.12, 0.2)},
	"swift": {"name": "Swift", "color": Color(0.3, 0.9, 1.0)},
	"molten": {"name": "Molten", "color": Color(1.0, 0.45, 0.1)},
	"warded": {"name": "Warded", "color": Color(0.55, 0.5, 1.0)},
	"frozen": {"name": "Frozen", "color": Color(0.6, 0.88, 1.0)},
	"jailer": {"name": "Jailer", "color": Color(0.8, 0.68, 0.4)},
	"mortar": {"name": "Mortar", "color": Color(1.0, 0.82, 0.3)},
	"plagued": {"name": "Plagued", "color": Color(0.55, 0.9, 0.3)},
	"arcane": {"name": "Arcane", "color": Color(0.95, 0.45, 1.0)},
}
const ELITE_NAMES_A := ["Grim", "Hollow", "Rot", "Ash", "Marrow", "Pale", "Vile", "Dread", "Cairn", "Gloom"]
const ELITE_NAMES_B := ["jaw", "bone", "shank", "skull", "rib", "grin", "maw", "knuckle", "spine", "tooth"]
const ELITE_TITLES := ["the Restless", "the Unburied", "the Hungering", "the Forsworn", "the Silent", "of the Low Barrow"]

# --- Difficulty tiers ----------------------------------------------------

const TIERS := [
	{"id": "normal", "name": "Normal", "hp": 1.0, "dmg": 1.0, "spd": 1.0, "press": 1.0, "souls": 110, "loot": 1.0, "gold": 1.0, "xp": 1.0, "chest": "silver", "color": Color(0.8, 0.8, 0.8)},
	{"id": "veteran", "name": "Veteran", "hp": 2.6, "dmg": 2.1, "spd": 1.08, "press": 1.25, "souls": 140, "loot": 1.6, "gold": 1.8, "xp": 1.6, "chest": "gold", "color": Color(1.0, 0.75, 0.3)},
	{"id": "nightmare", "name": "Nightmare", "hp": 6.5, "dmg": 4.6, "spd": 1.17, "press": 1.5, "souls": 170, "loot": 2.6, "gold": 3.0, "xp": 2.4, "chest": "crypt", "color": Color(0.95, 0.25, 0.25)},
]

# --- Upgrade cards (in-hunt level ups) -----------------------------------
# only: limit to hero styles. max: stacks. rarity drives frame color and weight.

const CARDS := {
	"might": {"name": "Grave Strength", "desc": "+18% damage", "icon": "strong", "rarity": "common", "max": 6},
	"haste": {"name": "Bloodrush", "desc": "+14% attack speed", "icon": "lightning-tear", "rarity": "common", "max": 6},
	"vigor": {"name": "Iron Hide", "desc": "+20% max health and heal 30%", "icon": "heart-plus", "rarity": "common", "max": 5},
	"swift": {"name": "Fleetfoot", "desc": "+9% move speed", "icon": "running-shoe", "rarity": "common", "max": 4},
	"magnet": {"name": "Soul Grasp", "desc": "Pick up souls and gold from farther away", "icon": "magnet", "rarity": "common", "max": 3},
	"crit": {"name": "Deathmark", "desc": "+9% critical chance", "icon": "bullseye", "rarity": "rare", "max": 5},
	"regen": {"name": "Second Breath", "desc": "Regenerate 1.2% health per second", "icon": "health-normal", "rarity": "rare", "max": 4},
	"leech": {"name": "Bloodthirst", "desc": "Heal 3% of damage dealt", "icon": "dripping-sword", "rarity": "rare", "max": 4},
	"dash": {"name": "Shadowstep", "desc": "Dash recharges 20% faster", "icon": "sprint", "rarity": "common", "max": 3},
	"wrath": {"name": "Wrath", "desc": "Super charges 25% faster", "icon": "explosion-rays", "rarity": "rare", "max": 3},
	"multishot": {"name": "Split Shot", "desc": "+1 projectile", "icon": "arrow-cluster", "rarity": "epic", "max": 3, "only": ["bow", "magic"]},
	"pierce": {"name": "Barbed Arrows", "desc": "Arrows pierce one more foe", "icon": "barbed-arrow", "rarity": "rare", "max": 3, "only": ["bow"]},
	"inferno": {"name": "Inferno", "desc": "+35% blast radius", "icon": "fireball", "rarity": "rare", "max": 3, "only": ["magic"]},
	"reach": {"name": "Long Reach", "desc": "+25% swing size", "icon": "sword-spin", "rarity": "rare", "max": 3, "only": ["melee"]},
	"wave": {"name": "Sword Wave", "desc": "Swings launch a cutting wave", "icon": "crossed-swords", "rarity": "epic", "max": 3, "only": ["melee"]},
	"blades": {"name": "Orbiting Blades", "desc": "Spectral blades circle you", "icon": "spinning-blades", "rarity": "epic", "max": 4, "only": ["melee"]},
	"storm": {"name": "Storm Call", "desc": "Lightning strikes chained foes", "icon": "lightning-helix", "rarity": "epic", "max": 4, "only": ["magic"]},
	"nova": {"name": "Fire Nova", "desc": "A ring of fire bursts around you", "icon": "fire-ring", "rarity": "epic", "max": 4, "only": ["magic"]},
	"ward": {"name": "Bone Ward", "desc": "A shield blocks one hit, recharging", "icon": "bolt-shield", "rarity": "rare", "max": 3},
	"thorns": {"name": "Thorns", "desc": "Melee attackers take 60% of the hit", "icon": "slashed-shield", "rarity": "rare", "max": 3, "only": ["melee"]},
	"smite": {"name": "Holy Smite", "desc": "Lightning falls from the heavens on nearby foes", "icon": "sun", "rarity": "epic", "max": 4, "hero": ["knight"]},
	"quake": {"name": "Earthshaker", "desc": "The ground bursts around you, hurling foes back", "icon": "fist", "rarity": "epic", "max": 4, "hero": ["barbarian"]},
	"axes": {"name": "Thrown Axes", "desc": "Hurl spinning axes that cut through the horde", "icon": "crossed-axes", "rarity": "epic", "max": 4, "hero": ["barbarian"]},
	"meteor": {"name": "Meteor Shower", "desc": "Meteors rain down on your enemies", "icon": "meteor-impact", "rarity": "epic", "max": 4, "hero": ["mage"]},
	"frost": {"name": "Frost Ring", "desc": "A ring of ice freezes everything near you", "icon": "frozen-orb", "rarity": "epic", "max": 4, "hero": ["mage"]},
	"barrage": {"name": "Arrow Storm", "desc": "A hail of arrows falls on the thickest crowd", "icon": "arrow-cluster", "rarity": "epic", "max": 4, "hero": ["ranger"]},
	"explosive": {"name": "Explosive Arrows", "desc": "Every few volleys one arrow bursts into flame", "icon": "fireball", "rarity": "rare", "max": 3, "hero": ["ranger"]},
	"greed": {"name": "Grave Robber", "desc": "+30% gold", "icon": "two-coins", "rarity": "common", "max": 3},
	"bladestorm": {"name": "Bladestorm", "desc": "Twice the blades, spinning faster", "icon": "spinning-sword", "rarity": "legendary", "max": 1, "evo": ["blades", "haste"]},
	"tempest": {"name": "Tempest", "desc": "Storm Call strikes 3 more foes, and crits call lightning", "icon": "lightning-helix", "rarity": "legendary", "max": 1, "evo": ["storm", "crit"], "only": ["magic"]},
	"inferno_heart": {"name": "Inferno Heart", "desc": "Fire Nova is half again as wide and heals you", "icon": "flame", "rarity": "legendary", "max": 1, "evo": ["nova", "vigor"], "only": ["magic"]},
	"rain": {"name": "Rain of Arrows", "desc": "Every third volley fires a full circle", "icon": "arrow-cluster", "rarity": "legendary", "max": 1, "evo": ["multishot", "pierce"], "only": ["bow"]},
	"judgement_day": {"name": "Judgement Day", "desc": "Sword waves are twice as wide and stun", "icon": "crossed-swords", "rarity": "legendary", "max": 1, "evo": ["wave", "reach"], "only": ["melee"]},
	"armageddon": {"name": "Armageddon", "desc": "Meteors fall twice as many and twice as hard", "icon": "meteor-impact", "rarity": "legendary", "max": 1, "evo": ["meteor", "inferno"], "hero": ["mage"]},
	"heavens": {"name": "Wrath of Heaven", "desc": "Holy Smite strikes three more foes and stuns them", "icon": "sun", "rarity": "legendary", "max": 1, "evo": ["smite", "might"], "hero": ["knight"]},
	"fault": {"name": "Faultline", "desc": "Earthshaker cracks the earth twice as wide", "icon": "fist", "rarity": "legendary", "max": 1, "evo": ["quake", "reach"], "hero": ["barbarian"]},
	"deluge": {"name": "Deluge", "desc": "Arrow Storm falls twice, a second wave behind the first", "icon": "arrow-cluster", "rarity": "legendary", "max": 1, "evo": ["barrage", "multishot"], "hero": ["ranger"]},
	"phoenix": {"name": "Undying", "desc": "Once per hunt, rise again at half health", "icon": "ghost", "rarity": "legendary", "max": 1},
}
const CARD_WEIGHT := {"common": 10.0, "rare": 6.0, "epic": 3.2, "legendary": 0.8}

## All foe definitions, base and extra.
static func enemy(kind: String) -> Dictionary:
	if kind.begins_with("rival_"):
		return rival_def(kind.substr(6))
	return ENEMIES[kind] if ENEMIES.has(kind) else ENEMIES_EXTRA[kind]


static func enemy_kinds() -> Array:
	return ENEMIES.keys() + ENEMIES_EXTRA.keys()


## Daily bounties: three are drawn per calendar day. `stat` is summed over
## hunts (or the best single hunt with `best`); `win` counts only won hunts,
## `veteran` only wins on Veteran or harder, `hero` ties it to a hero.
## targets/gold are parallel lists (easy → hard); shards go to the hero named.
const BOUNTY_POOL := {
	"kills": {"text": "Slay %d skeletons", "stat": "kills", "targets": [120, 220], "gold": [150, 300]},
	"elites": {"text": "Slay %d champions", "stat": "elites", "targets": [3, 6], "gold": [180, 360]},
	"boss": {"text": "Slay the Gravemaw", "stat": "wins", "targets": [1], "gold": [250], "win": true},
	"hero": {"text": "Win a hunt as the %s", "stat": "wins", "targets": [1], "gold": [200], "win": true, "hero": true, "shards": 3},
	"veteran": {"text": "Clear Veteran", "stat": "wins", "targets": [1], "gold": [400], "win": true, "veteran": true, "shards": 4},
	"gold": {"text": "Collect %d gold in hunts", "stat": "gold", "targets": [300, 600], "gold": [150, 300]},
	"level": {"text": "Reach level %d in one hunt", "stat": "level", "targets": [8, 10], "gold": [150, 250], "best": true},
}
const BOUNTIES_PER_DAY := 3

## Shrines in the graveyard: stand in the ring for a moment to take the
## blessing for SHRINE_TIME seconds. Each hunt assigns the three at random.
const SHRINES := {
	"fury": {"name": "Shrine of Fury", "short": "Fury", "color": Color(1.0, 0.35, 0.2), "dmg": 1.5},
	"haste": {"name": "Shrine of Haste", "short": "Haste", "color": Color(0.35, 0.9, 1.0), "rate": 1.4, "speed": 1.2},
	"bones": {"name": "Shrine of Bones", "short": "Bones", "color": Color(0.85, 0.85, 0.65), "armor": 0.35},
}
const SHRINE_TIME := 20.0
## The cursed shrine: standing in it calls a champion pack; outlast CURSE_TIME
## seconds with the hero alive and it pays out a card and a rare.
const CURSE := {"name": "Cursed Shrine", "color": Color(0.85, 0.25, 0.95)}
const CURSE_TIME := 20.0
## The health potion: one button, a long recharge that champions' deaths shorten.
const POTION := {"cd": 50.0, "heal": 0.45, "elite_cd": 10.0}

## Pacts: offered once mid-hunt. Each is a gain and a price, or refuse both.
## `mod` keys: dmg rate hp armor gold xp (hero), foe_speed foe_hp pack (foes),
## dmg_taken (hero takes more).
const PACTS := {
	"blood": {"name": "Blood Pact", "good": "+40% damage", "bad": "Foes move 15% faster", "icon": "dripping-sword", "mod": {"dmg": 0.4, "foe_speed": 0.15}},
	"glass": {"name": "Glass Soul", "good": "+35% attack speed", "bad": "You take 25% more damage", "icon": "lightning-tear", "mod": {"rate": 0.35, "dmg_taken": 0.25}},
	"greed": {"name": "Gilded Hunger", "good": "+60% gold", "bad": "30% more foes", "icon": "two-coins", "mod": {"gold": 0.6, "pack": 0.3}},
	"vow": {"name": "Iron Vow", "good": "+35% health, +8% armor", "bad": "-15% attack speed", "icon": "checked-shield", "mod": {"hp": 0.35, "armor": 0.08, "rate": -0.15}},
	"moon": {"name": "Hunter's Moon", "good": "+30% souls", "bad": "Foes have 25% more health", "icon": "moon", "mod": {"xp": 0.3, "foe_hp": 0.25}},
}

## Renown road: every hunt earns renown; each step hands out a reward in order.
## Step n (1-based) opens at road_threshold(n).
static func road_threshold(n: int) -> int:
	return 60 * n + 10 * n * (n - 1)


## What step n pays: gold, a chest opened on the spot, or shards for the hero
## in use. Every fourth step is a chest, better as the road goes on.
static func road_reward(n: int) -> Dictionary:
	match n % 4:
		1:
			return {"kind": "gold", "amount": 100 + 25 * n}
		2:
			return {"kind": "shards", "amount": 5 + n / 2}
		3:
			return {"kind": "gold", "amount": 160 + 30 * n}
	return {"kind": "chest", "chest": "silver" if n < 12 else ("gold" if n < 24 else "crypt")}


## Weekly omens: one rule twist for a week, with a bigger chest. `mod` keys are
## the same as PACTS'; `no_dash` removes the dash.
const WEEKLY_OMENS := [
	{"id": "swarm", "name": "The Swarm", "desc": "Half again as many foes, each a little frailer.", "icon": "bone-gnawer", "mod": {"pack": 0.5, "foe_hp": -0.2}},
	{"id": "still", "name": "Stillness", "desc": "No dash. Your super charges twice as fast.", "icon": "hourglass", "mod": {"super": 1.0}, "no_dash": true},
	{"id": "swiftdead", "name": "The Swift Dead", "desc": "Every foe moves 20% faster.", "icon": "running-shoe", "mod": {"foe_speed": 0.2}},
	{"id": "glass", "name": "Glass Hunt", "desc": "+60% damage, but you have 40% less health.", "icon": "broken-bone", "mod": {"dmg": 0.6, "hp": -0.4}},
	{"id": "ironclad", "name": "Ironclad Dead", "desc": "Foes have 50% more health; you take 20% less damage.", "icon": "checked-shield", "mod": {"foe_hp": 0.5, "dmg_taken": -0.2}},
	{"id": "frenzy", "name": "Blood Frenzy", "desc": "Foes hit 30% harder; you attack 30% faster.", "icon": "dripping-sword", "mod": {"rate": 0.3, "foe_dmg": 0.3}},
]
## A won omen hunt pays 25% more gold and its chest is one grade better.
const OMEN_GOLD := 0.25

## Treasure trails: a clue scroll is three goals in a row, then a casket.
## `text` takes the number or hero name.
const CLUE_GOALS := {
	"elites": {"text": "Slay %d champions in one hunt", "n": 3},
	"win_hero": {"text": "Win a hunt as the %s"},
	"nodash": {"text": "Win a hunt using the dash %d times or fewer", "n": 10},
	"depth": {"text": "Reach depth %d in the Endless Descent", "n": 4},
	"veteran": {"text": "Win on Veteran or harder"},
	"fast": {"text": "Slay a boss within %d seconds of it waking", "n": 100},
	"gold": {"text": "Collect %d gold in one hunt", "n": 350},
}
const CLUE_STEPS := 3

## Kill-streak milestones ("Massacre"): reaching one pays bonus souls and gold.
## A streak ends after STREAK_WINDOW seconds without a kill.
const STREAKS := [15, 30, 50, 100]
const STREAK_WINDOW := 2.5

## XP (souls) needed for each in-hunt level: grows gently so the first few
## choices come fast and the later ones mark real progress.
static func run_level_xp(level: int) -> int:
	return int(round(5.0 + level * 4.0 + pow(level, 1.6)))

# --- Items ---------------------------------------------------------------

const SLOTS := ["weapon", "helm", "chest", "legs", "trinket"]
const SLOT_NAME := {"weapon": "Weapon", "helm": "Helm", "chest": "Chest", "legs": "Legs", "trinket": "Offhand"}
const SLOT_ICON := {"weapon": "broadsword", "helm": "visored-helm", "chest": "breastplate", "legs": "leg-armor", "trinket": "shield"}
const ITEM_BASES := {
	"weapon": ["Brand", "Cleaver", "Edge", "Fang", "Reaver"],
	"helm": ["Helm", "Sallet", "Cowl", "Crown", "Visage"],
	"chest": ["Mail", "Hauberk", "Plate", "Shroud", "Carapace"],
	"legs": ["Greaves", "Leggings", "Cuisses", "Treads", "Wraps"],
	"trinket": ["Charm", "Talisman", "Sigil", "Amulet", "Idol"],
}
## Short stat names for compare lines, and whether the number is a percent.
const AFFIX_SHORT := {
	"dmg": ["Damage", "%"], "hp": ["Health", "%"], "aspd": ["Attack speed", "%"], "crit": ["Crit chance", "%"],
	"speed": ["Move speed", "%"], "armor": ["Armor", "%"], "gold": ["Gold found", "%"], "regen": ["Regen", "/s"],
}
const ITEM_PREFIX := {
	"common": ["Worn", "Plain", "Rusted", "Old"],
	"magic": ["Gravewoven", "Moonlit", "Hallowed", "Ashen"],
	"rare": ["Barrowborn", "Wraithbound", "Bloodsworn", "Nightfall"],
}
## Affix pool: stat key -> [min, max] per rarity step, and its label.
const AFFIXES := {
	"dmg": {"label": "+%d%% damage", "roll": [6, 12]},
	"hp": {"label": "+%d%% health", "roll": [8, 14]},
	"aspd": {"label": "+%d%% attack speed", "roll": [5, 9]},
	"crit": {"label": "+%d%% critical chance", "roll": [3, 6]},
	"speed": {"label": "+%d%% move speed", "roll": [3, 6]},
	"armor": {"label": "+%d%% damage reduction", "roll": [3, 6]},
	"gold": {"label": "+%d%% gold found", "roll": [10, 20]},
	"regen": {"label": "+%d health per second", "roll": [2, 4]},
}
const SLOT_MAIN := {"weapon": "dmg", "helm": "crit", "chest": "hp", "legs": "armor", "trinket": "aspd"}
const SLOT_POOL := {
	"weapon": ["aspd", "crit", "dmg"],
	"helm": ["hp", "armor", "regen"],
	"chest": ["armor", "regen", "hp"],
	"legs": ["speed", "hp", "regen"],
	"trinket": ["gold", "speed", "regen", "crit"],
}

## Unique drops tracked by the collection log. `card` legendaries start the
## hunt holding that card. Rates are 1/n per roll on that source.
const UNIQUES := {
	"cleaver": {"cls": "barbarian", "dye": Color(0.45, 0.95, 0.7), "name": "Gravemaw's Cleaver", "slot": "weapon", "rarity": "legendary", "source": "boss", "rate": 25, "stats": {"dmg": 30, "aspd": 10}, "card": "blades", "power": "Start every hunt with Orbiting Blades", "icon": "battle-axe"},
	"shroud": {"cls": "ranger", "dye": Color(0.12, 0.28, 0.22), "name": "Shroud of the Barrow", "slot": "chest", "rarity": "legendary", "source": "boss", "rate": 25, "stats": {"hp": 30, "armor": 8}, "card": "ward", "power": "Start every hunt with Bone Ward", "icon": "breastplate"},
	"crown": {"cls": "knight", "dye": Color(0.95, 0.78, 0.3), "name": "Crown of the Barrow King", "slot": "helm", "rarity": "legendary", "source": "boss", "rate": 40, "stats": {"crit": 10, "gold": 25}, "card": "smite", "power": "Start every hunt with Holy Smite", "icon": "crowned-skull"},
	"emberheart": {"cls": "mage", "dye": Color(1.0, 0.4, 0.1), "name": "Emberheart", "slot": "trinket", "rarity": "legendary", "source": "elite", "rate": 60, "stats": {"dmg": 12, "regen": 4}, "card": "nova", "power": "Start every hunt with Fire Nova", "icon": "flame"},
	"scepter": {"cls": "mage", "dye": Color(0.75, 0.4, 1.0), "name": "Hexer's Scepter", "slot": "weapon", "rarity": "legendary", "source": "hexer", "rate": 25, "stats": {"dmg": 26, "crit": 8}, "card": "leech", "power": "Start every hunt with Bloodthirst", "icon": "wizard-staff"},
	"gown": {"cls": "mage", "dye": Color(0.45, 0.2, 0.6), "name": "Gown of Thorns", "slot": "chest", "rarity": "legendary", "source": "hexer", "rate": 25, "stats": {"hp": 24, "armor": 6}, "card": "frost", "power": "Start every hunt with Frost Ring", "icon": "breastplate"},
	"greaves": {"cls": "knight", "dye": Color(0.5, 0.85, 1.0), "name": "Wraithstep Greaves", "slot": "legs", "rarity": "legendary", "source": "hexer", "rate": 30, "stats": {"speed": 8, "hp": 14}, "card": "regen", "power": "Start every hunt with Second Breath", "icon": "leg-armor"},
	"charm": {"name": "Hex Charm", "slot": "trophy", "rarity": "magic", "source": "hexer", "rate": 4, "icon": "gems", "power": "A cultist's token. Sells for 90 gold.", "sell": 90},
	"bonelet": {"name": "Bonelet", "slot": "pet", "rarity": "legendary", "source": "boss", "rate": 50, "icon": "skull-crossed-bones", "power": "A tiny skeleton that follows you everywhere."},
	"sigil": {"name": "Champion's Sigil", "slot": "trophy", "rarity": "rare", "source": "elite", "rate": 12, "icon": "rune-stone", "power": "Proof of a champion slain. Sells for 150 gold.", "sell": 150},
	"tooth": {"name": "Barrow Tooth", "slot": "trophy", "rarity": "magic", "source": "boss", "rate": 4, "icon": "broken-bone", "power": "An old king's tooth. Sells for 60 gold.", "sell": 60},
	"abyssal": {"name": "Abyssal Gem", "slot": "trophy", "rarity": "legendary", "source": "nightmare", "rate": 80, "icon": "crystal-shine", "power": "It hums. Sells for 2000 gold.", "sell": 2000},
}
const LOG_ORDER := ["cleaver", "shroud", "crown", "bonelet", "tooth", "scepter", "gown", "greaves", "charm", "emberheart", "sigil", "abyssal"]

## Rarity weights by source; tier loot multiplier shifts weight upward.
const DROP_RARITY := {
	"trash": {"common": 70.0, "magic": 26.0, "rare": 4.0, "legendary": 0.0},
	"elite": {"common": 20.0, "magic": 50.0, "rare": 28.0, "legendary": 2.0},
	"boss": {"common": 0.0, "magic": 45.0, "rare": 45.0, "legendary": 10.0},
	"chest": {"common": 25.0, "magic": 45.0, "rare": 26.0, "legendary": 4.0},
}

const CHESTS := {
	"silver": {"name": "Silver Chest", "model": "chest", "gold": [90, 140], "shards": 10, "items": 1, "color": Color(0.8, 0.85, 0.95)},
	"gold": {"name": "Gold Chest", "model": "chest_gold", "gold": [220, 320], "shards": 18, "items": 2, "color": Color(1.0, 0.8, 0.3)},
	"crypt": {"name": "Crypt Chest", "model": "chest_gold", "gold": [500, 700], "shards": 30, "items": 3, "color": Color(0.95, 0.3, 0.3)},
}

# --- Skills (Old School curve) -------------------------------------------

const SKILLS := ["attack", "strength", "defence", "hitpoints", "ranged", "magic"]
const SKILL_NAME := {"attack": "Attack", "strength": "Strength", "defence": "Defence", "hitpoints": "Hitpoints", "ranged": "Ranged", "magic": "Magic"}
const SKILL_ICON := {"attack": "crossed-swords", "strength": "strong", "defence": "checked-shield", "hitpoints": "heart-organ", "ranged": "high-shot", "magic": "magic-swirl"}
const SKILL_PERK := {
	"attack": "+0.6% attack speed per level",
	"strength": "+1% melee damage per level",
	"defence": "+0.4% damage reduction per level",
	"hitpoints": "+1% health per level",
	"ranged": "+1% bow damage per level",
	"magic": "+1% spell damage per level",
}
## Skill XP per point of damage dealt.
const XP_PER_DAMAGE := 0.16

static var _xp_table: PackedInt32Array

## XP needed to reach `level` (1..99), the RuneScape formula.
static func xp_for_level(level: int) -> int:
	if _xp_table.is_empty():
		_xp_table.resize(100)
		var points := 0.0
		_xp_table[1] = 0
		for lvl in range(1, 99):
			points += floor(lvl + 300.0 * pow(2.0, lvl / 7.0))
			_xp_table[lvl + 1] = int(floor(points / 4.0))
	return _xp_table[clampi(level, 1, 99)]


static func level_for_xp(xp: int) -> int:
	var lvl := 1
	while lvl < 99 and xp >= xp_for_level(lvl + 1):
		lvl += 1
	return lvl


static func combat_level(levels: Dictionary) -> int:
	var base: float = 0.25 * (int(levels.get("defence", 1)) + int(levels.get("hitpoints", 10)))
	var melee: float = 0.325 * (int(levels.get("attack", 1)) + int(levels.get("strength", 1)))
	var rng: float = 0.325 * floor(1.5 * int(levels.get("ranged", 1)))
	var mag: float = 0.325 * floor(1.5 * int(levels.get("magic", 1)))
	return int(floor(base + maxf(melee, maxf(rng, mag))))
