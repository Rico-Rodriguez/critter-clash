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
## Which way this foe turns to get round a wall; kept so it follows the wall
## instead of dithering at it.
var _side := 1.0
var _hound_t := 0.0 # time spent chasing without closing in; harder tiers speed up
var nameplate: Label3D
var warded_t := 0.0
var _cast_t := 3.0
var _pool_t := 0.0
var _sink := 0.0
## Seconds the body lies after the death animation before it sinks.
var linger := DB.CORPSE_LINGER
var _hit_cd := {}
## While > 0 the foe is reeling from a hit and does not move or start attacks.
var hit_t := 0.0
const SPAWN_TIME := 0.95
var age := 0.0
var ward_hp := 0.0
var ward_mesh: MeshInstance3D
var dash_dir := Vector3.ZERO
var _dash_hit := false
var _trail_t := 0.0
var _fire_t := 0.0
## A ritual caller stands at the sigil and chants instead of fighting.
var channel := false


func setup(h: Hunt, kind_: String, tier: Dictionary, elite_ := false, force_affix := "") -> void:
	hunt = h
	kind = kind_
	def = DB.enemy(kind)
	elite = elite_
	max_hp = def["hp"] * tier["hp"] * (1.0 + hunt.progress() * 0.6) * (1.0 + DB.RUN_FOE_HP * (hunt.run_level - 1))
	dmg = def["dmg"] * tier["dmg"]
	speed = def["speed"] * randf_range(0.92, 1.08) * float(tier.get("spd", 1.0))
	radius = def["radius"]
	mass = def["mass"]
	reach = def["reach"]
	xp_value = def["xp"]
	strafe = 1.0 if randf() < 0.5 else -1.0
	_side = strafe
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
		affixes = a.slice(0, 1 if hunt.ai() <= 0.0 else (3 if hunt.ai() >= 2.5 else 2))
		if force_affix != "":
			affixes = [force_affix]
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
	if def.has("tint") and not elite:
		set_tint(def["tint"])
	if def.has("rival"):
		nameplate = Label3D.new()
		nameplate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		nameplate.no_depth_test = true
		nameplate.pixel_size = 0.006
		nameplate.font = hunt.fx.title_font
		nameplate.font_size = 44
		nameplate.outline_size = 14
		nameplate.modulate = Color(1.0, 0.55, 0.45)
		nameplate.outline_modulate = Color(0, 0, 0, 0.9)
		nameplate.text = str(def["name"])
		nameplate.position = Vector3(0, 2.6, 0)
		add_child(nameplate)
	if kind == "robber":
		_wear_sack()
	if elite and "warded" in affixes:
		ward_hp = max_hp * 0.25
		ward_mesh = Fx.make_ward(1.0)
		ward_mesh.position = Vector3(0, 1.0, 0)
		add_child(ward_mesh)
	model.scale = Vector3.ONE * sc
	if ward_mesh:
		ward_mesh.scale = Vector3.ONE * sc * 1.15
	hp = max_hp
	state = "spawn"
	var spawn_anim: String = def["anim"]["spawn"]
	var dur := SPAWN_TIME
	play(spawn_anim, 0.0, anim_length(spawn_anim) / dur * 0.9)
	state_t = dur
	model.position.y = -1.7 * sc
	atk_cd = randf_range(0.2, 0.8)


## The champion affixes that throw something at the hero now and then.
func _tick_casts(dt: float) -> void:
	_cast_t -= dt
	if _cast_t > 0.0:
		return
	var at := hunt.hero.flat_pos()
	if "frozen" in affixes:
		_cast_t = 5.0
		hunt.blast_at(at, 2.6, 1.0, dmg * 0.7, "slow", DB.ELITE_AFFIXES["frozen"]["color"], 0.4)
	elif "jailer" in affixes:
		_cast_t = 7.0
		hunt.blast_at(at, 2.2, 0.9, dmg * 0.4, "root", DB.ELITE_AFFIXES["jailer"]["color"], 0.25)
	elif "mortar" in affixes:
		_cast_t = 6.0
		for i in 3:
			var spot := at + Vector3(randf_range(-2.5, 2.5), 0, randf_range(-2.5, 2.5)) * (0.0 if i == 0 else 1.0)
			hunt.blast_at(spot, 2.0, 1.0 + i * 0.4, dmg * 0.7, "", DB.ELITE_AFFIXES["mortar"]["color"])
	elif "arcane" in affixes:
		_cast_t = 6.5
		var yaw0 := yaw_to(flat_pos(), at)
		for i in 3:
			hunt.beam_from(flat_pos(), yaw0 + TAU * i / 3.0, 1.3, dmg * 0.9, DB.ELITE_AFFIXES["arcane"]["color"])
	else:
		_cast_t = 99.0


## The Grave Robber carries his loot on his back.
func _wear_sack() -> void:
	var skel: Skeleton3D = model.find_child("Skeleton3D", true, false)
	var att := BoneAttachment3D.new()
	att.bone_name = "chest"
	skel.add_child(att)
	var sack := KK.prop("res://assets/kaykit/dungeon/coin_stack_medium.gltf")
	sack.position = Vector3(0, 0.05, -0.3)
	sack.scale = Vector3.ONE * 1.7
	att.add_child(sack)
	restyle(sack)
	for mi in KK.meshes(sack):
		mi.set_instance_shader_parameter("tint", Color(1.0, 0.8, 0.25, 0.5))


func _escape() -> void:
	hunt.fx.puff(flat_pos(), Color(0.35, 0.3, 0.25, 0.8), 10, 1.0, 2.5)
	hunt.fx.text(flat_pos(), "Escaped!", Color(1.0, 0.85, 0.4))
	Sfx.play("goblin_escape", -2.0)
	hunt.foes.erase(self)
	queue_free()


func tick(dt: float) -> void:
	if not alive:
		_tick_dead(dt)
		return
	tick_common(dt)
	age += dt
	if kind == "robber" and age > 16.0:
		_escape()
		return
	if elite and state == "chase":
		if "swift" in affixes:
			_trail_t -= dt
			if _trail_t <= 0.0:
				_trail_t = 0.2
				hunt.fx.puff(flat_pos(), Color(0.3, 0.55, 0.65, 0.35), 1, 0.2, 0.6)
		if "molten" in affixes:
			_fire_t -= dt
			if _fire_t <= 0.0:
				_fire_t = 0.6
				hunt.add_fire_patch(flat_pos(), 0.9, 3.0, dmg * 0.25)
		if "plagued" in affixes:
			_pool_t -= dt
			if _pool_t <= 0.0:
				_pool_t = 1.0
				hunt.add_fire_patch(flat_pos(), 1.1, 4.0, dmg * 0.2)
		_tick_casts(dt)
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
	if channel:
		face(yaw_to(position, hunt.ritual_at), dt, 6.0)
		if state_t <= 0.0:
			state_t = 1.4
			play(def["anim"]["attack"], 0.2, 0.8, true)
		return
	match state:
		"chase":
			_chase(dt, to_hero, dist)
		"windup":
			face(aim_yaw, dt, 10.0)
			if def["ai"] == "ranged":
				# Track the hero until most of the windup is spent, then lock.
				if state_t > 0.3:
					aim_yaw = yaw_to(position, _lead_pos(0.3))
					if tele:
						tele.rotation.y = aim_yaw
						tele.position = flat_pos() + dir_of(aim_yaw) * reach * 0.5 + Vector3(0, 0.04, 0)
			elif def["ai"] == "charge" and state_t > 0.2:
				aim_yaw = yaw_to(position, _lead_pos(0.3))
				if tele:
					tele.rotation.y = aim_yaw
					tele.position = flat_pos() + Vector3(0, 0.04, 0)
			if state_t <= 0.0:
				_release()
		"dash":
			_tick_dash(dt, hero)
		"recover":
			if state_t <= 0.0:
				state = "chase"


## A hound's lunge: a short, fast run along the lane it showed.
func _tick_dash(dt: float, hero: Hero) -> void:
	position += dash_dir * 17.0 * dt
	position = hunt.arena.resolve(position, radius)
	if _trail_t <= 0.0:
		_trail_t = 0.05
		hunt.fx.puff(flat_pos(), Color(0.35, 0.3, 0.26, 0.4), 1, 0.3, 0.8)
	_trail_t -= dt
	if not _dash_hit and flat_pos().distance_to(hero.flat_pos()) < radius + hero.radius + 0.25:
		_dash_hit = true
		hunt.damage_hero(dmg, self, 0.3)
		hero.push(dash_dir, 8.0)
	if state_t <= 0.0:
		state = "recover"
		state_t = 0.7
		atk_cd = float(def["cooldown"]) * randf_range(0.9, 1.2)


## Where the hero will be in `t` seconds if they keep running: harder tiers
## aim there instead of where they are.
func _lead_pos(t: float) -> Vector3:
	var h := hunt.hero
	return h.position + h.vel * t * minf(hunt.ai(), 1.0)


func _chase(dt: float, to_hero: Vector3, dist: float) -> void:
	var want := Vector3.ZERO
	var ai: String = def["ai"]
	var hero := hunt.hero
	if ai == "flee":
		_flee(dt, to_hero, dist)
		return
	# On the Long Road a hero in another room is reached through the gap.
	if hunt.mode == "trial":
		var via := hunt.arena.route(flat_pos(), hero.flat_pos())
		if via.distance_to(hero.flat_pos()) > 0.01:
			var tv := _around_walls(via - flat_pos(), INF)
			position += tv * speed * hunt.foe_speed_mult * dt
			face(atan2(tv.x, tv.z), dt, 10.0)
			play(def["anim"]["run"], 0.15)
			return
	if ai == "melee" or ai == "bomb" or ai == "charge" or ai == "slam":
		# Cut the corner: run to where the hero is going, and fan out so a pack
		# surrounds instead of queueing behind itself.
		var lead := hero.vel * clampf(dist / maxf(speed * hunt.foe_speed_mult, 1.0), 0.0, 1.0) * minf(0.4 + 0.2 * hunt.ai(), 1.0)
		want = (to_hero + lead) / maxf((to_hero + lead).length(), 0.01)
		if dist > 3.5 and ai != "slam":
			want = (want + to_hero.cross(Vector3.UP).normalized() * strafe * (0.3 + 0.15 * hunt.ai())).normalized()
		if ai == "charge":
			if dist < 8.5 and dist > 2.6 and atk_cd <= 0.0:
				_windup()
				return
		elif dist <= reach + hero.radius + 0.15 and atk_cd <= 0.0:
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
	# A long kite wears the pack's patience: on Veteran and up, foes that cannot
	# close the gap run harder the longer it lasts.
	if hunt.ai() > 0.0 and (ai == "melee" or ai == "slam") and dist > 4.0:
		_hound_t = minf(_hound_t + dt, 5.0)
		spd *= 1.0 + 0.05 * hunt.ai() * _hound_t
	elif dist < 3.0:
		_hound_t = 0.0
	want = _around_walls(want, dist, to_hero / maxf(dist, 0.01))
	position += want * spd * dt
	if want.length_squared() > 0.01:
		face(atan2(want.x, want.z) if ai == "melee" or ai == "bomb" or dist > reach else yaw_to(position, hero.position), dt, 10.0)
		play(def["anim"]["run"], 0.15, clampf(spd / 3.2, 0.7, 1.5))
	else:
		face(yaw_to(position, hero.position), dt)
		play(def["anim"]["idle"], 0.2)


## Turns `want` off a wall in the way. Pushing straight into the circles a
## wall is made of pins a foe in the dip between two of them. Heading for the
## hero, follow the arena's step field round the wall; otherwise (or outside
## the field) take the first clear heading on a fan, favouring the side it
## turned last.
func _around_walls(want: Vector3, dist: float, to_hero := Vector3.ZERO) -> Vector3:
	var l := want.length()
	if l < 0.01:
		return want
	var dir := want / l
	var look := radius + 0.8
	# Nothing to steer round when the target is closer than the wall.
	if dist < look or not _walled(dir, look):
		return dir * minf(l, 1.0)
	if dir.dot(to_hero) > 0.3:
		var f := hunt.arena.flow_dir(flat_pos())
		if f != Vector3.ZERO:
			return f * minf(l, 1.0)
	for a in [35.0, 70.0, 105.0, 140.0]:
		for sgn in [_side, -_side]:
			var d := dir.rotated(Vector3.UP, deg_to_rad(a) * sgn)
			if not _walled(d, look):
				_side = sgn
				return d * minf(l, 1.0)
	return dir * minf(l, 1.0)


func _walled(d: Vector3, look: float) -> bool:
	var p := flat_pos()
	return hunt.arena.blocked(p + d * look, radius) or hunt.arena.blocked(p + d * look * 0.5, radius)


## Runs straight away from the hero, around walls, and tires as it goes: a
## chase you keep is a chase you win.
func _flee(dt: float, to_hero: Vector3, dist: float) -> void:
	var away := -to_hero / maxf(dist, 0.01)
	var spd := speed * (1.0 - 0.18 * floorf(age / 4.0)) * hunt.foe_speed_mult
	var want := away
	for i in 6:
		if not hunt.arena.blocked(position + want * 1.4, radius):
			break
		want = away.rotated(Vector3.UP, deg_to_rad(40.0 * (i + 1)) * (1.0 if i % 2 == 0 else -1.0))
	position += want * spd * dt
	face(atan2(want.x, want.z), dt, 12.0)
	play(def["anim"]["run"], 0.12, clampf(spd / 3.2, 0.8, 1.8))


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
		"bomb", "necro", "slam":
			tele = hunt.fx.telegraph(0, flat_pos(), 0.0, Vector2(float(def["blast"]), 0), w)
			Sfx.play("enemy_windup", -6.0, 1.3)
		"charge":
			aim_yaw = yaw_to(position, _lead_pos(0.3))
			tele = hunt.fx.telegraph(2, flat_pos(), aim_yaw, Vector2(1.0, 7.5), w)
			Sfx.play("enemy_windup", -6.0, 1.6)


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
			# Expert and up: a spread of three, so a sidestep has to be a real one.
			var n := 3 if hunt.ai() >= 1.5 and not def.has("rival") else 1
			for i in n:
				var dir := dir_of(aim_yaw + (i - (n - 1) * 0.5) * deg_to_rad(14.0))
				hunt.spawn_proj("bolt", flat_pos() + dir * 0.6, dir * float(def["proj_speed"]), dmg, 1, self)
			Sfx.play("atk_archer", -9.0, 0.8)
		"caster":
			var blast: float = def["blast"] * (1.25 if elite else 1.0)
			hunt.fx.vfx.impact(&"nature" if def.get("root", false) else &"shadow", aim, blast)
			hunt.fx.flash_light(aim, Color(0.7, 0.3, 1.0), 4.0, 5.0, 0.3)
			Sfx.play("boom", -8.0, 1.2)
			if hero.flat_pos().distance_to(aim) <= blast + hero.radius * 0.5:
				hunt.damage_hero(dmg, self, 0.5)
				# Thorn shamans' circles bind: a rooted hero is a target.
				if def.get("root", false):
					hero.root_t = maxf(hero.root_t, 0.9)
		"bomb":
			var blast_r: float = def["blast"]
			var at := flat_pos()
			hunt.fx.flame_burst(at, blast_r)
			hunt.fx.puff(at, Color(0.3, 0.25, 0.2, 0.7), 8, 1.2, 3.0)
			hunt.fx.flash_light(at, Color(1.0, 0.55, 0.25), 5.0, 8.0, 0.3)
			hunt.shake(0.3)
			Sfx.play("boom", -3.0)
			if hero.flat_pos().distance_to(at) <= blast_r + hero.radius * 0.5:
				hunt.damage_hero(dmg, self, 0.7)
			for f in hunt.foes_near(position, blast_r + 1.0):
				if f != self and not f is Boss and at.distance_to(f.flat_pos()) <= blast_r:
					hunt.damage_foe(f, dmg * 0.8, self, (f.flat_pos() - at).normalized(), 9.0)
			hp = 0.0
			hunt._kill(self)
			return
		"slam":
			var sr: float = def["blast"]
			var sat := flat_pos()
			hunt.fx.vfx.nova(&"physical", sat, sr * 1.1, 0.35)
			hunt.fx.puff(sat, Color(0.3, 0.26, 0.2, 0.7), 10, 1.4, 3.5)
			hunt.fx.bone_burst(sat, 5, 6.0)
			hunt.shake(0.3)
			Sfx.play("quake", -4.0, 1.2)
			if hero.flat_pos().distance_to(sat) <= sr + hero.radius * 0.5:
				hunt.damage_hero(dmg, self, 0.8)
				hero.push((hero.flat_pos() - sat).normalized(), 14.0)
		"charge":
			dash_dir = dir_of(aim_yaw)
			_dash_hit = false
			state = "dash"
			state_t = 0.4
			play(def["anim"]["run"], 0.05, 2.2)
			Sfx.play("charge", -8.0, 1.6)
			return
		"necro":
			for i in 3:
				var a := TAU * i / 3.0 + randf() * 0.5
				var sp := hunt.arena.resolve(flat_pos() + Vector3(sin(a), 0, cos(a)) * 2.2, 0.5)
				if hunt.foes.size() < Hunt.MAX_FOES:
					hunt.spawn_foe("minion", sp)
			hunt.fx.vfx.nova(&"shadow", flat_pos(), 3.2, 0.5)
			Sfx.play("unlock_start", -4.0)
	state = "recover"
	state_t = 0.35
	atk_cd = float(def["cooldown"]) * (0.7 if "swift" in affixes else 1.0) * randf_range(0.85, 1.15)


## Light foes flinch when hit: a short stagger so blows read as blows.
func stagger() -> void:
	if elite or state != "chase" or kind in ["warrior", "mage", "necro", "robber", "bomber", "brute"]:
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
		linger -= dt
		if linger > 0.0:
			return
		_sink += dt
		position.y = -_sink * 3.0
		if _sink > 0.4:
			queue_free()
