class_name Actor
extends Node3D
## Anything that fights: the hero, a skeleton, the boss. Position lives on
## the XZ plane (y = 0 ground). Owns the model, its animation player and the
## per-instance shader flash/tint.

const CHAR_SHADER := preload("res://src/fx/char.gdshader")
const FoeRig := preload("res://src/core/foe_rig.gd")

var hunt: Hunt
var hp := 100.0
var max_hp := 100.0
var radius := 0.5
var mass := 1.0
## What the ground under this body does (set each tick by TerrainRun; 1 on plain ground):
## walk-speed multiplier, grip (hero acceleration), and how far knockback carries.
var t_speed := 1.0
var t_grip := 1.0
var t_slide := 1.0
var speed := 4.0
var alive := true
var knock := Vector3.ZERO
var stun_t := 0.0
var freeze_t := 0.0
var flash_t := 0.0
var _flash_len := 0.12
## Body springs: squash/stretch (a scale offset in the model's own axes) and a
## lean (small rotation about X and Z), both kicked by impulses and settling
## with a little overshoot. Idle actors cost nothing (see _tick_springs).
const SPRING_K := 420.0
const SPRING_C := 17.0
const SPRING_IMPULSE := 34.0
var _sq := Vector3.ZERO
var _sq_v := Vector3.ZERO
var _lean := Vector2.ZERO
var _lean_v := Vector2.ZERO
## A held pose: the springs settle here instead of at rest (a boss crouching
## through a wind-up). Zero is the rest pose.
var _sq_t := Vector3.ZERO
var _lean_t := Vector2.ZERO
var _spring_base := Vector3.ONE
var _spring_on := false
var model: Node3D
var anim: AnimationPlayer
var cur_anim := ""
## True for a "glb:" or "proc:" model (see foe_rig.gd): it keeps its own PBR
## materials and its own clips, which `play` finds through `_rig_def`.
var foreign := false
var _rig_def: Dictionary = {}
var _clip_cache := {}
var _meshes: Array[MeshInstance3D] = []
var _tint := Color(0, 0, 0, 0)
var _rim := Color.WHITE
var _rim_strength := 0.5
var _eyes := Color(0, 0, 0, 0)
static var _mats := {}
static var _skins := {}
static var _grime: NoiseTexture2D


## Loads a KayKit character, swaps its materials for the shared character
## shader (one material per texture), and keeps the mesh list for flashes.
## `head_scale` < 1 shrinks the head (and helmet) on the shared skeleton for a
## more adult build; the chest is broadened a little to match.
## A "glb:"/"proc:" `model_name` builds a foreign rig instead (foe_rig.gd);
## `rig_def` is the foe or boss def that carries its fit, clips and alias.
## The hero build (`adult_build`): bone scales on the shared KayKit skeleton.
## Bone scales multiply down the chain (spine > chest > head and arms), so
## `head` and `arm` are the sizes wanted on screen and are divided by the trunk.
const HERO_BUILD := {"head": 0.64, "arm": Vector3(1.04, 1.06, 1.04), "chest": Vector3(1.1, 1.04, 1.1), "spine": Vector3(1.0, 1.08, 1.0), "leg": 1.28}
## Set before `build_model` for heroes (in the hunt, camp and portraits).
var adult_build := false
## The hips' rest height on KayKit's Rig_Medium, which the baked clips assume.
const KK_HIPS := 0.405663


func build_model(model_name: String, weapons: Dictionary, rim: Color, rim_strength := 0.5, eyes := Color(0, 0, 0, 0), head_scale := 0.8, rig_def := {}) -> void:
	if FoeRig.is_foreign(model_name):
		_build_foreign(model_name, weapons, rig_def)
		return
	model = KK.character(model_name, weapons)
	add_child(model)
	var skel: Skeleton3D = model.find_child("Skeleton3D", true, false)
	if merge_parts and skel:
		_merge_parts(skel, model_name)
	var own_hips := skel.get_bone_rest(skel.find_bone("hips")).origin.y if skel and skel.find_bone("hips") >= 0 else 0.0
	if own_hips > KK_HIPS + 0.05:
		# Our own grown-up bodies (tools/art/make_hero_body.py) are built to
		# size: their legs are longer than the clips expect, so only the hips
		# are lifted, to stand on the ground.
		var lift := BoneScaler.new()
		lift.lift = own_hips - KK_HIPS
		skel.add_child(lift)
	elif skel and adult_build:
		# Heroes go further than the dead: a smaller head on a longer body and
		# longer legs, so a knight reads as a grown man in armor, not a toy.
		var bs := BoneScaler.new()
		var leg := HERO_BUILD["leg"] as float
		var trunk: Vector3 = (HERO_BUILD["spine"] as Vector3) * (HERO_BUILD["chest"] as Vector3)
		var arm: Vector3 = (HERO_BUILD["arm"] as Vector3) / trunk
		bs.scales = {"head": Vector3.ONE * float(HERO_BUILD["head"]) / trunk, "chest": HERO_BUILD["chest"], "spine": HERO_BUILD["spine"],
			"upperarm.l": arm, "upperarm.r": arm, "upperleg.l": Vector3(1.0, leg, 1.0), "upperleg.r": Vector3(1.0, leg, 1.0)}
		bs.lift = skel.get_bone_global_rest(skel.find_bone("upperleg.l")).origin.y * (leg - 1.0)
		skel.add_child(bs)
	elif skel and head_scale != 1.0:
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


func _build_foreign(model_name: String, weapons: Dictionary, rig_def: Dictionary) -> void:
	foreign = true
	_rig_def = rig_def
	var built := FoeRig.build(model_name, rig_def)
	model = built["root"]
	add_child(model)
	anim = built["anim"]
	anim.playback_default_blend_time = 0.12
	var skel: Skeleton3D = model.find_child("Skeleton3D", true, false)
	# Weapon keys are bone names on the foe's own skeleton.
	for slot in weapons:
		if skel == null or skel.find_bone(slot) < 0:
			continue
		var att := BoneAttachment3D.new()
		att.bone_name = slot
		skel.add_child(att)
		att.add_child(KK.prop(str(weapons[slot]) if str(weapons[slot]).begins_with("res://") else KK.WEAPON_DIR + str(weapons[slot])))
	if merge_parts and skel:
		_merge_parts(skel, model_name)
	_rim = Color(rig_def.get("rim_color", Color.WHITE))
	_rim_strength = float(rig_def.get("rim", 0.0))
	_eyes = Color(0, 0, 0, 0)
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
			if foreign:
				var lit := FoeRig.lit(src, _rim, _rim_strength)
				if lit:
					mi.set_surface_override_material(s, lit)
				continue
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
				# Our dark models carry a metal and roughness mask beside their swatches.
				var mask_path := tex.resource_path.get_basename() + "_mask.png"
				if tex.resource_path.ends_with("dark_texture.png") and ResourceLoader.exists(mask_path):
					m.set_shader_parameter("mask_tex", load(mask_path))
				_mats[key] = m
			mi.set_surface_override_material(s, _mats[key])


## Swaps the character texture for a recoloured one (DB.SKINS) and shades it
## clean: `polish` is the glossy, rim-lit grade, `veins` the glowing seams in
## `accent`, `eyes` the skull's eye glow. The skin carries the colour, so
## nothing is tinted. Materials are shared by skin and source texture, so
## every foe of a skin still batches; weapons keep their own texture.
func reskin(sk: Dictionary) -> void:
	var tex_name := str(sk["tex"])
	var eyes: Color = sk["eyes"]
	for mi in _meshes:
		for s in mi.mesh.get_surface_count():
			var m := mi.get_surface_override_material(s) as ShaderMaterial
			if m == null:
				continue
			var base := m.get_shader_parameter("albedo_tex") as Texture2D
			if base == null or not str(base.resource_path).begins_with(KK.CHAR_DIR):
				continue
			var key := "%s|%s|%s|%s" % [tex_name, base.resource_path, eyes.to_html(), _rim.to_html()]
			if not _skins.has(key):
				var d := m.duplicate() as ShaderMaterial
				d.set_shader_parameter("albedo_tex", load(KK.CHAR_DIR + tex_name))
				d.set_shader_parameter("eye_glow", eyes)
				d.set_shader_parameter("roughness", float(sk["rough"]))
				_skins[key] = d
			mi.set_surface_override_material(s, _skins[key])
		mi.set_instance_shader_parameter("grade", Vector4(float(sk["polish"]), 0.0, float(sk["veins"]), 0.0))
		mi.set_instance_shader_parameter("accent", sk["accent"])


## Stops tracking the meshes under `root` (call before freeing it).
func forget(root: Node) -> void:
	for mi in KK.meshes(root):
		_meshes.erase(mi)


func mesh_list() -> Array[MeshInstance3D]:
	return _meshes


## The clip this actor's rig has for a combat clip name (KayKit rigs: itself).
func _clip(name_: String) -> String:
	if not foreign:
		return name_ if anim and anim.has_animation(name_) else ""
	return FoeRig.resolve(anim, name_, _rig_def, _clip_cache) if anim else ""


func play(name_: String, blend := -1.0, speed_ := 1.0, restart := false) -> void:
	if anim == null:
		return
	if foreign:
		var real := _clip(name_)
		if real == "":
			_pose_for(name_, restart)
			return
		# One state: callers compare names, so keep theirs, play the rig's.
		if name_ == cur_anim and not restart:
			anim.speed_scale = speed_
			return
		cur_anim = name_
		anim.speed_scale = speed_
		if restart and anim.current_animation == real:
			anim.stop()
		anim.play(real, blend)
		return
	if not anim.has_animation(name_):
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
	var n := _clip(name_)
	if n != "":
		return anim.get_animation(n).length
	return 1.0


## A rig with no clip for `name_` fakes a one-shot with the body springs.
func _pose_for(name_: String, restart: bool) -> void:
	if not restart and name_ == cur_anim:
		return
	cur_anim = name_
	match FoeRig.class_of(name_):
		"attack":
			squash(Vector3(-0.06, -0.04, 0.16))
		"cast", "taunt":
			squash(Vector3(-0.05, 0.12, -0.05))


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


## Hit feedback: a hard white flash (full for the first beat, then a quick
## fade) and a squash pop of the model. A crit holds the flash longer.
func hit_flash(crit := false) -> void:
	_flash_len = 0.17 if crit else 0.12
	flash_t = _flash_len
	set_flash(1.0)
	squash(Vector3(0.05, -0.09, 0.05) * (1.4 if crit else 1.0))


## A blow from the direction `dir` (world, the way it pushes): flash, squash
## and the body leans away along `dir`, harder for light actors and crits.
func hit_react(dir: Vector3, power := 1.0, crit := false) -> void:
	hit_flash(crit)
	if dir.length_squared() > 0.0001:
		lean(dir.normalized(), 0.13 * power * (1.35 if crit else 1.0))


## Kicks the squash/stretch spring. `offset` is a scale change in the model's
## axes (z is forward): (-0.06, -0.04, 0.16) is a lunge, (0.05, -0.09, 0.05) a hit.
func squash(offset: Vector3) -> void:
	if model == null:
		return
	_start_springs()
	_sq_v += offset * SPRING_IMPULSE


## Tips the model so its head moves along `dir` (world) by about `rad` radians.
func lean(dir: Vector3, rad: float) -> void:
	if model == null:
		return
	_start_springs()
	var l := dir.rotated(Vector3.UP, -rotation.y)
	_lean_v += Vector2(l.z, -l.x) * rad * SPRING_IMPULSE


## Back to the rest pose at once (a foe that just died stays where it fell).
func clear_springs() -> void:
	if _spring_on:
		_spring_on = false
		_sq = Vector3.ZERO
		_sq_v = Vector3.ZERO
		_lean = Vector2.ZERO
		_lean_v = Vector2.ZERO
		_sq_t = Vector3.ZERO
		_lean_t = Vector2.ZERO
		model.scale = _spring_base
		model.rotation = Vector3(0.0, model.rotation.y, 0.0)


## Holds the body in a pose: `sq` is a scale change in the model's axes (as
## squash), `lean_pose` the tip in radians (x: forward when positive, y: roll).
func hold_pose(sq: Vector3, lean_pose: Vector2) -> void:
	if model == null:
		return
	_start_springs()
	_sq_t = sq
	_lean_t = lean_pose


## Lets go of a held pose; the springs carry the body back to rest.
func release_pose() -> void:
	_sq_t = Vector3.ZERO
	_lean_t = Vector2.ZERO


func _start_springs() -> void:
	if not _spring_on:
		_spring_on = true
		_spring_base = model.scale


func _tick_springs(dt: float) -> void:
	var h := minf(dt, 1.0 / 30.0)
	_sq_v += (-SPRING_K * (_sq - _sq_t) - SPRING_C * _sq_v) * h
	_sq += _sq_v * h
	_lean_v += (-SPRING_K * (_lean - _lean_t) - SPRING_C * _lean_v) * h
	_lean += _lean_v * h
	if _sq_t == Vector3.ZERO and _lean_t == Vector2.ZERO and _sq.length_squared() + _sq_v.length_squared() * 0.0025 < 0.000004 and _lean.length_squared() + _lean_v.length_squared() * 0.0025 < 0.000004:
		_spring_on = false
		_sq = Vector3.ZERO
		_sq_v = Vector3.ZERO
		_lean = Vector2.ZERO
		_lean_v = Vector2.ZERO
		model.scale = _spring_base
		model.rotation = Vector3(0.0, model.rotation.y, 0.0)
		return
	model.scale = _spring_base * (Vector3.ONE + _sq)
	model.rotation = Vector3(_lean.x, model.rotation.y, _lean.y)


func tick_common(dt: float) -> void:
	if flash_t > 0.0:
		flash_t -= dt
		# Full white for the first beat, then a quick fade.
		var hold := _flash_len - 0.06
		if flash_t > hold:
			set_flash(1.0)
		else:
			set_flash(clampf(flash_t / maxf(hold, 0.01), 0.0, 1.0))
	if _spring_on and model:
		_tick_springs(dt)
	if knock.length_squared() > 0.0001:
		position += knock * dt
		knock = knock.move_toward(Vector3.ZERO, 26.0 / t_slide * dt)
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
