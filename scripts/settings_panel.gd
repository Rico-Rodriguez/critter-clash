class_name SettingsPanel
extends VBoxContainer

## Music, sound and haptics: an on/off switch per channel and volume
## sliders for music and effects. Changes apply at once and persist.


func _ready() -> void:
	add_theme_constant_override("separation", 18)
	_row("MUSIC", "music_on", "music_vol")
	_row("SOUND EFFECTS", "sfx_on", "sfx_vol")
	_row("HAPTICS", "haptics_on", "")


func _row(title: String, on_key: String, vol_key: String) -> void:
	var plate := UiKit.Plate.new()
	plate.kind = "plaque"
	plate.pad = 18
	plate.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(plate)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	plate.add_child(col)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	col.add_child(top)
	var name := UiKit.label(title, 28, UiKit.GOLD.lightened(0.2), "x", 4)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(name)
	var sw := Switch.new()
	sw.on = bool(AudioDirector.settings.get(on_key, true))
	sw.custom_minimum_size = Vector2(132, 60)
	sw.changed.connect(func(v: bool) -> void:
		AudioDirector.set_setting(on_key, v)
		AudioDirector.sfx("ui_toggle")
		if on_key == "haptics_on" and v:
			AudioDirector.haptic("medium")
	)
	top.add_child(sw)
	if vol_key == "":
		return
	var slider := VolumeSlider.new()
	slider.value = float(AudioDirector.settings.get(vol_key, 0.8))
	slider.custom_minimum_size = Vector2(0, 56)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.moved.connect(func(v: float) -> void: AudioDirector.set_setting(vol_key, v))
	slider.released.connect(func() -> void:
		if vol_key == "sfx_vol":
			AudioDirector.sfx("gem", 0.0, 1.5)
	)
	col.add_child(slider)


## A forged toggle: a recessed groove with a gilt knob that slides across;
## the groove glows warm when on.
class Switch extends Control:
	signal changed(value: bool)
	var on := true
	var _k := 1.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		_k = 1.0 if on else 0.0

	func _gui_input(event: InputEvent) -> void:
		var tap := (event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT) or (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed)
		if tap:
			on = not on
			changed.emit(on)
			create_tween().tween_property(self, "_k", 1.0 if on else 0.0, 0.14).set_trans(Tween.TRANS_QUAD)
			accept_event()

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var h := r.size.y
		var rad := h * 0.5
		var groove := Color(0.04, 0.03, 0.02).lerp(Color(0.42, 0.24, 0.06), _k)
		_pill(r, Color(0.55, 0.4, 0.2))
		_pill(r.grow(-3.0), groove)
		# Inner shadow along the top lip.
		_pill(Rect2(r.position + Vector2(4, 4), Vector2(r.size.x - 8, h * 0.3)), Color(0, 0, 0, 0.35))
		var x := lerpf(rad, r.size.x - rad, _k)
		var c := Vector2(x, rad)
		draw_circle(c + Vector2(0, 3), rad - 5.0, Color(0, 0, 0, 0.5))
		draw_circle(c, rad - 5.0, Color("b8863a"))
		draw_circle(c, rad - 8.0, Color("e6c27a"))
		draw_circle(c + Vector2(-rad * 0.18, -rad * 0.2), rad * 0.3, Color(1, 0.96, 0.8, 0.55))
		var font := UiKit.font_x
		var txt := "ON" if on else "OFF"
		var tx := (r.size.x - rad * 2.0) * 0.5 + (0.0 if on else rad * 2.0) - (r.size.x - rad * 2.0) * 0.5
		UiKit.draw_text(self, font, Vector2(tx if not on else 4.0, h * 0.5 + 8), txt, 20, Color("fff1d0") if on else Color(0.7, 0.62, 0.5), Color(0.05, 0.03, 0.02), 2, r.size.x - rad * 2.0)

	func _pill(r: Rect2, col: Color) -> void:
		var rad := r.size.y * 0.5
		draw_rect(Rect2(r.position + Vector2(rad, 0), Vector2(r.size.x - rad * 2.0, r.size.y)), col)
		draw_circle(r.position + Vector2(rad, rad), rad, col)
		draw_circle(r.position + Vector2(r.size.x - rad, rad), rad, col)


## Volume: a recessed track, a gilt fill with a soft glow, and a knob that
## follows the finger.
class VolumeSlider extends Control:
	signal moved(value: float)
	signal released
	var value := 0.8
	var _drag := false

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _gui_input(event: InputEvent) -> void:
		var press := false
		var lift := false
		var at := Vector2.ZERO
		if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			press = event.pressed
			lift = not event.pressed
			at = event.position
		elif event is InputEventScreenTouch:
			press = event.pressed
			lift = not event.pressed
			at = event.position
		elif (event is InputEventMouseMotion or event is InputEventScreenDrag) and _drag:
			at = event.position
			_set_from(at.x)
			accept_event()
			return
		if press:
			_drag = true
			_set_from(at.x)
			accept_event()
		elif lift and _drag:
			_drag = false
			released.emit()
			accept_event()

	func _set_from(x: float) -> void:
		var rad := size.y * 0.42
		value = clampf((x - rad) / maxf(size.x - rad * 2.0, 1.0), 0.0, 1.0)
		moved.emit(value)
		queue_redraw()

	func _draw() -> void:
		var h := size.y
		var rad := h * 0.42
		var track := Rect2(rad, h * 0.5 - 7, size.x - rad * 2.0, 14)
		draw_rect(track.grow(2.0), Color(0.5, 0.36, 0.18))
		draw_rect(track, Color(0.03, 0.02, 0.015))
		draw_rect(Rect2(track.position, Vector2(track.size.x, 4)), Color(0, 0, 0, 0.6))
		var fill := Rect2(track.position, Vector2(track.size.x * value, track.size.y))
		for i in 4:
			draw_rect(fill.grow(2.0 + i * 2.0), Color(1.0, 0.7, 0.3, 0.05))
		draw_rect(fill, Color("c99a48"))
		draw_rect(Rect2(fill.position, Vector2(fill.size.x, 4)), Color(1, 0.92, 0.7, 0.5))
		var c := Vector2(track.position.x + track.size.x * value, h * 0.5)
		draw_circle(c + Vector2(0, 3), rad - 4.0, Color(0, 0, 0, 0.5))
		draw_circle(c, rad - 4.0, Color("b8863a"))
		draw_circle(c, rad - 7.0, Color("e6c27a"))
		draw_circle(c + Vector2(-rad * 0.18, -rad * 0.2), rad * 0.28, Color(1, 0.96, 0.8, 0.55))
