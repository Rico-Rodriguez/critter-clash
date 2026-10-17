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
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
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
		var frame := UiKit.rarity_box(rarity)
		frame.content_margin_left = 8
		frame.content_margin_right = 8
		frame.content_margin_top = 8
		frame.content_margin_bottom = 8
		add_theme_stylebox_override("panel", frame)
		custom_minimum_size = Vector2(0, 360)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 4)
		add_child(box)
		var ribbon := UiKit.label(Catalog.rarity_name(rarity), 16, cols["ink"], "x", 3)
		ribbon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(ribbon)
		var unlocked := bool(row["unlocked"])
		if unlocked:
			var face := TextureRect.new()
			face.custom_minimum_size = Vector2(0, 150)
			face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			face.texture = SpriteBank.critter(id)
			face.mouse_filter = Control.MOUSE_FILTER_IGNORE
			box.add_child(face)
		else:
			var face := Silhouette.new()
			face.tex = SpriteBank.critter(id)
			face.custom_minimum_size = Vector2(0, 150)
			box.add_child(face)
		var name := UiKit.label(str(info["name"]), 26, UiKit.CREAM, "x", 5)
		name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(name)
		if not unlocked:
			var locked := UiKit.label(Catalog.unlock_line(id), 16, Color("ffe08a"), "x", 3)
			locked.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			locked.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			box.add_child(locked)
			return
		var level := int(row["level"])
		var badge_row := HBoxContainer.new()
		badge_row.alignment = BoxContainer.ALIGNMENT_CENTER
		badge_row.add_theme_constant_override("separation", 6)
		var badge := UiKit.label("LV %d" % level, 20, UiKit.CREAM, "x", 4)
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge_row.add_child(badge)
		if SaveGame.can_level(id):
			var arrow := UiKit.label("▲", 26, Color("7dff4a"), "x", 5)
			badge_row.add_child(arrow)
		box.add_child(badge_row)
		if level >= Catalog.MAX_CARD_LEVEL:
			box.add_child(UiKit.label("MAX", 18, Color("ffe08a"), "x", 4))
		else:
			var need := SaveGame.cards_needed(level)
			var have := int(row["cards"])
			var bar := CardBar.new()
			bar.ratio = clampf(float(have) / float(maxi(need, 1)), 0.0, 1.0)
			bar.caption = "%d/%d" % [mini(have, need), need]
			bar.surplus = maxi(0, have - need)
			bar.custom_minimum_size = Vector2(0, 28)
			box.add_child(bar)
			box.add_child(UiKit.label("%d coins" % SaveGame.coins_needed(level), 14, Color("d5e6ff"), "b", 3))
		var actions := HBoxContainer.new()
		actions.alignment = BoxContainer.ALIGNMENT_CENTER
		actions.add_theme_constant_override("separation", 6)
		if SaveGame.can_level(id):
			var up := UiKit.confirm("UP", 100, 48)
			up.pressed.connect(func() -> void: upgrade.emit(hero_id))
			actions.add_child(up)
		var gear_b := UiKit.secondary("GEAR", 100, 48)
		gear_b.pressed.connect(func() -> void: gear.emit(hero_id))
		actions.add_child(gear_b)
		box.add_child(actions)


class Silhouette extends Control:
	var tex: Texture2D

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if tex == null:
			return
		draw_texture_rect(tex, Rect2(Vector2.ZERO, size), false, Color(0.06, 0.07, 0.1, 1))
		var c := Vector2(size.x * 0.5, size.y * 0.58)
		draw_circle(c, 28, Color(0, 0, 0, 0.4))
		draw_arc(c + Vector2(0, -8), 13, PI, TAU, 16, Color("ffe7a0"), 4.0, true)
		draw_rect(Rect2(c.x - 15, c.y - 2, 30, 24), Color("ffe7a0"), true)
		draw_circle(c + Vector2(0, 8), 4, Color("3a2a12"))


class CardBar extends Control:
	var ratio := 0.0
	var caption := ""
	var surplus := 0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var plate := StyleBoxFlat.new()
		plate.bg_color = Color("10284f")
		plate.set_corner_radius_all(8)
		plate.set_border_width_all(3)
		plate.border_color = Color("081018")
		plate.draw(get_canvas_item(), Rect2(Vector2.ZERO, size))
		var inner := Rect2(4, 4, maxf(0.0, (size.x - 8.0) * ratio), maxf(0.0, size.y - 8.0))
		if inner.size.x > 1.0:
			var fill := StyleBoxFlat.new()
			fill.bg_color = Color("3ecf4a")
			fill.set_corner_radius_all(6)
			fill.draw(get_canvas_item(), inner)
			var gloss := StyleBoxFlat.new()
			gloss.bg_color = Color(1, 1, 1, 0.28)
			gloss.set_corner_radius_all(5)
			gloss.draw(get_canvas_item(), Rect2(inner.position, Vector2(inner.size.x, maxf(3.0, inner.size.y * 0.38))))
		UiKit.ensure()
		var reserve := 36.0 if surplus > 0 else 0.0
		draw_string(UiKit.font_x, Vector2(8, size.y * 0.78), caption, HORIZONTAL_ALIGNMENT_CENTER, size.x - 16.0 - reserve, 16, Color.WHITE)
		if surplus > 0:
			var pill := Rect2(size.x - 40, 2, 36, size.y - 4)
			var gold := StyleBoxFlat.new()
			gold.bg_color = Color("f0a020")
			gold.set_corner_radius_all(8)
			gold.draw(get_canvas_item(), pill)
			draw_string(UiKit.font_x, Vector2(pill.position.x, size.y * 0.75), "+%d" % surplus, HORIZONTAL_ALIGNMENT_CENTER, pill.size.x, 14, Color("3a2208"))
