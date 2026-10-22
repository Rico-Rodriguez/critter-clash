class_name Pact
extends Control
## A pact: two offers, each a gain with a price, or neither. The tree is
## paused underneath, like the level-up cards.

signal picked(id: String)

var _done := false


func open(choices: Array) -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var scrim := ColorRect.new()
	scrim.color = Color(0.03, 0.01, 0.04, 0.82)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(scrim)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	box.custom_minimum_size = Vector2(620, 0)
	box.offset_left = -310.0
	box.offset_right = 310.0
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.add_theme_constant_override("separation", 14)
	add_child(box)
	var title := Ui.label("A Pact", "Title", HORIZONTAL_ALIGNMENT_CENTER)
	title.add_theme_font_size_override("font_size", 56)
	box.add_child(title)
	box.add_child(Ui.label("Power has a price", "Caption", HORIZONTAL_ALIGNMENT_CENTER))
	for id: String in choices:
		box.add_child(_offer(id))
	var no := Button.new()
	no.text = "Refuse"
	no.theme_type_variation = "Ghost"
	no.custom_minimum_size = Vector2(0, 72)
	no.focus_mode = Control.FOCUS_NONE
	no.pressed.connect(func(): _pick(""))
	box.add_child(no)
	Ui.pop_in(box, 0.0, 0.92)


func _offer(id: String) -> Button:
	var p: Dictionary = DB.PACTS[id]
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 190)
	b.focus_mode = Control.FOCUS_NONE
	b.theme_type_variation = "Choice"
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 18
	row.offset_right = -18
	row.offset_top = 12
	row.offset_bottom = -12
	row.add_theme_constant_override("separation", 18)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(row)
	row.add_child(Ui.icon_rect(str(p["icon"]), 76, Color(0.95, 0.75, 0.4)))
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(Ui.label(str(p["name"]), "Heading"))
	var good := Ui.label("＋ " + str(p["good"]), "Body")
	good.add_theme_color_override("font_color", Color(0.5, 1.0, 0.6))
	v.add_child(good)
	var bad := Ui.label("－ " + str(p["bad"]), "Body")
	bad.add_theme_color_override("font_color", Color(1.0, 0.5, 0.45))
	v.add_child(bad)
	row.add_child(v)
	b.pressed.connect(func(): _pick(id))
	return b


func _pick(id: String) -> void:
	if _done:
		return
	_done = true
	Sfx.play("card_flip", -2.0)
	picked.emit(id)
