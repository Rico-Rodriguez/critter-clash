class_name Equipment
extends Control
## The equipment screen: your hero (drag to turn them) beside their power,
## then one row per slot: what is worn there, its tier, rarity and power, and
## a green Equip button when the bag holds something better for it. Tapping a
## slot opens the bag filtered to it; the bag is a list whose rows answer one
## question with one number: how much power the piece would add. Tapping a row
## tries the piece on the model and slides up its card. Gear is class-specific,
## so other heroes' pieces sit folded at the bottom of the bag.

const DragScroll := preload("res://src/ui/drag_scroll.gd")
const SwipeDismiss := preload("res://src/ui/swipe_dismiss.gd")
const ItemIcons := preload("res://src/ui/item_icons.gd")

signal closed

const SLOT_SIDE := {"helm": 0, "chest": 0, "legs": 0, "weapon": 1, "trinket": 1}
const GOLD := Color(0.91, 0.71, 0.35)
const GREEN := Color(0.4, 1.0, 0.5)
const RED := Color(1.0, 0.45, 0.4)
const DIM := Color(0.66, 0.63, 0.58)
## Icon base tone; the material's color is mixed in (Old School style).
const ICON_TONE := Color(0.88, 0.84, 0.76)
const ROW_H := 96.0
const STAGE_H := 330.0
const SLOT_ORDER := ["weapon", "helm", "chest", "legs", "trinket"]

var ui: LobbyUI
var lobby: Node3D
var hero_id := "knight"
var filter := ""
var show_others := false
var selected: Dictionary = {}

var _name: Label
var _sub: Label
var _delta: Label
var _slots := {}
var _strip: GridContainer
var _power: Label
var _waiting: Label
var _slot_box: VBoxContainer
var _bag_box: VBoxContainer
var _bag_btn: Button
var _tabs := {}
var _tab_row: HBoxContainer
var _list: VBoxContainer
var _scroll: DragScroll
var _count: Label
var _sell_btn: Button
var _toast: Label
var _hint: Label
var _stage: Control
var _popup: Control
var _card: PanelContainer
var _new_uids := {}
var _last_power := 0
var _delta_tween: Tween

var _vp: SubViewport
var _actor: Actor
var _yaw := 0.45
var _spin := 0.0
var _dragging := false


func open(u: LobbyUI) -> void:
	ui = u
	lobby = u.lobby
	hero_id = Game.hero_id()
	Game.new_tier = -1
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	for it in Game.data["items"]:
		if Game.is_new(int(it["uid"])):
			_new_uids[int(it["uid"])] = true
	var bg := ColorRect.new()
	bg.color = Color(0.045, 0.04, 0.055)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var safe := MarginContainer.new()
	safe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	safe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Ui.apply_safe_area(safe, 14)
	add_child(safe)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	safe.add_child(col)
	_build_header(col)
	_build_top(col)
	_build_slots(col)
	_build_bag(col)
	_set_bag(false)
	_toast = Ui.label("", "HudLabel", HORIZONTAL_ALIGNMENT_CENTER)
	_toast.add_theme_font_size_override("font_size", 26)
	_toast.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_toast.offset_top = 470.0
	_toast.modulate.a = 0.0
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_toast)
	_build_actor()
	_last_power = Game.power_score(hero_id)
	_refresh()
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.2)


# --- Layout ----------------------------------------------------------------

func _build_header(col: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(row)
	row.add_child(_round_button("‹", func(): _cycle(-1)))
	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", 0)
	mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name = Ui.label("", "Title", HORIZONTAL_ALIGNMENT_CENTER)
	_name.add_theme_font_size_override("font_size", 38)
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
	b.custom_minimum_size = Vector2(64, 64)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 32)
	b.add_theme_color_override("font_color", GOLD)
	b.pressed.connect(func():
		Sfx.play("ui_tap", -4.0)
		cb.call())
	return b


## The 3D stage with the hero, and the slot buttons floating either side.
## The hero on the left, their power and stats on the right.
func _build_top(col: VBoxContainer) -> void:
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 14)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(top)
	_build_stage(top)
	var side := VBoxContainer.new()
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side.alignment = BoxContainer.ALIGNMENT_CENTER
	side.add_theme_constant_override("separation", 2)
	side.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(side)
	side.add_child(Ui.label("TOTAL POWER", "Caption"))
	_power = Ui.label("", "Title")
	_power.add_theme_font_size_override("font_size", 64)
	side.add_child(_power)
	_waiting = Ui.label("", "Body")
	_waiting.add_theme_font_size_override("font_size", 21)
	side.add_child(_waiting)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 12)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	side.add_child(gap)
	_strip = GridContainer.new()
	_strip.columns = 2
	_strip.add_theme_constant_override("h_separation", 12)
	_strip.add_theme_constant_override("v_separation", 6)
	side.add_child(_strip)


## One row per slot, with Equip best and the way into the bag under them.
func _build_slots(col: VBoxContainer) -> void:
	_slot_box = VBoxContainer.new()
	_slot_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_slot_box.add_theme_constant_override("separation", 8)
	col.add_child(_slot_box)
	for slot: String in SLOT_ORDER:
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0, 112)
		b.pressed.connect(func(): _on_slot(slot))
		_slot_box.add_child(b)
		_slots[slot] = b
	var fill := Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_slot_box.add_child(fill)
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
	_bag_btn = Button.new()
	_bag_btn.custom_minimum_size = Vector2(0, 76)
	_bag_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bag_btn.focus_mode = Control.FOCUS_NONE
	_bag_btn.add_theme_font_size_override("font_size", 23)
	_bag_btn.icon = Ui.icon("swap-bag")
	_bag_btn.pressed.connect(func():
		Sfx.play("ui_tap", -4.0)
		filter = ""
		_set_bag(true)
		_refresh())
	foot.add_child(_bag_btn)
	_slot_box.add_child(foot)


## The slot rows or the bag list; the hero and power stay above either.
func _set_bag(on: bool) -> void:
	_slot_box.visible = not on
	_bag_box.visible = on
	if not on:
		_close_card(true)
	_scroll.scroll_vertical = 0


func _build_stage(col: Container) -> void:
	var stage := Control.new()
	_stage = stage
	stage.custom_minimum_size = Vector2(300, STAGE_H)
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(stage)
	var glow := TextureRect.new()
	var gt := GradientTexture2D.new()
	var g := Gradient.new()
	g.set_color(0, Color(0.26, 0.2, 0.17, 1.0))
	g.set_color(1, Color(0.05, 0.045, 0.055, 0.0))
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.6)
	gt.fill_to = Vector2(0.5, 0.0)
	gt.width = 256
	gt.height = 256
	glow.texture = gt
	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(glow)
	var svc := SubViewportContainer.new()
	svc.stretch = true
	svc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	svc.mouse_filter = Control.MOUSE_FILTER_STOP
	svc.gui_input.connect(_stage_input)
	stage.add_child(svc)
	_vp = SubViewport.new()
	_vp.transparent_bg = true
	_vp.own_world_3d = true
	_vp.msaa_3d = Viewport.MSAA_2X
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	svc.add_child(_vp)
	GearStage.light(_vp)
	var cam := Camera3D.new()
	cam.fov = 30.0
	_vp.add_child(cam)
	cam.look_at_from_position(Vector3(0, 1.35, 4.5), Vector3(0, 0.93, 0), Vector3.UP)
	_hint = Ui.label("Drag to turn", "Caption", HORIZONTAL_ALIGNMENT_CENTER)
	_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_hint.offset_top = -30.0
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.modulate.a = 0.6
	stage.add_child(_hint)


func _build_bag(outer: VBoxContainer) -> void:
	_bag_box = VBoxContainer.new()
	_bag_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_bag_box.add_theme_constant_override("separation", 8)
	outer.add_child(_bag_box)
	var col := _bag_box
	_tab_row = HBoxContainer.new()
	_tab_row.add_theme_constant_override("separation", 4)
	for f in ["", "weapon", "helm", "chest", "legs", "trinket"]:
		var b := Button.new()
		b.theme_type_variation = "Ghost"
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 62)
		b.add_theme_font_size_override("font_size", 17)
		b.text = "All" if f == "" else DB.SLOT_NAME[f]
		if f != "":
			b.icon = Ui.icon(DB.SLOT_ICON[f])
			b.expand_icon = false
			b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
			b.add_theme_constant_override("icon_max_width", 26)
		var ff: String = f
		b.pressed.connect(func():
			filter = ff
			_clear_new(ff)
			Sfx.play("ui_tap", -6.0)
			_close_card(false)
			_refresh())
		_tab_row.add_child(b)
		_tabs[f] = b
	col.add_child(_tab_row)
	_scroll = DragScroll.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.custom_minimum_size = Vector2(0, 150)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 6)
	_scroll.add_child(_list)
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 10)
	var back := Button.new()
	back.text = "‹  Slots"
	back.custom_minimum_size = Vector2(0, 68)
	back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	back.focus_mode = Control.FOCUS_NONE
	back.add_theme_font_size_override("font_size", 23)
	back.pressed.connect(func():
		Sfx.play("ui_back", -6.0)
		_set_bag(false)
		_refresh())
	foot.add_child(back)
	_sell_btn = Button.new()
	_sell_btn.custom_minimum_size = Vector2(0, 68)
	_sell_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sell_btn.focus_mode = Control.FOCUS_NONE
	_sell_btn.add_theme_font_size_override("font_size", 21)
	_sell_btn.pressed.connect(_confirm_sell_junk)
	foot.add_child(_sell_btn)
	col.add_child(foot)
	_count = Ui.label("", "Caption", HORIZONTAL_ALIGNMENT_CENTER)
	_count.modulate.a = 0.7
	col.add_child(_count)


# --- The model ---------------------------------------------------------------

func _build_actor() -> void:
	if _actor and is_instance_valid(_actor):
		_actor.queue_free()
	var d: Dictionary = DB.HEROES[hero_id]
	_actor = Actor.new()
	_vp.add_child(_actor)
	_actor.build_model(d["model"], {}, Color(0.55, 0.68, 1.0), 0.5)
	_actor.play(d["anim"]["idle"], 0.0)
	_actor.rotation.y = _yaw
	_dress()


## Puts on what the hero wears, plus the selected piece as a try-on.
func _dress() -> void:
	var preview := {}
	if not selected.is_empty() and str(selected["cls"]) == hero_id:
		preview[selected["slot"]] = selected
	GearLook.apply(_actor, hero_id, preview)


func _process(dt: float) -> void:
	if _actor == null or not is_instance_valid(_actor):
		return
	if not _dragging:
		_yaw += _spin * dt
		_spin = lerpf(_spin, 0.0, 1.0 - exp(-3.0 * dt))
	_actor.rotation.y = _yaw


func _stage_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		_dragging = e.pressed
		if e.pressed:
			_spin = 0.0
			create_tween().tween_property(_hint, "modulate:a", 0.0, 0.4)
	elif e is InputEventMouseMotion and _dragging:
		var dx: float = e.relative.x * 0.011
		_yaw += dx
		_spin = dx * 40.0
	elif e is InputEventScreenDrag:
		var dx2: float = e.relative.x * 0.011
		_yaw += dx2
		_spin = dx2 * 40.0


# --- Refresh ---------------------------------------------------------------

func _refresh() -> void:
	var d: Dictionary = DB.HEROES[hero_id]
	_name.text = d["name"]
	_name.add_theme_color_override("font_color", GOLD.lerp(d["color"], 0.4))
	var power := Game.power_score(hero_id)
	_sub.text = "Lv %d" % int(Game.hero(hero_id)["level"])
	_power.text = str(power)
	var waiting := 0
	for slot in SLOT_ORDER:
		var bi := _best_for(slot)
		if not bi.is_empty():
			waiting += _gain(bi)
	_waiting.text = "+%d waiting in your bag" % waiting if waiting > 0 else "Wearing your best"
	_waiting.add_theme_color_override("font_color", GREEN if waiting > 0 else DIM)
	_bag_btn.text = "Bag · %d" % Game.data["items"].size()
	if power != _last_power:
		_show_delta(power - _last_power)
		_last_power = power
	for slot: String in _slots:
		_style_slot(_slots[slot], slot)
	for f: String in _tabs:
		_tabs[f].button_pressed = f == filter
	_build_strip()
	_build_list()
	var junk := Game.junk_items()
	var gold := 0
	for it in junk:
		gold += Game.item_value(it)
	_sell_btn.text = "Sell junk (%d) · %d gold" % [junk.size(), gold] if not junk.is_empty() else "No junk to sell"
	_sell_btn.disabled = junk.is_empty()
	_count.text = "Bag %d / %d" % [Game.data["items"].size(), Game.INVENTORY_CAP]


## The bag as a list, in groups: what would make you stronger, what you wear,
## the rest you could wear, what needs more skill, and other heroes' gear.
func _build_list() -> void:
	Ui.clear(_list)
	var groups := {"up": [], "worn": [], "bag": [], "locked": [], "others": []}
	for it in Game.data["items"]:
		if filter != "" and it["slot"] != filter:
			continue
		if str(it["cls"]) != hero_id:
			groups["others"].append(it)
		elif Game.owner_of(int(it["uid"])) == hero_id:
			groups["worn"].append(it)
		elif Game.wear_block(hero_id, it) != "":
			groups["locked"].append(it)
		elif _gain(it) > 0:
			groups["up"].append(it)
		else:
			groups["bag"].append(it)
	for k: String in groups:
		groups[k].sort_custom(func(a, b): return Game.item_power(a) > Game.item_power(b))
	groups["up"].sort_custom(func(a, b): return _gain(a) > _gain(b))
	groups["worn"].sort_custom(func(a, b): return DB.SLOTS.find(a["slot"]) < DB.SLOTS.find(b["slot"]))
	var any := false
	for spec in [["up", "Upgrades", GREEN], ["worn", "Wearing", GOLD], ["bag", "In your bag", DIM], ["locked", "Needs more skill", RED]]:
		var items: Array = groups[spec[0]]
		if items.is_empty():
			continue
		any = true
		# Exact copies stack into one row with a count.
		var stacks := {}
		var order := []
		for it in items:
			var k := Game.copy_key(it)
			if not stacks.has(k):
				stacks[k] = 0
				order.append(it)
			stacks[k] += 1
		_list.add_child(_section(spec[1], order.size(), spec[2]))
		for it in order:
			_list.add_child(_row(it, stacks[Game.copy_key(it)]))
	if not any:
		var empty := Ui.label("Nothing here yet.\nKill things, open chests, beat the bosses.", "Body", HORIZONTAL_ALIGNMENT_CENTER)
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.custom_minimum_size = Vector2(0, 110)
		empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty.modulate.a = 0.7
		_list.add_child(empty)
	var others: Array = groups["others"]
	if not others.is_empty():
		var tog := Button.new()
		tog.theme_type_variation = "Ghost"
		tog.focus_mode = Control.FOCUS_NONE
		tog.custom_minimum_size = Vector2(0, 58)
		tog.add_theme_font_size_override("font_size", 20)
		tog.text = ("▾ " if show_others else "▸ ") + "Other heroes' gear (%d)" % others.size()
		tog.pressed.connect(func():
			show_others = not show_others
			Sfx.play("ui_tap", -6.0)
			_refresh())
		_list.add_child(tog)
		if show_others:
			for it in others:
				_list.add_child(_row(it))


func _section(title: String, n: int, col: Color) -> Control:
	var l := Ui.label("%s  ·  %d" % [title.to_upper(), n], "Caption")
	l.add_theme_color_override("font_color", col)
	l.add_theme_font_size_override("font_size", 18)
	l.custom_minimum_size = Vector2(0, 34)
	l.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	return l


## How much power the piece adds over what the hero wears in its slot.
func _gain(it: Dictionary) -> int:
	var cur := Game.equipped(hero_id, it["slot"])
	return Game.item_power(it) - (Game.item_power(cur) if not cur.is_empty() else 0)


## True when the bag holds an upgrade the hero can wear in `slot`.
func _has_upgrade(slot: String) -> bool:
	for it in Game.data["items"]:
		if it["slot"] == slot and str(it["cls"]) == hero_id and Game.owner_of(int(it["uid"])) == "" and Game.wear_block(hero_id, it) == "" and _gain(it) > 0:
			return true
	return false


## The frame color: rarity, Diablo's orange for ancients, a set's own color.
func _frame_color(it: Dictionary) -> Color:
	if it.get("ancient", false):
		return Color(1.0, 0.55, 0.12)
	if Game.item_set(it) != "" and str(it.get("unique", "")) == "":
		return DB.SETS[Game.item_set(it)]["color"]
	return DB.rarity_color(it["rarity"])


## "T5 Verdite · Rare · Regalia set": what a piece is, in words.
func _describe(it: Dictionary) -> String:
	var parts := [_tier_tag(it), DB.RARITY_NAME[it["rarity"]]]
	if it.get("ancient", false):
		parts.append("Ancient")
	var st := Game.item_set(it)
	if st != "":
		parts.append("%s set" % DB.SETS[st]["short"])
	return " · ".join(parts)


func _tier_tag(it: Dictionary) -> String:
	return "T%d %s" % [int(it.get("mat", 0)) + 1, GearDB.material_name(str(it["cls"]), int(it.get("mat", 0)))]


## One bag row: icon, name and what it is on the left; on the right the one
## number that matters (power gained), or why it doesn't apply.
func _row(it: Dictionary, copies := 1) -> Control:
	var uid := int(it["uid"])
	var col := _frame_color(it)
	var mine: bool = str(it["cls"]) == hero_id
	var owner := Game.owner_of(uid)
	var block := Game.wear_block(hero_id, it)
	var is_sel: bool = not selected.is_empty() and int(selected["uid"]) == uid
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, ROW_H)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_stylebox_override("normal", _row_box(col, is_sel, 0.0))
	b.add_theme_stylebox_override("hover", _row_box(col, is_sel, 0.06))
	b.add_theme_stylebox_override("pressed", _row_box(col, true, 0.12))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var h := HBoxContainer.new()
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 10
	h.offset_right = -16
	h.add_theme_constant_override("separation", 14)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(h)
	var tile := Panel.new()
	tile.custom_minimum_size = Vector2(76, 76)
	tile.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tile.add_theme_stylebox_override("panel", _frame(col, 0.4, 12, 3))
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ic := ItemIcons.rect(it, 60, _icon_tone(it))
	ic.position = Vector2(8, 8)
	tile.add_child(ic)
	if _new_uids.has(uid) and owner == "" and mine:
		tile.add_child(_dot(Vector2(-4, -4)))
	h.add_child(tile)
	var tv := VBoxContainer.new()
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.alignment = BoxContainer.ALIGNMENT_CENTER
	tv.add_theme_constant_override("separation", 0)
	tv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var nm := Ui.label(str(it["name"]) + ("  ×%d" % copies if copies > 1 else ""), "Heading")
	nm.add_theme_font_size_override("font_size", 23)
	nm.add_theme_color_override("font_color", col.lightened(0.25))
	nm.clip_text = true
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	tv.add_child(nm)
	var sub := Ui.label(_describe(it), "Small")
	sub.add_theme_font_size_override("font_size", 17)
	sub.add_theme_color_override("font_color", DIM)
	sub.clip_text = true
	sub.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	tv.add_child(sub)
	h.add_child(tv)
	var right := VBoxContainer.new()
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	right.custom_minimum_size = Vector2(104, 0)
	right.add_theme_constant_override("separation", -4)
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(right)
	var big := Ui.label("", "Title", HORIZONTAL_ALIGNMENT_RIGHT)
	big.add_theme_font_size_override("font_size", 30)
	var small := Ui.label("", "Caption", HORIZONTAL_ALIGNMENT_RIGHT)
	small.add_theme_font_size_override("font_size", 15)
	if not mine:
		big.text = str(DB.HEROES[it["cls"]]["name"])
		big.add_theme_font_size_override("font_size", 20)
		big.add_theme_color_override("font_color", Color(DB.HEROES[it["cls"]]["color"]).lightened(0.2))
		small.text = "power %d" % Game.item_power(it)
		b.modulate = Color(1, 1, 1, 0.7)
	elif owner == hero_id:
		big.text = str(Game.item_power(it))
		big.add_theme_color_override("font_color", GOLD)
		small.text = "worn · power"
	elif block != "":
		big.text = "Lv %d" % GearDB.req_for(it)
		big.add_theme_font_size_override("font_size", 24)
		big.add_theme_color_override("font_color", RED)
		small.text = "%s needed" % DB.SKILL_NAME[GearDB.skill_for(hero_id, str(it["slot"]))]
		b.modulate = Color(1, 1, 1, 0.75)
	else:
		var g := _gain(it)
		big.text = ("+%d" % g) if g > 0 else str(g)
		big.add_theme_color_override("font_color", GREEN if g > 0 else DIM)
		small.text = "power"
	right.add_child(big)
	right.add_child(small)
	b.pressed.connect(func():
		Sfx.play("ui_tap", -4.0)
		_select(it))
	return b


func _row_box(col: Color, sel: bool, lift: float) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.09, 0.085, 0.1).lerp(Color(col.r, col.g, col.b), 0.08 + lift + (0.08 if sel else 0.0))
	s.set_corner_radius_all(14)
	s.border_width_left = 6
	s.border_color = col
	if sel:
		s.set_border_width_all(3)
		s.border_width_left = 6
		s.border_color = col.lightened(0.3)
	return s


## The hero's numbers, with `33 → 41 ▲` while a bag piece is being tried on.
func _build_strip() -> void:
	Ui.clear(_strip)
	var try_on := {}
	var it := selected
	if not it.is_empty() and str(it["cls"]) == hero_id and Game.owner_of(int(it["uid"])) != hero_id and Game.wear_block(hero_id, it) == "":
		try_on[it["slot"]] = it
	var now := Game.hero_stats(hero_id)
	var then := Game.hero_stats(hero_id, try_on) if not try_on.is_empty() else now
	for spec in [["Health", "hp", 1.0, "%d"], ["Damage", "dmg", 1.0, "%d"], ["Armor", "armor", 100.0, "%d%%"], ["Speed", "rate", 1.0, "%.2f"]]:
		var key: String = spec[1]
		var k: float = spec[2]
		var f: String = spec[3]
		var nv := DB.armor_dr(float(now[key])) if key == "armor" else float(now[key])
		var tv := DB.armor_dr(float(then[key])) if key == "armor" else float(then[key])
		var a: String = f % (nv * k)
		var b: String = f % (tv * k)
		var cell := VBoxContainer.new()
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.add_theme_constant_override("separation", -2)
		cell.add_child(Ui.label(spec[0], "Caption", HORIZONTAL_ALIGNMENT_CENTER))
		var val := Ui.label(a if a == b else "%s → %s" % [a, b], "Body", HORIZONTAL_ALIGNMENT_CENTER)
		val.add_theme_font_size_override("font_size", 22 if a == b else 19)
		if a != b:
			var up := tv > nv
			val.text += " ▲" if up else " ▼"
			val.add_theme_color_override("font_color", GREEN if up else RED)
		cell.add_child(val)
		_strip.add_child(cell)


## A slot row: the worn piece's icon, then slot, name, and tier · rarity ·
## power; on the right a green Equip button when the bag has better.
func _style_slot(b: Button, slot: String) -> void:
	var it := Game.equipped(hero_id, slot)
	var col := _frame_color(it) if not it.is_empty() else Color(0.45, 0.42, 0.4)
	b.add_theme_stylebox_override("normal", _row_box(col, false, 0.0))
	b.add_theme_stylebox_override("hover", _row_box(col, false, 0.04))
	b.add_theme_stylebox_override("pressed", _row_box(col, true, 0.08))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for c in b.get_children():
		b.remove_child(c)
		c.queue_free()
	var h := HBoxContainer.new()
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 12
	h.offset_right = -12
	h.add_theme_constant_override("separation", 16)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(h)
	var tile := Panel.new()
	tile.custom_minimum_size = Vector2(84, 84)
	tile.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if it.is_empty():
		var empty_box := _frame(col, 0.0, 14, 2)
		empty_box.bg_color = Color(0.05, 0.045, 0.06, 0.9)
		tile.add_theme_stylebox_override("panel", empty_box)
		var ph := Ui.icon_rect(GearDB.icon(hero_id, slot), 44, Color(0.5, 0.48, 0.46, 0.4))
		ph.position = Vector2(20, 20)
		tile.add_child(ph)
	else:
		tile.add_theme_stylebox_override("panel", _frame(col, 0.4, 14, 3))
		var ic := ItemIcons.rect(it, 64, _icon_tone(it))
		ic.position = Vector2(10, 10)
		tile.add_child(ic)
	h.add_child(tile)
	var tv := VBoxContainer.new()
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.alignment = BoxContainer.ALIGNMENT_CENTER
	tv.add_theme_constant_override("separation", 0)
	tv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cap := Ui.label(str(DB.SLOT_NAME[slot]).to_upper(), "Caption")
	cap.add_theme_font_size_override("font_size", 16)
	tv.add_child(cap)
	var nm := Ui.label("Nothing worn" if it.is_empty() else str(it["name"]), "Heading")
	nm.add_theme_font_size_override("font_size", 23)
	nm.add_theme_color_override("font_color", DIM if it.is_empty() else Color(0.93, 0.9, 0.85))
	nm.clip_text = true
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	tv.add_child(nm)
	if not it.is_empty():
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 8)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.add_child(_tier_chip(it))
		var rl := Ui.label(DB.RARITY_NAME[it["rarity"]], "Small")
		rl.add_theme_color_override("font_color", col.lightened(0.2))
		line.add_child(rl)
		var pl := Ui.label("· Power %d" % Game.item_power(it), "Small")
		pl.add_theme_color_override("font_color", DIM)
		line.add_child(pl)
		tv.add_child(line)
	h.add_child(tv)
	var best := _best_for(slot)
	if not best.is_empty():
		var eq := Button.new()
		eq.theme_type_variation = "PrimaryButton"
		eq.focus_mode = Control.FOCUS_NONE
		eq.custom_minimum_size = Vector2(118, 80)
		eq.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		eq.add_theme_font_size_override("font_size", 21)
		eq.text = "▲ +%d\nEquip" % _gain(best)
		eq.pressed.connect(func(): _equip(best))
		h.add_child(eq)
	else:
		var more := Ui.label("›", "Title")
		more.add_theme_font_size_override("font_size", 40)
		more.add_theme_color_override("font_color", Color(0.4, 0.38, 0.42))
		h.add_child(more)


## "T4 Mithril" on the material's own color: the tier, readable at a glance.
func _tier_chip(it: Dictionary) -> Control:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var st := StyleBoxFlat.new()
	st.bg_color = GearDB.accent(it).lerp(Color.WHITE, 0.35)
	st.set_corner_radius_all(6)
	st.content_margin_left = 7
	st.content_margin_right = 7
	p.add_theme_stylebox_override("panel", st)
	var l := Ui.label(_tier_tag(it), "Small")
	l.add_theme_font_size_override("font_size", 16)
	l.add_theme_color_override("font_color", Color(0.06, 0.05, 0.07))
	p.add_child(l)
	return p


## A small gold dot for "new": quieter than the camp's red one, since a
## fresh bag can be full of them.
func _dot(at: Vector2) -> Panel:
	var d := Panel.new()
	var st := StyleBoxFlat.new()
	st.bg_color = GOLD
	st.set_corner_radius_all(9)
	st.set_border_width_all(2)
	st.border_color = Color(0.1, 0.08, 0.06)
	d.add_theme_stylebox_override("panel", st)
	d.size = Vector2(18, 18)
	d.position = at
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return d


func _clear_new(slot: String) -> void:
	if slot == "":
		return
	for it in Game.data["items"]:
		if str(it["slot"]) == slot:
			_new_uids.erase(int(it["uid"]))


func _frame(col: Color, fill: float, radius: int, border: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.07, 0.065, 0.08, 0.9).lerp(Color(col.r, col.g, col.b, 0.9), fill * 0.5)
	s.set_corner_radius_all(radius)
	s.set_border_width_all(border)
	s.border_color = col
	s.anti_aliasing = true
	s.shadow_color = Color(col.r, col.g, col.b, 0.35 if fill > 0.0 else 0.0)
	s.shadow_size = 10 if fill > 0.0 else 0
	return s


# --- The piece's card ----------------------------------------------------------

## Slides up over the list with everything about one piece and what to do
## with it. The model above keeps wearing it, so you see the change.
func _open_card(it: Dictionary) -> void:
	_close_card(false)
	var uid := int(it["uid"])
	var col := _frame_color(it)
	var owner := Game.owner_of(uid)
	var is_worn := owner == hero_id
	var mine: bool = str(it["cls"]) == hero_id
	var block := Game.wear_block(hero_id, it)
	_card = PanelContainer.new()
	_card.theme_type_variation = "Card"
	_card.anchor_left = 0.0
	_card.anchor_right = 1.0
	_card.anchor_top = 1.0
	_card.anchor_bottom = 1.0
	_card.offset_left = 10.0
	_card.offset_right = -10.0
	_card.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_card.offset_bottom = -Ui.safe_insets(10).w
	_card.mouse_filter = Control.MOUSE_FILTER_STOP
	var bs := StyleBoxFlat.new()
	bs.bg_color = Color(0.1, 0.09, 0.11, 0.98)
	bs.set_corner_radius_all(22)
	bs.set_border_width_all(3)
	bs.border_color = col
	bs.shadow_color = Color(0, 0, 0, 0.6)
	bs.shadow_size = 24
	bs.content_margin_left = 20
	bs.content_margin_right = 20
	bs.content_margin_top = 16
	bs.content_margin_bottom = 18
	_card.add_theme_stylebox_override("panel", bs)
	add_child(_card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	_card.add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	var tile := Panel.new()
	tile.custom_minimum_size = Vector2(84, 84)
	tile.add_theme_stylebox_override("panel", _frame(col, 0.45, 14, 3))
	var ic := ItemIcons.rect(it, 68, _icon_tone(it))
	ic.position = Vector2(8, 8)
	tile.add_child(ic)
	head.add_child(tile)
	var hv := VBoxContainer.new()
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hv.alignment = BoxContainer.ALIGNMENT_CENTER
	hv.add_theme_constant_override("separation", 0)
	var nm := Ui.label(str(it["name"]), "Heading")
	nm.add_theme_font_size_override("font_size", 26)
	nm.add_theme_color_override("font_color", col.lightened(0.25))
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hv.add_child(nm)
	var sl := Ui.label("%s · Power %d" % [_describe(it), Game.item_power(it)], "Small")
	sl.add_theme_color_override("font_color", DIM)
	sl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hv.add_child(sl)
	head.add_child(hv)
	var x := _round_button("✕", func(): _close_card(true))
	x.custom_minimum_size = Vector2(56, 56)
	x.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	head.add_child(x)
	v.add_child(head)
	# What it replaces, so the comparison has a name.
	var cur := Game.equipped(hero_id, it["slot"])
	if mine and not is_worn and not cur.is_empty():
		var g := _gain(it)
		var cmp := Ui.label("Instead of %s: %s power" % [str(cur["name"]), ("+%d" % g) if g > 0 else str(g)], "Small")
		cmp.add_theme_color_override("font_color", GREEN if g > 0 else DIM)
		cmp.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(cmp)
	var stats := HFlowContainer.new()
	stats.add_theme_constant_override("h_separation", 16)
	stats.add_theme_constant_override("v_separation", 2)
	for line in Game.describe_stats(it):
		var l := Ui.label(line, "Body")
		l.add_theme_font_size_override("font_size", 20)
		l.add_theme_color_override("font_color", Color(1.0, 0.65, 0.3) if line.begins_with("Start") else (Color(0.45, 1.0, 0.6) if line.begins_with("Set") else Color(0.6, 0.78, 1.0)))
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if line.begins_with("Set") or line.begins_with("Start") else TextServer.AUTOWRAP_OFF
		if l.autowrap_mode != TextServer.AUTOWRAP_OFF:
			l.custom_minimum_size = Vector2(620, 0)
		stats.add_child(l)
	v.add_child(stats)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	if is_worn:
		row.add_child(_action("Remove", "", func(): _unequip(it["slot"])))
	elif mine:
		var eq := _action("Equip" if block == "" else block.trim_prefix("Requires "), "PrimaryButton", func(): _equip(it))
		eq.disabled = block != ""
		row.add_child(eq)
	var insp := _action("Inspect", "", func(): _inspect(it))
	insp.icon = Ui.icon("magic-swirl")
	row.add_child(insp)
	if owner == "":
		var sell := _action("Sell %d" % Game.item_value(it), "", Callable())
		sell.icon = Ui.icon("two-coins")
		var needs_confirm := DB.RARITIES.find(it["rarity"]) >= 2
		sell.pressed.connect(func():
			if needs_confirm and sell.text != "Tap to sell":
				sell.text = "Tap to sell"
				Sfx.play("ui_error", -8.0)
				return
			Game.salvage(uid)
			Sfx.play("coin", -2.0)
			_close_card(true))
		row.add_child(sell)
	v.add_child(row)
	# Gold sinks live behind one button, on a panel that says what they do.
	var can_temper: bool = int(it.get("mat", 0)) < GearDB.TIERS - 1
	if str(it.get("unique", "")) == "" and mine and (can_temper or it["rarity"] != "common"):
		var imp := _action("Improve  ·  Temper / Reforge", "", func(): _open_forge(it))
		imp.icon = Ui.icon("anvil")
		v.add_child(imp)
	SwipeDismiss.attach(_card, func(): _close_card(true), null, true)
	_card.modulate.a = 0.0
	_card.create_tween().tween_property(_card, "modulate:a", 1.0, 0.16)


## Temper and Reforge, each with what it does, what it costs and the gold
## you have, so neither is a mystery button.
func _open_forge(it: Dictionary) -> void:
	var uid := int(it["uid"])
	var box := _modal()
	var head := HBoxContainer.new()
	var title := Ui.label("Improve", "Heading")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var purse := Ui.label("%s gold" % Ui.fmt_num(Game.gold()), "Value")
	purse.add_theme_color_override("font_color", GOLD)
	purse.add_theme_font_size_override("font_size", 24)
	head.add_child(Ui.icon_rect("two-coins", 30, GOLD))
	head.add_child(purse)
	box.add_child(head)
	var nm := Ui.label("%s · Power %d" % [str(it["name"]), Game.item_power(it)], "Small")
	nm.add_theme_color_override("font_color", _frame_color(it).lightened(0.25))
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(nm)
	var mat := int(it.get("mat", 0))
	if mat < GearDB.TIERS - 1:
		var next := it.duplicate(true)
		var k := (1.0 + 0.22 * (mat + 1)) / (1.0 + 0.22 * mat)
		for key in next["stats"]:
			next["stats"][key] = int(round(float(next["stats"][key]) * k))
		next["mat"] = mat + 1
		var cost := DB.temper_cost(it)
		var c := _forge_card(box, "sword-smithing", "Temper", "Raise it one material tier. Every stat on it grows, and it takes the new material's look.")
		c.add_child(Ui.label("%s  →  %s    Power %d → %d" % [_tier_tag(it), _tier_tag(next), Game.item_power(it), Game.item_power(next)], "Body"))
		var block := Game.wear_block(hero_id, next)
		if block != "":
			var bl := Ui.label("To wear it after: %s" % block.trim_prefix("Requires "), "Small")
			bl.add_theme_color_override("font_color", RED)
			c.add_child(bl)
		var tb := _action("Temper · %s gold" % Ui.fmt_num(cost), "GoldButton", func():
			if Game.temper(uid):
				Sfx.play("levelup", -4.0)
				_close_popup()
				_say("Tempered to %s" % GearDB.material_name(str(it["cls"]), int(Game.item(uid)["mat"])))
				_select(Game.item(uid), true)
			else:
				Sfx.play("ui_error", -6.0))
		if Game.gold() < cost:
			tb.text = "Need %s more gold" % Ui.fmt_num(cost - Game.gold())
			tb.disabled = true
		c.add_child(tb)
	if it["rarity"] != "common":
		var main: String = DB.SLOT_MAIN[it["slot"]]
		var cost2 := DB.reforge_cost(it)
		var c2 := _forge_card(box, "anvil", "Reforge", "Reroll the bonus stats for a new mix. %s stays." % (DB.AFFIXES[main]["label"] % int(it["stats"][main])))
		var extra := PackedStringArray()
		for key in it["stats"]:
			if key != main:
				extra.append(DB.AFFIXES[key]["label"] % int(it["stats"][key]))
		if not extra.is_empty():
			var el := Ui.label("Rerolled: " + ", ".join(extra), "Small")
			el.add_theme_color_override("font_color", Color(0.6, 0.78, 1.0))
			el.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			c2.add_child(el)
		var rb := _action("Reforge · %s gold" % Ui.fmt_num(cost2), "", func():
			if Game.reforge(uid):
				Sfx.play("gear_equip", 0.0, 1.2)
				_close_popup()
				_say("Reforged")
				_select(Game.item(uid), true)
			else:
				Sfx.play("ui_error", -6.0))
		if Game.gold() < cost2:
			rb.text = "Need %s more gold" % Ui.fmt_num(cost2 - Game.gold())
			rb.disabled = true
		c2.add_child(rb)


func _forge_card(box: VBoxContainer, icon: String, title: String, what: String) -> VBoxContainer:
	var card := PanelContainer.new()
	card.theme_type_variation = "Card"
	box.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	card.add_child(v)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	h.add_child(Ui.icon_rect(icon, 32, GOLD))
	h.add_child(Ui.label(title, "Heading"))
	v.add_child(h)
	var w := Ui.label(what, "Body")
	w.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(w)
	return v


func _close_card(deselect: bool) -> void:
	if _card and is_instance_valid(_card):
		_card.queue_free()
	_card = null
	if deselect and not selected.is_empty():
		selected = {}
		_dress()
		_refresh()


func _action(text: String, variation: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	if variation != "":
		b.theme_type_variation = variation
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, 64)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 23)
	b.clip_text = true
	if cb.is_valid():
		b.pressed.connect(cb)
	return b


func _show_delta(d: int) -> void:
	_delta.text = ("▲ +%d" % d) if d > 0 else ("▼ %d" % d)
	_delta.add_theme_color_override("font_color", GREEN if d > 0 else RED)
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

## Tapping a piece tries it on and opens its card; tapping it again closes it.
func _select(it: Dictionary, keep := false) -> void:
	if not keep and not selected.is_empty() and int(selected["uid"]) == int(it["uid"]):
		_close_card(true)
		return
	selected = it
	_new_uids.erase(int(it["uid"]))
	_dress()
	_refresh()
	_open_card(it)


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
	selected = {}
	show_others = false
	_close_card(false)
	_build_actor()
	_last_power = Game.power_score(hero_id)
	_delta.text = ""
	_refresh()


## A slot opens the bag filtered to it.
func _on_slot(slot: String) -> void:
	Sfx.play("ui_tap", -4.0)
	filter = slot
	show_others = false
	_clear_new(slot)
	_set_bag(true)
	_refresh()


## The piece the bag holds that would add the most power in `slot`, or {}.
func _best_for(slot: String) -> Dictionary:
	var best := {}
	for it in Game.data["items"]:
		if it["slot"] != slot or str(it["cls"]) != hero_id or Game.owner_of(int(it["uid"])) != "" or Game.wear_block(hero_id, it) != "":
			continue
		if _gain(it) > 0 and (best.is_empty() or _gain(it) > _gain(best)):
			best = it
	return best


## After a change, redress the model with a short flash.
func _redress() -> void:
	_dress()
	var t := create_tween()
	t.tween_method(_actor.set_flash, 0.9, 0.0, 0.3)
	Portraits.rebuild(self, hero_id)
	if Game.new_tier >= 0:
		_reveal_tier(Game.new_tier)
		Game.new_tier = -1


func _equip(it: Dictionary) -> void:
	Game.equip(hero_id, int(it["uid"]))
	Sfx.play("gear_equip", -2.0)
	selected = {}
	_close_card(false)
	_redress()
	_refresh()


func _unequip(slot: String) -> void:
	Game.unequip(hero_id, slot)
	Sfx.play("ui_back", -4.0)
	selected = {}
	_close_card(false)
	_redress()
	_refresh()


func _equip_best() -> void:
	var n := Game.equip_best(hero_id)
	if n == 0:
		_say("Already wearing your best", Color(0.8, 0.8, 0.8))
		Sfx.play("ui_error", -8.0)
		return
	Sfx.play("gear_equip", -2.0)
	selected = {}
	_close_card(false)
	_redress()
	_say("%d piece%s equipped" % [n, "" if n == 1 else "s"], GREEN)
	_refresh()


func _inspect(it: Dictionary) -> void:
	var v := GearInspect.new()
	add_child(v)
	v.open(it)


## A first piece of a higher material: rays behind the hero, its name large.
func _reveal_tier(mat: int) -> void:
	var col := GearDB.accent({"cls": hero_id, "mat": mat})
	var r := TierReveal.new()
	add_child(r)
	# The rays go behind the hero (under the 3D stage), the words in front.
	r.play(GearDB.material_name(hero_id, mat), "Tier %d unlocked · a new look" % (mat + 1), col, _stage, 1)
	Sfx.play("levelup", -2.0)
	Ui.buzz(40, 0.5)
	var t := create_tween()
	t.tween_method(_actor.set_flash, 1.0, 0.0, 0.6)
	_spin = 9.0


func _confirm_sell_junk() -> void:
	var junk := Game.junk_items()
	if junk.is_empty():
		return
	var gold := 0
	for it in junk:
		gold += Game.item_value(it)
	var box := _modal()
	box.add_child(Ui.label("Sell %d items?" % junk.size(), "Heading", HORIZONTAL_ALIGNMENT_CENTER))
	var msg := Ui.label("Common and magic gear nobody is wearing, and spare copies of pieces you have twice.\nYou get %d gold." % gold, "Body", HORIZONTAL_ALIGNMENT_CENTER)
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(msg)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.add_child(_action("Keep", "", _close_popup))
	row.add_child(_action("Sell", "GoldButton", func():
		var got := 0
		for it in Game.junk_items():
			got += Game.salvage(int(it["uid"]))
		Sfx.play("coin", 0.0)
		_close_popup()
		_say("+%d gold" % got)
		if not selected.is_empty() and Game.item(int(selected["uid"])).is_empty():
			selected = {}
			_close_card(false)
			_dress()
		_refresh()))
	box.add_child(row)


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


# --- Closing -------------------------------------------------------------------

func _close() -> void:
	Game.mark_items_seen()
	lobby.refresh_gear()
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.18)
	t.tween_callback(func():
		closed.emit()
		queue_free())


## An item's icon color: its metal, hide or cloth (Old School style), kept
## light enough to read on the rarity frame.
func _icon_tone(it: Dictionary) -> Color:
	if not it.has("cls"):
		return ICON_TONE
	return ICON_TONE.lerp(GearDB.accent(it).lerp(GearDB.item_color(it), 0.5), 0.6)
