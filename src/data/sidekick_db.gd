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
# --- Breeding: breeds and the genome --------------------------------------

## Breeds that only come from a pair: the two parents (either order) have a
## BREED_HYBRID chance to hatch one of these instead of a parent's breed. Each
## wears its first parent's body and casts its first parent's kit, then
## echoes the second parent's ability at ECHO_DMG.
const BREEDS := {
	"cinderbone": {
		"name": "Cinderbone Drake", "element": "Fire · Bone", "icon": "dragon-head", "color": Color(1.0, 0.62, 0.3),
		"model": "sf:dragon", "fly": 1.4, "scale": 0.9, "camp_offset": Vector3(0.1, -0.15, 1.1),
		"pair": ["drake", "bonelet"], "unlock": {"kind": "bred"}, "how": "Breed an Ember Drake with a Bonelet",
		"origin": "A drake that swallowed a Bonelet's bones and kept them",
		"ability": {"kind": "breath", "name": "Bonefire Breath", "cd": 5.0, "dmg": 0.6, "range": 5.0, "cone": 0.55, "burn": 3.0},
		"echo": {"kind": "bone_toss", "name": "Bone Toss", "cd": 4.0, "dmg": 0.45, "bounces": 3},
		"desc": "Breathes a cone of fire, then hurls a burning bone that bounces between 3 foes.",
	},
	"hexstorm": {
		"name": "Hexstorm Raven", "element": "Storm · Shadow", "icon": "raven", "color": Color(0.55, 0.65, 1.0),
		"model": "sf:crow", "fly": 0.0, "scale": 1.1, "hunt_scale": 1.0, "fill": 3.4,
		"pair": ["crow", "hexling"], "unlock": {"kind": "bred"}, "how": "Breed a Storm Crow with a Hexling",
		"origin": "A storm crow that learned a hexling's curse",
		"ability": {"kind": "storm", "name": "Hexchain", "cd": 4.0, "dmg": 0.4, "chain": 4, "range": 7.0},
		"echo": {"kind": "hex", "name": "Hex", "cd": 6.0, "dmg": 0.35, "burst": 0.6, "delay": 1.5, "radius": 2.5},
		"desc": "Lightning leaps between 4 foes, then the toughest is hexed and bursts.",
	},
	"briarshade": {
		"name": "Briarshade", "element": "Shadow · Thorn", "icon": "two-shadows", "color": Color(0.55, 0.75, 0.6),
		"model": "sf:wraith", "camp_scale": 1.7, "fly": 0.2, "scale": 1.1,
		"pair": ["shade", "sapling"], "unlock": {"kind": "bred"}, "how": "Breed a Hexbound Shade with a Thorn Sapling",
		"origin": "A shade that took root in Ancient heartwood",
		"ability": {"kind": "shadowstrike", "name": "Briar Strike", "cd": 5.0, "dmg": 0.5, "strikes": 3},
		"echo": {"kind": "snare", "name": "Rootsnare", "cd": 7.0, "dmg": 0.35, "radius": 3.0, "pulses": 3, "hold": 1.2},
		"desc": "Strikes behind the 3 toughest foes, then roots burst under the pack.",
	},
}
const BREED_ORDER := ["cinderbone", "hexstorm", "briarshade"]
const BREED_HYBRID := 0.35
## Breeding: both parents at BREED_BOND, BREED_GOLD, then they rest BREED_REST s.
const BREED_BOND := 3
const BREED_GOLD := 1000
const BREED_REST := 8 * 3600
const ECHO_DMG := 0.6
## The genome's element: changes the ability's colour and its VFX element.
const ELEMENTS := {
	"fire": {"name": "Fire", "color": Color(1.0, 0.45, 0.15), "vfx": &"fire"},
	"ice": {"name": "Ice", "color": Color(0.45, 0.85, 1.0), "vfx": &"frost"},
	"storm": {"name": "Storm", "color": Color(0.5, 0.6, 1.0), "vfx": &"storm"},
	"shadow": {"name": "Shadow", "color": Color(0.7, 0.4, 1.0), "vfx": &"shadow"},
}
## Patterns are toon accents on the model (its own materials stay untouched).
const PATTERNS := ["plain", "spots", "stripes", "crest", "horns"]
## Personality: a name and a passive perk.
const PERSONALITIES := {
	"fierce": {"name": "Fierce", "perk": "+10% ability damage"},
	"swift": {"name": "Swift", "perk": "Casts 10% more often"},
	"keen": {"name": "Keen", "perk": "+15% reach"},
	"loyal": {"name": "Loyal", "perk": "+25% bond from hunts"},
	"lucky": {"name": "Lucky", "perk": "Doubles the exotic egg chance"},
	"eager": {"name": "Eager", "perk": "Its first cast comes at once"},
}
## Gene ranges: multipliers on the breed's numbers.
const GENE_RANGE := {"dmg": Vector2(0.85, 1.3), "haste": Vector2(0.85, 1.25), "reach": Vector2(0.85, 1.25), "size": Vector2(0.85, 1.25)}
## How far one generation drifts from its parents' average.
const MUTATE := 0.12
const GLOW_CHANCE := 0.06
const GLOW_INHERIT := 0.35
const ECHO_CHANCE := 0.15

## Offspring defs, built from their genome: {"x7": def}. Filled from the save
## by sidekicks.gd (sync) so every caller resolves an id with def().
static var BRED: Dictionary = {}


## Any sidekick by id: a base one, a pure breed, or a bred individual.
static func def(id: String) -> Dictionary:
	if ROSTER.has(id):
		return ROSTER[id]
	if BRED.has(id):
		return BRED[id]
	return BREEDS.get(id, {})


static func exists(id: String) -> bool:
	return not def(id).is_empty()


## The breed (species) behind an id: itself for base sidekicks.
static func species(id: String) -> String:
	return str(def(id).get("breed", id))


## The hybrid breed a pair can make, or "".
static func hybrid_for(a: String, b: String) -> String:
	for k in BREED_ORDER:
		var p: Array = BREEDS[k]["pair"]
		if (p[0] == a and p[1] == b) or (p[0] == b and p[1] == a):
			return k
	return ""


## A neutral genome (a base sidekick's, for inheritance).
static func base_genes() -> Dictionary:
	return {"dmg": 1.0, "haste": 1.0, "reach": 1.0, "size": 1.0, "element": "", "pattern": "plain", "accent": "", "glow": false, "personality": "", "echo": ""}


## Rolls a child: the breed (a parent's, or their hybrid) and a genome from
## both parents' genes plus mutation. Pure and seeded: the same parents and
## seed always give the same child.
static func roll_child(a: String, ga: Dictionary, b: String, gb: Dictionary, sd: int) -> Dictionary:
	var r := RandomNumberGenerator.new()
	r.seed = sd
	var sa := species(a)
	var sb := species(b)
	var hy := hybrid_for(sa, sb)
	var breed := sa if r.randf() < 0.5 else sb
	if hy != "" and r.randf() < BREED_HYBRID:
		breed = hy
	var g := base_genes()
	for k in GENE_RANGE:
		var rg: Vector2 = GENE_RANGE[k]
		var avg := (float(ga.get(k, 1.0)) + float(gb.get(k, 1.0))) * 0.5
		g[k] = snappedf(clampf(avg + r.randf_range(-MUTATE, MUTATE), rg.x, rg.y), 0.01)
	var els := ELEMENTS.keys()
	var roll := r.randf()
	var ea := str(ga.get("element", ""))
	var eb := str(gb.get("element", ""))
	if roll < 0.4 and ea != "":
		g["element"] = ea
	elif roll < 0.8 and eb != "":
		g["element"] = eb
	else:
		g["element"] = els[r.randi() % els.size()]
	g["pattern"] = PATTERNS[1 + r.randi() % (PATTERNS.size() - 1)] if r.randf() < 0.75 else "plain"
	g["accent"] = Color.from_hsv(r.randf(), r.randf_range(0.45, 0.8), r.randf_range(0.85, 1.0)).to_html(false)
	var glow_p := GLOW_INHERIT if bool(ga.get("glow", false)) or bool(gb.get("glow", false)) else GLOW_CHANCE
	g["glow"] = r.randf() < glow_p
	var ps := PERSONALITIES.keys()
	g["personality"] = ps[r.randi() % ps.size()]
	# Mixed attacks: sometimes a child echoes the other parent's ability.
	if not BREEDS.has(breed) and r.randf() < ECHO_CHANCE:
		var other := sb if breed == sa else sa
		if other != breed and ROSTER.has(other):
			g["echo"] = other
	return {"breed": breed, "genes": g}


## How rare a genome is, 0..4: Common, Rare, Epic, Legendary, Mythic.
static func grade(g: Dictionary) -> int:
	var score := 0.0
	for k in ["dmg", "haste", "reach"]:
		score += maxf(float(g.get(k, 1.0)) - 1.0, 0.0) * 4.0
	if bool(g.get("glow", false)):
		score += 1.2
	if str(g.get("echo", "")) != "":
		score += 1.0
	return clampi(int(score), 0, 4)


const GRADES := ["Common", "Rare", "Epic", "Legendary", "Mythic"]
const GRADE_COLORS := [Color(0.85, 0.85, 0.85), Color(0.35, 0.8, 1.0), Color(0.75, 0.4, 1.0), Color(1.0, 0.6, 0.15), Color(1.0, 0.3, 0.45)]


## A bred individual's def: its breed's, with the genome applied.
static func bred_def(breed: String, g: Dictionary) -> Dictionary:
	var base: Dictionary = (ROSTER[breed] if ROSTER.has(breed) else BREEDS[breed]).duplicate(true)
	base["breed"] = breed
	base["genes"] = g
	var per: Dictionary = PERSONALITIES.get(str(g.get("personality", "")), {})
	var el: Dictionary = ELEMENTS.get(str(g.get("element", "")), {})
	base["name"] = ("%s %s" % [per.get("name", ""), base["name"]]).strip_edges()
	base.erase("evolved_name")
	if not el.is_empty():
		base["color"] = el["color"]
		base["vfx_el"] = el["vfx"]
		base["element"] = el["name"]
	var ab: Dictionary = base["ability"]
	var dmg := float(g.get("dmg", 1.0)) * (1.1 if str(g.get("personality", "")) == "fierce" else 1.0)
	var haste := float(g.get("haste", 1.0)) * (1.1 if str(g.get("personality", "")) == "swift" else 1.0)
	ab["dmg"] = float(ab.get("dmg", 0.0)) * dmg
	if ab.has("burst"):
		ab["burst"] = float(ab["burst"]) * dmg
	ab["cd"] = float(ab["cd"]) / haste
	base["reach"] = float(g.get("reach", 1.0)) * (1.15 if str(g.get("personality", "")) == "keen" else 1.0)
	base["scale"] = float(base["scale"]) * float(g.get("size", 1.0))
	if str(g.get("echo", "")) != "" and ROSTER.has(str(g["echo"])):
		base["echo"] = (ROSTER[str(g["echo"])]["ability"] as Dictionary).duplicate(true)
	if base.has("echo"):
		var e: Dictionary = base["echo"]
		e["dmg"] = float(e.get("dmg", 0.0)) * dmg
	base["perk"] = str(g.get("personality", ""))
	return base


## Which of each model's own clips plays for each state (see
## docs/review/sidekicks/clip_inventory.md). Keys: idle, move, run, attack,
## hit, special. A missing key falls back to a procedural move in
## hunt/sidekick.gd (lunge, hop-spin, recoil, bob), so a model never stalls.
const CLIPS := {
	"wisp": {"idle": "Idle_Loop", "move": "Walk", "attack": "Attack", "hit": "Hit", "special": "Special"},
	"drake": {"idle": "Flying_Idle", "move": "Fast_Flying", "attack": "Attack", "hit": "Hit", "special": "Special"},
	"bonelet": {"idle": "Idle_Loop", "move": "Walk_Loop", "run": "Run", "attack": "Attack", "hit": "Hit", "special": "Special"},
	"hexling": {"idle": "Idle", "move": "Walk", "attack": "Attack", "hit": "Hit", "special": "Special"},
	"acolyte": {"idle": "Idle", "move": "Walk_Loop", "run": "Run", "attack": "Attack", "hit": "Hit", "special": "Special"},
	"crow": {"idle": "Idle", "move": "Fast_Flying", "attack": "Attack", "hit": "Hit", "special": "Special"},
	"mimic": {"idle": "Idle", "move": "Walk", "attack": "Bite_Front", "hit": "Hit", "special": "Special"},
	"bat": {"idle": "Hover", "move": "Bat_Flying", "attack": "Attack", "hit": "Hit", "special": "Special"},
	"barrow_squire": {"idle": "Idle", "move": "Walk", "run": "Run", "attack": "Punch", "hit": "Hit", "special": "Special"},
	"shade": {"idle": "Idle", "move": "Walk", "run": "Run", "attack": "Attack", "hit": "Hit", "special": "Special"},
	"sapling": {"idle": "Idle", "move": "Walk_Loop", "attack": "Attack", "hit": "Hit", "special": "Special"},
}
## Abilities shown with the "special" animation (bigger, area or support
## moves); the rest use "attack".
const SPECIAL_KINDS := ["mend", "breath", "hex", "thorns", "snare"]

const ORDER := ["drake", "wisp", "bonelet", "hexling", "crow", "acolyte", "mimic", "bat", "barrow_squire", "shade", "sapling"]

## Eggs. Each warms in the hatchery by real time ("secs") or by kills in
## hunts ("kills"), whichever comes first; gems finish one now. Species eggs
## ("hatches") drop from their boss or zone with a pity streak; the rest hatch
## a roll from "pool" ([id, weight]), preferring sidekicks you don't have yet.
## A sidekick you already own hatches as DUP_KILLS bond kills for it instead.
const EGGS := {
	"ember": {"name": "Ember Egg", "hatches": "drake", "boss": "gravemaw", "chance": 0.125, "pity": 12, "kills": 500, "secs": 8 * 3600, "rarity": "rare", "color": Color(1.0, 0.5, 0.2)},
	"grove": {"name": "Grove Egg", "hatches": "bat", "zone": "grove", "chance": 0.1, "pity": 15, "kills": 500, "secs": 8 * 3600, "rarity": "rare", "color": Color(0.45, 0.85, 0.4)},
	"brood": {"name": "Brood Egg", "kills": 300, "secs": 3 * 3600, "rarity": "common", "color": Color(0.92, 0.82, 0.62),
		"pool": [["wisp", 3], ["bonelet", 3], ["hexling", 3], ["acolyte", 2], ["crow", 2], ["mimic", 1], ["bat", 1], ["drake", 1]]},
	"season": {"name": "Season Egg", "kills": 400, "secs": 6 * 3600, "rarity": "epic", "color": Color(0.55, 0.75, 1.0),
		"pool": [["crow", 2], ["acolyte", 2], ["mimic", 2], ["bat", 2], ["drake", 2], ["barrow_squire", 1]]},
	"nest": {"name": "Nest Egg", "kills": 400, "secs": 4 * 3600, "rarity": "bred", "color": Color(0.95, 0.75, 0.85)},
	"exotic": {"name": "Exotic Egg", "kills": 800, "secs": 12 * 3600, "rarity": "exotic", "color": Color(1.0, 0.78, 0.3),
		"pool": [["drake", 2], ["bat", 2], ["mimic", 2], ["barrow_squire", 3], ["shade", 3], ["sapling", 3]]},
}
## The hatchery holds this many eggs; all of them warm at once.
const HATCH_SLOTS := 6
## A gem buys this many seconds of warming (rounded up, at least one gem).
const GEM_SECS := 900
const DUP_KILLS := 300
## Exotic wild drops in a hunt: per boss felled, per elite slain, and a
## guarantee after EXOTIC_PITY bosses without one (counted across hunts).
const EXOTIC_BOSS := 0.03
const EXOTIC_ELITE := 0.003
const EXOTIC_PITY := 40
## Chests: gems in each, and the chance of a Brood Egg.
const CHEST_GEMS := {"silver": 2, "gold": 6, "crypt": 15}
const CHEST_EGG := {"silver": 0.0, "gold": 0.15, "crypt": 0.4}

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

## Evolution stages, the same ladder for every sidekick: a small Hatchling,
## the Grown pet, and an Elder (its evolved form, with a crown).
const STAGE_BOND := [1, 4, BOND_EVOLVE]
const STAGE_LABELS := ["Hatchling", "Grown", "Elder"]
const STAGE_DMG := [0.9, 1.0, EVOLVE_DMG]
const STAGE_SCALE := [0.8, 1.0, EVOLVE_SCALE]
const STAGE_COOLDOWN := [1.0, 1.0, 0.85]
const STAGE_NOTES := ["Small and eager: 90% damage.", "Full size.", "Evolved: bigger, +50% damage, ability 15% sooner, and a crown."]

## Pets from before sidekicks: the boss pets become these sidekicks.
const PET_TO_SIDEKICK := {"bonelet": "bonelet", "hexling": "hexling", "acolyte": "acolyte", "barrow_squire": "barrow_squire", "shade": "shade", "sapling": "sapling"}


## 0 Hatchling, 1 Grown, 2 Elder.
static func stage_of(bond: int) -> int:
	var st := 0
	for i in STAGE_BOND.size():
		if bond >= int(STAGE_BOND[i]):
			st = i
	return st


static func stage_name(id: String, st: int) -> String:
	var d: Dictionary = def(id)
	match st:
		0:
			return "Young %s" % d["name"]
		2:
			return str(d["evolved_name"]) if d.has("evolved_name") else "Elder %s" % d["name"]
	return str(d["name"])


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
	var d: Dictionary = def(id)
	var ab: String = d["ability"]["name"]
	var out := [
		[BOND_REACH, "%s reaches 30%% farther" % ab],
		[STAGE_BOND[1], "Grows up to full size"],
		[BOND_CARDS, "%s cards join your level-up pool" % d["name"] if not d.has("cards") else "Its cards join your level-up pool (%s)" % ", ".join(PackedStringArray(d["cards"].map(func(c): return str(DB.CARDS[c]["name"]))))],
		[BOND_CHAMPIONS, "Picks off champions first"],
		[BOND_EVOLVE, "Evolves into the %s: bigger, +50%% damage" % d["evolved_name"] if d.has("evolved_name") else "Evolves: bigger, +50% damage"],
	]
	return out


static func display_name(id: String, kills: int) -> String:
	return stage_name(id, stage_of(bond_level(kills)))


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
