extends Control
## A sidekick grows up or evolves: light is drawn in from all round, the body
## whitens and shakes harder, a white-out, and the larger form stands where it
## was, colour flooding back, its new title slamming in. Plays over the results
## and goes by itself after a few seconds; a tap on the title closes it sooner.
## `res`: {id, stage_from, stage_to}. Preloaded by path (no class_name).

const FxUi := preload("res://src/ui/fx_ui.gd")
const SKDB := preload("res://src/data/sidekick_db.gd")
const HATCH := preload("res://src/ui/hatch_show.gd")

signal finished

var _pet: TextureRect
var _glow: TextureRect
var _flash: ColorRect
var _rays: TierReveal.Rays
var _sparks: HATCH.Bits
var _title: Label
var _sub: Label
var _col := Color.WHITE
var _shake := 0.0
var _mid := Vector2.ZERO
var _to := 1
var _open := false
var _done := false


func play(host: Control, res: Dictionary, on_done := Callable()) -> void:
	var id := str(res["id"])
	var pd: Dictionary = SKDB.def(id)
	_col = Color(pd["color"])
	_to = int(res.get("stage_to", 1))
	var from := int(res.get("stage_from", maxi(_to - 1, 0)))
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	if on_done.is_valid():
		finished.connect(on_done)
	host.add_child(self)
	var vp := get_viewport_rect().size
	_mid = Vector2(vp.x * 0.5, vp.y * 0.4)
	var scrim := ColorRect.new()
	scrim.color = Color(0.02, 0.015, 0.04, 0.0)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scrim)
	_rays = TierReveal.Rays.new()
	_rays.color = _col
	_rays.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rays.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rays)
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow = TextureRect.new()
	_glow.texture = FxUi._dot_texture()
	_glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_glow.size = Vector2(720, 720)
	_glow.position = _mid - _glow.size * 0.5
	_glow.pivot_offset = _glow.size * 0.5
	_glow.modulate = Color(_col.lightened(0.4), 0.0)
	_glow.scale = Vector2.ONE * 0.3
	_glow.material = add
	_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_glow)
	var size_from := 190.0 + 40.0 * from
	var size_to := 190.0 + 40.0 * _to
	_pet = Ui.icon_rect(str(pd["icon"]), size_to, Color.WHITE)
	_pet.self_modulate = _col
	_pet.size = Vector2(size_to, size_to)
	_pet.position = _mid - _pet.size * 0.5
	_pet.pivot_offset = Vector2(size_to * 0.5, size_to * 0.9)
	_pet.scale = Vector2.ONE * (size_from / size_to) * 0.4
	_pet.modulate.a = 0.0
	add_child(_pet)
	_sparks = HATCH.Bits.new()
	_sparks.streaks = true
	_sparks.gravity = 0.0
	_sparks.material = add
	_sparks.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_sparks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_sparks)
	var evolved := _to >= 2
	_title = Ui.label("EVOLVED!" if evolved else "GROWN UP!", "Title", HORIZONTAL_ALIGNMENT_CENTER)
	_title.add_theme_font_size_override("font_size", 72)
	_title.add_theme_color_override("font_color", _col.lightened(0.45))
	_title.add_theme_constant_override("outline_size", 14)
	_title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.88))
	_title.size = Vector2(vp.x, 90)
	_title.position = Vector2(0, _mid.y + size_to * 0.5 + 40.0)
	_title.pivot_offset = Vector2(vp.x * 0.5, 45)
	_title.modulate.a = 0.0
	add_child(_title)
	_sub = Ui.label("%s  ·  %s" % [SKDB.stage_name(id, _to), SKDB.STAGE_LABELS[_to]] if SKDB.stage_name(id, _to) != str(pd["name"]) else SKDB.STAGE_LABELS[_to], "Heading", HORIZONTAL_ALIGNMENT_CENTER)
	_sub.size = Vector2(vp.x, 50)
	_sub.position = Vector2(0, _title.position.y + 84.0)
	_sub.modulate.a = 0.0
	_sub.add_theme_color_override("font_color", _col.lightened(0.2))
	add_child(_sub)
	_flash = ColorRect.new()
	_flash.color = Color(1, 1, 1, 0)
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)
	_sequence(scrim, size_from / size_to)


func _process(dt: float) -> void:
	if _shake <= 0.01:
		position = Vector2.ZERO
		return
	position = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * minf(_shake, 10.0) * Game.shake_amp()
	_shake = move_toward(_shake, 0.0, dt * 50.0)


func _sequence(scrim: ColorRect, from_k: float) -> void:
	Sfx.play("charge", -6.0, 0.9)
	var t := create_tween()
	t.tween_property(scrim, "color:a", 0.88, 0.3)
	t.parallel().tween_property(_pet, "modulate:a", 1.0, 0.2)
	t.parallel().tween_property(_pet, "scale", Vector2.ONE * from_k, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(_rays, "reach", 600.0, 0.8).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(_rays, "alpha", 0.14, 0.8)
	# Build-up: light streams in, the body whitens and trembles, the glow swells.
	var build := 1.3
	t.tween_method(func(v: float): _gather(v, build), 0.0, 1.0, build)
	t.parallel().tween_property(_glow, "modulate:a", 0.9, build)
	t.parallel().tween_property(_glow, "scale", Vector2.ONE * 1.0, build)
	t.parallel().tween_property(_rays, "alpha", 0.3, build)
	t.parallel().tween_property(_pet, "self_modulate", Color(2.0, 2.0, 2.0), build).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(_pet, "scale", Vector2.ONE * from_k * 0.88, build).set_trans(Tween.TRANS_QUAD)
	t.tween_callback(_whiteout)
	# The new form: bigger than it was, flooding back to its colours.
	t.tween_property(_flash, "color:a", 0.0, 0.5).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(_pet, "scale", Vector2(1.18, 1.18), 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(_pet, "self_modulate", _col, 0.7).set_trans(Tween.TRANS_SINE)
	t.tween_property(_pet, "scale", Vector2(1.0, 1.0), 0.45).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	t.parallel().tween_callback(_banner)
	t.tween_interval(2.2)
	t.tween_callback(_close)


## Light motes spawn on a wide circle and fly in, quicker as it goes.
func _gather(v: float, _total: float) -> void:
	_shake = maxf(_shake, 1.0 + 6.0 * v * v)
	_pet.rotation_degrees = sin(v * v * 160.0) * 4.0 * v
	if randf() > 0.25 + 0.7 * v:
		return
	for i in 2:
		var a := randf() * TAU
		var r := randf_range(300.0, 520.0)
		var life := randf_range(0.45, 0.8)
		var from := _mid + Vector2.from_angle(a) * r
		_sparks.throw(from, (_mid - from) / life * 1.3, randf_range(3.0, 5.5), Color(_col.lightened(randf() * 0.6), 0.95), life)


func _whiteout() -> void:
	Sfx.play("levelup", -2.0)
	Sfx.play("shield_break", -5.0, 1.2)
	Sfx.play("rare_chime", -1.0)
	Ui.buzz(140, 0.9)
	_shake = 14.0
	_pet.rotation_degrees = 0.0
	_flash.color = Color(1, 1, 1, 1)
	_glow.scale = Vector2.ONE * 1.5
	for i in 70 + 30 * _to:
		var a := randf() * TAU
		_sparks.throw(_mid, Vector2.from_angle(a) * randf_range(300.0, 1100.0), randf_range(3.0, 6.0), Color(_col.lightened(randf() * 0.6), 1.0), randf_range(0.6, 1.2))


## Its new title slams in from big to size.
func _banner() -> void:
	_open = true
	_title.scale = Vector2.ONE * 2.4
	var t := create_tween().set_parallel(true)
	t.tween_property(_title, "modulate:a", 1.0, 0.08)
	t.tween_property(_title, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_callback(func(): _shake = maxf(_shake, 6.0)).set_delay(0.14)
	t.tween_property(_sub, "modulate:a", 1.0, 0.3).set_delay(0.25)
	t.tween_property(_rays, "alpha", 0.2, 0.6)
	t.tween_property(_glow, "modulate:a", 0.4, 0.8)
	FxUi.bob(_pet, 2.5, 2.0)


func _close() -> void:
	if _done:
		return
	_done = true
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.3)
	t.tween_callback(func():
		finished.emit()
		queue_free())


func _gui_input(ev: InputEvent) -> void:
	if not (ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT) and not (ev is InputEventScreenTouch and ev.pressed):
		return
	accept_event()
	if _open:
		_close()
