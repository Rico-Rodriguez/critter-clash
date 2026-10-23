extends Control
## A new save's first choice: one of the starting heroes. The others wait on
## the Trophy Road. Shown once, over the camp, before anything else.
## No class_name (over-the-air packs can't add global classes): preload it.

const TrophyRoad := preload("res://src/lobby/trophy_road.gd")

signal picked(id: String)

var _choice := ""
var _cards := {}
var _go: Button


func open() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.025, 0.04, 0.93)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Ui.apply_safe_area(m, 30)
	add_child(m)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 18)
	m.add_child(v)
	v.add_child(Ui.label("THE BARROW WAKES", "RoadTag", HORIZONTAL_ALIGNMENT_CENTER))
	var tl := Ui.label("Choose your hero", "Title", HORIZONTAL_ALIGNMENT_CENTER)
	tl.add_theme_font_size_override("font_size", 58)
	v.add_child(tl)
	var others: Array = []
	for st in DB.TROPHY_ROAD:
		if str(st["kind"]) == "pick":
			others.append(Ui.fmt_num(int(st["t"])))
	var sub := Ui.label("The others join you on the Trophy Road, at %s trophies." % " and ".join(PackedStringArray(others)), "Body", HORIZONTAL_ALIGNMENT_CENTER)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(sub)
	var i := 0
	for hid in DB.START_HEROES:
		var id: String = hid
		var card := TrophyRoad.hero_choice(id, func(): _select(id))
		card.toggle_mode = true
		card.size_flags_horizontal = Control.SIZE_FILL
		_cards[id] = card
		var cc := CenterContainer.new()
		cc.add_child(card)
		v.add_child(cc)
		Ui.pop_in(card, 0.12 + 0.08 * i, 0.8)
		i += 1
	_go = Button.new()
	_go.theme_type_variation = &"PrimaryButton"
	_go.custom_minimum_size = Vector2(560, 100)
	_go.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_go.focus_mode = Control.FOCUS_NONE
	_go.pressed.connect(_start)
	v.add_child(_go)
	_select(Game.hero_id() if Game.hero_id() in DB.START_HEROES else "knight")


func _select(id: String) -> void:
	_choice = id
	for k in _cards:
		(_cards[k] as Button).set_pressed_no_signal(k == id)
		var c: Button = _cards[k]
		var lit := 1.0 if k == id else 0.62
		c.modulate = Color(lit, lit, lit, c.modulate.a)
	_go.text = "Start as %s" % DB.HEROES[id]["name"]


func _start() -> void:
	Game.pick_start_hero(_choice)
	Sfx.play("unlock_start", 0.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.3)
	t.tween_callback(func():
		picked.emit(_choice)
		queue_free())
