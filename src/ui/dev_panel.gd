class_name DevPanel
extends PanelContainer
## Hidden camera tuning panel (pause menu -> tap the info line five times).
## Sliders write straight to the live camera; "Copy values" puts a one-line
## summary on the clipboard so it can be pasted back as the new defaults.
## Nothing here is saved.

signal closed

# [camera var, label, min, max, step]
const PARAMS := [
	["pitch_deg", "Pitch", 30.0, 75.0, 1.0],
	["distance", "Distance", 12.0, 28.0, 0.25],
	["fov_w", "FOV", 30.0, 60.0, 1.0],
	["anchor", "Anchor", 0.4, 0.7, 0.01],
	["lookahead", "Lookahead", 0.0, 0.8, 0.05],
	["lead_max", "Lead max", 0.0, 5.0, 0.1],
	["follow_rate", "Follow", 2.0, 14.0, 0.5],
]

var _hunt: Hunt
var _labels := {}


func open(h: Hunt) -> void:
	_hunt = h
	anchor_left = 0.0
	anchor_right = 1.0
	anchor_top = 1.0
	anchor_bottom = 1.0
	offset_left = 12.0
	offset_right = -12.0
	offset_top = -468.0
	offset_bottom = -12.0
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	add_child(v)
	var head := Ui.label("Camera tuning (not saved)", "Heading")
	head.add_theme_font_size_override("font_size", 26)
	v.add_child(head)
	for p in PARAMS:
		v.add_child(_row(p))
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	var copy := Button.new()
	copy.text = "Copy values"
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.custom_minimum_size = Vector2(0, 64)
	copy.focus_mode = Control.FOCUS_NONE
	copy.pressed.connect(func():
		DisplayServer.clipboard_set(summary())
		copy.text = "Copied!")
	buttons.add_child(copy)
	var done := Button.new()
	done.text = "Done"
	done.theme_type_variation = "PrimaryButton"
	done.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	done.custom_minimum_size = Vector2(0, 64)
	done.focus_mode = Control.FOCUS_NONE
	done.pressed.connect(func():
		closed.emit()
		queue_free())
	buttons.add_child(done)
	v.add_child(buttons)


func summary() -> String:
	var c := _hunt.cam
	return "pitch=%d dist=%.1f fov=%d anchor=%.2f look=%.2f lead=%.1f rate=%.1f" % [c.pitch_deg, c.distance, c.fov_w, c.anchor, c.lookahead, c.lead_max, c.follow_rate]


func _row(p: Array) -> Control:
	var key: String = p[0]
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var name_l := Ui.label(str(p[1]), "Body")
	name_l.custom_minimum_size = Vector2(130, 0)
	row.add_child(name_l)
	var s := HSlider.new()
	s.min_value = p[2]
	s.max_value = p[3]
	s.step = p[4]
	s.value = float(_hunt.cam.get(key))
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.focus_mode = Control.FOCUS_NONE
	row.add_child(s)
	var val := Ui.label(_fmt(s.value, float(p[4])), "Value", HORIZONTAL_ALIGNMENT_RIGHT)
	val.add_theme_font_size_override("font_size", 22)
	val.custom_minimum_size = Vector2(80, 0)
	row.add_child(val)
	s.value_changed.connect(func(x: float):
		_hunt.cam.set(key, x)
		# The hunt is paused, so redraw the frame behind the menu by hand.
		_hunt.cam._apply(0.0)
		val.text = _fmt(x, float(p[4])))
	return row


static func _fmt(x: float, step: float) -> String:
	return ("%d" % int(x)) if step >= 1.0 else ("%.2f" % x)
