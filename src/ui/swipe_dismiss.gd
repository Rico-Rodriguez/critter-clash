class_name SwipeDismiss
extends Node
## Drag a panel down and let go to close it, like a phone sheet: it follows
## the finger, closes when pulled far enough or flicked, and springs back
## otherwise. Wire a handle with `attach`, or drive it from another gesture
## (a list pulled past its top) with `drag` and `release`.

## Fraction of the panel's height, or a downward flick (px/s), that closes it.
const FAR := 0.28
const FLICK := 900.0

var panel: Control
var on_close: Callable
## Slide the panel off before calling `on_close` (for closers that don't).
var slide_out := false

var _base_y := 0.0
var _moving := false
var _down := false
var _dragging := false
var _from := Vector2.ZERO
var _last_y := 0.0
var _last_t := 0
var _speed := 0.0
var _handle: Control
var _done := false


## Swipes on `handle` (default: the panel itself) move `panel`.
static func attach(panel_: Control, close: Callable, handle: Control = null, slide := false) -> SwipeDismiss:
	var s := SwipeDismiss.new()
	s.panel = panel_
	s.on_close = close
	s.slide_out = slide
	s._handle = handle if handle else panel_
	panel_.add_child(s)
	return s


func _ready() -> void:
	if _handle:
		_handle.gui_input.connect(_on_handle_input)
		get_tree().node_added.connect(_on_node_added)
		Ui.pass_drags(_handle, _handle)


func _on_node_added(n: Node) -> void:
	if _handle and _handle.is_ancestor_of(n):
		Ui.pass_drags.call_deferred(n, _handle)


func _on_handle_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			_down = true
			_dragging = false
			_from = e.global_position
			_last_y = _from.y
			_last_t = Time.get_ticks_usec()
			_speed = 0.0
		elif _down:
			_down = false
			if _dragging:
				_dragging = false
				if Time.get_ticks_usec() - _last_t > 80000:
					_speed = 0.0
				release(panel.position.y - _base_y, _speed)
				_handle.accept_event()
	elif e is InputEventMouseMotion and _down:
		var p: Vector2 = e.global_position
		if not _dragging:
			var d := p - _from
			if d.length() < DragScroll.SLOP:
				return
			if absf(d.y) < absf(d.x) or d.y < 0.0:
				_down = false
				return
			_dragging = true
			Ui.cancel_press(_handle, _from)
		var now := Time.get_ticks_usec()
		var dt := maxf((now - _last_t) / 1000000.0, 0.001)
		_speed = lerpf(_speed, (p.y - _last_y) / dt, 0.6)
		_last_y = p.y
		_last_t = now
		drag(p.y - _from.y)
		_handle.accept_event()


## Moves the panel `dy` px below where it rests.
func drag(dy: float) -> void:
	if _done:
		return
	if not _moving:
		_moving = true
		_base_y = panel.position.y
	panel.position.y = _base_y + maxf(dy, 0.0)


## Lets go after a drag of `dy` px at `speed` px/s: close, or spring back.
func release(dy: float, speed: float) -> void:
	if _done or not _moving:
		return
	_moving = false
	if dy > panel.size.y * FAR or (speed > FLICK and dy > 20.0):
		_done = true
		if slide_out:
			var t := panel.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
			t.tween_property(panel, "position:y", _base_y + panel.size.y + 40.0, 0.18)
			t.tween_callback(on_close)
		else:
			on_close.call()
		return
	var back := panel.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	back.tween_property(panel, "position:y", _base_y, 0.25)
