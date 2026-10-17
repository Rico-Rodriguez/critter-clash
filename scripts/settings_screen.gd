extends ScreenBase

## Settings: music, sound effects and haptics.


func build() -> void:
	show_nav = true
	nav_tab = ""
	var box := column()
	box.add_child(header())
	box.add_child(h1("Settings"))
	box.add_child(body("Sound and touch feedback. Changes save straight away."))
	var pad := MarginContainer.new()
	for side in ["left", "right"]:
		pad.add_theme_constant_override("margin_" + side, 18)
	pad.add_theme_constant_override("margin_top", 16)
	box.add_child(pad)
	pad.add_child(SettingsPanel.new())
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)
	var credits := UiKit.secondary("CREDITS", 300, 72)
	credits.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	credits.pressed.connect(go.bind("credits", {}))
	box.add_child(credits)
	box.add_child(back_button("home"))
