class_name BossThorn
extends Boss
## The Thornmother. She teaches the dash: a ring of thorns rolls out from her
## and only a dash goes through it. She seeds the ground with briars that stay,
## lashes vines across the clearing in a sweep, and binds the hero in roots.
## Spending the ring leaves her open; enraged she rolls two rings at once.

const GREEN := Color(0.55, 0.95, 0.35)
const RING_SPEED := 9.0
const RING_REACH := 15.0

var _ring_r := -1.0
var _ring2_r := -1.0
var _ring_hit := false
var _seeds: Array = []
var _lash_yaw := 0.0


func setup(h: Hunt, t: Dictionary) -> void:
	super.setup(h, t)
	keep_dist = 6.0


func _choose(dist: float) -> void:
	var options := ["ring", "seeds", "lash", "roots"]
	if dist < 5.0:
		options += ["ring"]
	options.erase(last)
	_begin(options[randi() % options.size()])


func _begin(p: String) -> void:
	if p == "summon":
		super._begin(p)
		return
	_clear_tele()
	pattern = p
	last = p
	state = "attack"
	step = 0
	step_t = 0.0
	var hero := hunt.hero
	var fast := 0.8 if enraged else 1.0
	rotation.y = yaw_to(position, hero.position)
	match p:
		"ring":
			step_t = 1.0 * fast
			tele.append(hunt.fx.telegraph(0, flat_pos(), 0.0, Vector2(3.0, 0), step_t))
			play("Ranged_Magic_Spellcasting_Long", 0.1, 1.2, true)
			Sfx.play("boss_windup", -2.0, 0.9)
		"seeds":
			_seeds.clear()
			var n := 6 if enraged else 4
			for i in n:
				var off := Vector3.ZERO if i == 0 else Vector3(randf_range(-5.5, 5.5), 0, randf_range(-5.5, 5.5))
				var at := hunt.arena.resolve(hero.flat_pos() + off + hero.vel * 0.4, 0.5)
				_seeds.append(at)
				tele.append(hunt.fx.telegraph(0, at, 0.0, Vector2(1.7, 0), 1.1 + i * 0.1))
			step_t = 1.1
			play("Ranged_Magic_Summon", 0.1, 1.0, true)
			Sfx.play("boss_windup", -4.0, 1.2)
		"lash":
			_lash_yaw = yaw_to(position, hero.position) - 0.7
			step_t = 0.5
			play("Skeletons_Taunt", 0.1, 1.3, true)
			Sfx.play("boss_roar", -6.0, 1.4)
		"roots":
			step_t = 0.2
			play("Ranged_Magic_Spellcasting", 0.1, 1.0, true)


func _tick_pattern(dt: float, to: Vector3, dist: float) -> void:
	if pattern == "summon":
		super._tick_pattern(dt, to, dist)
		return
	step_t -= dt
	var hero := hunt.hero
	match pattern:
		"ring":
			if step == 0 and step_t <= 0.0:
				# The ring rolls out; a second, slower one follows when enraged.
				step = 1
				_ring_r = 1.5
				_ring2_r = -3.5 if enraged else -1.0
				_ring_hit = false
				_clear_tele()
				# The thorn wave is a dodge-it gameplay front: leaves and spores
				# torn up along it, moving at exactly RING_SPEED.
				hunt.fx.vfx.nova(&"nature", flat_pos(), RING_REACH, RING_REACH / RING_SPEED, Fx.VfxLib.NO_TINT, &"big")
				Sfx.play("quake", -2.0, 0.8)
				hunt.shake(0.3)
			elif step == 1:
				_ring_r += RING_SPEED * dt
				_ring2_r += RING_SPEED * dt
				var d := hero.flat_pos().distance_to(flat_pos())
				for r in [_ring_r, _ring2_r]:
					if r > 0.0 and absf(d - r) < 0.7 and not _ring_hit:
						_ring_hit = true
						hunt.damage_hero(dmg * 1.1, self, 1.0)
						hero.slow_t = maxf(hero.slow_t, 1.5)
				if _ring2_r > 0.0 and _ring2_r < 0.5:
					hunt.fx.vfx.nova(&"nature", flat_pos(), RING_REACH, RING_REACH / RING_SPEED, GREEN.lightened(0.3), &"big")
					_ring_hit = false
				if maxf(_ring_r, _ring2_r) > RING_REACH:
					_finish(0.6)
					# The ring spends her: the moment to close in.
					expose(float(DB.EXPOSED["time"]) * 0.7)
		"seeds":
			if step == 0 and step_t <= 0.0:
				step = 1
				for at: Vector3 in _seeds:
					if hero.flat_pos().distance_to(at) < 1.7 + hero.radius * 0.5:
						hunt.damage_hero(dmg * 0.8, self, 0.5)
					hunt.fx.burst(at, GREEN, 10, 5.0, 1.0)
					hunt.fx.puff(at, Color(0.3, 0.25, 0.15, 0.6), 6, 1.0, 2.0)
					# The briar stays: ground you cannot stand on for a while.
					hunt.add_fire_patch(at, 1.5, 7.0 if enraged else 5.0, dmg * 0.35)
				Sfx.play("boss_hit", -4.0, 1.3)
				_finish(0.7)
		"lash":
			# Vines sweep across in a fan, one after another.
			if step_t <= 0.0:
				var n := 5 if enraged else 4
				if step < n:
					hunt.beam_from(flat_pos(), _lash_yaw + 0.35 * step, 0.7, dmg * 0.9, GREEN)
					step += 1
					step_t = 0.22
				else:
					_finish(0.9)
		"roots":
			if step == 0 and step_t <= 0.0:
				step = 1
				var n := 3 if enraged else 2
				for i in n:
					var at := hero.flat_pos() + hero.vel * 0.3 + (Vector3.ZERO if i == 0 else Vector3(randf_range(-3, 3), 0, randf_range(-3, 3)))
					hunt.blast_at(hunt.arena.resolve(at, 0.4), 2.0, 1.0 + 0.2 * i, dmg * 0.6, "root", GREEN, 0.4)
				_finish(0.8)
