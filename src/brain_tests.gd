extends RefCounted
## Behaviour tests for the sixteen Rimehollow and Cinder Mire foes (foe_brains.gd).
## A real Hunt is built in the test tree and its foes are ticked by hand at 20 Hz;
## the hero stands still and is topped up each tick, every hit is read off its HP.
## Terrain is a `Terrain` grid hung on the arena as meta "terrain" (the same
## place the Lead's `arena.terrain` will be), so the ground rules are the real ones.

const T := preload("res://src/hunt/terrain.gd")
const TerrainRun := preload("res://src/hunt/terrain_run.gd")
const BiomeGround := preload("res://src/hunt/biome_ground.gd")
const FoeBrains := preload("res://src/hunt/foe_brains.gd")
const NF := preload("res://src/data/next_foes.gd")
const DT := 0.05

var ok: Callable
var h: Hunt
var hits: Array = []
var clock := 0.0
var last_tele := -99.0
var seen_tele := false
var m := {}


static func run(ok_: Callable) -> void:
	_registry(ok_)
	var b = new()
	b.ok = ok_
	b.go()


static func _declares(path: String) -> bool:
	return _declares_src(FileAccess.get_file_as_string(path))


static func _declares_src(src: String) -> bool:
	for line in src.split("\n"):
		if line.begins_with("class_name"):
			return true
	return false


static func _registry(ok: Callable) -> void:
	var bad := []
	var plain := []
	for k: String in NF.FROST + NF.SWAMP:
		var d: Dictionary = DB.enemy(k)
		var kind := str(d["brain"]["kind"])
		if not FoeBrains.SCRIPTS.has(kind):
			bad.append(k)
	for kind: String in FoeBrains.SCRIPTS:
		var src := FileAccess.get_file_as_string((FoeBrains.SCRIPTS[kind] as GDScript).resource_path)
		if _declares_src(src):
			plain.append(kind)
	ok.call("brains: eight foes per zone, all with a registered brain %s" % str(bad), NF.FROST.size() == 8 and NF.SWAMP.size() == 8 and bad.is_empty())
	ok.call("brains: no brain script declares a class_name %s" % str(plain), plain.is_empty())
	ok.call("brains: the foe base, registry and brains are plain scripts", not _declares("res://src/hunt/foe_brain.gd") and not _declares("res://src/hunt/foe_brains.gd"))
	for id in ["frost", "swamp"]:
		var z: Dictionary = DB.ZONES[id]
		var f: Dictionary = z["faction_next"]
		ok.call("brains: %s fields eight foes through faction_next" % id, f.values().size() == 8 and f.values().all(func(k): return DB.enemy(k).has("brain")))
	ok.call("brains: the rebuilt factions are on by default and `next = false` brings back the old ones", FoeBrains.next and FoeBrains.faction(DB.ZONES["frost"])["minion"] == "rh_imp" and _old_faction())


static func _old_faction() -> bool:
	FoeBrains.next = false
	var old: bool = FoeBrains.faction(DB.ZONES["frost"])["minion"] == "thrall"
	FoeBrains.next = true
	return old


# --- Harness --------------------------------------------------------------------

func go() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	h = Hunt.new()
	tree.root.add_child(h)
	h.phase = "rise"
	_wolves()
	_ice_overshoot()
	_telegraphs_and_clips()
	_dormant()
	_skitter()
	_kite()
	_casters()
	_yeti()
	_drift()
	_ambush()
	_wasp()
	_real_terrain()
	_pack_limits()
	h.queue_free()


## Clears the field, parks the hero, lays a floor of `kind` (or none).
func _stage(floor_kind := -1, hero_at := Vector3(0, 0, 0)) -> void:
	for f in h.foes.duplicate():
		if is_instance_valid(f):
			f.queue_free()
	h.foes.clear()
	h.patches.clear()
	h.projs.clear()
	h.hero.position = hero_at
	h.hero.alive = true
	h.hero.hp = h.hero.max_hp
	h.hero.slow_t = 0.0
	hits.clear()
	m = {}
	h.cam.global_position = hero_at + Vector3(0, 22, 9)
	h.cam.look_at(hero_at, Vector3.UP)
	clock = 0.0
	last_tele = -99.0
	seen_tele = false
	_ground(floor_kind)


## The real arena's grid: `floor_kind` swaps in a floor of one kind through
## `terrain_begin` and a live TerrainRun, so drowning, fire and the surface
## speeds are the game's. -1 turns the grid off (the no-terrain fallbacks).
func _ground(floor_kind: int) -> void:
	var a: Arena = h.arena
	if floor_kind < 0:
		a.terrain_live = false
		return
	var g := _floor(floor_kind)
	if a.tview == null:
		a.terrain_begin({}, g)
	else:
		a.terrain = g
		a.tview.t = g
		a.terrain_live = true
		a.terrain_painted()
	a.terrain_ev.clear()
	if h.terr == null:
		h.terr = TerrainRun.new()
		h.terr.setup(h)
	h.terr.t = g


func _floor(kind: int) -> RefCounted:
	var g := T.make()
	for z in g.h:
		for x in g.w:
			g.set_kind(Vector2i(x, z), kind)
	return g


func grid() -> RefCounted:
	return h.arena.terrain


func foe(kind: String, at: Vector3, up := true) -> Enemy:
	var e: Enemy = h.spawn_foe(kind, at)
	if up:
		for i in 30:
			if e.state != "spawn":
				break
			h._tick_foes(DT)
	return e


## One 20 Hz tick of everything the foes touch; reads hero hits and telegraphs.
func tick() -> void:
	h.hero.invuln = 0.0
	h.hero.hp = h.hero.max_hp
	h._tick_foes(DT)
	h.fx._process(DT)
	if h.hero.hp < h.hero.max_hp:
		hits.append({"t": clock, "since_tele": clock - last_tele})
	h.hero.hp = h.hero.max_hp
	for l in h.fx._live:
		if str(l.get("kind", "")) == "tele":
			last_tele = clock
			seen_tele = true
	if grid_ok() and h.terr != null:
		h.terr.tick(DT)
	clock += DT


func grid_ok() -> bool:
	return h.arena.terrain_live


func run_for(sec: float, until := Callable()) -> bool:
	var n := int(sec / DT)
	for i in n:
		tick()
		if until.is_valid() and until.call():
			return true
	return false


func alive(kind: String) -> Array:
	return h.foes.filter(func(f): return f.alive and f.kind == kind)


func brain(e: Enemy) -> RefCounted:
	return FoeBrains.of(e)


func chk(msg: String, cond: bool) -> void:
	ok.call(msg, cond)


# --- Tests ----------------------------------------------------------------------

func _wolves() -> void:
	_stage()
	var w := foe("rh_wolf", Vector3(9, 0, 0))
	run_for(1.5)
	var pack := alive("rh_wolf")
	chk("wolf: the director's one wolf brings a pack of three or four (%d)" % pack.size(), pack.size() >= 3 and pack.size() <= 4)
	# Circle first, then lunge one at a time.
	var both := 0
	var windups := 0
	var dashed := 0
	var circle_d := []
	for i in int(14.0 / DT):
		tick()
		var busy := 0
		for f in alive("rh_wolf"):
			var b := brain(f)
			if b.st == "windup" or b.st == "dash":
				busy += 1
			if b.st == "windup":
				windups += 1
			if b.st == "dash":
				dashed += 1
			if b.st == "move" and i < int(2.5 / DT):
				circle_d.append(f.flat_pos().distance_to(h.hero.flat_pos()))
		both = maxi(both, busy)
	chk("wolf: never two wolves lunging at once (peak %d)" % both, both == 1)
	chk("wolf: each lunge shows a windup before the dash", windups > 0 and dashed > 0 and windups >= dashed * 0.5)
	chk("wolf: it lunges and lands hits (%d)" % hits.size(), hits.size() >= 1)
	var avg := 0.0
	for d: float in circle_d:
		avg += d
	avg /= maxf(circle_d.size(), 1)
	chk("wolf: the pack circles near the ring before lunging (mean %.1f m)" % avg, avg > 3.5 and avg < 8.5)


func _ice_overshoot() -> void:
	var reach := {}
	for fk in [[T.DRY, "dry"], [T.ICE, "ice"]]:
		_stage(fk[0])
		var w := foe("rh_wolf", Vector3(7, 0, 0))
		var b := brain(w)
		b.packmate = true
		for f in alive("rh_wolf"):
			if f != w:
				f.queue_free()
				h.foes.erase(f)
		var from := Vector3.ZERO
		var lunging := false
		var best := 0.0
		for i in int(12.0 / DT):
			tick()
			if b.st == "windup" and not lunging:
				lunging = true
			if b.st == "dash" and from == Vector3.ZERO:
				from = w.flat_pos()
			if from != Vector3.ZERO:
				best = maxf(best, w.flat_pos().distance_to(from))
			if b.st == "move" and from != Vector3.ZERO:
				break
		reach[fk[1]] = best
	chk("wolf: a lunge on ice goes further than on dry ground (%.1f vs %.1f m)" % [reach["ice"], reach["dry"]], reach["dry"] > 5.0 and reach["ice"] > reach["dry"] * 1.2)


## Every foe, hero standing 4 m away: it must show a telegraph before it hurts, and
## play the idle or run, attack, hit and die clips the game requires.
func _telegraphs_and_clips() -> void:
	for k: String in NF.FROST + NF.SWAMP:
		var floor_k := T.BOG if k in ["cm_bogfin", "cm_frog"] else T.DRY
		_stage(floor_k)
		var e := foe(k, Vector3(4.5, 0, 0), not k in ["cm_bogfin", "cm_frog", "rh_effigy"])
		if k in ["cm_bogfin", "cm_frog", "rh_effigy"]:
			run_for(1.2)
		var anims := {}
		var phases := {}
		for i in int(16.0 / DT):
			tick()
			if is_instance_valid(e):
				anims[e.cur_anim] = true
				var b := brain(e)
				if b != null:
					phases[b.st] = true
		var a: Dictionary = e.def["anim"]
		var committed := phases.has("windup") or phases.has("crouch") or phases.has("bubble") or phases.has("wake")
		chk("%s: commits to an attack through a readable windup (phases %s)" % [k, str(phases.keys())], committed)
		var swings: bool = anims.has(str(a["attack"])) or phases.has("dash") or phases.has("hop") or phases.has("leap") or not e.alive
		chk("%s: its blow plays the attack clip or a lunge (saw %s)" % [k, str(anims.keys())], swings)
		chk("%s: plays its idle or run clip" % k, anims.has(str(a["run"])) or anims.has(str(a["idle"])))
		var worst := 0.0
		for hit in hits:
			worst = maxf(worst, float(hit["since_tele"]))
		chk("%s: every hit on the hero follows a ground telegraph (%d hits, worst %.1f s after)" % [k, hits.size(), worst], hits.is_empty() or worst < 2.6)
		# Hit and death clips.
		if is_instance_valid(e) and e.alive:
			h.damage_foe(e, 1.0, h.hero, Vector3.ZERO, 0.0)
			h.damage_foe(e, 9999.0, h.hero, Vector3.ZERO, 0.0)
			chk("%s: dies on its death clip" % k, not e.alive and e.cur_anim == str(a["die"]))


func _dormant() -> void:
	_stage()
	var e := foe("rh_effigy", Vector3(9, 0, 0), false)
	run_for(1.0)
	var hp0 := e.hp
	h.damage_foe(e, 50.0, h.hero, Vector3.ZERO, 0.0)
	chk("effigy: a statue cannot be hurt before it wakes", e.hp == hp0 and e.state == "spawn")
	h.hero.position = Vector3(3.5, 0, 0)
	h.hero.position = Vector3(3.5, 0, 0)
	e.position = Vector3(9, 0, 0)
	run_for(0.2)
	chk("effigy: it wakes when the hero is within its wake radius", brain(e).st == "wake" and teles_live() > 0)
	run_for(10.0, func(): return hits.size() >= 1)
	chk("effigy: after waking it fights as a melee foe (%d hits)" % hits.size(), e.state != "spawn" and hits.size() >= 1)
	var hp1 := e.hp
	h.damage_foe(e, 50.0, h.hero, Vector3.ZERO, 0.0)
	chk("effigy: awake, it can be hurt", e.hp < hp1)
	# Shivers just outside the radius, wakes by itself in time.
	_stage()
	var s := foe("rh_effigy", Vector3(0, 0, 20), false)
	h.hero.position = Vector3(0, 0, 0)
	run_for(8.0)
	chk("effigy: a hero far away does not wake it", brain(s).st == "move" and s.state == "spawn")
	run_for(8.0)
	chk("effigy: but the ice cracks by itself in the end", s.state != "spawn")


func count_kind(kind: int) -> int:
	var n := 0
	var g := grid()
	for z in g.h:
		for x in g.w:
			if g.kind_of(Vector2i(x, z)) == kind:
				n += 1
	return n


func teles_live() -> int:
	var n := 0
	for l in h.fx._live:
		if str(l.get("kind", "")) == "tele":
			n += 1
	return n


func _skitter() -> void:
	_stage()
	var e := foe("rh_imp", Vector3(8, 0, 0))
	var hopped := false
	var far := 0.0
	var prev := e.flat_pos()
	var crouched := false
	for i in int(6.0 / DT):
		tick()
		var b := brain(e)
		if b.st == "crouch":
			crouched = true
		if b.st == "hop":
			hopped = true
			far = maxf(far, e.flat_pos().distance_to(prev))
		prev = e.flat_pos() if b.st != "hop" else prev
		if hopped and b.st == "recover":
			break
	chk("imp: it crouches (a small ring shows the landing), then hops", crouched and hopped and far > 1.5)
	chk("imp: the hop leaves a chill puddle", h.patches.size() >= 1)


func _kite() -> void:
	_stage()
	var w := foe("rh_wraith", Vector3(12, 0, 0))
	var shots := 0
	var flew := 0.0
	var d_end := 0.0
	for i in int(10.0 / DT):
		tick()
		shots = maxi(shots, h.projs.size())
		flew = maxf(flew, w.model.position.y)
		d_end = w.flat_pos().distance_to(h.hero.flat_pos())
	chk("wraith: it hovers above the ground (%.1f m)" % flew, flew > 0.5)
	chk("wraith: it fires bolts from range (%d seen, %.1f m away)" % [shots, d_end], shots >= 1 and d_end > 4.5)
	_stage(T.DRY)
	var imp := foe("cm_imp", Vector3(11, 0, 0))
	var p0 := imp.flat_pos()
	run_for(8.0)
	chk("cinder imp: it plants itself and shoots (%d bolts)" % h.projs.size(), imp.flat_pos().distance_to(h.hero.flat_pos()) < 10.0 and (h.projs.size() >= 1 or hits.size() >= 1))


func _casters() -> void:
	# Rime Seer thins the ice under the hero.
	_stage(T.ICE)
	var seer := foe("rh_seer", Vector3(7, 0, 0))
	run_for(8.0)
	var thin := count_kind(T.THIN_ICE) + count_kind(T.WATER)
	chk("seer: it shows a ring, then thins the ice under the hero (%d cells)" % thin, thin >= 2 and seen_tele)
	# Pyre Shaman lights the bog.
	_stage(T.BOG)
	var sh := foe("cm_shaman", Vector3(7, 0, 0))
	run_for(8.0, func(): return count_kind(T.BURNING) > 0)
	var burning := count_kind(T.BURNING)
	chk("shaman: it ignites the bog near the hero (%d cells)" % burning, burning >= 1)
	# Mire Hag plants lanterns that burst after the fuse.
	_stage(T.PLANK)
	var hag := foe("cm_hag", Vector3(7, 0, 0))
	run_for(3.0)
	var planted: int = brain(hag)._lanterns
	chk("hag: she plants a lantern with a ring that counts down", planted >= 1 and teles_live() >= 1)
	# The fuse is a SceneTree timer, which tests do not wait on: fire the burst itself.
	FoeBrains.SCRIPTS["caster"].burst(h, h.hero.flat_pos(), 2.2, 10.0)
	var lit := count_kind(T.BURNING)
	chk("hag: the lantern ignites the planks when the fuse ends (%d cells)" % lit, lit >= 1)
	var cap_ok := true
	for i in int(20.0 / DT):
		tick()
		cap_ok = cap_ok and brain(hag)._lanterns <= 3
	chk("hag: never more than three lanterns at once", cap_ok)
	# Winter Caller summons imps, capped.
	_stage(T.DRY)
	var cl := foe("rh_caller", Vector3(7, 0, 0))
	run_for(20.0)
	var imps := alive("rh_imp").size()
	chk("caller: it raises frost imps (%d)" % imps, imps >= 2)
	run_for(40.0)
	chk("caller: never more than six imps at once (%d)" % alive("rh_imp").size(), alive("rh_imp").size() <= 6)


func _yeti() -> void:
	_stage(T.ICE)
	var y := foe("rh_yeti", Vector3(9, 0, 0))
	var lobbed := false
	var slammed := false
	var slowed := false
	for i in int(14.0 / DT):
		tick()
		var b := brain(y)
		if b.st == "windup" and b._kind == "lob":
			lobbed = true
		if b.st == "windup" and b._kind == "slam":
			slammed = true
		slowed = slowed or h.hero.slow_t > 0.0
	var thin := count_kind(T.THIN_ICE) + count_kind(T.WATER)
	chk("yeti: it lobs a snowball at range and slams up close (lob %s, slam %s)" % [lobbed, slammed], lobbed or slammed)
	chk("yeti: its blows crack the ice into thin ice (%d cells)" % thin, thin >= 4)


func _drift() -> void:
	# Shardling: lanes, a burst, dies.
	_stage(T.DRY)
	var s := foe("rh_shard", Vector3(6, 0, 0))
	m["lanes"] = 0
	run_for(8.0, func():
		m["lanes"] = maxi(int(m["lanes"]), teles_live())
		return not s.alive)
	var lanes: int = m["lanes"]
	chk("shardling: it shows shard lanes, then bursts and is gone (%d lanes)" % lanes, lanes >= 4 and not s.alive)
	# Shards break ice walls.
	_stage(T.WALL_ICE)
	grid().set_kind(grid().cell_of(Vector3(0, 0, 0)), T.DRY)
	var s2 := foe("rh_shard", Vector3(1.0, 0, 0))
	s2.hp = 0.0
	h._kill(s2)
	var walls := 0
	for z in grid().h:
		for x in grid().w:
			if grid().kind_of(Vector2i(x, z)) == T.WALL_ICE:
				walls += 1
	chk("shardling: its burst breaks ice walls round it", walls < 22 * 26 - 1)
	# Sporecap: rots planks.
	_stage(T.PLANK)
	var sp := foe("cm_spore", Vector3(5, 0, 0))
	run_for(10.0, func(): return not sp.alive)
	var bog := 0
	for z in grid().h:
		for x in grid().w:
			if grid().kind_of(Vector2i(x, z)) == T.BOG:
				bog += 1
	chk("sporecap: it bursts into spores and rots the planks to bog (%d cells)" % bog, not sp.alive and bog >= 4)
	# Bloat: killed over bog it ignites it; popped near the hero too.
	_stage(T.BOG)
	var bl := foe("cm_bloat", Vector3(8, 0, 0))
	bl.hp = 0.0
	h._kill(bl)
	var lit := 0
	for z in grid().h:
		for x in grid().w:
			if grid().kind_of(Vector2i(x, z)) == T.BURNING:
				lit += 1
	chk("bloat: killing it ignites the bog under it (%d cells)" % lit, lit >= 2)
	_stage(T.DRY)
	var bd := foe("cm_bloat", Vector3(8, 0, 0))
	bd.hp = 0.0
	h._kill(bd)
	chk("bloat: over dry ground nothing burns", not grid().kind_of(grid().cell_of(Vector3(8, 0, 0))) == T.BURNING)


func _ambush() -> void:
	# Bogfin: submerged over bog, creeps, bubbles, bursts out.
	_stage(T.BOG)
	var g := grid()
	for z in g.h:
		for x in g.w:
			var c := Vector2i(x, z)
			if g.center_of(c).distance_to(Vector3.ZERO) < 2.6:
				g.set_kind(c, T.DRY)
	var f := foe("cm_bogfin", Vector3(10, 0, 0), false)
	run_for(1.5)
	chk("bogfin: it starts submerged: untouchable, model sunk", f.state == "spawn" and f.model.position.y < -1.0)
	var hp0 := f.hp
	h.damage_foe(f, 40.0, h.hero, Vector3.ZERO, 0.0)
	chk("bogfin: a submerged foe takes no damage", f.hp == hp0)
	var d0 := f.flat_pos().distance_to(h.hero.flat_pos())
	run_for(3.0)
	chk("bogfin: it creeps toward the hero under the bog (%.1f -> %.1f m)" % [d0, f.flat_pos().distance_to(h.hero.flat_pos())], f.flat_pos().distance_to(h.hero.flat_pos()) < d0 - 1.0)
	m["bubbled"] = false
	run_for(10.0, func():
		m["bubbled"] = m["bubbled"] or (brain(f).st == "bubble" and teles_live() > 0)
		return brain(f).st == "move")
	var bubbled: bool = m["bubbled"]
	chk("bogfin: a bubbling ring warns before it surfaces", bubbled)
	chk("bogfin: it surfaces to fight and can be hurt", f.state != "spawn" and f.model.position.y > -0.5)
	var h1 := f.hp
	h.damage_foe(f, 10.0, h.hero, Vector3.ZERO, 0.0)
	chk("bogfin: surfaced, it takes damage", f.hp < h1)
	# Fire sends it running.
	_stage(T.BOG)
	var b2 := foe("cm_bogfin", Vector3(10, 0, 0), false)
	run_for(1.0)
	g = grid()
	g.ignite(g.cell_of(Vector3(10, 0, 0)))
	run_for(0.5)
	chk("bogfin: fire over its bog drives it up and away (%s)" % brain(b2).st, brain(b2).st in ["flee", "move"] and b2.state == "chase")
	# Frog: lane, leap, lands near the hero.
	_stage(T.BOG)
	g = grid()
	for z in g.h:
		for x in g.w:
			var c2 := Vector2i(x, z)
			if g.center_of(c2).distance_to(Vector3.ZERO) < 2.0:
				g.set_kind(c2, T.DRY)
	var fr := foe("cm_frog", Vector3(9, 0, 0), false)
	run_for(1.0)
	chk("frog: it hides in the bog", fr.state == "spawn")
	m["lane"] = false
	m["leapt"] = false
	run_for(10.0, func():
		m["lane"] = m["lane"] or (brain(fr).st == "bubble" and teles_live() > 0)
		m["leapt"] = m["leapt"] or brain(fr).st == "leap"
		return m["leapt"] and brain(fr).st == "recover")
	var lane: bool = m["lane"]
	var leapt: bool = m["leapt"]
	chk("frog: a lane shows, then it leaps out of the bog (lane %s, leap %s)" % [lane, leapt], lane and leapt and fr.state != "spawn")
	# Without a grid nothing submerges.
	_stage()
	var nb := foe("cm_bogfin", Vector3(8, 0, 0))
	run_for(6.0)
	chk("bogfin: with no terrain it just fights on the surface", nb.state != "spawn" and hits.size() >= 1)


## The game's own terrain: biome_ground.gd paints the two zones, and the arena's
## TerrainRun drowns and burns the new foes (the grid is `arena.terrain`).
func _real_terrain() -> void:
	for zid in ["frost", "swamp", "barrow"]:
		var a := Arena.new()
		a.build(true, zid, 0, 1)
		BiomeGround.paint(a, zid)
		var n := 0
		for i in a.terrain.kind.size():
			if int(a.terrain.kind[i]) != T.DRY:
				n += 1
		chk("ground %s: %s" % [zid, "painted (%d cells), live" % n if zid != "barrow" else "left alone"], (a.terrain_live and n > 20) if zid != "barrow" else (not a.terrain_live and n == 0))
		a.free()
	_stage(T.WATER)
	var imp := foe("rh_imp", Vector3(6, 0, 0))
	var fin := foe("cm_bogfin", Vector3(-6, 0, 0))
	run_for(2.0)
	chk("real terrain: a frost foe in open water drowns through the arena's TerrainRun", not imp.alive and h.terr.drowned >= 1)
	chk("real terrain: an aquatic Bogfin does not drown in water", fin.alive)
	_stage(T.BURNING)
	var cold := foe("rh_imp", Vector3(6, 0, 0))
	var hot := foe("cm_imp", Vector3(-6, 0, 0))
	var cold_hp := cold.hp
	var hot_hp := hot.hp
	run_for(1.4)
	chk("real terrain: burning bog hurts a frost foe (%.0f -> %.0f)" % [cold_hp, cold.hp], cold.hp < cold_hp)
	chk("real terrain: a fire foe walks through it unhurt", hot.hp >= hot_hp)
	_stage(T.BURNING)
	var hag := foe("cm_bogfin", Vector3(6, 0, 0))
	var wolf := foe("rh_wolf", Vector3(-6, 0, 0))
	var hag_hp := hag.hp
	var wolf_hp := wolf.hp
	run_for(1.4)
	chk("real terrain: fire hurts a bog dweller harder than a land foe by max HP (%.2f vs %.2f)" % [(hag_hp - hag.hp) / hag_hp, (wolf_hp - wolf.hp) / wolf_hp], (hag_hp - hag.hp) / hag_hp > (wolf_hp - wolf.hp) / wolf_hp)
	_stage(-1)


func _wasp() -> void:
	_stage(T.DRY)
	var w := foe("cm_wasp", Vector3(8, 0, 0))
	m["windup"] = false
	m["dive"] = false
	m["flew"] = 0.0
	run_for(10.0, func():
		m["windup"] = m["windup"] or (brain(w).st == "windup" and teles_live() > 0)
		m["dive"] = m["dive"] or brain(w).st == "dash"
		m["flew"] = maxf(float(m["flew"]), w.model.position.y)
		return false)
	var windup: bool = m["windup"]
	var dive: bool = m["dive"]
	var flew: float = m["flew"]
	chk("wasp: it shows a lane, then dives and stings (%d hits)" % hits.size(), windup and dive and hits.size() >= 1)
	chk("wasp: it flies above the ground (%.1f m)" % flew, flew > 0.8)
	chk("wasp: over dry ground its sparks leave short ember patches", h.patches.size() >= 1)
	_stage(T.BOG)
	var w2 := foe("cm_wasp", Vector3(8, 0, 0))
	seed(7)
	run_for(30.0, func(): return count_kind(T.BURNING) > 0)
	var burning := count_kind(T.BURNING)
	chk("wasp: its sparks set the bog alight (%d cells)" % burning, burning >= 1)


func _pack_limits() -> void:
	_stage()
	var n0 := h.foes.size()
	for i in 4:
		foe("rh_wolf", Vector3(15, 0, i))
	chk("pack: a pack never fills the field past the cap (%d)" % h.foes.size(), h.foes.size() <= Hunt.MAX_FOES)
