extends ScreenBase

## Renders a RunSim. The thumbstick, cards, and taming live here.
## Simulation steps at a fixed 60Hz; sprites interpolate between steps.

const STEP := 1.0 / 60.0

var biome_id := "meadow"
var hero_id := "ember"
var sim: RunSim
var drive := Vector2.ZERO
var acc := 0.0
var hitstop := 0.0
var trauma := 0.0
var tame_p := 0.0
var hearts := 0
var committed := false
var summary: Dictionary = {}
var _modal_up := false
var _punch: Dictionary = {}
var _actor_sprites: Dictionary = {}
var _gem_sprites: Dictionary = {}
var _shot_sprites: Dictionary = {}

var world: Node2D
var arena: Sprite2D
var marks: GroundMarks
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
var clock_label: Label
var boss_label: Label
var banner: Label
var floats: Array = []
var finger := -1


func _init() -> void:
	paint_bg = false


func build() -> void:
	UiKit.ensure()
	world = Node2D.new()
	add_child(world)
	arena = Sprite2D.new()
	arena.centered = false
	world.add_child(arena)
	marks = GroundMarks.new()
	world.add_child(marks)
	actors_root = Node2D.new()
	world.add_child(actors_root)
	sparks = SparkLayer.new()
	world.add_child(sparks)
	var shade := TextureRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.texture = SpriteBank.vignette()
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.modulate = Color(1, 1, 1, 0.55)
	add_child(shade)
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
	var tex := SpriteBank.arena(biome_id)
	arena.texture = tex
	if tex.get_width() > 0:
		arena.scale = Vector2(720.0 / float(tex.get_width()), 1280.0 / float(tex.get_height()))
	var session := Session.solo(biome_id, hero_id)
	sim = RunSim.new()
	var stats := {}
	stats[hero_id] = SaveGame.build_run_stats(hero_id)
	sim.start(session, stats)
	marks.sim = sim
	level_label.text = Catalog.critter(hero_id)["name"]


func _build_hud() -> void:
	var pad := insets()
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
	level_label = UiKit.label("Hero", 26, Color("fff6ea"), "x", 6)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clock_label = UiKit.label("0:00", 26, Color("fff6ea"), "x", 6)
	var pause := UiKit.secondary("Pause", 130, 54)
	pause.pressed.connect(_pause)
	row.add_child(level_label)
	row.add_child(gap)
	row.add_child(clock_label)
	row.add_child(pause)
	top.add_child(row)
	hp_meter = Meter.new()
	hp_meter.fill = Color("e25b4a")
	hp_meter.custom_minimum_size = Vector2(0, 22)
	top.add_child(hp_meter)
	xp_meter = Meter.new()
	xp_meter.fill = Color("7dcea0")
	xp_meter.custom_minimum_size = Vector2(0, 12)
	top.add_child(xp_meter)
	boss_label = UiKit.label("", 24, Color("ffe08a"), "x", 6)
	boss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.add_child(boss_label)
	boss_meter = Meter.new()
	boss_meter.fill = Color("ffd15a")
	boss_meter.custom_minimum_size = Vector2(0, 18)
	boss_meter.visible = false
	top.add_child(boss_meter)
	banner = UiKit.label("", 36, Color("fff6ea"), "x", 8)
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
	dim.color = Color(0.12, 0.07, 0.05, 0.55)
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
	delta = minf(delta, 0.05)
	if hitstop > 0.0:
		hitstop = maxf(0.0, hitstop - delta)
		_hud()
		_sync(1.0)
		_tick_floats(0.0)
		return
	trauma = maxf(0.0, trauma - delta * 2.3)
	var mag := trauma * trauma * 11.0
	world.position = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * mag
	_decay_punch(delta)
	if not _modal_up and sim.result == "" and not sim.paused:
		acc += delta
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
	if not stick.active:
		stick.hint = maxf(0.0, stick.hint - delta * 0.12)
	stick.queue_redraw()


func _move() -> Vector2:
	if drive.length() > 0.05:
		return drive.normalized()
	if stick.active:
		return stick.vec
	var key := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		key.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		key.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		key.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		key.y += 1.0
	if key.length() > 1.0:
		return key.normalized()
	return key


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
	stick.vec = Vector2.ZERO
	stick.hint = 0.0
	stick.queue_redraw()


func _drag_stick(at: Vector2) -> void:
	var delta := at - stick.origin
	if delta.length() > 76.0:
		delta = delta.normalized() * 76.0
	stick.vec = delta / 76.0
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
	clock_label.text = "%d:%02d  Lv%d" % [secs / 60, secs % 60, sim.level]
	var show_boss := sim.phase == "boss" or sim.phase == "tame"
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
				AudioDirector.play_throttled("hit", 0.045)
			"hero_hurt":
				_float(ev["pos"], str(int(round(float(ev["amount"])))), Color("ff6d6d"), true)
				_punch[int(ev["id"])] = 0.14
				_hurt_flash()
				AudioDirector.play_throttled("hit", 0.05)
				AudioDirector.haptic(16)
			"die":
				var info := Catalog.critter(str(ev.get("sprite", "")))
				var col := Color(str(info.get("color", "ffb070"))) if not info.is_empty() else Color("ffb070")
				_burst(ev["pos"], col, 12, 180.0)
				AudioDirector.play_throttled("death", 0.06)
			"boom":
				_burst(ev["pos"], Color("ffb15a"), 10, 160.0)
			"attack":
				_punch[int(ev["id"])] = 0.2
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
					summary = SaveGame.commit_victory(biome_id, str(ev["id"]))
				AudioDirector.play("win")
				AudioDirector.haptic(30)
				_show_tame(str(ev["name"]))
			"hero_down":
				if not committed:
					committed = true
					SaveGame.commit_defeat(biome_id)
				AudioDirector.play("lose")
				_show_defeat(str(ev.get("reason", "")))
			"revive":
				_banner("Second wind!")
				AudioDirector.play("merge")
			"banner":
				_banner(str(ev["text"]))


func _sync(alpha: float) -> void:
	marks.alpha = alpha
	marks.tame_p = tame_p
	marks.queue_redraw()
	var seen := {}
	for actor in sim.actors:
		var show: bool = actor.alive or (actor.kind == "boss" and sim.phase == "tame")
		if not show:
			continue
		seen[actor.id] = true
		var sprite := _actor_sprite(actor.id, SpriteBank.critter(actor.sprite))
		var pos: Vector2 = actor.prev.lerp(actor.pos, alpha)
		var bob := sin(sim.time * 7.0 + float(actor.id)) * 2.6 if actor.alive else 0.0
		sprite.position = pos + Vector2(0.0, -bob)
		var tex_w := maxf(float(sprite.texture.get_width()), 1.0)
		var base := actor.radius * 3.4 / tex_w
		if actor.kind == "boss" and sim.phase == "tame":
			base *= lerpf(1.0, 0.4, tame_p)
		var punch := float(_punch.get(actor.id, 0.0))
		sprite.scale = Vector2(base * (1.0 + punch), base * (1.0 - punch * 0.5))
		sprite.modulate = Color(1.7, 1.7, 1.7) if actor.flash > 0.0 else Color.WHITE
		sprite.z_index = int(pos.y)
		sprite.visible = true
	for id in _actor_sprites.keys():
		if not seen.has(id):
			_actor_sprites[id].visible = false
	var seen_gems := {}
	for gem in sim.gems:
		if not gem.alive:
			continue
		var gid := gem.get_instance_id()
		seen_gems[gid] = true
		var sprite := _pooled(_gem_sprites, gid, SpriteBank.fx("gem"))
		var pos: Vector2 = gem.prev.lerp(gem.pos, alpha)
		sprite.position = pos + Vector2(0.0, sin(gem.bob) * 4.0)
		sprite.scale = Vector2.ONE * 0.42
		sprite.rotation = 0.0
		sprite.modulate = Color.WHITE
		sprite.visible = true
		sprite.z_index = int(pos.y)
	for id in _gem_sprites.keys():
		if not seen_gems.has(id):
			_gem_sprites[id].visible = false
	var seen_shots := {}
	for shot in sim.shots:
		if not shot.alive:
			continue
		var sid := shot.get_instance_id()
		seen_shots[sid] = true
		var kind := "arrow" if shot.kind == "arrow" else "orb"
		var sprite := _pooled(_shot_sprites, sid, SpriteBank.fx(kind))
		sprite.position = shot.prev.lerp(shot.pos, alpha)
		if shot.kind == "arrow":
			sprite.rotation = shot.vel.angle()
			sprite.scale = Vector2(0.5, 0.5)
			sprite.modulate = Color.WHITE
		else:
			sprite.rotation = 0.0
			sprite.scale = Vector2.ONE * (0.62 if shot.kind == "bash" else 0.48)
			if shot.kind == "enemy":
				sprite.modulate = Color(1.0, 0.45, 0.32)
			elif shot.kind == "bash":
				sprite.modulate = Color(1.0, 0.92, 0.55)
			else:
				sprite.modulate = Color(1.0, 0.62, 0.28)
		sprite.visible = true
		sprite.z_index = 4000
	for id in _shot_sprites.keys():
		if not seen_shots.has(id):
			_shot_sprites[id].visible = false


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
	label.position = pos + Vector2(randf_range(-18, 18), -36)
	label.modulate = Color(1, 1, 1, 1)
	label.z_index = 4096
	label.add_theme_font_override("font", UiKit.font_x)
	label.add_theme_font_size_override("font_size", 34 if big else 22)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.12, 0.05, 0.04, 0.92))
	label.add_theme_constant_override("outline_size", 6)
	label.set_meta("life", 0.7)


func _tick_floats(delta: float) -> void:
	for label in floats:
		if not label.visible:
			continue
		var life := float(label.get_meta("life")) - delta
		label.set_meta("life", life)
		label.position.y -= 48.0 * delta
		label.modulate.a = clampf(life / 0.28, 0.0, 1.0)
		if life <= 0.0:
			label.visible = false


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
	var title := UiKit.label("Level %d" % level_n, 40, Color("fff6ea"), "x", 8)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	modal_box.add_child(title)
	var sub := UiKit.label("Pick a blessing", 22, Color("ffe0bf"), "m", 0)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	modal_box.add_child(sub)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	modal_box.add_child(row)
	for i in offer.size():
		row.add_child(_offer_card(i, str(offer[i])))


func _offer_card(index: int, id: String) -> Button:
	var card := Catalog.card(id)
	var button := Button.new()
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(190, 300)
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.add_theme_font_override("font", UiKit.font_b)
	button.add_theme_font_size_override("font_size", 22)
	button.add_theme_color_override("font_color", Color("3a241c"))
	button.add_theme_color_override("font_hover_color", Color("3a241c"))
	button.add_theme_color_override("font_pressed_color", Color("3a241c"))
	button.text = "%s\n\n%s\n\n%s" % [Catalog.rarity_name(str(card.get("rarity", "common"))), str(card.get("name", id)), str(card.get("desc", ""))]
	var box := UiKit.rarity_box(str(card.get("rarity", "common")))
	button.add_theme_stylebox_override("normal", box)
	button.add_theme_stylebox_override("hover", box)
	button.add_theme_stylebox_override("pressed", box)
	button.add_theme_stylebox_override("focus", box)
	button.pressed.connect(_pick.bind(index))
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


func _show_tame(boss_name: String) -> void:
	hearts = 0
	tame_p = 0.0
	_open_modal()
	var title := UiKit.label("%s is calm" % boss_name, 40, Color("fff6ea"), "x", 8)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	modal_box.add_child(title)
	var face := portrait(sim.boss.sprite if sim.boss else hero_id, 180)
	face.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	modal_box.add_child(face)
	var sub := UiKit.label("Tap the hearts to tame.", 22, Color("ffe0bf"), "m", 0)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	modal_box.add_child(sub)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	modal_box.add_child(row)
	for _i in 3:
		var heart := UiKit.button("♥", 120, 110)
		heart.pressed.connect(_tap_heart.bind(heart, boss_name))
		row.add_child(heart)


func _tap_heart(button: Button, boss_name: String) -> void:
	if button.disabled:
		return
	button.disabled = true
	button.text = "♥"
	hearts += 1
	tame_p = float(hearts) / 3.0
	AudioDirector.play("merge")
	AudioDirector.haptic(12)
	if sim.boss:
		_burst(sim.boss.pos, Color("ff8fb0"), 8, 120.0)
	if hearts >= 3:
		_show_victory(boss_name)


func _show_victory(boss_name: String) -> void:
	_open_modal()
	var already := bool(summary.get("already", false))
	var title := UiKit.label("Tamed", 44, Color("fff6ea"), "x", 8)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	modal_box.add_child(title)
	var line := "%s bonded closer." % boss_name if already else "%s joined your collection." % boss_name
	var sub := UiKit.label(line, 24, Color("ffe0bf"), "b", 0)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	modal_box.add_child(sub)
	var trophies := UiKit.label("+%d trophies" % int(summary.get("trophies", 0)), 28, Color("ffe08a"), "x", 6)
	trophies.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	modal_box.add_child(trophies)
	var button := UiKit.button("Open the chest", 460, 86)
	button.pressed.connect(func() -> void: go("chest"))
	modal_box.add_child(button)


func _show_defeat(reason: String) -> void:
	_open_modal()
	var title := UiKit.label("Bounced out", 44, Color("fff6ea"), "x", 8)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	modal_box.add_child(title)
	var line := "The wilds outlasted you." if reason == "time" else "The wilds were a bit much."
	var sub := UiKit.label(line, 24, Color("ffe0bf"), "m", 0)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	modal_box.add_child(sub)
	var button := UiKit.button("Open the pouch", 460, 86)
	button.pressed.connect(func() -> void: go("chest"))
	modal_box.add_child(button)


func _pause() -> void:
	if _modal_up or sim == null or sim.result != "":
		return
	_open_modal()
	var title := UiKit.label("Paused", 44, Color("fff6ea"), "x", 8)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	modal_box.add_child(title)
	var resume := UiKit.button("Resume", 420, 80)
	resume.pressed.connect(_close_modal)
	modal_box.add_child(resume)
	var leave := UiKit.secondary("Leave hunt", 420, 70)
	leave.pressed.connect(func() -> void: go("home"))
	modal_box.add_child(leave)


class Meter extends Control:
	var ratio := 1.0
	var fill := Color("e25b4a")

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.16, 0.08, 0.05, 0.55), true)
		var width := maxf(0.0, (size.x - 6.0) * clampf(ratio, 0.0, 1.0))
		draw_rect(Rect2(3, 3, width, maxf(0.0, size.y - 6.0)), fill, true)


class StickLayer extends Control:
	var active := false
	var origin := Vector2.ZERO
	var vec := Vector2.ZERO
	var hint := 1.0

	func _draw() -> void:
		if size.y < 10.0:
			return
		if active:
			draw_circle(origin, 76.0, Color(1, 1, 1, 0.16))
			draw_arc(origin, 76.0, 0, TAU, 36, Color(1, 1, 1, 0.7), 4.0, true)
			draw_circle(origin + vec * 70.0, 30.0, Color(1, 1, 1, 0.92))
		elif hint > 0.04:
			UiKit.ensure()
			var text := "Drag to steer"
			var width := 220.0
			draw_string(UiKit.font_b, Vector2(size.x * 0.5 - width * 0.5, size.y * 0.78), text, HORIZONTAL_ALIGNMENT_LEFT, width, 28, Color(1, 1, 1, 0.7 * hint))


class GroundMarks extends Node2D:
	var sim: RunSim
	var alpha := 1.0
	var tame_p := 0.0

	func _draw() -> void:
		if sim == null:
			return
		var shadow := SpriteBank.fx("shadow")
		for actor in sim.actors:
			var show: bool = actor.alive or (actor.kind == "boss" and sim.phase == "tame")
			if not show:
				continue
			var pos: Vector2 = actor.prev.lerp(actor.pos, alpha)
			var w := actor.radius * 2.1
			draw_texture_rect(shadow, Rect2(pos.x - w, pos.y + actor.radius * 0.2, w * 2.0, w * 0.7), false, Color(1, 1, 1, 0.42))
			if actor.kind != "hero" and actor.alive and actor.max_hp > 0.0:
				var width := 34.0 if actor.kind != "boss" else 70.0
				var y := pos.y - actor.radius * 1.55
				var t := clampf(actor.hp / actor.max_hp, 0.0, 1.0)
				draw_rect(Rect2(pos.x - width, y, width * 2.0, 7.0), Color(0, 0, 0, 0.45), true)
				var col := Color("ffd15a") if actor.kind == "boss" else Color("ff6d5a")
				draw_rect(Rect2(pos.x - width, y, width * 2.0 * t, 7.0), col, true)
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
