extends SceneTree
## Writes res://src/ui/theme.tres, the one Theme every screen uses.
## godot --headless --path . -s res://tools/build_theme.gd
## Edit the tokens here (or the saved theme in the editor) — never per node.

const INK := Color("0d0c10")
const PANEL := Color("17151c")
const PANEL_HI := Color("221f29")
const LINE := Color("4a3d2a")
const GOLD := Color("e8b65a")
const TEXT := Color("f1e8d8")
const DIM := Color("a39a8a")
const EMBER := Color("d9622b")
const EMBER_DK := Color("7e2f10")
const SLATE := Color("2d2a36")
const SLATE_DK := Color("15131a")
const RED := Color("c23a32")
const TEAL := Color("3fc6c0")
const GOLD_FILL := Color("d4a24c")
const GOLD_RIM := Color("f6dfa6")
const GOLD_INK := Color("24170a")
## Dark glass: panels and cards over the camp, with a gold hairline.
const GLASS := Color(0.085, 0.07, 0.105, 0.9)

var theme := Theme.new()
var body: FontFile
var body_med: FontFile
var title: FontVariation
## Cinzel with air between the letters: buttons, captions and tabs.
var title_wide: FontVariation


func _init() -> void:
	body = load("res://assets/fonts/AlegreyaSans-Bold.ttf")
	body_med = load("res://assets/fonts/AlegreyaSans-Medium.ttf")
	title = FontVariation.new()
	title.base_font = load("res://assets/fonts/Cinzel-Variable.ttf")
	title.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 800}
	title_wide = title.duplicate() as FontVariation
	title_wide.spacing_glyph = 2
	theme.default_font = body
	theme.default_font_size = 26

	_labels()
	_panels()
	_buttons()
	_bars()
	_misc()
	_premium()
	var err := ResourceSaver.save(theme, "res://src/ui/theme.tres")
	print("theme: ", error_string(err))
	quit(0 if err == OK else 1)


func box(bg: Color, radius := 12, border := 0, border_color := LINE, bottom := -1) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.set_border_width_all(border)
	if bottom >= 0:
		s.border_width_bottom = bottom
	s.border_color = border_color
	s.content_margin_left = 18
	s.content_margin_right = 18
	s.content_margin_top = 12
	s.content_margin_bottom = 12
	s.anti_aliasing = true
	return s


func _labels() -> void:
	theme.set_color("font_color", "Label", TEXT)
	theme.set_color("font_outline_color", "Label", Color(0, 0, 0, 0.85))
	theme.set_constant("outline_size", "Label", 0)
	theme.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.0))
	for v in [["Title", 50, GOLD, 10], ["Heading", 32, GOLD, 0], ["HudTitle", 40, GOLD, 10], ["Value", 30, TEXT, 0], ["HudValue", 30, TEXT, 8]]:
		theme.set_type_variation(v[0], "Label")
		theme.set_font("font", v[0], title)
		theme.set_font_size("font_size", v[0], v[1])
		theme.set_color("font_color", v[0], v[2])
		theme.set_constant("outline_size", v[0], v[3])
	# Labels under pet portraits on the Breeding Wheel and the bestiary.
	theme.set_type_variation("Tiny", "Label")
	theme.set_font_size("font_size", "Tiny", 17)
	theme.set_color("font_color", "Tiny", TEXT)
	theme.set_font("font", "Tiny", body_med)
	theme.set_type_variation("Small", "Label")
	theme.set_font_size("font_size", "Small", 21)
	theme.set_color("font_color", "Small", DIM)
	theme.set_font("font", "Small", body_med)
	theme.set_type_variation("Body", "Label")
	theme.set_font("font", "Body", body_med)
	theme.set_font_size("font_size", "Body", 24)
	theme.set_type_variation("HudLabel", "Label")
	theme.set_constant("outline_size", "HudLabel", 8)
	theme.set_font_size("font_size", "HudLabel", 24)
	theme.set_type_variation("Caption", "Label")
	theme.set_font("font", "Caption", title_wide)
	theme.set_font_size("font_size", "Caption", 18)
	theme.set_color("font_color", "Caption", Color("b9a27a"))
	theme.set_color("default_color", "RichTextLabel", TEXT)
	theme.set_font("normal_font", "RichTextLabel", body_med)
	theme.set_font("bold_font", "RichTextLabel", body)
	theme.set_font_size("normal_font_size", "RichTextLabel", 24)
	theme.set_font_size("bold_font_size", "RichTextLabel", 24)


func _panels() -> void:
	var p := box(GLASS, 12, 1, Color(GOLD, 0.3))
	p.shadow_color = Color(0, 0, 0, 0.45)
	p.shadow_size = 12
	theme.set_stylebox("panel", "PanelContainer", p)
	theme.set_stylebox("panel", "Panel", p)
	theme.set_type_variation("Card", "PanelContainer")
	var c := box(Color(0.12, 0.1, 0.14, 0.88), 12, 1, Color(1, 1, 1, 0.07))
	theme.set_stylebox("panel", "Card", c)
	theme.set_type_variation("Sheet", "PanelContainer")
	var sh := box(Color(0.06, 0.05, 0.075, 0.98), 22, 0)
	sh.corner_radius_bottom_left = 0
	sh.corner_radius_bottom_right = 0
	sh.border_width_top = 1
	sh.border_color = Color(GOLD, 0.45)
	sh.content_margin_left = 24
	sh.content_margin_right = 24
	sh.content_margin_top = 22
	sh.shadow_color = Color(0, 0, 0, 0.6)
	sh.shadow_size = 24
	theme.set_stylebox("panel", "Sheet", sh)
	# A tab page: the sheet's margins over a backdrop drawn behind it.
	theme.set_type_variation("Page", "PanelContainer")
	var pg := sh.duplicate() as StyleBoxFlat
	pg.bg_color = Color(0, 0, 0, 0)
	pg.border_width_top = 0
	pg.shadow_size = 0
	theme.set_stylebox("panel", "Page", pg)
	theme.set_type_variation("Chip", "PanelContainer")
	var chip := box(Color(0.08, 0.065, 0.1, 0.82), 40, 1, Color(GOLD, 0.35))
	chip.content_margin_top = 6
	chip.content_margin_bottom = 6
	chip.content_margin_left = 14
	chip.content_margin_right = 18
	theme.set_stylebox("panel", "Chip", chip)
	# Notification badge: a red pill with a count (or empty, as a dot).
	theme.set_type_variation("Badge", "PanelContainer")
	var bd := box(Color("e0473a"), 20, 2, INK)
	bd.content_margin_left = 7
	bd.content_margin_right = 7
	bd.content_margin_top = 0
	bd.content_margin_bottom = 0
	theme.set_stylebox("panel", "Badge", bd)
	theme.set_type_variation("BadgeLabel", "Label")
	theme.set_font_size("font_size", "BadgeLabel", 18)
	theme.set_color("font_color", "BadgeLabel", TEXT)
	theme.set_type_variation("Plaque", "PanelContainer")
	var pl := box(GLASS, 10, 1, Color(GOLD, 0.35))
	pl.content_margin_top = 8
	pl.content_margin_bottom = 8
	theme.set_stylebox("panel", "Plaque", pl)
	# Old School parchment: the level-up scroll.
	theme.set_type_variation("Parchment", "PanelContainer")
	var pa := box(Color("cdbb93"), 8, 3, Color("5a4630"))
	pa.shadow_color = Color(0, 0, 0, 0.5)
	pa.shadow_size = 8
	pa.content_margin_top = 10
	pa.content_margin_bottom = 10
	theme.set_stylebox("panel", "Parchment", pa)
	theme.set_type_variation("ParchmentText", "Label")
	theme.set_color("font_color", "ParchmentText", Color("1d2a7a"))
	theme.set_font_size("font_size", "ParchmentText", 22)
	theme.set_type_variation("ParchmentTitle", "Label")
	theme.set_color("font_color", "ParchmentTitle", Color("6b1408"))
	theme.set_font("font", "ParchmentTitle", title)
	theme.set_font_size("font_size", "ParchmentTitle", 24)


## A button: a flat fill with a 1px lit rim and a soft shadow tinted `dk`
## (a dark drop for most, a warm glow for gold); it sinks 2px when pressed.
func _button_set(type: String, bg: Color, dk: Color, font_color: Color, size := 28, radius := 12, font = null, rim := Color(0, 0, 0, 0)) -> void:
	if type != "Button":
		theme.set_type_variation(type, "Button")
	var n := box(bg, radius, 1, rim if rim.a > 0.0 else bg.lightened(0.4))
	n.content_margin_top = 12
	n.content_margin_bottom = 12
	n.shadow_color = Color(dk, 0.45)
	n.shadow_size = 10
	n.shadow_offset = Vector2(0, 3)
	var h := n.duplicate()
	h.bg_color = bg.lightened(0.06)
	var pr := n.duplicate()
	pr.bg_color = bg.darkened(0.12)
	pr.shadow_size = 3
	pr.shadow_offset = Vector2(0, 1)
	pr.content_margin_top = 14
	pr.content_margin_bottom = 10
	var d := n.duplicate()
	d.bg_color = bg.darkened(0.5).lerp(Color(0.12, 0.11, 0.14), 0.6)
	d.border_color = Color(1, 1, 1, 0.08)
	d.shadow_size = 0
	var f := StyleBoxEmpty.new()
	theme.set_stylebox("normal", type, n)
	theme.set_stylebox("hover", type, h)
	theme.set_stylebox("pressed", type, pr)
	theme.set_stylebox("hover_pressed", type, pr)
	theme.set_stylebox("disabled", type, d)
	theme.set_stylebox("focus", type, f)
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		theme.set_color(k, type, font_color)
	theme.set_color("font_disabled_color", type, Color(TEXT, 0.35))
	theme.set_constant("outline_size", type, 0)
	theme.set_font_size("font_size", type, size)
	theme.set_font("font", type, font if font != null else title_wide)
	theme.set_constant("h_separation", type, 10)
	theme.set_constant("icon_max_width", type, 36)
	for k in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color", "icon_hover_pressed_color"]:
		theme.set_color(k, type, font_color)
	theme.set_color("icon_disabled_color", type, Color(TEXT, 0.3))


func _buttons() -> void:
	_button_set("Button", Color("1c1823"), Color.BLACK, TEXT, 24, 12, null, Color(GOLD, 0.32))
	# The main actions are polished gold: a pale rim and a warm glow under them.
	_button_set("PrimaryButton", GOLD_FILL, GOLD_FILL, GOLD_INK, 30, 12, null, GOLD_RIM)
	_button_set("GoldButton", GOLD_FILL, GOLD_FILL, GOLD_INK, 26, 12, null, GOLD_RIM)
	_button_set("DangerButton", Color("6e231e"), Color.BLACK, TEXT, 24, 12, null, Color("d9776c"))
	# Flat tab / ghost buttons.
	theme.set_type_variation("Ghost", "Button")
	var g := box(Color(0, 0, 0, 0), 12, 0)
	var gh := box(Color(1, 1, 1, 0.05), 12, 0)
	for k in ["normal", "disabled"]:
		theme.set_stylebox(k, "Ghost", g)
	for k in ["hover", "pressed", "hover_pressed"]:
		theme.set_stylebox(k, "Ghost", gh)
	theme.set_stylebox("focus", "Ghost", StyleBoxEmpty.new())
	theme.set_color("font_color", "Ghost", DIM)
	theme.set_color("font_pressed_color", "Ghost", GOLD)
	theme.set_color("font_hover_color", "Ghost", TEXT)
	theme.set_color("font_hover_pressed_color", "Ghost", GOLD)
	theme.set_color("icon_normal_color", "Ghost", DIM)
	theme.set_color("icon_pressed_color", "Ghost", GOLD)
	theme.set_color("icon_hover_color", "Ghost", TEXT)
	theme.set_color("icon_hover_pressed_color", "Ghost", GOLD)
	theme.set_font("font", "Ghost", title_wide)
	theme.set_font_size("font_size", "Ghost", 20)
	theme.set_constant("icon_max_width", "Ghost", 46)
	# Segmented choice buttons (mode, location, difficulty): the chosen one is lit.
	theme.set_type_variation("Choice", "Ghost")
	var cn := box(Color(1, 1, 1, 0.03), 12, 1, Color(1, 1, 1, 0.09))
	var cp := box(Color(GOLD, 0.12), 12, 1, Color(GOLD, 0.85))
	cp.shadow_color = Color(GOLD, 0.18)
	cp.shadow_size = 10
	for k in ["normal", "hover", "disabled"]:
		theme.set_stylebox(k, "Choice", cn)
	for k in ["pressed", "hover_pressed"]:
		theme.set_stylebox(k, "Choice", cp)
	# A tappable summary card (the camp's expedition card): opens a picker.
	theme.set_type_variation("CardButton", "Ghost")
	var cb := box(GLASS, 12, 1, Color(GOLD, 0.38))
	cb.shadow_color = Color(0, 0, 0, 0.45)
	cb.shadow_size = 12
	var cbp := box(Color(0.13, 0.11, 0.15, 0.92), 12, 1, Color(GOLD, 0.75))
	for k in ["normal", "disabled"]:
		theme.set_stylebox(k, "CardButton", cb)
	for k in ["hover", "pressed", "hover_pressed"]:
		theme.set_stylebox(k, "CardButton", cbp)
	# Round icon buttons (pause, settings, arrows).
	theme.set_type_variation("RoundButton", "Button")
	# An orb: dark glass, a gold hairline, a soft drop shadow.
	var r := box(Color(0.1, 0.085, 0.12, 0.9), 60, 1, Color(GOLD, 0.5))
	r.shadow_color = Color(0, 0, 0, 0.5)
	r.shadow_size = 8
	r.shadow_offset = Vector2(0, 3)
	r.set_content_margin_all(12)
	var rp := r.duplicate()
	rp.bg_color = Color(0.12, 0.1, 0.12, 0.9)
	for k in ["normal", "hover", "disabled"]:
		theme.set_stylebox(k, "RoundButton", r)
	for k in ["pressed", "hover_pressed"]:
		theme.set_stylebox(k, "RoundButton", rp)
	theme.set_stylebox("focus", "RoundButton", StyleBoxEmpty.new())
	theme.set_constant("icon_max_width", "RoundButton", 40)
	for k in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_hover_pressed_color", "icon_focus_color"]:
		theme.set_color(k, "RoundButton", GOLD)


func _bar(type: String, fill: Color, bg := Color(0, 0, 0, 0.6), radius := 8) -> void:
	if type != "ProgressBar":
		theme.set_type_variation(type, "ProgressBar")
	var b := box(bg, radius, 2, Color(0, 0, 0, 0.9))
	b.set_content_margin_all(0)
	var f := box(fill, radius, 0)
	f.set_content_margin_all(0)
	f.border_width_top = 3
	f.border_color = fill.lightened(0.35)
	theme.set_stylebox("background", type, b)
	theme.set_stylebox("fill", type, f)
	theme.set_font_size("font_size", type, 18)
	theme.set_color("font_color", type, TEXT)
	theme.set_color("font_outline_color", type, Color.BLACK)
	theme.set_constant("outline_size", type, 5)


func _bars() -> void:
	_bar("ProgressBar", GOLD)
	_bar("HPBar", Color("cf3b34"))
	_bar("XPBar", TEAL, Color(0, 0, 0, 0.55), 5)
	_bar("BossBar", Color("b0281f"), Color(0, 0, 0, 0.7), 4)
	_bar("SoulBar", Color("7fd6ff"), Color(0, 0, 0, 0.55), 6)


func _misc() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.18)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 3
	sb.content_margin_right = 3
	var empty := StyleBoxEmpty.new()
	theme.set_stylebox("scroll", "VScrollBar", empty)
	theme.set_stylebox("grabber", "VScrollBar", sb)
	theme.set_stylebox("grabber_highlight", "VScrollBar", sb)
	theme.set_stylebox("grabber_pressed", "VScrollBar", sb)
	theme.set_stylebox("panel", "ScrollContainer", empty)
	# Slider.
	var track := box(Color(0, 0, 0, 0.6), 6, 0)
	track.content_margin_top = 4
	track.content_margin_bottom = 4
	var fill := box(GOLD, 6, 0)
	fill.content_margin_top = 4
	fill.content_margin_bottom = 4
	theme.set_stylebox("slider", "HSlider", track)
	theme.set_stylebox("grabber_area", "HSlider", fill)
	theme.set_stylebox("grabber_area_highlight", "HSlider", fill)
	# Separators.
	var line := StyleBoxLine.new()
	line.color = Color(GOLD, 0.25)
	line.thickness = 2
	theme.set_stylebox("separator", "HSeparator", line)
	theme.set_constant("separation", "HSeparator", 16)
	theme.set_constant("separation", "VBoxContainer", 12)
	theme.set_constant("separation", "HBoxContainer", 12)
	theme.set_constant("h_separation", "GridContainer", 14)
	theme.set_constant("v_separation", "GridContainer", 14)
	# Check buttons use the same text.
	theme.set_color("font_color", "CheckButton", TEXT)
	theme.set_color("font_pressed_color", "CheckButton", TEXT)
	theme.set_color("font_hover_color", "CheckButton", TEXT)
	theme.set_color("font_hover_pressed_color", "CheckButton", TEXT)
	theme.set_stylebox("focus", "CheckButton", StyleBoxEmpty.new())
	# Tooltip-ish panel for the item card.
	theme.set_color("font_color", "LineEdit", TEXT)
	_social()


## The camp's bottom tab bar, chat bubbles and text fields (names, codes, chat).
func _social() -> void:
	# The bar sits flush with the bottom edge under a gold hairline.
	theme.set_type_variation("NavBar", "PanelContainer")
	var nb := box(Color("0f0d13"), 0, 0)
	nb.border_width_top = 1
	nb.border_color = Color(GOLD, 0.35)
	nb.set_content_margin_all(0)
	nb.shadow_color = Color(0, 0, 0, 0.6)
	nb.shadow_size = 18
	theme.set_stylebox("panel", "NavBar", nb)
	# A tab: a muted icon over its name; the open one is gold, with a glowing
	# line along the bar's top edge.
	theme.set_type_variation("NavTab", "Ghost")
	var tn := box(Color(0, 0, 0, 0), 0, 0)
	tn.set_content_margin_all(2)
	tn.content_margin_top = 8
	var tp := tn.duplicate() as StyleBoxFlat
	tp.bg_color = Color(GOLD, 0.07)
	tp.border_width_top = 2
	tp.border_color = Color("f3d58f")
	tp.expand_margin_top = 1
	tp.shadow_color = Color(GOLD, 0.12)
	tp.shadow_size = 16
	for k in ["normal", "hover", "disabled", "focus"]:
		theme.set_stylebox(k, "NavTab", tn)
	for k in ["pressed", "hover_pressed"]:
		theme.set_stylebox(k, "NavTab", tp)
	theme.set_font("font", "NavTab", title_wide)
	theme.set_font_size("font_size", "NavTab", 14)
	theme.set_constant("outline_size", "NavTab", 0)
	theme.set_constant("icon_max_width", "NavTab", 40)
	theme.set_constant("h_separation", "NavTab", 0)
	for k in ["font_color", "font_hover_color"]:
		theme.set_color(k, "NavTab", Color("7d7466"))
	for k in ["font_pressed_color", "font_hover_pressed_color"]:
		theme.set_color(k, "NavTab", Color("f3d58f"))
	theme.set_color("icon_normal_color", "NavTab", Color("7d7466"))
	theme.set_color("icon_hover_color", "NavTab", Color("a39a8a"))
	theme.set_color("icon_pressed_color", "NavTab", Color("f6e3b4"))
	theme.set_color("icon_hover_pressed_color", "NavTab", Color("f6e3b4"))
	# Chat: others on the left in slate, yours on the right in warm brown;
	# system lines (drops, joins, raid hits) sit centered without a bubble.
	theme.set_type_variation("Bubble", "PanelContainer")
	var bo := box(PANEL_HI, 14, 0)
	bo.corner_radius_bottom_left = 3
	bo.content_margin_top = 8
	bo.content_margin_bottom = 8
	bo.content_margin_left = 14
	bo.content_margin_right = 14
	theme.set_stylebox("panel", "Bubble", bo)
	theme.set_type_variation("BubbleMine", "PanelContainer")
	var bm := bo.duplicate()
	bm.bg_color = Color("3a2f1f")
	bm.corner_radius_bottom_left = 14
	bm.corner_radius_bottom_right = 3
	theme.set_stylebox("panel", "BubbleMine", bm)
	# An invite or raid card inside the chat: outlined in the party blue.
	theme.set_type_variation("InviteCard", "PanelContainer")
	var ic := box(Color("1b1f2a"), 12, 3, Color("4f8de0"))
	theme.set_stylebox("panel", "InviteCard", ic)
	# A reward: a warm card with a gold edge (gifts, the invite screen).
	theme.set_type_variation("GiftCard", "PanelContainer")
	var gc := box(Color("2a2116"), 12, 3, GOLD)
	gc.shadow_color = Color(GOLD, 0.18)
	gc.shadow_size = 10
	theme.set_stylebox("panel", "GiftCard", gc)
	# The Trophy Road: a step still ahead, a step passed, a step that opens a
	# mode, arena or hero (warm, gold edge), the step ready to claim (ember
	# edge, glowing), an arena's banner, and the "you are here" pill.
	theme.set_type_variation("RoadStep", "PanelContainer")
	var rs := box(Color("1a171f"), 16, 2, Color(1, 1, 1, 0.07))
	rs.content_margin_top = 14
	rs.content_margin_bottom = 14
	theme.set_stylebox("panel", "RoadStep", rs)
	theme.set_type_variation("RoadDone", "PanelContainer")
	var rd := rs.duplicate()
	rd.bg_color = Color("141217")
	rd.border_color = Color(GOLD, 0.16)
	theme.set_stylebox("panel", "RoadDone", rd)
	theme.set_type_variation("RoadUnlock", "PanelContainer")
	var ru := rs.duplicate()
	ru.bg_color = Color("241c18")
	ru.border_color = Color(GOLD, 0.55)
	ru.shadow_color = Color(GOLD, 0.08)
	ru.shadow_size = 12
	theme.set_stylebox("panel", "RoadUnlock", ru)
	theme.set_type_variation("RoadReady", "PanelContainer")
	var rr := rs.duplicate()
	rr.bg_color = Color("3a2016")
	rr.set_border_width_all(3)
	rr.border_color = EMBER.lightened(0.15)
	rr.shadow_color = Color(EMBER, 0.45)
	rr.shadow_size = 22
	theme.set_stylebox("panel", "RoadReady", rr)
	theme.set_type_variation("RoadArena", "PanelContainer")
	var ra := box(Color(0.06, 0.05, 0.08, 0.72), 22, 3, Color(GOLD, 0.6))
	ra.shadow_color = Color(0, 0, 0, 0.55)
	ra.shadow_size = 18
	ra.content_margin_left = 26
	ra.content_margin_right = 26
	ra.content_margin_top = 22
	ra.content_margin_bottom = 22
	theme.set_stylebox("panel", "RoadArena", ra)
	theme.set_type_variation("RoadHere", "PanelContainer")
	var rh := box(GOLD, 30, 3, Color("fff0c8"))
	rh.content_margin_top = 4
	rh.content_margin_bottom = 4
	rh.content_margin_left = 14
	rh.content_margin_right = 14
	rh.shadow_color = Color(GOLD, 0.5)
	rh.shadow_size = 14
	theme.set_stylebox("panel", "RoadHere", rh)
	theme.set_type_variation("RoadHereLabel", "Label")
	theme.set_font("font", "RoadHereLabel", title)
	theme.set_font_size("font_size", "RoadHereLabel", 24)
	theme.set_color("font_color", "RoadHereLabel", Color("2a1a06"))
	theme.set_type_variation("RoadTag", "Label")
	theme.set_font("font", "RoadTag", title)
	theme.set_font_size("font_size", "RoadTag", 17)
	theme.set_color("font_color", "RoadTag", GOLD)
	theme.set_type_variation("RoadNum", "Label")
	theme.set_font("font", "RoadNum", title)
	theme.set_font_size("font_size", "RoadNum", 26)
	theme.set_color("font_color", "RoadNum", Color("f5d38c"))
	theme.set_constant("outline_size", "RoadNum", 6)
	_button_set("BlueButton", Color("27477d"), Color.BLACK, Color("eef3ff"), 22, 12, null, Color("8fb4f0"))
	_button_set("GreenButton", Color("235e3b"), Color.BLACK, Color("eefff2"), 24, 12, null, Color("8fe0a8"))
	# Text fields: dark wells with a gold caret.
	var le := box(Color(0, 0, 0, 0.5), 12, 2, Color(1, 1, 1, 0.1))
	le.content_margin_top = 14
	le.content_margin_bottom = 14
	var lf := le.duplicate()
	lf.border_color = Color(GOLD, 0.7)
	theme.set_stylebox("normal", "LineEdit", le)
	theme.set_stylebox("focus", "LineEdit", lf)
	theme.set_stylebox("read_only", "LineEdit", le)
	theme.set_color("font_placeholder_color", "LineEdit", Color(DIM, 0.8))
	theme.set_color("caret_color", "LineEdit", GOLD)
	theme.set_color("selection_color", "LineEdit", Color(GOLD, 0.35))
	theme.set_font("font", "LineEdit", body_med)
	theme.set_font_size("font_size", "LineEdit", 26)


## The camp's premium pieces: the gold HUNT bar, glass pills and slots,
## gold-trimmed price tags and dark shop tiles edged in their rarity's color.
## Shine and motion come from src/ui/fx_ui.gd.
func _premium() -> void:
	_button_set("HuntButton", GOLD_FILL, GOLD_FILL, GOLD_INK, 40, 12, null, GOLD_RIM)
	theme.set_type_variation("HuntLabel", "Label")
	var hunt_font := title.duplicate() as FontVariation
	hunt_font.spacing_glyph = 8
	theme.set_font("font", "HuntLabel", hunt_font)
	theme.set_font_size("font_size", "HuntLabel", 40)
	theme.set_color("font_color", "HuntLabel", GOLD_INK)
	theme.set_constant("outline_size", "HuntLabel", 0)
	theme.set_type_variation("HuntSub", "Label")
	theme.set_font("font", "HuntSub", body_med)
	theme.set_font_size("font_size", "HuntSub", 20)
	theme.set_color("font_color", "HuntSub", Color("5a3c14"))
	# A price tag: dark, trimmed in gold.
	_button_set("PriceButton", Color("1e1810"), Color.BLACK, Color("f3dca6"), 24, 10, body, Color("d6ae62"))
	for v in [["SeasonPill", Color(0.66, 0.55, 0.86, 0.55)], ["TrophyPill", Color(GOLD, 0.45)], ["SlotButton", Color(GOLD, 0.4)], ["ModeButton", Color(GOLD, 0.4)]]:
		_button_set(v[0], GLASS, Color.BLACK, TEXT, 18, 12, null, v[1])
	for t in ["SlotButton", "ModeButton"]:
		theme.set_constant("icon_max_width", t, 52)
	theme.set_type_variation("PillLabel", "Label")
	theme.set_font("font", "PillLabel", title_wide)
	theme.set_font_size("font_size", "PillLabel", 15)
	theme.set_color("font_color", "PillLabel", Color("cdbb96"))
	theme.set_constant("outline_size", "PillLabel", 0)
	# Shop tiles: dark cards edged in their rarity's color, brighter along
	# the top; a glow behind the art comes from the code.
	for v in [["TileSlate", "8d8578"], ["TileGreen", "6fd08a"], ["TileBlue", "5b8ee8"],
			["TilePurple", "a970f0"], ["TileGold", "f3d58f"], ["TileRed", "e8705e"]]:
		theme.set_type_variation(v[0], "Button")
		var rim := Color(v[1])
		var t := box(Color(0.1, 0.085, 0.12, 0.94), 12, 1, Color(rim, 0.5))
		t.border_width_top = 2
		t.set_content_margin_all(0)
		t.shadow_color = Color(0, 0, 0, 0.45)
		t.shadow_size = 10
		t.shadow_offset = Vector2(0, 3)
		var h := t.duplicate() as StyleBoxFlat
		h.border_color = Color(rim, 0.8)
		var pr := t.duplicate() as StyleBoxFlat
		pr.bg_color = Color(0.07, 0.06, 0.085, 0.96)
		pr.border_color = Color(rim, 0.9)
		pr.shadow_size = 3
		for k in ["normal", "disabled"]:
			theme.set_stylebox(k, v[0], t)
		theme.set_stylebox("hover", v[0], h)
		for k in ["pressed", "hover_pressed"]:
			theme.set_stylebox(k, v[0], pr)
		theme.set_stylebox("focus", v[0], StyleBoxEmpty.new())
	# The price under a shop tile: a gold-trimmed tag, or a faint one once
	# it's yours.
	for v in [["PricePlate", Color("1e1810"), Color("d6ae62")], ["OwnedPlate", Color(0, 0, 0, 0), Color(1, 1, 1, 0.14)]]:
		theme.set_type_variation(v[0], "PanelContainer")
		var p := box(v[1], 8, 1, v[2])
		p.content_margin_top = 4
		p.content_margin_bottom = 4
		p.content_margin_left = 8
		p.content_margin_right = 8
		theme.set_stylebox("panel", v[0], p)
	theme.set_type_variation("PriceLabel", "Label")
	theme.set_font("font", "PriceLabel", body)
	theme.set_font_size("font_size", "PriceLabel", 22)
	theme.set_color("font_color", "PriceLabel", Color("f3dca6"))
	theme.set_constant("outline_size", "PriceLabel", 0)
	# A discount in a tile's corner: gold lettering, no plate.
	theme.set_type_variation("Ribbon", "PanelContainer")
	var rb := StyleBoxEmpty.new()
	theme.set_stylebox("panel", "Ribbon", rb)
	theme.set_type_variation("RibbonLabel", "Label")
	theme.set_font("font", "RibbonLabel", title_wide)
	theme.set_font_size("font_size", "RibbonLabel", 16)
	theme.set_color("font_color", "RibbonLabel", Color("f3d58f"))
	# The day's headline deal: a card with a brighter gold edge.
	theme.set_type_variation("FeatureCard", "PanelContainer")
	var fc := box(Color(0.1, 0.08, 0.11, 0.95), 14, 1, Color(GOLD, 0.55))
	fc.border_width_top = 2
	fc.border_color = Color(GOLD, 0.6)
	fc.shadow_color = Color(0, 0, 0, 0.5)
	fc.shadow_size = 14
	fc.set_content_margin_all(16)
	theme.set_stylebox("panel", "FeatureCard", fc)
	# A row of text tabs (the shop's Deals, Chests, Skins): the open one is
	# gold with a glowing underline.
	theme.set_type_variation("TextTab", "Ghost")
	var tt := box(Color(0, 0, 0, 0), 0, 0)
	tt.content_margin_top = 10
	tt.content_margin_bottom = 10
	var ttp := tt.duplicate() as StyleBoxFlat
	ttp.border_width_bottom = 2
	ttp.border_color = Color("f3d58f")
	for k in ["normal", "hover", "disabled", "focus"]:
		theme.set_stylebox(k, "TextTab", tt)
	for k in ["pressed", "hover_pressed"]:
		theme.set_stylebox(k, "TextTab", ttp)
	theme.set_font("font", "TextTab", title_wide)
	theme.set_font_size("font_size", "TextTab", 19)
	for k in ["font_color", "font_hover_color"]:
		theme.set_color(k, "TextTab", Color("7d7466"))
	for k in ["font_pressed_color", "font_hover_pressed_color"]:
		theme.set_color(k, "TextTab", Color("f3d58f"))
	# The hero's name over their feet: wide-set capitals with a soft glow.
	theme.set_type_variation("HeroTitle", "Label")
	var hero_font := title.duplicate() as FontVariation
	hero_font.spacing_glyph = 5
	theme.set_font("font", "HeroTitle", hero_font)
	theme.set_font_size("font_size", "HeroTitle", 44)
	theme.set_color("font_color", "HeroTitle", Color("f6e7c4"))
	theme.set_color("font_shadow_color", "HeroTitle", Color(GOLD, 0.35))
	theme.set_constant("shadow_outline_size", "HeroTitle", 12)
	theme.set_constant("shadow_offset_x", "HeroTitle", 0)
	theme.set_constant("shadow_offset_y", "HeroTitle", 0)
	# The Trophy Road's thin gold line.
	_bar("RoadBar", Color("e9c27a"), Color(1, 1, 1, 0.08), 4)
	var rf := theme.get_stylebox("fill", "RoadBar").duplicate() as StyleBoxFlat
	rf.border_width_top = 0
	rf.shadow_color = Color(GOLD, 0.5)
	rf.shadow_size = 6
	theme.set_stylebox("fill", "RoadBar", rf)
	var rbg := theme.get_stylebox("background", "RoadBar").duplicate() as StyleBoxFlat
	rbg.set_border_width_all(0)
	theme.set_stylebox("background", "RoadBar", rbg)
	# The mode's icon well on the mode card: violet glass.
	theme.set_type_variation("ModeWell", "PanelContainer")
	var mw := box(Color("261a3a"), 12, 1, Color(0.66, 0.55, 0.86, 0.5))
	mw.set_content_margin_all(14)
	theme.set_stylebox("panel", "ModeWell", mw)
