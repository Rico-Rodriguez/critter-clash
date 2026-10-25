extends "res://src/hunt/hunt_events.gd"
## The hunt, part 5: the rules that differ by mode. The Long Road's rooms,
## the Wilderness rivals, the Descent's depths and pacts, Boss Rush, and
## waking a boss.


# --- The Long Road ------------------------------------------------------------

func _direct_trial(dt: float) -> void:
	_tick_spawn_queue(dt)
	var tr: Dictionary = arena.trial
	var z := hero.position.z
	var frac := clampf((arena.start.z - z) / (arena.start.z - float(tr["boss_z"])), 0.0, 1.0)
	souls = maxi(souls, int(frac * souls_goal))
	for r: Dictionary in tr["rooms"]:
		match str(r["state"]):
			"idle":
				if int(r["index"]) > 0 and z < float(r["hi"]) - 4.0:
					_start_room(r)
			"active":
				# The sealed way on holds: a shove into the gate must not pop the
				# hero out on the far side, past the fight.
				if hero.position.z < float(r["lo"]) + hero.radius and hero.position.z > float(r["lo"]) - 3.0:
					hero.position.z = float(r["lo"]) + hero.radius + 0.9
				if _spawn_q.is_empty() and _room_alive(r) == 0:
					_clear_room(r)
				elif r.has("deadline") and time > float(r["deadline"]) and not r.get("sealed", false):
					r["sealed"] = true
					banner("The vault seals", Color(0.9, 0.5, 0.4), "Too slow. The chest is lost.")
					Sfx.play("shield_break", -2.0, 0.6)
	# The dead left behind in earlier rooms fade away.
	for f in foes.duplicate():
		if f.alive and absf(f.position.z - z) > 42.0:
			foes.erase(f)
			f.queue_free()
	if boss == null and z < float(tr["boss_z"]) and phase == "rise":
		arena.set_gate(tr["boss_gate"], true)
		_begin_boss()


## A room wakes up as the hero walks in: the way on is sealed until it is clear.
func _start_room(r: Dictionary) -> void:
	r["state"] = "active"
	var kind := str(r["kind"])
	var d: float = r["depth"]
	var press := float(tier.get("press", 1.0))
	var base := int((14.0 + d * 26.0) * press)
	var plan: Array = []
	var title := "Ambush!"
	var sub := "The dead rise around you"
	match kind:
		"ambush":
			for i in base:
				plan.append({"kind": _pick_kind(d)})
		"horde":
			title = "A horde!"
			sub = "Too many to count"
			for i in int(base * 1.5):
				plan.append({"kind": ["minion", "minion", "minion", "hound", "bomber"][randi() % 5]})
		"hunters":
			title = "Crossbows!"
			sub = "Close the distance or break their aim"
			for i in 6 + int(d * 8):
				plan.append({"kind": "rogue" if randf() < 0.65 else "mage"})
			for i in base / 3:
				plan.append({"kind": "minion"})
		"brutes":
			title = "Bone Brutes"
			sub = "Stay out of the slam"
			for i in (3 if d > 0.6 else 2):
				plan.append({"kind": "brute"})
			for i in base / 2:
				plan.append({"kind": _pick_kind(d)})
		"elite":
			title = "A champion guards the way"
			sub = "Cut him down"
			plan.append({"kind": ["warrior", "minion", "rogue", "mage"][randi() % 4], "elite": true})
			if d > 0.6:
				plan.append({"kind": "warrior", "elite": true})
			for i in base / 2:
				plan.append({"kind": _pick_kind(d)})
		"treasure":
			title = "Guarded treasure"
			sub = "The chest is yours if you win"
			for i in base / 2:
				plan.append({"kind": _pick_kind(d)})
		"shrine":
			# Some quiet places are not quiet: a cursed altar and its keepers.
			if randf() < 0.4:
				r["altar"] = true
				title = "A cursed altar"
				sub = "Its keepers wake. Win, and it pays twice"
				for i in 2 + int(ai() * 0.5):
					plan.append({"kind": ["warrior", "rogue", "mage"][randi() % 3], "elite": true})
				for i in base / 3:
					plan.append({"kind": _pick_kind(d)})
			else:
				title = "A quiet place"
				sub = "Rest, and take the blessing"
				for i in 3:
					_drop("heart", hero.flat_pos() + Vector3(randf_range(-3, 3), 0, randf_range(-3, 3)), 1)
	# Twists: some fights happen in the dark, and a vault must be won quickly.
	if kind == "treasure":
		r["deadline"] = time + 25.0
		sub = "Win in 25 seconds or the vault seals"
	elif kind != "shrine" and randf() < 0.15 + 0.12 * ai():
		r["dark"] = true
		_set_dark(true)
		sub = "The torches gutter out. %s" % sub
	banner(title, Color(1.0, 0.82, 0.5) if kind != "shrine" else Color(0.7, 0.95, 0.7), sub)
	Sfx.play("roar", -4.0, 1.2)
	if plan.is_empty():
		r["state"] = "clear"
		rooms_cleared += 1
		return
	arena.set_gate(r["gate"], true)
	# Packs of four from a point in the room, spaced out over a few seconds.
	var center := Vector3.ZERO
	for i in plan.size():
		if i % 4 == 0:
			center = arena.room_point(r, hero.position, 8.0)
		var spot := arena.resolve(center + Vector3(randf_range(-1.8, 1.8), 0, randf_range(-1.8, 1.8)), 0.6)
		_spawn_q.append({"t": 0.35 * i + (i / 4) * 0.8, "kind": plan[i]["kind"], "pos": spot, "elite": plan[i].get("elite", false), "room": r})


## A dark room: the hero's lantern shrinks and the room loses its light.
func _set_dark(on: bool) -> void:
	var t := create_tween().set_parallel()
	t.tween_property(hero.light, "omni_range", 6.0 if on else 11.0, 1.2)
	t.tween_property(arena.env, "ambient_light_energy", float(zone["env"]["ambient_e"]) * (0.25 if on else 1.0), 1.2)


func _tick_spawn_queue(dt: float) -> void:
	var i := _spawn_q.size() - 1
	while i >= 0:
		var q: Dictionary = _spawn_q[i]
		q["t"] -= dt
		if q["t"] <= 0.0:
			if foes.size() < MAX_FOES:
				var e := spawn_foe(q["kind"], q["pos"], q["elite"])
				(q["room"]["foes"] as Array).append(e)
				if q["elite"]:
					banner(e.elite_name, DB.ELITE_AFFIXES[e.affixes[0]]["color"].lightened(0.3), "A champion!")
			_spawn_q.remove_at(i)
		i -= 1


func _clear_room(r: Dictionary) -> void:
	r["state"] = "clear"
	rooms_cleared += 1
	arena.set_gate(r["gate"], false)
	if r.get("dark", false):
		_set_dark(false)
	var at := hero.flat_pos()
	banner("Room cleared", Color(0.6, 1.0, 0.7), "The way is open")
	safe_moment()
	Sfx.play("rare_chime", -2.0)
	var kind := str(r["kind"])
	for i in randi_range(4, 7):
		_drop("gold", at, randi_range(2, 5))
	for i in randi_range(1, 2):
		_drop("heart", at + Vector3(randf_range(-2, 2), 0, randf_range(-2, 2)), 1)
	var d: float = r["depth"]
	if r.get("altar", false):
		for i in 2:
			_drop_item(at, _roll_good("elite", 2))
	elif kind in ["elite", "brutes"]:
		_drop_item(at, _roll_good("elite", 1))
	elif kind == "treasure" and not r.get("sealed", false):
		var cp: Vector3 = r.get("chest_at", at)
		fx.puff(cp, Color(1.0, 0.85, 0.4, 0.6), 10, 1.0, 2.0)
		Sfx.play("chest_land", -2.0)
		for i in 2:
			_drop_item(cp, _roll_good("chest", 1))
		for i in 8:
			_drop("gold", cp, randi_range(3, 7))
	elif randf() < 0.3 + 0.2 * d:
		_drop_item(at, Game.roll_item("trash", tier_i, "", "", loot_bonus))


# --- The Wilderness -----------------------------------------------------------

func _spawn_rivals() -> void:
	rivals_spawned = true
	rivals_total = int(DB.WILD_RIVALS[tier_i])
	var order := ["knight", "ranger", "mage", "barbarian", "rogue"]
	order.shuffle()
	for i in rivals_total:
		var a := TAU * (i + randf() * 0.4) / rivals_total
		var at := arena.resolve(DB.WILD_CENTER + Vector3(sin(a), 0, cos(a)) * 17.0, 0.8)
		if at.distance_to(hero.position) < 12.0:
			at = arena.resolve(DB.WILD_CENTER + Vector3(sin(a + PI), 0, cos(a + PI)) * 15.0, 0.8)
		spawn_foe("rival_" + str(order[i % order.size()]), at)
	banner("The Wilderness", Color(0.95, 0.75, 0.45), "%d rival bands. The ring closes. Be the last." % rivals_total)
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.0
	cyl.bottom_radius = 1.0
	cyl.height = 6.0
	cyl.radial_segments = 72
	cyl.rings = 1
	cyl.cap_top = false
	cyl.cap_bottom = false
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(1.0, 0.22, 0.2, 0.22)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	ring_mesh = MeshInstance3D.new()
	ring_mesh.mesh = cyl
	ring_mesh.material_override = m
	ring_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring_mesh.position = DB.WILD_CENTER + Vector3(0, 3.0, 0)
	world.add_child(ring_mesh)


func _tick_wild(dt: float) -> void:
	if not rivals_spawned:
		if time > 1.5:
			_spawn_rivals()
		return
	ring_r = DB.wild_ring(time)
	ring_mesh.scale = Vector3(ring_r, 1.0, ring_r)
	# Each time the ring starts to close a banner says so.
	var stage := 0
	for t in [35.0, 95.0, 150.0, 200.0]:
		if time >= t:
			stage += 1
	if stage > _ring_stage:
		_ring_stage = stage
		banner("The ring closes", Color(1.0, 0.45, 0.35), "Get inside")
		Sfx.play("roar", -4.0, 0.8)
	_ring_hurt_t -= dt
	if _ring_hurt_t <= 0.0:
		_ring_hurt_t = 0.5
		if hero.alive and hero.flat_pos().distance_to(DB.WILD_CENTER) > ring_r + 0.4:
			damage_hero(hero.max_hp * (0.03 + 0.012 * _ring_stage), null)
		for f in foes.duplicate():
			if is_instance_valid(f) and f.alive and f.state != "spawn" and f.flat_pos().distance_to(DB.WILD_CENTER) > ring_r + 0.4:
				damage_foe(f, f.max_hp * 0.06, null, Vector3.ZERO, 0.0)
	if hero.alive and phase == "rise" and rivals_alive() == 0:
		_wild_win()


func _wild_win() -> void:
	phase = "victory"
	phase_t = 0.0
	_end_time = time
	Sfx.music("", 2.0)
	Sfx.play("sting_victory", 0.0)
	banner("Last band standing", Color(1.0, 0.85, 0.45), "The Wilderness is yours")
	if hero.alive:
		hero.act("Cheering", 1.6, true)
	var at := hero.flat_pos()
	for i in 24:
		_drop("gold", at, randi_range(3, 8))
	for i in 2:
		_drop_item(at, Game.roll_item("boss", tier_i, "", "", loot_bonus))
	for i in 8:
		_drop("soul", at, 4)
	for f in foes.duplicate():
		if f.alive:
			_kill(f)


# --- Endless Descent and Boss Rush --------------------------------------------

## Two pacts you have not taken, or nothing if all are spent.
func offer_pact() -> void:
	pact_offered = true
	var pool: Array = DB.PACTS.keys().filter(func(k): return not k in pacts)
	pool.shuffle()
	var choices := pool.slice(0, 2)
	if choices.is_empty():
		return
	if bot:
		pick_pact(choices[0])
		return
	tip("pact", "A pact: power with a price. You may refuse both", "dripping-sword")
	end_hitstop()
	get_tree().paused = true
	hud.show_pact(choices)


func pick_pact(id: String) -> void:
	get_tree().paused = false
	if id == "":
		return
	pacts.append(id)
	foe_speed_mult *= 1.0 + float(DB.PACTS[id]["mod"].get("foe_speed", 0.0))
	hero.recompute()
	if id == "vow":
		hero.hp = minf(hero.hp + hero.max_hp * 0.35, hero.max_hp)
	banner(str(DB.PACTS[id]["name"]), Color(0.85, 0.5, 0.95), str(DB.PACTS[id]["good"]))
	Sfx.play("unlock_start", -2.0, 0.8)


func _tick_depth(dt: float) -> void:
	depth_t += dt
	if depth_t < DB.DESCENT_TIME:
		return
	depth_t = 0.0
	depth += 1
	banner("Depth %d" % depth, Color(0.95, 0.8, 0.5), "The dead grow bolder")
	_depth_moment()
	# Deeper looks deeper: thicker fog, redder light, less of the moon.
	var k := clampf((depth - 1) / 12.0, 0.0, 1.0)
	var tw := create_tween().set_parallel()
	tw.tween_property(arena.env, "fog_density", float(zone["env"]["fog_d"]) * (1.0 + 1.6 * k), 2.0)
	tw.tween_property(arena.env, "fog_light_color", Color(zone["env"]["fog"]).lerp(Color(0.22, 0.04, 0.05), k), 2.0)
	tw.tween_property(arena.sun, "light_energy", float(zone["env"]["sun_e"]) * (1.0 - 0.6 * k), 2.0)
	Sfx.play("boom", -4.0, 0.8)
	shake(0.25)
	for i in 2:
		_drop("heart", hero.flat_pos() + Vector3(randf_range(-3, 3), 0, randf_range(-3, 3)), 1)
	if depth % DB.DESCENT_BOSS_EVERY == 0:
		var lap := depth / DB.DESCENT_BOSS_EVERY
		cur_boss = "gravemaw" if lap % 2 == 1 else "hexer"
		_begin_boss()
		return
	if depth % 4 == 0:
		offer_pact()
	for i in 1 + depth / 6:
		var kinds := ["warrior", "minion", "rogue", "mage"]
		var at := arena.spawn_point(hero.position, 7.0, 11.0)
		var e := spawn_foe(kinds[randi() % kinds.size()], at, true)
		banner(e.elite_name, DB.ELITE_AFFIXES[e.affixes[0]]["color"].lightened(0.3), "A champion rises!")
	if depth % 3 == 0:
		_start_surge(progress())


## The ground gives way a little further: a red shockwave out from the hero,
## embers bursting from the earth all around, the camera dropping back.
func _depth_moment() -> void:
	var at := hero.flat_pos()
	var col := Color(1.0, 0.3, 0.15)
	fx.vfx.nova(&"physical", at, 12.0, 0.9, Fx.VfxLib.NO_TINT, &"big")
	fx.vfx.nova(&"fire", at, 6.0, 0.6, Fx.VfxLib.NO_TINT, &"big")
	for i in 14:
		var p := at + Vector3(randf_range(-10.0, 10.0), 0, randf_range(-10.0, 10.0))
		fx.embers_at(p, col.lerp(Color(1.0, 0.8, 0.4), randf()), 4, 0.8)
	fx.puff(at, Color(0.3, 0.12, 0.08, 0.5), 10, 4.0, 3.0)
	cam.punch = -0.12


func _direct_rush(dt: float) -> void:
	rush_wait -= dt
	if rush_wait > 0.0 or _warming or boss != null:
		return
	var entry: Array = rush_order()[rush_i]
	cur_boss = str(entry[0])
	cur_boss_power = float(entry[1])
	_begin_boss()


func _begin_boss() -> void:
	boss_at = time
	phase = "boss_intro"
	phase_t = 0.0
	hero.invuln = 3.0
	# The King draws every soul to himself: the risen fall where they stand.
	for f in foes.duplicate():
		if f.alive:
			f.die()
			corpses.append(f)
			fx.bone_burst(f.flat_pos(), 3, 4.0)
	foes.clear()
	for pr in projs:
		_release_proj(pr)
	projs.clear()
	boss = _make_boss()
	world.add_child(boss)
	boss.position = arena.boss_spawn
	boss.rotation.y = 0.0
	var boss_tier := scaled_tier()
	if mode == "descent":
		# Each lap of bosses is bigger than the last.
		boss_tier = boss_tier.duplicate()
		boss_tier["hp"] = float(tier["hp"]) * (1.0 + 0.5 * (depth / DB.DESCENT_BOSS_EVERY - 1))
	boss.setup(self, boss_tier)
	cam.focus_override = arena.boss_spawn + Vector3(0, 0, 3.0)
	fx.puff(arena.boss_spawn, Color(0.3, 0.27, 0.22, 0.85), 22, 3.0, 3.0)
	fx.bone_burst(arena.boss_spawn, 10, 8.0)
	var aura: Color = DB.boss_def(cur_boss)["color"]
	fx.vfx.nova(&"shadow", arena.boss_spawn, 7.0, 0.8, Fx.VfxLib.NO_TINT, &"big")
	fx.vfx.impact(&"shadow", arena.boss_spawn, 2.5, Fx.VfxLib.NO_TINT, &"big")
	shake(0.8)
	Sfx.music(str(zone.get("boss_music", "boss")) if mode != "rift" else "rift", 0.6)
	Sfx.play("boss_roar", 2.0)
	var bd := DB.boss_def(cur_boss)
	banner(str(bd["name"]), Color(bd["color"]).lightened(0.25), str(bd["wake"]))
	if cur_boss == "gravemaw":
		tip("exposed", "Bait his charge into a wall: a dazed king takes 50% more", "bullseye")
	else:
		tip("exposed_q", "Close in when she casts: she reels and takes 50% more", "bullseye")
