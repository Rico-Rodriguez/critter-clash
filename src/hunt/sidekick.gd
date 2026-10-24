extends Node3D
## The sidekick at the hero's side in a hunt: follows (walking or flying),
## and every few seconds uses its one ability. Damage is a share of the
## hero's damage (sidekick_db.gd), so it never outclasses the hero. It cannot
## be hurt. Preloaded by hunt_state.gd (no class_name: OTA packs).

const SDB := preload("res://src/data/sidekick_db.gd")
const Look := preload("res://src/core/sidekick_look.gd")

var hunt: Node
var id := ""
var def: Dictionary
var ab: Dictionary
var bond := 1
var evolved := false
var look: Dictionary
## Seconds until the ability is ready, and its full cooldown.
var cd := 2.0
var cd_max := 5.0
## Foes this sidekick finished off this hunt (the HUD shows it).
var slain := 0
var _side := 1.0
var _bob := 0.0
var _act_t := 0.0
## Hunt-only readability: the companion is drawn a bit bigger than in camp,
## over a thin ground ring in the hero's team colour (one shared, unlit,
## crisp-alpha draw: no glow, no falloff).
const HUNT_SCALE := 1.2
const RING_COLOR := Color(0.35, 0.75, 1.0, 0.4)
static var _ring_mesh: TorusMesh
var ring: MeshInstance3D


func setup(h: Node, sid: String, kills: int) -> void:
	hunt = h
	id = sid
	def = SDB.ROSTER[id]
	ab = def["ability"]
	bond = SDB.bond_level(kills)
	evolved = bond >= SDB.BOND_EVOLVE
	look = Look.build(id, evolved)
	add_child(look["root"])
	(look["root"] as Node3D).scale *= HUNT_SCALE * float(def.get("hunt_scale", 1.0))
	_add_ring()
	Look.play(look, "idle")
	cd_max = float(ab["cd"])
	cd = minf(2.0, cd_max)
	_side = -1.0
	position = hunt.hero.position + Vector3(-1.2, 0, 0.8)


func _add_ring() -> void:
	if _ring_mesh == null:
		_ring_mesh = TorusMesh.new()
		_ring_mesh.inner_radius = 0.5
		_ring_mesh.outer_radius = 0.56
		_ring_mesh.rings = 40
		_ring_mesh.ring_segments = 3
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = RING_COLOR
		m.disable_receive_shadows = true
		_ring_mesh.material = m
	ring = MeshInstance3D.new()
	ring.name = "CompanionRing"
	ring.mesh = _ring_mesh
	ring.scale = Vector3(1.0, 0.05, 1.0)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)


func display_name() -> String:
	return str(def["evolved_name"]) if evolved and def.has("evolved_name") else str(def["name"])


func ability_name() -> String:
	return str(ab["name"])


func _card(effect: String) -> int:
	for cid in def.get("cards", []):
		if str(DB.CARDS[cid]["effect"]) == effect:
			return int(hunt.cards.get(cid, 0))
	return 0


## The ability's damage per hit: a share of the hero's, grown by evolving and
## by its power card.
func hit_dmg(share: float) -> float:
	var k := share * (SDB.EVOLVE_DMG if evolved else 1.0) * (1.0 + SDB.POWER_PER * _card("power"))
	return float(hunt.hero.dmg) * k


func reach_mult() -> float:
	return SDB.REACH_MULT if bond >= SDB.BOND_REACH else 1.0


func cooldown() -> float:
	return cd_max / (1.0 + SDB.HASTE_PER * _card("haste"))


func tick(dt: float) -> void:
	var hero: Node3D = hunt.hero
	_bob += dt
	_act_t = maxf(_act_t - dt, 0.0)
	var want: Vector3 = hero.position + Vector3(_side * 1.4, 0, 0.9).rotated(Vector3.UP, hero.rotation.y)
	var d := want - position
	d.y = 0.0
	var moving := d.length() > 0.4
	if moving:
		var spd := (float(hero.speed) + 1.0) * clampf(d.length() / 1.5, 0.6, 2.2)
		position += d.normalized() * minf(spd * dt, d.length())
		rotation.y = lerp_angle(rotation.y, atan2(d.x, d.z), 1.0 - exp(-10.0 * dt))
	var fly := float(def["fly"])
	position.y = fly + (sin(_bob * 2.6) * 0.12 if fly > 0.0 else 0.0)
	ring.position.y = 0.04 - position.y
	if _act_t <= 0.0:
		Look.play(look, "move" if moving else "idle")
	cd -= dt
	if cd <= 0.0 and hunt.phase != "defeat":
		if _use():
			cd = cooldown()
		else:
			cd = 0.3


## Picks a target near the hero. From Bond 8, champions and bosses first;
## `pack`: the foe with the most others around it (the thickest pack).
func _target(r: float, pack := false) -> Node3D:
	var hero: Node3D = hunt.hero
	var near: Array = hunt.foes_near(hero.position, r)
	if near.is_empty():
		return null
	if bond >= SDB.BOND_CHAMPIONS:
		for f in near:
			if f is Boss or (f is Enemy and (f as Enemy).elite):
				return f
	if pack:
		var best: Node3D = null
		var bn := -1
		for f in near:
			var n: int = hunt.foes_near(f.position, 2.5).size()
			if n > bn:
				bn = n
				best = f
		return best
	return hunt.nearest_foe(hero.position, r)


func _strike(f: Node3D, amount: float, force := 0.0) -> void:
	if f == null or not f.alive:
		return
	var dir: Vector3 = (f.position - position)
	dir.y = 0.0
	hunt.damage_foe(f, amount, self, dir.normalized() if dir.length() > 0.01 else Vector3.FORWARD, force)
	if not f.alive:
		slain += 1
		if str(ab["kind"]) == "snap":
			for i in int(ab.get("gold", 2)):
				hunt._drop("gold", f.flat_pos(), randi_range(1, 3))


func _attack_anim() -> void:
	Look.play(look, "attack", 0.05, 1.3)
	_act_t = 0.5


## Uses the ability. False when there was nothing to use it on.
func _use() -> bool:
	var fx = hunt.fx
	var col: Color = def["color"]
	match str(ab["kind"]):
		"mend":
			var hero = hunt.hero
			if hero.hp >= hero.max_hp and hunt.foes_near(hero.position, float(ab["radius"]) * reach_mult()).is_empty():
				return false
			hero.hp = minf(hero.hp + hero.max_hp * float(ab["heal"]) * (SDB.EVOLVE_DMG if evolved else 1.0) * hunt.heal_mult(), hero.max_hp)
			var r := float(ab["radius"]) * reach_mult()
			fx.ring(hero.flat_pos(), r, col, 0.5)
			fx.burst(hero.flat_pos() + Vector3(0, 1.0, 0), col, 10, 3.0, 1.5)
			for f in hunt.foes_near(hero.position, r):
				_strike(f, hit_dmg(float(ab["dmg"])))
			Sfx.play("sparkle", -6.0, 1.2)
		"breath":
			var t := _target(8.0 * reach_mult(), true)
			if t == null:
				return false
			var from := Vector3(position.x, 0.0, position.z)
			var to: Vector3 = t.flat_pos()
			var fwd := (to - from)
			fwd.y = 0.0
			fwd = fwd.normalized() if fwd.length() > 0.01 else Vector3.FORWARD
			rotation.y = atan2(fwd.x, fwd.z)
			var rng := float(ab["range"]) * reach_mult()
			var flame := Color(0.35, 0.6, 1.0) if evolved else Color(1.0, 0.45, 0.12)
			# Swoop toward the pack, then breathe along the cone.
			var start := to - fwd * minf(rng * 0.45, from.distance_to(to))
			position = Vector3(start.x, position.y, start.z)
			for i in 4:
				var p := start + fwd * rng * (0.2 + 0.24 * i)
				fx.flame_burst(p, 0.8 + 0.25 * i, false, flame)
			for f in hunt.foes_near(start, rng + 0.5):
				var to_f: Vector3 = f.flat_pos() - start
				if to_f.length() <= rng + f.radius and fwd.dot(to_f.normalized()) > cos(float(ab["cone"])):
					_strike(f, hit_dmg(float(ab["dmg"])), 2.0)
			var mid := start + fwd * rng * 0.55
			hunt.add_pyre(mid, rng * 0.35, float(ab["burn"]), hit_dmg(float(ab["dmg"])) * 0.25)
			if _card("haste") > 0:
				fx.ring(mid, rng * 0.5, flame, 0.4)
				for f in hunt.foes_near(mid, rng * 0.5):
					_strike(f, hit_dmg(float(ab["dmg"])) * 0.3)
			_attack_anim()
			Sfx.play("fire_trail", -4.0, 0.9)
		"bone_toss":
			var t := _target(7.0 * reach_mult())
			if t == null:
				return false
			var hit := []
			var at: Node3D = t
			var prev := Vector3(position.x, 0.6, position.z)
			for i in int(ab["bounces"]):
				if at == null:
					break
				hit.append(at)
				fx.lightning(PackedVector3Array([prev, at.flat_pos() + Vector3(0, 0.6, 0)]), Color(0.95, 0.9, 0.78))
				fx.bone_burst(at.flat_pos(), 3, 3.5)
				prev = at.flat_pos() + Vector3(0, 0.6, 0)
				_strike(at, hit_dmg(float(ab["dmg"])), 2.5)
				at = _next_foe(at.position, 4.0 * reach_mult(), hit)
			_attack_anim()
			Sfx.play("impact", -6.0, 1.3)
		"hex":
			var t := _target(7.0 * reach_mult())
			if t == null:
				return false
			var near: Array = hunt.foes_near(hunt.hero.position, 7.0 * reach_mult())
			for f in near:
				if f is Boss or (f.hp > t.hp):
					t = f
			_strike(t, hit_dmg(float(ab["dmg"])))
			var at: Vector3 = t.flat_pos()
			var r := float(ab["radius"]) * reach_mult()
			fx.telegraph(0, at, 0.0, Vector2(r, 0), float(ab["delay"]))
			var burst := hit_dmg(float(ab["burst"]))
			var me := self
			get_tree().create_timer(float(ab["delay"]), false).timeout.connect(func():
				if not is_instance_valid(me) or not is_instance_valid(hunt):
					return
				var c2 := Color(0.7, 0.45, 1.0)
				fx.ring(at, r, c2, 0.45)
				fx.burst(at, c2, 14, 6.0)
				for f in hunt.foes_near(at, r):
					_strike(f, burst)
				Sfx.play("boom", -8.0, 1.3))
			_attack_anim()
			Sfx.play("frost", -6.0, 0.8)
		"thorns":
			var hero = hunt.hero
			var r := float(ab["radius"]) * reach_mult()
			var near: Array = hunt.foes_near(hero.position, r)
			if near.is_empty():
				return false
			fx.ring(hero.flat_pos(), r, col, 0.5, 0.2)
			fx.burst(hero.flat_pos(), col, 16, 7.0, 0.3)
			for f in near:
				_strike(f, hit_dmg(float(ab["dmg"])), float(ab["push"]))
			_attack_anim()
			Sfx.play("thorns", -4.0)
		"storm":
			var t := _target(float(ab["range"]) * reach_mult())
			if t == null:
				return false
			var pts := PackedVector3Array([Vector3(position.x, position.y + 0.8, position.z)])
			var hit := []
			var at: Node3D = t
			for i in int(ab["chain"]):
				if at == null:
					break
				hit.append(at)
				pts.append(at.flat_pos() + Vector3(0, 0.8, 0))
				_strike(at, hit_dmg(float(ab["dmg"])), 1.0)
				at = _next_foe(at.position, 4.5 * reach_mult(), hit)
			fx.lightning(pts, Color(0.6, 0.85, 1.0))
			_attack_anim()
			Sfx.play("thunder", -8.0, 1.2)
		"snap":
			var t := _target(5.0 * reach_mult())
			if t == null:
				return false
			var p: Vector3 = t.flat_pos()
			position = Vector3(p.x, position.y, p.z) - (p - Vector3(position.x, 0, position.z)).normalized() * 0.8
			fx.burst(p, Color(1.0, 0.82, 0.3), 8, 5.0)
			_strike(t, hit_dmg(float(ab["dmg"])), 3.0)
			_attack_anim()
			Sfx.play("coin", -6.0, 1.1)
		"leech":
			var t := _target(6.0 * reach_mult())
			if t == null:
				return false
			var hero = hunt.hero
			var hit := []
			var at: Node3D = t
			for i in int(ab["bites"]):
				if at == null:
					break
				hit.append(at)
				fx.burst(at.flat_pos() + Vector3(0, 0.6, 0), Color(0.85, 0.2, 0.25), 6, 4.0)
				_strike(at, hit_dmg(float(ab["dmg"])), 1.0)
				hero.hp = minf(hero.hp + hero.max_hp * float(ab["heal"]) * hunt.heal_mult(), hero.max_hp)
				at = _next_foe(at.position, 4.0 * reach_mult(), hit)
			if not hit.is_empty():
				var last: Node3D = hit[hit.size() - 1]
				position = Vector3(last.position.x, position.y, last.position.z)
			_attack_anim()
			Sfx.play("lifesteal", -6.0)
		"bash":
			var t := _target(6.0 * reach_mult(), true)
			if t == null:
				return false
			var p: Vector3 = t.flat_pos()
			position = Vector3(p.x, position.y, p.z) - (p - Vector3(position.x, 0, position.z)).normalized() * 0.9
			var r := float(ab["radius"]) * reach_mult()
			fx.ring(p, r, col, 0.4, 0.18)
			fx.puff(p, Color(0.3, 0.27, 0.23, 0.6), 8, 1.5, 2.0)
			for f in hunt.foes_near(p, r):
				_strike(f, hit_dmg(float(ab["dmg"])), 4.0)
				if f.alive and not f is Boss:
					f.stun_t = maxf(f.stun_t, float(ab["stun"]))
			_attack_anim()
			Sfx.play("impact", -4.0, 0.8)
		"shadowstrike":
			var near: Array = hunt.foes_near(hunt.hero.position, 7.0 * reach_mult())
			if near.is_empty():
				return false
			near.sort_custom(func(a, b): return a.hp > b.hp)
			for i in mini(int(ab["strikes"]), near.size()):
				var f: Node3D = near[i]
				var tough: bool = f is Boss or (f is Enemy and (f as Enemy).elite)
				fx.puff(f.flat_pos(), Color(0.15, 0.1, 0.25, 0.7), 6, 0.8, 1.5)
				fx.burst(f.flat_pos() + Vector3(0, 0.7, 0), col, 6, 4.0)
				_strike(f, hit_dmg(float(ab["dmg"])) * (2.0 if tough else 1.0), 1.0)
			var last: Node3D = near[mini(int(ab["strikes"]), near.size()) - 1]
			if is_instance_valid(last):
				position = Vector3(last.position.x, position.y, last.position.z)
			_attack_anim()
			Sfx.play("swing", -4.0, 1.4)
		"snare":
			var t := _target(7.0 * reach_mult(), true)
			if t == null:
				return false
			var at: Vector3 = t.flat_pos()
			var r := float(ab["radius"]) * reach_mult()
			fx.ring(at, r, col, 0.5, 0.2)
			fx.burst(at, col, 14, 5.0, 0.4)
			for f in hunt.foes_near(at, r):
				if not f is Boss:
					f.stun_t = maxf(f.stun_t, float(ab["hold"]))
			var me := self
			var amount := hit_dmg(float(ab["dmg"]))
			for k in int(ab["pulses"]):
				get_tree().create_timer(0.4 * (k + 1), false).timeout.connect(func():
					if not is_instance_valid(me) or not is_instance_valid(hunt):
						return
					fx.ring(at, r * 0.8, col, 0.3)
					for f in hunt.foes_near(at, r):
						_strike(f, amount))
			_attack_anim()
			Sfx.play("thorns", -4.0, 0.8)
		_:
			return false
	return true


func _next_foe(from: Vector3, r: float, skip: Array) -> Node3D:
	var best: Node3D = null
	var bd := r
	for f in hunt.foes_near(from, r):
		if f in skip:
			continue
		var dd: float = Vector2(f.position.x - from.x, f.position.z - from.z).length()
		if dd < bd:
			bd = dd
			best = f
	return best
