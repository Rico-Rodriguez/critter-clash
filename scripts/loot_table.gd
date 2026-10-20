class_name LootTable
extends RefCounted

## Data-driven gear drop tables. Every piece is earned from a source: camps,
## elites, the biome boss, chests (by rarity) and the treasure goblin. Each
## source carries a drop chance and tier weights {iron, steel, rune}; a deeper
## biome index nudges the weights a little toward the higher tiers and raises
## the tier cap (MAX_TIER_BY_DEPTH) that limits what that source may drop.
##
## Rolling picks the hero who receives the piece (usually the one in the run),
## a uniform slot on that hero, and prefers a piece the hero does not own yet.
## Duplicates are allowed once the rerolls run out and convert to shards or
## coins at banking time (see save_game.gd).
##
## Rarity (Common..Legendary) is rolled first via Rarity.roll(), then a gear
## tier (Iron..Rune) is picked within the source's weights, and affixes are
## applied for Rare+ gear via Rarity.roll_affixes().
##
## The same file also holds the gathering drop tables (RESOURCE_TABLES): what
## a resource node pays out when it is worked (see docs/gathering.md).

## source -> {chance, count: [min, max], weights: [iron, steel, rune]}
## Chests escalate with rarity: commons mostly iron, legendaries mostly rune.
## The elite sources are per depth tier (fringe/wilds/deep/abyss): the deeper
## the ground, the more of an elite's gear is steel and rune. The plain
## "elite" source stays as the fallback.
const SOURCES := {
	"camp": {"chance": 0.06, "count": [1, 1], "weights": [85, 14, 1]},
	"elite": {"chance": 0.30, "count": [1, 1], "weights": [60, 35, 5]},
	"elite_fringe": {"chance": 0.30, "count": [1, 1], "weights": [65, 30, 5]},
	"elite_wilds": {"chance": 0.35, "count": [1, 1], "weights": [50, 40, 10]},
	"elite_deep": {"chance": 0.40, "count": [1, 2], "weights": [35, 45, 20]},
	"elite_abyss": {"chance": 0.50, "count": [1, 2], "weights": [20, 45, 35]},
	"boss": {"chance": 1.0, "count": [1, 2], "weights": [35, 50, 15]},
	"boss_boreal": {"chance": 1.0, "count": [1, 2], "weights": [15, 50, 35], "min_rarity": 2},
	"boss_inferno": {"chance": 1.0, "count": [1, 2], "weights": [10, 45, 45], "min_rarity": 2},
	"goblin": {"chance": 1.0, "count": [1, 1], "weights": [20, 55, 25]},
	"chest_common": {"chance": 0.40, "count": [1, 1], "weights": [80, 18, 2]},
	"chest_rare": {"chance": 0.70, "count": [1, 1], "weights": [50, 42, 8]},
	"chest_epic": {"chance": 1.0, "count": [1, 2], "weights": [22, 55, 23]},
	"chest_legendary": {"chance": 1.0, "count": [1, 2], "weights": [8, 40, 52]},
}

## The boss a source belongs to: a lair boss (Catalog.LAIRS) pays from its own
## source, a biome boss from the plain "boss" one.
const BOSS_SOURCES: Dictionary = {
	"boreal": "boss_boreal",
	"inferno": "boss_inferno",
}

## Highest GearDB.Tier a source may drop at each biome depth (index = the
## biome's position in Catalog.BIOMES). Shallow ground caps hard: meadow (idx 0)
## is iron only for every source, the boss included; mushroom (idx 1) adds steel
## but never rune. Rune unlocks at frost (idx 2) for the boss, the goblin and
## the rare-and-better chests first, then spreads to every source at volcano
## (idx 3), so it grows with depth. Values are GearDB.Tier (1..3).
const MAX_TIER_BY_DEPTH := {
	"camp": [1, 2, 2, 3],
	"elite": [1, 2, 2, 3],
	"elite_fringe": [1, 2, 2, 3],
	"elite_wilds": [1, 2, 2, 3],
	"elite_deep": [1, 2, 3, 3],
	"elite_abyss": [1, 2, 3, 3],
	"boss": [1, 2, 3, 3],
	"boss_boreal": [1, 2, 3, 3],
	"boss_inferno": [1, 2, 3, 3],
	"goblin": [1, 2, 3, 3],
	"chest_common": [1, 2, 2, 3],
	"chest_rare": [1, 2, 3, 3],
	"chest_epic": [1, 2, 3, 3],
	"chest_legendary": [1, 2, 3, 3],
}

## The hero in the run keeps its own drops this share of the time; the rest of
## the time any gear hero (uniform over GearDB.HERO_SLOTS) receives the piece.
const RUN_HERO_SHARE := 0.75
## Slot rerolls that try to hand the target hero a piece it does not own yet.
const OWNED_REROLLS := 3
## How far one biome of depth shifts weight from iron toward steel and rune.
const DEPTH_SHIFT := 0.04
const DEPTH_SHIFT_CAP := 0.15
## How far one difficulty tier shifts weight the same way, on top of depth.
## The biome cap still applies, so a raised tier cannot beat MAX_TIER_BY_DEPTH.
const TIER_SHIFT := 0.07
const SHIFT_CAP := 0.30

## Gathering drops, keyed by resource node id (GatheringDB.NODES). Each row is
## {id, weight, amount: [min, max]}: the material, how likely it is over the
## others and how many of it a gather takes. A node's table always has a row,
## so a gather always yields something; the lower-weight row is the rarer
## leftover of the tier below, so a better node also pays a little of the
## worse one.
const RESOURCE_TABLES := {
	# --- Woodcutting ---
	"willow": [{"id": "willow_logs", "weight": 100, "amount": [1, 2]}],
	"oak": [{"id": "oak_logs", "weight": 88, "amount": [1, 2]}, {"id": "willow_logs", "weight": 12, "amount": [1, 2]}],
	"sporewood": [{"id": "sporewood_logs", "weight": 88, "amount": [1, 2]}, {"id": "oak_logs", "weight": 12, "amount": [1, 2]}],
	"barrowwood": [{"id": "barrowwood_logs", "weight": 86, "amount": [1, 3]}, {"id": "sporewood_logs", "weight": 14, "amount": [1, 2]}],
	"frostpine": [{"id": "frostpine_logs", "weight": 86, "amount": [1, 3]}, {"id": "barrowwood_logs", "weight": 14, "amount": [1, 2]}],
	"glacierheart": [{"id": "glacierheart_logs", "weight": 84, "amount": [1, 3]}, {"id": "frostpine_logs", "weight": 16, "amount": [1, 2]}],
	"cinderwood": [{"id": "cinderwood_logs", "weight": 84, "amount": [1, 3]}, {"id": "glacierheart_logs", "weight": 16, "amount": [1, 2]}],
	"emberbark": [{"id": "emberbark_logs", "weight": 82, "amount": [1, 3]}, {"id": "cinderwood_logs", "weight": 18, "amount": [1, 2]}],
	# --- Fishing ---
	"brook": [{"id": "brook_fish", "weight": 100, "amount": [1, 1]}],
	"shallow_pool": [{"id": "pool_fish", "weight": 90, "amount": [1, 2]}, {"id": "brook_fish", "weight": 10, "amount": [1, 1]}],
	"spore_stream": [{"id": "spore_carp", "weight": 90, "amount": [1, 2]}, {"id": "pool_fish", "weight": 10, "amount": [1, 1]}],
	"underroot_pool": [{"id": "underroot_eel", "weight": 88, "amount": [1, 2]}, {"id": "spore_carp", "weight": 12, "amount": [1, 1]}],
	"glacier_lake": [{"id": "glacier_fish", "weight": 88, "amount": [1, 2]}, {"id": "underroot_eel", "weight": 12, "amount": [1, 1]}],
	"frostspring": [{"id": "frostspring_crab", "weight": 86, "amount": [1, 2]}, {"id": "glacier_fish", "weight": 14, "amount": [1, 1]}],
	"magma_vent": [{"id": "magma_fish", "weight": 86, "amount": [1, 2]}, {"id": "frostspring_crab", "weight": 14, "amount": [1, 1]}],
	"emberdeep": [{"id": "emberdeep_fish", "weight": 84, "amount": [1, 3]}, {"id": "magma_fish", "weight": 16, "amount": [1, 2]}],
	# --- Mining ---
	"copper_vein": [{"id": "copper_ore", "weight": 100, "amount": [1, 2]}],
	"tin_vein": [{"id": "tin_ore", "weight": 88, "amount": [1, 2]}, {"id": "copper_ore", "weight": 12, "amount": [1, 2]}],
	"iron_vein": [{"id": "iron_ore", "weight": 88, "amount": [1, 2]}, {"id": "tin_ore", "weight": 12, "amount": [1, 2]}],
	"coal_vein": [{"id": "coal", "weight": 86, "amount": [1, 3]}, {"id": "iron_ore", "weight": 14, "amount": [1, 2]}],
	"silver_vein": [{"id": "silver_ore", "weight": 86, "amount": [1, 2]}, {"id": "coal", "weight": 14, "amount": [1, 2]}],
	"gold_vein": [{"id": "gold_ore", "weight": 86, "amount": [1, 2]}, {"id": "silver_ore", "weight": 14, "amount": [1, 2]}],
	"cinderore": [{"id": "cinderore", "weight": 84, "amount": [1, 2]}, {"id": "gold_ore", "weight": 16, "amount": [1, 2]}],
	"runebound_seam": [{"id": "runebound_shard", "weight": 84, "amount": [1, 2]}, {"id": "cinderore", "weight": 16, "amount": [1, 2]}],

	# --- Depth Tiers: Fringe ---
	"fringe_oak": [{"id": "oak_logs", "weight": 88, "amount": [1, 2]}, {"id": "willow_logs", "weight": 12, "amount": [1, 2]}],
	"fringe_copper": [{"id": "copper_ore", "weight": 88, "amount": [1, 2]}, {"id": "tin_ore", "weight": 12, "amount": [1, 2]}],
	"fringe_shrimp": [{"id": "shrimp", "weight": 90, "amount": [1, 2]}, {"id": "brook_fish", "weight": 10, "amount": [1, 1]}],
	# --- Depth Tiers: Wilds ---
	"wilds_willow": [{"id": "willow_logs", "weight": 88, "amount": [1, 2]}, {"id": "oak_logs", "weight": 12, "amount": [1, 2]}],
	"wilds_iron": [{"id": "iron_ore", "weight": 88, "amount": [1, 2]}, {"id": "copper_ore", "weight": 12, "amount": [1, 2]}],
	"wilds_trout": [{"id": "trout", "weight": 90, "amount": [1, 2]}, {"id": "pool_fish", "weight": 10, "amount": [1, 1]}],
	# --- Depth Tiers: Deep ---
	"deep_yew": [{"id": "yew_logs", "weight": 86, "amount": [1, 3]}, {"id": "willow_logs", "weight": 14, "amount": [1, 2]}],
	"deep_mithril": [{"id": "mithril_ore", "weight": 86, "amount": [1, 3]}, {"id": "iron_ore", "weight": 14, "amount": [1, 2]}],
	"deep_salmon": [{"id": "salmon", "weight": 88, "amount": [1, 2]}, {"id": "trout", "weight": 12, "amount": [1, 1]}],
	# --- Depth Tiers: Abyss ---
	"abyss_magic": [{"id": "magic_logs", "weight": 84, "amount": [1, 3]}, {"id": "yew_logs", "weight": 16, "amount": [1, 2]}],
	"abyss_runite": [{"id": "runite_ore", "weight": 84, "amount": [1, 2]}, {"id": "mithril_ore", "weight": 16, "amount": [1, 2]}],
	"abyss_shark": [{"id": "shark", "weight": 84, "amount": [1, 3]}, {"id": "salmon", "weight": 16, "amount": [1, 2]}],
}


## Roll a source into earned item ids (backward compatible).
## Returns Array[String] of base item IDs "hero.slot.tier".
static func roll(rng: RandomNumberGenerator, source: String, hero: String, biome_idx := 0, difficulty := 0) -> Array[String]:
	var out: Array[String] = []
	var detailed := roll_detailed(rng, source, hero, biome_idx, difficulty)
	for entry in detailed:
		out.append(str(entry["id"]))
	return out


## Roll a source into detailed drop entries with rarity and affixes.
## Returns Array[Dictionary] with keys: id (String extended), rarity (int Rarity.Tier), affixes (Array[Dictionary]).
static func roll_detailed(rng: RandomNumberGenerator, source: String, hero: String, biome_idx := 0, difficulty := 0) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var s: Dictionary = SOURCES.get(source, {})
	if s.is_empty():
		return out
	if rng.randf() >= float(s["chance"]):
		return out
	var weights := _weights(s["weights"], biome_idx, source, difficulty)
	for _i in rng.randi_range(int(s["count"][0]), int(s["count"][1])):
		var tier: int = _tier(rng, weights)
		var rarity: int = _rarity_floor(Rarity.roll(rng, biome_idx, difficulty), s, biome_idx)
		var affixes: Array[Dictionary] = Rarity.roll_affixes(rng, rarity)
		var keys: Array = GearDB.HERO_SLOTS.keys()
		var h := hero if GearDB.HERO_SLOTS.has(hero) else ""
		if h == "" or rng.randf() >= RUN_HERO_SHARE:
			h = str(keys[rng.randi() % keys.size()])
		var slots: Array = GearDB.HERO_SLOTS[h]
		var slot := str(slots[rng.randi() % slots.size()])
		for _j in OWNED_REROLLS:
			if not GearDB.owns_any_variant(h, slot, tier):
				break
			slot = str(slots[rng.randi() % slots.size()])
		var ext_id := GearDB.item_id_ext(h, slot, tier, rarity, affixes)
		out.append({"id": ext_id, "rarity": rarity, "affixes": affixes})
	return out


## Tier weights for a source at a biome depth: the depth shift slides a slice of
## the iron weight toward steel and rune, then the biome's cap drops any weight
## above the source's highest allowed tier and spreads it over the tiers that
## remain. The weight total never changes, so a shallow source is never a rune
## faucet and a roll always lands on an allowed tier. A difficulty tier adds a
## further shift (still cap-bound), so Normal is unchanged.
static func _weights(base: Array, biome_idx: int, source := "", difficulty := 0) -> Array:
	var w := [float(base[0]), float(base[1]), float(base[2])]
	var shift := minf(DEPTH_SHIFT_CAP, DEPTH_SHIFT * float(maxi(0, biome_idx)))
	shift = minf(SHIFT_CAP, shift + TIER_SHIFT * float(maxi(0, difficulty)))
	var move: float = float(w[0]) * shift
	w[0] = float(w[0]) - move
	w[1] = float(w[1]) + move * 0.65
	w[2] = float(w[2]) + move * 0.35
	return _cap(w, biome_idx, source)


## The highest tier a source may drop at a biome depth (GearDB.Tier). A source
## with no cap row (a future source) stays uncapped.
static func max_tier(source: String, biome_idx: int) -> int:
	var caps: Array = MAX_TIER_BY_DEPTH.get(source, [])
	if caps.is_empty():
		return GearDB.Tier.RUNE
	return int(caps[clampi(biome_idx, 0, caps.size() - 1)])


## A source may promise a rarity floor ("min_rarity"): a lair boss never
## hands out common gear, so its floor is rare. The floor is capped by the
## biome's own rarity cap, so a shallow ground can never be talked into a
## legendary it has not earned.
static func _rarity_floor(rarity: int, s: Dictionary, biome_idx: int) -> int:
	var floor := int(s.get("min_rarity", 0))
	if floor <= rarity:
		return rarity
	var caps: Array = Rarity.MAX_RARITY_BY_DEPTH
	var cap := int(caps[clampi(biome_idx, 0, caps.size() - 1)])
	return maxi(rarity, mini(floor, cap))


## The elite source of a depth tier (the biome's index in Catalog.BIOMES):
## fringe, wilds, deep, abyss. Each one leans harder on the better gear than
## the last. An unknown index falls back to the plain elite source.
static func elite_source(biome_idx: int) -> String:
	match biome_idx:
		0:
			return "elite_fringe"
		1:
			return "elite_wilds"
		2:
			return "elite_deep"
		3:
			return "elite_abyss"
		_:
			return "elite"


## The loot source a boss pays from: a lair boss has its own source, a biome
## boss the plain "boss" one.
static func boss_source(boss_id: String) -> String:
	return str(BOSS_SOURCES.get(boss_id, "boss"))


## Zero the weight above a source's tier cap and renormalise: the removed weight
## is spread proportionally over the allowed tiers. If the cap allows no base
## weight at all, it falls back to certain on the cap tier.
static func _cap(w: Array, biome_idx: int, source: String) -> Array:
	var cap := max_tier(source, biome_idx)
	var out := [0.0, 0.0, 0.0]
	var spill := 0.0
	for i in 3:
		if i + 1 <= cap:
			out[i] = float(w[i])
		else:
			spill += float(w[i])
	if spill <= 0.0:
		return out
	var allowed := 0.0
	for v in out:
		allowed += float(v)
	if allowed <= 0.0:
		out[cap - 1] = 1.0
		return out
	for i in 3:
		out[i] = float(out[i]) * (1.0 + spill / allowed)
	return out


## One weighted tier pick, returned as a GearDB.Tier (IRON..RUNE).
static func _tier(rng: RandomNumberGenerator, weights: Array) -> int:
	var total := 0.0
	for v in weights:
		total += float(v)
	if total <= 0.0:
		return GearDB.Tier.IRON
	var r := rng.randf() * total
	for i in weights.size():
		r -= float(weights[i])
		if r <= 0.0:
			return i + 1
	return GearDB.Tier.RUNE


## A hero (usually the runner), a uniform slot on that hero, and an item the
## hero does not own yet where the rerolls can find one.
static func _pick(rng: RandomNumberGenerator, hero: String, tier: int) -> String:
	var keys: Array = GearDB.HERO_SLOTS.keys()
	var h := hero if GearDB.HERO_SLOTS.has(hero) else ""
	if h == "" or rng.randf() >= RUN_HERO_SHARE:
		h = str(keys[rng.randi() % keys.size()])
	var slots: Array = GearDB.HERO_SLOTS[h]
	var slot := str(slots[rng.randi() % slots.size()])
	for _i in OWNED_REROLLS:
		var id := GearDB.item_id(h, slot, tier)
		if not GearDB.has(h, id):
			return id
		slot = str(slots[rng.randi() % slots.size()])
	return GearDB.item_id(h, slot, tier)


## Returns the biome-specific elite source key for a biome index.
## Fringe (0) -> elite_fringe, Wilds (1) -> elite_wilds, Deep (2) -> elite_deep, Abyss (3) -> elite_abyss.
## Falls back to base "elite" for unknown indices.
static func elite_source(biome_idx: int) -> String:
	match biome_idx:
		0:
			return "elite_fringe"
		1:
			return "elite_wilds"
		2:
			return "elite_deep"
		3:
			return "elite_abyss"
		_:
			return "elite"


# --- Gathering resources -----------------------------------------------------

## The drop table of a resource node, or [] for a node without one.
static func resource_table(node_id: String) -> Array:
	return RESOURCE_TABLES.get(node_id, [])


## Rolls a resource node's table into the materials it pays: [{id, amount}].
## One row wins by weight and its amount is rolled inside the row's span, so
## a gather always yields one material. An unknown node pays nothing.
static func roll_resource(rng: RandomNumberGenerator, node_id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var rows: Array = resource_table(node_id)
	if rows.is_empty():
		return out
	var total := 0.0
	for row in rows:
		total += float(row["weight"])
	if total <= 0.0:
		return out
	var r := rng.randf() * total
	var picked: Dictionary = rows[rows.size() - 1]
	for row in rows:
		r -= float(row["weight"])
		if r <= 0.0:
			picked = row
			break
	var span: Array = picked["amount"]
	out.append({"id": str(picked["id"]), "amount": rng.randi_range(int(span[0]), int(span[1]))})
	return out
