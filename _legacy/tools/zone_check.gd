extends SceneTree

## A headless check of the wilderness zone builder (scripts/zone_builder.gd).
## Every depth tier must build a zone that is far bigger than the shipped
## hunt arena, that carries the tier's own monsters, elites and resources,
## and that the hero can walk from the south gate to the north gate.
##
##   godot --headless --path . -s res://tools/zone_check.gd

const SEED := 20261020


func _init() -> void:
	var ok := true
	for tier_id in WorldData.tier_order():
		ok = _check_zone(str(tier_id)) and ok
	ok = _check_stable() and ok
	print("ZONE CHECK ", "PASSED" if ok else "FAILED")
	quit(0 if ok else 1)


## One tier's zone: its size, its ground, its monsters and its resources.
func _check_zone(tier_id: String) -> bool:
	var zone := ZoneBuilder.build(tier_id, SEED)
	var ok := true
	# The zone is far bigger than the arena the hunt ships with.
	var arena := HuntMap.ARENA.x * HuntMap.ARENA.y
	var ground := zone.size.x * zone.size.y
	ok = ok and ground > arena * 4.0
	# The ground is laid out, and both gates stand on it.
	ok = ok and zone.nodes.size() >= 4
	ok = ok and zone.segs.size() >= 3
	ok = ok and zone.depth(zone.entry) > 0.0
	ok = ok and zone.depth(zone.exit) > 0.0
	# The hero can walk from the south gate to the north gate.
	var field := zone.flow(zone.entry)
	ok = ok and field[zone.cell_index(zone.exit)] >= 0
	# The tier's own monsters stand in the tier's own level range.
	var levels := WorldData.monster_level_range(tier_id)
	ok = ok and zone.spawns.size() >= 3
	for entry in zone.spawns:
		var spawn: Dictionary = entry
		ok = ok and int(spawn["level"]) >= int(levels["min"])
		ok = ok and int(spawn["level"]) <= int(levels["max"])
		ok = ok and zone.depth(spawn["pos"]) > 0.0
	# The tier's own elites, resources and scenery are in it.
	ok = ok and zone.elites.size() >= 1
	ok = ok and zone.gathering.size() == WorldData.gathering_nodes_for_tier(tier_id).size()
	for entry in zone.gathering:
		var node: Dictionary = entry
		ok = ok and zone.depth(node["pos"]) > 0.0
	ok = ok and zone.props.size() > 20
	ok = ok and zone.landmarks.size() > 0
	print("[%s] %s" % [tier_id, str(zone.summary())])
	return ok


## One seed always builds the same zone, and another seed lays it out
## differently.
func _check_stable() -> bool:
	var a := ZoneBuilder.build("wilds", SEED)
	var b := ZoneBuilder.build("wilds", SEED)
	var c := ZoneBuilder.build("wilds", SEED + 1)
	var ok := a.spawns.size() == b.spawns.size()
	for i in mini(a.spawns.size(), b.spawns.size()):
		var pa: Vector2 = a.spawns[i]["pos"]
		var pb: Vector2 = b.spawns[i]["pos"]
		ok = ok and pa == pb
	var differs := a.spawns.size() != c.spawns.size()
	if not differs and not a.spawns.is_empty():
		var pa: Vector2 = a.spawns[0]["pos"]
		var pc: Vector2 = c.spawns[0]["pos"]
		differs = pa != pc
	return ok and differs
