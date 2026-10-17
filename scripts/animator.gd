class_name CritterAnimator
extends RefCounted

var model: Node3D
var rig: Node3D
var parts := {}
var rest_pos := {}
var rest_rot := {}
var rest_scale := {}
var horns: Array = []
var ears: Array = []
var horn_rest: Array = []
var ear_rest: Array = []
var local_forward := Vector3(0, 0, -1)
var rest_rig_scale := Vector3.ONE
var rest_rig_pos := Vector3.ZERO
var rest_rig_rot := Vector3.ZERO
var phase := 0.0
var attack_t := -1.0
var hit_t := -1.0
var death_t := -1.0
var pop_t := -1.0
var gait := "walk"
var blink_clock := 0.0


func bind(root: Node3D, gait_name: String) -> void:
	model = root
	gait = gait_name
	rig = _find_exact(root, "Rig")
	if rig == null:
		rig = root
	for name in ["Body", "Head", "Snout", "Tail", "TailMid", "TailTip", "Quills", "WingL", "WingR", "LegFL", "LegFR", "LegBL", "LegBR", "ScleraL", "ScleraR", "PupilL", "PupilR"]:
		var node := _find_exact(root, name)
		if node:
			_remember(name, node)
	horns = _find_prefix(root, "Horn")
	ears = _find_prefix(root, "Ear")
	for node in horns:
		horn_rest.append((node as Node3D).rotation)
	for node in ears:
		ear_rest.append((node as Node3D).rotation)
	if rig:
		rest_rig_scale = rig.scale
		rest_rig_pos = rig.position
		rest_rig_rot = rig.rotation
	var marker := _find_exact(root, "Forward")
	if marker and model:
		var local: Vector3 = model.to_local(marker.global_position)
		local.y = 0.0
		if local.length() > 0.01:
			local_forward = local.normalized()
	blink_clock = randf() * 2.5


func face_yaw(dir: Vector3) -> float:
	var flat := Vector3(dir.x, 0, dir.z)
	if flat.length() < 0.001:
		return 0.0
	flat = flat.normalized()
	return atan2(flat.x, flat.z) - atan2(local_forward.x, local_forward.z)


func play_attack() -> void:
	attack_t = 0.0


func play_hit() -> void:
	hit_t = 0.0


func play_death() -> void:
	death_t = 0.0


func pop() -> void:
	pop_t = 0.0


func tick(dt: float, moving: bool) -> void:
	phase += dt
	blink_clock += dt
	if death_t >= 0.0:
		death_t += dt
		_apply_death()
		return
	if attack_t >= 0.0:
		attack_t += dt
		if attack_t > 0.45:
			attack_t = -1.0
	if hit_t >= 0.0:
		hit_t += dt
		if hit_t > 0.28:
			hit_t = -1.0
	if pop_t >= 0.0:
		pop_t += dt
		if pop_t > 0.38:
			pop_t = -1.0
	_apply(moving)


func _apply(moving: bool) -> void:
	var rate := 6.2
	match gait:
		"waddle":
			rate = 8.4
		"stomp":
			rate = 4.0
		"hop":
			rate = 5.2
		"fly":
			rate = 3.2
	var swing := sin(phase * rate)
	var bob := absf(sin(phase * rate))
	if gait == "fly":
		bob = sin(phase * rate) * 0.5 + 0.5
	elif gait == "hop":
		bob = maxf(0.0, sin(phase * rate))
	elif not moving and attack_t < 0.0:
		bob = absf(sin(phase * 1.6)) * 0.35
		swing *= 0.15

	var breathe := 1.0 + sin(phase * 2.1) * 0.025
	var pop_scale := 1.0
	if pop_t >= 0.0:
		var u := clampf(pop_t / 0.38, 0.0, 1.0)
		pop_scale = lerp(0.25, 1.0, clampf(u * 1.35, 0.0, 1.0))
		pop_scale *= 1.0 + sin(u * PI) * 0.12
	if rig:
		rig.scale = rest_rig_scale * Vector3(breathe * pop_scale, (2.0 - breathe) * pop_scale, breathe * pop_scale)
		rig.position = rest_rig_pos
		rig.rotation = rest_rig_rot

	var lunge := 0.0
	var crouch := 0.0
	if attack_t >= 0.0:
		var u := clampf(attack_t / 0.45, 0.0, 1.0)
		if u < 0.32:
			var k := u / 0.32
			lunge = -sin(k * PI) * 0.1
			crouch = sin(k * PI) * 0.08
		else:
			var k := (u - 0.32) / 0.68
			lunge = sin(k * PI) * 0.2
			crouch = -sin(k * PI) * 0.04
	if hit_t >= 0.0:
		lunge -= sin(clampf(hit_t / 0.28, 0.0, 1.0) * PI) * 0.08

	var body_bob := bob * (0.07 if gait == "hop" else 0.035)
	if gait == "fly":
		body_bob = sin(phase * 3.0) * 0.06
	_set_pos("Body", Vector3(0, body_bob - crouch, 0) + local_forward * lunge)
	_set_rot("Body", Vector3(lunge * 0.8, 0, swing * (0.08 if gait == "waddle" else 0.04)))

	var head_look := sin(phase * 1.3) * 0.08
	_set_rot("Head", Vector3(-lunge * 0.4 + sin(phase * 2.0) * 0.04, head_look, 0))
	_set_rot("Snout", Vector3(sin(phase * 3.0) * 0.05, 0, 0))

	if gait == "fly":
		var flap := sin(phase * 9.0) * (0.7 if attack_t >= 0.0 else 0.38)
		_set_rot("WingL", Vector3(0, flap, 0))
		_set_rot("WingR", Vector3(0, -flap, 0))
		_set_rot("LegFL", Vector3(0.2, 0, 0))
		_set_rot("LegFR", Vector3(0.2, 0, 0))
	elif gait == "hop":
		var tuck := bob * 0.8
		_set_rot("LegBL", Vector3(tuck, 0, 0.15))
		_set_rot("LegBR", Vector3(tuck, 0, -0.15))
		_set_rot("LegFL", Vector3(-swing * 0.4, 0, 0))
		_set_rot("LegFR", Vector3(swing * 0.4, 0, 0))
		_set_rot("WingL", Vector3(0, sin(phase * rate) * 0.2, 0))
		_set_rot("WingR", Vector3(0, -sin(phase * rate) * 0.2, 0))
	else:
		var amp := 0.55 if moving else 0.08
		if gait == "stomp":
			amp = 0.35 if moving else 0.05
		_set_rot("LegFL", Vector3(swing * amp, 0, 0))
		_set_rot("LegBR", Vector3(swing * amp, 0, 0))
		_set_rot("LegFR", Vector3(-swing * amp, 0, 0))
		_set_rot("LegBL", Vector3(-swing * amp, 0, 0))
		var flap2 := sin(phase * (6.0 if attack_t >= 0.0 else 2.4)) * (0.45 if attack_t >= 0.0 else 0.18)
		_set_rot("WingL", Vector3(0, flap2, 0))
		_set_rot("WingR", Vector3(0, -flap2, 0))

	var wag := sin(phase * (rate * 0.5 + 1.0))
	_set_rot("Tail", Vector3(0, wag * 0.28, wag * 0.08))
	_set_rot("TailMid", Vector3(0, wag * 0.35, 0))
	_set_rot("TailTip", Vector3(0, wag * 0.45, 0))

	if parts.has("Quills"):
		var pulse := 1.0 + sin(phase * 3.2) * 0.035
		if attack_t >= 0.0:
			pulse += sin(clampf(attack_t / 0.45, 0.0, 1.0) * PI) * 0.08
		parts["Quills"].scale = rest_scale["Quills"] * Vector3.ONE * pulse

	for i in ears.size():
		var twitch := sin(phase * 2.2 + float(i)) * 0.08
		if blink_clock > 2.6 and blink_clock < 2.85:
			twitch += 0.25
		(ears[i] as Node3D).rotation = ear_rest[i] + Vector3(twitch, 0, twitch * 0.4)
	for i in horns.size():
		var twitch := sin(phase * 1.4 + float(i) * 0.7) * 0.04
		(horns[i] as Node3D).rotation = horn_rest[i] + Vector3(0, 0, twitch)

	var blink := 1.0
	var cycle := fmod(blink_clock, 3.6)
	if cycle < 0.1:
		blink = 0.12
	for eye_name in ["ScleraL", "ScleraR"]:
		if parts.has(eye_name):
			var s: Vector3 = rest_scale[eye_name]
			parts[eye_name].scale = Vector3(s.x, s.y * blink, s.z)


func _apply_death() -> void:
	var u := clampf(death_t / 0.7, 0.0, 1.0)
	if rig:
		rig.rotation = rest_rig_rot + Vector3(0, 0, u * 1.45)
		rig.position = rest_rig_pos + Vector3(0, -u * 0.2, 0)
		var s := 1.0 - u * 0.25
		rig.scale = rest_rig_scale * Vector3(s, s * (1.0 - u * 0.4), s)


func _remember(name: String, node: Node3D) -> void:
	parts[name] = node
	rest_pos[name] = node.position
	rest_rot[name] = node.rotation
	rest_scale[name] = node.scale


func _set_rot(name: String, offset: Vector3) -> void:
	if not parts.has(name):
		return
	parts[name].rotation = rest_rot[name] + offset


func _set_pos(name: String, offset: Vector3) -> void:
	if not parts.has(name):
		return
	parts[name].position = rest_pos[name] + offset


func _find_exact(root: Node, name: String) -> Node3D:
	if root.name == name and root is Node3D:
		return root
	var found := root.find_child(name, true, false)
	return found as Node3D


func _find_prefix(root: Node, prefix: String) -> Array:
	var out: Array = []
	if str(root.name).begins_with(prefix) and root is Node3D:
		out.append(root)
	for node in root.find_children("*", "Node3D", true, false):
		if str(node.name).begins_with(prefix):
			out.append(node)
	return out
