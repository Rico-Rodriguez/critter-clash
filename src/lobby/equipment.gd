class_name Equipment
extends Control
## The equipment screen: the camp hero stays visible in the middle with the
## five slots around them, and the bag is a grid underneath. Tap a tile for a
## side-by-side compare against what is worn; switch heroes with the arrows to
## dress each one. Everything applies immediately and the 3D hero changes with it.

signal closed

const TILE := 126.0
const SLOT_POS := {
	"helm": Vector2(0, 0), "chest": Vector2(0, 1), "legs": Vector2(0, 2),
	"weapon": Vector2(1, 0), "trinket": Vector2(1, 1),
}

var ui: LobbyUI
var lobby: Node3D
var hero_id := "knight"
var filter := ""

var _name: Label
var _sub: Label
var _delta: Label
var _slots := {}
var _grid: GridContainer
var _filter_buttons := {}
var _sell_btn: Button
var _toast: Label
var _popup: Control
var _new_uids := {}
var _last_power := 0
var _delta_tween: Tween


func open(u: LobbyUI) -> void:
	ui = u
	lobby = u.lobby
	hero_id = Game.hero_id()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	for it in Game.data["items"]:
		if Game.is_new(int(it["uid"])):
			_new_uids[int(it["uid"])] = true
	_build_header()
	_build_slots()
	_build_panel()
	_last_power = Game.power_score(hero_id)
	_refresh()
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.2)


# --- Layout ----------------------------------------------------------------

func _build_header() -> void:
	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Ui.apply_safe_area(m, 20)
	add_child(m)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(row)
	row.add_child(_round_button("‹", func(): _cycle(-1)))
	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", 0)
	mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name = Ui.label("", "Title", HORIZONTAL_ALIGNMENT_CENTER)
	_name.add_theme_font_size_override("font_size", 40)
	mid.add_child(_name)
	var line := HBoxContainer.new()
	line.alignment = BoxContainer.ALIGNMENT_CENTER
	line.add_theme_constant_override("separation", 10)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sub = Ui.label("", "HudLabel", HORIZONTAL_ALIGNMENT_CENTER)
	_sub.add_theme_font_size_override("font_size", 22)
	line.add_child(_sub)
	_delta = Ui.label("", "HudLabel", HORIZONTAL_ALIGNMENT_CENTER)
	_delta.add_theme_font_size_override("font_size", 22)
	line.add_child(_delta)
	mid.add_child(line)
	row.add_child(mid)
	row.add_child(_round_button("›", func(): _cycle(1)))
	row.add_child(_round_button("✕", _close))


func _round_button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.theme_type_variation = "RoundButton"
	b.text = text
	b.custom_minimum_size = Vector2(68, 68)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 34)
	b.add_theme_color_override("font_color", Color(0.91, 0.71, 0.35))
	b.pressed.connect(func():
		Sfx.play("ui_tap", -4.0)
		cb.call())
	return b


func _build_slots() -> void:
	for slot: String in SLOT_POS:
		var p: Vector2 = SLOT_POS[slot]
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.anchor_left = p.x
		b.anchor_right = p.x
		b.anchor_top = 0.0
		b.anchor_bottom = 0.0
		var x := 16.0
		b.offset_left = x if p.x == 0.0 else -x - 128.0
		b.offset_right = x + 128.0 if p.x == 0.0 else -x
		var y := 250.0 + p.y * 146.0
		b.offset_top = y
		b.offset_bottom = y + 128.0
		b.pressed.connect(func(): _on_slot(slot))
		add_child(b)
		_slots[slot] = b


func _build_panel() -> void:
	var panel := PanelContainer.new()
	panel.theme_type_variation = "Sheet"
	panel.anchor_right = 1.0
	panel.anchor_top = 0.55
	panel.anchor_bottom = 1.0
	add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)
	var filters := HBoxContainer.new()
	filters.add_theme_constant_override("separation", 4)
	for f in ["", "weapon", "helm", "chest", "legs", "trinket"]:
		var b := Button.new()
		b.theme_type_variation = "Ghost"
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 58)
		if f == "":
			b.text = "All"
		else:
			b.icon = Ui.icon(DB.SLOT_ICON[f])
			b.expand_icon = true
		var ff: String = f
		b.pressed.connect(func():
			filter = ff
			Sfx.play("ui_tap", -6.0)
			_refresh())
		filters.add_child(b)
		_filter_buttons[f] = b
	v.add_child(filters)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = 5
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(_grid)
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 10)
	var best := Button.new()
	best.text = "Equip best"
	best.theme_type_variation = "GoldButton"
	best.custom_minimum_size = Vector2(0, 76)
	best.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	best.focus_mode = Control.FOCUS_NONE
	best.add_theme_font_size_override("font_size", 26)
	best.pressed.connect(_equip_best)
	foot.add_child(best)
	_sell_btn = Button.new()
	_sell_btn.custom_minimum_size = Vector2(0, 76)
	_sell_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sell_btn.focus_mode = Control.FOCUS_NONE
	_sell_btn.add_theme_font_size_override("font_size", 22)
	_sell_btn.pressed.connect(_confirm_sell_junk)
	foot.add_child(_sell_btn)
	v.add_child(foot)
	_toast = Ui.label("", "HudLabel", HORIZONTAL_ALIGNMENT_CENTER)
	_toast.add_theme_font_size_override("font_size", 26)
	_toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_toast.anchor_left = 0.0
	_toast.anchor_right = 1.0
	_toast.offset_left = 0.0
	_toast.offset_right = 0.0
	_toast.offset_top = 700.0
	_toast.modulate.a = 0.0
	add_child(_toast)


# --- Refresh ---------------------------------------------------------------

func _refresh() -> void:
	var d: Dictionary = DB.HEROES[hero_id]
	_name.text = d["name"]
	_name.add_theme_color_override("font_color", Color(0.91, 0.71, 0.35).lerp(d["color"], 0.4))
	var power := Game.power_score(hero_id)
	_sub.text = "Lv %d · Power %d" % [int(Game.hero(hero_id)["level"]), power]
	if power != _last_power:
		_show_delta(power - _last_power)
		_last_power = power
	for slot: String in _slots:
		_style_slot(_slots[slot], slot)
	for f: String in _filter_buttons:
		_filter_buttons[f].button_pressed = f == filter
	Ui.clear(_grid)
	var items: Array = Game.data["items"].duplicate()
	items.sort_custom(func(a, b):
		var ea := 1 if Game.owner_of(int(a["uid"])) == hero_id else 0
		var eb := 1 if Game.owner_of(int(b["uid"])) == hero_id else 0
		if ea != eb:
			return ea > eb
		return Game.item_score(a) > Game.item_score(b))
	var shown := 0
	for it in items:
		if filter != "" and it["slot"] != filter:
			continue
		_grid.add_child(_tile(it))
		shown += 1
	if shown == 0:
		var empty := Ui.label("Nothing here yet.\nChampions, the King and chests drop gear.", "Body", HORIZONTAL_ALIGNMENT_CENTER)
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.custom_minimum_size = Vector2(600, 120)
		_grid.add_child(empty)
	var junk := Game.junk_items()
	var gold := 0
	for it in junk:
		gold += Game.item_value(it)
	_sell_btn.text = "Sell junk (%d) · %d gold" % [junk.size(), gold] if not junk.is_empty() else "No junk to sell"
	_sell_btn.disabled = junk.is_empty()


func _style_slot(b: Button, slot: String) -> void:
	var it := Game.equipped(hero_id, slot)
	var col := DB.rarity_color(it["rarity"]) if not it.is_empty() else Color(0.45, 0.42, 0.4)
	b.add_theme_stylebox_override("normal", _frame(col, 0.0 if it.is_empty() else 0.25, 16, 4))
	b.add_theme_stylebox_override("hover", _frame(col, 0.3, 16, 4))
	b.add_theme_stylebox_override("pressed", _frame(col, 0.4, 16, 4))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for c in b.get_children():
		c.queue_free()
	var icon_name: String = DB.SLOT_ICON[slot]
	if not it.is_empty() and str(it.get("unique", "")) != "":
		icon_name = DB.UNIQUES[it["unique"]]["icon"]
	var ic := Ui.icon_rect(icon_name, 70, col.lightened(0.3) if not it.is_empty() else Color(0.5, 0.48, 0.46, 0.55))
	ic.position = Vector2(29, 12)
	b.add_child(ic)
	var cap := Ui.label(DB.SLOT_NAME[slot] if it.is_empty() else _short_stat(it), "HudLabel", HORIZONTAL_ALIGNMENT_CENTER)
	cap.add_theme_font_size_override("font_size", 17)
	cap.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	cap.offset_top = -34
	cap.offset_bottom = -8
	b.add_child(cap)


## The main stat of an item as a short line ("+12% Damage").
func _short_stat(it: Dictionary) -> String:
	var best_k := ""
	var best_v := -1
	for k in it["stats"]:
		if int(it["stats"][k]) > best_v:
			best_v = int(it["stats"][k])
			best_k = k
	if best_k == "":
		return "—"
	var sh: Array = DB.AFFIX_SHORT[best_k]
	return "+%d%s %s" % [best_v, sh[1], sh[0]]


func _frame(col: Color, fill: float, radius: int, border: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.07, 0.065, 0.08, 0.86).lerp(Color(col.r, col.g, col.b, 0.9), fill * 0.5)
	s.set_corner_radius_all(radius)
	s.set_border_width_all(border)
	s.border_color = col
	s.anti_aliasing = true
	s.shadow_color = Color(col.r, col.g, col.b, 0.35 if fill > 0.0 else 0.0)
	s.shadow_size = 10 if fill > 0.0 else 0
	return s


func _tile(it: Dictionary) -> Control:
	var uid := int(it["uid"])
	var col := DB.rarity_color(it["rarity"])
	var owner := Game.owner_of(uid)
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, TILE)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_stylebox_override("normal", _frame(col, 0.0, 12, 3))
	b.add_theme_stylebox_override("hover", _frame(col, 0.25, 12, 3))
	b.add_theme_stylebox_override("pressed", _frame(col, 0.4, 12, 3))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var icon_name: String = DB.UNIQUES[it["unique"]]["icon"] if str(it.get("unique", "")) != "" else DB.SLOT_ICON[it["slot"]]
	var ic := Ui.icon_rect(icon_name, 62, col.lightened(0.25))
	ic.position = Vector2(32, 18)
	b.add_child(ic)
	var cap := Ui.label(_short_stat(it), "HudLabel", HORIZONTAL_ALIGNMENT_CENTER)
	cap.add_theme_font_size_override("font_size", 15)
	cap.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	cap.offset_top = -30
	cap.offset_bottom = -6
	b.add_child(cap)
	if _new_uids.has(uid) and owner == "":
		var dot := ColorRect.new()
		dot.color = Color(0.4, 1.0, 0.5)
		dot.size = Vector2(14, 14)
		dot.position = Vector2(8, 8)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(dot)
	if owner == "" and _beats_worn(it):
		var up := Ui.label("▲", "HudLabel", HORIZONTAL_ALIGNMENT_RIGHT)
		up.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5))
		up.add_theme_font_size_override("font_size", 24)
		up.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		up.offset_left = -40
		up.offset_right = -8
		up.offset_top = 4
		b.add_child(up)
	if owner != "":
		var badge := Panel.new()
		badge.size = Vector2(28, 28)
		badge.position = Vector2(TILE - 36.0, 8.0) if owner != hero_id else Vector2(8.0, 8.0)
		var bs := StyleBoxFlat.new()
		bs.bg_color = DB.HEROES[owner]["color"]
		bs.set_corner_radius_all(14)
		bs.set_border_width_all(2)
		bs.border_color = Color(0, 0, 0, 0.7)
		badge.add_theme_stylebox_override("panel", bs)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var t := Ui.label("E" if owner == hero_id else str(DB.HEROES[owner]["name"]).left(1), "HudLabel", HORIZONTAL_ALIGNMENT_CENTER)
		t.add_theme_font_size_override("font_size", 16)
		t.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		badge.add_child(t)
		b.add_child(badge)
	b.pressed.connect(func():
		Sfx.play("ui_tap", -4.0)
		_open_detail(it))
	return b


## True when `it` is a better pick than what the current hero wears there.
func _beats_worn(it: Dictionary) -> bool:
	var cur := Game.equipped(hero_id, it["slot"])
	return cur.is_empty() or Game.item_score(it) > Game.item_score(cur)


func _show_delta(d: int) -> void:
	_delta.text = ("▲ +%d" % d) if d > 0 else ("▼ %d" % d)
	_delta.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5) if d > 0 else Color(1.0, 0.45, 0.4))
	_delta.modulate.a = 1.0
	if _delta_tween:
		_delta_tween.kill()
	_delta_tween = create_tween()
	_delta_tween.tween_interval(1.6)
	_delta_tween.tween_property(_delta, "modulate:a", 0.0, 0.5)


func _say(text: String, col := Color(1.0, 0.85, 0.5)) -> void:
	_toast.text = text
	_toast.add_theme_color_override("font_color", col)
	_toast.modulate.a = 1.0
	var t := create_tween()
	t.tween_interval(1.4)
	t.tween_property(_toast, "modulate:a", 0.0, 0.4)


# --- Actions -----------------------------------------------------------------

func _cycle(dir: int) -> void:
	var order: Array = DB.HERO_ORDER
	var i := order.find(hero_id)
	for n in order.size():
		i = posmod(i + dir, order.size())
		if Game.hero(order[i])["unlocked"]:
			break
	hero_id = order[i]
	Game.set_hero(hero_id)
	ui._shown_hero = hero_id
	lobby.show_hero(hero_id, false)
	_last_power = Game.power_score(hero_id)
	_delta.text = ""
	_refresh()


func _on_slot(slot: String) -> void:
	Sfx.play("ui_tap", -4.0)
	filter = slot
	_refresh()
	var it := Game.equipped(hero_id, slot)
	if not it.is_empty():
		_open_detail(it)


func _equip(it: Dictionary) -> void:
	Game.equip(hero_id, int(it["uid"]))
	Sfx.play("gear_equip", -2.0)
	lobby.refresh_gear()
	_refresh()


func _unequip(slot: String) -> void:
	Game.unequip(hero_id, slot)
	Sfx.play("ui_back", -4.0)
	lobby.refresh_gear()
	_refresh()


func _equip_best() -> void:
	var n := Game.equip_best(hero_id)
	if n == 0:
		_say("Already wearing your best", Color(0.8, 0.8, 0.8))
		Sfx.play("ui_error", -8.0)
		return
	Sfx.play("gear_equip", -2.0)
	lobby.refresh_gear()
	_say("%d piece%s equipped" % [n, "" if n == 1 else "s"], Color(0.4, 1.0, 0.5))
	_refresh()


func _confirm_sell_junk() -> void:
	var junk := Game.junk_items()
	if junk.is_empty():
		return
	var gold := 0
	for it in junk:
		gold += Game.item_value(it)
	var box := _modal()
	box.add_child(Ui.label("Sell %d items?" % junk.size(), "Heading", HORIZONTAL_ALIGNMENT_CENTER))
	var msg := Ui.label("Common and magic gear nobody is wearing.\nYou get %d gold." % gold, "Body", HORIZONTAL_ALIGNMENT_CENTER)
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(msg)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var no := Button.new()
	no.text = "Keep"
	no.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	no.custom_minimum_size = Vector2(0, 76)
	no.focus_mode = Control.FOCUS_NONE
	no.pressed.connect(_close_popup)
	row.add_child(no)
	var yes := Button.new()
	yes.text = "Sell"
	yes.theme_type_variation = "GoldButton"
	yes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	yes.custom_minimum_size = Vector2(0, 76)
	yes.focus_mode = Control.FOCUS_NONE
	yes.pressed.connect(func():
		var got := 0
		for it in Game.junk_items():
			got += Game.salvage(int(it["uid"]))
		Sfx.play("coin", 0.0)
		_close_popup()
		_say("+%d gold" % got)
		_refresh())
	row.add_child(yes)
	box.add_child(row)


# --- Item detail ---------------------------------------------------------------

func _modal() -> VBoxContainer:
	_close_popup()
	_popup = Control.new()
	_popup.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var scrim := ColorRect.new()
	scrim.color = Color(0, 0, 0, 0.6)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed:
			_close_popup())
	_popup.add_child(scrim)
	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -310.0
	panel.offset_right = 310.0
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.offset_top = -10.0
	panel.offset_bottom = 10.0
	_popup.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)
	add_child(_popup)
	Ui.pop_in(panel, 0.0, 0.9)
	return v


func _close_popup() -> void:
	if _popup and is_instance_valid(_popup):
		_popup.queue_free()
	_popup = null


func _open_detail(it: Dictionary) -> void:
	var uid := int(it["uid"])
	var col := DB.rarity_color(it["rarity"])
	var owner := Game.owner_of(uid)
	var cur := Game.equipped(hero_id, it["slot"])
	var is_worn := owner == hero_id
	var v := _modal()
	var icon_name: String = DB.UNIQUES[it["unique"]]["icon"] if str(it.get("unique", "")) != "" else DB.SLOT_ICON[it["slot"]]
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	head.add_child(Ui.icon_rect(icon_name, 70, col))
	var hv := VBoxContainer.new()
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hv.add_theme_constant_override("separation", 0)
	var nm := Ui.label(str(it["name"]), "Heading")
	nm.add_theme_color_override("font_color", col.lightened(0.2))
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hv.add_child(nm)
	var where := "" if owner == "" else (" · worn by %s" % DB.HEROES[owner]["name"])
	hv.add_child(Ui.label("%s %s%s" % [DB.RARITY_NAME[it["rarity"]], DB.SLOT_NAME[it["slot"]], where], "Small"))
	head.add_child(hv)
	v.add_child(head)
	for line in Game.describe_stats(it):
		var l := Ui.label(line, "Body")
		l.add_theme_font_size_override("font_size", 23)
		l.add_theme_color_override("font_color", Color(1.0, 0.65, 0.3) if line.begins_with("Start") else Color(0.6, 0.78, 1.0))
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(l)
	if not is_worn:
		v.add_child(HSeparator.new())
		if cur.is_empty():
			v.add_child(Ui.label("Nothing worn in this slot yet", "Small"))
		else:
			v.add_child(Ui.label("Compared with %s" % cur["name"], "Caption"))
			var diffs := Game.compare(it, cur)
			if diffs.is_empty():
				v.add_child(Ui.label("Same stats", "Body"))
			for d in diffs:
				var up: bool = d["diff"] > 0
				var dl := Ui.label("%s %s" % ["▲" if up else "▼", d["text"] if up else str(d["text"])], "Body")
				dl.add_theme_font_size_override("font_size", 23)
				dl.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5) if up else Color(1.0, 0.45, 0.4))
				v.add_child(dl)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	if is_worn:
		var rm := Button.new()
		rm.text = "Remove"
		rm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rm.custom_minimum_size = Vector2(0, 76)
		rm.focus_mode = Control.FOCUS_NONE
		rm.pressed.connect(func():
			_close_popup()
			_unequip(it["slot"]))
		row.add_child(rm)
	else:
		var eq := Button.new()
		eq.text = "Equip on %s" % DB.HEROES[hero_id]["name"]
		eq.theme_type_variation = "PrimaryButton"
		eq.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		eq.custom_minimum_size = Vector2(0, 76)
		eq.focus_mode = Control.FOCUS_NONE
		eq.add_theme_font_size_override("font_size", 26)
		eq.pressed.connect(func():
			_close_popup()
			_equip(it))
		row.add_child(eq)
		if owner == "":
			var sell := Button.new()
			sell.text = "Sell %d" % Game.item_value(it)
			sell.icon = Ui.icon("two-coins")
			sell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			sell.custom_minimum_size = Vector2(0, 76)
			sell.focus_mode = Control.FOCUS_NONE
			var needs_confirm := DB.RARITIES.find(it["rarity"]) >= 2
			sell.pressed.connect(func():
				if needs_confirm and sell.text != "Tap to sell":
					sell.text = "Tap to sell"
					Sfx.play("ui_error", -8.0)
					return
				Game.salvage(uid)
				Sfx.play("coin", -2.0)
				_close_popup()
				_refresh())
			row.add_child(sell)
	v.add_child(row)


# --- Closing -------------------------------------------------------------------

func _close() -> void:
	Game.mark_items_seen()
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.18)
	t.tween_callback(func():
		closed.emit()
		queue_free())
