class_name Rarity
extends RefCounted

## Rarity tiers for gear drops. Separate from GearDB.Tier (material quality).
## Common < Uncommon < Rare < Epic < Legendary.
enum Tier { COMMON, UNCOMMON, RARE, EPIC, LEGENDARY }
const TIER_KEYS: Array[String] = ["common", "uncommon", "rare", "epic", "legendary"]
const TIER_NAMES: Array[String] = ["Common", "Uncommon", "Rare", "Epic", "Legendary"]
const TIER_COLORS: Array[Color] = [
	Color("b9a68a"),
	Color("8fb4e8"),
	Color("c46b8a"),
	Color("d45ad0"),
	Color("ff6a2a")
]

## Drop weights per biome depth (Catalog.BIOMES index).
## Legendaries only unlock at Deep (frost, idx 2) and Abyss (volcano, idx 3).
const DROP_WEIGHTS: Array = [
	[85, 14, 1, 0, 0],
	[70, 25, 5, 0, 0],
	[55, 30, 12, 3, 0],
	[40, 30, 20, 8, 2]
]

## Maximum rarity allowed per biome depth (index = Rarity.Tier).
const MAX_RARITY_BY_DEPTH: Array[int] = [1, 2, 4, 4]

## Difficulty tier (Catalog.Tier) adds weight shift toward higher rarities.
const DIFFICULTY_SHIFT: Array[float] = [0.0, 0.10, 0.20]

## Number of affixes per rarity tier (Rare+ only).
const AFFIX_COUNT: Array[int] = [0, 0, 1, 2, 3]

## Stat keys that are whole numbers rather than fractions. Mirrors
## GearDB.INT_STATS ("hp_flat", "armor", "magnet"). The list is copied here on
## purpose: GearDB needs this file for its rarity tiers and affix pool, so
## referring back to GearDB here would make the two classes depend on each
## other and Godot could not resolve the cycle.
const INT_STATS: Array[String] = ["hp_flat", "armor", "magnet"]

## Affix pool: {id, name, stat_key, base_value, is_percent, min_tier}.
## min_tier is Rarity.Tier (Rare=2, Epic=3, Legendary=4).
const AFFIX_POOL: Array[Dictionary] = [
	{"id": "strength", "name": "of Strength", "stat_key": "dmg_pct", "base_value": 0.04, "is_percent": true, "min_tier": 2},
	{"id": "vigor", "name": "of Vigor", "stat_key": "hp_flat", "base_value": 12, "is_percent": false, "min_tier": 2},
	{"id": "crit", "name": "of Precision", "stat_key": "crit", "base_value": 0.02, "is_percent": true, "min_tier": 2},
	{"id": "haste", "name": "of Swiftness", "stat_key": "haste", "base_value": 0.03, "is_percent": true, "min_tier": 2},
	{"id": "armor", "name": "of Warding", "stat_key": "armor", "base_value": 1, "is_percent": false, "min_tier": 2},
	{"id": "speed", "name": "of the Wind", "stat_key": "speed_pct", "base_value": 0.03, "is_percent": true, "min_tier": 2},
	{"id": "regen", "name": "of Renewal", "stat_key": "regen", "base_value": 0.5, "is_percent": false, "min_tier": 2},
	{"id": "gathering_speed", "name": "of the Forager", "stat_key": "gather_speed", "base_value": 0.1, "is_percent": true, "min_tier": 2},
	{"id": "gathering_yield", "name": "of the Hoarder", "stat_key": "gather_yield", "base_value": 0.1, "is_percent": true, "min_tier": 2},
	{"id": "crit_mult", "name": "of Cruelty", "stat_key": "crit_mult", "base_value": 0.1, "is_percent": true, "min_tier": 3},
	{"id": "siphon", "name": "of Leeching", "stat_key": "siphon", "base_value": 0.03, "is_percent": true, "min_tier": 3},
	{"id": "thorns", "name": "of Thorns", "stat_key": "thorns", "base_value": 0.1, "is_percent": true, "min_tier": 3},
	{"id": "execute", "name": "of Execution", "stat_key": "execute", "base_value": 0.15, "is_percent": true, "min_tier": 4},
	{"id": "magnet", "name": "of Attraction", "stat_key": "magnet", "base_value": 20, "is_percent": false, "min_tier": 3},
	{"id": "skill_xp", "name": "of Mastery", "stat_key": "skill_xp_pct", "base_value": 0.1, "is_percent": true, "min_tier": 3},
]


## Weighted rarity roll at a biome depth and difficulty tier.
static func roll(rng: RandomNumberGenerator, biome_idx: int, difficulty := 0) -> int:
	var idx := clampi(biome_idx, 0, DROP_WEIGHTS.size() - 1)
	var weights: Array[float] = []
	for w in DROP_WEIGHTS[idx]:
		weights.append(float(w))
	var shift := DIFFICULTY_SHIFT[clampi(difficulty, 0, DIFFICULTY_SHIFT.size() - 1)]
	if shift > 0.0:
		var move := weights[0] * shift
		weights[0] -= move
		weights[1] += move * 0.5
		weights[2] += move * 0.3
		weights[3] += move * 0.15
		weights[4] += move * 0.05
	var cap := MAX_RARITY_BY_DEPTH[idx]
	for i in range(cap + 1, weights.size()):
		weights[i] = 0.0
	var total := 0.0
	for w in weights:
		total += w
	if total <= 0.0:
		return Tier.COMMON
	var r := rng.randf() * total
	for i in range(weights.size()):
		r -= weights[i]
		if r <= 0.0:
			return i
	return Tier.COMMON


## Number of affixes for a rarity tier.
static func affix_count(rarity: int) -> int:
	return AFFIX_COUNT[clampi(rarity, 0, AFFIX_COUNT.size() - 1)]


## Roll random affixes for a rarity tier (Rare+).
## Returns array of {id, name, stat_key, value, is_percent}.
static func roll_affixes(rng: RandomNumberGenerator, rarity: int) -> Array[Dictionary]:
	var count := affix_count(rarity)
	if count <= 0:
		return []
	var pool: Array[Dictionary] = []
	for affix in AFFIX_POOL:
		if int(affix["min_tier"]) <= rarity:
			pool.append(affix)
	var out: Array[Dictionary] = []
	var available := pool.duplicate()
	for i in range(count):
		if available.is_empty():
			break
		var idx := rng.randi() % available.size()
		var picked: Dictionary = available[idx]
		available.remove_at(idx)
		var mul := 1.0
		if rarity == Tier.LEGENDARY:
			mul = 1.5
		elif rarity == Tier.EPIC:
			mul = 1.25
		var value := float(picked["base_value"]) * mul
		if bool(picked["is_percent"]):
			value = float(round(value * 100.0)) / 100.0
		else:
			value = float(int(round(value)))
		out.append({
			"id": picked["id"],
			"name": picked["name"],
			"stat_key": picked["stat_key"],
			"value": value,
			"is_percent": picked["is_percent"]
		})
	return out


## Apply affixes to a base stat dictionary (from GearDB.stats_for).
## int_stats lists the whole-number stat keys; it defaults to this file's
## INT_STATS so the caller does not have to know about them.
static func apply_affixes(base: Dictionary, affixes: Array[Dictionary], int_stats: Array = INT_STATS) -> Dictionary:
	var out: Dictionary = base.duplicate(true)
	for affix in affixes:
		var key := str(affix["stat_key"])
		var value := float(affix["value"])
		if key in int_stats:
			out[key] = out.get(key, 0) + int(round(value))
		else:
			out[key] = out.get(key, 0.0) + value
	return out


## Full item name with rarity prefix and affix suffixes.
static func format_name(base_name: String, rarity: int, affixes: Array[Dictionary]) -> String:
	var prefix := TIER_NAMES[clampi(rarity, 0, TIER_NAMES.size() - 1)]
	var name := "%s %s" % [prefix, base_name]
	if not affixes.is_empty():
		var suffixes: Array[String] = []
		for a in affixes:
			suffixes.append(str(a["name"]))
		name += " " + ", ".join(suffixes)
	return name


## Get color for a rarity tier.
static func color(rarity: int) -> Color:
	return TIER_COLORS[clampi(rarity, 0, TIER_COLORS.size() - 1)]