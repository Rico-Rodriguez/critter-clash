class_name TierBounds
extends RefCounted

## Where the world's depth tiers begin and end, and what happens when the
## hero walks across one of those lines. The world runs south to north: the
## safe Hub sits at the south edge, the boss lair at the north. Depth runs
## from 0 at the south edge to 1 at the lair -- the same measure the hunt's
## own depth curve rides, so a tier edge and a monster's depth never
## disagree about where the hero is.
##
## The bands own whole grid rows counted from the south, so every edge lands
## on a row line and the fog wall has something to stand on. The layout is
## data, the lookups are pure, and the tracker is the only stateful part.

## The bands, south to north. "rows" is how many grid rows a band owns,
## counted from the south edge. "tier" is the band's index in the tier order,
## and -1 for the Hub, which is a place rather than a tier.
const BANDS: Array = [
	{
		"id": "hub",
		"name": "Barrow Haven",
		"tier": -1,
		"rows": 1,
		"safe": true,
	},
	{
		"id": "fringe",
		"name": "The Fringe",
		"tier": 0,
		"rows": 1,
		"safe": false,
	},
	{
		"id": "wilds",
		"name": "The Wilds",
		"tier": 1,
		"rows": 2,
		"safe": false,
	},
	{
		"id": "deep",
		"name": "The Deep",
		"tier": 2,
		"rows": 2,
		"safe": false,
	},
	{
		"id": "abyss",
		"name": "The Abyss",
		"tier": 3,
		"rows": 1,
		"safe": false,
	},
]

## What stands at each tier edge: the fog wall that marks the line and the
## ground that darkens past it. "from" is the shallow band, "to" the deep
## one, and the line between them is the boundary. "darken" is how dark the
## ground runs past the edge, and it only grows as the world deepens.
const EDGES: Array = [
	{
		"id": "hub_fringe",
		"from": "hub",
		"to": "fringe",
		"kind": "treeline",
		"fog_wall": false,
		"darkened_ground": false,
		"width": 90.0,
		"fog_alpha": 0.0,
		"darken": 0.0,
		"tint": Color(0.62, 0.68, 0.52),
	},
	{
		"id": "fringe_wilds",
		"from": "fringe",
		"to": "wilds",
		"kind": "mist",
		"fog_wall": true,
		"darkened_ground": true,
		"width": 160.0,
		"fog_alpha": 0.35,
		"darken": 0.15,
		"tint": Color(0.58, 0.64, 0.62),
	},
	{
		"id": "wilds_deep",
		"from": "wilds",
		"to": "deep",
		"kind": "blight",
		"fog_wall": true,
		"darkened_ground": true,
		"width": 220.0,
		"fog_alpha": 0.5,
		"darken": 0.3,
		"tint": Color(0.44, 0.64, 0.34),
	},
	{
		"id": "deep_abyss",
		"from": "deep",
		"to": "abyss",
		"kind": "ash",
		"fog_wall": true,
		"darkened_ground": true,
		"width": 280.0,
		"fog_alpha": 0.62,
		"darken": 0.45,
		"tint": Color(0.74, 0.36, 0.18),
	},
]


# --- Layout ------------------------------------------------------------------

## The world's row count, as the biome declares it.
static func world_rows() -> int:
	return int(WorldData.BIOME["world_rows"])


## The size of one grid cell, as the biome declares it.
static func cell_size() -> Vector2:
	var cell: Vector2 = WorldData.BIOME["cell_size"]
	return cell


## The whole world, in sim px.
static func world_size() -> Vector2:
	var dims := WorldData.world_dimensions()
	var total: Vector2 = dims["total_size"]
	return total


## The bands, south to north.
static func bands() -> Array:
	return BANDS.duplicate(true)


## The band with this id, or {} when the id is unknown.
static func band(band_id: String) -> Dictionary:
	for b in BANDS:
		if str(b["id"]) == band_id:
			return b.duplicate(true)
	return {}


## A band's index in the tier order: 0 for the Fringe, -1 for the Hub.
static func band_index(band_id: String) -> int:
	var b := band(band_id)
	if b.is_empty():
		return -1
	return int(b["tier"])


## The wilderness tier a band names: 0 for the Fringe through 3 for the
## Abyss, and -1 for the Hub, which is a place rather than a tier.
static func tier_index(band_id: String) -> int:
	return WorldData.tier_index(band_id)


## How many grid rows each band owns, scaled to the world as it stands.
static func band_rows() -> Array:
	var rows := world_rows()
	var total := 0
	for b in BANDS:
		total += int(b["rows"])
	# The shares are rounded as a running total, so the bands keep their
	# proportions and the rows that do not divide evenly land on the bands
	# that lost the most to the rounding instead of all on the deepest one.
	var out: Array = []
	var acc := 0.0
	var used := 0
	for b in BANDS:
		acc += float(int(b["rows"])) * float(rows) / float(maxi(total, 1))
		var count := maxi(1, int(round(acc)) - used)
		out.append(count)
		used += count
	# Whatever the rounding left over goes to the deepest band, so every row
	# of the grid belongs to someone.
	var left := rows - used
	if left > 0:
		out[out.size() - 1] = int(out[out.size() - 1]) + left
	return out


## Where a band sits: the grid rows it owns counted from the north the way
## the map counts them, and the depth range those rows cover.
static func band_span(band_id: String) -> Dictionary:
	if band(band_id).is_empty():
		return {}
	var rows := world_rows()
	var counts := band_rows()
	var used := 0
	var span := 0
	for i in BANDS.size():
		if str(BANDS[i]["id"]) == band_id:
			span = int(counts[i])
			break
		used += int(counts[i])
	return {
		"rows": span,
		"from_row": rows - used - span,
		"to_row": rows - used - 1,
		"depth_from": float(used) / float(maxi(rows, 1)),
		"depth_to": float(used + span) / float(maxi(rows, 1)),
	}


## The band that owns a grid row, counted from the north the way the map
## counts them. Row 0 is the lair's row. {} when the row is off the map.
static func band_at_row(row: int) -> Dictionary:
	var rows := world_rows()
	if row < 0 or row >= rows:
		return {}
	var counts := band_rows()
	var used := 0
	for i in BANDS.size():
		var span := int(counts[i])
		var from_row := rows - used - span
		var to_row := rows - used - 1
		if row >= from_row and row <= to_row:
			return BANDS[i].duplicate(true)
		used += span
	return {}


# --- Where the tiers sit -----------------------------------------------------

## How deep a spot lies: 0 at the south edge, 1 at the lair.
static func depth_at_position(pos: Vector2, size: Vector2) -> float:
	return 1.0 - clampf(pos.y / maxf(size.y, 1.0), 0.0, 1.0)


## The band a depth falls in. A depth sitting exactly on an edge belongs to
## the band north of it, so the tier changes the moment the line is crossed.
static func band_at_depth(depth: float) -> Dictionary:
	var d := clampf(depth, 0.0, 1.0)
	var rows := world_rows()
	var counts := band_rows()
	var used := 0
	var chosen: Dictionary = BANDS[0]
	for i in BANDS.size():
		if d >= float(used) / float(maxi(rows, 1)):
			chosen = BANDS[i]
		used += int(counts[i])
	return chosen.duplicate(true)


## The band a world position falls in.
static func band_at_position(pos: Vector2, size: Vector2) -> Dictionary:
	return band_at_depth(depth_at_position(pos, size))


## The tier id at a depth: "hub", "fringe", "wilds", "deep" or "abyss".
static func tier_id_at_depth(depth: float) -> String:
	return str(band_at_depth(depth)["id"])


## The tier id a world position falls in.
static func tier_id_at_position(pos: Vector2, size: Vector2) -> String:
	return tier_id_at_depth(depth_at_position(pos, size))


## Whether a band is safe ground.
static func is_safe(band_id: String) -> bool:
	return bool(band(band_id).get("safe", false))


## Whether a depth lies on safe ground.
static func safe_at_depth(depth: float) -> bool:
	return is_safe(tier_id_at_depth(depth))


# --- Boundary markers --------------------------------------------------------

## The markers for every tier edge.
static func edges() -> Array:
	return EDGES.duplicate(true)


## One edge by the two bands it separates.
static func edge(from_id: String, to_id: String) -> Dictionary:
	for e in EDGES:
		if str(e["from"]) == from_id and str(e["to"]) == to_id:
			return e.duplicate(true)
	return {}


## The edge that stands between two bands, whichever side the crossing came
## from. A band pair only has one edge, and the edge is written deep to
## shallow, so a return walk has to be looked up the other way round.
static func edge_between(a_id: String, b_id: String) -> Dictionary:
	var e := edge(a_id, b_id)
	if not e.is_empty():
		return e
	return edge(b_id, a_id)


## The edge a band opens off, or {} for the shallowest band, which no edge
## leads into.
static func entering_edge(band_id: String) -> Dictionary:
	for e in EDGES:
		if str(e["to"]) == band_id:
			return e.duplicate(true)
	return {}


## The marker for an edge, with the place it stands worked out for the world
## as it stands: the depth it sits at, the world y it crosses, and the grid
## row it stands on.
static func marker(from_id: String, to_id: String, size: Vector2) -> Dictionary:
	var e := edge(from_id, to_id)
	if e.is_empty():
		return {}
	var span := band_span(to_id)
	if span.is_empty():
		return {}
	var depth := float(span["depth_from"])
	var y := (1.0 - depth) * size.y
	var cell := cell_size()
	var m := e.duplicate(true)
	m["depth"] = depth
	m["y"] = y
	m["row"] = clampi(int(y / maxf(cell.y, 1.0)), 0, maxi(world_rows() - 1, 0))
	return m


## Every marker, placed on the world as it stands.
static func markers(size: Vector2) -> Array:
	var out: Array = []
	for e in EDGES:
		var m := marker(str(e["from"]), str(e["to"]), size)
		if not m.is_empty():
			out.append(m)
	return out


## The markers for the edges that carry a fog wall, placed on the world as
## it stands. The treeline at the Hub has no wall and so no marker here.
static func fog_walls(size: Vector2) -> Array:
	var out: Array = []
	for m in markers(size):
		if bool(m.get("fog_wall", false)):
			out.append(m)
	return out


## The fog wall a band sits behind, or {} when the band is open ground.
static func fog_wall_for(band_id: String) -> Dictionary:
	for e in EDGES:
		if str(e["to"]) == band_id and bool(e["fog_wall"]):
			return e.duplicate(true)
	return {}


## The fog a band sits in: the alpha of the wall that stands at its edge.
static func fog_alpha_for(band_id: String) -> float:
	return float(fog_wall_for(band_id).get("fog_alpha", 0.0))


# --- Darkened ground ---------------------------------------------------------

## Whether a band's ground runs darkened. The ground darkens past an edge
## that says so, and only that edge decides.
static func darkened_ground(band_id: String) -> bool:
	return bool(entering_edge(band_id).get("darkened_ground", false))


## How dark a band's ground runs: 0 at the treeline, darkest by the lair.
static func darkening_for(band_id: String) -> float:
	var e := entering_edge(band_id)
	if not bool(e.get("darkened_ground", false)):
		return 0.0
	return float(e.get("darken", 0.0))


## How dark the ground runs at a depth.
static func darkening_at_depth(depth: float) -> float:
	return darkening_for(tier_id_at_depth(depth))


## How dark the ground runs at a world position.
static func darkening_at_position(pos: Vector2, size: Vector2) -> float:
	return darkening_at_depth(depth_at_position(pos, size))


# --- Crossings ---------------------------------------------------------------

## A band name in the HUD's voice: "The Deep" reads as "the Deep".
static func short_name(name: String) -> String:
	if name.begins_with("The "):
		return "the " + name.substr(4)
	return name


## The warning a crossing raises: "Entering the Deep" on the way down,
## "Returning to the Wilds" on the way back up.
static func crossing_message(to_b: Dictionary, deeper: bool) -> String:
	return ("Entering " if deeper else "Returning to ") + short_name(str(to_b["name"]))


## The event a tier crossing raises: where the hero came from, where they
## walked into, and the warning the HUD shows. Empty when the band did not
## change.
static func crossing(from_id: String, to_id: String) -> Dictionary:
	if from_id == to_id or from_id.is_empty():
		return {}
	var from_b := band(from_id)
	var to_b := band(to_id)
	if from_b.is_empty() or to_b.is_empty():
		return {}
	var deeper := band_index(to_id) > band_index(from_id)
	var tier_no := tier_index(to_id)
	var e := edge_between(from_id, to_id)
	var event := {
		"type": "tier_change",
		"from": from_id,
		"to": to_id,
		"tier": tier_no,
		"name": str(to_b["name"]),
		"direction": "deeper" if deeper else "shallower",
		"message": crossing_message(to_b, deeper),
		"safe": bool(to_b.get("safe", false)),
		"edge": str(e.get("id", "")),
		"edge_kind": str(e.get("kind", "")),
		"fog_wall": bool(e.get("fog_wall", false)),
		"darkened_ground": bool(e.get("darkened_ground", false)),
	}
	if tier_no >= 0:
		var tier := WorldData.tier_data(to_id)
		var danger: Dictionary = tier.get("danger", {})
		event["recommended_combat"] = int(tier.get("recommended_combat", 1))
		event["monster_level_min"] = int(tier.get("monster_level_min", 1))
		event["monster_level_max"] = int(tier.get("monster_level_max", 10))
		event["hazard"] = str(danger.get("hazard_type", ""))
	return event


## Watches a moving point and reports the tier crossings it makes. The hunt
## keeps one and asks it for an event every step.
class Tracker extends RefCounted:
	## The band the point was in last time.
	var current := ""
	## How deep the point was last time.
	var depth := 0.0

	func _init(start_id: String = "") -> void:
		current = start_id

	## The band the point is in now, and the crossing it made to get there.
	func update(new_depth: float) -> Dictionary:
		depth = new_depth
		var id := TierBounds.tier_id_at_depth(new_depth)
		if current.is_empty() or id == current:
			current = id
			return {}
		var event := TierBounds.crossing(current, id)
		current = id
		if not event.is_empty():
			event["depth"] = new_depth
		return event

	## The same, for a world position.
	func update_at(pos: Vector2, size: Vector2) -> Dictionary:
		return update(TierBounds.depth_at_position(pos, size))

	## The band the point stands in now.
	func current_band() -> Dictionary:
		return TierBounds.band(current)

	## Whether the point stands on safe ground.
	func in_safe_zone() -> bool:
		return TierBounds.is_safe(current)


# --- Checks ------------------------------------------------------------------

## Checks the tables against each other and returns what does not add up.
## An empty list means the bands, the edges and the biome agree.
static func validate() -> Array:
	var problems: Array = []
	var ids: Array = []
	for b in BANDS:
		ids.append(str(b["id"]))
	# Every band but the shallowest has an edge standing on its line.
	for i in range(1, BANDS.size()):
		var from_id := str(BANDS[i - 1]["id"])
		var to_id := str(BANDS[i]["id"])
		if edge_between(from_id, to_id).is_empty():
			problems.append("no edge between %s and %s" % [from_id, to_id])
	# Every edge names bands that exist and runs deeper than it starts.
	for e in EDGES:
		var from_id := str(e["from"])
		var to_id := str(e["to"])
		var edge_id := str(e["id"])
		if not ids.has(from_id):
			problems.append("edge %s starts at unknown band %s" % [edge_id, from_id])
		if not ids.has(to_id):
			problems.append("edge %s ends at unknown band %s" % [edge_id, to_id])
		if band_index(to_id) <= band_index(from_id):
			problems.append("edge %s does not run deeper" % edge_id)
	# A wall that carries fog and a ground that darkens have to say how much.
		if bool(e.get("fog_wall", false)) and float(e.get("fog_alpha", 0.0)) <= 0.0:
			problems.append("fog wall %s has no alpha" % edge_id)
		if bool(e.get("darkened_ground", false)) and float(e.get("darken", 0.0)) <= 0.0:
			problems.append("darkened ground %s has no darkening" % edge_id)
	# The band order and the biome's own tiers have to agree.
	for b in BANDS:
		var band_id := str(b["id"])
		if band_index(band_id) != tier_index(band_id):
			problems.append("band %s does not match the biome tier" % band_id)
	# The rows have to cover the world, every row of it.
	var counts := band_rows()
	var used := 0
	for n in counts:
		used += int(n)
	if used != world_rows():
		problems.append("bands own %d rows of %d" % [used, world_rows()])
	# The ground has to get darker and the fog thicker as the world deepens.
	var dark := -1.0
	var fog := -1.0
	for b in BANDS:
		var band_id := str(b["id"])
		var d := darkening_for(band_id)
		if d < dark:
			problems.append("band %s lightens as the world deepens" % band_id)
		dark = d
		var a := fog_alpha_for(band_id)
		if a < fog:
			problems.append("band %s thins the fog as the world deepens" % band_id)
		fog = a
	return problems
