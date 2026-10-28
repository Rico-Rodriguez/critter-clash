extends Boss
## The Frost Troll, lord of the Frozen Crypt: a troll cased in ice. He keeps
## Gravemaw's cleave, quake and charge, and adds two of his own:
##   spikes    a fan of ice lanes from him, each leaving a drag of frost
##             where it ends: step between the lanes
##   blizzard  three volleys of crossing beams, each turned a little further
##             than the last: read the turn and keep moving
## A spent blizzard leaves him open. Enraged: a wider fan and a fourth beam.
## Across the fight:
##   phase 2  Shatter: ice pillars rise round you, then burst into crossing
##            lances: get clear of the pillars and out of the crosses
##   phase 3  Whiteout: five fast volleys of six beams, the gaps turning each
##            time, and frost left where every beam ends
## The room: patches of drag-frost take the edges at 2 and 3.
## (No class_name: scripts the IPA didn't bake are preloaded by path.)

const FROST := Color(0.6, 0.88, 1.0)
const MINE := ["spikes", "blizzard", "shatter", "whiteout"]

var _yaw0 := 0.0
var _pillars: Array = []


func setup(h: Hunt, t: Dictionary) -> void:
	super.setup(h, t)
	keep_dist = 3.8


func _choose(dist: float) -> void:
	var options := ["spikes", "blizzard"]
	if dist < 5.5:
		options += ["cleave", "quake"]
	else:
		options += ["charge", "spikes"]
	if phase >= 2:
		options += ["shatter", "shatter"]
	if final:
		options += ["whiteout", "whiteout"]
	options.erase(last)
	_begin(options[randi() % options.size()])


func _begin(p: String) -> void:
	if not p in MINE:
		super._begin(p)
		return
	_clear_tele()
	pattern = p
	last = p
	state = "attack"
	step = 0
	step_t = 0.0
	var hero := hunt.hero
	_yaw0 = yaw_to(position, hero.position)
	rotation.y = _yaw0
	match p:
		"spikes":
			var n := 7 if enraged else 5
			var spread := 0.3
			for i in n:
				var yaw := _yaw0 + (i - (n - 1) * 0.5) * spread
				hunt.beam_from(flat_pos(), yaw, 1.2, dmg * 0.8, FROST)
			step_t = 1.45
			play("Ranged_Magic_Spellcasting", 0.1, 1.0, true)
			Sfx.play("boss_windup", -4.0, 1.2)
			hunt.hud.event("Ice lances", FROST, "ice-bolt")
		"shatter":
			# Pillars rise round the hero; a beat after they burst they throw lances.
			_pillars.clear()
			var n := 6 if final else 4
			var off := randf() * TAU
			var lead := hero.flat_pos() + hero.vel * 0.3
			for i in n:
				var a := off + TAU * i / n
				var at := hunt.arena.resolve(lead + Vector3(sin(a), 0, cos(a)) * randf_range(3.6, 5.6), 0.4)
				_pillars.append(at)
				hunt.blast_at(at, 1.4, 1.2, dmg * 0.7, "slow", FROST)
			step_t = 1.25
			play("Ranged_Magic_Summon", 0.1, 1.0, true)
			Sfx.play("boss_windup", -3.0, 1.1)
			hunt.hud.event("Shatter", FROST, "ice-bolt")
		"whiteout":
			step_t = 0.9
			play("Skeletons_Taunt", 0.1, 1.0, true)
			Sfx.play("boss_roar", -2.0, 1.4)
			hunt.hud.event("Whiteout", FROST, "frozen-orb")
		"blizzard":
			step_t = 0.2
			play("Skeletons_Taunt", 0.1, 1.0, true)
			Sfx.play("boss_roar", -4.0, 1.3)
			hunt.hud.event("Blizzard", FROST, "frozen-orb")


func _tick_pattern(dt: float, to: Vector3, dist: float) -> void:
	if not pattern in MINE:
		super._tick_pattern(dt, to, dist)
		return
	step_t -= dt
	match pattern:
		"spikes":
			if step_t <= 0.0:
				# Frost where each lane ends: the ground drags for a while.
				var fwd_n := 7 if enraged else 5
				for i in fwd_n:
					var yaw := _yaw0 + (i - (fwd_n - 1) * 0.5) * 0.3
					var end := hunt.arena.resolve(flat_pos() + Vector3(sin(yaw), 0, cos(yaw)) * 11.0, 0.4)
					hunt.add_fire_patch(end, 1.4, 4.0, 0.0, &"frost", true)
				hunt.shake(0.25)
				_finish(0.8)
		"shatter":
			if step == 0 and step_t <= 0.0:
				step = 1
				step_t = 1.1
				var rot := randf() * PI * 0.5
				for p: Vector3 in _pillars:
					hunt.add_fire_patch(p, 1.4, 4.0, 0.0, &"frost", true)
					for k in 4:
						hunt.beam_from(p, rot + k * PI * 0.5, 0.9, dmg * 0.7, FROST)
				Sfx.play("boss_hit", -6.0, 1.4)
			elif step == 1 and step_t <= 0.0:
				hunt.shake(0.3)
				_finish(0.6)
		"whiteout":
			# Five quick volleys of six; each is turned a notch from the last.
			if step < 5 and step_t <= 0.0:
				var base := _yaw0 + step * 0.26
				for k in 6:
					var yaw := base + k * TAU / 6.0
					hunt.beam_from(flat_pos(), yaw, 0.8, dmg * 0.7, FROST)
					if step == 4 or step == 0:
						var end := hunt.arena.resolve(flat_pos() + Vector3(sin(yaw), 0, cos(yaw)) * 11.0, 0.4)
						hunt.add_fire_patch(end, 1.4, 4.0, 0.0, &"frost", true)
				step += 1
				step_t = 0.6
				Sfx.play("boss_hit", -8.0, 1.5)
			elif step >= 5 and step_t <= 0.0:
				hunt.shake(0.35)
				_finish(0.5)
				expose(float(DB.EXPOSED["time"]) * 0.7)
		"blizzard":
			if step < 3 and step_t <= 0.0:
				var beams := 4 if enraged else 3
				var base := _yaw0 + step * (PI / float(beams) * 0.5)
				for k in beams:
					hunt.beam_from(flat_pos(), base + k * TAU / float(beams), 0.9, dmg * 0.7, FROST)
				step += 1
				step_t = 0.85
				Sfx.play("boss_hit", -8.0, 1.4)
			elif step >= 3 and step_t <= 0.0:
				hunt.shake(0.3)
				_finish(0.5)
				expose(float(DB.EXPOSED["time"]) * 0.6)


func _phase_lines(n: int) -> Array:
	if n == 2:
		return ["The Troll rises", "\"Winter keeps what it takes.\""]
	return ["The Long Winter", "\"Nothing thaws. Nothing leaves.\""]


func _phase_fx(n: int) -> void:
	hunt.fx.vfx.nova(&"frost", flat_pos(), 8.0, 0.45, Fx.VfxLib.NO_TINT, &"big")
	if n == 3:
		hunt.fx.vfx.sky(flat_pos() + Vector3(1, 0, 2), FROST, 0.3, 14.0)


func _phase_arena(n: int) -> void:
	# Drag-frost takes the crypt's edges: more of it each phase.
	_patch_ring(4 if n == 2 else 7, 9.5 if n == 2 else 11.0, 1.9, 14.0, 0.0, &"frost", true, randf() * TAU)
