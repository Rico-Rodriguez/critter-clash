extends RefCounted
## The Pets tab: stable (your companion on stage, the roster), hatchery,
## breeding, collection and showcase as five segments of one page. The
## builders live partly here (stable, showcase, rename) and partly in
## lobby_ui_sheets.gd (hatchery, breeding, collection, a pet's detail page),
## which this file drives. `ui` is the LobbyUI.

const SKS := preload("res://src/autoload/sidekicks.gd")
const SKDB := preload("res://src/data/sidekick_db.gd")
const Care := preload("res://src/core/pet_care.gd")
const PetStage := preload("res://src/lobby/pet_stage.gd")
const PetIcons := preload("res://src/ui/pet_icons.gd")
const FxUi := preload("res://src/ui/fx_ui.gd")


static func segments(ui) -> Array:
	return [
		["Stable", func(s: Sheet): build_stable(ui, s)],
		["Eggs", func(s: Sheet): build_hatchery(ui, s), egg_ready()],
		["Breed", func(s: Sheet): ui._build_breeding(s)],
		["Album", func(s: Sheet): ui._build_collection(s)],
		["Podium", func(s: Sheet): build_showcase(ui, s)],
	]


static func egg_ready() -> bool:
	var now := int(Time.get_unix_time_from_system())
	return SKS.hatchery(Game.data).any(func(e): return SKS.egg_ready(e, now))


## The tab's badge: an egg is ready to hatch.
static func dot() -> bool:
	return egg_ready()


# --- Stable ------------------------------------------------------------------

## Who is at your side, on a stage; the roster below. A pet's tile opens its page.
static func build_stable(ui, s: Sheet) -> void:
	if str(ui._sk_detail) != "" and SKS.is_owned(Game.data, str(ui._sk_detail)):
		ui._build_sidekick_detail(s, str(ui._sk_detail))
		return
	ui._sk_detail = ""
	var b := s.body
	var a := SKS.active(Game.data)
	if a == "":
		b.add_child(_empty_side())
	else:
		_side_card(ui, s, a)
	var owned: int = SKDB.ORDER.filter(func(i): return SKS.is_owned(Game.data, i)).size() + SKS.bred_ids(Game.data).size()
	b.add_child(Ui.label("STABLE · %d / %d" % [owned, SKDB.ORDER.size() + SKS.bred_ids(Game.data).size()], "Caption"))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	for id: String in SKDB.ORDER:
		grid.add_child(ui._sidekick_tile(s, id))
	for id: String in SKS.bred_ids(Game.data):
		grid.add_child(ui._sidekick_tile(s, id))
	b.add_child(grid)
	FxUi.deal_in(grid, 0.04)


static func _empty_side() -> Control:
	var c: PanelContainer = PanelContainer.new()
	c.theme_type_variation = &"Card"
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 6)
	var ic := Ui.icon_rect("egg-clutch", 96, Color(1, 1, 1, 0.3))
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(ic)
	var none := (Game.data["sidekicks"]["owned"] as Dictionary).is_empty()
	var l := Ui.label("No pet yet. Slay your first boss: the Grave Wisp follows the victor." if none else "No one at your side. Pick a pet from your stable.", "Body", HORIZONTAL_ALIGNMENT_CENTER)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(l)
	c.add_child(v)
	c.custom_minimum_size = Vector2(0, 220)
	return c


## The companion at your side: stage, name (rename), role line and Bond.
static func _side_card(ui, s: Sheet, id: String) -> void:
	var b := s.body
	var d: Dictionary = SKDB.def(id)
	var k := SKS.kills(Game.data, id)
	var lv := SKDB.bond_level(k)
	b.add_child(PetStage.make(id, 400))
	var name_l := Ui.label(ui._pet_name(id), "Title")
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_l.clip_text = true
	b.add_child(ui._row([name_l, rename_button(ui, id, func():
		ui._refresh_camp_sidekick()
		s.rebuild())], 10))
	var rar := SKDB.rarity(id)
	var sub := Ui.label("%s · %s · Bond %d · %s" % [SKDB.GRADES[rar].to_upper(), str(d["element"]).capitalize(), lv, SKDB.STAGE_LABELS[SKDB.stage_of(lv)]], "Caption")
	sub.add_theme_color_override("font_color", SKDB.GRADE_COLORS[rar])
	b.add_child(sub)
	var line := Ui.label("%s · %s" % [d["ability"]["name"], d["desc"]], "Small")
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.add_child(line)
	var btn := Button.new()
	btn.theme_type_variation = &"GoldButton"
	btn.text = "DETAILS"
	btn.focus_mode = Control.FOCUS_NONE
	btn.custom_minimum_size = Vector2(0, 68)
	btn.pressed.connect(func():
		Sfx.play("ui_tap", -4.0)
		ui._sk_detail = id
		s.rebuild())
	b.add_child(btn)


# --- Hatchery ----------------------------------------------------------------

static func build_hatchery(ui, s: Sheet) -> void:
	var b := s.body
	var info := Ui.label("Eggs warm in the nest by the clock or by kills in hunts, whichever comes first. Gems finish one right now.", "Small")
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.add_child(info)
	ui._build_hatchery(s)
	build_egg_shop(ui, s)


# --- Egg shop ----------------------------------------------------------------

## The rotating shelf under the hatchery: three daily offers and a weekly
## feature (EggShop via Game.egg_shop()). A buy lays the egg in the hatchery.
static func build_egg_shop(ui, s: Sheet) -> void:
	var b := s.body
	var offers: Array = Game.egg_shop()
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 6)
	b.add_child(gap)
	var daily := int(offers[0]["left"])
	var weekly := int(offers[offers.size() - 1]["left"])
	b.add_child(ui._row([Ui.label("EGG SHOP", "Caption"), ui._spacer(), Ui.icon_rect("two-coins", 26, Color(1.0, 0.84, 0.4)), Ui.label("%d" % Game.gold(), "Value")], 8))
	var info := Ui.label("Fresh eggs every day, one rare feature every week. Daily offers turn in %s · the feature in %s." % [_span(daily), _span(weekly)], "Small")
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.add_child(info)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	for of: Dictionary in offers:
		grid.add_child(_offer_card(ui, s, of))
	b.add_child(grid)
	FxUi.deal_in(grid, 0.06)


static func _span(secs: int) -> String:
	if secs >= 86400:
		return "%dd %dh" % [secs / 86400, (secs % 86400) / 3600]
	if secs >= 3600:
		return "%dh %02dm" % [secs / 3600, (secs % 3600) / 60]
	return "%dm" % maxi(secs / 60, 1)


## What an egg hatches, in one line.
static func egg_blurb(kind: String) -> String:
	var ed: Dictionary = SKDB.EGGS[kind]
	if ed.has("hatches"):
		return "Always a %s" % str(SKDB.ROSTER[str(ed["hatches"])]["name"])
	var mut := SKDB.MUTATION_BASE * float(ed.get("mut", 1.0))
	return "A random pet · %.1f%% mutation" % (mut * 100.0)


static func _offer_card(ui, s: Sheet, of: Dictionary) -> Control:
	var kind := str(of["egg"])
	var ed: Dictionary = SKDB.EGGS[kind]
	var col: Color = ed["color"]
	var sold := bool(of["sold"])
	var c: PanelContainer = ui._card()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.custom_minimum_size = Vector2(0, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	var tag := Ui.label("WEEKLY FEATURE" if bool(of["weekly"]) else str(ed["rarity"]).to_upper(), "Caption")
	tag.add_theme_color_override("font_color", Color(1.0, 0.82, 0.4) if bool(of["weekly"]) else col.lightened(0.2))
	v.add_child(tag)
	var egg := Ui.icon_rect("egg-clutch", 64, col)
	egg.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(egg)
	if bool(of["weekly"]) and not sold:
		FxUi.bob(egg, 5.0, 2.2)
	var nm := Ui.label(str(ed["name"]), "Body")
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(nm)
	var blurb := Ui.label(egg_blurb(kind), "Small")
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	blurb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(blurb)
	var go := Button.new()
	go.focus_mode = Control.FOCUS_NONE
	go.theme_type_variation = &"GoldButton"
	go.add_theme_font_size_override("font_size", 24)
	go.clip_text = true
	var gems := str(of["cur"]) == "gems"
	go.text = "SOLD" if sold else "%d %s" % [int(of["price"]), "gems" if gems else "gold"]
	go.icon = Ui.icon("gems" if gems else "two-coins")
	go.expand_icon = true
	var why := str(of["why"])
	go.disabled = why != ""
	if why != "" and not sold:
		go.tooltip_text = why
	var slot := int(of["slot"])
	go.pressed.connect(func():
		var got: Dictionary = Game.buy_egg(slot)
		if got.is_empty():
			return
		FxUi.pop(egg)
		ui._toast("%s laid in your hatchery" % str(SKDB.EGGS[str(got["egg"])]["name"]), SKDB.EGGS[str(got["egg"])]["color"])
		s.rebuild())
	v.add_child(go)
	if why != "" and not sold:
		var note := Ui.label(why, "Small")
		note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		note.add_theme_color_override("font_color", Color(0.9, 0.55, 0.5))
		v.add_child(note)
	if sold:
		c.modulate = Color(1, 1, 1, 0.55)
	c.add_child(v)
	return c


# --- Showcase ----------------------------------------------------------------

## Your three best on a podium, and every pet you own to pin or unpin.
static func build_showcase(ui, s: Sheet) -> void:
	var b := s.body
	var picks: Array = SKS.showcase(Game.data)
	var info := Ui.label("Pin up to %d pets to show them off. Unpinned slots fill with your rarest." % SKDB.SHOWCASE_SLOTS, "Small")
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.add_child(info)
	if picks.is_empty():
		b.add_child(_empty_side())
		return
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	for id: String in picks:
		row.add_child(_podium_card(ui, s, id))
	b.add_child(row)
	FxUi.deal_in(row, 0.06)
	b.add_child(Ui.label("PIN A PET", "Caption"))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	for id: String in SKDB.ORDER + SKS.bred_ids(Game.data):
		if SKS.is_owned(Game.data, id):
			grid.add_child(_pin_tile(ui, s, id))
	b.add_child(grid)


static func _podium_card(ui, s: Sheet, id: String) -> Control:
	var d: Dictionary = SKDB.def(id)
	var rar := SKDB.rarity(id)
	var gc: Color = SKDB.GRADE_COLORS[rar]
	var btn := Button.new()
	btn.focus_mode = Control.FOCUS_NONE
	btn.theme_type_variation = &"Ghost"
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size = Vector2(0, 200)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(gc, 0.14)
	sb.border_color = Color(gc, 0.9 if rar >= 2 else 0.5)
	sb.set_border_width_all(3 if rar >= 3 else 2)
	sb.set_corner_radius_all(14)
	for st in ["normal", "hover", "pressed", "focus"]:
		btn.add_theme_stylebox_override(st, sb)
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 2)
	var ic := CenterContainer.new()
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ic.add_child(PetIcons.rect(id, SKS.stage(Game.data, id), 108))
	v.add_child(ic)
	var nm := Ui.label(ui._pet_name(id), "Small", HORIZONTAL_ALIGNMENT_CENTER)
	nm.clip_text = true
	nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(nm)
	var gl := Ui.label(SKDB.GRADES[rar].to_upper() + (" ★" if SKS.is_pinned(Game.data, id) else ""), "Caption", HORIZONTAL_ALIGNMENT_CENTER)
	gl.add_theme_color_override("font_color", gc)
	gl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(gl)
	btn.add_child(v)
	btn.pressed.connect(func():
		Sfx.play("ui_tap", -4.0)
		ui._sk_detail = id
		s.show_segment(0))
	return btn


static func _pin_tile(ui, s: Sheet, id: String) -> Control:
	var d: Dictionary = SKDB.def(id)
	var pinned := SKS.is_pinned(Game.data, id)
	var full := (Game.data["sidekicks"]["showcase"] as Array).size() >= SKDB.SHOWCASE_SLOTS
	var tile: Button = ui._sk_tile_box(str(d["icon"]), Color(d["color"]), ("★ " if pinned else "") + str(ui._pet_name(id)),
			"Pinned · tap to unpin" if pinned else ("Showcase is full" if full else "Tap to pin"), -1.0, not pinned and full, func():
		if not SKS.pin(Game.data, id):
			Sfx.play("ui_error", -6.0)
			return
		Sfx.play("ui_toggle", -4.0)
		Game.save()
		s.rebuild(), id)
	tile.disabled = not pinned and full
	return tile


# --- Renaming ----------------------------------------------------------------

static func rename_button(ui, id: String, done: Callable) -> Button:
	var btn := Button.new()
	btn.theme_type_variation = &"Ghost"
	btn.text = "RENAME"
	btn.focus_mode = Control.FOCUS_NONE
	btn.custom_minimum_size = Vector2(150, 62)
	btn.add_theme_font_size_override("font_size", 22)
	btn.pressed.connect(func():
		Sfx.play("ui_tap", -4.0)
		rename(ui, id, done))
	return btn


## The naming dialog: a field with a live count and a reason when the name
## won't do. Saving an empty name goes back to the breed name.
static func rename(ui, id: String, done: Callable) -> Control:
	var host: Control = ui.get_node("%Overlay")
	var layer := Control.new()
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_STOP
	host.add_child(layer)
	var scrim := ColorRect.new()
	scrim.color = Color(0, 0, 0, 0.62)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(scrim)
	var d: Dictionary = SKDB.def(id)
	var breed := SKDB.display_name(id, SKS.kills(Game.data, id))
	var cur := Care.nickname(Game.data, id)
	var close := func():
		var t := layer.create_tween().set_parallel(true)
		t.tween_property(layer, "modulate:a", 0.0, 0.15)
		t.chain().tween_callback(layer.queue_free)
	scrim.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed:
			close.call())
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"Card"
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.14
	panel.anchor_bottom = 0.14
	panel.offset_left = -310.0
	panel.offset_right = 310.0
	panel.grow_vertical = Control.GROW_DIRECTION_END
	layer.add_child(panel)
	var m := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		m.add_theme_constant_override(side, 22)
	panel.add_child(m)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	m.add_child(v)
	v.add_child(ui._row([PetIcons.rect(id, SKS.stage(Game.data, id), 72), Ui.label("Name your %s" % str(d["name"]), "Heading")], 12))
	var hint := Ui.label("%d to %d letters, numbers, spaces, ' - and ." % [Care.NAME_MIN, Care.NAME_MAX], "Small")
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(hint)
	var le := LineEdit.new()
	le.name = "NameField"
	le.text = cur
	le.placeholder_text = breed
	le.max_length = Care.NAME_MAX
	le.custom_minimum_size = Vector2(0, 76)
	le.add_theme_font_size_override("font_size", 32)
	le.alignment = HORIZONTAL_ALIGNMENT_CENTER
	le.select_all_on_focus = true
	v.add_child(le)
	var meta := HBoxContainer.new()
	var err := Ui.label("", "Small")
	err.name = "NameError"
	err.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	err.add_theme_color_override("font_color", Color(1.0, 0.5, 0.45))
	meta.add_child(err)
	var count := Ui.label("", "Small", HORIZONTAL_ALIGNMENT_RIGHT)
	meta.add_child(count)
	v.add_child(meta)
	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 12)
	var cancel := Button.new()
	cancel.theme_type_variation = &"Ghost"
	cancel.text = "CANCEL"
	cancel.focus_mode = Control.FOCUS_NONE
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel.custom_minimum_size = Vector2(0, 68)
	cancel.pressed.connect(func():
		Sfx.play("ui_back", -4.0)
		close.call())
	btns.add_child(cancel)
	var save := Button.new()
	save.name = "SaveName"
	save.theme_type_variation = &"GoldButton"
	save.focus_mode = Control.FOCUS_NONE
	save.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save.custom_minimum_size = Vector2(0, 68)
	btns.add_child(save)
	v.add_child(btns)
	var check := func(text: String):
		var r := Care.check_name(text)
		count.text = "%d / %d" % [text.strip_edges().length(), Care.NAME_MAX]
		err.text = str(r["err"])
		var same := str(r["name"]) == cur
		save.text = "SAVE" if str(r["name"]) != "" else ("RESET NAME" if cur != "" else "SAVE")
		save.disabled = not bool(r["ok"]) or same
	var commit := func():
		if save.disabled:
			Sfx.play("ui_error", -6.0)
			return
		if not Care.set_name(Game.data, id, le.text):
			return
		Game.save()
		Sfx.play("gear_equip", -3.0)
		close.call()
		done.call()
	le.text_changed.connect(check)
	le.text_submitted.connect(func(_t: String): commit.call())
	save.pressed.connect(commit)
	check.call(cur)
	# Pops in near the top, clear of the on-screen keyboard.
	panel.pivot_offset = Vector2(310, 40)
	panel.scale = Vector2.ONE * 0.9
	layer.modulate.a = 0.0
	var tw := layer.create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(layer, "modulate:a", 1.0, 0.16)
	tw.tween_property(panel, "scale", Vector2.ONE, 0.26)
	le.grab_focus.call_deferred()
	return layer
