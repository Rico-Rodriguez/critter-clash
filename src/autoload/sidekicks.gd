extends RefCounted
## Sidekick rules on the save data: owning, the one active slot, bond kills,
## eggs and unlocks, and the migration from pets and the hero ally. Static
## functions on the save dictionary so tests can drive them directly.
## Preload by path: `const SK := preload("res://src/autoload/sidekicks.gd")`.

const SDB := preload("res://src/data/sidekick_db.gd")


## The save block. `owned`: {id: {"kills": int}}; `eggs`: {egg_id: {"kills"}}
## held and warming; `dry`: {egg_id: wins without a drop}; `chests`: chests
## opened (the Mimic's goal); `migrated`: pets and ally folded in.
static func fresh() -> Dictionary:
	return {"active": "", "owned": {}, "eggs": {}, "dry": {}, "chests": 0, "seen": [], "migrated": false}


static func block(d: Dictionary) -> Dictionary:
	if not (d.get("sidekicks") is Dictionary):
		d["sidekicks"] = fresh()
	var b: Dictionary = d["sidekicks"]
	for k in fresh():
		if not b.has(k):
			b[k] = fresh()[k]
	return b


## Pets and the hero ally from before sidekicks, folded in once (safe to run
## on every load: the `migrated` flag stops a second pass, so no save version
## is needed). Boss pets become sidekicks, the followed pet is the one at your
## side, and the hero ally is gone (co-op partners are unaffected).
static func migrate(d: Dictionary) -> void:
	var b := block(d)
	if bool(b["migrated"]):
		return
	var pets: Array = d.get("pets", []) if d.get("pets") is Array else []
	for pid in pets:
		var sid := str(SDB.PET_TO_SIDEKICK.get(str(pid), ""))
		if sid != "":
			own(d, sid)
	var followed := str(SDB.PET_TO_SIDEKICK.get(str(d.get("pet", "")), ""))
	if followed != "" and is_owned(d, followed):
		b["active"] = followed
	d["ally"] = ""
	check_unlocks(d)
	b["migrated"] = true


static func is_owned(d: Dictionary, id: String) -> bool:
	return block(d)["owned"].has(id)


## Adds a sidekick. The first one owned goes straight to your side.
static func own(d: Dictionary, id: String) -> bool:
	if not SDB.ROSTER.has(id) or is_owned(d, id):
		return false
	var b := block(d)
	b["owned"][id] = {"kills": 0}
	if str(b["active"]) == "":
		b["active"] = id
	return true


static func active(d: Dictionary) -> String:
	var a := str(block(d)["active"])
	return a if is_owned(d, a) else ""


## "" sends the sidekick home (no one at your side).
static func set_active(d: Dictionary, id: String) -> bool:
	if id != "" and not is_owned(d, id):
		return false
	block(d)["active"] = id
	return true


static func kills(d: Dictionary, id: String) -> int:
	if not is_owned(d, id):
		return 0
	return int(block(d)["owned"][id].get("kills", 0))


static func bond(d: Dictionary, id: String) -> int:
	return SDB.bond_level(kills(d, id))


static func evolved(d: Dictionary, id: String) -> bool:
	return bond(d, id) >= SDB.BOND_EVOLVE


## Unlocks by plain goals (boss kills, trophies, chests). Returns ids gained.
static func check_unlocks(d: Dictionary) -> Array:
	var out := []
	var b := block(d)
	var st: Dictionary = d.get("stats", {})
	for id: String in SDB.ORDER:
		if is_owned(d, id):
			continue
		var u: Dictionary = SDB.ROSTER[id]["unlock"]
		var got := false
		match str(u["kind"]):
			"boss_kills":
				got = int(st.get("boss_kills", 0)) >= int(u["n"])
			"renown":
				got = int(d.get("renown", 0)) >= int(u["n"])
			"chests":
				got = int(b["chests"]) >= int(u["n"])
			"pet":
				got = (d.get("pets", []) as Array).has(str(u["unique"])) if d.get("pets") is Array else false
		if got and own(d, id):
			out.append(id)
	return out


## A chest was opened: counts toward the Gilded Mimic.
static func note_chest(d: Dictionary) -> Array:
	var b := block(d)
	b["chests"] = int(b["chests"]) + 1
	return check_unlocks(d)


## Progress toward a locked sidekick, for the sheet: [text, fill 0..1].
static func progress(d: Dictionary, id: String) -> Array:
	var u: Dictionary = SDB.ROSTER[id]["unlock"]
	var b := block(d)
	var st: Dictionary = d.get("stats", {})
	match str(u["kind"]):
		"boss_kills":
			return ["Slay a boss", clampf(float(st.get("boss_kills", 0)) / float(u["n"]), 0.0, 1.0)]
		"renown":
			return ["Trophy Road %s / %s" % [int(d.get("renown", 0)), int(u["n"])], clampf(float(d.get("renown", 0)) / float(u["n"]), 0.0, 1.0)]
		"chests":
			return ["Open chests %d / %d" % [int(b["chests"]), int(u["n"])], clampf(float(b["chests"]) / float(u["n"]), 0.0, 1.0)]
		"pet":
			return [str(SDB.ROSTER[id]["how"]), 0.0]
		"egg":
			var eid := str(u["egg"])
			var e: Dictionary = SDB.EGGS[eid]
			if b["eggs"].has(eid):
				var k := int(b["eggs"][eid]["kills"])
				return ["%s hatching %d / %d" % [e["name"], k, int(e["kills"])], clampf(float(k) / float(e["kills"]), 0.0, 1.0)]
			return [str(SDB.ROSTER[id]["how"]), 0.0]
	return ["", 0.0]


## A hidden sidekick shows as ??? until its egg is found.
static func hidden(d: Dictionary, id: String) -> bool:
	if not bool(SDB.ROSTER[id].get("hidden", false)) or is_owned(d, id):
		return false
	var u: Dictionary = SDB.ROSTER[id]["unlock"]
	return not (str(u.get("kind", "")) == "egg" and block(d)["eggs"].has(str(u["egg"])))


## Applies a finished hunt: bond kills to the sidekick at your side, warmth to
## held eggs (hatching any that are ready), egg drops, and goal unlocks.
## Returns {id, kills, bond_from, bond_to, evolved, egg, hatched [], unlocked []}.
static func after_hunt(d: Dictionary, r: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var b := block(d)
	var out := {"id": "", "kills": 0, "bond_from": 0, "bond_to": 0, "evolved": false, "egg": "", "hatched": [], "unlocked": []}
	var k := maxi(int(r.get("kills", 0)), 0)
	var a := active(d)
	if a != "" and k > 0:
		var before := bond(d, a)
		b["owned"][a]["kills"] = kills(d, a) + k
		out["id"] = a
		out["kills"] = k
		out["bond_from"] = before
		out["bond_to"] = bond(d, a)
		out["evolved"] = before < SDB.BOND_EVOLVE and int(out["bond_to"]) >= SDB.BOND_EVOLVE
	# Eggs warm with every kill, then hatch.
	for eid: String in b["eggs"].keys():
		var e: Dictionary = b["eggs"][eid]
		e["kills"] = int(e["kills"]) + k
		if int(e["kills"]) >= int(SDB.EGGS[eid]["kills"]):
			b["eggs"].erase(eid)
			var sid := str(SDB.EGGS[eid]["hatches"])
			if own(d, sid):
				out["hatched"].append(sid)
	# Egg drops on a win (or a boss felled in the Descent).
	if r.get("win", false) or not (r.get("bosses", []) as Array).is_empty():
		for eid: String in SDB.EGGS:
			var e: Dictionary = SDB.EGGS[eid]
			if is_owned(d, str(e["hatches"])) or b["eggs"].has(eid):
				continue
			var eligible := false
			if e.has("boss"):
				eligible = (r.get("bosses", []) as Array).has(str(e["boss"]))
			elif e.has("zone"):
				eligible = r.get("win", false) and str(r.get("zone", "")) == str(e["zone"])
			if not eligible:
				continue
			var dry := int(b["dry"].get(eid, 0))
			if dry + 1 >= int(e["pity"]) or rng.randf() < float(e["chance"]):
				b["eggs"][eid] = {"kills": 0}
				b["dry"][eid] = 0
				out["egg"] = eid
			else:
				b["dry"][eid] = dry + 1
	out["unlocked"] = check_unlocks(d)
	return out
