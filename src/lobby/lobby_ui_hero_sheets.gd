extends "res://src/lobby/lobby_ui_widgets.gd"
## The camp screen, part 2: the Heroes sheet, talents and Skills.

const TalentPathView := preload("res://src/lobby/talent_path_view.gd")

## The talent node shown under the tree ("path.index", "" for none), and the
## option picked on a choice node not yet learned.
var _talent_sel := ""
var _talent_opt := 0


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
	var sup := _row([_disc({"slam": "sun", "whirlwind": "whirlwind", "volley": "arrow-cluster", "meteor": "meteor-impact", "shadowstep": "two-shadows"}[d["super"]], Color(1.0, 0.6, 0.25), 56)], 14)
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
	# The hero already in use needs no dead button, just a word that it is.
	if id == Game.hero_id():
		var inuse := Ui.label("✓ Your hero for the next hunt", "Small", HORIZONTAL_ALIGNMENT_CENTER)
		inuse.add_theme_color_override("font_color", Color(0.6, 0.88, 0.55))
		b.add_child(inuse)
		return
	var use := Button.new()
	use.theme_type_variation = &"GoldButton"
	use.focus_mode = Control.FOCUS_NONE
	use.custom_minimum_size = Vector2(0, 92)
	use.text = "Use"
	use.pressed.connect(func():
		Game.set_hero(id)
		Sfx.play("ui_press", 0.0)
		refresh()
		s.close())
	b.add_child(use)


## The talent tree: the hero's three paths side by side, each a small tree
## (TalentPathView), and under them the picked node with Learn and Refund.
## Nothing is spent by tapping a node, only by Learn.
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
	b.add_child(head)
	# Two saved builds, the gold refunds cost, and a full reset.
	var bar := _row([], 8)
	for i in DB.TALENT_BUILDS:
		var bb := Button.new()
		bb.text = "Build %s" % "AB"[i]
		bb.theme_type_variation = &"Choice"
		bb.toggle_mode = true
		bb.button_pressed = Game.talent_build(id) == i
		bb.focus_mode = Control.FOCUS_NONE
		bb.custom_minimum_size = Vector2(132, 52)
		bb.pressed.connect(func():
			Game.set_talent_build(id, i)
			_talent_sel = ""
			Sfx.play("ui_tap", -4.0)
			refresh()
			s.rebuild())
		bar.add_child(bb)
	bar.add_child(_spacer())
	bar.add_child(_row([Ui.icon_rect("two-coins", 28, Color(0.95, 0.75, 0.35)), Ui.label(Ui.fmt_num(Game.gold()), "Small")], 6))
	var reset := Button.new()
	var rc := Game.respec_cost(id)
	reset.text = "Reset" if rc == 0 else "Reset · %s" % Ui.fmt_num(rc)
	reset.theme_type_variation = &"Ghost"
	reset.focus_mode = Control.FOCUS_NONE
	reset.disabled = Game.talent_spent(id) == 0
	reset.pressed.connect(func():
		if not Game.respec(id):
			Sfx.play("ui_error", -6.0)
			return
		_talent_sel = ""
		Sfx.play("ui_back", -4.0)
		refresh()
		s.rebuild())
	bar.add_child(reset)
	b.add_child(bar)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 8)
	var paths := TalentDB.paths(id)
	for pi in paths.size():
		var path: Dictionary = paths[pi]
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_theme_constant_override("separation", 0)
		col.add_child(Ui.icon_rect(path["icon"], 44, Color(d["color"]).lightened(0.3)))
		col.add_child(Ui.label(str(path["name"]).to_upper(), "Caption", HORIZONTAL_ALIGNMENT_CENTER))
		var pp := Game.path_points(id, pi)
		var al := Ui.label(("%d pt%s · %s" % [pp, "" if pp == 1 else "s", TalentDB.attune_text(path, pp)]) if pp > 0 else str(path["blurb"]), "Small", HORIZONTAL_ALIGNMENT_CENTER)
		al.add_theme_font_size_override("font_size", 17)
		al.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		al.custom_minimum_size = Vector2(0, 40)
		col.add_child(al)
		var view: Control = TalentPathView.new()
		var sel := -1
		if _talent_sel.begins_with("%d." % pi):
			sel = int(_talent_sel.split(".")[1])
		view.setup(id, pi, sel)
		view.picked.connect(func(idx: int):
			_talent_sel = TalentDB.key(pi, idx)
			_talent_opt = 0
			Sfx.play("ui_tap", -6.0)
			s.rebuild())
		col.add_child(view)
		cols.add_child(col)
	b.add_child(cols)
	b.add_child(_talent_detail(s, id))


func _talent_detail(s: Sheet, id: String) -> Control:
	var card := _card()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	card.add_child(v)
	if _talent_sel == "":
		v.add_child(_row([_disc("scroll-unfurled", Color(0.95, 0.75, 0.35), 64), _talent_lines("Pick a node", "%d of %d points spent" % [Game.talent_spent(id), Game.talent_earned(id)])], 14))
		var hint := Ui.label("Tap a node to see what it does. Rows open as you put points into a path, and one keystone can be active at a time.", "Body")
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(hint)
		return card
	var parts := _talent_sel.split(".")
	var pi := int(parts[0])
	var ni := int(parts[1])
	var n := TalentDB.node(id, pi, ni)
	var path: Dictionary = TalentDB.paths(id)[pi]
	var rank := Game.talent_rank(id, pi, ni)
	var mx := TalentDB.max_rank(n)
	var pick := Game.talent_pick(id, pi, ni)
	var kind: String = n["k"]
	var sub := "%s · %s" % [TalentDB.KIND_NAME[kind], path["name"]]
	if mx > 1:
		sub += " · rank %d/%d" % [rank, mx]
	var col := Color(0.85, 0.4, 0.2) if kind == "k" else Color(0.95, 0.75, 0.35)
	v.add_child(_row([_disc(TalentDB.icon(n, pick if pick >= 0 else _talent_opt), col, 64), _talent_lines(n["name"], sub)], 14))
	var lines: PackedStringArray = []
	if kind == "m":
		if rank > 0:
			lines.append("Now: " + TalentDB.describe(n, rank))
		if rank < mx:
			lines.append("Next rank: " + TalentDB.describe(n, rank + 1))
	elif kind != "c":
		lines.append(TalentDB.describe(n))
	if kind == "k":
		lines.append("Cost: " + str(n["cost"]))
	if not lines.is_empty():
		var tl := Ui.label("\n".join(lines), "Body")
		tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(tl)
	if kind == "c":
		var opts := HBoxContainer.new()
		opts.add_theme_constant_override("separation", 8)
		for j in n["opts"].size():
			var o: Dictionary = n["opts"][j]
			var ob := Button.new()
			ob.theme_type_variation = &"Choice"
			ob.toggle_mode = true
			ob.button_pressed = (pick == j) if rank > 0 else (_talent_opt == j)
			ob.disabled = rank > 0 and pick != j
			ob.focus_mode = Control.FOCUS_NONE
			ob.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			ob.custom_minimum_size = Vector2(0, 92)
			var ov := VBoxContainer.new()
			ov.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			ov.offset_left = 12
			ov.offset_right = -12
			ov.offset_top = 6
			ov.offset_bottom = -8
			ov.add_theme_constant_override("separation", 0)
			ov.mouse_filter = Control.MOUSE_FILTER_IGNORE
			ov.add_child(Ui.label(o["name"], "Body"))
			var od := Ui.label(o["desc"], "Small")
			od.add_theme_font_size_override("font_size", 18)
			od.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			ov.add_child(od)
			ob.add_child(ov)
			ob.pressed.connect(func():
				if rank == 0:
					_talent_opt = j
					Sfx.play("ui_tap", -6.0)
				s.rebuild())
			opts.add_child(ob)
		v.add_child(opts)
	# Why it cannot be learned or refunded, when that is not obvious.
	var note := ""
	var ks := Game.keystone(id)
	var row := TalentDB.row(ni)
	if not Game.row_open(id, pi, row):
		note = "Opens at %d points in %s (you have %d)." % [TalentDB.GATES[row], path["name"], Game.path_points(id, pi, row)]
	elif kind == "k" and ks != "" and ks != TalentDB.key(pi, ni):
		var kp := ks.split(".")
		note = "One keystone at a time: %s is active." % TalentDB.node(id, int(kp[0]), int(kp[1]))["name"]
	elif kind == "c" and rank > 0:
		note = "Refund this node to take the other upgrade."
	elif rank > 0 and not Game.can_refund(id, pi, ni) and Game.gold() >= Game.refund_cost(id, pi, ni):
		note = "A higher row needs this point: refund those first."
	if note != "":
		var nl := Ui.label(note, "Small")
		nl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(nl)
	var rc := Game.refund_cost(id, pi, ni)
	var refund := _talent_button("Refund" if rank == 0 or rc == 0 else "Refund · %d" % rc, "BlueButton", Game.can_refund(id, pi, ni), func():
		if Game.refund_talent(id, pi, ni):
			Sfx.play("ui_back", -4.0)
			refresh()
		s.rebuild())
	var learn := _talent_button("Learn", "GoldButton", Game.can_learn(id, pi, ni), func():
		if Game.learn_talent(id, pi, ni, _talent_opt):
			Sfx.play("levelup", -4.0)
			refresh()
		s.rebuild())
	s.footer.add_child(refund)
	s.footer.add_child(learn)
	return card


func _talent_lines(title: String, sub: String) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	v.add_child(Ui.label(title, "Value"))
	v.add_child(Ui.label(sub.to_upper(), "Caption"))
	return v


func _talent_button(text: String, variation: String, enabled: bool, cb: Callable) -> Button:
	var bt := Button.new()
	bt.text = text
	bt.theme_type_variation = variation
	bt.focus_mode = Control.FOCUS_NONE
	bt.disabled = not enabled
	bt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bt.custom_minimum_size = Vector2(0, 76)
	bt.pressed.connect(cb)
	return bt


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
