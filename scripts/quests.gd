class_name Quests
extends RefCounted

## The business of the town: the board of tasks, what each one wants and
## what it pays. A task is judged from the save itself, so nothing has to
## remember to fire an event: the board looks at what the player has done
## and works out what is finished.

## One task: what it is called, what it wants, and what it pays.
const LIST: Array = [
	{
		"id": "road_out",
		"name": "The road out",
		"blurb": "The Meadow Gate is shut behind a guardian. Clear the Fringe and the way north opens.",
		"goal": "Clear the Fringe",
		"reward": {"coins": 120, "trophies": 10},
	},
	{
		"id": "deeper",
		"name": "Deeper still",
		"blurb": "The Mushroom Gate waits for whoever can walk the Wilds and live.",
		"goal": "Clear the Wilds",
		"reward": {"coins": 260, "trophies": 20},
	},
	{
		"id": "three_chests",
		"name": "What the hunt leaves",
		"blurb": "Three chests brought home from the ground. The drawer fills faster than the road pays.",
		"goal": "Bring three hunt chests home",
		"reward": {"coins": 90, "gear_shards": 12},
	},
	{
		"id": "old_sprout",
		"name": "Steel for Old Sprout",
		"blurb": "The forge needs iron, and the ground keeps it. Bring the smith his steel.",
		"goal": "Equip an iron piece",
		"reward": {"coins": 60, "trophies": 5},
	},
]

## The tasks the board shows, in order, each with its state: "done" (the
## goal is met and the reward is waiting), "ready" (the goal is met) or
## "open" (still to do).
static func board() -> Array:
	var out: Array = []
	for quest in LIST:
		var id := str(quest["id"])
		var met := _met(id)
		var claimed := bool(SaveGame.data.get("quests_claimed", {}).get(id, false))
		var state := "open"
		if met and not claimed:
			state = "done"
		elif claimed:
			state = "ready"
		out.append({
			"id": id,
			"name": str(quest["name"]),
			"blurb": str(quest["blurb"]),
			"goal": str(quest["goal"]),
			"reward": quest["reward"],
			"state": state,
		})
	return out


## Whether the goal of a task is met, read from the save.
static func _met(id: String) -> bool:
	match id:
		"road_out":
			return SaveGame.tier_cleared("fringe")
		"deeper":
			return SaveGame.tier_cleared("wilds")
		"three_chests":
			return _hunt_chests() >= 3
		"old_sprout":
			return _wears_iron()
	return false


## How many hunt chests have been brought home: they are in the log, one
## entry each.
static func _hunt_chests() -> int:
	var n := 0
	for entry in SaveGame.data.get("log", []):
		if entry is Dictionary and str((entry as Dictionary).get("kind", "hunt")) == "hunt":
			n += 1
	return n


## Whether the hero wears a piece of iron: the forge makes iron first.
static func _wears_iron() -> bool:
	var hero := SaveGame.featured_id()
	for slot in GearDB.HERO_SLOTS.get(hero, []):
		var piece := str(GearDB.equipped(hero).get(str(slot), ""))
		if piece == "":
			continue
		if int(GearDB.item(piece).get("tier", 0)) <= 1:
			return true
	return false


## Pays a task out, once. Returns the reward that was paid, or {} when
## the task was not finished or was already paid.
static func claim(id: String) -> Dictionary:
	var quest: Dictionary = {}
	for entry in LIST:
		if str(entry["id"]) == id:
			quest = entry
	if quest.is_empty() or not _met(id):
		return {}
	var claimed: Dictionary = SaveGame.data.get("quests_claimed", {})
	if bool(claimed.get(id, false)):
		return {}
	claimed[id] = true
	SaveGame.data["quests_claimed"] = claimed
	var reward: Dictionary = quest["reward"]
	if reward.has("coins"):
		SaveGame.data["coins"] = int(SaveGame.data.get("coins", 0)) + int(reward["coins"])
	if reward.has("trophies"):
		SaveGame.data["trophies"] = int(SaveGame.data.get("trophies", 0)) + int(reward["trophies"])
	if reward.has("gear_shards"):
		SaveGame.data["gear_shards"] = int(SaveGame.data.get("gear_shards", 0)) + int(reward["gear_shards"])
	return reward
