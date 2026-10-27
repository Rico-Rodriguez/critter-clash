extends Control
## Pause menu over the hunt.

signal resumed
signal abandoned

var _confirm := false
var _hunt: Hunt
var _taps: Array[float] = []
var _dev: DevPanel
var _peek: Tween


func open(h: Hunt) -> void:
	_hunt = h
	%Info.mouse_filter = Control.MOUSE_FILTER_STOP
	%Info.gui_input.connect(_on_info_input)
	%Info.text = "%s · %s · %s" % [DB.HEROES[h.hero_id]["name"], h.tier["name"], Ui.fmt_time(h.time)]
	%Resume.pressed.connect(func():
		Sfx.play("ui_back", -4.0)
		resumed.emit())
	%Abandon.pressed.connect(func():
		if not _confirm:
			_confirm = true
			%Abandon.text = "Tap again to leave"
			Sfx.play("ui_error", -6.0)
			return
		abandoned.emit())
	# Tapping the dimmed game around the menu resumes, like closing any sheet.
	get_node("Scrim").gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and _dev == null:
			Sfx.play("ui_back", -4.0)
			resumed.emit())
	var box := SettingsBox.new()
	box.in_hunt = true
	%Settings.add_child(box)
	Game.setting_changed.connect(_on_setting)
	Ui.pop_in(%Panel, 0.0, 0.92)


## A camera, button or graphics change: the world is paused behind a dark
## scrim, so lift the scrim for a moment and the player sees the new view.
func _on_setting(key: String) -> void:
	if not (key in ["camera", "buttons", "quality"]) or _dev != null:
		return
	if _peek:
		_peek.kill()
	var scrim: Control = get_node("Scrim")
	_peek = create_tween().set_parallel(true)
	_peek.tween_property(scrim, "modulate:a", 0.12, 0.18)
	_peek.tween_property(%Panel, "modulate:a", 0.4, 0.18)
	_peek.chain().tween_interval(0.9)
	_peek.chain().tween_property(scrim, "modulate:a", 1.0, 0.3)
	_peek.parallel().tween_property(%Panel, "modulate:a", 1.0, 0.3)


## Five taps on the info line within three seconds open the camera panel.
func _on_info_input(e: InputEvent) -> void:
	if not (e is InputEventMouseButton and e.pressed):
		return
	var now := Time.get_ticks_msec() / 1000.0
	_taps.append(now)
	while not _taps.is_empty() and now - _taps[0] > 3.0:
		_taps.pop_front()
	if _taps.size() >= 5 and _dev == null:
		_taps.clear()
		open_dev_panel()


## Shows the tuning panel over a see-through pause screen, so the camera
## changes are visible behind it.
func open_dev_panel() -> void:
	%Panel.visible = false
	get_node("Scrim").modulate.a = 0.15
	_dev = DevPanel.new()
	add_child(_dev)
	_dev.open(_hunt)
	_dev.closed.connect(func():
		_dev = null
		%Panel.visible = true
		get_node("Scrim").modulate.a = 1.0)
