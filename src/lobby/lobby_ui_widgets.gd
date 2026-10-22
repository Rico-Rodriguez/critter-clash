extends CanvasLayer
## The camp screen, part 1 (see lobby_ui.gd): its fields and the small
## widget builders every sheet uses.

var lobby: Node3D
var chest_opening := false
var _shown_hero := ""
## Which tab of the Heroes sheet is showing.
var _hero_tab := "stats"
## Why a locked mode or place can't be picked, after a tap on it.
var _exp_note := ""
var _sheet: Sheet
var _sheet_name := ""
var equipment: Equipment
var _road_note: Array = []
## The side column (daily, campfire, season, feats) and its badges.
var _side: VBoxContainer
var _side_badges := {}
var _idle_label: Label
var _goal: Label
var _note_lines: Array = []

const MODE_ICON := {"horde": "skull-crossed-bones", "trial": "castle", "descent": "hourglass", "rush": "crowned-skull", "rift": "crystal-shine", "wild": "wolf-head"}


# --- Defined in lobby_ui.gd ---------------------------------------------

# The sheets call back into the camp screen; lobby_ui.gd overrides these.
func refresh() -> void:
	pass


func open_sheet(_name: String) -> void:
	pass


func open_equipment() -> void:
	pass


# --- Widgets ------------------------------------------------------------------

func _card() -> PanelContainer:
	var c := PanelContainer.new()
	c.theme_type_variation = "Card"
	return c


func _row(children: Array, sep := 12) -> HBoxContainer:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", sep)
	for c in children:
		r.add_child(c)
	return r


func _spacer() -> Control:
	var s := Control.new()
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return s


func _disc(icon: String, col: Color, size_: float) -> Panel:
	var p := Panel.new()
	p.custom_minimum_size = Vector2(size_, size_)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var st := StyleBoxFlat.new()
	st.bg_color = col.darkened(0.55)
	st.set_corner_radius_all(int(size_ * 0.5))
	st.set_border_width_all(3)
	st.border_color = col
	st.anti_aliasing = true
	p.add_theme_stylebox_override("panel", st)
	var ic := Ui.icon_rect(icon, size_ * 0.6, col.lightened(0.4))
	ic.position = Vector2(size_ * 0.2, size_ * 0.2)
	p.add_child(ic)
	return p


## A hero's portrait in a rounded frame; the flat icon disc until it is rendered.
func _portrait(id: String, col: Color, size_: float) -> Control:
	var t := Portraits.tex(id)
	if t == null:
		return _disc(DB.HEROES[id]["icon"], col, size_)
	var p := Panel.new()
	p.custom_minimum_size = Vector2(size_, size_)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var st := StyleBoxFlat.new()
	st.bg_color = col.darkened(0.7)
	st.set_corner_radius_all(int(size_ * 0.5))
	st.set_border_width_all(3)
	st.border_color = col
	st.anti_aliasing = true
	p.add_theme_stylebox_override("panel", st)
	p.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	var tr := TextureRect.new()
	tr.texture = t
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(tr)
	return p


func _num(v: float) -> String:
	return str(v).trim_suffix(".0")


## One choice in a picker: icon, name, a line of what it means. Locked choices
## are dimmed and say how to open them instead.
func _option(icon: String, title: String, sub: String, chosen: bool, lock: String, cb: Callable) -> Button:
	var btn := Button.new()
	btn.theme_type_variation = "Choice"
	btn.toggle_mode = true
	btn.button_pressed = chosen
	btn.focus_mode = Control.FOCUS_NONE
	btn.disabled = lock != ""
	# Each extra line of the description (tier notes) makes the card taller.
	btn.custom_minimum_size = Vector2(0, 112 + 34 * sub.count("\n"))
	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_theme_constant_override("margin_left", 18)
	m.add_theme_constant_override("margin_right", 18)
	btn.add_child(m)
	var h := HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_theme_constant_override("separation", 16)
	m.add_child(h)
	var ic := Ui.icon_rect("padlock" if lock != "" else icon, 48, Color(0.91, 0.71, 0.35) if chosen else Color(0.64, 0.6, 0.54))
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(ic)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	v.add_theme_constant_override("separation", 2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(v)
	var tl := Ui.label(title, "Value")
	tl.add_theme_font_size_override("font_size", 26)
	if lock != "":
		tl.modulate.a = 0.5
	v.add_child(tl)
	var sl := Ui.label(lock if lock != "" else sub, "Small")
	sl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(sl)
	btn.set_meta("title", tl)
	btn.pressed.connect(cb)
	return btn


## A short line that rises off a control and fades: feedback for a tap.
func _float_text(over: Control, text: String, color: Color) -> void:
	var l := Ui.label(text, "HudLabel")
	l.add_theme_font_size_override("font_size", 24)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	l.global_position = over.global_position + Vector2(over.size.x + 8.0, -over.size.y * 2.0)
	var t := l.create_tween().set_parallel(true)
	t.tween_property(l, "position:y", l.position.y - 40.0, 1.2).set_ease(Tween.EASE_OUT)
	t.tween_property(l, "modulate:a", 0.0, 1.2).set_delay(0.5)
	t.chain().tween_callback(l.queue_free)
