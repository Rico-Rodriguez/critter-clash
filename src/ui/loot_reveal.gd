extends Control
## Not a class_name (see item_icons.gd). After a win, the gear you found comes
## out one piece at a time before the results list: the worst first and the
## best last, each on its own card in its rarity's light, with whether it
## beats what its hero wears. A tap shows the next; Skip shows the list.
## `finished` fires once, after the last card or on Skip.

signal finished

const ItemIcons := preload("res://src/ui/item_icons.gd")
const RAYS := preload("res://src/fx/ui_rays.gdshader")
const ORDER := ["common", "magic", "rare", "legendary"]

var _items: Array = []
var _played := ""
var _i := -1
var _card: Control
var _rays: ColorRect
var _count: Label
var _done := false


## The pieces worth a card: gear only, worst first. Uniques count as legendary.
static func pick(items: Array) -> Array:
	var out: Array = items.filter(func(it): return it["slot"] in DB.SLOTS)
	out.sort_custom(func(a, b): return _rank(a) < _rank(b))
	return out


static func _rank(it: Dictionary) -> int:
	var r := ORDER.find(str(it.get("rarity", "common")))
	return (r if r >= 0 else 0) + (10 if str(it.get("unique", "")) != "" else 0)


func setup(items: Array, played: String) -> void:
	_items = items
	_played = played


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.015, 0.03, 0.88)
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
	var title := Ui.label("THE HOARD", "Heading", HORIZONTAL_ALIGNMENT_CENTER)
	title.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 150
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(title)
	_count = Ui.label("", "Caption", HORIZONTAL_ALIGNMENT_CENTER)
	_count.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_count.offset_top = -260
	_count.offset_bottom = -220
	_count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_count)
	var skip := Button.new()
	skip.theme_type_variation = &"Ghost"
	skip.text = "SKIP"
	skip.focus_mode = Control.FOCUS_NONE
	skip.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	skip.offset_left = -110
	skip.offset_right = 110
	skip.offset_top = -190
	skip.offset_bottom = -120
	skip.pressed.connect(_finish)
	add_child(skip)
	_next()


func _gui_input(e: InputEvent) -> void:
	if (e is InputEventMouseButton and e.pressed) or (e is InputEventScreenTouch and e.pressed):
		accept_event()
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
	_count.text = "%d OF %d · TAP FOR THE NEXT" % [_i + 1, _items.size()] if _i + 1 < _items.size() else "%d OF %d · TAP TO SEE IT ALL" % [_i + 1, _items.size()]
	Ui.pop_in.call_deferred(_card, 0.0, 0.6)
	var best := _i == _items.size() - 1 and _rank(it) >= 2
	Sfx.play("gear_drop", -2.0)
	if str(it.get("rarity", "")) in ["rare", "legendary"] or str(it.get("unique", "")) != "":
		Sfx.play("rare_chime", 0.0, 0.9 if best else 1.0)
	if best:
		Ui.buzz(60, 0.6)


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
	# A wrapping label needs a width, or the card measures it one word wide.
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
		line = "▲ Better than what your %s wears" % DB.HEROES[hero]["name"] if DB.HEROES.has(hero) else "▲ An upgrade"
	elif DB.HEROES.has(hero) and hero != _played:
		line = "For your %s" % DB.HEROES[hero]["name"]
	if line != "":
		var l := Ui.label(line, "Body", HORIZONTAL_ALIGNMENT_CENTER)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 384
		l.add_theme_color_override("font_color", Color(0.45, 1.0, 0.55) if up else Color(0.75, 0.82, 1.0))
		v.add_child(l)
	p.add_child(v)
	# Centre it once its size is known.
	p.resized.connect(func():
		p.position = (size - p.size) * Vector2(0.5, 0.46))
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
