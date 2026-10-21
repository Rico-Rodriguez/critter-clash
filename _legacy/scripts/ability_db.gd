class_name AbilityDB
extends RefCounted

## Class ability data contract. Every starting class owns two abilities: the
## class's answer to a situation the plain attack cannot cover. This file is
## the data layer only - the sim casts them and the HUD lists them in a later
## phase. See docs/abilities.md.
##
## An ability is:
##   id        unique key
##   class     the class that owns it (a key of CLASSES)
##   name      display name
##   kind      the effect verb (see KINDS)
##   cooldown  seconds of sim time before it can be used again
##   cost      mana the cast spends
##   power     the base magnitude, before the trained skill scales it
##   scale     {"skill", "per_level", "cap"} - the trained skill that feeds it
##   radius    the area it covers in world units (0 = a single target)
##   range     how far away it can be used (0 = it does not reach out)
##   duration  how long it lasts (a buff, an aura) or how long it spins
##   hits      how many times it strikes
##   targets   "foes", "party" or "self"
##   desc      one line for the tooltip
##
## What power means, by kind:
##   aoe_spin  fraction of the caster's damage per hit, hits times over
##   leap      fraction of the caster's damage on the landing
##   slam      fraction of the caster's damage per foe in the radius
##   nova      fraction of the caster's damage per foe in the ring
##   nuke      fraction of the caster's damage on its one target
##   multi_hit fraction of the caster's damage per hit, hits times
##   aura      health a second that each ally in the field heals
##   buff      fraction of incoming damage avoided while it lasts
##   summon    fraction of the caster's damage the servant deals per hit
##   shape     fraction of damage the caster adds while shifted
##
## Every ability scales with a trained combat skill (a GearDB.SKILL_KEYS key),
## and each class scales with a skill that class really trains: the Barbarian
## with Strength and Attack, the Paladin with Strength and Hitpoints, the
## Sorceress with Magic, the Rogue with Ranged and Defence, the Necromancer
## with Magic and Hitpoints, the Druid with Strength and Defence. A fresh hero
## sits at the start level of its skill, so a new ability does exactly its base
## power and training lifts it from there - the same way GearDB.level_bonus
## grows the hero's own stats.

## The effect verbs an ability can use.
const KINDS: Array[String] = ["aoe_spin", "leap", "aura", "slam", "nova", "nuke", "multi_hit", "buff", "summon", "shape"]

## The starting classes and the abilities each one owns. The class id is
## the hero id in Catalog.CRITTERS; the role is the one the class fights under
## (run_sim's ROLE_TUNING is keyed by role, never by hero id). The roster
## itself - stats, model, unlock - belongs to the class phase, not to this
## file: this file only owns what a class can DO.
const CLASSES: Dictionary = {
	"barbarian": {
		"name": "Barbarian", "role": "tank",
		"blurb": "A wandering berserker from the Dreadlands. Twin axes carve a red path through the barrows.",
		"abilities": ["whirlwind", "leap"],
	},
	"paladin": {
		"name": "Paladin", "role": "tank",
		"blurb": "A Zakarum zealot clad in blessed steel. Sword and shield hold the line against the dark.",
		"abilities": ["aura_of_light", "shield_slam"],
	},
	"sorceress": {
		"name": "Sorceress", "role": "mage",
		"blurb": "A Vizjerei prodigy. Fire, ice and lightning answer her call from afar.",
		"abilities": ["frost_nova", "fireball"],
	},
	"rogue": {
		"name": "Rogue", "role": "archer",
		"blurb": "A Sister of the Sightless Eye. Bows and traps strike unseen from the shadows.",
		"abilities": ["fan_of_knives", "vanish"],
	},
	"necromancer": {
		"name": "Necromancer", "role": "mage",
		"blurb": "A binder of bone. The dead rise at her call and hold the line beside her.",
		"abilities": ["raise_skeleton", "bone_spikes"],
	},
	"druid": {
		"name": "Druid", "role": "tank",
		"blurb": "A shapeshifter of the wilds. Bear form, thornwood, and the patience of the grove.",
		"abilities": ["wild_shape", "thorn_lash"],
	},
}

## The abilities. Two per class, ordered the way the class lists them.
const ABILITIES: Array = [
	# --- Barbarian ---
	{"id": "whirlwind", "class": "barbarian", "name": "Whirlwind", "kind": "aoe_spin",
		"cooldown": 9.0, "cost": 25, "power": 0.45, "scale": {"skill": "strength", "per_level": 0.02, "cap": 1.2},
		"radius": 170.0, "duration": 1.2, "hits": 3, "targets": "foes",
		"desc": "Spin through the ring, cutting every foe that comes close."},
	{"id": "leap", "class": "barbarian", "name": "Leap", "kind": "leap",
		"cooldown": 6.0, "cost": 15, "power": 0.9, "scale": {"skill": "attack", "per_level": 0.02, "cap": 1.2},
		"range": 320.0, "radius": 90.0, "targets": "foes",
		"desc": "Hurl yourself at the farthest foe and crush the landing."},
	# --- Paladin ---
	{"id": "aura_of_light", "class": "paladin", "name": "Aura of Light", "kind": "aura",
		"cooldown": 20.0, "cost": 30, "power": 2.0, "scale": {"skill": "hitpoints", "per_level": 0.05, "cap": 4.0},
		"radius": 260.0, "duration": 8.0, "targets": "party",
		"desc": "Holy light stands around you and mends everyone inside it."},
	{"id": "shield_slam", "class": "paladin", "name": "Shield Slam", "kind": "slam",
		"cooldown": 7.0, "cost": 20, "power": 1.1, "scale": {"skill": "strength", "per_level": 0.025, "cap": 1.4},
		"radius": 120.0, "duration": 0.4, "targets": "foes",
		"desc": "Drive the shield down. The ground shakes and nearby foes stagger."},
	# --- Sorceress ---
	{"id": "frost_nova", "class": "sorceress", "name": "Frost Nova", "kind": "nova",
		"cooldown": 12.0, "cost": 30, "power": 0.6, "scale": {"skill": "magic", "per_level": 0.02, "cap": 1.1},
		"radius": 190.0, "targets": "foes",
		"desc": "A ring of frost bites everything around you and slows it."},
	{"id": "fireball", "class": "sorceress", "name": "Fireball", "kind": "nuke",
		"cooldown": 8.0, "cost": 35, "power": 2.4, "scale": {"skill": "magic", "per_level": 0.03, "cap": 2.0},
		"range": 340.0, "targets": "foes",
		"desc": "One burning bolt, one target, all of it."},
	# --- Rogue ---
	{"id": "fan_of_knives", "class": "rogue", "name": "Fan of Knives", "kind": "multi_hit",
		"cooldown": 10.0, "cost": 25, "power": 0.25, "scale": {"skill": "ranged", "per_level": 0.012, "cap": 0.8},
		"radius": 200.0, "hits": 5, "targets": "foes",
		"desc": "A fan of knives shreds every foe in its arc."},
	{"id": "vanish", "class": "rogue", "name": "Vanish", "kind": "buff",
		"cooldown": 18.0, "cost": 25, "power": 0.35, "scale": {"skill": "defence", "per_level": 0.01, "cap": 0.35},
		"duration": 4.0, "targets": "self",
		"desc": "Step out of sight. The next blows are harder to land."},
]


# --- Lookups -----------------------------------------------------------------

## The ability record, or {} for an unknown id.
static func ability(id: String) -> Dictionary:
	for entry in ABILITIES:
		if str(entry["id"]) == id:
			return entry
	return {}


static func has_ability(id: String) -> bool:
	return not ability(id).is_empty()


## Every ability, in table order.
static func abilities() -> Array:
	return ABILITIES


## The class record, or {} for an unknown class id.
static func class_info(class_id: String) -> Dictionary:
	return CLASSES.get(class_id, {})


## The class ids, in the order CLASSES lists them.
static func class_ids() -> Array[String]:
	var out: Array[String] = []
	for key in CLASSES.keys():
		out.append(str(key))
	return out


## The display name of a class, or the id itself. (Not called class_name:
## that word is a GDScript keyword.)
static func class_display_name(class_id: String) -> String:
	var c := class_info(class_id)
	return str(c["name"]) if not c.is_empty() else class_id


## The class that owns an ability, or "" for an unknown id.
static func class_of_ability(id: String) -> String:
	var a := ability(id)
	return str(a["class"]) if not a.is_empty() else ""


## The abilities of one class, in the order the class lists them.
static func abilities_for_class(class_id: String) -> Array:
	var out: Array = []
	var c := class_info(class_id)
	if c.is_empty():
		return out
	var ids: Array = c.get("abilities", [])
	for id in ids:
		var a := ability(str(id))
		if not a.is_empty():
			out.append(a)
	return out


## The ability ids of one class, in the order the class lists them.
static func ability_ids_for_class(class_id: String) -> Array[String]:
	var out: Array[String] = []
	for a in abilities_for_class(class_id):
		out.append(str(a["id"]))
	return out


## The display name of an ability, or the id itself.
static func name_of(id: String) -> String:
	var a := ability(id)
	return str(a["name"]) if not a.is_empty() else id


## The one-line description of an ability, or "" for an unknown id.
static func desc_of(id: String) -> String:
	var a := ability(id)
	return str(a.get("desc", "")) if not a.is_empty() else ""


## The effect verb of an ability, or "" for an unknown id.
static func kind_of(id: String) -> String:
	var a := ability(id)
	return str(a.get("kind", "")) if not a.is_empty() else ""


## The seconds before an ability can be used again, 0 for an unknown id.
static func cooldown_of(id: String) -> float:
	var a := ability(id)
	return float(a.get("cooldown", 0.0)) if not a.is_empty() else 0.0


## The mana an ability spends, 0 for an unknown id.
static func cost_of(id: String) -> int:
	var a := ability(id)
	return int(a.get("cost", 0)) if not a.is_empty() else 0


# --- Scaling -----------------------------------------------------------------

## The trained skill an ability scales with, or "" for an unknown id.
static func scale_skill(id: String) -> String:
	var a := ability(id)
	if a.is_empty():
		return ""
	var s: Dictionary = a.get("scale", {})
	return str(s.get("skill", ""))


## The level a skill starts at: 1 for every skill but Hitpoints, which starts
## at 10 (GearDB.START_LEVEL). A fresh hero has a delta of zero, so its
## abilities do exactly their base power until they are trained.
static func skill_baseline(skill: String) -> int:
	return int(GearDB.START_LEVEL.get(skill, 1))


## The ability's power at a given level of the skill it scales with. The
## level is the trained level of that skill: the ability is worth its base
## power plus per_level for every level above the skill's baseline, capped.
static func scaled_power(id: String, skill_level: int) -> float:
	var a := ability(id)
	if a.is_empty():
		return 0.0
	var base := float(a.get("power", 0.0))
	var s: Dictionary = a.get("scale", {})
	if s.is_empty():
		return base
	var per := float(s.get("per_level", 0.0))
	var cap := float(s.get("cap", INF))
	var delta := maxf(0.0, float(skill_level - skill_baseline(str(s.get("skill", "")))))
	return minf(cap, base + per * delta)


## The trained level of the skill an ability scales with, for a hero. 0 for an
## unknown id or an ability with no scale.
static func trained_level(hero: String, id: String) -> int:
	var skill := scale_skill(id)
	if skill == "":
		return 0
	return GearDB.level(hero, skill)


## The ability's power for a hero, at that hero's trained level.
static func scaled_power_for(hero: String, id: String) -> float:
	return scaled_power(id, trained_level(hero, id))


# --- Checks ------------------------------------------------------------------

## Everything wrong with the tables, as readable lines. Empty means the data
## is sound; the sim phase calls this so a typo in a row fails loudly.
static func validate() -> Array[String]:
	var problems: Array[String] = []
	for entry in CLASSES:
		var c: Dictionary = CLASSES[entry]
		if not c.has("name") or not c.has("role") or not c.has("abilities"):
			problems.append("class %s is missing name, role or abilities" % str(entry))
		var ids: Array = c.get("abilities", [])
		if ids.is_empty():
			problems.append("class %s owns no ability" % str(entry))
		for id in ids:
			if not has_ability(str(id)):
				problems.append("class %s lists unknown ability %s" % [str(entry), str(id)])
	for entry in ABILITIES:
		var a: Dictionary = entry
		var id := str(a.get("id", ""))
		if id == "":
			problems.append("an ability has no id")
			continue
		if not CLASSES.has(str(a.get("class", ""))):
			problems.append("ability %s belongs to no known class" % id)
		if not (str(a.get("kind", "")) in KINDS):
			problems.append("ability %s has unknown kind %s" % [id, str(a.get("kind", ""))])
		if not (str(a.get("targets", "")) in ["foes", "party", "self"]):
			problems.append("ability %s has unknown targets %s" % [id, str(a.get("targets", ""))])
		var skill := ""
		var sc: Dictionary = a.get("scale", {})
		skill = str(sc.get("skill", ""))
		if not (skill in GearDB.SKILL_KEYS):
			problems.append("ability %s scales with unknown skill %s" % [id, skill])
		if float(a.get("cooldown", 0.0)) <= 0.0:
			problems.append("ability %s has no cooldown" % id)
		if int(a.get("cost", 0)) <= 0:
			problems.append("ability %s costs nothing" % id)
	return problems
