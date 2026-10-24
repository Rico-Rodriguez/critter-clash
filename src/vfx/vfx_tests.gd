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
