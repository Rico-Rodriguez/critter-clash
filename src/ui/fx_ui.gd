extends RefCounted
## Shared motion kit for menus: shine, pulses, bobbing, deal-in, coin fly-ins,
## count-ups and living page backdrops. Use via
## `const FxUi := preload("res://src/ui/fx_ui.gd")`.
## Loops are tweens bound to the node they move, so they die with it.

const GLOSS := preload("res://src/fx/ui_gloss.gdshader")
const BACKDROP := preload("res://src/fx/ui_backdrop.gdshader")

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


## A slow misty gradient with motes drifting up, behind everything in `c`.
static func backdrop(c: Control, top := Color(0.11, 0.08, 0.14), bottom := Color(0.04, 0.03, 0.06),
		mist := Color(0.5, 0.32, 0.6), motes := Color(1.0, 0.78, 0.45, 0.55)) -> Control:
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
	for d in [-9.0, 9.0, -6.0, 5.0, 0.0]:
		t.tween_property(c, "rotation_degrees", d, 0.07)
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
		t.tween_callback(r.queue_free)


## Squash on press, spring back on release. Wired to every button by UiJuice.
static func press_bounce(b: BaseButton) -> void:
	if b.has_meta("fx_bounce"):
		return
	b.set_meta("fx_bounce", true)
	b.button_down.connect(func() -> void:
		b.pivot_offset = b.size * 0.5
		var t := b.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.tween_property(b, "scale", Vector2(0.94, 0.9), 0.06))
	b.button_up.connect(func() -> void:
		var t := b.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_property(b, "scale", Vector2(1.05, 1.06), 0.08)
		t.tween_property(b, "scale", Vector2.ONE, 0.18))
