class_name ScreenBase
extends Control

signal travel(screen: String, args: Dictionary)

var paint_bg := true
var show_nav := false
var nav_tab := ""


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 0
	offset_top = 0
	offset_right = 0
	offset_bottom = 0
	mouse_filter = Control.MOUSE_FILTER_STOP
	modulate.a = 0.0
	build()
	if show_nav:
		var dock := UiKit.Dock.new(nav_tab, _nav)
		add_child(dock)
	if paint_bg:
		scale = Vector2(0.96, 0.96)
		call_deferred("_intro")
	else:
		var tw := create_tween()
		tw.tween_property(self, "modulate:a", 1.0, 0.12)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and paint_bg:
		queue_redraw()


func _draw() -> void:
	if paint_bg:
		UiKit.paint_menu(self)


func _intro() -> void:
	pivot_offset = size * 0.5
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "modulate:a", 1.0, 0.22)
	tw.tween_property(self, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _nav(screen: String) -> void:
	if screen == nav_tab:
		return
	go(screen)


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
	var bottom := int(pad["b"])
	if show_nav:
		bottom += 132
	margin.add_theme_constant_override("margin_left", int(pad["l"]))
	margin.add_theme_constant_override("margin_right", int(pad["r"]))
	margin.add_theme_constant_override("margin_top", int(pad["t"]))
	margin.add_theme_constant_override("margin_bottom", bottom)
	add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(box)
	return box


func header() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var trophies := UiKit.Pill.new("trophy", func() -> void: go("trophy"))
	trophies.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	trophies.set_amount(str(int(SaveGame.data["trophies"])))
	var coins := UiKit.Pill.new("coin", func() -> void: toast("Win hunts to earn coins."))
	coins.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	coins.set_amount(str(int(SaveGame.data["coins"])))
	var gems := UiKit.Pill.new("gem", func() -> void: toast("Free game. No shop."))
	gems.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gems.set_amount("0")
	row.add_child(trophies)
	row.add_child(coins)
	row.add_child(gems)
	return row


func h1(text: String) -> Label:
	return UiKit.title(text, 48)


func back_button(target: String, args: Dictionary = {}) -> Button:
	var button := UiKit.secondary("Back", 220, 64)
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
	var label := UiKit.label(text, size, Color("e7f2ff"), "b", 4)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


func toast(text: String) -> void:
	var label := UiKit.label(text, 28, UiKit.CREAM, "x", 6)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_CENTER)
	label.offset_left = -280
	label.offset_right = 280
	label.offset_top = -20
	label.offset_bottom = 40
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	label.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(label, "modulate:a", 1.0, 0.08)
	tw.tween_interval(0.7)
	tw.tween_property(label, "modulate:a", 0.0, 0.25)
	tw.tween_callback(label.queue_free)


func plate(node: Control) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", UiKit.panel())
	panel.add_child(node)
	return panel
