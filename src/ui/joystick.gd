class_name Joystick
extends Control
## Floating thumbstick. A touch that starts anywhere in this control (and
## not on a registered button) places the base under the finger; dragging
## steers. Reads raw touches so it works alongside a second finger on the
## action buttons.

const RADIUS := 92.0
const DEAD := 0.12

var finger := -1
var origin := Vector2.ZERO
var knob := Vector2.ZERO
var value := Vector2.ZERO
var blockers: Array[Control] = []
var home := Vector2.ZERO
var home_frac := 0.27
var idle_alpha := 0.3
var _alpha := 0.35


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_place_home)
	_place_home()


func _place_home() -> void:
	home = Vector2(size.x * home_frac, size.y * 0.8)
	if finger < 0:
		origin = home
		knob = home


func _input(e: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if e is InputEventScreenTouch:
		var t := e as InputEventScreenTouch
		var p := _local(t.position)
		if t.pressed and finger < 0 and Rect2(Vector2.ZERO, size).has_point(p) and p.y > size.y * 0.3 and not _on_blocker(t.position):
			finger = t.index
			origin = p
			knob = p
			value = Vector2.ZERO
			queue_redraw()
		elif not t.pressed and t.index == finger:
			finger = -1
			value = Vector2.ZERO
			origin = home
			knob = home
			queue_redraw()
	elif e is InputEventScreenDrag:
		var d := e as InputEventScreenDrag
		if d.index == finger:
			var p2 := _local(d.position)
			var off := p2 - origin
			if off.length() > RADIUS:
				# Drag the base along so the stick never feels "stuck".
				origin = p2 - off.normalized() * RADIUS
				off = p2 - origin
			knob = p2
			var v := off / RADIUS
			value = v if v.length() > DEAD else Vector2.ZERO
			queue_redraw()


func _local(screen_pos: Vector2) -> Vector2:
	return get_global_transform_with_canvas().affine_inverse() * screen_pos


func _on_blocker(screen_pos: Vector2) -> bool:
	for b in blockers:
		if b.is_visible_in_tree() and b.get_global_rect().grow(18).has_point(screen_pos):
			return true
	return false


func release() -> void:
	finger = -1
	value = Vector2.ZERO
	origin = home
	knob = home
	queue_redraw()


func _process(dt: float) -> void:
	var want := 0.85 if finger >= 0 else idle_alpha
	if absf(_alpha - want) > 0.01:
		_alpha = lerpf(_alpha, want, 1.0 - exp(-12.0 * dt))
		queue_redraw()


func _draw() -> void:
	var gold := Color(0.91, 0.71, 0.35)
	draw_circle(origin, RADIUS + 6, Color(0, 0, 0, 0.28 * _alpha))
	draw_arc(origin, RADIUS, 0, TAU, 64, Color(gold, 0.55 * _alpha), 3.0, true)
	draw_arc(origin, RADIUS * 0.55, 0, TAU, 48, Color(1, 1, 1, 0.08 * _alpha), 2.0, true)
	var k := origin + (knob - origin).limit_length(RADIUS)
	draw_circle(k, 40, Color(0.08, 0.07, 0.09, 0.85 * _alpha))
	draw_arc(k, 40, 0, TAU, 48, Color(gold, 0.9 * _alpha), 3.0, true)
	draw_circle(k, 14, Color(gold, 0.5 * _alpha))
