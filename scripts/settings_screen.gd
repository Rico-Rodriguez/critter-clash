extends ScreenBase

## Settings: sound, haptics and the comfort/accessibility options. Every
## change applies and saves immediately; the panel scrolls so each new
## control can stay at least 88 device px tall on a 1179-wide phone.


func build() -> void:
	show_nav = true
	nav_tab = ""
	var box := column()
	box.add_child(header())
	box.add_child(h1("Settings"))
	box.add_child(body("Sound, comfort and text options. Changes save straight away."))
	var pad := MarginContainer.new()
	for side in ["left", "right"]:
		pad.add_theme_constant_override("margin_" + side, 18)
	pad.add_theme_constant_override("margin_top", 16)
	pad.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pad.add_child(sc)
	sc.add_child(SettingsPanel.new())
	box.add_child(pad)
	var credits := UiKit.secondary("CREDITS", 300, 72)
	credits.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	credits.pressed.connect(go.bind("credits", {}))
	box.add_child(credits)
	box.add_child(back_button("home"))
