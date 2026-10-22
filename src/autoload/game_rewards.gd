extends "res://src/autoload/game_heroes.gd"
## Game, part 4: rewards outside the hunt. Chests, the renown road, the
## weekly omen, treasure trails and daily bounties.


# --- Rewards -------------------------------------------------------------

## Opens a chest kind: returns a list of rewards already applied.
func open_chest(kind: String) -> Array:
	var c: Dictionary = DB.CHESTS[kind]
	var out := []
	var g := rng.randi_range(c["gold"][0], c["gold"][1])
	data["gold"] = gold() + g
	out.append({"type": "gold", "amount": g})
	# Shards: most go to the hero you play (Brawl Stars' power points), the
	# rest to another, a locked one first so the roster still opens up.
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


## A locked hero with enough shards joins the roster. Returns its id or "".
func unlock_by_shards() -> String:
	for id in DB.HERO_ORDER:
		if not hero(id)["unlocked"] and int(hero(id)["shards"]) >= 20:
			hero(id)["unlocked"] = true
			hero(id)["shards"] = int(hero(id)["shards"]) - 20
			return id
	return ""


func tier_for_chest(kind: String) -> int:
	return {"silver": 0, "gold": DB.TIER_VETERAN, "crypt": DB.TIER_NIGHTMARE}.get(kind, 0)


# --- Renown road -----------------------------------------------------------

func renown() -> int:
	return int(data.get("renown", 0))


func _earn_renown(r: Dictionary) -> int:
	var n := 12 + int(r.get("tier", 0)) * 6 + int(r.get("kills", 0)) / 20 + int(r.get("elites", 0)) * 3
	if r.get("win", false):
		n += 25
	if str(r.get("mode", "horde")) == "descent":
		n += int(r.get("depth", 1)) * 4
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


## 0..1 progress toward the next step at a given renown total (the results
## screen fills the bar from the old total to the new).
func road_fill_for(r: int) -> float:
	var done := 0
	while DB.road_threshold(done + 1) <= r:
		done += 1
	var lo := DB.road_threshold(done) if done > 0 else 0
	var hi := DB.road_threshold(done + 1)
	return clampf(float(r - lo) / float(hi - lo), 0.0, 1.0)


func road_reward_text(n: int) -> String:
	var rw := DB.road_reward(n)
	match rw["kind"]:
		"gold":
			return "%d gold" % int(rw["amount"])
		"shards":
			return "%d %s shards" % [int(rw["amount"]), DB.HEROES[hero_id()]["name"]]
	return DB.CHESTS[rw["chest"]]["name"]


## Pays the next unclaimed step. Returns lines describing what came out.
func claim_road() -> Array:
	if road_claimable() <= 0:
		return []
	var n := int(data["road"]) + 1
	data["road"] = n
	var rw := DB.road_reward(n)
	var lines := []
	match rw["kind"]:
		"gold":
			data["gold"] = gold() + int(rw["amount"])
			lines.append("+%d gold" % int(rw["amount"]))
		"shards":
			hero(hero_id())["shards"] = int(hero(hero_id())["shards"]) + int(rw["amount"])
			lines.append("+%d %s shards" % [int(rw["amount"]), DB.HEROES[hero_id()]["name"]])
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
	save()
	return lines


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
