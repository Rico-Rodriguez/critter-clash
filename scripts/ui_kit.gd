class_name UiKit
extends RefCounted

## Premium fantasy chrome: forged metal frames around leather and stone,
## engraved Cinzel display type, restrained gold. Frames are drawn by
## shaders/ui_frame.gdshader through Frame. Screens call button() / label()
## / Plate and never invent a second palette.

static var font_m: Font
static var font_b: Font
static var font_x: Font
## Heaviest Cinzel, slightly emboldened: combat numbers.
static var font_n: Font

const INK := Color("120c08")
const CREAM := Color("f3e6c8")
const GOLD := Color("e2bb6a")
const MUTED := Color("b8a888")
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
	font_m = load("res://assets/fonts/AlegreyaSans-Medium.ttf")
	font_b = load("res://assets/fonts/AlegreyaSans-Bold.ttf")
	var cinzel := FontVariation.new()
	cinzel.base_font = load("res://assets/fonts/Cinzel-Variable.ttf")
	cinzel.variation_opentype = {"wght": 800}
	font_x = cinzel
	if font_x == null:
		font_x = font_b
	var heavy := FontVariation.new()
	heavy.base_font = load("res://assets/fonts/Cinzel-Variable.ttf")
	heavy.variation_opentype = {"wght": 900}
	heavy.variation_embolden = 0.6
	font_n = heavy
	_load_icons()
	Frame.preload_assets()


## Text-scale helper for the accessibility "Text size" setting (100/115/130 %),
## read live from the settings dict. Applied in label() so every menu text in
## the game scales from one place; buttons fit by auto-shrinking.
static func text_px(px: int) -> int:
	return int(round(float(px) * AudioDirector.text_scale()))


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
	l.add_theme_font_size_override("font_size", text_px(size))
	l.add_theme_color_override("font_color", color)
	# Engraved look: a thin dark keyline and a soft drop shadow, never the
	# fat cartoon outline.
	var outline_px := outline
	if outline_px < 0 and (weight == "x" or size >= 28):
		outline_px = clampi(int(size / 12), 3, 6)
	outline_px = mini(outline_px, maxi(3, int(size / 9)))
	if outline_px > 0:
		l.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.02, 0.9))
		l.add_theme_constant_override("outline_size", outline_px)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", maxi(2, int(size / 14)))
	l.add_theme_constant_override("shadow_outline_size", maxi(2, int(size / 10)))
	return l


static func paint_menu(_c: Control) -> void:
	# Kept for old callers. The backdrop is a shader layer now (Backdrop).
	pass


static func title(text: String, size: int = 52) -> Label:
	var l := label(text, size, GOLD.lightened(0.25), "x", maxi(4, int(size / 10)))
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


## Flat fallback plate for StyleBox users: dark leather with a bronze rim.
## The caller's hue only nudges the tone; the palette stays dark and warm.
static func panel(bg: Color = Color("1c4c97"), radius: int = 22) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	var lum := bg.get_luminance()
	s.bg_color = Color("221a14").lerp(Color("3a2c20"), clampf(lum * 1.4, 0.0, 1.0))
	s.set_corner_radius_all(mini(radius, 12))
	s.set_border_width_all(3)
	s.border_width_bottom = 4
	s.border_color = Color("8a6a3a")
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
	b.pressed.connect(func() -> void: AudioDirector.sfx("ui_press"))
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


## Enamel and metal for each tone. "hi"/"lo" are the face, "rim_hi"/"rim_lo"
## the metal frame, "edge" the darkest keyline, "ink" the caption colour.
static func tone_colors(tone: String) -> Dictionary:
	match tone:
		"blue", "steel":
			return {"hi": Color("4a586c"), "lo": Color("1c2430"), "rim_hi": Color("dfe4ea"), "rim_lo": Color("4a525e"), "edge": Color("0c1016"), "lip": Color("2a323e"), "ink": Color("eef1f5")}
		"green":
			return {"hi": Color("2f8a4a"), "lo": Color("10381d"), "rim_hi": Color("f0d896"), "rim_lo": Color("5a3e18"), "edge": Color("08140c"), "lip": Color("164a26"), "ink": Color("f6ecd0")}
		"red":
			return {"hi": Color("9a2a26"), "lo": Color("3e0c0c"), "rim_hi": Color("e8c886"), "rim_lo": Color("4e3012"), "edge": Color("160606"), "lip": Color("5a1414"), "ink": Color("f6ecd0")}
		"purple":
			return {"hi": Color("6a3a9a"), "lo": Color("26103e"), "rim_hi": Color("e8d0f0"), "rim_lo": Color("4a2e5a"), "edge": Color("12081c"), "lip": Color("3a1a5a"), "ink": Color("f4ecf8")}
		"stone":
			# Settled / already-done state: worn stone in a dulled gilt frame.
			return {"hi": Color("5a5348"), "lo": Color("2a2620"), "rim_hi": Color("c8ae78"), "rim_lo": Color("4e3e24"), "edge": Color("100e0c"), "lip": Color("34302a"), "ink": Color("e4d8b8")}
		"grey":
			return {"hi": Color("4a4540"), "lo": Color("26221e"), "rim_hi": Color("8a8278"), "rim_lo": Color("3a3530"), "edge": Color("100e0c"), "lip": Color("2e2a26"), "ink": Color("b0a898")}
		"leather":
			return {"hi": Color("3a2c22"), "lo": Color("1a130e"), "rim_hi": Color("e8c886"), "rim_lo": Color("4e3214"), "edge": Color("0e0906"), "lip": Color("2a1e14"), "ink": CREAM}
		_:
			# The primary call to action: crimson enamel in a gilded frame.
			return {"hi": Color("b23a2a"), "lo": Color("4e0f0e"), "rim_hi": Color("ffe3a0"), "rim_lo": Color("6a4416"), "edge": Color("1a0806"), "lip": Color("6a1a14"), "ink": Color("fff0cc")}


## Shader uniforms for each Frame preset, coloured by tone.
static func skin_params(preset: String, tone: String) -> Dictionary:
	var c: Dictionary = tone_colors(tone)
	var p := {
		"face_top": c["hi"], "face_bot": c["lo"], "metal_hi": c["rim_hi"], "metal_lo": c["rim_lo"],
		"radius": 12.0, "frame": 6.0, "sheen": 0.0, "studs": 0.0, "bump_amt": 0.5,
		"detail_amt": 0.18, "detail_scale": 1.0, "shadow_alpha": 0.55, "press": 0.0,
		"glow_color": Color(1, 0.75, 0.3, 0.0), "detail_tex": "marble", "leather": true, "time_glow": 0.0,
	}
	match preset:
		"panel":
			p["face_top"] = Color("2a2019")
			p["face_bot"] = Color("140f0b")
			p["metal_hi"] = Color("e9cd8e")
			p["metal_lo"] = Color("4a2e12")
			p["frame"] = 7.0
			p["radius"] = 14.0
			p["studs"] = 1.0
			p["bump_amt"] = 0.7
		"card":
			p["frame"] = 6.0
			p["radius"] = 12.0
			p["bump_amt"] = 0.4
			p["detail_amt"] = 0.3
		"plaque":
			p["face_top"] = Color("3a2d22")
			p["face_bot"] = Color("1c150f")
			p["frame"] = 5.0
			p["radius"] = 10.0
		"inset":
			p["face_top"] = Color("0c0907")
			p["face_bot"] = Color("1e1712")
			p["metal_hi"] = Color("a8875a")
			p["metal_lo"] = Color("2e1e0e")
			p["frame"] = 3.5
			p["radius"] = 999.0
			p["bump_amt"] = 0.25
			p["shadow_alpha"] = 0.35
		"button":
			p["frame"] = 6.0
			p["radius"] = 10.0
			p["sheen"] = 1.0
			p["bump_amt"] = 0.2
			p["studs"] = 1.0
			p["detail_amt"] = 0.12
			p["time_glow"] = 0.4 if tone == "gold" else 0.0
		"round":
			p["frame"] = 4.0
			p["radius"] = 999.0
			p["sheen"] = 1.0
			p["bump_amt"] = 0.1
		"tile":
			p["face_top"] = Color("3a2e24")
			p["face_bot"] = Color("17110c")
			p["metal_hi"] = Color("d8b878")
			p["metal_lo"] = Color("3e2810")
			p["frame"] = 5.0
			p["radius"] = 12.0
			p["sheen"] = 0.35
			p["bump_amt"] = 0.6
		"slot":
			p["face_top"] = Color("120e0b")
			p["face_bot"] = Color("221a14")
			p["metal_hi"] = Color("b8955e")
			p["metal_lo"] = Color("33220f")
			p["frame"] = 5.0
			p["radius"] = 12.0
			p["bump_amt"] = 0.4
			p["shadow_alpha"] = 0.45
		"dock":
			p["face_top"] = Color("2c2620")
			p["face_bot"] = Color("0f0c0a")
			p["metal_hi"] = Color("e2c27e")
			p["metal_lo"] = Color("4a3012")
			p["frame"] = 6.0
			p["radius"] = 6.0
			p["detail_tex"] = "stone"
			p["detail_amt"] = 0.35
			p["leather"] = false
			p["shadow_alpha"] = 0.7
		"tab":
			p["face_top"] = Color("5a2a1e")
			p["face_bot"] = Color("26100c")
			p["metal_hi"] = Color("ffe6a8")
			p["metal_lo"] = Color("6a4416")
			p["frame"] = 6.0
			p["radius"] = 14.0
			p["sheen"] = 0.6
			p["studs"] = 1.0
			p["glow_color"] = Color(1.0, 0.72, 0.32, 0.38)
	return p


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
## Square-cut (chamfered) panel fill with a vertical gradient: forged windows.
static func ch_fill(ci: CanvasItem, rect: Rect2, cut: float, top: Color, bottom: Color) -> void:
	var c := minf(cut, minf(rect.size.x, rect.size.y) * 0.5)
	var p := rect.position
	var e := rect.end
	var pts := PackedVector2Array([Vector2(p.x + c, p.y), Vector2(e.x - c, p.y), Vector2(e.x, p.y + c), Vector2(e.x, e.y - c), Vector2(e.x - c, e.y), Vector2(p.x + c, e.y), Vector2(p.x, e.y - c), Vector2(p.x, p.y + c)])
	var cols := PackedColorArray()
	for q in pts:
		cols.append(top.lerp(bottom, (q.y - p.y) / maxf(rect.size.y, 1.0)))
	ci.draw_polygon(pts, cols)


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
	var align := HORIZONTAL_ALIGNMENT_CENTER if w > 0 else HORIZONTAL_ALIGNMENT_LEFT
	var keyline := clampi(ring, 2, 4)
	ci.draw_string_outline(font, origin + Vector2(0, maxf(2.0, px * 0.07)), text, align, w, px, keyline * 2 + 2, Color(0, 0, 0, 0.55))
	ci.draw_string_outline(font, origin, text, align, w, px, keyline * 2, edge)
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
			return {"bg": Color("1e3a5e"), "lip": Color("6aa8e8"), "glow": Color("4a9cff"), "ink": CREAM}
		"epic":
			return {"bg": Color("3a1e5a"), "lip": Color("c08cf0"), "glow": Color("b060ff"), "ink": CREAM}
		"legendary":
			return {"bg": Color("4a3010"), "lip": Color("ffd77a"), "glow": Color("ffb030"), "ink": CREAM}
		_:
			return {"bg": Color("2e2924"), "lip": Color("b8aa94"), "glow": Color("d8ccb8"), "ink": CREAM}


## Frame metal (hi, lo) for each rarity: silver, steel blue, amethyst, gold.
static func rarity_metal(rarity: String) -> Array:
	match rarity:
		"rare":
			return [Color("cfe2f6"), Color("2a4668")]
		"epic":
			return [Color("e6cef8"), Color("4a2a6a")]
		"legendary":
			return [Color("ffe6a8"), Color("6a4416")]
		_:
			return [Color("d8d0c0"), Color("4a443c")]


static func hero_rarity(id: String) -> String:
	if id in ["thistle", "caplet", "nimbus", "cinder", "boreal", "inferno"]:
		return "legendary"
	if id in ["lumen", "pip", "bramble"]:
		return "epic"
	return "rare"


static func rarity_box(rarity: String) -> StyleBoxFlat:
	var cols: Dictionary = rarity_colors(rarity)
	var s := panel(cols["bg"], 12)
	s.bg_color = cols["bg"]
	s.border_color = cols["lip"]
	s.set_border_width_all(4)
	s.shadow_color = Color(cols["glow"], 0.35)
	s.shadow_size = 10
	s.shadow_offset = Vector2.ZERO
	return s


## The last computed safe insets, and the sizes they were computed for.
static var _insets: Dictionary = {}
static var _insets_vp: Vector2 = Vector2.ZERO
static var _insets_px: Vector2i = Vector2i.ZERO


## Safe-area insets in viewport pixels: the notch, the home indicator and
## the side cutouts, with a small margin. They only move when the window
## does, so they are computed once and kept until the viewport size or the
## window size changes (a rotation, a resize, another device). Every caller
## reads the same cached dictionary: it is shared, so read it and do not
## change it.
static func safe_insets() -> Dictionary:
	var tree := Engine.get_main_loop()
	if not (tree is SceneTree):
		return _compute_insets()
	var root := (tree as SceneTree).root
	# The viewport size in logical pixels, and the window size in device
	# pixels: a rotation changes the first, a rescaled window the second.
	var vp := root.get_visible_rect().size
	var px := root.size
	if _insets.is_empty() or vp != _insets_vp or px != _insets_px:
		_insets_vp = vp
		_insets_px = px
		_insets = _compute_insets()
	return _insets


## The real work behind safe_insets(): ask the display server once.
static func _compute_insets() -> Dictionary:
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
			draw_icon(ci, tex, box, Color("e2bb6a"), Color("120a04"), 2.0)
		"gem":
			# A cut emerald in a thin gold setting.
			var pts := PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.86, -r * 0.3), c + Vector2(r * 0.55, r * 0.7), c + Vector2(0, r), c + Vector2(-r * 0.55, r * 0.7), c + Vector2(-r * 0.86, -r * 0.3)])
			var big := PackedVector2Array()
			for p in pts:
				big.append(c + (p - c) * 1.16)
			ci.draw_colored_polygon(big, Color("0c0806"))
			var rim := PackedVector2Array()
			for p in pts:
				rim.append(c + (p - c) * 1.08)
			ci.draw_colored_polygon(rim, Color("c9a35a"))
			ci.draw_polygon(pts, PackedColorArray([Color("9af0c8"), Color("2fa878"), Color("0e5a3c"), Color("063a26"), Color("0e5a3c"), Color("3cc28a")]))
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r * 0.62), c + Vector2(r * 0.42, -r * 0.18), c + Vector2(0, r * 0.15), c + Vector2(-r * 0.42, -r * 0.18)]), Color(0.75, 1.0, 0.9, 0.35))
		_:
			# A stamped gold coin: dark keyline, bevelled rim, engraved field.
			ci.draw_circle(c + Vector2(0, 2), r + 3, Color(0, 0, 0, 0.45))
			ci.draw_circle(c, r + 2.5, Color("120a04"))
			ci.draw_circle(c, r, Color("8a5a18"))
			ci.draw_circle(c + Vector2(0, -r * 0.05), r * 0.9, Color("e8c070"))
			ci.draw_circle(c + Vector2(0, r * 0.04), r * 0.7, Color("a8742a"))
			ci.draw_circle(c, r * 0.66, Color("d8a850"))
			ci.draw_arc(c, r * 0.66, PI * 1.05, PI * 1.95, 14, Color("fff0c0"), 2.0, true)
			ci.draw_arc(c, r * 0.4, 0.0, TAU, 18, Color(0.45, 0.28, 0.08, 0.7), 2.0, true)


## A shader-drawn frame behind its parent (show_behind_parent). It reaches
## `margin` px past the parent on every side so the shadow and glow fit, and
## the framed box itself lines up with the parent rect (or `box` if set).
class Frame extends Node2D:
	# A Node2D, not a Control, so Container parents leave its layout alone.
	var size := Vector2.ZERO
	static var _shader: Shader
	static var _stone: Texture2D
	static var _marble: Texture2D
	static var _leather: Texture2D
	static var _flat: Texture2D
	var preset := "panel"
	var tone := "gold"
	var margin := 16.0
	var box := Rect2()
	var mat: ShaderMaterial
	var params := {}

	static func preload_assets() -> void:
		if _shader != null:
			return
		_shader = load("res://shaders/ui_frame.gdshader")
		_stone = load("res://assets/textures/ui/ui_stone.jpg")
		_marble = load("res://assets/textures/ui/ui_marble.jpg")
		_leather = load("res://assets/textures/ui/ui_leather_n.jpg")
		var img := Image.create(4, 4, false, Image.FORMAT_RGB8)
		img.fill(Color(0.5, 0.5, 1.0))
		_flat = ImageTexture.create_from_image(img)

	func _init(which: String = "panel", which_tone: String = "gold", extra: Dictionary = {}) -> void:
		preset = which
		tone = which_tone
		params = extra

	func _ready() -> void:
		preload_assets()
		show_behind_parent = true
		mat = ShaderMaterial.new()
		mat.shader = _shader
		material = mat
		apply()
		var host := get_parent() as Control
		if host != null:
			host.resized.connect(_fit)
		_fit()

	func _fit() -> void:
		var host := get_parent() as Control
		if host == null:
			return
		var r := box if box.size != Vector2.ZERO else Rect2(Vector2.ZERO, host.size)
		position = r.position - Vector2(margin, margin)
		size = r.size + Vector2(margin, margin) * 2.0
		mat.set_shader_parameter("px", size)
		mat.set_shader_parameter("margin", margin)
		queue_redraw()

	func set_param(key: String, value: Variant) -> void:
		if mat != null:
			mat.set_shader_parameter(key, value)

	func apply() -> void:
		var p := UiKit.skin_params(preset, tone)
		for key in params:
			p[key] = params[key]
		# Angular forged metal: square-cut corners on everything but true rounds.
		var r := float(p.get("radius", 12.0))
		if r < 100.0 and not p.has("chamfer"):
			p["chamfer"] = r * 1.1
			p["radius"] = 2.0
		var detail: Texture2D = _marble if str(p.get("detail_tex", "marble")) == "marble" else _stone
		mat.set_shader_parameter("detail", detail)
		mat.set_shader_parameter("bump", _leather if bool(p.get("leather", true)) else _flat)
		for key in p:
			if key in ["detail_tex", "leather"]:
				continue
			mat.set_shader_parameter(key, p[key])

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color.WHITE, true)


class Btn extends Button:
	var tone := "gold"
	var round := false
	var icon_name := ""
	var caption := ""
	var font_px := 0
	var _down := false
	var skin: Frame

	func _ready() -> void:
		UiKit.ensure()
		focus_mode = Control.FOCUS_NONE
		var empty := StyleBoxEmpty.new()
		for state in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
			add_theme_stylebox_override(state, empty)
		add_theme_font_override("font", UiKit.font_x)
		add_theme_font_size_override("font_size", font_px if font_px > 0 else int(clampf(custom_minimum_size.y * 0.42, 22, 44)))
		# Caption is painted in _draw over the frame.
		for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color", "font_hover_pressed_color"]:
			add_theme_color_override(key, Color(0, 0, 0, 0))
		add_theme_constant_override("outline_size", 0)
		var kind := "button"
		if icon_name != "":
			kind = "tile"
		elif round:
			kind = "round"
		if kind == "tile" and tone == "forged":
			# Home tiles: the same riveted bronze-on-leather trim as the
			# chest slots beside them, with a heavier bevel.
			skin = Frame.new("tile", "leather", {"metal_hi": Color("f0cf8a"), "metal_lo": Color("5e3f1f"), "studs": 1.0, "frame": 8.0})
		else:
			skin = Frame.new(kind, "grey" if disabled else tone)
		skin.margin = 14.0
		add_child(skin)
		button_down.connect(_sink)
		button_up.connect(_rise)

	## Re-skin in place (e.g. SELECT -> settled EQUIPPED) without rebuilding.
	func set_tone(t: String) -> void:
		if t == tone and skin != null:
			return
		tone = t
		if skin == null:
			return
		var at := skin.get_index()
		var behind := skin.show_behind_parent
		skin.queue_free()
		skin = Frame.new("button", "grey" if disabled and t != "stone" else t)
		skin.margin = 14.0
		skin.show_behind_parent = behind
		add_child(skin)
		move_child(skin, at)
		queue_redraw()

	func _sink() -> void:
		_down = true
		pivot_offset = size * 0.5
		var tw := create_tween()
		tw.tween_property(self, "scale", Vector2(0.95, 0.94), 0.05)
		skin.set_param("press", 1.0)
		AudioDirector.haptic("light")
		queue_redraw()

	func _rise() -> void:
		_down = false
		pivot_offset = size * 0.5
		skin.set_param("press", 0.0)
		var tw := create_tween()
		tw.tween_property(self, "scale", Vector2(1.04, 1.04), 0.07).set_ease(Tween.EASE_OUT)
		tw.tween_property(self, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		queue_redraw()

	func _draw() -> void:
		var sunk := 2.0 if (_down or button_pressed) else 0.0
		var face := Rect2(Vector2(0, sunk), size)
		if icon_name != "":
			_draw_tile(face)
		else:
			_draw_caption(face)

	func _draw_tile(face: Rect2) -> void:
		var tex := UiKit.icon(icon_name)
		var px := face.size.y * (0.42 if caption != "" else 0.56)
		var top := face.size.y * 0.15 if caption != "" else (face.size.y - px) * 0.5
		var r := Rect2(face.position + Vector2((face.size.x - px) * 0.5, top), Vector2(px, px))
		if tone == "forged":
			# Recessed medallion lit from the top left, the same key as the
			# baked 3D chests: bevel ring light above, dark below, a warm
			# pool behind the glyph, a cast shadow and a top highlight.
			var c := r.get_center()
			var rad := px * 0.78
			for i in 8:
				var k := float(i) / 7.0
				draw_circle(c, rad * (1.0 - k * 0.08), Color(0.03, 0.02, 0.01, 0.12))
			draw_arc(c, rad, PI * 0.95, PI * 1.85, 40, Color(1.0, 0.86, 0.6, 0.55), 3.0, true)
			draw_arc(c, rad, -0.15 * PI, 0.85 * PI, 40, Color(0.0, 0.0, 0.0, 0.6), 3.0, true)
			draw_circle(c, rad - 3.0, Color(0.09, 0.06, 0.04, 0.95))
			for i in 5:
				draw_circle(c + Vector2(-rad * 0.12, -rad * 0.18), rad * (0.8 - i * 0.13), Color(1.0, 0.7, 0.32, 0.05))
			if tex:
				draw_texture_rect(tex, Rect2(r.position + Vector2(3, 4), r.size), false, Color(0, 0, 0, 0.55))
			UiKit.draw_icon(self, tex, r, Color("e9c47c"), Color(0.06, 0.04, 0.02), 2.0)
			if tex:
				draw_texture_rect_region(tex, Rect2(r.position + Vector2(-1, -1.5), Vector2(r.size.x, r.size.y * 0.5)), Rect2(Vector2.ZERO, Vector2(tex.get_width(), tex.get_height() * 0.5)), Color(1.0, 0.96, 0.82, 0.35))
		else:
			UiKit.draw_icon(self, tex, r, UiKit.GOLD.lightened(0.2), Color(0.06, 0.04, 0.02), 2.0)
		if caption != "":
			var font := UiKit.font_x
			var fpx := int(clampf(face.size.y * 0.16, 14, 24))
			UiKit.draw_text(self, font, Vector2(face.position.x, face.position.y + face.size.y * 0.84), caption, fpx, UiKit.CREAM, Color(0.05, 0.03, 0.02), 2, face.size.x)

	func _draw_caption(face: Rect2) -> void:
		if text == "":
			return
		var font := UiKit.font_x
		if font == null:
			return
		var px := font_px if font_px > 0 else int(clampf(face.size.y * (0.42 if round else 0.36), 16, 46))
		var pad := 18.0 if font_px > 0 else 28.0
		var bounds := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px)
		while bounds.x > face.size.x - pad and px > 14:
			px -= 2
			bounds = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px)
		var baseline := face.position.y + (face.size.y - font.get_height(px)) * 0.5 + font.get_ascent(px) - 1.0
		var cols: Dictionary = UiKit.tone_colors("grey" if disabled else tone)
		UiKit.draw_text(self, font, Vector2(face.position.x, baseline), text, px, cols["ink"], cols["edge"], 2, face.size.x)


## Full-screen backdrop: torch-lit dark stone (shaders/menu_bg.gdshader).
class Backdrop extends ColorRect:
	func _ready() -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		Frame.preload_assets()
		var mat := ShaderMaterial.new()
		mat.shader = load("res://shaders/menu_bg.gdshader")
		mat.set_shader_parameter("stone", Frame._stone)
		material = mat
		resized.connect(_fit)
		_fit()

	func _fit() -> void:
		(material as ShaderMaterial).set_shader_parameter("px_size", size)


## A framed panel: forged rim over dark leather. `kind` picks the preset
## ("panel", "inset", "card", "plaque"); `glow` adds an outer aura.
class Plate extends PanelContainer:
	var kind := "panel"
	var tone := "leather"
	var glow := Color(0, 0, 0, 0)
	var pad := 16
	var skin: Frame
	# Old callers set these; they now only tint the face.
	var top := Color(0, 0, 0, 0)
	var bottom := Color(0, 0, 0, 0)
	var edge := Color(0, 0, 0, 0)
	var rim := Color(0, 0, 0, 0)
	var radius := 14.0

	func _ready() -> void:
		var box := StyleBoxEmpty.new()
		box.content_margin_left = pad
		box.content_margin_right = pad
		box.content_margin_top = pad
		box.content_margin_bottom = pad
		add_theme_stylebox_override("panel", box)
		mouse_filter = Control.MOUSE_FILTER_PASS
		var extra := {}
		if glow.a > 0.0:
			extra["glow_color"] = glow
		skin = Frame.new(kind, tone, extra)
		skin.margin = 18.0
		add_child(skin)


## A dimmed sheet over the page that asks once before something that cannot
## be undone: a heading, one plain line about what it costs, and the two ways
## out. The caller sets the words and the tone of the way forward.
class ConfirmSheet extends Control:
	signal confirmed
	signal cancelled
	var heading := "Are you sure?"
	## What the action costs, in plain words. Left out when empty.
	var body := ""
	var keep_text := "KEEP"
	var go_text := "GO"
	## True when the way forward is the dangerous one (red metal, not green).
	var go_danger := false
	var wide := 240.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var dim := ColorRect.new()
		dim.color = Color(0, 0, 0, 0.62)
		dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		dim.gui_input.connect(func(e: InputEvent) -> void:
			if (e is InputEventMouseButton and e.pressed) or (e is InputEventScreenTouch and e.pressed):
				cancelled.emit())
		add_child(dim)
		var center := CenterContainer.new()
		center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(center)
		var plate := Plate.new()
		plate.kind = "panel"
		plate.pad = 24
		center.add_child(plate)
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 14)
		plate.add_child(box)
		var title := UiKit.title(heading, 40)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(title)
		if body != "":
			var line := UiKit.label(body, 22, UiKit.CREAM, "b", 4)
			line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			box.add_child(line)
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 14)
		box.add_child(row)
		var keep := UiKit.secondary(keep_text, wide, 88)
		keep.pressed.connect(func() -> void: cancelled.emit())
		row.add_child(keep)
		var go: Button = UiKit.danger(go_text, wide, 88) if go_danger else UiKit.confirm(go_text, wide, 88)
		go.pressed.connect(func() -> void: confirmed.emit())
		row.add_child(go)


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

	func _ready() -> void:
		var bar := Frame.new("inset", "leather")
		bar.margin = 10.0
		add_child(bar)
		var plus := Frame.new("round", "green", {"frame": 3.5, "studs": 0.0})
		plus.margin = 8.0
		add_child(plus)
		resized.connect(func() -> void:
			var h := size.y
			bar.box = Rect2(h * 0.4, h * 0.16, size.x - h * 0.4 - 2, h * 0.68)
			bar._fit()
			plus.box = Rect2(size.x - h * 0.66, h * 0.16, h * 0.62, h * 0.62)
			plus._fit())

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
				AudioDirector.sfx("ui_tap")
				AudioDirector.haptic("light")
				_plus.call()
				pivot_offset = size * 0.5
				var tw := create_tween()
				tw.tween_property(self, "scale", Vector2(0.95, 0.95), 0.05)
				tw.tween_property(self, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	func _draw() -> void:
		var h := size.y
		var pb := Rect2(size.x - h * 0.66, h * 0.16, h * 0.62, h * 0.62)
		var c := pb.get_center()
		var arm := pb.size.x * 0.22
		var thick := maxf(3.0, pb.size.x * 0.1)
		for a in [Rect2(c.x - arm, c.y - thick * 0.5, arm * 2.0, thick), Rect2(c.x - thick * 0.5, c.y - arm, thick, arm * 2.0)]:
			draw_rect((a as Rect2).grow(1.5), Color(0.04, 0.1, 0.05, 0.9), true)
		for a in [Rect2(c.x - arm, c.y - thick * 0.5, arm * 2.0, thick), Rect2(c.x - thick * 0.5, c.y - arm, thick, arm * 2.0)]:
			draw_rect(a, Color("f6e7c1"), true)
		# Currency icon overlapping the left end.
		UiKit.draw_currency(self, kind, Rect2(0, 0, h, h))
		var font := UiKit.font_b
		var px := int(h * 0.46)
		UiKit.draw_text(self, font, Vector2(h * 0.98, h * 0.5 + font.get_ascent(px) * 0.4), str(int(round(_shown))), px, UiKit.CREAM, Color(0.04, 0.03, 0.02), 2, -1)


## Bottom tab bar on carved stone: icons over engraved labels, the current
## tab raised on a gilded plaque with a warm glow.
class Dock extends Control:
	const TABS := [
		["hub", "Camp", "home"],
		["heroes", "Heroes", "crown_a"],
		["trophy", "Road", "trophy"],
	]
	var current := ""
	var _go: Callable
	var bar_h := 118.0
	var bottom_pad := 12.0
	var _t := 0.0
	var _bar: Frame
	var _tab: Frame

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
		_bar = Frame.new("dock", "leather")
		_bar.margin = 20.0
		add_child(_bar)
		_tab = Frame.new("tab", "gold")
		_tab.margin = 22.0
		add_child(_tab)
		resized.connect(_layout)
		_layout()

	## Index of a tab by id, or -1 when it is not in TABS. Tabs are always
	## looked up by id, never by a hard-coded position.
	func _tab_index(id: String) -> int:
		for i in TABS.size():
			if str(TABS[i][0]) == id:
				return i
		return -1

	## The icon rect for a tab, in Dock-local coordinates: the same math _draw
	## uses, so a pip can ride the right icon whatever the tab order, count or
	## icon size. An unknown id returns an empty rect.
	func tab_icon_rect(id: String) -> Rect2:
		var i := _tab_index(id)
		if i < 0:
			return Rect2()
		var slot := size.x / TABS.size()
		var on := id == current
		var px := 76.0 if on else 60.0
		var top := -20.0 if on else 0.0
		return Rect2(slot * i + (slot - px) * 0.5, top + (10.0 if on else 12.0), px, px)

	func _layout() -> void:
		# The bar's frame runs off the sides and bottom so only its top trim shows.
		_bar.box = Rect2(-12, 0, size.x + 24, size.y + 30)
		_bar._fit()
		var slot := size.x / TABS.size()
		var i := 0
		for n in TABS.size():
			if str(TABS[n][0]) == current:
				i = n
		_tab.visible = current in TABS.map(func(t: Array) -> String: return str(t[0]))
		_tab.box = Rect2(slot * i + 4, -20, slot - 8, bar_h + 10)
		_tab._fit()

	func _process(delta: float) -> void:
		_t += delta
		if _tab != null:
			_tab.set_param("glow_color", Color(1.0, 0.72, 0.32, 0.32 + 0.12 * sin(_t * 2.6)))

	func _gui_input(event: InputEvent) -> void:
		var hit := (event is InputEventMouseButton and (event as InputEventMouseButton).pressed) or (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed)
		if not hit:
			return
		var i := clampi(int(event.position.x / (size.x / TABS.size())), 0, TABS.size() - 1)
		var id := str(TABS[i][0])
		if id != current:
			AudioDirector.sfx("ui_tap")
			AudioDirector.haptic("light")
			_go.call(id)

	func _draw() -> void:
		var slot := size.x / TABS.size()
		for i in TABS.size():
			var id := str(TABS[i][0])
			var x := slot * i
			var on := id == current
			if i > 0 and not on and str(TABS[i - 1][0]) != current:
				# Carved divider.
				draw_rect(Rect2(x - 1, 22, 1, bar_h - 44), Color(0, 0, 0, 0.45), true)
				draw_rect(Rect2(x, 22, 1, bar_h - 44), Color(1, 0.9, 0.7, 0.08), true)
			var top := -20.0 if on else 0.0
			var tex := UiKit.icon(str(TABS[i][2]))
			var icon_r := tab_icon_rect(id)
			var px := icon_r.size.x
			if on:
				# Warm halo behind the active icon.
				for k in 10:
					draw_circle(icon_r.get_center(), px * (0.75 - k * 0.05), Color(1.0, 0.75, 0.35, 0.035))
			var fill := Color("ffe3a0") if on else Color(0.84, 0.77, 0.64)
			UiKit.draw_icon(self, tex, icon_r, fill, Color(0.05, 0.03, 0.02), 3.0 if on else 2.5)
			var font := UiKit.font_n if on else UiKit.font_x
			var fpx := 25 if on else 21
			var ink := Color("fff1d6") if on else Color(0.84, 0.77, 0.64)
			UiKit.draw_text(self, font, Vector2(x, top + bar_h - (10.0 if on else 18.0)), str(TABS[i][1]).to_upper(), fpx, ink, Color(0.04, 0.03, 0.02), 4 if on else 3, slot)
			if on:
				# Gilt underline so the active tab reads even at a glance.
				var ux := x + slot * 0.28
				draw_rect(Rect2(ux, top + bar_h - 2.0, slot * 0.44, 4.0), Color("ffd27a"), true)
				draw_rect(Rect2(ux, top + bar_h + 2.0, slot * 0.44, 2.0), Color(0, 0, 0, 0.5), true)


## A circular portrait in a gilded, riveted ring (hunt HUD, map bosses).
class Medal extends Control:
	var tex: Texture2D
	var locked := false
	var face: TextureRect
	var _mat: ShaderMaterial

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		face = TextureRect.new()
		face.texture = tex
		face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		face.stretch_mode = TextureRect.STRETCH_SCALE
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_mat = ShaderMaterial.new()
		_mat.shader = load("res://shaders/ui_art.gdshader")
		_mat.set_shader_parameter("circle", 1.0)
		_mat.set_shader_parameter("fade_alpha", 0.0)
		_mat.set_shader_parameter("desat", 0.9 if locked else 0.0)
		_mat.set_shader_parameter("darken", 0.6 if locked else 0.0)
		face.material = _mat
		add_child(face)
		var ring := MedalRing.new()
		ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(ring)
		resized.connect(_fit)
		_fit()

	func _fit() -> void:
		var inset := size.x * 0.09
		face.position = Vector2(inset, inset)
		face.size = size - Vector2(inset, inset) * 2.0
		_mat.set_shader_parameter("px", face.size)

	func _draw() -> void:
		var c := size * 0.5
		var r := size.x * 0.5
		draw_circle(c + Vector2(0, 4), r, Color(0, 0, 0, 0.55))
		draw_circle(c, r - 4, Color("1a110a"))
		for i in 8:
			draw_circle(c, (r - 8) * (1.0 - i * 0.09), Color(0.55, 0.22, 0.12, 0.08))


class MedalRing extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size * 0.5
		var w := maxf(6.0, size.x * 0.075)
		var r := size.x * 0.5 - w * 0.6
		draw_arc(c, r, 0, TAU, 64, Color("120a04"), w + 3.0, true)
		draw_arc(c, r, 0, TAU, 64, Color("8a5a1a"), w, true)
		draw_arc(c, r, PI * 1.05, PI * 1.95, 32, Color("ffe6a8"), w * 0.38, true)
		draw_arc(c, r, PI * 0.1, PI * 0.9, 32, Color("4a2e0e"), w * 0.38, true)
		draw_arc(c, r - w * 0.6, 0, TAU, 64, Color(0, 0, 0, 0.6), 2.0, true)
		for k in 4:
			var a := PI * 0.25 + k * PI * 0.5
			var p := c + Vector2.from_angle(a) * r
			draw_circle(p, w * 0.62, Color("120a04"))
			draw_circle(p, w * 0.45, Color("f0d08a"))


class Gem extends Control:
	var kind := "coin"

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		UiKit.draw_currency(self, kind, Rect2(Vector2.ZERO, size))


## Level badge: a gilded shield with dark enamel and the number engraved.
class Badge extends Control:
	var level := 1
	var tone := "gold"

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var r := Rect2(Vector2(3, 3), size - Vector2(6, 6))
		var pts := PackedVector2Array([
			r.position + Vector2(r.size.x * 0.5, 0), r.position + Vector2(r.size.x, r.size.y * 0.16),
			r.position + Vector2(r.size.x * 0.94, r.size.y * 0.64), r.position + Vector2(r.size.x * 0.5, r.size.y),
			r.position + Vector2(r.size.x * 0.06, r.size.y * 0.64), r.position + Vector2(0, r.size.y * 0.16),
		])
		var c := r.get_center()
		var outer := PackedVector2Array()
		var inner := PackedVector2Array()
		for p in pts:
			outer.append(c + (p - c) * 1.1)
			inner.append(c + (p - c) * 0.74)
		draw_colored_polygon(outer, Color(0.06, 0.04, 0.02))
		var gold := PackedColorArray()
		for p in pts:
			gold.append(Color("ffe3a0").lerp(Color("7a4e18"), (p.y - r.position.y) / r.size.y))
		draw_polygon(pts, gold)
		var enamel := PackedColorArray()
		var cols: Dictionary = UiKit.tone_colors("red" if tone == "gold" else tone)
		for p in inner:
			enamel.append((cols["hi"] as Color).lerp(cols["lo"], (p.y - r.position.y) / r.size.y))
		draw_polygon(inner, enamel)
		var font := UiKit.font_x
		var px := int(r.size.y * 0.42)
		UiKit.draw_text(self, font, Vector2(r.position.x, c.y + font.get_ascent(px) * 0.34), str(level), px, Color("fff0cc"), Color(0.05, 0.02, 0.01), 2, r.size.x)


## A Clash-style chest: wooden body and arched lid with gold bands and a
## lock plate. `tone` picks the wood: "wood", "silver", "gold", "magic".
static func draw_chest(ci: CanvasItem, rect: Rect2, tone: String = "wood", lit: bool = true) -> void:
	var w := rect.size.x
	var h := rect.size.y
	var o := rect.position
	# Dark walnut bound in blackened iron with a brass lock; "silver" is
	# steel-bound ash, "gold" gilded, "magic" violet-stained.
	var wood_hi := Color("7a4a2a")
	var wood_lo := Color("3a1f10")
	var band := Color("5a5650")
	var band_lo := Color("24221f")
	var lock_hi := Color("f0cf7a")
	var lock_lo := Color("8a5a1a")
	match tone:
		"silver":
			wood_hi = Color("8a6a4a")
			wood_lo = Color("4a3420")
			band = Color("d8dce2")
			band_lo = Color("6a707a")
		"gold":
			band = Color("ffe3a0")
			band_lo = Color("9a6a20")
		"magic":
			wood_hi = Color("5a3a7a")
			wood_lo = Color("24143a")
			band = Color("c8b0e8")
			band_lo = Color("5a4a7a")
	if not lit:
		for k in 3:
			pass
		wood_hi = wood_hi.darkened(0.6)
		wood_lo = wood_lo.darkened(0.6)
		band = band.darkened(0.6)
		band_lo = band_lo.darkened(0.6)
		lock_hi = lock_hi.darkened(0.6)
		lock_lo = lock_lo.darkened(0.6)
	var ink := Color("120a05") if lit else Color(0, 0, 0, 0.6)
	var body := Rect2(o + Vector2(w * 0.1, h * 0.44), Vector2(w * 0.8, h * 0.46))
	var lid := Rect2(o + Vector2(w * 0.08, h * 0.14), Vector2(w * 0.84, h * 0.34))
	ci.draw_set_transform(o + Vector2(w * 0.5, h * 0.92), 0.0, Vector2(1.0, 0.22))
	ci.draw_circle(Vector2.ZERO, w * 0.46, Color(0, 0, 0, 0.45))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	rr_fill(ci, body.grow(2.5), 5, ink, ink)
	rr_fill(ci, body, 4, wood_hi, wood_lo)
	rr_fill(ci, lid.grow(2.5), lid.size.y * 0.5, ink, ink)
	rr_fill(ci, lid, lid.size.y * 0.46, wood_hi.lightened(0.08), wood_lo.lightened(0.05))
	# Plank seams and grain.
	for i in 3:
		var y := body.position.y + body.size.y * (0.28 + i * 0.24)
		ci.draw_line(Vector2(body.position.x + 3, y), Vector2(body.end.x - 3, y), Color(0, 0, 0, 0.35), 1.5)
		ci.draw_line(Vector2(body.position.x + 3, y + 1.5), Vector2(body.end.x - 3, y + 1.5), Color(1, 0.85, 0.6, 0.08), 1.0)
	for i in 2:
		var y := lid.position.y + lid.size.y * (0.45 + i * 0.25)
		ci.draw_line(Vector2(lid.position.x + 6, y), Vector2(lid.end.x - 6, y), Color(0, 0, 0, 0.3), 1.5)
	# Iron straps with rivets.
	for fx: float in [0.22, 0.78]:
		var bx: float = o.x + w * fx - w * 0.05
		var strap := Rect2(bx, lid.position.y + 1, w * 0.1, lid.size.y + body.size.y + 1)
		rr_fill(ci, strap.grow(1.5), 2, ink, ink)
		rr_fill(ci, strap, 2, band, band_lo)
		for k in 3:
			var ry: float = strap.position.y + strap.size.y * (0.18 + k * 0.32)
			ci.draw_circle(Vector2(strap.get_center().x, ry), w * 0.018, band.lightened(0.35))
	# Rim and the brass lock plate.
	rr_fill(ci, Rect2(lid.position.x - 2, lid.end.y - h * 0.045, lid.size.x + 4, h * 0.075), 2, ink, ink)
	rr_fill(ci, Rect2(lid.position.x, lid.end.y - h * 0.035, lid.size.x, h * 0.055), 2, band, band_lo)
	var lock := Rect2(o + Vector2(w * 0.41, h * 0.41), Vector2(w * 0.18, h * 0.22))
	rr_fill(ci, lock.grow(2.5), 4, ink, ink)
	rr_fill(ci, lock, 3, lock_hi, lock_lo)
	ci.draw_circle(lock.get_center() + Vector2(0, -lock.size.y * 0.1), lock.size.x * 0.13, ink)
	ci.draw_rect(Rect2(lock.get_center() + Vector2(-lock.size.x * 0.05, -lock.size.y * 0.02), Vector2(lock.size.x * 0.1, lock.size.y * 0.3)), ink, true)
	if lit:
		# A thin warm line of light leaking from under the lid.
		ci.draw_line(Vector2(lid.position.x + 4, lid.end.y + 1), Vector2(lid.end.x - 4, lid.end.y + 1), Color(1.0, 0.8, 0.4, 0.55), 2.0)
		rr_fill(ci, Rect2(lid.position + Vector2(lid.size.x * 0.15, lid.size.y * 0.12), Vector2(lid.size.x * 0.7, lid.size.y * 0.2)), lid.size.y * 0.1, Color(1, 0.9, 0.75, 0.18), Color(1, 1, 1, 0.0))
