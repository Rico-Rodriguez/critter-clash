extends ScreenBase

var title_label: Label
var loot_box: VBoxContainer
var open_button: Button
var home_button: Button
var showing_loot := false


func build() -> void:
	var box := column()
	box.add_child(header())
	title_label = h1("Chest")
	box.add_child(title_label)
	box.add_child(body("Cards level your critters. Gear fills weapon, armor, and charm."))
	loot_box = VBoxContainer.new()
	loot_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	loot_box.add_theme_constant_override("separation", 8)
	box.add_child(loot_box)
	open_button = UiKit.button("Open", 420, 90)
	open_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	open_button.pressed.connect(_on_open)
	box.add_child(open_button)
	home_button = UiKit.secondary("Home", 220, 64)
	home_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	home_button.visible = false
	home_button.pressed.connect(func() -> void: go("home"))
	box.add_child(home_button)


func open(_args: Dictionary = {}) -> void:
	_arm()


func _arm() -> void:
	for child in loot_box.get_children():
		child.queue_free()
	home_button.visible = false
	showing_loot = false
	if SaveGame.pending_count() <= 0:
		title_label.text = "No chests"
		open_button.visible = false
		home_button.visible = true
		loot_box.add_child(body("Win or lose a hunt and one comes home with you."))
		return
	var chest: Dictionary = SaveGame.data["chests"][0]
	var hunt := str(chest.get("kind", "hunt")) == "hunt"
	title_label.text = "Hunt chest" if hunt else "Small pouch"
	open_button.visible = true
	open_button.text = "Open"
	var biome := Catalog.biome(str(chest.get("biome", "meadow")))
	loot_box.add_child(body("From the %s." % str(biome["name"])))


func _on_open() -> void:
	if showing_loot:
		_arm()
		return
	_reveal()


func _reveal() -> void:
	var loot := SaveGame.open_next()
	if loot.is_empty():
		_arm()
		return
	for child in loot_box.get_children():
		child.queue_free()
	open_button.visible = false
	home_button.visible = true
	title_label.text = "Yours"
	loot_box.add_child(UiKit.label("+%d coins" % int(loot["coins"]), 32, Color("8a5a18"), "x", 0))
	var totals := {}
	for drop in loot["cards"]:
		var id := str(drop["id"])
		totals[id] = int(totals.get(id, 0)) + int(drop["count"])
	for id in totals.keys():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.add_child(portrait(str(id), 72))
		var info := Catalog.critter(str(id))
		row.add_child(UiKit.label("+%d %s" % [int(totals[id]), str(info.get("name", id))], 26, Color("3a241c"), "b", 0))
		loot_box.add_child(row)
	var gear: Dictionary = loot["gear"]
	if not gear.is_empty():
		var gear_label := UiKit.label(SaveGame.gear_text(gear), 22, Color("3a241c"), "b", 0)
		gear_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		loot_box.add_child(gear_label)
	if SaveGame.pending_count() > 0:
		open_button.visible = true
		open_button.text = "Next chest"
		showing_loot = true
