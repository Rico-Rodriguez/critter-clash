extends ScreenBase

var speech: Label
var progress: Label
var points_label: Label
var streak_label: Label
var hint: Label
var take_button: Button
var done_button: Button
var skip_button: Button


var task_bar: Control


func build() -> void:
	show_nav = true
	nav_tab = ""
	var box := column()
	box.add_theme_constant_override("separation", 16)
	box.add_child(header_with_back("home"))
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
	# 88 px tall, in step with the shared tap-target floor.
	take_button = UiKit.button("NEW TASK", 250, 88, "gold")
	take_button.pressed.connect(_take)
	done_button = UiKit.confirm("TURN IN", 220, 88)
	done_button.pressed.connect(_turn_in)
	skip_button = UiKit.secondary("CANCEL", 200, 88)
	skip_button.pressed.connect(_cancel)
	actions.add_child(take_button)
	actions.add_child(done_button)
	actions.add_child(skip_button)
	# One line under the actions that always says why an off action is off.
	hint = UiKit.label("", 20, UiKit.MUTED, "b", 2)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(hint)
	box.add_child(_section("POINTS SHOP"))
	for offer in Catalog.SLAYER_SHOP:
		box.add_child(_offer(offer))
	# The warden's ledger: every hunting ground, its tasks and their worth,
	# sealed until the biome opens. Fills the page with the long goal.
	box.add_child(_section("HUNTING GROUNDS"))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var grounds := VBoxContainer.new()
	grounds.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grounds.add_theme_constant_override("separation", 10)
	scroll.add_child(grounds)
	for biome in Catalog.BIOMES:
		grounds.add_child(_ground(biome))
	_refresh()


func _ground(biome: Dictionary) -> Control:
	var id := str(biome["id"])
	var open := SaveGame.biome_open(id)
	var plate := UiKit.Plate.new()
	plate.kind = "plaque"
	plate.pad = 14
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	plate.add_child(row)
	var medal := UiKit.Medal.new()
	medal.tex = SpriteBank.head(str(biome["boss"]))
	medal.locked = not open
	medal.custom_minimum_size = Vector2(86, 86)
	medal.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(medal)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 2)
	row.add_child(col)
	var ink := Color("fff1d6") if open else Color("9a8e7c")
	var name_label := UiKit.label(str(biome["name"]).to_upper(), 24, ink, "x", 4)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(name_label)
	for task in Catalog.SLAYER_TASKS:
		if str(task["biome"]) != id:
			continue
		var line := HBoxContainer.new()
		# Long contract lines wrap instead of clipping, so nothing is hidden.
		var t := UiKit.label(str(task["text"]), 20, Color("e6d8bc") if open else Color("8a7e6c"), "b", 3)
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.add_child(t)
		line.add_child(UiKit.label("%d PTS" % int(task["points"]), 20, UiKit.GOLD.lightened(0.15) if open else Color("8a7e6c"), "x", 3))
		col.add_child(line)
	if not open:
		col.add_child(UiKit.label("SEALED · " + SaveGame.biome_lock_text(id), 18, Color("c8b8a0"), "x", 3))
	return plate


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
	var slate: Dictionary = SaveGame.data.get("slayer", {})
	var task: Variant = slate.get("task", {})
	var open := typeof(task) == TYPE_DICTIONARY and not (task as Dictionary).is_empty()
	var ready := false
	if not open:
		speech.text = "The wilds still hunger. Take a contract, keep the streak alive, spend what you earn."
		progress.text = "None"
		hint.text = "No contract in hand. Take one from the warden to start hunting."
	else:
		var t: Dictionary = task
		speech.text = str(t.get("text", "The trail is cold."))
		var need := maxi(int(t.get("need", 1)), 1)
		var have := int(t.get("have", 0))
		progress.text = "%d / %d" % [have, need]
		ready = have >= need
		if ready:
			hint.text = ""
		else:
			hint.text = "Finish the contract first: %d to go." % (need - have)
	points_label.text = "%d points" % int(slate.get("points", 0))
	if open:
		var td: Dictionary = task
		task_bar.ratio = clampf(float(td.get("have", 0)) / maxf(float(td.get("need", 1)), 1.0), 0.0, 1.0)
	else:
		task_bar.ratio = 0.0
	task_bar.queue_redraw()
	var streak := int(slate.get("streak", 0))
	streak_label.text = "Streak %d  ·  +%d" % [streak, streak * 5]
	# Dead metal reads as dead metal: the grey skin carries the look, and the
	# hint line above already carries the why for each locked action.
	_lock(done_button, not (open and ready))
	_lock(skip_button, not open)


## Disabled actions sink to iron grey, inside and out.
func _lock(button: Button, locked: bool) -> void:
	button.disabled = locked
	var b := button as UiKit.Btn
	if b != null and b.skin != null:
		b.skin.tone = "grey" if locked else b.tone
		b.skin.apply()


func _take() -> void:
	if SaveGame.assign_task().is_empty():
		toast("Every trail is sealed. Win hunts to open new ground.")
	_refresh()


func _turn_in() -> void:
	var gained := SaveGame.complete_task()
	if gained > 0:
		toast("+%d slayer points" % gained)
	else:
		toast("The contract is not yet done.")
	# Every 5th consecutive turn-in also pays an earned gear piece; that reward
	# gets its own toast once the points line has faded.
	var reward: Dictionary = SaveGame.last_streak_reward
	if not reward.is_empty():
		var text := "Streak reward: "
		if reward.has("item"):
			text += str(GearDB.item(str(reward["item"])).get("name", ""))
		else:
			text += "%d coins" % int(reward.get("coins", 0))
		var tw := create_tween()
		tw.tween_interval(1.05)
		tw.tween_callback(func() -> void: toast(text))
	_refresh()


func _cancel() -> void:
	SaveGame.cancel_task()
	toast("Contract abandoned. The streak is forfeit.")
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
	var text_col := VBoxContainer.new()
	text_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_col.alignment = BoxContainer.ALIGNMENT_CENTER
	text_col.add_theme_constant_override("separation", 0)
	h.add_child(text_col)
	var name_label := UiKit.label(str(offer["name"]).to_upper(), 24, UiKit.CREAM, "x", 2)
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_col.add_child(name_label)
	# The offer text under the name: what a purchase actually fetches.
	var detail := UiKit.label(str(offer.get("detail", "")), 16, UiKit.MUTED, "b", 2)
	detail.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail.visible = str(offer.get("detail", "")) != ""
	text_col.add_child(detail)
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
			AudioDirector.haptic("light")
			toast("Bought %s" % str(offer["name"]))
			_refresh()
		else:
			AudioDirector.haptic("light")
			toast("Not enough points. Turn in contracts to earn more.")
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
