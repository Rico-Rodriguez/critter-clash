extends RefCounted
## The terrain cell grid's rules, as plain data with no scene tree: a 2 m grid
## over the playfield, one kind per cell, and the timers that change a cell's
## kind (thin ice snapping, fire spreading, ash re-flooding). The Arena owns one
## of these per hunt, calls `step(dt)` once per physics tick, and reads the
## answers back (`surface_at`, `body_effect`, `flow_cost`) from Hero and Enemy.
## Keeping it node-free lets tests/terrain_tests.gd run it headless and fast.
## Hooks that wire it into the Lead's files: docs section "Dev hooks" in
## biome-rebuild-plan.md.
##
## Kinds: DRY, ICE, THIN_ICE, WATER, PLANK, BOG, BURNING, ASH, WALL_ICE.
## Thin ice: a walker standing on a cell starts a SNAP_DELAY fuse; when it ends the
## cell is WATER for WATER_TIME, then freezes back to ICE. Anything walking that is
## in a WATER cell drowns (foes) or is chilled and dragged out (hero).
## Fire: `ignite` turns a BOG or PLANK cell BURNING; every STEP seconds the fire
## warns the flammable neighbours (visible telegraph), and the warned cell
## ignites one STEP later. BURNING lasts BURN_TIME then becomes ASH (a plank
## falls into BOG instead); ASH floods back to BOG after ASH_TIME.

const CELL := 2.0
## 22 x 26 cells cover x -22..22 and z -31..21: the playfield (x +-21, z -31..21).
const W := 22
const H := 26
const ORIGIN := Vector2(-22.0, -31.0)

const DRY := 0
const ICE := 1
const THIN_ICE := 2
const WATER := 3
const PLANK := 4
const BOG := 5
const BURNING := 6
const ASH := 7
const WALL_ICE := 8
const NAMES := ["dry", "ice", "thin_ice", "water", "plank", "bog", "burning", "ash", "wall_ice"]

## Tunables (seconds, metres). The plan fixes the first four; the rest are first guesses.
const SNAP_DELAY := 1.2
const WATER_TIME := 8.0
const STEP := 1.5
const ASH_TIME := 25.0
const BURN_TIME := 4.5
## Walkers lighter than this do not crack thin ice (a drifting spore, a hare).
const CRACK_MASS := 0.8
## Burning damage per second, as a fraction of the victim's max HP per second for
## foes that live in the bog and as a flat hero value scaled by the hunt tier.
const BURN_DPS := 14.0
const CHILL_HIT := 12.0

## Per kind: `grip` scales ground acceleration (ice 60 -> about 16), `speed` the
## walk speed, `slide` how far knockback and dashes carry, `cost` the flow-field
## cost (-1 = blocked), `solid` whether a body may stand there, `flammable`
## whether fire spreads into it.
const SURFACE := {
	DRY: {"grip": 1.0, "speed": 1.0, "slide": 1.0, "cost": 1.0, "solid": true, "flammable": false},
	ICE: {"grip": 0.27, "speed": 1.0, "slide": 1.4, "cost": 1.0, "solid": true, "flammable": false},
	THIN_ICE: {"grip": 0.27, "speed": 1.0, "slide": 1.4, "cost": 1.0, "solid": true, "flammable": false},
	WATER: {"grip": 0.5, "speed": 0.5, "slide": 1.0, "cost": -1.0, "solid": false, "flammable": false},
	PLANK: {"grip": 1.0, "speed": 1.0, "slide": 1.0, "cost": 1.0, "solid": true, "flammable": true},
	BOG: {"grip": 0.8, "speed": 0.55, "slide": 0.6, "cost": 3.0, "solid": true, "flammable": true},
	BURNING: {"grip": 1.0, "speed": 0.8, "slide": 1.0, "cost": 6.0, "solid": true, "flammable": false},
	ASH: {"grip": 1.0, "speed": 1.1, "slide": 1.0, "cost": 1.0, "solid": true, "flammable": false},
	WALL_ICE: {"grip": 1.0, "speed": 1.0, "slide": 1.0, "cost": -1.0, "solid": false, "flammable": false},
}
## Knockback slides this much further on ice.
const KNOCK_SLIDE := 1.8

var w := W
var h := H
var origin := ORIGIN
var kind := PackedByteArray()
## Seconds left before the cell changes: a thin-ice fuse, water, burn or ash timer.
var timer := PackedFloat32Array()
## > 0: fire will enter this cell when it reaches 0 (the telegraph).
var warn := PackedFloat32Array()
## Cells with a running timer or warning, so a quiet map costs nothing.
var _active := {}


static func make(w_ := W, h_ := H, origin_ := ORIGIN) -> RefCounted:
	var t: RefCounted = load("res://src/hunt/terrain.gd").new()
	t.w = w_
	t.h = h_
	t.origin = origin_
	t.kind.resize(w_ * h_)
	t.timer.resize(w_ * h_)
	t.warn.resize(w_ * h_)
	return t


## A map from text rows (row 0 is the lowest z). '.' dry, ',' ice, 't' thin ice,
## '~' water, 'p' plank, 'b' bog, '#' ice wall, ':' ash. For tests and layouts.
static func parse(rows: Array, origin_ := ORIGIN) -> RefCounted:
	var t := make(str(rows[0]).length(), rows.size(), origin_)
	var key := {".": DRY, ",": ICE, "t": THIN_ICE, "~": WATER, "p": PLANK, "b": BOG, "#": WALL_ICE, ":": ASH}
	for z in rows.size():
		for x in str(rows[z]).length():
			t.set_kind(Vector2i(x, z), int(key[str(rows[z])[x]]))
	return t


## Paints a noisy ellipse (centre cx, cz; radii rx, rz) with `k`. `only` >= 0 limits it
## to cells of that kind; `noise` roughens the edge. For zone layouts.
func fill_ellipse(k: int, cx: float, cz: float, rx: float, rz: float, only := -1, noise := 0.0, seed_ := 1) -> void:
	var n := FastNoiseLite.new()
	n.seed = seed_
	n.frequency = 0.16
	for z in h:
		for x in w:
			var c := Vector2i(x, z)
			if only >= 0 and kind_of(c) != only:
				continue
			var o := center_of(c)
			var d := Vector2((o.x - cx) / rx, (o.z - cz) / rz).length() + n.get_noise_2d(o.x, o.z) * noise
			if d <= 1.0:
				set_kind(c, k)


## Paints a one-cell-wide path from a to b (x, z) with `k`, stepping through shared
## edges so the cells touch end to end. Cells of a kind in `keep` are left alone.
func fill_line(k: int, a: Vector2, b: Vector2, keep: Array = []) -> void:
	var c := cell_of(Vector3(a.x, 0, a.y))
	var e := cell_of(Vector3(b.x, 0, b.y))
	var total := e - c
	var cells: Array[Vector2i] = [c]
	while c != e:
		var d := e - c
		# Take the step on the axis with the larger share of its way still to go.
		var fx := absf(float(d.x)) / maxf(absf(float(total.x)), 1.0)
		var fz := absf(float(d.y)) / maxf(absf(float(total.y)), 1.0)
		if d.y == 0 or (d.x != 0 and fx >= fz):
			c.x += signi(d.x)
		else:
			c.y += signi(d.y)
		cells.append(c)
	for q in cells:
		if in_bounds(q) and not keep.has(kind_of(q)):
			set_kind(q, k)


func idx(c: Vector2i) -> int:
	return c.y * w + c.x


func in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < w and c.y < h


func cell_of(p: Vector3) -> Vector2i:
	return Vector2i(floori((p.x - origin.x) / CELL), floori((p.z - origin.y) / CELL))


func center_of(c: Vector2i) -> Vector3:
	return Vector3(origin.x + (float(c.x) + 0.5) * CELL, 0.0, origin.y + (float(c.y) + 0.5) * CELL)


func kind_of(c: Vector2i) -> int:
	return int(kind[idx(c)]) if in_bounds(c) else DRY


func kind_at(p: Vector3) -> int:
	return kind_of(cell_of(p))


func set_kind(c: Vector2i, k: int, t := 0.0) -> void:
	if not in_bounds(c):
		return
	var i := idx(c)
	kind[i] = k
	timer[i] = t
	warn[i] = 0.0
	if t > 0.0:
		_active[i] = true
	else:
		_active.erase(i)


func surface(k: int) -> Dictionary:
	return SURFACE[k]


func surface_at(p: Vector3) -> Dictionary:
	return SURFACE[kind_at(p)]


## True while the cell is a warned neighbour: fire will arrive within STEP.
func warned(c: Vector2i) -> bool:
	return in_bounds(c) and warn[idx(c)] > 0.0


func is_cracking(c: Vector2i) -> bool:
	return kind_of(c) == THIN_ICE and timer[idx(c)] > 0.0


## Cost of crossing p for the arena's flow field; -1 means blocked.
func flow_cost(p: Vector3) -> float:
	return float(surface_at(p)["cost"])


## The ground acceleration a body gets: `base` (60 on foot) scaled by the grip.
func accel_at(p: Vector3, base: float) -> float:
	return base * float(surface_at(p)["grip"])


func speed_mult_at(p: Vector3) -> float:
	return float(surface_at(p)["speed"])


## How far a knockback or a dash carries from here, relative to dry ground.
func slide_at(p: Vector3) -> float:
	return float(surface_at(p)["slide"])


# --- Changes the game makes -------------------------------------------------

## Fire starts here. Only bog and planks catch; returns whether it took.
func ignite(c: Vector2i) -> bool:
	if not in_bounds(c) or not bool(SURFACE[kind_of(c)]["flammable"]):
		return false
	var i := idx(c)
	if int(kind[i]) == PLANK:
		_was_plank[i] = true
	kind[i] = BURNING
	timer[i] = BURN_TIME
	warn[i] = 0.0
	_active[i] = true
	_ev.append({"ev": "ignite", "cell": c})
	_warn_neighbours(c)
	return true


## Ignites every flammable cell whose centre is within r of p.
func ignite_at(p: Vector3, r: float) -> int:
	var n := 0
	var reach := ceili(r / CELL)
	var c0 := cell_of(p)
	for dz in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			var c := c0 + Vector2i(dx, dz)
			if in_bounds(c) and center_of(c).distance_to(Vector3(p.x, 0, p.z)) <= r + CELL * 0.5 and ignite(c):
				n += 1
	return n


## A Rime Seer's or a Yeti's blow turns solid ice to thin ice. Returns whether it took.
func thin(c: Vector2i) -> bool:
	if kind_of(c) != ICE:
		return false
	set_kind(c, THIN_ICE)
	_ev.append({"ev": "thin", "cell": c})
	return true


## A Sporecap rots a plank to bog.
func rot(c: Vector2i) -> bool:
	if kind_of(c) != PLANK:
		return false
	set_kind(c, BOG)
	return true


## An ice wall breaks (dash, hit, super): the cell becomes solid ice.
func break_wall(c: Vector2i) -> bool:
	if kind_of(c) != WALL_ICE:
		return false
	set_kind(c, ICE)
	return true


## Starts the fuse under a walker. Safe to call every tick: a running fuse is kept.
func stand(c: Vector2i, mass: float, flying := false) -> void:
	if flying or mass < CRACK_MASS or kind_of(c) != THIN_ICE:
		return
	var i := idx(c)
	if timer[i] <= 0.0:
		timer[i] = SNAP_DELAY
		_active[i] = true


## What this cell does to a body standing in it right now. `lethal` (foes in open
## water), `chill` (hero in water), `dps` (burning), plus the surface's own
## `speed` and `grip`. Flyers feel nothing.
func body_effect(p: Vector3, flying := false) -> Dictionary:
	var k := kind_at(p)
	var out := {"kind": k, "lethal": false, "chill": false, "dps": 0.0, "speed": 1.0, "grip": 1.0}
	if flying:
		return out
	var s: Dictionary = SURFACE[k]
	out["speed"] = float(s["speed"])
	out["grip"] = float(s["grip"])
	if k == WATER:
		out["lethal"] = true
		out["chill"] = true
	elif k == BURNING:
		out["dps"] = BURN_DPS
	return out


## The centre of the nearest solid cell to p that is not bog, fire or thin ice: where the chilled hero
## is dragged to. A ring search out to 6 cells; falls back to p.
func nearest_safe(p: Vector3) -> Vector3:
	var c0 := cell_of(p)
	for ring in range(1, 7):
		var best := Vector3.ZERO
		var best_d := INF
		for dz in range(-ring, ring + 1):
			for dx in range(-ring, ring + 1):
				if maxi(absi(dx), absi(dz)) != ring:
					continue
				var c := c0 + Vector2i(dx, dz)
				if not in_bounds(c):
					continue
				var k := kind_of(c)
				if bool(SURFACE[k]["solid"]) and k != BURNING and k != BOG and k != THIN_ICE:
					var d := center_of(c).distance_to(p)
					if d < best_d:
						best_d = d
						best = center_of(c)
		if best_d < INF:
			return best
	return p


## Cells with a running fuse, warning or timer (the ones that need repainting).
func active() -> Array:
	return _active.keys()


# --- Time ---------------------------------------------------------------------

## Advances every running timer. Returns the events this tick, for the arena to
## draw and play: {"ev": "thin"|"snap"|"refreeze"|"warn"|"ignite"|"burnt"|"fell"|"flood", "cell": Vector2i}.
func step(dt: float) -> Array:
	for i: int in _active.keys():
		var c := Vector2i(i % w, i / w)
		if warn[i] > 0.0:
			warn[i] -= dt
			if warn[i] <= 0.0:
				warn[i] = 0.0
				ignite(c)
			continue
		if timer[i] <= 0.0:
			_active.erase(i)
			continue
		timer[i] -= dt
		if timer[i] > 0.0:
			continue
		timer[i] = 0.0
		match int(kind[i]):
			THIN_ICE:
				set_kind(c, WATER, WATER_TIME)
				_ev.append({"ev": "snap", "cell": c})
			WATER:
				set_kind(c, ICE)
				_ev.append({"ev": "refreeze", "cell": c})
			BURNING:
				if _was_plank.has(i):
					_was_plank.erase(i)
					set_kind(c, BOG)
					_ev.append({"ev": "fell", "cell": c})
				else:
					set_kind(c, ASH, ASH_TIME)
					_ev.append({"ev": "burnt", "cell": c})
			ASH:
				set_kind(c, BOG)
				_ev.append({"ev": "flood", "cell": c})
	var out := _ev
	_ev = []
	return out


## Events since the last step; `step` hands them out.
var _ev: Array = []
## Cells that were planks when they caught: they fall into bog, not ash.
var _was_plank := {}


func _warn_neighbours(c: Vector2i) -> void:
	for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var n := c + d
		if in_bounds(n) and bool(SURFACE[kind_of(n)]["flammable"]) and warn[idx(n)] <= 0.0:
			warn[idx(n)] = STEP
			_active[idx(n)] = true
			_ev.append({"ev": "warn", "cell": n})
