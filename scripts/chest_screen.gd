extends ScreenBase

var title_label: Label
var loot_box: VBoxContainer
var open_button: Button
var home_button: Button
var showing_loot := false
var burst: Burst


func build() -> void:
	var box := column()
	box.add_child(header())
	title_label = h1("Chest")
	box.add_child(title_label)
	box.add_child(body("Cards level your critters. Gear fills weapon, armor, and charm."))
	loot_box = VBoxContainer.new()
	loot_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	loot_box.add_theme_constant_override("separation", 8)
	box.add_child(loot_box)
	burst = Burst.new()
	burst.set_anchors_preset(Control.PRESET_FULL_RECT)
	burst.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(burst)
	open_button = UiKit.button("Open", 420, 90)
	open_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	open_button.pressed.connect(_on_open)
	box.add_child(open_button)
	home_button = UiKit.secondary("Home", 220, 64)
	home_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	home_button.visible = false
	home_button.pressed.connect(func() -> void: go("home"))
	box.add_child(home_button)


func open(_args: Dictionary = {}) -> void:
	_arm()


func _arm() -> void:
	for child in loot_box.get_children():
		child.queue_free()
	home_button.visible = false
	showing_loot = false
	if SaveGame.pending_count() <= 0:
		title_label.text = "No chests"
		open_button.visible = false
		home_button.visible = true
		loot_box.add_child(body("Win or lose a hunt and one comes home with you."))
		return
	var chest: Dictionary = SaveGame.data["chests"][0]
	var hunt := str(chest.get("kind", "hunt")) == "hunt"
	title_label.text = "Hunt chest" if hunt else "Small pouch"
	open_button.visible = true
	open_button.text = "Open"
	var biome := Catalog.biome(str(chest.get("biome", "meadow")))
	loot_box.add_child(body("From the %s." % str(biome["name"])))


func _on_open() -> void:
	if showing_loot:
		_arm()
		return
	_reveal()


func _reveal() -> void:
	var loot := SaveGame.open_next()
	if loot.is_empty():
		_arm()
		return
	for child in loot_box.get_children():
		child.queue_free()
	open_button.visible = false
	home_button.visible = true
	title_label.text = "Yours"
	if burst:
		burst.pop()
		AudioDirector.play("merge")
		AudioDirector.haptic(18)
	loot_box.add_child(UiKit.label("+%d coins" % int(loot["coins"]), 32, Color("ffe08a"), "x", 6))
	var totals := {}
	for drop in loot["cards"]:
		var id := str(drop["id"])
		totals[id] = int(totals.get(id, 0)) + int(drop["count"])
	for id in totals.keys():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.add_child(portrait(str(id), 72))
		var info := Catalog.critter(str(id))
		row.add_child(UiKit.label("+%d %s" % [int(totals[id]), str(info.get("name", id))], 26, UiKit.CREAM, "x", 5))
		loot_box.add_child(row)
	var gear: Dictionary = loot["gear"]
	if not gear.is_empty():
		var gear_label := UiKit.label(SaveGame.gear_text(gear), 22, Color("e7f2ff"), "x", 4)
		gear_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		loot_box.add_child(gear_label)
	if SaveGame.pending_count() > 0:
		open_button.visible = true
		open_button.text = "Next chest"
		showing_loot = true


class Burst extends Control:
	var parts: Array[Dictionary] = []
	var shaking := true
	var t := 0.0

	func _process(delta: float) -> void:
		t += delta
		if shaking:
			pivot_offset = size * 0.5
			rotation = sin(t * 9.0) * 0.06
		var alive := false
		for part in parts:
			part["life"] = float(part["life"]) - delta
			part["p"] = part["p"] + part["v"] * delta
			part["v"] = part["v"] + Vector2(0, 280.0) * delta
			if float(part["life"]) > 0.0:
				alive = true
		if not shaking and not alive:
			visible = false
			set_process(false)
		queue_redraw()

	func pop() -> void:
		shaking = false
		rotation = 0.0
		var origin := size * 0.5
		for i in 36:
			var ang := float(i) / 36.0 * TAU + randf_range(-0.1, 0.1)
			var speed := randf_range(180.0, 520.0)
			parts.append({
				"p": origin,
				"v": Vector2.from_angle(ang) * speed,
				"life": randf_range(0.45, 0.85),
				"max": 0.7,
				"s": randf_range(6.0, 14.0),
				"c": Color("ffe08a") if i % 2 == 0 else Color("7dff5a"),
			})

	func _draw() -> void:
		var c := size * 0.5
		if shaking:
			var body := Rect2(c.x - 70, c.y - 20, 140, 90)
			draw_rect(body, Color("8a4b16"), true)
			draw_rect(Rect2(c.x - 78, c.y - 48, 156, 36), Color("ffd56a"), true)
			draw_rect(Rect2(c.x - 8, c.y - 36, 16, 28), Color("ffe9a0"), true)
			draw_circle(c + Vector2(0, 24), 10, Color("fff1c2"))
		for part in parts:
			var life := float(part["life"])
			if life <= 0.0:
				continue
			var a := clampf(life / float(part["max"]), 0.0, 1.0)
			var col: Color = part["c"]
			col.a = a
			draw_circle(part["p"], float(part["s"]) * a, col)
