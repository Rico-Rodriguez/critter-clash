class_name SimCheck
extends RefCounted

static var failures := 0


static func run() -> int:
	failures = 0
	if OS.get_cmdline_user_args().has("--class-report"):
		class_report(_class_tag())
	_roles()
	_modes()
	_save()
	_daily_check()
	_steer()
	_maps()
	_cards()
	_pools_check()
	_fights()
	_kite()
	_boss_intro_check()
	_dodge_check()
	_events_check()
	if failures == 0:
		print("SIM CHECK PASSED")
		return 0
	print("SIM CHECK FAILED ", failures)
	return 1


static func _roles() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var exclusive := {
		"mage": ["mage_radius", "mage_power", "mage_chain", "mage_crit", "meteor", "arcane_orb"],
		"archer": ["archer_pierce", "multishot", "archer_crit", "archer_haste", "volley", "hunters_mark"],
		"tank": ["tank_thorns", "tank_bash", "earthquake", "bulwark", "taunt_roar", "tank_armor"],
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


## Daily Challenge: one deterministic map per UTC day, one or two modifiers,
## a monotonic score, and the local board's ranking and 10-run cap. The board
## test runs on a temporary copy of SaveGame.data and restores it (rewriting
## the save to its original contents) so the real board is never touched.
static func _daily_check() -> void:
	var base := 1750000000
	var key := Daily.today_key(base)
	var a := Session.daily("ember", base)
	var b := Session.daily("pebble", base)
	if a.seed != b.seed or a.biome_id != b.biome_id or a.daily_key != b.daily_key:
		_fail("daily is not deterministic")
	if str(a.modifiers) != str(b.modifiers):
		_fail("daily modifiers are not deterministic")
	if a.mode != Session.Mode.SOLO:
		_fail("daily should be solo")
	if a.seed != Daily.seed_for(key) or a.biome_id != Daily.biome_for(key):
		_fail("daily does not follow its key")
	if a.modifiers.size() < 1 or a.modifiers.size() > 2:
		_fail("daily should pick one or two modifiers, got %d" % a.modifiers.size())
	var seeds := {}
	for i in 30:
		seeds[Daily.seed_for(Daily.today_key(base + i * 86400))] = true
	if seeds.size() < 20:
		_fail("30 days gave only %d distinct seeds" % seeds.size())
	# The rotation must cover every biome and never land on the same one two
	# days running. 28 days is short enough to stay quick and long enough that
	# a skipped biome would show.
	var counts := {}
	var prev := ""
	for i in 28:
		var bid := Daily.biome_for(Daily.today_key(base + i * 86400))
		if bid == prev:
			_fail("daily repeated %s on consecutive days" % bid)
			break
		prev = bid
		counts[bid] = int(counts.get(bid, 0)) + 1
	for entry in Catalog.BIOMES:
		var bid := str(entry["id"])
		if int(counts.get(bid, 0)) < 3:
			_fail("daily biome %s appeared %d times in 28 days" % [bid, int(counts.get(bid, 0))])
	var win := {"win": true, "time": 200.0, "kills": 60, "level": 8, "hp": 50.0, "max_hp": 100.0}
	var loss := win.duplicate()
	loss["win"] = false
	loss["hp"] = 0.0
	if Daily.score(win) <= Daily.score(loss):
		_fail("a win must outscore a loss")
	var slow := win.duplicate()
	slow["time"] = 280.0
	if Daily.score(win) <= Daily.score(slow):
		_fail("a faster win must outscore a slower one")
	var keep: Dictionary = SaveGame.data.duplicate(true)
	SaveGame.no_write = true
	SaveGame.data["daily"] = {}
	SaveGame.data["pending_upload"] = []
	var tk := "2000-01-01"
	if SaveGame.record_daily(tk, {"score": 100, "hero": "ember", "time": 100, "result": "loss", "at": 1}) != 1:
		_fail("first daily run should rank 1")
	if SaveGame.record_daily(tk, {"score": 500, "hero": "ember", "time": 90, "result": "win", "at": 2}) != 1:
		_fail("best daily run should rank 1")
	if SaveGame.record_daily(tk, {"score": 300, "hero": "juniper", "time": 120, "result": "loss", "at": 3}) != 2:
		_fail("middle daily run should rank 2")
	if SaveGame.daily_best(tk) != 500:
		_fail("daily best should be 500")
	for i in 15:
		SaveGame.record_daily(tk, {"score": i + 1, "hero": "ember", "time": 60, "result": "loss", "at": 4 + i})
	var board := SaveGame.daily_board(tk)
	if board.size() != SaveGame.DAILY_RUNS:
		_fail("daily board should keep %d runs, got %d" % [SaveGame.DAILY_RUNS, board.size()])
	for i in range(1, board.size()):
		if int(board[i - 1]["score"]) < int(board[i]["score"]):
			_fail("daily board is not sorted by score")
			break
	# Daily access: a sealed biome is playable through the daily, but the
	# session and a win leave the clear state alone. Run on the in-memory
	# copy with no_write set, then restore.
	SaveGame.data["trophies"] = 0
	SaveGame.data["cleared"] = {}
	var locked_unix := 0
	for i in 8:
		var u := base + i * 86400
		if not SaveGame.biome_open(Daily.biome_for(Daily.today_key(u))):
			locked_unix = u
			break
	if locked_unix == 0:
		_fail("daily rotation never hit a sealed biome")
	else:
		var locked_id := Daily.biome_for(Daily.today_key(locked_unix))
		var before: Dictionary = SaveGame.data["cleared"].duplicate(true)
		var daily_session := Session.daily("ember", locked_unix)
		var daily_sim := RunSim.new()
		daily_sim.start(daily_session, {"ember": Catalog.base_stats("ember")})
		for _i in 5:
			daily_sim.step(STEP, [Vector2.ZERO])
		SaveGame.commit_daily_pass(locked_id, str(Catalog.biome(locked_id)["boss"]))
		if str(SaveGame.data["cleared"]) != str(before):
			_fail("a locked daily changed the clear state")
		if SaveGame.biome_cleared(locked_id):
			_fail("a locked daily marked %s cleared" % locked_id)
	SaveGame.data = keep
	SaveGame.no_write = false
	print("DAILY ok: key %s seed %d biome %s" % [key, a.seed, a.biome_id])


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


## Blessing pools: each card in exactly one pool, class pools hold enough
## cards, and 2000 seeded offers per role respect class exclusivity, maxes,
## uniques, duplicates and the one-class-card guarantee. card_text is checked
## for every rank and must carry the rank total for stackables.
static func _pools_check() -> void:
	var counts := {"general": 0, "tank": 0, "archer": 0, "mage": 0}
	for entry in Catalog.CARDS:
		var id := str(entry.get("id", ""))
		var pool := Catalog.pool_of(id)
		if not counts.has(pool):
			_fail("card %s has unknown pool %s" % [id, pool])
			return
		counts[pool] = int(counts[pool]) + 1
		if bool(entry.get("stack", false)) != (int(entry.get("max", 1)) > 1):
			_fail("card %s stack flag mismatch" % id)
			return
	if int(counts["general"]) < 14:
		_fail("general pool only %d" % int(counts["general"]))
	for role in ["tank", "archer", "mage"]:
		if int(counts[role]) < 6:
			_fail("%s pool only %d" % [role, int(counts[role])])
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	for role in ["tank", "archer", "mage"]:
		for _i in 2000:
			var stacks := {}
			for entry in Catalog.CARDS:
				stacks[str(entry["id"])] = rng.randi_range(0, int(entry["max"]))
			var offer: Array = Catalog.roll_offer(role, stacks, rng)
			if offer.size() != 3:
				_fail("%s offer size %d" % [role, offer.size()])
				return
			var seen := {}
			var has_class := false
			for id in offer:
				var sid := str(id)
				if seen.has(sid):
					_fail("%s duplicate %s" % [role, sid])
					return
				seen[sid] = true
				if sid == "snack":
					continue
				var entry := Catalog.card(sid)
				if entry.is_empty():
					_fail("unknown card " + sid)
					return
				var card_pool := Catalog.pool_of(sid)
				if card_pool != "general" and card_pool != role:
					_fail("%s offered %s from %s" % [role, sid, card_pool])
					return
				if card_pool == role:
					has_class = true
				var have := int(stacks.get(sid, 0))
				if have >= int(entry.get("max", 1)):
					_fail("%s offered %s at max" % [role, sid])
					return
			if _class_available(role, stacks) and not has_class:
				_fail("%s offer had no class card" % role)
				return
	# The class swap draws from the run rng now: over 500 fresh offers a role
	# must see its exclusives spread across at least four distinct ids rather
	# than the same card pinned by a hash of the general card it replaced.
	for role in ["tank", "archer", "mage"]:
		var cover := {}
		for _i in 500:
			for id in Catalog.roll_offer(role, {}, rng):
				if Catalog.pool_of(str(id)) == role:
					cover[str(id)] = true
		if cover.size() < 4:
			_fail("%s class swap covered only %d ids" % [role, cover.size()])
	for entry in Catalog.CARDS:
		var id := str(entry["id"])
		for have in range(0, int(entry["max"])):
			var text := Catalog.card_text(id, have)
			if text.strip_edges() == "":
				_fail("empty card_text for %s rank %d" % [id, have])
				return
			if bool(entry.get("stack", false)) and have > 0:
				var total := float(entry.get("n", 0)) * float(have + 1)
				if text.find(Catalog.fmt_amount(total)) < 0:
					_fail("card_text %s rank %d missing total %s" % [id, have, Catalog.fmt_amount(total)])
					return
	print("POOLS ok, general %d tank %d archer %d mage %d" % [int(counts["general"]), int(counts["tank"]), int(counts["archer"]), int(counts["mage"])])


static func _class_available(role: String, stacks: Dictionary) -> bool:
	for entry in Catalog.CARDS:
		if Catalog.pool_of(str(entry["id"])) != role:
			continue
		if int(stacks.get(str(entry["id"]), 0)) < int(entry["max"]):
			return true
	return false


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
	return {
		"result": sim.result,
		"time": sim.time,
		"level": sim.level,
		"hp": hp,
		"dmg_taken": sim.dmg_taken,
		"kills": sim.kills,
	}


## Optional tag for the class report: --class-tag=AFTER (defaults to REPORT).
static func _class_tag() -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--class-tag="):
			return arg.substr(12)
	return "REPORT"


## Class balance report: one representative hero per role over five fixed
## seeds. Prints wins, average clear time, damage the team took (total and
## per minute), foes killed (total and per minute) and average health left.
##   godot --headless --path . -- --sim-check --class-report [--class-tag=TAG]
## Measured on main e54d622 vs this branch, seeds 3/7 time out for every
## class both before and after (the bot never reaches the lair: a pathing issue
## outside this change). Winning seeds 11/19/23 average:
## BEFORE tank 276 s, 28 dmg/min | archer 2/3 wins, 9 dmg/min | mage 215 s, 8 dmg/min
## AFTER  tank 192 s,  7 dmg/min | archer 207 s, 4 dmg/min    | mage 219 s, 10 dmg/min
static func class_report(tag: String) -> void:
	var reps := {"tank": "pebble", "archer": "juniper", "mage": "ember"}
	var seeds := [3, 7, 11, 19, 23]
	for role in ["tank", "archer", "mage"]:
		var hero := str(reps[role])
		var wins := 0
		var total_time := 0.0
		var total_dmg := 0.0
		var total_kills := 0
		var total_hp := 0.0
		for seed in seeds:
			var r := _play(hero, "meadow", seed, false)
			if OS.get_environment("CC_CLASS_TRACE") != "":
				print("  TRACE %s seed %d result=%s time=%.1f hp=%.0f" % [role, seed, r["result"], r["time"], float(r.get("hp", 0.0))])
			if str(r["result"]) == "win":
				wins += 1
			total_time += float(r["time"])
			total_dmg += float(r.get("dmg_taken", 0.0))
			total_kills += int(r.get("kills", 0))
			total_hp += float(r.get("hp", 0.0))
		var mins := maxf(total_time / 60.0, 0.001)
		print("CLASS %s %s wins %d/%d avg_time %.1f dmg_taken %d (per minute %d) kills %d (per minute %d) hp_left %d" % [
			tag, role, wins, seeds.size(), total_time / float(seeds.size()),
			int(round(total_dmg)), int(round(total_dmg / mins)),
			total_kills, int(round(float(total_kills) / mins)),
			int(round(total_hp / float(seeds.size()))),
		])


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


## Boss intro: walking into the lair spawns a live boss immediately, but it
## holds still and cannot be hurt or attack for BOSS_INTRO seconds, and its
## first telegraph only opens once it shares the hero's view.
static func _boss_intro_check() -> void:
	var session := Session.solo("meadow", "ember")
	session.seed = 11
	var sim := RunSim.new()
	sim.start(session, {"ember": Catalog.base_stats("ember")})
	if not sim.explore:
		_fail("boss intro check needs an explore map")
		return
	var hero: RunSim.Actor = sim.heroes[0]
	hero.hp = 1e9
	hero.max_hp = 1e9
	hero.pos = sim.map.lair
	sim.step(STEP, [Vector2.ZERO])
	sim.drain_events()
	if sim.boss == null or not sim.boss.alive:
		_fail("boss missing right after the lair triggered")
		return
	if sim.phase != "boss":
		_fail("lair did not start the boss phase")
	if sim.boss.boss_state != "intro":
		_fail("boss did not enter its intro (state %s)" % sim.boss.boss_state)
	if str(sim.boss_title).is_empty():
		_fail("boss intro had no title")
	var boss: RunSim.Actor = sim.boss
	var hp0 := boss.hp
	# The reveal is untouchable, even by a direct blow.
	sim._hurt(boss, 100.0, hero.pos, false, hero, false)
	if boss.hp < hp0:
		_fail("the boss took damage during its intro")
	var seen_attack := false
	var guard := 0
	while boss.boss_state == "intro" and guard < 600:
		guard += 1
		_step_one(sim)
		for e in sim.drain_events():
			var kind := str(e.get("type", ""))
			if (kind == "windup" or kind == "attack") and int(e.get("id", -1)) == boss.id:
				seen_attack = true
		if boss.hp < hp0:
			_fail("the boss took damage during its intro")
			break
	if seen_attack:
		_fail("the boss attacked during its intro")
	if boss.boss_state == "intro":
		_fail("the boss intro never ended")
	# After the intro the first telegraph must land with the boss in view.
	var windup_d := -1.0
	for _i in int(30.0 / STEP):
		_step_one(sim)
		for e in sim.drain_events():
			if str(e.get("type", "")) == "windup" and int(e.get("id", -1)) == boss.id:
				windup_d = boss.pos.distance_to(hero.pos)
		if windup_d >= 0.0 or not boss.alive:
			break
	if windup_d < 0.0:
		_fail("the boss never telegraphed an attack")
	elif windup_d > RunSim.BOSS_ENGAGE:
		_fail("first boss windup was %.0f px away" % windup_d)


## One bot-sized step: resolves a pending level-up before advancing, so the
## intro timing check is never frozen behind a card offer.
static func _step_one(sim: RunSim) -> void:
	while sim.paused and sim.offer.size() > 0:
		sim.choose(0)
	if sim.paused:
		sim.paused = false
	sim.step(STEP, [Vector2.ZERO])


## Dodge roll: covers ground in the open, grants i-frames while dashing,
## respects the cooldown, shoots a dodge event, and never ends inside an
## obstacle (dodged straight into the forest edge, the hero stays outside).
static func _dodge_check() -> void:
	var session := Session.solo("meadow", "ember")
	session.seed = 11
	var sim := RunSim.new()
	sim.start(session, {"ember": Catalog.base_stats("ember")})
	if not sim.explore:
		_fail("dodge check needs an explore map")
		return
	var hero: RunSim.Actor = sim.heroes[0]
	var map := sim.map
	var start: Vector2 = hero.pos
	var dir := Vector2.ZERO
	for cand in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN, Vector2(1, -1).normalized()]:
		var clear := true
		for s in 11:
			if map.depth(start + cand * (240.0 * float(s) / 10.0)) < hero.radius * 1.4:
				clear = false
				break
		if clear:
			dir = cand
			break
	if dir == Vector2.ZERO:
		_fail("no open lane from the start for the dodge")
		return
	if not sim.dodge(0, dir):
		_fail("dodge refused at full cooldown")
		return
	var landed := false
	for i in 15:
		if sim.dodge(0, dir):
			_fail("second dodge succeeded during cooldown")
			return
		sim.step(1.0 / 60.0, [Vector2.ZERO])
		landed = hero.pos.distance_to(start) > 150.0
		if i == 4 and hero.iframes <= 0.0:
			_fail("dodge i-frames expired early")
	if not landed:
		_fail("dodge did not cover 150 px within 0.25 s")
	var ev := false
	for e in sim.drain_events():
		if str(e.get("type", "")) == "dodge" and int(e.get("id", -1)) == hero.id:
			ev = true
	if not ev:
		_fail("dodge emitted no event")
	# Cooldown releases: after ~2.3 s a second roll goes through.
	for _i in 140:
		sim.step(1.0 / 60.0, [Vector2.ZERO])
		sim.drain_events()
	if not sim.dodge(0, dir):
		_fail("dodge stayed on cooldown past 2.3 s")
	# Into the wall: the roll ends at the edge, never inside the forest.
	for _i in 240:
		sim.step(1.0 / 60.0, [Vector2(1, 0)])
		sim.drain_events()
	hero = sim.heroes[0]
	if not hero.alive:
		return
	if sim.dodge(0, Vector2(1, 0)):
		for _i in 15:
			sim.step(1.0 / 60.0, [Vector2.ZERO])
			sim.drain_events()
		if sim.map.depth(sim.heroes[0].pos) < sim.heroes[0].radius * 0.8 - 1.0:
			_fail("dodge ended inside an obstacle")


## Map events: deterministic shrines/affixes/goblin, shrine buffs that raise a
## stat and expire, shielded elites, a fleeing goblin that pays out, and
## molten death patches.
static func _events_check() -> void:
	# (a) The same seed rebuilds identical map events; a different seed varies.
	var a := HuntMap.world("meadow", 11)
	var b := HuntMap.world("meadow", 11)
	var c := HuntMap.world("meadow", 12)
	if _event_sig(a) != _event_sig(b):
		_fail("map events are not deterministic")
	if _event_sig(a) == _event_sig(c):
		_fail("map events do not vary with the seed")
	if a.shrines.size() < 2:
		_fail("world placed only %d shrines" % a.shrines.size())
	if a.goblin_at == Vector2.INF:
		_fail("world rolled no goblin haunt")
	# (b) A shrine raises the stat it names, then lets go after 30 s.
	var bsim := _sim("meadow", "ember", 11)
	if bsim.shrines.is_empty():
		_fail("run has no shrines")
		return
	var bhero: RunSim.Actor = bsim.heroes[0]
	bsim.shrines[0]["kind"] = "fury"
	bsim.shrines[0]["used"] = false
	var base_dmg: float = bhero.dmg
	bhero.pos = bsim.shrines[0]["pos"]
	bsim._step_shrines(STEP)
	if not bhero.shrine_buffs.has("fury") or bhero.dmg <= base_dmg:
		_fail("fury shrine did not raise damage")
	for _i in 1830:
		bsim._step_shrines(STEP)
	if bhero.shrine_buffs.has("fury") or bhero.dmg != base_dmg:
		_fail("fury shrine did not expire after 30 s")
	# (c) A shielded elite soaks damage with its shield before its hp.
	var csim := _sim("meadow", "ember", 11)
	var chero: RunSim.Actor = csim.heroes[0]
	var elite := csim._place_minion(0, csim._clamp_point(chero.pos + Vector2(400, 0), 24.0), -1)
	csim._make_elite(elite)
	csim._apply_affixes(elite, ["shielded"])
	if elite.shield <= 0.0:
		_fail("shielded elite got no shield")
	var ehp: float = elite.hp
	csim._hurt(elite, 5.0, elite.pos, false, chero, false)
	if elite.hp != ehp or elite.shield >= 0.4 * ehp:
		_fail("shield did not absorb the hit")
	csim._hurt(elite, elite.shield + 40.0, elite.pos, false, chero, false)
	if elite.hp >= ehp:
		_fail("hp did not drop once the shield broke")
	# (d) The goblin outruns the hero, and killing it pays out a chest.
	var gsim := _sim("meadow", "ember", 11)
	var ghero: RunSim.Actor = gsim.heroes[0]
	var lane := _clear_dir(gsim, ghero)
	var gob := gsim._spawn_goblin(gsim.map.push_inside(ghero.pos + lane * 340.0, 30.0))
	var gap: float = gob.pos.distance_to(ghero.pos)
	for _i in 120:
		var to: Vector2 = gob.pos - ghero.pos
		if to.length() > 1.0:
			ghero.pos += to.normalized() * ghero.speed * 0.5 * STEP
		gsim._step_goblin(gob, STEP, ghero)
	var gap2: float = gob.pos.distance_to(ghero.pos)
	if gap2 <= gap:
		_fail("goblin did not outrun the hero (%.0f -> %.0f)" % [gap, gap2])
	gsim.drain_events()
	gsim._hurt(gob, 1.0e9, gob.pos, false, ghero, false)
	var looted := false
	for e in gsim.drain_events():
		if str(e.get("type", "")) == "loot":
			looted = true
	if not looted:
		_fail("goblin kill dropped no loot")
	# (e) A molten death leaves a burning patch that hurts the hero.
	var msim := _sim("meadow", "ember", 11)
	var mhero: RunSim.Actor = msim.heroes[0]
	var molten := msim._place_minion(0, msim._clamp_point(mhero.pos + Vector2(-300, 0), 24.0), -1)
	msim._apply_affixes(molten, ["molten"])
	msim.drain_events()
	msim._hurt(molten, 1.0e9, molten.pos, false, mhero, false)
	var patch: RunSim.Field = null
	for f in msim.fields:
		if f.kind == "molten":
			patch = f
	if patch == null:
		_fail("molten death left no patch")
		return
	mhero.iframes = 0.0
	mhero.pos = patch.pos
	var mhp: float = mhero.hp
	msim._step_fields(STEP)
	if mhero.hp >= mhp:
		_fail("molten patch did not damage the hero")
	print("EVENTS shrines/affixes/goblin ok")


static func _sim(biome: String, hero: String, seed: int) -> RunSim:
	var session := Session.solo(biome, hero)
	session.seed = seed
	var sim := RunSim.new()
	sim.start(session, {hero: Catalog.base_stats(hero)})
	return sim


static func _event_sig(m: HuntMap) -> String:
	var s := str(m.shrines) + "|" + str(m.goblin_at)
	for camp in m.camps:
		s += "|" + str(camp.get("affixes", []))
	return s


## A heading from the hero with the most open ground ahead (for test staging).
static func _clear_dir(sim: RunSim, hero: RunSim.Actor) -> Vector2:
	var best := Vector2.RIGHT
	var best_depth := -1.0e9
	for k in 8:
		var d := Vector2.RIGHT.rotated(TAU * float(k) / 8.0)
		var depth := sim.map.depth(hero.pos + d * 340.0)
		if depth > best_depth:
			best_depth = depth
			best = d
	return best


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
