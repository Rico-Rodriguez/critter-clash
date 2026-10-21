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
		"super": "slam", "super_name": "Judgement", "super_desc": "Leap and smash the ground, stunning everything nearby.",
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
		"super": "volley", "super_name": "Hail of Arrows", "super_desc": "A wide fan of piercing arrows.",
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
		"super": "nova", "super_name": "Frost Nova", "super_desc": "A ring of ice that freezes and shatters the horde.",
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

const HERO_MAX_LEVEL := 10
## Shards and gold to go from level n to n+1 (index = current level).
const UPGRADE_SHARDS := [0, 6, 12, 20, 32, 48, 70, 100, 140, 200]
const UPGRADE_GOLD := [0, 60, 140, 280, 500, 800, 1200, 1800, 2700, 4000]
const LEVEL_POWER := 0.09

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

const BOSS := {
	"name": "Gravemaw", "title": "the Barrow King",
	"model": "Skeleton_Warrior", "weapons": {"handslot.r": "axe_2handed.gltf", "handslot.l": "Skeleton_Shield_Large_B.gltf"},
	"hp": 3400.0, "dmg": 26.0, "speed": 3.0, "radius": 1.5, "scale": 2.6, "mass": 40.0,
}

## Elite affixes: Diablo-style champions. Each multiplies or adds a trait.
const ELITE_AFFIXES := {
	"vampiric": {"name": "Vampiric", "color": Color(0.9, 0.12, 0.2)},
	"swift": {"name": "Swift", "color": Color(0.3, 0.9, 1.0)},
	"molten": {"name": "Molten", "color": Color(1.0, 0.45, 0.1)},
	"warded": {"name": "Warded", "color": Color(0.55, 0.5, 1.0)},
}
const ELITE_NAMES_A := ["Grim", "Hollow", "Rot", "Ash", "Marrow", "Pale", "Vile", "Dread", "Cairn", "Gloom"]
const ELITE_NAMES_B := ["jaw", "bone", "shank", "skull", "rib", "grin", "maw", "knuckle", "spine", "tooth"]
const ELITE_TITLES := ["the Restless", "the Unburied", "the Hungering", "the Forsworn", "the Silent", "of the Low Barrow"]

# --- Difficulty tiers ----------------------------------------------------

const TIERS := [
	{"id": "normal", "name": "Normal", "hp": 1.0, "dmg": 1.0, "souls": 110, "loot": 1.0, "gold": 1.0, "xp": 1.0, "chest": "silver", "color": Color(0.8, 0.8, 0.8)},
	{"id": "veteran", "name": "Veteran", "hp": 2.1, "dmg": 1.6, "souls": 140, "loot": 1.6, "gold": 1.8, "xp": 1.6, "chest": "gold", "color": Color(1.0, 0.75, 0.3)},
	{"id": "nightmare", "name": "Nightmare", "hp": 4.2, "dmg": 2.4, "souls": 170, "loot": 2.6, "gold": 3.0, "xp": 2.4, "chest": "crypt", "color": Color(0.95, 0.25, 0.25)},
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
	"blades": {"name": "Orbiting Blades", "desc": "Spectral blades circle you", "icon": "spinning-blades", "rarity": "epic", "max": 4},
	"storm": {"name": "Storm Call", "desc": "Lightning strikes chained foes", "icon": "lightning-helix", "rarity": "epic", "max": 4},
	"nova": {"name": "Fire Nova", "desc": "A ring of fire bursts around you", "icon": "fire-ring", "rarity": "epic", "max": 4},
	"ward": {"name": "Bone Ward", "desc": "A shield blocks one hit, recharging", "icon": "bolt-shield", "rarity": "rare", "max": 3},
	"thorns": {"name": "Thorns", "desc": "Melee attackers take 60% of the hit", "icon": "slashed-shield", "rarity": "rare", "max": 3},
	"greed": {"name": "Grave Robber", "desc": "+30% gold", "icon": "two-coins", "rarity": "common", "max": 3},
	"phoenix": {"name": "Undying", "desc": "Once per hunt, rise again at half health", "icon": "ghost", "rarity": "legendary", "max": 1},
}
const CARD_WEIGHT := {"common": 10.0, "rare": 6.0, "epic": 3.2, "legendary": 0.8}

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
const SLOT_NAME := {"weapon": "Weapon", "helm": "Helm", "chest": "Chest", "legs": "Legs", "trinket": "Trinket"}
const SLOT_ICON := {"weapon": "broadsword", "helm": "visored-helm", "chest": "breastplate", "legs": "leg-armor", "trinket": "gem-pendant"}
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
	"cleaver": {"name": "Gravemaw's Cleaver", "slot": "weapon", "rarity": "legendary", "source": "boss", "rate": 25, "stats": {"dmg": 30, "aspd": 10}, "card": "blades", "power": "Start every hunt with Orbiting Blades", "icon": "battle-axe", "look": "axe_2handed.gltf"},
	"shroud": {"name": "Shroud of the Barrow", "slot": "chest", "rarity": "legendary", "source": "boss", "rate": 25, "stats": {"hp": 30, "armor": 8}, "card": "ward", "power": "Start every hunt with Bone Ward", "icon": "breastplate"},
	"crown": {"name": "Crown of the Barrow King", "slot": "helm", "rarity": "legendary", "source": "boss", "rate": 40, "stats": {"crit": 10, "gold": 25}, "card": "storm", "power": "Start every hunt with Storm Call", "icon": "crowned-skull"},
	"emberheart": {"name": "Emberheart", "slot": "trinket", "rarity": "legendary", "source": "elite", "rate": 60, "stats": {"dmg": 12, "regen": 4}, "card": "nova", "power": "Start every hunt with Fire Nova", "icon": "flame"},
	"bonelet": {"name": "Bonelet", "slot": "pet", "rarity": "legendary", "source": "boss", "rate": 50, "icon": "skull-crossed-bones", "power": "A tiny skeleton that follows you everywhere."},
	"sigil": {"name": "Champion's Sigil", "slot": "trophy", "rarity": "rare", "source": "elite", "rate": 12, "icon": "rune-stone", "power": "Proof of a champion slain. Sells for 150 gold.", "sell": 150},
	"tooth": {"name": "Barrow Tooth", "slot": "trophy", "rarity": "magic", "source": "boss", "rate": 4, "icon": "broken-bone", "power": "An old king's tooth. Sells for 60 gold.", "sell": 60},
	"abyssal": {"name": "Abyssal Gem", "slot": "trophy", "rarity": "legendary", "source": "nightmare", "rate": 80, "icon": "crystal-shine", "power": "It hums. Sells for 2000 gold.", "sell": 2000},
}
const LOG_ORDER := ["cleaver", "shroud", "crown", "bonelet", "tooth", "emberheart", "sigil", "abyssal"]

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
