extends Boss
## The Cinder Ogre, who tends the Burning Swamp: a brute with a furnace in his
## chest. He keeps Gravemaw's cleave, quake and charge, and adds three:
##   eruption  a line of fire bursts out from him toward you, one after another
##   inferno   a blast under him, then a ring of fire round that: stand in the gap
##   bloats    he coughs up methane bloats; pop them away from yourself
## A spent inferno leaves him open. Enraged: a longer eruption, more bloats.
## (No class_name: scripts the IPA didn't bake are preloaded by path.)

const FIRE := Color(1.0, 0.5, 0.15)
const MINE := ["eruption", "inferno", "bloats"]

var _line: Array = []


func setup(h: Hunt, t: Dictionary) -> void:
	super.setup(h, t)
	keep_dist = 3.4


func _choose(dist: float) -> void:
	var options := ["eruption", "inferno", "bloats"]
	if dist < 5.5:
		options += ["cleave", "quake"]
	else:
		options += ["charge", "eruption"]
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
	var yaw := yaw_to(position, hero.position)
	rotation.y = yaw
	match p:
		"eruption":
			_line.clear()
			var n := 8 if enraged else 6
			var fwd := Vector3(sin(yaw), 0, cos(yaw))
			for i in n:
				var at := hunt.arena.resolve(flat_pos() + fwd * (3.0 + i * 2.6), 0.4)
				_line.append(at)
				hunt.blast_at(at, 1.6, 0.8 + i * 0.16, dmg * 0.8, "", FIRE)
			step_t = 0.8 + n * 0.16 + 0.4
			play("Melee_2H_Attack_Chop", 0.1, 0.8, true)
			Sfx.play("boss_windup", -3.0, 0.8)
			hunt.hud.event("Eruption", FIRE, "fire-ring")
		"inferno":
			var c := flat_pos()
			hunt.blast_at(c, 3.4, 1.2, dmg * 1.0, "", FIRE, 0.8)
			var n := 10
			var gap := randi() % n
			for i in n:
				if i == gap:
					continue
				var a := TAU * i / n
				hunt.blast_at(hunt.arena.resolve(c + Vector3(sin(a), 0, cos(a)) * 6.4, 0.3), 2.1, 1.7, dmg * 0.8, "", FIRE)
			step_t = 2.4
			play("Skeletons_Taunt", 0.1, 1.0, true)
			Sfx.play("boss_roar", -3.0, 0.9)
			hunt.hud.event("Inferno", FIRE, "flame")
		"bloats":
			step_t = 1.0
			play("Ranged_Magic_Summon", 0.1, 1.0, true)
			Sfx.play("boss_windup", -4.0, 0.7)
			hunt.fx.telegraph(0, flat_pos(), 0.0, Vector2(radius + 1.0, 0), step_t, 0.6, &"fire")


func _tick_pattern(dt: float, to: Vector3, dist: float) -> void:
	if not pattern in MINE:
		super._tick_pattern(dt, to, dist)
		return
	step_t -= dt
	match pattern:
		"eruption":
			if step_t <= 0.0:
				hunt.shake(0.3)
				_finish(0.8)
		"inferno":
			if step_t <= 0.0:
				hunt.shake(0.45)
				_finish(0.4)
				expose(float(DB.EXPOSED["time"]) * 0.6)
		"bloats":
			if step_t <= 0.0:
				var n := 3 if enraged else 2
				for i in n:
					var a := TAU * i / n + randf() * 0.6
					if hunt.foes.size() < Hunt.MAX_FOES:
						hunt.spawn_foe("bomber", hunt.arena.resolve(flat_pos() + Vector3(sin(a), 0, cos(a)) * 4.0, 0.6))
				Sfx.play("boss_hit", -6.0, 0.8)
				_finish(0.9)
