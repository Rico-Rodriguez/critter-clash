extends ScreenBase

var hero_id := "ember"
var biome_id := "meadow"
var return_to := "heroes"
var slot := "weapon"
var list: VBoxContainer
var title_label: Label
var summary: Label


const Home := preload("res://scripts/home_screen.gd")

var sockets := {}
var stage_slot: Control


func build() -> void:
	var pad := insets()
	stage_slot = Control.new()
	stage_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage_slot.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	stage_slot.anchor_bottom = 0.42
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
	title_label = h1("Loadout")
	box.add_child(title_label)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 330)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(spacer)
	var slots := HBoxContainer.new()
	slots.alignment = BoxContainer.ALIGNMENT_CENTER
	slots.add_theme_constant_override("separation", 26)
	for name in ["weapon", "armor", "charm"]:
		var sock := Socket.new()
		sock.kind = name
		sock.custom_minimum_size = Vector2(190, 230)
		sock.pressed.connect(_pick_slot.bind(name))
		sockets[name] = sock
		slots.add_child(sock)
	box.add_child(slots)
	var plaque := UiKit.Plate.new()
	plaque.kind = "plaque"
	plaque.pad = 14
	summary = UiKit.label("", 22, UiKit.GOLD.lightened(0.2), "x", 3)
	summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	plaque.add_child(summary)
	box.add_child(plaque)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 10)
	scroll.add_child(list)
	var back := UiKit.secondary("Back", 260, 72)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(func() -> void: go(return_to, {"biome": biome_id}))
	box.add_child(back)


func open(args: Dictionary = {}) -> void:
	hero_id = str(args.get("hero", "ember"))
	biome_id = str(args.get("biome", "meadow"))
	return_to = "collection" if str(args.get("from", "")) == "collection" else "heroes"
	_fill()


func _pick_slot(next: String) -> void:
	slot = next
	_fill()


func _fill() -> void:
	var info := Catalog.critter(hero_id)
	title_label.text = "%s's gear" % str(info["name"])
	if stage_slot.get_child_count() == 0 or stage_slot.get_child(0).hero_id != hero_id:
		for c in stage_slot.get_children():
			c.queue_free()
		var show := Home.Showcase.new()
		show.hero_id = hero_id
		show.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		stage_slot.add_child(show)
	for name in sockets.keys():
		var sock: Socket = sockets[name]
		sock.active = name == slot
		var uid := int(SaveGame.hero(hero_id)[name])
		sock.rarity = ""
		if uid > 0:
			var p := SaveGame.find_gear(uid)
			if not p.is_empty():
				sock.rarity = str(p["rarity"])
		sock.queue_redraw()
	var equipped := int(SaveGame.hero(hero_id)[slot])
	var worn := "Empty %s slot" % slot
	if equipped > 0:
		var piece := SaveGame.find_gear(equipped)
		if not piece.is_empty():
			worn = "Wearing " + SaveGame.gear_text(piece)
	summary.text = worn
	for child in list.get_children():
		child.queue_free()
	if equipped > 0:
		var clear := UiKit.secondary("Unequip %s" % slot, 420, 72)
		clear.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		clear.pressed.connect(_clear_slot)
		list.add_child(clear)
	var found := false
	for piece in SaveGame.data["bag"]:
		if str(piece["slot"]) != slot:
			continue
		found = true
		var button := Button.new()
		button.focus_mode = Control.FOCUS_NONE
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.custom_minimum_size = Vector2(0, 92)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_override("font", UiKit.font_x)
		button.add_theme_font_size_override("font_size", 22)
		button.add_theme_color_override("font_color", UiKit.rarity_colors(str(piece["rarity"]))["lip"].lightened(0.3))
		button.text = SaveGame.gear_text(piece)
		var none := StyleBoxEmpty.new()
		for st in ["normal", "hover", "pressed", "focus"]:
			button.add_theme_stylebox_override(st, none)
		var metal := UiKit.rarity_metal(str(piece["rarity"]))
		var fr := UiKit.Frame.new("plaque", "leather", {"metal_hi": metal[0], "metal_lo": metal[1]})
		fr.margin = 2.0
		button.add_child(fr)
		button.pressed.connect(_equip.bind(int(piece["uid"])))
		list.add_child(button)
	if not found:
		var hint := body("Your bag holds no %s yet. Hunt chests drop weapons, armor, and charms." % slot)
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		list.add_child(hint)


func _equip(uid: int) -> void:
	SaveGame.equip(hero_id, uid)
	_fill()


func _clear_slot() -> void:
	SaveGame.unequip(hero_id, slot)
	_fill()


## A round gear socket in a forged ring. Glows when it is the open slot;
## the ring takes the worn item's rarity metal.
class Socket extends Button:
	var kind := "weapon"
	var active := false
	var rarity := ""

	func _ready() -> void:
		focus_mode = Control.FOCUS_NONE
		var none := StyleBoxEmpty.new()
		for st in ["normal", "hover", "pressed", "focus"]:
			add_theme_stylebox_override(st, none)

	func _draw() -> void:
		var r := size.x * 0.42
		var c := Vector2(size.x * 0.5, r + 8.0)
		var metal: Array = UiKit.rarity_metal(rarity) if rarity != "" else [Color("a8875a"), Color("2e1e0e")]
		if active:
			for k in 10:
				draw_circle(c, r + 22.0 - k * 2.0, Color(1.0, 0.72, 0.3, 0.035))
		draw_circle(c + Vector2(0, 5), r + 4, Color(0, 0, 0, 0.6))
		draw_circle(c, r + 2, Color("120a04"))
		draw_arc(c, r - 4, 0, TAU, 64, (Color("e8c886") if active else metal[1]), 8.0, true)
		draw_arc(c, r - 4, PI * 1.05, PI * 1.95, 32, (Color("fff0c0") if active else metal[0]), 3.0, true)
		draw_circle(c, r - 9, Color("0c0806"))
		for k in 6:
			draw_circle(c, (r - 12) * (1.0 - k * 0.12), Color(0.35, 0.22, 0.12, 0.07))
		var col := Color("e8c886") if active else Color("8a7a62")
		var s := r * 0.55
		match kind:
			"weapon":
				UiKit.draw_icon(self, UiKit.icon("sword"), Rect2(c - Vector2(s, s), Vector2(s, s) * 2.0), col, Color(0, 0, 0, 0), 0.0)
			"charm":
				UiKit.draw_icon(self, UiKit.icon("star"), Rect2(c - Vector2(s, s), Vector2(s, s) * 2.0), col, Color(0, 0, 0, 0), 0.0)
			_:
				var pts := PackedVector2Array([c + Vector2(-s * 0.8, -s * 0.8), c + Vector2(s * 0.8, -s * 0.8), c + Vector2(s * 0.75, s * 0.1), c + Vector2(0, s), c + Vector2(-s * 0.75, s * 0.1)])
				draw_colored_polygon(pts, col)
				var inner := PackedVector2Array()
				for p in pts:
					inner.append(c + (p - c) * 0.62)
				draw_colored_polygon(inner, Color("0c0806"))
		var font := UiKit.font_x
		var label := kind.to_upper()
		var fs := 20
		var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(font, Vector2(size.x * 0.5 - w * 0.5, size.y - 8), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("e8c886") if active else UiKit.MUTED)
