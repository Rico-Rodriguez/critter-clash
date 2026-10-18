class_name GearDB
extends RefCounted

## Gear data contract. Every piece is EARNED (camps, elites, bosses, chests,
## the treasure goblin); heroes start bare. Gear is per hero and per slot, and
## each piece has a tier that visibly changes the model when equipped.
## See docs/gear.md. Owners: this file's shape is the contract; drop tables,
## loot rolling, persistence/migration and sim coverage build on the API below.

enum Slot { HELM, CHEST, PAULDRONS, GLOVES, BOOTS, WEAPON, OFFHAND, CHARM }
const SLOT_KEYS: Array[String] = ["helm", "chest", "pauldrons", "gloves", "boots", "weapon", "offhand", "charm"]
const SLOT_NAMES: Array[String] = ["Helm", "Chest", "Pauldrons", "Gloves", "Boots", "Weapon", "Off-hand", "Charm"]

## BARE is "nothing equipped" (underlayer); items exist at IRON..RUNE.
enum Tier { BARE, IRON, STEEL, RUNE }
const TIER_KEYS: Array[String] = ["bare", "iron", "steel", "rune"]
const TIER_NAMES: Array[String] = ["Bare", "Iron", "Blackened Steel", "Cursed Rune Plate"]
const TIER_COLORS: Array[Color] = [Color("6b6258"), Color("b9a68a"), Color("8fb4e8"), Color("ff6a2a")]
## Stat multiplier per tier (index = Tier).
const TIER_MUL: Array[float] = [0.0, 1.0, 1.7, 2.6]

## Save key on SaveGame.data. Shape:
##   data["armory"] = {
##     "v": 2,
##     "owned":    {hero_id: {item_id: count, ...}, ...},
##     "equipped": {hero_id: {slot_key: item_id, ...}, ...},   # missing/"" = empty
##     "xp":       {hero_id: {skill_key: xp_int, ...}, ...},     # missing = start level
##     "reinforce": {hero_id: {item_id: 0..REINFORCE_MAX}, ...},  # coins poured in
##   }
const SAVE_KEY := "armory"
const SAVE_V := 2

## Heroes and the slots each can fill (Gnash fights bare-handed: no off-hand).
const HERO_SLOTS := {
	"pebble": ["helm", "chest", "pauldrons", "gloves", "boots", "weapon", "offhand", "charm"],
	"bramble": ["helm", "chest", "pauldrons", "gloves", "boots", "weapon", "offhand", "charm"],
	"lumen": ["helm", "chest", "pauldrons", "gloves", "boots", "weapon", "charm"],
	"ember": ["helm", "chest", "pauldrons", "gloves", "boots", "weapon", "offhand", "charm"],
}

## Per-hero, per-slot base name; the tier prefixes it ("Iron Bascinet").
const NAMES := {
	"pebble": {"helm": "Horned Helm", "chest": "Cuirass", "pauldrons": "Pauldrons", "gloves": "Gauntlets",
		"boots": "Sabatons", "weapon": "Longsword", "offhand": "Tower Shield", "charm": "Oath Seal"},
	"bramble": {"helm": "Grave Crown", "chest": "Ribcage Plate", "pauldrons": "Bone Spaulders", "gloves": "Ossuary Grips",
		"boots": "Grave Greaves", "weapon": "Duelist Blade", "offhand": "Parrying Dirk", "charm": "Soul Lantern"},
	"lumen": {"helm": "Jaw Cage", "chest": "Stitched Hide", "pauldrons": "Spiked Mantle", "gloves": "Claw Caps",
		"boots": "Wraps", "weapon": "Cleaver Claws", "charm": "Fang Totem"},
	"ember": {"helm": "Beak Mask", "chest": "Oilcloth Coat", "pauldrons": "Crow Mantle", "gloves": "Leech Gloves",
		"boots": "Mire Boots", "weapon": "Censer Staff", "offhand": "Plague Bell", "charm": "Vial of Rot"},
}
const TIER_PREFIX: Array[String] = ["", "Iron", "Blackened", "Runebound"]

## Stat deltas at Tier.IRON (scaled by TIER_MUL). Keys match
## SaveGame.build_run_stats: hp_flat, armor, dmg_pct, haste, crit, speed_pct, regen.
const SLOT_STATS := {
	"helm": {"hp_flat": 10, "armor": 1},
	"chest": {"hp_flat": 22, "armor": 1},
	"pauldrons": {"hp_flat": 8, "dmg_pct": 0.03},
	"gloves": {"haste": 0.03, "dmg_pct": 0.02},
	"boots": {"speed_pct": 0.04, "hp_flat": 6},
	"weapon": {"dmg_pct": 0.1},
	"offhand": {"armor": 1, "hp_flat": 8},
	"charm": {"crit": 0.03, "regen": 0.3},
}
const INT_STATS := ["hp_flat", "armor"]

## Reinforce: coins pour into an owned piece for a small stat bump, +0 to +5.
## Each level scales the piece's own stats; the coin price grows with the tier
## and the next level, so a rune +5 is a long sink.
const REINFORCE_MAX := 5
const REINFORCE_STEP := 0.04
## Base coin price per level at Tier.IRON/STEEL/RUNE (index = Tier); the cost
## of the next level is the base times (level + 1).
const REINFORCE_COST: Array[int] = [0, 50, 120, 260]

# --- Combat skills (OSRS-style, persistent, per hero) ------------------------
## XP from matching actions (wired by helpers): melee hits -> Attack and
## Strength, damage taken or blocked -> Defence, ranged hits -> Ranged,
## spells -> Magic, all damage dealt -> Hitpoints. Levels 1-99, OSRS curve.
enum Skill { ATTACK, STRENGTH, DEFENCE, RANGED, MAGIC, HITPOINTS }
const SKILL_KEYS: Array[String] = ["attack", "strength", "defence", "ranged", "magic", "hitpoints"]
const SKILL_NAMES: Array[String] = ["Attack", "Strength", "Defence", "Ranged", "Magic", "Hitpoints"]
const MAX_LEVEL := 99
## Hitpoints starts at 10 like OSRS; everything else at 1.
const START_LEVEL := {"hitpoints": 10}

## Requirement level per tier (index = Tier) and the skill each slot gates on.
## Weapons gate on the hero's class skill (WEAPON_SKILL).
const REQ_BY_TIER: Array[int] = [0, 1, 20, 40]
const SLOT_SKILL := {
	"helm": "defence", "chest": "defence", "boots": "defence", "offhand": "defence",
	"pauldrons": "strength", "gloves": "strength", "weapon": "", "charm": "hitpoints",
}
const WEAPON_SKILL := {"pebble": "attack", "bramble": "attack", "lumen": "attack", "ember": "magic"}
## Per-item overrides: item_id -> {skill: level}. Merged over the default.
const REQ_OVERRIDES := {}

## Tests and tools may point the API at a scratch dict instead of the save.
static var store_override: Variant = null


# --- Items -----------------------------------------------------------------

## Item id: "<hero>.<slot>.<tier>", e.g. "pebble.helm.2".
static func item_id(hero: String, slot: String, tier: int) -> String:
	return "%s.%s.%d" % [hero, slot, tier]


static func is_item(id: String) -> bool:
	var p := id.split(".")
	if p.size() != 3 or not HERO_SLOTS.has(p[0]) or not (p[1] in HERO_SLOTS[p[0]]):
		return false
	var t := int(p[2])
	return t >= Tier.IRON and t <= Tier.RUNE and str(t) == p[2]


## {id, hero, slot, tier, name, stats} or {} for an unknown id.
static func item(id: String) -> Dictionary:
	if not is_item(id):
		return {}
	var p := id.split(".")
	var hero := p[0]
	var slot := p[1]
	var tier := int(p[2])
	return {"id": id, "hero": hero, "slot": slot, "tier": tier,
		"name": "%s %s" % [TIER_PREFIX[tier], NAMES[hero][slot]], "stats": stats_for(slot, tier),
		"requires": requirements(id)}


## {skill_key: level} needed to equip (empty = no requirement).
static func requirements(id: String) -> Dictionary:
	if not is_item(id):
		return {}
	var p := id.split(".")
	var tier := int(p[2])
	var skill: String = SLOT_SKILL.get(p[1], "")
	if p[1] == "weapon":
		skill = WEAPON_SKILL.get(p[0], "attack")
	var out := {}
	if skill != "" and REQ_BY_TIER[tier] > 1:
		out[skill] = REQ_BY_TIER[tier]
	out.merge(REQ_OVERRIDES.get(id, {}), true)
	return out


static func stats_for(slot: String, tier: int) -> Dictionary:
	var out := {}
	var base: Dictionary = SLOT_STATS.get(slot, {})
	for k in base:
		var v := float(base[k]) * TIER_MUL[clampi(tier, 0, 3)]
		out[k] = int(round(v)) if k in INT_STATS else v
	return out


## Every item id in the game (4 heroes x their slots x 3 tiers).
static func all_items(hero := "") -> Array[String]:
	var out: Array[String] = []
	for h in HERO_SLOTS:
		if hero != "" and h != hero:
			continue
		for slot in HERO_SLOTS[h]:
			for t in range(Tier.IRON, Tier.RUNE + 1):
				out.append(item_id(h, slot, t))
	return out


# --- Store -----------------------------------------------------------------

static func _store() -> Dictionary:
	var data: Dictionary
	if store_override != null:
		data = store_override
	else:
		var tree := Engine.get_main_loop() as SceneTree
		var save: Node = tree.root.get_node_or_null("/root/SaveGame") if tree else null
		if save == null:
			store_override = {}
			data = store_override
		else:
			data = save.data
	if not data.has(SAVE_KEY) or typeof(data[SAVE_KEY]) != TYPE_DICTIONARY:
		data[SAVE_KEY] = {"v": SAVE_V, "owned": {}, "equipped": {}, "xp": {}, "reinforce": {}}
	var a: Dictionary = data[SAVE_KEY]
	for k in ["owned", "equipped", "xp", "reinforce"]:
		if not a.has(k) or typeof(a[k]) != TYPE_DICTIONARY:
			a[k] = {}
	return a


static func _persist() -> void:
	if store_override != null:
		return
	var tree := Engine.get_main_loop() as SceneTree
	var save: Node = tree.root.get_node_or_null("/root/SaveGame") if tree else null
	if save and save.has_method("_write"):
		save._write()


# --- API -------------------------------------------------------------------

## Adds one copy of an item to its hero's stash. False for unknown ids.
static func grant(id: String) -> bool:
	var it := item(id)
	if it.is_empty():
		return false
	var owned: Dictionary = _store()["owned"]
	var h: String = it["hero"]
	if not owned.has(h):
		owned[h] = {}
	owned[h][id] = int(owned[h].get(id, 0)) + 1
	_persist()
	return true


## {ok: bool, reason: String}. Reasons: "Unknown item", "Not for this hero",
## "Not owned", "Requires Defence 20" (first unmet requirement).
static func can_equip(hero: String, id: String) -> Dictionary:
	var it := item(id)
	if it.is_empty():
		return {"ok": false, "reason": "Unknown item"}
	if it["hero"] != hero:
		return {"ok": false, "reason": "Not for this hero"}
	if not has(hero, id):
		return {"ok": false, "reason": "Not owned"}
	var req: Dictionary = it["requires"]
	for k in SKILL_KEYS:
		if req.has(k) and level(hero, k) < int(req[k]):
			return {"ok": false, "reason": "Requires %s %d" % [SKILL_NAMES[SKILL_KEYS.find(k)], int(req[k])]}
	return {"ok": true, "reason": ""}


## Equips an owned item into its slot (replacing what was there). Refuses
## unmet requirements; call can_equip() for the reason to show.
static func equip(hero: String, id: String) -> bool:
	var it := item(id)
	if not bool(can_equip(hero, id)["ok"]):
		return false
	var eq: Dictionary = _store()["equipped"]
	if not eq.has(hero):
		eq[hero] = {}
	eq[hero][it["slot"]] = id
	_persist()
	return true


static func unequip(hero: String, slot: String) -> void:
	var eq: Dictionary = _store()["equipped"]
	if eq.has(hero):
		eq[hero].erase(slot)
		_persist()


## {slot_key: item_id or ""} for every slot this hero has.
static func equipped(hero: String) -> Dictionary:
	var eq: Dictionary = _store()["equipped"].get(hero, {})
	var out := {}
	for slot in HERO_SLOTS.get(hero, []):
		var id := str(eq.get(slot, ""))
		out[slot] = id if is_item(id) else ""
	return out


## Owned item ids for a hero (each once), best tier first.
static func owned(hero: String) -> Array[String]:
	var out: Array[String] = []
	var o: Dictionary = _store()["owned"].get(hero, {})
	for id in o:
		if int(o[id]) > 0 and is_item(str(id)):
			out.append(str(id))
	out.sort_custom(func(a, b): return int(a.get_slice(".", 2)) > int(b.get_slice(".", 2)) or (a.get_slice(".", 2) == b.get_slice(".", 2) and a < b))
	return out


static func has(hero: String, id: String) -> bool:
	return int(_store()["owned"].get(hero, {}).get(id, 0)) > 0


## Tier showing in a slot (Tier.BARE when empty). Gear3D renders from this.
static func slot_tier(hero: String, slot: String) -> int:
	var id: String = equipped(hero).get(slot, "")
	return int(id.get_slice(".", 2)) if id != "" else Tier.BARE


## {slot_key: tier} for rendering.
static func tiers(hero: String) -> Dictionary:
	var out := {}
	for slot in HERO_SLOTS.get(hero, []):
		out[slot] = slot_tier(hero, slot)
	return out


## Summed stat deltas from everything the hero has on, with each piece's
## reinforce levels folded in (the next level adds REINFORCE_STEP of its stats).
static func stats(hero: String) -> Dictionary:
	var out := {}
	for slot in HERO_SLOTS.get(hero, []):
		var id: String = equipped(hero)[slot]
		if id == "":
			continue
		var s: Dictionary = item(id)["stats"]
		var mul := 1.0 + REINFORCE_STEP * float(reinforce_level(hero, id))
		for k in s:
			var v := float(s[k]) * mul
			out[k] = out.get(k, 0) + (int(round(v)) if k in INT_STATS else v)
	return out


# --- Reinforce ---------------------------------------------------------------

## Reinforce levels on a hero's owned piece (0 when unknown/unowned).
static func reinforce_level(hero: String, id: String) -> int:
	var row: Dictionary = _store()["reinforce"].get(hero, {})
	return clampi(int(row.get(id, 0)), 0, REINFORCE_MAX)


## Coin price to take an owned piece to its next reinforce level; 0 when the
## piece is unknown, not this hero's, or already at REINFORCE_MAX.
static func reinforce_cost(hero: String, id: String) -> int:
	var it := item(id)
	if it.is_empty() or str(it["hero"]) != hero or not has(hero, id):
		return 0
	var lvl := reinforce_level(hero, id)
	if lvl >= REINFORCE_MAX:
		return 0
	return REINFORCE_COST[int(it["tier"])] * (lvl + 1)


## Pour coins into one owned piece: +1 reinforce (stats rise, see stats()), up
## to REINFORCE_MAX. Refuses unknown/foreign/unowned pieces, a maxed piece and
## an unaffordable price; the wallet never goes negative.
static func reinforce(hero: String, id: String) -> bool:
	var it := item(id)
	if it.is_empty() or str(it["hero"]) != hero or not has(hero, id):
		return false
	var lvl := reinforce_level(hero, id)
	if lvl >= REINFORCE_MAX:
		return false
	var cost := REINFORCE_COST[int(it["tier"])] * (lvl + 1)
	var save := _save_node()
	if save == null:
		return false
	var wallet := int((save as Node).data.get("coins", 0))
	if wallet < cost:
		return false
	var all: Dictionary = _store()["reinforce"]
	if not all.has(hero):
		all[hero] = {}
	all[hero][id] = lvl + 1
	(save as Node).data["coins"] = wallet - cost
	_persist()
	return true


static func _save_node() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null("/root/SaveGame") if tree else null


## Stub for loot owners: a random item at a tier (any hero if hero == "").
## Drop tables and source weighting live with the helpers, not here.
static func random_item(rng: RandomNumberGenerator, tier: int, hero := "") -> String:
	var heroes: Array = HERO_SLOTS.keys() if hero == "" else [hero]
	var h: String = heroes[rng.randi() % heroes.size()]
	var slots: Array = HERO_SLOTS[h]
	return item_id(h, str(slots[rng.randi() % slots.size()]), clampi(tier, Tier.IRON, Tier.RUNE))


# --- Skills API --------------------------------------------------------------

## Total XP to reach a level (OSRS): sum over l < L of floor(l + 300 * 2^(l/7)) / 4.
static func xp_for_level(lvl: int) -> int:
	var pts := 0
	for l in range(1, clampi(lvl, 1, MAX_LEVEL)):
		pts += int(floor(l + 300.0 * pow(2.0, l / 7.0)))
	return int(floor(pts / 4.0))


static func level_for_xp(xp_total: int) -> int:
	var lvl := 1
	while lvl < MAX_LEVEL and xp_total >= xp_for_level(lvl + 1):
		lvl += 1
	return lvl


static func xp(hero: String, skill: String) -> int:
	var row: Dictionary = _store()["xp"].get(hero, {})
	if row.has(skill):
		return int(row[skill])
	return xp_for_level(int(START_LEVEL.get(skill, 1)))


static func level(hero: String, skill: String) -> int:
	return level_for_xp(xp(hero, skill))


## {skill_key: level} for a hero.
static func skills(hero: String) -> Dictionary:
	var out := {}
	for k in SKILL_KEYS:
		out[k] = level(hero, k)
	return out


## Adds XP; returns the number of levels gained (for level-up toasts).
static func add_xp(hero: String, skill: String, amount: int) -> int:
	if not (skill in SKILL_KEYS) or amount <= 0:
		return 0
	var before := level(hero, skill)
	var all: Dictionary = _store()["xp"]
	if not all.has(hero):
		all[hero] = {}
	all[hero][skill] = mini(xp(hero, skill) + amount, xp_for_level(MAX_LEVEL) * 2)
	_persist()
	return level(hero, skill) - before


## Trained power: skill levels are the hero's base-stat growth now that the
## coin/card Upgrade is gone. A fresh hero sits at the start levels, so every
## delta is zero and bare run stats match Catalog.base_stats exactly. The
## coefficients are tuned so a level-20 main damage skill lands near the old
## mid-card-upgrade power (card 5 scaled hp and dmg by 1 + 0.08 * 4 = 1.32).
const DAMAGE_PER_LEVEL := 0.016
const HP_PER_LEVEL := 0.016
const CRIT_PER_ATTACK := 0.001
const ARMOR_PER_DEFENCE := 0.1


## Per-level stat hook, folded into run stats next to stats(hero): the single
## place skill levels become hero power. Attack +0.1% crit per level, Strength
## +1.6% damage, Defence +0.1 armour, Hitpoints +1.6% max HP per level over 10,
## and Ranged/Magic +1.6% damage for heroes whose weapon uses that skill.
static func level_bonus(hero: String) -> Dictionary:
	var s := skills(hero)
	var out := {
		"crit": (s["attack"] - 1) * CRIT_PER_ATTACK,
		"dmg_pct": (s["strength"] - 1) * DAMAGE_PER_LEVEL,
		"armor": (s["defence"] - 1) * ARMOR_PER_DEFENCE,
		"hp_pct": maxf(0.0, float(s["hitpoints"] - 10)) * HP_PER_LEVEL,
	}
	var ws: String = WEAPON_SKILL.get(hero, "attack")
	if ws == "ranged" or ws == "magic":
		out["dmg_pct"] += (s[ws] - 1) * DAMAGE_PER_LEVEL
	return out
