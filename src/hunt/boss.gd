class_name Boss
extends Actor
## Gravemaw, the Barrow King. Every attack is telegraphed on the ground and
## can be walked or dashed out of. Below half health he enrages: faster,
## more spears, more graves.

var state := "intro"
var state_t := 0.0
var dmg := 30.0
var pattern := ""
var step := 0
var step_t := 0.0
var cd := 1.0
var enraged := false
var summons_done := 0
var tele: Array = []
var charge_dir := Vector3.ZERO
var charge_hit := false
var graves_at: Array = []
var last := ""
var fight_t := 0.0
var berserk := false
var cd_mult := 1.0
var add_t := 14.0
var display_name := ""
var title := ""
var boss_id := "gravemaw"
var def: Dictionary
## How close the boss wants to stand, and how near before it backs away.
var keep_dist := 3.2
var retreat_dist := 0.0


func setup(h: Hunt, tier: Dictionary) -> void:
	hunt = h
	var d: Dictionary = DB.boss_def(boss_id)
	def = d
	var aura: Color = d["color"]
	display_name = d["name"]
	title = d["title"]
	max_hp = d["hp"] * tier["hp"]
	hp = max_hp
	dmg = d["dmg"] * tier["dmg"]
	speed = d["speed"]
	radius = d["radius"]
	mass = d["mass"]
	build_model(d["model"], d["weapons"], aura, 0.55, Color(aura, 1.0))
	model.scale = Vector3.ONE * float(d["scale"])
	var occ: Vector2 = d["occluder"]
	hunt.arena.add_dynamic_occluder(self, occ.x, occ.y)
	# A crown of green fire over the King's head.
	var crown := GPUParticles3D.new()
	crown.amount = 40
	crown.lifetime = 0.8
	crown.local_coords = false
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	pm.emission_ring_radius = 0.45
	pm.emission_ring_inner_radius = 0.3
	pm.emission_ring_height = 0.05
	pm.emission_ring_axis = Vector3.UP
	pm.direction = Vector3.UP
	pm.spread = 10.0
	pm.initial_velocity_min = 1.2
	pm.initial_velocity_max = 2.2
	pm.gravity = Vector3.ZERO
	pm.color = aura
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 1))
	ramp.set_color(1, Color(1, 1, 1, 0))
	var rt := GradientTexture1D.new()
	rt.gradient = ramp
	pm.color_ramp = rt
	crown.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.35, 0.35)
	var sm := ShaderMaterial.new()
	sm.shader = Fx.SOFT
	sm.set_shader_parameter("intensity", 3.0)
	q.material = sm
	crown.draw_pass_1 = q
	crown.position = Vector3(0, 5.3, 0.1)
	add_child(crown)
	var glow := OmniLight3D.new()
	glow.light_color = aura
	glow.light_energy = 1.8
	glow.omni_range = 7.0
	glow.position = Vector3(0, 4.0, 0.8)
	add_child(glow)
	state = "intro"
	state_t = 2.4
	play("Skeletons_Awaken_Standing", 0.0, anim_length("Skeletons_Awaken_Standing") / 2.2)


func tick(dt: float) -> void:
	if not alive:
		state_t -= dt
		if state_t < 0.0:
			position.y -= dt * 0.6
		return
	tick_common(dt)
	state_t -= dt
	if state == "intro":
		if state_t <= 0.0:
			state = "chase"
			cd = 0.6
		return
	if freeze_t > 0.0 or stun_t > 0.0:
		return
	fight_t += dt
	if not berserk and fight_t > 150.0 - 40.0 * hunt.tier_i:
		_berserk()
	# The longer you kite, the more of his court arrives to cut you off.
	if state == "chase" and fight_t > 10.0:
		add_t -= dt
		if add_t <= 0.0:
			add_t = 20.0 - 4.0 * hunt.tier_i
			_call_court()
	if not enraged and hp < max_hp * 0.5:
		_enrage()
	if state == "chase" and (summons_done == 0 and hp < max_hp * 0.7 or summons_done == 1 and hp < max_hp * 0.35):
		summons_done += 1
		_begin("summon")
	var hero := hunt.hero
	var to := hero.flat_pos() - flat_pos()
	var dist := to.length()
	match state:
		"chase":
			cd -= dt
			if dist > 3.2:
				var spd := speed * (1.3 if enraged else 1.0)
				position += to / dist * spd * dt
				position = hunt.arena.resolve(position, radius * 0.6)
				play("Skeletons_Walking", 0.25, 1.1 if enraged else 0.85)
			else:
				play("Skeletons_Idle", 0.25)
			face(atan2(to.x, to.z), dt, 5.0)
			if cd <= 0.0:
				_choose(dist)
		"attack":
			_tick_pattern(dt, to, dist)


func _choose(dist: float) -> void:
	var options := []
	if dist < 5.5:
		options += ["cleave", "cleave", "quake"]
	else:
		options += ["charge", "spears"]
	options += ["graves", "spears"]
	options.erase(last)
	var p: String = options[randi() % options.size()]
	_begin(p)


func _begin(p: String) -> void:
	_clear_tele()
	pattern = p
	last = p
	state = "attack"
	step = 0
	step_t = 0.0
	var hero := hunt.hero
	var yaw := yaw_to(position, hero.position)
	var fast := 0.8 if enraged else 1.0
	match p:
		"cleave":
			rotation.y = yaw
			step_t = 0.95 * fast
			tele.append(hunt.fx.telegraph(1, flat_pos(), yaw, Vector2(5.0, 0), step_t, 1.1))
			play("Melee_2H_Attack_Chop", 0.1, anim_length("Melee_2H_Attack_Chop") * 0.5 / step_t, true)
			Sfx.play("boss_windup", -2.0)
		"quake":
			step_t = 1.15 * fast
			tele.append(hunt.fx.telegraph(0, flat_pos(), 0.0, Vector2(5.6, 0), step_t))
			play("Skeletons_Taunt", 0.1, anim_length("Skeletons_Taunt") / (step_t + 0.3), true)
			Sfx.play("boss_windup", -2.0, 0.8)
		"charge":
			rotation.y = yaw
			charge_dir = dir_of(yaw)
			step_t = 1.0 * fast
			tele.append(hunt.fx.telegraph(2, flat_pos(), yaw, Vector2(1.7, 15.0), step_t))
			play("Skeletons_Taunt_Longer", 0.1, 1.4, true)
			Sfx.play("boss_roar", -4.0, 1.2)
		"spears":
			rotation.y = yaw
			step_t = 0.6
			play("Ranged_Magic_Spellcasting", 0.15, 1.2, true)
			Sfx.play("boss_windup", -4.0, 1.3)
		"graves":
			graves_at.clear()
			var n := 7 if enraged else 5
			for i in n:
				var off := Vector3.ZERO if i == 0 else Vector3(randf_range(-4.5, 4.5), 0, randf_range(-4.5, 4.5))
				var p2 := hunt.arena.resolve(hero.flat_pos() + off + hero.vel * 0.35, 0.4)
				graves_at.append(p2)
				tele.append(hunt.fx.telegraph(0, p2, 0.0, Vector2(1.7, 0), 1.0 + i * 0.12))
			step_t = 1.0
			play("Ranged_Magic_Summon", 0.15, 1.0, true)
			Sfx.play("boss_windup", -4.0, 0.7)
		"summon":
			step_t = 1.2
			play("Skeletons_Taunt_Longer", 0.15, 1.0, true)
			Sfx.play("boss_roar", 0.0)
			hunt.banner(str(def["summon_line"]), Color(def["color"]).lightened(0.2))


func _tick_pattern(dt: float, to: Vector3, dist: float) -> void:
	step_t -= dt
	var hero := hunt.hero
	match pattern:
		"cleave":
			if step == 0 and step_t <= 0.0:
				var ang := absf(angle_difference(rotation.y, atan2(to.x, to.z)))
				if dist < 5.0 + hero.radius and ang < 1.15:
					hunt.damage_hero(dmg * 1.1, self)
				hunt.fx.slash(flat_pos(), rotation.y, 5.2, 130, Color(0.5, 1.0, 0.75), false, 0.25)
				hunt.fx.puff(flat_pos() + dir_of(rotation.y) * 3.0, Color(0.3, 0.27, 0.23, 0.6), 10, 2.0, 3.0)
				hunt.shake(0.35)
				Sfx.play("boss_slam", -2.0)
				_finish(0.7)
		"quake":
			if step == 0 and step_t <= 0.0:
				if dist < 5.6 + hero.radius * 0.5:
					hunt.damage_hero(dmg * 1.3, self)
					hero.push(to.normalized(), 22.0)
				hunt.fx.ring(flat_pos(), 6.2, Color(0.45, 1.0, 0.75), 0.55, 0.12)
				hunt.fx.puff(flat_pos(), Color(0.3, 0.27, 0.23, 0.7), 18, 4.5, 4.0)
				hunt.fx.bone_burst(flat_pos(), 8, 7.0)
				hunt.fx.flash_light(flat_pos(), Color(0.4, 1.0, 0.7), 5.0, 10.0, 0.4)
				hunt.shake(0.6)
				Sfx.play("quake", 0.0)
				_finish(0.9)
		"charge":
			if step == 0:
				if step_t <= 0.0:
					step = 1
					step_t = 15.0 / 24.0
					charge_hit = false
					_clear_tele()
					play("Running_A", 0.05, 1.6)
					Sfx.play("charge", 0.0, 0.7)
			elif step == 1:
				position += charge_dir * 24.0 * dt
				var before := position
				position = hunt.arena.resolve(position, radius * 0.6)
				hunt.fx.puff(flat_pos(), Color(0.3, 0.27, 0.23, 0.5), 2, 0.6, 1.5)
				if not charge_hit and hero.flat_pos().distance_to(flat_pos()) < radius + hero.radius + 0.3:
					charge_hit = true
					hunt.damage_hero(dmg * 1.25, self)
					hero.push(charge_dir.cross(Vector3.UP) * (1.0 if randf() < 0.5 else -1.0), 18.0)
				if step_t <= 0.0 or before.distance_to(position) > 0.05:
					hunt.shake(0.4)
					hunt.fx.ring(flat_pos(), 3.0, Color(0.45, 1.0, 0.75), 0.35)
					Sfx.play("charge_land", -2.0)
					_finish(1.0)
		"spears":
			if step_t <= 0.0:
				var volleys := 3 if enraged else 2
				if step < volleys:
					var n := 11 if enraged else 7
					var yaw := yaw_to(position, hero.position) + (0.12 if step % 2 == 1 else 0.0)
					for i in n:
						var a := yaw + (i - (n - 1) * 0.5) * deg_to_rad(11.0)
						var d := dir_of(a)
						hunt.spawn_proj("spear", flat_pos() + d * 1.6, d * 12.5, dmg * 0.55, 1, self)
					Sfx.play("atk_mage", -3.0, 0.6)
					hunt.fx.flash_light(flat_pos() + dir_of(yaw) * 1.5, Color(0.5, 1.0, 0.7), 2.5, 6.0, 0.2)
					step += 1
					step_t = 0.42
					face(yaw, 1.0, 1.0)
				else:
					_finish(0.8)
		"graves":
			if step == 0 and step_t <= 0.0:
				step = 1
				step_t = 0.12 * graves_at.size() + 0.1
			if step >= 1:
				var idx := int((0.12 * graves_at.size() + 0.1 - step_t) / 0.12)
				while step - 1 < graves_at.size() and step - 1 <= idx:
					var p: Vector3 = graves_at[step - 1]
					if hero.flat_pos().distance_to(p) < 1.7 + hero.radius * 0.5:
						hunt.damage_hero(dmg * 0.9, self)
					hunt.fx.bone_burst(p, 5, 6.0)
					hunt.fx.puff(p, Color(0.3, 0.27, 0.23, 0.6), 6, 1.0, 2.5)
					hunt.fx.burst(p, Color(0.5, 1.0, 0.75), 8, 5.0, 1.2)
					Sfx.play("boss_hit", -6.0, 1.3)
					step += 1
				if step - 1 >= graves_at.size():
					hunt.shake(0.3)
					_finish(0.6)
		"summon":
			if step == 0 and step_t <= 0.0:
				step = 1
				for i in (8 if enraged else 6):
					var a2 := TAU * i / (8 if enraged else 6)
					hunt.spawn_foe("minion" if i % 3 != 0 else "warrior", hunt.arena.resolve(flat_pos() + Vector3(sin(a2), 0, cos(a2)) * 4.0, 0.6))
				hunt.shake(0.3)
				_finish(0.5)


## A handful of the dead climb out around the hero: bigger and faster with the tier.
func _call_court() -> void:
	var n := 3 + 2 * hunt.tier_i
	for i in n:
		var a := TAU * i / n + randf() * 0.4
		var at := hunt.arena.resolve(hunt.hero.flat_pos() + Vector3(sin(a), 0, cos(a)) * randf_range(5.0, 8.0), 0.6)
		if hunt.foes.size() < Hunt.MAX_FOES:
			hunt.spawn_foe("hound" if (hunt.tier_i >= 1 and i % 3 == 0) else "minion", at)
	Sfx.play("aggro", -8.0)


func _finish(recover: float) -> void:
	_clear_tele()
	state = "chase"
	cd = (recover * (0.65 if enraged else 1.0) + randf_range(0.2, 0.6)) * cd_mult


func _clear_tele() -> void:
	for t in tele:
		hunt.fx.cancel(t)
	tele.clear()


## Stall guard: a fight dragged past two and a half minutes ends in a frenzy,
## so kiting forever is never the safe answer.
func _berserk() -> void:
	berserk = true
	dmg *= 1.5
	speed *= 1.3
	cd_mult = 0.7
	hunt.banner("%s grows impatient" % display_name, Color(1.0, 0.5, 0.3))
	hunt.shake(0.4)
	Sfx.play("boss_roar", -2.0, 0.9)


func _enrage() -> void:
	enraged = true
	set_tint(Color(1.0, 0.25, 0.2, 0.45))
	hunt.banner("%s is enraged!" % display_name, Color(1.0, 0.4, 0.3))
	hunt.shake(0.5)
	Sfx.play("boss_roar", 0.0, 0.85)
	hunt.fx.ring(flat_pos(), 6.0, Color(1.0, 0.3, 0.2), 0.6)


func die() -> void:
	alive = false
	_clear_tele()
	set_flash(0.0)
	play("Skeletons_Death", 0.1, 0.7)
	state_t = 2.5
