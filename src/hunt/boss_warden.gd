extends Boss
## The Gilded Warden, keeper of the Vault: a knight in gold who swings the
## Vault's own key and carries its door for a shield. He keeps Gravemaw's
## cleave, quake and charge, and adds two of his own:
##   coinfall  gold rains on circles around the hero, one after another
##   lockdown  a ring of blasts shuts round the hero with one gap left open,
##             then the middle falls in: walk out through the gap
## Spending a lockdown leaves him open. Enraged, more coins and a tighter ring.
## Across the fight:
##   phase 2  Avalanche: gold pours down in lanes across the floor, one after
##            another; stand between them
##   phase 3  the avalanche comes in a grid (a second set crosses the first), and
##            his charges chain, one into the next
## The room: gilded vault floor (slow, burning gold) takes the edges at 2 and 3.
## (No class_name: scripts the IPA didn't bake are preloaded by path.)

const GOLD := Color(1.0, 0.82, 0.35)

var _coins: Array = []


func setup(h: Hunt, t: Dictionary) -> void:
	super.setup(h, t)
	keep_dist = 3.6
	chain_charge = true


func _choose(dist: float) -> void:
	combo = 0
	var options := ["coinfall", "lockdown"]
	if phase >= 2:
		options += ["avalanche", "avalanche"]
	if dist < 5.5:
		options += ["cleave", "quake"]
	else:
		options += ["charge", "coinfall"]
	options.erase(last)
	_begin(options[randi() % options.size()])


func _begin(p: String) -> void:
	if not p in ["coinfall", "lockdown", "avalanche"]:
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
		"avalanche":
			# Lanes of gold across the floor, falling one after another.
			var fwd := dir_of(rotation.y)
			var perp := dir_of(rotation.y + PI * 0.5)
			var c := hero.flat_pos()
			var skip := randi() % 5
			for i in 5:
				if i == skip and final:
					continue
				var off := (i - 2) * 3.8
				var from := hunt.arena.resolve(c - fwd * 7.0 + perp * off, 0.4)
				hunt.beam_from(from, rotation.y, 1.0 + 0.22 * i, dmg * 0.9, GOLD)
			if final:
				# The second set crosses the first.
				var skip2 := randi() % 5
				for i in 5:
					if i == skip2:
						continue
					var off2 := (i - 2) * 3.8
					var from2 := hunt.arena.resolve(c - perp * 7.0 + fwd * off2, 0.4)
					hunt.beam_from(from2, rotation.y + PI * 0.5, 2.1 + 0.22 * i, dmg * 0.9, GOLD)
			step_t = (3.4 if final else 2.3)
			play("Skeletons_Taunt", 0.1, 1.0, true)
			Sfx.play("boss_roar", -4.0, 1.3)
			hunt.hud.event("Avalanche", GOLD, "two-coins")
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
	if not pattern in ["coinfall", "lockdown", "avalanche"]:
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
					hunt.fx.vfx.impact(&"holy", p, 1.5, GOLD, &"skill")
					Sfx.play("boss_hit", -6.0, 1.5)
					step += 1
				if step - 1 >= _coins.size():
					hunt.shake(0.25)
					_finish(0.6)
		"avalanche":
			if step_t <= 0.0:
				hunt.shake(0.3)
				_finish(0.7)
		"lockdown":
			if step_t <= 0.0:
				hunt.shake(0.4)
				_finish(0.4)
				# The vault shut on nothing: the moment to strike.
				expose(float(DB.EXPOSED["time"]) * 0.6)


func _phase_lines(n: int) -> Array:
	if n == 2:
		return ["The Vault opens", "\"Nothing leaves the Vault.\""]
	return ["The Vault seals", "\"Every coin has its keeper.\""]


func _phase_fx(n: int) -> void:
	hunt.fx.vfx.nova(&"holy", flat_pos(), 8.0, 0.45, Fx.VfxLib.NO_TINT, &"big")
	if n == 3:
		hunt.fx.vfx.sky(flat_pos() + Vector3(2, 0, 2), GOLD, 0.3, 14.0)


func _phase_arena(n: int) -> void:
	# Gilded floor takes the vault's edge: it drags and it burns.
	_patch_ring(4 if n == 2 else 7, 9.5 if n == 2 else 11.0, 1.8, 14.0, dmg * 0.25, &"holy", true, randf() * TAU)
