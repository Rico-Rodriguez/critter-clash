extends "res://src/hunt/foe_brain.gd"
## Bogfin and Bog Frog: foes that live under the bog. With a terrain grid a
## foe over a BOG cell is submerged: `e.state == "spawn"` (untouchable, model
## sunk), creeping toward the hero over bog cells only, a ripple on the surface.
## Inside `trigger` metres, ready to strike:
##   bogfin   a bubbling ring on the ground for 0.7 s, then it surfaces and
##            bursts out (a hit if the hero is still in the ring), then fights
##            as a melee foe and dives again when the hero is far.
##   frog     (`leap`) a lane on the ground for `windup`, then it leaps the lane
##            and lands; on the surface it moves in short quick hops.
## Fire: if the cell it hides in is burning or about to, it surfaces and runs
## to the nearest safe ground. Without a terrain grid, nothing submerges: the
## bogfin is a melee foe and the frog a hopper that leaps.

var _leap := false
var _from := Vector3.ZERO
var _to := Vector3.ZERO
var _hop_t := 0.0
var _hit := false
var _far_t := 0.0
var _ripple := 0.0
var _flee_to := Vector3.ZERO


func setup(e_: Enemy) -> void:
	super.setup(e_)
	_leap = bool(cfg.get("leap", false))


func ready() -> void:
	if _can_hide():
		_dive(true)


func _bog_at(p: Vector3) -> bool:
	var tr := terrain()
	return tr != null and tr.kind_at(p) == Terrain.BOG


func _can_hide() -> bool:
	return _bog_at(e.flat_pos())


func _fire_near(p: Vector3) -> bool:
	var tr := terrain()
	if tr == null:
		return false
	var c: Vector2i = tr.cell_of(p)
	if tr.kind_of(c) == Terrain.BURNING or tr.warned(c):
		return true
	for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if tr.kind_of(c + d) == Terrain.BURNING:
			return true
	return false


func think(dt: float, to: Vector3, dist: float) -> void:
	match st:
		"sub":
			_creep(dt, to, dist)
		"bubble":
			if _fire_near(e.flat_pos()):
				_flee()
			elif t >= (float(e.def["windup"]) if _leap else 0.7):
				clear_teles()
				if _leap:
					_start_leap()
				else:
					_burst()
		"leap":
			var u := clampf(t / 0.5, 0.0, 1.0)
			e.position = _from.lerp(_to, u)
			e.position.y = _from.y
			e.model.position.y = sin(u * PI) * 1.5
			if not _hit and u > 0.6 and e.flat_pos().distance_to(h.hero.flat_pos()) < e.radius + h.hero.radius + 0.3:
				_hit = true
				hurt_hero(1.0, 0.3)
				h.hero.push((h.hero.flat_pos() - e.flat_pos()).normalized(), 8.0)
			if u >= 1.0:
				_land()
		"rise":
			var k := clampf(t / 0.35, 0.0, 1.0)
			e.model.position.y = lerpf(_sink_y, 0.0, k)
			if k >= 1.0:
				e.model.position.y = 0.0
				go("move", "chase")
		"flee":
			var away := (_flee_to - e.flat_pos())
			if away.length() < 0.6 or t > 2.5:
				go("move", "chase")
			else:
				walk(away.normalized(), spd() * 1.3, dt, away.length(), false)
		"move":
			if _leap:
				_hop(dt, to, dist)
			else:
				_fight(dt, to, dist)
			if _fire_near(e.flat_pos()):
				_flee()
				return
			# Far from the hero and over bog: slip under again.
			_far_t = _far_t + dt if dist > float(cfg.get("trigger", 3.6)) + 2.5 and _can_hide() else 0.0
			if _far_t > float(cfg.get("dive_after", 4.0)):
				_dive(false)
		"windup", "recover":
			melee(dt, to, dist)


func _fight(dt: float, to: Vector3, dist: float) -> void:
	melee(dt, to, dist)


## The frog: quick hops (a burst of speed, then a pause), a leap when in range.
func _hop(dt: float, to: Vector3, dist: float) -> void:
	_hop_t += dt
	var radial := to / maxf(dist, 0.01)
	if cd <= 0.0 and dist < float(cfg.get("trigger", 6.0)) and dist > 2.4:
		_aim_leap(dist)
		return
	var cycle := 0.7
	if fmod(_hop_t, cycle) < 0.45:
		var side := radial.cross(Vector3.UP) * e.strafe * 0.35
		walk((radial + side).normalized(), spd() * 1.8, dt, dist)
		e.model.position.y = sin(fmod(_hop_t, cycle) / 0.45 * PI) * 0.45
	else:
		e.model.position.y = 0.0
		play("idle", 0.1)
		face_hero(dt)
	if dist <= e.reach + h.hero.radius + 0.15 and cd <= 0.0:
		e.model.position.y = 0.0
		start_swing()


func _creep(dt: float, to: Vector3, dist: float) -> void:
	if _fire_near(e.flat_pos()):
		_flee()
		return
	var radial := to / maxf(dist, 0.01)
	var step := radial * spd() * 0.8 * dt
	var next := e.flat_pos() + step
	if _bog_at(next):
		e.position += step
		e.face(atan2(radial.x, radial.z), dt, 8.0)
	_ripple -= dt
	if _ripple <= 0.0:
		_ripple = 0.45
		h.fx.puff(e.flat_pos(), Color(0.45, 0.4, 0.25, 0.5), 1, 0.25, 0.4)
	if cd <= 0.0 and dist <= float(cfg.get("trigger", 3.6)) and h.on_screen(e.position, 1.0):
		_bubble(dist)


func _dive(first: bool) -> void:
	hidden = true
	go("sub", "spawn")
	e.state_t = 1e9
	e.model.position.y = _sink_y
	play("idle", 0.0)
	_far_t = 0.0
	if not first:
		h.fx.puff(e.flat_pos(), Color(0.45, 0.4, 0.25, 0.7), 4, 0.6, 1.2)
	cd = maxf(cd, 0.8)


func _surface() -> void:
	hidden = false
	e.state_t = 0.0


func _bubble(dist: float) -> void:
	if _leap:
		_aim_leap(dist)
		return
	go("bubble")
	tele(0, e.flat_pos(), 0.0, Vector2(1.8, 0), 0.7, 0.6)
	h.fx.puff(e.flat_pos(), Color(0.45, 0.4, 0.25, 0.8), 5, 0.7, 1.0)
	Sfx.play("enemy_windup", -8.0, 0.7)


func _aim_leap(dist: float) -> void:
	var w := float(e.def["windup"])
	e.aim_yaw = yaw_hero()
	var len_ := minf(dist + 0.8, 7.5)
	_to = h.arena.resolve(e.flat_pos() + Actor.dir_of(e.aim_yaw) * len_, e.radius)
	go("bubble")
	e.face(e.aim_yaw, 0.0)
	tele(2, e.flat_pos(), e.aim_yaw, Vector2(1.0, len_), w)
	if not hidden:
		play("idle", 0.1)
		e.squash(Vector3(0.1, -0.16, -0.08))
	Sfx.play("enemy_windup", -6.0, 1.6)


func _start_leap() -> void:
	_surface()
	_from = e.position
	_hit = false
	go("leap", "dash")
	play("run", 0.05, 2.0)
	lunge_pose(Actor.dir_of(e.aim_yaw))
	Sfx.play("charge", -8.0, 1.6)


func _land() -> void:
	e.model.position.y = 0.0
	e.squash(Vector3(0.12, -0.14, 0.0))
	h.fx.puff(e.flat_pos(), Color(0.45, 0.4, 0.25, 0.7), 4, 0.6, 1.2)
	cd = float(e.def["cooldown"]) * randf_range(0.9, 1.3)
	go("recover", "recover")


## Bogfin: out of the bog with a burst at its own feet.
func _burst() -> void:
	_surface()
	go("rise", "chase")
	e.model.position.y = _sink_y
	play("spawn", 0.0, 2.0, true)
	h.fx.puff(e.flat_pos(), Color(0.45, 0.4, 0.25, 0.8), 8, 1.0, 2.4)
	Sfx.play("quake", -8.0, 1.5)
	if hero_in(e.flat_pos(), 1.8):
		hurt_hero(0.8, 0.5)
		h.hero.push((h.hero.flat_pos() - e.flat_pos()).normalized(), 9.0)
	cd = 0.4


func _flee() -> void:
	clear_teles()
	var tr := terrain()
	_flee_to = tr.nearest_safe(e.flat_pos()) if tr != null else e.flat_pos()
	_surface()
	go("flee", "chase")
	e.model.position.y = 0.0
	play("run", 0.1, 1.4)
	h.fx.puff(e.flat_pos(), Color(0.45, 0.4, 0.25, 0.7), 4, 0.6, 1.2)
	cd = maxf(cd, 1.5)


func interrupt() -> void:
	super.interrupt()
	if st == "bubble":
		if hidden:
			go("sub", "spawn")
		else:
			go("move", "chase")
