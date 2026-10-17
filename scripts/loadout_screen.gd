extends ScreenBase

var hero_id := "ember"
var biome_id := "meadow"
var return_to := "heroes"
var slot := "weapon"
var list: VBoxContainer
var title_label: Label
var summary: Label


func build() -> void:
	var box := column()
	box.add_child(header())
	title_label = h1("Loadout")
	box.add_child(title_label)
	summary = body("")
	box.add_child(summary)
	var slots := HBoxContainer.new()
	slots.alignment = BoxContainer.ALIGNMENT_CENTER
	slots.add_theme_constant_override("separation", 8)
	for name in ["weapon", "armor", "charm"]:
		var button := UiKit.secondary(name.capitalize(), 180, 64)
		button.pressed.connect(_pick_slot.bind(name))
		slots.add_child(button)
	box.add_child(slots)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)
	var back := UiKit.secondary("Back", 200, 64)
	back.pressed.connect(func() -> void: go(return_to, {"biome": biome_id}))
	box.add_child(back)


func open(args: Dictionary = {}) -> void:
	hero_id = str(args.get("hero", "ember"))
	biome_id = str(args.get("biome", "meadow"))
	return_to = "collection" if str(args.get("from", "")) == "collection" else "heroes"
	_fill()


func _pick_slot(next: String) -> void:
	slot = next
	_fill()


func _fill() -> void:
	var info := Catalog.critter(hero_id)
	title_label.text = "%s loadout" % str(info["name"])
	var equipped := int(SaveGame.hero(hero_id)[slot])
	var worn := "Empty %s slot" % slot
	if equipped > 0:
		var piece := SaveGame.find_gear(equipped)
		if not piece.is_empty():
			worn = "Wearing " + SaveGame.gear_text(piece)
	summary.text = worn
	for child in list.get_children():
		child.queue_free()
	if equipped > 0:
		var clear := UiKit.secondary("Unequip %s" % slot, 420, 64)
		clear.pressed.connect(_clear_slot)
		list.add_child(clear)
	var found := false
	for piece in SaveGame.data["bag"]:
		if str(piece["slot"]) != slot:
			continue
		found = true
		var button := Button.new()
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.custom_minimum_size = Vector2(0, 84)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_override("font", UiKit.font_b)
		button.add_theme_font_size_override("font_size", 20)
		button.add_theme_color_override("font_color", Color("3a241c"))
		button.text = SaveGame.gear_text(piece)
		button.add_theme_stylebox_override("normal", UiKit.rarity_box(str(piece["rarity"])))
		button.pressed.connect(_equip.bind(int(piece["uid"])))
		list.add_child(button)
	if not found:
		list.add_child(body("Chests drop weapons, armor, and charms."))


func _equip(uid: int) -> void:
	SaveGame.equip(hero_id, uid)
	_fill()


func _clear_slot() -> void:
	SaveGame.unequip(hero_id, slot)
	_fill()
