class_name ScreenBase
extends Control

signal travel(screen: String, args: Dictionary)

var paint_bg := true
var show_nav := false
var nav_tab := ""
## Menu screens share the calm home theme; the hunt sets its own.
var music_track := "home"


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 0
	offset_top = 0
	offset_right = 0
	offset_bottom = 0
	mouse_filter = Control.MOUSE_FILTER_STOP
	modulate.a = 0.0
	if paint_bg:
		add_child(UiKit.Backdrop.new())
	build()
	if music_track != "":
		AudioDirector.music(music_track)
	_touch_scroll(self)
	if show_nav:
		_dock = UiKit.Dock.new(nav_tab, _nav)
		add_child(_dock)
	if paint_bg:
		scale = Vector2(0.96, 0.96)
		call_deferred("_intro")
	else:
		var tw := create_tween()
		tw.tween_property(self, "modulate:a", 1.0, 0.12)


## Touch drags only reach a ScrollContainer when the controls under the
## finger pass the event up, so everything inside a scroll list (cards,
## frames, buttons) is set to PASS; buttons still take taps, and the list
## follows the finger. Content added later is caught as it enters.
func _touch_scroll(node: Node) -> void:
	for child in node.get_children():
		if child is ScrollContainer:
			var sc := child as ScrollContainer
			sc.scroll_deadzone = 14
			_pass_all(sc)
			sc.child_entered_tree.connect(func(_n: Node) -> void: _pass_all.call_deferred(sc))
		else:
			_touch_scroll(child)


func _pass_all(node: Node) -> void:
	for child in node.get_children():
		if child is ScrollBar:
			continue
		if child is Control and (child as Control).mouse_filter == Control.MOUSE_FILTER_STOP:
			(child as Control).mouse_filter = Control.MOUSE_FILTER_PASS
		_pass_all(child)


## The same pass-through for a scroll list whose content was filled in after
## the screen was ready (a tab switch, say): the fresh rows would otherwise
## swallow the drag and the list could not be scrolled by touch.
func pass_through(scroll: ScrollContainer) -> void:
	if scroll == null:
		return
	scroll.scroll_deadzone = 14
	_pass_all(scroll)


## Direction the next screen slides in from: -1 left, 1 right, 0 zoom.
static var slide_from := 0
var _dock: Control


func _intro() -> void:
	pivot_offset = size * 0.5
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "modulate:a", 1.0, 0.18)
	if slide_from != 0:
		scale = Vector2.ONE
		position.x = 90.0 * slide_from
		tw.tween_property(self, "position:x", 0.0, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		if _dock != null:
			# The nav bar is shared furniture: hold it still while the page
			# slides, so tab switches read as content moving, not the dock.
			_dock.position.x = -90.0 * slide_from
			tw.tween_property(_dock, "position:x", 0.0, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	else:
		tw.tween_property(self, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	slide_from = 0


## Leaves the screen: fades and drifts the other way, then frees it.
func leave(toward: int) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process_input(false)
	set_process_unhandled_input(false)
	# Stay opaque underneath while the incoming screen fades in on top; two
	# half-faded screens over black read as a dark flash between pages.
	var tw := create_tween()
	tw.set_parallel(true)
	if toward != 0:
		tw.tween_property(self, "position:x", -40.0 * toward, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		if _dock != null:
			tw.tween_property(_dock, "position:x", 40.0 * toward, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.chain().tween_interval(0.05)
	tw.chain().tween_callback(queue_free)


const NAV_ORDER := ["heroes", "home", "trophy"]


func _nav(screen: String) -> void:
	if screen == nav_tab:
		return
	var a := NAV_ORDER.find(nav_tab)
	var b := NAV_ORDER.find(screen)
	if a >= 0 and b >= 0:
		slide_from = 1 if b > a else -1
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


func header(compact := false) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var trophies := UiKit.Pill.new("trophy", func() -> void: go("trophy"))
	trophies.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Pills fill the row's height (the 88 px back-chip / cog row), so the
	# plus tap zone is as tall as the bar instead of the pill's 62 px.
	trophies.size_flags_vertical = Control.SIZE_EXPAND_FILL
	trophies.set_amount(str(int(SaveGame.data["trophies"])))
	var coins := UiKit.Pill.new("coin", func() -> void: toast("Win hunts to earn coins."))
	coins.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	coins.size_flags_vertical = Control.SIZE_EXPAND_FILL
	coins.set_amount(str(int(SaveGame.data["coins"])))
	var gems := UiKit.Pill.new("gem", func() -> void: toast("Free game. No shop."))
	gems.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gems.size_flags_vertical = Control.SIZE_EXPAND_FILL
	gems.set_amount("0")
	row.add_child(trophies)
	row.add_child(coins)
	# With the back chip leading the row there is no room for three pills at
	# 720 px; the third pill is the one that goes.
	if compact:
		gems.queue_free()
	else:
		row.add_child(gems)
	# Settings cog at the end of the currency bar: the same 88 px square as
	# the back chip, so the two round controls in the row match.
	var cog := UiKit.tile_button("", "gear", 88, "steel")
	cog.custom_minimum_size = Vector2(88, 88)
	cog.tooltip_text = "Settings"
	cog.pressed.connect(func() -> void: go("settings"))
	row.add_child(cog)
	return row


func h1(text: String) -> Label:
	return UiKit.title(text, 54)


func back_button(target: String, args: Dictionary = {}) -> Button:
	var button := UiKit.secondary("Back", 220, 88)
	button.pressed.connect(func() -> void: go(target, args))
	return button


## Back navigation, shared by every menu that opts in. Setting back_target
## (directly or through header_with_back) turns on the top-left back chip and
## routes Esc / Android back through back(). Screens that leave it empty are
## unchanged: no chip is shown and the key is left alone.
var back_target := ""
var back_args: Dictionary = {}


## The currency header with the shared back chip leading it, so back always
## sits top-left, inside the safe area, with the same size and look.
func header_with_back(target: String, args: Dictionary = {}) -> HBoxContainer:
	back_target = target
	back_args = args
	var row := header(true)
	var chip := BackChip.new()
	chip.pressed.connect(back)
	row.add_child(chip)
	row.move_child(chip, 0)
	return row


## Leave the screen the way a back gesture should. A screen with a dynamic
## destination (a screen opened from two places) overrides this.
func back() -> void:
	if back_target != "":
		go(back_target, back_args)


func _unhandled_input(event: InputEvent) -> void:
	if back_target == "":
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		back()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and back_target != "":
		back()


func portrait(id: String, px: float) -> TextureRect:
	var rect := TextureRect.new()
	rect.custom_minimum_size = Vector2(px, px)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.texture = SpriteBank.critter(id)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


func body(text: String, size: int = 24) -> Label:
	var label := UiKit.label(text, size, Color("efe4cc"), "b", 5)
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


## The shared top-left back control: an 88 px forged round chip with a gilt
## chevron, a real pressed sink and the ui_back sting. Every menu that opts
## into header_with_back carries the same affordance in the same spot.
class BackChip extends Button:
	func _ready() -> void:
		UiKit.ensure()
		custom_minimum_size = Vector2(88, 88)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		focus_mode = Control.FOCUS_NONE
		tooltip_text = "Back"
		var empty := StyleBoxEmpty.new()
		for state in ["normal", "hover", "pressed", "focus", "disabled"]:
			add_theme_stylebox_override(state, empty)
		var skin := UiKit.Frame.new("round", "leather")
		skin.margin = 12.0
		add_child(skin)
		pivot_offset = size * 0.5
		button_down.connect(_press)
		button_up.connect(_release)
		pressed.connect(func() -> void:
			AudioDirector.sfx("ui_back")
			AudioDirector.haptic("light"))

	func _press() -> void:
		pivot_offset = size * 0.5
		var tw := create_tween()
		tw.tween_property(self, "scale", Vector2(0.92, 0.92), 0.05)
		queue_redraw()

	func _release() -> void:
		pivot_offset = size * 0.5
		var tw := create_tween()
		tw.tween_property(self, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		queue_redraw()

	func _draw() -> void:
		var down := is_pressed()
		var sink := 2.0 if down else 0.0
		var cx := size.x * 0.54
		var cy := size.y * 0.5 + sink
		var w := size.x * 0.12
		var h := size.y * 0.16
		var pts := PackedVector2Array([Vector2(cx + w, cy - h), Vector2(cx - w, cy), Vector2(cx + w, cy + h)])
		draw_polyline(pts, Color(0, 0, 0, 0.55), 10.0, true)
		draw_polyline(pts, UiKit.INK, 7.0, true)
		draw_polyline(pts, Color("c8963a") if down else Color("ffe3a0"), 3.5, true)
