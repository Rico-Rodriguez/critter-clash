class_name LobbyUI
extends CanvasLayer
## The camp's interface: top bar, hero switcher, difficulty, the big button,
## and the sheets (Heroes, Bag, Skills, Log, Settings).

var lobby: Node3D
var chest_opening := false
var _shown_hero := ""
var _sheet: Sheet
var _sheet_name := ""
var equipment: Equipment
var _road_note: Array = []
## The side column (daily, campfire, season, feats) and its badges.
var _side: VBoxContainer
var _side_badges := {}
var _idle_label: Label
var _goal: Label
var _note_lines: Array = []


func setup(l: Node3D) -> void:
	lobby = l
	Ui.apply_safe_area(%Safe)
	_shown_hero = Game.hero_id()
	Game.refresh_bounties()
	%Prev.pressed.connect(func(): _cycle(-1))
	%Next.pressed.connect(func(): _cycle(1))
	%Hunt.pressed.connect(_on_hunt)
	%Settings.icon = Ui.icon("cog")
	%Settings.pressed.connect(func(): open_sheet("settings"))
	%Chest.pressed.connect(_open_chest)
	%Chest.icon = Ui.icon("locked-chest")
	# The profile chip opens the skills sheet.
	%CombatChip.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			Sfx.play("ui_tap", -4.0)
			open_sheet("skills"))
	for pair in [[%NavHeroes, "heroes", "visored-helm"], [%NavBag, "bag", "swap-bag"], [%NavSkills, "skills", "upgrade"], [%NavLog, "log", "scroll-unfurled"]]:
		var b: Button = pair[0]
		b.icon = Ui.icon(pair[2])
		var sheet_name: String = pair[1]
		b.pressed.connect(func(): open_sheet(sheet_name))
	%Road.pressed.connect(func(): open_sheet("road"))
	%Bounties.icon = Ui.icon("archery-target")
	%Bounties.pressed.connect(func(): open_sheet("bounties"))
	# Mode, place and difficulty change rarely, so the camp shows one summary
	# card and the choices live in a sheet behind it.
	%Expedition.pressed.connect(func(): open_sheet("expedition"))
	%CombatIcon.texture = Ui.icon("crossed-swords")
	%GoldIcon.texture = Ui.icon("two-coins")
	%Chest.visible = false
	_build_side()
	_goal = Ui.label("", "Small", HORIZONTAL_ALIGNMENT_CENTER)
	_goal.add_theme_color_override("font_color", Color(0.95, 0.85, 0.6))
	%HeroBox.add_child(_goal)
	Game.changed.connect(refresh)
	refresh()
	_count_gold_in()


const MODE_ICON := {"horde": "skull-crossed-bones", "trial": "castle", "descent": "hourglass", "rush": "crowned-skull", "rift": "crystal-shine", "wild": "wolf-head"}


func refresh() -> void:
	%Gold.text = Ui.fmt_num(Game.gold())
	%Combat.text = "Combat %d" % Game.combat_level()
	var id := _shown_hero
	var d: Dictionary = DB.HEROES[id]
	var h := Game.hero(id)
	%HeroName.text = d["name"]
	%HeroTitle.text = "%s · %s · %s" % [Game.mastery_title(id), d["title"], d["role"]]
	%HeroLevel.text = "Lv %d" % int(h["level"])
	%Power.text = "Power %d · Rating %d" % [Game.power_score(id), int(h.get("rating", 0))]
	var locked := not bool(h["unlocked"])
	%Hunt.disabled = locked
	%Lock.visible = locked
	if locked:
		%Hunt.text = "Locked"
		%Lock.text = "Clear Veteran, or gather 20 shards (%d/20)" % int(h["shards"]) if d["unlock"] == "veteran" else "Gather 20 shards (%d/20)" % int(h["shards"])
	else:
		%Hunt.text = {"horde": DB.zone(Game.zone_id())["enter"], "trial": "Take the Long Road", "descent": "Begin the Descent", "rush": "Start the Rush", "rift": "Open the Rift", "wild": "Enter the Wilderness"}[Game.mode_id()]
	var mode: Dictionary = DB.MODES[Game.mode_id()]
	var t: Dictionary = DB.TIERS[Game.tier()]
	%ExpIcon.texture = Ui.icon(MODE_ICON.get(Game.mode_id(), "crossed-swords"))
	%ExpMode.text = str(mode["name"]).to_upper()
	%ExpPlace.text = DB.zone(Game.zone_id())["name"]
	# Recommended power: a loss under it reads as "I need gear", not "unfair".
	var pw := Game.power_score(id)
	var rec := int(t["power"])
	%ExpTier.text = str(t["name"]).to_upper() + (" · OMEN" if not Game.active_omen(Game.mode_id()).is_empty() else "") + " · POWER %s / %s" % [Ui.fmt_num(pw), Ui.fmt_num(rec)]
	%ExpTier.add_theme_color_override("font_color", t["color"] if pw >= rec else Color(1.0, 0.45, 0.4))
	%NavHeroes.get_node("Dot").visible = _any_upgrade()
	%NavBag.get_node("Dot").visible = Game.new_item_count() > 0
	var list: Array = Game.data["bounties"]["list"]
	var done := list.filter(func(e): return Game.bounty_done(e)).size()
	var ready_n := Game.bounty_claimable()
	%BountyBadge.visible = ready_n > 0
	%BountyCount.text = str(ready_n)
	var steps := Game.road_claimable()
	var nxt := int(Game.data["road"]) + 1
	if steps > 0:
		%RoadText.text = "READY: %s" % Game.road_reward_text(nxt).to_upper()
	else:
		# Numbers, so an empty bar on a new save reads as "0 of 60", not broken.
		%RoadText.text = "ROAD %d / %d · NEXT: %s" % [Game.renown(), DB.road_threshold(nxt), Game.road_reward_text(nxt).to_upper()]
	%RoadBar.value = 100.0 if steps > 0 else maxf(Game.road_fill() * 100.0, 3.0)
	%RoadBadge.visible = steps > 0
	if _goal:
		# The closest thing worth chasing: something is always about to happen.
		_goal.text = Game.next_goal()
		_goal.visible = _goal.text != ""
	_refresh_side()


## Back from a hunt: the gold on the top bar ticks up from what it was.
func _count_gold_in() -> void:
	var m = lobby.main
	if m == null or int(m.gold_seen) < 0 or int(m.gold_seen) >= Game.gold():
		return
	var from := int(m.gold_seen)
	m.gold_seen = -1
	var to := Game.gold()
	var t := create_tween()
	t.tween_interval(0.6)
	t.tween_method(func(v: float):
		%Gold.text = Ui.fmt_num(int(v))
		if randf() < 0.3:
			Sfx.play("coin", -14.0, 1.2), float(from), float(to), 1.1)
	%Gold.text = Ui.fmt_num(from)


# --- Side column: daily, campfire, season, feats ---------------------------

func _build_side() -> void:
	_side = VBoxContainer.new()
	_side.add_theme_constant_override("separation", 12)
	_side.position = Vector2(0, 14)
	%Space.add_child(_side)
	for spec in [["daily", "sun", "Daily"], ["idle", "campfire", "Campfire"], ["season", "round-star", "Season"], ["feats", "trophy", "Feats"]]:
		var key: String = spec[0]
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 0)
		var b := Button.new()
		b.theme_type_variation = &"RoundButton"
		b.custom_minimum_size = Vector2(72, 72)
		b.icon = Ui.icon(spec[1])
		b.expand_icon = true
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(func(): _side_pressed(key))
		var badge := PanelContainer.new()
		badge.theme_type_variation = &"Badge"
		badge.custom_minimum_size = Vector2(22, 22)
		badge.position = Vector2(52, -4)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.visible = false
		b.add_child(badge)
		_side_badges[key] = badge
		col.add_child(b)
		var l := Ui.label(spec[2], "Caption", HORIZONTAL_ALIGNMENT_CENTER)
		l.add_theme_font_size_override("font_size", 14)
		col.add_child(l)
		if key == "idle":
			_idle_label = l
		_side.add_child(col)


func _refresh_side() -> void:
	if _side == null:
		return
	var login := Game.login_status()
	_side_badges["daily"].visible = bool(login["ready"])
	var g := Game.idle_gold()
	_side_badges["idle"].visible = g >= 50
	_idle_label.text = "+%d" % g if g >= 50 else "Campfire"
	_side_badges["season"].visible = Game.season_claimable() > 0
	_side_badges["feats"].visible = Game.achievement_claimable() > 0


func _side_pressed(key: String) -> void:
	Sfx.play("ui_tap", -4.0)
	match key:
		"idle":
			var rate := DB.IDLE_GOLD_HOUR + DB.IDLE_GOLD_TIER * int(Game.data["tier_unlocked"])
			var g := Game.claim_idle()
			if g > 0:
				Sfx.play("coin", 0.0)
				Ui.pop_in(%GoldChip, 0.0, 1.2)
				_float_text(_idle_label, "+%d gold" % g, Color(1.0, 0.85, 0.4))
			else:
				_float_text(_idle_label, "%d gold an hour" % rate, Color(0.85, 0.8, 0.7))
			refresh()
		"daily":
			open_sheet("daily")
		"season":
			open_sheet("season")
		"feats":
			open_sheet("feats")


## A short line that rises off a control and fades: feedback for a tap.
func _float_text(over: Control, text: String, color: Color) -> void:
	var l := Ui.label(text, "HudLabel")
	l.add_theme_font_size_override("font_size", 24)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	l.global_position = over.global_position + Vector2(over.size.x + 8.0, -over.size.y * 2.0)
	var t := l.create_tween().set_parallel(true)
	t.tween_property(l, "position:y", l.position.y - 40.0, 1.2).set_ease(Tween.EASE_OUT)
	t.tween_property(l, "modulate:a", 0.0, 1.2).set_delay(0.5)
	t.chain().tween_callback(l.queue_free)


func _build_daily(s: Sheet) -> void:
	var b := s.body
	var st := Game.login_status()
	b.add_child(_row([Ui.label("Login streak", "Heading"), _spacer(), Ui.label("Miss a day and it starts over", "Small")]))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	var day := int(st["day"])
	for i in DB.LOGIN_REWARDS.size():
		var rw: Dictionary = DB.LOGIN_REWARDS[i]
		var c := _card()
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 2)
		v.add_child(Ui.label("Day %d" % (i + 1), "Caption", HORIZONTAL_ALIGNMENT_CENTER))
		var ic := "two-coins" if rw.has("gold") else ("gems" if rw.has("shards") else "locked-chest")
		var claimed: bool = i + 1 < day or (i + 1 == day and not st["ready"])
		var today: bool = i + 1 == day and st["ready"]
		var col := Color(1.0, 0.85, 0.4) if today else (Color(0.5, 0.9, 0.55) if claimed else Color(0.7, 0.66, 0.6))
		var cc := CenterContainer.new()
		cc.add_child(Ui.icon_rect(ic, 44, col))
		v.add_child(cc)
		var t: String = ("%d gold" % int(rw["gold"])) if rw.has("gold") else (("%d shards" % int(rw["shards"])) if rw.has("shards") else DB.CHESTS[rw["chest"]]["name"])
		var tl := Ui.label(("✓ " if claimed else "") + t, "Small", HORIZONTAL_ALIGNMENT_CENTER)
		tl.add_theme_font_size_override("font_size", 15)
		tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(tl)
		c.add_child(v)
		grid.add_child(c)
	b.add_child(grid)
	if st["ready"]:
		var cb := Button.new()
		cb.theme_type_variation = &"GoldButton"
		cb.text = "Claim day %d" % day
		cb.custom_minimum_size = Vector2(0, 84)
		cb.focus_mode = Control.FOCUS_NONE
		cb.pressed.connect(func():
			var rw := Game.claim_login()
			Sfx.play("coin", 0.0)
			if rw.has("chest") and lobby.main:
				if lobby.main.pending_chest == "":
					lobby.main.pending_chest = str(rw["chest"])
					lobby.place_chest(lobby.main.pending_chest)
				else:
					lobby.main.chest_queue.append(str(rw["chest"]))
			refresh()
			s.rebuild())
		b.add_child(cb)
	var fw := _card()
	var fl := Ui.label("First win of the day: %s" % ("ready. Double gold and a better chest." if Game.first_win_ready() else "claimed. Back tomorrow."), "Body")
	fl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.45) if Game.first_win_ready() else Color(0.6, 0.6, 0.6))
	fw.add_child(fl)
	b.add_child(fw)
	var idle := _card()
	var il := Ui.label("The campfire gathers %d gold an hour while you are away, up to %d hours." % [DB.IDLE_GOLD_HOUR + DB.IDLE_GOLD_TIER * int(Game.data["tier_unlocked"]), int(DB.IDLE_HOURS)], "Small")
	il.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	idle.add_child(il)
	b.add_child(idle)


func _build_season(s: Sheet) -> void:
	var b := s.body
	var lv := Game.season_level()
	var se := Game.season()
	b.add_child(_row([Ui.label(Game.season_name(), "Heading"), _spacer(), Ui.label("%d days left" % Game.season_days_left(), "Small")]))
	var pb := ProgressBar.new()
	pb.theme_type_variation = &"XPBar"
	pb.show_percentage = false
	pb.custom_minimum_size = Vector2(0, 14)
	pb.value = 100.0 if lv >= DB.SEASON_TIERS else float(int(se["xp"]) % DB.SEASON_XP) / DB.SEASON_XP * 100.0
	b.add_child(pb)
	var note := Ui.label("Tier %d of %d · every hunt's renown counts · free for everyone" % [lv, DB.SEASON_TIERS], "Small")
	b.add_child(note)
	var claimed := int(se["claimed"])
	for n in range(maxi(claimed - 1, 1), mini(claimed + 9, DB.SEASON_TIERS) + 1):
		var rw := DB.season_reward(n)
		var c := _card()
		var row := _row([], 14)
		var num := Ui.label("%d" % n, "Value")
		num.custom_minimum_size = Vector2(54, 0)
		num.add_theme_font_size_override("font_size", 28)
		row.add_child(num)
		var t := ""
		match str(rw["kind"]):
			"gold": t = "%d gold" % int(rw["amount"])
			"shards": t = "%d shards" % int(rw["amount"])
			"chest": t = DB.CHESTS[rw["chest"]]["name"]
			"glow": t = "%s weapon glow for every hero" % DB.GLOWS[rw["glow"]]["name"]
		var tl := Ui.label(("✓ " if n <= claimed else "") + t, "Body")
		tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(tl)
		if n == claimed + 1 and n <= lv:
			var cb := Button.new()
			cb.text = "Claim"
			cb.theme_type_variation = &"GoldButton"
			cb.focus_mode = Control.FOCUS_NONE
			cb.pressed.connect(func():
				Game.claim_season()
				Sfx.play("coin", 0.0)
				refresh()
				s.rebuild())
			row.add_child(cb)
		elif n > lv:
			c.modulate = Color(1, 1, 1, 0.55)
		c.add_child(row)
		b.add_child(c)


func _build_feats(s: Sheet) -> void:
	var b := s.body
	var done: int = Game.data["achievements"].size()
	b.add_child(_row([Ui.label("Feats %d / %d" % [done, DB.ACHIEVEMENTS.size()], "Heading"), _spacer()]))
	for a: Dictionary in DB.ACHIEVEMENTS:
		var claimed: bool = Game.data["achievements"].has(a["id"])
		var ready_a := Game.achievement_done(a) and not claimed
		var c := _card()
		var row := _row([Ui.icon_rect("trophy", 40, Color(1.0, 0.82, 0.35) if claimed or ready_a else Color(0.45, 0.43, 0.4))], 12)
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_theme_constant_override("separation", 0)
		v.add_child(Ui.label(str(a["name"]), "Body"))
		var have := mini(Game.achievement_value(str(a["stat"])), int(a["n"]))
		v.add_child(Ui.label("%s · %s / %s" % [a["desc"], Ui.fmt_num(have), Ui.fmt_num(int(a["n"]))], "Small"))
		row.add_child(v)
		if ready_a:
			var cb := Button.new()
			cb.text = "+%d" % int(a["gold"])
			cb.icon = Ui.icon("two-coins")
			cb.theme_type_variation = &"GoldButton"
			cb.focus_mode = Control.FOCUS_NONE
			var aid: String = a["id"]
			cb.pressed.connect(func():
				Game.claim_achievement(aid)
				Sfx.play("coin", 0.0)
				refresh()
				s.rebuild())
			row.add_child(cb)
		elif claimed:
			row.add_child(Ui.label("✓", "Value"))
		else:
			c.modulate = Color(1, 1, 1, 0.7)
		c.add_child(row)
		b.add_child(c)


## True while nothing sits over the camp (taps on the hero open the roster).
func camp_idle() -> bool:
	return %Safe.visible and not chest_opening and (_sheet == null or not is_instance_valid(_sheet)) and (equipment == null or not is_instance_valid(equipment))


func _any_upgrade() -> bool:
	for id in DB.HERO_ORDER:
		if Game.can_upgrade(id):
			return true
	return false


func _cycle(dir: int) -> void:
	var i := DB.HERO_ORDER.find(_shown_hero)
	i = posmod(i + dir, DB.HERO_ORDER.size())
	_shown_hero = DB.HERO_ORDER[i]
	if Game.hero(_shown_hero)["unlocked"]:
		Game.set_hero(_shown_hero)
	lobby.show_hero(_shown_hero)
	Sfx.play("ui_toggle", -4.0)
	refresh()
	Ui.pop_in(%HeroBox, 0.0, 0.95)


func _on_hunt() -> void:
	if not Game.hero(_shown_hero)["unlocked"]:
		return
	Game.set_hero(_shown_hero)
	Sfx.play("ui_press", 0.0)
	lobby.start_hunt()


# --- Chest ---------------------------------------------------------------

func show_chest(kind: String) -> void:
	var c: Dictionary = DB.CHESTS[kind]
	%Chest.visible = true
	%Chest.tooltip_text = "Open your %s" % c["name"]
	%Chest.icon = Ui.icon("locked-chest")
	%Chest.self_modulate = c["color"] if c.has("color") else Color(1, 0.85, 0.5)
	Ui.pop_in(%Chest, 0.4, 0.6)
	# A slow pulse so the rail slot reads as "something is waiting".
	var pulse := %Chest.create_tween().set_loops()
	%Chest.pivot_offset = %Chest.custom_minimum_size * 0.5
	pulse.tween_property(%Chest, "scale", Vector2.ONE * 1.08, 0.7).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(%Chest, "scale", Vector2.ONE, 0.7).set_trans(Tween.TRANS_SINE)


func _open_chest() -> void:
	if chest_opening or lobby.main == null:
		return
	var kind: String = lobby.main.pending_chest
	if kind == "":
		return
	chest_opening = true
	%Chest.visible = false
	%Safe.visible = false
	var ov := preload("res://src/lobby/chest_open.gd").new()
	%Overlay.add_child(ov)
	ov.open(self, kind)


func chest_done() -> void:
	chest_opening = false
	%Safe.visible = true
	lobby.remove_chest()
	refresh()


# --- Sheets --------------------------------------------------------------

## The equipment screen takes over the camp: the 3D hero stays visible in the
## middle with the slots around them.
func open_equipment() -> void:
	%Safe.visible = false
	var eq := Equipment.new()
	equipment = eq
	%Overlay.add_child(eq)
	eq.open(self)
	eq.closed.connect(func():
		%Safe.visible = true
		refresh())


func open_sheet(name_: String) -> void:
	if _sheet and is_instance_valid(_sheet):
		_sheet.queue_free()
	if name_ == "chest":
		_open_chest()
		return
	_sheet = Sheet.new()
	_sheet_name = name_
	%Overlay.add_child(_sheet)
	match name_:
		"heroes":
			_sheet.open("Heroes", _build_heroes)
		"bag":
			_sheet.queue_free()
			open_equipment()
			return
		"skills":
			_sheet.open("Skills", _build_skills)
		"talents":
			_sheet.open("Talents", _build_talents)
		"road":
			_sheet.open("Renown Road", _build_road)
		"log":
			_sheet.open("Collection Log", _build_log)
		"bounties":
			_sheet.open("Daily Bounties", _build_bounties)
		"expedition":
			_sheet.open("Expedition", _build_expedition)
		"daily":
			_sheet.open("Daily", _build_daily)
		"season":
			_sheet.open("Season", _build_season)
		"feats":
			_sheet.open("Feats", _build_feats)
		"settings":
			_sheet.open("Settings", _build_settings, 0.7)
	_sheet.closed.connect(refresh)


## The portraits finished rendering after the Heroes sheet was already opened.
func portraits_ready() -> void:
	if _sheet and is_instance_valid(_sheet) and _sheet_name == "heroes":
		_sheet.rebuild()


func _card() -> PanelContainer:
	var c := PanelContainer.new()
	c.theme_type_variation = "Card"
	return c


func _row(children: Array, sep := 12) -> HBoxContainer:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", sep)
	for c in children:
		r.add_child(c)
	return r


func _spacer() -> Control:
	var s := Control.new()
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return s


func _disc(icon: String, col: Color, size_: float) -> Panel:
	var p := Panel.new()
	p.custom_minimum_size = Vector2(size_, size_)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var st := StyleBoxFlat.new()
	st.bg_color = col.darkened(0.55)
	st.set_corner_radius_all(int(size_ * 0.5))
	st.set_border_width_all(3)
	st.border_color = col
	st.anti_aliasing = true
	p.add_theme_stylebox_override("panel", st)
	var ic := Ui.icon_rect(icon, size_ * 0.6, col.lightened(0.4))
	ic.position = Vector2(size_ * 0.2, size_ * 0.2)
	p.add_child(ic)
	return p


## A hero's portrait in a rounded frame; the flat icon disc until it is rendered.
func _portrait(id: String, col: Color, size_: float) -> Control:
	var t := Portraits.tex(id)
	if t == null:
		return _disc(DB.HEROES[id]["icon"], col, size_)
	var p := Panel.new()
	p.custom_minimum_size = Vector2(size_, size_)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var st := StyleBoxFlat.new()
	st.bg_color = col.darkened(0.7)
	st.set_corner_radius_all(int(size_ * 0.5))
	st.set_border_width_all(3)
	st.border_color = col
	st.anti_aliasing = true
	p.add_theme_stylebox_override("panel", st)
	p.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	var tr := TextureRect.new()
	tr.texture = t
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(tr)
	return p


func _build_heroes(s: Sheet) -> void:
	var b := s.body
	var roster := HBoxContainer.new()
	roster.add_theme_constant_override("separation", 10)
	for id in DB.HERO_ORDER:
		var d: Dictionary = DB.HEROES[id]
		var h := Game.hero(id)
		var t := Button.new()
		t.toggle_mode = true
		t.button_pressed = id == _shown_hero
		t.custom_minimum_size = Vector2(0, 184)
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		t.focus_mode = Control.FOCUS_NONE
		var v := VBoxContainer.new()
		v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		v.offset_top = 14
		v.alignment = BoxContainer.ALIGNMENT_BEGIN
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var cc := CenterContainer.new()
		cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var pc := _portrait(id, d["color"] if h["unlocked"] else Color(0.4, 0.4, 0.42), 88)
		if not h["unlocked"]:
			pc.modulate = Color(0.35, 0.35, 0.4)
		cc.add_child(pc)
		v.add_child(cc)
		var nm := Ui.label(d["name"], "Body", HORIZONTAL_ALIGNMENT_CENTER)
		nm.add_theme_font_size_override("font_size", 21)
		v.add_child(nm)
		v.add_child(Ui.label(("Lv %d" % int(h["level"])) if h["unlocked"] else "Locked", "Small", HORIZONTAL_ALIGNMENT_CENTER))
		t.add_child(v)
		var hid: String = id
		t.pressed.connect(func():
			_shown_hero = hid
			if Game.hero(hid)["unlocked"]:
				Game.set_hero(hid)
			lobby.show_hero(hid)
			refresh()
			s.rebuild())
		if Game.can_upgrade(id):
			var dot := PanelContainer.new()
			dot.theme_type_variation = &"Badge"
			dot.custom_minimum_size = Vector2(20, 20)
			dot.size = Vector2(20, 20)
			dot.position = Vector2(8, 8)
			dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
			t.add_child(dot)
		roster.add_child(t)
	b.add_child(roster)
	var id2 := _shown_hero
	var d2: Dictionary = DB.HEROES[id2]
	var h2 := Game.hero(id2)
	var st := Game.hero_stats(id2)
	# Identity.
	var head := VBoxContainer.new()
	head.add_theme_constant_override("separation", 2)
	var nm2 := Ui.label("%s — %s" % [d2["name"], d2["title"]], "Heading")
	nm2.add_theme_color_override("font_color", d2["color"].lightened(0.3))
	head.add_child(nm2)
	var bl := Ui.label(d2["blurb"], "Body")
	bl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	head.add_child(bl)
	b.add_child(head)
	# Stats.
	var card := _card()
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	for pair in [
		["Health", "%d" % int(st["hp"]), "heart-organ"], ["Damage", "%d" % int(st["dmg"]), "sword-wound"],
		["Attacks / sec", "%.2f" % st["rate"], "lightning-tear"], ["Move speed", "%.1f" % st["speed"], "running-shoe"],
		["Critical", "%d%%" % int(st["crit"] * 100.0), "bullseye"], ["Armor", "%d%%" % int(DB.armor_dr(st["armor"]) * 100.0), "checked-shield"],
	]:
		var r := _row([Ui.icon_rect(pair[2], 26, Color(0.85, 0.72, 0.48)), Ui.label(pair[0], "Small")], 8)
		r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var val := Ui.label(pair[1], "Value", HORIZONTAL_ALIGNMENT_RIGHT)
		val.add_theme_font_size_override("font_size", 24)
		val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.add_child(val)
		grid.add_child(r)
	card.add_child(grid)
	b.add_child(card)
	# Super.
	var sc := _card()
	var srow := _row([_disc({"slam": "sun", "whirlwind": "whirlwind", "volley": "arrow-cluster", "meteor": "meteor-impact"}[d2["super"]], Color(1.0, 0.6, 0.25), 64)])
	var sv := VBoxContainer.new()
	sv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sv.add_theme_constant_override("separation", 0)
	sv.add_child(Ui.label("SUPER · " + str(d2["super_name"]).to_upper(), "Caption"))
	var sd := Ui.label(d2["super_desc"], "Body")
	sd.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sv.add_child(sd)
	srow.add_child(sv)
	sc.add_child(srow)
	b.add_child(sc)
	# Upgrade.
	if h2["unlocked"]:
		var uc := _card()
		var uv := VBoxContainer.new()
		var cost := Game.upgrade_cost(id2)
		if cost.is_empty():
			uv.add_child(Ui.label("Max level", "Heading", HORIZONTAL_ALIGNMENT_CENTER))
		else:
			var top := _row([Ui.label("Level %d → %d" % [int(h2["level"]), int(h2["level"]) + 1], "Heading"), _spacer(), Ui.label("+%d%% health and damage" % int(DB.LEVEL_POWER * 100.0), "Small")])
			uv.add_child(top)
			var ready_up: bool = int(h2["shards"]) >= int(cost["shards"])
			var pb := ProgressBar.new()
			pb.theme_type_variation = &"ProgressBar" if ready_up else &"XPBar"
			pb.custom_minimum_size = Vector2(0, 30)
			pb.max_value = cost["shards"]
			pb.value = mini(int(h2["shards"]), cost["shards"])
			pb.show_percentage = false
			var pl := Ui.label("Ready" if ready_up else "%d / %d shards" % [int(h2["shards"]), cost["shards"]], "HudLabel", HORIZONTAL_ALIGNMENT_CENTER)
			pl.add_theme_font_size_override("font_size", 19)
			pl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			pl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			pb.add_child(pl)
			uv.add_child(pb)
			var ub := Button.new()
			ub.theme_type_variation = "GoldButton"
			ub.text = "Upgrade · %d gold" % cost["gold"]
			ub.icon = Ui.icon("upgrade")
			ub.custom_minimum_size = Vector2(0, 84)
			ub.focus_mode = Control.FOCUS_NONE
			ub.disabled = not Game.can_upgrade(id2)
			ub.pressed.connect(func():
				if Game.upgrade(id2):
					Sfx.play("levelup", 0.0)
					lobby.show_hero(id2)
					s.rebuild())
			uv.add_child(ub)
		uc.add_child(uv)
		b.add_child(uc)
		# Mastery and rating: progress that every hunt with this hero moves.
		var mc := _card()
		var mv := VBoxContainer.new()
		mv.add_theme_constant_override("separation", 4)
		var nxt := Game.mastery_next(id2)
		mv.add_child(_row([Ui.icon_rect("round-star", 34, Color(1.0, 0.8, 0.35)), Ui.label("Mastery · %s" % Game.mastery_title(id2), "Heading"), _spacer(), Ui.label("Rating %d" % int(h2.get("rating", 0)), "Value")], 10))
		var mb := ProgressBar.new()
		mb.theme_type_variation = &"XPBar"
		mb.show_percentage = false
		mb.custom_minimum_size = Vector2(0, 12)
		var rank := int(h2.get("mastery_rank", 0))
		var lo := int(DB.MASTERY[rank]["at"])
		mb.value = 100.0 if nxt < 0 else float(int(h2.get("mastery", 0)) - lo) / float(nxt - lo) * 100.0
		mv.add_child(mb)
		var ml := Ui.label("Top rank" if nxt < 0 else "%d / %d to %s · ranks pay gold, shards and weapon glows" % [int(h2.get("mastery", 0)), nxt, DB.MASTERY[rank + 1]["title"]], "Small")
		ml.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		mv.add_child(ml)
		var rl := Ui.label("Rating: wins add, losses take away. Every %d pays out." % DB.RATING_STEP, "Small")
		rl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		mv.add_child(rl)
		mc.add_child(mv)
		b.add_child(mc)
		# Weapon glows: cosmetics bought with gold (or earned by mastery).
		b.add_child(Ui.label("WEAPON GLOW", "Caption"))
		var gl := HFlowContainer.new()
		gl.add_theme_constant_override("h_separation", 8)
		gl.add_theme_constant_override("v_separation", 8)
		for g in [""] + DB.GLOW_ORDER:
			var gb := Button.new()
			gb.toggle_mode = true
			gb.focus_mode = Control.FOCUS_NONE
			gb.button_pressed = str(h2.get("glow", "")) == g
			gb.custom_minimum_size = Vector2(0, 60)
			var owned: bool = g == "" or g in h2.get("glows", [])
			gb.text = "None" if g == "" else (str(DB.GLOWS[g]["name"]) if owned else "%s · %s" % [DB.GLOWS[g]["name"], Ui.fmt_num(int(DB.GLOWS[g]["gold"]))])
			if g != "":
				gb.add_theme_color_override("font_color", Color(DB.GLOWS[g]["color"], 1.0).lightened(0.3))
			var gid: String = g
			gb.pressed.connect(func():
				if gid == "" or gid in Game.hero(id2)["glows"]:
					Game.set_glow(id2, gid)
				elif not Game.buy_glow(id2, gid):
					Sfx.play("ui_error", -6.0)
					s.rebuild()
					return
				else:
					Sfx.play("coin", 0.0)
				lobby.show_hero(id2)
				refresh()
				s.rebuild())
			gl.add_child(gb)
		b.add_child(gl)
		# Companion: another hero of the band fights at your side.
		var ally := str(Game.data.get("ally", ""))
		var ab := Button.new()
		ab.theme_type_variation = &"CardButton"
		ab.focus_mode = Control.FOCUS_NONE
		ab.custom_minimum_size = Vector2(0, 72)
		ab.icon = Ui.icon("crossed-swords")
		ab.text = "Companion: %s (tap to change)" % (DB.HEROES[ally]["name"] if ally != "" else "none")
		ab.pressed.connect(func():
			var pool: Array = [""] + DB.HERO_ORDER.filter(func(x): return Game.hero(x)["unlocked"])
			var i := pool.find(str(Game.data.get("ally", "")))
			Game.data["ally"] = pool[(i + 1) % pool.size()]
			Game.save()
			Sfx.play("ui_toggle", -4.0)
			s.rebuild())
		b.add_child(ab)
		# Talents: a point per level, spent down three paths.
		var pts := Game.talent_points(id2)
		var tb := Button.new()
		tb.text = "Talents · %d point%s" % [pts, "" if pts == 1 else "s"] if pts > 0 else "Talents"
		tb.theme_type_variation = &"GoldButton" if pts > 0 else &"CardButton"
		tb.icon = Ui.icon("round-star")
		tb.custom_minimum_size = Vector2(0, 80)
		tb.focus_mode = Control.FOCUS_NONE
		tb.pressed.connect(func(): open_sheet("talents"))
		b.add_child(tb)
		# Gear: what this hero wears at a glance, and a way into the equipment screen.
		b.add_child(Ui.label("GEAR", "Caption"))
		var gear := _card()
		var gv := VBoxContainer.new()
		gv.add_theme_constant_override("separation", 12)
		var worn_n := 0
		var gear_power := 0
		for slot in DB.SLOTS:
			var worn := Game.equipped(id2, slot)
			if not worn.is_empty():
				worn_n += 1
				gear_power += Game.item_power(worn)
		gv.add_child(_row([Ui.icon_rect("breastplate", 40, Color(0.85, 0.72, 0.48)), Ui.label("Gear power %d" % gear_power, "Heading"), _spacer(), Ui.label("%d / %d slots" % [worn_n, DB.SLOTS.size()], "Small")], 12))
		var open_eq := Button.new()
		open_eq.text = "Equipment"
		open_eq.theme_type_variation = "PrimaryButton"
		open_eq.custom_minimum_size = Vector2(0, 80)
		open_eq.focus_mode = Control.FOCUS_NONE
		open_eq.pressed.connect(func():
			s.close()
			await get_tree().create_timer(0.25).timeout
			open_equipment())
		gv.add_child(open_eq)
		gear.add_child(gv)
		b.add_child(gear)
	else:
		var lc := _card()
		var ll := Ui.label("Locked — " + ("clear Veteran, or gather 20 shards from chests." if d2["unlock"] == "veteran" else "gather 20 shards from chests."), "Body")
		ll.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lc.add_child(ll)
		b.add_child(lc)


## The talent tree: three columns, each a path read top to bottom.
func _build_talents(s: Sheet) -> void:
	var b := s.body
	var id := _shown_hero
	var d: Dictionary = DB.HEROES[id]
	var pts := Game.talent_points(id)
	var head := _row([Ui.label("%s · Level %d" % [d["name"], int(Game.hero(id)["level"])], "Heading"), _spacer()])
	var chip := PanelContainer.new()
	chip.theme_type_variation = &"Chip"
	chip.add_child(Ui.label("%d point%s" % [pts, "" if pts == 1 else "s"], "Value"))
	head.add_child(chip)
	var reset := Button.new()
	var rc := Game.respec_cost(id)
	reset.text = "Reset" if rc == 0 else "Reset · %s" % Ui.fmt_num(rc)
	reset.theme_type_variation = &"Ghost"
	reset.focus_mode = Control.FOCUS_NONE
	reset.disabled = Game.talents(id).is_empty()
	reset.pressed.connect(func():
		if not Game.respec(id):
			Sfx.play("ui_error", -6.0)
			return
		Sfx.play("ui_back", -4.0)
		refresh()
		s.rebuild())
	head.add_child(reset)
	b.add_child(head)
	var note := Ui.label("Each level gives a point. Every node needs the one above it. The first reset is free; after that it costs gold.", "Small")
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.add_child(note)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 10)
	var paths := TalentDB.paths(id)
	for pi in paths.size():
		var path: Dictionary = paths[pi]
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_theme_constant_override("separation", 8)
		var ph := VBoxContainer.new()
		ph.add_theme_constant_override("separation", 0)
		ph.add_child(Ui.icon_rect(path["icon"], 44, Color(d["color"]).lightened(0.3)))
		ph.add_child(Ui.label(str(path["name"]).to_upper(), "Caption", HORIZONTAL_ALIGNMENT_CENTER))
		var bl := Ui.label(path["blurb"], "Small", HORIZONTAL_ALIGNMENT_CENTER)
		bl.add_theme_font_size_override("font_size", 15)
		bl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ph.add_child(bl)
		col.add_child(ph)
		var nodes: Array = path["nodes"]
		for ni in nodes.size():
			col.add_child(_talent_node(s, id, pi, ni, nodes[ni]))
		cols.add_child(col)
	b.add_child(cols)


func _talent_node(s: Sheet, id: String, pi: int, ni: int, n: Dictionary) -> Button:
	var owned := Game.has_talent(id, pi, ni)
	var can := Game.can_learn(id, pi, ni)
	var kind: String = n["k"]
	var tint: Color = {"m": Color(0.7, 0.75, 0.85), "n": Color(0.95, 0.75, 0.35), "k": Color(1.0, 0.5, 0.25)}[kind]
	var btn := Button.new()
	btn.toggle_mode = true
	btn.button_pressed = owned
	btn.custom_minimum_size = Vector2(0, 118 if kind != "m" else 104)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.focus_mode = Control.FOCUS_NONE
	btn.theme_type_variation = &"Choice"
	if not owned and not can:
		btn.modulate = Color(1, 1, 1, 0.5)
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 8
	v.offset_right = -8
	v.offset_top = 6
	v.offset_bottom = -6
	v.add_theme_constant_override("separation", 0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var kl := Ui.label(str(TalentDB.KIND_NAME[kind]).to_upper(), "Caption", HORIZONTAL_ALIGNMENT_CENTER)
	kl.add_theme_color_override("font_color", tint)
	kl.add_theme_font_size_override("font_size", 13)
	v.add_child(kl)
	var nl := Ui.label(n["name"], "Body", HORIZONTAL_ALIGNMENT_CENTER)
	nl.add_theme_font_size_override("font_size", 18)
	nl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(nl)
	var dl := Ui.label(TalentDB.describe(n), "Small", HORIZONTAL_ALIGNMENT_CENTER)
	dl.add_theme_font_size_override("font_size", 14)
	dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(dl)
	btn.add_child(v)
	btn.pressed.connect(func():
		if Game.learn_talent(id, pi, ni):
			Sfx.play("levelup", -4.0)
			refresh()
		else:
			Sfx.play("ui_error", -8.0)
		s.rebuild())
	return btn


func _build_skills(s: Sheet) -> void:
	var b := s.body
	var levels := Game.skill_levels()
	var total := 0
	for k in levels:
		total += int(levels[k])
	var head := _card()
	var hr := _row([_disc("crossed-swords", Color(0.95, 0.75, 0.35), 84)], 18)
	var hv := VBoxContainer.new()
	hv.add_theme_constant_override("separation", 0)
	var cl := Ui.label("Combat level %d" % Game.combat_level(), "Heading")
	hv.add_child(cl)
	hv.add_child(Ui.label("Total level %d · 99 is the top" % total, "Small"))
	hr.add_child(hv)
	head.add_child(hr)
	b.add_child(head)
	var grid := GridContainer.new()
	grid.columns = 2
	for sk in DB.SKILLS:
		var xp := int(Game.data["skills"][sk])
		var lvl := DB.level_for_xp(xp)
		var c := _card()
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 4)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var top := _row([Ui.icon_rect(DB.SKILL_ICON[sk], 40, Color(0.95, 0.78, 0.45)), Ui.label(DB.SKILL_NAME[sk], "Body"), _spacer()], 8)
		var lv := Ui.label("%d" % lvl, "Value")
		lv.add_theme_font_size_override("font_size", 30)
		lv.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
		top.add_child(lv)
		v.add_child(top)
		var pb := ProgressBar.new()
		pb.theme_type_variation = "XPBar"
		pb.custom_minimum_size = Vector2(0, 12)
		pb.show_percentage = false
		var lo := DB.xp_for_level(lvl)
		var hi := DB.xp_for_level(mini(lvl + 1, 99))
		pb.value = 100.0 if lvl >= 99 else float(xp - lo) / float(maxi(hi - lo, 1)) * 100.0
		v.add_child(pb)
		var xl := Ui.label("%s xp · %s to %d" % [Ui.fmt_num(xp), Ui.fmt_num(maxi(hi - xp, 0)), mini(lvl + 1, 99)], "Small")
		xl.add_theme_font_size_override("font_size", 17)
		v.add_child(xl)
		var perk := Ui.label(DB.SKILL_PERK[sk], "Small")
		perk.add_theme_font_size_override("font_size", 17)
		perk.add_theme_color_override("font_color", Color(0.55, 0.75, 1.0))
		perk.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(perk)
		c.add_child(v)
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(c)
	b.add_child(grid)
	var note := Ui.label("Damage you deal trains your skills: melee heroes train Attack, Strength and Defence; the Ranger trains Ranged; the Mage trains Magic. Hitpoints always trains.", "Small")
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.add_child(note)


## Mode, place and difficulty, each a short list of cards that say what the
## choice means (and, when locked, how to open it).
## The renown road: the next steps with what each pays; claim in order.
func _build_road(s: Sheet) -> void:
	var b := s.body
	var claimed := int(Game.data["road"])
	var ready_n := Game.road_claimable()
	b.add_child(_row([Ui.label("Renown %d" % Game.renown(), "Heading"), _spacer(), Ui.label("Every hunt earns renown", "Small")]))
	if not _road_note.is_empty():
		var nc := _card()
		var nl := Ui.label("Claimed: " + ", ".join(_road_note), "Body")
		nl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		nl.add_theme_color_override("font_color", Color(0.6, 1.0, 0.7))
		nc.add_child(nl)
		b.add_child(nc)
		_road_note = []
	for i in 8:
		var n := claimed + 1 + i
		var c := _card()
		var reachable := i < ready_n
		var row := _row([], 14)
		var num := Ui.label("%d" % n, "Value")
		num.add_theme_font_size_override("font_size", 30)
		num.custom_minimum_size = Vector2(54, 0)
		row.add_child(num)
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_theme_constant_override("separation", 0)
		v.add_child(Ui.label(Game.road_reward_text(n), "Body"))
		v.add_child(Ui.label("%d renown" % DB.road_threshold(n), "Small"))
		row.add_child(v)
		if i == 0 and reachable:
			var cb := Button.new()
			cb.text = "Claim"
			cb.theme_type_variation = &"GoldButton"
			cb.custom_minimum_size = Vector2(150, 70)
			cb.focus_mode = Control.FOCUS_NONE
			cb.pressed.connect(func():
				_road_note = Game.claim_road()
				Sfx.play("coin", 0.0)
				refresh()
				s.rebuild())
			row.add_child(cb)
		elif not reachable:
			c.modulate = Color(1, 1, 1, 0.55)
		c.add_child(row)
		b.add_child(c)


func _build_expedition(s: Sheet) -> void:
	var b := s.body
	var om := Game.weekly_omen()
	b.add_child(Ui.label("This week's omen", "Heading"))
	var olock := "Not on the Long Road" if Game.mode_id() == "trial" else ""
	b.add_child(_option(str(om["icon"]), str(om["name"]), "%s Pays 25%% more gold and a better chest." % om["desc"], bool(Game.data.get("omen_on", false)) and olock == "", olock, func():
		Game.set_omen(not bool(Game.data.get("omen_on", false)))
		_picked(s)))
	b.add_child(Ui.label("Mode", "Heading"))
	for mid: String in DB.MODE_ORDER:
		var m: Dictionary = DB.MODES[mid]
		var sub: String = m["blurb"]
		if m.has("rooms"):
			sub += " %d rooms on %s." % [int(m["rooms"][Game.tier()]), DB.TIERS[Game.tier()]["name"]]
		if mid == "descent" and Game.best_depth(Game.hero_id()) > 0:
			sub += " Your deepest: %d." % Game.best_depth(Game.hero_id())
		var mlock := "" if Game.mode_unlocked(mid) else str(m["unlock"])
		b.add_child(_option(MODE_ICON.get(mid, "crossed-swords"), m["name"], sub, mid == Game.mode_id(), mlock, func():
			Game.set_mode(mid)
			_picked(s)))
	b.add_child(Ui.label("Location", "Heading"))
	for zid: String in DB.ZONE_ORDER:
		var z: Dictionary = DB.ZONES[zid]
		var boss: Dictionary = DB.boss_def(z["boss"])
		var sub := "Boss: %s. %s" % [boss["name"], z["blurb"]]
		var lock := "" if Game.zone_unlocked(zid) else str(z["unlock"])
		b.add_child(_option("tombstone", z["name"], sub, zid == Game.zone_id(), lock, func():
			Game.set_zone(zid)
			_picked(s)))
	b.add_child(Ui.label("Difficulty", "Heading"))
	for i in DB.TIERS.size():
		var t: Dictionary = DB.TIERS[i]
		var sub := "Foes ×%s health, ×%s damage · loot ×%s · %s" % [_num(t["hp"]), _num(t["dmg"]), _num(t["loot"]), DB.CHESTS[t["chest"]]["name"]]
		if i == 0:
			sub = "The dead as they are · %s" % DB.CHESTS[t["chest"]]["name"]
		if float(t["mech"]) > 0.0:
			sub += "\nTelegraphed blows take %d%% of your health · healing −%d%%" % [int(round(float(t["mech"]) * 100.0)), int(round((1.0 - float(t["heal"])) * 100.0))]
		var pw := Game.power_score(Game.hero_id())
		sub += "\nRecommended power %s · yours %s" % [Ui.fmt_num(int(t["power"])), Ui.fmt_num(pw)]
		var lock := "" if i <= Game.mode_tier_unlocked() else "%s on %s to open" % ["Fell a boss" if Game.mode_id() == "descent" else "Win", DB.TIERS[i - 1]["name"]]
		var ti := i
		var card := _option("crowned-skull", t["name"], sub, i == Game.tier(), lock, func():
			Game.set_tier(ti)
			_picked(s))
		card.get_meta("title").add_theme_color_override("font_color", t["color"])
		b.add_child(card)


func _picked(s: Sheet) -> void:
	Sfx.play("ui_tap", -4.0)
	refresh()
	s.rebuild()


func _num(v: float) -> String:
	return str(v).trim_suffix(".0")


## One choice in a picker: icon, name, a line of what it means. Locked choices
## are dimmed and say how to open them instead.
func _option(icon: String, title: String, sub: String, chosen: bool, lock: String, cb: Callable) -> Button:
	var btn := Button.new()
	btn.theme_type_variation = "Choice"
	btn.toggle_mode = true
	btn.button_pressed = chosen
	btn.focus_mode = Control.FOCUS_NONE
	btn.disabled = lock != ""
	# Each extra line of the description (tier notes) makes the card taller.
	btn.custom_minimum_size = Vector2(0, 112 + 34 * sub.count("\n"))
	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_theme_constant_override("margin_left", 18)
	m.add_theme_constant_override("margin_right", 18)
	btn.add_child(m)
	var h := HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_theme_constant_override("separation", 16)
	m.add_child(h)
	var ic := Ui.icon_rect("padlock" if lock != "" else icon, 48, Color(0.91, 0.71, 0.35) if chosen else Color(0.64, 0.6, 0.54))
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(ic)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	v.add_theme_constant_override("separation", 2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(v)
	var tl := Ui.label(title, "Value")
	tl.add_theme_font_size_override("font_size", 26)
	if lock != "":
		tl.modulate.a = 0.5
	v.add_child(tl)
	var sl := Ui.label(lock if lock != "" else sub, "Small")
	sl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(sl)
	btn.set_meta("title", tl)
	btn.pressed.connect(cb)
	return btn


func _build_bounties(s: Sheet) -> void:
	var b := s.body
	b.add_child(Ui.label("Three new bounties every day. Progress counts from any hunt.", "Small"))
	var list: Array = Game.data["bounties"]["list"]
	for i in list.size():
		var e: Dictionary = list[i]
		var done := Game.bounty_done(e)
		var claimed: bool = e["claimed"]
		var c := _card()
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 8)
		var rew := "%d gold" % int(e["gold"])
		if int(e["shards"]) > 0:
			rew += " + %d %s shards" % [int(e["shards"]), DB.HEROES[e["shard_hero"]]["name"]]
		var top := _row([Ui.label(Game.bounty_text(e), "Body"), _spacer()], 8)
		top.get_child(0).add_theme_color_override("font_color", Color(0.6, 0.6, 0.6) if claimed else Color(1.0, 0.94, 0.85))
		v.add_child(top)
		var pb := ProgressBar.new()
		pb.theme_type_variation = "XPBar"
		pb.custom_minimum_size = Vector2(0, 14)
		pb.show_percentage = false
		pb.value = float(e["progress"]) / float(maxi(int(e["target"]), 1)) * 100.0
		v.add_child(pb)
		var bottom := _row([Ui.label("%d / %d" % [mini(int(e["progress"]), int(e["target"])), int(e["target"])], "Small"), _spacer(), Ui.label(rew, "Small")], 8)
		bottom.get_child(2).add_theme_color_override("font_color", Color(0.95, 0.78, 0.45))
		v.add_child(bottom)
		if done and not claimed:
			var cb := Button.new()
			cb.theme_type_variation = "GoldButton"
			cb.text = "Claim"
			cb.custom_minimum_size = Vector2(0, 76)
			cb.focus_mode = Control.FOCUS_NONE
			var idx := i
			cb.pressed.connect(func():
				var got := Game.claim_bounty(idx)
				if not got.is_empty():
					Sfx.play("coin", -2.0)
					Ui.buzz(20, 0.4)
					refresh()
					s.rebuild())
			v.add_child(cb)
		elif claimed:
			var dn := Ui.label("Claimed", "Caption", HORIZONTAL_ALIGNMENT_CENTER)
			dn.add_theme_color_override("font_color", Color(0.5, 0.85, 0.55))
			v.add_child(dn)
		c.add_child(v)
		b.add_child(c)


func _build_log(s: Sheet) -> void:
	var b := s.body
	var got := 0
	for u in DB.LOG_ORDER:
		if int(Game.data["log"].get(u, 0)) > 0:
			got += 1
	var st: Dictionary = Game.data["stats"]
	var cl := Game.clue()
	var cc0 := _card()
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 4)
	cv.add_child(Ui.label("CLUE SCROLL", "Caption"))
	if cl.is_empty():
		var none := Ui.label("None yet. Hunts sometimes turn one up: three goals, then a casket.", "Body")
		none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cv.add_child(none)
	else:
		var step := int(cl["step"])
		var gl := Ui.label("Step %d of %d: %s" % [step + 1, DB.CLUE_STEPS, Game.clue_goal_text(cl["goals"][step])], "Body")
		gl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		gl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.5))
		cv.add_child(gl)
	cc0.add_child(cv)
	b.add_child(cc0)
	var head := _row([Ui.label("Obtained %d / %d" % [got, DB.LOG_ORDER.size()], "Heading"), _spacer(), Ui.label("Boss kills: %d" % int(st["boss_kills"]), "Small")])
	b.add_child(head)
	# Kill counts and dry streaks: the Old School grind, out loud.
	var kcc := _card()
	var kv := VBoxContainer.new()
	kv.add_theme_constant_override("separation", 4)
	kv.add_child(Ui.label("BOSSES", "Caption"))
	for zid: String in DB.ZONE_ORDER:
		var bid := str(DB.ZONES[zid]["boss"])
		var line := "%s KC %s · dry %d (worst %d)" % [DB.BOSSES[bid]["name"], Ui.fmt_num(Game.kc(bid)), Game.dry(bid), int(Game.data["dry_best"].get(bid, 0))]
		kv.add_child(_row([Ui.icon_rect("crowned-skull", 28, Color(DB.BOSSES[bid]["color"])), Ui.label(line, "Body")], 8))
	kv.add_child(Ui.label("Rift keys: %d · rifts closed: %d" % [int(Game.data.get("rift_keys", 0)), int(st.get("rifts", 0))], "Small"))
	kcc.add_child(kv)
	b.add_child(kcc)
	# Pets: pick which one follows you.
	var pets: Array = Game.data.get("pets", [])
	if pets.size() > 1:
		var pr := HBoxContainer.new()
		pr.add_theme_constant_override("separation", 8)
		pr.add_child(Ui.label("Pet", "Body"))
		for pid: String in pets:
			var pb := Button.new()
			pb.toggle_mode = true
			pb.focus_mode = Control.FOCUS_NONE
			pb.button_pressed = str(Game.data["pet"]) == pid
			pb.text = str(DB.UNIQUES[pid]["name"])
			pb.pressed.connect(func():
				Game.data["pet"] = pid
				Game.save()
				s.rebuild())
			pr.add_child(pb)
		b.add_child(pr)
	var grid := GridContainer.new()
	grid.columns = 2
	for u in DB.LOG_ORDER:
		var ud: Dictionary = DB.UNIQUES[u]
		var n := int(Game.data["log"].get(u, 0))
		var col := DB.rarity_color(ud["rarity"])
		var c := _card()
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 2)
		var cc := CenterContainer.new()
		var ic := Ui.icon_rect(ud["icon"], 72, col if n > 0 else Color(0.08, 0.08, 0.09))
		cc.add_child(ic)
		v.add_child(cc)
		var nm := Ui.label(ud["name"] if n > 0 else "???", "Body", HORIZONTAL_ALIGNMENT_CENTER)
		nm.add_theme_color_override("font_color", col if n > 0 else Color(0.5, 0.48, 0.45))
		nm.add_theme_font_size_override("font_size", 20)
		nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(nm)
		var src: String = {"boss": "Gravemaw", "hexer": "Hexer Queen", "thorn": "Thornmother", "elite": "Champions", "nightmare": "Bosses (Nightmare)"}[ud["source"]]
		var rl := Ui.label("1/%d · %s" % [int(ud["rate"]), src], "Small", HORIZONTAL_ALIGNMENT_CENTER)
		rl.add_theme_font_size_override("font_size", 16)
		v.add_child(rl)
		if n > 0:
			var cnt := Ui.label("× %d" % n, "Value", HORIZONTAL_ALIGNMENT_CENTER)
			cnt.add_theme_font_size_override("font_size", 20)
			v.add_child(cnt)
		c.add_child(v)
		grid.add_child(c)
	b.add_child(grid)
	# Recipes: which pairs make an evolution, and each hero's signature card.
	var ec := _card()
	var ev := VBoxContainer.new()
	ev.add_theme_constant_override("separation", 2)
	ev.add_child(Ui.label("EVOLUTIONS · three of the first card, one of the second", "Caption"))
	for cid: String in DB.CARDS:
		var c: Dictionary = DB.CARDS[cid]
		if c.has("evo"):
			var el := Ui.label("%s + %s → %s" % [DB.CARDS[c["evo"][0]]["name"], DB.CARDS[c["evo"][1]]["name"], c["name"]], "Small")
			el.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			ev.add_child(el)
	for hid: String in DB.SIGNATURES:
		var sc: Dictionary = DB.CARDS[DB.SIGNATURES[hid]]
		var sl := Ui.label("%s signature: %s — %s" % [DB.HEROES[hid]["name"], sc["name"], sc["desc"]], "Small")
		sl.add_theme_color_override("font_color", DB.rarity_color("legendary"))
		sl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ev.add_child(sl)
	ec.add_child(ev)
	b.add_child(ec)
	# Sets: what each boss's set does.
	var setc := _card()
	var setv := VBoxContainer.new()
	setv.add_theme_constant_override("separation", 2)
	setv.add_child(Ui.label("SETS · pieces from a boss's hoard", "Caption"))
	for sid: String in DB.SETS:
		var sd: Dictionary = DB.SETS[sid]
		var sl2 := Ui.label("%s: 2 pieces %s · 4 pieces %s" % [sd["name"], sd["2"]["desc"], sd["4"]["desc"]], "Small")
		sl2.add_theme_color_override("font_color", sd["color"])
		sl2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		setv.add_child(sl2)
	setc.add_child(setv)
	b.add_child(setc)
	var stats := _card()
	var sv := VBoxContainer.new()
	sv.add_child(Ui.label("RECORD", "Caption"))
	for pair in [["Hunts", st["hunts"]], ["Victories", st["wins"]], ["Dead put back to rest", st["kills"]], ["Champions slain", st["elites"]]]:
		sv.add_child(_row([Ui.label(pair[0], "Body"), _spacer(), Ui.label(Ui.fmt_num(int(pair[1])), "Value")]))
	for i in DB.TIERS.size():
		var best := float(st["best"].get(str(i), 0.0))
		if best > 0.0:
			sv.add_child(_row([Ui.label("Fastest %s clear" % DB.TIERS[i]["name"], "Body"), _spacer(), Ui.label(Ui.fmt_time(best), "Value")]))
	stats.add_child(sv)
	b.add_child(stats)


func _build_settings(s: Sheet) -> void:
	var b := s.body
	b.add_child(SettingsBox.new())
	b.add_child(HSeparator.new())
	var cr := Ui.label("Art: KayKit by Kay Lousberg (CC0). Icons: game-icons.net (CC BY 3.0). Music: Kevin MacLeod (CC BY 4.0). Effects: Kenney, rubberduck and others (CC0). Full list in CREDITS.md.", "Small")
	cr.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.add_child(cr)
	var ota := get_node_or_null("/root/Ota")
	var ver := "Gravelight v%s" % ProjectSettings.get_setting("application/config/version")
	if ota:
		ver += " · build %d · content %d" % [int(ota.get("baked_build")), int(ota.get("build"))]
	b.add_child(Ui.label(ver, "Small"))
