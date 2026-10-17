extends ScreenBase

var grid: GridContainer
var count_label: Label
var kill_label: Label
var boss_id := "thistle"


func build() -> void:
	show_nav = true
	nav_tab = ""
	var box := column()
	box.add_child(header())
	box.add_child(h1("Collection Log"))
	count_label = UiKit.label("", 28, Color("ffe08a"), "x", 6)
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(count_label)
	kill_label = body("", 18)
	box.add_child(kill_label)
	var tabs := HBoxContainer.new()
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs.add_theme_constant_override("separation", 6)
	box.add_child(tabs)
	for entry in Catalog.BIOMES:
		var id := str(entry["boss"])
		var short := str(entry["name"]).split(" ")[0]
		var button := UiKit.secondary(short, 150, 56)
		button.pressed.connect(_tab.bind(id))
		tabs.add_child(button)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	grid = GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(grid)
	box.add_child(back_button("home"))
	_fill()


func _tab(id: String) -> void:
	boss_id = id
	AudioDirector.play("click")
	_fill()


func _fill() -> void:
	var total := Catalog.all_drops().size()
	count_label.text = "%d/%d" % [SaveGame.obtained_count(), total]
	var boss := Catalog.critter(boss_id)
	kill_label.text = "%s · %d kills" % [str(boss.get("name", "Boss")), SaveGame.boss_kills(boss_id)]
	for child in grid.get_children():
		child.queue_free()
	for entry in Catalog.drop_table(boss_id):
		var cell := LogCell.new()
		cell.drop = entry
		cell.got = SaveGame.has_log(str(entry["id"]))
		cell.custom_minimum_size = Vector2(0, 150)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.pressed_pet.connect(_pet)
		grid.add_child(cell)


func _pet(id: String) -> void:
	SaveGame.set_active_pet(id)
	var drop := Catalog.drop_by_id(id)
	toast("%s follows you." % str(drop.get("name", "Pet")))


class LogCell extends PanelContainer:
	signal pressed_pet(id: String)

	var drop: Dictionary = {}
	var got := false

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		var frame := UiKit.panel(Color("163e86"), 16)
		frame.border_color = Color("081018")
		frame.border_width_left = 4
		frame.border_width_right = 4
		frame.border_width_top = 4
		frame.border_width_bottom = 6
		add_theme_stylebox_override("panel", frame)
		gui_input.connect(_on_input)

	func _on_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and got and str(drop.get("kind", "")) == "pet":
			pressed_pet.emit(str(drop["id"]))

	func _draw() -> void:
		var center := Vector2(size.x * 0.5, 48)
		var kind := str(drop.get("kind", ""))
		if kind == "pet":
			var tex := SpriteBank.critter(str(drop.get("sprite", "thistle")))
			if tex:
				var tint := Color.WHITE if got else Color(0.07, 0.08, 0.1, 1)
				draw_texture_rect(tex, Rect2(center.x - 34, 8, 68, 68), false, tint)
		else:
			var col := Color(str(drop.get("color", "f0b429")))
			if not got:
				col = Color(0.1, 0.11, 0.14)
			_icon(center, kind, col, got)
		UiKit.ensure()
		var rarity := Catalog.rarity_label(str(drop.get("rarity", "common")))
		var ink := Color("ffe08a") if got else Color("9aabbf")
		draw_string(UiKit.font_x, Vector2(4, size.y - 32), str(drop.get("name", "")), HORIZONTAL_ALIGNMENT_CENTER, size.x - 8, 15, ink)
		draw_string(UiKit.font_b, Vector2(4, size.y - 12), rarity, HORIZONTAL_ALIGNMENT_CENTER, size.x - 8, 13, Color("d5e6ff") if got else Color("7d8ea6"))

	func _icon(center: Vector2, kind: String, col: Color, owned: bool) -> void:
		var edge := Color(1, 1, 1, 0.45) if owned else Color(0.45, 0.5, 0.58, 0.9)
		match kind:
			"cards":
				draw_rect(Rect2(center.x - 18, center.y - 24, 36, 48), col, true)
				draw_rect(Rect2(center.x - 18, center.y - 24, 36, 48), edge, false, 3.0)
			"gear":
				var shield := PackedVector2Array([
					center + Vector2(0, -26), center + Vector2(22, -8),
					center + Vector2(16, 20), center + Vector2(0, 28),
					center + Vector2(-16, 20), center + Vector2(-22, -8),
				])
				draw_colored_polygon(shield, col)
				draw_polyline(shield + PackedVector2Array([shield[0]]), edge, 3.0, true)
			"material":
				var gem := PackedVector2Array([
					center + Vector2(0, -26), center + Vector2(20, -6),
					center + Vector2(12, 22), center + Vector2(-12, 22),
					center + Vector2(-20, -6),
				])
				draw_colored_polygon(gem, col)
				draw_polyline(gem + PackedVector2Array([gem[0]]), edge, 3.0, true)
			_:
				draw_circle(center + Vector2(-8, 4), 16, col)
				draw_circle(center + Vector2(8, -2), 14, col.lightened(0.12))
				draw_arc(center + Vector2(-8, 4), 16, 0, TAU, 20, edge, 2.5, true)
				draw_arc(center + Vector2(8, -2), 14, 0, TAU, 18, edge, 2.5, true)
