extends "res://src/lobby/lobby_ui_sheets.gd"
## The camp screen, part 4: the Clan tab (clan and chat, friends, invites and
## rewards for bringing friends, rankings), parties, the profile and account
## sheet, the gift popup, and the hooks the rest of the camp reads (the clan
## line under the player's name, the Clan tab's dot).
##
## Everything online goes through Online.inst (src/net/online.gd), which is
## null in the headless checks and may be offline at any moment: each screen
## says so plainly instead of waiting.

const Online := preload("res://src/net/online.gd")

const BADGES := ["checked-shield", "skull-crossed-bones", "crowned-skull", "wolf-head", "flame", "moon",
	"sun", "crossed-axes", "castle", "ghost", "rune-stone", "round-star"]
const BADGE_COLORS := [Color("e8b45a"), Color("d9d4c7"), Color("c9a2ff"), Color("8fb3c9"), Color("ff8a3d"), Color("9ab8ff"),
	Color("ffd75e"), Color("e06a5a"), Color("b8a07a"), Color("a6f0d0"), Color("7fd7ff"), Color("f5a3d0")]
const ROLE_NAME := ["Leader", "Elder", "Member", "Wants to join"]
const PARTY_BLUE := Color("4f8de0")
const GOLD := Color(0.91, 0.71, 0.35)

var _chat_box: VBoxContainer
var _chat_scroll_to_end := false
var _requests_n := 0
## The player whose sheet is open: {id, name}.
var _player := {}
var _toast_label: Label
## Something changed while the player was typing; rebuild when they stop.
var _dirty := false
var _clan_form := {"name": "", "desc": "", "badge": 0, "open": true, "min_combat": 0}
## Second taps confirm risky buttons (leave, kick, delete): id -> time.
var _armed := {}


func _net() -> Node:
	return Online.inst


func _social_setup() -> void:
	var o := _net()
	if o == null:
		return
	o.state_changed.connect(_social_refresh)
	o.social_changed.connect(_social_refresh)
	o.chat_message.connect(_on_chat)
	o.gifts_arrived.connect(func(_list): _show_gifts.call_deferred())
	o.notice.connect(_toast)
	o.party.changed.connect(_social_refresh)
	# Gifts that landed while a hunt was on.
	_show_gifts.call_deferred()


func _process(_dt: float) -> void:
	_lift_for_keyboard()
	if _dirty and not _typing():
		_dirty = false
		_social_refresh()


## Under the player's name: the clan, or "No clan".
func _clan_line() -> String:
	var n := str(Game.data["online"]["clan_name"])
	return n if n != "" else "No clan"


func _social_dot() -> bool:
	var o := _net()
	if o == null or not o.is_on():
		return false
	return o.unread() > 0 or _requests_n > 0 or o.can_redeem()


## Sheets that belong to the social part; false when `name_` is not one.
func _open_social_sheet(s: Sheet, name_: String) -> bool:
	match name_:
		"clans":
			s.open("Clans", _build_find_clan)
		"chat":
			s.open(_clan_line(), _build_chat, 0.94)
		"friends":
			s.open("Add friends", _build_friends)
		"invite":
			s.open("Invite a friend", _build_invite)
		"ranks":
			s.open("Ranks", _build_ranks)
		"clan_create":
			s.open("New clan", _build_clan_create)
		"clan_members":
			s.open("Members", _build_members)
		"player":
			s.open(str(_player.get("name", "Hunter")), _build_player, 0.8)
		"gifts":
			s.open("Gifts!", _build_gifts, 0.7)
		"account":
			s.open("Account", _build_account)
		_:
			return false
	return true


func _social_refresh() -> void:
	if _net() == null or not is_inside_tree():
		return
	if _typing():
		_dirty = true
		return
	if tab == "clan" and _page is Sheet and is_instance_valid(_page):
		(_page as Sheet).rebuild()
	if _sheet and is_instance_valid(_sheet) and _sheet_name in ["clan_members", "profile", "account", "friends"]:
		_sheet.rebuild()
	refresh()


func _typing() -> bool:
	return is_inside_tree() and get_viewport().gui_get_focus_owner() is LineEdit


## The on-screen keyboard covers the bottom of the screen: lift the page or
## sheet holding the text field above it.
func _lift_for_keyboard() -> void:
	var kb := float(DisplayServer.virtual_keyboard_get_height())
	if kb > 0.0 and _typing():
		kb *= get_viewport().get_visible_rect().size.y / float(DisplayServer.window_get_size().y)
	else:
		kb = 0.0
	var ins := Ui.safe_insets(0)
	if _sheet and is_instance_valid(_sheet):
		_sheet.position.y = -kb
	%Pages.position.y = -maxf(0.0, kb - NAV_H - ins.w)


# --- Small pieces --------------------------------------------------------------

func _wrap_label(text: String, variation := "Body") -> Label:
	var l := Ui.label(text, variation)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


func _button(text: String, variation: String, cb: Callable, h := 72.0) -> Button:
	var b := Button.new()
	b.text = text
	b.theme_type_variation = variation
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, h)
	b.pressed.connect(func():
		Sfx.play("ui_tap", -4.0)
		cb.call())
	return b


## A button that asks for a second tap within 3 seconds before it acts.
func _confirm_button(text: String, ask: String, variation: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.theme_type_variation = variation
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 68)
	var key := str(b.get_instance_id())
	b.pressed.connect(func():
		var now := Time.get_ticks_msec() / 1000.0
		if now - float(_armed.get(key, -10.0)) < 3.0:
			_armed.erase(key)
			cb.call()
			return
		_armed[key] = now
		Sfx.play("ui_tap", -4.0)
		b.text = ask
		get_tree().create_timer(3.0).timeout.connect(func():
			if is_instance_valid(b) and _armed.has(key):
				_armed.erase(key)
				b.text = text))
	return b


func _field(placeholder: String, text := "", max_len := 200) -> LineEdit:
	var e := LineEdit.new()
	e.placeholder_text = placeholder
	e.text = text
	e.max_length = max_len
	e.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	e.custom_minimum_size = Vector2(0, 72)
	e.virtual_keyboard_enabled = true
	return e


func _badge(i: int, size_: float) -> Panel:
	i = clampi(i, 0, BADGES.size() - 1)
	return _disc(BADGES[i], BADGE_COLORS[i], size_)


func _dot(on: bool) -> Panel:
	var p := Panel.new()
	p.custom_minimum_size = Vector2(16, 16)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var st := StyleBoxFlat.new()
	st.bg_color = Color("4fae6a") if on else Color(1, 1, 1, 0.18)
	st.set_corner_radius_all(8)
	p.add_theme_stylebox_override("panel", st)
	return p


## A line that fades in at the top of the screen.
func _toast(text: String, col := Color(0.95, 0.9, 0.8)) -> void:
	if _toast_label and is_instance_valid(_toast_label):
		_toast_label.queue_free()
	var l := Ui.label(text, "HudLabel", HORIZONTAL_ALIGNMENT_CENTER)
	l.add_theme_font_size_override("font_size", 26)
	l.add_theme_color_override("font_color", col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	l.offset_top = Ui.safe_insets(0).y + 150.0
	l.offset_left = 30.0
	l.offset_right = -30.0
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	_toast_label = l
	var t := l.create_tween()
	l.modulate.a = 0.0
	t.tween_property(l, "modulate:a", 1.0, 0.2)
	t.tween_interval(2.6)
	t.tween_property(l, "modulate:a", 0.0, 0.5)
	t.tween_callback(l.queue_free)


## A slot filled when an online call returns; dropped if the screen moved on.
func _slot(parent: Control) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	parent.add_child(v)
	var wait := Ui.label("…", "Small", HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(wait)
	return v


## A slide-up sheet sized itself before its slot filled: size it again.
func _refit(s: Sheet) -> void:
	# After the sheet's slide-in (which ends at the height it had), and over
	# a few frames while wrapped labels settle their height.
	await get_tree().create_timer(0.4).timeout
	for i in 3:
		if not is_inside_tree():
			return
		await get_tree().process_frame
		if not is_instance_valid(s) or s.page:
			return
		s._fit()


func _fill(slot) -> bool:
	if not is_instance_valid(slot):
		return false
	Ui.clear(slot)
	return true


## When the game can't be online, says why (and offers what helps). True
## when online and the caller should build the real screen.
func _net_gate(b: Control) -> bool:
	var o := _net()
	var why := ""
	var retry := false
	if o == null or not o.configured():
		why = "Clans, friends and co-op hunts open when the camp server goes live. Your progress is safe on this phone."
	elif o.state == "off":
		why = "Online play is off. Turn it on under Profile › Account to join a clan and hunt with friends."
	elif o.state == "connecting":
		why = "Reaching the camp…"
	elif o.state == "down":
		why = "Can't reach the camp server right now. Everything else works offline."
		retry = true
	if why == "":
		return true
	var c := _card()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	c.add_child(v)
	v.add_child(_row([Ui.icon_rect("two-shadows", 56, GOLD), _wrap_label("Hunt together", "Heading")]))
	v.add_child(_wrap_label(why))
	if retry:
		v.add_child(_button("Try again", "PrimaryButton", func(): o.connect_now()))
	b.add_child(c)
	return false


# --- Clan --------------------------------------------------------------------------

## The Clan tab, after Clash Royale's Social panel: your clan (or a way into
## one) on top, the people you play with below, two big buttons at the foot.
func _build_social(s: Sheet) -> void:
	var b := s.body
	if not _net_gate(b):
		return
	var o := _net()
	b.add_child(_row([Ui.label("Code %s" % o.my_code(), "Small"), _spacer(),
		_icon_button("present", func(): open_sheet("invite"), o.can_redeem()),
		_icon_button("podium-winner", func(): open_sheet("ranks"), false)], 10))
	if o.in_clan():
		_build_my_clan(s)
	else:
		var c := _card()
		var tv := VBoxContainer.new()
		tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tv.add_theme_constant_override("separation", 2)
		tv.add_child(_wrap_label("Create or join a clan!", "Heading"))
		tv.add_child(_wrap_label("Chat, co-op hunts, a weekly raid", "Small"))
		var show := _button("Show", "GreenButton", func(): open_sheet("clans"), 72)
		show.custom_minimum_size.x = 140
		show.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		c.add_child(_row([Ui.icon_rect("checked-shield", 64, GOLD), tv, show], 14))
		b.add_child(c)
	if o.party.active():
		_build_party(b)
	var list := _card()
	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", 6)
	list.add_child(lv)
	lv.add_child(Ui.label("SOCIAL", "Caption"))
	_fill_social(_slot(lv))
	b.add_child(list)
	var party := _button("Party up", "BlueButton", _party_up, 84)
	party.icon = Ui.icon("shaking-hands")
	party.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	party.visible = not o.party.active()
	var add := _button("Add friends", "GreenButton", func(): open_sheet("friends"), 84)
	add.icon = Ui.icon("person")
	add.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if _requests_n > 0:
		add.add_child(_count_badge(_requests_n))
	s.footer.add_child(party)
	s.footer.add_child(add)


## A round icon button with an optional red dot (the header's gift and ranks).
func _icon_button(icon: String, cb: Callable, dot: bool) -> Button:
	var btn := Button.new()
	btn.theme_type_variation = "RoundButton"
	btn.icon = Ui.icon(icon)
	btn.expand_icon = true
	btn.custom_minimum_size = Vector2(72, 72)
	btn.focus_mode = Control.FOCUS_NONE
	btn.pressed.connect(cb)
	if dot:
		var d := _count_badge(0)
		d.position = Vector2(54, -4)
		btn.add_child(d)
	return btn


## A red corner badge with a count (or a plain dot for 0).
func _count_badge(n: int) -> PanelContainer:
	var d := PanelContainer.new()
	d.theme_type_variation = "Badge"
	d.position = Vector2(-6, -6)
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := Ui.label(str(n) if n > 0 else "!", "Small", HORIZONTAL_ALIGNMENT_CENTER)
	l.add_theme_color_override("font_color", Color.WHITE)
	d.add_child(l)
	return d


## Party up: open a party and post it in clan chat. Without a clan there is
## no one to tell yet, so point the way.
func _party_up() -> void:
	var o := _net()
	if not o.in_clan():
		_toast("Join a clan to party up")
		return
	var e: String = await o.party.create()
	if e != "":
		_toast(e, Color(1, 0.6, 0.5))
		return
	var e2: String = await o.party.invite_clan()
	_toast("Party posted in clan chat" if e2 == "" else e2)


## Friends and clanmates in one list, online first, then by power.
func _fill_social(slot: VBoxContainer) -> void:
	var o := _net()
	var people := {}
	var fr: Dictionary = await o.friends()
	if not is_instance_valid(slot):
		return
	var asks := 0
	if fr["ok"]:
		for f in fr["data"]:
			if int(f["state"]) == 2:
				asks += 1
			elif int(f["state"]) == 0:
				people[str(f["id"])] = {"id": str(f["id"]), "name": str(f["name"]), "online": bool(f["online"]), "line": ""}
	if asks != _requests_n:
		_requests_n = asks
		refresh()
	if o.in_clan():
		var mr: Dictionary = await o.clan_members()
		if not is_instance_valid(slot):
			return
		if mr["ok"]:
			for m in mr["data"]:
				var role := int(m["role"])
				if role < 3:
					people[str(m["id"])] = {"id": str(m["id"]), "name": str(m["name"]), "online": bool(m["online"]), "line": ROLE_NAME[role]}
	people.erase(o.user_id)
	var profs: Dictionary = await o.profiles(people.keys()) if not people.is_empty() else {}
	if not _fill(slot):
		return
	if asks > 0:
		slot.add_child(_button("%d friend request%s" % [asks, "" if asks == 1 else "s"], "GreenButton", func(): open_sheet("friends"), 64))
	if people.is_empty():
		slot.add_child(Ui.label("No one here yet", "Small", HORIZONTAL_ALIGNMENT_CENTER))
		return
	var rows: Array = people.values()
	for p in rows:
		p["power"] = int(profs.get(p["id"], {}).get("power", 0))
		var hid := str(profs.get(p["id"], {}).get("hero", ""))
		if str(p["line"]) == "":
			p["line"] = DB.HEROES[hid]["name"] if DB.HEROES.has(hid) else "Friend"
	rows.sort_custom(func(a, c): return a["power"] > c["power"] if a["online"] == c["online"] else a["online"])
	for p in rows:
		slot.add_child(_person_row(p))


func _person_row(p: Dictionary) -> Button:
	var btn := Button.new()
	btn.theme_type_variation = "CardButton"
	btn.focus_mode = Control.FOCUS_NONE
	btn.custom_minimum_size = Vector2(0, 84)
	var h := HBoxContainer.new()
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 18
	h.offset_right = -18
	h.add_theme_constant_override("separation", 14)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(h)
	var dot := _dot(bool(p["online"]))
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(dot)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 0)
	v.add_child(Ui.label(str(p["name"]), "Value"))
	v.add_child(Ui.label(str(p["line"]), "Small"))
	h.add_child(v)
	var pw := Ui.label(Ui.fmt_num(int(p["power"])), "Value")
	pw.add_theme_color_override("font_color", GOLD)
	pw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(pw)
	for ch in h.get_children():
		ch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var who := {"id": str(p["id"]), "name": str(p["name"])}
	btn.pressed.connect(func(): _open_player(who))
	return btn


func _build_find_clan(s: Sheet) -> void:
	var b := s.body
	var search := _field("Search clans by name", "", 20)
	var go := _button("Search", "PrimaryButton", func(): pass, 72)
	go.custom_minimum_size.x = 150
	b.add_child(_row([search, go]))
	var results := _slot(b)
	s.footer.add_child(_button("Start a clan", "GoldButton", func(): open_sheet("clan_create")))
	s.footer.get_child(0).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	go.pressed.connect(func(): _fill_clans(results, search.text))
	search.text_submitted.connect(func(t): _fill_clans(results, t))
	_fill_clans(results, "")


func _fill_clans(slot: VBoxContainer, query: String) -> void:
	var r: Dictionary = await _net().find_clans(query)
	if not _fill(slot):
		return
	if not r["ok"]:
		slot.add_child(_wrap_label(str(r["error"]), "Small"))
		return
	if r["data"].is_empty():
		slot.add_child(_wrap_label("No clans yet. Start one!", "Small"))
	var my_combat: int = _net().best_combat()
	for cl in r["data"]:
		var card := _card()
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 14)
		card.add_child(h)
		h.add_child(_badge(int(cl["badge"]), 76))
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_theme_constant_override("separation", 2)
		h.add_child(v)
		v.add_child(Ui.label(str(cl["name"]), "Value"))
		var line := "%d/%d members" % [int(cl["members"]), int(cl["max"])]
		v.add_child(Ui.label(line, "Small"))
		var too_low := my_combat < int(cl["min_combat"])
		var full := int(cl["members"]) >= int(cl["max"])
		var id := str(cl["id"])
		var jb := _button("Join" if cl["open"] else "Ask", "GreenButton", func(): _join_clan(id), 64)
		jb.custom_minimum_size.x = 120
		jb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		jb.disabled = too_low or full
		if too_low:
			jb.text = "Combat %d" % int(cl["min_combat"])
			jb.add_theme_font_size_override("font_size", 18)
		elif full:
			jb.text = "Full"
		h.add_child(jb)
		slot.add_child(card)
	if _sheet and is_instance_valid(_sheet) and _sheet_name == "clans":
		_refit(_sheet)


func _join_clan(id: String) -> void:
	var r: Dictionary = await _net().join_clan(id)
	if not r["ok"]:
		_toast(str(r["error"]), Color(1, 0.6, 0.5))
		return
	_toast("Asked to join. The leader will let you in." if r["asked"] else "Welcome to %s!" % _clan_line(), Color(0.7, 1, 0.75))
	Sfx.play("coin", -4.0)
	_social_refresh()


func _build_clan_create(s: Sheet) -> void:
	var b := s.body
	var f := _clan_form
	var name_e := _field("Clan name (3–20 letters)", str(f["name"]), 20)
	name_e.text_changed.connect(func(t): f["name"] = t)
	b.add_child(name_e)
	var desc_e := _field("A line about your clan (optional)", str(f["desc"]), 140)
	desc_e.text_changed.connect(func(t): f["desc"] = t)
	b.add_child(desc_e)
	b.add_child(Ui.label("BADGE", "Caption"))
	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	for i in BADGES.size():
		var btn := Button.new()
		btn.theme_type_variation = "Choice"
		btn.toggle_mode = true
		btn.button_pressed = int(f["badge"]) == i
		btn.focus_mode = Control.FOCUS_NONE
		btn.custom_minimum_size = Vector2(96, 96)
		var d := _badge(i, 72)
		d.position = Vector2(12, 12)
		btn.add_child(d)
		var n := i
		btn.pressed.connect(func():
			f["badge"] = n
			s.rebuild())
		grid.add_child(btn)
	b.add_child(grid)
	var open := CheckButton.new()
	open.text = "Anyone can join (off: they ask first)"
	open.button_pressed = bool(f["open"])
	open.focus_mode = Control.FOCUS_NONE
	open.toggled.connect(func(on): f["open"] = on)
	b.add_child(open)
	var mc := Ui.label("Minimum combat level: %d" % int(f["min_combat"]) if int(f["min_combat"]) > 0 else "Minimum combat level: none", "Body")
	mc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var minus := _button("−", "RoundButton", func():
		f["min_combat"] = maxi(0, int(f["min_combat"]) - 5)
		s.rebuild(), 64)
	var plus := _button("+", "RoundButton", func():
		f["min_combat"] = mini(120, int(f["min_combat"]) + 5)
		s.rebuild(), 64)
	minus.custom_minimum_size.x = 64
	plus.custom_minimum_size.x = 64
	b.add_child(_row([mc, minus, plus]))
	var err := _wrap_label("", "Small")
	err.add_theme_color_override("font_color", Color(1, 0.6, 0.5))
	b.add_child(err)
	var make := _button("Create clan", "GoldButton", func(): pass)
	make.pressed.connect(func():
		make.disabled = true
		var r: Dictionary = await _net().create_clan(str(f["name"]).strip_edges(), str(f["desc"]), int(f["badge"]), bool(f["open"]), int(f["min_combat"]))
		if not is_instance_valid(make):
			return
		make.disabled = false
		if not r["ok"]:
			err.text = str(r["error"])
			return
		_clan_form = {"name": "", "desc": "", "badge": 0, "open": true, "min_combat": 0}
		s.close()
		_toast("%s is yours. Invite your friends!" % _clan_line(), Color(0.7, 1, 0.75))
		_social_refresh())
	b.add_child(make)


## Your clan on the Clan tab: badge, name and Chat, with the raid under it.
## Tapping the name opens the members.
func _build_my_clan(s: Sheet) -> void:
	var o := _net()
	var card := _card()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	card.add_child(v)
	var badge_slot := Control.new()
	badge_slot.custom_minimum_size = Vector2(84, 84)
	var head := Button.new()
	head.flat = true
	head.focus_mode = Control.FOCUS_NONE
	head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.custom_minimum_size = Vector2(0, 84)
	for st_name in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		head.add_theme_stylebox_override(st_name, StyleBoxEmpty.new())
	head.pressed.connect(func(): open_sheet("clan_members"))
	var tv := VBoxContainer.new()
	tv.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tv.alignment = BoxContainer.ALIGNMENT_CENTER
	tv.add_theme_constant_override("separation", 2)
	tv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cname := Ui.label(_clan_line(), "Heading")
	cname.clip_text = true
	tv.add_child(cname)
	var sub := Ui.label("Members ›", "Small")
	tv.add_child(sub)
	head.add_child(tv)
	var chat := _button("Chat", "BlueButton", func(): open_sheet("chat"), 72)
	chat.icon = Ui.icon("conversation")
	chat.custom_minimum_size.x = 150
	chat.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if o.unread() > 0:
		chat.add_child(_count_badge(o.unread()))
	v.add_child(_row([badge_slot, head, chat], 14))
	s.body.add_child(card)
	_fill_clan_head(badge_slot, sub)
	_build_raid(v)


func _fill_clan_head(badge_slot: Control, sub: Label) -> void:
	var r: Dictionary = await _net().my_clan()
	if not r["ok"] or not is_instance_valid(badge_slot):
		return
	badge_slot.add_child(_badge(int(r["data"]["badge"]), 84))
	sub.text = "%d/%d members ›" % [int(r["data"]["members"]), int(r["data"]["max"])]


## The weekly raid boss: everyone's hunts wear it down.
func _build_raid(b: Control) -> void:
	var c := VBoxContainer.new()
	var slot := _slot(c)
	slot.add_theme_constant_override("separation", 6)
	b.add_child(c)
	var r: Dictionary = await _net().raid_status()
	if not _fill(slot) or not r["ok"] or r["data"].has("none"):
		if is_instance_valid(c):
			c.queue_free()
		return
	var d: Dictionary = r["data"]
	var boss_id := str(d.get("boss", "gravemaw"))
	var boss_name: String = DB.boss_def(boss_id)["name"] if DB.BOSSES.has(boss_id) else "Raid boss"
	var mx := maxi(1, int(d.get("max", 1)))
	var left := maxi(0, int(d.get("ends", 0)) - int(Time.get_unix_time_from_system()))
	var fallen := int(d.get("fallen", 0)) > 0
	var t := Ui.label(_dur(left), "Small")
	slot.add_child(_row([Ui.label(("RAID FELLED · " if fallen else "WEEKLY RAID · ") + boss_name.to_upper(), "Caption"), _spacer(), t]))
	var bar := ProgressBar.new()
	bar.theme_type_variation = "BossBar"
	bar.custom_minimum_size = Vector2(0, 26)
	bar.show_percentage = false
	bar.value = float(int(d.get("hp", 0))) / mx * 100.0
	slot.add_child(bar)


static func _dur(sec: int) -> String:
	if sec >= 86400:
		return "%dd %dh" % [sec / 86400, (sec % 86400) / 3600]
	return "%dh %dm" % [sec / 3600, (sec % 3600) / 60]


# --- Parties ---------------------------------------------------------------------------

func _build_party(b: Control) -> void:
	var p = _net().party
	var c := PanelContainer.new()
	c.theme_type_variation = "InviteCard"
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	c.add_child(v)
	b.add_child(c)
	v.add_child(_row([Ui.icon_rect("shaking-hands", 48, PARTY_BLUE.lightened(0.3)), _wrap_label("PARTY · +%d%% GOLD" % int(DB.PARTY_GOLD * 100), "Caption")]))
	var plan: Dictionary = p.plan
	if not plan.is_empty():
		v.add_child(Ui.label("%s · %s" % [DB.zone(str(plan.get("zone", "barrow")))["name"], DB.TIERS[clampi(int(plan.get("tier", 0)), 0, DB.TIERS.size() - 1)]["name"]], "Value"))
	for uid in p.members:
		var m: Dictionary = p.members[uid]
		var hero_name: String = DB.HEROES.get(str(m.get("hero", "knight")), DB.HEROES["knight"])["name"]
		var state_l := "Leader" if uid == p.leader else ("Ready" if m.get("ready", false) else "Getting ready…")
		var st := Ui.label(state_l, "Small")
		st.add_theme_color_override("font_color", Color("7fdc93") if state_l != "Getting ready…" else Color(0.7, 0.68, 0.62))
		v.add_child(_row([_dot(true), Ui.label("%s · %s" % [str(m.get("name", "Hunter")), hero_name], "Body"), _spacer(), st]))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	if p.is_leader():
		var start := _button("Start hunt", "GreenButton", func(): p.go())
		start.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		start.disabled = not p.all_ready()
		if start.disabled:
			start.text = "Waiting for party" if p.members.size() < 2 else "Waiting for ready"
		row.add_child(start)
		row.add_child(_button("Re-post", "Ghost", func():
			var e: String = await p.invite_clan()
			_toast("Party posted in clan chat" if e == "" else e)))
	else:
		var me: Dictionary = p.members.get(_net().user_id, {})
		var rd := _button("Not ready" if me.get("ready", false) else "Ready!", "BlueButton", func():
			p.hello(not bool(p.members.get(_net().user_id, {}).get("ready", false))))
		rd.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(rd)
	row.add_child(_button("Leave", "Ghost", func(): p.leave()))
	v.add_child(row)


# --- Chat ---------------------------------------------------------------------------------

func _build_chat(s: Sheet) -> void:
	var b := s.body
	var o := _net()
	_chat_box = VBoxContainer.new()
	_chat_box.add_theme_constant_override("separation", 10)
	b.add_child(_chat_box)
	if o.clan_log.is_empty():
		_chat_box.add_child(_wrap_label("No messages yet. Say hi!", "Small"))
	# Runs of the same clan news ("A new hunter joined") fold into one line.
	var last_news := ""
	var run := 0
	for m in o.clan_log:
		var news := Online.message_text(m) if str(m["kind"]) == "system" else ""
		if news != "" and news == last_news:
			run += 1
			(_chat_box.get_child(_chat_box.get_child_count() - 1) as Label).text = "%s ×%d" % [news, run]
			continue
		last_news = news
		run = 1
		_chat_box.add_child(_bubble(m))
	var emotes := HFlowContainer.new()
	emotes.add_theme_constant_override("h_separation", 8)
	emotes.add_theme_constant_override("v_separation", 8)
	for id in Online.EMOTES:
		var eid: String = id
		var eb := _button(Online.EMOTE_TEXT[id], "Chip", func(): _send({"t": "emote", "id": eid}), 54)
		eb.add_theme_font_size_override("font_size", 20)
		emotes.add_child(eb)
	b.add_child(emotes)
	var input := _field("Message", "", 200)
	input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var send := _button("Send", "PrimaryButton", func(): pass, 72)
	send.custom_minimum_size.x = 130
	var do_send := func():
		var t := input.text.strip_edges()
		if t == "":
			return
		input.text = ""
		input.release_focus()
		_send({"t": "text", "body": t})
	send.pressed.connect(do_send)
	input.text_submitted.connect(func(_t): do_send.call())
	s.footer.add_child(input)
	s.footer.add_child(send)
	o.mark_chat_read()
	_scroll_chat_end(s)


func _scroll_chat_end(s: Sheet) -> void:
	for i in 2:
		if not is_inside_tree():
			return
		await get_tree().process_frame
	if is_instance_valid(s) and is_instance_valid(_chat_box):
		var sc: ScrollContainer = s._scroll
		sc.scroll_vertical = int(_chat_box.position.y + _chat_box.size.y)


func _send(content: Dictionary) -> void:
	var e: String = await _net().send_chat(content)
	if e != "":
		_toast(e, Color(1, 0.6, 0.5))


func _on_chat(msg: Dictionary) -> void:
	if _chat_box and is_instance_valid(_chat_box):
		if _chat_box.get_child_count() == 1 and _chat_box.get_child(0) is Label:
			_chat_box.get_child(0).queue_free()
		_chat_box.add_child(_bubble(msg))
		_net().mark_chat_read()
		if _sheet and is_instance_valid(_sheet) and _sheet_name == "chat":
			_scroll_chat_end(_sheet)
	elif not bool(msg["mine"]):
		refresh()


func _bubble(m: Dictionary) -> Control:
	var kind := str(m["kind"])
	var text := Online.message_text(m)
	if kind in ["raid", "system"]:
		var l := _wrap_label(text, "Small")
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_color_override("font_color", GOLD)
		return l
	if kind == "invite":
		var c := PanelContainer.new()
		c.theme_type_variation = "InviteCard"
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 8)
		c.add_child(v)
		var inv: Dictionary = m["c"]
		var where: String = DB.zone(str(inv.get("zone", "barrow")))["name"]
		var tier: String = DB.TIERS[clampi(int(inv.get("tier", 0)), 0, DB.TIERS.size() - 1)]["name"]
		v.add_child(_wrap_label("%s wants to hunt together" % str(m["name"]), "Value"))
		v.add_child(Ui.label("%s · %s" % [where, tier], "Small"))
		var pid := str(inv.get("party", ""))
		var p = _net().party
		if not bool(m["mine"]) and p.id != pid and Time.get_unix_time_from_system() - int(m["at"]) < 3600:
			v.add_child(_button("Join party", "BlueButton", func():
				var e: String = await p.join(pid)
				_toast("Joined! Tap Ready when you are." if e == "" else e, Color(0.7, 0.85, 1.0) if e == "" else Color(1, 0.6, 0.5)), 64))
		return c
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 0)
	var bub := PanelContainer.new()
	bub.theme_type_variation = "BubbleMine" if m["mine"] else "Bubble"
	bub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bub.size_flags_stretch_ratio = 3.0
	var v2 := VBoxContainer.new()
	v2.add_theme_constant_override("separation", 2)
	bub.add_child(v2)
	if not m["mine"]:
		var nb := Button.new()
		nb.text = str(m["name"])
		nb.theme_type_variation = "Ghost"
		nb.flat = true
		nb.alignment = HORIZONTAL_ALIGNMENT_LEFT
		nb.focus_mode = Control.FOCUS_NONE
		nb.add_theme_font_size_override("font_size", 20)
		nb.add_theme_color_override("font_color", GOLD)
		for st_name in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
			nb.add_theme_stylebox_override(st_name, StyleBoxEmpty.new())
		var who := {"id": str(m["from"]), "name": str(m["name"])}
		nb.pressed.connect(func(): _open_player(who))
		v2.add_child(nb)
	var body := _wrap_label(text, "Body")
	if kind == "emote":
		body.add_theme_font_size_override("font_size", 34)
	v2.add_child(body)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gap.size_flags_stretch_ratio = 1.0
	if m["mine"]:
		h.add_child(gap)
		h.add_child(bub)
	else:
		h.add_child(bub)
		h.add_child(gap)
	return h


# --- Members ---------------------------------------------------------------------

func _build_members(s: Sheet) -> void:
	var b := s.body
	var slot := _slot(b)
	var o := _net()
	var mine: int = o.my_role()
	var r: Dictionary = await o.clan_members()
	if not _fill(slot):
		return
	if not r["ok"]:
		slot.add_child(_wrap_label(str(r["error"]), "Small"))
		return
	var ids := []
	for mem in r["data"]:
		ids.append(mem["id"])
	var profs: Dictionary = await o.profiles(ids)
	if not is_instance_valid(slot):
		return
	for mem in r["data"]:
		var role := int(mem["role"])
		var card := _card()
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 12)
		card.add_child(h)
		h.add_child(_dot(bool(mem["online"])))
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_theme_constant_override("separation", 0)
		h.add_child(v)
		var who := {"id": str(mem["id"]), "name": str(mem["name"])}
		var nb := _button(str(mem["name"]), "Ghost", func(): _open_player(who), 48)
		nb.alignment = HORIZONTAL_ALIGNMENT_LEFT
		v.add_child(nb)
		var pr: Dictionary = profs.get(str(mem["id"]), {})
		v.add_child(Ui.label("%s · combat %d · power %s" % [ROLE_NAME[clampi(role, 0, 3)], int(pr.get("combat", 3)), Ui.fmt_num(int(pr.get("power", 0)))], "Small"))
		var uid := str(mem["id"])
		if mine <= 1 and uid != o.user_id:
			if role == 3:
				h.add_child(_button("Let in", "GreenButton", func(): _manage("add", uid, s), 60))
			elif role > mine:
				if mine == 0 and role == 2:
					h.add_child(_button("Elder", "Ghost", func(): _manage("promote", uid, s), 60))
				h.add_child(_confirm_button("Kick", "Sure?", "Ghost", func(): _manage("kick", uid, s)))
		slot.add_child(card)
	_refit(s)
	b.add_child(HSeparator.new())
	b.add_child(_wrap_label("Your friend code: %s" % o.my_code(), "Small"))
	b.add_child(_confirm_button("Leave clan", "Tap again to leave", "Ghost", func():
		var lr: Dictionary = await o.leave_clan()
		if lr["ok"]:
			s.close()
			_toast("You left the clan.")
			_social_refresh()
		else:
			_toast(str(lr["error"]), Color(1, 0.6, 0.5))))


func _manage(action: String, uid: String, s: Sheet) -> void:
	var r: Dictionary = await _net().clan_manage(action, uid)
	if not r["ok"]:
		_toast(str(r["error"]), Color(1, 0.6, 0.5))
	if is_instance_valid(s):
		s.rebuild()


# --- Another player -----------------------------------------------------------------

func _open_player(who: Dictionary) -> void:
	if str(who.get("id", "")) == "" or str(who["id"]) == _net().user_id:
		return
	_player = who
	open_sheet("player")


func _build_player(s: Sheet) -> void:
	var b := s.body
	var o := _net()
	var uid := str(_player["id"])
	var slot := _slot(b)
	var pr: Dictionary = (await o.profiles([uid])).get(uid, {})
	if not _fill(slot):
		return
	var hero_id := str(pr.get("hero", ""))
	if DB.HEROES.has(hero_id):
		slot.add_child(Ui.label("Plays %s" % DB.HEROES[hero_id]["name"], "Body"))
	_refit(s)
	slot.add_child(Ui.label("Combat %d · power %s · %d hunts" % [int(pr.get("combat", 3)), Ui.fmt_num(int(pr.get("power", 0))), int(pr.get("hunts", 0))], "Small"))
	b.add_child(_button("Add friend", "PrimaryButton", func():
		var fr: Dictionary = await o.post_api("/v2/friend?ids=" + uid.uri_encode())
		_toast("Friend request sent" if fr["ok"] else str(fr["error"]))
		s.close()))
	b.add_child(Ui.label("REPORT", "Caption"))
	var reasons := HFlowContainer.new()
	reasons.add_theme_constant_override("h_separation", 8)
	reasons.add_theme_constant_override("v_separation", 8)
	for pair in [["chat", "Rude chat"], ["name", "Bad name"], ["cheating", "Cheating"], ["other", "Other"]]:
		var why: String = pair[0]
		reasons.add_child(_button(pair[1], "Chip", func():
			var rr: Dictionary = await o.report(uid, why)
			_toast("Thanks. We'll look into it." if rr["ok"] else str(rr["error"]))
			s.close(), 56))
	b.add_child(reasons)
	b.add_child(_confirm_button("Block", "Tap again: hide them everywhere", "Ghost", func():
		await o.block(uid)
		o.clan_log = o.clan_log.filter(func(m): return str(m["from"]) != uid)
		_toast("Blocked. You won't see their messages.")
		s.close()
		_social_refresh()))


# --- Friends ------------------------------------------------------------------------

func _build_friends(s: Sheet) -> void:
	var b := s.body
	if not _net_gate(b):
		return
	var o := _net()
	var c := _card()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	c.add_child(v)
	var code_l := Ui.label(o.my_code(), "Title")
	var copy := _button("Copy", "Ghost", func():
		DisplayServer.clipboard_set(o.my_code())
		_toast("Code copied"), 60)
	v.add_child(_row([Ui.label("YOUR FRIEND CODE", "Caption"), _spacer()]))
	v.add_child(_row([code_l, _spacer(), copy]))
	var add := _field("Friend's code", "", 6)
	add.max_length = 6
	var err := _wrap_label("", "Small")
	var addb := _button("Add", "PrimaryButton", func(): pass, 72)
	addb.custom_minimum_size.x = 120
	addb.pressed.connect(func():
		var r: Dictionary = await o.add_friend(add.text)
		if not is_instance_valid(err):
			return
		err.text = "Request sent!" if r["ok"] else str(r["error"])
		if r["ok"]:
			add.text = "")
	v.add_child(_row([add, addb]))
	v.add_child(err)
	b.add_child(c)
	var slot := _slot(b)
	_fill_friends(slot, s)


func _fill_friends(slot: VBoxContainer, s: Sheet) -> void:
	var o := _net()
	var r: Dictionary = await o.friends()
	if not _fill(slot):
		return
	if not r["ok"]:
		slot.add_child(_wrap_label(str(r["error"]), "Small"))
		return
	var by_state := [[], [], [], []]
	for f in r["data"]:
		by_state[clampi(int(f["state"]), 0, 3)].append(f)
	var asks: int = by_state[2].size()
	if asks != _requests_n:
		_requests_n = asks
		refresh()
	var ids := []
	for f in by_state[0]:
		ids.append(f["id"])
	var profs := {}
	if not ids.is_empty():
		profs = await o.profiles(ids)
	if not is_instance_valid(slot):
		return
	if not by_state[2].is_empty():
		slot.add_child(Ui.label("WANT TO BE FRIENDS", "Caption"))
		for f in by_state[2]:
			var fid := str(f["id"])
			slot.add_child(_friend_row(f, {}, [
				_button("Accept", "GreenButton", func():
					await o.accept_friend(fid)
					s.rebuild(), 60),
				_button("No", "Ghost", func():
					await o.remove_friend(fid)
					s.rebuild(), 60)]))
	slot.add_child(Ui.label("FRIENDS · %d" % by_state[0].size(), "Caption"))
	if by_state[0].is_empty():
		slot.add_child(_wrap_label("Swap codes with a friend", "Small"))
	var friends: Array = by_state[0]
	friends.sort_custom(func(a, b2): return bool(a["online"]) and not bool(b2["online"]))
	for f in friends:
		var fid2 := str(f["id"])
		slot.add_child(_friend_row(f, profs.get(fid2, {}), [
			_confirm_button("Remove", "Sure?", "Ghost", func():
				await o.remove_friend(fid2)
				s.rebuild())]))
	if not by_state[1].is_empty():
		slot.add_child(Ui.label("ASKED", "Caption"))
		for f in by_state[1]:
			var fid3 := str(f["id"])
			slot.add_child(_friend_row(f, {}, [_button("Cancel", "Ghost", func():
				await o.remove_friend(fid3)
				s.rebuild(), 60)]))
	if not by_state[3].is_empty():
		slot.add_child(Ui.label("BLOCKED", "Caption"))
		for f in by_state[3]:
			var fid4 := str(f["id"])
			slot.add_child(_friend_row(f, {}, [_button("Unblock", "Ghost", func():
				await o.remove_friend(fid4)
				o.blocked.erase(fid4)
				s.rebuild(), 60)]))
	_refit(s)


func _friend_row(f: Dictionary, pr: Dictionary, buttons: Array) -> PanelContainer:
	var card := _card()
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	card.add_child(h)
	h.add_child(_dot(bool(f["online"])))
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 0)
	h.add_child(v)
	v.add_child(Ui.label(str(f["name"]), "Value"))
	var line := "online" if f["online"] else "offline"
	if not pr.is_empty():
		var hid := str(pr.get("hero", ""))
		line = "%s · combat %d · power %s" % [DB.HEROES[hid]["name"] if DB.HEROES.has(hid) else line, int(pr.get("combat", 3)), Ui.fmt_num(int(pr.get("power", 0)))]
	v.add_child(Ui.label(line, "Small"))
	for btn in buttons:
		btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(btn)
	return card


# --- Invite a friend (referrals) ---------------------------------------------------

func _build_invite(s: Sheet) -> void:
	var b := s.body
	if not _net_gate(b):
		return
	var o := _net()
	var hero := PanelContainer.new()
	hero.theme_type_variation = "GiftCard"
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	hero.add_child(v)
	v.add_child(_row([Ui.icon_rect("present", 64, GOLD), _wrap_label("Both of you win", "Heading")]))
	v.add_child(_wrap_label("They get a welcome gift. You earn at every milestone.", "Body"))
	var code := Ui.label(o.my_code(), "Title", HORIZONTAL_ALIGNMENT_CENTER)
	code.add_theme_font_size_override("font_size", 64)
	v.add_child(code)
	v.add_child(_button("Copy invite message", "GoldButton", func():
		DisplayServer.clipboard_set("Hunt with me in Gravelight! Enter my code %s under Clan › gift for a welcome gift: 2,000 gold, a Gold Chest and 10 hero shards." % o.my_code())
		_toast("Invite copied. Paste it to a friend!")))
	b.add_child(hero)
	if o.can_redeem():
		_build_redeem(b, s)
	var slot := _slot(b)
	_fill_recruits(slot)


func _build_redeem(b: Control, s: Sheet) -> void:
	var o := _net()
	var c := _card()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	c.add_child(v)
	v.add_child(_wrap_label("Did a friend invite you?", "Value"))
	v.add_child(_wrap_label("2,000 gold, a Gold Chest and 10 shards", "Small"))
	var e := _field("Friend's code", "", 6)
	var err := _wrap_label("", "Small")
	err.add_theme_color_override("font_color", Color(1, 0.6, 0.5))
	var go := _button("Claim", "GreenButton", func(): pass, 72)
	go.custom_minimum_size.x = 130
	go.pressed.connect(func():
		go.disabled = true
		var r: Dictionary = await o.redeem(e.text)
		if not is_instance_valid(go):
			return
		go.disabled = false
		if r["ok"]:
			_toast("You and %s are hunting together!" % str(r["data"].get("friend", "your friend")), Color(0.7, 1, 0.75))
			s.rebuild()
		else:
			err.text = str(r["error"]))
	v.add_child(_row([e, go]))
	v.add_child(err)
	b.add_child(c)


func _fill_recruits(slot: VBoxContainer) -> void:
	var r: Dictionary = await _net().recruits()
	if not _fill(slot):
		return
	if not r["ok"]:
		slot.add_child(_wrap_label(str(r["error"]), "Small"))
		return
	var d: Dictionary = r["data"]
	var steps: Array = Online._as_list(d.get("steps"))
	var tiers: Array = Online._as_list(d.get("tiers"))
	var list: Array = Online._as_list(d.get("list"))
	# What one friend is worth, step by step.
	slot.add_child(Ui.label("FOR EVERY FRIEND", "Caption"))
	var ladder := _card()
	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", 8)
	ladder.add_child(lv)
	lv.add_child(_reward_line("They enter your code", Online._as_list(d.get("on_redeem")), Online._as_list(d.get("welcome"))))
	for st in steps:
		lv.add_child(_reward_line("They " + str(st.get("text", "")), Online._as_list(st.get("you")), Online._as_list(st.get("them"))))
	slot.add_child(ladder)
	# Bigger rewards for more friends.
	var done := 0
	for rc in list:
		if rc.get("done") is Dictionary and rc["done"].get("hunts5", false):
			done += 1
	slot.add_child(Ui.label("FRIENDS WHO PLAYED 5 HUNTS · %d" % done, "Caption"))
	for t in tiers:
		var paid := bool(t.get("paid", false))
		var need := int(t.get("count", 1))
		var row := _card()
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 12)
		row.add_child(h)
		var ic := Ui.icon_rect("open-treasure-chest" if paid else "locked-chest", 52, GOLD if paid or done >= need else Color(0.6, 0.58, 0.54))
		h.add_child(ic)
		var tv := VBoxContainer.new()
		tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tv.add_theme_constant_override("separation", 0)
		h.add_child(tv)
		tv.add_child(Ui.label("%d friend%s" % [need, "" if need == 1 else "s"], "Value"))
		tv.add_child(_wrap_label(", ".join(Online._as_list(t.get("grants")).map(func(g): return Online.grant_text(g))), "Small"))
		var st_l := Ui.label("Earned" if paid else "%d/%d" % [mini(done, need), need], "Small")
		st_l.add_theme_color_override("font_color", Color("7fdc93") if paid else Color(0.8, 0.76, 0.68))
		h.add_child(st_l)
		slot.add_child(row)
	slot.add_child(Ui.label("YOUR RECRUITS · %d" % list.size(), "Caption"))
	if list.is_empty():
		slot.add_child(_wrap_label("No one yet. Share your code!", "Small"))
	for rc in list:
		var marks := ""
		for st in steps:
			var ok: bool = rc.get("done") is Dictionary and rc["done"].get(str(st.get("id", "")), false)
			marks += ("✓ " if ok else "· ") + str(st.get("text", "")) + "   "
		var rv := VBoxContainer.new()
		rv.add_child(Ui.label(str(rc.get("name", "Hunter")), "Value"))
		rv.add_child(_wrap_label(marks.strip_edges(), "Small"))
		if not bool(rc.get("rewarded", true)):
			rv.add_child(Ui.label("Over the %d-friend reward limit" % int(d.get("max", 20)), "Caption"))
		var rcard := _card()
		rcard.add_child(rv)
		slot.add_child(rcard)
	if _sheet and is_instance_valid(_sheet):
		_refit(_sheet)


func _reward_line(when: String, you: Array, them: Array) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.add_child(Ui.label(when, "Value"))
	var you_t := ", ".join(you.map(func(g): return Online.grant_text(g)))
	var them_t := ", ".join(them.map(func(g): return Online.grant_text(g)))
	if you_t != "":
		var l := _wrap_label("You: " + you_t, "Small")
		l.add_theme_color_override("font_color", GOLD)
		v.add_child(l)
	if them_t != "":
		v.add_child(_wrap_label("Them: " + them_t, "Small"))
	return v


# --- Rankings -----------------------------------------------------------------------

func _build_ranks(s: Sheet) -> void:
	var b := s.body
	if not _net_gate(b):
		return
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 12)
	b.add_child(tabs)
	var slot := _slot(b)
	for t in [["power", "Power"], ["weekly", "This week"]]:
		var board: String = t[0]
		var tb := _button(t[1], "Ghost", func(): _fill_ranks(slot, board), 56)
		tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tabs.add_child(tb)
	_fill_ranks(slot)


func _fill_ranks(slot: VBoxContainer, board := "power") -> void:
	var o := _net()
	var r: Dictionary = await o.leaderboard(board)
	if not _fill(slot):
		return
	if not r["ok"]:
		slot.add_child(_wrap_label(str(r["error"]), "Small"))
		return
	if board == "weekly":
		var om := Game.weekly_omen()
		slot.add_child(_wrap_label("Omen: %s. Best omen hunt this week; resets Thursday." % om["name"], "Small"))
		if (r["data"] as Array).is_empty():
			slot.add_child(_wrap_label("No scores yet this week. Turn on the omen and hunt.", "Small"))
	var mine: Dictionary = r["mine"]
	if not mine.is_empty():
		var me := _card()
		me.add_child(_row([Ui.label("You", "Value"), _spacer(), Ui.label("#%d · %s" % [int(mine["rank"]), Ui.fmt_num(int(mine["score"]))], "Value")]))
		slot.add_child(me)
	for row in r["data"]:
		var meta = row.get("meta")
		var hid := str(meta.get("hero", "")) if meta is Dictionary else ""
		var name_l := Ui.label(str(row["name"]), "Body")
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_l.clip_text = true
		var rank := Ui.label("#%d" % int(row["rank"]), "Value")
		rank.custom_minimum_size.x = 80
		if int(row["rank"]) <= 3:
			rank.add_theme_color_override("font_color", GOLD)
		var line := _row([rank, name_l, Ui.label(DB.HEROES[hid]["name"] if DB.HEROES.has(hid) else "", "Small"), Ui.label(Ui.fmt_num(int(row["score"])), "Value")])
		var who := {"id": str(row["id"]), "name": str(row["name"])}
		var btn := Button.new()
		btn.theme_type_variation = "Ghost"
		btn.focus_mode = Control.FOCUS_NONE
		btn.custom_minimum_size = Vector2(0, 64)
		line.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for ch in line.get_children():
			ch.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(line)
		btn.pressed.connect(func(): _open_player(who))
		slot.add_child(btn)
	if _sheet and is_instance_valid(_sheet):
		_refit(_sheet)


# --- Gifts -------------------------------------------------------------------------

## Rewards from friends, the raid or support pop up once the camp is idle.
func _show_gifts() -> void:
	var o := _net()
	if o == null:
		return
	if o.gifts_pending.is_empty() or not camp_idle():
		if not o.gifts_pending.is_empty() and is_inside_tree():
			get_tree().create_timer(1.5).timeout.connect(_show_gifts)
		return
	open_sheet("gifts")
	refresh()


func _build_gifts(s: Sheet) -> void:
	var b := s.body
	var list: Array = _net().gifts_pending.duplicate()
	_net().gifts_pending.clear()
	for g in list:
		var c := PanelContainer.new()
		c.theme_type_variation = "GiftCard"
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 6)
		c.add_child(v)
		v.add_child(_row([Ui.icon_rect("present", 52, GOLD), _wrap_label(str(g["text"]), "Value")]))
		for one in g["grants"]:
			v.add_child(Ui.label("+ " + Online.grant_text(one), "Body"))
		b.add_child(c)
	if list.any(func(g): return (g["grants"] as Array).any(func(x): return str(x.get("kind", "")) == "chest")):
		b.add_child(_wrap_label("Your chests wait in the chest slot on the Hunt screen.", "Small"))
	b.add_child(_button("Collect", "GoldButton", func():
		Sfx.play("coin", 0.0)
		s.close()
		if _chest_ready():
			show_chest(lobby.main.pending_chest)
			lobby.place_chest(lobby.main.pending_chest)))
	Sfx.play("coin", -2.0)


# --- Profile and account ----------------------------------------------------------------

func _build_profile(s: Sheet) -> void:
	var b := s.body
	var o := _net()
	var st: Dictionary = Game.data["stats"]
	var c := _card()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	c.add_child(v)
	v.add_child(Ui.label("YOUR NAME", "Caption"))
	var e := _field("3 to 16 letters", Game.player_name() if str(Game.data["profile"]["name"]) != "" else "", 16)
	var err := _wrap_label("", "Small")
	var save := _button("Save", "PrimaryButton", func(): pass, 72)
	save.custom_minimum_size.x = 120
	save.pressed.connect(func():
		var r: Dictionary = await o.set_player_name(e.text) if o else _local_name(e.text)
		if not is_instance_valid(err):
			return
		err.text = "Saved" if r["ok"] else str(r["error"])
		e.release_focus()
		refresh())
	v.add_child(_row([e, save]))
	v.add_child(err)
	b.add_child(c)
	b.add_child(Ui.label("Hunts %d · wins %d · kills %s · bosses %d" % [int(st["hunts"]), int(st["wins"]), Ui.fmt_num(int(st["kills"])), int(st["boss_kills"])], "Body"))
	if o and o.my_code() != "":
		b.add_child(Ui.label("Friend code %s · %s" % [o.my_code(), _clan_line()], "Small"))
	# The battle log lives with the rest of your record.
	b.add_child(_button("Battle log", "Button", func(): open_sheet("log")))
	b.add_child(_button("Account, cloud save and new phone", "Ghost", func(): open_sheet("account")))


func _local_name(n: String) -> Dictionary:
	n = n.strip_edges()
	if n.length() < 3 or n.length() > 16:
		return {"ok": false, "error": "Names are 3 to 16 letters."}
	Game.data["profile"]["name"] = n
	Game.save()
	return {"ok": true}


func _build_account(s: Sheet) -> void:
	var b := s.body
	var o := _net()
	if o == null or not o.configured():
		b.add_child(_wrap_label("Your progress is saved on this phone. Cloud saves, moving to a new phone and the account tools open when the camp server goes live.", "Body"))
		return
	var online := CheckButton.new()
	online.text = "Online play (clans, friends, cloud save)"
	online.button_pressed = o.state != "off"
	online.focus_mode = Control.FOCUS_NONE
	online.toggled.connect(func(on):
		o.set_off(not on)
		s.rebuild())
	b.add_child(online)
	b.add_child(Ui.label({"on": "Connected", "connecting": "Connecting…", "down": "Can't reach the server", "off": "Offline"}.get(o.state, ""), "Small"))
	if not o.is_on():
		return
	var synced := int(Game.data["online"]["synced"])
	b.add_child(Ui.label("CLOUD SAVE", "Caption"))
	b.add_child(_wrap_label("Saved automatically after hunts. Last: %s" % (Time.get_datetime_string_from_unix_time(synced, true) if synced > 0 else "never"), "Small"))
	b.add_child(_button("Save now", "Ghost", func():
		var r: Dictionary = await o.cloud_save()
		_toast("Saved to the cloud" if r["ok"] else str(r["error"]))
		if is_instance_valid(s):
			s.rebuild()))
	b.add_child(Ui.label("NEW PHONE", "Caption"))
	b.add_child(_wrap_label("On this phone, make a code. On the new phone, enter it here within a day: the new phone takes over this account and its cloud save.", "Small"))
	var code_l := Ui.label("", "Title", HORIZONTAL_ALIGNMENT_CENTER)
	b.add_child(_button("Make a transfer code", "Ghost", func():
		await o.cloud_save()
		var r: Dictionary = await o.transfer_make()
		if is_instance_valid(code_l):
			code_l.text = str(r["data"].get("code", "")) if r["ok"] else ""
		if not r["ok"]:
			_toast(str(r["error"]))))
	b.add_child(code_l)
	var e := _field("Code from your old phone", "", 8)
	var err := _wrap_label("", "Small")
	var use := _confirm_button("Use", "Replace this phone's progress?", "PrimaryButton", func():
		var r: Dictionary = await o.transfer_use(e.text.strip_edges().to_upper())
		if not is_instance_valid(err):
			return
		err.text = "Welcome back, %s!" % Game.player_name() if r["ok"] else str(r["error"])
		if r["ok"]:
			lobby.show_hero(Game.hero_id())
			refresh())
	use.custom_minimum_size.x = 120
	b.add_child(_row([e, use]))
	b.add_child(err)
	b.add_child(HSeparator.new())
	b.add_child(Ui.label("DELETE ACCOUNT", "Caption"))
	b.add_child(_wrap_label("Deletes your online account (name, friends, clan, cloud save) and resets the progress on this phone. This can't be undone.", "Small"))
	b.add_child(_confirm_button("Delete my account", "Tap again to delete everything", "Ghost", func():
		var r: Dictionary = await o.delete_account()
		if r["ok"]:
			s.close()
			_toast("Account deleted.")
			lobby.show_hero(Game.hero_id())
			show_tab("hunt")
			refresh()
		else:
			_toast(str(r["error"]), Color(1, 0.6, 0.5))))
	if Online.Cfg.SUPPORT != "":
		b.add_child(_wrap_label("Questions or a problem with another player? Write to %s" % Online.Cfg.SUPPORT, "Caption"))


# --- Weekly event ------------------------------------------------------------

## Set by captures: a board answer to draw instead of asking the server.
var _board_stub := {}


## The weekly event: this week's rule, how long it runs, the rewards track the
## rule's hunts fill, and the week's board.
func _build_event(s: Sheet) -> void:
	var b := s.body
	var om := Game.weekly_omen()
	var on := bool(Game.data.get("omen_on", false)) and Game.mode_id() != "trial"
	var head := _card()
	var hv := VBoxContainer.new()
	hv.add_theme_constant_override("separation", 6)
	var top := _row([Ui.icon_rect(str(om["icon"]), 64, Color(0.85, 0.7, 1.0))], 16)
	var tv := VBoxContainer.new()
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.add_theme_constant_override("separation", 0)
	tv.add_child(Ui.label("WEEKLY EVENT · ENDS IN %s" % Game.left_text(Game.event_seconds_left()).to_upper(), "Caption"))
	tv.add_child(Ui.label(str(om["name"]), "Heading"))
	top.add_child(tv)
	hv.add_child(top)
	hv.add_child(_wrap_label("%s Pays 25%% more gold and a better chest, and every hunt under the rule earns event points." % om["desc"], "Small"))
	var tog := _button("Rule on: tap to hunt without it" if on else "Hunt under the rule", "Ghost" if on else "GoldButton", func():
		Game.set_omen(not bool(Game.data.get("omen_on", false)))
		refresh()
		s.rebuild(), 64)
	tog.disabled = Game.mode_id() == "trial"
	hv.add_child(tog)
	if Game.mode_id() == "trial":
		hv.add_child(_wrap_label("The Long Road keeps its own rules. Pick another mode to join in.", "Small"))
	head.add_child(hv)
	b.add_child(head)
	# Points toward the next tier.
	var pts := Game.event_points()
	var lv := Game.event_level()
	var full := lv >= DB.EVENT_TRACK.size()
	var floor_pts := int(DB.EVENT_TRACK[lv - 1]) if lv > 0 else 0
	var next_pts := int(DB.EVENT_TRACK[mini(lv, DB.EVENT_TRACK.size() - 1)])
	b.add_child(_row([Ui.label("Event points", "Heading"), _spacer(), Ui.label(Ui.fmt_num(pts) if full else "%s / %s" % [Ui.fmt_num(pts), Ui.fmt_num(next_pts)], "Value")]))
	var pb := ProgressBar.new()
	pb.theme_type_variation = &"XPBar"
	pb.show_percentage = false
	pb.custom_minimum_size = Vector2(0, 14)
	pb.value = 100.0 if full else float(pts - floor_pts) / maxf(next_pts - floor_pts, 1.0) * 100.0
	b.add_child(pb)
	var claimed := int(Game.event()["claimed"])
	for n in range(1, DB.EVENT_TRACK.size() + 1):
		var rw := DB.event_reward(n)
		var c := _card()
		var row := _row([], 14)
		var num := Ui.label("%d" % n, "Value")
		num.custom_minimum_size = Vector2(54, 0)
		num.add_theme_font_size_override("font_size", 28)
		row.add_child(num)
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_theme_constant_override("separation", 0)
		v.add_child(Ui.label(("✓ " if n <= claimed else "") + _reward_text(rw), "Body"))
		v.add_child(Ui.label("%s points" % Ui.fmt_num(int(DB.EVENT_TRACK[n - 1])), "Small"))
		row.add_child(v)
		if n == claimed + 1 and n <= lv:
			var cb := Button.new()
			cb.text = "Claim"
			cb.theme_type_variation = &"GoldButton"
			cb.focus_mode = Control.FOCUS_NONE
			cb.pressed.connect(func():
				Game.claim_event()
				Sfx.play("coin", 0.0)
				refresh()
				s.rebuild())
			row.add_child(cb)
		elif n > lv:
			c.modulate = Color(1, 1, 1, 0.55)
		c.add_child(row)
		b.add_child(c)
	b.add_child(Ui.label("THIS WEEK'S BOARD", "Caption"))
	var slot := VBoxContainer.new()
	slot.add_theme_constant_override("separation", 8)
	b.add_child(slot)
	_fill_event_board(slot)


## The week's top hunts under the rule: your best, then the top of the board.
## Offline there is no board; your own best still shows.
func _fill_event_board(slot: VBoxContainer) -> void:
	var best := Game.weekly_best()
	var r: Dictionary = _board_stub
	if r.is_empty():
		var o := _net()
		if o == null or not o.is_on():
			slot.add_child(_wrap_label("Your best this week: %s. The board opens when you are online." % (Ui.fmt_num(best) if best > 0 else "none yet"), "Small"))
			return
		slot.add_child(_wrap_label("Loading the board...", "Small"))
		r = await o.leaderboard("weekly")
		if not _fill(slot):
			return
		for c in slot.get_children():
			c.queue_free()
	if not r.get("ok", false):
		slot.add_child(_wrap_label(str(r.get("error", "The board is out of reach.")), "Small"))
		return
	var mine: Dictionary = r.get("mine", {})
	if not mine.is_empty():
		var me := _card()
		me.add_child(_row([Ui.label("You", "Value"), _spacer(), Ui.label("#%d · %s" % [int(mine["rank"]), Ui.fmt_num(int(mine["score"]))], "Value")]))
		slot.add_child(me)
	var rows: Array = r.get("data", [])
	if rows.is_empty():
		slot.add_child(_wrap_label("No scores yet this week. Be the first.", "Small"))
	for i in mini(rows.size(), DB.EVENT_BOARD_ROWS):
		var row: Dictionary = rows[i]
		var meta = row.get("meta")
		var hid := str(meta.get("hero", "")) if meta is Dictionary else ""
		var name_l := Ui.label(str(row["name"]), "Body")
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_l.clip_text = true
		var rank := Ui.label("#%d" % int(row["rank"]), "Value")
		rank.custom_minimum_size.x = 80
		if int(row["rank"]) <= 3:
			rank.add_theme_color_override("font_color", GOLD)
		slot.add_child(_row([rank, name_l, Ui.label(DB.HEROES[hid]["name"] if DB.HEROES.has(hid) else "", "Small"), Ui.label(Ui.fmt_num(int(row["score"])), "Value")]))
