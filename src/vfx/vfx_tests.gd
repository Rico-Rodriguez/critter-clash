extends RefCounted
## VFX library checks, called from tests.gd: every element has every
## variant in every tier, the batched layers are reused rather than grown,
## caps hold under spam, tiers stay apart, and no legacy ring / circle /
## glow helper survives anywhere in the game.

const VfxLib := preload("res://src/vfx/vfx_lib.gd")


static func run(ok: Callable) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var v: Node3D = VfxLib.new()
	tree.root.add_child(v)
	var at := Vector3(1, 0, 2)
	for el in VfxLib.ELEMENTS:
		for variant in VfxLib.VARIANTS:
			v.play(el, variant, at, 2.0, Vector3(0, 0, 1), 0.5)
	ok.call("vfx: %d elements x %d variants play" % [VfxLib.ELEMENTS.size(), VfxLib.VARIANTS.size()], VfxLib.ELEMENTS.size() >= 12 and VfxLib.VARIANTS.size() == 5)
	var missing := []
	for el in VfxLib.ELEMENTS:
		for table in [VfxLib.COLORS, VfxLib.EDGES, VfxLib.RIM, VfxLib.DEBRIS]:
			if not table.has(el):
				missing.append(el)
	ok.call("vfx: every element has colour, rim, debris and telegraph edge %s" % [missing], missing.is_empty())
	for i in 60:
		v._process(0.1)
	var built: Dictionary = v.built.duplicate()
	for round_ in 3:
		for el in VfxLib.ELEMENTS:
			for variant in VfxLib.VARIANTS:
				v.play(el, variant, at, 2.0, Vector3(0, 0, 1), 0.5)
		for i in 60:
			v._process(0.1)
	ok.call("vfx: layers reused, not grown %s -> %s" % [built, v.built], v.built["layer"] == built["layer"] and v.built["strip"] == 1)
	ok.call("vfx: idle layers hidden (%d)" % v.active_layers(), v.active_layers() == 0)
	var shadow := []
	for p in v.find_children("*", "GeometryInstance3D", true, false):
		if (p as GeometryInstance3D).cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			shadow.append(p.name)
	ok.call("vfx: nothing casts shadows %s" % [shadow], shadow.is_empty())
	ok.call("vfx: no lights in the library", v.find_children("*", "Light3D", true, false).is_empty())
	var loose := 0
	for c in v.get_children():
		if c is MeshInstance3D and not (c.mesh is ImmediateMesh):
			loose += 1
	ok.call("vfx: every piece batched (%d loose meshes, %d layers)" % [loose, v._layers.size()], loose == 0 and v._layers.size() <= VfxLib.LAYERS.size())
	v.free()
	_tiers(ok, tree)
	_spam(ok, tree)
	_blocks(ok, tree)
	ok.call("vfx: element_for maps hues", VfxLib.element_for(Color(1.0, 0.45, 0.1)) == &"fire" and VfxLib.element_for(Color(0.55, 0.9, 1.0)) in [&"frost", &"storm"] and VfxLib.element_for(Color(0.7, 0.3, 1.0)) == &"shadow")
	_legacy(ok)


## Counts what a tier produces for every element x variant.
static func _measure(tree: SceneTree, tier: StringName) -> Dictionary:
	var v: Node3D = VfxLib.new()
	tree.root.add_child(v)
	var shakes := [0.0]
	var freezes := [0]
	v.on_shake = func(a: float): shakes[0] = maxf(shakes[0], a)
	v.on_freeze = func(_t: float): freezes[0] += 1
	var st := {"decal": 0, "shock": 0, "bolt": 0, "sky": 0, "toon": 0, "chunk": 0, "star": 0}
	for el in VfxLib.ELEMENTS:
		for variant in [&"cast", &"travel", &"impact", &"nova"]:
			v.play(el, variant, Vector3.ZERO, 2.0, Vector3(0, 0, 1), 0.4, VfxLib.NO_TINT, tier)
		for i in 12:
			v._process(1.0 / 30.0)
			var bolts := 0
			for s in v._strips:
				if s["kind"] == "bolt":
					bolts += 1
					if s.get("sky", false):
						st["sky"] += 1
			st["bolt"] = maxi(st["bolt"], bolts)
			for n in ["toon", "chunk", "star"]:
				if v._layers.has(n):
					st[n] = maxi(st[n], int(v._layers[n]["alive"]))
		if v._layers.has("ground"):
			var L: Dictionary = v._layers["ground"]
			for i in int(L["top"]):
				if L["age"][i] < L["life"][i]:
					if int(L["prm"][i]) == 1: st["decal"] += 1
					if int(L["prm"][i]) == 0: st["shock"] += 1
		for i in 60:
			v._process(0.1)
	st["shake"] = shakes[0]
	st["freeze"] = freezes[0]
	v.free()
	return st


## Tiers: light is quick and quiet (no ground mark, no shockwave ring, no
## sky strike, no shake/freeze, one bolt at most); big outdoes skill.
static func _tiers(ok: Callable, tree: SceneTree) -> void:
	ok.call("vfx: three tiers", VfxLib.TIERS == [&"light", &"skill", &"big"] and VfxLib.TIER.size() == 3)
	var S := {}
	for tier in VfxLib.TIERS:
		S[tier] = _measure(tree, tier)
	var L: Dictionary = S[&"light"]
	ok.call("vfx: light tier leaves no ground mark %s" % [L], int(L["decal"]) == 0)
	ok.call("vfx: light tier has no sky strike", int(L["sky"]) == 0)
	ok.call("vfx: light tier at most one bolt", int(L["bolt"]) <= 1)
	ok.call("vfx: light tier has no shockwave ring", int(L["shock"]) == 0)
	ok.call("vfx: light tier no shake, no freeze", float(L["shake"]) == 0.0 and int(L["freeze"]) == 0)
	ok.call("vfx: light tier still pops (stars and puffs)", int(L["star"]) > 0 and int(L["toon"]) > 0)
	ok.call("vfx: big has sky strikes, skill none %s" % [S], int(S[&"big"]["sky"]) > 0 and int(S[&"skill"]["sky"]) == 0)
	ok.call("vfx: skill throws debris and marks the ground", int(S[&"skill"]["chunk"]) > 0 and int(S[&"skill"]["decal"]) > 0)
	ok.call("vfx: big is louder than skill", int(S[&"big"]["toon"]) > int(S[&"skill"]["toon"]) and int(S[&"big"]["chunk"]) >= int(S[&"skill"]["chunk"]) and float(S[&"big"]["shake"]) > float(S[&"skill"]["shake"]))
	ok.call("vfx: only big freezes", int(S[&"big"]["freeze"]) > 0 and int(S[&"skill"]["freeze"]) == 0)
	# Every call site names its tier.
	var untiered := []
	_scan_tiers("res://src", untiered)
	ok.call("vfx: every call site names a tier %s" % [untiered], untiered.is_empty())
	for site in TIER_MAP:
		var f: String = site.split(":")[0]
		var src := FileAccess.get_file_as_string("res://src/hunt/" + f)
		var want: String = TIER_MAP[site]
		ok.call("vfx: tier map %s -> %s" % [site, want], src.contains(site.split(":")[1]) and _tier_of(src, site.split(":")[1]) == want)


## 300 big impacts in a second stay inside every cap.
static func _spam(ok: Callable, tree: SceneTree) -> void:
	var s: Node3D = VfxLib.new()
	tree.root.add_child(s)
	var max_bolts := 0
	var max_sky := 0
	var max_marks := 0
	for i in 300:
		s.play([&"storm", &"frost", &"holy", &"fire"][i % 4], &"impact", Vector3(i % 10, 0, 0), 2.0, Vector3.ZERO, -1.0, VfxLib.NO_TINT, &"big")
		s._process(1.0 / 300.0)
		var b := 0
		var sk := 0
		for e in s._strips:
			if e["kind"] == "bolt":
				b += 1
				if e.get("sky", false): sk += 1
		max_bolts = maxi(max_bolts, b)
		max_sky = maxi(max_sky, sk)
		var L: Dictionary = s._layers["ground"]
		var m := 0
		for j in int(L["top"]):
			if L["age"][j] < L["life"][j] and int(L["prm"][j]) == 1:
				m += 1
		max_marks = maxi(max_marks, m)
	ok.call("vfx: bolts capped under spam (%d)" % max_bolts, max_bolts <= VfxLib.BOLT_POOL)
	ok.call("vfx: sky strikes capped (%d)" % max_sky, max_sky <= VfxLib.MAX_SKY)
	ok.call("vfx: ground marks capped (%d)" % max_marks, max_marks <= VfxLib.MAX_DECALS)
	var over := []
	for n in s._layers:
		if int(s._layers[n]["alive"]) > int(s._layers[n]["cap"]):
			over.append(n)
	ok.call("vfx: layers capped %s" % [over], over.is_empty())
	for i in 10:
		s.spray(&"fire", Vector3.ZERO, Vector3(1, 0, 0), 4.0, 0.5, 0.5)
	var sprays := 0
	for e in s._live:
		if e["kind"] == "spray": sprays += 1
	ok.call("vfx: sprays capped (%d)" % sprays, sprays <= VfxLib.MAX_SPRAYS and sprays > 0)
	s.free()


## The building blocks: puffs pop with overshoot then erode with a hard
## edge, no two puffs in a burst are the same size (no stamps), stars
## hollow out, sparks fall.
static func _blocks(ok: Callable, tree: SceneTree) -> void:
	var v: Node3D = VfxLib.new()
	tree.root.add_child(v)
	v.impact(&"fire", Vector3.ZERO, 1.5, VfxLib.NO_TINT, &"skill")
	var L: Dictionary = v._layers["toon"]
	var sizes := {}
	for i in int(L["top"]):
		sizes[snappedf(L["size"][i], 0.001)] = true
	ok.call("vfx: impact puffs vary in size (%d distinct of %d)" % [sizes.size(), int(L["top"])], sizes.size() >= int(L["top"]) - 1 and int(L["top"]) >= 4)
	ok.call("vfx: overshoot pop", VfxLib.ease_pop(0.35) > 1.1 and absf(VfxLib.ease_pop(1.0) - 1.0) < 0.01)
	ok.call("vfx: puffs hold, then dissolve with an erode edge", VfxLib.erode_at(0.3) == 0.0 and VfxLib.erode_at(0.8) > 0.4 and VfxLib.erode_at(1.0) == 1.0)
	ok.call("vfx: toon layer uses the 3-band toon shader", ((L["node"] as MultiMeshInstance3D).material_override as ShaderMaterial).shader == VfxLib.TOON)
	v.free()


## The mapping the PR lists, spot-checked: file:unique snippet -> tier.
const TIER_MAP := {
	"proj.gd:h.fx.flame_burst(at, r": "light",
	"proj.gd:h.fx.vfx.travel(el": "light",
	"proj.gd:h.fx.vfx.impact(&\"shadow\", at, r": "light",
	"hero.gd:hunt.fx.vfx.nova(&\"physical\", at, r * 1.1": "light",
	"hero.gd:hunt.fx.lightning(pts, col": "light",
	"sidekick.gd:0.55 if not is_special() else 0.8": "light",
	"hero.gd:hunt.fx.vfx.nova(&\"frost\", at, radius": "skill",
	"hero.gd:hunt.fx.vfx.nova(&\"fire\", flat_pos(), 3.4": "big",
	"boss.gd:hunt.fx.vfx.nova(&\"fire\", flat_pos(), 6.0": "big",
	"hunt_combat.gd:fx.vfx.nova(&\"shadow\", at, 9.0": "big",
	"boss_thorn.gd:RING_REACH / RING_SPEED, Fx": "big",
}


static func _tier_of(src: String, snippet: String) -> String:
	var i := src.find(snippet)
	var line := src.substr(i, src.find("\n", i) - i)
	for t in ["light", "skill", "big"]:
		if line.contains("&\"%s\"" % t):
			return t
	return ""


const CALLS := ["vfx.cast(", "vfx.travel(", "vfx.impact(", "vfx.nova(", "vfx.linger(", "fx.flame_burst(", "fx.lightning("]


static func _scan_tiers(dir: String, out: Array) -> void:
	for f in DirAccess.get_files_at(dir):
		if not f.ends_with(".gd") or f in ["vfx_tests.gd", "vfx_lib.gd", "vfx_capture.gd"]:
			continue
		var lines := FileAccess.get_file_as_string(dir + "/" + f).split("\n")
		for i in lines.size():
			var l := lines[i].strip_edges()
			if l.begins_with("#") or l.begins_with("func ") or l.begins_with("##"):
				continue
			for c in CALLS:
				if l.contains(c) and not (l.contains("&\"light\"") or l.contains("&\"skill\"") or l.contains("&\"big\"") or l.contains(", tier)")):
					out.append("%s:%d" % [f, i + 1])
	for d in DirAccess.get_directories_at(dir):
		_scan_tiers(dir + "/" + d, out)


## Legacy helpers that drew decorative colored rings, abstract circles,
## additive glow shells or light flashes. None may come back: a ring now
## exists only as an impact's brief shockwave (vfx.shockwave, called by the
## lib itself) or as a telegraph (fx.telegraph / vfx.target).
const LEGACY := ["fx.ring(", "func ring(", "TorusMesh", "\"tongue\"", "flash_light(", "Fx.SLASH", "Fx.TORNADO",
	"slash.gdshader", "tornado.gdshader", "vfx_core.gdshader", "vfx_decal.gdshader", "vfx_puff.gdshader", "vfx_crystal.gdshader",
	"CompanionRing", "_add_ring(", "vfx._burst(", "vfx._cloud(", "vfx._emit("]
## Effect code (not world art) may not use additive blending or emission glow.
const GLOW := ["blend_add", "BLEND_MODE_ADD", "emission_enabled = true"]
const EFFECT_FILES := ["res://src/vfx/vfx_lib.gd", "res://src/hunt/fx.gd", "res://src/hunt/hunt_loot.gd", "res://src/hunt/proj.gd",
	"res://src/hunt/sidekick.gd", "res://src/hunt/boss.gd", "res://src/hunt/hero.gd", "res://src/hunt/enemy.gd"]


static func _legacy(ok: Callable) -> void:
	var hits := []
	_scan_legacy("res://src", hits)
	ok.call("vfx: no legacy ring / circle / glow helper call sites %s" % [hits], hits.is_empty())
	for gone in ["src/fx/ring", "src/fx/flame_ring", "src/fx/flame_wall", "src/fx/scorch", "src/fx/slash", "src/fx/tornado", "src/vfx/vfx_core", "src/vfx/vfx_decal"]:
		ok.call("vfx: %s.gdshader removed" % gone, not ResourceLoader.exists("res://%s.gdshader" % gone))
	var glow := []
	for f in EFFECT_FILES:
		var s := FileAccess.get_file_as_string(f)
		for g in GLOW:
			if s.contains(g):
				glow.append("%s:%s" % [f.get_file(), g])
	ok.call("vfx: effect code has no additive glow or emission %s" % [glow], glow.is_empty())


static func _scan_legacy(dir: String, out: Array) -> void:
	for f in DirAccess.get_files_at(dir):
		if not f.ends_with(".gd") or f in ["vfx_tests.gd", "tests.gd"]:
			continue
		var lines := FileAccess.get_file_as_string(dir + "/" + f).split("\n")
		for i in lines.size():
			for t in LEGACY:
				if lines[i].contains(t):
					out.append("%s:%d %s" % [f, i + 1, t])
	for d in DirAccess.get_directories_at(dir):
		_scan_legacy(dir + "/" + d, out)
