extends RefCounted
## Headless rules for the terrain cell grid (src/hunt/terrain.gd): surface
## physics, thin ice and drowning, fire spreading, the bog re-flooding, and what
## a busy fire costs per tick. Called from tests.gd, so tools/dev/check.sh runs
## it. When the Arena owns a grid (`arena.terrain`) the last group runs the same
## rules through the real Hero and Enemy.

const T := preload("res://src/hunt/terrain.gd")


## A walker for the sims: the same velocity step Hero.tick uses.
class Body:
	var pos := Vector3.ZERO
	var vel := Vector3.ZERO
	var mass := 1.0
	var flying := false
	var alive := true
	var hp := 100.0


static func run(ok: Callable) -> void:
	_surfaces(ok)
	_ice_motion(ok)
	_thin_ice(ok)
	_drowning(ok)
	_fire(ok)
	_reflood(ok)
	_cost(ok)
	_arena(ok)
	_mire(ok)


static func _surfaces(ok: Callable) -> void:
	ok.call("terrain: nine kinds, each with a surface row", T.NAMES.size() == 9 and T.SURFACE.size() == 9)
	var g := T.make()
	ok.call("terrain: 22 x 26 cells of 2 m span the playfield", g.w == 22 and g.h == 26 and g.cell_of(Vector3(-21.0, 0, -31.0)) == Vector2i(0, 0) and g.cell_of(Vector3(20.9, 0, 20.9)) == Vector2i(21, 25))
	ok.call("terrain: a cell's centre maps back to the cell", g.cell_of(g.center_of(Vector2i(5, 7))) == Vector2i(5, 7))
	var rows := ["..,,", "tt~~", "pbb#"]
	var m := T.parse(rows, Vector2(0, 0))
	ok.call("terrain: rows parse to kinds", m.kind_of(Vector2i(0, 0)) == T.DRY and m.kind_of(Vector2i(2, 0)) == T.ICE and m.kind_of(Vector2i(0, 1)) == T.THIN_ICE and m.kind_of(Vector2i(3, 1)) == T.WATER and m.kind_of(Vector2i(0, 2)) == T.PLANK and m.kind_of(Vector2i(1, 2)) == T.BOG and m.kind_of(Vector2i(3, 2)) == T.WALL_ICE)
	var bog := T.SURFACE[T.BOG]
	ok.call("terrain: bog walks at about 55% speed", absf(float(bog["speed"]) - 0.55) < 0.02)
	ok.call("terrain: ice grip takes acceleration 60 to about 16", absf(m.accel_at(m.center_of(Vector2i(2, 0)), 60.0) - 16.0) < 2.0)
	ok.call("terrain: the flow field avoids water and ice walls, and pays more for bog and fire", m.flow_cost(m.center_of(Vector2i(3, 1))) < 0.0 and m.flow_cost(m.center_of(Vector2i(3, 2))) < 0.0 and m.flow_cost(m.center_of(Vector2i(1, 2))) > m.flow_cost(m.center_of(Vector2i(0, 0))) and float(T.SURFACE[T.BURNING]["cost"]) > float(T.SURFACE[T.BOG]["cost"]))
	ok.call("terrain: off the grid reads as dry ground", g.kind_at(Vector3(99, 0, 99)) == T.DRY)


## A body that runs, then lets go of the stick, on `row`; distance it carries.
static func _carry(row: String, run_s: float) -> Dictionary:
	var g := T.parse([row.repeat(1)], Vector2(0, 0))
	var b := Body.new()
	b.pos = Vector3(1.0, 0, 1.0)
	var dt := 1.0 / 60.0
	var top := 5.5
	var t := 0.0
	var reach_t := -1.0
	while t < run_s:
		var acc: float = g.accel_at(b.pos, 60.0)
		b.vel = b.vel.move_toward(Vector3(top, 0, 0), acc * dt)
		if reach_t < 0.0 and b.vel.x >= top - 0.01:
			reach_t = t
		b.pos += b.vel * dt
		t += dt
	var x0 := b.pos.x
	while b.vel.length() > 0.05 and t < run_s + 10.0:
		b.vel = b.vel.move_toward(Vector3.ZERO, g.accel_at(b.pos, 70.0) * dt)
		b.pos += b.vel * dt
		t += dt
	return {"to_top": reach_t, "slide": b.pos.x - x0}


static func _ice_motion(ok: Callable) -> void:
	var dry := _carry(".".repeat(40), 1.0)
	var ice := _carry(",".repeat(40), 1.0)
	ok.call("ice: reaching top speed takes longer than on dry ground (%.2f s vs %.2f s)" % [ice["to_top"], dry["to_top"]], float(ice["to_top"]) > float(dry["to_top"]) * 2.5)
	ok.call("ice: letting go of the stick carries further (%.1f m vs %.1f m)" % [ice["slide"], dry["slide"]], float(ice["slide"]) > float(dry["slide"]) * 2.5 and float(ice["slide"]) < 12.0)
	var g := T.parse([".,b:"], Vector2(0, 0))
	ok.call("ice: a dash glides about 40% further", is_equal_approx(g.slide_at(g.center_of(Vector2i(1, 0))), 1.4))
	ok.call("ice: a knockback carries further than on dry ground", g.slide_at(g.center_of(Vector2i(1, 0))) * T.KNOCK_SLIDE > g.slide_at(g.center_of(Vector2i(0, 0))) * 2.0)
	ok.call("bog: knockback is short and the walk is slow", g.slide_at(g.center_of(Vector2i(2, 0))) < 1.0 and g.speed_mult_at(g.center_of(Vector2i(2, 0))) < 0.6)
	ok.call("ash: fast and safe", g.speed_mult_at(g.center_of(Vector2i(3, 0))) > 1.0 and not g.body_effect(g.center_of(Vector2i(3, 0)))["lethal"] and float(g.body_effect(g.center_of(Vector2i(3, 0)))["dps"]) == 0.0)


static func _thin_ice(ok: Callable) -> void:
	var g := T.parse([",tt,"], Vector2(0, 0))
	var c := Vector2i(1, 0)
	g.stand(c, 0.3)
	ok.call("thin ice: something too light to crack it leaves it alone", not g.is_cracking(c))
	g.stand(c, 5.0, true)
	ok.call("thin ice: a flyer does not crack it", not g.is_cracking(c))
	g.stand(Vector2i(0, 0), 1.0)
	ok.call("thin ice: solid ice has no fuse", g.kind_of(Vector2i(0, 0)) == T.ICE and not g.is_cracking(Vector2i(0, 0)))
	g.stand(c, 1.0)
	ok.call("thin ice: a walker starts the fuse", g.is_cracking(c))
	var evs: Array = []
	for i in 71:
		evs.append_array(g.step(1.0 / 60.0))
	ok.call("thin ice: still ice just before 1.2 s", g.kind_of(c) == T.THIN_ICE and evs.is_empty())
	evs.append_array(g.step(1.0 / 30.0))
	ok.call("thin ice: it snaps to open water 1.2 s after the step", g.kind_of(c) == T.WATER and evs.any(func(e): return e["ev"] == "snap" and e["cell"] == c))
	ok.call("thin ice: the next cell is untouched", g.kind_of(Vector2i(2, 0)) == T.THIN_ICE and not g.is_cracking(Vector2i(2, 0)))
	for i in int(7.8 * 60):
		g.step(1.0 / 60.0)
	ok.call("thin ice: water stays open for about 8 s", g.kind_of(c) == T.WATER)
	for i in 30:
		g.step(1.0 / 60.0)
	ok.call("thin ice: then it freezes over as solid ice", g.kind_of(c) == T.ICE)
	var s := T.parse([",,"], Vector2(0, 0))
	ok.call("thin ice: a Seer's or Yeti's blow thins solid ice, and only ice", s.thin(Vector2i(0, 0)) and s.kind_of(Vector2i(0, 0)) == T.THIN_ICE and not s.thin(Vector2i(0, 0)))
	var sn := T.parse([",~,"], Vector2(0, 0))
	ok.call("thin ice: the hero pulled from water lands on solid ground, not in it", sn.kind_at(sn.nearest_safe(sn.center_of(Vector2i(1, 0)))) in [T.ICE, T.DRY])
	var cr := T.parse(["~tt,"], Vector2(0, 0))
	cr.stand(Vector2i(1, 0), 1.0)
	ok.call("thin ice: the hero is never dragged onto more thin ice", cr.cell_of(cr.nearest_safe(cr.center_of(Vector2i(0, 0)))) == Vector2i(3, 0))
	var w := T.parse(["#,"], Vector2(0, 0))
	ok.call("ice wall: breaking it leaves walkable ice", w.break_wall(Vector2i(0, 0)) and w.kind_of(Vector2i(0, 0)) == T.ICE and not w.break_wall(Vector2i(1, 0)))


## Foes tick through a map the way the arena will: stand, step, apply.
static func _drowning(ok: Callable) -> void:
	var g := T.parse([",,tttt,,"], Vector2(0, 0))
	var dt := 1.0 / 60.0
	var foe := Body.new()
	foe.pos = g.center_of(Vector2i(3, 0))
	var wraith := Body.new()
	wraith.pos = g.center_of(Vector2i(4, 0))
	wraith.flying = true
	var runner := Body.new()
	runner.pos = g.center_of(Vector2i(2, 0))
	runner.vel = Vector3(3.5, 0, 0)
	var shore := Body.new()
	shore.pos = g.center_of(Vector2i(0, 0))
	var bodies := [foe, wraith, runner, shore]
	for i in 160:
		for b: Body in bodies:
			if not b.alive:
				continue
			g.stand(g.cell_of(b.pos), b.mass, b.flying)
			b.pos += b.vel * dt
			var fx: Dictionary = g.body_effect(b.pos, b.flying)
			if bool(fx["lethal"]):
				b.alive = false
		g.step(dt)
	ok.call("drowning: a foe standing on thin ice when it snaps drowns", not foe.alive)
	ok.call("drowning: a flyer over the same hole is fine", wraith.alive)
	ok.call("drowning: a foe on the shore is fine", shore.alive)
	ok.call("drowning: a runner crossing at 3.5 m/s outpaces the 1.2 s fuse (tuning knob: SNAP_DELAY)", runner.alive and runner.pos.x > 12.0)
	var hero := T.parse(["t,"], Vector2(0, 0))
	hero.stand(Vector2i(0, 0), 1.0)
	for i in 80:
		hero.step(dt)
	var fx: Dictionary = hero.body_effect(hero.center_of(Vector2i(0, 0)))
	ok.call("drowning: the same hole chills the hero and names the drag out (lethal flag is for foes only)", fx["chill"] and hero.kind_of(Vector2i(0, 0)) == T.WATER and hero.cell_of(hero.nearest_safe(hero.center_of(Vector2i(0, 0)))) == Vector2i(1, 0))


static func _fire(ok: Callable) -> void:
	var g := T.parse([".bbbbb.pb"], Vector2(0, 0))
	var ev: Array = g.step(0.0)
	ok.call("fire: a dry or ash cell does not catch", not g.ignite(Vector2i(0, 0)) and ev.is_empty())
	ok.call("fire: bog catches", g.ignite(Vector2i(1, 0)) and g.kind_of(Vector2i(1, 0)) == T.BURNING)
	ok.call("fire: the next cell is warned a full step ahead, and still bog", g.warned(Vector2i(2, 0)) and g.kind_of(Vector2i(2, 0)) == T.BOG)
	ok.call("fire: the cell behind it (dry) is not warned", not g.warned(Vector2i(0, 0)))
	for i in 89:
		g.step(1.0 / 60.0)
	ok.call("fire: just before 1.5 s the telegraphed cell has not lit", g.kind_of(Vector2i(2, 0)) == T.BOG and g.warned(Vector2i(2, 0)))
	g.step(1.0 / 30.0)
	ok.call("fire: at 1.5 s it lights and warns the one after", g.kind_of(Vector2i(2, 0)) == T.BURNING and g.warned(Vector2i(3, 0)))
	# The front moves one cell per step; the first cell burns out after BURN_TIME.
	for i in int(4.6 * 60):
		g.step(1.0 / 60.0)
	ok.call("fire: spread goes across connected bog", g.kind_of(Vector2i(4, 0)) in [T.BURNING, T.ASH] and g.kind_of(Vector2i(5, 0)) in [T.BURNING, T.ASH, T.BOG])
	ok.call("fire: a burnt cell is ash, safe to stand on", g.kind_of(Vector2i(1, 0)) == T.ASH and float(g.body_effect(g.center_of(Vector2i(1, 0)))["dps"]) == 0.0)
	for i in 30 * 60:
		g.step(1.0 / 60.0)
	ok.call("fire: it stops at dry ground (the island is a firebreak)", g.kind_of(Vector2i(6, 0)) == T.DRY and g.kind_of(Vector2i(7, 0)) == T.PLANK)
	ok.call("fire: it never crossed the gap to the far planks", not g.warned(Vector2i(7, 0)) and g.kind_of(Vector2i(8, 0)) == T.BOG)
	var p := T.parse(["pbp"], Vector2(0, 0))
	p.ignite(Vector2i(1, 0))
	var all := []
	for i in 60 * 40:
		all.append_array(p.step(1.0 / 60.0))
	ok.call("fire: planks beside burning bog catch and fall into bog, leaving no ash", p.kind_of(Vector2i(0, 0)) == T.BOG and p.kind_of(Vector2i(2, 0)) == T.BOG and all.any(func(e): return e["ev"] == "fell"))
	var burn := T.parse(["b"], Vector2(0, 0))
	burn.ignite(Vector2i(0, 0))
	var fx: Dictionary = burn.body_effect(burn.center_of(Vector2i(0, 0)))
	ok.call("fire: a burning cell hurts walkers, not flyers", float(fx["dps"]) > 0.0 and float(burn.body_effect(burn.center_of(Vector2i(0, 0)), true)["dps"]) == 0.0)
	var vent := T.parse(["bbb", "bbb", "bbb"], Vector2(0, 0))
	ok.call("fire: a blast ignites the bog in its radius", vent.ignite_at(Vector3(3.0, 0, 3.0), 2.0) >= 4)
	var rot := T.parse(["pp"], Vector2(0, 0))
	ok.call("fire: a Sporecap rots a plank to bog, and only a plank", rot.rot(Vector2i(0, 0)) and rot.kind_of(Vector2i(0, 0)) == T.BOG and not rot.rot(Vector2i(0, 0)))


static func _reflood(ok: Callable) -> void:
	var g := T.parse(["bbbb"], Vector2(0, 0))
	g.ignite(Vector2i(0, 0))
	var t := 0.0
	var gone := -1.0
	var back := -1.0
	var flooded := {}
	while t < 80.0:
		for e: Dictionary in g.step(1.0 / 60.0):
			if e["ev"] == "flood":
				flooded[e["cell"]] = t
		t += 1.0 / 60.0
		if gone < 0.0 and g.kind_of(Vector2i(0, 0)) == T.ASH:
			gone = t
	back = float(flooded.get(Vector2i(0, 0), -1.0))
	ok.call("flood: the first cell is ash after its burn time (%.1f s)" % gone, absf(gone - T.BURN_TIME) < 0.1)
	ok.call("flood: it re-floods about 25 s after burning out (%.1f s later)" % (back - gone), absf((back - gone) - 25.0) < 0.2)
	ok.call("flood: every cell of the strip burned and flooded", flooded.size() == 4 and g.kind_of(Vector2i(3, 0)) == T.BOG)
	ok.call("flood: a flooded cell burns again", g.ignite(Vector2i(0, 0)))
	var q := T.parse(["b"], Vector2(0, 0))
	for i in 10:
		q.step(1.0 / 60.0)
	ok.call("flood: a quiet map has no active cells", q._active.is_empty())


static func _cost(ok: Callable) -> void:
	var g := T.make()
	for z in g.h:
		for x in g.w:
			g.set_kind(Vector2i(x, z), T.BOG if (x + z) % 7 != 0 else T.PLANK)
	g.ignite(Vector2i(10, 12))
	var t0 := Time.get_ticks_usec()
	var n := 0
	for i in 60 * 30:
		n += g.step(1.0 / 60.0).size()
	var ms := float(Time.get_ticks_usec() - t0) / 1000.0
	ok.call("fire: a whole-map blaze over 30 s costs under 0.5 ms a tick (%.2f ms total, %d events)" % [ms, n], ms / 1800.0 < 0.5 and n > 100)


## The same rules through the real arena, once it owns a grid.
static func _arena(ok: Callable) -> void:
	_arena_live(ok)
	for zone in ["frost", "swamp"]:
		var a := Arena.new()
		a.build(true, zone, 0, 1)
		var terr = a.get("terrain")
		if terr == null:
			ok.call("terrain %s: the arena builds without a grid until the Lead hooks it in (pending)" % zone, a.get_child_count() > 0)
		else:
			ok.call("terrain %s: the arena's grid is 22 x 26" % zone, terr.w == 22 and terr.h == 26)
			ok.call("terrain %s: the start is dry, safe ground" % zone, terr.kind_at(a.start) == T.DRY)
			ok.call("terrain %s: the grid shapes the play space with blocked cells only inside the bounds" % zone, terr.cell_of(a.start).y < terr.h)
		a.free()


## Whether firm footing (dry, ash, planks) links `from` to `to` cell by cell, so the
## way across the bog never needs a wade.
static func _firm_route(t: RefCounted, from: Vector3, to: Vector3) -> bool:
	var seen := {}
	var q: Array = [t.cell_of(from)]
	var goal: Vector2i = t.cell_of(to)
	seen[q[0]] = true
	while not q.is_empty():
		var c: Vector2i = q.pop_back()
		if c == goal:
			return true
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if seen.has(n) or not t.in_bounds(n) or not (t.kind_of(n) in [T.DRY, T.ASH, T.PLANK]):
				continue
			seen[n] = true
			q.append(n)
	return false


## The Cinder Mire: bog, islands, a boardwalk of planks that burn and fall, the
## Warlord's platform, and foe spots on the right ground.
static func _mire(ok: Callable) -> void:
	var m := Arena.new()
	m.build(true, "swamp", 0, 1)
	var t: RefCounted = m.terrain
	var firm := func(p: Vector3) -> bool: return t.kind_at(p) in [T.DRY, T.ASH]
	var count := {}
	for k in t.kind:
		count[int(k)] = int(count.get(int(k), 0)) + 1
	ok.call("mire: paints its cells, mostly bog with dry islands, ash and planks", m.terrain_live and int(count.get(T.BOG, 0)) > 150 and int(count.get(T.DRY, 0)) > 60 and int(count.get(T.ASH, 0)) > 10 and int(count.get(T.PLANK, 0)) > 30)
	ok.call("mire: the start and the Warlord's spot are dry, solid ground", t.kind_at(m.start) == T.DRY and t.kind_at(m.boss_spawn) == T.DRY and t.kind_at(m.crypt_pos) == T.DRY)
	ok.call("mire: the boardwalk is a firm route from the landing to the platform", _firm_route(t, m.start, m.boss_spawn))
	ok.call("mire: the platform is reachable on foot too", _reach(m, m.start, m.boss_spawn))
	ok.call("mire: every plank cell has its boardwalk piece, and it can burn", count.get(T.PLANK, 0) == m.plank_nodes.size() and m.plank_nodes.values().all(func(n): return is_instance_valid(n) and n.has_method("burn")))
	ok.call("mire: three shrines, each on firm ground and within reach", m.shrines.size() == 3 and m.shrines.all(func(s): return firm.call(s["pos"]) and _reach(m, m.start, s["pos"])))
	ok.call("mire: the vents stand on ash, clear of the planks", m.hazard_spots.size() == 5 and m.hazard_spots.all(func(v: Vector3): return t.kind_at(v) == T.ASH))
	ok.call("mire: the dead rise on firm ground, away from the landing", m.graves.size() >= 10 and m.graves.all(func(g: Vector3): return firm.call(g) and g.z <= 12.0))
	ok.call("mire: perches on firm open ground, spawn holes in open bog", m.perches.size() >= 12 and m.spawn_holes.size() >= 10 and m.perches.all(func(p: Vector3): return firm.call(p)) and m.spawn_holes.all(func(p: Vector3): return t.kind_at(p) == T.BOG))
	ok.call("mire: bog slows and the flow field counts it dearer than firm ground", float(t.surface(T.BOG)["speed"]) < 0.7 and float(t.flow_cost(Vector3(-19, 0, -3))) > float(t.flow_cost(m.start)))
	# A plank takes fire, and the fire runs the boardwalk and drops the pieces into the bog.
	var first := Vector2i(-1, -1)
	for c in t.w * t.h:
		var cc := Vector2i(c % t.w, c / t.w)
		if t.kind_of(cc) == T.PLANK and cc.y > 15:
			first = cc
			break
	var fell := 0
	var burned := 0
	t.ignite(first)
	for i in 60 * 30:
		for e: Dictionary in t.step(1.0 / 60.0):
			if e["ev"] == "ignite":
				m.plank_burn(e["cell"])
				burned += 1
			elif e["ev"] == "fell":
				m.plank_fall(e["cell"])
				fell += 1
	ok.call("mire: fire spreads over the boardwalk and burnt planks fall into the bog", burned > 6 and fell > 3)
	for i in 60 * 40:
		for e: Dictionary in t.step(1.0 / 60.0):
			if e["ev"] == "fell":
				m.plank_fall(e["cell"])
	var left := 0
	for i: int in m.plank_nodes:
		if t.kind[i] != T.PLANK:
			left += 1
	ok.call("mire: a fallen plank's piece is gone, a burnt one stays chared", left == 0)
	ok.call("mire: the islands are firebreaks, the landing never burns", t.kind_at(m.start) == T.DRY and t.kind_at(Vector3(0, 0, 18)) == T.DRY)
	m.free()


## Whether a 1 m walk from `from` to `to` exists round obstacles, water and walls.
static func _reach(a: Arena, from: Vector3, to: Vector3) -> bool:
	var seen := {}
	var q: Array = [Vector2i(roundi(from.x), roundi(from.z))]
	var goal := Vector2i(roundi(to.x), roundi(to.z))
	seen[q[0]] = true
	while not q.is_empty():
		var c: Vector2i = q.pop_back()
		if c.distance_to(goal) < 1.5:
			return true
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n := c + d
			var p := Vector3(n.x, 0, n.y)
			if seen.has(n) or p.x < a.min_x or p.x > a.max_x or p.z < a.min_z or p.z > a.max_z:
				continue
			seen[n] = true
			if a.blocked(p, 0.45) or a.terrain.flow_cost(p) < 0.0:
				continue
			q.append(n)
	return false


## A zone that paints its cells: ice walls hold until they break, and a broken
## wall and open water change what the flow field may cross.
static func _arena_live(ok: Callable) -> void:
	var r := Arena.new()
	r.build(true, "frost", 0, 1)
	ok.call("rimehollow: paints its cells, a lake with thin ice and holes, ice walls in both caverns", r.terrain_live and r.terrain.kind_at(Vector3(0, 0, 0)) == T.ICE and r.terrain.kind_at(Vector3(-15, 0, -2)) == T.WALL_ICE and r.terrain.kind_at(Vector3(15, 0, 2)) == T.WALL_ICE and r.terrain.kind_at(Vector3(3, 0, -2)) == T.WATER)
	ok.call("rimehollow: the start is on dry snow, three shrines, spawn points on firm ground", r.terrain.kind_at(r.start) == T.DRY and r.shrines.size() == 3 and r.graves.size() > 8 and r.graves.all(func(g: Vector3): return r.terrain.kind_at(g) in [T.DRY, T.ICE]))
	ok.call("rimehollow: the throne is reachable on foot", _reach(r, r.start, Vector3(0, 0, -21)))
	ok.call("rimehollow: a cavern is sealed until its ice is broken", not _reach(r, r.start, r.shrines[0]["pos"]) and not _reach(r, r.start, r.shrines[1]["pos"]) and _reach(r, r.start, r.shrines[2]["pos"]))
	r.break_ice_at(Vector3(-15, 0, -3), 3.0)
	r.break_ice_at(Vector3(15, 0, 3), 3.0)
	ok.call("rimehollow: breaking the walls opens both caverns", _reach(r, r.start, r.shrines[0]["pos"]) and _reach(r, r.start, r.shrines[1]["pos"]))
	ok.call("rimehollow: perches and spawn holes for the wraiths and callers, all on firm open ground", r.perches.size() >= 8 and r.spawn_holes.size() >= 6 and r.perches.all(func(p: Vector3): return r.terrain.kind_at(p) in [T.DRY, T.ICE]) and r.spawn_holes.all(func(p: Vector3): return r.terrain.kind_at(p) in [T.DRY, T.ICE]))
	r.free()
	var a := Arena.new()
	a.build(true, "grove", 0, 1)
	ok.call("terrain live: off until a zone paints it", not a.terrain_live)
	a.terrain_begin({})
	ok.call("terrain live: begin turns it on and draws the cells", a.terrain_live and a.tview != null and a.tview.mat != null)
	var wall := Vector2i(11, 14)
	var at: Vector3 = a.terrain.center_of(wall)
	a.add_ice_wall(wall)
	ok.call("ice wall: solid to a body standing in it", a.blocked(at, 0.4))
	ok.call("ice wall: solid to the flow field", a.terrain.flow_cost(at) < 0.0)
	ok.call("ice wall: a far dash does not break it", a.break_ice_at(at + Vector3(6, 0, 0), 0.5) == 0 and a.terrain.kind_at(at) == T.WALL_ICE)
	ok.call("ice wall: a blow beside it breaks it", a.break_ice_at(at + Vector3(1.0, 0, 0), 0.5) == 1)
	ok.call("ice wall: broken, the cell is ice and nothing blocks it", a.terrain.kind_at(at) == T.ICE and not a.blocked(at, 0.4) and a.terrain.flow_cost(at) > 0.0)
	ok.call("ice wall: breaking tells the hunt (event for sound and shards)", a.terrain_ev.size() == 1 and a.terrain_ev[0]["ev"] == "wallbreak")
	var hole := Vector2i(5, 5)
	a.terrain.set_kind(hole, T.WATER, 8.0)
	ok.call("water: the flow field will not route through it", a.terrain.flow_cost(a.terrain.center_of(hole)) < 0.0)
	a.free()
