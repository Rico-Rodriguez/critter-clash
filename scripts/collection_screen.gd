extends ScreenBase

var list: VBoxContainer


func build() -> void:
	var box := column()
	box.add_child(header())
	box.add_child(h1("Collection"))
	box.add_child(body("Duplicates and coins raise a critter's card level."))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 10)
	scroll.add_child(list)
	box.add_child(back_button("home"))
	_fill()


func _fill() -> void:
	for child in list.get_children():
		child.queue_free()
	for id in Catalog.playable_ids():
		list.add_child(_row(id))


func _row(id: String) -> PanelContainer:
	var info := Catalog.critter(id)
	var row: Dictionary = SaveGame.hero(id)
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", UiKit.panel(Color("fffaf3"), 20))
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var face := portrait(id, 96)
	if not bool(row["unlocked"]):
		face.modulate = Color(0.35, 0.3, 0.28, 0.85)
	box.add_child(face)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 2)
	box.add_child(text)
	text.add_child(UiKit.label(str(info["name"]), 26, Color("3a241c"), "x", 0))
	if bool(row["unlocked"]):
		var level := int(row["level"])
		text.add_child(UiKit.label("Lv %d · %s" % [level, Catalog.role_name(str(info["role"]))], 18, Color("6d5144"), "b", 0))
		if level >= Catalog.MAX_CARD_LEVEL:
			text.add_child(UiKit.label("Max level", 18, Color("3e7a32"), "b", 0))
		else:
			text.add_child(UiKit.label("%d/%d cards · %d coins" % [int(row["cards"]), SaveGame.cards_needed(level), SaveGame.coins_needed(level)], 18, Color("6d5144"), "m", 0))
		var actions := HBoxContainer.new()
		actions.add_theme_constant_override("separation", 8)
		var up := UiKit.secondary("Level", 120, 52)
		up.disabled = not SaveGame.can_level(id)
		up.pressed.connect(_level.bind(id))
		var gear := UiKit.secondary("Gear", 120, 52)
		gear.pressed.connect(_gear.bind(id))
		actions.add_child(up)
		actions.add_child(gear)
		text.add_child(actions)
	else:
		text.add_child(UiKit.label(str(info.get("unlock", "Locked")), 18, Color("8a5a3a"), "m", 0))
		var hint := UiKit.label(str(info.get("blurb", "")), 16, Color("6d5144"), "m", 0)
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.add_child(hint)
	return panel


func _level(id: String) -> void:
	if SaveGame.try_level(id):
		_fill()
		# Refresh the coin header by rebuilding is heavier; the row text is enough
		# and the header was captured at build. Rebuild the whole screen's header
		# by walking back to collection.
		go("collection")


func _gear(id: String) -> void:
	go("loadout", {"hero": id, "biome": "meadow", "from": "collection"})
