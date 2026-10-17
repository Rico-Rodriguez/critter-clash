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


static func paint_menu(c: Control) -> void:
	var h := maxf(c.size.y, 1.0)
	var w := maxf(c.size.x, 1.0)
	var top := Color("2f7de0")
	var bot := Color("12306e")
	var steps := 28
	for i in steps:
		var t := float(i) / float(steps)
		c.draw_rect(Rect2(0, h * t, w, h / float(steps) + 2.0), top.lerp(bot, t), true)
	var span := w + h
	var x := -h
	while x < span:
		c.draw_line(Vector2(x, 0), Vector2(x + h * 0.72, h), Color(1, 1, 1, 0.07), 16.0)
		x += 42.0
	c.draw_rect(Rect2(0, 0, w, 80), Color(0, 0, 0, 0.16), true)
	c.draw_rect(Rect2(0, h - 110, w, 110), Color(0, 0, 0, 0.26), true)
	c.draw_rect(Rect2(0, 0, 22, h), Color(0, 0, 0, 0.18), true)
	c.draw_rect(Rect2(w - 22, 0, 22, h), Color(0, 0, 0, 0.18), true)


static func title(text: String, size: int = 52) -> Label:
	var l := label(text, size, CREAM, "x", maxi(8, int(size / 6)))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


static func chunky(bg: Color, lip: Color, pressed: bool = false) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	var r := 18
	s.set_corner_radius_all(r)
	s.border_width_left = 4
	s.border_width_right = 4
	s.border_width_top = 4
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


static func panel(bg: Color = Color("163e86"), radius: int = 22) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.border_width_left = 6
	s.border_width_right = 6
	s.border_width_top = 6
	s.border_width_bottom = 8
	s.border_color = Color("f0d48a")
	s.shadow_color = Color(0, 0, 0, 0.45)
	s.shadow_size = 10
	s.shadow_offset = Vector2(0, 6)
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 12
	s.content_margin_bottom = 12
	return s


static func wood_panel(radius: int = 26) -> StyleBoxFlat:
	var s := panel(Color("6a3d22"), radius)
	s.border_color = Color("e8c07a")
	s.border_width_bottom = 12
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


static func _btn(text: String, wide: float, tall: float, tone: String, round: bool) -> Button:
	ensure()
	var b := Btn.new()
	b.tone = tone
	b.round = round
	b.text = text
	b.custom_minimum_size = Vector2(wide, tall)
	b.pressed.connect(func() -> void: AudioDirector.play("click"))
	return b


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


class Btn extends Button:
	var tone := "gold"
	var round := false
	var _box: StyleBoxFlat

	func _ready() -> void:
		UiKit.ensure()
		focus_mode = Control.FOCUS_NONE
		var empty := StyleBoxEmpty.new()
		for state in ["normal", "hover", "pressed", "focus", "disabled"]:
			add_theme_stylebox_override(state, empty)
		add_theme_font_override("font", UiKit.font_x)
		var px := int(clampf(custom_minimum_size.y * 0.40, 18, 46))
		add_theme_font_size_override("font_size", px)
		# The engine paints the caption before _draw, so the gloss would cover it.
		# Caption is drawn by hand at the end of _draw instead.
		for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
			add_theme_color_override(key, Color(0, 0, 0, 0))
		add_theme_constant_override("outline_size", 0)
		button_down.connect(_sink)
		button_up.connect(_rise)

	func _sink() -> void:
		pivot_offset = size * 0.5
		scale = Vector2(0.96, 0.90)
		AudioDirector.haptic(14)
		queue_redraw()

	func _rise() -> void:
		var tw := create_tween()
		tw.tween_property(self, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		queue_redraw()

	func _draw() -> void:
		var sunk := button_pressed
		var lip := 4.0 if sunk else 10.0
		var drop := 6.0 if sunk else 0.0
		var rect := Rect2(5, 3 + drop, maxf(8.0, size.x - 10), maxf(12.0, size.y - 14))
		var face := Color("8a8a8a")
		var lip_col := Color("4e4e4e")
		if not disabled:
			match tone:
				"blue":
					face = UiKit.BLUE
					lip_col = UiKit.BLUE_LIP
				"green":
					face = UiKit.GREEN
					lip_col = UiKit.GREEN_LIP
				"red":
					face = UiKit.RED
					lip_col = UiKit.RED_LIP
				_:
					face = UiKit.GOLD
					lip_col = UiKit.GOLD_LIP
		var radius := int(minf(rect.size.x, rect.size.y) * 0.48) if round else 16
		_paint(rect.grow(3), radius + 3, UiKit.INK)
		_paint(Rect2(rect.position.x, rect.position.y + rect.size.y - lip, rect.size.x, lip + 3), radius, lip_col)
		_paint(Rect2(rect.position, Vector2(rect.size.x, rect.size.y - lip)), radius, face)
		if not disabled:
			var gloss_h := (rect.size.y - lip) * 0.40
			_paint(Rect2(rect.position.x + 8, rect.position.y + 4, maxf(4.0, rect.size.x - 16), gloss_h), maxi(8, radius - 4), Color(1, 1, 1, 0.34))
		_draw_caption(rect, lip)

	func _draw_caption(rect: Rect2, lip: float) -> void:
		if text == "":
			return
		UiKit.ensure()
		var font := UiKit.font_x
		if font == null:
			return
		var px := int(clampf(size.y * (0.46 if round else 0.38), 16, 42))
		var bounds := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px)
		var face_h := maxf(8.0, rect.size.y - lip)
		var baseline := rect.position.y + (face_h - bounds.y) * 0.5 + font.get_ascent(px)
		var origin := Vector2(rect.position.x + (rect.size.x - bounds.x) * 0.5, baseline)
		var ink := Color(1, 1, 1, 0.7) if disabled else Color.WHITE
		var edge := Color(0.2, 0.2, 0.2, 0.8) if disabled else UiKit.INK
		draw_string(font, origin + Vector2(0, 4), text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color(0, 0, 0, 0.45))
		for ring in [2, 4, 6]:
			for i in 8:
				var off := Vector2.from_angle(float(i) * TAU / 8.0) * float(ring)
				draw_string(font, origin + off, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, edge)
		draw_string(font, origin, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, ink)

	func _paint(rect: Rect2, radius: int, color: Color) -> void:
		if _box == null:
			_box = StyleBoxFlat.new()
		_box.bg_color = color
		_box.set_corner_radius_all(maxi(0, radius))
		_box.draw(get_canvas_item(), rect)


class Backdrop extends Control:
	func _ready() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var h := maxf(size.y, 1.0)
		var w := maxf(size.x, 1.0)
		var top := Color("2f7de0")
		var bot := Color("12306e")
		var steps := 28
		for i in steps:
			var t := float(i) / float(steps)
			var band := Rect2(0, h * t, w, h / float(steps) + 2.0)
			draw_rect(band, top.lerp(bot, t), true)
		var gap := 46.0
		var y := 10.0
		var row := 0
		while y < h:
			var x := 8.0 if row % 2 == 0 else 30.0
			while x < w:
				draw_rect(Rect2(x, y, 10, 10), Color(1, 1, 1, 0.045), true)
				x += gap
			y += gap * 0.72
			row += 1
		draw_rect(Rect2(0, 0, w, 70), Color(0, 0, 0, 0.18), true)
		draw_rect(Rect2(0, h - 90, w, 90), Color(0, 0, 0, 0.28), true)
		draw_rect(Rect2(0, 0, 18, h), Color(0, 0, 0, 0.16), true)
		draw_rect(Rect2(w - 18, 0, 18, h), Color(0, 0, 0, 0.16), true)


class Pill extends PanelContainer:
	var value_label: Label
	var _target := "0"
	var _shown := 0

	func _init(kind: String, plus: Callable) -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var plate := UiKit.wood_panel(18)
		plate.content_margin_left = 8
		plate.content_margin_right = 6
		plate.content_margin_top = 4
		plate.content_margin_bottom = 6
		add_theme_stylebox_override("panel", plate)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		add_child(row)
		var icon := UiKit.Gem.new()
		icon.kind = kind
		icon.custom_minimum_size = Vector2(36, 36)
		row.add_child(icon)
		value_label = UiKit.label("0", 26, UiKit.CREAM, "x", 5)
		value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(value_label)
		var more := UiKit.icon_button("+", 40, "green")
		more.pressed.connect(plus)
		row.add_child(more)

	func set_amount(text: String) -> void:
		_target = text
		if is_inside_tree():
			_tick()
		else:
			call_deferred("_tick")

	func _tick() -> void:
		if not _target.is_valid_int():
			value_label.text = _target
			return
		var goal := int(_target)
		if goal == _shown:
			value_label.text = str(goal)
			return
		var from := _shown
		_shown = goal
		var tw := create_tween()
		tw.tween_method(_paint_count, float(from), float(goal), 0.38)

	func _paint_count(value: float) -> void:
		value_label.text = str(int(round(value)))


class Gem extends Control:
	var kind := "coin"

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size * 0.5
		match kind:
			"trophy":
				draw_circle(c + Vector2(0, 4), 14, Color("e7c36a"))
				draw_rect(Rect2(c.x - 8, c.y - 12, 16, 14), Color("ffe7a0"), true)
				draw_rect(Rect2(c.x - 10, c.y + 6, 20, 5), Color("c48a28"), true)
			"gem":
				var pts := PackedVector2Array([
					c + Vector2(0, -14), c + Vector2(12, -2), c + Vector2(0, 14), c + Vector2(-12, -2)
				])
				draw_colored_polygon(pts, Color("49e0c8"))
				draw_colored_polygon(PackedVector2Array([c + Vector2(0, -8), c + Vector2(6, 0), c + Vector2(0, 4), c + Vector2(-6, 0)]), Color(1, 1, 1, 0.45))
			_:
				draw_circle(c, 14, Color("f0b429"))
				draw_circle(c + Vector2(-4, -4), 5, Color(1, 1, 1, 0.55))
				draw_arc(c, 8, 0.4, 2.4, 8, Color("a86a10"), 2.0, true)


class Dock extends PanelContainer:
	func _init(current: String, go: Callable) -> void:
		set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		offset_top = -128
		offset_bottom = 0
		var plate := UiKit.wood_panel(0)
		plate.corner_radius_top_left = 22
		plate.corner_radius_top_right = 22
		plate.corner_radius_bottom_left = 0
		plate.corner_radius_bottom_right = 0
		plate.content_margin_left = 8
		plate.content_margin_right = 8
		plate.content_margin_top = 8
		plate.content_margin_bottom = 10
		add_theme_stylebox_override("panel", plate)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		add_child(row)
		var tabs := [
			["collection", "CARDS"],
			["home", "BATTLE"],
			["trophy", "ROAD"],
			["world", "MAP"],
		]
		for tab in tabs:
			var id := str(tab[0])
			var tone := "gold" if id == current else "blue"
			var b := UiKit.button(str(tab[1]), 150, 78, tone)
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.pressed.connect(go.bind(id))
			row.add_child(b)
