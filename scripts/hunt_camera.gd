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


func setup(map: HuntMap, hero: Vector2) -> void:
	view = HuntMap.VIEW
	map_size = map.size
	center = _clamp_center(hero)


func follow(hero: Vector2, dt: float) -> void:
	var delta := hero - center
	var push := Vector2(_past(delta.x, deadzone.x), _past(delta.y, deadzone.y))
	var target := center + push
	var blend := 1.0 - exp(-softness * maxf(dt, 0.0))
	center = center.lerp(target, blend)
	center = _clamp_center(center)


func top_left() -> Vector2:
	return center - view * 0.5


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
