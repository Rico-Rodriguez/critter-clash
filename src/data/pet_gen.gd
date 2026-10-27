extends RefCounted
## Pets 2.0 genetics, as plain data and pure functions (no sidekick_db.gd
## preload, so that file can preload this one): each handmade breed's colour
## variants, the part styles a species lends a child (head, wings, tail), and
## the rare mutations with their skins and powers. The rolls themselves are in
## sidekick_db.gd (roll_child, roll_wild); the look is built by
## core/pet_parts.gd from the same ids. Preload by path (no class_name).

## Per breed, four handmade colour variants: id, name, accent colour (the toon
## trim over the untouched model) and the stat it leans toward ("dmg", "haste",
## "reach" or "size"). A hatch picks one at random; a bred child may keep a
## parent's. A breed with no entry (a hybrid) uses VARIANTS_HYBRID.
const VARIANTS := {
	"wisp": [
		{"id": "moonlit", "name": "Moonlit", "color": "9fc4ff", "lean": "haste"},
		{"id": "marsh", "name": "Marshlight", "color": "7be08f", "lean": "reach"},
		{"id": "cinder", "name": "Cinder", "color": "ff9d4d", "lean": "dmg"},
		{"id": "orchid", "name": "Orchid", "color": "c58bff", "lean": "size"},
	],
	"drake": [
		{"id": "ash", "name": "Ashen", "color": "b9b4aa", "lean": "reach"},
		{"id": "crimson", "name": "Crimson", "color": "ff4a3a", "lean": "dmg"},
		{"id": "verdigris", "name": "Verdigris", "color": "4fd1a1", "lean": "haste"},
		{"id": "sunscale", "name": "Sunscale", "color": "ffc933", "lean": "size"},
	],
	"bonelet": [
		{"id": "ivory", "name": "Ivory", "color": "f3e9cf", "lean": "reach"},
		{"id": "gravemoss", "name": "Gravemoss", "color": "89c26a", "lean": "size"},
		{"id": "rustbone", "name": "Rustbone", "color": "d7773f", "lean": "dmg"},
		{"id": "nightbone", "name": "Nightbone", "color": "6f7bd1", "lean": "haste"},
	],
	"hexling": [
		{"id": "violet", "name": "Violet", "color": "b36bff", "lean": "dmg"},
		{"id": "plum", "name": "Plum", "color": "d95fa6", "lean": "size"},
		{"id": "teal", "name": "Tealcloak", "color": "37d4c8", "lean": "haste"},
		{"id": "ember", "name": "Emberhood", "color": "ff7a3a", "lean": "reach"},
	],
	"acolyte": [
		{"id": "fern", "name": "Fern", "color": "7cd45a", "lean": "reach"},
		{"id": "rose", "name": "Rosethorn", "color": "ee6f8f", "lean": "dmg"},
		{"id": "amber", "name": "Amber", "color": "f0b440", "lean": "size"},
		{"id": "frost", "name": "Frostbriar", "color": "8fe3ff", "lean": "haste"},
	],
	"crow": [
		{"id": "storm", "name": "Stormfeather", "color": "6fa8ff", "lean": "haste"},
		{"id": "ember", "name": "Emberwing", "color": "ff8a3d", "lean": "dmg"},
		{"id": "jade", "name": "Jadewing", "color": "46d6a0", "lean": "reach"},
		{"id": "rime", "name": "Rimecrow", "color": "d8f1ff", "lean": "size"},
	],
	"mimic": [
		{"id": "gold", "name": "Goldlid", "color": "ffd24a", "lean": "dmg"},
		{"id": "jade", "name": "Jadelid", "color": "52d6a0", "lean": "reach"},
		{"id": "ruby", "name": "Rubylid", "color": "f0476a", "lean": "haste"},
		{"id": "iron", "name": "Ironbound", "color": "a8b3c2", "lean": "size"},
	],
	"bat": [
		{"id": "crimson", "name": "Crimson", "color": "ff4565", "lean": "dmg"},
		{"id": "dusk", "name": "Duskwing", "color": "9a6bff", "lean": "haste"},
		{"id": "cave", "name": "Cavepale", "color": "e6e0cf", "lean": "reach"},
		{"id": "toxic", "name": "Toxic", "color": "9be83c", "lean": "size"},
	],
	"barrow_squire": [
		{"id": "royal", "name": "Royal", "color": "ffd25a", "lean": "dmg"},
		{"id": "verdant", "name": "Verdant", "color": "6ccf6a", "lean": "reach"},
		{"id": "ashen", "name": "Ashen", "color": "b4b8c4", "lean": "size"},
		{"id": "blood", "name": "Bloodsworn", "color": "e0485a", "lean": "haste"},
	],
	"shade": [
		{"id": "dusk", "name": "Dusk", "color": "8f7bff", "lean": "haste"},
		{"id": "ink", "name": "Inkwell", "color": "5a6bd6", "lean": "dmg"},
		{"id": "ghostlight", "name": "Ghostlight", "color": "9ff0e4", "lean": "reach"},
		{"id": "ember", "name": "Emberveil", "color": "ff7d4d", "lean": "size"},
	],
	"sapling": [
		{"id": "oak", "name": "Oakheart", "color": "9be04a", "lean": "size"},
		{"id": "birch", "name": "Birchbark", "color": "f1ecd6", "lean": "haste"},
		{"id": "autumn", "name": "Autumn", "color": "ff9a3a", "lean": "dmg"},
		{"id": "willow", "name": "Willow", "color": "5fd6b0", "lean": "reach"},
	],
}
const VARIANTS_HYBRID := [
	{"id": "bright", "name": "Bright", "color": "ffe08a", "lean": "haste"},
	{"id": "deep", "name": "Deep", "color": "7a8cff", "lean": "dmg"},
	{"id": "wild", "name": "Wild", "color": "7fe07a", "lean": "reach"},
	{"id": "grand", "name": "Grand", "color": "ff8fb0", "lean": "size"},
]
## How far a variant leans its stat.
const LEAN := 1.08

## Where a species' parts hang, in metres at its roster scale (read off the
## ortho silhouettes with tools/dev/pet_frames.py). Each anchor is [y, z] (the
## wings' is [y, x] for the wing root); crown is the top of the head, u the
## size unit parts are built in. The model faces +Z.
const FRAMES := {
	"acolyte": {"head": [0.95, 0.14], "wings": [0.62, 0.22], "tail": [0.35, -0.2], "crown": 0.98, "u": 1.0, "hs": 0.8},
	"barrow_squire": {"head": [0.98, 0.0], "wings": [0.62, 0.18], "tail": [0.4, -0.22], "crown": 1.0, "u": 1.0, "hs": 0.8},
	"bat": {"head": [0.78, 0.0], "wings": [0.5, 0.2], "tail": [0.25, -0.1], "crown": 0.84, "u": 0.8, "hs": 0.6},
	"bonelet": {"head": [0.95, 0.0], "wings": [0.65, 0.2], "tail": [0.4, -0.15], "crown": 0.98, "u": 1.0, "hs": 0.65},
	"crow": {"head": [1.08, 0.46], "wings": [0.8, 0.3], "tail": [0.6, -1.0], "crown": 1.08, "u": 1.0, "hs": 0.9},
	"drake": {"head": [0.42, 0.85], "wings": [0.5, 0.3], "tail": [0.3, -0.3], "crown": 0.5, "u": 0.7, "hs": 0.6},
	"hexling": {"head": [0.9, 0.05], "wings": [0.6, 0.2], "tail": [0.3, -0.2], "crown": 0.95, "u": 1.0, "hs": 0.75},
	"mimic": {"head": [0.85, 0.1], "wings": [0.6, 0.45], "tail": [0.45, -0.35], "crown": 0.85, "u": 0.85, "hs": 1.0},
	"sapling": {"head": [0.9, 0.05], "wings": [0.6, 0.3], "tail": [0.3, -0.25], "crown": 0.97, "u": 1.0, "hs": 0.9},
	"shade": {"head": [0.95, 0.0], "wings": [0.6, 0.15], "tail": [0.25, -0.07], "crown": 1.0, "u": 1.0, "hs": 0.7},
	"wisp": {"head": [0.4, 0.6], "wings": [0.3, 0.5], "tail": [0.2, -0.6], "crown": 0.8, "u": 0.8, "hs": 0.8},
}

## What each species lends a child that takes its head, wings or tail: the
## toon style core/pet_parts.gd builds (the model's own PBR stays untouched).
const PART_STYLES := {
	"drake": {"head": "horns", "wings": "dragon", "tail": "spike"},
	"wisp": {"head": "tuft", "wings": "wisp", "tail": "flame"},
	"bonelet": {"head": "skull", "wings": "ribs", "tail": "bone"},
	"hexling": {"head": "hood", "wings": "cape", "tail": "plume"},
	"acolyte": {"head": "leaves", "wings": "cape", "tail": "vine"},
	"crow": {"head": "beak", "wings": "feather", "tail": "fan"},
	"mimic": {"head": "crown", "wings": "lid", "tail": "chain"},
	"bat": {"head": "ears", "wings": "bat", "tail": "whip"},
	"barrow_squire": {"head": "helm", "wings": "banner", "tail": "mace"},
	"shade": {"head": "hood", "wings": "wisp", "tail": "flame"},
	"sapling": {"head": "leaves", "wings": "leaf", "tail": "vine"},
}
const PART_NAMES := {
	"head": {"horns": "drake horns", "tuft": "flame tuft", "skull": "bone skull", "hood": "hex hood", "leaves": "leaf crown", "beak": "crow beak", "crown": "gold crown", "ears": "bat ears", "helm": "squire helm"},
	"wings": {"dragon": "dragon wings", "wisp": "wisp wings", "ribs": "rib wings", "cape": "hex cape", "feather": "feather wings", "lid": "chest lids", "bat": "bat wings", "banner": "banner wings", "leaf": "leaf wings"},
	"tail": {"spike": "spiked tail", "flame": "flame tail", "bone": "bone tail", "plume": "plume tail", "vine": "vine tail", "fan": "feather fan", "chain": "gold chain tail", "whip": "whip tail", "mace": "mace tail"},
}
const PART_SLOTS := ["head", "wings", "tail"]
## What each borrowed part adds to the child's numbers (per part).
const PART_LEAN := {"head": {"reach": 0.04}, "wings": {"haste": 0.04}, "tail": {"dmg": 0.04}}

## Rare mutations: a special skin (toon parts, see pet_parts.gd) and a power.
## dmg / haste / reach / size multiply the genes; `more` adds a target to
## whatever the ability chains, bounces, strikes or pulses; `fx` multiplies its
## burn, hold, stun or heal. `element` re-colours the ability.
const MUTATIONS := {
	"gilded": {"name": "Gilded", "color": "ffd24a", "skin": "gilded", "dmg": 1.2, "haste": 1.0, "reach": 1.0, "size": 1.05, "more": 1, "fx": 1.0,
		"power": "Golden plating: +20% damage and one more target."},
	"frostborn": {"name": "Frostborn", "color": "8fe3ff", "skin": "frostborn", "dmg": 1.0, "haste": 1.1, "reach": 1.0, "size": 1.0, "more": 0, "fx": 1.5, "element": "ice",
		"power": "Ice-cast: abilities freeze and hold 50% longer, and it casts 10% sooner."},
	"stormtouched": {"name": "Stormtouched", "color": "7f9bff", "skin": "stormtouched", "dmg": 1.0, "haste": 1.2, "reach": 1.1, "size": 1.0, "more": 1, "fx": 1.0, "element": "storm",
		"power": "Crackling: casts 20% sooner, reaches 10% farther and hits one more target."},
	"voidborn": {"name": "Voidborn", "color": "b36bff", "skin": "voidborn", "dmg": 1.3, "haste": 1.0, "reach": 1.15, "size": 1.0, "more": 0, "fx": 1.0, "element": "shadow",
		"power": "Void-fed: +30% damage and 15% more reach."},
	"emberheart": {"name": "Emberheart", "color": "ff7a2a", "skin": "emberheart", "dmg": 1.25, "haste": 1.0, "reach": 1.0, "size": 1.05, "more": 0, "fx": 1.5, "element": "fire",
		"power": "A burning core: +25% damage and burns 50% longer."},
	"verdant": {"name": "Verdant", "color": "6ee06a", "skin": "verdant", "dmg": 1.0, "haste": 1.0, "reach": 1.2, "size": 1.0, "more": 0, "fx": 2.0,
		"power": "Overgrown: heals and holds twice as hard, and reaches 20% farther."},
}
const MUTATION_ORDER := ["gilded", "frostborn", "stormtouched", "voidborn", "emberheart", "verdant"]
## A child of a mutated parent keeps its mutation this often.
const MUTATION_INHERIT := 0.25
## Ability numbers a mutation's `more` adds one to (the first the ability has).
const MORE_KEYS := ["chain", "bounces", "strikes", "pulses", "bites"]
## Ability numbers a mutation's `fx` scales.
const FX_KEYS := ["burn", "hold", "stun", "heal"]


## The variants a breed can wear.
static func variants(breed: String) -> Array:
	return VARIANTS.get(breed, VARIANTS_HYBRID)


## One variant's record ({} when the id is "" or unknown).
static func variant(breed: String, id: String) -> Dictionary:
	for v: Dictionary in variants(breed):
		if str(v["id"]) == id:
			return v
	return {}


## The lines a pet's card lists: its variant, borrowed parts and mutation.
static func describe(g: Dictionary, breed: String, body: String) -> Array:
	var out := []
	var v := variant(breed, str(g.get("variant", "")))
	if not v.is_empty():
		out.append("%s coat (leans to %s)" % [v["name"], str(v["lean"])])
	var parts: Dictionary = g.get("parts", {})
	for slot: String in PART_SLOTS:
		var donor := str(parts.get(slot, body))
		if donor != body and PART_STYLES.has(donor):
			out.append("%s from a %s (+%d%% %s)" % [str(PART_NAMES[slot][PART_STYLES[donor][slot]]).capitalize(), donor.replace("_", " "), int(round(float((PART_LEAN[slot] as Dictionary).values()[0]) * 100.0)), str((PART_LEAN[slot] as Dictionary).keys()[0])])
	var mu: Dictionary = MUTATIONS.get(str(g.get("mutation", "")), {})
	if not mu.is_empty():
		out.append("%s mutation: %s" % [mu["name"], mu["power"]])
	return out
