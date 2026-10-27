class_name LobbyUI
extends "res://src/lobby/lobby_ui_social.gd"
## The camp's interface: a bar of four tabs along the bottom (Shop, Heroes,
## Hunt, Clan), swiped or tapped like Clash Royale's. Hunt is home:
## the player plate, the season, the side rails, the hero by the fire and the
## chest · hunt · road row. The other tabs are full pages above the bar;
## Expedition, Settings and the profile still slide up as sheets.
##
## Split into a chain of scripts: lobby_ui_widgets (fields, widgets) <
## lobby_ui_hero_sheets < lobby_ui_sheets < lobby_ui_social < lobby_ui
## (setup, home, tabs, chest, opening sheets).

const Shop := preload("res://src/lobby/shop.gd")

## Left to right in the bar.
const TABS := ["shop", "heroes", "hunt", "clan"]
const TAB_LOOK := {
	"shop": ["Shop", "two-coins"],
	"heroes": ["Heroes", "visored-helm"],
	"hunt": ["Hunt", "crossed-swords"],
	"clan": ["Clan", "checked-shield"],
}
## Which tab and sub-tab each old sheet name lands on.
const SHEET_TAB := {
	"heroes": ["heroes", 0],
	"bag": ["heroes", 0], "clan": ["clan", 0], "shop": ["shop", 0],
}

var _tab_btns := {}
var _tab_dots := {}
var _rail_r: VBoxContainer
var _season_label: Label
## A horizontal swipe in progress: where and when the finger went down.
var _sw_from := Vector2.ZERO
var _sw_t := -1.0
var _sw_index := -1
## The chest being opened was bought in the Shop: -1 off the shelf, else the deal.
var _bought_deal := -2


func setup(l: Node3D) -> void:
	lobby = l
	Ui.apply_safe_area(%Safe)
	# The bar sits flush with the bottom edge. The home indicator floats over
	# its lower part, so only half the inset is added: the icons still clear it.
	var bar := NAV_H + roundf(Ui.safe_insets(0).w * 0.5)
	%Safe.add_theme_constant_override("margin_bottom", int(bar) + 30)
	%NavBar.offset_top = -bar
	%M.add_theme_constant_override("margin_bottom", int(bar - NAV_H))
	%M.add_theme_constant_override("margin_top", 6)
	%M.add_theme_constant_override("margin_left", 8)
	%M.add_theme_constant_override("margin_right", 8)
	%Pages.offset_bottom = -bar
	_shown_hero = Game.hero_id()
	Game.refresh_bounties()
	Game.refresh_shop()
	%Prev.pressed.connect(func(): _cycle(-1))
	%Next.pressed.connect(func(): _cycle(1))
	%Hunt.pressed.connect(_on_hunt)
	%Settings.icon = Ui.icon("hamburger-menu")
	%Settings.pressed.connect(func(): open_sheet("settings"))
	%Chest.pressed.connect(_on_chest_slot)
	%Chest.icon = Ui.icon("locked-chest")
	%PlayerChip.pressed.connect(func():
		Sfx.play("ui_tap", -4.0)
		open_sheet("profile"))
	# The Trophy Road is the goal to chase, so it gets the top of the screen.
	%Road.pressed.connect(func(): open_sheet("road"))
	%RoadIcon.texture = Ui.icon("trophy")
	# The mode card right above HUNT says what you'll play and changes it.
	%Expedition.pressed.connect(func(): open_sheet("expedition"))
	%GoldIcon.texture = Ui.icon("two-coins")
	_build_tabs()
	_build_side()
	_dress_home()
	Game.changed.connect(refresh)
	_social_setup()
	refresh()
	_count_gold_in()


## The home's motion: shine on the HUNT button and the pills, breathing
## badges, embers drifting up past the hero.
func _dress_home() -> void:
	FxUi.gloss(%Hunt, 12.0, 0.5, 3.6)
	FxUi.gloss(%Road, 12.0, 0.18, 6.0, 2.0)
	FxUi.pulse(%RoadBadge, 1.18, 1.3)
	for k in _side_badges:
		FxUi.pulse(_side_badges[k], 1.18, 1.3)
	var embers := Control.new()
	embers.mouse_filter = Control.MOUSE_FILTER_IGNORE
	%Safe.add_child(embers)
	%Safe.move_child(embers, 0)
	FxUi.add_motes(embers, Color(1.0, 0.62, 0.3, 0.7), 18, 34.0)


func refresh() -> void:
	%Gold.text = Ui.fmt_num(Game.gold())
	var id := _shown_hero
	var d: Dictionary = DB.HEROES[id]
	var h := Game.hero(id)
	%Combat.text = str(Game.combat_level(id))
	%PlayerName.text = Game.player_name()
	%PlayerSub.text = "%s · Combat %d" % [_clan_line(), Game.combat_level(id)]
	var pw := Game.power_score(id)
	%HeroName.text = str(d["name"]).to_upper()
	%HeroTitle.text = "Power %s" % Ui.fmt_num(pw)
	var locked := not bool(h["unlocked"])
	%Hunt.disabled = locked
	%Lock.visible = locked
	if locked:
		_hunt_text = "Locked"
		%Lock.text = Game.hero_lock_text(id)
	else:
		_hunt_text = {"horde": DB.zone(Game.zone_id())["enter"], "trial": "Take the Long Road", "descent": "Begin the Descent", "rush": "Start the Rush", "rift": "Open the Rift", "wild": "Enter the Wilderness"}[Game.mode_id()]
	var mode: Dictionary = DB.MODES[Game.mode_id()]
	var t: Dictionary = DB.TIERS[Game.tier()]
	%ExpIcon.texture = Ui.icon(MODE_ICON.get(Game.mode_id(), "crossed-swords"))
	%ExpMode.text = str(mode["name"])
	%HuntLabel.text = "LOCKED" if locked else "HUNT"
	# Under the recommended power the line turns red, so a loss reads as "I
	# need gear", not "unfair".
	var rec := int(t["power"])
	var omen := " · Omen" if not Game.active_omen(Game.mode_id()).is_empty() else ""
	%ExpPlace.text = "%s · %s%s" % [DB.zone(Game.zone_id())["name"], t["name"], omen]
	if pw < rec:
		%ExpPlace.text += " · needs %s power" % Ui.fmt_num(rec)
	%ExpPlace.add_theme_color_override("font_color", Color(1.0, 0.55, 0.5) if pw < rec else Color(0.64, 0.6, 0.54))
	# The road: trophies toward the next step, and what that step gives.
	var steps := Game.road_claimable()
	var nxt := int(Game.data["road"]) + 1
	%RoadText.text = "READY" if steps > 0 else "%s / %s" % [Ui.fmt_num(Game.renown()), Ui.fmt_num(DB.road_threshold(nxt))]
	%RoadBar.value = 100.0 if steps > 0 else maxf(Game.road_fill() * 100.0, 3.0)
	%RoadBadge.visible = steps > 0
	var rw := DB.road_reward(nxt)
	%RoadNext.texture = Ui.icon(_road_icon(rw))
	%RoadNext.self_modulate = DB.CHESTS[rw["chest"]]["color"] if str(rw["kind"]) == "chest" else Color(1, 0.84, 0.45)
	_refresh_chest_slot()
	# Tab dots: something to do behind that tab, marked there with the same
	# dot (talent points to spend) or a gold one (new gear). Pieces ready to
	# level have their own green ▲ inside and don't light the tab.
	_tab_dots["heroes"].visible = _any_upgrade() or Game.new_item_count() > 0
	_tab_dots["clan"].visible = _social_dot()
	_tab_dots["shop"].visible = Game.shop_free_ready() > 0
	_refresh_side()
	_first_steps()


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


# --- First steps: a new player sees less and is pointed at the next thing --

const CampGuide := preload("res://src/lobby/camp_guide.gd")
const HeroPick := preload("res://src/lobby/hero_pick.gd")
const TrophyRoad := preload("res://src/lobby/trophy_road.gd")
var _guide: Control
var _pick: Control


## The first visit shows the hero, the hunt and the tabs; the side rails,
## season and road join after the first hunt, when they mean something.
func _first_steps() -> void:
	if not Game.data["start_picked"] and not is_instance_valid(_pick):
		_open_pick.call_deferred()
	var fresh := int(Game.data["stats"]["hunts"]) == 0
	if _side:
		_side.visible = not fresh
	if _rail_r:
		_rail_r.visible = not fresh
	%Road.modulate.a = 0.45 if fresh else 1.0
	_coach.call_deferred()


## A new save picks its first hero before anything else.
func _open_pick() -> void:
	if is_instance_valid(_pick) or Game.data["start_picked"]:
		return
	_pick = HeroPick.new()
	%Overlay.add_child(_pick)
	_pick.open()
	_pick.picked.connect(func(id: String):
		_shown_hero = id
		lobby.show_hero(id)
		refresh()
		_coach.call_deferred())


## Points at the first thing a new player hasn't been shown yet. Each note
## shows once per save.
func _coach() -> void:
	if is_instance_valid(_pick):
		return
	if is_instance_valid(_guide) or not camp_idle() or not is_inside_tree():
		return
	var tips: Dictionary = Game.data["tips"]
	var played := int(Game.data["stats"]["hunts"]) > 0
	for st in [
		["camp_hunt", not played, %Hunt, "Your first hunt", "Drag to move; you attack on your own. Survive the horde, pick a power each level, then beat the boss.", false],
		["camp_chest", _chest_ready(), %Chest, "A chest!", "Your win earned it. Tap to open it.", false],
		["camp_gear", played and Game.new_item_count() > 0, _tab_btns["heroes"], "New gear", "Put on what you found: better gear is the fastest way to grow.", false],
		["camp_heroes", played and _any_upgrade(), _tab_btns["heroes"], "Talent point", "Combat levels earn talent points. Spend them in Heroes.", false],
		["camp_clan", played and int(Game.data["stats"]["hunts"]) >= 3, _tab_btns["clan"], "Hunt together", "Join a clan, add friends, and bring a friend in for a big welcome gift.", false],
	]:
		if not bool(st[1]) or tips.has(st[0]):
			continue
		tips[st[0]] = true
		Game.save()
		_guide = CampGuide.new()
		_guide.setup(st[2], st[3], st[4], st[5], camp_idle)
		%Overlay.add_child(_guide)
		return


# --- Side rails: quests and season left, the campfire right ---------------

## The icon for a road step's reward, as the road itself shows it.
func _road_icon(rw: Dictionary) -> String:
	match str(rw["kind"]):
		"chest":
			return "locked-chest"
		"gold":
			return "two-coins"
		"shards":
			return "gems"
		"mode":
			return MODE_ICON.get(str(rw["id"]), "crossed-swords")
		"zone":
			return "tombstone"
		"hero":
			return str(DB.HEROES[rw["id"]]["icon"])
		"rift_key":
			return "crystal-shine"
		"cards":
			return str(DB.CARDS[rw["ids"][0]]["icon"])
	return "visored-helm"


func _build_side() -> void:
	_side = VBoxContainer.new()
	_side.add_theme_constant_override("separation", 18)
	_side.position = Vector2(0, 18)
	%Space.add_child(_side)
	# Daily, bounties and feats are one place (Quests); the road has the top bar.
	for spec in [["quests", "archery-target", "Quests"], ["season", "round-star", "Season"], ["event", "moon", "Event"]]:
		_side.add_child(_rail_button(spec[0], spec[1], spec[2]))
	_rail_r = VBoxContainer.new()
	_rail_r.add_theme_constant_override("separation", 0)
	_rail_r.anchor_left = 1.0
	_rail_r.anchor_right = 1.0
	_rail_r.offset_left = -84.0
	_rail_r.offset_top = 18.0
	%Space.add_child(_rail_r)
	_rail_r.add_child(_rail_button("idle", "campfire", "Campfire"))


func _rail_button(key: String, icon: String, text: String) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	var b := Button.new()
	b.theme_type_variation = &"RoundButton"
	b.custom_minimum_size = Vector2(76, 76)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.icon = Ui.icon(icon)
	b.expand_icon = true
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(func(): _side_pressed(key))
	# A small glowing dot: something to claim in there.
	var badge := PanelContainer.new()
	badge.theme_type_variation = &"Badge"
	badge.custom_minimum_size = Vector2(18, 18)
	badge.position = Vector2(56, 2)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.visible = false
	b.add_child(badge)
	_side_badges[key] = badge
	col.add_child(b)
	var l := Ui.label(text.to_upper(), "Caption", HORIZONTAL_ALIGNMENT_CENTER)
	l.add_theme_font_size_override("font_size", 14)
	col.add_child(l)
	if key == "idle":
		_idle_label = l
	if key == "season":
		_season_label = l
	return col


func _refresh_side() -> void:
	if _side == null:
		return
	var login := Game.login_status()
	_side_badges["quests"].visible = bool(login["ready"]) or Game.bounty_claimable() > 0 or Game.achievement_claimable() > 0
	_side_badges["season"].visible = Game.season_claimable() > 0
	_side_badges["event"].visible = Game.event_claimable() > 0
	_season_label.text = "TIER %d" % Game.season_level()
	var g := Game.idle_gold()
	_side_badges["idle"].visible = g >= 50
	_idle_label.text = "+%d" % g if g >= 50 else "CAMPFIRE"
	_idle_label.add_theme_color_override("font_color", Color("f3d58f") if g >= 50 else Color("b9a27a"))


func _side_pressed(key: String) -> void:
	Sfx.play("ui_tap", -4.0)
	match key:
		"idle":
			var rate := DB.IDLE_GOLD_HOUR + DB.IDLE_GOLD_TIER * int(Game.data["tier_unlocked"])
			var g := Game.claim_idle()
			if g > 0:
				Sfx.play("coin", 0.0)
				FxUi.coin_fly(%Overlay, _idle_label.get_global_rect().get_center(), %GoldChip, 8)
				_float_text(_idle_label, "+%d gold" % g, Color(1.0, 0.85, 0.4))
			else:
				_float_text(_idle_label, "%d gold an hour" % rate, Color(0.85, 0.8, 0.7))
			refresh()
		"quests":
			open_sheet("journal")
		"season":
			open_sheet("season")
		"event":
			open_sheet("event")


## True while the home is showing with nothing over it (taps on the hero open
## the roster).
func camp_idle() -> bool:
	return tab == "hunt" and %Safe.visible and not chest_opening and (_sheet == null or not is_instance_valid(_sheet))


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


# --- Tabs ----------------------------------------------------------------------

func _build_tabs() -> void:
	%Tabs.add_theme_constant_override("separation", 6)
	for key in TABS:
		var b := Button.new()
		b.theme_type_variation = &"NavTab"
		b.toggle_mode = true
		b.icon = Ui.icon(TAB_LOOK[key][1])
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.expand_icon = true
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var k: String = key
		b.pressed.connect(func(): show_tab(k))
		var dot := PanelContainer.new()
		dot.theme_type_variation = &"Badge"
		dot.custom_minimum_size = Vector2(16, 16)
		dot.anchor_left = 0.5
		dot.anchor_right = 0.5
		dot.offset_left = 16.0
		dot.offset_top = 8.0
		dot.offset_right = 32.0
		dot.offset_bottom = 24.0
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dot.visible = false
		b.add_child(dot)
		_tab_btns[key] = b
		_tab_dots[key] = dot
		%Tabs.add_child(b)
		FxUi.pulse(dot, 1.18, 1.3)
	_style_tabs()


## Each tab is an icon over its name; the open one is gold with a glowing
## line along the bar's top.
func _style_tabs() -> void:
	for k in TABS:
		var b: Button = _tab_btns[k]
		b.button_pressed = k == tab
		b.text = str(TAB_LOOK[k][0]).to_upper()
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP


## Opens tab `name_`, on sub-tab `sub` when it has them. The new page slides in
## from the side it sits on in the bar.
func show_tab(name_: String, sub := 0) -> void:
	if chest_opening or not TABS.has(name_):
		return
	if name_ == tab:
		_tab_btns[name_].button_pressed = true
		if _page is Sheet and is_instance_valid(_page) and (_page as Sheet).segment != sub:
			(_page as Sheet).show_segment(sub)
		return
	var dir := signf(TABS.find(name_) - TABS.find(tab))
	_leave_page()
	tab = name_
	_style_tabs()
	FxUi.pop(_tab_btns[tab], 1.12)
	Sfx.play("ui_toggle", -6.0)
	%Safe.visible = tab == "hunt"
	%Shade.visible = tab == "hunt"
	if tab == "hunt":
		refresh()
		return
	match tab:
		"heroes":
			var eq := Equipment.new()
			eq.tab_mode = true
			equipment = eq
			_page = eq
			%Pages.add_child(eq)
			eq.open(self)
		"clan":
			_page = _make_page("Clan", [["Clan", _build_social]], sub)
		"shop":
			_page = _make_page("Shop", Shop.segments(self), sub)
	if dir != 0.0:
		var w := get_viewport().get_visible_rect().size.x
		_page.position.x = dir * w * 0.35
		_page.modulate.a = 0.0
		var t := _page.create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		t.tween_property(_page, "position:x", 0.0, 0.22)
		t.tween_property(_page, "modulate:a", 1.0, 0.16)


func _make_page(title: String, segs: Array, sub: int) -> Sheet:
	var s := Sheet.new()
	s.page = true
	s.segments = segs
	s.segment = clampi(sub, 0, segs.size() - 1)
	%Pages.add_child(s)
	s.open(title, segs[s.segment][1])
	return s


func _leave_page() -> void:
	if _page and is_instance_valid(_page):
		if _page is Equipment:
			(_page as Equipment).leave()
		else:
			_page.queue_free()
	_page = null
	equipment = null


## A quick swipe left or right moves one tab over, anywhere but the open 3D
## camp (a drag there turns the hero) and the equipment stage (same there).
func _input(e: InputEvent) -> void:
	if chest_opening or (_sheet and is_instance_valid(_sheet)):
		return
	if e is InputEventScreenTouch:
		var t := e as InputEventScreenTouch
		var vp := get_viewport().get_visible_rect().size
		if t.pressed and _sw_index < 0:
			if tab == "hunt" and t.position.y < vp.y * 0.55:
				return
			if equipment and is_instance_valid(equipment) and equipment.blocks_swipe(t.position):
				return
			_sw_index = t.index
			_sw_from = t.position
			_sw_t = Time.get_ticks_msec() / 1000.0
		elif not t.pressed and t.index == _sw_index:
			_sw_index = -1
			var d := t.position - _sw_from
			var quick := Time.get_ticks_msec() / 1000.0 - _sw_t < 0.6
			if quick and absf(d.x) > 150.0 and absf(d.y) < absf(d.x) * 0.5:
				var i := TABS.find(tab) + (-1 if d.x > 0.0 else 1)
				if i >= 0 and i < TABS.size():
					show_tab(TABS[i])


# --- Chest ---------------------------------------------------------------

func _chest_ready() -> bool:
	return lobby.main != null and str(lobby.main.pending_chest) != ""


## The chest slot is always there, so the best moment has a fixed home; empty,
## it says how to fill it.
func _refresh_chest_slot() -> void:
	if _chest_ready():
		var c: Dictionary = DB.CHESTS[lobby.main.pending_chest]
		%ChestLabel.text = "OPEN"
		%Chest.modulate = Color.WHITE
		%Chest.add_theme_color_override("icon_normal_color", c["color"] if c.has("color") else Color(1, 0.85, 0.5))
	else:
		%ChestLabel.text = "NO CHEST"
		%Chest.modulate = Color(1, 1, 1, 0.6)
		%Chest.add_theme_color_override("icon_normal_color", Color(0.6, 0.57, 0.52))


func show_chest(kind: String) -> void:
	var c: Dictionary = DB.CHESTS[kind]
	%Chest.tooltip_text = "Open your %s" % c["name"]
	_refresh_chest_slot()
	Ui.pop_in(%Chest, 0.4, 0.6)
	# A rattle every couple of seconds: something is waiting in there.
	FxUi.shake(%Chest)


func _on_chest_slot() -> void:
	if _chest_ready():
		_open_chest()
	else:
		Sfx.play("ui_tap", -6.0)
		_float_text(%ChestLabel, "Win a hunt to earn one", Color(0.9, 0.85, 0.75))


func _open_chest() -> void:
	if chest_opening or lobby.main == null:
		return
	var kind: String = lobby.main.pending_chest
	if kind == "":
		return
	show_tab("hunt")
	chest_opening = true
	%Safe.visible = false
	%NavBar.visible = false
	var ov := preload("res://src/lobby/chest_open.gd").new()
	ov.deal = _bought_deal
	%Overlay.add_child(ov)
	ov.open(self, kind)


## A chest bought in the Shop opens like a won one: it goes ahead of any chest
## waiting in the slot (which comes back after), and it is paid for when the
## lid opens, so closing the app first costs nothing.
func open_bought_chest(kind: String, deal := -1) -> void:
	if chest_opening or lobby.main == null:
		return
	var m = lobby.main
	if str(m.pending_chest) != "":
		m.chest_queue.push_front(m.pending_chest)
	m.pending_chest = kind
	lobby.place_chest(kind)
	_bought_deal = deal
	_open_chest()


func chest_done() -> void:
	chest_opening = false
	%Safe.visible = true
	%NavBar.visible = true
	FxUi.still(%Chest)
	lobby.remove_chest()
	refresh()
	if _bought_deal != -2:
		_bought_deal = -2
		show_tab("shop")


# --- Sheets --------------------------------------------------------------

func open_equipment() -> void:
	show_tab("heroes")


## Opens a sheet by its old name: the ones that became tabs open their tab on
## the right sub-tab; the rest slide up over whatever is showing.
func open_sheet(name_: String) -> void:
	# Skins are sold in one place: the Shop's Skins tab, on the hero shown.
	if name_ == "looks":
		Shop.skins_hero = _shown_hero
		if _sheet and is_instance_valid(_sheet):
			_sheet.queue_free()
			_sheet = null
		if tab == "shop":
			(_page as Sheet).rebuild()
		else:
			show_tab("shop")
		Shop.focus_skins(_page)
		return
	if SHEET_TAB.has(name_):
		var to: Array = SHEET_TAB[name_]
		show_tab(str(to[0]), int(to[1]))
		return
	if _sheet and is_instance_valid(_sheet):
		_sheet.queue_free()
	if name_ == "chest":
		_open_chest()
		return
	if name_ == "road":
		var road := TrophyRoad.new()
		%Overlay.add_child(road)
		road.open(self)
		road.closed.connect(_sheet_closed)
		return
	_sheet = Sheet.new()
	_sheet_name = name_
	%Overlay.add_child(_sheet)
	match name_:
		"expedition":
			_sheet.open("Expedition", _build_expedition)
		"daily_sheet", "daily":
			_sheet.open("Daily", _build_daily)
		"journal":
			_sheet.open("Quests", _build_journal)
		"story":
			_sheet.open("Story", _build_story)
		"bounties":
			_sheet.open("Bounties", _build_bounties)
		"season":
			_sheet.open("Season", _build_season)
		"event":
			_sheet.open("Weekly Event", _build_event)
		"feats":
			_sheet.open("Feats", _build_feats)
		"log":
			_sheet.open("Log", _build_log)
		"settings":
			_sheet.open("Settings", _build_settings, 0.8)
		"profile":
			_sheet.open("Profile", _build_profile)
		"hero":
			_sheet.open(str(DB.HEROES[_shown_hero]["name"]), _build_hero_sheet)
		"skills":
			_sheet.open("Skills", _build_skills)
		"talents":
			_sheet.open("Talents", _build_talents)
		"sidekicks":
			_sk_detail = ""
			_sheet.open("Sidekicks", _build_sidekicks)
		_:
			if not _open_social_sheet(_sheet, name_):
				_sheet.queue_free()
				_sheet = null
				return
	_sheet.closed.connect(_sheet_closed)


## A claim or upgrade in a sheet changes the tiles and cards under it.
func _sheet_closed() -> void:
	refresh()
	# Use (in the hero card) may have switched heroes under the gear screen.
	if equipment and is_instance_valid(equipment):
		if equipment.hero_id != Game.hero_id():
			equipment._show_hero(Game.hero_id())
		else:
			equipment._refresh()
	if tab in ["clan", "shop"] and _page is Sheet and is_instance_valid(_page):
		(_page as Sheet).rebuild()


## The portraits finished rendering after the Heroes page was already opened.
func portraits_ready() -> void:
	if equipment and is_instance_valid(equipment):
		equipment._refresh()
