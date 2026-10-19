class_name CastFx3D
extends Node3D

## Hero cast telegraphs and hit impacts for the 3D hunt.
##
## Two families, both driven by the stage:
##   cast_telegraph() - the brief ground circle and aim lane that says a
##       hero is casting, tinted per hero so the player reads who is
##       casting at a glance: Aldric gold, Corvin arcane violet, Mordrek a
##       cold shadow green.
##   impact_burst() - the motes, the light flash and the expanding ground
##       ring where a shot or a blade lands.
##
## Phone rules: no new assets. The ground work reuses
## res://shaders/ground_decal.gdshader, the sparks reuse a dot built in
## code, and every colour rides on vertex colours. Particle systems and
## lights are pooled, the amounts stay small, and no light casts shadows.

## The stage's own ground decal shader: one flat quad that draws a disc, a
## lane or a ring. Reused here so the cast telegraph and the impact ring
## sit in the same visual family as the boss telegraphs.
const DECAL_SHADER := "res://shaders/ground_decal.gdshader"

## Per-hero cast colour. Aldric reads gold, Corvin arcane violet, Mordrek a
## cold shadow green; Gnash, the bone ghoul, gets blood red.
const HERO_COLORS := {
	"pebble": Color(1.0, 0.78, 0.36),
	"ember": Color(0.56, 0.48, 1.0),
	"bramble": Color(0.53, 0.70, 0.58),
	"lumen": Color(1.0, 0.42, 0.32),
}
## Anything that is not one of the four heroes casts warm gold.
const FALLBACK_CAST := Color(1.0, 0.84, 0.54)
## A hero taking a hit flares hot red instead of its own cast colour.
const HURT_COLOR := Color(1.0, 0.42, 0.32)

## How long a telegraph stays up, and how long an impact takes to settle.
const TELEGRAPH_LIFE := 0.5
const IMPACT_LIFE := 0.38
## Pools: a phone can hold a handful of live systems, no more.
const IMPACT_POOL := 4
const WISP_POOL := 2
const LIGHT_POOL := 3
## Rationing: a whole camp landing hits at once must not light up the phone.
## The meter refills at BURST_RATE bursts a second and holds BURST_CAP in
## reserve, so a spike shows a few impacts and the sustained rate stays low.
const BURST_RATE := 14.0
const BURST_CAP := 4.0
const BURST_COOLDOWN := 0.25

var _decal_shader: Shader
var _dot: Texture2D
var _impacts: Array[GPUParticles3D] = []
var _wisps: Array[GPUParticles3D] = []
var _lights: Array[OmniLight3D] = []
## The last hero to cast, and when. Impacts that follow its shot wear its
## colour, so a mage's violet splash never reads as a blade's gold.
var _cast_col := FALLBACK_CAST
var _cast_at := -10.0
## Burst meter: how many impacts the phone is still allowed to show.
var _tokens := BURST_CAP
var _token_t := 0.0
## Per-body cooldown, so a damage-over-time tick cannot machine-gun bursts.
var _cool: Dictionary = {}


func _ready() -> void:
	_decal_shader = load(DECAL_SHADER)
	for _i in IMPACT_POOL:
		var p := _make_impact()
		add_child(p)
		_impacts.append(p)
	for _i in WISP_POOL:
		var w := _make_wisp()
		add_child(w)
		_wisps.append(w)
	for _i in LIGHT_POOL:
		var l := _make_light()
		add_child(l)
		_lights.append(l)


## The colour a hero casts in. Unknown ids fall back to warm gold.
static func hero_color(sprite: String) -> Color:
	var id := sprite
	# Retired animal heroes still appear in old saves; they wear Aldric's gold.
	if Cast3D.RETIRED.has(id):
		id = str(Cast3D.RETIRED[id])
	var col: Color = HERO_COLORS.get(id, FALLBACK_CAST)
	return col


## The colour an impact should wear: the last hero's cast colour for a
## beat after it landed, or plain gold when nothing cast recently.
func impact_color() -> Color:
	if Time.get_ticks_msec() / 1000.0 - _cast_at < 0.8:
		return _cast_col
	return FALLBACK_CAST


## A hero begins casting: a ring charges at its feet and a lane reaches out
## along the aim to the ability's reach. Both wear the hero's colour, and
## both are gone inside half a second.
func cast_telegraph(sprite: String, at: Vector3, aim: float, reach: float, wide := false) -> void:
	var col := hero_color(sprite)
	_cast_col = col
	_cast_at = Time.get_ticks_msec() / 1000.0
	# A ring under the caster, charging from the middle out. A plain ring,
	# not a rune: the hero's own selection circle is already a rune.
	var disc := _decal(1.0, {
		"ring_color": Color(col.r, col.g, col.b, 0.95),
		"ring_radius": 0.42,
		"ring_width": 0.02,
		"ring_glow": 0.7,
		"fill_color": Color(col.r, col.g, col.b, 0.3),
		"fill_progress": 0.0,
		"ring_fade": 0.0,
		"pulse": 1.0,
	})
	disc.set_meta("fill_r", col.r)
	disc.set_meta("fill_g", col.g)
	disc.set_meta("fill_b", col.b)
	disc.set_meta("fill_alpha", 0.3)
	# A 2.2 m ring: the quad is a metre wide, the ring sits at 0.42 of it.
	disc.scale = Vector3(5.2, 1.0, 5.2)
	add_child(disc)
	# Lifted just clear of the grass blades, like the stage's reach ring.
	disc.global_position = at + Vector3(0, 0.16, 0)
	var tw := disc.create_tween()
	tw.tween_method(_charge_disc.bind(disc), 0.0, 1.0, TELEGRAPH_LIFE * 0.4)
	tw.tween_interval(TELEGRAPH_LIFE * 0.2)
	tw.tween_method(_fade_disc.bind(disc), 1.0, 0.0, TELEGRAPH_LIFE * 0.4)
	tw.tween_callback(disc.queue_free)
	# A lane along the aim, out to the reach: where the ability is going.
	if reach > 0.2:
		# The lane shows the direction of the cast, not the whole range: a
		# short ray reads at the hunt camera, a full-range one would swamp it.
		var len_m := minf(reach, 4.0)
		var wid_m := 2.4 if wide else 1.1
		var lane := _decal(1.0, {
			"ring_color": Color(col.r, col.g, col.b, 0.8),
			"ring_radius": 0.46,
			"ring_width": 0.016,
			"ring_glow": 0.5,
			"fill_color": Color(col.r, col.g, col.b, 0.16),
			"fill_progress": 1.0,
			"ring_fade": 0.0,
			"pulse": 0.0,
			"lane": true,
		})
		lane.scale = Vector3(len_m / 0.92, 1.0, wid_m * 2.0 / 0.92)
		add_child(lane)
		lane.global_position = at + Vector3(cos(aim), 0.0, sin(aim)) * (len_m * 0.5) + Vector3(0, 0.14, 0)
		# The sim's facing is an angle in x/y; the ground plane is x/z.
		lane.rotation.y = -aim
		var lt := lane.create_tween()
		lt.tween_method(_fade_ring.bind(lane), 0.0, 1.0, TELEGRAPH_LIFE * 0.4)
		lt.tween_interval(TELEGRAPH_LIFE * 0.2)
		lt.tween_method(_fade_ring.bind(lane), 1.0, 0.0, TELEGRAPH_LIFE * 0.4)
		lt.tween_callback(lane.queue_free)
	# Motes lift off the caster as the cast lands.
	var w := _take_particle(_wisps)
	if w != null:
		w.global_position = at + Vector3(0, 0.15, 0)
		_tint_particles(w, col, 1.1)
		w.restart()
		w.emitting = true


## A hit lands: motes, a light flash, a soft flare and a ring on the ground.
## Bursts are rationed, so a camp hitting at once stays readable on a phone.
func impact_burst(at: Vector3, color: Color, radius: float, strong := false, key := 0) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if key != 0 and now - float(_cool.get(key, -10.0)) < BURST_COOLDOWN:
		return
	# The meter: a few impacts may land together, but the phone only keeps
	# up with so many a second.
	_tokens = minf(BURST_CAP, _tokens + (now - _token_t) * BURST_RATE)
	_token_t = now
	if _tokens < 1.0:
		return
	_tokens -= 1.0
	if key != 0:
		_cool[key] = now
		if _cool.size() > 256:
			_cool.clear()
	# The ring on the ground, opening out to the blast radius.
	var r := clampf(radius, 0.25, 4.0)
	var ring := _decal(1.0, {
		"ring_color": Color(color.r, color.g, color.b, 0.95),
		"ring_radius": 0.04,
		"ring_width": 0.06,
		"ring_glow": 0.8,
		"fill_color": Color(color.r, color.g, color.b, 0.0),
		"ring_fade": 1.0,
		"pulse": 0.0,
	})
	ring.scale = Vector3(r / 0.45, 1.0, r / 0.45)
	add_child(ring)
	ring.global_position = at + Vector3(0, 0.14, 0)
	var tw := ring.create_tween()
	tw.tween_method(_grow_ring.bind(ring), 0.0, 1.0, IMPACT_LIFE)
	tw.tween_callback(ring.queue_free)
	# The spray.
	var p := _take_particle(_impacts)
	if p != null:
		p.global_position = at
		_tint_particles(p, color, 1.5 if strong else 1.1)
		p.restart()
		p.emitting = true
	# The light flash.
	var l := _take_light()
	if l != null:
		l.global_position = at + Vector3(0, 0.5, 0)
		l.light_color = color
		l.light_energy = 3.4 if strong else 1.9
		l.visible = true
		var lt := l.create_tween()
		lt.tween_method(_light_step.bind(l), l.light_energy, 0.0, 0.26)
		lt.tween_callback(_hide_light.bind(l))
	# The pop.
	_flare(at, color, 1.3 if strong else 0.9)


## A soft camera-facing flare where the hit landed.
func _flare(at: Vector3, color: Color, size_mul := 1.0) -> void:
	var q := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(1.6, 1.6) * size_mul
	q.mesh = quad
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.albedo_texture = _dot_texture()
	mat.albedo_color = Color(color.r * 2.0, color.g * 2.0, color.b * 2.0, 0.9)
	mat.disable_fog = true
	q.material_override = mat
	q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(q)
	q.global_position = at
	var tw := q.create_tween()
	tw.tween_method(_flare_step.bind(q), 0.0, 1.0, 0.24)
	tw.tween_callback(q.queue_free)


## A flat ground quad wearing the shared decal shader.
func _decal(size: float, params: Dictionary) -> MeshInstance3D:
	if _decal_shader == null:
		_decal_shader = load(DECAL_SHADER)
	var node := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.orientation = PlaneMesh.FACE_Y
	quad.size = Vector2(size, size)
	node.mesh = quad
	var mat := ShaderMaterial.new()
	mat.shader = _decal_shader
	for key in params:
		mat.set_shader_parameter(key, params[key])
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.set_meta("decal", true)
	return node


## The impact spray: a one-shot burst of motes, the same recipe as the
## stage's dust puffs but coloured from vertex colours.
func _make_impact() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = 16
	p.lifetime = 0.5
	p.one_shot = true
	p.explosiveness = 0.92
	p.emitting = false
	p.local_coords = false
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.12
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 68.0
	pm.initial_velocity_min = 1.2
	pm.initial_velocity_max = 3.4
	pm.gravity = Vector3(0, -6.0, 0)
	pm.damping_min = 1.0
	pm.damping_max = 2.6
	pm.scale_min = 0.5
	pm.scale_max = 1.3
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.2))
	curve.add_point(Vector2(0.2, 1.0))
	curve.add_point(Vector2(1, 0))
	var ct := CurveTexture.new()
	ct.curve = curve
	pm.scale_curve = ct
	pm.color_ramp = _fade_ramp()
	p.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.28, 0.28)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = _dot_texture()
	mat.albedo_color = Color(1.4, 1.4, 1.4, 1.0)
	mat.disable_fog = true
	quad.material = mat
	p.draw_pass_1 = quad
	return p


## The cast wisp: motes lifting off the caster as the ability leaves.
func _make_wisp() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = 12
	p.lifetime = 0.7
	p.one_shot = true
	p.explosiveness = 0.7
	p.emitting = false
	p.local_coords = false
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	pm.emission_ring_axis = Vector3.UP
	pm.emission_ring_radius = 0.85
	pm.emission_ring_inner_radius = 0.3
	pm.emission_ring_height = 0.1
	pm.direction = Vector3.UP
	pm.spread = 22.0
	pm.initial_velocity_min = 0.8
	pm.initial_velocity_max = 1.8
	pm.gravity = Vector3(0, 0.4, 0)
	pm.scale_min = 0.5
	pm.scale_max = 1.1
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.2))
	curve.add_point(Vector2(0.3, 1.0))
	curve.add_point(Vector2(1, 0))
	var ct := CurveTexture.new()
	ct.curve = curve
	pm.scale_curve = ct
	pm.color_ramp = _fade_ramp()
	p.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.22, 0.22)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = _dot_texture()
	mat.albedo_color = Color(1.1, 1.1, 1.1, 1.0)
	mat.disable_fog = true
	quad.material = mat
	p.draw_pass_1 = quad
	return p


## A shadowless omni light for the impact flash.
func _make_light() -> OmniLight3D:
	var l := OmniLight3D.new()
	l.omni_range = 4.5
	l.omni_attenuation = 1.6
	l.light_specular = 0.5
	l.shadow_enabled = false
	l.light_energy = 0.0
	l.visible = false
	return l


## A white-to-transparent ramp, so the motes fade on their own.
func _fade_ramp() -> GradientTexture1D:
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 1))
	ramp.set_color(1, Color(1, 1, 1, 0))
	var tex := GradientTexture1D.new()
	tex.gradient = ramp
	return tex


## A soft round dot for the sparks and the flare, built in code so the
## effect needs no new texture asset. The stage's own billboards use the
## same one (see stage3d._soft_dot).
static func soft_dot() -> Texture2D:
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for y in 32:
		for x in 32:
			var d := Vector2(x - 15.5, y - 15.5).length() / 16.0
			var a := clampf(1.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a * a))
	return ImageTexture.create_from_image(img)


## A soft round dot for the sparks, built once in code so the effect needs
## no new texture asset.
func _dot_texture() -> Texture2D:
	if _dot == null:
		_dot = soft_dot()
	return _dot


## Tints a pooled emitter. The colour rides on the vertex colours, so one
## system serves every hero.
func _tint_particles(p: GPUParticles3D, col: Color, gain: float) -> void:
	var quad := p.draw_pass_1 as QuadMesh
	if quad == null:
		return
	var mat := quad.material as StandardMaterial3D
	if mat == null:
		return
	mat.albedo_color = Color(col.r * gain, col.g * gain, col.b * gain, 1.0)


## The first free emitter in a pool, or null when they are all busy.
func _take_particle(pool: Array) -> GPUParticles3D:
	for node in pool:
		var p := node as GPUParticles3D
		if p != null and not p.emitting:
			return p
	return null


## The first free light in the pool, or null when they are all busy.
func _take_light() -> OmniLight3D:
	for node in _lights:
		var l := node as OmniLight3D
		if l != null and not l.visible:
			return l
	return null


## Charges the disc: the ring brightens while the fill grows from the
## middle out.
func _charge_disc(v: float, node: MeshInstance3D) -> void:
	var m := node.material_override as ShaderMaterial
	if m == null:
		return
	m.set_shader_parameter("ring_fade", v)
	m.set_shader_parameter("fill_progress", v)


## Fades the disc out: the ring dims and the fill thins with it.
func _fade_disc(v: float, node: MeshInstance3D) -> void:
	var m := node.material_override as ShaderMaterial
	if m == null:
		return
	m.set_shader_parameter("ring_fade", v)
	var base := float(node.get_meta("fill_alpha", 0.0))
	m.set_shader_parameter("fill_color", Color(
		float(node.get_meta("fill_r", 0.0)),
		float(node.get_meta("fill_g", 0.0)),
		float(node.get_meta("fill_b", 0.0)),
		base * v))


## Dims a ring on its own (the aim lane).
func _fade_ring(v: float, node: MeshInstance3D) -> void:
	var m := node.material_override as ShaderMaterial
	if m == null:
		return
	m.set_shader_parameter("ring_fade", v)


## Opens the impact ring out to the blast radius as it fades.
func _grow_ring(v: float, node: MeshInstance3D) -> void:
	var m := node.material_override as ShaderMaterial
	if m == null:
		return
	var e := 1.0 - pow(1.0 - v, 3.0)
	m.set_shader_parameter("ring_radius", lerpf(0.04, 0.45, e))
	m.set_shader_parameter("ring_width", lerpf(0.06, 0.018, e))
	m.set_shader_parameter("ring_fade", 1.0 - v)


## The flare: a soft pop that spreads as it dies.
func _flare_step(v: float, node: MeshInstance3D) -> void:
	var mat := node.material_override as StandardMaterial3D
	if mat == null:
		return
	var c := mat.albedo_color
	mat.albedo_color = Color(c.r, c.g, c.b, 0.9 * (1.0 - v))
	node.scale = Vector3.ONE * (1.0 + 0.6 * v)


## The light flash: a spike of energy that dies away.
func _light_step(v: float, light: OmniLight3D) -> void:
	if is_instance_valid(light):
		light.light_energy = v


## Puts a spent light back in the pool.
func _hide_light(light: OmniLight3D) -> void:
	if is_instance_valid(light):
		light.visible = false
		light.light_energy = 0.0
