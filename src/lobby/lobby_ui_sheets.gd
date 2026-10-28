extends "res://src/lobby/lobby_ui_hero_sheets.gd"
## The camp screen, part 3: the other sheets. Daily rewards, the season,
## feats, bounties, the collection log, the expedition
## picker and Settings.


## Quests: what there is to do and claim, one tile each: the daily reward,
## the day's bounties and the feats. Each says where it stands and opens its
## sheet. (The road and the season have their own buttons on the home.)
func _build_journal(s: Sheet) -> void:
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	var st := Game.login_status()
	var ready_d: bool = st["ready"]
	grid.add_child(_reward_tile("sun", "Daily", "Ready!" if ready_d else "Day %d" % int(st["day"]), -1.0, 1 if ready_d else 0, "daily"))
	var list: Array = Game.data["bounties"]["list"]
	var done := list.filter(func(e): return Game.bounty_done(e)).size()
	grid.add_child(_reward_tile("archery-target", "Bounties", "%d / %d" % [done, list.size()], float(done) / maxf(list.size(), 1.0), Game.bounty_claimable(), "bounties"))
	var got: int = Game.data["achievements"].size()
	grid.add_child(_reward_tile("trophy", "Feats", "%d / %d" % [got, DB.ACHIEVEMENTS.size()], float(got) / DB.ACHIEVEMENTS.size(), Game.achievement_claimable(), "feats"))
	var cleared: int = Game.data["story"]["cleared"].size()
	var nxt := Game.story_next()
	grid.add_child(_reward_tile("scroll-unfurled", "Story", "Done" if nxt >= STORY_DB.count() else "Chapter %d" % (nxt + 1), float(cleared) / STORY_DB.count(), 1 if nxt < STORY_DB.count() else 0, "story"))
	s.body.add_child(grid)
	FxUi.deal_in(grid, 0.06)


const STORY_DB := preload("res://src/data/story_db.gd")
const CUTSCENE := preload("res://src/ui/cutscene.gd")
const JOURNAL_TILE := {"story": &"TileRed", "daily": &"TileGold", "bounties": &"TileBlue", "road": &"TileRed", "season": &"TilePurple", "feats": &"TileGreen", "log": &"TileSlate"}


## A tile of the Journal grid, in its track's color. `frac` < 0 leaves out the
## bar; `ready_n` > 0 sets a shine across it, sways its icon and puts a
## breathing count in the corner.
func _reward_tile(icon: String, title: String, status: String, frac: float, ready_n: int, sheet: String) -> Button:
	var btn := Button.new()
	btn.theme_type_variation = JOURNAL_TILE.get(sheet, &"TileSlate")
	btn.focus_mode = Control.FOCUS_NONE
	btn.custom_minimum_size = Vector2(0, 236)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 10
	v.offset_right = -10
	v.offset_top = 22
	v.offset_bottom = -20
	v.add_theme_constant_override("separation", 6)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(v)
	var cc := CenterContainer.new()
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ic := Ui.icon_rect(icon, 84, Color(1.0, 0.86, 0.45) if ready_n > 0 else Color(1, 1, 1, 0.85))
	cc.add_child(ic)
	v.add_child(cc)
	var nm := Ui.label(title, "Value", HORIZONTAL_ALIGNMENT_CENTER)
	nm.add_theme_font_size_override("font_size", 28)
	nm.add_theme_constant_override("outline_size", 6)
	v.add_child(nm)
	var sl := Ui.label(status, "Small", HORIZONTAL_ALIGNMENT_CENTER)
	sl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.5) if ready_n > 0 else Color(1, 1, 1, 0.72))
	v.add_child(sl)
	if frac >= 0.0:
		var bar := ProgressBar.new()
		bar.theme_type_variation = &"XPBar"
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0, 14)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.value = frac * 100.0
		v.add_child(bar)
	if ready_n > 0:
		var dot := PanelContainer.new()
		dot.theme_type_variation = &"Badge"
		dot.position = Vector2(10, 10)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var n := Ui.label(str(ready_n), "Small", HORIZONTAL_ALIGNMENT_CENTER)
		n.add_theme_color_override("font_color", Color.WHITE)
		dot.add_child(n)
		btn.add_child(dot)
		FxUi.pulse(dot, 1.18, 1.3)
		FxUi.bob(ic, 5.0, 2.2)
	FxUi.gloss(btn, 16.0, 0.5 if ready_n > 0 else 0.0, 3.2, randf() * 2.0)
	btn.pressed.connect(func():
		Sfx.play("ui_tap", -4.0)
		open_sheet(sheet))
	return btn


## The story: one card per chapter, in order. A chapter opens once the one
## before it is cleared; its hero plays it for a 25% bigger first-clear prize.
func _build_story(s: Sheet) -> void:
	var b := s.body
	var cleared: int = Game.data["story"]["cleared"].size()
	b.add_child(_row([Ui.label("Gravelight", "Heading"), _spacer(), Ui.label("%d / %d chapters" % [cleared, STORY_DB.count()], "Small")]))
	for i in STORY_DB.count():
		var ch: Dictionary = STORY_DB.CHAPTERS[i]
		var open := Game.story_open(i)
		var done := Game.story_cleared(str(ch["id"]))
		var hd: Dictionary = DB.HEROES[str(ch["hero"])]
		var c := _card()
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 6)
		var top := _row([Ui.icon_rect(str(hd["icon"]), 58, Color(hd["color"]) if open else Color(1, 1, 1, 0.4))], 14)
		var tv := VBoxContainer.new()
		tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tv.add_theme_constant_override("separation", 0)
		tv.add_child(Ui.label("CHAPTER %d · %s" % [i + 1, str(DB.zone(str(ch["zone"]))["name"]).to_upper()], "Caption"))
		tv.add_child(Ui.label(("✓ " if done else "") + str(ch["title"]), "Heading"))
		top.add_child(tv)
		v.add_child(top)
		var bl := Ui.label(str(ch["blurb"]) if open else "Clear Chapter %d to open this one." % i, "Small")
		bl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(bl)
		var bd: Dictionary = STORY_DB.boss_def(DB.boss_def(str(ch["boss"])), str(ch["boss"]), ch)
		var foe := Ui.label("Boss: %s, %s · Best with the %s" % [bd["name"], bd["title"], hd["name"]], "Small")
		foe.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		foe.add_theme_color_override("font_color", Color(bd["color"]).lightened(0.2))
		v.add_child(foe)
		v.add_child(Ui.label(("First clear: " if not done else "Cleared · ") + _story_reward_text(ch), "Small"))
		if open:
			var btn := Button.new()
			btn.text = "Replay" if done else "Begin"
			btn.theme_type_variation = &"Ghost" if done else &"GoldButton"
			btn.focus_mode = Control.FOCUS_NONE
			btn.custom_minimum_size = Vector2(0, 64)
			btn.pressed.connect(func():
				Sfx.play("ui_press", 0.0)
				_begin_story(ch))
			v.add_child(btn)
		else:
			c.modulate = Color(1, 1, 1, 0.55)
		c.add_child(v)
		b.add_child(c)


func _story_reward_text(ch: Dictionary) -> String:
	var rw: Dictionary = ch["reward"]
	var parts: Array[String] = []
	if int(rw.get("gold", 0)) > 0:
		parts.append("%s gold" % Ui.fmt_num(int(rw["gold"])))
	if int(rw.get("gems", 0)) > 0:
		parts.append("%d gems" % int(rw["gems"]))
	if int(rw.get("shards", 0)) > 0:
		parts.append("%d %s shards" % [int(rw["shards"]), DB.HEROES[str(ch["hero"])]["name"]])
	if str(rw.get("glow", "")) != "":
		parts.append("%s weapon glow" % DB.GLOWS[str(rw["glow"])]["name"])
	return ", ".join(parts)


## Queues the chapter, plays its opening scene and then starts the hunt. The
## chapter's hero leads when unlocked; otherwise the current one does.
func _begin_story(ch: Dictionary) -> void:
	var hid := str(ch["hero"]) if Game.hero(str(ch["hero"]))["unlocked"] else Game.hero_id()
	Game.set_hero(hid)
	if not Game.story_begin(str(ch["id"])):
		return
	if _sheet and is_instance_valid(_sheet):
		_sheet.queue_free()
		_sheet = null
	var cs: Control = CUTSCENE.new()
	%Overlay.add_child(cs)
	cs.finished.connect(func(): lobby.start_hunt())
	cs.play(ch, "intro", hid)


func _build_daily(s: Sheet) -> void:
	var b := s.body
	var st := Game.login_status()
	b.add_child(_row([Ui.label("Login streak", "Heading"), _spacer()]))
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


## What a track reward pays, in words (the season and the weekly event).
func _reward_text(rw: Dictionary) -> String:
	match str(rw["kind"]):
		"gold": return "%d gold" % int(rw["amount"])
		"shards": return "%d shards" % int(rw["amount"])
		"chest": return str(DB.CHESTS[rw["chest"]]["name"])
		"gems": return "%d gems" % int(rw["amount"])
		"egg": return str(SKDB.EGGS[rw["egg"]]["name"])
		"glow": return "%s weapon glow for every hero" % DB.GLOWS[rw["glow"]]["name"]
		"outfit": return "%s outfit for every hero" % DB.OUTFITS[rw["outfit"]]["name"]
	return ""


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
	var note := Ui.label("Tier %d of %d" % [lv, DB.SEASON_TIERS], "Small")
	b.add_child(note)
	var claimed := int(se["claimed"])
	for n in range(maxi(claimed - 1, 1), mini(claimed + 9, DB.SEASON_TIERS) + 1):
		var rw := DB.season_reward(n, Game.season_id())
		var c := _card()
		var row := _row([], 14)
		var num := Ui.label("%d" % n, "Value")
		num.custom_minimum_size = Vector2(54, 0)
		num.add_theme_font_size_override("font_size", 28)
		row.add_child(num)
		var tl := Ui.label(("✓ " if n <= claimed else "") + _reward_text(rw), "Body")
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
func _build_bounties(s: Sheet) -> void:
	var b := s.body
	var left := 86400 - int(Time.get_unix_time_from_system()) % 86400
	b.add_child(Ui.label("New in %dh %02dm" % [left / 3600, (left % 3600) / 60], "Small"))
	var list: Array = Game.data["bounties"]["list"]
	for i in list.size():
		var e: Dictionary = list[i]
		var done := Game.bounty_done(e)
		var claimed: bool = e["claimed"]
		var c := _card()
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 8)
		var rew := "%d gold" % int(e["gold"])
		if int(e.get("gems", 0)) > 0:
			rew += " + %d gems" % int(e["gems"])
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
	# Boss pets are sidekicks now: picked on the Sidekicks sheet.
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
		var src: String = {"boss": "Gravemaw", "hexer": "Hexer Queen", "thorn": "Thornmother", "warden": "Gilded Warden", "rime": "Rime Regent", "cinder": "Cinder Ogre", "elite": "Champions", "nightmare": "Bosses (Nightmare)", "ancient_boss": "Ancient Gravemaw", "ancient_hexer": "Ancient Hexer Queen", "ancient_thorn": "Ancient Thornmother", "ancient_rime": "Ancient Rime Regent", "ancient_cinder": "Ancient Cinder Ogre"}[ud["source"]]
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


## Everything on one screen: mode and place as tiles, difficulty as a
## stepper with your power against the recommended, the omen, and a way in.
func _build_expedition(s: Sheet) -> void:
	var b := s.body
	var note := _exp_note
	_exp_note = ""
	b.add_child(Ui.label("MODE", "Caption"))
	var modes := GridContainer.new()
	modes.columns = 3
	modes.add_theme_constant_override("h_separation", 10)
	modes.add_theme_constant_override("v_separation", 10)
	b.add_child(modes)
	for mid: String in DB.MODE_ORDER:
		var m: Dictionary = DB.MODES[mid]
		var mlock := "" if Game.mode_unlocked(mid) else str(m["unlock"])
		modes.add_child(_tile(MODE_ICON.get(mid, "crossed-swords"), _short_mode(str(m["name"])), "", mid == Game.mode_id(), mlock != "", func():
			if mlock != "":
				_exp_note = "%s: %s" % [m["name"], mlock]
			else:
				Game.set_mode(mid)
			_picked(s)))
	var mode: Dictionary = DB.MODES[Game.mode_id()]
	var blurb: String = mode["blurb"]
	if mode.has("rooms"):
		blurb += " %d rooms on %s." % [int(mode["rooms"][Game.tier()]), DB.TIERS[Game.tier()]["name"]]
	if Game.mode_id() == "descent" and Game.best_depth(Game.hero_id()) > 0:
		blurb += " Your deepest: %d." % Game.best_depth(Game.hero_id())
	var mode_note := note != "" and note in _mode_notes()
	b.add_child(_exp_line(note if mode_note else blurb, mode_note))
	b.add_child(Ui.label("LOCATION", "Caption"))
	var zones := GridContainer.new()
	zones.columns = 3
	zones.add_theme_constant_override("h_separation", 10)
	b.add_child(zones)
	var zone_note := ""
	for zid: String in DB.ZONE_ORDER:
		var z: Dictionary = DB.ZONES[zid]
		var boss: Dictionary = DB.boss_def(z["boss"])
		var lock := "" if Game.zone_unlocked(zid) else str(z["unlock"])
		var zn := "%s: %s" % [z["name"], lock]
		if note == zn:
			zone_note = zn
		zones.add_child(_tile("", str(z["name"]), "Locked" if lock != "" else str(boss["name"]), zid == Game.zone_id(), lock != "", func():
			if lock != "":
				_exp_note = zn
			else:
				Game.set_zone(zid)
			_picked(s)))
	if zone_note != "":
		b.add_child(_exp_line(zone_note, true))
	b.add_child(Ui.label("DIFFICULTY", "Caption"))
	_build_difficulty(b, s)
	var om := Game.weekly_omen()
	var olock := "Not on the Long Road" if Game.mode_id() == "trial" else ""
	b.add_child(_option(str(om["icon"]), "Omen: %s" % om["name"], ("%s Pays 25%% more gold and a better chest." % om["desc"]) + ((" Week best: %d." % Game.weekly_best()) if Game.weekly_best() > 0 else ""), bool(Game.data.get("omen_on", false)) and olock == "", olock, func():
		Game.set_omen(not bool(Game.data.get("omen_on", false)))
		_picked(s)))
	refresh()
	var go := Button.new()
	go.theme_type_variation = "PrimaryButton"
	go.text = _hunt_text
	go.disabled = %Hunt.disabled
	go.focus_mode = Control.FOCUS_NONE
	go.custom_minimum_size = Vector2(0, 96)
	go.pressed.connect(func():
		s.close()
		%Hunt.pressed.emit())
	b.add_child(go)


## The mode names that fit a tile a third of the sheet wide.
func _short_mode(name_: String) -> String:
	return name_.trim_prefix("The ").replace("Endless ", "")


func _mode_notes() -> Array:
	var out := []
	for mid: String in DB.MODE_ORDER:
		out.append("%s: %s" % [DB.MODES[mid]["name"], DB.MODES[mid]["unlock"]] if DB.MODES[mid].has("unlock") else "")
	return out


func _exp_line(text: String, warn: bool) -> Label:
	var l := Ui.label(("Locked · " + text) if warn else text, "Small")
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if warn:
		l.add_theme_color_override("font_color", Color(0.95, 0.72, 0.45))
	return l


## A square choice: an icon (or none) over a name and a small line.
func _tile(icon: String, title: String, sub: String, chosen: bool, locked: bool, cb: Callable) -> Button:
	var btn := Button.new()
	btn.theme_type_variation = "Choice"
	btn.toggle_mode = true
	btn.button_pressed = chosen
	btn.focus_mode = Control.FOCUS_NONE
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size = Vector2(0, 112 if icon != "" else 92)
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 4)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(v)
	var tone := Color(0.91, 0.71, 0.35) if chosen else Color(0.64, 0.6, 0.54)
	if icon != "" or locked:
		var cc := CenterContainer.new()
		cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cc.add_child(Ui.icon_rect("padlock" if locked else icon, 40 if icon != "" else 26, tone))
		v.add_child(cc)
	var tl := Ui.label(title, "Body", HORIZONTAL_ALIGNMENT_CENTER)
	tl.add_theme_font_size_override("font_size", 21)
	if chosen:
		tl.add_theme_color_override("font_color", Color(0.95, 0.8, 0.52))
	v.add_child(tl)
	if sub != "":
		v.add_child(Ui.label(sub, "Caption", HORIZONTAL_ALIGNMENT_CENTER))
	if locked:
		v.modulate.a = 0.45
	btn.pressed.connect(cb)
	return btn


## ‹ Tier › with a pip per tier, your power against the recommended, and
## what the tier does to the dead.
func _build_difficulty(b: VBoxContainer, s: Sheet) -> void:
	var i := Game.tier()
	var top := Game.mode_tier_unlocked()
	var t: Dictionary = DB.TIERS[i]
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	b.add_child(row)
	var prev := _step("‹", i > 0, func():
		Game.set_tier(i - 1)
		_picked(s))
	row.add_child(prev)
	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", 0)
	row.add_child(mid)
	var nm := Ui.label(str(t["name"]), "Title", HORIZONTAL_ALIGNMENT_CENTER)
	nm.add_theme_font_size_override("font_size", 36)
	nm.add_theme_color_override("font_color", t["color"])
	mid.add_child(nm)
	var loot := "loot ×%s · %s" % [_num(t["loot"]), DB.CHESTS[t["chest"]]["name"]]
	mid.add_child(Ui.label("%d of %d · %s" % [i + 1, DB.TIERS.size(), loot], "Small", HORIZONTAL_ALIGNMENT_CENTER))
	row.add_child(_step("›", i < top, func():
		Game.set_tier(i + 1)
		_picked(s)))
	var pips := HBoxContainer.new()
	pips.add_theme_constant_override("separation", 6)
	b.add_child(pips)
	for k in DB.TIERS.size():
		var p := Panel.new()
		p.custom_minimum_size = Vector2(0, 10)
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var st := StyleBoxFlat.new()
		st.set_corner_radius_all(5)
		st.bg_color = Color(DB.TIERS[k]["color"]) if k <= top else Color(0.17, 0.15, 0.19)
		if k == i:
			st.set_border_width_all(2)
			st.border_color = Color(0.98, 0.85, 0.55)
			st.expand_margin_top = 3
			st.expand_margin_bottom = 3
		elif k <= top:
			st.bg_color = st.bg_color.darkened(0.35)
		p.add_theme_stylebox_override("panel", st)
		pips.add_child(p)
	var pw := Game.power_score(Game.hero_id())
	var need := int(t["power"])
	var pr := _row([Ui.label("Your power %s" % Ui.fmt_num(pw), "Body"), _spacer()], 8)
	var rec := Ui.label("Recommended %s" % Ui.fmt_num(need), "Body")
	rec.add_theme_color_override("font_color", Color(0.5, 0.85, 0.55) if pw >= need else Color(0.9, 0.45, 0.38))
	pr.add_child(rec)
	b.add_child(pr)
	var what := "The dead as they are" if i == 0 else "Foes ×%s health, ×%s damage" % [_num(t["hp"]), _num(t["dmg"])]
	if float(t["mech"]) > 0.0:
		what += " · telegraphed blows take %d%% of your health · healing −%d%%" % [int(round(float(t["mech"]) * 100.0)), int(round((1.0 - float(t["heal"])) * 100.0))]
	if i == top and top < DB.TIERS.size() - 1:
		what += "\n%s opens when you %s on %s." % [DB.TIERS[top + 1]["name"], "fell a boss" if Game.mode_id() == "descent" else "win", t["name"]]
	var wl := Ui.label(what, "Small")
	wl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.add_child(wl)


func _step(text: String, on: bool, cb: Callable) -> Button:
	var btn := Button.new()
	btn.theme_type_variation = "RoundButton"
	btn.text = text
	btn.disabled = not on
	btn.focus_mode = Control.FOCUS_NONE
	btn.custom_minimum_size = Vector2(76, 76)
	btn.add_theme_font_size_override("font_size", 34)
	btn.pressed.connect(cb)
	return btn


func _picked(s: Sheet) -> void:
	Sfx.play("ui_tap", -4.0)
	refresh()
	s.rebuild()


func _build_settings(s: Sheet) -> void:
	var b := s.body
	b.add_child(SettingsBox.new())
	b.add_child(HSeparator.new())
	_privacy_rows(b)
	b.add_child(HSeparator.new())
	var cr := Ui.label("Art: KayKit by Kay Lousberg (CC0). Sidekicks and bosses: LasquetiSpice, Alexei Ostapenko, Batuhan13, matisosanimation, Joseph Payeur, Spinnee, danielmclogan, BeardenInc, EvgeshQa, Mateus Schwaab, Riltariki, moonbaby2402 (provisional) (CC BY 4.0, Sketchfab). Icons: game-icons.net (CC BY 3.0). Music and boss stings: Kevin MacLeod (CC BY 4.0). Effects: Kenney, rubberduck and others (CC0). Full list in CREDITS.md.", "Small")
	cr.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.add_child(cr)
	var ota := get_node_or_null("/root/Ota")
	var ver := "Gravelight v%s" % ProjectSettings.get_setting("application/config/version")
	if ota:
		ver += " · build %d · content %d" % [int(ota.get("baked_build")), int(ota.get("build"))]
	b.add_child(Ui.label(ver, "Small"))
	_error_report_row(b, ver)


## Privacy: the two choices from the first-launch screen, and the policy.
func _privacy_rows(b: Control) -> void:
	var PV := preload("res://src/core/privacy.gd")
	b.add_child(Ui.label("PRIVACY", "Caption"))
	var rec: Dictionary = Game.data["privacy"]
	var online := CheckButton.new()
	online.text = "Online play"
	online.button_pressed = not bool(Game.data["online"]["off"])
	online.focus_mode = Control.FOCUS_NONE
	online.toggled.connect(func(on: bool):
		PV.record(bool(rec["crash"]), on)
		Sfx.play("ui_toggle", -4.0))
	b.add_child(online)
	var crash := CheckButton.new()
	crash.text = "Share crash reports"
	crash.button_pressed = bool(rec["crash"])
	crash.focus_mode = Control.FOCUS_NONE
	crash.toggled.connect(func(on: bool):
		PV.record(on, not bool(Game.data["online"]["off"]))
		Sfx.play("ui_toggle", -4.0))
	b.add_child(crash)
	var note := Ui.label("Online play applies on the next launch. Crash reports are optional and never include your save or name.", "Small")
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.add_child(note)
	var pol := Button.new()
	pol.name = "PolicyLink"
	pol.text = "Privacy policy"
	pol.theme_type_variation = "Ghost"
	pol.focus_mode = Control.FOCUS_NONE
	pol.pressed.connect(func(): OS.shell_open(PV.POLICY_URL))
	b.add_child(pol)


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


# --- Sidekicks ----------------------------------------------------------------

const SKS := preload("res://src/autoload/sidekicks.gd")
const SKDB := preload("res://src/data/sidekick_db.gd")
const HATCH := preload("res://src/ui/hatch_show.gd")
const Care := preload("res://src/core/pet_care.gd")
const PetsTab := preload("res://src/lobby/pets_tab.gd")
const PetStage := preload("res://src/lobby/pet_stage.gd")
## The sidekick whose detail page is open in the sheet ("" = the stable).
var _sk_detail := ""


## A pet's name as the player sees it: its nickname, else its breed (by stage).
func _pet_name(id: String) -> String:
	return Care.shown_name(Game.data, id, SKDB.display_name(id, SKS.kills(Game.data, id)))


## "Bred 2× · next rest 18h": what a litter has cost this pet and will cost it.
func _rest_note(id: String) -> String:
	var n := Care.bred_times(Game.data, id)
	var nxt := Care.hours_text(Care.next_rest(Game.data, id))
	if n == 0:
		return "Never bred · rests %s after a litter" % nxt
	return "Bred %d× · rests %s after the next litter%s" % [n, nxt, " (the longest)" if Care.at_cap(Game.data, id) else ""]


## The egg just hatched in the sheet, handed to the hatching show.
var _hatch_news := {}


## The hatchery: every egg warming, by the clock or by kills, whichever is
## first. A ready egg hatches on a tap; gems finish one now.
func _build_hatchery(s: Sheet) -> void:
	var b := s.body
	var now := int(Time.get_unix_time_from_system())
	var eggs: Array = SKS.hatchery(Game.data)
	var head := _row([Ui.label("HATCHERY · %d / %d" % [eggs.size(), SKDB.HATCH_SLOTS], "Caption"), _spacer(), Ui.icon_rect("gems", 26, Color(0.55, 0.9, 1.0)), Ui.label("%d" % SKS.gems(Game.data), "Value")], 8)
	b.add_child(head)
	if eggs.is_empty():
		var none := Ui.label("No eggs. Find them in chests, on the season road, and, rarely, as exotic drops from bosses.", "Small")
		none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.add_child(none)
		return
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	for e: Dictionary in eggs:
		grid.add_child(_egg_tile(s, e, now))
	b.add_child(grid)


func _egg_tile(s: Sheet, e: Dictionary, now: int) -> Control:
	var ed: Dictionary = SKDB.EGGS[str(e["kind"])]
	var col: Color = ed["color"]
	var uid := int(e["uid"])
	var c := _card()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.custom_minimum_size = Vector2(0, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	v.add_child(_row([Ui.icon_rect("egg-clutch", 40, col), Ui.label(str(ed["name"]), "Body")], 8))
	var hatchable := SKS.egg_ready(e, now)
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 12)
	bar.value = SKS.egg_frac(e, now) * 100.0
	v.add_child(bar)
	var left := maxi(int(ed["kills"]) - int(e["kills"]), 0)
	v.add_child(Ui.label("Ready!" if hatchable else "%s or %d kills" % [_dur(SKS.egg_secs_left(e, now)), left], "Small"))
	var go := Button.new()
	go.focus_mode = Control.FOCUS_NONE
	go.theme_type_variation = &"GoldButton"
	go.add_theme_font_size_override("font_size", 24)
	go.clip_text = true
	if hatchable:
		go.text = "HATCH"
		go.pressed.connect(func():
			_hatch_news = SKS.hatch(Game.data, uid, int(Time.get_unix_time_from_system()))
			_after_hatch(s))
	else:
		var cost := SKS.rush_cost(e, now)
		go.text = "%d gems" % cost
		go.disabled = SKS.gems(Game.data) < cost
		go.pressed.connect(func():
			_hatch_news = SKS.rush(Game.data, uid, int(Time.get_unix_time_from_system()))
			_after_hatch(s))
	v.add_child(go)
	c.add_child(v)
	return c


## "5h 12m", "14m", "40s".
static func _dur(secs: int) -> String:
	if secs >= 3600:
		return "%dh %02dm" % [secs / 3600, (secs % 3600) / 60]
	if secs >= 60:
		return "%dm" % (secs / 60)
	return "%ds" % secs


func _after_hatch(s: Sheet) -> void:
	if _hatch_news.is_empty():
		return
	Game.bounty_note("hatched")
	Game.save()
	_refresh_camp_sidekick()
	var res := _hatch_news
	_hatch_news = {}
	s.rebuild()
	play_hatch(res)


## The hatching: the egg wobbles, cracks and bursts, and the sidekick steps out.
func play_hatch(res: Dictionary) -> void:
	HATCH.new().play(%Overlay, res)


func _sidekick_tile(s: Sheet, id: String) -> Control:
	var d: Dictionary = SKDB.def(id)
	if SKS.hidden(Game.data, id):
		return _sk_tile_box("egg-clutch", Color(0.5, 0.5, 0.55), "???", "Hidden", 0.0, true, Callable())
	if SKS.is_owned(Game.data, id):
		var k := SKS.kills(Game.data, id)
		var here := SKS.active(Game.data) == id
		var tag := ""
		if d.has("genes"):
			tag = " · %s" % SKDB.GRADES[SKDB.grade(d["genes"])]
		return _sk_tile_box(str(d["icon"]), Color(d["color"]), _pet_name(id), ("At your side · " if here else "") + "Bond %d · %s" % [SKDB.bond_level(k), SKDB.STAGE_LABELS[SKDB.stage_of(SKDB.bond_level(k))]] + tag, -1.0, false, func():
			_sk_detail = id
			s.rebuild())
	var pr: Array = SKS.progress(Game.data, id)
	return _sk_tile_box(str(d["icon"]), Color(d["color"]), str(d["name"]), str(pr[0]), float(pr[1]), true, Callable())


## One stable tile: icon, name, a status line, and a bar when `frac` >= 0.
func _sk_tile_box(icon: String, col: Color, title: String, status: String, frac: float, locked: bool, cb: Callable) -> Control:
	var btn := Button.new()
	btn.theme_type_variation = &"Card"
	btn.focus_mode = Control.FOCUS_NONE
	btn.custom_minimum_size = Vector2(0, 132)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.disabled = not cb.is_valid()
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 12)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 4)
	var ic := Ui.icon_rect(icon if Ui.icon(icon) else "ghost", 40, col if not locked else col.darkened(0.45))
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(ic)
	var t := Ui.label(title, "Body")
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if locked:
		t.add_theme_color_override("font_color", Color(0.7, 0.7, 0.72))
	v.add_child(t)
	var st := Ui.label(status, "Small")
	st.mouse_filter = Control.MOUSE_FILTER_IGNORE
	st.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(st)
	if frac >= 0.0 and locked or frac > 0.0:
		var bar := ProgressBar.new()
		bar.theme_type_variation = &"XPBar"
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0, 10)
		bar.value = clampf(frac, 0.0, 1.0) * 100.0
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(bar)
	btn.add_child(v)
	if cb.is_valid():
		btn.pressed.connect(func():
			Sfx.play("ui_tap", -4.0)
			cb.call())
	return btn


func _build_sidekick_detail(s: Sheet, id: String) -> void:
	var b := s.body
	var d: Dictionary = SKDB.def(id)
	var k := SKS.kills(Game.data, id)
	var lv := SKDB.bond_level(k)
	var back := Button.new()
	back.theme_type_variation = &"Ghost"
	back.text = "‹ Stable"
	back.focus_mode = Control.FOCUS_NONE
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back.pressed.connect(func():
		Sfx.play("ui_back", -4.0)
		_sk_detail = ""
		s.rebuild())
	b.add_child(back)
	b.add_child(PetStage.make(id, 330))
	var title := Ui.label(_pet_name(id), "Title")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.clip_text = true
	b.add_child(_row([title, PetsTab.rename_button(self, id, func():
		_refresh_camp_sidekick()
		s.rebuild())], 10))
	var rar := SKDB.rarity(id)
	var kind := SKDB.display_name(id, k)
	var rchip := Ui.label(("%s · " % kind if Care.nickname(Game.data, id) != "" else "") + SKDB.GRADES[rar].to_upper(), "Caption")
	rchip.add_theme_color_override("font_color", SKDB.GRADE_COLORS[rar])
	b.add_child(rchip)
	var origin := Ui.label("%s · %s" % [d["origin"], d["element"]], "Small")
	origin.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.add_child(origin)
	var bc := _card()
	var bv := VBoxContainer.new()
	bv.add_theme_constant_override("separation", 4)
	var nxt := SKDB.bond_next(k)
	bv.add_child(_row([Ui.label("Bond %d" % lv, "Heading"), _spacer(), Ui.label(("%s / %s kills" % [Ui.fmt_num(k), Ui.fmt_num(nxt)]) if lv < SKDB.BOND_MAX else "Max bond", "Small")]))
	var bar := ProgressBar.new()
	bar.theme_type_variation = &"XPBar"
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 12)
	var lo := int(SKDB.BOND_KILLS[lv - 1])
	bar.value = 100.0 if lv >= SKDB.BOND_MAX else clampf(float(k - lo) / float(maxi(nxt - lo, 1)), 0.0, 1.0) * 100.0
	bv.add_child(bar)
	bc.add_child(bv)
	b.add_child(bc)
	b.add_child(_stage_card(id, lv))
	b.add_child(_breeding_card(id))
	if d.has("genes"):
		b.add_child(_genome_card(d))
	var ac := _card()
	var av := VBoxContainer.new()
	av.add_theme_constant_override("separation", 4)
	av.add_child(Ui.label("ABILITY · %s" % str(d["ability"]["name"]).to_upper() + ((" + %s" % str(d["echo"]["name"]).to_upper()) if d.has("echo") else ""), "Caption"))
	var desc := Ui.label(str(d["desc"]), "Body")
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	av.add_child(desc)
	ac.add_child(av)
	b.add_child(ac)
	var rc := _card()
	var rv := VBoxContainer.new()
	rv.add_theme_constant_override("separation", 4)
	rv.add_child(Ui.label("BOND REWARDS", "Caption"))
	for pair in SKDB.bond_rewards(id):
		var got := lv >= int(pair[0])
		var rl := Ui.label("%d · %s%s" % [int(pair[0]), pair[1], "  ✓" if got else ""], "Body")
		rl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		rl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.5) if got else Color(0.78, 0.78, 0.8))
		rv.add_child(rl)
	rc.add_child(rv)
	b.add_child(rc)
	var here := SKS.active(Game.data) == id
	var go := Button.new()
	go.theme_type_variation = &"GoldButton" if not here else &"Ghost"
	go.text = "AT YOUR SIDE" if here else "TAKE ALONG"
	go.focus_mode = Control.FOCUS_NONE
	go.custom_minimum_size = Vector2(0, 72)
	go.pressed.connect(func():
		if here:
			SKS.set_active(Game.data, "")
		else:
			SKS.set_active(Game.data, id)
			Sfx.play("gear_equip", -3.0)
		Game.save()
		_refresh_camp_sidekick()
		s.rebuild())
	b.add_child(go)
	if here:
		b.add_child(Ui.label("Tap again to send it home.", "Small", HORIZONTAL_ALIGNMENT_CENTER))
	var pinned := SKS.is_pinned(Game.data, id)
	var pin := Button.new()
	pin.theme_type_variation = &"Ghost"
	pin.text = "★ IN YOUR SHOWCASE" if pinned else "PIN TO SHOWCASE"
	pin.focus_mode = Control.FOCUS_NONE
	pin.custom_minimum_size = Vector2(0, 64)
	pin.pressed.connect(func():
		if not SKS.pin(Game.data, id):
			Sfx.play("ui_error", -6.0)
			return
		Sfx.play("ui_toggle", -4.0)
		Game.save()
		s.rebuild())
	b.add_child(pin)
	if not pinned and (Game.data["sidekicks"]["showcase"] as Array).size() >= SKDB.SHOWCASE_SLOTS:
		b.add_child(Ui.label("The showcase is full: unpin one first.", "Small", HORIZONTAL_ALIGNMENT_CENTER))


## How often this pet may breed: the litters so far, the rest it is on (a bar
## and a countdown) and the rest the next one will cost.
func _breeding_card(id: String) -> Control:
	var now := int(Time.get_unix_time_from_system())
	var rest := SKS.resting(Game.data, id, now)
	var c := _card()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	v.add_child(Ui.label("BREEDING", "Caption"))
	if rest > 0:
		var prev := maxi(Care.bred_times(Game.data, id) - 1, 0)
		var warm := Ui.label("Resting · back in %s" % _dur(rest), "Body")
		warm.add_theme_color_override("font_color", Color(1.0, 0.78, 0.4))
		v.add_child(warm)
		var bar := ProgressBar.new()
		bar.theme_type_variation = &"XPBar"
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0, 12)
		bar.value = (1.0 - clampf(float(rest) / float(Care.rest_secs(prev)), 0.0, 1.0)) * 100.0
		v.add_child(bar)
	elif SKS.bond(Game.data, id) < SKDB.BREED_BOND:
		v.add_child(Ui.label("Ready at Bond %d" % SKDB.BREED_BOND, "Body"))
	else:
		var ok := Ui.label("Ready to breed", "Body")
		ok.add_theme_color_override("font_color", Color(0.6, 0.95, 0.6))
		v.add_child(ok)
	var note := Ui.label(_rest_note(id), "Small")
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(note)
	c.add_child(v)
	return c


## The evolution ladder: Hatchling, Grown, Elder, with what each gives.
func _stage_card(id: String, lv: int) -> Control:
	var cur := SKDB.stage_of(lv)
	var c := _card()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	v.add_child(Ui.label("EVOLUTION", "Caption"))
	for st in 3:
		var reached := st <= cur
		var l := Ui.label("%s %s · Bond %d%s" % ["●" if st == cur else ("✓" if reached else "○"), SKDB.stage_name(id, st), int(SKDB.STAGE_BOND[st]), "  ← now" if st == cur else ""], "Body")
		l.add_theme_color_override("font_color", Color(1.0, 0.88, 0.5) if reached else Color(0.6, 0.6, 0.65))
		v.add_child(l)
		var n := Ui.label("     " + SKDB.STAGE_NOTES[st], "Small")
		n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(n)
	c.add_child(v)
	return c


## A bred sidekick's traits: grade, element, perk, and each gene.
func _genome_card(d: Dictionary) -> Control:
	var g: Dictionary = d["genes"]
	var gr := SKDB.grade(g)
	var c := _card()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	var head := Ui.label("%s · %s" % [SKDB.GRADES[gr].to_upper(), str(d["element"]).to_upper()], "Caption")
	head.add_theme_color_override("font_color", SKDB.GRADE_COLORS[gr])
	v.add_child(head)
	var per: Dictionary = SKDB.PERSONALITIES.get(str(g.get("personality", "")), {})
	if not per.is_empty():
		v.add_child(Ui.label("%s: %s" % [per["name"], per["perk"]], "Body"))
	var lines := []
	for k in ["dmg", "haste", "reach", "size"]:
		lines.append("%s %+d%%" % [{"dmg": "Damage", "haste": "Speed", "reach": "Reach", "size": "Size"}[k], int(round((float(g.get(k, 1.0)) - 1.0) * 100.0))])
	var gl := Ui.label("  ·  ".join(PackedStringArray(lines)), "Small")
	gl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(gl)
	var look := "%s pattern" % str(g.get("pattern", "plain")).capitalize()
	if bool(g.get("glow", false)):
		look += " · glowing"
	if str(g.get("echo", "")) != "":
		look += " · echoes %s" % SKDB.def(str(g["echo"]))["name"]
	v.add_child(Ui.label(look, "Small"))
	c.add_child(v)
	return c


var _breed_a := ""
var _breed_b := ""
var _breed_news := ""


## Breeding: pick two sidekicks at Bond 3+, pay gold, and a Nest Egg holding
## their child goes to the hatchery. The pair determines the breed (a parent's,
## or sometimes their hybrid); the traits are rolled and unique. Each parent
## then rests, longer every time it breeds (Care.REST_HOURS).
func _build_breeding(s: Sheet) -> void:
	var b := s.body
	var now := int(Time.get_unix_time_from_system())
	var info := Ui.label("Two pets at Bond %d+ lay a Nest Egg. The pair decides the breed; every child rolls its own traits." % SKDB.BREED_BOND, "Small")
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.add_child(info)
	b.add_child(_rest_ladder())
	if _breed_news != "":
		var news := Ui.label(_breed_news, "Heading", HORIZONTAL_ALIGNMENT_CENTER)
		news.add_theme_color_override("font_color", Color(1.0, 0.88, 0.5))
		b.add_child(news)
		_breed_news = ""
	var slots := HBoxContainer.new()
	slots.add_theme_constant_override("separation", 10)
	slots.add_child(_breed_slot(s, _breed_a, true))
	var plus := Ui.label("+", "Title", HORIZONTAL_ALIGNMENT_CENTER)
	plus.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slots.add_child(plus)
	slots.add_child(_breed_slot(s, _breed_b, false))
	b.add_child(slots)
	var plabel := Ui.label("PARENTS", "Caption")
	b.add_child(plabel)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	for id: String in SKDB.ORDER + SKS.bred_ids(Game.data):
		if not SKS.is_owned(Game.data, id):
			continue
		var d: Dictionary = SKDB.def(id)
		var lv := SKS.bond(Game.data, id)
		var rest := SKS.resting(Game.data, id, now)
		var sel := id == _breed_a or id == _breed_b
		var status := ("Resting %s" % _dur(rest)) if rest > 0 else (("Bond %d · next rest %s" % [lv, Care.hours_text(Care.next_rest(Game.data, id))]) if lv >= SKDB.BREED_BOND else "Bond %d (needs %d)" % [lv, SKDB.BREED_BOND])
		var ok := rest == 0 and lv >= SKDB.BREED_BOND
		var frac := -1.0
		if rest > 0:
			frac = clampf(float(rest) / float(Care.rest_secs(maxi(Care.bred_times(Game.data, id) - 1, 0))), 0.0, 1.0)
		var tile := _sk_tile_box(str(d["icon"]), Color(d["color"]), ("✓ " if sel else "") + _pet_name(id), status, frac, not ok, func():
			if id == _breed_a:
				_breed_a = ""
			elif id == _breed_b:
				_breed_b = ""
			elif _breed_a == "":
				_breed_a = id
			else:
				_breed_b = id
			s.rebuild())
		(tile as Button).disabled = not ok
		grid.add_child(tile)
	b.add_child(grid)
	var picked := _breed_a != "" and _breed_b != ""
	if picked:
		var hy := SKDB.hybrid_for(SKDB.species(_breed_a), SKDB.species(_breed_b))
		var pc := _card()
		var pv := VBoxContainer.new()
		pv.add_theme_constant_override("separation", 4)
		pv.add_child(Ui.label("OFFSPRING", "Caption"))
		var odds := "%s or %s" % [SKDB.def(_breed_a)["name"], SKDB.def(_breed_b)["name"]]
		if hy != "":
			odds += "\n%d%% chance of a %s" % [int(SKDB.BREED_HYBRID * 100.0), SKDB.BREEDS[hy]["name"]]
		var ol := Ui.label(odds + "\nTraits are rolled: looks, stats, element, personality.", "Body")
		ol.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		pv.add_child(ol)
		var rl := Ui.label("Then they rest: %s %s · %s %s" % [_pet_name(_breed_a), Care.hours_text(Care.next_rest(Game.data, _breed_a)), _pet_name(_breed_b), Care.hours_text(Care.next_rest(Game.data, _breed_b))], "Small")
		rl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		rl.add_theme_color_override("font_color", Color(1.0, 0.78, 0.4))
		pv.add_child(rl)
		pc.add_child(pv)
		b.add_child(pc)
	var why := SKS.breed_block(Game.data, _breed_a, _breed_b, now) if picked else "Pick two parents"
	var go := Button.new()
	go.theme_type_variation = &"GoldButton"
	go.text = "BREED · %s GOLD" % Ui.fmt_num(SKDB.BREED_GOLD)
	go.focus_mode = Control.FOCUS_NONE
	go.custom_minimum_size = Vector2(0, 72)
	go.disabled = why != ""
	go.pressed.connect(func():
		var e := SKS.breed(Game.data, _breed_a, _breed_b, int(Time.get_unix_time_from_system()), randi())
		if e.is_empty():
			return
		_breed_a = ""
		_breed_b = ""
		_breed_news = "A Nest Egg is in your hatchery!"
		Game.bounty_note("bred")
		Sfx.play("rare_chime", 0.0)
		Game.save()
		_refresh_camp_sidekick()
		s.rebuild())
	b.add_child(go)
	if why != "":
		b.add_child(Ui.label(why, "Small", HORIZONTAL_ALIGNMENT_CENTER))
	# Parents last: the offspring and the button stay in view.
	b.move_child(plabel, b.get_child_count() - 1)
	b.move_child(grid, b.get_child_count() - 1)


## The rests a pet earns, litter by litter: 8h, 12h, 18h, 24h, 36h, 48h.
func _rest_ladder() -> Control:
	var c := _card()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.add_child(Ui.label("REST AFTER EACH LITTER", "Caption"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	for i in Care.REST_HOURS.size():
		var chip := PanelContainer.new()
		chip.theme_type_variation = &"Card"
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var l := Ui.label("%dh" % int(Care.REST_HOURS[i]), "Body", HORIZONTAL_ALIGNMENT_CENTER)
		l.add_theme_color_override("font_color", Color(1.0, 0.86, 0.45) if i == Care.REST_HOURS.size() - 1 else Color(0.9, 0.88, 0.84))
		chip.add_child(l)
		row.add_child(chip)
	v.add_child(row)
	var note := Ui.label("Every litter makes a pet rest longer, up to %s. It never goes past that." % Care.hours_text(Care.max_rest()), "Small")
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(note)
	c.add_child(v)
	return c


## One parent slot over the pair: the pet, or an invitation to pick one.
func _breed_slot(s: Sheet, id: String, first: bool) -> Control:
	var btn := Button.new()
	btn.theme_type_variation = &"Card"
	btn.focus_mode = Control.FOCUS_NONE
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size = Vector2(0, 150)
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 10)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 2)
	if id == "":
		var q := Ui.icon_rect("egg-clutch", 48, Color(1, 1, 1, 0.25))
		q.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(q)
		var l := Ui.label("Parent %s" % ("one" if first else "two"), "Small", HORIZONTAL_ALIGNMENT_CENTER)
		l.modulate.a = 0.6
		v.add_child(l)
		btn.disabled = true
	else:
		var d: Dictionary = SKDB.def(id)
		var ic := Ui.icon_rect(str(d["icon"]), 56, Color(d["color"]))
		ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(ic)
		var nm := Ui.label(_pet_name(id), "Body", HORIZONTAL_ALIGNMENT_CENTER)
		nm.clip_text = true
		v.add_child(nm)
		var rl := Ui.label("Rests %s after" % Care.hours_text(Care.next_rest(Game.data, id)), "Small", HORIZONTAL_ALIGNMENT_CENTER)
		rl.add_theme_color_override("font_color", Color(1.0, 0.78, 0.4))
		v.add_child(rl)
		btn.pressed.connect(func():
			Sfx.play("ui_tap", -4.0)
			if first:
				_breed_a = ""
			else:
				_breed_b = ""
			s.rebuild())
	for ch in v.get_children():
		(ch as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(v)
	return btn


## The collection log: every breed and trait you've hatched, and what's left.
func _build_collection(s: Sheet) -> void:
	var b := s.body
	var f: Dictionary = SKS.block(Game.data)["found"]
	var breeds := SKS.breeds_found(Game.data)
	var all_breeds: Array = SKDB.ORDER + SKDB.BREED_ORDER
	var sections := [
		["BREEDS", all_breeds, breeds, func(k): return str(SKDB.def(k)["name"])],
		["ELEMENTS", SKDB.ELEMENTS.keys(), f["elements"], func(k): return str(SKDB.ELEMENTS[k]["name"])],
		["PATTERNS", SKDB.PATTERNS.slice(1), f["patterns"], func(k): return str(k).capitalize()],
		["PERSONALITIES", SKDB.PERSONALITIES.keys(), f["personalities"], func(k): return str(SKDB.PERSONALITIES[k]["name"])],
	]
	for sec in sections:
		var have: Array = sec[2]
		var total: Array = sec[1]
		var n := total.filter(func(k): return have.has(k)).size()
		b.add_child(Ui.label("%s · %d / %d" % [sec[0], n, total.size()], "Caption"))
		var fl := HFlowContainer.new()
		fl.add_theme_constant_override("h_separation", 8)
		fl.add_theme_constant_override("v_separation", 8)
		for k in total:
			var got := have.has(k)
			var l := Ui.label(str(sec[3].call(k)) if got else "???", "Small")
			l.add_theme_color_override("font_color", Color(1.0, 0.88, 0.5) if got else Color(0.5, 0.5, 0.55))
			var pc := _card()
			pc.add_child(l)
			fl.add_child(pc)
		b.add_child(fl)
	b.add_child(Ui.label("GLOW · %s" % ("found" if bool(f["glow"]) else "???"), "Caption"))


## The camp shows the sidekick at your side by the fire.
func _refresh_camp_sidekick() -> void:
	if lobby and is_instance_valid(lobby) and lobby.has_method("refresh_sidekick"):
		lobby.refresh_sidekick()
