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
	_header = header()
	# Home keeps the full-width currency bar, but lifts it to the 88 px tap
	# minimum so the pills and the settings cog are as easy to hit as any
	# other control on the screen.
	_header.custom_minimum_size = Vector2(0, 88)
	box.add_child(_header)
	_collect_pills()
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
	# HUNT opens the map sheet: pick a biome (sealed ones show why), then
	# Start runs it with the equipped hero.
	play.pressed.connect(open_map_sheet)
	box.add_child(play)
	box.add_child(_chests())
	box.add_child(_tiles())


var sheet: Control
var _header: HBoxContainer
var _pills: Array = []


## Home is rebuilt on every visit, but re-read the purse and the drawer on
## enter as well, so the counters and chest slots never show a stale number
## after a hunt, a chest open or a trophy claim.
func open(_args: Dictionary = {}) -> void:
	_sync()
	if bool(SaveGame.last_chest.get("full", false)):
		SaveGame.last_chest = {}
		get_tree().create_timer(0.5).timeout.connect(func() -> void: toast("Chest slots full! Open one to make room."))


func _collect_pills() -> void:
	_pills.clear()
	if _header == null:
		return
	for child in _header.get_children():
		if child.has_method("set_amount"):
			_pills.append(child)


func _sync() -> void:
	var amounts := [str(int(SaveGame.data["trophies"])), str(int(SaveGame.data["coins"])), "0"]
	for i in _pills.size():
		if i < amounts.size():
			_pills[i].set_amount(amounts[i])
	for slot in _slots:
		slot.refresh()
	_refresh_pips()


var _forge_pip: Control
var _slayer_pip: Control
var _trophy_pip: Control


## Re-read the three attention pips on enter, beside the counters: Forge when a
## piece is affordable, Slayer when a contract is finished, Road when a mastery
## trophy waits to be claimed. A static dot, so it is safe with reduce flashing.
func _refresh_pips() -> void:
	if _forge_pip != null:
		_forge_pip.visible = SaveGame.forge_ready(SaveGame.featured_id())
	if _slayer_pip != null:
		_slayer_pip.visible = SaveGame.slayer_ready()
	if _trophy_pip == null:
		_add_road_pip()
	if _trophy_pip != null:
		_trophy_pip.visible = SaveGame.mastery_ready()
		_place_road_pip()


## A small attention dot at a tile's top-right, drawn only (no new art).
func _add_tile_pip(tile: Control) -> Control:
	var pip := Pip.new()
	pip.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	pip.offset_left = -28.0
	pip.offset_top = -6.0
	pip.offset_right = -6.0
	pip.offset_bottom = 16.0
	pip.visible = false
	tile.add_child(pip)
	return pip


## The Road tab (the Home control that opens the Trophy screen) carries the
## mastery pip. It rides over the shared dock, so Home positions it against the
## dock's own layout and keeps it there on resize.
func _add_road_pip() -> void:
	if _dock == null:
		return
	_trophy_pip = Pip.new()
	_dock.add_child(_trophy_pip)
	_dock.resized.connect(_place_road_pip)
	_place_road_pip()


## Park the mastery pip at the top-right of the dock's Road tab icon. The dock
## resolves the tab by id ("trophy") and hands back its real icon rect, so the
## dot follows any tab order, count or icon-size change; if the tab is absent,
## the dock returns an empty rect and the dot hides.
func _place_road_pip() -> void:
	var dock := _dock as UiKit.Dock
	if _trophy_pip == null or dock == null:
		return
	var icon := dock.tab_icon_rect("trophy")
	if icon.size == Vector2.ZERO:
		_trophy_pip.visible = false
		return
	_trophy_pip.size = Vector2(22, 22)
	_trophy_pip.position = Vector2(icon.position.x + icon.size.x - 20.0, icon.position.y - 8.0)


func open_map_sheet() -> void:
	if sheet != null:
		return
	AudioDirector.sfx("ui_tap")
	sheet = MapSheet.new()
	sheet.home = self
	sheet.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(sheet)


func start_hunt(biome_id: String) -> void:
	SaveGame.data["last_biome"] = biome_id
	go("run", {"biome": biome_id, "hero": SaveGame.featured_id()})


## Today's seeded challenge, run with the equipped hero. The seed, day key and
## modifiers ride the run args so run_screen pins the exact same hunt.
func start_daily() -> void:
	var key := Daily.today_key(int(Time.get_unix_time_from_system()))
	var biome_id := Daily.biome_for(key)
	SaveGame.data["last_biome"] = biome_id
	go("run", {
		"biome": biome_id,
		"hero": SaveGame.featured_id(),
		"seed": Daily.seed_for(key),
		"daily": key,
		"modifiers": Daily.modifiers_for(key),
	})


func _nameplate(hero_id: String) -> Control:
	var info := Catalog.critter(hero_id)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var badge := UiKit.Badge.new()
	badge.level = int(SaveGame.hero(hero_id).get("level", 1))
	badge.custom_minimum_size = Vector2(76, 84)
	row.add_child(badge)
	# The name plate fills the row and wraps, so a long name (or a long
	# role title) never runs off the screen beside the badge.
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", -6)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var name_label := UiKit.label(str(info.get("name", "Hero")).to_upper(), 58, Color("fff1d0"), "x", 12)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(name_label)
	var role_label := UiKit.label(Catalog.role_name(str(info.get("role", ""))).to_upper(), 27, Color("ffcf5a"), "x", 7)
	role_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(role_label)
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
	return row


## Clash rules: a ready chest opens; a locked one starts its timer if
## nothing else is unlocking; otherwise the slot reports the countdown.
func _tap_slot(i: int) -> void:
	match SaveGame.chest_state(i):
		"ready":
			AudioDirector.sfx("ui_tap")
			AudioDirector.haptic("light")
			go("chest", {"index": i})
		"unlocking":
			AudioDirector.sfx("ui_tap")
			toast("Unlocks in %s" % SaveGame.clock(SaveGame.chest_wait(i)))
			_slots[i].nudge()
		"locked":
			if SaveGame.start_unlock(i):
				AudioDirector.sfx("unlock_start")
				AudioDirector.haptic("medium")
				toast("Unlocking: ready in %s" % SaveGame.span(SaveGame.chest_total(i)))
				_slots[i].nudge()
			else:
				var busy := SaveGame.unlocking_index()
				toast("Another chest is unlocking (%s left)" % SaveGame.clock(SaveGame.chest_wait(busy)))
				AudioDirector.sfx("ui_error")
				AudioDirector.haptic("light")
				_slots[i].nudge()


func _tiles() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	for tab in [["log", "Log", "book_open"], ["slayer", "Slayer", "skull"], ["skills", "Skills", "flask_full"], ["forge", "Forge", "gear"], ["credits", "Credits", "notepad"]]:
		var tile := UiKit.tile_button(str(tab[1]), str(tab[2]), 150, "forged")
		# Five tiles share the narrow portrait row; 128 wide still leaves the
		# 88 px tap floor and keeps every caption readable.
		tile.custom_minimum_size = Vector2(128, 128)
		tile.pressed.connect(go.bind(str(tab[0]), {}))
		# A ready Forge piece or a finishable contract gets a small dot; the
		# mastery dot rides the Road tab instead (see _add_road_pip).
		match str(tab[0]):
			"forge":
				_forge_pip = _add_tile_pip(tile)
			"slayer":
				_slayer_pip = _add_tile_pip(tile)
		row.add_child(tile)
	return row


## A small drawn attention dot for a ready tile or nav entry: an ember core in
## a gilt ring with a dark keyline. No new art, and static (never pulses), so it
## is safe with reduce flashing on.
class Pip extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5 - 2.0
		draw_circle(c + Vector2(0, 1.5), r + 1.0, Color(0, 0, 0, 0.5))
		draw_circle(c, r + 1.0, Color("160a05"))
		draw_circle(c, r, Color("e2bb6a"))
		draw_circle(c - Vector2(0, r * 0.12), r * 0.68, Color("c0341f"))
		draw_circle(c - Vector2(0, r * 0.28), r * 0.34, Color("ff8a4a"))
		draw_arc(c, r * 0.9, PI * 1.05, PI * 1.95, 16, Color(1, 0.95, 0.78, 0.75), 1.5, true)


class Showcase extends Control:
	var hero_id := "ember"
	var fill := 0.46
	var stage: Stage3D

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		stage = Stage3D.new()
		stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(stage)
		stage.pedestal_fill = fill
		if hero_id == "pebble":
			# Aldric showcase look (hero-visual increment 1): dress the
			# pedestal hero in T2 steel, the artist's full textured plate.
			# Without this, dress() uses his equipped tiers, and a bare
			# (T0) Aldric is stripped to the generated gambeson, which
			# renders as untextured grey clay under the showcase rig.
			# NOTE: bramble's kit shares this ("under" key); left for the
			# next hero-visual increment per scope.
			Gear3D.override = {"armor": 2, "weapon": 2}
		stage.bind_pedestal(hero_id)
		Gear3D.override = {}
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
			AudioDirector.sfx("chest_land")
			AudioDirector.haptic("medium")
		)

	func nudge() -> void:
		_shake = 1.0

	## Re-read the drawer on enter: a slot can fill or empty while another
	## screen (a hunt, the chest) is in front of Home.
	func refresh() -> void:
		var on := index < SaveGame.pending_count()
		if on == filled:
			return
		filled = on
		tone = SaveGame.chest_tone(index) if filled else "wood"
		mouse_filter = Control.MOUSE_FILTER_STOP if filled else Control.MOUSE_FILTER_IGNORE
		queue_redraw()

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


## Map choice: a sheet that rises over Home with one row per biome (art
## strip, name, boss, status; sealed biomes greyed with their unlock rule),
## the chosen row lit, and START at the foot.
class MapSheet extends Control:
	var home: Node
	var chosen := ""
	var _rows := {}
	var _start: Button
	var _panel: Control

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		var dim := ColorRect.new()
		dim.color = Color(0, 0, 0, 0.62)
		dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		dim.gui_input.connect(func(e: InputEvent) -> void:
			if (e is InputEventMouseButton and e.pressed) or (e is InputEventScreenTouch and e.pressed):
				close()
		)
		add_child(dim)
		var pad := UiKit.safe_insets()
		_panel = PanelContainer.new()
		var empty := StyleBoxEmpty.new()
		for side in ["left", "right", "top", "bottom"]:
			empty.set("content_margin_" + side, 26)
		_panel.add_theme_stylebox_override("panel", empty)
		_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		_panel.offset_left = float(pad["l"]) + 18.0
		_panel.offset_right = -float(pad["r"]) - 18.0
		_panel.offset_bottom = -float(pad["b"]) - 18.0
		_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
		add_child(_panel)
		var frame := UiKit.Frame.new("panel", "leather", {})
		frame.margin = 26.0
		_panel.add_child(frame)
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 14)
		_panel.add_child(box)
		var title := UiKit.title("Choose a hunt", 46)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(title)
		box.add_child(_daily_row())
		var last := str(SaveGame.data.get("last_biome", ""))
		for entry in Catalog.BIOMES:
			var id := str(entry["id"])
			if chosen == "" and SaveGame.biome_open(id):
				chosen = id
			box.add_child(_row(entry))
		if last != "" and SaveGame.biome_open(last):
			chosen = last
		var foot := HBoxContainer.new()
		foot.alignment = BoxContainer.ALIGNMENT_CENTER
		foot.add_theme_constant_override("separation", 16)
		var back := UiKit.secondary("Close", 200, 88)
		back.pressed.connect(close)
		foot.add_child(back)
		_start = UiKit.button("START", 400, 104, "gold")
		_start.pressed.connect(func() -> void:
			if chosen != "":
				AudioDirector.sfx("card_pick")
				home.start_hunt(chosen)
		)
		foot.add_child(_start)
		box.add_child(foot)
		_light()
		_panel.modulate.a = 0.0
		_panel.position.y += 80.0
		var tw := create_tween().set_parallel(true)
		tw.tween_property(_panel, "modulate:a", 1.0, 0.16)
		tw.tween_property(_panel, "position:y", _panel.position.y - 80.0, 0.26).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	func close() -> void:
		AudioDirector.sfx("ui_tap")
		home.sheet = null
		queue_free()

	func _row(entry: Dictionary) -> Control:
		var id := str(entry["id"])
		var open := SaveGame.biome_open(id)
		var cleared := SaveGame.biome_cleared(id)
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.flat = true
		b.custom_minimum_size = Vector2(0, 132)
		var none := StyleBoxEmpty.new()
		for st in ["normal", "hover", "pressed", "focus", "disabled"]:
			b.add_theme_stylebox_override(st, none)
		var holder := Control.new()
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		b.add_child(holder)
		_press_feel(b, holder)
		var h := HBoxContainer.new()
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		h.offset_left = 14
		h.offset_right = -14
		h.offset_top = 10
		h.offset_bottom = -10
		h.add_theme_constant_override("separation", 16)
		b.add_child(h)
		var art := TextureRect.new()
		art.texture = _art(id)
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		art.custom_minimum_size = Vector2(196, 0)
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if not open:
			art.modulate = Color(0.35, 0.35, 0.38)
		h.add_child(art)
		var v := VBoxContainer.new()
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_theme_constant_override("separation", 2)
		h.add_child(v)
		v.add_child(UiKit.label(str(entry["name"]).to_upper(), 30, UiKit.GOLD.lightened(0.2) if open else Color("8d8478"), "x", 4))
		var boss := Catalog.critter(str(entry["boss"]))
		v.add_child(UiKit.label("Guarded by %s" % str(boss["name"]), 18, UiKit.CREAM if open else UiKit.MUTED, "b", 0))
		var status := "✦ CLEARED" if cleared else ("OPEN" if open else "SEALED · " + SaveGame.biome_lock_text(id) + " to unlock")
		var st_label := UiKit.label(status, 16, Color("9fe08a") if cleared else (UiKit.GOLD if open else Color("c89a8a")), "x", 2)
		st_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(st_label)
		v.add_child(UiKit.label(Catalog.recommended_text(id), 16, UiKit.MUTED, "b", 0))
		if not open:
			# Sealed: the row itself is disabled and its label says why, so
			# it reads as unavailable instead of a dead tap.
			b.disabled = true
			b.tooltip_text = SaveGame.biome_lock_text(id) + " to unlock"
			var lock := TextureRect.new()
			lock.texture = UiKit.icon("lock_closed")
			lock.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			lock.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			lock.custom_minimum_size = Vector2(48, 48)
			lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
			h.add_child(lock)
		else:
			b.pressed.connect(func() -> void:
				chosen = id
				AudioDirector.sfx("ui_tap")
				_light()
			)
		_rows[id] = [b, holder]
		return b

	## The Daily Challenge row at the top of the sheet: today's seeded biome,
	## its modifiers and your best local score. Always open; tapping runs it
	## with the equipped hero (one attempt per run, retries fine).
	func _daily_row() -> Control:
		var key := Daily.today_key(int(Time.get_unix_time_from_system()))
		var biome := Catalog.biome(Daily.biome_for(key))
		var parts := PackedStringArray()
		for m in Daily.modifiers_for(key):
			parts.append(str(m.get("name", "")))
		var best := SaveGame.daily_best(key)
		# A sealed biome is still today's daily; flag the daily-only access.
		var locked := not SaveGame.biome_open(str(biome["id"]))
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.flat = true
		b.custom_minimum_size = Vector2(0, 132)
		var none := StyleBoxEmpty.new()
		for st in ["normal", "hover", "pressed", "focus", "disabled"]:
			b.add_theme_stylebox_override(st, none)
		var holder := Control.new()
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		b.add_child(holder)
		_press_feel(b, holder)
		var frame := UiKit.Frame.new("card", "leather", {
			"metal_hi": Color("ffe6a8"), "metal_lo": Color("6a4416"), "frame": 5.0,
			"glow_color": Color(1.0, 0.72, 0.3, 0.38),
			"face_top": Color("2a2016"), "face_bot": Color("0c0907"),
		})
		frame.margin = 2.0
		holder.add_child(frame)
		var h := HBoxContainer.new()
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		h.offset_left = 14
		h.offset_right = -14
		h.offset_top = 10
		h.offset_bottom = -10
		h.add_theme_constant_override("separation", 16)
		b.add_child(h)
		var art := TextureRect.new()
		art.texture = _art(str(biome["id"]))
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		art.custom_minimum_size = Vector2(196, 0)
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(art)
		var v := VBoxContainer.new()
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_theme_constant_override("separation", 2)
		h.add_child(v)
		v.add_child(UiKit.label("DAILY CHALLENGE", 30, UiKit.GOLD.lightened(0.25), "x", 4))
		v.add_child(UiKit.label("%s · %s" % [str(biome["name"]).to_upper(), " + ".join(parts)], 18, UiKit.CREAM, "b", 0))
		v.add_child(UiKit.label("Best today %d" % best if best > 0 else "No run today yet", 16, UiKit.GOLD if best > 0 else UiKit.MUTED, "x", 2))
		v.add_child(UiKit.label(Catalog.recommended_text(str(biome["id"])), 16, UiKit.MUTED, "b", 0))
		if locked:
			v.add_child(UiKit.label("Daily pass", 16, Color("9fe08a"), "b", 2))
		var tag := UiKit.label("TODAY", 16, Color("9fe08a"), "x", 2)
		tag.custom_minimum_size = Vector2(90, 0)
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		h.add_child(tag)
		b.pressed.connect(func() -> void:
			AudioDirector.sfx("card_pick")
			home.start_daily()
		)
		return b


	func _art(id: String) -> Texture2D:
		var path := "res://assets/sprites/arenas/%s_banner.png" % id
		return load(path) if ResourceLoader.exists(path) else SpriteBank.arena(id)

	## The flat rows are hand-drawn, so give them the same pressed sink the
	## shared buttons have: a quick shrink, then a spring back.
	func _press_feel(button: Button, holder: Control) -> void:
		button.button_down.connect(func() -> void:
			holder.pivot_offset = holder.size * 0.5
			var tw := create_tween()
			tw.tween_property(holder, "scale", Vector2(0.975, 0.975), 0.05))
		button.button_up.connect(func() -> void:
			holder.pivot_offset = holder.size * 0.5
			var tw := create_tween()
			tw.tween_property(holder, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT))

	func _light() -> void:
		for id in _rows:
			var holder: Control = _rows[id][1]
			for c in holder.get_children():
				c.queue_free()
			var on: bool = id == chosen
			var metal := [Color("ffe6a8"), Color("6a4416")] if on else UiKit.rarity_metal("common")
			var frame := UiKit.Frame.new("card", "leather", {
				"metal_hi": metal[0], "metal_lo": metal[1], "frame": 5.0 if on else 3.0,
				"glow_color": Color(1.0, 0.72, 0.3, 0.5) if on else Color(0, 0, 0, 0),
				"face_top": Color("2a2016") if on else Color("15100c"), "face_bot": Color("0c0907"),
			})
			frame.margin = 2.0
			holder.add_child(frame)
		_set_start_enabled(chosen != "")

	## START greys out (frame and label) when there is no hunt to launch, and
	## says what is missing.
	func _set_start_enabled(on: bool) -> void:
		_start.disabled = not on
		_start.tooltip_text = "" if on else "Pick a biome to begin"
		var skin = _start.get("skin")
		if skin != null:
			skin.tone = "gold" if on else "grey"
			skin.apply()
