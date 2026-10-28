class_name Boss
extends Actor
## The boss base: Gravemaw's cleave, quake, charge, spears and graves. Every
## attack is telegraphed on the ground and can be walked or dashed out of.
##
## Every boss fights in three phases. At 66% and 33% health it stops, gathers
## and breaks into the next phase (`_begin_shift`): unbreakable for a couple of
## seconds, the camera pushes in, the hero is shoved clear and safe, then the
## room changes (`_phase_arena`) and the boss comes back with more. Phase 2
## sets `enraged`, phase 3 sets `final`. Subclasses add their own moves per
## phase and override `_phase_lines`, `_phase_fx` and `_phase_arena`.

var state := "intro"
var state_t := 0.0
var dmg := 30.0
var pattern := ""
var step := 0
var step_t := 0.0
var cd := 1.0
var enraged := false
## Phase 3: the last third of the fight.
var final := false
## 1..3, raised by `_begin_shift`.
var phase := 1
var tele: Array = []
var charge_dir := Vector3.ZERO
var charge_hit := false
var graves_at: Array = []
var last := ""
var fight_t := 0.0
var _ring_t := 9.0
var _lanes_t := 12.0
var _ancient_t := 8.0
## Torment and up: the Ancient form, with a new name, a pale-gold aura and the Ancient cross.
var ancient := false
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
## Seconds left stunned and open to extra damage (DB.EXPOSED).
var exposed_t := 0.0

## Health fractions that open phase 2 and phase 3.
const PHASE_AT := [0.66, 0.33]
## A phase change: the whole beat, and the moment inside it that the break lands.
const SHIFT_LEN := 2.4
const SHIFT_BEAT := 1.1
## Longest wind-up pose held per pattern, for patterns whose first step is long.
const WIND_CAP := {"eruption": 0.8, "inferno": 1.2, "lockdown": 1.1, "spikes": 1.0, "bonecrown": 1.1, "crossfire": 1.1, "spiral": 1.0, "avalanche": 1.0, "meteors": 1.0, "magma": 1.1, "shatter": 1.0, "whiteout": 1.0}
## Patterns that wind up by rising and arching back; the rest crouch and tip back.
const CASTS := ["spears", "graves", "orbs", "circles", "lane", "ring", "seeds", "roots", "coinfall", "spikes", "blizzard", "bloats", "eruption", "crossfire", "spiral", "bramble", "overgrowth", "avalanche", "shatter", "whiteout", "meteors", "magma"]

## The element of the crown and the phase breaks (DB.BOSSES "el").
var crown_el: StringName = &"poison"
var shift_t := 0.0
var _shift_to := 1
var _shift_hit := false
var _wind_on := false
var _wind_left := 0.0
var _glow: OmniLight3D
var _glow_base := 1.8
## Charges chained after the first (phase 3 Gravemaw).
var combo := 0
## Phase 3 charges chain into the next (Gravemaw's rampage).
var chain_charge := false
## How much bigger the body has grown over the phases.
var _grown := 1.0


func setup(h: Hunt, tier: Dictionary) -> void:
	hunt = h
	var d: Dictionary = hunt.boss_def(boss_id)
	def = d
	ancient = hunt.tier_i >= DB.TIER_ANCIENT
	var aura: Color = Color(1.0, 0.86, 0.5) if ancient else d["color"]
	display_name = d["name"]
	# "Ancient" goes in the title so the HUD's name line still fits.
	title = "the Ancient" if ancient else d["title"]
	max_hp = d["hp"] * tier["hp"] * (1.0 + DB.RUN_BOSS_HP * (hunt.run_level - 1))
	hp = max_hp
	dmg = d["dmg"] * tier["dmg"]
	speed = d["speed"]
	radius = d["radius"]
	mass = d["mass"]
	build_model(d["model"], d["weapons"], aura, 0.55, Color(aura, 1.0), 0.8, d)
	if d.has("skin") and not foreign:
		if DB.SKINS.has(str(d["skin"])):
			reskin(DB.SKINS[str(d["skin"])])
		else:
			_gild(load(KK.CHAR_DIR + str(d["skin"])) as Texture2D)
	model.scale = Vector3.ONE * float(d["scale"])
	var occ: Vector2 = d["occluder"]
	hunt.arena.add_dynamic_occluder(self, occ.x, occ.y)
	# A crown of green toon flames over the King's head (emitted in tick).
	crown_col = aura
	crown_el = StringName(str(d.get("el", "poison")))
	var glow := OmniLight3D.new()
	glow.light_color = aura
	glow.light_energy = _glow_base
	glow.omni_range = 7.0
	glow.position = Vector3(0, 4.0, 0.8)
	add_child(glow)
	_glow = glow
	state = "intro"
	state_t = 2.4
	play("Skeletons_Awaken_Standing", 0.0, anim_length("Skeletons_Awaken_Standing") / 2.2)


var crown_col := Color(0.4, 1.0, 0.6)
var _crown_t := 0.0


func tick(dt: float) -> void:
	_crown_t -= dt
	if _crown_t <= 0.0 and visible and hunt.fx:
		# The crown of the boss's own element: bigger and busier each phase.
		_crown_t = randf_range(0.07, 0.12) / (1.0 + 0.45 * (phase - 1))
		var a := randf() * TAU
		var sc := 1.0 + 0.3 * (phase - 1)
		var top := global_position + Vector3(sin(a) * 0.4 * sc, 5.2 * _grown, cos(a) * 0.4 * sc + 0.1)
		hunt.fx.vfx.puff_el(crown_el, top, randf_range(0.2, 0.32) * sc, Vector3(0, 1.6, 0), randf_range(0.35, 0.5), crown_col)
	if not alive:
		state_t -= dt
		if state_t < 0.0:
			position.y -= dt * 0.6
		return
	tick_common(dt)
	exposed_t -= dt
	state_t -= dt
	if state == "intro":
		if state_t <= 0.0:
			state = "chase"
			cd = 0.6
		return
	if state == "shift":
		_tick_shift(dt)
		return
	# A held wind-up pose lets go as the blow lands.
	if _wind_left > 0.0:
		_wind_left -= dt
		if _wind_left <= 0.0:
			_strike()
	# The break comes even to a stunned or frozen boss, mid-attack or not.
	if phase < 3 and hunt.phase == "boss" and hp < max_hp * float(PHASE_AT[phase - 1]) and state in ["chase", "attack"]:
		_begin_shift(phase + 1)
		return
	if freeze_t > 0.0 or stun_t > 0.0:
		return
	if state == "attack" and not _wind_on:
		_wind_on = true
		if step == 0 and step_t > 0.12:
			_wind(minf(step_t, float(WIND_CAP.get(pattern, 1.2))), pattern in CASTS)
	fight_t += dt
	_tick_tier_moves(dt)
	if not berserk and fight_t > 150.0 - 30.0 * hunt.ai():
		_berserk()
	# The longer you kite, the more of his court arrives to cut you off.
	if state == "chase" and fight_t > 10.0:
		add_t -= dt
		if add_t <= 0.0:
			add_t = 20.0 - 4.0 * minf(hunt.ai(), 2.5)
			_call_court()
	var hero := hunt.hero
	var to := hero.flat_pos() - flat_pos()
	var dist := to.length()
	match state:
		"chase":
			cd -= dt
			if dist > 3.2:
				var spd := speed * (1.3 if enraged else 1.0)
				position += to / dist * spd * t_speed * dt
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
			# The clip is sped up so its blow (`strike`, a fraction of the clip; 0.5 for KayKit) lands as the telegraph ends.
			play("Melee_2H_Attack_Chop", 0.1, anim_length("Melee_2H_Attack_Chop") * float(_rig_def.get("strike", 0.5)) / step_t, true)
			Sfx.play("boss_windup", -2.0)
		"quake":
			step_t = 1.15 * fast
			tele.append(hunt.fx.telegraph(0, flat_pos(), 0.0, Vector2(5.6, 0), step_t))
			play("Skeletons_Taunt", 0.1, anim_length("Skeletons_Taunt") / (step_t + 0.3), true)
			Sfx.play("boss_windup", -2.0, 0.8)
		"charge":
			rotation.y = yaw
			charge_dir = dir_of(yaw)
			step_t = (0.6 if combo > 0 else 1.0) * fast
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


func _tick_pattern(dt: float, to: Vector3, dist: float) -> void:
	step_t -= dt
	var hero := hunt.hero
	match pattern:
		"cleave":
			if step == 0 and step_t <= 0.0:
				var ang := absf(angle_difference(rotation.y, atan2(to.x, to.z)))
				if dist < 5.0 + hero.radius and ang < 1.15:
					hunt.damage_hero(dmg * 1.1, self, 1.0)
				hunt.fx.slash(flat_pos(), rotation.y, 5.2, 130, Color(0.5, 1.0, 0.75), false, 0.25)
				hunt.fx.puff(flat_pos() + dir_of(rotation.y) * 3.0, Color(0.3, 0.27, 0.23, 0.6), 10, 2.0, 3.0)
				hunt.shake(0.35)
				Sfx.play("boss_slam", -2.0)
				_finish(0.7)
		"quake":
			if step == 0 and step_t <= 0.0:
				if dist < 5.6 + hero.radius * 0.5:
					hunt.damage_hero(dmg * 1.3, self, 1.0)
					hero.push(to.normalized(), 22.0)
				hunt.fx.vfx.nova(&"physical", flat_pos(), 6.2, 0.5, Fx.VfxLib.NO_TINT, &"big")
				hunt.fx.vfx.impact(&"shadow", flat_pos(), 2.5, Fx.VfxLib.NO_TINT, &"big")
				hunt.fx.puff(flat_pos(), Color(0.3, 0.27, 0.23, 0.7), 18, 4.5, 4.0)
				hunt.fx.bone_burst(flat_pos(), 8, 7.0)
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
					hunt.damage_hero(dmg * 1.25, self, 1.0)
					hero.push(charge_dir.cross(Vector3.UP) * (1.0 if randf() < 0.5 else -1.0), 18.0)
				if step_t <= 0.0 or before.distance_to(position) > 0.05:
					hunt.shake(0.4)
					hunt.fx.vfx.impact(&"physical", flat_pos(), 2.4, Fx.VfxLib.NO_TINT, &"skill")
					Sfx.play("charge_land", -2.0)
					var walled := before.distance_to(position) > 0.05
					# The last third: a charge that finds open floor turns and charges again.
					if chain_charge and final and not walled and combo < 2:
						combo += 1
						_begin("charge")
						return
					combo = 0
					_finish(1.0)
					# Into the wall: dazed. Baiting the charge is the opening.
					if walled:
						expose(float(DB.EXPOSED["time"]))
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
						hunt.damage_hero(dmg * 0.9, self, 0.6)
					hunt.fx.bone_burst(p, 5, 6.0)
					hunt.fx.puff(p, Color(0.3, 0.27, 0.23, 0.6), 6, 1.0, 2.5)
					hunt.fx.burst(p, Color(0.5, 1.0, 0.75), 8, 5.0, 1.2)
					Sfx.play("boss_hit", -6.0, 1.3)
					step += 1
				if step - 1 >= graves_at.size():
					hunt.shake(0.3)
					_finish(0.6)


## Harder tiers teach every boss more: Veteran adds a ring of blasts closing
## on the hero, Nightmare a fan of three lanes from the boss.
func _tick_tier_moves(dt: float) -> void:
	if hunt.ai() < 1.0:
		return
	_ring_t -= dt
	if _ring_t <= 0.0:
		_ring_t = 14.0 - 2.0 * (hunt.ai() - 1.0)
		var col: Color = def["color"]
		var at := hunt.hero.flat_pos()
		hunt.hud.event("Ring of ruin", Color(col).lightened(0.2), "fire-ring")
		for i in 6:
			var a := TAU * i / 6.0
			hunt.blast_at(hunt.arena.resolve(at + Vector3(sin(a), 0, cos(a)) * 4.0, 0.4), 2.0, 1.1 + i * 0.12, dmg * 0.6, "", col)
	if hunt.ai() < 2.0:
		return
	_lanes_t -= dt
	if _lanes_t <= 0.0:
		_lanes_t = 12.0
		var yaw := yaw_to(position, hunt.hero.position)
		hunt.hud.event("Lances", Color(1.0, 0.5, 0.4), "arrow-cluster")
		for k in [-0.5, 0.0, 0.5]:
			hunt.beam_from(flat_pos(), yaw + float(k), 1.3, dmg * 0.8, def["color"])
	if not ancient:
		return
	# The Ancient cross: four beams that turn a little each time.
	_ancient_t -= dt
	if _ancient_t <= 0.0:
		_ancient_t = 10.0
		hunt.hud.event("Ancient wrath", Color(1.0, 0.86, 0.5), "sun")
		var base_yaw := fight_t * 0.7
		for k in 4:
			hunt.beam_from(flat_pos(), base_yaw + k * PI / 2.0, 1.1, dmg * 0.7, Color(1.0, 0.86, 0.5))


## A handful of the dead climb out around the hero: bigger and faster with the tier.
func _call_court() -> void:
	var n := 3 + int(2.0 * hunt.ai())
	for i in n:
		var a := TAU * i / n + randf() * 0.4
		var at := hunt.arena.resolve(hunt.hero.flat_pos() + Vector3(sin(a), 0, cos(a)) * randf_range(5.0, 8.0), 0.6)
		if hunt.foes.size() < Hunt.MAX_FOES:
			hunt.spawn_foe("hound" if (hunt.ai() >= 1.0 and i % 3 == 0) else "minion", at)
	Sfx.play("aggro", -8.0)


## Stunned and taking extra damage for `t` seconds.
func expose(t: float) -> void:
	exposed_t = t
	stun_t = maxf(stun_t, t)
	_clear_tele()
	_cancel_wind()
	state = "chase"
	cd = t + 0.3
	play("Hit_A", 0.1, 0.5, true)
	hunt.fx.text(flat_pos() + Vector3(0, 2.5, 0), "Exposed!", Color(1.0, 0.85, 0.3), 1.4, 1.2)
	hunt.fx.telegraph(0, flat_pos(), 0.0, Vector2(radius + 1.2, 0), t, 0.6, &"holy")
	hunt.fx.vfx.impact(&"holy", flat_pos(), radius, Fx.VfxLib.NO_TINT, &"skill")
	hunt.hud.event("%s is exposed" % display_name, Color(1.0, 0.85, 0.3), "bullseye")
	Sfx.play("shield_break", -2.0, 0.7)


func _finish(recover: float) -> void:
	_clear_tele()
	_cancel_wind()
	state = "chase"
	cd = (recover * (0.65 if enraged else 1.0) + randf_range(0.2, 0.6)) * cd_mult


func _clear_tele() -> void:
	_wind_on = false
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


## A held pose before a blow: rise and arch back for a cast, crouch and tip
## back for a slam. `_strike` lets go of it with the lunge.
func _wind(dur: float, cast: bool) -> void:
	_wind_left = dur
	if cast:
		hold_pose(Vector3(-0.04, 0.09, -0.04), Vector2(-0.1, 0.0))
	else:
		hold_pose(Vector3(0.07, -0.13, 0.07), Vector2(-0.2, 0.0))


func _strike() -> void:
	_wind_left = 0.0
	release_pose()
	squash(Vector3(-0.06, -0.04, 0.16))
	lean(dir_of(rotation.y), 0.16)


## Drops the wind-up pose without the lunge (a stun, a phase break, a death).
func _cancel_wind() -> void:
	_wind_left = 0.0
	release_pose()


## The break into phase `n`: unbreakable and still while the boss gathers (the
## hero is invulnerable and gets shoved clear at the climax), then the room
## and the moves change. See `_tick_shift`.
func _begin_shift(n: int) -> void:
	_clear_tele()
	_cancel_wind()
	state = "shift"
	_shift_to = n
	shift_t = 0.0
	_shift_hit = false
	exposed_t = 0.0
	stun_t = 0.0
	if freeze_t > 0.0:
		freeze_t = 0.0
		if anim:
			anim.speed_scale = 1.0
		_apply_tint(_tint)
	hunt.hero.invuln = maxf(hunt.hero.invuln, SHIFT_LEN + 0.5)
	hunt.hero.slow_t = 0.0
	hunt.hero.root_t = 0.0
	play("Skeletons_Taunt_Longer", 0.15, anim_length("Skeletons_Taunt_Longer") / (SHIFT_BEAT + 0.4), true)
	# Anticipation: the boss crouches and gathers, the element drawn in.
	hold_pose(Vector3(0.09, -0.16, 0.09), Vector2(-0.22, 0.0))
	hunt.fx.vfx.cast(crown_el, flat_pos(), radius + 1.0, Fx.VfxLib.NO_TINT, &"big")
	hunt.fx.vfx.linger(crown_el, flat_pos(), radius + 2.2, SHIFT_BEAT, Fx.VfxLib.NO_TINT, &"skill")
	Sfx.play("boss_windup", 0.0, 0.6)
	Sfx.play("boss_roar", -3.0, 0.6)
	Sfx.intensity = 1.0


func _tick_shift(dt: float) -> void:
	shift_t += dt
	var hero := hunt.hero
	face(yaw_to(position, hero.position), dt, 2.5)
	if not _shift_hit:
		# Sparks pulled in from all round, faster as the beat nears.
		if randf() < dt * (10.0 + 30.0 * shift_t / SHIFT_BEAT):
			var a := randf() * TAU
			var out := Vector3(sin(a), 0, cos(a)) * randf_range(2.5, 4.5)
			hunt.fx.vfx.puff_el(crown_el, flat_pos() + out + Vector3(0, 0.3, 0), 0.26, -out * 2.4 + Vector3(0, 1.4, 0), 0.4, crown_col)
		if shift_t >= SHIFT_BEAT:
			_shift_climax()
	elif shift_t >= SHIFT_LEN:
		state = "chase"
		cd = 0.9
		fight_t = maxf(fight_t - 10.0, 0.0)


## The break itself: the crouch springs open, a shock rolls out, the hero is
## pushed clear, the camera punches and the frame freezes for a beat.
func _shift_climax() -> void:
	_shift_hit = true
	phase = _shift_to
	enraged = true
	final = phase >= 3
	release_pose()
	squash(Vector3(-0.1, 0.24, -0.1))
	lean(-dir_of(rotation.y), 0.2)
	var f := 1.05
	_grown *= f
	if _spring_on:
		_spring_base *= f
	else:
		model.scale *= f
	if _glow:
		_glow.light_energy = _glow_base + 0.7 * (phase - 1)
	var hero := hunt.hero
	var away := hero.flat_pos() - flat_pos()
	if away.length() < 11.0:
		hero.push(away.normalized() if away.length() > 0.1 else Vector3.BACK, 30.0)
	hunt.fx.vfx.nova(crown_el, flat_pos(), 11.0, 0.55, Fx.VfxLib.NO_TINT, &"big")
	hunt.fx.vfx.impact(crown_el, flat_pos(), 3.6, Fx.VfxLib.NO_TINT, &"big")
	hunt.fx.bone_burst(flat_pos(), 10, 8.0)
	hunt.cam.punch = 0.14
	hunt.shake(0.8)
	hunt.hitstop(0.1)
	Sfx.play("boss_roar", 3.0, 0.7)
	Sfx.play("quake", 0.0, 0.8)
	var ln := _phase_lines(phase)
	hunt.banner(ln[0], Color(def["color"]).lightened(0.2), ln[1])
	hunt.hud.boss_phase(phase)
	_phase_fx(phase)
	_phase_arena(phase)
	_summon_court(phase)
	# The last third has its own music where the zone does not.
	if phase == 3 and not hunt.zone.has("boss_music") and hunt.mode != "rift":
		Sfx.music("boss_2", 1.2)


## Banner [title, sub] for the break into phase `n` (2 or 3).
func _phase_lines(n: int) -> Array:
	if n == 2:
		return ["%s is enraged!" % display_name, str(def.get("enrage_line", ""))]
	return ["%s unbound!" % display_name, str(def.get("summon_line", ""))]


## Extra climax effects of the boss's own, once the shock is out.
func _phase_fx(_n: int) -> void:
	pass


## The room changes for phase `n`: hazards left on the ground and so on.
func _phase_arena(_n: int) -> void:
	pass


## The boss's dead climb out round the arena as the phase breaks.
func _summon_court(n: int) -> void:
	var cnt := 3 + 2 * n
	for i in cnt:
		var a := TAU * i / cnt + randf() * 0.3
		var at := hunt.arena.resolve(flat_pos() + Vector3(sin(a), 0, cos(a)) * randf_range(7.0, 9.5), 0.6)
		if hunt.foes.size() < Hunt.MAX_FOES:
			hunt.spawn_foe("warrior" if i % 3 == 0 else "minion", at)


## A ring of lingering hazards `ring_r` out from the boss: they bloom one
## after another and stay `dur` seconds (the room changing for a phase).
func _patch_ring(n: int, ring_r: float, r: float, dur: float, dps: float, el: StringName, slow := false, turn := 0.0) -> void:
	var base := flat_pos()
	for i in n:
		var a := TAU * i / n + turn
		var at := hunt.arena.resolve(base + Vector3(sin(a), 0, cos(a)) * ring_r, r * 0.6)
		get_tree().create_timer(0.08 * i, false).timeout.connect(func():
			if not is_instance_valid(hunt) or not alive:
				return
			hunt.add_fire_patch(at, r, dur, dps, el, slow)
			hunt.fx.vfx.nova(el, at, r * 1.6, 0.35, Fx.VfxLib.NO_TINT, &"skill"))


## The camera during the break: pushes in on the boss as it gathers, holds
## through the climax, then eases home. {focus, zoom, pitch (deg dropped)}.
func shift_shot() -> Dictionary:
	return shift_look(shift_t, position, hunt.hero.position)


static func shift_look(t: float, boss_pos: Vector3, hero_pos: Vector3) -> Dictionary:
	var k_in := smoothstep(0.0, SHIFT_BEAT, t)
	var k_out := smoothstep(SHIFT_BEAT + 0.5, SHIFT_LEN, t)
	var k := k_in * (1.0 - k_out)
	return {"focus": hero_pos.lerp(boss_pos, 0.25 + 0.75 * k), "zoom": lerpf(1.18, 0.82, k), "pitch": 11.0 * k}


func die() -> void:
	alive = false
	_clear_tele()
	_cancel_wind()
	set_flash(0.0)
	play("Skeletons_Death", 0.1, 0.7)
	state_t = 2.5


## A boss with its own skin (the Gilded Warden's gold plate): the body's
## texture is swapped for it and the mesh is shaded as fine, clean metal
## with a gold sheen. The texture carries the color, so nothing is tinted.
func _gild(tex: Texture2D) -> void:
	for mi in mesh_list():
		for i in mi.mesh.get_surface_count():
			var m := mi.get_surface_override_material(i) as ShaderMaterial
			if m == null:
				continue
			m = m.duplicate()
			# Gold texels read as "hot" skeleton eyes to the shader: no eye glow,
			# or the plate and the key blow out to white.
			m.set_shader_parameter("eye_glow", Color(0, 0, 0, 0))
			if str((m.get_shader_parameter("albedo_tex") as Texture2D).resource_path).begins_with(KK.CHAR_DIR):
				m.set_shader_parameter("albedo_tex", tex)
				m.set_shader_parameter("roughness", 0.5)
			mi.set_surface_override_material(i, m)
		mi.set_instance_shader_parameter("grade", Vector4(0.6, 0.0, 0.0, 0.0))
		mi.set_instance_shader_parameter("accent", Color(1.0, 0.82, 0.4))
