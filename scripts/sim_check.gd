class_name SimCheck
extends RefCounted

static var failures := 0


static func run() -> int:
	failures = 0
	_roles()
	_modes()
	_save()
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
	var summary := SaveGame.commit_victory("meadow", "thistle")
	if int(summary["trophies"]) != 30 or not bool(SaveGame.hero("thistle")["unlocked"]):
		_fail("tame did not unlock thistle")
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


static func _fights() -> void:
	for hero in ["ember", "juniper", "pebble"]:
		var report := _play(hero, "meadow", 11, false)
		print("FIGHT ", hero, " ", report)
		if str(report["result"]) != "win":
			_fail("%s should tame the meadow, got %s" % [hero, report["result"]])
		if float(report["time"]) < 60.0 or float(report["time"]) >= 119.0:
			_fail("%s time %s outside the hunt window" % [hero, report["time"]])
		if int(report["level"]) < 3:
			_fail("%s only reached level %s" % [hero, report["level"]])
	var idle := _play("ember", "meadow", 11, true)
	print("FIGHT idle ", idle)
	if str(idle["result"]) != "lose":
		_fail("standing still should lose")


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
