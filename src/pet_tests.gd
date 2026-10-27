extends RefCounted
## Pets 2.0 data checks, called from tests.gd: where eggs come from (Trophy
## Road, chests, season, events, story, the egg shop), then breeds, variants,
## hybrids' parts and mutations.

const SK := preload("res://src/autoload/sidekicks.gd")
const SDB := preload("res://src/data/sidekick_db.gd")
const EggShop := preload("res://src/autoload/egg_shop.gd")
const STORY := preload("res://src/data/story_db.gd")

const T0 := 1_800_000_000


static func run(ok: Callable) -> void:
	_sources(ok)
	_shop(ok)


static func _sources(ok: Callable) -> void:
	var keep := Game.data.duplicate(true)
	# Every egg reward names a real egg.
	var named := true
	var road_eggs := 0
	for i in DB.TROPHY_ROAD.size() + 30:
		var rw := DB.road_reward(i + 1)
		if str(rw["kind"]) == "egg":
			road_eggs += 1
			named = named and SDB.EGGS.has(str(rw["egg"]))
	ok.call("egg sources: the Trophy Road has eggs, all real", road_eggs >= 8 and named)
	ok.call("egg sources: the road keeps its length and its gates", DB.TROPHY_ROAD.size() == 35 and DB.road_gate("grove") == 2500 and DB.road_gate("vault") == 7500)
	var past := DB.TROPHY_ROAD.size()
	ok.call("egg sources: past the road, a season egg every fourth step and an exotic every twelfth", str(DB.road_reward(past + 4)["egg"]) == "season" and str(DB.road_reward(past + 12)["egg"]) == "exotic" and str(DB.road_reward(past + 1)["kind"]) == "chest")
	ok.call("egg sources: a road egg has a name", Game.road_reward_text(5 + 1) != "" and Game.road_reward_text(6) == "Brood Egg")
	# Claiming a road egg lays it; a full hatchery pays gems.
	Game.data = Game._fresh()
	Game.data["road"] = 5
	Game.data["renown"] = 700
	var lines := Game.claim_road()
	ok.call("egg sources: claiming the road egg warms it in the hatchery", SK.has_egg(Game.data, "brood") and int(Game.data["road"]) == 6 and lines.size() == 1 and str(lines[0]).contains("hatchery"))
	Game.data = Game._fresh()
	for i in SDB.HATCH_SLOTS:
		SK.give_egg(Game.data, "brood", T0, i)
	Game.data["road"] = 5
	Game.data["renown"] = 700
	Game.claim_road()
	ok.call("egg sources: a full hatchery pays the road egg as gems", SK.hatchery(Game.data).size() == SDB.HATCH_SLOTS and SK.gems(Game.data) == SDB.FULL_EGG_GEMS)
	# Chests hold eggs of their own grade.
	var cr := RandomNumberGenerator.new()
	cr.seed = 5
	var seen := {}
	var d := Game._fresh()
	for i in 400:
		d["sidekicks"]["hatchery"] = []
		for x in SK.chest_extras(d, "crypt", T0, cr):
			if str(x["type"]) == "egg":
				seen[str(x["egg"])] = true
	ok.call("egg sources: a Crypt chest can hold a Season or a Brood Egg", seen.has("season") and seen.has("brood"))
	var silver := false
	for i in 400:
		d["sidekicks"]["hatchery"] = []
		for x in SK.chest_extras(d, "silver", T0, cr):
			silver = silver or str(x["type"]) == "egg"
	ok.call("egg sources: a Silver chest rarely holds a Brood Egg", silver)
	# The season pass, weekly event and the story.
	var season_eggs := []
	for n in range(1, DB.SEASON_TIERS + 1):
		var rw := DB.season_reward(n)
		if str(rw["kind"]) == "egg":
			season_eggs.append(str(rw["egg"]))
	ok.call("egg sources: the season pass holds five eggs, one exotic, and ends on the glow", season_eggs.size() == 5 and season_eggs.count("exotic") == 1 and DB.season_reward(30)["kind"] == "glow")
	var ev_eggs := []
	for n in range(1, DB.EVENT_TRACK.size() + 1):
		if str(DB.event_reward(n)["kind"]) == "egg":
			ev_eggs.append(str(DB.event_reward(n)["egg"]))
	ok.call("egg sources: the weekly event pays a brood, a season and an omen egg", ev_eggs == ["brood", "season", "omen"] and DB.event_reward(10)["kind"] == "chest")
	Game.data = Game._fresh()
	Game.event()["pts"] = 99999
	for i in 4:
		Game.claim_event()
	ok.call("egg sources: event tier 4 lays an egg", SK.has_egg(Game.data, "brood"))
	var story_ok := true
	for i in STORY.count():
		story_ok = story_ok and SDB.EGGS.has(str(STORY.CHAPTERS[i]["reward"].get("egg", "")))
	ok.call("egg sources: every story chapter pays an egg", story_ok and str(STORY.CHAPTERS[STORY.count() - 1]["reward"]["egg"]) == "exotic")
	Game.data = Game._fresh()
	var first := Game.story_clear({"story": "oath", "hero": "mage"})
	ok.call("egg sources: the first clear lays the chapter's egg", str(first["egg"]) == "brood" and SK.has_egg(Game.data, "brood") and int(first["egg_gems"]) == 0)
	var again := Game.story_clear({"story": "oath", "hero": "mage"})
	ok.call("egg sources: a replay pays no second egg", SK.hatchery(Game.data).size() == 1 and str(again["egg"]) == "")
	Game.data = Game._fresh()
	for i in SDB.HATCH_SLOTS:
		SK.give_egg(Game.data, "brood", T0, i)
	var full := Game.story_clear({"story": "oath", "hero": "mage"})
	ok.call("egg sources: a full hatchery turns the story egg into gems", int(full["egg_gems"]) == SDB.FULL_EGG_GEMS and SK.gems(Game.data) >= SDB.FULL_EGG_GEMS + int(full["gems"]))
	Game.data = keep


static func _shop(ok: Callable) -> void:
	var d := Game._fresh()
	var now := T0
	var a := EggShop.offers(d, now)
	var b := EggShop.offers(Game._fresh(), now + 3600)
	ok.call("egg shop: four offers", a.size() == EggShop.SLOTS)
	var same := true
	for i in a.size():
		same = same and str(a[i]["egg"]) == str(b[i]["egg"]) and int(a[i]["price"]) == int(b[i]["price"])
	ok.call("egg shop: the same day shows the same shelf", same)
	var real := true
	for of: Dictionary in a:
		real = real and SDB.EGGS.has(str(of["egg"])) and int(of["price"]) > 0 and str(of["cur"]) in ["gold", "gems"]
	ok.call("egg shop: every offer is a real egg with a price", real)
	var changed := false
	for day in range(1, 12):
		var o := EggShop.offers(d, now + day * EggShop.DAY)
		changed = changed or str(o[1]["egg"]) != str(a[1]["egg"]) or str(o[2]["egg"]) != str(a[2]["egg"])
	ok.call("egg shop: the daily slots rotate", changed)
	var week_same := true
	var wk := (now / EggShop.WEEK) * EggShop.WEEK
	for day in 7:
		week_same = week_same and str(EggShop.offers(d, wk + day * EggShop.DAY)[3]["egg"]) == "omen"
	ok.call("egg shop: the weekly slot holds all week", week_same and bool(a[3]["weekly"]))
	# Buying.
	ok.call("egg shop: no gold, no gems, no egg", EggShop.buy(d, 0, now, 1).is_empty() and EggShop.buy(d, 1, now, 1).is_empty() and SK.hatchery(d).is_empty())
	d["gold"] = 10000
	d["gems"] = 500
	var gold0 := int(d["gold"])
	var got := EggShop.buy(d, 0, now, 77)
	ok.call("egg shop: buying pays and lays the egg", str(got["egg"]) == str(a[0]["egg"]) and int(d["gold"]) == gold0 - int(a[0]["price"]) and SK.hatchery(d).size() == 1)
	ok.call("egg shop: an offer sells once a day", EggShop.buy(d, 0, now + 60, 78).is_empty() and bool(EggShop.offers(d, now + 60)[0]["sold"]) and EggShop.buy_block(d, 0, now + 60) == "Sold out")
	ok.call("egg shop: it is back the next day", not bool(EggShop.offers(d, now + EggShop.DAY)[0]["sold"]) and (SK.block(d)["shop"] as Dictionary).size() == 1)
	var gems0 := SK.gems(d)
	var wk_buy := EggShop.buy(d, 3, now, 79)
	ok.call("egg shop: the weekly omen egg costs gems", str(wk_buy["egg"]) == "omen" and SK.gems(d) == gems0 - int(a[3]["price"]) and SK.has_egg(d, "omen"))
	EggShop.buy(d, 0, now + EggShop.DAY, 80)
	ok.call("egg shop: old days are forgotten", (SK.block(d)["shop"] as Dictionary).size() == 2)
	var f := Game._fresh()
	f["gold"] = 99999
	f["gems"] = 99999
	for i in SDB.HATCH_SLOTS:
		SK.give_egg(f, "brood", now, i)
	ok.call("egg shop: a full hatchery blocks it without charging", EggShop.buy(f, 1, now, 1).is_empty() and int(f["gems"]) == 99999 and EggShop.buy_block(f, 1, now) == "The hatchery is full")
	ok.call("egg shop: a bad slot is refused", EggShop.buy_block(f, 9, now) != "" and EggShop.buy(f, -1, now, 1).is_empty())
	# A species egg you own is never offered.
	var o := Game._fresh()
	SK.own(o, "drake")
	SK.own(o, "bat")
	var never := true
	for day in 60:
		var offs := EggShop.offers(o, now + day * EggShop.DAY)
		never = never and str(offs[2]["egg"]) == "season"
	ok.call("egg shop: no species egg for a pet you already have", never)
	# Through the Game, with a save.
	Game.memory_only = true
	var keep := Game.data.duplicate(true)
	Game.data = Game._fresh()
	Game.data["gold"] = 5000
	var sh := Game.egg_shop()
	var bought := Game.buy_egg(0)
	ok.call("egg shop: Game.buy_egg works on the save", sh.size() == 4 and not bought.is_empty() and int(Game.data["gold"]) < 5000)
	Game.data = keep
