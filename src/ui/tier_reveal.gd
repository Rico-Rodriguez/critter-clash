class_name TierReveal
extends Control
## A moment for a milestone: light rays wheel out behind the subject while a
## big word punches in, then everything fades. Used when a hero first wears a
## new tier. The rays live in `behind` (under a 3D stage, so the hero stands
## in front of them); the words sit on top.

var _rays: Rays


func play(title: String, subtitle: String, col: Color, behind: Control, index := 0) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rays = Rays.new()
	_rays.color = col
	_rays.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rays.mouse_filter = Control.MOUSE_FILTER_IGNORE
	behind.add_child(_rays)
	behind.move_child(_rays, index)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", -6)
	add_child(box)
	var t1 := Ui.label(title.to_upper(), "Title", HORIZONTAL_ALIGNMENT_CENTER)
	t1.add_theme_font_size_override("font_size", 64)
	t1.add_theme_color_override("font_color", col.lightened(0.45))
	t1.add_theme_constant_override("outline_size", 14)
	t1.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	box.add_child(t1)
	var t2 := Ui.label(subtitle, "HudLabel", HORIZONTAL_ALIGNMENT_CENTER)
	t2.add_theme_font_size_override("font_size", 24)
	box.add_child(t2)
	var r := behind.get_global_rect()
	box.size = Vector2(get_viewport_rect().size.x, 120)
	box.position = Vector2(0, r.position.y + r.size.y * 0.62)
	box.pivot_offset = Vector2(box.size.x * 0.5, 40)
	box.scale = Vector2.ONE * 2.2
	box.modulate.a = 0.0
	var t := create_tween().set_parallel(true)
	t.tween_property(box, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(box, "modulate:a", 1.0, 0.15)
	t.tween_property(_rays, "reach", 560.0, 0.6).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	t.tween_property(_rays, "alpha", 0.55, 0.25)
	t.chain().tween_interval(1.4)
	t.chain().tween_property(self, "modulate:a", 0.0, 0.5)
	t.parallel().tween_property(_rays, "modulate:a", 0.0, 0.5)
	t.chain().tween_callback(func():
		_rays.queue_free()
		queue_free())


## The wheel of light: soft triangles turning around the middle.
class Rays extends Control:
	const COUNT := 14
	var color := Color.WHITE
	var reach := 0.0
	var alpha := 0.0
	var _rot := 0.0

	func _process(dt: float) -> void:
		_rot += dt * 0.5
		queue_redraw()

	func _draw() -> void:
		if reach <= 0.0:
			return
		var c := size * Vector2(0.5, 0.48)
		var w := PI / COUNT * 0.55
		for i in COUNT:
			var a := _rot + TAU * i / COUNT
			var pts := PackedVector2Array([c, c + Vector2.from_angle(a - w) * reach, c + Vector2.from_angle(a + w) * reach])
			draw_polygon(pts, PackedColorArray([Color(color, alpha), Color(color, 0.0), Color(color, 0.0)]))
		draw_circle(c, 90.0, Color(color.lightened(0.5), alpha * 0.45))
