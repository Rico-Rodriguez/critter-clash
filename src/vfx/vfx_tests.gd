extends RefCounted
## VFX library checks, called from tests.gd: every element has every
## variant, pools are reused rather than grown, and no flat placeholder ring
## survives anywhere in the hunt.

const VfxLib := preload("res://src/vfx/vfx_lib.gd")


static func run(ok: Callable) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var v: Node3D = VfxLib.new()
	tree.root.add_child(v)
	var at := Vector3(1, 0, 2)
	for el in VfxLib.ELEMENTS:
		for variant in VfxLib.VARIANTS:
			v.play(el, variant, at, 2.0, Vector3(0, 0, 1), 0.5)
	ok.call("vfx: %d elements x %d variants play" % [VfxLib.ELEMENTS.size(), VfxLib.VARIANTS.size()], VfxLib.ELEMENTS.size() >= 12 and VfxLib.VARIANTS.size() >= 4)
	var missing := []
	for el in VfxLib.ELEMENTS:
		if not VfxLib.COLORS.has(el) or not VfxLib.EDGES.has(el):
			missing.append(el)
	ok.call("vfx: every element has a colour and a telegraph edge %s" % [missing], missing.is_empty())
	for i in 60:
		v._process(0.1)
	var built: Dictionary = v.built.duplicate()
	for round_ in 3:
		for el in VfxLib.ELEMENTS:
			for variant in VfxLib.VARIANTS:
				v.play(el, variant, at, 2.0, Vector3(0, 0, 1), 0.5)
		for i in 60:
			v._process(0.1)
	ok.call("vfx: pools reused, not grown %s -> %s" % [built, v.built], v.built == built)
	ok.call("vfx: decal pool capped", int(v.built["decal"]) <= VfxLib.MAX_DECALS)
	ok.call("vfx: bolt pool capped", int(v.built["bolt"]) <= VfxLib.BOLT_POOL)
	ok.call("vfx: idle layers hidden", v.active_layers() == 0)
	var shadow := []
	for p in v.find_children("*", "GeometryInstance3D", true, false):
		if (p as GeometryInstance3D).cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			shadow.append(p.name)
	ok.call("vfx: nothing casts shadows %s" % [shadow], shadow.is_empty())
	ok.call("vfx: no lights in the library", v.find_children("*", "Light3D", true, false).is_empty())
	v.free()
	_tiers(ok, tree)
	ok.call("vfx: element_for maps hues", VfxLib.element_for(Color(1.0, 0.45, 0.1)) == &"fire" and VfxLib.element_for(Color(0.55, 0.9, 1.0)) in [&"frost", &"storm"] and VfxLib.element_for(Color(0.7, 0.3, 1.0)) == &"shadow")
	# No placeholder ring art left: the flat ring shaders are gone and only the
	# shim in fx.gd (and sidekick.gd, owned by an open PR) still calls ring().
	for gone in ["ring", "flame_ring", "flame_wall", "scorch"]:
		ok.call("vfx: %s.gdshader removed" % gone, not ResourceLoader.exists("res://src/fx/%s.gdshader" % gone))
	var callers := []
	_scan("res://src", callers)
	ok.call("vfx: no fx.ring( call sites %s" % [callers], callers.is_empty())


static func _scan(dir: String, out: Array) -> void:
	for f in DirAccess.get_files_at(dir):
		if not f.ends_with(".gd") or f in ["fx.gd", "sidekick.gd", "vfx_tests.gd"]:
			continue
		var s := FileAccess.get_file_as_string(dir + "/" + f)
		if s.contains("fx.ring("):
			out.append(f)
	for d in DirAccess.get_directories_at(dir):
		_scan(dir + "/" + d, out)


## Tiers: light is quiet (no ground mark, no sky strike, no shatter, one
## bolt at most), big is louder than skill, and every cap holds under spam.
static func _tiers(ok: Callable, tree: SceneTree) -> void:
	ok.call("vfx: three tiers", VfxLib.TIERS == [&"light", &"skill", &"big"] and VfxLib.TIER.size() == 3)
	var cores := []
	for el in VfxLib.ELEMENTS:
		if not VfxLib.STYLE.has(el):
			cores.append(el)
	ok.call("vfx: every element has a procedural core %s" % [cores], cores.is_empty())
	var at := Vector3(0, 0, 0)
	var stats := {}
	for tier in VfxLib.TIERS:
		var v: Node3D = VfxLib.new()
		tree.root.add_child(v)
		var decals := 0
		var bolts := 0
		var sky := 0
		var chips := 0
		var cores_n := 0
		for el in VfxLib.ELEMENTS:
			for variant in [&"cast", &"travel", &"impact", &"nova"]:
				v.play(el, variant, at, 2.0, Vector3(0, 0, 1), 0.4, VfxLib.NO_TINT, tier)
			for i in 12:
				v._process(1.0 / 30.0)
				for e in v._live:
					if e["kind"] == "decal": decals += 1
					if e["kind"] == "bolt": bolts = maxi(bolts, v._bolts_live())
					if e["kind"] == "bolt" and e.get("sky", false): sky += 1
			for n in ["ball", "tongue", "spike"]:
				if v._layers.has(n):
					cores_n += int(v._layers[n]["alive"])
			if v._layers.has("chip"):
				chips += int(v._layers["chip"]["alive"])
		for i in 60:
			v._process(0.1)
		stats[tier] = {"decals": decals, "bolts": bolts, "sky": sky, "chips": chips, "cores": cores_n}
		v.free()
	var L: Dictionary = stats[&"light"]
	ok.call("vfx: light tier leaves no ground mark %s" % [L], int(L["decals"]) == 0)
	ok.call("vfx: light tier has no sky strike or shatter", int(L["sky"]) == 0 and int(L["chips"]) == 0)
	ok.call("vfx: light tier at most one bolt", int(L["bolts"]) <= 1)
	ok.call("vfx: light tier still draws a core", int(L["cores"]) > 0)
	ok.call("vfx: big has sky strikes, skill none %s" % [stats], int(stats[&"big"]["sky"]) > 0 and int(stats[&"skill"]["sky"]) == 0)
	ok.call("vfx: skill shatters crystals", int(stats[&"skill"]["chips"]) > 0)
	ok.call("vfx: big marks more ground than skill", int(stats[&"big"]["decals"]) >= int(stats[&"skill"]["decals"]))
	# Spam: 300 big storm/frost impacts in one second stay inside every cap.
	var s: Node3D = VfxLib.new()
	tree.root.add_child(s)
	for i in 300:
		s.play([&"storm", &"frost", &"holy"][i % 3], &"impact", Vector3(i % 10, 0, 0), 2.0, Vector3.ZERO, -1.0, VfxLib.NO_TINT, &"big")
		s._process(1.0 / 300.0)
	var skies := 0
	for e in s._live:
		if e["kind"] == "bolt" and e.get("sky", false):
			skies += 1
	ok.call("vfx: bolts capped under spam", int(s.built["bolt"]) <= VfxLib.BOLT_POOL)
	ok.call("vfx: sky strikes capped (%d)" % skies, skies <= VfxLib.MAX_SKY)
	ok.call("vfx: ground marks capped", int(s.built["decal"]) <= VfxLib.MAX_DECALS)
	var over := []
	for n in s._layers:
		if int(s._layers[n]["alive"]) > int(VfxLib.LAYERS[n]["amount"]):
			over.append(n)
	ok.call("vfx: core layers capped %s" % [over], over.is_empty())
	# Crystals and shards are batched: one MultiMesh each, never loose meshes.
	var loose := 0
	for c in s.get_children():
		if c is MeshInstance3D and not (c.mesh is ImmediateMesh or c.mesh is PlaneMesh):
			loose += 1
	ok.call("vfx: crystals and shards batched (%d loose meshes)" % loose, loose == 0 and s._layers["spike"]["node"] is MultiMeshInstance3D and s._layers["chip"]["node"] is MultiMeshInstance3D)
	s.free()
	# Every call site names its tier.
	var untiered := []
	_scan_tiers("res://src", untiered)
	ok.call("vfx: every call site names a tier %s" % [untiered], untiered.is_empty())
	for site in TIER_MAP:
		var f: String = site.split(":")[0]
		var src := FileAccess.get_file_as_string("res://src/hunt/" + f)
		var want: String = TIER_MAP[site]
		ok.call("vfx: tier map %s -> %s" % [site, want], src.contains(site.split(":")[1]) and _tier_of(src, site.split(":")[1]) == want)


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


const CALLS := ["vfx.cast(", "vfx.travel(", "vfx.impact(", "vfx.nova(", "vfx.linger(", "fx.ring(", "fx.flame_burst(", "fx.lightning("]


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
