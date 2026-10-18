class_name EquipUI
extends RefCounted

## Heroes-tab equip layout: eight gear sockets framing the 3D hero (left:
## helm, pauldrons, chest, gloves; right: weapon, off-hand, boots, charm) and
## a slot sheet to equip owned pieces. Empty sockets show the slot's outline
## glyph and a gold "+" so they read as progression, not as missing data.
## Data: GearDB (docs/gear.md).

const LEFT := ["helm", "pauldrons", "chest", "gloves"]
const RIGHT := ["weapon", "offhand", "boots", "charm"]
const ROMAN := ["", "I", "II", "III"]


## A single gear socket (custom drawn).
class Socket extends Control:
	var hero := ""
	var slot := ""
	var item := ""        # equipped item id or ""
	var spare := false    # owns something for this slot that is not equipped
	var available := true # this hero has the slot (Gnash has no off-hand)
	var _t := 0.0

	func _init() -> void:
		custom_minimum_size = Vector2(96, 96)
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _process(delta: float) -> void:
		if item == "" and available:
			_t += delta
			queue_redraw()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var tier := int(item.get_slice(".", 2)) if item != "" else 0
		var tc: Color = GearDB.TIER_COLORS[tier]
		UiKit.rr_shadow(self, r, 14.0, 5.0, 0.45)
		if item != "":
			UiKit.rr_fill(self, r, 14.0, Color("2a2119").lerp(tc, 0.32), Color("0c0907").lerp(tc, 0.12))
		else:
			UiKit.rr_fill(self, r, 14.0, Color("17120e"), Color("0c0907"))
		if not available:
			UiKit.rr_line(self, r.grow(-2), 12.0, Color(0.35, 0.3, 0.25, 0.4), 2.0)
			return
		if item != "":
			# Filled: tier-coloured rim with an inner glow for rune plate.
			UiKit.rr_line(self, r.grow(-2), 12.0, tc, 4.0)
			if tier == 3:
				UiKit.rr_line(self, r.grow(-7), 9.0, Color(tc.r, tc.g, tc.b, 0.35 + 0.2 * sin(Time.get_ticks_msec() * 0.004)), 3.0)
			_glyph(r.grow(-20), tc.lightened(0.45), 1.0)
			var font := get_theme_default_font()
			UiKit.draw_text(self, font, Vector2(size.x - 26, 24), ROMAN[tier], 18, tc.lightened(0.3), UiKit.INK, 3)
		else:
			# Empty: dashed gold socket, faint glyph, breathing "+".
			_dashed(r.grow(-3), Color(0.89, 0.73, 0.42, 0.55))
			_glyph(r.grow(-22), Color(0.72, 0.62, 0.48, 0.32), 0.9)
			var a := 0.55 + 0.35 * sin(_t * 2.6)
			var c := Vector2(size.x - 18, size.y - 18)
			draw_circle(c, 12, Color(0.1, 0.08, 0.06, 0.9))
			draw_line(c - Vector2(6, 0), c + Vector2(6, 0), Color(0.95, 0.78, 0.4, a), 3.0)
			draw_line(c - Vector2(0, 6), c + Vector2(0, 6), Color(0.95, 0.78, 0.4, a), 3.0)
		if spare:
			draw_circle(Vector2(14, 14), 7, Color("9fe08a"))
			draw_arc(Vector2(14, 14), 7, 0, TAU, 16, UiKit.INK, 2.0)

	func _dashed(r: Rect2, c: Color) -> void:
		var pts := UiKit.rr_points(r, 12.0, 6)
		for i in pts.size():
			if i % 2 == 0:
				draw_line(pts[i], pts[(i + 1) % pts.size()], c, 2.5)

	func _poly(pts: Array, r: Rect2, c: Color, fill := true) -> void:
		var out := PackedVector2Array()
		for p: Vector2 in pts:
			out.append(r.position + p * r.size)
		if fill:
			draw_colored_polygon(out, c)
		else:
			out.append(out[0])
			draw_polyline(out, c, 3.0)

	## Simple silhouettes in a unit square, one per slot.
	func _glyph(r: Rect2, c: Color, _s: float) -> void:
		match slot:
			"helm":
				_poly([Vector2(0.2, 0.95), Vector2(0.2, 0.4), Vector2(0.35, 0.12), Vector2(0.65, 0.12), Vector2(0.8, 0.4), Vector2(0.8, 0.95), Vector2(0.6, 0.95), Vector2(0.6, 0.55), Vector2(0.4, 0.55), Vector2(0.4, 0.95)], r, c)
			"pauldrons":
				_poly([Vector2(0.05, 0.75), Vector2(0.15, 0.35), Vector2(0.45, 0.2), Vector2(0.5, 0.45), Vector2(0.3, 0.55), Vector2(0.25, 0.85)], r, c)
				_poly([Vector2(0.95, 0.75), Vector2(0.85, 0.35), Vector2(0.55, 0.2), Vector2(0.5, 0.45), Vector2(0.7, 0.55), Vector2(0.75, 0.85)], r, c)
			"chest":
				_poly([Vector2(0.15, 0.15), Vector2(0.38, 0.1), Vector2(0.5, 0.25), Vector2(0.62, 0.1), Vector2(0.85, 0.15), Vector2(0.8, 0.6), Vector2(0.7, 0.92), Vector2(0.3, 0.92), Vector2(0.2, 0.6)], r, c)
			"gloves":
				_poly([Vector2(0.3, 0.95), Vector2(0.3, 0.5), Vector2(0.2, 0.3), Vector2(0.3, 0.25), Vector2(0.38, 0.4), Vector2(0.4, 0.08), Vector2(0.5, 0.08), Vector2(0.52, 0.35), Vector2(0.58, 0.1), Vector2(0.68, 0.12), Vector2(0.66, 0.4), Vector2(0.76, 0.22), Vector2(0.84, 0.28), Vector2(0.72, 0.6), Vector2(0.7, 0.95)], r, c)
			"boots":
				_poly([Vector2(0.3, 0.08), Vector2(0.6, 0.08), Vector2(0.6, 0.6), Vector2(0.92, 0.75), Vector2(0.92, 0.92), Vector2(0.28, 0.92)], r, c)
			"weapon":
				_poly([Vector2(0.86, 0.06), Vector2(0.94, 0.14), Vector2(0.38, 0.7), Vector2(0.3, 0.62)], r, c)
				_poly([Vector2(0.18, 0.56), Vector2(0.44, 0.82), Vector2(0.38, 0.88), Vector2(0.12, 0.62)], r, c)
				_poly([Vector2(0.26, 0.7), Vector2(0.3, 0.74), Vector2(0.12, 0.94), Vector2(0.06, 0.88)], r, c)
			"offhand":
				_poly([Vector2(0.15, 0.1), Vector2(0.85, 0.1), Vector2(0.85, 0.5), Vector2(0.5, 0.95), Vector2(0.15, 0.5)], r, c)
			"charm":
				draw_arc(r.position + Vector2(0.5, 0.32) * r.size, r.size.x * 0.24, PI * 0.9, PI * 2.1, 18, c, 3.0)
				_poly([Vector2(0.5, 0.45), Vector2(0.72, 0.68), Vector2(0.5, 0.95), Vector2(0.28, 0.68)], r, c)


## Builds the two socket columns over a stage. on_pick(slot) opens the sheet.
static func sockets(stage: Control, hero: String, top: float, on_pick: Callable) -> Array:
	var made := []
	var eq := GearDB.equipped(hero)
	var slots: Array = GearDB.HERO_SLOTS.get(hero, [])
	var owned := GearDB.owned(hero)
	for side in 2:
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 12)
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if side == 0:
			col.set_anchors_preset(Control.PRESET_TOP_LEFT)
			col.position = Vector2(18, top)
		else:
			col.set_anchors_preset(Control.PRESET_TOP_RIGHT)
			col.anchor_left = 1.0
			col.anchor_right = 1.0
			col.offset_left = -18 - 96
			col.offset_right = -18
			col.offset_top = top
		stage.add_child(col)
		for sl in (LEFT if side == 0 else RIGHT):
			var s := Socket.new()
			s.hero = hero
			s.slot = sl
			s.available = sl in slots
			s.item = str(eq.get(sl, ""))
			for id in owned:
				if id.get_slice(".", 1) == sl and id != s.item:
					s.spare = true
			if s.available:
				s.gui_input.connect(func(ev: InputEvent) -> void:
					if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
						on_pick.call(sl)
					elif ev is InputEventScreenTouch and ev.pressed:
						on_pick.call(sl))
			col.add_child(s)
			made.append(s)
	return made


static func stat_text(stats: Dictionary) -> String:
	var bits := PackedStringArray()
	if stats.has("hp_flat"):
		bits.append("+%d HP" % int(stats["hp_flat"]))
	if stats.has("armor"):
		bits.append("+%d armour" % int(stats["armor"]))
	if stats.has("dmg_pct"):
		bits.append("+%d%% dmg" % int(round(float(stats["dmg_pct"]) * 100)))
	if stats.has("haste"):
		bits.append("+%d%% haste" % int(round(float(stats["haste"]) * 100)))
	if stats.has("crit"):
		bits.append("+%d%% crit" % int(round(float(stats["crit"]) * 100)))
	if stats.has("speed_pct"):
		bits.append("+%d%% move" % int(round(float(stats["speed_pct"]) * 100)))
	if stats.has("regen"):
		bits.append("+%.1f regen" % float(stats["regen"]))
	return "  ".join(bits)


## One line for the plaque under the stats.
static func summary(hero: String) -> String:
	var eq := GearDB.equipped(hero)
	var filled := 0
	for sl in eq:
		if eq[sl] != "":
			filled += 1
	if filled == 0:
		return "Bare: no gear yet. Earn it from camps, elites, bosses and chests."
	var st := stat_text(GearDB.stats(hero))
	return "Gear %d / %d   ·   %s" % [filled, eq.size(), st]


## Slot sheet: owned pieces for this slot, with Equip or a locked badge.
static func sheet(host: Control, hero: String, slot: String, changed: Callable) -> Control:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.62)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	host.add_child(dim)
	var plate := UiKit.Plate.new()
	plate.kind = "panel"
	plate.pad = 26
	plate.set_anchors_preset(Control.PRESET_CENTER)
	plate.custom_minimum_size = Vector2(640, 0)
	plate.position = Vector2(-320, -330)
	dim.add_child(plate)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	plate.add_child(v)
	var name: String = str(Catalog.critter(hero)["name"])
	var title := UiKit.label("%s  ·  %s" % [GearDB.SLOT_NAMES[GearDB.SLOT_KEYS.find(slot)].to_upper(), name.to_upper()], 30, UiKit.GOLD.lightened(0.2), "x", 4)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var eq: String = GearDB.equipped(hero).get(slot, "")
	var items: Array = []
	for id in GearDB.owned(hero):
		if id.get_slice(".", 1) == slot:
			items.append(id)
	if items.is_empty():
		var hint := UiKit.label("Nothing yet. Pieces drop from camps, elites, bosses, chests and the treasure goblin.\nIron, then blackened steel, then cursed rune plate.", 21, UiKit.MUTED, "m", 2)
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint.custom_minimum_size = Vector2(580, 0)
		v.add_child(hint)
		# Preview the ladder so the empty slot shows what it can become.
		for t in range(1, 4):
			v.add_child(_row(hero, GearDB.item_id(hero, slot, t), "", changed, dim, true))
	for id in items:
		v.add_child(_row(hero, id, eq, changed, dim, false))
	var bar := HBoxContainer.new()
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_theme_constant_override("separation", 14)
	if eq != "":
		var off := UiKit.secondary("Unequip", 220, 78)
		off.pressed.connect(func() -> void:
			GearDB.unequip(hero, slot)
			dim.queue_free()
			changed.call())
		bar.add_child(off)
	var close := UiKit.button("Close", 220, 78, "gold")
	close.pressed.connect(func() -> void: dim.queue_free())
	bar.add_child(close)
	v.add_child(bar)
	return dim


static func _row(hero: String, id: String, eq: String, changed: Callable, dim: Control, preview: bool) -> Control:
	var it := GearDB.item(id)
	var tier := int(it["tier"])
	var tc: Color = GearDB.TIER_COLORS[tier]
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.modulate = Color(1, 1, 1, 0.55) if preview else Color.WHITE
	var sw := ColorRect.new()
	sw.color = tc
	sw.custom_minimum_size = Vector2(10, 64)
	row.add_child(sw)
	var tv := VBoxContainer.new()
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.add_theme_constant_override("separation", 0)
	tv.add_child(UiKit.label(str(it["name"]), 23, tc.lightened(0.25), "b", 3))
	var sub := "%s   %s" % [GearDB.TIER_NAMES[tier], stat_text(it["stats"])]
	tv.add_child(UiKit.label(sub, 17, UiKit.MUTED, "m", 2))
	row.add_child(tv)
	if preview:
		var req: Dictionary = it["requires"]
		var txt := "Earn it"
		for k in req:
			txt = "%s %d" % [GearDB.SKILL_NAMES[GearDB.SKILL_KEYS.find(k)], int(req[k])]
		row.add_child(_badge(txt, Color(0.5, 0.45, 0.38)))
		return row
	if id == eq:
		row.add_child(_badge("EQUIPPED", Color("9fe08a")))
		return row
	var ok := GearDB.can_equip(hero, id)
	if not bool(ok["ok"]):
		# Locked requirement badge, e.g. "Requires Defence 20".
		row.add_child(_badge(str(ok["reason"]), Color("e07a5a")))
		return row
	var b := UiKit.confirm("Equip", 150, 64)
	b.pressed.connect(func() -> void:
		GearDB.equip(hero, id)
		dim.queue_free()
		changed.call())
	row.add_child(b)
	return row


static func _badge(text: String, c: Color) -> Control:
	var l := UiKit.label(text, 17, c, "x", 3)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.custom_minimum_size = Vector2(150, 64)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	return l
