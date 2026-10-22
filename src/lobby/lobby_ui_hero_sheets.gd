extends "res://src/lobby/lobby_ui_widgets.gd"
## The camp screen, part 2: the Heroes sheet, talents and Skills.


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
		v.add_child(Ui.label(("Combat %d" % Game.combat_level(id)) if h["unlocked"] else "Locked", "Small", HORIZONTAL_ALIGNMENT_CENTER))
		t.add_child(v)
		var hid: String = id
		t.pressed.connect(func():
			_shown_hero = hid
			if Game.hero(hid)["unlocked"]:
				Game.set_hero(hid)
			lobby.show_hero(hid)
			refresh()
			s.rebuild())
		if h["unlocked"] and Game.talent_points(id) > 0:
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
	# Who they are.
	var head := VBoxContainer.new()
	head.add_theme_constant_override("separation", 0)
	var nm2 := Ui.label(d2["name"], "Title")
	nm2.add_theme_font_size_override("font_size", 40)
	nm2.add_theme_color_override("font_color", d2["color"].lightened(0.3))
	head.add_child(nm2)
	var bl := Ui.label("%s · %s" % [d2["title"], d2["blurb"]], "Body")
	bl.add_theme_color_override("font_color", Color(0.66, 0.63, 0.58))
	bl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	head.add_child(bl)
	b.add_child(head)
	# One sheet, three tabs: everything about a hero used to be one long scroll.
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	for t in [["stats", "Stats"], ["progress", "Progress"], ["looks", "Looks"]]:
		var tb := Button.new()
		tb.theme_type_variation = &"Choice"
		tb.toggle_mode = true
		tb.button_pressed = _hero_tab == t[0]
		tb.focus_mode = Control.FOCUS_NONE
		tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tb.custom_minimum_size = Vector2(0, 64)
		tb.text = t[1]
		if t[0] == "progress" and Game.talent_points(id2) > 0:
			tb.text += " •"
		var tid: String = t[0]
		tb.pressed.connect(func():
			_hero_tab = tid
			Sfx.play("ui_tap", -6.0)
			s.rebuild())
		tabs.add_child(tb)
	b.add_child(tabs)
	if not h2["unlocked"] and _hero_tab != "stats":
		_hero_locked(s, id2)
		return
	match _hero_tab:
		"progress":
			_hero_progress(s, id2)
		"looks":
			_hero_looks(s, id2)
		_:
			_hero_stats(s, id2)


func _hero_stats(s: Sheet, id2: String) -> void:
	var b := s.body
	var d2: Dictionary = DB.HEROES[id2]
	var h2 := Game.hero(id2)
	var st := Game.hero_stats(id2)
	var card := _card()
	var sv0 := VBoxContainer.new()
	sv0.add_theme_constant_override("separation", 0)
	var pairs := [
		["Health", "%d" % int(st["hp"]), "heart-organ"], ["Damage", "%d" % int(st["dmg"]), "sword-wound"],
		["Attacks / sec", "%.2f" % st["rate"], "lightning-tear"], ["Critical", "%d%%" % int(st["crit"] * 100.0), "bullseye"],
		["Armor", "%d%%" % int(DB.armor_dr(st["armor"]) * 100.0), "checked-shield"], ["Move speed", "%.1f" % st["speed"], "running-shoe"],
	]
	for i in pairs.size():
		var pair: Array = pairs[i]
		var r := _row([Ui.icon_rect(pair[2], 28, Color(0.85, 0.72, 0.48)), Ui.label(pair[0], "Body")], 12)
		r.custom_minimum_size = Vector2(0, 58)
		r.add_child(_spacer())
		var val := Ui.label(pair[1], "Value")
		val.add_theme_font_size_override("font_size", 26)
		r.add_child(val)
		sv0.add_child(r)
		if i < pairs.size() - 1:
			sv0.add_child(HSeparator.new())
	card.add_child(sv0)
	b.add_child(card)
	# Super.
	var sc := _card()
	var disc := _disc({"slam": "sun", "whirlwind": "whirlwind", "volley": "arrow-cluster", "meteor": "meteor-impact"}[d2["super"]], Color(1.0, 0.6, 0.25), 64)
	disc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var srow := _row([disc])
	var sv := VBoxContainer.new()
	sv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sv.add_theme_constant_override("separation", 0)
	sv.add_child(Ui.label("SUPER", "Caption"))
	sv.add_child(Ui.label(str(d2["super_name"]), "Heading"))
	var sd := Ui.label(d2["super_desc"], "Body")
	sd.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sv.add_child(sd)
	srow.add_child(sv)
	sc.add_child(srow)
	b.add_child(sc)
	if not h2["unlocked"]:
		_hero_locked(s, id2)
		return
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


func _hero_progress(s: Sheet, id2: String) -> void:
	var b := s.body
	var d2: Dictionary = DB.HEROES[id2]
	var h2 := Game.hero(id2)
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


func _hero_looks(s: Sheet, id2: String) -> void:
	var b := s.body
	var d2: Dictionary = DB.HEROES[id2]
	var h2 := Game.hero(id2)
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


func _hero_locked(s: Sheet, id2: String) -> void:
	var b := s.body
	var d2: Dictionary = DB.HEROES[id2]
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
	var note := Ui.label("Every %d combat levels give a point. Every node needs the one above it. The first reset is free; after that it costs gold." % DB.TALENT_COMBAT_STEP, "Small")
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
	var id := _shown_hero
	var levels := Game.skill_levels(id)
	# Only the skills this hero's style trains; the rest stay at their floor.
	var trained: Array = DB.STYLE_SKILLS[DB.HEROES[id]["skill"]]
	var total := 0
	for k in trained:
		total += int(levels[k])
	var head := _card()
	var hr := _row([_disc("crossed-swords", Color(0.95, 0.75, 0.35), 84)], 18)
	var hv := VBoxContainer.new()
	hv.add_theme_constant_override("separation", 0)
	var cl := Ui.label("Combat level %d" % Game.combat_level(id), "Heading")
	hv.add_child(cl)
	hv.add_child(Ui.label("Total level %d · 99 is the top" % total, "Small"))
	hv.add_child(Ui.label("%d shards · %d rub an XP lamp" % [int(Game.hero(id)["shards"]), DB.LAMP_SHARDS], "Small"))
	hr.add_child(hv)
	head.add_child(hr)
	b.add_child(head)
	var grid := GridContainer.new()
	grid.columns = 2
	for sk in trained:
		var xp := Game.skill_xp(sk, id)
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
		# XP lamps: shards from chests and duplicates turn into skill XP.
		var lamp := Button.new()
		lamp.theme_type_variation = "CardButton"
		lamp.text = "Lamp · +%s xp" % Ui.fmt_num(Game.lamp_xp(id, sk))
		lamp.custom_minimum_size = Vector2(0, 56)
		lamp.focus_mode = Control.FOCUS_NONE
		lamp.disabled = not Game.can_rub_lamp(id)
		var skn: String = sk
		lamp.pressed.connect(func():
			if Game.rub_lamp(id, skn):
				Sfx.play("skill_level", -4.0)
				refresh()
				s.rebuild())
		v.add_child(lamp)
		c.add_child(v)
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(c)
	b.add_child(grid)
	var note := Ui.label("Skills are a hero's power. Each hero trains their own with the damage they deal, and skills unlock better gear. Combat level earns talent points. Shards rub XP lamps.", "Small")
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.add_child(note)
