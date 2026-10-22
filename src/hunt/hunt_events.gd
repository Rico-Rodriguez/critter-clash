extends "res://src/hunt/hunt_combat.gd"
## The hunt, part 4: things that happen during a hunt. Shrines, curses,
## surges, the ritual and ground hazards.


# --- Shrines and curses -------------------------------------------------------

## Each shrine gets a random blessing and a colored ring on the ground.
func _setup_shrines() -> void:
	var ids: Array = DB.SHRINES.keys()
	ids.shuffle()
	# One shrine in three hunts is cursed.
	var cursed_i := randi() % arena.shrines.size() if (mode == "horde" or mode == "descent") and randf() < 0.45 and arena.shrines.size() > 0 else -1
	var ring_shader := preload("res://src/fx/hero_ring.gdshader")
	for i in arena.shrines.size():
		var sd: Dictionary = arena.shrines[i]
		var id: String = ids[i % ids.size()] if i != cursed_i else "curse"
		var col: Color = DB.SHRINES[id]["color"] if id != "curse" else DB.CURSE["color"]
		(sd["light"] as OmniLight3D).light_color = col
		var ring := MeshInstance3D.new()
		var q := PlaneMesh.new()
		q.size = Vector2(3.6, 3.6)
		ring.mesh = q
		var m := ShaderMaterial.new()
		m.shader = ring_shader
		m.set_shader_parameter("color", col)
		m.set_shader_parameter("intensity", 1.4)
		ring.material_override = m
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		world.add_child(ring)
		ring.position = Vector3(sd["pos"].x, 0.06, sd["pos"].z)
		shrines.append({"pos": sd["pos"], "id": id, "fill": 0.0, "used": false, "ring": ring, "light": sd["light"]})


## Standing in a shrine's ring fills it; full, it blesses the hero for a while.
func _tick_shrines(dt: float) -> void:
	for s in shrines:
		if s["used"]:
			continue
		var inside: bool = hero.alive and hero.flat_pos().distance_to(s["pos"]) < 1.8
		s["fill"] = clampf(float(s["fill"]) + (dt / 1.5 if inside else -dt * 1.5), 0.0, 1.0)
		var k: float = s["fill"]
		(s["ring"] as MeshInstance3D).scale = Vector3.ONE * (1.0 + k * 0.3)
		(s["light"] as OmniLight3D).light_energy = 1.6 + k * 3.0
		if k >= 1.0:
			_activate_shrine(s)
	var changed := false
	for bid in hero.buffs.keys():
		if time >= float(hero.buffs[bid]):
			hero.buffs.erase(bid)
			changed = true
	if changed:
		hero.recompute()


func _activate_shrine(s: Dictionary) -> void:
	s["used"] = true
	if s["id"] == "curse":
		_activate_curse(s)
		return
	var d: Dictionary = DB.SHRINES[s["id"]]
	hero.buffs[s["id"]] = time + DB.SHRINE_TIME
	hero.recompute()
	(s["ring"] as MeshInstance3D).queue_free()
	(s["light"] as OmniLight3D).light_energy = 0.4
	fx.ring(hero.flat_pos(), 4.0, d["color"], 0.6)
	fx.burst(hero.flat_pos(), d["color"], 24, 8.0, 1.0)
	fx.flash_light(hero.flat_pos(), d["color"], 4.0, 8.0, 0.5)
	Sfx.play("unlock_start", 0.0)
	Ui.buzz(40, 0.5)


## The cursed shrine wakes a champion pack. Outlast the curse for the prize.
func _activate_curse(s: Dictionary) -> void:
	var col: Color = DB.CURSE["color"]
	(s["ring"] as MeshInstance3D).queue_free()
	(s["light"] as OmniLight3D).light_energy = 0.4
	curse_t = DB.CURSE_TIME
	banner(str(DB.CURSE["name"]), col, "Survive %d seconds" % int(DB.CURSE_TIME))
	fx.ring(hero.flat_pos(), 5.0, col, 0.6)
	fx.burst(hero.flat_pos(), col, 28, 9.0, 1.0)
	fx.flash_light(hero.flat_pos(), col, 5.0, 9.0, 0.6)
	Sfx.play("boom", -2.0, 0.7)
	Ui.buzz(70, 0.7)
	shake(0.35)
	var n := 2 + int(ai())
	for i in n:
		var a := TAU * i / n
		var at := arena.resolve(hero.position + Actor.dir_of(a) * 7.0, 0.8)
		spawn_foe(["warrior", "minion", "rogue"][randi() % 3], at, true)


func _tick_curse(dt: float) -> void:
	if curse_t <= 0.0:
		return
	curse_t -= dt
	if curse_t > 0.0 or not hero.alive:
		return
	banner("The curse lifts", Color(0.85, 0.5, 1.0), "Take your due")
	Sfx.play("rare_chime", -2.0)
	_drop_item(hero.flat_pos(), _roll_good("elite", 2))
	run_level += 1
	pending_levels += 1
	if pending_levels == 1:
		_offer_cards()


# --- Surges, hazards and the ritual -------------------------------------------

## "The graves open!": a ring of the dead climbs out around the hero over two
## seconds, then the hunt breathes for eight.
func _start_surge(p: float) -> void:
	banner("The graves open!", Color(0.7, 0.95, 0.6), "Hold your ground")
	shake(0.3)
	Sfx.play("boom", -4.0, 0.7)
	var count := randi_range(10, 14) + int(ai() * 2.0)
	for i in count:
		var dir := Actor.dir_of(TAU * i / count + randf() * 0.2)
		var at := arena.resolve(hero.position + dir * randf_range(8.0, 10.0), 0.6)
		surge_queue.append({"t": 0.14 * i, "kind": _pick_kind(p), "pos": at})
	calm_t = 10.0


func _tick_surge(dt: float) -> void:
	var i := surge_queue.size() - 1
	while i >= 0:
		var q: Dictionary = surge_queue[i]
		q["t"] -= dt
		if q["t"] <= 0.0:
			if foes.size() < MAX_FOES:
				spawn_foe(q["kind"], q["pos"])
			surge_queue.remove_at(i)
		i -= 1


## Grave eruptions: telegraphed bursts under and around the hero. Whoever
## stands still is always hit; the cluster grows and quickens with the tier.
func _tick_hazards(dt: float) -> void:
	if _warming or not hero.alive or not (phase == "rise" or phase == "boss"):
		return
	if phase == "boss" and ai() < 1.0:
		return
	if mode == "trial" and not _room_active():
		return
	_erupt_t -= dt * (0.6 if phase == "boss" else 1.0)
	if _erupt_t > 0.0:
		return
	var e: Dictionary = DB.ERUPTION
	_erupt_t = maxf(float(e["every"]) - float(e["every_ai"]) * ai(), float(e["min"])) * randf_range(0.85, 1.15)
	var n := int(float(e["count"]) + float(e["count_ai"]) * ai())
	var lead := hero.vel * 0.35 * minf(ai(), 1.0)
	for i in n:
		var at := hero.flat_pos() + lead
		if i > 0:
			at = hero.flat_pos() + Actor.dir_of(randf() * TAU) * randf_range(2.2, 5.0)
		blast_at(arena.resolve(at, 0.4), float(e["radius"]), float(e["delay"]) + 0.1 * i, float(e["dmg"]) * float(tier["dmg"]), "", Color(0.85, 0.8, 0.6), float(e["mech"]))
	Sfx.play("quake", -12.0, 1.4)
	tip("eruption", "The ground bursts where you stand: keep moving", "explosion-rays")


## The ritual: Grave Callers chant around a sigil on the ground. Kill them
## before the chant ends.
func _start_ritual() -> void:
	ritual_done = true
	var rd: Dictionary = DB.RITUAL
	ritual_at = arena.spawn_point(hero.position, 9.0, 13.0)
	ritual_t = float(rd["time"])
	_ritual_tele = fx.telegraph(0, ritual_at, 0.0, Vector2(2.8, 0), ritual_t)
	var n := int(rd["callers"])
	for i in n:
		var at := arena.resolve(ritual_at + Actor.dir_of(TAU * i / n) * 2.6, 0.6)
		var e := spawn_foe("necro", at)
		e.channel = true
		e.max_hp *= 3.0
		e.hp = e.max_hp
		ritual_callers.append(e)
	banner("A ritual begins", Color(0.8, 0.45, 1.0), "Slay the %d Grave Callers in %d seconds" % [n, int(rd["time"])])
	tip("ritual", "Break the ritual for a prize, or face what it calls", "magic-swirl")
	Sfx.play("roar", -4.0, 0.7)


func _tick_ritual(dt: float) -> void:
	if ritual_t <= 0.0:
		return
	ritual_t -= dt
	var left: Array = ritual_callers.filter(func(c): return is_instance_valid(c) and c.alive)
	if left.size() < ritual_callers.size():
		hud.event("Caller slain · %d left" % left.size(), Color(0.8, 0.5, 1.0), "skull-crossed-bones")
		ritual_callers = left
	if fmod(ritual_t, 0.5) < dt:
		for c in left:
			fx.lightning(PackedVector3Array([(c as Enemy).position + Vector3(0, 1.6, 0), ritual_at + Vector3(0, 0.3, 0)]), Color(0.75, 0.4, 1.0))
	if left.is_empty():
		ritual_t = 0.0
		if _ritual_tele:
			fx.cancel(_ritual_tele)
		banner("The ritual is broken", Color(0.75, 1.0, 0.7), "Take your due")
		Sfx.play("rare_chime", -2.0)
		_drop_item(ritual_at, _roll_good("elite", 2))
		for i in 8:
			_drop("soul", ritual_at, 3)
		for i in 8:
			_drop("gold", ritual_at, randi_range(2, 5))
		return
	if ritual_t <= 0.0:
		for c in left:
			(c as Enemy).channel = false
		ritual_callers.clear()
		foe_speed_mult *= 1.0 + float(DB.RITUAL["fail_speed"])
		var e := spawn_foe("brute", ritual_at, true)
		banner("The ritual is complete", Color(1.0, 0.35, 0.3), "%s climbs out. The dead quicken." % e.elite_name)
		shake(0.5)
		Sfx.play("boss_roar", -4.0, 1.3)
