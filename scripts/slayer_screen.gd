extends ScreenBase

var speech: Label
var progress: Label
var points_label: Label
var streak_label: Label


var task_bar: Control


func build() -> void:
	show_nav = true
	nav_tab = ""
	var box := column()
	box.add_theme_constant_override("separation", 16)
	box.add_child(header())
	box.add_child(h1("Slayer Master"))
	# The warden speaks from a framed dialogue panel.
	var talk_plate := UiKit.Plate.new()
	talk_plate.kind = "panel"
	talk_plate.pad = 22
	box.add_child(talk_plate)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	talk_plate.add_child(row)
	var medal := UiKit.Medal.new()
	medal.tex = SpriteBank.head("bramble")
	medal.custom_minimum_size = Vector2(150, 150)
	medal.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(medal)
	var talk := VBoxContainer.new()
	talk.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	talk.alignment = BoxContainer.ALIGNMENT_CENTER
	talk.add_theme_constant_override("separation", 6)
	row.add_child(talk)
	talk.add_child(UiKit.label("WARDEN BRAMBLE", 26, UiKit.GOLD.lightened(0.2), "x", 3))
	speech = UiKit.label("", 21, UiKit.CREAM, "m", 2)
	speech.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	talk.add_child(speech)
	# Current task with a forged progress bar.
	var task_plate := UiKit.Plate.new()
	task_plate.kind = "plaque"
	task_plate.pad = 18
	box.add_child(task_plate)
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 10)
	task_plate.add_child(tv)
	var head_row := HBoxContainer.new()
	tv.add_child(head_row)
	head_row.add_child(UiKit.label("CURRENT TASK", 20, UiKit.MUTED, "x", 2))
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head_row.add_child(gap)
	progress = UiKit.label("", 22, UiKit.GOLD.lightened(0.2), "x", 2)
	head_row.add_child(progress)
	task_bar = TaskBar.new()
	task_bar.custom_minimum_size = Vector2(0, 26)
	tv.add_child(task_bar)
	var stats := HBoxContainer.new()
	stats.add_theme_constant_override("separation", 18)
	tv.add_child(stats)
	points_label = UiKit.label("", 22, UiKit.GOLD.lightened(0.2), "x", 2)
	var gap2 := Control.new()
	gap2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	streak_label = UiKit.label("", 22, Color("9fd88a"), "x", 2)
	stats.add_child(points_label)
	stats.add_child(gap2)
	stats.add_child(streak_label)
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 12)
	box.add_child(actions)
	var take := UiKit.button("NEW TASK", 250, 84, "gold")
	take.pressed.connect(_take)
	var done := UiKit.confirm("TURN IN", 220, 84)
	done.pressed.connect(_turn_in)
	var skip := UiKit.secondary("CANCEL", 200, 84)
	skip.pressed.connect(_cancel)
	actions.add_child(take)
	actions.add_child(done)
	actions.add_child(skip)
	box.add_child(_section("POINTS SHOP"))
	for offer in Catalog.SLAYER_SHOP:
		box.add_child(_offer(offer))
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)
	box.add_child(back_button("home"))
	_refresh()


func _section(text: String) -> Control:
	var l := UiKit.label(text, 24, UiKit.GOLD, "x", 2)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var rule := SectionRule.new()
	rule.custom_minimum_size = Vector2(0, 44)
	rule.add_child(l)
	l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return rule


func _refresh() -> void:
	var task: Dictionary = SaveGame.data["slayer"]["task"]
	if task.is_empty():
		speech.text = "I have work. Take a task, keep a streak, spend the points."
		progress.text = "None"
	else:
		speech.text = str(task["text"])
		progress.text = "%d / %d" % [int(task.get("have", 0)), int(task["need"])]
	points_label.text = "%d points" % int(SaveGame.data["slayer"]["points"])
	var t: Dictionary = SaveGame.data["slayer"]["task"]
	task_bar.ratio = 0.0 if t.is_empty() else clampf(float(t.get("have", 0)) / maxf(float(t["need"]), 1.0), 0.0, 1.0)
	task_bar.queue_redraw()
	var streak := int(SaveGame.data["slayer"]["streak"])
	streak_label.text = "Streak %d  ·  +%d" % [streak, streak * 5]


func _take() -> void:
	SaveGame.assign_task()
	_refresh()


func _turn_in() -> void:
	var gained := SaveGame.complete_task()
	if gained > 0:
		toast("+%d slayer points" % gained)
	_refresh()


func _cancel() -> void:
	SaveGame.cancel_task()
	toast("Streak reset.")
	_refresh()


func _offer(offer: Dictionary) -> Button:
	var button := Button.new()
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(0, 88)
	var none := StyleBoxEmpty.new()
	for st in ["normal", "hover", "pressed", "focus"]:
		button.add_theme_stylebox_override(st, none)
	var fr := UiKit.Frame.new("plaque", "leather", {})
	fr.margin = 2.0
	button.add_child(fr)
	var h := HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 28
	h.offset_right = -20
	button.add_child(h)
	var name := UiKit.label(str(offer["name"]).to_upper(), 24, UiKit.CREAM, "x", 2)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(name)
	var price := UiKit.label("%d PTS" % int(offer["cost"]), 24, UiKit.GOLD.lightened(0.2), "x", 2)
	price.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	price.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(price)
	button.button_down.connect(func() -> void:
		button.pivot_offset = button.size * 0.5
		create_tween().tween_property(button, "scale", Vector2(0.97, 0.97), 0.06))
	button.button_up.connect(func() -> void:
		create_tween().tween_property(button, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT))
	button.pressed.connect(func() -> void:
		if SaveGame.buy_slayer(str(offer["id"])):
			toast("Bought %s" % str(offer["name"]))
			_refresh()
		else:
			toast("Not enough points.")
	)
	return button


class TaskBar extends Control:
	var ratio := 0.0

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var rad := size.y * 0.5
		UiKit.ch_fill(self, r, rad, Color("e8c886"), Color("4e3012"))
		UiKit.ch_fill(self, r.grow(-3), rad - 3, Color("080605"), Color("1c1510"))
		var bar := r.grow(-5)
		var w := bar.size.x * ratio
		if w > bar.size.y:
			UiKit.ch_fill(self, Rect2(bar.position, Vector2(w, bar.size.y)), bar.size.y * 0.5, Color("d8352a").lightened(0.2), Color("d8352a").darkened(0.45))


class SectionRule extends Control:
	func _draw() -> void:
		var y := size.y * 0.5
		var gold := Color("c8963a")
		draw_line(Vector2(20, y), Vector2(size.x * 0.5 - 150, y), Color(gold, 0.7), 2.0, true)
		draw_line(Vector2(size.x * 0.5 + 150, y), Vector2(size.x - 20, y), Color(gold, 0.7), 2.0, true)
		for x in [size.x * 0.5 - 150, size.x * 0.5 + 150]:
			draw_colored_polygon(PackedVector2Array([Vector2(x - 7, y), Vector2(x, y - 5), Vector2(x + 7, y), Vector2(x, y + 5)]), Color("e8c886"))
