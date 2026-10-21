class_name LobbyUI
extends CanvasLayer
## The camp's interface: top bar, hero switcher, difficulty, the big button,
## and the sheets (Heroes, Bag, Skills, Log, Settings).

var lobby: Node3D
var chest_opening := false
var _shown_hero := ""
var _sheet: Sheet
var _sheet_name := ""
var equipment: Equipment


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
	for pair in [[%NavHeroes, "heroes", "visored-helm"], [%NavBag, "bag", "swap-bag"], [%NavSkills, "skills", "upgrade"], [%NavLog, "log", "scroll-unfurled"], [%NavBounty, "bounties", "archery-target"]]:
		var b: Button = pair[0]
		b.icon = Ui.icon(pair[2])
		var sheet_name: String = pair[1]
		b.pressed.connect(func(): open_sheet(sheet_name))
	for i in DB.ZONE_ORDER.size():
		var zb: Button = %Zones.get_child(i)
		var zid: String = DB.ZONE_ORDER[i]
		zb.pressed.connect(func():
			Game.set_zone(zid)
			Sfx.play("ui_press", -2.0)
			refresh())
	for i in DB.TIERS.size():
		var b2: Button = %Tiers.get_child(i)
		var ti := i
		b2.pressed.connect(func(): _pick_tier(ti))
	%CombatIcon.texture = Ui.icon("crossed-swords")
	%GoldIcon.texture = Ui.icon("two-coins")
	%Chest.visible = false
	Game.changed.connect(refresh)
	refresh()


func refresh() -> void:
	%Gold.text = Ui.fmt_num(Game.gold())
	%Combat.text = "Combat %d" % Game.combat_level()
	var id := _shown_hero
	var d: Dictionary = DB.HEROES[id]
	var h := Game.hero(id)
	%HeroName.text = d["name"]
	%HeroTitle.text = "%s · %s" % [d["title"], d["role"]]
	%HeroLevel.text = "Lv %d" % int(h["level"])
	%Power.text = "Power %d" % Game.power_score(id)
	var locked := not bool(h["unlocked"])
	%Hunt.disabled = locked
	if locked:
		%Hunt.text = "Locked"
		%Lock.visible = true
		%Lock.text = "Clear Veteran, or gather 20 shards (%d/20)" % int(h["shards"]) if d["unlock"] == "veteran" else "Gather 20 shards (%d/20)" % int(h["shards"])
	else:
		%Hunt.text = DB.zone(Game.zone_id())["enter"]
		var shut := Game.zone_unlocked("depths")
		%Lock.visible = not shut
		%Lock.text = "%s opens: %s" % [DB.ZONES["depths"]["name"], DB.ZONES["depths"]["unlock"]]
	for i in DB.ZONE_ORDER.size():
		var zb: Button = %Zones.get_child(i)
		var z: Dictionary = DB.ZONES[DB.ZONE_ORDER[i]]
		var zopen := Game.zone_unlocked(DB.ZONE_ORDER[i])
		zb.disabled = not zopen
		zb.text = z["name"] if zopen else "🔒 " + str(z["name"])
		zb.button_pressed = DB.ZONE_ORDER[i] == Game.zone_id()
	for i in DB.TIERS.size():
		var b: Button = %Tiers.get_child(i)
		var t: Dictionary = DB.TIERS[i]
		var open := i <= int(Game.data["tier_unlocked"])
		b.disabled = not open
		b.text = t["name"] if open else "🔒 " + t["name"]
		b.button_pressed = i == Game.tier()
		b.add_theme_color_override("font_pressed_color", t["color"])
		b.add_theme_color_override("font_hover_pressed_color", t["color"])
	%NavHeroes.get_node("Dot").visible = _any_upgrade()
	%NavBag.get_node("Dot").visible = Game.new_item_count() > 0
	%NavBounty.get_node("Dot").visible = Game.bounty_claimable() > 0


func _any_upgrade() -> bool:
	for id in DB.HERO_ORDER:
		if Game.can_upgrade(id):
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


func _pick_tier(i: int) -> void:
	Game.set_tier(i)
	Sfx.play("ui_tap", -4.0)
	refresh()


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
	%Chest.text = "Open your %s" % c["name"]
	%Chest.icon = Ui.icon("locked-chest")
	Ui.pop_in(%Chest, 0.4, 0.6)


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
			_sheet.open("Skills", _build_skills)
		"log":
			_sheet.open("Collection Log", _build_log)
		"bounties":
			_sheet.open("Daily Bounties", _build_bounties)
		"settings":
			_sheet.open("Settings", _build_settings, 0.7)
	_sheet.closed.connect(refresh)


## The portraits finished rendering after the Heroes sheet was already opened.
func portraits_ready() -> void:
	if _sheet and is_instance_valid(_sheet) and _sheet_name == "heroes":
		_sheet.rebuild()


func _card() -> PanelContainer:
	var c := PanelContainer.new()
	c.theme_type_variation = "Card"
	return c


func _row(children: Array, sep := 12) -> HBoxContainer:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", sep)
	for c in children:
		r.add_child(c)
	return r


func _spacer() -> Control:
	var s := Control.new()
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return s


func _disc(icon: String, col: Color, size_: float) -> Panel:
	var p := Panel.new()
	p.custom_minimum_size = Vector2(size_, size_)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var st := StyleBoxFlat.new()
	st.bg_color = col.darkened(0.55)
	st.set_corner_radius_all(int(size_ * 0.5))
	st.set_border_width_all(3)
	st.border_color = col
	st.anti_aliasing = true
	p.add_theme_stylebox_override("panel", st)
	var ic := Ui.icon_rect(icon, size_ * 0.6, col.lightened(0.4))
	ic.position = Vector2(size_ * 0.2, size_ * 0.2)
	p.add_child(ic)
	return p


## A hero's portrait in a rounded frame; the flat icon disc until it is rendered.
func _portrait(id: String, col: Color, size_: float) -> Control:
	var t := Portraits.tex(id)
	if t == null:
		return _disc(DB.HEROES[id]["icon"], col, size_)
	var p := Panel.new()
	p.custom_minimum_size = Vector2(size_, size_)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var st := StyleBoxFlat.new()
	st.bg_color = col.darkened(0.7)
	st.set_corner_radius_all(int(size_ * 0.5))
	st.set_border_width_all(3)
	st.border_color = col
	st.anti_aliasing = true
	p.add_theme_stylebox_override("panel", st)
	p.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	var tr := TextureRect.new()
	tr.texture = t
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(tr)
	return p


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
		v.add_child(Ui.label(("Lv %d" % int(h["level"])) if h["unlocked"] else "Locked", "Small", HORIZONTAL_ALIGNMENT_CENTER))
		t.add_child(v)
		var hid: String = id
		t.pressed.connect(func():
			_shown_hero = hid
			if Game.hero(hid)["unlocked"]:
				Game.set_hero(hid)
			lobby.show_hero(hid)
			refresh()
			s.rebuild())
		if Game.can_upgrade(id):
			var dot := ColorRect.new()
			dot.color = Color(0.4, 1.0, 0.5)
			dot.custom_minimum_size = Vector2(14, 14)
			dot.position = Vector2(8, 8)
			dot.size = Vector2(14, 14)
			t.add_child(dot)
		roster.add_child(t)
	b.add_child(roster)
	var id2 := _shown_hero
	var d2: Dictionary = DB.HEROES[id2]
	var h2 := Game.hero(id2)
	var st := Game.hero_stats(id2)
	# Identity.
	var head := VBoxContainer.new()
	head.add_theme_constant_override("separation", 2)
	var nm2 := Ui.label("%s — %s" % [d2["name"], d2["title"]], "Heading")
	nm2.add_theme_color_override("font_color", d2["color"].lightened(0.3))
	head.add_child(nm2)
	var bl := Ui.label(d2["blurb"], "Body")
	bl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	head.add_child(bl)
	b.add_child(head)
	# Stats.
	var card := _card()
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	for pair in [
		["Health", "%d" % int(st["hp"]), "heart-organ"], ["Damage", "%d" % int(st["dmg"]), "sword-wound"],
		["Attacks / sec", "%.2f" % st["rate"], "lightning-tear"], ["Move speed", "%.1f" % st["speed"], "running-shoe"],
		["Critical", "%d%%" % int(st["crit"] * 100.0), "bullseye"], ["Armor", "%d%%" % int(st["armor"] * 100.0), "checked-shield"],
	]:
		var r := _row([Ui.icon_rect(pair[2], 26, Color(0.85, 0.72, 0.48)), Ui.label(pair[0], "Small")], 8)
		r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var val := Ui.label(pair[1], "Value", HORIZONTAL_ALIGNMENT_RIGHT)
		val.add_theme_font_size_override("font_size", 24)
		val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.add_child(val)
		grid.add_child(r)
	card.add_child(grid)
	b.add_child(card)
	# Super.
	var sc := _card()
	var srow := _row([_disc({"slam": "meteor-impact", "whirlwind": "whirlwind", "volley": "arrow-cluster", "nova": "frozen-orb"}[d2["super"]], Color(1.0, 0.6, 0.25), 64)])
	var sv := VBoxContainer.new()
	sv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sv.add_theme_constant_override("separation", 0)
	sv.add_child(Ui.label("SUPER · " + str(d2["super_name"]).to_upper(), "Caption"))
	var sd := Ui.label(d2["super_desc"], "Body")
	sd.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sv.add_child(sd)
	srow.add_child(sv)
	sc.add_child(srow)
	b.add_child(sc)
	# Upgrade.
	if h2["unlocked"]:
		var uc := _card()
		var uv := VBoxContainer.new()
		var cost := Game.upgrade_cost(id2)
		if cost.is_empty():
			uv.add_child(Ui.label("Max level", "Heading", HORIZONTAL_ALIGNMENT_CENTER))
		else:
			var top := _row([Ui.label("Level %d → %d" % [int(h2["level"]), int(h2["level"]) + 1], "Heading"), _spacer(), Ui.label("+%d%% health and damage" % int(DB.LEVEL_POWER * 100.0), "Small")])
			uv.add_child(top)
			var pb := ProgressBar.new()
			pb.custom_minimum_size = Vector2(0, 30)
			pb.max_value = cost["shards"]
			pb.value = mini(int(h2["shards"]), cost["shards"])
			pb.show_percentage = false
			var pl := Ui.label("%d / %d shards" % [int(h2["shards"]), cost["shards"]], "HudLabel", HORIZONTAL_ALIGNMENT_CENTER)
			pl.add_theme_font_size_override("font_size", 19)
			pl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			pl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			pb.add_child(pl)
			uv.add_child(pb)
			var ub := Button.new()
			ub.theme_type_variation = "GoldButton"
			ub.text = "Upgrade · %d gold" % cost["gold"]
			ub.icon = Ui.icon("upgrade")
			ub.custom_minimum_size = Vector2(0, 84)
			ub.focus_mode = Control.FOCUS_NONE
			ub.disabled = not Game.can_upgrade(id2)
			ub.pressed.connect(func():
				if Game.upgrade(id2):
					Sfx.play("levelup", 0.0)
					lobby.show_hero(id2)
					s.rebuild())
			uv.add_child(ub)
		uc.add_child(uv)
		b.add_child(uc)
		# Gear: what this hero wears at a glance, and a way into the equipment screen.
		b.add_child(Ui.label("GEAR", "Caption"))
		var gear := _card()
		var gv := VBoxContainer.new()
		gv.add_theme_constant_override("separation", 12)
		var strip := HBoxContainer.new()
		strip.alignment = BoxContainer.ALIGNMENT_CENTER
		strip.add_theme_constant_override("separation", 12)
		for slot in DB.SLOTS:
			var worn := Game.equipped(id2, slot)
			var wc := GearDB.item_color(worn) if not worn.is_empty() else Color(0.4, 0.38, 0.36)
			var d_ := _disc(GearDB.icon(id2, slot), wc, 80)
			d_.modulate.a = 1.0 if not worn.is_empty() else 0.5
			strip.add_child(d_)
		gv.add_child(strip)
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
	else:
		var lc := _card()
		var ll := Ui.label("Locked — " + ("clear Veteran, or gather 20 shards from chests." if d2["unlock"] == "veteran" else "gather 20 shards from chests."), "Body")
		ll.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lc.add_child(ll)
		b.add_child(lc)


func _build_skills(s: Sheet) -> void:
	var b := s.body
	var levels := Game.skill_levels()
	var total := 0
	for k in levels:
		total += int(levels[k])
	var head := _card()
	var hr := _row([_disc("crossed-swords", Color(0.95, 0.75, 0.35), 84)], 18)
	var hv := VBoxContainer.new()
	hv.add_theme_constant_override("separation", 0)
	var cl := Ui.label("Combat level %d" % Game.combat_level(), "Heading")
	hv.add_child(cl)
	hv.add_child(Ui.label("Total level %d · Old School rules: 99 is the top" % total, "Small"))
	hr.add_child(hv)
	head.add_child(hr)
	b.add_child(head)
	var grid := GridContainer.new()
	grid.columns = 2
	for sk in DB.SKILLS:
		var xp := int(Game.data["skills"][sk])
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
		c.add_child(v)
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(c)
	b.add_child(grid)
	var note := Ui.label("Damage you deal trains your skills: melee heroes train Attack, Strength and Defence; the Ranger trains Ranged; the Mage trains Magic. Hitpoints always trains.", "Small")
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.add_child(note)


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
	var head := _row([Ui.label("Obtained %d / %d" % [got, DB.LOG_ORDER.size()], "Heading"), _spacer(), Ui.label("Boss kills: %d" % int(st["boss_kills"]), "Small")])
	b.add_child(head)
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
		var src: String = {"boss": "Gravemaw", "hexer": "Hexer Queen", "elite": "Champions", "nightmare": "Bosses (Nightmare)"}[ud["source"]]
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


func _build_settings(s: Sheet) -> void:
	var b := s.body
	b.add_child(SettingsBox.new())
	b.add_child(HSeparator.new())
	var cr := Ui.label("Art: KayKit by Kay Lousberg (CC0). Icons: game-icons.net (CC BY 3.0). Music: Kevin MacLeod (CC BY 4.0). Effects: Kenney, rubberduck and others (CC0). Full list in CREDITS.md.", "Small")
	cr.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.add_child(cr)
	var ota := get_node_or_null("/root/Ota")
	var ver := "Barrowfall v%s" % ProjectSettings.get_setting("application/config/version")
	if ota:
		ver += " · build %d · content %d" % [int(ota.get("baked_build")), int(ota.get("build"))]
	b.add_child(Ui.label(ver, "Small"))
