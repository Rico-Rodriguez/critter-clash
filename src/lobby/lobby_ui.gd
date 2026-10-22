class_name LobbyUI
extends "res://src/lobby/lobby_ui_social.gd"
## The camp's interface: a bar of five tabs along the bottom (Heroes, Gear,
## Hunt, Clan, Journal), swiped or tapped like Clash Royale's. Hunt is home:
## the player plate, the season, the side rails, the hero by the fire and the
## chest · hunt · road row. The other tabs are full pages above the bar;
## Expedition, Settings and the profile still slide up as sheets.
##
## Split into a chain of scripts: lobby_ui_widgets (fields, widgets) <
## lobby_ui_hero_sheets < lobby_ui_sheets < lobby_ui_social < lobby_ui
## (setup, home, tabs, chest, opening sheets).

const TABS := ["heroes", "gear", "hunt", "clan", "journal"]
const TAB_LOOK := {
	"heroes": ["Heroes", "visored-helm"],
	"gear": ["Gear", "swap-bag"],
	"hunt": ["Hunt", "crossed-swords"],
	"clan": ["Clan", "checked-shield"],
	"journal": ["Journal", "book-cover"],
}
## Which tab and sub-tab each old sheet name lands on.
const SHEET_TAB := {
	"heroes": ["heroes", 0], "skills": ["heroes", 1], "talents": ["heroes", 2],
	"bag": ["gear", 0],
	"bounties": ["journal", 0], "road": ["journal", 0], "daily": ["journal", 0],
	"season": ["journal", 1], "feats": ["journal", 2], "log": ["journal", 3],
	"journal": ["journal", 0], "clan": ["clan", 0], "friends": ["clan", 1],
}
const NAV_H := 128.0

var tab := "hunt"
var _page: Control
var _tab_btns := {}
var _tab_dots := {}
var _rail_r: VBoxContainer
var _bounty_badge: PanelContainer
var _bounty_count: Label
var _bounty_time: Label
## A horizontal swipe in progress: where and when the finger went down.
var _sw_from := Vector2.ZERO
var _sw_t := -1.0
var _sw_index := -1


func setup(l: Node3D) -> void:
	lobby = l
	Ui.apply_safe_area(%Safe)
	var ins := Ui.safe_insets(0)
	# The home stops above the tab bar; the bar itself clears the home bar.
	%Safe.add_theme_constant_override("margin_bottom", int(NAV_H + ins.w) + 14)
	%NavBar.offset_top = -(NAV_H + ins.w)
	%M.add_theme_constant_override("margin_bottom", int(ins.w))
	%Pages.offset_bottom = -(NAV_H + ins.w)
	_shown_hero = Game.hero_id()
	Game.refresh_bounties()
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
	%Season.pressed.connect(func(): open_sheet("season"))
	%Road.pressed.connect(func(): open_sheet("road"))
	%RoadIcon.texture = Ui.icon("trophy")
	# Mode, place and difficulty change rarely, so the camp shows one summary
	# card and the choices live in a sheet behind it.
	%Expedition.pressed.connect(func(): open_sheet("expedition"))
	%GoldIcon.texture = Ui.icon("two-coins")
	_build_tabs()
	_build_side()
	_goal = Ui.label("", "Small", HORIZONTAL_ALIGNMENT_CENTER)
	_goal.add_theme_color_override("font_color", Color(0.95, 0.85, 0.6))
	%HeroBox.add_child(_goal)
	Game.changed.connect(refresh)
	_social_setup()
	refresh()
	_count_gold_in()


func refresh() -> void:
	%Gold.text = Ui.fmt_num(Game.gold())
	var id := _shown_hero
	var d: Dictionary = DB.HEROES[id]
	var h := Game.hero(id)
	%Combat.text = str(Game.combat_level(id))
	%PlayerName.text = Game.player_name()
	%PlayerSub.text = "%s · Combat %d" % [_clan_line(), Game.combat_level(id)]
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
	%ExpTier.text = str(t["name"]).to_upper() + (" · OMEN" if not Game.active_omen(Game.mode_id()).is_empty() else "") + " · %s / %s" % [Ui.fmt_num(pw), Ui.fmt_num(rec)]
	%ExpTier.add_theme_color_override("font_color", t["color"] if pw >= rec else Color(1.0, 0.45, 0.4))
	# Season plaque.
	var lv := Game.season_level()
	%SeasonText.text = "%s · TIER %d" % [Game.season_name().to_upper(), lv]
	%SeasonBar.value = 100.0 if lv >= DB.SEASON_TIERS else float(int(Game.season()["xp"]) % DB.SEASON_XP) / DB.SEASON_XP * 100.0
	%SeasonBadge.visible = Game.season_claimable() > 0
	# The road: a trophy with a bar, like the trophy road beside Battle.
	var steps := Game.road_claimable()
	var nxt := int(Game.data["road"]) + 1
	%RoadText.text = "READY" if steps > 0 else "%d / %d" % [Game.renown(), DB.road_threshold(nxt)]
	%RoadBar.value = 100.0 if steps > 0 else maxf(Game.road_fill() * 100.0, 3.0)
	%RoadBadge.visible = steps > 0
	_refresh_chest_slot()
	# Tab dots: something to do behind that tab.
	_tab_dots["heroes"].visible = _any_upgrade()
	_tab_dots["gear"].visible = Game.new_item_count() > 0
	_tab_dots["journal"].visible = Game.bounty_claimable() > 0 or steps > 0 or Game.season_claimable() > 0 or Game.achievement_claimable() > 0
	_tab_dots["clan"].visible = _social_dot()
	if _goal:
		# The closest thing worth chasing: something is always about to happen.
		_goal.text = Game.next_goal()
		_goal.visible = _goal.text != ""
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
var _guide: Control


## The first visit shows the hero, the hunt and the tabs; the side rails,
## season and road join after the first hunt, when they mean something.
func _first_steps() -> void:
	var fresh := int(Game.data["stats"]["hunts"]) == 0
	if _side:
		_side.visible = not fresh
	if _rail_r:
		_rail_r.visible = not fresh
	%Road.modulate.a = 0.45 if fresh else 1.0
	%Season.get_parent().visible = not fresh
	_coach.call_deferred()


## Points at the first thing a new player hasn't been shown yet. Each note
## shows once per save.
func _coach() -> void:
	if is_instance_valid(_guide) or not camp_idle() or not is_inside_tree():
		return
	var tips: Dictionary = Game.data["tips"]
	var played := int(Game.data["stats"]["hunts"]) > 0
	for st in [
		["camp_hunt", not played, %Hunt, "Your first hunt", "Drag to move; you attack on your own. Survive the horde, pick a power each level, then beat the boss.", false],
		["camp_chest", _chest_ready(), %Chest, "A chest!", "Your win earned it. Tap to open it.", false],
		["camp_gear", played and Game.new_item_count() > 0, _tab_btns["gear"], "New gear", "Put on what you found: better gear is the fastest way to grow.", false],
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


# --- Side rails: daily and campfire left, bounties right ---------------------

func _build_side() -> void:
	_side = VBoxContainer.new()
	_side.add_theme_constant_override("separation", 12)
	_side.position = Vector2(0, 14)
	%Space.add_child(_side)
	for spec in [["daily", "sun", "Daily"], ["idle", "campfire", "Campfire"]]:
		_side.add_child(_rail_button(spec[0], spec[1], spec[2]))
	_rail_r = VBoxContainer.new()
	_rail_r.add_theme_constant_override("separation", 0)
	# A fixed width at the right edge, wide enough for the label under the button.
	_rail_r.anchor_left = 1.0
	_rail_r.anchor_right = 1.0
	_rail_r.offset_left = -104.0
	_rail_r.offset_top = 14.0
	_rail_r.alignment = BoxContainer.ALIGNMENT_BEGIN
	%Space.add_child(_rail_r)
	var bc := _rail_button("bounties", "archery-target", "Bounties")
	bc.get_child(0).size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_rail_r.add_child(bc)
	_bounty_badge = _side_badges["bounties"]
	_bounty_count = Ui.label("", "BadgeLabel", HORIZONTAL_ALIGNMENT_CENTER)
	_bounty_badge.add_child(_bounty_count)
	_bounty_time = Ui.label("", "Small", HORIZONTAL_ALIGNMENT_CENTER)
	_bounty_time.add_theme_font_size_override("font_size", 14)
	bc.add_child(_bounty_time)


func _rail_button(key: String, icon: String, text: String) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	var b := Button.new()
	b.theme_type_variation = &"RoundButton"
	b.custom_minimum_size = Vector2(80, 80)
	b.icon = Ui.icon(icon)
	b.expand_icon = true
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(func(): _side_pressed(key))
	var badge := PanelContainer.new()
	badge.theme_type_variation = &"Badge"
	badge.custom_minimum_size = Vector2(24, 24)
	badge.position = Vector2(58, -4)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.visible = false
	b.add_child(badge)
	_side_badges[key] = badge
	col.add_child(b)
	var l := Ui.label(text, "Caption", HORIZONTAL_ALIGNMENT_CENTER)
	l.add_theme_font_size_override("font_size", 15)
	col.add_child(l)
	if key == "idle":
		_idle_label = l
	return col


func _refresh_side() -> void:
	if _side == null:
		return
	var login := Game.login_status()
	_side_badges["daily"].visible = bool(login["ready"])
	var g := Game.idle_gold()
	_side_badges["idle"].visible = g >= 50
	_idle_label.text = "+%d" % g if g >= 50 else "Campfire"
	var ready_n := Game.bounty_claimable()
	_bounty_badge.visible = ready_n > 0
	_bounty_count.text = str(ready_n)
	var left := 86400 - int(Time.get_unix_time_from_system()) % 86400
	_bounty_time.text = "%dh %02dm" % [left / 3600, (left % 3600) / 60]


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
			open_sheet("daily_sheet")
		"bounties":
			open_sheet("bounties")


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
	for key in TABS:
		var b := Button.new()
		b.theme_type_variation = &"NavTab"
		b.toggle_mode = true
		b.button_pressed = key == tab
		b.text = str(TAB_LOOK[key][0]).to_upper()
		b.icon = Ui.icon(TAB_LOOK[key][1])
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		b.expand_icon = true
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.size_flags_stretch_ratio = 1.45 if key == tab else 1.0
		var k: String = key
		b.pressed.connect(func(): show_tab(k))
		var dot := PanelContainer.new()
		dot.theme_type_variation = &"Badge"
		dot.custom_minimum_size = Vector2(24, 24)
		dot.anchor_left = 0.5
		dot.anchor_right = 0.5
		dot.offset_left = 18.0
		dot.offset_top = 10.0
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dot.visible = false
		b.add_child(dot)
		_tab_btns[key] = b
		_tab_dots[key] = dot
		%Tabs.add_child(b)


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
	for k in TABS:
		_tab_btns[k].button_pressed = k == tab
		_tab_btns[k].size_flags_stretch_ratio = 1.45 if k == tab else 1.0
	Sfx.play("ui_toggle", -6.0)
	%Safe.visible = tab == "hunt"
	%Shade.visible = tab == "hunt"
	if tab == "hunt":
		refresh()
		return
	match tab:
		"gear":
			var eq := Equipment.new()
			eq.tab_mode = true
			equipment = eq
			_page = eq
			%Pages.add_child(eq)
			eq.open(self)
		"heroes":
			_page = _make_page("Heroes", [["Heroes", _build_heroes], ["Skills", _hero_picked.bind(_build_skills)], ["Talents", _hero_picked.bind(_build_talents), _any_upgrade()]], sub)
		"journal":
			var dot_today := Game.bounty_claimable() > 0 or Game.road_claimable() > 0 or bool(Game.login_status()["ready"])
			_page = _make_page("Journal", [["Today", _build_today, dot_today], ["Season", _build_season, Game.season_claimable() > 0], ["Feats", _build_feats, Game.achievement_claimable() > 0], ["Log", _build_log]], sub)
		"clan":
			_page = _make_page("Clan", _social_segments(), sub)
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


## Skills and talents belong to one hero: a row of names on top picks which.
func _hero_picked(s: Sheet, build: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	for id in DB.HERO_ORDER:
		if not Game.hero(id)["unlocked"]:
			continue
		var b := Button.new()
		b.theme_type_variation = &"Choice"
		b.toggle_mode = true
		b.button_pressed = id == _shown_hero
		b.text = DB.HEROES[id]["name"]
		b.custom_minimum_size = Vector2(0, 60)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 20)
		var hid: String = id
		b.pressed.connect(func():
			_shown_hero = hid
			Game.set_hero(hid)
			lobby.show_hero(hid)
			refresh()
			s.rebuild())
		row.add_child(b)
	s.body.add_child(row)
	build.call(s)


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
	# A slow pulse so the slot reads as "something is waiting".
	var pulse := %Chest.create_tween().set_loops()
	%Chest.pivot_offset = %Chest.custom_minimum_size * 0.5
	pulse.tween_property(%Chest, "scale", Vector2.ONE * 1.06, 0.7).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(%Chest, "scale", Vector2.ONE, 0.7).set_trans(Tween.TRANS_SINE)


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
	%Overlay.add_child(ov)
	ov.open(self, kind)


func chest_done() -> void:
	chest_opening = false
	%Safe.visible = true
	%NavBar.visible = true
	%Chest.scale = Vector2.ONE
	lobby.remove_chest()
	refresh()


# --- Sheets --------------------------------------------------------------

func open_equipment() -> void:
	show_tab("gear")


## Opens a sheet by its old name: the ones that became tabs open their tab on
## the right sub-tab; the rest slide up over whatever is showing.
func open_sheet(name_: String) -> void:
	if SHEET_TAB.has(name_):
		var to: Array = SHEET_TAB[name_]
		show_tab(str(to[0]), int(to[1]))
		return
	if _sheet and is_instance_valid(_sheet):
		_sheet.queue_free()
	if name_ == "chest":
		_open_chest()
		return
	_sheet = Sheet.new()
	_sheet_name = name_
	%Overlay.add_child(_sheet)
	match name_:
		"expedition":
			_sheet.open("Expedition", _build_expedition)
		"daily_sheet":
			_sheet.open("Daily", _build_daily)
		"settings":
			_sheet.open("Settings", _build_settings, 0.8)
		"profile":
			_sheet.open("Profile", _build_profile)
		_:
			if not _open_social_sheet(_sheet, name_):
				_sheet.queue_free()
				_sheet = null
				return
	_sheet.closed.connect(refresh)


## The portraits finished rendering after the Heroes page was already opened.
func portraits_ready() -> void:
	if tab == "heroes" and _page is Sheet and is_instance_valid(_page):
		(_page as Sheet).rebuild()
