extends ScreenBase


func build() -> void:
	show_nav = true
	nav_tab = "world"
	var box := column()
	box.add_child(header())
	box.add_child(h1("Biomes"))
	box.add_child(body("Clear them in order. Each boss has a drop table."))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 14)
	scroll.add_child(list)
	for entry in Catalog.BIOMES:
		list.add_child(_banner(entry))


func _banner(entry: Dictionary) -> PanelContainer:
	var id := str(entry["id"])
	var unlocked := SaveGame.biome_open(id)
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var frame := UiKit.panel(Color("102848"), 20)
	frame.content_margin_left = 0
	frame.content_margin_right = 0
	frame.content_margin_top = 0
	frame.content_margin_bottom = 0
	panel.add_theme_stylebox_override("panel", frame)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 0)
	panel.add_child(stack)
	var art := TextureRect.new()
	art.custom_minimum_size = Vector2(0, 168)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.texture = SpriteBank.arena(id)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not unlocked:
		art.modulate = Color(0.45, 0.5, 0.6)
	stack.add_child(art)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 10)
	margin.add_child(row)
	stack.add_child(margin)
	var medal := portrait(str(entry["boss"]), 84)
	var ring := PanelContainer.new()
	ring.add_theme_stylebox_override("panel", UiKit.rarity_box("legendary"))
	ring.add_child(medal)
	row.add_child(ring)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 2)
	row.add_child(text)
	var boss := Catalog.critter(str(entry["boss"]))
	text.add_child(UiKit.label(str(entry["name"]), 30, UiKit.CREAM, "x", 5))
	text.add_child(UiKit.label("Boss · %s" % str(boss["name"]), 16, Color("d5e6ff"), "b", 3))
	if SaveGame.biome_cleared(id):
		text.add_child(UiKit.label("CLEARED", 16, Color("b6ff9a"), "x", 3))
	if unlocked:
		var button := UiKit.button("CHOOSE HERO", 280, 64)
		button.pressed.connect(_open_biome.bind(id))
		text.add_child(button)
	else:
		text.add_child(UiKit.label("LOCKED", 18, Color("ffb0b0"), "x", 4))
		text.add_child(UiKit.label(SaveGame.biome_lock_text(id), 16, Color("d5e6ff"), "b", 3))
	return panel


func _open_biome(id: String) -> void:
	go("heroes", {"biome": id})
