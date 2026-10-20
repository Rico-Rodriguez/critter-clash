class_name ForgeScreen
extends ScreenBase

## The Forge: spend gear shards, earned from duplicate rolls, to craft an
## unowned piece the hero has not been handed yet. Only tiers the player can
## already drop at their deepest open biome are listed; deeper ground (Mushroom
## for steel, Frost for rune) is named below so the goal stays visible. The
## hero switcher is view-only, like Skills: it never writes the featured hero.

var _content: VBoxContainer
var _shards: Label
## The list's scroll box, held so a forge can keep the player's place.
var _scroll: ScrollContainer
## The slot to glow after a forge, so the player sees the row that takes the
## forged piece's place. Cleared once a refresh has applied it.
var _highlight_slot := ""
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
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(_scroll)
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 16)
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_content)
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
		_highlight_slot = ""
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
			var plate := _option_row(o)
			# The row that replaces a just-forged piece gets a steady gold
			# glow, then fades (no flashing).
			if _highlight_slot != "" and str(o["slot"]) == _highlight_slot:
				plate.glow = Color(UiKit.GOLD.r, UiKit.GOLD.g, UiKit.GOLD.b, 0.55)
				_highlight_slot = ""
			_content.add_child(plate)
			if plate.glow.a > 0.0:
				_fade_glow.call_deferred(plate)
	_content.add_child(_locked_footnote(hero))
	_highlight_slot = ""


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


## One forgeable piece: name, slot in plain words and the wear requirement, a
## short stat line, the shard cost and an 88 px FORGE button that greys out with
## its reason when the wallet is short.
func _option_row(opt: Dictionary) -> UiKit.Plate:
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
	var worn: String = str(GearDB.equipped(view_id()).get(str(opt["slot"]), ""))
	var stats := stat_line(str(opt["id"]), worn)
	if stats != "":
		col.add_child(UiKit.label(stats, 19, UiKit.MUTED, "m", 3))
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
	var owned: Dictionary = GearDB._store()["owned"].get(hero, {})
	for tier in range(GearDB.Tier.IRON + 1, GearDB.Tier.RUNE + 1):
		var reason := SaveGame.forge_lock_reason(tier)
		if reason == "":
			continue
		for slot in GearDB.HERO_SLOTS.get(hero, []):
			var owns_any := false
			for oid in owned:
				if int(owned[oid]) > 0:
					var p := GearDB._parse_id(str(oid))
					if not p.is_empty() and p["slot"] == slot and int(p["tier"]) == tier:
						owns_any = true
						break
			if not owns_any:
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


## The stat line for one forgeable piece: its own stats worded like the rest of
## the game, or the gain over the piece the hero already wears in that slot
## ("+7 HP  +1 armour over Iron Horned Helm"). Wording and order come from
## EquipUI.stat_text so the Forge never invents a second stat language.
static func stat_line(id: String, worn_id: String) -> String:
	var it := GearDB.item(id)
	if it.is_empty():
		return ""
	var stats: Dictionary = it["stats"]
	# Only an upgrade reads as a gain; a piece at or below the worn tier just
	# states its own stats (stat_text prints every value with a "+").
	if worn_id == "" or not GearDB.is_item(worn_id) or int(GearDB.item(worn_id)["tier"]) >= int(it["tier"]):
		return EquipUI.stat_text(stats)
	var worn: Dictionary = GearDB.item(worn_id)["stats"]
	var gain := {}
	for k in stats:
		var d: float = float(stats[k]) - float(worn.get(k, 0))
		if d > 0.0:
			gain[k] = d
	if gain.is_empty():
		return EquipUI.stat_text(stats)
	return "%s over %s" % [EquipUI.stat_text(gain), str(GearDB.item(worn_id)["name"])]


## Fades a just-forged row's steady gold glow out once, so it reads as a
## moment rather than a blink.
func _fade_glow(plate: UiKit.Plate) -> void:
	if not is_instance_valid(plate) or plate.skin == null:
		return
	var gold := UiKit.GOLD
	var tw := plate.create_tween()
	tw.tween_interval(1.1)
	tw.tween_method(func(a: float) -> void:
		if is_instance_valid(plate) and plate.skin != null:
			plate.skin.set_param("glow_color", Color(gold.r, gold.g, gold.b, a)), 0.55, 0.0, 0.6)


## Puts the list back where it was before a refresh rebuilt it.
func _restore_scroll(to: int) -> void:
	if _scroll != null:
		_scroll.scroll_vertical = to


func _do_forge(id: String) -> void:
	var keep := _scroll.scroll_vertical if _scroll != null else 0
	if SaveGame.forge(view_id(), id):
		AudioDirector.sfx("card_pick")
		AudioDirector.haptic("medium")
		toast("Forged %s" % str(GearDB.item(id).get("name", "")))
		_highlight_slot = str(GearDB.item(id)["slot"])
	else:
		AudioDirector.sfx("ui_error")
		AudioDirector.haptic("light")
	_refresh()
	# The rebuilt list lays out on the next frame, so the scroll lands after it.
	_restore_scroll.call_deferred(keep)
