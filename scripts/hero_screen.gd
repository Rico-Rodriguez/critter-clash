extends ScreenBase

## Heroes tab, the one place for heroes and gear: the knight on the lit 3D
## plinth framed by the eight GearDB sockets, a plaque with the card level
## (shards bar, stat preview current -> next) and UPGRADE with its coin cost,
## framed hero tiles to browse, then SELECT (or EQUIPPED). Home and every hunt
## use the equipped hero.

const Home := preload("res://scripts/home_screen.gd")
const StatsPanel := preload("res://scripts/stats_panel.gd")

var biome_id := "meadow"
var selected := "ember"
var list: GridContainer
var detail: Label
var gear_line: Label
var stat_line: Label
var hunt: Button
var stage_slot: Control
var showcase: Control
var sockets: Array = []
var card_bar: CardBar
var preview_line: Label
var upgrade: Button
var price: PriceTag
var stats_panel: StatsPanel


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
	preview_line = UiKit.label("", 22, UiKit.CREAM, "b", 2)
	preview_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pv.add_child(preview_line)
	card_bar = CardBar.new()
	card_bar.custom_minimum_size = Vector2(560, 40)
	card_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	pv.add_child(card_bar)
	gear_line = UiKit.label("", 18, UiKit.MUTED, "m", 2)
	gear_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pv.add_child(gear_line)
	box.add_child(plaque)
	# Collapsed Stats and Training header under the plaque, in normal page
	# flow below the 3D stage (the spacer above pushed everything down).
	stats_panel = StatsPanel.new()
	stats_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(stats_panel)
	# Three tiles a row: six unlocked heroes wrap to two rows instead of
	# running off the screen.
	list = GridContainer.new()
	list.columns = 4
	list.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	list.add_theme_constant_override("h_separation", 16)
	list.add_theme_constant_override("v_separation", 12)
	box.add_child(list)
	# Head room for the UPGRADE price tag above the button.
	var tag_gap := Control.new()
	tag_gap.custom_minimum_size = Vector2(0, 12)
	tag_gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(tag_gap)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	upgrade = UiKit.confirm("UPGRADE", 330, 110)
	upgrade.pressed.connect(_upgrade)
	# Coin cost as a price tag on the button's top edge.
	price = PriceTag.new()
	price.size = Vector2(150, 50)
	price.position = Vector2(330 - 162, -26)
	upgrade.add_child(price)
	hunt = UiKit.button("SELECT", 330, 110, "gold")
	hunt.pressed.connect(func() -> void:
		if selected == SaveGame.featured_id():
			return
		SaveGame.set_featured(selected)
		AudioDirector.sfx("card_pick")
		AudioDirector.haptic("medium")
		toast("%s is now your hero" % str(Catalog.critter(selected)["name"]))
		_fill()
	)
	row.add_child(upgrade)
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
	showcase.fill = 0.645
	showcase.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage_slot.add_child(showcase)
	for sock in sockets:
		if is_instance_valid(sock) and is_instance_valid(sock.get_parent()):
			sock.get_parent().queue_free()
	sockets = EquipUI.sockets(stage_slot, selected, float(insets()["t"]) + 200.0, open_slot)
	var info := Catalog.critter(selected)
	var stats := SaveGame.build_run_stats(selected)
	var equipped := selected == SaveGame.featured_id()
	hunt.text = "✓ EQUIPPED" if equipped else "SELECT"
	hunt.disabled = equipped
	# Settled state reads as done (muted stone/gilt), never as a red alarm.
	if hunt.has_method("set_tone"):
		hunt.call("set_tone", "stone" if equipped else "gold")
	hunt.modulate = Color(0.92, 0.9, 0.86) if equipped else Color.WHITE
	stat_line.text = "%s  ·  %s" % [str(info["name"]).to_upper(), Catalog.role_name(str(info["role"])).to_upper()]
	_fill_level(stats)
	stats_panel.set_hero(selected)
	gear_line.text = EquipUI.summary(selected)


## Heroes train for power now (skill XP from hunts), so the old card/relic
## UPGRADE button, its coin price and the relic bar are hidden. The level
## label stays as a flavour readout of the banked card levels.
func _fill_level(stats: Dictionary) -> void:
	var level := int(SaveGame.hero(selected)["level"])
	var hp_now := int(round(float(stats["hp"])))
	var dmg_now := int(round(float(stats["dmg"])))
	preview_line.text = "Level %d   ·   Health %d   ·   Damage %d" % [level, hp_now, dmg_now]
	card_bar.visible = false
	upgrade.visible = false
	price.visible = false


func _upgrade() -> void:
	if SaveGame.try_level(selected):
		AudioDirector.haptic("medium")
		toast("%s reached level %d" % [str(Catalog.critter(selected)["name"]), int(SaveGame.hero(selected)["level"])])
		_fill()


func open_slot(slot: String) -> void:
	AudioDirector.play("click")
	EquipUI.sheet(self, selected, slot, _fill)


func _tile(id: String) -> Control:
	var info := Catalog.critter(id)
	var row := SaveGame.hero(id)
	var on := id == selected
	var rarity := UiKit.hero_rarity(id)
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.flat = true
	b.custom_minimum_size = Vector2(158, 206)
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
	medal.custom_minimum_size = Vector2(100, 100)
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


## Card shards toward the next level: green and glowing when the upgrade is
## affordable, with a "+N" pill for surplus cards.
class CardBar extends Control:
	var ratio := 0.0
	var caption := ""
	var surplus := 0
	var ready_up := false

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		UiKit.ensure()
		var r := Rect2(Vector2.ZERO, size)
		UiKit.ch_fill(self, r.grow(1), size.y * 0.5, Color("8a6a3a"), Color("3a2410"))
		UiKit.ch_fill(self, r.grow(-2), size.y * 0.5 - 2, Color("070504"), Color("1a140f"))
		var inner := Rect2(4, 4, maxf(0.0, (size.x - 8.0) * ratio), maxf(0.0, size.y - 8.0))
		if inner.size.x > inner.size.y:
			var hi := Color("7ad06a") if ready_up else Color("4aa3d8")
			var lo := Color("1e5a22") if ready_up else Color("123e66")
			UiKit.ch_fill(self, inner, inner.size.y * 0.5, hi, lo)
			UiKit.ch_fill(self, Rect2(inner.position + Vector2(4, 1), Vector2(inner.size.x - 8, inner.size.y * 0.4)), inner.size.y * 0.2, Color(1, 1, 1, 0.3), Color(1, 1, 1, 0.0))
		var reserve := 56.0 if surplus > 0 else 0.0
		UiKit.draw_text(self, UiKit.font_b, Vector2(14, size.y * 0.72), caption, 22, UiKit.CREAM, Color(0.04, 0.03, 0.02), 3, size.x - 28.0 - reserve)
		if surplus > 0:
			var pill := Rect2(size.x - 56, 3, 52, size.y - 6)
			UiKit.ch_fill(self, pill, pill.size.y * 0.5, Color("ffe3a0"), Color("9a6a20"))
			UiKit.draw_text(self, UiKit.font_b, Vector2(pill.position.x, size.y * 0.72), "+%d" % surplus, 20, Color("2a1806"), Color(1, 0.95, 0.8, 0.0), 0, pill.size.x)


## Dark pill with a stamped coin and the upgrade cost (red when short).
class PriceTag extends Control:
	var amount := 0
	var short := false

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		UiKit.ensure()
		var r := Rect2(Vector2.ZERO, size)
		UiKit.ch_fill(self, r.grow(2), size.y * 0.5, Color("c9a35c"), Color("5a3a14"))
		UiKit.ch_fill(self, r, size.y * 0.5, Color("231a12"), Color("0c0907"))
		UiKit.draw_currency(self, "coin", Rect2(4, 4, size.y - 8, size.y - 8))
		UiKit.draw_text(self, UiKit.font_b, Vector2(size.y, size.y * 0.72), str(amount), 28, Color("ff8a7a") if short else UiKit.CREAM, Color(0.04, 0.03, 0.02), 3, size.x - size.y - 8.0)
