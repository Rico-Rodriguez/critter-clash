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
	life = float(ex.get("life", 0.9 if kind == "arrow" else 1.6))
	radius = {"arrow": 0.4, "fireball": 0.45, "bolt": 0.35, "spear": 0.45, "wave": float(ex.get("width", 1.2)), "orb": 0.5, "axe": 0.7}.get(kind, 0.4)
	rotation = Vector3(0, atan2(v.x, v.z), 0)
	active = true
	visible = true


## Returns false when the projectile is spent.
func tick(dt: float, h: Hunt) -> bool:
	life -= dt
	position += vel * dt
	if kind == "axe":
		body.rotation.y += dt * 22.0
	if kind == "fireball" or kind == "orb":
		_ember_t -= dt
		if _ember_t <= 0.0:
			_ember_t = 0.03
			h.fx.embers_at(position - Vector3(0, 1.0, 0) - vel.normalized() * 0.3, Color(1.0, 0.45, 0.12) if kind == "fireball" else Color(0.7, 0.35, 1.0), 1, 0.1)
	if life <= 0.0:
		if kind == "fireball":
			_explode(h)
		return false
	var flat := Vector3(position.x, 0, position.z)
	if h.arena.blocked(flat, 0.05) and kind != "wave":
		if kind == "fireball":
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
			if kind == "fireball":
				_explode(h)
				return false
			var force := 3.5 if kind == "arrow" else 6.0
			h.damage_foe(f, dmg, source, vel.normalized(), force)
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
			if kind == "fireball":
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


func _explode(h: Hunt) -> void:
	var at := Vector3(position.x, 0, position.z)
	var r := maxf(splash, 1.2)
	h.fx.ring(at, r * 1.15, Color(1.0, 0.5, 0.15), 0.32, 0.18)
	h.fx.burst(at, Color(1.0, 0.55, 0.2), 14, 7.0, 0.8)
	h.fx.embers_at(at, Color(1.0, 0.45, 0.1), 6, r * 0.5)
	h.fx.flash_light(at, Color(1.0, 0.55, 0.25), 3.0, r * 3.0, 0.2)
	Sfx.play("impact", -8.0)
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
