extends ScreenBase

## The desk in the camp: the chest drawer, the wordmark and tidy icon tiles
## for the side screens (log, slayer, skills, forge, stash, credits).
##
## There is no hunt button here any more. Hunts start at a gate in the camp,
## so the desk is where the camp's own business lives.


func build() -> void:
	# The camp is the front door now, so the desk is the camp's counter: the
	# chest drawer and the side tiles, with no tab of its own.
	show_nav = false
	nav_tab = ""
	var pad := insets()
	# The desk shows the hero on the lit plinth: the camp shows the place,
	# the desk shows the one who works there.
	var stage := Showcase.new()
	stage.hero_id = SaveGame.featured_id()
	stage.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	stage.anchor_bottom = 0.42
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
	box.add_child(_chests())
	box.add_child(_tiles())


var _header: HBoxContainer
var _pills: Array = []


## Home is rebuilt on every visit, but re-read the purse and the drawer on
## enter as well, so the counters and chest slots never show a stale number
## after a hunt, a chest open or a trophy claim.
func open(_args: Dictionary = {}) -> void:
	_sync()
	if bool(SaveGame.last_chest.get("full", false)):
		var queued: Dictionary = SaveGame.last_chest.get("queued", {})
		SaveGame.last_chest = {}
		var note := _queued_note(queued)
		get_tree().create_timer(0.5).timeout.connect(func() -> void: toast(note))


## What the last chest that found no room in the drawer became, said once on
## the way home: it joined the queue and waits its turn there.
func _queued_note(queued: Dictionary) -> String:
	if queued.is_empty():
		return "Chest slots full! Open one to make room."
	return SaveGame.queue_text(queued)


func _collect_pills() -> void:
	_pills.clear()
	if _header == null:
		return
	for child in _header.get_children():
		if child.has_method("set_amount"):
			_pills.append(child)


## Re-read the three counters on enter: the trophies, the coins and the gear
## shards. The shard wallet is read from the same place the Forge reads it, so
## a duplicate melted into shards shows here instead of a flat zero.
func _sync() -> void:
	var amounts := [str(int(SaveGame.data["trophies"])), str(int(SaveGame.data["coins"])), str(int(SaveGame.data.get("gear_shards", 0)))]
	for i in _pills.size():
		if i < amounts.size():
			_pills[i].set_amount(amounts[i])
	for slot in _slots:
		slot.refresh()
	_refresh_pips()


var _forge_pip: Control
var _slayer_pip: Control
var _trophy_pip: Control
## The Skills tile carries the bag: it gets a dot while the bag holds
## something worth selling.
var _skills_pip: Control
## The Stash tile carries the Hub stash: it gets a dot while something is
## parked there.
var _stash_pip: Control


## Re-read the three attention pips on enter, beside the counters: Forge when a
## piece is affordable, Slayer when a contract is finished, Road when a mastery
## trophy waits to be claimed. A static dot, so it is safe with reduce flashing.
func _refresh_pips() -> void:
	if _forge_pip != null:
		_forge_pip.visible = SaveGame.forge_ready(SaveGame.featured_id())
	if _slayer_pip != null:
		_slayer_pip.visible = SaveGame.slayer_ready()
	if _skills_pip != null:
		_skills_pip.visible = SaveGame.bag_value() > 0
	if _stash_pip != null:
		_stash_pip.visible = SaveGame.stash_total() > 0
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


var _slots: Array = []


func _chests() -> VBoxContainer:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
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
	col.add_child(row)
	# The queue: the chests that found the drawer full, each with its own
	# clock on the moment it may be opened.
	if SaveGame.queued_count() > 0:
		col.add_child(_queued_row())
	return col


## The queued chests, one chip each: the chest's look, its rarity and the
## countdown on its timer. A chip that is ready opens the chest; one that
## is still waiting says how long it waits. Nothing is drawn when the queue
## is empty.
func _queued_row() -> VBoxContainer:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	var waiting := SaveGame.queued_count()
	if waiting <= 0:
		return col
	var head := UiKit.label("QUEUED · %d WAITING" % waiting, 17, UiKit.MUTED.lightened(0.15), "b", 2)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(head)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	# Four chips fit the row; the rest are counted in one line.
	for i in mini(waiting, 4):
		var chip := QueuedChip.new()
		chip.index = i
		chip.custom_minimum_size = Vector2(156, 168)
		chip.pressed.connect(_tap_queued.bind(i))
		row.add_child(chip)
	if waiting > 4:
		var more := UiKit.label("+%d MORE" % (waiting - 4), 18, UiKit.MUTED.lightened(0.15), "b", 2)
		more.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(more)
	col.add_child(row)
	return col


## A queued chest: it opens once its timer is up. Before that the chip says
## how long it still waits and does nothing else.
func _tap_queued(i: int) -> void:
	AudioDirector.sfx("ui_tap")
	if SaveGame.queued_state(i) == "ready":
		AudioDirector.haptic("medium")
		go("chest", {"queue": i})
		return
	toast("Opens in %s" % SaveGame.span(SaveGame.queued_wait(i)))


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
	row.add_theme_constant_override("separation", 10)
	var tabs := [["log", "Log", "book_open"], ["slayer", "Slayer", "skull"], ["skills", "Skills", "flask_full"], ["forge", "Forge", "gear"], ["stash", "Stash", "pouch"], ["credits", "Credits", "notepad"]]
	# Six tiles share the narrow portrait row, so the width comes from the
	# safe area: the row never runs off the screen and every tile keeps the
	# 88 px tap floor.
	var pad := insets()
	var avail := get_viewport_rect().size.x - float(pad["l"]) - float(pad["r"])
	var tile_w := clampi(int((avail - 10.0 * (tabs.size() - 1)) / float(tabs.size())), 88, 128)
	for tab in tabs:
		var tile := UiKit.tile_button(str(tab[1]), str(tab[2]), 150, "forged")
		tile.custom_minimum_size = Vector2(tile_w, 128)
		tile.pressed.connect(go.bind(str(tab[0]), {}))
		# A ready Forge piece or a finishable contract gets a small dot; the
		# mastery dot rides the Road tab instead (see _add_road_pip).
		match str(tab[0]):
			"forge":
				_forge_pip = _add_tile_pip(tile)
			"slayer":
				_slayer_pip = _add_tile_pip(tile)
			"skills":
				_skills_pip = _add_tile_pip(tile)
			"stash":
				_stash_pip = _add_tile_pip(tile)
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


class ChestSlot extends Control:
	var filled := false
	var index := 0
	var tone := "wood"
	var t := 0.0
	var frame: UiKit.Frame
	var _wait := 0
	var _state := ""
	## Last chest state read, so a change (the unlock finishing) can be heard.
	var _seen := ""
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
			# The unlock finishing is the one change the slot announces:
			# the chest is ready to be opened.
			if _seen == "":
				_seen = _state
			elif _seen != _state:
				_seen = _state
				if _state == "ready":
					AudioDirector.sfx("chest_ready")
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


## A chest waiting its turn in the queue: its look, its rarity and the clock
## on the moment it may be opened. The chip is live, so the countdown ticks
## down while Home is open, and the chest lights up once its timer is up.
class QueuedChip extends Button:
	var index := 0
	var _wait := 0
	var _total := 1
	var _age := 0
	var _is_ready := false
	var _flash := 0.0
	var _t := 0.0

	func _ready() -> void:
		UiKit.ensure()
		focus_mode = Control.FOCUS_NONE
		var empty := StyleBoxEmpty.new()
		for state in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
			add_theme_stylebox_override(state, empty)
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button_down.connect(func() -> void: _flash = 1.0)

	## The chip reads the queue every frame, so it never shows a stale
	## countdown: the chest leaves the queue by being opened, and the chip
	## for it stops drawing when its place is gone.
	func _process(delta: float) -> void:
		_t += delta
		_flash = maxf(0.0, _flash - delta * 2.4)
		if index >= SaveGame.queued_count():
			queue_redraw()
			return
		_wait = SaveGame.queued_wait(index)
		_total = maxi(1, SaveGame.queued_total(index))
		_age = SaveGame.queued_age_of(SaveGame.queued_chest(index))
		_is_ready = _wait <= 0
		queue_redraw()

	func _draw() -> void:
		UiKit.ensure()
		if index >= SaveGame.queued_count():
			return
		var r := Rect2(Vector2.ZERO, size)
		var font := UiKit.font_x
		var rarity := SaveGame.queued_rarity(index)
		var tone := SaveGame.queued_tone(index)
		var cols: Dictionary = UiKit.rarity_colors(rarity)
		var base: Color = cols["bg"]
		var lip: Color = cols["lip"]
		var glow: Color = cols["glow"]
		# The plate the chip sits on: the rarity's own metal, dimmed while
		# the chest waits and lit once its timer is up.
		var face := base if not _is_ready else base.lightened(0.10)
		UiKit.rr_shadow(self, r, 12.0, 4.0, 0.35)
		UiKit.rr_fill(self, r, 12.0, face.lightened(0.08), face.darkened(0.22))
		UiKit.rr_line(self, r.grow(-2.0), 10.0, Color(lip, 0.85 if _is_ready else 0.5), 2.0)
		if _is_ready:
			# A ready chest breathes a little light around its plate.
			var pulse := 0.30 + 0.16 * sin(_t * 3.0)
			for i in 4:
				UiKit.rr_line(self, r.grow(3.0 + i * 3.0), 14.0 + i * 3.0, Color(glow, pulse * (1.0 - float(i) / 4.0)), 2.0)
		# The chest itself, in the tone it was earned in.
		var tex := SpriteBank._load("res://assets/sprites/chests/%s.png" % tone, "chest_" + tone)
		var art := Rect2(Vector2(r.size.x * 0.5 - 34.0, 32.0), Vector2(68, 68))
		if tex:
			draw_texture_rect(tex, art, false, Color.WHITE if _is_ready else Color(0.74, 0.72, 0.70))
		# Rarity tag across the top.
		UiKit.draw_text(self, font, Vector2(0, 24), rarity.to_upper(), 15, glow.lightened(0.35), Color(0.03, 0.02, 0.01), 2, r.size.x)
		# How long it has been waiting, counted from the moment it queued.
		var since := "just now" if _age < 60 else "%s ago" % SaveGame.span(_age)
		UiKit.draw_text(self, font, Vector2(0, r.size.y - 44), since, 14, UiKit.MUTED.lightened(0.1), Color(0.05, 0.03, 0.02), 2, r.size.x)
		# The countdown: the clock on the chest, ticking down.
		var caption := "READY" if _is_ready else SaveGame.clock(_wait)
		var ink := UiKit.GOLD.lightened(0.25) if _is_ready else UiKit.CREAM
		UiKit.draw_text(self, font, Vector2(0, r.size.y - 22), caption, 21, ink, Color(0.05, 0.03, 0.02), 2, r.size.x)
		# A thin bar: how much of the wait is done.
		var bar := Rect2(r.size.x * 0.16, r.size.y - 12, r.size.x * 0.68, 6)
		draw_rect(bar.grow(1.0), Color(0.02, 0.01, 0.0, 0.9))
		var f := clampf(1.0 - float(_wait) / float(_total), 0.0, 1.0)
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * f, bar.size.y)), lip)
		if _flash > 0.0:
			UiKit.rr_line(self, r.grow(-2.0), 10.0, Color(1.0, 0.92, 0.72, _flash * 0.8), 3.0)


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
