class_name UiKit
extends RefCounted

## Supercell-style chrome: chunky type, glossy buttons, blue menu plates.
## Gameplay screens call button() / label() and never invent a second palette.

static var font_m: Font
static var font_b: Font
static var font_x: Font

const INK := Color("1a120c")
const CREAM := Color("fff6ea")
const GOLD := Color("ffc83a")
const GOLD_LIP := Color("c47a12")
const BLUE := Color("3aa0f5")
const BLUE_LIP := Color("1456a8")
const GREEN := Color("5dce45")
const GREEN_LIP := Color("1f8a28")
const RED := Color("ef4b4b")
const RED_LIP := Color("a11e28")


static func ensure() -> void:
	if font_x:
		return
	font_m = load("res://assets/fonts/Nunito-SemiBold.ttf")
	font_b = load("res://assets/fonts/Nunito-Bold.ttf")
	font_x = load("res://assets/fonts/LilitaOne-Regular.ttf")
	if font_x == null:
		font_x = font_b
	_load_icons()


static func label(text: String, size: int, color: Color, weight: String = "m", outline: int = -1) -> Label:
	ensure()
	var l := Label.new()
	l.text = text
	var font := font_m
	if weight == "b":
		font = font_b
	elif weight == "x":
		font = font_x
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	var outline_px := outline
	if outline_px < 0 and (weight == "x" or size >= 28):
		outline_px = maxi(6, int(size / 7))
	if outline_px > 0:
		l.add_theme_color_override("font_outline_color", INK)
		l.add_theme_constant_override("outline_size", outline_px)
		l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.45))
		l.add_theme_constant_override("shadow_offset_x", 0)
		l.add_theme_constant_override("shadow_offset_y", maxi(2, int(outline_px * 0.45)))
	return l


static func paint_menu(_c: Control) -> void:
	# Kept for old callers. The backdrop is a shader layer now (Backdrop).
	pass


static func title(text: String, size: int = 52) -> Label:
	var l := label(text, size, CREAM, "x", maxi(8, int(size / 5)))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_constant_override("shadow_offset_y", maxi(4, int(size / 9)))
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
	return l


static func chunky(bg: Color, lip: Color, pressed: bool = false) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(18)
	s.set_border_width_all(4)
	s.border_width_bottom = 4 if pressed else 10
	s.border_color = lip
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 6
	s.content_margin_bottom = 6 if pressed else 12
	s.shadow_color = Color(0, 0, 0, 0.35)
	s.shadow_size = 6
	s.shadow_offset = Vector2(0, 3 if not pressed else 1)
	return s


## Menu plate: deep blue face, dark navy outline, soft drop shadow.
static func panel(bg: Color = Color("1c4c97"), radius: int = 22) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.set_border_width_all(4)
	s.border_width_bottom = 7
	s.border_color = Color("0a1d45")
	s.shadow_color = Color(0, 0, 0, 0.4)
	s.shadow_size = 12
	s.shadow_offset = Vector2(0, 6)
	s.content_margin_left = 16
	s.content_margin_right = 16
	s.content_margin_top = 14
	s.content_margin_bottom = 14
	s.anti_aliasing = true
	return s


static func wood_panel(radius: int = 26) -> StyleBoxFlat:
	var s := panel(Color("6a3d22"), radius)
	s.border_color = Color("2e170a")
	return s


static func button(text: String, wide: float = 440, tall: float = 86, tone: String = "gold") -> Button:
	return _btn(text, wide, tall, tone, false)


static func secondary(text: String, wide: float = 280, tall: float = 72) -> Button:
	return _btn(text, wide, tall, "blue", false)


static func confirm(text: String, wide: float = 280, tall: float = 72) -> Button:
	return _btn(text, wide, tall, "green", false)


static func danger(text: String, wide: float = 280, tall: float = 72) -> Button:
	return _btn(text, wide, tall, "red", false)


static func icon_button(text: String, px: float = 64, tone: String = "blue") -> Button:
	return _btn(text, px, px, tone, true)


## Square tile with an icon over a caption: Log, Slayer, Skills, Credits.
static func tile_button(caption: String, icon_name: String, px: float = 132, tone: String = "blue") -> Button:
	var b := _btn("", px, px, tone, false) as Btn
	b.icon_name = icon_name
	b.caption = caption
	return b


static func _btn(text: String, wide: float, tall: float, tone: String, round: bool) -> Button:
	ensure()
	var b := Btn.new()
	b.tone = tone
	b.round = round
	b.text = text
	b.custom_minimum_size = Vector2(wide, tall)
	b.pressed.connect(func() -> void: AudioDirector.play("click"))
	return b


static var _icons: Dictionary = {}


## Icons are loaded up front. A texture first loaded inside _draw renders as
## a blank white quad, so draw code only reads this cache.
static func icon(name: String) -> Texture2D:
	if _icons.is_empty():
		_load_icons()
	return _icons.get(name, null)


static func _load_icons() -> void:
	var dir := DirAccess.open("res://assets/sprites/icons")
	if dir == null:
		return
	for file in dir.get_files():
		var f := file.trim_suffix(".import").trim_suffix(".remap")
		if f.ends_with(".png") and not _icons.has(f.get_basename()):
			var tex := load("res://assets/sprites/icons/" + f) as Texture2D
			if tex:
				_icons[f.get_basename()] = tex


static func tone_colors(tone: String) -> Dictionary:
	match tone:
		"blue":
			return {"hi": Color("6fd0ff"), "lo": Color("2a80e6"), "lip": Color("1650a6"), "edge": Color("0b2a5e")}
		"green":
			return {"hi": Color("a4f56a"), "lo": Color("43b42e"), "lip": Color("217a1c"), "edge": Color("0e3d0c")}
		"red":
			return {"hi": Color("ff8a7a"), "lo": Color("e23d3d"), "lip": Color("a01c26"), "edge": Color("4c0a10")}
		"purple":
			return {"hi": Color("d69bff"), "lo": Color("9046d8"), "lip": Color("5a1e96"), "edge": Color("2a0a4a")}
		"grey":
			return {"hi": Color("b9c2cf"), "lo": Color("7d8796"), "lip": Color("4d5562"), "edge": Color("23272e")}
		_:
			return {"hi": Color("ffe36a"), "lo": Color("f7a817"), "lip": Color("b9650b"), "edge": Color("4a2604")}


## Rounded-rect outline as a polygon, for gradient fills.
static func rr_points(rect: Rect2, radius: float, seg: int = 6) -> PackedVector2Array:
	var r := minf(radius, minf(rect.size.x, rect.size.y) * 0.5)
	var pts := PackedVector2Array()
	var corners := [
		[rect.position + Vector2(rect.size.x - r, r), -PI * 0.5],
		[rect.position + Vector2(rect.size.x - r, rect.size.y - r), 0.0],
		[rect.position + Vector2(r, rect.size.y - r), PI * 0.5],
		[rect.position + Vector2(r, r), PI],
	]
	for corner in corners:
		var c: Vector2 = corner[0]
		var start: float = corner[1]
		for i in seg + 1:
			var a := start + float(i) / float(seg) * PI * 0.5
			pts.append(c + Vector2(cos(a), sin(a)) * r)
	return pts


## Vertical two-stop gradient in a rounded rect. Color is linear in y, so
## the triangulated fill reproduces it exactly.
static func rr_fill(ci: CanvasItem, rect: Rect2, radius: float, top: Color, bottom: Color) -> void:
	if rect.size.x < 1.0 or rect.size.y < 1.0:
		return
	var pts := rr_points(rect, radius)
	var cols := PackedColorArray()
	for p in pts:
		var t := clampf((p.y - rect.position.y) / rect.size.y, 0.0, 1.0)
		cols.append(top.lerp(bottom, t))
	ci.draw_polygon(pts, cols)


static func rr_line(ci: CanvasItem, rect: Rect2, radius: float, color: Color, width: float) -> void:
	var pts := rr_points(rect, radius)
	pts.append(pts[0])
	ci.draw_polyline(pts, color, width, true)


## Soft drop shadow: stacked translucent rounded rects.
static func rr_shadow(ci: CanvasItem, rect: Rect2, radius: float, depth: float, alpha: float = 0.35) -> void:
	for i in 4:
		var g := float(i) * 2.0
		var r := Rect2(rect.position + Vector2(-g, depth - g * 0.5), rect.size + Vector2(g * 2.0, g))
		var c := Color(0, 0, 0, alpha / (1.0 + i))
		rr_fill(ci, r, radius + g, c, c)


## Outlined, shadowed text drawn by hand (buttons, badges, nav labels).
static func draw_text(ci: CanvasItem, font: Font, origin: Vector2, text: String, px: int, ink: Color, edge: Color = INK, ring: int = 4, width: float = -1) -> void:
	var w := width
	ci.draw_string(font, origin + Vector2(0, maxf(3.0, ring * 0.8)), text, HORIZONTAL_ALIGNMENT_CENTER if w > 0 else HORIZONTAL_ALIGNMENT_LEFT, w, px, Color(0, 0, 0, 0.5))
	ci.draw_string_outline(font, origin, text, HORIZONTAL_ALIGNMENT_CENTER if w > 0 else HORIZONTAL_ALIGNMENT_LEFT, w, px, ring * 2, edge)
	ci.draw_string(font, origin, text, HORIZONTAL_ALIGNMENT_CENTER if w > 0 else HORIZONTAL_ALIGNMENT_LEFT, w, px, ink)


## A white silhouette icon, tinted, with a dark outline and drop shadow.
static func draw_icon(ci: CanvasItem, tex: Texture2D, rect: Rect2, fill: Color, edge: Color = INK, ring: float = 3.0) -> void:
	if tex == null:
		return
	ci.draw_texture_rect(tex, Rect2(rect.position + Vector2(0, ring + 2.0), rect.size), false, Color(0, 0, 0, 0.45))
	for i in 12:
		var off := Vector2.from_angle(float(i) * TAU / 12.0) * ring
		ci.draw_texture_rect(tex, Rect2(rect.position + off, rect.size), false, edge)
	ci.draw_texture_rect(tex, rect, false, fill)
	# Top sheen: the upper half a touch lighter.
	var top := Rect2(rect.position, Vector2(rect.size.x, rect.size.y * 0.45))
	ci.draw_texture_rect_region(tex, top, Rect2(Vector2.ZERO, Vector2(tex.get_width(), tex.get_height() * 0.45)), Color(1, 1, 1, 0.22))


static func rarity_colors(rarity: String) -> Dictionary:
	match rarity:
		"rare":
			return {"bg": Color("1d6ec4"), "lip": Color("08386e"), "ink": CREAM}
		"epic":
			return {"bg": Color("8c3ec4"), "lip": Color("4a1478"), "ink": CREAM}
		"legendary":
			return {"bg": Color("f0a020"), "lip": Color("8a4e08"), "ink": CREAM}
		_:
			return {"bg": Color("d9d3c8"), "lip": Color("6a6258"), "ink": Color("2a241c")}


static func hero_rarity(id: String) -> String:
	if id in ["thistle", "caplet", "nimbus", "cinder"]:
		return "legendary"
	if id in ["lumen", "pip", "bramble"]:
		return "epic"
	return "rare"


static func rarity_box(rarity: String) -> StyleBoxFlat:
	var cols: Dictionary = rarity_colors(rarity)
	var s := panel(cols["bg"], 18)
	s.border_color = cols["lip"]
	s.border_width_left = 8
	s.border_width_right = 8
	s.border_width_top = 8
	s.border_width_bottom = 12
	return s


static func safe_insets() -> Dictionary:
	var vp := Vector2(720, 1280)
	var tree := Engine.get_main_loop()
	if tree is SceneTree:
		vp = (tree as SceneTree).root.get_visible_rect().size
	var screen := DisplayServer.screen_get_size()
	var win := DisplayServer.window_get_size()
	var safe := DisplayServer.get_display_safe_area()
	var top := 16
	var bot := 12
	var left := 14
	var right := 14
	var px := Vector2(win) if win.x > 0 else Vector2(screen)
	var sy := vp.y / maxf(px.y, 1.0)
	var sx := vp.x / maxf(px.x, 1.0)
	var fake := fake_notch()
	if fake.y > 0:
		# Desktop captures stand in for an iPhone: Dynamic Island and the
		# home indicator, in device pixels.
		top = maxi(top, int(fake.x * sy) + 8)
		bot = maxi(bot, int(fake.y * sy) + 4)
	elif screen.y > 0 and safe.size.y > 0 and safe.size.y < screen.y - 2:
		top = maxi(top, int(safe.position.y * sy) + 8)
		bot = maxi(bot, int((screen.y - (safe.position.y + safe.size.y)) * sy) + 4)
		left = maxi(left, int(safe.position.x * sx) + 6)
		right = maxi(right, int((screen.x - (safe.position.x + safe.size.x)) * sx) + 6)
	elif OS.get_name() == "iOS":
		top = maxi(top, 70)
		bot = maxi(bot, 24)
	return {"l": left, "t": top, "r": right, "b": bot}


## "--notch" on the command line fakes iPhone safe insets (top, bottom px).
static func fake_notch() -> Vector2:
	for arg in OS.get_cmdline_user_args():
		if arg == "--notch":
			return Vector2(177, 102)
	return Vector2.ZERO


## Coin, gem, and trophy icons drawn with gradients and outlines.
static func draw_currency(ci: CanvasItem, kind: String, rect: Rect2) -> void:
	var c := rect.get_center()
	var r := rect.size.y * 0.42
	match kind:
		"trophy":
			var tex := icon("trophy")
			var box := Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0)
			draw_icon(ci, tex, box, Color("ffd34a"), Color("4a2604"), 3.0)
		"gem":
			var pts := PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.9, -r * 0.25), c + Vector2(0, r), c + Vector2(-r * 0.9, -r * 0.25)])
			var big := PackedVector2Array()
			for p in pts:
				big.append(c + (p - c) * 1.18)
			ci.draw_colored_polygon(big, Color("063a33"))
			ci.draw_polygon(pts, PackedColorArray([Color("b8fff2"), Color("3fe0c4"), Color("0f8f84"), Color("5cf0d6")]))
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r * 0.7), c + Vector2(r * 0.45, -r * 0.2), c + Vector2(0, r * 0.1), c + Vector2(-r * 0.45, -r * 0.2)]), Color(1, 1, 1, 0.45))
		_:
			ci.draw_circle(c + Vector2(0, 3), r + 3, Color(0, 0, 0, 0.35))
			ci.draw_circle(c, r + 3, Color("4a2604"))
			ci.draw_circle(c, r, Color("e08a10"))
			ci.draw_circle(c + Vector2(0, -r * 0.08), r * 0.84, Color("ffcc3a"))
			ci.draw_circle(c + Vector2(0, -r * 0.08), r * 0.6, Color("f2a81c"))
			ci.draw_arc(c + Vector2(0, -r * 0.08), r * 0.6, PI * 1.1, PI * 1.9, 12, Color("fff2b0"), 3.0, true)
			ci.draw_circle(c + Vector2(-r * 0.35, -r * 0.45), r * 0.16, Color(1, 1, 1, 0.8))


class Btn extends Button:
	var tone := "gold"
	var round := false
	var icon_name := ""
	var caption := ""
	var _down := false

	func _ready() -> void:
		UiKit.ensure()
		focus_mode = Control.FOCUS_NONE
		var empty := StyleBoxEmpty.new()
		for state in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
			add_theme_stylebox_override(state, empty)
		add_theme_font_override("font", UiKit.font_x)
		add_theme_font_size_override("font_size", int(clampf(custom_minimum_size.y * 0.40, 18, 46)))
		# Caption is painted in _draw on top of the gloss.
		for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color", "font_hover_pressed_color"]:
			add_theme_color_override(key, Color(0, 0, 0, 0))
		add_theme_constant_override("outline_size", 0)
		button_down.connect(_sink)
		button_up.connect(_rise)

	func _sink() -> void:
		_down = true
		pivot_offset = size * 0.5
		var tw := create_tween()
		tw.tween_property(self, "scale", Vector2(0.94, 0.92), 0.05)
		AudioDirector.haptic(14)
		queue_redraw()

	func _rise() -> void:
		_down = false
		pivot_offset = size * 0.5
		var tw := create_tween()
		tw.tween_property(self, "scale", Vector2(1.05, 1.05), 0.07).set_ease(Tween.EASE_OUT)
		tw.tween_property(self, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		queue_redraw()

	func _draw() -> void:
		var cols: Dictionary = UiKit.tone_colors("grey" if disabled else tone)
		var sunk := _down or button_pressed
		var lip := 4.0 if sunk else maxf(7.0, size.y * 0.1)
		var outer := Rect2(4, 2, maxf(8.0, size.x - 8), maxf(12.0, size.y - 10))
		var radius := outer.size.y * 0.5 if round else minf(22.0, outer.size.y * 0.3)
		var drop := (maxf(7.0, size.y * 0.1) - lip)
		if not sunk:
			UiKit.rr_shadow(self, outer, radius, 6.0, 0.32)
		# Dark edge, lip, then the face.
		UiKit.rr_fill(self, outer.grow(3), radius + 3, cols["edge"], cols["edge"])
		UiKit.rr_fill(self, outer, radius, cols["lip"], cols["lip"].darkened(0.15))
		var face := Rect2(outer.position + Vector2(0, drop), Vector2(outer.size.x, outer.size.y - lip - drop + (drop * 0.0)))
		face.size.y = outer.size.y - lip - drop
		UiKit.rr_fill(self, face, radius, cols["hi"], cols["lo"])
		# Gloss band across the top and a bright rim line.
		var gloss := Rect2(face.position + Vector2(6, 4), Vector2(face.size.x - 12, face.size.y * 0.44))
		UiKit.rr_fill(self, gloss, maxf(4.0, radius - 4.0), Color(1, 1, 1, 0.5), Color(1, 1, 1, 0.08))
		UiKit.rr_line(self, face.grow(-1.5), radius - 1.5, Color(1, 1, 1, 0.35), 2.0)
		if icon_name != "":
			_draw_tile(face)
		else:
			_draw_caption(face)

	func _draw_tile(face: Rect2) -> void:
		var tex := UiKit.icon(icon_name)
		var px := face.size.y * 0.5
		var r := Rect2(face.position + Vector2((face.size.x - px) * 0.5, face.size.y * 0.1), Vector2(px, px))
		UiKit.draw_icon(self, tex, r, Color.WHITE, UiKit.INK, 3.0)
		if caption != "":
			var font := UiKit.font_x
			var fpx := int(clampf(face.size.y * 0.2, 14, 28))
			UiKit.draw_text(self, font, Vector2(face.position.x, face.position.y + face.size.y * 0.9), caption, fpx, Color.WHITE, UiKit.INK, 3, face.size.x)

	func _draw_caption(face: Rect2) -> void:
		if text == "":
			return
		var font := UiKit.font_x
		if font == null:
			return
		var px := int(clampf(face.size.y * (0.5 if round else 0.46), 16, 48))
		var bounds := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px)
		while bounds.x > face.size.x - 16 and px > 14:
			px -= 2
			bounds = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px)
		var baseline := face.position.y + (face.size.y - font.get_height(px)) * 0.5 + font.get_ascent(px)
		var ink := Color(1, 1, 1, 0.75) if disabled else Color.WHITE
		var edge: Color = UiKit.tone_colors("grey" if disabled else tone)["edge"]
		UiKit.draw_text(self, font, Vector2(face.position.x, baseline), text, px, ink, edge, maxi(3, int(px / 9)), face.size.x)


## Full-screen layered backdrop (shaders/menu_bg.gdshader).
class Backdrop extends ColorRect:
	func _ready() -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var mat := ShaderMaterial.new()
		mat.shader = load("res://shaders/menu_bg.gdshader")
		material = mat
		resized.connect(_fit)
		_fit()

	func _fit() -> void:
		(material as ShaderMaterial).set_shader_parameter("px_size", size)


## A panel drawn by hand: gradient face, navy outline, inner light rim,
## and a soft shadow. Content margins come from `pad`.
class Plate extends PanelContainer:
	var top := Color("2a6cc6")
	var bottom := Color("173f86")
	var edge := Color("0a1d45")
	var rim := Color(1, 1, 1, 0.22)
	var radius := 22.0
	var glow := Color(0, 0, 0, 0)
	var pad := 14

	func _ready() -> void:
		var box := StyleBoxEmpty.new()
		box.content_margin_left = pad
		box.content_margin_right = pad
		box.content_margin_top = pad
		box.content_margin_bottom = pad + 4
		add_theme_stylebox_override("panel", box)
		mouse_filter = Control.MOUSE_FILTER_PASS

	func _draw() -> void:
		var r := Rect2(Vector2(3, 2), size - Vector2(6, 8))
		if glow.a > 0.0:
			for i in 5:
				var g := 4.0 + float(i) * 4.0
				UiKit.rr_fill(self, r.grow(g), radius + g, Color(glow, glow.a / (1.0 + i * 1.3)), Color(glow, glow.a / (1.0 + i * 1.3)))
		UiKit.rr_shadow(self, r, radius, 7.0, 0.3)
		UiKit.rr_fill(self, r.grow(3), radius + 3, edge, edge)
		UiKit.rr_fill(self, Rect2(r.position + Vector2(0, r.size.y - 10), Vector2(r.size.x, 10)), minf(radius, 10.0), bottom.darkened(0.35), bottom.darkened(0.35))
		UiKit.rr_fill(self, Rect2(r.position, r.size - Vector2(0, 5)), radius, top, bottom)
		UiKit.rr_line(self, Rect2(r.position, r.size - Vector2(0, 5)).grow(-2), radius - 2, rim, 2.0)


class Pill extends Control:
	static var _last: Dictionary = {}
	var kind := "coin"
	var value := 0
	var _shown := 0.0
	var _plus: Callable
	var _press := 0.0

	func _init(which: String, plus: Callable) -> void:
		kind = which
		_plus = plus
		custom_minimum_size = Vector2(0, 62)
		mouse_filter = Control.MOUSE_FILTER_STOP

	func set_amount(text: String) -> void:
		value = int(text) if text.is_valid_int() else 0
		# Count up from whatever this pill last showed on any screen.
		_shown = float(_last.get(kind, value))
		_last[kind] = value
		if absf(_shown - value) > 0.5:
			var tw := create_tween()
			tw.tween_interval(0.25)
			tw.tween_method(func(v: float) -> void:
				_shown = v
				queue_redraw(), _shown, float(value), 0.7).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		queue_redraw()

	func _gui_input(event: InputEvent) -> void:
		var hit := (event is InputEventMouseButton and (event as InputEventMouseButton).pressed) or (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed)
		if hit:
			var at: Vector2 = event.position
			if at.x > size.x - size.y - 4 and _plus.is_valid():
				AudioDirector.play("click")
				_plus.call()
				pivot_offset = size * 0.5
				var tw := create_tween()
				tw.tween_property(self, "scale", Vector2(0.95, 0.95), 0.05)
				tw.tween_property(self, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	func _draw() -> void:
		var h := size.y
		var bar := Rect2(h * 0.42, h * 0.16, size.x - h * 0.42 - 2, h * 0.68)
		UiKit.rr_fill(self, bar.grow(3), bar.size.y * 0.5 + 3, Color("06122c"), Color("06122c"))
		UiKit.rr_fill(self, bar, bar.size.y * 0.5, Color(0.02, 0.06, 0.16, 0.92), Color(0.08, 0.16, 0.34, 0.92))
		UiKit.rr_line(self, bar.grow(-1.5), bar.size.y * 0.5, Color(1, 1, 1, 0.12), 2.0)
		# Plus button on the right end.
		var pb := Rect2(size.x - h * 0.74, h * 0.1, h * 0.72, h * 0.72)
		UiKit.rr_fill(self, pb.grow(2), 12, Color("0e3d0c"), Color("0e3d0c"))
		UiKit.rr_fill(self, pb, 10, Color("a4f56a"), Color("38a826"))
		UiKit.rr_fill(self, Rect2(pb.position + Vector2(4, 3), Vector2(pb.size.x - 8, pb.size.y * 0.42)), 7, Color(1, 1, 1, 0.5), Color(1, 1, 1, 0.08))
		var c := pb.get_center()
		var arm := pb.size.x * 0.24
		var thick := pb.size.x * 0.13
		for a in [Rect2(c.x - arm, c.y - thick * 0.5, arm * 2.0, thick), Rect2(c.x - thick * 0.5, c.y - arm, thick, arm * 2.0)]:
			draw_rect((a as Rect2).grow(2.5), Color("0e3d0c"), true)
		for a in [Rect2(c.x - arm, c.y - thick * 0.5, arm * 2.0, thick), Rect2(c.x - thick * 0.5, c.y - arm, thick, arm * 2.0)]:
			draw_rect(a, Color.WHITE, true)
		# Currency icon overlapping the left end.
		UiKit.draw_currency(self, kind, Rect2(0, 0, h, h))
		var font := UiKit.font_x
		var px := int(h * 0.44)
		UiKit.draw_text(self, font, Vector2(h * 0.95, h * 0.5 + font.get_ascent(px) * 0.42), str(int(round(_shown))), px, Color.WHITE, UiKit.INK, 3, -1)


## Bottom tab bar: icons over labels, the current tab raised and glowing.
class Dock extends Control:
	const TABS := [
		["collection", "Cards", "cards_fan"],
		["home", "Battle", "sword"],
		["trophy", "Road", "trophy"],
		["world", "Map", "flag_triangle"],
	]
	var current := ""
	var _go: Callable
	var bar_h := 118.0
	var bottom_pad := 12.0
	var _t := 0.0

	func _init(tab: String, go: Callable) -> void:
		current = tab
		_go = go

	func _ready() -> void:
		bottom_pad = float(UiKit.safe_insets()["b"])
		set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		offset_left = 0
		offset_right = 0
		offset_top = -(bar_h + bottom_pad)
		offset_bottom = 0
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _gui_input(event: InputEvent) -> void:
		var hit := (event is InputEventMouseButton and (event as InputEventMouseButton).pressed) or (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed)
		if not hit:
			return
		var i := clampi(int(event.position.x / (size.x / TABS.size())), 0, TABS.size() - 1)
		var id := str(TABS[i][0])
		if id != current:
			AudioDirector.play("click")
			AudioDirector.haptic(10)
			_go.call(id)

	func _draw() -> void:
		var w := size.x
		var top := 0.0
		# Bar body: dark navy with a bevelled top edge, bleeding to the bottom.
		draw_rect(Rect2(0, top - 10, w, 10), Color(0, 0, 0, 0.25), true)
		UiKit.rr_fill(self, Rect2(-4, top, w + 8, size.y + 20), 0, Color("1c3f7c"), Color("0a1a3c"))
		draw_rect(Rect2(0, top, w, 4), Color("4f86d6"), true)
		draw_rect(Rect2(0, top + 4, w, 2), Color("08142e"), true)
		var slot := w / TABS.size()
		for i in TABS.size():
			var id := str(TABS[i][0])
			var x := slot * i
			if i > 0:
				draw_rect(Rect2(x - 1, top + 16, 2, bar_h - 30), Color(0, 0, 0, 0.3), true)
			var on := id == current
			var cell := Rect2(x + 6, top + 10, slot - 12, bar_h - 18)
			if on:
				cell = Rect2(x + 2, top - 22, slot - 4, bar_h + 14)
				var pulse := 0.5 + 0.5 * sin(_t * 3.0)
				for g in 4:
					var gg := 4.0 + g * 5.0
					UiKit.rr_fill(self, cell.grow(gg), 22 + gg, Color(1.0, 0.85, 0.35, (0.14 + pulse * 0.06) / (1.0 + g)), Color(1.0, 0.85, 0.35, 0.0))
				UiKit.rr_fill(self, cell.grow(3), 22, Color("0b2a5e"), Color("0b2a5e"))
				UiKit.rr_fill(self, cell, 20, Color("7fd3ff"), Color("2a74d6"))
				UiKit.rr_fill(self, Rect2(cell.position + Vector2(6, 4), Vector2(cell.size.x - 12, cell.size.y * 0.4)), 14, Color(1, 1, 1, 0.45), Color(1, 1, 1, 0.05))
			var tex := UiKit.icon(str(TABS[i][2]))
			var px := 70.0 if on else 54.0
			var icon_r := Rect2(x + (slot - px) * 0.5, cell.position.y + (8.0 if on else 6.0), px, px)
			UiKit.draw_icon(self, tex, icon_r, Color.WHITE if on else Color(0.72, 0.8, 0.95), UiKit.INK, 3.5 if on else 3.0)
			var font := UiKit.font_x
			var fpx := 26 if on else 21
			UiKit.draw_text(self, font, Vector2(x, cell.position.y + cell.size.y - 12), str(TABS[i][1]), fpx, Color.WHITE if on else Color(0.75, 0.83, 0.96), UiKit.INK, 3, slot)


class Gem extends Control:
	var kind := "coin"

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		UiKit.draw_currency(self, kind, Rect2(Vector2.ZERO, size))


## Level badge: a gold shield with the number, Clash card style.
class Badge extends Control:
	var level := 1
	var tone := "gold"

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var r := Rect2(Vector2(2, 2), size - Vector2(4, 4))
		var cols: Dictionary = UiKit.tone_colors(tone)
		var pts := PackedVector2Array([
			r.position + Vector2(r.size.x * 0.5, 0), r.position + Vector2(r.size.x, r.size.y * 0.18),
			r.position + Vector2(r.size.x, r.size.y * 0.62), r.position + Vector2(r.size.x * 0.5, r.size.y),
			r.position + Vector2(0, r.size.y * 0.62), r.position + Vector2(0, r.size.y * 0.18),
		])
		var outline := PackedVector2Array()
		var c := r.get_center()
		for p in pts:
			outline.append(c + (p - c) * 1.12)
		draw_colored_polygon(outline, cols["edge"])
		var colors := PackedColorArray()
		for p in pts:
			colors.append((cols["hi"] as Color).lerp(cols["lo"], (p.y - r.position.y) / r.size.y))
		draw_polygon(pts, colors)
		var font := UiKit.font_x
		var px := int(r.size.y * 0.5)
		UiKit.draw_text(self, font, Vector2(r.position.x, c.y + font.get_ascent(px) * 0.36), str(level), px, Color.WHITE, UiKit.INK, 3, r.size.x)
