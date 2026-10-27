extends RefCounted
## Builds a sidekick's model, unmodified (art lock: the pack's own PBR
## materials, no tint, rim or glow). Returns {"root": Node3D, "anim":
## AnimationPlayer or null, one clip name per state (idle, move, run, attack, hit, special;
## "" when the model lacks it)}.

const SDB := preload("res://src/data/sidekick_db.gd")
const Q_DIR := "res://assets/quaternius/"
## Licensed hero-quality replacements (CC0 / CC-BY, see CREDITS.md): "sf:name".
const SF_DIR := "res://assets/sidekicks/"


## Companion meshes also sit on this render layer, and the fill light only
## lights that layer, so it never brightens the hero or the ground.
const FILL_LAYER := 1 << 19


static func build(id: String, evolved := false) -> Dictionary:
	var d: Dictionary = SDB.def(id)
	var spec := str(d["evolved_model"]) if evolved and d.has("evolved_model") else str(d["model"])
	var grow := SDB.EVOLVE_SCALE if evolved else 1.0
	var out := {"root": null, "anim": null, "idle": "", "move": "", "run": "", "attack": "", "hit": "", "special": ""}
	var root := Node3D.new()
	root.name = "SidekickModel"
	var model: Node3D
	if spec.begins_with("kk:"):
		model = KK.character(spec.substr(3))
		model.scale = Vector3.ONE * float(d["scale"]) * grow
		out["anim"] = KK.anim_player(model)
		out["idle"] = "Skeletons_Idle"
		out["move"] = "Running_A"
		out["attack"] = ""
	elif spec.begins_with("prop:"):
		model = KK.prop(spec.substr(5))
		_fit(model, float(d["scale"]) * grow)
	else:
		# "sf:" scenes wrap a licensed glb pre-scaled to 1 m (tools/art/wrap_sidekicks.gd).
		var path := SF_DIR + spec.substr(3) + ".tscn" if spec.begins_with("sf:") else Q_DIR + spec.substr(2) + ".glb"
		if not ResourceLoader.exists(path):
			# A missing scene must not crash the hunt: stand in a KayKit skeleton.
			push_warning("sidekick model missing: %s" % path)
			return _placeholder(out, root, float(d["scale"]) * grow)
		model = (KK.scene(path) as PackedScene).instantiate()
		if spec.begins_with("sf:"):
			# Skinned imports carry bind-space mesh bounds that _fit can't read.
			model.scale = Vector3.ONE * float(d["scale"]) * grow
			# ...and the renderer culls them by those bounds, so use the posed ones.
			var culls: Dictionary = model.get_meta("cull_aabbs", {})
			var inner := model.get_child(0)
			for mp: String in culls:
				var mi := inner.get_node_or_null(mp) as MeshInstance3D
				if mi:
					mi.custom_aabb = culls[mp]
			_add_fill(root, float(d["scale"]) * grow, float(d.get("fill", 1.6)))
			_lit_opaque(model, spec.substr(3) in KEEP_EMISSION)
		else:
			_fit(model, float(d["scale"]) * grow)
		var ap: AnimationPlayer = model.find_child("AnimationPlayer", true, false)
		if ap:
			out["anim"] = ap
			var map: Dictionary = SDB.CLIPS.get(SDB.species(id), SDB.CLIPS.get(str(d.get("pair", [""])[0]), {}))
			for k in ["idle", "move", "run", "attack", "hit", "special"]:
				out[k] = _clip(ap, [str(map[k])]) if map.has(k) else ""
			if out["idle"] == "" and map.is_empty():
				out["idle"] = _clip(ap, ["Flying_Idle", "Bat_Flying", "Idle"])
				out["move"] = _clip(ap, ["Fast_Flying", "Bat_Flying", "Walk"])
			for n in [out["idle"], out["move"], out["run"]]:
				if n != "":
					ap.get_animation(n).loop_mode = Animation.LOOP_LINEAR
	if evolved and str(d.get("evolved_look", "")) == "ash":
		_ash(model)
	root.add_child(model)
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		(mi as MeshInstance3D).layers = 1 | FILL_LAYER
	if d.has("pair") or d.has("genes"):
		var top := float(d["scale"]) * grow * 0.95
		if d.has("pair"):
			_crest(root, SDB.def(str(d["pair"][1]))["color"], top)
		if d.has("genes"):
			_traits(root, d, top)
	out["root"] = root
	return out


## A hybrid breed's crest: three toon crystals over the head in its second
## parent's colour (its own nodes; the model's PBR stays untouched).
static func _crest(root: Node3D, col: Color, top: float) -> void:
	var crest := Node3D.new()
	crest.name = "FusionCrest"
	crest.position = Vector3(0, top, 0)
	for i in 3:
		var mi := MeshInstance3D.new()
		var pm := PrismMesh.new()
		pm.size = Vector3(0.1, 0.28 + 0.06 * int(i == 1), 0.1)
		mi.mesh = pm
		mi.position = Vector3((i - 1) * 0.13, 0.04 * int(i == 1), 0)
		mi.rotation.z = (i - 1) * -0.28
		Fx.toon(mi, col)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		crest.add_child(mi)
	root.add_child(crest)


## A bred individual's looks, as toon nodes on top of the unmodified model
## (art lock): a pattern in its accent colour, and a crisp glow gem when it
## has the glow gene. Everything is its own Node3D named "Traits".
static func _traits(root: Node3D, d: Dictionary, top: float) -> void:
	var sc := top
	var g: Dictionary = d["genes"]
	var t := Node3D.new()
	t.name = "Traits"
	var acc := Color.html(str(g.get("accent", "ffffff")))
	var pat := str(g.get("pattern", "plain"))
	match pat:
		"spots":
			for i in 5:
				var mi := _bit(SphereMesh.new(), acc, Vector3(0.12, 0.12, 0.12))
				var a := i * 1.26
				mi.position = Vector3(cos(a) * 0.17 * sc, (0.35 + 0.12 * (i % 3)) * sc, sin(a) * 0.17 * sc)
				t.add_child(mi)
		"stripes":
			for i in 3:
				var mi := _bit(BoxMesh.new(), acc, Vector3(0.36 * sc, 0.05, 0.05))
				mi.position = Vector3(0, (0.3 + 0.2 * i) * sc, 0.12 * sc)
				t.add_child(mi)
		"crest":
			for i in 3:
				var mi := _bit(PrismMesh.new(), acc, Vector3(0.1, 0.26 + 0.06 * int(i == 1), 0.1))
				mi.position = Vector3((i - 1) * 0.12, top + 0.05, 0)
				mi.rotation.z = (i - 1) * -0.3
				t.add_child(mi)
		"horns":
			for sgn in [-1.0, 1.0]:
				var mi := _bit(PrismMesh.new(), acc, Vector3(0.1, 0.3, 0.1))
				mi.position = Vector3(sgn * 0.16, top, 0)
				mi.rotation.z = sgn * -0.45
				t.add_child(mi)
	if bool(g.get("glow", false)):
		var gem := _bit(PrismMesh.new(), Color(d["color"]).lightened(0.35), Vector3(0.16, 0.22, 0.16))
		gem.name = "GlowGem"
		gem.position = Vector3(0, top + 0.3, 0)
		t.add_child(gem)
	root.add_child(t)


static func _bit(mesh: Mesh, col: Color, size: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	if mesh is PrismMesh:
		(mesh as PrismMesh).size = size
	elif mesh is BoxMesh:
		(mesh as BoxMesh).size = size
	elif mesh is SphereMesh:
		(mesh as SphereMesh).radius = size.x * 0.5
		(mesh as SphereMesh).height = size.x
	mi.mesh = mesh
	Fx.toon(mi, col)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## The Ash Wyrm: the drake's own textures baked to ash grey, with embers
## glowing in the crevices (both baked by tools/art/ash_textures.py, so no
## colour multiply and the detail stays crisp).
const ASH_ALBEDO := preload("res://assets/sidekicks/dragon_ash_albedo.png")
const ASH_EMBERS := preload("res://assets/sidekicks/dragon_ash_emission.png")
static func _ash(model: Node3D) -> void:
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var src := mi.get_active_material(i) as BaseMaterial3D
			if src == null:
				continue
			var m := src.duplicate() as BaseMaterial3D
			m.albedo_texture = ASH_ALBEDO
			m.emission_enabled = true
			m.emission = Color.WHITE
			m.emission_energy_multiplier = 1.0
			m.emission_texture = ASH_EMBERS
			# One-surface meshes take it as material_override: a surface override on
			# the cached scene's mesh logs "Parameter material is null" when freed
			# under the headless renderer.
			if mi.mesh.get_surface_count() == 1:
				mi.material_override = m
			else:
				mi.set_surface_override_material(i, m)


## Art lock: companions are lit, opaque PBR without glow. Some Sketchfab
## imports arrive unshaded, alpha-blended (with a depth prepass) or with a
## white emission map; this keeps every texture as the artist made it and only
## puts the material back on the lit, opaque path. Blended surfaces become an
## alpha cut-out (still the opaque pass), so feathers and tatters keep their
## edges. One copy per source material, shared by every instance.
## Kept emission: the bat's eyes, the mimic's gold and the treant's sap are
## small emission maps painted by their artists (no white wash).
const KEEP_EMISSION := ["bat", "mimic", "treant"]
static var _lit_cache := {}
static func _lit_opaque(model: Node3D, keep_emission: bool) -> void:
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null:
			continue
		var n := mi.mesh.get_surface_count()
		for i in n:
			var src := mi.get_active_material(i) as BaseMaterial3D
			if src == null:
				continue
			var m := lit_material(src, keep_emission)
			if m == src:
				continue
			# One surface: material_override (see _ash).
			if n == 1:
				mi.material_override = m
			else:
				mi.set_surface_override_material(i, m)


static func lit_material(src: BaseMaterial3D, keep_emission := false) -> BaseMaterial3D:
	var blended := src.transparency in [BaseMaterial3D.TRANSPARENCY_ALPHA, BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS]
	var unlit := src.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED
	var glow := src.emission_enabled and not keep_emission
	if not (blended or unlit or glow):
		return src
	var key := [src.get_instance_id(), keep_emission]
	if not _lit_cache.has(key):
		var m := src.duplicate() as BaseMaterial3D
		m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
		if blended:
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			m.alpha_scissor_threshold = 0.5
		if glow:
			m.emission_enabled = false
		_lit_cache[key] = m
	return _lit_cache[key]


## Stand-in when a model scene is missing.
static func _placeholder(out: Dictionary, root: Node3D, h: float) -> Dictionary:
	var model := KK.character("Skeleton_Minion")
	model.scale = Vector3.ONE * h * 0.45
	out["anim"] = KK.anim_player(model)
	out["idle"] = "Skeletons_Idle"
	out["move"] = "Running_A"
	out["attack"] = ""
	root.add_child(model)
	out["root"] = root
	return out


## A soft white fill light that rides with the companion so its unmodified
## PBR reads in dark zones (lights the model, never tints its materials).
static func _add_fill(root: Node3D, h: float, energy := 1.6) -> void:
	var l := OmniLight3D.new()
	l.name = "SidekickFill"
	l.light_color = Color.WHITE
	l.light_energy = energy
	l.omni_range = 2.2 * maxf(h, 0.6)
	l.light_specular = 0.3
	l.shadow_enabled = false
	l.position = Vector3(0, h * 1.1, h * 0.9)
	l.light_cull_mask = FILL_LAYER
	root.add_child(l)


static func _clip(ap: AnimationPlayer, wants: Array) -> String:
	for w: String in wants:
		for n: String in ap.get_animation_list():
			if n == w or n.ends_with("|" + w) or n.ends_with("/" + w):
				return n
	return ""


## Scales a model so its rest-pose height is `h` metres, feet on the ground.
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


## True when the model has its own clip for `which` (else the caller fakes it).
static func has(look: Dictionary, which: String) -> bool:
	var ap: AnimationPlayer = look.get("anim")
	var clip := str(look.get(which, ""))
	return ap != null and clip != "" and ap.has_animation(clip)


## Plays a state's clip. Looping clips keep running; one-shots (attack, hit,
## special) restart, sped up to fit `fit` seconds when given.
static func play(look: Dictionary, which: String, blend := 0.15, speed := 1.0, fit := 0.0) -> void:
	if not has(look, which):
		return
	var ap: AnimationPlayer = look["anim"]
	var clip := str(look[which])
	var once := which in ["attack", "hit", "special"]
	if fit > 0.0:
		speed = maxf(ap.get_animation(clip).length / fit, 0.5)
	if ap.current_animation == clip and not once:
		ap.speed_scale = speed
		return
	ap.speed_scale = 1.0 if once else speed
	ap.play(clip, blend, speed if once else 1.0)
