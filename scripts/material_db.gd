class_name MaterialDB
extends RefCounted

## What a material is worth, in coins, and what it is called. One table prices
## the whole bag: the boss drops (Catalog.DROPS, the rows with kind
## "material") and the gathered resources (GatheringDB.RESOURCES) share one
## bag, so they share one price list (see docs/gathering.md).
##
## The prices are deliberately small. A boss material is worth less than the
## coin purse the same boss can drop (40 coins), and a worked resource is
## worth less than a single coin from a hunt chest, so selling the bag never
## competes with the real loot: it is a tidy-up, not a farm.
##
## The ids are material ids: the same strings the save counts under
## (SaveGame.data["materials"]).

## material id -> coins for one of it.
const PRICES: Dictionary = {
	# --- Boss materials (Catalog.DROPS, the rows with kind "material") ---
	# Four per biome: a common one, an uncommon one, a rare one and a very
	# rare one, each dearer than the last.
	"meadow_fiber": 6,
	"pollen": 8,
	"boar_bristle": 10,
	"flower_crown": 16,
	"cap_bits": 6,
	"spore_dust": 8,
	"toad_cap": 10,
	"giant_cap": 16,
	"frost_wool": 6,
	"ice_shard": 8,
	"hare_fluff": 10,
	"aurora_shard": 16,
	"ash_clump": 6,
	"ember_ore": 8,
	"salamander_scale": 10,
	"heart_of_ash": 16,
	# --- Gathered resources (GatheringDB.RESOURCES) ---
	# Eight per skill, one per node tier: the better node pays a dearer
	# material, so the deeper biomes are worth the trip.
	"willow_logs": 2,
	"oak_logs": 3,
	"sporewood_logs": 4,
	"barrowwood_logs": 5,
	"frostpine_logs": 6,
	"glacierheart_logs": 8,
	"cinderwood_logs": 10,
	"emberbark_logs": 12,
	"brook_fish": 2,
	"pool_fish": 3,
	"spore_carp": 4,
	"underroot_eel": 5,
	"glacier_fish": 6,
	"frostspring_crab": 8,
	"magma_fish": 10,
	"emberdeep_fish": 12,
	"copper_ore": 2,
	"tin_ore": 3,
	"iron_ore": 4,
	"coal": 5,
	"silver_ore": 6,
	"gold_ore": 8,
	"cinderore": 10,
	"runebound_shard": 12,
	# --- Depth tier resources (GatheringDB.DEPTH_TIERS) ---
	# The tier ladder prices like the one above: the fringe is worth a few
	# coins, the abyss worth real money. A material with no price is never
	# sold, so every resource the depths give carries one.
	"shrimp": 2,
	"trout": 3,
	"salmon": 5,
	"shark": 9,
	"yew_logs": 5,
	"magic_logs": 9,
	"mithril_ore": 6,
	"runite_ore": 10,
}


## The coins one of a material is worth, or 0 for an id that is not a
## material. An unknown id is never sold, so it never pays out.
static func price(id: String) -> int:
	return int(PRICES.get(id, 0))


## The coins a stack of a material is worth.
static func value(id: String, count: int) -> int:
	return price(id) * maxi(count, 0)


## True when the id names a material the bag can hold.
static func is_material(id: String) -> bool:
	return PRICES.has(id)


## The display name: a boss drop keeps the name the catalog gives it, a
## gathered resource the one in GatheringDB.RESOURCES. An unknown id reads as
## itself.
static func name_of(id: String) -> String:
	var drop := Catalog.drop_by_id(id)
	if not drop.is_empty():
		return str(drop.get("name", id))
	return GatheringDB.resource_name(id)


## "boss" for a boss drop, "gathered" for a worked resource, "" for anything
## else. The bag lists the two groups apart.
static func kind_of(id: String) -> String:
	if not Catalog.drop_by_id(id).is_empty():
		return "boss"
	if not GatheringDB.resource(id).is_empty():
		return "gathered"
	return ""


## The gathering skill a resource trains, "" for a boss material.
static func skill_of(id: String) -> String:
	return str(GatheringDB.resource(id).get("skill", ""))


## The material ids of one group, in a stable order: the boss drops in the
## catalog's own order (biome by biome), the gathered resources in the order
## the gathering database lists them.
static func ids_of_kind(kind: String) -> Array:
	var out: Array = []
	if kind == "boss":
		for entry in Catalog.DROPS:
			var id := str(entry.get("id", ""))
			if str(entry.get("kind", "")) == "material" and is_material(id):
				out.append(id)
		return out
	if kind == "gathered":
		for id in GatheringDB.RESOURCES.keys():
			if is_material(str(id)):
				out.append(str(id))
	return out


## Every material id, both groups.
static func all_ids() -> Array:
	return ids_of_kind("boss") + ids_of_kind("gathered")


## The painted icon for a material, or "" when it has none. The boss drops
## were baked as 3D props (tools: --bake-icons); the gathered resources have
## no art yet, so the caller draws a glyph instead.
static func icon_path(id: String) -> String:
	var path := "res://assets/sprites/items/%s.png" % id
	return path if ResourceLoader.exists(path) else ""
