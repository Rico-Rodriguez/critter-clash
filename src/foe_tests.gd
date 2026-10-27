extends RefCounted
## Every foe def, every zone: the six animation states the game plays (idle,
## run, attack, hit, die, spawn) resolve to real clips on the foe's own model,
## the model and weapons load, and the stats are sane. `Actor.play` silently
## ignores a clip it cannot find, so a typo in db.gd shows up as a foe frozen in
## its T-pose; this is the only place that catches it.

const STATES := ["idle", "run", "attack", "hit", "die", "spawn"]
const AIS := ["melee", "ranged", "caster", "bomb", "necro", "charge", "slam", "flee"]
const NUMS := ["hp", "dmg", "speed", "radius", "reach", "windup", "cooldown", "mass", "xp", "scale"]


static func run(ok: Callable) -> void:
	_defs(ok)
	_zones(ok)


## The clips a def's model offers: the shared Rig_Medium library for KayKit
## characters, the glb's own AnimationPlayer for a foreign rig (`glb` key).
static func clips(def: Dictionary) -> PackedStringArray:
	if def.has("glb"):
		var root: Node = load(str(def["glb"])).instantiate()
		var out := PackedStringArray()
		for ap: AnimationPlayer in root.find_children("*", "AnimationPlayer", true, false):
			out.append_array(ap.get_animation_list())
		root.free()
		return out
	return KK.lib().get_animation_list()


static func _defs(ok: Callable) -> void:
	var kinds: Array = DB.enemy_kinds()
	ok.call("foes: %d foe defs to check" % kinds.size(), kinds.size() >= 20)
	var bad_anim := []
	var bad_model := []
	var bad_stat := []
	var bad_ai := []
	var models := {}
	for k: String in kinds:
		var d: Dictionary = DB.enemy(k)
		var offered := clips(d)
		var a: Dictionary = d["anim"]
		for s in STATES:
			if not a.has(s) or not offered.has(str(a[s])):
				bad_anim.append("%s.%s" % [k, s])
		var path := str(d["glb"]) if d.has("glb") else KK.CHAR_DIR + str(d["model"]) + ".glb"
		if not models.has(path):
			models[path] = ResourceLoader.exists(path)
		if not models[path]:
			bad_model.append(k)
		for slot: String in d.get("weapons", {}):
			var wp := str(d["weapons"][slot])
			if not ResourceLoader.exists(wp if wp.begins_with("res://") else KK.WEAPON_DIR + wp):
				bad_model.append("%s:%s" % [k, wp])
		for n in NUMS:
			if not d.has(n) or float(d[n]) < 0.0:
				bad_stat.append("%s.%s" % [k, n])
		if not str(d["ai"]) in AIS:
			bad_ai.append(k)
	ok.call("foes: every def has idle, run, attack, hit, die and spawn clips on its model %s" % str(bad_anim), bad_anim.is_empty())
	ok.call("foes: every model and weapon file loads %s" % str(bad_model), bad_model.is_empty())
	ok.call("foes: every def has its stats %s" % str(bad_stat), bad_stat.is_empty())
	ok.call("foes: every def names an AI the enemy knows %s" % str(bad_ai), bad_ai.is_empty())


static func _zones(ok: Callable) -> void:
	var slots := ["minion", "warrior", "rogue", "mage", "necro", "hound", "brute", "bomber"]
	for id: String in DB.ZONE_ORDER:
		var f: Dictionary = DB.ZONES[id].get("faction", {})
		var bad := f.keys().filter(func(slot): return not slot in slots or not (DB.ENEMIES.has(f[slot]) or DB.ENEMIES_EXTRA.has(f[slot])))
		ok.call("zone %s: faction slots are director classes with real foes %s" % [id, str(bad)], bad.is_empty())
