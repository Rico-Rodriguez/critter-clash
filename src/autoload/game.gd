extends Node
## The profile: currencies, heroes, gear, skills, the collection log and
## settings. Saved as JSON in user://. Also the loot and reward rules that
## change the profile (chests, hunt results, item rolls).

signal changed

const SAVE_PATH := "user://barrowfall_save.json"
const SAVE_VERSION := 3
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
	Sfx.refresh_volume.call_deferred()


func _fresh() -> Dictionary:
	var heroes := {}
	for id in DB.HERO_ORDER:
		heroes[id] = {"level": 1, "shards": 0, "unlocked": DB.HEROES[id]["unlock"] == "start", "gear": {}, "talents": []}
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
		"settings": {"music": 0.7, "sfx": 1.0, "shake": true, "quality": "auto", "camera": "standard", "buttons": "right", "haptics": true},
		"seen_tutorial": false,
		"seen_items": [],
		"bounties": {"day": "", "list": []},
		"zone": "barrow",
		"mode": "horde",
	}


func load_save() -> void:
	data = _fresh()
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary and int(parsed.get("version", 0)) in [1, 2, SAVE_VERSION]:
		if int(parsed.get("version", 0)) == 1:
			_migrate_v1(parsed)
		if int(parsed.get("version", 0)) == 2:
			_migrate_v2(parsed)
		_merge(data, parsed)


## v1 had three slots (weapon, armor, trinket); armor became chest.
func _migrate_v1(d: Dictionary) -> void:
	for it in d.get("items", []):
		if it.get("slot", "") == "armor":
			it["slot"] = "chest"
	for hid in d.get("heroes", {}):
		var g: Dictionary = d["heroes"][hid].get("gear", {})
		if g.has("armor"):
			g["chest"] = g["armor"]
			g.erase("armor")
	d["version"] = 2


## v3 made gear class-specific with material tiers. Old pieces go to the hero
## wearing them (or a hero picked by item id) at a tier matching their rarity.
func _migrate_v2(d: Dictionary) -> void:
	var worn := {}
	for hid in d.get("heroes", {}):
		for slot in d["heroes"][hid].get("gear", {}):
			worn[int(d["heroes"][hid]["gear"][slot])] = hid
	for it in d.get("items", []):
		if it.has("cls"):
			continue
		var uid := int(it.get("uid", 0))
		var u := str(it.get("unique", ""))
		if u != "" and DB.UNIQUES.has(u) and DB.UNIQUES[u].has("cls"):
			it["cls"] = DB.UNIQUES[u]["cls"]
			it["mat"] = 6
		else:
			it["cls"] = worn.get(uid, DB.HERO_ORDER[uid % DB.HERO_ORDER.size()])
			it["mat"] = clampi(DB.RARITIES.find(str(it.get("rarity", "common"))) * 2 + int(it.get("tier", 0)), 0, 5)
		# A piece worn by a hero other than its new owner goes back to the bag.
		if worn.has(uid) and worn[uid] != it["cls"]:
			d["heroes"][worn[uid]]["gear"].erase(it["slot"])
		if u == "":
			it["name"] = _item_name(it, str(it.get("rarity", "common")))
	d["version"] = SAVE_VERSION


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


func zone_id() -> String:
	var z := str(data.get("zone", "barrow"))
	return z if DB.ZONES.has(z) and zone_unlocked(z) else "barrow"


func mode_id() -> String:
	var m := str(data.get("mode", "horde"))
	return m if DB.MODES.has(m) and mode_unlocked(m) else "horde"


## Descent and Boss Rush open once you have won on Normal.
func mode_unlocked(id: String) -> bool:
	return not DB.MODES[id].has("unlock") or int(data["tier_unlocked"]) >= 1


func best_depth(hero: String) -> int:
	return int(data["stats"]["best"].get("descent_" + hero, 0))


func set_mode(id: String) -> void:
	if DB.MODES.has(id):
		data["mode"] = id
		save()


func zone_unlocked(id: String) -> bool:
	return id == "barrow" or (id == "depths" and int(data["tier_unlocked"]) >= 2)


func set_zone(id: String) -> void:
	if DB.ZONES.has(id) and zone_unlocked(id):
		data["zone"] = id
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


## Why a hero cannot wear a piece ("" when it can): wrong class, or too low a
## skill level for the material.
func wear_block(hero_id_: String, it: Dictionary) -> String:
	if str(it.get("cls", hero_id_)) != hero_id_:
		return "Made for the %s" % DB.HEROES[it["cls"]]["name"]
	var skill := GearDB.skill_for(hero_id_, str(it["slot"]))
	var need := GearDB.req_for(it)
	if skill_level(skill) < need:
		return "Requires %s %d" % [DB.SKILL_NAME[skill], need]
	return ""


func equip(hero_id_: String, uid: int) -> void:
	var it := item(uid)
	if it.is_empty() or wear_block(hero_id_, it) != "":
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
	return int({"common": 8, "magic": 25, "rare": 70, "legendary": 400}.get(it["rarity"], 5) * (1.0 + 0.5 * int(it.get("mat", 0))))


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


## Items the player has not looked at yet (shown with a dot).
func new_item_count() -> int:
	var n := 0
	for it in data["items"]:
		if not int(it["uid"]) in data["seen_items"]:
			n += 1
	return n


func is_new(uid: int) -> bool:
	return not uid in data["seen_items"]


func mark_items_seen() -> void:
	for it in data["items"]:
		if not int(it["uid"]) in data["seen_items"]:
			data["seen_items"].append(int(it["uid"]))
	save()


## Puts the best bag item in every slot, taking only from this hero or from
## the bag (never from another hero). Returns how many slots changed.
func equip_best(hero_id_: String) -> int:
	var changed_n := 0
	for slot in DB.SLOTS:
		var best := equipped(hero_id_, slot)
		var best_score := item_score(best) if not best.is_empty() else -1.0
		for it in data["items"]:
			if it["slot"] != slot:
				continue
			var owner := owner_of(int(it["uid"]))
			if (owner != "" and owner != hero_id_) or wear_block(hero_id_, it) != "":
				continue
			if item_score(it) > best_score:
				best = it
				best_score = item_score(it)
		if not best.is_empty() and int(hero(hero_id_)["gear"].get(slot, 0)) != int(best["uid"]):
			hero(hero_id_)["gear"][slot] = int(best["uid"])
			changed_n += 1
	if changed_n > 0:
		save()
	return changed_n


## Unequipped, non-unique common and magic items: safe to sell in one go.
func junk_items() -> Array:
	var out := []
	for it in data["items"]:
		if DB.RARITIES.find(it["rarity"]) <= 1 and str(it.get("unique", "")) == "" and owner_of(int(it["uid"])) == "":
			out.append(it)
	return out


## Stat-by-stat difference of `it` against `cur` (the equipped piece, or {}).
## Returns [{"key", "label", "diff", "text"}], biggest changes first.
func compare(it: Dictionary, cur: Dictionary) -> Array:
	var keys := {}
	for k in it["stats"]:
		keys[k] = true
	if not cur.is_empty():
		for k in cur["stats"]:
			keys[k] = true
	var out := []
	for k in keys:
		var d: int = int(it["stats"].get(k, 0)) - (int(cur["stats"].get(k, 0)) if not cur.is_empty() else 0)
		if d == 0:
			continue
		var sh: Array = DB.AFFIX_SHORT[k]
		out.append({"key": k, "label": sh[0], "diff": d, "text": "%s%d%s %s" % ["+" if d > 0 else "", d, sh[1], sh[0]]})
	out.sort_custom(func(a, b): return absi(a["diff"]) > absi(b["diff"]))
	return out


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
## `preview` maps a slot to a bag item to try there instead of what is worn
## (the gear screen shows the change before you commit).
func hero_stats(id: String, preview := {}) -> Dictionary:
	var h: Dictionary = DB.HEROES[id]
	var lvl := int(hero(id)["level"])
	var sk := skill_levels()
	var power := 1.0 + DB.LEVEL_POWER * (mini(lvl, 10) - 1) + DB.LEVEL_POWER_LATE * maxi(lvl - 10, 0)
	var s := {
		"hp": h["hp"] * power, "dmg": h["dmg"] * power, "rate": h["rate"], "speed": h["speed"],
		"range": h["range"], "crit": 0.05, "armor": h["armor"], "regen": 0.0, "gold": 1.0,
		"arc": h.get("arc", 0.0), "splash": h.get("splash", 0.0), "proj_speed": h.get("proj_speed", 0.0),
		"style": h["style"], "cards": [], "dash": 0.0, "super": 0.0, "xp": 0.0, "flags": {},
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
		var it: Dictionary = preview[slot] if preview.has(slot) else equipped(id, slot)
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
	_apply_talents(id, s)
	s["armor"] = minf(s["armor"], 0.6)
	return s


# --- Talents -------------------------------------------------------------

func talents(id: String) -> Array:
	return hero(id).get("talents", [])


func talent_points(id: String) -> int:
	return int(hero(id)["level"]) - 1 - talents(id).size()


func has_talent(id: String, path: int, idx: int) -> bool:
	return TalentDB.key(path, idx) in talents(id)


## A node can be learned with a point to spend and the node above it owned.
func can_learn(id: String, path: int, idx: int) -> bool:
	return talent_points(id) > 0 and not has_talent(id, path, idx) and (idx == 0 or has_talent(id, path, idx - 1))


func learn_talent(id: String, path: int, idx: int) -> bool:
	if not can_learn(id, path, idx):
		return false
	var h := hero(id)
	if not h.has("talents"):
		h["talents"] = []
	h["talents"].append(TalentDB.key(path, idx))
	save()
	return true


## Free: hands back every point.
func respec(id: String) -> void:
	hero(id)["talents"] = []
	save()


func _apply_talents(id: String, s: Dictionary) -> void:
	for k: String in talents(id):
		var parts := k.split(".")
		var path := int(parts[0])
		var idx := int(parts[1])
		if path >= TalentDB.paths(id).size() or idx >= TalentDB.paths(id)[path]["nodes"].size():
			continue
		var n := TalentDB.node(id, path, idx)
		s["dmg"] *= 1.0 + float(n.get("dmg", 0.0))
		s["hp"] *= 1.0 + float(n.get("hp", 0.0))
		s["rate"] *= 1.0 + float(n.get("rate", 0.0))
		s["speed"] *= 1.0 + float(n.get("speed", 0.0))
		s["gold"] += float(n.get("gold", 0.0))
		s["crit"] += float(n.get("crit", 0.0))
		s["armor"] += float(n.get("armor", 0.0))
		s["regen"] += float(n.get("regen", 0.0)) * s["hp"]
		s["dash"] += float(n.get("dash", 0.0))
		s["super"] += float(n.get("super", 0.0))
		s["xp"] += float(n.get("xp", 0.0))
		for c in n.get("cards", []):
			s["cards"].append(c)
		for f: String in n.get("flags", {}):
			s["flags"][f] = maxf(float(s["flags"].get(f, 0.0)), float(n["flags"][f]))


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


## A random item for one hero's class (mostly the hero being played, so loot
## is useful). Harder content drops better material: `bonus` shifts the tier
## (zone, depth, boss). Legendary rolls become a known unique of that class.
func roll_item(source: String, tier_i: int, slot := "", cls := "", bonus := 0) -> Dictionary:
	var t: Dictionary = DB.TIERS[tier_i]
	var rarity := roll_rarity(source, t["loot"])
	if cls == "":
		cls = hero_id() if rng.randf() < 0.65 else DB.HERO_ORDER[rng.randi() % DB.HERO_ORDER.size()]
	if rarity == "legendary":
		var pool := []
		for u in DB.UNIQUES:
			var ud: Dictionary = DB.UNIQUES[u]
			if ud["slot"] in DB.SLOTS and ud["cls"] == cls and (slot == "" or ud["slot"] == slot):
				pool.append(u)
		if not pool.is_empty():
			return make_unique(pool[rng.randi() % pool.size()])
		rarity = "rare"
	if slot == "":
		slot = DB.SLOTS[rng.randi() % DB.SLOTS.size()]
	var mat := GearDB.roll_mat(tier_i, bonus + (1 if source == "boss" else 0), rng)
	return make_item(cls, slot, mat, rarity)


## Builds a piece: stats scale with the material and the rarity.
func make_item(cls: String, slot: String, mat: int, rarity: String) -> Dictionary:
	var step := DB.RARITIES.find(rarity)
	var scale_ := 1.0 + 0.22 * mat
	var stats := {}
	var main: String = DB.SLOT_MAIN[slot]
	stats[main] = _roll_affix(main, step, scale_)
	var pool: Array = DB.SLOT_POOL[slot].duplicate()
	pool.erase(main)
	pool.shuffle()
	for i in step:
		if i < pool.size():
			stats[pool[i]] = _roll_affix(pool[i], step, scale_)
	var it := {"uid": 0, "slot": slot, "rarity": rarity, "name": "", "stats": stats, "unique": "", "cls": cls, "mat": mat}
	it["name"] = _item_name(it, rarity)
	return it


func _item_name(it: Dictionary, rarity: String) -> String:
	var base := GearDB.base_name(str(it["cls"]), str(it["slot"]), int(it.get("mat", 0)))
	if rarity == "common":
		return base
	var prefixes: Array = DB.ITEM_PREFIX[rarity] if DB.ITEM_PREFIX.has(rarity) else DB.ITEM_PREFIX["rare"]
	return "%s %s" % [prefixes[rng.randi() % prefixes.size()], base]


func _roll_affix(key: String, step: int, mult: float) -> int:
	var r: Array = DB.AFFIXES[key]["roll"]
	var lo: float = r[0] * (1.0 + 0.35 * step) * mult
	var hi: float = r[1] * (1.0 + 0.35 * step) * mult
	return int(round(rng.randf_range(lo, hi)))


func make_unique(u: String) -> Dictionary:
	var ud: Dictionary = DB.UNIQUES[u]
	return {"uid": 0, "slot": ud["slot"], "rarity": ud["rarity"], "name": ud["name"], "stats": ud.get("stats", {}).duplicate(), "unique": u, "cls": ud.get("cls", "knight"), "mat": 6}


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
		if src == source or (src == "nightmare" and source in ["boss", "hexer"] and tier_i == 2):
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


## The number shown on gear tiles: the sum of its affixes (uniques get a bonus).
func item_power(it: Dictionary) -> int:
	return int(round(item_score(it)))


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
		var key := str(t) if str(r.get("zone", "barrow")) == "barrow" else "%s%d" % [r["zone"], t]
		if str(r.get("mode", "horde")) == "trial":
			key = "t" + key
		elif str(r.get("mode", "horde")) == "rush":
			key = "rush%d_%s" % [t, r["hero"]]
		var best := float(st["best"].get(key, 0.0))
		if best <= 0.0 or float(r["time"]) < best:
			st["best"][key] = float(r["time"])
		if t >= int(data["tier_unlocked"]) and t < DB.TIERS.size() - 1:
			data["tier_unlocked"] = t + 1
			summary["unlocked_tier"] = t + 1
		if t >= 1 and not hero("barbarian")["unlocked"]:
			hero("barbarian")["unlocked"] = true
			summary["unlocked_hero"] = "barbarian"
	if str(r.get("mode", "horde")) == "descent":
		var dkey: String = "descent_" + str(r["hero"])
		var d := int(r.get("depth", 1))
		if d > int(st["best"].get(dkey, 0)):
			st["best"][dkey] = d
			summary["record"] = true
	_bounty_progress(r)
	var opened := unlock_by_shards()
	if opened != "":
		summary["unlocked_hero"] = opened
	save()
	return summary


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
	if int(data["tier_unlocked"]) < 1:
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
		if def.has("veteran") and int(r.get("tier", 0)) < 1:
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
