class_name StashScreen
extends ScreenBase

## The Hub stash (see docs/stash.md): the materials the player has parked in
## the Hub, kept out of the bag so the bag stays a clean "sell this" pile.
## The bag is the sell pile: the Skills screen sells it, one stack or the
## whole lot. The stash is the keep pile: nothing sells out of it, and a
## stack only leaves when the player takes it back into the bag.
##
## Two tabs, the way the Skills screen's bag is split:
##   STASH - what is parked in the Hub. A row takes it back into the bag.
##   BAG   - what the player is carrying. A row parks it in the stash.
## Both tabs have a bulk action (take the lot, park the lot). Neither asks
## first: a park and a take are both ways back, so nothing is ever lost.

## The tab buttons, by tab id.
var _tab_buttons := {}
var _content: VBoxContainer
var _summary: Label
## The row of bulk actions under the tab bar.
var _actions: HBoxContainer
## The list the tabs fill, so a rebuilt tab can let touches through again.
var _scroll: ScrollContainer


func build() -> void:
	show_nav = true
	nav_tab = ""
	var box := column()
	box.add_child(header_with_back("home"))
	box.add_child(h1("Stash"))
	_summary = UiKit.label("", 24, Color("e6d8bc"), "x", 4)
	_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_summary)
	box.add_child(_tab_bar())
	# The bulk action of the current tab sits under the tab bar and stays
	# there while the list below it scrolls.
	_actions = HBoxContainer.new()
	_actions.alignment = BoxContainer.ALIGNMENT_CENTER
	_actions.add_theme_constant_override("separation", 14)
	box.add_child(_actions)
	# The list of stacks can run past the screen, so it scrolls; the tab bar
	# and back chip stay put.
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	_scroll = scroll
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 16)
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_content)
	_show_tab("stash")


## Where the back chip goes: the Hub by default, the Skills screen's bag when
## the player came from there.
func open(args: Dictionary = {}) -> void:
	var from := str(args.get("from", "home"))
	back_target = from if from == "skills" else "home"


func _tab_bar() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	for entry in [["stash", "Stash"], ["bag", "Bag"]]:
		var key := str(entry[0])
		var button := UiKit.secondary(str(entry[1]), 210, 88)
		button.toggle_mode = true
		button.pressed.connect(func() -> void: _show_tab(key))
		_tab_buttons[key] = button
		row.add_child(button)
	return row


func _show_tab(tab: String) -> void:
	for key in _tab_buttons:
		var button: Button = _tab_buttons[key]
		button.set_pressed_no_signal(key == tab)
		button.modulate = Color(1.08, 1.02, 0.9) if key == tab else Color(0.6, 0.6, 0.64)
	if _summary != null:
		if tab == "bag":
			_summary.text = "Bag · %d items · %d coins" % [SaveGame.bag_count(), SaveGame.bag_value()]
		else:
			_summary.text = "Stash · %d items · %d coins" % [SaveGame.stash_total(), SaveGame.stash_value()]
	if _content == null:
		return
	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()
	for child in _actions.get_children():
		_actions.remove_child(child)
		child.queue_free()
	if tab == "bag":
		_bag_tab()
	else:
		_stash_tab()
	# The rows were built after the screen was ready, so they still swallow
	# touches: let them pass, or the list cannot be dragged.
	pass_through(_scroll)


## What is parked in the Hub. A row takes the stack back into the bag.
func _stash_tab() -> void:
	_bulk_action("WITHDRAW ALL", SaveGame.stash_total() > 0, _withdraw_all)
	var held := _held(SaveGame.data["stash"])
	if held.is_empty():
		_content.add_child(_empty_stash())
		return
	_content.add_child(body("What you have parked in the Hub. The stash is never sold: take a stack back into the bag when you want it."))
	_add_groups(held, "stash", _withdraw)


## What the player is carrying. A row parks the stack in the stash.
func _bag_tab() -> void:
	_bulk_action("DEPOSIT ALL", SaveGame.bag_count() > 0, _deposit_all)
	var held := _held(SaveGame.data["materials"])
	if held.is_empty():
		_content.add_child(_empty_bag())
		return
	_content.add_child(body("What you are carrying. The bag is the sell pile: park what you want to keep in the stash."))
	_add_groups(held, "bag", _deposit)


## The materials held in a pile (the bag or the stash), in a stable order:
## the known ones (the boss spoils, then the gathered resources) and after
## them anything else the save holds, so a stack nobody has priced yet is
## still shown rather than sitting unseen.
func _held(counts: Dictionary) -> Array:
	var out: Array = []
	var known := {}
	for id in MaterialDB.all_ids():
		known[id] = true
		out.append(id)
	for key in counts.keys():
		var id := str(key)
		if not known.has(id):
			out.append(id)
	var held: Array = []
	for id in out:
		if int(counts.get(id, 0)) > 0:
			held.append(id)
	return held


## The list of stacks, split into the boss spoils, the gathered resources and
## anything else, the way the bag on the Skills screen is split. The pile is
## the stash or the bag, and the button on a row moves the stack to the
## other one.
func _add_groups(held: Array, source: String, handler: Callable) -> void:
	var boss: Array = []
	var gathered: Array = []
	var other: Array = []
	for id in held:
		match MaterialDB.kind_of(str(id)):
			"boss":
				boss.append(id)
			"gathered":
				gathered.append(id)
			_:
				other.append(id)
	if not boss.is_empty():
		_content.add_child(_group_label("FROM THE HUNT"))
		for id in boss:
			_content.add_child(_row(str(id), source, handler))
	if not gathered.is_empty():
		_content.add_child(_group_label("GATHERED"))
		for id in gathered:
			_content.add_child(_row(str(id), source, handler))
	if not other.is_empty():
		_content.add_child(_group_label("OTHER"))
		for id in other:
			_content.add_child(_row(str(id), source, handler))


## One stack: its icon, its name, how many there are and what the stack is
## worth. The button moves it to the other pile.
func _row(id: String, source: String, handler: Callable) -> Control:
	var row := StashRow.new()
	var stashed := source == "stash"
	var count := SaveGame.stash_count(id) if stashed else SaveGame.material_count(id)
	row.setup(id, count, MaterialDB.price(id), "WITHDRAW" if stashed else "DEPOSIT")
	row.act.connect(handler)
	return row


## A group head inside the list.
func _group_label(text: String) -> Control:
	var l := UiKit.label(text, 22, UiKit.GOLD, "x", 3)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


## An empty stash: the Hub has nothing parked yet.
func _empty_stash() -> Control:
	var l := body("The stash is empty. Park something from the bag and it waits here, out of reach of the sell button.")
	l.add_theme_color_override("font_color", UiKit.MUTED)
	return l


## An empty bag: the wilds have given nothing yet.
func _empty_bag() -> Control:
	var l := body("The bag is empty. Work a node in a biome, or bring a boss down, and its spoils land here.")
	l.add_theme_color_override("font_color", UiKit.MUTED)
	return l


## The bulk action under the tab bar: the whole pile, in one go.
func _bulk_action(caption: String, enabled: bool, handler: Callable) -> void:
	var button := UiKit.button(caption, 320, 88)
	# Set before the button enters the tree so its forged skin builds in the
	# grey tone and the caption dims with it (UiKit.Btn reads disabled in _ready).
	button.disabled = not enabled
	button.pressed.connect(handler)
	_actions.add_child(button)


## Parks a stack from the bag in the stash.
func _deposit(id: String) -> void:
	var moved := SaveGame.deposit_stash(id)
	if moved <= 0:
		AudioDirector.sfx("ui_error")
		return
	AudioDirector.sfx("ui_tap")
	AudioDirector.haptic("light")
	toast("Parked %d %s" % [moved, MaterialDB.name_of(id)])
	_show_tab("bag")


## Takes a stack out of the stash and back into the bag.
func _withdraw(id: String) -> void:
	var moved := SaveGame.withdraw_stash(id)
	if moved <= 0:
		AudioDirector.sfx("ui_error")
		return
	AudioDirector.sfx("ui_tap")
	AudioDirector.haptic("light")
	toast("Took %d %s" % [moved, MaterialDB.name_of(id)])
	_show_tab("stash")


## Parks the whole bag in the stash.
func _deposit_all() -> void:
	var moved := SaveGame.deposit_all_stash()
	if moved <= 0:
		AudioDirector.sfx("ui_error")
		return
	AudioDirector.sfx("chest_rattle")
	AudioDirector.haptic("medium")
	toast("Parked %d materials" % moved)
	_show_tab("bag")


## Takes the whole stash back into the bag.
func _withdraw_all() -> void:
	var moved := SaveGame.withdraw_all_stash()
	if moved <= 0:
		AudioDirector.sfx("ui_error")
		return
	AudioDirector.sfx("chest_rattle")
	AudioDirector.haptic("medium")
	toast("Took %d materials" % moved)
	_show_tab("stash")


## One material of the stash or the bag: its icon, its name, how many of it
## there are and what the stack is worth. The button moves the stack to the
## other pile.
class StashRow extends PanelContainer:
	signal act(id: String)
	var id := ""
	var count := 0
	var price := 0
	var action_text := "DEPOSIT"

	func setup(material_id: String, have: int, unit: int, caption: String) -> void:
		id = material_id
		count = have
		price = unit
		action_text = caption

	func _ready() -> void:
		custom_minimum_size = Vector2(0, 132)
		var empty := StyleBoxEmpty.new()
		for side in ["left", "right", "top", "bottom"]:
			empty.set("content_margin_" + side, 16)
		add_theme_stylebox_override("panel", empty)
		var fr := UiKit.Frame.new("plaque", "leather")
		fr.margin = 14.0
		add_child(fr)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		add_child(row)
		var icon := MaterialIcon.new()
		icon.id = id
		icon.custom_minimum_size = Vector2(92, 92)
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(icon)
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		col.add_theme_constant_override("separation", 4)
		row.add_child(col)
		col.add_child(UiKit.label(MaterialDB.name_of(id).to_upper(), 26, Color("fff1d6"), "x", 5))
		if price > 0:
			col.add_child(UiKit.label("×%d · %d coins each" % [count, price], 20, UiKit.MUTED, "b", 3))
		else:
			col.add_child(UiKit.label("×%d · no price yet" % count, 20, UiKit.MUTED, "b", 3))
		var right := VBoxContainer.new()
		right.alignment = BoxContainer.ALIGNMENT_CENTER
		right.add_theme_constant_override("separation", 6)
		row.add_child(right)
		if price > 0:
			right.add_child(UiKit.label("%d COINS" % (count * price), 21, UiKit.GOLD.lightened(0.15), "x", 3))
		var button := UiKit.button(action_text, 200, 88)
		button.pressed.connect(func() -> void: act.emit(id))
		right.add_child(button)
