class_name Equipment
extends Control
## The equipment screen: your hero in the middle (drag to turn them) with the
## five slots around them, their real stats underneath, and the bag below as a
## grid of tiles. One color means one thing: a tile's frame is the piece's
## material tier, grey to red. Pips under the icon count its bonus stats, and
## a green ▲ marks a piece that beats what is worn. The slots around the hero
## pick which collection shows below. Tapping a tile tries it on: the stat
## strip shows the change, and its card takes the place of the hero buttons
## without covering the collection. Gear is class-specific, so other heroes' pieces sit
## folded at the bottom of the bag.

const DragScroll := preload("res://src/ui/drag_scroll.gd")
const ItemIcons := preload("res://src/ui/item_icons.gd")

signal closed

const GOLD := Color(0.91, 0.71, 0.35)
const GREEN := Color(0.4, 1.0, 0.5)
const RED := Color(1.0, 0.45, 0.4)
const DIM := Color(0.66, 0.63, 0.58)
const EMPTY := Color(0.36, 0.34, 0.38)
## Icon base tone; the material's color is mixed in (Old School style).
const ICON_TONE := Color(0.88, 0.84, 0.76)
const STAGE_H := 372.0
const SLOT_TILE := 108.0
const TILE := 118.0
const LINE_TILE := 104.0
const COLS := 5
## The place under the stats that holds the skills or the piece's card.
const REGION_H := 176.0
## Slots down the left of the hero, then down the right.
const LEFT_SLOTS := ["helm", "chest", "legs"]
const RIGHT_SLOTS := ["weapon", "trinket"]
const SLOT_ORDER := ["weapon", "helm", "chest", "legs", "trinket"]

var ui: LobbyUI
var lobby: Node3D
## Shown as the camp's Gear tab: no way back (the tab bar is the way out).
var tab_mode := false
var hero_id := "knight"
var filter := "weapon"
var selected: Dictionary = {}

var _title: Label
var _faces: HBoxContainer
var _slots := {}
var _best_btn: Button
var _best_ups := 0
var _strip: GridContainer
var _hero_row: HBoxContainer
var _list: VBoxContainer
var _scroll: DragScroll
var _count: Label
var _toast: Label
var _hint: Label
var _stage: Control
var _popup: Control
var _card: PanelContainer
## Where the card sits, in place of the hero buttons.
var _card_box: VBoxContainer
var _hero_panel: VBoxContainer
var _skills_btn: Button
var _slot_title: Label
var _new_uids := {}

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
	if tab_mode:
		safe.add_theme_constant_override("margin_bottom", 10)
	add_child(safe)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	safe.add_child(col)
	_build_header(col)
	_build_top(col)
	_build_bag(col)
	_toast = Ui.label("", "HudLabel", HORIZONTAL_ALIGNMENT_CENTER)
	_toast.add_theme_font_size_override("font_size", 26)
	_toast.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_toast.offset_top = 420.0
	_toast.modulate.a = 0.0
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_toast)
	_build_actor()
	_refresh()
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.2)


# --- Layout ----------------------------------------------------------------

## A plain way back on the left, the hero's name in the middle, and the
## heroes you own as faces on the right: tap a face to dress that hero.
func _build_header(col: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(row)
	var back := Button.new()
	back.theme_type_variation = "Ghost"
	back.text = "‹ Camp"
	back.focus_mode = Control.FOCUS_NONE
	back.custom_minimum_size = Vector2(0, 64)
	back.add_theme_font_size_override("font_size", 26)
	back.pressed.connect(func():
		Sfx.play("ui_tap", -4.0)
		_close())
	if not tab_mode:
		row.add_child(back)
	_title = Ui.label("", "Heading", HORIZONTAL_ALIGNMENT_CENTER)
	_title.add_theme_font_size_override("font_size", 28)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.clip_text = true
	_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	# The name opens the hero's card (power, Super, unlock).
	_title.mouse_filter = Control.MOUSE_FILTER_STOP
	_title.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and not e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_open_hero(hero_id))
	row.add_child(_title)
	_faces = HBoxContainer.new()
	_faces.add_theme_constant_override("separation", 8)
	row.add_child(_faces)


## One face per hero; the one shown is lit and ringed in its color. A locked
## hero's face is dark and opens its card (how to unlock it).
func _build_faces() -> void:
	Ui.clear(_faces)
	for id: String in DB.HERO_ORDER:
		var on := id == hero_id
		var open: bool = Game.hero(id)["unlocked"]
		var d: Dictionary = DB.HEROES[id]
		var f := Button.new()
		f.flat = true
		f.focus_mode = Control.FOCUS_NONE
		f.custom_minimum_size = Vector2(64, 64)
		var cc := CenterContainer.new()
		cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var p := ui._portrait(id, d["color"] if on else Color(0.45, 0.42, 0.4), 60)
		if not on:
			p.modulate = Color(0.6, 0.6, 0.65) if open else Color(0.25, 0.25, 0.3)
		cc.add_child(p)
		f.add_child(cc)
		if open and Game.talent_points(id) > 0:
			var dot := PanelContainer.new()
			dot.theme_type_variation = "Badge"
			dot.custom_minimum_size = Vector2(20, 20)
			dot.position = Vector2(46, -2)
			dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
			f.add_child(dot)
		f.pressed.connect(func():
			if not open:
				Sfx.play("ui_tap", -4.0)
				_open_hero(id)
			elif id != hero_id:
				Sfx.play("ui_tap", -4.0)
				_show_hero(id))
		_faces.add_child(f)


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


## The paper doll: armor slots down the left, weapon and offhand down the
## right, the hero between; the stat strip below.
func _build_top(col: VBoxContainer) -> void:
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(top)
	var left := _slot_column(LEFT_SLOTS)
	top.add_child(left)
	_build_stage(top)
	var right := _slot_column(RIGHT_SLOTS)
	top.add_child(right)
	var card := PanelContainer.new()
	card.theme_type_variation = "Card"
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(card)
	_strip = GridContainer.new()
	_strip.columns = 4
	_strip.add_theme_constant_override("h_separation", 6)
	card.add_child(_strip)
	# One fixed-height place under the stats: the hero's skills and buttons,
	# or the card of the piece picked. Neither pushes the collection around.
	var region := VBoxContainer.new()
	region.custom_minimum_size = Vector2(0, REGION_H)
	region.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(region)
	_hero_panel = VBoxContainer.new()
	_hero_panel.add_theme_constant_override("separation", 8)
	region.add_child(_hero_panel)
	_skills_btn = Button.new()
	_skills_btn.theme_type_variation = "CardButton"
	_skills_btn.focus_mode = Control.FOCUS_NONE
	_skills_btn.custom_minimum_size = Vector2(0, 92)
	_skills_btn.pressed.connect(func():
		Sfx.play("ui_tap", -4.0)
		ui._shown_hero = hero_id
		ui.open_sheet("skills"))
	_hero_panel.add_child(_skills_btn)
	_hero_row = HBoxContainer.new()
	_hero_row.add_theme_constant_override("separation", 8)
	_hero_panel.add_child(_hero_row)
	_card_box = VBoxContainer.new()
	region.add_child(_card_box)


func _slot_column(slots: Array) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 14)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for slot: String in slots:
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(SLOT_TILE, SLOT_TILE)
		b.pressed.connect(func(): _on_slot(slot))
		v.add_child(b)
		_slots[slot] = b
	return v


func _build_stage(col: Container) -> void:
	var stage := Control.new()
	_stage = stage
	stage.custom_minimum_size = Vector2(200, STAGE_H)
	stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
	# Slow warm rays behind the hero, as on the pet stage: one light, one subject.
	var rays := ColorRect.new()
	rays.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rm := ShaderMaterial.new()
	rm.shader = preload("res://src/fx/ui_rays.gdshader")
	rm.set_shader_parameter("tint", Color(1.0, 0.78, 0.45))
	rm.set_shader_parameter("strength", 0.14)
	rays.material = rm
	rays.set_anchors_preset(Control.PRESET_CENTER)
	rays.offset_left = -STAGE_H * 0.6
	rays.offset_right = STAGE_H * 0.6
	rays.offset_top = -STAGE_H * 0.62
	rays.offset_bottom = STAGE_H * 0.58
	stage.add_child(rays)
	stage.clip_contents = true
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
	cam.look_at_from_position(Vector3(0, 1.42, 5.0), Vector3(0, 0.98, 0), Vector3.UP)
	_hint = Ui.label("Drag to turn", "Caption", HORIZONTAL_ALIGNMENT_CENTER)
	_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_hint.offset_top = -30.0
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.modulate.a = 0.6
	stage.add_child(_hint)


## The collection of the slot picked around the hero, and the count.
func _build_bag(col: VBoxContainer) -> void:
	_slot_title = Ui.label("", "Heading")
	_slot_title.add_theme_font_size_override("font_size", 22)
	col.add_child(_slot_title)
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
	foot.alignment = BoxContainer.ALIGNMENT_CENTER
	_count = Ui.label("", "Caption", HORIZONTAL_ALIGNMENT_CENTER)
	_count.modulate.a = 0.75
	foot.add_child(_count)
	col.add_child(foot)


# --- The model ---------------------------------------------------------------

func _build_actor() -> void:
	if _actor and is_instance_valid(_actor):
		_actor.queue_free()
	var d: Dictionary = DB.HEROES[hero_id]
	_actor = Actor.new()
	_vp.add_child(_actor)
	_actor.adult_build = true
	_actor.build_model(d["model"], {}, Color(0.55, 0.68, 1.0), 0.5)
	_actor.play(GearDB.anims(hero_id, Game.weapon_family(hero_id))["idle"], 0.0)
	_actor.rotation.y = _yaw
	_dress()


## Puts on what the hero wears, plus the selected piece as a try-on.
func _dress() -> void:
	var preview := {}
	if selected.has("cos"):
		# A skin or glow on trial: worn for the look, then put back.
		var h := Game.hero(hero_id)
		var was := [h.get("skin", ""), h.get("glow", ""), h.get("outfit", "")]
		h[selected["cos"]] = selected["key"]
		GearLook.apply(_actor, hero_id, preview)
		h["skin"] = was[0]
		h["glow"] = was[1]
		h["outfit"] = was[2]
		return
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
	_build_faces()
	_title.text = str(d["name"])
	_title.add_theme_color_override("font_color", GOLD.lerp(d["color"], 0.4))
	for slot: String in _slots:
		_style_slot(_slots[slot], slot)
	var ups := 0
	for slot in SLOT_ORDER:
		if not _best_for(slot).is_empty():
			ups += 1
	_best_ups = ups
	_slot_title.text = "Skins · looks only, never stats" if filter == "skins" else "%s collection" % str(DB.SLOT_NAME[filter])
	_build_strip()
	_build_skills()
	_build_hero_row()
	_hero_panel.visible = _card == null
	var keep := _scroll.scroll_vertical
	_build_list()
	_keep_scroll(keep)
	var have := 0
	var all := 0
	for slot in SLOT_ORDER:
		for row in Game.catalog(hero_id, slot):
			for it in row:
				if not it.is_empty():
					all += 1
					if int(it["uid"]) != 0:
						have += 1
	_count.text = "%s collection  ·  %d / %d found" % [str(d["name"]), have, all]


## The slot's collection: one row per weapon family (one row for armor), its
## best piece shown once with the ladder of sets it climbs beside it; then
## the boss-set and unique pieces, each its own piece. What is not found yet
## shows dark, with the skill it will need.
func _build_list() -> void:
	Ui.clear(_list)
	if filter == "skins":
		_build_skins_list()
		return
	var rows := Game.catalog(hero_id, filter)
	var fams: Array = DB.HERO_FAMILIES.get(hero_id, []) if filter == "weapon" else []
	for i in rows.size():
		var row: Array = rows[i]
		if i >= maxi(fams.size(), 1):
			_list.add_child(_section("Boss sets and uniques", row.size(), DB.rarity_color("legendary")))
			var grid := _grid()
			for it in row:
				if not it.is_empty():
					grid.add_child(_tile(it))
			_list.add_child(grid)
		else:
			_list.add_child(_line_row(row, str(fams[i]) if not fams.is_empty() else ""))


## One family (or the armor line): the piece in view as one tile, and a
## ladder of its sets, grey to green, filled where found. Tapping a rung
## picks that set's piece.
func _line_row(row: Array, fam: String) -> Control:
	var pieces: Array = row.filter(func(x): return not x.is_empty())
	# In view: the piece picked, else the one worn, else the best found.
	var shown: Dictionary = pieces[0]
	var found_n := 0
	var worn := {}
	var picked := {}
	for it: Dictionary in pieces:
		if int(it["uid"]) != 0:
			found_n += 1
			shown = it
			if Game.owner_of(int(it["uid"])) == hero_id:
				worn = it
		if _same(selected, it):
			picked = it
	if not worn.is_empty():
		shown = worn
	if not picked.is_empty():
		shown = picked
	var panel := PanelContainer.new()
	panel.theme_type_variation = "Card"
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	panel.add_child(h)
	var tile := _tile(shown)
	tile.custom_minimum_size = Vector2(LINE_TILE, LINE_TILE)
	tile.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	h.add_child(tile)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 6)
	h.add_child(v)
	if fam != "":
		v.add_child(_family_head(DB.FAMILIES[fam]))
	else:
		var n := Ui.label(str(DB.SLOT_NAME[filter]).to_upper(), "Caption")
		n.add_theme_font_size_override("font_size", 18)
		n.add_theme_color_override("font_color", GOLD)
		v.add_child(n)
	var ladder := HBoxContainer.new()
	ladder.add_theme_constant_override("separation", 4)
	for it: Dictionary in row:
		if it.is_empty():
			var gap := Control.new()
			gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			ladder.add_child(gap)
			continue
		ladder.add_child(_rung(it, _same(it, shown)))
	v.add_child(ladder)
	var st := Ui.label("%d of %d found" % [found_n, pieces.size()] + ("  ·  wearing %s" % _tier_tag(shown) if Game.owner_of(int(shown["uid"])) == hero_id and int(shown["uid"]) != 0 else ""), "Small")
	st.add_theme_color_override("font_color", DIM)
	st.add_theme_font_size_override("font_size", 16)
	v.add_child(st)
	return panel


## One set on a family's ladder: its name in its color, filled when found;
## the skill it needs when the hero lacks it.
func _rung(it: Dictionary, on: bool) -> Button:
	var col := _frame_color(it)
	var found := int(it["uid"]) != 0
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, 34)
	var block := Game.wear_block(hero_id, it)
	# The body font, not the button's wide capitals: set names fit the rung.
	# Every rung names its set; one the hero cannot wear yet adds a padlock
	# (its card says which skill level it needs) rather than a cryptic "Att 40".
	var l := Ui.label(_tier_tag(it), "Small", HORIZONTAL_ALIGNMENT_CENTER)
	l.add_theme_font_size_override("font_size", 15)
	l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.clip_text = true
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(l)
	if block != "" and not found:
		var lk := Ui.icon_rect("padlock", 14, Color(1.0, 0.6, 0.55))
		lk.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		lk.position += Vector2(4, -7)
		lk.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(lk)
	var box := StyleBoxFlat.new()
	box.set_corner_radius_all(8)
	box.anti_aliasing = true
	box.set_border_width_all(3 if on else 2)
	box.border_color = col.lightened(0.4) if on else (col if found else col.darkened(0.5))
	box.bg_color = Color(col.r, col.g, col.b, 0.55) if found else Color(0.06, 0.055, 0.07)
	for k in ["normal", "hover", "pressed"]:
		b.add_theme_stylebox_override(k, box)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	l.add_theme_color_override("font_color", Color(0.98, 0.95, 0.9) if found else (Color(1.0, 0.6, 0.55) if block != "" else Color(0.55, 0.53, 0.5)))
	b.pressed.connect(func():
		Sfx.play("ui_tap", -4.0)
		_select(it, true))
	return b


## A weapon family's name and how it fights, above its row.
func _family_head(fd: Dictionary) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	h.custom_minimum_size = Vector2(0, 40)
	h.add_child(Ui.icon_rect(str(fd["icon"]), 26, GOLD))
	var n := Ui.label(str(fd["name"]).to_upper(), "Caption")
	n.add_theme_font_size_override("font_size", 18)
	n.add_theme_color_override("font_color", GOLD)
	h.add_child(n)
	var how := Ui.label(str(fd["how"]), "Small")
	how.add_theme_color_override("font_color", DIM)
	how.add_theme_font_size_override("font_size", 16)
	how.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	how.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	h.add_child(how)
	return h


func _grid() -> GridContainer:
	var g := GridContainer.new()
	g.columns = COLS
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	g.add_theme_constant_override("h_separation", 12)
	g.add_theme_constant_override("v_separation", 12)
	return g


## Skins as a collection of their own: weapon skins, then glows. Tapping one
## puts it on the hero above to try.
func _on_skins() -> void:
	_close_card(false)
	selected = {}
	filter = "skins"
	_scroll.scroll_vertical = 0
	_dress()
	_refresh()


func _build_skins_list() -> void:
	var outfits: Array = DB.OUTFIT_ORDER.filter(func(k): return hero_id in DB.OUTFITS[k]["heroes"] and (not DB.OUTFITS[k].get("gift", false) or k in Game.hero(hero_id)["outfits"]))
	if not outfits.is_empty():
		_list.add_child(_section("Outfits", outfits.size(), Color(0.45, 0.7, 1.0)))
		var og := _grid()
		for k: String in outfits:
			og.add_child(_cos_tile({"cos": "outfit", "key": k}))
		_list.add_child(og)
	var skins: Array = DB.WEAPON_SKIN_ORDER.filter(func(k): return hero_id in DB.WEAPON_SKINS[k]["heroes"])
	if not skins.is_empty():
		_list.add_child(_section("Weapon skins", skins.size(), GOLD))
		var sg := _grid()
		for k: String in skins:
			sg.add_child(_cos_tile({"cos": "skin", "key": k}))
		_list.add_child(sg)
	var glows: Array = DB.GLOW_ORDER.filter(func(g): return not DB.GLOWS[g].get("gift", false) or g in Game.hero(hero_id).get("glows", []))
	_list.add_child(_section("Weapon glows", glows.size(), Color(0.75, 0.6, 1.0)))
	var gg := _grid()
	for g: String in glows:
		gg.add_child(_cos_tile({"cos": "glow", "key": g}))
	_list.add_child(gg)


## A skin or glow's color, art, owned and worn state.
func _cos_info(c: Dictionary) -> Dictionary:
	var h := Game.hero(hero_id)
	var k := str(c["key"])
	if c["cos"] == "skin":
		var sd: Dictionary = DB.WEAPON_SKINS[k]
		return {"name": sd["name"], "kind": "Weapon skin", "icon": sd["icon"], "col": GOLD, "tint": Color("f6e3b4"),
			"owned": k in h.get("skins", []), "worn": str(h.get("skin", "")) == k, "price": Game.skin_price(k)}
	if c["cos"] == "outfit":
		var od: Dictionary = DB.OUTFITS[k]
		var oc := Color(od["dye"], 1.0)
		return {"name": od["name"], "kind": "Outfit", "icon": DB.HEROES[hero_id]["icon"], "col": oc, "tint": oc.lightened(0.25),
			"owned": k in h.get("outfits", []), "worn": str(h.get("outfit", "")) == k, "price": Game.outfit_price(k)}
	var gd: Dictionary = DB.GLOWS[k]
	var gc := Color(gd["color"], 1.0)
	return {"name": "%s glow" % gd["name"], "kind": "Weapon glow", "icon": "dripping-sword", "col": gc, "tint": gc.lerp(Color.WHITE, 0.2),
		"owned": k in h.get("glows", []), "worn": str(h.get("glow", "")) == k, "price": Game.glow_price(k)}


func _cos_tile(c: Dictionary) -> Button:
	var info := _cos_info(c)
	var col: Color = info["col"]
	var on: bool = selected.get("key", "") == c["key"] and selected.get("cos", "") == c["cos"]
	var b := Button.new()
	b.custom_minimum_size = Vector2(TILE, TILE)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_stylebox_override("normal", _tile_box(col, on, 0.0))
	b.add_theme_stylebox_override("hover", _tile_box(col, on, 0.08))
	b.add_theme_stylebox_override("pressed", _tile_box(col, true, 0.14))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon := Ui.icon_rect(str(info["icon"]), TILE * 0.55, info["tint"])
	if not info["owned"]:
		icon.modulate = Color(1, 1, 1, 0.55)
	cc.add_child(icon)
	b.add_child(cc)
	if info["worn"]:
		b.add_child(_badge("✓", GOLD, Control.PRESET_BOTTOM_RIGHT))
	elif not info["owned"]:
		b.add_child(_badge(Ui.fmt_price(int(info["price"])), Color(0.95, 0.85, 0.6), Control.PRESET_TOP_LEFT))
	b.pressed.connect(func():
		Sfx.play("ui_tap", -4.0)
		if on:
			_close_card(true)
		else:
			_select_cos(c))
	return b


func _select_cos(c: Dictionary) -> void:
	selected = c
	_dress()
	_refresh()
	_open_cos_card(c)


## A skin or glow's card: it is on the hero above already; wear it, take it
## off, or buy it (a second tap confirms a purchase).
func _open_cos_card(c: Dictionary) -> void:
	_close_card(false)
	var info := _cos_info(c)
	_card = PanelContainer.new()
	_card.mouse_filter = Control.MOUSE_FILTER_STOP
	_card.add_theme_stylebox_override("panel", _card_box_style(info["col"]))
	_card_box.add_child(_card)
	_hero_panel.visible = false
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	_card.add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	var hv := VBoxContainer.new()
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var nm := Ui.label(str(info["name"]), "Heading")
	nm.add_theme_font_size_override("font_size", 25)
	nm.add_theme_color_override("font_color", Color(info["col"]).lightened(0.25))
	hv.add_child(nm)
	var sl := Ui.label("%s · looks only · %s" % [info["kind"], "worn" if info["worn"] else ("yours" if info["owned"] else "trying it on")], "Small")
	sl.add_theme_color_override("font_color", DIM)
	hv.add_child(sl)
	head.add_child(hv)
	var x := _round_button("✕", func(): _close_card(true))
	x.custom_minimum_size = Vector2(56, 56)
	head.add_child(x)
	v.add_child(head)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var key := str(c["key"])
	if info["owned"]:
		row.add_child(_action("Take off" if info["worn"] else "Wear", "" if info["worn"] else "PrimaryButton", func():
			if c["cos"] == "skin":
				Game.set_skin(hero_id, "" if info["worn"] else key)
			elif c["cos"] == "outfit":
				Game.set_outfit(hero_id, "" if info["worn"] else key)
			else:
				Game.set_glow(hero_id, "" if info["worn"] else key)
			Sfx.play("ui_toggle", -4.0)
			_redress()
			_select_cos(c)))
	else:
		var price := int(info["price"])
		var buy := _action("Buy · %s" % Ui.fmt_num(price), "GoldButton", Callable())
		buy.icon = Ui.icon("two-coins")
		buy.pressed.connect(func():
			if not buy.has_meta("sure"):
				buy.set_meta("sure", true)
				buy.text = "Tap again to buy · %s" % Ui.fmt_num(price)
				Sfx.play("ui_tap", -4.0)
				return
			var ok := Game.buy_skin(hero_id, key) if c["cos"] == "skin" else (Game.buy_outfit(hero_id, key) if c["cos"] == "outfit" else Game.buy_glow(hero_id, key))
			if not ok:
				Sfx.play("ui_error", -6.0)
				_say("Not enough gold", RED)
				return
			Sfx.play("coin", -2.0)
			_say("%s is yours" % str(info["name"]), GREEN)
			ui.refresh()
			_redress()
			_select_cos(c))
		buy.disabled = Game.gold() < price
		if buy.disabled:
			buy.text = "Needs %s gold" % Ui.fmt_num(price)
		row.add_child(buy)
	v.add_child(row)
	_card.modulate.a = 0.0
	_card.create_tween().tween_property(_card, "modulate:a", 1.0, 0.16)


func _section(title: String, n: int, col: Color) -> Control:
	var l := Ui.label("%s  ·  %d" % [title.to_upper(), n], "Caption")
	l.add_theme_color_override("font_color", col)
	l.add_theme_font_size_override("font_size", 18)
	l.custom_minimum_size = Vector2(0, 34)
	l.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	return l


## How much the piece adds over what the hero wears in its slot (the same
## score Equip best uses). It decides the ▲, and is never shown as a number.
func _gain(it: Dictionary) -> int:
	var cur := Game.equipped(hero_id, it["slot"])
	return Game.item_power(it) - (Game.item_power(cur) if not cur.is_empty() else 0)


## The frame color: the set, the one quality ladder.
func _frame_color(it: Dictionary) -> Color:
	return DB.gear_color(it)


func _tier_tag(it: Dictionary) -> String:
	return GearDB.material_name(str(it["cls"]), int(it.get("mat", 0)))


func _same(a: Dictionary, b: Dictionary) -> bool:
	return a.has("slot") and b.has("slot") and Game.piece_key(a) == Game.piece_key(b)


## One collection tile. Found: the icon in its set's frame, its level, a
## copies bar, a green ▲ when it can level up, a ✓ when worn. Not found: a
## dark outline, and the skill it needs when the hero lacks it.
func _tile(it: Dictionary) -> Button:
	var uid := int(it["uid"])
	var found := uid != 0
	var b := _tile_button(it, TILE, _same(selected, it))
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if not found:
		# Not found: the frame and icon fade, the skill it needs stays legible.
		for c in b.get_children():
			c.modulate = Color(0.45, 0.45, 0.5, 0.75)
		for k in ["normal", "hover"]:
			var st: StyleBoxFlat = b.get_theme_stylebox(k).duplicate()
			st.border_color = st.border_color.darkened(0.55)
			st.bg_color = Color(0.06, 0.055, 0.07)
			b.add_theme_stylebox_override(k, st)
		if Game.wear_block(hero_id, it) != "":
			# The skill in full ("Attack 40"): "Att 40" read as a stat, not a requirement.
			var lv := Ui.label("%s %d" % [DB.SKILL_NAME[GearDB.skill_for(hero_id, str(it["slot"]))], GearDB.req_for(it)], "Caption", HORIZONTAL_ALIGNMENT_CENTER)
			lv.add_theme_font_size_override("font_size", 14)
			lv.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			lv.add_theme_color_override("font_color", Color(1.0, 0.6, 0.55))
			lv.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
			lv.offset_top = 4.0
			lv.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.add_child(lv)
	else:
		b.add_child(_badge("%d" % int(it.get("lv", 1)), Color(0.95, 0.92, 0.86), Control.PRESET_TOP_LEFT))
		if Game.level_block(it) == "":
			b.add_child(_badge("▲", GREEN, Control.PRESET_TOP_RIGHT))
		if Game.owner_of(uid) == hero_id:
			b.add_child(_badge("✓", GOLD, Control.PRESET_BOTTOM_RIGHT))
	b.pressed.connect(func():
		Sfx.play("ui_tap", -4.0)
		_select(it))
	return b


## A framed tile with the piece's icon and its copies bar: shared by the
## collection and the slots around the hero.
func _tile_button(it: Dictionary, size_: float, sel: bool) -> Button:
	var col := _frame_color(it)
	var b := Button.new()
	b.custom_minimum_size = Vector2(size_, size_)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_stylebox_override("normal", _tile_box(col, sel, 0.0))
	b.add_theme_stylebox_override("hover", _tile_box(col, sel, 0.08))
	b.add_theme_stylebox_override("pressed", _tile_box(col, true, 0.14))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cc.offset_bottom = -10.0
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cc.add_child(ItemIcons.rect(it, size_ * 0.6, _icon_tone(it)))
	b.add_child(cc)
	if int(it["uid"]) != 0:
		b.add_child(_copies_bar(it))
	return b


## Under the icon: copies toward the next level, green once there are
## enough; a full gold bar at max level. A unique's bar is gold too.
func _copies_bar(it: Dictionary) -> Control:
	var maxed := int(it.get("lv", 1)) >= DB.PIECE_MAX_LV
	var need := int(DB.level_cost(it)["cards"]) if not maxed else 1
	var have := int(it.get("cards", 0)) if not maxed else 1
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.max_value = need
	bar.value = mini(have, need)
	bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_left = 12.0
	bar.offset_right = -12.0
	bar.offset_top = -17.0
	bar.offset_bottom = -9.0
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.55)
	bg.set_corner_radius_all(4)
	var fill := StyleBoxFlat.new()
	fill.bg_color = GOLD if maxed else (GREEN if have >= need else Color(0.55, 0.75, 1.0))
	fill.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill)
	return bar


func _badge(text: String, col: Color, corner: Control.LayoutPreset) -> Label:
	var l := Ui.label(text, "Caption")
	l.add_theme_font_size_override("font_size", 19)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0.04, 0.035, 0.05))
	l.add_theme_constant_override("outline_size", 6)
	l.set_anchors_and_offsets_preset(corner)
	var right := corner in [Control.PRESET_TOP_RIGHT, Control.PRESET_BOTTOM_RIGHT]
	var bottom := corner in [Control.PRESET_BOTTOM_LEFT, Control.PRESET_BOTTOM_RIGHT]
	l.grow_horizontal = Control.GROW_DIRECTION_BEGIN if right else Control.GROW_DIRECTION_END
	l.grow_vertical = Control.GROW_DIRECTION_BEGIN if bottom else Control.GROW_DIRECTION_END
	l.position += Vector2(-7 if right else 8, -1 if bottom else 3)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _tile_box(col: Color, sel: bool, lift: float) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.085, 0.08, 0.095).lerp(Color(col.r, col.g, col.b), 0.12 + lift)
	s.set_corner_radius_all(14)
	s.set_border_width_all(5 if sel else 3)
	s.border_color = col.lightened(0.35) if sel else col
	s.anti_aliasing = true
	if sel:
		s.shadow_color = Color(col.r, col.g, col.b, 0.45)
		s.shadow_size = 10
	return s


## The hero's numbers, with `33 → 41 ▲` while a bag piece is being tried on.
func _build_strip() -> void:
	Ui.clear(_strip)
	var now := Game.hero_stats(hero_id)
	var then := Game.hero_stats(hero_id, _try_on())
	for spec in [["Health", "hp", 1.0, "%d"], ["Damage", "dmg", 1.0, "%d"], ["Armor", "armor", 100.0, "%d%%"], ["Hits/s", "rate", 1.0, "%.2f"]]:
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
		val.add_theme_font_size_override("font_size", 24 if a == b else 20)
		if a != b:
			var up := tv > nv
			val.text += " ▲" if up else " ▼"
			val.add_theme_color_override("font_color", GREEN if up else RED)
		cell.add_child(val)
		_strip.add_child(cell)


## A rebuilt list comes back at the top; put the reader back where they were
## once it has its height.
func _keep_scroll(v: int) -> void:
	await get_tree().process_frame
	if is_instance_valid(_scroll):
		_scroll.scroll_vertical = v


## The hero's skill levels at a glance (what gear they can wear rests on
## them); tapping opens the Skills sheet.
func _build_skills() -> void:
	Ui.clear(_skills_btn)
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 16.0
	v.offset_right = -16.0
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 4)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_skills_btn.add_child(v)
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cl := Ui.label("Combat level %d" % Game.combat_level(hero_id), "Body")
	cl.add_theme_font_size_override("font_size", 20)
	cl.add_theme_color_override("font_color", GOLD)
	cl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(cl)
	var more := Ui.label("Skills ›", "Caption")
	more.add_theme_font_size_override("font_size", 16)
	top.add_child(more)
	v.add_child(top)
	var chips := HBoxContainer.new()
	chips.add_theme_constant_override("separation", 18)
	chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for sk: String in DB.STYLE_SKILLS[DB.HEROES[hero_id]["skill"]]:
		var c := HBoxContainer.new()
		c.add_theme_constant_override("separation", 6)
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.add_child(Ui.icon_rect(DB.SKILL_ICON[sk], 28, Color(0.95, 0.78, 0.45)))
		var l := Ui.label("%s %d" % [DB.SKILL_NAME[sk], Game.skill_level(sk, hero_id)], "Body")
		l.add_theme_font_size_override("font_size", 19)
		c.add_child(l)
		chips.add_child(c)
	v.add_child(chips)


## Talents, Equip best and skins. Points to spend turn Talents green with
## the count on it; the hero faces above carry the red dot.
func _build_hero_row() -> void:
	Ui.clear(_hero_row)
	var pts := Game.talent_points(hero_id)
	for spec in [["Talents" + (" · %d" % pts if pts > 0 else ""), "GreenButton" if pts > 0 else "BlueButton", "talents"],
			["Equip best" + (" · ▲%d" % _best_ups if _best_ups > 0 else ""), "GoldButton", "best"],
			["Skins", "BlueButton" if filter != "skins" else "GoldButton", "looks"]]:
		var b := Button.new()
		b.theme_type_variation = spec[1]
		b.text = spec[0]
		b.custom_minimum_size = Vector2(0, 60)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 19)
		b.clip_text = true
		var what: String = spec[2]
		if what == "best":
			_best_btn = b
			b.modulate = Color.WHITE if _best_ups > 0 else Color(1, 1, 1, 0.45)
		b.pressed.connect(func():
			if what != "best":
				Sfx.play("ui_tap", -4.0)
			if what == "looks":
				_on_skins()
			elif what == "best":
				_equip_best()
			else:
				ui._shown_hero = hero_id
				ui.open_sheet(what))
		_hero_row.add_child(b)


func _open_hero(id: String) -> void:
	ui._shown_hero = id
	ui.open_sheet("hero")


## The selected piece as a try-on {slot: piece}, when this hero could wear it
## instead of what they have ({} otherwise).
func _try_on() -> Dictionary:
	var it := selected
	if it.has("slot") and str(it["cls"]) == hero_id and Game.owner_of(int(it["uid"])) != hero_id and Game.wear_block(hero_id, it) == "":
		return {it["slot"]: it}
	return {}


## A slot around the hero: the worn piece's tile (with a green ▲ when the bag
## holds better), or a hollow frame with the slot's outline when empty.
func _style_slot(b: Button, slot: String) -> void:
	var it := Game.equipped(hero_id, slot)
	var on := filter == slot
	for c in b.get_children():
		b.remove_child(c)
		c.queue_free()
	if it.is_empty():
		var box := _tile_box(EMPTY, on, 0.0)
		box.bg_color = Color(0.05, 0.045, 0.06, 0.9)
		b.add_theme_stylebox_override("normal", box)
		b.add_theme_stylebox_override("hover", box)
		b.add_theme_stylebox_override("pressed", _tile_box(EMPTY, true, 0.1))
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		var cc := CenterContainer.new()
		cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cc.add_child(Ui.icon_rect(GearDB.icon(hero_id, slot), SLOT_TILE * 0.5, Color(0.5, 0.48, 0.46, 0.45)))
		b.add_child(cc)
	else:
		var t := _tile_button(it, SLOT_TILE, on)
		for k in ["normal", "hover", "pressed", "focus"]:
			b.add_theme_stylebox_override(k, t.get_theme_stylebox(k))
		for c in t.get_children():
			t.remove_child(c)
			b.add_child(c)
		t.free()
	if _hands_full(slot):
		b.add_child(_strike())
	elif not _best_for(slot).is_empty():
		b.add_child(_badge("▲", GREEN, Control.PRESET_TOP_RIGHT))


## The shield slot while the weapon in hand (worn or tried on) takes both hands.
func _hands_full(slot: String) -> bool:
	if slot != "trinket":
		return false
	var w: Dictionary = _try_on().get("weapon", Game.equipped(hero_id, "weapon"))
	return Game.two_hands(hero_id, w)


## A red slash across a slot that can't be used.
func _strike() -> Control:
	var c := Control.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bar := ColorRect.new()
	bar.color = Color(0.85, 0.25, 0.2, 0.9)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var len_ := SLOT_TILE * 1.1
	bar.size = Vector2(len_, 6)
	bar.pivot_offset = bar.size / 2.0
	bar.position = Vector2(SLOT_TILE, SLOT_TILE) / 2.0 - bar.size / 2.0
	bar.rotation = -PI / 4.0
	c.add_child(bar)
	return c


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


# --- The piece's card ----------------------------------------------------------

## Everything about one piece and what to do with it, in place of the hero
## buttons. The model and stat strip above show it worn.
func _open_card(it: Dictionary) -> void:
	_close_card(false)
	var uid := int(it["uid"])
	var found := uid != 0
	var col := _frame_color(it)
	var is_worn := found and Game.owner_of(uid) == hero_id
	var mine: bool = str(it["cls"]) == hero_id
	var block := Game.wear_block(hero_id, it)
	_card = PanelContainer.new()
	_card.mouse_filter = Control.MOUSE_FILTER_STOP
	_card.add_theme_stylebox_override("panel", _card_box_style(col))
	_card_box.add_child(_card)
	_hero_panel.visible = false
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	_card.add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	var tile := _tile_button(it, 84, false)
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(tile)
	var hv := VBoxContainer.new()
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hv.alignment = BoxContainer.ALIGNMENT_CENTER
	hv.add_theme_constant_override("separation", 0)
	var nm := Ui.label(str(it["name"]), "Heading")
	nm.add_theme_font_size_override("font_size", 25)
	nm.add_theme_color_override("font_color", col.lightened(0.25))
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hv.add_child(nm)
	var sl := Ui.label(Game.item_tag(it) + ("" if mine else " · %s" % DB.HEROES[it["cls"]]["name"]) + _copies_text(it), "Small")
	sl.add_theme_color_override("font_color", DIM)
	sl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hv.add_child(sl)
	# What the piece gives; how that moves the hero shows in the stat strip.
	var gives := PackedStringArray()
	for k in it["stats"]:
		gives.append(str(DB.AFFIXES[k]["label"]) % int(it["stats"][k]))
	var gl := Ui.label("  ".join(gives), "Body")
	gl.add_theme_font_size_override("font_size", 21)
	gl.add_theme_color_override("font_color", Color(0.6, 0.78, 1.0))
	gl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hv.add_child(gl)
	head.add_child(hv)
	var x := _round_button("✕", func(): _close_card(true))
	x.custom_minimum_size = Vector2(56, 56)
	x.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	head.add_child(x)
	v.add_child(head)
	var u := str(it.get("unique", ""))
	if u != "":
		v.add_child(_card_note(str(DB.UNIQUES[u].get("power", "")), GOLD))
	var st := Game.item_set(it)
	if st != "":
		v.add_child(_card_note("%s set. 2 worn: %s. 4 worn: %s" % [DB.SETS[st]["name"], DB.SETS[st]["2"]["desc"], DB.SETS[st]["4"]["desc"]], Color(0.45, 1.0, 0.6)))
	if it["slot"] == "trinket" and not is_worn and Game.two_hands(hero_id, Game.equipped(hero_id, "weapon")):
		v.add_child(_card_note("Your weapon takes both hands: equipping this takes the weapon off.", Color(1.0, 0.65, 0.3)))
	elif it["slot"] == "weapon" and Game.two_hands(hero_id, it):
		v.add_child(_card_note("Two-handed: no shield with it.", Color(1.0, 0.65, 0.3)))
	if not found:
		v.add_child(_card_note("Not found yet. " + Game.drop_hint(it) + ("." if block == "" else ", and needs %s." % block.trim_prefix("Requires ")), DIM))
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 10)
	if is_worn:
		row2.add_child(_action("Remove", "", func(): _unequip(it["slot"])))
	elif found:
		var eq := _action("Equip" if block == "" else "Needs " + block.trim_prefix("Requires "), "PrimaryButton", func(): _equip(it))
		eq.disabled = block != ""
		row2.add_child(eq)
	if found:
		var lb := Game.level_block(it)
		var cost := DB.level_cost(it)
		var up := _action("Level up · %s" % Ui.fmt_num(int(cost["gold"])) if lb == "" else lb, "GreenButton", func():
			if Game.level_up(uid):
				Sfx.play("levelup", -4.0)
				_say("%s is level %d" % [str(it["name"]), int(Game.item(uid)["lv"])], GREEN)
				_redress()
				_select(Game.item(uid), true)
			else:
				Sfx.play("ui_error", -6.0))
		if lb == "":
			up.icon = Ui.icon("two-coins")
		up.disabled = lb != ""
		row2.add_child(up)
	if found:
		var src := Game.trade_source(it)
		if not src.is_empty():
			var tr := _action("Trade %d copies of %s for 1 · %s" % [DB.TRADE_COPIES, str(src["name"]), Ui.fmt_num(Game.trade_fee(it))], "", func():
				if Game.trade_copies(int(src["uid"]), uid):
					Sfx.play("coin", -6.0)
					_say("+1 copy of %s" % str(it["name"]), GREEN)
					_select(Game.item(uid), true)
				else:
					Sfx.play("ui_error", -6.0))
			v.add_child(tr)
	var insp := _action("", "", func(): _inspect(it))
	insp.icon = Ui.icon("magic-swirl")
	insp.size_flags_horizontal = Control.SIZE_SHRINK_END
	insp.custom_minimum_size = Vector2(76, 58)
	row2.add_child(insp)
	v.add_child(row2)
	_card.modulate.a = 0.0
	_card.create_tween().tween_property(_card, "modulate:a", 1.0, 0.16)


func _card_box_style(col: Color) -> StyleBoxFlat:
	var bs := StyleBoxFlat.new()
	bs.bg_color = Color(0.1, 0.09, 0.11, 0.98)
	bs.set_corner_radius_all(22)
	bs.set_border_width_all(3)
	bs.border_color = col
	bs.content_margin_left = 16
	bs.content_margin_right = 16
	bs.content_margin_top = 12
	bs.content_margin_bottom = 12
	return bs


func _card_note(text: String, col: Color) -> Label:
	var l := Ui.label(text, "Small")
	l.add_theme_color_override("font_color", col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


## Copies toward the next level, for the card's second line.
func _copies_text(it: Dictionary) -> String:
	if int(it["uid"]) == 0:
		return ""
	if int(it.get("lv", 1)) >= DB.PIECE_MAX_LV:
		return " · max level"
	return " · %d/%d copies" % [int(it.get("cards", 0)), int(DB.level_cost(it)["cards"])]


func _close_card(deselect: bool) -> void:
	if _card and is_instance_valid(_card):
		_card.queue_free()
	_card = null
	if _hero_panel:
		_hero_panel.visible = true
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
	b.custom_minimum_size = Vector2(0, 58)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 23)
	b.clip_text = true
	if cb.is_valid():
		b.pressed.connect(cb)
	return b


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
	if not keep and _same(selected, it):
		_close_card(true)
		return
	selected = it
	_new_uids.erase(int(it["uid"]))
	_dress()
	_refresh()
	_open_card(it)


func _show_hero(id: String) -> void:
	hero_id = id
	Game.set_hero(hero_id)
	ui._shown_hero = hero_id
	lobby.show_hero(hero_id, false)
	selected = {}
	_close_card(false)
	_build_actor()
	_refresh()


## A slot shows its collection and opens the card of what is worn there.
func _on_slot(slot: String) -> void:
	Sfx.play("ui_tap", -4.0)
	_close_card(false)
	filter = slot
	_clear_new(slot)
	_scroll.scroll_vertical = 0
	var worn := Game.equipped(hero_id, slot)
	if _hands_full(slot):
		_say("Your weapon takes both hands: no shield.")
	if worn.is_empty():
		selected = {}
		_dress()
		_refresh()
	else:
		_select(worn, true)


## The piece the bag holds that beats the worn one by most in `slot`, or {}.
func _best_for(slot: String) -> Dictionary:
	var best := {}
	# No shield is "better" while a two-handed weapon is in hand.
	if slot == "trinket" and Game.two_hands(hero_id, Game.equipped(hero_id, "weapon")):
		return best
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
	var bumped := Game.equip(hero_id, int(it["uid"]))
	Sfx.play("gear_equip", -2.0)
	selected = {}
	_close_card(false)
	_redress()
	if bumped == "trinket":
		_say("Two-handed: your offhand went back to the bag", Color(1.0, 0.65, 0.3))
	elif bumped == "weapon":
		_say("Your two-handed weapon went back to the bag", Color(1.0, 0.65, 0.3))
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

## The tab bar moved away from Gear.
func leave() -> void:
	Game.mark_items_seen()
	lobby.refresh_gear()
	queue_free()


## True where a horizontal drag means "turn the hero", not "next tab".
func blocks_swipe(at: Vector2) -> bool:
	return _popup != null or (_stage != null and _stage.get_global_rect().has_point(at))


func _close() -> void:
	if tab_mode:
		ui.show_tab("hunt")
		return
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
