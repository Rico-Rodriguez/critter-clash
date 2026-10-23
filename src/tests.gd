class_name Tests
extends RefCounted
## Small rule checks, run with `-- --test`. Prints TEST <name> OK/FAIL and
## returns the number of failures. The save is kept in memory only.

var _fails := 0


func _ok(name_: String, cond: bool) -> void:
	print("TEST %s %s" % [name_, "OK" if cond else "FAIL"])
	if not cond:
		_fails += 1


func run() -> int:
	Game.memory_only = true
	Game.data = Game._fresh()
	# Content packs cannot add global classes: the installed IPA's class list
	# is fixed, and a script naming a class it lacks fails to compile (black
	# screen). New scripts are preloaded by path instead of using class_name.
	var baked := "Actor Ally Arena BoneScaler Boss BossHexer BossThorn DB DepthsLayout DevPanel Enemy Equipment Fx GearDB GearInspect GearLook GearStage GroveLayout Hero Hud Hunt HuntBot HuntCam Joystick KK LobbyUI Pact Pickup Portraits Proj RadialButton SettingsBox Sheet TalentDB Tests TierReveal TrialLayout Ui XpRing".split(" ")
	var extra := []
	for c in ProjectSettings.get_global_class_list():
		if not baked.has(str(c["class"])):
			extra.append(str(c["class"]))
	_ok("no class_name the IPA lacks %s" % str(extra), extra.is_empty())
	_ok("xp level 2", DB.xp_for_level(2) == 83)
	_ok("xp level 99", DB.xp_for_level(99) == 13034431)
	_ok("level for xp", DB.level_for_xp(DB.xp_for_level(40)) == 40 and DB.level_for_xp(DB.xp_for_level(40) - 1) == 39)
	_ok("fresh combat level", Game.combat_level() == 3)
	# Skills are per hero: XP from a hunt goes to the hero who played it.
	var keep_sk := Game.data.duplicate(true)
	Game.finish_hunt({"hero": "ranger", "xp": {"ranged": DB.xp_for_level(40), "hitpoints": 0}})
	_ok("hunt xp trains its hero", Game.skill_level("ranged", "ranger") == 40 and Game.combat_level("ranger") > 3)
	_ok("other heroes keep their own skills", Game.skill_level("ranged", "knight") == 1 and Game.combat_level("knight") == 3)
	Game.data = keep_sk

	var base: float = Game.hero_stats("knight")["hp"]
	Game.skills("knight")["hitpoints"] = DB.xp_for_level(11)
	var up: float = Game.hero_stats("knight")["hp"]
	Game.skills("knight")["hitpoints"] = DB.xp_for_level(10)
	_ok("hitpoints scale health", absf(up / base - (1.0 + DB.SKILL_EARLY)) < 0.001)
	# Bought levels are refunded in shards and gold, once.
	var keep_lv := Game.data.duplicate(true)
	Game.hero("knight")["level"] = 3
	var g_lv := Game.gold()
	var s_lv := int(Game.hero("knight")["shards"])
	Game._refund_levels()
	Game._refund_levels()
	_ok("bought levels refunded once", Game.gold() == g_lv + DB.UPGRADE_GOLD[1] + DB.UPGRADE_GOLD[2] and int(Game.hero("knight")["shards"]) == s_lv + DB.UPGRADE_SHARDS[1] + DB.UPGRADE_SHARDS[2] and int(Game.hero("knight")["level"]) == 1)
	# Lamps turn shards into XP for a skill the hero trains.
	Game.hero("knight")["shards"] = DB.LAMP_SHARDS
	var xp_lamp := Game.lamp_xp("knight", "strength")
	_ok("a ranger skill takes no lamp", not Game.rub_lamp("knight", "ranged"))
	_ok("lamp adds xp", Game.rub_lamp("knight", "strength") and Game.skill_xp("strength", "knight") == xp_lamp and int(Game.hero("knight")["shards"]) == 0)
	_ok("no shards, no lamp", not Game.can_rub_lamp("knight"))
	Game.data = keep_lv

	var common_boss := 0
	for i in 2000:
		if Game.roll_rarity("boss") == "common":
			common_boss += 1
	_ok("boss never drops common", common_boss == 0)

	var gold_before := Game.gold()
	var got := Game.open_chest("silver")
	_ok("chest pays gold", Game.gold() > gold_before and got.size() >= 3)

	# An exact copy of a worn rare is junk; the worn one and a different rare are not.
	var rare := Game.grant_item(Game.make_item("knight", "helm", 0, "rare"))
	var twin: Dictionary = Game.grant_item(rare.duplicate(true))
	var other := Game.grant_item(Game.make_item("knight", "chest", 0, "rare"))
	Game.equip("knight", int(rare["uid"]))
	var junk_uids := Game.junk_items().map(func(x): return int(x["uid"]))
	_ok("spare copy is junk", junk_uids.has(int(twin["uid"])) and not junk_uids.has(int(rare["uid"])) and not junk_uids.has(int(other["uid"])))

	var round_trip = JSON.parse_string(JSON.stringify(Game.data))
	_ok("save round trip", _same(Game.data, round_trip))

	# Bounties: a new day draws a fresh, stable set; progress counts and pays.
	Game.data = Game._fresh()
	_ok("bounties drawn", Game.refresh_bounties("2030-01-01") and Game.data["bounties"]["list"].size() == DB.BOUNTIES_PER_DAY)
	var first := JSON.stringify(Game.data["bounties"]["list"])
	_ok("bounties same day", not Game.refresh_bounties("2030-01-01") and JSON.stringify(Game.data["bounties"]["list"]) == first)
	_ok("bounties next day", Game.refresh_bounties("2030-01-02") and str(Game.data["bounties"]["day"]) == "2030-01-02")
	Game.data["bounties"]["list"] = [{"id": "kills", "target": 120, "gold": 150, "progress": 0, "claimed": false, "hero": "", "shards": 0, "shard_hero": ""}]
	Game.finish_hunt({"win": false, "tier": 0, "zone": "barrow", "hero": "knight", "gold": 10, "xp": {}, "items": [], "kills": 130, "elites": 0, "level": 3})
	_ok("bounty progress capped", int(Game.data["bounties"]["list"][0]["progress"]) == 120 and Game.bounty_claimable() == 1)
	var g0 := Game.gold()
	var paid := Game.claim_bounty(0)
	_ok("bounty pays once", int(paid.get("gold", 0)) == 150 and Game.gold() == g0 + 150 and Game.claim_bounty(0).is_empty())

	_ok("zones", Game.zone_unlocked("barrow") and not Game.zone_unlocked("depths") and Game.zone_id() == "barrow")
	Game.data["tier_unlocked"] = DB.TIER_VETERAN
	_ok("depths shut until veteran is won", not Game.zone_unlocked("depths"))
	Game.data["tier_unlocked"] = DB.TIER_VETERAN + 1
	_ok("depths opens after veteran", Game.zone_unlocked("depths"))
	for z in DB.ZONES:
		_ok("zone %s boss exists" % z, DB.BOSSES.has(DB.ZONES[z]["boss"]))
	for u in DB.LOG_ORDER:
		_ok("unique %s defined" % u, DB.UNIQUES.has(u))
	_depth_tests()
	_meta_tests()
	_unique_names()
	_net_tests()
	_gear_tests()
	return _fails


func _gear_tests() -> void:
	Game.data = Game._fresh()
	# Every part a gear stage names exists in its KayKit file, every weapon model loads.
	var missing := []
	var scenes := {}
	# Every look: stages, their alternatives, set looks and unique looks.
	var looks: Array = []
	for cls in GearDB.LINES:
		for slot in DB.SLOTS:
			for st: Dictionary in GearDB.LINES[cls][slot]:
				looks.append(st)
				looks.append_array(st.get("alts", []))
	for sid in GearDB.SET_LOOKS:
		_ok("set look %s is a set" % sid, DB.SETS.has(sid))
		for cls in GearDB.LINES:
			for slot in DB.SLOTS:
				looks.append(GearDB.SET_LOOKS[sid]["cls"][cls][slot])
	for u in GearDB.UNIQUE_LOOKS:
		_ok("unique look %s is a unique" % u, DB.UNIQUES.has(u))
		looks.append(GearDB.UNIQUE_LOOKS[u])
	for st: Dictionary in looks:
		for spec: String in GearDB.expand(st.get("parts", [])):
			var src := spec.get_slice("/", 0)
			if not scenes.has(src):
				scenes[src] = load(KK.CHAR_DIR + src + ".glb").instantiate()
			if (scenes[src] as Node).find_child(GearDB.mesh_name(spec), true, false) == null:
				missing.append(spec)
		var model := str(st.get("model", ""))
		if model.begins_with("kit:"):
			if not GearDB.KITS.has(model.trim_prefix("kit:")):
				missing.append(model)
			else:
				for part: Array in GearDB.KITS[model.trim_prefix("kit:")]:
					if not ResourceLoader.exists("res://assets/kaykit/" + str(part[0])):
						missing.append(part[0])
		elif model != "" and not ResourceLoader.exists(KK.WEAPON_DIR + model):
			missing.append(model)
		if st.has("icon") and not ResourceLoader.exists("res://assets/icons/%s.svg" % st["icon"]):
			missing.append(st["icon"])
	for n: Node in scenes.values():
		n.free()
	_ok("gear parts exist %s" % str(missing), missing.is_empty())
	var it := Game.make_item("mage", "chest", 3, "rare")
	_ok("item is class gear", it["cls"] == "mage" and it["mat"] == 3 and (str(it["name"]).ends_with("Sage Robe") or str(it["name"]).ends_with("Sage Ragged Robe")))
	# Alternatives and set looks change the model and the name, never the stats.
	it["look"] = 0
	_ok("look 0 is the stage", GearDB.base_name(it) == "Sage Robe")
	it["look"] = 1
	_ok("look 1 is the alternative", GearDB.base_name(it) == "Sage Ragged Robe" and GearDB.piece(it)["parts"].has("Skeleton_Mage/Body"))
	it["set"] = "hexer"
	_ok("a set piece wears the set", GearDB.base_name(it) == "Sage Necromancer Robe" and GearDB.accent(it) == GearDB.SET_LOOKS["hexer"]["accent"])
	var kn := Game.make_item("knight", "helm", 0, "common")
	kn["look"] = 1
	_ok("a stage without alternatives ignores look", GearDB.base_name(kn) == "Bronze Helm")
	# The first higher material a hero wears is news once; lower ones never are.
	Game.data = Game._fresh()
	for sk in DB.SKILLS:
		Game.skills("knight")[sk] = DB.xp_for_level(40)
	Game.new_tier = -1
	Game.equip("knight", int(Game.grant_item(Game.make_item("knight", "helm", 0, "common"))["uid"]))
	_ok("bronze is not a new tier", Game.new_tier == -1)
	Game.equip("knight", int(Game.grant_item(Game.make_item("knight", "chest", 3, "common"))["uid"]))
	_ok("mithril is a new tier", Game.new_tier == 3)
	Game.new_tier = -1
	Game.equip("knight", int(Game.grant_item(Game.make_item("knight", "legs", 2, "common"))["uid"]))
	_ok("steel after mithril is not", Game.new_tier == -1)
	Game.new_tier = -1
	Game.data = Game._fresh()
	Game.grant_item(it)
	_ok("wrong class blocked", Game.wear_block("knight", it) != "")
	_ok("low skill blocked", Game.wear_block("mage", it).begins_with("Requires Magic"))
	Game.skills("mage")["magic"] = DB.xp_for_level(40)
	_ok("skill lets you wear", Game.wear_block("mage", it) == "")
	Game.equip("mage", int(it["uid"]))
	_ok("equipped", Game.equipped("mage", "chest")["uid"] == it["uid"])
	Game.equip("knight", int(it["uid"]))
	_ok("knight cannot take it", Game.owner_of(int(it["uid"])) == "mage")
	# Old saves: v2 items become class gear and keep their wearer.
	var old := {"version": 2, "heroes": {"knight": {"gear": {"weapon": 5}}}, "items": [{"uid": 5, "slot": "weapon", "rarity": "rare", "name": "Old Brand", "stats": {"dmg": 9}, "unique": "", "tier": 1}, {"uid": 6, "slot": "chest", "rarity": "legendary", "name": "Shroud of the Barrow", "stats": {}, "unique": "shroud", "tier": 0}]}
	Game._migrate_v2(old)
	_ok("migrated to wearer", old["items"][0]["cls"] == "knight" and old["items"][0]["mat"] >= 2 and old["version"] == 3)
	var v3 := {"version": 3, "tier_unlocked": 2, "tier": 1, "stats": {"best": {"1": 80.0, "depths2": 90.0, "t1": 70.0, "rush2_mage": 60.0, "descent_mage": 7, "wildplace_knight": 2}}}
	Game._migrate_v3(v3)
	var b3: Dictionary = v3["stats"]["best"]
	_ok("v3 tiers move up the ladder", v3["tier_unlocked"] == 4 and v3["tier"] == 2 and v3["version"] == 4)
	_ok("v3 best keys follow", b3.has("2") and b3.has("depths4") and b3.has("t2") and b3.has("rush4_mage") and b3.has("descent_mage") and b3.has("wildplace_knight"))
	Game._migrate_v4(v3)
	var mt3: Dictionary = v3["mode_tiers"]
	_ok("v4 modes keep the tiers they won", v3["version"] == 5 and int(mt3["horde"]) == 4 and int(mt3["trial"]) == 3 and int(mt3["rush"]) == 4 and int(mt3["descent"]) == 4 and not mt3.has("wild"))
	var v5 := {"version": 5, "items": [{"name": "Moonlit Dragon Dragon Shield", "unique": ""}, {"name": "Ancient Black Dragonhide Chaps", "unique": ""}, {"name": "Worn Mystic Robe Top", "unique": ""}, {"name": "Crown of the Barrow King", "unique": "crown"}]}
	Game._migrate_v5(v5)
	var n5: Array = v5["items"].map(func(i: Dictionary) -> String: return str(i["name"]))
	_ok("v5 gear takes the new names %s" % str(n5), v5["version"] == Game.SAVE_VERSION and n5 == ["Moonlit Bloodiron Warden Shield", "Ancient Nightscale Chaps", "Worn Sage Robe", "Crown of the Barrow King"])
	# The error log folds repeats into one line with a count.
	var el = load("res://src/autoload/error_log.gd").new()
	el._enabled = false
	el._add("script", "hunt.gd:10 _tick", "Invalid access")
	el._add("script", "hunt.gd:10 _tick", "Invalid access")
	el._add("error", "fx.gd:3 burst", "Bad index")
	_ok("error log dedupes", el.error_count() == 3 and el._d["errors"].size() == 2 and el.report("T").contains("x2"))
	var sh0 := int(Game.hero(Game.hero_id())["shards"])
	Game.open_chest("gold")
	_ok("chest shards go to the hero played", int(Game.hero(Game.hero_id())["shards"]) - sh0 >= int(DB.CHESTS["gold"]["shards"] * DB.SHARDS_TO_PLAYED))
	_ok("armor curve diminishes", DB.armor_dr(0.15) > 0.12 and DB.armor_dr(2.0) <= DB.ARMOR_CAP and DB.armor_dr(1.0, 0.5) < DB.armor_dr(1.0))
	_ok("migrated unique", old["items"][1]["cls"] == "ranger" and old["items"][1]["mat"] == 6)
	_ok("modes defined", Game.mode_id() == "horde" and (DB.MODES["trial"]["rooms"] as Array).size() == DB.TIERS.size())
	Game.set_mode("trial")
	_ok("mode saved", Game.mode_id() == "trial")
	Game.set_mode("nonsense")
	_ok("bad mode ignored", Game.mode_id() == "trial")
	for t: Dictionary in DB.TIERS:
		_ok("tier %s has scaling" % t["id"], t.has("spd") and t.has("press"))
	for id in DB.HERO_ORDER:
		for c in DB.CARDS:
			if DB.CARDS[c].has("hero") and id in DB.CARDS[c]["hero"]:
				_ok("%s power card %s has an icon" % [id, c], Ui.icon(str(DB.CARDS[c]["icon"])) != null)
	var drops := {}
	var rng := RandomNumberGenerator.new()
	for i in 600:
		drops[GearDB.roll_mat(0, 0, rng)] = true
	_ok("normal does not drop dragon", not drops.has(6))


## Deep equality that treats 3 and 3.0 as equal (JSON has one number type).
func _same(a, b) -> bool:
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size():
			return false
		for k in a:
			if not b.has(k) or not _same(a[k], b[k]):
				return false
		return true
	if a is Array and b is Array:
		if a.size() != b.size():
			return false
		for i in a.size():
			if not _same(a[i], b[i]):
				return false
		return true
	if (a is int or a is float) and (b is int or b is float):
		return is_equal_approx(float(a), float(b))
	return typeof(a) == typeof(b) and a == b


## Talents, the renown road, clue scrolls, modes.
## Phase 11 meta: gold sinks, sets, mastery, rating, dailies, season, feats.
func _meta_tests() -> void:
	var keep := Game.data.duplicate(true)
	Game.data["gold"] = 100000
	for s in DB.SKILLS:
		Game.skills("knight")[s] = DB.xp_for_level(60)
	var it := Game.grant_item(Game.make_item("knight", "weapon", 2, "rare"))
	var uid := int(it["uid"])
	var main_v := int(it["stats"]["dmg"])
	_ok("reforge keeps the main affix", Game.reforge(uid) and int(Game.item(uid)["stats"]["dmg"]) == main_v)
	_ok("temper raises material and stats", Game.temper(uid) and int(Game.item(uid)["mat"]) == 3 and int(Game.item(uid)["stats"]["dmg"]) > main_v)
	var g0 := Game.gold()
	_ok("first respec is free", Game.respec("knight") and Game.gold() == g0)
	_ok("second respec costs gold", Game.respec("knight") and Game.gold() < g0)
	# Sets: four pieces of the Regalia give the 2 and 4 piece bonuses.
	var plain := Game.hero_stats("knight")
	for slot in ["helm", "chest", "legs", "trinket"]:
		var p := Game.make_item("knight", slot, 1, "magic")
		p["set"] = "gravemaw"
		Game.equip("knight", int(Game.grant_item(p)["uid"]))
	var dressed := Game.hero_stats("knight")
	_ok("set counts", int(Game.set_counts("knight").get("gravemaw", 0)) == 4)
	_ok("set flags reach the hunt", dressed["flags"].has("exposed"))
	_ok("boss items can be set pieces", Game.item_set({"unique": "cleaver"}) == "gravemaw")
	# Mastery and rating move with every hunt.
	var r := {"win": true, "tier": 2, "hero": "knight", "gold": 100, "kills": 400, "elites": 2, "xp": {}, "items": [], "mode": "horde", "time": 90.0, "zone": "barrow", "chest": "silver", "bosses": ["gravemaw"], "perfect": 4}
	Game.data["daily"] = {"day": "", "won": false}
	var m0 := int(Game.hero("knight")["mastery"])
	var r0 := int(Game.hero("knight")["rating"])
	var sm := Game.finish_hunt(r)
	_ok("first win of the day doubles gold", bool(sm.get("first_win", false)) and int(r["gold"]) == 200 and str(r["chest"]) == "gold")
	_ok("only once a day", not Game.first_win_ready())
	_ok("mastery gained", int(Game.hero("knight")["mastery"]) - m0 == 400 / 10 + 40 + 30)
	_ok("rating up on a win", int(Game.hero("knight")["rating"]) - r0 == DB.RATING_WIN + DB.RATING_WIN_TIER * 2)
	_ok("kill count and dry streak", Game.kc("gravemaw") == 1 and Game.dry("gravemaw") == 1)
	r["items"] = [Game.make_unique("crown")]
	Game.finish_hunt(r)
	_ok("a unique ends the dry streak", Game.kc("gravemaw") == 2 and Game.dry("gravemaw") == 0)
	r["win"] = false
	var before := int(Game.hero("knight")["rating"])
	Game.finish_hunt(r)
	_ok("rating down on a loss", int(Game.hero("knight")["rating"]) == before - DB.RATING_LOSS)
	_ok("best perfect dodges kept", int(Game.data["stats"]["best_perfect"]) == 4)
	# Dailies.
	Game.data["login"] = {"last": "", "count": 0}
	var rw := Game.claim_login()
	_ok("login day one pays", rw.has("gold") and not Game.login_status()["ready"])
	Game.data["idle_since"] = int(Time.get_unix_time_from_system()) - 7200
	_ok("campfire gathers gold", Game.idle_gold() > 0 and Game.claim_idle() > 0 and Game.idle_gold() == 0)
	# Season and feats.
	Game.season()["xp"] = DB.SEASON_XP * 2
	_ok("season steps open", Game.season_claimable() == 2 and not Game.claim_season().is_empty())
	_ok("feats count", Game.achievement_claimable() > 0 and Game.claim_achievement("first_blood") > 0 and Game.claim_achievement("first_blood") == 0)
	# Rift keys come from the deep Descent.
	var dr := {"win": false, "tier": 0, "hero": "mage", "gold": 5, "kills": 5, "elites": 0, "xp": {}, "items": [], "mode": "descent", "depth": DB.RIFT_DEPTH}
	Game.finish_hunt(dr)
	_ok("rift key dropped", int(Game.data["rift_keys"]) == 1 and Game.mode_unlocked("rift"))
	_ok("next goal says something", Game.next_goal() != "" or true)
	Game.data = keep


func _depth_tests() -> void:
	Game.data = Game._fresh()
	_ok("no points at combat 3", Game.talent_points("knight") == 0 and not Game.can_learn("knight", 0, 0))
	for sk in DB.STYLE_SKILLS["melee"]:
		Game.skills("knight")[sk] = DB.xp_for_level(16)
	_ok("three points at combat 18", Game.combat_level("knight") == 18 and Game.talent_points("knight") == 3)
	_ok("nodes need the one above", not Game.can_learn("knight", 0, 1) and Game.can_learn("knight", 0, 0))
	var hp0: float = Game.hero_stats("knight")["hp"]
	Game.learn_talent("knight", 0, 0)
	_ok("talent adds health", float(Game.hero_stats("knight")["hp"]) > hp0 * 1.07)
	Game.learn_talent("knight", 0, 1)
	Game.learn_talent("knight", 0, 2)
	_ok("stalwart sets second wind", float(Game.hero_stats("knight")["flags"].get("second_wind", 0.0)) > 0.0)
	_ok("points spent", Game.talent_points("knight") == 0)
	Game.respec("knight")
	_ok("respec is free", Game.talent_points("knight") == 3 and absf(float(Game.hero_stats("knight")["hp"]) - hp0) < 0.01)
	for hid in DB.HERO_ORDER:
		for path in TalentDB.paths(hid):
			_ok("%s %s has eight nodes" % [hid, path["name"]], path["nodes"].size() == 8)
			for n in path["nodes"]:
				for c in n.get("cards", []):
					_ok("talent card %s exists" % c, DB.CARDS.has(c))
	Game.data = Game._fresh()
	_ok("road starts closed", Game.road_claimable() == 0)
	Game.data["renown"] = DB.road_threshold(2)
	_ok("two steps open", Game.road_claimable() == 2)
	var gold_pre := Game.gold()
	Game.claim_road()
	_ok("claim pays and counts", int(Game.data["road"]) == 1 and Game.road_claimable() == 1 and Game.gold() > gold_pre)
	_ok("modes locked until a win", not Game.mode_unlocked("descent") and Game.mode_unlocked("horde"))
	Game.data["tier_unlocked"] = 1
	_ok("modes open after a win", Game.mode_unlocked("descent") and Game.mode_unlocked("rush"))
	# Difficulties open per mode: a Horde win does not open Hard in Boss Rush.
	Game.data["mode_tiers"] = {}
	Game.set_mode("horde")
	Game.finish_hunt({"win": true, "tier": 0, "hero": "knight", "gold": 1, "kills": 1, "elites": 0, "xp": {}, "items": [], "mode": "horde", "time": 100.0, "zone": "barrow"})
	_ok("a win opens the next tier in its mode", Game.mode_tier_unlocked("horde") == 1 and Game.mode_tier_unlocked("rush") == 0)
	Game.set_mode("rush")
	Game.set_tier(1)
	_ok("other modes stay shut", Game.tier() == 0)
	Game.finish_hunt({"win": false, "tier": 0, "hero": "knight", "gold": 1, "kills": 1, "elites": 0, "xp": {}, "items": [], "mode": "descent", "time": 300.0, "zone": "barrow", "depth": 6, "bosses": ["hexer"]})
	_ok("a Descent boss opens the Descent's next tier", Game.mode_tier_unlocked("descent") == 1)
	Game.set_mode("horde")
	Game.data["clue"] = {"step": 0, "goals": [{"id": "gold", "hero": "knight"}, {"id": "veteran", "hero": "knight"}, {"id": "elites", "hero": "knight"}]}
	var r := {"win": true, "tier": 1, "hero": "knight", "gold": 400, "elites": 3, "kills": 10, "xp": {}, "items": [], "dashes": 3, "mode": "horde", "time": 100.0, "zone": "barrow"}
	Game.finish_hunt(r)
	_ok("clue step 1", int(Game.clue().get("step", -1)) == 1)
	Game.finish_hunt(r)
	Game.finish_hunt(r)
	_ok("clue casket empties the scroll", Game.clue().is_empty() or Game.clue().has("goals"))
	var depth_r := {"win": false, "tier": 0, "hero": "mage", "gold": 5, "kills": 5, "elites": 0, "xp": {}, "items": [], "mode": "descent", "depth": 6}
	Game.finish_hunt(depth_r)
	_ok("deepest descent kept", Game.best_depth("mage") == 6)


## Every `%Name` a scene script looks up must be marked unique in its .tscn:
## a missing flag is a null at runtime (tapping the campfire crashed the app).
func _unique_names() -> void:
	var missing: Array = []
	var dirs: Array = ["res://src"]
	while not dirs.is_empty():
		var dir: String = dirs.pop_back()
		for sub in DirAccess.get_directories_at(dir):
			dirs.append(dir.path_join(sub))
		for f in DirAccess.get_files_at(dir):
			if not f.ends_with(".tscn") or not FileAccess.file_exists(dir.path_join(f.get_basename() + ".gd")):
				continue
			var uniq := {}
			var cur := ""
			for line in FileAccess.get_file_as_string(dir.path_join(f)).split("\n"):
				if line.begins_with("[node name=\""):
					cur = line.get_slice("\"", 1)
				elif line.begins_with("["):
					cur = ""
				elif cur != "" and line.strip_edges() == "unique_name_in_owner = true":
					uniq[cur] = true
			var re := RegEx.create_from_string("(?<![\\w\"'])%([A-Z]\\w*)")
			for m in re.search_all(FileAccess.get_file_as_string(dir.path_join(f.get_basename() + ".gd"))):
				if not uniq.has(m.get_string(1)):
					missing.append("%s:%s" % [f, m.get_string(1)])
	if not missing.is_empty():
		print("missing unique names: ", missing)
	_ok("scene unique names", missing.is_empty())


## The online layer's offline parts: what never needs a server.
func _net_tests() -> void:
	var Online := preload("res://src/net/online.gd")
	var Nk := preload("res://src/net/nk_client.gd")
	_ok("commas", Online.commas(25000) == "25,000" and Online.commas(999) == "999" and Online.commas(1234567) == "1,234,567")
	_ok("grant text", Online.grant_text({"kind": "gold", "amount": 2000}) == "2,000 gold" and Online.grant_text({"kind": "chest", "chest": "gold"}) == DB.CHESTS["gold"]["name"])
	var win := {"win": true, "tier": 0, "kills": 100, "elites": 2, "bosses": ["gravemaw"]}
	var t: Dictionary = DB.RAID_HIT
	_ok("raid damage", Online.raid_damage(win) == 100 * int(t["kill"]) + 2 * int(t["elite"]) + int(t["boss"]) + int(t["win"]))
	win["tier"] = 2
	_ok("raid damage grows with tier", Online.raid_damage(win) > Online.raid_damage({"win": true, "tier": 0, "kills": 100, "elites": 2, "bosses": ["gravemaw"]}))
	_ok("empty lists from the server", Online._as_list({}).is_empty() and Online._as_list([1]).size() == 1)
	_ok("lua errors trimmed", Nk._clean_error("/nakama/data/modules/gravelight.lua:236: That's your own code!\nstack traceback:\n...") == "That's your own code!")
	var claims := {"uid": "abc", "exp": 99}
	var mid := Marshalls.utf8_to_base64(JSON.stringify(claims)).replace("+", "-").replace("/", "_").trim_suffix("=").trim_suffix("=")
	_ok("session claims", Nk.jwt_claims("x." + mid + ".y").get("uid", "") == "abc")
	# Gift glows are earned, never bought.
	Game.data["gold"] = 999999
	_ok("kinship glow not for sale", not Game.buy_glow("knight", "kinship") and not "kinship" in Game.hero("knight")["glows"])
	Game.data = Game._fresh()
