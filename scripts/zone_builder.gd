class_name ZoneBuilder
extends RefCounted

## Builds the wilderness of the Barrow Lands: one large explorable zone per
## depth tier - the Fringe, the Wilds, the Deep, the Abyss - out of the data
## in WorldData.
##
## A zone is a place to walk through, not a field to fight in. It is many
## times the size of the shipped hunt arena, and it carries the tier's own
## character: the monsters stand in the tier's level range, the packs are as
## big as the tier's danger says, the elites are as common as the tier's
## elite chance, the resource nodes are the ones the tier names, and the
## ground wears the tier's own scenery.
##
## Every zone is built from a seed, so one seed always builds the same zone.
## The four zones of a seed stack north to south in tier order, so the four
## together are the whole Barrow Lands: the Fringe's north gate is the
## Wilds' south gate, and the Abyss' north gate is the lair.
##
## The builder only makes the place. The hunt simulation, the fog, the
## monsters and the loot come later, in the run that opens the zone.

## How many of the biome's cells each zone spans. The deep tiers are the
## big ones. A cell is the biome's own cell (WorldData.BIOME["cell_size"]),
## so a zone is always a whole number of the world's grid squares.
const ZONE_CELLS := {
	"fringe": Vector2i(4, 2),
	"wilds": Vector2i(4, 3),
	"deep": Vector2i(5, 3),
	"abyss": Vector2i(5, 4),
}

## The ground one monster pack claims, in sim px: a zone holds one pack per
## this much ground, so the big zones hold more of them.
const PACK_AREA := 1_200_000.0

## The ground one wandering patrol claims, in sim px, before the tier's
## patrol density scales the number.
const PATROL_AREA := 3_000_000.0

## How many monsters a pack holds before the tier's pack size scales it.
const BASE_PACK := 4

## How far two packs keep apart, in sim px.
const PACK_GAP := 340.0

## How far a pack keeps from a gate, in sim px.
const GATE_GAP := 430.0

## The ground one clump of scenery claims, in sim px.
const PROP_AREA := 34_000.0

## The hub's own height in the stacked world, in sim px.
const HUB_HEIGHT := 1280.0

## The scenery each tier wears. A row is a kind of prop, how often it is
## drawn, how big it stands and how wide it is. A kind with no width is
## soft: the ground under it is still walkable. A kind with a width is
## solid, and stands in the zone's landmarks as well as its props.
const PROP_KITS := {
	"fringe": [
		{"kind": "oak", "weight": 3.0, "lo": 1.1, "hi": 1.9, "wide": 70.0},
		{"kind": "birch", "weight": 2.0, "lo": 1.0, "hi": 1.6, "wide": 0.0},
		{"kind": "bush", "weight": 2.5, "lo": 0.8, "hi": 1.4, "wide": 0.0},
		{"kind": "boulder", "weight": 1.5, "lo": 1.0, "hi": 1.8, "wide": 80.0},
		{"kind": "stump", "weight": 1.0, "lo": 0.8, "hi": 1.2, "wide": 0.0},
		{"kind": "barrow_mound", "weight": 0.7, "lo": 1.2, "hi": 2.0, "wide": 110.0},
		{"kind": "bone_pile", "weight": 0.6, "lo": 0.8, "hi": 1.2, "wide": 0.0},
		{"kind": "grass_tuft", "weight": 3.0, "lo": 0.6, "hi": 1.1, "wide": 0.0},
	],
	"wilds": [
		{"kind": "blight_tree", "weight": 3.0, "lo": 1.0, "hi": 1.8, "wide": 70.0},
		{"kind": "thorn_bush", "weight": 2.5, "lo": 0.8, "hi": 1.4, "wide": 0.0},
		{"kind": "mushroom_cap", "weight": 2.0, "lo": 0.7, "hi": 1.3, "wide": 0.0},
		{"kind": "boulder", "weight": 1.5, "lo": 1.0, "hi": 1.7, "wide": 80.0},
		{"kind": "barrow_mound", "weight": 0.9, "lo": 1.2, "hi": 2.1, "wide": 110.0},
		{"kind": "grave_marker", "weight": 0.7, "lo": 0.9, "hi": 1.3, "wide": 46.0},
		{"kind": "bone_pile", "weight": 0.8, "lo": 0.8, "hi": 1.2, "wide": 0.0},
		{"kind": "grass_tuft", "weight": 2.0, "lo": 0.6, "hi": 1.1, "wide": 0.0},
	],
	"deep": [
		{"kind": "dead_tree", "weight": 3.0, "lo": 1.0, "hi": 1.8, "wide": 70.0},
		{"kind": "rime_shrub", "weight": 2.5, "lo": 0.8, "hi": 1.4, "wide": 0.0},
		{"kind": "standing_stone", "weight": 1.2, "lo": 1.0, "hi": 1.6, "wide": 46.0},
		{"kind": "boulder", "weight": 1.5, "lo": 1.0, "hi": 1.8, "wide": 80.0},
		{"kind": "barrow_mound", "weight": 1.0, "lo": 1.2, "hi": 2.2, "wide": 110.0},
		{"kind": "crystal", "weight": 0.6, "lo": 0.7, "hi": 1.1, "wide": 0.0},
		{"kind": "bone_pile", "weight": 0.9, "lo": 0.8, "hi": 1.3, "wide": 0.0},
		{"kind": "fog_fern", "weight": 2.0, "lo": 0.6, "hi": 1.1, "wide": 0.0},
	],
	"abyss": [
		{"kind": "scorched_tree", "weight": 3.0, "lo": 1.0, "hi": 1.8, "wide": 70.0},
		{"kind": "ash_pillar", "weight": 1.2, "lo": 1.0, "hi": 1.7, "wide": 60.0},
		{"kind": "ember_vent", "weight": 0.9, "lo": 0.8, "hi": 1.3, "wide": 0.0},
		{"kind": "ash_bush", "weight": 2.0, "lo": 0.8, "hi": 1.4, "wide": 0.0},
		{"kind": "boulder", "weight": 1.5, "lo": 1.0, "hi": 1.8, "wide": 80.0},
		{"kind": "bone_pile", "weight": 1.0, "lo": 0.8, "hi": 1.3, "wide": 0.0},
		{"kind": "magma_bloom", "weight": 0.7, "lo": 0.7, "hi": 1.2, "wide": 0.0},
		{"kind": "ash_tuft", "weight": 2.0, "lo": 0.6, "hi": 1.1, "wide": 0.0},
	],
}


# --- Building ----------------------------------------------------------------

## Builds one zone for a depth tier. The tier's own data drives the size,
## the monsters, the elites and the resources; the seed drives the layout.
static func build(tier_id: String, seed: int) -> WildernessZone:
	var tier := WorldData.tier_data(tier_id)
	var zone := WildernessZone.new()
	zone.id = str(tier["id"])
	zone.tier_id = zone.id
	zone.tier_name = str(tier["name"])
	zone.tier_depth = int(tier.get("depth", 0))
	zone.loot_tier = int(tier.get("loot_tier", 0))
	zone.recommended = int(tier.get("recommended_combat", 1))
	zone.danger = Dictionary(tier.get("danger", {}))
	zone.seed = seed
	var rng := RandomNumberGenerator.new()
	rng.seed = seed * 7919 + hash(zone.tier_id)
	_zone_frame(zone)
	_lay_terrain(zone, rng)
	_lay_camps(zone, rng)
	_lay_patrols(zone, rng)
	_lay_loot(zone, rng)
	_lay_gathering(zone, rng)
	_lay_scenery(zone, rng)
	_repair(zone)
	_publish(zone)
	zone.is_world = true
	zone.boss_at = zone.exit
	zone.zones = [{"id": zone.tier_id, "rect": zone.play}]
	zone.goblin_at = _goblin_haunt(zone, rng)
	return zone


## Builds every zone of the Barrow Lands for one seed, south to north: the
## Fringe first, the Abyss last.
static func build_all(seed: int) -> Array:
	var out: Array = []
	for tier_id in WorldData.tier_order():
		out.append(build(str(tier_id), seed))
	return out


## The zone in one line: its size, its ground and what stands in it.
static func summary(zone: WildernessZone) -> Dictionary:
	return zone.summary()


# --- The world the zones make -------------------------------------------------

## How many of the biome's cells a tier's zone spans.
static func zone_cells(tier_id: String) -> Vector2i:
	var cells: Vector2i = ZONE_CELLS.get(tier_id, Vector2i(4, 3))
	return cells


## How big a tier's zone is, in sim px.
static func zone_size(tier_id: String) -> Vector2:
	var cells := zone_cells(tier_id)
	var cell: Vector2 = WorldData.BIOME["cell_size"]
	return Vector2(cell.x * float(cells.x), cell.y * float(cells.y))


## Where a tier's zone stands in the stacked world: the hub is at the south,
## then the Fringe, the Wilds, the Deep and the Abyss to the north. A zone's
## own coordinates start at its own corner, so the world position of a point
## inside a zone is the zone's origin plus the point.
static func world_origin(tier_id: String) -> Vector2:
	var y := HUB_HEIGHT
	for id in WorldData.tier_order():
		if str(id) == tier_id:
			break
		y += zone_size(str(id)).y
	return Vector2(0.0, y)


## How big the whole stacked world is, in sim px: the hub and the four zones
## stacked, as wide as the widest of them.
static func world_size() -> Vector2:
	var h := HUB_HEIGHT
	var w := 0.0
	for id in WorldData.tier_order():
		var s := zone_size(str(id))
		h += s.y
		w = maxf(w, s.x)
	return Vector2(w, h)


# --- The tier's own things ----------------------------------------------------

## The critters that live in a tier: four of the biome's skins to a tier, in
## tier order, so the Fringe keeps the barrow beasts and the Abyss keeps the
## ash ones.
static func tier_skins(tier_id: String) -> Array:
	var tier := WorldData.tier_data(tier_id)
	var depth := int(tier.get("depth", 0))
	var all: Array = WorldData.BIOME["skins"]
	var out: Array = []
	for k in 4:
		var i := depth * 4 + k
		if i >= 0 and i < all.size():
			out.append(str(all[i]))
	if out.is_empty():
		out = all.duplicate()
	return out


## Resolves a resource node the world names to a gathering node.
##
## The world names its own nodes ("copper_vein", "ash_log", "minnow_pool").
## Some of those are the gathering catalog's nodes and some are not, so an
## unknown name falls back to the tier's own node for the skill the name
## implies, and a name that implies no skill at all (a nest, a bloom) stays
## a marker: something to find, not something to work.
static func resolve_gathering(id: String, tier_id: String) -> Dictionary:
	var out := {"id": id, "node": "", "skill": "", "kind": "marker", "name": _pretty(id)}
	if GatheringDB.has_node(id):
		var n := GatheringDB.node(id)
		out["node"] = id
		out["skill"] = str(n.get("skill", ""))
		out["kind"] = str(n.get("kind", "marker"))
		out["name"] = str(n.get("name", out["name"]))
		return out
	if GatheringDB.has_depth_node(id):
		var d := GatheringDB.depth_node(id)
		out["node"] = id
		out["skill"] = str(d.get("skill", ""))
		out["kind"] = str(d.get("kind", "marker"))
		out["name"] = str(d.get("name", out["name"]))
		return out
	var skill := _skill_of_name(id)
	if skill == "":
		return out
	for entry in GatheringDB.depth_nodes_for_tier(tier_id):
		if str(entry.get("skill", "")) != skill:
			continue
		out["node"] = str(entry.get("id", ""))
		out["skill"] = skill
		out["kind"] = str(entry.get("kind", "marker"))
		out["name"] = str(entry.get("name", out["name"]))
		return out
	return out


## The gathering skill a node name implies, or "" when it implies none.
static func _skill_of_name(id: String) -> String:
	var n := id.to_lower()
	if "vein" in n or "ore" in n or "seam" in n:
		return "mining"
	if "log" in n or "tree" in n or "wood" in n:
		return "woodcutting"
	if "pool" in n or "lake" in n or "pond" in n or "spot" in n or "water" in n:
		return "fishing"
	return ""


## A readable name for a node id: "copper_vein" reads as "Copper Vein".
static func _pretty(id: String) -> String:
	var out := ""
	for part in id.split("_", false):
		if out != "":
			out += " "
		out += part.substr(0, 1).to_upper() + part.substr(1)
	return out


# --- The ground ---------------------------------------------------------------

## The zone's frame: its size in cells, its play area and its chunk grid.
static func _zone_frame(zone: WildernessZone) -> void:
	var cells := zone_cells(zone.tier_id)
	var cell: Vector2 = WorldData.BIOME["cell_size"]
	zone.size = Vector2(cell.x * float(cells.x), cell.y * float(cells.y))
	zone.play = Rect2(Vector2.ZERO, zone.size)
	zone.chunk_size = cell
	zone.chunks.clear()
	for row in cells.y:
		for col in cells.x:
			zone.chunks.append({"col": col, "row": row, "ground": zone.tier_id, "props": []})


## Lays the ground out: a gate at the south, a gate at the north, a chain of
## clearings between them, and pockets hanging off the sides where the elites
## and the chests sit.
static func _lay_terrain(zone: WildernessZone, rng: RandomNumberGenerator) -> void:
	var w := zone.size.x
	var h := zone.size.y
	var gate_r := 430.0
	var entry := Vector2(w * rng.randf_range(0.26, 0.42), h - 250.0)
	var exit_at := Vector2(w * rng.randf_range(0.58, 0.74), 250.0)
	zone.entry = entry
	zone.exit = exit_at
	zone.start = entry
	zone.lair = exit_at
	zone.lair_r = gate_r
	var first := zone.add_area(entry, gate_r, "gate")
	var last := zone.add_area(exit_at, gate_r, "gate")
	var cells := zone_cells(zone.tier_id)
	var steps := cells.x + cells.y
	var chain: Array = []
	var prev := first
	for k in steps:
		var t := float(k + 1) / float(steps + 1)
		var at := entry.lerp(exit_at, t)
		at.x = clampf(at.x + rng.randf_range(-w * 0.2, w * 0.2), 560.0, w - 560.0)
		at.y = clampf(at.y + rng.randf_range(-150.0, 150.0), 460.0, h - 460.0)
		var r := rng.randf_range(400.0, 640.0)
		var idx := zone.add_area(at, r, "clearing")
		_link_wide(zone, prev, idx, rng.randf_range(380.0, 520.0), rng, true)
		chain.append(idx)
		prev = idx
	_link_wide(zone, prev, last, rng.randf_range(400.0, 540.0), rng, true)
	# Pockets: quiet clearings off the side of the chain.
	var want := 2 + zone.tier_depth
	var made := 0
	var tries := 0
	while made < want and tries < want * 14:
		tries += 1
		if chain.is_empty():
			break
		var host_id: int = int(chain[rng.randi() % chain.size()])
		var host: Dictionary = zone.nodes[host_id]
		var at: Vector2 = host["pos"]
		at += Vector2.RIGHT.rotated(rng.randf() * TAU) * rng.randf_range(560.0, 1000.0)
		if at.x < 430.0 or at.x > w - 430.0 or at.y < 400.0 or at.y > h - 400.0:
			continue
		var r := rng.randf_range(270.0, 380.0)
		var crowded := false
		for other in zone.nodes:
			var op: Vector2 = other["pos"]
			if op.distance_to(at) < r + float(other["r"]) - 140.0:
				crowded = true
				break
		if crowded:
			continue
		var idx := zone.add_area(at, r, "pocket")
		var from_id: int = int(chain[rng.randi() % chain.size()])
		_link_wide(zone, from_id, idx, rng.randf_range(300.0, 400.0), rng, false)
		made += 1


# --- The monsters -------------------------------------------------------------

## Places the monsters: a pack in nearly every open area, sized and levelled
## by the tier, and the elites the tier's chance calls for.
static func _lay_camps(zone: WildernessZone, rng: RandomNumberGenerator) -> void:
	var tier := WorldData.tier_data(zone.tier_id)
	var danger := zone.danger
	var skins := tier_skins(zone.tier_id)
	var lvl_lo := int(tier.get("monster_level_min", 1))
	var lvl_hi := int(tier.get("monster_level_max", 10))
	var pack_size := maxi(1, int(round(float(BASE_PACK) * float(danger.get("pack_size_mul", 1.0)))))
	var want := maxi(3, int(round(zone.size.x * zone.size.y / PACK_AREA)))
	var elite_chance := float(tier.get("elite_chance", 0.0))
	# The open areas that can hold a pack. The gates stay clear.
	var hosts: Array = []
	for i in zone.nodes.size():
		if str(zone.nodes[i]["kind"]) == "gate":
			continue
		hosts.append(i)
	if hosts.is_empty():
		return
	_shuffle(hosts, rng)
	var placed := 0
	var round_i := 0
	while placed < want and round_i < want * 4:
		var host_id: int = int(hosts[round_i % hosts.size()])
		round_i += 1
		var area: Dictionary = zone.nodes[host_id]
		var spot := _free_spot(zone, area, rng)
		if spot == Vector2.INF:
			continue
		zone.camps.append({
			"pos": spot,
			"count": pack_size,
			"elite": false,
			"node": host_id,
			"skin": str(skins[rng.randi() % skins.size()]),
			"level": _level_at(zone, spot, lvl_lo, lvl_hi, rng),
		})
		placed += 1
	# The elites: the deep tiers always keep a few, and the tier's chance
	# adds the rest.
	var order: Array = []
	for i in zone.camps.size():
		order.append(i)
	_shuffle(order, rng)
	var elites := 0
	var min_elites := 1 + zone.tier_depth
	for idx in order:
		var camp: Dictionary = zone.camps[int(idx)]
		var elite := false
		if elites < min_elites:
			elite = true
		elif rng.randf() < elite_chance:
			elite = true
		if elite:
			elites += 1
			camp["elite"] = true


## Walks the patrols: small groups that drift along the trail, in the number
## the tier's patrol density asks for.
static func _lay_patrols(zone: WildernessZone, rng: RandomNumberGenerator) -> void:
	var tier := WorldData.tier_data(zone.tier_id)
	var danger := zone.danger
	var skins := tier_skins(zone.tier_id)
	var lvl_lo := int(tier.get("monster_level_min", 1))
	var lvl_hi := int(tier.get("monster_level_max", 10))
	var size_mul := float(danger.get("pack_size_mul", 1.0))
	var want := maxi(1, int(round(zone.size.x * zone.size.y / PATROL_AREA * float(danger.get("patrol_density", 1.0)))))
	var segs: Array = zone.segs.duplicate()
	_shuffle(segs, rng)
	for k in mini(want, segs.size()):
		var s: Dictionary = segs[k]
		var a: Vector2 = s["a"]
		var b: Vector2 = s["b"]
		zone.patrols.append({
			"a": a.lerp(b, 0.2),
			"b": a.lerp(b, 0.8),
			"count": maxi(1, int(round(float(BASE_PACK) * 0.6 * size_mul))),
			"skin": str(skins[rng.randi() % skins.size()]),
			"level": _level_at(zone, a, lvl_lo, lvl_hi, rng),
		})


## The zone's chests: one in every pocket, and one out in the open by a
## clearing. The pockets are the quiet ground off the trail, so a chest is
## the reward for walking away from the path.
static func _lay_loot(zone: WildernessZone, rng: RandomNumberGenerator) -> void:
	var pockets: Array = []
	var clearings: Array = []
	for i in zone.nodes.size():
		var kind := str(zone.nodes[i]["kind"])
		if kind == "pocket":
			pockets.append(i)
		elif kind == "clearing":
			clearings.append(i)
	_shuffle(pockets, rng)
	for i in pockets:
		var n: Dictionary = zone.nodes[i]
		var away := Vector2.UP
		if not (n["links"] as Array).is_empty():
			away = -(n["links"][0] as Vector2).normalized()
		zone.loot.append({
			"pos": (n["pos"] as Vector2) + away * float(n["r"]) * 0.45,
			"tier": "rare" if zone.tier_depth >= 2 else "common",
		})
	if not clearings.is_empty():
		var i: int = clearings[rng.randi() % clearings.size()]
		var n: Dictionary = zone.nodes[i]
		zone.loot.append({
			"pos": (n["pos"] as Vector2) + Vector2.RIGHT.rotated(rng.randf() * TAU) * float(n["r"]) * 0.6,
			"tier": "common",
		})


## Joins two areas with a corridor that has room to bend. A plain link
## bends the corridor once, and the inside of that bend is a corner where
## two shapes meet at an angle: a body that walks into it can be wedged
## between them. A way clearing at the bend opens the corner up, so the
## whole route is walkable.
static func _link_wide(zone: WildernessZone, a: int, b: int, w: float, rng: RandomNumberGenerator, trail: bool) -> void:
	var pa: Vector2 = zone.nodes[a]["pos"]
	var pb: Vector2 = zone.nodes[b]["pos"]
	var mid := pa.lerp(pb, 0.5)
	var way := zone.add_area(mid, w * 0.85, "way")
	zone.link(a, way, w, rng, trail)
	zone.link(way, b, w, rng, trail)


## The level of the monsters at a place: the tier's own range, low at the
## south gate and high at the north one, so walking north walks deeper.
static func _level_at(zone: WildernessZone, at: Vector2, lo: int, hi: int, rng: RandomNumberGenerator) -> int:
	var span := maxf(1.0, zone.entry.y - zone.exit.y)
	var t := clampf((zone.entry.y - at.y) / span, 0.0, 1.0)
	t = clampf(t + rng.randf_range(-0.12, 0.12), 0.0, 1.0)
	return int(round(lerpf(float(lo), float(hi), t)))


## A free spot inside an open area: away from the other packs and from the
## gates, so the hero never walks into a knot of monsters.
static func _free_spot(zone: WildernessZone, area: Dictionary, rng: RandomNumberGenerator) -> Vector2:
	var centre: Vector2 = area["pos"]
	var r: float = area["r"]
	for k in 14:
		var at := centre + Vector2.RIGHT.rotated(rng.randf() * TAU) * r * rng.randf_range(0.1, 0.72)
		if at.x < 140.0 or at.x > zone.size.x - 140.0 or at.y < 140.0 or at.y > zone.size.y - 140.0:
			continue
		if at.distance_to(zone.entry) < GATE_GAP or at.distance_to(zone.exit) < GATE_GAP:
			continue
		var clear := true
		for c in zone.camps:
			if at.distance_to(c["pos"]) < PACK_GAP:
				clear = false
				break
		if clear:
			return at
	return Vector2.INF


# --- The resources ------------------------------------------------------------

## Places the tier's resource nodes: one per open area, easiest first, so
## the walk north earns the better nodes as it goes.
static func _lay_gathering(zone: WildernessZone, rng: RandomNumberGenerator) -> void:
	var ids: Array = WorldData.gathering_nodes_for_tier(zone.tier_id)
	if ids.is_empty():
		return
	var areas: Array = []
	for i in zone.nodes.size():
		if str(zone.nodes[i]["kind"]) == "gate":
			continue
		areas.append(i)
	if areas.is_empty():
		return
	# South to north, so the first node the tier lists is the one nearest
	# the entry gate.
	areas.sort_custom(func(a: int, b: int) -> bool:
		var pa: Vector2 = zone.nodes[a]["pos"]
		var pb: Vector2 = zone.nodes[b]["pos"]
		return pa.y > pb.y)
	var used: Array = []
	for k in ids.size():
		if k >= areas.size():
			break
		var area: Dictionary = zone.nodes[int(areas[k])]
		var at := _free_spot(zone, area, rng)
		if at == Vector2.INF:
			at = area["pos"]
		var node := resolve_gathering(str(ids[k]), zone.tier_id)
		# Two names in one tier must not claim the same catalog node.
		if str(node["node"]) != "" and used.has(str(node["node"])):
			node["node"] = ""
			node["skill"] = ""
			node["kind"] = "marker"
		elif str(node["node"]) != "":
			used.append(str(node["node"]))
		node["pos"] = at
		zone.gathering.append(node)


# --- The scenery --------------------------------------------------------------

## Dresses the zone: clumps of the tier's own scenery in the forest between
## the clearings, and the standing things (barrow mounds, standing stones)
## that block a path.
static func _lay_scenery(zone: WildernessZone, rng: RandomNumberGenerator) -> void:
	var kit: Array = PROP_KITS.get(zone.tier_id, PROP_KITS["fringe"])
	var clumps := maxi(4, int(round(zone.size.x * zone.size.y / PROP_AREA)))
	for k in clumps:
		var at := _forest_point(zone, rng)
		if at == Vector2.INF:
			continue
		var row := _pick_prop(kit, rng)
		var kind := str(row.get("kind", "bush"))
		var lo := float(row.get("lo", 1.0))
		var hi := float(row.get("hi", 1.0))
		var wide := float(row.get("wide", 0.0))
		for j in rng.randi_range(2, 6):
			var p := at + Vector2.RIGHT.rotated(rng.randf() * TAU) * rng.randf_range(0.0, 170.0)
			if p.x < 40.0 or p.x > zone.size.x - 40.0 or p.y < 40.0 or p.y > zone.size.y - 40.0:
				continue
			# The clearings and the trails stay clear of the scenery.
			var room := zone.depth(p)
			if room > -40.0:
				continue
			# A standing thing keeps well away from the open ground, so it
			# can never seal a trail in.
			if wide > 0.0 and room > -(wide + 140.0):
				continue
			var prop := {
				"kind": kind,
				"pos": p,
				"scale": rng.randf_range(lo, hi),
				"rot": rng.randf() * TAU,
			}
			zone.props.append(prop)
			if wide > 0.0:
				zone.landmarks.append({"pos": p, "kind": kind, "r": wide, "yaw": prop["rot"]})


## A spot in the forest: off the open ground and clear of the trail.
static func _forest_point(zone: WildernessZone, rng: RandomNumberGenerator) -> Vector2:
	for k in 16:
		var at := Vector2(rng.randf_range(60.0, zone.size.x - 60.0), rng.randf_range(60.0, zone.size.y - 60.0))
		if zone.depth(at) > -40.0:
			continue
		if zone.trail_dist(at) < 150.0:
			continue
		return at
	return Vector2.INF


## One prop from a kit, drawn by weight.
static func _pick_prop(kit: Array, rng: RandomNumberGenerator) -> Dictionary:
	var total := 0.0
	for row in kit:
		total += float(row.get("weight", 1.0))
	var roll := rng.randf() * total
	for row in kit:
		roll -= float(row.get("weight", 1.0))
		if roll <= 0.0:
			var picked: Dictionary = row
			return picked
	var first: Dictionary = kit[0]
	return first


## Where the treasure goblin hides in this zone: a pocket, or a clearing
## when the zone rolled no pockets.
static func _goblin_haunt(zone: WildernessZone, rng: RandomNumberGenerator) -> Vector2:
	var places: Array = []
	for i in zone.nodes.size():
		if str(zone.nodes[i]["kind"]) == "pocket":
			places.append(i)
	if places.is_empty():
		for i in zone.nodes.size():
			if str(zone.nodes[i]["kind"]) == "clearing":
				places.append(i)
	if places.is_empty():
		return Vector2.INF
	var pick: Dictionary = zone.nodes[int(places[rng.randi() % places.size()])]
	var at: Vector2 = pick["pos"]
	return at


# --- Making the zone hold together --------------------------------------------

## Makes sure the zone holds together: every pack, every node and both gates
## must be reachable from the entry gate over open ground, and nothing may
## seal the zone off.
static func _repair(zone: WildernessZone) -> void:
	# A standing thing must never wall the zone in: drop the last one and
	# rebake until the ground is whole again.
	var guard := 0
	while guard < 8:
		guard += 1
		zone.bake_grid()
		if _all_reachable(zone, zone.flow(zone.entry)):
			break
		if zone.landmarks.is_empty():
			break
		zone.landmarks.pop_back()
	var field := zone.flow(zone.entry)
	# What is still stranded moves to the nearest ground the hero can walk
	# to, or goes.
	var kept: Array = []
	for entry in zone.camps:
		var camp: Dictionary = entry
		var at: Vector2 = camp["pos"]
		if not _reachable(zone, field, at):
			at = _nudge(zone, at, field)
		if at == Vector2.INF:
			continue
		camp["pos"] = at
		kept.append(camp)
	zone.camps = kept
	var kept_nodes: Array = []
	for entry in zone.gathering:
		var g: Dictionary = entry
		var at: Vector2 = g["pos"]
		if not _reachable(zone, field, at):
			at = _nudge(zone, at, field)
		if at == Vector2.INF:
			continue
		g["pos"] = at
		kept_nodes.append(g)
	zone.gathering = kept_nodes
	var kept_loot: Array = []
	for entry in zone.loot:
		var c: Dictionary = entry
		var at: Vector2 = c["pos"]
		if not _reachable(zone, field, at):
			at = _nudge(zone, at, field)
		if at == Vector2.INF:
			continue
		c["pos"] = at
		kept_loot.append(c)
	zone.loot = kept_loot


## True when every pack, every node and the exit gate can be walked to.
static func _all_reachable(zone: WildernessZone, field: PackedInt32Array) -> bool:
	if not _reachable(zone, field, zone.exit):
		return false
	for entry in zone.camps:
		var c: Dictionary = entry
		if not _reachable(zone, field, c["pos"]):
			return false
	for entry in zone.gathering:
		var g: Dictionary = entry
		if not _reachable(zone, field, g["pos"]):
			return false
	return true


## True when a point stands on open ground the hero can walk to.
static func _reachable(zone: WildernessZone, field: PackedInt32Array, at: Vector2) -> bool:
	var i := zone.cell_index(at)
	if i < 0 or i >= zone.open_cells.size() or i >= field.size():
		return false
	if zone.open_cells[i] == 0:
		return false
	return field[i] >= 0


## The nearest spot to a point that the hero can actually walk to.
static func _nudge(zone: WildernessZone, at: Vector2, field: PackedInt32Array) -> Vector2:
	for ring in range(1, 9):
		var step := 120.0 * float(ring)
		for k in 12:
			var p := at + Vector2.RIGHT.rotated(TAU * float(k) / 12.0) * step
			if p.x < 60.0 or p.x > zone.size.x - 60.0 or p.y < 60.0 or p.y > zone.size.y - 60.0:
				continue
			if _reachable(zone, field, p):
				return p
	return Vector2.INF


## Publishes the zone's spawn points and elite markers from the packs the
## ground ended up holding.
static func _publish(zone: WildernessZone) -> void:
	zone.spawns.clear()
	zone.elites.clear()
	for entry in zone.camps:
		var camp: Dictionary = entry
		var spawn := {
			"pos": camp["pos"],
			"skin": str(camp.get("skin", "")),
			"level": int(camp.get("level", 1)),
			"count": int(camp.get("count", 1)),
			"elite": bool(camp.get("elite", false)),
			"kind": "camp",
			"area": int(camp.get("node", -1)),
		}
		zone.spawns.append(spawn)
		if bool(spawn["elite"]):
			zone.elites.append({
				"pos": spawn["pos"],
				"skin": spawn["skin"],
				"level": spawn["level"],
				"count": spawn["count"],
				"area": spawn["area"],
			})
	for entry in zone.patrols:
		var patrol: Dictionary = entry
		zone.spawns.append({
			"pos": patrol["a"],
			"skin": str(patrol.get("skin", "")),
			"level": int(patrol.get("level", 1)),
			"count": int(patrol.get("count", 1)),
			"elite": false,
			"kind": "patrol",
			"a": patrol["a"],
			"b": patrol["b"],
		})


## Fisher-Yates on the zone's seeded rng; Array.shuffle() would use the
## global one.
static func _shuffle(a: Array, rng: RandomNumberGenerator) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: Variant = a[i]
		a[i] = a[j]
		a[j] = tmp
