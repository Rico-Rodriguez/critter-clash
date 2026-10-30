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

## What each species lends a child that takes its head, wings or tail: the
## part's name on the card. On the pet it shows as the donor's colours over the
## body's own part (GRAFT below finds it) plus the donor's small trait
## (core/pet_parts.gd). A slot with no GRAFT entry is data and card text only
## (nothing is drawn for it).
const PART_STYLES := {
	"drake": {"head": "horns", "wings": "dragon", "tail": "spike"},
	"wisp": {"head": "maw", "wings": "fins", "tail": "flame"},
	"bonelet": {"head": "skull", "wings": "ribs", "tail": "bone"},
	"hexling": {"head": "eye", "wings": "cape", "tail": "plume"},
	"acolyte": {"head": "mask", "wings": "cape", "tail": "vine"},
	"crow": {"head": "beak", "wings": "feather", "tail": "fan"},
	"mimic": {"head": "fangs", "wings": "lid", "tail": "chain"},
	"bat": {"head": "ears", "wings": "bat", "tail": "whip"},
	"barrow_squire": {"head": "helm", "wings": "banner", "tail": "mace"},
	"shade": {"head": "veil", "wings": "wisp", "tail": "flame"},
	"sapling": {"head": "bark", "wings": "leaf", "tail": "vine"},
}
const PART_NAMES := {
	"head": {"horns": "horned dragon head", "maw": "mawko head", "skull": "bone skull", "eye": "cyclops head", "mask": "plague mask", "beak": "crow head", "fangs": "fanged chest lid", "ears": "bat head", "helm": "squire helm", "veil": "veiled head", "bark": "treant head"},
	"wings": {"dragon": "dragon wings", "fins": "mawko fins", "ribs": "rib wings", "cape": "hex cape", "feather": "feather wings", "lid": "chest lids", "bat": "bat wings", "banner": "banner wings", "wisp": "wisp wings", "leaf": "leaf wings"},
	"tail": {"spike": "dragon tail", "flame": "mawko tail", "bone": "bone tail", "plume": "plume tail", "vine": "vine tail", "fan": "crow tail", "chain": "gold chain tail", "whip": "whip tail", "mace": "mace tail"},
}

## Which turn (degrees about Y) makes a species' model face +Z; 0 when it does.
const GRAFT_YAW := {}

## Which of a donor's triangles are its head, wings or tail: `bones` (lower-case
## name fragments; a triangle belongs when most of its weight sits on them,
## minus `not`) or `meshes` (name fragments of rigid meshes), `pivot` the bone
## the part hangs from, `split` makes a left and a right piece, `own_colour` bones
## keep their colours when a child inherits the part (core/pet_graft.gd regions). Reviewed with
## tools/dev/graft_sheet.sh (every part, extracted, one PNG per species).
const GRAFT := {
	"drake": {
		"head": {"bones": ["head", "jaw"], "pivot": "neck_02"},
		"wings": {"bones": ["wing_"], "pivot": "spine_01", "split": true},
		"tail": {"bones": ["tail_"], "pivot": "tail_01"},
	},
	"wisp": {
		"head": {"bones": ["head", "jaw", "lure"], "pivot": "neck_01"},
		"wings": {"bones": ["fin_"], "pivot": "spine_01", "split": true},
		"tail": {"bones": ["tail_"], "pivot": "tail_01"},
	},
	"bonelet": {"head": {"bones": ["head"], "pivot": "chest"}},
	"hexling": {"head": {"bones": ["head"], "pivot": "chest"}},
	"acolyte": {"head": {"bones": ["face"], "pivot": "neck"}},
	"crow": {
		"head": {"bones": ["head", "jaw"], "pivot": "neck_01"},
		"wings": {"bones": ["wing_"], "pivot": "spine_01", "split": true},
		"tail": {"bones": ["tail_"], "pivot": "tail_01"},
	},
	"mimic": {
		"head": {"bones": ["lid"], "pivot": "hips"},
		"tail": {"bones": ["tail_"], "pivot": "tail_01"},
	},
	"bat": {
		"head": {"bones": ["head", "jaw", "ear_"], "pivot": "neck_01"},
		"wings": {"bones": ["wing_"], "pivot": "spine_01", "split": true},
	},
	"barrow_squire": {"head": {"bones": ["spine.006"], "pivot": "spine.005"}},
	"shade": {"head": {"bones": ["head_08", "bone.019", "hair"], "pivot": "neck_07"}},
	"sapling": {"head": {"bones": ["head", "jaw", "crown"], "own_colour": ["crown"], "pivot": "spine_01"}},
}

## Each part's own colour (sRGB hex), for a bred pet whose body inherited it:
## that region of the body is recoloured from its own colour to the donor's
## (core/pet_parts.gd tints, fx/pet_skin.gdshader). The commonest colour over
## the part's GRAFT region (tools/dev/region_colours.gd prints them), or the
## Blender pet's palette colour for that part where horns or eyes outweigh it.
const REGION_COLOR := {
	"drake": {"head": "b9472a", "wings": "8e2c22", "tail": "b9472a"},
	"wisp": {"head": "8e9096", "wings": "5cc9bb", "tail": "8e9096"},
	"crow": {"head": "1e2331", "wings": "121520", "tail": "1e2331"},
	"mimic": {"head": "7c4b2a", "tail": "e2aa3c"},
	"bat": {"head": "4a3036", "wings": "6e2a36"},
	"bonelet": {"head": "e5c9ad"},
	"hexling": {"head": "3a2f4a"},
	"acolyte": {"head": "4a4937"},
	"barrow_squire": {"head": "cdaf5a"},
	"shade": {"head": "2a2438"},
	"sapling": {"head": "6b4a2e"},
}

## Where a receiver hangs wings and a tail that its own model has no slot for
## (bone name fragments; "" = the body's bounds, for a model without a skeleton).
const MOUNT := {
	"drake": {"wings": "spine_01", "tail": "tail_01"},
	"wisp": {"wings": "spine_01", "tail": "tail_01"},
	"bonelet": {"wings": "chest", "tail": "hips"},
	"hexling": {"wings": "chest", "tail": "hips"},
	"acolyte": {"wings": "chest", "tail": "pelvis"},
	"crow": {"wings": "spine_01", "tail": "tail_01"},
	"mimic": {"wings": "hips", "tail": "tail_01"},
	"bat": {"wings": "spine_01", "tail": "tail_01"},
	"barrow_squire": {"wings": "spine.004", "tail": "hips_018"},
	"shade": {"wings": "spine2", "tail": "spine4"},
	"sapling": {"wings": "spine_01", "tail": "hips"},
}

## True when `donor` has a real `slot` part to lend (a GRAFT entry).
static func donates(donor: String, slot: String) -> bool:
	return (GRAFT.get(donor, {}) as Dictionary).has(slot)


## How many (slot, donor) parts exist to find.
static func donor_parts() -> int:
	var n := 0
	for sp: String in GRAFT:
		n += (GRAFT[sp] as Dictionary).size()
	return n


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
