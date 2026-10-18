extends ScreenBase

## Renders a RunSim. The thumbstick, cards, and boss loot live here.
## Combat steps at a fixed 60Hz. The stick is sampled every displayed frame.

const STEP := 1.0 / 60.0

var biome_id := "meadow"
var hero_id := "ember"
var sim: RunSim
var drive := Vector2.ZERO
var acc := 0.0
var hitstop := 0.0
var trauma := 0.0
var committed := false
## Daily Challenge: the pinned day key and modifiers, the run args (so TRY
## AGAIN repeats the same hunt) and the recorded local entry.
var daily_key := ""
var is_daily := false
## True when the daily plays a biome the player has not unlocked: daily-only
## access with a mild health assist, and no clear credit on a win.
var daily_pass := false
var run_args: Dictionary = {}
var daily_entry: Dictionary = {}
var daily_recorded := false
var pet_follow := ""
var pet_pos := Vector2.ZERO
var pet_ready := false
var summary: Dictionary = {}
## Gear item ids picked up this run (from gear_pickup events), shown in the
## end-of-run loot reveal alongside any summary["gear"] the save layer adds.
var run_gear: Array = []
var _boss_lit := false
var _modal_up := false
var minimap: MiniMap
var dodge_btn: DodgeButton
var _punch: Dictionary = {}
var _actor_sprites: Dictionary = {}
var _gem_sprites: Dictionary = {}
var _shot_sprites: Dictionary = {}

var stage: Stage3D
var world: Node2D
var stream: MapStream
var cam: HuntCamera
var marks: GroundMarks
var threats: ThreatLayer
var sync_alpha := 1.0
var actors_root: Node2D
var sparks: SparkLayer
var stick: StickLayer
var modal: Control
var modal_box: VBoxContainer
var flash_rect: ColorRect
var hp_meter: Meter
var xp_meter: Meter
var boss_meter: Meter
var level_label: Label
var level_badge: UiKit.Badge
var name_label: Label
var hero_medal: UiKit.Medal
var clock_label: Label
var boss_label: Label
var banner: Label
var boss_card: BossNameCard
var floats: Array = []
var _jitter: Dictionary = {}
var finger := -1
var finger_at := Vector2.ZERO
var _stick_out := Vector2.ZERO


func _init() -> void:
	paint_bg = false


func build() -> void:
	music_track = ""
	UiKit.ensure()
	stage = Stage3D.new()
	stage.set_anchors_preset(Control.PRESET_FULL_RECT)
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stage)
	world = Node2D.new()
	add_child(world)
	stream = MapStream.new()
	stream.visible = false
	world.add_child(stream)
	marks = GroundMarks.new()
	marks.visible = false
	world.add_child(marks)
	actors_root = Node2D.new()
	world.add_child(actors_root)
	sparks = SparkLayer.new()
	sparks.visible = false
	world.add_child(sparks)
	var shade := TextureRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.texture = SpriteBank.vignette()
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.modulate = Color(1, 1, 1, 0.72)
	add_child(shade)
	threats = ThreatLayer.new()
	threats.screen = self
	threats.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	threats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(threats)
	_build_hud()
	minimap = MiniMap.new()
	minimap.screen = self
	minimap.visible = false
	add_child(minimap)
	dodge_btn = DodgeButton.new()
	dodge_btn.screen = self
	add_child(dodge_btn)
	stick = StickLayer.new()
	stick.set_anchors_preset(Control.PRESET_FULL_RECT)
	stick.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stick)
	flash_rect = ColorRect.new()
	flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash_rect.color = Color(1, 0.2, 0.15, 0)
	# Damage reads as a red bite at the screen edges; the playfield in the
	# middle stays clear (a full-screen wash hid the fight for a frame).
	var edge := ShaderMaterial.new()
	edge.shader = Shader.new()
	edge.shader.code = "shader_type canvas_item;\nvoid fragment() {\n\tvec2 d = (UV - 0.5) * vec2(1.0, 0.8);\n\tfloat v = smoothstep(0.28, 0.62, length(d));\n\tCOLOR = vec4(COLOR.rgb, COLOR.a * v);\n}\n"
	flash_rect.material = edge
	add_child(flash_rect)
	_build_modal()


func open(args: Dictionary = {}) -> void:
	biome_id = str(args.get("biome", "meadow"))
	hero_id = str(args.get("hero", "ember"))
	run_args = args.duplicate(true)
	var session := Session.solo(biome_id, hero_id)
	# Real runs keep Session.solo's fresh random seed, so every load lays out
	# a slightly different map. Captures, movies and the daily challenge pin
	# one through args["seed"] (or CC_SEED for the capture scripts).
	if args.has("seed"):
		session.seed = int(args["seed"])
	elif OS.get_environment("CC_SEED").is_valid_int():
		session.seed = OS.get_environment("CC_SEED").to_int()
	# A daily rides the same seeded path, plus its day key and modifiers.
	if args.has("daily"):
		is_daily = true
		daily_key = str(args["daily"])
		session.daily_key = daily_key
		session.modifiers = args.get("modifiers", [])
	# A sealed biome is playable through the daily (daily access). Give the
	# heroes the Daily pass so the taste of a later biome is fair.
	daily_pass = is_daily and not SaveGame.biome_open(biome_id)
	sim = RunSim.new()
	var stats := {}
	stats[hero_id] = SaveGame.build_run_stats(hero_id)
	if daily_pass:
		stats[hero_id]["hp"] = float(stats[hero_id]["hp"]) * Daily.PASS_HP_MUL
	sim.start(session, stats)
	AudioDirector.music("hunt")
	cam = HuntCamera.new()
	var hero_at := sim.play.get_center()
	if not sim.heroes.is_empty():
		hero_at = sim.heroes[0].pos
	cam.setup(sim.map, hero_at)
	stream.sync(sim.map, cam.view_rect())
	if sim.explore:
		stage.bind_world(sim.map, biome_id)
		minimap.sim = sim
		minimap.visible = true
	else:
		stage.bind_hunt(biome_id)
		minimap.visible = false
	marks.sim = sim
	var info := Catalog.critter(hero_id)
	name_label.text = str(info["name"])
	hero_medal.tex = SpriteBank.head(hero_id)
	if hero_medal.face != null:
		hero_medal.face.texture = hero_medal.tex
	SaveGame.set_featured(hero_id)
	_mount_pet()


func _build_hud() -> void:
	var pad := insets()
	var scrim := Scrim.new()
	scrim.top_h = float(pad["t"]) + 300.0
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(scrim)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", int(pad["l"]))
	margin.add_theme_constant_override("margin_right", int(pad["r"]))
	margin.add_theme_constant_override("margin_top", int(pad["t"]))
	margin.add_theme_constant_override("margin_bottom", int(pad["b"]))
	add_child(margin)
	var top := VBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_theme_constant_override("separation", 6)
	margin.add_child(top)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 8)
	# Hero plate: portrait medal, name, and a segmented life bar.
	var medal := UiKit.Medal.new()
	medal.tex = SpriteBank.head("ember")
	medal.custom_minimum_size = Vector2(98, 98)
	row.add_child(medal)
	hero_medal = medal
	var info := VBoxContainer.new()
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.add_theme_constant_override("separation", 4)
	name_label = UiKit.label("Hero", 26, UiKit.GOLD.lightened(0.2), "x", 3)
	info.add_child(name_label)
	hp_meter = Meter.new()
	hp_meter.fill = Color("d8352a")
	hp_meter.segments = 10
	hp_meter.custom_minimum_size = Vector2(230, 26)
	info.add_child(hp_meter)
	row.add_child(info)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(gap)
	var side := HBoxContainer.new()
	side.mouse_filter = Control.MOUSE_FILTER_IGNORE
	side.alignment = BoxContainer.ALIGNMENT_CENTER
	side.add_theme_constant_override("separation", 12)
	var clock_plate := UiKit.Plate.new()
	clock_plate.kind = "plaque"
	clock_plate.pad = 10
	clock_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clock_plate.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	clock_label = UiKit.label("0:00", 26, UiKit.CREAM, "b", 3)
	clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	clock_label.custom_minimum_size = Vector2(70, 0)
	clock_plate.add_child(clock_label)
	side.add_child(clock_plate)
	var pause := UiKit.icon_button("II", 64, "steel")
	pause.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pause.pressed.connect(_pause)
	side.add_child(pause)
	row.add_child(side)
	top.add_child(row)
	var xp_row := HBoxContainer.new()
	xp_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	xp_row.add_theme_constant_override("separation", 8)
	# Level shield (the same gilt-and-enamel badge as Home) beside a
	# recessed XP track with a glowing fill.
	level_badge = UiKit.Badge.new()
	level_badge.custom_minimum_size = Vector2(58, 64)
	xp_row.add_child(level_badge)
	level_label = Label.new()
	level_label.visible = false
	xp_row.add_child(level_label)
	xp_meter = XpBar.new()
	xp_meter.fill = Color("3fd0b0")
	xp_meter.custom_minimum_size = Vector2(0, 28)
	xp_meter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	xp_meter.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	xp_row.add_child(xp_meter)
	top.add_child(xp_row)
	boss_label = UiKit.label("", 28, UiKit.GOLD.lightened(0.2), "x", 4)
	boss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_label.visible = false
	# Boss name + bar stop short of the corner minimap so its right end shows.
	var label_wrap := MarginContainer.new()
	label_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label_wrap.add_theme_constant_override("margin_left", 30)
	label_wrap.add_theme_constant_override("margin_right", int(MiniMap.DIAM) + 40)
	label_wrap.add_child(boss_label)
	top.add_child(label_wrap)
	boss_meter = Meter.new()
	boss_meter.fill = Color("b8241c")
	boss_meter.ornate = true
	boss_meter.custom_minimum_size = Vector2(0, 30)
	boss_meter.visible = false
	var boss_wrap := MarginContainer.new()
	boss_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boss_wrap.add_theme_constant_override("margin_left", 30)
	boss_wrap.add_theme_constant_override("margin_right", int(MiniMap.DIAM) + 40)
	boss_wrap.add_child(boss_meter)
	top.add_child(boss_wrap)
	banner = UiKit.label("", 38, UiKit.GOLD.lightened(0.25), "x", 4)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.modulate.a = 0.0
	top.add_child(banner)
	# The boss name card floats above the HUD in the upper-middle band,
	# clear of the boss bar above it and the hero below.
	boss_card = BossNameCard.new()
	boss_card.anchor_left = 0.0
	boss_card.anchor_right = 1.0
	boss_card.anchor_top = 0.27
	boss_card.anchor_bottom = 0.27
	boss_card.offset_left = float(pad["l"]) + 42.0
	boss_card.offset_right = -(float(pad["r"]) + 42.0)
	boss_card.offset_top = 0.0
	boss_card.offset_bottom = float(BossNameCard.CARD_H)
	boss_card.z_index = 1600
	boss_card.visible = false
	boss_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(boss_card)


func _build_modal() -> void:
	modal = Control.new()
	modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal.visible = false
	modal.mouse_filter = Control.MOUSE_FILTER_STOP
	# Above the damage numbers (z 1000 in the world layer), so no float crosses a modal.
	modal.z_index = 2000
	add_child(modal)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(1, 1, 1, 1)
	# Dimmed battlefield with a warm-black vignette: the fight stays
	# visible in the middle, the edges sink, no flat navy wash.
	var vig := Shader.new()
	vig.code = """shader_type canvas_item;
void fragment() {
	vec2 c = UV - 0.5;
	c.x *= 0.62;
	float r = length(c) * 2.0;
	float a = mix(0.5, 0.92, smoothstep(0.25, 1.05, r));
	COLOR = vec4(0.035, 0.022, 0.015, a);
}
"""
	var vm := ShaderMaterial.new()
	vm.shader = vig
	dim.material = vm
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	modal.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	modal.add_child(center)
	modal_box = VBoxContainer.new()
	modal_box.custom_minimum_size = Vector2(690, 0)
	modal_box.add_theme_constant_override("separation", 12)
	center.add_child(modal_box)


func _process(delta: float) -> void:
	if sim == null:
		return
	# Touch events are applied before _process. Re-read the latest point
	# every displayed frame so a 120Hz phone is not waiting on the 60Hz sim.
	if stick.active:
		stick.place(finger_at)
	delta = minf(delta, 0.05)
	if hitstop > 0.0:
		hitstop = maxf(0.0, hitstop - delta)
		_hud()
		_sync(1.0)
		_tick_floats(0.0)
		return
	trauma = maxf(0.0, trauma - delta * 2.3)
	var mag := trauma * trauma * 11.0 * AudioDirector.shake_scale()
	var shake := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * mag
	_place_camera(delta, shake)
	_decay_punch(delta)
	if not _modal_up and sim.result == "" and not sim.paused:
		# Cap the backlog: after a hitch, drop time instead of fast-forwarding.
		acc = minf(acc + delta, STEP * 5.0)
		var steps := 0
		while acc >= STEP and steps < 5 and not sim.paused and sim.result == "" and not _modal_up:
			sim.step(STEP, [_move()])
			_drain()
			acc -= STEP
			steps += 1
		_sync(clampf(acc / STEP, 0.0, 1.0))
	else:
		_drain()
		_sync(1.0)
	sparks.tick(delta)
	_tick_floats(delta)
	_hud()
	if threats != null:
		threats.queue_redraw()
	if not stick.active:
		stick.hint_left = maxf(0.0, stick.hint_left - delta)
		stick.hint = 1.0 if stick.hint_left > 0.35 else stick.hint_left / 0.35
	stick.queue_redraw()


func _place_camera(delta: float, shake: Vector2) -> void:
	var origin := Vector2.ZERO
	if cam != null and sim != null and sim.map != null:
		var hero_at := sim.play.get_center()
		if not sim.heroes.is_empty():
			hero_at = sim.heroes[0].pos
		cam.follow(hero_at, delta)
		stream.sync(sim.map, cam.view_rect())
		origin = cam.top_left()
	world.position = Vector2.ZERO
	if stage:
		stage.set_shake(shake)


func _move() -> Vector2:
	var want := Vector2.ZERO
	if drive.length() > 0.05:
		want = drive.normalized()
	elif stick.active:
		want = stick.vec
	else:
		if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
			want.x -= 1.0
		if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
			want.x += 1.0
		if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
			want.y -= 1.0
		if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
			want.y += 1.0
		if want.length() > 1.0:
			want = want.normalized()
	_stick_out = RunSim.ease_stick(_stick_out, want, STEP)
	return _stick_out


func _input(event: InputEvent) -> void:
	if sim == null or _modal_up:
		return
	var height := size.y if size.y > 1.0 else 1280.0
	var limit := height * 0.40
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		# The DODGE button owns its own taps; they never plant the stick.
		if touch.pressed and _in_dodge(touch.position):
			return
		if touch.pressed and touch.position.y > limit and finger < 0:
			finger = touch.index
			_begin_stick(touch.position)
		elif not touch.pressed and touch.index == finger:
			_end_stick()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if stick.active and drag.index == finger:
			_drag_stick(drag.position)
	elif event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index != MOUSE_BUTTON_LEFT:
			return
		if mouse.pressed and _in_dodge(mouse.position):
			return
		if mouse.pressed and mouse.position.y > limit:
			finger = -2
			_begin_stick(mouse.position)
		elif not mouse.pressed and finger == -2:
			_end_stick()
	elif event is InputEventMouseMotion and finger == -2 and stick.active:
		_drag_stick((event as InputEventMouseMotion).position)


func _in_dodge(at: Vector2) -> bool:
	return dodge_btn != null and dodge_btn.visible and Rect2(dodge_btn.position, dodge_btn.size).has_point(at)


## The DODGE tap: dash along the stick vector, or the hero's facing when idle.
## The sim owns the cooldown, the i-frames, and the obstacle slide.
func _try_dodge() -> void:
	if sim == null or _modal_up or sim.paused or sim.result != "":
		return
	if sim.heroes.is_empty():
		return
	var want := stick.vec if stick.active else Vector2.ZERO
	if drive.length() > 0.05:
		want = drive.normalized()
	sim.dodge(0, want)


func _begin_stick(at: Vector2) -> void:
	stick.active = true
	stick.origin = at
	stick.knob = at
	stick.vec = Vector2.ZERO
	finger_at = at
	stick.hint = 0.0
	stick.hint_left = 0.0
	stick.queue_redraw()


func _drag_stick(at: Vector2) -> void:
	finger_at = at
	stick.place(at)
	stick.queue_redraw()


func _end_stick() -> void:
	finger = -1
	stick.active = false
	stick.vec = Vector2.ZERO
	stick.queue_redraw()


func _hud() -> void:
	if sim.heroes.is_empty():
		return
	var hero: RunSim.Actor = sim.heroes[0]
	hp_meter.ratio = hero.hp / maxf(hero.max_hp, 1.0)
	xp_meter.ratio = float(sim.xp) / float(maxi(sim.xp_need, 1))
	var secs := int(sim.time)
	clock_label.text = "%d:%02d" % [secs / 60, secs % 60]
	level_label.text = str(sim.level)
	if level_badge.level != sim.level:
		level_badge.level = sim.level
		level_badge.queue_redraw()
	var show_boss := sim.phase == "boss"
	if show_boss != _boss_lit:
		_boss_lit = show_boss
		stage.boss_focus(show_boss)
	boss_meter.visible = show_boss and sim.boss != null
	boss_label.visible = show_boss and sim.boss != null
	boss_label.get_parent().visible = boss_label.visible
	if show_boss and sim.boss != null:
		boss_meter.ratio = sim.boss.hp / maxf(sim.boss.max_hp, 1.0)
		boss_label.text = sim.boss.display


func _drain() -> void:
	if sim == null:
		return
	for ev in sim.drain_events():
		if ev.has("shake"):
			trauma = minf(1.0, trauma + float(ev["shake"]))
		if ev.has("stop"):
			hitstop = minf(0.12, maxf(hitstop, float(ev["stop"])))
		match str(ev.get("type", "")):
			"hit":
				var amt := float(ev["amount"])
				var crit := bool(ev.get("crit", false))
				if amt < 99999.0:
					if round(amt) <= 0.0:
						_float(ev["pos"], "Blocked", Color("9a9a9a"), false, int(ev["id"]), amt, "hit")
					elif crit or not _merge_float(int(ev["id"]), amt):
						_float(ev["pos"], str(int(round(amt))) + ("!" if crit else ""), Color("ff8a2a") if crit else Color("fbf2de"), crit, int(ev["id"]), amt, "hit")
				_burst(ev["pos"], Color("ffe08a") if crit else Color("fff6ea"), 8 if crit else 5, 150.0)
				_punch[int(ev["id"])] = 0.16
				var struck := sim._actor_by_id(int(ev["id"]))
				var on_boss := struck != null and struck.kind == "boss"
				stage.hurt(int(ev["id"]), on_boss, crit or float(ev["amount"]) >= 40.0)
				if crit:
					AudioDirector.sfx("crit")
					AudioDirector.haptic("heavy")
				elif on_boss:
					AudioDirector.sfx("boss_hit")
					AudioDirector.haptic("heavy")
				else:
					AudioDirector.sfx("hit")
					AudioDirector.haptic("medium")
			"hero_hurt":
				var hdmg := float(ev["amount"])
				if round(hdmg) <= 0.0:
					_float(ev["pos"], "Blocked", Color("9a9a9a"), true, int(ev["id"]), hdmg, "hero")
				else:
					_float(ev["pos"], str(int(round(hdmg))), Color("ff6d6d"), true, int(ev["id"]), hdmg, "hero")
				var guard := sim._actor_by_id(int(ev["id"]))
				if guard != null and str(guard.role) == "tank" and guard.swing_t > 0.0:
					stage.guard_glint(guard.id)
				_punch[int(ev["id"])] = 0.14
				stage.hurt(int(ev["id"]))
				_hurt_flash()
				AudioDirector.sfx("hero_hurt")
				AudioDirector.haptic("heavy")
			"die":
				var info := Catalog.critter(str(ev.get("sprite", "")))
				var col := Color(str(info.get("color", "ffb070"))) if not info.is_empty() else Color("ffb070")
				_burst(ev["pos"], col, 12, 180.0)
				stage.died(int(ev["id"]), ev["pos"], str(ev.get("sprite", "")))
				AudioDirector.sfx("enemy_die")
			"boom":
				_burst(ev["pos"], Color("ffb15a"), 10, 160.0)
			"charge":
				stage.charge_fx(int(ev.get("id", -1)), ev["pos"], ev.get("to", ev["pos"]))
				_burst(ev.get("to", ev["pos"]), Color("c9ab7e"), 6, 150.0)
				AudioDirector.haptic("medium")
			"charge_land":
				stage.charge_land_fx(ev["pos"], float(ev.get("radius", 78.0)))
				_burst(ev["pos"], Color("d8e8ea"), 10, 190.0)
			"cleave":
				stage.cleave_fx(ev["pos"], float(ev.get("facing", 0.0)), float(ev.get("range", 120.0)), float(RunSim.ROLE_TUNING["tank"].get("cleave_arc", 160.0)), float(ev.get("stop", 0.04)) > 0.045)
				var tank := sim._actor_by_id(int(ev.get("id", -1)))
				if tank != null:
					var foe := sim.nearest_hostile(tank, float(ev.get("range", 120.0)) + 40.0)
					if foe != null:
						stage.lifesteal_fx(tank.id, foe.pos)
			"hitstop":
				hitstop = maxf(hitstop, float(ev.get("stop", 0.05)))
			# Gear loot (contract in docs/gear.md): run_sim emits gear_drop when
			# a piece hits the ground and gear_pickup when the hero takes it.
			"gear_drop":
				var it := GearDB.item(str(ev.get("item", "")))
				if not it.is_empty():
					stage.loot_beam(str(ev.get("key", ev["item"])), ev["pos"], int(it["tier"]))
					if int(it["tier"]) >= 3:
						AudioDirector.haptic("rare")
			"gear_pickup":
				var it2 := GearDB.item(str(ev.get("item", "")))
				if not it2.is_empty():
					var hp: Vector2 = sim.heroes[0].pos if not sim.heroes.is_empty() else ev["pos"]
					stage.loot_pickup(str(ev.get("key", ev["item"])), ev["pos"], int(it2["tier"]), hp)
					_float(ev["pos"] + Vector2(0, -40), str(it2["name"]), GearDB.TIER_COLORS[int(it2["tier"])].lightened(0.2), false)
					run_gear.append(str(ev["item"]))
					AudioDirector.sfx("chest_open")
			"loot":
				stage.loot_open(ev["pos"])
				_burst(ev["pos"], Color("ffd27a"), 18, 220.0)
				_float(ev["pos"], "+%d coins" % int(ev.get("coins", 0)), Color("ffd27a"), true)
				var sent := SaveGame.send_camp_chest(str(ev.get("tier", "common")), biome_id)
				_float(ev["pos"] + Vector2(0, -70), "Chest sent home" if sent == "sent" else "Chest drawer full", Color("f4e3b5") if sent == "sent" else Color("c98b7a"), false)
				AudioDirector.sfx("chest_open")
				AudioDirector.haptic("rare" if str(ev.get("tier", "")) == "rare" else "medium")
			"shrine":
				var sk := str(ev.get("kind", ""))
				_banner("Shrine of " + _shrine_word(sk))
				_burst(ev.get("pos", Vector2.ZERO), _shrine_color(sk), 24, 250.0)
				AudioDirector.sfx("levelup", -4.0)
				AudioDirector.haptic("light")
			"goblin_down":
				_banner("Treasure goblin slain!")
				_burst(ev.get("pos", Vector2.ZERO), Color("ffd27a"), 26, 280.0)
				AudioDirector.sfx("chest_open")
				AudioDirector.haptic("rare")
			"goblin_escape":
				_burst(ev.get("pos", Vector2.ZERO), Color("b7a06a"), 8, 120.0)
			"shield_break":
				_burst(ev.get("pos", Vector2.ZERO), Color("8fd0ff"), 12, 190.0)
				AudioDirector.sfx("hit", -2.0)
			"dodge":
				_burst(ev["pos"], Color("c9b79a"), 8, 140.0)
				AudioDirector.sfx("ui_tap", -6.0)
				AudioDirector.haptic("light")
			"aggro":
				AudioDirector.sfx("ui_tap", -8.0)
			"attack":
				_punch[int(ev["id"])] = 0.2
				stage.attack(int(ev["id"]))
				var who := sim._actor_by_id(int(ev["id"]))
				if who != null and who.kind == "hero":
					AudioDirector.sfx({"mage": "atk_mage", "archer": "atk_archer", "tank": "atk_tank"}.get(str(ev.get("role", who.role)), "atk_archer"))
				elif who != null and who.kind == "boss":
					AudioDirector.sfx("boss_slam")
					AudioDirector.haptic("medium")
				else:
					AudioDirector.sfx("atk_enemy")
			"windup":
				stage.windup(int(ev["id"]), float(ev.get("time", 0.4)))
				var winder := sim._actor_by_id(int(ev["id"]))
				if winder != null and winder.kind == "boss":
					AudioDirector.sfx("boss_windup")
			"gem":
				_burst(ev["pos"], Color("b6f27a"), 4, 90.0)
				AudioDirector.gem()
			"skill_up":
				var skill_key := str(ev.get("skill", ""))
				var skill_at := GearDB.SKILL_KEYS.find(skill_key)
				var skill_name := str(GearDB.SKILL_NAMES[skill_at]) if skill_at >= 0 else skill_key.capitalize()
				_banner("%s %d" % [skill_name, int(ev.get("level", 1))])
			"levelup":
				AudioDirector.sfx("levelup")
				AudioDirector.duck(-6.0, 0.8)
				AudioDirector.haptic("levelup")
				if not sim.heroes.is_empty():
					stage.celebrate(sim.heroes[0].id)
				_show_levelup(int(ev["level"]), ev["offer"])
			"boss_in":
				if boss_card != null:
					boss_card.present(str(ev["name"]), str(ev.get("title", "")))
				if cam != null and ev.has("pos"):
					cam.nudge(ev["pos"], RunSim.BOSS_INTRO)
				# The hunt loop hands over to the boss theme as it arrives.
				AudioDirector.music("boss", 1.0)
				AudioDirector.sfx("boss_roar")
				AudioDirector.duck(-9.0, 1.6, 1.2)
				AudioDirector.haptic("heavy")
				# Ground-shake when the boss slams down.
				get_tree().create_timer(Stage3D.BOSS_DROP_TIME).timeout.connect(func() -> void:
					trauma = minf(1.0, trauma + 0.75)
					hitstop = maxf(hitstop, 0.05)
					AudioDirector.sfx("boss_slam", 2.0)
					AudioDirector.haptic("heavy"))
			"boss_down":
				if not committed:
					committed = true
					if daily_pass:
						summary = SaveGame.commit_daily_pass(biome_id, str(ev["id"]))
					else:
						summary = SaveGame.commit_victory(biome_id, str(ev["id"]), sim.slain)
					if not is_daily:
						# Fixed-seed dailies are replayable, so they never bank gear.
						# Pieces still on the ground when the boss falls join the spoils.
						summary["gear"] = sim.bank_gear()
				AudioDirector.sfx("boss_die")
				AudioDirector.haptic("heavy")
				AudioDirector.sting(true)
				var reveal: Dictionary = summary.get("reveal", {})
				if reveal.is_empty():
					_show_victory(str(ev["name"]))
				else:
					_show_rare(reveal, str(ev["name"]))
			"hero_down":
				if not committed:
					committed = true
					SaveGame.commit_defeat(biome_id, sim.slain)
					if not is_daily:
						# A loss keeps half: the spoils show only what was banked.
						run_gear = sim.bank_gear()
				AudioDirector.sting(false)
				AudioDirector.haptic("heavy")
				# Let the fall read before the card covers it.
				var why := str(ev.get("reason", ""))
				get_tree().create_timer(0.2 if why == "time" else 1.3).timeout.connect(func() -> void:
					if is_inside_tree():
						_show_defeat(why))
			"revive":
				_banner("Second wind!")
				AudioDirector.sfx("levelup")
				AudioDirector.haptic("levelup")
			"banner":
				_banner(str(ev["text"]))
			"fx":
				var at: Vector2 = ev.get("pos", Vector2.ZERO)
				var col := _fx_color(str(ev.get("fx", "")))
				_burst(at, col, 8, 160.0)
				if ev.has("to"):
					var to: Vector2 = ev.get("to", at)
					_burst(at.lerp(to, 0.5), col, 5, 130.0)


func _sync(alpha: float) -> void:
	sync_alpha = alpha
	stage.sync_hunt(sim, alpha)
	stage.sync_fx(sim, alpha)
	_sync_pet(alpha)


func _actor_sprite(id: int, tex: Texture2D) -> Sprite2D:
	return _pooled(_actor_sprites, id, tex)


func _pooled(pool: Dictionary, id: int, tex: Texture2D) -> Sprite2D:
	if pool.has(id):
		var existing: Sprite2D = pool[id]
		existing.texture = tex
		return existing
	var sprite := Sprite2D.new()
	sprite.texture = tex
	sprite.centered = true
	actors_root.add_child(sprite)
	pool[id] = sprite
	return sprite


func _decay_punch(delta: float) -> void:
	for id in _punch.keys():
		_punch[id] = maxf(0.0, float(_punch[id]) - delta * 3.4)


func _burst(pos: Vector2, color: Color, count: int, speed: float) -> void:
	sparks.burst(pos, color, count, speed)


## Placeholder skill colours: one per fx name, unknown names fall back warm.
func _fx_color(name: String) -> Color:
	match name:
		"chain_lightning", "storm_crown":
			return Color("a9e5ff")
		"fire_trail", "meteor", "phoenix":
			return Color("ff7a3c")
		"frost_nova":
			return Color("9fe4ff")
		"orbiting_blades":
			return Color("e8eef7")
		"thorns_aura":
			return Color("7dff5a")
		"blink", "arcane_split":
			return Color("c9a8ff")
		"spirit_wolf":
			return Color("bfe9ff")
		"static_field":
			return Color("ffe14a")
		"gem_burst":
			return Color("b6f27a")
		"volley":
			return Color("f4f7ff")
		"hunter_mark":
			return Color("ffb15a")
		"earthquake":
			return Color("d0a060")
		"taunt_roar":
			return Color("ff9a6a")
		"vampiric_kill", "crit_siphon", "execute":
			return Color("ff5a6a")
		"ricochet":
			return Color("7ec8ff")
		"bulwark":
			return Color("8fd0ff")
		"berserk":
			return Color("ff8a3c")
		"affix_fast":
			return Color("ffd15a")
		"affix_shielded":
			return Color("8fd0ff")
		"affix_molten", "molten":
			return Color("ff7a3c")
		"affix_vampiric":
			return Color("ff5a6a")
		"goblin_spawn":
			return Color("ffd27a")
		_:
			return Color("ffe08a")


## Display word for a shrine kind (the banner reads "Shrine of Fury").
func _shrine_word(kind: String) -> String:
	match kind:
		"fury":
			return "Fury"
		"haste":
			return "Haste"
		"warding":
			return "Warding"
		"greed":
			return "Greed"
		_:
			return kind.capitalize()


func _shrine_color(kind: String) -> Color:
	match kind:
		"fury":
			return Color("ff7a5a")
		"haste":
			return Color("ffe14a")
		"warding":
			return Color("8fd0ff")
		"greed":
			return Color("b6f27a")
		_:
			return Color("ffe08a")


func _hurt_flash() -> void:
	flash_rect.color = Color(0.85, 0.08, 0.04, 0.5 * AudioDirector.flash_scale())
	var tw := create_tween()
	tw.tween_property(flash_rect, "color:a", 0.0, 0.28).set_ease(Tween.EASE_OUT)


func _banner(text: String) -> void:
	banner.text = text
	banner.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(0.85)
	tw.tween_property(banner, "modulate:a", 0.0, 0.35)


## Rapid non-crit hits on one target fold into a single rising number: any
## hit while a younger-than-0.45 s "hit" number is live (whatever the source:
## cleave, blades, chain lightning) tops it up instead of spawning a label.
## Crits, blocked tags and loot lines never absorb.
func _merge_float(id: int, amount: float) -> bool:
	if id < 0:
		return false
	for other in floats:
		if not other.visible:
			continue
		if int(other.get_meta("eid", -1)) != id:
			continue
		if str(other.get_meta("kind", "")) != "hit":
			continue
		if bool(other.get_meta("blocked", false)) or bool(other.get_meta("big", false)):
			continue
		if float(other.get_meta("life", 0.0)) <= 0.0 or float(other.get_meta("age", 0.0)) > 0.45:
			continue
		var total := float(other.get_meta("total", 0.0)) + amount
		other.set_meta("total", total)
		other.text = str(int(round(total)))
		other.set_meta("life", 0.75)
		other.set_meta("life_max", 0.75)
		other.set_meta("age", 0.0)
		other.reset_size()
		other.pivot_offset = other.size * 0.5
		_kill_tween(other, "pop")
		_kill_tween(other, "shrink")
		# Bigger totals sit a touch larger, but the bump is transient so a
		# long chain reads as one number breathing rather than inflating.
		var hold := Vector2.ONE * minf(1.0 + total / 500.0, 1.18)
		other.set_meta("hold", hold)
		other.scale = hold * 1.12
		var gt := create_tween()
		gt.tween_property(other, "scale", hold, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		other.set_meta("pop", gt)
		# Refresh the climb so the folded number keeps rising.
		var vel: Vector2 = other.get_meta("vel", Vector2(0.0, -120.0))
		other.set_meta("vel", Vector2(vel.x, minf(vel.y, -randf_range(150.0, 195.0))))
		_arm_shrink(other, 0.75)
		return true
	return false


## One floating label for a hit, a crit, hero damage, or a loot line (kind
## ""). Damage kinds run smaller and are spaced with jitter and rows.
func _float(pos: Vector2, text: String, color: Color, big: bool, id: int = -1, amount: float = 0.0, kind: String = "") -> void:
	# The damage-numbers setting hides hit and hurt digits; loot lines stay.
	if (kind == "hit" or kind == "hero") and not bool(AudioDirector.settings.get("damage_numbers", true)):
		return
	# Numbers anchor to their target: a hit landing off screen (a long
	# archer shot) shows nothing rather than being clamped into a corner
	# far from the fight.
	if kind != "" and stage != null and not get_viewport_rect().grow(-12.0).has_point(stage.project(pos)):
		return
	var label: Label = null
	for entry in floats:
		if not entry.visible:
			label = entry
			break
	if label == null:
		label = Label.new()
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		world.add_child(label)
		floats.append(label)
	# A pooled label may still carry tweens from its last life.
	_kill_tween(label, "pop")
	_kill_tween(label, "shrink")
	UiKit.ensure()
	label.visible = true
	label.text = text
	label.modulate = Color(1, 1, 1, 1)
	label.z_index = 1000
	label.add_theme_font_override("font", UiKit.font_n)
	label.set_meta("eid", id)
	label.set_meta("total", amount)
	label.set_meta("big", big)
	label.set_meta("kind", kind)
	var is_damage := kind != ""
	var crit := kind == "hit" and big
	var hero := kind == "hero"
	# A fully absorbed smack (armour, shield, i-frames, a 0-damage event) is
	# not "0", it is "Blocked"; it never folds into a damage number.
	var blocked: bool = is_damage and round(amount) <= 0.0
	var big_hit := kind == "hit" and not crit and amount >= 40.0
	label.set_meta("crit", crit)
	label.set_meta("blocked", blocked)
	label.set_meta("age", 0.0)
	# Damage numbers run smaller so a crowd of hits stays legible; coins and
	# banner texts keep the old display size.
	if blocked:
		label.add_theme_font_size_override("font_size", 34)
		label.add_theme_color_override("font_color", Color("9a9a9a"))
	elif crit:
		label.add_theme_font_size_override("font_size", 70)
		label.add_theme_color_override("font_color", Color("ffb028"))
	elif hero:
		label.add_theme_font_size_override("font_size", 44)
		label.add_theme_color_override("font_color", color)
	elif is_damage:
		label.add_theme_font_size_override("font_size", 38)
		label.add_theme_color_override("font_color", color)
	else:
		label.add_theme_font_size_override("font_size", 96 if big else 50)
		label.add_theme_color_override("font_color", color)
	# Dark warm keyline plus a soft cast shadow; kept thin so the smaller
	# combat numbers stay crisp instead of muddy. Crits swap in a darker
	# red-brown key and a faint ember glow; blocked tags sit flat grey.
	var outline := Color(0.04, 0.015, 0.01)
	if crit:
		outline = Color("5a1a0a")
	elif blocked:
		outline = Color(0.05, 0.05, 0.05)
	label.add_theme_color_override("font_outline_color", outline)
	if crit:
		label.add_theme_constant_override("outline_size", 14)
		label.add_theme_constant_override("shadow_outline_size", 12)
		label.add_theme_constant_override("shadow_offset_y", 4)
		label.add_theme_constant_override("shadow_offset_x", 2)
	elif blocked:
		label.add_theme_constant_override("outline_size", 6)
		label.add_theme_constant_override("shadow_outline_size", 4)
		label.add_theme_constant_override("shadow_offset_y", 2)
		label.add_theme_constant_override("shadow_offset_x", 1)
	elif is_damage:
		label.add_theme_constant_override("outline_size", 10)
		label.add_theme_constant_override("shadow_outline_size", 8)
		label.add_theme_constant_override("shadow_offset_y", 3)
		label.add_theme_constant_override("shadow_offset_x", 1)
	else:
		label.add_theme_constant_override("outline_size", 16 if big else 13)
		label.add_theme_constant_override("shadow_outline_size", 22 if big else 18)
		label.add_theme_constant_override("shadow_offset_y", 6)
		label.add_theme_constant_override("shadow_offset_x", 3)
	if crit:
		label.add_theme_color_override("font_shadow_color", Color(1.0, 0.5, 0.12, 0.5))
	else:
		label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.45 if is_damage else 0.5))
	label.reset_size()
	label.pivot_offset = label.size * 0.5
	# Pop in: crits start huge and crash down through 1.15x to settle at
	# 1.0x with an orange-to-gold flash, other hits just punch up from 1.5x.
	# A blocked tag lands flat: no pop, no tilt, it is only a note.
	var hold := Vector2.ONE * (1.15 if big_hit else 1.0)
	label.set_meta("hold", hold)
	if blocked:
		label.scale = Vector2.ONE
		label.rotation = 0.0
	else:
		label.scale = Vector2.ONE * (2.1 if crit else (1.9 if (not is_damage and big) else 1.5))
		label.rotation = randf_range(-0.12, 0.12) if crit else 0.0
		var pop := create_tween()
		if crit:
			label.modulate = Color(1.0, 0.55, 0.28, 1.0)
			pop.tween_property(label, "scale", Vector2.ONE * 1.15, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			pop.parallel().tween_property(label, "modulate", Color(1, 1, 1, 1), 0.18)
			pop.tween_property(label, "scale", Vector2.ONE, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		else:
			pop.tween_property(label, "scale", hold, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		label.set_meta("pop", pop)
	var at := _projected(pos)
	var row := 0
	var lift := Vector2.ZERO
	if blocked:
		# A short, flat note: it drifts up gently and fades fast.
		var bseq := int(_jitter.get(id, 0))
		_jitter[id] = bseq + 1
		row = _claim_row(label, at, label.size.y)
		var brow_h := maxf(label.size.y * 0.9, 1.0)
		lift = Vector2(0.0, -30.0 - brow_h * float(row)) - label.size * 0.5
		label.set_meta("vel", Vector2(randf_range(-14.0, 14.0), -randf_range(60.0, 90.0)))
		label.set_meta("delay", 0.0)
		label.set_meta("life", 0.5)
		label.set_meta("fade", 0.2)
	elif is_damage:
		# Alternating jitter per target: successive hits on one foe fan out
		# left and right instead of retracing the same pixels. The swing is
		# a touch wider than before so separate numbers never read as a
		# column, and each gets its own drift direction.
		var seq := int(_jitter.get(id, 0))
		_jitter[id] = seq + 1
		var side := 1.0 if seq % 2 == 0 else -1.0
		var jx := side * randf_range(24.0, 60.0)
		# Fixed rows climb at 0.9x the label height, capped at four; a fifth
		# number evicts the oldest, which then fades out quickly.
		row = _claim_row(label, at, label.size.y)
		var row_h := maxf(label.size.y * 0.9, 1.0)
		lift = Vector2(jx, -36.0 - row_h * float(row)) - label.size * 0.5
		var drift := side * randf_range(12.0, 48.0) + randf_range(-9.0, 9.0)
		label.set_meta("vel", Vector2(drift, -randf_range(185.0, 215.0)))
		label.set_meta("delay", 0.0)
		label.set_meta("life", 0.95 if crit else 0.75)
		label.set_meta("fade", 0.25)
		_arm_shrink(label, 0.95 if crit else 0.75)
	else:
		# Banner texts keep the old crowd-stack and toss.
		var stack := 0
		for other in floats:
			if other != label and other.visible and float(other.get_meta("life", 0.0)) > 0.5:
				if (other.position + other.size * 0.5).distance_to(at + Vector2(0, -36)) < 90.0:
					stack += 1
		lift = Vector2(randf_range(-42, 42) + (24.0 if stack % 2 == 1 else -24.0 if stack > 0 else 0.0), -36.0 - 44.0 * mini(stack, 3)) - label.size * 0.5
		label.set_meta("vel", Vector2(randf_range(-70.0, 70.0), -150.0 if big else -120.0))
		label.set_meta("delay", 0.06 * mini(stack, 3))
		label.set_meta("life", 0.85 if big else 0.7)
		label.set_meta("fade", 0.28)
	label.set_meta("life_max", float(label.get_meta("life")))
	label.set_meta("row", row)
	label.set_meta("base", at)
	label.set_meta("sim", pos)
	label.set_meta("lift", lift)
	var spawn := _keep_in_safe(label, at + lift)
	if is_damage:
		# Nudge a fresh number clear of any live one before it appears.
		spawn = _clear_rect(label, spawn)
		lift = spawn - at
		label.set_meta("lift", lift)
	label.position = _keep_in_safe(label, at + lift)


## Lowest free row of live numbers near a spawn point, so a volley climbs
## instead of overprinting; when all four rows are taken the oldest is cut
## short and its row reused.
func _claim_row(label: Label, at: Vector2, height: float) -> int:
	var used := {}
	var oldest: Label = null
	var oldest_life := 1e9
	var reach := maxf(height * 1.6, 64.0)
	for other in floats:
		if other == label or not other.visible:
			continue
		if float(other.get_meta("life", 0.0)) <= 0.0:
			continue
		var base: Vector2 = other.get_meta("base", other.position)
		if base.distance_to(at) > reach:
			continue
		used[int(other.get_meta("row", 0))] = true
		var life := float(other.get_meta("life", 0.0))
		if life < oldest_life:
			oldest_life = life
			oldest = other
	for r in 4:
		if not used.has(r):
			return r
	if oldest != null:
		oldest.set_meta("life", minf(oldest_life, 0.12))
		_kill_tween(oldest, "shrink")
		return int(oldest.get_meta("row", 0))
	return 0


## Nudge a fresh number until its rect clears every live one: sideways on
## alternating sides, then lifting a row after a couple of tries. Gives up
## after a handful so a crowd still spawns rather than stalling.
func _clear_rect(label: Label, want: Vector2) -> Vector2:
	var tries := 0
	while tries < 6 and _rect_blocked(label, want):
		var side := 1.0 if tries % 2 == 0 else -1.0
		want.x += side * randf_range(26.0, 54.0)
		if tries >= 2:
			want.y -= randf_range(18.0, 30.0)
		want = _keep_in_safe(label, want)
		tries += 1
	return want


## True when a label's spawn rect would overlap any other live number.
func _rect_blocked(label: Label, at: Vector2) -> bool:
	var rect := Rect2(at, label.size * label.scale).grow(2.0)
	for other in floats:
		if other == label or not other.visible:
			continue
		if float(other.get_meta("life", 0.0)) <= 0.0:
			continue
		if rect.intersects(Rect2(other.position, other.size * other.scale)):
			return true
	return false


## Fade-out shrink: a number eases down to 0.85x over its last 0.25 s.
func _arm_shrink(label: Label, life_max: float) -> void:
	var hold: Vector2 = label.get_meta("hold", Vector2.ONE)
	var st := create_tween()
	st.tween_interval(maxf(0.0, life_max - 0.25))
	st.tween_property(label, "scale", hold * 0.85, 0.25)
	label.set_meta("shrink", st)


func _kill_tween(label: Label, key: String) -> void:
	if not label.has_meta(key):
		return
	var tw := label.get_meta(key) as Tween
	if tw != null and tw.is_valid():
		tw.kill()


func _tick_floats(delta: float) -> void:
	for label in floats:
		if _modal_up and label.visible:
			label.visible = false
			continue
		if not label.visible:
			continue
		var delay := float(label.get_meta("delay", 0.0))
		if delay > 0.0:
			label.set_meta("delay", delay - delta)
			label.modulate.a = 0.0
			label.position = _projected(label.get_meta("sim")) + label.get_meta("lift")
			continue
		var life := float(label.get_meta("life")) - delta
		label.set_meta("life", life)
		# Age gates the rapid-hit fold: only a just-born number absorbs.
		label.set_meta("age", float(label.get_meta("age", 0.0)) + delta)
		var lift: Vector2 = label.get_meta("lift")
		var vel: Vector2 = label.get_meta("vel", Vector2(0, -48))
		vel.y += 300.0 * delta
		vel.x *= 1.0 - 2.5 * delta
		lift += vel * delta
		label.set_meta("vel", vel)
		label.set_meta("lift", lift)
		label.position = _keep_in_safe(label, _projected(label.get_meta("sim")) + lift)
		label.modulate.a = clampf(life / float(label.get_meta("fade", 0.28)), 0.0, 1.0)
		if life <= 0.0:
			label.visible = false


## Numbers never clip at the screen edge or slide under the notch / HUD:
## they are held inside the safe area with a margin.
func _keep_in_safe(label: Label, at: Vector2) -> Vector2:
	var ins := UiKit.safe_insets()
	var vp := get_viewport_rect().size
	var tl := world.get_global_transform().affine_inverse() * Vector2(float(ins["l"]) + 16.0, float(ins["t"]) + 170.0)
	var br := world.get_global_transform().affine_inverse() * Vector2(vp.x - float(ins["r"]) - 16.0, vp.y - float(ins["b"]) - 40.0)
	var sz := label.size * label.scale
	return Vector2(clampf(at.x, tl.x, maxf(tl.x, br.x - sz.x)), clampf(at.y, tl.y, maxf(tl.y, br.y - sz.y)))


func _projected(sim_pos: Vector2) -> Vector2:
	if stage == null:
		return sim_pos
	return world.to_local(stage.project(sim_pos))


func _clear_modal() -> void:
	while modal_box.get_child_count() > 0:
		var child := modal_box.get_child(0)
		modal_box.remove_child(child)
		child.free()


func _open_modal() -> void:
	_modal_up = true
	_end_stick()
	_clear_modal()
	modal.visible = true
	# Ease the dim in rather than snapping the whole frame dark.
	modal.modulate.a = 0.0
	create_tween().tween_property(modal, "modulate:a", 1.0, 0.16)


func _close_modal() -> void:
	_modal_up = false
	modal.visible = false
	_clear_modal()


func _show_levelup(level_n: int, offer: Array) -> void:
	_open_modal()
	var title := UiKit.title("LEVEL %d" % level_n, 44)
	modal_box.add_child(title)
	var sub := UiKit.label("Pick a blessing", 22, Color("ffe7b0"), "x", 4)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	modal_box.add_child(sub)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	modal_box.add_child(row)
	for i in offer.size():
		var card := _offer_card(i, str(offer[i]))
		row.add_child(card)
		# Staggered slam-in: each card flips edge-on to face while dropping
		# from slightly oversize, one after another.
		card.pivot_offset = Vector2(113, 240)
		card.scale = Vector2(0.06, 1.22)
		card.modulate.a = 0.0
		var tw := create_tween()
		tw.tween_interval(0.12 * float(i))
		tw.tween_callback(AudioDirector.sfx.bind("card_flip", 0.0, 1.0 + 0.06 * i))
		tw.tween_property(card, "modulate:a", 1.0, 0.06)
		tw.tween_property(card, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _offer_card(index: int, id: String) -> Button:
	var info := Catalog.card(id)
	var rarity := str(info.get("rarity", "common"))
	var have := int(sim.stacks.get(id, 0)) if sim != null else 0
	var rank := have + 1
	var stack := bool(info.get("stack", false))
	var button := OfferCard.new()
	button.rarity = rarity
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(226, 480)
	button.pressed.connect(_pick.bind(index))
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 4)
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 16
	box.offset_right = -16
	box.offset_top = 18
	box.offset_bottom = -18
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	button.add_child(box)
	var ribbon := UiKit.label(Catalog.rarity_name(rarity).to_upper(), 15, UiKit.rarity_colors(rarity)["lip"], "x", 3)
	ribbon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ribbon.custom_minimum_size = Vector2(0, 32)
	box.add_child(ribbon)
	var icon := CardIcon.new()
	icon.op = str(info.get("op", ""))
	icon.rarity = rarity
	icon.custom_minimum_size = Vector2(0, 214)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(icon)
	var name := UiKit.label(str(info.get("name", id)), 28, UiKit.GOLD.lightened(0.2), "x", 3)
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name.autowrap_mode = TextServer.AUTOWRAP_OFF
	name.clip_text = true
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(name)
	var desc := UiKit.label(Catalog.card_text(id, have), 26, UiKit.MUTED.lightened(0.3), "m", 3)
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.max_lines_visible = 3
	box.add_child(desc)
	if stack and rank >= 2:
		# Rank badge: this pick's numeral on a forged medallion pinned to the
		# card's top-right corner, clear of the rarity ribbon (rank I bare).
		var badge := RankMedallion.new()
		badge.numeral = _roman(rank)
		badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		badge.offset_left = -66.0
		badge.offset_right = -10.0
		badge.offset_top = 10.0
		badge.offset_bottom = 66.0
		button.add_child(badge)
	button.resized.connect(_fit_card.bind(button, name, desc))
	_fit_card(button, name, desc)
	return button


## Names stay on one line: the display face steps down until the line fits,
## never wrapping. Descriptions cap at three lines, the body face easing
## down a little when a longer line would spill over.
func _fit_card(button: Button, name: Label, desc: Label) -> void:
	var width := button.size.x
	if width <= 1.0:
		width = button.custom_minimum_size.x
	width = maxf(90.0, width - 34.0)
	var base := int(name.get_meta("base_size", 28))
	name.set_meta("base_size", base)
	var nf: Font = name.get_theme_font("font")
	if nf != null:
		var px := base
		while px > int(round(float(base) * 0.7)) and nf.get_string_size(name.text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x > width:
			px -= 1
		name.add_theme_font_size_override("font_size", px)
	var dbase := int(desc.get_meta("base_size", 26))
	desc.set_meta("base_size", dbase)
	var df: Font = desc.get_theme_font("font")
	if df == null:
		return
	var px2 := dbase
	var floor_px := int(round(float(dbase) * 0.82))
	while px2 > floor_px:
		var tall := df.get_multiline_string_size(desc.text, HORIZONTAL_ALIGNMENT_CENTER, width, px2, -1, TextServer.BREAK_WORD_BOUND | TextServer.BREAK_MANDATORY).y
		var lines := int(round(tall / maxf(df.get_height(px2), 1.0)))
		if lines <= 3:
			break
		px2 -= 1
	desc.add_theme_font_size_override("font_size", px2)


## Roman numeral for a card rank badge, capped at X.
static func _roman(n: int) -> String:
	var value := clampi(n, 1, 10)
	var vals := [10, 9, 5, 4, 1]
	var syms := ["X", "IX", "V", "IV", "I"]
	var out := ""
	for i in vals.size():
		while value >= int(vals[i]):
			out += str(syms[i])
			value -= int(vals[i])
	return out


func _pick(index: int) -> void:
	if sim == null:
		return
	var nxt: Array = sim.choose(index)
	AudioDirector.sfx("card_pick")
	AudioDirector.haptic("medium")
	if nxt.is_empty():
		_close_modal()
	else:
		_show_levelup(sim.level, nxt)


func _mount_pet() -> void:
	var pet_id := SaveGame.active_pet()
	if pet_id == "":
		return
	var drop := Catalog.drop_by_id(pet_id)
	pet_follow = str(drop.get("sprite", "thistle"))


func _sync_pet(alpha: float) -> void:
	if pet_follow == "" or sim == null or sim.heroes.is_empty() or stage == null:
		return
	var hero: RunSim.Actor = sim.heroes[0]
	var pos: Vector2 = hero.prev.lerp(hero.pos, alpha)
	var behind := -46.0 if cos(hero.facing) < 0.0 else 46.0
	var goal := pos + Vector2(behind, 22.0)
	if not pet_ready:
		pet_pos = goal
		pet_ready = true
	pet_pos = pet_pos.lerp(goal, 0.2)
	stage.sync_pet(pet_follow, pet_pos, hero.facing, hero.vel.length() > 20.0)


func _show_rare(drop: Dictionary, boss_name: String) -> void:
	_open_modal()
	var beam := GoldBeam.new()
	beam.set_anchors_preset(Control.PRESET_FULL_RECT)
	beam.mouse_filter = Control.MOUSE_FILTER_IGNORE
	modal.add_child(beam)
	modal.move_child(beam, 1)
	var kind := "BOSS PET" if str(drop.get("kind", "")) == "pet" else "VERY RARE"
	var title := UiKit.title(kind, 48)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	modal_box.add_child(title)
	var sprite_id := str(drop.get("sprite", ""))
	if sprite_id != "":
		var face := portrait(sprite_id, 200)
		face.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		modal_box.add_child(face)
	var name := UiKit.label(str(drop.get("name", "Drop")), 32, Color("ffe08a"), "x", 6)
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	modal_box.add_child(name)
	var sub := UiKit.label("%s dropped something rare." % boss_name, 20, Color("ffe7b0"), "x", 4)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	modal_box.add_child(sub)
	var button := UiKit.button("LOVELY", 420, 80)
	button.pressed.connect(func() -> void:
		if is_instance_valid(beam):
			beam.queue_free()
		_show_victory(boss_name)
	)
	modal_box.add_child(button)
	AudioDirector.sfx("rare_chime")
	AudioDirector.sfx("sparkle")
	AudioDirector.duck(-10.0, 1.2, 1.5)
	AudioDirector.haptic("rare")


## A forged end-of-hunt panel with a crest on top. Returns the inner column.
func _end_panel(win: bool) -> VBoxContainer:
	for f in floats:
		f.visible = false
	for c in modal.get_children():
		if c is GoldBeam:
			c.queue_free()
	var crest := EndCrest.new()
	crest.win = win
	crest.custom_minimum_size = Vector2(0, 210)
	modal_box.add_child(crest)
	var plate := UiKit.Plate.new()
	plate.kind = "panel"
	plate.pad = 30
	plate.glow = Color(1.0, 0.72, 0.3, 0.4) if win else Color(0.8, 0.12, 0.08, 0.35)
	plate.custom_minimum_size = Vector2(720, 0)
	plate.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	modal_box.add_child(plate)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 16)
	plate.add_child(col)
	plate.pivot_offset = Vector2(360, 200)
	plate.scale = Vector2(0.85, 0.85)
	plate.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(plate, "modulate:a", 1.0, 0.2)
	tw.parallel().tween_property(plate, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return col


## One big hero stat line: the hero's name over its run in a single
## bold read (foes slain, time, level), rather than three small tiles.
func _end_stats() -> VBoxContainer:
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 0)
	var t := int(sim.time) if sim else 0
	var who := UiKit.label(str(Catalog.critter(hero_id).get("name", "Hero")).to_upper(), 20, UiKit.MUTED.lightened(0.1), "x", 3)
	who.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(who)
	var big := UiKit.label("%d SLAIN  ·  %d:%02d  ·  LV %d" % [sim.slain if sim else 0, t / 60, t % 60, sim.level if sim else 1], 44, UiKit.CREAM, "x", 4)
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(big)
	return v


## The chest that comes home: its baked icon, rarity and unlock time, and
## where it went (the Home chest slots), or a Clash-style notice when every
## slot was taken.
func _end_chest(win: bool) -> Control:
	var info: Dictionary = SaveGame.last_chest
	var tone := str(info.get("tone", "silver" if win else "wood"))
	var rarity := str(info.get("rarity", "rare" if win else "common"))
	var full := bool(info.get("full", false))
	var plate := UiKit.Plate.new()
	plate.kind = "plaque"
	plate.pad = 14
	plate.glow = Color(UiKit.rarity_colors(rarity)["glow"], 0.55)
	plate.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	plate.add_child(row)
	var icon := TextureRect.new()
	icon.texture = SpriteBank._load("res://assets/sprites/chests/%s.png" % tone, "chest_" + tone)
	icon.custom_minimum_size = Vector2(136, 136)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if full:
		icon.modulate = Color(0.45, 0.42, 0.4)
	row.add_child(icon)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 2)
	row.add_child(v)
	var kind := "HUNT CHEST" if win else "SMALL POUCH"
	v.add_child(UiKit.label("%s CHEST EARNED" % rarity.to_upper() if win else "%s POUCH EARNED" % rarity.to_upper(), 24, UiKit.rarity_colors(rarity)["glow"].lightened(0.25), "x", 3))
	if full:
		v.add_child(UiKit.label("Chest slots full!", 26, Color("ff8a6a"), "x", 3))
		v.add_child(UiKit.label("Open a chest to make room next time.", 19, UiKit.MUTED.lightened(0.15), "b", 2))
	else:
		v.add_child(UiKit.label("Sent to your chest slots", 26, UiKit.CREAM, "x", 3))
		v.add_child(UiKit.label("Unlock time %s · tap it on Home" % SaveGame.span(int(SaveGame.UNLOCK_SECONDS.get(rarity, 3600))), 19, UiKit.MUTED.lightened(0.15), "b", 2))
	plate.tooltip_text = kind
	return plate


## Score and record a finished daily once, then hold the entry for the panel.
func _daily_result(win: bool) -> void:
	if not is_daily or daily_recorded:
		return
	daily_recorded = true
	var hp := 0.0
	var max_hp := 1.0
	if not sim.heroes.is_empty():
		hp = sim.heroes[0].hp
		max_hp = sim.heroes[0].max_hp
	var entry := {
		"score": Daily.score({
			"win": win, "time": sim.time, "kills": sim.slain,
			"level": sim.level, "hp": hp, "max_hp": max_hp,
		}),
		"hero": hero_id,
		"time": int(sim.time),
		"result": "win" if win else "loss",
		"at": int(Time.get_unix_time_from_system()),
	}
	entry["rank"] = SaveGame.record_daily(daily_key, entry)
	SaveGame.daily_submit(daily_key, entry)
	daily_entry = entry


## The daily read on the end panel: today's score and local rank.
func _daily_line() -> Control:
	var plate := UiKit.Plate.new()
	plate.kind = "plaque"
	plate.pad = 12
	plate.glow = Color(UiKit.GOLD, 0.45)
	plate.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 2)
	plate.add_child(v)
	v.add_child(UiKit.label("DAILY CHALLENGE · %s" % daily_key, 18, UiKit.MUTED.lightened(0.2), "x", 2))
	var score := UiKit.label("Daily score %d" % int(daily_entry.get("score", 0)), 34, UiKit.GOLD.lightened(0.25), "x", 3)
	score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(score)
	var rank := UiKit.label("Rank #%d today" % int(daily_entry.get("rank", 0)), 22, UiKit.CREAM, "x", 2)
	rank.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(rank)
	return plate


## Gear earned this run: pickups seen in hunt plus anything the save layer
## reports in summary["gear"] (deduped by occurrence, not by id).
func _spoils() -> Array:
	var out: Array = run_gear.duplicate()
	for id in summary.get("gear", []):
		if not (str(id) in run_gear):
			out.append(str(id))
	for id in OS.get_environment("CC_DEMO_SPOILS").split(",", false):
		if not (id in out):
			out.append(id)
	return out


func _show_victory(boss_name: String) -> void:
	_daily_result(true)
	_open_modal()
	var col := _end_panel(true)
	var title := UiKit.title("VICTORY", 64)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var sub := UiKit.label("%s has fallen." % boss_name, 24, UiKit.MUTED.lightened(0.2), "m", 2)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(sub)
	var rule := GiltRule.new()
	rule.custom_minimum_size = Vector2(0, 18)
	col.add_child(rule)
	var drops: Array = summary.get("drops", [])
	if not drops.is_empty():
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 12)
		col.add_child(row)
		for drop in drops:
			var tag := UiKit.Plate.new()
			tag.kind = "card"
			tag.pad = 10
			# Rarity frame: the tag glows in the drop's rarity colour.
			var rar := str(drop.get("rarity", "rare"))
			tag.glow = Color(UiKit.rarity_colors(rar)["glow"], 0.75)
			tag.custom_minimum_size = Vector2(200, 0)
			var dv := VBoxContainer.new()
			dv.add_theme_constant_override("separation", 2)
			tag.add_child(dv)
			var ico := TextureRect.new()
			var did := str(drop.get("id", ""))
			if str(drop.get("kind", "")) == "pet" and str(drop.get("sprite", "")) != "":
				ico.texture = SpriteBank.head(str(drop["sprite"]))
			else:
				ico.texture = SpriteBank._load("res://assets/sprites/items/%s.png" % did, did)
			ico.custom_minimum_size = Vector2(124, 124)
			ico.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			ico.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			dv.add_child(ico)
			var line := UiKit.label(str(drop.get("name", "Drop")), 18, UiKit.GOLD.lightened(0.2), "x", 2)
			line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			dv.add_child(line)
			row.add_child(tag)
	var spoils := EquipUI.loot_reveal(_spoils())
	if spoils != null:
		col.add_child(spoils)
	col.add_child(_end_stats())
	if is_daily:
		col.add_child(_daily_line())
	if daily_pass:
		# The daily is a taste of a sealed biome, not a clear: make that read.
		var pass_note := UiKit.label("Daily pass · playable today only", 20, UiKit.MUTED.lightened(0.15), "m", 2)
		pass_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(pass_note)
	else:
		var prize := HBoxContainer.new()
		prize.alignment = BoxContainer.ALIGNMENT_CENTER
		prize.add_theme_constant_override("separation", 10)
		var cup := TextureRect.new()
		cup.texture = UiKit.icon("trophy")
		cup.custom_minimum_size = Vector2(46, 46)
		cup.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		cup.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		cup.modulate = UiKit.GOLD
		prize.add_child(cup)
		var trophies := UiKit.label("+%d" % int(summary.get("trophies", 0)), 40, UiKit.GOLD.lightened(0.25), "x", 3)
		prize.add_child(trophies)
		col.add_child(prize)
	col.add_child(_end_chest(true))
	var button := UiKit.button("CONTINUE", 660, 104, "gold")
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(func() -> void: go("home"))
	col.add_child(button)


func _show_defeat(reason: String) -> void:
	_daily_result(false)
	_open_modal()
	var col := _end_panel(false)
	var title := UiKit.title("DEFEATED", 60)
	title.add_theme_color_override("font_color", Color("d8a090"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var line := "The wilds outlasted you." if reason == "time" else "The wilds were too much this time."
	var sub := UiKit.label(line, 24, UiKit.MUTED.lightened(0.2), "m", 2)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(sub)
	var hint := UiKit.label("Level your heroes with cards and gear, then return.", 19, UiKit.MUTED, "m", 2)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var spoils := EquipUI.loot_reveal(_spoils())
	if spoils != null:
		col.add_child(spoils)
	col.add_child(_end_stats())
	if is_daily:
		col.add_child(_daily_line())
	col.add_child(_end_chest(false))
	col.add_child(hint)
	var button := UiKit.button("CONTINUE", 660, 104, "steel")
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(func() -> void: go("home"))
	col.add_child(button)
	var again := UiKit.secondary("TRY AGAIN", 300, 64)
	again.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	# A daily retries the same seeded hunt; a normal run rolls a fresh map.
	again.pressed.connect(func() -> void: go("run", run_args if is_daily else {"biome": biome_id, "hero": hero_id}))
	col.add_child(again)


func _pause() -> void:
	if _modal_up or sim == null or sim.result != "":
		return
	_open_modal()
	var title := UiKit.title("PAUSED", 52)
	modal_box.add_child(title)
	var resume := UiKit.confirm("RESUME", 420, 84)
	resume.pressed.connect(_close_modal)
	modal_box.add_child(resume)
	var leave := UiKit.danger("LEAVE HUNT", 420, 72)
	leave.pressed.connect(func() -> void: go("home"))
	modal_box.add_child(leave)
	var panel := SettingsPanel.new()
	panel.custom_minimum_size = Vector2(640, 0)
	modal_box.add_child(panel)


## A level-up blessing: a forged card in its rarity's metal over dark leather,
## with a soft aura and a press bounce.
## Crest over the end panel: crossed blades behind a gilded (victory) or
## blackened (defeat) shield with a crown or a skull.
class GiltRule extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)

	func _draw() -> void:
		var c := size * 0.5
		var gold := Color("c8963a")
		var clear := Color(gold, 0.0)
		for side in [-1.0, 1.0]:
			var a := c + Vector2(side * 16.0, 0)
			var b := c + Vector2(side * size.x * 0.4, 0)
			draw_polygon(PackedVector2Array([a + Vector2(0, -1.5), b + Vector2(0, -0.5), b + Vector2(0, 0.5), a + Vector2(0, 1.5)]), PackedColorArray([gold, clear, clear, gold]))
		draw_colored_polygon(PackedVector2Array([c + Vector2(0, -7), c + Vector2(9, 0), c + Vector2(0, 7), c + Vector2(-9, 0)]), Color("f0d08a"))


class EndCrest extends Control:
	var win := true
	var t := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()

	func _draw() -> void:
		var c := Vector2(size.x * 0.5, size.y * 0.55)
		var glow := Color(1.0, 0.75, 0.35) if win else Color(0.85, 0.15, 0.1)
		if win:
			# Slow-turning gilt rays behind the shield.
			for i in 16:
				var a := TAU * i / 16.0 + t * 0.15
				var a2 := a + 0.09
				var far := 190.0
				var clear := Color(1.0, 0.82, 0.45, 0.0)
				draw_polygon(PackedVector2Array([c, c + Vector2.from_angle(a) * far, c + Vector2.from_angle(a2) * far]),
					PackedColorArray([Color(1.0, 0.82, 0.45, 0.22), clear, clear]))
		else:
			# Embers drifting up off a dying fire.
			for i in 14:
				var x := c.x + sin(i * 12.9) * 150.0 + sin(t + i) * 8.0
				var y := c.y + 70.0 - fmod(t * (24.0 + i % 4 * 8.0) + i * 31.0, 180.0)
				draw_circle(Vector2(x, y), 2.0 + float(i % 3), Color(1.0, 0.45, 0.15, 0.5 * clampf((y - c.y + 110.0) / 180.0, 0.0, 1.0)))
		for k in 12:
			draw_circle(c, 120.0 - k * 7.0, Color(glow, 0.018 + 0.006 * sin(t * 2.0)))
		var steel := Color("cfd4da") if win else Color("6a6460")
		for side in [-1.0, 1.0]:
			var a := Vector2(c.x - side * 110.0, c.y + 50.0)
			var b := Vector2(c.x + side * 110.0, c.y - 60.0)
			draw_line(a, b, Color("120a04"), 14.0, true)
			draw_line(a, b, steel, 8.0, true)
			draw_line(a + (b - a) * 0.12 + Vector2(0, -16).rotated(side * 0.5), a + (b - a) * 0.12 + Vector2(0, 16).rotated(side * 0.5), Color("c8963a"), 8.0, true)
		var w := 64.0
		var pts := PackedVector2Array([c + Vector2(-w, -w * 0.9), c + Vector2(w, -w * 0.9), c + Vector2(w * 0.95, w * 0.15), c + Vector2(0, w * 1.05), c + Vector2(-w * 0.95, w * 0.15)])
		var outer := PackedVector2Array()
		for p in pts:
			outer.append(c + (p - c) * 1.14)
		draw_colored_polygon(outer, Color("120a04"))
		var metal_hi := Color("ffe6a8") if win else Color("8a7a70")
		var metal_lo := Color("6a4416") if win else Color("2a2220")
		draw_polygon(outer, PackedColorArray([metal_hi, metal_hi, metal_lo, metal_lo, metal_lo]))
		var face_hi := Color("8a2620") if win else Color("2a2422")
		var face_lo := Color("3a0c0a") if win else Color("100c0a")
		draw_polygon(pts, PackedColorArray([face_hi, face_hi, face_lo, face_lo, face_lo]))
		var ico := UiKit.icon("crown_a" if win else "skull")
		if ico != null:
			UiKit.draw_icon(self, ico, Rect2(c - Vector2(34, 40), Vector2(68, 68)), Color("f0d08a") if win else Color("d8c8b8"), Color("120a04"), 3.0)


## A small forged rank medallion: a bronze-rimmed disc with the pick's
## numeral stamped in gold, pinned to the card's top-right corner.
class RankMedallion extends Control:
	var numeral := "II"

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)

	func _draw() -> void:
		UiKit.ensure()
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5 - 3.0
		var hi := Color("f0d18e")
		var lo := Color("5a3814")
		# Cast shadow, dark bezel, then a cast-bronze band lit from the top left.
		draw_circle(c + Vector2(0, 3), r + 1.0, Color(0, 0, 0, 0.5))
		draw_circle(c, r + 1.0, Color("120a04"))
		for k in 24:
			var a0 := TAU * float(k) / 24.0
			var lit := 0.5 + 0.5 * cos(a0 + 2.36)
			draw_arc(c, r - 3.0, a0, a0 + TAU / 24.0 + 0.01, 3, lo.lerp(hi, lit), 6.0, true)
		# Engraved inner bevel over a dark seat, then a domed enamel face.
		draw_arc(c, r - 6.5, 0.0, TAU, 32, Color(1.0, 0.88, 0.6, 0.5), 1.2, true)
		draw_circle(c, r - 7.0, Color("0a0605"))
		for k in 6:
			draw_circle(c + Vector2(-float(k) * 0.4, -float(k) * 0.6), r - 7.0 - float(k) * 1.2, Color("2a1c12").lightened(float(k) * 0.05))
		# The rank numeral, stamped in gold.
		var font: Font = UiKit.font_x
		var px := int(r * 0.95)
		var ascent := font.get_ascent(px)
		var descent := font.get_descent(px)
		var w := font.get_string_size(numeral, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
		var at := Vector2(c.x - w * 0.5, c.y + (ascent - descent) * 0.5)
		UiKit.draw_text(self, font, at, numeral, px, Color("ffe6a8"), Color("120a04"), 3)


class OfferCard extends Button:
	var rarity := "common"
	var frame: UiKit.Frame

	func _ready() -> void:
		focus_mode = Control.FOCUS_NONE
		var empty := StyleBoxEmpty.new()
		for state in ["normal", "hover", "pressed", "focus", "disabled"]:
			add_theme_stylebox_override(state, empty)
		var cols: Dictionary = UiKit.rarity_colors(rarity)
		var metal := UiKit.rarity_metal(rarity)
		frame = UiKit.Frame.new("card", "leather", {
			"metal_hi": Color(metal[0]).lightened(0.3), "metal_lo": Color(metal[1]).lightened(0.18), "studs": 1.0, "frame": 8.0,
			"glow_color": Color(cols["glow"], 0.45 if rarity != "common" else 0.15),
			"face_top": Color(cols["bg"]).lerp(Color("1c1510"), 0.35), "face_bot": Color("0c0907"),
		})
		frame.margin = 4.0
		add_child(frame)
		if rarity in ["epic", "legendary"]:
			# Epic glow breathes: a slow brightness pulse on the frame.
			var pulse := create_tween().set_loops()
			pulse.tween_property(frame, "modulate", Color(1.3, 1.18, 1.4), 0.7).set_trans(Tween.TRANS_SINE)
			pulse.tween_property(frame, "modulate", Color(1, 1, 1), 0.7).set_trans(Tween.TRANS_SINE)
		button_down.connect(func() -> void:
			pivot_offset = size * 0.5
			create_tween().tween_property(self, "scale", Vector2(0.95, 0.95), 0.06))
		button_up.connect(func() -> void:
			create_tween().tween_property(self, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT))


class CardIcon extends Control:
	var op := ""

	var rarity := "common"
	var _shadow := false
	## True for the off-screen copy that only paints the glyph into a
	## texture for the sculpting shader.
	var glyph_only := false
	var _sculpt: TextureRect

	const SCULPT := """shader_type canvas_item;
uniform vec3 metal_hi = vec3(1.0, 0.86, 0.55);
uniform vec3 metal_lo = vec3(0.36, 0.22, 0.08);
uniform float px = 0.00390625;
#define A(p) texture(TEXTURE, p).a
void fragment() {
	vec2 uv = UV;
	vec4 g = texture(TEXTURE, uv);
	// Bevel normal from the glyph's own alpha: a soft gradient across a few
	// pixels of its edge, lit from the top left like the rest of the UI.
	float r = 3.5 * px;
	float dx = A(uv + vec2(r, 0.0)) - A(uv - vec2(r, 0.0)) + 0.5 * (A(uv + vec2(r, r)) - A(uv - vec2(r, r)) + A(uv + vec2(r, -r)) - A(uv - vec2(r, -r)));
	float dy = A(uv + vec2(0.0, r)) - A(uv - vec2(0.0, r)) + 0.5 * (A(uv + vec2(r, r)) - A(uv - vec2(r, r)) + A(uv + vec2(-r, r)) - A(uv - vec2(-r, r)));
	vec3 n = normalize(vec3(-dx, -dy, 0.55));
	vec3 L = normalize(vec3(-0.55, -0.6, 0.6));
	float diff = clamp(dot(n, L), 0.0, 1.0);
	float spec = pow(clamp(dot(reflect(-L, n), vec3(0.0, 0.0, 1.0)), 0.0, 1.0), 22.0);
	// Metal rim band: where the glyph is present but its eroded copy is not.
	float e = 6.0 * px;
	float inner = min(min(A(uv + vec2(e, 0.0)), A(uv - vec2(e, 0.0))), min(A(uv + vec2(0.0, e)), A(uv - vec2(0.0, e))));
	inner = min(inner, min(min(A(uv + vec2(e, e) * 0.7), A(uv - vec2(e, e) * 0.7)), min(A(uv + vec2(e, -e) * 0.7), A(uv - vec2(e, -e) * 0.7))));
	float edge = clamp(g.a - inner, 0.0, 1.0);
	vec3 base0 = g.rgb / max(g.a, 0.001);
	// The rim takes some of the glyph's hue, so thin strokes (all rim)
	// keep their colour identity as tinted metal.
	vec3 metal = mix(metal_lo, metal_hi, diff) * mix(vec3(1.0), base0 * 1.25, 0.45) + spec * 0.85;
	// Enamel inlay: the glyph's colour, deepened, domed and glossy.
	vec3 base = g.rgb / max(g.a, 0.001);
	vec3 enamel = base * base * (0.7 + 0.5 * diff) + vec3(spec * 0.55);
	enamel += vec3(0.16) * smoothstep(0.55, 0.15, uv.y) * inner;
	vec3 col = mix(enamel, metal, smoothstep(0.1, 0.55, edge));
	// Cast shadow down and to the right.
	float sh = A(uv - vec2(3.0, 6.0) * px);
	vec4 shadow = vec4(0.0, 0.0, 0.0, 0.6 * sh);
	COLOR = mix(shadow, vec4(col, 1.0), g.a);
}
"""

	func _ready() -> void:
		if glyph_only:
			return
		# Paint the glyph once at 2x into a texture, then show it through
		# the sculpting shader: enamel inlay set in a bevelled metal rim.
		var vp := SubViewport.new()
		vp.size = Vector2i(256, 256)
		vp.transparent_bg = true
		vp.disable_3d = true
		vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		var painter := CardIcon.new()
		painter.glyph_only = true
		painter.op = op
		painter.rarity = rarity
		painter.size = Vector2(256, 256)
		vp.add_child(painter)
		add_child(vp)
		_sculpt = TextureRect.new()
		_sculpt.texture = vp.get_texture()
		_sculpt.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_sculpt.stretch_mode = TextureRect.STRETCH_SCALE
		_sculpt.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sh := Shader.new()
		sh.code = SCULPT
		var mat := ShaderMaterial.new()
		mat.shader = sh
		var metal := UiKit.rarity_metal(rarity)
		mat.set_shader_parameter("metal_hi", Vector3(metal[0].r, metal[0].g, metal[0].b))
		mat.set_shader_parameter("metal_lo", Vector3(metal[1].r, metal[1].g, metal[1].b) * 0.7)
		_sculpt.material = mat
		add_child(_sculpt)
		resized.connect(_place)
		_place()

	func _place() -> void:
		if _sculpt:
			_sculpt.size = Vector2(128, 128)
			_sculpt.position = size * 0.5 - Vector2(64, 64)

	func _draw() -> void:
		if glyph_only:
			var gc := size * 0.5
			var gs := 2.84
			draw_set_transform(gc - gc * gs, 0.0, Vector2(gs, gs))
			_glyphs(gc)
			draw_set_transform(Vector2.ZERO)
			return
		var c := Vector2(size.x * 0.5, size.y * 0.5)
		var metal := UiKit.rarity_metal(rarity)
		var glow: Color = UiKit.rarity_colors(rarity)["glow"]
		var rank := {"common": 0, "rare": 1, "epic": 2, "legendary": 3}.get(rarity, 0) as int
		# Sunburst behind the medallion: bronze for commons, brighter and
		# denser with rarity.
		var rays := 12 + rank * 4
		var ray_col := Color(glow, 0.4 + rank * 0.08) if rank > 0 else Color(0.95, 0.68, 0.36, 0.38)
		for i in rays:
			var ang := TAU * i / float(rays) - PI * 0.5
			var far := 84.0 if i % 2 == 0 else 70.0
			draw_polygon(PackedVector2Array([c, c + Vector2.from_angle(ang - 0.07) * far, c + Vector2.from_angle(ang + 0.07) * far]),
				PackedColorArray([ray_col, Color(ray_col, 0.0), Color(ray_col, 0.0)]))
		for k in 8:
			draw_circle(c, 70.0 - k * 3.0, Color(glow if rank > 0 else Color(0.9, 0.62, 0.3), 0.03))
		# Forged ring: drop shadow, dark bezel, two-tone metal with a lit
		# upper arc, engraved ticks, and four rivets.
		draw_circle(c + Vector2(0, 6), 62, Color(0, 0, 0, 0.6))
		draw_circle(c, 61, Color("120a04"))
		draw_arc(c, 56, 0, TAU, 64, metal[1], 10.0, true)
		draw_arc(c, 56, PI * 1.02, PI * 1.98, 32, metal[0], 5.0, true)
		draw_arc(c, 61, 0, TAU, 64, Color("120a04"), 2.0, true)
		for i in 24:
			var ang := TAU * i / 24.0
			draw_line(c + Vector2.from_angle(ang) * 52.5, c + Vector2.from_angle(ang) * 59.0, Color(metal[1].darkened(0.45), 0.9), 1.5, true)
		for i in 4:
			var at := c + Vector2.from_angle(TAU * i / 4.0 + PI * 0.25) * 56.0
			draw_circle(at, 4.2, Color("120a04"))
			draw_circle(at, 3.2, metal[0])
			draw_circle(at - Vector2(1, 1), 1.2, Color(1, 1, 1, 0.7))
		# Domed enamel face tinted by rarity, lit from the upper left.
		var face := Color(glow).darkened(0.72) if rank > 0 else Color("2a1c12")
		draw_circle(c, 50, Color("0a0605"))
		for k in 10:
			var r := 49.0 - k * 4.2
			draw_circle(c + Vector2(-k * 0.9, -k * 1.1), r, face.lightened(k * 0.035))
		# The glyph itself is the sculpted child (_sculpt) drawn over this.
		# Glass sheen over the top of the dome.
		var sheen := PackedVector2Array()
		var cols := PackedColorArray()
		for i in 17:
			var ang := PI * 1.12 + PI * 0.76 * i / 16.0
			sheen.append(c + Vector2.from_angle(ang) * 46.0)
			cols.append(Color(1, 1, 1, 0.16))
		for i in 17:
			var ang := PI * 1.88 - PI * 0.76 * i / 16.0
			sheen.append(c + Vector2.from_angle(ang) * 30.0 + Vector2(0, -6))
			cols.append(Color(1, 1, 1, 0.0))
		draw_polygon(sheen, cols)

	func _tone(col: Color) -> Color:
		if _shadow:
			return Color(0.03, 0.02, 0.01, 0.55)
		return col.lerp(Color("f0d6a0"), 0.18)

	func _glyphs(c: Vector2) -> void:
		match op:
			"hp":
				_heart(c, 22, _tone(Color("ff5a6a")))
			"heal":
				_heart(c + Vector2(0, 2), 18, _tone(Color("ff5a6a")))
				_plus(c + Vector2(16, -16), 8, _tone(Color.WHITE))
			"dmg":
				_sword(c, _tone(Color("f2f4f8")))
			"haste":
				_bolt(c, _tone(Color("ffe14a")))
			"swift":
				_chevrons(c, _tone(Color("7ec8ff")))
			"crit":
				_spark(c, _tone(Color("ffe08a")))
			"regen":
				_drop(c, _tone(Color("5dce45")))
			"magnet":
				_magnet(c)
			"bounce":
				_bounce(c, _tone(Color("7ec8ff")))
			"shots":
				_arrows(c, _tone(Color("f4f7ff")))
			"armor":
				_shield(c, _tone(Color("8fd0ff")))
			"siphon":
				_drop(c + Vector2(-8, -6), _tone(Color("ff5a6a")))
				_heart(c + Vector2(14, 12), 12, _tone(Color("ff8fa0")))
			"splash":
				_splash(c, _tone(Color("7ec8ff")))
			"splash_mul":
				_flame(c, _tone(Color("ff8a3c")))
			"pierce":
				_pierce(c, _tone(Color("f4f7ff")))
			"thorns":
				_thorns(c, _tone(Color("7dff5a")))
			"bash":
				_shield(c + Vector2(-4, 2), _tone(Color("ffe08a")))
				_spark(c + Vector2(16, -14), _tone(Color("fff6ea")))
			"revive":
				_heart(c + Vector2(0, 6), 16, _tone(Color("ff5a6a")))
				_chevron_up(c + Vector2(0, -18), _tone(Color("ffe08a")))
			"orbit", "ricochet":
				_bounce(c, _tone(Color("dce8ff")))
			"chain", "storm":
				_bolt(c, _tone(Color("a9e5ff")))
			"trail", "meteor", "berserk", "phoenix":
				_flame(c, _tone(Color("ff8a3c")))
			"nova", "split":
				_splash(c, _tone(Color("9fe4ff")))
			"aura":
				_thorns(c, _tone(Color("7dff5a")))
			"crit_siphon", "vampkill":
				_heart(c + Vector2(0, 4), 17, _tone(Color("ff5a6a")))
				_spark(c + Vector2(17, -16), _tone(Color("ffe08a")))
			"execute":
				_sword(c, _tone(Color("ff8a8a")))
			"blink":
				_chevrons(c, _tone(Color("c9a8ff")))
			"wolf":
				_spark(c + Vector2(0, 2), _tone(Color("bfe9ff")))
				_heart(c + Vector2(15, -15), 8, _tone(Color("ff8fa0")))
			"static":
				_bolt(c, _tone(Color("ffe14a")))
			"gemburst":
				_spark(c, _tone(Color("b6f27a")))
			"volley":
				_arrows(c, _tone(Color("f4f7ff")))
			"mark":
				_spark(c, _tone(Color("ffb15a")))
			"quake":
				_splash(c, _tone(Color("d0a060")))
			"bulwark", "taunt":
				_shield(c, _tone(Color("8fd0ff")))
			_:
				_spark(c, _tone(Color("ffe08a")))

	func _heart(c: Vector2, s: float, col: Color) -> void:
		draw_circle(c + Vector2(-s * 0.42, -s * 0.2), s * 0.48, col)
		draw_circle(c + Vector2(s * 0.42, -s * 0.2), s * 0.48, col)
		draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.86, 0), c + Vector2(0, s), c + Vector2(s * 0.86, 0)]), col)

	func _plus(c: Vector2, s: float, col: Color) -> void:
		draw_rect(Rect2(c.x - s, c.y - s * 0.28, s * 2.0, s * 0.56), col, true)
		draw_rect(Rect2(c.x - s * 0.28, c.y - s, s * 0.56, s * 2.0), col, true)

	func _sword(c: Vector2, col: Color) -> void:
		draw_line(c + Vector2(0, -28), c + Vector2(0, 16), col, 8.0)
		draw_colored_polygon(PackedVector2Array([c + Vector2(0, -34), c + Vector2(8, -18), c + Vector2(-8, -18)]), col)
		draw_line(c + Vector2(-14, 8), c + Vector2(14, 8), _tone(Color("e0a04a")), 6.0)
		draw_line(c + Vector2(0, 16), c + Vector2(0, 28), _tone(Color("8a5a28")), 6.0)

	func _bolt(c: Vector2, col: Color) -> void:
		draw_colored_polygon(PackedVector2Array([
			c + Vector2(2, -30), c + Vector2(16, -2), c + Vector2(4, -2),
			c + Vector2(10, 28), c + Vector2(-14, 2), c + Vector2(0, 2)
		]), col)

	func _chevrons(c: Vector2, col: Color) -> void:
		for dx in [-10.0, 12.0]:
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(-16 + dx, -14), c + Vector2(6 + dx, 0), c + Vector2(-16 + dx, 14),
				c + Vector2(-8 + dx, 0)
			]), col)

	func _spark(c: Vector2, col: Color) -> void:
		draw_colored_polygon(PackedVector2Array([
			c + Vector2(0, -26), c + Vector2(6, -6), c + Vector2(26, 0), c + Vector2(6, 6),
			c + Vector2(0, 26), c + Vector2(-6, 6), c + Vector2(-26, 0), c + Vector2(-6, -6)
		]), col)

	func _drop(c: Vector2, col: Color) -> void:
		draw_colored_polygon(PackedVector2Array([c + Vector2(0, -26), c + Vector2(16, 6), c + Vector2(0, 22), c + Vector2(-16, 6)]), col)
		draw_circle(c + Vector2(0, 6), 14, col)
		draw_circle(c + Vector2(-5, -2), 4, Color(1, 1, 1, 0.55))

	func _magnet(c: Vector2) -> void:
		draw_arc(c + Vector2(0, 4), 20, PI, TAU, 18, _tone(Color("ef4b4b")), 10.0, true)
		draw_line(c + Vector2(-20, 4), c + Vector2(-20, 22), _tone(Color("ef4b4b")), 10.0)
		draw_line(c + Vector2(20, 4), c + Vector2(20, 22), _tone(Color("f0f2f6")), 10.0)
		draw_rect(Rect2(c.x - 26, c.y + 16, 12, 10), _tone(Color("ffe08a")), true)
		draw_rect(Rect2(c.x + 14, c.y + 16, 12, 10), _tone(Color("9aa3b2")), true)

	func _bounce(c: Vector2, col: Color) -> void:
		draw_arc(c + Vector2(-6, 4), 22, PI * 0.15, PI * 0.95, 16, col, 5.0, true)
		draw_colored_polygon(PackedVector2Array([c + Vector2(12, -16), c + Vector2(22, -4), c + Vector2(6, -4)]), col)
		draw_arc(c + Vector2(6, 8), 16, PI * 1.1, TAU * 0.92, 14, _tone(Color("ffe08a")), 5.0, true)

	func _arrows(c: Vector2, col: Color) -> void:
		for i in 3:
			var y := -16.0 + float(i) * 16.0
			draw_line(c + Vector2(-18, y), c + Vector2(8, y), col, 4.0)
			draw_colored_polygon(PackedVector2Array([c + Vector2(6, y - 7), c + Vector2(22, y), c + Vector2(6, y + 7)]), col)

	func _shield(c: Vector2, col: Color) -> void:
		draw_colored_polygon(PackedVector2Array([
			c + Vector2(0, -26), c + Vector2(22, -14), c + Vector2(18, 8),
			c + Vector2(0, 28), c + Vector2(-18, 8), c + Vector2(-22, -14)
		]), col)
		draw_colored_polygon(PackedVector2Array([
			c + Vector2(0, -16), c + Vector2(10, -8), c + Vector2(8, 4),
			c + Vector2(0, 16), c + Vector2(-8, 4), c + Vector2(-10, -8)
		]), Color(1, 1, 1, 0.35))

	func _splash(c: Vector2, col: Color) -> void:
		for i in 3:
			draw_arc(c, 12.0 + float(i) * 12.0, PI * 1.15, PI * 1.85, 12, col, 4.0, true)

	func _flame(c: Vector2, col: Color) -> void:
		draw_colored_polygon(PackedVector2Array([
			c + Vector2(0, -30), c + Vector2(16, -4), c + Vector2(8, 0),
			c + Vector2(14, 18), c + Vector2(0, 26), c + Vector2(-14, 18),
			c + Vector2(-8, 0), c + Vector2(-16, -4)
		]), col)
		draw_colored_polygon(PackedVector2Array([c + Vector2(0, -6), c + Vector2(6, 10), c + Vector2(0, 16), c + Vector2(-6, 10)]), _tone(Color("ffe08a")))

	func _pierce(c: Vector2, col: Color) -> void:
		draw_line(c + Vector2(-28, 0), c + Vector2(16, 0), col, 5.0)
		draw_colored_polygon(PackedVector2Array([c + Vector2(10, -10), c + Vector2(30, 0), c + Vector2(10, 10)]), col)
		draw_line(c + Vector2(-4, -16), c + Vector2(-4, 16), _tone(Color("ff5a6a")), 3.0)

	func _thorns(c: Vector2, col: Color) -> void:
		for ang in [-0.9, -0.2, 0.45, 1.15, 1.9]:
			var dir := Vector2.from_angle(ang)
			draw_colored_polygon(PackedVector2Array([
				c + dir * 8.0 + Vector2(-dir.y, dir.x) * 5.0,
				c + dir * 30.0,
				c + dir * 8.0 - Vector2(-dir.y, dir.x) * 5.0
			]), col)

	func _chevron_up(c: Vector2, col: Color) -> void:
		draw_colored_polygon(PackedVector2Array([c + Vector2(0, -12), c + Vector2(14, 6), c + Vector2(-14, 6)]), col)


## A forged bar: dark inset in a bronze rim, an enamel fill with a sheen,
## segment ticks, and a pale "recent damage" ghost that drains behind it.
## Soft dark gradients at the top and bottom so the HUD reads over bright ground.
class Scrim extends Control:
	var top_h := 360.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)

	func _draw() -> void:
		_band(0.0, top_h, 0.62, true)
		_band(size.y - 260.0, 260.0, 0.45, false)

	func _band(y0: float, h: float, peak: float, fade_down: bool) -> void:
		var strips := 8
		for i in strips:
			var t0 := float(i) / strips
			var t1 := float(i + 1) / strips
			var a0 := peak * pow(1.0 - t0 if fade_down else t0, 1.6)
			var a1 := peak * pow(1.0 - t1 if fade_down else t1, 1.6)
			var c0 := Color(0.04, 0.025, 0.015, a0)
			var c1 := Color(0.04, 0.025, 0.015, a1)
			draw_polygon(PackedVector2Array([Vector2(0, y0 + h * t0), Vector2(size.x, y0 + h * t0), Vector2(size.x, y0 + h * t1), Vector2(0, y0 + h * t1)]), PackedColorArray([c0, c0, c1, c1]))


## XP: a track sunk into a dark groove (inner shadow along the top), a
## gilt rim, a teal fill with a soft breathing glow and a light sweep.
class XpBar extends Meter:
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var rad := size.y * 0.5
		# Forged frame: a dark iron plate with a bevelled bronze band and a
		# rivet at each end, so the bar reads as a bar even when empty.
		UiKit.ch_fill(self, r.grow(7), rad + 7, Color(0, 0, 0, 0.6), Color(0, 0, 0, 0.6))
		UiKit.ch_fill(self, r.grow(5), rad + 5, Color("5a5048"), Color("1e1a16"))
		UiKit.ch_fill(self, r, rad, Color("f0d18e"), Color("5a3814"))
		for end in [rad, size.x - rad]:
			draw_circle(Vector2(end, rad), 5.0, Color("2a1c10"))
			draw_circle(Vector2(end - 0.8, rad - 0.8), 3.6, Color("e7c27a"))
		var groove := r.grow(-3)
		UiKit.ch_fill(self, groove, rad - 3, Color("030202"), Color("1a130d"))
		# The empty track keeps a faint enamel tint and notches every tenth.
		UiKit.ch_fill(self, groove.grow(-2), rad - 5, Color(fill, 0.16), Color(fill.darkened(0.5), 0.12))
		UiKit.ch_fill(self, Rect2(groove.position, Vector2(groove.size.x, groove.size.y * 0.42)), rad - 3, Color(0, 0, 0, 0.7), Color(0, 0, 0, 0.0))
		for i in range(1, 10):
			var x := groove.position.x + groove.size.x * i / 10.0
			draw_line(Vector2(x, groove.position.y + 3), Vector2(x, groove.end.y - 3), Color(0.9, 0.75, 0.45, 0.28), 2.0)
		var bar := groove.grow(-3)
		var w := bar.size.x * clampf(ratio, 0.0, 1.0)
		if w > bar.size.y * 0.6:
			var fr := Rect2(bar.position, Vector2(w, bar.size.y))
			var glow := 0.18 + 0.1 * sin(_t * 3.0)
			for i in 3:
				UiKit.ch_fill(self, fr.grow(2.0 + i * 2.0), bar.size.y * 0.5 + 2.0 + i * 2.0, Color(fill, glow / (i + 1)), Color(fill, glow / (i + 1)))
			UiKit.ch_fill(self, fr, bar.size.y * 0.5, fill.lightened(0.3), fill.darkened(0.4))
			UiKit.ch_fill(self, Rect2(fr.position + Vector2(3, 1), Vector2(fr.size.x - 6, fr.size.y * 0.36)), fr.size.y * 0.2, Color(1, 1, 1, 0.38), Color(1, 1, 1, 0.0))
			# A soft sweep of light running along the fill.
			var sx := fmod(_t * 0.45, 1.6) - 0.3
			var cx := fr.position.x + fr.size.x * sx
			if cx > fr.position.x and cx < fr.end.x:
				var hw := minf(28.0, fr.end.x - cx)
				draw_rect(Rect2(cx, fr.position.y + 2, hw, fr.size.y - 4), Color(1, 1, 1, 0.18))
			# Bright leading edge.
			draw_circle(Vector2(fr.end.x - bar.size.y * 0.5, fr.get_center().y), bar.size.y * 0.42, Color(fill.lightened(0.6), 0.55))


class Meter extends Control:
	var ratio := 1.0
	var fill := Color("d8352a")
	var segments := 1
	var ornate := false
	var _ghost := 1.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ghost = ratio

	func _process(delta: float) -> void:
		if _ghost > ratio:
			_ghost = maxf(ratio, _ghost - delta * 0.5)
		else:
			_ghost = ratio
		queue_redraw()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var rad := size.y * 0.5
		UiKit.ch_fill(self, r.grow(2), rad + 2, Color(0, 0, 0, 0.6), Color(0, 0, 0, 0.6))
		UiKit.ch_fill(self, r, rad, Color("e8c886"), Color("4e3012"))
		var inner := r.grow(-3)
		UiKit.ch_fill(self, inner, rad - 3, Color("080605"), Color("1c1510"))
		var bar := inner.grow(-2)
		var ghost_w := bar.size.x * clampf(_ghost, 0.0, 1.0)
		if ghost_w > bar.size.y * 0.6:
			UiKit.ch_fill(self, Rect2(bar.position, Vector2(ghost_w, bar.size.y)), bar.size.y * 0.5, Color(1, 0.92, 0.8, 0.55), Color(1, 0.8, 0.6, 0.4))
		var width := bar.size.x * clampf(ratio, 0.0, 1.0)
		if width > bar.size.y * 0.6:
			var fr := Rect2(bar.position, Vector2(width, bar.size.y))
			UiKit.ch_fill(self, fr, bar.size.y * 0.5, fill.lightened(0.25), fill.darkened(0.45))
			UiKit.ch_fill(self, Rect2(fr.position + Vector2(3, 1), Vector2(fr.size.x - 6, fr.size.y * 0.38)), fr.size.y * 0.2, Color(1, 1, 1, 0.32), Color(1, 1, 1, 0.0))
		if segments > 1:
			for i in range(1, segments):
				var x := bar.position.x + bar.size.x * float(i) / float(segments)
				draw_line(Vector2(x, bar.position.y + 1), Vector2(x, bar.end.y - 1), Color(0, 0, 0, 0.55), 2.0)
		if ornate:
			# Gilded end caps for the boss bar.
			for side in [0.0, 1.0]:
				var cx := lerpf(r.position.x + 2.0, r.end.x - 2.0, side)
				var c := Vector2(cx, r.get_center().y)
				var pts := PackedVector2Array([c + Vector2(0, -rad - 6), c + Vector2(rad * 0.9, 0), c + Vector2(0, rad + 6), c + Vector2(-rad * 0.9, 0)])
				var big := PackedVector2Array()
				for p in pts:
					big.append(c + (p - c) * 1.2)
				draw_colored_polygon(big, Color("120a04"))
				draw_polygon(pts, PackedColorArray([Color("ffe6a8"), Color("c8963a"), Color("6a4416"), Color("c8963a")]))


class StickLayer extends Control:
	# Viewport units on the 720-wide playfield. Full speed is a short push;
	# past the rim the base slides with the thumb so a reverse is instant.
	const RADIUS := 46.0
	const DEAD := 3.0
	const FULL := 16.0
	var active := false
	var origin := Vector2.ZERO
	var knob := Vector2.ZERO
	var vec := Vector2.ZERO
	var hint := 1.0
	var hint_left := 1.2

	func place(at: Vector2) -> void:
		var delta := at - origin
		var dist := delta.length()
		if dist > RADIUS and dist > 0.001:
			origin = at - delta * (RADIUS / dist)
			delta = at - origin
			dist = RADIUS
		knob = origin + delta
		if dist <= DEAD or dist <= 0.001:
			vec = Vector2.ZERO
		else:
			var mag := clampf((dist - DEAD) / (FULL - DEAD), 0.0, 1.0)
			vec = delta * (mag / dist)
		queue_redraw()

	func _draw() -> void:
		if size.y < 10.0:
			return
		if active:
			_draw_base()
			_draw_knob()
		elif hint > 0.04:
			UiKit.ensure()
			var text := "Drag to steer"
			var width := 220.0
			draw_string(UiKit.font_x, Vector2(size.x * 0.5 - width * 0.5, size.y * 0.78), text, HORIZONTAL_ALIGNMENT_LEFT, width, 28, Color(1, 1, 1, 0.85 * hint))


	## Forged base: a smoked-enamel well in a cast-bronze ring lit from the
	## top left, eight engraved ticks, and an ember glow on the rim toward
	## the push.
	func _draw_base() -> void:
		var c := origin
		var r := RADIUS
		draw_circle(c + Vector2(0, 3), r + 9.0, Color(0, 0, 0, 0.35))
		for k in 6:
			var t := float(k) / 5.0
			draw_circle(c, r * (1.0 - t * 0.55), Color(0.05, 0.07, 0.09, 0.5).lerp(Color(0.12, 0.17, 0.2, 0.62), t))
		for k in 40:
			var a0 := TAU * k / 40.0
			var lit := 0.5 + 0.5 * cos(a0 + 2.36)
			var col := Color(0.38, 0.24, 0.1).lerp(Color(0.9, 0.66, 0.34), lit)
			draw_arc(c, r + 3.0, a0, a0 + TAU / 40.0 + 0.01, 3, col, 6.0, true)
		draw_arc(c, r + 6.5, 0.0, TAU, 48, Color(0.16, 0.09, 0.04, 0.9), 1.5, true)
		draw_arc(c, r - 0.5, 0.0, TAU, 48, Color(1.0, 0.88, 0.6, 0.55), 1.0, true)
		for k in 8:
			var d := Vector2.RIGHT.rotated(TAU * k / 8.0)
			draw_line(c + d * (r - 9.0), c + d * (r - 3.0), Color(0.85, 0.7, 0.45, 0.55), 1.5, true)
		if vec.length() > 0.05:
			var ang := vec.angle()
			var glow := clampf(vec.length(), 0.0, 1.0)
			for k in 3:
				draw_arc(c, r + 3.0, ang - 0.55 + k * 0.1, ang + 0.55 - k * 0.1, 16, Color(1.0, 0.62, 0.22, 0.22 * glow * (k + 1)), 8.0 - k * 2.0, true)

	## Knob: a bronze dome with an enamel inset and a hard specular glint.
	func _draw_knob() -> void:
		var k := knob
		var r := 21.0
		draw_circle(k + Vector2(1.5, 4.0), r + 1.0, Color(0, 0, 0, 0.4))
		draw_circle(k, r + 1.5, Color(0.2, 0.11, 0.04))
		for i in 7:
			var t := float(i) / 6.0
			draw_circle(k - Vector2(3, 4) * t, r * (1.0 - t * 0.7), Color(0.5, 0.31, 0.13).lerp(Color(0.98, 0.78, 0.46), t))
		draw_circle(k, r * 0.5, Color(0.25, 0.08, 0.06))
		draw_circle(k, r * 0.42, Color(0.6, 0.12, 0.08))
		draw_circle(k - Vector2(2, 2.5), r * 0.22, Color(0.95, 0.4, 0.25))
		draw_circle(k - Vector2(7, 8), 3.0, Color(1, 0.97, 0.88, 0.9))


class GoldBeam extends Control:
	var spin := 0.0

	func _process(delta: float) -> void:
		spin += delta
		queue_redraw()

	func _draw() -> void:
		if size.y < 10.0:
			return
		var c := Vector2(size.x * 0.5, size.y * 0.42)
		var top := Vector2(size.x * 0.5, -40.0)
		draw_colored_polygon(PackedVector2Array([
			top + Vector2(-36, 0), top + Vector2(36, 0), c + Vector2(90, 120), c + Vector2(-90, 120)
		]), Color(1.0, 0.82, 0.28, 0.38))
		draw_colored_polygon(PackedVector2Array([
			top + Vector2(-12, 0), top + Vector2(12, 0), c + Vector2(28, 140), c + Vector2(-28, 140)
		]), Color(1.0, 0.95, 0.7, 0.55))
		for i in 10:
			var ang := spin * 0.7 + float(i) * TAU / 10.0
			var dir := Vector2.from_angle(ang)
			draw_line(c, c + dir * 240.0, Color(1.0, 0.86, 0.4, 0.28), 10.0)
		draw_circle(c, 90, Color(1.0, 0.9, 0.45, 0.22))


class GroundMarks extends Node2D:
	var sim: RunSim
	var alpha := 1.0

	func _draw() -> void:
		if sim == null:
			return
		var shadow := SpriteBank.fx("shadow")
		for actor in sim.actors:
			if not actor.alive:
				continue
			var pos: Vector2 = actor.prev.lerp(actor.pos, alpha)
			var w := actor.radius * 2.1
			draw_texture_rect(shadow, Rect2(pos.x - w, pos.y + actor.radius * 0.2, w * 2.0, w * 0.7), false, Color(1, 1, 1, 0.42))
			if actor.kind == "minion" and actor.alive and actor.max_hp > 0.0:
				var width := 28.0
				var y := pos.y - actor.radius * 1.65
				var t := clampf(actor.hp / actor.max_hp, 0.0, 1.0)
				draw_rect(Rect2(pos.x - width - 2, y - 2, width * 2.0 + 4, 12.0), Color("1a100c"), true)
				draw_rect(Rect2(pos.x - width, y, width * 2.0, 8.0), Color("3a1814"), true)
				draw_rect(Rect2(pos.x - width, y, width * 2.0 * t, 8.0), Color("ff4d4d"), true)
				draw_rect(Rect2(pos.x - width, y, width * 2.0 * t, 3.0), Color(1, 1, 1, 0.35), true)
		for ping in sim.pings:
			if not ping.alive or ping.max_life <= 0.0:
				continue
			var filled := 1.0 - clampf(ping.life / ping.max_life, 0.0, 1.0)
			if ping.kind == "circle":
				draw_circle(ping.pos, ping.radius, Color(1.0, 0.35, 0.22, 0.16 + 0.2 * filled))
				draw_arc(ping.pos, ping.radius, 0, TAU, 40, Color(1.0, 0.5, 0.28, 0.95), 4.0, true)
				draw_circle(ping.pos, maxf(4.0, ping.radius * filled), Color(1.0, 0.42, 0.2, 0.16))
			else:
				var end := ping.pos + ping.dir * ping.length
				draw_line(ping.pos, end, Color(1.0, 0.72, 0.25, 0.28), ping.width * 2.0, true)
				draw_line(ping.pos, end, Color(1.0, 0.86, 0.4, 0.9), 5.0, true)


class SparkLayer extends Node2D:
	var parts: Array = []

	func burst(pos: Vector2, color: Color, count: int, speed: float) -> void:
		for _i in count:
			var ang := randf() * TAU
			var vel := Vector2.RIGHT.rotated(ang) * randf_range(speed * 0.35, speed)
			var life := randf_range(0.22, 0.5)
			parts.append({"p": pos, "v": vel, "life": life, "max": life, "c": color, "s": randf_range(3.0, 7.0)})
		if parts.size() > 140:
			parts = parts.slice(parts.size() - 100, parts.size())
		queue_redraw()

	func tick(delta: float) -> void:
		var i := 0
		while i < parts.size():
			parts[i]["life"] = float(parts[i]["life"]) - delta
			parts[i]["p"] = parts[i]["p"] + parts[i]["v"] * delta
			parts[i]["v"] = parts[i]["v"] * 0.96
			if float(parts[i]["life"]) <= 0.0:
				parts.remove_at(i)
			else:
				i += 1
		queue_redraw()

	func _draw() -> void:
		for part in parts:
			var life := float(part["life"])
			var peak := maxf(float(part["max"]), 0.001)
			var a := clampf(life / peak, 0.0, 1.0)
			var col: Color = part["c"]
			col.a = a
			draw_circle(part["p"], float(part["s"]) * (0.45 + a), col)


## Enemy health bars over the 3D bodies, and arrows at the screen edge for
## anything hostile outside the view. The edge band respects the safe area
## and keeps clear of the top HUD and the joystick zone.
class ThreatLayer extends Control:
	var screen: Node
	var t := 0.0

	func _process(delta: float) -> void:
		t += delta

	func _draw() -> void:
		var run := screen as Object
		var sim: RunSim = run.get("sim")
		var stage: Stage3D = run.get("stage")
		if sim == null or stage == null or stage.camera == null:
			return
		var pad := UiKit.safe_insets()
		var band := Rect2(Vector2.ZERO, size)
		band.position += Vector2(float(pad["l"]) + 26.0, float(pad["t"]) + 230.0)
		band.size -= Vector2(float(pad["l"]) + float(pad["r"]) + 52.0, float(pad["t"]) + float(pad["b"]) + 230.0 + 150.0)
		var center := band.get_center()
		var alpha := float(run.get("sync_alpha"))
		var offscreen: Array = []
		for actor in sim.actors:
			if not actor.alive or actor.team == 0:
				continue
			if sim.explore and actor.kind == "minion" and not actor.aggro:
				continue
			var pos: Vector2 = actor.prev.lerp(actor.pos, alpha)
			var boss: bool = actor.kind == "boss"
			var head_h: float = Stage3D.BOSS_METERS * 1.05 if boss else Stage3D.HERO_METERS * 0.95
			var foot := get_global_transform().affine_inverse() * stage.project(pos, 0.0)
			var head := get_global_transform().affine_inverse() * stage.project(pos, head_h)
			if Rect2(Vector2.ZERO, size).grow(-8.0).has_point(foot):
				if not boss and actor.max_hp > 0.0 and actor.hp < actor.max_hp:
					_bar(head + Vector2(0, -10), clampf(actor.hp / actor.max_hp, 0.0, 1.0))
				# The boss is named by the top bar alone; no floating tag.
			else:
				offscreen.append([foot, boss])
		_drawn.clear()
		# Boss first so a crowd of minions never hides its marker.
		offscreen.sort_custom(func(a: Array, b: Array) -> bool: return bool(a[1]) and not bool(b[1]))
		for item in offscreen:
			_arrow(center, item[0], band, item[1])

	var _drawn: Array[Vector2] = []

	func _bar(at: Vector2, ratio: float) -> void:
		var w := 30.0
		var r := Rect2(at.x - w, at.y - 5.0, w * 2.0, 9.0)
		draw_rect(r.grow(2.0), Color(0.05, 0.03, 0.02, 0.85), true)
		draw_rect(r, Color(0.22, 0.06, 0.05), true)
		draw_rect(Rect2(r.position, Vector2(r.size.x * ratio, r.size.y)), Color("d8352a"), true)
		draw_rect(Rect2(r.position, Vector2(r.size.x * ratio, 3.0)), Color(1, 0.8, 0.7, 0.35), true)

	func _arrow(from: Vector2, target: Vector2, band: Rect2, boss: bool) -> void:
		var dir := (target - from).normalized()
		if dir == Vector2.ZERO:
			return
		# Walk out from the centre to the band edge along the direction.
		var tx := INF
		var ty := INF
		if dir.x > 0.001:
			tx = (band.end.x - from.x) / dir.x
		elif dir.x < -0.001:
			tx = (band.position.x - from.x) / dir.x
		if dir.y > 0.001:
			ty = (band.end.y - from.y) / dir.y
		elif dir.y < -0.001:
			ty = (band.position.y - from.y) / dir.y
		var at := from + dir * minf(tx, ty)
		if not boss:
			# Minions: one small, quiet chevron per cluster on the edge.
			for p in _drawn:
				if p.distance_to(at) < 48.0:
					return
			_drawn.append(at)
			var m := 11.0
			var sd := dir.orthogonal()
			var tp := at + dir * m
			var pts := PackedVector2Array([tp, at - dir * m * 0.5 + sd * m * 0.8, at - dir * m * 0.1, at - dir * m * 0.5 - sd * m * 0.8])
			draw_colored_polygon(pts, Color(0.05, 0.03, 0.02, 0.45))
			var inner := PackedVector2Array()
			for q in pts:
				inner.append(at + (q - at) * 0.72)
			draw_colored_polygon(inner, Color(0.95, 0.85, 0.65, 0.5))
			return
		_drawn.append(at)
		# A forged chevron: iron body with a lit and a shadowed facet, a gilt
		# edge, and a gem in the throat (ember red for the boss).
		var s := 30.0 if boss else 19.0
		s *= 1.0 + 0.06 * sin(t * 6.0)
		var side := dir.orthogonal()
		var tip := at + dir * s
		var wl := at - dir * s * 0.55 + side * s * 0.85
		var wr := at - dir * s * 0.55 - side * s * 0.85
		var notch := at - dir * s * 0.12
		var shadow := PackedVector2Array()
		for p in [tip, wl, notch, wr]:
			shadow.append(p + Vector2(0, 4))
		draw_colored_polygon(shadow, Color(0, 0, 0, 0.5))
		# Light falls from the top-left: pick which facet is lit.
		var lit_left := side.dot(Vector2(-0.6, -0.8)) > 0.0
		var lit := Color("8a7a66") if not boss else Color("9a5a44")
		var dark := Color("2e2620") if not boss else Color("3a1612")
		draw_colored_polygon(PackedVector2Array([tip, wl, notch]), lit if lit_left else dark)
		draw_colored_polygon(PackedVector2Array([tip, notch, wr]), dark if lit_left else lit)
		var outline := PackedVector2Array([tip, wl, notch, wr, tip])
		draw_polyline(outline, Color(0.07, 0.04, 0.02, 0.95), 4.5, true)
		draw_polyline(outline, Color("c9a25a"), 1.8, true)
		draw_line(tip, notch, Color(1.0, 0.9, 0.7, 0.35), 1.2, true)
		var g := at - dir * s * 0.05
		var gs := s * (0.2 if boss else 0.17)
		var gem := PackedVector2Array([g + dir * gs, g + side * gs * 0.8, g - dir * gs, g - side * gs * 0.8])
		draw_colored_polygon(gem, Color("e8462e") if boss else Color("f0a830"))
		draw_colored_polygon(PackedVector2Array([g + dir * gs, g + side * gs * 0.8, g]), Color(1, 0.85, 0.7, 0.55))



## Corner minimap for explore hunts. Fills in as the fog lifts: open ground,
## the hero, camps and chests once seen, and the boss lair (always marked as
## the goal). Tap to enlarge it over a dimmed screen (the hunt pauses); tap
## again to close.
class MiniMap extends Control:
	var screen: Node
	var sim: RunSim
	var big := false
	var _base: ImageTexture
	var _veil: ImageTexture
	var _veil_img: Image
	var _t := 0.0
	var _pulse := 0.0
	var _paper: TextureRect
	var _mat: ShaderMaterial
	var _marks: Control
	## Corner disc, in UI px, and how much of the map it spans (px of world).
	const DIAM := 150.0
	const SPAN := 3600.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		_mat = ShaderMaterial.new()
		_mat.shader = load("res://shaders/minimap.gdshader")
		_paper = TextureRect.new()
		_paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_paper.material = _mat
		_paper.stretch_mode = TextureRect.STRETCH_SCALE
		add_child(_paper)
		_marks = Marks.new()
		_marks.map = self
		_marks.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_marks)
		_layout()
		get_viewport().size_changed.connect(_layout)

	func _layout() -> void:
		var view := get_viewport_rect().size
		var pad := UiKit.safe_insets()
		if big:
			var w := view.x - 80.0
			var h := minf(w * 2.0, view.y - float(pad["t"]) - float(pad["b"]) - 200.0)
			w = h * 0.5
			size = Vector2(w, h)
			position = Vector2((view.x - w) * 0.5, float(pad["t"]) + 120.0 + (view.y - float(pad["t"]) - float(pad["b"]) - 200.0 - h) * 0.5)
		else:
			size = Vector2(DIAM, DIAM)
			position = Vector2(view.x - float(pad["r"]) - DIAM - 22.0, float(pad["t"]) + 196.0)
		if _paper != null:
			_paper.position = Vector2.ZERO
			_paper.size = size
			_marks.size = size
			_mat.set_shader_parameter("round_mask", not big)
			_mat.set_shader_parameter("px_size", size)
		queue_redraw()

	func _gui_input(event: InputEvent) -> void:
		var tap := (event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT) or (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed)
		if tap:
			accept_event()
			toggle()

	func toggle() -> void:
		big = not big
		if screen != null:
			screen.set("_modal_up", big)
		AudioDirector.sfx("ui_tap")
		_layout()

	func _process(delta: float) -> void:
		if sim == null or not visible:
			return
		_t += delta
		_pulse += delta
		if _base == null:
			_bake_base()
		if _t >= 0.25:
			_t = 0.0
			_bake_veil()
		_aim()
		queue_redraw()
		_marks.queue_redraw()

	## Where the paper looks: the whole map when big, else a disc on the hero.
	func _aim() -> void:
		if big or sim.heroes.is_empty():
			_mat.set_shader_parameter("center_uv", Vector2(0.5, 0.5))
			_mat.set_shader_parameter("span_uv", Vector2.ONE)
			return
		_mat.set_shader_parameter("center_uv", sim.heroes[0].pos / sim.map.size)
		_mat.set_shader_parameter("span_uv", Vector2(SPAN, SPAN) / sim.map.size)

	func _bake_base() -> void:
		var m := sim.map
		var img := Image.create(m.grid_w, m.grid_h, false, Image.FORMAT_RGBA8)
		for y in m.grid_h:
			for x in m.grid_w:
				var c := Vector2((x + 0.5) * HuntMap.GRID, (y + 0.5) * HuntMap.GRID)
				var open := m.open_cells[y * m.grid_w + x] == 1
				# Explored chart: woods and walls a mid dark green, open ground
				# a warm parchment, the packed trail a brighter sand. All of it
				# sits well clear of the near-black fog.
				var col := Color(0.16, 0.28, 0.18)
				if open:
					col = Color(0.8, 0.7, 0.5)
					if m.trail_dist(c) < 70.0:
						col = Color(0.94, 0.82, 0.56)
				img.set_pixel(x, y, col)
		_base = ImageTexture.create_from_image(img)
		_veil_img = Image.create(m.grid_w, m.grid_h, false, Image.FORMAT_RGBA8)
		_bake_veil()
		_paper.texture = _base
		_mat.set_shader_parameter("base_tex", _base)

	func _bake_veil() -> void:
		var m := sim.map
		var data := PackedByteArray()
		data.resize(m.grid_w * m.grid_h * 4)
		for i in m.grid_w * m.grid_h:
			# White with the fog's alpha: the shader reads only the alpha, and
			# the overlay reuses the same image as a tintable veil.
			data[i * 4] = 255
			data[i * 4 + 1] = 255
			data[i * 4 + 2] = 255
			data[i * 4 + 3] = 0 if sim.fog_seen[i] == 1 else 255
		_veil_img.set_data(m.grid_w, m.grid_h, false, Image.FORMAT_RGBA8, data)
		if _veil == null:
			_veil = ImageTexture.create_from_image(_veil_img)
			_mat.set_shader_parameter("veil_tex", _veil)
		else:
			_veil.update(_veil_img)

	## World px -> local UI px, for the current view.
	func _to_ui(p: Vector2) -> Vector2:
		if big:
			return p / sim.map.size * size
		var h: Vector2 = sim.heroes[0].pos if not sim.heroes.is_empty() else sim.map.size * 0.5
		return size * 0.5 + (p - h) / SPAN * DIAM

	func _inside(q: Vector2, margin: float) -> bool:
		return big or q.distance_to(size * 0.5) <= DIAM * 0.5 - margin

	## Local UI px -> veil texel uv, mirroring the paper's own view transform.
	func _uv_at(q: Vector2) -> Vector2:
		var m := sim.map
		var p := q
		if not big:
			var h: Vector2 = sim.heroes[0].pos if not sim.heroes.is_empty() else m.size * 0.5
			p = h + (q - size * 0.5) / DIAM * SPAN
		var uv := p / m.size
		return Vector2(clampf(uv.x, 0.0, 1.0), clampf(uv.y, 0.0, 1.0))

	## A near-black teal wash over the unexplored paper, so the fog reads
	## sharply against the warm parchment. One textured polygon (clipped to
	## the disc or the frame) sampling the veil image, which the shader keeps
	## in step with the same view; no extra per-frame bake.
	func _fog(ci: CanvasItem) -> void:
		if _veil == null:
			return
		var pts := PackedVector2Array()
		var uvs := PackedVector2Array()
		if big:
			for q: Vector2 in [Vector2.ZERO, Vector2(size.x, 0.0), size, Vector2(0.0, size.y)]:
				pts.append(q)
				uvs.append(q / size)
		else:
			var c := size * 0.5
			var r := DIAM * 0.5 - 1.0
			for k in 64:
				var q2 := c + Vector2.RIGHT.rotated(TAU * float(k) / 64.0) * r
				pts.append(q2)
				uvs.append(_uv_at(q2))
		ci.draw_colored_polygon(pts, Color(0.06, 0.09, 0.1, 0.92), uvs, _veil)

	func _bronze_ring(ci: CanvasItem, c: Vector2, r: float) -> void:
		# Forged bronze: a dark outer lip, a warm cast band lit from the top
		# left, a thin bright bevel on the inside, and four rivets.
		ci.draw_arc(c, r + 7.0, 0.0, TAU, 64, Color(0.09, 0.06, 0.03, 0.85), 13.0, true)
		var band := 9.0
		for k in 48:
			var a0 := TAU * k / 48.0
			var a1 := TAU * (k + 1) / 48.0
			var lit := 0.5 + 0.5 * cos(a0 + 2.36)
			var col := Color(0.42, 0.27, 0.12).lerp(Color(0.86, 0.62, 0.32), lit)
			col = col.darkened(0.12 * float(k % 3 == 0))
			ci.draw_arc(c, r + band * 0.5 + 1.0, a0, a1 + 0.01, 3, col, band, true)
		ci.draw_arc(c, r + band + 1.5, 0.0, TAU, 64, Color(0.2, 0.12, 0.05), 2.0, true)
		ci.draw_arc(c, r + 1.0, 0.0, TAU, 64, Color(1.0, 0.86, 0.55, 0.85), 1.5, true)
		ci.draw_arc(c, r - 0.5, 0.0, TAU, 64, Color(0.1, 0.06, 0.02, 0.9), 1.5, true)
		for k in 4:
			var ang := PI * 0.25 + PI * 0.5 * k
			var at := c + Vector2.RIGHT.rotated(ang) * (r + band * 0.5 + 1.0)
			ci.draw_circle(at, 3.6, Color(0.18, 0.1, 0.04))
			ci.draw_circle(at, 2.6, Color(0.95, 0.78, 0.45))
			ci.draw_circle(at + Vector2(-0.8, -0.8), 1.0, Color(1, 0.97, 0.85))
		# Engraved north notch.
		var n := c + Vector2(0, -(r + band * 0.5 + 1.0))
		ci.draw_colored_polygon(PackedVector2Array([n + Vector2(0, -5), n + Vector2(4, 3), n + Vector2(-4, 3)]), Color(0.16, 0.08, 0.03))

	## Forged bronze border for the full map: a dark outer lip, a hammered
	## band with a warm top-left highlight, an engraved gold bevel, riveted
	## corner bosses and a title cartouche.
	func _bronze_frame(ci: CanvasItem, r: Rect2) -> void:
		var band := 16.0
		ci.draw_rect(r.grow(band + 4.0), Color(0.07, 0.04, 0.02, 0.9), false, 4.0)
		for k in 6:
			var t := float(k) / 5.0
			var col := Color(0.36, 0.22, 0.1).lerp(Color(0.72, 0.5, 0.24), sin(t * PI))
			ci.draw_rect(r.grow(band - k * 2.6), col, false, 3.0)
		# Top and left catch the light, bottom and right fall into shadow.
		ci.draw_line(r.position + Vector2(-band, -band), Vector2(r.end.x + band, r.position.y - band), Color(1, 0.86, 0.55, 0.55), 2.0)
		ci.draw_line(r.position + Vector2(-band, -band), Vector2(r.position.x - band, r.end.y + band), Color(1, 0.86, 0.55, 0.4), 2.0)
		ci.draw_line(Vector2(r.position.x - band, r.end.y + band), r.end + Vector2(band, band), Color(0.1, 0.05, 0.02, 0.8), 2.0)
		ci.draw_line(Vector2(r.end.x + band, r.position.y - band), r.end + Vector2(band, band), Color(0.1, 0.05, 0.02, 0.8), 2.0)
		# Engraved inner bevel and a shadow onto the paper.
		ci.draw_rect(r.grow(2.0), Color(1.0, 0.85, 0.5, 0.9), false, 1.5)
		ci.draw_rect(r.grow(-2.0), Color(0, 0, 0, 0.35), false, 4.0)
		# Rivets along the band.
		var mid := band * 0.5
		var step := 64.0
		var x := r.position.x + step
		while x < r.end.x - step * 0.5:
			for y in [r.position.y - mid, r.end.y + mid]:
				_rivet(ci, Vector2(x, y), 3.2)
			x += step
		var y2 := r.position.y + step
		while y2 < r.end.y - step * 0.5:
			for x2 in [r.position.x - mid, r.end.x + mid]:
				_rivet(ci, Vector2(x2, y2), 3.2)
			y2 += step
		# Corner bosses: an enamel stud in a bronze rosette.
		for corner in [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]:
			var cc: Vector2 = corner + (r.get_center() - corner).sign() * -mid * 0.2
			ci.draw_circle(cc, 17.0, Color(0.08, 0.04, 0.02))
			for k in 8:
				var a := k * TAU / 8.0
				ci.draw_circle(cc + Vector2.RIGHT.rotated(a) * 11.0, 5.0, Color(0.6, 0.4, 0.18))
			ci.draw_circle(cc, 12.0, Color(0.78, 0.56, 0.26))
			ci.draw_circle(cc, 8.0, Color(0.12, 0.3, 0.32))
			ci.draw_circle(cc + Vector2(-2.5, -2.5), 3.0, Color(0.55, 0.85, 0.85, 0.7))
		# Title cartouche, centred on the top band.
		var font: Font = UiKit.font_b
		var title := str(sim.biome.get("name", "Map")).to_upper()
		var tw := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
		var plate := Rect2(Vector2(r.get_center().x - tw * 0.5 - 34.0, r.position.y - band - 26.0), Vector2(tw + 68.0, 52.0))
		var pts := PackedVector2Array([plate.position + Vector2(16, 0), Vector2(plate.end.x - 16, plate.position.y), Vector2(plate.end.x, plate.get_center().y), Vector2(plate.end.x - 16, plate.end.y), Vector2(plate.position.x + 16, plate.end.y), Vector2(plate.position.x, plate.get_center().y)])
		var outer := PackedVector2Array()
		for q in pts:
			outer.append(plate.get_center() + (q - plate.get_center()) * Vector2(1.04, 1.16))
		ci.draw_colored_polygon(outer, Color(0.08, 0.04, 0.02))
		ci.draw_colored_polygon(pts, Color(0.5, 0.33, 0.15))
		var inner := PackedVector2Array()
		for q in pts:
			inner.append(plate.get_center() + (q - plate.get_center()) * Vector2(0.95, 0.78))
		ci.draw_colored_polygon(inner, Color(0.16, 0.09, 0.05))
		ci.draw_string(font, Vector2(plate.get_center().x - tw * 0.5, plate.get_center().y + 11.0), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color("f2d9a0"))

	func _rivet(ci: CanvasItem, at: Vector2, rad: float) -> void:
		ci.draw_circle(at + Vector2(0.8, 0.8), rad + 0.8, Color(0.08, 0.04, 0.02, 0.8))
		ci.draw_circle(at, rad, Color(0.86, 0.66, 0.36))
		ci.draw_circle(at + Vector2(-rad * 0.3, -rad * 0.3), rad * 0.4, Color(1, 0.95, 0.8))

	## The lair's skull, blood red once the den is known and a dim ember
	## before that, always marked as the goal.
	func _skull(ci: CanvasItem, p: Vector2, s: float, found: bool) -> void:
		var bone := Color(0.96, 0.34, 0.22) if found else Color(0.5, 0.14, 0.1, 0.7)
		var ink := Color(0.08, 0.02, 0.03)
		ci.draw_circle(p + Vector2(0, -s * 0.15), s * 1.05, ink)
		ci.draw_rect(Rect2(p + Vector2(-s * 0.62, s * 0.2), Vector2(s * 1.24, s * 0.85)), ink, true)
		ci.draw_circle(p + Vector2(0, -s * 0.15), s * 0.85, bone)
		ci.draw_rect(Rect2(p + Vector2(-s * 0.45, s * 0.25), Vector2(s * 0.9, s * 0.6)), bone, true)
		ci.draw_circle(p + Vector2(-s * 0.33, -s * 0.12), s * 0.24, ink)
		ci.draw_circle(p + Vector2(s * 0.33, -s * 0.12), s * 0.24, ink)
		ci.draw_colored_polygon(PackedVector2Array([p + Vector2(0, s * 0.12), p + Vector2(s * 0.12, s * 0.34), p + Vector2(-s * 0.12, s * 0.34)]), ink)
		for k in 3:
			ci.draw_line(p + Vector2(-s * 0.22 + k * s * 0.22, s * 0.5), p + Vector2(-s * 0.22 + k * s * 0.22, s * 0.85), ink, 1.0)

	func _draw() -> void:
		if big:
			draw_rect(Rect2(-position, get_viewport_rect().size), Color(0, 0, 0, 0.6), true)

	func draw_marks(ci: CanvasItem) -> void:
		if sim == null or _base == null:
			return
		var r := Rect2(Vector2.ZERO, size)
		var c := size * 0.5
		# Fog first, under the frame and every marker, so nothing it covers
		# ever hides a glyph.
		_fog(ci)
		if big:
			_bronze_frame(ci, r)
		else:
			_bronze_ring(ci, c, DIAM * 0.5)
		var dot := 3.0 if not big else 5.0
		# Landmarks once seen: small engraved glyphs (tree, stones, ruin, crystal).
		for lm in sim.map.landmarks:
			var lpos: Vector2 = lm["pos"]
			var known := sim.seen_at(lpos)
			# The full map is a hunter's chart: landmarks not yet seen are
			# sketched in faintly; the corner disc shows only what you found.
			if not known and not big:
				continue
			var q := _to_ui(lpos)
			if not _inside(q, 5.0):
				continue
			var g := dot * 1.4
			var ink := Color(0.1, 0.07, 0.04, 0.9 if known else 0.35)
			match str(lm.get("kind", "")):
				"great_tree":
					ci.draw_circle(q + Vector2(0, -g * 0.4), g, ink)
					ci.draw_circle(q + Vector2(0, -g * 0.4), g * 0.7, Color(0.3, 0.5, 0.25))
					ci.draw_line(q, q + Vector2(0, g * 0.9), ink, 2.0)
				"crystal":
					ci.draw_colored_polygon(PackedVector2Array([q + Vector2(0, -g * 1.2), q + Vector2(g * 0.6, 0), q + Vector2(0, g * 0.9), q + Vector2(-g * 0.6, 0)]), Color(0.55, 0.85, 1.0))
					ci.draw_polyline(PackedVector2Array([q + Vector2(0, -g * 1.2), q + Vector2(g * 0.6, 0), q + Vector2(0, g * 0.9), q + Vector2(-g * 0.6, 0), q + Vector2(0, -g * 1.2)]), ink, 1.0)
				_:
					for k in 3:
						var x := (k - 1) * g * 0.7
						ci.draw_rect(Rect2(q + Vector2(x - g * 0.22, -g * (0.9 if k == 1 else 0.6)), Vector2(g * 0.44, g * (1.5 if k == 1 else 1.2))), Color(0.62, 0.6, 0.55), true)
						ci.draw_rect(Rect2(q + Vector2(x - g * 0.22, -g * (0.9 if k == 1 else 0.6)), Vector2(g * 0.44, g * (1.5 if k == 1 else 1.2))), ink, false, 1.0)
		# Chests once seen: gold on a dark bed with a 1 px rim.
		for ch in sim.chests:
			if bool(ch["open"]) or not sim.seen_at(ch["pos"]):
				continue
			var p := _to_ui(ch["pos"])
			if not _inside(p, 5.0):
				continue
			var box := Rect2(p - Vector2(dot, dot), Vector2(dot, dot) * 2.0)
			ci.draw_rect(box.grow(1.0), Color(0.08, 0.05, 0.02, 0.85), true)
			ci.draw_rect(box, Color("ffd24a"), true)
			ci.draw_rect(box, Color(0.08, 0.05, 0.02), false, 1.0)
		# Known camps: crossed-blade marks with a 1 px dark rim, orange for
		# elites.
		var camps := {}
		for a in sim.actors:
			if a.alive and a.kind == "minion" and sim.seen_at(a.pos):
				var key := a.camp
				if not camps.has(key):
					camps[key] = [a.pos, a.elite]
				elif a.elite:
					camps[key][1] = true
		for key in camps:
			var p := _to_ui(camps[key][0])
			if not _inside(p, 6.0):
				continue
			var s := dot * (1.9 if camps[key][1] else 1.5)
			var col := Color("ff9a2a") if camps[key][1] else Color("e8442c")
			ci.draw_circle(p, s + 1.0, Color(0.12, 0.03, 0.02))
			ci.draw_circle(p, s, col)
			ci.draw_line(p + Vector2(-s, -s) * 0.55, p + Vector2(s, s) * 0.55, Color(0.15, 0.04, 0.02), 1.5)
			ci.draw_line(p + Vector2(s, -s) * 0.55, p + Vector2(-s, s) * 0.55, Color(0.15, 0.04, 0.02), 1.5)
		# Rumoured camps on the full map: faint dashed rings where packs den.
		if big:
			for camp in sim.map.camps:
				var cp: Vector2 = camp["pos"]
				if sim.seen_at(cp):
					continue
				var q := _to_ui(cp)
				var rr := dot * 1.6
				for k in 8:
					var a := k * TAU / 8.0
					ci.draw_arc(q, rr, a, a + TAU / 16.0, 3, Color(0.95, 0.55, 0.4, 0.45), 1.5)
		# The lair: a red skull, always marked; on the corner disc it pins to
		# the rim in its direction when it is out of view.
		var lp := _to_ui(sim.map.lair)
		var found := sim.seen_at(sim.map.lair)
		var ls := dot * (2.6 if big else 2.2)
		if not _inside(lp, ls + 2.0):
			lp = c + (lp - c).normalized() * (DIAM * 0.5 - ls - 3.0)
		_skull(ci, lp, ls, found)
		if big:
			var font: Font = UiKit.font_b
			var pct := int(round(sim.explored() * 100.0))
			var line := "Explored %d%%   ·   Tap to close" % pct
			var lw := font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
			ci.draw_string(font, Vector2((r.size.x - lw) * 0.5, r.size.y + 56), line, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(0.95, 0.88, 0.72, 0.85))
		# The hero goes last, on top of the paper, the fog and every glyph.
		_hero_mark(ci)

	## A bright warm-white and gold arrowhead with a dark rim and a soft
	## pulsing halo, pointing where the hero moves (a plain dot when its
	## heading is unknown). Sized in device px at 1179 wide: ~6.5 canvas px
	## of radius on the corner disc.
	func _hero_mark(ci: CanvasItem) -> void:
		if sim.heroes.is_empty():
			return
		var h: RunSim.Actor = sim.heroes[0]
		var hp := _to_ui(h.pos)
		var hr := 6.5 if not big else 10.0
		var wave := 0.5 + 0.5 * sin(_pulse * TAU / 1.1)
		for k in 3:
			var a := (0.22 - float(k) * 0.06) * (0.45 + 0.55 * wave)
			ci.draw_circle(hp, hr * (1.3 + float(k) * 0.35), Color(1.0, 0.84, 0.45, a))
		var dir := Vector2.ZERO
		if h.vel.length_squared() > 1.0:
			dir = h.vel.normalized()
		elif not is_nan(h.facing):
			dir = Vector2.RIGHT.rotated(h.facing)
		if dir == Vector2.ZERO:
			ci.draw_circle(hp, hr * 1.22, Color(0.05, 0.03, 0.02, 0.92))
			ci.draw_circle(hp, hr, Color(1.0, 0.94, 0.76))
			ci.draw_circle(hp, hr * 0.45, Color(1.0, 0.78, 0.34, 0.9))
			return
		var pts := PackedVector2Array([hp + dir * hr, hp + dir.rotated(2.5) * hr * 0.8, hp - dir * hr * 0.45, hp + dir.rotated(-2.5) * hr * 0.8])
		var back := PackedVector2Array()
		var core := PackedVector2Array()
		for q: Vector2 in pts:
			back.append(hp + (q - hp) * 1.24)
			core.append(hp + (q - hp) * 0.5)
		ci.draw_colored_polygon(back, Color(0.05, 0.03, 0.02, 0.92))
		ci.draw_colored_polygon(pts, Color(1.0, 0.94, 0.76))
		ci.draw_colored_polygon(core, Color(1.0, 0.78, 0.34, 0.9))


## The DODGE button: a cast-bronze disc with a dash glyph in the lower-right
## thumb zone. A dark veil sweeps away as the cooldown refills, and a gold
## ring flashes when the roll becomes ready again.
class DodgeButton extends Control:
	var screen: Node
	var frac := 1.0
	var _flash := 0.0
	const DIAM := 92.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		_layout()
		get_viewport().size_changed.connect(_layout)

	func _layout() -> void:
		var view := get_viewport_rect().size
		var pad := UiKit.safe_insets()
		size = Vector2(DIAM, DIAM)
		# Left-handed: the dash flips to the left edge (the stick zone is the
		# whole bottom band, so it still plants under either thumb).
		var left := bool(AudioDirector.settings.get("left_handed", false))
		var x := float(pad["l"]) + 30.0 if left else view.x - float(pad["r"]) - DIAM - 30.0
		position = Vector2(x, view.y - float(pad["b"]) - DIAM - 34.0)
		queue_redraw()

	func _process(delta: float) -> void:
		if screen == null or screen.get("sim") == null:
			return
		var sim: RunSim = screen.get("sim")
		var now := sim.dodge_ready(0)
		if now >= 1.0 and frac < 1.0:
			_flash = 1.0
		_flash = maxf(0.0, _flash - delta * 2.4)
		frac = now
		queue_redraw()

	func _gui_input(event: InputEvent) -> void:
		var tap := (event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT) or (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed)
		if tap:
			accept_event()
			screen.call("_try_dodge")

	## Steel well, bronze rim lit from the top left, and twin chevrons for
	## the dash. While on cooldown the un-refilled part of the disc is veiled.
	func _draw() -> void:
		var c := Vector2(size.x * 0.5, size.y * 0.5)
		var r := size.x * 0.5 - 8.0
		draw_circle(c + Vector2(0, 3), r + 5.0, Color(0, 0, 0, 0.35))
		for k in 40:
			var a0 := TAU * k / 40.0
			var lit := 0.5 + 0.5 * cos(a0 + 2.36)
			var col := Color(0.3, 0.2, 0.1).lerp(Color(0.82, 0.6, 0.3), lit)
			draw_arc(c, r + 2.5, a0, a0 + TAU / 40.0 + 0.01, 3, col, 5.0, true)
		draw_arc(c, r + 5.5, 0.0, TAU, 48, Color(0.16, 0.09, 0.04, 0.9), 1.5, true)
		draw_arc(c, r - 0.5, 0.0, TAU, 48, Color(1.0, 0.88, 0.6, 0.5), 1.0, true)
		for k in 6:
			var t := float(k) / 5.0
			draw_circle(c, r * (1.0 - t * 0.55), Color(0.06, 0.08, 0.1, 0.62).lerp(Color(0.16, 0.2, 0.24, 0.7), t))
		if frac < 0.999:
			# Radial veil: covers the still-cooling slice and recedes clockwise.
			var a0 := -PI * 0.5
			var a1 := a0 + TAU * clampf(1.0 - frac, 0.0, 1.0)
			var pts := PackedVector2Array([c])
			for s in 27:
				pts.append(c + Vector2.RIGHT.rotated(a0 + (a1 - a0) * float(s) / 26.0) * r)
			draw_colored_polygon(pts, Color(0.05, 0.06, 0.08, 0.66))
		var glyph := Color(0.94, 0.87, 0.68, 0.95) if frac >= 0.999 else Color(0.6, 0.52, 0.4, 0.5)
		for side in 2:
			var off := Vector2(-8.0 + float(side) * 16.0, 2.0)
			draw_polyline(PackedVector2Array([
				c + off + Vector2(-6.5, -11.0),
				c + off + Vector2(6.5, 0.0),
				c + off + Vector2(-6.5, 11.0),
			]), glyph, 5.0, true)
		if _flash > 0.01:
			draw_arc(c, r + 2.5, 0.0, TAU, 40, Color(1.0, 0.85, 0.4, 0.7 * _flash), 3.5, true)


## The boss reveal name card: a dark leather panel in a forged bronze frame,
## the boss NAME in large gilded caps over its TITLE between thin gilt rules.
## It slides and fades in over 0.25 s, holds ~1.2 s, then fades out.
class BossNameCard extends Control:
	const CARD_H := 178.0
	var boss_name := ""
	var boss_title := ""
	var _rest_top := 0.0
	var _rest_bottom := CARD_H

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_rest_top = offset_top
		_rest_bottom = offset_bottom
		resized.connect(queue_redraw)

	func present(name_text: String, title_text: String) -> void:
		boss_name = name_text
		boss_title = title_text
		visible = true
		modulate.a = 0.0
		offset_top = _rest_top + 34.0
		offset_bottom = _rest_bottom + 34.0
		queue_redraw()
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(self, "modulate:a", 1.0, 0.25)
		tw.tween_property(self, "offset_top", _rest_top, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(self, "offset_bottom", _rest_bottom, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.set_parallel(false)
		tw.tween_interval(1.2)
		tw.tween_property(self, "modulate:a", 0.0, 0.35)
		tw.tween_callback(func() -> void: visible = false)

	func _draw() -> void:
		if boss_name == "" or size.x < 60.0 or size.y < 50.0:
			return
		var face := Rect2(Vector2(12, 12), size - Vector2(24, 24))
		UiKit.rr_shadow(self, face, 12.0, 12.0, 0.45)
		UiKit.rr_fill(self, face, 12.0, Color("322417"), Color("140f0b"))
		UiKit.rr_line(self, face, 12.0, Color("e2bb6a"), 3.5)
		UiKit.rr_line(self, face.grow(-5.0), 9.0, Color("8a6a3a"), 1.5)
		var fx := UiKit.font_x
		var name_px := clampi(int(size.y * 0.32), 30, 46)
		var name_base := face.position.y + 16.0 + fx.get_ascent(name_px)
		UiKit.draw_text(self, fx, Vector2(face.position.x, name_base), boss_name.to_upper(), name_px, Color("f6d98e"), Color("0e0906"), 3, face.size.x)
		var ft := UiKit.font_b
		var title_px := clampi(int(size.y * 0.15), 18, 26)
		var title_base := name_base + fx.get_height(name_px) * 0.32 + float(title_px)
		var tw := ft.get_string_size(boss_title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_px).x
		var mid := face.get_center().x
		var y := title_base - float(title_px) * 0.34
		_gilt_rule(face.position.x + 42.0, mid - tw * 0.5 - 28.0, y)
		_gilt_rule(mid + tw * 0.5 + 28.0, face.end.x - 42.0, y)
		UiKit.draw_text(self, ft, Vector2(face.position.x, title_base), boss_title, title_px, Color("e6d2a4"), Color("0e0906"), 2, face.size.x)

	## A thin bronze rule with a soft gold highlight, guarding the title.
	func _gilt_rule(x0: float, x1: float, y: float) -> void:
		if x1 <= x0:
			return
		draw_line(Vector2(x0, y), Vector2(x1, y), Color("c9a35a"), 2.0, true)
		draw_line(Vector2(x0, y), Vector2(x1, y), Color(1.0, 0.9, 0.62, 0.35), 0.8, true)


## Draws the minimap's frame and markers above its paper.
class Marks extends Control:
	var map: Control

	func _draw() -> void:
		map.call("draw_marks", self)
