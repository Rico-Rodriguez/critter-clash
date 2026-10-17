class_name MainMenu
extends Control

signal play_requested
signal guide_requested


func _ready() -> void:
	UiKit.ensure()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var safe := UiKit.safe_insets()
	var title := UiKit.label("Critter Clash", 64, Color("fff6ea"), "x")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(40, safe.t + 18)
	title.size = Vector2(640, 84)
	add_child(title)
	var sub := UiKit.label("Two glades, one river. Drop a twin on forest, water, or lava and it grows into something else.", 22, Color("fff1e2"), "b")
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.position = Vector2(70, safe.t + 104)
	sub.size = Vector2(580, 88)
	add_child(sub)

	var legend := HBoxContainer.new()
	legend.position = Vector2(110, safe.t + 200)
	legend.size = Vector2(500, 42)
	legend.alignment = BoxContainer.ALIGNMENT_CENTER
	legend.add_theme_constant_override("separation", 10)
	legend.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(legend)
	for pair in [["Forest", "7dbe6a"], ["Water", "6ec8e0"], ["Lava", "ff7a45"]]:
		var chip := PanelContainer.new()
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.add_theme_stylebox_override("panel", UiKit.panel(Color(pair[1]), 14))
		var lab := UiKit.label(pair[0], 16, Color("3a241c"), "b")
		lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.add_child(lab)
		legend.add_child(chip)

	var play := UiKit.button("Enter the Glade", 460, 92)
	play.position = Vector2(130, 1280 - safe.b - 250)
	play.pressed.connect(func() -> void: play_requested.emit())
	add_child(play)
	var guide := UiKit.button("Field Guide", 460, 78)
	guide.position = Vector2(130, 1280 - safe.b - 140)
	guide.add_theme_stylebox_override("normal", UiKit.chunky(Color("d7efc4"), Color("6d8a48")))
	guide.add_theme_stylebox_override("hover", UiKit.chunky(Color("e7f8d8"), Color("6d8a48")))
	guide.add_theme_stylebox_override("pressed", UiKit.chunky(Color("c4e0ae"), Color("547038"), true))
	guide.add_theme_stylebox_override("focus", UiKit.chunky(Color("e7f8d8"), Color("6d8a48")))
	guide.pressed.connect(func() -> void: guide_requested.emit())
	add_child(guide)
