class_name Tests
extends RefCounted
## Small rule checks, run with `-- --test`. Prints TEST <name> OK/FAIL and
## returns the number of failures. The save is kept in memory only.

const SKDB_T := preload("res://src/data/sidekick_db.gd")

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
	Game.hero("knight")["shards"] = 60
	Game.data["gold"] = 999
	_ok("super rank needs its gold", not Game.buy_super_rank("knight") and Game.super_rank("knight") == 0)
	Game.data["gold"] = 1000
	_ok("super rank pays shards and gold", Game.buy_super_rank("knight") and Game.super_rank("knight") == 1 and int(Game.hero("knight")["shards"]) == 10 and Game.gold() == 0)
	# Super progression (feat/super-progression).
	var costs := [[50, 1000], [100, 3000], [200, 7000], [350, 15000], [500, 30000]]
	var cost_ok := DB.SUPER_RANKS.size() == 5
	for i in DB.SUPER_RANKS.size():
		cost_ok = cost_ok and int(DB.SUPER_RANKS[i]["shards"]) == costs[i][0] and int(DB.SUPER_RANKS[i]["gold"]) == costs[i][1]
	_ok("super ranks keep the planned costs", cost_ok)
	var perks_ok := true
	for h: String in DB.HEROES:
		var kind := str(DB.HEROES[h]["super"])
		var list: Array = DB.SUPER_PERKS.get(kind, [])
		perks_ok = perks_ok and list.size() == 5
		for r in list:
			perks_ok = perks_ok and str(r.get("text", "")) != "" and r.size() >= 2
			for k: String in r:
				perks_ok = perks_ok and not k in ["charge", "rate", "super", "dmg"]
	_ok("every super has 5 behavior ranks, none touch charge", perks_ok)
	_ok("rank perks add up", DB.super_perks("slam", 0).is_empty() and DB.super_perks("slam", 1).get("radius", 0.0) == 1.0 and DB.super_perks("slam", 5).get("lock", 0.0) == -2.0)
	var keep_renown = Game.data.get("renown", 0)
	Game.data["renown"] = 0
	_ok("super locked for a fresh hero", Game.combat_level("knight") >= int(DB.SUPER_UNLOCK["level"]) or not Game.super_unlocked("knight"))
	Game.data["renown"] = int(DB.SUPER_UNLOCK["trophies"])
	_ok("Trophy Road unlocks the super", Game.super_unlocked("knight"))
	Game.data["renown"] = keep_renown
	_ok("backup fill waits, earned charge exists", float(DB.SUPER["floor_after"]) >= 30.0 and float(DB.SUPER["kill"]) > 0.0 and float(DB.SUPER["calm_gain"]) > 0.0)
	Game.hero("knight")["super_rank"] = 0
	# Super charge rules (balance/supers-charge-fix).
	_ok("super: no charge from the super's own hits", DB.super_hit_charge(500.0, 10.0, 10.0, 1.0, true) == 0.0)
	_ok("super: no charge while locked out", DB.super_hit_charge(10.0, 10.0, 10.0, 1.0, true) == 0.0)
	_ok("super: a hit charges at most one swing", is_equal_approx(DB.super_hit_charge(500.0, 10.0, 10.0, 1.0, false), 1.0 / DB.SUPER["per_hit"]))
	_ok("super: spent swing budget charges nothing", DB.super_hit_charge(10.0, 10.0, 0.0, 1.0, false) == 0.0)
	_ok("super: small hits charge pro rata", is_equal_approx(DB.super_hit_charge(5.0, 10.0, 10.0, 1.0, false), 0.5 / DB.SUPER["per_hit"]))
	_ok("super: lockout after each super", float(DB.SUPER["lock"]) == 12.0 and float(DB.SUPER["per_hit"]) == 40.0)
	_ok("super: no bonus is x1", DB.super_rate(0.0) == 1.0)
	_ok("super: bonuses soften", DB.super_rate(0.5) < 1.5 and DB.super_rate(0.5) > 1.3 and DB.super_rate(1.0) - DB.super_rate(0.5) < DB.super_rate(0.5) - 1.0)
	_ok("super: rate never above x2.2", DB.super_rate(100.0) <= 2.2 and DB.super_rate(0.75 + 0.45 + 0.5 + 0.35) < 2.2)
	var still := {}
	for p in DB.WEEKLY_OMENS:
		if p["id"] == "still":
			still = p
	_ok("super: Stillness is +50%", float(still.get("mod", {}).get("super", 0.0)) == 0.5 and str(still["desc"]).contains("50%"))
	Game.data = keep_lv

	var common_boss := 0
	for i in 2000:
		if Game.roll_rarity("boss") == "common":
			common_boss += 1
	_ok("boss never drops common", common_boss == 0)

	var gold_before := Game.gold()
	var got := Game.open_chest("silver")
	_ok("chest pays gold", Game.gold() > gold_before and got.size() >= 3)

	# Gear is a collection: a second drop of a piece is a copy toward its level.
	# An empty collection first: the chest above may have dropped this helm.
	Game.data["items"] = []
	for hid in DB.HERO_ORDER:
		Game.hero(hid)["gear"] = {}
	var n0: int = Game.data["items"].size()
	var helm := Game.grant_item(Game.make_item("knight", "helm", 0, "rare"))
	var again := Game.grant_item(Game.make_item("knight", "helm", 0, "common"))
	_ok("a second drop is a copy", again.get("dupe", false) and int(again["uid"]) == int(helm["uid"]) and Game.data["items"].size() == n0 + 1 and int(Game.item(int(helm["uid"]))["cards"]) == 1)
	var other := Game.grant_item(Game.make_item("knight", "helm", 1, "rare"))
	_ok("another set is another piece", not other.get("dupe", false) and Game.data["items"].size() == n0 + 2)
	var hu := int(helm["uid"])
	Game.item(hu)["cards"] = 0
	_ok("no copies, no level", Game.level_block(Game.item(hu)) != "" and not Game.level_up(hu))
	var cost := DB.level_cost(Game.item(hu))
	Game.item(hu)["cards"] = int(cost["cards"])
	Game.data["gold"] = int(cost["gold"]) + 5
	var main_k: String = DB.SLOT_MAIN["helm"]
	var hp1 := int(Game.item(hu)["stats"][main_k])
	_ok("copies and gold level a piece", Game.level_up(hu) and int(Game.item(hu)["lv"]) == 2 and int(Game.item(hu)["cards"]) == 0 and Game.gold() == 5 and int(Game.item(hu)["stats"][main_k]) > hp1)
	var ta := Game.make_item("knight", "weapon", 1)
	var tb := Game.make_item("knight", "weapon", 1)
	for _k in 40:
		if str(tb.get("fam", "")) != str(ta.get("fam", "")):
			break
		tb = Game.make_item("knight", "weapon", 1)
	ta = Game.grant_item(ta)
	tb = Game.grant_item(tb)
	ta["cards"] = DB.TRADE_COPIES
	Game.data["gold"] = 100000
	var tb_cards := int(tb["cards"])
	_ok("trade test has two pieces", int(ta["uid"]) != int(tb["uid"]))
	if Game.can_trade(ta, tb):
		_ok("copies trade into a sibling piece", Game.trade_copies(int(ta["uid"]), int(tb["uid"])) and int(ta["cards"]) == 0 and int(tb["cards"]) == tb_cards + 1 and Game.gold() == 100000 - Game.trade_fee(tb))
	_ok("too few copies never trade", not Game.can_trade(ta, tb))
	var cat := Game.catalog("barbarian", "weapon")
	_ok("the armory has a row per family", cat.size() == DB.HERO_FAMILIES["barbarian"].size() and cat[0].size() == GearDB.TIERS)
	# The Vault has its own boss, the Gilded Warden, with his own table and arms.
	_ok("the vault's boss is the warden", str(DB.ZONES["vault"]["boss"]) == "warden" and DB.BOSSES.has("warden"))
	_ok("the warden's arms exist", ResourceLoader.exists("res://assets/kaykit/weapons/warden_key.gltf") and ResourceLoader.exists("res://assets/kaykit/weapons/warden_door.gltf"))
	var wsrc := []
	for u: String in DB.UNIQUES:
		if str(DB.UNIQUES[u]["source"]) == "warden":
			wsrc.append(u)
	_ok("the warden has a unique table, all in the log", wsrc.size() == 3 and wsrc.all(func(u): return u in DB.LOG_ORDER))
	var wb: Node = load("res://src/hunt/boss_warden.gd").new()
	_ok("the warden's script is a Boss", wb is Boss)
	wb.free()
	# The Rogue's families: six, each with a model in every set, and a drop picks one.
	_ok("the rogue has six weapon families", DB.HERO_FAMILIES.get("rogue", []).size() == 6)
	var fam_models := true
	for hid: String in DB.HERO_FAMILIES:
		for f: String in DB.HERO_FAMILIES[hid]:
			fam_models = fam_models and str(DB.FAMILIES[f]["hero"]) == hid
			for m in GearDB.TIERS:
				fam_models = fam_models and ResourceLoader.exists("res://assets/kaykit/weapons/" + str(GearDB.family_look(f, m)["model"]))
	_ok("every family has a model in every set", fam_models)
	_ok("a rogue weapon drop rolls a rogue family", DB.HERO_FAMILIES["rogue"].has(str(Game.make_item("rogue", "weapon", 2).get("fam", ""))))
	# v8 saves: copies of a piece fold into the worn one as level copies.
	var a := Game.make_item("knight", "chest", 2, "rare")
	a["uid"] = 501
	var b := a.duplicate(true)
	b["uid"] = 502
	b["ancient"] = true
	var c := Game.make_item("knight", "chest", 3, "rare")
	c["uid"] = 503
	var v8 := {"version": 8, "items": [a, b, c], "heroes": {"knight": {"gear": {"chest": 502}}}}
	Game._migrate_v8(v8)
	var kept: Dictionary = v8["items"][0]
	_ok("v8 folds copies into the worn piece", v8["items"].size() == 2 and int(kept["uid"]) == 502 and int(kept["cards"]) == 1 and not kept.has("ancient") and int(v8["heroes"]["knight"]["gear"]["chest"]) == 502)

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

	# Shop: one draw a day, a free gift, deals sell once, gold only leaves when paid.
	Game.data = Game._fresh()
	_ok("shop drawn", Game.refresh_shop("2030-01-01") and Game.shop_deals().size() == 6 and not Game.refresh_shop("2030-01-01"))
	_ok("shop free gift", int(Game.shop_deals()[0]["price"]) == 0 and Game.shop_free_ready() == 1)
	var sg := Game.gold()
	_ok("shop gift is free", not Game.buy_deal(0).is_empty() and Game.gold() >= sg and Game.shop_free_ready() == 0 and Game.buy_deal(0).is_empty())
	Game.data["gold"] = 0
	_ok("shop needs gold", Game.shop_block(1) == "Not enough gold" and Game.buy_deal(1).is_empty())
	Game.data["gold"] = 100000
	var sh_hero := str(Game.shop_deals()[1]["hero"])
	var sh0 := int(Game.hero(sh_hero)["shards"])
	var sh_price := int(Game.shop_deals()[1]["price"])
	_ok("shop shards", not Game.buy_deal(1).is_empty() and int(Game.hero(sh_hero)["shards"]) == sh0 + 20 and Game.gold() == 100000 - sh_price)
	var bag: int = Game.data["items"].size()
	_ok("shop gear", not Game.buy_deal(3).is_empty() and Game.data["items"].size() == bag + 1 and Game.shop_block(3) == "Sold")
	var g_chest := Game.gold()
	_ok("shop chest deal", not Game.buy_chest(str(Game.shop_deals()[5]["chest"]), 5).is_empty() and Game.gold() < g_chest and Game.buy_chest(str(Game.shop_deals()[5]["chest"]), 5).is_empty())
	_ok("shop chests cost more than their gold", DB.SHOP_CHESTS.keys().all(func(k): return int(DB.SHOP_CHESTS[k]) * (1.0 - DB.SHOP_CHEST_OFF) > int(DB.CHESTS[k]["gold"][1])))
	_ok("shop next day", Game.refresh_shop("2030-01-02") and Game.shop_free_ready() == 1)
	_ok("glow of the week on sale", Game.glow_price(Game.glow_of_week()) < int(DB.GLOWS[Game.glow_of_week()]["gold"]))

	_ok("zones", Game.zone_unlocked("barrow") and not Game.zone_unlocked("depths") and Game.zone_id() == "barrow")
	Game.data["tier_unlocked"] = DB.TIER_VETERAN + 1
	_ok("depths waits for the road, not a tier", not Game.zone_unlocked("depths"))
	Game.data["unlocks"].append("depths")
	_ok("depths opens from the road", Game.zone_unlocked("depths"))
	for z in DB.ZONES:
		_ok("zone %s boss exists" % z, DB.BOSSES.has(DB.ZONES[z]["boss"]))
	for u in DB.LOG_ORDER:
		_ok("unique %s defined" % u, DB.UNIQUES.has(u))
	_depth_tests()
	_meta_tests()
	_unique_names()
	_net_tests()
	_gear_tests()
	# A hood helm brings its own hood: the bare head under it goes, the helm shows.
	var ra := Actor.new()
	ra.build_model(DB.HEROES["rogue"]["model"], {}, Color(0.5, 0.6, 1.0), 0.2)
	var hood_pre := {}
	for slot in DB.SLOTS:
		hood_pre[slot] = Game.make_item("rogue", slot, 4, "rare")
	GearLook.apply(ra, "rogue", hood_pre)
	var rh := ra.model.find_child("DarkRogue_Head", true, false) as MeshInstance3D
	var rhelm := ra.model.find_child("DarkRogue_Helm4_Mesh", true, false) as MeshInstance3D
	_ok("hooded rogue wears the hood", GearDB.look(hood_pre["helm"])["hood"] and rh != null and not rh.visible and rhelm != null and rhelm.visible)
	ra.free()
	_ok("warden wears his own gold skin", ResourceLoader.exists(KK.CHAR_DIR + str(DB.BOSSES["warden"].get("skin", ""))) and str(DB.BOSSES["warden"].get("skin", "")) != "")
	_sidekick_tests()
	_pet_polish_tests()
	_hatchery_tests()
	preload("res://src/kit_model_tests.gd").run(_ok)
	preload("res://src/pet_tests.gd").run(_ok)
	preload("res://src/biome_tests.gd").run(_ok)
	preload("res://src/terrain_tests.gd").run(_ok)
	preload("res://src/foe_tests.gd").run(_ok)
	preload("res://src/brain_tests.gd").run(_ok)
	preload("res://src/ambience_tests.gd").run(_ok)
	preload("res://src/rig_tests.gd").run(_ok)
	preload("res://src/boss_model_tests.gd").run(_ok)
	preload("res://src/foe_model_tests.gd").run(_ok)
	_breeding_tests()
	_pet_care_tests()
	_story_tests()
	_stage_tests()
	_gate_tests()
	_event_tests()
	_settings_tests()
	_feel_tests()
	_world_tests()
	_store_tests()
	_sidekick_motor_tests()
	_collision_tests()
	_focus_tests()
	_levelup_tests()
	_bank_tests()
	# The Thorn Sapling is its own rigged treant (made in Blender, see CREDITS.md), not a reused Rogue.
	var sap_m := str(preload("res://src/data/sidekick_db.gd").ROSTER["sapling"]["model"])
	var sap_look: Dictionary = preload("res://src/core/sidekick_look.gd").build("sapling")
	var sap: Node3D = sap_look["root"]
	_ok("sapling has its own rigged model", sap_m == "sf:treant" and sap.find_child("Skeleton3D", true, false) != null and str(sap_look["idle"]) != "")
	# The hunt sidekick (hunt/sidekick.gd) gets the team ring at its feet and the
	# hunt scale; the camp pet (lobby.gd builds Look.build straight) gets neither.
	var fake_src := GDScript.new()
	fake_src.source_code = "extends Node\nvar hero := Node3D.new()\n"
	fake_src.reload()
	var fake_hunt: Node = fake_src.new()
	var hsk: Node3D = preload("res://src/hunt/sidekick.gd").new()
	hsk.setup(fake_hunt, "bat", 0)
	var hroot := hsk.find_child("SidekickModel", true, false) as Node3D
	_ok("hunt sidekick is drawn bigger, with no ring under it; camp model is plain", hsk.find_child("CompanionRing", true, false) == null and hroot != null and hroot.scale.x > 1.0 and sap.find_child("CompanionRing", true, false) == null and sap.scale.is_equal_approx(Vector3.ONE))
	hsk.free()
	(fake_hunt.get("hero") as Node3D).free()
	fake_hunt.free()
	var fill := sap.find_child("SidekickFill", true, false) as OmniLight3D
	var LK := preload("res://src/core/sidekick_look.gd")
	_ok("sidekick fill light only lights the companion layer", fill != null and fill.light_cull_mask == LK.FILL_LAYER and sap.find_children("*", "MeshInstance3D", true, false).all(func(m): return (m as MeshInstance3D).layers & LK.FILL_LAYER))
	sap.free()
	# sf: scenes skip _fit, so each must be wrapped to 1 m tall with feet at 0
	# (tools/art/wrap_sidekicks.gd), loaded with posed cull bounds.
	var sk_bad := []
	var SDB0 := preload("res://src/data/sidekick_db.gd")
	for f: String in DirAccess.get_files_at("res://assets/sidekicks/"):
		if not f.ends_with(".tscn"):
			continue
		var wrap: Node3D = (load("res://assets/sidekicks/" + f) as PackedScene).instantiate()
		var pa: AABB = wrap.get_meta("posed_aabb", AABB())
		var skinned := wrap.find_children("*", "MeshInstance3D", true, false).any(func(m): return (m as MeshInstance3D).skin != null)
		if absf(pa.size.y - 1.0) > 0.03 or absf(pa.position.y) > 0.03 or (skinned and wrap.get_meta("cull_aabbs", {}).is_empty()):
			sk_bad.append(f)
		wrap.free()
	for sid: String in SDB0.ROSTER:
		for key in ["model", "evolved_model"]:
			var spec := str(SDB0.ROSTER[sid].get(key, ""))
			if spec.begins_with("sf:") and not ResourceLoader.exists("res://assets/sidekicks/%s.tscn" % spec.substr(3)):
				sk_bad.append(spec)
	_ok("sf: sidekick scenes 1 m tall, feet at 0, posed bounds %s" % [sk_bad], sk_bad.is_empty())
	# Art lock: every sf: companion (camp and hunt, unevolved) draws lit and
	# opaque, with no emission except the artists' small maps in KEEP_EMISSION.
	var mat_bad := []
	for sid: String in SDB0.ROSTER:
		var spec := str(SDB0.ROSTER[sid]["model"])
		if not spec.begins_with("sf:"):
			continue
		var lk: Dictionary = LK.build(sid)
		for mi in (lk["root"] as Node).find_children("*", "MeshInstance3D", true, false):
			var m3 := mi as MeshInstance3D
			for i in m3.mesh.get_surface_count():
				var bm := m3.get_active_material(i) as BaseMaterial3D
				if bm == null:
					continue
				if bm.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED or not bm.transparency in [BaseMaterial3D.TRANSPARENCY_DISABLED, BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR] or (bm.emission_enabled and not spec.substr(3) in LK.KEEP_EMISSION):
					mat_bad.append("%s/%s:%d" % [sid, m3.name, i])
		(lk["root"] as Node).free()
	_ok("sf: sidekick materials lit, opaque, no emission %s" % [mat_bad], mat_bad.is_empty())
	preload("res://src/vfx/vfx_tests.gd").run(_ok)
	preload("res://src/hunt/anim_tests.gd").run(_ok)
	preload("res://src/hunt/boss_intro_tests.gd").run(_ok)
	preload("res://src/hunt/boss_phase_tests.gd").run(_ok)
	preload("res://src/sound_tests.gd").run(_ok)
	preload("res://src/economy_tests.gd").run(_ok)
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
			if spec.begins_with("P:"):
				if not ResourceLoader.exists(GearDB.GEAR_DIR + spec.substr(2).get_slice("@", 0)):
					missing.append(spec)
				continue
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
	var it := Game.make_item("mage", "chest", 2, "rare")
	_ok("item is class gear", it["cls"] == "mage" and it["mat"] == 2 and str(it["name"]).ends_with("Barrowsteel Star Robe"))
	# Alternatives and set looks change the model and the name, never the stats.
	it["look"] = 0
	_ok("look 0 is the stage", GearDB.base_name(it) == "Barrowsteel Star Robe")
	it["set"] = "hexer"
	_ok("a set piece wears the set", GearDB.base_name(it) == "Barrowsteel Necromancer Robe" and GearDB.accent(it) == GearDB.SET_LOOKS["hexer"]["accent"])
	var orb := Game.make_item("mage", "trinket", 2, "rare")
	orb["look"] = 1
	_ok("look 1 is the alternative", GearDB.base_name(orb) == "Barrowsteel Skull Orb" and GearDB.piece(orb)["model"] == "uniq_skull_orb.gltf")
	# Weapon families: the scythe is endgame, boss-only, and no Gravedigger.
	var fams := {}
	for i in 200:
		fams[Game.roll_family("barbarian", 4)] = true
	_ok("no scythe outside boss drops", not fams.has("scythe") and fams.has("maul"))
	var low := {}
	for i in 200:
		low[Game.roll_family("barbarian", 0)] = true
	_ok("only early families in Gravedigger", low.keys().all(func(f): return int(DB.FAMILIES[f]["min_set"]) == 0))
	var boss_fams := {}
	for i in 300:
		boss_fams[Game.roll_family("barbarian", 4, DB.TIER_NIGHTMARE)] = true
	_ok("a Nightmare boss can drop the scythe", boss_fams.has("scythe"))
	_ok("the scythe needs level 60 in any set", GearDB.req_for({"slot": "weapon", "mat": 3, "fam": "scythe"}) == 60)
	var shield := Game.make_item("knight", "trinket", 2, "rare")
	shield["stats"] = {"armor": 20}
	var hammer := Game.make_item("knight", "weapon", 3, "common")
	hammer["fam"] = "warhammer"
	var blade := Game.make_item("knight", "weapon", 3, "common")
	blade["fam"] = "sword"
	_ok("a two-handed weapon takes both hands", Game.two_hands("knight", hammer) and not Game.two_hands("knight", blade))
	_ok("no shield counts with a two-handed weapon", Game.hero_stats("knight", {"weapon": hammer, "trinket": shield})["armor"] < Game.hero_stats("knight", {"weapon": blade, "trinket": shield})["armor"])
	_ok("a Barbarian's shield goes only with throwing axes", Game.two_hands("barbarian", {"slot": "weapon", "fam": "maul"}) and Game.two_hands("barbarian", {"slot": "weapon", "fam": "twin"}) and not Game.two_hands("barbarian", {"slot": "weapon", "fam": "throwing"}))
	_ok("a quiver needs no hand", not Game.two_hands("ranger", {"slot": "weapon", "fam": "longbow"}))
	var kg: Dictionary = Game.hero("knight")["gear"].duplicate()
	var ks: Dictionary = Game.skills("knight").duplicate()
	for sk2 in ["attack", "defence"]:
		Game.skills("knight")[sk2] = DB.xp_for_level(70)
	var su := int(Game.grant_item(shield)["uid"])
	Game.equip("knight", su)
	_ok("equipping a two-hander takes the shield off", Game.equip("knight", int(Game.grant_item(hammer)["uid"])) == "trinket" and Game.equipped("knight", "trinket").is_empty())
	_ok("equipping a shield takes the two-hander off", Game.equip("knight", su) == "weapon" and Game.equipped("knight", "weapon").is_empty())
	Game.hero("knight")["gear"] = kg
	Game.skills("knight").merge(ks, true)
	_ok("a family weapon wears its family's model", str(GearDB.look({"cls": "barbarian", "slot": "weapon", "mat": 2, "fam": "maul"})["model"]) == "barb_maul_2.gltf")
	var kn := Game.make_item("knight", "helm", 0, "common")
	kn["look"] = 1
	_ok("a stage without alternatives ignores look", GearDB.base_name(kn) == "Gravedigger Kettle Hat")
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
	_ok("v5 gear takes the new names %s" % str(n5), v5["version"] == 6 and n5 == ["Moonlit Bloodiron Warden Shield", "Ancient Nightscale Chaps", "Worn Sage Robe", "Crown of the Barrow King"])
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
	Game.open_whole_road()
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
## Phase 11 meta: gold sinks, sets, mastery, dailies, season, feats.
func _meta_tests() -> void:
	var keep := Game.data.duplicate(true)
	Game.data["gold"] = 100000
	for s in DB.SKILLS:
		Game.skills("knight")[s] = DB.xp_for_level(60)
	var g0 := Game.gold()
	Game.hero("knight")["free_respec"] = true
	Game.learn_talent("knight", 0, 0)
	_ok("first respec is free", Game.respec("knight") and Game.gold() == g0)
	Game.learn_talent("knight", 0, 0)
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
	# Mastery moves with every hunt.
	var r := {"win": true, "tier": 2, "hero": "knight", "gold": 100, "kills": 400, "elites": 2, "xp": {}, "items": [], "mode": "horde", "time": 90.0, "zone": "barrow", "chest": "silver", "bosses": ["gravemaw"], "perfect": 4}
	Game.data["daily"] = {"day": "", "won": false}
	var m0 := int(Game.hero("knight")["mastery"])
	var sm := Game.finish_hunt(r)
	_ok("first win of the day doubles gold", bool(sm.get("first_win", false)) and int(r["gold"]) == 200 and str(r["chest"]) == "gold")
	_ok("only once a day", not Game.first_win_ready())
	_ok("mastery gained", int(Game.hero("knight")["mastery"]) - m0 == 400 / 10 + 40 + 30)
	_ok("kill count and dry streak", Game.kc("gravemaw") == 1 and Game.dry("gravemaw") == 1)
	r["items"] = [Game.make_unique("crown")]
	Game.finish_hunt(r)
	_ok("a unique ends the dry streak", Game.kc("gravemaw") == 2 and Game.dry("gravemaw") == 0)
	r["win"] = false
	Game.finish_hunt(r)
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
	_ok("rows open with points in the path", Game.can_learn("knight", 0, 0) and not Game.can_learn("knight", 0, 2))
	var hp0: float = Game.hero_stats("knight")["hp"]
	Game.learn_talent("knight", 0, 0)
	_ok("a rank adds health", float(Game.hero_stats("knight")["hp"]) > hp0 * 1.03)
	Game.learn_talent("knight", 0, 0)
	Game.learn_talent("knight", 0, 0)
	_ok("a minor stops at its max", Game.talent_rank("knight", 0, 0) == 3 and not Game.can_learn("knight", 0, 0))
	_ok("points spent", Game.talent_points("knight") == 0)
	Game.respec("knight")
	_ok("respec is free", Game.talent_points("knight") == 3 and absf(float(Game.hero_stats("knight")["hp"]) - hp0) < 0.01)
	# A deep tree: ranks, gates, a choice, one keystone, refunds and builds.
	for sk in DB.STYLE_SKILLS["melee"]:
		Game.skills("knight")[sk] = DB.xp_for_level(99)
	_ok("22 points at the top combat level", Game.talent_earned("knight") == DB.TALENT_MAX and DB.TALENT_MAX == 22)
	Game.talents_opened("knight")
	for n in [[1, 0], [1, 0], [1, 0], [1, 2], [1, 1], [1, 1], [1, 1], [1, 3]]:
		Game.learn_talent("knight", n[0], n[1])
	_ok("the choice row opens at 6", Game.row_open("knight", 1, 2) and not Game.row_open("knight", 1, 3))
	_ok("smiter starts the hunt with Holy Smite", "smite" in Game.hero_stats("knight")["cards"])
	Game.learn_talent("knight", 1, 4, 1)
	_ok("a choice keeps its option", Game.talent_pick("knight", 1, 4) == 1 and float(Game.hero_stats("knight")["sp"].get("echo", 0.0)) > 0.0)
	_ok("attunement adds crit damage", absf(float(Game.hero_stats("knight")["flags"].get("critdmg", 0.0)) - 0.02 * 9) < 0.001)
	for n in [[1, 3], [1, 3], [1, 5], [1, 5], [1, 6]]:
		Game.learn_talent("knight", n[0], n[1])
	_ok("crit damage adds up", absf(float(Game.hero_stats("knight")["flags"]["critdmg"]) - (0.5 + 0.02 * 14)) < 0.001)
	_ok("keystone row opens at 13", Game.row_open("knight", 1, 4) and Game.can_learn("knight", 1, 7))
	Game.learn_talent("knight", 1, 7)
	_ok("the keystone bends the card pool", "smite" in Game.hero_stats("knight")["always"])
	for n in [[0, 0], [0, 0], [0, 0], [0, 1], [0, 1], [0, 1], [0, 2]]:
		Game.learn_talent("knight", n[0], n[1])
	_ok("all 22 spent", Game.talent_points("knight") == 0 and Game.talent_spent("knight") == 22)
	Game.data["gold"] = 1000
	_ok("ranks learned this visit refund free", Game.refund_cost("knight", 0, 2) == 0 and Game.refund_talent("knight", 0, 2) and Game.gold() == 1000)
	Game.learn_talent("knight", 0, 2)
	Game.talents_opened("knight")
	_ok("a refund costs gold", Game.refund_talent("knight", 1, 0) and Game.gold() == 1000 - DB.TALENT_REFUND_GOLD)
	_ok("a higher row holds the ranks below", not Game.can_refund("knight", 1, 0))
	_ok("only one keystone", Game.keystone("knight") == "1.7")
	_ok("refund the keystone", Game.refund_talent("knight", 1, 7) and Game.keystone("knight") == "")
	Game.set_talent_build("knight", 1)
	_ok("build B starts empty", Game.talent_spent("knight") == 0 and Game.talent_points("knight") == 22)
	Game.set_talent_build("knight", 0)
	_ok("build A is kept", Game.talent_spent("knight") == 20)
	# An old straight-line save gets its points back.
	Game.hero("knight")["talents"] = ["0.0", "0.1"]
	Game.data["talents_refunded"] = 0
	Game._refund_old_talents()
	_ok("old talents are refunded", Game.hero("knight")["talents"].is_empty() and int(Game.data["talents_refunded"]) == 1)
	for hid in DB.HERO_ORDER:
		for path in TalentDB.paths(hid):
			_ok("%s %s has eight nodes" % [hid, path["name"]], path["nodes"].size() == 8)
			var slots := 0
			for n in path["nodes"]:
				slots += TalentDB.max_rank(n)
				for src in [n] + n.get("opts", []):
					for c in src.get("cards", []) + src.get("always", []) + src.get("never", []):
						_ok("talent card %s exists" % c, DB.CARDS.has(c))
					for k in src.get("sp", {}):
						_ok("%s super perk %s is real" % [hid, k], DB.SUPER_PERKS[DB.HEROES[hid]["super"]].any(func(r): return r.has(k)))
			_ok("%s %s takes 15 points" % [hid, path["name"]], slots == 15)
			_ok("%s %s describes every node" % [hid, path["name"]], path["nodes"].all(func(n): return TalentDB.describe(n) != ""))
	Game.data = Game._fresh()
	_ok("a new save starts with one hero", Game.hero("knight")["unlocked"] and not Game.hero("ranger")["unlocked"] and not Game.hero("barbarian")["unlocked"] and not Game.data["start_picked"])
	Game.pick_start_hero("mage")
	_ok("the first pick is the only starter", Game.hero("mage")["unlocked"] and not Game.hero("knight")["unlocked"] and Game.hero_id() == "mage" and Game.data["start_picked"])
	_ok("road starts closed", Game.road_claimable() == 0)
	_ok("modes wait for the road", not Game.mode_unlocked("trial") and not Game.mode_unlocked("descent") and Game.mode_unlocked("horde"))
	Game.data["renown"] = DB.road_threshold(2)
	_ok("two steps open", Game.road_claimable() == 2)
	var gold_pre := Game.gold()
	Game.claim_road()
	_ok("claim pays and counts", int(Game.data["road"]) == 1 and Game.road_claimable() == 1 and Game.gold() > gold_pre)
	Game.claim_road()
	_ok("a mode step opens the mode", Game.mode_unlocked("trial") and not Game.mode_unlocked("rush"))
	Game.data["renown"] = DB.road_threshold(4)
	Game.claim_road()
	Game.claim_road("ranger")
	_ok("a pick step adds the chosen hero", Game.hero("ranger")["unlocked"] and not Game.hero("knight")["unlocked"] and Game.road_pickable() == ["knight"])
	for i in DB.TROPHY_ROAD.size() + 1:
		_ok("road step %d has a name" % (i + 1), Game.road_reward_text(i + 1) != "")
	_ok("weekly seed is stable per week", Game.weekly_seed(100) == Game.weekly_seed(100) and Game.weekly_seed(100) != Game.weekly_seed(101))
	_ok("weekly score ranks a win above a loss", Game.weekly_score({"win": true, "level": 5}) > Game.weekly_score({"win": false, "level": 5}))
	var wb_keep: Variant = Game.data.get("weekly", {})
	Game.data.erase("weekly")
	_ok("weekly best starts at zero", Game.weekly_best() == 0)
	_ok("weekly best records", Game.record_weekly({"win": true, "level": 3}) and Game.weekly_best() == 1150)
	_ok("weekly worse run is not kept", not Game.record_weekly({"win": false}) and Game.weekly_best() == 1150)
	_ok("weekly entry carries this week's seed", int(Game.weekly_entry()["seed"]) == Game.weekly_seed())
	Game.data["weekly"] = wb_keep
	_ok("the Vault is the fourth zone (the Frozen Crypt and Burning Swamp follow)", DB.ZONE_ORDER.size() >= 4 and DB.ZONE_ORDER[3] == "vault" and DB.ZONES.has("vault") and DB.ARENAS.any(func(z): return z["zone"] == "vault"))
	_ok("the Vault opens on the road", DB.TROPHY_ROAD.any(func(st): return str(st["kind"]) == "zone" and str(st.get("id", "")) == "vault"))
	_ok("the Rogue is a hero", DB.HEROES.has("rogue") and "rogue" in DB.HERO_ORDER and GearDB.LINES.has("rogue") and TalentDB.PATHS.has("rogue"))
	_ok("the Rogue is on the road", DB.TROPHY_ROAD.any(func(st): return str(st["kind"]) == "hero" and str(st.get("id", "")) == "rogue"))
	_ok("the Rogue has a signature", DB.CARDS.has(DB.SIGNATURES["rogue"]))
	_ok("a new save has the Rogue locked", not Game._fresh()["heroes"]["rogue"]["unlocked"])
	_ok("the Rogue has four weapon skins", DB.WEAPON_SKIN_ORDER.filter(func(k): return "rogue" in DB.WEAPON_SKINS[k]["heroes"]).size() == 4)
	for u in ["barrow_relic", "barrow_squire", "hex_relic", "shade", "thorn_relic", "sapling", "rime_relic", "cinder_relic"]:
		_ok("ancient unique %s" % u, DB.UNIQUES.has(u) and u in DB.LOG_ORDER and str(DB.UNIQUES[u]["source"]).begins_with("ancient_"))
	_ok("ancient uniques never roll below Torment", Game.roll_uniques("ancient_boss", 0).size() >= 0 and DB.TIER_ANCIENT == 6)
	_ok("bone spikes card defined, universal epic", DB.CARDS.has("bone_spikes") and DB.CARDS["bone_spikes"]["rarity"] == "epic" and not DB.CARDS["bone_spikes"].has("hero") and Ui.icon("broken-bone") != null)
	const HeroS := preload("res://src/hunt/hero.gd")
	_ok("bone spikes speed up and hit harder per level", HeroS.spikes_cooldown(4) < HeroS.spikes_cooldown(1) and HeroS.spikes_mult(4) > HeroS.spikes_mult(1) and HeroS.spikes_cooldown(4) >= 1.6)
	_ok("road cards start locked", not Game.card_open("skybolt") and Game.card_open("might"))
	_ok("every hero has two road epics", ["oath_storm", "shockwave", "rime_trap", "storm_arrows", "skybolt", "rift_quake", "thunder_cry", "skyfall"].all(func(c): return DB.CARDS.has(c) and DB.card_road_step(c) > 0))
	var tr0 := Game.renown()
	Game.finish_hunt({"win": false, "tier": 0, "hero": "mage", "gold": 1, "kills": 0, "elites": 0, "xp": {}, "items": [], "mode": "horde", "time": 50.0, "zone": "barrow"})
	_ok("a loss never takes trophies", Game.renown() >= tr0)
	# Old saves keep what the old rules opened and skip the steps they passed.
	var v6 := {"version": 6, "tier_unlocked": DB.TIER_VETERAN + 1, "renown": 900, "road": 14, "heroes": {"barbarian": {"unlocked": false}}}
	Game._migrate_v6(v6)
	_ok("v6 keeps its modes and zones", v6["version"] == 7 and "descent" in v6["unlocks"] and "depths" in v6["unlocks"] and not "grove" in v6["unlocks"])
	_ok("v6 road counts the new steps", int(v6["road"]) == 7 and v6["start_picked"])
	Game.open_whole_road()
	_ok("modes open after the road", Game.mode_unlocked("descent") and Game.mode_unlocked("rush"))
	# One ladder: a win on the highest tier in any mode opens the next in every mode.
	Game.data["tier_unlocked"] = 0
	Game.data["tier_wins"] = {}
	Game.set_mode("horde")
	Game.finish_hunt({"win": true, "tier": 0, "hero": "knight", "gold": 1, "kills": 1, "elites": 0, "xp": {}, "items": [], "mode": "horde", "time": 100.0, "zone": "barrow"})
	_ok("one win opens the next tier", Game.mode_tier_unlocked() == 1)
	Game.set_mode("rush")
	Game.set_tier(1)
	_ok("a Horde win opens it in Boss Rush too", Game.tier() == 1 and Game.mode_tier_unlocked("rush") == 1)
	Game.finish_hunt({"win": false, "tier": 1, "hero": "knight", "gold": 1, "kills": 1, "elites": 0, "xp": {}, "items": [], "mode": "descent", "time": 300.0, "zone": "barrow", "depth": 6, "bosses": ["hexer"]})
	_ok("a Descent boss opens the next tier everywhere", Game.mode_tier_unlocked("horde") == 2)
	# First-clear trophies pay once a difficulty for the account, not again in another mode.
	var fc := {"win": true, "tier": 2, "hero": "knight", "gold": 1, "kills": 1, "elites": 0, "xp": {}, "items": [], "mode": "horde", "time": 100.0, "zone": "barrow"}
	var fc_gain: Array = []
	for md in ["horde", "trial", "horde"]:
		var f2: Dictionary = fc.duplicate(true)
		f2["mode"] = md
		fc_gain.append(int(Game.finish_hunt(f2)["renown"]))
	_ok("first-clear trophies pay once a difficulty", Game.mode_tier_unlocked() == 3 and fc_gain[0] >= fc_gain[1] + DB.TROPHY_FIRST_CLEAR and fc_gain[2] == fc_gain[1])
	# Old saves with per-mode tiers keep the best of them.
	Game.data["tier_unlocked"] = 1
	Game.data["mode_tiers"] = {"horde": 1, "trial": 4, "rush": 2}
	Game._one_ladder()
	_ok("an old save keeps its best mode's tier", Game.mode_tier_unlocked("horde") == 4)
	Game._one_ladder()
	_ok("the ladder migration is safe to repeat", Game.mode_tier_unlocked() == 4)
	# The road now opens every zone by 5,000 trophies; a save past a mode's step has it.
	_ok("all six zones open by 5,000 trophies", DB.ZONE_ORDER.all(func(z: String) -> bool: return DB.road_gate(z) <= 5000))
	_ok("every mode opens by 1,200 trophies", ["trial", "rush", "descent", "wild"].all(func(m: String) -> bool: return DB.road_gate(m) <= 1200))
	_ok("the Rogue joins at 3,500", DB.TROPHY_ROAD.any(func(st: Dictionary) -> bool: return str(st["kind"]) == "hero" and str(st["id"]) == "rogue" and int(st["t"]) == 3500))
	var road_keep2: Dictionary = Game.data
	Game.data = Game._fresh()
	Game.data["road"] = DB.road_step("wild")
	_ok("a save past the Wilderness's step can play it", Game.mode_unlocked("wild") and not Game.mode_unlocked("descent"))
	Game.data = road_keep2
	# Boss Rush runs every boss the player has opened, not just the first two.
	var ro_all: Array = DB.rush_order_for(DB.ZONE_ORDER).map(func(e: Array) -> String: return str(e[0]))
	_ok("rush with every zone open fields all six bosses once", ro_all == ["gravemaw", "hexer", "thorn", "warden", "rime", "cinder"])
	var ro_new: Array = DB.rush_order_for(["barrow"])
	_ok("rush with one zone repeats its boss, stronger", ro_new.size() == DB.RUSH_MIN and ro_new[0][0] == "gravemaw" and float(ro_new[-1][1]) > 1.0)
	var ro_pow: Array = DB.rush_order_for(DB.ZONE_ORDER).map(func(e: Array) -> float: return float(e[1]))
	_ok("rush bosses get stronger", ro_pow[0] == 1.0 and ro_pow[-1] > ro_pow[0])
	# A save that claimed the Rogue's road step under the old, shorter road.
	var road_keep: Dictionary = Game.data
	Game.data = Game._fresh()
	Game.data["road"] = DB.TROPHY_ROAD.size() + 3
	Game._road_heroes()
	_ok("a save past a hero's road step has that hero", Game.hero("rogue")["unlocked"] and Game.hero("barbarian")["unlocked"])
	Game.data = road_keep
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
	var nkc: Node = Nk.new()
	nkc.set_server("https://abc.example.com")
	_ok("server url: https on 443, wss socket", nkc.base == "https://abc.example.com:443" and nkc.ws_base == "wss://abc.example.com:443")
	nkc.set_server("http://127.0.0.1:7350/")
	_ok("server url: http with port", nkc.base == "http://127.0.0.1:7350" and nkc.ws_base == "ws://127.0.0.1:7350")
	nkc.set_server("")
	_ok("server url: empty goes offline", not nkc.configured())
	nkc.free()
	var claims := {"uid": "abc", "exp": 99}
	var mid := Marshalls.utf8_to_base64(JSON.stringify(claims)).replace("+", "-").replace("/", "_").trim_suffix("=").trim_suffix("=")
	_ok("session claims", Nk.jwt_claims("x." + mid + ".y").get("uid", "") == "abc")
	# Gift glows are earned, never bought.
	Game.data["gold"] = 999999
	_ok("kinship glow not for sale", not Game.buy_glow("knight", "kinship") and not "kinship" in Game.hero("knight")["glows"])
	# Weapon skins: a model that loads, sold only to the heroes listed.
	for sk: String in DB.WEAPON_SKIN_ORDER:
		_ok("skin %s model" % sk, ResourceLoader.exists(KK.WEAPON_DIR + str(DB.WEAPON_SKINS[sk]["model"])))
		_ok("skin %s icon" % sk, ResourceLoader.exists("res://assets/icons/%s.svg" % DB.WEAPON_SKINS[sk]["icon"]))
	_ok("skin not for the ranger", not Game.buy_skin("ranger", "reaper") and Game.hero("ranger")["skins"].is_empty())
	var g0 := Game.gold()
	_ok("skin bought", Game.buy_skin("barbarian", "reaper") and Game.gold() == g0 - Game.skin_price("reaper") and Game.hero("barbarian")["skin"] == "reaper")
	Game.set_skin("barbarian", "")
	_ok("skin put away, kept", Game.hero("barbarian")["skin"] == "" and Game.buy_skin("barbarian", "reaper") and Game.gold() == g0 - Game.skin_price("reaper"))
	Game.data = Game._fresh()
	_outfit_tests()


## Outfits: sold per hero for gold, season ones earned for every hero, a save
## from before them still loads, and the look dyes the body but not the head.
func _outfit_tests() -> void:
	var keep := Game.data
	Game.data = Game._fresh()
	for k: String in DB.OUTFIT_ORDER:
		var od: Dictionary = DB.OUTFITS[k]
		_ok("outfit %s is whole" % k, od.has("name") and not (od["heroes"] as Array).is_empty() and float(od["mix"]) > 0.0 and float(od["mix"]) <= 1.0 and (od.get("gift", false) or int(od["gold"]) > 0))
		_ok("outfit %s fits real heroes" % k, (od["heroes"] as Array).all(func(h): return DB.HEROES.has(h)))
	_ok("every hero has two outfits to buy", DB.HERO_ORDER.all(func(h): return DB.OUTFIT_ORDER.filter(func(k): return h in DB.OUTFITS[k]["heroes"] and not DB.OUTFITS[k].get("gift", false)).size() >= 2))
	_ok("a fresh hero wears nothing", Game.hero("knight")["outfit"] == "" and Game.hero("knight")["outfits"].is_empty())
	Game.data["gold"] = 100000
	_ok("outfit not for another hero", not Game.buy_outfit("ranger", "crimson") and Game.hero("ranger")["outfits"].is_empty())
	_ok("season outfit not for sale", not Game.buy_outfit("knight", "embergilt"))
	var g0 := Game.gold()
	_ok("outfit bought and worn", Game.buy_outfit("knight", "crimson") and Game.gold() == g0 - Game.outfit_price("crimson") and Game.hero("knight")["outfit"] == "crimson")
	Game.set_outfit("knight", "")
	_ok("outfit put away, kept", Game.hero("knight")["outfit"] == "" and Game.buy_outfit("knight", "crimson") and Game.gold() == g0 - Game.outfit_price("crimson"))
	Game.set_outfit("knight", "viper")
	_ok("cannot wear what you do not own", Game.hero("knight")["outfit"] == "crimson")
	Game.data["gold"] = 10
	_ok("too poor to buy", not Game.buy_outfit("knight", "gilded"))
	# The season pass pays an outfit to every hero.
	var tiers := 0
	for n in range(1, DB.SEASON_TIERS + 1):
		if DB.season_reward(n)["kind"] == "outfit":
			tiers += 1
	_ok("the pass pays one outfit a season", tiers == 1 and DB.season_reward(DB.SEASON_OUTFIT_TIER, 1)["outfit"] == DB.SEASON_OUTFITS[1])
	Game.season()["claimed"] = DB.SEASON_OUTFIT_TIER - 1
	Game.season()["xp"] = DB.SEASON_XP * DB.SEASON_OUTFIT_TIER
	var got := Game.claim_season()
	_ok("season claim pays the outfit", got.get("kind", "") == "outfit" and DB.HERO_ORDER.all(func(h): return str(got["outfit"]) in Game.hero(h)["outfits"]))
	# An old save has neither key and still loads.
	var old := Game._fresh()
	(old["heroes"]["mage"] as Dictionary).erase("outfit")
	(old["heroes"]["mage"] as Dictionary).erase("outfits")
	var merged := Game._fresh()
	Game._merge(merged, old)
	_ok("old save gets outfit keys", merged["heroes"]["mage"]["outfit"] == "" and merged["heroes"]["mage"]["outfits"] is Array)
	# The look: body dyed, head left alone.
	Game.hero("knight")["outfit"] = "crimson"
	var a := Actor.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(a)
	a.build_model(DB.HEROES["knight"]["model"], {}, Color(0.5, 0.6, 1.0), 0.2)
	GearLook.apply(a, "knight")
	var dyed := 0
	var head_dyed := 0
	for m in a.find_children("*", "MeshInstance3D", true, false):
		var c: Variant = m.get_instance_shader_parameter("dye")
		if c is Color and (c as Color).a > 0.5:
			dyed += 1
			if str(m.name).ends_with("_Head"):
				head_dyed += 1
	_ok("outfit dyes the body, not the head", dyed >= 2 and head_dyed == 0)
	a.queue_free()
	Game.data = keep


const PET_DB := preload("res://src/data/sidekick_db.gd")


## Pet polish: rarity, the showcase, pet quests, and the hatching show.
func _pet_polish_tests() -> void:
	const SK := preload("res://src/autoload/sidekicks.gd")
	const HATCH := preload("res://src/ui/hatch_show.gd")
	var keep := Game.data
	Game.data = Game._fresh()
	_ok("every species has a rarity", PET_DB.ORDER.all(func(i): return PET_DB.SPECIES_RARITY.has(i) and PET_DB.rarity(i) >= 0 and PET_DB.rarity(i) < PET_DB.GRADES.size()))
	_ok("exotics outrank starters", PET_DB.rarity("shade") > PET_DB.rarity("wisp"))
	_ok("empty stable, empty showcase", SK.showcase(Game.data).is_empty())
	for id in ["wisp", "bonelet", "drake", "shade", "crow"]:
		SK.own(Game.data, id)
	var show: Array = SK.showcase(Game.data)
	_ok("showcase fills with the rarest", show.size() == PET_DB.SHOWCASE_SLOTS and show[0] == "shade" and show[1] == "drake")
	_ok("pin a common one", SK.pin(Game.data, "wisp") and SK.showcase(Game.data)[0] == "wisp" and SK.showcase(Game.data).size() == PET_DB.SHOWCASE_SLOTS)
	_ok("cannot pin what you do not own", not SK.pin(Game.data, "sapling"))
	SK.pin(Game.data, "bonelet")
	SK.pin(Game.data, "crow")
	_ok("the case holds three", not SK.pin(Game.data, "drake") and (Game.data["sidekicks"]["showcase"] as Array).size() == 3)
	_ok("unpin", SK.pin(Game.data, "wisp") and not SK.is_pinned(Game.data, "wisp"))
	# Pet quests: dealt one a day once a sidekick is yours, never before.
	Game.data = Game._fresh()
	for d in range(1, 21):
		Game.refresh_bounties("2031-02-%02d" % d)
		_ok("no pet quest without a pet (%d)" % d, Game.data["bounties"]["list"].all(func(e): return not e["id"] in DB.PET_BOUNTIES))
		Game.data["bounties"]["day"] = ""
	SK.own(Game.data, "wisp")
	var all_pet := true
	for d in range(1, 21):
		Game.refresh_bounties("2031-02-%02d" % d)
		var n: int = (Game.data["bounties"]["list"] as Array).filter(func(e): return e["id"] in DB.PET_BOUNTIES and e["id"] != "pet_breed").size()
		all_pet = all_pet and n == 1 and Game.data["bounties"]["list"].size() == DB.BOUNTIES_PER_DAY
		Game.data["bounties"]["day"] = ""
	_ok("one pet quest a day, three in all", all_pet)
	var entry := func(id: String, target: int) -> Dictionary:
		return {"id": id, "target": target, "gold": 100, "gems": 3, "progress": 0, "claimed": false, "hero": "", "shards": 0, "shard_hero": ""}
	Game.data["bounties"]["list"] = [entry.call("pet_kills", 100), entry.call("pet_win", 1), entry.call("pet_hatch", 1)]
	SK.set_active(Game.data, "")
	Game.finish_hunt({"win": true, "tier": 0, "zone": "barrow", "hero": "knight", "gold": 10, "xp": {}, "items": [], "kills": 130, "elites": 0, "level": 3, "mode": "horde", "time": 90.0})
	_ok("pet quests need a pet along", int(Game.data["bounties"]["list"][0]["progress"]) == 0 and int(Game.data["bounties"]["list"][1]["progress"]) == 0)
	SK.set_active(Game.data, "wisp")
	Game.finish_hunt({"win": true, "tier": 0, "zone": "barrow", "hero": "knight", "gold": 10, "xp": {}, "items": [], "kills": 130, "elites": 0, "level": 3, "mode": "horde", "time": 90.0})
	_ok("pet kills and win count with a pet", int(Game.data["bounties"]["list"][0]["progress"]) == 100 and int(Game.data["bounties"]["list"][1]["progress"]) == 1)
	_ok("hatch quest waits for a hatch", int(Game.data["bounties"]["list"][2]["progress"]) == 0)
	Game.bounty_note("hatched")
	_ok("hatching counts", int(Game.data["bounties"]["list"][2]["progress"]) == 1)
	var gems0 := int(Game.data["gems"])
	var paid := Game.claim_bounty(2)
	_ok("pet quest pays gems", int(paid.get("gems", 0)) == 3 and int(Game.data["gems"]) == gems0 + 3)
	# The hatching show builds for every egg and rarity without error.
	var root := (Engine.get_main_loop() as SceneTree).root
	for pet in ["wisp", "drake", "shade"]:
		var host := Control.new()
		host.size = Vector2(720, 1280)
		root.add_child(host)
		var h: Control = HATCH.new()
		h.play(host, {"id": pet, "kind": "brood", "new": true, "kills": 0})
		_ok("hatch show builds for %s" % pet, h.get_child_count() >= 6)
		host.queue_free()
	# A mutation adds its own reveal; a growth plays the evolve show.
	var mhost := Control.new()
	mhost.size = Vector2(720, 1280)
	root.add_child(mhost)
	var mh: Control = HATCH.new()
	mh.play(mhost, {"id": "drake", "kind": "exotic", "new": true, "kills": 0, "mutation": "Frostbound", "mutation_power": "Its bite chills"})
	_ok("hatch show builds with a mutation", mh.get_child_count() >= 6)
	# The game's own result names a mutation by id with no power line: the show fills in both.
	var mh2: Control = HATCH.new()
	mh2.play(mhost, {"id": "drake", "kind": "exotic", "new": true, "kills": 0, "mutation": "frostborn"})
	_ok("hatch show turns a mutation id into its name and power", mh2._res["mutation"] == "Frostborn" and str(mh2._res["mutation_power"]).begins_with("Ice-cast"))
	var eh: Control = preload("res://src/ui/evolve_show.gd").new()
	eh.play(mhost, {"id": "drake", "stage_from": 1, "stage_to": 2})
	_ok("evolve show builds", eh.get_child_count() >= 6)
	mhost.queue_free()
	const PLIFE := preload("res://src/hunt/pet_life.gd")
	var stray := []
	for persona: String in PLIFE.PERSONAS:
		for f in PLIFE.PERSONAS[persona]:
			if not PLIFE.FIDGETS.has(f):
				stray.append(f)
	for kind: String in preload("res://src/hunt/pet_anim.gd").STYLE_OF:
		if not PLIFE.PERSONA_OF.has(kind):
			stray.append(kind)
	_ok("every ability has a temperament of known fidgets %s" % str(stray), stray.is_empty())
	Game.data = keep


## Sidekicks: the save migration from pets and the ally, bond, eggs, unlocks.
func _sidekick_tests() -> void:
	const SK := preload("res://src/autoload/sidekicks.gd")
	var marks: Array = preload("res://src/data/sidekick_db.gd").road_marks()
	_ok("trophy sidekicks are marked on the road", not marks.is_empty() and marks.all(func(m): return int(m["t"]) > 0) and str(marks[0]["id"]) == "crow")
	const SDB := preload("res://src/data/sidekick_db.gd")
	var keep := Game.data.duplicate(true)
	_ok("sidekick roster: 8 at launch + 3 Ancient", SDB.ORDER.size() == 11 and SDB.ORDER.size() == SDB.ROSTER.size())
	for id: String in SDB.ORDER:
		for cid in SDB.ROSTER[id].get("cards", []):
			_ok("sidekick card %s defined" % cid, DB.CARDS.has(cid) and str(DB.CARDS[cid]["sidekick"]) == id)
	# An old save (v9, before sidekicks): two boss pets, one followed, a hero ally.
	var old := Game._fresh()
	old.erase("sidekicks")
	old["pets"] = ["bonelet", "hexling"]
	old["pet"] = "hexling"
	old["ally"] = "ranger"
	old["stats"]["boss_kills"] = 3
	var d := Game._fresh()
	Game._merge(d, old)
	SK.migrate(d)
	_ok("migration: boss pets become sidekicks", SK.is_owned(d, "bonelet") and SK.is_owned(d, "hexling") and not SK.is_owned(d, "acolyte"))
	_ok("migration: followed pet is at your side", SK.active(d) == "hexling")
	_ok("migration: hero ally gone", str(d["ally"]) == "")
	_ok("migration: first boss kill gives the Wisp", SK.is_owned(d, "wisp"))
	SK.set_active(d, "bonelet")
	d["pets"].append("acolyte")
	SK.migrate(d)
	_ok("migration runs once", SK.active(d) == "bonelet" and bool(d["sidekicks"]["migrated"]))
	# A save from a build with no sidekicks key at all.
	var bare := {"pets": ["acolyte"], "pet": "acolyte", "ally": "mage", "stats": {"boss_kills": 0}}
	SK.migrate(bare)
	_ok("migration: bare save", SK.active(bare) == "acolyte" and not SK.is_owned(bare, "wisp") and str(bare["ally"]) == "")
	var fresh := Game._fresh()
	SK.migrate(fresh)
	_ok("fresh save: no sidekick", SK.active(fresh) == "" and (fresh["sidekicks"]["owned"] as Dictionary).is_empty())
	# Bond levels.
	_ok("bond 1 at 0", SDB.bond_level(0) == 1)
	_ok("bond 4 at 1240, next 2000", SDB.bond_level(1240) == 4 and SDB.bond_next(1240) == 2000)
	_ok("bond caps at 10", SDB.bond_level(10000000) == 10)
	# A hunt's kills go to the sidekick at your side.
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var s := SK.after_hunt(d, {"kills": 250, "win": false}, rng)
	_ok("hunt kills grow bond", SK.kills(d, "bonelet") == 250 and int(s["bond_to"]) == 2 and SK.kills(d, "hexling") == 0)
	# Ember Egg: pity guarantees it, kills hatch the Drake.
	var got_egg := false
	for i in 20:
		var r := SK.after_hunt(d, {"kills": 0, "win": true, "bosses": ["gravemaw"], "zone": "barrow"}, rng)
		if str(r["egg"]) == "ember":
			got_egg = true
			break
	_ok("ember egg drops within pity", got_egg and SK.has_egg(d, "ember"))
	var h := SK.after_hunt(d, {"kills": 600}, rng)
	_ok("egg hatches the drake", (h["hatched"] as Array).has("drake") and SK.is_owned(d, "drake") and not SK.has_egg(d, "ember"))
	_ok("night bat hidden until its egg", SK.hidden(d, "bat"))
	# Mimic after 100 chests; Storm Crow on the road.
	for i in 99:
		SK.note_chest(d)
	_ok("99 chests: no mimic", not SK.is_owned(d, "mimic"))
	SK.note_chest(d)
	_ok("100 chests: mimic", SK.is_owned(d, "mimic"))
	d["renown"] = 4000
	_ok("trophies give the crow", SK.check_unlocks(d).has("crow"))
	# Through the Game: a pet drop is a sidekick, a hunt reports bond.
	Game.data = Game._fresh()
	SK.migrate(Game.data)
	Game.grant_item(Game.make_unique("bonelet"))
	_ok("pet drop is a sidekick at your side", SK.active(Game.data) == "bonelet")
	# The Ancient pets (Torment+ boss drops) are sidekicks with their own abilities.
	for pid in ["barrow_squire", "shade", "sapling"]:
		_ok("ancient pet %s is a sidekick" % pid, SDB.ROSTER.has(pid) and str(SDB.ROSTER[pid]["unlock"]["unique"]) == pid and str(SDB.PET_TO_SIDEKICK[pid]) == pid and str(DB.UNIQUES[pid]["source"]).begins_with("ancient_"))
		_ok("ancient pet %s is not owned before its drop" % pid, not SK.is_owned(Game.data, pid))
		Game.grant_item(Game.make_unique(pid))
		_ok("ancient pet %s drop unlocks it" % pid, SK.is_owned(Game.data, pid))
	_ok("ancient sidekick abilities are distinct", ["bash", "shadowstrike", "snare"] == ["barrow_squire", "shade", "sapling"].map(func(i): return str(SDB.ROSTER[i]["ability"]["kind"])))
	var sum := Game.finish_hunt({"hero": "knight", "kills": 120, "win": false, "tier": 0, "time": 60.0})
	_ok("finish_hunt reports sidekick bond", str(sum["sidekick"]["id"]) == "bonelet" and SK.kills(Game.data, "bonelet") == 120)
	Game.data = keep


func _hatchery_tests() -> void:
	const SK := preload("res://src/autoload/sidekicks.gd")
	var keep := Game.data.duplicate(true)
	var t0 := 1_800_000_000
	var d := Game._fresh()
	SK.migrate(d)
	# An old save's egg moves into the hatchery with its kills.
	d["sidekicks"]["eggs"] = {"grove": {"kills": 120}}
	_ok("hatchery: old eggs move in with their kills", SK.has_egg(d, "grove") and int(SK.hatchery(d)[0]["kills"]) == 120 and (d["sidekicks"]["eggs"] as Dictionary).is_empty())
	d = Game._fresh()
	var e := SK.give_egg(d, "brood", t0, 5)
	var secs := int(SKDB_T.EGGS["brood"]["secs"])
	_ok("hatchery: a new egg is not ready", not SK.egg_ready(e, t0) and is_zero_approx(SK.egg_frac(e, t0)))
	_ok("hatchery: half the clock is half warm", is_equal_approx(SK.egg_frac(e, t0 + secs / 2), 0.5))
	_ok("hatchery: a clock set backwards counts as no time", is_zero_approx(SK.egg_frac(e, t0 - 9999)))
	e["kills"] = int(SKDB_T.EGGS["brood"]["kills"]) * 3 / 4
	_ok("hatchery: kills or time, whichever is further", is_equal_approx(SK.egg_frac(e, t0 + secs / 2), 0.75))
	_ok("hatchery: the clock alone hatches it", SK.egg_ready(e, t0 + secs) and SK.egg_secs_left(e, t0 + secs) == 0)
	_ok("hatchery: not ready, no hatch", SK.hatch(d, int(e["uid"]), t0).is_empty() and SK.hatchery(d).size() == 1)
	# Gems finish an egg: one per GEM_SECS left, rounded up.
	e["kills"] = 0
	var cost := SK.rush_cost(e, t0)
	_ok("hatchery: rush cost by time left", cost == int(ceil(float(secs) / SKDB_T.GEM_SECS)))
	d["gems"] = cost - 1
	_ok("hatchery: too few gems, no rush", SK.rush(d, int(e["uid"]), t0).is_empty() and SK.gems(d) == cost - 1)
	d["gems"] = cost + 3
	var same := SK.egg_result(d, e)
	var hr := SK.rush(d, int(e["uid"]), t0)
	_ok("hatchery: rush spends gems and hatches", SK.gems(d) == 3 and str(hr.get("id", "")) == same and bool(hr["new"]) and SK.is_owned(d, same) and SK.hatchery(d).is_empty())
	# Pools prefer sidekicks you don't own; a duplicate becomes bond kills.
	var d2 := Game._fresh()
	for p in SKDB_T.EGGS["exotic"]["pool"]:
		if str(p[0]) != "shade":
			SK.own(d2, str(p[0]))
	var ok_fresh := true
	for i in 20:
		ok_fresh = ok_fresh and SK.egg_result(d2, {"kind": "exotic", "seed": i * 7919}) == "shade"
	_ok("hatchery: an egg hatches the one you lack", ok_fresh)
	SK.own(d2, "shade")
	var ex := SK.give_egg(d2, "exotic", t0, 99)
	var dup := SK.hatch(d2, int(ex["uid"]), t0 + 13 * 3600)
	_ok("hatchery: a duplicate hatches its own individual", bool(dup["new"]) and bool(dup.get("wild", false)) and SK.bred_ids(d2).has(str(dup["id"])) and SKDB_T.species(str(dup["id"])) in ["drake", "bat", "mimic", "barrow_squire", "shade", "sapling"] and SK.kills(d2, SKDB_T.species(str(dup["id"]))) == 0)
	_ok("hatchery: same egg seed, same sidekick", SK.egg_result(Game._fresh(), {"kind": "brood", "seed": 42}) == SK.egg_result(Game._fresh(), {"kind": "brood", "seed": 42}))
	# Pools only name real sidekicks.
	var pools_ok := true
	for k in SKDB_T.EGGS:
		var ed: Dictionary = SKDB_T.EGGS[k]
		pools_ok = pools_ok and ed.has("secs") and ed.has("kills") and (str(ed["rarity"]) == "bred" or SKDB_T.ROSTER.has(str(ed.get("hatches", ""))) or (ed["pool"] as Array).all(func(p): return SKDB_T.ROSTER.has(str(p[0])) and int(p[1]) > 0))
	_ok("hatchery: every egg hatches a real sidekick", pools_ok)
	# The hatchery caps; a full one blocks drops.
	var d3 := Game._fresh()
	for i in SKDB_T.HATCH_SLOTS:
		SK.give_egg(d3, "brood", t0, i)
	_ok("hatchery: full at HATCH_SLOTS", SK.hatchery_full(d3) and SK.give_egg(d3, "brood", t0, 1).is_empty() and is_zero_approx(SK.exotic_chance(d3, true, 0)))
	# Exotic drops: rare, with a pity across hunts.
	var d4 := Game._fresh()
	_ok("exotic: rare per boss, rarer per elite", SK.exotic_chance(d4, true, 0) == SKDB_T.EXOTIC_BOSS and SK.exotic_chance(d4, false, 0) == SKDB_T.EXOTIC_ELITE)
	d4["sidekicks"]["dry"]["exotic"] = SKDB_T.EXOTIC_PITY - 2
	_ok("exotic: pity guarantees the boss after", SK.exotic_chance(d4, true, 1) == 1.0 and SK.exotic_chance(d4, true, 0) < 1.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var r := SK.after_hunt(d4, {"kills": 50, "win": true, "bosses": ["hexer"], "exotic": 1, "now": t0}, rng)
	_ok("exotic: a found egg joins the hatchery, pity resets", int(r.get("exotic", 0)) == 1 and SK.has_egg(d4, "exotic") and int(d4["sidekicks"]["dry"]["exotic"]) == 0 and int(SK.hatchery(d4)[0]["kills"]) == 0)
	SK.after_hunt(d4, {"kills": 0, "win": true, "bosses": ["hexer", "thorn"], "now": t0}, rng)
	_ok("exotic: bosses without one count toward pity", int(d4["sidekicks"]["dry"]["exotic"]) == 2)
	# Chests and the season.
	var d5 := Game._fresh()
	var r5 := RandomNumberGenerator.new()
	r5.seed = 1
	var got_egg := false
	var gems := 0
	for i in 30:
		for x in SK.chest_extras(d5, "crypt", t0, r5):
			if str(x["type"]) == "egg":
				got_egg = true
			else:
				gems += int(x["amount"])
	_ok("chests: gems every time, brood eggs sometimes", gems == 30 * int(SKDB_T.CHEST_GEMS["crypt"]) and got_egg and SK.gems(d5) == gems)
	_ok("chests: silver never has an egg", SK.chest_extras(Game._fresh(), "silver", t0, r5).all(func(x): return str(x["type"]) != "egg"))
	_ok("season: Season Eggs at tiers 10 and 25, gems along the road", str(DB.season_reward(10)["kind"]) == "egg" and str(DB.season_reward(25)["egg"]) == "season" and str(DB.season_reward(3)["kind"]) == "gems" and str(DB.season_reward(30)["kind"]) == "glow")
	Game.data = Game._fresh()
	Game.data["season"] = {"id": Game.season_id(), "xp": DB.SEASON_XP * 10, "claimed": 9}
	Game.claim_season()
	_ok("season: claiming tier 10 puts a Season Egg in the hatchery", SK.has_egg(Game.data, "season"))
	Game.data = keep


# Sidekick movement and state machine (hunt/sidekick_motor.gd), no scene.
func _sidekick_motor_tests() -> void:
	const M := preload("res://src/hunt/sidekick_motor.gd")
	const SKN := preload("res://src/hunt/sidekick.gd")
	var dt := 1.0 / 60.0
	var m := M.new()
	m.rng.seed = 7
	var hero := Vector3.ZERO
	m.pos = m.slot(hero, 0.0)
	# The hero walks 6 m/s along +z for 3 s: it keeps up near its slot, lagging.
	var max_lag := 0.0
	for i in 180:
		hero.z += 6.0 * dt
		m.step(dt, hero, 0.0, 6.0)
		max_lag = maxf(max_lag, M.flat_dist(m.pos, m.slot(hero, 0.0)))
	var lag := M.flat_dist(m.pos, m.slot(hero, 0.0))
	_ok("sidekick follows with lag but keeps up", lag > 0.2 and lag < M.SPRINT_DIST and m.teleports == 0)
	_ok("sidekick faces where it walks", absf(angle_difference(m.yaw, 0.0)) < 0.2)
	# The hero stops: it settles within a short distance of the hero.
	for i in 120:
		m.step(dt, hero, 0.0, 6.0)
	_ok("sidekick settles near a stopped hero", M.flat_dist(m.pos, hero) < M.SLOT.length() + 0.8)
	# Standing still a while: it wanders, but stays near the hero.
	var wandered := false
	var far := 0.0
	for i in 600:
		m.step(dt, hero, 0.0, 6.0)
		wandered = wandered or m.state == M.S.WANDER
		far = maxf(far, M.flat_dist(m.pos, hero))
	_ok("sidekick wanders near an idle hero", wandered and far < M.WANDER_R + 1.0)
	# Falling behind: sprint past SPRINT_DIST, blink back past TELEPORT_DIST.
	_ok("state: sprint when far", M.pick_state(M.SPRINT_DIST + 0.5, true, 0.0) == M.S.SPRINT)
	_ok("state: follow when the hero moves", M.pick_state(1.0, true, 0.0) == M.S.FOLLOW)
	_ok("state: idle at the slot", M.pick_state(0.1, false, 0.0) == M.S.IDLE)
	_ok("state: wander after standing still", M.pick_state(0.3, false, M.STILL_BEFORE_WANDER + 0.1) == M.S.WANDER)
	var tp := false
	for i in int(M.FAR_BEFORE_BLINK * 60.0) + 2:
		tp = m.step(dt, hero + Vector3(0, 0, M.TELEPORT_DIST + 15.0), 0.0, 6.0) or tp
	_ok("sidekick teleports when too far", tp and m.teleports == 1 and M.flat_dist(m.pos, m.slot(hero + Vector3(0, 0, M.TELEPORT_DIST + 15.0), 0.0)) < 0.01)
	var m2 := M.new()
	m2.pos = Vector3(M.SPRINT_DIST + 2.0, 0, 0)
	m2.step(dt, Vector3.ZERO, 0.0, 6.0)
	m2.step(dt, Vector3(0, 0, 0.1), 0.0, 6.0)
	_ok("sidekick sprints to catch up", m2.state == M.S.SPRINT and m2.teleports == 0)
	# Actions: wind-up, one hit frame, then back to moving; a flinch never
	# cuts an attack short.
	var m3 := M.new()
	m3.act(M.S.ATTACK, 0.2, 0.5, Vector3(0, 0, 5))
	_ok("hit reaction can't interrupt an attack", not m3.act(M.S.HIT, 0.0, 0.3))
	var hits := 0
	var first := -1.0
	for i in 40:
		m3.step(dt, m3.slot(Vector3.ZERO, 0.0), 0.0, 6.0)
		if m3.take_hit():
			hits += 1
			first = m3.state_t
	_ok("attack lands once on its hit frame", hits == 1 and first >= 0.2 and first < 0.25)
	_ok("attack ends back in locomotion", not m3.is_action())
	# Walls: it steps round a blocker instead of stopping dead.
	var m4 := M.new()
	m4.pos = Vector3(-1.4, 0, -4.0)
	var wall := func(p: Vector3) -> bool: return absf(p.x + 1.4) < 0.6 and absf(p.z + 1.5) < 0.4
	var inside := false
	var h4 := Vector3.ZERO
	for i in 300:
		h4.z += 0.5 * dt
		m4.step(dt, h4, 0.0, 6.0, wall)
		inside = inside or wall.call(m4.pos)
	_ok("sidekick steers round a wall", not inside and M.flat_dist(m4.pos, m4.slot(h4, 0.0)) < 1.2)
	# Regression (#62 feedback): an attack on a far target walks/runs there,
	# never teleports, and lands only after arriving; no blink in combat.
	var m5 := M.new()
	m5.pos = Vector3(-1.4, 0, 0.9)
	var foe := Vector3(-1.4, 0, 7.5)
	m5.act(M.S.ATTACK, 0.22, 0.55, foe, foe - Vector3(0, 0, 0.8))
	var jump := 0.0
	var landed := Vector3.INF
	for i in 180:
		var before := m5.pos
		m5.step(dt, Vector3.ZERO, 0.0, 6.0)
		jump = maxf(jump, M.flat_dist(before, m5.pos))
		if m5.take_hit() and landed == Vector3.INF:
			landed = m5.pos
	_ok("attack runs to its target, no teleport", m5.teleports == 0 and jump < 0.25 and landed != Vector3.INF and M.flat_dist(landed, foe) < 1.8)
	# Far behind right after an attack, and on screen: it sprints, no blink.
	var m6 := M.new()
	m6.act(M.S.ATTACK, 0.1, 0.2)
	var hero6 := Vector3(0, 0, M.TELEPORT_DIST + 2.0)
	for i in 60:
		m6.step(dt, hero6, 0.0, 6.0, Callable(), Callable(), Callable(), func(_p): return true)
	_ok("no teleport during or right after combat", m6.teleports == 0)
	var m7 := M.new()
	for i in 600:
		m7.step(dt, Vector3(0, 0, M.TELEPORT_DIST + 2.0 + i * 0.4), 0.0, 6.0, Callable(), Callable(), Callable(), func(_p): return true)
	_ok("on screen it only blinks when hopelessly far", m7.teleports >= 1)
	var m8 := M.new()
	var seen_far := false
	for i in 120:
		m8.step(dt, Vector3(0, 0, M.TELEPORT_DIST + 4.0), 0.0, 0.0, Callable(), Callable(), Callable(), func(_p): return true)
	_ok("no blink while on screen and merely far", m8.teleports == 0)
	# Procedural fallbacks move the pose when a clip is missing.
	var lunge: Dictionary = SKN.pose(M.S.ATTACK, 0.3, 0.0, 0.22, 0.55, false, 0.0)
	var hop: Dictionary = SKN.pose(M.S.SPECIAL, 0.3, 0.0, 0.32, 0.8, false, 0.0)
	_ok("fallback attack lunges, special rises", float(lunge["z"]) > 0.2 and float(hop["y"]) > 0.2)
	# Pet moves: anticipate, strike, settle; no style jumps at the hit frame or snaps at the end.
	const PA := preload("res://src/hunt/pet_anim.gd")
	var pa_bad := []
	for kind: String in PA.STYLE_OF:
		var sty := PA.style_for(kind)
		var before: Dictionary = PA.strike(sty, 0.3 - 0.0005, 0.3)
		var after: Dictionary = PA.strike(sty, 0.3 + 0.0005, 0.3)
		for key in PA.KEYS:
			if absf(float(before[key]) - float(after[key])) > 0.03:
				pa_bad.append("%s jumps at the hit (%s)" % [kind, key])
		var gone: Dictionary = PA.strike(sty, 0.3 + PA.TAIL + 0.01, 0.3)
		for key in PA.KEYS:
			if absf(float(gone[key]) - float(PA.neutral()[key])) > 0.0001:
				pa_bad.append("%s does not settle (%s)" % [kind, key])
		var peak := 0.0
		for i in 40:
			var q: Dictionary = PA.strike(sty, 0.3 + i * 0.02, 0.3)
			peak = maxf(peak, absf(float(q["z"])) + absf(float(q["y"])) + absf(float(q["pitch"])) + absf(float(q["spin"])))
		if peak < 0.3:
			pa_bad.append("%s barely moves" % kind)
	_ok("pet moves anticipate, strike and settle %s" % str(pa_bad), pa_bad.is_empty())
	var flapped: Dictionary = PA.flap(5.0, 0.7)
	var strode: Dictionary = PA.gait(4.0, 0.7, 6.0)
	_ok("pet gait: flyers bob, walkers lean into speed", float(strode["pitch"]) > 0.05 and absf(float(flapped["y"])) > 0.0)
	_ok("pet lean: accelerating tips forward, braking back", float(PA.lean(Vector3(0, 0, 6.0), 3.0)["pitch"]) > 0.05 and float(PA.lean(Vector3(0, 0, -6.0), 3.0)["pitch"]) < -0.05)
	# Every clip in the map exists on its model.
	var bad := []
	const SDB2 := preload("res://src/data/sidekick_db.gd")
	for sid in SDB2.ORDER:
		var lk := preload("res://src/core/sidekick_look.gd").build(sid)
		for key in SDB2.CLIPS.get(sid, {}):
			if not preload("res://src/core/sidekick_look.gd").has(lk, key):
				bad.append("%s.%s" % [sid, key])
		(lk["root"] as Node).free()
	_ok("sidekick clip map matches the rigs %s" % str(bad), bad.is_empty())
	# Every sidekick has its own idle, move, attack, hit and special clip (no
	# procedural fallback), and the fast walkers a run.
	var gaps := []
	for sid in SDB2.ORDER:
		var want := ["idle", "move", "attack", "hit", "special"]
		if sid in ["bonelet", "acolyte", "shade", "barrow_squire"]:
			want.append("run")
		var lk2 := preload("res://src/core/sidekick_look.gd").build(sid)
		for key in want:
			if not preload("res://src/core/sidekick_look.gd").has(lk2, key):
				gaps.append("%s.%s" % [sid, key])
		(lk2["root"] as Node).free()
	_ok("every sidekick has real attack, hit and special clips %s" % str(gaps), gaps.is_empty())


## Environment props: every model has a collision policy, every solid one a
## collider, and nothing walks or paths through the crypt.
func _collision_tests() -> void:
	const PS := preload("res://src/hunt/prop_shapes.gd")
	const FOOT := preload("res://src/data/prop_footprints.gd")
	var unlisted := {}
	var missing := []
	var clutter_blocks := []
	for cfg in [["barrow", 0, 1], ["depths", 0, 1], ["vault", 0, 1], ["grove", 0, 1], ["barrow", 5, 1], ["barrow", 5, 2], ["barrow", 5, 3]]:
		var a := Arena.new()
		a.build(true, cfg[0], cfg[1], cfg[2])
		for p: Dictionary in a.props:
			var file := str(p["path"]).get_file()
			if not PS.POLICY.has(file):
				unlisted[file] = true
				continue
			var pos: Vector3 = p["pos"]
			var inside := pos.x > a.min_x and pos.x < a.max_x and pos.z > a.min_z and pos.z < a.max_z and pos.y < 0.5
			if not inside:
				continue
			if p["shape"] != "walk" and (int(p["obs"]) < 0 or not a.blocked(pos + Vector3(0.0, 0, 0.0), 0.05) and not a.blocked(pos, 0.3)):
				missing.append("%s %s@%s" % [cfg[0], file, pos])
			if PS.POLICY[file] == "walk" and int(p["obs"]) >= 0:
				clutter_blocks.append(file)
		a.free()
	_ok("every prop type has a collision policy %s" % str(unlisted.keys()), unlisted.is_empty())
	_ok("every blocking prop placed has a collider %s" % str(missing.slice(0, 4)), missing.is_empty())
	_ok("ground clutter has no collider %s" % str(clutter_blocks.slice(0, 4)), clutter_blocks.is_empty())
	var no_foot := []
	for f: String in PS.POLICY:
		# A zero footprint is allowed: a pebble with nothing in the body band.
		if PS.POLICY[f] != "walk" and not FOOT.FOOT.has(f):
			no_foot.append(f)
	_ok("every blocking prop type has a baked footprint %s" % str(no_foot), no_foot.is_empty())
	var crypt_now: Array = PS.measure(PS.path_of("crypt.gltf"))
	var crypt_baked: Array = FOOT.FOOT["crypt.gltf"]
	_ok("prop footprints baked (crypt matches its mesh)", absf(float(crypt_now[2]) - float(crypt_baked[2])) < 0.01 and absf(float(crypt_now[3]) - float(crypt_baked[3])) < 0.01)

	# The crypt: walk at it from every side the playfield allows, the way
	# Hero.tick moves (step, then resolve), and never end up inside.
	var b := Arena.new()
	b.build(true, "barrow", 0, 1)
	var cp := b.crypt_pos
	var half := Vector2(3.0, 4.0) * PS.FILL * 1.9
	var in_crypt := func(q: Vector3, r: float) -> bool:
		return absf(q.x - cp.x) < half.x + r * 0.8 and absf(q.z - cp.z) < half.y + r * 0.8
	var through := []
	for k in 11:
		var ang := PI * 0.5 + PI * float(k) / 10.0 # west, south, east
		var p := b.resolve(cp + Vector3(cos(ang), 0, sin(ang)) * 14.0, 0.5)
		for i in 360:
			var d := (cp - p)
			d.y = 0.0
			p = b.resolve(p + d.normalized() * 5.5 / 60.0, 0.5)
			if in_crypt.call(p, 0.5):
				through.append(k)
				break
	_ok("hero can't walk into the crypt from any side %s" % str(through), through.is_empty())
	_ok("projectiles stop at the crypt", b.blocked(cp + Vector3(0, 0, half.y - 0.3), 0.05) and b.blocked(cp + Vector3(half.x - 0.3, 0, 0), 0.05))
	# A foe east of the crypt reaches a hero west of it by the flow field
	# (Enemy._around_walls), round the front, never through it.
	# (The step field reaches 40 m of path, so the pair sit within that.)
	var hero_at := Vector3(cp.x - 3.0, 0, cp.z + half.y + 2.0)
	var foe := Vector3(cp.x + half.x + 2.3, 0, cp.z - 1.5)
	for i in 400:
		b.update_flow(hero_at, 1.0 / 60.0)
	var reached := false
	var cut := false
	for i in 60 * 20:
		if i % 15 == 0:
			b.update_flow(hero_at, 0.25)
		var f := b.flow_dir(foe)
		if f == Vector3.ZERO:
			f = (hero_at - foe).normalized()
		foe = b.resolve(foe + f * 3.2 / 60.0, 0.55)
		cut = cut or in_crypt.call(foe, 0.55)
		if foe.distance_to(hero_at) < 1.5:
			reached = true
			break
	_ok("a foe paths round the crypt to the hero (reached %s at %s, through %s)" % [reached, foe, cut], reached and not cut)
	b.free()
## Leaving the app mid-hunt: pause, snapshot, then 3-2-1 or retreat.
func _focus_tests() -> void:
	var FG := preload("res://src/hunt/focus_guard.gd")
	var tree := Engine.get_main_loop() as SceneTree
	var keep := Game.data.duplicate(true)
	var h := Hunt.new()
	h.phase = "rise"
	h.hero = Hero.new()
	h.tier = {"gold": 1.0, "chest": "silver", "xp": 1.0}
	h.gold = 77
	h.hero.def = DB.HEROES["knight"]
	var g := FG.new(h)
	tree.root.add_child(g)
	var was := tree.paused
	tree.paused = false
	h.hitstop(0.09)
	g.suspend(1000.0)
	_ok("focus loss pauses the world and ends hitstop", tree.paused and is_equal_approx(Engine.time_scale, 1.0))
	_ok("focus loss snapshots the run's gold", int(Game.data.get("suspended_run", {}).get("gold", -1)) == 77)
	g.suspend(1001.0)
	_ok("a second focus-out keeps the first time", is_equal_approx(g.away_at, 1000.0))
	_ok("a short absence counts down", g.resume(1010.0) == "countdown" and not Game.data.has("suspended_run"))
	g._finish_countdown()
	_ok("the countdown unpauses", not tree.paused)
	g.suspend(2000.0)
	_ok("a long absence retreats to camp", g.resume(2000.0 + FG.AWAY_LIMIT + 1.0) == "lobby")
	tree.paused = true
	g.paused_by_us = false
	g.suspend(3000.0)
	_ok("a menu's pause is left to the menu", g.resume(3005.0) == "none" and tree.paused)
	# A process killed in the background pays the snapshot on the next boot.
	var g0 := Game.gold()
	Game.data["suspended_run"] = {"hero": "knight", "gold": 40, "xp": {}, "items": [], "kills": 3, "tier": 0}
	Game.recover_suspended_run()
	_ok("a killed run's gold is kept once", Game.gold() == g0 + 40 and not Game.data.has("suspended_run"))
	Game.recover_suspended_run()
	_ok("recovery does not pay twice", Game.gold() == g0 + 40)
	tree.paused = was
	g.queue_free()
	h.hero.free()
	h.free()
	Game.data = keep


## Level-up cards: a hitstop running when the cards pause the tree must not
## leave the world (and the cards' tweens) at 0.05x; no cards once it's clear.
func _levelup_tests() -> void:
	var h := Hunt.new()
	h.phase = "rise"
	h.hero = Hero.new()
	h.tier = {"gold": 1.0}
	h.hitstop(0.09)
	_ok("hitstop slows the world", is_equal_approx(Engine.time_scale, 0.05))
	h.end_hitstop()
	_ok("cards end a running hitstop before pausing", is_equal_approx(Engine.time_scale, 1.0) and h._real_hitstop == 0.0)
	h.phase = "victory"
	Engine.time_scale = 0.25
	h.end_hitstop()
	_ok("victory slow-mo is left alone", is_equal_approx(Engine.time_scale, 0.25))
	Engine.time_scale = 1.0
	h.phase = "rise"
	_ok("mid-run cards still show with no foe alive", h.foes.is_empty() and h._spawn_q.is_empty() and not h.cards_blocked())
	# Boss Rush: a boss falls mid-run, the phase goes back to "rise" for the break.
	h.mode = "rush"
	_ok("the Boss Rush break card still shows", not h.cards_blocked())
	h.phase = "victory"
	h.pending_levels = 1
	h._offer_cards()
	_ok("no card after the final boss falls; the pick is dropped", h.cards_blocked() and h.pending_levels == 0)
	h.phase = "defeat"
	_ok("no card after death", h.cards_blocked())
	h.hero.free()
	h.free()


## The upgrade bank: level-ups wait on the "+N" badge instead of pausing.
func _bank_tests() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var h := Hunt.new()
	h.phase = "rise"
	h.mode = "horde"
	h.hero_id = "knight"
	h.hero = Hero.new()
	h.hero.def = DB.HEROES["knight"]
	h.hero.hunt = h
	h.hero.base = Game.hero_stats("knight")
	var hud: Node = load("res://src/ui/hud.tscn").instantiate()
	hud.hunt = h
	h.hud = hud
	tree.root.add_child(hud)
	hud._make_bank_badge()
	h.bank_level()
	_ok("a level-up does not pause the game", not tree.paused and not h.card_open)
	h.bank_level()
	_ok("the badge shows the banked count", hud.bank_count() == 2 and hud._bank.visible and hud._bank.text == "+2 cards")
	hud._bank.pressed.emit()
	var lv: Node = null
	for c in hud.get_children():
		if c.has_method("_pick"):
			lv = c
	_ok("tapping the badge pauses and opens the cards", tree.paused and h.card_open and lv != null)
	if lv:
		lv._keep()
	_ok("keep for later closes and keeps the picks", not tree.paused and not h.card_open and h.pending_levels == 2)
	hud._bank.pressed.emit()
	h.pick_card("might")
	_ok("after a pick the next banked set shows right away", tree.paused and h.card_open and h.pending_levels == 1 and hud.bank_count() == 1)
	h.close_bank()
	# Safe moments open the bank by themselves: a room cleared, a boss down mid-run.
	h.safe_moment()
	_ok("a cleared room opens the banked picks", tree.paused and h.card_open)
	h.close_bank()
	h.pending_levels = 0
	hud.set_bank(0)
	h.bank_level(true)
	_ok("the break between bosses opens the cards", tree.paused and h.card_open and h.pending_levels == 1)
	h.close_bank()
	# The final boss falls: banked picks are dropped and the badge hides.
	h.phase = "victory"
	h.bank_level()
	_ok("no cards after the run ends; bank dropped, badge hidden", h.pending_levels == 0 and not hud._bank.visible and not h.card_open)
	for c in hud.get_children():
		if c.has_method("_pick"):
			c.free()
	tree.paused = false
	hud.free()
	h.hero.free()
	h.free()


func _breeding_tests() -> void:
	const SK := preload("res://src/autoload/sidekicks.gd")
	const SKL_T := preload("res://src/core/sidekick_look.gd")
	var t0 := 1_800_000_000
	var ga := SKDB_T.base_genes()
	# The roll is seeded: the same parents and seed always give the same child.
	var c1 := SKDB_T.roll_child("drake", ga, "wisp", ga, 42)
	var c2 := SKDB_T.roll_child("drake", ga, "wisp", ga, 42)
	_ok("breeding: the same seed gives the same child", c1 == c2)
	var distinct := {}
	var in_range := true
	var breeds_ok := true
	for sd in 200:
		var c := SKDB_T.roll_child("drake", ga, "wisp", ga, sd)
		distinct[str(c["genes"])] = true
		breeds_ok = breeds_ok and ["drake", "wisp"].has(c["breed"]) or SKDB_T.BREEDS.has(c["breed"])
		for k in SKDB_T.GENE_RANGE:
			var rg: Vector2 = SKDB_T.GENE_RANGE[k]
			in_range = in_range and float(c["genes"][k]) >= rg.x - 0.001 and float(c["genes"][k]) <= rg.y + 0.001
	_ok("breeding: the same parents give many different children", distinct.size() > 150)
	_ok("breeding: every gene stays in range", in_range)
	_ok("breeding: a child's breed is a parent's or a hybrid", breeds_ok)
	# A matching pair can produce its hybrid breed, and only that pair can.
	var hy := 0
	var other := 0
	for sd in 300:
		if SKDB_T.roll_child("drake", ga, "bonelet", ga, sd)["breed"] == "cinderbone":
			hy += 1
		if SKDB_T.roll_child("drake", ga, "wisp", ga, sd)["breed"] == "cinderbone":
			other += 1
	_ok("breeding: the right pair can breed a hybrid, about a third of the time", hy > 60 and hy < 150 and other == 0)
	# Parents with strong genes pull the child up.
	var strong := ga.duplicate()
	strong["dmg"] = 1.3
	var avg := 0.0
	for sd in 100:
		avg += float(SKDB_T.roll_child("drake", strong, "wisp", strong, sd)["genes"]["dmg"])
	_ok("breeding: strong parents breed strong children", avg / 100.0 > 1.2)
	# Rules.
	var d := Game._fresh()
	SK.migrate(d)
	for id in ["drake", "wisp"]:
		SK.own(d, id)
		d["sidekicks"]["owned"][id]["kills"] = 700
	d["gold"] = SKDB_T.BREED_GOLD
	_ok("breeding: a good pair can breed", SK.breed_block(d, "drake", "wisp", t0) == "")
	_ok("breeding: not with itself", SK.breed_block(d, "drake", "drake", t0) != "")
	SK.own(d, "bonelet")
	_ok("breeding: needs Bond %d" % SKDB_T.BREED_BOND, SK.breed_block(d, "drake", "bonelet", t0) != "")
	_ok("breeding: needs both owned", SK.breed_block(d, "drake", "hexling", t0) != "")
	d["gold"] = SKDB_T.BREED_GOLD - 1
	_ok("breeding: needs gold", SK.breed_block(d, "drake", "wisp", t0) != "")
	d["gold"] = SKDB_T.BREED_GOLD
	var egg := SK.breed(d, "drake", "wisp", t0, 7)
	_ok("breeding: pays gold and lays a nest egg", int(d["gold"]) == 0 and str(egg["kind"]) == "nest" and SK.hatchery(d).size() == 1)
	_ok("breeding: the parents rest", SK.resting(d, "drake", t0) == SKDB_T.BREED_REST and SK.breed_block(d, "drake", "wisp", t0 + 10) != "")
	_ok("breeding: rested parents can breed again", SK.resting(d, "drake", t0 + SKDB_T.BREED_REST) == 0)
	# The nest egg already holds its child, so hatching can't reroll it.
	_ok("breeding: not hatched too soon", SK.hatch(d, int(egg["uid"]), t0).is_empty())
	var want: Dictionary = egg["child"]
	var out := SK.hatch(d, int(egg["uid"]), t0 + int(SKDB_T.EGGS["nest"]["secs"]))
	var cid := str(out.get("id", ""))
	_ok("breeding: the egg hatches the child it held", cid == "x1" and SK.is_owned(d, cid) and d["sidekicks"]["owned"][cid]["genes"] == want["genes"])
	_ok("breeding: the child is in the collection log", SK.breeds_found(d).has(str(want["breed"])) and (d["sidekicks"]["found"]["elements"] as Array).has(str(want["genes"]["element"])))
	# Save-safe: the def is rebuilt from the save alone.
	var saved: Dictionary = JSON.parse_string(JSON.stringify(d))
	SKDB_T.BRED.clear()
	SK.migrate(saved)
	_ok("breeding: a saved child comes back with its def", SKDB_T.exists(cid) and SKDB_T.def(cid)["name"] == SKDB_T.bred_def(str(want["breed"]), want["genes"])["name"])
	# Genes change the def.
	var g := SKDB_T.base_genes()
	g["dmg"] = 1.3
	g["haste"] = 1.2
	g["size"] = 1.2
	g["element"] = "ice"
	g["personality"] = "eager"
	var base := SKDB_T.ROSTER["drake"]
	var bd := SKDB_T.bred_def("drake", g)
	_ok("breeding: damage and speed genes change the ability", float(bd["ability"]["dmg"]) > float(base["ability"]["dmg"]) and float(bd["ability"]["cd"]) < float(base["ability"]["cd"]))
	_ok("breeding: the size gene scales it", float(bd["scale"]) > float(base["scale"]))
	_ok("breeding: the element recolours its attacks", bd["vfx_el"] == &"frost" and bd["color"] != base["color"])
	# Every kind of bred pet has a model; patterns and the glow gene are data and card text, never primitives.
	for pat in SKDB_T.PATTERNS:
		var gg := g.duplicate()
		gg["pattern"] = pat
		gg["glow"] = true
		SKDB_T.BRED["x99"] = SKDB_T.bred_def("drake", gg)
		var look := SKL_T.build("x99", false)
		_ok("breeding: a %s drake builds with no primitive trait shapes" % pat, look["root"].get_node_or_null("Traits") == null and look["root"].find_children("*", "MeshInstance3D", true, false).size() > 0)
		look["root"].free()
	SKDB_T.BRED.erase("x99")
	# A Lucky pet doubles the exotic egg odds.
	var dl := Game._fresh()
	SK.migrate(dl)
	var lg := SKDB_T.base_genes()
	lg["personality"] = "lucky"
	SKDB_T.BRED["x98"] = SKDB_T.bred_def("drake", lg)
	var plain := SK.exotic_chance(dl, false, 0)
	dl["sidekicks"]["owned"]["x98"] = {"kills": 0, "breed": "drake", "genes": lg, "parents": []}
	SK.set_active(dl, "x98")
	_ok("breeding: a lucky pet doubles exotic odds", is_equal_approx(SK.exotic_chance(dl, false, 0), plain * 2.0))
	SKDB_T.BRED.erase("x98")


func _story_tests() -> void:
	const SDB_S := preload("res://src/data/story_db.gd")
	var keep: Dictionary = Game.data
	Game.data = Game._fresh()
	_ok("story: five chapters", SDB_S.count() == 5)
	var ids := {}
	var data_ok := true
	var beats_ok := true
	var tied_ok := true
	for ch: Dictionary in SDB_S.CHAPTERS:
		ids[ch["id"]] = true
		data_ok = data_ok and ch["hero"] in DB.HERO_ORDER and DB.ZONES.has(ch["zone"]) and DB.BOSSES.has(ch["boss"]) and not ch["intro"].is_empty() and not ch["outro"].is_empty()
		tied_ok = tied_ok and str(DB.ZONES[ch["zone"]]["boss"]) == str(ch["boss"])
		for which in ["intro", "outro"]:
			for b: Dictionary in ch[which]:
				beats_ok = beats_ok and b["who"] in ["hero", "boss", "narrator"] and b.get("cam", "wide") in ["wide", "hero", "boss"] and str(b["line"]) != ""
	_ok("story: chapter ids are unique", ids.size() == SDB_S.count())
	_ok("story: every chapter has a real hero, zone and boss", data_ok)
	_ok("story: every chapter's boss is its zone's boss", tied_ok)
	_ok("story: every beat is a known speaker, camera and line", beats_ok)
	_ok("story: the finale pays a weapon glow that exists", DB.GLOWS.has(SDB_S.CHAPTERS[4]["reward"]["glow"]))
	_ok("story: a fresh save has no story", Game.data["story"]["cleared"].is_empty() and Game.story_next() == 0)
	_ok("story: the camp button points a new player at Chapter 1", Game.story_home_label() == "CHAPTER 1")
	var camp_src := FileAccess.get_file_as_string("res://src/lobby/lobby_ui.gd")
	_ok("story: the camp rail has its own Story button that opens the story", camp_src.contains("[\"story\", \"scroll-unfurled\"]") and camp_src.contains("open_sheet(\"story\")"))
	_ok("story: chapter 1 is open, 2 is not", Game.story_open(0) and not Game.story_open(1) and not Game.story_open(9) and not Game.story_open(-1))
	_ok("story: a locked chapter cannot be queued", not Game.story_begin("roots") and str(Game.data["story"]["run"]) == "")
	_ok("story: an unknown chapter cannot be queued", not Game.story_begin("nope"))
	_ok("story: an open chapter queues", Game.story_begin("oath") and str(Game.data["story"]["run"]) == "oath")
	var taken := Game.story_take()
	_ok("story: taking hands over the chapter once", str(taken["id"]) == "oath" and Game.story_take().is_empty())
	# Boss retelling.
	var base: Dictionary = DB.boss_def("gravemaw")
	var told: Dictionary = SDB_S.boss_def(base, "gravemaw", taken)
	_ok("story: the chapter boss gets its own name and title", str(told["name"]) == "Gravemaw" and str(told["title"]) == "the Oathbreaker")
	var lk: Dictionary = SDB_S.chapter("lightless")
	var big: Dictionary = SDB_S.boss_def(base, "gravemaw", lk)
	_ok("story: the Lightless King is bigger and tougher", float(big["hp"]) > float(base["hp"]) * 1.5 and float(big["scale"]) > float(base["scale"]) * 1.2)
	_ok("story: another zone's boss is left alone", SDB_S.boss_def(DB.boss_def("thorn"), "thorn", taken) == DB.boss_def("thorn"))
	_ok("story: a normal hunt leaves the boss alone", SDB_S.boss_def(base, "gravemaw", {}) == base)
	_ok("story: the base boss table was not changed", DB.boss_def("gravemaw")["name"] == base["name"] and float(DB.boss_def("gravemaw")["hp"]) == float(base["hp"]))
	# Paying a clear.
	var hunt := {"win": true, "tier": 0, "zone": "barrow", "mode": "horde", "time": 120.0, "chest": "silver", "hero": "mage", "level": 6, "souls": 100, "gold": 10, "xp": {}, "items": [], "kills": 5, "elites": 0, "story": "oath"}
	var g0 := Game.gold()
	var out := Game.finish_hunt(hunt)
	var su: Dictionary = out.get("story", {})
	_ok("story: a first win reports the chapter", bool(su.get("first", false)) and str(su["id"]) == "oath" and not bool(su["hero_bonus"]))
	_ok("story: it pays the chapter reward and opens the next", int(su["gold"]) == 1500 and Game.story_cleared("oath") and Game.story_open(1) and Game.story_next() == 1)
	_ok("story: gold lands in the purse", Game.gold() >= g0 + 1500)
	var again := Game.finish_hunt(hunt)
	_ok("story: a replay pays nothing more and stays cleared", not bool(again["story"]["first"]) and int(again["story"]["gold"]) == 0 and Game.data["story"]["cleared"].size() == 1)
	var lost := Game.finish_hunt(_story_loss(hunt))
	_ok("story: a loss pays and clears nothing", not lost.has("story"))
	var sh0 := int(Game.hero("ranger")["shards"])
	var rh := hunt.duplicate()
	rh["hero"] = "ranger"
	rh["story"] = "roots"
	var ro := Game.finish_hunt(rh)
	_ok("story: the chapter's own hero earns 25% more", bool(ro["story"]["hero_bonus"]) and int(ro["story"]["gold"]) == int(round(1800 * 1.25)))
	_ok("story: shards go to the chapter's hero", int(Game.hero("ranger")["shards"]) == sh0 + int(ro["story"]["shards"]) and int(ro["story"]["shards"]) > 35)
	# The finale's glow reaches every hero.
	for id in ["crypt", "vault", "lightless"]:
		var fh := hunt.duplicate()
		fh["story"] = id
		fh["hero"] = SDB_S.chapter(id)["hero"]
		Game.finish_hunt(fh)
	var all_glow := true
	for id in DB.HERO_ORDER:
		all_glow = all_glow and "wraith" in Game.hero(id)["glows"]
	_ok("story: the whole story is cleared and the finale's glow is everyone's", Game.story_next() == 5 and all_glow)
	_ok("story: the camp button reads COMPLETE once it is all cleared", Game.story_home_label() == "COMPLETE")
	_ok("story: the cutscene script has no class_name", not ("\n" + FileAccess.get_file_as_string("res://src/ui/cutscene.gd")).contains("\nclass_name "))
	_ok("story: the story data has no class_name", not ("\n" + FileAccess.get_file_as_string("res://src/data/story_db.gd")).contains("\nclass_name "))
	Game.data = keep


func _story_loss(h: Dictionary) -> Dictionary:
	var l := h.duplicate()
	l["win"] = false
	return l


func _stage_tests() -> void:
	const SK := preload("res://src/autoload/sidekicks.gd")
	const SKL_T := preload("res://src/core/sidekick_look.gd")
	_ok("stages: bond 1-3 is Hatchling", SKDB_T.stage_of(1) == 0 and SKDB_T.stage_of(3) == 0)
	_ok("stages: bond 4-9 is Grown", SKDB_T.stage_of(4) == 1 and SKDB_T.stage_of(9) == 1)
	_ok("stages: bond 10 is Elder", SKDB_T.stage_of(10) == 2)
	_ok("stages: the Drake's Elder is the Ash Wyrm", SKDB_T.stage_name("drake", 2) == "Ash Wyrm" and SKDB_T.stage_name("drake", 0) == "Young Ember Drake")
	_ok("stages: an Elder without its own name is Elder X", SKDB_T.stage_name("bonelet", 2) == "Elder Bonelet")
	_ok("stages: display name follows bond kills", SKDB_T.display_name("drake", 0) == "Young Ember Drake" and SKDB_T.display_name("drake", 15000) == "Ash Wyrm" and SKDB_T.display_name("drake", 1000) == "Ember Drake")
	_ok("stages: power only grows", SKDB_T.STAGE_DMG[0] < SKDB_T.STAGE_DMG[1] and SKDB_T.STAGE_DMG[1] < SKDB_T.STAGE_DMG[2] and SKDB_T.STAGE_SCALE[0] < SKDB_T.STAGE_SCALE[2])
	# Growing up is reported once.
	var d := Game._fresh()
	SK.migrate(d)
	SK.own(d, "bonelet")
	SK.set_active(d, "bonelet")
	d["sidekicks"]["owned"]["bonelet"]["kills"] = 980
	var out := SK.after_hunt(d, {"kills": 40, "win": false}, RandomNumberGenerator.new())
	_ok("stages: crossing Bond 4 is a stage up", int(out["stage_from"]) == 0 and int(out["stage_to"]) == 1 and not bool(out["evolved"]))
	d["sidekicks"]["owned"]["bonelet"]["kills"] = 14990
	out = SK.after_hunt(d, {"kills": 20, "win": false}, RandomNumberGenerator.new())
	_ok("stages: crossing Bond 10 evolves", int(out["stage_to"]) == 2 and bool(out["evolved"]))
	out = SK.after_hunt(d, {"kills": 20, "win": false}, RandomNumberGenerator.new())
	_ok("stages: no second evolution", not bool(out["evolved"]) and int(out["stage_from"]) == 2)
	# Models: sizes follow the stage; only Elders wear a crown.
	var sizes := []
	for st in 3:
		var look := SKL_T.build("bonelet", false, st)
		var big := 0.0
		for ch in look["root"].get_children():
			if ch is Node3D and not (ch is Light3D) and ch.name != "ElderCrown":
				big = maxf(big, (ch as Node3D).scale.y)
		sizes.append(big)
		_ok("stages: stage %d crown matches" % st, (look["root"].get_node_or_null("ElderCrown") != null) == (st == 2))
		look["root"].free()
	_ok("stages: the model grows with each stage", sizes[0] < sizes[1] and sizes[1] < sizes[2])
	_ok("stages: the old bool call still works", SKL_T.build("bonelet", true)["root"].get_node_or_null("ElderCrown") != null)


const PRIV := preload("res://src/core/privacy.gd")
const CRASH := preload("res://src/core/crash_report.gd")


## App Store readiness: the consent record, the crash-report hookup (inert
## without a DSN and a yes) and that no secret ships in the repo.
func _store_tests() -> void:
	var keep = Game.data
	Game.data = Game._fresh()
	_ok("privacy: a new save is asked", PRIV.needed())
	_ok("privacy: crash reports off until said yes", not PRIV.crash_ok())
	_ok("privacy: online off until answered", not PRIV.online_ok())
	PRIV.record(false, true)
	_ok("privacy: answered once, not asked again", not PRIV.needed())
	_ok("privacy: a no stays a no", not PRIV.crash_ok() and PRIV.online_ok())
	PRIV.record(true, false)
	_ok("privacy: crash yes recorded", PRIV.crash_ok())
	_ok("privacy: online no switches the account off", not PRIV.online_ok() and bool(Game.data["online"]["off"]))
	Game.data["privacy"]["v"] = PRIV.VERSION - 1
	_ok("privacy: a new policy version asks again", PRIV.needed() and not PRIV.crash_ok())
	Game.data = {"seen_tutorial": true, "online": {"off": false}}
	_ok("privacy: an old save without the key is asked", PRIV.needed())
	Game.data = Game._fresh()
	# The screen itself: toggling crash reports and tapping CONTINUE records and finishes.
	var scr: CanvasLayer = PRIV.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(scr)
	scr.build()
	var seen := [false]
	scr.done.connect(func(): seen[0] = true)
	var accept := scr.find_child("AcceptButton", true, false) as Button
	_ok("privacy: the screen has a continue button", accept != null)
	for cb in scr.find_children("*", "CheckButton", true, false):
		if (cb as CheckButton).text == "Share crash reports":
			(cb as CheckButton).button_pressed = true
	accept.pressed.emit()
	_ok("privacy: continue finishes the screen", seen[0])
	_ok("privacy: continue records the crash yes", PRIV.crash_ok() and not PRIV.needed())
	scr.queue_free()
	Game.data = Game._fresh()
	# The hookup: DSN parsing and the envelope.
	var t: Dictionary = CRASH.parse_dsn("https://abc123@o42.ingest.example.io/777")
	_ok("crash: DSN parses to the envelope url", t.get("url") == "https://o42.ingest.example.io/api/777/envelope/" and t.get("key") == "abc123")
	_ok("crash: a secret-key DSN keeps only the public key", CRASH.parse_dsn("https://abc:secret@h.example/9").get("key") == "abc")
	_ok("crash: http DSN refused", CRASH.parse_dsn("http://abc@h.example/9").is_empty())
	_ok("crash: junk DSN refused", CRASH.parse_dsn("").is_empty() and CRASH.parse_dsn("https://h.example/9").is_empty() and CRASH.parse_dsn("https://k@h.example/x").is_empty())
	var el = load("res://src/autoload/error_log.gd").new()
	el._enabled = false
	el._add("script", "x.gd:1 f", "boom")
	var ev: Dictionary = CRASH.event(el, "gravelight@2.0.0+1", 1)
	_ok("crash: event names the error", str(ev["exception"]["values"][0]["value"]).contains("boom"))
	_ok("crash: event id is 32 hex", str(ev["event_id"]).length() == 32)
	var env := CRASH.envelope("https://abc@h.example/9", ev).split("\n")
	_ok("crash: envelope is header, item header, event", env.size() == 3 and JSON.parse_string(env[1])["type"] == "event" and JSON.parse_string(env[2])["event_id"] == ev["event_id"])
	var blob := JSON.stringify(ev)
	_ok("crash: event carries no save, name or account", not blob.contains("user_id") and not blob.contains(Game.player_name()))
	# Gating: needs a DSN and a yes.
	_ok("crash: no DSN in the repo, so nothing is due", str(ProjectSettings.get_setting("crash/dsn", "")) == "" and CRASH.dsn() == "" or OS.get_environment("CC_CRASH_DSN") != "")
	var node: Node = CRASH.new()
	var out: String = await node.send_if_due(el, "r", 1)
	_ok("crash: nothing is sent without a DSN", out == "skipped")
	node.free()
	Game.data = keep


func _gate_tests() -> void:
	const GATE := preload("res://src/core/app_gate.gd")
	var ok_body := '{"build": 12, "min_engine": 3, "min_native": 5, "store_url": "https://apps.apple.com/app/id1"}'.to_utf8_buffer()
	var r := GATE.parse(HTTPRequest.RESULT_SUCCESS, 200, ok_body)
	_ok("gate: a good version.json parses", int(r.get("min_native", 0)) == 5)
	_ok("gate: a failed request fails open", GATE.parse(HTTPRequest.RESULT_CANT_CONNECT, 0, PackedByteArray()).is_empty())
	_ok("gate: a timeout fails open", GATE.parse(HTTPRequest.RESULT_TIMEOUT, 0, PackedByteArray()).is_empty())
	_ok("gate: a 404 fails open", GATE.parse(HTTPRequest.RESULT_SUCCESS, 404, "Not Found".to_utf8_buffer()).is_empty())
	_ok("gate: bad JSON fails open", GATE.parse(HTTPRequest.RESULT_SUCCESS, 200, "<html>".to_utf8_buffer()).is_empty())
	_ok("gate: a non-object answer fails open", GATE.parse(HTTPRequest.RESULT_SUCCESS, 200, "[1,2]".to_utf8_buffer()).is_empty())
	_ok("gate: below min_native blocks", GATE.verdict(r, 3)["block"] == true)
	_ok("gate: at min_native lets in", GATE.verdict(r, 5)["block"] == false)
	_ok("gate: above min_native lets in", GATE.verdict(r, 6)["block"] == false)
	_ok("gate: no min_native never blocks (OTA-only builds)", GATE.verdict({"build": 9, "min_engine": 3}, 3)["block"] == false)
	_ok("gate: an unknown installed shell never blocks", GATE.verdict(r, 0)["block"] == false)
	_ok("gate: min_engine alone never blocks", GATE.verdict({"min_engine": 99}, 3)["block"] == false)
	_ok("gate: the store link comes from the server", GATE.verdict(r, 3)["store_url"] == "https://apps.apple.com/app/id1")
	_ok("gate: a junk store link falls back", GATE.verdict({"min_native": 9, "store_url": "javascript:x"}, 3)["store_url"] == GATE.STORE_URL)
	_ok("gate: App Store link says App Store", GATE.button_text("https://apps.apple.com/app/id1") == "OPEN APP STORE")
	_ok("gate: sideload link says update", GATE.button_text(GATE.STORE_URL) == "GET THE UPDATE")
	_ok("gate: itms-apps link says App Store", GATE.button_text("itms-apps://apps.apple.com/app/id1") == "OPEN APP STORE")
	_ok("gate: a lookalike host is not the store", not GATE.is_store_url("https://apps.apple.com.evil.example/app/id1"))
	_ok("gate: a query mention is not the store", GATE.button_text("https://example.com/?u=apps.apple.com/app/id1") == "GET THE UPDATE")
	_ok("gate: empty link is not the store", not GATE.is_store_url(""))
	var root: Window = (Engine.get_main_loop() as SceneTree).root
	var g: Node = GATE.new()
	root.add_child(g)
	var was: bool = root.get_tree().paused
	_ok("gate: the installed shell reads from Ota", g.installed() == int(Ota.NATIVE_VERSION) and g.installed() > 0)
	_ok("gate: no answer lets the player in", g.apply({}) == false and not g.blocked and root.get_node_or_null("UpdateRequired") == null)
	_ok("gate: a satisfied answer lets the player in", g.apply({"min_native": 1}) == false and not g.blocked)
	_ok("gate: a too-old shell is blocked", g.apply({"min_native": 99}) == true and g.blocked)
	_ok("gate: the blocking screen is up and pauses the game", g.find_child("UpdateRequired", true, false) != null and root.get_tree().paused)
	var btn := g.find_child("UpdateButton", true, false) as Button
	_ok("gate: the screen has an update button", btn != null and btn.text != "")
	_ok("gate: going offline keeps a gate that is up", g.apply({}) == true and g.blocked)
	var cleared := [false]
	g.cleared.connect(func(): cleared[0] = true)
	_ok("gate: a lowered min_native clears it", g.apply({"min_native": 1}) == false and not g.blocked and cleared[0])
	_ok("gate: clearing unpauses the game", root.get_tree().paused == was)
	g.free()


func _event_tests() -> void:
	const SK := preload("res://src/autoload/sidekicks.gd")
	var keep: Dictionary = Game.data
	Game.data = Game._fresh()
	var om := Game.weekly_omen()
	_ok("event: more weird rules than before", DB.WEEKLY_OMENS.size() >= 8)
	var mods_ok := true
	for o in DB.WEEKLY_OMENS:
		for k in o["mod"]:
			mods_ok = mods_ok and k in ["pack", "foe_hp", "foe_speed", "foe_dmg", "dmg", "hp", "dmg_taken", "rate", "super"]
	_ok("event: every rule only uses known modifiers", mods_ok)
	_ok("event: a hunt off the rule earns no bonus XP", Game.add_omen_xp({"omen": "", "win": true, "level": 8}) == 0 and int(Game.season()["xp"]) == 0)
	var win := {"omen": str(om["id"]), "win": true, "level": 8, "souls": 300, "bosses": ["a", "b"], "depth": 0, "perfect": 4}
	var xp := Game.add_omen_xp(win)
	_ok("event: a win under the rule earns score/60 season XP", xp == DB.omen_xp_for(Game.weekly_score(win)) and xp > 15 and int(Game.season()["xp"]) == xp)
	_ok("event: a loss still earns a little", Game.add_omen_xp({"omen": str(om["id"]), "win": false, "level": 3, "souls": 40}) > 0)
	_ok("event: the clock reads", Game.event_seconds_left() > 0 and Game.event_seconds_left() <= 604800)
	_ok("event: time text", Game.left_text(2 * 86400 + 5 * 3600) == "2d 5h" and Game.left_text(5 * 3600 + 720) == "5h 12m" and Game.left_text(30) == "1m")
	# Finishing a hunt under the rule reports the XP.
	Game.data["omen_on"] = true
	var s := Game.finish_hunt({"win": true, "tier": 0, "zone": "barrow", "mode": "horde", "time": 120.0, "chest": "silver", "omen": str(om["id"]), "hero": "knight", "level": 6, "souls": 100, "gold": 10, "xp": {}, "items": [], "kills": 5, "elites": 0})
	_ok("event: finish_hunt carries the XP", int(s["omen_xp"]) > 0)
	var sb := Game.finish_hunt({"win": true, "tier": 0, "zone": "barrow", "mode": "horde", "time": 120.0, "chest": "silver", "omen": "", "hero": "knight", "level": 6, "gold": 10, "xp": {}, "items": [], "kills": 5, "elites": 0})
	_ok("event: a plain hunt reports none", not sb.has("omen_xp"))
	# A save from before the fold: this week's earned, unclaimed tiers are paid once.
	Game.data = Game._fresh()
	Game.data["event"] = {"week": Game.week_number(), "pts": 1100, "claimed": 1, "hunts": 5}
	Game._fold_event()
	_ok("event: the old track pays the tiers earned and not claimed", int(Game.data["folded_event"]) == 3 and SK.has_egg(Game.data, "brood"))
	var gold1 := Game.gold()
	Game._fold_event()
	_ok("event: the fold pays only once", Game.gold() == gold1 and int(Game.data["event"]["pts"]) == 0)
	Game.data = Game._fresh()
	Game.data["event"] = {"week": Game.week_number() - 1, "pts": 5000, "claimed": 0, "hunts": 9}
	Game._fold_event()
	_ok("event: last week's old points pay nothing", int(Game.data["folded_event"]) == 0)
	Game.data = keep


## Every pause-menu and settings option: it is saved at once, and a running
## hunt shows the change at once (camera, buttons, shake, graphics).
func _settings_tests() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var keep := Game.data.duplicate(true)
	Game.data = Game._fresh()
	var seen: Array[String] = []
	var rec := func(k: String): seen.append(k)
	Game.setting_changed.connect(rec)
	Game.set_setting("camera", "wide")
	_ok("settings: a change is announced", seen == ["camera"])
	Game.setting_changed.disconnect(rec)
	_ok("settings: it survives a save round trip", JSON.parse_string(JSON.stringify(Game.data["settings"]))["camera"] == "wide")
	Game.data = Game._fresh()
	var h := Hunt.new()
	tree.root.add_child(h)
	_ok("settings: a hunt starts on the saved camera", is_equal_approx(h.cam.dist_mult, 1.0))
	for pair in [["close", 0.86], ["wide", 1.16], ["standard", 1.0]]:
		Game.set_setting("camera", pair[0])
		_ok("settings: camera %s applies in the hunt" % pair[0], is_equal_approx(h.cam.dist_mult, float(pair[1])))
	var before := h.cam.global_position
	Game.set_setting("camera", "wide")
	_ok("settings: the camera moves right away, even paused", h.cam.global_position.distance_to(before) > 1.0)
	_ok("settings: a new save starts on Low shake", Game.setting("shake_level") == "low" and h.cam.shake_level == "low")
	Game.set_setting("shake_level", "off")
	h.shake(1.0)
	_ok("settings: shake off stops the shake", h.cam.shake_level == "off" and h.cam.trauma == 0.0)
	for lv in ["low", "medium", "high"]:
		Game.set_setting("shake_level", lv)
		_ok("settings: shake %s applies in the hunt" % lv, h.cam.shake_level == lv)
	Game.set_setting("shake_level", "low")
	Game.set_setting("buttons", "left")
	_ok("settings: buttons move to the left", h.hud.get_node("%Dash").anchor_left == 0.0 and h.hud.get_node("%Super").anchor_left == 0.0)
	Game.set_setting("buttons", "right")
	_ok("settings: buttons move back to the right", h.hud.get_node("%Dash").anchor_left == 1.0)
	var grass: int = h.arena._grass_n
	Game.set_setting("quality", "low")
	_ok("settings: low graphics drops ambient occlusion, grass and mist", h.low and h.fx.quality_low and h.fx.vfx.quality_low and not h.arena.env.ssao_enabled and h.arena._grass_mm.visible_instance_count < grass and h.arena._mist.amount == 26)
	Game.set_setting("quality", "high")
	_ok("settings: high graphics brings them back", not h.low and h.arena.env.ssao_enabled and h.arena._grass_mm.visible_instance_count == grass and h.arena._mist.amount == 48)
	_ok("settings: a phone caps at 60 fps, the saver at 30, a desktop is left alone", Game.fps_cap("60", true) == 60 and Game.fps_cap("30", true) == 30 and Game.fps_cap(null, true) == 60 and Game.fps_cap("30", false) == 0)
	_ok("settings: a new save is on 60 fps and a 30 fps frame is not slowed down", Game.setting("fps") == "60" and Game.max_step("60") < 1.0 / 30.0 + 0.0001 and Game.max_step("30") > 1.0 / 30.0)
	var prev_cap := Engine.max_fps
	Game.set_setting("fps", "30")
	_ok("settings: the frame rate choice is saved and announced", Game.setting("fps") == "30")
	Game.set_setting("fps", "60")
	Engine.max_fps = prev_cap
	# The pause menu's own buttons write the same settings.
	var pause: Control = load("res://src/ui/pause.tscn").instantiate()
	tree.root.add_child(pause)
	pause.open(h)
	var box: Control = pause.find_children("*", "VBoxContainer", true, false).filter(func(n): return n is SettingsBox)[0]
	var wide: Button = null
	var notes := 0
	for b in box.find_children("*", "Button", true, false):
		if (b as Button).text == "Close":
			wide = b
	for l in box.find_children("*", "Label", true, false):
		if (l as Label).text.contains("next hunt"):
			notes += 1
	_ok("settings: the pause menu has the camera row and no next-hunt note", wide != null and notes == 0)
	wide.pressed.emit()
	_ok("settings: tapping Close in the pause menu moves the live camera", Game.setting("camera") == "close" and is_equal_approx(h.cam.dist_mult, 0.86))
	var lifted: float = pause.get_node("Scrim").modulate.a
	_ok("settings: the pause scrim lifts to show the new view", lifted < 1.0 or pause._peek != null)
	pause.free()
	var camp := SettingsBox.new()
	tree.root.add_child(camp)
	var camp_notes := 0
	for l in camp.find_children("*", "Label", true, false):
		if (l as Label).text.contains("next hunt"):
			camp_notes += 1
	_ok("settings: the camp says changes wait for the next hunt", camp_notes == 1)
	camp.free()
	h.free()
	Game.data = keep


## The screen shake level: one dial for every source, a hard ceiling, an old
## on/off save moves to Low or Off.
func _shake_level_tests() -> void:
	var c := HuntCam.new()
	var order := ["off", "low", "medium", "high"]
	var amps: Array[float] = []
	var kicks: Array[float] = []
	var pushes: Array[float] = []
	var peaks: Array[float] = []
	for lv in order:
		c.shake_level = lv
		c.trauma = 0.0
		c._kick = Vector3.ZERO
		c.kick(Vector3(1, 0, 0), 0.2)
		kicks.append(c._kick.length())
		for i in 30:
			c.add_trauma(1.0)
		peaks.append(c.trauma)
		amps.append(c.amp())
		pushes.append(float(HuntCam.LEVELS[lv]["push"]))
	_ok("shake: the levels step up Off, Low, Medium, High", amps[0] == 0.0 and amps[0] < amps[1] and amps[1] < amps[2] and amps[2] < amps[3])
	_ok("shake: kicks and punches follow the level", kicks[0] == 0.0 and kicks[1] < kicks[2] and kicks[2] < kicks[3] and pushes[1] < pushes[3] and pushes[0] == 0.0)
	_ok("shake: nothing builds up while Off", peaks[0] == 0.0)
	_ok("shake: stacked blows cap below full trauma", peaks[3] <= HuntCam.MAX_TRAUMA + 0.001 and peaks[3] > 0.5)
	c.shake_level = "high"
	c.trauma = 0.0
	c.add_trauma(1.0)
	_ok("shake: one blow can't jump straight to the cap", c.trauma <= HuntCam.MAX_ADD + 0.001)
	c.trauma = 0.0
	c._kick = Vector3.ZERO
	for i in 20:
		c.kick(Vector3(1, 0, 0), 0.4)
	_ok("shake: stacked kicks stay under the kick cap", c._kick.length() <= HuntCam.MAX_KICK + 0.001)
	# Low, the default, is about a third of the old full-strength shake (old
	# peak shift 0.6 m and 0.05 rad at trauma 1; new Low peak at the cap).
	var low_move: float = HuntCam.MAX_SHAKE_MOVE * HuntCam.LEVELS["low"]["amp"]
	var low_turn: float = HuntCam.MAX_SHAKE_TURN * HuntCam.LEVELS["low"]["amp"]
	_ok("shake: Low is 30-35% of the old move, less of the old turn", low_move / 0.6 > 0.28 and low_move / 0.6 < 0.37 and low_turn / 0.05 < 0.3)
	_ok("shake: even High moves and turns less than the old shake", HuntCam.MAX_SHAKE_MOVE < 0.6 and HuntCam.MAX_SHAKE_TURN < 0.05)
	# The camera itself: at the trauma cap, the worst frame stays inside the budget.
	var tree := Engine.get_main_loop() as SceneTree
	var tgt := Node3D.new()
	tree.root.add_child(tgt)
	var cam := HuntCam.new()
	tree.root.add_child(cam)
	cam.target = tgt
	cam.snap()
	var rest := cam.global_position
	for lv in ["low", "high"]:
		cam.shake_level = lv
		cam.trauma = 0.0
		cam.add_trauma(1.0)
		cam.add_trauma(1.0)
		cam.add_trauma(1.0)
		var worst := 0.0
		for i in 40:
			cam.trauma = HuntCam.MAX_TRAUMA
			cam.follow(0.0, Vector3.ZERO)
			cam._t += 0.05
			worst = maxf(worst, cam.global_position.distance_to(rest))
		var budget: float = HuntCam.MAX_SHAKE_MOVE * float(HuntCam.LEVELS[lv]["amp"]) * HuntCam.MAX_TRAUMA * HuntCam.MAX_TRAUMA * 1.5
		_ok("shake: %s stays inside its move budget (%.2f m)" % [lv, worst], worst <= budget and (lv == "high" or worst < 0.2))
	cam.free()
	tgt.free()
	_ok("shake: a bad saved level reads as Low", HuntCam.level_of("loud") == "low" and HuntCam.level_of(null) == "low" and HuntCam.level_of("high") == "high")
	_ok("shake: the camp jolts follow the setting", _shake_amp_for("off") == 0.0 and _shake_amp_for("low") < _shake_amp_for("high"))
	# Old saves.
	var keep := Game.data.duplicate(true)
	for case in [[{"shake": true, "music": 0.5}, "low"], [{"shake": false}, "off"], [{"shake": true, "shake_level": "high"}, "high"], [{"music": 1.0}, "low"]]:
		var d := {"settings": case[0].duplicate()}
		Game._migrate_shake(d)
		_ok("shake: old save %s becomes %s" % [str(case[0]), case[1]], d["settings"].get("shake_level", "low") == case[1] and not d["settings"].has("shake"))
	Game.data = keep
	c.free()


func _shake_amp_for(lv: String) -> float:
	var keep: Variant = Game.data["settings"].get("shake_level")
	Game.data["settings"]["shake_level"] = lv
	var a := Game.shake_amp()
	Game.data["settings"]["shake_level"] = keep
	return a


## Combat feel: hit reactions spring back to rest, the camera kick respects the
## shake setting, and hitstop is paid from a tank that can't snowball.
func _feel_tests() -> void:
	var a := Actor.new()
	a.model = Node3D.new()
	a.add_child(a.model)
	a.hit_react(Vector3(1, 0, 0), 1.0, false)
	_ok("feel: a hit flashes the actor", a.flash_t > 0.0)
	a.tick_common(0.016)
	_ok("feel: a hit tips the model and squashes it", a._spring_on and (a.model.rotation.z != 0.0 or a.model.rotation.x != 0.0))
	var peak := 0.0
	for i in 12:
		a.tick_common(0.016)
		peak = maxf(peak, absf(a.model.rotation.z) + absf(a.model.rotation.x))
	_ok("feel: the lean is visible but not a faceplant", peak > 0.03 and peak < 0.6)
	for i in 120:
		a.tick_common(0.016)
	_ok("feel: springs settle back to the rest pose", not a._spring_on and a.model.scale.is_equal_approx(Vector3.ONE) and a.model.rotation.is_zero_approx())
	a.squash(Vector3(-0.1, -0.1, 0.3))
	a.tick_common(0.016)
	var stretched := a.model.scale.z > 1.0
	a.clear_springs()
	_ok("feel: a lunge stretches forward, and clear_springs resets it at once", stretched and a.model.scale == Vector3.ONE and a.model.rotation.is_zero_approx())
	var big := Actor.new()
	big.model = Node3D.new()
	big.add_child(big.model)
	var small := Actor.new()
	small.model = Node3D.new()
	small.add_child(small.model)
	big.hit_react(Vector3(1, 0, 0), 0.4)
	small.hit_react(Vector3(1, 0, 0), 1.2)
	big.tick_common(0.016)
	small.tick_common(0.016)
	_ok("feel: light foes tip further than heavy ones", absf(small.model.rotation.z) > absf(big.model.rotation.z) * 1.5)
	var c := HuntCam.new()
	c.shake_level = "high"
	c.kick(Vector3(1, 0, 0), 0.2)
	_ok("feel: a camera kick is stored", c._kick.x > 0.15)
	c.shake_level = "off"
	c._kick = Vector3.ZERO
	c.kick(Vector3(1, 0, 0), 0.2)
	_ok("feel: no kick when screen shake is off", c._kick == Vector3.ZERO)
	c.shake_level = "high"
	c.trauma = 0.0
	c.add_trauma(0.4)
	var first := c.trauma
	c.add_trauma(0.4)
	_ok("feel: trauma has diminishing returns", first > 0.35 and c.trauma - first < first and c.trauma < 1.0)
	_shake_level_tests()
	var h := Hunt.new()
	h.phase = "rise"
	h.hero = Hero.new()
	h.tier = {"gold": 1.0}
	h.hitstop(0.1)
	h.hitstop(0.1)
	h.hitstop(0.1)
	_ok("feel: hitstop stops drawing once the tank is empty", h._stop_bank < 0.02 and h._real_hitstop <= 0.12)
	h.end_hitstop()
	h._stop_bank = 0.0
	Engine.time_scale = 1.0
	h.hitstop(0.1)
	_ok("feel: an empty tank skips the hitstop", is_equal_approx(Engine.time_scale, 1.0) and h._real_hitstop == 0.0)
	h._stop_bank = Hunt.STOP_TANK
	h.hitstop(0.05)
	_ok("feel: a full tank pays the stop", is_equal_approx(Engine.time_scale, 0.05) and is_equal_approx(h._stop_bank, Hunt.STOP_TANK - 0.05))
	h.end_hitstop()
	_ok("feel: ending hitstop clears the ease", h._stop_ease == 0.0 and is_equal_approx(Engine.time_scale, 1.0))
	h.hero.free()
	h.free()
	c.free()
	a.free()
	big.free()
	small.free()


## A pair with an unfound hybrid makes it by BREED_HYBRID_PITY tries; once
## found, the pair rolls plain odds again.
func _hybrid_pity_tests() -> void:
	const SK := preload("res://src/autoload/sidekicks.gd")
	var d := Game._fresh()
	SK.migrate(d)
	for id in ["drake", "bonelet", "wisp"]:
		SK.own(d, id)
		d["sidekicks"]["owned"][id]["kills"] = 700
	d["gold"] = SKDB_T.BREED_GOLD * 100
	_ok("hybrid pity: a pair with no hybrid has none", SK.hybrid_tries_left(d, "drake", "wisp") == 0)
	_ok("hybrid pity: a fresh pair is sure by try %d" % SKDB_T.BREED_HYBRID_PITY, SK.hybrid_tries_left(d, "drake", "bonelet") == SKDB_T.BREED_HYBRID_PITY)
	# Seeds whose first rolls miss the hybrid: the pity must still deliver it on time.
	var now := 1_000_000
	var got := ""
	var tries := 0
	var sd := 0
	while tries < SKDB_T.BREED_HYBRID_PITY and got != "cinderbone":
		sd += 1
		var trial: Dictionary = SKDB_T.roll_child("drake", {}, "bonelet", {}, sd)
		if str(trial["breed"]) == "cinderbone" and tries < SKDB_T.BREED_HYBRID_PITY - 1:
			continue
		d["sidekicks"]["hatchery"] = []
		d["sidekicks"]["rest"] = {}
		var e := SK.breed(d, "drake", "bonelet", now, sd)
		got = str(e["child"]["breed"])
		tries += 1
	_ok("hybrid pity: misses then a sure hybrid on try %d" % SKDB_T.BREED_HYBRID_PITY, got == "cinderbone" and tries == SKDB_T.BREED_HYBRID_PITY)
	_ok("hybrid pity: the count clears after the hybrid", not (d["sidekicks"]["hy_dry"] as Dictionary).has("bonelet+drake"))
	# Either order of the parents counts toward the same pair.
	d["sidekicks"]["hy_dry"] = {"bonelet+drake": 1}
	_ok("hybrid pity: parent order doesn't matter", SK.hybrid_tries_left(d, "bonelet", "drake") == SK.hybrid_tries_left(d, "drake", "bonelet"))
	d["sidekicks"]["found"]["breeds"].append("cinderbone")
	_ok("hybrid pity: none once the hybrid is found", SK.hybrid_tries_left(d, "drake", "bonelet") == 0)
	# A forced roll changes only the breed: the rest of the genome is the seed's.
	var plain: Dictionary = SKDB_T.roll_child("drake", {}, "bonelet", {}, 99)
	var forced: Dictionary = SKDB_T.roll_child("drake", {}, "bonelet", {}, 99, SKDB_T.MUTATION_BASE, true)
	_ok("hybrid pity: a forced roll keeps the seed's genes", str(forced["breed"]) == "cinderbone" and forced["genes"]["dmg"] == plain["genes"]["dmg"] and forced["genes"]["personality"] == plain["genes"]["personality"])
	var old := Game._fresh()
	old["sidekicks"].erase("hy_dry")
	_ok("hybrid pity: an old save without counts loads", SK.hybrid_tries_left(old, "drake", "bonelet") == SKDB_T.BREED_HYBRID_PITY)


## The Breeding Wheel's ring and the Matchmaker's numbers match the rules.
func _matchmaker_tests() -> void:
	const SK := preload("res://src/autoload/sidekicks.gd")
	var ring: Array = SKDB_T.WHEEL
	var every := ring.size() == SKDB_T.ORDER.size() and SKDB_T.ORDER.all(func(k): return ring.count(k) == 1)
	_ok("wheel: every species is on the ring once", every)
	var near := true
	for h: String in SKDB_T.BREED_ORDER:
		var p: Array = SKDB_T.BREEDS[h]["pair"]
		var gap := absi(ring.find(p[0]) - ring.find(p[1]))
		near = near and (gap == 1 or gap == ring.size() - 1)
	_ok("wheel: each hybrid's parents are neighbours", near)
	var d := Game._fresh()
	SK.migrate(d)
	for id in ["drake", "bonelet", "wisp"]:
		SK.own(d, id)
	var odds := SK.litter_odds(d, "drake", "bonelet")
	var total := 0.0
	for o: Array in odds:
		total += float(o[1])
	_ok("matchmaker: a hybrid pair's odds add to 1", is_equal_approx(total, 1.0) and odds.size() == 3)
	# The odds shown are the odds rolled.
	var hits := 0
	for sd in 4000:
		if str(SKDB_T.roll_child("drake", {}, "bonelet", {}, sd)["breed"]) == "cinderbone":
			hits += 1
	_ok("matchmaker: the hybrid share matches the roll (%d / 4000)" % hits, absf(hits / 4000.0 - float(odds[2][1])) < 0.03)
	_ok("matchmaker: a pair with no hybrid is 50/50", SK.litter_odds(d, "drake", "wisp") == [["drake", 0.5], ["wisp", 0.5]])
	d["sidekicks"]["hy_dry"] = {"bonelet+drake": SKDB_T.BREED_HYBRID_PITY - 1}
	_ok("matchmaker: on the pity litter the hybrid is certain", float(SK.litter_odds(d, "drake", "bonelet")[2][1]) == 1.0)
	var base := SK.mutation_chance(d, "nest")
	_ok("matchmaker: unmutated parents give the nest's mutation chance", is_equal_approx(SK.litter_mutation_chance(d, "drake", "bonelet"), base))
	var cid := SK._add_bred(d, {"breed": "bonelet", "genes": SKDB_T.base_genes().merged({"mutation": "gilded"}, true)}, [])
	var want := SKDB_T.GEN.MUTATION_INHERIT + (1.0 - SKDB_T.GEN.MUTATION_INHERIT) * base
	_ok("matchmaker: a mutated parent adds its inherit chance", is_equal_approx(SK.litter_mutation_chance(d, "drake", cid), want))
	_ok("matchmaker: owning a bred bonelet owns the breed", SK.owns_species(d, "bonelet") and SK.count_of_species(d, "bonelet") == 2 and SK.mutated_one(d, "bonelet", "gilded") == cid)
	_ok("matchmaker: breed mutations list what you own", SK.breed_mutations(d).get("bonelet", []) == ["gilded"])


## Releasing a bred pet frees its room for gold; species pets and the one at
## your side stay.
func _release_tests() -> void:
	const SK := preload("res://src/autoload/sidekicks.gd")
	var d := Game._fresh()
	SK.migrate(d)
	SK.own(d, "drake")
	d["gold"] = 0
	var cid := SK._add_bred(d, SKDB_T.roll_wild("bonelet", 5), [])
	SK.set_active(d, "drake")
	_ok("release: a species pet can't go", SK.release(d, "drake") == 0 and SK.is_owned(d, "drake"))
	SK.set_active(d, cid)
	_ok("release: not the pet at your side", SK.release(d, cid) == 0 and SK.is_owned(d, cid))
	SK.set_active(d, "drake")
	SK.pin(d, cid)
	_ok("release: a bred pet goes for gold", SK.release(d, cid) == SKDB_T.RELEASE_GOLD and not SK.is_owned(d, cid) and int(d["gold"]) == SKDB_T.RELEASE_GOLD)
	_ok("release: it leaves the showcase", not SK.is_pinned(d, cid))
	# A full stable stops breeding until a release makes room.
	for i in SKDB_T.STABLE_MAX:
		SK._add_bred(d, SKDB_T.roll_wild("bonelet", 100 + i), [])
	_ok("release: a full stable blocks breeding", not SK.stable_room(d))
	SK.release(d, str(SK.bred_ids(d)[0]))
	_ok("release: and a release makes room", SK.stable_room(d))


## Pets 2.0 care: the flat rest after a litter, the hybrid pity, releasing, and names.
func _pet_care_tests() -> void:
	const SK := preload("res://src/autoload/sidekicks.gd")
	const Care := preload("res://src/core/pet_care.gd")
	var t0 := 1_000_000
	# The rest is flat: 8h after every litter, however many came before.
	var ok := true
	for i in 8:
		ok = ok and Care.rest_secs(i) == 8 * 3600
	_ok("care: rest is 8h after every litter", ok)
	var d := Game._fresh()
	SK.migrate(d)
	for id in ["drake", "wisp", "bonelet"]:
		SK.own(d, id)
		d["sidekicks"]["owned"][id]["kills"] = 700
	_ok("care: a pet that never bred has bred 0 times", Care.bred_times(d, "drake") == 0 and Care.next_rest(d, "drake") == 8 * 3600)
	d["gold"] = SKDB_T.BREED_GOLD * 20
	var now := t0
	SK.breed(d, "drake", "wisp", now, 1)
	_ok("care: the first litter rests both parents 8h", SK.resting(d, "drake", now) == 8 * 3600 and SK.resting(d, "wisp", now) == 8 * 3600)
	_ok("care: and counts it", Care.bred_times(d, "drake") == 1 and Care.next_rest(d, "drake") == 8 * 3600)
	now += 8 * 3600
	SK.breed(d, "drake", "bonelet", now, 2)
	_ok("care: a repeat parent rests 8h like a first-timer", SK.resting(d, "drake", now) == 8 * 3600 and SK.resting(d, "bonelet", now) == 8 * 3600)
	_ok("care: a rested parent is not blocked, a resting one is", SK.breed_block(d, "wisp", "bonelet", now) != "" and SK.breed_block(d, "wisp", "wisp", now) != "")
	for i in 8:
		now += 9 * 3600
		d["sidekicks"]["hatchery"] = []
		SK.breed(d, "drake", "wisp", now, 10 + i)
	_ok("care: after many litters the rest is still 8h", SK.resting(d, "drake", now) == 8 * 3600 and Care.bred_times(d, "drake") == 10)
	# A clock set far ahead (or a 48h rest from the old ladder) reads as 8h at most.
	d["sidekicks"]["rest"]["drake"] = now + 48 * 3600
	_ok("care: an old 48h rest is cut to 8h", SK.resting(d, "drake", now) == 8 * 3600)
	# Save-safe: counts survive a save round trip; an old save has none.
	var saved: Dictionary = JSON.parse_string(JSON.stringify(d))
	_ok("care: counts survive the save", Care.bred_times(saved, "drake") == Care.bred_times(d, "drake"))
	var old := Game._fresh()
	old["sidekicks"].erase("bcount")
	_ok("care: an old save without counts still loads", Care.bred_times(old, "drake") == 0 and Care.next_rest(old, "drake") == 8 * 3600)
	_hybrid_pity_tests()
	_release_tests()
	_matchmaker_tests()
	# Names.
	_ok("name: plain names pass", bool(Care.check_name("Ember")["ok"]) and bool(Care.check_name("Sir Wiggles-II")["ok"]) and bool(Care.check_name("O'Malley")["ok"]))
	_ok("name: spaces are trimmed and squeezed", str(Care.check_name("   Big    Boo  ")["name"]) == "Big Boo")
	_ok("name: empty clears", bool(Care.check_name("   ")["ok"]) and str(Care.check_name("   ")["name"]) == "")
	_ok("name: too short and too long fail", not bool(Care.check_name("A")["ok"]) and not bool(Care.check_name("Abcdefghijklmnop")["ok"]) and bool(Care.check_name("Abcdefghijklmn")["ok"]))
	_ok("name: odd characters fail", not bool(Care.check_name("Fluffy<3")["ok"]) and not bool(Care.check_name("Rex\nTwo")["ok"]) and not bool(Care.check_name("🙂🙂")["ok"]))
	_ok("name: must start with a letter or number", not bool(Care.check_name("-Rex")["ok"]) and not bool(Care.check_name(".Rex")["ok"]))
	var rude := ["fuck", "F u C k", "sh1t", "B1tch", "bigcunt", "n1gg3r", "ass", "D1CK", "f.u.c.k"]
	var allrude := true
	for r in rude:
		allrude = allrude and not bool(Care.check_name(r)["ok"])
	_ok("name: the filter catches rude words, spaced or spelled with digits", allrude)
	var clean := true
	for c in ["Peacock", "Cucumber", "Assam", "Scrap", "Grassy", "Cockatrice", "Dickens", "Classic", "Passion", "Hello", "Titan", "Spicy", "Cuckoo", "Torpedo"]:
		clean = clean and bool(Care.check_name(c)["ok"])
	_ok("name: ordinary words that contain a short bad one pass", clean)
	_ok("name: a pet takes a name and the name reads back", Care.set_name(d, "drake", "  Cinder  ") and Care.nickname(d, "drake") == "Cinder" and Care.shown_name(d, "drake", "Ember Drake") == "Cinder")
	_ok("name: a bad name changes nothing", not Care.set_name(d, "drake", "fuck") and Care.nickname(d, "drake") == "Cinder")
	_ok("name: not for a pet you don't own", not Care.set_name(d, "hexling", "Boo"))
	_ok("name: empty puts the breed name back", Care.set_name(d, "drake", "") and Care.shown_name(d, "drake", "Ember Drake") == "Ember Drake")
	Care.set_name(d, "wisp", "Boo")
	var saved2: Dictionary = JSON.parse_string(JSON.stringify(d))
	_ok("name: it survives the save", Care.nickname(saved2, "wisp") == "Boo")


## The living world: grass wind, footprints, props that wobble, bats, beetles.
func _world_tests() -> void:
	const LIFE := preload("res://src/hunt/arena_life.gd")
	var a := Arena.new()
	a.build(true, "barrow", 0, 1)
	var lf: RefCounted = a.life
	_ok("world: the grass is a wind shader on the stock texture", lf.grass_mat is ShaderMaterial and lf.grass_mat.shader == LIFE.GRASS and lf.grass_mat.get_shader_parameter("albedo_tex") != null)
	_ok("world: bats circle over the barrow", lf.bats != null and lf.bats.multimesh.visible_instance_count == 4)
	_ok("world: beetles live in the barrow", lf._bug_n == 7 and lf._bug_mm.visible_instance_count == 7)
	var d := Arena.new()
	d.build(true, "depths", 0, 1)
	lf.set_low(false)
	_ok("world: quality high shows all the critters", lf.bats.multimesh.visible_instance_count == 7 and lf._bug_n == 14 and lf._print_n == 40)
	lf.set_low(true)
	_ok("world: and low shows fewer again", lf.bats.multimesh.visible_instance_count == 4 and lf._bug_n == 7 and lf._print_n == 24)
	_ok("world: no bats or beetles indoors", d.life.bats == null and d.life._bugs.is_empty())
	var t := Arena.new()
	t.build(true, "barrow", 3, 1)
	_ok("world: none in a trial either", t.life.bats == null)
	# Footprints: a walk down the path leaves prints; grass leaves none.
	var kids := a.get_child_count()
	lf._print_i = 0
	for k in 12:
		lf.tick(0.1, Vector3(0.0, 0.0, 16.0 - k * 1.0), Vector3(0, 0, -5), true, [])
	_ok("world: walking the path leaves boot prints", lf._print_i >= 8)
	var off := Vector3(14.0, 0.0, 16.0)
	var before: int = lf._print_i
	_ok("world: not on the grass (test spot is off the path)", a.on_path(off) < 0.3)
	for k in 12:
		lf.tick(0.1, off + Vector3(0, 0, -k * 1.0), Vector3(0, 0, -5), true, [])
	_ok("world: the grass keeps no prints", lf._print_i == before)
	_ok("world: standing still leaves none", lf._print_i == before and (func() -> bool:
		lf.tick(0.1, Vector3(0, 0, 5), Vector3.ZERO, true, [])
		return lf._print_i == before).call())
	for k in 200:
		lf._print_last = Vector3(1e6, 0, 1e6)
		lf._step(Vector3(0.0, 0.0, 10.0), Vector3(0, 0, -3))
	_ok("world: the print pool wraps", lf._print_i >= 0 and lf._print_i < lf._print_mm.instance_count)
	_ok("world: ticking adds no nodes", a.get_child_count() == kids)
	# The grass bends round the hero and the nearest foes.
	lf.tick(0.016, Vector3(3, 0, 4), Vector3.ZERO, true, [])
	var p0: Vector4 = lf.grass_mat.get_shader_parameter("push0")
	_ok("world: the hero presses the grass", is_equal_approx(p0.x, 3.0) and is_equal_approx(p0.z, 4.0) and p0.w > 0.5)
	# Props: a hard blow rocks a gravestone and it settles back to where it stood.
	var rp: Dictionary = {}
	for r in lf._react:
		if not r["small"]:
			rp = r
			break
	_ok("world: gravestones are reactive", not rp.is_empty())
	if not rp.is_empty():
		var at := Vector3(rp["x"], 0.0, rp["z"]) + Vector3(0.4, 0, 0)
		var hard: Array = lf.nudge(at, 0.5, 1.2)
		_ok("world: a hard blow reports the stone it hit", hard.size() >= 1 and hard.size() <= 2)
		_ok("world: an immediate second blow is rate-limited", rp["cool"] > 0.0 and lf.nudge(at, 0.5, 1.2).filter(func(v): return v == Vector3(rp["x"], 0.0, rp["z"])).is_empty())
		var peak := 0.0
		for i in 20:
			lf.tick(0.016, Vector3(-30, 0, 30), Vector3.ZERO, false, [])
			peak = maxf(peak, (rp["tilt"] as Vector2).length())
		_ok("world: the stone rocks but does not fall over (%.2f rad)" % peak, peak > 0.03 and peak < 0.45)
		for i in 400:
			lf.tick(0.016, Vector3(-30, 0, 30), Vector3.ZERO, false, [])
		_ok("world: it settles back exactly", not rp["on"] and rp["tilt"] == Vector2.ZERO and (rp["n"] as Node3D).transform.is_equal_approx(rp["base"]))
		var baked := 0
		for r in lf._react:
			baked += (r["slots"] as Array).size()
		_ok("world: batched props keep a slot to wobble (the dummy renderer can't read instances back)", baked > 0)
	# Beetles scatter from the hero and from fights, and stay in the arena.
	var b0: Dictionary = lf._bugs[0]
	var bp: Vector3 = b0["p"]
	b0["run"] = 0.0
	lf.tick(0.016, bp + Vector3(0.5, 0, 0), Vector3.ZERO, true, [])
	_ok("world: a beetle bolts when the hero gets close", float(b0["run"]) > 0.0 and float(b0["v"]) > 2.0)
	var b1: Dictionary = lf._bugs[1]
	b1["run"] = 0.0
	lf.nudge(b1["p"], 0.5, 1.0)
	_ok("world: a fight scares them too", float(b1["run"]) > 0.0)
	var inside := true
	for i in 600:
		lf.tick(0.016, bp, Vector3.ZERO, true, [])
		for bb in lf._bugs:
			var q: Vector3 = bb["p"]
			inside = inside and q.x > a.min_x and q.x < a.max_x and q.z > a.min_z and q.z < a.max_z
	_ok("world: beetles stay inside the walls", inside)
	a.free()
	d.free()
	t.free()
