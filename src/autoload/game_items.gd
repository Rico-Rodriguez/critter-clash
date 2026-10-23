extends "res://src/autoload/game_state.gd"
## Game, part 2: gear. Gear is a collection: one copy of each piece (a set,
## slot and weapon family), unlocked by its first drop. Later drops are
## copies, and copies plus gold level a piece up. Equipping, rolls, glows
## and skins, and gear sets.


# --- Collection and equipping -------------------------------------------------

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


## Returns the slot it had to empty ("trinket" when a two-handed weapon
## goes on, "weapon" when a shield goes on over one), or "".
func equip(hero_id_: String, uid: int) -> String:
	var it := item(uid)
	if it.is_empty() or wear_block(hero_id_, it) != "":
		return ""
	var prev := owner_of(uid)
	if prev != "":
		hero(prev)["gear"].erase(it["slot"])
	var gear: Dictionary = hero(hero_id_)["gear"]
	gear[it["slot"]] = uid
	var bumped := ""
	if it["slot"] == "weapon" and two_hands(hero_id_, it) and gear.has("trinket"):
		bumped = "trinket"
	elif it["slot"] == "trinket" and two_hands(hero_id_, equipped(hero_id_, "weapon")):
		bumped = "weapon"
	if bumped != "":
		gear.erase(bumped)
	_note_tier(hero_id_, it)
	save()
	return bumped


## Whether weapon `w` takes both of the hero's hands, as in OSRS: no shield
## can be worn with it. Only shields are barred; a quiver or a floating
## grimoire needs no hand. A weapon from before families fights as the
## hero's first family (Game.weapon_family).
func two_hands(id: String, w: Dictionary) -> bool:
	if w.is_empty() or w.get("slot", "weapon") != "weapon" or not bool(GearDB.LINES[id].get("shield", false)):
		return false
	var fams: Array = DB.HERO_FAMILIES.get(id, [])
	var f := str(w.get("fam", ""))
	return GearDB.two_handed(id, f if f in fams else (str(fams[0]) if not fams.is_empty() else ""))


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
			# Weapons go on first: a two-handed one leaves the offhand empty.
			if slot == "trinket" and two_hands(hero_id_, equipped(hero_id_, "weapon")):
				continue
			if item_score(it) > best_score:
				best = it
				best_score = item_score(it)
		if slot == "trinket" and two_hands(hero_id_, equipped(hero_id_, "weapon")):
			if hero(hero_id_)["gear"].has("trinket"):
				hero(hero_id_)["gear"].erase("trinket")
				changed_n += 1
			continue
		if not best.is_empty() and int(hero(hero_id_)["gear"].get(slot, 0)) != int(best["uid"]):
			hero(hero_id_)["gear"][slot] = int(best["uid"])
			_note_tier(hero_id_, best)
			changed_n += 1
	if changed_n > 0:
		save()
	return changed_n


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
	if it.has("fam") and source == "boss":
		it["fam"] = roll_family(cls, mat, tier_i)
		it["name"] = gear_name(it)
	return it


## A piece of a hero's line at level 1. Rarity no longer shapes a piece (a
## piece is the same whoever finds it); it only decides, on a roll, whether a
## drop is a unique.
func make_item(cls: String, slot: String, mat: int, _rarity := "rare") -> Dictionary:
	var it := {"uid": 0, "slot": slot, "rarity": "rare", "name": "", "stats": {}, "unique": "", "cls": cls, "mat": mat, "look": 0, "lv": 1, "cards": 0}
	if slot == "weapon" and DB.HERO_FAMILIES.has(cls):
		it["fam"] = roll_family(cls, mat)
	it["stats"] = piece_stats(it)
	it["name"] = gear_name(it)
	return it


## A piece's stats at its level: its slot's main stat and its set's second
## stat (DB.SET_STAT), at the middle of their rolls. A unique keeps its own
## numbers; both grow DB.PIECE_LV_STAT a level.
func piece_stats(it: Dictionary) -> Dictionary:
	var lv := clampi(int(it.get("lv", 1)), 1, DB.PIECE_MAX_LV)
	var u := str(it.get("unique", ""))
	var out := {}
	if u != "" and DB.UNIQUES.has(u):
		var base: Dictionary = DB.UNIQUES[u].get("stats", {})
		for k in base:
			out[k] = _grown(int(base[k]), lv)
		return out
	var mat := clampi(int(it.get("mat", 0)), 0, GearDB.TIERS - 1)
	var scale_ := 1.0 + DB.MAT_STAT * mat
	var main: String = DB.SLOT_MAIN[str(it["slot"])]
	out[main] = _grown(_mid_affix(main, scale_), lv)
	var second: String = DB.SET_STAT[mat]
	if second != "" and second != main:
		out[second] = _grown(maxi(1, int(round(_mid_affix(second, scale_) * 0.6))), lv)
	return out


## A level-1 stat at `lv`: DB.PIECE_LV_STAT more a level, and never less
## than +1 a level, so a small stat (armor 8) still moves every level.
func _grown(v: int, lv: int) -> int:
	return v + maxi(lv - 1, int(round(v * DB.PIECE_LV_STAT * (lv - 1))))


func _mid_affix(key: String, mult: float) -> int:
	var r: Array = DB.AFFIXES[key]["roll"]
	# What a two-bonus (rare) roll used to average.
	return int(round((float(r[0]) + float(r[1])) * 0.5 * 1.7 * mult))


## A weapon family for a drop of set `mat`: one that comes in that set, and a
## boss-only family only from a boss on a hard enough tier (`tier_i` -1 for
## a drop that is not a boss's).
func roll_family(cls: String, mat: int, tier_i := -1) -> String:
	var pool := []
	for f: String in DB.HERO_FAMILIES[cls]:
		var fd: Dictionary = DB.FAMILIES[f]
		if mat >= int(fd["min_set"]) and (not fd.has("boss_from") or tier_i >= int(fd["boss_from"])):
			pool.append(f)
	return str(pool[rng.randi() % pool.size()])


## What a piece is called: its set and kind ("Bloodiron Scythe"). Uniques
## keep their own names.
func gear_name(it: Dictionary) -> String:
	if str(it.get("unique", "")) != "":
		return str(it["name"])
	return GearDB.base_name(it)


## "Bloodiron · Lv 3 · Weapon", plus a boss set or Unique: what a piece is,
## in words, without a power number.
func item_tag(it: Dictionary, with_slot := true) -> String:
	var parts := [GearDB.material_name(str(it.get("cls", "")), int(it.get("mat", 0))), "Lv %d" % int(it.get("lv", 1))]
	if it.get("dupe", false):
		parts.push_front("Copy")
	if str(it.get("unique", "")) != "":
		parts.append("Unique")
	var st := item_set(it)
	if st != "":
		parts.append("%s set" % DB.SETS[st]["short"])
	if with_slot:
		parts.append(str(DB.SLOT_NAME[it["slot"]]))
	return " · ".join(parts)


func make_unique(u: String) -> Dictionary:
	var ud: Dictionary = DB.UNIQUES[u]
	return {"uid": 0, "slot": ud["slot"], "rarity": ud["rarity"], "name": ud["name"], "stats": ud.get("stats", {}).duplicate(), "unique": u, "cls": ud.get("cls", "knight"), "mat": GearDB.TIERS - 1, "fam": ud.get("fam", ""), "lv": 1, "cards": 0}


## Adds a drop to the collection (or the log / pet / sale for non-gear
## uniques). A piece already owned becomes a copy toward its next level: the
## stored piece comes back with "dupe" set. Returns the stored piece, or {}
## when the drop was not gear.
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
			# Boss pets are sidekicks now.
			SK.check_unlocks(data)
			return {}
		if ud["slot"] == "trophy":
			data["gold"] = gold() + int(ud.get("sell", 0))
			return {}
	var have := owned(it)
	if not have.is_empty():
		have["cards"] = int(have.get("cards", 0)) + 1
		var back := have.duplicate(true)
		back["dupe"] = true
		return back
	it["lv"] = 1
	it["cards"] = 0
	it["look"] = 0
	it["stats"] = piece_stats(it)
	it["name"] = gear_name(it)
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

## What makes a piece the same piece: hero, slot, set, family, boss set
## and unique. Two drops with one key are one piece and its copy.
func piece_key(it: Dictionary) -> String:
	return "%s|%s|%d|%s|%s|%s" % [it.get("cls", ""), it["slot"], int(it.get("mat", 0)), str(it.get("fam", "")), str(it.get("set", "")), str(it.get("unique", ""))]


## The owned piece that `it` is a copy of ({} if none).
func owned(it: Dictionary) -> Dictionary:
	var k := piece_key(it)
	for p in data["items"]:
		if piece_key(p) == k:
			return p
	return {}


## Why a piece can't level up now ("" when it can).
func level_block(it: Dictionary) -> String:
	if int(it.get("lv", 1)) >= DB.PIECE_MAX_LV:
		return "Max level"
	var c := DB.level_cost(it)
	if int(it.get("cards", 0)) < int(c["cards"]):
		return "Needs %d copies" % int(c["cards"])
	if gold() < int(c["gold"]):
		return "Not enough gold"
	return ""


func level_up(uid: int) -> bool:
	var it := item(uid)
	if it.is_empty() or level_block(it) != "":
		return false
	var c := DB.level_cost(it)
	it["cards"] = int(it["cards"]) - int(c["cards"])
	data["gold"] = gold() - int(c["gold"])
	it["lv"] = int(it.get("lv", 1)) + 1
	it["stats"] = piece_stats(it)
	save()
	return true


## Pieces with copies and gold enough to level (the gear tab's dot).
func levels_ready(hero_id_: String) -> int:
	var n := 0
	for it in data["items"]:
		if str(it.get("cls", "")) == hero_id_ and level_block(it) == "":
			n += 1
	return n


## Every piece a hero can collect in a slot, as rows for the armory: one row
## per weapon family (or one row of sets), each set in its column (a {} where
## a family has no piece of that set), then a row of the boss-set and unique
## pieces owned. Owned pieces are the stored ones; the rest are level-1
## stand-ins with uid 0.
func catalog(cls: String, slot: String) -> Array:
	var rows := []
	var fams: Array = DB.HERO_FAMILIES.get(cls, []) if slot == "weapon" else []
	for f in (fams if not fams.is_empty() else [""]):
		var row := []
		for mat in GearDB.TIERS:
			var fd: Dictionary = DB.FAMILIES.get(f, {})
			if mat < int(fd.get("min_set", 0)):
				row.append({})
				continue
			var it := {"uid": 0, "slot": slot, "rarity": "rare", "name": "", "stats": {}, "unique": "", "cls": cls, "mat": mat, "look": 0, "lv": 1, "cards": 0}
			if f != "":
				it["fam"] = f
			var have := owned(it)
			if have.is_empty():
				it["stats"] = piece_stats(it)
				it["name"] = gear_name(it)
				row.append(it)
			else:
				row.append(have)
		rows.append(row)
	var extra := []
	for it in data["items"]:
		if str(it.get("cls", "")) == cls and it["slot"] == slot and (str(it.get("unique", "")) != "" or str(it.get("set", "")) != ""):
			extra.append(it)
	if not extra.is_empty():
		rows.append(extra)
	return rows


## Where a piece not yet found comes from, in words.
func drop_hint(it: Dictionary) -> String:
	var fd: Dictionary = DB.FAMILIES.get(str(it.get("fam", "")), {})
	if fd.has("boss_from"):
		return "Drops from %s bosses and up" % str(DB.TIERS[int(fd["boss_from"])]["name"])
	var mat := int(it.get("mat", 0))
	for i in DB.TIERS.size():
		# A drop can land one set above its difficulty's.
		if int(DB.TIERS[i]["mat"]) >= mat - 1:
			return "Drops on %s and up" % str(DB.TIERS[i]["name"])
	return ""


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


## What a weapon skin costs now: one place, so a shop sale can change it.
func skin_price(skin: String) -> int:
	return int(DB.WEAPON_SKINS[skin]["gold"])


func buy_skin(id: String, skin: String) -> bool:
	var h := hero(id)
	if skin in h["skins"]:
		h["skin"] = skin
		save()
		return true
	var d: Dictionary = DB.WEAPON_SKINS[skin]
	var cost := skin_price(skin)
	if not id in d["heroes"] or gold() < cost:
		return false
	data["gold"] = gold() - cost
	h["skins"].append(skin)
	h["skin"] = skin
	save()
	return true


func set_skin(id: String, skin: String) -> void:
	if skin == "" or skin in hero(id)["skins"]:
		hero(id)["skin"] = skin
		save()


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
