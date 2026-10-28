extends "res://src/hunt/foe_brain.gd"
## Wail Wraith and Cinder Imp: ranged foes that keep their distance and shoot
## a lane-telegraphed bolt. The wraith flies (`fly`: crosses water and thin ice)
## and strafes; the imp is `perch`ed: it plants itself and shoots, and only
## steps back if the hero closes in. If the arena lists `perches` (Vector3s,
## stilt platforms) a perched foe walks to the nearest one in range first.

var _perch := Vector3.INF


func think(dt: float, to: Vector3, dist: float) -> void:
	match st:
		"move":
			_move(dt, to, dist)
		"windup":
			if t < float(e.def["windup"]) - 0.3:
				e.aim_yaw = Actor.yaw_to(e.position, e._lead_pos(0.3))
				if teles.size() > 0 and is_instance_valid(teles[0]):
					(teles[0] as Node3D).rotation.y = e.aim_yaw
					(teles[0] as Node3D).position = e.flat_pos() + Actor.dir_of(e.aim_yaw) * e.reach * 0.5 + Vector3(0, 0.04, 0)
			e.face(e.aim_yaw, dt, 10.0)
			if t >= float(e.def["windup"]):
				_shoot()
		"recover":
			face_hero(dt)
			if t >= 0.4:
				go("move", "chase")


func _move(dt: float, to: Vector3, dist: float) -> void:
	var keep := float(cfg.get("keep", 7.0))
	var radial := to / maxf(dist, 0.01)
	var want := Vector3.ZERO
	if bool(cfg.get("perch", false)):
		if _perch == Vector3.INF:
			_perch = _pick_perch()
		if _perch != Vector3.INF and e.flat_pos().distance_to(_perch) > 0.8 and dist > keep * 0.5:
			walk((_perch - e.flat_pos()).normalized(), spd(), dt, e.flat_pos().distance_to(_perch), true)
		elif dist < keep * 0.55:
			walk(-radial, spd(), dt, dist, true)
		elif dist > e.reach * 0.95:
			walk(radial, spd(), dt, dist)
		else:
			play("idle", 0.2)
			face_hero(dt)
	else:
		if dist > e.reach * 0.95 or dist > keep * 1.3:
			want = radial
		elif dist < keep * 0.7:
			want = -radial
		else:
			want = radial.cross(Vector3.UP) * e.strafe * 0.6
		walk(want, spd(), dt, dist, true)
	if dist <= e.reach and cd <= 0.0 and h.on_screen(e.position, 1.0):
		_wind()


func _pick_perch() -> Vector3:
	var list: Variant = h.arena.get("perches")
	var best := Vector3.INF
	if list is Array:
		var hp := h.hero.flat_pos()
		var bd := INF
		for p: Vector3 in list:
			var d := p.distance_to(hp)
			if d > float(cfg.get("keep", 7.0)) * 0.6 and d < e.reach * 0.9 and d < bd:
				bd = d
				best = p
	return best


func _wind() -> void:
	var w := float(e.def["windup"]) * (0.75 if "swift" in e.affixes else 1.0)
	go("windup", "windup")
	e.aim_yaw = yaw_hero()
	swing(w)
	e.lean(-Actor.dir_of(e.aim_yaw), 0.08)
	tele(2, e.flat_pos(), e.aim_yaw, Vector2(0.35, e.reach), w)


func _shoot() -> void:
	clear_teles()
	lunge_pose(Actor.dir_of(e.aim_yaw))
	var n := 3 if h.ai() >= 1.5 else int(cfg.get("shots", 1))
	for i in n:
		var dir := Actor.dir_of(e.aim_yaw + (i - (n - 1) * 0.5) * deg_to_rad(14.0))
		h.spawn_proj(str(e.def.get("proj", "bolt")), e.flat_pos() + dir * 0.6 + Vector3(0, hover, 0), dir * float(e.def["proj_speed"]), e.dmg, 1, e)
	Sfx.play("atk_archer", -9.0, 0.8)
	cd = float(e.def["cooldown"]) * randf_range(0.85, 1.15)
	go("recover", "recover")
