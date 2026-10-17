class_name Catalog
extends RefCounted

## Static roster, biomes, waves, upgrade cards, and trophy milestones.
## Habitat never changes a critter's role. A tamed boss is a new hero with a fixed role.

const BOSS_AT := 68.0
const MAX_CARD_LEVEL := 10
const MAX_RUN_LEVEL := 8

const WAVES: Array = [
	{"until": 18.0, "every": 1.62, "pool": [0, 0, 0, 1]},
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


static func role_name(role: String) -> String:
	match role:
		"mage":
			return "Mage"
		"archer":
			return "Archer"
		"tank":
			return "Tank"
		_:
			return "Critter"


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
	}


static func roll_offer(role: String, stacks: Dictionary, rng: RandomNumberGenerator) -> Array:
	_index_cards()
	var picked: Array = []
	var guard := 0
	while picked.size() < 3 and guard < 48:
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
			picked.append("snack")
			continue
		picked.append(str(pool[rng.randi() % pool.size()]["id"]))
	return picked


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
		"name": "Snack",
		"rarity": "common",
		"op": "heal",
		"n": 22,
		"max": 99,
		"roles": [],
		"desc": "Heal 22 right now.",
	}


const PLAYABLE: Array = [
	"ember", "juniper", "pebble", "lumen", "pip", "bramble",
	"thistle", "caplet", "nimbus", "cinder",
]

const BIOMES: Array = [
	{
		"id": "meadow",
		"name": "Meadow",
		"boss": "thistle",
		"gate": 0,
		"need": "",
		"hp_mul": 1.0,
		"dmg_mul": 1.0,
		"boss_mul": 1.0,
		"skins": ["sprout", "beetle", "moth", "boarlet"],
		"blurb": "Sun on the grass. Thistle keeps the flowers.",
	},
	{
		"id": "mushroom",
		"name": "Mushroom Forest",
		"boss": "caplet",
		"gate": 30,
		"need": "meadow",
		"hp_mul": 1.14,
		"dmg_mul": 1.08,
		"boss_mul": 1.2,
		"skins": ["capling", "spore", "glowmoth", "puddle"],
		"blurb": "Blue shade and fat caps. Caplet waits underneath.",
	},
	{
		"id": "frost",
		"name": "Frost Peaks",
		"boss": "nimbus",
		"gate": 80,
		"need": "mushroom",
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
		"gate": 150,
		"need": "frost",
		"hp_mul": 1.42,
		"dmg_mul": 1.24,
		"boss_mul": 1.58,
		"skins": ["cindling", "skink", "ashbat", "magmash"],
		"blurb": "Warm stone and slow lava. Cinder naps in it.",
	},
]

const MILESTONES: Array = [
	{"id": "m10", "trophies": 10, "kind": "coins", "amount": 40, "label": "Coin purse", "detail": "40 coins"},
	{"id": "m30", "trophies": 30, "kind": "chest", "label": "Trail chest", "detail": "A hunt chest"},
	{"id": "m45", "trophies": 45, "kind": "unlock", "hero": "lumen", "cards": 8, "label": "Lumen joins", "detail": "Owl archer unlocked"},
	{"id": "m80", "trophies": 80, "kind": "gear", "slot": "charm", "rarity": "rare", "label": "Rare charm", "detail": "A charm for any hero"},
	{"id": "m110", "trophies": 110, "kind": "unlock", "hero": "pip", "cards": 8, "label": "Pip joins", "detail": "Frog mage unlocked"},
	{"id": "m150", "trophies": 150, "kind": "unlock", "hero": "bramble", "cards": 8, "label": "Bramble joins", "detail": "Hedgehog tank unlocked"},
	{"id": "m190", "trophies": 190, "kind": "coins", "amount": 120, "label": "Heavy purse", "detail": "120 coins"},
	{"id": "m240", "trophies": 240, "kind": "gear", "slot": "weapon", "rarity": "epic", "label": "Epic weapon", "detail": "A strong weapon"},
]

## op is how a stack changes the run. roles empty means every hero.
## Exclusive cards are the epic role rows.
const CARDS: Array = [
	{"id": "might", "name": "Might", "rarity": "common", "op": "dmg", "n": 5, "max": 5, "roles": [], "desc": "Damage +5."},
	{"id": "haste", "name": "Quick Paws", "rarity": "common", "op": "haste", "n": 0.14, "max": 5, "roles": [], "desc": "Attack faster."},
	{"id": "vitality", "name": "Thick Hide", "rarity": "common", "op": "hp", "n": 24, "max": 5, "roles": [], "desc": "Max health +24."},
	{"id": "swift", "name": "Light Foot", "rarity": "common", "op": "swift", "n": 0.08, "max": 4, "roles": [], "desc": "Move faster."},
	{"id": "crit", "name": "Lucky Spark", "rarity": "common", "op": "crit", "n": 0.06, "max": 5, "roles": [], "desc": "Crit chance +6%."},
	{"id": "regen", "name": "Dew Sip", "rarity": "common", "op": "regen", "n": 1.4, "max": 4, "roles": [], "desc": "Regenerate 1.4 health each second."},
	{"id": "magnet", "name": "Gem Magnet", "rarity": "common", "op": "magnet", "n": 42, "max": 3, "roles": [], "desc": "Gems fly in from farther away."},
	{"id": "might_plus", "name": "Heavy Blow", "rarity": "rare", "op": "dmg", "n": 11, "max": 3, "roles": [], "desc": "Damage +11."},
	{"id": "bounce", "name": "Ricochet", "rarity": "rare", "op": "bounce", "n": 1, "max": 3, "roles": [], "desc": "Attacks bounce to another critter."},
	{"id": "multishot", "name": "Multishot", "rarity": "rare", "op": "shots", "n": 1, "max": 2, "roles": [], "desc": "Fire an extra shot."},
	{"id": "armor", "name": "Bark Coat", "rarity": "rare", "op": "armor", "n": 2, "max": 4, "roles": [], "desc": "Armor +2."},
	{"id": "siphon", "name": "Nibble", "rarity": "rare", "op": "siphon", "n": 0.05, "max": 3, "roles": [], "desc": "Heal a little of the damage you deal."},
	{"id": "vitality_plus", "name": "Hearty", "rarity": "rare", "op": "hp", "n": 42, "max": 2, "roles": [], "desc": "Max health +42."},
	{"id": "mage_radius", "name": "Wider Splash", "rarity": "epic", "op": "splash", "n": 32, "max": 3, "roles": ["mage"], "desc": "Mage exclusive. Splash reaches farther."},
	{"id": "mage_power", "name": "Hotter Splash", "rarity": "epic", "op": "splash_mul", "n": 0.25, "max": 3, "roles": ["mage"], "desc": "Mage exclusive. Splash hits harder."},
	{"id": "archer_pierce", "name": "Pierce", "rarity": "epic", "op": "pierce", "n": 1, "max": 4, "roles": ["archer"], "desc": "Archer exclusive. Shots fly through another critter."},
	{"id": "tank_thorns", "name": "Thorns", "rarity": "epic", "op": "thorns", "n": 0.22, "max": 4, "roles": ["tank"], "desc": "Tank exclusive. Attackers take damage back."},
	{"id": "tank_bash", "name": "Shield Bash", "rarity": "epic", "op": "bash", "n": 1, "max": 3, "roles": ["tank"], "desc": "Tank exclusive. Melee sends a shockwave."},
	{"id": "second_wind", "name": "Second Wind", "rarity": "legendary", "op": "revive", "n": 1, "max": 1, "roles": [], "desc": "Once, get back up at half health."},
]

const CRITTERS: Dictionary = {
	"ember": {
		"name": "Ember", "role": "mage", "kind": "hero", "color": "ff7a3c",
		"blurb": "Dragon mage. Fire orbs splash.",
		"unlock": "A starter hero.",
		"hp": 168, "dmg": 19, "interval": 0.46, "range": 320, "speed": 268,
		"splash": 92, "splash_mul": 0.66, "proj_speed": 520, "armor": 0,
	},
	"juniper": {
		"name": "Juniper", "role": "archer", "kind": "hero", "color": "e07a3d",
		"blurb": "Fox archer. Fast arrows.",
		"unlock": "A starter hero.",
		"hp": 116, "dmg": 14, "interval": 0.33, "range": 400, "speed": 292,
		"splash": 0, "splash_mul": 0.0, "proj_speed": 780, "armor": 0,
	},
	"pebble": {
		"name": "Pebble", "role": "tank", "kind": "hero", "color": "3aa8a0",
		"blurb": "Otter tank. Melee, and hard to move.",
		"unlock": "A starter hero.",
		"hp": 280, "dmg": 27, "interval": 0.42, "range": 138, "speed": 244,
		"splash": 0, "splash_mul": 0.0, "proj_speed": 420, "armor": 3,
	},
	"lumen": {
		"name": "Lumen", "role": "archer", "kind": "hero", "color": "f0d7a2",
		"blurb": "Owl archer. Long sight, quiet shots.",
		"unlock": "Trophy road.",
		"hp": 122, "dmg": 14, "interval": 0.38, "range": 430, "speed": 268,
		"splash": 0, "splash_mul": 0.0, "proj_speed": 720, "armor": 0,
	},
	"pip": {
		"name": "Pip", "role": "mage", "kind": "hero", "color": "7dba62",
		"blurb": "Frog mage. Bubbles splash and bounce.",
		"unlock": "Trophy road.",
		"hp": 138, "dmg": 15, "interval": 0.48, "range": 280, "speed": 270,
		"splash": 68, "splash_mul": 0.7, "proj_speed": 510, "armor": 0,
	},
	"bramble": {
		"name": "Bramble", "role": "tank", "kind": "hero", "color": "8d6244",
		"blurb": "Hedgehog tank. Spines out, feet planted.",
		"unlock": "Trophy road.",
		"hp": 276, "dmg": 20, "interval": 0.52, "range": 110, "speed": 214,
		"splash": 0, "splash_mul": 0.0, "proj_speed": 400, "armor": 4,
	},
	"thistle": {
		"name": "Thistle", "role": "tank", "kind": "boss", "color": "c46b8a",
		"blurb": "Meadow boss. A flower-crowned boar.",
		"unlock": "Tame the Meadow boss.",
		"hp": 252, "dmg": 23, "interval": 0.48, "range": 118, "speed": 232,
		"splash": 0, "splash_mul": 0.0, "proj_speed": 420, "armor": 3,
		"boss_hp": 1720, "boss_speed": 74, "boss_radius": 78, "boss_touch": 15,
		"aoe": 24, "charge": 30, "shot": 11,
		"bias_charge": 0.46, "bias_aoe": 0.34,
	},
	"caplet": {
		"name": "Caplet", "role": "mage", "kind": "boss", "color": "d45ad0",
		"blurb": "Mushroom boss. A toad in a red cap.",
		"unlock": "Tame the Mushroom Forest boss.",
		"hp": 160, "dmg": 17, "interval": 0.55, "range": 300, "speed": 246,
		"splash": 86, "splash_mul": 0.7, "proj_speed": 450, "armor": 0,
		"boss_hp": 1500, "boss_speed": 64, "boss_radius": 80, "boss_touch": 15,
		"aoe": 26, "charge": 26, "shot": 12,
		"bias_charge": 0.16, "bias_aoe": 0.40,
	},
	"nimbus": {
		"name": "Nimbus", "role": "archer", "kind": "boss", "color": "d7e7f6",
		"blurb": "Frost boss. A hare made of weather.",
		"unlock": "Tame the Frost Peaks boss.",
		"hp": 128, "dmg": 16, "interval": 0.32, "range": 410, "speed": 308,
		"splash": 0, "splash_mul": 0.0, "proj_speed": 800, "armor": 0,
		"boss_hp": 1420, "boss_speed": 92, "boss_radius": 70, "boss_touch": 14,
		"aoe": 22, "charge": 28, "shot": 12,
		"bias_charge": 0.40, "bias_aoe": 0.22,
	},
	"cinder": {
		"name": "Cinder", "role": "mage", "kind": "boss", "color": "ff5a32",
		"blurb": "Volcano boss. A round lava salamander.",
		"unlock": "Tame the Ember Volcano boss.",
		"hp": 168, "dmg": 19, "interval": 0.52, "range": 290, "speed": 248,
		"splash": 98, "splash_mul": 0.74, "proj_speed": 440, "armor": 1,
		"boss_hp": 1680, "boss_speed": 68, "boss_radius": 82, "boss_touch": 18,
		"aoe": 28, "charge": 32, "shot": 13,
		"bias_charge": 0.22, "bias_aoe": 0.50,
	},
	"sprout": {"name": "Sprout", "kind": "minion", "archetype": "chaser", "color": "67b85a", "hp": 28, "dmg": 7, "speed": 96, "radius": 24, "xp": 2},
	"beetle": {"name": "Beetle", "kind": "minion", "archetype": "runner", "color": "d2a03a", "hp": 38, "dmg": 8, "speed": 128, "radius": 22, "xp": 3},
	"moth": {"name": "Moth", "kind": "minion", "archetype": "shooter", "color": "f0e2b0", "hp": 22, "dmg": 7, "speed": 72, "radius": 22, "xp": 3, "interval": 1.55, "shot_speed": 200, "shot_range": 250},
	"boarlet": {"name": "Boarlet", "kind": "minion", "archetype": "brute", "color": "c47858", "hp": 78, "dmg": 11, "speed": 88, "radius": 30, "xp": 5},
	"capling": {"name": "Capling", "kind": "minion", "archetype": "chaser", "color": "d85a8a", "hp": 32, "dmg": 8, "speed": 100, "radius": 24, "xp": 2},
	"spore": {"name": "Spore", "kind": "minion", "archetype": "runner", "color": "c9b6ef", "hp": 40, "dmg": 9, "speed": 150, "radius": 22, "xp": 3},
	"glowmoth": {"name": "Glowmoth", "kind": "minion", "archetype": "shooter", "color": "8ef0c8", "hp": 30, "dmg": 9, "speed": 76, "radius": 22, "xp": 3, "interval": 1.3, "shot_speed": 235, "shot_range": 290},
	"puddle": {"name": "Puddle", "kind": "minion", "archetype": "brute", "color": "6a8f4e", "hp": 96, "dmg": 13, "speed": 90, "radius": 32, "xp": 5},
	"snowpup": {"name": "Snowpup", "kind": "minion", "archetype": "chaser", "color": "e7f2fb", "hp": 34, "dmg": 8, "speed": 108, "radius": 24, "xp": 2},
	"shard": {"name": "Shard", "kind": "minion", "archetype": "runner", "color": "9fd4ef", "hp": 44, "dmg": 10, "speed": 156, "radius": 22, "xp": 3},
	"icewisp": {"name": "Icewisp", "kind": "minion", "archetype": "shooter", "color": "d5f4ff", "hp": 30, "dmg": 10, "speed": 80, "radius": 22, "xp": 3, "interval": 1.25, "shot_speed": 250, "shot_range": 300},
	"yeti": {"name": "Yeti", "kind": "minion", "archetype": "brute", "color": "f7f7fb", "hp": 110, "dmg": 14, "speed": 88, "radius": 34, "xp": 5},
	"cindling": {"name": "Cindling", "kind": "minion", "archetype": "chaser", "color": "ff8a3c", "hp": 34, "dmg": 9, "speed": 110, "radius": 24, "xp": 2},
	"skink": {"name": "Skink", "kind": "minion", "archetype": "runner", "color": "e25b2a", "hp": 46, "dmg": 10, "speed": 160, "radius": 22, "xp": 3},
	"ashbat": {"name": "Ashbat", "kind": "minion", "archetype": "shooter", "color": "6a534c", "hp": 32, "dmg": 11, "speed": 84, "radius": 22, "xp": 3, "interval": 1.2, "shot_speed": 255, "shot_range": 300},
	"magmash": {"name": "Magmash", "kind": "minion", "archetype": "brute", "color": "ff5a2a", "hp": 120, "dmg": 15, "speed": 86, "radius": 34, "xp": 5},
}
