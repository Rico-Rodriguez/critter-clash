extends ScreenBase

## Trophy Road: a winding stone road down the screen, gilded up to the
## player's trophy count, with a reward medallion at every milestone and a
## glowing marker where the player stands.

var road: Road


func build() -> void:
	show_nav = true
	nav_tab = "trophy"
	var box := column()
	box.add_child(header_with_back("home"))
	box.add_child(h1("Trophy Road"))
	box.add_child(body("Win hunts to climb. Claim each reward as you pass it."))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	road = Road.new()
	road.claim.connect(_claim)
	road.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(road)
	road.rebuild()


func _claim(id: String) -> void:
	if SaveGame.claim(id):
		go("trophy")


class Road extends Control:
	signal claim(id: String)
	const STEP := 230.0
	const TOP := 120.0
	var points: Array[Vector2] = []
	var t := 0.0
	var trophies := 0
	var _shown := 0.0
	var marker_at := Vector2.ZERO
	var marker: Marker

	func rebuild() -> void:
		for child in get_children():
			child.queue_free()
		trophies = int(SaveGame.data["trophies"])
		var count := Catalog.MILESTONES.size()
		custom_minimum_size = Vector2(0, TOP + count * STEP + 40)
		for i in count:
			var entry: Dictionary = Catalog.MILESTONES[i]
			var node := Milestone.new()
			node.setup(entry, trophies, i % 2 == 0)
			node.claim.connect(func(id: String) -> void: claim.emit(id))
			add_child(node)
		# The player's marker sits above the medallions.
		marker = Marker.new()
		marker.road = self
		marker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(marker)
		resized.connect(_place)
		call_deferred("_place")
		# The gilded fill climbs to the current count when the road opens.
		var tw := create_tween()
		tw.tween_interval(0.3)
		tw.tween_method(func(v: float) -> void:
			_shown = v
			queue_redraw(), 0.0, float(trophies), 1.1).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()

	func _node_point(i: int, w: float) -> Vector2:
		var sway := sin(float(i) * 1.15 + 0.4) * minf(150.0, w * 0.21)
		return Vector2(w * 0.5 + sway, TOP + float(i) * STEP)

	func _place() -> void:
		var w := size.x if size.x > 20.0 else 640.0
		points.clear()
		# Road starts above the first milestone at zero trophies.
		points.append(Vector2(w * 0.5, 20))
		for i in Catalog.MILESTONES.size():
			points.append(_node_point(i, w))
		points.append(_node_point(Catalog.MILESTONES.size(), w) + Vector2(0, -60))
		var n := 0
		for child in get_children():
			if child is Milestone:
				(child as Milestone).anchor_at(points[n + 1], w)
				n += 1
		queue_redraw()

	## Smooth path through the points (Catmull-Rom), sampled densely.
	func _curve() -> PackedVector2Array:
		var out := PackedVector2Array()
		if points.size() < 2:
			return out
		for i in points.size() - 1:
			var p0 := points[maxi(i - 1, 0)]
			var p1 := points[i]
			var p2 := points[i + 1]
			var p3 := points[mini(i + 2, points.size() - 1)]
			for k in 16:
				var s := float(k) / 16.0
				var s2 := s * s
				var s3 := s2 * s
				out.append(0.5 * ((2.0 * p1) + (-p0 + p2) * s + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * s2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * s3))
		out.append(points[points.size() - 1])
		return out

	## Where along the curve (sample index) a trophy count sits.
	func _progress_index(curve: PackedVector2Array, count: float) -> float:
		var marks: Array = [0.0]
		for entry in Catalog.MILESTONES:
			marks.append(float(entry["trophies"]))
		var seg := 0
		while seg < marks.size() - 1 and count >= float(marks[seg + 1]):
			seg += 1
		var frac := 0.0
		if seg < marks.size() - 1:
			frac = (count - float(marks[seg])) / maxf(float(marks[seg + 1]) - float(marks[seg]), 1.0)
		var idx := (float(seg) + frac) * 16.0
		# Keep the pin clear of a medallion it has just passed.
		if seg > 0 and frac > 0.0 and fmod(idx, 16.0) < 5.0:
			idx = floorf(idx / 16.0) * 16.0 + 5.0
		return minf(idx, float(curve.size() - 1))

	func _draw() -> void:
		var curve := _curve()
		if curve.size() < 2:
			return
		# Road bed: shadow, dark edging, worn flagstone, centre wear.
		draw_polyline(_offset(curve, Vector2(0, 8)), Color(0, 0, 0, 0.45), 58.0, true)
		draw_polyline(curve, Color("120c08"), 54.0, true)
		draw_polyline(curve, Color("4a3e34"), 46.0, true)
		draw_polyline(curve, Color("5c4e42"), 34.0, true)
		# Flagstone joints across the road.
		for i in range(4, curve.size() - 2, 4):
			var dir := (curve[i + 1] - curve[i - 1]).normalized()
			var n := dir.orthogonal()
			draw_line(curve[i] - n * 22.0, curve[i] + n * 22.0, Color(0.07, 0.05, 0.04, 0.8), 2.0, true)
		# Gilded progress up to the shown trophy count.
		var idx := _progress_index(curve, _shown)
		var lit := PackedVector2Array()
		for i in int(idx) + 1:
			lit.append(curve[i])
		if int(idx) < curve.size() - 1:
			lit.append(curve[int(idx)].lerp(curve[int(idx) + 1], idx - floorf(idx)))
		if lit.size() >= 2:
			draw_polyline(lit, Color(1.0, 0.7, 0.25, 0.22), 40.0, true)
			draw_polyline(lit, Color("8a5a1a"), 18.0, true)
			draw_polyline(lit, Color("e8c070"), 12.0, true)
			draw_polyline(lit, Color("fff0c0"), 3.0, true)
		if lit.size() > 0:
			marker_at = lit[lit.size() - 1]
		if marker != null:
			marker.queue_redraw()

	func _offset(pts: PackedVector2Array, by: Vector2) -> PackedVector2Array:
		var out := PackedVector2Array()
		for p in pts:
			out.append(p + by)
		return out


## A reward stop on the road: a medallion on the road with the reward
## inside, and a plaque to one side naming it.
class Milestone extends Control:
	signal claim(id: String)
	var entry: Dictionary
	var need := 0
	var reached := false
	var claimed := false
	var left := true
	var t := 0.0
	var plaque: PanelContainer
	var medal: RewardMedal

	func setup(e: Dictionary, trophies: int, on_left: bool) -> void:
		entry = e
		need = int(e["trophies"])
		reached = trophies >= need
		claimed = str(e["id"]) in SaveGame.data["claimed"]
		left = on_left
		mouse_filter = Control.MOUSE_FILTER_PASS
		medal = RewardMedal.new()
		medal.entry = e
		medal.reached = reached
		medal.claimed = claimed
		medal.size = Vector2(112, 112)
		add_child(medal)
		plaque = PanelContainer.new()
		var empty := StyleBoxEmpty.new()
		for side in ["left", "right", "top", "bottom"]:
			empty.set("content_margin_" + side, 14)
		plaque.add_theme_stylebox_override("panel", empty)
		var metal := UiKit.rarity_metal("legendary" if reached else "common")
		var glow := 0.3 if reached and not claimed else 0.0
		var fr := UiKit.Frame.new("plaque", "leather", {"metal_hi": metal[0], "metal_lo": metal[1], "glow_color": Color(1.0, 0.7, 0.3, glow)})
		fr.margin = 16.0
		plaque.add_child(fr)
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 2)
		plaque.add_child(box)
		var head := UiKit.label(str(e["label"]).to_upper(), 24, UiKit.GOLD.lightened(0.2) if reached else Color("fff1d6"), "x", 5)
		box.add_child(head)
		var detail := UiKit.label(str(e["detail"]), 20, Color("e6d8bc"), "b", 4)
		detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(detail)
		var tag := HBoxContainer.new()
		tag.add_theme_constant_override("separation", 6)
		var gem := UiKit.Gem.new()
		gem.kind = "trophy"
		gem.custom_minimum_size = Vector2(30, 30)
		tag.add_child(gem)
		tag.add_child(UiKit.label(str(need), 22, Color("fff1d6"), "b", 4))
		box.add_child(tag)
		if claimed:
			box.add_child(UiKit.label("CLAIMED", 20, Color("b4f09e"), "x", 4))
		elif reached:
			var button := UiKit.confirm("CLAIM", 190, 88)
			button.pressed.connect(func() -> void: claim.emit(str(entry["id"])))
			box.add_child(button)
		else:
			box.add_child(UiKit.label("%d to go" % (need - int(SaveGame.data["trophies"])), 20, Color("f0c890"), "b", 4))
		add_child(plaque)

	func anchor_at(p: Vector2, w: float) -> void:
		position = Vector2.ZERO
		size = Vector2(w, 0)
		medal.position = p - medal.size * 0.5
		var pw := minf(290.0, w * 0.43)
		plaque.custom_minimum_size = Vector2(pw, 0)
		plaque.reset_size()
		# Plaque on the open side of the bend.
		var on_left := p.x > w * 0.5
		var px := p.x - 76.0 - pw if on_left else p.x + 76.0
		px = clampf(px, 10.0, w - pw - 10.0)
		plaque.position = Vector2(px, p.y - 56.0)

	func _process(delta: float) -> void:
		if reached and not claimed:
			t += delta
			medal.pivot_offset = medal.size * 0.5
			medal.scale = Vector2.ONE * (1.0 + sin(t * 3.5) * 0.04)


class RewardMedal extends Control:
	var entry: Dictionary
	var reached := false
	var claimed := false
	var _face: Texture2D

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		if str(entry.get("kind", "")) == "unlock":
			_face = SpriteBank.head(str(entry["hero"]))

	func _draw() -> void:
		var c := size * 0.5
		var r := size.x * 0.5 - 4.0
		if reached and not claimed:
			for g in 5:
				draw_circle(c, r + 6.0 + g * 5.0, Color(1.0, 0.72, 0.3, 0.07))
		draw_circle(c + Vector2(0, 5), r, Color(0, 0, 0, 0.55))
		draw_circle(c, r, Color("120a04"))
		var rim := Color("e8c070") if reached else Color("8a8070")
		var rim_lo := Color("6a4416") if reached else Color("3a352e")
		draw_circle(c, r - 2, rim_lo)
		draw_arc(c, r - 5, PI * 1.0, PI * 2.0, 32, rim, 5.0, true)
		draw_circle(c, r - 10, Color("1e1610"))
		draw_circle(c, r - 12, Color("2c2018") if reached else Color("1a1612"))
		var inner := r - 22
		var kind := str(entry.get("kind", ""))
		var dim := Color(1, 1, 1, 1) if reached else Color(0.55, 0.52, 0.48, 1)
		match kind:
			"coins":
				UiKit.draw_currency(self, "coin", Rect2(c - Vector2(inner, inner), Vector2(inner, inner) * 2.0))
			"chest":
				UiKit.draw_chest(self, Rect2(c - Vector2(inner, inner * 0.9), Vector2(inner * 2.0, inner * 1.7)), "gold" if reached else "wood", true)
			"unlock":
				if _face != null:
					var s := inner * 2.0
					draw_texture_rect(_face, Rect2(c - Vector2(s, s) * 0.5, Vector2(s, s)), false, dim)
			"gear":
				var icon := UiKit.icon("crown_a") if str(entry.get("slot", "")) == "charm" else UiKit.icon("sword")
				var col := Color("c08cf0") if str(entry.get("rarity", "")) == "epic" else Color("6aa8e8")
				UiKit.draw_icon(self, icon, Rect2(c - Vector2(inner, inner) * 0.8, Vector2(inner, inner) * 1.6), col * dim, Color(0.05, 0.03, 0.02), 2.0)
		if claimed:
			# A green wax seal with a tick.
			var sc := c + Vector2(r * 0.6, r * 0.6)
			draw_circle(sc, 17, Color("0c1a0e"))
			draw_circle(sc, 14, Color("2f8a4a"))
			draw_polyline(PackedVector2Array([sc + Vector2(-7, 0), sc + Vector2(-2, 6), sc + Vector2(8, -6)]), Color("f6ecd0"), 4.0, true)


## The glowing "you are here" pin with the live trophy count.
class Marker extends Control:
	var road: Road

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if road == null or road.points.is_empty():
			return
		var at := road.marker_at
		var pulse := 0.5 + 0.5 * sin(road.t * 3.0)
		# Offset to the side of the road so it never hides a medallion.
		var pin := at + Vector2(0, 0)
		for g in 5:
			draw_circle(pin, 30.0 + g * 6.0 + pulse * 6.0, Color(1.0, 0.72, 0.3, 0.07))
		draw_circle(pin + Vector2(0, 4), 30, Color(0, 0, 0, 0.5))
		draw_circle(pin, 30, Color("120a04"))
		draw_circle(pin, 27, Color("c8963a"))
		draw_arc(pin, 24, PI, TAU, 24, Color("ffe6a8"), 2.5, true)
		draw_circle(pin, 22, Color("2a1a10"))
		var trophy := UiKit.icon("trophy")
		UiKit.draw_icon(self, trophy, Rect2(pin - Vector2(15, 17), Vector2(30, 30)), UiKit.GOLD.lightened(0.25), Color(0.05, 0.03, 0.02), 1.5)
		var tag := Rect2(pin + Vector2(-34, 30), Vector2(68, 28))
		UiKit.rr_fill(self, tag.grow(2), 14, Color("120a04"), Color("120a04"))
		UiKit.rr_fill(self, tag, 12, Color("e8c070"), Color("8a5a1a"))
		UiKit.draw_text(self, UiKit.font_b, Vector2(tag.position.x, tag.end.y - 7), str(int(round(road._shown))), 19, Color("2a1806"), Color(1, 0.95, 0.8, 0.0), 0, tag.size.x)
