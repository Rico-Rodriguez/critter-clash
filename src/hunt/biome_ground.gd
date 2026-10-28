extends RefCounted
## Paints terrain cells into the Rimehollow and Cinder Mire hunts when the zone's
## own arena has not (arena.terrain_live is false): ice sheets with a few thin
## patches in the frost, the bog pools in the swamp (with the zone's own dark earth underfoot). The cells sit
## under the props arena_frozen.gd and arena_swamp.gd already place, so the ground
## the player sees is the ground the rules use. A zone that paints its own cells
## (the Lead's layouts) calls terrain_begin first and this does nothing.
## Preloaded by hunt.gd, no class_name.

const T := preload("res://src/hunt/terrain.gd")

## Where arena_frozen.gd lays its ice sheets (Art.ice_sheets) and drifts.
const SHEETS := [Vector3(-4, 0, 6), Vector3(3, 0, 12), Vector3(-15, 0, 2), Vector3(14, 0, -1), Vector3(5, 0, -20), Vector3(-9, 0, -11), Vector3(15.5, 0, 13), Vector3(-1, 0, -17)]
const THIN := [Vector3(-10, 0, -1), Vector3(11, 0, -12), Vector3(3, 0, -7)]
## Where arena_swamp.gd digs its bog pools.
const POOLS := [Vector3(-8, 0, 6), Vector3(7, 0, 8.5), Vector3(-11.5, 0, -6), Vector3(11, 0, -3), Vector3(0, 0, -6), Vector3(-5, 0, -16.5), Vector3(9.5, 0, -16), Vector3(-2, 0, 17.5)]


static func wants(zone_id: String) -> bool:
	return zone_id == "frost" or zone_id == "swamp"


static func paint(a: Arena, zone_id: String) -> void:
	if a.terrain_live or not wants(zone_id):
		return
	var g: RefCounted = a.terrain
	if zone_id == "frost":
		for p: Vector3 in SHEETS:
			_blob(g, p, T.ICE, 1)
		for p: Vector3 in THIN:
			_blob(g, p, T.THIN_ICE, 1)
	else:
		for p: Vector3 in POOLS:
			_blob(g, p, T.BOG, 1)
	var look := {}
	if zone_id == "swamp":
		# Soot-dark earth and wet bog (the zone's own ground colours, lifted a step so it reads).
		look = {"dark": (a.zone_env["ground"] as Dictionary)["dark"], "base_a": Color(0.22, 0.205, 0.17), "base_b": Color(0.3, 0.28, 0.23),
			"bog_col": Color(0.07, 0.05, 0.035)}
	a.terrain_begin(look)
	a.terrain_painted()


## A 2 x 2 (r = 1) or larger square of cells round `p`.
static func _blob(g: RefCounted, p: Vector3, kind: int, r: int) -> void:
	var c0: Vector2i = g.cell_of(p)
	for dz in range(-r, r + 1):
		for dx in range(-r, r + 1):
			if absi(dx) + absi(dz) > r:
				continue
			var c := c0 + Vector2i(dx, dz)
			if g.in_bounds(c) and g.kind_of(c) == T.DRY:
				g.set_kind(c, kind)
