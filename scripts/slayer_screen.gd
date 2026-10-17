extends ScreenBase

var speech: Label
var progress: Label
var points_label: Label
var streak_label: Label


func build() -> void:
	show_nav = true
	nav_tab = ""
	var box := column()
	box.add_child(header())
	box.add_child(h1("Slayer Master"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	var face := portrait("bramble", 140)
	row.add_child(face)
	var talk := VBoxContainer.new()
	talk.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(talk)
	talk.add_child(UiKit.label("Warden Bramble", 26, UiKit.CREAM, "x", 5))
	speech = body("Bring me a task and I will pay in slayer points.", 18)
	speech.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	talk.add_child(speech)
	progress = UiKit.label("", 22, Color("ffe08a"), "x", 4)
	progress.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(progress)
	var stats := HBoxContainer.new()
	stats.alignment = BoxContainer.ALIGNMENT_CENTER
	stats.add_theme_constant_override("separation", 18)
	box.add_child(stats)
	points_label = UiKit.label("", 22, Color("ffe08a"), "x", 4)
	streak_label = UiKit.label("", 22, Color("b6ff9a"), "x", 4)
	stats.add_child(points_label)
	stats.add_child(streak_label)
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 8)
	box.add_child(actions)
	var take := UiKit.button("NEW TASK", 210, 68)
	take.pressed.connect(_take)
	var done := UiKit.confirm("TURN IN", 180, 68)
	done.pressed.connect(_turn_in)
	var skip := UiKit.danger("CANCEL", 160, 68)
	skip.pressed.connect(_cancel)
	actions.add_child(take)
	actions.add_child(done)
	actions.add_child(skip)
	box.add_child(UiKit.label("Points shop", 28, UiKit.CREAM, "x", 5))
	for offer in Catalog.SLAYER_SHOP:
		box.add_child(_offer(offer))
	box.add_child(back_button("home"))
	_refresh()


func _refresh() -> void:
	var task: Dictionary = SaveGame.data["slayer"]["task"]
	if task.is_empty():
		speech.text = "I have work. Take a task, keep a streak, spend the points."
		progress.text = "No task yet"
	else:
		speech.text = str(task["text"])
		progress.text = "%d / %d" % [int(task.get("have", 0)), int(task["need"])]
	points_label.text = "%d points" % int(SaveGame.data["slayer"]["points"])
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
	var button := UiKit.button("", 640, 64)
	var line := UiKit.label("%s   ·   %d pts" % [str(offer["name"]), int(offer["cost"])], 26, Color.WHITE, "x", 4)
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	line.set_anchors_preset(Control.PRESET_FULL_RECT)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(line)
	button.pressed.connect(func() -> void:
		if SaveGame.buy_slayer(str(offer["id"])):
			toast("Bought %s" % str(offer["name"]))
			_refresh()
		else:
			toast("Not enough points.")
	)
	return button
