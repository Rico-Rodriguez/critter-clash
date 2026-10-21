class_name Equipment
extends Control
## The equipment screen, Old School style: your hero big in the middle (drag to
## turn them), the five slots either side, and the bag underneath. Tapping a
## piece tries it on the model right away; Equip makes it stick. Gear is
## class-specific, so the bag shows this hero's pieces first and the others'
## under "Others".

signal closed

const TILE := 118.0
const SLOT_SIDE := {"helm": 0, "chest": 0, "legs": 0, "weapon": 1, "trinket": 1}
const GOLD := Color(0.91, 0.71, 0.35)

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
var _grid: GridContainer
var _filter_buttons := {}
var _others_btn: Button
var _sell_btn: Button
var _info: PanelContainer
var _toast: Label
var _hint: Label
var _popup: Control
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
	col.add_theme_constant_override("separation", 10)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	safe.add_child(col)
	_build_header(col)
	_build_stage(col)
	_info = PanelContainer.new()
	_info.theme_type_variation = "Card"
	col.add_child(_info)
	_build_bag(col)
	_toast = Ui.label("", "HudLabel", HORIZONTAL_ALIGNMENT_CENTER)
	_toast.add_theme_font_size_override("font_size", 26)
	_toast.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_toast.offset_top = 560.0
	_toast.modulate.a = 0.0
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
func _build_stage(col: VBoxContainer) -> void:
	var stage := Control.new()
	stage.custom_minimum_size = Vector2(0, 430)
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
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
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.52, 0.7)
	env.ambient_light_energy = 0.75
	var we := WorldEnvironment.new()
	we.environment = env
	_vp.add_child(we)
	var key := DirectionalLight3D.new()
	key.light_color = Color(1.0, 0.86, 0.68)
	key.light_energy = 1.6
	key.rotation_degrees = Vector3(-35, 40, 0)
	_vp.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.light_color = Color(0.5, 0.65, 1.0)
	rim.light_energy = 1.0
	rim.rotation_degrees = Vector3(-20, -150, 0)
	_vp.add_child(rim)
	var floor_m := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.05
	cyl.bottom_radius = 1.1
	cyl.height = 0.08
	floor_m.mesh = cyl
	floor_m.position = Vector3(0, -0.04, 0)
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.12, 0.1, 0.1)
	fm.roughness = 0.9
	floor_m.material_override = fm
	_vp.add_child(floor_m)
	var cam := Camera3D.new()
	cam.fov = 30.0
	_vp.add_child(cam)
	cam.look_at_from_position(Vector3(0, 1.35, 4.5), Vector3(0, 0.93, 0), Vector3.UP)
	for slot: String in SLOT_SIDE:
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(104, 104)
		b.size = Vector2(104, 104)
		b.pressed.connect(func(): _on_slot(slot))
		stage.add_child(b)
		_slots[slot] = b
	# Left column: helm, chest, legs. Right column: weapon, offhand.
	var order := {"helm": 0, "chest": 1, "legs": 2, "weapon": 0, "trinket": 1}
	for slot: String in _slots:
		var b: Button = _slots[slot]
		var right: bool = SLOT_SIDE[slot] == 1
		b.anchor_left = 1.0 if right else 0.0
		b.anchor_right = b.anchor_left
		b.offset_left = -118.0 if right else 6.0
		b.offset_right = -6.0 if right else 118.0
		b.offset_top = 18.0 + order[slot] * 124.0
		b.offset_bottom = b.offset_top + 108.0
	_hint = Ui.label("Drag to turn", "Caption", HORIZONTAL_ALIGNMENT_CENTER)
	_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_hint.offset_top = -34.0
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.modulate.a = 0.6
	stage.add_child(_hint)


func _build_bag(col: VBoxContainer) -> void:
	var filters := HBoxContainer.new()
	filters.add_theme_constant_override("separation", 4)
	for f in ["", "weapon", "helm", "chest", "legs", "trinket"]:
		var b := Button.new()
		b.theme_type_variation = "Ghost"
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 54)
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
	_others_btn = Button.new()
	_others_btn.theme_type_variation = "Ghost"
	_others_btn.toggle_mode = true
	_others_btn.focus_mode = Control.FOCUS_NONE
	_others_btn.custom_minimum_size = Vector2(120, 54)
	_others_btn.add_theme_font_size_override("font_size", 20)
	_others_btn.pressed.connect(func():
		show_others = _others_btn.button_pressed
		Sfx.play("ui_tap", -6.0)
		_refresh())
	filters.add_child(_others_btn)
	col.add_child(filters)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 150)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
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
	best.custom_minimum_size = Vector2(0, 68)
	best.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	best.focus_mode = Control.FOCUS_NONE
	best.add_theme_font_size_override("font_size", 26)
	best.pressed.connect(_equip_best)
	foot.add_child(best)
	_sell_btn = Button.new()
	_sell_btn.custom_minimum_size = Vector2(0, 68)
	_sell_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sell_btn.focus_mode = Control.FOCUS_NONE
	_sell_btn.add_theme_font_size_override("font_size", 21)
	_sell_btn.pressed.connect(_confirm_sell_junk)
	foot.add_child(_sell_btn)
	col.add_child(foot)


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
	_sub.text = "Lv %d · Power %d" % [int(Game.hero(hero_id)["level"]), power]
	if power != _last_power:
		_show_delta(power - _last_power)
		_last_power = power
	for slot: String in _slots:
		_style_slot(_slots[slot], slot)
	for f: String in _filter_buttons:
		_filter_buttons[f].button_pressed = f == filter
	var others := 0
	for it in Game.data["items"]:
		if str(it["cls"]) != hero_id:
			others += 1
	_others_btn.text = "Others %d" % others
	_others_btn.button_pressed = show_others
	Ui.clear(_grid)
	var items: Array = Game.data["items"].duplicate()
	items.sort_custom(func(a, b):
		var ea := 1 if Game.owner_of(int(a["uid"])) == hero_id else 0
		var eb := 1 if Game.owner_of(int(b["uid"])) == hero_id else 0
		if ea != eb:
			return ea > eb
		var wa := 1 if Game.wear_block(hero_id, a) == "" else 0
		var wb := 1 if Game.wear_block(hero_id, b) == "" else 0
		if wa != wb:
			return wa > wb
		return Game.item_score(a) > Game.item_score(b))
	var shown := 0
	for it in items:
		if (str(it["cls"]) != hero_id) != show_others:
			continue
		if filter != "" and it["slot"] != filter:
			continue
		_grid.add_child(_tile(it))
		shown += 1
	if shown == 0:
		var empty := Ui.label("Nothing here yet.\nKill things, open chests, beat the bosses." if not show_others else "No gear for the other heroes.", "Body", HORIZONTAL_ALIGNMENT_CENTER)
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.custom_minimum_size = Vector2(600, 90)
		_grid.add_child(empty)
	var junk := Game.junk_items()
	var gold := 0
	for it in junk:
		gold += Game.item_value(it)
	_sell_btn.text = "Sell junk (%d) · %d gold" % [junk.size(), gold] if not junk.is_empty() else "No junk to sell"
	_sell_btn.disabled = junk.is_empty()
	_build_info()


func _style_slot(b: Button, slot: String) -> void:
	var it := Game.equipped(hero_id, slot)
	var sel: bool = not selected.is_empty() and selected["slot"] == slot and str(selected["cls"]) == hero_id
	var col := DB.rarity_color(it["rarity"]) if not it.is_empty() else Color(0.45, 0.42, 0.4)
	var w := 6 if sel else 4
	b.add_theme_stylebox_override("normal", _frame(col.lightened(0.5) if sel else col, 0.0 if it.is_empty() else 0.25, 16, w))
	b.add_theme_stylebox_override("hover", _frame(col, 0.3, 16, w))
	b.add_theme_stylebox_override("pressed", _frame(col, 0.4, 16, w))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for c in b.get_children():
		c.queue_free()
	var ic_col := GearDB.item_color(it) if not it.is_empty() else Color(0.5, 0.48, 0.46, 0.55)
	var ic := Ui.icon_rect(GearDB.icon(hero_id, slot) if it.is_empty() else GearDB.item_icon(it), 58, ic_col)
	ic.position = Vector2(23, 8)
	b.add_child(ic)
	var cap_text: String = DB.SLOT_NAME[slot] if it.is_empty() else GearDB.material_name(hero_id, int(it["mat"]))
	var cap := Ui.label(cap_text, "HudLabel", HORIZONTAL_ALIGNMENT_CENTER)
	cap.add_theme_font_size_override("font_size", 16)
	cap.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	cap.offset_top = -34
	cap.offset_bottom = -6
	cap.clip_text = true
	b.add_child(cap)


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


func _tile(it: Dictionary) -> Control:
	var uid := int(it["uid"])
	var col := DB.rarity_color(it["rarity"])
	var owner := Game.owner_of(uid)
	var mine: bool = str(it["cls"]) == hero_id
	var blocked := Game.wear_block(hero_id, it)
	var is_sel: bool = not selected.is_empty() and int(selected["uid"]) == uid
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, TILE)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.focus_mode = Control.FOCUS_NONE
	var bw := 6 if is_sel else 3
	b.add_theme_stylebox_override("normal", _frame(col.lightened(0.5) if is_sel else col, 0.0, 12, bw))
	b.add_theme_stylebox_override("hover", _frame(col, 0.25, 12, bw))
	b.add_theme_stylebox_override("pressed", _frame(col, 0.4, 12, bw))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var ic := Ui.icon_rect(GearDB.item_icon(it), 58, GearDB.item_color(it))
	ic.position = Vector2(30, 12)
	b.add_child(ic)
	var cap := Ui.label(GearDB.material_name(str(it["cls"]), int(it["mat"])), "HudLabel", HORIZONTAL_ALIGNMENT_CENTER)
	cap.add_theme_font_size_override("font_size", 16)
	cap.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	cap.offset_top = -32
	cap.offset_bottom = -6
	cap.clip_text = true
	b.add_child(cap)
	if not mine or blocked != "":
		b.modulate = Color(1, 1, 1, 0.5)
	if _new_uids.has(uid) and owner == "":
		var dot := ColorRect.new()
		dot.color = Color(0.4, 1.0, 0.5)
		dot.size = Vector2(14, 14)
		dot.position = Vector2(8, 8)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(dot)
	if owner == "" and mine and blocked == "" and _beats_worn(it):
		var up := Ui.label("▲", "HudLabel", HORIZONTAL_ALIGNMENT_RIGHT)
		up.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5))
		up.add_theme_font_size_override("font_size", 24)
		up.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		up.offset_left = -40
		up.offset_right = -8
		up.offset_top = 4
		b.add_child(up)
	elif mine and blocked != "" and owner == "":
		var lk := Ui.label("🔒", "HudLabel", HORIZONTAL_ALIGNMENT_RIGHT)
		lk.add_theme_font_size_override("font_size", 20)
		lk.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		lk.offset_left = -40
		lk.offset_right = -8
		lk.offset_top = 4
		b.add_child(lk)
	if owner == hero_id:
		b.add_child(_badge("E", DB.HEROES[owner]["color"], Vector2(8, 8)))
	elif not mine:
		b.add_child(_badge(str(DB.HEROES[it["cls"]]["name"]).left(1), DB.HEROES[it["cls"]]["color"], Vector2(8, 8)))
	b.pressed.connect(func():
		Sfx.play("ui_tap", -4.0)
		_select(it))
	return b


func _badge(text: String, col: Color, at: Vector2) -> Panel:
	var badge := Panel.new()
	badge.size = Vector2(28, 28)
	badge.position = at
	var bs := StyleBoxFlat.new()
	bs.bg_color = col
	bs.set_corner_radius_all(14)
	bs.set_border_width_all(2)
	bs.border_color = Color(0, 0, 0, 0.7)
	badge.add_theme_stylebox_override("panel", bs)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t := Ui.label(text, "HudLabel", HORIZONTAL_ALIGNMENT_CENTER)
	t.add_theme_font_size_override("font_size", 16)
	t.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_child(t)
	return badge


## True when `it` is a better pick than what the current hero wears there.
func _beats_worn(it: Dictionary) -> bool:
	var cur := Game.equipped(hero_id, it["slot"])
	return cur.is_empty() or Game.item_score(it) > Game.item_score(cur)


# --- The detail strip -------------------------------------------------------

func _build_info() -> void:
	Ui.clear(_info)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	_info.add_child(v)
	if selected.is_empty():
		var hint := Ui.label("Tap a piece to try it on.", "Body", HORIZONTAL_ALIGNMENT_CENTER)
		hint.add_theme_font_size_override("font_size", 22)
		hint.add_theme_color_override("font_color", Color(0.7, 0.66, 0.6))
		v.add_child(hint)
		return
	var it := selected
	var uid := int(it["uid"])
	var col := DB.rarity_color(it["rarity"])
	var owner := Game.owner_of(uid)
	var is_worn := owner == hero_id
	var mine: bool = str(it["cls"]) == hero_id
	var cur := Game.equipped(hero_id, it["slot"])
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	head.add_child(Ui.icon_rect(GearDB.item_icon(it), 56, GearDB.item_color(it)))
	var hv := VBoxContainer.new()
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hv.add_theme_constant_override("separation", 0)
	var nm := Ui.label(str(it["name"]), "Heading")
	nm.add_theme_font_size_override("font_size", 25)
	nm.add_theme_color_override("font_color", col.lightened(0.2))
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hv.add_child(nm)
	var req_skill := GearDB.skill_for(str(it["cls"]), str(it["slot"]))
	var req := GearDB.req_for(it)
	var sub := "%s · %s %d" % [DB.RARITY_NAME[it["rarity"]], DB.SKILL_NAME[req_skill], req]
	if owner != "" and owner != hero_id:
		sub += " · worn by %s" % DB.HEROES[owner]["name"]
	var sl := Ui.label(sub, "Small")
	var block := Game.wear_block(hero_id, it)
	sl.add_theme_color_override("font_color", Color(1.0, 0.5, 0.42) if block != "" else Color(0.7, 0.68, 0.62))
	hv.add_child(sl)
	head.add_child(hv)
	v.add_child(head)
	var stats := HFlowContainer.new()
	stats.add_theme_constant_override("h_separation", 14)
	stats.add_theme_constant_override("v_separation", 0)
	for line in Game.describe_stats(it):
		var l := Ui.label(line, "Body")
		l.add_theme_font_size_override("font_size", 20)
		l.add_theme_color_override("font_color", Color(1.0, 0.65, 0.3) if line.begins_with("Start") else Color(0.6, 0.78, 1.0))
		stats.add_child(l)
	if mine and not is_worn and not cur.is_empty():
		for d in Game.compare(it, cur):
			var up: bool = d["diff"] > 0
			var dl := Ui.label("%s %s" % ["▲" if up else "▼", d["text"]], "Body")
			dl.add_theme_font_size_override("font_size", 20)
			dl.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5) if up else Color(1.0, 0.45, 0.4))
			stats.add_child(dl)
	v.add_child(stats)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	if is_worn:
		row.add_child(_action("Remove", "", func(): _unequip(it["slot"])))
	else:
		var eq := _action("Equip" if block == "" else block, "PrimaryButton", func(): _equip(it))
		eq.disabled = block != ""
		row.add_child(eq)
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
				selected = {}
				_dress()
				_refresh())
			row.add_child(sell)
	v.add_child(row)


func _action(text: String, variation: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	if variation != "":
		b.theme_type_variation = variation
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, 64)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 24)
	if cb.is_valid():
		b.pressed.connect(cb)
	return b


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

func _select(it: Dictionary) -> void:
	selected = it if selected.is_empty() or int(selected["uid"]) != int(it["uid"]) else {}
	_dress()
	_refresh()


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
	_build_actor()
	_last_power = Game.power_score(hero_id)
	_delta.text = ""
	_refresh()


func _on_slot(slot: String) -> void:
	Sfx.play("ui_tap", -4.0)
	filter = slot
	show_others = false
	var it := Game.equipped(hero_id, slot)
	selected = it
	_dress()
	_refresh()


## After a change, redress the model with a short flash.
func _redress() -> void:
	_dress()
	var t := create_tween()
	t.tween_method(_actor.set_flash, 0.9, 0.0, 0.3)
	Portraits.rebuild(self, hero_id)


func _equip(it: Dictionary) -> void:
	Game.equip(hero_id, int(it["uid"]))
	Sfx.play("gear_equip", -2.0)
	selected = Game.item(int(it["uid"]))
	_redress()
	_refresh()


func _unequip(slot: String) -> void:
	Game.unequip(hero_id, slot)
	Sfx.play("ui_back", -4.0)
	selected = {}
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
	_redress()
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
