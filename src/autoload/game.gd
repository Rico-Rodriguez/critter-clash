extends Node
## The profile: currencies, heroes, gear, skills, the collection log and
## settings. Saved as JSON in user://. Also the loot and reward rules that
## change the profile (chests, hunt results, item rolls).

signal changed

const SAVE_PATH := "user://barrowfall_save.json"
const SAVE_VERSION := 1
const INVENTORY_CAP := 48

var data: Dictionary = {}
var rng := RandomNumberGenerator.new()
## Set by the capture harness and tests: never touch the disk.
var memory_only := false


func _ready() -> void:
	rng.randomize()
	if OS.get_cmdline_user_args().has("--fresh") or OS.get_cmdline_user_args().has("--capture") or OS.get_cmdline_user_args().has("--bot"):
		memory_only = true
		data = _fresh()
	else:
		load_save()


func _fresh() -> Dictionary:
	var heroes := {}
	for id in DB.HERO_ORDER:
		heroes[id] = {"level": 1, "shards": 0, "unlocked": DB.HEROES[id]["unlock"] == "start", "gear": {}}
	var skills := {}
	for s in DB.SKILLS:
		skills[s] = DB.xp_for_level(10) if s == "hitpoints" else 0
	return {
		"version": SAVE_VERSION,
		"gold": 0,
		"hero": "knight",
		"heroes": heroes,
		"items": [],
		"next_uid": 1,
		"skills": skills,
		"log": {},
		"tier_unlocked": 0,
		"tier": 0,
		"pet": "",
		"stats": {"hunts": 0, "wins": 0, "kills": 0, "elites": 0, "boss_kills": 0, "best": {}},
		"settings": {"music": 0.7, "sfx": 1.0, "shake": true, "quality": "auto", "camera": "standard"},
		"seen_tutorial": false,
	}


func load_save() -> void:
	data = _fresh()
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary and int(parsed.get("version", 0)) == SAVE_VERSION:
		_merge(data, parsed)


## Copies saved values over the fresh defaults so new keys keep defaults.
func _merge(into: Dictionary, from: Dictionary) -> void:
	for k in from:
		if into.has(k) and into[k] is Dictionary and from[k] is Dictionary:
			_merge(into[k], from[k])
		else:
			into[k] = from[k]


func save() -> void:
	changed.emit()
	if memory_only:
		return
	var f := FileAccess.open(SAVE_PATH + ".tmp", FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(data))
	f.close()
	DirAccess.rename_absolute(SAVE_PATH + ".tmp", SAVE_PATH)


# --- Accessors -----------------------------------------------------------

func gold() -> int:
	return int(data["gold"])


func hero_id() -> String:
	return str(data["hero"])


func hero(id: String) -> Dictionary:
	return data["heroes"][id]


func set_hero(id: String) -> void:
	if hero(id)["unlocked"]:
		data["hero"] = id
		save()


func tier() -> int:
	return int(data["tier"])


func set_tier(t: int) -> void:
	data["tier"] = clampi(t, 0, int(data["tier_unlocked"]))
	save()


func setting(key: String):
	return data["settings"].get(key)


func set_setting(key: String, value) -> void:
	data["settings"][key] = value
	save()


func skill_level(s: String) -> int:
	return DB.level_for_xp(int(data["skills"][s]))


func skill_levels() -> Dictionary:
	var out := {}
	for s in DB.SKILLS:
		out[s] = skill_level(s)
	return out


func combat_level() -> int:
	return DB.combat_level(skill_levels())


func item(uid: int) -> Dictionary:
	for it in data["items"]:
		if int(it["uid"]) == uid:
			return it
	return {}


func equipped(hero_id_: String, slot: String) -> Dictionary:
	var uid := int(hero(hero_id_)["gear"].get(slot, 0))
	return item(uid) if uid > 0 else {}


func owner_of(uid: int) -> String:
	for id in DB.HERO_ORDER:
		for slot in hero(id)["gear"]:
			if int(hero(id)["gear"][slot]) == uid:
				return id
	return ""


func equip(hero_id_: String, uid: int) -> void:
	var it := item(uid)
	if it.is_empty():
		return
	var prev := owner_of(uid)
	if prev != "":
		hero(prev)["gear"].erase(it["slot"])
	hero(hero_id_)["gear"][it["slot"]] = uid
	save()


func unequip(hero_id_: String, slot: String) -> void:
	hero(hero_id_)["gear"].erase(slot)
	save()


func item_value(it: Dictionary) -> int:
	return {"common": 8, "magic": 25, "rare": 70, "legendary": 400}.get(it["rarity"], 5)


func salvage(uid: int) -> int:
	var it := item(uid)
	if it.is_empty():
		return 0
	var owner := owner_of(uid)
	if owner != "":
		hero(owner)["gear"].erase(it["slot"])
	data["items"].erase(it)
	var v := item_value(it)
	data["gold"] = gold() + v
	save()
	return v


## Sells every unequipped item at or below `rarity`. Returns gold gained.
func salvage_below(rarity: String) -> int:
	var cap := DB.RARITIES.find(rarity)
	var total := 0
	for it in data["items"].duplicate():
		if DB.RARITIES.find(it["rarity"]) <= cap and owner_of(int(it["uid"])) == "" and str(it.get("unique", "")) == "":
			total += salvage(int(it["uid"]))
	return total


func upgrade_cost(id: String) -> Dictionary:
	var lvl := int(hero(id)["level"])
	if lvl >= DB.HERO_MAX_LEVEL:
		return {}
	return {"shards": DB.UPGRADE_SHARDS[lvl], "gold": DB.UPGRADE_GOLD[lvl]}


func can_upgrade(id: String) -> bool:
	var c := upgrade_cost(id)
	return not c.is_empty() and hero(id)["unlocked"] and int(hero(id)["shards"]) >= c["shards"] and gold() >= c["gold"]


func upgrade(id: String) -> bool:
	if not can_upgrade(id):
		return false
	var c := upgrade_cost(id)
	hero(id)["shards"] = int(hero(id)["shards"]) - c["shards"]
	data["gold"] = gold() - c["gold"]
	hero(id)["level"] = int(hero(id)["level"]) + 1
	save()
	return true


# --- Hero stats ----------------------------------------------------------

## The hero's numbers before in-hunt cards: base, card level, skills, gear.
func hero_stats(id: String) -> Dictionary:
	var h: Dictionary = DB.HEROES[id]
	var lvl := int(hero(id)["level"])
	var sk := skill_levels()
	var power := 1.0 + DB.LEVEL_POWER * (lvl - 1)
	var s := {
		"hp": h["hp"] * power, "dmg": h["dmg"] * power, "rate": h["rate"], "speed": h["speed"],
		"range": h["range"], "crit": 0.05, "armor": h["armor"], "regen": 0.0, "gold": 1.0,
		"arc": h.get("arc", 0.0), "splash": h.get("splash", 0.0), "proj_speed": h.get("proj_speed", 0.0),
		"style": h["style"], "cards": [],
	}
	# Skills: the Old School levels give small, steady edges.
	s["rate"] *= 1.0 + 0.006 * (sk["attack"] - 1)
	s["hp"] *= 1.0 + 0.01 * (sk["hitpoints"] - 10)
	s["armor"] += 0.004 * (sk["defence"] - 1)
	match h["skill"]:
		"melee":
			s["dmg"] *= 1.0 + 0.01 * (sk["strength"] - 1)
		"ranged":
			s["dmg"] *= 1.0 + 0.01 * (sk["ranged"] - 1)
		"magic":
			s["dmg"] *= 1.0 + 0.01 * (sk["magic"] - 1)
	# Gear.
	for slot in DB.SLOTS:
		var it := equipped(id, slot)
		if it.is_empty():
			continue
		var st: Dictionary = it["stats"]
		s["dmg"] *= 1.0 + st.get("dmg", 0) / 100.0
		s["hp"] *= 1.0 + st.get("hp", 0) / 100.0
		s["rate"] *= 1.0 + st.get("aspd", 0) / 100.0
		s["crit"] += st.get("crit", 0) / 100.0
		s["speed"] *= 1.0 + st.get("speed", 0) / 100.0
		s["armor"] += st.get("armor", 0) / 100.0
		s["gold"] += st.get("gold", 0) / 100.0
		s["regen"] += float(st.get("regen", 0))
		var u := str(it.get("unique", ""))
		if u != "" and DB.UNIQUES[u].has("card"):
			s["cards"].append(DB.UNIQUES[u]["card"])
	s["armor"] = minf(s["armor"], 0.6)
	return s


## One number for the roster: roughly damage per second times survivability.
func power_score(id: String) -> int:
	var s := hero_stats(id)
	return int(round(s["dmg"] * s["rate"] * 4.0 + s["hp"] * (1.0 + s["armor"]) * 0.5))


# --- Items ---------------------------------------------------------------

func roll_rarity(source: String, loot_mult := 1.0) -> String:
	var w: Dictionary = DB.DROP_RARITY[source].duplicate()
	w["rare"] *= loot_mult
	w["legendary"] *= loot_mult * loot_mult
	var total := 0.0
	for k in w:
		total += w[k]
	var r := rng.randf() * total
	for k in DB.RARITIES:
		r -= w[k]
		if r <= 0.0:
			return k
	return "common"


## A random item. Legendary rolls become a known unique from the source's
## table when one exists, so legendaries always mean something.
func roll_item(source: String, tier_i: int, slot := "") -> Dictionary:
	var t: Dictionary = DB.TIERS[tier_i]
	var rarity := roll_rarity(source, t["loot"])
	if rarity == "legendary":
		var pool := []
		for u in DB.UNIQUES:
			var ud: Dictionary = DB.UNIQUES[u]
			if ud["slot"] in DB.SLOTS:
				pool.append(u)
		return make_unique(pool[rng.randi() % pool.size()])
	if slot == "":
		slot = DB.SLOTS[rng.randi() % DB.SLOTS.size()]
	var step := DB.RARITIES.find(rarity)
	var tier_bonus := 1.0 + 0.35 * tier_i
	var stats := {}
	var main: String = DB.SLOT_MAIN[slot]
	stats[main] = _roll_affix(main, step, tier_bonus)
	var pool: Array = DB.SLOT_POOL[slot].duplicate()
	pool.erase(main)
	pool.shuffle()
	for i in step:
		if i < pool.size():
			stats[pool[i]] = _roll_affix(pool[i], step, tier_bonus)
	var prefixes: Array = DB.ITEM_PREFIX[rarity]
	var bases: Array = DB.ITEM_BASES[slot]
	var name_ := "%s %s" % [prefixes[rng.randi() % prefixes.size()], bases[rng.randi() % bases.size()]]
	return {"uid": 0, "slot": slot, "rarity": rarity, "name": name_, "stats": stats, "unique": "", "tier": tier_i}


func _roll_affix(key: String, step: int, mult: float) -> int:
	var r: Array = DB.AFFIXES[key]["roll"]
	var lo: float = r[0] * (1.0 + 0.5 * step) * mult
	var hi: float = r[1] * (1.0 + 0.5 * step) * mult
	return int(round(rng.randf_range(lo, hi)))


func make_unique(u: String) -> Dictionary:
	var ud: Dictionary = DB.UNIQUES[u]
	return {"uid": 0, "slot": ud["slot"], "rarity": ud["rarity"], "name": ud["name"], "stats": ud.get("stats", {}).duplicate(), "unique": u, "tier": 0}


## Adds an item to the bag (or the log / pet / sale for non-gear uniques).
## Returns the stored item, or {} when it was turned into gold.
func grant_item(it: Dictionary) -> Dictionary:
	var u := str(it.get("unique", ""))
	if u != "":
		data["log"][u] = int(data["log"].get(u, 0)) + 1
		var ud: Dictionary = DB.UNIQUES[u]
		if ud["slot"] == "pet":
			if str(data["pet"]) == "":
				data["pet"] = u
			return {}
		if ud["slot"] == "trophy":
			data["gold"] = gold() + int(ud.get("sell", 0))
			return {}
	if data["items"].size() >= INVENTORY_CAP:
		data["gold"] = gold() + item_value(it)
		return {}
	it["uid"] = int(data["next_uid"])
	data["next_uid"] = int(data["next_uid"]) + 1
	data["items"].append(it)
	return it


## Rolls a source's unique table (collection log). Returns unique ids hit.
func roll_uniques(source: String, tier_i: int) -> Array:
	var hits := []
	var mult: float = DB.TIERS[tier_i]["loot"]
	for u in DB.LOG_ORDER:
		var ud: Dictionary = DB.UNIQUES[u]
		var src := str(ud["source"])
		if src == source or (src == "nightmare" and source == "boss" and tier_i == 2):
			if rng.randf() < mult / float(ud["rate"]):
				hits.append(u)
	return hits


func is_better(it: Dictionary, hero_id_: String) -> bool:
	var cur := equipped(hero_id_, it["slot"])
	if cur.is_empty():
		return true
	return item_score(it) > item_score(cur)


func item_score(it: Dictionary) -> float:
	var s := 0.0
	for k in it["stats"]:
		s += float(it["stats"][k])
	return s + (60.0 if str(it.get("unique", "")) != "" else 0.0)


func describe_stats(it: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	for k in it["stats"]:
		out.append(DB.AFFIXES[k]["label"] % int(it["stats"][k]))
	var u := str(it.get("unique", ""))
	if u != "":
		out.append(str(DB.UNIQUES[u].get("power", "")))
	return out


# --- Rewards -------------------------------------------------------------

## Opens a chest kind: returns a list of rewards already applied.
func open_chest(kind: String) -> Array:
	var c: Dictionary = DB.CHESTS[kind]
	var out := []
	var g := rng.randi_range(c["gold"][0], c["gold"][1])
	data["gold"] = gold() + g
	out.append({"type": "gold", "amount": g})
	# Shards: split between two heroes, favouring locked ones a little so the
	# roster opens up.
	var ids: Array = DB.HERO_ORDER.duplicate()
	ids.shuffle()
	var total: int = c["shards"]
	var a := int(ceil(total * 0.6))
	for pair in [[ids[0], a], [ids[1], total - a]]:
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
	return {"silver": 0, "gold": 1, "crypt": 2}.get(kind, 0)


## Applies a finished hunt. `r`: win, tier, hero, gold, xp {skill: amount},
## items [], kills, elites, time. Returns a summary with level-ups.
func finish_hunt(r: Dictionary) -> Dictionary:
	var summary := {"levels": [], "unlocked_tier": -1, "unlocked_hero": "", "items": []}
	data["gold"] = gold() + int(r.get("gold", 0))
	var before := skill_levels()
	for s in r.get("xp", {}):
		data["skills"][s] = mini(int(data["skills"][s]) + int(r["xp"][s]), 200000000)
	var after := skill_levels()
	for s in DB.SKILLS:
		if after[s] > before[s]:
			summary["levels"].append({"skill": s, "from": before[s], "to": after[s]})
	for it in r.get("items", []):
		var stored := grant_item(it)
		summary["items"].append(stored if not stored.is_empty() else it)
	var st: Dictionary = data["stats"]
	st["hunts"] = int(st["hunts"]) + 1
	st["kills"] = int(st["kills"]) + int(r.get("kills", 0))
	st["elites"] = int(st["elites"]) + int(r.get("elites", 0))
	if r.get("win", false):
		st["wins"] = int(st["wins"]) + 1
		st["boss_kills"] = int(st["boss_kills"]) + 1
		var t := int(r["tier"])
		var key := str(t)
		var best := float(st["best"].get(key, 0.0))
		if best <= 0.0 or float(r["time"]) < best:
			st["best"][key] = float(r["time"])
		if t >= int(data["tier_unlocked"]) and t < DB.TIERS.size() - 1:
			data["tier_unlocked"] = t + 1
			summary["unlocked_tier"] = t + 1
		if t >= 1 and not hero("barbarian")["unlocked"]:
			hero("barbarian")["unlocked"] = true
			summary["unlocked_hero"] = "barbarian"
	var opened := unlock_by_shards()
	if opened != "":
		summary["unlocked_hero"] = opened
	save()
	return summary
