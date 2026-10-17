extends ScreenBase


func build() -> void:
	show_nav = true
	nav_tab = "home"
	var box := column()
	box.add_child(header())
	box.add_child(UiKit.title("CRITTER CLASH", 40))
	var stage := Showcase.new()
	stage.hero_id = SaveGame.featured_id()
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage.custom_minimum_size = Vector2(0, 380)
	box.add_child(stage)
	var play := UiKit.button("HUNT", 560, 108, "gold")
	play.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	play.pressed.connect(func() -> void: go("world"))
	box.add_child(play)
	box.add_child(_more())
	box.add_child(_chests())


func _more() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	for tab in [["log", "LOG"], ["slayer", "SLAYER"], ["skills", "SKILLS"]]:
		var button := UiKit.secondary(str(tab[1]), 190, 60)
		button.pressed.connect(go.bind(str(tab[0]), {}))
		row.add_child(button)
	return row


func _chests() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	var pending := SaveGame.pending_count()
	for i in 4:
		var slot := ChestSlot.new()
		slot.filled = i < pending
		slot.custom_minimum_size = Vector2(120, 92)
		if slot.filled:
			slot.gui_input.connect(func(event: InputEvent) -> void:
				if event is InputEventMouseButton and event.pressed:
					go("chest")
			)
		row.add_child(slot)
	return row


class Showcase extends Control:
	var hero_id := "ember"
	var stage: Stage3D
	var name_label: Label

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var plate := ColorRect.new()
		plate.set_anchors_preset(Control.PRESET_FULL_RECT)
		plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
		plate.color = Color("142033")
		add_child(plate)
		stage = Stage3D.new()
		stage.set_anchors_preset(Control.PRESET_FULL_RECT)
		stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(stage)
		stage.bind_pedestal(hero_id)
		var info := Catalog.critter(hero_id)
		name_label = UiKit.label("%s  ·  %s" % [str(info.get("name", "Hero")), Catalog.role_name(str(info.get("role", "")))], 28, UiKit.CREAM, "x", 6)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(name_label)

	func _process(_delta: float) -> void:
		if name_label == null:
			return
		name_label.position = Vector2(20, maxf(8.0, size.y - 52.0))
		name_label.size = Vector2(maxf(10.0, size.x - 40.0), 40)


class ChestSlot extends Control:
	var filled := false
	var t := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP if filled else Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		if not filled:
			return
		t += delta
		pivot_offset = size * 0.5
		rotation = sin(t * 7.0) * 0.05
		queue_redraw()

	func _draw() -> void:
		var r := Rect2(4, 6, size.x - 8, size.y - 10)
		var wood := StyleBoxFlat.new()
		wood.bg_color = Color("6a3d22")
		wood.set_corner_radius_all(16)
		wood.set_border_width_all(5)
		wood.border_color = Color("e8c07a")
		wood.draw(get_canvas_item(), r)
		var inner := r.grow(-8)
		var well := StyleBoxFlat.new()
		well.bg_color = Color("3e2414")
		well.set_corner_radius_all(10)
		well.draw(get_canvas_item(), inner)
		UiKit.ensure()
		if not filled:
			_chest(inner, Color(1, 1, 1, 0.28))
			if UiKit.font_x:
				draw_string(UiKit.font_x, inner.position + Vector2(0, inner.size.y - 6), "Empty", HORIZONTAL_ALIGNMENT_CENTER, inner.size.x, 16, Color(1, 0.92, 0.75, 0.8))
			return
		_chest(inner, Color("ffd56a"))

	func _chest(r: Rect2, col: Color) -> void:
		var body := Rect2(r.position.x + 18, r.position.y + 22, r.size.x - 36, r.size.y - 40)
		draw_rect(body, col, true)
		draw_rect(Rect2(body.position.x - 4, body.position.y - 14, body.size.x + 8, 18), col.lightened(0.15), true)
		draw_rect(Rect2(body.position.x + body.size.x * 0.5 - 5, body.position.y - 6, 10, 16), Color(1, 1, 1, 0.85), true)
		draw_circle(body.position + Vector2(body.size.x * 0.5, body.size.y * 0.62), 6, Color(1, 0.95, 0.75, 0.9))
