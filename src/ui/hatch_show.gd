extends Control
## The hatching: an egg wobbles harder three times, cracks, bursts in light,
## and the sidekick pops out with its rarity. Tap to skip ahead, tap again to
## carry on. `res` is what SKS.hatch returned: {id, kind, new, kills}.

const FxUi := preload("res://src/ui/fx_ui.gd")
const SKDB := preload("res://src/data/sidekick_db.gd")
const WOBBLES := [7.0, 12.0, 18.0]

signal finished

var _res := {}
var _egg: TextureRect
var _pet: TextureRect
var _flash: ColorRect
var _rays: TierReveal.Rays
var _caption: VBoxContainer
var _hint: Label
var _tween: Tween
var _shown := false
var _done := false
var _col := Color.WHITE
var _rar := 0


## Plays over `host` (a full-screen layer). `on_done` runs when the player moves on.
func play(host: Control, res: Dictionary, on_done := Callable()) -> void:
	_res = res
	var pd: Dictionary = SKDB.def(str(res["id"]))
	_col = Color(pd["color"])
	_rar = SKDB.rarity(str(res["id"]))
	var egg_col: Color = SKDB.EGGS[str(res["kind"])]["color"] if SKDB.EGGS.has(str(res["kind"])) else Color(0.92, 0.82, 0.62)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	if on_done.is_valid():
		finished.connect(on_done)
	host.add_child(self)
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
	FxUi.add_motes(self, Color(egg_col, 0.6), 18, 40.0)
	var vp := get_viewport_rect().size
	var mid := Vector2(vp.x * 0.5, vp.y * 0.42)
	_egg = Ui.icon_rect("egg-clutch", 240.0, egg_col)
	_egg.size = Vector2(240, 240)
	_egg.position = mid - _egg.size * 0.5
	_egg.pivot_offset = _egg.size * 0.5
	_egg.scale = Vector2.ONE * 0.4
	_egg.modulate.a = 0.0
	add_child(_egg)
	_pet = Ui.icon_rect(str(pd["icon"]), 260.0, _col)
	_pet.size = Vector2(260, 260)
	_pet.position = mid - _pet.size * 0.5
	_pet.pivot_offset = _pet.size * 0.5
	_pet.scale = Vector2.ZERO
	add_child(_pet)
	_caption = VBoxContainer.new()
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caption.add_theme_constant_override("separation", 2)
	_caption.size = Vector2(vp.x, 200)
	_caption.position = Vector2(0, mid.y + 150)
	_caption.modulate.a = 0.0
	add_child(_caption)
	_hint = Ui.label("TAP TO CONTINUE", "Caption", HORIZONTAL_ALIGNMENT_CENTER)
	_hint.size = Vector2(vp.x, 40)
	_hint.position = Vector2(0, vp.y - 150)
	_hint.modulate.a = 0.0
	add_child(_hint)
	_flash = ColorRect.new()
	_flash.color = Color(1, 1, 1, 0)
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)
	_tween = create_tween()
	_tween.tween_property(scrim, "color:a", 0.9, 0.3)
	_tween.parallel().tween_property(_egg, "modulate:a", 1.0, 0.2)
	_tween.parallel().tween_property(_egg, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(_rays, "reach", 520.0, 0.9).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(_rays, "alpha", 0.12, 0.9)
	for i in WOBBLES.size():
		var amp: float = WOBBLES[i]
		_tween.tween_interval(0.25)
		for s in [1.0, -1.0, 0.7, -0.7, 0.0]:
			_tween.tween_property(_egg, "rotation_degrees", amp * s, 0.07 + 0.01 * (2 - i)).set_trans(Tween.TRANS_SINE)
		_tween.tween_callback(_crack.bind(i))
	_tween.tween_interval(0.25)
	_tween.tween_callback(_burst)


## One wobble ends: a rattle, and a flash of light along the new crack.
func _crack(i: int) -> void:
	Sfx.play("chest_rattle", -4.0, 1.0 + i * 0.12)
	Ui.buzz(30 + i * 30, 0.4)
	var t := create_tween()
	t.tween_property(_flash, "color:a", 0.18 + 0.12 * i, 0.05)
	t.tween_property(_flash, "color:a", 0.0, 0.2)
	_egg.modulate = _egg.modulate.lerp(Color(1.6, 1.5, 1.3), 0.25)


func _burst() -> void:
	Sfx.play("shield_break", -2.0)
	Sfx.play("gem", -3.0)
	Ui.buzz(120, 0.9)
	_egg.visible = false
	_flash.color = Color(1, 1, 1, 0.95)
	var t := create_tween().set_parallel(true)
	t.tween_property(_flash, "color:a", 0.0, 0.45).set_ease(Tween.EASE_OUT)
	t.tween_property(_rays, "alpha", 0.35 + 0.1 * _rar, 0.3)
	t.tween_property(_rays, "reach", 640.0 + 60.0 * _rar, 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_sparks()
	_reveal()


## Shards of light thrown out of the egg, more of them the rarer the sidekick.
func _sparks() -> void:
	var p := CPUParticles2D.new()
	p.position = _egg.position + _egg.size * 0.5
	p.texture = FxUi._dot_texture()
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 40 + 20 * _rar
	p.lifetime = 1.1
	p.direction = Vector2(0, -1)
	p.spread = 180.0
	p.gravity = Vector2(0, 420)
	p.initial_velocity_min = 260.0
	p.initial_velocity_max = 620.0
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.4
	p.color = _col.lightened(0.35)
	var ramp := Gradient.new()
	ramp.set_color(0, Color.WHITE)
	ramp.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = ramp
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	p.material = mat
	add_child(p)
	p.emitting = true


func _reveal() -> void:
	if _shown:
		return
	_shown = true
	var pd: Dictionary = SKDB.def(str(_res["id"]))
	var gc: Color = SKDB.GRADE_COLORS[_rar]
	var name_l := Ui.label(str(pd["name"]), "Title", HORIZONTAL_ALIGNMENT_CENTER)
	name_l.add_theme_font_size_override("font_size", 56)
	name_l.add_theme_color_override("font_color", _col.lightened(0.4))
	name_l.add_theme_constant_override("outline_size", 12)
	name_l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_caption.add_child(name_l)
	var rar_l := Ui.label(SKDB.GRADES[_rar].to_upper() + ("  ·  NEW!" if bool(_res["new"]) else ""), "Heading", HORIZONTAL_ALIGNMENT_CENTER)
	rar_l.add_theme_color_override("font_color", gc)
	_caption.add_child(rar_l)
	var sub := "%s · %s" % [pd["element"], pd["ability"]["name"]] if bool(_res["new"]) else "Already yours: +%d bond kills" % int(_res["kills"])
	_caption.add_child(Ui.label(sub, "Body", HORIZONTAL_ALIGNMENT_CENTER))
	Sfx.play("rare_chime", 0.0, 1.0 + 0.0 * _rar)
	Sfx.play("sparkle", -2.0)
	if _rar >= 3:
		Sfx.play("levelup", -4.0)
	_tween = create_tween()
	_tween.tween_property(_pet, "scale", Vector2.ONE * 1.2, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_pet, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_SINE)
	_tween.parallel().tween_property(_caption, "modulate:a", 1.0, 0.3)
	_tween.tween_callback(func():
		FxUi.bob(_pet, 3.0, 2.0)
		FxUi.pulse(_hint, 1.06, 1.2))
	_tween.tween_property(_hint, "modulate:a", 0.8, 0.4).set_delay(0.5)


func _gui_input(ev: InputEvent) -> void:
	if not (ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT) and not (ev is InputEventScreenTouch and ev.pressed):
		return
	accept_event()
	if not _shown:
		# Skip the shaking: straight to the burst.
		if _tween:
			_tween.kill()
		_burst()
		return
	if _hint.modulate.a < 0.4 or _done:
		return
	_done = true
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.25)
	t.tween_callback(func():
		finished.emit()
		queue_free())
