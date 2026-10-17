class_name ScreenBase
extends Control

signal travel(screen: String, args: Dictionary)

var paint_bg := true


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 0
	offset_top = 0
	offset_right = 0
	offset_bottom = 0
	mouse_filter = Control.MOUSE_FILTER_STOP
	if paint_bg:
		var bg := ColorRect.new()
		bg.color = Color("fff3e4")
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(bg)
	modulate.a = 0.0
	build()
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.14)


func build() -> void:
	pass


func open(_args: Dictionary = {}) -> void:
	pass


func go(screen: String, args: Dictionary = {}) -> void:
	travel.emit(screen, args)


func insets() -> Dictionary:
	return UiKit.safe_insets()


func column() -> VBoxContainer:
	var pad := insets()
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", int(pad["l"]))
	margin.add_theme_constant_override("margin_right", int(pad["r"]))
	margin.add_theme_constant_override("margin_top", int(pad["t"]))
	margin.add_theme_constant_override("margin_bottom", int(pad["b"]))
	add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(box)
	return box


func header() -> HBoxContainer:
	var row := HBoxContainer.new()
	var trophies := UiKit.label("%d trophies" % int(SaveGame.data["trophies"]), 22, Color("3a241c"), "b", 0)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var coins := UiKit.label("%d coins" % int(SaveGame.data["coins"]), 22, Color("8a5a18"), "b", 0)
	row.add_child(trophies)
	row.add_child(gap)
	row.add_child(coins)
	return row


func h1(text: String) -> Label:
	var label := UiKit.label(text, 44, Color("3a241c"), "x", 0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


func back_button(target: String, args: Dictionary = {}) -> Button:
	var button := UiKit.secondary("Back", 200, 64)
	button.pressed.connect(func() -> void: go(target, args))
	return button


func portrait(id: String, px: float) -> TextureRect:
	var rect := TextureRect.new()
	rect.custom_minimum_size = Vector2(px, px)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.texture = SpriteBank.critter(id)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


func body(text: String, size: int = 20) -> Label:
	var label := UiKit.label(text, size, Color("6d5144"), "m", 0)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label
