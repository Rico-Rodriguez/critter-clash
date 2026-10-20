class_name WorldData
extends RefCounted

## One biome: a safe Hub at the south, four wilderness depth tiers
## stretching north to the boss lair. Depth increases with distance
## from the Hub; deeper tiers gate better loot and harder monsters.

const HUB: Dictionary = {
	"id": "hub",
	"name": "Barrow Haven",
	"spawn": Vector2(0, 0),
	"shops": ["general_store", "material_buyer"],
	"no_combat": true,
	"services": ["stash", "forge", "slayer_master", "trophy_board"],
	"ambient": "safe",
}

const TIERS: Array = [
	{
		"id": "fringe",
		"name": "The Fringe",
		"depth": 0,
		"monster_level_min": 1,
		"monster_level_max": 10,
		"loot_tier": 0,
		"gathering_nodes": ["copper_vein", "ash_log", "minnow_pool"],
		"elite_chance": 0.05,
		"danger": {
			"aggro_radius_mul": 0.8,
			"pack_size_mul": 0.7,
			"patrol_density": 0.3,
			"environmental_hazard": false,
		},
		"recommended_combat": 5,
		"description": "The treeline. Rot badgers and barrow beetles skulk at the edge of the light.",
	},
	{
		"id": "wilds",
		"name": "The Wilds",
		"depth": 1,
		"monster_level_min": 11,
		"monster_level_max": 25,
		"loot_tier": 1,
		"gathering_nodes": ["tin_vein", "oak_log", "trout_pool", "blight_cap"],
		"elite_chance": 0.15,
		"danger": {
			"aggro_radius_mul": 1.0,
			"pack_size_mul": 1.0,
			"patrol_density": 0.6,
			"environmental_hazard": false,
		},
		"recommended_combat": 18,
		"description": "Deeper gloom. Blight skitterers and moths hunt in packs; the trails grow narrow.",
	},
	{
		"id": "deep",
		"name": "The Deep",
		"depth": 2,
		"monster_level_min": 26,
		"monster_level_max": 45,
		"loot_tier": 2,
		"gathering_nodes": ["iron_vein", "willow_log", "salmon_pool", "glowmoth_nest", "rime_vein"],
		"elite_chance": 0.30,
		"danger": {
			"aggro_radius_mul": 1.25,
			"pack_size_mul": 1.3,
			"patrol_density": 1.0,
			"environmental_hazard": true,
			"hazard_type": "blight_fog",
			"hazard_interval": 45.0,
			"hazard_damage_per_tick": 8,
		},
		"recommended_combat": 35,
		"description": "The old barrows. Rime stalkers and blight trolls guard the ways; fog seeps from the ground.",
	},
	{
		"id": "abyss",
		"name": "The Abyss",
		"depth": 3,
		"monster_level_min": 46,
		"monster_level_max": 70,
		"loot_tier": 3,
		"gathering_nodes": ["coal_vein", "maple_log", "shark_pool", "ashbat_roost", "cinder_vein", "magma_bloom"],
		"elite_chance": 0.30,
		"danger": {
			"aggro_radius_mul": 1.5,
			"pack_size_mul": 1.6,
			"patrol_density": 1.4,
			"environmental_hazard": true,
			"hazard_type": "ash_fall",
			"hazard_interval": 30.0,
			"hazard_damage_per_tick": 15,
		},
		"recommended_combat": 58,
		"description": "The lair approaches. Ashwyrms and magma behemoths rule; the air itself burns.",
	},
]

const BIOME: Dictionary = {
	"id": "barrow",
	"name": "The Barrow Lands",
	"hub": "hub",
	"tier_order": ["fringe", "wilds", "deep", "abyss"],
	"boss": "gravemaw",
	"gate": 0,
	"need": "",
	"recommended_level": 3,
	"hp_mul": 1.0,
	"dmg_mul": 1.0,
	"boss_mul": 1.0,
	"skins": ["sprout", "beetle", "moth", "boarlet", "capling", "spore", "glowmoth", "puddle", "snowpup", "shard", "icewisp", "yeti", "cindling", "skink", "ashbat", "magmash"],
	"blurb": "Grey grass over old barrows. Four depths of wilds guard the lair below.",
	"world_cols": 4,
	"world_rows": 7,
	"cell_size": Vector2(1120, 1280),
}

## The gates of the hub: one per biome, each a door that leads out to that
## biome's Fringe tier. The first biome's gate stands open; the rest are
## sealed until the player unlocks them (the unlock is kept in the save,
## see SaveGame.gate_open). 'frost' and 'ember' are placeholders for biomes
## that do not exist yet.
const GATES: Array = [
	{
		"id": "barrow_gate",
		"biome": "barrow",
		"name": "Barrow Gate",
		"dest": "fringe",
		"spawn": Vector2(0, 0),
		"open_by_default": true,
		"need": "",
	},
	{
		"id": "frost_gate",
		"biome": "frost",
		"name": "Frost Gate",
		"dest": "fringe",
		"spawn": Vector2(0, 0),
		"open_by_default": false,
		"need": "Clear the Barrow Lands",
	},
	{
		"id": "ember_gate",
		"biome": "ember",
		"name": "Ember Gate",
		"dest": "fringe",
		"spawn": Vector2(0, 0),
		"open_by_default": false,
		"need": "Clear the Frost Peaks",
	},
]

const SHOPS: Dictionary = {
	"general_store": {
		"id": "general_store",
		"name": "General Store",
		"stock": [
			{"item": "coins", "currency": "coins", "price": 1, "limit": 0},
			{"item": "health_potion", "currency": "coins", "price": 12, "limit": 20},
			{"item": "energy_potion", "currency": "coins", "price": 18, "limit": 15},
			{"item": "teleport_scroll", "currency": "coins", "price": 50, "limit": 5},
			{"item": "identify_scroll", "currency": "coins", "price": 30, "limit": 10},
		],
		"buy_types": ["material", "gear", "consumable"],
		"buy_price_mul": 0.4,
	},
	"material_buyer": {
		"id": "material_buyer",
		"name": "Material Buyer",
		"stock": [],
		"buy_types": ["material"],
		"buy_price_mul": 0.6,
		"specialty": "materials",
	},
}

static func biome(id: String) -> Dictionary:
	if str(id) == "barrow":
		return BIOME
	return BIOME

static func hub_data() -> Dictionary:
	return HUB

## Every hub gate, in hub order.
static func gates() -> Array:
	return GATES

## One gate by its id. An unknown id reads as an empty gate.
static func gate_by_id(id: String) -> Dictionary:
	for gate in GATES:
		if str(gate["id"]) == id:
			return gate
	return {}

static func tier_data(tier_id: String) -> Dictionary:
	for tier in TIERS:
		if str(tier["id"]) == tier_id:
			return tier
	return TIERS[0]

static func tier_by_depth(depth: int) -> Dictionary:
	for tier in TIERS:
		if int(tier["depth"]) == depth:
			return tier
	return TIERS[0]

## The tier's depth index, or -1 when the id is not a wilderness tier.
static func tier_index(tier_id: String) -> int:
	for tier in TIERS:
		if str(tier["id"]) == tier_id:
			return int(tier["depth"])
	return -1

static func shop_data(shop_id: String) -> Dictionary:
	return SHOPS.get(shop_id, {})

static func all_tiers() -> Array:
	return TIERS.duplicate()

static func tier_ids() -> Array:
	var ids: Array = []
	for tier in TIERS:
		ids.append(str(tier["id"]))
	return ids

static func gathering_nodes_for_tier(tier_id: String) -> Array:
	var tier := tier_data(tier_id)
	return Array(tier.get("gathering_nodes", []))

static func elite_chance_for_tier(tier_id: String) -> float:
	var tier := tier_data(tier_id)
	return float(tier.get("elite_chance", 0.0))

static func monster_level_range(tier_id: String) -> Dictionary:
	var tier := tier_data(tier_id)
	return {
		"min": int(tier.get("monster_level_min", 1)),
		"max": int(tier.get("monster_level_max", 10)),
	}

static func loot_tier_for_depth(depth: int) -> int:
	var tier := tier_by_depth(depth)
	return int(tier.get("loot_tier", 0))

static func danger_params(tier_id: String) -> Dictionary:
	var tier := tier_data(tier_id)
	return Dictionary(tier.get("danger", {}))

static func recommended_combat(tier_id: String) -> int:
	var tier := tier_data(tier_id)
	return int(tier.get("recommended_combat", 1))

static func tier_name(tier_id: String) -> String:
	var tier := tier_data(tier_id)
	return str(tier.get("name", "Unknown"))

static func tier_description(tier_id: String) -> String:
	var tier := tier_data(tier_id)
	return str(tier.get("description", ""))

static func world_dimensions() -> Dictionary:
	return {
		"cols": int(BIOME["world_cols"]),
		"rows": int(BIOME["world_rows"]),
		"cell_size": BIOME["cell_size"],
		"total_size": Vector2(
			float(BIOME["world_cols"]) * BIOME["cell_size"].x,
			float(BIOME["world_rows"]) * BIOME["cell_size"].y
		),
	}

static func hub_spawn() -> Vector2:
	return HUB["spawn"]

static func is_hub_zone(zone_id: String) -> bool:
	return str(zone_id) == "hub"

static func tier_order() -> Array:
	return Array(BIOME["tier_order"])