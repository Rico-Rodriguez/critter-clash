extends Node
## The profile: currencies, heroes, gear, skills, the collection log and
## settings. Saved as JSON in user://. Also the loot and reward rules that
## change the profile (chests, hunt results, item rolls).

signal changed

const SAVE_PATH := "user://barrowfall_save.json"
const SAVE_VERSION := 5
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
	if int(data.get("idle_since", 0)) <= 0:
		data["idle_since"] = int(Time.get_unix_time_from_system())
	Sfx.refresh_volume.call_deferred()


func _fresh() -> Dictionary:
	var heroes := {}
	for id in DB.HERO_ORDER:
		heroes[id] = {"level": 1, "shards": 0, "unlocked": DB.HEROES[id]["unlock"] == "start", "gear": {}, "talents": [],
			"mastery": 0, "mastery_rank": 0, "rating": 0, "rating_paid": 0, "free_respec": true, "glow": "", "glows": [], "best_mat": -1}
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
		## Each mode opens its own difficulties: {mode: highest open tier}.
		## tier_unlocked stays the best across all modes (zones, campfire).
		"mode_tiers": {},
		"tier": 0,
		"pet": "",
		"stats": {"hunts": 0, "wins": 0, "kills": 0, "elites": 0, "boss_kills": 0, "best": {}, "rifts": 0, "best_perfect": 0, "best_tier_won": 0},
		"settings": {"music": 0.7, "sfx": 1.0, "shake": true, "quality": "auto", "camera": "standard", "buttons": "right", "haptics": true},
		"seen_tutorial": false,
		"seen_items": [],
		"bounties": {"day": "", "list": []},
		"zone": "barrow",
		"mode": "horde",
		"renown": 0,
		"road": 0,
		"omen_on": false,
		"clue": {},
		# Retention: first win of the day, the login calendar, the campfire,
		# boss kill counts and dry streaks, rift keys, achievements, the season.
		"daily": {"day": "", "won": false},
		"login": {"last": "", "count": 0},
		"idle_since": 0,
		"kc": {},
		"dry": {},
		"dry_best": {},
		"rift_keys": 0,
		"achievements": {},
		"season": {"id": -1, "xp": 0, "claimed": 0},
		"pets": [],
		"ally": "",
		"tips": {},
	}


func load_save() -> void:
	data = _fresh()
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary and int(parsed.get("version", 0)) in [1, 2, 3, 4, SAVE_VERSION]:
		if int(parsed.get("version", 0)) == 1:
			_migrate_v1(parsed)
		if int(parsed.get("version", 0)) == 2:
			_migrate_v2(parsed)
		if int(parsed.get("version", 0)) == 3:
			_migrate_v3(parsed)
		if int(parsed.get("version", 0)) == 4:
			_migrate_v4(parsed)
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
	d["version"] = 3


## v4 split three difficulty tiers into eight. Old Veteran and Nightmare map
## to their new places, and so do the tier digits in best-time keys.
func _migrate_v3(d: Dictionary) -> void:
	var m: Array = DB.TIER_FROM_V3
	d["tier_unlocked"] = int(m[clampi(int(d.get("tier_unlocked", 0)), 0, 2)])
	d["tier"] = int(m[clampi(int(d.get("tier", 0)), 0, 2)])
	var best: Dictionary = d.get("stats", {}).get("best", {})
	var out := {}
	var re := RegEx.create_from_string("^(t|depths|tdepths|rush|wild)?([0-2])(_.*)?$")
	for k: String in best:
		var mt := re.search(k)
		if mt and not k.begins_with("wildplace"):
			out[mt.get_string(1) + str(m[int(mt.get_string(2))]) + mt.get_string(3)] = best[k]
		else:
			out[k] = best[k]
	if d.has("stats"):
		d["stats"]["best"] = out
	d["version"] = 4


## v5 gives each mode its own unlocked difficulty, rebuilt from the wins the
## save already records (best-time keys carry mode and tier). The Descent
## keeps no per-tier record, so it takes the Horde's.
func _migrate_v4(d: Dictionary) -> void:
	var cap := int(d.get("tier_unlocked", 0))
	var mt := {}
	var re := RegEx.create_from_string("^(t|tdepths|tgrove|depths|grove|rush|rift|wild)?([0-9])(_.*)?$")
	for k: String in d.get("stats", {}).get("best", {}):
		var m := re.search(k)
		if m == null:
			continue
		var pre := m.get_string(1)
		var mode := "horde"
		if pre.begins_with("t"):
			mode = "trial"
		elif pre in ["rush", "rift", "wild"]:
			mode = pre
		mt[mode] = mini(maxi(int(mt.get(mode, 0)), int(m.get_string(2)) + 1), mini(cap, DB.TIERS.size() - 1))
	mt["descent"] = int(mt.get("horde", 0))
	d["mode_tiers"] = mt
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


## Descent and Boss Rush open once you have won on Normal; a rift needs a key.
func mode_unlocked(id: String) -> bool:
	if id == "rift":
		return int(data.get("rift_keys", 0)) > 0
	return not DB.MODES[id].has("unlock") or int(data["tier_unlocked"]) >= 1


func best_depth(hero: String) -> int:
	return int(data["stats"]["best"].get("descent_" + hero, 0))


func set_mode(id: String) -> void:
	if DB.MODES.has(id):
		data["mode"] = id
		save()


func zone_unlocked(id: String) -> bool:
	match id:
		"depths":
			return int(data["tier_unlocked"]) > DB.TIER_VETERAN
		"grove":
			return int(data["tier_unlocked"]) > DB.TIER_VETERAN + 1
	return id == "barrow"


func set_zone(id: String) -> void:
	if DB.ZONES.has(id) and zone_unlocked(id):
		data["zone"] = id
		save()


func tier() -> int:
	return clampi(int(data["tier"]), 0, mode_tier_unlocked())


## The highest difficulty open in a mode (the chosen mode by default).
func mode_tier_unlocked(mode := "") -> int:
	var m := mode if mode != "" else mode_id()
	return mini(int(data["mode_tiers"].get(m, 0)), DB.TIERS.size() - 1)


## Opens the next difficulty in `mode` after tier `t` is beaten there.
## Returns the newly opened tier, or -1.
func _open_mode_tier(mode: String, t: int) -> int:
	if t < mode_tier_unlocked(mode) or t >= DB.TIERS.size() - 1:
		return -1
	data["mode_tiers"][mode] = t + 1
	return t + 1


func set_tier(t: int) -> void:
	data["tier"] = clampi(t, 0, mode_tier_unlocked())
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
	_apply_sets(id, s, preview)
	# Armor is a rating; DB.armor_dr turns it into damage taken, on a curve.
	s["armor"] = minf(s["armor"], 2.0)
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


## The first reset per hero is free; after that it costs gold per level.
func respec_cost(id: String) -> int:
	return 0 if bool(hero(id).get("free_respec", true)) else DB.RESPEC_GOLD * int(hero(id)["level"])


func respec(id: String) -> bool:
	var c := respec_cost(id)
	if gold() < c:
		return false
	data["gold"] = gold() - c
	hero(id)["free_respec"] = false
	hero(id)["talents"] = []
	save()
	return true


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
	var mat := GearDB.roll_mat(int(t["mat"]), bonus + (1 if source == "boss" else 0), rng)
	var it := make_item(cls, slot, mat, rarity)
	# Ancient: Diablo's rare orange-bordered roll, every number 30% higher.
	if tier_i >= DB.ANCIENT_FROM_TIER and rarity == "rare" and rng.randf() < DB.ANCIENT_CHANCE * float(t["loot"]):
		for k in it["stats"]:
			it["stats"][k] = int(round(float(it["stats"][k]) * DB.ANCIENT_MULT))
		it["ancient"] = true
		it["name"] = "Ancient " + str(it["name"])
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
	it["name"] = _item_name(it, rarity)
	return it


func _item_name(it: Dictionary, rarity: String) -> String:
	var base := GearDB.base_name(it)
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


## Applies a finished hunt. `r`: win, tier, hero, gold, xp {skill: amount},
## items [], kills, elites, time. Returns a summary with level-ups.
func finish_hunt(r: Dictionary) -> Dictionary:
	var summary := {"levels": [], "unlocked_tier": -1, "unlocked_hero": "", "items": []}
	# The first win of the day: double gold and a chest one grade better.
	if r.get("win", false) and first_win_ready():
		data["daily"] = {"day": today(), "won": true}
		r["gold"] = int(round(int(r.get("gold", 0)) * (1.0 + DB.FIRST_WIN_GOLD)))
		var grades := ["silver", "gold", "crypt"]
		if str(r.get("chest", "")) in grades:
			r["chest"] = grades[mini(grades.find(str(r["chest"])) + 1, 2)]
		summary["first_win"] = true
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
		if str(r.get("mode", "horde")) != "wild":
			st["boss_kills"] = int(st["boss_kills"]) + 1
		var t := int(r["tier"])
		var key := str(t) if str(r.get("zone", "barrow")) == "barrow" else "%s%d" % [r["zone"], t]
		if str(r.get("mode", "horde")) == "trial":
			key = "t" + key
		elif str(r.get("mode", "horde")) == "rush":
			key = "rush%d_%s" % [t, r["hero"]]
		elif str(r.get("mode", "horde")) == "rift":
			key = "rift%d_%s" % [t, r["hero"]]
		elif str(r.get("mode", "horde")) == "wild":
			key = "wild%d_%s" % [t, r["hero"]]
		var best := float(st["best"].get(key, 0.0))
		if best <= 0.0 or float(r["time"]) < best:
			st["best"][key] = float(r["time"])
		if t >= int(data["tier_unlocked"]) and t < DB.TIERS.size() - 1:
			data["tier_unlocked"] = t + 1
		summary["unlocked_tier"] = _open_mode_tier(str(r.get("mode", "horde")), t)
		if t >= DB.TIER_VETERAN and not hero("barbarian")["unlocked"]:
			hero("barbarian")["unlocked"] = true
			summary["unlocked_hero"] = "barbarian"
	summary["renown"] = _earn_renown(r)
	season()["xp"] = int(season()["xp"]) + int(summary["renown"])
	var hid := str(r.get("hero", hero_id()))
	summary["mastery"] = _gain_mastery(hid, r)
	if str(r.get("mode", "horde")) != "rift":
		summary["rating"] = _gain_rating(hid, r)
	_count_bosses(r)
	st["best_perfect"] = maxi(int(st.get("best_perfect", 0)), int(r.get("perfect", 0)))
	if r.get("win", false):
		st["best_tier_won"] = maxi(int(st.get("best_tier_won", 0)), int(r["tier"]) + 1)
		if str(r.get("mode", "")) == "rift":
			st["rifts"] = int(st.get("rifts", 0)) + 1
	if str(r.get("mode", "")) == "descent" and int(r.get("depth", 1)) >= DB.RIFT_DEPTH:
		data["rift_keys"] = int(data.get("rift_keys", 0)) + 1
		summary["rift_key"] = true
	summary["achievements"] = achievement_claimable()
	summary["clue"] = _clue_progress(r)
	if str(r.get("mode", "horde")) == "wild" and int(r.get("rivals", 0)) > 0:
		var wkey: String = "wildplace_" + str(r["hero"])
		var place := int(r.get("place", 99))
		if int(st["best"].get(wkey, 99)) > place:
			st["best"][wkey] = place
			summary["record"] = true
	if str(r.get("mode", "horde")) == "descent":
		# The Descent never ends in a win: felling its first boss beats the tier.
		if (r.get("bosses", []) as Array).size() > 0:
			var tt := int(r["tier"])
			summary["unlocked_tier"] = _open_mode_tier("descent", tt)
			if tt >= int(data["tier_unlocked"]) and tt < DB.TIERS.size() - 1:
				data["tier_unlocked"] = tt + 1
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
	var old_base := GearDB.base_name(it)
	it["mat"] = mat + 1
	var base := GearDB.base_name(it)
	if str(it["name"]).contains(old_base):
		it["name"] = str(it["name"]).replace(old_base, base)
	else:
		var prefix := str(it["name"]).get_slice(" ", 0) if it["rarity"] != "common" else ""
		it["name"] = base if prefix == "" else "%s %s" % [prefix, base]
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
	var cost := int(DB.GLOWS[glow]["gold"])
	if gold() < cost:
		return false
	data["gold"] = gold() - cost
	h["glows"].append(glow)
	h["glow"] = glow
	save()
	return true


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


# --- Mastery, rating, dailies -----------------------------------------------------

func today() -> String:
	return Time.get_date_string_from_system()


func _day_offset(days: int) -> String:
	return Time.get_date_string_from_unix_time(int(Time.get_unix_time_from_system()) + days * 86400)


func mastery_title(id: String) -> String:
	return str(DB.MASTERY[int(hero(id).get("mastery_rank", 0))]["title"])


## Points to the next rank, or -1 at the top.
func mastery_next(id: String) -> int:
	var r := int(hero(id).get("mastery_rank", 0))
	return -1 if r >= DB.MASTERY.size() - 1 else int(DB.MASTERY[r + 1]["at"])


func _gain_mastery(id: String, r: Dictionary) -> Dictionary:
	var h := hero(id)
	var pts := int(r.get("kills", 0)) / 10 + (40 if r.get("win", false) else 0) + 15 * int(r.get("tier", 0))
	h["mastery"] = int(h.get("mastery", 0)) + pts
	var out := {"gained": pts, "titles": []}
	var rank := DB.mastery_rank(int(h["mastery"]))
	while int(h.get("mastery_rank", 0)) < rank:
		h["mastery_rank"] = int(h.get("mastery_rank", 0)) + 1
		var m: Dictionary = DB.MASTERY[h["mastery_rank"]]
		data["gold"] = gold() + int(m.get("gold", 0))
		h["shards"] = int(h["shards"]) + int(m.get("shards", 0))
		if m.has("glow") and not m["glow"] in h["glows"]:
			h["glows"].append(m["glow"])
		out["titles"].append(str(m["title"]))
	return out


func _gain_rating(id: String, r: Dictionary) -> Dictionary:
	var h := hero(id)
	var before := int(h.get("rating", 0))
	var d := DB.RATING_WIN + DB.RATING_WIN_TIER * int(r.get("tier", 0)) if r.get("win", false) else -DB.RATING_LOSS
	h["rating"] = maxi(before + d, 0)
	var paid := 0
	while int(h["rating"]) >= (int(h.get("rating_paid", 0)) + 1) * DB.RATING_STEP:
		h["rating_paid"] = int(h.get("rating_paid", 0)) + 1
		var g := 150 * int(h["rating_paid"])
		data["gold"] = gold() + g
		h["shards"] = int(h["shards"]) + 5 + int(h["rating_paid"]) * 2
		paid += g
	return {"delta": int(h["rating"]) - before, "rating": int(h["rating"]), "milestone_gold": paid}


## The campfire's gold waiting since the last visit.
func idle_gold() -> int:
	var since := int(data.get("idle_since", 0))
	if since <= 0:
		return 0
	var hours := minf((Time.get_unix_time_from_system() - since) / 3600.0, DB.IDLE_HOURS)
	return int(hours * (DB.IDLE_GOLD_HOUR + DB.IDLE_GOLD_TIER * int(data["tier_unlocked"])))


func claim_idle() -> int:
	var g := idle_gold()
	data["gold"] = gold() + g
	data["idle_since"] = int(Time.get_unix_time_from_system())
	save()
	return g


## The login calendar: {day 1..7 of the streak if claimed now, ready}.
func login_status() -> Dictionary:
	var l: Dictionary = data["login"]
	if str(l["last"]) == today():
		return {"day": (int(l["count"]) - 1) % DB.LOGIN_REWARDS.size() + 1, "ready": false}
	var cont := str(l["last"]) == _day_offset(-1)
	var n := int(l["count"]) + 1 if cont else 1
	return {"day": (n - 1) % DB.LOGIN_REWARDS.size() + 1, "ready": true}


## Pays today's login reward. Returns the reward and, for a chest, its kind.
func claim_login() -> Dictionary:
	var st := login_status()
	if not st["ready"]:
		return {}
	var l: Dictionary = data["login"]
	l["count"] = int(l["count"]) + 1 if str(l["last"]) == _day_offset(-1) else 1
	l["last"] = today()
	var rw: Dictionary = DB.LOGIN_REWARDS[int(st["day"]) - 1]
	data["gold"] = gold() + int(rw.get("gold", 0))
	if rw.has("shards"):
		hero(hero_id())["shards"] = int(hero(hero_id())["shards"]) + int(rw["shards"])
	save()
	return rw


func first_win_ready() -> bool:
	var d: Dictionary = data["daily"]
	return str(d["day"]) != today() or not bool(d["won"])


# --- Kill counts and dry streaks ---------------------------------------------------

func kc(boss_id: String) -> int:
	return int(data["kc"].get(boss_id, 0))


func dry(boss_id: String) -> int:
	return int(data["dry"].get(boss_id, 0))


func _count_bosses(r: Dictionary) -> void:
	var got := {}
	for it in r.get("items", []):
		var u := str(it.get("unique", ""))
		if u != "" and DB.UNIQUES.has(u):
			got[str(DB.SOURCE_BOSS.get(DB.UNIQUES[u]["source"], ""))] = true
	for b: String in r.get("bosses", []):
		data["kc"][b] = kc(b) + 1
		data["dry"][b] = 0 if got.has(b) else dry(b) + 1
		data["dry_best"][b] = maxi(int(data["dry_best"].get(b, 0)), dry(b))


# --- Achievements and the season ----------------------------------------------------

func achievement_value(stat: String) -> int:
	var st: Dictionary = data["stats"]
	match stat:
		"wins", "kills", "elites", "rifts":
			return int(st.get(stat, 0))
		"tier":
			return int(st.get("best_tier_won", 0))
		"depth":
			var best := 0
			for id in DB.HERO_ORDER:
				best = maxi(best, best_depth(id))
			return best
		"perfect":
			return int(st.get("best_perfect", 0))
		"log":
			return data["log"].keys().filter(func(k): return int(data["log"][k]) > 0).size()
		"mastery":
			var m := 0
			for id in DB.HERO_ORDER:
				m = maxi(m, int(hero(id).get("mastery_rank", 0)))
			return m
		"set":
			var best_set := 0
			for id in DB.HERO_ORDER:
				for n in set_counts(id).values():
					best_set = maxi(best_set, int(n))
			return best_set
	if stat.begins_with("kc_"):
		return kc(stat.substr(3))
	return 0


func achievement_done(a: Dictionary) -> bool:
	return achievement_value(str(a["stat"])) >= int(a["n"])


func achievement_claimable() -> int:
	var n := 0
	for a: Dictionary in DB.ACHIEVEMENTS:
		if achievement_done(a) and not data["achievements"].has(a["id"]):
			n += 1
	return n


func claim_achievement(id: String) -> int:
	for a: Dictionary in DB.ACHIEVEMENTS:
		if a["id"] == id and achievement_done(a) and not data["achievements"].has(id):
			data["achievements"][id] = true
			data["gold"] = gold() + int(a["gold"])
			save()
			return int(a["gold"])
	return 0


func season_id() -> int:
	return int(Time.get_unix_time_from_system() / (86400.0 * 7.0 * DB.SEASON_WEEKS))


func season() -> Dictionary:
	var s: Dictionary = data["season"]
	if int(s["id"]) != season_id():
		data["season"] = {"id": season_id(), "xp": 0, "claimed": 0}
	return data["season"]


func season_name() -> String:
	return str(DB.SEASON_NAMES[season_id() % DB.SEASON_NAMES.size()])


## Days left in the current season.
func season_days_left() -> int:
	var span := 86400.0 * 7.0 * DB.SEASON_WEEKS
	var end := (season_id() + 1) * span
	return int(ceil((end - Time.get_unix_time_from_system()) / 86400.0))


func season_level() -> int:
	return mini(int(season()["xp"]) / DB.SEASON_XP, DB.SEASON_TIERS)


func season_claimable() -> int:
	return season_level() - int(season()["claimed"])


## Pays the next season step. Returns {kind, ...} or {} (a chest is opened).
func claim_season() -> Dictionary:
	if season_claimable() <= 0:
		return {}
	var s := season()
	s["claimed"] = int(s["claimed"]) + 1
	var rw := DB.season_reward(int(s["claimed"]))
	match str(rw["kind"]):
		"gold":
			data["gold"] = gold() + int(rw["amount"])
		"shards":
			hero(hero_id())["shards"] = int(hero(hero_id())["shards"]) + int(rw["amount"])
		"chest":
			rw["opened"] = open_chest(str(rw["chest"]))
		"glow":
			for id in DB.HERO_ORDER:
				if not rw["glow"] in hero(id)["glows"]:
					hero(id)["glows"].append(rw["glow"])
	save()
	return rw


## The nearest goal worth chasing, for the camp ("12 shards to level 6").
func next_goal() -> String:
	var id := hero_id()
	var c := upgrade_cost(id)
	if not c.is_empty():
		var need_s := int(c["shards"]) - int(hero(id)["shards"])
		var need_g := int(c["gold"]) - gold()
		if need_s <= 0 and need_g <= 0:
			return "Level %d is ready: upgrade in Heroes" % (int(hero(id)["level"]) + 1)
		if need_s > 0 and need_s <= 30:
			return "%d shards to level %d" % [need_s, int(hero(id)["level"]) + 1]
	var t := mode_tier_unlocked()
	if t < DB.TIERS.size() - 1 and tier() == t:
		return "%s on %s to open %s" % ["Fell a Descent boss" if mode_id() == "descent" else "Win", DB.TIERS[t]["name"], DB.TIERS[t + 1]["name"]]
	var nxt := mastery_next(id)
	if nxt > 0:
		return "%d mastery to %s" % [nxt - int(hero(id)["mastery"]), DB.MASTERY[int(hero(id)["mastery_rank"]) + 1]["title"]]
	return ""
