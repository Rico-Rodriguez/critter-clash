extends RefCounted
## The sixteen foes of the biome rebuild: eight for Rimehollow (frost) and eight
## for the Cinder Mire (swamp). Each def is a normal foe def (db.gd's keys) plus
## `brain`: a Dictionary naming the behaviour script that runs it (foe_brains.gd)
## and its tuning. `ai` still names the nearest stock kind so anything that only
## reads the stock keys (the bot, the director, stagger) keeps working.
##
## The models are KayKit skeletons in the zone skins until the Art bot's Quaternius
## and Blender models land. Swapping one is a def edit (`model` -> "glb:wolf" and
## an `anim` map of the new rig's clips, see foe_rig.gd); the brains only use the
## six `anim` keys, `radius`, `scale` and `fly`, never the skeleton.
##
## They are reached through the zones' `faction_next` (db.gd) while
## `FoeBrains.next` (on by default; `--old-foes` turns it off for a bot run).

const A_SK := {"idle": "Skeletons_Idle", "run": "Running_A", "attack": "Melee_1H_Attack_Chop", "spawn": "Skeletons_Awaken_Standing", "die": "Skeletons_Death", "hit": "Hit_B"}
const A_WALK := {"idle": "Skeletons_Idle", "run": "Skeletons_Walking", "attack": "Melee_1H_Attack_Slice_Diagonal", "spawn": "Skeletons_Awaken_Standing", "die": "Skeletons_Death", "hit": "Hit_A"}
const A_CAST := {"idle": "Skeletons_Idle", "run": "Skeletons_Walking", "attack": "Ranged_Magic_Spellcasting", "spawn": "Skeletons_Awaken_Standing", "die": "Skeletons_Death", "hit": "Hit_B"}
const A_SUMMON := {"idle": "Skeletons_Idle", "run": "Skeletons_Walking", "attack": "Ranged_Magic_Summon", "spawn": "Skeletons_Awaken_Standing", "die": "Skeletons_Death", "hit": "Hit_B"}
const A_SHOOT := {"idle": "Ranged_1H_Aiming", "run": "Running_A", "attack": "Ranged_1H_Shoot", "spawn": "Skeletons_Awaken_Standing", "die": "Skeletons_Death", "hit": "Hit_B"}
const A_HEAVY := {"idle": "Skeletons_Idle", "run": "Skeletons_Walking", "attack": "Melee_2H_Attack_Chop", "spawn": "Skeletons_Awaken_Standing", "die": "Skeletons_Death", "hit": "Hit_B"}

const FROST := ["rh_imp", "rh_effigy", "rh_wraith", "rh_seer", "rh_caller", "rh_wolf", "rh_yeti", "rh_shard"]
const SWAMP := ["cm_spore", "cm_bogfin", "cm_imp", "cm_shaman", "cm_hag", "cm_frog", "cm_bloat", "cm_wasp"]

const FOES := {
	# --- Rimehollow ---------------------------------------------------------
	"rh_imp": {
		"name": "Frost Imp", "model": "Skeleton_Minion", "weapons": {"handslot.r": "Skeleton_Blade.gltf"}, "skin": "rime", "base": "minion",
		"ai": "melee", "hp": 30.0, "dmg": 8.0, "speed": 4.2, "radius": 0.38, "reach": 1.2, "rider": "chill",
		"windup": 0.35, "cooldown": 1.0, "mass": 0.8, "xp": 1, "scale": 0.82, "anim": A_SK,
		"brain": {"kind": "skitter", "hop_at": 4.2, "hop_len": 3.4, "puddle": 0.9},
	},
	"rh_effigy": {
		"name": "Frozen Effigy", "model": "Skeleton_Warrior", "weapons": {"handslot.r": "Skeleton_Axe.gltf", "handslot.l": "Skeleton_Shield_Large_A.gltf"}, "skin": "rime", "base": "warrior",
		"ai": "melee", "hp": 170.0, "dmg": 22.0, "speed": 2.7, "radius": 0.62, "reach": 1.6, "rider": "chill",
		"windup": 0.55, "cooldown": 1.6, "mass": 4.0, "xp": 4, "scale": 1.18, "anim": A_WALK,
		"brain": {"kind": "dormant", "wake_r": 6.0, "wake_time": 0.9},
	},
	"rh_wraith": {
		"name": "Wail Wraith", "model": "Skeleton_Mage", "weapons": {}, "skin": "regent", "base": "rogue",
		"ai": "ranged", "hp": 48.0, "dmg": 13.0, "speed": 3.2, "radius": 0.45, "reach": 9.5, "rider": "chill", "proj": "frostbolt", "proj_speed": 11.0,
		"windup": 0.85, "cooldown": 2.6, "mass": 0.8, "xp": 3, "scale": 0.95, "fly": true, "element": "frost", "anim": A_CAST,
		"brain": {"kind": "kite", "hover": 0.9, "keep": 7.0, "shots": 1},
	},
	"rh_seer": {
		"name": "Rime Seer", "model": "Skeleton_Mage", "weapons": {"handslot.r": "Skeleton_Staff.gltf"}, "skin": "rime", "base": "mage",
		"ai": "caster", "hp": 62.0, "dmg": 20.0, "speed": 2.7, "radius": 0.45, "reach": 9.0, "blast": 2.2, "element": "frost", "leave": "frost",
		"windup": 1.2, "cooldown": 4.2, "mass": 1.2, "xp": 3, "scale": 1.0, "anim": A_CAST,
		"brain": {"kind": "caster", "spell": "thin", "keep": 7.5, "r": 2.2},
	},
	"rh_caller": {
		"name": "Winter Caller", "model": "Skeleton_Mage", "weapons": {"handslot.r": "Skeleton_Staff.gltf"}, "skin": "rime", "base": "necro",
		"ai": "necro", "hp": 100.0, "dmg": 0.0, "speed": 2.6, "radius": 0.5, "reach": 9.0, "blast": 2.0,
		"windup": 1.3, "cooldown": 7.5, "mass": 1.5, "xp": 5, "scale": 1.2, "element": "frost", "anim": A_SUMMON,
		"brain": {"kind": "caster", "spell": "summon", "keep": 8.0, "minion": "rh_imp", "count": 2, "cap": 6},
	},
	"rh_wolf": {
		"name": "Frost Wolf", "model": "Skeleton_Rogue", "weapons": {"handslot.r": "Skeleton_Blade.gltf"}, "skin": "rime", "base": "hound",
		"ai": "charge", "hp": 56.0, "dmg": 15.0, "speed": 4.3, "radius": 0.45, "reach": 1.4, "rider": "chill", "trail": "frost",
		"windup": 0.65, "cooldown": 2.4, "mass": 1.0, "xp": 2, "scale": 0.9, "anim": A_SK,
		"brain": {"kind": "pack", "circle": 5.5, "lunge_len": 8.0, "gap": 0.9},
	},
	"rh_yeti": {
		"name": "Rime Yeti", "model": "Skeleton_Warrior", "weapons": {"handslot.r": "axe_2handed.gltf"}, "skin": "rime", "base": "brute",
		"ai": "slam", "hp": 560.0, "dmg": 34.0, "speed": 2.3, "radius": 0.9, "reach": 2.9, "rider": "chill", "leave": "frost", "death": "shatter", "element": "frost",
		"windup": 1.05, "cooldown": 3.2, "mass": 6.5, "xp": 9, "scale": 1.7, "blast": 3.4, "anim": A_HEAVY,
		"brain": {"kind": "yeti", "lob_min": 5.5, "lob_max": 11.0, "lob_r": 1.9, "lob_every": 4.5, "crack_r": 3.4},
	},
	"rh_shard": {
		"name": "Crystal Shardling", "model": "Skeleton_Minion", "weapons": {"handslot.r": "res://assets/kaykit/dungeon/barrel_small.gltf"}, "skin": "regent", "base": "bomber",
		"ai": "bomb", "hp": 26.0, "dmg": 30.0, "speed": 3.6, "radius": 0.4, "reach": 1.9,
		"windup": 0.8, "cooldown": 9.0, "mass": 0.6, "xp": 2, "scale": 0.8, "blast": 2.6, "fly": true, "element": "frost", "anim": A_SK,
		"brain": {"kind": "drift", "pop": "shards", "hover": 0.7, "shards": 6},
	},
	# --- Cinder Mire -----------------------------------------------------------
	"cm_spore": {
		"name": "Sporecap", "model": "Skeleton_Minion", "weapons": {}, "skin": "bog", "base": "minion",
		"ai": "bomb", "hp": 34.0, "dmg": 10.0, "speed": 2.5, "radius": 0.42, "reach": 1.6,
		"windup": 0.7, "cooldown": 9.0, "mass": 0.9, "xp": 1, "scale": 0.95, "blast": 1.8, "element": "nature", "anim": A_SK,
		"brain": {"kind": "drift", "pop": "spores", "rot_r": 2.2},
	},
	"cm_bogfin": {
		"name": "Bogfin", "model": "Skeleton_Warrior", "weapons": {"handslot.r": "Skeleton_Blade.gltf"}, "skin": "bog", "base": "warrior",
		"ai": "melee", "hp": 130.0, "dmg": 19.0, "speed": 3.0, "radius": 0.55, "reach": 1.5,
		"windup": 0.55, "cooldown": 1.7, "mass": 3.0, "xp": 3, "scale": 1.05, "anim": A_WALK,
		"brain": {"kind": "ambush", "trigger": 3.6, "dive_after": 4.0},
	},
	"cm_imp": {
		"name": "Cinder Imp", "model": "Skeleton_Rogue", "weapons": {"handslot.r": "Skeleton_Crossbow.gltf"}, "skin": "cinder", "base": "rogue",
		"ai": "ranged", "hp": 44.0, "dmg": 13.0, "speed": 3.3, "radius": 0.42, "reach": 9.0, "rider": "scorch", "proj": "cinderbolt", "proj_speed": 12.0,
		"windup": 0.8, "cooldown": 2.3, "mass": 0.9, "xp": 2, "scale": 0.9, "element": "fire", "anim": A_SHOOT,
		"brain": {"kind": "kite", "keep": 7.5, "perch": true, "shots": 1},
	},
	"cm_shaman": {
		"name": "Pyre Shaman", "model": "Skeleton_Mage", "weapons": {"handslot.r": "Skeleton_Staff.gltf"}, "skin": "cinder", "base": "mage",
		"ai": "caster", "hp": 64.0, "dmg": 20.0, "speed": 2.7, "radius": 0.45, "reach": 9.0, "blast": 2.2, "element": "fire", "leave": "fire",
		"windup": 1.2, "cooldown": 4.4, "mass": 1.2, "xp": 3, "scale": 1.0, "anim": A_CAST,
		"brain": {"kind": "caster", "spell": "ignite", "keep": 7.5, "r": 2.2},
	},
	"cm_hag": {
		"name": "Mire Hag", "model": "Skeleton_Mage", "weapons": {"handslot.r": "Skeleton_Staff.gltf"}, "skin": "bog", "base": "necro",
		"ai": "necro", "hp": 96.0, "dmg": 18.0, "speed": 2.6, "radius": 0.5, "reach": 9.0, "blast": 2.4,
		"windup": 1.1, "cooldown": 6.0, "mass": 1.4, "xp": 5, "scale": 1.12, "element": "fire", "anim": A_SUMMON,
		"brain": {"kind": "caster", "spell": "lantern", "keep": 8.5, "r": 2.4, "fuse": 4.5, "cap": 3},
	},
	"cm_frog": {
		"name": "Bog Frog", "model": "Skeleton_Rogue", "weapons": {}, "skin": "bog", "base": "hound",
		"ai": "charge", "hp": 54.0, "dmg": 16.0, "speed": 3.8, "radius": 0.45, "reach": 1.4, "rider": "scorch",
		"windup": 0.6, "cooldown": 2.4, "mass": 1.0, "xp": 2, "scale": 0.85, "anim": A_SK,
		"brain": {"kind": "ambush", "leap": true, "trigger": 6.0, "dive_after": 3.0, "hop": 3.2},
	},
	"cm_bloat": {
		"name": "Methane Bloat", "model": "Skeleton_Minion", "weapons": {"handslot.r": "res://assets/kaykit/dungeon/barrel_small.gltf"}, "skin": "bog", "base": "bomber",
		"ai": "bomb", "hp": 26.0, "dmg": 34.0, "speed": 3.0, "radius": 0.5, "reach": 1.9, "death": "ignite",
		"windup": 0.85, "cooldown": 9.0, "mass": 0.6, "xp": 2, "scale": 1.2, "blast": 2.5, "fly": true, "element": "fire", "anim": A_SK,
		"brain": {"kind": "drift", "pop": "methane", "hover": 0.9, "ignite_r": 2.4},
	},
	"cm_wasp": {
		"name": "Ember Wasp", "model": "Skeleton_Rogue", "weapons": {}, "skin": "cinder", "base": "rogue",
		"ai": "charge", "hp": 38.0, "dmg": 12.0, "speed": 5.2, "radius": 0.38, "reach": 1.3, "rider": "scorch",
		"windup": 0.55, "cooldown": 2.0, "mass": 0.6, "xp": 2, "scale": 0.72, "fly": true, "element": "fire", "anim": A_SK,
		"brain": {"kind": "wasp", "hover": 1.4, "orbit": 5.5, "dive_len": 9.0, "spark_every": 0.35},
	},
}
