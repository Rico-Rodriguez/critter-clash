class_name LobbyUI
extends "res://src/lobby/lobby_ui_sheets.gd"
## The camp's interface: top bar, hero switcher, difficulty, the big button,
## and the sheets (Heroes, Bag, Skills, Log, Settings).
##
## Split into a chain of scripts: lobby_ui_widgets (fields, widgets) <
## lobby_ui_hero_sheets < lobby_ui_sheets < lobby_ui (setup, top bar, side
## column, chest, opening sheets).


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


func refresh() -> void:
	%Gold.text = Ui.fmt_num(Game.gold())
	var id := _shown_hero
	%Combat.text = "Combat %d" % Game.combat_level(id)
	var d: Dictionary = DB.HEROES[id]
	var h := Game.hero(id)
	%HeroName.text = d["name"]
	%HeroTitle.text = "%s · %s · %s" % [Game.mastery_title(id), d["title"], d["role"]]
	# The top chip shows this hero's combat level; bought levels are gone.
	%HeroLevel.get_parent().visible = false
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


## True while nothing sits over the camp (taps on the hero open the roster).
func camp_idle() -> bool:
	return %Safe.visible and not chest_opening and (_sheet == null or not is_instance_valid(_sheet)) and (equipment == null or not is_instance_valid(equipment))


func _any_upgrade() -> bool:
	for id in DB.HERO_ORDER:
		if Game.hero(id)["unlocked"] and Game.talent_points(id) > 0:
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
			_sheet.open("%s · Skills" % DB.HEROES[_shown_hero]["name"], _build_skills)
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
