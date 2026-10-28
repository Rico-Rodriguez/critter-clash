extends RefCounted
## A simulated week of play for three kinds of player, through the real
## Game.finish_hunt and the real track claims. It guards the shape of the
## economy (nobody finishes the season in a week, a casual player still gets
## something from every track, a grinder is rewarded but capped), not exact
## numbers: those move with DB tuning. Run `-- --test` and read the ECONOMY lines.

## A tier-0 win as the autopilot plays one (see check.sh's bot lines).
const WIN := {"win": true, "tier": 0, "zone": "barrow", "mode": "horde", "time": 200.0, "chest": "silver", "hero": "knight",
	"level": 9, "souls": 150, "gold": 500, "xp": {}, "items": [], "kills": 165, "elites": 1, "bosses": ["gravemaw"], "depth": 0, "perfect": 0}
const LOSS := {"win": false, "tier": 0, "zone": "barrow", "mode": "horde", "time": 120.0, "chest": "wood", "hero": "knight",
	"level": 6, "souls": 60, "gold": 150, "xp": {}, "items": [], "kills": 80, "elites": 0, "bosses": [], "depth": 0, "perfect": 0}

## [name, hunts per day, share of them that win, share of them under the weekly rule]
const PLAYERS := [["casual", 2, 0.5, 0.5], ["regular", 5, 0.7, 0.6], ["grinder", 15, 0.8, 0.8]]


static func run(ok: Callable) -> void:
	var keep: Dictionary = Game.data
	var out := {}
	for p in PLAYERS:
		out[p[0]] = _week(p)
		var r: Dictionary = out[p[0]]
		print("ECONOMY %-8s gold=%d gems=%d shards=%d renown=%d season_tiers=%d event_tiers=%d chests=%d" % [p[0], r["gold"], r["gems"], r["shards"], r["renown"], r["season"], r["event"], r["chests"]])
	Game.data = keep
	var c: Dictionary = out["casual"]
	var g: Dictionary = out["grinder"]
	# A hunt result lists boss ids; this used to throw in int() and skip the weekly score.
	ok.call("economy: the weekly score takes the hunt's boss list", Game.weekly_score({"win": true, "bosses": ["gravemaw", "hexer"]}) == Game.weekly_score({"win": true, "bosses": 2}))
	ok.call("economy: even a casual week earns gold, renown and a season tier", c["gold"] > 0 and c["renown"] > 0 and c["season"] >= 1)
	ok.call("economy: a casual week does not finish the weekly event", c["event"] < DB.EVENT_TRACK.size())
	ok.call("economy: a grinder out-earns a casual player", g["gold"] > c["gold"] and g["renown"] > c["renown"])
	ok.call("economy: nobody finishes a six-week season in one week", g["season"] < DB.SEASON_TIERS)
	# Gold per hunt must not balloon with volume: 7.5x the hunts pays under 9x the gold.
	ok.call("economy: gold scales with hunts, not faster", g["gold"] < c["gold"] * 9)


## Plays seven days, claims every tier the week earned, and returns what the save gained.
static func _week(p: Array) -> Dictionary:
	Game.data = Game._fresh()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var om := str(Game.weekly_omen()["id"])
	var gold0 := Game.gold()
	var gems0 := int(Game.data.get("gems", 0))
	var shards0 := int(Game.hero("knight")["shards"])
	var renown0 := Game.renown()
	var chests := 0
	for day in 7:
		Game.data["daily"] = Game._fresh()["daily"]  # a new day: the first win pays again
		for i in int(p[1]):
			var r: Dictionary = (WIN if rng.randf() < float(p[2]) else LOSS).duplicate(true)
			if rng.randf() < float(p[3]):
				r["omen"] = om
			Game.finish_hunt(r)
			chests += 1
	var tiers := {"season": Game.season_level(), "event": Game.event_level()}
	while Game.season_claimable() > 0:
		Game.claim_season()
	while Game.event_claimable() > 0:
		Game.claim_event()
	return {"gold": Game.gold() - gold0, "gems": int(Game.data.get("gems", 0)) - gems0, "shards": int(Game.hero("knight")["shards"]) - shards0,
		"renown": Game.renown() - renown0, "season": tiers["season"], "event": tiers["event"], "chests": chests}
