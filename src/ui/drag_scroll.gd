extends ScrollContainer
## Not a class_name: an over-the-air pack cannot register new global classes
## (the baked IPA's class list is fixed), so users preload it by path.
## A vertical list that scrolls when you drag anywhere on it, rows included,
## the way phone lists do. Godot's own touch scrolling only sees drags that
## reach the container, and every Button or PanelContainer in a row stops
## them, so the rows are set to pass input up and the drag is handled here.
## A drag cancels the press it began on, so scrolling never taps a row.

## Dragging down while already at the top: the distance pulled (px), for a
## sheet to follow the finger. `pull_released` has the finger's speed (px/s).
signal pulled(dy: float)
signal pull_released(dy: float, speed: float)

## How far a press may wander before it becomes a drag.
const SLOP := 12.0
const FRICTION := 3.5

var _down := false
var _dragging := false
var _from := Vector2.ZERO
var _last_y := 0.0
var _last_t := 0
var _speed := 0.0
var _fling := 0.0
var _pull := 0.0
## scroll_vertical is whole pixels; keep the fraction so slow drags still move.
var _pos := 0.0


func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)
	Ui.pass_drags(self, self)
	set_process(false)


func _on_node_added(n: Node) -> void:
	if is_ancestor_of(n):
		# Deferred: builders often set mouse_filter after add_child.
		Ui.pass_drags.call_deferred(n, self)


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			_down = true
			_dragging = false
			_from = e.global_position
			_last_y = _from.y
			_last_t = Time.get_ticks_usec()
			_speed = 0.0
			_fling = 0.0
			_pos = scroll_vertical
			accept_event()
		elif _down:
			_down = false
			if _dragging:
				_dragging = false
				# A finger that stopped before lifting should not fling.
				if Time.get_ticks_usec() - _last_t > 80000:
					_speed = 0.0
				if _pull > 0.0:
					pull_released.emit(_pull, _speed)
					_pull = 0.0
				else:
					_fling = -_speed
					set_process(absf(_fling) > 30.0)
				accept_event()
	elif e is InputEventMouseMotion and _down:
		var p: Vector2 = e.global_position
		if not _dragging:
			var d := p - _from
			if d.length() < SLOP:
				return
			if absf(d.y) < absf(d.x):
				# Sideways: leave it to whatever is under the finger.
				_down = false
				return
			_dragging = true
			Ui.cancel_press(self, _from)
			_last_y = p.y
		var now := Time.get_ticks_usec()
		var dt := maxf((now - _last_t) / 1000000.0, 0.001)
		var dy := p.y - _last_y
		_speed = lerpf(_speed, dy / dt, 0.6)
		_last_y = p.y
		_last_t = now
		_move(dy)
		accept_event()


func _move(dy: float) -> void:
	var wants_pull := pulled.get_connections().size() > 0
	if wants_pull and (_pull > 0.0 or (_pos <= 0.0 and dy > 0.0)):
		_pull = maxf(_pull + dy, 0.0)
		pulled.emit(_pull)
		return
	_scroll_to(_pos - dy)


func _scroll_to(y: float) -> void:
	var bar := get_v_scroll_bar()
	_pos = clampf(y, 0.0, maxf(bar.max_value - bar.page, 0.0))
	scroll_vertical = roundi(_pos)


func _process(dt: float) -> void:
	# Something else moved the list (a filter, a rebuild): stop coasting.
	if _down or scroll_vertical != roundi(_pos):
		_fling = 0.0
	var was := _pos
	_scroll_to(_pos + _fling * dt)
	_fling *= exp(-FRICTION * dt)
	if absf(_fling) < 30.0 or is_equal_approx(was, _pos):
		_fling = 0.0
		set_process(false)
