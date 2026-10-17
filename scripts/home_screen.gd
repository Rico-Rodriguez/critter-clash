extends ScreenBase

## Home: the featured hero on a lit 3D meadow plinth across the top half,
## a big HUNT button, chest slots, and tidy icon tiles for the side screens.


func build() -> void:
	show_nav = true
	nav_tab = "home"
	var pad := insets()
	var hero_id := SaveGame.featured_id()
	# The 3D stage bleeds to the screen edges and under the status bar.
	var stage := Showcase.new()
	stage.hero_id = hero_id
	stage.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	stage.anchor_bottom = 0.5
	stage.offset_bottom = 30
	add_child(stage)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", int(pad["l"]))
	margin.add_theme_constant_override("margin_right", int(pad["r"]))
	margin.add_theme_constant_override("margin_top", int(pad["t"]))
	margin.add_theme_constant_override("margin_bottom", int(pad["b"]) + 140)
	add_child(margin)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 16)
	margin.add_child(box)
	box.add_child(header())
	var logo := UiKit.title("CRITTER CLASH", 46)
	logo.add_theme_color_override("font_color", Color("ffe9a8"))
	box.add_child(logo)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(spacer)
	box.add_child(_nameplate(hero_id))
	var play := UiKit.button("HUNT", 600, 132, "gold")
	play.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	play.pressed.connect(func() -> void: go("world"))
	box.add_child(play)
	box.add_child(_chests())
	box.add_child(_tiles())


func _nameplate(hero_id: String) -> Control:
	var info := Catalog.critter(hero_id)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var badge := UiKit.Badge.new()
	badge.level = int(SaveGame.hero(hero_id).get("level", 1))
	badge.custom_minimum_size = Vector2(64, 70)
	row.add_child(badge)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", -6)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(UiKit.label(str(info.get("name", "Hero")), 44, UiKit.CREAM, "x", 8))
	col.add_child(UiKit.label(Catalog.role_name(str(info.get("role", ""))).to_upper(), 22, Color("ffd34a"), "x", 5))
	row.add_child(col)
	return row


func _chests() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	var pending := SaveGame.pending_count()
	for i in 4:
		var slot := ChestSlot.new()
		slot.filled = i < pending
		slot.tone = ["wood", "silver", "gold", "magic"][i % 4] if slot.filled else "wood"
		slot.custom_minimum_size = Vector2(156, 168)
		if slot.filled:
			slot.gui_input.connect(func(event: InputEvent) -> void:
				if (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed):
					go("chest")
			)
		row.add_child(slot)
	return row


func _tiles() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	for tab in [["log", "Log", "book_open"], ["slayer", "Slayer", "skull"], ["skills", "Skills", "flask_full"], ["credits", "Credits", "notepad"]]:
		var tile := UiKit.tile_button(str(tab[1]), str(tab[2]), 150, "blue")
		tile.custom_minimum_size = Vector2(150, 128)
		tile.pressed.connect(go.bind(str(tab[0]), {}))
		row.add_child(tile)
	return row


class Showcase extends Control:
	var hero_id := "ember"
	var stage: Stage3D

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		stage = Stage3D.new()
		stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(stage)
		stage.bind_pedestal(hero_id)
		# Soft fade into the menu below, and a dark band under the pills.
		var fade := Fade.new()
		fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(fade)


class Fade extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		# Vertex-colored quads interpolate per pixel, so there are no bands.
		var h := size.y
		var w := size.x
		var bottom := Color(0.075, 0.06, 0.05)
		_grad(Rect2(0, h * 0.6, w, h * 0.4 + 1.0), Color(bottom, 0.0), bottom)
		_grad(Rect2(0, 0, w, h * 0.24), Color(0.02, 0.015, 0.01, 0.7), Color(0.02, 0.015, 0.01, 0.0))
		# Side vignette so the scene sinks into the stone frame.
		var side := Color(0.02, 0.015, 0.01, 0.55)
		var clear := Color(0.02, 0.015, 0.01, 0.0)
		draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w * 0.22, 0), Vector2(w * 0.22, h), Vector2(0, h)]), PackedColorArray([side, clear, clear, side]))
		draw_polygon(PackedVector2Array([Vector2(w * 0.78, 0), Vector2(w, 0), Vector2(w, h), Vector2(w * 0.78, h)]), PackedColorArray([clear, side, side, clear]))

	func _grad(r: Rect2, top: Color, bot: Color) -> void:
		var pts := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
		draw_polygon(pts, PackedColorArray([top, top, bot, bot]))


class ChestSlot extends Control:
	var filled := false
	var tone := "wood"
	var t := 0.0
	var frame: UiKit.Frame

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP if filled else Control.MOUSE_FILTER_IGNORE
		frame = UiKit.Frame.new("slot", "leather")
		frame.margin = 14.0
		add_child(frame)
		if filled:
			frame.set_param("metal_hi", Color("ffe3a0"))

	func _process(delta: float) -> void:
		t += delta
		if filled:
			frame.set_param("glow_color", Color(1.0, 0.7, 0.3, 0.22 + 0.16 * sin(t * 2.4)))
			queue_redraw()

	func _draw() -> void:
		UiKit.ensure()
		var r := Rect2(Vector2.ZERO, size)
		if filled:
			# Warm light spilling from the chest onto the slot floor.
			var c := Vector2(r.size.x * 0.5, r.size.y * 0.5)
			for i in 6:
				draw_circle(c, r.size.x * (0.42 - i * 0.05), Color(1.0, 0.62, 0.25, 0.035))
		var bob := sin(t * 2.6) * 3.0 if filled else 0.0
		var art := Rect2(r.position + Vector2(r.size.x * 0.13, 16 + bob), Vector2(r.size.x * 0.74, r.size.x * 0.64))
		UiKit.draw_chest(self, art, tone, filled)
		var font := UiKit.font_x
		var caption := "OPEN" if filled else "EMPTY"
		var ink := UiKit.GOLD.lightened(0.2) if filled else Color(0.5, 0.45, 0.38)
		UiKit.draw_text(self, font, Vector2(r.position.x, r.end.y - 16), caption, 20 if filled else 17, ink, Color(0.05, 0.03, 0.02), 2, r.size.x)
