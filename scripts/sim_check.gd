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
	_gear_save_check()
	_slayer_log_check()
	_settings_check()
	_daily_check()
	_steer()
	_maps()
	_cards()
	_pools_check()
	_exclusivity_check()
	_fights()
	if OS.get_cmdline_user_args().has("--seed-sweep"):
		seed_sweep()
	_kite()
	_boss_intro_check()
	_dodge_check()
	_events_check()
	_gear_drop_smoke()
	_skill_xp_smoke()
	_gear_coverage_check()
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
	# Road gear goes straight into the armory for the featured hero.
	var charm_had := GearDB.owned(SaveGame.featured_id()).size()
	if not SaveGame.claim("m80"):
		_fail("trophy charm")
	elif GearDB.owned(SaveGame.featured_id()).size() <= charm_had:
		_fail("trophy charm missing from the armory")
	if SaveGame.data.has("bag"):
		_fail("legacy bag came back")
	if SaveGame.claim("m80"):
		_fail("double claim")


## Gear persistence: kernel saves get packaged as the active kit with old-save
## migration. (a) A synthetic v2 save converts equipped + bag pieces into the
## armory exactly once. (b) The bare hero matches base stats and equipped
## deltas equal the summed GearDB stats_for + level_bonus. (c) A gated rune
## piece stays owned but never equips. (d) A save/load round trip keeps the
## armory (and unknown future keys) intact. Runs with no_write and restores
## the save afterwards; GearDB writes go to scratch override dicts.
static func _gear_save_check() -> void:
	var keep: Dictionary = SaveGame.data.duplicate(true)
	var keep_no_write: bool = SaveGame.no_write
	var keep_store: Variant = GearDB.store_override
	SaveGame.no_write = true
	# (a) Migration of a v2 legacy save: equipped pieces become the owner's
	# item (weapon->weapon, armor->chest, charm->charm; common->iron 1,
	# rare->steel 2, legendary->rune 3), gated pieces stay owned but off, bag
	# pieces convert for the featured hero, junk pays out coins.
	var legacy := {
		"save_version": 2,
		"coins": 30,
		"featured": "pebble",
		"bag": [
			{"uid": 1, "slot": "weapon", "rarity": "common", "name": "Old Claw", "stats": {"dmg_pct": 0.1}},
			{"uid": 2, "slot": "armor", "rarity": "common", "name": "Old Vest", "stats": {"hp_flat": 20}},
			{"uid": 4, "slot": "charm", "rarity": "rare", "name": "Old Charm", "stats": {"crit": 0.04}},
			{"uid": 5, "slot": "weapon", "rarity": "uncommon", "name": "Old Wand", "stats": {"dmg_pct": 0.09}},
			{"uid": 11, "slot": "weapon", "rarity": "epic", "name": "Grand Mallet", "stats": {"dmg_pct": 0.13}},
			{"uid": 12, "slot": "armor", "rarity": "rare", "name": "Bright Shell", "stats": {"hp_flat": 30}},
			{"uid": 13, "slot": "charm", "rarity": "legendary", "name": "Grand Bead", "stats": {"crit": 0.05}},
			{"uid": 14, "slot": "helmet", "rarity": "epic", "name": "Junk Bit", "stats": {}},
		],
		"heroes": {
			"pebble": {"unlocked": true, "cards": 3, "level": 2, "weapon": 1, "armor": 2, "charm": 4},
			"ember": {"unlocked": true, "cards": 1, "level": 4, "weapon": 5, "armor": 0, "charm": 0},
		},
	}
	SaveGame.data = legacy
	SaveGame.migrate_legacy_armory(2)
	var armory: Dictionary = SaveGame.data["armory"]
	if int(armory.get("migrated_from", 0)) != 2:
		_fail("migration did not stamp migrated_from %s" % str(armory))
	var eq_pebble: Dictionary = GearDB.equipped("pebble")
	var eq_ember: Dictionary = GearDB.equipped("ember")
	if eq_pebble["weapon"] != "pebble.weapon.1" or eq_pebble["chest"] != "pebble.chest.1" or eq_pebble["charm"] != "":
		_fail("pebble migration equipped %s" % str(eq_pebble))
	if eq_ember["weapon"] != "ember.weapon.1":
		_fail("ember migration equipped %s" % str(eq_ember))
	for missing in ["pebble.charm.2", "pebble.weapon.2", "pebble.chest.2", "pebble.charm.3"]:
		if not GearDB.has("pebble", missing):
			_fail("migration lost gated piece %s" % missing)
	if not GearDB.has("ember", "ember.weapon.1") or GearDB.has("ember", "ember.chest.2"):
		_fail("migration granted the wrong ember pieces")
	if int(SaveGame.data["coins"]) != 40:
		_fail("unmapped legacy pieces did not pay 10 coins each, coins %d" % int(SaveGame.data["coins"]))
	if SaveGame.data.has("bag") or SaveGame.data.has("gear_uid") or SaveGame.data["heroes"]["pebble"].has("weapon"):
		_fail("migration left the legacy Loadout keys behind")
	var stamp: Dictionary = armory.duplicate(true)
	SaveGame.migrate_legacy_armory(2)
	if armory != stamp:
		_fail("migration ran twice")
	# (b) Equip math: a bare hero matches base stats; the geared deltas equal
	# the summed GearDB stats_for + level_bonus of what is on.
	GearDB.store_override = {}
	SaveGame.reset_new()
	var bare := SaveGame.build_run_stats("pebble")
	var base := Catalog.base_stats("pebble")
	if bare != base:
		_fail("bare hero run stats drifted from base: %s vs %s" % [str(bare), str(base)])
	var worn_ids: Array = ["pebble.helm.1", "pebble.weapon.2", "pebble.gloves.1", "pebble.boots.1"]
	for id in worn_ids:
		if not GearDB.grant(id):
			_fail("grant %s" % id)
	if GearDB.add_xp("pebble", "attack", GearDB.xp_for_level(20)) != 19:
		_fail("attack xp did not reach level 20")
	for id in worn_ids:
		if not GearDB.equip("pebble", id):
			_fail("equip %s" % id)
	var geared := SaveGame.build_run_stats("pebble")
	var want: Dictionary = GearDB.stats("pebble")
	var per: Dictionary = {}
	for id in worn_ids:
		for k in GearDB.item(id)["stats"]:
			per[k] = float(per.get(k, 0.0)) + float(GearDB.item(id)["stats"][k])
	for k in per:
		if not is_equal_approx(float(per[k]), float(want.get(k, 0.0))):
			_fail("GearDB.stats is not the sum of stats_for for %s" % k)
	for k in GearDB.level_bonus("pebble"):
		want[k] = float(want.get(k, 0.0)) + float(GearDB.level_bonus("pebble")[k])
	_folds(geared, bare, want, "hp", "add", "hp_flat")
	_folds(geared, bare, want, "armor", "add", "armor")
	_folds(geared, bare, want, "crit", "add", "crit")
	_folds(geared, bare, want, "regen", "add", "regen")
	_folds(geared, bare, want, "dmg", "mul", "dmg_pct")
	_folds(geared, bare, want, "interval", "div", "haste")
	_folds(geared, bare, want, "speed", "mul", "speed_pct")
	# (c) A rune piece with a level-1 skill stays owned and never equips.
	GearDB.store_override = {}
	if not GearDB.grant("pebble.boots.3"):
		_fail("grant gated rune boots")
	var gate: Dictionary = GearDB.can_equip("pebble", "pebble.boots.3")
	if bool(gate["ok"]) or str(gate["reason"]) != "Requires Defence 40":
		_fail("rune boots gate said %s" % str(gate))
	if GearDB.equip("pebble", "pebble.boots.3") or str(GearDB.equipped("pebble")["boots"]) != "":
		_fail("rune boots equipped through the gate")
	# (d) Save -> load round trip: JSON, reconcile and the (stamped) migration
	# pass must leave the armory byte-identical, unknown keys included.
	GearDB.store_override = null
	SaveGame.data["armory"] = {
		"v": 1,
		"owned": {"pebble": {"pebble.helm.1": 2, "pebble.chest.2": 1}},
		"equipped": {"pebble": {"helm": "pebble.helm.1", "weapon": "pebble.weapon.2"}, "ember": {}},
		"xp": {"pebble": {"attack": 4156, "hitpoints": 1154}},
		"migrated_from": 2,
		"future_unknown_key": {"hint": "survives"},
	}
	var want_armory: Dictionary = SaveGame.data["armory"].duplicate(true)
	var round_trip: Variant = JSON.parse_string(JSON.stringify(SaveGame.data))
	if typeof(round_trip) != TYPE_DICTIONARY:
		_fail("save round trip did not parse")
	else:
		SaveGame.data = round_trip
		SaveGame.data["save_version"] = SaveGame.VERSION
		SaveGame._reconcile()
		SaveGame.migrate_legacy_armory(2)
		# JSON.loads returns floats for every number; unify both sides the
		# same way so the comparison is about content, not float/int casts.
		# Unknown future keys and the migration stamp ride along untouched.
		var want_back: Variant = JSON.parse_string(JSON.stringify(want_armory))
		if SaveGame.data["armory"] != want_back:
			_fail("round trip lost armory content: %s" % str(SaveGame.data["armory"]))
	SaveGame.data = keep
	SaveGame.no_write = keep_no_write
	GearDB.store_override = keep_store
	print("GEAR ok: migration, equip math, gating, round-trip")


## One run-stat fold. mode "add": geared == bare + want[stat]. "mul":
## geared == bare * (1 + want[stat]). For "interval" want[stat] is haste and
## the bare interval divides through 1 + haste instead of multiplying.
static func _folds(geared: Dictionary, bare: Dictionary, want: Dictionary, key: String, mode: String, stat: String) -> void:
	var want_v := float(want.get(stat, 0.0))
	var expected := float(bare[key])
	match mode:
		"add":
			expected = float(bare[key]) + want_v
		"mul":
			expected = float(bare[key]) * (1.0 + want_v)
		"div":
			expected = float(bare[key]) / (1.0 + want_v)
	if not is_equal_approx(float(geared[key]), expected):
		_fail("%s fold off: gear %s vs expected %s (%s %s)" % [key, str(geared[key]), str(expected), mode, str(want_v)])

## Slayer and collection-log accounting on a scratch save: kills count once
## and only for the task's biome, a finished contract must pay exactly once,
## the warden never hands the same task back twice in 200 rolls and never sends
## the player to locked ground, and an old save with missing keys reconciles.
static func _slayer_log_check() -> void:
	var keep: Dictionary = SaveGame.data.duplicate(true)
	SaveGame.no_write = true
	# Kill accounting: a minion task counts its own biome's kills and clamps.
	SaveGame.data = SaveGame._fresh()
	SaveGame.assign_task("meadow_critters")
	SaveGame.commit_defeat("frost", 10)
	if int(SaveGame.data["slayer"]["task"].get("have", -1)) != 0:
		_fail("kills in the wrong biome advanced a task")
	SaveGame.commit_defeat("meadow", 30)
	if int(SaveGame.data["slayer"]["task"].get("have", -1)) != 30:
		_fail("kills did not advance the minion task")
	SaveGame.commit_defeat("meadow", 30)
	if int(SaveGame.data["slayer"]["task"].get("have", -1)) != 40:
		_fail("minion progress did not clamp at the goal")
	# A boss task only counts the boss, never the run's minion kills.
	SaveGame.assign_task("thistle_task")
	SaveGame.commit_defeat("meadow", 20)
	if int(SaveGame.data["slayer"]["task"].get("have", -1)) != 0:
		_fail("a defeat advanced a boss task")
	SaveGame.commit_victory("meadow", "thistle", 20)
	if int(SaveGame.data["slayer"]["task"].get("have", -1)) != 1:
		_fail("a boss kill did not advance the boss task")
	SaveGame.commit_victory("meadow", "thistle", 20)
	if int(SaveGame.data["slayer"]["task"].get("have", -1)) != 1:
		_fail("boss progress did not clamp at the goal")
	# A finished contract pays once; a second turn-in changes nothing.
	SaveGame.assign_task("meadow_critters")
	SaveGame.data["slayer"]["task"]["have"] = 40
	var before := int(SaveGame.data["slayer"]["points"])
	var paid := SaveGame.complete_task()
	if paid != 25:
		_fail("task payout %d, expected 25" % paid)
	if int(SaveGame.data["slayer"]["points"]) != before + 25:
		_fail("points were not paid exactly once")
	if SaveGame.complete_task() != 0:
		_fail("a cleared task paid a second time")
	if int(SaveGame.data["slayer"]["points"]) != before + 25:
		_fail("a cleared task changed the points")
	# 200 rolls: no back-to-back repeat and never a locked biome.
	SaveGame.data = SaveGame._fresh()
	var previous := ""
	for i in 200:
		var picked: Dictionary = SaveGame.assign_task()
		if picked.is_empty():
			_fail("assignment %d found no task" % i)
			break
		var id := str(picked["id"])
		if id == previous:
			_fail("assignment repeated %s back to back" % id)
			break
		if not SaveGame.biome_open(str(picked["biome"])):
			_fail("assignment %d chose locked biome %s" % [i, picked["biome"]])
			break
		previous = id
		SaveGame.data["slayer"]["task"]["have"] = int(picked.get("need", 1))
		SaveGame.complete_task()
	# Collection log: a first find is new until seen, and dead ids are skipped.
	SaveGame.data = SaveGame._fresh()
	SaveGame.data["log"] = ["thistle_purse", "ghost_of_a_dead_drop"]
	SaveGame.data["log_seen"] = []
	if not SaveGame.log_is_new("thistle_purse"):
		_fail("a fresh find should be marked new")
	if SaveGame.log_new_count() != 2:
		_fail("new log count %d, expected 2" % SaveGame.log_new_count())
	if SaveGame.log_obtained_count() != 1:
		_fail("a drop removed from the catalog should not be counted")
	SaveGame.log_mark_seen(["thistle_purse"])
	if SaveGame.log_is_new("thistle_purse"):
		_fail("a seen find should not stay new")
	# The log order is biome then rarity and stable between calls.
	var order: Array = Catalog.log_entries()
	if order.size() != Catalog.all_drops().size():
		_fail("log order lost entries: %d" % order.size())
	if str(order) != str(Catalog.log_entries()):
		_fail("log order is not stable between calls")
	# Old save: missing keys reconcile to defaults without a crash.
	SaveGame.data = {"log": ["thistle_purse"], "slayer": {"points": 7, "streak": 3}}
	SaveGame._reconcile()
	if not SaveGame.data["slayer"].has("task"):
		_fail("an old save did not gain an empty task")
	if int(SaveGame.data["slayer"]["points"]) != 7 or int(SaveGame.data["slayer"]["streak"]) != 3:
		_fail("an old save's slayer values were not kept")
	if not SaveGame.data.has("log_seen") or not ("thistle_purse" in SaveGame.data["log_seen"]):
		_fail("an old save's finds should start read")
	var empty: Dictionary = SaveGame.assign_task()
	if empty.is_empty():
		_fail("assign after an old-save reconcile failed")
	elif not SaveGame.biome_open(str(empty["biome"])):
		_fail("old-save assign chose a locked biome")
	SaveGame.data = keep
	SaveGame.no_write = false
	print("SLAYER LOG ok: 200 assignments, single claim, old-save defaults")
## Settings + accessibility: an old save's defaults, persistence through
## set_setting, survival of a restart (reload from SaveGame.data), and
## clamping of corrupt or out-of-range values. Runs on an in-memory copy
## with SaveGame.no_write set, then restores both the data and the volume mix.
static func _settings_check() -> void:
	var keep: Dictionary = SaveGame.data.duplicate(true)
	SaveGame.no_write = true
	# (1) Defaults on an old save: no settings block in the save at all.
	SaveGame.data["settings"] = {}
	AudioDirector._load_settings()
	for key in AudioDirector.DEFAULTS:
		if not AudioDirector.settings.has(key):
			_fail("settings default missing " + str(key))
	if float(AudioDirector.settings["music_vol"]) != 0.8 or float(AudioDirector.settings["sfx_vol"]) != 0.9:
		_fail("volume defaults moved")
	if not bool(AudioDirector.settings["music_on"]) or not bool(AudioDirector.settings["sfx_on"]) or not bool(AudioDirector.settings["haptics_on"]):
		_fail("toggle defaults should be on")
	if float(AudioDirector.settings["screen_shake"]) != 1.0:
		_fail("screen shake default should be full")
	if bool(AudioDirector.settings["reduce_flashing"]) or bool(AudioDirector.settings["left_handed"]):
		_fail("reduce flashing / left-handed default should be off")
	if not bool(AudioDirector.settings["damage_numbers"]):
		_fail("damage numbers default should be on")
	if int(AudioDirector.settings["text_size"]) != 100:
		_fail("text size default should be 100%")
	# (2) Round-trip: set_setting persists into SaveGame.data and a fresh
	# _load_settings (the restart path) reads the same values back.
	AudioDirector.set_setting("music_vol", 0.25)
	AudioDirector.set_setting("damage_numbers", false)
	AudioDirector.set_setting("text_size", 130)
	AudioDirector.set_setting("screen_shake", 0.4)
	if float(SaveGame.data["settings"]["music_vol"]) != 0.25 or bool(SaveGame.data["settings"]["damage_numbers"]):
		_fail("set_setting did not persist into the save block")
	AudioDirector._load_settings()
	if float(AudioDirector.settings["music_vol"]) != 0.25:
		_fail("music volume did not survive reload")
	if bool(AudioDirector.settings["damage_numbers"]):
		_fail("damage numbers did not survive reload")
	if int(AudioDirector.settings["text_size"]) != 130:
		_fail("text size did not survive reload")
	if float(AudioDirector.settings["screen_shake"]) <= 0.39 or float(AudioDirector.settings["screen_shake"]) >= 0.41:
		_fail("screen shake readback lost precision")
	# (3) Clamping: garbage values from a hand-edited save land in range and
	# keep their type, so _apply()'s arithmetic can never see a string.
	SaveGame.data["settings"] = {"music_vol": 9.0, "sfx_vol": -3.0, "text_size": 4, "screen_shake": 7.0, "music_on": 1, "haptics_on": "water"}
	AudioDirector._load_settings()
	if float(AudioDirector.settings["music_vol"]) != 1.0 or float(AudioDirector.settings["sfx_vol"]) != 0.0:
		_fail("volume clamping")
	if float(AudioDirector.settings["screen_shake"]) != 1.0:
		_fail("screen shake clamping")
	if int(AudioDirector.settings["text_size"]) != 100:
		_fail("text size clamping")
	if not bool(AudioDirector.settings["music_on"]) or not bool(AudioDirector.settings["haptics_on"]):
		_fail("switch clamping")
	# Restore: the save data and the live mix return to their pre-check state.
	SaveGame.data = keep
	SaveGame.no_write = false
	AudioDirector._load_settings()
	print("SETTINGS ok: defaults, round-trip, clamping")


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


## Blessing exclusivity: for every role on the hero roster (derived from
## Catalog.CRITTERS, never hard-coded ids) 3000 seeded offers with random
## stacks must stay inside that role's class pool or the general pool, pass
## role_can_take (a melee tank never sees a Shot-only card), and only fall back
## to "snack" when no legal card is left. Each hero must carry a real role.
static func _exclusivity_check() -> void:
	var roles := {}
	for id in Catalog.CRITTERS.keys():
		var entry: Dictionary = Catalog.CRITTERS[id]
		if str(entry.get("kind", "")) != "hero":
			continue
		var role := str(entry.get("role", ""))
		if role != "tank" and role != "archer" and role != "mage":
			_fail("hero %s has unknown role %s" % [id, role])
			return
		roles[role] = true
	if roles.is_empty():
		_fail("no playable hero roles found")
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260101
	for role in roles.keys():
		var general := 0
		var class_n := 0
		for entry in Catalog.CARDS:
			var cid := str(entry["id"])
			if not Catalog.role_can_take(role, cid):
				continue
			if Catalog.pool_of(cid) == "general":
				general += 1
			elif Catalog.pool_of(cid) == role:
				class_n += 1
		if general < 14:
			_fail("%s only has %d legal general cards" % [role, general])
			return
		if class_n < 6:
			_fail("%s only has %d legal class cards" % [role, class_n])
			return
		for _i in 3000:
			var stacks := {}
			for entry in Catalog.CARDS:
				stacks[str(entry["id"])] = rng.randi_range(0, int(entry["max"]))
			var offer: Array = Catalog.roll_offer(role, stacks, rng)
			if offer.size() != 3:
				_fail("%s offer size %d" % [role, offer.size()])
				return
			var left := _legal_card_left(role, stacks, offer)
			for id in offer:
				var sid := str(id)
				if sid == "snack":
					if left:
						_fail("%s offered snack while legal cards remain" % role)
						return
					continue
				if not Catalog.role_can_take(role, sid):
					_fail("%s offered %s its attack style cannot use" % [role, sid])
					return
				var pool := Catalog.pool_of(sid)
				if pool != "general" and pool != role:
					_fail("%s offered %s from %s" % [role, sid, pool])
					return
	print("EXCLUSIVITY ok, roles %s" % str(roles.keys()))


## True when a legal card (role pool or general, role_can_take, under max and
## not already in this offer) is still available.
static func _legal_card_left(role: String, stacks: Dictionary, offer: Array) -> bool:
	for entry in Catalog.CARDS:
		var cid := str(entry["id"])
		if cid in offer:
			continue
		if not Catalog.role_can_take(role, cid):
			continue
		var pool := Catalog.pool_of(cid)
		if pool != "general" and pool != role:
			continue
		if int(stacks.get(cid, 0)) < int(entry["max"]):
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
			print("TRACE %s/%d t=%d hp=%d pos=%s mv=%s phase=%s boss=%s goal=%s" % [hero, session.seed, int(sim.time), int(h.hp), str(h.pos.round()), str(mv.snapped(Vector2(0.01, 0.01))), sim.phase, str(bosses), str(mem.get("goal", ""))])
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
		"skill_xp": sim.skill_xp.duplicate(true),
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


## 20-seed explore sweep, one representative hero per role, on "meadow":
## reports wins/timeouts/losses and the average winning time. Zero timeouts
## means the bot always found a route to the lair. Losses are balance, not
## pathing, and are only reported.
##   godot --path . -- --sim-check --seed-sweep
static func seed_sweep() -> void:
	var reps := {"tank": "pebble", "archer": "juniper", "mage": "ember"}
	for role in ["tank", "archer", "mage"]:
		var hero: String = reps[role]
		var wins := 0
		var timeouts := 0
		var losses := 0
		var win_times: Array = []
		var hp_left: Array = []
		for seed in range(1, 21):
			var report := _play(hero, "meadow", seed, false)
			var result := str(report["result"])
			var taken := float(report["time"])
			if result == "win":
				wins += 1
				win_times.append(taken)
				hp_left.append(float(report["hp"]))
			else:
				if result == "":
					timeouts += 1
				else:
					losses += 1
				print("SWEEP-FAIL %s seed %d result %s time %.1f" % [role, seed, result, taken])
		var avg_t := 0.0
		var min_t := 0.0
		var max_t := 0.0
		var avg_hp := 0.0
		if not win_times.is_empty():
			for v in win_times:
				avg_t += float(v)
			avg_t /= win_times.size()
			min_t = win_times.min()
			max_t = win_times.max()
			for v in hp_left:
				avg_hp += float(v)
			avg_hp /= hp_left.size()
		print("SWEEP %s wins %d/20 timeouts %d losses %d avg_win_time %.1f min %.1f max %.1f avg_hp_left %.1f" % [role, wins, timeouts, losses, avg_t, min_t, max_t, avg_hp])


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


## Gear drops: a seeded run rolls identical loot, banking grants each earned
## piece exactly once (a win keeps all, a loss keeps half), and every rolled id
## is a real item. Runs on a scratch armory so the player's save is untouched.
static func _gear_drop_smoke() -> void:
	var prev_override: Variant = GearDB.store_override
	var prev_nowrite: bool = SaveGame.no_write
	GearDB.store_override = {}
	SaveGame.no_write = true
	var sources := ["camp", "elite", "boss", "goblin", "chest_common", "chest_epic"]
	var a := _sim("meadow", "ember", 11)
	var b := _sim("meadow", "ember", 11)
	for sim in [a, b]:
		for source in sources:
			sim._gear_roll_drop(source, Vector2.ZERO)
	if a.gear_found.is_empty():
		_fail("a seeded run rolled no gear")
	if str(a.gear_found) != str(b.gear_found):
		_fail("gear drops are not deterministic for a seed")
	for id in a.gear_found:
		if not GearDB.is_item(str(id)):
			_fail("rolled a non-item gear id " + str(id))
	a.result = "win"
	a.bank_gear()
	if _owned_total() != a.gear_found.size():
		_fail("a win did not bank every drop")
	a.bank_gear()
	if _owned_total() != a.gear_found.size():
		_fail("gear banked twice")
	GearDB.store_override = {}
	var c := _sim("meadow", "ember", 11)
	for source in sources:
		c._gear_roll_drop(source, Vector2.ZERO)
	c.result = "lose"
	c.bank_gear()
	if _owned_total() != c.gear_found.size() / 2:
		_fail("a loss did not keep half the drops")
	GearDB.store_override = prev_override
	SaveGame.no_write = prev_nowrite
	print("GEAR smoke ok: %d drops banked" % a.gear_found.size())


## Combat-skill XP: a melee RunBot fight trains Attack and Strength, a mage
## fight trains Magic, committing writes the XP exactly once, and the commit
## queues a skill_up event per level gained. Runs on a scratch armory.
static func _skill_xp_smoke() -> void:
	var prev_override: Variant = GearDB.store_override
	var prev_nowrite: bool = SaveGame.no_write
	GearDB.store_override = {}
	SaveGame.no_write = true
	var melee := _fight_xp("pebble", 11)
	var melee_row: Dictionary = melee.skill_xp.get("pebble", {})
	if float(melee_row.get("attack", 0.0)) <= 0.0 or float(melee_row.get("strength", 0.0)) <= 0.0:
		_fail("melee fight trained no Attack/Strength")
	var mage := _fight_xp("ember", 11)
	var mage_row: Dictionary = mage.skill_xp.get("ember", {})
	if float(mage_row.get("magic", 0.0)) <= 0.0:
		_fail("mage fight trained no Magic")
	# Top up so the commit is guaranteed to gain a level and queue the event.
	melee.skill_xp["pebble"]["attack"] = float(melee_row.get("attack", 0.0)) + 5000.0
	melee.bank_gear()
	var total := _skill_total()
	if total <= 0:
		_fail("committing a fight granted no skill XP")
	melee.bank_gear()
	if _skill_total() != total:
		_fail("skill XP committed twice")
	var ups := 0
	for ev in melee.drain_events():
		if str(ev.get("type", "")) == "skill_up":
			ups += 1
	if ups <= 0:
		_fail("committing queued no skill_up event")
	GearDB.store_override = prev_override
	SaveGame.no_write = prev_nowrite
	print("SKILL xp smoke ok: %d xp, %d level-ups" % [total, ups])


## A short RunBot hunt for the skill-XP smoke: enough fighting to train the
## hero, without waiting for a full clear.
static func _fight_xp(hero: String, seed: int) -> RunSim:
	var sim := _sim("meadow", hero, seed)
	var mem := {}
	var guard := 0
	while sim.result == "" and guard < 60 * 120:
		guard += 1
		if sim.paused and sim.offer.size() > 0:
			sim.choose(_best(sim))
			sim.drain_events()
			continue
		if sim.paused:
			break
		var mv := RunBot.explore_steer(sim, 0, mem) if sim.explore else RunBot.steer(sim, 0)
		sim.step(1.0 / 60.0, [mv])
		sim.drain_events()
	return sim


## Total XP held in the current GearDB store (a scratch armory in tests).
static func _skill_total() -> int:
	var total := 0
	var xp: Dictionary = GearDB._store()["xp"]
	for hero in xp:
		for skill in xp[hero]:
			total += int(xp[hero][skill])
	return total


## Gear coverage sweep (docs/gear.md contract). Everything runs on a scratch
## armory (GearDB.store_override = {}) with SaveGame.no_write; both restore
## after so the player's save never moves. Sub-checks:
## 1-3  drop rates over 20000 seeded rolls per source, hero targeting and the
##      owned-out reroll preference,
## 4-5  seed determinism of gear and combat, pickup pacing of the run events,
## 6    equip stat math for full tier-1/2/3 kits and the exact gate text,
## 7    banking: a win keeps all, a loss keeps the earliest floor-half once.
static func _gear_coverage_check() -> void:
	var keep: Dictionary = SaveGame.data.duplicate(true)
	var keep_no_write: bool = SaveGame.no_write
	var keep_store: Variant = GearDB.store_override
	SaveGame.no_write = true
	_gear_loot_rates()
	_gear_equip_math()
	_gear_runs()
	_gear_bank()
	SaveGame.data = keep
	SaveGame.no_write = keep_no_write
	GearDB.store_override = keep_store


## 1-3. 20000 seeded rolls per source on a scratch armory: observed drop
## chance and tier split stay within tolerance of SOURCES, the boss never
## rolls empty, a deeper biome never lowers the rune share, the run hero
## keeps its 75% coin share plus its 1/4 slice of the uniform fallback
## (about 81% of the pieces, see loot_table.gd _pick) on legal slots (Gnash
## never gets an offhand), and because the hero owns nearly all of one tier
## the owned-out rerolls keep duplicates well under the uniform rate.
static func _gear_loot_rates() -> void:
	GearDB.store_override = {}
	var run_hero := "ember"
	## The hero owns everything except two tier-2 slots: a tier-2 pick should
	## end owned only if all four uniform slot attempts miss the two holes
	## (about 1 - (6/8)^4 of such picks), versus 6/8 without preference.
	var unowned := ["ember.helm.2", "ember.boots.2"]
	for id in GearDB.all_items():
		if str(id) in unowned:
			continue
		GearDB.grant(str(id))
	var rng := RandomNumberGenerator.new()
	rng.seed = 701
	var rolls := 20000
	var items := 0
	var hero_kept := 0
	var dup_total := 0
	var dup_owned := 0
	for source in LootTable.SOURCES.keys():
		var data: Dictionary = LootTable.SOURCES[source]
		var weights: Array = data["weights"]
		var weight_sum: float = float(weights[0]) + float(weights[1]) + float(weights[2])
		var drops := 0
		var tiers := [0, 0, 0]
		for _i in rolls:
			var rolled: Array[String] = LootTable.roll(rng, str(source), run_hero, 0)
			if not rolled.is_empty():
				drops += 1
				if str(source) == "boss" and rolled.size() < 1:
					_fail("boss rolled zero pieces")
			for id in rolled:
				var sid := str(id)
				var parts := sid.split(".")
				if not GearDB.is_item(sid) or not (str(parts[1]) in GearDB.HERO_SLOTS[str(parts[0])]):
					_fail("%s is not a real item on a legal slot" % sid)
					continue
				if str(parts[1]) == "offhand" and str(parts[0]) == "lumen":
					_fail("Gnash rolled an offhand piece")
				if str(parts[0]) == run_hero:
					hero_kept += 1
					if int(parts[2]) == 2:
						dup_total += 1
						if str(parts[1]) != "helm" and str(parts[1]) != "boots":
							dup_owned += 1
				tiers[int(parts[2]) - 1] += 1
				items += 1
		var observed: float = float(drops) / float(rolls)
		if absf(observed - float(data["chance"])) > 0.015:
			_fail("%s drop chance %.3f off %.3f" % [str(source), observed, float(data["chance"])])
		var source_items: int = tiers[0] + tiers[1] + tiers[2]
		for t in 3:
			var share: float = float(tiers[t]) / float(maxi(source_items, 1))
			if absf(share - float(weights[t]) / weight_sum) > 0.02:
				_fail("%s tier %d share %.3f off %.3f" % [str(source), t + 1, share, float(weights[t]) / weight_sum])
	# A deeper biome must never lower the rune share of any source.
	var deep: int = Catalog.BIOMES.size() - 1
	for source in LootTable.SOURCES.keys():
		var base: Array = LootTable.SOURCES[source]["weights"]
		if _rune_share(base, deep) < _rune_share(base, 0) - 0.000001:
			_fail("biome depth lowered the rune share of %s" % str(source))
	var hero_share := float(hero_kept) / float(maxi(items, 1))
	# Effective keep share: the run hero wins its 75% coin plus its 1/4 of
	# the uniform fallback (the fallback draws among ALL gear heroes,
	# including itself, exactly as docs/gear.md describes).
	var expect_share: float = LootTable.RUN_HERO_SHARE + (1.0 - LootTable.RUN_HERO_SHARE) / float(GearDB.HERO_SLOTS.size())
	if absf(hero_share - expect_share) > 0.03:
		_fail("the run hero kept %.3f of the gear" % hero_share)
	var dup_rate := float(dup_owned) / float(maxi(dup_total, 1))
	if dup_rate < 0.15 or dup_rate > 0.45:
		_fail("duplicate rate %.3f is not well under the uniform rate" % dup_rate)
	if items <= 0:
		_fail("nothing rolled at all")
	print("GEAR rates ok: %d pieces, run hero %.0f%% (%.0f%% coin, rest uniform), dups %.0f%% (uniform 75%%)" % [items, hero_share * 100.0, LootTable.RUN_HERO_SHARE * 100.0, dup_rate * 100.0])


## Exact rune share of a tier-weight triple after LootTable's biome shift.
static func _rune_share(base: Array, biome_idx: int) -> float:
	var w: Array = LootTable._weights(base, biome_idx)
	return float(w[2]) / (float(w[0]) + float(w[1]) + float(w[2]))


## 6. Equip math: a full tier-1/2/3 kit for every gear hero folds the exact
## stats_for sums plus the level hook into build_run_stats, and a gated
## piece below the level refuses with its exact lock text.
static func _gear_equip_math() -> void:
	for hero in GearDB.HERO_SLOTS.keys():
		for tier in [GearDB.Tier.IRON, GearDB.Tier.STEEL, GearDB.Tier.RUNE]:
			_gear_full_kit(str(hero), int(tier))
	print("GEAR equip ok: full tier-1/2/3 kits fold stats_for + level_bonus")


## One full kit on a fresh scratch store: gate text at starting skills, then
## skills raised via add_xp to the tier's requirement, and the equipped
## run-stat deltas matched field by field through _folds.
static func _gear_full_kit(hero: String, tier: int) -> void:
	GearDB.store_override = {}
	var bare := SaveGame.build_run_stats(hero)
	if tier >= GearDB.Tier.STEEL:
		for slot in GearDB.HERO_SLOTS[hero]:
			var gid: String = GearDB.item_id(hero, str(slot), tier)
			var req: Dictionary = GearDB.requirements(gid)
			if req.is_empty():
				continue
			# The gate check needs the piece owned so "Not owned" can't mask
			# the requirement reason; a duplicate grant is harmless here.
			GearDB.grant(gid)
			var gate: Dictionary = GearDB.can_equip(hero, gid)
			if bool(gate["ok"]) or str(gate["reason"]) != _gear_req_text(req):
				_fail("%s gate said %s, wanted %s" % [gid, str(gate), str(_gear_req_text(req))])
			if GearDB.equip(hero, gid) or str(GearDB.equipped(hero)[str(slot)]) != "":
				_fail("%s equipped below its level gate" % gid)
	var lvl: int = GearDB.REQ_BY_TIER[tier]
	for k in GearDB.SKILL_KEYS:
		if GearDB.level(hero, k) < lvl:
			GearDB.add_xp(hero, k, GearDB.xp_for_level(lvl) - GearDB.xp(hero, k))
		if GearDB.level(hero, k) < lvl:
			_fail("%s %s did not reach level %d" % [hero, k, lvl])
	var want := {}
	for slot in GearDB.HERO_SLOTS[hero]:
		var gid: String = GearDB.item_id(hero, str(slot), tier)
		if not GearDB.grant(gid) or not bool(GearDB.can_equip(hero, gid)["ok"]) or not GearDB.equip(hero, gid):
			_fail("the %s kit refused %s" % [hero, gid])
			continue
		if str(GearDB.equipped(hero)[str(slot)]) != gid or GearDB.slot_tier(hero, str(slot)) != tier:
			_fail("%s did not seat in %s" % [gid, str(slot)])
		var s: Dictionary = GearDB.stats_for(str(slot), tier)
		for k in s:
			want[k] = float(want.get(k, 0.0)) + float(s[k])
	for k in GearDB.level_bonus(hero):
		want[k] = float(want.get(k, 0.0)) + float(GearDB.level_bonus(hero)[k])
	var geared := SaveGame.build_run_stats(hero)
	_folds(geared, bare, want, "hp", "add", "hp_flat")
	_folds(geared, bare, want, "armor", "add", "armor")
	_folds(geared, bare, want, "crit", "add", "crit")
	_folds(geared, bare, want, "regen", "add", "regen")
	_folds(geared, bare, want, "dmg", "mul", "dmg_pct")
	_folds(geared, bare, want, "interval", "div", "haste")
	_folds(geared, bare, want, "speed", "mul", "speed_pct")


## "Requires <Skill> <level>" for the first gate in can_equip's order — the
## exact text the equip UI shows on owned, locked pieces.
static func _gear_req_text(req: Dictionary) -> String:
	for k in GearDB.SKILL_KEYS:
		if req.has(k):
			return "Requires %s %d" % [GearDB.SKILL_NAMES[GearDB.SKILL_KEYS.find(k)], int(req[k])]
	return ""


## 4-5. Runs. The same seed replays identical gear_found and combat, another
## seed diverges (checked on two 60 s windows), and a full bot run to the
## result picks every drop up exactly once unless it still lies in
## gear_ground. Every source is seeded once 10 s in so the loot hooks run
## even on a short window.
static func _gear_runs() -> void:
	GearDB.store_override = {}
	var quick := int(60.0 * 60.0)
	var full := int(60.0 * 400.0)
	var a := _gear_run(11, quick)
	if str(a["gear"]) == "":
		_fail("the seeded run rolled no gear")
	if _gear_run_key(a) != _gear_run_key(_gear_run(11, quick)):
		_fail("the same seed did not replay the same run")
	if _gear_run_key(_gear_run(12, quick)) == _gear_run_key(a):
		_fail("a different seed replayed the same run")
	var win := _gear_run(11, full)
	var win2 := _gear_run(11, full)
	if str(win["result"]) != "win":
		_fail("the full seeded bot run ended %s" % str(win["result"]))
	if _gear_run_key(win) != _gear_run_key(win2):
		_fail("the same seed did not replay the same combat outcome")
	_gear_pickup_flow(win)
	print("GEAR run ok: seeds replay identical, win %s at %.0fs with %s picked" % [str(win["result"]), float(win["time"]), str(win["gear"])])


## One bot-driven sample run: explore steering with greedy level-ups, and
## one seeded roll from every loot source 10 s in. Returns the combat
## counters, the gear list, and the drop/pickup/leftover key tallies.
static func _gear_run(seed: int, cap: int) -> Dictionary:
	var session := Session.solo("meadow", "ember")
	session.seed = seed
	var sim := RunSim.new()
	sim.start(session, {"ember": Catalog.base_stats("ember")})
	var drops := {}
	var pickups := {}
	var mem := {}
	var seeded := false
	var guard := 0
	while sim.result == "" and guard < cap:
		guard += 1
		if sim.paused:
			if sim.offer.size() > 0:
				sim.choose(_best(sim))
				sim.drain_events()
			else:
				return {"gear": str(sim.gear_found), "kills": sim.kills, "hp": float(sim.heroes[0].hp),
					"result": "stuck", "time": sim.time, "drops": drops, "pickups": pickups, "left": ""}
			continue
		if guard == int(10.0 / STEP) and not seeded:
			seeded = true
			for source in LootTable.SOURCES:
				sim._gear_roll_drop(str(source), sim.heroes[0].pos)
		var mv := RunBot.explore_steer(sim, 0, mem) if sim.explore else RunBot.steer(sim, 0)
		sim.step(STEP, [mv])
		for e in sim.drain_events():
			match str(e.get("type", "")):
				"gear_drop":
					var drop_key := str(e.get("key", ""))
					drops[drop_key] = int(drops.get(drop_key, 0)) + 1
				"gear_pickup":
					var pick_key := str(e.get("key", ""))
					pickups[pick_key] = int(pickups.get(pick_key, 0)) + 1
	var hp := 0.0
	if sim.heroes.size() > 0:
		hp = float(sim.heroes[0].hp)
	var left := ""
	for g in sim.gear_ground:
		left += "\"%s\"" % str(g["key"])
	return {"gear": str(sim.gear_found), "kills": sim.kills, "hp": hp, "result": sim.result,
		"time": sim.time, "drops": drops, "pickups": pickups, "left": left}


## A run signature: gear list plus the combat outcome (time, kills, hp).
static func _gear_run_key(r: Dictionary) -> String:
	return "%s|%s|%s|%s|%s" % [str(r["gear"]), str(r["kills"]), str(r["hp"]), str(r["result"]), str(r["time"])]


## Every gear_drop event resolves to exactly one gear_pickup event with the
## same key, unless the piece is still lying in gear_ground at run end.
static func _gear_pickup_flow(r: Dictionary) -> void:
	var drops: Dictionary = r["drops"]
	var picks: Dictionary = r["pickups"]
	var left: String = str(r["left"])
	for key in drops.keys():
		if int(drops[key]) != 1:
			_fail("drop key %s repeated" % str(key))
			return
	for key in picks.keys():
		if not drops.has(key):
			_fail("a gear_pickup had no matching gear_drop")
			return
		if int(picks[key]) != 1:
			_fail("pickup key %s repeated" % str(key))
			return
	for key in drops.keys():
		if not picks.has(key) and not left.contains("\"%s\"" % str(key)):
			_fail("drop %s was never picked up" % str(key))
			return


## 7. Banking: a win keeps every drop, a loss keeps the earliest floor-half
## and nothing more, a repeat call banks nothing, and the real save never
## sees a write (the scratch armory is still the store override after).
static func _gear_bank() -> void:
	GearDB.store_override = {}
	SaveGame.no_write = true
	var snapshot: Dictionary = SaveGame.data.duplicate(true)
	var ids: Array[String] = ["pebble.helm.1", "pebble.chest.1", "pebble.weapon.2", "pebble.boots.1", "ember.charm.1"]
	var win := RunSim.new()
	win.result = "win"
	for id in ids:
		win.gear_found.append(id)
	if str(win.bank_gear()) != str(ids) or _owned_total() != ids.size():
		_fail("a win did not bank every drop")
	if win.bank_gear().size() != 0 or _owned_total() != ids.size():
		_fail("a repeat bank call changed the armory")
	GearDB.store_override = {}
	var lose := RunSim.new()
	lose.result = "lose"
	for id in ids:
		lose.gear_found.append(id)
	var kept: Array[String] = lose.bank_gear()
	if str(kept) != str(ids.slice(0, ids.size() / 2)) or _owned_total() != ids.size() / 2:
		_fail("a loss did not keep the earliest floor-half: %s" % str(kept))
	if lose.bank_gear().size() != 0 or _owned_total() != ids.size() / 2:
		_fail("a repeat loss bank call changed the armory")
	for late in ["pebble.weapon.2", "pebble.boots.1", "ember.charm.1"]:
		if GearDB.has("pebble", late) or GearDB.has("ember", late):
			_fail("a banked loss kept the tail piece %s" % late)
	if SaveGame.data != snapshot or GearDB.store_override == null:
		_fail("banking wrote the real save")
	print("GEAR bank ok: win %d, loss %d earliest-first, second call banks nothing" % [ids.size(), ids.size() / 2])


## Total copies held in the current GearDB store (a scratch armory in tests).
static func _owned_total() -> int:
	var total := 0
	var owned: Dictionary = GearDB._store()["owned"]
	for hero in owned:
		for id in owned[hero]:
			total += int(owned[hero][id])
	return total


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
