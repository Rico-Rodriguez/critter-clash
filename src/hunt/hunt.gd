class_name Hunt
extends Node3D
## One hunt in the Barrow: the dead rise, the soul meter fills, the King
## wakes, and the hunt ends in victory or death. Owns every actor and runs
## the rules; the HUD only reads from here and sends input back.

signal finished(result: Dictionary)

const HUD_SCENE := preload("res://src/ui/hud.tscn")
const MAX_FOES := 44

var tier_i := 0
var zone_id := "barrow"
## "horde" (fill the soul meter) or "trial" (the Long Road, room by room).
var mode := "horde"
var trial_rooms := 0
var trial_seed := 1
var _spawn_q: Array = []
## Tiers added to the metal of everything that drops (deeper zones, trial depth).
var loot_bonus := 0
var zone: Dictionary
var rerolls_left := 1
var tier: Dictionary
var hero_id := "knight"
var arena: Arena
var fx: Fx
var cam: HuntCam
var hud: Hud
var world: Node3D
var hero: Hero
var boss: Boss
var pet: Actor
var ally: Ally
var foes: Array[Enemy] = []
var projs: Array[Proj] = []
var pickups: Array[Pickup] = []
var cards := {}
var time := 0.0
var phase := "rise"
var phase_t := 0.0
var souls := 0
var souls_goal := 110
var run_level := 1
var run_xp := 0
var kills := 0
var elites_killed := 0
var gold := 0
var items: Array = []
var uniques: Array = []
var dmg_dealt := 0.0
var foe_speed_mult := 1.0
var spawn_t := 1.5
var elite_marks := [0.28, 0.58, 0.86]
var pending_levels := 0
var bot := false
var low := false
var result := {}
var _proj_pool := {}
var _real_hitstop := 0.0
var _skill_base := {}
var _skill_shown := {}
var _skill_t := 0.0
var _bot: HuntBot
var _ended := false
var _warming := false
var patches: Array = []
var shrines: Array = []
## The first surge comes early so a new player meets the horde in the first minute.
var surge_marks := [0.15, 0.45, 0.75]
var surge_queue: Array = []
var calm_t := 0.0
var _storming := false
var robber_wanted := false
var robber_spawned := false
## Pacts taken this hunt (see DB.PACTS), and whether the mid-hunt offer is spent.
var pacts: Array[String] = []
## The weekly omen this hunt carries ({} when off), see DB.WEEKLY_OMENS.
var omen := {}
var dashes := 0
var boss_time := 9999.0
var pact_offered := false
var curse_t := 0.0
## The Wilderness: the ring's radius now, its mesh, the rival count.
var ring_r := 34.0
var ring_mesh: MeshInstance3D
var rivals_total := 0
var rivals_spawned := false
var _ring_hurt_t := 0.0
var _ring_stage := 0
var depth := 1
var depth_t := 0.0
## Boss Rush: which boss is next, and the breather before it.
var rush_i := 0
var rush_wait := 0.0
var cur_boss := ""
var cur_boss_power := 1.0
var streak := 0
var perfect_dodges := 0
var banished: Array[String] = []
## Bosses killed this hunt (kill counts and dry streaks), and the rift's boss.
var bosses_killed: Array[String] = []
var rift_boss := ""
var banishes_left := DB.BANISHES
## Burning ground from Pyre: {pos, r, t, dps, tick}.
var pyres: Array = []
var _erupt_t := 6.0
## The ritual event: its callers, the sigil's center, seconds left (0 = none).
var ritual_callers: Array = []
var ritual_at := Vector3.ZERO
var ritual_t := 0.0
var ritual_done := false
var _ritual_tele: MeshInstance3D
var _xp_frac := 0.0
var streak_t := 0.0


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
	if str(Game.data.get("pet", "")) != "":
		_spawn_pet()
	var aid := str(Game.data.get("ally", ""))
	if aid != "" and aid != hero_id and DB.HEROES.has(aid) and Game.hero(aid)["unlocked"]:
		ally = Ally.new()
		world.add_child(ally)
		ally.position = arena.resolve(hero.position + Vector3(2.0, 0, 1.0), 0.5)
		ally.setup(self, aid)
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
		_skill_base[s] = int(Game.data["skills"][s])
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
	fx.ring(at, 2.0, Color.WHITE, 0.3)
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
	fx.flash_light(at, Color.WHITE, 0.1, 3.0, 0.1)
	fx.lightning(PackedVector3Array([at + flat, at + flat + Vector3(2, 0, 0)]))
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


func _weak_device() -> bool:
	var name_ := RenderingServer.get_video_adapter_name().to_lower()
	return name_.contains("mali-g5") or name_.contains("adreno (tm) 5") or name_.contains("powervr")


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
	if pet:
		_tick_pet(dt)
	if ally and phase != "defeat":
		ally.tick(dt)
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


# --- Foes ----------------------------------------------------------------

func _tick_foes(dt: float) -> void:
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


func nearest_foe(from: Vector3, max_d: float) -> Actor:
	var best: Actor = null
	var bd := max_d
	for f in foes:
		if not f.alive or f.state == "spawn":
			continue
		var d := Vector2(f.position.x - from.x, f.position.z - from.z).length() - f.radius
		if d < bd:
			bd = d
			best = f
	if boss and boss.alive and boss.state != "intro":
		var db := Vector2(boss.position.x - from.x, boss.position.z - from.z).length() - boss.radius
		if db < bd:
			best = boss
	return best


## Live foes (and the boss) whose center is within `r` of `p`.
func foes_near(p: Vector3, r: float) -> Array:
	var out := []
	var r2 := r * r
	for f in foes:
		if not f.alive or f.state == "spawn":
			continue
		var dx := f.position.x - p.x
		var dz := f.position.z - p.z
		if dx * dx + dz * dz <= r2:
			out.append(f)
	if boss and boss.alive and boss.state != "intro":
		var dx2 := boss.position.x - p.x
		var dz2 := boss.position.z - p.z
		if sqrt(dx2 * dx2 + dz2 * dz2) <= r + boss.radius:
			out.append(boss)
	return out


func on_screen(p: Vector3, margin := 0.0) -> bool:
	var vp := get_viewport().get_visible_rect()
	if cam.is_position_behind(p):
		return false
	var s := cam.unproject_position(p + Vector3(0, 1, 0))
	return s.x > -margin * 40.0 and s.x < vp.size.x + margin * 40.0 and s.y > 80.0 and s.y < vp.size.y - 40.0


## A telegraphed blast on the ground: after `delay` it hurts the hero if they
## are still inside, and may slow or root them.
func blast_at(pos: Vector3, r: float, delay: float, amount: float, effect: String, col: Color, mech := 0.5) -> void:
	fx.telegraph(0, pos, 0.0, Vector2(r, 0), delay)
	get_tree().create_timer(delay, false).timeout.connect(func():
		if _ended or not is_instance_valid(hero):
			return
		fx.ring(pos, r, col, 0.35)
		fx.burst(pos, col, 14, 7.0)
		Sfx.play("boom", -10.0, 1.3)
		if hero.alive and hero.flat_pos().distance_to(pos) < r + hero.radius * 0.5:
			damage_hero(amount, null, mech)
			if effect == "slow":
				hero.slow_t = 2.5
			elif effect == "root":
				hero.root_t = 1.2)


## A lane across the ground from `from` along `yaw`: it flashes, then cuts.
func beam_from(from: Vector3, yaw: float, delay: float, amount: float, col: Color, mech := 0.6) -> void:
	fx.telegraph(2, from, yaw, Vector2(0.9, 14.0), delay)
	get_tree().create_timer(delay, false).timeout.connect(func():
		if _ended or not is_instance_valid(hero):
			return
		var fwd := Vector3(sin(yaw), 0, cos(yaw))
		var rel := hero.flat_pos() - from
		var along := rel.dot(fwd)
		var across := (rel - fwd * along).length()
		fx.ring(from + fwd * 6.0, 1.2, col, 0.3)
		if hero.alive and along > 0.0 and along < 14.0 and across < 0.9 + hero.radius * 0.5:
			damage_hero(amount, null, mech))


## A burning patch of ground left by a molten champion. It telegraphs red; the
## hero takes `dps` a second while standing in it.
func add_fire_patch(at: Vector3, r: float, dur: float, dps: float) -> void:
	patches.append({"pos": at, "r": r, "t": dur, "dps": dps, "tick": 0.5, "node": fx.telegraph(0, at, 0.0, Vector2(r, 0), dur)})


## Pyre: burning ground that hurts the dead standing in it.
func add_pyre(at: Vector3, r: float, dur: float, dps: float) -> void:
	pyres.append({"pos": at, "r": r, "t": dur, "dps": dps, "tick": 0.0})
	fx.embers_at(at, Color(1.0, 0.45, 0.1), 8, r * 0.7)


func _tick_pyres(dt: float) -> void:
	var i := pyres.size() - 1
	while i >= 0:
		var pr: Dictionary = pyres[i]
		pr["t"] -= dt
		pr["tick"] -= dt
		if pr["tick"] <= 0.0:
			pr["tick"] = 0.5
			fx.embers_at(pr["pos"], Color(1.0, 0.45, 0.1), 3, float(pr["r"]) * 0.7)
			for f in foes_near(pr["pos"], float(pr["r"])):
				damage_foe(f, float(pr["dps"]) * 0.5, hero, Vector3.ZERO, 0.0)
		if pr["t"] <= 0.0:
			pyres.remove_at(i)
		i -= 1


func _tick_patches(dt: float) -> void:
	var i := patches.size() - 1
	while i >= 0:
		var pt: Dictionary = patches[i]
		pt["t"] -= dt
		pt["tick"] -= dt
		if pt["tick"] <= 0.0:
			pt["tick"] = 0.5
			var d: float = hero.flat_pos().distance_to(pt["pos"])
			if hero.alive and d < float(pt["r"]) + hero.radius * 0.5:
				damage_hero(float(pt["dps"]) * 0.5, null, 0.06)
		if pt["t"] <= 0.0:
			patches.remove_at(i)
		i -= 1


## How far along the hunt is, 0 to 1: it paces what spawns and how tough foes
## are. In the Descent it follows the depth; the soul bar shows `objective_fill`.
func progress() -> float:
	if mode == "descent":
		return clampf(0.12 + (depth - 1) * 0.07, 0.0, 1.0)
	if _rushlike():
		return 0.5
	if mode == "wild":
		return clampf(time / 240.0, 0.05, 1.0)
	return clampf(float(souls) / float(souls_goal), 0.0, 1.0)


## What the top bar shows.
func objective_fill() -> float:
	if mode == "descent":
		return clampf(depth_t / DB.DESCENT_TIME, 0.0, 1.0)
	if _rushlike():
		return float(rush_i) / rush_order().size()
	if mode == "wild":
		return float(rivals_alive()) / float(maxi(rivals_total, 1))
	return progress()


func spawn_foe(kind: String, at: Vector3, elite := false, affix := "") -> Enemy:
	# A zone's own faction stands in for the skeletons of the same role.
	kind = str(zone.get("faction", {}).get(kind, kind))
	var e := Enemy.new()
	world.add_child(e)
	e.position = at
	e.rotation.y = Actor.yaw_to(at, hero.position)
	e.setup(self, kind, scaled_tier(), elite, affix)
	foes.append(e)
	fx.puff(at, Color(0.28, 0.23, 0.18, 0.75), 7, 0.7, 1.6)
	if on_screen(at):
		fx.bone_burst(at, 2, 3.0)
	return e


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


func _room_active() -> bool:
	for r: Dictionary in arena.trial.get("rooms", []):
		if str(r["state"]) == "active":
			return true
	return false


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


func brute_count() -> int:
	var n := 0
	for f in foes:
		if f.alive and f.kind == "brute":
			n += 1
	return n


func necro_count() -> int:
	var n := 0
	for f in foes:
		if f.alive and f.kind == "necro":
			n += 1
	return n


func _pick_kind(p: float) -> String:
	var w := {
		"minion": 1.0,
		"warrior": 0.28 if p > 0.12 else 0.0,
		"rogue": 0.3 if p > 0.22 else 0.0,
		"mage": 0.2 if p > 0.42 else 0.0,
		"hound": 0.2 if p > 0.2 else 0.0,
		"brute": 0.07 if p > 0.4 and brute_count() < 2 else 0.0,
		"bomber": 0.22 if p > 0.3 else 0.0,
		"necro": 0.12 if p > 0.55 and necro_count() < 2 else 0.0,
	}
	for k in zone["weights"]:
		w[k] = float(w[k]) * float(zone["weights"][k])
	var total := 0.0
	for k in w:
		total += w[k]
	var r := randf() * total
	for k in w:
		r -= w[k]
		if r <= 0.0:
			return k
	return "minion"


var boss_at := 0.0
var rooms_cleared := 0


# --- The Long Road --------------------------------------------------------

func objective_title() -> String:
	match mode:
		"trial":
			return "THE LONG ROAD"
		"descent":
			return "DEPTH"
		"rush":
			return "BOSS RUSH"
		"rift":
			return "THE RIFT"
		"wild":
			return "THE WILDERNESS"
	return "SOULS"


func objective_text() -> String:
	if mode == "descent":
		return "Depth %d" % depth
	if mode == "wild":
		return "%d rivals · ring %dm" % [rivals_alive(), int(ring_r)]
	if _rushlike():
		return "Boss %d / %d" % [mini(rush_i + 1, rush_order().size()), rush_order().size()]
	if mode != "trial":
		return "%d / %d" % [souls, souls_goal]
	if boss != null:
		return "The boss"
	return "Room %d / %d" % [mini(rooms_cleared + 1, trial_rooms), trial_rooms]


## Where the autopilot should walk next on the Long Road: the gap of the room
## it stands in (once clear), else the middle of the room.
func trial_goal() -> Vector3:
	var rooms: Array = arena.trial["rooms"]
	var i := arena.room_at(hero.position.z)
	if i < 0 or i >= rooms.size():
		return Vector3(0, 0, arena.boss_spawn.z + 10.0)
	var r: Dictionary = rooms[i]
	return Vector3(float(r["gap_x"]), 0, float(r["lo"]) - 4.0)


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


func _room_alive(r: Dictionary) -> int:
	var n := 0
	for f in r["foes"]:
		if is_instance_valid(f) and f.alive:
			n += 1
	return n


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
	Sfx.play("rare_chime", -2.0)
	var kind := str(r["kind"])
	for i in randi_range(4, 7):
		_drop("gold", at, randi_range(2, 5) * int(tier["gold"]))
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
		Sfx.play("chest", -2.0)
		for i in 2:
			_drop_item(cp, _roll_good("chest", 1))
		for i in 8:
			_drop("gold", cp, randi_range(3, 7))
	elif randf() < 0.3 + 0.2 * d:
		_drop_item(at, Game.roll_item("trash", tier_i, "", "", loot_bonus))


func _make_boss() -> Boss:
	var b: Boss = BossHexer.new() if cur_boss == "hexer" else (BossThorn.new() if cur_boss == "thorn" else Boss.new())
	b.boss_id = cur_boss
	return b


# --- The Wilderness ------------------------------------------------------

func rivals_alive() -> int:
	var n := 0
	for f in foes:
		if is_instance_valid(f) and f.alive and f.kind.begins_with("rival_"):
			n += 1
	return n


func _spawn_rivals() -> void:
	rivals_spawned = true
	rivals_total = int(DB.WILD_RIVALS[tier_i])
	var order := ["knight", "ranger", "mage", "barbarian"]
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
		_drop("gold", at, randi_range(3, 8) * int(tier["gold"]))
	for i in 2:
		_drop_item(at, Game.roll_item("boss", tier_i, "", "", loot_bonus))
	for i in 8:
		_drop("soul", at, 4)
	for f in foes.duplicate():
		if f.alive:
			_kill(f)


## A rival falls: they pay in gold and gear, and the feed counts the rest.
func _rival_down(f: Enemy) -> void:
	var at := f.flat_pos()
	for i in 6:
		_drop("gold", at, randi_range(3, 7) * int(tier["gold"]))
	if randf() < 0.55:
		_drop_item(at, _roll_good("elite", 1))
	_drop("heart", at, 1)
	Sfx.play("rare_chime", -4.0)
	hud.event("%s down · %d left" % [f.def["name"], rivals_alive()], Color(1.0, 0.6, 0.45), "crossed-swords")


# --- Endless Descent and Boss Rush ---------------------------------------

## The tier the foes of this moment are built from: the Descent makes
## everything tougher with depth, the second lap of the Rush hits harder.
func scaled_tier() -> Dictionary:
	var fh := pact_sum("foe_hp")
	var fd := pact_sum("foe_dmg")
	if fd != 0.0 and mode != "descent" and not _rushlike():
		var td := tier.duplicate()
		td["hp"] = float(tier["hp"]) * (1.0 + fh)
		td["dmg"] = float(tier["dmg"]) * (1.0 + fd)
		return td
	if mode == "descent" and depth > 1:
		var t := tier.duplicate()
		t["hp"] = float(tier["hp"]) * (1.0 + DB.DESCENT_HP * (depth - 1)) * (1.0 + fh)
		t["dmg"] = float(tier["dmg"]) * (1.0 + DB.DESCENT_DMG * (depth - 1)) * (1.0 + fd)
		return t
	if fh > 0.0 and not _rushlike():
		var tp := tier.duplicate()
		tp["hp"] = float(tier["hp"]) * (1.0 + fh)
		return tp
	if _rushlike() and cur_boss_power > 1.0:
		var t2 := tier.duplicate()
		t2["hp"] = float(tier["hp"]) * cur_boss_power
		t2["dmg"] = float(tier["dmg"]) * (1.0 + (cur_boss_power - 1.0) * 0.6)
		return t2
	return tier


## Boss Rush and the rift run the same rules: bosses in a row, no soul phase.
func _rushlike() -> bool:
	return mode == "rush" or mode == "rift"


func rush_order() -> Array:
	return [[rift_boss, DB.RIFT_POWER]] if mode == "rift" else DB.RUSH_ORDER


## The music of the moment: the Descent and rifts have their own; zones may too.
func music_track() -> String:
	if mode == "descent":
		return "descent"
	if mode == "rift":
		return "rift"
	return str(zone.get("music", "hunt"))


## A one-time callout the first time a player meets something (saved).
func tip(key: String, text: String, icon_name := "round-star") -> void:
	if bot or Game.data["tips"].has(key):
		return
	Game.data["tips"][key] = true
	hud.event(text, Color(1.0, 0.92, 0.6), icon_name)


## How cunning foes are on this tier: 0 Normal, 1 Veteran, 2 Nightmare, 3 Abyss.
func ai() -> float:
	return float(tier.get("ai", 0.0))


## Multiplier on passive healing (regen, leech, heal-on-hit cards).
func heal_mult() -> float:
	return float(tier.get("heal", 1.0))


## Total of one pact modifier over the pacts taken.
func pact_sum(key: String) -> float:
	var n := 0.0 if omen.is_empty() else float(omen["mod"].get(key, 0.0))
	for id in pacts:
		n += float(DB.PACTS[id]["mod"].get(key, 0.0))
	return n


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


func _direct_rush(dt: float) -> void:
	rush_wait -= dt
	if rush_wait > 0.0 or _warming or boss != null:
		return
	var entry: Array = rush_order()[rush_i]
	cur_boss = str(entry[0])
	cur_boss_power = float(entry[1])
	_begin_boss()


## A boss other than the last falls: loot, a breath, a card, the next one.
func _boss_down_midway() -> void:
	var b := boss
	b.die()
	boss = null
	phase = "rise"
	phase_t = 0.0
	hud.boss_mode(null)
	Ui.buzz(80, 0.7)
	var at := b.flat_pos()
	var col: Color = DB.boss_def(b.boss_id)["color"]
	fx.bone_burst(at, 16, 9.0)
	fx.ring(at, 8.0, Color(col).lightened(0.2), 0.9)
	fx.flash_light(at, Color(col).lightened(0.3), 9.0, 16.0, 1.2)
	shake(0.8)
	Sfx.play("boss_die", 0.0)
	banner("%s falls" % b.display_name, Color(1.0, 0.85, 0.5))
	for i in 12:
		_drop("gold", at, randi_range(3, 8) * int(tier["gold"]))
	for i in 2 if _rushlike() else 1:
		_drop_item(at, Game.roll_boss_item(b.boss_id, tier_i, loot_bonus))
	for i in 5:
		_drop("soul", at, 3)
	_discard_boss(b)
	for f in foes.duplicate():
		if f.alive:
			_kill(f)
	hero.hp = minf(hero.hp + hero.max_hp * 0.5, hero.max_hp)
	Sfx.music(music_track(), 1.0)
	if mode == "descent":
		depth_t = 0.0
		return
	rush_i += 1
	rush_wait = DB.RUSH_GAP
	var nxt: Array = rush_order()[rush_i]
	banner("Next: %s" % DB.boss_def(str(nxt[0]))["name"], Color(0.85, 0.8, 0.7), "Take a card and a breath")
	run_level += 1
	pending_levels += 1
	if pending_levels == 1:
		_offer_cards()


## The dead boss sinks away; free it and its occluder a moment later.
func _discard_boss(b: Boss) -> void:
	get_tree().create_timer(3.5, false).timeout.connect(func():
		if is_instance_valid(b):
			for o in arena.occluders.duplicate():
				if o.get("node") == b:
					arena.occluders.erase(o)
			b.queue_free())


func _begin_boss() -> void:
	boss_at = time
	phase = "boss_intro"
	phase_t = 0.0
	hero.invuln = 3.0
	# The King draws every soul to himself: the risen fall where they stand.
	for f in foes.duplicate():
		if f.alive:
			f.die()
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
	fx.ring(arena.boss_spawn, 7.0, aura, 0.8)
	fx.flash_light(arena.boss_spawn, aura, 8.0, 16.0, 1.2)
	shake(0.8)
	Sfx.music(str(zone.get("boss_music", "boss")) if mode != "rift" else "rift", 0.6)
	Sfx.play("boss_roar", 2.0)
	var bd := DB.boss_def(cur_boss)
	banner(str(bd["name"]), Color(bd["color"]).lightened(0.25), str(bd["wake"]))
	if cur_boss == "gravemaw":
		tip("exposed", "Bait his charge into a wall: a dazed king takes 50% more", "bullseye")
	else:
		tip("exposed_q", "Close in when she casts: she reels and takes 50% more", "bullseye")


# --- Damage --------------------------------------------------------------

func damage_foe(f: Actor, amount: float, src: Node3D, dir: Vector3, force: float) -> void:
	if not f.alive:
		return
	if f is Enemy and (f as Enemy).state == "spawn":
		return
	if f is Boss and (f as Boss).state == "intro":
		return
	if src == hero:
		amount *= hero.hit_mult()
	if f is Boss and (f as Boss).exposed_t > 0.0:
		amount *= 1.0 + float(DB.EXPOSED["dmg"]) + float(hero.flags.get("exposed", 0.0))
	var crit := randf() < hero.crit
	if crit:
		amount *= 2.0 + float(hero.flags.get("critdmg", 0.0))
	if hero.flags.has("execute") and f.hp <= f.max_hp * 0.3:
		amount *= 1.0 + float(hero.flags["execute"])
	if hero.flags.has("mark") and f is Enemy and (f as Enemy).elite:
		amount *= 1.0 + float(hero.flags["mark"])
	amount = roundf(amount * randf_range(0.92, 1.08))
	if f is Enemy and (f as Enemy).ward_hp > 0.0:
		var e := f as Enemy
		var soak := minf(amount, e.ward_hp)
		e.ward_hp -= soak
		amount -= soak
		if e.ward_hp <= 0.0:
			e.ward_mesh.queue_free()
			e.ward_mesh = null
			fx.burst(f.flat_pos(), Color(0.6, 0.55, 1.0), 16, 7.0)
			Sfx.play("shield_break", -4.0)
		if amount <= 0.0:
			fx.text(f.flat_pos(), "Warded", Color(0.7, 0.65, 1.0), 0.6, 0.6)
			return
	var landed := minf(amount, maxf(f.hp, 0.0))
	f.hp -= amount
	f.hit_flash()
	if f is Enemy and f.hp > 0.0:
		(f as Enemy).stagger()
		if (f as Enemy).kind == "robber":
			for i in randi_range(1, 2):
				_drop("gold", f.flat_pos(), randi_range(2, 5))
	if force > 0.0:
		f.push(dir, force)
	var big := f is Boss
	fx.number(f.flat_pos() + Vector3(0, 0.6 if big else 0.0, 0), int(amount), Color(1.0, 0.72, 0.25) if crit else Color(1, 1, 1), 1.6 if crit else 1.0, null if crit else f)
	fx.burst(f.flat_pos(), Color(1.0, 0.85, 0.6) if not crit else Color(1.0, 0.6, 0.2), 5 if not crit else 9, 6.0)
	if crit:
		Sfx.play("crit", -6.0)
		if int(cards.get("tempest", 0)) > 0 and not _storming and randf() < 0.2:
			_storming = true
			hero._storm(3, hero.dmg * 0.8)
			_storming = false
	dmg_dealt += landed
	hero.super_charge = minf(hero.super_charge + landed / (hero.dmg * 15.0) * hero.super_rate, 1.0)
	if hero.leech > 0.0 and hero.alive:
		var heal := minf(landed * hero.leech * heal_mult(), hero.leech_pool)
		hero.leech_pool -= heal
		hero.hp = minf(hero.hp + heal, hero.max_hp)
	if f.hp <= 0.0:
		if src == hero and int(cards.get("rampage", 0)) > 0:
			hero.rampage = mini(hero.rampage + 1, 15)
			hero.rampage_t = 6.0
		if f is Boss:
			if phase == "defeat":
				f.hp = 1.0
				return
			_kill_boss()
		else:
			_kill(f as Enemy)


func _kill(f: Enemy) -> void:
	f.die()
	foes.erase(f)
	kills += 1
	if hero.flags.has("bloodlust"):
		hero.rage = mini(hero.rage + 1, int(hero.flags["bloodlust"]))
		hero.rage_t = 1.5
		hero.recompute()
	streak += 1
	streak_t = DB.STREAK_WINDOW
	if streak in DB.STREAKS:
		run_xp += streak / 3
		gold += streak / 5
		hud.event("Massacre ×%d · +%d souls +%d gold" % [streak, streak / 3, streak / 5], Color(1.0, 0.45, 0.3), "skull-crossed-bones")
		Sfx.play("rare_chime", -2.0, 0.8)
		shake(0.25)
		_check_level()
	var at := f.flat_pos()
	fx.bone_burst(at, 5 if not f.elite else 12, 5.5 if not f.elite else 8.0)
	fx.puff(at, Color(0.4, 0.38, 0.35, 0.5), 3, 0.4, 1.2)
	Sfx.play("enemy_die", -5.0)
	var soul_gain: int = f.xp_value
	if phase == "rise" and mode == "horde":
		souls = mini(souls + (1 if not f.elite else 6), souls_goal)
	# Souls for XP.
	var orbs := clampi(int(ceil(soul_gain / 3.0)), 1, 8)
	for i in orbs:
		_drop("soul", at, int(ceil(float(soul_gain) / orbs)))
	if randf() < 0.22:
		for i in randi_range(1, 2):
			_drop("gold", at, randi_range(1, 3))
	if randf() < 0.012:
		_drop("heart", at, 1)
	if f.kind == "robber":
		for i in 25:
			_drop("gold", at, randi_range(3, 8))
		for i in 2:
			_drop_item(at, _roll_good("elite", 1 if i == 0 else 0))
		hitstop(0.08)
		banner("Grave Robber slain", Color(1.0, 0.85, 0.35), "His hoard spills out")
		Sfx.play("rare_chime", -2.0)
	if f.kind.begins_with("rival_"):
		_rival_down(f)
	if f.elite:
		elites_killed += 1
		hero.potion_cd -= float(DB.POTION["elite_cd"])
		hitstop(0.09)
		shake(0.5)
		# A fountain of coin every time, whatever else drops.
		for i in 16:
			_drop("gold", at, randi_range(2, 5))
		fx.flash_light(at, Color(1.0, 0.82, 0.35), 4.0, 7.0, 0.4)
		fx.burst(at + Vector3(0, 0.8, 0), Color(1.0, 0.82, 0.35), 20, 7.0, 1.8)
		Sfx.play("coin", -2.0, 0.9)
		_drop_item(at, Game.roll_item("elite", tier_i, "", "", loot_bonus))
		for u in Game.roll_uniques("elite", tier_i):
			_drop_item(at, Game.make_unique(u))
		if "molten" in f.affixes:
			fx.telegraph(0, at, 0.0, Vector2(2.6, 0), 1.0)
			get_tree().create_timer(1.0, false).timeout.connect(func():
				fx.ring(at, 2.8, Color(1.0, 0.45, 0.1), 0.4)
				fx.burst(at, Color(1.0, 0.5, 0.15), 18, 8.0)
				if hero.flat_pos().distance_to(at) < 2.6:
					damage_hero(f.dmg * 1.2, null, 0.5))
		banner("%s slain" % f.elite_name, Color(1.0, 0.85, 0.5))
		Sfx.play("rare_chime", -4.0)
	elif randf() < 0.012:
		_drop_item(at, Game.roll_item("trash", tier_i, "", "", loot_bonus))


## Rolls an item of at least rarity index `min_idx` (tries a few times).
func _roll_good(source: String, min_idx: int) -> Dictionary:
	var it := Game.roll_item(source, tier_i, "", "", loot_bonus)
	for i in 6:
		if DB.RARITIES.find(it["rarity"]) >= min_idx:
			break
		it = Game.roll_item(source, tier_i, "", "", loot_bonus)
	return it


func _kill_boss() -> void:
	boss_time = minf(boss_time, time - boss_at)
	bosses_killed.append(boss.boss_id)
	if mode == "descent" or (_rushlike() and rush_i < rush_order().size() - 1):
		_boss_down_midway()
		return
	boss.die()
	Ui.buzz(120, 0.9)
	phase = "victory"
	phase_t = 0.0
	_end_time = time
	hud.boss_mode(null)
	hud.victory_mode()
	Engine.time_scale = 0.25
	_real_hitstop = 1.4
	var at := boss.flat_pos()
	fx.bone_burst(at, 20, 10.0)
	fx.ring(at, 9.0, Color(DB.boss_def(cur_boss)["color"]).lightened(0.2), 1.0)
	fx.flash_light(at, Color(DB.boss_def(cur_boss)["color"]).lightened(0.3), 10.0, 18.0, 1.5)
	shake(1.0)
	Sfx.play("boss_die", 2.0)
	Sfx.music("", 2.0)
	get_tree().create_timer(0.35 * 0.25, true).timeout.connect(func(): Sfx.play("sting_victory", 0.0))
	banner("Victory", Color(1.0, 0.85, 0.45), str(DB.boss_def(cur_boss)["fall"]))
	if hero.alive:
		hero.act("Cheering", 1.6, true)
	# The hoard.
	for i in 26:
		_drop("gold", at, randi_range(3, 8) * int(tier["gold"]))
	for i in randi_range(3, 4):
		_drop_item(at, Game.roll_boss_item(cur_boss, tier_i, loot_bonus))
	if mode == "rift":
		_drop_item(at, Game.make_unique(_rift_unique()))
	for u in Game.roll_uniques(str(DB.boss_def(cur_boss)["source"]), tier_i):
		_drop_item(at, Game.make_unique(u))
	for i in 10:
		_drop("soul", at, 4)
	# Everything left standing crumbles.
	for f in foes.duplicate():
		if f.alive:
			_kill(f)


var _end_time := 0.0


## The rift's prize: a unique from the boss's table, for this hero if one fits.
func _rift_unique() -> String:
	var src := str(DB.boss_def(cur_boss)["source"])
	var mine := []
	var any := []
	for u: String in DB.UNIQUES:
		var ud: Dictionary = DB.UNIQUES[u]
		if str(ud["source"]) != src or not ud["slot"] in DB.SLOTS:
			continue
		any.append(u)
		if str(ud.get("cls", "")) == hero_id:
			mine.append(u)
	var pool := mine if not mine.is_empty() else any
	return str(pool.pick_random()) if not pool.is_empty() else "tooth"


## `mech` marks a telegraphed attack: it also takes that many shares of the
## tier's `mech` fraction of max health, through armor (see DB.TIERS).
func damage_hero(amount: float, src: Node3D, mech := 0.0) -> void:
	if not hero.alive or phase == "victory" or phase == "boss_intro":
		return
	if hero.invuln > 0.0:
		if hero.dash_t > 0.0 or hero.dash_cd > hero.dash_cd_max - 0.4:
			if not hero.perfect_used and amount > 0.0:
				_perfect_dodge()
			else:
				fx.text(hero.flat_pos(), "Dodged", Color(0.7, 0.9, 1.0), 0.6, 0.6)
		return
	if hero.ward_up:
		hero.break_ward()
		return
	# Bulwark: a planted knight takes blows from the front on the shield.
	if int(cards.get("bulwark", 0)) > 0 and hero.still_t > 0.25 and src != null:
		var to := (src as Node3D).global_position - hero.global_position
		if absf(angle_difference(hero.rotation.y, atan2(to.x, to.z))) < deg_to_rad(75.0):
			amount *= 0.4
			fx.text(hero.flat_pos(), "Blocked", Color(0.75, 0.85, 1.0), 0.6, 0.5)
			Sfx.play("shield_break", -12.0, 1.6)
	amount *= 1.0 - DB.armor_dr(hero.armor, float(tier.get("pen", 0.0)))
	amount += hero.max_hp * float(tier.get("mech", 0.0)) * mech
	amount *= 1.0 + pact_sum("dmg_taken")
	amount = roundf(amount * randf_range(0.92, 1.08))
	hero.hp -= amount
	hero.hit_flash()
	hero.invuln = 0.08
	fx.number(hero.flat_pos(), int(amount), Color(1.0, 0.3, 0.25), 0.9)
	hud.hurt(clampf(amount / hero.max_hp * 4.0, 0.25, 1.0))
	Ui.buzz(35, clampf(amount / hero.max_hp * 5.0, 0.3, 1.0))
	shake(0.22)
	Sfx.play("hero_hurt", -3.0)
	if src is Enemy:
		var e := src as Enemy
		if "vampiric" in e.affixes:
			e.hp = minf(e.hp + amount * 2.0, e.max_hp)
			fx.lightning(PackedVector3Array([hero.position + Vector3(0, 1.0, 0), e.position + Vector3(0, 1.0, 0)]), Color(1.0, 0.2, 0.25))
		if hero.thorns > 0.0 and e.def["ai"] == "melee" and e.alive:
			Sfx.play("thorns", -6.0)
			damage_foe(e, amount * hero.thorns * 2.0, hero, (e.flat_pos() - hero.flat_pos()).normalized(), 3.0)
	if hero.hp > 0.0 and hero.flags.has("second_wind") and not hero.wind_used and hero.hp < hero.max_hp * 0.3:
		hero.wind_used = true
		hero.hp = minf(hero.hp + hero.max_hp * float(hero.flags["second_wind"]), hero.max_hp)
		hud.event("Second wind", Color(0.5, 1.0, 0.6), "heart-plus")
		fx.ring(hero.flat_pos(), 4.0, Color(0.5, 1.0, 0.6), 0.5)
		Sfx.play("levelup", -6.0)
	if hero.hp <= 0.0:
		hero.hp = 0.0
		if int(cards.get("phoenix", 0)) > 0 and not hero.revived:
			hero.revive()
			fx.ring(hero.flat_pos(), 6.0, Color(1.0, 0.6, 0.2), 0.6)
			fx.flash_light(hero.flat_pos(), Color(1.0, 0.6, 0.25), 8.0, 12.0, 0.8)
			for f in foes_near(hero.position, 6.0):
				damage_foe(f, hero.dmg * 3.0, hero, (f.flat_pos() - hero.flat_pos()).normalized(), 12.0)
			banner("Undying", Color(1.0, 0.7, 0.3), "You rise again")
			Sfx.play("phoenix", 0.0)
		else:
			_hero_dies()


## The hero dashed through a blow that would have landed: reward the read.
func _perfect_dodge() -> void:
	hero.perfect_used = true
	hero.riposte_t = float(DB.PERFECT_DODGE["time"])
	hero.super_charge = minf(hero.super_charge + float(DB.PERFECT_DODGE["super"]), 1.0)
	perfect_dodges += 1
	if hero.flags.has("dodge_heal"):
		hero.hp = minf(hero.hp + hero.max_hp * float(hero.flags["dodge_heal"]), hero.max_hp)
	fx.text(hero.flat_pos() + Vector3(0, 0.4, 0), "Perfect!", Color(0.55, 0.95, 1.0), 1.2, 0.9)
	tip("perfect", "Perfect dodge: your next hits strike 35% harder", "sprint")
	fx.ring(hero.flat_pos(), 2.6, Color(0.55, 0.9, 1.0), 0.35, 0.16)
	fx.flash_light(hero.flat_pos(), Color(0.5, 0.85, 1.0), 3.0, 6.0, 0.25)
	Sfx.play("unlock_start", -4.0, 1.5)
	Ui.buzz(30, 0.5)
	hitstop(0.07)


func _hero_dies() -> void:
	hero.die_anim()
	Ui.buzz(120, 0.8)
	phase = "defeat"
	phase_t = 0.0
	_end_time = time
	Engine.time_scale = 0.35
	_real_hitstop = 1.2
	Sfx.music("", 1.5)
	Sfx.play("sting_defeat", 0.0)
	banner("You have died", Color(0.85, 0.2, 0.18), str(zone["defeat"]))
	get_tree().create_timer(2.4 * 0.35, true).timeout.connect(func(): _end(false))


# --- Projectiles ----------------------------------------------------------

func spawn_proj(kind: String, pos: Vector3, vel: Vector3, dmg: float, hits: int, src: Node3D, extra := {}) -> void:
	var pool: Array = _proj_pool.get(kind, [])
	_proj_pool[kind] = pool
	var p: Proj
	if pool.is_empty():
		p = Proj.new()
		p.body = _proj_body(kind)
		p.add_child(p.body)
		world.add_child(p)
	else:
		p = pool.pop_back()
	p.launch(kind, pos, vel, dmg, hits, src, extra)
	projs.append(p)


func _proj_body(kind: String) -> Node3D:
	var root := Node3D.new()
	match kind:
		"arrow":
			var a := KK.prop("res://assets/kaykit/weapons/arrow_bow.gltf")
			a.rotation = Vector3(0, 0, 0)
			a.scale = Vector3.ONE * 1.4
			root.add_child(a)
			root.add_child(_streak(Color(1.0, 0.9, 0.6), 1.8))
		"bolt":
			var b := KK.prop("res://assets/kaykit/weapons/Skeleton_Arrow.gltf")
			b.scale = Vector3.ONE * 1.4
			root.add_child(b)
			root.add_child(_streak(Color(1.0, 0.3, 0.2), 1.6))
		"fireball":
			var s := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.26
			sm.height = 0.52
			s.mesh = sm
			var m := StandardMaterial3D.new()
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.albedo_color = Color(1.0, 0.85, 0.5)
			m.emission_enabled = true
			m.emission = Color(1.0, 0.45, 0.1)
			m.emission_energy_multiplier = 4.0
			s.material_override = m
			s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(s)
			root.add_child(_streak(Color(1.0, 0.5, 0.15), 1.4, 0.7))
		"axe":
			var ax := KK.prop("res://assets/kaykit/weapons/axe_1handed.gltf")
			ax.scale = Vector3.ONE * 1.9
			ax.rotation = Vector3(PI * 0.5, 0, 0)
			ax.position = Vector3(0, 0, -0.55)
			root.add_child(ax)
			root.add_child(_streak(Color(1.0, 0.7, 0.4), 1.0, 0.5))
		"orb":
			var o := MeshInstance3D.new()
			var om := SphereMesh.new()
			om.radius = 0.3
			om.height = 0.6
			o.mesh = om
			var omat := StandardMaterial3D.new()
			omat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			omat.albedo_color = Color(0.9, 0.7, 1.0)
			omat.emission_enabled = true
			omat.emission = Color(0.7, 0.35, 1.0)
			omat.emission_energy_multiplier = 4.0
			o.material_override = omat
			o.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(o)
			root.add_child(_streak(Color(0.7, 0.4, 1.0), 1.4, 0.6))
		"spear":
			var bone := KK.prop("res://assets/kaykit/graveyard/bone_A.gltf")
			bone.scale = Vector3.ONE * 2.2
			bone.rotation = Vector3(0, PI * 0.5, 0)
			root.add_child(bone)
			root.add_child(_streak(Color(0.45, 1.0, 0.7), 1.6, 0.6))
		"wave":
			var w := MeshInstance3D.new()
			w.mesh = fx._arc(100)
			var wm := ShaderMaterial.new()
			wm.shader = Fx.SLASH
			wm.set_shader_parameter("color", Color(0.7, 0.85, 1.0))
			w.material_override = wm
			w.set_instance_shader_parameter("progress", 0.5)
			w.scale = Vector3(1.4, 1, 0.9)
			w.position = Vector3(0, -0.2, -0.6)
			w.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(w)
	return root


func _streak(color: Color, length: float, width := 0.35) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(width, length)
	q.orientation = PlaneMesh.FACE_Y
	mi.mesh = q
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(color.r, color.g, color.b, 0.55)
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0))
	g.set_color(1, Color(1, 1, 1, 1))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0.5, 1.0)
	gt.fill_to = Vector2(0.5, 0.0)
	gt.width = 8
	gt.height = 64
	m.albedo_texture = gt
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	mi.position = Vector3(0, 0, -length * 0.5)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


func _tick_projs(dt: float) -> void:
	var i := projs.size() - 1
	while i >= 0:
		var p := projs[i]
		if not p.tick(dt, self):
			_release_proj(p)
			projs.remove_at(i)
		i -= 1


func _release_proj(p: Proj) -> void:
	p.active = false
	p.visible = false
	_proj_pool[p.kind] = _proj_pool.get(p.kind, [])
	_proj_pool[p.kind].append(p)


# --- Pickups -------------------------------------------------------------

var _label_n := 0
var _soul_mesh: Mesh
var _soul_mat: Material
var _heart_mat: Material


func _drop(kind: String, at: Vector3, value: int) -> void:
	var p := Pickup.new()
	p.kind = kind
	p.value = value
	p.spin = randf() * TAU
	world.add_child(p)
	p.position = at + Vector3(0, 0.8, 0)
	var a := randf() * TAU
	var spd := randf_range(1.5, 4.5) if kind != "gold" or phase != "victory" else randf_range(3.0, 8.0)
	p.vel = Vector3(sin(a) * spd, randf_range(5.0, 8.0), cos(a) * spd)
	p.settle = randf_range(0.45, 0.7)
	match kind:
		"soul", "heart":
			if _soul_mesh == null:
				var sm := SphereMesh.new()
				sm.radius = 0.14
				sm.height = 0.28
				sm.radial_segments = 10
				sm.rings = 6
				_soul_mesh = sm
				var m := StandardMaterial3D.new()
				m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				m.albedo_color = Color(0.6, 0.95, 1.0)
				m.emission_enabled = true
				m.emission = Color(0.35, 0.85, 1.0)
				m.emission_energy_multiplier = 4.0
				_soul_mat = m
				var hm := m.duplicate() as StandardMaterial3D
				hm.albedo_color = Color(1.0, 0.5, 0.5)
				hm.emission = Color(1.0, 0.15, 0.2)
				_heart_mat = hm
			var mi := MeshInstance3D.new()
			mi.mesh = _soul_mesh
			mi.material_override = _soul_mat if kind == "soul" else _heart_mat
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			if kind == "heart":
				mi.scale = Vector3.ONE * 2.0
			p.add_child(mi)
			p.body = mi
		"gold":
			var c := KK.prop("res://assets/kaykit/dungeon/coin.gltf")
			c.scale = Vector3.ONE * 1.5
			c.rotation.x = PI * 0.5
			var holder := Node3D.new()
			holder.add_child(c)
			p.add_child(holder)
			p.body = holder
	pickups.append(p)


func _drop_item(at: Vector3, it: Dictionary) -> void:
	var p := Pickup.new()
	p.kind = "item"
	p.item = it
	world.add_child(p)
	p.position = at + Vector3(0, 1.0, 0)
	var a := randf() * TAU
	var spd := randf_range(2.0, 4.0)
	p.vel = Vector3(sin(a) * spd, 7.0, cos(a) * spd)
	p.settle = 0.75
	var model_path: String = {"weapon": "res://assets/kaykit/weapons/sword_2handed_color.gltf", "helm": "res://assets/kaykit/graveyard/skull.gltf", "chest": "res://assets/kaykit/weapons/shield_badge_color.gltf", "legs": "res://assets/kaykit/weapons/shield_square_color.gltf", "trinket": "res://assets/kaykit/dungeon/key.gltf", "pet": "res://assets/kaykit/graveyard/skull.gltf", "trophy": "res://assets/kaykit/graveyard/skull_candle.gltf"}.get(it["slot"], "res://assets/kaykit/dungeon/coin_stack_small.gltf")
	var m := KK.prop(model_path)
	m.scale = Vector3.ONE * 1.3
	m.rotation = Vector3(0, randf() * TAU, PI * 0.5 if it["slot"] == "weapon" else 0.0)
	m.position.y = 0.2
	var holder := Node3D.new()
	holder.add_child(m)
	p.add_child(holder)
	p.body = holder
	var col := DB.rarity_color(it["rarity"])
	get_tree().create_timer(0.7, false).timeout.connect(func():
		if is_instance_valid(p) and p.is_inside_tree():
			p.beam = fx.beam(Vector3(p.position.x, 0, p.position.z), col, 9.0 if it["rarity"] == "legendary" else 6.0)
			var l := Label3D.new()
			# Short and big ("Rare Helm"), stacked so neighbours do not overlap.
			l.text = "%s %s" % [DB.RARITY_NAME[it["rarity"]], DB.SLOT_NAME.get(it["slot"], "Trophy")] if str(it.get("unique", "")) == "" else str(it["name"])
			l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			l.no_depth_test = true
			l.pixel_size = 0.013
			l.font = fx.title_font
			l.font_size = 44
			l.outline_size = 14
			l.modulate = col.lightened(0.15)
			l.outline_modulate = Color(0, 0, 0, 0.9)
			l.position = Vector3(0, 1.6 + 0.55 * (_label_n % 3), 0)
			_label_n += 1
			p.add_child(l)
			p.label = l
			Sfx.play("gear_drop", -2.0)
			if it["rarity"] == "legendary":
				Sfx.play("sparkle", 0.0)
				Ui.buzz(60, 0.6)
			if it["rarity"] in ["rare", "legendary"]:
				Sfx.play("rare_chime", 0.0, 0.9 if it["rarity"] == "legendary" else 1.0))
	pickups.append(p)


func _tick_pickups(dt: float) -> void:
	var i := pickups.size() - 1
	while i >= 0:
		var p := pickups[i]
		if not is_instance_valid(p) or not p.tick(dt, self):
			pickups.remove_at(i)
		i -= 1


func _loot_left() -> int:
	var n := 0
	for p in pickups:
		if is_instance_valid(p):
			n += 1
	return n


func collect(p: Pickup) -> void:
	match p.kind:
		"soul":
			_xp_frac += p.value * hero.xp_mult
			run_xp += int(_xp_frac)
			_xp_frac -= int(_xp_frac)
			Sfx.play("gem", -12.0, 1.0 + minf(run_xp % 7, 6) * 0.03)
			fx.flare(hero.flat_pos() + Vector3(0, 0.3, 0), Color(0.3, 0.8, 1.0, 0.5))
			_check_level()
		"gold":
			var g := int(round(p.value * float(tier["gold"]) * hero.gold_mult))
			gold += maxi(g, 1)
			Sfx.play("coin", -10.0)
		"heart":
			hero.hp = minf(hero.hp + hero.max_hp * 0.25, hero.max_hp)
			fx.text(hero.flat_pos(), "+%d" % int(hero.max_hp * 0.25), Color(0.4, 1.0, 0.5))
			Sfx.play("lifesteal", -4.0)
		"item":
			items.append(p.item)
			fx.release_beam(p.beam)
			var col := DB.rarity_color(p.item["rarity"])
			fx.burst(hero.flat_pos(), col, 12, 5.0)
			var better: bool = p.item["slot"] in DB.SLOTS and Game.is_better(p.item, hero_id)
			hud.toast("[color=#%s]%s[/color]" % [col.to_html(false), p.item["name"]], "▲ Upgrade for your %s" % DB.SLOT_NAME[p.item["slot"]].to_lower() if better else "Picked up")
			Sfx.play("gear_pickup", -2.0)
	p.queue_free()


func _check_level() -> void:
	var need := DB.run_level_xp(run_level)
	if run_xp >= need and hero.alive and phase != "defeat":
		run_xp -= need
		run_level += 1
		pending_levels += 1
		if pending_levels == 1:
			_offer_cards()


func _offer_cards() -> void:
	var choices := roll_cards(card_choices())
	if choices.is_empty():
		pending_levels = 0
		return
	Sfx.play("levelup", 0.0)
	Ui.buzz(25, 0.4)
	fx.ring(hero.flat_pos(), 3.0, Color(0.4, 0.9, 1.0), 0.6)
	fx.ring(hero.flat_pos(), 5.0, Color(0.7, 0.95, 1.0), 0.45, 0.2)
	fx.burst(hero.flat_pos() + Vector3(0, 1.0, 0), Color(0.5, 0.9, 1.0), 26, 8.0, 1.6)
	fx.flash_light(hero.flat_pos(), Color(0.5, 0.85, 1.0), 4.0, 8.0, 0.35)
	if bot:
		var pref := ["bladestorm", "tempest", "inferno_heart", "rain", "judgement_day", "armageddon", "heavens", "fault", "deluge", "meteor", "smite", "quake", "axes", "barrage", "frost", "explosive", "blades", "storm", "nova", "might", "haste", "multishot", "wave", "crit", "vigor", "phoenix", "reach", "inferno", "pierce", "regen", "leech", "wrath", "ward", "swift"]
		var best: String = choices[0]
		for c in pref:
			if c in choices:
				best = c
				break
		pick_card(best)
		return
	get_tree().paused = true
	hud.show_levelup(choices, run_level)


## Three choices, four once the hero reaches DB.FOURTH_CARD_LEVEL.
func card_choices() -> int:
	return 4 if int(Game.hero(hero_id)["level"]) >= DB.FOURTH_CARD_LEVEL else 3


## Removes a card from this hunt's pool and returns a replacement for it (or
## "" when nothing is left to draw).
func banish(id: String, shown: Array) -> String:
	if banishes_left <= 0 or DB.CARDS[id].has("evo"):
		return ""
	banishes_left -= 1
	banished.append(id)
	var fresh := roll_cards(1, shown + banished)
	return "" if fresh.is_empty() else str(fresh[0])


## Redraws the level-up cards, never repeating what was just shown. Evolutions
## stay on offer. Returns [] when no reroll is left.
func reroll_cards(shown: Array) -> Array:
	if rerolls_left <= 0:
		return []
	rerolls_left -= 1
	var out := []
	for id in shown:
		if DB.CARDS[id].has("evo"):
			out.append(id)
	var fresh := roll_cards(shown.size() - out.size(), shown)
	out.append_array(fresh)
	if fresh.is_empty() and out.size() < shown.size():
		rerolls_left += 1
		return []
	return out


func roll_cards(n: int, exclude := []) -> Array:
	var pool := []
	var weights := []
	for id in DB.CARDS:
		var c: Dictionary = DB.CARDS[id]
		if int(cards.get(id, 0)) >= int(c["max"]):
			continue
		if c.has("only") and not str(hero.def["style"]) in c["only"]:
			continue
		if c.has("hero") and not hero_id in c["hero"]:
			continue
		if c["rarity"] == "legendary" and run_level < 5:
			continue
		if c.has("evo") or id in exclude or id in banished:
			continue # evolutions are offered by rule, below
		pool.append(id)
		weights.append(float(DB.CARD_WEIGHT[c["rarity"]]))
	var out := []
	var evos := eligible_evolutions()
	if not evos.is_empty() and exclude.is_empty():
		out.append(evos.pick_random())
	while out.size() < n and not pool.is_empty():
		var total := 0.0
		for w in weights:
			total += w
		var r := randf() * total
		for i in pool.size():
			r -= weights[i]
			if r <= 0.0:
				out.append(pool[i])
				pool.remove_at(i)
				weights.remove_at(i)
				break
	return out


## Evolution cards on offer: the first card of the pair is maxed, the second
## is owned, and the evolution itself is not taken yet.
func eligible_evolutions() -> Array:
	var out := []
	for id in DB.CARDS:
		var c: Dictionary = DB.CARDS[id]
		if not c.has("evo") or int(cards.get(id, 0)) > 0:
			continue
		if c.has("only") and not str(hero.def["style"]) in c["only"]:
			continue
		if c.has("hero") and not hero_id in c["hero"]:
			continue
		var a: String = c["evo"][0]
		var b: String = c["evo"][1]
		# Three stacks of the first card is enough: evolutions should be reachable
		# in a normal hunt, not only in a lucky one.
		if int(cards.get(a, 0)) >= mini(int(DB.CARDS[a]["max"]), 3) and int(cards.get(b, 0)) >= 1:
			out.append(id)
	return out


func pick_card(id: String) -> void:
	cards[id] = int(cards.get(id, 0)) + 1
	hero.recompute()
	if id == "vigor":
		hero.hp = minf(hero.hp + hero.max_hp * 0.3, hero.max_hp)
	pending_levels -= 1
	get_tree().paused = false
	Sfx.play("card_pick", -2.0)
	if pending_levels > 0:
		_offer_cards()
	else:
		_check_level()


# --- Skills (live OSRS level-ups) -----------------------------------------

func skill_xp_gained() -> Dictionary:
	var total := dmg_dealt * DB.XP_PER_DAMAGE * float(tier["xp"])
	var out := {}
	match str(hero.def["skill"]):
		"melee":
			for s in ["attack", "strength", "defence"]:
				out[s] = int(total / 3.0)
		"ranged":
			out["ranged"] = int(total)
		"magic":
			out["magic"] = int(total)
	out["hitpoints"] = int(total / 3.0)
	return out


func _check_skill_levels() -> void:
	var g := skill_xp_gained()
	for s in g:
		var lvl := DB.level_for_xp(int(_skill_base[s]) + int(g[s]))
		if lvl > int(_skill_shown[s]):
			_skill_shown[s] = lvl
			hud.skill_toast(s, lvl)
			Sfx.play("skill_level", -2.0)


# --- Pet -----------------------------------------------------------------

func _spawn_pet() -> void:
	pet = Actor.new()
	world.add_child(pet)
	var pid := str(Game.data["pet"])
	pet.build_model(str(DB.UNIQUES.get(pid, {}).get("model", "Skeleton_Minion")), {}, Color(0.5, 0.7, 1.0), 0.4, Color(1.0, 0.6, 0.2, 1.0))
	pet.model.scale = Vector3.ONE * 0.42
	pet.position = hero.position + Vector3(1.2, 0, 1.0)
	pet.play("Skeletons_Idle")


func _tick_pet(dt: float) -> void:
	var want := hero.position + Vector3(1.1, 0, 0.9).rotated(Vector3.UP, hero.rotation.y)
	var d := want - pet.position
	d.y = 0.0
	if d.length() > 0.4:
		pet.position += d.normalized() * minf(d.length(), (hero.speed + 1.0) * dt * clampf(d.length(), 0.6, 2.0))
		pet.face(atan2(d.x, d.z), dt)
		pet.play("Running_A", 0.15, 1.3)
	else:
		pet.play("Skeletons_Idle", 0.2)


# --- Feel ----------------------------------------------------------------

func hitstop(t: float) -> void:
	if phase == "victory" or phase == "defeat":
		return
	Engine.time_scale = 0.05
	_real_hitstop = maxf(_real_hitstop, t)


func shake(v: float) -> void:
	cam.add_trauma(v)


func banner(text: String, color := Color(1, 0.85, 0.5), sub := "") -> void:
	hud.banner(text, color, sub)


# --- End -----------------------------------------------------------------

func _abandon() -> void:
	get_tree().paused = false
	_end(false)


func _end(win: bool) -> void:
	if _ended:
		return
	_ended = true
	Engine.time_scale = 1.0
	# Loot still lying around after a win is swept into the bag.
	if win:
		for p in pickups:
			if is_instance_valid(p):
				match p.kind:
					"gold":
						gold += int(round(p.value * float(tier["gold"]) * hero.gold_mult))
					"item":
						items.append(p.item)
	var spent := _end_time if _end_time > 0.0 else time
	result = {
		"win": win, "tier": tier_i, "zone": zone_id, "mode": mode, "rooms_cleared": rooms_cleared, "rooms": trial_rooms,"hero": hero_id, "gold": gold, "xp": skill_xp_gained(),
		"items": items, "kills": kills, "elites": elites_killed, "time": spent,
		"chest": tier["chest"] if win else "", "level": run_level, "souls": souls,
		"depth": depth, "dashes": dashes, "boss_time": boss_time,
		"rivals": rivals_total, "place": 1 if win else rivals_alive() + 1,
		"omen": str(omen.get("id", "")),
		"bosses": bosses_killed, "perfect": perfect_dodges,
	}
	# A won hunt under the weekly omen pays more, and its chest is a grade better.
	if not omen.is_empty() and (win or mode == "descent"):
		result["gold"] = int(round(gold * (1.0 + DB.OMEN_GOLD)))
		var grades := ["silver", "gold", "crypt"]
		var ch := str(result["chest"]) if win else ""
		if ch != "":
			result["chest"] = grades[mini(grades.find(ch) + 1, 2)]
	if mode == "wild" and not win and rivals_total > 0 and int(result["place"]) <= 3:
		result["chest"] = "silver"
	if mode == "descent":
		for pair in DB.DESCENT_CHESTS:
			if depth >= int(pair[0]):
				result["chest"] = pair[1]
				break
	var summary := Game.finish_hunt(result)
	result["summary"] = summary
	if bot:
		finished.emit(result)
		return
	hud.show_results(result)
