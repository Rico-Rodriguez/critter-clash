class_name Catalog
extends RefCounted

## Static roster, biomes, waves, upgrade cards, and trophy milestones.
## Habitat never changes a critter's role. Bosses drop loot. They are not heroes.

const BOSS_AT := 62.0
const MAX_CARD_LEVEL := 10
const MAX_RUN_LEVEL := 8

const WAVES: Array = [
	{"until": 18.0, "every": 1.62, "pool": [0, 0, 1, 1, 2]},
	{"until": 36.0, "every": 1.32, "pool": [0, 1, 1, 2]},
	{"until": 52.0, "every": 1.18, "pool": [1, 2, 2, 3]},
	{"until": 68.0, "every": 1.08, "pool": [1, 2, 3, 2, 2]},
]

static var _cards: Dictionary = {}


static func critter(id: String) -> Dictionary:
	return CRITTERS.get(id, {})


static func biome(id: String) -> Dictionary:
	for entry in BIOMES:
		if str(entry["id"]) == id:
			return entry
	return BIOMES[0]


static func card(id: String) -> Dictionary:
	_index_cards()
	return _cards.get(id, {})


## Every card sits in exactly one pool: "general" (roles []) or its one class.
static func pool_of(id: String) -> String:
	var entry := card(id)
	var roles: Array = entry.get("roles", [])
	if roles.is_empty():
		return "general"
	return str(roles[0])


## Ranged classes fire Shot objects; the tank's melee swing does not.
static func is_ranged(role: String) -> bool:
	return role == "archer" or role == "mage"


## Cards carry an optional "needs" ("ranged" archer+mage only, "melee" tank
## only) when their op is dead outside one attack style. Unset means everyone.
static func role_can_take(role: String, id: String) -> bool:
	var need := str(card(id).get("needs", ""))
	if need == "":
		return true
	if need == "ranged":
		return is_ranged(role)
	if need == "melee":
		return role == "tank"
	return false


## The concrete effect of the next pick: format `rank_desc` with the per-rank
## amount ({n}), the total after this pick ({total}) and the rank ({rank}).
## Cards without a rank_desc (the uniques) fall back to `desc`.
static func card_text(id: String, have: int) -> String:
	var entry := card(id)
	if entry.is_empty():
		return ""
	var fmt := str(entry.get("rank_desc", ""))
	# A first pick reads the plain description; ranks II+ show the running total.
	if fmt == "" or have <= 0:
		return str(entry.get("desc", ""))
	var amount := float(entry.get("n", 0))
	var rank := maxi(1, have + 1)
	var text := fmt.replace("{n}", fmt_amount(amount))
	text = text.replace("{total}", fmt_amount(amount * float(rank)))
	return text.replace("{rank}", str(rank))


## Short number for card text: fractions under 1 are shown as percents.
static func fmt_amount(value: float) -> String:
	if value > 0.0 and value < 1.0:
		return "%d%%" % int(round(value * 100.0))
	if absf(value - round(value)) < 0.005:
		return str(int(round(value)))
	return "%.1f" % value


static func milestone(id: String) -> Dictionary:
	for entry in MILESTONES:
		if str(entry["id"]) == id:
			return entry
	return {}


static func playable_ids() -> Array:
	var ids: Array = []
	for entry in PLAYABLE:
		ids.append(str(entry))
	return ids


## True for a hero class on the playable roster.
static func is_playable_class(id: String) -> bool:
	return str(id) in PLAYABLE


## The class a retired hero id became ("" for a live id or an unknown one).
static func replacement_for(id: String) -> String:
	return str(RETIRED_HEROES.get(id, ""))


## The skills a class really trains (GearDB skill keys). Empty for anything
## that is not a hero class.
static func class_skills(id: String) -> Array:
	var row := critter(id)
	if row.is_empty():
		return []
	return row.get("skills", [])


## The class's headline ability, an AbilityDB id. "" for anything else.
static func class_ability(id: String) -> String:
	return str(critter(id).get("ability", ""))


static func role_name(role: String) -> String:
	match role:
		"mage":
			return "Mage"
		"archer":
			return "Archer"
		"tank":
			return "Tank"
		_:
			return "Beast"


static func unlock_line(id: String) -> String:
	for entry in MILESTONES:
		if str(entry.get("hero", "")) == id:
			return "Trophy Road %d" % int(entry["trophies"])
	return str(critter(id).get("unlock", "Locked"))


static func rarity_name(rarity: String) -> String:
	match rarity:
		"rare":
			return "Rare"
		"epic":
			return "Epic"
		"legendary":
			return "Legendary"
		_:
			return "Common"


static func xp_for_level(level: int) -> int:
	return 14 + (level - 1) * 8


static func base_stats(id: String) -> Dictionary:
	var c := critter(id)
	return {
		"hp": float(c.get("hp", 100)),
		"dmg": float(c.get("dmg", 10)),
		"interval": float(c.get("interval", 0.5)),
		"range": float(c.get("range", 200)),
		"speed": float(c.get("speed", 240)),
		"armor": float(c.get("armor", 0)),
		"regen": 0.0,
		"crit": 0.05,
		"crit_mult": 1.8,
		"splash": float(c.get("splash", 0)),
		"splash_mul": float(c.get("splash_mul", 0.62)),
		"pierce": 0,
		"bounce": 0,
		"shots": 0,
		"thorns": 0.0,
		"bash": 0,
		"magnet": 56.0,
		"siphon": 0.0,
		"revive": 0,
		"proj_speed": float(c.get("proj_speed", 520)),
		"orbit": 0,
		"chain": 0,
		"trail": 0,
		"nova": 0,
		"crit_siphon": 0.0,
		"aura": 0,
		"ricochet": 0.0,
		"execute": 0.0,
		"blink": 0,
		"wolf": 0,
		"static": 0,
		"gemburst": 0,
		"vampkill": 0.0,
		"berserk": 0.0,
		"meteor": 0,
		"split": 0,
		"volley": 0,
		"mark": 0.0,
		"quake": 0,
		"bulwark": 0.0,
		"taunt": 0,
		"phoenix": 0,
		"storm": 0,
	}


## Three cards for a role. The rarity roll fills the offer; if none of the
## three is from the role's own pool, one general card is swapped for a
## random available class card, so a class almost always sees an exclusive.
## The swap reuses the passed rng value that picked the card it replaces, so
## it varies run to run, stays deterministic for a seed, and draws no extra
## rng: the run's random stream is unchanged. Never another class, max or repeat.
static func roll_offer(role: String, stacks: Dictionary, rng: RandomNumberGenerator) -> Array:
	_index_cards()
	var picked: Array = []
	var rolls: Array = []
	var guard := 0
	while picked.size() < 3 and guard < 64:
		guard += 1
		var rarity := _roll_rarity(rng)
		var pool := _pool(role, rarity, stacks, picked)
		if pool.is_empty():
			pool = _pool(role, "epic", stacks, picked)
		if pool.is_empty():
			pool = _pool(role, "rare", stacks, picked)
		if pool.is_empty():
			pool = _pool(role, "common", stacks, picked)
		if pool.is_empty():
			if not ("snack" in picked):
				picked.append("snack")
				rolls.append(-1)
			continue
		var roll := rng.randi()
		rolls.append(roll)
		picked.append(str(pool[roll % pool.size()]["id"]))
	if not _has_class(picked, role):
		var class_pool := _class_pool(role, stacks, picked)
		if not class_pool.is_empty():
			for i in range(picked.size() - 1, -1, -1):
				if picked[i] != "snack" and pool_of(str(picked[i])) == "general":
					var slot := maxi(0, int(rolls[i])) % class_pool.size()
					picked[i] = str(class_pool[slot]["id"])
					break
	return picked


static func _has_class(picked: Array, role: String) -> bool:
	for id in picked:
		if pool_of(str(id)) == role:
			return true
	return false


static func _roll_rarity(rng: RandomNumberGenerator) -> String:
	var roll := rng.randf()
	if roll < 0.055:
		return "legendary"
	if roll < 0.14:
		return "epic"
	if roll < 0.40:
		return "rare"
	return "common"


static func _pool(role: String, rarity: String, stacks: Dictionary, picked: Array) -> Array:
	var out: Array = []
	for entry in CARDS:
		if str(entry["rarity"]) != rarity:
			continue
		if str(entry["id"]) in picked:
			continue
		var roles: Array = entry["roles"]
		if roles.size() > 0 and role not in roles:
			continue
		if not role_can_take(role, str(entry["id"])):
			continue
		var have := int(stacks.get(str(entry["id"]), 0))
		if have >= int(entry["max"]):
			continue
		out.append(entry)
	return out


## The role's own class cards still under their max and not already picked.
static func _class_pool(role: String, stacks: Dictionary, picked: Array) -> Array:
	var out: Array = []
	for entry in CARDS:
		if pool_of(str(entry["id"])) != role:
			continue
		if not role_can_take(role, str(entry["id"])):
			continue
		if str(entry["id"]) in picked:
			continue
		var have := int(stacks.get(str(entry["id"]), 0))
		if have >= int(entry["max"]):
			continue
		out.append(entry)
	return out


static func _index_cards() -> void:
	if not _cards.is_empty():
		return
	for entry in CARDS:
		_cards[str(entry["id"])] = entry
	_cards["snack"] = {
		"id": "snack",
		"name": "Grave Gruel",
		"rarity": "common",
		"op": "heal",
		"n": 22,
		"max": 99,
		"roles": [],
		"stack": true,
		"desc": "Crypt ration. Heal 22 right now.",
		"rank_desc": "Heal {n} right now.",
	}


## The six Diablo-esque hero classes. Retired ids ("juniper", "pip", "pebble",
## "ember", "lumen", "bramble") keep rows below only so old saves and
## duel/daily records still resolve; they render as the closest new class.
const PLAYABLE: Array = [
	"barbarian", "paladin", "sorceress", "rogue", "necromancer", "druid",
]

## The old hero ids and the class each one became. A save that owned or
## featured a retired hero moves to the class that replaced it (see
## SaveGame.migrate_retired_heroes), and the 3D cast and the portraits render
## the retired id as that same class.
const RETIRED_HEROES: Dictionary = {
	"juniper": "rogue", "pip": "sorceress", "pebble": "paladin",
	"ember": "sorceress", "lumen": "barbarian", "bramble": "necromancer",
}

## Boss pet roll. 1 in PET_RATE, separate from the weighted table.
const PET_RATE := 50

const BIOMES: Array = [
	{
		"id": "meadow",
		"name": "Meadow",
		"boss": "thistle",
		"lairs": [],
		"gate": 0,
		"need": "",
		"recommended_level": 3,
		"hp_mul": 1.0,
		"dmg_mul": 1.0,
		"boss_mul": 1.0,
		"skins": ["sprout", "beetle", "moth", "boarlet"],
		"blurb": "Grey grass over old barrows. Gravemaw feeds below.",
	},
	{
		"id": "mushroom",
		"name": "Mushroom Forest",
		"boss": "caplet",
		"lairs": [],
		"gate": 30,
		"need": "meadow",
		"recommended_level": 20,
		"hp_mul": 1.14,
		"dmg_mul": 1.08,
		"boss_mul": 1.2,
		"skins": ["capling", "spore", "glowmoth", "puddle"],
		"blurb": "Rot under the caps. Nightmaw hunts the dark.",
	},
	{
		"id": "frost",
		"name": "Frost Peaks",
		"boss": "nimbus",
		"lairs": ["boreal"],
		"gate": 80,
		"need": "mushroom",
		"recommended_level": 40,
		"hp_mul": 1.28,
		"dmg_mul": 1.16,
		"boss_mul": 1.38,
		"skins": ["snowpup", "shard", "icewisp", "yeti"],
		"blurb": "Quiet snow. Nimbus runs the ridgeline.",
	},
	{
		"id": "volcano",
		"name": "Ember Volcano",
		"boss": "cinder",
		"lairs": ["inferno"],
		"gate": 150,
		"need": "frost",
		"recommended_level": 55,
		"hp_mul": 1.42,
		"dmg_mul": 1.24,
		"boss_mul": 1.58,
		"skins": ["cindling", "skink", "ashbat", "magmash"],
		"blurb": "Warm stone and slow lava. Cinder naps in it.",
	},
]

## The boss lairs: a second lair inside a biome, beside the biome boss that
## holds the ridge. A lair is a boss of its own -- its own critter, its own
## drop table, its own promise -- and it never replaces the biome boss: both
## stand in the same ground. A lair also carries the rarity floor of its
## payout ("guarantee"), so a lair kill always lands rare or better.
##
## "depth_min" is the depth a ground must reach for the lair to stand in it,
## counted like DEPTH_TIERS (fringe 0, wilds 1, deep 2, abyss 3). It is the
## same depth as the lair's own "tier": a lair waits in the deep ground, so
## the shallows never hold one.
const LAIRS: Array = [
	{
		"id": "boreal",
		"name": "Boreal, the Frost Wyrm",
		"biome": "frost",
		"tier": "deep",
		"depth_min": 2,
		"guarantee": "rare",
	},
	{
		"id": "inferno",
		"name": "Inferno, the Magma Colossus",
		"biome": "volcano",
		"tier": "abyss",
		"depth_min": 3,
		"guarantee": "rare",
	},
]

## Per-map difficulty tiers, unlocked in order by clearing the boss on the tier
## below. Normal (index 0) is always open. Each tier scales enemy hp, damage,
## spawn density and elite chance, and lifts loot-tier weights and skill XP.
## `loot` is the shift the loot table adds before its biome cap applies, so a
## Nightmare Meadow still cannot roll rune (see LootTable.MAX_TIER_BY_DEPTH).
const TIER_COUNT := 3
const TIER_NAMES: Array[String] = ["Normal", "Veteran", "Nightmare"]
const TIER_KEYS: Array[String] = ["normal", "veteran", "nightmare"]
const TIER_MUL: Array = [
	{"hp": 1.0, "dmg": 1.0, "density": 1.0, "elite": 0.0, "loot": 0, "xp": 1.0, "aggro": 1.0},
	{"hp": 1.35, "dmg": 1.2, "density": 1.18, "elite": 0.1, "loot": 1, "xp": 1.5, "aggro": 1.25},
	{"hp": 1.8, "dmg": 1.45, "density": 1.35, "elite": 0.22, "loot": 2, "xp": 2.25, "aggro": 1.55},
]

## The four depth tiers of the world, shallowest first. Each biome sits in one
## of them: the Fringe is the meadow rim, the Wilds the mushroom wood, the
## Deep the frost peaks and the Abyss the volcano.
const DEPTH_TIERS: Array[String] = ["fringe", "wilds", "deep", "abyss"]

## Elite spawn chance per depth tier. The Fringe keeps the shallows clean
## (0%), the Wilds throws up the odd elite pack (5%), the Deep makes them
## regular fare (15%) and the Abyss is crawling with them (30%).
const ELITE_SPAWN_BY_TIER: Dictionary = {
	"fringe": 0.0,
	"wilds": 0.05,
	"deep": 0.15,
	"abyss": 0.30,
}

## The same chances keyed by biome id, so a biome can be asked directly. The
## table mirrors ELITE_SPAWN_BY_TIER: the Fringe is the meadow, the Wilds the
## mushroom wood, the Deep the frost peaks, the Abyss the volcano.
const ELITE_SPAWN_BY_BIOME: Dictionary = {
	"meadow": 0.0,
	"mushroom": 0.05,
	"frost": 0.15,
	"volcano": 0.30,
}

## The ceiling on the elite chance: a difficulty tier adds its own chance on
## top of the biome's, and no ground ever turns into a guaranteed elite.
const ELITE_CHANCE_CAP := 0.6


static func tier_mul(tier: int) -> Dictionary:
	return TIER_MUL[clampi(tier, 0, TIER_COUNT - 1)]


static func tier_name(tier: int) -> String:
	return TIER_NAMES[clampi(tier, 0, TIER_COUNT - 1)]


## The elite spawn chance of a ground. The key may be a biome id ("frost"), a
## depth tier ("deep"), a biome name ("Frost Peaks") or a biome index (2), so
## every caller can ask the question the way it holds the answer.
static func elite_spawn_chance(key: Variant) -> float:
	match typeof(key):
		TYPE_INT, TYPE_FLOAT:
			return elite_spawn_chance_tier(int(key))
		_:
			var id := _key_id(str(key))
			if ELITE_SPAWN_BY_BIOME.has(id):
				return float(ELITE_SPAWN_BY_BIOME[id])
			if ELITE_SPAWN_BY_TIER.has(id):
				return float(ELITE_SPAWN_BY_TIER[id])
			for entry in BIOMES:
				if _key_id(str(entry["id"])) == id or _key_id(str(entry["name"])) == id:
					return float(ELITE_SPAWN_BY_TIER.get(depth_tier(str(entry["id"])), 0.0))
			return 0.0


## The elite spawn chance of a depth tier by index (0 = fringe).
static func elite_spawn_chance_tier(tier: int) -> float:
	var idx := clampi(tier, 0, DEPTH_TIERS.size() - 1)
	return float(ELITE_SPAWN_BY_TIER.get(DEPTH_TIERS[idx], 0.0))


## The depth tier a ground sits in ("fringe", "wilds", "deep", "abyss").
static func depth_tier(id: String) -> String:
	var key := _key_id(id)
	for i in BIOMES.size():
		var entry: Dictionary = BIOMES[i]
		if _key_id(str(entry["id"])) == key or _key_id(str(entry["name"])) == key:
			return DEPTH_TIERS[clampi(i, 0, DEPTH_TIERS.size() - 1)]
	return DEPTH_TIERS[0]


## The visible aura flag: an elite wears its glow where the ground allows
## elite spawns at all. The Fringe never shows one.
static func elite_has_aura(key: Variant) -> bool:
	return elite_spawn_chance(key) > 0.0


## The chance a wild critter here is promoted to an elite on a difficulty
## tier: the biome's own chance plus the tier's, under the cap.
static func elite_chance(biome_id: String, tier: int) -> float:
	var base := elite_spawn_chance(biome_id)
	return clampf(base + float(tier_mul(tier).get("elite", 0.0)), 0.0, ELITE_CHANCE_CAP)


## A loose key ("Frost Peaks", "FROST", " frost ") into a plain id.
static func _key_id(text: String) -> String:
	return text.strip_edges().to_lower().replace(" ", "_")


## Intra-tier depth scaling (0.0 at biome start, 1.0 at boss lair).
## HP scales more aggressively than damage so depth feels like endurance.
## Aggro radius grows with depth so Abyss monsters hunt the player.
const DEPTH_HP_CURVE := 1.6
const DEPTH_DMG_CURVE := 0.7
const DEPTH_AGGRO_CURVE := 0.5
const DEPTH_XP_CURVE := 0.6

## Returns the combined multiplier for a given tier and depth (0..1).
## tier_mul provides the baseline; depth adds intra-tier progression.
static func depth_mul(tier: int, depth: float) -> Dictionary:
	var t := tier_mul(tier)
	var d := clampf(depth, 0.0, 1.0)
	return {
		"hp": t["hp"] * (1.0 + d * DEPTH_HP_CURVE),
		"dmg": t["dmg"] * (1.0 + d * DEPTH_DMG_CURVE),
		"aggro": t["aggro"] * (1.0 + d * DEPTH_AGGRO_CURVE),
		"xp": t["xp"] * (1.0 + d * DEPTH_XP_CURVE),
		"density": t["density"],
		"elite": t["elite"],
		"loot": t["loot"],
	}


## Aggro radius multiplier for a tier (Abyss monsters hunt the player).
static func aggro_mul(tier: int) -> float:
	return tier_mul(tier)["aggro"]


## Returns base stats for a critter scaled by tier and depth (0..1).
## Uses the critter's own tier_hp, tier_dmg, depth_hp, depth_dmg, aggro params.
static func scaled_stats(id: String, tier: int, depth: float) -> Dictionary:
	var c := critter(id)
	if c.is_empty():
		return {}
	var dm := depth_mul(tier, depth)
	var tier_hp := float(c.get("tier_hp", 1.0))
	var tier_dmg := float(c.get("tier_dmg", 1.0))
	var depth_hp := float(c.get("depth_hp", 1.0))
	var depth_dmg := float(c.get("depth_dmg", 1.0))
	var aggro := float(c.get("aggro", 1.0))
	return {
		"hp": float(c.get("hp", 100)) * dm["hp"] * tier_hp * depth_hp,
		"dmg": float(c.get("dmg", 10)) * dm["dmg"] * tier_dmg * depth_dmg,
		"interval": float(c.get("interval", 0.5)),
		"range": float(c.get("range", 200)),
		"speed": float(c.get("speed", 240)),
		"armor": float(c.get("armor", 0)),
		"regen": 0.0,
		"crit": 0.05,
		"crit_mult": 1.8,
		"splash": float(c.get("splash", 0)),
		"splash_mul": float(c.get("splash_mul", 0.62)),
		"pierce": 0,
		"bounce": 0,
		"shots": 0,
		"thorns": 0.0,
		"bash": 0,
		"magnet": 56.0,
		"siphon": 0.0,
		"revive": 0,
		"proj_speed": float(c.get("proj_speed", 520)),
		"orbit": 0,
		"chain": 0,
		"trail": 0,
		"nova": 0,
		"crit_siphon": 0.0,
		"aura": 0,
		"ricochet": 0.0,
		"execute": 0.0,
		"blink": 0,
		"wolf": 0,
		"static": 0,
		"gemburst": 0,
		"vampkill": 0.0,
		"berserk": 0.0,
		"meteor": 0,
		"split": 0,
		"volley": 0,
		"mark": 0.0,
		"quake": 0,
		"bulwark": 0.0,
		"taunt": 0,
		"phoenix": 0,
		"storm": 0,
		"aggro_radius": float(c.get("radius", 24)) * dm["aggro"] * aggro,
		"xp": int(c.get("xp", 1)) * dm["xp"],
	}


## The combat level a map is tuned for; the map picker reads this and Normal
## hunts fall off in XP once the hero leaves it far behind.
static func recommended_level(id: String) -> int:
	return int(biome(id).get("recommended_level", 1))


## The map surfaces' shared caption for the level a biome is tuned for, so the
## world banners and the home map sheet all read the same.
static func recommended_text(id: String) -> String:
	return "Recommended combat %d" % recommended_level(id)


## XP falloff for over-leveled Normal farming: 1.0 while the hero is within
## `FALLOFF_GRACE` combat levels of the map, sliding toward `FALLOFF_FLOOR`
## beyond that. Veteran and Nightmare are the deliberate challenge, so they
## never fall off.
const FALLOFF_GRACE := 8
const FALLOFF_RATE := 0.04
const FALLOFF_FLOOR := 0.25


static func xp_falloff(combat: int, recommended: int, tier: int) -> float:
	if tier != 0:
		return 1.0
	var over := combat - recommended
	if over <= FALLOFF_GRACE:
		return 1.0
	return maxf(FALLOFF_FLOOR, 1.0 - float(over - FALLOFF_GRACE) * FALLOFF_RATE)

const MILESTONES: Array = [
	{"id": "m10", "trophies": 10, "kind": "coins", "amount": 40, "label": "Coin purse", "detail": "40 coins"},
	{"id": "m30", "trophies": 30, "kind": "chest", "label": "Trail chest", "detail": "A hunt chest"},
	{"id": "m45", "trophies": 45, "kind": "unlock", "hero": "druid", "cards": 8, "label": "Druid joins", "detail": "Grove shapeshifter unlocked"},
	{"id": "m80", "trophies": 80, "kind": "gear", "slot": "charm", "rarity": "rare", "label": "Rare charm", "detail": "A charm for any hero"},
	{"id": "m110", "trophies": 110, "kind": "unlock", "hero": "necromancer", "cards": 8, "label": "Necromancer joins", "detail": "Bone binder unlocked"},
	{"id": "m150", "trophies": 150, "kind": "gear", "slot": "armor", "rarity": "rare", "label": "Rare armour", "detail": "Blackened steel for any knight"},
	{"id": "m190", "trophies": 190, "kind": "coins", "amount": 120, "label": "Heavy purse", "detail": "120 coins"},
	{"id": "m240", "trophies": 240, "kind": "gear", "slot": "weapon", "rarity": "epic", "label": "Epic weapon", "detail": "A strong weapon"},
]

## Mastery trophies for the trophy screen's second section. Progress is
## derived from GearDB and the wallet each time, never counted here. req is
## the check SaveGame evaluates: "skill" any combat skill at `need`,
## "combat" the OSRS-style per-hero combat level, "iron_kit" a full iron
## kit one hero owns, "steel_kit" a full blackened steel kit one hero wears,
## "rune" the first cursed piece owned, "total" the crew's summed combat
## skill levels. reward is coins or a chest, never a gear piece (gems are not a live currency).
const SKILL_TROPHIES: Array = [
	{"id": "first_blood", "name": "First Blood", "text": "The first kill stains deepest. You will not wash it out.", "req": "skill", "need": 10,
		"reward": {"kind": "coins", "amount": 40}},
	{"id": "blooded", "name": "Blooded", "text": "Twenty levels of scar. The barrows have begun to learn your name.", "req": "skill", "need": 20,
		"reward": {"kind": "coins", "amount": 80}},
	{"id": "veteran", "name": "Veteran", "text": "Forty levels. Your old wounds remember more than the living do.", "req": "skill", "need": 40,
		"reward": {"kind": "chest"}},
	{"id": "relentless", "name": "Relentless", "text": "Sixty. The barrow lights keep burning, just to watch you work.", "req": "skill", "need": 60,
		"reward": {"kind": "coins", "amount": 180}},
	{"id": "combat30", "name": "Combat 30", "text": "Counted in warden's marks. The dead keep their own tally.", "req": "combat", "need": 30,
		"reward": {"kind": "coins", "amount": 120}},
	{"id": "combat50", "name": "Combat 50", "text": "Halfway up the grave trade. Halfway into the grave.", "req": "combat", "need": 50,
		"reward": {"kind": "chest"}},
	{"id": "combat75", "name": "Combat 75", "text": "Near mastery. The dead step aside, calling it courtesy.", "req": "combat", "need": 75,
		"reward": {"kind": "coins", "amount": 300}},
	{"id": "iron_clad", "name": "Iron Clad", "text": "Cold iron over warm skin. It itches. Good.", "req": "iron_kit",
		"reward": {"kind": "coins", "amount": 100}},
	{"id": "blackened", "name": "Blackened", "text": "Steel blacked in beast blood. It never shines again.", "req": "steel_kit",
		"reward": {"kind": "chest"}},
	{"id": "cursed_plate", "name": "Cursed Plate", "text": "One plate bound in old runes. At night it whispers whose.", "req": "rune",
		"reward": {"kind": "coins", "amount": 220}},
	{"id": "total100", "name": "Total 100", "text": "A hundred lessons written in marrow.", "req": "total", "need": 100,
		"reward": {"kind": "chest"}},
	{"id": "total250", "name": "Total 250", "text": "Two hundred and fifty. The wilds bow to no one. Close enough.", "req": "total", "need": 250,
		"reward": {"kind": "coins", "amount": 500}},
]

## op is how a stack changes the run. roles empty means every hero; pool_of()
## reads that as "general". stack is true until a card is unique (max 1).
## rank_desc is the next pick's effect: {n} per rank, {total} after the pick.
##
## Card audit (id -> pool/needs -> reason). needs is "ranged" for Shot-only
## effects (archer + mage) and "melee" for the tank's swing-only effects; an
## unset needs works for both styles.
##   bounce         general/ranged  -> shot.bounce; melee fires no shots.
##   ricochet_plus  general/ranged  -> read only in _step_shots.
##   archer_pierce  archer/ranged   -> shot.pierce.
##   multishot      archer/ranged   -> extra shots.
##   volley         archer/ranged   -> projectile fan.
##   mage_radius    mage/ranged     -> shot.splash.
##   mage_power     mage/ranged     -> shot.splash_mul.
##   arcane_orb     mage/ranged     -> shot.split.
##   tank_bash      tank/melee      -> bash only runs on the melee swing.
##   earthquake     tank/melee      -> quake only runs on the melee swing.
##   all others     general/class, no needs: stat picks (dmg/hp/haste/crit/...),
##     reactives that fire on any hit (siphon, crit_siphon, execute, mark,
##     vampkill, thorns, bulwark) and global skills (orbit, chain, trail, nova,
##     aura, blink, wolf, static, gemburst, meteor, storm) run for melee too.
const CARDS: Array = [
	{"id": "might", "name": "Might", "rarity": "common", "op": "dmg", "n": 5, "max": 5, "roles": [], "stack": true, "desc": "Damage +5.", "rank_desc": "Damage +{n} (total +{total})"},
	{"id": "haste", "name": "Battle Fervour", "rarity": "common", "op": "haste", "n": 0.14, "max": 5, "roles": [], "stack": true, "desc": "Blood-lust quickens your strikes.", "rank_desc": "Attack speed +{n} (total +{total})"},
	{"id": "vitality", "name": "Gravehide", "rarity": "common", "op": "hp", "n": 24, "max": 5, "roles": [], "stack": true, "desc": "Blackened flesh. Max health +24.", "rank_desc": "Max health +{n} (total +{total})"},
	{"id": "swift", "name": "Grave Stride", "rarity": "common", "op": "swift", "n": 0.08, "max": 4, "roles": [], "stack": true, "desc": "Cross the gloom faster.", "rank_desc": "Move speed +{n} (total +{total})"},
	{"id": "crit", "name": "Cruel Odds", "rarity": "common", "op": "crit", "n": 0.06, "max": 5, "roles": [], "stack": true, "desc": "Fate turns cruel. Crit chance +6%.", "rank_desc": "Crit chance +{n} (total +{total})"},
	{"id": "regen", "name": "Grave Mend", "rarity": "common", "op": "regen", "n": 1.4, "max": 4, "roles": [], "stack": true, "desc": "Flesh knits itself whole: 1.4 health each second.", "rank_desc": "Regen +{n}/s (total +{total})"},
	{"id": "magnet", "name": "Soul Grasp", "rarity": "common", "op": "magnet", "n": 42, "max": 3, "roles": [], "stack": true, "desc": "The dead give up their gems from farther away.", "rank_desc": "Magnet +{n} (total +{total})"},
	{"id": "might_plus", "name": "Heavy Blow", "rarity": "rare", "op": "dmg", "n": 11, "max": 3, "roles": [], "stack": true, "desc": "Damage +11.", "rank_desc": "Damage +{n} (total +{total})"},
	{"id": "bounce", "name": "Ricochet", "rarity": "rare", "op": "bounce", "n": 1, "max": 3, "roles": [], "needs": "ranged", "stack": true, "desc": "Attacks bounce to another foe.", "rank_desc": "Bounces +{n} (total {total})"},
	{"id": "armor", "name": "War Plate", "rarity": "rare", "op": "armor", "n": 2, "max": 4, "roles": [], "stack": true, "desc": "Blackened plate over the scars. Armor +2.", "rank_desc": "Armor +{n} (total +{total})"},
	{"id": "siphon", "name": "Bloodletting", "rarity": "rare", "op": "siphon", "n": 0.05, "max": 3, "roles": [], "stack": true, "desc": "Drink of each wound: heal a little of the damage you deal.", "rank_desc": "Lifesteal +{n} (total +{total})"},
	{"id": "vitality_plus", "name": "Bone Vigor", "rarity": "rare", "op": "hp", "n": 42, "max": 2, "roles": [], "stack": true, "desc": "Vigor of the tomb. Max health +42.", "rank_desc": "Max health +{n} (total +{total})"},
	{"id": "second_wind", "name": "Second Wind", "rarity": "legendary", "op": "revive", "n": 1, "max": 1, "roles": [], "stack": false, "desc": "Once, get back up at half health."},
	{"id": "orbit_blades", "name": "Orbiting Blades", "rarity": "common", "op": "orbit", "n": 1, "max": 3, "roles": [], "stack": true, "desc": "Blades circle you and cut what they touch.", "rank_desc": "{total} blades orbit you"},
	{"id": "chain_lightning", "name": "Chain Lightning", "rarity": "common", "op": "chain", "n": 1, "max": 3, "roles": [], "stack": true, "desc": "Every few attacks, lightning leaps between foes.", "rank_desc": "Chains to {total} foes"},
	{"id": "gem_burst", "name": "Gem Burst", "rarity": "common", "op": "gemburst", "n": 1, "max": 3, "roles": [], "stack": true, "desc": "Gems sometimes burst with damage when collected.", "rank_desc": "Gem burst +{n} (total {total})"},
	{"id": "fire_trail", "name": "Fire Trail", "rarity": "common", "op": "trail", "n": 1, "max": 3, "roles": [], "stack": true, "desc": "You leave burning ground as you run.", "rank_desc": "Fire trail +{n} (total {total})"},
	{"id": "frost_nova", "name": "Frost Nova", "rarity": "common", "op": "nova", "n": 1, "max": 3, "roles": [], "stack": true, "desc": "A frost ring damages and slows nearby foes.", "rank_desc": "Frost nova +{n} (total {total})"},
	{"id": "crit_siphon", "name": "Blood Spark", "rarity": "rare", "op": "crit_siphon", "n": 0.1, "max": 3, "roles": [], "stack": true, "desc": "Critical hits heal you.", "rank_desc": "Crit heal +{n} (total +{total})"},
	{"id": "thorns_aura", "name": "Barbed Wrath", "rarity": "rare", "op": "aura", "n": 1, "max": 3, "roles": [], "stack": true, "desc": "A pulse of barbs rends nearby foes.", "rank_desc": "Thorn aura +{n} (total {total})"},
	{"id": "ricochet_plus", "name": "Ricochet+", "rarity": "rare", "op": "ricochet", "n": 0.15, "max": 3, "roles": [], "needs": "ranged", "stack": true, "desc": "Hits can bounce to another foe.", "rank_desc": "Ricochet +{n} (total +{total})"},
	{"id": "executioner", "name": "Executioner", "rarity": "rare", "op": "execute", "n": 0.25, "max": 3, "roles": [], "stack": true, "desc": "Deal more damage to foes below 25% health.", "rank_desc": "Execute +{n} (total +{total})"},
	{"id": "blink", "name": "Blink", "rarity": "rare", "op": "blink", "n": 1, "max": 3, "roles": [], "stack": true, "desc": "When badly hurt, teleport away with brief safety.", "rank_desc": "Blink +{n} (total {total})"},
	{"id": "spirit_wolf", "name": "Spectral Hound", "rarity": "rare", "op": "wolf", "n": 1, "max": 3, "roles": [], "stack": true, "desc": "A hound of the grave fights beside you.", "rank_desc": "{total} spectral hounds"},
	{"id": "static_field", "name": "Static Field", "rarity": "rare", "op": "static", "n": 1, "max": 3, "roles": [], "stack": true, "desc": "Standing still charges a shocking attack.", "rank_desc": "Static charge +{n} (total {total})"},
	{"id": "vampiric_kill", "name": "Vampiric Kill", "rarity": "rare", "op": "vampkill", "n": 0.04, "max": 3, "roles": [], "stack": true, "desc": "Heal when you kill a foe.", "rank_desc": "Kill heal +{n} (total +{total})"},
	{"id": "berserk", "name": "Berserk", "rarity": "rare", "op": "berserk", "n": 0.25, "max": 3, "roles": [], "stack": true, "desc": "Attack faster as your health drops.", "rank_desc": "Berserk +{n} (total +{total})"},
	{"id": "phoenix", "name": "Phoenix Rebirth", "rarity": "legendary", "op": "phoenix", "n": 1, "max": 1, "roles": [], "stack": false, "desc": "Once, rise again in a fire nova."},
	{"id": "storm_crown", "name": "Storm Crown", "rarity": "legendary", "op": "storm", "n": 1, "max": 3, "roles": [], "stack": true, "desc": "Lightning constantly arcs from you.", "rank_desc": "Storm +{n} (total {total})"},
	{"id": "mage_radius", "name": "Grave Radius", "rarity": "epic", "op": "splash", "n": 32, "max": 3, "roles": ["mage"], "needs": "ranged", "stack": true, "desc": "Mage exclusive. Splash reaches farther.", "rank_desc": "Splash +{n} (total +{total})"},
	{"id": "mage_power", "name": "Blighted Splash", "rarity": "epic", "op": "splash_mul", "n": 0.25, "max": 3, "roles": ["mage"], "needs": "ranged", "stack": true, "desc": "Mage exclusive. Splash hits harder.", "rank_desc": "Splash damage +{n} (total +{total})"},
	{"id": "mage_chain", "name": "Arc Lightning", "rarity": "epic", "op": "chain", "n": 1, "max": 3, "roles": ["mage"], "stack": true, "desc": "Mage exclusive. Lightning leaps between foes.", "rank_desc": "Chain +{n} (total {total})"},
	{"id": "mage_crit", "name": "Focused Mind", "rarity": "rare", "op": "crit", "n": 0.07, "max": 4, "roles": ["mage"], "stack": true, "desc": "Mage exclusive. Crit chance +7%.", "rank_desc": "Crit chance +{n} (total +{total})"},
	{"id": "meteor", "name": "Meteor", "rarity": "epic", "op": "meteor", "n": 1, "max": 3, "roles": ["mage"], "stack": true, "desc": "Mage exclusive. Meteors fall on nearby foes.", "rank_desc": "Meteors +{n} (total {total})"},
	{"id": "arcane_orb", "name": "Arcane Orb", "rarity": "epic", "op": "split", "n": 1, "max": 2, "roles": ["mage"], "needs": "ranged", "stack": true, "desc": "Mage exclusive. Orbs pierce and split on impact.", "rank_desc": "Orbs split +{n} (total {total})"},
	{"id": "archer_pierce", "name": "Pierce", "rarity": "epic", "op": "pierce", "n": 1, "max": 4, "roles": ["archer"], "needs": "ranged", "stack": true, "desc": "Archer exclusive. Shots fly through another foe.", "rank_desc": "Pierce +{n} (total {total})"},
	{"id": "multishot", "name": "Multishot", "rarity": "rare", "op": "shots", "n": 1, "max": 2, "roles": ["archer"], "needs": "ranged", "stack": true, "desc": "Archer exclusive. Fire an extra shot.", "rank_desc": "Extra shots +{n} (total {total})"},
	{"id": "archer_crit", "name": "Steady Aim", "rarity": "rare", "op": "crit", "n": 0.07, "max": 4, "roles": ["archer"], "stack": true, "desc": "Archer exclusive. Crit chance +7%.", "rank_desc": "Crit chance +{n} (total +{total})"},
	{"id": "archer_haste", "name": "Quickdraw", "rarity": "rare", "op": "haste", "n": 0.12, "max": 4, "roles": ["archer"], "stack": true, "desc": "Archer exclusive. Attack faster.", "rank_desc": "Attack speed +{n} (total +{total})"},
	{"id": "volley", "name": "Volley", "rarity": "epic", "op": "volley", "n": 1, "max": 3, "roles": ["archer"], "needs": "ranged", "stack": true, "desc": "Archer exclusive. Every few shots fire a fan.", "rank_desc": "Volley +{n} (total {total})"},
	{"id": "hunters_mark", "name": "Hunter's Mark", "rarity": "epic", "op": "mark", "n": 0.1, "max": 3, "roles": ["archer"], "stack": true, "desc": "Archer exclusive. Marked foes take more damage.", "rank_desc": "Mark +{n} (total +{total})"},
	{"id": "tank_thorns", "name": "Thorns", "rarity": "epic", "op": "thorns", "n": 0.22, "max": 4, "roles": ["tank"], "stack": true, "desc": "Tank exclusive. Attackers take damage back.", "rank_desc": "Thorns +{n} (total +{total})"},
	{"id": "tank_bash", "name": "Shield Bash", "rarity": "epic", "op": "bash", "n": 1, "max": 3, "roles": ["tank"], "needs": "melee", "stack": true, "desc": "Tank exclusive. Melee sends a shockwave.", "rank_desc": "Bash +{n} (total {total})"},
	{"id": "earthquake", "name": "Earthquake Slam", "rarity": "epic", "op": "quake", "n": 1, "max": 3, "roles": ["tank"], "needs": "melee", "stack": true, "desc": "Tank exclusive. Melee shocks and stuns nearby foes.", "rank_desc": "Quake +{n} (total {total})"},
	{"id": "bulwark", "name": "Bulwark", "rarity": "epic", "op": "bulwark", "n": 0.1, "max": 3, "roles": ["tank"], "stack": true, "desc": "Tank exclusive. Take less damage while standing still.", "rank_desc": "Bulwark +{n} (total +{total})"},
	{"id": "taunt_roar", "name": "Taunt Roar", "rarity": "epic", "op": "taunt", "n": 1, "max": 3, "roles": ["tank"], "stack": true, "desc": "Tank exclusive. A roar pulls in and weakens foes.", "rank_desc": "Taunt +{n} (total {total})"},
	{"id": "tank_armor", "name": "Iron Plating", "rarity": "rare", "op": "armor", "n": 3, "max": 4, "roles": ["tank"], "stack": true, "desc": "Tank exclusive. Armor +3.", "rank_desc": "Armor +{n} (total +{total})"},
]

const CRITTERS: Dictionary = {
	"barbarian": {
		"name": "Barbarian", "role": "tank", "kind": "hero", "color": "c0392b",
		"blurb": "A wandering berserker from the Dreadlands. Twin axes carve a red path through the barrows.",
		"unlock": "A starter hero.",
		## The class ability (an AbilityDB id) and the skills the class
		## really trains. Its abilities scale with those skills.
		"ability": "whirlwind", "skills": ["attack", "strength"],
		"hp": 320, "dmg": 28, "interval": 0.45, "range": 120, "speed": 270,
		"splash": 0, "splash_mul": 0.0, "proj_speed": 400, "armor": 2,
	},
	"paladin": {
		"name": "Paladin", "role": "tank", "kind": "hero", "color": "f1c40f",
		"blurb": "A Zakarum zealot clad in blessed steel. Sword and shield hold the line against the dark.",
		"unlock": "A starter hero.",
		"ability": "aura_of_light", "skills": ["strength", "hitpoints"],
		"hp": 300, "dmg": 24, "interval": 0.48, "range": 135, "speed": 250,
		"splash": 0, "splash_mul": 0.0, "proj_speed": 420, "armor": 4,
	},
	"sorceress": {
		"name": "Sorceress", "role": "mage", "kind": "hero", "color": "8e44ad",
		"blurb": "A Vizjerei prodigy. Fire, ice and lightning answer her call from afar.",
		"unlock": "A starter hero.",
		"ability": "frost_nova", "skills": ["magic", "hitpoints"],
		"hp": 180, "dmg": 22, "interval": 0.5, "range": 340, "speed": 260,
		"splash": 100, "splash_mul": 0.7, "proj_speed": 540, "armor": 0,
	},
	"rogue": {
		"name": "Rogue", "role": "archer", "kind": "hero", "color": "27ae60",
		"blurb": "A Sister of the Sightless Eye. Bows and traps strike unseen from the shadows.",
		"unlock": "A starter hero.",
		"ability": "fan_of_knives", "skills": ["ranged", "defence"],
		"hp": 200, "dmg": 18, "interval": 0.38, "range": 420, "speed": 290,
		"splash": 0, "splash_mul": 0.0, "proj_speed": 800, "armor": 1,
	},
	"necromancer": {
		"name": "Necromancer", "role": "mage", "kind": "hero", "color": "5f7a6b",
		"blurb": "A binder of bone. The dead rise at her call and hold the line beside her.",
		"unlock": "Trophy road.",
		"ability": "raise_skeleton", "skills": ["magic", "hitpoints"],
		"hp": 172, "dmg": 19, "interval": 0.54, "range": 300, "speed": 258,
		"splash": 80, "splash_mul": 0.66, "proj_speed": 490, "armor": 0,
	},
	"druid": {
		"name": "Druid", "role": "tank", "kind": "hero", "color": "3f8f5f",
		"blurb": "A shapeshifter of the wilds. Bear form, thornwood, and the patience of the grove.",
		"unlock": "Trophy road.",
		"ability": "wild_shape", "skills": ["strength", "defence"],
		"hp": 262, "dmg": 25, "interval": 0.43, "range": 130, "speed": 282,
		"splash": 0, "splash_mul": 0.0, "proj_speed": 400, "armor": 2,
	},
	"juniper": {
		"name": "Juniper", "role": "archer", "kind": "hero", "color": "e07a3d",
		"blurb": "Retired.", "retired": true,
		"unlock": "Retired.",
		"hp": 116, "dmg": 14, "interval": 0.33, "range": 400, "speed": 292,
		"splash": 0, "splash_mul": 0.0, "proj_speed": 780, "armor": 0,
	},
	"pebble": {
		"name": "Aldric", "role": "tank", "kind": "hero", "color": "b89a5e",
		"blurb": "Ashen paladin. Sword and shield; hard to move.",
		"unlock": "Retired.",
		"hp": 280, "dmg": 31, "interval": 0.42, "range": 138, "speed": 256,
		"splash": 0, "splash_mul": 0.0, "proj_speed": 420, "armor": 3,
	},
	"lumen": {
		"name": "Gnash", "role": "tank", "kind": "hero", "color": "c0453a",
		"blurb": "Ghoul berserker. Twin claws, fast and frenzied, thin hide.",
		"unlock": "Retired.",
		"hp": 224, "dmg": 17, "interval": 0.3, "range": 104, "speed": 292,
		"splash": 0, "splash_mul": 0.0, "proj_speed": 400, "armor": 1,
	},
	"pip": {
		"name": "Pip", "role": "mage", "kind": "hero", "color": "7dba62",
		"blurb": "Retired.", "retired": true,
		"unlock": "Retired.",
		"hp": 138, "dmg": 15, "interval": 0.48, "range": 280, "speed": 270,
		"splash": 68, "splash_mul": 0.7, "proj_speed": 510, "armor": 0,
	},
	"ember": {
		"name": "Corvin", "role": "mage", "kind": "hero", "color": "8fd14f",
		"blurb": "Plague doctor. Miasma bolts burst and linger.",
		"unlock": "Retired.",
		"hp": 168, "dmg": 21, "interval": 0.46, "range": 320, "speed": 268,
		"splash": 92, "splash_mul": 0.66, "proj_speed": 520, "armor": 0,
	},
	"bramble": {
		"name": "Mordrek", "role": "tank", "kind": "hero", "color": "6fbf8f",
		"blurb": "Bone Knight. A cursed duelist with one long blade.",
		"unlock": "Retired.",
		"hp": 276, "dmg": 20, "interval": 0.52, "range": 110, "speed": 214,
		"splash": 0, "splash_mul": 0.0, "proj_speed": 400, "armor": 4,
	},
	"thistle": {
		"name": "Gravemaw", "role": "tank", "kind": "boss", "color": "c46b8a",
		"blurb": "Meadow boss. A barrow troll gorged on the dead, an ember burning in its chest.",
		"unlock": "Meadow boss.",
		"hp": 252, "dmg": 23, "interval": 0.48, "range": 118, "speed": 232,
		"splash": 0, "splash_mul": 0.0, "proj_speed": 420, "armor": 3,
		"boss_hp": 1600, "boss_speed": 74, "boss_radius": 78, "boss_touch": 15,
		"aoe": 24, "charge": 30, "shot": 11,
		"bias_charge": 0.46, "bias_aoe": 0.34,
		"tier_hp": 1.2, "tier_dmg": 1.15, "depth_hp": 1.0, "depth_dmg": 1.0, "aggro": 1.3,
	},
	"caplet": {
		"name": "Nightmaw", "role": "mage", "kind": "boss", "color": "d45ad0",
		"blurb": "Mushroom Forest boss. A rot-wolf that walks upright, veins lit with blight.",
		"unlock": "Mushroom Forest boss.",
		"hp": 160, "dmg": 17, "interval": 0.55, "range": 300, "speed": 246,
		"splash": 86, "splash_mul": 0.7, "proj_speed": 450, "armor": 0,
		"boss_hp": 1500, "boss_speed": 64, "boss_radius": 80, "boss_touch": 15,
		"aoe": 26, "charge": 26, "shot": 12,
		"bias_charge": 0.16, "bias_aoe": 0.40,
		"tier_hp": 1.2, "tier_dmg": 1.15, "depth_hp": 1.0, "depth_dmg": 1.0, "aggro": 1.3,
	},
	"nimbus": {
		"name": "Nimbus", "role": "archer", "kind": "boss", "color": "d7e7f6",
		"blurb": "Frost boss. A hare made of weather.",
		"unlock": "Frost Peaks boss.",
		"hp": 128, "dmg": 16, "interval": 0.32, "range": 410, "speed": 308,
		"splash": 0, "splash_mul": 0.0, "proj_speed": 800, "armor": 0,
		"boss_hp": 1420, "boss_speed": 92, "boss_radius": 70, "boss_touch": 14,
		"aoe": 22, "charge": 28, "shot": 12,
		"bias_charge": 0.40, "bias_aoe": 0.22,
		"tier_hp": 1.2, "tier_dmg": 1.15, "depth_hp": 1.0, "depth_dmg": 1.0, "aggro": 1.3,
	},
	"cinder": {
		"name": "Cinder", "role": "mage", "kind": "boss", "color": "ff5a32",
		"blurb": "Volcano boss. A round lava salamander.",
		"unlock": "Ember Volcano boss.",
		"hp": 168, "dmg": 19, "interval": 0.52, "range": 290, "speed": 248,
		"splash": 98, "splash_mul": 0.74, "proj_speed": 440, "armor": 1,
		"boss_hp": 1680, "boss_speed": 68, "boss_radius": 82, "boss_touch": 18,
		"aoe": 28, "charge": 32, "shot": 13,
		"bias_charge": 0.22, "bias_aoe": 0.50,
		"tier_hp": 1.2, "tier_dmg": 1.15, "depth_hp": 1.0, "depth_dmg": 1.0, "aggro": 1.3,
	},
	# Boreal, the Frost Wyrm: the lair boss of the Deep (Frost Peaks). He
	# stands beside Nimbus, never in his place, and his hoard is rare or
	# better (guarantee).
	"boreal": {
		"name": "Boreal", "role": "archer", "kind": "boss", "color": "b7f0ff",
		"blurb": "Deep lair boss. A frost wyrm that breathes rime, scales pale as glaciers.",
		"unlock": "Frost Peaks lair boss.",
		"hp": 136, "dmg": 18, "interval": 0.35, "range": 430, "speed": 280,
		"splash": 0, "splash_mul": 0.0, "proj_speed": 850, "armor": 0,
		"boss_hp": 1800, "boss_speed": 88, "boss_radius": 85, "boss_touch": 16,
		"aoe": 24, "charge": 30, "shot": 14,
		"bias_charge": 0.35, "bias_aoe": 0.25,
		"tier_hp": 1.2, "tier_dmg": 1.15, "depth_hp": 1.0, "depth_dmg": 1.0, "aggro": 1.3,
		"guarantee": "rare",
	},
	# Inferno, the Magma Colossus: the lair boss of the Abyss (Ember
	# Volcano). He stands beside Cinder, never in his place, and his hoard
	# is rare or better (guarantee).
	"inferno": {
		"name": "Inferno", "role": "mage", "kind": "boss", "color": "ff6a1a",
		"blurb": "Abyss lair boss. A magma colossus, core burning white-hot through cracked plate.",
		"unlock": "Ember Volcano lair boss.",
		"hp": 184, "dmg": 22, "interval": 0.55, "range": 310, "speed": 220,
		"splash": 110, "splash_mul": 0.78, "proj_speed": 420, "armor": 2,
		"boss_hp": 2100, "boss_speed": 60, "boss_radius": 90, "boss_touch": 20,
		"aoe": 32, "charge": 28, "shot": 12,
		"bias_charge": 0.20, "bias_aoe": 0.55,
		"tier_hp": 1.2, "tier_dmg": 1.15, "depth_hp": 1.0, "depth_dmg": 1.0, "aggro": 1.3,
		"guarantee": "rare",
	},
	"sprout": {"name": "Rot Badger", "kind": "minion", "archetype": "chaser", "color": "67b85a", "hp": 28, "dmg": 7, "speed": 96, "radius": 24, "xp": 2, "tier_hp": 1.0, "tier_dmg": 1.0, "depth_hp": 1.0, "depth_dmg": 1.0, "aggro": 1.0},
	"beetle": {"name": "Barrow Scarab", "kind": "minion", "archetype": "runner", "color": "d2a03a", "hp": 38, "dmg": 8, "speed": 128, "radius": 22, "xp": 3, "tier_hp": 1.0, "tier_dmg": 1.0, "depth_hp": 1.0, "depth_dmg": 1.0, "aggro": 1.0},
	"moth": {"name": "Grave Moth", "kind": "minion", "archetype": "shooter", "color": "f0e2b0", "hp": 22, "dmg": 7, "speed": 72, "radius": 22, "xp": 3, "interval": 1.55, "shot_speed": 200, "shot_range": 250, "tier_hp": 1.0, "tier_dmg": 1.0, "depth_hp": 1.0, "depth_dmg": 1.0, "aggro": 1.2},
	"boarlet": {"name": "Grave Bear", "kind": "minion", "archetype": "brute", "color": "c47858", "hp": 78, "dmg": 11, "speed": 88, "radius": 30, "xp": 5, "tier_hp": 1.15, "tier_dmg": 1.1, "depth_hp": 1.1, "depth_dmg": 1.05, "aggro": 1.1},
	"capling": {"name": "Mossback", "kind": "minion", "archetype": "chaser", "color": "d85a8a", "hp": 32, "dmg": 8, "speed": 100, "radius": 24, "xp": 2, "tier_hp": 1.0, "tier_dmg": 1.0, "depth_hp": 1.0, "depth_dmg": 1.0, "aggro": 1.0},
	"spore": {"name": "Blight Skitterer", "kind": "minion", "archetype": "runner", "color": "c9b6ef", "hp": 40, "dmg": 9, "speed": 150, "radius": 22, "xp": 3, "tier_hp": 1.0, "tier_dmg": 1.0, "depth_hp": 1.0, "depth_dmg": 1.0, "aggro": 1.15},
	"glowmoth": {"name": "Blight Moth", "kind": "minion", "archetype": "shooter", "color": "8ef0c8", "hp": 30, "dmg": 9, "speed": 76, "radius": 22, "xp": 3, "interval": 1.3, "shot_speed": 235, "shot_range": 290, "tier_hp": 1.0, "tier_dmg": 1.0, "depth_hp": 1.0, "depth_dmg": 1.0, "aggro": 1.2},
	"puddle": {"name": "Blight Troll", "kind": "minion", "archetype": "brute", "color": "6a8f4e", "hp": 96, "dmg": 13, "speed": 90, "radius": 32, "xp": 5, "tier_hp": 1.15, "tier_dmg": 1.1, "depth_hp": 1.1, "depth_dmg": 1.05, "aggro": 1.1},
	"snowpup": {"name": "Rime Stalker", "kind": "minion", "archetype": "chaser", "color": "e7f2fb", "hp": 34, "dmg": 8, "speed": 108, "radius": 24, "xp": 2, "tier_hp": 1.0, "tier_dmg": 1.0, "depth_hp": 1.0, "depth_dmg": 1.0, "aggro": 1.0},
	"shard": {"name": "Ice Wraith", "kind": "minion", "archetype": "runner", "color": "9fd4ef", "hp": 44, "dmg": 10, "speed": 156, "radius": 22, "xp": 3, "tier_hp": 1.0, "tier_dmg": 1.0, "depth_hp": 1.0, "depth_dmg": 1.0, "aggro": 1.15},
	"icewisp": {"name": "Frostcaller", "kind": "minion", "archetype": "shooter", "color": "d5f4ff", "hp": 30, "dmg": 10, "speed": 80, "radius": 22, "xp": 3, "interval": 1.25, "shot_speed": 250, "shot_range": 300, "tier_hp": 1.0, "tier_dmg": 1.0, "depth_hp": 1.0, "depth_dmg": 1.0, "aggro": 1.2},
	"yeti": {"name": "Yeti", "kind": "minion", "archetype": "brute", "color": "f7f7fb", "hp": 110, "dmg": 14, "speed": 88, "radius": 34, "xp": 5, "tier_hp": 1.15, "tier_dmg": 1.1, "depth_hp": 1.1, "depth_dmg": 1.05, "aggro": 1.1},
	"cindling": {"name": "Ash Wyrmling", "kind": "minion", "archetype": "chaser", "color": "ff8a3c", "hp": 34, "dmg": 9, "speed": 110, "radius": 24, "xp": 2, "tier_hp": 1.0, "tier_dmg": 1.0, "depth_hp": 1.0, "depth_dmg": 1.0, "aggro": 1.0},
	"skink": {"name": "Ashrunner", "kind": "minion", "archetype": "runner", "color": "e25b2a", "hp": 46, "dmg": 10, "speed": 160, "radius": 22, "xp": 3, "tier_hp": 1.0, "tier_dmg": 1.0, "depth_hp": 1.0, "depth_dmg": 1.0, "aggro": 1.15},
	"ashbat": {"name": "Ashbat", "kind": "minion", "archetype": "shooter", "color": "6a534c", "hp": 32, "dmg": 11, "speed": 84, "radius": 22, "xp": 3, "interval": 1.2, "shot_speed": 255, "shot_range": 300, "tier_hp": 1.0, "tier_dmg": 1.0, "depth_hp": 1.0, "depth_dmg": 1.0, "aggro": 1.2},
	"magmash": {"name": "Magma Behemoth", "kind": "minion", "archetype": "brute", "color": "ff5a2a", "hp": 120, "dmg": 15, "speed": 86, "radius": 34, "xp": 5, "tier_hp": 1.15, "tier_dmg": 1.1, "depth_hp": 1.1, "depth_dmg": 1.05, "aggro": 1.1},
}


## One row per obtainable drop. Pets are rolled at 1/PET_RATE and are not weighted.
## The row ids stay for saves, so the baked item art, the material prices and
## the collection log all survive the boss split: Nimbus and Cinder keep the
## rows they always had, and the lair bosses Boreal and Inferno add their own
## hoard beside them.
const DROPS: Array = [
	{"id": "thistle_purse", "boss": "thistle", "name": "Coin purse", "kind": "coins", "amount": 40, "rarity": "common", "weight": 22, "color": "f0b429"},
	{"id": "thistle_pouch", "boss": "thistle", "name": "Heavy purse", "kind": "coins", "amount": 90, "rarity": "uncommon", "weight": 10, "color": "e8c07a"},
	{"id": "meadow_fiber", "boss": "thistle", "name": "Barrow sinew", "kind": "material", "amount": 4, "rarity": "common", "weight": 20, "color": "67b85a"},
	{"id": "pollen", "boss": "thistle", "name": "Grave ash", "kind": "material", "amount": 2, "rarity": "uncommon", "weight": 12, "color": "f2d35a"},
	{"id": "thistle_ember_cards", "boss": "thistle", "name": "Sorceress relics", "kind": "cards", "hero": "sorceress", "amount": 2, "rarity": "common", "weight": 12, "color": "8e44ad"},
	{"id": "thistle_juniper_cards", "boss": "thistle", "name": "Necromancer relics", "kind": "cards", "hero": "necromancer", "amount": 2, "rarity": "uncommon", "weight": 8, "color": "5f7a6b"},
	{"id": "thistle_claw", "boss": "thistle", "name": "Gravemaw talon", "kind": "gear", "slot": "weapon", "gear_rarity": "common", "rarity": "uncommon", "weight": 8, "color": "c46b8a"},
	{"id": "thistle_shell", "boss": "thistle", "name": "Barrow-hide mantle", "kind": "gear", "slot": "armor", "gear_rarity": "rare", "rarity": "rare", "weight": 5, "color": "8d4e6a"},
	{"id": "boar_bristle", "boss": "thistle", "name": "Troll bristle", "kind": "material", "amount": 1, "rarity": "rare", "weight": 4, "color": "a86848"},
	{"id": "thistle_bell", "boss": "thistle", "name": "Smoulder charm", "kind": "gear", "slot": "charm", "gear_rarity": "rare", "rarity": "rare", "weight": 3, "color": "ffe08a"},
	{"id": "flower_crown", "boss": "thistle", "name": "Barrow crown", "kind": "material", "amount": 1, "rarity": "very_rare", "weight": 2, "color": "ffd15a"},
	{"id": "thistle_pet", "boss": "thistle", "name": "Gravespawn", "kind": "pet", "sprite": "thistle", "rarity": "very_rare", "weight": 0, "color": "c46b8a"},
	{"id": "caplet_purse", "boss": "caplet", "name": "Coin purse", "kind": "coins", "amount": 48, "rarity": "common", "weight": 22, "color": "f0b429"},
	{"id": "caplet_pouch", "boss": "caplet", "name": "Heavy purse", "kind": "coins", "amount": 110, "rarity": "uncommon", "weight": 10, "color": "e8c07a"},
	{"id": "cap_bits", "boss": "caplet", "name": "Rot fur", "kind": "material", "amount": 4, "rarity": "common", "weight": 20, "color": "d45ad0"},
	{"id": "spore_dust", "boss": "caplet", "name": "Blight dust", "kind": "material", "amount": 2, "rarity": "uncommon", "weight": 12, "color": "c9b6ef"},
	{"id": "caplet_pebble_cards", "boss": "caplet", "name": "Paladin relics", "kind": "cards", "hero": "paladin", "amount": 2, "rarity": "common", "weight": 12, "color": "f1c40f"},
	{"id": "caplet_pip_cards", "boss": "caplet", "name": "Barbarian relics", "kind": "cards", "hero": "barbarian", "amount": 2, "rarity": "uncommon", "weight": 8, "color": "c0392b"},
	{"id": "caplet_wand", "boss": "caplet", "name": "Blightfang wand", "kind": "gear", "slot": "weapon", "gear_rarity": "common", "rarity": "uncommon", "weight": 8, "color": "d45ad0"},
	{"id": "caplet_wrap", "boss": "caplet", "name": "Wolfhide wrap", "kind": "gear", "slot": "armor", "gear_rarity": "rare", "rarity": "rare", "weight": 5, "color": "8a3a86"},
	{"id": "toad_cap", "boss": "caplet", "name": "Moonless pelt", "kind": "material", "amount": 1, "rarity": "rare", "weight": 4, "color": "e23a4a"},
	{"id": "glow_bead", "boss": "caplet", "name": "Blight eye", "kind": "gear", "slot": "charm", "gear_rarity": "rare", "rarity": "rare", "weight": 3, "color": "8ef0c8"},
	{"id": "giant_cap", "boss": "caplet", "name": "Alpha skull", "kind": "material", "amount": 1, "rarity": "very_rare", "weight": 2, "color": "ff5a6a"},
	{"id": "caplet_pet", "boss": "caplet", "name": "Rotspawn", "kind": "pet", "sprite": "caplet", "rarity": "very_rare", "weight": 0, "color": "d45ad0"},
	{"id": "nimbus_purse", "boss": "nimbus", "name": "Coin purse", "kind": "coins", "amount": 56, "rarity": "common", "weight": 22, "color": "f0b429"},
	{"id": "nimbus_pouch", "boss": "nimbus", "name": "Heavy purse", "kind": "coins", "amount": 130, "rarity": "uncommon", "weight": 10, "color": "e8c07a"},
	{"id": "frost_wool", "boss": "nimbus", "name": "Rimefang pelt", "kind": "material", "amount": 4, "rarity": "common", "weight": 20, "color": "d7e7f6"},
	{"id": "ice_shard", "boss": "nimbus", "name": "Ice shard", "kind": "material", "amount": 2, "rarity": "uncommon", "weight": 12, "color": "9fd4ef"},
	{"id": "nimbus_lumen_cards", "boss": "nimbus", "name": "Barbarian relics", "kind": "cards", "hero": "barbarian", "amount": 2, "rarity": "common", "weight": 12, "color": "c0392b"},
	{"id": "nimbus_bramble_cards", "boss": "nimbus", "name": "Necromancer relics", "kind": "cards", "hero": "necromancer", "amount": 2, "rarity": "uncommon", "weight": 8, "color": "5f7a6b"},
	{"id": "nimbus_sling", "boss": "nimbus", "name": "Frostfang blade", "kind": "gear", "slot": "weapon", "gear_rarity": "common", "rarity": "uncommon", "weight": 8, "color": "d7e7f6"},
	{"id": "nimbus_coat", "boss": "nimbus", "name": "Rimeguard coat", "kind": "gear", "slot": "armor", "gear_rarity": "rare", "rarity": "rare", "weight": 5, "color": "8aa4c0"},
	{"id": "hare_fluff", "boss": "nimbus", "name": "Wraith wisp", "kind": "material", "amount": 1, "rarity": "rare", "weight": 4, "color": "f7f7fb"},
	{"id": "storm_bell", "boss": "nimbus", "name": "Storm sigil", "kind": "gear", "slot": "charm", "gear_rarity": "rare", "rarity": "rare", "weight": 3, "color": "ffe08a"},
	{"id": "aurora_shard", "boss": "nimbus", "name": "Aurora shard", "kind": "material", "amount": 1, "rarity": "very_rare", "weight": 2, "color": "b7f0ff"},
	{"id": "nimbus_pet", "boss": "nimbus", "name": "Rimeling", "kind": "pet", "sprite": "nimbus", "rarity": "very_rare", "weight": 0, "color": "d7e7f6"},
	{"id": "cinder_purse", "boss": "cinder", "name": "Coin purse", "kind": "coins", "amount": 64, "rarity": "common", "weight": 22, "color": "f0b429"},
	{"id": "cinder_pouch", "boss": "cinder", "name": "Heavy purse", "kind": "coins", "amount": 150, "rarity": "uncommon", "weight": 10, "color": "e8c07a"},
	{"id": "ash_clump", "boss": "cinder", "name": "Ash clump", "kind": "material", "amount": 4, "rarity": "common", "weight": 20, "color": "6a534c"},
	{"id": "ember_ore", "boss": "cinder", "name": "Ember ore", "kind": "material", "amount": 2, "rarity": "uncommon", "weight": 12, "color": "ff8a3c"},
	{"id": "cinder_ember_cards", "boss": "cinder", "name": "Sorceress relics", "kind": "cards", "hero": "sorceress", "amount": 3, "rarity": "common", "weight": 12, "color": "8e44ad"},
	{"id": "cinder_pebble_cards", "boss": "cinder", "name": "Paladin relics", "kind": "cards", "hero": "paladin", "amount": 2, "rarity": "uncommon", "weight": 8, "color": "f1c40f"},
	{"id": "cinder_mallet", "boss": "cinder", "name": "Cinderfang", "kind": "gear", "slot": "weapon", "gear_rarity": "common", "rarity": "uncommon", "weight": 8, "color": "ff5a32"},
	{"id": "cinder_plate", "boss": "cinder", "name": "Ash plate", "kind": "gear", "slot": "armor", "gear_rarity": "rare", "rarity": "rare", "weight": 5, "color": "a84830"},
	{"id": "salamander_scale", "boss": "cinder", "name": "Cinder scale", "kind": "material", "amount": 1, "rarity": "rare", "weight": 4, "color": "e25b2a"},
	{"id": "magma_charm", "boss": "cinder", "name": "Magma charm", "kind": "gear", "slot": "charm", "gear_rarity": "rare", "rarity": "rare", "weight": 3, "color": "ffd15a"},
	{"id": "heart_of_ash", "boss": "cinder", "name": "Heart of ash", "kind": "material", "amount": 1, "rarity": "very_rare", "weight": 2, "color": "ff5a2a"},
	{"id": "cinder_pet", "boss": "cinder", "name": "Ashling", "kind": "pet", "sprite": "cinder", "rarity": "very_rare", "weight": 0, "color": "ff5a32"},
	# --- Lair hoards -----------------------------------------------------------
	# A lair boss keeps no common coin: every row of its table is rare or
	# better, so the kill is a haul and never a pocket lint (guarantee).
	{"id": "boreal_coat", "boss": "boreal", "name": "Glacierguard coat", "kind": "gear", "slot": "armor", "gear_rarity": "rare", "rarity": "rare", "weight": 6, "color": "8aa4c0"},
	{"id": "boreal_sling", "boss": "boreal", "name": "Wyrmfang bow", "kind": "gear", "slot": "weapon", "gear_rarity": "rare", "rarity": "rare", "weight": 5, "color": "b7f0ff"},
	{"id": "frost_sigil", "boss": "boreal", "name": "Frost sigil", "kind": "gear", "slot": "charm", "gear_rarity": "rare", "rarity": "rare", "weight": 4, "color": "ffe08a"},
	{"id": "wyrm_essence", "boss": "boreal", "name": "Wyrm essence", "kind": "material", "amount": 1, "rarity": "rare", "weight": 4, "color": "f7f7fb"},
	{"id": "boreal_heart", "boss": "boreal", "name": "Boreal heart", "kind": "material", "amount": 1, "rarity": "very_rare", "weight": 2, "color": "b7f0ff"},
	{"id": "boreal_hoard", "boss": "boreal", "name": "Wyrm hoard", "kind": "coins", "amount": 180, "rarity": "very_rare", "weight": 3, "color": "f0b429"},
	{"id": "boreal_lumen_cards", "boss": "boreal", "name": "Barbarian relics", "kind": "cards", "hero": "barbarian", "amount": 2, "rarity": "rare", "weight": 3, "color": "c0392b"},
	{"id": "boreal_pet", "boss": "boreal", "name": "Frostling", "kind": "pet", "sprite": "boreal", "rarity": "very_rare", "weight": 0, "color": "b7f0ff"},
	{"id": "inferno_plate", "boss": "inferno", "name": "Magma plate", "kind": "gear", "slot": "armor", "gear_rarity": "rare", "rarity": "rare", "weight": 6, "color": "a84830"},
	{"id": "inferno_mallet", "boss": "inferno", "name": "Infernofang", "kind": "gear", "slot": "weapon", "gear_rarity": "rare", "rarity": "rare", "weight": 5, "color": "ff6a1a"},
	{"id": "inferno_charm", "boss": "inferno", "name": "Inferno charm", "kind": "gear", "slot": "charm", "gear_rarity": "rare", "rarity": "rare", "weight": 4, "color": "ffd15a"},
	{"id": "colossus_scale", "boss": "inferno", "name": "Colossus scale", "kind": "material", "amount": 1, "rarity": "rare", "weight": 4, "color": "e25b2a"},
	{"id": "heart_of_inferno", "boss": "inferno", "name": "Heart of inferno", "kind": "material", "amount": 1, "rarity": "very_rare", "weight": 2, "color": "ff5a2a"},
	{"id": "inferno_hoard", "boss": "inferno", "name": "Colossus hoard", "kind": "coins", "amount": 220, "rarity": "very_rare", "weight": 3, "color": "f0b429"},
	{"id": "inferno_ember_cards", "boss": "inferno", "name": "Sorceress relics", "kind": "cards", "hero": "sorceress", "amount": 3, "rarity": "rare", "weight": 3, "color": "8e44ad"},
	{"id": "inferno_pet", "boss": "inferno", "name": "Emberling", "kind": "pet", "sprite": "inferno", "rarity": "very_rare", "weight": 0, "color": "ff6a1a"},
]

## Gathering skills. They are account-wide, not per hero (see docs/gathering.md):
## the XP for each id lives in SaveGame.data["skills"] and the level comes
## from the OSRS curve below. The resource nodes they work are in
## GatheringDB.NODES.
const SKILLS: Array = [
	{"id": "woodcutting", "name": "Woodcutting"},
	{"id": "fishing", "name": "Fishing"},
	{"id": "mining", "name": "Mining"},
]

const SLAYER_TASKS: Array = [
	{"id": "meadow_critters", "text": "Defeat 40 Meadow beasts", "biome": "meadow", "kind": "minion", "need": 40, "points": 25},
	{"id": "thistle_task", "text": "Defeat Gravemaw", "biome": "meadow", "kind": "boss", "need": 1, "points": 40},
	{"id": "mushroom_critters", "text": "Defeat 50 Mushroom beasts", "biome": "mushroom", "kind": "minion", "need": 50, "points": 30},
	{"id": "caplet_task", "text": "Defeat Nightmaw", "biome": "mushroom", "kind": "boss", "need": 1, "points": 50},
	{"id": "frost_critters", "text": "Defeat 50 Frost beasts", "biome": "frost", "kind": "minion", "need": 50, "points": 35},
	{"id": "nimbus_task", "text": "Defeat Nimbus", "biome": "frost", "kind": "boss", "need": 1, "points": 60},
	{"id": "volcano_critters", "text": "Defeat 60 Volcano beasts", "biome": "volcano", "kind": "minion", "need": 60, "points": 40},
	{"id": "cinder_task", "text": "Defeat Cinder", "biome": "volcano", "kind": "boss", "need": 1, "points": 70},
]

const SLAYER_SHOP: Array = [
	{"id": "wardens_cache", "name": "Warden's cache", "kind": "gear", "cost": 50, "detail": "A piece of gear for your current hero."},
	{"id": "trail_ribbon", "name": "Trail ribbon", "kind": "cosmetic", "cosmetic": "ribbon", "cost": 30, "detail": "A gold ribbon on your home pedestal."},
	{"id": "slayer_chest", "name": "Hunt chest", "kind": "chest", "cost": 20, "detail": "A hunt chest for the shelf."},
]


static func skill_trophy(id: String) -> Dictionary:
	for entry in SKILL_TROPHIES:
		if str(entry["id"]) == id:
			return entry
	return {}


## The old boss ids and the boss that holds their lair now. Nimbus and Cinder
## own rows of their own -- they stand beside the lair bosses (Boreal,
## Inferno), they do not become them -- so no id moves and the map is empty.
## An old save still resolves: every boss id it names is a live boss.
const LEGACY_BOSSES: Dictionary = {}


## The boss id a lookup should use. A legacy id maps to the boss that holds
## its lair now, but never away from a boss that owns rows of its own: the
## drops of Nimbus are Nimbus', the drops of Cinder are Cinder's. An id that
## is unknown here resolves to itself, so an old save never lands on nothing.
static func resolve_boss(boss_id: String) -> String:
	for entry in DROPS:
		if str(entry["boss"]) == boss_id:
			return boss_id
	return str(LEGACY_BOSSES.get(boss_id, boss_id))


static func drop_table(boss_id: String) -> Array:
	var id := resolve_boss(boss_id)
	var rows: Array = []
	for entry in DROPS:
		if str(entry["boss"]) == id:
			rows.append(entry)
	return rows


static func all_drops() -> Array:
	return DROPS


## Collection-log order: walk the world's biomes in unlock order, then the
## rarest last inside each, then id, so the grid never reshuffles between
## visits and the "x / y" counts line up with what the player sees. A
## biome's lairs follow its own boss, so every drop in the catalog is on the
## board and the log never hides a hoard.
static func log_entries() -> Array:
	var rows: Array = []
	for biome in BIOMES:
		# The biome's own boss and the lairs that stand in the same ground:
		# every drop in the catalog is on the board, so the log never hides
		# a hoard.
		var owners: Array = [str(biome["boss"])]
		for lair in lairs_for(str(biome["id"])):
			owners.append(str(lair["id"]))
		var group: Array = []
		for entry in DROPS:
			if str(entry["boss"]) in owners:
				group.append(entry)
		group.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			var ra := _log_rarity_rank(str(a.get("rarity", "common")))
			var rb := _log_rarity_rank(str(b.get("rarity", "common")))
			if ra != rb:
				return ra < rb
			return str(a.get("id", "")) < str(b.get("id", "")))
		rows.append_array(group)
	return rows


static func log_table(boss_id: String) -> Array:
	var id := resolve_boss(boss_id)
	var rows: Array = []
	for entry in log_entries():
		if str(entry["boss"]) == id:
			rows.append(entry)
	return rows


static func _log_rarity_rank(rarity: String) -> int:
	match rarity:
		"uncommon":
			return 1
		"rare":
			return 2
		"very_rare":
			return 3
		_:
			return 0


static func drop_by_id(id: String) -> Dictionary:
	for entry in DROPS:
		if str(entry["id"]) == id:
			return entry
	return {}


static func bosses() -> Array:
	var ids: Array = []
	for entry in BIOMES:
		ids.append(str(entry["boss"]))
	return ids


## The lairs of a ground, in catalog order. A biome may hold none.
static func lairs_for(biome_id: String) -> Array:
	var out: Array = []
	for entry in LAIRS:
		if str(entry["biome"]) == biome_id:
			out.append(entry)
	return out


## The depth a ground sits in, as a number: 0 the Fringe, 1 the Wilds, 2 the
## Deep, 3 the Abyss (the order of DEPTH_TIERS). A hunt runs at the depth of
## the ground it is hunting.
static func depth_index(id: String) -> int:
	return maxi(0, DEPTH_TIERS.find(depth_tier(id)))


## The lairs that stand in a ground at this depth: a lair appears only where
## the ground is deep enough for it, so a shallow biome holds none.
static func lairs_at_depth(biome_id: String, depth: int) -> Array:
	var out: Array = []
	for entry in lairs_for(biome_id):
		if int(entry.get("depth_min", 0)) <= depth:
			out.append(entry)
	return out


## Every lair boss id. The biome bosses are separate: a lair stands beside
## the biome boss, it never replaces it.
static func lair_bosses() -> Array:
	var out: Array = []
	for entry in LAIRS:
		out.append(str(entry["id"]))
	return out


## The lair row of a boss id, or {} for a plain biome boss.
static func lair_for(boss_id: String) -> Dictionary:
	for entry in LAIRS:
		if str(entry["id"]) == boss_id:
			return entry
	return {}


## The rows a boss always pays: the rare-or-better rows of its own table,
## when it carries a guarantee ("rare" for a lair boss). A biome boss without
## a guarantee pays its weighted roll alone, so the old bosses never change.
static func guaranteed_drops(boss_id: String) -> Array:
	var boss := critter(boss_id)
	var floor := str(boss.get("guarantee", ""))
	if floor == "":
		return []
	var want := _log_rarity_rank(floor)
	var rows: Array = []
	for entry in drop_table(boss_id):
		if str(entry.get("kind", "")) == "pet":
			# Pets are rolled on their own (PET_RATE), never as a guarantee.
			continue
		if _log_rarity_rank(str(entry.get("rarity", "common"))) >= want:
			rows.append(entry)
	return rows


static func is_reveal(drop: Dictionary) -> bool:
	return str(drop.get("kind", "")) == "pet" or str(drop.get("rarity", "")) == "very_rare"


static func rarity_label(rarity: String) -> String:
	match rarity:
		"uncommon":
			return "Uncommon"
		"rare":
			return "Rare"
		"very_rare":
			return "Very rare"
		_:
			return "Common"


static func slayer_task(id: String) -> Dictionary:
	for entry in SLAYER_TASKS:
		if str(entry["id"]) == id:
			return entry
	return {}


static func slayer_offer(id: String) -> Dictionary:
	for entry in SLAYER_SHOP:
		if str(entry["id"]) == id:
			return entry
	return {}


## The top of the Old School XP curve: no skill goes past level 99.
const MAX_SKILL_LEVEL := 99


## Total XP required to reach `level`, matching the Old School curve (1-99).
## The same curve the combat skills use in GearDB.xp_for_level, so a gathering
## level and a combat level are worth the same.
static func skill_xp_to_level(level: int) -> int:
	var points := 0
	var lvl := 1
	while lvl < level:
		points += int(floor(float(lvl) + 300.0 * pow(2.0, float(lvl) / 7.0)))
		lvl += 1
	return int(floor(float(points) / 4.0))


static func skill_level(xp: int) -> int:
	var level := 1
	while level < MAX_SKILL_LEVEL and skill_xp_to_level(level + 1) <= xp:
		level += 1
	return level
