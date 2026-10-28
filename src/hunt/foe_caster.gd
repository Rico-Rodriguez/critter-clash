extends "res://src/hunt/foe_brain.gd"
## The four casters, one windup shape: keep `keep` metres off, show the spell on
## the ground for the foe's `windup`, then land it. `cfg.spell`:
##   thin     Rime Seer: a circle under the hero; hit or not, ice in it turns thin.
##   ignite   Pyre Shaman: a circle under the hero; bog and planks in it catch fire.
##   lantern  Mire Hag: plants a lantern near the hero; a ring counts down `fuse`
##            seconds, then the lantern bursts and ignites the ground. `cap` lit
##            lanterns per hag at most.
##   summon   Winter Caller: rings at 2 spots (arena `spawn_holes` if it has them,
##            else round the caller); `count` imps climb out. Never above `cap`.
## With no terrain grid yet, thin/ignite/lantern leave a ground patch instead.

var _aim := Vector3.ZERO
var _spots: Array = []
var _lanterns := 0


func think(dt: float, to: Vector3, dist: float) -> void:
	match st:
		"move":
			var keep := float(cfg.get("keep", 7.5))
			var radial := to / maxf(dist, 0.01)
			var want := radial.cross(Vector3.UP) * e.strafe * 0.5
			if dist > e.reach * 0.95:
				want = radial
			elif dist < keep * 0.6:
				want = -radial
			walk(want, spd(), dt, dist, true)
			if dist <= e.reach and cd <= 0.0 and h.on_screen(e.position, 1.0) and _can_cast():
				_wind()
		"windup":
			e.face(Actor.yaw_to(e.position, _aim) if str(cfg["spell"]) != "summon" else yaw_hero(), dt, 10.0)
			if t >= float(e.def["windup"]) * (0.75 if "swift" in e.affixes else 1.0):
				_cast()
		"recover":
			face_hero(dt)
			if t >= 0.4:
				go("move", "chase")


func _can_cast() -> bool:
	match str(cfg["spell"]):
		"summon":
			return FoeBrains.count(h, str(cfg["minion"])) < int(cfg.get("cap", 6)) and h.foes.size() < Hunt.MAX_FOES - 2
		"lantern":
			return _lanterns < int(cfg.get("cap", 3))
	return true


func _wind() -> void:
	var w := float(e.def["windup"]) * (0.75 if "swift" in e.affixes else 1.0)
	go("windup", "windup")
	swing(w)
	var r := float(cfg.get("r", float(e.def.get("blast", 2.0)))) * (1.25 if e.elite else 1.0)
	match str(cfg["spell"]):
		"thin", "ignite":
			_aim = h.hero.flat_pos()
			tele(0, _aim, 0.0, Vector2(r, 0), w, 0.6)
		"lantern":
			_aim = h.arena.resolve(h.hero.flat_pos() + Vector3(randf_range(-2.5, 2.5), 0, randf_range(-2.5, 2.5)), 0.5)
			var fuse := float(cfg.get("fuse", 4.5))
			tele(0, _aim, 0.0, Vector2(r, 0), w + fuse, 0.6, &"fire")
			_lanterns += 1
			e.aim = _aim
		"summon":
			_spots = _summon_spots(int(cfg.get("count", 2)))
			for p: Vector3 in _spots:
				tele(0, p, 0.0, Vector2(1.0, 0), w, 0.6, &"frost")
	Sfx.play("enemy_windup", -6.0)


func _summon_spots(n: int) -> Array:
	var out: Array = []
	var holes: Variant = h.arena.get("spawn_holes")
	if holes is Array:
		var near: Array = (holes as Array).filter(func(p: Vector3): return p.distance_to(e.flat_pos()) < 14.0 and p.distance_to(h.hero.flat_pos()) > 3.0)
		near.shuffle()
		for p: Vector3 in near.slice(0, n):
			out.append(p)
	var a0 := randf() * TAU
	while out.size() < n:
		var a := a0 + TAU * out.size() / float(n)
		out.append(h.arena.resolve(e.flat_pos() + Vector3(sin(a), 0, cos(a)) * 2.4, 0.5))
	return out


func _cast() -> void:
	var spell := str(cfg["spell"])
	var r := float(cfg.get("r", float(e.def.get("blast", 2.0)))) * (1.25 if e.elite else 1.0)
	var tr := terrain()
	match spell:
		"thin", "ignite":
			clear_teles()
			h.fx.vfx.impact(element(), _aim, r, Fx.VfxLib.NO_TINT, &"skill")
			Sfx.play("boom", -8.0, 1.2)
			if hero_in(_aim, r):
				hurt_hero(1.0, 0.5)
			if tr != null:
				if spell == "thin":
					for c in cells_near(_aim, r):
						tr.thin(c)
				else:
					tr.ignite_at(_aim, r)
			elif spell == "thin":
				h.add_fire_patch(_aim, r, 4.0, 0.0, &"frost", true)
			else:
				h.add_fire_patch(_aim, r, 3.5, e.dmg * 0.3, &"fire")
		"lantern":
			_plant(_aim, r)
		"summon":
			clear_teles()
			for p: Vector3 in _spots:
				h.fx.vfx.nova(&"frost", p, 1.6, 0.4, Fx.VfxLib.NO_TINT, &"skill")
				if h.foes.size() < Hunt.MAX_FOES:
					h.spawn_foe(str(cfg["minion"]), p)
			Sfx.play("unlock_start", -4.0)
	cd = float(e.def["cooldown"]) * randf_range(0.85, 1.15)
	go("recover", "recover")


## The lantern: a flame on the spot now, a ring counting down, then the burst.
## It does not need its hag alive; the timer owns it.
func _plant(at: Vector3, r: float) -> void:
	var fuse := float(cfg.get("fuse", 4.5))
	h.fx.vfx.linger(&"fire", at, 0.5, fuse, Fx.VfxLib.NO_TINT, &"light")
	var dmg := e.dmg
	var hunt := h
	var me: WeakRef = weakref(self)
	h.get_tree().create_timer(fuse, false).timeout.connect(func():
		var b: Object = me.get_ref()
		if b != null:
			b._lanterns -= 1
		if hunt._ended or not is_instance_valid(hunt.hero):
			return
		burst(hunt, at, r, dmg))
	_aim = at


func on_death() -> void:
	super.on_death()


## The lantern's burst: a blast, then the cells under it catch (or an ember patch
## without a grid). Static so the timer needs no live brain, and tests can call it.
static func burst(hunt: Hunt, at: Vector3, r: float, dmg: float) -> void:
	hunt.fx.vfx.impact(&"fire", at, r, Fx.VfxLib.NO_TINT, &"skill")
	Sfx.play("boom", -8.0, 1.0)
	if hunt.hero.alive and hunt.hero.flat_pos().distance_to(at) <= r + hunt.hero.radius * 0.5:
		hunt.damage_hero(dmg, null, 0.5)
	if hunt.arena.terrain_live:
		hunt.arena.terrain.ignite_at(at, r)
	else:
		hunt.add_fire_patch(at, r, 3.5, dmg * 0.25, &"fire")
