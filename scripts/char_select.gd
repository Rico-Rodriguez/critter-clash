extends ScreenBase

## The character select: the front door of the game.
##
## The six classes stand in a row, the one you are looking at stands on its
## plinth in 3D wearing what you equipped it with, and BEGIN takes that
## hero into the world. The town is where the game opens after this, not
## this screen: the character you pick here is the character the town holds.

## The class the player is looking at.
var selected := ""
## The plinth with the hero on it.
var showcase: Control
## The name under the plinth.
var name_label: Label
## The role and the level under the name.
var detail_label: Label
## The gear the hero wears, in one line.
var gear_label: Label
## The roster of classes.
var list: GridContainer


func build() -> void:
	show_nav = false
	nav_tab = ""
	var pad := insets()
	# The plinth: the hero the player is looking at, in the round.
	var stage := Control.new()
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	stage.anchor_bottom = 0.46
	add_child(stage)
	showcase = Showcase.new()
	showcase.fill = 0.6
	showcase.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage.add_child(showcase)
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
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)
	box.add_child(header())
	box.add_child(h1("CHOOSE YOUR HERO"))
	name_label = UiKit.label("", 40, UiKit.GOLD.lightened(0.25), "x", 5)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(name_label)
	detail_label = body("")
	box.add_child(detail_label)
	gear_label = UiKit.label("", 18, UiKit.MUTED, "b", 1)
	gear_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gear_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(gear_label)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(spacer)
	# The roster: four across, then the rest.
	list = GridContainer.new()
	list.columns = 4
	list.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	list.add_theme_constant_override("h_separation", 14)
	list.add_theme_constant_override("v_separation", 10)
	box.add_child(list)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	var begin := UiKit.button("ENTER THE TOWN", 420, 116, "gold")
	begin.pressed.connect(_begin)
	row.add_child(begin)
	box.add_child(row)


func open(_args: Dictionary = {}) -> void:
	var owned := HeroTile.owned()
	if selected == "" or not owned.has(selected):
		selected = SaveGame.featured_id()
		if not owned.has(selected):
			selected = str(owned[0])
	_fill()


## The plinth, the plaque and the roster, for the hero being looked at.
func _fill() -> void:
	if showcase != null:
		showcase.queue_free()
	showcase = Showcase.new()
	showcase.hero_id = selected
	showcase.fill = 0.6
	showcase.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var stage := showcase.get_parent()
	if stage == null:
		stage = self.get_child(0)
	stage.add_child(showcase)
	var info := Catalog.critter(selected)
	name_label.text = str(info.get("name", "Hero")).to_upper()
	detail_label.text = "%s \u00b7 level %d" % [
		Catalog.role_name(str(info.get("role", ""))),
		int(SaveGame.hero(selected).get("level", 1)),
	]
	gear_label.text = _gear_line(selected)
	for child in list.get_children():
		child.queue_free()
	for id in HeroTile.owned():
		list.add_child(HeroTile.build(str(id), selected, _select))


## The gear the hero wears, in one line.
func _gear_line(id: String) -> String:
	var worn: Array = []
	for slot in GearDB.HERO_SLOTS.get(id, []):
		var piece := str(GearDB.equipped(id).get(str(slot), ""))
		if piece == "":
			continue
		worn.append(str(GearDB.item(piece).get("name", piece)))
	if worn.is_empty():
		return "Wearing nothing yet. The first good steel is out in the ground."
	return "Wearing " + ", ".join(worn)


func _select(id: String) -> void:
	if id == selected:
		return
	selected = id
	AudioDirector.play("click")
	_fill()


## Takes the hero into the world: the town holds this one from now on.
func _begin() -> void:
	SaveGame.set_featured(selected)
	AudioDirector.sfx("ui_tap")
	AudioDirector.haptic("medium")
	go("hub")
