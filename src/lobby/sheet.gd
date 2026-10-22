class_name Sheet
extends Control
## A slide-up panel over the camp with a title, a close button and a
## scrolling body. The camp fills `body`; `rebuild` refills it in place.

signal closed

var body: VBoxContainer
var panel: PanelContainer
var title_label: Label
var builder: Callable
var _scroll: ScrollContainer


func open(title: String, build: Callable, height := 0.86) -> void:
	builder = build
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var scrim := ColorRect.new()
	scrim.color = Color(0, 0, 0, 0.55)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed:
			close())
	add_child(scrim)
	panel = PanelContainer.new()
	panel.theme_type_variation = "Sheet"
	panel.anchor_left = 0.0
	panel.anchor_right = 1.0
	panel.anchor_top = 1.0 - height
	panel.anchor_bottom = 1.0
	add_child(panel)
	# Keep the content clear of the home bar.
	var inset := MarginContainer.new()
	Ui.apply_safe_area(inset, 0)
	for side in ["margin_top", "margin_left", "margin_right"]:
		inset.add_theme_constant_override(side, 0)
	panel.add_child(inset)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	inset.add_child(v)
	var head := HBoxContainer.new()
	title_label = Ui.label(title, "Title")
	title_label.add_theme_font_size_override("font_size", 40)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title_label)
	var x := Button.new()
	x.theme_type_variation = "RoundButton"
	x.text = "✕"
	x.custom_minimum_size = Vector2(68, 68)
	x.focus_mode = Control.FOCUS_NONE
	x.add_theme_font_size_override("font_size", 28)
	x.add_theme_color_override("font_color", Color(0.91, 0.71, 0.35))
	x.pressed.connect(close)
	head.add_child(x)
	v.add_child(head)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(_scroll)
	var m := MarginContainer.new()
	m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m.add_theme_constant_override("margin_bottom", 40)
	m.add_theme_constant_override("margin_right", 6)
	_scroll.add_child(m)
	body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 16)
	m.add_child(body)
	builder.call(self)
	await get_tree().process_frame
	var end_y := panel.position.y
	panel.position.y = end_y + panel.size.y
	scrim.modulate.a = 0.0
	var t := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(panel, "position:y", end_y, 0.32)
	t.tween_property(scrim, "modulate:a", 1.0, 0.25)
	Sfx.play("ui_tap", -4.0)


func rebuild() -> void:
	var keep := _scroll.scroll_vertical
	Ui.clear(body)
	builder.call(self)
	await get_tree().process_frame
	_scroll.scroll_vertical = keep


func close() -> void:
	if not is_inside_tree():
		return
	Sfx.play("ui_back", -6.0)
	var t := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	t.tween_property(panel, "position:y", panel.position.y + panel.size.y, 0.22)
	t.tween_property(self, "modulate:a", 0.0, 0.22)
	t.chain().tween_callback(func():
		closed.emit()
		queue_free())
