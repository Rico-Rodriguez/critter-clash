extends "res://src/autoload/game_rewards.gd"
## Game, part 5: reasons to come back. Mastery and rating, the campfire,
## login calendar, kill counts, achievements, the season and the next goal.


# --- Mastery, rating, dailies -------------------------------------------------

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
		"gems":
			data["gems"] = int(data.get("gems", 0)) + int(rw["amount"])
		"egg":
			# A full hatchery pays the egg as gems instead.
			if SK.give_egg(data, str(rw["egg"]), int(Time.get_unix_time_from_system()), rng.randi()).is_empty():
				data["gems"] = int(data.get("gems", 0)) + 40
		"glow":
			for id in DB.HERO_ORDER:
				if not rw["glow"] in hero(id)["glows"]:
					hero(id)["glows"].append(rw["glow"])
	save()
	return rw


# --- Story campaign -----------------------------------------------------------

const STORY := preload("res://src/data/story_db.gd")


func story_cleared(id: String) -> bool:
	return id in data["story"]["cleared"]


## A chapter opens once the one before it is cleared.
func story_open(i: int) -> bool:
	return i == 0 or (i > 0 and i < STORY.count() and story_cleared(str(STORY.CHAPTERS[i - 1]["id"])))


## The first chapter not yet cleared (count() when the story is done).
func story_next() -> int:
	for i in STORY.count():
		if not story_cleared(str(STORY.CHAPTERS[i]["id"])):
			return i
	return STORY.count()


## Queues chapter `id` for the next hunt. False when it is not open.
func story_begin(id: String) -> bool:
	var i := STORY.index(id)
	if i < 0 or not story_open(i):
		return false
	data["story"]["run"] = id
	save()
	return true


## The chapter the hunt now starting plays ({} for a normal hunt). Consumed:
## a hunt that is left or lost does not leave the chapter queued.
func story_take() -> Dictionary:
	var id := str(data["story"].get("run", ""))
	data["story"]["run"] = ""
	return STORY.chapter(id)


## Pays a won chapter hunt: first clears pay the chapter reward, the chapter's
## own hero adds 25%. Returns {id, first, gold, gems, shards, glow, hero_bonus}.
func story_clear(r: Dictionary) -> Dictionary:
	var ch: Dictionary = STORY.chapter(str(r.get("story", "")))
	if ch.is_empty():
		return {}
	var first := not story_cleared(str(ch["id"]))
	var out := {"id": str(ch["id"]), "first": first, "gold": 0, "gems": 0, "shards": 0, "glow": "", "hero_bonus": false}
	if first:
		var rw: Dictionary = ch["reward"]
		var bonus := 1.25 if str(r.get("hero", "")) == str(ch["hero"]) else 1.0
		out["hero_bonus"] = bonus > 1.0
		out["gold"] = int(round(int(rw.get("gold", 0)) * bonus))
		out["gems"] = int(round(int(rw.get("gems", 0)) * bonus))
		out["shards"] = int(round(int(rw.get("shards", 0)) * bonus))
		data["gold"] = gold() + int(out["gold"])
		data["gems"] = int(data.get("gems", 0)) + int(out["gems"])
		hero(str(ch["hero"]))["shards"] = int(hero(str(ch["hero"]))["shards"]) + int(out["shards"])
		if str(rw.get("glow", "")) != "":
			out["glow"] = str(rw["glow"])
			for id in DB.HERO_ORDER:
				if not rw["glow"] in hero(id)["glows"]:
					hero(id)["glows"].append(rw["glow"])
		data["story"]["cleared"].append(str(ch["id"]))
	return out


## The nearest goal worth chasing, for the camp ("An XP lamp is ready").
func next_goal() -> String:
	var id := hero_id()
	if can_buy_super_rank(id):
		return "A Super rank is ready: buy it in Skills"
	if talent_points(id) > 0:
		return "A talent point to spend in Heroes"
	var t := mode_tier_unlocked()
	if t < DB.TIERS.size() - 1 and tier() == t:
		return "%s on %s to open %s" % ["Fell a Descent boss" if mode_id() == "descent" else "Win", DB.TIERS[t]["name"], DB.TIERS[t + 1]["name"]]
	var nxt := mastery_next(id)
	if nxt > 0:
		return "%d mastery to %s" % [nxt - int(hero(id)["mastery"]), DB.MASTERY[int(hero(id)["mastery_rank"]) + 1]["title"]]
	return ""
