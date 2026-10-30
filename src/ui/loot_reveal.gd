extends Control
## Not a class_name (see item_icons.gd). After a win, the gear you found comes
## out one piece at a time before the results list: the worst first and the
## best last, each on its own card in its rarity's light, with whether it
## beats what its hero wears. Dots count the pieces, a tray below collects the
## ones seen, and Equip now puts an upgrade on its hero there and then. A tap
## shows the next; Skip shows the list. `finished` fires once, after the last
## card or on Skip.

signal finished

const ItemIcons := preload("res://src/ui/item_icons.gd")
const RAYS := preload("res://src/fx/ui_rays.gdshader")
const ORDER := ["common", "magic", "rare", "legendary"]
const TRAY := 76.0

var _items: Array = []
var _played := ""
var _heading := ""
var _i := -1
var _card: Control
var _rays: ColorRect
var _dots: HBoxContainer
var _tray: HBoxContainer
var _go: Button
var _done := false


## The pieces worth a card: gear only, worst first. Uniques count as legendary.
static func pick(items: Array) -> Array:
	var out: Array = items.filter(func(it): return it["slot"] in DB.SLOTS)
	out.sort_custom(func(a, b): return _rank(a) < _rank(b))
	return out


static func _rank(it: Dictionary) -> int:
	var r := ORDER.find(str(it.get("rarity", "common")))
	return (r if r >= 0 else 0) + (10 if str(it.get("unique", "")) != "" else 0)


## `heading` is the small line over VICTORY ("Gravemaw falls").
func setup(items: Array, played: String, heading := "") -> void:
	_items = items
	_played = played
	_heading = heading


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.015, 0.03, 0.9)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	_rays = ColorRect.new()
	_rays.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = RAYS
	m.set_shader_parameter("strength", 0.4)
	_rays.material = m
	_rays.set_anchors_preset(Control.PRESET_CENTER)
	_rays.offset_left = -560
	_rays.offset_right = 560
	_rays.offset_top = -640
	_rays.offset_bottom = 480
	add_child(_rays)
	var head := VBoxContainer.new()
	head.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	head.offset_top = 110
	head.add_theme_constant_override("separation", -6)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(head)
	var sub := Ui.label(_heading.to_upper() if _heading != "" else "THE HOARD", "Caption", HORIZONTAL_ALIGNMENT_CENTER)
	sub.add_theme_color_override("font_color", Color(0.95, 0.75, 0.42))
	head.add_child(sub)
	var title := Ui.label("Victory", "Title", HORIZONTAL_ALIGNMENT_CENTER)
	title.add_theme_font_size_override("font_size", 76)
	title.add_theme_color_override("font_color", Color(1.0, 0.84, 0.48))
	head.add_child(title)
	Ui.pop_in.call_deferred(title, 0.05, 1.4)
	# Below the card: the dots, the tray of what came out so far, one button
	# that acts on the piece shown, and a way past it all.
	var foot := VBoxContainer.new()
	foot.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	foot.offset_left = 40
	foot.offset_right = -40
	foot.offset_top = -420
	foot.offset_bottom = -90
	foot.alignment = BoxContainer.ALIGNMENT_END
	foot.add_theme_constant_override("separation", 22)
	foot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(foot)
	_dots = HBoxContainer.new()
	_dots.alignment = BoxContainer.ALIGNMENT_CENTER
	_dots.add_theme_constant_override("separation", 10)
	_dots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	foot.add_child(_dots)
	_tray = HBoxContainer.new()
	_tray.alignment = BoxContainer.ALIGNMENT_CENTER
	_tray.add_theme_constant_override("separation", 10)
	_tray.mouse_filter = Control.MOUSE_FILTER_IGNORE
	foot.add_child(_tray)
	_go = Button.new()
	_go.theme_type_variation = &"GoldButton"
	_go.focus_mode = Control.FOCUS_NONE
	_go.custom_minimum_size = Vector2(0, 88)
	_go.add_theme_font_size_override("font_size", 32)
	_go.pressed.connect(_act)
	foot.add_child(_go)
	var skip := Button.new()
	skip.flat = true
	skip.text = "SKIP TO THE LIST"
	skip.focus_mode = Control.FOCUS_NONE
	skip.add_theme_font_size_override("font_size", 20)
	skip.add_theme_color_override("font_color", Color(0.7, 0.66, 0.6))
	skip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	skip.pressed.connect(_finish)
	foot.add_child(skip)
	_next()


func _gui_input(e: InputEvent) -> void:
	if (e is InputEventMouseButton and e.pressed) or (e is InputEventScreenTouch and e.pressed):
		accept_event()
		_next()


## Whether the piece shown would be an upgrade for its hero now.
func _upgrade(it: Dictionary) -> bool:
	var hero := str(it.get("cls", _played))
	return int(it.get("uid", 0)) > 0 and not it.get("dupe", false) and Game.is_better(it, hero) and Game.wear_block(hero, it) == ""


## The gold button: put the upgrade on, or move on.
func _act() -> void:
	if _done or _i < 0 or _i >= _items.size():
		return
	var it: Dictionary = _items[_i]
	if _upgrade(it) and Game.owner_of(int(it["uid"])) == "":
		var hero := str(it.get("cls", _played))
		Game.equip(hero, int(it["uid"]))
		Sfx.play("gear_equip", -2.0)
		Ui.buzz(30, 0.4)
		_go.text = "EQUIPPED  ✓"
		_go.theme_type_variation = &"Ghost"
		var t := _go.create_tween()
		t.tween_interval(0.5)
		t.tween_callback(_next)
		return
	_next()


func _next() -> void:
	if _done:
		return
	_i += 1
	if _i >= _items.size():
		_finish()
		return
	if _card:
		var old := _card
		var tw := old.create_tween().set_parallel()
		tw.tween_property(old, "modulate:a", 0.0, 0.15)
		tw.tween_property(old, "position:x", old.position.x - 120.0, 0.15)
		tw.chain().tween_callback(old.queue_free)
	var it: Dictionary = _items[_i]
	var col := DB.gear_color(it)
	(_rays.material as ShaderMaterial).set_shader_parameter("tint", col)
	_card = _make_card(it, col)
	add_child(_card)
	Ui.pop_in(_card, 0.0, 0.6)
	_build_dots()
	_build_tray()
	var last := _i == _items.size() - 1
	if _upgrade(it) and Game.owner_of(int(it["uid"])) == "":
		_go.text = "EQUIP NOW"
		_go.theme_type_variation = &"GoldButton"
	else:
		_go.text = "SEE IT ALL" if last else "NEXT"
		_go.theme_type_variation = &"GoldButton" if last else &"Ghost"
	var best := last and _rank(it) >= 2
	Sfx.play("gear_drop", -2.0)
	if str(it.get("rarity", "")) in ["rare", "legendary"] or str(it.get("unique", "")) != "":
		Sfx.play("rare_chime", 0.0, 0.9 if best else 1.0)
	if best:
		Ui.buzz(60, 0.6)


## A dot per piece, lit up to the one shown.
func _build_dots() -> void:
	Ui.clear(_dots)
	for k in _items.size():
		var d := Panel.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(1.0, 0.84, 0.48) if k <= _i else Color(1, 1, 1, 0.2)
		sb.set_corner_radius_all(8)
		d.add_theme_stylebox_override("panel", sb)
		d.custom_minimum_size = Vector2(14, 14) if k != _i else Vector2(30, 14)
		d.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_dots.add_child(d)


## What came out so far, small, in their frames; the ones to come are ghosts.
## Up to six fit: past that, the latest six.
func _build_tray() -> void:
	Ui.clear(_tray)
	var from := maxi(0, mini(_i - 4, _items.size() - 6))
	for k in range(from, mini(from + 6, _items.size())):
		var it: Dictionary = _items[k]
		var seen := k <= _i
		var col := DB.gear_color(it) if seen else Color(1, 1, 1, 0.18)
		var p := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.05, 0.04, 0.06, 0.9)
		sb.set_corner_radius_all(14)
		sb.set_border_width_all(4 if k == _i else 3)
		sb.border_color = col
		if k == _i:
			sb.shadow_color = Color(col.r, col.g, col.b, 0.5)
			sb.shadow_size = 10
		p.add_theme_stylebox_override("panel", sb)
		p.custom_minimum_size = Vector2(TRAY, TRAY)
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if seen:
			var cc := CenterContainer.new()
			cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var art := ItemIcons.rect(it, TRAY * 0.72, col)
			art.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cc.add_child(art)
			p.add_child(cc)
		else:
			p.modulate.a = 0.5
		_tray.add_child(p)


func _make_card(it: Dictionary, col: Color) -> Control:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.06, 0.07).lerp(col, 0.1)
	sb.set_corner_radius_all(22)
	sb.set_border_width_all(4)
	sb.border_color = col
	sb.shadow_color = Color(col.r, col.g, col.b, 0.5)
	sb.shadow_size = 26
	sb.content_margin_left = 28
	sb.content_margin_right = 28
	sb.content_margin_top = 26
	sb.content_margin_bottom = 26
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.custom_minimum_size = Vector2(440, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var unique := str(it.get("unique", "")) != ""
	var kind := Ui.label(("UNIQUE" if unique else str(it.get("rarity", "common")).to_upper()) + " · " + str(DB.SLOT_NAME.get(it["slot"], it["slot"])).to_upper(), "Caption", HORIZONTAL_ALIGNMENT_CENTER)
	kind.add_theme_color_override("font_color", col)
	v.add_child(kind)
	var cc := CenterContainer.new()
	cc.custom_minimum_size = Vector2(0, 230)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var art := ItemIcons.rect(it, 210, col)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cc.add_child(art)
	v.add_child(cc)
	var nm := Ui.label(str(it["name"]), "Title", HORIZONTAL_ALIGNMENT_CENTER)
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nm.custom_minimum_size.x = 384
	nm.add_theme_font_size_override("font_size", 38)
	v.add_child(nm)
	var hero := str(it.get("cls", _played))
	var line := ""
	var up := false
	if it.get("dupe", false):
		line = "+1 copy toward its next level"
	elif int(it.get("uid", 0)) > 0 and Game.is_better(it, hero):
		up = true
		var gain := Game.item_power(it) - (Game.item_power(Game.equipped(hero, it["slot"])) if not Game.equipped(hero, it["slot"]).is_empty() else 0)
		var who: String = DB.HEROES[hero]["name"] if DB.HEROES.has(hero) else "hero"
		line = "+%d power  ▲ over your %s's" % [gain, who] if gain > 0 else "▲ Better than what your %s wears" % who
	elif DB.HEROES.has(hero) and hero != _played:
		line = "For your %s" % DB.HEROES[hero]["name"]
	if line != "":
		var l := Ui.label(line, "Body", HORIZONTAL_ALIGNMENT_CENTER)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 384
		l.add_theme_color_override("font_color", Color(0.45, 1.0, 0.55) if up else Color(0.75, 0.82, 1.0))
		v.add_child(l)
	p.add_child(v)
	# Centre it once its size is known, between the title and the tray.
	p.resized.connect(func():
		p.position = (size - p.size) * Vector2(0.5, 0.43))
	return p


func _finish() -> void:
	if _done:
		return
	_done = true
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.2)
	tw.tween_callback(func():
		finished.emit()
		queue_free())
