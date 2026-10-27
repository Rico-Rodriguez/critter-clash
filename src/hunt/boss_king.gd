extends Boss
## Gravemaw, the Barrow King (also the Lightless King of the story, and the
## Boss Rush / Descent / rift pick). He keeps the base cleave, quake, charge,
## spears and graves, and across the fight gains:
##   phase 2  Crown of Bones: two rings of bone erupt round him, one close and
##            one wide, with a safe lane between them: step into the lane
##   phase 3  Rampage: a charge that finds open floor turns and charges again
## The room: at phase 2 and 3 green grave-fire breaks out round him.
## (No class_name: scripts the IPA didn't bake are preloaded by path.)

const BONE := Color(0.4, 1.0, 0.75)

var _crown_at := Vector3.ZERO


func setup(h: Hunt, t: Dictionary) -> void:
	super.setup(h, t)
	chain_charge = true


func _choose(dist: float) -> void:
	combo = 0
	var options := []
	if dist < 5.5:
		options += ["cleave", "cleave", "quake"]
	else:
		options += ["charge", "spears"]
	options += ["graves", "spears"]
	if phase >= 2:
		options += ["bonecrown", "bonecrown"]
	if final:
		options += ["charge"]
	options.erase(last)
	_begin(options[randi() % options.size()])


func _begin(p: String) -> void:
	if p != "bonecrown":
		super._begin(p)
		return
	_clear_tele()
	pattern = p
	last = p
	state = "attack"
	step = 0
	var fast := 0.85 if final else 1.0
	rotation.y = yaw_to(position, hunt.hero.position)
	_crown_at = flat_pos()
	# Two rings, the wide one a beat after the near one; the lane between is safe.
	for i in 7:
		var a := TAU * i / 7.0
		hunt.blast_at(hunt.arena.resolve(_crown_at + Vector3(sin(a), 0, cos(a)) * 4.2, 0.3), 1.8, 1.25 * fast, dmg * 0.9, "", BONE)
	for i in 13:
		var a2 := TAU * (i + 0.5) / 13.0
		hunt.blast_at(hunt.arena.resolve(_crown_at + Vector3(sin(a2), 0, cos(a2)) * 9.6, 0.3), 2.0, 1.6 * fast, dmg * 0.9, "", BONE)
	step_t = 1.9 * fast
	play("Skeletons_Taunt", 0.1, anim_length("Skeletons_Taunt") / step_t, true)
	Sfx.play("boss_roar", -2.0, 0.8)
	hunt.hud.event("Crown of Bones", BONE, "crowned-skull")


func _tick_pattern(dt: float, to: Vector3, dist: float) -> void:
	if pattern != "bonecrown":
		super._tick_pattern(dt, to, dist)
		return
	step_t -= dt
	if step_t <= 0.0:
		hunt.shake(0.4)
		_finish(0.9)


func _phase_lines(n: int) -> Array:
	if n == 2:
		return ["The King rises", "\"You will lie beside them.\""]
	return ["The Barrow Unbound", "\"Then I will walk you down.\""]


func _phase_fx(n: int) -> void:
	hunt.fx.vfx.nova(&"physical", flat_pos(), 8.0, 0.45, Fx.VfxLib.NO_TINT, &"big")
	if n == 3:
		hunt.fx.vfx.sky(flat_pos(), BONE, 0.3, 14.0)


func _phase_arena(n: int) -> void:
	# Grave-fire round the King: more of it, and wider, each phase.
	_patch_ring(5 if n == 2 else 8, 9.5 if n == 2 else 11.0, 1.8, 14.0, dmg * 0.3, &"poison", false, randf() * TAU)
