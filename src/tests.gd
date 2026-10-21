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
	return _fails


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
