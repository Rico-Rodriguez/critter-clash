extends "res://src/lobby/lobby_ui_widgets.gd"
## The camp screen, part 2: the Heroes sheet, talents and Skills.


## A hero's card, opened from their name or face on the Heroes tab: stats at a glance, then the way into
## skills, talents and looks, and Use.
func _build_hero_sheet(s: Sheet) -> void:
	var b := s.body
	var id := _shown_hero
	var d: Dictionary = DB.HEROES[id]
	var h := Game.hero(id)
	var open: bool = h["unlocked"]
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 18)
	head.add_child(_portrait(id, d["color"] if open else Color(0.4, 0.4, 0.42), 132))
	var hv := VBoxContainer.new()
	hv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hv.add_theme_constant_override("separation", 2)
	var role := Ui.label("%s · %s" % [d["title"], d["role"]], "Small")
	hv.add_child(role)
	var cl := Ui.label(("Combat %d" % Game.combat_level(id)) if open else "Locked", "Heading")
	cl.add_theme_color_override("font_color", Color(0.75, 0.9, 0.5) if open else Color(0.7, 0.68, 0.62))
	hv.add_child(cl)
	if open:
		hv.add_child(Ui.label("Power %s · %s" % [Ui.fmt_num(Game.power_score(id)), Game.mastery_title(id)], "Small"))
	head.add_child(hv)
	b.add_child(head)
	# Six numbers in chips, not a table.
	var st := Game.hero_stats(id)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	for pair in [["heart-organ", "%d" % int(st["hp"]), "Health"], ["sword-wound", "%d" % int(st["dmg"]), "Damage"],
			["lightning-tear", "%.2f" % st["rate"], "Hits/s"], ["bullseye", "%d%%" % int(st["crit"] * 100.0), "Crit"],
			["checked-shield", "%d%%" % int(DB.armor_dr(st["armor"]) * 100.0), "Armor"], ["running-shoe", "%.1f" % st["speed"], "Speed"]]:
		var c := _card()
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var cv := VBoxContainer.new()
		cv.add_theme_constant_override("separation", 0)
		var top := _row([Ui.icon_rect(pair[0], 30, Color(0.85, 0.72, 0.48)), Ui.label(pair[1], "Value")], 8)
		top.alignment = BoxContainer.ALIGNMENT_CENTER
		cv.add_child(top)
		cv.add_child(Ui.label(pair[2], "Caption", HORIZONTAL_ALIGNMENT_CENTER))
		c.add_child(cv)
		grid.add_child(c)
	b.add_child(grid)
	var sup := _row([_disc({"slam": "sun", "whirlwind": "whirlwind", "volley": "arrow-cluster", "meteor": "meteor-impact"}[d["super"]], Color(1.0, 0.6, 0.25), 56)], 14)
	var sl := Ui.label("Super: %s" % d["super_name"], "Value")
	sl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sup.add_child(sl)
	b.add_child(sup)
	if not open:
		var lk := Ui.label(Game.hero_lock_text(id), "Body", HORIZONTAL_ALIGNMENT_CENTER)
		lk.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.add_child(lk)
		return
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var pts := Game.talent_points(id)
	for t in [["Skills", "BlueButton", "skills"], ["Talents" + (" · %d" % pts if pts > 0 else ""), "GreenButton" if pts > 0 else "BlueButton", "talents"], ["Skins", "BlueButton", "looks"]]:
		var tb := Button.new()
		tb.text = t[0]
		tb.theme_type_variation = t[1]
		tb.focus_mode = Control.FOCUS_NONE
		tb.custom_minimum_size = Vector2(0, 80)
		tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var to: String = t[2]
		tb.pressed.connect(func(): open_sheet(to))
		row.add_child(tb)
	b.add_child(row)
	var use := Button.new()
	use.theme_type_variation = &"GoldButton"
	use.focus_mode = Control.FOCUS_NONE
	use.custom_minimum_size = Vector2(0, 92)
	use.text = "In use" if id == Game.hero_id() else "Use"
	use.disabled = id == Game.hero_id()
	use.pressed.connect(func():
		Game.set_hero(id)
		Sfx.play("ui_press", 0.0)
		refresh()
		s.close())
	b.add_child(use)


## The talent tree: three columns, each a path read top to bottom.
func _build_talents(s: Sheet) -> void:
	var b := s.body
	var id := _shown_hero
	var d: Dictionary = DB.HEROES[id]
	var pts := Game.talent_points(id)
	var head := _row([Ui.label("%s · Combat %d" % [d["name"], Game.combat_level(id)], "Heading"), _spacer()])
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
	var id := _shown_hero
	# Only the skills this hero's style trains; the rest stay at their floor.
	var trained: Array = DB.STYLE_SKILLS[DB.HEROES[id]["skill"]]
	var line: Dictionary = GearDB.LINES[id]
	var shards := int(Game.hero(id)["shards"])
	var head := _card()
	var hr := _row([_disc("crossed-swords", Color(0.95, 0.75, 0.35), 84)], 18)
	var hv := VBoxContainer.new()
	hv.add_theme_constant_override("separation", 2)
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hv.add_child(Ui.label("Combat level %d" % Game.combat_level(id), "Heading"))
	var how := Ui.label("Skills rise as you fight in hunts. Each level makes the hero stronger, and gear asks for a level to wear it.", "Small")
	how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hv.add_child(how)
	hr.add_child(hv)
	head.add_child(hr)
	b.add_child(head)
	# Super ranks: what shards buy, with the price and the change on every rank.
	var sup_card := _card()
	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 6)
	var rank := Game.super_rank(id)
	var st := Ui.label("%s · rank %d of %d" % [DB.HEROES[id]["super_name"], rank, DB.SUPER_RANKS.size()], "Body")
	st.add_theme_font_size_override("font_size", 24)
	st.add_theme_color_override("font_color", Color(0.75, 0.6, 1.0))
	sv.add_child(st)
	if not Game.super_unlocked(id):
		var ul := Ui.label("Unlocks at combat level %d, or for every hero at %d trophies." % [int(DB.SUPER_UNLOCK["level"]), int(DB.SUPER_UNLOCK["trophies"])], "Small")
		ul.add_theme_font_size_override("font_size", 20)
		ul.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sv.add_child(ul)
	var perks: Array = DB.SUPER_PERKS.get(str(DB.HEROES[id]["super"]), [])
	for i in perks.size():
		var rl := Ui.label("%s %d. %s" % ["✓" if i < rank else "·", i + 1, perks[i]["text"]], "Small")
		rl.add_theme_font_size_override("font_size", 20)
		rl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4) if i < rank else Color(0.7, 0.68, 0.64))
		sv.add_child(rl)
	var cost := Game.super_rank_cost(id)
	var buy := Button.new()
	buy.theme_type_variation = "CardButton"
	buy.focus_mode = Control.FOCUS_NONE
	buy.add_theme_font_size_override("font_size", 18)
	if cost.is_empty():
		buy.text = "Max rank"
		buy.disabled = true
	else:
		buy.text = "Rank %d: %d shards + %s gold  (you have %d shards)" % [rank + 1, int(cost["shards"]), Ui.fmt_num(int(cost["gold"])), shards]
		buy.disabled = not Game.can_buy_super_rank(id)
	buy.pressed.connect(func():
		if Game.buy_super_rank(id):
			Sfx.play("skill_level", -4.0)
			refresh()
			s.rebuild())
	sv.add_child(buy)
	sup_card.add_child(sv)
	b.add_child(sup_card)
	for sk: String in trained:
		var xp := Game.skill_xp(sk, id)
		var lvl := DB.level_for_xp(xp)
		var c := _card()
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 4)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var top := _row([Ui.icon_rect(DB.SKILL_ICON[sk], 40, Color(0.95, 0.78, 0.45)), Ui.label(DB.SKILL_NAME[sk], "Body"), _spacer()], 8)
		var lvl_l := Ui.label("%d" % lvl, "Value")
		lvl_l.add_theme_font_size_override("font_size", 30)
		lvl_l.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
		top.add_child(lvl_l)
		v.add_child(top)
		var pb := ProgressBar.new()
		pb.theme_type_variation = "XPBar"
		pb.custom_minimum_size = Vector2(0, 12)
		pb.show_percentage = false
		var lo := DB.xp_for_level(lvl)
		var hi := DB.xp_for_level(mini(lvl + 1, 99))
		pb.value = 100.0 if lvl >= 99 else float(xp - lo) / float(maxi(hi - lo, 1)) * 100.0
		v.add_child(pb)
		var nx := Ui.label("Max level" if lvl >= 99 else "%s xp to level %d" % [Ui.fmt_num(hi - xp), lvl + 1], "Small")
		nx.add_theme_font_size_override("font_size", 16)
		v.add_child(nx)
		var does: String = DB.SKILL_PERK[sk]
		if sk == str(line["weapon_skill"]):
			does += ". Weapons up to level %d" % lvl
		if sk == str(line["armor_skill"]):
			does += ". Armor up to level %d" % lvl
		var perk := Ui.label(does, "Small")
		perk.add_theme_font_size_override("font_size", 16)
		perk.add_theme_color_override("font_color", Color(0.55, 0.75, 1.0))
		perk.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(perk)
		row.add_child(v)
		c.add_child(row)
		b.add_child(c)
