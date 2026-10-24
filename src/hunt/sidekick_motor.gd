extends RefCounted
## How a sidekick moves on its own: a spring-lagged follow to a slot at the
## hero's side, steering round walls (the arena's flow field), idle wander
## near a hero who stands still, a sprint to catch up and a blink back when
## it falls far behind. Flyers bob and bank into turns. Pure state and maths
## (no scene tree), so tests drive it directly; sidekick.gd applies `pos`,
## `yaw` and `bank` to the node and plays the matching animation.

enum S { IDLE, FOLLOW, WANDER, SPRINT, ATTACK, SPECIAL, HIT }
const NAMES := ["idle", "follow", "wander", "sprint", "attack", "special", "hit"]

## Slot beside the hero (hero space: x to its side, z ahead).
const SLOT := Vector3(1.4, 0, 0.9)
## Inside this the sidekick settles; it walks beyond it.
const ARRIVE := 0.45
## Past this it sprints, past TELEPORT it blinks back to its slot.
const SPRINT_DIST := 4.5
const TELEPORT_DIST := 11.0
## Wander after the hero has stood still this long, within WANDER_R of it.
const STILL_BEFORE_WANDER := 1.4
const WANDER_R := 2.2
## Follow lag: how fast velocity chases the wanted velocity (1/s).
const ACCEL := 6.0
const TURN := 9.0
const BANK_MAX := 0.45

var pos := Vector3.ZERO
var vel := Vector3.ZERO
var yaw := 0.0
var bank := 0.0
var fly := 0.0
var side := -1.0
var state: int = S.IDLE
var state_t := 0.0
## Remaining lock of an attack/special/hit, and when its hit lands.
var action_t := 0.0
var hit_at := -1.0
var face_to := Vector3.INF
var still_t := 0.0
var wander_to := Vector3.INF
var wander_wait := 0.0
var teleports := 0
## Melee moves walk/run to `approach` first; the wind-up starts on arrival.
var approach := Vector3.INF
var approach_t := 0.0
## Set when an approach gave up (target out of reach): the caller cancels.
var aborted := false
## Seconds since the last action (combat), and how long it has been too far.
var since_action := 99.0
var far_t := 0.0
## Teleport needs this long out of combat and this long too far.
const CALM_BEFORE_BLINK := 2.5
const FAR_BEFORE_BLINK := 0.8
const APPROACH_REACH := 0.9
const APPROACH_GIVE_UP := 1.8
var rng := RandomNumberGenerator.new()
var _last_hero := Vector3.INF


func slot(hero_pos: Vector3, hero_yaw: float) -> Vector3:
	var p := hero_pos + Vector3(side * SLOT.x, 0, SLOT.z).rotated(Vector3.UP, hero_yaw)
	p.y = 0.0
	return p


static func flat_dist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


## The locomotion state for a distance to the slot (actions decide themselves).
static func pick_state(dist: float, hero_moving: bool, still_t_: float) -> int:
	if dist > SPRINT_DIST:
		return S.SPRINT
	if dist > ARRIVE and (hero_moving or dist > WANDER_R + 0.6):
		return S.FOLLOW
	if not hero_moving and still_t_ >= STILL_BEFORE_WANDER:
		return S.WANDER
	if dist > ARRIVE * 2.5:
		return S.FOLLOW
	return S.IDLE


func is_action() -> bool:
	return state in [S.ATTACK, S.SPECIAL, S.HIT]


## Starts an attack, special or hit reaction: `windup` until its hit lands,
## `dur` in all. A hit reaction never cuts an attack short.
func act(kind: int, windup: float, dur: float, at := Vector3.INF, go_to := Vector3.INF) -> bool:
	if kind == S.HIT and state in [S.ATTACK, S.SPECIAL]:
		return false
	_enter(kind)
	action_t = dur
	hit_at = windup
	face_to = at
	approach = Vector3(go_to.x, 0, go_to.z) if go_to != Vector3.INF else Vector3.INF
	approach_t = 0.0
	aborted = false
	since_action = 0.0
	return true


func approaching() -> bool:
	return approach != Vector3.INF and flat_dist(pos, approach) > APPROACH_REACH


## True once, on the frame an action's hit lands.
func take_hit() -> bool:
	if hit_at >= 0.0 and state_t >= hit_at:
		hit_at = -1.0
		return true
	return false


func _enter(s: int) -> void:
	if s != state:
		state = s
		state_t = 0.0


## One step. `hero_speed` in m/s. `blocked(p)` and `flow(p)` come from the
## arena (null in tests): flow points round walls toward the hero. Returns
## true when it teleported this step.
func step(dt: float, hero_pos: Vector3, hero_yaw: float, hero_speed: float, blocked := Callable(), flow := Callable(), resolve := Callable(), on_screen := Callable()) -> bool:
	var closing := is_action() and approaching()
	# The wind-up clock only runs once it has reached its target.
	if not closing:
		state_t += dt
	else:
		approach_t += dt
		if approach_t > APPROACH_GIVE_UP:
			aborted = true
			hit_at = -1.0
			approach = Vector3.INF
			closing = false
			_enter(S.IDLE)
	since_action = 0.0 if is_action() else since_action + dt
	var hero_moving := _last_hero != Vector3.INF and flat_dist(hero_pos, _last_hero) > 0.25 * dt
	_last_hero = hero_pos
	still_t = 0.0 if hero_moving else still_t + dt
	var want_at := slot(hero_pos, hero_yaw)
	var dist := flat_dist(pos, want_at)
	# Blink back only when genuinely left behind out of combat: never during
	# or right after an action, only after being too far for a while, and
	# only from off-screen unless it is hopelessly far.
	far_t = far_t + dt if dist > TELEPORT_DIST else 0.0
	var seen: bool = on_screen.is_valid() and on_screen.call(pos)
	if far_t >= FAR_BEFORE_BLINK and not is_action() and since_action >= CALM_BEFORE_BLINK and (not seen or dist > TELEPORT_DIST * 2.0):
		far_t = 0.0
		pos = Vector3(want_at.x, pos.y, want_at.z)
		vel = Vector3.ZERO
		teleports += 1
		_enter(S.IDLE)
		return true
	if is_action() and not closing:
		action_t -= dt
		if action_t <= 0.0:
			approach = Vector3.INF
			_enter(S.IDLE)
	if not is_action():
		var s := pick_state(dist, hero_moving, still_t)
		if s == S.WANDER:
			# Pick a spot near the hero, walk there slowly, wait, repeat.
			if wander_to == Vector3.INF or flat_dist(wander_to, hero_pos) > WANDER_R + 0.5:
				wander_to = _wander_spot(hero_pos, blocked)
			if flat_dist(pos, wander_to) < 0.3:
				wander_wait -= dt
				if wander_wait <= 0.0:
					wander_to = _wander_spot(hero_pos, blocked)
					wander_wait = rng.randf_range(1.0, 2.6)
				s = S.IDLE if wander_wait > 0.0 else S.WANDER
			want_at = wander_to
		else:
			wander_to = Vector3.INF
			wander_wait = 0.0
			if s == S.IDLE and state == S.WANDER and still_t > STILL_BEFORE_WANDER:
				s = S.WANDER
		_enter(s)
	# Wanted velocity for the state; the spring (ACCEL) supplies the lag.
	var to := want_at - pos
	to.y = 0.0
	var d := to.length()
	var spd := 0.0
	match state:
		S.FOLLOW:
			spd = (hero_speed + 0.6) * clampf(d / 1.6, 0.35, 1.25)
		S.SPRINT:
			spd = hero_speed * 2.1 + 1.0
		S.WANDER:
			spd = minf(1.3, hero_speed * 0.35 + 0.4) * clampf(d / 0.6, 0.2, 1.0)
		S.ATTACK, S.SPECIAL:
			if closing:
				to = approach - pos
				to.y = 0.0
				d = to.length()
				spd = hero_speed * 2.1 + 1.0
		S.HIT:
			spd = 0.0
	var dir := to / d if d > 0.001 else Vector3.ZERO
	if fly < 0.6 and dir != Vector3.ZERO and blocked.is_valid() and (blocked.call(pos + dir * 0.9) or blocked.call(pos + dir * 0.45)):
		var f: Vector3 = flow.call(pos) if flow.is_valid() else Vector3.ZERO
		dir = f if f != Vector3.ZERO else _sidestep(dir, blocked)
	var want_v := dir * spd
	var k := 1.0 - exp(-(ACCEL * (1.6 if state == S.SPRINT else 1.0)) * dt)
	var prev_v := vel
	vel = vel.lerp(want_v, k)
	var before := pos
	pos += vel * dt
	# Momentum never carries it into a wall: it slides along it instead.
	if fly < 0.6 and blocked.is_valid() and blocked.call(pos) and not blocked.call(before):
		var sx := before + Vector3(vel.x * dt, 0, 0)
		var sz := before + Vector3(0, 0, vel.z * dt)
		if not blocked.call(sx):
			pos = sx
			vel.z = 0.0
		elif not blocked.call(sz):
			pos = sz
			vel.x = 0.0
		else:
			pos = before
			vel = Vector3.ZERO
	if resolve.is_valid() and fly < 0.6:
		pos = resolve.call(pos)
	# Face where it goes, or its target while acting.
	var look := vel
	if is_action() and face_to != Vector3.INF and not closing:
		look = face_to - pos
	look.y = 0.0
	if look.length() > 0.15:
		yaw = lerp_angle(yaw, atan2(look.x, look.z), 1.0 - exp(-TURN * dt))
	# Flyers bank into the turn (sideways acceleration).
	if fly > 0.0 and dt > 0.0:
		var acc := (vel - prev_v) / dt
		var right := Vector3(cos(yaw), 0, -sin(yaw))
		var want_bank := clampf(-acc.dot(right) * 0.08, -BANK_MAX, BANK_MAX)
		bank = lerpf(bank, want_bank, 1.0 - exp(-5.0 * dt))
	return false


func speed() -> float:
	return Vector2(vel.x, vel.z).length()


func _wander_spot(hero_pos: Vector3, blocked: Callable) -> Vector3:
	for i in 8:
		var a := rng.randf() * TAU
		var r := rng.randf_range(0.9, WANDER_R)
		var p := hero_pos + Vector3(cos(a) * r, 0, sin(a) * r)
		p.y = 0.0
		if not blocked.is_valid() or not blocked.call(p):
			return p
	return Vector3(hero_pos.x, 0, hero_pos.z)


func _sidestep(dir: Vector3, blocked: Callable) -> Vector3:
	for a in [0.7, -0.7, 1.4, -1.4]:
		var d := dir.rotated(Vector3.UP, a)
		if not blocked.call(pos + d * 0.5) and not blocked.call(pos + d * 0.9):
			return d
	return Vector3.ZERO
