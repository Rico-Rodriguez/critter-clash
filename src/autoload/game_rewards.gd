extends "res://src/autoload/game_heroes.gd"
## Game, part 4: rewards outside the hunt. Chests, the Trophy Road, the
## weekly omen, treasure trails, daily bounties and the shop.


# --- Rewards -------------------------------------------------------------

## Opens a chest kind: returns a list of rewards already applied.
func open_chest(kind: String) -> Array:
	var c: Dictionary = DB.CHESTS[kind]
	var out := []
	var g := rng.randi_range(c["gold"][0], c["gold"][1])
	data["gold"] = gold() + g
	out.append({"type": "gold", "amount": g})
	# Shards: most go to the hero you play (Brawl Stars' power points), the
	# rest to another, a locked one first: a head start for when it joins.
	var others: Array = DB.HERO_ORDER.filter(func(h): return h != hero_id())
	others.shuffle()
	others.sort_custom(func(x, y): return not hero(x)["unlocked"] and hero(y)["unlocked"])
	var total: int = c["shards"]
	var a := int(ceil(total * DB.SHARDS_TO_PLAYED))
	for pair in [[hero_id(), a], [others[0], total - a]]:
		var hid: String = pair[0]
		hero(hid)["shards"] = int(hero(hid)["shards"]) + int(pair[1])
		out.append({"type": "shards", "hero": hid, "amount": int(pair[1])})
	for i in c["items"]:
		var it := grant_item(roll_item("chest", tier_for_chest(kind)))
		if not it.is_empty():
			out.append({"type": "item", "item": it})
	var opened := unlock_by_shards()
	if opened != "":
		out.append({"type": "unlock", "hero": opened})
	save()
	return out


## Heroes join on the Trophy Road now; shards a locked hero gathers wait
## for it (XP lamps). Kept, returning "", for the callers that still ask.
func unlock_by_shards() -> String:
	return ""


func tier_for_chest(kind: String) -> int:
	return {"silver": 0, "gold": DB.TIER_VETERAN, "crypt": DB.TIER_NIGHTMARE}.get(kind, 0)


# --- Trophy Road -----------------------------------------------------------

## Trophies (saved as `renown`, the road's old name). They never go down.
func renown() -> int:
	return int(data.get("renown", 0))


## Trophies for a finished hunt (see DB.TROPHY_*). `summary` says whether it
## was the first win of the day or opened a new difficulty.
func _earn_renown(r: Dictionary, summary := {}) -> int:
	var n := 0
	if r.get("win", false):
		n = DB.TROPHY_WIN + int(r.get("tier", 0)) * DB.TROPHY_TIER
		n += mini(int(r.get("elites", 0)), DB.TROPHY_ELITE_CAP) * DB.TROPHY_ELITE
		if summary.get("first_win", false):
			n += DB.TROPHY_FIRST_WIN
		# The first win on a difficulty pays the first-clear bonus, even though
		# the next one only opens after DB.TIER_WINS wins.
		var wkey := "%s:%d" % [str(r.get("mode", "horde")), int(r.get("tier", 0))]
		if int(summary.get("unlocked_tier", -1)) >= 0 or int(data.get("tier_wins", {}).get(wkey, 0)) == 1:
			n += DB.TROPHY_FIRST_CLEAR
	else:
		n = mini(int(r.get("kills", 0)) / 15 + int(r.get("elites", 0)) * 2, DB.TROPHY_LOSS_MAX)
	if str(r.get("mode", "horde")) == "descent":
		n += int(r.get("depth", 1)) * DB.TROPHY_DEPTH
	data["renown"] = renown() + n
	return n


## Steps reached but not yet claimed.
func road_claimable() -> int:
	var n := int(data.get("road", 0))
	var open := 0
	while DB.road_threshold(n + open + 1) <= renown():
		open += 1
	return open


## 0..1 progress toward the next step.
func road_fill() -> float:
	return road_fill_for(renown())


## 0..1 progress toward the next step at a given trophy total (the results
## screen fills the bar from the old total to the new).
func road_fill_for(r: int) -> float:
	var done := 0
	while DB.road_threshold(done + 1) <= r:
		done += 1
	var lo := DB.road_threshold(done)
	var hi := DB.road_threshold(done + 1)
	return clampf(float(r - lo) / float(hi - lo), 0.0, 1.0)


## The next step that opens something (a mode, zone or hero), 1-based, or 0.
func road_next_unlock() -> int:
	for i in DB.TROPHY_ROAD.size():
		if DB.road_threshold(i + 1) > renown() and not str(DB.TROPHY_ROAD[i]["kind"]) in ["gold", "chest", "shards"]:
			return i + 1
	return 0


## Starting heroes not yet in the roster: what a `pick` step offers.
func road_pickable() -> Array:
	return DB.START_HEROES.filter(func(h): return not hero(h)["unlocked"])


## A short name for step n: "300 gold", "Boss Rush", "A new hero".
## A road card is in the draws once its step is claimed (derived from the
## claimed count, so old saves need no new key).
func card_open(id: String) -> bool:
	var st := DB.card_road_step(id)
	return st == 0 or int(data.get("road", 0)) >= st


func road_reward_text(n: int) -> String:
	var rw := DB.road_reward(n)
	match str(rw["kind"]):
		"gold":
			return "%d gold" % int(rw["amount"])
		"shards":
			return "%d shards" % int(rw["amount"])
		"mode":
			return str(DB.MODES[rw["id"]]["name"])
		"zone":
			return str(DB.ZONES[rw["id"]]["name"])
		"hero":
			return str(DB.HEROES[rw["id"]]["name"])
		"pick":
			return "A new hero"
		"rift_key":
			return "A rift key"
		"cards":
			return "New cards: %s" % ", ".join(PackedStringArray((rw["ids"] as Array).map(func(c): return str(DB.CARDS[c]["name"]))))
	return DB.CHESTS[rw["chest"]]["name"]


## Pays the next unclaimed step. A `pick` step takes the hero chosen (one of
## road_pickable()). Returns lines describing what came out.
func claim_road(pick := "") -> Array:
	if road_claimable() <= 0:
		return []
	var n := int(data["road"]) + 1
	var rw := DB.road_reward(n)
	var lines := []
	match str(rw["kind"]):
		"gold":
			data["gold"] = gold() + int(rw["amount"])
			lines.append("+%d gold" % int(rw["amount"]))
		"shards":
			hero(hero_id())["shards"] = int(hero(hero_id())["shards"]) + int(rw["amount"])
			lines.append("+%d %s shards" % [int(rw["amount"]), DB.HEROES[hero_id()]["name"]])
		"mode", "zone":
			if not str(rw["id"]) in data["unlocks"]:
				data["unlocks"].append(str(rw["id"]))
			lines.append("%s is open" % road_reward_text(n))
		"rift_key":
			data["rift_keys"] = int(data.get("rift_keys", 0)) + 1
			lines.append("A rift key: the Rift is open")
		"cards":
			lines.append("%s join your level-up draws" % road_reward_text(n).trim_prefix("New cards: "))
		"pick", "hero":
			var hid := str(rw.get("id", pick))
			var pickable := road_pickable()
			if str(rw["kind"]) == "pick" and not hid in pickable:
				hid = str(pickable[0]) if not pickable.is_empty() else ""
			if hid == "" or hero(hid)["unlocked"]:
				data["gold"] = gold() + DB.ROAD_SPARE_GOLD
				lines.append("+%d gold" % DB.ROAD_SPARE_GOLD)
			else:
				hero(hid)["unlocked"] = true
				lines.append("%s joins your band" % DB.HEROES[hid]["name"])
		"chest":
			for e in open_chest(str(rw["chest"])):
				match e["type"]:
					"gold":
						lines.append("+%d gold" % int(e["amount"]))
					"shards":
						lines.append("+%d %s shards" % [int(e["amount"]), DB.HEROES[e["hero"]]["name"]])
					"item":
						lines.append(str(e["item"]["name"]))
					"unlock":
						lines.append("%s joins your band" % DB.HEROES[e["hero"]]["name"])
	data["road"] = n
	save()
	return lines


## Where a locked hero comes from, for its card.
func hero_lock_text(id: String) -> String:
	for i in range(int(data["road"]), DB.TROPHY_ROAD.size()):
		var st: Dictionary = DB.TROPHY_ROAD[i]
		if str(st["kind"]) == "hero" and str(st["id"]) == id:
			return "Joins on the Trophy Road at %d trophies" % int(st["t"])
		if str(st["kind"]) == "pick" and id in DB.START_HEROES:
			return "Choose on the Trophy Road at %d trophies" % int(st["t"])
	return "Joins on the Trophy Road"


## A new save's first hero: it joins, the other starting heroes wait on the road.
func pick_start_hero(id: String) -> void:
	if not id in DB.START_HEROES:
		return
	for h in DB.START_HEROES:
		hero(h)["unlocked"] = h == id
	data["hero"] = id
	data["start_picked"] = true
	save()


## Opens every mode and zone the road gates (bots, captures, tests).
func open_whole_road() -> void:
	for st in DB.TROPHY_ROAD:
		if st.has("id") and str(st["kind"]) in ["mode", "zone"] and not str(st["id"]) in data["unlocks"]:
			data["unlocks"].append(str(st["id"]))


# --- Weekly omen -----------------------------------------------------------

## This week's omen: the week number picks one in turn.
func weekly_omen() -> Dictionary:
	var week := int(Time.get_unix_time_from_system() / 604800.0)
	return DB.WEEKLY_OMENS[week % DB.WEEKLY_OMENS.size()]


## The omen a hunt in `mode` carries, or {} (the Long Road keeps its own rules).
func active_omen(mode: String) -> Dictionary:
	if bool(data.get("omen_on", false)) and mode != "trial":
		return weekly_omen()
	return {}


func set_omen(on: bool) -> void:
	data["omen_on"] = on
	save()


# --- Treasure trails -------------------------------------------------------

func clue() -> Dictionary:
	return data.get("clue", {})


func clue_goal_text(g: Dictionary) -> String:
	var def: Dictionary = DB.CLUE_GOALS[g["id"]]
	var t: String = def["text"]
	if g["id"] == "win_hero":
		return t % DB.HEROES[g["hero"]]["name"]
	return t % int(def["n"]) if t.contains("%d") else t


func _clue_new() -> Dictionary:
	var ids: Array = DB.CLUE_GOALS.keys()
	ids.shuffle()
	var goals := []
	for i in DB.CLUE_STEPS:
		var gid: String = ids[i]
		var pool: Array = DB.HERO_ORDER.filter(func(h): return hero(h)["unlocked"])
		goals.append({"id": gid, "hero": pool[rng.randi() % pool.size()]})
	return {"step": 0, "goals": goals}


func _goal_met(g: Dictionary, r: Dictionary) -> bool:
	var win: bool = r.get("win", false)
	var def: Dictionary = DB.CLUE_GOALS[g["id"]]
	match g["id"]:
		"elites":
			return int(r.get("elites", 0)) >= int(def["n"])
		"win_hero":
			return win and r["hero"] == g["hero"]
		"nodash":
			return win and int(r.get("dashes", 99)) <= int(def["n"])
		"depth":
			return str(r.get("mode", "")) == "descent" and int(r.get("depth", 1)) >= int(def["n"])
		"veteran":
			return win and int(r.get("tier", 0)) >= DB.TIER_VETERAN
		"fast":
			return float(r.get("boss_time", 9999.0)) <= float(def["n"])
		"gold":
			return int(r.get("gold", 0)) >= int(def["n"])
	return false


## Advances the clue after a hunt. Returns {"event": "", "found", "step" or
## "casket", "lines": [...]} for the results screen.
func _clue_progress(r: Dictionary) -> Dictionary:
	var c := clue()
	if c.is_empty():
		var odds := 0.35 if r.get("win", false) else 0.12
		if rng.randf() < odds:
			data["clue"] = _clue_new()
			return {"event": "found"}
		return {}
	var step := int(c["step"])
	if not _goal_met(c["goals"][step], r):
		return {}
	step += 1
	if step < DB.CLUE_STEPS:
		c["step"] = step
		return {"event": "step", "step": step}
	data["clue"] = {}
	var lines := []
	data["gold"] = gold() + 600
	lines.append("+600 gold")
	hero(hero_id())["shards"] = int(hero(hero_id())["shards"]) + 12
	lines.append("+12 %s shards" % DB.HEROES[hero_id()]["name"])
	var it := roll_item("boss", maxi(int(r.get("tier", 0)), 1), "", "", 1)
	for i in 8:
		if it["rarity"] == "legendary":
			break
		it = roll_item("boss", maxi(int(r.get("tier", 0)), 1), "", "", 1)
	var stored := grant_item(it)
	lines.append(str((stored if not stored.is_empty() else it)["name"]))
	return {"event": "casket", "lines": lines}


# --- Daily bounties --------------------------------------------------------

## Draws today's bounties if the date changed. Seeded by the date, so the same
## day always gives the same three. Returns true when a new set was drawn.
func refresh_bounties(today := "") -> bool:
	if today == "":
		today = Time.get_date_string_from_system()
	var b: Dictionary = data["bounties"]
	if str(b["day"]) == today and not (b["list"] as Array).is_empty():
		return false
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(today)
	var ids: Array = DB.BOUNTY_POOL.keys()
	if int(data["tier_unlocked"]) < DB.TIER_VETERAN:
		ids.erase("veteran")
	var list := []
	while list.size() < DB.BOUNTIES_PER_DAY and not ids.is_empty():
		var id: String = ids[rng.randi() % ids.size()]
		ids.erase(id)
		var def: Dictionary = DB.BOUNTY_POOL[id]
		var k := rng.randi() % (def["targets"] as Array).size()
		var entry := {"id": id, "target": int(def["targets"][k]), "gold": int(def["gold"][k]), "progress": 0, "claimed": false, "hero": "", "shards": 0, "shard_hero": ""}
		if def.has("hero"):
			var pool: Array = DB.HERO_ORDER.filter(func(h): return hero(h)["unlocked"])
			entry["hero"] = pool[rng.randi() % pool.size()]
		if def.has("shards"):
			entry["shards"] = int(def["shards"])
			entry["shard_hero"] = entry["hero"] if entry["hero"] != "" else hero_id()
		list.append(entry)
	data["bounties"] = {"day": today, "list": list}
	save()
	return true


func bounty_text(e: Dictionary) -> String:
	var def: Dictionary = DB.BOUNTY_POOL[e["id"]]
	var t: String = def["text"]
	if def.has("hero"):
		return t % DB.HEROES[e["hero"]]["name"]
	return t % int(e["target"]) if t.contains("%d") else t


func bounty_done(e: Dictionary) -> bool:
	return int(e["progress"]) >= int(e["target"])


func bounty_claimable() -> int:
	var n := 0
	for e in data["bounties"]["list"]:
		if bounty_done(e) and not e["claimed"]:
			n += 1
	return n


func _bounty_progress(r: Dictionary) -> void:
	var won: bool = r.get("win", false)
	for e in data["bounties"]["list"]:
		var def: Dictionary = DB.BOUNTY_POOL[e["id"]]
		if e["claimed"] or (def.has("win") and not won):
			continue
		if def.has("veteran") and int(r.get("tier", 0)) < DB.TIER_VETERAN:
			continue
		if def.has("hero") and str(r.get("hero", "")) != str(e["hero"]):
			continue
		var amount := 0
		match def["stat"]:
			"wins": amount = 1
			"level": amount = int(r.get("level", 0))
			_: amount = int(r.get(def["stat"], 0))
		if def.has("best"):
			e["progress"] = maxi(int(e["progress"]), amount)
		else:
			e["progress"] = mini(int(e["progress"]) + amount, int(e["target"]))


## Pays out a finished bounty. Returns its reward ({} if not claimable).
func claim_bounty(i: int) -> Dictionary:
	var list: Array = data["bounties"]["list"]
	if i < 0 or i >= list.size():
		return {}
	var e: Dictionary = list[i]
	if e["claimed"] or not bounty_done(e):
		return {}
	e["claimed"] = true
	data["gold"] = gold() + int(e["gold"])
	var sh := str(e.get("shard_hero", ""))
	if int(e["shards"]) > 0 and sh != "":
		hero(sh)["shards"] = int(hero(sh)["shards"]) + int(e["shards"])
	var opened := unlock_by_shards()
	save()
	return {"gold": int(e["gold"]), "shards": int(e["shards"]), "hero": sh, "unlocked": opened}


# --- Shop ----------------------------------------------------------------------

## Draws the day's deals once (a new day, or a fresh save). Returns true when
## it drew. Slot 0 is always the free gift.
func refresh_shop(today_ := "") -> bool:
	if today_ == "":
		today_ = today()
	var s: Dictionary = data["shop"]
	if str(s["day"]) == today_ and not (s["deals"] as Array).is_empty():
		return false
	var top := clampi(int(data["tier_unlocked"]), 0, DB.TIERS.size() - 1)
	var deals := []
	if day_number(today_) % 2 == 0:
		deals.append({"kind": "gold", "amount": DB.SHOP_FREE_GOLD + DB.SHOP_FREE_GOLD_TIER * top, "price": 0})
	else:
		deals.append({"kind": "shards", "hero": hero_id(), "amount": DB.SHOP_FREE_SHARDS, "price": 0})
	# Shards for the hero in use, and for another (a locked one first, like chests).
	var others: Array = DB.HERO_ORDER.filter(func(h): return h != hero_id())
	others.shuffle()
	others.sort_custom(func(x, y): return not hero(x)["unlocked"] and hero(y)["unlocked"])
	for pair in [[hero_id(), 20], [others[0], 15]]:
		var n: int = pair[1]
		deals.append({"kind": "shards", "hero": pair[0], "amount": n, "price": _shop_round(n * DB.SHOP_SHARD_GOLD * (1.0 - DB.SHOP_DEAL_OFF))})
	# Two pieces for the hero in use, in different slots, at the best material
	# opened so far: useful today, never better than what the hunt can drop.
	var slots: Array = DB.SLOTS.duplicate()
	slots.shuffle()
	for r in ["rare", "magic"]:
		var mat := GearDB.roll_mat(int(DB.TIERS[top]["mat"]), 0, rng)
		var it := make_item(hero_id(), str(slots.pop_back()), mat, r)
		deals.append({"kind": "gear", "item": it, "price": DB.shop_gear_price(it)})
	var kinds := ["silver", "gold"] + (["crypt"] if top >= DB.TIER_NIGHTMARE else [])
	var ck: String = kinds[rng.randi() % kinds.size()]
	deals.append({"kind": "chest", "chest": ck, "price": _shop_round(int(DB.SHOP_CHESTS[ck]) * (1.0 - DB.SHOP_CHEST_OFF))})
	for d in deals:
		d["bought"] = false
	data["shop"] = {"day": today_, "deals": deals}
	save()
	return true


func _shop_round(v: float) -> int:
	return int(round(v / 10.0)) * 10


func shop_deals() -> Array:
	return data["shop"]["deals"]


## Why deal `i` can't be bought right now, or "" when it can.
func shop_block(i: int) -> String:
	var d: Dictionary = shop_deals()[i]
	if d["bought"]:
		return "Sold"
	if gold() < int(d["price"]):
		return "Not enough gold"
	return ""


## Free gifts not yet taken today (the Shop tab's dot).
func shop_free_ready() -> int:
	var n := 0
	for d in shop_deals():
		if int(d["price"]) == 0 and not d["bought"]:
			n += 1
	return n


## Buys deal `i` (not a chest: those go through buy_chest so the gold leaves
## when the lid opens). Returns the deal, or {} when it can't be bought.
func buy_deal(i: int) -> Dictionary:
	if shop_block(i) != "":
		return {}
	var d: Dictionary = shop_deals()[i]
	match str(d["kind"]):
		"gold":
			data["gold"] = gold() + int(d["amount"])
		"shards":
			hero(str(d["hero"]))["shards"] = int(hero(str(d["hero"]))["shards"]) + int(d["amount"])
			unlock_by_shards()
		"gear":
			var it := grant_item((d["item"] as Dictionary).duplicate(true))
			if not it.is_empty():
				d["uid"] = int(it["uid"])
		_:
			return {}
	data["gold"] = gold() - int(d["price"])
	d["bought"] = true
	save()
	return d


func shop_chest_price(kind: String, deal := -1) -> int:
	return int(shop_deals()[deal]["price"]) if deal >= 0 else int(DB.SHOP_CHESTS[kind])


## Pays for a chest and opens it: from the chest shelf (deal -1) or today's
## chest deal. Returns the rewards, or [] when it can't be paid for.
func buy_chest(kind: String, deal := -1) -> Array:
	if deal >= 0 and (shop_block(deal) != "" or shop_deals()[deal]["kind"] != "chest"):
		return []
	var price := shop_chest_price(kind, deal)
	if gold() < price:
		return []
	data["gold"] = gold() - price
	if deal >= 0:
		shop_deals()[deal]["bought"] = true
	return open_chest(kind)
