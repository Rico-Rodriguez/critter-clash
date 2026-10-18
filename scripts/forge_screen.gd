class_name ForgeScreen
extends ScreenBase

## The Forge: spend gear shards, earned from duplicate rolls, to craft an
## unowned piece the hero has not been handed yet. Only tiers the player can
## already drop at their deepest open biome are listed; deeper ground (Mushroom
## for steel, Frost for rune) is named below so the goal stays visible. The
## hero switcher is view-only, like Skills: it never writes the featured hero.

var _content: VBoxContainer
var _shards: Label
## The hero the page is showing. Empty follows the featured hero; the switcher
## only moves this local view and never writes the save (TASK).
var _view_hero := ""


## The hero whose forge list is on screen.
func view_id() -> String:
	if _view_hero != "" and SaveGame.data["heroes"].has(_view_hero):
		return _view_hero
	return SaveGame.featured_id()


## View-only pick: records which hero the page shows and returns the new id.
## Unlocked heroes only. Never touches SaveGame.data["featured"].
func set_view(id: String) -> String:
	if SaveGame.data["heroes"].has(id) and bool(SaveGame.hero(id)["unlocked"]):
		_view_hero = id
	return view_id()


func build() -> void:
	show_nav = true
	nav_tab = ""
	var box := column()
	box.add_child(header_with_back("home"))
	box.add_child(h1("The Forge"))
	_shards = UiKit.label("", 26, UiKit.GOLD.lightened(0.15), "x", 5)
	_shards.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_shards)
	# The list can run long once a hero owns most of a tier, so it scrolls;
	# the header and the shard line stay put.
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 16)
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_content)
	_refresh()


func _refresh() -> void:
	_shards.text = "Shards %d" % int(SaveGame.data.get("gear_shards", 0))
	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()
	var hero := view_id()
	_content.add_child(body("Duplicate gear melts into shards. Spend them here on a piece this hero has not found yet."))
	_content.add_child(_hero_switcher(hero))
	var options: Array = SaveGame.forge_options(hero)
	if options.is_empty():
		_content.add_child(_empty_state())
		_content.add_child(_locked_footnote(hero))
		return
	# One group per forgeable tier, best first, each a header over its rows.
	for tier in range(SaveGame.forge_cap(), GearDB.Tier.IRON - 1, -1):
		var rows: Array = []
		for o in options:
			if int(o["tier"]) == tier:
				rows.append(o)
		if rows.is_empty():
			continue
		_content.add_child(_tier_header(tier))
		for o in rows:
			_content.add_child(_option_row(o))
	_content.add_child(_locked_footnote(hero))


## One chip per unlocked hero: the shown one is the gold primary, the rest are
## secondary steel. Tapping is view-only and redraws the list.
func _hero_switcher(current: String) -> Control:
	var row := HFlowContainer.new()
	row.alignment = FlowContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("h_separation", 10)
	row.add_theme_constant_override("v_separation", 10)
	for id in Catalog.playable_ids():
		if not bool(SaveGame.hero(str(id))["unlocked"]):
			continue
		var name := str(Catalog.critter(str(id)).get("name", id)).to_upper()
		var on := str(id) == current
		var button := UiKit.button(name, 150, 82) if on else UiKit.secondary(name, 150, 82)
		button.toggle_mode = true
		button.set_pressed_no_signal(on)
		button.pressed.connect(func() -> void: _pick_hero(str(id)))
		row.add_child(button)
	return row


func _pick_hero(id: String) -> void:
	if id == view_id():
		return
	set_view(id)
	AudioDirector.sfx("card_pick")
	AudioDirector.haptic("medium")
	_refresh()


func _tier_header(tier: int) -> Control:
	var l := UiKit.label(GearDB.TIER_NAMES[tier].to_upper(), 24, GearDB.TIER_COLORS[tier].lightened(0.15), "x", 4)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


## One forgeable piece: name, slot in plain words and the wear requirement, the
## shard cost and an 88 px FORGE button that greys out with its reason when the
## wallet is short.
func _option_row(opt: Dictionary) -> Control:
	var plate := UiKit.Plate.new()
	plate.kind = "plaque"
	plate.pad = 16
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	plate.add_child(row)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 4)
	row.add_child(col)
	var it := GearDB.item(str(opt["id"]))
	col.add_child(UiKit.label(str(it.get("name", "")).to_upper(), 28, Color("fff1d6"), "x", 5))
	var line := PackedStringArray()
	line.append(_slot_words(str(opt["slot"])))
	var req := GearDB.requirements(str(opt["id"]))
	if not req.is_empty() and not str(opt["reason"]).begins_with("Requires"):
		line.append(_req_text(req))
	col.add_child(UiKit.label(" · ".join(line), 20, UiKit.MUTED, "b", 3))
	if not bool(opt["ok"]):
		col.add_child(UiKit.label(str(opt["reason"]), 20, Color("d8a0a0"), "b", 3))
	var right := VBoxContainer.new()
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	right.add_theme_constant_override("separation", 8)
	row.add_child(right)
	right.add_child(UiKit.label("%d SHARDS" % int(opt["cost"]), 22, UiKit.GOLD.lightened(0.15), "x", 3))
	var forge := UiKit.button("FORGE", 190, 88)
	# Set before the button enters the tree so its forged skin builds in the
	# grey tone and the caption dims with it (UiKit.Btn reads disabled in _ready).
	forge.disabled = not bool(opt["ok"])
	forge.pressed.connect(_do_forge.bind(str(opt["id"])))
	right.add_child(forge)
	return plate


## A plain-words slot name ("Off-hand" rather than "offhand").
func _slot_words(slot: String) -> String:
	var i := GearDB.SLOT_KEYS.find(slot)
	return GearDB.SLOT_NAMES[i] if i >= 0 else slot


## "Requires Defence 20" restated for the forge: "Wear at Defence 20".
func _req_text(req: Dictionary) -> String:
	var parts := PackedStringArray()
	for k in GearDB.SKILL_KEYS:
		if req.has(k):
			parts.append("%s %d" % [GearDB.SKILL_NAMES[GearDB.SKILL_KEYS.find(k)], int(req[k])])
	return "Wear at " + ", ".join(parts)


func _locked_footnote(hero: String) -> Control:
	var lines := PackedStringArray()
	for tier in range(GearDB.Tier.IRON + 1, GearDB.Tier.RUNE + 1):
		var reason := SaveGame.forge_lock_reason(tier)
		if reason == "":
			continue
		for slot in GearDB.HERO_SLOTS.get(hero, []):
			if not GearDB.has(hero, GearDB.item_id(hero, str(slot), tier)):
				lines.append(reason)
				break
	if lines.is_empty():
		return Control.new()
	var l := UiKit.label(" · ".join(lines), 19, UiKit.MUTED, "b", 3)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _empty_state() -> Control:
	var l := body("Every piece you can forge is already yours.")
	l.add_theme_color_override("font_color", UiKit.MUTED)
	return l


func _do_forge(id: String) -> void:
	if SaveGame.forge(view_id(), id):
		AudioDirector.sfx("card_pick")
		AudioDirector.haptic("medium")
		toast("Forged %s" % str(GearDB.item(id).get("name", "")))
	else:
		AudioDirector.sfx("ui_error")
		AudioDirector.haptic("light")
	_refresh()
