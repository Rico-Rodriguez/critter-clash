extends "res://src/hunt/foe_brain.gd"
## Frost Wolf: a pack circles the hero at `circle` metres, then ONE wolf at a
## time shows a lane and lunges (`gap` seconds between lunges). The lunge is
## 8 m of fast run; on ice (terrain slide > 1) it overshoots and coasts, so a
## sidestep leaves the wolf sliding past. Wolves alone lunge sooner.

var _circle_t := 0.0
var _dash := Vector3.ZERO
var _hit := false
var _coast := 0.0
var _trail_t := 0.0
var _len := 8.0


var packmate := false


func ready() -> void:
	_circle_t = -randf() * 0.8
	# The director sends one wolf; it brings its pack (3 to 4 in all).
	if packmate:
		return
	var n := 0
	for f in h.foes:
		if f != e and f.alive and f.kind == e.kind and f.flat_pos().distance_to(e.flat_pos()) < 8.0:
			n += 1
	for i in maxi(0, randi_range(2, 3) - n):
		if h.foes.size() >= Hunt.MAX_FOES:
			break
		var a := TAU * (i + 0.5) / 3.0 + randf() * 0.5
		var mate: Enemy = h.spawn_foe(e.kind, h.arena.resolve(e.flat_pos() + Vector3(sin(a), 0, cos(a)) * 1.8, 0.5))
		var b := FoeBrains.of(mate)
		if b != null:
			b.packmate = true


func think(dt: float, to: Vector3, dist: float) -> void:
	match st:
		"move":
			_circle(dt, to, dist)
		"windup":
			if t < float(e.def["windup"]) - 0.2:
				e.aim_yaw = Actor.yaw_to(e.position, e._lead_pos(0.3))
				if teles.size() > 0 and is_instance_valid(teles[0]):
					(teles[0] as Node3D).rotation.y = e.aim_yaw
					(teles[0] as Node3D).position = e.flat_pos() + Vector3(0, 0.04, 0)
			e.face(e.aim_yaw, dt, 12.0)
			if t >= float(e.def["windup"]):
				_launch()
		"dash":
			_run(dt)
		"recover":
			if _coast > 0.0:
				e.position += _dash * _coast * dt
				_coast = maxf(_coast - 11.0 * dt, 0.0)
			if t >= 0.75:
				go("move", "chase")


func _circle(dt: float, to: Vector3, dist: float) -> void:
	_circle_t += dt
	var ring := float(cfg.get("circle", 5.5))
	var radial := to / maxf(dist, 0.01)
	var tang := radial.cross(Vector3.UP) * e.strafe
	var want := tang
	if dist > ring + 1.0:
		want = (radial * 1.0 + tang * 0.35).normalized()
	elif dist < ring - 1.2:
		want = (-radial * 0.6 + tang).normalized()
	walk(want, spd() * 0.9, dt, dist, true)
	if cd <= 0.0 and _circle_t >= 1.3 and dist > 2.4 and dist < float(cfg.get("lunge_len", 8.0)) + 1.0 and _may_lunge():
		_wind()


## One wolf in its windup or lunge at a time, and a beat after the last one.
func _may_lunge() -> bool:
	for f in h.foes:
		if f == e or not f.alive or f.kind != e.kind:
			continue
		var b := FoeBrains.of(f)
		if b != null and (b.st == "windup" or b.st == "dash" or (b.st == "recover" and b.t < float(cfg.get("gap", 0.9)))):
			return false
	return true


func _wind() -> void:
	var w := float(e.def["windup"]) * (0.75 if "swift" in e.affixes else 1.0)
	go("windup", "windup")
	e.aim_yaw = Actor.yaw_to(e.position, e._lead_pos(0.3))
	_len = float(cfg.get("lunge_len", 8.0))
	play("idle", 0.1)
	e.squash(Vector3(0.08, -0.12, -0.06))
	e.lean(-Actor.dir_of(e.aim_yaw), 0.1)
	tele(2, e.flat_pos(), e.aim_yaw, Vector2(1.0, _len), w)
	Sfx.play("enemy_windup", -6.0, 1.6)


func _launch() -> void:
	clear_teles()
	_dash = Actor.dir_of(e.aim_yaw)
	_hit = false
	var tr := terrain()
	var slide := float(tr.slide_at(e.flat_pos())) if tr != null else 1.0
	_len *= slide
	go("dash", "dash")
	play("run", 0.05, 2.2)
	lunge_pose(_dash)
	Sfx.play("charge", -8.0, 1.6)


func _run(dt: float) -> void:
	var step := 19.0 * dt
	e.position += _dash * step
	e.position = h.arena.resolve(e.position, e.radius)
	_len -= step
	_trail_t -= dt
	if _trail_t <= 0.0:
		_trail_t = 0.2
		h.fx.puff(e.flat_pos(), Color(0.8, 0.9, 1.0, 0.4), 1, 0.3, 0.8)
		if e.def.has("trail") and h.biome != null:
			h.biome.trail(e)
	if not _hit and e.flat_pos().distance_to(h.hero.flat_pos()) < e.radius + h.hero.radius + 0.25:
		_hit = true
		hurt_hero(1.0, 0.3)
		h.hero.push(_dash, 8.0)
	if _len <= 0.0 or t > 0.9:
		var tr := terrain()
		var slide := float(tr.slide_at(e.flat_pos())) if tr != null else 1.0
		_coast = 19.0 * 0.35 * (slide - 1.0) / 0.4 if slide > 1.05 else 0.0
		cd = float(e.def["cooldown"]) * randf_range(0.9, 1.2)
		_circle_t = 0.0
		go("recover", "recover")
		play("idle", 0.2)
