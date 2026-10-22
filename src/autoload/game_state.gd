extends Node
## The profile (part 1 of the Game autoload, see game.gd): the save data,
## saving, and the plain accessors every screen reads.

signal changed

const SAVE_PATH := "user://barrowfall_save.json"
const SAVE_VERSION := 6
const INVENTORY_CAP := 48

var data: Dictionary = {}
var rng := RandomNumberGenerator.new()
## Set by the capture harness and tests: never touch the disk.
var memory_only := false


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


# --- Dates --------------------------------------------------------------------

func today() -> String:
	return Time.get_date_string_from_system()


func _day_offset(days: int) -> String:
	return Time.get_date_string_from_unix_time(int(Time.get_unix_time_from_system()) + days * 86400)
