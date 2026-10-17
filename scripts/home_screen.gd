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
		var h := size.y
		var w := size.x
		var bottom := Color(0.06, 0.18, 0.42)
		var steps := 24
		for i in steps:
			var t := float(i) / float(steps)
			var y := h * (0.78 + 0.22 * t)
			draw_rect(Rect2(0, y, w, h * 0.22 / steps + 1.0), Color(bottom, t * t), true)
		for i in steps:
			var t := float(i) / float(steps)
			draw_rect(Rect2(0, h * 0.16 * t, w, h * 0.16 / steps + 1.0), Color(0, 0.03, 0.12, 0.42 * (1.0 - t)), true)


class ChestSlot extends Control:
	var filled := false
	var tone := "wood"
	var t := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP if filled else Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		t += delta
		if filled:
			queue_redraw()

	func _draw() -> void:
		UiKit.ensure()
		var r := Rect2(4, 4, size.x - 8, size.y - 12)
		UiKit.rr_shadow(self, r, 18, 6.0, 0.3)
		UiKit.rr_fill(self, r.grow(3), 21, Color("0a1d45"), Color("0a1d45"))
		if filled:
			UiKit.rr_fill(self, r, 18, Color("3d86e0"), Color("1a4596"))
			var glow := 0.5 + 0.5 * sin(t * 3.0)
			UiKit.rr_line(self, r.grow(-3), 15, Color(1.0, 0.86, 0.35, 0.5 + glow * 0.4), 4.0)
		else:
			UiKit.rr_fill(self, r, 18, Color(0.06, 0.14, 0.32, 0.92), Color(0.04, 0.1, 0.24, 0.92))
		var bob := sin(t * 3.2) * 4.0 if filled else 0.0
		var art := Rect2(r.position + Vector2(r.size.x * 0.12, 10 + bob), Vector2(r.size.x * 0.76, r.size.x * 0.66))
		UiKit.draw_chest(self, art, tone, filled)
		var font := UiKit.font_x
		var caption := "Open!" if filled else "Empty"
		var ink := Color.WHITE if filled else Color(0.62, 0.72, 0.9)
		if filled:
			var chip := Rect2(r.position.x + 12, r.end.y - 42, r.size.x - 24, 34)
			UiKit.rr_fill(self, chip.grow(2), 12, Color("0e3d0c"), Color("0e3d0c"))
			UiKit.rr_fill(self, chip, 10, Color("a4f56a"), Color("38a826"))
			UiKit.draw_text(self, font, Vector2(chip.position.x, chip.end.y - 8), caption, 22, ink, Color("0e3d0c"), 3, chip.size.x)
		else:
			UiKit.draw_text(self, font, Vector2(r.position.x, r.end.y - 14), caption, 22, ink, UiKit.INK, 3, r.size.x)
