class_name Hunt
extends "res://src/hunt/hunt_modes.gd"

const Online := preload("res://src/net/online.gd")
const Partner := preload("res://src/hunt/partner.gd")
## One hunt in the Barrow: the dead rise, the soul meter fills, the King
## wakes, and the hunt ends in victory or death. Owns every actor and runs
## the rules; the HUD only reads from here and sends input back.
##
## Split by subject into a chain of scripts, each extending the one before
## (a part only calls parts below it): hunt_state < hunt_loot < hunt_combat
## < hunt_events < hunt_modes < hunt (setup, the frame tick, the director).


# --- Setup and the frame ------------------------------------------------------

## Party partners join a party hunt (see src/net/party_link.gd).
func _spawn_partners() -> void:
	if bot or Online.inst == null or not Online.inst.party.in_hunt:
		return
	var link = Online.inst.party
	var side := 1.0
	for uid in link.mates():
		var p := Partner.new()
		world.add_child(p)
		p.position = arena.resolve(hero.position + Vector3(2.0 * side, 0, -1.0), 0.5)
		p.setup_partner(self, uid, link.members[uid], link.moves)
		partners.append(p)
		side = -side


func _ready() -> void:
	zone_id = Game.zone_id()
	zone = DB.zone(zone_id)
	loot_bonus = int(zone.get("loot_bonus", 0))
	mode = Game.mode_id()
	tier_i = Game.tier()
	tier = DB.TIERS[tier_i]
	rerolls_left = 2 if ai() >= 2.0 else 1
	hero_id = Game.hero_id()
	souls_goal = int(tier["souls"])
	if mode == "trial":
		trial_rooms = int(DB.MODES["trial"]["rooms"][tier_i])
		trial_seed = Game.rng.randi()
		souls_goal = 100
		loot_bonus += 1
	if mode == "rift":
		# A rift key opens one empowered boss with a guaranteed unique.
		Game.data["rift_keys"] = maxi(int(Game.data.get("rift_keys", 0)) - 1, 0)
		Game.save()
		rift_boss = "gravemaw" if randf() < 0.5 else "hexer"
	if mode == "descent" or _rushlike() or mode == "wild":
		elite_marks.clear()
		surge_marks.clear()
		rush_wait = 3.0
	if mode == "wild":
		souls_goal = 99999
		elite_marks = [0.45, 0.8]
	elif mode == "horde" and ai() >= 2.0:
		# Nightmare and up: a second wave of champions.
		elite_marks = [0.22, 0.42, 0.58, 0.72, 0.86]
	cur_boss = str(zone["boss"])
	omen = Game.active_omen(mode)
	if not omen.is_empty():
		foe_speed_mult *= 1.0 + float(omen["mod"].get("foe_speed", 0.0))
	robber_wanted = randf() < 0.35 and mode == "horde"
	ritual_done = not (mode == "horde" and randf() < float(DB.RITUAL["chance"]))
	_erupt_t = 14.0 if ai() <= 0.0 else 7.0
	low = str(Game.setting("quality")) == "low" or OS.has_feature("mobile") and str(Game.setting("quality")) == "auto" and _weak_device()
	bot = OS.get_cmdline_user_args().has("--bot")
	world = Node3D.new()
	world.name = "World"
	add_child(world)
	arena = Arena.new()
	world.add_child(arena)
	arena.build(low, zone_id, trial_rooms, trial_seed)
	fx = Fx.new()
	fx.quality_low = low
	world.add_child(fx)
	# Big hits kick the camera and freeze a beat (rate limited in the lib).
	fx.vfx.on_shake = shake
	fx.vfx.on_freeze = hitstop
	hero = Hero.new()
	world.add_child(hero)
	hero.position = arena.start
	arena.follow = hero
	hero.rotation.y = PI
	var stats := Game.hero_stats(hero_id)
	for c in stats["cards"]:
		cards[c] = int(cards.get(c, 0)) + 1
	hero.setup(self, hero_id, stats)
	cam = HuntCam.new()
	world.add_child(cam)
	cam.target = hero
	cam.shake_enabled = bool(Game.setting("shake"))
	cam.dist_mult = {"close": 0.86, "wide": 1.16}.get(str(Game.setting("camera")), 1.0)
	cam.snap()
	cam.current = true
	# Sidekicks replaced the hero ally and the cosmetic pet.
	_spawn_sidekick()
	_spawn_partners()
	_setup_shrines()
	hud = HUD_SCENE.instantiate()
	add_child(hud)
	hud.setup(self)
	hud.dash_pressed.connect(func(): hero.try_dash())
	hud.super_pressed.connect(func(): hero.try_super())
	hud.card_picked.connect(pick_card)
	hud.results_closed.connect(func(again: bool):
		result["again"] = again
		finished.emit(result))
	hud.abandon_pressed.connect(_abandon)
	for s in DB.SKILLS:
		_skill_base[s] = Game.skill_xp(s, hero_id)
		_skill_shown[s] = DB.level_for_xp(_skill_base[s])
	if bot:
		_bot = HuntBot.new()
		_bot.hunt = self
	if not bot:
		await _warmup()
	Sfx.music(music_track())
	Sfx.play("hunt_start", -2.0)
	if mode == "rift":
		hud.banner("A rift opens", Color(0.6, 0.85, 1.0), "%s · %s waits beyond, twice as strong. A unique is yours if you win." % [tier["name"], DB.boss_def(rift_boss)["name"]])
	elif mode == "descent" or _rushlike():
		hud.banner(str(DB.MODES[mode]["name"]), Color(0.85, 0.8, 0.7), "%s · %s" % [tier["name"], "Survive as deep as you can" if mode == "descent" else "%d bosses, no rest" % rush_order().size()])
	elif mode == "trial":
		hud.banner(str(DB.MODES["trial"]["name"]), Color(0.85, 0.8, 0.7), "%s · %d rooms to the %s" % [tier["name"], trial_rooms, DB.boss_def(cur_boss)["name"]])
	else:
		hud.banner(str(zone["name"]), Color(0.85, 0.8, 0.7), "%s · %s" % [tier["name"], str(zone["wake"]) % souls_goal])


## On a phone the first draw of every material, particle and effect compiles a
## shader pipeline and hitches the frame. Draw one of everything behind a black
## curtain before the hunt begins, so the hitches happen where nobody sees them.
func _warmup() -> void:
	_warming = true
	var layer := CanvasLayer.new()
	layer.layer = 40
	add_child(layer)
	var curtain := ColorRect.new()
	curtain.color = Color(0.01, 0.01, 0.02, 1.0)
	curtain.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	curtain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The level-up cards use shadowed styleboxes and big icons: draw them once
	# here so the first real level-up does not stall on a shader compile.
	var lu := preload("res://src/ui/levelup.tscn").instantiate()
	layer.add_child(lu)
	lu.open(self, ["might", "crit", "blades", "bladestorm"], 1)
	layer.add_child(curtain)
	var at := hero.flat_pos() + Vector3(0, 0, -3.0)
	var flat := Vector3.UP
	for deg in [60, 120, 180, 360]:
		fx.slash(at, 0.0, 2.0, deg, Color.WHITE)
	fx.vfx.warmup(at)
	for shape in 3:
		fx.telegraph(shape, at, 0.0, Vector2(2.0, 5.0), 0.4)
	var beam := fx.beam(at, Color.WHITE, 3.0)
	fx.number(at, 1, Color.WHITE)
	fx.text(at, "x", Color.WHITE)
	fx.burst(at, Color.WHITE, 4)
	fx.puff(at, Color(1, 1, 1, 0.3), 2)
	fx.bone_burst(at, 2)
	fx.embers_at(at, Color.ORANGE, 2)
	fx.flare(at, Color.WHITE)
	fx.lightning(PackedVector3Array([at + flat, at + flat + Vector3(2, 0, 0)]), Color(0.6, 0.8, 1.0), &"skill")
	for kind in ["arrow", "bolt", "fireball", "spear", "wave", "orb", "axe"]:
		spawn_proj(kind, at, Vector3.ZERO, 0.0, 1, hero, {"life": 0.04})
	var temp: Array[Enemy] = []
	var x := -3.0
	for kind in DB.enemy_kinds():
		temp.append(spawn_foe(kind, at + Vector3(x, 0, -2.0)))
		x += 1.5
	temp.append(spawn_foe("minion", at + Vector3(0, 0, -4.0), true))
	var b := _make_boss()
	world.add_child(b)
	b.position = at + Vector3(0, 0, -7.0)
	b.setup(self, tier)
	_drop("soul", at, 1)
	_drop("gold", at, 1)
	_drop("heart", at, 1)
	_drop_item(at, Game.roll_item("chest", 0))
	for i in 3:
		await get_tree().process_frame
	lu.queue_free()
	for e in temp:
		foes.erase(e)
		e.queue_free()
	for o in arena.occluders.duplicate():
		if o.get("node") == b:
			arena.occluders.erase(o)
	b.queue_free()
	fx.release_beam(beam)
	for pk in pickups:
		if is_instance_valid(pk):
			if pk.beam:
				fx.release_beam(pk.beam)
			pk.queue_free()
	pickups.clear()
	await get_tree().process_frame
	time = 0.0
	phase_t = 0.0
	_warming = false
	var t := create_tween()
	t.tween_property(curtain, "color:a", 0.0, 0.35)
	t.tween_callback(layer.queue_free)


func _process(delta: float) -> void:
	if _real_hitstop > 0.0:
		_real_hitstop -= delta / maxf(Engine.time_scale, 0.01)
		if _real_hitstop <= 0.0 and phase != "victory_slow":
			Engine.time_scale = 1.0
	var dt := minf(delta, 1.0 / 30.0)
	tick(dt)


func tick(dt: float) -> void:
	time += dt
	phase_t += dt
	# Input.
	var mv := Vector2.ZERO
	if bot and _bot:
		mv = _bot.steer(dt)
	else:
		mv = hud.move_vector()
		var k := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		if k.length() > 0.1:
			mv = k
		if Input.is_action_just_pressed("dash"):
			hero.try_dash()
		if Input.is_action_just_pressed("super"):
			hero.try_super()
	if phase == "boss_intro" or phase == "defeat":
		mv = Vector2.ZERO
	hero.move_input = mv
	hero.tick(dt)
	_tick_shrines(dt)
	_tick_curse(dt)
	_tick_hazards(dt)
	_tick_ritual(dt)
	_tick_foes(dt)
	if boss:
		boss.tick(dt)
		if boss.alive:
			_separate_from(boss)
	_tick_projs(dt)
	_tick_pickups(dt)
	_tick_patches(dt)
	_tick_pyres(dt)
	if sidekick:
		sidekick.tick(dt)
	if phase != "defeat":
		for p in partners:
			p.tick(dt)
	match phase:
		"rise":
			_direct(dt)
		"boss_intro":
			if phase_t > 2.6:
				phase = "boss"
				hud.boss_mode(boss)
		"victory":
			# After the fountain settles the loot flies to the hero.
			if phase_t > 1.6:
				for pk in pickups:
					if is_instance_valid(pk) and pk.settle <= 0.0:
						pk.pulled = true
			if phase_t > 7.0 or (phase_t > 3.0 and _loot_left() == 0):
				_end(true)
	if pending_levels > 0 and cards_blocked():
		drop_bank()
	if streak > 0:
		streak_t -= dt
		if streak_t <= 0.0:
			streak = 0
	_frame_camera()
	cam.follow(dt, hero.vel)
	var watch := [hero.position]
	if boss and boss.alive:
		watch.append(boss.position)
	arena.update_occlusion(watch, cam.pitch_deg, dt)
	_skill_t -= dt
	if _skill_t <= 0.0:
		_skill_t = 0.4
		_check_skill_levels()
	hud.refresh(dt)


## Sets the camera's zoom and focus for the moment: wider for the boss and
## big crowds, tight on the loot fountain after a win.
func _frame_camera() -> void:
	match phase:
		"boss_intro":
			cam.zoom_target = 1.25
		"boss":
			cam.zoom_target = 1.18
			if boss and boss.alive:
				cam.focus_override = hero.position.lerp(boss.position, 0.25)
			else:
				cam.focus_override = null
		"victory":
			# First the fall, close on the boss, then back to the hero and the loot.
			if phase_t < 0.6 and boss:
				cam.zoom_target = 0.75
				cam.focus_override = boss.position
			else:
				cam.zoom_target = 0.85
				cam.focus_override = null
		_:
			cam.zoom_target = 1.0 + clampf((foes.size() - 15) / 60.0, 0.0, 0.12)
			# Back to the hero: a boss that fell mid-run (Descent, Boss Rush)
			# would otherwise leave the camera pinned where the fight was.
			cam.focus_override = null


# --- Foes ----------------------------------------------------------------

func _tick_foes(dt: float) -> void:
	arena.update_flow(hero.position, dt)
	var i := foes.size() - 1
	while i >= 0:
		# A foe's tick can remove others (a bomber's blast, a robber escaping).
		if i >= foes.size():
			i = foes.size() - 1
			continue
		var f := foes[i]
		if not is_instance_valid(f):
			foes.remove_at(i)
		else:
			f.tick(dt)
		i -= 1
	# The fallen lie a while and sink; the oldest go first past the cap.
	var extra := corpses.size() - DB.CORPSE_MAX
	var j := corpses.size() - 1
	while j >= 0:
		var c := corpses[j]
		if not is_instance_valid(c):
			corpses.remove_at(j)
		else:
			if j < extra:
				c.linger = minf(c.linger, 0.0)
			c.tick(dt)
		j -= 1
	# Separation: the dead push each other apart and off the hero.
	var n := foes.size()
	for a in n:
		var fa := foes[a]
		if not fa.alive:
			continue
		for b in range(a + 1, n):
			var fb := foes[b]
			if not fb.alive:
				continue
			var d := fb.position - fa.position
			d.y = 0.0
			var rr := fa.radius + fb.radius
			var l2 := d.length_squared()
			if l2 < rr * rr and l2 > 0.0001:
				var l := sqrt(l2)
				var push := (rr - l) * 0.5
				var dir := d / l
				var wa := fb.mass / (fa.mass + fb.mass)
				fa.position -= dir * push * wa * 2.0
				fb.position += dir * push * (1.0 - wa) * 2.0
		_separate_from_hero(fa)
		fa.position = arena.resolve(fa.position, fa.radius)


func _separate_from_hero(f: Actor) -> void:
	if not hero.alive or hero.dash_t > 0.0:
		return
	var d := f.position - hero.position
	d.y = 0.0
	var rr := f.radius + hero.radius
	var l := d.length()
	if l < rr and l > 0.001:
		f.position += d / l * (rr - l)


func _separate_from(b: Actor) -> void:
	_separate_from_hero(b)
	for f in foes:
		if not f.alive:
			continue
		var d := f.position - b.position
		d.y = 0.0
		var rr := f.radius + b.radius
		var l := d.length()
		if l < rr and l > 0.001:
			f.position += d / l * (rr - l)


func _direct(dt: float) -> void:
	if _warming:
		return
	if mode == "trial":
		_direct_trial(dt)
		return
	if _rushlike():
		_direct_rush(dt)
		return
	if mode == "descent":
		_tick_depth(dt)
	if mode == "wild":
		_tick_wild(dt)
	var p := progress()
	var target := int((lerpf(7.0, 30.0, p) + ai() * 3.0) * float(tier.get("press", 1.0)))
	if mode == "wild":
		target = int(target * DB.WILD_PVE)
	target = mini(int(target * (1.0 + pact_sum("pack"))), MAX_FOES)
	if mode == "horde" and not pact_offered and p >= 0.5:
		offer_pact()
	calm_t -= dt
	if calm_t > 0.0:
		target = int(target * 0.6)
	if not surge_marks.is_empty() and p >= surge_marks[0]:
		surge_marks.pop_front()
		_start_surge(p)
	_tick_surge(dt)
	spawn_t -= dt
	if spawn_t <= 0.0 and foes.size() < target:
		spawn_t = lerpf(1.7, 0.75, p) * (2.0 if calm_t > 0.0 else 1.0) / float(tier.get("press", 1.0))
		var pack := randi_range(2, 3 + int(p * 4.0))
		var center := arena.spawn_point(hero.position, 8.5, 14.0)
		# Running in a straight line has a price: sometimes the pack is waiting ahead.
		if hero.vel.length() > 2.5 and (ai() >= 0.5 or p > 0.35) and randf() < (0.5 if hero.hp > hero.max_hp * 0.3 else 0.15):
			var ahead := arena.spawn_point(hero.position + hero.vel.normalized() * 7.0, 2.5, 6.0)
			if ahead.distance_to(hero.position) > 6.0:
				center = ahead
		for i in pack:
			var at := arena.resolve(center + Vector3(randf_range(-1.6, 1.6), 0, randf_range(-1.6, 1.6)), 0.5)
			var kind := _pick_kind(p)
			spawn_foe(kind, at)
			# On Nightmare and up the hounds hunt in pairs.
			if kind == "hound" and ai() >= 2.0:
				spawn_foe("hound", arena.resolve(at + Vector3(1.0, 0, 0), 0.5))
		Sfx.play("aggro", -14.0)
	if time > 8.0 and hero.def["style"] != "melee":
		tip("steady", "Plant your feet: standing still aims truer (+25% damage)", "bullseye")
	if not ritual_done and p >= float(DB.RITUAL["at"]):
		_start_ritual()
	if robber_wanted and not robber_spawned and p >= 0.4:
		robber_spawned = true
		spawn_foe("robber", arena.spawn_point(hero.position, 9.0, 12.0))
		banner("A Grave Robber!", Color(1.0, 0.85, 0.35), "Catch him before he gets away")
		Sfx.play("roar", -2.0, 1.6)
	if not elite_marks.is_empty() and p >= elite_marks[0]:
		var mark: float = elite_marks.pop_front()
		var kinds := ["warrior", "minion", "rogue", "mage"] if p > 0.5 else ["warrior", "minion"]
		# The middle mark of a horde hunt is a mini-boss: a champion Bone Brute.
		var mini_boss := mode == "horde" and absf(mark - 0.58) < 0.01
		if mini_boss:
			kinds = ["brute"]
		var at2 := arena.spawn_point(hero.position, 7.0, 11.0)
		var e := spawn_foe(kinds[randi() % kinds.size()], at2, true)
		banner(e.elite_name, DB.ELITE_AFFIXES[e.affixes[0]]["color"].lightened(0.3), "A brute of the barrow, crowned in bone" if mini_boss else "A champion rises!")
		Sfx.play("roar", -4.0, 1.1)
		tip("champion", "Champions carry curses and drop better loot", "crowned-skull")
	if souls >= souls_goal:
		_begin_boss()
