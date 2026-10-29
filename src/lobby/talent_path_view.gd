extends Control
## One path of a hero's talent tree, drawn in code: the lines between nodes,
## the gate on each row (points in the path it needs), and the nodes themselves
## (minor = disc, notable = diamond, choice = ringed disc, keystone = hexagon),
## lit by how many ranks they hold. Tapping a node emits `picked`.

signal picked(idx: int)

const ROW_H := 94.0
const GOLD := Color("e8b65a")
const GOLD_RIM := Color("f6dfa6")
const EMBER := Color("d9622b")
const TEAL := Color("3fc6c0")
const DIM_LINE := Color("2f2936")
const LOCK := Color("5a5060")
const SIZE := {"m": 30.0, "n": 30.0, "c": 34.0, "k": 40.0}

var hero_id := ""
var path := 0
var selected := -1
var _press := Vector2.INF


func setup(id: String, p: int, sel: int) -> void:
	hero_id = id
	path = p
	selected = sel
	custom_minimum_size = Vector2(0, ROW_H * 5.0)
	mouse_filter = Control.MOUSE_FILTER_PASS


func _center(idx: int) -> Vector2:
	var s: Array = TalentDB.SLOTS[idx]
	return Vector2((float(s[1]) + 0.5) / 3.0 * size.x, (float(s[0]) + 0.5) * ROW_H)


func _draw() -> void:
	var nodes: Array = TalentDB.paths(hero_id)[path]["nodes"]
	for l in TalentDB.LINKS:
		var lit := Game.has_talent(hero_id, path, l[0]) and Game.has_talent(hero_id, path, l[1])
		draw_line(_center(l[0]), _center(l[1]), GOLD if lit else DIM_LINE, 4.0 if lit else 3.0, true)
	var font := get_theme_font("font", "Caption")
	for r in range(1, 5):
		var on := Game.row_open(hero_id, path, r)
		var txt := str(TalentDB.GATES[r])
		var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x + 18.0
		var pill := Rect2(Vector2(size.x * 0.5 - w * 0.5, r * ROW_H - 12.0), Vector2(w, 24.0))
		draw_style_box(_box(Color("17151c"), Color(GOLD, 0.55) if on else DIM_LINE, 12, 2), pill)
		draw_string(font, pill.position + Vector2(9.0, 18.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, GOLD if on else LOCK)
	var ks := Game.keystone(hero_id)
	for i in nodes.size():
		_draw_node(i, nodes[i], ks)


func _draw_node(i: int, n: Dictionary, ks: String) -> void:
	var c := _center(i)
	var kind: String = n["k"]
	var r: float = SIZE[kind]
	var rank := Game.talent_rank(hero_id, path, i)
	var mx := TalentDB.max_rank(n)
	var open := Game.row_open(hero_id, path, TalentDB.row(i)) and (kind != "k" or ks == "" or ks == TalentDB.key(path, i))
	var fill := Color("15131a")
	var rim := Color("3d3546")
	var ink := Color("6d6474")
	if rank >= mx:
		fill = EMBER if kind == "k" else GOLD
		rim = GOLD_RIM
		ink = Color("24170a")
		_glow(c, r, Color(fill, 0.35))
	elif rank > 0:
		fill = Color("3a2c17")
		rim = GOLD
		ink = GOLD_RIM
	elif open:
		fill = Color("1d1a23")
		rim = Color("8a7a5a")
		ink = Color("f1e8d8")
	if i == selected:
		_outline(kind, c, r + 6.0, TEAL)
	_shape(kind, c, r, rim)
	_shape(kind, c, r - (6.0 if kind == "c" else 3.0), fill)
	if kind == "c":
		_shape(kind, c, r - 9.0, rim)
		_shape(kind, c, r - 11.0, fill)
	var ic := Ui.icon(TalentDB.icon(n, Game.talent_pick(hero_id, path, i)))
	if ic:
		var s := r * 1.05
		draw_texture_rect(ic, Rect2(c - Vector2(s, s) * 0.5, Vector2(s, s)), false, ink)
	if mx > 1:
		var font := get_theme_font("font", "Caption")
		var txt := "%d/%d" % [rank, mx]
		var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 12.0
		var pill := Rect2(Vector2(c.x - w * 0.5, c.y + r - 8.0), Vector2(w, 20.0))
		draw_style_box(_box(Color("0d0c10"), Color("4a3d2a"), 10, 1), pill)
		draw_string(font, pill.position + Vector2(6.0, 15.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, GOLD_RIM if rank > 0 else Color("a39a8a"))


func _points(kind: String, c: Vector2, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	match kind:
		"n":
			for a in 4:
				pts.append(c + Vector2.from_angle(a * PI * 0.5 - PI * 0.5) * r * 1.2)
		"k":
			for a in 6:
				pts.append(c + Vector2.from_angle(a * PI / 3.0 - PI * 0.5) * r * 1.1)
		_:
			for a in 32:
				pts.append(c + Vector2.from_angle(a * TAU / 32.0) * r)
	return pts


func _shape(kind: String, c: Vector2, r: float, col: Color) -> void:
	draw_colored_polygon(_points(kind, c, r), col)


func _outline(kind: String, c: Vector2, r: float, col: Color) -> void:
	var pts := _points(kind, c, r)
	pts.append(pts[0])
	draw_polyline(pts, col, 3.0, true)


func _glow(c: Vector2, r: float, col: Color) -> void:
	for k in 3:
		draw_circle(c, r + 6.0 + k * 5.0, Color(col, col.a * (0.5 - k * 0.15)))


func _box(bg: Color, border: Color, radius: int, width: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(radius)
	s.anti_aliasing = true
	return s


## A tap is a press and release close together (a drag scrolls the sheet).
func _gui_input(e: InputEvent) -> void:
	if not (e is InputEventMouseButton) or e.button_index != MOUSE_BUTTON_LEFT:
		return
	if e.pressed:
		_press = e.position
		return
	if _press == Vector2.INF or e.position.distance_to(_press) > 24.0:
		return
	_press = Vector2.INF
	var nodes: Array = TalentDB.paths(hero_id)[path]["nodes"]
	var best := -1
	var best_d := 60.0
	for i in nodes.size():
		var d := _center(i).distance_to(e.position)
		if d < best_d:
			best = i
			best_d = d
	if best >= 0:
		picked.emit(best)
