class_name HuntCamera
extends RefCounted

## Follows the hero in world space. The hero can wander inside `deadzone`
## (half extents) before the view eases after them. The view never crosses
## the map edge. When the map is exactly one screen, the clamp pins the
## view and the hunt looks as it does today.

var center := Vector2.ZERO
var view := HuntMap.VIEW
var map_size := HuntMap.VIEW
var deadzone := Vector2(56, 64)
var softness := 8.0

## Boss reveal nudge: a temporary offset eases the view toward a point
## (the rising boss) then eases back, without ever letting the hero leave
## the frame. `_nudge` is applied on top of the follow centre.
const NUDGE_IN := 0.5
const NUDGE_OUT := 0.6
const NUDGE_MAX := 240.0
var _nudge := Vector2.ZERO
var _nudge_goal := Vector2.ZERO
var _nudge_total := 0.0
var _nudge_left := 0.0
var _nudge_on := false


func setup(map: HuntMap, hero: Vector2) -> void:
	view = HuntMap.VIEW
	map_size = map.size
	center = _clamp_center(hero)
	_nudge = Vector2.ZERO
	_nudge_on = false


func follow(hero: Vector2, dt: float) -> void:
	var delta := hero - center
	var push := Vector2(_past(delta.x, deadzone.x), _past(delta.y, deadzone.y))
	var target := center + push
	var blend := 1.0 - exp(-softness * maxf(dt, 0.0))
	center = center.lerp(target, blend)
	center = _clamp_center(center)
	_step_nudge(hero, maxf(dt, 0.0))


## Look toward `target` for `seconds`: ease out, hold, ease back. The offset
## is capped by a margin so the hero always stays well inside the view.
func nudge(target: Vector2, seconds: float) -> void:
	_nudge_goal = target
	_nudge_total = maxf(seconds, NUDGE_IN + NUDGE_OUT)
	_nudge_left = _nudge_total
	_nudge_on = true


func _step_nudge(hero: Vector2, dt: float) -> void:
	var want := Vector2.ZERO
	if _nudge_on:
		_nudge_left = maxf(0.0, _nudge_left - dt)
		var spent := _nudge_total - _nudge_left
		var ease_in := smoothstep(0.0, NUDGE_IN, spent)
		var ease_out := smoothstep(0.0, NUDGE_OUT, _nudge_left)
		var weight := minf(ease_in, ease_out)
		var toward := _nudge_goal - hero
		if toward.length() > 1.0:
			want = toward.normalized() * minf(toward.length(), NUDGE_MAX) * weight
		var room := Vector2(view.x * 0.5 - 150.0, view.y * 0.5 - 200.0)
		want.x = clampf(want.x, -room.x, room.x)
		want.y = clampf(want.y, -room.y, room.y)
		if _nudge_left <= 0.0:
			_nudge_on = false
	_nudge = _nudge.lerp(want, 1.0 - exp(-14.0 * dt))


func top_left() -> Vector2:
	return center + _nudge - view * 0.5


func view_rect() -> Rect2:
	return Rect2(top_left(), view)


func _past(delta: float, limit: float) -> float:
	var excess := absf(delta) - limit
	if excess <= 0.0:
		return 0.0
	return signf(delta) * excess


func _clamp_center(at: Vector2) -> Vector2:
	return Vector2(_clamp_axis(at.x, map_size.x, view.x), _clamp_axis(at.y, map_size.y, view.y))


func _clamp_axis(value: float, length: float, window: float) -> float:
	var half := window * 0.5
	var lo := half
	var hi := length - half
	if hi <= lo:
		return length * 0.5
	return clampf(value, lo, hi)
