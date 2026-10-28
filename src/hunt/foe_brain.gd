extends RefCounted
## Base of the Rimehollow and Cinder Mire foe brains. A brain owns one Enemy:
## `FoeBrains.tick` runs it instead of `Enemy.tick` once the foe has climbed out
## (the stock spawn rise still plays), and the brain does everything `tick`
## would: common upkeep, freeze and stun, hit stagger, then its own `think`.
##
## The brain keeps its own phase `st` and timer `t`, and mirrors it onto
## `e.state` the way the stock AI does: "chase" while moving (so `stagger()` and
## the director see a normal foe), "windup" while committed, "recover" after.
## A hidden foe is `e.state == "spawn"` with the model sunk: the whole game
## already treats that as untouchable and untargetable.
##
## Subclasses override `think`, `ready` and `on_death`. No class_name (OTA).

const FoeBrains := preload("res://src/hunt/foe_brains.gd")
const Terrain := preload("res://src/hunt/terrain.gd")

var e: Enemy
var h: Hunt
var cfg: Dictionary
var st := "move"
var t := 0.0
var cd := 1.0
var hidden := false
var fly := false
var hover := 0.0
var teles: Array = []
var _ready_done := false
var _bob := randf() * TAU
var _sink_y := 0.0


func setup(e_: Enemy) -> void:
	e = e_
	h = e.hunt
	cfg = e.def.get("brain", {})
	fly = bool(e.def.get("fly", false))
	hover = float(cfg.get("hover", 0.0))
	cd = randf_range(0.4, 1.2)
	_sink_y = -1.7 * float(e.def["scale"])


## The arena's terrain grid while a zone paints one (`arena.terrain_live`, see
## biome_ground.gd). Null otherwise: every brain has a fallback.
func terrain() -> Object:
	var a: Arena = h.arena
	return a.terrain if a.terrain_live else null


## Called by Hunt each tick for a live foe. True: the brain ran the tick.
func tick(dt: float) -> bool:
	if not e.alive:
		return false
	if e.state == "spawn" and not hidden:
		return false
	if not _ready_done:
		_ready_done = true
		ready()
	e.tick_common(dt)
	e.age += dt
	if e.freeze_t > 0.0 or e.stun_t > 0.0:
		interrupt()
		return true
	if e.hit_t > 0.0:
		e.hit_t -= dt
		return true
	t += dt
	cd -= dt
	if e.elite and not hidden and e.state == "chase":
		e._tick_casts(dt)
	var to := h.hero.flat_pos() - e.flat_pos()
	think(dt, to, to.length())
	if fly and not hidden:
		_bob += dt * 3.0
		e.model.position.y = hover + sin(_bob) * 0.12
	return true


## One-off setup once the foe is up and the brain is in charge.
func ready() -> void:
	pass


func think(_dt: float, _to: Vector3, _dist: float) -> void:
	pass


## A stun or freeze cancels whatever the foe was committed to.
func interrupt() -> void:
	clear_teles()
	if st != "move" and not hidden:
		go("move", "chase")
		cd = maxf(cd, 0.6)


func on_death() -> void:
	clear_teles()
	if fly:
		e.model.position.y = 0.0


# --- Helpers ------------------------------------------------------------------

func go(phase: String, state: String = "") -> void:
	st = phase
	t = 0.0
	if state != "":
		e.state = state


func spd() -> float:
	var s := e.speed * h.foe_speed_mult
	var tr := terrain()
	if tr != null and not fly:
		s *= float(tr.speed_mult_at(e.flat_pos()))
	return s


func play(key: String, blend := 0.15, speed := 1.0, restart := false) -> void:
	e.play(str(e.def["anim"][key]), blend, speed, restart)


## Walk along `want` (unit-ish) at `s`, round walls, facing the way it goes.
func walk(want: Vector3, s: float, dt: float, dist_to_goal := INF, face_hero := false) -> void:
	if want.length_squared() < 0.0001:
		play("idle", 0.2)
		e.face(Actor.yaw_to(e.position, h.hero.position), dt)
		return
	var to := h.hero.flat_pos() - e.flat_pos()
	if not fly:
		want = e._around_walls(want, dist_to_goal, to / maxf(to.length(), 0.01))
	e.position += want * s * dt
	e.face(Actor.yaw_to(e.position, h.hero.position) if face_hero else atan2(want.x, want.z), dt, 10.0)
	play("run", 0.15, clampf(s / 3.2, 0.7, 1.6))


func face_hero(dt: float, rate := 10.0) -> void:
	e.face(Actor.yaw_to(e.position, h.hero.position), dt, rate)


func yaw_hero() -> float:
	return Actor.yaw_to(e.position, h.hero.position)


## A ground warning that is cancelled with the brain's others.
func tele(shape: int, pos: Vector3, yaw: float, size: Vector2, dur: float, cone := 0.6, element: StringName = &"") -> MeshInstance3D:
	var n := h.fx.telegraph(shape, pos, yaw, size, dur, cone, element)
	teles.append(n)
	return n


func clear_teles() -> void:
	for n in teles:
		if is_instance_valid(n):
			h.fx.cancel(n)
	teles.clear()


func hurt_hero(mult := 1.0, mech := 0.3) -> void:
	h.damage_hero(e.dmg * mult, e, mech)


func element() -> StringName:
	return StringName(e.def.get("element", "physical"))


func hero_in(at: Vector3, r: float) -> bool:
	return h.hero.alive and h.hero.flat_pos().distance_to(at) <= r + h.hero.radius * 0.5


## The strike animation timed so the blow lands as the windup ends.
func swing(windup: float) -> void:
	var atk := str(e.def["anim"]["attack"])
	e.play(atk, 0.08, clampf(e.anim_length(atk) * 0.45 / maxf(windup, 0.05), 0.5, 2.5), true)
	e.squash(Vector3(0.05, -0.07, -0.05))


func lunge_pose(dir: Vector3) -> void:
	e.squash(Vector3(-0.06, -0.05, 0.16))
	e.lean(dir, 0.12)


## Cells of the terrain within `r` of `p` (empty without a grid).
func cells_near(p: Vector3, r: float) -> Array:
	var tr := terrain()
	var out: Array = []
	if tr == null:
		return out
	var reach := ceili(r / Terrain.CELL)
	var c0: Vector2i = tr.cell_of(p)
	for dz in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			var c := c0 + Vector2i(dx, dz)
			if tr.in_bounds(c) and tr.center_of(c).distance_to(Vector3(p.x, 0, p.z)) <= r + Terrain.CELL * 0.5:
				out.append(c)
	return out


# --- A stock-like melee swing, shared by the foes that close in ----------------

## move -> windup (cone telegraph) -> recover. `start_melee` is where a subclass
## decides the swing begins; `melee` drives the three phases once it has.
func melee(dt: float, to: Vector3, dist: float, speed_mult := 1.0) -> void:
	match st:
		"move":
			var want := to / maxf(dist, 0.01)
			if dist > 3.5:
				want = (want + to.cross(Vector3.UP).normalized() * e.strafe * 0.3).normalized()
			if dist <= e.reach + h.hero.radius + 0.15 and cd <= 0.0:
				start_swing()
			else:
				walk(want, spd() * speed_mult, dt, dist)
		"windup":
			if t < float(e.def["windup"]) * 0.65:
				e.aim_yaw = yaw_hero()
			e.face(e.aim_yaw, dt, 10.0)
			if t >= float(e.def["windup"]):
				release_swing()
		"recover":
			face_hero(dt)
			if t >= 0.35:
				go("move", "chase")


func start_swing() -> void:
	var w := float(e.def["windup"]) * (0.75 if "swift" in e.affixes else 1.0)
	go("windup", "windup")
	e.aim_yaw = yaw_hero()
	swing(w)
	e.lean(-Actor.dir_of(e.aim_yaw), 0.08)
	tele(1, e.flat_pos(), e.aim_yaw, Vector2(e.reach + 0.6, 0), w, 0.9)


func release_swing() -> void:
	clear_teles()
	lunge_pose(Actor.dir_of(e.aim_yaw))
	var ang := absf(angle_difference(e.aim_yaw, yaw_hero()))
	var d := h.hero.flat_pos().distance_to(e.flat_pos())
	if d <= e.reach + h.hero.radius + 0.35 and ang < 1.1:
		hurt_hero()
	Sfx.play("atk_enemy", -8.0)
	cd = float(e.def["cooldown"]) * randf_range(0.85, 1.15)
	go("recover", "recover")
