extends Node

## Local progress. No account, no shop.
## clan_id and duel_rating are stored so a later clan roster or duel
## ladder can persist without a save migration. Nothing reads them yet.

const PATH := "user://critter_clash.json"
## 5: the gathering skills are Woodcutting, Fishing and Mining (Catalog.SKILLS);
## the old placeholder ids (foraging, taming, crafting) are dropped on load,
## see migrate_gathering_skills.
## 4: heroes train for power, they no longer buy it (see migrate_training); the
## GearDB armory gains a "reinforce" map ({owned, equipped, xp, reinforce}).
## 3: the GearDB armory ({v, owned, equipped, xp}; legacy v2 saves migrate on
## load, see migrate_legacy_armory).
const VERSION := 5

var data: Dictionary = {}


func _ready() -> void:
	_load()


func reset_new() -> void:
	data = _fresh()
	_reconcile()
	_write()


func pending_count() -> int:
	return data["chests"].size()


## First-hunt hint ids this save has already shown (see run_screen's HintLayer).
func hint_seen(id: String) -> bool:
	return str(id) in data["hints_seen"]


## Record a hint as shown and persist. Idempotent: the id is stored once.
func mark_hint(id: String) -> void:
	if str(id) in data["hints_seen"]:
		return
	data["hints_seen"].append(str(id))
	_write()


## Clash-style chest drawer: four slots. Earned chests arrive locked; the
## player taps one to start its timer (one unlocks at a time), and the
## timer scales with rarity. Reward chests (milestones, the slayer shop)
## arrive ready. The drawer never holds more than four: a chest that
## arrives with every slot taken pays out into the wallet instead of being
## lost (see pay_out).
const SLOTS := 4
const UNLOCK_SECONDS := {"common": 15 * 60, "rare": 60 * 60, "epic": 3 * 60 * 60}
const RARITY_OF_TONE := {"wood": "common", "silver": "rare", "magic": "epic", "gold": "epic"}

## How many payouts the save keeps: what each chest became when the drawer
## was full.
const PAYOUT_LOG_LIMIT := 10

## What the last hunt sent home: {"tone", "rarity", "full", "index",
## "payout"}. Not saved.
var last_chest: Dictionary = {}

## The payout waiting to be announced by the screen that earned it. Not
## saved; the save keeps the log of every payout.
var last_payout: Dictionary = {}


func _new_chest(kind: String, biome_id: String, timed: bool) -> Dictionary:
	var chest := {"kind": kind, "biome": biome_id, "seed": randi()}
	if not timed:
		chest["tone"] = "gold"
		chest["ready_at"] = 0
	return chest


## Put a chest in the drawer. The drawer holds SLOTS chests and no more, and
## the cap is never bypassed: a chest that arrives when every slot is taken
## cannot be stored, so it pays out into the wallet instead (see pay_out) and
## false comes back. No chest is ever lost.
func add_chest(chest: Dictionary) -> bool:
	if data["chests"].size() >= SLOTS:
		last_payout = pay_out(chest)
		return false
	chest["fresh"] = true
	data["chests"].append(chest)
	return true


## A chest with nowhere to go pays out instead of being lost: it opens on the
## spot and its loot is credited to the wallet (coins, with the relic stacks
## banked as coins, and gear shards) and any gear piece goes to its hero.
## The payout joins the log, so the player can still see what became what.
func pay_out(chest: Dictionary) -> Dictionary:
	var loot := _chest_loot(chest)
	var gear: Array = []
	for piece in loot.get("gear_items", []):
		if piece is Dictionary:
			gear.append(str(piece.get("id", "")))
	var paid := {
		"coins": int(loot.get("coins", 0)),
		"shards": int(loot.get("gear_shards", 0)),
		"gear": gear,
		"at": int(Time.get_unix_time_from_system()),
	}
	var log := payout_log()
	log.append(paid.duplicate(true))
	while log.size() > PAYOUT_LOG_LIMIT:
		log.pop_front()
	data["payouts"] = log
	return paid


## The payouts this save has made, newest last.
func payout_log() -> Array:
	var out: Variant = data.get("payouts", [])
	return out if typeof(out) == TYPE_ARRAY else []


## The newest payout on record, or {} when the drawer never turned one away.
func newest_payout() -> Dictionary:
	var log := payout_log()
	if log.is_empty():
		return {}
	var entry: Variant = log[log.size() - 1]
	return entry if typeof(entry) == TYPE_DICTIONARY else {}


## The payout waiting to be announced, taken once: the screen that earned it
## calls this so the same payout is never told twice.
func take_payout() -> Dictionary:
	var paid := last_payout
	last_payout = {}
	return paid


## What a payout paid, in one line: "128 coins", "128 coins + 5 shards",
## "128 coins + Iron Blade". Empty text for an empty payout.
func payout_text(payout: Dictionary) -> String:
	if payout.is_empty():
		return ""
	var parts := PackedStringArray()
	var coins := int(payout.get("coins", 0))
	if coins > 0:
		parts.append("%d coins" % coins)
	var shards := int(payout.get("shards", 0))
	if shards > 0:
		parts.append("%d shards" % shards)
	for piece in payout.get("gear", []):
		var id := str(piece)
		if piece is Dictionary:
			id = str(piece.get("id", ""))
		parts.append(str(GearDB.item(id).get("name", "gear")))
	if parts.is_empty():
		return "coins"
	return " + ".join(parts)


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


## The look of a chest: reward chests are gilded, pouches are plain wood, a
## hunt chest takes its biome's metal. Reads a chest that is not in the drawer
## yet, so a chest that pays out still knows what it looked like.
func chest_tone_of(chest: Dictionary) -> String:
	var tone := str(chest.get("tone", ""))
	if tone != "":
		return tone
	if str(chest.get("kind", "hunt")) == "scrap":
		return "wood"
	return {"meadow": "silver", "mushroom": "magic", "frost": "silver", "volcano": "gold"}.get(str(chest.get("biome", "meadow")), "silver")


## The look of chest i: pouches are plain wood, hunt chests take their
## biome's metal, reward chests are gilded.
func chest_tone(i: int) -> String:
	if i < 0 or i >= data["chests"].size():
		return "wood"
	return chest_tone_of(data["chests"][i])


func biome_cleared(id: String) -> bool:
	return bool(data["cleared"].get(id, false))


## Highest difficulty tier cleared on a biome (-1 = none). A Normal win records
## tier 0, which opens Veteran; clearing Veteran opens Nightmare.
func difficulty_cleared(biome_id: String) -> int:
	return int(_difficulty_map().get(biome_id, -1))


## Highest difficulty tier open on a biome (Catalog.Tier index). Normal (0) is
## always open; each cleared tier opens the one above.
func difficulty_unlocked(biome_id: String) -> int:
	return clampi(difficulty_cleared(biome_id) + 1, 0, Catalog.TIER_COUNT - 1)


func difficulty_open(biome_id: String, tier: int) -> bool:
	return tier >= 0 and tier < Catalog.TIER_COUNT and tier <= difficulty_unlocked(biome_id)


## Record a cleared tier for a biome (never downgrades). Returns true when this
## clear opened a new tier. Persisting is the caller's job (commit_victory).
func note_difficulty_clear(biome_id: String, tier: int) -> bool:
	var before := difficulty_unlocked(biome_id)
	var map := _difficulty_map()
	var clamped := clampi(tier, 0, Catalog.TIER_COUNT - 1)
	if clamped > int(map.get(biome_id, -1)):
		map[biome_id] = clamped
	return difficulty_unlocked(biome_id) > before


func _difficulty_map() -> Dictionary:
	if not data.has("difficulty_cleared") or typeof(data["difficulty_cleared"]) != TYPE_DICTIONARY:
		data["difficulty_cleared"] = {}
	return data["difficulty_cleared"]


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
	AudioDirector.sfx("levelup", -3.0)
	return true


## Grant hero_id the next piece for a legacy-style reward slot ("weapon",
## "armor" -> chest, "charm", or any GearDB slot) at the reward's rarity
## (common -> iron, rare/epic -> blackened steel, legendary -> rune). An
## owned tier steps up so a reward is never a dead duplicate. Returns the id.
func grant_reward(hero_id: String, slot: String, rarity: String) -> String:
	var gear_slot := str({"armor": "chest"}.get(slot, slot))
	var tier := int({"common": 1, "uncommon": 1, "rare": 2, "epic": 2, "legendary": 3}.get(rarity, 1))
	for t in range(tier, 4):
		var id := GearDB.item_id(hero_id, gear_slot, t)
		if GearDB.is_item(id) and not GearDB.has(hero_id, id):
			GearDB.grant(id)
			return id
	var fallback := GearDB.item_id(hero_id, gear_slot, tier)
	if GearDB.is_item(fallback):
		GearDB.grant(fallback)
		return fallback
	return ""


## The hero's run stats: Catalog base plus trained power (GearDB.level_bonus)
## plus worn, reinforced gear (GearDB.stats). Skill levels replaced the old
## coin/card Upgrade as the base-stat source, so a fresh hero (no skill bonus,
## no gear) comes out exactly Catalog.base_stats. The whole formula lives in
## GearDB; this only folds its two halves in.
func build_run_stats(hero_id: String) -> Dictionary:
	var stats := Catalog.base_stats(hero_id)
	var gear := GearDB.stats(hero_id)
	var bonus: Dictionary = GearDB.level_bonus(hero_id)
	for k in bonus:
		gear[k] = float(gear.get(k, 0.0)) + float(bonus[k])
	if gear.has("dmg_pct"):
		stats["dmg"] = float(stats["dmg"]) * (1.0 + float(gear["dmg_pct"]))
	if gear.has("haste"):
		stats["interval"] = float(stats["interval"]) / (1.0 + float(gear["haste"]))
	if gear.has("hp_pct"):
		stats["hp"] = float(stats["hp"]) * (1.0 + float(gear["hp_pct"]))
	if gear.has("hp_flat"):
		stats["hp"] = float(stats["hp"]) + float(gear["hp_flat"])
	if gear.has("armor"):
		stats["armor"] = float(stats["armor"]) + float(gear["armor"])
	if gear.has("crit"):
		stats["crit"] = float(stats["crit"]) + float(gear["crit"])
	if gear.has("speed_pct"):
		stats["speed"] = float(stats["speed"]) * (1.0 + float(gear["speed_pct"]))
	if gear.has("regen"):
		stats["regen"] = float(stats["regen"]) + float(gear["regen"])
	return stats


## --- Legacy gear migration ---------------------------------------------------
## v2 saves kept gear as uids on the hero row plus a bag of uid pieces. One
## load-time pass folds them into the GearDB armory (keys kept, stats now
## come from GearDB only):
##   weapon -> weapon, armor -> chest, charm -> charm
##   common/uncommon -> iron 1, rare/epic -> blackened steel 2,
##   legendary -> rune 3
## Equipped pieces go to the hero they were on and re-equip through
## GearDB.can_equip (a gated piece stays owned but off). Bag pieces convert
## for the featured hero. A piece with no GearDB counterpart (a hero without
## kit pieces or an unknown slot/rarity) pays out at 10 coins each. The
## pass stamps armory.migrated_from = old save version and never runs twice.

## Coins per unmapped legacy piece (about a pouch's quieter drop).
const LEGACY_COIN_RATE := 10

## Coins a relic/card drop pays at bank time. Relics no longer buy hero levels
## (skill XP does), so a card roll converts to coins instead of dead stock.
const RELIC_COINS := 15


## The GearDB item id one legacy uid piece converts to, or "" when none maps.
func _legacy_armory_item(hero_id: String, piece: Dictionary) -> String:
	var gear_slot := str({"weapon": "weapon", "armor": "chest", "charm": "charm"}.get(str(piece.get("slot", "")), ""))
	if gear_slot == "":
		return ""
	var tier := int({
		"common": GearDB.Tier.IRON, "uncommon": GearDB.Tier.IRON,
		"rare": GearDB.Tier.STEEL, "epic": GearDB.Tier.STEEL,
		"legendary": GearDB.Tier.RUNE,
	}.get(str(piece.get("rarity", "")), 0))
	if tier == 0:
		return ""
	var id := GearDB.item_id(hero_id, gear_slot, tier)
	return id if GearDB.is_item(id) else ""


## One legacy piece: a GearDB grant to hero_id, equipping it when it was
## equipped and the gates allow; unmappable pieces melt into coins.
func _convert_legacy_piece(hero_id: String, piece: Dictionary, was_equipped: bool) -> void:
	var id := _legacy_armory_item(hero_id, piece)
	if id == "":
		data["coins"] = int(data["coins"]) + LEGACY_COIN_RATE
		return
	GearDB.grant(id)
	if was_equipped and bool(GearDB.can_equip(hero_id, id)["ok"]):
		GearDB.equip(hero_id, id)


## Fold legacy uid gear into the armory once, for old_version saves. Safe to
## call again: it returns immediately once armory.migrated_from is stamped.
func migrate_legacy_armory(old_version: int) -> void:
	var existing: Variant = data.get(GearDB.SAVE_KEY)
	if typeof(existing) == TYPE_DICTIONARY and (existing as Dictionary).has("migrated_from"):
		_drop_legacy_gear()
		return
	var armory: Dictionary = existing if typeof(existing) == TYPE_DICTIONARY else {}
	data[GearDB.SAVE_KEY] = armory
	armory["v"] = GearDB.SAVE_V
	for k in ["owned", "equipped", "xp", "reinforce"]:
		if not armory.has(k) or typeof(armory[k]) != TYPE_DICTIONARY:
			armory[k] = {}
	var worn := {}
	for id in data["heroes"].keys():
		var row: Dictionary = data["heroes"][id]
		for legacy_slot in ["weapon", "armor", "charm"]:
			var uid := int(row.get(legacy_slot, 0))
			if uid <= 0:
				continue
			# Equipped pieces convert for their owner; the bag copy of the
			# same uid must not convert again.
			worn[uid] = true
			_convert_legacy_piece(id, _legacy_piece(uid), true)
	for piece in data.get("bag", []):
		if worn.has(int(piece.get("uid", 0))):
			continue
		_convert_legacy_piece(featured_id(), piece, false)
	armory["migrated_from"] = int(old_version)
	_drop_legacy_gear()


func _legacy_piece(uid: int) -> Dictionary:
	for entry in data.get("bag", []):
		if typeof(entry) == TYPE_DICTIONARY and int(entry.get("uid", 0)) == uid:
			return entry
	return {}


## The legacy Loadout is gone: once its pieces live in the armory, the bag,
## the uid counter and the per-hero weapon/armor/charm uids leave the save.
func _drop_legacy_gear() -> void:
	data.erase("bag")
	data.erase("gear_uid")
	for id in data.get("heroes", {}).keys():
		var row: Variant = data["heroes"][id]
		if typeof(row) == TYPE_DICTIONARY:
			for legacy_slot in ["weapon", "armor", "charm"]:
				(row as Dictionary).erase(legacy_slot)


## --- Training migration ------------------------------------------------------
## The old coin/card Upgrade scaled a hero's base hp and damage by
## 1 + 0.08 * (level - 1). Skill levels replace it as the power source, and
## build_run_stats no longer reads the card level at all. So an existing save
## does not lose power: once, each old upgrade level banks the equivalent skill
## XP (five levels of the damage skill and five Hitpoints levels per card
## level), which reproduces the old multiplier and keeps the level display.
## Heroes already at level 1 need nothing. The stamp (data["training_migrated"])
## makes the pass run exactly once; the migration never zeroes a wallet.

## Skill levels granted per old card level. The old card scale was 1 + 0.08
## per level; DAMAGE_PER_LEVEL/HP_PER_LEVEL are 0.016, so five skill levels per
## card level match it (and a magic hero, who trains both Strength and Magic,
## comes out ahead, never behind).
const TRAIN_LEVELS_PER_CARD := 5


func migrate_training() -> void:
	if bool(data.get("training_migrated", false)):
		return
	for id in data.get("heroes", {}).keys():
		var hero_id := str(id)
		var row: Variant = data["heroes"][id]
		if typeof(row) != TYPE_DICTIONARY:
			continue
		var level := int((row as Dictionary).get("level", 1))
		if level <= 1:
			continue
		# Damage: Strength for everyone; a magic/ranged weapon skill rides on
		# top for the heroes whose weapon uses it.
		var damage := mini(GearDB.MAX_LEVEL, 1 + TRAIN_LEVELS_PER_CARD * (level - 1))
		_grant_skill_xp(hero_id, "strength", damage)
		var hp := mini(GearDB.MAX_LEVEL, 10 + TRAIN_LEVELS_PER_CARD * (level - 1))
		_grant_skill_xp(hero_id, "hitpoints", hp)
		var ws: String = GearDB.WEAPON_SKILL.get(hero_id, "attack")
		if ws == "ranged" or ws == "magic":
			_grant_skill_xp(hero_id, ws, damage)
	# Stamp last: the grants above trigger writes, so a crash mid-pass leaves
	# the flag clear and the next load tops up (grants only ever add).
	data["training_migrated"] = true


## Banks the XP a skill needs to reach `target` (a no-op when it is already
## there or higher), so the migration only ever tops up.
func _grant_skill_xp(hero_id: String, skill: String, target: int) -> void:
	var shortfall := GearDB.xp_for_level(target) - GearDB.xp(hero_id, skill)
	if shortfall > 0:
		GearDB.add_xp(hero_id, skill, shortfall)


## Drops the gathering ids that are no longer skills. The gathering skills
## are Woodcutting, Fishing and Mining (Catalog.SKILLS); foraging, taming and
## crafting were placeholders that never had an XP source, so nothing is lost
## by dropping them. Fishing keeps its XP: the id did not change.
func migrate_gathering_skills() -> void:
	for sid in data["skills"].keys():
		if not GatheringDB.is_skill(str(sid)):
			data["skills"].erase(sid)


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


func commit_victory(biome_id: String, boss_id: String, slain: int = 0, tier: int = 0) -> Dictionary:
	var first := not biome_cleared(biome_id)
	data["cleared"][biome_id] = true
	# Clearing a tier opens the next one; a higher tier cleared at once (a
	# staged win) records up to that tier rather than only one step.
	var tier_opened := note_difficulty_clear(biome_id, tier)
	var gained := 30 if first else 16
	data["trophies"] = int(data["trophies"]) + gained
	data["kills"][boss_id] = int(data["kills"].get(boss_id, 0)) + 1
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var rolled := _roll_boss(boss_id, rng)
	var drops: Array = []
	var reveal := {}
	for entry in rolled:
		# The summary carries its own copy so _apply_drop can stamp the granted
		# result without ever touching the Catalog.DROPS constants.
		var drop: Dictionary = (entry as Dictionary).duplicate()
		_apply_drop(drop, rng, biome_id)
		drops.append(drop)
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
		"tier": clampi(tier, 0, Catalog.TIER_COUNT - 1),
		"tier_opened": tier_opened,
		"unlocked_tier": difficulty_unlocked(biome_id),
	}


## A daily won on a biome the player has not unlocked: the boss falls and the
## run scores, but the clear is daily-only. No cleared flag, trophies, boss
## kill or slayer progress, so it never unlocks the biome or advances
## progress. The hunt chest still comes home as the run's loot.
func commit_daily_pass(biome_id: String, boss_id: String) -> Dictionary:
	_send_home(_new_chest("hunt", biome_id, true))
	_write()
	return {"trophies": 0, "first": false, "boss": boss_id, "drops": [], "reveal": {}, "kills": boss_kills(boss_id)}


## A chest comes home to the drawer. The drawer holds SLOTS chests: with every
## slot taken the chest cannot be stored, so it pays out into the wallet
## instead of being dropped, and last_chest says what it paid.
func _send_home(chest: Dictionary) -> void:
	var tone := chest_tone_of(chest)
	var rarity := str(RARITY_OF_TONE.get(tone, "rare"))
	if data["chests"].size() >= SLOTS:
		# The drawer is full: the chest pays out rather than being lost. The
		# run card and Home say what it paid, so no menu screen repeats it.
		last_chest = {"tone": tone, "rarity": rarity, "full": true, "index": -1, "payout": pay_out(chest)}
		return
	add_chest(chest)
	var i: int = data["chests"].size() - 1
	last_chest = {"tone": chest_tone(i), "rarity": chest_rarity(i), "full": false, "index": i}


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
	return id in data.get("log", [])


## True while an entry has been found but not yet looked at in the log. The
## mark survives a restart because seen ids are written with the save.
func log_is_new(id: String) -> bool:
	var log: Array = data.get("log", [])
	if not (id in log):
		return false
	var seen: Array = data.get("log_seen", [])
	return not (id in seen)


## How many obtained entries the player has not looked at yet.
func log_new_count() -> int:
	var log: Array = data.get("log", [])
	var seen: Array = data.get("log_seen", [])
	var n := 0
	for id in log:
		if not (id in seen):
			n += 1
	return n


## Obtained entries that still exist in the catalog. A drop removed between
## builds is skipped rather than counted or drawn.
func log_obtained_count() -> int:
	var log: Array = data.get("log", [])
	var n := 0
	for id in log:
		if not Catalog.drop_by_id(str(id)).is_empty():
			n += 1
	return n


## Clear the unread mark once the log has shown the given ids (all of them
## when ids is empty). Written at once so it survives reopening the app.
func log_mark_seen(ids: Array = []) -> void:
	if typeof(data.get("log", null)) != TYPE_ARRAY:
		return
	if typeof(data.get("log_seen", null)) != TYPE_ARRAY:
		data["log_seen"] = []
	var seen: Array = data["log_seen"]
	var changed := false
	for id in data["log"]:
		if id in seen:
			continue
		if not ids.is_empty() and not (id in ids):
			continue
		seen.append(id)
		changed = true
	if changed:
		_write()


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


## Puts gathered materials in the bag and returns the new count. Materials are
## one pool for boss drops and gathered resources alike (see docs/gathering.md).
func add_material(id: String, amount: int) -> int:
	if id == "" or amount <= 0:
		return material_count(id)
	data["materials"][id] = material_count(id) + amount
	_write()
	return int(data["materials"][id])


## Puts a run's worth of gathered materials in the bag, in one write. Each row
## is {id, amount}, the shape the gathering drops come in.
func add_materials(drops: Array) -> void:
	var any := false
	for drop in drops:
		var id := str(drop.get("id", ""))
		var amount := int(drop.get("amount", 0))
		if id == "" or amount <= 0:
			continue
		data["materials"][id] = material_count(id) + amount
		any = true
	if any:
		_write()


## What one material is worth, in coins, and what a whole stack of it is
## worth. The prices live in MaterialDB, the one table for the whole bag.
func material_value(id: String, amount: int) -> int:
	return MaterialDB.value(id, amount)


## Sells materials out of the bag: the coins go into the wallet and the
## counts come down. `amount` is how many to sell; a negative amount sells
## the whole stack. Returns the coins paid, and 0 when nothing was sold (an
## unknown material, or an empty stack).
func sell_material(id: String, amount: int = -1) -> int:
	var have := material_count(id)
	var unit := MaterialDB.price(id)
	if have <= 0 or unit <= 0:
		return 0
	var sold := have if amount < 0 else mini(amount, have)
	if sold <= 0:
		return 0
	var coins := unit * sold
	if sold >= have:
		data["materials"].erase(id)
	else:
		data["materials"][id] = have - sold
	data["coins"] = int(data["coins"]) + coins
	_write()
	return coins


## Sells everything the bag holds in one write and returns the coins paid.
## A material with no price is left alone rather than thrown away.
func sell_all_materials() -> int:
	var total := 0
	for key in data["materials"].keys():
		var id := str(key)
		var count := material_count(id)
		var unit := MaterialDB.price(id)
		if count <= 0 or unit <= 0:
			continue
		total += unit * count
		data["materials"].erase(id)
	if total > 0:
		data["coins"] = int(data["coins"]) + total
		_write()
	return total


## How many items the bag holds, every kind together.
func bag_count() -> int:
	var total := 0
	for key in data["materials"].keys():
		total += material_count(str(key))
	return total


## What the whole bag is worth, in coins.
func bag_value() -> int:
	var total := 0
	for key in data["materials"].keys():
		var id := str(key)
		total += material_value(id, material_count(id))
	return total


# --- Gathering skills --------------------------------------------------------

## Gathering is account-wide, not per hero (docs/gathering.md): the XP for
## the three gathering skills lives in data["skills"], keyed by skill id, and
## the level comes from the OSRS curve in Catalog.skill_level.

## XP banked in a gathering skill. Unknown skills read 0.
func gathering_xp(skill: String) -> int:
	if not GatheringDB.is_skill(skill):
		return 0
	return int(data["skills"].get(skill, 0))


## Level of a gathering skill (1-99 on the OSRS curve).
func gathering_level(skill: String) -> int:
	return Catalog.skill_level(gathering_xp(skill))


## {skill_id: level} for every gathering skill.
func gathering_skills() -> Dictionary:
	var out := {}
	for entry in Catalog.SKILLS:
		var id := str(entry["id"])
		out[id] = gathering_level(id)
	return out


## True when the account has reached `level` in a gathering skill.
func gathering_reached(skill: String, level: int) -> bool:
	return gathering_level(skill) >= level


## Adds gathering XP and returns the levels gained (0 for an unknown skill or
## a bad amount, and for a skill already at the top of the curve). Writes the
## save.
func add_gathering_xp(skill: String, amount: int) -> int:
	if not GatheringDB.is_skill(skill) or amount <= 0:
		return 0
	var before := gathering_level(skill)
	# The curve ends at 99, so XP past it is never banked.
	var cap := Catalog.skill_xp_to_level(Catalog.MAX_SKILL_LEVEL)
	data["skills"][skill] = mini(gathering_xp(skill) + amount, cap)
	_write()
	return gathering_level(skill) - before


func assign_task(task_id: String = "") -> Dictionary:
	if not data.has("slayer") or typeof(data["slayer"]) != TYPE_DICTIONARY:
		return {}
	var pick := {}
	if task_id != "":
		pick = Catalog.slayer_task(task_id).duplicate()
	else:
		var choices: Array = []
		var current := _log_slayer_task_id()
		var last := str(data["slayer"].get("last", ""))
		for entry in Catalog.SLAYER_TASKS:
			var entry_id := str(entry["id"])
			# A contract never comes straight back, and the warden only sends
			# hunters into ground the player has actually opened.
			if entry_id == current or entry_id == last:
				continue
			if not biome_open(str(entry["biome"])):
				continue
			choices.append(entry)
		if choices.is_empty():
			return {}
		pick = (choices[randi() % choices.size()] as Dictionary).duplicate()
	if pick.is_empty():
		return {}
	var previous := _log_slayer_task_id()
	if previous != "" and previous != str(pick.get("id", "")):
		data["slayer"]["last"] = previous
	pick["have"] = 0
	data["slayer"]["task"] = pick
	_write()
	AudioDirector.play("click")
	return pick


## The id of the task in hand, or "" when there is none (and never a crash on
## an old save whose task key is missing or malformed).
func _log_slayer_task_id() -> String:
	var task: Variant = data["slayer"].get("task", {})
	if typeof(task) != TYPE_DICTIONARY:
		return ""
	return str((task as Dictionary).get("id", ""))


func cancel_task() -> void:
	if not data.has("slayer") or typeof(data["slayer"]) != TYPE_DICTIONARY:
		return
	var previous := _log_slayer_task_id()
	if previous != "":
		data["slayer"]["last"] = previous
	data["slayer"]["task"] = {}
	data["slayer"]["streak"] = 0
	_write()
	# The contract is dropped and the streak with it: a wrong note, not a
	# quiet one.
	AudioDirector.sfx("ui_error")


func complete_task() -> int:
	if not data.has("slayer") or typeof(data["slayer"]) != TYPE_DICTIONARY:
		return 0
	var task: Variant = data["slayer"].get("task", {})
	if typeof(task) != TYPE_DICTIONARY or (task as Dictionary).is_empty():
		AudioDirector.play("error")
		return 0
	var t: Dictionary = task
	if int(t.get("have", 0)) < int(t.get("need", 1)):
		AudioDirector.play("error")
		return 0
	# Pay exactly once: the contract is cleared and marked before the save, so
	# reopening the screen or restarting can never pay the same task again.
	var streak := int(data["slayer"].get("streak", 0))
	var gained := int(t.get("points", 0)) + streak * 5
	data["slayer"]["points"] = int(data["slayer"].get("points", 0)) + gained
	data["slayer"]["streak"] = streak + 1
	data["slayer"]["last"] = str(t.get("id", ""))
	data["slayer"]["task"] = {}
	# Every 5th consecutive turn-in also pays one earned gear piece, the same
	# roll the Warden's cache uses; the slayer screen reads the result for its
	# toast.
	last_streak_reward = {}
	if (streak + 1) % 5 == 0:
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		var piece := _cache_piece(featured_id(), rng)
		if piece != "":
			GearDB.grant(piece)
			last_streak_reward = {"item": piece}
		else:
			data["coins"] = int(data["coins"]) + CACHE_COINS
			last_streak_reward = {"coins": CACHE_COINS}
	_write()
	# Slayer points are a payout: the coin sound says "paid".
	AudioDirector.sfx("coin")
	return gained


## Coin consolation when a cache or streak reward finds a full kit: the warden
## still pays, in coins.
const CACHE_COINS := 25


## What the last turn-in's streak reward granted, for the slayer screen toast:
## {"item": id} or {"coins": 25}, {} when this turn-in granted nothing.
var last_streak_reward: Dictionary = {}


## The cache tier: one roll on the deepest opened biome's boss weights — the
## richest hunt the player can currently take — with rune pressed back down
## to steel, so a slayer reward can never pay the top tier.
func _cache_tier(rng: RandomNumberGenerator) -> int:
	var deepest := 0
	for i in Catalog.BIOMES.size():
		if biome_open(str(Catalog.BIOMES[i]["id"])):
			deepest = i
	var weights: Array = LootTable._weights(LootTable.SOURCES["boss"]["weights"], deepest, "boss")
	return mini(LootTable._tier(rng, weights), GearDB.Tier.STEEL)


## One Warden's-cache piece for hero_id, or "" when the hero already owns
## every eligible piece (iron and blackened steel only; rune is never in the
## cache). The slot prefers an unowned slot, then the rolled tier, then the
## best tier still missing, then kit order.
func _cache_piece(hero_id: String, rng: RandomNumberGenerator) -> String:
	var tier := _cache_tier(rng)
	var best := ""
	var best_rank := -1
	for slot in GearDB.HERO_SLOTS.get(hero_id, []):
		var slot_key := str(slot)
		var bare := true
		for t in range(GearDB.Tier.IRON, GearDB.Tier.STEEL + 1):
			var id := GearDB.item_id(hero_id, slot_key, t)
			if GearDB.has(hero_id, id):
				bare = false
				continue
			# Gift order: bare slot, on-roll tier, richer tier, kit order.
			var rank := (8 if bare else 0) + (4 if t == tier else 0) + t
			if rank > best_rank:
				best_rank = rank
				best = id
	return best


func buy_slayer(offer_id: String) -> bool:
	var offer := Catalog.slayer_offer(offer_id)
	if offer.is_empty() or int(data["slayer"]["points"]) < int(offer["cost"]):
		AudioDirector.play("error")
		return false
	data["slayer"]["points"] = int(data["slayer"]["points"]) - int(offer["cost"])
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	match str(offer["kind"]):
		# The Warden's cache grants one earned piece for the featured hero; a
		# full kit pays the coin consolation instead.
		"gear":
			var piece := _cache_piece(featured_id(), rng)
			if piece == "":
				data["coins"] = int(data["coins"]) + CACHE_COINS
			else:
				GearDB.grant(piece)
		"cosmetic":
			data["cosmetic"] = str(offer.get("cosmetic", "ribbon"))
		"chest":
			# A bought chest is a promised prize: with the drawer full it
			# pays out into the wallet rather than being lost.
			add_chest(_new_chest("hunt", "meadow", false))
	_write()
	# The warden takes the points and hands something over: coins jingle,
	# a chest opens, a piece clanks into the armory.
	match str(offer["kind"]):
		"chest":
			AudioDirector.sfx("chest_open")
		"gear":
			AudioDirector.sfx("gear_equip")
		_:
			AudioDirector.sfx("coin")
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


func _apply_drop(drop: Dictionary, rng: RandomNumberGenerator, biome_id := "") -> void:
	var id := str(drop["id"])
	if biome_id == "":
		for entry in Catalog.BIOMES:
			if str(entry["boss"]) == str(drop.get("boss", "")):
				biome_id = str(entry["id"])
				break
	match str(drop["kind"]):
		"coins":
			data["coins"] = int(data["coins"]) + int(drop.get("amount", 0))
		"material":
			data["materials"][id] = int(data["materials"].get(id, 0)) + int(drop.get("amount", 1))
		"cards":
			# Relics no longer buy hero levels (skill XP does), so a card drop
			# banks as coins at its coin value instead of dead stock.
			data["coins"] = int(data["coins"]) + int(drop.get("amount", 1)) * RELIC_COINS
		"gear":
			drop["granted"] = _grant_boss_gear(drop, biome_id)
		"pet":
			data["pets"][id] = true
			if str(data.get("active_pet", "")) == "":
				data["active_pet"] = id
	if id not in data["log"]:
		data["log"].append(id)


## A boss gear row pays inside the loot tier caps: its gear_rarity sets the
## wanted tier (common/uncommon iron, rare/epic steel, legendary rune), clamped
## to the boss cap for the biome's depth (meadow is iron only, mushroom adds
## steel, frost adds rune). The run's hero gets an unowned piece of the row's
## slot at that tier, else the best lower tier; when every piece up to the cap
## is owned it banks through the duplicate path (shards, or coins on a complete
## tier) instead of a second copy. Returns the _bank_gear_piece-style result.
func _grant_boss_gear(drop: Dictionary, biome_id: String) -> Dictionary:
	var hero := featured_id()
	var slot := str(drop.get("slot", "charm"))
	var gear_slot := str({"armor": "chest"}.get(slot, slot))
	var biome_idx := 0
	for i in Catalog.BIOMES.size():
		if str(Catalog.BIOMES[i]["id"]) == biome_id:
			biome_idx = i
			break
	var wanted := int({
		"common": GearDB.Tier.IRON, "uncommon": GearDB.Tier.IRON,
		"rare": GearDB.Tier.STEEL, "epic": GearDB.Tier.STEEL,
		"legendary": GearDB.Tier.RUNE,
	}.get(str(drop.get("gear_rarity", "common")), GearDB.Tier.IRON))
	var cap := mini(wanted, LootTable.max_tier("boss", biome_idx))
	for t in range(cap, GearDB.Tier.IRON - 1, -1):
		var id := GearDB.item_id(hero, gear_slot, t)
		if GearDB.is_item(id) and not GearDB.has(hero, id):
			GearDB.grant(id)
			return {"kind": "gear", "id": id, "amount": 1}
	return _bank_gear_piece(GearDB.item_id(hero, gear_slot, cap))


## Record one run's kills against the task in hand. Called once, at run end,
## from either commit path; the goal is a hard ceiling and kills only count for
## the task's own biome, so a minion task and its boss can never double-dip.
func _note_slayer(biome_id: String, slain: int, boss: bool) -> void:
	if not data.has("slayer") or typeof(data["slayer"]) != TYPE_DICTIONARY:
		return
	var task: Variant = data["slayer"].get("task", {})
	if typeof(task) != TYPE_DICTIONARY or (task as Dictionary).is_empty():
		return
	var t: Dictionary = task
	if str(t.get("biome", "")) != biome_id:
		return
	var need := int(t.get("need", 0))
	var have := int(t.get("have", 0))
	if str(t.get("kind", "")) == "minion":
		t["have"] = mini(need, have + maxi(0, slain))
	elif str(t.get("kind", "")) == "boss" and boss:
		t["have"] = mini(need, have + 1)


func open_next(index: int = 0) -> Dictionary:
	if index < 0 or index >= data["chests"].size():
		return {}
	var chest: Dictionary = data["chests"].pop_at(index)
	var loot := _chest_loot(chest)
	_write()
	return loot


## What a chest pays when it opens: coins (with the relic stacks banked as
## coins), gear shards and any gear piece it rolled. The chest's own seed
## fixes the roll, so a chest that pays out because the drawer was full pays
## exactly what it would have paid there.
func _chest_loot(chest: Dictionary) -> Dictionary:
	var loot := _roll_loot(chest)
	# Drawer chests also roll earned gear, by rarity, from the chest's own seed
	# so the drop is fixed the moment the chest is earned. The gear hero is
	# whoever is currently selected. Existing rewards above stay unchanged.
	var rng := RandomNumberGenerator.new()
	rng.seed = int(chest.get("seed", 0))
	var tone := chest_tone_of(chest)
	var biome_id := str(chest.get("biome", "meadow"))
	var biome_idx := 0
	for i in Catalog.BIOMES.size():
		if str(Catalog.BIOMES[i]["id"]) == biome_id:
			biome_idx = i
			break
	var gear_items: Array = []
	var gear_shards := 0
	var gear_coins := 0
	for id in LootTable.roll(rng, "chest_" + str(RARITY_OF_TONE.get(tone, "rare")), featured_id(), biome_idx):
		var res := _bank_gear_piece(str(id))
		match str(res.get("kind", "")):
			"gear":
				gear_items.append({"kind": "gear", "id": str(id)})
			"shards":
				gear_shards += int(res["amount"])
			"coins":
				gear_coins += int(res["amount"])
	loot["coins"] = int(loot.get("coins", 0)) + gear_coins
	loot["gear_items"] = gear_items
	loot["gear_shards"] = gear_shards
	return loot


## Shard and coin payouts by tier (index = GearDB.Tier) for a duplicate roll.
## A hero who already owns every item of a tier has nothing left to earn there,
## so its duplicates pay coins instead of shards.
const GEAR_SHARDS: Array[int] = [0, 5, 15, 40]
const GEAR_DUP_COINS: Array[int] = [0, 10, 25, 60]


## Grant earned gear ids to their heroes, one copy each, once. A duplicate (the
## hero already owns the piece, or an earlier id in this same list banked it)
## melts into gear shards; if the hero already owns every item of that tier the
## roll pays coins instead. Unknown ids are skipped. Drop tables and rolling
## live in LootTable; this only banks the run. Returns
## {"ids": [granted item ids], "shards": total shards, "coins": total coins},
## the end card reads for the shard/coin spoils.
func bank_gear(ids: Array) -> Dictionary:
	var banked: Array[String] = []
	var shards := 0
	var coins := 0
	for id in ids:
		var res := _bank_gear_piece(str(id))
		match str(res.get("kind", "")):
			"gear":
				banked.append(str(id))
			"shards":
				shards += int(res["amount"])
			"coins":
				coins += int(res["amount"])
	_write()
	return {"ids": banked, "shards": shards, "coins": coins}


## Bank one rolled piece. A new piece is granted as gear; a duplicate pays
## shards, or coins when hero already owns every item of that tier. Returns
## {"kind": "gear"|"shards"|"coins", "id": id, "amount": n}, or {} if unknown.
func _bank_gear_piece(id: String) -> Dictionary:
	var it := GearDB.item(id)
	if it.is_empty():
		return {}
	var hero := str(it["hero"])
	var tier := int(it["tier"])
	if not GearDB.has(hero, id):
		GearDB.grant(id)
		return {"kind": "gear", "id": id, "amount": 1}
	if _owns_tier(hero, tier):
		data["coins"] = int(data.get("coins", 0)) + GEAR_DUP_COINS[tier]
		return {"kind": "coins", "id": id, "amount": GEAR_DUP_COINS[tier]}
	data["gear_shards"] = int(data.get("gear_shards", 0)) + GEAR_SHARDS[tier]
	return {"kind": "shards", "id": id, "amount": GEAR_SHARDS[tier]}


## True when hero already owns every GearDB item of a tier.
func _owns_tier(hero: String, tier: int) -> bool:
	for slot in GearDB.HERO_SLOTS.get(hero, []):
		if not GearDB.has(hero, GearDB.item_id(hero, str(slot), tier)):
			return false
	return true


## --- The Forge ---------------------------------------------------------------
## Shards from duplicate rolls buy the pieces a hunt has not handed over yet.
## A tier opens once the player has opened ground deep enough to drop it (the
## boss cap, LootTable.max_tier), so a meadow-only player can forge iron but
## must reach Mushroom for blackened steel and Frost for cursed rune.

## Shard price per tier (index = GearDB.Tier), about four times the duplicate
## refund, so forging stays a deliberate sink rather than the fast road.
const FORGE_COST: Array[int] = [0, 20, 60, 160]


## The deepest biome the player has opened, as an index into Catalog.BIOMES.
func forge_depth() -> int:
	var deepest := 0
	for i in Catalog.BIOMES.size():
		if biome_open(str(Catalog.BIOMES[i]["id"])):
			deepest = i
	return deepest


## The best tier the Forge can make right now: the boss cap at the deepest
## opened biome.
func forge_cap() -> int:
	return LootTable.max_tier("boss", forge_depth())


## Every UNOWNED piece of a hero's kit at or below forge_cap(), best tier
## first, as {id, slot, tier, cost, ok, reason}. A piece the wallet cannot
## afford carries its shortfall, "Need 40 more shards", and ok stays false.
func forge_options(hero: String) -> Array:
	var out: Array = []
	if not GearDB.HERO_SLOTS.has(hero):
		return out
	var shards := int(data.get("gear_shards", 0))
	for tier in range(forge_cap(), GearDB.Tier.IRON - 1, -1):
		for slot in GearDB.HERO_SLOTS[hero]:
			var id := GearDB.item_id(hero, str(slot), tier)
			if not GearDB.is_item(id) or GearDB.has(hero, id):
				continue
			var cost := FORGE_COST[tier]
			var reason := forge_skill_gate(hero, id)
			if reason == "" and shards < cost:
				reason = "Need %d more shards" % (cost - shards)
			out.append({
				"id": id, "slot": str(slot), "tier": tier, "cost": cost, "ok": reason == "",
				"reason": reason,
			})
	return out


## The forge respects the same skill gates as wearing: a piece whose
## requirement the hero has not trained ("Requires Defence 20") cannot be
## forged yet. "" when every requirement is met.
func forge_skill_gate(hero: String, id: String) -> String:
	var req := GearDB.requirements(id)
	for k in GearDB.SKILL_KEYS:
		if req.has(k) and GearDB.level(hero, k) < int(req[k]):
			return "Requires %s %d" % [GearDB.SKILL_NAMES[GearDB.SKILL_KEYS.find(k)], int(req[k])]
	return ""


## Why a tier cannot be forged yet, or "" when it can. Uses the biome that
## first drops the tier ("Reach Frost to forge rune").
func forge_lock_reason(tier: int) -> String:
	if tier < GearDB.Tier.IRON or tier > GearDB.Tier.RUNE or tier <= forge_cap():
		return ""
	for i in Catalog.BIOMES.size():
		if LootTable.max_tier("boss", i) >= tier:
			return "Reach %s to forge %s" % [str(Catalog.BIOMES[i]["name"]).split(" ")[0], GearDB.TIER_KEYS[tier]]
	return ""


## Forge one unowned piece for a hero, paying its shard cost. Refuses an
## unknown or foreign id, a piece the hero already owns, a tier above the
## current cap, an untrained skill gate and an unaffordable price. On success
## it grants the piece, deducts the shards and writes once; the wallet never
## goes negative and a refused grant never costs shards.
func forge(hero: String, id: String) -> bool:
	var it := GearDB.item(id)
	if it.is_empty() or str(it["hero"]) != hero:
		return false
	var tier := int(it["tier"])
	if tier > forge_cap() or GearDB.has(hero, id) or forge_skill_gate(hero, id) != "":
		return false
	var cost := FORGE_COST[tier]
	var shards := int(data.get("gear_shards", 0))
	if shards < cost:
		return false
	if not GearDB.grant(id):
		return false
	data["gear_shards"] = shards - cost
	_write()
	return true


## --- Home attention pips -----------------------------------------------------
## Read-only queries behind the small "something to do" dots on Home. Each one
## reads existing state only, so a pip can never drift from the screen it points
## at. Keyed by state, never by hero id.

## True while the given hero has a Forge option they can afford right now.
func forge_ready(hero: String) -> bool:
	for option in forge_options(hero):
		if bool(option.get("ok", false)):
			return true
	return false


## True while any mastery trophy is earned and still unclaimed.
func mastery_ready() -> bool:
	for trophy in Catalog.SKILL_TROPHIES:
		if bool(mastery_state(trophy, "claim").get("ok", false)):
			return true
	return false


## True while the contract in hand has reached its need and waits to be turned
## in: the same test slayer_screen enables TURN IN with. No task, or one still
## short, reads false.
func slayer_ready() -> bool:
	if not data.has("slayer") or typeof(data["slayer"]) != TYPE_DICTIONARY:
		return false
	var task: Variant = data["slayer"].get("task", {})
	if typeof(task) != TYPE_DICTIONARY or (task as Dictionary).is_empty():
		return false
	var t: Dictionary = task
	return int(t.get("have", 0)) >= int(t.get("need", 1))


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
			# A claimed prize is never thrown away: with the drawer full it
			# pays out into the wallet instead.
			add_chest(_new_chest("hunt", "meadow", false))
		"unlock":
			# Relics no longer buy hero levels, so the joining bonus pays coins.
			data["heroes"][str(entry["hero"])]["unlocked"] = true
			data["coins"] = int(data["coins"]) + int(entry["cards"]) * RELIC_COINS
		"gear":
			grant_reward(featured_id(), str(entry["slot"]), str(entry["rarity"]))
	_write()
	# The sound follows the prize: coins jingle, a chest opens, a relic
	# joins the roster.
	match str(entry["kind"]):
		"coins":
			AudioDirector.sfx("coin")
		"chest":
			AudioDirector.sfx("chest_open")
		_:
			AudioDirector.sfx("card_pick")
	return true


## --- Mastery trophies --------------------------------------------------------
## Progress for the SKILL_TROPHIES table is derived from GearDB each time it
## is asked for (no new counters). Claims live in data["mastery_claimed"],
## an array that reconciles in for old saves.

## Slots a hero has at a tier: owned (iron) or worn (blackened steel).
func _kit_count(hero: String, tier: int, equipped: bool) -> int:
	var count := 0
	for slot in GearDB.HERO_SLOTS.get(hero, []):
		var id := GearDB.item_id(hero, str(slot), tier)
		var met := GearDB.slot_tier(hero, str(slot)) == tier if equipped else GearDB.has(hero, id)
		if met:
			count += 1
	return count


## The fullest kit any one hero has. {count, slots, ok} for one hero being
## fully kitted, exactly as the trophy asks.
func _best_kit(tier: int, equipped: bool) -> Dictionary:
	var best := {"count": 0, "slots": 0}
	for hero in GearDB.HERO_SLOTS.keys():
		var count := _kit_count(str(hero), tier, equipped)
		if count > int(best["count"]):
			best = {"count": count, "slots": int((GearDB.HERO_SLOTS[str(hero)] as Array).size())}
	best["ok"] = int(best["count"]) > 0 and int(best["count"]) >= int(best["slots"])
	return best


## The top combat skill any hero has actually trained (an XP row in the
## armory), so the Hitpoints starting-10 never satisfies a blood trophy.
func _best_skill(need: int) -> Dictionary:
	var xp: Dictionary = GearDB._store()["xp"]
	var best := ""
	var best_level := 0
	for hero in GearDB.HERO_SLOTS.keys():
		var row: Dictionary = xp.get(hero, {})
		if typeof(row) != TYPE_DICTIONARY:
			continue
		for key in GearDB.SKILL_KEYS:
			if not row.has(key):
				continue
			var level := GearDB.level(str(hero), key)
			if level > best_level:
				best_level = level
				best = key
	return {"skill": best, "level": best_level, "need": need, "ok": best_level >= need}


## A hero's OSRS combat level, the same formula the Skills screen prints.
func combat_level(hero: String) -> int:
	return SkillsScreen.combat_level(GearDB.skills(hero))


func _best_combat(need: int) -> Dictionary:
	var best := 2
	for hero in GearDB.HERO_SLOTS.keys():
		best = maxi(best, combat_level(str(hero)))
	return {"level": best, "need": need, "ok": best >= need}


## The crew's summed combat-skill levels, every armory hero read raw.
func _best_total(need: int) -> Dictionary:
	var total := 0
	for hero in GearDB.HERO_SLOTS.keys():
		for key in GearDB.SKILL_KEYS:
			total += GearDB.level(str(hero), key)
	return {"total": total, "need": need, "ok": total >= need}


func _rune_owned() -> bool:
	for hero in GearDB.HERO_SLOTS.keys():
		for id in GearDB.owned(str(hero)):
			if int(id.get_slice(".", 2)) == GearDB.Tier.RUNE:
				return true
	return false


## Readiness plus the numbers a row prints ("Defence 14 / 20"). whence "claim"
## also requires the trophy to be unclaimed, so it pays exactly once.
func mastery_state(trophy: Dictionary, whence := "") -> Dictionary:
	var req := str(trophy.get("req", ""))
	var need := int(trophy.get("need", 1))
	var out := {}
	match req:
		"skill":
			out = _best_skill(need)
		"combat":
			out = _best_combat(need)
		"iron_kit":
			out = _best_kit(GearDB.Tier.IRON, false)
		"steel_kit":
			out = _best_kit(GearDB.Tier.STEEL, true)
		"rune":
			out = {"count": 1 if _rune_owned() else 0, "ok": _rune_owned()}
		"total":
			out = _best_total(need)
		_:
			out = {"ok": false}
	out["id"] = str(trophy.get("id", ""))
	out["req"] = req
	out["need"] = need
	if whence == "claim":
		out["ok"] = bool(out.get("ok", false)) and str(out["id"]) not in mastery_claimed()
	return out


## "Defence 14 / 20", "Combat 21 / 30", "Iron 5 / 8" — the live requirement
## a mastery row prints, or "" for an unknown id.
func mastery_progress(trophy: Dictionary) -> String:
	var state := mastery_state(trophy)
	match str(state["req"]):
		"skill":
			var skill_name := str(state["skill"])
			if skill_name == "":
				return "0 / %d" % int(state["need"])
			return "%s %d / %d" % [GearDB.SKILL_NAMES[GearDB.SKILL_KEYS.find(skill_name)], int(state["level"]), int(state["need"])]
		"combat":
			return "Combat %d / %d" % [int(state["level"]), int(state["need"])]
		"iron_kit":
			return "Iron %d / %d" % [int(state["count"]), maxi(int(state["slots"]), int(state["need"]))]
		"steel_kit":
			return "Steel %d / %d" % [int(state["count"]), maxi(int(state["slots"]), int(state["need"]))]
		"rune":
			return "Rune %d / 1" % int(state["count"])
		"total":
			return "Total %d / %d" % [int(state["total"]), int(state["need"])]
	return ""


## The plain requirement a locked mastery row shows, greyed, before it is
## ready: what has to happen for the trophy to turn.
func mastery_requirement(trophy: Dictionary) -> String:
	var need := int(trophy.get("need", 0))
	match str(trophy.get("req", "")):
		"skill":
			return "Any combat skill %d" % need
		"combat":
			return "Combat level %d" % need
		"iron_kit":
			return "One hero owns a full iron kit"
		"steel_kit":
			return "One hero wears full blackened steel"
		"rune":
			return "Own one cursed rune piece"
		"total":
			return "Crew total level %d" % need
	return "Unknown trophy"


## Id of the deepest biome the player has opened ("meadow" at worst).
func _deepest_open_biome() -> String:
	var biome := "meadow"
	for b in Catalog.BIOMES:
		if biome_open(str(b["id"])):
			biome = str(b["id"])
	return biome


## Ids of already-claimed mastery trophies. Old saves start empty.
func mastery_claimed() -> Array:
	var out: Variant = data.get("mastery_claimed", [])
	return out if typeof(out) == TYPE_ARRAY else []


func mastery_is_claimed(id: String) -> bool:
	return str(id) in mastery_claimed()


## Claim a mastery trophy once: pays coins or a chest, never gear.
## False when the trophy is unknown, unearned or already claimed.
func claim_mastery(id: String) -> bool:
	var trophy := Catalog.skill_trophy(id)
	if trophy.is_empty():
		return false
	if not bool(mastery_state(trophy, "claim")["ok"]):
		return false
	var claimed := mastery_claimed()
	claimed.append(str(id))
	data["mastery_claimed"] = claimed
	var reward: Dictionary = trophy.get("reward", {})
	match str(reward.get("kind", "coins")):
		"coins":
			data["coins"] = int(data["coins"]) + int(reward.get("amount", 0))
		"chest":
			# A hunt chest from the deepest open ground, so a late trophy's
			# chest can hold the tiers the player is hunting now. With the
			# drawer full it pays out into the wallet instead.
			add_chest(_new_chest("hunt", _deepest_open_biome(), false))
	_write()
	# The sound follows the prize: coins jingle, a chest opens.
	match str(reward.get("kind", "coins")):
		"coins":
			AudioDirector.sfx("coin")
		"chest":
			AudioDirector.sfx("chest_open")
		_:
			AudioDirector.sfx("card_pick")
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
	# The old drawer also rolled relic/card stacks per hero. Relics no longer
	# buy hero levels, so those rolls bank as coins; the rng is still drawn the
	# same way (id then amount) so a given chest seed still pays the same total.
	var drops: Array = []
	var count := rng.randi_range(3, 5) if hunt else rng.randi_range(1, 2)
	for _i in count:
		var id: String = str(pool[rng.randi() % pool.size()])
		var cards := rng.randi_range(1, 3) if hunt else 1
		drops.append({"id": id, "count": cards})
	var relic_coins := 0
	for drop in drops:
		relic_coins += int(drop["count"]) * RELIC_COINS
	data["coins"] = int(data["coins"]) + coins + relic_coins
	return {
		"coins": coins + relic_coins,
		"cards": [],
		"biome": str(chest.get("biome", "meadow")),
		"kind": str(chest.get("kind", "hunt")),
	}


func _fresh() -> Dictionary:
	var heroes := {}
	for id in Catalog.playable_ids():
		var unlocked: bool = str(id) in STARTERS
		heroes[id] = {
			"unlocked": unlocked,
			"cards": 1 if unlocked else 0,
			"level": 1,
		}
	# Gathering XP, one entry per gathering skill (Catalog.SKILLS).
	var skills := {}
	for entry in Catalog.SKILLS:
		skills[str(entry["id"])] = 0
	return {
		"save_version": VERSION,
		"coins": 30,
		"gear_shards": 0,
		"trophies": 0,
		"claimed": [],
		"cleared": {},
		"difficulty_cleared": {},
		"chests": [],
		# What each chest paid out when the drawer was full, newest last.
		"payouts": [],
		"clan_id": "",
		"duel_rating": 0,
		"featured": "pebble",
		"heroes": heroes,
		"kills": {},
		"log": [],
		"log_seen": [],
		"pets": {},
		"active_pet": "",
		"materials": {},
		"cosmetic": "",
		"mastery_claimed": [],
		"slayer": {"points": 0, "streak": 0, "task": {}},
		"skills": skills,
		"daily": {},
		"pending_upload": [],
		# Player options: AudioDirector merges its own values and clamps what
		# it loads, so the save layer only guards the container here.
		"settings": {},
		# First-hunt guidance hints already shown, by hint id.
		"hints_seen": [],
		# True once the old card-level power has been banked as skill XP; a
		# fresh save has nothing to migrate (see migrate_training).
		"training_migrated": true,
	}


func _reconcile() -> void:
	# Unknown keys in a loaded save are left alone here, so data added by a
	# later version survives a downgrade/upgrade round trip. Known structures
	# get their defaults filled in.
	data["save_version"] = VERSION
	if not data.has("heroes"):
		data["heroes"] = {}
	for key in ["claimed", "chests"]:
		if not data.has(key) or typeof(data[key]) != TYPE_ARRAY:
			data[key] = []
	# The payout log: what each chest became when the drawer was full. An old
	# save has never turned a chest away, so it starts empty.
	if not data.has("payouts") or typeof(data["payouts"]) != TYPE_ARRAY:
		data["payouts"] = []
	if not data.has("cleared") or typeof(data["cleared"]) != TYPE_DICTIONARY:
		data["cleared"] = {}
	# Per-biome highest cleared difficulty tier. Old saves start at none.
	if not data.has("difficulty_cleared") or typeof(data["difficulty_cleared"]) != TYPE_DICTIONARY:
		data["difficulty_cleared"] = {}
	# An old or trimmed save can be missing the wallet; biome gating and card
	# levelling read these directly, so they must never be absent.
	if not data.has("coins"):
		data["coins"] = 0
	if not data.has("gear_shards"):
		data["gear_shards"] = 0
	if not data.has("trophies"):
		data["trophies"] = 0
	if not data.has("clan_id"):
		data["clan_id"] = ""
	if not data.has("duel_rating"):
		data["duel_rating"] = 0
	if not data.has("featured"):
		data["featured"] = "pebble"
	# Retired animal heroes: a save that had one equipped moves to Aldric.
	if str(data["featured"]) in RETIRED:
		data["featured"] = "pebble"
	for rid in RETIRED:
		if data["heroes"].has(rid):
			data["heroes"].erase(rid)
	for key in ["log"]:
		if not data.has(key) or typeof(data[key]) != TYPE_ARRAY:
			data[key] = []
	# Unread log markers. An old save has no record of which finds were already
	# looked at, so what it owns counts as read and only new finds get marked.
	if not data.has("log_seen") or typeof(data["log_seen"]) != TYPE_ARRAY:
		data["log_seen"] = (data["log"] as Array).duplicate()
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
	# Mastery trophies claim into their own array; an old save starts empty.
	if not data.has("mastery_claimed") or typeof(data["mastery_claimed"]) != TYPE_ARRAY:
		data["mastery_claimed"] = []
	# Old saves predate the settings block: it returns empty and every
	# option falls back to its AudioDirector default.
	if not data.has("settings") or typeof(data["settings"]) != TYPE_DICTIONARY:
		data["settings"] = {}
	# Old saves predate the hint tracking: reconcile to empty, so existing
	# players still see each first-hunt hint once.
	if not data.has("hints_seen") or typeof(data["hints_seen"]) != TYPE_ARRAY:
		data["hints_seen"] = []
	# Old saves predate the training migration: an absent flag means the old
	# card levels have not been banked as skill XP yet, so the pass runs on
	# load (migrate_training).
	if not data.has("training_migrated"):
		data["training_migrated"] = false
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
			}


func _load() -> void:
	data = _fresh()
	_reconcile()
	var parsed := _read_save(save_path)
	if parsed.is_empty() and FileAccess.file_exists(save_path):
		push_warning("SaveGame: %s is unreadable, trying the backup" % save_path)
	if parsed.is_empty():
		parsed = _read_save(_bak_path())
		if not parsed.is_empty():
			push_warning("SaveGame: restored progress from %s" % _bak_path())
		elif FileAccess.file_exists(_bak_path()):
			push_warning("SaveGame: backup unreadable too, starting a fresh save")
	if parsed.is_empty():
		_write()
		return
	var old_version := int(parsed.get("save_version", 0))
	# Older versions migrate forward (v2 carries the legacy gear bag, see
	# migrate_legacy_armory); only future versions or corrupt saves reset.
	if old_version > VERSION:
		# A save from a newer build cannot be read here, so it resets. The
		# warning is loud on purpose: the player is about to lose progress.
		push_warning("SaveGame: save version %d is newer than this build, starting fresh" % old_version)
		_write()
		return
	if old_version <= 0:
		# No version stamp: a pre-versioning or hand-edited file. It still
		# holds the player's progress, so it migrates forward like any other
		# old save instead of being replaced by a new account.
		if not _has_account_shape(parsed):
			# Nothing to migrate. The backup is tried before anything is
			# reset, so a good backup still rescues the progress.
			push_warning("SaveGame: the save has no version stamp and no account in it, trying the backup")
			var backup := _read_save(_bak_path())
			var backup_version := int(backup.get("save_version", 0))
			if _has_account_shape(backup) and backup_version <= VERSION:
				push_warning("SaveGame: restored progress from %s" % _bak_path())
				parsed = backup
				old_version = backup_version
				# The backup is good and about to be used: keep it. The
				# write at the end of this load would otherwise rotate the
				# broken save over it.
				_last_backup_ms = Time.get_ticks_msec()
			else:
				push_warning("SaveGame: the backup holds no account either, starting a fresh save")
				_write()
				return
		if old_version <= 0:
			push_warning("SaveGame: the save has no version stamp, migrating it forward as version 1")
			old_version = 1
	data = parsed
	_sanitize()
	_reconcile()
	migrate_legacy_armory(old_version)
	migrate_training()
	migrate_gathering_skills()
	_write()


## True when a save file still carries an account: a hero roster, skill rows
## or the wallet. A file with none of them holds no progress to keep, so it
## is a reset rather than a migration.
func _has_account_shape(parsed: Dictionary) -> bool:
	for key in ["heroes", "skills", "kills", "materials"]:
		var value: Variant = parsed.get(key, null)
		if typeof(value) == TYPE_DICTIONARY and not (value as Dictionary).is_empty():
			return true
	for key in ["coins", "trophies", "gear_shards"]:
		if parsed.has(key):
			return true
	return false


## Tests set this so a headless check never touches the player's save file.
var no_write := false
## Where the save lives. Only sim_check points this at a scratch file.
var save_path := PATH
## The backup rotates at most once per BACKUP_EVERY_MS so frequent saves do
## not thrash; the first write of a session always rotates.
const BACKUP_EVERY_MS := 60000
var _last_backup_ms := -BACKUP_EVERY_MS


func _bak_path() -> String:
	return save_path + ".bak"


func _tmp_path() -> String:
	return save_path + ".tmp"


## The save dictionary stored at `path`, or {} when the file is missing,
## empty, truncated or not a JSON object.
func _read_save(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var text := file.get_as_text()
	file.close()
	if text.strip_edges().is_empty():
		return {}
	var json := JSON.new()
	if json.parse(text) != OK or typeof(json.data) != TYPE_DICTIONARY:
		return {}
	return json.data


## Type sanity for a loaded save: a field of the wrong type falls back to its
## fresh default and negative wallets clamp to 0; every other field (and any
## unknown future key) is kept as it is. JSON numbers load as floats, so any
## number is accepted for the int fields.
func _sanitize() -> void:
	var fresh := _fresh()
	var parsed_wallet := {}
	for key in ["coins", "trophies"]:
		if data.has(key):
			parsed_wallet[key] = data[key]
	for key in fresh:
		if not data.has(key):
			continue
		var want := typeof(fresh[key])
		var have := typeof(data[key])
		if want == TYPE_INT:
			if have == TYPE_INT or have == TYPE_FLOAT:
				data[key] = int(data[key])
			else:
				data[key] = fresh[key]
		elif have != want:
			data[key] = fresh[key]
	# Wallets never refill to the starter purse from a broken value: an
	# unreadable amount reads 0, a negative one clamps to 0.
	for key in ["coins", "trophies"]:
		if not data.has(key):
			continue
		var raw: Variant = parsed_wallet.get(key, 0)
		data[key] = maxi(0, int(raw)) if typeof(raw) == TYPE_INT or typeof(raw) == TYPE_FLOAT else 0


## Atomic write: the save goes to a temp file, is read back and parsed, and
## only then replaces the real file. The previous good file is kept as the
## backup (rotated at most once per BACKUP_EVERY_MS).
func _write() -> void:
	if no_write:
		return
	var tmp := _tmp_path()
	var file := FileAccess.open(tmp, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	if _read_save(tmp).is_empty():
		DirAccess.remove_absolute(tmp)
		return
	var now := Time.get_ticks_msec()
	if now - _last_backup_ms >= BACKUP_EVERY_MS and not _read_save(save_path).is_empty():
		_replace(save_path, _bak_path())
		_last_backup_ms = now
	_replace(tmp, save_path)


## Move `from` over `to` (removing `to` first where rename cannot overwrite).
func _replace(from: String, to: String) -> void:
	if DirAccess.rename_absolute(from, to) == OK:
		return
	DirAccess.remove_absolute(to)
	DirAccess.rename_absolute(from, to)
