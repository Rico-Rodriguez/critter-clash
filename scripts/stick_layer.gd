class_name StickLayer
extends Control

## The thumbstick: the base that sits under the thumb and the knob that
## slides inside it. The hunt and the town both drive the hero with this,
## so it lives in a file of its own.

# Viewport units on the 720-wide playfield. Full speed is a short push;
# past the rim the base slides with the thumb so a reverse is instant.
const RADIUS := 46.0
const DEAD := 3.0
const FULL := 16.0
var active := false
var origin := Vector2.ZERO
var knob := Vector2.ZERO
var vec := Vector2.ZERO
var hint := 1.0
var hint_left := 1.2

func place(at: Vector2) -> void:
	var delta := at - origin
	var dist := delta.length()
	if dist > RADIUS and dist > 0.001:
		origin = at - delta * (RADIUS / dist)
		delta = at - origin
		dist = RADIUS
	knob = origin + delta
	if dist <= DEAD or dist <= 0.001:
		vec = Vector2.ZERO
	else:
		var mag := clampf((dist - DEAD) / (FULL - DEAD), 0.0, 1.0)
		vec = delta * (mag / dist)
	queue_redraw()

func _draw() -> void:
	if size.y < 10.0:
		return
	if active:
		# Batched: base and knob are cached meshes moved to the thumb, the
		# push glow one draw (was ~75 separate primitive draws).
		var b := _batch.begin(self)
		b.cached("base", _draw_base, origin)
		if vec.length() > 0.05:
			var ang := vec.angle()
			var glow := clampf(vec.length(), 0.0, 1.0)
			for k in 3:
				b.draw_arc(origin, RADIUS + 3.0, ang - 0.55 + k * 0.1, ang + 0.55 - k * 0.1, 16, Color(1.0, 0.62, 0.22, 0.22 * glow * (k + 1)), 8.0 - k * 2.0, true)
			b.flush()
		b.cached("knob", _draw_knob, knob)
	elif hint > 0.04:
		UiKit.ensure()
		var text := "Drag to steer"
		var width := 220.0
		draw_string(UiKit.font_x, Vector2(size.x * 0.5 - width * 0.5, size.y * 0.78), text, HORIZONTAL_ALIGNMENT_LEFT, width, 28, Color(1, 1, 1, 0.85 * hint))


var _batch := CanvasBatch.new()

## Forged base: a smoked-enamel well in a cast-bronze ring lit from the
## top left and eight engraved ticks (the ember glow toward the push is
## drawn live in _draw). Recorded once around the origin.
func _draw_base(b: CanvasBatch) -> void:
	var c := Vector2.ZERO
	var r := RADIUS
	b.draw_circle(c + Vector2(0, 3), r + 9.0, Color(0, 0, 0, 0.35))
	for k in 6:
		var t := float(k) / 5.0
		b.draw_circle(c, r * (1.0 - t * 0.55), Color(0.05, 0.07, 0.09, 0.5).lerp(Color(0.12, 0.17, 0.2, 0.62), t))
	for k in 40:
		var a0 := TAU * k / 40.0
		var lit := 0.5 + 0.5 * cos(a0 + 2.36)
		var col := Color(0.38, 0.24, 0.1).lerp(Color(0.9, 0.66, 0.34), lit)
		b.draw_arc(c, r + 3.0, a0, a0 + TAU / 40.0 + 0.01, 3, col, 6.0, true)
	b.draw_arc(c, r + 6.5, 0.0, TAU, 48, Color(0.16, 0.09, 0.04, 0.9), 1.5, true)
	b.draw_arc(c, r - 0.5, 0.0, TAU, 48, Color(1.0, 0.88, 0.6, 0.55), 1.0, true)
	for k in 8:
		var d := Vector2.RIGHT.rotated(TAU * k / 8.0)
		b.draw_line(c + d * (r - 9.0), c + d * (r - 3.0), Color(0.85, 0.7, 0.45, 0.55), 1.5, true)

## Knob: a bronze dome with an enamel inset and a hard specular glint.
func _draw_knob(b: CanvasBatch) -> void:
	var k := Vector2.ZERO
	var r := 21.0
	b.draw_circle(k + Vector2(1.5, 4.0), r + 1.0, Color(0, 0, 0, 0.4))
	b.draw_circle(k, r + 1.5, Color(0.2, 0.11, 0.04))
	for i in 7:
		var t := float(i) / 6.0
		b.draw_circle(k - Vector2(3, 4) * t, r * (1.0 - t * 0.7), Color(0.5, 0.31, 0.13).lerp(Color(0.98, 0.78, 0.46), t))
	b.draw_circle(k, r * 0.5, Color(0.25, 0.08, 0.06))
	b.draw_circle(k, r * 0.42, Color(0.6, 0.12, 0.08))
	b.draw_circle(k - Vector2(2, 2.5), r * 0.22, Color(0.95, 0.4, 0.25))
	b.draw_circle(k - Vector2(7, 8), 3.0, Color(1, 0.97, 0.88, 0.9))

