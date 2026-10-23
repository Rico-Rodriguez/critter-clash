extends "res://src/autoload/game_state.gd"
## Game, part 2: gear. The bag, equipping, item rolls, salvage, the gold
## sinks that change a piece (reforge, temper, glows) and gear sets.


# --- Bag and equipping --------------------------------------------------------

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
	if skill_level(skill, hero_id_) < need:
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
	_note_tier(hero_id_, it)
	save()


## Set when a hero first puts on a higher material than it ever wore: the
## equipment screen reads it (and resets it to -1) to celebrate the new tier.
var new_tier := -1


func _note_tier(id: String, it: Dictionary) -> void:
	var h := hero(id)
	if int(h.get("best_mat", -1)) < 0:
		# An older save: what the hero already wears is not news.
		var b := 0
		for slot in DB.SLOTS:
			if slot != it["slot"] and not equipped(id, slot).is_empty():
				b = maxi(b, int(equipped(id, slot).get("mat", 0)))
		h["best_mat"] = b
	var mat := int(it.get("mat", 0))
	if mat > int(h["best_mat"]):
		h["best_mat"] = mat
		new_tier = mat


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
			_note_tier(hero_id_, best)
			changed_n += 1
	if changed_n > 0:
		save()
	return changed_n


## Unequipped, non-unique common and magic items: safe to sell in one go.
func junk_items() -> Array:
	var out := []
	var spare := spare_copies()
	for it in data["items"]:
		if owner_of(int(it["uid"])) != "":
			continue
		if (DB.RARITIES.find(it["rarity"]) <= 1 and str(it.get("unique", "")) == "") or spare.has(int(it["uid"])):
			out.append(it)
	return out


## Two pieces that are the same in every way (name, material, stats) share
## a key: the bag stacks them, and only one is worth keeping.
func copy_key(it: Dictionary) -> String:
	return "%s|%s|%s|%d|%s" % [it["cls"], it["slot"], it["name"], int(it.get("mat", 0)), JSON.stringify(it["stats"], "", true)]


## uid -> true for every unworn piece that is an exact copy of another piece
## kept (a worn copy is kept first).
func spare_copies() -> Dictionary:
	var kept := {}
	for it in data["items"]:
		if owner_of(int(it["uid"])) != "":
			kept[copy_key(it)] = true
	var spare := {}
	for it in data["items"]:
		if owner_of(int(it["uid"])) != "":
			continue
		var k := copy_key(it)
		if kept.has(k):
			spare[int(it["uid"])] = true
		else:
			kept[k] = true
	return spare


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
	var mat := GearDB.roll_mat(int(t["mat"]), bonus + (1 if source == "boss" else 0), rng)
	var it := make_item(cls, slot, mat, rarity)
	# Ancient: Diablo's rare orange-bordered roll, every number 30% higher.
	if tier_i >= DB.ANCIENT_FROM_TIER and rarity == "rare" and rng.randf() < DB.ANCIENT_CHANCE * float(t["loot"]):
		for k in it["stats"]:
			it["stats"][k] = int(round(float(it["stats"][k]) * DB.ANCIENT_MULT))
		it["ancient"] = true
		it["name"] = gear_name(it)
	return it


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
	# `look` picks among a stage's alternative models (GearDB.piece).
	var it := {"uid": 0, "slot": slot, "rarity": rarity, "name": "", "stats": stats, "unique": "", "cls": cls, "mat": mat, "look": rng.randi() % 1000}
	it["name"] = gear_name(it)
	return it


## What a piece is called: its material and kind ("Steel Greaves"). No random
## prefix: the tier color and the bonus-stat pips already say how good it is,
## so the name only says what it is. Uniques keep their own names.
func gear_name(it: Dictionary) -> String:
	if str(it.get("unique", "")) != "":
		return str(it["name"])
	return ("Ancient " if it.get("ancient", false) else "") + GearDB.base_name(it)


## How many bonus stats a piece has beyond its slot's main one (0 to 2).
func bonus_count(it: Dictionary) -> int:
	return maxi(it["stats"].size() - 1, 0)


## "Tier 3 · 2 bonus stats · Legs", plus Ancient, a set or Unique: what a
## piece is, in words, without a power number.
func item_tag(it: Dictionary, with_slot := true) -> String:
	var parts := ["Tier %d" % (int(it.get("mat", 0)) + 1)]
	if str(it.get("unique", "")) != "":
		parts.append("Unique")
	else:
		var n := bonus_count(it)
		parts.append("no bonus stats" if n == 0 else ("1 bonus stat" if n == 1 else "%d bonus stats" % n))
	if it.get("ancient", false):
		parts.append("Ancient")
	var st := item_set(it)
	if st != "":
		parts.append("%s set" % DB.SETS[st]["short"])
	if with_slot:
		parts.append(str(DB.SLOT_NAME[it["slot"]]))
	return " · ".join(parts)


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
			if not u in data["pets"]:
				data["pets"].append(u)
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
		if src == source or (src == "nightmare" and source in ["boss", "hexer", "thorn"] and tier_i >= DB.TIER_NIGHTMARE):
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
	var st := item_set(it)
	if st != "":
		out.append("Set: %s (2: %s · 4: %s)" % [DB.SETS[st]["name"], DB.SETS[st]["2"]["desc"], DB.SETS[st]["4"]["desc"]])
	return out


# --- Gold sinks ----------------------------------------------------------------

func can_reforge(it: Dictionary) -> bool:
	return str(it.get("unique", "")) == "" and it["rarity"] != "common" and gold() >= DB.reforge_cost(it)


## New extra affixes (the main one stays): gold for another roll at a build.
func reforge(uid: int) -> bool:
	var it := item(uid)
	if it.is_empty() or not can_reforge(it):
		return false
	data["gold"] = gold() - DB.reforge_cost(it)
	var step := DB.RARITIES.find(str(it["rarity"]))
	var scale_ := (1.0 + 0.22 * int(it.get("mat", 0))) * (DB.ANCIENT_MULT if it.get("ancient", false) else 1.0)
	var main: String = DB.SLOT_MAIN[it["slot"]]
	var stats := {main: it["stats"][main]}
	var pool: Array = DB.SLOT_POOL[it["slot"]].duplicate()
	pool.erase(main)
	pool.shuffle()
	for i in step:
		if i < pool.size():
			stats[pool[i]] = _roll_affix(pool[i], step, scale_)
	it["stats"] = stats
	save()
	return true


func can_temper(it: Dictionary) -> bool:
	return str(it.get("unique", "")) == "" and int(it.get("mat", 0)) < GearDB.TIERS - 1 and gold() >= DB.temper_cost(it)


## One material step up: every number grows with it, and so does the name.
func temper(uid: int) -> bool:
	var it := item(uid)
	if it.is_empty() or not can_temper(it):
		return false
	data["gold"] = gold() - DB.temper_cost(it)
	var mat := int(it.get("mat", 0))
	var k := (1.0 + 0.22 * (mat + 1)) / (1.0 + 0.22 * mat)
	for key in it["stats"]:
		it["stats"][key] = int(round(float(it["stats"][key]) * k))
	it["mat"] = mat + 1
	it["name"] = gear_name(it)
	# Tempering can lift a piece past what the hero may wear: unequip if so.
	var owner := owner_of(uid)
	if owner != "" and wear_block(owner, it) != "":
		hero(owner)["gear"].erase(it["slot"])
	save()
	return true


func buy_glow(id: String, glow: String) -> bool:
	var h := hero(id)
	if glow in h["glows"]:
		h["glow"] = glow
		save()
		return true
	var cost := glow_price(glow)
	if DB.GLOWS[glow].get("gift", false) or gold() < cost:
		return false
	data["gold"] = gold() - cost
	h["glows"].append(glow)
	h["glow"] = glow
	save()
	return true


## The glow on sale this week (the shop's cosmetic deal), from the ones sold.
func glow_of_week() -> String:
	var sold: Array = DB.GLOW_ORDER.filter(func(g): return not DB.GLOWS[g].get("gift", false))
	# Day 0 was a Thursday; +3 makes the week turn over on Monday.
	return sold[((day_number(today()) + 3) / 7) % sold.size()]


func glow_price(glow: String) -> int:
	var cost := int(DB.GLOWS[glow]["gold"])
	if glow == glow_of_week():
		cost = int(round(cost * (1.0 - DB.SHOP_GLOW_OFF) / 10.0)) * 10
	return cost


func set_glow(id: String, glow: String) -> void:
	if glow == "" or glow in hero(id)["glows"]:
		hero(id)["glow"] = glow
		save()


# --- Sets and ancients -----------------------------------------------------------

## The set a piece belongs to ("" for none): its tag, or its unique's boss.
func item_set(it: Dictionary) -> String:
	return GearDB.set_of(it)


## Pieces of each set a hero wears.
func set_counts(id: String, preview := {}) -> Dictionary:
	var n := {}
	for slot in DB.SLOTS:
		var it: Dictionary = preview[slot] if preview.has(slot) else equipped(id, slot)
		var st := item_set(it) if not it.is_empty() else ""
		if st != "":
			n[st] = int(n.get(st, 0)) + 1
	return n


func _apply_sets(id: String, s: Dictionary, preview: Dictionary) -> void:
	var counts := set_counts(id, preview)
	for st: String in counts:
		for need in ["2", "4"]:
			if int(counts[st]) < int(need):
				continue
			var b: Dictionary = DB.SETS[st][need]
			s["dmg"] *= 1.0 + float(b.get("dmg", 0.0))
			s["hp"] *= 1.0 + float(b.get("hp", 0.0))
			s["speed"] *= 1.0 + float(b.get("speed", 0.0))
			s["crit"] += float(b.get("crit", 0.0))
			for f: String in b.get("flags", {}):
				s["flags"][f] = float(b["flags"][f])


## A boss's hoard: like any boss drop, but a piece may belong to its set.
func roll_boss_item(boss_id: String, tier_i: int, bonus := 0) -> Dictionary:
	var it := roll_item("boss", tier_i, "", "", bonus)
	if str(it.get("unique", "")) == "" and it["rarity"] != "common" and DB.SETS.has(boss_id) and rng.randf() < DB.SET_CHANCE:
		it["set"] = boss_id
		# A set piece wears the set's own look, and is named for it.
		it["name"] = GearDB.base_name(it)
	return it
