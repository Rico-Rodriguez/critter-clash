extends "res://src/hunt/foe_brain.gd"
## Ember Wasp: a flying skirmisher. It buzzes round the hero at `orbit` metres,
## then shows a lane for its windup and dives along it (`dive_len` metres, fast),
## stinging once, and climbs away. Every `spark_every` seconds of the dive it
## drops a spark: over bog or planks that is a real fire start in the terrain
## grid (about half the time); elsewhere a short ember patch. Patches are capped.

var _dir := Vector3.ZERO
var _hit := false
var _spark := 0.0
var _len := 9.0


func think(dt: float, to: Vector3, dist: float) -> void:
	match st:
		"move":
			var orbit := float(cfg.get("orbit", 5.5))
			var radial := to / maxf(dist, 0.01)
			var want := radial.cross(Vector3.UP) * e.strafe
			if dist > orbit + 1.0:
				want = (radial + want * 0.4).normalized()
			elif dist < orbit - 1.2:
				want = (-radial * 0.6 + want).normalized()
			walk(want, spd(), dt, dist, true)
			if cd <= 0.0 and dist < float(cfg.get("dive_len", 9.0)) + 1.0 and h.on_screen(e.position, 1.0):
				_wind()
		"windup":
			if t < float(e.def["windup"]) - 0.15:
				e.aim_yaw = Actor.yaw_to(e.position, e._lead_pos(0.25))
				if teles.size() > 0 and is_instance_valid(teles[0]):
					(teles[0] as Node3D).rotation.y = e.aim_yaw
					(teles[0] as Node3D).position = e.flat_pos() + Vector3(0, 0.04, 0)
			e.face(e.aim_yaw, dt, 14.0)
			if t >= float(e.def["windup"]):
				_dive()
		"dash":
			_fly(dt)
		"recover":
			e.position += _dir * 3.0 * maxf(0.6 - t, 0.0) * dt * 4.0
			if t >= 0.9:
				go("move", "chase")


func _wind() -> void:
	var w := float(e.def["windup"]) * (0.75 if "swift" in e.affixes else 1.0)
	go("windup", "windup")
	e.aim_yaw = Actor.yaw_to(e.position, e._lead_pos(0.25))
	_len = float(cfg.get("dive_len", 9.0))
	e.squash(Vector3(0.08, -0.1, -0.06))
	tele(2, e.flat_pos(), e.aim_yaw, Vector2(0.8, _len), w)
	Sfx.play("enemy_windup", -6.0, 2.0)


func _dive() -> void:
	clear_teles()
	_dir = Actor.dir_of(e.aim_yaw)
	_hit = false
	_spark = 0.0
	go("dash", "dash")
	play("run", 0.05, 2.2)
	lunge_pose(_dir)
	Sfx.play("charge", -9.0, 2.0)


func _fly(dt: float) -> void:
	var step := 17.0 * dt
	e.position += _dir * step
	e.position = h.arena.resolve(e.position, e.radius)
	_len -= step
	_spark -= dt
	if _spark <= 0.0:
		_spark = float(cfg.get("spark_every", 0.35))
		_drop_spark()
	if not _hit and e.flat_pos().distance_to(h.hero.flat_pos()) < e.radius + h.hero.radius + 0.3:
		_hit = true
		hurt_hero(1.0, 0.25)
		h.hero.push(_dir, 5.0)
	if _len <= 0.0 or t > 1.0:
		cd = float(e.def["cooldown"]) * randf_range(0.9, 1.3)
		go("recover", "recover")
		play("run", 0.1, 1.0)


func _drop_spark() -> void:
	var at := e.flat_pos()
	var tr := terrain()
	if tr != null:
		var k: int = tr.kind_at(at)
		if k == Terrain.BOG or k == Terrain.PLANK:
			if randf() < 0.5:
				tr.ignite(tr.cell_of(at))
			return
	if h.patches.size() < 10:
		h.add_fire_patch(at, 0.6, 1.5, e.dmg * 0.25, &"fire")
