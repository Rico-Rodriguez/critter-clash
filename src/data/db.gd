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


## Gear has one quality ladder you can see: its material tier, grey to red.
## Rarity (how many bonus stats) shows as pips, never as a rival color.
const TIER_COLOR := [
	Color(0.66, 0.64, 0.6), Color(0.42, 0.8, 0.46), Color(0.36, 0.6, 1.0), Color(0.7, 0.46, 1.0),
	Color(1.0, 0.8, 0.3), Color(1.0, 0.52, 0.2), Color(0.95, 0.24, 0.26),
]


## The color a piece shows everywhere (frame, drop beam, name): its tier.
## Pets and trophies have no tier and keep their rarity's color.
static func gear_color(it: Dictionary) -> Color:
	if not str(it.get("slot", "")) in SLOTS:
		return rarity_color(str(it.get("rarity", "common")))
	return TIER_COLOR[clampi(int(it.get("mat", 0)), 0, TIER_COLOR.size() - 1)]

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
	# The Grove Cult (the Hollow Grove's faction): hooded folk, not bones.
	"cutthroat": {
		"name": "Grove Cutthroat", "model": "Rogue_Hooded", "weapons": {"handslot.r": "dagger.gltf"},
		"ai": "melee", "hp": 30.0, "dmg": 10.0, "speed": 4.1, "radius": 0.42, "reach": 1.2,
		"windup": 0.3, "cooldown": 0.95, "mass": 1.0, "xp": 1, "scale": 1.0, "tint": Color(0.35, 0.75, 0.3, 0.3),
		"anim": {"idle": "Idle_A", "run": "Running_A", "attack": "Melee_1H_Attack_Stab", "spawn": "Spawn_Ground", "die": "Death_A", "hit": "Hit_A"},
	},
	"slinger": {
		"name": "Grove Slinger", "model": "Rogue_Hooded", "weapons": {"handslot.r": "crossbow_1handed.gltf"},
		"ai": "ranged", "hp": 42.0, "dmg": 12.0, "speed": 3.4, "radius": 0.45, "reach": 8.5,
		"windup": 0.7, "cooldown": 2.2, "mass": 1.0, "xp": 2, "scale": 1.0, "proj_speed": 14.0, "tint": Color(0.35, 0.75, 0.3, 0.3),
		"anim": {"idle": "Idle_A", "run": "Running_A", "attack": "Ranged_1H_Shoot", "spawn": "Spawn_Ground", "die": "Death_A", "hit": "Hit_A"},
	},
	"shaman": {
		"name": "Thorn Shaman", "model": "Rogue_Hooded", "weapons": {"handslot.r": "staff.gltf"},
		"ai": "caster", "hp": 58.0, "dmg": 22.0, "speed": 2.9, "radius": 0.45, "reach": 9.0,
		"windup": 1.1, "cooldown": 3.8, "mass": 1.2, "xp": 3, "scale": 1.05, "blast": 2.1, "root": true, "tint": Color(0.5, 0.95, 0.35, 0.45),
		"anim": {"idle": "Idle_A", "run": "Walking_A", "attack": "Ranged_Magic_Spellcasting", "spawn": "Spawn_Ground", "die": "Death_A", "hit": "Hit_A"},
	},
	"brawler": {
		"name": "Grove Brawler", "model": "Barbarian", "weapons": {"handslot.r": "axe_1handed.gltf"},
		"ai": "melee", "hp": 130.0, "dmg": 20.0, "speed": 2.9, "radius": 0.6, "reach": 1.6,
		"windup": 0.55, "cooldown": 1.5, "mass": 3.5, "xp": 3, "scale": 1.15, "tint": Color(0.3, 0.55, 0.25, 0.45),
		"anim": {"idle": "Idle_A", "run": "Running_A", "attack": "Melee_1H_Attack_Chop", "spawn": "Spawn_Ground", "die": "Death_A", "hit": "Hit_A"},
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
		"hp": 4250.0, "dmg": 26.0, "speed": 3.0, "radius": 1.5, "scale": 2.6, "mass": 40.0,
		"color": Color(0.4, 1.0, 0.75), "source": "boss", "occluder": Vector2(1.8, 5.0), "summon_line": "The King calls his dead!", "enrage_line": "\"You will lie beside them.\"",
	},
	"thorn": {
		"name": "The Thornmother", "title": "of the Hollow Grove", "wake": "the Thornmother uncurls", "fall": "The Thornmother withers. Take what is yours.",
		"model": "Rogue_Hooded", "weapons": {"handslot.r": "staff.gltf"},
		"hp": 5200.0, "dmg": 25.0, "speed": 3.1, "radius": 1.3, "scale": 2.5, "mass": 35.0,
		"color": Color(0.55, 0.95, 0.35), "source": "thorn", "occluder": Vector2(1.5, 4.8), "summon_line": "The Grove answers its Mother!", "enrage_line": "\"Root and rot. Feed the wood.\"",
	},
	"hexer": {
		"name": "Hexer Queen", "title": "of the Sunken Crypt", "wake": "the Queen of the Crypt rises", "fall": "The Hexer Queen unravels. Take what is yours.",
		"model": "Skeleton_Mage", "weapons": {"handslot.r": "Skeleton_Staff.gltf"},
		"hp": 4700.0, "dmg": 23.0, "speed": 3.3, "radius": 1.25, "scale": 2.3, "mass": 30.0,
		"color": Color(0.75, 0.4, 1.0), "source": "hexer", "occluder": Vector2(1.4, 4.6), "summon_line": "The Queen calls her cult!", "enrage_line": "\"I will unmake you, thread by thread.\"",
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
	"grove": {
		"name": "The Hollow Grove", "boss": "thorn", "blurb": "An autumn wood. The Grove Cult tends its Mother among the roots.",
		"wake": "Gather %d souls to wake the Thornmother", "defeat": "The Grove keeps you", "enter": "Into the Grove",
		"loot_bonus": 2, "weights": {"rogue": 1.3, "mage": 1.4, "hound": 1.5, "necro": 0.0, "brute": 0.8, "bomber": 1.6},
		"faction": {"minion": "cutthroat", "rogue": "slinger", "mage": "shaman", "warrior": "brawler"},
		"souls_mult": 1.0, "unlock": "Clear Expert in the Crypt", "music": "grove", "boss_music": "grove_boss",
		"env": {"bg": Color(0.03, 0.025, 0.015), "ambient": Color(0.55, 0.42, 0.28), "ambient_e": 0.32, "fog": Color(0.16, 0.12, 0.06), "fog_d": 0.014,
			"sun": Color(1.0, 0.72, 0.45), "sun_e": 0.42, "sun_rot": Vector3(-50, -40, 0), "mist": Color(0.75, 0.62, 0.4, 0.1), "motes": Color(0.85, 1.0, 0.45, 0.9)},
	},
}
const ZONE_ORDER := ["barrow", "depths", "grove"]

## How a hunt is played. horde: the soul meter fills, the boss wakes. trial:
## the Long Road, a generated dungeon of rooms to fight through, boss at the
## end. `rooms` is per difficulty tier.
const MODES := {
	"horde": {"name": "Horde Hunt", "short": "Horde", "blurb": "Hold the graveyard against the rising dead."},
	"trial": {"name": "The Long Road", "short": "Long Road", "blurb": "Fight room by room down a new dungeon to the boss.", "rooms": [5, 5, 6, 6, 7, 7, 7, 8]},
	"descent": {"name": "Endless Descent", "short": "Descent", "blurb": "The dead never stop. Each minute goes a level deeper; a boss every fifth. How deep can you go?", "unlock": "Win on Normal to open"},
	"wild": {"name": "The Wilderness", "short": "Wilderness", "blurb": "A closing ring and rival bands hunting you. Be the last band standing.", "unlock": "Win on Normal to open"},
	"rush": {"name": "Boss Rush", "short": "Boss Rush", "blurb": "Both bosses, twice, back to back. A card and a breath between each.", "unlock": "Win on Normal to open"},
	"rift": {"name": "Rift", "short": "Rift", "blurb": "Spend a rift key: one boss at more than twice its strength, and a unique drop if you win.", "unlock": "Reach depth 8 in the Descent for a rift key"},
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
const WILD_RIVALS := [5, 5, 6, 6, 7, 7, 8, 8]
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

const MODE_ORDER := ["horde", "trial", "descent", "rush", "rift", "wild"]

static func zone(id: String) -> Dictionary:
	return ZONES[id] if ZONES.has(id) else ZONES["barrow"]


static func boss_def(id: String) -> Dictionary:
	return BOSSES[id] if BOSSES.has(id) else BOSSES["gravemaw"]

## Elite affixes: Diablo-style champions. Each multiplies or adds a trait.
## The fallen stay on the ground a while, then sink; past CORPSE_MAX the
## oldest sink first (thousands of bodies in a deep Descent cost frames).
const CORPSE_LINGER := 20.0
const CORPSE_MAX := 45

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

## Eight steps, each roughly +60-70% foe health, so there is always a next
## tier a few sessions away instead of one wall. Beyond raw numbers:
##   ai     how cunning foes and bosses are (0 Normal, 1 old Veteran, 2 old
##          Nightmare): leading shots, cutting off, extra boss moves.
##   mech   telegraphed attacks also take this fraction of max health, through
##          armor. Gear cannot tank a mechanic; you have to step out of it.
##   pen    fraction of the hero's armor that foes ignore.
##   heal   multiplier on passive healing (regen, leech, heal-on-hit cards).
##   mat    base material of drops (GearDB.roll_mat).
##   power  recommended hero power (Game.power_score) shown on the card.
const TIERS := [
	{"id": "normal", "name": "Normal", "hp": 1.0, "dmg": 1.0, "spd": 1.0, "press": 1.0, "souls": 150, "loot": 1.0, "gold": 1.0, "xp": 1.0, "chest": "silver",
		"ai": 0.0, "mech": 0.0, "pen": 0.0, "heal": 1.0, "mat": 0, "power": 350, "color": Color(0.8, 0.8, 0.8)},
	{"id": "hard", "name": "Hard", "hp": 1.7, "dmg": 1.45, "spd": 1.04, "press": 1.12, "souls": 160, "loot": 1.3, "gold": 1.4, "xp": 1.3, "chest": "silver",
		"ai": 0.5, "mech": 0.04, "pen": 0.05, "heal": 0.95, "mat": 1, "power": 550, "color": Color(0.6, 0.85, 0.55)},
	{"id": "veteran", "name": "Veteran", "hp": 2.9, "dmg": 2.1, "spd": 1.08, "press": 1.25, "souls": 170, "loot": 1.6, "gold": 1.8, "xp": 1.6, "chest": "gold",
		"ai": 1.0, "mech": 0.08, "pen": 0.1, "heal": 0.85, "mat": 2, "power": 850, "color": Color(1.0, 0.75, 0.3)},
	{"id": "expert", "name": "Expert", "hp": 4.8, "dmg": 3.0, "spd": 1.12, "press": 1.35, "souls": 180, "loot": 2.1, "gold": 2.4, "xp": 2.0, "chest": "gold",
		"ai": 1.5, "mech": 0.12, "pen": 0.18, "heal": 0.75, "mat": 3, "power": 1300, "color": Color(1.0, 0.55, 0.25)},
	{"id": "nightmare", "name": "Nightmare", "hp": 8.0, "dmg": 4.4, "spd": 1.17, "press": 1.5, "souls": 190, "loot": 2.6, "gold": 3.0, "xp": 2.4, "chest": "crypt",
		"ai": 2.0, "mech": 0.16, "pen": 0.25, "heal": 0.65, "mat": 4, "power": 2000, "color": Color(0.95, 0.25, 0.25)},
	{"id": "hell", "name": "Hell", "hp": 13.5, "dmg": 6.4, "spd": 1.21, "press": 1.6, "souls": 200, "loot": 3.2, "gold": 3.8, "xp": 2.9, "chest": "crypt",
		"ai": 2.3, "mech": 0.22, "pen": 0.32, "heal": 0.55, "mat": 5, "power": 3100, "color": Color(0.85, 0.12, 0.35)},
	{"id": "torment", "name": "Torment", "hp": 23.0, "dmg": 9.0, "spd": 1.25, "press": 1.7, "souls": 210, "loot": 3.9, "gold": 4.7, "xp": 3.4, "chest": "crypt",
		"ai": 2.6, "mech": 0.28, "pen": 0.4, "heal": 0.45, "mat": 5, "power": 4700, "color": Color(0.7, 0.2, 0.85)},
	{"id": "abyss", "name": "Abyss", "hp": 39.0, "dmg": 12.5, "spd": 1.3, "press": 1.8, "souls": 220, "loot": 4.8, "gold": 5.8, "xp": 4.0, "chest": "crypt",
		"ai": 3.0, "mech": 0.35, "pen": 0.45, "heal": 0.35, "mat": 6, "power": 7000, "color": Color(0.35, 0.85, 1.0)},
]
## Old saves had three tiers: Normal, Veteran, Nightmare.
const TIER_FROM_V3 := [0, 2, 4]
## Named tier indices other rules depend on.
const TIER_VETERAN := 2
const TIER_NIGHTMARE := 4
## Hero armor turns into damage reduction on a curve (1 - e^-k·armor): the
## first points count fully, stacking past ~60 armor gives little.
const ARMOR_K := 0.95
const ARMOR_CAP := 0.65
## Passive healing (regen) can never exceed this fraction of max health a
## second, before the tier's `heal`. Leech has its own per-second cap.
const REGEN_CAP := 0.025
const LEECH_CAP := 0.04
## Foes and bosses grow with the hunt's level: a build that snowballs still
## meets a boss worth fighting. Fraction per run level past the first.
const RUN_FOE_HP := 0.035
const RUN_BOSS_HP := 0.05

## Skill over stats. Eruptions: every few seconds the graves burst under and
## around the hero (telegraphed); a hero who never moves is always hit. The
## interval shortens and the cluster grows with the tier's ai.
const ERUPTION := {"every": 12.0, "every_ai": 2.6, "min": 4.2, "count": 2, "count_ai": 1.5, "dmg": 13.0, "radius": 1.9, "delay": 1.15, "mech": 0.55}
## Dashing through a blow that would have landed: a riposte, harder hits for a
## few seconds, and a slice of super.
const PERFECT_DODGE := {"dmg": 0.35, "time": 3.0, "super": 0.15}
## Bow and staff heroes who plant their feet aim truer: more damage after
## standing still a moment. Moving is safety, standing is damage.
const STEADY := {"after": 0.45, "dmg": 0.25}
## A boss that slams into a wall on its charge (or spends itself on a big
## spell) is stunned and takes extra damage: the reward for baiting it.
const EXPOSED := {"time": 2.4, "dmg": 0.5}
## The ritual: Grave Callers chant around a sigil. Kill them all in time for
## a prize; fail and a champion brute climbs out and the dead quicken.
const RITUAL := {"chance": 0.6, "at": 0.35, "time": 18.0, "callers": 3, "fail_speed": 0.1}

static func armor_dr(armor: float, pen := 0.0) -> float:
	return minf(1.0 - exp(-ARMOR_K * maxf(armor, 0.0) * (1.0 - pen)), ARMOR_CAP)

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
	# Signatures: one rule-changing legendary per hero.
	"bulwark": {"name": "Bulwark", "desc": "Standing still, your shield takes 60% of blows from the front", "icon": "checked-shield", "rarity": "legendary", "max": 1, "hero": ["knight"], "sig": true},
	"ricochet": {"name": "Ricochet", "desc": "Arrows that hit leap on to another foe", "icon": "high-shot", "rarity": "legendary", "max": 1, "hero": ["ranger"], "sig": true},
	"pyre": {"name": "Pyre", "desc": "Fireballs leave the ground burning", "icon": "flame", "rarity": "legendary", "max": 1, "hero": ["mage"], "sig": true},
	"rampage": {"name": "Rampage", "desc": "Every kill: +3% damage for 6 seconds, up to +45%", "icon": "muscle-up", "rarity": "legendary", "max": 1, "hero": ["barbarian"], "sig": true},
}
## A companion hero hits at this share of its own damage.
const ALLY_DMG := 0.45
## Card banishes per hunt: remove a card from this hunt's pool for good.
const BANISHES := 3
## Hero level that adds a fourth level-up choice, and one that adds a second
## potion charge.
const FOURTH_CARD_LEVEL := 15
const SECOND_POTION_LEVEL := 20
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
	"speed": ["Move speed", "%"], "armor": ["Armor", ""], "gold": ["Gold found", "%"], "regen": ["Regen", "/s"],
}
## Affix pool: stat key -> [min, max] per rarity step, and its label.
const AFFIXES := {
	"dmg": {"label": "+%d%% damage", "roll": [6, 12]},
	"hp": {"label": "+%d%% health", "roll": [8, 14]},
	"aspd": {"label": "+%d%% attack speed", "roll": [5, 9]},
	"crit": {"label": "+%d%% critical chance", "roll": [3, 6]},
	"speed": {"label": "+%d%% move speed", "roll": [3, 6]},
	"armor": {"label": "+%d armor", "roll": [3, 6]},
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
	"bonelet": {"name": "Bonelet", "slot": "pet", "rarity": "legendary", "source": "boss", "rate": 50, "icon": "skull-crossed-bones", "power": "A tiny skeleton that follows you everywhere.", "model": "Skeleton_Minion"},
	"hexling": {"name": "Hexling", "slot": "pet", "rarity": "legendary", "source": "hexer", "rate": 50, "icon": "magic-swirl", "power": "A tiny cultist with a tinier staff.", "model": "Skeleton_Mage"},
	"sigil": {"name": "Champion's Sigil", "slot": "trophy", "rarity": "rare", "source": "elite", "rate": 12, "icon": "rune-stone", "power": "Proof of a champion slain. Sells for 150 gold.", "sell": 150},
	"tooth": {"name": "Barrow Tooth", "slot": "trophy", "rarity": "magic", "source": "boss", "rate": 4, "icon": "broken-bone", "power": "An old king's tooth. Sells for 60 gold.", "sell": 60},
	"thornbow": {"cls": "ranger", "dye": Color(0.45, 0.85, 0.3), "name": "Thornwood Longbow", "slot": "weapon", "rarity": "legendary", "source": "thorn", "rate": 25, "stats": {"dmg": 28, "crit": 9}, "card": "barrage", "power": "Start every hunt with Arrow Storm", "icon": "pocket-bow"},
	"barkplate": {"cls": "barbarian", "dye": Color(0.4, 0.3, 0.18), "name": "Barkhide Plate", "slot": "chest", "rarity": "legendary", "source": "thorn", "rate": 25, "stats": {"hp": 32, "armor": 9}, "card": "thorns", "power": "Start every hunt with Thorns", "icon": "breastplate"},
	"seedheart": {"cls": "knight", "dye": Color(0.6, 1.0, 0.4), "name": "Seedheart Aegis", "slot": "trinket", "rarity": "legendary", "source": "thorn", "rate": 30, "stats": {"aspd": 12, "regen": 5}, "card": "ward", "power": "Start every hunt with Bone Ward", "icon": "shield"},
	"acolyte": {"name": "Acolyte", "slot": "pet", "rarity": "legendary", "source": "thorn", "rate": 50, "icon": "ghost", "power": "A very small cultist who means well.", "model": "Rogue_Hooded"},
	"seed": {"name": "Thorn Seed", "slot": "trophy", "rarity": "magic", "source": "thorn", "rate": 4, "icon": "gems", "power": "It wriggles. Sells for 80 gold.", "sell": 80},
	"abyssal": {"name": "Abyssal Gem", "slot": "trophy", "rarity": "legendary", "source": "nightmare", "rate": 80, "icon": "crystal-shine", "power": "It hums. Sells for 2000 gold.", "sell": 2000},
}
const LOG_ORDER := ["cleaver", "shroud", "crown", "bonelet", "tooth", "scepter", "gown", "greaves", "hexling", "charm", "thornbow", "barkplate", "seedheart", "acolyte", "seed", "emberheart", "sigil", "abyssal"]
## Unique sources and the boss whose kill count and dry streak they follow.
const SOURCE_BOSS := {"boss": "gravemaw", "hexer": "hexer", "thorn": "thorn"}

## Rarity weights by source; tier loot multiplier shifts weight upward.
const DROP_RARITY := {
	"trash": {"common": 70.0, "magic": 26.0, "rare": 4.0, "legendary": 0.0},
	"elite": {"common": 20.0, "magic": 50.0, "rare": 28.0, "legendary": 2.0},
	"boss": {"common": 0.0, "magic": 45.0, "rare": 45.0, "legendary": 10.0},
	"chest": {"common": 25.0, "magic": 45.0, "rare": 26.0, "legendary": 4.0},
}

## Share of a chest's shards that go to the hero in use.
const SHARDS_TO_PLAYED := 0.75
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


# --- Gold sinks -------------------------------------------------------------

## Reforge rerolls an item's extra affixes; temper raises its material one step
## (stats scale with it). Costs grow with material and rarity.
const REFORGE_GOLD := 60
const TEMPER_GOLD := 220
## Talent reset: the first is free, then this much per hero level.
const RESPEC_GOLD := 90

static func reforge_cost(it: Dictionary) -> int:
	return REFORGE_GOLD * (1 + int(it.get("mat", 0))) * (1 + RARITIES.find(str(it["rarity"])))


static func temper_cost(it: Dictionary) -> int:
	return TEMPER_GOLD * int(pow(int(it.get("mat", 0)) + 1, 2))

## Weapon glows bought with gold, per hero. "" is none.
const GLOWS := {
	"ember": {"name": "Ember", "color": Color(1.0, 0.45, 0.12, 0.45), "gold": 2500},
	"frost": {"name": "Frost", "color": Color(0.4, 0.85, 1.0, 0.45), "gold": 2500},
	"venom": {"name": "Venom", "color": Color(0.45, 1.0, 0.35, 0.45), "gold": 4000},
	"void": {"name": "Void", "color": Color(0.7, 0.3, 1.0, 0.5), "gold": 6000},
	"gold": {"name": "Kingsgold", "color": Color(1.0, 0.85, 0.3, 0.55), "gold": 12000},
}
const GLOW_ORDER := ["ember", "frost", "venom", "void", "gold"]

# --- Sets and ancients --------------------------------------------------------

## Boss gear sets: a piece from a boss's hoard can belong to its set (and the
## boss's uniques always do). Bonuses at 2 and 4 pieces worn by one hero.
## `flags` are rules the hunt reads (Hero.flags).
const SETS := {
	"gravemaw": {"name": "Barrow King's Regalia", "short": "Regalia", "color": Color(0.45, 1.0, 0.6),
		"2": {"dmg": 0.12, "desc": "+12% damage"}, "4": {"flags": {"exposed": 0.4}, "desc": "Exposed bosses take 40% more from you"}},
	"thorn": {"name": "Thornmother's Bark", "short": "Barkbound", "color": Color(0.6, 0.95, 0.35),
		"2": {"hp": 0.12, "desc": "+12% health"}, "4": {"flags": {"thorn_dash": 1.5}, "desc": "Your dash leaves thorns that cut the dead"}},
	"hexer": {"name": "Raiment of the Crypt Queen", "short": "Raiment", "color": Color(0.8, 0.55, 1.0),
		"2": {"speed": 0.08, "crit": 0.05, "desc": "+8% move speed, +5% crit"}, "4": {"flags": {"dodge_heal": 0.12}, "desc": "Perfect dodges heal 12% health"}},
}
const SET_CHANCE := 0.3
## Ancient: a rare roll on Hell and up, every number 30% higher.
const ANCIENT_CHANCE := 0.03
const ANCIENT_MULT := 1.3
const ANCIENT_FROM_TIER := 5

# --- Hero mastery and rating ---------------------------------------------------

## Mastery points per hunt: kills/10 + 40 a win + 15 a tier step. Ranks pay out
## once and give a title shown under the hero's name.
const MASTERY := [
	{"at": 0, "title": "Recruit"},
	{"at": 300, "title": "Blooded", "gold": 300},
	{"at": 900, "title": "Veteran", "gold": 600, "shards": 20},
	{"at": 2000, "title": "Champion", "gold": 1200, "shards": 40, "glow": "ember"},
	{"at": 4000, "title": "Warlord", "gold": 2500, "shards": 80},
	{"at": 7500, "title": "Master", "gold": 5000, "shards": 140, "glow": "frost"},
	{"at": 13000, "title": "Grandmaster", "gold": 9000, "shards": 220},
	{"at": 21000, "title": "Legend", "gold": 15000, "shards": 320, "glow": "gold"},
]

## Trophy rating (Brawl Stars): wins add, losses take away, a milestone every
## RATING_STEP pays out once.
const RATING_WIN := 10
const RATING_WIN_TIER := 4
const RATING_LOSS := 6
const RATING_STEP := 100

static func mastery_rank(points: int) -> int:
	var r := 0
	for i in MASTERY.size():
		if points >= int(MASTERY[i]["at"]):
			r = i
	return r

# --- Daily and idle -----------------------------------------------------------

## The first win of each day: the chest is a grade better and gold doubles.
const FIRST_WIN_GOLD := 1.0
## Login calendar: day n of a streak (1-7, then it loops). A missed day resets it.
const LOGIN_REWARDS := [
	{"gold": 150}, {"shards": 8}, {"gold": 300}, {"chest": "silver"}, {"gold": 500}, {"shards": 20}, {"chest": "gold"},
]
## The campfire: gold accrues while away, up to IDLE_HOURS, faster with the
## highest tier opened.
const IDLE_GOLD_HOUR := 30
const IDLE_GOLD_TIER := 20
const IDLE_HOURS := 12.0

# --- Rifts ---------------------------------------------------------------------

## A rift key drops when the Descent reaches RIFT_DEPTH. A rift is one boss at
## RIFT_POWER health (and more damage) with a guaranteed unique from its table.
const RIFT_DEPTH := 8
const RIFT_POWER := 2.6

# --- Achievements --------------------------------------------------------------

## `stat` reads Game.achievement_value; `n` is the target; gold on claim.
const ACHIEVEMENTS := [
	{"id": "first_blood", "name": "First Blood", "desc": "Win your first hunt", "stat": "wins", "n": 1, "gold": 100},
	{"id": "hunter", "name": "Grave Hunter", "desc": "Win 25 hunts", "stat": "wins", "n": 25, "gold": 800},
	{"id": "slayer", "name": "Barrow Slayer", "desc": "Win 100 hunts", "stat": "wins", "n": 100, "gold": 3000},
	{"id": "bones_1k", "name": "Bonebreaker", "desc": "Slay 1,000 skeletons", "stat": "kills", "n": 1000, "gold": 300},
	{"id": "bones_25k", "name": "Ossuary", "desc": "Slay 25,000 skeletons", "stat": "kills", "n": 25000, "gold": 3000},
	{"id": "champs", "name": "Champion's Bane", "desc": "Slay 50 champions", "stat": "elites", "n": 50, "gold": 800},
	{"id": "king", "name": "Kingslayer", "desc": "Kill Gravemaw 50 times", "stat": "kc_gravemaw", "n": 50, "gold": 1500},
	{"id": "queen", "name": "Queenslayer", "desc": "Kill the Hexer Queen 50 times", "stat": "kc_hexer", "n": 50, "gold": 1500},
	{"id": "veteran", "name": "Hardened", "desc": "Win on Veteran", "stat": "tier", "n": 3, "gold": 500},
	{"id": "nightmare", "name": "Waking Nightmare", "desc": "Win on Nightmare", "stat": "tier", "n": 5, "gold": 2000},
	{"id": "torment", "name": "Tormentor", "desc": "Win on Torment", "stat": "tier", "n": 7, "gold": 6000},
	{"id": "abyss", "name": "Into the Abyss", "desc": "Win on Abyss", "stat": "tier", "n": 8, "gold": 15000},
	{"id": "deep", "name": "Deep Delver", "desc": "Reach depth 10 in the Descent", "stat": "depth", "n": 10, "gold": 1500},
	{"id": "dodger", "name": "Untouchable", "desc": "Make 10 perfect dodges in one hunt", "stat": "perfect", "n": 10, "gold": 800},
	{"id": "collector", "name": "Collector", "desc": "Fill 6 collection log slots", "stat": "log", "n": 6, "gold": 1500},
	{"id": "master", "name": "Mastery", "desc": "Reach Champion mastery with any hero", "stat": "mastery", "n": 3, "gold": 1500},
	{"id": "rift", "name": "Riftwalker", "desc": "Close a rift", "stat": "rifts", "n": 1, "gold": 1000},
	{"id": "set4", "name": "Dressed to Kill", "desc": "Wear four pieces of one set", "stat": "set", "n": 4, "gold": 2000},
]

# --- Season ---------------------------------------------------------------------

## A season lasts SEASON_WEEKS; season xp is the renown earned in it. Each of
## SEASON_TIERS steps pays a reward; the last a weapon glow and a title. Free:
## the game charges nothing.
const SEASON_WEEKS := 6
const SEASON_TIERS := 30
const SEASON_XP := 120
const SEASON_NAMES := ["Season of Bones", "Season of the Hex", "Season of Ash", "Season of the Grove"]

static func season_reward(n: int) -> Dictionary:
	if n == SEASON_TIERS:
		return {"kind": "glow", "glow": "void"}
	if n % 5 == 0:
		return {"kind": "chest", "chest": "gold" if n < 20 else "crypt"}
	if n % 2 == 0:
		return {"kind": "shards", "amount": 6 + n / 2}
	return {"kind": "gold", "amount": 120 + 20 * n}

# --- Hero-defining legendaries ------------------------------------------------

## Rule-changing cards, one per hero, offered as legendaries from run level 6.
## (Defined in CARDS; listed here for the Log.)
const SIGNATURES := {"knight": "bulwark", "ranger": "ricochet", "mage": "pyre", "barbarian": "rampage"}
