class_name BossLook
extends RefCounted

## Grimdark lair bosses (art pass 2026-10-18: Gravemaw, Nightmaw): corrupted beasts that stand
## well over twice the hero's height, with burning eyes, a glowing core and
## emissive corruption veins. Enemy-side only; Cast3D asks here first for
## these ids, and Stage3D calls dress() after a boss model is sized.
## Models (CC-BY 4.0, see CREDITS.md) live in assets/models/sketchfab/boss/;
## their death/hit clips are KayKit (CC0) retargeted by tools/retarget.gd and
## merged with the native clips by tools/boss_bake.gd. Vein masks and the
## ashen werewolf hide come from tools/paint_boss.py.
## The ids stay for saves; names live in Catalog.

const DIR := "res://assets/models/sketchfab/boss/"

const BOSSES := {
	# Gravemaw, the Barrow Troll (Meadow). Ember-red corruption.
	"thistle": {
		"scene": DIR + "troll.tscn",
		"clips": {"idle": "idle", "run": "run", "walk": "walk", "attack": "attack", "hit": "stagger", "death": "death", "perch": "idle"},
		"glow": Color(1.0, 0.3, 0.06),
		"grade": Color(0.6, 0.58, 0.56),
		"mats": {
			"MI_Troll_Body_Mountain01_Upper": {"veins": DIR + "troll_veins_upper.png"},
			"MI_Troll_Body_Mountain01_Lower": {"veins": DIR + "troll_veins_lower.png"},
			"MI_Troll_Heads_Cave": {"veins": DIR + "troll_veins_head.png"},
		},
		"core_bone": "Spine2_027",
		"core_size": 0.13,
		"eyes": "bones",
		# Skinned AABB of this rig is ~2.8x its posed body (scaled bind
		# space), so Stage3D's bounds-based sizing needs a boost: about 12 m
		# visible, ~2.8x the hero.
		"size_boost": 2.3,
	},
	# Nightmaw, the Rot-Wolf (Mushroom Forest). Sick green corruption.
	"caplet": {
		"scene": DIR + "werewolf.tscn",
		"clips": {"idle": "idle", "run": "run", "walk": "walk", "attack": "attack", "hit": "hit", "death": "death", "perch": "idle"},
		"glow": Color(0.55, 1.0, 0.22),
		"grade": Color(0.9, 0.9, 0.9),
		"mats": {
			"Body": {"albedo_tex": DIR + "werewolf_paint.png", "veins": DIR + "werewolf_veins.png"},
			"Wool": {"albedo_tex": DIR + "werewolf_wool_paint.png"},
		},
		"core_bone": "Chest_42",
		"core_size": 0.12,
		"eyes": "Head_0",
		# Hunched, long-armed: sized a little under Gravemaw (~12 m, 2.8x the knight).
		"size_boost": 1.0,
	},
}


static func has(id: String) -> bool:
	return BOSSES.has(id) and ResourceLoader.exists(str(BOSSES[id]["scene"]))


static func scene(id: String) -> String:
	return str(BOSSES[id]["scene"])


static func clips(id: String) -> Dictionary:
	return BOSSES[id]["clips"]


static func size_boost(id: String) -> float:
	return float(BOSSES[id].get("size_boost", 1.0))


static func glow(id: String) -> Color:
	return BOSSES[id]["glow"]


## Restyle a sized boss model in place: matte graded hide with emissive veins,
## burning eyes, a pulsing core on the chest bone, and (in the hunt) a slow
## drift of corruption embers. Costs: 1 core quad, 1 particle draw, eyes.
static func dress(model: Node3D, id: String) -> void:
	if not BOSSES.has(id):
		return
	var cfg: Dictionary = BOSSES[id]
	var col: Color = cfg["glow"]
	_materials(model, cfg)
	var sk := _skeleton(model)
	if sk == null:
		return
	if str(cfg["eyes"]) == "bones":
		Armor3D.glow_eyes(model, col)
	else:
		_head_eyes(model, sk, str(cfg["eyes"]), col)
	if _height(model) < 6.0:
		# Portraits, banners and medallions: veins and eyes only. The core
		# light blows out a close-up and its quad would punch the alpha.
		return
	_core(model, sk, str(cfg["core_bone"]), float(cfg["core_size"]), col)
	_embers(model, col)


## Low render tier: fewer embers, no core light. Loaded lazily so offline
## tools (no autoloads) can still dress a boss.
static func _low() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or not tree.root.has_node("SaveGame"):
		return false
	return str(load("res://scripts/quality.gd").level()) == "low"


static func _skeleton(model: Node) -> Skeleton3D:
	var found := model.find_children("*", "Skeleton3D", true, false)
	return found[0] as Skeleton3D if not found.is_empty() else null


static func _materials(node: Node, cfg: Dictionary) -> void:
	var mats: Dictionary = cfg["mats"]
	var grade: Color = cfg["grade"]
	var col: Color = cfg["glow"]
	for mi: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var base := mi.get_active_material(i)
			if not base is StandardMaterial3D:
				continue
			var mat := (base as StandardMaterial3D).duplicate() as StandardMaterial3D
			var o: Dictionary = mats.get(base.resource_name, {})
			# Matte, damp hide: no metal, low spec, a cold thin rim.
			mat.metallic = 0.0
			mat.metallic_texture = null
			mat.metallic_specular = 0.3
			mat.roughness_texture = null
			mat.roughness = 0.84
			mat.clearcoat_enabled = false
			mat.rim_enabled = true
			mat.rim = 0.18
			mat.rim_tint = 0.85
			if o.has("albedo_tex"):
				mat.albedo_texture = load(str(o["albedo_tex"]))
			mat.albedo_color = mat.albedo_color * grade
			if o.has("veins"):
				mat.emission_enabled = true
				mat.emission = col
				mat.emission_energy_multiplier = float(cfg.get("vein_energy", 1.6))
				mat.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
				mat.emission_texture = load(str(o["veins"]))
			mi.set_surface_override_material(i, mat)


## World-space scale of a bone's frame, walked down from the (already sized)
## model root so it works before the model enters the tree.
static func _bone_scale(model: Node3D, sk: Skeleton3D, bone: int) -> float:
	var xf := sk.get_bone_global_rest(bone)
	var n: Node = sk
	while n != null and n != model.get_parent():
		if n is Node3D:
			xf = (n as Node3D).transform * xf
		n = n.get_parent()
	return maxf(xf.basis.get_scale().x, 0.000001)


static func _attach(sk: Skeleton3D, bone_name: String) -> BoneAttachment3D:
	var at := BoneAttachment3D.new()
	at.name = "BossFx_" + bone_name
	at.bone_name = bone_name
	sk.add_child(at)
	at.transform = sk.get_bone_global_rest(sk.find_bone(bone_name))
	return at


const CORE_SHADER := """shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, depth_test_disabled, cull_disabled, shadows_disabled, fog_disabled;
uniform vec4 col : source_color = vec4(1.0, 0.3, 0.06, 1.0);
uniform float size = 1.0;
uniform float energy = 2.0;
varying vec2 uv;
void vertex() {
	// Camera-facing quad of a fixed world size, whatever the bone's scale.
	uv = UV;
	vec3 c = (VIEW_MATRIX * vec4(MODEL_MATRIX[3].xyz, 1.0)).xyz;
	c.z += size * 0.6;
	POSITION = PROJECTION_MATRIX * vec4(c + vec3((UV - 0.5) * vec2(2.0, -2.0) * size, 0.0), 1.0);
}
void fragment() {
	float d = length(uv - 0.5) * 2.0;
	float pulse = 0.78 + 0.22 * sin(TIME * 3.1) + 0.08 * sin(TIME * 7.7);
	float core = (exp(-d * d * 18.0) * 1.6 + exp(-d * d * 4.0) * 0.45) * (1.0 - smoothstep(0.55, 1.0, d));
	ALBEDO = col.rgb * core * energy * pulse;
}
"""


## The heart of the corruption: an additive glow sprite riding the chest
## bone (drawn through the hide so it reads as light under the skin) plus a
## short-range omni light that tints the body round it.
static func _core(model: Node3D, sk: Skeleton3D, bone_name: String, frac: float, col: Color) -> void:
	var b := sk.find_bone(bone_name)
	if b < 0:
		return
	var meters := _height(model)
	var at := _attach(sk, bone_name)
	var spr := Sprite3D.new()
	spr.name = "BossCore"
	var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	spr.texture = ImageTexture.create_from_image(img)
	var sh := Shader.new()
	sh.code = CORE_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("col", col)
	mat.set_shader_parameter("size", meters * frac)
	mat.set_shader_parameter("energy", 1.6)
	spr.material_override = mat
	spr.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	spr.extra_cull_margin = 16384.0
	at.add_child(spr)
	if _low():
		return
	var light := OmniLight3D.new()
	light.name = "BossCoreLight"
	light.light_color = col
	light.light_energy = 2.4
	light.shadow_enabled = false
	light.light_specular = 0.2
	var s := _bone_scale(model, sk, b)
	light.omni_range = meters * 0.42 / s
	light.position = Vector3(0, 0, meters * 0.12 / s)
	at.add_child(light)


## Model height in world metres (Stage3D sizes the model before dress()).
static func _height(model: Node3D) -> float:
	var root := model.get_parent()
	if root != null and root.has_meta("meters"):
		return float(root.get_meta("meters"))
	var sk := _skeleton(model)
	var lo := 1e9
	var hi := -1e9
	for b in sk.get_bone_count():
		var y := (_chain(model, sk) * sk.get_bone_global_rest(b).origin).y
		lo = minf(lo, y)
		hi = maxf(hi, y)
	return maxf(hi - lo, 0.5)


static func _chain(model: Node3D, sk: Skeleton3D) -> Transform3D:
	var xf := Transform3D()
	var n: Node = sk
	while n != null and n != model.get_parent():
		if n is Node3D:
			xf = (n as Node3D).transform * xf
		n = n.get_parent()
	return xf


## Rigs without eye bones (the werewolf): two ember beads on the head bone,
## placed from the head/jaw/neck rest pose.
static func _head_eyes(model: Node3D, sk: Skeleton3D, head_name: String, col: Color) -> void:
	var hb := sk.find_bone(head_name)
	if hb < 0:
		return
	var head := sk.get_bone_global_rest(hb)
	var jb := sk.find_bone("Jaw_1")
	var nb := sk.get_bone_parent(hb)
	if jb < 0 or nb < 0:
		return
	var jaw := sk.get_bone_global_rest(jb).origin
	var neck := sk.get_bone_global_rest(nb).origin
	# Snout direction: from the neck through the jaw, flattened off the head's up.
	var up := (head.origin - neck).normalized()
	var fwd := (jaw - head.origin)
	fwd = (fwd - up * fwd.dot(up)).normalized()
	var side := up.cross(fwd).normalized()
	var span := head.origin.distance_to(jaw)
	var at := _attach(sk, head_name)
	var inv := head.basis.inverse()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = col
	mat.emission_enabled = true
	mat.emission = col
	mat.emission_energy_multiplier = 4.0
	var bead := SphereMesh.new()
	bead.radius = span * 0.09
	bead.height = span * 0.18
	bead.radial_segments = 8
	bead.rings = 4
	for sgn: float in [-1.0, 1.0]:
		var e := MeshInstance3D.new()
		e.name = "BossEye"
		e.mesh = bead
		e.material_override = mat
		e.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var p: Vector3 = up * span * EYE_UP + fwd * span * EYE_FWD + side * span * EYE_SIDE * sgn
		e.position = inv * p
		at.add_child(e)


const EYE_UP := 0.35
const EYE_FWD := 0.75
const EYE_SIDE := 0.28


## Corruption embers drifting up off the body: one GPU particle draw.
static func _embers(model: Node3D, col: Color) -> void:
	var root := model.get_parent() as Node3D
	if root == null or not root.has_meta("meters"):
		return
	var meters := float(root.get_meta("meters"))
	if meters < 6.0:
		return  # banners and portraits stay clean
	var p := GPUParticles3D.new()
	p.name = "BossEmbers"
	p.amount = 14 if _low() else 28
	p.lifetime = 2.6
	p.preprocess = 2.0
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3(-meters, -1, -meters), Vector3(meters * 2, meters * 1.6, meters * 2))
	p.position = Vector3(0, meters * 0.45, 0)
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = meters * 0.28
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 25.0
	pm.initial_velocity_min = meters * 0.08
	pm.initial_velocity_max = meters * 0.18
	pm.gravity = Vector3(0, meters * 0.02, 0)
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.6
	pm.scale_min = 0.6
	pm.scale_max = 1.3
	var ramp := Gradient.new()
	ramp.set_color(0, Color(col.r, col.g, col.b, 0.0))
	ramp.add_point(0.15, Color(col.r * 1.4, col.g * 1.4, col.b * 1.4, 1.0))
	ramp.set_color(ramp.get_point_count() - 1, Color(col.r * 0.4, col.g * 0.2, col.b * 0.1, 0.0))
	var gt := GradientTexture1D.new()
	gt.gradient = ramp
	pm.color_ramp = gt
	p.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * meters * 0.022
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	var dot := GradientTexture2D.new()  # soft round spark instead of a hard square
	dot.width = 32
	dot.height = 32
	dot.fill = GradientTexture2D.FILL_RADIAL
	dot.fill_from = Vector2(0.5, 0.5)
	dot.fill_to = Vector2(0.5, 0.0)
	var fall := Gradient.new()
	fall.set_color(0, Color(1, 1, 1, 1))
	fall.set_color(1, Color(1, 1, 1, 0))
	dot.gradient = fall
	m.albedo_texture = dot
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	m.disable_receive_shadows = true
	quad.material = m
	p.draw_pass_1 = quad
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(p)
