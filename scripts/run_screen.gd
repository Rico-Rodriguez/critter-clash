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
var pet_follow := ""
var pet_pos := Vector2.ZERO
var pet_ready := false
var summary: Dictionary = {}
var _modal_up := false
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
var name_label: Label
var hero_medal: UiKit.Medal
var clock_label: Label
var boss_label: Label
var banner: Label
var floats: Array = []
var finger := -1
var finger_at := Vector2.ZERO
var _stick_out := Vector2.ZERO


func _init() -> void:
	paint_bg = false


func build() -> void:
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
	shade.modulate = Color(1, 1, 1, 0.55)
	add_child(shade)
	threats = ThreatLayer.new()
	threats.screen = self
	threats.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	threats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(threats)
	_build_hud()
	stick = StickLayer.new()
	stick.set_anchors_preset(Control.PRESET_FULL_RECT)
	stick.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stick)
	flash_rect = ColorRect.new()
	flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash_rect.color = Color(1, 0.2, 0.15, 0)
	add_child(flash_rect)
	_build_modal()


func open(args: Dictionary = {}) -> void:
	biome_id = str(args.get("biome", "meadow"))
	hero_id = str(args.get("hero", "ember"))
	var session := Session.solo(biome_id, hero_id)
	sim = RunSim.new()
	var stats := {}
	stats[hero_id] = SaveGame.build_run_stats(hero_id)
	sim.start(session, stats)
	cam = HuntCamera.new()
	var hero_at := sim.play.get_center()
	if not sim.heroes.is_empty():
		hero_at = sim.heroes[0].pos
	cam.setup(sim.map, hero_at)
	stream.sync(sim.map, cam.view_rect())
	stage.bind_hunt(biome_id)
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
	var lvl := UiKit.Plate.new()
	lvl.kind = "plaque"
	lvl.pad = 6
	lvl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	level_label = UiKit.label("1", 24, UiKit.GOLD.lightened(0.2), "x", 3)
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_label.custom_minimum_size = Vector2(34, 0)
	lvl.add_child(level_label)
	xp_row.add_child(lvl)
	xp_meter = Meter.new()
	xp_meter.fill = Color("3fb8a0")
	xp_meter.custom_minimum_size = Vector2(0, 20)
	xp_meter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	xp_meter.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	xp_row.add_child(xp_meter)
	top.add_child(xp_row)
	boss_label = UiKit.label("", 28, UiKit.GOLD.lightened(0.2), "x", 4)
	boss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_label.visible = false
	top.add_child(boss_label)
	boss_meter = Meter.new()
	boss_meter.fill = Color("b8241c")
	boss_meter.ornate = true
	boss_meter.custom_minimum_size = Vector2(0, 30)
	boss_meter.visible = false
	var boss_wrap := MarginContainer.new()
	boss_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boss_wrap.add_theme_constant_override("margin_left", 30)
	boss_wrap.add_theme_constant_override("margin_right", 30)
	boss_wrap.add_child(boss_meter)
	top.add_child(boss_wrap)
	banner = UiKit.label("", 38, UiKit.GOLD.lightened(0.25), "x", 4)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.modulate.a = 0.0
	top.add_child(banner)


func _build_modal() -> void:
	modal = Control.new()
	modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal.visible = false
	modal.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(modal)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.05, 0.14, 0.78)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	modal.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	modal.add_child(center)
	modal_box = VBoxContainer.new()
	modal_box.custom_minimum_size = Vector2(640, 0)
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
	var mag := trauma * trauma * 11.0
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
		if mouse.pressed and mouse.position.y > limit:
			finger = -2
			_begin_stick(mouse.position)
		elif not mouse.pressed and finger == -2:
			_end_stick()
	elif event is InputEventMouseMotion and finger == -2 and stick.active:
		_drag_stick((event as InputEventMouseMotion).position)


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
	var show_boss := sim.phase == "boss"
	boss_meter.visible = show_boss and sim.boss != null
	boss_label.visible = show_boss and sim.boss != null
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
				var crit := bool(ev.get("crit", false))
				_float(ev["pos"], str(int(round(float(ev["amount"])))), Color("ffe08a") if crit else Color("fff8ee"), crit)
				_burst(ev["pos"], Color("ffe08a") if crit else Color("fff6ea"), 8 if crit else 5, 150.0)
				_punch[int(ev["id"])] = 0.16
				stage.hurt(int(ev["id"]))
				AudioDirector.play_throttled("hit", 0.045)
			"hero_hurt":
				_float(ev["pos"], str(int(round(float(ev["amount"])))), Color("ff6d6d"), true)
				_punch[int(ev["id"])] = 0.14
				stage.hurt(int(ev["id"]))
				_hurt_flash()
				AudioDirector.play_throttled("hit", 0.05)
				AudioDirector.haptic(16)
			"die":
				var info := Catalog.critter(str(ev.get("sprite", "")))
				var col := Color(str(info.get("color", "ffb070"))) if not info.is_empty() else Color("ffb070")
				_burst(ev["pos"], col, 12, 180.0)
				stage.died(int(ev["id"]), ev["pos"], str(ev.get("sprite", "")))
				AudioDirector.play_throttled("death", 0.06)
			"boom":
				_burst(ev["pos"], Color("ffb15a"), 10, 160.0)
			"attack":
				_punch[int(ev["id"])] = 0.2
				stage.attack(int(ev["id"]))
				AudioDirector.play_throttled("shoot", 0.05)
			"gem":
				_burst(ev["pos"], Color("b6f27a"), 4, 90.0)
				AudioDirector.play_throttled("deploy", 0.06)
			"levelup":
				AudioDirector.play("merge")
				AudioDirector.haptic(18)
				_show_levelup(int(ev["level"]), ev["offer"])
			"boss_in":
				_banner("%s awakens" % str(ev["name"]))
				AudioDirector.play("den")
				AudioDirector.haptic(24)
			"boss_down":
				if not committed:
					committed = true
					summary = SaveGame.commit_victory(biome_id, str(ev["id"]), sim.slain)
				AudioDirector.haptic(30)
				var reveal: Dictionary = summary.get("reveal", {})
				if reveal.is_empty():
					AudioDirector.play("win")
					_show_victory(str(ev["name"]))
				else:
					_show_rare(reveal, str(ev["name"]))
			"hero_down":
				if not committed:
					committed = true
					SaveGame.commit_defeat(biome_id, sim.slain)
				AudioDirector.play("lose")
				_show_defeat(str(ev.get("reason", "")))
			"revive":
				_banner("Second wind!")
				AudioDirector.play("merge")
			"banner":
				_banner(str(ev["text"]))


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


func _hurt_flash() -> void:
	flash_rect.color = Color(1, 0.25, 0.18, 0.32)
	var tw := create_tween()
	tw.tween_property(flash_rect, "color:a", 0.0, 0.2)


func _banner(text: String) -> void:
	banner.text = text
	banner.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(0.85)
	tw.tween_property(banner, "modulate:a", 0.0, 0.35)


func _float(pos: Vector2, text: String, color: Color, big: bool) -> void:
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
	UiKit.ensure()
	label.visible = true
	label.text = text
	label.modulate = Color(1, 1, 1, 1)
	label.z_index = 4096
	label.add_theme_font_override("font", UiKit.font_x)
	label.add_theme_font_size_override("font_size", 40 if big else 28)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", UiKit.INK)
	label.add_theme_constant_override("outline_size", 8 if big else 6)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.45))
	label.add_theme_constant_override("shadow_offset_y", 3)
	label.pivot_offset = Vector2(18, 16)
	label.scale = Vector2(1.45, 1.45)
	var pop := create_tween()
	pop.tween_property(label, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var lift := Vector2(randf_range(-18, 18), -36)
	label.set_meta("sim", pos)
	label.set_meta("lift", lift)
	label.position = _projected(pos) + lift
	label.set_meta("life", 0.7)


func _tick_floats(delta: float) -> void:
	for label in floats:
		if not label.visible:
			continue
		var life := float(label.get_meta("life")) - delta
		label.set_meta("life", life)
		var lift: Vector2 = label.get_meta("lift")
		lift.y -= 48.0 * delta
		label.set_meta("lift", lift)
		label.position = _projected(label.get_meta("sim")) + lift
		label.modulate.a = clampf(life / 0.28, 0.0, 1.0)
		if life <= 0.0:
			label.visible = false


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
	row.add_theme_constant_override("separation", 14)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	modal_box.add_child(row)
	for i in offer.size():
		var card := _offer_card(i, str(offer[i]))
		row.add_child(card)
		card.pivot_offset = Vector2(95, 160)
		card.scale = Vector2(0.08, 1.0)
		var tw := create_tween()
		tw.tween_interval(0.06 * float(i))
		tw.tween_property(card, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _offer_card(index: int, id: String) -> Button:
	var info := Catalog.card(id)
	var rarity := str(info.get("rarity", "common"))
	var button := OfferCard.new()
	button.rarity = rarity
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(210, 330)
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
	icon.custom_minimum_size = Vector2(0, 132)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(icon)
	var name := UiKit.label(str(info.get("name", id)), 22, UiKit.GOLD.lightened(0.2), "x", 3)
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(name)
	var desc := UiKit.label(str(info.get("desc", "")), 17, UiKit.MUTED.lightened(0.15), "m", 2)
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(desc)
	return button


func _pick(index: int) -> void:
	if sim == null:
		return
	var nxt: Array = sim.choose(index)
	AudioDirector.play("click")
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
	AudioDirector.play("win")
	AudioDirector.play("den", -4.0)
	AudioDirector.haptic(30)


func _show_victory(boss_name: String) -> void:
	_open_modal()
	var title := UiKit.title("VICTORY", 52)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	modal_box.add_child(title)
	var sub := UiKit.label("%s dropped loot." % boss_name, 24, Color("ffe7b0"), "x", 4)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	modal_box.add_child(sub)
	var drops: Array = summary.get("drops", [])
	for drop in drops:
		var line := UiKit.label(str(drop.get("name", "Drop")), 22, Color("ffe08a"), "x", 4)
		line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		modal_box.add_child(line)
	var trophies := UiKit.label("+%d trophies" % int(summary.get("trophies", 0)), 28, Color("ffe08a"), "x", 6)
	trophies.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	modal_box.add_child(trophies)
	var button := UiKit.button("Open the chest", 460, 86)
	button.pressed.connect(func() -> void: go("chest"))
	modal_box.add_child(button)


func _show_defeat(reason: String) -> void:
	_open_modal()
	var title := UiKit.title("BOUNCED OUT", 44)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	modal_box.add_child(title)
	var line := "The wilds outlasted you." if reason == "time" else "The wilds were a bit much."
	var sub := UiKit.label(line, 24, Color("ffe7b0"), "x", 4)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	modal_box.add_child(sub)
	var button := UiKit.button("Open the pouch", 460, 86)
	button.pressed.connect(func() -> void: go("chest"))
	modal_box.add_child(button)


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


## A level-up blessing: a forged card in its rarity's metal over dark leather,
## with a soft aura and a press bounce.
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
			"metal_hi": metal[0], "metal_lo": metal[1], "studs": 1.0, "frame": 7.0,
			"glow_color": Color(cols["glow"], 0.45 if rarity != "common" else 0.15),
			"face_top": Color(cols["bg"]).lerp(Color("1c1510"), 0.35), "face_bot": Color("0c0907"),
		})
		frame.margin = 4.0
		add_child(frame)
		button_down.connect(func() -> void:
			pivot_offset = size * 0.5
			create_tween().tween_property(self, "scale", Vector2(0.95, 0.95), 0.06))
		button_up.connect(func() -> void:
			create_tween().tween_property(self, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT))


class CardIcon extends Control:
	var op := ""

	var rarity := "common"
	var _shadow := false

	func _draw() -> void:
		var c := Vector2(size.x * 0.5, size.y * 0.52)
		var metal := UiKit.rarity_metal(rarity)
		var glow: Color = UiKit.rarity_colors(rarity)["glow"]
		for k in 6:
			draw_circle(c, 62.0 - k * 2.5, Color(glow, 0.035))
		draw_circle(c + Vector2(0, 5), 54, Color(0, 0, 0, 0.55))
		draw_circle(c, 52, Color("120a04"))
		draw_arc(c, 48, 0, TAU, 48, metal[1], 7.0, true)
		draw_arc(c, 48, PI * 1.05, PI * 1.95, 24, metal[0], 3.0, true)
		draw_circle(c, 44, Color("0c0806"))
		for k in 5:
			draw_circle(c, 40.0 - k * 7.0, Color(glow, 0.06))
		# Cast shadow first, then the glyph in muted, metal-leaning colour.
		_shadow = true
		draw_set_transform(Vector2(0, 4))
		_glyphs(c)
		draw_set_transform(Vector2.ZERO)
		_shadow = false
		_glyphs(c)

	func _tone(col: Color) -> Color:
		if _shadow:
			return Color(0, 0, 0, 0.6)
		return col.lerp(Color("e2c48a"), 0.28).darkened(0.05)

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
		UiKit.rr_fill(self, r.grow(2), rad + 2, Color(0, 0, 0, 0.6), Color(0, 0, 0, 0.6))
		UiKit.rr_fill(self, r, rad, Color("e8c886"), Color("4e3012"))
		var inner := r.grow(-3)
		UiKit.rr_fill(self, inner, rad - 3, Color("080605"), Color("1c1510"))
		var bar := inner.grow(-2)
		var ghost_w := bar.size.x * clampf(_ghost, 0.0, 1.0)
		if ghost_w > bar.size.y * 0.6:
			UiKit.rr_fill(self, Rect2(bar.position, Vector2(ghost_w, bar.size.y)), bar.size.y * 0.5, Color(1, 0.92, 0.8, 0.55), Color(1, 0.8, 0.6, 0.4))
		var width := bar.size.x * clampf(ratio, 0.0, 1.0)
		if width > bar.size.y * 0.6:
			var fr := Rect2(bar.position, Vector2(width, bar.size.y))
			UiKit.rr_fill(self, fr, bar.size.y * 0.5, fill.lightened(0.25), fill.darkened(0.45))
			UiKit.rr_fill(self, Rect2(fr.position + Vector2(3, 1), Vector2(fr.size.x - 6, fr.size.y * 0.38)), fr.size.y * 0.2, Color(1, 1, 1, 0.32), Color(1, 1, 1, 0.0))
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
			draw_circle(origin, RADIUS, Color(1, 1, 1, 0.16))
			draw_arc(origin, RADIUS, 0, TAU, 36, Color(1, 1, 1, 0.7), 4.0, true)
			draw_circle(knob, 22.0, Color(1, 1, 1, 0.92))
		elif hint > 0.04:
			UiKit.ensure()
			var text := "Drag to steer"
			var width := 220.0
			draw_string(UiKit.font_x, Vector2(size.x * 0.5 - width * 0.5, size.y * 0.78), text, HORIZONTAL_ALIGNMENT_LEFT, width, 28, Color(1, 1, 1, 0.85 * hint))


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
			var pos: Vector2 = actor.prev.lerp(actor.pos, alpha)
			var boss: bool = actor.kind == "boss"
			var head_h: float = Stage3D.BOSS_METERS * 1.05 if boss else Stage3D.HERO_METERS * 0.95
			var foot := get_global_transform().affine_inverse() * stage.project(pos, 0.0)
			var head := get_global_transform().affine_inverse() * stage.project(pos, head_h)
			if Rect2(Vector2.ZERO, size).grow(-8.0).has_point(foot):
				if not boss and actor.max_hp > 0.0 and actor.hp < actor.max_hp:
					_bar(head + Vector2(0, -10), clampf(actor.hp / actor.max_hp, 0.0, 1.0))
			else:
				offscreen.append([foot, boss])
		for item in offscreen:
			_arrow(center, item[0], band, item[1])

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
		var s := 26.0 if boss else 15.0
		s *= 1.0 + 0.08 * sin(t * 6.0)
		var side := dir.orthogonal()
		var tip := at + dir * s
		var pts := PackedVector2Array([tip, at - dir * s * 0.4 + side * s * 0.8, at - dir * s * 0.1, at - dir * s * 0.4 - side * s * 0.8])
		var glow := Color(1.0, 0.25, 0.15, 0.35) if boss else Color(0.95, 0.3, 0.2, 0.22)
		draw_circle(at, s * 1.15, glow)
		var outline := PackedVector2Array(pts)
		outline.append(pts[0])
		draw_colored_polygon(pts, Color("e8462e") if boss else Color("d9a441"))
		draw_polyline(outline, Color(0.12, 0.04, 0.02, 0.95), 3.0, true)
		if boss:
			draw_circle(at - dir * s * 0.9, 7.0, Color("f3d9a0"))
