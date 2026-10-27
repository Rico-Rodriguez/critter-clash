extends "res://src/autoload/game_goals.gd"
## The profile: currencies, heroes, gear, skills, the collection log and
## settings. Saved as JSON in user://. Also the loot and reward rules that
## change the profile (chests, hunt results, item rolls).
##
## The autoload is split by subject into a chain of scripts, each extending
## the one before (a layer only calls layers below it):
## game_state (save, accessors) < game_items (gear) < game_heroes (stats,
## talents) < game_rewards (chests, road, bounties) < game_goals (mastery,
## season) < game (boot, save migrations, finish_hunt).

## Local error and crash log (Settings copies it as a report).
const ErrorLog := preload("res://src/autoload/error_log.gd")
var errors: ErrorLog


func _ready() -> void:
	rng.randomize()
	if OS.get_cmdline_user_args().has("--fresh") or OS.get_cmdline_user_args().has("--capture") or OS.get_cmdline_user_args().has("--bot") or OS.get_cmdline_user_args().has("--nettest"):
		memory_only = true
		data = _fresh()
	errors = ErrorLog.install(not memory_only)
	var ota := get_node_or_null("/root/Ota")
	if ota:
		errors.set_build(int(ota.get("build")))
	if not memory_only:
		load_save()
	SK.migrate(data)
	if not memory_only:
		recover_suspended_run()
	if int(data.get("idle_since", 0)) <= 0:
		data["idle_since"] = int(Time.get_unix_time_from_system())
	Sfx.refresh_volume.call_deferred()


## Ota restarts the game in-process after an update: the logger is held by the
## engine, so it must be let go before its script is reloaded.
func _ota_unload() -> void:
	if errors:
		# A clean close, or the restarted log would count a crash.
		errors.session_closed()
		OS.remove_logger(errors)
		errors = null


func _notification(what: int) -> void:
	if errors == null:
		return
	if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_EXIT_TREE]:
		errors.session_closed()
	elif what == NOTIFICATION_APPLICATION_RESUMED and not memory_only:
		errors.session_open()


## A hunt that was in the background when the process died pays out now, as
## a retreat: what it had earned is kept, nothing is lost. Returns the summary.
func recover_suspended_run() -> Dictionary:
	var snap = data.get("suspended_run")
	if not snap is Dictionary:
		data.erase("suspended_run")
		return {}
	data.erase("suspended_run")
	var r: Dictionary = snap
	r["win"] = false
	var summary := finish_hunt(r)
	data["recovered_run"] = {"gold": int(r.get("gold", 0)), "items": (r.get("items", []) as Array).size()}
	save()
	return summary


# --- Loading and migrations ---------------------------------------------------

func load_save() -> void:
	data = _fresh()
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary and int(parsed.get("version", 0)) in [1, 2, 3, 4, 5, 6, 7, 8, SAVE_VERSION]:
		if int(parsed.get("version", 0)) == 1:
			_migrate_v1(parsed)
		if int(parsed.get("version", 0)) == 2:
			_migrate_v2(parsed)
		if int(parsed.get("version", 0)) == 3:
			_migrate_v3(parsed)
		if int(parsed.get("version", 0)) == 4:
			_migrate_v4(parsed)
		if int(parsed.get("version", 0)) == 5:
			_migrate_v5(parsed)
		if int(parsed.get("version", 0)) == 6:
			_migrate_v6(parsed)
		if int(parsed.get("version", 0)) == 7:
			_migrate_v7(parsed)
		if int(parsed.get("version", 0)) == 8:
			_migrate_v8(parsed)
		_merge(data, parsed)
		_rename_gear()
		_refund_levels()
		_free_hands()


## Pieces once carried a random prefix ("Barrowborn Steel Greaves"). Names are
## now just material and kind, so old pieces are renamed on every load (cheap,
## and safe to repeat, so no save version is needed).
func _rename_gear() -> void:
	for it in data["items"]:
		if it is Dictionary and it.has("cls") and str(it.get("slot", "")) in DB.SLOTS:
			it["name"] = gear_name(it)


## No shield with a two-handed weapon: one worn from before the rule goes
## back to the bag (safe to repeat, so no save version is needed).
func _free_hands() -> void:
	for id in DB.HERO_ORDER:
		if two_hands(id, equipped(id, "weapon")):
			hero(id)["gear"].erase("trinket")


## Bought hero levels are gone (skills are the power now): give back the shards
## and gold each level cost. Shards rub XP lamps. Level 1 marks it done.
func _refund_levels() -> void:
	for id in DB.HERO_ORDER:
		var lvl := clampi(int(hero(id)["level"]), 1, DB.HERO_MAX_LEVEL)
		for l in range(1, lvl):
			hero(id)["shards"] = int(hero(id)["shards"]) + int(DB.UPGRADE_SHARDS[l])
			data["gold"] = gold() + int(DB.UPGRADE_GOLD[l])
		hero(id)["level"] = 1


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
			it["name"] = gear_name(it)
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
	d["version"] = 5


## v6 renamed the gear materials and pieces. Item names are stored, so old
## pieces get the new words. Order matters: "Dragon Shield" before "Dragon ".
const _V6_NAMES := [
	["Green Dragonhide", "Fenscale"], ["Blue Dragonhide", "Tidescale"], ["Red Dragonhide", "Emberscale"],
	["Black Dragonhide", "Nightscale"], ["Dragon Shield", "Warden Shield"], ["Mithril ", "Cobalt "],
	["Adamant ", "Verdite "], ["Rune ", "Skyiron "], ["Dragon ", "Bloodiron "], ["Mystic ", "Sage "],
	["Infinity ", "Sunwoven "], ["Med Helm", "Helm"], ["Full Helm", "Visored Helm"], ["Chainbody", "Hauberk"],
	["Platebody", "Cuirass"], ["Chainlegs", "Chausses"], ["Platelegs", "Greaves"], ["Robe Top", "Robe"],
	["Robe Bottom", "Robe Skirt"],
]


func _migrate_v5(d: Dictionary) -> void:
	for it in d.get("items", []):
		if it is Dictionary and str(it.get("unique", "")) == "":
			var nm := str(it.get("name", ""))
			for pair in _V6_NAMES:
				nm = nm.replace(pair[0], pair[1])
			it["name"] = nm
	d["version"] = 6


## v7 brings the Trophy Road. Renown becomes trophies and keeps its total; the
## old road's step count is replaced by the new road's. Steps already passed
## count as claimed (the old road paid for that renown) but still open what
## they gate, and whatever the old rules had opened stays open.
func _migrate_v6(d: Dictionary) -> void:
	var tu := int(d.get("tier_unlocked", 0))
	var open := ["trial"]
	if tu >= 1:
		open.append_array(["descent", "wild", "rush"])
	if tu > DB.TIER_VETERAN:
		open.append("depths")
	if tu > DB.TIER_VETERAN + 1:
		open.append("grove")
	var trophies := int(d.get("renown", 0))
	var n := 0
	while DB.road_threshold(n + 1) <= trophies:
		n += 1
		var st := DB.road_reward(n)
		if str(st["kind"]) in ["mode", "zone"] and not str(st["id"]) in open:
			open.append(str(st["id"]))
		elif str(st["kind"]) == "hero" and d.get("heroes", {}).has(str(st["id"])):
			d["heroes"][str(st["id"])]["unlocked"] = true
	d["unlocks"] = open
	d["road"] = n
	d["start_picked"] = true
	d["version"] = 7


## v8 folds the seven material tiers into five named sets. Each piece moves to
## its set, and its stats are rescaled so it is exactly as strong as before
## (stats grow DB.MAT_STAT a set now, 0.22 a tier then). Names are rebuilt on
## load (`_rename_gear`).
const _V8_SET := [0, 1, 1, 2, 3, 3, 4]


func _migrate_v7(d: Dictionary) -> void:
	for it in d.get("items", []):
		if not (it is Dictionary) or not it.has("mat"):
			continue
		var old := clampi(int(it["mat"]), 0, _V8_SET.size() - 1)
		var mat: int = _V8_SET[old]
		it["mat"] = mat
		if str(it.get("unique", "")) == "" and it.get("stats") is Dictionary:
			var k := (1.0 + 0.22 * old) / (1.0 + DB.MAT_STAT * mat)
			for key in it["stats"]:
				it["stats"][key] = maxi(1, int(round(float(it["stats"][key]) * k)))
	for hid in d.get("heroes", {}):
		var h: Dictionary = d["heroes"][hid]
		if int(h.get("best_mat", -1)) >= 0:
			h["best_mat"] = _V8_SET[clampi(int(h["best_mat"]), 0, _V8_SET.size() - 1)]
	d["version"] = 8


## v9 makes gear a collection. Pieces that are the same piece (Game.piece_key)
## fold into one: the worn one (or the first) is kept at level 1, every other
## copy becomes a copy toward its next level, and stats become the piece's
## fixed ones. A Barbarian weapon from before families is an Axe.
func _migrate_v8(d: Dictionary) -> void:
	var worn := {}
	for hid in d.get("heroes", {}):
		for slot in d["heroes"][hid].get("gear", {}):
			worn[int(d["heroes"][hid]["gear"][slot])] = true
	var items: Array = d.get("items", [])
	for it in items:
		if not (it is Dictionary) or not str(it.get("slot", "")) in DB.SLOTS:
			continue
		if str(it["slot"]) == "weapon" and DB.HERO_FAMILIES.has(str(it.get("cls", ""))) and str(it.get("fam", "")) == "":
			it["fam"] = str(DB.UNIQUES.get(str(it.get("unique", "")), {}).get("fam", DB.HERO_FAMILIES[str(it["cls"])][0]))
	# Worn pieces first, so they are the ones kept.
	var order := items.duplicate()
	order.sort_custom(func(a, b): return worn.has(int(a.get("uid", 0))) and not worn.has(int(b.get("uid", 0))))
	var kept := {}
	var remap := {}
	var out := []
	for it in order:
		if not (it is Dictionary) or not str(it.get("slot", "")) in DB.SLOTS:
			out.append(it)
			continue
		var k := piece_key(it)
		if kept.has(k):
			kept[k]["cards"] = int(kept[k]["cards"]) + 1
			remap[int(it["uid"])] = int(kept[k]["uid"])
			continue
		it.erase("ancient")
		it["rarity"] = "legendary" if str(it.get("unique", "")) != "" else "rare"
		it["look"] = 0
		it["lv"] = 1
		it["cards"] = 0
		it["stats"] = piece_stats(it)
		it["name"] = gear_name(it)
		kept[k] = it
		out.append(it)
	d["items"] = out
	for hid in d.get("heroes", {}):
		var g: Dictionary = d["heroes"][hid].get("gear", {})
		for slot in g:
			if remap.has(int(g[slot])):
				g[slot] = remap[int(g[slot])]
	d["version"] = SAVE_VERSION


# --- The end of a hunt --------------------------------------------------------

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
	if str(r.get("omen", "")) != "":
		if record_weekly(r):
			summary["weekly_best"] = weekly_best()
		summary["event_pts"] = add_event_points(r)
		summary["event_total"] = event_points()
		summary["event_tiers"] = event_claimable()
	data["gold"] = gold() + int(r.get("gold", 0))
	# Skill XP goes to the hero who earned it.
	var sk_hid := str(r.get("hero", hero_id()))
	var before := skill_levels(sk_hid)
	for s in r.get("xp", {}):
		skills(sk_hid)[s] = mini(skill_xp(s, sk_hid) + int(r["xp"][s]), 200000000)
	var after := skill_levels(sk_hid)
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
		summary["unlocked_tier"] = _open_mode_tier(str(r.get("mode", "horde")), t)
		if summary["unlocked_tier"] > 0 and t >= int(data["tier_unlocked"]) and t < DB.TIERS.size() - 1:
			data["tier_unlocked"] = t + 1
	summary["renown"] = _earn_renown(r, summary)
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
			if summary["unlocked_tier"] > 0 and tt >= int(data["tier_unlocked"]) and tt < DB.TIERS.size() - 1:
				data["tier_unlocked"] = tt + 1
		var dkey: String = "descent_" + str(r["hero"])
		var d := int(r.get("depth", 1))
		if d > int(st["best"].get(dkey, 0)):
			st["best"][dkey] = d
			summary["record"] = true
	summary["sidekick"] = SK.after_hunt(data, r, rng)
	_bounty_progress(r)
	var opened := unlock_by_shards()
	if opened != "":
		summary["unlocked_hero"] = opened
	save()
	return summary
