extends RefCounted
## Shared motion kit for menus: shine, pulses, bobbing, deal-in, coin fly-ins,
## count-ups and living page backdrops. Use via
## `const FxUi := preload("res://src/ui/fx_ui.gd")`.
## Loops are tweens bound to the node they move, so they die with it.

const GLOSS := preload("res://src/fx/ui_gloss.gdshader")
const BACKDROP := preload("res://src/fx/ui_backdrop.gdshader")
const RAYS := preload("res://src/fx/ui_rays.gdshader")

static var _dot: Texture2D


## A soft highlight and a shine band sweeping across `c` every `period`
## seconds. Returns the overlay so callers can retune it.
static func gloss(c: Control, radius := 18.0, sweep := 0.5, period := 3.4, offset := 0.0) -> ColorRect:
	var r := c.get_node_or_null("Gloss") as ColorRect
	if r == null:
		r = ColorRect.new()
		r.name = "Gloss"
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		r.material = ShaderMaterial.new()
		r.material.shader = GLOSS
		c.add_child(r)
		var fit := func() -> void:
			(r.material as ShaderMaterial).set_shader_parameter("rect_size", r.size)
		r.resized.connect(fit)
		fit.call()
	var m := r.material as ShaderMaterial
	m.set_shader_parameter("radius", radius)
	m.set_shader_parameter("sweep", sweep)
	m.set_shader_parameter("period", period)
	m.set_shader_parameter("offset", offset)
	return r


## Turning light rays drawn on `host` under its content, centered on
## `around` (a featured item inside it), `reach` times that item's size.
static func rays(host: Control, around: Control, tint := Color(1.0, 0.8, 0.4), reach := 2.2, strength := 0.35) -> ColorRect:
	var r := ColorRect.new()
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = RAYS
	m.set_shader_parameter("tint", tint)
	m.set_shader_parameter("strength", strength)
	r.material = m
	host.add_child(r)
	host.move_child(r, 0)
	# Containers settle sizes over a frame or two, so it follows both.
	var fit := func() -> void:
		var side := maxf(around.size.x, around.size.y) * reach
		r.size = Vector2(side, side)
		r.global_position = around.get_global_rect().get_center() - r.size * 0.5
	host.resized.connect(fit)
	around.resized.connect(fit)
	around.item_rect_changed.connect(fit)
	fit.call_deferred()
	return r


## A soft glow in `tint` behind `around` (an item on a card), drawn on `host`
## under its content.
static func halo(host: Control, around: Control, tint: Color, reach := 1.8) -> TextureRect:
	var r := TextureRect.new()
	r.texture = _dot_texture()
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.modulate = Color(tint, 0.38)
	host.add_child(r)
	host.move_child(r, 0)
	var fit := func() -> void:
		var side := maxf(around.size.x, around.size.y) * reach
		r.size = Vector2(side, side)
		r.global_position = around.get_global_rect().get_center() - r.size * 0.5
	host.resized.connect(fit)
	around.resized.connect(fit)
	around.item_rect_changed.connect(fit)
	fit.call_deferred()
	return r


## A slow misty gradient with motes drifting up, behind everything in `c`.
static func backdrop(c: Control, top := Color(0.11, 0.085, 0.06), bottom := Color(0.043, 0.043, 0.051),
		mist := Color(0.5, 0.33, 0.18), motes := Color(1.0, 0.78, 0.45, 0.55)) -> Control:
	var host := Control.new()
	host.name = "Backdrop"
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.show_behind_parent = true
	var r := ColorRect.new()
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var m := ShaderMaterial.new()
	m.shader = BACKDROP
	m.set_shader_parameter("top_color", top)
	m.set_shader_parameter("bottom_color", bottom)
	m.set_shader_parameter("mist_color", mist)
	r.material = m
	host.add_child(r)
	add_motes(host, motes)
	c.add_child(host)
	c.move_child(host, 0)
	return host


## Embers or dust rising through `c`. Kept sparse: a menu, not a bonfire.
static func add_motes(c: Control, color := Color(1.0, 0.78, 0.45, 0.55), amount := 22, rise := 26.0) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.name = "Motes"
	p.texture = _dot_texture()
	p.amount = amount
	p.lifetime = 9.0
	p.preprocess = 9.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.direction = Vector2(0, -1)
	p.spread = 20.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = rise * 0.5
	p.initial_velocity_max = rise * 1.3
	p.scale_amount_min = 0.25
	p.scale_amount_max = 0.7
	p.color = color
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 0))
	ramp.set_color(1, Color(1, 1, 1, 0))
	ramp.add_point(0.2, Color.WHITE)
	ramp.add_point(0.75, Color(1, 1, 1, 0.8))
	p.color_ramp = ramp
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	p.material = mat
	c.add_child(p)
	var fit := func() -> void:
		p.position = c.size * 0.5
		p.emission_rect_extents = c.size * 0.5
	c.resized.connect(fit)
	fit.call()
	return p


## A soft round glow, filling its parent, for light behind an icon.
static func glow_dot(tint: Color, alpha := 1.0) -> TextureRect:
	var r := TextureRect.new()
	r.texture = _dot_texture()
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.modulate = Color(tint, alpha)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


static func dot_texture() -> Texture2D:
	return _dot_texture()


static func _dot_texture() -> Texture2D:
	if _dot == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 32
		t.height = 32
		_dot = t
	return _dot


static func _center(c: Control) -> void:
	c.pivot_offset = c.size * 0.5
	if not c.has_meta("fx_pivot"):
		c.set_meta("fx_pivot", true)
		c.resized.connect(func() -> void: c.pivot_offset = c.size * 0.5)


## Breathes `c` in and out, for badges and anything waiting to be claimed.
static func pulse(c: Control, amount := 1.14, period := 1.4) -> Tween:
	_center(c)
	_stop(c, "pulse")
	var t := c.create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(c, "scale", Vector2.ONE * amount, period * 0.5)
	t.tween_property(c, "scale", Vector2.ONE, period * 0.5)
	c.set_meta("fx_pulse", t)
	return t


## A gentle sway, for chests and icons on display. Scale and rotation only:
## containers own position.
static func bob(c: Control, degrees := 4.0, period := 2.4, offset := 0.0) -> Tween:
	_center(c)
	_stop(c, "bob")
	c.rotation_degrees = -degrees
	var t := c.create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if offset > 0.0:
		t.tween_interval(offset)
		offset = 0.0
	t.tween_property(c, "rotation_degrees", degrees, period * 0.5)
	t.parallel().tween_property(c, "scale", Vector2.ONE * 1.05, period * 0.5)
	t.tween_property(c, "rotation_degrees", -degrees, period * 0.5)
	t.parallel().tween_property(c, "scale", Vector2.ONE, period * 0.5)
	c.set_meta("fx_bob", t)
	return t


## A rattle every few seconds: a chest that is ready to open.
static func shake(c: Control, every := 2.2) -> Tween:
	_center(c)
	_stop(c, "shake")
	var t := c.create_tween().set_loops()
	t.tween_interval(every)
	# A "this is ready" cue, not screen shake: it follows the setting but stays visible.
	var k := 0.35 + 0.65 * Game.shake_amp()
	for d in [-9.0, 9.0, -6.0, 5.0, 0.0]:
		t.tween_property(c, "rotation_degrees", d * k, 0.07)
	c.set_meta("fx_shake", t)
	return t


## Ends a loop started by pulse, bob or shake and settles the control.
static func still(c: Control) -> void:
	for k in ["pulse", "bob", "shake"]:
		_stop(c, k)
	c.rotation = 0.0
	c.scale = Vector2.ONE


static func _stop(c: Control, key: String) -> void:
	var k := "fx_" + key
	if c.has_meta(k):
		var t: Tween = c.get_meta(k)
		if t and t.is_valid():
			t.kill()
		c.remove_meta(k)


## The visible children of `box` arrive one after another.
static func deal_in(box: Node, step := 0.045, from_scale := 0.86) -> void:
	var i := 0
	for n in box.get_children():
		var c := n as Control
		if c == null or not c.visible:
			continue
		c.modulate.a = 0.0
		c.scale = Vector2.ONE * from_scale
		var t := c.create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		# Sizes settle a frame later inside containers.
		t.tween_callback(func() -> void: c.pivot_offset = c.size * 0.5).set_delay(minf(i * step, 0.6))
		t.tween_property(c, "modulate:a", 1.0, 0.2).set_delay(minf(i * step, 0.6))
		t.tween_property(c, "scale", Vector2.ONE, 0.34).set_delay(minf(i * step, 0.6))
		i += 1


## A quick swell, for a number that just changed.
static func pop(c: Control, amount := 1.25) -> void:
	_center(c)
	var t := c.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(c, "scale", Vector2.ONE * amount, 0.08)
	t.tween_property(c, "scale", Vector2.ONE, 0.25)


## Counts `l` from one number to another, formatted like every other count.
static func count_to(l: Label, from: int, to: int, dur := 0.7) -> Tween:
	var t := l.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_method(func(v: float) -> void: l.text = Ui.fmt_num(int(v)), float(from), float(to), dur)
	t.tween_callback(pop.bind(l, 1.2))
	return t


## Coins burst from `from` (global position) and fly into `to`, which pops as
## each lands. `host` is a full-screen control above everything else.
static func coin_fly(host: Control, from: Vector2, to: Control, n := 8, icon := "two-coins", tint := Color(1.0, 0.84, 0.4)) -> void:
	var end := to.get_global_rect().get_center() - host.get_global_rect().position
	var start := from - host.get_global_rect().position
	for i in n:
		var r := Ui.icon_rect(icon, 30, tint)
		r.size = Vector2(30, 30)
		r.pivot_offset = r.size * 0.5
		r.position = start - r.size * 0.5
		r.scale = Vector2.ONE * 0.4
		host.add_child(r)
		var spread := Vector2(randf_range(-90, 90), randf_range(-110, -30))
		var mid := start + spread - r.size * 0.5
		var delay := i * 0.05
		var t := r.create_tween()
		t.tween_interval(delay)
		t.tween_property(r, "position", mid, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.parallel().tween_property(r, "scale", Vector2.ONE, 0.22)
		t.tween_property(r, "position", end - r.size * 0.5, 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t.parallel().tween_property(r, "scale", Vector2.ONE * 0.6, 0.42)
		t.tween_callback(pop.bind(to, 1.15))
		t.tween_callback(Sfx.play.bind("coin", -12.0, 1.0 + i * 0.05))
		t.tween_callback(r.queue_free)


## Where the last finger went down and when, so a reward that lands a moment
## later can fly out of the button that earned it.
static var last_tap := Vector2(-1.0, -1.0)
static var last_tap_ms := -100000


static func mark_tap(at: Vector2) -> void:
	last_tap = at
	last_tap_ms = Time.get_ticks_msec()


## The last tap if it was within `ms`, else the middle of the screen.
static func recent_tap(ms: int) -> Vector2:
	if Time.get_ticks_msec() - last_tap_ms <= ms:
		return last_tap
	return (Engine.get_main_loop() as SceneTree).root.get_visible_rect().size * 0.5


## The same as 0..1 of the screen, for the screen-change curtain.
static func recent_tap_uv(ms: int) -> Vector2:
	var size := (Engine.get_main_loop() as SceneTree).root.get_visible_rect().size
	if Time.get_ticks_msec() - last_tap_ms <= ms:
		return (last_tap / size).clamp(Vector2(0.05, 0.05), Vector2(0.95, 0.95))
	return Vector2(0.5, 0.5)


## Squash on press, a springy overshoot on release, and a brief brighten while
## held. Wired to every button by UiJuice. A press on a greyed-out button
## shakes it "no". Buttons with their own pulse or sway keep that instead.
static func press_bounce(b: BaseButton) -> void:
	if b.has_meta("fx_bounce"):
		return
	b.set_meta("fx_bounce", true)
	b.button_down.connect(func() -> void:
		if b.has_meta("fx_pulse") or b.has_meta("fx_bob"):
			return
		b.pivot_offset = b.size * 0.5
		_kill_press(b)
		if not b.has_meta("fx_tint"):
			b.set_meta("fx_tint", b.self_modulate)
		var t := b.create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.tween_property(b, "scale", Vector2(0.93, 0.92), 0.07)
		t.tween_property(b, "self_modulate", (b.get_meta("fx_tint") as Color) * Color(1.22, 1.22, 1.22, 1.0), 0.07)
		b.set_meta("fx_press", t))
	b.button_up.connect(func() -> void:
		if not b.has_meta("fx_press"):
			return
		_kill_press(b)
		var t := b.create_tween().set_parallel(true)
		t.tween_property(b, "scale", Vector2(1.05, 1.05), 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.tween_property(b, "self_modulate", b.get_meta("fx_tint", Color.WHITE), 0.2)
		t.chain().tween_property(b, "scale", Vector2.ONE, 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		b.set_meta("fx_press", t))
	b.gui_input.connect(func(e: InputEvent) -> void:
		if b.disabled and e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			deny(b))


static func _kill_press(b: Control) -> void:
	if b.has_meta("fx_press"):
		var t: Tween = b.get_meta("fx_press")
		if t and t.is_valid():
			t.kill()
		b.remove_meta("fx_press")


## A quick side-to-side shake for something that can't be done right now.
static func deny(c: Control) -> void:
	if c.has_meta("fx_deny"):
		return
	_center(c)
	c.set_meta("fx_deny", true)
	Sfx.play("ui_error", -6.0)
	var t := c.create_tween().set_trans(Tween.TRANS_SINE)
	for d in [-7.0, 7.0, -4.0, 4.0, 0.0]:
		t.tween_property(c, "rotation_degrees", d * 0.45, 0.05)
	t.tween_callback(func() -> void: c.remove_meta("fx_deny"))


## A quick red wash on a chip whose number just went down.
static func deny_flash(c: Control) -> void:
	var t := c.create_tween().set_trans(Tween.TRANS_SINE)
	t.tween_property(c, "self_modulate", Color(1.5, 0.7, 0.65), 0.08)
	t.tween_property(c, "self_modulate", Color.WHITE, 0.3)
