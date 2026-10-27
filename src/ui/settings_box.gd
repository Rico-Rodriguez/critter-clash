class_name SettingsBox
extends VBoxContainer
## Volume, screen shake and graphics rows; used by the pause menu and the camp.
## Every row saves at once, and a running hunt applies it at once too (see
## Hunt.apply_setting); in the camp the next hunt picks it up.

## True when shown over a hunt, where nothing waits for the next one.
var in_hunt := false


func _ready() -> void:
	add_theme_constant_override("separation", 14)
	# Slider drags save on release; this catches a close in the middle of one.
	tree_exiting.connect(Game.save)
	_slider("Music", "music")
	_slider("Effects", "sfx")
	_choices("Screen shake", "shake_level", ["off", "low", "medium", "high"])
	var buzz := CheckButton.new()
	buzz.text = "Vibration"
	buzz.button_pressed = bool(Game.setting("haptics"))
	buzz.focus_mode = Control.FOCUS_NONE
	buzz.toggled.connect(func(on: bool):
		Game.set_setting("haptics", on)
		Sfx.play("ui_toggle", -4.0)
		Ui.buzz(30))
	add_child(buzz)
	_choices("Buttons", "buttons", ["right", "left"])
	_choices("Camera", "camera", ["close", "standard", "wide"])
	_choices("Graphics", "quality", ["auto", "low", "high"])
	_choices("Frame rate", "fps", ["60", "30"])
	if not in_hunt:
		var note := Ui.label("Button, camera and graphics changes apply in your next hunt. 30 fps saves battery.", "Small")
		note.add_theme_font_size_override("font_size", 17)
		add_child(note)


## A row of exclusive toggle buttons that writes the chosen value to a setting.
func _choices(title: String, key: String, options: Array) -> void:
	var row := HBoxContainer.new()
	row.add_child(Ui.label(title, "Body"))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(sp)
	for o: String in options:
		var b := Button.new()
		b.text = o.capitalize()
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.theme_type_variation = "Ghost"
		b.add_theme_font_size_override("font_size", 20)
		b.button_pressed = str(Game.setting(key)) == o
		b.pressed.connect(func():
			Game.set_setting(key, o)
			Sfx.play("ui_tap", -4.0)
			for c in row.get_children():
				if c is Button:
					c.button_pressed = c == b)
		row.add_child(b)
	add_child(row)


func _slider(title: String, key: String) -> void:
	var row := HBoxContainer.new()
	var l := Ui.label(title, "Body")
	l.custom_minimum_size = Vector2(120, 0)
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = float(Game.setting(key))
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.focus_mode = Control.FOCUS_NONE
	s.value_changed.connect(func(v: float):
		Game.data["settings"][key] = v
		Sfx.refresh_volume())
	s.drag_ended.connect(func(_c: bool):
		Game.save()
		if key == "sfx":
			Sfx.play("ui_tap"))
	row.add_child(s)
	add_child(row)
