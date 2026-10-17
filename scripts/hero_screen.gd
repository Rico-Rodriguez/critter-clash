extends ScreenBase

## Heroes tab: the critter you are looking at on the lit 3D plinth, framed
## hero tiles to browse, a stats plaque, then SELECT (or EQUIPPED when it is
## already the active hero) and Loadout. Home and every hunt use the
## equipped hero.

const Home := preload("res://scripts/home_screen.gd")

var biome_id := "meadow"
var selected := "ember"
var list: HBoxContainer
var detail: Label
var gear_line: Label
var stat_line: Label
var hunt: Button
var stage_slot: Control
var showcase: Control


func build() -> void:
	show_nav = true
	nav_tab = "heroes"
	var pad := insets()
	stage_slot = Control.new()
	stage_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage_slot.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	stage_slot.anchor_bottom = 0.52
	add_child(stage_slot)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", int(pad["l"]))
	margin.add_theme_constant_override("margin_right", int(pad["r"]))
	margin.add_theme_constant_override("margin_top", int(pad["t"]))
	margin.add_theme_constant_override("margin_bottom", int(pad["b"]) + 140)
	add_child(margin)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 14)
	margin.add_child(box)
	box.add_child(header())
	box.add_child(h1("Heroes"))
	detail = body("")
	box.add_child(detail)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(spacer)
	var plaque := UiKit.Plate.new()
	plaque.kind = "plaque"
	plaque.pad = 16
	plaque.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 2)
	plaque.add_child(pv)
	stat_line = UiKit.label("", 24, UiKit.GOLD.lightened(0.2), "x", 3)
	stat_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stat_line.custom_minimum_size = Vector2(620, 0)
	pv.add_child(stat_line)
	gear_line = UiKit.label("", 18, UiKit.MUTED, "m", 2)
	gear_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pv.add_child(gear_line)
	box.add_child(plaque)
	list = HBoxContainer.new()
	list.alignment = BoxContainer.ALIGNMENT_CENTER
	list.add_theme_constant_override("separation", 16)
	box.add_child(list)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	var loadout := UiKit.secondary("Loadout", 250, 96)
	loadout.pressed.connect(func() -> void: go("loadout", {"hero": selected, "biome": biome_id}))
	hunt = UiKit.button("SELECT", 440, 110, "gold")
	hunt.pressed.connect(func() -> void:
		if selected == SaveGame.featured_id():
			return
		SaveGame.set_featured(selected)
		AudioDirector.sfx("card_pick")
		AudioDirector.haptic("medium")
		toast("%s is now your hero" % str(Catalog.critter(selected)["name"]))
		_fill()
	)
	row.add_child(loadout)
	row.add_child(hunt)
	box.add_child(row)


func open(args: Dictionary = {}) -> void:
	biome_id = str(args.get("biome", "meadow"))
	detail.text = "Tap a hero to look, then Select. Home and hunts use your equipped hero."
	selected = SaveGame.featured_id()
	if not bool(SaveGame.hero(selected)["unlocked"]):
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
		list.add_child(_tile(id))
	if showcase != null:
		showcase.queue_free()
	showcase = Home.Showcase.new()
	showcase.hero_id = selected
	showcase.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage_slot.add_child(showcase)
	var info := Catalog.critter(selected)
	var stats := SaveGame.build_run_stats(selected)
	var equipped := selected == SaveGame.featured_id()
	hunt.text = "✓ EQUIPPED" if equipped else "SELECT"
	hunt.disabled = equipped
	hunt.modulate = Color(0.85, 0.95, 0.8) if equipped else Color.WHITE
	stat_line.text = "%s  ·  %s" % [str(info["name"]).to_upper(), Catalog.role_name(str(info["role"])).to_upper()]
	gear_line.text = "Health %d   ·   Damage %d\n%s" % [
		int(round(float(stats["hp"]))),
		int(round(float(stats["dmg"]))),
		SaveGame.equipped_line(selected),
	]


func _tile(id: String) -> Control:
	var info := Catalog.critter(id)
	var row := SaveGame.hero(id)
	var on := id == selected
	var rarity := UiKit.hero_rarity(id)
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.flat = true
	b.custom_minimum_size = Vector2(196, 230)
	var empty := StyleBoxEmpty.new()
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(st, empty)
	var metal := UiKit.rarity_metal(rarity) if not on else [Color("ffe6a8"), Color("6a4416")]
	var frame := UiKit.Frame.new("card", "leather", {
		"metal_hi": metal[0], "metal_lo": metal[1], "frame": 6.0 if on else 4.0,
		"glow_color": Color(1.0, 0.72, 0.3, 0.55) if on else Color(0, 0, 0, 0),
		"face_top": Color("2a2016") if on else Color("16110d"), "face_bot": Color("0c0907"),
	})
	frame.margin = 2.0
	b.add_child(frame)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 4)
	b.add_child(v)
	var medal := UiKit.Medal.new()
	medal.tex = SpriteBank.head(id)
	medal.custom_minimum_size = Vector2(112, 112)
	medal.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(medal)
	var n := UiKit.label(str(info["name"]).to_upper(), 20, UiKit.GOLD.lightened(0.2) if on else UiKit.CREAM, "x", 3)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(n)
	var l := UiKit.label("Level %d" % int(row["level"]), 17, UiKit.MUTED, "m", 2)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	if id == SaveGame.featured_id():
		var tag := UiKit.label("EQUIPPED", 15, Color("9fe08a"), "x", 3)
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(tag)
	if not on:
		b.modulate = Color(0.78, 0.78, 0.78)
	b.pressed.connect(_select.bind(id))
	return b


func _select(id: String) -> void:
	if id == selected:
		return
	selected = id
	AudioDirector.play("click")
	_fill()
