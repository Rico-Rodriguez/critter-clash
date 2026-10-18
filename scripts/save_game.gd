extends Node

## Local progress. No account, no shop.
## clan_id and duel_rating are stored so a later clan roster or duel
## ladder can persist without a save migration. Nothing reads them yet.

const PATH := "user://critter_clash.json"
const VERSION := 2

var data: Dictionary = {}


func _ready() -> void:
	_load()


func reset_new() -> void:
	data = _fresh()
	_reconcile()
	_write()


func pending_count() -> int:
	return data["chests"].size()


## Clash-style chest drawer: four slots. Earned chests arrive locked; the
## player taps one to start its timer (one unlocks at a time), and the
## timer scales with rarity. Reward chests (milestones, the slayer shop)
## arrive ready. A chest earned with every slot taken is lost.
const SLOTS := 4
const UNLOCK_SECONDS := {"common": 15 * 60, "rare": 60 * 60, "epic": 3 * 60 * 60}
const RARITY_OF_TONE := {"wood": "common", "silver": "rare", "magic": "epic", "gold": "epic"}

## What the last hunt sent home: {"tone", "rarity", "full", "index"}. Not saved.
var last_chest: Dictionary = {}


func _new_chest(kind: String, biome_id: String, timed: bool) -> Dictionary:
	var chest := {"kind": kind, "biome": biome_id, "seed": randi()}
	if not timed:
		chest["tone"] = "gold"
		chest["ready_at"] = 0
	return chest


## Put a chest in the drawer; false (and the chest is dropped) when full.
## Reward chests pass force so a claimed prize is never thrown away.
func add_chest(chest: Dictionary, force := false) -> bool:
	if data["chests"].size() >= SLOTS and not force:
		return false
	chest["fresh"] = true
	data["chests"].append(chest)
	return true


func slots_full() -> bool:
	return data["chests"].size() >= SLOTS


func chest_rarity(i: int) -> String:
	return str(RARITY_OF_TONE.get(chest_tone(i), "rare"))


## Full unlock time of chest i, from its rarity.
func chest_total(i: int) -> int:
	return int(UNLOCK_SECONDS.get(chest_rarity(i), 3600))


## "locked" (timer not started), "unlocking", or "ready".
func chest_state(i: int) -> String:
	if i < 0 or i >= data["chests"].size():
		return ""
	if not data["chests"][i].has("ready_at"):
		return "locked"
	return "ready" if chest_wait(i) <= 0 else "unlocking"


## Seconds until chest i can be opened (0 = ready). A locked chest reports
## its full timer so the slot can show how long it will take.
func chest_wait(i: int) -> int:
	if i < 0 or i >= data["chests"].size():
		return 0
	var chest: Dictionary = data["chests"][i]
	if not chest.has("ready_at"):
		return chest_total(i)
	return maxi(0, int(chest["ready_at"]) - int(Time.get_unix_time_from_system()))


func unlocking_index() -> int:
	for i in data["chests"].size():
		if chest_state(i) == "unlocking":
			return i
	return -1


## Start chest i's timer. Only one chest unlocks at a time.
func start_unlock(i: int) -> bool:
	if chest_state(i) != "locked" or unlocking_index() >= 0:
		return false
	data["chests"][i]["ready_at"] = int(Time.get_unix_time_from_system()) + chest_total(i)
	_write()
	return true


func first_ready() -> int:
	for i in data["chests"].size():
		if chest_state(i) == "ready":
			return i
	return -1


## Chests that arrived since Home last showed them (for the fly-in).
func take_fresh() -> Array:
	var out: Array = []
	for i in data["chests"].size():
		if bool(data["chests"][i].get("fresh", false)):
			out.append(i)
			data["chests"][i].erase("fresh")
	if not out.is_empty():
		_write()
	return out


static func clock(seconds: int) -> String:
	if seconds >= 3600:
		return "%d:%02d:%02d" % [seconds / 3600, (seconds % 3600) / 60, seconds % 60]
	return "%d:%02d" % [seconds / 60, seconds % 60]


static func span(seconds: int) -> String:
	if seconds >= 3600 and seconds % 3600 == 0:
		return "%dh" % (seconds / 3600)
	if seconds >= 3600:
		return "%dh %dm" % [seconds / 3600, (seconds % 3600) / 60]
	return "%dm" % (seconds / 60)


## The look of chest i: pouches are plain wood, hunt chests take their
## biome's metal, reward chests are gilded.
func chest_tone(i: int) -> String:
	if i < 0 or i >= data["chests"].size():
		return "wood"
	var chest: Dictionary = data["chests"][i]
	if chest.has("tone"):
		return str(chest["tone"])
	if str(chest.get("kind", "hunt")) == "scrap":
		return "wood"
	return {"meadow": "silver", "mushroom": "magic", "frost": "silver", "volcano": "gold"}.get(str(chest.get("biome", "meadow")), "silver")


func biome_cleared(id: String) -> bool:
	return bool(data["cleared"].get(id, false))


func biome_open(id: String) -> bool:
	var entry := Catalog.biome(id)
	if int(data["trophies"]) < int(entry["gate"]):
		return false
	var need := str(entry["need"])
	if need != "" and not biome_cleared(need):
		return false
	return true


func biome_lock_text(id: String) -> String:
	var entry := Catalog.biome(id)
	var parts: PackedStringArray = PackedStringArray()
	var need := str(entry["need"])
	if need != "" and not biome_cleared(need):
		parts.append("Clear %s" % str(Catalog.biome(need)["name"]))
	if int(data["trophies"]) < int(entry["gate"]):
		parts.append("%d trophies" % int(entry["gate"]))
	if parts.is_empty():
		return "Locked"
	return " · ".join(parts)


## The two knights a new save starts with; Gnash and Mordrek join on the road.
const STARTERS := ["pebble", "ember"]
## Animal heroes retired from the playable roster (saves move to Aldric).
const RETIRED := ["juniper", "pip"]

func hero(id: String) -> Dictionary:
	return data["heroes"][id]


func featured_id() -> String:
	var id := str(data.get("featured", "pebble"))
	if not data["heroes"].has(id) or not bool(data["heroes"][id]["unlocked"]):
		return "pebble"
	return id


func set_featured(id: String) -> void:
	if featured_id() == id and str(data.get("featured", "")) == id:
		return
	data["featured"] = id
	_write()


func can_level(id: String) -> bool:
	var row: Dictionary = hero(id)
	if not bool(row["unlocked"]):
		return false
	var level := int(row["level"])
	if level >= Catalog.MAX_CARD_LEVEL:
		return false
	if int(row["cards"]) < cards_needed(level):
		return false
	if int(data["coins"]) < coins_needed(level):
		return false
	return true


func cards_needed(level: int) -> int:
	return level * 2


func coins_needed(level: int) -> int:
	return level * 15


func try_level(id: String) -> bool:
	if not can_level(id):
		AudioDirector.play("error")
		return false
	var row: Dictionary = hero(id)
	var level := int(row["level"])
	row["cards"] = int(row["cards"]) - cards_needed(level)
	row["level"] = level + 1
	data["coins"] = int(data["coins"]) - coins_needed(level)
	_write()
	AudioDirector.play("merge")
	return true


func find_gear(uid: int) -> Dictionary:
	for entry in data["bag"]:
		if int(entry["uid"]) == uid:
			return entry
	return {}


func equip(hero_id: String, uid: int) -> void:
	var piece := find_gear(uid)
	if piece.is_empty():
		return
	var slot := str(piece["slot"])
	for id in data["heroes"].keys():
		if int(data["heroes"][id][slot]) == uid:
			data["heroes"][id][slot] = 0
	data["heroes"][hero_id][slot] = uid
	_write()
	AudioDirector.play("click")


func unequip(hero_id: String, slot: String) -> void:
	data["heroes"][hero_id][slot] = 0
	_write()


func gear_text(piece: Dictionary) -> String:
	if piece.is_empty():
		return ""
	var stats: Dictionary = piece["stats"]
	var parts: PackedStringArray = PackedStringArray()
	if stats.has("dmg_pct"):
		parts.append("+%d%% damage" % int(round(float(stats["dmg_pct"]) * 100.0)))
	if stats.has("haste"):
		parts.append("+%d%% attack speed" % int(round(float(stats["haste"]) * 100.0)))
	if stats.has("hp_flat"):
		parts.append("+%d health" % int(stats["hp_flat"]))
	if stats.has("armor"):
		parts.append("+%d armor" % int(stats["armor"]))
	if stats.has("crit"):
		parts.append("+%d%% crit" % int(round(float(stats["crit"]) * 100.0)))
	if stats.has("speed_pct"):
		parts.append("+%d%% move" % int(round(float(stats["speed_pct"]) * 100.0)))
	if stats.has("regen"):
		parts.append("+%.1f regen" % float(stats["regen"]))
	return str(piece["name"]) + " · " + " · ".join(parts)


func equipped_line(hero_id: String) -> String:
	var row: Dictionary = hero(hero_id)
	var bits: PackedStringArray = PackedStringArray()
	for slot in ["weapon", "armor", "charm"]:
		var uid := int(row[slot])
		if uid <= 0:
			bits.append("no " + slot)
			continue
		var piece := find_gear(uid)
		bits.append(str(piece.get("name", slot)) if not piece.is_empty() else slot)
	return " · ".join(bits)


func build_run_stats(hero_id: String) -> Dictionary:
	var stats := Catalog.base_stats(hero_id)
	var level := int(hero(hero_id)["level"])
	var scale := 1.0 + 0.08 * float(level - 1)
	stats["hp"] = float(stats["hp"]) * scale
	stats["dmg"] = float(stats["dmg"]) * scale
	var row: Dictionary = hero(hero_id)
	for slot in ["weapon", "armor", "charm"]:
		var uid := int(row[slot])
		if uid <= 0:
			continue
		var piece := find_gear(uid)
		if piece.is_empty():
			continue
		var bonus: Dictionary = piece["stats"]
		if bonus.has("dmg_pct"):
			stats["dmg"] = float(stats["dmg"]) * (1.0 + float(bonus["dmg_pct"]))
		if bonus.has("haste"):
			stats["interval"] = float(stats["interval"]) / (1.0 + float(bonus["haste"]))
		if bonus.has("hp_flat"):
			stats["hp"] = float(stats["hp"]) + float(bonus["hp_flat"])
		if bonus.has("armor"):
			stats["armor"] = float(stats["armor"]) + float(bonus["armor"])
		if bonus.has("crit"):
			stats["crit"] = float(stats["crit"]) + float(bonus["crit"])
		if bonus.has("speed_pct"):
			stats["speed"] = float(stats["speed"]) * (1.0 + float(bonus["speed_pct"]))
		if bonus.has("regen"):
			stats["regen"] = float(stats["regen"]) + float(bonus["regen"])
	return stats


## --- Daily Challenge local board -------------------------------------------
## data["daily"][key] = {"best": int, "runs": [{score, hero, time, result, at}]}
## kept sorted by score (top 10). This is the local leaderboard stub.

const DAILY_RUNS := 10


func _daily_board(key: String) -> Dictionary:
	if not data.has("daily") or typeof(data["daily"]) != TYPE_DICTIONARY:
		data["daily"] = {}
	if not data["daily"].has(key) or typeof(data["daily"][key]) != TYPE_DICTIONARY:
		data["daily"][key] = {"best": 0, "runs": []}
	var board: Dictionary = data["daily"][key]
	if not board.has("runs") or typeof(board["runs"]) != TYPE_ARRAY:
		board["runs"] = []
	if not board.has("best"):
		board["best"] = 0
	return board


## Record a finished daily run and return its 1-based rank on the board.
## The run list is trimmed to the best DAILY_RUNS scores.
func record_daily(key: String, entry: Dictionary) -> int:
	var board := _daily_board(key)
	var runs: Array = board["runs"]
	var score := int(entry.get("score", 0))
	var rank := 1
	for r in runs:
		if int(r.get("score", 0)) > score:
			rank += 1
	runs.append(entry.duplicate(true))
	runs.sort_custom(_daily_desc)
	while runs.size() > DAILY_RUNS:
		runs.pop_back()
	board["best"] = int(runs[0]["score"]) if not runs.is_empty() else 0
	_write()
	return rank


## The board for a day, best first (a copy, safe for the UI to iterate).
func daily_board(key: String) -> Array:
	var runs: Array = _daily_board(key)["runs"].duplicate()
	runs.sort_custom(_daily_desc)
	return runs


func daily_best(key: String) -> int:
	return int(_daily_board(key).get("best", 0))


## Local subnet of a future server. The run is queued; a server endpoint
## plugs in here later and drains the list.
func daily_submit(key: String, entry: Dictionary) -> void:
	if not data.has("pending_upload") or typeof(data["pending_upload"]) != TYPE_ARRAY:
		data["pending_upload"] = []
	data["pending_upload"].append({"key": key, "entry": entry.duplicate(true)})
	_write()


func _daily_desc(a: Dictionary, b: Dictionary) -> bool:
	return int(a.get("score", 0)) > int(b.get("score", 0))


var debug_rare := false


func commit_victory(biome_id: String, boss_id: String, slain: int = 0) -> Dictionary:
	var first := not biome_cleared(biome_id)
	data["cleared"][biome_id] = true
	var gained := 30 if first else 16
	data["trophies"] = int(data["trophies"]) + gained
	data["kills"][boss_id] = int(data["kills"].get(boss_id, 0)) + 1
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var drops := _roll_boss(boss_id, rng)
	var reveal := {}
	for drop in drops:
		_apply_drop(drop, rng)
		if str(drop.get("kind", "")) == "pet":
			reveal = drop
		elif reveal.is_empty() and Catalog.is_reveal(drop):
			reveal = drop
	_note_slayer(biome_id, slain, true)
	_send_home(_new_chest("hunt", biome_id, true))
	_write()
	return {
		"trophies": gained,
		"first": first,
		"boss": boss_id,
		"drops": drops,
		"reveal": reveal,
		"kills": int(data["kills"][boss_id]),
	}


## A daily won on a biome the player has not unlocked: the boss falls and the
## run scores, but the clear is daily-only. No cleared flag, trophies, boss
## kill or slayer progress, so it never unlocks the biome or advances
## progress. The hunt chest still comes home as the run's loot.
func commit_daily_pass(biome_id: String, boss_id: String) -> Dictionary:
	_send_home(_new_chest("hunt", biome_id, true))
	_write()
	return {"trophies": 0, "first": false, "boss": boss_id, "drops": [], "reveal": {}, "kills": boss_kills(boss_id)}


func _send_home(chest: Dictionary) -> void:
	var ok := add_chest(chest)
	if not ok:
		# Measure what would have come home, then drop it.
		data["chests"].append(chest)
	var i: int = data["chests"].size() - 1
	last_chest = {"tone": chest_tone(i), "rarity": chest_rarity(i), "full": not ok, "index": i if ok else -1}
	if not ok:
		data["chests"].pop_back()


## A camp chest opened mid-hunt goes home locked on its timer: commons as
## wood (15m), elite chests as silver (1h). One slot stays free for the
## boss's chest. Returns "sent" or "full".
func send_camp_chest(tier: String, biome_id: String) -> String:
	if data["chests"].size() >= SLOTS - 1:
		return "full"
	var chest := {"kind": "camp", "biome": biome_id, "seed": randi(), "tone": "silver" if tier == "rare" else "wood"}
	add_chest(chest)
	_write()
	return "sent"


func commit_defeat(biome_id: String, slain: int = 0) -> void:
	_note_slayer(biome_id, slain, false)
	_send_home(_new_chest("scrap", biome_id, true))
	_write()


func obtained_count() -> int:
	return data["log"].size()


func has_log(id: String) -> bool:
	return id in data["log"]


func boss_kills(id: String) -> int:
	return int(data["kills"].get(id, 0))


func active_pet() -> String:
	var id := str(data.get("active_pet", ""))
	if id == "" or not bool(data["pets"].get(id, false)):
		return ""
	return id


func set_active_pet(id: String) -> void:
	if not bool(data["pets"].get(id, false)):
		return
	data["active_pet"] = id
	_write()


func material_count(id: String) -> int:
	return int(data["materials"].get(id, 0))


func assign_task(task_id: String = "") -> Dictionary:
	var pick := {}
	if task_id != "":
		pick = Catalog.slayer_task(task_id).duplicate()
	else:
		var choices: Array = []
		var current := str(data["slayer"]["task"].get("id", ""))
		for entry in Catalog.SLAYER_TASKS:
			if str(entry["id"]) != current:
				choices.append(entry)
		if choices.is_empty():
			return {}
		pick = (choices[randi() % choices.size()] as Dictionary).duplicate()
	if pick.is_empty():
		return {}
	pick["have"] = 0
	data["slayer"]["task"] = pick
	_write()
	AudioDirector.play("click")
	return pick


func cancel_task() -> void:
	data["slayer"]["task"] = {}
	data["slayer"]["streak"] = 0
	_write()


func complete_task() -> int:
	var task: Dictionary = data["slayer"]["task"]
	if task.is_empty() or int(task.get("have", 0)) < int(task.get("need", 1)):
		AudioDirector.play("error")
		return 0
	var streak := int(data["slayer"]["streak"])
	var gained := int(task["points"]) + streak * 5
	data["slayer"]["points"] = int(data["slayer"]["points"]) + gained
	data["slayer"]["streak"] = streak + 1
	data["slayer"]["task"] = {}
	_write()
	AudioDirector.play("merge")
	return gained


func buy_slayer(offer_id: String) -> bool:
	var offer := Catalog.slayer_offer(offer_id)
	if offer.is_empty() or int(data["slayer"]["points"]) < int(offer["cost"]):
		AudioDirector.play("error")
		return false
	data["slayer"]["points"] = int(data["slayer"]["points"]) - int(offer["cost"])
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	match str(offer["kind"]):
		"charm":
			data["bag"].append(_roll_gear(rng, "charm", "rare", "meadow"))
		"cosmetic":
			data["cosmetic"] = str(offer.get("cosmetic", "ribbon"))
		"chest":
			add_chest(_new_chest("hunt", "meadow", false), true)
	_write()
	AudioDirector.play("merge")
	return true


func _roll_boss(boss_id: String, rng: RandomNumberGenerator) -> Array:
	var weighted: Array = []
	var pet := {}
	for entry in Catalog.drop_table(boss_id):
		if str(entry["kind"]) == "pet":
			pet = (entry as Dictionary).duplicate()
		else:
			weighted.append((entry as Dictionary).duplicate())
	var got: Array = []
	var picked := _weighted(rng, weighted)
	if not picked.is_empty():
		got.append(picked)
	var force := debug_rare
	debug_rare = false
	if not pet.is_empty() and (force or rng.randi_range(1, Catalog.PET_RATE) == 1):
		got.append(pet)
	return got


func _weighted(rng: RandomNumberGenerator, rows: Array) -> Dictionary:
	var total := 0
	for row in rows:
		total += int(row["weight"])
	if total <= 0:
		return {}
	var roll := rng.randi_range(1, total)
	var acc := 0
	for row in rows:
		acc += int(row["weight"])
		if roll <= acc:
			return row
	return {}


func _apply_drop(drop: Dictionary, rng: RandomNumberGenerator) -> void:
	var id := str(drop["id"])
	match str(drop["kind"]):
		"coins":
			data["coins"] = int(data["coins"]) + int(drop.get("amount", 0))
		"material":
			data["materials"][id] = int(data["materials"].get(id, 0)) + int(drop.get("amount", 1))
		"cards":
			var hero_id := str(drop.get("hero", ""))
			if data["heroes"].has(hero_id):
				var row: Dictionary = data["heroes"][hero_id]
				row["cards"] = int(row["cards"]) + int(drop.get("amount", 1))
		"gear":
			var piece := _roll_gear(rng, str(drop.get("slot", "charm")), str(drop.get("gear_rarity", "common")), "meadow")
			piece["name"] = str(drop.get("name", piece["name"]))
			data["bag"].append(piece)
		"pet":
			data["pets"][id] = true
			if str(data.get("active_pet", "")) == "":
				data["active_pet"] = id
	if id not in data["log"]:
		data["log"].append(id)


func _note_slayer(biome_id: String, slain: int, boss: bool) -> void:
	var task: Dictionary = data["slayer"]["task"]
	if task.is_empty() or str(task.get("biome", "")) != biome_id:
		return
	if str(task.get("kind", "")) == "minion":
		task["have"] = mini(int(task["need"]), int(task.get("have", 0)) + maxi(0, slain))
	elif str(task.get("kind", "")) == "boss" and boss:
		task["have"] = mini(int(task["need"]), int(task.get("have", 0)) + 1)


func open_next(index: int = 0) -> Dictionary:
	if index < 0 or index >= data["chests"].size():
		return {}
	var chest: Dictionary = data["chests"].pop_at(index)
	var loot := _roll_loot(chest)
	_write()
	return loot


func claim(id: String) -> bool:
	if id in data["claimed"]:
		return false
	var entry := Catalog.milestone(id)
	if entry.is_empty():
		return false
	if int(data["trophies"]) < int(entry["trophies"]):
		return false
	data["claimed"].append(id)
	match str(entry["kind"]):
		"coins":
			data["coins"] = int(data["coins"]) + int(entry["amount"])
		"chest":
			add_chest(_new_chest("hunt", "meadow", false), true)
		"unlock":
			var row: Dictionary = data["heroes"][str(entry["hero"])]
			row["unlocked"] = true
			row["cards"] = int(row["cards"]) + int(entry["cards"])
		"gear":
			var rng := RandomNumberGenerator.new()
			rng.randomize()
			data["bag"].append(_roll_gear(rng, str(entry["slot"]), str(entry["rarity"]), "meadow"))
	_write()
	AudioDirector.play("merge")
	return true


func _roll_loot(chest: Dictionary) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(chest["seed"])
	var hunt := str(chest["kind"]) == "hunt"
	var coins := rng.randi_range(32, 54) if hunt else rng.randi_range(10, 18)
	var pool: Array = []
	for id in Catalog.playable_ids():
		if bool(data["heroes"][id]["unlocked"]):
			pool.append(id)
	if pool.is_empty():
		pool = ["ember"]
	var drops: Array = []
	var count := rng.randi_range(3, 5) if hunt else rng.randi_range(1, 2)
	for _i in count:
		var id: String = str(pool[rng.randi() % pool.size()])
		var cards := rng.randi_range(1, 3) if hunt else 1
		drops.append({"id": id, "count": cards})
	var gear := {}
	var chance := 0.65 if hunt else 0.22
	if rng.randf() < chance:
		var slots := ["weapon", "armor", "charm"]
		var slot: String = slots[rng.randi() % slots.size()]
		var roll := rng.randf()
		var rarity := "common"
		if hunt and roll > 0.9:
			rarity = "epic"
		elif roll > 0.58:
			rarity = "rare"
		gear = _roll_gear(rng, slot, rarity, str(chest.get("biome", "meadow")))
	data["coins"] = int(data["coins"]) + coins
	for drop in drops:
		var row: Dictionary = data["heroes"][str(drop["id"])]
		row["cards"] = int(row["cards"]) + int(drop["count"])
	if not gear.is_empty():
		data["bag"].append(gear)
	return {
		"coins": coins,
		"cards": drops,
		"gear": gear,
		"biome": str(chest.get("biome", "meadow")),
		"kind": str(chest.get("kind", "hunt")),
	}


func _roll_gear(rng: RandomNumberGenerator, slot: String, rarity: String, biome_id: String) -> Dictionary:
	var mul := 1.0
	if rarity == "rare":
		mul = 1.35
	elif rarity == "epic":
		mul = 1.75
	var stats := {}
	if slot == "weapon":
		stats["dmg_pct"] = rng.randf_range(0.08, 0.13) * mul
		if rarity != "common":
			stats["haste"] = rng.randf_range(0.03, 0.055) * mul
	elif slot == "armor":
		stats["hp_flat"] = int(round(rng.randi_range(18, 30) * mul))
		stats["armor"] = 1 if rarity == "common" else int(round(rng.randi_range(2, 3) * mul))
	else:
		var pick := rng.randi() % 3
		if pick == 0:
			stats["crit"] = rng.randf_range(0.03, 0.05) * mul
		elif pick == 1:
			stats["speed_pct"] = rng.randf_range(0.06, 0.1) * mul
		else:
			stats["regen"] = rng.randf_range(0.5, 0.9) * mul
	var uid := int(data["gear_uid"])
	data["gear_uid"] = uid + 1
	return {
		"uid": uid,
		"slot": slot,
		"rarity": rarity,
		"name": _gear_name(rng, slot, rarity, biome_id),
		"biome": biome_id,
		"stats": stats,
	}


func _gear_name(rng: RandomNumberGenerator, slot: String, rarity: String, biome_id: String) -> String:
	var nouns := {
		"weapon": ["Claw", "Sling", "Wand", "Mallet"],
		"armor": ["Vest", "Shell", "Coat", "Wrap"],
		"charm": ["Charm", "Bell", "Bead", "Leaf"],
	}
	var place := str(Catalog.biome(biome_id)["name"]).split(" ")[0]
	var noun: String = nouns[slot][rng.randi() % nouns[slot].size()]
	var prefix := ""
	if rarity == "rare":
		prefix = "Bright "
	elif rarity == "epic":
		prefix = "Grand "
	return "%s%s %s" % [prefix, place, noun]


func _fresh() -> Dictionary:
	var heroes := {}
	for id in Catalog.playable_ids():
		var unlocked: bool = str(id) in STARTERS
		heroes[id] = {
			"unlocked": unlocked,
			"cards": 1 if unlocked else 0,
			"level": 1,
			"weapon": 0,
			"armor": 0,
			"charm": 0,
		}
	return {
		"save_version": VERSION,
		"coins": 30,
		"trophies": 0,
		"claimed": [],
		"cleared": {},
		"chests": [],
		"gear_uid": 1,
		"bag": [],
		"clan_id": "",
		"duel_rating": 0,
		"featured": "pebble",
		"heroes": heroes,
		"kills": {},
		"log": [],
		"pets": {},
		"active_pet": "",
		"materials": {},
		"cosmetic": "",
		"slayer": {"points": 0, "streak": 0, "task": {}},
		"skills": {"foraging": 0, "fishing": 0, "taming": 0, "crafting": 0},
		"daily": {},
		"pending_upload": [],
	}


func _reconcile() -> void:
	if not data.has("heroes"):
		data["heroes"] = {}
	for key in ["claimed", "chests", "bag"]:
		if not data.has(key) or typeof(data[key]) != TYPE_ARRAY:
			data[key] = []
	if not data.has("cleared") or typeof(data["cleared"]) != TYPE_DICTIONARY:
		data["cleared"] = {}
	if not data.has("gear_uid"):
		data["gear_uid"] = 1
	if not data.has("clan_id"):
		data["clan_id"] = ""
	if not data.has("duel_rating"):
		data["duel_rating"] = 0
	if not data.has("featured"):
		data["featured"] = "pebble"
	# Retired animal heroes: a save that had one equipped moves to Aldric, and
	# their gear goes back to the bag (unequipped) for the knights.
	if str(data["featured"]) in RETIRED:
		data["featured"] = "pebble"
	for rid in RETIRED:
		if data["heroes"].has(rid):
			data["heroes"].erase(rid)
	for key in ["log"]:
		if not data.has(key) or typeof(data[key]) != TYPE_ARRAY:
			data[key] = []
	for key in ["kills", "pets", "materials"]:
		if not data.has(key) or typeof(data[key]) != TYPE_DICTIONARY:
			data[key] = {}
	if not data.has("active_pet"):
		data["active_pet"] = ""
	if not data.has("cosmetic"):
		data["cosmetic"] = ""
	if not data.has("slayer") or typeof(data["slayer"]) != TYPE_DICTIONARY:
		data["slayer"] = {"points": 0, "streak": 0, "task": {}}
	else:
		if not data["slayer"].has("points"):
			data["slayer"]["points"] = 0
		if not data["slayer"].has("streak"):
			data["slayer"]["streak"] = 0
		if not data["slayer"].has("task") or typeof(data["slayer"]["task"]) != TYPE_DICTIONARY:
			data["slayer"]["task"] = {}
	if not data.has("skills") or typeof(data["skills"]) != TYPE_DICTIONARY:
		data["skills"] = {}
	# Daily boards: one entry per UTC day key, each with a best score and a
	# short local run list. Old saves simply start empty.
	if not data.has("daily") or typeof(data["daily"]) != TYPE_DICTIONARY:
		data["daily"] = {}
	if not data.has("pending_upload") or typeof(data["pending_upload"]) != TYPE_ARRAY:
		data["pending_upload"] = []
	for key in data["daily"].keys():
		var board: Variant = data["daily"][key]
		if typeof(board) != TYPE_DICTIONARY:
			data["daily"][key] = {"best": 0, "runs": []}
			continue
		if not board.has("runs") or typeof(board["runs"]) != TYPE_ARRAY:
			board["runs"] = []
		if not board.has("best"):
			board["best"] = 0
	for entry in Catalog.SKILLS:
		var sid := str(entry["id"])
		if not data["skills"].has(sid):
			data["skills"][sid] = 0
	for id in Catalog.playable_ids():
		if not data["heroes"].has(id):
			data["heroes"][id] = {
				"unlocked": false,
				"cards": 0,
				"level": 1,
				"weapon": 0,
				"armor": 0,
				"charm": 0,
			}
		else:
			var row: Dictionary = data["heroes"][id]
			for slot in ["weapon", "armor", "charm"]:
				if not row.has(slot):
					row[slot] = 0


func _load() -> void:
	data = _fresh()
	_reconcile()
	if not FileAccess.file_exists(PATH):
		_write()
		return
	var file := FileAccess.open(PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		_write()
		return
	if int(parsed.get("save_version", 0)) != VERSION:
		_write()
		return
	data = parsed
	_reconcile()


## Tests set this so a headless check never touches the player's save file.
var no_write := false


func _write() -> void:
	if no_write:
		return
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(data, "\t"))
