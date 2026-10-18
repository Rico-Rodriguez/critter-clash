extends ScreenBase

var grid: GridContainer


func build() -> void:
	show_nav = true
	nav_tab = "collection"
	var box := column()
	box.add_child(header())
	box.add_child(h1("Collection"))
	box.add_child(body("Duplicates and coins raise a card level."))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	grid = GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 22)
	scroll.add_child(grid)
	_fill()


func _fill() -> void:
	for child in grid.get_children():
		child.queue_free()
	for id in Catalog.playable_ids():
		var card := HeroCard.new()
		card.setup(id)
		card.upgrade.connect(_level)
		card.gear.connect(_gear)
		grid.add_child(card)


func _level(id: String) -> void:
	if SaveGame.try_level(id):
		go("collection")


func _gear(id: String) -> void:
	SaveGame.set_featured(id)
	go("loadout", {"hero": id, "biome": "meadow", "from": "collection"})


## A collectible card: rarity-forged frame with a soft aura, the hero's
## 3D render backlit in an inset window, a level shield, and a name plaque.
class HeroCard extends PanelContainer:
	signal upgrade(id: String)
	signal gear(id: String)

	var hero_id := ""

	func setup(id: String) -> void:
		hero_id = id
		var info := Catalog.critter(id)
		var row: Dictionary = SaveGame.hero(id)
		var rarity := UiKit.hero_rarity(id)
		var cols: Dictionary = UiKit.rarity_colors(rarity)
		var unlocked := bool(row["unlocked"])
		var box_style := StyleBoxEmpty.new()
		box_style.content_margin_left = 14
		box_style.content_margin_right = 14
		box_style.content_margin_top = 14
		box_style.content_margin_bottom = 14
		add_theme_stylebox_override("panel", box_style)
		custom_minimum_size = Vector2(0, 470)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var metal := UiKit.rarity_metal(rarity)
		var frame := UiKit.Frame.new("card", "leather", {
			"metal_hi": metal[0], "metal_lo": metal[1], "studs": 1.0, "frame": 7.0,
			"glow_color": Color(cols["glow"], 0.3 if unlocked else 0.0),
			"face_top": Color("221a14") if unlocked else Color("15110e"), "face_bot": Color("0e0b08"),
		})
		frame.margin = 18.0
		add_child(frame)
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 6)
		add_child(box)
		var ribbon := UiKit.label(Catalog.rarity_name(rarity).to_upper(), 21, Color(cols["lip"]).lightened(0.25), "x", 4)
		ribbon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(ribbon)
		var art := ArtWindow.new()
		art.tex = SpriteBank.critter(id)
		art.glow = cols["glow"]
		art.locked = not unlocked
		art.custom_minimum_size = Vector2(0, 190)
		box.add_child(art)
		if unlocked:
			var badge := UiKit.Badge.new()
			badge.level = int(row["level"])
			badge.size = Vector2(54, 60)
			badge.position = Vector2(-4, 22)
			art.add_child(badge)
		var name := UiKit.label(str(info["name"]).to_upper(), 29, Color("fff1d6") if unlocked else Color("cdbfa6"), "x", 5)
		name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(name)
		if not unlocked:
			var locked := UiKit.label("Unlock: " + Catalog.unlock_line(id), 21, Color("f0cf86"), "b", 4)
			locked.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			locked.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			box.add_child(locked)
			return
		var level := int(row["level"])
		if level >= Catalog.MAX_CARD_LEVEL:
			var maxed := UiKit.label("MAX LEVEL", 22, UiKit.GOLD, "x", 4)
			maxed.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			box.add_child(maxed)
		else:
			var need := SaveGame.cards_needed(level)
			var have := int(row["cards"])
			var bar := CardBar.new()
			bar.ratio = clampf(float(have) / float(maxi(need, 1)), 0.0, 1.0)
			bar.caption = "%d / %d" % [mini(have, need), need]
			bar.surplus = maxi(0, have - need)
			bar.ready_up = SaveGame.can_level(id)
			bar.custom_minimum_size = Vector2(0, 42)
			box.add_child(bar)
		var actions := HBoxContainer.new()
		actions.alignment = BoxContainer.ALIGNMENT_CENTER
		actions.add_theme_constant_override("separation", 8)
		if SaveGame.can_level(id):
			var up := UiKit.confirm("UPGRADE", 168, 60)
			up.font_px = 27
			up.pressed.connect(func() -> void: upgrade.emit(hero_id))
			actions.add_child(up)
		var gear_b := UiKit.secondary("GEAR", 118 if SaveGame.can_level(id) else 168, 60)
		gear_b.font_px = 27
		gear_b.pressed.connect(func() -> void: gear.emit(hero_id))
		actions.add_child(gear_b)
		box.add_child(actions)


## Inset art window: dark recess, rarity-coloured backlight, the render,
## and a floor shadow. Locked heroes show as a dark silhouette with a lock.
class ArtWindow extends Control:
	var tex: Texture2D
	var glow := Color.WHITE
	var locked := false

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		clip_contents = false

	func _draw() -> void:
		var r := Rect2(Vector2(4, 0), size - Vector2(8, 0))
		UiKit.ch_fill(self, r.grow(2), 14, Color(0, 0, 0, 0.6), Color(0, 0, 0, 0.6))
		UiKit.ch_fill(self, r, 12, Color("0a0806"), Color("16110d"))
		var c := r.get_center() + Vector2(0, -6)
		var g := glow if not locked else Color(0.4, 0.4, 0.45)
		for i in 10:
			var k := float(i) / 10.0
			draw_circle(c, r.size.y * (0.62 - k * 0.5), Color(g, 0.05 + k * 0.012))
		# Floor shadow.
		draw_set_transform(Vector2(c.x, r.end.y - 16), 0.0, Vector2(1.0, 0.22))
		draw_circle(Vector2.ZERO, r.size.x * 0.32, Color(0, 0, 0, 0.55))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if tex != null:
			var ts := tex.get_size()
			var fit := minf((r.size.x - 12) / ts.x, (r.size.y - 8) / ts.y)
			var dst := Rect2(c - ts * fit * 0.5 + Vector2(0, 4), ts * fit)
			if locked:
				# Silhouette with a faint cold edge so the shape reads.
				draw_texture_rect(tex, dst.grow(2), false, Color(0.45, 0.55, 0.7, 0.35))
				draw_texture_rect(tex, dst, false, Color(0.04, 0.04, 0.05, 1.0))
			else:
				draw_texture_rect(tex, dst, false)
		# Inner rim shadow and a top sheen line.
		UiKit.rr_line(self, r.grow(-1), 9, Color(0, 0, 0, 0.7), 3.0)
		draw_line(r.position + Vector2(12, 2), Vector2(r.end.x - 12, r.position.y + 2), Color(1, 0.9, 0.7, 0.08), 1.0)
		if locked:
			_frost(r)
			_chain(r.position + Vector2(10, 12), r.end - Vector2(10, 12))
			_chain(Vector2(r.end.x - 10, r.position.y + 12), Vector2(r.position.x + 10, r.end.y - 12))
			# A heavy padlock where the chains cross.
			draw_circle(c + Vector2(0, 3), 34, Color(0, 0, 0, 0.5))
			var lk := UiKit.icon("lock_closed")
			var px := 58.0
			UiKit.draw_icon(self, lk, Rect2(c - Vector2(px, px) * 0.5, Vector2(px, px)), UiKit.GOLD, Color(0.05, 0.03, 0.02), 3.0)

	## Frosted glass over the window: a cold milky wash, brighter at the top,
	## with a few diagonal glints.
	func _frost(r: Rect2) -> void:
		UiKit.ch_fill(self, r, 12, Color(0.62, 0.7, 0.8, 0.2), Color(0.3, 0.36, 0.45, 0.1))
		for i in 4:
			var x := r.position.x + r.size.x * (0.12 + 0.24 * i)
			draw_line(Vector2(x, r.position.y + 8), Vector2(x - 34, r.position.y + 70), Color(0.9, 0.95, 1.0, 0.07), 6.0)
		draw_line(r.position + Vector2(14, 4), Vector2(r.end.x - 14, r.position.y + 4), Color(0.85, 0.92, 1.0, 0.25), 1.5)

	## A run of iron chain links from a to b.
	func _chain(a: Vector2, b: Vector2) -> void:
		var d := b - a
		var n := int(d.length() / 15.0)
		var ang := d.angle()
		for i in n + 1:
			var p := a + d * (float(i) / float(maxi(n, 1)))
			var flat := i % 2 == 0
			var sx := 11.0
			var sy := 6.0 if flat else 2.6
			draw_set_transform(p + Vector2(0, 2), ang, Vector2(1, 1))
			draw_arc(Vector2.ZERO, 1.0, 0, TAU, 2, Color.TRANSPARENT)
			_link(sx, sy, Color(0, 0, 0, 0.55))
			draw_set_transform(p, ang, Vector2(1, 1))
			_link(sx, sy, Color("6d655c") if flat else Color("4a443d"))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	func _link(sx: float, sy: float, col: Color) -> void:
		var pts := PackedVector2Array()
		for k in 17:
			var t := TAU * k / 16.0
			pts.append(Vector2(cos(t) * sx, sin(t) * sy))
		draw_polyline(pts, col, 3.2, true)


class CardBar extends Control:
	var ratio := 0.0
	var caption := ""
	var surplus := 0
	var ready_up := false

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		UiKit.ensure()
		var r := Rect2(Vector2.ZERO, size)
		UiKit.ch_fill(self, r.grow(1), size.y * 0.5, Color("8a6a3a"), Color("3a2410"))
		UiKit.ch_fill(self, r.grow(-2), size.y * 0.5 - 2, Color("070504"), Color("1a140f"))
		var inner := Rect2(4, 4, maxf(0.0, (size.x - 8.0) * ratio), maxf(0.0, size.y - 8.0))
		if inner.size.x > inner.size.y:
			var hi := Color("7ad06a") if ready_up else Color("4aa3d8")
			var lo := Color("1e5a22") if ready_up else Color("123e66")
			UiKit.ch_fill(self, inner, inner.size.y * 0.5, hi, lo)
			UiKit.ch_fill(self, Rect2(inner.position + Vector2(4, 1), Vector2(inner.size.x - 8, inner.size.y * 0.4)), inner.size.y * 0.2, Color(1, 1, 1, 0.3), Color(1, 1, 1, 0.0))
		var reserve := 56.0 if surplus > 0 else 0.0
		UiKit.draw_text(self, UiKit.font_b, Vector2(8, size.y * 0.72), caption, 24, UiKit.CREAM, Color(0.04, 0.03, 0.02), 3, size.x - 16.0 - reserve)
		if surplus > 0:
			var pill := Rect2(size.x - 56, 3, 52, size.y - 6)
			UiKit.ch_fill(self, pill, pill.size.y * 0.5, Color("ffe3a0"), Color("9a6a20"))
			UiKit.draw_text(self, UiKit.font_b, Vector2(pill.position.x, size.y * 0.72), "+%d" % surplus, 20, Color("2a1806"), Color(1, 0.95, 0.8, 0.0), 0, pill.size.x)
