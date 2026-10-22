class_name XpRing
extends Control
## The run's XP as a ring around the hero portrait.

var value := 0.0: set = _set_value


func _set_value(v: float) -> void:
	v = clampf(v, 0.0, 1.0)
	if not is_equal_approx(v, value):
		value = v
		queue_redraw()


func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.5 - 4.0
	draw_arc(c, r, 0.0, TAU, 64, Color(0, 0, 0, 0.55), 7.0, true)
	if value > 0.0:
		draw_arc(c, r, -PI * 0.5, -PI * 0.5 + TAU * value, 64, Color(0.55, 0.85, 1.0), 7.0, true)
