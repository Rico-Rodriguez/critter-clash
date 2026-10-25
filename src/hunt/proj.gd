class_name Proj
extends Node3D
## A projectile. Moves in a straight line on the XZ plane, hits by radius.
## Pooled by kind; `team` 0 hits foes, 1 hits the hero.

var kind := "arrow"
var vel := Vector3.ZERO
var dmg := 10.0
var hits_left := 1
var team := 0
var source: Node3D
var life := 1.0
var radius := 0.35
var splash := 0.0
var extra := {}
var hit_set := {}
var active := false
var body: Node3D
var _ember_t := 0.0


func launch(kind_: String, pos: Vector3, v: Vector3, dmg_: float, hits: int, src: Node3D, ex: Dictionary) -> void:
	kind = kind_
	position = Vector3(pos.x, 1.0, pos.z)
	vel = v
	dmg = dmg_
	hits_left = hits
	source = src
	extra = ex
	hit_set.clear()
	splash = float(ex.get("splash", 0.0))
	team = 1 if src is Enemy or src is Boss else 0
	life = float(ex.get("life", 0.9 if kind in ["arrow", "quarrel", "soularrow", "knife"] else 1.6))
	radius = {"arrow": 0.4, "fireball": 0.45, "bolt": 0.35, "spear": 0.45, "wave": float(ex.get("width", 1.2)), "orb": 0.5, "axe": 0.7, "throwaxe": 0.75,
		"knife": 0.45, "quarrel": 0.4, "soularrow": 0.45, "spark": 0.35, "firebolt": 0.45}.get(kind, 0.4)
	rotation = Vector3(0, atan2(v.x, v.z), 0)
	active = true
	visible = true


## Returns false when the projectile is spent.
func tick(dt: float, h: Hunt) -> bool:
	life -= dt
	position += vel * dt
	if kind == "axe" or kind == "throwaxe" or kind == "knife":
		body.rotation.y += dt * 22.0
	if extra.get("home", false) and team == 0:
		_steer(dt, h)
	if kind == "throwaxe":
		return _tick_return(dt, h)
	if kind in ["fireball", "orb", "spark", "soularrow", "firebolt"]:
		_ember_t -= dt
		if _ember_t <= 0.0:
			_ember_t = 0.045
			var ec: Color = {"fireball": Color(1.0, 0.45, 0.12), "orb": Color(0.7, 0.35, 1.0), "spark": Color(1.0, 0.8, 0.3), "soularrow": Color(0.5, 1.0, 0.7), "firebolt": Color(1.0, 0.5, 0.12)}[kind]
			# A small dissolve core trailing the shot (light tier: cheap and
			# quiet, since basics fire several times a second).
			var el: StringName = {"fireball": &"fire", "orb": &"shadow", "spark": &"fire", "soularrow": &"nature", "firebolt": &"fire"}[kind]
			h.fx.vfx.travel(el, position - vel.normalized() * 0.25, vel, ec, &"light")
	if life <= 0.0:
		if _bursts():
			_explode(h)
		return false
	var flat := Vector3(position.x, 0, position.z)
	if h.arena.blocked(flat, 0.05) and kind != "wave":
		if _bursts():
			_explode(h)
		else:
			h.fx.burst(flat, Color(0.8, 0.75, 0.6), 4, 3.0)
		return false
	if team == 0:
		for f in h.foes_near(flat, radius + 1.6):
			if hit_set.has(f) or f.state == "spawn":
				continue
			if flat.distance_to(f.flat_pos()) > radius + f.radius:
				continue
			hit_set[f] = true
			if _bursts():
				_explode(h)
				return false
			var force := 3.5 if kind == "arrow" else 6.0
			h.damage_foe(f, dmg, source, vel.normalized(), force)
			if kind in ["arrow", "quarrel", "soularrow", "knife", "axe"]:
				Sfx.play("pierce", -5.0)
			if float(extra.get("stun", 0.0)) > 0.0 and f.alive:
				f.stun_t = maxf(f.stun_t, float(extra["stun"]))
			# Ricochet: the arrow leaps once to the nearest other foe.
			if kind == "arrow" and source is Hero and not extra.has("bounced") and int(h.cards.get("ricochet", 0)) > 0:
				var nxt: Actor = null
				var bd := 6.0
				for o in h.foes_near(flat, 6.0):
					if o != f and not hit_set.has(o) and o.state != "spawn" and flat.distance_to(o.flat_pos()) < bd:
						bd = flat.distance_to(o.flat_pos())
						nxt = o
				if nxt:
					extra["bounced"] = true
					var d := (nxt.flat_pos() - flat).normalized()
					vel = d * vel.length()
					rotation.y = atan2(d.x, d.z)
					life = maxf(life, 0.5)
					continue
			hits_left -= 1
			if hits_left <= 0:
				return false
		if h.boss and h.boss.alive and not hit_set.has(h.boss) and flat.distance_to(h.boss.flat_pos()) < radius + h.boss.radius:
			hit_set[h.boss] = true
			if _bursts():
				_explode(h)
				return false
			h.damage_foe(h.boss, dmg, source, vel.normalized(), 0.0)
			hits_left -= 1
			if hits_left <= 0:
				return false
	else:
		var hero := h.hero
		if hero.alive and flat.distance_to(hero.flat_pos()) < radius + hero.radius * 0.8:
			h.damage_hero(dmg, source, 0.2 if source is Boss else 0.0)
			h.fx.burst(flat, Color(1.0, 0.4, 0.3), 6, 4.0)
			return false
	return true


## A thrown weapon: out for `back` seconds (or until a wall), then home to the
## thrower's hand, cutting everything on the way both ways.
func _tick_return(dt: float, h: Hunt) -> bool:
	var flat := Vector3(position.x, 0, position.z)
	var src := source as Actor
	var back := float(extra.get("back", 0.4))
	var going := not extra.has("returning")
	if going and (life <= float(extra.get("life", 1.0)) - back or h.arena.blocked(flat, 0.05)):
		extra["returning"] = true
		hit_set.clear()
		going = false
	if not going:
		if src == null or not is_instance_valid(src) or not src.alive:
			return false
		var to := src.flat_pos() - flat
		if to.length() < 0.7 or life <= 0.0:
			return false
		vel = to.normalized() * maxf(vel.length(), 18.0) * (1.0 + dt * 2.0)
	for f in h.foes_near(flat, radius + 1.6):
		if hit_set.has(f) or f.state == "spawn":
			continue
		if flat.distance_to(f.flat_pos()) > radius + f.radius:
			continue
		hit_set[f] = true
		h.damage_foe(f, dmg, source, vel.normalized(), 4.0)
		h.fx.burst(f.flat_pos(), Color(1.0, 0.7, 0.45), 4, 4.0)
	if randf() < 0.5:
		h.fx.embers_at(flat, Color(1.0, 0.6, 0.3), 1, 0.2)
	return true


## Fire bursts where it lands; so do the hero's sparks and splashing orbs.
func _bursts() -> bool:
	return kind == "fireball" or kind == "spark" or kind == "firebolt" or (kind == "orb" and splash > 0.0 and team == 0)


## A seeking shot turns toward the nearest foe ahead of it.
func _steer(dt: float, h: Hunt) -> void:
	var flat := Vector3(position.x, 0, position.z)
	var best: Actor = null
	var bd := 8.0
	for f in h.foes_near(flat, 8.0):
		if hit_set.has(f) or f.state == "spawn" or not f.alive:
			continue
		var d := flat.distance_to(f.flat_pos())
		if d < bd:
			bd = d
			best = f
	if h.boss and h.boss.alive and not hit_set.has(h.boss) and flat.distance_to(h.boss.flat_pos()) < bd:
		best = h.boss
	if best == null:
		return
	var want: Vector3 = (best.flat_pos() - flat).normalized()
	var cur := vel.normalized()
	var spd := vel.length()
	var turn := clampf(cur.signed_angle_to(want, Vector3.UP), -7.0 * dt, 7.0 * dt)
	vel = cur.rotated(Vector3.UP, turn) * spd
	rotation.y = atan2(vel.x, vel.z)


func _explode(h: Hunt) -> void:
	var at := Vector3(position.x, 0, position.z)
	var r := maxf(splash, 1.2)
	if kind == "orb":
		h.fx.vfx.impact(&"shadow", at, r, Fx.VfxLib.NO_TINT, &"light")
		h.fx.flash_light(at, Color(0.7, 0.4, 1.0), 3.0, r * 3.0, 0.2)
		Sfx.play("impact", -8.0)
	else:
		# Fire lands as fire: a torn ring of flame and a scorch, with a wall
		# of flame on the wisp's bolts.
		h.fx.flame_burst(at, r, kind == "firebolt", Color(1.0, 0.55, 0.18), &"light")
		Sfx.play("fire_hit", -6.0)
	var any := false
	for f in h.foes_near(at, r + 1.0):
		if at.distance_to(f.flat_pos()) <= r + f.radius:
			h.damage_foe(f, dmg, source, (f.flat_pos() - at).normalized(), 5.0)
			any = true
	if h.boss and h.boss.alive and at.distance_to(h.boss.flat_pos()) <= r + h.boss.radius:
		h.damage_foe(h.boss, dmg, source, Vector3.ZERO, 0.0)
		any = true
	if any:
		h.shake(0.08)
	if source is Hero and int(h.cards.get("pyre", 0)) > 0:
		h.add_pyre(at, r * 0.8, 2.5, dmg * 0.45)
