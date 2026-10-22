extends Control
## Opening a chest in camp: tap, the lid flies, and the rewards come out one
## card at a time. Tap to advance; the last tap collects.

var ui: LobbyUI
var kind := ""
var rewards: Array = []
var idx := -1
var stage := "closed"
var _hint: Label
var _card_holder: CenterContainer
var _scrim: ColorRect


func open(u: LobbyUI, k: String) -> void:
	ui = u
	kind = k
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_scrim = ColorRect.new()
	_scrim.color = Color(0.0, 0.0, 0.02, 0.35)
	_scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_scrim)
	_card_holder = CenterContainer.new()
	_card_holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_card_holder.offset_top = -120
	_card_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_card_holder)
	_hint = Ui.label("Tap to open your %s" % DB.CHESTS[kind]["name"], "HudTitle", HORIZONTAL_ALIGNMENT_CENTER)
	_hint.add_theme_font_size_override("font_size", 34)
	_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_hint.offset_top = -260.0
	_hint.offset_bottom = -200.0
	add_child(_hint)
	Sfx.play("chest_rattle", 0.0)


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		_advance()


func _advance() -> void:
	match stage:
		"closed":
			stage = "rewards"
			rewards = Game.open_chest(kind)
			ui.lobby.open_chest_fx()
			Sfx.play("chest_open", 0.0)
			var t := create_tween()
			t.tween_property(_scrim, "color:a", 0.7, 0.4)
			_hint.text = ""
			await get_tree().create_timer(0.45).timeout
			_next()
		"rewards":
			_next()
		"summary":
			stage = "done"
			Sfx.play("ui_press", -2.0)
			var t2 := create_tween()
			t2.tween_property(self, "modulate:a", 0.0, 0.25)
			t2.tween_callback(func():
				ui.chest_done()
				queue_free())


func _next() -> void:
	idx += 1
	Ui.clear(_card_holder)
	if idx >= rewards.size():
		_summary()
		return
	var r: Dictionary = rewards[idx]
	_card_holder.add_child(_reward_card(r))
	Ui.pop_in(_card_holder.get_child(0), 0.0, 0.5)
	_hint.text = "%d / %d · tap" % [idx + 1, rewards.size()]
	match str(r["type"]):
		"gold":
			Sfx.play("coin", 0.0)
		"item":
			Sfx.play("rare_chime" if r["item"]["rarity"] in ["rare", "legendary"] else "gear_drop", 0.0)
		"unlock":
			Sfx.play("levelup", 0.0)
		_:
			Sfx.play("card_flip", 0.0)


func _reward_card(r: Dictionary) -> Control:
	var col := Color(1.0, 0.8, 0.35)
	var icon := "two-coins"
	var title := ""
	var sub := ""
	match str(r["type"]):
		"gold":
			title = "+%d gold" % int(r["amount"])
		"shards":
			var d: Dictionary = DB.HEROES[r["hero"]]
			col = d["color"]
			icon = d["icon"]
			title = "+%d %s shards" % [int(r["amount"]), d["name"]]
			var h := Game.hero(r["hero"])
			var cost := Game.upgrade_cost(r["hero"])
			sub = ("%d / %d to next level" % [int(h["shards"]), cost["shards"]]) if h["unlocked"] and not cost.is_empty() else ("%d / 20 to unlock" % int(h["shards"]) if not h["unlocked"] else "")
		"item":
			var it: Dictionary = r["item"]
			col = DB.rarity_color(it["rarity"])
			icon = GearDB.item_icon(it)
			title = str(it["name"])
			sub = "%s %s · for the %s\n%s" % [DB.RARITY_NAME[it["rarity"]], DB.SLOT_NAME.get(it["slot"], ""), DB.HEROES[it["cls"]]["name"], "\n".join(Game.describe_stats(it))]
		"unlock":
			var d2: Dictionary = DB.HEROES[r["hero"]]
			col = d2["color"]
			icon = d2["icon"]
			title = "%s unlocked!" % d2["name"]
			sub = d2["blurb"]
	var p := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.09, 0.08, 0.11, 0.97)
	st.set_corner_radius_all(20)
	st.set_border_width_all(4)
	st.border_color = col
	st.shadow_color = Color(col, 0.45)
	st.shadow_size = 30
	st.content_margin_left = 30
	st.content_margin_right = 30
	st.content_margin_top = 30
	st.content_margin_bottom = 30
	p.add_theme_stylebox_override("panel", st)
	p.custom_minimum_size = Vector2(480, 0)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cc := CenterContainer.new()
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cc.add_child(Ui.icon_rect(icon, 150, col.lightened(0.2)))
	v.add_child(cc)
	var t := Ui.label(title, "Heading", HORIZONTAL_ALIGNMENT_CENTER)
	t.add_theme_font_size_override("font_size", 36)
	t.add_theme_color_override("font_color", col.lightened(0.25))
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(t)
	if sub != "":
		var s := Ui.label(sub, "Body", HORIZONTAL_ALIGNMENT_CENTER)
		s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(s)
	p.add_child(v)
	return p


func _summary() -> void:
	stage = "summary"
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(520, 0)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(Ui.label(DB.CHESTS[kind]["name"], "Title", HORIZONTAL_ALIGNMENT_CENTER))
	for r in rewards:
		var line := ""
		var col := Color(1, 0.85, 0.5)
		match str(r["type"]):
			"gold":
				line = "+%d gold" % int(r["amount"])
			"shards":
				line = "+%d %s shards" % [int(r["amount"]), DB.HEROES[r["hero"]]["name"]]
				col = DB.HEROES[r["hero"]]["color"].lightened(0.2)
			"item":
				line = str(r["item"]["name"])
				col = DB.rarity_color(r["item"]["rarity"])
			"unlock":
				line = "%s unlocked" % DB.HEROES[r["hero"]]["name"]
		var l := Ui.label(line, "Body", HORIZONTAL_ALIGNMENT_CENTER)
		l.add_theme_color_override("font_color", col)
		v.add_child(l)
	p.add_child(v)
	_card_holder.add_child(p)
	Ui.pop_in(p, 0.0, 0.8)
	_hint.text = "Tap to collect"
