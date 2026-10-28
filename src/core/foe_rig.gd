extends RefCounted
## Foes and bosses that are not KayKit Rig_Medium skeletons.
##
## A model spec is a string on `def["model"]`:
##   "skeleton_warrior"   a KayKit character (the original path, handled by KK).
##   "glb:wolf"           any rigged scene with its own AnimationPlayer: the
##                        wrapped `assets/foes/wolf.tscn` (1 m tall, feet at 0,
##                        posed `cull_aabbs`: tools/art/wrap_sidekicks.gd) or a
##                        bare `assets/foes/wolf.glb`.
##   "proc:shard"         a static mesh (`assets/foes/shard.tscn|glb`) moved by
##                        clips generated here (hover, orbit, lunge, collapse).
## Other def keys that go with it: "fit" (height in metres at scale 1.0,
## default 1.9 like a KayKit skeleton), "clips" (class -> clip name or list of
## names), "alias" (exact KayKit clip name -> clip name), "proc" (tuning for
## generated clips), "rim" (0 by default: art lock).
##
## The combat code keeps asking for KayKit clip names ("Skeletons_Walking",
## "Melee_2H_Attack_Chop"...). `resolve()` maps each to a clip the rig has, so
## no foe or boss script needs to know which rig it drives.

const DIR := "res://assets/foes/"
const FOE_SHADER := preload("res://src/fx/foe.gdshader")

const CLASSES := ["idle", "walk", "run", "attack", "cast", "taunt", "hit", "spawn", "die"]
## First match wins, so "Ranged_1H_Aiming" (a stance) comes before "Ranged".
const KK_RULES := [
	["Awaken", "spawn"], ["Spawn", "spawn"], ["Death", "die"], ["Taunt", "taunt"],
	["Hit_", "hit"], ["Idle", "idle"], ["Aiming", "idle"], ["Walking", "walk"],
	["Running", "run"], ["Magic", "cast"], ["Ranged", "cast"], ["Attack", "attack"],
	["Throw", "attack"], ["Interact", "cast"], ["Use_Item", "cast"], ["Block", "hit"],
]
## What stands in when a rig lacks a class.
const CHAIN := {
	"idle": ["idle", "walk"], "walk": ["walk", "run", "idle"], "run": ["run", "walk", "idle"],
	"attack": ["attack", "cast"], "cast": ["cast", "attack"], "taunt": ["taunt", "cast", "attack"],
	"hit": ["hit"], "spawn": ["spawn"], "die": ["die"],
}
## Words that identify a class inside a foreign clip name (lower case).
const WORDS := {
	"die": ["death", "die", "dead"], "hit": ["hitreact", "hit", "hurt", "damage", "flinch"],
	"spawn": ["spawn", "appear", "emerge", "wake", "rise"], "taunt": ["taunt", "roar", "emote", "scream", "dance"],
	"cast": ["cast", "spell", "summon", "magic"], "attack": ["attack", "bite", "punch", "slash", "swipe", "smash", "claw", "slam", "sting", "headbutt", "butt"],
	"run": ["run", "sprint", "gallop", "fast"], "walk": ["walk", "swim", "crawl", "fly", "hover", "move"],
	"idle": ["idle", "stand", "breath"],
}


static func is_foreign(model_name: String) -> bool:
	return model_name.begins_with("glb:") or model_name.begins_with("proc:")


static func scene_path(id: String) -> String:
	if id.contains("://"):
		return id
	for ext in [".tscn", ".glb"]:
		if ResourceLoader.exists(DIR + id + ext):
			return DIR + id + ext
	return ""


## Builds {"root": Node3D, "anim": AnimationPlayer}. The root holds a "Rig"
## node (the fitted model) and an AnimationPlayer named "Anim". Never null: a
## missing asset stands in a plain capsule so a bad spec cannot crash a hunt.
static func build(spec: String, def: Dictionary) -> Dictionary:
	var proc := spec.begins_with("proc:")
	var id := spec.substr(spec.find(":") + 1)
	var root := Node3D.new()
	root.name = "FoeModel"
	var path := scene_path(id)
	var rig := Node3D.new()
	rig.name = "Body" if proc else "Rig"
	root.add_child(rig)
	var inst: Node3D
	if path == "":
		push_warning("foe model missing: %s" % spec)
		inst = _stand_in()
	else:
		inst = (load(path) as PackedScene).instantiate()
	var fit := float(def.get("fit", 1.9))
	rig.add_child(inst)
	if inst.has_meta("posed_aabb"):
		# Wrapped: already 1 m tall, feet at 0, with posed culling bounds.
		inst.scale = Vector3.ONE * fit
		var culls: Dictionary = inst.get_meta("cull_aabbs", {})
		var inner := inst.get_child(0) if inst.get_child_count() > 0 else null
		for mp: String in culls:
			var mi := inner.get_node_or_null(mp) as MeshInstance3D if inner else null
			if mi:
				mi.custom_aabb = culls[mp]
	else:
		_fit(inst, fit)
	var ap: AnimationPlayer = inst.find_child("AnimationPlayer", true, false)
	if ap == null or proc:
		if ap:
			ap.get_parent().remove_child(ap)
			ap.free()
		ap = AnimationPlayer.new()
		ap.name = "Anim"
		root.add_child(ap)
		ap.add_animation_library("", _proc_library(root, rig, def.get("proc", {})))
	else:
		# Its own player and clips: tracks are relative to the player's root, so leave them be.
		_loop_locomotion(ap, def)
		_fill_missing(ap, rig, def)
	return {"root": root, "anim": ap}


static func _stand_in() -> Node3D:
	var mi := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = 0.35
	cm.height = 1.0
	mi.mesh = cm
	mi.position.y = 0.5
	var n := Node3D.new()
	n.add_child(mi)
	return n


## Scales `model` so its rest-pose height is `h` metres, feet on the ground
## (bare glb imports; wrapped scenes are fitted already).
static func _fit(model: Node3D, h: float) -> void:
	var box := AABB()
	var first := true
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		var xf := Transform3D.IDENTITY
		var n: Node = m
		while n != null and n != model:
			if n is Node3D:
				xf = (n as Node3D).transform * xf
			n = n.get_parent()
		var b := xf * m.mesh.get_aabb()
		box = b if first else box.merge(b)
		first = false
	if first or box.size.y <= 0.001:
		return
	var k := h / box.size.y
	model.scale = Vector3.ONE * k
	model.position.y = -box.position.y * k


static func _loop_locomotion(ap: AnimationPlayer, def: Dictionary) -> void:
	for c in ["idle", "walk", "run"]:
		var n := resolve_class(ap, c, def)
		if n != "":
			ap.get_animation(n).loop_mode = Animation.LOOP_LINEAR


## A clip of `ap` whose name ends with `want` ("Armature|Idle" matches "Idle").
static func find_clip(ap: AnimationPlayer, want: String) -> String:
	if ap.has_animation(want):
		return want
	for n: String in ap.get_animation_list():
		if n.ends_with("|" + want) or n.ends_with("/" + want):
			return n
	return ""


## The class of a KayKit clip name ("Melee_2H_Attack_Chop" -> "attack").
static func class_of(kk_clip: String) -> String:
	for r in KK_RULES:
		if kk_clip.contains(str(r[0])):
			return str(r[1])
	return ""


## The rig's clip for a class, from def["clips"] first, then by looking at
## the clip names. "" when the rig has nothing close.
static func resolve_class(ap: AnimationPlayer, cls: String, def: Dictionary, chain := true) -> String:
	var clips: Dictionary = def.get("clips", {})
	for c: String in (CHAIN.get(cls, [cls]) if chain else [cls]):
		if clips.has(c):
			var want = clips[c]
			for w in (want if want is Array else [want]):
				var n := find_clip(ap, str(w))
				if n != "":
					return n
		for n: String in ap.get_animation_list():
			var low := n.get_slice("|", n.get_slice_count("|") - 1).to_lower()
			for w: String in WORDS.get(c, []):
				if low.contains(w):
					if c == "walk" and (low.contains("run") or low.contains("fast") or low.contains("idle")):
						continue
					return n
	return ""


## The clip to play for a combat-code clip name: an exact alias, the clip
## itself (a KayKit rig), or the class it belongs to. "" when none fits.
static func resolve(ap: AnimationPlayer, name_: String, def: Dictionary, cache: Dictionary) -> String:
	if cache.has(name_):
		return cache[name_]
	var out := ""
	var alias: Dictionary = def.get("alias", {})
	if alias.has(name_):
		out = find_clip(ap, str(alias[name_]))
	if out == "":
		out = find_clip(ap, name_)
	if out == "":
		var cls := class_of(name_)
		if cls != "":
			out = resolve_class(ap, cls, def)
	cache[name_] = out
	return out


## A rig with its own clips that lacks a class (a single-clip Sketchfab creature has no hit, no
## death, no strike) gets the generated clip of that class, named "gen_<class>", moving the "Rig"
## node (the fitted model sits one level below, so its own scale is kept). def["clips"] can point a
## class at the rig's clip; def["gen"] (an Array of classes) forces a generated clip even where the
## FoeRig.CHAIN would stand in another clip (a caster that has an attack but no cast). A generated
## clip moves only the node, so the skeleton keeps the pose of the clip that played before it.
static func _fill_missing(ap: AnimationPlayer, rig: Node3D, def: Dictionary) -> void:
	var base := ap.get_node_or_null(ap.root_node)
	if base == null:
		return
	var lib: AnimationLibrary
	var forced: Array = def.get("gen", [])
	for cls: String in CLASSES:
		if resolve_class(ap, cls, def) != "" and not forced.has(cls):
			continue
		if lib == null:
			lib = _proc_library(base, rig, def.get("proc", {}), true)
		var gen := lib.get_animation(cls).duplicate() as Animation
		var lib_name := ""
		if not ap.has_animation_library(lib_name):
			ap.add_animation_library(lib_name, AnimationLibrary.new())
		ap.get_animation_library(lib_name).add_animation("gen_" + cls, gen)


# -- generated clips for proc rigs ---------------------------------------------


## Tuning in def["proc"]: "hover" (idle height, m), "bob" (bob height), "rate"
## (bobs per second), "lean" (run tilt, rad), "spin" (turns per idle loop of
## children named Orbit*), "lunge" (attack reach, m).
static func _proc_library(root: Node, body: Node3D, tune: Dictionary, fitted := false) -> AnimationLibrary:
	var lib := AnimationLibrary.new()
	var hover := float(tune.get("hover", 0.0))
	var bob := float(tune.get("bob", 0.06))
	var rate := float(tune.get("rate", 0.6))
	var lean := float(tune.get("lean", 0.18))
	var lunge := float(tune.get("lunge", 0.7))
	var orbits: Array[NodePath] = []
	for n in body.find_children("Orbit*", "Node3D", true, false):
		orbits.append(root.get_path_to(n))
	if fitted:
		orbits.clear()
	var bp := root.get_path_to(body)
	var idle_len := 1.0 / maxf(rate, 0.1)
	# Idle and walk: a bob (and, when hovering, a slow drift), orbits turn once a loop.
	lib.add_animation("idle", _loop(bp, orbits, idle_len, hover, bob, 0.0, 0.0, 1.0))
	lib.add_animation("walk", _loop(bp, orbits, idle_len * 0.7, hover, bob * 1.5, lean * 0.5, 0.05, 1.0))
	lib.add_animation("run", _loop(bp, orbits, idle_len * 0.45, hover, bob * 2.0, lean, 0.08, 2.0))
	lib.add_animation("attack", _once(bp, 0.55, [
		[0.0, Vector3(0, hover, 0), Vector3.ZERO, Vector3.ONE],
		[0.18, Vector3(0, hover + 0.1, -0.35), Vector3(-0.25, 0, 0), Vector3(1.05, 0.92, 0.9)],
		[0.3, Vector3(0, hover, lunge), Vector3(0.35, 0, 0), Vector3(0.92, 1.0, 1.18)],
		[0.55, Vector3(0, hover, 0), Vector3.ZERO, Vector3.ONE]]))
	lib.add_animation("cast", _once(bp, 0.9, [
		[0.0, Vector3(0, hover, 0), Vector3.ZERO, Vector3.ONE],
		[0.4, Vector3(0, hover + 0.55, 0), Vector3(-0.2, 0, 0), Vector3(0.94, 1.12, 0.94)],
		[0.65, Vector3(0, hover + 0.45, 0.1), Vector3(0.1, 0, 0), Vector3(1.06, 0.94, 1.06)],
		[0.9, Vector3(0, hover, 0), Vector3.ZERO, Vector3.ONE]]))
	lib.add_animation("taunt", _once(bp, 1.2, [
		[0.0, Vector3(0, hover, 0), Vector3.ZERO, Vector3.ONE],
		[0.35, Vector3(0, hover + 0.35, -0.1), Vector3(-0.3, 0, 0), Vector3(0.95, 1.1, 0.95)],
		[0.6, Vector3(0, hover + 0.3, -0.1), Vector3(-0.3, 0.2, 0), Vector3(0.95, 1.1, 0.95)],
		[0.85, Vector3(0, hover + 0.3, -0.1), Vector3(-0.3, -0.2, 0), Vector3(0.95, 1.1, 0.95)],
		[1.2, Vector3(0, hover, 0), Vector3.ZERO, Vector3.ONE]]))
	lib.add_animation("hit", _once(bp, 0.28, [
		[0.0, Vector3(0, hover, 0), Vector3.ZERO, Vector3.ONE],
		[0.08, Vector3(0, hover, -0.25), Vector3(-0.3, 0, 0.1), Vector3(1.06, 0.92, 1.06)],
		[0.28, Vector3(0, hover, 0), Vector3.ZERO, Vector3.ONE]]))
	lib.add_animation("spawn", _once(bp, 0.9, [
		[0.0, Vector3(0, hover - 0.4, 0), Vector3.ZERO, Vector3(0.2, 0.2, 0.2)],
		[0.55, Vector3(0, hover + 0.15, 0), Vector3.ZERO, Vector3(1.1, 1.1, 1.1)],
		[0.9, Vector3(0, hover, 0), Vector3.ZERO, Vector3.ONE]]))
	lib.add_animation("die", _once(bp, 0.8, [
		[0.0, Vector3(0, hover, 0), Vector3.ZERO, Vector3.ONE],
		[0.3, Vector3(0, hover + 0.1, 0), Vector3(-0.4, 0, 0.2), Vector3(1.08, 0.9, 1.08)],
		[0.8, Vector3(0, -0.1, 0), Vector3(-1.2, 0, 0.5), Vector3(0.7, 0.2, 0.7)]]))
	return lib


static func _track(a: Animation, path: String, times: Array, vals: Array) -> void:
	var t := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(t, path)
	a.track_set_interpolation_type(t, Animation.INTERPOLATION_CUBIC if times.size() > 3 else Animation.INTERPOLATION_LINEAR)
	for i in times.size():
		a.track_insert_key(t, times[i], vals[i])


static func _loop(bp: NodePath, orbits: Array[NodePath], len_: float, hover: float, bob: float, lean: float, sway: float, orbit_turns: float) -> Animation:
	var a := Animation.new()
	a.length = len_
	a.loop_mode = Animation.LOOP_LINEAR
	var ts := [0.0, len_ * 0.25, len_ * 0.5, len_ * 0.75, len_]
	_track(a, "%s:position" % bp, ts, [Vector3(0, hover, 0), Vector3(0, hover + bob, 0), Vector3(0, hover, 0), Vector3(0, hover + bob * 0.4, 0), Vector3(0, hover, 0)])
	_track(a, "%s:rotation" % bp, ts, [Vector3(lean, 0, 0), Vector3(lean, 0, sway), Vector3(lean, 0, 0), Vector3(lean, 0, -sway), Vector3(lean, 0, 0)])
	for o in orbits:
		_track(a, "%s:rotation" % o, [0.0, len_ * 0.5, len_], [Vector3.ZERO, Vector3(0, PI * orbit_turns, 0), Vector3(0, TAU * orbit_turns, 0)])
	return a


## `keys`: [time, position, rotation, scale].
static func _once(bp: NodePath, len_: float, keys: Array) -> Animation:
	var a := Animation.new()
	a.length = len_
	var ts := []
	for k in keys:
		ts.append(float(k[0]))
	_track(a, "%s:position" % bp, ts, keys.map(func(k): return k[1]))
	_track(a, "%s:rotation" % bp, ts, keys.map(func(k): return k[2]))
	_track(a, "%s:scale" % bp, ts, keys.map(func(k): return k[3]))
	return a


## One material per source material, shared by every foe of that look: the
## model's own PBR in foe.gdshader (with the per-instance flash and tint).
static var _mats := {}
static var _two_sided: Shader


static func lit(src: Material, rim: Color, rim_strength: float) -> Material:
	var b := src as BaseMaterial3D
	if b == null:
		return null
	if b.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
		return null
	var key := "%s|%s|%.2f" % [b.resource_path if b.resource_path != "" else str(b.get_instance_id()), rim.to_html(), rim_strength]
	if _mats.has(key):
		return _mats[key]
	var m := ShaderMaterial.new()
	m.shader = FOE_SHADER
	if b.cull_mode == BaseMaterial3D.CULL_DISABLED:
		if _two_sided == null:
			_two_sided = Shader.new()
			_two_sided.code = FOE_SHADER.code.replace("cull_back", "cull_disabled")
		m.shader = _two_sided
	m.set_shader_parameter("albedo", b.albedo_color)
	if b.albedo_texture:
		m.set_shader_parameter("albedo_tex", b.albedo_texture)
		m.set_shader_parameter("use_tex", true)
	m.set_shader_parameter("use_vcol", b.vertex_color_use_as_albedo)
	if b.normal_enabled and b.normal_texture:
		m.set_shader_parameter("normal_tex", b.normal_texture)
		m.set_shader_parameter("use_normal", true)
		m.set_shader_parameter("normal_scale", b.normal_scale)
	m.set_shader_parameter("roughness", b.roughness)
	m.set_shader_parameter("metallic", b.metallic)
	var mr := b.roughness_texture if b.roughness_texture else b.metallic_texture
	if mr:
		m.set_shader_parameter("mr_tex", mr)
		m.set_shader_parameter("use_mr", true)
	if b.emission_enabled:
		m.set_shader_parameter("emission_color", b.emission)
		m.set_shader_parameter("emission_energy", b.emission_energy_multiplier)
		if b.emission_texture:
			m.set_shader_parameter("emission_tex", b.emission_texture)
			m.set_shader_parameter("use_emission_tex", true)
	m.set_shader_parameter("rim_color", rim)
	m.set_shader_parameter("rim_strength", rim_strength)
	_mats[key] = m
	return m
