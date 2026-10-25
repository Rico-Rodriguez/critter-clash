extends RefCounted
## `-- --capture --shots=collision [--zone=barrow|depths|grove]`: frames of the
## hero walking into a big building and a foe routing round one, with every
## collider outlined, plus a top-down map. Prints COLL lines the PR quotes.

const PS := preload("res://src/hunt/prop_shapes.gd")


static func shoot(main: Node, h: Hunt, zone: String) -> void:
	h.spawn_t = 1e9
	# Past the hunt's warm-up and intro (the autopilot plays through them).
	await main._wait_sim(h, 2.5)
	h.bot = false
	for f in h.foes.duplicate():
		f.queue_free()
	h.foes.clear()
	await main._wait_sim(h, 0.3)
	h.arena.debug_outlines()
	await _map(main, h, zone)
	var plan: Dictionary = {
		"barrow": {"push": [Vector3(1.5, 0, -12.0), Vector2(0, -1)], "route": [Vector3(-3.0, 0, -17.5), Vector3(7.6, 0, -28.0)]},
		"depths": {"push": [Vector3(14.0, 0, 9.0), Vector2(0, -1)], "route": [Vector3(14.0, 0, 0.0), Vector3(14.0, 0, 8.5)]},
		"grove": {"push": [Vector3(0, 0, 0), Vector2(0, -1)], "route": [Vector3(0, 0, 0), Vector3(0, 0, -8)]},
	}[zone]
	if zone == "grove":
		# The grove's shrine: hero south of it walking in, a foe behind it.
		var at := _first(h, "shrine.gltf")
		plan["push"] = [at + Vector3(0.3, 0, 6.0), Vector2(0, -1)]
		plan["route"] = [at + Vector3(0, 0, 3.5), at + Vector3(0, 0, -3.5)]
	await _push(main, h, zone, plan["push"][0], plan["push"][1])
	await _route(main, h, zone, plan["route"][0], plan["route"][1])


static func _first(h: Hunt, file: String) -> Vector3:
	for p: Dictionary in h.arena.props:
		if str(p["path"]).get_file() == file:
			return p["pos"]
	return Vector3.ZERO


static func _map(main: Node, h: Hunt, zone: String) -> void:
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	var a := h.arena
	cam.size = maxf(a.max_x - a.min_x, a.max_z - a.min_z) + 6.0
	cam.position = Vector3((a.min_x + a.max_x) * 0.5, 60.0, (a.min_z + a.max_z) * 0.5)
	cam.rotation_degrees = Vector3(-90, 0, 0)
	cam.far = 200.0
	h.add_child(cam)
	var was := h.get_viewport().get_camera_3d()
	cam.current = true
	await main._wait(0.3)
	await main._save("coll_%s_map" % zone)
	cam.current = false
	if was:
		was.current = true
	cam.queue_free()


## The hero holds the stick toward a building for 3 s.
static func _push(main: Node, h: Hunt, zone: String, from: Vector3, stick: Vector2) -> void:
	h.hero.position = from
	h.cam.focus_override = from + Vector3(0, 0, -4.0)
	var frames := 18
	var inside := false
	for i in frames:
		_hold(stick)
		h.hero.invuln = 99.0
		await main._wait_sim(h, 0.18)
		inside = inside or _inside(h, h.hero.position, h.hero.radius)
		await main._save("coll_%s_push_%02d" % [zone, i])
	_hold(Vector2.ZERO)
	print("COLL %s push hero from=%s end=%s inside=%s" % [zone, from, h.hero.position, str(inside)])
	h.cam.focus_override = null


## A foe on the far side of a building walks round it to reach the hero.
static func _route(main: Node, h: Hunt, zone: String, hero_at: Vector3, foe_at: Vector3) -> void:
	h.hero.position = hero_at
	h.hero.vel = Vector3.ZERO
	var e: Enemy = h.spawn_foe("brute" if zone != "grove" else "minion", foe_at)
	e.max_hp = 1e9
	e.hp = 1e9
	h.cam.focus_override = (hero_at + foe_at) * 0.5 + Vector3(0, 0, 2.0)
	h.cam.dist_mult = 1.25
	var inside := false
	var path: Array = []
	var reached := -1.0
	var t0 := h.time
	for i in 40:
		h.hero.position = hero_at
		h.hero.invuln = 99.0
		await main._wait_sim(h, 0.25)
		if not is_instance_valid(e):
			break
		path.append(e.position)
		inside = inside or _inside(h, e.position, e.radius)
		if reached < 0.0 and e.position.distance_to(hero_at) < e.radius + h.hero.radius + 1.2:
			reached = h.time - t0
		if i % 2 == 0:
			_dot(h, e.position)
			await main._save("coll_%s_route_%02d" % [zone, i / 2])
	print("COLL %s route foe from=%s to hero=%s reached=%s at=%.1fs inside=%s" % [zone, foe_at, hero_at, str(reached >= 0.0), reached, str(inside)])
	h.cam.focus_override = null


static func _hold(v: Vector2) -> void:
	for pair in [["move_left", -v.x], ["move_right", v.x], ["move_up", -v.y], ["move_down", v.y]]:
		if float(pair[1]) > 0.0:
			Input.action_press(pair[0], float(pair[1]))
		else:
			Input.action_release(pair[0])


## Whether a walker of radius r sinks into a collider (more than a fifth of
## its radius: resolve() leaves it touching, never inside).
static func _inside(h: Hunt, p: Vector3, r: float) -> bool:
	return h.arena.blocked(p, r * 0.8)


static func _dot(h: Hunt, p: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.12
	s.height = 0.24
	mi.mesh = s
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1.0, 0.35, 0.2)
	mi.material_override = m
	mi.position = p + Vector3(0, 0.15, 0)
	h.add_child(mi)
