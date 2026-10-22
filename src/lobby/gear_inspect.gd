class_name GearInspect
extends Control
## One piece of gear on its own, big and slowly turning (drag to turn it): a
## weapon or offhand floats alone with its sparks; a worn piece is shown on
## the hero, wearing nothing else, with the camera on that part of the body.
## Swipe down on it to put it away.

const DragScroll := preload("res://src/ui/drag_scroll.gd")
const SwipeDismiss := preload("res://src/ui/swipe_dismiss.gd")

var _pivot: Node3D
var _yaw := 0.6
var _spin := 0.7
var _dragging := false
var _swipe: SwipeDismiss
## How a drag on the stage is being read: "" undecided, "turn" or "close".
var _axis := ""
var _from := Vector2.ZERO
var _last := Vector2.ZERO
var _last_t := 0
var _speed := 0.0


func open(it: Dictionary) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_swipe = SwipeDismiss.attach(self, _close, null, false)
	var col := DB.gear_color(it)
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.028, 0.04)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var glow := TextureRect.new()
	var gt := GradientTexture2D.new()
	var g := Gradient.new()
	g.set_color(0, Color(GearDB.accent(it), 0.32))
	g.set_color(1, Color(0, 0, 0, 0))
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(0.5, 0.0)
	glow.texture = gt
	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	glow.offset_bottom = -440
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(glow)
	var safe := MarginContainer.new()
	safe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	safe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Ui.apply_safe_area(safe, 20)
	add_child(safe)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	safe.add_child(v)
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(spacer)
	var x := Button.new()
	x.theme_type_variation = "RoundButton"
	x.text = "✕"
	x.custom_minimum_size = Vector2(64, 64)
	x.focus_mode = Control.FOCUS_NONE
	x.add_theme_font_size_override("font_size", 32)
	x.pressed.connect(_close)
	top.add_child(x)
	v.add_child(top)
	var svc := SubViewportContainer.new()
	svc.stretch = true
	svc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	svc.mouse_filter = Control.MOUSE_FILTER_STOP
	svc.gui_input.connect(_input_stage)
	v.add_child(svc)
	var vp := SubViewport.new()
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_2X
	svc.add_child(vp)
	GearStage.light(vp, false)
	_pivot = Node3D.new()
	vp.add_child(_pivot)
	var cam := Camera3D.new()
	cam.fov = 30.0
	vp.add_child(cam)
	GearStage.show_piece(_pivot, cam, it)
	# Words under the piece: what it is, then what it does.
	var nm := Ui.label(str(it["name"]), "Title", HORIZONTAL_ALIGNMENT_CENTER)
	nm.add_theme_font_size_override("font_size", 36)
	nm.add_theme_color_override("font_color", col.lightened(0.25))
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(nm)
	var sub := Ui.label(Game.item_tag(it, false), "Body", HORIZONTAL_ALIGNMENT_CENTER)
	sub.add_theme_color_override("font_color", Color(0.72, 0.68, 0.62))
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(sub)
	for line in Game.describe_stats(it):
		var l := Ui.label(line, "Body", HORIZONTAL_ALIGNMENT_CENTER)
		l.add_theme_font_size_override("font_size", 21)
		l.add_theme_color_override("font_color", Color(1.0, 0.65, 0.3) if line.begins_with("Start") else (Color(0.45, 1.0, 0.6) if line.begins_with("Set") else Color(0.6, 0.78, 1.0)))
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(l)
	var hint := Ui.label("Drag to turn", "Caption", HORIZONTAL_ALIGNMENT_CENTER)
	hint.modulate.a = 0.5
	v.add_child(hint)
	Sfx.play("sparkle", -8.0)
	modulate.a = 0.0
	_pivot.scale = Vector3.ONE * 0.6
	var t := create_tween().set_parallel(true).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	t.tween_property(self, "modulate:a", 1.0, 0.2)
	t.tween_property(_pivot, "scale", Vector3.ONE, 0.45)


func _process(dt: float) -> void:
	if _pivot == null:
		return
	if not _dragging:
		_yaw += _spin * dt
		_spin = lerpf(_spin, 0.7, 1.0 - exp(-1.5 * dt))
	_pivot.rotation.y = _yaw


func _input_stage(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		_dragging = e.pressed
		if e.pressed:
			_axis = ""
			_from = e.global_position
			_last = _from
			_last_t = Time.get_ticks_usec()
			_speed = 0.0
		elif _axis == "close":
			if Time.get_ticks_usec() - _last_t > 80000:
				_speed = 0.0
			_swipe.release(_last.y - _from.y, _speed)
	elif e is InputEventMouseMotion and _dragging:
		var p: Vector2 = e.global_position
		if _axis == "":
			var d := p - _from
			if d.length() < DragScroll.SLOP:
				return
			_axis = "close" if d.y > absf(d.x) else "turn"
		if _axis == "close":
			var now := Time.get_ticks_usec()
			_speed = lerpf(_speed, (p.y - _last.y) / maxf((now - _last_t) / 1000000.0, 0.001), 0.6)
			_last = p
			_last_t = now
			_swipe.drag(p.y - _from.y)
		else:
			_yaw += e.relative.x * 0.011
			_spin = e.relative.x * 0.4
	elif e is InputEventScreenDrag and _axis == "turn":
		_yaw += e.relative.x * 0.011
		_spin = e.relative.x * 0.4


func _close() -> void:
	Sfx.play("ui_back", -4.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.15)
	t.tween_callback(queue_free)
