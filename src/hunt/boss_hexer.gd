class_name BossHexer
extends Boss
## The Hexer Queen. She keeps her distance and works the room: rings of orbs
## flung outward, circles of dark summoning on the ground, a blink, and a cursed
## lane that slows. Every attack is telegraphed. Below half health she doubles
## down: more orbs, more circles, three lanes at once. Across the fight:
##   phase 2  Hex Crossfire: lanes close on the hero from three sides at once
##   phase 3  Unmaking: she stands still and turns a double spiral of orbs, and
##            the spent spiral leaves her open
## The room: dark sigils burn into the floor round her at phase 2 and 3.

const VIOLET := Color(0.75, 0.4, 1.0)

var circles_at: Array = []
var blink_to := Vector3.ZERO
var lane_dir := Vector3.ZERO
var _spin := 0.0
var _spin_t := 0.0
var _cross_at := Vector3.ZERO


func setup(h: Hunt, t: Dictionary) -> void:
	super.setup(h, t)
	keep_dist = 9.0
	retreat_dist = 5.5


func _choose(dist: float) -> void:
	var options := ["orbs", "circles", "lane"]
	if phase >= 2:
		options += ["crossfire", "crossfire"]
	if final:
		options += ["spiral"]
	if dist < 6.5:
		options += ["blink", "blink"]
	options.erase(last)
	_begin(options[randi() % options.size()])


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
	rotation.y = yaw
	match p:
		"orbs":
			step_t = 0.9 * fast
			hunt.fx.vfx.linger(&"shadow", flat_pos(), 2.4, step_t, Fx.VfxLib.NO_TINT, &"big")
			hunt.fx.vfx.cast(&"shadow", flat_pos(), 2.0, Fx.VfxLib.NO_TINT, &"big")
			play("Ranged_Magic_Spellcasting", 0.1, 1.0, true)
			Sfx.play("boss_windup", -3.0, 1.2)
		"circles":
			circles_at.clear()
			var n := 4 if enraged else 3
			for i in n:
				var off := Vector3.ZERO if i == 0 else Vector3(randf_range(-6.5, 6.5), 0, randf_range(-6.5, 6.5))
				var at := hunt.arena.resolve(hero.flat_pos() + off + hero.vel * 0.4, 0.5)
				circles_at.append(at)
				tele.append(hunt.fx.telegraph(0, at, 0.0, Vector2(2.1, 0), 1.3 * fast))
			step_t = 1.3 * fast
			play("Ranged_Magic_Summon", 0.1, 1.0, true)
			Sfx.play("boss_windup", -4.0, 0.8)
		"lane":
			step_t = 1.0 * fast
			lane_dir = dir_of(yaw)
			tele.append(hunt.fx.telegraph(2, flat_pos(), yaw, Vector2(2.2, 20.0), step_t))
			if enraged:
				for sgn in [-1.0, 1.0]:
					tele.append(hunt.fx.telegraph(2, flat_pos(), yaw + 0.45 * sgn, Vector2(2.2, 20.0), step_t))
			play("Skeletons_Taunt", 0.1, 1.4, true)
			Sfx.play("boss_roar", -5.0, 1.5)
		"crossfire":
			# Lanes from three (four, enraged) points round the hero, all aimed at where they stand.
			_cross_at = hero.flat_pos() + hero.vel * 0.35
			var n := 4 if final else 3
			var off := randf() * TAU
			for i in n:
				var a := off + TAU * i / n
				var from := hunt.arena.resolve(_cross_at + Vector3(sin(a), 0, cos(a)) * 9.0, 0.4)
				var aim := yaw_to(from, _cross_at)
				hunt.beam_from(from, aim, 1.2 * fast, dmg * 0.9, VIOLET)
				hunt.fx.vfx.cast(&"shadow", from, 1.6, Fx.VfxLib.NO_TINT, &"skill")
			step_t = 1.2 * fast + 0.5
			play("Ranged_Magic_Summon", 0.1, 1.0, true)
			Sfx.play("boss_windup", -3.0, 0.7)
			hunt.hud.event("Hex Crossfire", VIOLET, "lightning-helix")
		"spiral":
			_spin = randf() * TAU
			step_t = 1.0
			hunt.fx.vfx.linger(&"shadow", flat_pos(), 3.0, 1.0 + 3.4, Fx.VfxLib.NO_TINT, &"big")
			play("Ranged_Magic_Spellcasting_Long", 0.1, 1.0, true)
			Sfx.play("boss_roar", -4.0, 1.3)
			hunt.hud.event("Unmaking", VIOLET, "magic-swirl")
		"blink":
			# Blinking out of a hero who closed the gap leaves her reeling.
			if hero.flat_pos().distance_to(flat_pos()) < 3.5 and randf() < 0.5:
				expose(float(DB.EXPOSED["time"]) * 0.7)
				return
			step_t = 0.35
			hunt.fx.vfx.impact(&"shadow", flat_pos(), 2.0, Fx.VfxLib.NO_TINT, &"skill")
			hunt.fx.puff(flat_pos(), Color(0.45, 0.25, 0.6, 0.7), 12, 2.0, 3.0)
			blink_to = _blink_spot()
			Sfx.play("dash", -2.0, 0.7)


## A free spot about 8 m from the hero, preferring the far side of the room.
func _blink_spot() -> Vector3:
	var hero := hunt.hero
	var best := flat_pos()
	var best_d := -1.0
	for i in 14:
		var a := randf() * TAU
		var p := hunt.arena.resolve(hero.flat_pos() + Vector3(sin(a), 0, cos(a)) * 8.0, 0.8)
		if hunt.arena.blocked(p, 0.8):
			continue
		var d := p.distance_to(flat_pos())
		if d > best_d:
			best_d = d
			best = p
	return best


func _tick_pattern(dt: float, to: Vector3, dist: float) -> void:
	step_t -= dt
	var hero := hunt.hero
	match pattern:
		"orbs":
			if step < 2 and step_t <= 0.0:
				var n := 14 if enraged else 8
				var phase := 0.0 if step == 0 else PI / n
				for i in n:
					var d := dir_of(phase + TAU * i / n)
					hunt.spawn_proj("orb", flat_pos() + d * 1.5, d * 9.0, dmg * 0.6, 1, self, {"life": 2.4})
				hunt.fx.vfx.nova(&"shadow", flat_pos(), 4.5, 0.3, Fx.VfxLib.NO_TINT, &"skill")
				Sfx.play("atk_mage", -3.0, 0.7)
				step += 1
				step_t = 0.55
			elif step >= 2 and step_t <= 0.0:
				_finish(0.9)
		"circles":
			if step == 0 and step_t <= 0.0:
				step = 1
				for at: Vector3 in circles_at:
					if hero.flat_pos().distance_to(at) < 2.1 + hero.radius * 0.5:
						hunt.damage_hero(dmg * 0.9, self, 0.7)
					hunt.fx.bone_burst(at, 5, 6.0)
					hunt.fx.burst(at, VIOLET, 10, 5.0, 1.2)
					hunt.fx.puff(at, Color(0.35, 0.2, 0.45, 0.6), 6, 1.2, 2.5)
					hunt.spawn_foe("minion", hunt.arena.resolve(at + Vector3(0.6, 0, 0), 0.5))
					hunt.spawn_foe("minion", hunt.arena.resolve(at - Vector3(0.6, 0, 0), 0.5))
				Sfx.play("boss_hit", -4.0, 0.9)
				hunt.shake(0.3)
				_finish(0.8)
		"lane":
			if step == 0 and step_t <= 0.0:
				step = 1
				var dirs := [lane_dir]
				if enraged:
					dirs.append(lane_dir.rotated(Vector3.UP, 0.45))
					dirs.append(lane_dir.rotated(Vector3.UP, -0.45))
				var cursed := false
				for d: Vector3 in dirs:
					var rel := hero.flat_pos() - flat_pos()
					var along := rel.dot(d)
					var lateral := absf(rel.x * d.z - rel.z * d.x)
					if not cursed and along > 0.0 and along < 20.0 and lateral < 1.1 + hero.radius * 0.6:
						cursed = true
						hunt.damage_hero(dmg * 1.0, self, 0.8)
						hero.slow_t = 3.0
					hunt.fx.lightning(PackedVector3Array([flat_pos() + Vector3(0, 1.5, 0) + d * 1.5, flat_pos() + Vector3(0, 0.6, 0) + d * 20.0]), Color(0.6, 0.8, 1.0), &"big")
				Sfx.play("boss_slam", -3.0, 1.3)
				hunt.shake(0.3)
				_finish(0.8)
				# Three lanes at once spend her: a short opening.
				if enraged:
					expose(float(DB.EXPOSED["time"]) * 0.6)
		"crossfire":
			if step_t <= 0.0:
				hunt.shake(0.3)
				_finish(0.8)
		"spiral":
			# Two arms of orbs turning round her; the wind-up is the first second.
			if step == 0 and step_t <= 0.0:
				step = 1
				step_t = 3.4
				_spin_t = 0.0
			elif step == 1:
				_spin_t -= dt
				if _spin_t <= 0.0:
					_spin_t = 0.15
					_spin += 0.42
					for arm in 2:
						var d := dir_of(_spin + PI * arm)
						hunt.spawn_proj("orb", flat_pos() + d * 1.5, d * 7.5, dmg * 0.5, 1, self, {"life": 2.6})
					Sfx.play("atk_mage", -9.0, 0.9)
				rotation.y = _spin
				if step_t <= 0.0:
					step = 2
					hunt.shake(0.3)
					_finish(0.6)
					# The spiral spends her: a longer opening.
					expose(float(DB.EXPOSED["time"]) * 0.8)
		"blink":
			if step == 0 and step_t <= 0.0:
				step = 1
				step_t = 0.4
				model.visible = false
				position = blink_to
			elif step == 1 and step_t <= 0.0:
				step = 2
				model.visible = true
				var yaw := yaw_to(position, hero.position)
				rotation.y = yaw
				hunt.fx.vfx.impact(&"shadow", flat_pos(), 2.2, Fx.VfxLib.NO_TINT, &"big")
				hunt.fx.puff(flat_pos(), Color(0.45, 0.25, 0.6, 0.7), 12, 2.0, 3.0)
				var n := 5 if enraged else 3
				for i in n:
					var d := dir_of(yaw + (i - (n - 1) * 0.5) * deg_to_rad(13.0))
					hunt.spawn_proj("orb", flat_pos() + d * 1.5, d * 10.5, dmg * 0.6, 1, self, {"life": 2.0})
				Sfx.play("atk_mage", -3.0, 0.8)
				play("Ranged_Magic_Spellcasting", 0.1, 1.2, true)
				_finish(0.6)


func die() -> void:
	model.visible = true
	super.die()


func _phase_lines(n: int) -> Array:
	if n == 2:
		return ["The Queen unveils", "\"I will unmake you, thread by thread.\""]
	return ["The Unmaking", "\"Kneel. The cult is only the beginning.\""]


func _phase_fx(n: int) -> void:
	hunt.fx.vfx.nova(&"shadow", flat_pos(), 7.0, 0.4, Fx.VfxLib.NO_TINT, &"big")
	if n == 3:
		hunt.fx.vfx.sky(flat_pos() + Vector3(2, 0, 1), VIOLET, 0.3, 14.0)


func _phase_arena(n: int) -> void:
	# Dark sigils burn into the floor round her: they drag at the feet.
	_patch_ring(4 if n == 2 else 7, 9.0 if n == 2 else 10.5, 1.9, 14.0, dmg * 0.25, &"shadow", true, randf() * TAU)
