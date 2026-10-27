extends RefCounted
## A bred pet's coat pattern (spots, stripes), glow gene and mutation, painted
## into the model's own materials. Each source StandardMaterial3D is rebuilt as
## a ShaderMaterial on fx/pet_skin.gdshader that reads the very same textures
## and PBR numbers, plus masked overlays (plates, rime, arcs, cracks, moss,
## spots...): no attached shapes and no whole-body tint, so the artist's
## albedo, normal and roughness maps stay sharp. One material per source
## material and variant (mutation, pattern, glow) is shared by every pet that
## wears it; the pet's own accent colour is a per-instance uniform.
## No class_name (OTA packs): preload by path.

const GEN := preload("res://src/data/pet_gen.gd")
const SDB := preload("res://src/data/sidekick_db.gd")
const SHADER := preload("res://src/fx/pet_skin.gdshader")

const PATTERN_IDS := {"spots": 1, "stripes": 2}
## UV tiling of the marks per model (mark cells across the whole UV square): the
## artists' atlases differ a lot in how much of the square one limb takes.
const PAT_SCALE := {"dragon": 12.0, "mawko": 16.0, "skeleton": 22.0, "lich": 16.0, "crow": 16.0, "plague": 16.0,
	"mimic": 16.0, "bat": 16.0, "squire": 11.0, "wraith": 16.0, "treant": 16.0}

static var _cache := {}


## The shader's variant ids for a genome: {"mutation": 0..6, "pattern": 0..2, "glow": bool}.
static func variant(g: Dictionary) -> Dictionary:
	return {
		"mutation": GEN.MUTATION_ORDER.find(str(g.get("mutation", ""))) + 1,
		"pattern": int(PATTERN_IDS.get(str(g.get("pattern", "plain")), 0)),
		"glow": bool(g.get("glow", false)),
	}


static func is_plain(g: Dictionary) -> bool:
	var v := variant(g)
	return int(v["mutation"]) == 0 and int(v["pattern"]) == 0 and not bool(v["glow"])


## The colour of a genome's marks: its accent gene, else `fallback`.
static func accent(g: Dictionary, fallback: Color) -> Color:
	var hex := str(g.get("accent", ""))
	return Color.html(hex) if hex.is_valid_html_color() else fallback


## Gives every mesh under `model` (the body and its grafted parts) the variant
## of genome `g`. A plain genome changes nothing.
static func apply(model: Node3D, g: Dictionary, fallback: Color, body_model: String) -> void:
	if is_plain(g):
		return
	var v := variant(g)
	var acc := accent(g, fallback)
	var mcol := Color.html(str(GEN.MUTATIONS[str(g["mutation"])]["color"])) if int(v["mutation"]) > 0 else Color.WHITE
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null:
			continue
		var n := mi.mesh.get_surface_count()
		var touched := false
		for i in n:
			var src := mi.get_active_material(i) as BaseMaterial3D
			if src == null:
				continue
			var m := material(src, v, mcol, _model_of(mi, body_model))
			if m == null:
				continue
			touched = true
			# One surface: material_override (a surface override on the cached
			# scene's mesh logs "Parameter material is null" when freed headless).
			if n == 1:
				mi.material_override = m
			else:
				mi.set_surface_override_material(i, m)
		if touched:
			mi.set_instance_shader_parameter("accent", acc)


## The model a mesh comes from: a borrowed part carries its donor's, anything
## else is the body's.
static func _model_of(mi: Node, body_model: String) -> String:
	var n: Node = mi
	while n != null:
		if n.has_meta("donor"):
			return str(SDB.def(str(n.get_meta("donor")))["model"]).trim_prefix("sf:")
		n = n.get_parent()
	return body_model


## The shared variant material for `src`, or null when `src` uses a feature the
## shader does not copy (it is then left as the artist made it).
static func material(src: BaseMaterial3D, v: Dictionary, mcol: Color, model_name: String) -> ShaderMaterial:
	var key := [src.get_instance_id(), int(v["mutation"]), int(v["pattern"]), bool(v["glow"])]
	if not _cache.has(key):
		_cache[key] = {"src": src, "mat": _make(src, v, mcol, float(PAT_SCALE.get(model_name, 16.0)))}
	return _cache[key]["mat"]


static func convertible(m: BaseMaterial3D) -> bool:
	return m is StandardMaterial3D \
		and m.shading_mode == BaseMaterial3D.SHADING_MODE_PER_PIXEL \
		and m.cull_mode == BaseMaterial3D.CULL_DISABLED \
		and m.transparency in [BaseMaterial3D.TRANSPARENCY_DISABLED, BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR] \
		and not (m.uv1_triplanar or m.vertex_color_use_as_albedo or m.rim_enabled or m.clearcoat_enabled \
			or m.anisotropy_enabled or m.subsurf_scatter_enabled or m.heightmap_enabled or m.detail_enabled \
			or m.refraction_enabled or m.backlight_enabled or m.proximity_fade_enabled or m.billboard_mode != 0) \
		and m.uv1_scale == Vector3.ONE and m.uv1_offset == Vector3.ZERO


static func _ch(c: int) -> Vector4:
	match c:
		BaseMaterial3D.TEXTURE_CHANNEL_GREEN:
			return Vector4(0, 1, 0, 0)
		BaseMaterial3D.TEXTURE_CHANNEL_BLUE:
			return Vector4(0, 0, 1, 0)
		BaseMaterial3D.TEXTURE_CHANNEL_ALPHA:
			return Vector4(0, 0, 0, 1)
		BaseMaterial3D.TEXTURE_CHANNEL_GRAYSCALE:
			return Vector4(1, 1, 1, 0) / 3.0
	return Vector4(1, 0, 0, 0)


static func _make(src: BaseMaterial3D, v: Dictionary, mcol: Color, pat_scale: float) -> ShaderMaterial:
	if not convertible(src):
		return null
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter("albedo", src.albedo_color)
	m.set_shader_parameter("tex_albedo", src.albedo_texture)
	m.set_shader_parameter("roughness", src.roughness)
	m.set_shader_parameter("metallic", src.metallic)
	m.set_shader_parameter("specular", src.metallic_specular)
	if src.roughness_texture != null:
		m.set_shader_parameter("tex_rough", src.roughness_texture)
		m.set_shader_parameter("rough_ch", _ch(src.roughness_texture_channel))
	if src.metallic_texture != null:
		m.set_shader_parameter("tex_metal", src.metallic_texture)
		m.set_shader_parameter("metal_ch", _ch(src.metallic_texture_channel))
	if src.normal_enabled and src.normal_texture != null:
		m.set_shader_parameter("tex_normal", src.normal_texture)
		m.set_shader_parameter("normal_scale", src.normal_scale)
	if src.ao_enabled and src.ao_texture != null:
		m.set_shader_parameter("tex_ao", src.ao_texture)
		m.set_shader_parameter("ao_ch", _ch(src.ao_texture_channel))
		m.set_shader_parameter("ao_on", 1.0)
		m.set_shader_parameter("ao_light", src.ao_light_affect)
	if src.emission_enabled:
		m.set_shader_parameter("emit_on", 1.0)
		m.set_shader_parameter("emit_col", src.emission)
		m.set_shader_parameter("emit_energy", src.emission_energy_multiplier)
		m.set_shader_parameter("emit_mul", 1.0 if src.emission_operator == BaseMaterial3D.EMISSION_OP_MULTIPLY else 0.0)
		if src.emission_texture != null:
			m.set_shader_parameter("tex_emit", src.emission_texture)
	if src.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR:
		m.set_shader_parameter("alpha_on", 1.0)
		m.set_shader_parameter("scissor", src.alpha_scissor_threshold)
	m.set_shader_parameter("mutation", int(v["mutation"]))
	m.set_shader_parameter("pattern", int(v["pattern"]))
	m.set_shader_parameter("glow_on", 1.0 if bool(v["glow"]) else 0.0)
	m.set_shader_parameter("mut_color", mcol)
	m.set_shader_parameter("pat_scale", pat_scale)
	return m
