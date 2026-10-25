class_name RadialButton
extends Control
## Round action button for the hunt (dash, super). Handles raw touches so it
## can be pressed while another finger holds the stick. `fill` 0..1 draws the
## charge or cooldown ring; `ready` makes it glow.

signal pressed

@export var icon_name := "sprint"
@export var ring_color := Color(0.91, 0.71, 0.35)
@export var glow_color := Color(1.0, 0.55, 0.2)
@export var caption := ""

var fill := 1.0
var is_ready := true
var cooldown_mode := false
## Super lockout: seconds left (0 = none) out of `lock_max`, drawn as a
## draining grey ring and a countdown instead of the charge ring.
var lock_left := 0.0
var lock_max := 1.0
var _icon: Texture2D
var _press := 0.0
var _pulse := 0.0
var _finger := -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon = Ui.icon(icon_name)


func _input(e: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if e is InputEventScreenTouch:
		var t := e as InputEventScreenTouch
		var r := size.x * 0.5
		var c := get_global_rect().get_center()
		if t.pressed and t.position.distance_to(c) <= r + 16.0:
			_finger = t.index
			_press = 1.0
			pressed.emit()
			get_viewport().set_input_as_handled()
			queue_redraw()
		elif not t.pressed and t.index == _finger:
			_finger = -1


func _process(dt: float) -> void:
	_press = maxf(_press - dt * 6.0, 0.0)
	_pulse += dt
	queue_redraw()


func _draw() -> void:
	var r := size.x * 0.5
	var c := size * 0.5
	var s := 1.0 - _press * 0.08
	var rr := r * s
	if is_ready and not cooldown_mode:
		var g := 0.5 + 0.5 * sin(_pulse * 5.0)
		draw_circle(c, rr + 10 + g * 6.0, Color(glow_color, 0.18 + 0.12 * g))
	draw_circle(c, rr, Color(0.05, 0.045, 0.06, 0.82))
	if not is_ready:
		draw_circle(c, rr - 3, Color(0, 0, 0, 0.35))
	# Ring: charge (super) or recovery (dash).
	var col := glow_color if is_ready else ring_color
	draw_arc(c, rr - 4, 0, TAU, 64, Color(1, 1, 1, 0.08), 6.0, true)
	if lock_left > 0.0:
		var k := clampf(lock_left / maxf(lock_max, 0.01), 0.0, 1.0)
		draw_arc(c, rr - 4, -PI * 0.5, -PI * 0.5 + TAU * k, 64, Color(0.62, 0.62, 0.66, 0.9), 6.0, true)
		if _icon:
			var lsz := rr * 0.8
			draw_texture_rect(_icon, Rect2(c - Vector2(lsz, lsz) * 0.5, Vector2(lsz, lsz)), false, Color(1, 1, 1, 0.18))
		var lf := get_theme_default_font()
		var txt := str(ceili(lock_left))
		var lfs := int(rr * 0.75)
		var tw := lf.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, lfs)
		var tp := Vector2(c.x - tw.x * 0.5, c.y + lfs * 0.35)
		draw_string_outline(lf, tp, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, lfs, 6, Color(0, 0, 0, 0.9))
		draw_string(lf, tp, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, lfs, Color(0.9, 0.9, 0.92))
		return
	if fill > 0.001:
		draw_arc(c, rr - 4, -PI * 0.5, -PI * 0.5 + TAU * clampf(fill, 0.0, 1.0), 64, col, 6.0 if not is_ready else 7.0, true)
	if _icon:
		var isz := rr * 1.05
		var tint := Color(1, 1, 1, 1.0 if is_ready else 0.45)
		if is_ready and not cooldown_mode:
			tint = Color(1.0, 0.92, 0.75)
		draw_texture_rect(_icon, Rect2(c - Vector2(isz, isz) * 0.5, Vector2(isz, isz)), false, tint)
	if caption != "" and is_ready and not cooldown_mode:
		var f := get_theme_default_font()
		var fs := 18
		var w := f.get_string_size(caption, HORIZONTAL_ALIGNMENT_CENTER, -1, fs).x
		draw_string_outline(f, Vector2(c.x - w * 0.5, size.y + 22), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 6, Color(0, 0, 0, 0.9))
		draw_string(f, Vector2(c.x - w * 0.5, size.y + 22), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1.0, 0.85, 0.55))
