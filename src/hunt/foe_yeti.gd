extends "res://src/hunt/foe_brain.gd"
## Rime Yeti: walks straight at the hero and ground-pounds (a circle round its
## own feet, then a shockwave that cracks the ice within `crack_r` into thin ice
## and shoves the hero). At `lob_min`..`lob_max` metres it rears back and lobs a
## snowball instead: a circle where it will land (aimed at the hero's feet when
## the windup starts, never tracking), a chill and thin ice on impact.

var _lob_cd := 2.5
var _kind := "slam"
var _aim := Vector3.ZERO


func think(dt: float, to: Vector3, dist: float) -> void:
	_lob_cd -= dt
	match st:
		"move":
			var radial := to / maxf(dist, 0.01)
			if dist <= e.reach + h.hero.radius + 0.15 and cd <= 0.0:
				_wind("slam")
			elif cd <= 0.0 and _lob_cd <= 0.0 and dist >= float(cfg.get("lob_min", 5.5)) and dist <= float(cfg.get("lob_max", 11.0)) and h.on_screen(e.position, 1.0):
				_wind("lob")
			else:
				walk(radial, spd(), dt, dist)
		"windup":
			e.face(Actor.yaw_to(e.position, _aim) if _kind == "lob" else yaw_hero(), dt, 6.0)
			if t >= float(e.def["windup"]) * (1.0 if _kind == "slam" else 0.85):
				if _kind == "slam":
					_slam()
				else:
					_lob()
		"recover":
			if t >= 0.5:
				go("move", "chase")


func _wind(kind: String) -> void:
	_kind = kind
	var w := float(e.def["windup"]) * (1.0 if kind == "slam" else 0.85)
	go("windup", "windup")
	swing(w)
	e.lean(-Actor.dir_of(yaw_hero()), 0.1)
	if kind == "slam":
		tele(0, e.flat_pos(), 0.0, Vector2(float(e.def["blast"]), 0), w, 0.6)
	else:
		_aim = h.hero.flat_pos()
		tele(0, _aim, 0.0, Vector2(float(cfg.get("lob_r", 1.9)), 0), w, 0.6, &"frost")
	Sfx.play("enemy_windup", -6.0, 0.8)


func _slam() -> void:
	clear_teles()
	var r := float(e.def["blast"])
	var at := e.flat_pos()
	h.fx.vfx.nova(&"frost", at, r * 1.1, 0.35, Fx.VfxLib.NO_TINT, &"skill")
	h.fx.puff(at, Color(0.85, 0.92, 1.0, 0.7), 10, 1.4, 3.5)
	h.shake(0.3)
	Sfx.play("quake", -4.0, 1.2)
	if hero_in(at, r):
		hurt_hero(1.0, 0.8)
		h.hero.push((h.hero.flat_pos() - at).normalized(), 14.0)
	var tr := terrain()
	if tr != null:
		for c in cells_near(at, float(cfg.get("crack_r", 3.4))):
			tr.thin(c)
	elif e.def.has("leave") and h.biome != null:
		h.biome.leave(e, at)
	cd = float(e.def["cooldown"]) * randf_range(0.9, 1.15)
	_lob_cd = maxf(_lob_cd, 1.5)
	go("recover", "recover")


func _lob() -> void:
	clear_teles()
	var r := float(cfg.get("lob_r", 1.9))
	h.fx.vfx.impact(&"frost", _aim, r, Fx.VfxLib.NO_TINT, &"skill")
	Sfx.play("boom", -8.0, 1.4)
	if hero_in(_aim, r):
		hurt_hero(0.6, 0.4)
		h.hero.slow_t = maxf(h.hero.slow_t, 2.0)
	var tr := terrain()
	if tr != null:
		for c in cells_near(_aim, r):
			tr.thin(c)
	else:
		h.add_fire_patch(_aim, r, 3.0, 0.0, &"frost", true)
	cd = float(e.def["cooldown"]) * 0.8
	_lob_cd = float(cfg.get("lob_every", 4.5)) * randf_range(0.9, 1.2)
	go("recover", "recover")
