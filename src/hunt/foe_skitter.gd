extends "res://src/hunt/foe_brain.gd"
## Frost Imp: a fast zig-zagging swarm foe. Past `hop_at` metres it skitters in
## a weave; inside it crouches (a small cone shows where it will land), hops
## `hop_len` metres and bites if it lands on the hero, leaving a chill puddle.
## Up close it swings like any minion.

var _land := Vector3.ZERO
var _from := Vector3.ZERO
var _hopped := false
var _weave := randf() * TAU
const HOP_TIME := 0.42


func think(dt: float, to: Vector3, dist: float) -> void:
	match st:
		"move":
			_weave += dt * 5.0
			var radial := to / maxf(dist, 0.01)
			if cd <= 0.0 and dist < float(cfg.get("hop_at", 4.2)) and dist > e.reach + 0.8:
				_crouch(dist)
				return
			if dist <= e.reach + h.hero.radius + 0.15 and cd <= 0.0:
				start_swing()
				return
			var want := (radial + radial.cross(Vector3.UP) * sin(_weave) * 0.55).normalized()
			walk(want, spd(), dt, dist)
		"crouch":
			e.face(Actor.yaw_to(e.position, _land), dt, 14.0)
			if t >= 0.3:
				clear_teles()
				_from = e.position
				_hopped = false
				go("hop", "dash")
				play("run", 0.05, 2.0)
				e.lean(Actor.dir_of(Actor.yaw_to(e.position, _land)), 0.12)
		"hop":
			var u := clampf(t / HOP_TIME, 0.0, 1.0)
			e.position = _from.lerp(_land, u)
			e.position.y = _from.y
			e.model.position.y = sin(u * PI) * 0.9
			if u >= 1.0:
				_land_hop()
		"windup", "recover":
			melee(dt, to, dist)


func _crouch(dist: float) -> void:
	var len_ := minf(float(cfg.get("hop_len", 3.4)), dist + 0.6)
	var dir := (h.hero.flat_pos() - e.flat_pos()).normalized()
	_land = h.arena.resolve(e.flat_pos() + dir * len_, e.radius)
	go("crouch", "windup")
	play("idle", 0.1)
	e.squash(Vector3(0.1, -0.16, -0.08))
	var yaw := Actor.yaw_to(e.position, _land)
	tele(0, _land, 0.0, Vector2(1.1, 0), 0.3)
	Sfx.play("enemy_windup", -9.0, 1.9)
	e.face(yaw, 0.0)


func _land_hop() -> void:
	e.model.position.y = 0.0
	e.squash(Vector3(0.12, -0.14, 0.0))
	if hero_in(e.flat_pos(), 1.1 + e.radius):
		hurt_hero(1.0, 0.2)
	if h.patches.size() < 8:
		h.add_fire_patch(e.flat_pos(), float(cfg.get("puddle", 0.9)), 2.5, 0.0, &"frost", true)
	cd = float(e.def["cooldown"]) * randf_range(1.0, 1.6)
	go("recover", "recover")
	play("idle", 0.1)


func on_death() -> void:
	super.on_death()
	e.model.position.y = 0.0
