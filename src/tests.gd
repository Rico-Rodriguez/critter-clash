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
	_ok("xp level 2", DB.xp_for_level(2) == 83)
	_ok("xp level 99", DB.xp_for_level(99) == 13034431)
	_ok("level for xp", DB.level_for_xp(DB.xp_for_level(40)) == 40 and DB.level_for_xp(DB.xp_for_level(40) - 1) == 39)
	_ok("fresh combat level", Game.combat_level() == 3)

	var base: float = Game.hero_stats("knight")["hp"]
	Game.hero("knight")["level"] = 2
	var up: float = Game.hero_stats("knight")["hp"]
	Game.hero("knight")["level"] = 1
	_ok("hero level scales", absf(up / base - (1.0 + DB.LEVEL_POWER)) < 0.001)

	var common_boss := 0
	for i in 2000:
		if Game.roll_rarity("boss") == "common":
			common_boss += 1
	_ok("boss never drops common", common_boss == 0)

	var gold_before := Game.gold()
	var got := Game.open_chest("silver")
	_ok("chest pays gold", Game.gold() > gold_before and got.size() >= 3)

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
	Game.data["tier_unlocked"] = 2
	_ok("depths opens after veteran", Game.zone_unlocked("depths"))
	for z in DB.ZONES:
		_ok("zone %s boss exists" % z, DB.BOSSES.has(DB.ZONES[z]["boss"]))
	for u in DB.LOG_ORDER:
		_ok("unique %s defined" % u, DB.UNIQUES.has(u))
	_gear_tests()
	return _fails


func _gear_tests() -> void:
	Game.data = Game._fresh()
	# Every part a gear stage names exists in its KayKit file, every weapon model loads.
	var missing := []
	var scenes := {}
	for cls in GearDB.LINES:
		for slot in DB.SLOTS:
			for st: Dictionary in GearDB.LINES[cls][slot]:
				for spec: String in GearDB.expand(st.get("parts", [])):
					var src := spec.get_slice("/", 0)
					if not scenes.has(src):
						scenes[src] = load(KK.CHAR_DIR + src + ".glb").instantiate()
					if (scenes[src] as Node).find_child(GearDB.mesh_name(spec), true, false) == null:
						missing.append(spec)
				if st.has("model") and not ResourceLoader.exists(KK.WEAPON_DIR + str(st["model"])):
					missing.append(st["model"])
	for n: Node in scenes.values():
		n.free()
	_ok("gear parts exist %s" % str(missing), missing.is_empty())
	var it := Game.make_item("mage", "chest", 3, "rare")
	_ok("item is class gear", it["cls"] == "mage" and it["mat"] == 3 and str(it["name"]).ends_with("Mystic Robe Top"))
	Game.grant_item(it)
	_ok("wrong class blocked", Game.wear_block("knight", it) != "")
	_ok("low skill blocked", Game.wear_block("mage", it).begins_with("Requires Magic"))
	Game.data["skills"]["magic"] = DB.xp_for_level(40)
	_ok("skill lets you wear", Game.wear_block("mage", it) == "")
	Game.equip("mage", int(it["uid"]))
	_ok("equipped", Game.equipped("mage", "chest")["uid"] == it["uid"])
	Game.equip("knight", int(it["uid"]))
	_ok("knight cannot take it", Game.owner_of(int(it["uid"])) == "mage")
	# Old saves: v2 items become class gear and keep their wearer.
	var old := {"version": 2, "heroes": {"knight": {"gear": {"weapon": 5}}}, "items": [{"uid": 5, "slot": "weapon", "rarity": "rare", "name": "Old Brand", "stats": {"dmg": 9}, "unique": "", "tier": 1}, {"uid": 6, "slot": "chest", "rarity": "legendary", "name": "Shroud of the Barrow", "stats": {}, "unique": "shroud", "tier": 0}]}
	Game._migrate_v2(old)
	_ok("migrated to wearer", old["items"][0]["cls"] == "knight" and old["items"][0]["mat"] >= 2 and old["version"] == Game.SAVE_VERSION)
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
