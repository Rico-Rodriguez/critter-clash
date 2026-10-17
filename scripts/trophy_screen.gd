extends ScreenBase

var road: Road


func build() -> void:
	show_nav = true
	nav_tab = "trophy"
	var box := column()
	box.add_child(header())
	box.add_child(h1("Trophy Road"))
	box.add_child(body("Wins add trophies. Claim the rewards as you pass them."))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	road = Road.new()
	road.claim.connect(_claim)
	road.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(road)
	road.rebuild()


func _claim(id: String) -> void:
	if SaveGame.claim(id):
		go("trophy")


class Road extends Control:
	signal claim(id: String)

	func rebuild() -> void:
		for child in get_children():
			child.queue_free()
		var count := Catalog.MILESTONES.size()
		custom_minimum_size = Vector2(0, 48 + count * 188)
		for i in count:
			var entry: Dictionary = Catalog.MILESTONES[i]
			var node := Milestone.new()
			node.setup(entry, int(SaveGame.data["trophies"]))
			node.claim.connect(func(id: String) -> void: claim.emit(id))
			add_child(node)
		call_deferred("_place")

	func _place() -> void:
		var w := size.x if size.x > 20.0 else 640.0
		for i in get_child_count():
			var child := get_child(i) as Control
			var y := 24.0 + float(i) * 188.0
			var sway := sin(float(i) * 0.95) * minf(120.0, w * 0.18)
			child.position = Vector2(w * 0.5 + sway - 140.0, y)
		queue_redraw()

	func _draw() -> void:
		if get_child_count() < 2:
			return
		for i in get_child_count() - 1:
			var a := get_child(i) as Control
			var b := get_child(i + 1) as Control
			var p0 := a.position + Vector2(140, 70)
			var p1 := b.position + Vector2(140, 10)
			draw_line(p0, p1, Color("081428"), 18.0, true)
			draw_line(p0, p1, Color("f0d48a"), 10.0, true)
			var trophies := int(SaveGame.data["trophies"])
			var need := int(Catalog.MILESTONES[i]["trophies"])
			if trophies >= need:
				draw_line(p0, p1, Color("5dce45"), 6.0, true)


class Milestone extends PanelContainer:
	signal claim(id: String)
	var pulsing := false
	var t := 0.0

	func setup(entry: Dictionary, trophies: int) -> void:
		var id := str(entry["id"])
		var need := int(entry["trophies"])
		var claimed: bool = id in SaveGame.data["claimed"]
		custom_minimum_size = Vector2(280, 132)
		var ready := trophies >= need and not claimed
		pulsing = ready
		var bg := Color("1a4e9a") if trophies >= need else Color("1a3058")
		add_theme_stylebox_override("panel", UiKit.panel(bg, 18))
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 2)
		add_child(box)
		box.add_child(UiKit.label(str(entry["label"]), 24, UiKit.CREAM, "x", 4))
		box.add_child(UiKit.label("%d trophies" % need, 16, Color("ffe08a"), "x", 3))
		box.add_child(UiKit.label(str(entry["detail"]), 16, Color("d5e6ff"), "b", 3))
		if claimed:
			box.add_child(UiKit.label("CLAIMED", 18, Color("b6ff9a"), "x", 3))
		elif ready:
			var button := UiKit.confirm("CLAIM", 200, 52)
			button.pressed.connect(func() -> void: claim.emit(id))
			box.add_child(button)
		else:
			box.add_child(UiKit.label("%d to go" % (need - trophies), 16, Color("ffd0a8"), "x", 3))

	func _process(delta: float) -> void:
		if not pulsing:
			return
		t += delta
		pivot_offset = size * 0.5
		scale = Vector2.ONE * (1.0 + sin(t * 4.0) * 0.035)
