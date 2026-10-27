extends RefCounted
## Sound rules, run from tests.gd: hit layers, the heat of a fight, the button click.


static func run(_ok: Callable) -> void:
	# Sound: hits get a low layer; a fight heats the music and then cools it.
	_ok("sfx: thump layer exists", Sfx.has("thump"))
	_ok("sfx: hits are layered", Sfx.LAYERS.has("crit") and Sfx.LAYERS.has("boss_hit"))
	var layer_missing := []
	for ev in Sfx.LAYERS:
		for l in Sfx.LAYERS[ev]:
			if not Sfx.has(str(l[0])):
				layer_missing.append(str(l[0]))
	_ok("sfx: every layer is a real sound %s" % [layer_missing], layer_missing.is_empty())
	var heat_missing := []
	for ev in Sfx.HEAT:
		if not Sfx.has(str(ev)):
			heat_missing.append(ev)
	_ok("sfx: every heat event is a real sound %s" % [heat_missing], heat_missing.is_empty())
	Sfx.intensity = 0.0
	Sfx.play("boss_roar")
	_ok("sfx: a roar heats the music", Sfx.intensity > 0.3)
	Sfx.tick(4.0)
	_ok("sfx: the fight cools off", Sfx.intensity < 0.0001 or Sfx.intensity < 0.3)
	Sfx.tick(20.0)
	_ok("sfx: music settles to calm", Sfx.intensity == 0.0)
	Sfx.last_menu_ms = 0
	Sfx.play("coin", -80.0)
	_ok("sfx: menu sounds are noted for the button click", Sfx.last_menu_ms > 0)
