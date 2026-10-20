class_name Minimap
extends Control

## Zone minimap for the corner HUD.
##
## A zone is a column of depth tiers: the safe hub at the south, the four
## wilderness tiers climbing north to the boss lair (WorldData.TIERS). This
## panel draws that column as a small chart that rides with the hero: the
## hero's white dot sits in the middle of the panel, the band of the tier
## the hero is in is lit, and the gates, lairs, elites and gathering nodes
## the game feeds in are pinned on top of it.
##
## Game code drives it with three calls:
##   set_player(pos)              the hero's world position
##   set_tier(tier_id)            the depth tier the hero is in
##   add_marker(kind, pos, tier)  a gate, lair, elite or gathering node
##
## This is the zone chart, not the run screen's fog-of-war map (the MiniMap
## class inside run_screen.gd).

# --- marker kinds -----------------------------------------------------------

const KIND_GATE := "gate"
const KIND_LAIR := "lair"
const KIND_ELITE := "elite"
const KIND_NODE := "node"

# --- palette ----------------------------------------------------------------

const COL_PLAYER := Color("f7f4ee")
const COL_GATE := Color("45d6e6")
const COL_LAIR := Color("ef4b4b")
const COL_ELITE := Color("e2bb6a")
const COL_NODE := Color("5dce45")
const COL_HUB := Color("e8d6a4")
const COL_EDGE := Color("120c08")
## One colour per depth tier, shallow to deep.
const TIER_COLORS := {
	"fringe": Color("86c46b"),
	"wilds": Color("c8a86a"),
	"deep": Color("4f9ad8"),
	"abyss": Color("a463d6"),
}
const TIER_FALLBACK := [Color("86c46b"), Color("c8a86a"), Color("4f9ad8"), Color("a463d6")]

# --- layout -----------------------------------------------------------------

const DEFAULT_SIZE := Vector2(176, 232)
## Frame margin, in UI px.
const FRAME_PAD := 7.0
## Room under the map for the tier name.
const FOOTER := 18.0

# --- state ------------------------------------------------------------------

## The zone's world bounds. The panel shows a window of it, centred on the
## hero. Defaults to the biome world from WorldData.
var world_rect := Rect2()
## How much of the world (world px) the panel shows from top to bottom.
var view_span := 3200.0
## Write the name under each pin.
var show_labels := false

var player_pos := Vector2.ZERO
var has_player := false
var current_tier := ""
var markers: Array[Dictionary] = []

var _frame: StyleBoxFlat


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = DEFAULT_SIZE
	if world_rect.size == Vector2.ZERO:
		set_world_rect(Rect2(Vector2.ZERO, _zone_size()))
	_frame = StyleBoxFlat.new()
	_frame.bg_color = Color(0.07, 0.05, 0.03, 0.88)
	_frame.set_corner_radius_all(10)
	_frame.set_border_width_all(2)
	_frame.border_color = Color("8a6a3a")
	_frame.shadow_color = Color(0, 0, 0, 0.45)
	_frame.shadow_size = 8
	_frame.shadow_offset = Vector2(0, 3)
	UiKit.ensure()
	resized.connect(queue_redraw)
	queue_redraw()


## The biome world's size, the default zone the panel charts.
func _zone_size() -> Vector2:
	var dims := WorldData.world_dimensions()
	var total: Vector2 = dims.get("total_size", Vector2(4480, 8960))
	return total


# --- feeding the panel ------------------------------------------------------

## The zone's world bounds. The panel shows a window of this, centred on the
## hero.
func set_world_rect(rect: Rect2) -> void:
	world_rect = rect
	queue_redraw()


## How much of the world the panel shows, top to bottom, in world px.
func set_view_span(px: float) -> void:
	view_span = maxf(200.0, px)
	queue_redraw()


## The hero's world position. The dot stays in the middle of the panel and
## the zone scrolls under it.
func set_player(pos: Vector2) -> void:
	player_pos = pos
	has_player = true
	queue_redraw()


## The depth tier the hero is in ("fringe", "wilds", "deep", "abyss"): its
## band lights up and its name is written under the map.
func set_tier(tier_id: String) -> void:
	var id := str(tier_id)
	if id == str(current_tier):
		return
	current_tier = id
	queue_redraw()


## Adds a marker: a hub gate, a boss lair, an elite pack or a gathering
## node. `pos` is a world position; `tier` is the depth tier it sits in.
func add_marker(kind: String, pos: Vector2, tier: String = "", label: String = "") -> Dictionary:
	var m := {"kind": str(kind), "pos": pos, "tier": str(tier), "label": str(label)}
	markers.append(m)
	queue_redraw()
	return m


## Adds a gathering node. The node's name and skill come from GatheringDB,
## so the pin knows what it is; the tier is taken from the node's record
## unless the caller names one.
func add_node(node_id: String, pos: Vector2, tier: String = "") -> Dictionary:
	var rec := GatheringDB.depth_node(node_id)
	if rec.is_empty():
		rec = GatheringDB.node(node_id)
	var label := str(rec.get("name", node_id))
	var id := str(tier)
	if id == "":
		id = str(rec.get("tier", ""))
	return add_marker(KIND_NODE, pos, id, label)


func remove_marker(marker: Dictionary) -> void:
	markers.erase(marker)
	queue_redraw()


func clear_markers() -> void:
	markers.clear()
	queue_redraw()


## Parks the panel in a corner of its parent: "top_right", "top_left",
## "bottom_right" or "bottom_left".
func anchor_corner(corner: String = "top_right", margin: float = 16.0) -> void:
	var w := size.x
	var h := size.y
	anchor_left = 1.0 if corner.ends_with("right") else 0.0
	anchor_right = anchor_left
	anchor_top = 1.0 if corner.begins_with("bottom") else 0.0
	anchor_bottom = anchor_top
	offset_left = -w - margin if anchor_left > 0.5 else margin
	offset_right = -margin if anchor_left > 0.5 else w + margin
	offset_top = -h - margin if anchor_top > 0.5 else margin
	offset_bottom = -margin if anchor_top > 0.5 else h + margin


## The colour of a depth tier, by id.
func tier_color(tier_id: String) -> Color:
	if TIER_COLORS.has(tier_id):
		var known: Color = TIER_COLORS[tier_id]
		return known
	for i in WorldData.TIERS.size():
		var t: Dictionary = WorldData.TIERS[i]
		if str(t.get("id", "")) == str(tier_id):
			var fallback: Color = TIER_FALLBACK[i % TIER_FALLBACK.size()]
			return fallback
	return Color("b8a888")


# --- drawing ----------------------------------------------------------------

func _draw() -> void:
	if _frame != null:
		draw_style_box(_frame, Rect2(Vector2.ZERO, size))
	var area := _map_area()
	if area.size.x < 8.0 or area.size.y < 8.0:
		return
	_draw_bands(area)
	_draw_markers(area)
	_draw_north(area)
	_draw_player(area)
	_draw_footer(area)


## The map area inside the frame, with room left for the footer.
func _map_area() -> Rect2:
	var pad := FRAME_PAD
	return Rect2(
		Vector2(pad, pad),
		Vector2(maxf(size.x - pad * 2.0, 8.0), maxf(size.y - pad * 2.0 - FOOTER, 8.0))
	)


## Pixels per world unit. The map is square-scaled, so the horizontal reach
## follows the panel's shape.
func _scale(area: Rect2) -> float:
	return area.size.y / maxf(view_span, 100.0)


## Where the hero stands when the game has not said yet: the middle of the
## zone.
func _anchor() -> Vector2:
	if has_player:
		return player_pos
	return world_rect.get_center()


func _to_map(world: Vector2, area: Rect2) -> Vector2:
	var k := _scale(area)
	return area.get_center() + (world - _anchor()) * k


func _map_rect(wr: Rect2, area: Rect2) -> Rect2:
	var a := _to_map(wr.position, area)
	var b := _to_map(wr.end, area)
	return Rect2(a, b - a)


## The slice of the world the panel can show right now.
func _visible_world(area: Rect2) -> Rect2:
	var k := _scale(area)
	var half := area.size * 0.5 / maxf(k, 0.0001)
	return Rect2(_anchor() - half, half * 2.0)


## The world row a depth fraction lives in. Depth 0 is the south edge of the
## zone, depth 1 the north.
func _depth_y(v: float) -> float:
	return world_rect.end.y - v * world_rect.size.y


## The band of the world a depth slice covers.
func _band_world(v0: float, v1: float) -> Rect2:
	var top := _depth_y(v1)
	var bottom := _depth_y(v0)
	return Rect2(world_rect.position.x, top, world_rect.size.x, bottom - top)


## The depth tiers, shallowest first, as panels: the hub takes the south
## slice and the tiers share the rest of the column.
func _draw_bands(area: Rect2) -> void:
	var tiers := WorldData.TIERS
	var n := tiers.size()
	if n <= 0:
		return
	var slice := 1.0 / float(n + 1)
	_band(area, 0.0, slice, COL_HUB, str(current_tier) == "")
	for i in n:
		var t: Dictionary = tiers[i]
		var id := str(t.get("id", ""))
		_band(area, slice * float(i + 1), slice * float(i + 2), tier_color(id), id == str(current_tier))


func _band(area: Rect2, v0: float, v1: float, col: Color, lit: bool) -> void:
	var clip := _band_world(v0, v1).intersection(_visible_world(area))
	if clip.size.x <= 0.0 or clip.size.y <= 0.0:
		return
	var mr := _map_rect(clip, area)
	if mr.size.x <= 0.0 or mr.size.y <= 0.0:
		return
	draw_rect(mr, Color(col.r, col.g, col.b, 0.18 if lit else 0.07), true)
	draw_rect(mr, Color(col.r, col.g, col.b, 0.95 if lit else 0.45), false, 2.0 if lit else 1.0)


func _draw_markers(area: Rect2) -> void:
	var reach := area.grow(8.0)
	for m in markers:
		var wpos: Vector2 = m.get("pos", Vector2.ZERO)
		var p := _to_map(wpos, area)
		if not reach.has_point(p):
			continue
		match str(m.get("kind", "")):
			KIND_GATE:
				_draw_gate(p)
			KIND_LAIR:
				_draw_lair(p)
			KIND_ELITE:
				_draw_elite(p)
			_:
				_draw_node(p)
		if show_labels:
			var label := str(m.get("label", ""))
			if label != "":
				var font := UiKit.font_m
				if font != null:
					UiKit.draw_text(self, font, p + Vector2(7.0, 4.0), label, 10, UiKit.CREAM, COL_EDGE, 2, -1)


## A hub gate: a hollow cyan diamond.
func _draw_gate(p: Vector2) -> void:
	var pts := _diamond(p, 6.0)
	draw_colored_polygon(pts, Color(COL_GATE.r, COL_GATE.g, COL_GATE.b, 0.20))
	draw_polyline(_closed(pts), Color(0, 0, 0, 0.7), 3.6, true)
	draw_polyline(_closed(pts), COL_GATE, 1.8, true)


## The boss lair: a red disc with a dark cross.
func _draw_lair(p: Vector2) -> void:
	draw_circle(p, 7.5, Color(0, 0, 0, 0.55))
	draw_circle(p, 5.8, COL_LAIR)
	draw_line(p + Vector2(-2.8, -2.8), p + Vector2(2.8, 2.8), Color(0.12, 0.03, 0.03, 0.9), 1.8, true)
	draw_line(p + Vector2(2.8, -2.8), p + Vector2(-2.8, 2.8), Color(0.12, 0.03, 0.03, 0.9), 1.8, true)


## An elite pack: a gold triangle.
func _draw_elite(p: Vector2) -> void:
	var r := 5.4
	draw_colored_polygon(_triangle(p, r * 1.35), Color(0, 0, 0, 0.6))
	draw_colored_polygon(_triangle(p, r), COL_ELITE)


## A gathering node: a small green dot.
func _draw_node(p: Vector2) -> void:
	draw_circle(p, 4.0, Color(0, 0, 0, 0.5))
	draw_circle(p, 2.6, COL_NODE)


## The hero: a white dot in the middle of the panel.
func _draw_player(area: Rect2) -> void:
	if not has_player:
		return
	var p := _to_map(player_pos, area)
	draw_circle(p, 9.0, Color(1, 1, 1, 0.12))
	draw_circle(p, 6.0, Color(0, 0, 0, 0.6))
	draw_circle(p, 4.2, COL_PLAYER)


## A pip at the top of the map: north is up.
func _draw_north(area: Rect2) -> void:
	var p := area.position + Vector2(area.size.x * 0.5, 7.0)
	draw_colored_polygon(
		PackedVector2Array([p + Vector2(0, -5.0), p + Vector2(4.0, 2.0), p + Vector2(-4.0, 2.0)]),
		Color(0.92, 0.88, 0.76, 0.55)
	)


## The tier the hero is in, under the map.
func _draw_footer(_area: Rect2) -> void:
	if str(current_tier) == "":
		return
	var font := UiKit.font_m
	if font == null:
		return
	var col := tier_color(str(current_tier))
	var base := Vector2(FRAME_PAD + 4.0, size.y - 5.0)
	draw_rect(Rect2(base - Vector2(4.0, 10.0), Vector2(6.0, 12.0)), col, true)
	UiKit.draw_text(self, font, base + Vector2(8.0, 0.0), WorldData.tier_name(str(current_tier)), 12, col, COL_EDGE, 2, -1)


# --- shapes -----------------------------------------------------------------

func _diamond(p: Vector2, r: float) -> PackedVector2Array:
	return PackedVector2Array([
		p + Vector2(0, -r),
		p + Vector2(r, 0),
		p + Vector2(0, r),
		p + Vector2(-r, 0),
	])


func _triangle(p: Vector2, r: float) -> PackedVector2Array:
	return PackedVector2Array([
		p + Vector2(0, -r),
		p + Vector2(r * 0.92, r * 0.8),
		p + Vector2(-r * 0.92, r * 0.8),
	])


func _closed(pts: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array(pts)
	if out.size() > 0:
		out.append(out[0])
	return out
