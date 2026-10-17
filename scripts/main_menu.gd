class_name MainMenu
extends Control

signal play_requested
signal guide_requested


func _ready() -> void:
	UiKit.ensure()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var safe := UiKit.safe_insets()

	var top := Panel.new()
	top.position = Vector2(28, safe.t + 6)
	top.size = Vector2(664, 196)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var top_style := UiKit.panel(Color(0.16, 0.08, 0.06, 0.78), 26)
	top_style.border_color = Color(1, 0.86, 0.62, 0.35)
	top.add_theme_stylebox_override("panel", top_style)
	add_child(top)

	var title := UiKit.label("Critter Clash", 54, Color("fff6ea"), "x", 8)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(16, 10)
	title.size = Vector2(632, 64)
	top.add_child(title)
	var sub := UiKit.label("Drop a twin on forest, water, or lava.", 20, Color("ffe7cf"), "b", 5)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.position = Vector2(24, 78)
	sub.size = Vector2(616, 32)
	top.add_child(sub)

	var legend := HBoxContainer.new()
	legend.position = Vector2(70, 122)
	legend.size = Vector2(524, 52)
	legend.alignment = BoxContainer.ALIGNMENT_CENTER
	legend.add_theme_constant_override("separation", 12)
	legend.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(legend)
	for pair in [["Forest", "3f9a45"], ["Water", "2f8eb8"], ["Lava", "e85a28"]]:
		var chip := PanelContainer.new()
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.add_theme_stylebox_override("panel", UiKit.panel(Color(pair[1]), 14))
		var lab := UiKit.label(pair[0], 16, Color("fff8ee"), "b", 4)
		lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.add_child(lab)
		legend.add_child(chip)

	var dock := Panel.new()
	dock.position = Vector2(70, 1280 - safe.b - 230)
	dock.size = Vector2(580, 210)
	dock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dock_style := UiKit.panel(Color(0.16, 0.08, 0.06, 0.55), 28)
	dock_style.border_color = Color(1, 0.86, 0.62, 0.28)
	dock.add_theme_stylebox_override("panel", dock_style)
	add_child(dock)

	var play := UiKit.button("Enter the Glade", 500, 86)
	play.position = Vector2(40, 16)
	play.pressed.connect(func() -> void: play_requested.emit())
	dock.add_child(play)
	var guide := UiKit.button("Field Guide", 500, 72)
	guide.position = Vector2(40, 114)
	guide.add_theme_stylebox_override("normal", UiKit.chunky(Color("d7efc4"), Color("6d8a48")))
	guide.add_theme_stylebox_override("hover", UiKit.chunky(Color("e7f8d8"), Color("6d8a48")))
	guide.add_theme_stylebox_override("pressed", UiKit.chunky(Color("c4e0ae"), Color("547038"), true))
	guide.add_theme_stylebox_override("focus", UiKit.chunky(Color("e7f8d8"), Color("6d8a48")))
	guide.pressed.connect(func() -> void: guide_requested.emit())
	dock.add_child(guide)
