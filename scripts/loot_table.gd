class_name LootTable
extends RefCounted

## Data-driven gear drop tables. Every piece is earned from a source: camps,
## elites, the biome boss, chests (by rarity) and the treasure goblin. Each
## source carries a drop chance and tier weights {iron, steel, rune}; a deeper
## biome index nudges the weights a little toward the higher tiers.
##
## Rolling picks the hero who receives the piece (usually the one in the run),
## a uniform slot on that hero, and prefers a piece the hero does not own yet.
## Duplicates are allowed once the rerolls run out (the count increments).

## source -> {chance, count: [min, max], weights: [iron, steel, rune]}
## Chests escalate with rarity: commons mostly iron, legendaries mostly rune.
const SOURCES := {
	"camp": {"chance": 0.06, "count": [1, 1], "weights": [85, 14, 1]},
	"elite": {"chance": 0.30, "count": [1, 1], "weights": [60, 35, 5]},
	"boss": {"chance": 1.0, "count": [1, 2], "weights": [35, 50, 15]},
	"goblin": {"chance": 1.0, "count": [1, 1], "weights": [20, 55, 25]},
	"chest_common": {"chance": 0.40, "count": [1, 1], "weights": [80, 18, 2]},
	"chest_rare": {"chance": 0.70, "count": [1, 1], "weights": [50, 42, 8]},
	"chest_epic": {"chance": 1.0, "count": [1, 2], "weights": [22, 55, 23]},
	"chest_legendary": {"chance": 1.0, "count": [1, 2], "weights": [8, 40, 52]},
}

## The hero in the run keeps its own drops this share of the time; the rest of
## the time any gear hero (uniform over GearDB.HERO_SLOTS) receives the piece.
const RUN_HERO_SHARE := 0.75
## Slot rerolls that try to hand the target hero a piece it does not own yet.
const OWNED_REROLLS := 3
## How far one biome of depth shifts weight from iron toward steel and rune.
const DEPTH_SHIFT := 0.04
const DEPTH_SHIFT_CAP := 0.15


## Roll a source into earned item ids. Empty when the source's chance misses.
## hero is the run's critter id (any hero is fine); biome_idx is the biome's
## position in Catalog.BIOMES (deeper = a little more steel/rune).
static func roll(rng: RandomNumberGenerator, source: String, hero: String, biome_idx := 0) -> Array[String]:
	var out: Array[String] = []
	var s: Dictionary = SOURCES.get(source, {})
	if s.is_empty():
		return out
	if rng.randf() >= float(s["chance"]):
		return out
	var weights := _weights(s["weights"], biome_idx)
	for _i in rng.randi_range(int(s["count"][0]), int(s["count"][1])):
		out.append(_pick(rng, hero, _tier(rng, weights)))
	return out


## Tier weights nudged by biome depth: a slice of the iron weight slides to
## steel and rune, capped so a shallow source never becomes a rune faucet.
static func _weights(base: Array, biome_idx: int) -> Array:
	var w := [float(base[0]), float(base[1]), float(base[2])]
	var shift := minf(DEPTH_SHIFT_CAP, DEPTH_SHIFT * float(maxi(0, biome_idx)))
	var move: float = float(w[0]) * shift
	w[0] = float(w[0]) - move
	w[1] = float(w[1]) + move * 0.65
	w[2] = float(w[2]) + move * 0.35
	return w


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
