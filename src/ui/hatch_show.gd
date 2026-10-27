extends Control
## The hatching: an egg drops in and lands with a squash, then wobbles three
## times. Each wobble ends in a crack that leaks light, and the rarer the
## sidekick the longer the egg hangs, trembling, before it bursts. The burst
## throws shell, sparks and a white-out; the sidekick leaps out as a black
## silhouette and floods with colour, and its name slams in. A mutation gets a
## second beat: a prismatic surge and its own banner. Tap to skip ahead, tap
## again to carry on.
##
## `res` is what SKS.hatch returned: {id, kind, new, kills}. Optional:
## `mutation` (its name, e.g. "Frostbound") and `mutation_power` (a line on
## what it does) play the mutation reveal.

const FxUi := preload("res://src/ui/fx_ui.gd")
const SKDB := preload("res://src/data/sidekick_db.gd")
const WOBBLES := [7.0, 12.0, 18.0]
const EGG := 240.0

signal finished


## Loose pieces thrown about: shell shards (solid) or sparks (drawn long, added).
class Bits extends Control:
	var items: Array = []
	var gravity := 1500.0
	var streaks := false

	func throw(pos: Vector2, vel: Vector2, size: float, col: Color, life: float, spin := 0.0) -> void:
		items.append({"p": pos, "v": vel, "s": size, "c": col, "l": life, "age": 0.0, "r": randf() * TAU, "w": spin, "k": randi() % 3})

	func _process(dt: float) -> void:
		var i := 0
		while i < items.size():
			var it: Dictionary = items[i]
			it["age"] = float(it["age"]) + dt
			if float(it["age"]) >= float(it["l"]):
				items.remove_at(i)
				continue
			var v: Vector2 = it["v"]
			v.y += gravity * dt
			v *= exp(-0.6 * dt)
			it["v"] = v
			it["p"] = (it["p"] as Vector2) + v * dt
			it["r"] = float(it["r"]) + float(it["w"]) * dt
			i += 1
		queue_redraw()

	func _draw() -> void:
		for it in items:
			var u: float = float(it["age"]) / float(it["l"])
			var col: Color = it["c"]
			var p: Vector2 = it["p"]
			var s: float = float(it["s"]) * (1.0 - u * 0.5)
			col.a *= 1.0 - smoothstep(0.55, 1.0, u)
			if streaks:
				var v: Vector2 = it["v"]
				draw_line(p, p - v * 0.045, col, maxf(s * 0.45, 1.5))
				continue
			var a: float = it["r"]
			var pts := PackedVector2Array()
			match int(it["k"]):
				0:
					pts = PackedVector2Array([Vector2(0, -s), Vector2(s * 0.8, s * 0.6), Vector2(-s * 0.7, s * 0.5)])
				1:
					pts = PackedVector2Array([Vector2(-s * 0.9, -s * 0.3), Vector2(s * 0.2, -s), Vector2(s, s * 0.2), Vector2(-s * 0.2, s * 0.7)])
				_:
					pts = PackedVector2Array([Vector2(-s, 0), Vector2(0, -s * 0.5), Vector2(s, s * 0.1), Vector2(0.2 * s, s * 0.8)])
			for j in pts.size():
				pts[j] = p + pts[j].rotated(a)
			draw_colored_polygon(pts, col)
			draw_polyline(pts + PackedVector2Array([pts[0]]), Color(col.lightened(0.45), col.a), 2.0)


## Cracks across the egg's shell. `glow` draws the light leaking through them.
class Cracks extends Control:
	## Each crack: points in 0..1 of the egg's box, a branch off its middle.
	const PATHS := [
		[Vector2(0.52, 0.12), Vector2(0.46, 0.22), Vector2(0.55, 0.3), Vector2(0.47, 0.4), Vector2(0.56, 0.5), Vector2(0.5, 0.58)],
		[Vector2(0.8, 0.4), Vector2(0.7, 0.44), Vector2(0.66, 0.54), Vector2(0.56, 0.56), Vector2(0.5, 0.64), Vector2(0.38, 0.62)],
		[Vector2(0.2, 0.62), Vector2(0.3, 0.58), Vector2(0.36, 0.7), Vector2(0.46, 0.7), Vector2(0.52, 0.8), Vector2(0.62, 0.78), Vector2(0.7, 0.86)],
	]
	var glow := false
	var tint := Color.WHITE
	## 0..1 growth of each crack; the light follows in `lit`.
	var grow := [0.0, 0.0, 0.0]
	var lit := 0.0

	func _draw() -> void:
		for i in PATHS.size():
			var g: float = grow[i]
			if g <= 0.0:
				continue
			var pts: PackedVector2Array = _cut(PATHS[i], g)
			if pts.size() < 2:
				continue
			if glow:
				draw_polyline(pts, Color(tint, 0.35 * lit), 22.0 * size.x / EGG)
				draw_polyline(pts, Color(tint.lightened(0.5), 0.8 * lit), 9.0 * size.x / EGG)
				draw_polyline(pts, Color(1, 1, 1, lit), 4.0 * size.x / EGG)
			else:
				draw_polyline(pts, Color(0.12, 0.07, 0.05, 0.85), 8.0 * size.x / EGG)

	func _cut(path: Array, g: float) -> PackedVector2Array:
		var out := PackedVector2Array()
		var total := path.size() - 1
		var upto := g * total
		for j in path.size():
			if float(j) <= upto:
				out.append((path[j] as Vector2) * size)
			else:
				var prev: Vector2 = path[j - 1]
				var f := upto - float(j - 1)
				out.append(prev.lerp(path[j], f) * size)
				break
		return out


var _res := {}
var _egg: TextureRect
var _pet: TextureRect
var _flash: ColorRect
var _rays: TierReveal.Rays
var _glow: TextureRect
var _cracks: Cracks
var _crack_glow: Cracks
var _shards: Bits
var _sparks: Bits
var _caption: VBoxContainer
var _hint: Label
var _tween: Tween
var _shown := false
var _done := false
var _col := Color.WHITE
var _rar := 0
var _mid := Vector2.ZERO
var _shake := 0.0
var _ncrack := 0


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
	_mid = Vector2(vp.x * 0.5, vp.y * 0.42)
	# The light behind the egg: it swells with every crack.
	_glow = TextureRect.new()
	_glow.texture = FxUi._dot_texture()
	_glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_glow.size = Vector2(760, 760)
	_glow.position = _mid - _glow.size * 0.5
	_glow.pivot_offset = _glow.size * 0.5
	_glow.modulate = Color(_col.lightened(0.3), 0.0)
	_glow.scale = Vector2.ONE * 0.4
	_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = add
	add_child(_glow)
	_egg = Ui.icon_rect("egg-clutch", EGG, Color.WHITE)
	_egg.self_modulate = egg_col
	_egg.size = Vector2(EGG, EGG)
	_egg.position = _mid - _egg.size * 0.5 + Vector2(0, -420)
	_egg.pivot_offset = Vector2(EGG * 0.5, EGG * 0.92)
	_egg.modulate.a = 0.0
	add_child(_egg)
	_cracks = Cracks.new()
	_crack_glow = Cracks.new()
	_crack_glow.glow = true
	_crack_glow.tint = _col
	_crack_glow.material = add
	for c in [_cracks, _crack_glow]:
		c.size = _egg.size
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_egg.add_child(c)
	_pet = Ui.icon_rect(str(pd["icon"]), 260.0, Color.WHITE)
	_pet.self_modulate = Color.BLACK
	_pet.size = Vector2(260, 260)
	_pet.position = _mid - _pet.size * 0.5
	_pet.pivot_offset = Vector2(130, 240)
	_pet.scale = Vector2.ZERO
	add_child(_pet)
	_shards = Bits.new()
	_sparks = Bits.new()
	_sparks.streaks = true
	_sparks.gravity = 500.0
	_sparks.material = add
	for b in [_shards, _sparks]:
		b.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(b)
	_caption = VBoxContainer.new()
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caption.add_theme_constant_override("separation", 2)
	_caption.size = Vector2(vp.x, 260)
	_caption.position = Vector2(0, _mid.y + 150)
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
	_sequence(scrim)


func _process(dt: float) -> void:
	if _shake <= 0.01:
		position = Vector2.ZERO
		return
	position = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake
	_shake = move_toward(_shake, 0.0, dt * 60.0)


## The build-up: drop, squash, three wobbles with a crack each, the hang.
func _sequence(scrim: ColorRect) -> void:
	_tween = create_tween()
	_tween.tween_property(scrim, "color:a", 0.95, 0.3)
	_tween.parallel().tween_property(_egg, "modulate:a", 1.0, 0.1)
	_tween.parallel().tween_property(_egg, "position:y", _mid.y - EGG * 0.5, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.parallel().tween_property(_rays, "reach", 520.0, 0.9).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(_rays, "alpha", 0.1, 0.9)
	_tween.parallel().tween_property(_glow, "modulate:a", 0.25, 0.8)
	_tween.tween_callback(_land)
	_tween.tween_property(_egg, "scale", Vector2(1.22, 0.8), 0.07).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_egg, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for i in WOBBLES.size():
		var amp: float = WOBBLES[i]
		# It gathers itself (crouch, lean back), then rattles.
		_tween.tween_property(_egg, "scale", Vector2(1.05 + 0.02 * i, 0.93 - 0.02 * i), 0.2 + 0.02 * (2 - i)).set_trans(Tween.TRANS_SINE)
		_tween.parallel().tween_property(_egg, "rotation_degrees", -amp * 0.5, 0.2 + 0.02 * (2 - i)).set_trans(Tween.TRANS_SINE)
		for s in [1.0, -1.0, 0.8, -0.8, 0.5, 0.0]:
			_tween.tween_property(_egg, "rotation_degrees", amp * s, 0.07 + 0.01 * (2 - i)).set_trans(Tween.TRANS_SINE)
			if s == 1.0:
				_tween.parallel().tween_property(_egg, "scale", Vector2(0.94, 1.06), 0.07)
		_tween.tween_property(_egg, "scale", Vector2.ONE, 0.08)
		_tween.tween_callback(_crack.bind(i))
		_tween.tween_interval(0.12)
	# The rarer it is, the longer it hangs, trembling, before it goes.
	var hang := 0.2 + 0.2 * _rar
	_tween.tween_callback(_charge.bind(hang))
	_tween.tween_interval(hang)
	_tween.tween_callback(_burst)


func _land() -> void:
	Sfx.play("chest_land", -4.0)
	Ui.buzz(40, 0.5)
	_shake = 6.0
	for i in 12:
		var a := randf_range(PI * 0.05, PI * 0.95)
		_sparks.throw(_mid + Vector2(randf_range(-60, 60), EGG * 0.42), Vector2(cos(a) * (i % 2 * 2 - 1), -sin(a)) * randf_range(120, 330), 3.5, Color(1, 0.9, 0.7, 0.8), 0.45)


## One wobble ends: a rattle, a crack that leaks light, a pulse of the glow.
func _crack(i: int) -> void:
	_ncrack = i + 1
	Sfx.play("chest_rattle", -4.0, 1.0 + i * 0.12)
	Ui.buzz(30 + i * 30, 0.4)
	_shake = 4.0 + 3.0 * i
	var t := create_tween().set_parallel(true)
	t.tween_method(func(v: float): _set_grow(i, v), 0.0, 1.0, 0.16)
	t.tween_property(_crack_glow, "lit", 0.55 + 0.2 * i, 0.12)
	t.tween_property(_glow, "modulate:a", 0.3 + 0.2 * i, 0.2)
	t.tween_property(_glow, "scale", Vector2.ONE * (0.5 + 0.25 * i), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_flash.color = Color(_col.lightened(0.7), 0.0)
	t.tween_property(_flash, "color:a", 0.07 + 0.05 * i, 0.05)
	t.chain().tween_property(_flash, "color:a", 0.0, 0.2)
	t.tween_property(_rays, "alpha", 0.1 + 0.05 * i, 0.2)
	# A few flecks of shell and light jump off the crack.
	for j in 5 + 2 * i:
		var a := randf_range(-PI, 0.0)
		_shards.throw(_mid + Vector2(randf_range(-30, 30), randf_range(-50, 20)), Vector2(cos(a), sin(a)) * randf_range(120, 300), randf_range(4, 8), _egg.self_modulate.darkened(0.1), 0.7, randf_range(-8, 8))
	for j in 4:
		var a2 := randf() * TAU
		_sparks.throw(_mid + Vector2(randf_range(-30, 30), randf_range(-40, 30)), Vector2.from_angle(a2) * randf_range(160, 380), 3.0, Color(_col.lightened(0.6), 0.9), 0.5)


func _set_grow(i: int, v: float) -> void:
	_cracks.grow[i] = v
	_crack_glow.grow[i] = v
	_cracks.queue_redraw()
	_crack_glow.queue_redraw()


## The hang before the burst: the egg lifts, shakes and glows hotter.
func _charge(hang: float) -> void:
	Sfx.play("charge", -8.0, 0.9 + 0.1 * _rar)
	var t := create_tween().set_parallel(true)
	t.tween_property(_egg, "position:y", _egg.position.y - 22.0, hang).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(_egg, "scale", Vector2.ONE * 1.1, hang)
	t.tween_property(_crack_glow, "lit", 1.0, hang)
	t.tween_property(_glow, "modulate:a", 0.85, hang)
	t.tween_property(_glow, "scale", Vector2.ONE * 1.1, hang)
	t.tween_property(_rays, "alpha", 0.28, hang)
	t.tween_method(func(v: float): _shake = maxf(_shake, 2.0 + 4.0 * v), 0.0, 1.0, hang)
	t.tween_method(func(v: float): _egg.rotation_degrees = sin(v * hang * 70.0) * (3.0 + 6.0 * v), 0.0, 1.0, hang)


func _burst() -> void:
	if _egg.visible == false:
		return
	Sfx.play("shield_break", -2.0)
	Sfx.play("gem", -3.0)
	Ui.buzz(120, 0.9)
	_shake = 12.0 + 3.0 * _rar
	var from := _egg.position + _egg.size * 0.5
	_egg.visible = false
	_flash.color = Color(1, 1, 1, 1.0)
	var t := create_tween().set_parallel(true)
	t.tween_property(_flash, "color:a", 0.0, 0.5).set_ease(Tween.EASE_OUT)
	t.tween_property(_rays, "alpha", 0.22 + 0.06 * _rar, 0.3)
	t.tween_property(_rays, "reach", 700.0 + 60.0 * _rar, 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	t.tween_property(_glow, "scale", Vector2.ONE * 1.6, 0.5).set_ease(Tween.EASE_OUT)
	t.tween_property(_glow, "modulate:a", 0.4, 0.8).set_delay(0.1)
	# Shell flies in every direction, spinning; sparks streak out after it.
	var shell := egg_shell_color()
	for i in 16 + 3 * _rar:
		var a := TAU * i / float(16 + 3 * _rar) + randf_range(-0.2, 0.2)
		_shards.throw(from + Vector2.from_angle(a) * randf_range(20, 70), Vector2.from_angle(a) * randf_range(380, 900) + Vector2(0, -300), randf_range(9, 20), shell.lerp(Color(1, 1, 1), randf() * 0.3), randf_range(0.9, 1.5), randf_range(-12, 12))
	for i in 36 + 18 * _rar:
		var a2 := randf() * TAU
		_sparks.throw(from, Vector2.from_angle(a2) * randf_range(300, 1100), randf_range(3.0, 6.0), Color(_col.lightened(randf() * 0.6), 1.0), randf_range(0.6, 1.2))
	_reveal()


func egg_shell_color() -> Color:
	return _egg.self_modulate


## The hatchling: a black silhouette that leaps out, floods with colour,
## lands with a squash. Its name slams in, then the rarity stars light.
func _reveal() -> void:
	if _shown:
		return
	_shown = true
	var pd: Dictionary = SKDB.def(str(_res["id"]))
	var gc: Color = SKDB.GRADE_COLORS[_rar]
	var mut := str(_res.get("mutation", ""))
	var name_l := Ui.label(str(pd["name"]), "Title", HORIZONTAL_ALIGNMENT_CENTER)
	name_l.add_theme_font_size_override("font_size", 56)
	name_l.add_theme_color_override("font_color", _col.lightened(0.4))
	name_l.add_theme_constant_override("outline_size", 12)
	name_l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	name_l.pivot_offset = Vector2(get_viewport_rect().size.x * 0.5, 40)
	name_l.modulate.a = 0.0
	_caption.add_child(name_l)
	var rar_l := Ui.label(SKDB.GRADES[_rar].to_upper() + ("  ·  NEW!" if bool(_res["new"]) else ""), "Heading", HORIZONTAL_ALIGNMENT_CENTER)
	rar_l.add_theme_color_override("font_color", gc)
	rar_l.modulate.a = 0.0
	_caption.add_child(rar_l)
	var sub := "%s · %s" % [pd["element"], pd["ability"]["name"]] if bool(_res["new"]) else "Already yours: +%d bond kills" % int(_res["kills"])
	var sub_l := Ui.label(sub, "Body", HORIZONTAL_ALIGNMENT_CENTER)
	sub_l.modulate.a = 0.0
	_caption.add_child(sub_l)
	var stars := HBoxContainer.new()
	stars.alignment = BoxContainer.ALIGNMENT_CENTER
	stars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stars.add_theme_constant_override("separation", 6)
	_caption.add_child(stars)
	_caption.move_child(stars, 1)
	for i in _rar + 1:
		var st := Ui.icon_rect("round-star", 34.0, gc)
		st.pivot_offset = Vector2(17, 17)
		st.scale = Vector2.ZERO
		stars.add_child(st)
	Sfx.play("rare_chime", 0.0, 1.0)
	Sfx.play("sparkle", -2.0)
	if _rar >= 3:
		Sfx.play("levelup", -4.0)
	if _rar >= 3:
		_confetti(gc)
	_pet.position = _mid - _pet.size * 0.5
	_pet.scale = Vector2.ONE * 0.3
	_tween = create_tween()
	# Leap out: up and over with a stretch, a light flood, then the landing.
	_tween.tween_property(_pet, "scale", Vector2(0.9, 1.35), 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(_pet, "position:y", _mid.y - 130.0 - 130.0, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_pet, "position:y", _mid.y - 130.0, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.parallel().tween_property(_pet, "scale", Vector2(1.0, 1.0), 0.2)
	_tween.parallel().tween_property(_pet, "self_modulate", _col, 0.36).set_trans(Tween.TRANS_SINE)
	_tween.tween_callback(_thud)
	_tween.tween_property(_pet, "scale", Vector2(1.28, 0.82), 0.07).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_pet, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(name_l, "modulate:a", 1.0, 0.1)
	_tween.parallel().tween_callback(func(): _slam(name_l)).set_delay(0.0)
	_tween.tween_property(rar_l, "modulate:a", 1.0, 0.2)
	_tween.parallel().tween_property(sub_l, "modulate:a", 1.0, 0.3)
	for i in stars.get_child_count():
		var st: Control = stars.get_child(i)
		_tween.parallel().tween_property(st, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.09 * i)
		_tween.parallel().tween_callback(Sfx.play.bind("ui_tap", -10.0, 1.0 + 0.12 * i)).set_delay(0.09 * i)
	if mut != "":
		_tween.tween_interval(0.35)
		_tween.tween_callback(_mutate.bind(mut))
	else:
		_tween.tween_callback(_idle)


## The landing: dust, a thump, a small shake.
func _thud() -> void:
	Sfx.play("chest_land", -6.0, 1.2)
	_shake = 7.0
	for i in 14:
		var dir := 1.0 if i % 2 == 0 else -1.0
		_sparks.throw(_mid + Vector2(0, 112), Vector2(dir * randf_range(120, 420), -randf_range(10, 140)), 3.5, Color(1, 0.95, 0.85, 0.7), 0.45)


## The name slams in from big to size.
func _slam(l: Label) -> void:
	l.scale = Vector2.ONE * 2.1
	var t := create_tween().set_parallel(true)
	t.tween_property(l, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_callback(func(): _shake = maxf(_shake, 5.0)).set_delay(0.12)


## Falling bits of colour for the rare ones.
func _confetti(gc: Color) -> void:
	var p := CPUParticles2D.new()
	p.position = Vector2(get_viewport_rect().size.x * 0.5, -20)
	p.texture = FxUi._dot_texture()
	p.amount = 60
	p.lifetime = 2.4
	p.one_shot = true
	p.explosiveness = 0.35
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(get_viewport_rect().size.x * 0.5, 4)
	p.direction = Vector2(0, 1)
	p.spread = 25.0
	p.gravity = Vector2(0, 260)
	p.initial_velocity_min = 140.0
	p.initial_velocity_max = 380.0
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.2
	p.color = gc.lightened(0.25)
	p.hue_variation_max = 0.12
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	p.material = mat
	add_child(p)
	p.emitting = true


## The reveal is over: it bobs, and the hint asks for a tap.
func _idle() -> void:
	FxUi.bob(_pet, 3.0, 2.0)
	FxUi.pulse(_hint, 1.06, 1.2)
	var t := create_tween()
	t.tween_property(_hint, "modulate:a", 0.8, 0.4).set_delay(0.3)


## A mutation: the sidekick convulses with prismatic light, a banner slams in,
## and it settles with a shimmer that never quite stops.
func _mutate(mut: String) -> void:
	Sfx.play("unlock_start", -2.0)
	Sfx.play("charge", -6.0, 1.3)
	Ui.buzz(150, 1.0)
	var vp := get_viewport_rect().size
	var banner := Ui.label("MUTATION!", "Title", HORIZONTAL_ALIGNMENT_CENTER)
	banner.add_theme_font_size_override("font_size", 78)
	banner.add_theme_constant_override("outline_size", 16)
	banner.add_theme_color_override("font_outline_color", Color(0.05, 0.0, 0.1, 0.9))
	banner.size = Vector2(vp.x, 100)
	banner.position = Vector2(0, _mid.y - 330)
	banner.pivot_offset = Vector2(vp.x * 0.5, 50)
	banner.scale = Vector2.ONE * 2.6
	banner.modulate.a = 0.0
	add_child(banner)
	var power := str(_res.get("mutation_power", ""))
	var m_l := Ui.label(mut, "Heading", HORIZONTAL_ALIGNMENT_CENTER)
	m_l.add_theme_font_size_override("font_size", 38)
	m_l.add_theme_constant_override("outline_size", 8)
	m_l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	m_l.modulate.a = 0.0
	_caption.add_child(m_l)
	var pw_l: Label = null
	if power != "":
		pw_l = Ui.label(power, "Body", HORIZONTAL_ALIGNMENT_CENTER)
		pw_l.modulate.a = 0.0
		_caption.add_child(pw_l)
	var t := create_tween()
	# Build: the body judders, colours churn, light gathers.
	t.tween_method(func(v: float):
		_pet.self_modulate = Color.from_hsv(fmod(v * 3.0, 1.0), 0.55 * v, 1.0).lerp(Color.WHITE, 0.3 * v)
		_pet.rotation_degrees = sin(v * 90.0) * 5.0 * v
		_shake = maxf(_shake, 2.0 + 5.0 * v), 0.0, 1.0, 0.7)
	t.parallel().tween_property(_rays, "alpha", 0.45, 0.7)
	t.parallel().tween_property(_glow, "modulate", Color(1, 1, 1, 1.0), 0.7)
	t.parallel().tween_property(_pet, "scale", Vector2.ONE * 1.18, 0.7).set_trans(Tween.TRANS_QUAD)
	t.tween_callback(func():
		_flash.color = Color(1, 1, 1, 1)
		_shake = 16.0
		Sfx.play("levelup", -1.0, 1.15)
		Sfx.play("shield_break", -4.0, 1.4)
		Sfx.play("rare_chime", 0.0, 1.5)
		Ui.buzz(160, 1.0)
		_pet.rotation_degrees = 0.0
		_rainbow_burst())
	t.tween_property(_flash, "color:a", 0.0, 0.45)
	t.parallel().tween_property(_pet, "scale", Vector2(1.3, 0.82), 0.06)
	t.tween_property(_pet, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(banner, "modulate:a", 1.0, 0.08)
	t.parallel().tween_property(banner, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(_glow, "modulate", Color(_col.lightened(0.3), 0.45), 0.6)
	t.parallel().tween_property(_rays, "alpha", 0.3, 0.6)
	t.tween_property(m_l, "modulate:a", 1.0, 0.25)
	if pw_l:
		t.tween_property(pw_l, "modulate:a", 1.0, 0.3)
	t.tween_callback(func():
		# The shimmer: banner and name drift round the colour wheel, the sidekick glints.
		var shimmer := create_tween().set_loops()
		shimmer.tween_method(func(v: float):
			var rb := Color.from_hsv(v, 0.55, 1.0)
			banner.add_theme_color_override("font_color", rb)
			m_l.add_theme_color_override("font_color", Color.from_hsv(fmod(v + 0.5, 1.0), 0.5, 1.0))
			_pet.self_modulate = _col.lerp(Color.from_hsv(v, 0.5, 1.0), 0.28), 0.0, 1.0, 2.4)
		_idle())


## Sparks in every colour of the wheel, thrown up from the sidekick.
func _rainbow_burst() -> void:
	var from := _pet.position + _pet.size * 0.5
	for i in 90:
		var a := randf() * TAU
		_sparks.throw(from, Vector2.from_angle(a) * randf_range(280, 1000), randf_range(3.0, 6.0), Color.from_hsv(randf(), 0.6, 1.0), randf_range(0.7, 1.3))
	_confetti(Color.from_hsv(randf(), 0.5, 1.0))


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
