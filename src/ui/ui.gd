class_name Ui
extends RefCounted
## Small UI helpers shared by every screen.

static var _icons := {}
## Extra insets (left, top, right, bottom) in virtual pixels, for screenshots
## that pretend to be a phone with a notch (`--notch`).
static var forced_inset := Vector4.ZERO


static func icon(name_: String) -> Texture2D:
	if not _icons.has(name_):
		var path := "res://assets/icons/%s.svg" % name_
		_icons[name_] = load(path) if ResourceLoader.exists(path) else null
	return _icons[name_]


## A short vibration on phones, if the player left haptics on. Keep these for
## moments that matter (you got hit, a super, a boss falling), never for every hit.
static func buzz(ms: int, amp := 0.5) -> void:
	if not OS.has_feature("mobile") or not bool(Game.setting("haptics")):
		return
	Input.vibrate_handheld(ms, amp)


static func fmt_time(sec: float) -> String:
	var s := int(sec)
	return "%d:%02d" % [s / 60, s % 60]


static func fmt_num(n: int) -> String:
	if n >= 1000000:
		return "%.1fM" % (n / 1000000.0)
	if n >= 10000:
		return "%.1fk" % (n / 1000.0)
	return str(n)


static func hex(c: Color) -> String:
	return c.to_html(false)


## Keeps a full-rect MarginContainer clear of notches and the home bar.
static func apply_safe_area(m: MarginContainer, base := 20) -> void:
	var ins := safe_insets(base)
	m.add_theme_constant_override("margin_left", int(ins.x))
	m.add_theme_constant_override("margin_top", int(ins.y))
	m.add_theme_constant_override("margin_right", int(ins.z))
	m.add_theme_constant_override("margin_bottom", int(ins.w))


## Room to leave for notches and the home bar, in UI pixels: left, top,
## right, bottom (never less than `base`).
static func safe_insets(base := 20) -> Vector4:
	var win := DisplayServer.window_get_size()
	var safe := DisplayServer.get_display_safe_area()
	# Not the node's own viewport: it may not be in the tree yet.
	var vp: Vector2 = (Engine.get_main_loop() as SceneTree).root.get_visible_rect().size
	var top := base
	var bottom := base
	var left := base
	var right := base
	if win.x > 0 and win.y > 0 and safe.size.x > 0 and OS.has_feature("mobile"):
		var sy := vp.y / win.y
		var sx := vp.x / win.x
		top = maxi(base, int(safe.position.y * sy) + 6)
		bottom = maxi(base, int((win.y - safe.end.y) * sy) + 6)
		left = maxi(base, int(safe.position.x * sx))
		right = maxi(base, int((win.x - safe.end.x) * sx))
	left = maxi(left, int(forced_inset.x))
	top = maxi(top, int(forced_inset.y))
	right = maxi(right, int(forced_inset.z))
	bottom = maxi(bottom, int(forced_inset.w))
	return Vector4(left, top, right, bottom)


## A quick scale-and-fade entrance.
static func pop_in(c: Control, delay := 0.0, from_scale := 0.85) -> void:
	c.pivot_offset = c.size * 0.5
	c.modulate.a = 0.0
	c.scale = Vector2.ONE * from_scale
	var t := c.create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(c, "modulate:a", 1.0, 0.18).set_delay(delay)
	t.tween_property(c, "scale", Vector2.ONE, 0.32).set_delay(delay)


static func clear(n: Node) -> void:
	for c in n.get_children():
		n.remove_child(c)
		c.queue_free()


## A tinted icon.
static func icon_rect(name_: String, size_: float, tint := Color.WHITE) -> TextureRect:
	var t := TextureRect.new()
	t.texture = icon(name_)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.custom_minimum_size = Vector2(size_, size_)
	t.modulate = tint
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


static func label(text: String, variation := "", align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	if variation != "":
		l.theme_type_variation = variation
	l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
