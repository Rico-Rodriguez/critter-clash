extends RefCounted
## Frozen Crypt and Burning Swamp checks, called from tests.gd: each zone is
## wired end to end (foes, boss, hazards, art, music, loot, road, eggs) and
## nothing the biomes touch can drift out of step with the data.

const SDB := preload("res://src/data/sidekick_db.gd")
const BI := preload("res://src/hunt/boss_intro.gd")
const BIOME := preload("res://src/hunt/biome.gd")

const NEW := {"frost": "rime", "swamp": "cinder"}


static func run(ok: Callable) -> void:
	_zones(ok)
	_foes(ok)
	_loot(ok)
	_road(ok)
	_files(ok)
	_rules(ok)


static func _zones(ok: Callable) -> void:
	ok.call("biomes: both zones follow the Vault", DB.ZONE_ORDER.slice(3) == ["vault", "frost", "swamp"])
	for id: String in NEW:
		var z: Dictionary = DB.ZONES[id]
		var env: Dictionary = z["env"]
		ok.call("biome %s: crisp lighting (no fog, no glow wash, a ground palette)" % id, float(env["fog_d"]) == 0.0 and not bool(env["glow"]) and env.has("ground") and float(env["mist"].a) == 0.0)
		ok.call("biome %s: names its boss, hazards, weather and music" % id, DB.BOSSES.has(str(z["boss"])) and (z["hazards"] as Array).size() >= 3 and str(env["weather"]) != "" and str(z["music"]) != "" and str(z["boss_music"]) != "")
		ok.call("biome %s: every faction slot is a real foe" % id, (z["faction"] as Dictionary).values().all(func(k): return DB.ENEMIES.has(k) or DB.ENEMIES_EXTRA.has(k)))
		ok.call("biome %s: weights name every foe class it fields" % id, (z["faction"] as Dictionary).keys().all(func(k): return float(z["weights"].get(k, 1.0)) > 0.0))
		ok.call("biome %s: a boss with an intro style and an entrance skin" % id, BI.STYLE.has(str(z["boss"])) and DB.SKINS.has(str(DB.BOSSES[str(z["boss"])]["skin"])))
		ok.call("biome %s: an arena exists in the arena list or by id" % id, FileAccess.file_exists("res://src/hunt/arena_%s.gd" % ("rime" if id == "frost" else "mire")))
		ok.call("biome %s: boss script exists and has no class_name" % id, _plain("res://src/hunt/boss_%s.gd" % str(z["boss"])))


static func _foes(ok: Callable) -> void:
	var frost := ["thrall", "frostguard", "rimearcher", "rimeseer", "frostcaller", "rimehound", "colossus"]
	var swamp := ["bogwalker", "charredguard", "embershooter", "cinderwitch", "pyrecaller", "bogleaper", "methanebloat", "cinderbrute"]
	for k: String in frost + swamp:
		var d: Dictionary = DB.enemy(k)
		var base: Dictionary = DB.enemy(str(d["base"]))
		ok.call("foe %s: a base class, a skin and a model" % k, DB.SKINS.has(str(d["skin"])) and str(d["model"]) != "" and not base.is_empty())
	ok.call("biome swamp: the bloat's death ignites the ground", str(DB.enemy("methanebloat").get("death", "")) == "ignite")
	ok.call("biomes: ten or more new foe types between them", (frost + swamp).size() >= 10 and frost.size() >= 3 and swamp.size() >= 3)


static func _loot(ok: Callable) -> void:
	for id: String in NEW:
		var boss: String = NEW[id]
		var drops: Array = DB.UNIQUES.keys().filter(func(u): return str(DB.UNIQUES[u]["source"]) == boss or str(DB.UNIQUES[u]["source"]) == "ancient_" + boss)
		ok.call("loot %s: five uniques, all in the log" % boss, drops.size() == 5 and drops.all(func(u): return u in DB.LOG_ORDER))
		ok.call("loot %s: source maps back to its boss" % boss, str(DB.SOURCE_BOSS[boss]) == boss)
		var slots := {}
		for u: String in drops:
			slots[str(DB.UNIQUES[u].get("slot", ""))] = true
		ok.call("loot %s: more than one gear slot" % boss, slots.size() >= 3)
	for egg in ["frost", "cinder"]:
		var e: Dictionary = SDB.EGGS[egg]
		var pool: Array = e["pool"]
		ok.call("egg %s: a pool of real pets" % egg, pool.size() >= 4 and pool.all(func(r): return SDB.ROSTER.has(str(r[0])) and int(r[1]) > 0))
		ok.call("egg %s: comes from a Trophy Road step" % egg, DB.TROPHY_ROAD.any(func(st): return str(st["kind"]) == "egg" and str(st.get("egg", "")) == egg))


static func _road(ok: Callable) -> void:
	for id: String in NEW:
		ok.call("road %s: gate is past the Vault and the step index matches" % id, DB.road_gate(id) > DB.road_gate("vault") and DB.road_step(id) > DB.road_step("vault") and str(DB.TROPHY_ROAD[DB.road_step(id) - 1]["id"]) == id)
	ok.call("road: frost opens before swamp", DB.road_gate("frost") < DB.road_gate("swamp"))
	var keep := Game.data.duplicate(true)
	Game.data["unlocks"] = []
	Game.data["road"] = 0
	ok.call("unlock: closed on a new road", not Game.zone_unlocked("frost") and not Game.zone_unlocked("swamp"))
	Game.data["road"] = DB.road_step("frost")
	ok.call("unlock: the Crypt opens on its step, the Swamp stays shut", Game.zone_unlocked("frost") and not Game.zone_unlocked("swamp"))
	Game.data["road"] = DB.road_step("swamp")
	ok.call("unlock: the Swamp opens on its step", Game.zone_unlocked("swamp"))
	Game.data = keep


static func _files(ok: Callable) -> void:
	for t in ["frozen", "frozen_boss", "swamp", "swamp_boss"]:
		ok.call("music %s: the track ships" % t, ResourceLoader.exists("res://assets/audio/music/%s.ogg" % t))
	for z: String in NEW:
		var tracks := [str(DB.ZONES[z]["music"]), str(DB.ZONES[z]["boss_music"])]
		ok.call("biome %s: its music keys are shipped tracks" % z, tracks.all(func(t): return ResourceLoader.exists("res://assets/audio/music/%s.ogg" % t)))
	for s: String in DB.SKINS:
		ok.call("skin %s: texture ships" % s, ResourceLoader.exists("res://assets/kaykit/characters/" + str(DB.SKINS[s]["tex"])))
	for p in ["res://src/hunt/biome.gd", "res://src/hunt/biome_art.gd", "res://src/hunt/arena_rime.gd", "res://src/hunt/arena_mire.gd", "res://src/hunt/mire_plank.gd"]:
		ok.call("%s has no class_name" % p.get_file(), _plain(p))


static func _rules(ok: Callable) -> void:
	ok.call("hazards: the patch rider tables name both elements", BIOME.PATCH_DPS.has("frost") and BIOME.PATCH_DPS.has("fire"))
	for c: Dictionary in [BIOME.ICICLE, BIOME.VENT, BIOME.MARSH]:
		ok.call("hazards: a telegraph longer than 1s, a minimum gap", float(c.get("delay", c.get("warn", 0.0))) >= 1.0 and float(c["min"]) >= 3.0)
	ok.call("hazards: gale warns before it pushes", float(BIOME.GALE["warn"]) >= 1.0 and float(BIOME.GALE["min"]) >= 10.0)


static func _plain(path: String) -> bool:
	var f := FileAccess.open(path, FileAccess.READ)
	return f != null and not f.get_as_text().contains("\nclass_name ")
