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
var surge_marks := [0.25, 0.5, 0.75]
var surge_queue: Array = []
var calm_t := 0.0
var _storming := false
var robber_wanted := false
var robber_spawned := false
var streak := 0
var streak_t := 0.0


func _ready() -> void:
	zone_id = Game.zone_id()
	zone = DB.zone(zone_id)
	loot_bonus = int(zone.get("loot_bonus", 0))
	mode = Game.mode_id()
	tier_i = Game.tier()
	rerolls_left = 2 if tier_i >= 2 else 1
	tier = DB.TIERS[tier_i]
	hero_id = Game.hero_id()
	souls_goal = int(tier["souls"])
	if mode == "trial":
		trial_rooms = int(DB.MODES["trial"]["rooms"][tier_i])
		trial_seed = Game.rng.randi()
		souls_goal = 100
		loot_bonus += 1
	robber_wanted = randf() < 0.35
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
	_setup_shrines()
	hud = HUD_SCENE.instantiate()
	add_child(hud)
	hud.setup(self)
	hud.dash_pressed.connect(func(): hero.try_dash())
	hud.super_pressed.connect(func(): hero.try_super())
	hud.card_picked.connect(pick_card)
	hud.results_closed.connect(func(): finished.emit(result))
	hud.abandon_pressed.connect(_abandon)
	for s in DB.SKILLS:
		_skill_base[s] = int(Game.data["skills"][s])
		_skill_shown[s] = DB.level_for_xp(_skill_base[s])
	if bot:
		_bot = HuntBot.new()
		_bot.hunt = self
	if not bot:
		await _warmup()
	Sfx.music("hunt")
	Sfx.play("hunt_start", -2.0)
	if mode == "trial":
		hud.banner(str(DB.MODES["trial"]["name"]), Color(0.85, 0.8, 0.7), "%s · %d rooms to the %s" % [tier["name"], trial_rooms, DB.boss_def(str(zone["boss"]))["name"]])
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
	var ring_shader := preload("res://src/fx/hero_ring.gdshader")
	for i in arena.shrines.size():
		var sd: Dictionary = arena.shrines[i]
		var id: String = ids[i % ids.size()]
		var col: Color = DB.SHRINES[id]["color"]
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
	var d: Dictionary = DB.SHRINES[s["id"]]
	hero.buffs[s["id"]] = time + DB.SHRINE_TIME
	hero.recompute()
	(s["ring"] as MeshInstance3D).queue_free()
	(s["light"] as OmniLight3D).light_energy = 0.4
	banner(str(d["name"]), d["color"], "%d seconds" % int(DB.SHRINE_TIME))
	fx.ring(hero.flat_pos(), 4.0, d["color"], 0.6)
	fx.burst(hero.flat_pos(), d["color"], 24, 8.0, 1.0)
	fx.flash_light(hero.flat_pos(), d["color"], 4.0, 8.0, 0.5)
	Sfx.play("unlock_start", 0.0)
	Ui.buzz(40, 0.5)


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
	_tick_foes(dt)
	if boss:
		boss.tick(dt)
		if boss.alive:
			_separate_from(boss)
	_tick_projs(dt)
	_tick_pickups(dt)
	_tick_patches(dt)
	if pet:
		_tick_pet(dt)
	match phase:
		"rise":
			_direct(dt)
		"boss_intro":
			if phase_t > 2.6:
				phase = "boss"
				hud.boss_mode(boss)
		"victory":
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
			cam.zoom_target = 0.85
			cam.focus_override = null
		_:
			cam.zoom_target = 1.0 + clampf((foes.size() - 15) / 60.0, 0.0, 0.12)


# --- Foes ----------------------------------------------------------------

func _tick_foes(dt: float) -> void:
	var i := foes.size() - 1
	while i >= 0:
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


## A burning patch of ground left by a molten champion. It telegraphs red; the
## hero takes `dps` a second while standing in it.
func add_fire_patch(at: Vector3, r: float, dur: float, dps: float) -> void:
	patches.append({"pos": at, "r": r, "t": dur, "dps": dps, "tick": 0.5, "node": fx.telegraph(0, at, 0.0, Vector2(r, 0), dur)})


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
				damage_hero(float(pt["dps"]) * 0.5, null)
		if pt["t"] <= 0.0:
			patches.remove_at(i)
		i -= 1


func progress() -> float:
	return clampf(float(souls) / float(souls_goal), 0.0, 1.0)


func spawn_foe(kind: String, at: Vector3, elite := false, affix := "") -> Enemy:
	var e := Enemy.new()
	world.add_child(e)
	e.position = at
	e.rotation.y = Actor.yaw_to(at, hero.position)
	e.setup(self, kind, tier, elite, affix)
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
	var p := progress()
	var target := int((lerpf(7.0, 30.0, p) + tier_i * 3) * float(tier.get("press", 1.0)))
	target = mini(target, MAX_FOES)
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
		if hero.vel.length() > 2.5 and (tier_i >= 1 or p > 0.35) and randf() < 0.5:
			var ahead := arena.spawn_point(hero.position + hero.vel.normalized() * 7.0, 2.5, 6.0)
			if ahead.distance_to(hero.position) > 6.0:
				center = ahead
		for i in pack:
			var at := arena.resolve(center + Vector3(randf_range(-1.6, 1.6), 0, randf_range(-1.6, 1.6)), 0.5)
			spawn_foe(_pick_kind(p), at)
		Sfx.play("aggro", -14.0)
	if robber_wanted and not robber_spawned and p >= 0.4:
		robber_spawned = true
		spawn_foe("robber", arena.spawn_point(hero.position, 9.0, 12.0))
		banner("A Grave Robber!", Color(1.0, 0.85, 0.35), "Catch him before he gets away")
		Sfx.play("roar", -2.0, 1.6)
	if not elite_marks.is_empty() and p >= elite_marks[0]:
		elite_marks.pop_front()
		var kinds := ["warrior", "minion", "rogue", "mage"] if p > 0.5 else ["warrior", "minion"]
		var at2 := arena.spawn_point(hero.position, 7.0, 11.0)
		var e := spawn_foe(kinds[randi() % kinds.size()], at2, true)
		banner(e.elite_name, DB.ELITE_AFFIXES[e.affixes[0]]["color"].lightened(0.3), "A champion rises!")
		Sfx.play("roar", -4.0, 1.1)
	if souls >= souls_goal:
		_begin_boss()


## "The graves open!": a ring of the dead climbs out around the hero over two
## seconds, then the hunt breathes for eight.
func _start_surge(p: float) -> void:
	banner("The graves open!", Color(0.7, 0.95, 0.6), "Hold your ground")
	shake(0.3)
	Sfx.play("boom", -4.0, 0.7)
	var count := randi_range(10, 14) + tier_i * 2
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
	return "THE LONG ROAD" if mode == "trial" else "SOULS"


func objective_text() -> String:
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
	if OS.get_environment("TRIALDBG") != "" and int(time) % 5 == 0 and int(time * 10) % 10 == 0:
		var st := []
		for rr: Dictionary in tr["rooms"]:
			st.append(str(rr["state"]).left(1))
		print("TRIAL real=%d t=%d z=%.1f pos_x=%.1f foes=%d q=%d rooms=%s hp=%d" % [Time.get_ticks_msec() / 1000, int(time), z, hero.position.x, foes.size(), _spawn_q.size(), "".join(st), int(hero.hp)])
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
			title = "A quiet place"
			sub = "Rest, and take the blessing"
			for i in 3:
				_drop("heart", hero.flat_pos() + Vector3(randf_range(-3, 3), 0, randf_range(-3, 3)), 1)
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
	var at := hero.flat_pos()
	banner("Room cleared", Color(0.6, 1.0, 0.7), "The way is open")
	Sfx.play("rare_chime", -2.0)
	var kind := str(r["kind"])
	for i in randi_range(4, 7):
		_drop("gold", at, randi_range(2, 5) * int(tier["gold"]))
	for i in randi_range(1, 2):
		_drop("heart", at + Vector3(randf_range(-2, 2), 0, randf_range(-2, 2)), 1)
	var d: float = r["depth"]
	if kind in ["elite", "brutes"]:
		_drop_item(at, _roll_good("elite", 1))
	elif kind == "treasure":
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
	var b: Boss = BossHexer.new() if zone["boss"] == "hexer" else Boss.new()
	b.boss_id = zone["boss"]
	return b


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
	boss.setup(self, tier)
	cam.focus_override = arena.boss_spawn + Vector3(0, 0, 3.0)
	fx.puff(arena.boss_spawn, Color(0.3, 0.27, 0.22, 0.85), 22, 3.0, 3.0)
	fx.bone_burst(arena.boss_spawn, 10, 8.0)
	var aura: Color = DB.boss_def(str(zone["boss"]))["color"]
	fx.ring(arena.boss_spawn, 7.0, aura, 0.8)
	fx.flash_light(arena.boss_spawn, aura, 8.0, 16.0, 1.2)
	shake(0.8)
	Sfx.music("boss", 0.6)
	Sfx.play("boss_roar", 2.0)
	var bd := DB.boss_def(str(zone["boss"]))
	banner(str(bd["name"]), Color(bd["color"]).lightened(0.25), str(bd["wake"]))


# --- Damage --------------------------------------------------------------

func damage_foe(f: Actor, amount: float, _src: Node3D, dir: Vector3, force: float) -> void:
	if not f.alive:
		return
	if f is Enemy and (f as Enemy).state == "spawn":
		return
	if f is Boss and (f as Boss).state == "intro":
		return
	var crit := randf() < hero.crit
	if crit:
		amount *= 2.0
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
	fx.number(f.flat_pos() + Vector3(0, 0.6 if big else 0.0, 0), int(amount), Color(1.0, 0.72, 0.25) if crit else Color(1, 1, 1), 1.35 if crit else 1.0, null if crit else f)
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
		hero.hp = minf(hero.hp + landed * hero.leech, hero.max_hp)
	if f.hp <= 0.0:
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
	streak += 1
	streak_t = DB.STREAK_WINDOW
	if streak in DB.STREAKS:
		run_xp += streak / 3
		gold += streak / 5
		banner("Massacre ×%d" % streak, Color(1.0, 0.4, 0.3), "+%d souls  +%d gold" % [streak / 3, streak / 5])
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
	if f.elite:
		elites_killed += 1
		hitstop(0.09)
		shake(0.5)
		for i in 10:
			_drop("gold", at, randi_range(2, 5))
		_drop_item(at, Game.roll_item("elite", tier_i, "", "", loot_bonus))
		for u in Game.roll_uniques("elite", tier_i):
			_drop_item(at, Game.make_unique(u))
		if "molten" in f.affixes:
			fx.telegraph(0, at, 0.0, Vector2(2.6, 0), 1.0)
			get_tree().create_timer(1.0, false).timeout.connect(func():
				fx.ring(at, 2.8, Color(1.0, 0.45, 0.1), 0.4)
				fx.burst(at, Color(1.0, 0.5, 0.15), 18, 8.0)
				if hero.flat_pos().distance_to(at) < 2.6:
					damage_hero(f.dmg * 1.2, null))
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
	boss.die()
	Ui.buzz(120, 0.9)
	phase = "victory"
	phase_t = 0.0
	_end_time = time
	hud.boss_mode(null)
	Engine.time_scale = 0.25
	_real_hitstop = 1.4
	var at := boss.flat_pos()
	fx.bone_burst(at, 20, 10.0)
	fx.ring(at, 9.0, Color(DB.boss_def(str(zone["boss"]))["color"]).lightened(0.2), 1.0)
	fx.flash_light(at, Color(DB.boss_def(str(zone["boss"]))["color"]).lightened(0.3), 10.0, 18.0, 1.5)
	shake(1.0)
	Sfx.play("boss_die", 2.0)
	Sfx.music("", 2.0)
	get_tree().create_timer(0.35 * 0.25, true).timeout.connect(func(): Sfx.play("sting_victory", 0.0))
	banner("Victory", Color(1.0, 0.85, 0.45), str(DB.boss_def(str(zone["boss"]))["fall"]))
	if hero.alive:
		hero.act("Cheering", 1.6, true)
	# The hoard.
	for i in 26:
		_drop("gold", at, randi_range(3, 8) * int(tier["gold"]))
	for i in randi_range(3, 4):
		_drop_item(at, Game.roll_item("boss", tier_i, "", "", loot_bonus))
	for u in Game.roll_uniques(str(DB.boss_def(str(zone["boss"]))["source"]), tier_i):
		_drop_item(at, Game.make_unique(u))
	for i in 10:
		_drop("soul", at, 4)
	# Everything left standing crumbles.
	for f in foes.duplicate():
		if f.alive:
			_kill(f)


var _end_time := 0.0


func damage_hero(amount: float, src: Node3D) -> void:
	if not hero.alive or phase == "victory" or phase == "boss_intro":
		return
	if hero.invuln > 0.0:
		if hero.dash_t > 0.0 or hero.dash_cd > hero.dash_cd_max - 0.4:
			fx.text(hero.flat_pos(), "Dodged", Color(0.7, 0.9, 1.0), 0.6, 0.6)
		return
	if hero.ward_up:
		hero.break_ward()
		return
	amount *= (1.0 - hero.armor)
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
			l.text = str(it["name"])
			l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			l.no_depth_test = true
			l.pixel_size = 0.0065
			l.font = fx.title_font
			l.font_size = 44
			l.outline_size = 14
			l.modulate = col.lightened(0.15)
			l.outline_modulate = Color(0, 0, 0, 0.9)
			l.position = Vector3(0, 1.6, 0)
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
			run_xp += p.value
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
	var choices := roll_cards(3)
	if choices.is_empty():
		pending_levels = 0
		return
	Sfx.play("levelup", 0.0)
	Ui.buzz(25, 0.4)
	fx.ring(hero.flat_pos(), 3.0, Color(0.4, 0.9, 1.0), 0.6)
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
	var fresh := roll_cards(3 - out.size(), shown)
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
		if c.has("evo") or id in exclude:
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
		if int(cards.get(a, 0)) >= int(DB.CARDS[a]["max"]) and int(cards.get(b, 0)) >= 1:
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
	pet.build_model("Skeleton_Minion", {}, Color(0.5, 0.7, 1.0), 0.4, Color(1.0, 0.6, 0.2, 1.0))
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
		"win": win, "tier": tier_i, "zone": zone_id, "mode": mode, "rooms_cleared": rooms_cleared, "hero": hero_id, "gold": gold, "xp": skill_xp_gained(),
		"items": items, "kills": kills, "elites": elites_killed, "time": spent,
		"chest": tier["chest"] if win else "", "level": run_level, "souls": souls,
	}
	var summary := Game.finish_hunt(result)
	result["summary"] = summary
	if bot:
		finished.emit(result)
		return
	hud.show_results(result)
