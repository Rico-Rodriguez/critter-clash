extends Boss
## The Gilded Warden, keeper of the Vault: a knight in gold who swings the
## Vault's own key and carries its door for a shield. He keeps Gravemaw's
## cleave, quake and charge, and adds two of his own:
##   coinfall  gold rains on circles around the hero, one after another
##   lockdown  a ring of blasts shuts round the hero with one gap left open,
##             then the middle falls in: walk out through the gap
## Spending a lockdown leaves him open. Enraged, more coins and a tighter ring.
## (No class_name: scripts the IPA didn't bake are preloaded by path.)

const GOLD := Color(1.0, 0.82, 0.35)

var _coins: Array = []


func setup(h: Hunt, t: Dictionary) -> void:
	super.setup(h, t)
	keep_dist = 3.6


func _choose(dist: float) -> void:
	var options := ["coinfall", "lockdown"]
	if dist < 5.5:
		options += ["cleave", "quake"]
	else:
		options += ["charge", "coinfall"]
	options.erase(last)
	_begin(options[randi() % options.size()])


func _begin(p: String) -> void:
	if not p in ["coinfall", "lockdown"]:
		super._begin(p)
		return
	_clear_tele()
	pattern = p
	last = p
	state = "attack"
	step = 0
	step_t = 0.0
	var hero := hunt.hero
	rotation.y = yaw_to(position, hero.position)
	match p:
		"coinfall":
			_coins.clear()
			var n := 9 if enraged else 6
			for i in n:
				var off := Vector3.ZERO if i == 0 else Vector3(randf_range(-5.0, 5.0), 0, randf_range(-5.0, 5.0))
				var at := hunt.arena.resolve(hero.flat_pos() + off + hero.vel * 0.4, 0.4)
				_coins.append(at)
				tele.append(hunt.fx.telegraph(0, at, 0.0, Vector2(1.5, 0), 1.0 + i * 0.12))
			step_t = 1.0
			play("Ranged_Magic_Summon", 0.1, 1.0, true)
			Sfx.play("boss_windup", -4.0, 1.4)
		"lockdown":
			# Bolts all round the hero but one gap, then the middle.
			var at := hero.flat_pos()
			var n := 12
			var r := 3.2 if enraged else 3.8
			var gap := randi() % n
			for i in n:
				if i == gap or i == (gap + 1) % n:
					continue
				var a := TAU * i / n
				hunt.blast_at(hunt.arena.resolve(at + Vector3(sin(a), 0, cos(a)) * r, 0.3), 1.25, 1.1, dmg * 0.7, "slow", GOLD)
			hunt.blast_at(at, r - 1.0, 1.9, dmg * 1.0, "", GOLD, 0.8)
			step_t = 2.0
			play("Skeletons_Taunt", 0.1, 1.0, true)
			Sfx.play("boss_roar", -4.0, 1.1)
			hunt.hud.event("Lockdown", GOLD, "padlock")


func _tick_pattern(dt: float, to: Vector3, dist: float) -> void:
	if not pattern in ["coinfall", "lockdown"]:
		super._tick_pattern(dt, to, dist)
		return
	step_t -= dt
	var hero := hunt.hero
	match pattern:
		"coinfall":
			if step == 0 and step_t <= 0.0:
				step = 1
				step_t = 0.12 * _coins.size() + 0.1
			if step >= 1:
				var idx := int((0.12 * _coins.size() + 0.1 - step_t) / 0.12)
				while step - 1 < _coins.size() and step - 1 <= idx:
					var p: Vector3 = _coins[step - 1]
					if hero.flat_pos().distance_to(p) < 1.5 + hero.radius * 0.5:
						hunt.damage_hero(dmg * 0.85, self, 0.6)
					hunt.fx.burst(p, GOLD, 12, 6.0, 1.5)
					hunt.fx.ring(p, 1.5, GOLD, 0.3)
					Sfx.play("boss_hit", -6.0, 1.5)
					step += 1
				if step - 1 >= _coins.size():
					hunt.shake(0.25)
					_finish(0.6)
		"lockdown":
			if step_t <= 0.0:
				hunt.shake(0.4)
				_finish(0.4)
				# The vault shut on nothing: the moment to strike.
				expose(float(DB.EXPOSED["time"]) * 0.6)
