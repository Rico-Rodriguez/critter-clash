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
var _squash_base := Vector3.ZERO
var model: Node3D
var anim: AnimationPlayer
var cur_anim := ""
var _meshes: Array[MeshInstance3D] = []
var _tint := Color(0, 0, 0, 0)
var _rim := Color.WHITE
var _rim_strength := 0.5
var _eyes := Color(0, 0, 0, 0)
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
	if merge_parts and skel:
		_merge_parts(skel, model_name)
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
	_rim = rim
	_rim_strength = rim_strength
	_eyes = eyes
	restyle(model)


## Applies the character shader to every mesh under `root` and tracks them for
## flashes and tints. Call it again for parts added later (a swapped weapon).
## Minions draw as one mesh: KayKit splits a body into 6-8 skinned parts
## (arms, legs, head, jaw, eyes...), a draw call each per foe. Parts that
## share a skeleton, skin and material are concatenated once per model and
## the merged mesh is shared by every foe of that model.
var merge_parts := false
static var _merged := {}


func _merge_parts(skel: Skeleton3D, key: String) -> void:
	var parts: Array[MeshInstance3D] = []
	for c in skel.get_children():
		var mi := c as MeshInstance3D
		if mi == null or not mi.visible or mi.mesh == null or mi.skin == null:
			continue
		if not mi.transform.is_equal_approx(Transform3D.IDENTITY) or mi.mesh.get_blend_shape_count() > 0:
			continue
		parts.append(mi)
	if parts.size() < 2:
		return
	var skin := parts[0].skin
	for mi in parts:
		if mi.skin.get_bind_count() != skin.get_bind_count():
			return
		for b in skin.get_bind_count():
			if mi.skin.get_bind_name(b) != skin.get_bind_name(b) or mi.skin.get_bind_bone(b) != skin.get_bind_bone(b) or not mi.skin.get_bind_pose(b).is_equal_approx(skin.get_bind_pose(b)):
				return
	var names := PackedStringArray()
	for mi in parts:
		names.append(str(mi.name))
	var k := key + "|" + ",".join(names)
	var merged: ArrayMesh = _merged.get(k)
	if merged == null:
		merged = _concat(parts)
		if merged == null:
			return
		_merged[k] = merged
	parts[0].mesh = merged
	for si in merged.get_surface_count():
		parts[0].set_surface_override_material(si, null)
	for i in range(1, parts.size()):
		skel.remove_child(parts[i])
		parts[i].free()


## Concatenates every surface of `parts`, one output surface per material.
static func _concat(parts: Array[MeshInstance3D]) -> ArrayMesh:
	var by_mat := {}
	var order := []
	for mi in parts:
		for s in mi.mesh.get_surface_count():
			var mat := mi.get_active_material(s)
			var fmt: int = (mi.mesh as ArrayMesh).surface_get_format(s) if mi.mesh is ArrayMesh else -1
			if fmt == -1 or mi.mesh.surface_get_primitive_type(s) != Mesh.PRIMITIVE_TRIANGLES:
				return null
			var mk := [mat, fmt]
			if not by_mat.has(mk):
				by_mat[mk] = []
				order.append(mk)
			by_mat[mk].append(mi.mesh.surface_get_arrays(s))
	var out := ArrayMesh.new()
	var lists := [Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL, Mesh.ARRAY_TANGENT, Mesh.ARRAY_COLOR, Mesh.ARRAY_TEX_UV, Mesh.ARRAY_TEX_UV2, Mesh.ARRAY_BONES, Mesh.ARRAY_WEIGHTS]
	for mk in order:
		var arrs: Array = by_mat[mk]
		var res := []
		res.resize(Mesh.ARRAY_MAX)
		var idx := PackedInt32Array()
		var base := 0
		for a in arrs:
			for t in lists:
				if a[t] == null:
					continue
				if res[t] == null:
					res[t] = a[t].duplicate()
				else:
					res[t].append_array(a[t])
			var n: int = (a[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
			if a[Mesh.ARRAY_INDEX] != null:
				for v in a[Mesh.ARRAY_INDEX]:
					idx.append(v + base)
			else:
				for v in n:
					idx.append(v + base)
			base += n
		res[Mesh.ARRAY_INDEX] = idx
		var flags: int = (mk[1] as int) & (Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS)
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, res, [], {}, flags)
		out.surface_set_material(out.get_surface_count() - 1, mk[0])
	return out


## Minions skip the shadow pass (a draw per mesh each): the hunt gives them
## one shared blob shadow instead (see hunt_state.gd tick_blobs).
var casts_shadow := true


func restyle(root: Node) -> void:
	for mi in KK.meshes(root):
		if mi in _meshes:
			continue
		_meshes.append(mi)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if casts_shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for s in mi.mesh.get_surface_count():
			var src := mi.get_active_material(s)
			var tex: Texture2D = null
			if src is BaseMaterial3D:
				tex = (src as BaseMaterial3D).albedo_texture
			if tex == null:
				continue
			var key := "%s|%s|%.2f|%s" % [tex.resource_path, _rim.to_html(), _rim_strength, _eyes.to_html()]
			if not _mats.has(key):
				var m := ShaderMaterial.new()
				m.shader = CHAR_SHADER
				m.set_shader_parameter("albedo_tex", tex)
				m.set_shader_parameter("rim_color", _rim)
				m.set_shader_parameter("rim_strength", _rim_strength)
				m.set_shader_parameter("eye_glow", _eyes)
				m.set_shader_parameter("grime_tex", _grime)
				_mats[key] = m
			mi.set_surface_override_material(s, _mats[key])


## Stops tracking the meshes under `root` (call before freeing it).
func forget(root: Node) -> void:
	for mi in KK.meshes(root):
		_meshes.erase(mi)


func mesh_list() -> Array[MeshInstance3D]:
	return _meshes


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


## Hit feedback: a white flash and a quick squash pop of the model.
func hit_flash() -> void:
	if flash_t <= 0.0 and model:
		_squash_base = model.scale
	flash_t = 0.11
	set_flash(1.0)


func tick_common(dt: float) -> void:
	if flash_t > 0.0:
		flash_t -= dt
		var fk := clampf(flash_t / 0.11, 0.0, 1.0)
		set_flash(fk)
		if model and _squash_base != Vector3.ZERO:
			model.scale = _squash_base * (Vector3(1.0 + 0.16 * fk, 1.0 - 0.14 * fk, 1.0 + 0.16 * fk) if flash_t > 0.0 else Vector3.ONE)
			if flash_t <= 0.0:
				_squash_base = Vector3.ZERO
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


## Like face, but the turn never exceeds `max_rate` rad/s.
func face_capped(yaw: float, dt: float, rate: float, max_rate: float) -> void:
	var d := wrapf(yaw - rotation.y, -PI, PI)
	rotation.y += clampf(d * (1.0 - exp(-rate * dt)), -max_rate * dt, max_rate * dt)


static func yaw_to(from: Vector3, to: Vector3) -> float:
	return atan2(to.x - from.x, to.z - from.z)


static func dir_of(yaw: float) -> Vector3:
	return Vector3(sin(yaw), 0, cos(yaw))
