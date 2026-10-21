class_name Enemy
extends Actor
## A risen skeleton. States: spawn (climbing out of the ground, untouchable),
## chase, windup (committed to an attack, telegraphed), recover, dead.

var kind := "minion"
var def: Dictionary
var state := "spawn"
var state_t := 0.0
var atk_cd := 0.0
var dmg := 10.0
var reach := 1.2
var elite := false
var affixes: Array = []
var elite_name := ""
var xp_value := 1
var tele: MeshInstance3D
var aim := Vector3.ZERO
var aim_yaw := 0.0
var strafe := 1.0
var nameplate: Label3D
var warded_t := 0.0
var _sink := 0.0
var _hit_cd := {}
## While > 0 the foe is reeling from a hit and does not move or start attacks.
var hit_t := 0.0
const SPAWN_TIME := 0.95


func setup(h: Hunt, kind_: String, tier: Dictionary, elite_ := false) -> void:
	hunt = h
	kind = kind_
	def = DB.ENEMIES[kind]
	elite = elite_
	max_hp = def["hp"] * tier["hp"] * (1.0 + hunt.progress() * 0.6)
	dmg = def["dmg"] * tier["dmg"]
	speed = def["speed"] * randf_range(0.92, 1.08)
	radius = def["radius"]
	mass = def["mass"]
	reach = def["reach"]
	xp_value = def["xp"]
	strafe = 1.0 if randf() < 0.5 else -1.0
	var rim := Color(0.45, 0.6, 1.0)
	build_model(def["model"], def["weapons"], rim, 0.45, Color(1.0, 0.55, 0.15, 1.0))
	var sc: float = def["scale"]
	if elite:
		max_hp *= 4.5
		dmg *= 1.5
		radius *= 1.3
		mass *= 2.5
		xp_value *= 6
		sc *= 1.38
		var a: Array = DB.ELITE_AFFIXES.keys()
		a.shuffle()
		affixes = a.slice(0, 1 if tier["id"] == "normal" else 2)
		var c: Color = DB.ELITE_AFFIXES[affixes[0]]["color"]
		set_tint(Color(c.r, c.g, c.b, 0.8))
		if "swift" in affixes:
			speed *= 1.45
		elite_name = "%s%s %s" % [DB.ELITE_NAMES_A.pick_random(), DB.ELITE_NAMES_B.pick_random(), DB.ELITE_TITLES.pick_random()]
		nameplate = Label3D.new()
		nameplate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		nameplate.no_depth_test = true
		nameplate.pixel_size = 0.006
		nameplate.font = hunt.fx.title_font
		nameplate.font_size = 48
		nameplate.outline_size = 14
		nameplate.modulate = c.lightened(0.3)
		nameplate.outline_modulate = Color(0, 0, 0, 0.9)
		var tags := []
		for af in affixes:
			tags.append(DB.ELITE_AFFIXES[af]["name"])
		nameplate.text = "%s\n%s" % [elite_name, " · ".join(tags)]
		nameplate.position = Vector3(0, 2.9, 0)
		add_child(nameplate)
	model.scale = Vector3.ONE * sc
	hp = max_hp
	state = "spawn"
	var spawn_anim: String = def["anim"]["spawn"]
	var dur := SPAWN_TIME
	play(spawn_anim, 0.0, anim_length(spawn_anim) / dur * 0.9)
	state_t = dur
	model.position.y = -1.7 * sc
	atk_cd = randf_range(0.2, 0.8)


func tick(dt: float) -> void:
	if not alive:
		_tick_dead(dt)
		return
	tick_common(dt)
	state_t -= dt
	atk_cd -= dt
	warded_t -= dt
	var hero := hunt.hero
	var to_hero := hero.flat_pos() - flat_pos()
	var dist := to_hero.length()
	if state == "spawn":
		# Climbing out of the grave.
		var k := 1.0 - clampf(state_t / SPAWN_TIME, 0.0, 1.0)
		model.position.y = lerpf(-1.7 * model.scale.y, 0.0, 1.0 - pow(1.0 - minf(k * 1.4, 1.0), 2.0))
		if state_t <= 0.0:
			model.position.y = 0.0
			state = "chase"
		return
	if freeze_t > 0.0 or stun_t > 0.0:
		if state == "windup":
			_cancel_windup()
		return
	if hit_t > 0.0:
		hit_t -= dt
		return
	match state:
		"chase":
			_chase(dt, to_hero, dist)
		"windup":
			face(aim_yaw, dt, 10.0)
			if def["ai"] == "ranged":
				# Track the hero until most of the windup is spent, then lock.
				if state_t > 0.3:
					aim_yaw = yaw_to(position, hero.position)
					if tele:
						tele.rotation.y = aim_yaw
						tele.position = flat_pos() + dir_of(aim_yaw) * reach * 0.5 + Vector3(0, 0.04, 0)
			if state_t <= 0.0:
				_release()
		"recover":
			if state_t <= 0.0:
				state = "chase"


func _chase(dt: float, to_hero: Vector3, dist: float) -> void:
	var want := Vector3.ZERO
	var ai: String = def["ai"]
	var hero := hunt.hero
	if ai == "melee":
		want = to_hero / maxf(dist, 0.01)
		if dist <= reach + hero.radius + 0.15 and atk_cd <= 0.0:
			_windup()
			return
	else:
		var keep: float = reach * 0.7
		if dist > reach * 0.95:
			want = to_hero / maxf(dist, 0.01)
		elif dist < keep * 0.6:
			want = -to_hero / maxf(dist, 0.01)
		else:
			want = to_hero.cross(Vector3.UP).normalized() * strafe * 0.5
		if dist <= reach and atk_cd <= 0.0 and hunt.on_screen(position, 1.0):
			_windup()
			return
	var spd := speed * hunt.foe_speed_mult
	position += want * spd * dt
	if want.length_squared() > 0.01:
		face(atan2(want.x, want.z) if ai == "melee" or dist > reach else yaw_to(position, hero.position), dt, 10.0)
		play(def["anim"]["run"], 0.15, clampf(spd / 3.2, 0.7, 1.5))
	else:
		face(yaw_to(position, hero.position), dt)
		play(def["anim"]["idle"], 0.2)


func _windup() -> void:
	state = "windup"
	var w: float = def["windup"] * (0.75 if "swift" in affixes else 1.0)
	state_t = w
	aim_yaw = yaw_to(position, hunt.hero.position)
	aim = hunt.hero.flat_pos()
	var atk: String = def["anim"]["attack"]
	var ai: String = def["ai"]
	# Time the swing so the blow lands as the windup ends.
	var len_ := anim_length(atk)
	var impact := len_ * 0.45
	play(atk, 0.08, clampf(impact / w, 0.5, 2.5), true)
	match ai:
		"melee":
			if kind == "warrior" or elite:
				tele = hunt.fx.telegraph(1, flat_pos(), aim_yaw, Vector2(reach + 0.6, 0), w, 0.9)
		"ranged":
			tele = hunt.fx.telegraph(2, flat_pos(), aim_yaw, Vector2(0.35, reach), w)
		"caster":
			var blast: float = def["blast"] * (1.25 if elite else 1.0)
			tele = hunt.fx.telegraph(0, aim, 0.0, Vector2(blast, 0), w)
			Sfx.play("enemy_windup", -6.0)


func _cancel_windup() -> void:
	if tele:
		hunt.fx.cancel(tele)
		tele = null
	state = "chase"
	atk_cd = 0.6


func _release() -> void:
	if tele:
		hunt.fx.cancel(tele)
		tele = null
	var hero := hunt.hero
	match str(def["ai"]):
		"melee":
			var d := hero.flat_pos().distance_to(flat_pos())
			var ang := absf(angle_difference(aim_yaw, yaw_to(position, hero.position)))
			if d <= reach + hero.radius + 0.35 and ang < 1.1:
				hunt.damage_hero(dmg, self)
			Sfx.play("atk_enemy", -8.0)
		"ranged":
			var dir := dir_of(aim_yaw)
			hunt.spawn_proj("bolt", flat_pos() + dir * 0.6, dir * float(def["proj_speed"]), dmg, 1, self)
			Sfx.play("atk_archer", -9.0, 0.8)
		"caster":
			var blast: float = def["blast"] * (1.25 if elite else 1.0)
			hunt.fx.ring(aim, blast * 1.1, Color(0.7, 0.3, 1.0), 0.4)
			hunt.fx.burst(aim, Color(0.75, 0.35, 1.0), 14, 7.0, 1.0)
			hunt.fx.flash_light(aim, Color(0.7, 0.3, 1.0), 4.0, 5.0, 0.3)
			Sfx.play("boom", -8.0, 1.2)
			if hero.flat_pos().distance_to(aim) <= blast + hero.radius * 0.5:
				hunt.damage_hero(dmg, self)
	state = "recover"
	state_t = 0.35
	atk_cd = float(def["cooldown"]) * (0.7 if "swift" in affixes else 1.0) * randf_range(0.85, 1.15)


## Light foes flinch when hit: a short stagger so blows read as blows.
func stagger() -> void:
	if elite or state != "chase" or kind in ["warrior", "mage"]:
		return
	hit_t = 0.18
	play(def["anim"]["hit"], 0.04, 1.6, true)


func can_hit(id: int, cd: float) -> bool:
	var now := hunt.time
	if now < float(_hit_cd.get(id, -10.0)):
		return false
	_hit_cd[id] = now + cd
	return true


func die() -> void:
	alive = false
	if tele:
		hunt.fx.cancel(tele)
		tele = null
	if nameplate:
		nameplate.queue_free()
		nameplate = null
	set_flash(0.0)
	anim.speed_scale = 1.0
	play(def["anim"]["die"], 0.05, 1.9)
	state_t = 0.45
	_sink = 0.0


func _tick_dead(dt: float) -> void:
	if knock.length_squared() > 0.0001:
		position += knock * dt
		knock = knock.move_toward(Vector3.ZERO, 22.0 * dt)
	state_t -= dt
	if state_t <= 0.0:
		_sink += dt
		position.y = -_sink * 3.0
		if _sink > 0.4:
			queue_free()
