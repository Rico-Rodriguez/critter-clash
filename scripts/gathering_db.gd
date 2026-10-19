class_name GatheringDB
extends RefCounted

## Gathering skills and the resource nodes they work. Gathering is
## account-wide (see docs/gathering.md): the XP for the three gathering
## skills lives in SaveGame.data["skills"] and the level comes from the OSRS
## curve in Catalog.skill_level. This file holds only the data - the nodes,
## what they ask for and what they pay.
##
## A node is:
##   id       unique key, also its loot table key in LootTable.RESOURCE_TABLES
##   skill    the gathering skill it trains
##   name     display name
##   kind     "tree" | "spot" | "vein" - the three families of node
##   biome    the biome it grows in
##   level    the gathering level it asks for
##   xp       XP it pays for one successful gather
##   respawn  seconds of sim time before it can be worked again
##
## The skill ids live in Catalog.SKILLS (the save owns their XP), so this file
## never restates them.

## The resource nodes. Two of each kind per biome, so a biome always offers
## a starter node and something to level towards. XP climbs with the level
## the node asks for, and the respawn grows with it: the better nodes are
## slower to come back.
const NODES: Array = [
	# --- Meadow ---
	{"id": "willow", "skill": "woodcutting", "name": "Willow", "kind": "tree", "biome": "meadow", "level": 1, "xp": 25, "respawn": 6.0},
	{"id": "oak", "skill": "woodcutting", "name": "Oak", "kind": "tree", "biome": "meadow", "level": 15, "xp": 38, "respawn": 8.0},
	{"id": "brook", "skill": "fishing", "name": "Brook", "kind": "spot", "biome": "meadow", "level": 1, "xp": 20, "respawn": 6.0},
	{"id": "shallow_pool", "skill": "fishing", "name": "Shallow Pool", "kind": "spot", "biome": "meadow", "level": 10, "xp": 30, "respawn": 8.0},
	{"id": "copper_vein", "skill": "mining", "name": "Copper Vein", "kind": "vein", "biome": "meadow", "level": 1, "xp": 17, "respawn": 6.0},
	{"id": "tin_vein", "skill": "mining", "name": "Tin Vein", "kind": "vein", "biome": "meadow", "level": 15, "xp": 35, "respawn": 8.0},
	# --- Mushroom ---
	{"id": "sporewood", "skill": "woodcutting", "name": "Sporewood", "kind": "tree", "biome": "mushroom", "level": 25, "xp": 50, "respawn": 10.0},
	{"id": "barrowwood", "skill": "woodcutting", "name": "Barrowwood", "kind": "tree", "biome": "mushroom", "level": 35, "xp": 63, "respawn": 12.0},
	{"id": "spore_stream", "skill": "fishing", "name": "Spore Stream", "kind": "spot", "biome": "mushroom", "level": 20, "xp": 45, "respawn": 10.0},
	{"id": "underroot_pool", "skill": "fishing", "name": "Underroot Pool", "kind": "spot", "biome": "mushroom", "level": 35, "xp": 55, "respawn": 12.0},
	{"id": "iron_vein", "skill": "mining", "name": "Iron Vein", "kind": "vein", "biome": "mushroom", "level": 25, "xp": 50, "respawn": 10.0},
	{"id": "coal_vein", "skill": "mining", "name": "Coal Vein", "kind": "vein", "biome": "mushroom", "level": 30, "xp": 65, "respawn": 12.0},
	# --- Frost ---
	{"id": "frostpine", "skill": "woodcutting", "name": "Frostpine", "kind": "tree", "biome": "frost", "level": 45, "xp": 75, "respawn": 14.0},
	{"id": "glacierheart", "skill": "woodcutting", "name": "Glacierheart", "kind": "tree", "biome": "frost", "level": 60, "xp": 100, "respawn": 16.0},
	{"id": "glacier_lake", "skill": "fishing", "name": "Glacier Lake", "kind": "spot", "biome": "frost", "level": 45, "xp": 70, "respawn": 14.0},
	{"id": "frostspring", "skill": "fishing", "name": "Frostspring", "kind": "spot", "biome": "frost", "level": 55, "xp": 80, "respawn": 16.0},
	{"id": "silver_vein", "skill": "mining", "name": "Silver Vein", "kind": "vein", "biome": "frost", "level": 40, "xp": 75, "respawn": 14.0},
	{"id": "gold_vein", "skill": "mining", "name": "Gold Vein", "kind": "vein", "biome": "frost", "level": 55, "xp": 100, "respawn": 16.0},
	# --- Volcano ---
	{"id": "cinderwood", "skill": "woodcutting", "name": "Cinderwood", "kind": "tree", "biome": "volcano", "level": 70, "xp": 112, "respawn": 18.0},
	{"id": "emberbark", "skill": "woodcutting", "name": "Emberbark", "kind": "tree", "biome": "volcano", "level": 80, "xp": 125, "respawn": 20.0},
	{"id": "magma_vent", "skill": "fishing", "name": "Magma Vent", "kind": "spot", "biome": "volcano", "level": 65, "xp": 95, "respawn": 18.0},
	{"id": "emberdeep", "skill": "fishing", "name": "Emberdeep", "kind": "spot", "biome": "volcano", "level": 80, "xp": 120, "respawn": 20.0},
	{"id": "cinderore", "skill": "mining", "name": "Cinderore", "kind": "vein", "biome": "volcano", "level": 70, "xp": 125, "respawn": 18.0},
	{"id": "runebound_seam", "skill": "mining", "name": "Runebound Seam", "kind": "vein", "biome": "volcano", "level": 80, "xp": 150, "respawn": 20.0},
]

## What a gathered resource is called and which skill drops it. The ids are
## material ids: they land in SaveGame.data["materials"] like the boss
## materials, so one bag holds everything the world gives.
const RESOURCES: Dictionary = {
	"willow_logs": {"name": "Willow logs", "skill": "woodcutting"},
	"oak_logs": {"name": "Oak logs", "skill": "woodcutting"},
	"sporewood_logs": {"name": "Sporewood logs", "skill": "woodcutting"},
	"barrowwood_logs": {"name": "Barrowwood logs", "skill": "woodcutting"},
	"frostpine_logs": {"name": "Frostpine logs", "skill": "woodcutting"},
	"glacierheart_logs": {"name": "Glacierheart logs", "skill": "woodcutting"},
	"cinderwood_logs": {"name": "Cinderwood logs", "skill": "woodcutting"},
	"emberbark_logs": {"name": "Emberbark logs", "skill": "woodcutting"},
	"brook_fish": {"name": "Brook fish", "skill": "fishing"},
	"pool_fish": {"name": "Pool fish", "skill": "fishing"},
	"spore_carp": {"name": "Spore carp", "skill": "fishing"},
	"underroot_eel": {"name": "Underroot eel", "skill": "fishing"},
	"glacier_fish": {"name": "Glacier fish", "skill": "fishing"},
	"frostspring_crab": {"name": "Frostspring crab", "skill": "fishing"},
	"magma_fish": {"name": "Magma fish", "skill": "fishing"},
	"emberdeep_fish": {"name": "Emberdeep fish", "skill": "fishing"},
	"copper_ore": {"name": "Copper ore", "skill": "mining"},
	"tin_ore": {"name": "Tin ore", "skill": "mining"},
	"iron_ore": {"name": "Iron ore", "skill": "mining"},
	"coal": {"name": "Coal", "skill": "mining"},
	"silver_ore": {"name": "Silver ore", "skill": "mining"},
	"gold_ore": {"name": "Gold ore", "skill": "mining"},
	"cinderore": {"name": "Cinderore", "skill": "mining"},
	"runebound_shard": {"name": "Runebound shard", "skill": "mining"},
}


# --- Lookups -----------------------------------------------------------------

## The node record, or {} for an unknown id.
static func node(id: String) -> Dictionary:
	for entry in NODES:
		if str(entry["id"]) == id:
			return entry
	return {}


static func has_node(id: String) -> bool:
	return not node(id).is_empty()


## Orders two nodes by the level they ask for, then by id.
static func _by_level(a: Dictionary, b: Dictionary) -> bool:
	var la := int(a["level"])
	var lb := int(b["level"])
	if la != lb:
		return la < lb
	return str(a["id"]) < str(b["id"])


## Every node, ordered by the level it asks for (then id, so the order is
## stable). Callers that want a flat list use this; NODES itself stays in
## biome order for readability.
static func nodes() -> Array:
	var out: Array = NODES.duplicate()
	out.sort_custom(_by_level)
	return out


## The nodes of one gathering skill, ordered by level.
static func nodes_for_skill(skill: String) -> Array:
	var out: Array = []
	for entry in nodes():
		if str(entry["skill"]) == skill:
			out.append(entry)
	return out


## The nodes of one biome, ordered by level.
static func nodes_for_biome(biome: String) -> Array:
	var out: Array = []
	for entry in nodes():
		if str(entry["biome"]) == biome:
			out.append(entry)
	return out


## The nodes of one biome for one skill, ordered by level.
static func nodes_for(skill: String, biome: String) -> Array:
	var out: Array = []
	for entry in nodes_for_biome(biome):
		if str(entry["skill"]) == skill:
			out.append(entry)
	return out


## The gathering skill a node trains, or "" for an unknown node.
static func skill_of(id: String) -> String:
	var n := node(id)
	return str(n["skill"]) if not n.is_empty() else ""


## The gathering skill ids, in the order Catalog.SKILLS lists them.
static func skill_ids() -> Array[String]:
	var out: Array[String] = []
	for entry in Catalog.SKILLS:
		out.append(str(entry["id"]))
	return out


## True when the id names a gathering skill.
static func is_skill(id: String) -> bool:
	return id in skill_ids()


## The display name of a gathering skill, or the id itself.
static func skill_name(id: String) -> String:
	for entry in Catalog.SKILLS:
		if str(entry["id"]) == id:
			return str(entry["name"])
	return id


## The display name of a resource, or the id itself.
static func resource_name(id: String) -> String:
	var r: Dictionary = RESOURCES.get(id, {})
	return str(r["name"]) if not r.is_empty() else id


## The resource record, or {} for an unknown id.
static func resource(id: String) -> Dictionary:
	return RESOURCES.get(id, {})
