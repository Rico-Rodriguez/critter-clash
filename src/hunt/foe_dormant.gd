extends "res://src/hunt/foe_brain.gd"
## Frozen Effigy: a statue that stands where it spawned, frozen mid-pose and
## untouchable (the stock `spawn` state), shivering once the hero is within
## 1.4x `wake_r`. At `wake_r` (or after `wake_max` seconds) the ice cracks for
## `wake_time` seconds with a ring telegraph, then it swings at once: the
## wake-up ambush. After that it is a plain shielded melee foe.

var _dormant := true
var _shiver := 0.0


func setup(e_: Enemy) -> void:
	super.setup(e_)
	hidden = true


func ready() -> void:
	pass


## The statue is "spawn" the whole time, so Hunt hands it to us from tick one.
func tick(dt: float) -> bool:
	if _dormant and e.alive and not _ready_done:
		_ready_done = true
		e.state = "spawn"
		e.state_t = 1e9
		e.model.position.y = 0.0
		play("idle", 0.0)
		e.anim.speed_scale = 0.0
	return super.tick(dt)


func think(dt: float, to: Vector3, dist: float) -> void:
	if _dormant:
		_statue(dt, dist)
		return
	match st:
		"wake":
			if t >= float(cfg.get("wake_time", 0.9)):
				clear_teles()
				h.fx.vfx.nova(&"frost", e.flat_pos(), 2.6, 0.4, Fx.VfxLib.NO_TINT, &"skill")
				h.fx.puff(e.flat_pos(), Color(0.85, 0.95, 1.0, 0.8), 8, 1.1, 2.4)
				Sfx.play("quake", -6.0, 1.6)
				go("move", "chase")
				cd = 0.0
				start_swing()
		"move", "windup", "recover":
			melee(dt, to, dist)


func _statue(dt: float, dist: float) -> void:
	var wake_r := float(cfg.get("wake_r", 6.0))
	if dist < wake_r * 1.4 and dist >= wake_r:
		_shiver += dt * 40.0
		e.model.rotation.z = sin(_shiver) * 0.03
	if dist < wake_r or t > float(cfg.get("wake_max", 14.0)):
		_wake()


func _wake() -> void:
	_dormant = false
	hidden = false
	e.model.rotation.z = 0.0
	e.anim.speed_scale = 1.0
	e.state = "windup"
	go("wake", "windup")
	var w := float(cfg.get("wake_time", 0.9))
	play("spawn", 0.0, e.anim_length(str(e.def["anim"]["spawn"])) / w * 0.9, true)
	tele(0, e.flat_pos(), 0.0, Vector2(2.6, 0), w, 0.6, &"frost")
	Sfx.play("enemy_windup", -4.0, 0.6)
