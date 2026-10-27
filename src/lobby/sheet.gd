class_name Sheet
extends Control
## A slide-up panel over the camp with a title, a close button and a
## scrolling body. The camp fills `body`; `rebuild` refills it in place.
## Tap outside, swipe the title down, or pull the list down from its top to
## close it.
##
## As a tab page (`page = true`, set before `open`) it fills its parent instead:
## no scrim, no close button, nothing to swipe away, and optional segments
## (sub-tabs) under the title that swap the builder.

const DragScroll := preload("res://src/ui/drag_scroll.gd")
const SwipeDismiss := preload("res://src/ui/swipe_dismiss.gd")
const FxUi := preload("res://src/ui/fx_ui.gd")
## A page's backdrop runs from this down to near-black.
const PAGE_BOTTOM := Color(0.04, 0.03, 0.06)

signal closed

var body: VBoxContainer
var panel: PanelContainer
var title_label: Label
var builder: Callable
var _scroll: DragScroll
var _fade: TextureRect
var _cap := 0.86
var page := false
## [[label, builder], ...] for a page's sub-tabs; `segment` is the one shown.
var segments: Array = []
var segment := 0
var _seg_row: HBoxContainer
## Buttons pinned under the scrolling body (Clash Royale's panel footer);
## builders fill it like `body`.
var footer: HBoxContainer
signal segment_changed(i: int)


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
	if not page:
		add_child(scrim)
	panel = PanelContainer.new()
	# A page is see-through over a slow misty backdrop with motes rising.
	panel.theme_type_variation = "Page" if page else "Sheet"
	panel.anchor_left = 0.0
	panel.anchor_right = 1.0
	panel.anchor_top = 0.0 if page else 1.0 - height
	panel.anchor_bottom = 1.0
	add_child(panel)
	if page:
		FxUi.backdrop(self, Color(0.11, 0.08, 0.14), PAGE_BOTTOM)
	else:
		var motes := Control.new()
		motes.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(motes)
		FxUi.add_motes(motes, Color(1.0, 0.8, 0.5, 0.35), 10, 18.0)
	var inset := MarginContainer.new()
	if page:
		# A page sits above the tab bar, so only the notch needs clearing.
		var ins := Ui.safe_insets(0)
		inset.add_theme_constant_override("margin_top", int(ins.y) + 30)
		for side in ["margin_left", "margin_right", "margin_bottom"]:
			inset.add_theme_constant_override(side, 0)
	else:
		# Keep the content clear of the home bar.
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
	if not page:
		head.add_child(x)
	v.add_child(head)
	# One segment needs no row of choices.
	if segments.size() > 1:
		_seg_row = HBoxContainer.new()
		_seg_row.add_theme_constant_override("separation", 8 if segments.size() < 5 else 6)
		v.add_child(_seg_row)
		_build_segments()
	var wrap := Control.new()
	wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(wrap)
	footer = HBoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	v.add_child(footer)
	_scroll = DragScroll.new()
	_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	wrap.add_child(_scroll)
	# A fade at the bottom edge says there is more to scroll to.
	_fade = TextureRect.new()
	var g := Gradient.new()
	var under := PAGE_BOTTOM if page else Color(0.075, 0.07, 0.09)
	g.set_color(0, Color(under, 0.0))
	g.set_color(1, under)
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
	if page:
		_call_builder()
		FxUi.deal_in(body, 0.05)
		return
	var swipe := SwipeDismiss.attach(panel, close, head)
	_scroll.pulled.connect(swipe.drag)
	_scroll.pull_released.connect(swipe.release)
	_call_builder()
	await get_tree().process_frame
	_fit()
	await get_tree().process_frame
	var end_y := panel.position.y
	panel.position.y = end_y + panel.size.y
	scrim.modulate.a = 0.0
	var t := create_tween().set_parallel(true).set_ease(Tween.EASE_OUT)
	# A small overshoot: the sheet lands with a spring, not a stop.
	t.tween_property(panel, "position:y", end_y, 0.42).set_trans(Tween.TRANS_BACK)
	t.tween_property(scrim, "modulate:a", 1.0, 0.25).set_trans(Tween.TRANS_CUBIC)
	FxUi.deal_in(body, 0.04, 0.9)
	Sfx.play("ui_tap", -4.0)


func rebuild() -> void:
	var keep := _scroll.scroll_vertical
	Ui.clear(body)
	_call_builder()
	await get_tree().process_frame
	if not page:
		_fit()
	_scroll.scroll_vertical = keep
	_update_fade()


## Sizes the panel to its content, up to the cap.
func _fit() -> void:
	var vh := get_viewport_rect().size.y
	var chrome := 22.0 + 68.0 + 14.0 + 14.0 + 40.0
	if footer.visible:
		chrome += footer.get_combined_minimum_size().y + 14.0
	var want: float = chrome + body.get_parent().get_combined_minimum_size().y
	var frac := clampf(want / vh, 0.3, _cap)
	panel.anchor_top = 1.0 - frac
	panel.offset_top = 0.0
	_update_fade()


func _update_fade() -> void:
	var bar := _scroll.get_v_scroll_bar()
	_fade.visible = bar.max_value - bar.page - bar.value > 8.0


## Shows a page's sub-tab `i`, from the top.
func show_segment(i: int) -> void:
	if segments.is_empty():
		return
	segment = clampi(i, 0, segments.size() - 1)
	builder = segments[segment][1]
	_build_segments()
	Ui.clear(body)
	_call_builder()
	FxUi.deal_in(body, 0.05)
	_scroll.scroll_vertical = 0
	segment_changed.emit(segment)


func _build_segments() -> void:
	if _seg_row == null:
		return
	Ui.clear(_seg_row)
	for i in segments.size():
		var b := Button.new()
		b.theme_type_variation = &"Choice"
		b.toggle_mode = true
		b.button_pressed = i == segment
		b.text = str(segments[i][0])
		b.custom_minimum_size = Vector2(0, 66)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.focus_mode = Control.FOCUS_NONE
		# Five segments need a smaller label to fit one row.
		b.add_theme_font_size_override("font_size", 22 if segments.size() < 5 else 17)
		if segments.size() >= 5:
			b.clip_text = true
		var n := i
		b.pressed.connect(func():
			Sfx.play("ui_toggle", -6.0)
			show_segment(n))
		_seg_row.add_child(b)
		if segments[i].size() > 2 and bool(segments[i][2]):
			var dot := PanelContainer.new()
			dot.theme_type_variation = &"Badge"
			dot.custom_minimum_size = Vector2(20, 20)
			dot.position = Vector2(10, 8)
			dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.add_child(dot)


func close() -> void:
	# A tab page stays until another tab replaces it.
	if page or not is_inside_tree():
		return
	Sfx.play("ui_back", -6.0)
	var t := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	t.tween_property(panel, "position:y", panel.position.y + panel.size.y, 0.22)
	t.tween_property(self, "modulate:a", 0.0, 0.22)
	t.chain().tween_callback(func():
		closed.emit()
		queue_free())


func _call_builder() -> void:
	Ui.clear(footer)
	builder.call(self)
	footer.visible = footer.get_child_count() > 0
