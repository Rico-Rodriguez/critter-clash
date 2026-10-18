class_name CanvasBatch
extends RefCounted

## Records CanvasItem-style draw calls (circles, arcs, lines, polylines,
## rects, flat or vertex-coloured polygons) as coloured triangles and
## submits them as ONE mesh draw. Godot issues a separate draw call per
## polygon, arc or circle command, so a HUD widget drawn from dozens of
## primitives costs dozens of draws; through a batch it costs one.
##
## Usage inside a CanvasItem's _draw():
##     var b := _batch.begin(self)
##     b.draw_circle(...); b.draw_arc(...); ...
##     b.flush()
## Textured polygons and strings flush the pending triangles first and go
## straight to the CanvasItem, so painter's order is kept. `cached()` bakes
## static decoration once and replays it as a single mesh draw.
## Antialiased strokes get a short alpha feather instead of Godot's AA pass.

var feather := 0.9
var _ci: CanvasItem
var _v := PackedVector2Array()
var _c := PackedColorArray()
var _pool: Array[ArrayMesh] = []
var _used := 0
var _cache := {}


func begin(ci: CanvasItem) -> CanvasBatch:
	_ci = ci
	_used = 0
	_v.clear()
	_c.clear()
	return self


## Submits the pending triangles as one draw.
func flush() -> void:
	if _v.is_empty():
		return
	var m: ArrayMesh
	if _used < _pool.size():
		m = _pool[_used]
		m.clear_surfaces()
	else:
		m = ArrayMesh.new()
		_pool.append(m)
	_used += 1
	_ci.draw_mesh(_commit(m), null)


## Draws static decoration from a mesh baked on first use. `build` receives
## this batch and records into it; `key` must change when the shape does.
## `at` offsets the replay (e.g. a joystick base that follows the thumb).
func cached(key: String, build: Callable, at := Vector2.ZERO) -> void:
	flush()
	if not _cache.has(key):
		var keep_v := _v
		var keep_c := _c
		_v = PackedVector2Array()
		_c = PackedColorArray()
		build.call(self)
		_cache[key] = _commit(ArrayMesh.new())
		_v = keep_v
		_c = keep_c
	if at != Vector2.ZERO:
		_ci.draw_set_transform(at)
	_ci.draw_mesh(_cache[key], null)
	if at != Vector2.ZERO:
		_ci.draw_set_transform(Vector2.ZERO)


func clear_cache() -> void:
	_cache.clear()


func _commit(m: ArrayMesh) -> ArrayMesh:
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = _v
	arr[Mesh.ARRAY_COLOR] = _c
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	_v = PackedVector2Array()
	_c = PackedColorArray()
	return m


# --- Primitives ---------------------------------------------------------------

func tri(a: Vector2, b: Vector2, c: Vector2, ca: Color, cb: Color, cc: Color) -> void:
	_v.append(a)
	_v.append(b)
	_v.append(c)
	_c.append(ca)
	_c.append(cb)
	_c.append(cc)


func quad(a: Vector2, b: Vector2, c: Vector2, d: Vector2, ca: Color, cb: Color, cc: Color, cd: Color) -> void:
	tri(a, b, c, ca, cb, cc)
	tri(a, c, d, ca, cc, cd)


static func _segs(radius: float) -> int:
	return clampi(int(radius * 0.9) + 10, 12, 64)


func draw_circle(pos: Vector2, radius: float, color: Color, filled := true, width := -1.0, antialiased := false) -> void:
	if radius <= 0.0:
		return
	if not filled:
		draw_arc(pos, radius, 0.0, TAU, _segs(radius), color, width, antialiased)
		return
	var n := _segs(radius)
	var prev := pos + Vector2(radius, 0.0)
	for i in range(1, n + 1):
		var q := pos + Vector2.RIGHT.rotated(TAU * float(i) / float(n)) * radius
		tri(pos, prev, q, color, color, color)
		prev = q


func draw_arc(center: Vector2, radius: float, a0: float, a1: float, point_count: int, color: Color, width := -1.0, antialiased := false) -> void:
	var n := maxi(point_count, 2)
	var pts := PackedVector2Array()
	for i in n:
		pts.append(center + Vector2.RIGHT.rotated(lerpf(a0, a1, float(i) / float(n - 1))) * radius)
	draw_polyline(pts, color, width, antialiased)


func draw_line(from: Vector2, to: Vector2, color: Color, width := -1.0, antialiased := false) -> void:
	draw_polyline(PackedVector2Array([from, to]), color, width, antialiased)


## Thick strip with mitred joins; a closed loop when the ends meet.
func draw_polyline(points: PackedVector2Array, color: Color, width := -1.0, antialiased := false) -> void:
	var n := points.size()
	if n < 2:
		return
	var w := maxf(width, 1.0) * 0.5
	var closed := points[0].distance_to(points[n - 1]) < 0.01 and n > 2
	var offs := PackedVector2Array()
	offs.resize(n)
	for i in n:
		var d_in := Vector2.ZERO
		var d_out := Vector2.ZERO
		if i > 0:
			d_in = (points[i] - points[i - 1]).normalized()
		elif closed:
			d_in = (points[0] - points[n - 2]).normalized()
		if i < n - 1:
			d_out = (points[i + 1] - points[i]).normalized()
		elif closed:
			d_out = (points[1] - points[0]).normalized()
		if d_in == Vector2.ZERO:
			d_in = d_out
		if d_out == Vector2.ZERO:
			d_out = d_in
		var nrm := Vector2(-d_in.y, d_in.x)
		var tangent := (d_in + d_out)
		if tangent.length_squared() < 1e-6:
			offs[i] = nrm
			continue
		tangent = tangent.normalized()
		var miter := Vector2(-tangent.y, tangent.x)
		offs[i] = miter / maxf(miter.dot(nrm), 0.35)
	var clear := Color(color, 0.0)
	var f := feather if antialiased else 0.0
	for i in n - 1:
		var a := points[i]
		var b := points[i + 1]
		var oa := offs[i]
		var ob := offs[i + 1]
		quad(a + oa * w, b + ob * w, b - ob * w, a - oa * w, color, color, color, color)
		if f > 0.0:
			quad(a + oa * (w + f), b + ob * (w + f), b + ob * w, a + oa * w, clear, clear, color, color)
			quad(a - oa * w, b - ob * w, b - ob * (w + f), a - oa * (w + f), color, color, clear, clear)


func draw_rect(rect: Rect2, color: Color, filled := true, width := -1.0, antialiased := false) -> void:
	if filled:
		var p := rect.position
		var e := rect.end
		quad(p, Vector2(e.x, p.y), e, Vector2(p.x, e.y), color, color, color, color)
		return
	var p2 := rect.position
	var e2 := rect.end
	draw_polyline(PackedVector2Array([p2, Vector2(e2.x, p2.y), e2, Vector2(p2.x, e2.y), p2]), color, width, antialiased)


func draw_colored_polygon(points: PackedVector2Array, color: Color, uvs := PackedVector2Array(), texture: Texture2D = null) -> void:
	if texture != null:
		flush()
		_ci.draw_colored_polygon(points, color, uvs, texture)
		return
	var cols := PackedColorArray()
	cols.resize(points.size())
	cols.fill(color)
	draw_polygon(points, cols)


func draw_polygon(points: PackedVector2Array, colors: PackedColorArray, uvs := PackedVector2Array(), texture: Texture2D = null) -> void:
	if texture != null:
		flush()
		_ci.draw_polygon(points, colors, uvs, texture)
		return
	if points.size() < 3:
		return
	var one := colors.size() == 1
	var idx := Geometry2D.triangulate_polygon(points)
	if idx.is_empty():
		for i in range(1, points.size() - 1):
			idx.append_array([0, i, i + 1])
	for k in range(0, idx.size(), 3):
		var i0 := idx[k]
		var i1 := idx[k + 1]
		var i2 := idx[k + 2]
		tri(points[i0], points[i1], points[i2], colors[0 if one else i0], colors[0 if one else i1], colors[0 if one else i2])


func draw_string(font: Font, pos: Vector2, text: String, alignment := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0, font_size := 16, modulate := Color.WHITE) -> void:
	flush()
	_ci.draw_string(font, pos, text, alignment, width, font_size, modulate)


## UiKit.ch_fill (chamfered rect, vertical gradient) as batched triangles.
func ch_fill(rect: Rect2, cut: float, top: Color, bottom: Color) -> void:
	var c := minf(cut, minf(rect.size.x, rect.size.y) * 0.5)
	var p := rect.position
	var e := rect.end
	var pts := PackedVector2Array([Vector2(p.x + c, p.y), Vector2(e.x - c, p.y), Vector2(e.x, p.y + c), Vector2(e.x, e.y - c), Vector2(e.x - c, e.y), Vector2(p.x + c, e.y), Vector2(p.x, e.y - c), Vector2(p.x, p.y + c)])
	var cols := PackedColorArray()
	for q in pts:
		cols.append(top.lerp(bottom, (q.y - p.y) / maxf(rect.size.y, 1.0)))
	# Convex octagon: a fan from the centre is exact and skips triangulation.
	var mid := rect.get_center()
	var mc := top.lerp(bottom, 0.5)
	for i in 8:
		tri(mid, pts[i], pts[(i + 1) % 8], mc, cols[i], cols[(i + 1) % 8])
