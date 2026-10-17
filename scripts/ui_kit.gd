class_name UiKit
extends RefCounted

static var font_m: Font
static var font_b: Font
static var font_x: Font


static func ensure() -> void:
	if font_m:
		return
	font_m = load("res://assets/fonts/Nunito-SemiBold.ttf")
	font_b = load("res://assets/fonts/Nunito-Bold.ttf")
	font_x = load("res://assets/fonts/Nunito-ExtraBold.ttf")


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
	if outline_px < 0 and size >= 40:
		outline_px = 10
	if outline_px > 0:
		l.add_theme_color_override("font_outline_color", Color(0.16, 0.07, 0.05, 0.95))
		l.add_theme_constant_override("outline_size", outline_px)
	return l


static func chunky(bg: Color, lip: Color, pressed: bool = false) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	var r := 22
	s.corner_radius_top_left = r
	s.corner_radius_top_right = r
	s.corner_radius_bottom_left = r
	s.corner_radius_bottom_right = r
	s.border_width_left = 3
	s.border_width_right = 3
	s.border_width_top = 3
	s.border_width_bottom = 3 if pressed else 8
	s.border_color = lip
	s.content_margin_left = 16
	s.content_margin_right = 16
	s.content_margin_top = 8
	s.content_margin_bottom = 8 if pressed else 12
	s.shadow_color = Color(0.15, 0.08, 0.05, 0.28)
	s.shadow_size = 8
	s.shadow_offset = Vector2(0, 4 if not pressed else 1)
	return s


static func panel(bg: Color, radius: int = 28) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.corner_radius_top_left = radius
	s.corner_radius_top_right = radius
	s.corner_radius_bottom_left = radius
	s.corner_radius_bottom_right = radius
	s.border_width_left = 4
	s.border_width_right = 4
	s.border_width_top = 4
	s.border_width_bottom = 4
	s.border_color = Color(0.28, 0.16, 0.12, 0.35)
	s.shadow_color = Color(0.2, 0.1, 0.06, 0.18)
	s.shadow_size = 12
	s.content_margin_left = 16
	s.content_margin_right = 16
	s.content_margin_top = 12
	s.content_margin_bottom = 12
	return s


static func secondary(text: String, wide: float = 280, tall: float = 72) -> Button:
	ensure()
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(wide, tall)
	b.add_theme_font_override("font", font_b)
	b.add_theme_font_size_override("font_size", 26)
	b.add_theme_color_override("font_color", Color("3a241c"))
	b.add_theme_color_override("font_hover_color", Color("3a241c"))
	b.add_theme_color_override("font_pressed_color", Color("3a241c"))
	b.add_theme_color_override("font_focus_color", Color("3a241c"))
	var normal := chunky(Color("fff6ea"), Color("c4a07a"))
	var hover := chunky(Color("fffaf3"), Color("c4a07a"))
	var pressed := chunky(Color("f0e2d0"), Color("a88460"), true)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("focus", hover)
	b.add_theme_stylebox_override("disabled", chunky(Color("efe6da"), Color("d5c4b0"), true))
	b.pressed.connect(func() -> void: AudioDirector.play("click"))
	return b


static func rarity_box(rarity: String) -> StyleBoxFlat:
	var bg := Color("fffaf3")
	var lip := Color("b7a48e")
	match rarity:
		"rare":
			bg = Color("e5f2ff")
			lip = Color("2c78c4")
		"epic":
			bg = Color("f4e6ff")
			lip = Color("7a38b0")
		"legendary":
			bg = Color("fff1c9")
			lip = Color("d39212")
	var s := panel(bg, 18)
	s.border_color = lip
	s.border_width_left = 8
	s.border_width_right = 8
	s.border_width_top = 8
	s.border_width_bottom = 8
	return s


static func safe_insets() -> Dictionary:
	var vp := Vector2(720, 1280)
	var tree := Engine.get_main_loop()
	if tree is SceneTree:
		vp = (tree as SceneTree).root.get_visible_rect().size
	var screen := DisplayServer.screen_get_size()
	var safe := DisplayServer.get_display_safe_area()
	var top := 20
	var bot := 18
	var left := 14
	var right := 14
	if screen.y > 0 and safe.size.y > 0 and safe.size.y < screen.y - 2:
		var sy := vp.y / float(screen.y)
		var sx := vp.x / float(maxf(screen.x, 1))
		top = maxi(top, int(safe.position.y * sy) + 6)
		bot = maxi(bot, int((screen.y - (safe.position.y + safe.size.y)) * sy) + 6)
		left = maxi(left, int(safe.position.x * sx) + 6)
		right = maxi(right, int((screen.x - (safe.position.x + safe.size.x)) * sx) + 6)
	if OS.get_name() == "iOS":
		top = maxi(top, 88)
		bot = maxi(bot, 36)
	return {"l": left, "t": top, "r": right, "b": bot}


static func button(text: String, wide: float = 440, tall: float = 86) -> Button:
	ensure()
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(wide, tall)
	b.add_theme_font_override("font", font_x)
	b.add_theme_font_size_override("font_size", 34)
	b.add_theme_color_override("font_color", Color("3a241c"))
	b.add_theme_color_override("font_hover_color", Color("3a241c"))
	b.add_theme_color_override("font_pressed_color", Color("3a241c"))
	b.add_theme_color_override("font_focus_color", Color("3a241c"))
	b.add_theme_stylebox_override("normal", chunky(Color("ffc56a"), Color("b87432")))
	b.add_theme_stylebox_override("hover", chunky(Color("ffd48a"), Color("b87432")))
	b.add_theme_stylebox_override("pressed", chunky(Color("e8a84e"), Color("8d5a28"), true))
	b.add_theme_stylebox_override("focus", chunky(Color("ffd48a"), Color("b87432")))
	b.pressed.connect(func() -> void: AudioDirector.play("click"))
	b.button_down.connect(func() -> void:
		b.pivot_offset = b.size * 0.5
		var tw := b.create_tween()
		tw.tween_property(b, "scale", Vector2(0.97, 0.93), 0.05)
	)
	b.button_up.connect(func() -> void:
		var tw := b.create_tween()
		tw.tween_property(b, "scale", Vector2.ONE, 0.1).set_trans(Tween.TRANS_BACK)
	)
	return b
