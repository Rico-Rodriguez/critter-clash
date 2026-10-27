extends Node3D
## The sidekick at the hero's side in a hunt: moves on its own
## (sidekick_motor.gd: lagged follow, wander, sprint, blink back), turns to
## face where it goes, animates from its own rig with procedural fallbacks,
## and every few seconds winds up and uses its one ability on the hit frame. Damage is a share of the
## hero's damage (sidekick_db.gd), so it never outclasses the hero. It cannot
## be hurt. Preloaded by hunt_state.gd (no class_name: OTA packs).

const SDB := preload("res://src/data/sidekick_db.gd")
const Look := preload("res://src/core/sidekick_look.gd")
const Motor := preload("res://src/hunt/sidekick_motor.gd")
const PetLife := preload("res://src/hunt/pet_life.gd")
const PetFx := preload("res://src/hunt/pet_fx.gd")
const PetAnim := preload("res://src/hunt/pet_anim.gd")

var hunt: Node
var id := ""
## The breed behind the id (cards and clips key on it; bred individuals are "x7").
var species := ""
var def: Dictionary
var ab: Dictionary
var bond := 1
var evolved := false
var stage := 1
var look: Dictionary
## Seconds until the ability is ready, and its full cooldown.
var cd := 2.0
var cd_max := 5.0
## Foes this sidekick finished off this hunt (the HUD shows it).
var slain := 0
var _bob := 0.0
## Body-language layer (pet_life.gd): pop-in, fidgets, cheers.
var _life := PetLife.new_life(0)
var motor := Motor.new()
## Procedural pose layer between the node and the model (lunge, hop, recoil,
## bank), so the rig's clips and the fallbacks stack.
var pivot := Node3D.new()
## A wound-up ability waiting for its hit frame.
var _pending := false
var _windup := 0.25
var _dur := 0.6
## Body language of the move in hand (pet_anim.gd style), and how long ago it
## began, which keeps counting after the move so the follow-through plays out.
var _style := "lunge"
var _act_t := 99.0
var _prev_vel := Vector3.ZERO
var _acc := 0.0
var _dust_t := 0.0
var _last_hp := -1.0
var _flinch_cd := 0.0
var _was_closing := false
var _last_state := -1
## Timings (s): wind-up to the hit frame, and the whole move.
const ATTACK_TIME := Vector2(0.22, 0.55)
const SPECIAL_TIME := Vector2(0.32, 0.8)
const HIT_TIME := 0.32
## Hunt-only readability: the companion is drawn a bit bigger than in camp
## (no ring under it: the art lock has no decorative rings).
const HUNT_SCALE := 1.2


func setup(h: Node, sid: String, kills: int) -> void:
	hunt = h
	id = sid
	def = SDB.def(id)
	species = SDB.species(id)
	ab = def["ability"]
	bond = SDB.bond_level(kills)
	stage = SDB.stage_of(bond)
	evolved = stage == 2
	look = Look.build(id, evolved, stage)
	pivot.name = "Pose"
	add_child(pivot)
	pivot.add_child(look["root"])
	(look["root"] as Node3D).scale *= HUNT_SCALE * float(def.get("hunt_scale", 1.0))
	Look.play(look, "idle")
	_life = PetLife.new_life(hash(id), str(ab["kind"]))
	cd_max = float(ab["cd"])
	cd = 0.2 if str(def.get("perk", "")) == "eager" else minf(2.0, cd_max)
	motor.fly = float(def["fly"])
	motor.rng.seed = hash(id)
	motor.pos = motor.slot(hunt.hero.position, hunt.hero.rotation.y)
	motor.yaw = hunt.hero.rotation.y
	position = motor.pos


func display_name() -> String:
	return SDB.stage_name(id, stage)


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
	var k := share * float(SDB.STAGE_DMG[stage]) * (1.0 + SDB.POWER_PER * _card("power"))
	return float(hunt.hero.dmg) * k


func reach_mult() -> float:
	return (SDB.REACH_MULT if bond >= SDB.BOND_REACH else 1.0) * float(def.get("reach", 1.0))


func cooldown() -> float:
	return cd_max * float(SDB.STAGE_COOLDOWN[stage]) / (1.0 + SDB.HASTE_PER * _card("haste"))


func tick(dt: float) -> void:
	var hero: Node3D = hunt.hero
	_bob += dt
	_flinch_cd = maxf(_flinch_cd - dt, 0.0)
	# Flinch when the hero is struck (it can't be hurt itself).
	if _last_hp >= 0.0 and float(hero.hp) < _last_hp - 0.5 and _flinch_cd <= 0.0 and not _pending:
		if motor.act(Motor.S.HIT, 0.0, HIT_TIME, hero.position):
			_flinch_cd = 1.5
	_last_hp = float(hero.hp)
	var arena = hunt.get("arena")
	var was := position
	var blk := Callable()
	var flow := Callable()
	var res := Callable()
	if arena != null:
		blk = func(p: Vector3) -> bool: return arena.blocked(p, 0.35)
		flow = func(p: Vector3) -> Vector3: return arena.flow_dir(p)
		res = func(p: Vector3) -> Vector3: return arena.resolve(p, 0.3)
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	var seen := Callable()
	if cam:
		seen = func(p: Vector3) -> bool: return cam.is_position_in_frustum(p + Vector3(0, 0.5, 0))
	if motor.step(dt, hero.position, hero.rotation.y, float(hero.speed), blk, flow, res, seen):
		_blink(was)
	if motor.aborted:
		# Its target got away before it arrived: try again shortly.
		motor.aborted = false
		_pending = false
		cd = 0.3
	var fly := float(def["fly"])
	position = Vector3(motor.pos.x, fly + (sin(_bob * 2.6) * 0.12 if fly > 0.0 else 0.0), motor.pos.z)
	rotation.y = motor.yaw
	_animate(dt)
	cd -= dt
	if _pending:
		if motor.take_hit():
			_pending = false
			_fire()
	elif cd <= 0.0 and hunt.phase != "defeat":
		var at = _wants_to_act()
		if at == null:
			cd = 0.3
		else:
			_wind_up(at)


## Blinked back after falling far behind: a puff where it was and a crisp
## spark where it lands.
func _blink(from: Vector3) -> void:
	var fx = hunt.fx
	if fx == null:
		return
	fx.puff(Vector3(from.x, 0, from.z), Color(0.5, 0.5, 0.55, 0.5), 5, 0.5, 1.0)
	fx.burst(Vector3(motor.pos.x, 0, motor.pos.z), def["color"], 6, 3.0, 0.6)
	Sfx.play("dodge", -10.0, 1.3)


## Where it would aim its ability now, or null when there's nothing to use it
## on (the ability itself still decides; this only starts the wind-up).
func _wants_to_act():
	var hero = hunt.hero
	var k := str(ab["kind"])
	if k == "mend":
		if hero.hp < hero.max_hp or not hunt.foes_near(hero.position, float(ab["radius"]) * reach_mult()).is_empty():
			return hero.position
		return null
	if k == "thorns":
		return hero.position if not hunt.foes_near(hero.position, float(ab["radius"]) * reach_mult()).is_empty() else null
	var f: Node3D = hunt.nearest_foe(hero.position, 8.0 * reach_mult())
	return f.position if f != null else null


## Melee moves walk or run up to the target before the wind-up (no snapping
## onto it); ranged and hero-centred moves cast from where it stands.
const MELEE_KINDS := {"snap": 0.8, "bash": 0.9, "leech": 0.9, "shadowstrike": 0.9}
func _approach_point(at: Vector3) -> Vector3:
	var k := str(ab["kind"])
	var from := Vector3(motor.pos.x, 0, motor.pos.z)
	var to := Vector3(at.x, 0, at.z)
	var gap := 0.0
	if MELEE_KINDS.has(k):
		gap = MELEE_KINDS[k]
	elif k == "breath":
		gap = float(ab["range"]) * reach_mult() * 0.45
	else:
		return Vector3.INF
	if from.distance_to(to) <= gap + Motor.APPROACH_REACH:
		return Vector3.INF
	return to + (from - to).normalized() * gap


func is_special() -> bool:
	return str(ab["kind"]) in SDB.SPECIAL_KINDS


func _wind_up(at: Vector3) -> void:
	var t := SPECIAL_TIME if is_special() else ATTACK_TIME
	_windup = t.x
	_dur = t.y
	_style = PetAnim.style_for(str(ab["kind"]))
	motor.act(Motor.S.SPECIAL if is_special() else Motor.S.ATTACK, t.x, t.y, at, _approach_point(at))
	_pending = true
	cd = 0.3
	if hunt.fx:
		# Anticipation: its element gathers where the move will come from.
		var k := str(ab["kind"])
		PetFx.windup(self, k, _el(KIT_EL.get(k, &"physical")), _tint(_kit_color(k)), stage, is_special(), at)
	Sfx.play("charge" if is_special() else "swing", -14.0, 1.35)


## The hit frame: the ability lands (its own VFX/SFX), plus a small spark.
func _fire() -> void:
	# No ability moves the node any more (they used to snap it onto the
	# target, which read as a teleport); the motor walked it there instead.
	var ok := _use()
	if ok and def.has("echo"):
		_echo()
	if ok:
		cd = cooldown()
		if hunt.fx:
			hunt.fx.burst(Vector3(position.x, maxf(position.y - 0.6, 0.0), position.z), def["color"], 5, 2.5, 0.8)
	else:
		cd = 0.3
		motor.action_t = minf(motor.action_t, 0.1)


## The element each move is drawn in when the pet has none of its own, and the
## colour (the pet's own unless the move has a fixed one, like flame).
const KIT_EL := {"mend": &"heal", "breath": &"fire", "bone_toss": &"physical", "hex": &"shadow", "thorns": &"nature", "storm": &"storm", "snap": &"buff", "leech": &"blood", "bash": &"physical", "shadowstrike": &"shadow", "snare": &"nature"}


func _kit_color(k: String) -> Color:
	match k:
		"breath":
			return Color(0.35, 0.6, 1.0) if evolved else Color(1.0, 0.45, 0.12)
		"hex":
			return Color(0.7, 0.45, 1.0)
		"bash", "bone_toss":
			return Color(0.8, 0.76, 0.68)
	return def["color"]


## A bred element recolours the ability's VFX: its element wins over the kit's.
func _el(kit: StringName) -> StringName:
	return def.get("vfx_el", kit)


## A bred element's colour replaces the kit's own on its VFX.
func _tint(base: Color) -> Color:
	return Color(def["color"]).lightened(0.15) if def.has("vfx_el") else base


## Mixed attacks: right after its own cast, a hybrid or an echo-gened child
## casts its other parent's ability at ECHO_DMG (the numbers are captured by
## each kind before any timer, so restoring `ab` after is safe).
func _echo() -> void:
	var at := Vector3(position.x, 0.4, position.z)
	var c: Color = def["color"]
	if hunt.fx:
		hunt.fx.vfx.star(at + Vector3(0, 0.8, 0), 0.7, c.lightened(0.25), 0.16, 4.0)
		hunt.fx.vfx.sparks(at + Vector3(0, 0.6, 0), 8, 6.0, c, 0.3)
	var keep := ab
	var e: Dictionary = (def["echo"] as Dictionary).duplicate()
	for key in ["dmg", "burst"]:
		if e.has(key):
			e[key] = float(e[key]) * SDB.ECHO_DMG
	ab = e
	_use()
	ab = keep


## Clips from the rig where it has them; a procedural pose where it doesn't
## (and a lighter accent on top where it does).
func _animate(dt: float) -> void:
	var st := motor.state
	var t := motor.state_t
	# While a melee move is still closing in, it runs; the clip starts on
	# arrival so its contact frame lines up with the hit.
	var closing := motor.approaching()
	var fresh := st != _last_state or (_was_closing and not closing)
	_last_state = st
	_was_closing = closing
	var spd := motor.speed()
	if closing:
		st = Motor.S.SPRINT
	match st:
		Motor.S.ATTACK, Motor.S.SPECIAL, Motor.S.HIT:
			var which: String = ["attack", "special", "hit"][[Motor.S.ATTACK, Motor.S.SPECIAL, Motor.S.HIT].find(st)]
			if which == "special" and not Look.has(look, "special") and Look.has(look, "attack"):
				which = "attack"
			if fresh:
				Look.play(look, which, 0.06, 1.0, _dur if st != Motor.S.HIT else HIT_TIME)
		_:
			if spd > 0.3:
				var run := st == Motor.S.SPRINT and Look.has(look, "run")
				var ref := 2.6 if run else 1.8
				Look.play(look, "run" if run else "move", 0.2, clampf(spd / ref, 0.7, 1.9))
			else:
				Look.play(look, "idle", 0.25, 1.0)
	var has_clip := Look.has(look, _clip_key(st))
	var acting := st == Motor.S.ATTACK or st == Motor.S.SPECIAL
	if acting and fresh:
		_act_t = 0.0
	else:
		_act_t += dt
	var p := pose(st, t, spd, _windup, _dur, has_clip, _bob, _style, motor.fly > 0.0)
	if not acting and _act_t < _windup + PetAnim.TAIL:
		# The move is over; its follow-through still rings out of the body.
		p = PetAnim.add(p, PetAnim.strike(_style, _act_t, _windup, 0.35 if has_clip else 1.0))
	elif spd > 0.3 and not motor.is_action():
		p = PetAnim.add(p, _lean(dt))
		_dust(dt, st, spd)
	else:
		_prev_vel = motor.vel
	var phase: String = str(hunt.phase)
	var mood := "cheer" if phase == "victory" else ("wary" if phase == "boss_intro" else ("droop" if phase == "defeat" else ""))
	var lf: Dictionary = PetLife.step(_life, dt, spd < 0.3 and not motor.is_action(), mood)
	pivot.position = Vector3(0, float(p["y"]) + float(lf["y"]), p["z"])
	pivot.rotation = Vector3(float(p["pitch"]) + float(lf["pitch"]), float(p["spin"]) + float(lf["yaw"]), motor.bank + float(p.get("roll", 0.0)) + float(lf["roll"]))
	var sy: float = float(p["sy"]) * float(lf["sy"])
	pivot.scale = Vector3(1.0 / sqrt(sy), sy, 1.0 / sqrt(sy)) * float(lf["s"])


static func _clip_key(st: int) -> String:
	match st:
		Motor.S.ATTACK:
			return "attack"
		Motor.S.SPECIAL:
			return "special"
		Motor.S.HIT:
			return "hit"
	return "move"


## Leaning into a change of pace: speeding up tips it forward, braking back.
func _lean(dt: float) -> Dictionary:
	var fwd := Vector3(sin(motor.yaw), 0, cos(motor.yaw))
	var a := (motor.vel - _prev_vel).dot(fwd) / maxf(dt, 0.001)
	_prev_vel = motor.vel
	_acc = lerpf(_acc, a, 1.0 - exp(-8.0 * dt))
	return PetAnim.lean(Vector3(0, 0, _acc), motor.speed())


## Dust kicked up by a sprint, a skid when it brakes hard.
func _dust(dt: float, st: int, spd: float) -> void:
	_dust_t -= dt
	if not hunt.fx or motor.fly > 0.0 or _dust_t > 0.0:
		return
	var sprint := st == Motor.S.SPRINT and spd > 3.2
	var skid := _acc < -14.0 and spd > 1.5
	if not (sprint or skid):
		return
	_dust_t = 0.07 if sprint else 0.05
	var back := -Vector3(sin(motor.yaw), 0, cos(motor.yaw))
	var s := 0.24 * PetFx.k_for(stage) * (1.3 if skid else 1.0)
	hunt.fx.vfx.smoke(position + back * 0.25 + Vector3(randf_range(-0.12, 0.12), 0.06, 0), s, back * 0.8 + Vector3(0, 0.7, 0), 0.4)


## The procedural pose for a state at time t: lift y, forward z, pitch, spin,
## side lean and squash (sy). Attacks and specials play their move's style
## (pet_anim.gd); with a clip the accent is scaled down so it only adds
## weight. Pure, so tests can read it.
static func pose(st: int, t: float, spd: float, windup: float, dur: float, has_clip: bool, bob: float, style := "", flies := false) -> Dictionary:
	var o := {"y": 0.0, "z": 0.0, "pitch": 0.0, "spin": 0.0, "roll": 0.0, "sy": 1.0}
	var k := 0.35 if has_clip else 1.0
	match st:
		Motor.S.ATTACK, Motor.S.SPECIAL:
			if style == "":
				style = "lunge" if st == Motor.S.ATTACK else "float"
			o = PetAnim.strike(style, t, windup, k)
		Motor.S.HIT:
			var u := clampf(t / HIT_TIME, 0.0, 1.0)
			var back := (1.0 - u) * (1.0 - u)
			o["z"] = -0.3 * back * k
			o["pitch"] = -0.42 * back * k
			o["roll"] = sin(u * 26.0) * 0.12 * (1.0 - u) * k
			o["sy"] = 1.0 - 0.18 * (1.0 - u) * (1.0 - u) + 0.04 * sin(u * PI)
		_:
			var g := PetAnim.flap(spd, bob) if flies else PetAnim.gait(spd, bob, 6.0)
			if has_clip and spd > 0.3:
				g["y"] = float(g["y"]) * k
				g["roll"] = float(g["roll"]) * k
			o = g
	return o


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


## The attack pose now comes from the wind-up (_wind_up/_animate); kept so
## every ability path reads the same.
func _attack_anim() -> void:
	pass


## Uses the ability. False when there was nothing to use it on. The damage
## is here; every effect is drawn by pet_fx.gd.
func _use() -> bool:
	var fx = hunt.fx
	var col: Color = def["color"]
	match str(ab["kind"]):
		"mend":
			var hero = hunt.hero
			if hero.hp >= hero.max_hp and hunt.foes_near(hero.position, float(ab["radius"]) * reach_mult()).is_empty():
				return false
			hero.hp = minf(hero.hp + hero.max_hp * float(ab["heal"]) * float(SDB.STAGE_DMG[stage]) * hunt.heal_mult(), hero.max_hp)
			var r := float(ab["radius"]) * reach_mult()
			PetFx.mend(self, _el(&"heal"), col, hero.flat_pos(), r, stage)
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
			var flame := _tint(_kit_color("breath"))
			# Swoop toward the pack, then breathe along the cone.
			var start := to - fwd * minf(rng * 0.45, from.distance_to(to))
			# One continuous jet that widens into the cone, not stamped bursts.
			PetFx.breath(self, _el(&"fire"), flame, start, fwd, rng, float(ab["cone"]), stage)
			for f in hunt.foes_near(start, rng + 0.5):
				var to_f: Vector3 = f.flat_pos() - start
				if to_f.length() <= rng + f.radius and fwd.dot(to_f.normalized()) > cos(float(ab["cone"])):
					_strike(f, hit_dmg(float(ab["dmg"])), 2.0)
			var mid := start + fwd * rng * 0.55
			hunt.add_pyre(mid, rng * 0.35, float(ab["burn"]), hit_dmg(float(ab["dmg"])) * 0.25)
			if _card("haste") > 0:
				fx.vfx.nova(_el(&"fire"), mid, rng * 0.5, 0.4, flame, &"skill")
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
			var prev := Vector3(position.x, 0.8 + maxf(position.y - 0.4, 0.0), position.z)
			for i in int(ab["bounces"]):
				if at == null:
					break
				hit.append(at)
				PetFx.bone_hop(self, _el(&"physical"), prev, at.flat_pos(), i, stage)
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
			var c2 := _tint(_kit_color("hex"))
			PetFx.hex_mark(self, _el(&"shadow"), c2, at, r, float(ab["delay"]), stage)
			var burst := hit_dmg(float(ab["burst"]))
			var me := self
			get_tree().create_timer(float(ab["delay"]), false).timeout.connect(func():
				if not is_instance_valid(me) or not is_instance_valid(hunt):
					return
				PetFx.hex_burst(me, _el(&"shadow"), c2, at, r, stage)
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
			PetFx.thorns(self, _el(&"nature"), col, hero.flat_pos(), r, stage)
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
			PetFx.storm(self, _el(&"storm"), _tint(Color(0.6, 0.85, 1.0)), pts, stage)
			_attack_anim()
			Sfx.play("thunder", -8.0, 1.2)
		"snap":
			var t := _target(5.0 * reach_mult())
			if t == null:
				return false
			var p: Vector3 = t.flat_pos()
			PetFx.snap(self, _el(&"buff"), p, stage)
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
				PetFx.leech(self, _el(&"blood"), col, at.flat_pos(), hero.flat_pos(), i, stage)
				_strike(at, hit_dmg(float(ab["dmg"])), 1.0)
				hero.hp = minf(hero.hp + hero.max_hp * float(ab["heal"]) * hunt.heal_mult(), hero.max_hp)
				at = _next_foe(at.position, 4.0 * reach_mult(), hit)
			_attack_anim()
			Sfx.play("lifesteal", -6.0)
		"bash":
			var t := _target(6.0 * reach_mult(), true)
			if t == null:
				return false
			var p: Vector3 = t.flat_pos()
			var r := float(ab["radius"]) * reach_mult()
			PetFx.bash(self, _el(&"physical"), p, r, stage)
			for f in hunt.foes_near(p, r):
				_strike(f, hit_dmg(float(ab["dmg"])), 4.0)
				if f.alive and not f is Boss:
					f.stun_t = maxf(f.stun_t, float(ab["stun"]))
					PetFx.dizzy(fx.vfx, f.flat_pos(), Color(1.0, 0.92, 0.5))
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
				PetFx.shadow_cut(self, _el(&"shadow"), col, f.flat_pos(), i, tough, stage)
				_strike(f, hit_dmg(float(ab["dmg"])) * (2.0 if tough else 1.0), 1.0)
			_attack_anim()
			Sfx.play("swing", -4.0, 1.4)
		"snare":
			var t := _target(7.0 * reach_mult(), true)
			if t == null:
				return false
			var at: Vector3 = t.flat_pos()
			var r := float(ab["radius"]) * reach_mult()
			var el := _el(&"nature")
			PetFx.snare_open(self, el, col, at, r, stage)
			for f in hunt.foes_near(at, r):
				if not f is Boss:
					f.stun_t = maxf(f.stun_t, float(ab["hold"]))
			var me := self
			var amount := hit_dmg(float(ab["dmg"]))
			for k in int(ab["pulses"]):
				get_tree().create_timer(0.4 * (k + 1), false).timeout.connect(func():
					if not is_instance_valid(me) or not is_instance_valid(hunt):
						return
					PetFx.snare_pulse(me, el, col, at, r, stage)
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
