class_name SimCheck
extends RefCounted

static var failures := 0
## --quick trims the long RunBot fights and the seeded statistical sweeps so a
## dev loop finishes in under a minute; default (no flags) is unchanged.
static var quick := false
## --only=<name,...> runs a subset of CHECKS by their short tag.
static var only: Array = []
## --timings prints per-check elapsed ms and the top five at the end.
static var timings := false
static var _times: Array = []

## Every check in run order. The name is the --only tag and the --timings label.
const CHECKS := [
	"roles", "modes", "save", "gear_save", "train", "slayer_log", "slayer_gear", "settings",
	"save_safety", "daily", "steer", "maps", "cards", "pools", "exclusivity", "fights",
	"kite", "boss_intro", "dodge", "events", "gear_drop", "skill_xp", "gear_coverage",
	"skills_screen", "xp_drop", "skill_trophies", "end_card", "drops_names", "gear_log",
	"forge", "boss_gear", "home_pips", "hints", "grim_names", "pacing_scale",
	"difficulty",
]
## run_screen.gd has no class_name; its inner HintLayer is reached through the
## preloaded script constant so the pure trigger helper can be tested.
const RunScreenScript := preload("res://scripts/run_screen.gd")


static func run() -> int:
	failures = 0
	_times = []
	var args := OS.get_cmdline_user_args()
	if not quick:
		quick = args.has("--quick")
	if not timings:
		timings = args.has("--timings")
	only = []
	for arg in args:
		if arg.begins_with("--only="):
			only = arg.substr(7).split(",", false)
	if args.has("--class-report"):
		class_report(_class_tag())
	if args.has("--pacing"):
		pacing(_class_tag())
		return 0
	for name in CHECKS:
		if not only.is_empty() and name not in only:
			continue
		var t0 := Time.get_ticks_usec()
		_dispatch(name)
		var ms := float(Time.get_ticks_usec() - t0) / 1000.0
		_times.append([name, ms])
		if timings:
			print("TIME ", name, " ", int(round(ms)), " ms")
	if timings:
		_report_timings()
	if failures == 0:
		print("SIM CHECK PASSED")
		return 0
	print("SIM CHECK FAILED ", failures)
	return 1


static func _dispatch(name: String) -> void:
	match name:
		"roles":
			_roles()
		"modes":
			_modes()
		"save":
			_save()
		"gear_save":
			_gear_save_check()
		"train":
			_train_check()
		"slayer_log":
			_slayer_log_check()
		"slayer_gear":
			_slayer_gear_check()
		"settings":
			_settings_check()
		"save_safety":
			_save_safety_check()
		"daily":
			_daily_check()
		"steer":
			_steer()
		"maps":
			_maps()
		"cards":
			_cards()
		"grim_names":
			_grim_names_check()
		"pools":
			_pools_check()
		"exclusivity":
			_exclusivity_check()
		"drops_names":
			_drops_names_check()
		"fights":
			_fights()
			if OS.get_cmdline_user_args().has("--seed-sweep"):
				seed_sweep()
		"kite":
			_kite()
		"boss_intro":
			_boss_intro_check()
		"dodge":
			_dodge_check()
		"events":
			_events_check()
		"gear_drop":
			_gear_drop_smoke()
		"boss_gear":
			_boss_gear_check()
		"skill_xp":
			_skill_xp_smoke()
		"xp_drop":
			_xp_drop_check()
		"skill_trophies":
			_skill_trophy_check()
		"pacing_scale":
			_pacing_scale_check()
		"difficulty":
			_difficulty_check()
		"gear_coverage":
			_gear_coverage_check()
		"skills_screen":
			_skills_screen_check()
		"end_card":
			_end_card_check()
		"gear_log":
			_gear_log_check()
		"forge":
			_forge_check()
		"home_pips":
			_home_pips_check()
		"hints":
			_hints_check()
		_:
			_fail("unknown check " + name)


## Top five slowest checks, so a profile is one line away from the run.
static func _report_timings() -> void:
	var ranked: Array = _times.duplicate()
	ranked.sort_custom(func(a: Variant, b: Variant) -> bool: return float(a[1]) > float(b[1]))
	print("TIMINGS top ", mini(5, ranked.size()), ":")
	for i in mini(5, ranked.size()):
		print("  ", i + 1, ". ", ranked[i][0], " ", int(round(float(ranked[i][1]))), " ms")


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
		for _i in (200 if quick else 700):
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
	var wallet_before := int(SaveGame.data["coins"])
	var loot := SaveGame.open_next()
	if int(loot.get("coins", 0)) <= 0 or not loot.get("cards", []).is_empty():
		_fail("chest loot should pay coins, not relics")
	if int(SaveGame.data["coins"]) - wallet_before != int(loot["coins"]):
		_fail("relic drops did not bank as coins")
	# Relics no longer buy levels: power comes from trained skills. A fresh
	# hero matches base stats, and banked Strength/Hitpoints xp raise hp/damage.
	var base_hp := float(Catalog.base_stats("ember")["hp"])
	var base_dmg := float(Catalog.base_stats("ember")["dmg"])
	var bare := SaveGame.build_run_stats("ember")
	if float(bare["hp"]) != base_hp or float(bare["dmg"]) != base_dmg:
		_fail("fresh hero did not match base stats")
	GearDB.add_xp("ember", "strength", GearDB.xp_for_level(20))
	GearDB.add_xp("ember", "hitpoints", GearDB.xp_for_level(20))
	var trained := SaveGame.build_run_stats("ember")
	if float(trained["hp"]) <= base_hp or float(trained["dmg"]) <= base_dmg:
		_fail("training did not scale hp and damage")
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
	_folds_pct_add(geared, bare, want, "hp", "hp_pct", "hp_flat")
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


## Combined hp fold, matching build_run_stats' order: the percentage applies to
## the bare value first, the flat lands after. geared == bare * (1 + pct) + flat.
static func _folds_pct_add(geared: Dictionary, bare: Dictionary, want: Dictionary, key: String, pct: String, flat: String) -> void:
	var expected := float(bare[key]) * (1.0 + float(want.get(pct, 0.0))) + float(want.get(flat, 0.0))
	if not is_equal_approx(float(geared[key]), expected):
		_fail("%s fold off: gear %s vs expected %s (%s + %s)" % [key, str(geared[key]), str(expected), pct, flat])


## Slayer and collection-log accounting on a scratch save: kills count once
## and only for the task's biome, a finished contract must pay exactly once,
## the warden never hands the same task back twice (200 rolls, 40 with --quick)
## and never sends the player to locked ground, and an old save with missing
## keys reconciles.
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
	# Seeded rolls: no back-to-back repeat and never a locked biome.
	SaveGame.data = SaveGame._fresh()
	var previous := ""
	var rolls := 40 if quick else 200
	for i in rolls:
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
	print("SLAYER LOG ok: %d assignments, single claim, old-save defaults" % rolls)


## Slayer rewards stay on the GearDB armory: the Warden's cache sells the
## featured hero exactly one legal iron/steel piece and deducts its cost, the
## 5th consecutive turn-in grants one piece the same way (the 6th grants
## nothing), rune tier is never granted, and a hero who owns every eligible
## piece is paid coins instead. Runs on a scratch armory and restores
## everything afterwards.
static func _slayer_gear_check() -> void:
	var keep: Dictionary = SaveGame.data.duplicate(true)
	var keep_no_write: bool = SaveGame.no_write
	var keep_store: Variant = GearDB.store_override
	SaveGame.no_write = true
	var offer := Catalog.slayer_offer("wardens_cache")
	if offer.is_empty() or str(offer["kind"]) != "gear" or int(offer["cost"]) <= 0:
		_fail("the Warden's cache offer disappeared")
		return
	# (1) Buying the cache: exactly one valid piece for the featured hero,
	# always iron or steel, at the listed cost.
	SaveGame.data = SaveGame._fresh()
	GearDB.store_override = {}
	var hero := SaveGame.featured_id()
	SaveGame.data["slayer"]["points"] = int(offer["cost"])
	if not SaveGame.buy_slayer("wardens_cache"):
		_fail("buying the cache refused with points in hand")
	elif _owned_total() != 1:
		_fail("the cache granted %d pieces, wanted 1" % _owned_total())
	var granted_ids: Array = GearDB.owned(hero)
	if granted_ids.size() != 1:
		_fail("the cache did not land on the featured hero: %s" % str(granted_ids))
	else:
		if not _legal_slayer_piece(str(granted_ids[0]), hero, "the cache"):
			_fail("the cache paid an illegal piece %s" % str(granted_ids[0]))
	if int(SaveGame.data["slayer"]["points"]) != 0:
		_fail("the cache did not deduct its cost: %d points left" % int(SaveGame.data["slayer"]["points"]))
	# (2) The 5th consecutive turn-in grants one legal piece; the sixth grants
	# nothing again.
	SaveGame.data = SaveGame._fresh()
	GearDB.store_override = {}
	hero = SaveGame.featured_id()
	for i in 6:
		SaveGame.assign_task("meadow_critters")
		SaveGame.data["slayer"]["task"]["have"] = int(SaveGame.data["slayer"]["task"]["need"])
		SaveGame.complete_task()
		var owned := _owned_total()
		if i < 4 and owned != 0:
			_fail("turn-in %d granted a piece early" % (i + 1))
			break
		elif i == 4:
			var item: String = str(SaveGame.last_streak_reward.get("item", ""))
			if owned != 1 or not SaveGame.last_streak_reward.has("item"):
				_fail("the 5th turn-in granted nothing: %d pieces, %s" % [owned, str(SaveGame.last_streak_reward)])
			elif not _legal_slayer_piece(item, hero, "the 5th turn-in"):
				_fail("the 5th turn-in streak piece was illegal: " + item)
		elif i == 5 and (owned != 1 or not SaveGame.last_streak_reward.is_empty()):
			_fail("the 6th turn-in granted again: %d pieces, %s" % [owned, str(SaveGame.last_streak_reward)])
	# (3) A full kit: the cache grants nothing and pays coins instead, and the
	# 5th streak turn-in does the same.
	SaveGame.data = SaveGame._fresh()
	GearDB.store_override = {}
	hero = SaveGame.featured_id()
	for slot in GearDB.HERO_SLOTS[hero]:
		for t in range(GearDB.Tier.IRON, GearDB.Tier.STEEL + 1):
			GearDB.grant(GearDB.item_id(hero, str(slot), t))
	var full := _owned_total()
	SaveGame.data["slayer"]["points"] = int(offer["cost"])
	var coins_before := int(SaveGame.data["coins"])
	if not SaveGame.buy_slayer("wardens_cache"):
		_fail("a full-kit cache purchase should still succeed")
	if _owned_total() != full:
		_fail("a full kit bought a duplicate piece")
	if int(SaveGame.data["coins"]) != coins_before + SaveGame.CACHE_COINS:
		_fail("a full-kit cache did not pay coins")
	SaveGame.assign_task("meadow_critters")
	SaveGame.data["slayer"]["task"]["have"] = int(SaveGame.data["slayer"]["task"]["need"])
	SaveGame.data["slayer"]["streak"] = 4
	coins_before = int(SaveGame.data["coins"])
	SaveGame.complete_task()
	if SaveGame.last_streak_reward.get("coins", 0) != SaveGame.CACHE_COINS or not SaveGame.last_streak_reward.has("coins"):
		_fail("a full-kit 5-streak did not pay coins: %s" % str(SaveGame.last_streak_reward))
	if _owned_total() != full:
		_fail("a full-kit 5-streak granted gear")
	if int(SaveGame.data["coins"]) != coins_before + SaveGame.CACHE_COINS:
		_fail("a full-kit 5-streak paid the wrong coins")
	SaveGame.data = keep
	SaveGame.no_write = keep_no_write
	GearDB.store_override = keep_store
	print("SLAYER GEAR ok: cache grant, 5-streak once, full kit pays coins")


## A slayer reward is legal when it is a real GearDB piece for the hero's
## slot at iron or blackened steel — never rune, never another hero.
static func _legal_slayer_piece(id: String, hero: String, source: String) -> bool:
	var it := GearDB.item(id)
	if not GearDB.is_item(id) or str(it["hero"]) != hero or not (str(it["slot"]) in GearDB.HERO_SLOTS[hero]):
		print("SLAYER %s paid a piece outside the hero's kit: %s" % [source, id])
		return false
	if int(it["tier"]) > GearDB.Tier.STEEL:
		print("SLAYER %s paid above steel: %s" % [source, id])
		return false
	return true


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


## First-hunt hints: the save key starts empty on a fresh save, reconciles to []
## for an old save, and mark_hint records each id exactly once. The HintLayer
## trigger helper is pure, so it is driven here with synthetic state.
static func _hints_check() -> void:
	var keep: Dictionary = SaveGame.data.duplicate(true)
	var keep_no_write: bool = SaveGame.no_write
	SaveGame.no_write = true
	# (1) A fresh save has seen nothing; mark_hint is a one-time record.
	SaveGame.data = SaveGame._fresh()
	SaveGame._reconcile()
	if SaveGame.hint_seen("move"):
		_fail("a fresh save already saw the move hint")
	SaveGame.mark_hint("move")
	if not SaveGame.hint_seen("move"):
		_fail("mark_hint did not record the hint")
	SaveGame.mark_hint("move")
	SaveGame.mark_hint("move")
	if (SaveGame.data["hints_seen"] as Array).count("move") != 1:
		_fail("mark_hint recorded an id more than once")
	if SaveGame.hint_seen("lair"):
		_fail("mark_hint marked a hint that was never shown")
	# (2) An old save without the key reconciles to [].
	SaveGame.data = SaveGame._fresh()
	SaveGame.data.erase("hints_seen")
	SaveGame._reconcile()
	if typeof(SaveGame.data.get("hints_seen")) != TYPE_ARRAY or not (SaveGame.data["hints_seen"] as Array).is_empty():
		_fail("hints_seen did not reconcile to []")
	# A wrongly-typed key is repaired by the type sanity pass.
	SaveGame.data["hints_seen"] = "nope"
	SaveGame._sanitize()
	if typeof(SaveGame.data["hints_seen"]) != TYPE_ARRAY:
		_fail("_sanitize left a bad hints_seen type")
	# (3) The pure trigger order on synthetic state.
	var seen: Array = []
	if RunScreenScript.HintLayer.next_hint({"started": false}, seen) != "":
		_fail("a hint fired before the run started")
	if RunScreenScript.HintLayer.next_hint({"started": true}, seen) != "move":
		_fail("move should be the first hint")
	seen = ["move"]
	if RunScreenScript.HintLayer.next_hint({"started": true, "moved": true}, seen) != "":
		_fail("still/lair/loot fired without a trigger")
	if RunScreenScript.HintLayer.next_hint({"started": true, "enemy_in_range": true}, seen) != "still":
		_fail("an enemy in range while moving should hint still")
	seen = ["move", "still"]
	if RunScreenScript.HintLayer.next_hint({"started": true, "time": 10.0, "explored": 0.05}, seen) != "":
		_fail("lair hint fired before 25 s / 15%")
	if RunScreenScript.HintLayer.next_hint({"started": true, "time": 25.0}, seen) != "lair":
		_fail("lair hint did not fire at 25 s")
	if RunScreenScript.HintLayer.next_hint({"started": true, "explored": 0.2}, seen) != "lair":
		_fail("lair hint did not fire at 15% explored")
	seen = ["move", "still", "lair"]
	if RunScreenScript.HintLayer.next_hint({"started": true, "gear_dropped": true}, seen) != "loot":
		_fail("loot hint did not fire on a ground drop")
	seen = ["move", "still", "lair", "loot"]
	if RunScreenScript.HintLayer.next_hint({"started": true, "enemy_in_range": true, "time": 99.0, "gear_dropped": true}, seen) != "":
		_fail("a hint repeated after it was already seen")
	SaveGame.data = keep
	SaveGame.no_write = keep_no_write
	print("HINTS ok: key, idempotent mark, reconcile, trigger order")


## Save robustness on a scratch file (SaveGame.save_path), never the real
## save: atomic write + backup rotation, a corrupt or truncated main file
## falls back to the backup, both broken starts fresh, a wrong-typed wallet
## resets alone while the armory survives, and unknown keys round-trip.
static func _save_safety_check() -> void:
	var keep: Dictionary = SaveGame.data.duplicate(true)
	var keep_path: String = SaveGame.save_path
	var keep_no_write: bool = SaveGame.no_write
	var keep_backup: int = SaveGame._last_backup_ms
	var path := "user://sim_check_save_safety.json"
	SaveGame.save_path = path
	SaveGame.no_write = false
	var put := func(p: String, text: String) -> void:
		var f := FileAccess.open(p, FileAccess.WRITE)
		f.store_string(text)
		f.close()
	var wipe := func() -> void:
		for p in [path, path + ".bak", path + ".tmp"]:
			if FileAccess.file_exists(p):
				DirAccess.remove_absolute(p)
	wipe.call()
	# Two writes: the first good file becomes the backup on the second.
	SaveGame.data = SaveGame._fresh()
	SaveGame._reconcile()
	SaveGame.data["coins"] = 123
	SaveGame.data["future_key"] = {"x": 1}
	SaveGame._last_backup_ms = -SaveGame.BACKUP_EVERY_MS
	SaveGame._write()
	SaveGame.data["coins"] = 124
	SaveGame._last_backup_ms = -SaveGame.BACKUP_EVERY_MS
	SaveGame._write()
	if FileAccess.file_exists(path + ".tmp"):
		_fail("save left its temp file behind")
	if int(SaveGame._read_save(path).get("coins", -1)) != 124 or int(SaveGame._read_save(path + ".bak").get("coins", -1)) != 123:
		_fail("atomic write / backup rotation")
	# A second write inside the window keeps the backup where it is.
	SaveGame.data["coins"] = 125
	SaveGame._write()
	if int(SaveGame._read_save(path + ".bak").get("coins", -1)) != 123:
		_fail("backup rotated inside the throttle window")
	# Truncated main -> backup, unknown key survives.
	put.call(path, "{\"coins\": 12, \"save_ver")
	SaveGame._load()
	if int(SaveGame.data["coins"]) != 123:
		_fail("truncated save did not fall back to the backup (coins %s)" % str(SaveGame.data["coins"]))
	if not SaveGame.data.has("future_key"):
		_fail("unknown save key lost on load")
	# Empty main and corrupt backup -> fresh, no crash.
	put.call(path, "")
	put.call(path + ".bak", "not json")
	SaveGame._load()
	if int(SaveGame.data["coins"]) != int(SaveGame._fresh()["coins"]):
		_fail("both saves broken should start fresh")
	# Wrong-typed fields reset alone; the armory and float coins survive.
	SaveGame.data = SaveGame._fresh()
	SaveGame._reconcile()
	SaveGame.data["coins"] = "abc"
	SaveGame.data["trophies"] = -5
	SaveGame.data["heroes"] = "broken"
	SaveGame.data["armory"] = {"v": 1, "owned": {"pebble": ["pebble.helm.1"]}, "equipped": {}, "xp": {}}
	put.call(path, JSON.stringify(SaveGame.data))
	SaveGame._load()
	if int(SaveGame.data["coins"]) != 0 or int(SaveGame.data["trophies"]) != 0:
		_fail("wrong-typed or negative wallet not reset")
	if typeof(SaveGame.data["heroes"]) != TYPE_DICTIONARY or SaveGame.data["heroes"].is_empty():
		_fail("broken heroes field not restored")
	if str(SaveGame.data.get("armory", {}).get("owned", {})).find("pebble.helm.1") < 0:
		_fail("type sanity dropped the armory")
	put.call(path, JSON.stringify({"save_version": 3, "coins": 77.0}))
	SaveGame._load()
	if typeof(SaveGame.data["coins"]) != TYPE_INT or int(SaveGame.data["coins"]) != 77:
		_fail("JSON float coins must load as 77")
	wipe.call()
	SaveGame.save_path = keep_path
	SaveGame._last_backup_ms = keep_backup
	SaveGame.data = keep
	SaveGame.no_write = keep_no_write
	print("SAVE SAFETY ok: atomic write, backup fallback, fresh on double corruption, type sanity")


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
		for i in (90 if quick else 300):
			var mv := Vector2.ZERO if i < 140 else Vector2(1, 0.2).normalized()
			sim.step(1.0 / 60.0, [mv])
			sim.drain_events()
			if sim.paused and sim.offer.size() > 0:
				sim.choose(0)
				sim.drain_events()
	print("CARDS ", Catalog.CARDS.size(), " ok")


## Grimdark naming pass guard: minion display names and power-up
## name/desc texts carry zero cute leftovers, minion names stay unique, and
## every rank_desc keeps the {n}/{total} placeholders it shipped with.
## Words are matched whole and case-insensitive; ids and numbers are keys
## and stay untouched.
static func _grim_names_check() -> void:
	var banned := [
		"paws", "paw", "critter", "bunny", "puppy", "pup", "snack", "cute",
		"fluffy", "dew", "nibble", "hearty", "puddle",
	]
	var names := {}
	for id in Catalog.CRITTERS:
		var row: Dictionary = Catalog.CRITTERS[id]
		if str(row.get("kind", "")) != "minion":
			continue
		var name := str(row.get("name", ""))
		_word_check("minion name " + str(id), name, banned)
		if name.is_empty():
			_fail("minion " + str(id) + " has no name")
		elif names.has(name):
			_fail("minion name is shared by two rows: " + name)
		names[name] = true
	var rows: Array = Catalog.CARDS.duplicate()
	rows.append(Catalog.card("snack"))
	for entry in rows:
		var id := str(entry.get("id", ""))
		_word_check("card name " + id, str(entry.get("name", "")), banned)
		_word_check("card desc " + id, str(entry.get("desc", "")), banned)
	# Placeholders the landing table shipped with: stack rows use {n}/{total},
	# summon rows count with {total} alone, the heal fallback only {n}, and
	# the uniques carry no rank_desc at all.
	var total_only := ["orbit_blades", "chain_lightning", "spirit_wolf"]
	for entry in Catalog.CARDS:
		var id := str(entry["id"])
		var rd := str(entry.get("rank_desc", ""))
		if id in ["phoenix", "second_wind"]:
			if rd != "":
				_fail(id + " is unique but shipped a rank_desc: " + rd)
			continue
		if rd.is_empty():
			_fail(id + " lost its rank_desc")
			continue
		if id in total_only:
			if not rd.contains("{total}") or rd.contains("{n}"):
				_fail(id + " rank_desc placeholders drifted: " + rd)
			continue
		if not rd.contains("{n}") or not rd.contains("{total}"):
			_fail(id + " rank_desc lost {n}/{total}: " + rd)
	var snack_rd := str(Catalog.card("snack").get("rank_desc", ""))
	if not snack_rd.contains("{n}") or snack_rd.contains("{total}"):
		_fail("snack rank_desc placeholders drifted: " + snack_rd)
	print("GRIM NAMES ok, %d minions named" % names.size())


## Whole-word, case-insensitive banned-word scan over display text.
static func _word_check(where: String, text: String, banned: Array) -> void:
	var letters := ""
	for ch in text.to_lower():
		letters += ch if (ch >= "a" and ch <= "z") else " "
	for word in letters.split(" ", false):
		if word in banned:
			_fail(where + " keeps the banned word '" + word + "'")
			return


## Blessing pools: each card in exactly one pool, class pools hold enough
## cards, and seeded offers per role (2000, 600 with --quick) respect class
## exclusivity, maxes, uniques, duplicates and the one-class-card guarantee.
## card_text is checked for every rank and must carry the rank total for
## stackables.
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
		for _i in (600 if quick else 2000):
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
		for _i in (200 if quick else 500):
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
## Catalog.CRITTERS, never hard-coded ids) seeded offers with random stacks
## (3000, 600 with --quick) must stay inside that role's class pool or the
## general pool, pass role_can_take (a melee tank never sees a Shot-only card),
## and only fall back to "snack" when no legal card is left. Each hero must
## carry a real role.
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
		for _i in (600 if quick else 3000):
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


## Catalog DROPS: card rows carry their hero's display name and roster colour
## (ids stay the log save keys), no retired cute-roster word survives in any
## drop name, ids are unique, and names stay short for the victory/log plates.
static func _drops_names_check() -> void:
	var bans := ["wool", "fluff", "hare", "bunny", "cute", "bell", "puff", "kit", "pup", "let", "mallet"]
	var seen := {}
	for entry in Catalog.DROPS:
		var drop: Dictionary = entry
		var id := str(drop["id"])
		if seen.has(id):
			_fail("duplicate drop id " + id)
			continue
		seen[id] = true
		var label := str(drop.get("name", ""))
		if label.length() > 20:
			_fail("drop %s name is %d characters: %s" % [id, label.length(), label])
		if str(drop.get("kind", "")) == "cards":
			var hero := str(drop.get("hero", ""))
			var row: Dictionary = Catalog.critter(hero)
			if row.is_empty():
				_fail("card drop %s names unknown hero %s" % [id, hero])
			else:
				if label != str(row["name"]) + " relics":
					_fail("card drop %s says '%s', hero %s is '%s'" % [id, label, hero, str(row["name"])])
				if str(drop.get("color", "")) != str(row["color"]):
					_fail("card drop %s does not carry the %s roster colour" % [id, hero])
		for word in label.to_lower().split(" ", false):
			for ban in bans:
				if word == ban or word.ends_with(ban):
					_fail("drop %s keeps the cute word '%s' in '%s'" % [id, ban, label])
	print("DROPS names ok: %d rows, ids unique, card labels tied to the roster, no cute words" % Catalog.DROPS.size())


static func _fights() -> void:
	# --quick keeps one short pebble hunt so bot planning still gets exercised
	# without waiting out three full clears.
	if quick:
		var short := _play("pebble", "meadow", 11, false, 60.0 * 60.0)
		print("FIGHT pebble ", short)
		return
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
		for seed in ([11] if quick else [3, 11, 42]):
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
	while t < (15.0 if quick else 40.0) and sim.boss != null and sim.boss.alive:
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
	var keep_data: Dictionary = SaveGame.data.duplicate(true)
	var prev_override: Variant = GearDB.store_override
	var prev_nowrite: bool = SaveGame.no_write
	GearDB.store_override = {}
	SaveGame.no_write = true
	SaveGame.data["gear_shards"] = 0
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
	var banked: Array = a.bank_gear()
	if _owned_total() != banked.size():
		_fail("a win did not bank every granted drop")
	if a.bank_gear().size() != 0 or _owned_total() != banked.size():
		_fail("gear banked twice")
	GearDB.store_override = {}
	var c := _sim("meadow", "ember", 11)
	for source in sources:
		c._gear_roll_drop(source, Vector2.ZERO)
	c.result = "lose"
	var kept: Array = c.bank_gear()
	if _owned_total() != kept.size():
		_fail("a loss did not bank the pieces it kept")
	if kept.size() > c.gear_found.size() / 2 or c.bank_gear().size() != 0:
		_fail("a loss did not keep the earliest floor-half once")
	GearDB.store_override = prev_override
	SaveGame.no_write = prev_nowrite
	SaveGame.data = keep_data
	print("GEAR smoke ok: %d dropped, %d banked, %d kept on a loss" % [a.gear_found.size(), banked.size(), kept.size()])


## The first boss gear row with the given gear_rarity, or {} when there is none.
static func _boss_gear_row(boss_id: String, rarity: String) -> Dictionary:
	for entry in Catalog.drop_table(boss_id):
		if str(entry.get("kind", "")) == "gear" and str(entry.get("gear_rarity", "")) == rarity:
			return entry
	return {}


## Boss "gear" rows obey the loot tier caps: a rare row on meadow pays iron
## (the meadow boss cap is iron only), a full slot banks shards instead of a
## steel copy, and frost rows may reach steel/rune but never above the depth
## cap. The summary's gear row is a copy carrying "granted" while Catalog.DROPS
## stays untouched. Runs on a scratch armory and restores everything after.
static func _boss_gear_check() -> void:
	var keep: Dictionary = SaveGame.data.duplicate(true)
	var keep_no_write: bool = SaveGame.no_write
	var keep_store: Variant = GearDB.store_override
	SaveGame.no_write = true
	# (1) A rare gear row on meadow pays an iron piece for the featured hero,
	# and the meadow boss cap keeps it off steel.
	SaveGame.data = SaveGame._fresh()
	GearDB.store_override = {}
	var hero := SaveGame.featured_id()
	var rare_row := _boss_gear_row("thistle", "rare")
	if rare_row.is_empty():
		_fail("no rare gear row on the meadow boss")
		return
	var slot := str({"armor": "chest"}.get(str(rare_row["slot"]), str(rare_row["slot"])))
	var iron_id := GearDB.item_id(hero, slot, GearDB.Tier.IRON)
	var meadow: Dictionary = SaveGame._grant_boss_gear(rare_row, "meadow")
	if str(meadow.get("kind", "")) != "gear" or str(meadow.get("id", "")) != iron_id:
		_fail("a meadow rare row did not grant iron: %s" % str(meadow))
	if GearDB.has(hero, GearDB.item_id(hero, slot, GearDB.Tier.STEEL)):
		_fail("a meadow rare row paid steel above the cap")
	# (2) With the slot's iron piece owned, the same row banks iron shards and
	# still grants no steel copy.
	var shards_before := int(SaveGame.data["gear_shards"])
	var dup: Dictionary = SaveGame._grant_boss_gear(rare_row, "meadow")
	if str(dup.get("kind", "")) != "shards" or int(dup.get("amount", 0)) != SaveGame.GEAR_SHARDS[GearDB.Tier.IRON]:
		_fail("a full meadow slot did not bank iron shards: %s" % str(dup))
	if int(SaveGame.data["gear_shards"]) != shards_before + SaveGame.GEAR_SHARDS[GearDB.Tier.IRON]:
		_fail("iron shards did not reach the wallet")
	if GearDB.has(hero, GearDB.item_id(hero, slot, GearDB.Tier.STEEL)):
		_fail("a duplicate meadow row granted steel")
	# (3) Frost (index 2) is the first ground where a boss row may pay steel or
	# rune, never above LootTable.max_tier("boss", 2).
	SaveGame.data = SaveGame._fresh()
	GearDB.store_override = {}
	hero = SaveGame.featured_id()
	var frost_cap := LootTable.max_tier("boss", 2)
	var frost_rare := _boss_gear_row("nimbus", "rare")
	var steel: Dictionary = SaveGame._grant_boss_gear(frost_rare, "frost")
	var steel_item := GearDB.item(str(steel.get("id", "")))
	if str(steel.get("kind", "")) != "gear" or int(steel_item.get("tier", 0)) != GearDB.Tier.STEEL:
		_fail("a frost rare row did not pay steel: %s" % str(steel))
	elif int(steel_item["tier"]) > frost_cap:
		_fail("a frost rare row paid above the cap")
	var legendary := frost_rare.duplicate(true)
	legendary["gear_rarity"] = "legendary"
	var rune: Dictionary = SaveGame._grant_boss_gear(legendary, "frost")
	var rune_item := GearDB.item(str(rune.get("id", "")))
	if str(rune.get("kind", "")) != "gear" or int(rune_item.get("tier", 0)) != GearDB.Tier.RUNE:
		_fail("a frost legendary row did not pay rune: %s" % str(rune))
	elif int(rune_item["tier"]) > frost_cap:
		_fail("a frost legendary row paid above the cap")
	# (4) A meadow legendary row is still clamped to iron; the summary's gear
	# row is a copy carrying "granted" and Catalog.DROPS never gains the key.
	SaveGame.data = SaveGame._fresh()
	GearDB.store_override = {}
	var clamped: Dictionary = SaveGame._grant_boss_gear(legendary, "meadow")
	var clamped_item := GearDB.item(str(clamped.get("id", "")))
	if str(clamped.get("kind", "")) != "gear" or int(clamped_item.get("tier", 0)) != GearDB.Tier.IRON:
		_fail("a meadow legendary row was not clamped to iron: %s" % str(clamped))
	SaveGame.data = SaveGame._fresh()
	GearDB.store_override = {}
	var saw_grant := false
	var wins := 0
	while wins < 400 and not saw_grant:
		wins += 1
		for drop in SaveGame.commit_victory("meadow", "thistle", 0).get("drops", []):
			if str(drop.get("kind", "")) != "gear":
				continue
			var granted: Dictionary = drop.get("granted", {})
			if str(granted.get("kind", "")) not in ["gear", "shards", "coins"]:
				_fail("a summary gear drop carried no granted result: %s" % str(drop))
			saw_grant = true
			break
	if not saw_grant:
		_fail("400 meadow wins rolled no gear row")
	for row in Catalog.DROPS:
		if row.has("granted"):
			_fail("Catalog.DROPS was mutated with a granted key")
			break
	SaveGame.data = keep
	SaveGame.no_write = keep_no_write
	GearDB.store_override = keep_store
	print("BOSS GEAR ok: caps clamp, shard banking, granted summary copy")


## Combat-skill XP: a melee RunBot fight trains Attack and Strength, a mage
## fight trains Magic, committing writes the XP exactly once, and the commit
## queues a skill_up event per level gained. Runs on a scratch armory.
## Combat-skill XP: a melee RunBot fight trains Attack, Strength and Defence
## (controlled), a mage fight trains Magic and Defence (longrange), committing
## writes the XP exactly once, and the commit queues a skill_up event per level
## gained. Runs on a scratch armory.
static func _skill_xp_smoke() -> void:
	var prev_override: Variant = GearDB.store_override
	var prev_nowrite: bool = SaveGame.no_write
	GearDB.store_override = {}
	SaveGame.no_write = true
	var melee := _fight_xp("pebble", 11)
	var melee_row: Dictionary = melee.skill_xp.get("pebble", {})
	if float(melee_row.get("attack", 0.0)) <= 0.0 or float(melee_row.get("strength", 0.0)) <= 0.0:
		_fail("melee fight trained no Attack/Strength")
	if float(melee_row.get("defence", 0.0)) <= 0.0:
		_fail("controlled melee trained no Defence")
	var mage := _fight_xp("ember", 11)
	var mage_row: Dictionary = mage.skill_xp.get("ember", {})
	if float(mage_row.get("magic", 0.0)) <= 0.0:
		_fail("mage fight trained no Magic")
	if float(mage_row.get("defence", 0.0)) <= 0.0:
		_fail("longrange spell trained no Defence")
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
	while sim.result == "" and guard < 60 * (30 if quick else 120):
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


## Skills screen: the OSRS combat-level helper behind the per-hero header on
## three known vectors, the next-unlock guidance over GearDB.all_items, the
## "all unlocked" state once Defence passes its last gate, and the view-only
## hero switcher (it must never write SaveGame.data["featured"]). Runs on a
## scratch armory (GearDB.store_override = {}) and restores it afterwards.
## This game has no Prayer skill, so the header passes only the six keys; the
## canonical OSRS 126 vector feeds the helper's optional "prayer" entry.
static func _skills_screen_check() -> void:
	var keep_store: Variant = GearDB.store_override
	var keep_nowrite: bool = SaveGame.no_write
	GearDB.store_override = {}
	SaveGame.no_write = true
	var one := {"attack": 1, "strength": 1, "defence": 1, "ranged": 1, "magic": 1, "hitpoints": 1}
	if SkillsScreen.combat_level(one) != 1:
		_fail("combat level all-1 gave %d" % SkillsScreen.combat_level(one))
	var maxed := {"attack": 99, "strength": 99, "defence": 99, "ranged": 99, "magic": 99, "hitpoints": 99, "prayer": 99}
	if SkillsScreen.combat_level(maxed) != 126:
		_fail("combat level all-99 gave %d" % SkillsScreen.combat_level(maxed))
	var melee := {"attack": 99, "strength": 99, "defence": 99, "ranged": 1, "magic": 1, "hitpoints": 99}
	if SkillsScreen.combat_level(melee) != 113:
		_fail("combat level melee-max gave %d" % SkillsScreen.combat_level(melee))
	# Hitpoints starts at 10, so a fresh hero's header reads 3, not 1.
	var start_hp := int(GearDB.START_LEVEL.get("hitpoints", 1))
	if start_hp != 10:
		_fail("Hitpoints start moved to %d; adjust the fresh-hero vector" % start_hp)
	var hero := SaveGame.featured_id()
	var fresh := {"attack": 1, "strength": 1, "defence": 1, "ranged": 1, "magic": 1, "hitpoints": start_hp}
	if SkillsScreen.combat_level(GearDB.skills(hero)) != SkillsScreen.combat_level(fresh):
		_fail("fresh hero combat level %d, expected %d" % [SkillsScreen.combat_level(GearDB.skills(hero)), SkillsScreen.combat_level(fresh)])
	# The header total is the six skill levels summed: a fresh hero is 15.
	if SkillsScreen.total_level(hero) != 15:
		_fail("fresh hero total level %d, expected 15" % SkillsScreen.total_level(hero))
	# View-only hero switcher (TASK): the page may show any unlocked hero, but
	# picking one is a local view change and must never write the save's
	# featured hero, which Home and the hunts own.
	var relock: Array = []
	for id in Catalog.playable_ids():
		var row: Dictionary = SaveGame.hero(str(id))
		if not bool(row["unlocked"]):
			relock.append(str(id))
			row["unlocked"] = true
	var featured_raw := str(SaveGame.data.get("featured", ""))
	var other := "pebble" if hero != "pebble" else "ember"
	var screen := SkillsScreen.new()
	if screen.view_id() != hero:
		_fail("skills view should open on the featured hero %s" % hero)
	screen.set_view(other)
	if screen.view_id() != other:
		_fail("skills view did not move to %s" % other)
	if str(SaveGame.data.get("featured", "")) != featured_raw:
		_fail("the skills hero picker wrote SaveGame.data['featured']")
	screen.set_view(hero)
	if screen.view_id() != hero:
		_fail("skills view did not return to the featured hero")
	if str(SaveGame.data.get("featured", "")) != featured_raw:
		_fail("the skills hero picker wrote SaveGame.data['featured']")
	screen.free()
	for id in relock:
		SaveGame.hero(id)["unlocked"] = false
	# The fresh hero's Defence row names the first steel gate (level 20).
	var text := SkillsScreen.next_unlock(hero, "defence")
	if text.find("Defence 20") < 0:
		_fail("fresh Defence unlock said '%s'" % text)
	# Reaching 40 opens every Defence-gated piece.
	GearDB.add_xp(hero, "defence", GearDB.xp_for_level(40) - GearDB.xp(hero, "defence"))
	if GearDB.level(hero, "defence") != 40:
		_fail("Defence did not reach 40")
	var opened := SkillsScreen.next_unlock(hero, "defence")
	if opened != "All gear unlocked":
		_fail("Defence still gated after 40: '%s'" % opened)
	GearDB.store_override = keep_store
	SaveGame.no_write = keep_nowrite
	print("SKILLS ok: combat vectors 1/126/113, view-only picker, level-20 unlock, all open at 40")


## XP drops: a seeded RunBot fight announces each skill's XP as it is earned.
## The drop amounts must sum to exactly what the commit writes (same rounding),
## a skill never drops twice inside one second, and the mid-run skill_level
## events are monotonic and reach exactly the committed levels. Runs on a
## scratch armory (store_override = {}) so the player's save never moves.
static func _xp_drop_check() -> void:
	var prev_override: Variant = GearDB.store_override
	var prev_nowrite: bool = SaveGame.no_write
	GearDB.store_override = {}
	SaveGame.no_write = true
	var hero := "pebble"
	# Park the hero a sliver below a few level-ups so the run crosses real
	# levels mid-fight; the crossings, not the numbers, are under test.
	GearDB.add_xp(hero, "attack", GearDB.xp_for_level(2) - 1)
	GearDB.add_xp(hero, "strength", GearDB.xp_for_level(2) - 1)
	GearDB.add_xp(hero, "hitpoints", GearDB.xp_for_level(11) - 1)
	var base := {}
	for skill in GearDB.SKILL_KEYS:
		base[skill] = GearDB.xp(hero, skill)
	var sim := _sim("meadow", hero, 11)
	var mem := {}
	var drops := {}
	var last_t := {}
	var levels := {}
	var guard := 0
	while sim.result == "" and sim.kills < 8 and guard < 60 * 60:
		guard += 1
		if sim.paused and sim.offer.size() > 0:
			sim.choose(_best(sim))
		if sim.paused and sim.offer.is_empty():
			break
		var mv := RunBot.explore_steer(sim, 0, mem) if sim.explore else RunBot.steer(sim, 0)
		sim.step(1.0 / 60.0, [mv])
		_collect_xp_drops(sim.drain_events(), drops, last_t, levels)
	# Flush whatever sat between the last drop and the end, then drain it too.
	sim._flush_xp_drops(true)
	_collect_xp_drops(sim.drain_events(), drops, last_t, levels)
	# The fight itself must not have written GearDB: only the scratch seed is there.
	for skill in GearDB.SKILL_KEYS:
		if GearDB.xp(hero, skill) != int(base[skill]):
			_fail("run_sim wrote GearDB xp for " + skill)
	# Sum of drops == committed amounts, per skill, exactly.
	var raw: Dictionary = sim.skill_xp.get(hero, {})
	var total := 0
	var any := false
	for skill in GearDB.SKILL_KEYS:
		var committed := int(round(float(raw.get(skill, 0.0))))
		if committed <= 0:
			continue
		any = true
		total += committed
		if int(drops.get(skill, 0)) != committed:
			_fail("%s drops sum %d, committed %d" % [skill, int(drops.get(skill, 0)), committed])
	if not any:
		_fail("the seeded fight trained no skill XP")
	# Committing writes exactly those amounts and reaches those levels; the
	# daily path (commit_xp without banking gear) writes once even if repeated
	# or followed by bank_gear.
	sim.commit_xp()
	sim.commit_xp()
	for skill in GearDB.SKILL_KEYS:
		var committed := int(round(float(raw.get(skill, 0.0))))
		var base_lvl := GearDB.level_for_xp(int(base[skill]))
		if GearDB.xp(hero, skill) != int(base[skill]) + committed:
			_fail("commit wrote %s xp %d, expected %d" % [skill, GearDB.xp(hero, skill), int(base[skill]) + committed])
		var reached := GearDB.level(hero, skill)
		var expect_level := GearDB.level_for_xp(int(base[skill]) + committed)
		if reached != expect_level:
			_fail("%s committed level %d, expected %d" % [skill, reached, expect_level])
		var seq: Array = levels.get(skill, [])
		if not seq.is_empty():
			if int(seq[0]) != base_lvl + 1:
				_fail("%s first announced level %d, expected %d" % [skill, int(seq[0]), base_lvl + 1])
			if int(seq[-1]) != reached:
				_fail("%s last announced level %d, committed %d" % [skill, int(seq[-1]), reached])
	if levels.is_empty():
		_fail("no skill_level crossed during the seeded fight")
	var after_commit := _skill_total()
	sim.bank_gear()
	if _skill_total() != after_commit:
		_fail("bank_gear after commit_xp wrote the run XP twice")
	GearDB.store_override = prev_override
	SaveGame.no_write = prev_nowrite
	print("XP drops ok: %d xp over %d skills" % [total, drops.size()])


## Folds one event drain into the drop and level tallies, failing on a drop
## tighter than one second or a skill_level that repeats or skips.
static func _collect_xp_drops(evs: Array, drops: Dictionary, last_t: Dictionary, levels: Dictionary) -> void:
	for ev in evs:
		var kind := str(ev.get("type", ""))
		if kind == "xp_drop":
			var skill := str(ev.get("skill", ""))
			var amount := int(ev.get("amount", 0))
			if amount < 1:
				_fail("xp_drop with amount " + str(amount))
			var t := float(ev.get("t", 0.0))
			if last_t.has(skill) and t - float(last_t[skill]) < 1.0 - 0.0001:
				_fail("%s had two drops %.3fs apart" % [skill, t - float(last_t[skill])])
			last_t[skill] = t
			drops[skill] = int(drops.get(skill, 0)) + amount
		elif kind == "skill_level":
			var skill := str(ev.get("skill", ""))
			var level := int(ev.get("level", 0))
			var seq: Array = levels.get(skill, [])
			if not seq.is_empty() and level != int(seq[-1]) + 1:
				_fail("%s skill_level jumped %d -> %d" % [skill, int(seq[-1]), level])
			seq.append(level)
			levels[skill] = seq
## Collection Log Armory tab: the per-hero gear progression counts, the drop
## hint derived from LootTable.MAX_TIER_BY_DEPTH (never hard-coded), and the
## view-only hero switcher (it must never write SaveGame.data["featured"]).
## Runs on a scratch armory (GearDB.store_override = {}) with SaveGame.no_write
## and restores both afterwards. Keyed by role-free hero params, never by id.
static func _gear_log_check() -> void:
	var keep_store: Variant = GearDB.store_override
	var keep_nowrite: bool = SaveGame.no_write
	GearDB.store_override = {}
	SaveGame.no_write = true
	var hero := SaveGame.featured_id()
	if not GearDB.grant(GearDB.item_id(hero, "helm", GearDB.Tier.IRON)):
		_fail("armory scratch could not grant an iron helm")
	var counts: Dictionary = LogScreen.armory_counts(hero)
	if int(counts["iron"]) != 1 or int(counts["steel"]) != 0 or int(counts["rune"]) != 0:
		_fail("armory counts %s, wanted iron 1 steel 0 rune 0" % str(counts))
	var per_tier := int(GearDB.HERO_SLOTS[hero].size())
	if int(counts["total"]) != per_tier:
		_fail("armory per-tier total %d, wanted %d slots" % [int(counts["total"]), per_tier])
	# The steel hint names the shallowest biome where steel can drop.
	var first_steel := ""
	for depth in Catalog.BIOMES.size():
		var reach := false
		for source in LootTable.MAX_TIER_BY_DEPTH:
			if LootTable.max_tier(str(source), depth) >= GearDB.Tier.STEEL:
				reach = true
				break
		if reach:
			first_steel = str(Catalog.BIOMES[depth]["name"]).split(" ")[0]
			break
	var steel_hint := LogScreen.drop_hint(GearDB.Tier.STEEL)
	if first_steel == "" or steel_hint.find(first_steel) < 0:
		_fail("steel hint '%s' does not mention its first biome '%s'" % [steel_hint, first_steel])
	var meadow := str(Catalog.BIOMES[0]["name"]).split(" ")[0]
	if LogScreen.drop_hint(GearDB.Tier.IRON).find(meadow) < 0:
		_fail("iron hint '%s' does not mention %s" % [LogScreen.drop_hint(GearDB.Tier.IRON), meadow])
	# View-only hero switcher (TASK): the page may show any unlocked hero, but
	# picking one is a local view change and must never write the save's
	# featured hero, which Home and the hunts own.
	var relock: Array = []
	for id in Catalog.playable_ids():
		var row: Dictionary = SaveGame.hero(str(id))
		if not bool(row["unlocked"]):
			relock.append(str(id))
			row["unlocked"] = true
	var other := ""
	for id in Catalog.playable_ids():
		if str(id) != hero:
			other = str(id)
			break
	var featured_raw := str(SaveGame.data.get("featured", ""))
	var screen := LogScreen.new()
	if screen.armory_view_id() != hero:
		_fail("armory should open on the featured hero %s" % hero)
	screen.set_armory_view(other)
	if screen.armory_view_id() != other:
		_fail("armory view did not move to %s" % other)
	if str(SaveGame.data.get("featured", "")) != featured_raw:
		_fail("the armory hero picker wrote SaveGame.data['featured']")
	# A hero's counts are its own: the other hero holds nothing yet.
	var other_counts: Dictionary = LogScreen.armory_counts(other)
	if int(other_counts["iron"]) != 0 or int(other_counts["steel"]) != 0 or int(other_counts["rune"]) != 0:
		_fail("armory counts bled between heroes: %s" % str(other_counts))
	screen.free()
	for id in relock:
		SaveGame.hero(id)["unlocked"] = false
	GearDB.store_override = keep_store
	SaveGame.no_write = keep_nowrite
	print("GEAR LOG ok: iron 1/%d, steel hint '%s', view-only picker" % [per_tier, steel_hint])
## The Forge (docs/gear.md): shards craft unowned pieces at tiers the player
## can already drop. A fresh 0-shard save offers nothing affordable; 100 shards
## on meadow-only ground offers iron alone and forging one deducts exactly 20
## and grants exactly that id once; owned ids are never listed; rune waits for
## a depth-2 biome and steel shows its "Need 40 more shards" shortfall; the
## wallet never goes negative; locked tiers name their biome. Everything runs
## on a scratch armory with SaveGame.no_write and restores both afterwards.
static func _forge_check() -> void:
	var keep: Dictionary = SaveGame.data.duplicate(true)
	var keep_no_write: bool = SaveGame.no_write
	var keep_store: Variant = GearDB.store_override
	SaveGame.no_write = true
	GearDB.store_override = {}
	SaveGame.data = SaveGame._fresh()
	var hero := SaveGame.featured_id()
	# A fresh save has no shards: every option is listed but none is affordable,
	# and every option is iron (meadow is the only biome open).
	var opts: Array = SaveGame.forge_options(hero)
	if opts.is_empty():
		_fail("a fresh save offered no forge options")
	for o in opts:
		if bool(o["ok"]) or int(o["tier"]) != GearDB.Tier.IRON:
			_fail("a fresh save offered %s" % str(o))
	# An over-cap tier is refused before the wallet is even read.
	if SaveGame.forge(hero, GearDB.item_id(hero, "helm", GearDB.Tier.STEEL)) or int(SaveGame.data["gear_shards"]) != 0:
		_fail("meadow forged above its cap or moved the wallet")
	# 100 shards on meadow: iron only, all affordable.
	SaveGame.data["gear_shards"] = 100
	opts = SaveGame.forge_options(hero)
	var seen_iron := 0
	for o in opts:
		if int(o["tier"]) != GearDB.Tier.IRON:
			_fail("meadow offered a non-iron option %s" % str(o))
		elif bool(o["ok"]):
			seen_iron += 1
	if seen_iron <= 0:
		_fail("meadow offered no affordable iron option")
	# Forge one: exactly 20 shards leave and exactly that id arrives, once.
	var target := str(opts[0]["id"])
	if not SaveGame.forge(hero, target):
		_fail("forging %s refused with 100 shards" % target)
	if int(SaveGame.data["gear_shards"]) != 80:
		_fail("forge did not deduct 20 shards, %d left" % int(SaveGame.data["gear_shards"]))
	if not GearDB.has(hero, target):
		_fail("forge did not grant %s" % target)
	if SaveGame.forge(hero, target) or int(SaveGame.data["gear_shards"]) != 80:
		_fail("the forge granted an owned piece or moved the wallet")
	for o in SaveGame.forge_options(hero):
		if str(o["id"]) == target:
			_fail("an owned id stayed in the forge options")
	# Unknown, foreign and not-a-hero-slot ids are all refused without a claim.
	if SaveGame.forge(hero, "nonsense.id.1") or SaveGame.forge(hero, "ember.helm.1"):
		_fail("the forge accepted an unknown or foreign id")
	# Mushroom (depth 1) unlocks steel but never rune.
	SaveGame.data["trophies"] = 30
	SaveGame.data["cleared"]["meadow"] = true
	var steel := false
	for o in SaveGame.forge_options(hero):
		if int(o["tier"]) == GearDB.Tier.RUNE:
			_fail("mushroom offered a rune option")
		elif int(o["tier"]) == GearDB.Tier.STEEL:
			steel = true
	if not steel:
		_fail("mushroom offered no steel option")
	if SaveGame.forge_lock_reason(GearDB.Tier.RUNE) != "Reach Frost to forge rune":
		_fail("the rune lock said '%s'" % SaveGame.forge_lock_reason(GearDB.Tier.RUNE))
	# Steel is skill-gated like wearing it: untrained, the option names the
	# skill and the forge refuses without touching the wallet.
	var gated := ""
	var gate := ""
	for o in SaveGame.forge_options(hero):
		if int(o["tier"]) == GearDB.Tier.STEEL:
			gated = str(o["id"])
			gate = str(o["reason"])
			break
	if not gate.begins_with("Requires ") or SaveGame.forge(hero, gated) or int(SaveGame.data["gear_shards"]) != 80:
		_fail("an untrained steel piece was forgeable ('%s')" % gate)
	for skill in GearDB.SKILL_KEYS:
		GearDB.add_xp(hero, skill, GearDB.xp_for_level(40))
	# The shard shortfall is named, not just "no".
	SaveGame.data["gear_shards"] = 20
	var short := ""
	for o in SaveGame.forge_options(hero):
		if int(o["tier"]) == GearDB.Tier.STEEL:
			short = str(o["reason"])
			break
	if short != "Need 40 more shards":
		_fail("a 20-shard steel option said '%s'" % short)
	# Frost (depth 2) opens rune; volcano needs frost cleared, so the cap stops
	# there.
	SaveGame.data["trophies"] = 150
	SaveGame.data["cleared"]["mushroom"] = true
	var rune := false
	for o in SaveGame.forge_options(hero):
		if int(o["tier"]) == GearDB.Tier.RUNE:
			rune = true
	if not rune:
		_fail("frost offered no rune option")
	if SaveGame.forge_lock_reason(GearDB.Tier.RUNE) != "":
		_fail("frost still locked rune: '%s'" % SaveGame.forge_lock_reason(GearDB.Tier.RUNE))
	# The wallet never goes negative: forge down to exactly 20, then a 20-cost
	# forge with only 20 left succeeds and the next refusal leaves 0, not -20.
	GearDB.store_override = {}
	for skill in GearDB.SKILL_KEYS:
		GearDB.add_xp(hero, skill, GearDB.xp_for_level(40))
	SaveGame.data["gear_shards"] = 20
	var first := ""
	for o in SaveGame.forge_options(hero):
		if bool(o["ok"]):
			first = str(o["id"])
			break
	if first == "" or not SaveGame.forge(hero, first):
		_fail("a 20-shard iron forge refused at exactly the price")
	if int(SaveGame.data["gear_shards"]) != 0:
		_fail("an exact-price forge left %d shards" % int(SaveGame.data["gear_shards"]))
	var second := ""
	for o in SaveGame.forge_options(hero):
		second = str(o["id"])
		break
	if second != "" and (SaveGame.forge(hero, second) or int(SaveGame.data["gear_shards"]) != 0):
		_fail("a 0-shard wallet forged or went negative")
	if int(SaveGame.data.get("gear_shards", 0)) < 0:
		_fail("the shard wallet went negative")
	SaveGame.data = keep
	SaveGame.no_write = keep_no_write
	GearDB.store_override = keep_store
	print("FORGE ok: 0 shards none, meadow iron only, forge deducts 20 once, steel skill-gated, rune gated to frost, wallet >= 0")


## Total XP held in the current GearDB store (a scratch armory in tests).
static func _skill_total() -> int:
	var total := 0
	var xp: Dictionary = GearDB._store()["xp"]
	for hero in xp:
		for skill in xp[hero]:
			total += int(xp[hero][skill])
	return total


## Grant (or equip) a full kit at a tier, in HERO_SLOTS order.
static func _kit(hero: String, tier: int, to_equip: bool) -> bool:
	for slot in GearDB.HERO_SLOTS[hero]:
		var id := GearDB.item_id(hero, str(slot), tier)
		if not (GearDB.equip(hero, id) if to_equip else GearDB.grant(id)):
			return false
	return true


## Mastery trophies (catalog SKILL_TROPHIES). On a scratch armory and save:
## (a) a fresh save cannot claim any of the twelve, (b) trained XP surfaces
## them once each — first_blood, blooded pay coins once, combat75 pays coins
## once — and the Hitpoints starting-10 never satisfies a blood trophy,
## (c) a full iron kit owned opens iron_clad and its coins pay exactly once,
## (d) blackened steel worn opens blackened with a chest exactly once,
## cursed_plate stays shut until one rune piece is owned and pays coins
## once. Everything restores.
static func _skill_trophy_check() -> void:
	var keep: Dictionary = SaveGame.data.duplicate(true)
	var keep_no_write: bool = SaveGame.no_write
	var keep_store: Variant = GearDB.store_override
	SaveGame.no_write = true
	GearDB.store_override = {}
	SaveGame.reset_new()
	# (a) Fresh save: every trophy locked, and claiming refuses outright.
	for entry in Catalog.SKILL_TROPHIES:
		if bool(SaveGame.mastery_state(entry).get("ok", false)):
			_fail("fresh save can claim %s" % str(entry["id"]))
		if SaveGame.claim_mastery(str(entry["id"])):
			_fail("fresh save claimed %s" % str(entry["id"]))
	if not SaveGame.mastery_claimed().is_empty():
		_fail("fresh save recorded a mastery claim")
	# (b) XP trophies: any trained combat skill counts, tracked per row.
	var hero := str(GearDB.HERO_SLOTS.keys()[0])
	GearDB.add_xp(hero, "defence", GearDB.xp_for_level(20) - GearDB.xp(hero, "defence"))
	var coins := int(SaveGame.data["coins"])
	if not SaveGame.claim_mastery("first_blood"):
		_fail("first_blood refused at Defence 20")
	elif int(SaveGame.data["coins"]) != coins + 40:
		_fail("first_blood paid wrong coins")
	if SaveGame.claim_mastery("first_blood"):
		_fail("first_blood claimed twice")
	coins = int(SaveGame.data["coins"])
	if not SaveGame.claim_mastery("blooded"):
		_fail("blooded refused at Defence 20")
	elif int(SaveGame.data["coins"]) != coins + 80:
		_fail("blooded paid wrong coins")
	if SaveGame.claim_mastery("blooded"):
		_fail("blooded claimed twice")
	if bool(SaveGame.mastery_state(Catalog.skill_trophy("veteran")).get("ok", false)):
		_fail("veteran ready below level 40")
	if SaveGame.claim_mastery("no_such_trophy"):
		_fail("unknown mastery claimed")
	# All six skills to 99 past the combat gate; combat75 must pay its coins once.
	for skill in GearDB.SKILL_KEYS:
		GearDB.add_xp(hero, str(skill), GearDB.xp_for_level(99) - GearDB.xp(hero, str(skill)))
	if int(SaveGame.combat_level(hero)) < 75:
		_fail("combat level math at 99s: %d" % int(SaveGame.combat_level(hero)))
	var purse := int(SaveGame.data["coins"])
	if not SaveGame.claim_mastery("combat75"):
		_fail("combat75 refused at all-99 skills")
	elif int(SaveGame.data["coins"]) != purse + 300:
		_fail("combat75 paid wrong coins")
	if SaveGame.claim_mastery("combat75"):
		_fail("combat75 claimed twice")
	# (c) A full iron kit owned opens iron_clad; coins pay exactly once and
	# the drawer never moves for a coin reward.
	var chests := SaveGame.pending_count()
	coins = int(SaveGame.data["coins"])
	if not _kit(hero, GearDB.Tier.IRON, false):
		_fail("iron kit grant")
	if not bool(SaveGame.mastery_state(Catalog.skill_trophy("iron_clad")).get("ok", false)):
		_fail("iron_clad shut with a full iron kit")
	if not SaveGame.claim_mastery("iron_clad"):
		_fail("iron_clad claim refused")
	elif int(SaveGame.data["coins"]) != coins + 100:
		_fail("iron_clad paid wrong coins")
	if SaveGame.pending_count() != chests or SaveGame.claim_mastery("iron_clad"):
		_fail("iron_clad paid twice")
	# (d) Blackened steel worn; chest lands exactly once. Cursed plate waits
	# for the first rune piece, then pays coins once.
	chests = int(SaveGame.data["chests"].size())
	if not _kit(hero, GearDB.Tier.STEEL, false) or not _kit(hero, GearDB.Tier.STEEL, true):
		_fail("steel kit grant or equip")
	if not bool(SaveGame.mastery_state(Catalog.skill_trophy("blackened")).get("ok", false)):
		_fail("blackened shut in full blackened steel")
	if not SaveGame.claim_mastery("blackened"):
		_fail("blackened claim refused")
	elif SaveGame.pending_count() != chests + 1:
		_fail("blackened chest did not land exactly once")
	if SaveGame.claim_mastery("blackened"):
		_fail("blackened claimed twice")
	coins = int(SaveGame.data["coins"])
	if bool(SaveGame.mastery_state(Catalog.skill_trophy("cursed_plate")).get("ok", false)):
		_fail("cursed_plate open before a rune piece")
	if not _kit(hero, GearDB.Tier.RUNE, false):
		_fail("rune piece grant")
	if not SaveGame.claim_mastery("cursed_plate"):
		_fail("cursed_plate refused after a rune piece")
	elif int(SaveGame.data["coins"]) != coins + 220:
		_fail("cursed_plate paid wrong coins")
	if SaveGame.claim_mastery("cursed_plate"):
		_fail("cursed_plate claimed twice")
	SaveGame.data = keep
	SaveGame.no_write = keep_no_write
	GearDB.store_override = keep_store
	print("MASTERY ok: fresh none, coins/chest pay once")


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
	_gear_gating_check()
	_gear_duplicates_check()
	_gear_equip_math()
	_gear_runs()
	_gear_bank()
	SaveGame.data = keep
	SaveGame.no_write = keep_no_write
	GearDB.store_override = keep_store


## 1-3. 20000 seeded rolls per source at the shallow and deep ends on a scratch
## armory: observed drop chance and tier split match SOURCES after the biome
## cap (meadow iron only, so deeper ground never loses rune), the boss never
## rolls empty, the run hero keeps its 75% coin share plus its 1/4 slice of the
## uniform fallback (about 81% of the pieces, see loot_table.gd _pick) on legal
## slots (Gnash never gets an offhand), and because the hero owns nearly all of
## one tier the owned-out rerolls keep duplicates well under the uniform rate.
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
	var deep: int = Catalog.BIOMES.size() - 1
	for source in LootTable.SOURCES.keys():
		var data: Dictionary = LootTable.SOURCES[source]
		var base: Array = data["weights"]
		var prev_rune := -1.0
		for depth in [0, deep]:
			var want: Array = LootTable._weights(base, int(depth), str(source))
			var weight_sum := 0.0
			for v in want:
				weight_sum += float(v)
			var drops := 0
			var tiers := [0, 0, 0]
			for _i in rolls:
				var rolled: Array[String] = LootTable.roll(rng, str(source), run_hero, int(depth))
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
				var want_share: float = float(want[t]) / maxf(weight_sum, 0.0001)
				if absf(share - want_share) > 0.02:
					_fail("%s depth %d tier %d share %.3f off capped %.3f" % [str(source), int(depth), t + 1, share, want_share])
			var rune_now := _rune_share(base, int(depth), str(source))
			if rune_now < prev_rune - 0.000001:
				_fail("a deeper biome lowered the rune share of %s" % str(source))
			prev_rune = rune_now
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


## Exact rune share of a tier-weight triple after LootTable's biome cap.
static func _rune_share(base: Array, biome_idx: int, source: String) -> float:
	var w: Array = LootTable._weights(base, biome_idx, source)
	return float(w[2]) / maxf(float(w[0]) + float(w[1]) + float(w[2]), 0.0001)


## 1b. Tier gating by biome depth. On a fresh scratch armory 50 meadow (idx 0)
## runs' worth of rolls drop iron only from every source, boss included; a
## mushroom (idx 1) roll never yields rune; frost (idx 2) lets the boss, the
## goblin and the rare-and-better chests reach rune while camps and common
## chests stay below; and each source's capped weights keep the same total.
static func _gear_gating_check() -> void:
	GearDB.store_override = {}
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var sources: Array = LootTable.SOURCES.keys()
	for _run in 50:
		for source in sources:
			for id in LootTable.roll(rng, str(source), "ember", 0):
				if int(str(id).get_slice(".", 2)) != GearDB.Tier.IRON:
					_fail("meadow rolled %s outside iron" % str(id))
					return
	var saw_steel := false
	for _i in 4000:
		for source in sources:
			for id in LootTable.roll(rng, str(source), "ember", 1):
				var tier := int(str(id).get_slice(".", 2))
				if tier == GearDB.Tier.RUNE:
					_fail("mushroom rolled rune %s" % str(id))
					return
				if tier == GearDB.Tier.STEEL:
					saw_steel = true
	if not saw_steel:
		_fail("mushroom never rolled steel")
	# Frost: the boss, the goblin and the rare-and-better chests reach rune;
	# camps, elites and the common chest do not.
	if LootTable.max_tier("boss", 2) < GearDB.Tier.RUNE or LootTable.max_tier("goblin", 2) < GearDB.Tier.RUNE:
		_fail("frost boss/goblin cannot reach rune")
	if LootTable.max_tier("chest_common", 2) >= GearDB.Tier.RUNE or LootTable.max_tier("camp", 2) >= GearDB.Tier.RUNE:
		_fail("frost camp/common chest can reach rune")
	for source in sources:
		var cap := LootTable.max_tier(str(source), 2)
		for _i in 4000:
			for id in LootTable.roll(rng, str(source), "ember", 2):
				if int(str(id).get_slice(".", 2)) > cap:
					_fail("frost %s rolled above its cap %d: %s" % [str(source), cap, str(id)])
					return
	# A cap only renormalises: every source keeps its base weight total.
	for source in sources:
		var base: Array = LootTable.SOURCES[source]["weights"]
		var want := 0.0
		for v in base:
			want += float(v)
		for depth in Catalog.BIOMES.size():
			var w: Array = LootTable._weights(base, depth, str(source))
			var total := 0.0
			for v in w:
				total += float(v)
			if absf(total - want) > 0.001:
				_fail("%s weights lost mass at depth %d: %.3f vs %.3f" % [str(source), depth, total, want])
				return
	print("GEAR gating ok: meadow iron-only, mushroom steel-no-rune, rune from frost boss/rare first")


## 1c. Duplicates bank as shards and coins. A second copy of an owned piece
## pays shards (iron 5, steel 15, rune 40); once the hero owns every item of a
## tier a duplicate pays coins instead (iron 10, steel 25, rune 60); an old
## save's missing gear_shards defaults to 0; and banking a run twice pays once.
static func _gear_duplicates_check() -> void:
	GearDB.store_override = {}
	SaveGame.data["gear_shards"] = 0
	SaveGame.data["coins"] = 0
	# First copy banks the piece, the second copy of the same piece pays shards.
	var res: Dictionary = SaveGame.bank_gear(["ember.helm.1", "ember.helm.1"])
	if str(res["ids"]) != "[\"ember.helm.1\"]" or int(res["shards"]) != 5 or int(res["coins"]) != 0:
		_fail("iron duplicate banked %s" % str(res))
	if not GearDB.has("ember", "ember.helm.1") or int(SaveGame.data["gear_shards"]) != 5:
		_fail("iron duplicate did not pay 5 shards")
	# Steel is 15, rune is 40.
	GearDB.grant("ember.chest.2")
	res = SaveGame.bank_gear(["ember.chest.2"])
	if int(res["shards"]) != 15 or int(SaveGame.data["gear_shards"]) != 20:
		_fail("steel duplicate paid %s" % str(res))
	GearDB.grant("ember.weapon.3")
	res = SaveGame.bank_gear(["ember.weapon.3"])
	if int(res["shards"]) != 40 or int(SaveGame.data["gear_shards"]) != 60:
		_fail("rune duplicate paid %s" % str(res))
	# Full tier: ember owns every iron item, so an iron duplicate pays coins.
	for slot in GearDB.HERO_SLOTS["ember"]:
		GearDB.grant(GearDB.item_id("ember", str(slot), GearDB.Tier.IRON))
	var coins_before := int(SaveGame.data["coins"])
	res = SaveGame.bank_gear(["ember.helm.1"])
	if int(res["coins"]) != 10 or int(res["shards"]) != 0 or int(SaveGame.data["coins"]) != coins_before + 10:
		_fail("a complete iron tier did not pay 10 coins: %s" % str(res))
	if int(SaveGame.data["gear_shards"]) != 60:
		_fail("the coins payout also moved the shard wallet")
	# Old save: a missing gear_shards key reconciles to 0.
	SaveGame.data.erase("gear_shards")
	SaveGame._reconcile()
	if int(SaveGame.data.get("gear_shards", -1)) != 0:
		_fail("gear_shards did not default to 0 on an old save")
	# Banking a run twice pays once.
	var sim := RunSim.new()
	sim.result = "win"
	sim.gear_found.assign(["pebble.helm.1", "pebble.helm.1"])
	var first: Array = sim.bank_gear()
	var wallet := int(SaveGame.data["gear_shards"])
	var coins_now := int(SaveGame.data["coins"])
	if first.size() != 1 or int(sim.gear_bank["shards"]) != 5:
		_fail("the run's duplicate did not bank as 5 shards: %s" % str(sim.gear_bank))
	if sim.bank_gear().size() != 0 or int(SaveGame.data["gear_shards"]) != wallet or int(SaveGame.data["coins"]) != coins_now:
		_fail("banking a run twice paid again")
	print("GEAR duplicates ok: iron 5/10, steel 15/25, rune 40/60, paid once")


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
	_folds_pct_add(geared, bare, want, "hp", "hp_pct", "hp_flat")
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


## Training replaces the coin/card Upgrade as the power source:
## (a) a fresh hero's run stats equal Catalog.base_stats exactly;
## (b) banked skill XP raises exactly the matching stat and no other;
## (c) an old save's card level banks once as skill XP, losing no power and
##     never applying twice;
## (d) reinforce charges coins, raises the piece and caps at REINFORCE_MAX.
static func _train_check() -> void:
	var keep: Dictionary = SaveGame.data.duplicate(true)
	var keep_no_write: bool = SaveGame.no_write
	var keep_store: Variant = GearDB.store_override
	SaveGame.no_write = true
	GearDB.store_override = {}
	SaveGame.reset_new()
	# (a) A fresh hero is exactly the catalog base, stat for stat.
	for hero in Catalog.playable_ids():
		var bare := SaveGame.build_run_stats(str(hero))
		var base := Catalog.base_stats(str(hero))
		for k in base:
			if not is_equal_approx(float(bare.get(k, -999999.0)), float(base[k])):
				_fail("fresh %s drifts from base at %s: %s vs %s" % [str(hero), k, str(bare.get(k)), str(base[k])])
	# (b) Each skill drives its own stat.
	var start := SaveGame.build_run_stats("pebble")
	GearDB.add_xp("pebble", "strength", GearDB.xp_for_level(20))
	GearDB.add_xp("pebble", "hitpoints", GearDB.xp_for_level(20))
	var grown := SaveGame.build_run_stats("pebble")
	if float(grown["dmg"]) <= float(start["dmg"]):
		_fail("strength training did not raise damage")
	if float(grown["hp"]) <= float(start["hp"]):
		_fail("hitpoints training did not raise hp")
	if float(grown["armor"]) != float(start["armor"]) or float(grown["crit"]) != float(start["crit"]):
		_fail("strength/hitpoints training leaked into armor/crit")
	GearDB.add_xp("pebble", "attack", GearDB.xp_for_level(20) - GearDB.xp("pebble", "attack"))
	GearDB.add_xp("pebble", "defence", GearDB.xp_for_level(20))
	var split := SaveGame.build_run_stats("pebble")
	if float(split["crit"]) <= float(grown["crit"]):
		_fail("attack training did not raise crit")
	if float(split["armor"]) <= float(grown["armor"]):
		_fail("defence training did not raise armor")
	# (c) Legacy card level -> banked skill XP, exactly once, no power loss.
	GearDB.store_override = null
	SaveGame.data = SaveGame._fresh()
	SaveGame.data["training_migrated"] = false
	SaveGame.data["heroes"]["ember"]["unlocked"] = true
	SaveGame.data["heroes"]["ember"]["level"] = 4
	SaveGame.migrate_training()
	var str_lvl := GearDB.level("ember", "strength")
	var hp_lvl := GearDB.level("ember", "hitpoints")
	if str_lvl < 1 + SaveGame.TRAIN_LEVELS_PER_CARD * 3 or hp_lvl < 10 + SaveGame.TRAIN_LEVELS_PER_CARD * 3:
		_fail("migration banked too little: strength %d hp %d" % [str_lvl, hp_lvl])
	if GearDB.level("ember", "magic") < str_lvl:
		_fail("mage migration skipped the weapon skill")
	if float(SaveGame.build_run_stats("ember")["hp"]) < float(Catalog.base_stats("ember")["hp"]) * (1.0 + 0.08 * 3.0):
		_fail("migration lost hp power")
	var stamp := GearDB.xp("ember", "strength")
	SaveGame.data["training_migrated"] = false
	SaveGame.migrate_training()
	if GearDB.xp("ember", "strength") != stamp:
		_fail("migration applied twice")
	# (d) Reinforce: coins out, stats up, hard cap.
	GearDB.store_override = {}
	SaveGame.data = SaveGame._fresh()
	SaveGame.data["coins"] = 100000
	if not GearDB.grant("pebble.weapon.1") or not GearDB.equip("pebble", "pebble.weapon.1"):
		_fail("reinforce setup")
	var before := GearDB.stats("pebble")
	var cost := GearDB.reinforce_cost("pebble", "pebble.weapon.1")
	if cost <= 0 or not GearDB.reinforce("pebble", "pebble.weapon.1"):
		_fail("reinforce refused a legal owned piece")
	if GearDB.reinforce_level("pebble", "pebble.weapon.1") != 1:
		_fail("reinforce level did not reach 1")
	if int(SaveGame.data["coins"]) != 100000 - cost:
		_fail("reinforce charged the wrong price")
	var after := GearDB.stats("pebble")
	var raised := false
	for k in after:
		if float(after[k]) > float(before.get(k, 0.0)):
			raised = true
	if not raised:
		_fail("reinforce did not raise the piece stats")
	for _i in GearDB.REINFORCE_MAX + 3:
		GearDB.reinforce("pebble", "pebble.weapon.1")
	if GearDB.reinforce_level("pebble", "pebble.weapon.1") != GearDB.REINFORCE_MAX:
		_fail("reinforce did not cap at %d" % GearDB.REINFORCE_MAX)
	if GearDB.reinforce("pebble", "pebble.weapon.1") or GearDB.reinforce("pebble", "pebble.weapon.2"):
		_fail("reinforce accepted a maxed or unowned piece")
	SaveGame.data = keep
	SaveGame.no_write = keep_no_write
	GearDB.store_override = keep_store
	print("TRAIN ok: base stats, skill power, migration, reinforce")


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


## Every Label's text under a node, joined with newlines (end-card rows read
## their copy back through this).
static func _text_of(node: Node) -> String:
	var out := ""
	if node is Label:
		out += (node as Label).text + "\n"
	for child in node.get_children():
		out += _text_of(child)
	return out


## 8. The end card's two new rows, run through the real RunScreen helpers with
## no scene: banked duplicates read as a gold shards/coins plaque (and vanish
## when nothing melted), and the run hero's non-zero combat XP prints in
## GearDB order, rounded like the commit (and vanishes with no XP). Never
## keyed by hero id; the run hero comes from the Catalog roster order.
static func _end_card_check() -> void:
	var screen = load("res://scripts/run_screen.gd").new()
	var hero := str(Catalog.playable_ids()[0])
	screen.set("hero_id", hero)
	var sim := RunSim.new()
	sim.gear_bank = {"ids": [], "shards": 15, "coins": 25}
	sim.skill_xp = {hero: {"attack": 12.4, "defence": 3.6}}
	screen.set("sim", sim)
	var melt: Control = screen._melt_line()
	if melt == null:
		_fail("melt line missing for 15 shards / 25 coins")
	else:
		var melt_text := _text_of(melt)
		if melt_text.find("+15 gear shards") < 0 or melt_text.find("+25 coins") < 0:
			_fail("melt line said: %s" % melt_text.strip_edges())
		melt.free()
	var run_xp: Control = screen._end_xp()
	if run_xp == null:
		_fail("xp row missing for the run hero")
	else:
		var xp_text := _text_of(run_xp)
		if xp_text.find("+12 Attack") < 0 or xp_text.find("+4 Defence") < 0 or xp_text.find("Strength") >= 0:
			_fail("xp row said: %s" % xp_text.strip_edges())
		run_xp.free()
	# Nothing melted -> no plaque; no combat XP -> no line (a daily reads both).
	sim.gear_bank = {"ids": [], "shards": 0, "coins": 0}
	if screen._melt_line() != null:
		_fail("melt line showed with nothing melted")
	sim.skill_xp = {}
	if screen._end_xp() != null:
		_fail("xp row showed with no XP")
	screen.free()
	print("END CARD ok: melted-duplicate line and run skill XP line")


## Home attention pips (SaveGame.forge_ready / mastery_ready / slayer_ready).
## On a scratch save and armory, the read-only queries drive the Home dots:
## a fresh save lights none; 20 shards light the Forge; a trained combat skill
## lights mastery and claiming clears it; a finished contract lights Slayer and
## an unfinished one does not. Everything restores.
static func _home_pips_check() -> void:
	var keep: Dictionary = SaveGame.data.duplicate(true)
	var keep_no_write: bool = SaveGame.no_write
	var keep_store: Variant = GearDB.store_override
	SaveGame.no_write = true
	GearDB.store_override = {}
	SaveGame.data = SaveGame._fresh()
	var hero := SaveGame.featured_id()
	# Fresh: no shards, no XP, no contract, so no pip.
	if SaveGame.forge_ready(hero):
		_fail("a fresh home lit the Forge pip")
	if SaveGame.mastery_ready():
		_fail("a fresh home lit the mastery pip")
	if SaveGame.slayer_ready():
		_fail("a fresh home lit the Slayer pip")
	# 20 shards cover one iron piece on a meadow-only save.
	SaveGame.data["gear_shards"] = 20
	if not SaveGame.forge_ready(hero):
		_fail("20 shards did not light the Forge pip")
	if SaveGame.mastery_ready():
		_fail("shards alone lit the mastery pip")
	# Train a combat skill to 10: First Blood turns; claiming it clears the pip.
	GearDB.add_xp(hero, "attack", GearDB.xp_for_level(10))
	if not SaveGame.mastery_ready():
		_fail("a trained skill did not light the mastery pip")
	if not SaveGame.claim_mastery("first_blood"):
		_fail("a lit mastery trophy could not be claimed")
	if SaveGame.mastery_ready():
		_fail("mastery stayed lit after its only claim")
	# A finished contract reads ready; one short, or none, does not.
	var task := Catalog.slayer_task("meadow_critters").duplicate()
	task["have"] = int(task["need"])
	SaveGame.data["slayer"]["task"] = task
	if not SaveGame.slayer_ready():
		_fail("a finished contract did not light the Slayer pip")
	task["have"] = int(task["need"]) - 1
	SaveGame.data["slayer"]["task"] = task
	if SaveGame.slayer_ready():
		_fail("an unfinished contract lit the Slayer pip")
	SaveGame.data["slayer"]["task"] = {}
	if SaveGame.slayer_ready():
		_fail("no contract lit the Slayer pip")
	SaveGame.data = keep
	SaveGame.no_write = keep_no_write
	GearDB.store_override = keep_store
	print("HOME PIPS ok: fresh none, shards forge, mastery claim clears, contract turn-in")
## --- Progression pacing report (--pacing) ------------------------------------
## Target OSRS-feel pacing for a ~4 minute run: first iron piece in run 1-2, a
## full iron kit by ~3-8 runs, the steel gate (main/Defence 20) around runs 6-18,
## the rune gate (40) around runs 30-60, and short steel defence-locked windows.
## RunBot fights are slow, so each role is sampled with six fresh full fights and
## the 60-run campaign is extrapolated from their measured per-run XP and loot
## means: every skill grows with the earned gear + skill damage bonus, and the
## longrange/controlled split trains Defence alongside the main skill instead of
## only from damage taken.
##   godot --headless --path . -- --sim-check --pacing [--class-tag=AFTER]
const PACING_RUNS := 60
const PACING_SEEDS: Array[int] = [11, 19, 23, 31, 42, 57]
const PACING_ROLES: Array[String] = ["tank", "archer", "mage"]
## Fixed projection RNG per role, so the report is reproducible (roles are not
## hero ids; the loot model just needs a stable stream).
const PACING_RUN_RNG := {"tank": 1201, "archer": 2202, "mage": 3303}
## Recorded per-run main-skill XP of one fresh ~4 min ranged run before
## SKILL_XP_SCALE (the longrange split gives Ranged 75% of the award). The
## default check asserts the current scale turns this run into a level between
## 5 and 20 from scratch.
const PACING_RUN_RAW := 21742.0


## Report the 60-run projected campaign for one hero per role. Runs on a scratch
## armory with SaveGame.no_write and restores both afterwards.
static func pacing(tag: String) -> void:
	var keep_store: Variant = GearDB.store_override
	var keep_nowrite: bool = SaveGame.no_write
	var keep_data: Dictionary = SaveGame.data.duplicate(true)
	SaveGame.no_write = true
	var reps := _pacing_reps()
	print("PACING %s scale=%.4f runs=%d samples=%d" % [tag, RunSim.SKILL_XP_SCALE, PACING_RUNS, PACING_SEEDS.size()])
	print("PACING method: %d fresh full RunBot fights per role (seeds %s); per-run XP and loot are the measured means, projected XP scales with earned gear + skill bonus (Defence rides the longrange/controlled split)." % [PACING_SEEDS.size(), str(PACING_SEEDS)])
	for role in PACING_ROLES:
		if not reps.has(role):
			_fail("pacing has no hero for role " + role)
			continue
		_pacing_role(role, str(reps[role]))
	print("PACING done")
	SaveGame.data = keep_data
	SaveGame.no_write = keep_nowrite
	GearDB.store_override = keep_store


## Cheap (< 5 s, no fights) default-check guard: one recorded ~4 min run's
## main-skill XP at the current SKILL_XP_SCALE lands between level 5 and 20, so
## a run cannot drift far outside the intended pacing.
static func _pacing_scale_check() -> void:
	var scale: float = RunSim.SKILL_XP_SCALE
	var xp := int(round(PACING_RUN_RAW * scale))
	var lvl := GearDB.level_for_xp(xp)
	if lvl < 5 or lvl > 20:
		_fail("recorded run main skill lands level %d at scale %.4f (want 5-20)" % [lvl, scale])
	print("PACING scale ok: scale %.4f -> recorded run lvl%d" % [scale, lvl])


## The first hero Catalog lists for each role, preferring one with a GearDB kit
## so the gear side of the report can be modelled. Never hard-codes a hero id
## (run_sim keys on role); an archer without a gear set reports gear as n/a.
static func _pacing_reps() -> Dictionary:
	var out := {}
	var geared := {}
	for id in Catalog.CRITTERS:
		var entry: Dictionary = Catalog.CRITTERS[id]
		if str(entry.get("kind", "")) != "hero":
			continue
		var role := str(entry.get("role", ""))
		if not (role in PACING_ROLES):
			continue
		if not out.has(role):
			out[role] = str(id)
		if GearDB.HERO_SLOTS.has(str(id)) and not geared.has(role):
			geared[role] = str(id)
	for role in geared:
		out[role] = geared[role]
	return out


## The skill a role's weapon trains (the "main skill" for the report).
static func _pacing_skill(role: String) -> String:
	match role:
		"archer":
			return "ranged"
		"mage":
			return "magic"
		_:
			return "attack"


## Six fresh full bot fights: measured mean XP per skill key and mean gear
## pieces per tier, per run. Every fight starts from base stats on an empty
## scratch armory, so the means describe a from-scratch run.
static func _pacing_sample(hero: String) -> Dictionary:
	GearDB.store_override = {}
	var per_skill := {}
	var per_tier := [0.0, 0.0, 0.0]
	for seed in PACING_SEEDS:
		var session := Session.solo("meadow", hero)
		session.seed = seed
		var sim := RunSim.new()
		sim.start(session, {hero: Catalog.base_stats(hero)})
		_pacing_fight(sim)
		var row: Dictionary = sim.skill_xp.get(hero, {})
		for k in row:
			per_skill[str(k)] = float(per_skill.get(str(k), 0.0)) + float(row[k])
		for gid in sim.gear_found:
			per_tier[int(str(gid).get_slice(".", 2)) - 1] += 1.0
	var n := float(PACING_SEEDS.size())
	for k in per_skill:
		per_skill[k] = float(per_skill[k]) / n
	for t in 3:
		per_tier[t] = float(per_tier[t]) / n
	return {"skill": per_skill, "tier": per_tier}


## One bot-driven fight to its result (or a safety cap), with greedy level-ups.
static func _pacing_fight(sim: RunSim) -> void:
	var mem := {}
	var guard := 0
	while sim.result == "" and guard < int(60.0 * 400.0):
		guard += 1
		if sim.paused:
			if sim.offer.size() > 0:
				sim.choose(_best(sim))
				sim.drain_events()
			else:
				break
			continue
		var mv := RunBot.explore_steer(sim, 0, mem) if sim.explore else RunBot.steer(sim, 0)
		sim.step(STEP, [mv])
		sim.drain_events()


## Project the 60-run campaign for one role from the measured means: add the
## run's XP, bank the mean gear (equipping the best that fits the current
## levels), then read off the milestone runs.
static func _pacing_role(role: String, hero: String) -> void:
	var main := _pacing_skill(role)
	var sample := _pacing_sample(hero)
	var base_skill: Dictionary = sample["skill"]
	var base_tier: Array = sample["tier"]
	GearDB.store_override = {}
	var rng := RandomNumberGenerator.new()
	rng.seed = int(PACING_RUN_RNG[role])
	var levels := {}
	for sk in GearDB.SKILL_KEYS:
		levels[sk] = {10: -1, 20: -1, 40: -1}
	var first := {GearDB.Tier.IRON: -1, GearDB.Tier.STEEL: -1, GearDB.Tier.RUNE: -1}
	var full_iron := -1
	var full_steel := -1
	var lock_first := -1
	var lock_last := -1
	var loot_acc := [0.0, 0.0, 0.0]
	var geared := GearDB.HERO_SLOTS.has(hero)
	for run in range(1, PACING_RUNS + 1):
		var mult := _pacing_dmg_mult(hero)
		for sk in base_skill:
			# With the longrange/controlled split almost all Defence XP is earned
			# by dealing damage, so every skill rides the same gear/skill bonus.
			var amount := float(base_skill[sk]) * mult
			GearDB.add_xp(hero, str(sk), int(round(amount)))
		if geared:
			for t in 3:
				loot_acc[t] += float(base_tier[t])
				while loot_acc[t] >= 1.0:
					loot_acc[t] -= 1.0
					_pacing_grant(hero, t + 1, rng)
					if int(first[t + 1]) < 0:
						first[t + 1] = run
			_pacing_equip_best(hero)
		for sk in GearDB.SKILL_KEYS:
			for target in [10, 20, 40]:
				if int(levels[sk][target]) < 0 and GearDB.level(hero, str(sk)) >= target:
					levels[sk][target] = run
		if geared and full_iron < 0 and _pacing_full_kit(hero, GearDB.Tier.IRON):
			full_iron = run
		if geared and full_steel < 0 and _pacing_full_kit(hero, GearDB.Tier.STEEL):
			full_steel = run
		if geared and _pacing_locked(hero):
			lock_first = run if lock_first < 0 else lock_first
			lock_last = run
	_pacing_print(role, hero, main, sample, levels, first, full_iron, full_steel, lock_first, lock_last, geared)


## Current offensive bonus from worn gear and the skill level hook, as a
## multiplier on a fresh run's earned combat XP.
static func _pacing_dmg_mult(hero: String) -> float:
	var gear := GearDB.stats(hero)
	var bonus: Dictionary = GearDB.level_bonus(hero)
	return 1.0 + float(gear.get("dmg_pct", 0.0)) + float(bonus.get("dmg_pct", 0.0))


## Grant one projected piece at a tier, preferring a slot the hero does not own
## at that tier yet (mirrors LootTable._pick's owned-out rerolls).
static func _pacing_grant(hero: String, tier: int, rng: RandomNumberGenerator) -> void:
	var slots: Array = GearDB.HERO_SLOTS[hero]
	var free: Array = []
	for s in slots:
		if not GearDB.has(hero, GearDB.item_id(hero, str(s), tier)):
			free.append(str(s))
	var slot := str(free[rng.randi() % free.size()]) if not free.is_empty() else str(slots[rng.randi() % slots.size()])
	GearDB.grant(GearDB.item_id(hero, slot, tier))


## Wear the best owned, equippable piece in every slot (gated pieces come on as
## the skills cross their requirement during the projected campaign).
static func _pacing_equip_best(hero: String) -> void:
	for s in GearDB.HERO_SLOTS[hero]:
		var best := ""
		for t in range(GearDB.Tier.IRON, GearDB.Tier.RUNE + 1):
			var id := GearDB.item_id(hero, str(s), t)
			if GearDB.has(hero, id) and bool(GearDB.can_equip(hero, id)["ok"]):
				best = id
		if best != "":
			GearDB.equip(hero, best)


## True when every slot the hero has holds an owned, equippable piece of at
## least this tier (a better piece also counts for a lower tier's kit).
static func _pacing_full_kit(hero: String, tier: int) -> bool:
	for s in GearDB.HERO_SLOTS[hero]:
		var ok := false
		for t in range(tier, GearDB.Tier.RUNE + 1):
			var id := GearDB.item_id(hero, str(s), t)
			if GearDB.has(hero, id) and bool(GearDB.can_equip(hero, id)["ok"]):
				ok = true
				break
		if not ok:
			return false
	return true


## True while a dropped Defence-gated steel piece is still level-locked: the
## "locked loot" window the report traces. Only the slots the Defence gate
## covers (helm/chest/boots/off-hand) are counted, since the weapon/strength/
## hitpoints slots train through other skills and stay locked far longer; rune
## pieces are excluded too (they wait for the rune gate much later).
static func _pacing_locked(hero: String) -> bool:
	for s in GearDB.HERO_SLOTS[hero]:
		if str(GearDB.SLOT_SKILL.get(str(s), "")) != "defence":
			continue
		var id := GearDB.item_id(hero, str(s), GearDB.Tier.STEEL)
		if GearDB.has(hero, id) and not bool(GearDB.can_equip(hero, id)["ok"]):
			return true
	return false


static func _pacing_print(role: String, hero: String, main: String, sample: Dictionary, levels: Dictionary, first: Dictionary, full_iron: int, full_steel: int, lock_first: int, lock_last: int, geared: bool) -> void:
	var row: Dictionary = sample["skill"]
	var tiers: Array = sample["tier"]
	print("PACING %s %s: fresh main(%s)/run %.0f def/run %.0f loot/run iron %.1f steel %.1f rune %.1f" % [
		role, hero, main, float(row.get(main, 0.0)), float(row.get("defence", 0.0)),
		float(tiers[0]), float(tiers[1]), float(tiers[2])])
	print("PACING %s main 10@%s 20@%s 40@%s | def 20@%s 40@%s" % [
		role, _pacing_run(int(levels[main][10])), _pacing_run(int(levels[main][20])), _pacing_run(int(levels[main][40])),
		_pacing_run(int(levels["defence"][20])), _pacing_run(int(levels["defence"][40]))])
	if not geared:
		print("PACING %s gear: n/a (no %s gear set in GearDB.HERO_SLOTS)" % [role, hero])
		return
	print("PACING %s first iron@%s steel@%s rune@%s | full iron kit@%s full steel kit@%s" % [
		role, _pacing_run(int(first[GearDB.Tier.IRON])), _pacing_run(int(first[GearDB.Tier.STEEL])), _pacing_run(int(first[GearDB.Tier.RUNE])),
		_pacing_run(full_iron), _pacing_run(full_steel)])
	if lock_first < 0:
		print("PACING %s steel defence-locked loot: none" % role)
	else:
		var tail := " (still locked at run %d)" % lock_last if lock_last >= PACING_RUNS else ""
		print("PACING %s steel defence-locked loot: runs %d-%d (%d runs)%s" % [role, lock_first, lock_last, lock_last - lock_first + 1, tail])


## "-" for a milestone the 60-run projection never reaches.
static func _pacing_run(run: int) -> String:
	return "-" if run < 0 else str(run)


## Per-map difficulty tiers: tiers scale the fight, unlocks persist in the
## save, Normal farming falls off in XP once the hero outgrows the map, and the
## loot cap still stops Nightmare Meadow from rolling rune.
static func _difficulty_check() -> void:
	var keep_store: Variant = GearDB.store_override
	var keep_nowrite: bool = SaveGame.no_write
	var keep_data: Dictionary = SaveGame.data.duplicate(true)
	GearDB.store_override = {}
	SaveGame.no_write = true

	# 1) Tiers scale enemy hp, damage, density and elite chance (same seed).
	var normal := _difficulty_sim("meadow", 0)
	var veteran := _difficulty_sim("meadow", 1)
	var nightmare := _difficulty_sim("meadow", 2)
	var ns := _difficulty_foes(normal)
	var vs := _difficulty_foes(veteran)
	var xs := _difficulty_foes(nightmare)
	if not (float(vs["hp"]) > float(ns["hp"]) and float(xs["hp"]) > float(vs["hp"])):
		_fail("enemy hp did not rise with tier: %s -> %s -> %s" % [ns["hp"], vs["hp"], xs["hp"]])
	if not (float(vs["dmg"]) > float(ns["dmg"]) and float(xs["dmg"]) > float(vs["dmg"])):
		_fail("enemy damage did not rise with tier: %s -> %s -> %s" % [ns["dmg"], vs["dmg"], xs["dmg"]])
	if not int(ns["count"]) < int(xs["count"]):
		_fail("enemy density did not rise with tier: %s -> %s" % [ns["count"], xs["count"]])
	if not int(ns["elite"]) < int(xs["elite"]):
		_fail("elite count did not rise with tier: %s -> %s" % [ns["elite"], xs["elite"]])
	normal.begin_boss()
	veteran.begin_boss()
	nightmare.begin_boss()
	if normal.boss == null or veteran.boss == null or nightmare.boss == null:
		_fail("a boss failed to spawn for the tier scaling check")
	elif not (float(veteran.boss.max_hp) > float(normal.boss.max_hp) and float(nightmare.boss.max_hp) > float(veteran.boss.max_hp)):
		_fail("boss hp did not rise with tier")

	# 2) The loot cap holds: Nightmare Meadow still cannot roll rune.
	if LootTable.max_tier("boss", 0) != GearDB.Tier.IRON:
		_fail("meadow boss tier cap changed")
	var rng := RandomNumberGenerator.new()
	rng.seed = 987654
	var rune := 0
	for _i in 600:
		for id in LootTable.roll(rng, "boss", "pebble", 0, 2):
			if int(str(id).get_slice(".", 2)) == GearDB.Tier.RUNE:
				rune += 1
	if rune > 0:
		_fail("Nightmare meadow rolled rune gear %d times" % rune)

	# 3) XP falloff: only Normal, only past the grace band, and monotone.
	if Catalog.xp_falloff(3, 3, 0) != 1.0:
		_fail("a hero at the map's level should not fall off")
	if Catalog.xp_falloff(80, 3, 0) >= 1.0:
		_fail("a far over-leveled hero should fall off on Normal")
	if Catalog.xp_falloff(80, 3, 2) != 1.0:
		_fail("Nightmare must never fall off")
	if Catalog.xp_falloff(90, 3, 0) > Catalog.xp_falloff(30, 3, 0):
		_fail("falloff should not rise with combat level")
	# Wired end to end: the same hit trains less once the hero is over-leveled.
	var fp := _difficulty_fresh_sim("pebble", 0)
	var xp_fresh := _difficulty_hit_xp(fp)
	for skill in ["attack", "strength", "defence", "hitpoints"]:
		GearDB.add_xp("pebble", skill, GearDB.xp_for_level(70))
	var boosted := _difficulty_fresh_sim("pebble", 0)
	var xp_boosted := _difficulty_hit_xp(boosted)
	if boosted.xp_falloff() >= 1.0:
		_fail("an over-leveled Normal run reported no falloff")
	if xp_boosted >= xp_fresh:
		_fail("over-leveled hit trained %f xp, fresh hit %f" % [xp_boosted, xp_fresh])

	# 4) Unlocks persist across a save round trip.
	_difficulty_unlock_check()

	SaveGame.data = keep_data
	GearDB.store_override = keep_store
	SaveGame.no_write = keep_nowrite
	print("DIFFICULTY ok: tiers scale, nightmare meadow stays iron, falloff works, unlocks persist")


## A fresh exploration run at `tier` for the tier/falloff checks.
static func _difficulty_sim(biome: String, tier: int, seed := 11) -> RunSim:
	var session := Session.solo(biome, "pebble")
	session.seed = seed
	var sim := RunSim.new()
	sim.start(session, {"pebble": Catalog.base_stats("pebble")}, tier)
	return sim


static func _difficulty_fresh_sim(hero: String, tier: int) -> RunSim:
	var session := Session.solo("meadow", hero)
	session.seed = 11
	var sim := RunSim.new()
	sim.start(session, {hero: Catalog.base_stats(hero)}, tier)
	return sim


## Mean hp/damage and the counts a fight spawned, for comparing tiers.
static func _difficulty_foes(sim: RunSim) -> Dictionary:
	var count := 0
	var elite := 0
	var hp := 0.0
	var dmg := 0.0
	for a in sim.actors:
		if a.kind != "minion" or not a.alive:
			continue
		count += 1
		if a.elite:
			elite += 1
		hp += a.max_hp
		dmg += a.dmg
	var n := float(maxi(count, 1))
	return {"count": count, "elite": elite, "hp": hp / n, "dmg": dmg / n}


## The run's skill XP from one fixed hit on a dummy foe.
static func _difficulty_hit_xp(sim: RunSim) -> float:
	var hero: RunSim.Actor = sim.heroes[0]
	var foe := RunSim.Actor.new()
	foe.kind = "minion"
	foe.team = 1
	foe.max_hp = 1000.0
	foe.hp = 1000.0
	sim._skill_xp_hurt(hero, foe, 100.0)
	var total := 0.0
	var row: Dictionary = sim.skill_xp.get(str(hero.sprite), {})
	for k in row:
		total += float(row[k])
	return total


## Clearing a tier opens the next, it persists across a reload, and one biome's
## unlock never leaks to another. Writes to a scratch save file and restores it.
static func _difficulty_unlock_check() -> void:
	var keep_path: String = SaveGame.save_path
	var keep_no_write: bool = SaveGame.no_write
	var keep_backup: int = SaveGame._last_backup_ms
	var path := "user://sim_check_difficulty.json"
	var wipe := func() -> void:
		for p in [path, path + ".bak", path + ".tmp"]:
			if FileAccess.file_exists(p):
				DirAccess.remove_absolute(p)
	wipe.call()
	SaveGame.save_path = path
	SaveGame.no_write = false
	SaveGame.data = SaveGame._fresh()
	SaveGame._reconcile()
	if SaveGame.difficulty_unlocked("meadow") != 0 or SaveGame.difficulty_open("meadow", 1):
		_fail("a fresh save should only have Normal open")
	SaveGame._last_backup_ms = -SaveGame.BACKUP_EVERY_MS
	SaveGame._write()
	if not SaveGame.note_difficulty_clear("meadow", 0) or SaveGame.difficulty_unlocked("meadow") != 1:
		_fail("clearing Normal should open Veteran")
	if not SaveGame.difficulty_open("meadow", 1) or SaveGame.difficulty_open("meadow", 2):
		_fail("Veteran should be open and Nightmare still sealed")
	SaveGame.note_difficulty_clear("meadow", 1)
	SaveGame._write()
	if not SaveGame.difficulty_open("meadow", 2):
		_fail("clearing Veteran should open Nightmare")
	if SaveGame.difficulty_open("mushroom", 1):
		_fail("unlocking meadow must not open another biome")
	SaveGame._load()
	if SaveGame.difficulty_unlocked("meadow") != 2 or SaveGame.difficulty_open("mushroom", 1):
		_fail("difficulty unlocks did not persist across a reload")
	# commit_victory records the run's tier as a clear, opening the next.
	SaveGame.data = SaveGame._fresh()
	SaveGame._reconcile()
	var summary := SaveGame.commit_victory("meadow", "thistle", 0, 0)
	if int(summary.get("unlocked_tier", -1)) != 1:
		_fail("commit_victory did not open the next tier")
	wipe.call()
	SaveGame.save_path = keep_path
	SaveGame._last_backup_ms = keep_backup
	SaveGame.no_write = keep_no_write


static func _fail(message: String) -> void:
	failures += 1
	print("FAIL ", message)


const STEP := 1.0 / 60.0
