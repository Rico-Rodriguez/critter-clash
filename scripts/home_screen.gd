extends ScreenBase

## Home: the featured hero on a lit 3D meadow plinth across the top half,
## a big HUNT button, chest slots, and tidy icon tiles for the side screens.


func build() -> void:
	show_nav = true
	nav_tab = "home"
	var pad := insets()
	var hero_id := SaveGame.featured_id()
	# The 3D stage bleeds to the screen edges and under the status bar.
	var stage := Showcase.new()
	stage.hero_id = hero_id
	stage.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	stage.anchor_bottom = 0.5
	stage.offset_bottom = 30
	add_child(stage)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", int(pad["l"]))
	margin.add_theme_constant_override("margin_right", int(pad["r"]))
	margin.add_theme_constant_override("margin_top", int(pad["t"]))
	margin.add_theme_constant_override("margin_bottom", int(pad["b"]) + 140)
	add_child(margin)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 16)
	margin.add_child(box)
	box.add_child(header())
	var plate := LogoPlate.new()
	var logo := Wordmark.new()
	logo.text = "CRITTER CLASH"
	plate.add_child(logo)
	logo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	plate.custom_minimum_size = Vector2(0, 92)
	box.add_child(plate)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(spacer)
	box.add_child(_nameplate(hero_id))
	var play := ForgedButton.new()
	play.text = "HUNT"
	play.custom_minimum_size = Vector2(600, 136)
	play.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	# HUNT replays the last biome with the featured hero; the map (World
	# tab) is where a different biome is picked.
	play.pressed.connect(func() -> void:
		var last := str(SaveGame.data.get("last_biome", ""))
		if last != "" and SaveGame.biome_open(last):
			go("run", {"biome": last, "hero": hero_id})
		else:
			go("world")
	)
	box.add_child(play)
	box.add_child(_chests())
	box.add_child(_tiles())


func _nameplate(hero_id: String) -> Control:
	var info := Catalog.critter(hero_id)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var badge := UiKit.Badge.new()
	badge.level = int(SaveGame.hero(hero_id).get("level", 1))
	badge.custom_minimum_size = Vector2(76, 84)
	row.add_child(badge)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", -6)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(UiKit.label(str(info.get("name", "Hero")).to_upper(), 58, Color("fff1d0"), "x", 12))
	col.add_child(UiKit.label(Catalog.role_name(str(info.get("role", ""))).to_upper(), 27, Color("ffcf5a"), "x", 7))
	row.add_child(col)
	return row


var _slots: Array = []


func _chests() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	var pending := SaveGame.pending_count()
	_slots.clear()
	for i in SaveGame.SLOTS:
		var slot := ChestSlot.new()
		slot.filled = i < pending
		slot.index = i
		slot.tone = SaveGame.chest_tone(i) if slot.filled else "wood"
		slot.custom_minimum_size = Vector2(156, 168)
		if slot.filled:
			slot.gui_input.connect(func(event: InputEvent) -> void:
				if (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed):
					_tap_slot(i)
			)
		row.add_child(slot)
		_slots.append(slot)
	# Chests won since Home last showed: they drop into their slots.
	var fresh := SaveGame.take_fresh()
	var k := 0
	for f in fresh:
		if int(f) < _slots.size():
			_slots[int(f)].arrive(0.45 + 0.22 * k)
			k += 1
	if bool(SaveGame.last_chest.get("full", false)):
		SaveGame.last_chest = {}
		get_tree().create_timer(0.5).timeout.connect(func() -> void: toast("Chest slots full! Open one to make room."))
	return row


## Clash rules: a ready chest opens; a locked one starts its timer if
## nothing else is unlocking; otherwise the slot reports the countdown.
func _tap_slot(i: int) -> void:
	match SaveGame.chest_state(i):
		"ready":
			go("chest", {"index": i})
		"unlocking":
			toast("Unlocks in %s" % SaveGame.clock(SaveGame.chest_wait(i)))
			_slots[i].nudge()
		"locked":
			if SaveGame.start_unlock(i):
				AudioDirector.play("merge", -6.0)
				AudioDirector.haptic(12)
				toast("Unlocking: ready in %s" % SaveGame.span(SaveGame.chest_total(i)))
				_slots[i].nudge()
			else:
				var busy := SaveGame.unlocking_index()
				toast("Another chest is unlocking (%s left)" % SaveGame.clock(SaveGame.chest_wait(busy)))
				AudioDirector.play("error", -8.0)
				_slots[i].nudge()


func _tiles() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	for tab in [["log", "Log", "book_open"], ["slayer", "Slayer", "skull"], ["skills", "Skills", "flask_full"], ["credits", "Credits", "notepad"]]:
		var tile := UiKit.tile_button(str(tab[1]), str(tab[2]), 150, "forged")
		tile.custom_minimum_size = Vector2(150, 128)
		tile.pressed.connect(go.bind(str(tab[0]), {}))
		row.add_child(tile)
	return row


class Showcase extends Control:
	var hero_id := "ember"
	var stage: Stage3D

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		stage = Stage3D.new()
		stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(stage)
		stage.bind_pedestal(hero_id)
		# Soft fade into the menu below, and a dark band under the pills.
		var fade := Fade.new()
		fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(fade)


class Fade extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		# Vertex-colored quads interpolate per pixel, so there are no bands.
		var h := size.y
		var w := size.x
		var bottom := Color(0.075, 0.06, 0.05)
		_grad(Rect2(0, h * 0.6, w, h * 0.4 + 1.0), Color(bottom, 0.0), bottom)
		_grad(Rect2(0, 0, w, h * 0.24), Color(0.02, 0.015, 0.01, 0.7), Color(0.02, 0.015, 0.01, 0.0))
		# Side vignette so the scene sinks into the stone frame.
		var side := Color(0.02, 0.015, 0.01, 0.55)
		var clear := Color(0.02, 0.015, 0.01, 0.0)
		draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w * 0.22, 0), Vector2(w * 0.22, h), Vector2(0, h)]), PackedColorArray([side, clear, clear, side]))
		draw_polygon(PackedVector2Array([Vector2(w * 0.78, 0), Vector2(w, 0), Vector2(w, h), Vector2(w * 0.78, h)]), PackedColorArray([clear, side, side, clear]))

	func _grad(r: Rect2, top: Color, bot: Color) -> void:
		var pts := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
		draw_polygon(pts, PackedColorArray([top, top, bot, bot]))


class ChestSlot extends Control:
	var filled := false
	var index := 0
	var tone := "wood"
	var t := 0.0
	var frame: UiKit.Frame
	var _wait := 0
	var _state := ""
	## 1 while the chest is still in the air on its fly-in, 0 once seated.
	var drop := 0.0
	var _flash := 0.0
	var _shake := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP if filled else Control.MOUSE_FILTER_IGNORE
		frame = UiKit.Frame.new("slot", "leather", {"metal_hi": Color("f0cf8a"), "metal_lo": Color("5e3f1f"), "studs": 1.0, "frame": 8.0})
		frame.margin = 14.0
		add_child(frame)
		if filled:
			frame.set_param("metal_hi", Color("ffe3a0"))

	## Fly-in: the chest falls from above the slot, lands with a squash,
	## a dust flash and a thud.
	func arrive(delay: float) -> void:
		drop = 1.0
		var tw := create_tween()
		tw.tween_interval(delay)
		tw.tween_property(self, "drop", 0.0, 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(func() -> void:
			_flash = 1.0
			_shake = 1.0
			AudioDirector.play("hit", -6.0)
			AudioDirector.haptic(16)
		)

	func nudge() -> void:
		_shake = 1.0

	func _process(delta: float) -> void:
		t += delta
		_flash = maxf(0.0, _flash - delta * 2.2)
		_shake = maxf(0.0, _shake - delta * 3.0)
		if filled:
			_wait = SaveGame.chest_wait(index)
			_state = SaveGame.chest_state(index)
			var pulse := 0.22 + 0.16 * sin(t * 2.4) if _state == "ready" else (0.1 if _state == "unlocking" else 0.04)
			frame.set_param("glow_color", Color(1.0, 0.7, 0.3, pulse))
		queue_redraw()

	func _draw() -> void:
		UiKit.ensure()
		var r := Rect2(Vector2.ZERO, size)
		var font := UiKit.font_x
		if not filled:
			_draw_recess(r)
			UiKit.draw_text(self, font, Vector2(0, r.end.y - 16), "EMPTY", 17, Color(0.62, 0.55, 0.45, 0.7), Color(0.03, 0.02, 0.01), 2, r.size.x)
			return
		var ready := _state == "ready"
		var rarity := SaveGame.chest_rarity(index)
		var rc: Color = UiKit.rarity_colors(rarity)["glow"]
		if ready:
			# Warm light spilling from the chest onto the slot floor.
			var c := Vector2(r.size.x * 0.5, r.size.y * 0.46)
			for i in 6:
				draw_circle(c, r.size.x * (0.42 - i * 0.05), Color(1.0, 0.62, 0.25, 0.035))
		var bob := sin(t * 2.6) * 3.0 if ready else 0.0
		var shake := sin(t * 60.0) * 4.0 * _shake
		# The baked 3D chest: same model as the chest screen.
		var w := r.size.x * 0.84
		var lift := drop * drop * 300.0
		var squash := 1.0 + 0.12 * _shake * (1.0 if drop <= 0.0 else 0.0)
		var aw := w * (1.0 + drop * 0.35) * squash
		var ah := w * (1.0 + drop * 0.35) / squash
		var art := Rect2(Vector2((r.size.x - aw) * 0.5 + shake, 14 + bob - lift + (w - ah)), Vector2(aw, ah))
		# Contact shadow on the slot floor.
		var sh := 0.5 * (1.0 - drop)
		draw_set_transform(Vector2(r.size.x * 0.5, 14 + w * 0.9), 0.0, Vector2(1.0, 0.28))
		draw_circle(Vector2.ZERO, w * 0.38, Color(0, 0, 0, 0.35 * sh))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if _flash > 0.0:
			var fc := Vector2(r.size.x * 0.5, 14 + w * 0.85)
			draw_arc(fc, w * (0.3 + (1.0 - _flash) * 0.45), 0, TAU, 40, Color(1.0, 0.85, 0.5, _flash * 0.8), 4.0, true)
		var tex := SpriteBank._load("res://assets/sprites/chests/%s.png" % tone, "chest_" + tone)
		var tint := Color.WHITE if _state != "locked" else Color(0.82, 0.8, 0.78)
		if tex:
			draw_texture_rect(tex, art, false, tint)
		# Rarity tag across the top.
		UiKit.draw_text(self, font, Vector2(0, 26), rarity.to_upper(), 15, rc.lightened(0.35), Color(0.03, 0.02, 0.01), 2, r.size.x)
		var caption := ""
		var ink := UiKit.CREAM
		match _state:
			"ready":
				caption = "OPEN"
				ink = UiKit.GOLD.lightened(0.2)
			"unlocking":
				caption = SaveGame.clock(_wait)
				# Unlock progress as a thin gilt bar over a dark groove.
				var total := float(SaveGame.chest_total(index))
				var f := clampf(1.0 - float(_wait) / maxf(total, 1.0), 0.0, 1.0)
				var bar := Rect2(r.size.x * 0.16, r.end.y - 46, r.size.x * 0.68, 8)
				draw_rect(bar.grow(1.5), Color(0.02, 0.01, 0.0, 0.95))
				draw_rect(Rect2(bar.position, Vector2(bar.size.x * f, bar.size.y)), Color("d9b064"))
				draw_rect(Rect2(bar.position, Vector2(bar.size.x * f, 2)), Color(1, 0.95, 0.8, 0.6))
			_:
				# Locked: padlock and the full unlock time.
				caption = SaveGame.span(SaveGame.chest_total(index))
				var lock := UiKit.icon("lock_closed")
				if lock:
					var lr := Rect2(Vector2(r.size.x * 0.5 - 15, r.end.y - 72), Vector2(30, 30))
					UiKit.draw_icon(self, lock, lr, Color("e9c47c"), Color(0.06, 0.04, 0.02), 2.0)
		UiKit.draw_text(self, font, Vector2(0, r.end.y - 16), caption, 20, ink, Color(0.05, 0.03, 0.02), 2, r.size.x)

	## An empty slot is an inlaid recess in the leather: a dark sunken
	## well, shadow under the top lip, light catching the bottom lip.
	func _draw_recess(r: Rect2) -> void:
		var well := Rect2(r.position + Vector2(20, 22), r.size - Vector2(40, 52))
		var dark := Color(0.035, 0.025, 0.018, 0.95)
		draw_rect(well, dark)
		for i in 7:
			var k := float(i) / 6.0
			draw_rect(Rect2(well.position, Vector2(well.size.x, 3.0 + i * 3.0)), Color(0, 0, 0, 0.16 * (1.0 - k)))
		draw_line(well.position + Vector2(0, well.size.y), well.end, Color(0.95, 0.75, 0.45, 0.35), 2.0)
		draw_line(Vector2(well.end.x, well.position.y), well.end, Color(0.95, 0.75, 0.45, 0.18), 1.5)
		draw_line(well.position, Vector2(well.end.x, well.position.y), Color(0, 0, 0, 0.8), 2.0)
		draw_line(well.position, Vector2(well.position.x, well.end.y), Color(0, 0, 0, 0.6), 2.0)
		# A faint embossed chest outline in the well floor.
		var c := well.get_center() + Vector2(0, 4)
		var bw := well.size.x * 0.46
		var bh := bw * 0.62
		var body := Rect2(c - Vector2(bw * 0.5, bh * 0.3), Vector2(bw, bh * 0.7))
		var ink := Color(0.5, 0.38, 0.24, 0.28)
		draw_rect(body, ink, false, 2.0)
		draw_arc(Vector2(c.x, body.position.y), bw * 0.5, PI, TAU, 24, ink, 2.0, true)
		draw_line(Vector2(body.position.x, body.position.y + 2), Vector2(body.end.x, body.position.y + 2), Color(0, 0, 0, 0.5), 1.0)


## A dark smoked plate behind the logo with gilt rules either side, so the
## title never fights the 3D scene behind it.
class LogoPlate extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)

	func _draw() -> void:
		var c := size * 0.5
		var rx := size.x * 0.5
		var ry := size.y * 0.95
		# Soft elliptical smoke: concentric vertex-coloured fans, no banding.
		var pts := PackedVector2Array([c])
		var cols := PackedColorArray([Color(0.03, 0.02, 0.015, 0.82)])
		for i in 49:
			var a := TAU * i / 48.0
			pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
			cols.append(Color(0.03, 0.02, 0.015, 0.0))
		for i in 48:
			draw_polygon(PackedVector2Array([pts[0], pts[i + 1], pts[i + 2]]), PackedColorArray([cols[0], cols[i + 1], cols[i + 2]]))
		var gold := Color("c8963a")
		var y := size.y - 10.0
		var half := size.x * 0.34
		draw_line(Vector2(c.x - half, y), Vector2(c.x - 34, y), Color(gold, 0.85), 2.0, true)
		draw_line(Vector2(c.x + 34, y), Vector2(c.x + half, y), Color(gold, 0.85), 2.0, true)
		var d := 9.0
		draw_colored_polygon(PackedVector2Array([Vector2(c.x, y - d), Vector2(c.x + d * 1.6, y), Vector2(c.x, y + d), Vector2(c.x - d * 1.6, y)]), Color("e8c886"))
		draw_circle(Vector2(c.x - half, y), 3.0, gold)
		draw_circle(Vector2(c.x + half, y), 3.0, gold)


## The carved wordmark: heavy Cinzel cut into the plate, with a dark
## chisel shadow above, a warm lip below, and a gilt face.
class Wordmark extends Control:
	var text := ""
	var size_px := 52

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)

	func _draw() -> void:
		UiKit.ensure()
		var font := UiKit.font_n
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
		var at := Vector2((size.x - w) * 0.5, size.y * 0.5 + size_px * 0.34)
		draw_string_outline(font, at + Vector2(0, 5), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, 14, Color(0, 0, 0, 0.55))
		draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, 8, Color("1c0f06"))
		draw_string(font, at + Vector2(0, -2), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, Color("3a2208"))
		draw_string(font, at + Vector2(0, 2), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, Color("fff0bf"))
		draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, Color("e2b252"))
		# Gilt sheen across the top half of the letters.
		var clip_h := size_px * 0.42
		var top := at.y - size_px * 0.72
		draw_set_transform(Vector2.ZERO)
		for i in 3:
			var a := 0.12 - 0.035 * i
			draw_rect(Rect2(at.x - 4, top + i * clip_h / 3.0, w + 8, clip_h / 3.0), Color(1, 0.95, 0.8, 0.0))
			draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, Color(1, 0.93, 0.7, a))


## HUNT: a slab of oxblood leather in a forged iron frame with gilt bevels
## and rivets, an embossed gilt label, and a real pressed state.
class ForgedButton extends BaseButton:
	var text := "HUNT"

	func _ready() -> void:
		button_down.connect(queue_redraw)
		button_up.connect(queue_redraw)
		mouse_entered.connect(queue_redraw)
		mouse_exited.connect(queue_redraw)
		resized.connect(queue_redraw)
		pivot_offset = size * 0.5

	func _poly(r: Rect2, cut: float) -> PackedVector2Array:
		return PackedVector2Array([
			r.position + Vector2(cut, 0), Vector2(r.end.x - cut, r.position.y), Vector2(r.end.x, r.position.y + cut),
			Vector2(r.end.x, r.end.y - cut), Vector2(r.end.x - cut, r.end.y), Vector2(r.position.x + cut, r.end.y),
			Vector2(r.position.x, r.end.y - cut), Vector2(r.position.x, r.position.y + cut)])

	func _draw() -> void:
		UiKit.ensure()
		var down := is_pressed() or button_pressed
		var sink := 6.0 if down else 0.0
		var r := Rect2(Vector2(0, sink), size - Vector2(0, 8))
		# Drop shadow shrinks when pressed.
		var sh := _poly(Rect2(r.position + Vector2(0, 8.0 - sink), r.size), 18)
		draw_colored_polygon(sh, Color(0, 0, 0, 0.55 if not down else 0.35))
		# Forged iron frame: dark rim, lit top bevel, gilt inner lip.
		draw_colored_polygon(_poly(r, 18), Color("17110c"))
		var iron := r.grow(-4)
		var top := Color("6a5c4c") if not down else Color("4a4036")
		var bot := Color("2a221b")
		var ip := _poly(iron, 15)
		draw_polygon(ip, PackedColorArray([top, top, top, bot, bot, bot, bot, top]))
		var gilt := iron.grow(-7)
		var gp := _poly(gilt, 11)
		var gl := PackedVector2Array(gp)
		gl.append(gp[0])
		draw_polyline(gl, Color("e6c06a"), 2.5, true)
		# Leather: deep oxblood, lighter toward the top, with stitching.
		var lea := gilt.grow(-4)
		var lt := Color("7c1e18") if not down else Color("5e1612")
		var lb := Color("3a0c0a")
		var lp := _poly(lea, 8)
		draw_polygon(lp, PackedColorArray([lt, lt, lt, lb, lb, lb, lb, lt]))
		var rng := RandomNumberGenerator.new()
		rng.seed = 41
		for i in 90:
			var p := lea.position + Vector2(rng.randf() * lea.size.x, rng.randf() * lea.size.y)
			draw_line(p, p + Vector2(rng.randf_range(2, 6), rng.randf_range(-1, 1)), Color(0, 0, 0, 0.12), 1.0)
		var st := lea.grow(-8)
		var x := st.position.x + 6.0
		while x < st.end.x - 6.0:
			draw_line(Vector2(x, st.position.y), Vector2(x + 7, st.position.y), Color(0.85, 0.62, 0.35, 0.55), 1.5)
			draw_line(Vector2(x, st.end.y), Vector2(x + 7, st.end.y), Color(0.85, 0.62, 0.35, 0.45), 1.5)
			x += 13.0
		# Gloss band across the upper leather.
		draw_rect(Rect2(lea.position + Vector2(10, 5), Vector2(lea.size.x - 20, lea.size.y * 0.22)), Color(1, 0.85, 0.75, 0.08 if not down else 0.03))
		# Rivets in the iron corners.
		for c in [iron.position + Vector2(18, iron.size.y * 0.5), Vector2(iron.end.x - 18, iron.position.y + iron.size.y * 0.5)]:
			draw_circle(c + Vector2(0, 1.5), 6.5, Color(0, 0, 0, 0.6))
			draw_circle(c, 6.0, Color("b08a48"))
			draw_circle(c - Vector2(1.5, 1.5), 2.5, Color("ffe6a8"))
		# Embossed gilt label: dark chisel above, light lip below, gold face.
		var font := UiKit.font_n
		var fs := 62
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var at := Vector2((size.x - w) * 0.5, r.position.y + r.size.y * 0.5 + fs * 0.35)
		draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 7, Color("1e0604"))
		draw_string(font, at + Vector2(0, -2), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("2a0a06"))
		draw_string(font, at + Vector2(0, 2), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("ffe9b0"))
		draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("e8b85a") if not down else Color("c89a48"))
