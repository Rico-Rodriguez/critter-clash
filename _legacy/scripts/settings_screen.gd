extends ScreenBase

## Settings: sound, haptics and the comfort/accessibility options. Every
## change applies and saves immediately; the panel scrolls so each new
## control can stay at least 88 device px tall on a 720-wide phone.


func build() -> void:
	show_nav = true
	nav_tab = ""
	var box := column()
	box.add_child(header_with_back("hub"))
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
	var panel := SettingsPanel.new()
	# Fill the scroll width so the rows span the screen like every other menu.
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(panel)
	box.add_child(pad)
	# Credits stays reachable; the back chip up top now leads home, so no
	# duplicate bottom Back button.
	var credits := UiKit.secondary("CREDITS", 300, 88)
	credits.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	credits.pressed.connect(go.bind("credits", {}))
	box.add_child(credits)
	var ver := UiKit.label(build_line(get_node_or_null("/root/Ota")), 20, UiKit.MUTED, "b", 3)
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(ver)


## "v1.1.0 · Build 212" plus the content pack when one is mounted, e.g.
## "v1.1.0 · Build 212 · Content 230", and a staged pack waiting for relaunch.
static func build_line(ota: Node) -> String:
	var text := "v%s" % str(ProjectSettings.get_setting("application/config/version", ""))
	if ota == null:
		return text + " · Build %d" % int(ProjectSettings.get_setting("ota/build", 0))
	text += " · Build %d" % int(ota.get("baked_build"))
	if int(ota.get("ota_build")) > 0:
		text += " · Content %d" % int(ota.get("ota_build"))
	if int(ota.get("pending_build")) > 0:
		text += " · %d ready on relaunch" % int(ota.get("pending_build"))
	return text
