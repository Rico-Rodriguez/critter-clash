class_name CritterAnimator
extends RefCounted

var model: Node3D
var player: AnimationPlayer
var clips := {}
var local_forward := Vector3(0, 0, -1)
var rest_scale := Vector3.ONE
var phase := 0.0
var attack_t := -1.0
var hit_t := -1.0
var death_t := -1.0
var pop_t := -1.0
var gait := "walk"
var current := ""


func bind(root: Node3D, gait_name: String) -> void:
	model = root
	gait = gait_name
	rest_scale = root.scale
	player = _find_player(root)
	var marker := root.find_child("Forward", true, false)
	if marker and model:
		var local: Vector3 = model.to_local(marker.global_position)
		local.y = 0.0
		if local.length() > 0.01:
			local_forward = local.normalized()
	_index_clips()
	_play("idle", true)


func face_yaw(dir: Vector3) -> float:
	var flat := Vector3(dir.x, 0, dir.z)
	if flat.length() < 0.001:
		return 0.0
	flat = flat.normalized()
	return atan2(flat.x, flat.z) - atan2(local_forward.x, local_forward.z)


func play_attack() -> void:
	attack_t = 0.0
	if not _play("attack", false):
		_play("gesture", false)


func play_hit() -> void:
	hit_t = 0.0
	_play("hit", false)


func play_death() -> void:
	death_t = 0.0
	_play("death", false)


func pop() -> void:
	pop_t = 0.0


func tick(dt: float, moving: bool) -> void:
	phase += dt
	if death_t >= 0.0:
		death_t += dt
		_juice(1.0)
		if not clips.has("death"):
			var u := clampf(death_t / 0.7, 0.0, 1.0)
			model.rotation.z = u * 1.4
			model.position.y = -u * 0.25
		return
	if attack_t >= 0.0:
		attack_t += dt
		if attack_t > 0.55:
			attack_t = -1.0
	if hit_t >= 0.0:
		hit_t += dt
		if hit_t > 0.32:
			hit_t = -1.0
	if pop_t >= 0.0:
		pop_t += dt
		if pop_t > 0.38:
			pop_t = -1.0
	if attack_t < 0.0 and hit_t < 0.0:
		var want := "idle"
		if not clips.has("idle") and clips.has("fly"):
			want = "fly"
		if moving:
			if gait == "fly" and clips.has("run"):
				want = "run"
			elif gait == "fly" and clips.has("fly"):
				want = "fly"
			elif clips.has("walk"):
				want = "walk"
			elif clips.has("run"):
				want = "run"
		_play(want, true)
	_juice(1.0)


func _juice(extra: float) -> void:
	if model == null:
		return
	var breathe := 1.0 + sin(phase * 2.2) * 0.018 * extra
	var pop_scale := 1.0
	if pop_t >= 0.0:
		var u := clampf(pop_t / 0.38, 0.0, 1.0)
		pop_scale = lerp(0.2, 1.0, clampf(u * 1.4, 0.0, 1.0))
		pop_scale *= 1.0 + sin(u * PI) * 0.1
	var hit_squash := 1.0
	if hit_t >= 0.0:
		hit_squash = 1.0 - sin(clampf(hit_t / 0.32, 0.0, 1.0) * PI) * 0.08
	model.scale = rest_scale * Vector3(breathe, (2.0 - breathe) * pop_scale * hit_squash, breathe)


func _play(kind: String, loop: bool) -> bool:
	if player == null or not clips.has(kind):
		return false
	if loop and current == kind and player.is_playing():
		return true
	current = kind
	player.speed_scale = 1.15 if kind == "walk" else 1.0
	player.play(clips[kind])
	return true


func _index_clips() -> void:
	if player == null:
		return
	for name in player.get_animation_list():
		var low := name.to_lower()
		var kind := ""
		if "death" in low:
			kind = "death"
		elif "hit" in low:
			kind = "hit"
		elif "attack" in low or "punch" in low or "headbutt" in low or "bite" in low or "gesture" in low:
			kind = "attack"
		elif "fast_fly" in low or "gallop" in low:
			kind = "run"
		elif "fly" in low and "idle" in low:
			kind = "idle"
		elif "fly" in low:
			kind = "fly"
		elif ("walk" in low or "run" in low or ("swim" in low and "idle" not in low)) and "idle" not in low:
			kind = "walk"
		elif "idle" in low:
			kind = "idle"
		if kind == "" or clips.has(kind):
			continue
		clips[kind] = name
		var anim := player.get_animation(name)
		if anim:
			if kind in ["idle", "walk", "run", "fly"]:
				anim.loop_mode = Animation.LOOP_LINEAR
			else:
				anim.loop_mode = Animation.LOOP_NONE


func _find_player(root: Node) -> AnimationPlayer:
	if root is AnimationPlayer:
		return root
	var found := root.find_children("*", "AnimationPlayer", true, false)
	if found.is_empty():
		return null
	return found[0]
