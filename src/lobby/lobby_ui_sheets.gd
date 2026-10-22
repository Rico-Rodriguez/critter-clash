extends "res://src/lobby/lobby_ui_hero_sheets.gd"
## The camp screen, part 3: the other sheets. Daily rewards, the season,
## feats, the renown road, bounties, the collection log, the expedition
## picker and Settings.


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
	_error_report_row(b, ver)


## One tap copies the error log, so a playtester can paste it into a message.
func _error_report_row(b: Control, ver: String) -> void:
	var n := Game.errors.error_count()
	var c := Game.errors.crash_count()
	var row := _row([Ui.label("Errors %d · crashes %d" % [n, c], "Small"), _spacer()], 8)
	var copy := Button.new()
	copy.text = "Copy report"
	copy.theme_type_variation = "Ghost"
	copy.focus_mode = Control.FOCUS_NONE
	copy.pressed.connect(func():
		DisplayServer.clipboard_set(Game.errors.report(ver))
		Sfx.play("ui_tap", -4.0)
		copy.text = "Copied")
	row.add_child(copy)
	b.add_child(row)
