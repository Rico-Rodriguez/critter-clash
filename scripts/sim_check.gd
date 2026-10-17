class_name SimCheck
extends RefCounted

static var failures := 0


static func run() -> int:
	failures = 0
	_roles()
	_modes()
	_save()
	_steer()
	_maps()
	_cards()
	_fights()
	_kite()
	if failures == 0:
		print("SIM CHECK PASSED")
		return 0
	print("SIM CHECK FAILED ", failures)
	return 1


static func _roles() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var exclusive := {
		"mage": ["mage_radius", "mage_power", "meteor", "arcane_orb"],
		"archer": ["archer_pierce", "volley", "hunters_mark"],
		"tank": ["tank_thorns", "tank_bash", "earthquake", "bulwark", "taunt_roar"],
	}
	var all_ex: Array = []
	for role in exclusive.keys():
		for id in exclusive[role]:
			all_ex.append(id)
	for role in exclusive.keys():
		var saw := false
		for _i in 700:
			var offer: Array = Catalog.roll_offer(role, {}, rng)
			if offer.size() != 3:
				_fail("%s offer size %d" % [role, offer.size()])
				return
			for id in offer:
				if str(id) in all_ex and str(id) not in exclusive[role]:
					_fail("%s rolled %s" % [role, id])
					return
				if str(id) in exclusive[role]:
					saw = true
				if Catalog.card(str(id)).is_empty():
					_fail("unknown card " + str(id))
					return
		if not saw:
			_fail(role + " never saw an exclusive")


static func _modes() -> void:
	var coop := Session.coop("meadow", "ember", "pebble")
	coop.seed = 4
	var sim := RunSim.new()
	sim.start(coop, {"ember": Catalog.base_stats("ember"), "pebble": Catalog.base_stats("pebble")})
	if sim.heroes.size() != 2 or int(sim.heroes[0].team) != 0 or int(sim.heroes[1].team) != 0:
		_fail("coop teams")
	sim.step(STEP, [Vector2.RIGHT, Vector2.LEFT])
	var duel := Session.duel("meadow", "juniper", "pebble")
	duel.seed = 8
	var rival := RunSim.new()
	rival.start(duel, {"juniper": Catalog.base_stats("juniper"), "pebble": Catalog.base_stats("pebble")})
	if rival.heroes.size() != 2 or int(rival.heroes[1].team) != 2:
		_fail("duel team")
	var before: float = rival.heroes[0].dmg
	rival.stacks["might"] = 2
	rival._recompute(rival.heroes[0])
	if rival.heroes[0].dmg <= before:
		_fail("might did not raise damage")


static func _save() -> void:
	SaveGame.reset_new()
	if not SaveGame.biome_open("meadow") or SaveGame.biome_open("mushroom"):
		_fail("biome gates at start")
	if Catalog.PET_RATE != 50:
		_fail("pet rate")
	if Catalog.skill_xp_to_level(2) != 83 or Catalog.skill_xp_to_level(99) != 13034431:
		_fail("skill curve")
	if Catalog.skill_level(0) != 1 or Catalog.skill_level(83) != 2 or Catalog.skill_level(13034431) != 99:
		_fail("skill level")
	if Catalog.all_drops().size() != 48:
		_fail("drop log size %d" % Catalog.all_drops().size())
	SaveGame.assign_task("meadow_critters")
	var summary := SaveGame.commit_victory("meadow", "thistle", 40)
	if int(summary["trophies"]) != 30:
		_fail("clear trophies")
	if SaveGame.data["heroes"].has("thistle"):
		_fail("boss became a hero")
	if int(summary.get("kills", 0)) != 1 or SaveGame.boss_kills("thistle") != 1:
		_fail("boss kill count")
	var drops: Array = summary.get("drops", [])
	if drops.is_empty() or not SaveGame.has_log(str(drops[0]["id"])):
		_fail("drop was not logged")
	if int(SaveGame.data["slayer"]["task"].get("have", 0)) != 40:
		_fail("slayer progress")
	if SaveGame.complete_task() != 25:
		_fail("slayer payout")
	if not SaveGame.biome_open("mushroom") or SaveGame.biome_open("frost"):
		_fail("meadow clear should open mushroom only")
	_drawer()
	var loot := SaveGame.open_next()
	if int(loot.get("coins", 0)) <= 0 or loot.get("cards", []).is_empty():
		_fail("chest loot empty")
	SaveGame.data["heroes"]["ember"]["cards"] = 8
	SaveGame.data["coins"] = 80
	if not SaveGame.try_level("ember") or int(SaveGame.hero("ember")["level"]) != 2:
		_fail("card level")
	var base_hp := float(Catalog.base_stats("ember")["hp"])
	if float(SaveGame.build_run_stats("ember")["hp"]) <= base_hp:
		_fail("level did not scale hp")
	SaveGame.data["trophies"] = 80
	if not SaveGame.claim("m80") or SaveGame.data["bag"].is_empty():
		_fail("trophy charm")
	var charm_uid := 0
	for piece in SaveGame.data["bag"]:
		if str(piece["slot"]) == "charm":
			charm_uid = int(piece["uid"])
	if charm_uid == 0:
		_fail("trophy charm missing")
	else:
		SaveGame.equip("ember", charm_uid)
		if int(SaveGame.hero("ember")["charm"]) != charm_uid:
			_fail("equip charm")
	if SaveGame.claim("m80"):
		_fail("double claim")


static func _steer() -> void:
	# The stick drives velocity directly: full speed on the first step,
	# instant reverse, instant stop (feel comes from Stage3D's lean/settle).
	var vel := Vector2.ZERO
	vel = RunSim.ease_stick(vel, Vector2.RIGHT, STEP)
	if vel.x < 0.99:
		_fail("start should be immediate, got %s" % vel)
	vel = RunSim.ease_stick(vel, Vector2.LEFT * 0.5, STEP)
	if absf(vel.x + 0.5) > 0.01:
		_fail("partial tilt should map straight through, got %s" % vel)
	vel = RunSim.ease_stick(vel, Vector2.ZERO, STEP)
	if vel != Vector2.ZERO:
		_fail("stop should be immediate, got %s" % vel)


static func _maps() -> void:
	var play := HuntMap.PLAY
	for biome in ["meadow", "mushroom", "frost", "volcano"]:
		var map := HuntMap.for_biome(biome)
		if map.size != HuntMap.ARENA or map.zones.size() != 1 or map.chunks.size() != 1:
			_fail("%s is not a single-arena map" % biome)
			return
		var zone: Dictionary = map.zones[0]
		var rect: Rect2 = zone["rect"]
		if rect != play or map.play != play:
			_fail("%s playfield moved" % biome)
			return
		if map.chunks_in(Rect2(Vector2.ZERO, HuntMap.VIEW)).size() != 1:
			_fail("%s streamed more than its one chunk" % biome)
			return
		if map.boss_spawn(76.0) != Vector2(play.get_center().x, play.position.y + 84.0):
			_fail("%s boss arena moved" % biome)
			return
	var pinned := HuntCamera.new()
	var meadow := HuntMap.for_biome("meadow")
	pinned.setup(meadow, Vector2(40, 168))
	pinned.follow(Vector2(900, 1500), 1.0)
	var tl := pinned.top_left()
	if tl.x < -0.01 or tl.y < -0.01 or tl.x > HuntMap.ARENA.x - HuntMap.VIEW.x + 0.01 or tl.y > HuntMap.ARENA.y - HuntMap.VIEW.y + 0.01:
		_fail("arena camera left the map")
	_world_maps()
	var wide := HuntMap.explore("meadow", 4, 4)
	if wide.size != Vector2(2880, 5120) or wide.chunks.size() != 16 or wide.zones.size() != 16:
		_fail("4x4 map is not 16 chunks")
		return
	var near: Dictionary = wide.zone_near(wide.zones[0]["rect"].get_center())
	if str(near["id"]) != "0_0":
		_fail("spawn zone did not follow the hero")
	var far: Dictionary = wide.zone_near(wide.zones[15]["rect"].get_center())
	if str(far["id"]) != "3_3":
		_fail("far zone was not chosen")
	var cam := HuntCamera.new()
	cam.setup(wide, wide.size * 0.5)
	var before: float = cam.center.x
	cam.follow(cam.center + Vector2(cam.deadzone.x + 40.0, 0), 1.0 / 60.0)
	var eased: float = cam.center.x - before
	if eased <= 1.0 or eased >= 20.0:
		_fail("camera deadzone is not soft (%s)" % eased)
	for _i in 180:
		cam.follow(Vector2.ZERO, 1.0 / 60.0)
	if cam.top_left().length() > 1.0:
		_fail("camera crossed the north-west bound")
	for _i in 180:
		cam.follow(wide.size, 1.0 / 60.0)
	var corner := cam.top_left()
	if absf(corner.x - (wide.size.x - 720.0)) > 1.0 or absf(corner.y - (wide.size.y - 1280.0)) > 1.0:
		_fail("camera crossed the south-east bound")
	var shown: Array = wide.chunks_in(Rect2(Vector2.ZERO, HuntMap.VIEW))
	if shown.size() != 4:
		_fail("stream window loaded %d chunks" % shown.size())
		return
	var stream := MapStream.new()
	stream.sync(meadow, Rect2(Vector2.ZERO, HuntMap.VIEW))
	if stream.get_child_count() != 1 or stream.get_child(0).get_child_count() != 1:
		_fail("small map did not keep a single backdrop")
	stream.free()
	var wide_stream := MapStream.new()
	wide_stream.sync(wide, Rect2(Vector2.ZERO, HuntMap.VIEW))
	if wide_stream.get_child_count() != 4:
		_fail("wide map instanced %d chunks" % wide_stream.get_child_count())
	elif wide_stream.get_child(0).get_child_count() != 3:
		_fail("chunk props were not instanced")
	wide_stream.sync(wide, Rect2(wide.size - HuntMap.VIEW, HuntMap.VIEW))
	if wide_stream.get_child_count() != 4 or wide_stream.get_node_or_null("0_0") != null:
		_fail("off-screen chunks stayed loaded")
	wide_stream.free()


## Card table coverage: at least 33 cards, unique ids, and every op can be
## applied and simulated for five seconds without error.
static func _cards() -> void:
	if Catalog.CARDS.size() < 33:
		_fail("only %d cards" % Catalog.CARDS.size())
	var seen := {}
	for entry in Catalog.CARDS:
		var id := str(entry.get("id", ""))
		if id == "" or seen.has(id):
			_fail("duplicate or empty card id " + id)
			continue
		seen[id] = true
		var roles: Array = entry.get("roles", [])
		var hero := "ember"
		if roles.size() > 0:
			hero = str({"mage": "ember", "archer": "juniper", "tank": "pebble"}.get(str(roles[0]), "ember"))
		var session := Session.solo("meadow", hero)
		session.seed = 77
		var sim := RunSim.new()
		sim.start(session, {hero: Catalog.base_stats(hero)})
		sim.stacks[id] = 1
		for h in sim.heroes:
			sim._recompute(h)
		# Put a couple of foes in reach so attack and pulse skills run too.
		var me: RunSim.Actor = sim.heroes[0]
		sim._spawn_minion(0, sim._clamp_point(me.pos + Vector2(120, 0), 24.0))
		sim._spawn_minion(1, sim._clamp_point(me.pos + Vector2(-110, 44), 24.0))
		for i in 300:
			var mv := Vector2.ZERO if i < 140 else Vector2(1, 0.2).normalized()
			sim.step(1.0 / 60.0, [mv])
			sim.drain_events()
			if sim.paused and sim.offer.size() > 0:
				sim.choose(0)
				sim.drain_events()
	print("CARDS ", Catalog.CARDS.size(), " ok")


static func _fights() -> void:
	# Explore hunts: each hero clears a map and kills the lair boss in a
	# 2.5-5.5 minute bot run (bots walk the map greedily; players land at 3-5+).
	for hero in ["ember", "juniper", "pebble"]:
		var report := _play(hero, "meadow", 11, false)
		print("FIGHT ", hero, " ", report)
		if str(report["result"]) != "win":
			_fail("%s should clear the meadow, got %s" % [hero, report["result"]])
		if float(report["time"]) < 150.0 or float(report["time"]) > 330.0:
			_fail("%s time %s outside the 2.5-5.5 min bot window" % [hero, report["time"]])
		if int(report["level"]) < 6:
			_fail("%s only reached level %s" % [hero, report["level"]])
	# No clock and no wave spawner: a hero who stands at the start is safe.
	var idle := _play("ember", "meadow", 11, true, 60.0 * 90.0)
	print("FIGHT idle ", idle)
	if str(idle["result"]) != "" or float(idle["hp"]) <= 0.0:
		_fail("standing at the start should be safe in an explore hunt")


## Explore map invariants: the start and lair are open, the lair is
## reachable, every camp and chest sits on reachable open ground, and the
## opening has no critters in sight.
static func _world_maps() -> void:
	for biome in ["meadow", "mushroom", "frost", "volcano"]:
		for seed in [3, 11, 42]:
			var m := HuntMap.world(biome, seed)
			var arena := HuntMap.ARENA.x * HuntMap.ARENA.y
			if m.size.x * m.size.y < arena * 15.0:
				_fail("world map is not ~16x the arena")
			var field := m.flow(m.start)
			if field[m.cell_index(m.lair)] < 0:
				_fail("%s/%d lair unreachable" % [biome, seed])
			for c in m.camps:
				if field[m.cell_index(c["pos"])] < 0 or m.depth(c["pos"]) < 0.0:
					_fail("%s/%d camp off the open ground" % [biome, seed])
			for c in m.loot:
				if field[m.cell_index(c["pos"])] < 0:
					_fail("%s/%d chest unreachable" % [biome, seed])
			if m.camps.size() < 8 or m.loot.size() < 3 or m.patrols.size() < 2:
				_fail("%s/%d too few camps/chests/patrols (%d/%d/%d)" % [biome, seed, m.camps.size(), m.loot.size(), m.patrols.size()])
			var elites := 0
			for c in m.camps:
				if bool(c["elite"]):
					elites += 1
			if elites < 2:
				_fail("%s/%d needs two elite packs" % [biome, seed])
	var session := Session.solo("meadow", "ember")
	session.seed = 11
	var sim := RunSim.new()
	sim.start(session, {"ember": Catalog.base_stats("ember")})
	if not sim.explore:
		_fail("solo hunts should be explore maps")
		return
	var hero_at: Vector2 = sim.heroes[0].pos
	for actor in sim.actors:
		if actor.kind == "minion" and actor.pos.distance_to(hero_at) < RunSim.AGGRO_CAMP + 150.0:
			_fail("a camp sits on the start")
	# Walls hold: walking into the forest slides along the edge.
	for _i in 240:
		sim.step(1.0 / 60.0, [Vector2(1, 0)])
		sim.drain_events()
	if sim.map.depth(sim.heroes[0].pos) < sim.heroes[0].radius * 0.8 - 1.0:
		_fail("hero walked into the forest")
	print("WORLD maps ok, opening clear")


## Balance sweep: each hero over several seeds, plus idle. Prints the
## average win time as a share of the 120 s hunt limit.
##   godot --path . -- --balance
static func balance() -> void:
	for hero in ["ember", "juniper", "pebble", "idle"]:
		var times: Array = []
		var wins := 0
		for seed in [3, 7, 11, 19, 23, 31, 42, 57]:
			var r := _play("ember" if hero == "idle" else hero, "meadow", seed, hero == "idle")
			times.append(float(r["time"]))
			if str(r["result"]) == "win":
				wins += 1
		var total := 0.0
		for t in times:
			total += t
		var avg := total / times.size()
		print("BALANCE %s wins %d/8 avg %.1fs min %.1f max %.1f" % [hero, wins, avg, times.min(), times.max()])


static func _play(hero: String, biome: String, seed: int, idle: bool, frames: float = 60.0 * 600.0) -> Dictionary:
	var session := Session.solo(biome, hero)
	session.seed = seed
	var sim := RunSim.new()
	var stats := {}
	stats[hero] = Catalog.base_stats(hero)
	sim.start(session, stats)
	var guard := 0
	var mem := {}
	while sim.result == "" and guard < int(frames):
		guard += 1
		if sim.paused and sim.offer.size() > 0:
			sim.choose(_best(sim))
			sim.drain_events()
			continue
		if sim.paused:
			return {"result": "stuck", "time": sim.time, "level": sim.level, "hp": 0}
		var mv := Vector2.ZERO if idle else (RunBot.explore_steer(sim, 0, mem) if sim.explore else RunBot.steer(sim, 0))
		sim.step(1.0 / 60.0, [mv])
		sim.drain_events()
		if OS.get_environment("CC_TRACE") == hero and guard % 600 == 0:
			var h: RunSim.Actor = sim.heroes[0]
			var bosses := []
			for a in sim.actors:
				if a.kind == "boss" and a.alive:
					bosses.append([a.pos.round(), int(a.hp), a.boss_state])
			var near := []
			for a in sim.actors:
				if a.alive and a.kind == "minion" and a.pos.distance_to(h.pos) < 700.0:
					near.append([a.sprite, a.pos.round(), a.aggro, int(a.pos.distance_to(h.pos)), a.range])
			print("TRACE near=", near)
			print("TRACE t=%d hp=%d pos=%s mv=%s phase=%s boss=%s goal=%s" % [int(sim.time), int(h.hp), str(h.pos.round()), str(mv.snapped(Vector2(0.01, 0.01))), sim.phase, str(bosses), str(mem.get("goal", ""))])
	var hp := 0.0
	if sim.heroes.size() > 0:
		hp = sim.heroes[0].hp
	return {"result": sim.result, "time": sim.time, "level": sim.level, "hp": hp}


## The hero kites the boss around the arena stones and into the corners;
## the boss must keep closing in (no stall longer than ~1 s while chasing)
## and never end up inside a stone.
static func _kite() -> void:
	var session := Session.solo("meadow", "pebble")
	session.seed = 11
	var sim := RunSim.new()
	var stats := {"pebble": Catalog.base_stats("pebble")}
	sim.start(session, stats)
	sim.heroes[0].hp = 1e9
	sim.heroes[0].max_hp = 1e9
	sim.begin_boss()
	if sim.obstacles.is_empty():
		_fail("boss arena built no stones")
	var inner := sim.play.grow(-110.0)
	var corners := [inner.position, Vector2(inner.end.x, inner.position.y), inner.end, Vector2(inner.position.x, inner.end.y)]
	var leg_t := 0.0
	var leg := 0
	var stall := 0.0
	var worst := 0.0
	var last := Vector2.INF
	var t := 0.0
	while t < 40.0 and sim.boss != null and sim.boss.alive:
		if sim.paused:
			if sim.offer.size() > 0:
				sim.choose(0)
			sim.paused = false
		var hero: RunSim.Actor = sim.heroes[0]
		var goal: Vector2 = corners[leg % 4]
		leg_t += 1.0 / 60.0
		# A corner can sit behind a stone; a player would give up and turn.
		if hero.pos.distance_to(goal) < 60.0 or leg_t > 6.0:
			leg += 1
			leg_t = 0.0
		var mv := (goal - hero.pos).normalized()
		sim.step(1.0 / 60.0, [mv])
		sim.drain_events()
		t += 1.0 / 60.0
		var b := sim.boss
		for o in sim.obstacles:
			if b.pos.distance_to(Vector2(o.x, o.y)) < o.z + b.radius * 0.6 - 1.0:
				_fail("boss inside a stone")
				return
		var chasing := b.boss_state == "idle" and b.pos.distance_to(hero.pos) > 220.0
		if chasing and last != Vector2.INF and b.pos.distance_to(last) < 0.5:
			stall += 1.0 / 60.0
		else:
			stall = 0.0
		worst = maxf(worst, stall)
		last = b.pos
	print("KITE boss worst stall %.2fs over %.0fs, legs %d" % [worst, t, leg])
	if worst > 1.0:
		_fail("boss stalled %.2fs while chasing" % worst)


## Chest drawer rules: earned chests arrive locked with a rarity timer,
## one unlocks at a time, a fifth is refused and reported.
static func _drawer() -> void:
	var keep: Array = SaveGame.data["chests"].duplicate(true)
	SaveGame.data["chests"].clear()
	SaveGame.commit_defeat("meadow", 0)
	if SaveGame.chest_state(0) != "locked" or SaveGame.chest_total(0) != SaveGame.UNLOCK_SECONDS["common"]:
		_fail("a pouch should arrive locked with the common timer")
	if not SaveGame.start_unlock(0) or SaveGame.chest_state(0) != "unlocking":
		_fail("tapping a locked chest should start its timer")
	SaveGame.commit_defeat("meadow", 0)
	if SaveGame.start_unlock(1):
		_fail("only one chest may unlock at a time")
	SaveGame.data["chests"][0]["ready_at"] = 0
	if SaveGame.chest_state(0) != "ready" or SaveGame.first_ready() != 0:
		_fail("an elapsed timer should make the chest ready")
	SaveGame.commit_defeat("meadow", 0)
	SaveGame.commit_defeat("meadow", 0)
	SaveGame.commit_defeat("meadow", 0)
	if SaveGame.pending_count() != SaveGame.SLOTS or not bool(SaveGame.last_chest.get("full", false)):
		_fail("a chest earned with full slots should be refused and reported")
	if SaveGame.take_fresh().size() != SaveGame.SLOTS or not SaveGame.take_fresh().is_empty():
		_fail("fresh chests should be reported once for the fly-in")
	if SaveGame.UNLOCK_SECONDS["common"] >= SaveGame.UNLOCK_SECONDS["rare"] or SaveGame.UNLOCK_SECONDS["rare"] >= SaveGame.UNLOCK_SECONDS["epic"]:
		_fail("timers should grow with rarity")
	SaveGame.data["chests"] = keep
	SaveGame.last_chest = {}


static func _best(sim: RunSim) -> int:
	var best_i := 0
	var best_s := -1
	for i in sim.offer.size():
		var card := Catalog.card(str(sim.offer[i]))
		var score := 1
		match str(card.get("op", "")):
			"revive", "phoenix":
				score = 7
			"dmg", "haste", "pierce", "splash", "splash_mul", "bash", "volley", "meteor", "storm":
				score = 6
			"quake", "chain", "orbit", "aura", "nova", "trail", "split", "hp", "regen", "armor", "thorns", "bulwark", "wolf":
				score = 5
			"swift", "bounce", "shots", "crit", "execute", "mark", "ricochet", "crit_siphon", "vampkill", "berserk", "static", "gemburst", "blink":
				score = 4
			_:
				score = 1
		if score > best_s:
			best_s = score
			best_i = i
	return best_i


static func _fail(message: String) -> void:
	failures += 1
	print("FAIL ", message)


const STEP := 1.0 / 60.0
