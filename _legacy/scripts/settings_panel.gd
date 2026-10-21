class_name SettingsPanel
extends VBoxContainer

## Every player option on one panel: music, SFX and haptics, camera shake,
## flashing and damage-number comfort toggles, the text scale and the
## left-handed HUD swap. Changes apply at once and persist straight away.
## Each control is at least 88 device px tall on a 720-wide phone and
## carries its own visible label or value readout.


func _ready() -> void:
	add_theme_constant_override("separation", 14)
	_build()


## Rebuild in place, so changing the text size (or a future theme option)
## rescales the labels this panel displays right away.
func _build() -> void:
	for child in get_children():
		child.queue_free()
	_section("SOUND")
	_row("MUSIC", "music_on", "music_vol")
	_row("SOUND EFFECTS", "sfx_on", "sfx_vol")
	_section("TOUCH & CONTROLS")
	_row("HAPTICS", "haptics_on", "")
	_row("SCREEN SHAKE", "", "screen_shake")
	_row("LEFT-HANDED HUD", "left_handed", "")
	_section("COMFORT")
	_row("REDUCE FLASHING", "reduce_flashing", "")
	_row("DAMAGE NUMBERS", "damage_numbers", "")
	_section("TEXT SIZE")
	_row_options()


func _section(title: String) -> void:
	var l := UiKit.label(title, 22, UiKit.MUTED, "b")
	var first := get_child_count() > 0
	if first:
		var gap := Control.new()
		gap.custom_minimum_size = Vector2(0, 8)
		add_child(gap)
	add_child(l)


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
	if on_key != "":
		var sw := Switch.new()
		sw.on = bool(AudioDirector.settings[on_key])
		sw.custom_minimum_size = Vector2(132, 64)
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
	slider.value = float(AudioDirector.settings[vol_key])
	slider.custom_minimum_size = Vector2(0, 64)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.moved.connect(func(v: float) -> void:
		AudioDirector.set_setting(vol_key, v)
		_preview_tick(vol_key)
	)
	slider.released.connect(_release_preview.bind(vol_key))
	col.add_child(slider)


## One cycle-of-three row: Text size 100 / 115 / 130 %.
func _row_options() -> void:
	var plate := UiKit.Plate.new()
	plate.kind = "plaque"
	plate.pad = 18
	plate.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(plate)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	plate.add_child(col)
	var name := UiKit.label("TEXT SIZE 100 / 115 / 130%", 28, UiKit.GOLD.lightened(0.2), "x", 4)
	col.add_child(name)
	var seg := Seg.new()
	seg.custom_minimum_size = Vector2(0, 64)
	seg.value = int(AudioDirector.settings["text_size"])
	seg.changed.connect(func(v: int) -> void:
		AudioDirector.set_setting("text_size", v)
		# Labels are scaled at creation: rebuild the rows so the panel
		# shows the new size right away.
		_build.call_deferred()
	)
	col.add_child(seg)


## Live preview of the channel being dragged: a soft tick as the SFX volume
## moves (the music bus previews itself live since the theme is playing).
var _preview_ms := 0


func _preview_tick(vol_key: String) -> void:
	var now := Time.get_ticks_msec()
	if now - _preview_ms < 160:
		return
	_preview_ms = now
	if vol_key == "sfx_vol":
		AudioDirector.sfx("ui_tap", -6.0)


func _release_preview(vol_key: String) -> void:
	if vol_key == "sfx_vol":
		AudioDirector.sfx("gem", 0.0, 1.5)
	elif vol_key == "music_vol":
		# A short chord on the Music bus: previews the music volume (and
		# stays silent if music is switched off). The victory sting is an
		# eight second cue and has no business in a slider preview.
		AudioDirector.sfx("music_stab")


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
## follows the finger. The current 0-100 % value is engraved in the middle
## of the track: the control labels itself, so it needs no extra HUD text.
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
		# Self-label: the live 0-100 % readout engraved over the track.
		var font := UiKit.font_b
		var px := UiKit.text_px(24)
		var txt := "%d%%" % int(round(value * 100.0))
		var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
		UiKit.draw_text(self, font, Vector2(size.x * 0.5 - w * 0.5, h * 0.5 + px * 0.34), txt, px, Color("f9efdd"), Color(0.06, 0.04, 0.02), 2)


## A captioned pill per choice (Text size 100 / 115 / 130 %): the selected
## cap is gilded, the others engraved, each cap at least 88 device px tall.
class Seg extends Control:
	signal changed(value: int)
	var options: Array = [[100, "100%"], [115, "115%"], [130, "130%"]]
	var value := 100

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _index(x: float) -> int:
		return clampi(int(x / maxf(size.x / options.size(), 1.0)), 0, options.size() - 1)

	func _gui_input(event: InputEvent) -> void:
		var tap := (event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT) or (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed)
		if tap:
			var pick := _index(event.position.x)
			if int(options[pick][0]) != value:
				value = int(options[pick][0])
				changed.emit(value)
				AudioDirector.sfx("ui_toggle")
			accept_event()

	func _draw() -> void:
		var face := Rect2(Vector2(4, 4), size - Vector2(8, 8))
		UiKit.rr_shadow(self, face, 10.0, 6.0, 0.3)
		UiKit.rr_fill(self, face, 10.0, Color("120c08"), Color("241a10"))
		UiKit.rr_line(self, face, 10.0, Color(0.55, 0.4, 0.2), 3.0)
		var cap := face.size.x / options.size()
		for i in options.size():
			var on := int(options[i][0]) == value
			var cell := Rect2(face.position + Vector2(cap * i, 0), Vector2(cap, face.size.y))
			var r := cell.grow(-3.0)
			if on:
				UiKit.rr_fill(self, r, 7.0, Color("8a6420"), Color("3a2608"))
				UiKit.rr_line(self, r, 7.0, Color("e8c886"), 2.5)
			var font := UiKit.font_x
			var fpx := UiKit.text_px(26)
			var ink := Color("1a1206") if on else Color(0.76, 0.68, 0.55)
			var txt := str(options[i][1])
			var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fpx).x
			var tp := Vector2(cell.get_center().x - tw * 0.5, cell.get_center().y + fpx * 0.36)
			UiKit.draw_text(self, font, tp, txt, fpx, ink, Color(0.06, 0.04, 0.02) if not on else Color(0.28, 0.2, 0.06), 2)
