extends Boss
## The Rime Regent, lord of the Frozen Crypt: a skeleton king in ice. He keeps
## Gravemaw's cleave, quake and charge, and adds two of his own:
##   spikes    a fan of ice lanes from him, each leaving a drag of frost
##             where it ends: step between the lanes
##   blizzard  three volleys of crossing beams, each turned a little further
##             than the last: read the turn and keep moving
## A spent blizzard leaves him open. Enraged: a wider fan and a fourth beam.
## (No class_name: scripts the IPA didn't bake are preloaded by path.)

const FROST := Color(0.6, 0.88, 1.0)
const MINE := ["spikes", "blizzard"]

var _yaw0 := 0.0


func setup(h: Hunt, t: Dictionary) -> void:
	super.setup(h, t)
	keep_dist = 3.8


func _choose(dist: float) -> void:
	var options := ["spikes", "blizzard"]
	if dist < 5.5:
		options += ["cleave", "quake"]
	else:
		options += ["charge", "spikes"]
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
