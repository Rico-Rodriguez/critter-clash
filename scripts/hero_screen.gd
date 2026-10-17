extends ScreenBase

## Choose a hero: the selected critter on the lit 3D plinth, framed hero
## tiles to pick from, a stats plaque, then Loadout and Hunt.

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
	margin.add_theme_constant_override("margin_bottom", int(pad["b"]))
	add_child(margin)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 14)
	margin.add_child(box)
	box.add_child(header())
	box.add_child(h1("Choose a hero"))
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
	hunt = UiKit.button("HUNT", 440, 110, "gold")
	hunt.pressed.connect(func() -> void:
		SaveGame.set_featured(selected)
		go("run", {"biome": biome_id, "hero": selected})
	)
	row.add_child(loadout)
	row.add_child(hunt)
	box.add_child(row)
	box.add_child(back_button("world"))


func open(args: Dictionary = {}) -> void:
	biome_id = str(args.get("biome", "meadow"))
	var biome := Catalog.biome(biome_id)
	detail.text = "%s  ·  guarded by %s" % [str(biome["name"]), str(Catalog.critter(str(biome["boss"]))["name"])]
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
	hunt.text = "HUNT"
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
