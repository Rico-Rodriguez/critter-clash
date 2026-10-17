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
	_fights()
	if failures == 0:
		print("SIM CHECK PASSED")
		return 0
	print("SIM CHECK FAILED ", failures)
	return 1


static func _roles() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var exclusive := {
		"mage": ["mage_radius", "mage_power"],
		"archer": ["archer_pierce"],
		"tank": ["tank_thorns", "tank_bash"],
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
	var vel := Vector2.ZERO
	vel = RunSim.ease_stick(vel, Vector2.RIGHT, STEP)
	if vel.x <= 0.02 or vel.x > 0.55:
		_fail("start should ease, got %s" % vel)
	if vel.normalized().dot(Vector2.RIGHT) < 0.99:
		_fail("heading did not match the stick")
	for _i in 6:
		vel = RunSim.ease_stick(vel, Vector2.RIGHT, STEP)
	if vel.x < 0.95:
		_fail("did not reach full speed, got %s" % vel)
	vel = RunSim.ease_stick(vel, Vector2.LEFT, STEP)
	if vel.x > -0.95:
		_fail("reverse should snap, got %s" % vel)
	if vel.normalized().dot(Vector2.LEFT) < 0.99:
		_fail("reverse heading lagged")
	vel = RunSim.ease_stick(vel, Vector2.ZERO, STEP)
	if vel.x >= -0.02 or vel.x < -0.85:
		_fail("stop should ease, got %s" % vel)


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
	var session := Session.solo("meadow", "ember")
	session.seed = 11
	var sim := RunSim.new()
	sim.start(session, {"ember": Catalog.base_stats("ember")})
	var minions := 0
	var hero_at: Vector2 = sim.heroes[0].pos
	for actor in sim.actors:
		if actor.kind != "minion":
			continue
		minions += 1
		# Packs land just outside the camera's view, inside the zone.
		if not play.has_point(actor.pos):
			_fail("spawn left the zone")
			return
		var rel: Vector2 = actor.pos - hero_at
		var view := RunSim.VIEW_BOX
		var outer := view.grow(RunSim.SPAWN_MARGIN + 80.0)
		if view.grow(-30.0).has_point(rel) or not outer.has_point(rel):
			_fail("opening pack spawned at %s, not just outside the view" % str(rel))
			return
	if minions != RunSim.PACK_SIZE:
		_fail("expected an opening pack of %d" % RunSim.PACK_SIZE)
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


static func _fights() -> void:
	for hero in ["ember", "juniper", "pebble"]:
		var report := _play(hero, "meadow", 11, false)
		print("FIGHT ", hero, " ", report)
		if str(report["result"]) != "win":
			_fail("%s should clear the meadow, got %s" % [hero, report["result"]])
		if float(report["time"]) < 60.0 or float(report["time"]) >= 119.0:
			_fail("%s time %s outside the hunt window" % [hero, report["time"]])
		if int(report["level"]) < 3:
			_fail("%s only reached level %s" % [hero, report["level"]])
	var idle := _play("ember", "meadow", 11, true)
	print("FIGHT idle ", idle)
	if str(idle["result"]) != "lose":
		_fail("standing still should lose")


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
		print("BALANCE %s wins %d/8 avg %.1fs (%.0f%% of 120) min %.1f max %.1f" % [hero, wins, avg, avg / 1.2, times.min(), times.max()])


static func _play(hero: String, biome: String, seed: int, idle: bool) -> Dictionary:
	var session := Session.solo(biome, hero)
	session.seed = seed
	var sim := RunSim.new()
	var stats := {}
	stats[hero] = Catalog.base_stats(hero)
	sim.start(session, stats)
	var guard := 0
	while sim.result == "" and guard < 9000:
		guard += 1
		if sim.paused and sim.offer.size() > 0:
			sim.choose(_best(sim))
			sim.drain_events()
			continue
		if sim.paused:
			return {"result": "stuck", "time": sim.time, "level": sim.level, "hp": 0}
		var mv := Vector2.ZERO if idle else RunBot.steer(sim, 0)
		sim.step(1.0 / 60.0, [mv])
		sim.drain_events()
	var hp := 0.0
	if sim.heroes.size() > 0:
		hp = sim.heroes[0].hp
	return {"result": sim.result, "time": sim.time, "level": sim.level, "hp": hp}


static func _best(sim: RunSim) -> int:
	var best_i := 0
	var best_s := -1
	for i in sim.offer.size():
		var card := Catalog.card(str(sim.offer[i]))
		var score := 1
		match str(card.get("op", "")):
			"revive":
				score = 7
			"dmg", "haste", "pierce", "splash", "splash_mul", "bash":
				score = 6
			"hp", "regen", "armor", "thorns":
				score = 4
			"swift", "bounce", "shots", "crit":
				score = 3
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
