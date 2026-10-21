class_name Showcase
extends Control

## The lit 3D plinth with a hero standing on it: the pedestal, the hero
## dressed in what is actually equipped, and a soft fade into the menu
## below it. The Heroes tab frames it with the gear sockets; the camp
## shows the hero by the fire instead.

var hero_id := "ember"
var fill := 0.46
var stage: Stage3D

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage = Stage3D.new()
	stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stage)
	stage.pedestal_fill = fill
	# The pedestal dresses the hero from what is actually equipped
	# (GearDB tiers); no showcase override, so a bare hero reads bare.
	stage.bind_pedestal(hero_id)
	# Soft fade into the menu below, and a dark band under the pills.
	var fade := Fade.new()
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fade)


class Fade extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		# Vertex-colored quads interpolate per pixel, so there are no bands.
		var h := size.y
		var w := size.x
		var bottom := Color(0.075, 0.06, 0.05)
		_grad(Rect2(0, h * 0.6, w, h * 0.4 + 1.0), Color(bottom, 0.0), bottom)
		_grad(Rect2(0, 0, w, h * 0.24), Color(0.02, 0.015, 0.01, 0.7), Color(0.02, 0.015, 0.01, 0.0))
		# Side vignette so the scene sinks into the stone frame.
		var side := Color(0.02, 0.015, 0.01, 0.55)
		var clear := Color(0.02, 0.015, 0.01, 0.0)
		draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w * 0.22, 0), Vector2(w * 0.22, h), Vector2(0, h)]), PackedColorArray([side, clear, clear, side]))
		draw_polygon(PackedVector2Array([Vector2(w * 0.78, 0), Vector2(w, 0), Vector2(w, h), Vector2(w * 0.78, h)]), PackedColorArray([clear, side, side, clear]))

	func _grad(r: Rect2, top: Color, bot: Color) -> void:
		var pts := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
		draw_polygon(pts, PackedColorArray([top, top, bot, bot]))
