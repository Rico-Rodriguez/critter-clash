extends "res://src/autoload/game_items.gd"
## Game, part 3: heroes. Upgrades, the stats a hero takes into a hunt,
## talents and the power score.


# --- Upgrades -----------------------------------------------------------------

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
	var sk := skill_levels(id)
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
