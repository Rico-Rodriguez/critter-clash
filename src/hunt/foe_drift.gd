extends "res://src/hunt/foe_brain.gd"
## Foes that drift in and pop. Close in they swell for `windup` seconds with a
## ring on the ground, then burst and die. `cfg.pop`:
##   shards   Crystal Shardling (flies): six lanes of shards from the body, each
##            drawn on the ground first; the burst breaks ice walls near it.
##   spores   Sporecap: a spore ring; a hit slows the hero, and planks inside
##            `rot_r` rot into bog.
##   methane  Methane Bloat (flies): a fire burst that ignites bog and planks
##            inside `ignite_r`. Killing it does the same where it hangs, so
##            it is safest to pop over dry land.
## A killed (not popped) shardling or bloat still bursts, but harmlessly to the
## hero: the ground effect only.

var _popped := false
var _lanes: Array = []


func think(dt: float, to: Vector3, dist: float) -> void:
	match st:
		"move":
			if dist <= e.reach + h.hero.radius + 0.1 and cd <= 0.0:
				_swell()
			else:
				walk(to / maxf(dist, 0.01), spd(), dt, dist)
		"windup":
			face_hero(dt)
			# A white blink, quicker as it goes: about to burst.
			if fmod(t, lerpf(0.3, 0.12, clampf(t / float(e.def["windup"]), 0.0, 1.0))) < dt:
				e.hit_flash()
			if t >= float(e.def["windup"]):
				_pop()


func _swell() -> void:
	var w := float(e.def["windup"]) * (0.75 if "swift" in e.affixes else 1.0)
	go("windup", "windup")
	play("idle", 0.1)
	var at := e.flat_pos()
	if str(cfg["pop"]) == "shards":
		_lanes.clear()
		var a0 := randf() * TAU
		for i in int(cfg.get("shards", 6)):
			var yaw := a0 + TAU * i / float(cfg.get("shards", 6))
			_lanes.append(yaw)
			tele(2, at, yaw, Vector2(0.45, float(e.def["blast"]) + 2.0), w)
	else:
		tele(0, at, 0.0, Vector2(float(e.def["blast"]), 0), w, 0.6, &"fire" if str(cfg["pop"]) == "methane" else &"")
	Sfx.play("enemy_windup", -6.0, 1.3)


func _pop() -> void:
	clear_teles()
	_popped = true
	var at := e.flat_pos()
	var r := float(e.def["blast"])
	match str(cfg["pop"]):
		"shards":
			h.fx.vfx.nova(&"frost", at, r, 0.35, Fx.VfxLib.NO_TINT, &"skill")
			h.fx.burst(at + Vector3(0, 0.6, 0), Color(0.7, 0.92, 1.0), 14, 7.0, 0.8)
			var reach := r + 2.0
			var rel := h.hero.flat_pos() - at
			for yaw: float in _lanes:
				var fwd := Actor.dir_of(yaw)
				var along := rel.dot(fwd)
				var across := (rel - fwd * along).length()
				if h.hero.alive and along > 0.0 and along < reach and across < 0.55 + h.hero.radius * 0.5:
					hurt_hero(1.0, 0.5)
					break
			_break_walls(at, r)
		"spores":
			h.fx.vfx.nova(&"nature", at, r, 0.35, Fx.VfxLib.NO_TINT, &"skill")
			h.fx.puff(at, Color(0.55, 0.65, 0.3, 0.7), 8, 1.1, 2.0)
			if hero_in(at, r):
				hurt_hero(1.0, 0.4)
				h.hero.slow_t = maxf(h.hero.slow_t, 1.5)
			_rot(at)
		"methane":
			h.fx.flame_burst(at, r, true, Color(1.0, 0.55, 0.18), &"skill")
			h.fx.puff(at, Color(0.3, 0.25, 0.2, 0.7), 8, 1.2, 3.0)
			h.shake(0.3)
			Sfx.play("boom", -3.0)
			if hero_in(at, r):
				hurt_hero(1.0, 0.7)
			for f in h.foes_near(e.position, r + 1.0):
				if f != e and not f is Boss and at.distance_to(f.flat_pos()) <= r:
					h.damage_foe(f, e.dmg * 0.8, e, (f.flat_pos() - at).normalized(), 9.0)
			_ignite(at)
	e.hp = 0.0
	h._kill(e)


func on_death() -> void:
	super.on_death()
	e.model.position.y = 0.0
	if _popped:
		return
	var at := e.flat_pos()
	match str(cfg["pop"]):
		"shards":
			h.fx.burst(at + Vector3(0, 0.6, 0), Color(0.7, 0.92, 1.0), 10, 6.0, 0.8)
			_break_walls(at, float(e.def["blast"]))
		"methane":
			_ignite(at)
		"spores":
			h.fx.puff(at, Color(0.55, 0.65, 0.3, 0.6), 5, 0.9, 1.6)


func _break_walls(at: Vector3, r: float) -> void:
	var tr := terrain()
	if tr != null:
		for c in cells_near(at, r):
			tr.break_wall(c)


func _rot(at: Vector3) -> void:
	var tr := terrain()
	if tr != null:
		for c in cells_near(at, float(cfg.get("rot_r", 2.2))):
			tr.rot(c)
	elif h.patches.size() < 10:
		h.add_fire_patch(at, 1.4, 3.0, 0.0, &"nature", true)


func _ignite(at: Vector3) -> void:
	var tr := terrain()
	if tr != null:
		tr.ignite_at(at, float(cfg.get("ignite_r", 2.4)))
