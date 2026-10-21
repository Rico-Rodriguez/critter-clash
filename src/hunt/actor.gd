class_name Actor
extends Node3D
## Anything that fights: the hero, a skeleton, the boss. Position lives on
## the XZ plane (y = 0 ground). Owns the model, its animation player and the
## per-instance shader flash/tint.

const CHAR_SHADER := preload("res://src/fx/char.gdshader")

var hunt: Hunt
var hp := 100.0
var max_hp := 100.0
var radius := 0.5
var mass := 1.0
var speed := 4.0
var alive := true
var knock := Vector3.ZERO
var stun_t := 0.0
var freeze_t := 0.0
var flash_t := 0.0
var model: Node3D
var anim: AnimationPlayer
var cur_anim := ""
var _meshes: Array[MeshInstance3D] = []
var _tint := Color(0, 0, 0, 0)
static var _mats := {}
static var _grime: NoiseTexture2D


## Loads a KayKit character, swaps its materials for the shared character
## shader (one material per texture), and keeps the mesh list for flashes.
## `head_scale` < 1 shrinks the head (and helmet) on the shared skeleton for a
## more adult build; the chest is broadened a little to match.
func build_model(model_name: String, weapons: Dictionary, rim: Color, rim_strength := 0.5, eyes := Color(0, 0, 0, 0), head_scale := 0.8) -> void:
	model = KK.character(model_name, weapons)
	add_child(model)
	var skel: Skeleton3D = model.find_child("Skeleton3D", true, false)
	if skel and head_scale != 1.0:
		var bs := BoneScaler.new()
		bs.scales = {"head": Vector3.ONE * head_scale, "chest": Vector3(1.06, 1.0, 1.1)}
		skel.add_child(bs)
	if _grime == null:
		_grime = NoiseTexture2D.new()
		_grime.width = 128
		_grime.height = 128
		_grime.seamless = true
		var fn := FastNoiseLite.new()
		fn.frequency = 0.045
		fn.fractal_octaves = 3
		_grime.noise = fn
	anim = KK.anim_player(model)
	anim.playback_default_blend_time = 0.12
	for mi in KK.meshes(model):
		_meshes.append(mi)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		for s in mi.mesh.get_surface_count():
			var src := mi.get_active_material(s)
			var tex: Texture2D = null
			if src is BaseMaterial3D:
				tex = (src as BaseMaterial3D).albedo_texture
			if tex == null:
				continue
			var key := "%s|%s|%.2f|%s" % [tex.resource_path, rim.to_html(), rim_strength, eyes.to_html()]
			if not _mats.has(key):
				var m := ShaderMaterial.new()
				m.shader = CHAR_SHADER
				m.set_shader_parameter("albedo_tex", tex)
				m.set_shader_parameter("rim_color", rim)
				m.set_shader_parameter("rim_strength", rim_strength)
				m.set_shader_parameter("eye_glow", eyes)
				m.set_shader_parameter("grime_tex", _grime)
				_mats[key] = m
			mi.set_surface_override_material(s, _mats[key])


func play(name_: String, blend := -1.0, speed_ := 1.0, restart := false) -> void:
	if anim == null or not anim.has_animation(name_):
		return
	if name_ == cur_anim and not restart:
		anim.speed_scale = speed_
		return
	cur_anim = name_
	anim.speed_scale = speed_
	if restart and anim.current_animation == name_:
		anim.stop()
	anim.play(name_, blend)


func anim_length(name_: String) -> float:
	if anim and anim.has_animation(name_):
		return anim.get_animation(name_).length
	return 1.0


func set_flash(v: float) -> void:
	for mi in _meshes:
		mi.set_instance_shader_parameter("flash", v)


func set_tint(c: Color) -> void:
	_tint = c
	if freeze_t <= 0.0:
		_apply_tint(c)


func _apply_tint(c: Color) -> void:
	for mi in _meshes:
		mi.set_instance_shader_parameter("tint", c)


func hit_flash() -> void:
	flash_t = 0.11
	set_flash(1.0)


func tick_common(dt: float) -> void:
	if flash_t > 0.0:
		flash_t -= dt
		set_flash(clampf(flash_t / 0.11, 0.0, 1.0))
	if knock.length_squared() > 0.0001:
		position += knock * dt
		knock = knock.move_toward(Vector3.ZERO, 26.0 * dt)
	stun_t = maxf(stun_t - dt, 0.0)
	if freeze_t > 0.0:
		freeze_t -= dt
		if freeze_t <= 0.0:
			if anim:
				anim.speed_scale = 1.0
			_apply_tint(_tint)


func freeze(t: float) -> void:
	freeze_t = maxf(freeze_t, t)
	if anim:
		anim.speed_scale = 0.0
	_apply_tint(Color(0.45, 0.75, 1.0, 0.85))


func push(dir: Vector3, force: float) -> void:
	knock += dir * force / maxf(mass, 0.5)


func flat_pos() -> Vector3:
	return Vector3(position.x, 0, position.z)


func face(yaw: float, dt: float, rate := 14.0) -> void:
	rotation.y = lerp_angle(rotation.y, yaw, 1.0 - exp(-rate * dt))


static func yaw_to(from: Vector3, to: Vector3) -> float:
	return atan2(to.x - from.x, to.z - from.z)


static func dir_of(yaw: float) -> Vector3:
	return Vector3(sin(yaw), 0, cos(yaw))
