extends ScreenBase


func build() -> void:
	var box := column()
	box.add_child(header())
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 18)
	box.add_child(spacer)
	box.add_child(h1("Critter Clash"))
	box.add_child(body("Steer one hero. Tame the boss."))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	for id in ["ember", "juniper", "pebble"]:
		row.add_child(portrait(id, 168))
	box.add_child(row)
	var play := UiKit.button("Hunt", 520, 96)
	play.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	play.pressed.connect(func() -> void: go("world"))
	box.add_child(play)
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 12)
	var collection := UiKit.secondary("Collection", 250, 74)
	collection.pressed.connect(func() -> void: go("collection"))
	var trophies := UiKit.secondary("Trophy Road", 250, 74)
	trophies.pressed.connect(func() -> void: go("trophy"))
	actions.add_child(collection)
	actions.add_child(trophies)
	box.add_child(actions)
	if SaveGame.pending_count() > 0:
		var chest := UiKit.button("Open chest (%d)" % SaveGame.pending_count(), 520, 84)
		chest.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		chest.pressed.connect(func() -> void: go("chest"))
		box.add_child(chest)
	var grow := Control.new()
	grow.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(grow)
	box.add_child(body("Drag the lower screen to steer. Your hero bites the nearest wild critter.", 18))
