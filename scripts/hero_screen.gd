extends ScreenBase

var biome_id := "meadow"
var selected := "ember"
var list: VBoxContainer
var detail: Label
var gear_line: Label
var hunt: Button
var face: TextureRect


func build() -> void:
	var box := column()
	box.add_child(header())
	box.add_child(h1("Choose a hero"))
	detail = body("")
	box.add_child(detail)
	var center := CenterContainer.new()
	face = portrait("ember", 168)
	center.add_child(face)
	box.add_child(center)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 10)
	scroll.add_child(list)
	gear_line = body("", 18)
	box.add_child(gear_line)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	var loadout := UiKit.secondary("Loadout", 220, 74)
	loadout.pressed.connect(func() -> void: go("loadout", {"hero": selected, "biome": biome_id}))
	hunt = UiKit.button("Hunt", 280, 74)
	hunt.pressed.connect(func() -> void: go("run", {"biome": biome_id, "hero": selected}))
	row.add_child(loadout)
	row.add_child(hunt)
	box.add_child(row)
	box.add_child(back_button("world"))


func open(args: Dictionary = {}) -> void:
	biome_id = str(args.get("biome", "meadow"))
	var biome := Catalog.biome(biome_id)
	detail.text = "%s · tame %s" % [str(biome["name"]), str(Catalog.critter(str(biome["boss"]))["name"])]
	for id in Catalog.playable_ids():
		if bool(SaveGame.hero(id)["unlocked"]):
			selected = id
			break
	_fill()


func _fill() -> void:
	for child in list.get_children():
		child.queue_free()
	for id in Catalog.playable_ids():
		if not bool(SaveGame.hero(id)["unlocked"]):
			continue
		list.add_child(_row(id))
	face.texture = SpriteBank.critter(selected)
	var info := Catalog.critter(selected)
	var stats := SaveGame.build_run_stats(selected)
	hunt.text = "Hunt as %s" % str(info["name"])
	gear_line.text = "%s · HP %d · DMG %d\n%s" % [
		Catalog.role_name(str(info["role"])),
		int(round(float(stats["hp"]))),
		int(round(float(stats["dmg"]))),
		SaveGame.equipped_line(selected),
	]


func _row(id: String) -> Button:
	var info := Catalog.critter(id)
	var row := SaveGame.hero(id)
	var button := Button.new()
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size = Vector2(0, 92)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_override("font", UiKit.font_b)
	button.add_theme_font_size_override("font_size", 26)
	button.add_theme_color_override("font_color", Color("3a241c"))
	button.text = "  %s   Lv %d   %s" % [str(info["name"]), int(row["level"]), Catalog.role_name(str(info["role"]))]
	var on := id == selected
	button.add_theme_stylebox_override("normal", UiKit.chunky(Color("ffc56a") if on else Color("fff6ea"), Color("b87432") if on else Color("c4a07a")))
	button.add_theme_stylebox_override("hover", UiKit.chunky(Color("ffd48a") if on else Color("fffaf3"), Color("b87432")))
	button.add_theme_stylebox_override("pressed", UiKit.chunky(Color("e8a84e"), Color("8d5a28"), true))
	button.pressed.connect(_select.bind(id))
	return button


func _select(id: String) -> void:
	selected = id
	AudioDirector.play("click")
	_fill()
