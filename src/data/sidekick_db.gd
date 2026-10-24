extends RefCounted
## Sidekicks: the one companion that walks (or flies) at your side, shared by
## every hero. Each has one ability whose damage is a share of the hero's, so
## it never outclasses the hero. Bond (1-10) grows from kills made with it.
## Preloaded by path (no class_name: see CLAUDE.md, OTA packs).

## Launch roster in sheet order. `model`: a KayKit Rig_Medium character
## ("kk:"), a KayKit prop ("prop:") or a Quaternius CC0 glb ("q:").
## `camp_scale`: extra size by the camp fire (the thin undead read small
## beside the hero; feet stay on the ground).
## `scale`: the KayKit model's scale, or for others its height in metres.
## `fly`: hover height (0 walks).
## `unlock`: how it is earned (see sidekicks.gd unlock rules).
## `ability`: kind (the code path in hunt/sidekick.gd), cd seconds, dmg (share
## of hero damage), plus kind-specific numbers.
const ROSTER := {
	"wisp": {
		"name": "Grave Wisp", "element": "Spirit", "icon": "ghost", "color": Color(0.6, 0.95, 0.85),
		"model": "sf:mawko", "fly": 1.2, "scale": 0.8,
		"unlock": {"kind": "boss_kills", "n": 1}, "how": "Free after your first boss kill",
		"origin": "Drifted out of the first grave you robbed of its king",
		"ability": {"kind": "mend", "name": "Mending Light", "cd": 6.0, "dmg": 0.3, "heal": 0.05, "radius": 3.0},
		"desc": "Every 6s it heals you for 5% of your health and pulses light at foes close by (30% of your damage).",
	},
	"drake": {
		"name": "Ember Drake", "element": "Fire", "icon": "dragon-head", "color": Color(1.0, 0.5, 0.15),
		"model": "sf:dragon", "evolved_model": "sf:dragon", "evolved_name": "Ash Wyrm", "evolved_look": "ash", "camp_offset": Vector3(0.1, -0.15, 1.1), "fly": 1.4, "scale": 0.8,
		"unlock": {"kind": "egg", "egg": "ember"}, "how": "Hatches from an Ember Egg that Gravemaw drops",
		"origin": "Hatched from an egg Gravemaw dropped",
		"ability": {"kind": "breath", "name": "Fire Breath", "cd": 5.0, "dmg": 0.6, "range": 5.0, "cone": 0.55, "burn": 3.0},
		"desc": "Every 5s it swoops to the thickest pack and breathes a cone of fire: 60% of your damage, and the ground burns for 3s.",
		"cards": ["drake_inferno", "drake_nova"],
	},
	"bonelet": {
		"name": "Bonelet", "element": "Bone", "icon": "skull-crossed-bones", "color": Color(0.92, 0.88, 0.78),
		"model": "sf:skeleton", "camp_scale": 1.7, "fly": 0.0, "scale": 1.0,
		"unlock": {"kind": "pet", "unique": "bonelet"}, "how": "Gravemaw's rare drop (1/50)",
		"origin": "A tiny skeleton that follows you everywhere",
		"ability": {"kind": "bone_toss", "name": "Bone Toss", "cd": 4.0, "dmg": 0.45, "bounces": 3},
		"desc": "Every 4s it hurls a bone that bounces between 3 foes, 45% of your damage each.",
		"cards": ["bonelet_rattle", "bonelet_pile"],
	},
	"hexling": {
		"name": "Hexling", "element": "Shadow", "icon": "magic-swirl", "color": Color(0.7, 0.45, 1.0),
		"model": "sf:lich", "camp_scale": 1.7, "fly": 0.3, "scale": 1.0,
		"unlock": {"kind": "pet", "unique": "hexling"}, "how": "The Hexer's rare drop (1/50)",
		"origin": "A tiny cultist with a tinier staff",
		"ability": {"kind": "hex", "name": "Hex", "cd": 6.0, "dmg": 0.35, "burst": 0.6, "delay": 1.5, "radius": 2.5},
		"desc": "Every 6s it hexes the toughest foe near you (35%); the hex bursts 1.5s later, 60% to everything around it.",
		"cards": ["hexling_curse", "hexling_doom"],
	},
	"acolyte": {
		"name": "Acolyte", "element": "Thorn", "icon": "thorny-vine", "color": Color(0.55, 0.85, 0.35),
		"model": "sf:plague", "camp_scale": 1.7, "fly": 0.0, "scale": 1.0,
		"unlock": {"kind": "pet", "unique": "acolyte"}, "how": "The Thornmother's rare drop (1/50)",
		"origin": "A very small cultist who means well",
		"ability": {"kind": "thorns", "name": "Thorn Ward", "cd": 7.0, "dmg": 0.5, "radius": 3.5, "push": 7.0},
		"desc": "Every 7s thorns burst around you: 50% of your damage and foes are thrown back.",
		"cards": ["acolyte_bramble", "acolyte_grove"],
	},
	"crow": {
		"name": "Storm Crow", "element": "Storm", "icon": "raven", "color": Color(0.55, 0.8, 1.0),
		"model": "sf:crow", "fly": 0.0, "scale": 1.0, "hunt_scale": 1.0, "fill": 3.4,
		"unlock": {"kind": "renown", "n": 4000}, "how": "Trophy Road: 4,000 trophies",
		"origin": "Rides the thunder that follows a champion",
		"ability": {"kind": "storm", "name": "Chain Lightning", "cd": 4.0, "dmg": 0.4, "chain": 4, "range": 7.0},
		"desc": "Every 4s lightning leaps between 4 foes, 40% of your damage each.",
		"cards": ["crow_tempest", "crow_thunder"],
	},
	"mimic": {
		"name": "Gilded Mimic", "element": "Gold", "icon": "open-treasure-chest", "color": Color(1.0, 0.82, 0.3),
		"model": "sf:mimic", "fly": 0.0, "scale": 1.0,
		"unlock": {"kind": "chests", "n": 100}, "how": "Open 100 chests",
		"origin": "It was the hundredth chest. It bit back.",
		"ability": {"kind": "snap", "name": "Gold Snap", "cd": 3.0, "dmg": 0.7, "gold": 2},
		"desc": "Every 3s it bites the nearest foe for 70% of your damage; its kills spill gold.",
		"cards": ["mimic_greed", "mimic_jaws"],
	},
	"bat": {
		"name": "Night Bat", "element": "Blood", "icon": "bat-wing", "color": Color(0.85, 0.3, 0.35),
		"model": "sf:bat", "fly": 1.5, "scale": 1.0, "hidden": true,
		"unlock": {"kind": "egg", "egg": "grove"}, "how": "Hatches from a Grove Egg",
		"origin": "Hatched from an egg found under the Hollow Grove",
		"ability": {"kind": "leech", "name": "Blood Dive", "cd": 4.0, "dmg": 0.3, "bites": 3, "heal": 0.01},
		"desc": "Every 4s it dives through 3 foes, 30% of your damage each, healing you 1% of your health per bite.",
		"cards": ["bat_frenzy", "bat_thirst"],
	},
	# The Ancient pets (Torment and up): one from each boss's Ancient form.
	"barrow_squire": {
		"name": "Barrow Squire", "element": "Iron", "icon": "checked-shield", "color": Color(1.0, 0.86, 0.5),
		"model": "sf:squire", "camp_scale": 1.7, "fly": 0.0, "scale": 1.0,
		"unlock": {"kind": "pet", "unique": "barrow_squire"}, "how": "Ancient Gravemaw's rare drop (1/60, Torment+)",
		"origin": "A small, very loyal skeleton knight from the first king's barrow",
		"ability": {"kind": "bash", "name": "Shield Bash", "cd": 6.0, "dmg": 0.55, "radius": 2.2, "stun": 0.8},
		"desc": "Every 6s it charges the nearest pack and slams its shield down: 55% of your damage, and foes are stunned for 0.8s.",
		"cards": ["squire_iron", "squire_drill"],
	},
	"shade": {
		"name": "Hexbound Shade", "element": "Shadow", "icon": "two-shadows", "color": Color(0.6, 0.5, 0.95),
		"model": "sf:wraith", "camp_scale": 1.7, "fly": 0.2, "scale": 1.0,
		"unlock": {"kind": "pet", "unique": "shade"}, "how": "The Ancient Hexer Queen's rare drop (1/60, Torment+)",
		"origin": "A quiet shade the Queen bound to her spindle",
		"ability": {"kind": "shadowstrike", "name": "Shadow Strike", "cd": 5.0, "dmg": 0.5, "strikes": 3},
		"desc": "Every 5s it steps from shadow to shadow behind the 3 toughest foes near you, 50% of your damage each (double on champions and bosses).",
		"cards": ["shade_veil", "shade_dusk"],
	},
	"sapling": {
		"name": "Thorn Sapling", "element": "Thorn", "icon": "lightning-tree", "color": Color(0.7, 1.0, 0.45),
		"model": "sf:treant", "fly": 0.0, "scale": 1.0,
		"unlock": {"kind": "pet", "unique": "sapling"}, "how": "The Ancient Thornmother's rare drop (1/60, Torment+)",
		"origin": "A tiny treant grown from Ancient heartwood",
		"ability": {"kind": "snare", "name": "Rootsnare", "cd": 7.0, "dmg": 0.35, "radius": 3.0, "pulses": 3, "hold": 1.2},
		"desc": "Every 7s roots burst under the thickest pack and hold it for 1.2s, then squeeze 3 times for 35% of your damage.",
		"cards": ["sapling_bloom", "sapling_deep"],
	},
}
## Which of each model's own clips plays for each state (see
## docs/review/sidekicks/clip_inventory.md). Keys: idle, move, run, attack,
## hit, special. A missing key falls back to a procedural move in
## hunt/sidekick.gd (lunge, hop-spin, recoil, bob), so a model never stalls.
const CLIPS := {
	"wisp": {"idle": "Idle", "move": "Walk"},
	"drake": {"idle": "Flying_Idle", "move": "Fast_Flying"},
	"bonelet": {"idle": "Idle", "move": "Walk"},
	"hexling": {"idle": "Idle", "move": "Walk"},
	"acolyte": {"idle": "Idle", "move": "Walk"},
	"crow": {"idle": "Idle", "move": "Fast_Flying"},
	"mimic": {"idle": "Idle", "move": "Walk", "attack": "Bite_Front"},
	"bat": {"idle": "Bat_Flying", "move": "Bat_Flying"},
	"barrow_squire": {"idle": "Idle", "move": "Walk", "run": "Run", "attack": "Punch"},
	"shade": {"idle": "Idle", "move": "Walk"},
	"sapling": {"idle": "Idle", "move": "Walk"},
}
## Abilities shown with the "special" animation (bigger, area or support
## moves); the rest use "attack".
const SPECIAL_KINDS := ["mend", "breath", "hex", "thorns", "snare"]

const ORDER := ["drake", "wisp", "bonelet", "hexling", "crow", "acolyte", "mimic", "bat", "barrow_squire", "shade", "sapling"]

## Eggs: found, then warmed by kills (any hero, any sidekick) until they hatch.
## `boss`: dropped by that boss; `zone`: by any won hunt in that zone.
## Chance per eligible win, guaranteed after `pity` dry wins.
const EGGS := {
	"ember": {"name": "Ember Egg", "hatches": "drake", "boss": "gravemaw", "chance": 0.125, "pity": 12, "kills": 500},
	"grove": {"name": "Grove Egg", "hatches": "bat", "zone": "grove", "chance": 0.1, "pity": 15, "kills": 500},
}

## Total kills with a sidekick at your side to reach bond level i+1.
const BOND_KILLS := [0, 200, 500, 1000, 2000, 3500, 5500, 8000, 11000, 15000]
const BOND_MAX := 10
## Bond rewards, the same rule for every sidekick (its ability names fill in).
const BOND_REACH := 3     # ability reach / radius +30%
const BOND_CARDS := 5     # its two cards join the level-up pool
const BOND_CHAMPIONS := 8 # aims at champions and bosses first
const BOND_EVOLVE := 10   # evolves: bigger, +50% damage
const REACH_MULT := 1.3
const EVOLVE_DMG := 1.5
const EVOLVE_SCALE := 1.25

## Pets from before sidekicks: the boss pets become these sidekicks.
const PET_TO_SIDEKICK := {"bonelet": "bonelet", "hexling": "hexling", "acolyte": "acolyte", "barrow_squire": "barrow_squire", "shade": "shade", "sapling": "sapling"}


static func bond_level(kills: int) -> int:
	var lv := 1
	for i in BOND_KILLS.size():
		if kills >= int(BOND_KILLS[i]):
			lv = i + 1
	return mini(lv, BOND_MAX)


## Kills needed for the next bond level (or the last threshold at max).
static func bond_next(kills: int) -> int:
	var lv := bond_level(kills)
	return int(BOND_KILLS[mini(lv, BOND_MAX - 1)])


static func bond_rewards(id: String) -> Array:
	var d: Dictionary = ROSTER[id]
	var ab: String = d["ability"]["name"]
	var out := [
		[BOND_REACH, "%s reaches 30%% farther" % ab],
		[BOND_CARDS, "%s cards join your level-up pool" % d["name"] if not d.has("cards") else "Its cards join your level-up pool (%s)" % ", ".join(PackedStringArray(d["cards"].map(func(c): return str(DB.CARDS[c]["name"]))))],
		[BOND_CHAMPIONS, "Picks off champions first"],
		[BOND_EVOLVE, "Evolves into the %s: bigger, +50%% damage" % d["evolved_name"] if d.has("evolved_name") else "Evolves: bigger, +50% damage"],
	]
	return out


static func display_name(id: String, kills: int) -> String:
	var d: Dictionary = ROSTER[id]
	if bond_level(kills) >= BOND_EVOLVE and d.has("evolved_name"):
		return str(d["evolved_name"])
	return str(d["name"])


## Sidekick cards live in DB.CARDS (key "sidekick"): they join the level-up
## pool once Bond 5 is reached with that sidekick at your side. "power": +30%
## ability damage per stack, "haste": the ability comes 20% more often.
const POWER_PER := 0.3
const HASTE_PER := 0.2


## Sidekicks earned by trophies, for the Trophy Road: [{id, t}] by trophies.
static func road_marks() -> Array:
	var out := []
	for id in ORDER:
		var u: Dictionary = ROSTER[id]["unlock"]
		if str(u["kind"]) == "renown":
			out.append({"id": id, "t": int(u["n"])})
	out.sort_custom(func(a, b): return int(a["t"]) < int(b["t"]))
	return out
