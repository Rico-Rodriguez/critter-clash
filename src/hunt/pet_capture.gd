extends RefCounted
## The "petfx" capture shot: in a live hunt the sidekick walks up, winds up and
## fires its real ability at the nearest foe, saving a frame every `step`
## seconds of sim time (petfx_NN.png) so a contact sheet shows the anticipation,
## the hit and the follow-through. `--el=frost` recolours it to another
## element, `--stage=0|1|2` previews its growth stage.


static func shoot(main: Node, h: Node, el: String, frames: int, step: float) -> void:
	await main._wait_sim(h, 2.5)
	h.bot = false
	h.hero.hp = h.hero.max_hp * 50.0
	h.hero.max_hp *= 50.0
	var sk = h.sidekick
	if sk == null:
		print("PETFX no sidekick")
		return
	if el != "":
		sk.def = sk.def.duplicate(true)
		sk.def["vfx_el"] = StringName(el)
		sk.def["color"] = h.fx.vfx.COLORS[StringName(el)]
	sk.cd = 999.0
	# A tidy stage: three foes frozen in a pack ahead of the hero, the rest sent away.
	var pack := 0
	var hp: Vector3 = h.hero.position
	for f in h.foes:
		f.stun_t = 999.0
		if pack < 3:
			f.position = hp + Vector3(-0.8 + 1.0 * pack, 0, -3.6 + 0.4 * (pack % 2))
			f.hp = f.max_hp * 100.0
			pack += 1
		else:
			f.position = hp + Vector3(0, 0, 80)
	await main._wait_sim(h, 1.2)
	sk.motor.pos = hp + Vector3(1.3, 0, -1.1)
	sk.motor.vel = Vector3.ZERO
	sk.position = Vector3(sk.motor.pos.x, sk.position.y, sk.motor.pos.z)
	await main._wait_sim(h, 0.3)
	sk.cd = 0.0
	var at = sk._wants_to_act()
	if at != null:
		sk._wind_up(at)
	for i in frames:
		await main._save("petfx_%02d" % i)
		await main._wait_sim(h, step)
