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
var _fade: TextureRect
var _cap := 0.86


## `height` is the most of the screen the sheet may take; it shrinks to fit
## its content when that is less.
func open(title: String, build: Callable, height := 0.86) -> void:
	builder = build
	_cap = height
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
	var wrap := Control.new()
	wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(wrap)
	_scroll = ScrollContainer.new()
	_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	wrap.add_child(_scroll)
	# A fade at the bottom edge says there is more to scroll to.
	_fade = TextureRect.new()
	var g := Gradient.new()
	g.set_color(0, Color(0.075, 0.07, 0.09, 0.0))
	g.set_color(1, Color(0.075, 0.07, 0.09, 1.0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	gt.width = 4
	gt.height = 64
	_fade.texture = gt
	_fade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_fade.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_fade.offset_top = -64.0
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(_fade)
	_scroll.get_v_scroll_bar().value_changed.connect(func(_v): _update_fade())
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
	_fit()
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
	_fit()
	_scroll.scroll_vertical = keep
	_update_fade()


## Sizes the panel to its content, up to the cap.
func _fit() -> void:
	var vh := get_viewport_rect().size.y
	var chrome := 22.0 + 68.0 + 14.0 + 14.0 + 40.0
	var want: float = chrome + body.get_parent().get_combined_minimum_size().y
	var frac := clampf(want / vh, 0.3, _cap)
	panel.anchor_top = 1.0 - frac
	panel.offset_top = 0.0
	_update_fade()


func _update_fade() -> void:
	var bar := _scroll.get_v_scroll_bar()
	_fade.visible = bar.max_value - bar.page - bar.value > 8.0


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
