class_name Unit
extends Node3D

var species := ""
var form := "base"
var team := 0
var stats := {}
var hp := 1.0
var max_hp := 1.0
var cool := 0.2
var dead := false
var dying := false
var structure := false
var lane_x := 0.0
var match_ref: Node
var animator: CritterAnimator
var visual: Node3D
var moving := false
var target: Unit
var retarget := 0.0
var attack_lock := 0.0
var slow_t := 0.0
var slow_amt := 0.0
var burn_t := 0.0
var burn_dps := 0.0
var aura_tick := 0.0
var flash_t := 0.0
var flash_mats: Array = []
var bar_root: Node3D
var bar_fill: MeshInstance3D
var _facing := Vector3(0, 0, 1)


func configure(p_stats: Dictionary, p_team: int, p_match: Node) -> void:
	stats = p_stats
	team = p_team
	match_ref = p_match
	species = str(stats.get("species", species))
	form = str(stats.get("form", form))
	structure = bool(stats.get("structure", false))
	max_hp = float(stats["hp"])
	hp = max_hp
	lane_x = -2.55 if position.x < 0.15 else 2.55


func build_visual() -> void:
	visual = Node3D.new()
	add_child(visual)
	var model: Node3D
	if structure:
		model = match_ref.arena.packed("den" if species == "den" else "burrow").instantiate()
		visual.rotation.y = PI if team == 0 else 0.0
	else:
		model = match_ref.arena.packed("%s_%s" % [species, form]).instantiate()
	visual.scale = Vector3.ONE * (1.28 if structure else 2.05)
	visual.add_child(model)
	var tint := Color(1.04, 0.98, 0.92) if team == 0 else Color(0.86, 0.92, 1.08)
	var flag := Color("ffb15a") if team == 0 else Color("9eb6f2")
	flash_mats = StyleLib.stylize(model, 0.02 if structure else 0.013, tint, flag, true)
	if not structure:
		animator = CritterAnimator.new()
		animator.bind(model, str(stats.get("gait", "walk")))
		animator.pop()
		var shadow := MeshInstance3D.new()
		var quad := QuadMesh.new()
		var rad := float(stats["radius"])
		quad.size = Vector2(rad * 2.3, rad * 1.7)
		shadow.mesh = quad
		shadow.rotation.x = -PI * 0.5
		shadow.position.y = 0.03
		var blob := Color(1.0, 0.55, 0.25, 0.4) if team == 0 else Color(0.45, 0.55, 0.95, 0.42)
		shadow.material_override = StyleLib.blob_material(blob)
		shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(shadow)
		if form != "base":
			var ring := MeshInstance3D.new()
			var tor := TorusMesh.new()
			tor.inner_radius = rad * 0.7
			tor.outer_radius = rad * 0.88
			ring.mesh = tor
			ring.position.y = 0.05
			ring.material_override = StyleLib.flat_material(Roster.habitat_color(form), 1.1)
			ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(ring)
	_build_bar()
	_place_height()


func tick(dt: float) -> void:
	if dead:
		return
	if dying:
		if animator:
			animator.tick(dt, false)
		_decay_flash(dt)
		return
	_statuses(dt)
	if hp <= 0.0:
		die()
		return
	var haste := 1.0 - slow_amt if slow_t > 0.0 else 1.0
	haste *= 1.0 + float(match_ref.speed_bonus(self))
	cool = maxf(0.0, cool - dt * haste)
	attack_lock = maxf(0.0, attack_lock - dt)
	if structure:
		_shoot()
	elif bool(stats.get("support", false)):
		_support(dt)
	else:
		_fight(dt)
	if animator:
		var hover := 1.55 if bool(stats.get("flying", false)) else 0.0
		visual.position.y = hover + sin(Time.get_ticks_msec() * 0.004) * (0.05 if hover > 0.0 else 0.0)
		animator.tick(dt, moving)
	_decay_flash(dt)
	_update_bar()


func flat_to(other: Unit) -> float:
	return Vector2(position.x, position.z).distance_to(Vector2(other.position.x, other.position.z))


func apply_slow(amount: float, time: float) -> void:
	if amount >= slow_amt or slow_t <= 0.0:
		slow_amt = amount
	slow_t = maxf(slow_t, time)


func apply_burn(dps: float, time: float) -> void:
	burn_dps = maxf(burn_dps, dps)
	burn_t = maxf(burn_t, time)


func receive_heal(amount: float) -> void:
	hp = minf(max_hp, hp + amount)
	flash_t = maxf(flash_t, 0.08)


func flash() -> void:
	flash_t = 0.12


func die() -> void:
	if dying or dead:
		return
	dying = true
	target = null
	match_ref.announce_death(self)
	if animator:
		animator.play_death()
		get_tree().create_timer(0.7).timeout.connect(func() -> void: dead = true)
	else:
		var tw := create_tween()
		tw.tween_property(visual, "scale", Vector3(0.15, 0.15, 0.15), 0.45)
		tw.parallel().tween_property(visual, "position:y", -0.35, 0.45)
		tw.tween_callback(func() -> void: dead = true)


func _statuses(dt: float) -> void:
	if slow_t > 0.0:
		slow_t -= dt
		if slow_t <= 0.0:
			slow_amt = 0.0
	if burn_t > 0.0:
		burn_t -= dt
		hp -= burn_dps * dt
	if float(stats.get("aura_dps", 0.0)) > 0.0:
		aura_tick += dt
		if aura_tick >= 0.25:
			aura_tick = 0.0
			match_ref.aura_tick(self)


func _support(dt: float) -> void:
	var hurt: Unit = match_ref.best_heal_target(self)
	if hurt:
		target = hurt
		_face(hurt.position - position)
		if flat_to(hurt) <= float(stats["heal_radius"]):
			moving = false
			if cool <= 0.0 and hurt.hp < hurt.max_hp - 0.5:
				cool = float(stats["period"])
				hurt.receive_heal(float(stats["heal"]))
				if animator:
					animator.play_attack()
				match_ref.arena.burst(hurt.position, Color("b6f0a4"), false)
			_place_height()
			return
		_step(hurt.position, dt)
		return
	_fight(dt)


func _fight(dt: float) -> void:
	retarget -= dt
	if retarget <= 0.0 or target == null or not is_instance_valid(target) or target.dying or target.dead:
		retarget = 0.22
		target = match_ref.pick_target(self)
	if target and is_instance_valid(target) and not target.dying:
		_face(target.position - position)
		var reach := float(stats["range"]) + float(target.stats["radius"]) * 0.3
		if flat_to(target) <= reach and _can_hit(target):
			moving = false
			_try_swing(target)
			_place_height()
			return
		_step(target.position, dt)
		return
	var goal: Vector3 = match_ref.enemy_anchor(team)
	goal.x = lane_x
	_face(goal - position)
	_step(goal, dt)


func _shoot() -> void:
	target = match_ref.pick_target(self)
	if target == null:
		return
	_face(target.position - position)
	if flat_to(target) <= float(stats["range"]) and cool <= 0.0:
		_try_swing(target)


func _try_swing(other: Unit) -> void:
	if cool > 0.0 or attack_lock > 0.0 or dying:
		return
	if not _can_hit(other):
		return
	cool = float(stats["period"])
	attack_lock = minf(0.42, float(stats["period"]) * 0.7)
	if animator:
		animator.play_attack()
	var delay := minf(0.16, attack_lock * 0.45)
	var snapshot := other
	get_tree().create_timer(delay).timeout.connect(func() -> void:
		if dying or dead:
			return
		if not is_instance_valid(snapshot) or snapshot.dead:
			return
		match_ref.deliver_attack(self, snapshot)
	)


func _can_hit(other: Unit) -> bool:
	if other.structure and structure:
		return false
	if bool(other.stats.get("flying", false)) and not bool(stats.get("hits_air", false)):
		return false
	return true


func _step(goal: Vector3, dt: float) -> void:
	var delta := Vector3(goal.x - position.x, 0, goal.z - position.z)
	var dist := delta.length()
	if dist < 0.08:
		moving = false
		_place_height()
		return
	var step: float = float(stats["speed"]) * dt
	if slow_t > 0.0:
		step *= 1.0 - slow_amt
	step *= 1.0 + float(match_ref.speed_bonus(self))
	if step > dist:
		step = dist
	position += delta.normalized() * step
	position.x = clampf(position.x, -4.55, 4.55)
	position.z = clampf(position.z, -8.7, 8.7)
	moving = true
	_place_height()


func _face(dir: Vector3) -> void:
	if dir.length() < 0.02 or visual == null or animator == null:
		return
	_facing = Vector3(dir.x, 0, dir.z).normalized()
	var target_yaw := animator.face_yaw(_facing)
	var diff := wrapf(target_yaw - visual.rotation.y, -PI, PI)
	visual.rotation.y += diff * 0.2


func _place_height() -> void:
	var flying := bool(stats.get("flying", false))
	position.y = match_ref.arena.surface_y(position.x, position.z, false)
	if visual and not structure:
		visual.position.y = 1.55 if flying else 0.0


func _build_bar() -> void:
	bar_root = Node3D.new()
	var lift := 2.15 if structure else float(stats["radius"]) * 2.6 + 1.15
	if bool(stats.get("flying", false)):
		lift += 1.7
	bar_root.position = Vector3(0, lift, 0)
	var width := 1.7 if structure else 0.95
	var bg := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(width, 0.16 if structure else 0.13)
	bg.mesh = q
	bg.material_override = StyleLib.flat_material(Color(0.16, 0.1, 0.1, 0.82), 0.2)
	bg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bar_fill = MeshInstance3D.new()
	bar_fill.mesh = q
	var col := Color("ffb15a") if team == 0 else Color("9eb6f2")
	bar_fill.material_override = StyleLib.flat_material(col, 0.4)
	bar_fill.position = Vector3(0, 0, 0.02)
	bar_fill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bar_root.add_child(bg)
	bar_root.add_child(bar_fill)
	add_child(bar_root)
	_orient_bar()
	bar_root.visible = structure


func _update_bar() -> void:
	if bar_root == null:
		return
	var k := clampf(hp / max_hp, 0.0, 1.0)
	bar_fill.scale.x = maxf(k, 0.02)
	bar_fill.position.x = -(1.0 - k) * (0.85 if structure else 0.475)
	bar_root.visible = structure or hp < max_hp - 0.4
	_orient_bar()


func _orient_bar() -> void:
	if bar_root == null or match_ref == null:
		return
	bar_root.look_at(match_ref.arena.camera.global_position, Vector3.UP)
	bar_root.rotate_y(PI)


func _decay_flash(dt: float) -> void:
	if flash_t > 0.0:
		flash_t = maxf(0.0, flash_t - dt)
	var f := clampf(flash_t / 0.12, 0.0, 1.0)
	for mat in flash_mats:
		if mat:
			mat.set_shader_parameter("flash", f)
