extends Control
## The Trophy Road, full screen over the camp: arenas as banners, a glowing
## track that fills to the player's trophies, and a card per step. Steps are
## claimed in order; one that opens a mode, an arena or a hero gets a reveal.
## No class_name (over-the-air packs can't add global classes): preload it.

const DragScroll := preload("res://src/ui/drag_scroll.gd")

signal closed

const TRACK_X := 132.0
const CARD_X := 176.0
const STEP_H := 150.0
const BIG_H := 176.0
const ARENA_H := 262.0
const GAP := 16.0
const SKDB := preload("res://src/data/sidekick_db.gd")
const SKR := preload("res://src/autoload/sidekicks.gd")
const ZONE_ICON := {"barrow": "tombstone", "depths": "ghost", "grove": "wolf-head", "vault": "locked-chest"}
const MODE_ICON := {"horde": "skull-crossed-bones", "trial": "castle", "descent": "hourglass", "rush": "crowned-skull", "rift": "crystal-shine", "wild": "wolf-head"}
const GOLD := Color("e8b65a")
const EMBER := Color("d9622b")

## The trophies the track showed last time, so a reopen fills from there.
static var _last_seen := -1

var ui: Node
var _scroll: DragScroll
var _content: Control
var _items: Array = []
var _here: PanelContainer
var _here_label: Label
var _count_label: Label
var _next_label: Label
var _next_bar: ProgressBar
var _burst: CPUParticles2D
var _num_labels: Array = []
var _claim_btn: Button
var _shown := 0.0
var _time := 0.0


func open(u: Node) -> void:
	ui = u
	add_to_group("trophy_road")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_background()
	var root := MarginContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var ins := Ui.safe_insets(0)
	root.add_theme_constant_override("margin_top", int(ins.y) + 26)
	root.add_theme_constant_override("margin_bottom", int(ins.w))
	add_child(root)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	root.add_child(v)
	v.add_child(_header())
	_scroll = DragScroll.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	v.add_child(_scroll)
	_content = Control.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.draw.connect(_draw_track)
	_scroll.add_child(_content)
	_burst = _make_burst()
	add_child(_burst)
	# The track fills from where it stood last time (or the last step reached).
	var start := _last_seen if _last_seen >= 0 and _last_seen <= Game.renown() else DB.road_threshold(int(Game.data["road"]))
	_shown = float(mini(start, Game.renown()))
	_build.call_deferred(true)
	# Slide in.
	modulate.a = 0.0
	var t := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "modulate:a", 1.0, 0.22)
	Sfx.play("ui_press", -4.0)


func close() -> void:
	_last_seen = Game.renown()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	Sfx.play("ui_back", -4.0)
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.18)
	t.tween_callback(func():
		closed.emit()
		queue_free())


func _process(dt: float) -> void:
	_time += dt
	if _content:
		_content.queue_redraw()
	get_tree().call_group("road_rays", "queue_redraw")
	if _claim_btn and is_instance_valid(_claim_btn):
		_claim_btn.pivot_offset = _claim_btn.size * 0.5
		_claim_btn.scale = Vector2.ONE * (1.0 + 0.045 * sin(_time * 5.0))


# --- Frame -------------------------------------------------------------------

func _background() -> void:
	var bg := TextureRect.new()
	var g := Gradient.new()
	g.set_color(0, Color("1d1622"))
	g.set_color(1, Color("09080b"))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0.5, 0.0)
	gt.fill_to = Vector2(0.5, 1.0)
	bg.texture = gt
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	# Slow embers rising behind everything.
	var motes := CPUParticles2D.new()
	motes.amount = 40
	motes.lifetime = 9.0
	motes.preprocess = 9.0
	motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	var vp := get_viewport_rect().size
	motes.position = Vector2(vp.x * 0.5, vp.y + 20.0)
	motes.emission_rect_extents = Vector2(vp.x * 0.5, 10.0)
	motes.direction = Vector2(0, -1)
	motes.spread = 12.0
	motes.gravity = Vector2.ZERO
	motes.initial_velocity_min = 60.0
	motes.initial_velocity_max = 150.0
	motes.scale_amount_min = 2.0
	motes.scale_amount_max = 5.0
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.75, 0.35, 0.0))
	ramp.set_color(1, Color(1.0, 0.75, 0.35, 0.0))
	ramp.add_point(0.25, Color(1.0, 0.78, 0.4, 0.45))
	ramp.add_point(0.75, Color(1.0, 0.6, 0.3, 0.25))
	motes.color_ramp = ramp
	add_child(motes)


func _header() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	var m := MarginContainer.new()
	for side in ["margin_left", "margin_right"]:
		m.add_theme_constant_override(side, 24)
	m.add_child(box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var back := Button.new()
	back.theme_type_variation = &"RoundButton"
	back.text = "✕"
	back.custom_minimum_size = Vector2(68, 68)
	back.focus_mode = Control.FOCUS_NONE
	back.pressed.connect(close)
	row.add_child(back)
	var tl := Ui.label("Trophy Road", "Title")
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(tl)
	var chip := PanelContainer.new()
	chip.theme_type_variation = &"Chip"
	var ch := HBoxContainer.new()
	ch.add_theme_constant_override("separation", 8)
	ch.add_child(Ui.icon_rect("trophy", 40, GOLD))
	_count_label = Ui.label("0", "RoadNum")
	_count_label.add_theme_font_size_override("font_size", 34)
	ch.add_child(_count_label)
	chip.add_child(ch)
	row.add_child(chip)
	box.add_child(row)
	var nr := HBoxContainer.new()
	nr.add_theme_constant_override("separation", 14)
	_next_label = Ui.label("", "Small")
	_next_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nr.add_child(_next_label)
	box.add_child(nr)
	_next_bar = ProgressBar.new()
	_next_bar.show_percentage = false
	_next_bar.custom_minimum_size = Vector2(0, 14)
	box.add_child(_next_bar)
	return m


# --- Building the road ---------------------------------------------------------

## Lays out every row. `first` scrolls to the player and fills the track.
func _build(first := false) -> void:
	var keep := _scroll.scroll_vertical
	Ui.clear(_content)
	_items.clear()
	_num_labels.clear()
	_claim_btn = null
	var w := _content.size.x if _content.size.x > 0.0 else get_viewport_rect().size.x
	var y := 24.0
	var claimed := int(Game.data["road"])
	var ready_n := Game.road_claimable()
	var last := maxi(DB.TROPHY_ROAD.size() + 2, claimed + ready_n + 3)
	var arena_i := 0
	# Sidekicks that trophies earn sit on the road where they join.
	var marks := SKDB.road_marks()
	var mark_i := 0
	# Arena 1 and what a new save starts with.
	y = _add_arena(0, y, w)
	arena_i = 1
	y = _add_start(y, w, "visored-helm", "FIRST HERO", _start_hero_name(), "Your first pick")
	y = _add_start(y, w, MODE_ICON["horde"], "MODE", str(DB.MODES["horde"]["name"]), "Fill the soul meter, wake the boss")
	for n in range(1, last + 1):
		var t := DB.road_threshold(n)
		while arena_i < DB.ARENAS.size() and int(DB.ARENAS[arena_i]["t"]) <= t:
			y = _add_arena(arena_i, y, w)
			arena_i += 1
		y = _add_step(n, y, w, claimed, ready_n)
		while mark_i < marks.size() and int(marks[mark_i]["t"]) <= t:
			y = _add_sidekick(marks[mark_i], y, w)
			mark_i += 1
	_content.custom_minimum_size = Vector2(0, y + 80.0)
	_here = PanelContainer.new()
	_here.theme_type_variation = &"RoadHere"
	_here.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_here_label = Ui.label("", "RoadHereLabel", HORIZONTAL_ALIGNMENT_CENTER)
	_here.add_child(_here_label)
	_content.add_child(_here)
	_refresh_header()
	_set_shown(_shown)
	if first:
		await get_tree().process_frame
		var target := clampf(_y_for(float(Game.renown())) - _scroll.size.y * 0.45, 0.0, maxf(_content.size.y - _scroll.size.y, 0.0))
		_scroll._scroll_to(maxf(target - 260.0, 0.0))
		var t := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		t.tween_method(_scroll._scroll_to, maxf(target - 260.0, 0.0), target, 0.7)
		t.tween_method(_set_shown, _shown, float(Game.renown()), 1.1).set_delay(0.25)
		var i := 0
		for it in _items:
			var node: Control = it["node"]
			if absf(float(it["y"]) - target) < _scroll.size.y * 1.4:
				Ui.pop_in(node, 0.04 * i, 0.92)
				i += 1
	else:
		await get_tree().process_frame
		_scroll._scroll_to(keep)


func _start_hero_name() -> String:
	for h in DB.START_HEROES:
		if Game.hero(h)["unlocked"]:
			return str(DB.HEROES[h]["name"])
	return "Your choice"


func _add_arena(i: int, y: float, w: float) -> float:
	var a: Dictionary = DB.ARENAS[i]
	var zid := str(a["zone"])
	var z: Dictionary = DB.ZONES[zid]
	var open := Game.renown() >= int(a["t"]) or Game.zone_unlocked(zid)
	var p := PanelContainer.new()
	p.theme_type_variation = &"RoadArena"
	p.position = Vector2(20, y)
	p.size = Vector2(w - 40, ARENA_H)
	p.custom_minimum_size = p.size
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	var col: Color = a["color"]
	var well := CenterContainer.new()
	well.custom_minimum_size = Vector2(120, 120)
	well.add_child(Ui.icon_rect(ZONE_ICON.get(zid, "tombstone"), 104, col.lightened(0.35) if open else Color(0.45, 0.42, 0.4)))
	row.add_child(well)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 2)
	var tag := Ui.label("ARENA %d  ·  %s" % [i + 1, ("%d TROPHIES" % int(a["t"])) if int(a["t"]) > 0 else "START"], "RoadTag")
	tag.add_theme_color_override("font_color", col.lightened(0.45))
	v.add_child(tag)
	var nm := Ui.label(str(z["name"]), "Title")
	nm.add_theme_font_size_override("font_size", 42)
	if not open:
		nm.add_theme_color_override("font_color", Color(0.7, 0.66, 0.6))
	v.add_child(nm)
	var bl := Ui.label(str(z["blurb"]), "Small")
	bl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(bl)
	var boss := Ui.label(("Boss: %s" % str(DB.BOSSES[z["boss"]]["name"])) if open else "Opens at %d trophies" % int(a["t"]), "Caption")
	if not open:
		boss.add_theme_color_override("font_color", GOLD)
	v.add_child(boss)
	row.add_child(v)
	p.add_child(row)
	_content.add_child(p)
	_items.append({"kind": "arena", "y": y, "h": ARENA_H, "node": p, "color": col, "open": open})
	return y + ARENA_H + GAP * 2.0


## A sidekick milestone: no claim button; it joins after the next hunt
## past its trophies (Sidekicks.check_unlocks).
func _add_sidekick(m: Dictionary, y: float, w: float) -> float:
	var id := str(m["id"])
	var sd: Dictionary = SKDB.ROSTER[id]
	var t := int(m["t"])
	var owned := SKR.is_owned(Game.data, id)
	var reached := owned or Game.renown() >= t
	var sub := str(sd["desc"]) if reached else "Joins at %d trophies" % t
	var c := _card(y, w, BIG_H, "RoadDone" if owned else "RoadUnlock", str(sd["icon"]), "NEW SIDEKICK", str(sd["name"]), sub, reached)
	if owned:
		c.modulate.a = 0.8
		_add_check(c)
	elif not reached:
		var lk := Ui.icon_rect("padlock", 40, Color(0.55, 0.5, 0.45))
		lk.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		(c.get_child(0) as HBoxContainer).add_child(lk)
	_items.append({"kind": "step", "t": t, "y": y, "h": BIG_H, "node": c, "state": "done" if owned else ("reached" if reached else "locked"), "big": true})
	_num(t, y, BIG_H)
	return y + BIG_H + GAP


func _add_start(y: float, w: float, icon: String, tag: String, title: String, sub: String) -> float:
	var c := _card(y, w, STEP_H, "RoadDone", icon, tag, title, sub, true)
	c.modulate.a = 0.85
	_add_check(c)
	_items.append({"kind": "step", "t": 0, "y": y, "h": STEP_H, "node": c, "state": "done", "big": false})
	_num(0, y, STEP_H)
	return y + STEP_H + GAP


func _add_step(n: int, y: float, w: float, claimed: int, ready_n: int) -> float:
	var rw := DB.road_reward(n)
	var kind := str(rw["kind"])
	var big := not kind in ["gold", "chest", "shards"]
	var h := BIG_H if big else STEP_H
	var state := "done" if n <= claimed else ("ready" if n == claimed + 1 and ready_n > 0 else ("reached" if n <= claimed + ready_n else "locked"))
	var icon := "two-coins"
	var tag := "REWARD"
	var title := Game.road_reward_text(n)
	var sub := ""
	match kind:
		"chest":
			icon = "locked-chest" if state != "done" else "open-treasure-chest"
			sub = "Gold, shards and %d piece%s of gear" % [int(DB.CHESTS[rw["chest"]]["items"]), "" if int(DB.CHESTS[rw["chest"]]["items"]) == 1 else "s"]
		"shards":
			icon = "gems"
			sub = "For the hero you play"
		"mode":
			icon = MODE_ICON.get(str(rw["id"]), "crossed-swords")
			tag = "NEW MODE"
			sub = str(DB.MODES[rw["id"]]["blurb"])
		"zone":
			icon = ZONE_ICON.get(str(rw["id"]), "tombstone")
			tag = "NEW ARENA"
			sub = "Boss: %s" % str(DB.BOSSES[DB.ZONES[rw["id"]]["boss"]]["name"])
		"pick":
			icon = "visored-helm"
			tag = "NEW HERO"
			title = "Your pick"
			var names: Array = Game.road_pickable().map(func(x): return str(DB.HEROES[x]["name"]))
			sub = ("Pick %s" % " or ".join(PackedStringArray(names))) if not names.is_empty() and state != "done" else "Joined your band"
		"hero":
			icon = str(DB.HEROES[rw["id"]]["icon"])
			tag = "NEW HERO"
			sub = str(DB.HEROES[rw["id"]]["title"])
		"rift_key":
			icon = "crystal-shine"
			tag = "NEW MODE"
			title = "Rift"
			sub = "Your first rift key"
		"cards":
			icon = str(DB.CARDS[rw["ids"][0]]["icon"])
			tag = "NEW CARDS"
			sub = "They join your level-up draws"
		"egg":
			icon = "egg-clutch"
			tag = "NEW EGG"
			sub = "Warms in your hatchery"
	var style := "RoadReady" if state == "ready" else ("RoadDone" if state == "done" else ("RoadUnlock" if big else "RoadStep"))
	var c := _card(y, w, h, style, icon, tag, title, sub, state != "locked")
	if state == "done":
		c.modulate.a = 0.8
		_add_check(c)
	elif state == "ready":
		var b := Button.new()
		b.theme_type_variation = &"PrimaryButton"
		b.text = "Pick" if kind == "pick" else "Claim"
		b.custom_minimum_size = Vector2(136, 76)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(_claim.bind(n))
		(c.get_child(0) as HBoxContainer).add_child(b)
		_claim_btn = b
	elif state == "reached":
		var nx := Ui.label("NEXT", "RoadTag")
		nx.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		(c.get_child(0) as HBoxContainer).add_child(nx)
	else:
		var lk := Ui.icon_rect("padlock", 40, Color(0.55, 0.5, 0.45))
		lk.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		(c.get_child(0) as HBoxContainer).add_child(lk)
	_items.append({"kind": "step", "t": DB.road_threshold(n), "y": y, "h": h, "node": c, "state": state, "big": big})
	_num(DB.road_threshold(n), y, h)
	return y + h + GAP


## A step's card: an icon well, then tag, title and a line under it.
func _card(y: float, w: float, h: float, style: String, icon: String, tag: String, title: String, sub: String, lit: bool) -> PanelContainer:
	var c := PanelContainer.new()
	c.theme_type_variation = StringName(style)
	c.position = Vector2(CARD_X, y)
	c.size = Vector2(w - CARD_X - 24.0, h)
	c.custom_minimum_size = c.size
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var well := PanelContainer.new()
	well.theme_type_variation = &"Chip"
	well.custom_minimum_size = Vector2(88, 88)
	well.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var cc := CenterContainer.new()
	var tint := Color(1.0, 0.84, 0.5) if lit else Color(0.6, 0.56, 0.5)
	if style == "RoadStep" and lit:
		tint = Color(0.88, 0.82, 0.72)
	cc.add_child(Ui.icon_rect(icon, 56, tint))
	well.add_child(cc)
	row.add_child(well)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 0)
	var tl := Ui.label(tag, "RoadTag")
	if tag == "REWARD":
		tl.add_theme_color_override("font_color", Color(0.66, 0.6, 0.52))
	v.add_child(tl)
	var nm := Ui.label(title, "Value")
	nm.add_theme_font_size_override("font_size", 30 if style == "RoadUnlock" or style == "RoadReady" else 27)
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	v.add_child(nm)
	if sub != "":
		var sl := Ui.label(sub, "Small")
		sl.add_theme_font_size_override("font_size", 19)
		sl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sl.max_lines_visible = 2
		v.add_child(sl)
	row.add_child(v)
	c.add_child(row)
	_content.add_child(c)
	return c


func _add_check(c: PanelContainer) -> void:
	var ck := Ui.label("✓", "Value")
	ck.add_theme_color_override("font_color", Color(0.5, 0.9, 0.55))
	ck.add_theme_font_size_override("font_size", 38)
	ck.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	(c.get_child(0) as HBoxContainer).add_child(ck)


## The trophy count beside a step, left of the track.
func _num(t: int, y: float, h: float) -> void:
	var l := Ui.label(Ui.fmt_num(t), "RoadNum", HORIZONTAL_ALIGNMENT_RIGHT)
	l.position = Vector2(0, y + h * 0.5 - 20.0)
	l.size = Vector2(TRACK_X - 30.0, 40)
	if t > Game.renown():
		l.add_theme_color_override("font_color", Color(0.55, 0.5, 0.45))
	_content.add_child(l)
	_num_labels.append(l)


# --- The track ------------------------------------------------------------------

## The y on the track for a trophy count: between the dots of the steps around it.
func _y_for(v: float) -> float:
	var prev_t := 0.0
	var prev_y := -1.0
	for it in _items:
		if str(it["kind"]) != "step":
			continue
		var cy: float = float(it["y"]) + float(it["h"]) * 0.5
		var t: float = float(it["t"])
		if prev_y < 0.0:
			prev_y = cy
			prev_t = t
		if v <= t:
			if t <= prev_t:
				return cy
			return lerpf(prev_y, cy, (v - prev_t) / (t - prev_t))
		prev_t = t
		prev_y = cy
	return prev_y


func _set_shown(v: float) -> void:
	_shown = v
	if not is_instance_valid(_here) or _items.is_empty():
		return
	var fy := _y_for(v)
	_here_label.text = Ui.fmt_num(int(round(v)))
	_here.reset_size()
	_here.position = Vector2(TRACK_X - _here.size.x - 26.0, fy - _here.size.y * 0.5)
	_count_label.text = Ui.fmt_num(int(round(v)))
	for l in _num_labels:
		var lab: Label = l
		lab.visible = absf(lab.position.y + 20.0 - fy) > 34.0


func _draw_track() -> void:
	if _items.is_empty():
		return
	var w := _content.size.x
	# Arena bands: each arena's color washes the road behind its banner.
	for it in _items:
		if str(it["kind"]) != "arena":
			continue
		var col: Color = it["color"]
		var y0: float = float(it["y"]) - 90.0
		var y1: float = float(it["y"]) + float(it["h"]) + 90.0
		var mid: float = (y0 + y1) * 0.5
		var a := 0.28 if it["open"] else 0.12
		_content.draw_polygon(PackedVector2Array([Vector2(0, y0), Vector2(w, y0), Vector2(w, mid), Vector2(0, mid)]),
			PackedColorArray([Color(col, 0.0), Color(col, 0.0), Color(col, a), Color(col, a)]))
		_content.draw_polygon(PackedVector2Array([Vector2(0, mid), Vector2(w, mid), Vector2(w, y1), Vector2(0, y1)]),
			PackedColorArray([Color(col, a), Color(col, a), Color(col, 0.0), Color(col, 0.0)]))
	var first_y := _y_for(0.0)
	var last: Dictionary = _items[-1]
	var end_y: float = float(last["y"]) + float(last["h"]) * 0.5
	var fy := _y_for(_shown)
	var x := TRACK_X
	# The road ahead, then the road walked: a glow, the gold, a bright core.
	_content.draw_line(Vector2(x, first_y), Vector2(x, end_y + 60.0), Color(0.16, 0.13, 0.12), 14.0, true)
	_content.draw_line(Vector2(x, first_y), Vector2(x, end_y + 60.0), Color(1, 1, 1, 0.04), 4.0, true)
	if fy > first_y:
		_content.draw_line(Vector2(x, first_y), Vector2(x, fy), Color(GOLD, 0.16), 38.0, true)
		_content.draw_line(Vector2(x, first_y), Vector2(x, fy), GOLD, 14.0, true)
		_content.draw_line(Vector2(x, first_y), Vector2(x, fy), Color(1.0, 0.94, 0.75, 0.75), 4.0, true)
		# A shine runs down the walked road.
		var span := fy - first_y + 300.0
		var s := first_y - 150.0 + fmod(_time * 520.0, span)
		var a0 := maxf(s - 70.0, first_y)
		var a1 := minf(s + 70.0, fy)
		if a1 > a0:
			_content.draw_line(Vector2(x, a0), Vector2(x, a1), Color(1, 1, 1, 0.55), 10.0, true)
	# The dots.
	var pulse := fmod(_time * 1.3, 1.0)
	for it in _items:
		if str(it["kind"]) != "step":
			continue
		var cy: float = float(it["y"]) + float(it["h"]) * 0.5
		var r := 21.0 if it["big"] else 15.0
		var p := Vector2(x, cy)
		match str(it["state"]):
			"done", "reached":
				_content.draw_circle(p, r + 4.0, Color("2a1a06"))
				_content.draw_circle(p, r, GOLD)
				_content.draw_circle(p, r * 0.45, Color(1.0, 0.95, 0.8))
			"ready":
				_content.draw_circle(p, r + 6.0 + 22.0 * pulse, Color(EMBER, 0.5 * (1.0 - pulse)))
				_content.draw_circle(p, r + 4.0, Color("2a1206"))
				_content.draw_circle(p, r, EMBER.lightened(0.1))
				_content.draw_circle(p, r * 0.45, Color(1.0, 0.85, 0.6))
			_:
				_content.draw_circle(p, r + 4.0, Color("0d0c10"))
				_content.draw_circle(p, r, Color("221e26"))
				_content.draw_arc(p, r, 0.0, TAU, 32, Color(0.45, 0.4, 0.34), 3.0, true)
	# Where the player stands: a pulsing light on the track.
	var hp := 0.5 + 0.5 * sin(_time * 3.2)
	_content.draw_circle(Vector2(x, fy), 26.0 + 10.0 * hp, Color(GOLD, 0.18))
	_content.draw_circle(Vector2(x, fy), 13.0, Color(1.0, 0.96, 0.85))


# --- Header ------------------------------------------------------------------------

func _refresh_header() -> void:
	var nu := Game.road_next_unlock()
	if Game.road_claimable() > 0:
		_next_label.text = "A reward is ready to claim"
	elif nu > 0:
		_next_label.text = "Next: %s at %s  ·  %s to go" % [Game.road_reward_text(nu) if str(DB.road_reward(nu)["kind"]) != "pick" else "a new hero", Ui.fmt_num(DB.road_threshold(nu)), Ui.fmt_num(DB.road_threshold(nu) - Game.renown())]
	else:
		_next_label.text = "Every arena, mode and hero is open. Chests every %d." % DB.ROAD_EVERY
	_next_bar.value = Game.road_fill() * 100.0 if Game.road_claimable() == 0 else 100.0


# --- Claiming ------------------------------------------------------------------------

func _claim(n: int) -> void:
	var rw := DB.road_reward(n)
	if str(rw["kind"]) == "pick":
		_open_pick(n)
		return
	var lines := Game.claim_road()
	_celebrate(n, rw, lines)


func _celebrate(n: int, rw: Dictionary, lines: Array) -> void:
	var kind := str(rw["kind"])
	var at := _dot_global(n)
	_burst.global_position = at
	_burst.color = EMBER.lightened(0.3) if kind in ["gold", "shards", "chest"] else GOLD
	_burst.restart()
	Ui.buzz(30, 0.4)
	if kind in ["gold", "shards"]:
		Sfx.play("coin", 0.0)
		_float(lines[0] if not lines.is_empty() else "", at)
		_build()
		return
	Sfx.play("unlock_start" if kind != "chest" else "chest_open", 0.0)
	_build()
	_reveal(rw, lines)


## The dot of step n, in screen space.
func _dot_global(n: int) -> Vector2:
	var t := DB.road_threshold(n)
	for it in _items:
		if str(it["kind"]) == "step" and int(it["t"]) == t:
			return _content.global_position + Vector2(TRACK_X, float(it["y"]) + float(it["h"]) * 0.5)
	return get_viewport_rect().size * 0.5


func _float(text: String, at: Vector2) -> void:
	var l := Ui.label(text, "HudTitle", HORIZONTAL_ALIGNMENT_CENTER)
	l.add_theme_color_override("font_color", Color(1.0, 0.85, 0.45))
	add_child(l)
	l.size = Vector2(500, 60)
	l.position = at + Vector2(-60.0, -40.0)
	var t := l.create_tween().set_parallel(true)
	t.tween_property(l, "position:y", l.position.y - 140.0, 1.1).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(l, "modulate:a", 0.0, 0.5).set_delay(0.6)
	t.chain().tween_callback(l.queue_free)


func _make_burst() -> CPUParticles2D:
	var b := CPUParticles2D.new()
	b.emitting = false
	b.one_shot = true
	b.explosiveness = 1.0
	b.amount = 48
	b.lifetime = 0.9
	b.spread = 180.0
	b.gravity = Vector2(0, 500)
	b.initial_velocity_min = 260.0
	b.initial_velocity_max = 620.0
	b.scale_amount_min = 4.0
	b.scale_amount_max = 9.0
	b.damping_min = 120.0
	b.damping_max = 220.0
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 1))
	ramp.set_color(1, Color(1, 1, 1, 0))
	b.color_ramp = ramp
	b.z_index = 10
	return b


# --- Reveal and hero pick ------------------------------------------------------------

## A full-screen card for something new: rays, the icon, its name.
func _reveal(rw: Dictionary, lines: Array) -> void:
	var kind := str(rw["kind"])
	var icon := "locked-chest"
	var tag := "REWARD"
	var title := ""
	var sub := ""
	match kind:
		"mode":
			icon = MODE_ICON.get(str(rw["id"]), "crossed-swords")
			tag = "NEW MODE UNLOCKED"
			title = str(DB.MODES[rw["id"]]["name"])
			sub = str(DB.MODES[rw["id"]]["blurb"])
		"zone":
			icon = ZONE_ICON.get(str(rw["id"]), "tombstone")
			tag = "NEW ARENA UNLOCKED"
			title = str(DB.ZONES[rw["id"]]["name"])
			sub = str(DB.ZONES[rw["id"]]["blurb"])
		"rift_key":
			icon = "crystal-shine"
			tag = "NEW MODE UNLOCKED"
			title = "Rift"
			sub = str(DB.MODES["rift"]["blurb"])
		"cards":
			icon = str(DB.CARDS[rw["ids"][0]]["icon"])
			tag = "NEW CARDS UNLOCKED"
			title = Game.road_reward_text(int(DB.TROPHY_ROAD.find(rw)) + 1).trim_prefix("New cards: ")
			sub = "They join your level-up draws"
		"hero", "pick":
			var hid := str(rw.get("id", ""))
			for l in lines:
				for h in DB.HERO_ORDER:
					if str(l).begins_with(str(DB.HEROES[h]["name"]) + " joins"):
						hid = h
			if hid != "":
				icon = str(DB.HEROES[hid]["icon"])
				title = str(DB.HEROES[hid]["name"])
				sub = "%s · %s" % [DB.HEROES[hid]["title"], DB.HEROES[hid]["blurb"]]
			tag = "NEW HERO"
		"egg":
			icon = "egg-clutch"
			tag = "NEW EGG"
			title = str(preload("res://src/data/sidekick_db.gd").EGGS[rw["egg"]]["name"])
			sub = "\n".join(PackedStringArray(lines.map(func(x): return str(x))))
		"chest":
			icon = "open-treasure-chest"
			title = str(DB.CHESTS[rw["chest"]]["name"])
			sub = "\n".join(PackedStringArray(lines.map(func(x): return str(x))))
	var ov := _modal()
	var v: VBoxContainer = ov.get_meta("box")
	var rays := Control.new()
	rays.custom_minimum_size = Vector2(440, 400)
	rays.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rays.draw.connect(func():
		var c := rays.size * 0.5
		for i in 12:
			var a := _time * 0.35 + TAU * i / 12.0
			rays.draw_colored_polygon(PackedVector2Array([c, c + Vector2.from_angle(a - 0.1) * 210.0, c + Vector2.from_angle(a + 0.1) * 210.0]), Color(GOLD, 0.13))
		rays.draw_circle(c, 120.0, Color(GOLD, 0.1))
		rays.draw_circle(c, 84.0, Color(0.1, 0.08, 0.06, 0.9)))
	rays.add_to_group("road_rays")
	var ic := Ui.icon_rect(icon, 128, Color(1.0, 0.86, 0.5))
	ic.position = Vector2(156, 136)
	rays.add_child(ic)
	var rc := CenterContainer.new()
	rc.add_child(rays)
	v.add_child(rc)
	v.add_child(Ui.label(tag, "RoadTag", HORIZONTAL_ALIGNMENT_CENTER))
	var tl := Ui.label(title, "Title", HORIZONTAL_ALIGNMENT_CENTER)
	tl.add_theme_font_size_override("font_size", 56)
	v.add_child(tl)
	if sub != "":
		var sl := Ui.label(sub, "Body", HORIZONTAL_ALIGNMENT_CENTER)
		sl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sl.custom_minimum_size = Vector2(560, 0)
		v.add_child(sl)
	var ok := Button.new()
	ok.theme_type_variation = &"GoldButton"
	ok.text = "Continue"
	ok.custom_minimum_size = Vector2(320, 88)
	ok.focus_mode = Control.FOCUS_NONE
	ok.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ok.pressed.connect(func():
		Sfx.play("ui_press", -2.0)
		var t := ov.create_tween()
		t.tween_property(ov, "modulate:a", 0.0, 0.18)
		t.tween_callback(ov.queue_free))
	v.add_child(ok)
	Sfx.play("rare_chime", -2.0)
	Ui.pop_in(v, 0.05, 0.6)


## A dimmed full-screen layer with a centered column (meta "box").
func _modal() -> Control:
	var ov := Control.new()
	ov.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ov.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.015, 0.03, 0.94)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ov.add_child(dim)
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ov.add_child(cc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	cc.add_child(v)
	ov.set_meta("box", v)
	add_child(ov)
	ov.modulate.a = 0.0
	ov.create_tween().tween_property(ov, "modulate:a", 1.0, 0.2)
	return ov


func _open_pick(n: int) -> void:
	var ov := _modal()
	var v: VBoxContainer = ov.get_meta("box")
	v.add_child(Ui.label("NEW HERO", "RoadTag", HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(Ui.label("Choose who joins", "Title", HORIZONTAL_ALIGNMENT_CENTER))
	for hid in Game.road_pickable():
		var id: String = hid
		v.add_child(hero_choice(id, func():
			ov.queue_free()
			var lines := Game.claim_road(id)
			_celebrate(n, DB.road_reward(n), lines)))
	var later := Button.new()
	later.theme_type_variation = &"Ghost"
	later.text = "Not now"
	later.focus_mode = Control.FOCUS_NONE
	later.pressed.connect(ov.queue_free)
	v.add_child(later)
	Ui.pop_in(v, 0.0, 0.8)
	Sfx.play("card_flip", -2.0)


## A big tappable card for one hero: portrait (or icon), name, role, blurb.
static func hero_choice(id: String, on_pick: Callable) -> Button:
	var d: Dictionary = DB.HEROES[id]
	var b := Button.new()
	b.theme_type_variation = &"CardButton"
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(620, 176)
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 20
	row.offset_right = -20
	row.add_theme_constant_override("separation", 20)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var col: Color = d["color"]
	var pic := PanelContainer.new()
	pic.theme_type_variation = &"Chip"
	pic.custom_minimum_size = Vector2(136, 136)
	pic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tex := Portraits.tex(id)
	if tex:
		var tr := TextureRect.new()
		tr.texture = tex
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pic.add_child(tr)
	else:
		var cc := CenterContainer.new()
		cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cc.add_child(Ui.icon_rect(str(d["icon"]), 84, col.lightened(0.3)))
		pic.add_child(cc)
	row.add_child(pic)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tg := Ui.label(str(d["role"]).to_upper(), "RoadTag")
	tg.add_theme_color_override("font_color", col.lightened(0.35))
	v.add_child(tg)
	var nm := Ui.label(str(d["name"]), "Title")
	nm.add_theme_font_size_override("font_size", 40)
	v.add_child(nm)
	var bl := Ui.label(str(d["blurb"]), "Small")
	bl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(bl)
	row.add_child(v)
	b.add_child(row)
	b.pressed.connect(func():
		Sfx.play("card_pick", 0.0)
		on_pick.call())
	return b
