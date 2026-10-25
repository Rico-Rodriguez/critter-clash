extends "res://src/autoload/game_items.gd"
## Game, part 3: heroes. Upgrades, the stats a hero takes into a hunt,
## talents and the power score.


# --- Super ranks --------------------------------------------------------------

func super_rank(id: String) -> int:
	return int(hero(id).get("super_rank", 0))


## Whether `id` has its super yet (combat level, or the Trophy Road).
func super_unlocked(id: String) -> bool:
	return combat_level(id) >= int(DB.SUPER_UNLOCK["level"]) or int(data.get("renown", 0)) >= int(DB.SUPER_UNLOCK["trophies"])


## The next rank's price, or {} at max rank.
func super_rank_cost(id: String) -> Dictionary:
	var r := super_rank(id)
	return {} if r >= DB.SUPER_RANKS.size() else DB.SUPER_RANKS[r]


func can_buy_super_rank(id: String) -> bool:
	var c := super_rank_cost(id)
	return hero(id)["unlocked"] and not c.is_empty() and int(hero(id)["shards"]) >= int(c["shards"]) and gold() >= int(c["gold"])


func buy_super_rank(id: String) -> bool:
	if not can_buy_super_rank(id):
		return false
	var c := super_rank_cost(id)
	hero(id)["shards"] = int(hero(id)["shards"]) - int(c["shards"])
	data["gold"] = gold() - int(c["gold"])
	hero(id)["super_rank"] = super_rank(id) + 1
	save()
	return true


# --- XP lamps -----------------------------------------------------------------

## XP one lamp adds to skill `s` of hero `id` at its current level.
func lamp_xp(id: String, s: String) -> int:
	return DB.LAMP_SHARDS * DB.LAMP_XP * skill_level(s, id)


func can_rub_lamp(id: String) -> bool:
	return hero(id)["unlocked"] and int(hero(id)["shards"]) >= DB.LAMP_SHARDS


func rub_lamp(id: String, s: String) -> bool:
	if not can_rub_lamp(id) or not s in DB.STYLE_SKILLS[DB.HEROES[id]["skill"]]:
		return false
	var xp := lamp_xp(id, s)
	hero(id)["shards"] = int(hero(id)["shards"]) - DB.LAMP_SHARDS
	skills(id)[s] = mini(skill_xp(s, id) + xp, 200000000)
	save()
	return true


# --- Hero stats ----------------------------------------------------------

## The hero's numbers before in-hunt cards: base, skills, gear.
## `preview` maps a slot to a bag item to try there instead of what is worn
## (the gear screen shows the change before you commit).
func hero_stats(id: String, preview := {}) -> Dictionary:
	var h: Dictionary = DB.HEROES[id]
	var sk := skill_levels(id)
	var s := {
		"hp": h["hp"], "dmg": h["dmg"], "rate": h["rate"], "speed": h["speed"],
		"range": h["range"], "crit": 0.05, "armor": h["armor"], "regen": 0.0, "gold": 1.0,
		"arc": h.get("arc", 0.0), "splash": h.get("splash", 0.0), "proj_speed": h.get("proj_speed", 0.0),
		"style": h["style"], "cards": [], "dash": 0.0, "super": 0.0, "xp": 0.0, "flags": {},
	}
	# The weapon's family decides how the hero swings.
	var fam := weapon_family(id, preview)
	s["family"] = fam
	if fam != "":
		var fd: Dictionary = DB.FAMILIES[fam]
		s["dmg"] *= float(fd["dmg"])
		s["rate"] *= float(fd["rate"])
		s["range"] *= float(fd["range"])
		s["arc"] = float(fd["arc"])
		s["splash"] *= float(fd.get("splash", 1.0))
		s["proj_speed"] *= float(fd.get("pspeed", 1.0))
	# Skills are the hero's power. Ranged and Magic do Attack's and Strength's
	# jobs both.
	var dmg_sk: String = {"melee": "strength", "ranged": "ranged", "magic": "magic"}[h["skill"]]
	var spd_sk: String = "attack" if h["skill"] == "melee" else dmg_sk
	s["dmg"] *= DB.skill_mult(sk[dmg_sk])
	s["rate"] *= 1.0 + DB.SKILL_SPEED * (sk[spd_sk] - 1)
	s["hp"] *= DB.skill_mult(sk["hitpoints"], 10)
	s["armor"] += DB.SKILL_ARMOR * (sk["defence"] - 1)
	# Gear.
	# A two-handed weapon tried on takes the shield off (Game.equip does the same).
	var w: Dictionary = preview["weapon"] if preview.has("weapon") else equipped(id, "weapon")
	var no_off := two_hands(id, w)
	for slot in DB.SLOTS:
		var it: Dictionary = preview[slot] if preview.has(slot) else equipped(id, slot)
		if it.is_empty() or slot == "trinket" and no_off:
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


## The family of the weapon a hero holds, or "" for a hero without families.
## A weapon from before families fights as the hero's first.
func weapon_family(id: String, preview := {}) -> String:
	var fams: Array = DB.HERO_FAMILIES.get(id, [])
	if fams.is_empty():
		return ""
	var w: Dictionary = preview["weapon"] if preview.has("weapon") else equipped(id, "weapon")
	var f := str(w.get("fam", ""))
	return f if f in fams else str(fams[0])


# --- Talents -------------------------------------------------------------

func talents(id: String) -> Array:
	return hero(id).get("talents", [])


## Points earned: one per few combat levels.
func talent_earned(id: String) -> int:
	return mini(DB.TALENT_MAX, (combat_level(id) - 3) / DB.TALENT_COMBAT_STEP)


func talent_points(id: String) -> int:
	return talent_earned(id) - talents(id).size()


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


## The first reset per hero is free; after that it costs gold per point earned.
func respec_cost(id: String) -> int:
	return 0 if bool(hero(id).get("free_respec", true)) else DB.RESPEC_GOLD * (talent_earned(id) + 1)


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
