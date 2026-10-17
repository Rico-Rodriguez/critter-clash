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
	_write()


func pending_count() -> int:
	return data["chests"].size()


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


func hero(id: String) -> Dictionary:
	return data["heroes"][id]


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


func commit_victory(biome_id: String, boss_id: String) -> Dictionary:
	var first := not biome_cleared(biome_id)
	data["cleared"][biome_id] = true
	var gained := 30 if first else 16
	data["trophies"] = int(data["trophies"]) + gained
	var row: Dictionary = data["heroes"][boss_id]
	var already := bool(row["unlocked"])
	row["unlocked"] = true
	row["cards"] = int(row["cards"]) + (4 if already else 8)
	data["chests"].append({"kind": "hunt", "biome": biome_id, "seed": randi()})
	_write()
	return {"trophies": gained, "first": first, "already": already, "boss": boss_id}


func commit_defeat(biome_id: String) -> void:
	data["chests"].append({"kind": "scrap", "biome": biome_id, "seed": randi()})
	_write()


func open_next() -> Dictionary:
	if data["chests"].is_empty():
		return {}
	var chest: Dictionary = data["chests"].pop_front()
	var loot := _roll_loot(chest)
	_write()
	AudioDirector.play("win", -8.0)
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
			data["chests"].append({"kind": "hunt", "biome": "meadow", "seed": randi()})
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
		var unlocked: bool = str(id) == "ember" or str(id) == "juniper" or str(id) == "pebble"
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
		"heroes": heroes,
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


func _write() -> void:
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(data, "\t"))
