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
		"sp": {}, "always": [], "never": [],
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
	s["armor"] = clampf(s["armor"], 0.0, 2.0)
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

## Ranks learned since the tree was last opened, per hero and build: these
## refund for free (Diablo IV's unconfirmed points). Not saved.
var _fresh_ranks := {}


## The hero's saved talent builds: {build, builds: [{ranks: {key: n}, picks: {key: i}}, ...]}.
func talent_tree(id: String) -> Dictionary:
	var h := hero(id)
	if not (h.get("tree") is Dictionary):
		h["tree"] = {}
	var t: Dictionary = h["tree"]
	if not (t.get("builds") is Array):
		t["builds"] = []
	while t["builds"].size() < DB.TALENT_BUILDS:
		t["builds"].append({"ranks": {}, "picks": {}})
	t["build"] = clampi(int(t.get("build", 0)), 0, DB.TALENT_BUILDS - 1)
	return t


func talent_build(id: String) -> int:
	return int(talent_tree(id)["build"])


## The build in use: {ranks, picks}.
func _talents(id: String) -> Dictionary:
	var b: Dictionary = talent_tree(id)["builds"][talent_build(id)]
	for k in ["ranks", "picks"]:
		if not (b.get(k) is Dictionary):
			b[k] = {}
	return b


## Switch builds: free, and each build keeps its own spent points.
func set_talent_build(id: String, b: int) -> void:
	talent_tree(id)["build"] = clampi(b, 0, DB.TALENT_BUILDS - 1)
	save()


func talent_rank(id: String, path: int, idx: int) -> int:
	return int(_talents(id)["ranks"].get(TalentDB.key(path, idx), 0))


func has_talent(id: String, path: int, idx: int) -> bool:
	return talent_rank(id, path, idx) > 0


## The option taken on a choice node, or -1.
func talent_pick(id: String, path: int, idx: int) -> int:
	return int(_talents(id)["picks"].get(TalentDB.key(path, idx), -1)) if has_talent(id, path, idx) else -1


## Points earned: one per few combat levels.
func talent_earned(id: String) -> int:
	return clampi((combat_level(id) - 3) / DB.TALENT_COMBAT_STEP, 0, DB.TALENT_MAX)


func talent_spent(id: String) -> int:
	var n := 0
	for k in _talents(id)["ranks"]:
		n += int(_talents(id)["ranks"][k])
	return n


func talent_points(id: String) -> int:
	return maxi(talent_earned(id) - talent_spent(id), 0)


## Points in `path`, counting only rows above `below_row`.
func path_points(id: String, path: int, below_row := 99, ranks := {}) -> int:
	var rs: Dictionary = ranks if not ranks.is_empty() else _talents(id)["ranks"]
	var n := 0
	for k: String in rs:
		var parts := k.split(".")
		if int(parts[0]) == path and TalentDB.valid(id, path, int(parts[1])) and TalentDB.row(int(parts[1])) < below_row:
			n += int(rs[k])
	return n


func row_open(id: String, path: int, row: int) -> bool:
	return path_points(id, path, row) >= int(TalentDB.GATES[row])


## The keystone in use ("path.index"), or "".
func keystone(id: String) -> String:
	var rs: Dictionary = _talents(id)["ranks"]
	for k: String in rs:
		var parts := k.split(".")
		if int(rs[k]) > 0 and TalentDB.valid(id, int(parts[0]), int(parts[1])) and TalentDB.node(id, int(parts[0]), int(parts[1]))["k"] == "k":
			return k
	return ""


## A rank can be learned with a point to spend, its row open, below its max,
## and (for a keystone) no other keystone taken.
func can_learn(id: String, path: int, idx: int) -> bool:
	if not TalentDB.valid(id, path, idx) or talent_points(id) <= 0:
		return false
	var n := TalentDB.node(id, path, idx)
	if talent_rank(id, path, idx) >= TalentDB.max_rank(n) or not row_open(id, path, TalentDB.row(idx)):
		return false
	var ks := keystone(id)
	return n["k"] != "k" or ks == "" or ks == TalentDB.key(path, idx)


## `pick` is the option for a choice node.
func learn_talent(id: String, path: int, idx: int, pick := 0) -> bool:
	if not can_learn(id, path, idx):
		return false
	var b := _talents(id)
	var k := TalentDB.key(path, idx)
	b["ranks"][k] = talent_rank(id, path, idx) + 1
	if TalentDB.node(id, path, idx)["k"] == "c":
		b["picks"][k] = clampi(pick, 0, 1)
	var fk := "%s/%d" % [id, talent_build(id)]
	if not _fresh_ranks.has(fk):
		_fresh_ranks[fk] = {}
	_fresh_ranks[fk][k] = int(_fresh_ranks[fk].get(k, 0)) + 1
	save()
	return true


## Opening the tree confirms what was learned before: from now on it costs
## gold to refund.
func talents_opened(id: String) -> void:
	for b in DB.TALENT_BUILDS:
		_fresh_ranks.erase("%s/%d" % [id, b])


func refund_cost(id: String, path: int, idx: int) -> int:
	var fresh: Dictionary = _fresh_ranks.get("%s/%d" % [id, talent_build(id)], {})
	return 0 if int(fresh.get(TalentDB.key(path, idx), 0)) > 0 else DB.TALENT_REFUND_GOLD


## Every learned rank still has its row open with `ranks` (after a refund).
func _rows_hold(id: String, ranks: Dictionary) -> bool:
	for k: String in ranks:
		var parts := k.split(".")
		var p := int(parts[0])
		var i := int(parts[1])
		if int(ranks[k]) > 0 and TalentDB.valid(id, p, i) and path_points(id, p, TalentDB.row(i), ranks) < int(TalentDB.GATES[TalentDB.row(i)]):
			return false
	return true


## A rank can be refunded if it is gold enough and no higher row needs it.
func can_refund(id: String, path: int, idx: int) -> bool:
	var r := talent_rank(id, path, idx)
	if r <= 0 or gold() < refund_cost(id, path, idx):
		return false
	var after: Dictionary = _talents(id)["ranks"].duplicate()
	after[TalentDB.key(path, idx)] = r - 1
	# path_points reads an empty dict as "the saved one", so an emptied tree is fine.
	return after.values().all(func(v): return int(v) <= 0) or _rows_hold(id, after)


func refund_talent(id: String, path: int, idx: int) -> bool:
	if not can_refund(id, path, idx):
		return false
	data["gold"] = gold() - refund_cost(id, path, idx)
	var b := _talents(id)
	var k := TalentDB.key(path, idx)
	var fresh: Dictionary = _fresh_ranks.get("%s/%d" % [id, talent_build(id)], {})
	if int(fresh.get(k, 0)) > 0:
		fresh[k] = int(fresh[k]) - 1
	var r := talent_rank(id, path, idx) - 1
	if r <= 0:
		b["ranks"].erase(k)
		b["picks"].erase(k)
	else:
		b["ranks"][k] = r
	save()
	return true


## The first reset per hero is free; after that it costs what refunding every
## rank would.
func respec_cost(id: String) -> int:
	return 0 if bool(hero(id).get("free_respec", true)) else DB.TALENT_REFUND_GOLD * talent_spent(id)


func respec(id: String) -> bool:
	var c := respec_cost(id)
	if gold() < c or talent_spent(id) == 0:
		return false
	data["gold"] = gold() - c
	hero(id)["free_respec"] = false
	var b := _talents(id)
	b["ranks"] = {}
	b["picks"] = {}
	_fresh_ranks.erase("%s/%d" % [id, talent_build(id)])
	save()
	return true


func _apply_talents(id: String, s: Dictionary) -> void:
	var rs: Dictionary = _talents(id)["ranks"]
	for k: String in rs:
		var parts := k.split(".")
		var p := int(parts[0])
		var i := int(parts[1])
		if not TalentDB.valid(id, p, i):
			continue
		_apply_talent(s, TalentDB.effects(TalentDB.node(id, p, i), int(rs[k]), maxi(talent_pick(id, p, i), 0)))
	var paths := TalentDB.paths(id)
	for p in paths.size():
		var pts := path_points(id, p)
		if pts > 0:
			var a: Dictionary = paths[p]["attune"]
			_apply_talent(s, {str(a["stat"]): float(a["per"]) * pts} if str(a["stat"]) != "critdmg" else {"flags": {"critdmg": float(a["per"]) * pts}})


func _apply_talent(s: Dictionary, n: Dictionary) -> void:
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
		# Crit damage adds up across nodes; the other rules take the strongest.
		var v := float(n["flags"][f])
		s["flags"][f] = float(s["flags"].get(f, 0.0)) + v if f == "critdmg" else maxf(float(s["flags"].get(f, 0.0)), v)
	for k: String in n.get("sp", {}):
		s["sp"][k] = float(s["sp"].get(k, 0.0)) + float(n["sp"][k])
	for k in ["always", "never"]:
		for c in n.get(k, []):
			s[k].append(c)


## One number for the roster: roughly damage per second times survivability.
func power_score(id: String) -> int:
	var s := hero_stats(id)
	return int(round(s["dmg"] * s["rate"] * 4.0 + s["hp"] * (1.0 + s["armor"]) * 0.5))
