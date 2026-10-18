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
##     "v": 1,
##     "owned":    {hero_id: {item_id: count, ...}, ...},
##     "equipped": {hero_id: {slot_key: item_id, ...}, ...},   # missing/"" = empty
##   }
const SAVE_KEY := "armory"
const SAVE_V := 1

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
		"name": "%s %s" % [TIER_PREFIX[tier], NAMES[hero][slot]], "stats": stats_for(slot, tier)}


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
		data[SAVE_KEY] = {"v": SAVE_V, "owned": {}, "equipped": {}}
	var a: Dictionary = data[SAVE_KEY]
	for k in ["owned", "equipped"]:
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


## Equips an owned item into its slot (replacing what was there).
static func equip(hero: String, id: String) -> bool:
	var it := item(id)
	if it.is_empty() or it["hero"] != hero or not has(hero, id):
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


## Summed stat deltas from everything the hero has on.
static func stats(hero: String) -> Dictionary:
	var out := {}
	for slot in HERO_SLOTS.get(hero, []):
		var id: String = equipped(hero)[slot]
		if id == "":
			continue
		var s: Dictionary = item(id)["stats"]
		for k in s:
			out[k] = out.get(k, 0) + s[k]
	return out


## Stub for loot owners: a random item at a tier (any hero if hero == "").
## Drop tables and source weighting live with the helpers, not here.
static func random_item(rng: RandomNumberGenerator, tier: int, hero := "") -> String:
	var heroes: Array = HERO_SLOTS.keys() if hero == "" else [hero]
	var h: String = heroes[rng.randi() % heroes.size()]
	var slots: Array = HERO_SLOTS[h]
	return item_id(h, str(slots[rng.randi() % slots.size()]), clampi(tier, Tier.IRON, Tier.RUNE))
