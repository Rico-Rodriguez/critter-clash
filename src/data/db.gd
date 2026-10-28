class_name DB
extends RefCounted
## All tunable game data in one place: heroes, enemies, upgrade cards, loot,
## difficulty tiers and the OSRS skill curve. Nothing here touches the scene.

const BOSS_MODELS := preload("res://src/data/boss_models.gd")

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
## One color per set: Gravedigger grey, Warden blue, Barrowsteel violet,
## Bloodiron red, Gravelight soul green.
const TIER_COLOR := [
	Color(0.66, 0.64, 0.6), Color(0.36, 0.6, 1.0), Color(0.7, 0.46, 1.0), Color(0.95, 0.24, 0.26), Color(0.45, 1.0, 0.7),
]
## Each set up adds this much to a piece's stats (the top set: 2.32x the first).
const MAT_STAT := 0.33


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
		"skill": "ranged", "unlock": "pick",
	},
	"mage": {
		"name": "Mage", "title": "The Ember Witch", "role": "Caster",
		"model": "Mage",
		"weapons": {"handslot.r": "staff.gltf"},
		"weapon_bone": "handslot.r", "weapon_looks": [],
		"style": "magic", "hp": 380.0, "speed": 5.4, "dmg": 28.0, "rate": 1.15,
		"range": 8.5, "proj_speed": 16.0, "splash": 2.2, "armor": 0.1,
		"super": "meteor", "super_name": "Meteor Storm", "super_desc": "Call down a barrage of meteors on the horde.",
		"anim": {"idle": "Idle_B", "run": "Running_B", "attack": ["Ranged_Magic_Shoot"], "super": "Ranged_Magic_Summon"},
		"color": Color(0.85, 0.42, 0.95), "icon": "wizard-staff",
		"blurb": "Fireballs that burst through packs.",
		"skill": "magic", "unlock": "pick",
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
		"skill": "melee", "unlock": "road",
	},
	"rogue": {
		"name": "Rogue", "title": "The Unseen", "role": "Assassin",
		"model": "Rogue_Hooded",
		"weapons": {"handslot.r": "dagger.gltf", "handslot.l": "dagger.gltf"},
		"weapon_bone": "handslot.r", "weapon_looks": [],
		"style": "melee", "hp": 360.0, "speed": 5.9, "dmg": 21.0, "rate": 1.7,
		"range": 2.2, "arc": 120.0, "armor": 0.05,
		"super": "shadowstep", "super_name": "Shadowstep", "super_desc": "Blink from foe to foe, stabbing each one as you pass.",
		"anim": {"idle": "Idle_A", "run": "Running_A", "attack": ["Melee_Dualwield_Attack_Slice", "Melee_Dualwield_Attack_Chop"], "super": "Melee_Dualwield_Attack_Chop"},
		"color": Color(0.55, 0.9, 0.6), "icon": "hood",
		"blurb": "Two daggers, fast hands. Gets in, gets out.",
		"skill": "melee", "unlock": "road",
	},
}
const HERO_ORDER := ["knight", "ranger", "mage", "barbarian", "rogue"]

## Weapon families: the weapon, not the hero, decides the basic attack. Each
## has its own swing clips, hit shape, trail and sound; the hero keeps its
## super, dash and cards. `dmg`, `rate` and `range` scale the hero's numbers;
## `arc` replaces its swing arc. Attack kinds (Hero._impact):
##   cleave  one swing hits everything in the arc
##   slam    a smash a little ahead: a circle of `slam_r` that stuns and throws
##   sweep   a wide arc; big foes (elites, bosses) take `echo` follow-up hits,
##           the OSRS scythe's 100/50/25
##   flurry  `hits` quick swings per attack, alternating hands
##   thrust  a long line `width` wide that runs through everything in it
##   throw   a thrown weapon that flies out to `range` and comes back, cutting
##           everything on the way both ways
## Like OSRS, the strong families are earned: `level` is the least weapon
## skill to wield one (a set's own requirement can be higher), `min_set` the
## first set it comes in, and `boss_from` (if any) the difficulty tier from
## which a boss can drop it; nothing else does. The scythe is endgame.
const FAMILIES := {
	"axe": {"hero": "barbarian", "level": 1, "min_set": 0, "name": "Axe", "how": "Big chops that cleave a wide arc.", "attack": "cleave", "icon": "battle-axe",
		"clips": ["Melee_2H_Attack_Slice", "Melee_2H_Attack_Chop"], "dmg": 1.0, "rate": 1.0, "range": 1.0, "arc": 190.0,
		"trail": Color(1.0, 0.62, 0.3), "sfx": "cleave"},
	"maul": {"hero": "barbarian", "level": 40, "min_set": 3, "name": "Maul", "how": "Slow smashes that stun and throw everything around the blow.", "attack": "slam", "icon": "anvil",
		"clips": ["Melee_2H_Attack_Chop"], "dmg": 1.7, "rate": 0.6, "range": 0.85, "arc": 360.0, "slam_r": 2.5, "stun": 0.6, "knock": 11.0,
		"trail": Color(1.0, 0.8, 0.5), "sfx": "quake"},
	"scythe": {"hero": "barbarian", "level": 60, "min_set": 3, "boss_from": 4, "name": "Scythe", "how": "A huge reaping sweep. Elites and bosses are cut three times.", "attack": "sweep", "icon": "scythe",
		"clips": ["Melee_2H_Attack_Slice"], "dmg": 0.85, "rate": 0.8, "range": 1.3, "arc": 270.0, "echo": [0.5, 0.25],
		"trail": Color(0.7, 0.85, 1.0), "sfx": "cleave"},
	"twin": {"hero": "barbarian", "level": 10, "min_set": 1, "name": "Twin Axes", "how": "Two axes, two quick cuts every swing. Short reach.", "attack": "flurry", "icon": "crossed-axes", "dual": true,
		"clips": ["Melee_Dualwield_Attack_Slice", "Melee_Dualwield_Attack_Chop"], "dmg": 0.5, "rate": 1.45, "range": 0.85, "arc": 150.0, "hits": 2,
		"trail": Color(1.0, 0.45, 0.25), "sfx": "swing"},
	"halberd": {"hero": "barbarian", "level": 25, "min_set": 2, "name": "Halberd", "how": "Long thrusts that run through a whole line of foes.", "attack": "thrust", "icon": "halberd",
		"clips": ["Melee_2H_Attack_Stab"], "dmg": 1.15, "rate": 0.85, "range": 1.75, "arc": 30.0, "width": 1.3,
		"trail": Color(0.85, 0.9, 1.0), "sfx": "atk_tank"},
	"throwing": {"hero": "barbarian", "level": 1, "min_set": 0, "name": "Throwing Axe", "how": "Hurl the axe through the horde. It comes back to your hand.", "attack": "throw", "icon": "tomahawk", "one_hand": true,
		"clips": ["Throw"], "dmg": 0.75, "rate": 1.0, "range": 2.6, "arc": 0.0, "speed": 18.0,
		"trail": Color(1.0, 0.7, 0.4), "sfx": "swing"},
	# The Rogue: light blades, mostly one in each hand (tools/art/make_rogue_arms.py).
	"daggers": {"hero": "rogue", "level": 1, "min_set": 0, "name": "Daggers", "how": "Two daggers, two quick cuts every swing.", "attack": "flurry", "icon": "cloak-dagger", "dual": true,
		"clips": ["Melee_Dualwield_Attack_Slice", "Melee_Dualwield_Attack_Chop"], "dmg": 0.55, "rate": 1.4, "range": 0.85, "arc": 140.0, "hits": 2,
		"trail": Color(0.55, 0.9, 0.6), "sfx": "swing"},
	"chakram": {"hero": "rogue", "level": 1, "min_set": 0, "name": "Chakram", "how": "A bladed ring flung through the horde. It spins back to your hand.", "attack": "throw", "icon": "spinning-blades", "one_hand": true,
		"clips": ["Throw"], "dmg": 0.7, "rate": 1.1, "range": 2.4, "arc": 0.0, "speed": 20.0,
		"trail": Color(0.7, 1.0, 0.75), "sfx": "swing"},
	"rapier": {"hero": "rogue", "level": 10, "min_set": 1, "name": "Rapier", "how": "A lunge that runs a needle through a whole line of foes.", "attack": "thrust", "icon": "spear-feather",
		"clips": ["Melee_1H_Attack_Stab"], "dmg": 1.0, "rate": 1.15, "range": 1.6, "arc": 30.0, "width": 0.9,
		"trail": Color(0.85, 0.95, 1.0), "sfx": "atk_tank"},
	"sickles": {"hero": "rogue", "level": 25, "min_set": 2, "name": "Sickles", "how": "Two reaping hooks, three fast cuts every swing.", "attack": "flurry", "icon": "sword-wound", "dual": true,
		"clips": ["Melee_Dualwield_Attack_Slice", "Melee_Dualwield_Attack_Chop"], "dmg": 0.42, "rate": 1.35, "range": 0.9, "arc": 170.0, "hits": 3,
		"trail": Color(0.5, 1.0, 0.55), "sfx": "swing"},
	"katars": {"hero": "rogue", "level": 40, "min_set": 3, "name": "Katars", "how": "Punch daggers driven down together: the ground bursts, foes stagger.", "attack": "slam", "icon": "fist", "dual": true,
		"clips": ["Melee_Dualwield_Attack_Chop"], "dmg": 1.4, "rate": 0.85, "range": 0.8, "arc": 360.0, "slam_r": 2.0, "stun": 0.4, "knock": 7.0,
		"trail": Color(0.6, 1.0, 0.7), "sfx": "quake"},
	"nightblade": {"hero": "rogue", "level": 60, "min_set": 3, "boss_from": 4, "name": "Nightblade", "how": "A long curved edge. Elites and bosses are cut three times.", "attack": "sweep", "icon": "dripping-sword",
		"clips": ["Melee_1H_Attack_Slice_Horizontal", "Melee_1H_Attack_Slice_Diagonal"], "dmg": 0.8, "rate": 0.95, "range": 1.2, "arc": 220.0, "echo": [0.5, 0.25],
		"trail": Color(0.4, 0.9, 0.6), "sfx": "cleave"},
	# The Knight: one-handed, the shield always up.
	"sword": {"hero": "knight", "level": 1, "min_set": 0, "name": "Sword", "how": "Quick, sure cuts across the front.", "attack": "cleave", "icon": "broadsword",
		"clips": ["Melee_1H_Attack_Slice_Diagonal", "Melee_1H_Attack_Slice_Horizontal"], "dmg": 1.0, "rate": 1.0, "range": 1.0, "arc": 140.0,
		"trail": Color(0.75, 0.88, 1.0), "sfx": "atk_tank"},
	"mace": {"hero": "knight", "level": 1, "min_set": 0, "name": "Mace", "how": "Heavy blows that daze what they land on.", "attack": "slam", "icon": "flanged-mace",
		"clips": ["Melee_1H_Attack_Chop"], "dmg": 1.2, "rate": 0.85, "range": 0.85, "arc": 360.0, "slam_r": 1.7, "stun": 0.4, "knock": 7.0,
		"trail": Color(1.0, 0.85, 0.55), "sfx": "atk_tank"},
	"spear": {"hero": "knight", "level": 10, "min_set": 1, "name": "Spear", "how": "Long stabs through a line, from behind the shield.", "attack": "thrust", "icon": "spear-feather",
		"clips": ["Melee_1H_Attack_Stab"], "dmg": 1.0, "rate": 0.95, "range": 1.4, "arc": 30.0, "width": 1.1,
		"trail": Color(0.85, 0.9, 1.0), "sfx": "swing"},
	"flail": {"hero": "knight", "level": 25, "min_set": 2, "name": "Flail", "how": "Whirls the ball all the way round: nothing at your back is safe.", "attack": "cleave", "icon": "flail",
		"clips": ["Melee_2H_Attack_Spin"], "dmg": 0.85, "rate": 0.9, "range": 1.1, "arc": 360.0,
		"trail": Color(1.0, 0.75, 0.45), "sfx": "cleave"},
	"warhammer": {"hero": "knight", "level": 40, "min_set": 3, "name": "Warhammer", "how": "Two-handed, earth-shaking smashes that stun a whole crowd. No shield.", "attack": "slam", "icon": "warhammer",
		"clips": ["Melee_2H_Attack_Chop"], "anims": {"idle": "Melee_2H_Idle"}, "dmg": 1.9, "rate": 0.55, "range": 0.9, "arc": 360.0, "slam_r": 2.6, "stun": 0.8, "knock": 12.0,
		"trail": Color(1.0, 0.82, 0.5), "sfx": "quake"},
	"runeblade": {"hero": "knight", "level": 60, "min_set": 3, "boss_from": 4, "name": "Runeblade", "how": "Every cut sends a blade of light on through the horde.", "attack": "rune", "icon": "glowing-hands",
		"clips": ["Melee_1H_Attack_Slice_Diagonal", "Melee_1H_Attack_Slice_Horizontal"], "dmg": 1.0, "rate": 1.0, "range": 1.1, "arc": 170.0,
		"trail": Color(0.6, 1.0, 0.85), "sfx": "atk_tank"},
	# The Ranger: what leaves the hand changes. Volleys keep the bow cards.
	"shortbow": {"hero": "ranger", "level": 1, "min_set": 0, "name": "Shortbow", "how": "A fast pair of arrows, again and again.", "attack": "volley", "icon": "high-shot",
		"clips": ["Ranged_Bow_Release"], "dmg": 1.0, "rate": 1.0, "range": 1.0, "arc": 0.0,
		"trail": Color(1.0, 0.9, 0.6), "sfx": "atk_archer"},
	"knives": {"hero": "ranger", "level": 1, "min_set": 0, "name": "Throwing Knives", "how": "A fan of knives: short reach, hits everything in front.", "attack": "volley", "icon": "thrown-daggers",
		"clips": ["Throw"], "anims": {"idle": "Idle_B", "run": "Running_A", "super": "Throw"}, "bone": "handslot.r",
		"dmg": 0.5, "rate": 1.2, "range": 0.65, "arc": 0.0, "shots": 2, "spread": 15.0, "proj": "knife", "pspeed": 0.85,
		"trail": Color(0.9, 0.95, 1.0), "sfx": "swing"},
	"crossbow": {"hero": "ranger", "level": 10, "min_set": 1, "name": "Crossbow", "how": "One heavy bolt that punches through three foes.", "attack": "volley", "icon": "crossbow",
		"clips": ["Ranged_2H_Shoot"], "anims": {"idle": "Ranged_2H_Aiming", "run": "Running_HoldingRifle", "super": "Ranged_2H_Shooting"}, "bone": "handslot.r",
		"dmg": 2.1, "rate": 0.55, "range": 1.1, "arc": 0.0, "shots": -1, "pierce": 2, "proj": "quarrel", "pspeed": 1.4,
		"trail": Color(1.0, 0.8, 0.5), "sfx": "atk_archer"},
	"longbow": {"hero": "ranger", "level": 25, "min_set": 2, "name": "Longbow", "how": "Slow, far, hard-hitting arrows that pass through.", "attack": "volley", "icon": "bow-arrow",
		"clips": ["Ranged_Bow_Release"], "dmg": 1.45, "rate": 0.8, "range": 1.35, "arc": 0.0, "pierce": 1, "pspeed": 1.3, "spread": 4.0,
		"trail": Color(1.0, 0.95, 0.7), "sfx": "atk_archer"},
	"repeater": {"hero": "ranger", "level": 40, "min_set": 3, "name": "Repeaters", "how": "A hand crossbow in each fist, emptied into the horde.", "attack": "volley", "icon": "crossbow", "dual": true,
		"clips": ["Ranged_1H_Shoot"], "anims": {"idle": "Ranged_1H_Aiming", "run": "Running_A", "super": "Ranged_1H_Shooting"}, "bone": "handslot.r",
		"dmg": 0.55, "rate": 2.1, "range": 0.9, "arc": 0.0, "spread": 5.0, "proj": "quarrel", "pspeed": 1.2,
		"trail": Color(1.0, 0.6, 0.4), "sfx": "atk_archer"},
	"soulbow": {"hero": "ranger", "level": 60, "min_set": 3, "boss_from": 4, "name": "Soulbow", "how": "Arrows of soul fire that hunt down a foe on their own.", "attack": "volley", "icon": "bow-arrow",
		"clips": ["Ranged_Bow_Release"], "dmg": 1.15, "rate": 1.0, "range": 1.15, "arc": 0.0, "spread": 18.0, "proj": "soularrow", "home": true,
		"trail": Color(0.55, 1.0, 0.75), "sfx": "atk_archer"},
	# The Mage: the spell changes with the focus.
	"staff": {"hero": "mage", "level": 1, "min_set": 0, "name": "Staff", "how": "Fireballs that burst on whatever they hit.", "attack": "cast", "icon": "wizard-staff",
		"clips": ["Ranged_Magic_Shoot"], "dmg": 1.0, "rate": 1.0, "range": 1.0, "arc": 0.0,
		"trail": Color(1.0, 0.55, 0.2), "sfx": "atk_mage"},
	"wand": {"hero": "mage", "level": 1, "min_set": 0, "name": "Wand", "how": "A stream of quick sparks with small bursts.", "attack": "cast", "icon": "fairy-wand",
		"clips": ["Ranged_Magic_Shoot"], "dmg": 0.5, "rate": 1.9, "range": 0.95, "arc": 0.0, "splash": 0.45, "pspeed": 1.5, "proj": "spark",
		"trail": Color(1.0, 0.85, 0.4), "sfx": "atk_mage"},
	"tome": {"hero": "mage", "level": 10, "min_set": 1, "name": "Tome", "how": "Orbs that seek out foes and never miss.", "attack": "cast", "icon": "spell-book",
		"clips": ["Ranged_Magic_Spellcasting"], "dmg": 0.7, "rate": 1.0, "range": 1.0, "arc": 0.0, "shots": 1, "spread": 30.0, "splash": 0.5, "pspeed": 0.75, "proj": "orb", "home": true,
		"trail": Color(0.75, 0.45, 1.0), "sfx": "atk_mage"},
	"scepter": {"hero": "mage", "level": 25, "min_set": 2, "name": "Scepter", "how": "Lightning that leaps from foe to foe.", "attack": "chain", "icon": "lightning-tree",
		"clips": ["Ranged_Magic_Shoot"], "dmg": 0.95, "rate": 0.9, "range": 0.9, "arc": 0.0, "jumps": 4,
		"trail": Color(0.55, 0.8, 1.0), "sfx": "atk_mage"},
	"skullstaff": {"hero": "mage", "level": 40, "min_set": 3, "name": "Skull Staff", "how": "Slow skulls of fire that blow a crowd apart.", "attack": "cast", "icon": "skull-staff",
		"clips": ["Ranged_Magic_Summon"], "dmg": 2.3, "rate": 0.5, "range": 1.0, "arc": 0.0, "splash": 1.8, "pspeed": 0.6,
		"trail": Color(1.0, 0.3, 0.15), "sfx": "atk_mage"},
	"soulstaff": {"hero": "mage", "level": 60, "min_set": 3, "boss_from": 4, "name": "Soulstaff", "how": "A lance of soul fire through everything in its path.", "attack": "lance", "icon": "wizard-staff",
		"clips": ["Ranged_Magic_Shoot"], "dmg": 1.4, "rate": 0.8, "range": 1.2, "arc": 0.0, "width": 1.0,
		"trail": Color(0.55, 1.0, 0.75), "sfx": "atk_mage"},
}
## Every hero's families, in the order its gear screen shows them. A hero not
## listed fights the way its HEROES entry says, whatever it holds.
const HERO_FAMILIES := {
	"knight": ["sword", "mace", "spear", "flail", "warhammer", "runeblade"],
	"ranger": ["shortbow", "knives", "crossbow", "longbow", "repeater", "soulbow"],
	"mage": ["staff", "wand", "tome", "scepter", "skullstaff", "soulstaff"],
	"barbarian": ["axe", "maul", "scythe", "twin", "halberd", "throwing"],
	"rogue": ["daggers", "chakram", "rapier", "sickles", "katars", "nightblade"],
}

## Hero levels bought with shards and gold are gone: skills are a hero's power
## now. These tables only price the refund old saves get (Game._refund_levels).
const HERO_MAX_LEVEL := 20
## Shards and gold to go from level n to n+1 (index = current level).
const UPGRADE_SHARDS := [0, 6, 12, 20, 32, 48, 70, 100, 140, 200, 240, 280, 330, 390, 460, 540, 630, 730, 840, 960]
const UPGRADE_GOLD := [0, 60, 140, 280, 500, 800, 1200, 1800, 2700, 4000, 5500, 7000, 9000, 11500, 14500, 18000, 22000, 27000, 33000, 40000]

# --- Enemies -------------------------------------------------------------
# ai: melee (walk up, wind up, swing), ranged (keep distance, aimed bolt),
# caster (drops a telegraphed circle on the hero).

const NEXT_FOES := preload("res://src/data/next_foes.gd")

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
	# The Frozen Crypt's dead (the Frost Troll's court): the same bones, frozen
	# and recoloured from their own texture (no tint wash). `rider` is what a
	# landed blow leaves on the hero, `leave` and `trail` what a blast or a lunge
	# leaves on the ground, `death` what the body does, `base` the role it fills.
	"thrall": {
		"name": "Frostbound Thrall", "model": "Skeleton_Minion", "weapons": {"handslot.r": "Skeleton_Blade.gltf"}, "skin": "rime", "base": "minion",
		"ai": "melee", "hp": 36.0, "dmg": 9.0, "speed": 3.4, "radius": 0.42, "reach": 1.25, "rider": "chill",
		"windup": 0.4, "cooldown": 1.1, "mass": 1.0, "xp": 1, "scale": 1.0,
		"anim": {"idle": "Skeletons_Idle", "run": "Running_A", "attack": "Melee_1H_Attack_Chop", "spawn": "Skeletons_Awaken_Standing", "die": "Skeletons_Death", "hit": "Hit_B"},
	},
	"frostguard": {
		"name": "Rime Guard", "model": "Skeleton_Warrior", "weapons": {"handslot.r": "Skeleton_Axe.gltf", "handslot.l": "Skeleton_Shield_Large_A.gltf"}, "skin": "rime", "base": "warrior",
		"ai": "melee", "hp": 140.0, "dmg": 19.0, "speed": 2.6, "radius": 0.6, "reach": 1.55, "rider": "chill",
		"windup": 0.6, "cooldown": 1.6, "mass": 3.5, "xp": 3, "scale": 1.12,
		"anim": {"idle": "Skeletons_Idle", "run": "Skeletons_Walking", "attack": "Melee_1H_Attack_Slice_Diagonal", "spawn": "Skeletons_Awaken_Standing", "die": "Skeletons_Death", "hit": "Hit_A"},
	},
	"rimearcher": {
		"name": "Rime Archer", "model": "Skeleton_Rogue", "weapons": {"handslot.r": "Skeleton_Crossbow.gltf"}, "skin": "rime", "base": "rogue",
		"ai": "ranged", "hp": 46.0, "dmg": 12.0, "speed": 3.1, "radius": 0.45, "reach": 8.5, "rider": "chill", "proj": "frostbolt",
		"windup": 0.75, "cooldown": 2.4, "mass": 1.0, "xp": 2, "scale": 1.0, "proj_speed": 12.0,
		"anim": {"idle": "Ranged_1H_Aiming", "run": "Running_A", "attack": "Ranged_1H_Shoot", "spawn": "Skeletons_Awaken_Standing", "die": "Skeletons_Death", "hit": "Hit_B"},
	},
	"rimeseer": {
		"name": "Rime Seer", "model": "Skeleton_Mage", "weapons": {"handslot.r": "Skeleton_Staff.gltf"}, "skin": "rime", "base": "mage",
		"ai": "caster", "hp": 62.0, "dmg": 22.0, "speed": 2.7, "radius": 0.45, "reach": 9.0, "blast": 2.0, "element": "frost", "leave": "frost",
		"windup": 1.15, "cooldown": 4.0, "mass": 1.2, "xp": 3, "scale": 1.0,
		"anim": {"idle": "Skeletons_Idle", "run": "Skeletons_Walking", "attack": "Ranged_Magic_Spellcasting", "spawn": "Skeletons_Awaken_Standing", "die": "Skeletons_Death", "hit": "Hit_B"},
	},
	"frostcaller": {
		"name": "Winter Caller", "model": "Skeleton_Mage", "weapons": {"handslot.r": "Skeleton_Staff.gltf"}, "skin": "rime", "base": "necro",
		"ai": "necro", "hp": 95.0, "dmg": 0.0, "speed": 2.6, "radius": 0.5, "reach": 9.0, "blast": 3.0,
		"windup": 1.3, "cooldown": 7.0, "mass": 1.5, "xp": 5, "scale": 1.18,
		"anim": {"idle": "Skeletons_Idle", "run": "Skeletons_Walking", "attack": "Ranged_Magic_Summon", "spawn": "Skeletons_Awaken_Standing", "die": "Skeletons_Death", "hit": "Hit_B"},
	},
	"rimehound": {
		"name": "Rime Hound", "model": "Skeleton_Rogue", "weapons": {"handslot.r": "Skeleton_Blade.gltf"}, "skin": "rime", "base": "hound",
		"ai": "charge", "hp": 60.0, "dmg": 17.0, "speed": 4.0, "radius": 0.45, "reach": 1.4, "rider": "chill", "trail": "frost",
		"windup": 0.6, "cooldown": 2.8, "mass": 1.0, "xp": 2, "scale": 0.95,
		"anim": {"idle": "Skeletons_Idle", "run": "Running_A", "attack": "Melee_1H_Attack_Chop", "spawn": "Skeletons_Awaken_Standing", "die": "Skeletons_Death", "hit": "Hit_B"},
	},
	"colossus": {
		"name": "Glacier Colossus", "model": "Skeleton_Warrior", "weapons": {"handslot.r": "axe_2handed.gltf"}, "skin": "rime", "base": "brute",
		"ai": "slam", "hp": 540.0, "dmg": 36.0, "speed": 2.2, "radius": 0.85, "reach": 2.8, "rider": "chill", "leave": "frost", "death": "shatter", "element": "frost",
		"windup": 1.0, "cooldown": 3.4, "mass": 6.0, "xp": 8, "scale": 1.6, "blast": 3.3,
		"anim": {"idle": "Skeletons_Idle", "run": "Skeletons_Walking", "attack": "Melee_2H_Attack_Chop", "spawn": "Skeletons_Awaken_Standing", "die": "Skeletons_Death", "hit": "Hit_B"},
	},
	# The Burning Swamp's dead (the Cinder Warlord's court): drowned bog-bones and
	# charred, ember-veined ones. Fire is the theme: hits scorch, bodies ignite.
	"bogwalker": {
		"name": "Bog Husk", "model": "Skeleton_Minion", "weapons": {"handslot.r": "Skeleton_Blade.gltf"}, "skin": "bog", "base": "minion",
		"ai": "melee", "hp": 36.0, "dmg": 9.0, "speed": 3.4, "radius": 0.42, "reach": 1.25, "death": "ignite",
		"windup": 0.4, "cooldown": 1.1, "mass": 1.0, "xp": 1, "scale": 1.0,
		"anim": {"idle": "Skeletons_Idle", "run": "Running_A", "attack": "Melee_1H_Attack_Chop", "spawn": "Skeletons_Awaken_Standing", "die": "Skeletons_Death", "hit": "Hit_B"},
	},
	"charredguard": {
		"name": "Charred Guard", "model": "Skeleton_Warrior", "weapons": {"handslot.r": "Skeleton_Axe.gltf", "handslot.l": "Skeleton_Shield_Large_B.gltf"}, "skin": "cinder", "base": "warrior",
		"ai": "melee", "hp": 140.0, "dmg": 19.0, "speed": 2.6, "radius": 0.6, "reach": 1.55, "rider": "scorch",
		"windup": 0.6, "cooldown": 1.6, "mass": 3.5, "xp": 3, "scale": 1.12,
		"anim": {"idle": "Skeletons_Idle", "run": "Skeletons_Walking", "attack": "Melee_1H_Attack_Slice_Diagonal", "spawn": "Skeletons_Awaken_Standing", "die": "Skeletons_Death", "hit": "Hit_A"},
	},
	"embershooter": {
		"name": "Ember Spitter", "model": "Skeleton_Rogue", "weapons": {"handslot.r": "Skeleton_Crossbow.gltf"}, "skin": "cinder", "base": "rogue",
		"ai": "ranged", "hp": 46.0, "dmg": 12.0, "speed": 3.1, "radius": 0.45, "reach": 8.5, "rider": "scorch", "proj": "cinderbolt",
		"windup": 0.75, "cooldown": 2.4, "mass": 1.0, "xp": 2, "scale": 1.0, "proj_speed": 12.5,
		"anim": {"idle": "Ranged_1H_Aiming", "run": "Running_A", "attack": "Ranged_1H_Shoot", "spawn": "Skeletons_Awaken_Standing", "die": "Skeletons_Death", "hit": "Hit_B"},
	},
	"cinderwitch": {
		"name": "Cinder Witch", "model": "Skeleton_Mage", "weapons": {"handslot.r": "Skeleton_Staff.gltf"}, "skin": "cinder", "base": "mage",
		"ai": "caster", "hp": 62.0, "dmg": 22.0, "speed": 2.7, "radius": 0.45, "reach": 9.0, "blast": 2.0, "element": "fire", "leave": "fire",
		"windup": 1.15, "cooldown": 4.2, "mass": 1.2, "xp": 3, "scale": 1.0,
		"anim": {"idle": "Skeletons_Idle", "run": "Skeletons_Walking", "attack": "Ranged_Magic_Spellcasting", "spawn": "Skeletons_Awaken_Standing", "die": "Skeletons_Death", "hit": "Hit_B"},
	},
	"pyrecaller": {
		"name": "Pyre Caller", "model": "Skeleton_Mage", "weapons": {"handslot.r": "Skeleton_Staff.gltf"}, "skin": "cinder", "base": "necro",
		"ai": "necro", "hp": 95.0, "dmg": 0.0, "speed": 2.6, "radius": 0.5, "reach": 9.0, "blast": 3.0,
		"windup": 1.3, "cooldown": 7.0, "mass": 1.5, "xp": 5, "scale": 1.18,
		"anim": {"idle": "Skeletons_Idle", "run": "Skeletons_Walking", "attack": "Ranged_Magic_Summon", "spawn": "Skeletons_Awaken_Standing", "die": "Skeletons_Death", "hit": "Hit_B"},
	},
	"bogleaper": {
		"name": "Bog Leaper", "model": "Skeleton_Rogue", "weapons": {"handslot.r": "Skeleton_Blade.gltf"}, "skin": "bog", "base": "hound",
		"ai": "charge", "hp": 60.0, "dmg": 17.0, "speed": 4.0, "radius": 0.45, "reach": 1.4, "rider": "scorch", "trail": "fire",
		"windup": 0.6, "cooldown": 2.8, "mass": 1.0, "xp": 2, "scale": 0.95,
		"anim": {"idle": "Skeletons_Idle", "run": "Running_A", "attack": "Melee_1H_Attack_Chop", "spawn": "Skeletons_Awaken_Standing", "die": "Skeletons_Death", "hit": "Hit_B"},
	},
	"methanebloat": {
		"name": "Methane Bloat", "model": "Skeleton_Minion", "weapons": {"handslot.r": "res://assets/kaykit/dungeon/barrel_small.gltf"}, "skin": "bog", "base": "bomber",
		"ai": "bomb", "hp": 24.0, "dmg": 38.0, "speed": 4.2, "radius": 0.42, "reach": 1.7, "death": "ignite",
		"windup": 0.75, "cooldown": 9.0, "mass": 1.0, "xp": 2, "scale": 1.0, "blast": 2.4,
		"anim": {"idle": "Skeletons_Idle", "run": "Running_A", "attack": "Melee_1H_Attack_Chop", "spawn": "Skeletons_Awaken_Standing", "die": "Skeletons_Death", "hit": "Hit_B"},
	},
	"cinderbrute": {
		"name": "Pyre Brute", "model": "Skeleton_Warrior", "weapons": {"handslot.r": "axe_2handed.gltf"}, "skin": "cinder", "base": "brute",
		"ai": "slam", "hp": 540.0, "dmg": 36.0, "speed": 2.2, "radius": 0.85, "reach": 2.8, "rider": "scorch", "leave": "fire", "death": "ignite", "element": "fire",
		"windup": 1.0, "cooldown": 3.4, "mass": 6.0, "xp": 8, "scale": 1.6, "blast": 3.3,
		"anim": {"idle": "Skeletons_Idle", "run": "Skeletons_Walking", "attack": "Melee_2H_Attack_Chop", "spawn": "Skeletons_Awaken_Standing", "die": "Skeletons_Death", "hit": "Hit_B"},
	},
	"robber": {
		"name": "Grave Robber", "model": "Skeleton_Rogue", "weapons": {},
		"ai": "flee", "hp": 260.0, "dmg": 0.0, "speed": 6.2, "radius": 0.45, "reach": 0.0,
		"windup": 1.0, "cooldown": 99.0, "mass": 1.0, "xp": 10, "scale": 1.1, "tint": Color(1.0, 0.8, 0.2, 0.55),
		"anim": {"idle": "Skeletons_Idle", "run": "Running_A", "attack": "Melee_1H_Attack_Chop", "spawn": "Skeletons_Awaken_Standing", "die": "Skeletons_Death", "hit": "Hit_B"},
	},
}

## Recoloured character textures (tools/art/biome_textures.py): a foe's `skin`
## swaps the texture, keeps the model, and shades it clean (`polish`) instead of
## washing it with a tint. `eyes` is the glow of the skull's eye texels, `veins`
## the glowing seams (the molten grade) in `accent`.
const SKINS := {
	"rime": {"tex": "Skeleton_rime_texture.png", "polish": 0.55, "accent": Color(0.6, 0.88, 1.0), "eyes": Color(0.45, 0.9, 1.0, 1.0), "veins": 0.0, "rough": 0.58},
	"regent": {"tex": "Skeleton_regent_texture.png", "polish": 0.7, "accent": Color(0.55, 0.8, 1.0), "eyes": Color(0.5, 0.9, 1.0, 1.0), "veins": 0.0, "rough": 0.42},
	"bog": {"tex": "Skeleton_bog_texture.png", "polish": 0.0, "accent": Color(1.0, 0.6, 0.2), "eyes": Color(1.0, 0.6, 0.2, 1.0), "veins": 0.0, "rough": 0.85},
	"cinder": {"tex": "Skeleton_cinder_texture.png", "polish": 0.1, "accent": Color(1.0, 0.45, 0.1), "eyes": Color(1.0, 0.55, 0.15, 1.0), "veins": 0.7, "rough": 0.72},
	"ogre": {"tex": "Barbarian_cinder_texture.png", "polish": 0.12, "accent": Color(1.0, 0.42, 0.08), "eyes": Color(1.0, 0.55, 0.15, 0.0), "veins": 0.9, "rough": 0.7},
}

const BOSSES := {
	"gravemaw": {
		"name": "Gravemaw", "title": "the Barrow King", "wake": "the Barrow King wakes", "fall": "Gravemaw falls. Take what is yours.",
		"model": "Skeleton_Warrior", "weapons": {"handslot.r": "axe_2handed.gltf", "handslot.l": "Skeleton_Shield_Large_B.gltf"},
		"hp": 4250.0, "dmg": 26.0, "speed": 3.0, "radius": 1.5, "scale": 2.6, "mass": 40.0,
		"color": Color(0.4, 1.0, 0.75), "el": "poison", "source": "boss", "occluder": Vector2(1.8, 5.0), "summon_line": "The King calls his dead!", "enrage_line": "\"You will lie beside them.\"",
	},
	"thorn": {
		"name": "The Thornmother", "title": "of the Hollow Grove", "wake": "the Thornmother uncurls", "fall": "The Thornmother withers. Take what is yours.",
		"model": "Rogue_Hooded", "weapons": {"handslot.r": "staff.gltf"},
		"hp": 5200.0, "dmg": 25.0, "speed": 3.1, "radius": 1.3, "scale": 2.5, "mass": 35.0,
		"color": Color(0.55, 0.95, 0.35), "el": "nature", "source": "thorn", "occluder": Vector2(1.5, 4.8), "summon_line": "The Grove answers its Mother!", "enrage_line": "\"Root and rot. Feed the wood.\"",
	},
	"hexer": {
		"name": "Hexer Queen", "title": "of the Sunken Crypt", "wake": "the Queen of the Crypt rises", "fall": "The Hexer Queen unravels. Take what is yours.",
		"model": "Skeleton_Mage", "weapons": {"handslot.r": "Skeleton_Staff.gltf"},
		"hp": 4700.0, "dmg": 23.0, "speed": 3.3, "radius": 1.25, "scale": 2.3, "mass": 30.0,
		"color": Color(0.75, 0.4, 1.0), "el": "shadow", "source": "hexer", "occluder": Vector2(1.4, 4.6), "summon_line": "The Queen calls her cult!", "enrage_line": "\"I will unmake you, thread by thread.\"",
	},
	"warden": {
		"name": "The Gilded Warden", "title": "of the Vault", "wake": "the Warden turns the key", "fall": "The Warden kneels. The Vault is open.",
		"model": "Knight", "weapons": {"handslot.r": "warden_key.gltf", "handslot.l": "warden_door.gltf"}, "skin": "Knight_gilded_texture.png",
		"hp": 5600.0, "dmg": 27.0, "speed": 3.0, "radius": 1.4, "scale": 2.5, "mass": 45.0,
		"color": Color(1.0, 0.82, 0.35), "el": "holy", "source": "warden", "occluder": Vector2(1.6, 4.9), "summon_line": "The Warden calls the vault guard!", "enrage_line": "\"Nothing leaves the Vault.\"",
	},
	"rime": {
		"name": "The Frost Troll", "title": "of the Frozen Crypt", "wake": "the Troll stirs in the ice", "fall": "The Troll shatters. The Crypt thaws.",
		# moonbaby2402's troll (assets/foes/frost_troll.tscn, PROVISIONAL); `rig` pulls fit, clips and alias from boss_models.gd.
		# 5.7 m tall at scale 3.0, so the hitbox is wider and the occluder taller than the Regent's.
		"model": "glb:frost_troll", "rig": "frost_troll", "weapons": {}, "skin": "regent",
		"hp": 6000.0, "dmg": 28.0, "speed": 3.0, "radius": 1.95, "scale": 3.0, "mass": 60.0,
		"color": Color(0.55, 0.85, 1.0), "el": "frost", "source": "rime", "occluder": Vector2(2.1, 6.0), "summon_line": "The Troll calls the frozen dead!", "enrage_line": "\"Winter keeps what it takes.\"",
	},
	"cinder": {
		"name": "The Cinder Warlord", "title": "of the Burning Swamp", "wake": "the Warlord climbs from the embers", "fall": "The Warlord gutters out. The Swamp smoulders.",
		# Riltariki's orc (assets/foes/cinder_warlord.tscn); `rig` pulls fit, clips and alias from boss_models.gd.
		# 5.7 m tall at scale 3.0, so the hitbox is wider and the occluder taller than the Ogre's.
		"model": "glb:cinder_warlord", "rig": "cinder_warlord", "weapons": {}, "skin": "ogre",
		"hp": 6400.0, "dmg": 29.0, "speed": 3.0, "radius": 1.95, "scale": 3.0, "mass": 60.0,
		"color": Color(1.0, 0.5, 0.15), "el": "fire", "source": "cinder", "occluder": Vector2(2.1, 6.0), "summon_line": "The Warlord stokes the bog!", "enrage_line": "\"Burn. Burn. BURN.\"",
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
		"loot_bonus": 1, "weights": {"minion": 0.8, "warrior": 0.8, "rogue": 1.4, "mage": 1.8, "necro": 1.5, "hound": 1.4, "brute": 1.6}, "souls_mult": 1.0, "unlock": "Trophy Road: 800 trophies",
		"env": {"bg": Color(0.02, 0.012, 0.03), "ambient": Color(0.4, 0.3, 0.55), "ambient_e": 0.34, "fog": Color(0.1, 0.06, 0.14), "fog_d": 0.016,
			"sun": Color(0.7, 0.62, 1.0), "sun_e": 0.28, "sun_rot": Vector3(-78, -20, 0), "mist": Color(0.6, 0.45, 0.8, 0.09), "motes": Color(1.0, 0.65, 0.35, 0.9)},
	},
	"grove": {
		"name": "The Hollow Grove", "boss": "thorn", "blurb": "An autumn wood. The Grove Cult tends its Mother among the roots.",
		"wake": "Gather %d souls to wake the Thornmother", "defeat": "The Grove keeps you", "enter": "Into the Grove",
		"loot_bonus": 2, "weights": {"rogue": 1.3, "mage": 1.4, "hound": 1.5, "necro": 0.0, "brute": 0.8, "bomber": 1.6},
		"faction": {"minion": "cutthroat", "rogue": "slinger", "mage": "shaman", "warrior": "brawler"},
		"souls_mult": 1.0, "unlock": "Trophy Road: 2500 trophies", "music": "grove", "boss_music": "grove_boss",
		"env": {"bg": Color(0.03, 0.025, 0.015), "ambient": Color(0.55, 0.42, 0.28), "ambient_e": 0.32, "fog": Color(0.16, 0.12, 0.06), "fog_d": 0.014,
			"sun": Color(1.0, 0.72, 0.45), "sun_e": 0.42, "sun_rot": Vector3(-50, -40, 0), "mist": Color(0.75, 0.62, 0.4, 0.1), "motes": Color(0.85, 1.0, 0.45, 0.9)},
	},
	# The fourth zone: the Barrow King's treasury, built from the KayKit
	# dungeon pack. Warm and bright, light fog, so the gold reads crisp.
	"vault": {
		"name": "The Gilded Vault", "boss": "warden", "blurb": "The King's treasury, deep under the barrow. He guards every coin.",
		"wake": "Gather %d souls to wake the King", "defeat": "The Vault keeps you", "enter": "Break into the Vault",
		"loot_bonus": 3, "gold_bonus": 0.25, "weights": {"warrior": 1.6, "rogue": 1.4, "brute": 1.8, "hound": 1.2, "bomber": 1.2, "mage": 1.0}, "souls_mult": 1.0, "unlock": "Trophy Road: 7500 trophies",
		"env": {"bg": Color(0.03, 0.022, 0.012), "ambient": Color(0.62, 0.52, 0.38), "ambient_e": 0.36, "fog": Color(0.12, 0.09, 0.05), "fog_d": 0.006,
			"sun": Color(1.0, 0.86, 0.62), "sun_e": 0.4, "sun_rot": Vector3(-70, -25, 0), "mist": Color(0.8, 0.7, 0.45, 0.06), "motes": Color(1.0, 0.85, 0.4, 0.9)},
	},
	# The fifth and sixth zones: built crisp. No fog (`fog_d` 0), no bloom, no tint
	# washes; `env.weather` is falling snow or rising embers drawn as hard particles and
	# `env.skin` recolours every KayKit prop placed (tools/art/biome_textures.py).
	# `hazards` are run by src/hunt/biome.gd, `ground` recolours the floor shader.
	"frost": {
		"name": "The Frozen Crypt", "boss": "rime", "blurb": "A buried crypt under the ice. The Frost Troll holds the winter.",
		"wake": "Gather %d souls to wake the Troll", "defeat": "The Frost keeps you", "enter": "Into the Frozen Crypt",
		"loot_bonus": 3, "weights": {"warrior": 1.3, "rogue": 1.5, "mage": 1.4, "hound": 1.3, "brute": 1.0, "bomber": 0.0, "necro": 1.0},
		"faction": {"minion": "thrall", "warrior": "frostguard", "rogue": "rimearcher", "mage": "rimeseer", "necro": "frostcaller", "hound": "rimehound", "brute": "colossus"},
		# Rimehollow's own foes (next_foes.gd), fielded while FoeBrains.next is on.
		"faction_next": {"minion": "rh_imp", "warrior": "rh_effigy", "rogue": "rh_wraith", "mage": "rh_seer", "necro": "rh_caller", "hound": "rh_wolf", "brute": "rh_yeti", "bomber": "rh_shard"},
		"weights_next": {"warrior": 1.2, "rogue": 1.4, "mage": 1.3, "hound": 1.6, "brute": 1.0, "bomber": 1.2, "necro": 1.0},
		"souls_mult": 1.0, "unlock": "Trophy Road: 10500 trophies", "music": "frozen", "boss_music": "frozen_boss",
		"hazards": ["icefall", "thin_ice", "gale"],
		"hazard_line": "Icicles fall, thin ice gives way and gales shove",
		"env": {"bg": Color(0.05, 0.075, 0.12), "ambient": Color(0.72, 0.78, 0.9), "ambient_e": 0.5, "fog": Color(0.7, 0.8, 0.95), "fog_d": 0.0, "glow": false, "skin": "", "weather": "snow",
			"sun": Color(0.95, 0.97, 1.0), "sun_e": 1.1, "sun_rot": Vector3(-54, -32, 0), "mist": Color(1, 1, 1, 0.0), "motes": Color(0.92, 0.97, 1.0, 1.0),
			"ground": {"grass_a": Color(0.5, 0.57, 0.67), "grass_b": Color(0.64, 0.71, 0.8), "dirt": Color(0.36, 0.41, 0.5), "dark": Color(0.05, 0.07, 0.11)}},
	},
	"swamp": {
		"name": "The Burning Swamp", "boss": "cinder", "blurb": "A drowned wood alight on its own gas. The Cinder Warlord tends the fires.",
		"wake": "Gather %d souls to wake the Warlord", "defeat": "The Swamp keeps you", "enter": "Into the Burning Swamp",
		"loot_bonus": 3, "gold_bonus": 0.15, "weights": {"warrior": 1.2, "rogue": 1.4, "mage": 1.5, "hound": 1.5, "brute": 1.1, "bomber": 1.7, "necro": 1.0},
		"faction": {"minion": "bogwalker", "warrior": "charredguard", "rogue": "embershooter", "mage": "cinderwitch", "necro": "pyrecaller", "hound": "bogleaper", "bomber": "methanebloat", "brute": "cinderbrute"},
		# The Cinder Mire's own foes. No brute: the Ogre is its only heavy.
		"faction_next": {"minion": "cm_spore", "warrior": "cm_bogfin", "rogue": "cm_imp", "mage": "cm_shaman", "necro": "cm_hag", "hound": "cm_frog", "bomber": "cm_bloat", "skirmisher": "cm_wasp"},
		"weights_next": {"warrior": 1.2, "rogue": 1.2, "mage": 1.4, "hound": 1.4, "brute": 0.0, "bomber": 1.3, "necro": 1.0, "skirmisher": 1.2},
		"souls_mult": 1.0, "unlock": "Trophy Road: 12500 trophies", "music": "swamp", "boss_music": "swamp_boss",
		"hazards": ["vents", "mud", "marsh"],
		"hazard_line": "Vents erupt, mud drags and the marsh ignites",
		"env": {"bg": Color(0.04, 0.03, 0.025), "ambient": Color(0.62, 0.62, 0.64), "ambient_e": 0.95, "fog": Color(0.2, 0.15, 0.1), "fog_d": 0.0, "glow": false, "skin": "swamp", "weather": "embers",
			"sun": Color(0.92, 0.9, 0.86), "sun_e": 1.1, "sun_rot": Vector3(-46, -38, 0), "mist": Color(1, 1, 1, 0.0), "motes": Color(1.0, 0.55, 0.15, 1.0),
			"ground": {"grass_a": Color(0.15, 0.145, 0.12), "grass_b": Color(0.24, 0.225, 0.18), "dirt": Color(0.23, 0.19, 0.15), "dark": Color(0.03, 0.025, 0.02)}},
	},
}
const ZONE_ORDER := ["barrow", "depths", "grove", "vault", "frost", "swamp"]

## How a hunt is played. horde: the soul meter fills, the boss wakes. trial:
## the Long Road, a generated dungeon of rooms to fight through, boss at the
## end. `rooms` is per difficulty tier.
const MODES := {
	"horde": {"name": "Horde Hunt", "short": "Horde", "blurb": "Hold the graveyard against the rising dead."},
	"trial": {"name": "The Long Road", "short": "Long Road", "blurb": "Fight room by room down a new dungeon to the boss.", "unlock": "Trophy Road: 150 trophies", "rooms": [5, 5, 6, 6, 7, 7, 7, 8]},
	"descent": {"name": "Endless Descent", "short": "Descent", "blurb": "The dead never stop. Each minute goes a level deeper; a boss every fifth. How deep can you go?", "unlock": "Trophy Road: 1200 trophies"},
	"wild": {"name": "The Wilderness", "short": "Wilderness", "blurb": "A closing ring and rival bands hunting you. Be the last band standing.", "unlock": "Trophy Road: 2100 trophies"},
	"rush": {"name": "Boss Rush", "short": "Boss Rush", "blurb": "Both bosses, twice, back to back. A card and a breath between each.", "unlock": "Trophy Road: 550 trophies"},
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
const RUSH_ORDER := [["gravemaw", 1.0], ["hexer", 1.0], ["gravemaw", 1.3], ["hexer", 1.35]]
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
		"rogue":
			d.merge({"ai": "melee", "hp": 460.0, "dmg": 20.0, "speed": 4.8, "reach": 2.1, "windup": 0.35, "cooldown": 0.8})
		"ranger":
			d.merge({"ai": "ranged", "hp": 400.0, "dmg": 18.0, "speed": 4.2, "reach": 9.0, "windup": 0.55, "cooldown": 1.5, "proj_speed": 15.0})
		_:
			d.merge({"ai": "caster", "hp": 360.0, "dmg": 28.0, "speed": 3.9, "reach": 8.5, "windup": 1.0, "cooldown": 3.0, "blast": 2.0})
	return d

const MODE_ORDER := ["horde", "trial", "descent", "rush", "rift", "wild"]

static func zone(id: String) -> Dictionary:
	return ZONES[id] if ZONES.has(id) else ZONES["barrow"]


static func boss_def(id: String) -> Dictionary:
	var d: Dictionary = BOSSES[id] if BOSSES.has(id) else BOSSES["gravemaw"]
	if d.has("rig"):
		# A licensed model brings its fit, clips and alias; the boss keeps its own scale and the rest.
		return (BOSS_MODELS.DEFS[str(d["rig"])] as Dictionary).merged(d, true)
	return d

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
	{"id": "hard", "name": "Hard", "hp": 1.7, "dmg": 1.45, "spd": 1.04, "press": 1.12, "souls": 160, "loot": 1.3, "gold": 1.25, "xp": 1.3, "chest": "silver",
		"ai": 0.5, "mech": 0.04, "pen": 0.05, "heal": 0.95, "mat": 0, "power": 550, "color": Color(0.6, 0.85, 0.55)},
	{"id": "veteran", "name": "Veteran", "hp": 2.9, "dmg": 2.1, "spd": 1.08, "press": 1.25, "souls": 170, "loot": 1.6, "gold": 1.5, "xp": 1.6, "chest": "gold",
		"ai": 1.0, "mech": 0.08, "pen": 0.1, "heal": 0.85, "mat": 1, "power": 850, "color": Color(1.0, 0.75, 0.3)},
	{"id": "expert", "name": "Expert", "hp": 4.8, "dmg": 3.0, "spd": 1.12, "press": 1.35, "souls": 180, "loot": 2.1, "gold": 1.8, "xp": 2.0, "chest": "gold",
		"ai": 1.5, "mech": 0.12, "pen": 0.18, "heal": 0.75, "mat": 1, "power": 1300, "color": Color(1.0, 0.55, 0.25)},
	{"id": "nightmare", "name": "Nightmare", "hp": 8.0, "dmg": 4.4, "spd": 1.17, "press": 1.5, "souls": 190, "loot": 2.6, "gold": 2.1, "xp": 2.4, "chest": "crypt",
		"ai": 2.0, "mech": 0.16, "pen": 0.25, "heal": 0.65, "mat": 2, "power": 2000, "color": Color(0.95, 0.25, 0.25)},
	{"id": "hell", "name": "Hell", "hp": 13.5, "dmg": 6.4, "spd": 1.21, "press": 1.6, "souls": 200, "loot": 3.2, "gold": 2.4, "xp": 2.9, "chest": "crypt",
		"ai": 2.3, "mech": 0.22, "pen": 0.32, "heal": 0.55, "mat": 3, "power": 3100, "color": Color(0.85, 0.12, 0.35)},
	{"id": "torment", "name": "Torment", "hp": 23.0, "dmg": 9.0, "spd": 1.25, "press": 1.7, "souls": 210, "loot": 3.9, "gold": 2.7, "xp": 3.4, "chest": "crypt",
		"ai": 2.6, "mech": 0.28, "pen": 0.4, "heal": 0.45, "mat": 3, "power": 4700, "color": Color(0.7, 0.2, 0.85)},
	{"id": "abyss", "name": "Abyss", "hp": 39.0, "dmg": 12.5, "spd": 1.3, "press": 1.8, "souls": 220, "loot": 4.8, "gold": 3.0, "xp": 4.0, "chest": "crypt",
		"ai": 3.0, "mech": 0.35, "pen": 0.45, "heal": 0.35, "mat": 4, "power": 7000, "color": Color(0.35, 0.85, 1.0)},
]
## Old saves had three tiers: Normal, Veteran, Nightmare.
const TIER_FROM_V3 := [0, 2, 4]
## Named tier indices other rules depend on.
const TIER_VETERAN := 2
const TIER_NIGHTMARE := 4
## From Torment up every boss wakes in its Ancient form (Boss.ancient).
const TIER_ANCIENT := 6
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
## Super charge. Hits charge it, but only one swing's worth per swing (the main
## target, not every foe an area hit touches) and never from the super's own
## hits. After a super fires, charge is locked for `lock` seconds. All rate
## bonuses (Wrath, talents, pacts, ranks) add up, then soften toward `rate_cap`.
const SUPER := {"passive": 0.012, "per_hit": 40.0, "lock": 12.0, "rate_cap": 2.2,
	# Earned charge: kills, and staying unhurt for `calm` seconds.
	"kill": 0.006, "calm": 10.0, "calm_gain": 0.10,
	# Backup fill: passive charge only after `floor_after` s with no super.
	"floor_after": 40.0}


## Charge-rate multiplier for a summed bonus (0.25 = +25%): diminishing
## returns, never above SUPER.rate_cap.
static func super_rate(bonus: float) -> float:
	var k := float(SUPER["rate_cap"]) - 1.0
	return 1.0 + k * (1.0 - exp(-maxf(bonus, 0.0) / k))


## Charge one hit adds: `landed` damage, capped at the swing's remaining
## `budget`, none while the super is active or locked.
static func super_hit_charge(landed: float, dmg: float, budget: float, rate: float, blocked: bool) -> float:
	if blocked or budget <= 0.0 or dmg <= 0.0:
		return 0.0
	return minf(landed, budget) / (dmg * float(SUPER["per_hit"])) * rate


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
	"wrath": {"name": "Wrath", "desc": "Super charge +25% (all charge bonuses soften, max x2.2)", "icon": "explosion-rays", "rarity": "rare", "max": 3},
	"multishot": {"name": "Split Shot", "desc": "+1 projectile", "icon": "arrow-cluster", "rarity": "epic", "max": 3, "only": ["bow", "magic"]},
	"pierce": {"name": "Barbed Arrows", "desc": "Arrows pierce one more foe", "icon": "barbed-arrow", "rarity": "rare", "max": 3, "only": ["bow"]},
	"inferno": {"name": "Inferno", "desc": "+35% blast radius", "icon": "fireball", "rarity": "rare", "max": 3, "only": ["magic"]},
	"reach": {"name": "Long Reach", "desc": "+25% swing size", "icon": "sword-spin", "rarity": "rare", "max": 3, "only": ["melee"]},
	"wave": {"name": "Sword Wave", "desc": "Swings launch a cutting wave", "icon": "crossed-swords", "rarity": "epic", "max": 3, "only": ["melee"]},
	"blades": {"name": "Orbiting Blades", "desc": "Spectral blades circle you", "icon": "spinning-blades", "rarity": "epic", "max": 4, "only": ["melee"]},
	"storm": {"name": "Storm Call", "desc": "Lightning strikes chained foes", "icon": "lightning-helix", "rarity": "epic", "max": 4, "only": ["magic"]},
	"nova": {"name": "Fire Nova", "desc": "A ring of fire bursts around you", "icon": "fire-ring", "rarity": "epic", "max": 4, "only": ["magic"]},
	"wisp": {"name": "Hellfire Wisp", "desc": "A fire spirit at your side spits fireballs at random foes", "icon": "fireball", "rarity": "epic", "max": 4},
	"bone_spikes": {"name": "Bone Spikes", "desc": "Bone spikes burst beneath the nearest foes and pin them", "icon": "broken-bone", "rarity": "epic", "max": 4},
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
	"backstab": {"name": "Backstab", "desc": "Your crits hit 60% harder", "icon": "dripping-sword", "rarity": "legendary", "max": 1, "hero": ["rogue"], "sig": true},
	# Road cards: locked until their Trophy Road step (CARD_ROAD), two new epics a hero.
	"oath_storm": {"name": "Storm Oath", "desc": "Your oath calls chain lightning through nearby foes", "icon": "lightning-helix", "rarity": "epic", "max": 4, "hero": ["knight"]},
	"shockwave": {"name": "Shockwave", "desc": "Every few seconds the ground bursts around you", "icon": "fist", "rarity": "epic", "max": 4, "hero": ["knight", "rogue"]},
	"rime_trap": {"name": "Rime Trap", "desc": "A ring of frost bursts around you and slows the pack", "icon": "frozen-orb", "rarity": "epic", "max": 4, "hero": ["ranger", "rogue"]},
	"storm_arrows": {"name": "Storm Arrows", "desc": "Lightning leaps between the foes you shoot", "icon": "lightning-helix", "rarity": "epic", "max": 4, "hero": ["ranger"]},
	"skybolt": {"name": "Skybolt", "desc": "Bolts fall from the sky on the nearest foes", "icon": "sun", "rarity": "epic", "max": 4, "hero": ["mage"]},
	"rift_quake": {"name": "Rift Quake", "desc": "The earth splits around you and hurls foes back", "icon": "fist", "rarity": "epic", "max": 4, "hero": ["mage"]},
	"thunder_cry": {"name": "Thunder Cry", "desc": "Your war cry calls lightning on nearby foes", "icon": "sun", "rarity": "epic", "max": 4, "hero": ["barbarian"]},
	"skyfall": {"name": "Skyfall", "desc": "Burning rocks crash down on the horde", "icon": "meteor-impact", "rarity": "epic", "max": 4, "hero": ["barbarian"]},
	# Sidekick cards: in the pool only with that sidekick at Bond 5+ (see sidekick_db.gd).
	"drake_inferno": {"name": "Drake's Inferno", "desc": "Fire Breath +30% damage", "icon": "fire-breath", "rarity": "rare", "max": 3, "sidekick": "drake", "effect": "power"},
	"drake_nova": {"name": "Dragonfire Nova", "desc": "Fire Breath 20% more often, and each breath bursts a ring of fire", "icon": "dragon-head", "rarity": "epic", "max": 2, "sidekick": "drake", "effect": "haste"},
	"bonelet_rattle": {"name": "Rattlebones", "desc": "Bone Toss +30% damage", "icon": "skull-crossed-bones", "rarity": "rare", "max": 3, "sidekick": "bonelet", "effect": "power"},
	"bonelet_pile": {"name": "Bone Pile", "desc": "Bone Toss 20% more often", "icon": "skull-crossed-bones", "rarity": "epic", "max": 2, "sidekick": "bonelet", "effect": "haste"},
	"hexling_curse": {"name": "Deeper Curse", "desc": "Hex +30% damage", "icon": "magic-swirl", "rarity": "rare", "max": 3, "sidekick": "hexling", "effect": "power"},
	"hexling_doom": {"name": "Doom Clock", "desc": "Hex 20% more often", "icon": "magic-swirl", "rarity": "epic", "max": 2, "sidekick": "hexling", "effect": "haste"},
	"acolyte_bramble": {"name": "Bramble Crown", "desc": "Thorn Ward +30% damage", "icon": "thorny-vine", "rarity": "rare", "max": 3, "sidekick": "acolyte", "effect": "power"},
	"acolyte_grove": {"name": "Grove Prayer", "desc": "Thorn Ward 20% more often", "icon": "thorny-vine", "rarity": "epic", "max": 2, "sidekick": "acolyte", "effect": "haste"},
	"crow_tempest": {"name": "Crow's Tempest", "desc": "Chain Lightning +30% damage", "icon": "raven", "rarity": "rare", "max": 3, "sidekick": "crow", "effect": "power"},
	"crow_thunder": {"name": "Thunderwing", "desc": "Chain Lightning 20% more often", "icon": "lightning-tear", "rarity": "epic", "max": 2, "sidekick": "crow", "effect": "haste"},
	"mimic_greed": {"name": "Greed", "desc": "Gold Snap +30% damage", "icon": "open-treasure-chest", "rarity": "rare", "max": 3, "sidekick": "mimic", "effect": "power"},
	"mimic_jaws": {"name": "Hungry Jaws", "desc": "Gold Snap 20% more often", "icon": "open-treasure-chest", "rarity": "epic", "max": 2, "sidekick": "mimic", "effect": "haste"},
	"bat_frenzy": {"name": "Frenzy", "desc": "Blood Dive +30% damage", "icon": "bat-wing", "rarity": "rare", "max": 3, "sidekick": "bat", "effect": "power"},
	"bat_thirst": {"name": "Thirst", "desc": "Blood Dive 20% more often", "icon": "bat-wing", "rarity": "epic", "max": 2, "sidekick": "bat", "effect": "haste"},
	"squire_iron": {"name": "Iron Oath", "desc": "Shield Bash +30% damage", "icon": "checked-shield", "rarity": "rare", "max": 3, "sidekick": "barrow_squire", "effect": "power"},
	"squire_drill": {"name": "Shield Drill", "desc": "Shield Bash 20% more often", "icon": "checked-shield", "rarity": "epic", "max": 2, "sidekick": "barrow_squire", "effect": "haste"},
	"shade_veil": {"name": "Veil of Night", "desc": "Shadow Strike +30% damage", "icon": "two-shadows", "rarity": "rare", "max": 3, "sidekick": "shade", "effect": "power"},
	"shade_dusk": {"name": "Endless Dusk", "desc": "Shadow Strike 20% more often", "icon": "two-shadows", "rarity": "epic", "max": 2, "sidekick": "shade", "effect": "haste"},
	"sapling_bloom": {"name": "Heartwood Bloom", "desc": "Rootsnare +30% damage", "icon": "lightning-tree", "rarity": "rare", "max": 3, "sidekick": "sapling", "effect": "power"},
	"sapling_deep": {"name": "Deep Roots", "desc": "Rootsnare 20% more often", "icon": "lightning-tree", "rarity": "epic", "max": 2, "sidekick": "sapling", "effect": "haste"},
}
## A companion hero hits at this share of its own damage.
const ALLY_DMG := 0.45
## Card banishes per hunt: remove a card from this hunt's pool for good.
const BANISHES := 3
## Combat level that adds a fourth level-up choice, and one that adds a second
## potion charge.
const FOURTH_CARD_COMBAT := 70
const SECOND_POTION_COMBAT := 95
const CARD_WEIGHT := {"common": 10.0, "rare": 6.0, "epic": 3.2, "legendary": 0.8}

## All foe definitions, base and extra.
static func enemy(kind: String) -> Dictionary:
	if kind.begins_with("rival_"):
		return rival_def(kind.substr(6))
	if NEXT_FOES.FOES.has(kind):
		return NEXT_FOES.FOES[kind]
	return ENEMIES[kind] if ENEMIES.has(kind) else ENEMIES_EXTRA[kind]


static func enemy_kinds() -> Array:
	return ENEMIES.keys() + ENEMIES_EXTRA.keys() + NEXT_FOES.FOES.keys()


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
	# Pet quests: one is dealt a day once a sidekick is yours. `pet` needs one
	# at your side; `gems` (parallel to gold) pays toward the hatchery.
	"pet_win": {"text": "Win a hunt with a sidekick at your side", "stat": "wins", "targets": [1], "gold": [250], "gems": [3], "win": true, "pet": true},
	"pet_kills": {"text": "Slay %d foes with a sidekick at your side", "stat": "kills", "targets": [150, 300], "gold": [150, 300], "gems": [2, 4], "pet": true},
	"pet_hatch": {"text": "Hatch an egg", "stat": "hatched", "targets": [1], "gold": [200], "gems": [3]},
	"pet_breed": {"text": "Breed two sidekicks", "stat": "bred", "targets": [1], "gold": [300], "gems": [4], "needs": 2},
}
## The bounties a sidekick unlocks (the rest of the pool is open to everyone).
const PET_BOUNTIES := ["pet_win", "pet_kills", "pet_hatch", "pet_breed"]
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

## The Trophy Road: every hunt earns trophies (they never go down) and each
## step pays in order. Steps open arenas (zones), modes and heroes, with gold,
## chests and shards between. `pick` lets the player choose one of the
## START_HEROES they lack. Past the last step a Crypt chest every ROAD_EVERY.
## The save keys are still `renown` (trophies) and `road` (steps claimed).
const TROPHY_ROAD := [
	{"t": 60, "kind": "gold", "amount": 300},
	{"t": 150, "kind": "mode", "id": "trial"},
	{"t": 250, "kind": "chest", "chest": "silver"},
	{"t": 400, "kind": "pick"},
	{"t": 550, "kind": "mode", "id": "rush"},
	{"t": 650, "kind": "egg", "egg": "brood"},
	{"t": 800, "kind": "zone", "id": "depths"},
	{"t": 1000, "kind": "chest", "chest": "gold"},
	{"t": 1200, "kind": "mode", "id": "descent"},
	{"t": 1500, "kind": "pick"},
	{"t": 1800, "kind": "egg", "egg": "brood"},
	{"t": 2100, "kind": "mode", "id": "wild"},
	{"t": 2500, "kind": "zone", "id": "grove"},
	{"t": 3000, "kind": "hero", "id": "barbarian"},
	{"t": 3500, "kind": "rift_key"},
	# The long road: steps past 3,500 so the ladder lasts weeks, not an afternoon.
	{"t": 3800, "kind": "cards", "ids": ["oath_storm", "rime_trap", "skybolt", "thunder_cry"]},
	{"t": 4100, "kind": "egg", "egg": "season"},
	{"t": 4400, "kind": "chest", "chest": "gold"},
	{"t": 4700, "kind": "cards", "ids": ["wisp", "thorns"]},
	{"t": 5000, "kind": "chest", "chest": "crypt"},
	{"t": 5300, "kind": "egg", "egg": "season"},
	{"t": 5600, "kind": "gold", "amount": 2500},
	{"t": 5900, "kind": "cards", "ids": ["shockwave", "storm_arrows", "rift_quake", "skyfall"]},
	{"t": 6200, "kind": "chest", "chest": "crypt"},
	{"t": 6500, "kind": "egg", "egg": "season"},
	{"t": 6800, "kind": "hero", "id": "rogue"},
	{"t": 7100, "kind": "chest", "chest": "gold"},
	{"t": 7500, "kind": "zone", "id": "vault"},
	{"t": 7900, "kind": "shards", "amount": 120},
	{"t": 8300, "kind": "egg", "egg": "season"},
	{"t": 8700, "kind": "cards", "ids": ["explosive", "greed"]},
	{"t": 9100, "kind": "chest", "chest": "crypt"},
	{"t": 9500, "kind": "egg", "egg": "exotic"},
	{"t": 9800, "kind": "gold", "amount": 5000},
	{"t": 10000, "kind": "chest", "chest": "crypt"},
	# The cold and the burning: two more arenas out past the first long road.
	{"t": 10500, "kind": "zone", "id": "frost"},
	{"t": 10900, "kind": "egg", "egg": "frost"},
	{"t": 11300, "kind": "chest", "chest": "crypt"},
	{"t": 11900, "kind": "shards", "amount": 150},
	{"t": 12500, "kind": "zone", "id": "swamp"},
	{"t": 12900, "kind": "egg", "egg": "cinder"},
	{"t": 13300, "kind": "chest", "chest": "crypt"},
]
const ROAD_EVERY := 500

## Cards that join the level-up draws only once their road step is claimed.
static func card_road_step(id: String) -> int:
	for i in TROPHY_ROAD.size():
		var st: Dictionary = TROPHY_ROAD[i]
		if str(st["kind"]) == "cards" and id in st["ids"]:
			return i + 1
	return 0
## Arenas are the zones, opened where their step sits on the road.
const ARENAS := [
	{"zone": "barrow", "t": 0, "color": Color(0.36, 0.45, 0.75)},
	{"zone": "depths", "t": 800, "color": Color(0.6, 0.4, 0.8)},
	{"zone": "grove", "t": 2500, "color": Color(0.8, 0.6, 0.28)},
	{"zone": "vault", "t": 7500, "color": Color(0.95, 0.78, 0.35)},
	{"zone": "frost", "t": 10500, "color": Color(0.55, 0.82, 1.0)},
	{"zone": "swamp", "t": 12500, "color": Color(1.0, 0.5, 0.15)},
]
## A new save picks one of these; the rest come from the road's `pick` steps.
const START_HEROES := ["knight", "ranger", "mage"]
## What a pick or hero step pays instead when there is no hero left to give.
const ROAD_SPARE_GOLD := 500

## Trophies for a hunt: a win, more per difficulty above Normal and per elite
## (up to TROPHY_ELITE_CAP), the first win of the day, a difficulty cleared for
## the first time. A loss pays for how far it got, up to TROPHY_LOSS_MAX; the
## Descent pays per depth reached.
const TROPHY_WIN := 30
const TROPHY_TIER := 6
const TROPHY_ELITE := 2
const TROPHY_ELITE_CAP := 5
const TROPHY_FIRST_WIN := 30
const TROPHY_FIRST_CLEAR := 50
const TROPHY_LOSS_MAX := 15
const TROPHY_DEPTH := 4


## Step n (1-based) opens at road_threshold(n); road_threshold(0) is 0.
static func road_threshold(n: int) -> int:
	if n <= 0:
		return 0
	if n <= TROPHY_ROAD.size():
		return int(TROPHY_ROAD[n - 1]["t"])
	return int(TROPHY_ROAD[-1]["t"]) + ROAD_EVERY * (n - TROPHY_ROAD.size())


## What step n (1-based) pays.
static func road_reward(n: int) -> Dictionary:
	if n >= 1 and n <= TROPHY_ROAD.size():
		return TROPHY_ROAD[n - 1]
	# Past the last step: a Crypt chest each time, with an egg every fourth and
	# an exotic every twelfth.
	var k := n - TROPHY_ROAD.size()
	if k % 12 == 0:
		return {"t": road_threshold(n), "kind": "egg", "egg": "exotic"}
	if k % 4 == 0:
		return {"t": road_threshold(n), "kind": "egg", "egg": "season"}
	return {"t": road_threshold(n), "kind": "chest", "chest": "crypt"}


## The trophies at which a mode or zone opens, or -1 if the road never gates it.
## The 1-based road step that opens a zone or mode (0 when none does).
static func road_step(id: String) -> int:
	for i in TROPHY_ROAD.size():
		var st: Dictionary = TROPHY_ROAD[i]
		if st.has("id") and str(st["id"]) == id and str(st["kind"]) in ["mode", "zone"]:
			return i + 1
	return 0


static func road_gate(id: String) -> int:
	for st in TROPHY_ROAD:
		if st.has("id") and str(st["id"]) == id and str(st["kind"]) in ["mode", "zone"]:
			return int(st["t"])
	return -1


## Weekly omens: one rule twist for a week, with a bigger chest. `mod` keys are
## the same as PACTS'; `no_dash` removes the dash.
const WEEKLY_OMENS := [
	{"id": "swarm", "name": "The Swarm", "desc": "Half again as many foes, each a little frailer.", "icon": "bone-gnawer", "mod": {"pack": 0.5, "foe_hp": -0.2}},
	{"id": "still", "name": "Stillness", "desc": "No dash. Your super charges 50% faster.", "icon": "hourglass", "mod": {"super": 0.5}, "no_dash": true},
	{"id": "swiftdead", "name": "The Swift Dead", "desc": "Every foe moves 20% faster.", "icon": "running-shoe", "mod": {"foe_speed": 0.2}},
	{"id": "glass", "name": "Glass Hunt", "desc": "+60% damage, but you have 40% less health.", "icon": "broken-bone", "mod": {"dmg": 0.6, "hp": -0.4}},
	{"id": "ironclad", "name": "Ironclad Dead", "desc": "Foes have 50% more health; you take 20% less damage.", "icon": "checked-shield", "mod": {"foe_hp": 0.5, "dmg_taken": -0.2}},
	{"id": "frenzy", "name": "Blood Frenzy", "desc": "Foes hit 30% harder; you attack 30% faster.", "icon": "dripping-sword", "mod": {"rate": 0.3, "foe_dmg": 0.3}},
	{"id": "paper", "name": "Paper Crowns", "desc": "Twice the foes, each at half health.", "icon": "crowned-skull", "mod": {"pack": 1.0, "foe_hp": -0.5}},
	{"id": "titans", "name": "Week of Titans", "desc": "Few foes, but double health and 20% harder hits. You deal 40% more.", "icon": "tombstone", "mod": {"pack": -0.4, "foe_hp": 1.0, "foe_dmg": 0.2, "dmg": 0.4}},
]
## A won omen hunt pays 25% more gold and its chest is one grade better.
const OMEN_GOLD := 0.25

## The weekly event: the omen's hunts earn event points (score / EVENT_SCORE_DIV)
## toward a rewards track that resets with the week. EVENT_TRACK[n-1] is the
## total points for tier n.
const EVENT_SCORE_DIV := 10
const EVENT_TRACK := [150, 400, 700, 1100, 1600, 2200, 2900, 3700, 4600, 5600]
## Rows of the event board on the camp sheet.
const EVENT_BOARD_ROWS := 8

static func event_points_for(score: int) -> int:
	return maxi(score, 0) / EVENT_SCORE_DIV


## What tier `n` (1..10) of the event track pays. The last is the week's prize.
static func event_reward(n: int) -> Dictionary:
	if n == EVENT_TRACK.size():
		return {"kind": "chest", "chest": "crypt"}
	if n == 4:
		return {"kind": "egg", "egg": "brood"}
	if n == 7:
		return {"kind": "egg", "egg": "season"}
	if n == 9:
		return {"kind": "egg", "egg": "omen"}
	if n % 5 == 0:
		return {"kind": "chest", "chest": "gold"}
	if n % 3 == 0:
		return {"kind": "gems", "amount": 12 + 2 * n}
	if n % 2 == 0:
		return {"kind": "shards", "amount": 20 + 5 * n}
	return {"kind": "gold", "amount": 400 + 150 * n}

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
	"cleaver": {"cls": "barbarian", "fam": "axe", "dye": Color(0.45, 0.95, 0.7), "name": "Gravemaw's Cleaver", "slot": "weapon", "rarity": "legendary", "source": "boss", "rate": 25, "stats": {"dmg": 30, "aspd": 10}, "card": "blades", "power": "Start every hunt with Orbiting Blades", "icon": "battle-axe"},
	"shroud": {"cls": "ranger", "dye": Color(0.12, 0.28, 0.22), "name": "Shroud of the Barrow", "slot": "chest", "rarity": "legendary", "source": "boss", "rate": 25, "stats": {"hp": 30, "armor": 8}, "card": "ward", "power": "Start every hunt with Bone Ward", "icon": "breastplate"},
	"crown": {"cls": "knight", "dye": Color(0.95, 0.78, 0.3), "name": "Crown of the Barrow King", "slot": "helm", "rarity": "legendary", "source": "boss", "rate": 40, "stats": {"crit": 10, "gold": 25}, "card": "smite", "power": "Start every hunt with Holy Smite", "icon": "crowned-skull"},
	"emberheart": {"cls": "mage", "dye": Color(1.0, 0.4, 0.1), "name": "Emberheart", "slot": "trinket", "rarity": "legendary", "source": "elite", "rate": 60, "stats": {"dmg": 12, "regen": 4}, "card": "nova", "power": "Start every hunt with Fire Nova", "icon": "flame"},
	"scepter": {"cls": "mage", "fam": "scepter", "dye": Color(0.75, 0.4, 1.0), "name": "Hexer's Scepter", "slot": "weapon", "rarity": "legendary", "source": "hexer", "rate": 25, "stats": {"dmg": 26, "crit": 8}, "card": "leech", "power": "Start every hunt with Bloodthirst", "icon": "wizard-staff"},
	"gown": {"cls": "mage", "dye": Color(0.45, 0.2, 0.6), "name": "Gown of Thorns", "slot": "chest", "rarity": "legendary", "source": "hexer", "rate": 25, "stats": {"hp": 24, "armor": 6}, "card": "frost", "power": "Start every hunt with Frost Ring", "icon": "breastplate"},
	"greaves": {"cls": "knight", "dye": Color(0.5, 0.85, 1.0), "name": "Wraithstep Greaves", "slot": "legs", "rarity": "legendary", "source": "hexer", "rate": 30, "stats": {"speed": 8, "hp": 14}, "card": "regen", "power": "Start every hunt with Second Breath", "icon": "leg-armor"},
	"charm": {"name": "Hex Charm", "slot": "trophy", "rarity": "magic", "source": "hexer", "rate": 4, "icon": "gems", "power": "A cultist's token. Sells for 90 gold.", "sell": 90},
	"bonelet": {"name": "Bonelet", "slot": "pet", "rarity": "legendary", "source": "boss", "rate": 50, "icon": "skull-crossed-bones", "power": "Sidekick: Bone Toss bounces between 3 foes.", "model": "Skeleton_Minion"},
	"hexling": {"name": "Hexling", "slot": "pet", "rarity": "legendary", "source": "hexer", "rate": 50, "icon": "magic-swirl", "power": "Sidekick: Hex curses the toughest foe, then bursts.", "model": "Skeleton_Mage"},
	"sigil": {"name": "Champion's Sigil", "slot": "trophy", "rarity": "rare", "source": "elite", "rate": 12, "icon": "rune-stone", "power": "Proof of a champion slain. Sells for 150 gold.", "sell": 150},
	"tooth": {"name": "Barrow Tooth", "slot": "trophy", "rarity": "magic", "source": "boss", "rate": 4, "icon": "broken-bone", "power": "An old king's tooth. Sells for 60 gold.", "sell": 60},
	"thornbow": {"cls": "ranger", "fam": "longbow", "dye": Color(0.45, 0.85, 0.3), "name": "Thornwood Longbow", "slot": "weapon", "rarity": "legendary", "source": "thorn", "rate": 25, "stats": {"dmg": 28, "crit": 9}, "card": "barrage", "power": "Start every hunt with Arrow Storm", "icon": "pocket-bow"},
	"barkplate": {"cls": "barbarian", "dye": Color(0.4, 0.3, 0.18), "name": "Barkhide Plate", "slot": "chest", "rarity": "legendary", "source": "thorn", "rate": 25, "stats": {"hp": 32, "armor": 9}, "card": "thorns", "power": "Start every hunt with Thorns", "icon": "breastplate"},
	"seedheart": {"cls": "knight", "dye": Color(0.6, 1.0, 0.4), "name": "Seedheart Aegis", "slot": "trinket", "rarity": "legendary", "source": "thorn", "rate": 30, "stats": {"aspd": 12, "regen": 5}, "card": "ward", "power": "Start every hunt with Bone Ward", "icon": "shield"},
	# Ancient forms (Torment and up): a relic and a pet each.
	"barrow_relic": {"name": "Ancient Barrow Crown", "slot": "trophy", "rarity": "legendary", "source": "ancient_boss", "rate": 30, "icon": "crowned-skull", "power": "Cold iron from the first king. Sells for 5000 gold.", "sell": 5000},
	"barrow_squire": {"name": "Barrow Squire", "slot": "pet", "rarity": "legendary", "source": "ancient_boss", "rate": 60, "icon": "skull-crossed-bones", "power": "Sidekick: Shield Bash stuns the pack.", "model": "Skeleton_Warrior"},
	"hex_relic": {"name": "Ancient Hex Spindle", "slot": "trophy", "rarity": "legendary", "source": "ancient_hexer", "rate": 30, "icon": "magic-swirl", "power": "Still spinning. Sells for 5000 gold.", "sell": 5000},
	"shade": {"name": "Hexbound Shade", "slot": "pet", "rarity": "legendary", "source": "ancient_hexer", "rate": 60, "icon": "ghost", "power": "Sidekick: Shadow Strike hunts the toughest foes.", "model": "Skeleton_Rogue"},
	"thorn_relic": {"name": "Ancient Heartwood", "slot": "trophy", "rarity": "legendary", "source": "ancient_thorn", "rate": 30, "icon": "crystal-shine", "power": "Warm to the touch. Sells for 5000 gold.", "sell": 5000},
	"sapling": {"name": "Thorn Sapling", "slot": "pet", "rarity": "legendary", "source": "ancient_thorn", "rate": 60, "icon": "ghost", "power": "Sidekick: Rootsnare holds the pack.", "model": "Sapling"},
	"acolyte": {"name": "Acolyte", "slot": "pet", "rarity": "legendary", "source": "thorn", "rate": 50, "icon": "ghost", "power": "Sidekick: Thorn Ward throws foes back.", "model": "Rogue_Hooded"},
	"seed": {"name": "Thorn Seed", "slot": "trophy", "rarity": "magic", "source": "thorn", "rate": 4, "icon": "gems", "power": "It wriggles. Sells for 80 gold.", "sell": 80},
	# The Gilded Warden (the Vault).
	"gilded_fang": {"cls": "rogue", "fam": "daggers", "dye": Color(1.0, 0.82, 0.35), "name": "Gilded Fangs", "slot": "weapon", "rarity": "legendary", "source": "warden", "rate": 25, "stats": {"dmg": 27, "crit": 10}, "card": "greed", "power": "Start every hunt with Grave Robber", "icon": "cloak-dagger"},
	"hoardplate": {"cls": "knight", "dye": Color(1.0, 0.8, 0.35), "name": "Hoardplate", "slot": "chest", "rarity": "legendary", "source": "warden", "rate": 25, "stats": {"hp": 32, "armor": 9}, "card": "ward", "power": "Start every hunt with Bone Ward", "icon": "breastplate"},
	"vault_coin": {"name": "Vault Sovereign", "slot": "trophy", "rarity": "magic", "source": "warden", "rate": 4, "icon": "two-coins", "power": "Heavier than it looks. Sells for 120 gold.", "sell": 120},
	# The Frost Troll (the Frozen Crypt).
	"rime_maul": {"cls": "knight", "fam": "warhammer", "dye": Color(0.55, 0.85, 1.0), "name": "Glacierfall Maul", "slot": "weapon", "rarity": "legendary", "source": "rime", "rate": 25, "stats": {"dmg": 30, "hp": 10}, "card": "ward", "power": "Start every hunt with Bone Ward", "icon": "warhammer"},
	"rime_robe": {"cls": "mage", "dye": Color(0.78, 0.92, 1.0), "name": "Rimewoven Robes", "slot": "chest", "rarity": "legendary", "source": "rime", "rate": 25, "stats": {"hp": 30, "armor": 9}, "card": "regen", "power": "Start every hunt with Second Breath", "icon": "robe"},
	"rime_cowl": {"cls": "ranger", "dye": Color(0.62, 0.82, 1.0), "name": "Winter's Cowl", "slot": "helm", "rarity": "legendary", "source": "rime", "rate": 30, "stats": {"crit": 9, "speed": 6}, "card": "barrage", "power": "Start every hunt with Arrow Storm", "icon": "hood"},
	"rime_shard": {"name": "Rime Shard", "slot": "trophy", "rarity": "magic", "source": "rime", "rate": 4, "icon": "crystal-shine", "power": "It does not melt. Sells for 130 gold.", "sell": 130},
	"rime_relic": {"name": "Ancient Winter Seal", "slot": "trophy", "rarity": "legendary", "source": "ancient_rime", "rate": 30, "icon": "frozen-orb", "power": "Cold as the first frost. Sells for 5000 gold.", "sell": 5000},
	# The Cinder Warlord (the Burning Swamp).
	"cinder_maul": {"cls": "barbarian", "fam": "maul", "dye": Color(1.0, 0.45, 0.12), "name": "Ashmaker", "slot": "weapon", "rarity": "legendary", "source": "cinder", "rate": 25, "stats": {"dmg": 31, "aspd": 9}, "card": "wisp", "power": "Start every hunt with Hellfire Wisp", "icon": "warhammer"},
	"cinder_plate": {"cls": "knight", "dye": Color(0.3, 0.14, 0.08), "name": "Pyreplate", "slot": "chest", "rarity": "legendary", "source": "cinder", "rate": 25, "stats": {"hp": 34, "armor": 8}, "card": "thorns", "power": "Start every hunt with Thorns", "icon": "breastplate"},
	"cinder_boots": {"cls": "rogue", "dye": Color(0.85, 0.32, 0.1), "name": "Emberstride Boots", "slot": "legs", "rarity": "legendary", "source": "cinder", "rate": 30, "stats": {"speed": 9, "hp": 12}, "card": "greed", "power": "Start every hunt with Grave Robber", "icon": "boots"},
	"cinder_core": {"name": "Cinder Core", "slot": "trophy", "rarity": "magic", "source": "cinder", "rate": 4, "icon": "flame", "power": "Still warm. Sells for 140 gold.", "sell": 140},
	"cinder_relic": {"name": "Ancient Warlord Brand", "slot": "trophy", "rarity": "legendary", "source": "ancient_cinder", "rate": 30, "icon": "fire-ring", "power": "It never cools. Sells for 5000 gold.", "sell": 5000},
	"abyssal": {"name": "Abyssal Gem", "slot": "trophy", "rarity": "legendary", "source": "nightmare", "rate": 80, "icon": "crystal-shine", "power": "It hums. Sells for 2000 gold.", "sell": 2000},
}
const LOG_ORDER := ["cleaver", "shroud", "crown", "bonelet", "tooth", "scepter", "gown", "greaves", "hexling", "charm", "thornbow", "barkplate", "seedheart", "acolyte", "seed", "emberheart", "sigil", "abyssal", "barrow_relic", "barrow_squire", "hex_relic", "shade", "thorn_relic", "sapling", "gilded_fang", "hoardplate", "vault_coin", "rime_maul", "rime_robe", "rime_cowl", "rime_shard", "rime_relic", "cinder_maul", "cinder_plate", "cinder_boots", "cinder_core", "cinder_relic"]
## Unique sources and the boss whose kill count and dry streak they follow.
const SOURCE_BOSS := {"boss": "gravemaw", "hexer": "hexer", "thorn": "thorn", "warden": "warden", "rime": "rime", "cinder": "cinder"}

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
	"strength": "+4.5% melee damage per level (1.5% past 41)",
	"defence": "+0.4% damage reduction per level",
	"hitpoints": "+4.5% health per level (1.5% past 50)",
	"ranged": "+4.5% bow damage (1.5% past 41), +0.6% speed per level",
	"magic": "+4.5% spell damage (1.5% past 41), +0.6% speed per level",
}
## The skills each style trains. Every one gets a third of the hunt's XP, so
## all heroes level at the same pace: Ranged and Magic do the work of Attack
## and Strength together.
const STYLE_SKILLS := {
	"melee": ["attack", "strength", "defence", "hitpoints"],
	"ranged": ["ranged", "defence", "hitpoints"],
	"magic": ["magic", "defence", "hitpoints"],
}
## The skills are the hero's whole power (OSRS: no character level). Damage
## and health grow SKILL_EARLY per level for the first SKILL_KNEE levels (about
## what bought levels used to give), then SKILL_LATE so 99 is not runaway.
const SKILL_EARLY := 0.045
const SKILL_LATE := 0.015
const SKILL_KNEE := 40
const SKILL_SPEED := 0.006
const SKILL_ARMOR := 0.004
## Talent points: one per this many combat levels above 3, up to the cap.
const TALENT_COMBAT_STEP := 5
const TALENT_MAX := 19
## XP lamps: shards rubbed into a skill, worth this much XP per shard per
## level of the skill (OSRS lamps scale with level too).
const LAMP_SHARDS := 10

## Super ranks: the job for shards. Each rank costs shards plus gold and adds
## the change its line says, so the price and payoff are always readable.
## Super rank prices (shards + gold). Ranks change what the super does, never
## how fast it charges: see SUPER_PERKS.
const SUPER_RANKS := [
	{"shards": 50, "gold": 1000},
	{"shards": 100, "gold": 3000},
	{"shards": 200, "gold": 7000},
	{"shards": 350, "gold": 15000},
	{"shards": 500, "gold": 30000},
]

## The super unlocks at hero combat level `level`, or for every hero once the
## Trophy Road reaches `trophies`.
const SUPER_UNLOCK := {"level": 5, "trophies": 150}

## What each rank adds, per super. Numbers add up across ranks; `lock` is
## seconds off the lockout after the super.
const SUPER_PERKS := {
	"slam": [
		{"text": "Wider slam", "radius": 1.0},
		{"text": "Stun lasts 1 s longer", "stun": 1.0},
		{"text": "A second, smaller slam lands after the first", "echo": 1},
		{"text": "Lightning strikes along the leap", "trail": 1},
		{"text": "Lockout 2 s shorter", "lock": -2.0},
	],
	"whirlwind": [
		{"text": "Spin lasts 0.8 s longer", "dur": 0.8},
		{"text": "Wider spin", "radius": 0.8},
		{"text": "Each spin that cuts a foe heals 1% health", "heal": 0.01},
		{"text": "Ends in a fire blast", "finale": 1},
		{"text": "Lockout 2 s shorter", "lock": -2.0},
	],
	"volley": [
		{"text": "+6 arrows in the fan", "arrows": 6},
		{"text": "Arrow rain covers 3 more foes", "rain": 3},
		{"text": "A second fan follows the first", "echo": 1},
		{"text": "Arrow rain pins foes in place", "stun": 0.6},
		{"text": "Lockout 2 s shorter", "lock": -2.0},
	],
	"meteor": [
		{"text": "+3 meteors", "count": 3},
		{"text": "Bigger blasts", "radius": 0.7},
		{"text": "Meteors stun", "stun": 0.8},
		{"text": "A great meteor falls last", "echo": 1},
		{"text": "Lockout 2 s shorter", "lock": -2.0},
	],
	"shadowstep": [
		{"text": "Blink to 3 more foes", "marks": 3},
		{"text": "Longer reach", "reach": 3.0},
		{"text": "Stabs stun", "stun": 1.0},
		{"text": "Ends in a smoke burst", "finale": 1},
		{"text": "Lockout 2 s shorter", "lock": -2.0},
	],
}


## The summed perks of a `kind` super at `rank` (0 to SUPER_RANKS.size()).
static func super_perks(kind: String, rank: int) -> Dictionary:
	var out := {}
	var list: Array = SUPER_PERKS.get(kind, [])
	for i in clampi(rank, 0, list.size()):
		for k: String in list[i]:
			if k != "text":
				out[k] = float(out.get(k, 0.0)) + float(list[i][k])
	return out
const LAMP_XP := 5
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


## Damage or health multiplier from a skill at `level`, counted from `floor`.
static func skill_mult(level: int, floor_lv := 1) -> float:
	var l := maxi(level - floor_lv, 0)
	return 1.0 + SKILL_EARLY * mini(l, SKILL_KNEE) + SKILL_LATE * maxi(l - SKILL_KNEE, 0)


static func combat_level(levels: Dictionary) -> int:
	var base: float = 0.25 * (int(levels.get("defence", 1)) + int(levels.get("hitpoints", 10)))
	var melee: float = 0.325 * (int(levels.get("attack", 1)) + int(levels.get("strength", 1)))
	# OSRS counts Ranged and Magic 1.5x; here one of them stands in for Attack
	# and Strength together, so 2x keeps every hero's top combat level equal.
	var rng: float = 0.325 * 2 * int(levels.get("ranged", 1))
	var mag: float = 0.325 * 2 * int(levels.get("magic", 1))
	return int(floor(base + maxf(melee, maxf(rng, mag))))


# --- Gold sinks -------------------------------------------------------------

## Gear is a collection: one copy of each piece. Later drops of a piece are
## copies, and copies plus gold level it up (Clash Royale cards). A piece's
## stats are fixed: its slot's main stat and, from Warden up, its set's own
## second stat, times the set (MAT_STAT a step) and the level.
const PIECE_MAX_LV := 10
const PIECE_LV_STAT := 0.08
## The second stat each set adds (Gravedigger has none).
const SET_STAT := ["", "armor", "hp", "crit", "regen"]
## Copies used up to go from level n to n + 1 (index n - 1), and the gold,
## which also grows with the set: the long-term gold sink.
const PIECE_CARDS := [1, 2, 3, 4, 6, 8, 11, 15, 20]
const PIECE_GOLD := [60, 120, 220, 380, 600, 900, 1300, 1900, 2700]
const PIECE_GOLD_SET := 0.6
## Copy trading: TRADE_COPIES spare copies of a piece become one copy of another
## piece in the same slot and set, for TRADE_GOLD x the set's gold factor.
const TRADE_COPIES := 3
const TRADE_GOLD := 200
## Talent reset: the first is free, then this much per talent point earned.
const RESPEC_GOLD := 90

## What taking a piece from level `lv` to the next costs: {cards, gold}.
static func level_cost(it: Dictionary) -> Dictionary:
	var lv := clampi(int(it.get("lv", 1)), 1, PIECE_MAX_LV - 1)
	var g := float(PIECE_GOLD[lv - 1]) * (1.0 + PIECE_GOLD_SET * int(it.get("mat", 0)))
	return {"cards": int(PIECE_CARDS[lv - 1]), "gold": int(round(g / 10.0)) * 10}

## Weapon glows bought with gold, per hero. "" is none.
const GLOWS := {
	"ember": {"name": "Ember", "color": Color(1.0, 0.45, 0.12, 0.45), "gold": 2500},
	"frost": {"name": "Frost", "color": Color(0.4, 0.85, 1.0, 0.45), "gold": 2500},
	"venom": {"name": "Venom", "color": Color(0.45, 1.0, 0.35, 0.45), "gold": 4000},
	"void": {"name": "Void", "color": Color(0.7, 0.3, 1.0, 0.5), "gold": 6000},
	"gold": {"name": "Kingsgold", "color": Color(1.0, 0.85, 0.3, 0.55), "gold": 12000},
	# Not for sale: earned when a friend you invited plays their first hunts.
	"kinship": {"name": "Kinship", "color": Color(0.35, 0.75, 1.0, 0.55), "gold": 0, "gift": true},
	# Not for sale: hero mastery ranks pay these, so the shop's glows stay worth buying.
	"bloodmoon": {"name": "Bloodmoon", "color": Color(0.85, 0.12, 0.18, 0.5), "gold": 0, "gift": true},
	"wraith": {"name": "Wraith", "color": Color(0.8, 0.95, 0.9, 0.5), "gold": 0, "gift": true},
	"sunsteel": {"name": "Sunsteel", "color": Color(1.0, 0.95, 0.7, 0.6), "gold": 0, "gift": true},
}
const GLOW_ORDER := ["ember", "frost", "venom", "void", "gold", "kinship", "bloodmoon", "wraith", "sunsteel"]

# --- Shop -------------------------------------------------------------------------

## Everything costs gold the game pays out; nothing is sold for money. Chests
## cost about three times the gold inside them, so buying one trades gold for
## shards and gear, never gold for more gold.
const SHOP_CHESTS := {"silver": 400, "gold": 1100, "crypt": 2600}
## Daily deals, drawn fresh each day: a free gift, shards for two heroes, copies
## of two pieces for the hero in use and a chest at a discount. Each sells once.
const SHOP_SHARD_GOLD := 30
const SHOP_DEAL_OFF := 0.25
const SHOP_CHEST_OFF := 0.3
const SHOP_FREE_GOLD := 80
const SHOP_FREE_GOLD_TIER := 25
const SHOP_FREE_SHARDS := 5
## A copy of a piece, then +SHOP_GEAR_MAT for each set above the first.
const SHOP_GEAR_GOLD := 400
const SHOP_GEAR_MAT := 0.6
## One glow a week is on sale for every hero.
const SHOP_GLOW_OFF := 0.3

static func shop_gear_price(it: Dictionary) -> int:
	return int(round(SHOP_GEAR_GOLD * (1.0 + SHOP_GEAR_MAT * int(it.get("mat", 0))) / 10.0)) * 10


## Weapon skins: a new model in the hand, whatever weapon is equipped (the
## stats stay the item's). Bought with gold per hero. `model` is a file in
## assets/kaykit/weapons/; ours are built by the scripts in tools/art/.
const WEAPON_SKINS := {
	"oathbound": {"name": "Oathbound Blade", "model": "oathbound_blade.gltf", "icon": "broadsword", "scale": 1.0, "heroes": ["knight"], "gold": 6000},
	# Held one-handed and pointing forward, a scythe reads as a spear: the
	# Knight's idle pose is why it is the Barbarian's alone.
	"reaper": {"name": "Reaper's Scythe", "model": "reaper_scythe.gltf", "icon": "scythe", "scale": 0.85, "heroes": ["barbarian"], "gold": 8000},
	# KayKit Fantasy Weapons models, unmodified: about four looks a hero.
	"squire": {"name": "Squire's Pride", "model": "sword_A.gltf", "icon": "broadsword", "scale": 1.0, "heroes": ["knight"], "gold": 10000},
	"warden": {"name": "Gravewarden", "model": "sword_D.gltf", "icon": "dripping-sword", "scale": 1.0, "heroes": ["knight"], "gold": 20000},
	"dawn": {"name": "Dawnbreaker", "model": "hammer_B.gltf", "icon": "warhammer", "scale": 1.0, "heroes": ["knight"], "gold": 35000},
	"willow": {"name": "Willowstring", "model": "bow_A_withString.gltf", "icon": "pocket-bow", "scale": 1.0, "heroes": ["ranger"], "gold": 8000},
	"hawk": {"name": "Hawkeye Longbow", "model": "bow_B_withString.gltf", "icon": "bow-arrow", "scale": 1.0, "heroes": ["ranger"], "gold": 18000},
	"bolt": {"name": "Boltcaster", "model": "crossbow_2handed.gltf", "icon": "crossbow", "scale": 1.0, "heroes": ["ranger"], "gold": 28000},
	"elder": {"name": "Elder Bough", "model": "staff_A.gltf", "icon": "wizard-staff", "scale": 1.0, "heroes": ["mage"], "gold": 8000},
	"sprite": {"name": "Spritewand", "model": "wand_A.gltf", "icon": "fairy-wand", "scale": 1.0, "heroes": ["mage"], "gold": 16000},
	"grimoire": {"name": "Open Grimoire", "model": "spellbook_open.gltf", "icon": "spell-book", "scale": 1.0, "heroes": ["mage"], "gold": 26000},
	"hexstaff": {"name": "Hexwood Staff", "model": "staff_B.gltf", "icon": "skull-staff", "scale": 1.0, "heroes": ["mage"], "gold": 40000},
	"cleaver": {"name": "Raider's Cleaver", "model": "axe_A.gltf", "icon": "battle-axe", "scale": 1.0, "heroes": ["barbarian"], "gold": 12000},
	"crusher": {"name": "Skullcrusher", "model": "hammer_A.gltf", "icon": "warhammer", "scale": 1.0, "heroes": ["barbarian"], "gold": 22000},
	"twinfang": {"name": "Twinfang Axe", "model": "axe_C.gltf", "icon": "crossed-axes", "scale": 1.0, "heroes": ["barbarian"], "gold": 40000},
	"kris": {"name": "Wavy Kris", "model": "dagger_A.gltf", "icon": "cloak-dagger", "scale": 1.0, "heroes": ["rogue"], "gold": 8000},
	"stiletto": {"name": "Night Stiletto", "model": "dagger_B.gltf", "icon": "cloak-dagger", "scale": 1.0, "heroes": ["rogue"], "gold": 16000},
	"duelblade": {"name": "Duelist's Blade", "model": "sword_B.gltf", "icon": "crossed-swords", "scale": 0.8, "heroes": ["rogue"], "gold": 26000},
	"boneshiv": {"name": "Bone Shiv", "model": "Skeleton_Blade.gltf", "icon": "dripping-sword", "scale": 0.8, "heroes": ["rogue"], "gold": 40000},
}
const WEAPON_SKIN_ORDER := ["oathbound", "squire", "warden", "dawn", "willow", "hawk", "bolt", "elder", "sprite", "grimoire", "hexstaff", "reaper", "cleaver", "crusher", "twinfang", "kris", "stiletto", "duelblade", "boneshiv"]

## Outfits: a whole-body dye over what the hero wears, for the look only. Gear
## still decides the shapes; the dye keeps the cloth's own light and dark, so
## it stays crisp. `mix` is how much of the dye replaces the texture, `polish`
## (0..1) a clean, glossy finish, `shimmer` a band of light sweeping the
## outfit. `gift` outfits are earned (the season pass), never sold.
const OUTFITS := {
	"crimson": {"name": "Crimson Guard", "heroes": ["knight"], "dye": Color(0.8, 0.13, 0.16), "mix": 0.8, "polish": 0.0, "shimmer": 0.0, "gold": 12000},
	"gilded": {"name": "Gilded Oath", "heroes": ["knight"], "dye": Color(1.0, 0.76, 0.28), "mix": 0.85, "polish": 0.8, "shimmer": 0.6, "gold": 32000},
	"frostwood": {"name": "Frostwood", "heroes": ["ranger"], "dye": Color(0.55, 0.82, 1.0), "mix": 0.8, "polish": 0.0, "shimmer": 0.0, "gold": 10000},
	"emberstalker": {"name": "Emberstalker", "heroes": ["ranger"], "dye": Color(0.95, 0.42, 0.12), "mix": 0.82, "polish": 0.6, "shimmer": 0.5, "gold": 26000},
	"ashen": {"name": "Ashen Weave", "heroes": ["mage"], "dye": Color(0.62, 0.62, 0.7), "mix": 0.8, "polish": 0.0, "shimmer": 0.0, "gold": 10000},
	"sunfire": {"name": "Sunfire Vestments", "heroes": ["mage"], "dye": Color(1.0, 0.6, 0.15), "mix": 0.82, "polish": 0.7, "shimmer": 0.6, "gold": 28000},
	"bloodmoon": {"name": "Bloodmoon Raider", "heroes": ["barbarian"], "dye": Color(0.62, 0.07, 0.1), "mix": 0.8, "polish": 0.0, "shimmer": 0.0, "gold": 12000},
	"glacier": {"name": "Glacier Clan", "heroes": ["barbarian"], "dye": Color(0.6, 0.86, 0.96), "mix": 0.8, "polish": 0.6, "shimmer": 0.5, "gold": 28000},
	"midnight": {"name": "Midnight Shroud", "heroes": ["rogue"], "dye": Color(0.16, 0.2, 0.5), "mix": 0.82, "polish": 0.0, "shimmer": 0.0, "gold": 10000},
	"viper": {"name": "Viridian Viper", "heroes": ["rogue"], "dye": Color(0.15, 0.72, 0.38), "mix": 0.82, "polish": 0.6, "shimmer": 0.5, "gold": 28000},
	# Season pass outfits fit every hero.
	"embergilt": {"name": "Embergilt", "heroes": HERO_ORDER, "dye": Color(0.95, 0.55, 0.18), "mix": 0.85, "polish": 0.9, "shimmer": 0.7, "gold": 0, "gift": true},
	"moonsilk": {"name": "Moonsilk", "heroes": HERO_ORDER, "dye": Color(0.72, 0.8, 1.0), "mix": 0.85, "polish": 0.9, "shimmer": 0.7, "gold": 0, "gift": true},
	"verdigris": {"name": "Verdigris", "heroes": HERO_ORDER, "dye": Color(0.2, 0.78, 0.62), "mix": 0.85, "polish": 0.9, "shimmer": 0.7, "gold": 0, "gift": true},
}
const OUTFIT_ORDER := ["crimson", "gilded", "frostwood", "emberstalker", "ashen", "sunfire", "bloodmoon", "glacier", "midnight", "viper", "embergilt", "moonsilk", "verdigris"]
## The season pass's outfit, one a season in turn.
const SEASON_OUTFITS := ["embergilt", "moonsilk", "verdigris"]
## The pass pays it at this tier.
const SEASON_OUTFIT_TIER := 25

# --- Online ---------------------------------------------------------------------

## What one hunt deals to the clan raid boss: per kill, elite, boss and win,
## then +per_tier for each difficulty step. A won Normal hunt is about 9,000;
## the boss has 30,000 per clan member (server/nakama/modules/gl_rewards.lua),
## so it falls when about half the clan plays a few hunts in its week.
const RAID_HIT := {"kill": 25, "elite": 250, "boss": 2500, "win": 2500, "per_tier": 0.25}
## A party partner fights at this share of their hero's damage (they are
## fighting their own horde too), and a party hunt pays this much more gold.
const PARTNER_DMG := 0.6
const PARTY_GOLD := 0.2

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

# --- Hero mastery and rating ---------------------------------------------------

## Mastery points per hunt: kills/10 + 40 a win + 15 a tier step. Ranks pay out
## once and give a title shown under the hero's name.
const MASTERY := [
	{"at": 0, "title": "Recruit"},
	{"at": 300, "title": "Blooded", "gold": 150},
	{"at": 900, "title": "Veteran", "gold": 300, "shards": 20},
	{"at": 2000, "title": "Champion", "gold": 600, "shards": 40, "glow": "bloodmoon"},
	{"at": 4000, "title": "Warlord", "gold": 1250, "shards": 80},
	{"at": 7500, "title": "Master", "gold": 2500, "shards": 140, "glow": "wraith"},
	{"at": 13000, "title": "Grandmaster", "gold": 4500, "shards": 220},
	{"at": 21000, "title": "Legend", "gold": 7500, "shards": 320, "glow": "sunsteel"},
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
const IDLE_GOLD_TIER := 10
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
## Wins on a difficulty before the next one opens (the first still pays the first-clear trophies).
const TIER_WINS := 3
const SEASON_TIERS := 30
const SEASON_XP := 400
const SEASON_NAMES := ["Season of Bones", "Season of the Hex", "Season of Ash", "Season of the Grove"]

static func season_reward(n: int, sid := 0) -> Dictionary:
	if n == SEASON_TIERS:
		return {"kind": "glow", "glow": "void"}
	if n == SEASON_OUTFIT_TIER:
		return {"kind": "outfit", "outfit": SEASON_OUTFITS[sid % SEASON_OUTFITS.size()]}
	if n == 28:
		return {"kind": "egg", "egg": "exotic"}
	if n == 10 or n == 20:
		return {"kind": "egg", "egg": "season"}
	if n == 5 or n == 15:
		return {"kind": "egg", "egg": "brood"}
	if n % 5 == 0:
		return {"kind": "chest", "chest": "gold" if n < 20 else "crypt"}
	if n % 3 == 0 and n % 2 == 1:
		return {"kind": "gems", "amount": 10 + n}
	if n % 2 == 0:
		return {"kind": "shards", "amount": 15 + n}
	return {"kind": "gold", "amount": 300 + 50 * n}

# --- Hero-defining legendaries ------------------------------------------------

## Rule-changing cards, one per hero, offered as legendaries from run level 6.
## (Defined in CARDS; listed here for the Log.)
const SIGNATURES := {"knight": "bulwark", "ranger": "ricochet", "mage": "pyre", "barbarian": "rampage", "rogue": "backstab"}
