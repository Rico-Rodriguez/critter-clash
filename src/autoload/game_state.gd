extends Node
## The profile (part 1 of the Game autoload, see game.gd): the save data,
## saving, and the plain accessors every screen reads.

signal changed

const SAVE_PATH := "user://barrowfall_save.json"
const SAVE_VERSION := 9
## Sidekick rules (owning, bond, eggs, migration), shared by every part.
const SK := preload("res://src/autoload/sidekicks.gd")

var data: Dictionary = {}
var rng := RandomNumberGenerator.new()
## Set by the capture harness and tests: never touch the disk.
var memory_only := false


func _fresh() -> Dictionary:
	var heroes := {}
	for id in DB.HERO_ORDER:
		heroes[id] = {"level": 1, "shards": 0, "unlocked": DB.HEROES[id]["unlock"] == "start", "gear": {}, "talents": [],
			"mastery": 0, "mastery_rank": 0, "rating": 0, "rating_paid": 0, "free_respec": true, "glow": "", "glows": [], "skin": "", "skins": [], "outfit": "", "outfits": [], "best_mat": -1, "skills": _fresh_skills()}
	return {
		"version": SAVE_VERSION,
		"gold": 0,
		# Gems: hatch eggs sooner. From chests, the season and spare egg drops.
		"gems": 0,
		"hero": "knight",
		"heroes": heroes,
		"items": [],
		"next_uid": 1,
		# The shared skill XP from before each hero trained their own. Unread,
		# kept so nothing is lost if per-hero skills are ever rolled back.
		"skills": _fresh_skills(),
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
		# Trophies (the name is from before the Trophy Road) and road steps claimed.
		"renown": 0,
		"road": 0,
		# Modes and zones opened on the Trophy Road.
		"unlocks": [],
		# A new save chooses its first hero once, before the first hunt.
		"start_picked": false,
		"omen_on": false,
		# The weekly event: {week, pts, claimed, hunts}; reset when the week turns.
		"event": {"week": -1, "pts": 0, "claimed": 0, "hunts": 0},
		# The story campaign: chapter ids cleared, and the chapter the next hunt plays.
		"story": {"cleared": [], "run": ""},
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
		# Unused since sidekicks replaced the hero ally (kept so old saves load).
		"ally": "",
		"sidekicks": SK.fresh(),
		"tips": {},
		# Today's shop deals, drawn once a day so a gear offer stays the same piece.
		"shop": {"day": "", "deals": []},
		# The player's name, shown on the camp plate, to friends and in clans.
		"profile": {"name": ""},
		# The online account. `key` is this install's secret sign-in id (made
		# on first sign-in, carried to a new phone by a transfer code); the
		# rest mirrors the server so the camp can draw without waiting for it.
		"online": {"key": "", "user_id": "", "clan_id": "", "clan_name": "", "ref_code": "",
			"referred": false, "synced": 0, "grants_seen": [], "chat_seen": 0, "off": false},
	}


## Skill XP for a new hero (or the old shared pool): Hitpoints starts at 10.
## Old saves pick this up per hero through _merge, so heroes start fresh.
func _fresh_skills() -> Dictionary:
	var out := {}
	for s in DB.SKILLS:
		out[s] = DB.xp_for_level(10) if s == "hitpoints" else 0
	return out


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


## The name the player picked, or a stand-in until they pick one.
func player_name() -> String:
	var n := str(data["profile"]["name"])
	return n if n != "" else "Hunter"


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


## Modes open on the Trophy Road; a rift needs a key.
func mode_unlocked(id: String) -> bool:
	if id == "rift":
		return int(data.get("rift_keys", 0)) > 0
	return DB.road_gate(id) < 0 or id in data["unlocks"]


func best_depth(hero: String) -> int:
	return int(data["stats"]["best"].get("descent_" + hero, 0))


func set_mode(id: String) -> void:
	if DB.MODES.has(id):
		data["mode"] = id
		save()


## Zones (the arenas) open on the Trophy Road.
func zone_unlocked(id: String) -> bool:
	return DB.road_gate(id) < 0 or id in data["unlocks"]


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
	# A tier opens after TIER_WINS wins on the one below it, not the first.
	if not data.has("tier_wins"):
		data["tier_wins"] = {}
	var key := "%s:%d" % [mode, t]
	data["tier_wins"][key] = int(data["tier_wins"].get(key, 0)) + 1
	if int(data["tier_wins"][key]) < DB.TIER_WINS:
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


## Each hero trains their own skills. An empty id means the selected hero.
func skills(id := "") -> Dictionary:
	return hero(id if id != "" else hero_id())["skills"]


func skill_xp(s: String, id := "") -> int:
	return int(skills(id)[s])


func skill_level(s: String, id := "") -> int:
	return DB.level_for_xp(skill_xp(s, id))


func skill_levels(id := "") -> Dictionary:
	var out := {}
	for s in DB.SKILLS:
		out[s] = skill_level(s, id)
	return out


func combat_level(id := "") -> int:
	return DB.combat_level(skill_levels(id))


# --- Dates --------------------------------------------------------------------

func today() -> String:
	return Time.get_date_string_from_system()


## Days since 1970 for a "YYYY-MM-DD" date: a counter that ticks at local midnight.
func day_number(day: String) -> int:
	return int(Time.get_unix_time_from_datetime_string(day) / 86400)


func _day_offset(days: int) -> String:
	return Time.get_date_string_from_unix_time(int(Time.get_unix_time_from_system()) + days * 86400)
