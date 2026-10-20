class_name WildernessZone
extends HuntMap

## One depth tier of the Barrow Lands as a place: a large explorable zone -
## the Fringe, the Wilds, the Deep or the Abyss - built by ZoneBuilder out of
## the data in WorldData.
##
## A zone is a HuntMap, so the hunt simulation already knows how to walk one:
## the same pathing grid, the same flow field, the same camps, patrols,
## chests and gathering nodes. The zone adds what a depth tier knows that a
## biome map does not: which tier it is, how deep it runs, what the monsters
## in it are worth, where its two gates are, and the scenery that fills it.
##
## The fields the parent already has keep their meaning:
##   nodes    the open areas: the gates, the clearings and the pockets
##   segs     the corridors that join them
##   camps    the monster packs, each with the skin and the level it holds
##   patrols  the groups that drift along the trail
##   loot     the chests, in the pockets
##   gathering the resource nodes the tier names
##   landmarks the standing things that block a path
##   props    the soft scenery that fills the ground between the clearings
##
## `start` is the gate the hero comes in by and `lair` is the gate they leave
## by, at the far end of the zone.

## The tier this zone is: "fringe", "wilds", "deep" or "abyss".
var tier_id := "fringe"
## The tier's name as WorldData spells it: "The Fringe" and so on.
var tier_name := "The Fringe"
## How deep the tier runs: 0 at the treeline, 3 at the lair.
var tier_depth := 0
## The tier's loot tier: what the chests and the drops are worth.
var loot_tier := 0
## The combat level the tier recommends.
var recommended := 1
## The tier's danger: aggro, pack size, patrol density and any hazard.
var danger: Dictionary = {}
## The gate the hero comes in by, at the south of the zone.
var entry := Vector2.ZERO
## The gate they leave by, at the north of the zone.
var exit := Vector2.ZERO
## The monster spawn points of the zone: {pos, skin, level, count, elite,
## kind, area}. A "camp" stands still, a "patrol" walks a stretch of trail.
var spawns: Array = []
## The elite packs among them, as markers: {pos, skin, level, count, area}.
var elites: Array = []
## The soft scenery: {kind, pos, scale, rot}. A kind the stage does not know
## is scenery it can skip; a kind with a radius also stands in landmarks.
var props: Array = []


## Adds an open area to the zone and returns its index.
func add_area(pos: Vector2, r: float, kind: String = "clearing") -> int:
	return _add_node(pos, r, kind)


## Joins two areas with a corridor that bends once, so the trails wind.
func link(a: int, b: int, w: float, rng: RandomNumberGenerator, trail: bool = true) -> void:
	_link(a, b, w, rng, trail)


## Bakes the pathing grid for the zone's ground. The grid marks the open
## cells the hero can walk and the cells a standing thing blocks.
func bake_grid() -> void:
	_bake_grid()


## The monsters of the zone at one place, for the HUD and the map: the
## spawn points within `reach` of a point, nearest first.
func spawns_near(at: Vector2, reach: float) -> Array:
	var out: Array = []
	for s in spawns:
		var p: Vector2 = s["pos"]
		if p.distance_to(at) <= reach:
			out.append(s)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var pa: Vector2 = a["pos"]
		var pb: Vector2 = b["pos"]
		return pa.distance_squared_to(at) < pb.distance_squared_to(at))
	return out


## The zone in one line: its size, its ground and what stands in it.
func summary() -> Dictionary:
	return {
		"tier": tier_id,
		"name": tier_name,
		"depth": tier_depth,
		"size": size,
		"areas": nodes.size(),
		"spawns": spawns.size(),
		"elites": elites.size(),
		"gathering": gathering.size(),
		"props": props.size(),
		"landmarks": landmarks.size(),
	}
