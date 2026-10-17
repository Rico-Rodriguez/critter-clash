extends ScreenBase

var list: VBoxContainer


func build() -> void:
	var box := column()
	box.add_child(header())
	box.add_child(h1("Trophy Road"))
	box.add_child(body("Wins add trophies. Claim the rewards as you pass them."))
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
	var trophies := int(SaveGame.data["trophies"])
	for entry in Catalog.MILESTONES:
		list.add_child(_row(entry, trophies))


func _row(entry: Dictionary, trophies: int) -> PanelContainer:
	var id := str(entry["id"])
	var need := int(entry["trophies"])
	var claimed: bool = id in SaveGame.data["claimed"]
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", UiKit.panel(Color("fffaf3") if trophies >= need else Color("efe4d6"), 20))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	panel.add_child(box)
	box.add_child(UiKit.label("%s  ·  %d trophies" % [str(entry["label"]), need], 26, Color("3a241c"), "x", 0))
	box.add_child(UiKit.label(str(entry["detail"]), 18, Color("6d5144"), "m", 0))
	if claimed:
		box.add_child(UiKit.label("Claimed", 18, Color("3e7a32"), "b", 0))
	elif trophies >= need:
		var button := UiKit.button("Claim", 240, 64)
		button.pressed.connect(_claim.bind(id))
		box.add_child(button)
	else:
		box.add_child(UiKit.label("%d to go" % (need - trophies), 18, Color("8a5a3a"), "b", 0))
	return panel


func _claim(id: String) -> void:
	if SaveGame.claim(id):
		go("trophy")
