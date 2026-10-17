extends ScreenBase


func build() -> void:
	var box := column()
	box.add_child(header())
	box.add_child(h1("Biomes"))
	box.add_child(body("Clear them in order. Each boss can be tamed."))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 12)
	scroll.add_child(list)
	for entry in Catalog.BIOMES:
		list.add_child(_card(entry))
	box.add_child(back_button("home"))


func _card(entry: Dictionary) -> PanelContainer:
	var id := str(entry["id"])
	var unlocked := SaveGame.biome_open(id)
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", UiKit.panel(Color("fffaf3") if unlocked else Color("efe4d6"), 22))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)
	var boss := Catalog.critter(str(entry["boss"]))
	box.add_child(UiKit.label(str(entry["name"]), 32, Color("3a241c"), "x", 0))
	box.add_child(UiKit.label("Boss %s · %s" % [str(boss["name"]), Catalog.role_name(str(boss["role"]))], 20, Color("6d5144"), "b", 0))
	var blurb := UiKit.label(str(entry["blurb"]), 18, Color("6d5144"), "m", 0)
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(blurb)
	if SaveGame.biome_cleared(id):
		box.add_child(UiKit.label("Cleared · hunt again any time", 18, Color("3e7a32"), "b", 0))
	if unlocked:
		var button := UiKit.button("Choose hero", 420, 70)
		button.pressed.connect(_open_biome.bind(id))
		box.add_child(button)
	else:
		box.add_child(UiKit.label(SaveGame.biome_lock_text(id), 18, Color("8a5a3a"), "b", 0))
	return panel


func _open_biome(id: String) -> void:
	go("heroes", {"biome": id})
