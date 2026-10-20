class_name MaterialIcon
extends Control

## A material's picture: the baked prop when the drop has one, and a carved
## mark of its skill when it does not (the gathered resources have no art
## yet). Shared by the bag on the Skills screen and the Hub stash, so a
## material looks the same wherever it is shown.

var id := ""
var tex: Texture2D


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var path := MaterialDB.icon_path(id)
	if path != "":
		# Cached: canvas draw commands keep only the RID, so a local
		# texture would be freed after the draw and show as white.
		tex = SpriteBank._load(path, id)
	resized.connect(queue_redraw)


func _draw() -> void:
	var c := size * 0.5
	var r := maxf(minf(size.x, size.y) * 0.5 - 4.0, 0.0)
	if r <= 0.0:
		return
	if tex != null:
		draw_texture_rect(tex, Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0), false)
		return
	# No art yet: a small medallion with the skill's mark cut into it.
	draw_circle(c + Vector2(0, 3), r, Color(0, 0, 0, 0.5))
	draw_circle(c, r, Color("241a12"))
	draw_arc(c, r - 3, 0, TAU, 40, Color("c9a25a"), 3.0, true)
	_mark(c, r * 0.6)


func _mark(c: Vector2, r: float) -> void:
	var ink := Color("e8c070")
	match MaterialDB.skill_of(id):
		"woodcutting":
			# A log: a bark bar with a cut ring at each end.
			var bar := Rect2(c.x - r, c.y - r * 0.32, r * 2.0, r * 0.64)
			draw_rect(bar, Color("8a5a2a"))
			draw_rect(bar, Color("4a2c12"), false, 2.0)
			draw_circle(Vector2(c.x - r * 0.56, c.y), r * 0.24, Color("d8b070"))
			draw_circle(Vector2(c.x + r * 0.56, c.y), r * 0.24, Color("d8b070"))
		"fishing":
			# A fish: a body and a tail.
			var body := PackedVector2Array([
				c + Vector2(-r * 0.75, 0), c + Vector2(-r * 0.15, -r * 0.46),
				c + Vector2(r * 0.5, -r * 0.2), c + Vector2(r * 0.5, r * 0.2),
				c + Vector2(-r * 0.15, r * 0.46)])
			draw_colored_polygon(body, Color("7fb6d6"))
			var outline := body.duplicate()
			outline.append(body[0])
			draw_polyline(outline, ink, 2.0, true)
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(-r * 0.7, 0), c + Vector2(-r * 1.15, -r * 0.42),
				c + Vector2(-r * 1.15, r * 0.42)]), Color("7fb6d6"))
		_:
			# An ore chunk: a faceted lump.
			var chunk := PackedVector2Array([
				c + Vector2(-r * 0.72, r * 0.28), c + Vector2(-r * 0.34, -r * 0.62),
				c + Vector2(r * 0.46, -r * 0.5), c + Vector2(r * 0.78, r * 0.32),
				c + Vector2(0, r * 0.72)])
			draw_colored_polygon(chunk, Color("b08a5e"))
			var edge := chunk.duplicate()
			edge.append(chunk[0])
			draw_polyline(edge, ink, 2.0, true)
