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
	box.add_child(_chests())


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
	var face: TextureRect
	var name_label: Label
	var t := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		face = TextureRect.new()
		face.texture = SpriteBank.critter(hero_id)
		face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		face.custom_minimum_size = Vector2(280, 280)
		face.size = Vector2(280, 280)
		add_child(face)
		var info := Catalog.critter(hero_id)
		name_label = UiKit.label("%s  ·  %s" % [str(info.get("name", "Hero")), Catalog.role_name(str(info.get("role", "")))], 28, UiKit.CREAM, "x", 6)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(name_label)

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()
		if face == null:
			return
		var y := size.y * 0.46 + sin(t * 2.1) * 8.0
		face.position = Vector2(size.x * 0.5 - 140.0, y - 200.0)
		if name_label:
			name_label.position = Vector2(20, minf(size.y - 48.0, y + 96.0))
			name_label.size = Vector2(maxf(10.0, size.x - 40.0), 40)

	func _draw() -> void:
		var c := Vector2(size.x * 0.5, size.y * 0.50)
		draw_circle(c + Vector2(0, -20), 168, Color(1.0, 0.82, 0.35, 0.28))
		draw_circle(c + Vector2(0, -10), 110, Color(1.0, 0.92, 0.55, 0.22))
		draw_colored_polygon(PackedVector2Array([
			c + Vector2(-120, 78), c + Vector2(120, 78), c + Vector2(90, 108), c + Vector2(-90, 108)
		]), Color("c9842a"))
		draw_colored_polygon(PackedVector2Array([
			c + Vector2(-100, 70), c + Vector2(100, 70), c + Vector2(78, 92), c + Vector2(-78, 92)
		]), Color("f0c36a"))
		draw_colored_polygon(PackedVector2Array([
			c + Vector2(-70, 62), c + Vector2(70, 62), c + Vector2(50, 78), c + Vector2(-50, 78)
		]), Color(1, 1, 1, 0.28))


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
		var r := Rect2(6, 8, size.x - 12, size.y - 14)
		var plate := StyleBoxFlat.new()
		plate.bg_color = Color("1a3f86") if not filled else Color("8a4b16")
		plate.set_corner_radius_all(16)
		plate.set_border_width_all(4)
		plate.border_color = Color("081428")
		plate.draw(get_canvas_item(), r)
		if not filled:
			draw_string(UiKit.font_x, r.position + Vector2(r.size.x * 0.5 - 10, r.size.y * 0.65), "+", HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Color(1, 1, 1, 0.35))
			return
		var lid := Rect2(r.position.x + 10, r.position.y + 8, r.size.x - 20, 22)
		draw_rect(Rect2(r.position.x + 14, r.position.y + 28, r.size.x - 28, r.size.y - 40), Color("e0a04a"), true)
		draw_rect(lid, Color("ffd56a"), true)
		draw_rect(Rect2(r.position.x + r.size.x * 0.5 - 6, r.position.y + 24, 12, 16), Color("ffe9a0"), true)
		draw_circle(r.position + Vector2(r.size.x * 0.5, r.size.y * 0.62), 7, Color("fff1c2"))
