extends Control
## The level-up choice: three cards, tap one. The tree is paused underneath.

signal picked(id: String)

var _done := false
var _hunt: Hunt
var _choices: Array = []
var _reroll: Button


func open(h: Hunt, choices: Array, level: int) -> void:
	_hunt = h
	%Title.text = "Level %d" % level
	_held_row(h)
	_reroll = Button.new()
	_reroll.theme_type_variation = "CardButton"
	_reroll.add_theme_font_size_override("font_size", 26)
	_reroll.focus_mode = Control.FOCUS_NONE
	_reroll.custom_minimum_size = Vector2(0, 72)
	_reroll.pressed.connect(_do_reroll)
	$Box.add_child(_reroll)
	_fill(choices)
	Ui.pop_in(%Title, 0.0, 1.3)


## The build so far: small icons for the cards already held, with their stacks.
func _held_row(h: Hunt) -> void:
	var held: Array = []
	for id: String in h.cards:
		if int(h.cards[id]) > 0 and DB.CARDS.has(id):
			held.append(id)
	if held.is_empty():
		return
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for id: String in held:
		var col := DB.rarity_color(str(DB.CARDS[id]["rarity"]))
		var cell := HBoxContainer.new()
		cell.add_theme_constant_override("separation", 2)
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(Ui.icon_rect(str(DB.CARDS[id]["icon"]), 34, col.lightened(0.3)))
		cell.add_child(Ui.label("%d" % int(h.cards[id]), "Caption"))
		row.add_child(cell)
	$Box.add_child(row)
	$Box.move_child(row, %Cards.get_index())


## "With Bloodrush → Bladestorm" when this card finishes a pair you half hold.
func _evo_hint(id: String) -> String:
	for eid: String in DB.CARDS:
		var c: Dictionary = DB.CARDS[eid]
		if not c.has("evo") or int(_hunt.cards.get(eid, 0)) > 0:
			continue
		var pair: Array = c["evo"]
		if id in pair:
			var other: String = pair[1] if pair[0] == id else pair[0]
			if int(_hunt.cards.get(other, 0)) > 0:
				return "+ %s → %s" % [DB.CARDS[other]["name"], c["name"]]
	return ""


func _fill(choices: Array) -> void:
	_choices = choices
	Ui.clear(%Cards)
	for id in choices:
		%Cards.add_child(_card(id))
	_reroll.text = "Reroll (%d)" % _hunt.rerolls_left
	_reroll.disabled = _hunt.rerolls_left <= 0
	_reroll.modulate.a = 0.4 if _hunt.rerolls_left <= 0 else 1.0
	await get_tree().process_frame
	var i := 0
	for c in %Cards.get_children():
		Ui.pop_in(c, 0.03 + i * 0.07, 0.7)
		i += 1


func _do_reroll() -> void:
	if _done:
		return
	var fresh := _hunt.reroll_cards(_choices)
	if fresh.is_empty():
		return
	Sfx.play("card_flip", -4.0)
	_fill(fresh)


func _card(id: String) -> Control:
	var c: Dictionary = DB.CARDS[id]
	var rarity: String = c["rarity"]
	var col := DB.rarity_color(rarity)
	var have := int(_hunt.cards.get(id, 0))
	var b := Button.new()
	b.custom_minimum_size = Vector2(212, 360)
	b.focus_mode = Control.FOCUS_NONE
	var n := StyleBoxFlat.new()
	n.bg_color = Color(0.1, 0.09, 0.12, 0.97)
	n.set_corner_radius_all(16)
	n.set_border_width_all(3)
	n.border_width_top = 8
	n.border_color = col
	n.shadow_color = Color(col, 0.35)
	n.shadow_size = 14
	var h := n.duplicate() as StyleBoxFlat
	h.bg_color = Color(0.16, 0.14, 0.18, 0.98)
	for k in ["normal", "focus", "disabled"]:
		b.add_theme_stylebox_override(k, n)
	for k in ["hover", "pressed", "hover_pressed"]:
		b.add_theme_stylebox_override(k, h)
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 12
	v.offset_right = -12
	v.offset_top = 18
	v.offset_bottom = -14
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 8)
	b.add_child(v)
	var r := Ui.label("EVOLUTION" if c.has("evo") else DB.RARITY_NAME[rarity].to_upper(), "Caption", HORIZONTAL_ALIGNMENT_CENTER)
	r.add_theme_color_override("font_color", col)
	r.add_theme_font_size_override("font_size", 16)
	v.add_child(r)
	var ic_wrap := CenterContainer.new()
	ic_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ic_wrap.custom_minimum_size = Vector2(0, 108)
	var disc := Panel.new()
	disc.custom_minimum_size = Vector2(100, 100)
	disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ds := StyleBoxFlat.new()
	ds.bg_color = Color(col.darkened(0.7), 1.0)
	ds.set_corner_radius_all(50)
	ds.set_border_width_all(3)
	ds.border_color = Color(col, 0.8)
	disc.add_theme_stylebox_override("panel", ds)
	var ic := Ui.icon_rect(str(c["icon"]), 64, col.lightened(0.35))
	ic.position = Vector2(18, 18)
	ic.size = Vector2(64, 64)
	disc.add_child(ic)
	ic_wrap.add_child(disc)
	v.add_child(ic_wrap)
	var nm := Ui.label(str(c["name"]), "Heading", HORIZONTAL_ALIGNMENT_CENTER)
	nm.add_theme_font_size_override("font_size", 23)
	nm.add_theme_color_override("font_color", Color(1.0, 0.94, 0.85))
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(nm)
	var d := Ui.label(str(c["desc"]), "Body", HORIZONTAL_ALIGNMENT_CENTER)
	d.add_theme_font_size_override("font_size", 20)
	d.add_theme_color_override("font_color", Color(0.78, 0.74, 0.68))
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(d)
	var pips := HBoxContainer.new()
	pips.alignment = BoxContainer.ALIGNMENT_CENTER
	pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pips.add_theme_constant_override("separation", 6)
	for i in int(c["max"]):
		var p := ColorRect.new()
		p.custom_minimum_size = Vector2(18, 8)
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.color = col if i < have else (Color(1, 1, 1, 0.9) if i == have else Color(1, 1, 1, 0.12))
		pips.add_child(p)
	v.add_child(pips)
	var hint := _evo_hint(id)
	if hint != "":
		var eh := Ui.label(hint, "Caption", HORIZONTAL_ALIGNMENT_CENTER)
		eh.add_theme_color_override("font_color", Color(1.0, 0.8, 0.35))
		eh.add_theme_font_size_override("font_size", 14)
		eh.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(eh)
	elif have == 0:
		var nw := Ui.label("NEW", "Caption", HORIZONTAL_ALIGNMENT_CENTER)
		nw.add_theme_color_override("font_color", Color(0.6, 1.0, 0.7))
		nw.add_theme_font_size_override("font_size", 15)
		v.add_child(nw)
	b.pressed.connect(func(): _pick(id, b))
	return b


## A second finger is not turned into a mouse click by the engine, so a card
## tapped while the thumb still rests on the stick is read from the raw touch.
func _input(e: InputEvent) -> void:
	if _done or not (e is InputEventScreenTouch) or not e.pressed or e.index == 0:
		return
	if _reroll.get_global_rect().has_point(e.position):
		get_viewport().set_input_as_handled()
		_reroll.pressed.emit()
		return
	for c in %Cards.get_children():
		if (c as Control).get_global_rect().has_point(e.position):
			get_viewport().set_input_as_handled()
			c.pressed.emit()
			return


func _pick(id: String, b: Control) -> void:
	if _done:
		return
	_done = true
	Sfx.play("card_flip", -2.0)
	var t := create_tween().set_parallel(true)
	for c in %Cards.get_children():
		if c == b:
			c.pivot_offset = c.size * 0.5
			t.tween_property(c, "scale", Vector2.ONE * 1.08, 0.12)
		else:
			t.tween_property(c, "modulate:a", 0.0, 0.15)
	t.tween_property(%Scrim, "modulate:a", 0.0, 0.25).set_delay(0.12)
	t.chain().tween_callback(func(): picked.emit(id))
