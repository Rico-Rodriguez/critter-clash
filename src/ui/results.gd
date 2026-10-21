extends Control
## End of hunt: what you earned, what you levelled, what you found.

signal closed


func open(r: Dictionary) -> void:
	var win: bool = r["win"]
	var tier: Dictionary = DB.TIERS[int(r["tier"])]
	%Title.text = "Victory" if win else "Defeated"
	%Title.add_theme_color_override("font_color", Color(1.0, 0.82, 0.4) if win else Color(0.9, 0.3, 0.25))
	%Sub.text = "%s · %s · %s" % [DB.HEROES[r["hero"]]["name"], tier["name"], Ui.fmt_time(r["time"])]
	_stat("Kills", str(r["kills"]), "skull-crossed-bones")
	_stat("Champions", str(r["elites"]), "crowned-skull")
	_stat("Level", str(r["level"]), "upgrade")
	_stat("Gold", "+%d" % int(r["gold"]), "two-coins")
	var s: Dictionary = r.get("summary", {})
	# Skills.
	var levels := {}
	for lv in s.get("levels", []):
		levels[lv["skill"]] = lv
	for sk in DB.SKILLS:
		var gained := int(r["xp"].get(sk, 0))
		if gained <= 0:
			continue
		%Skills.add_child(_skill_row(sk, gained, levels.get(sk, {})))
	# Loot.
	var items: Array = s.get("items", r["items"])
	if items.is_empty():
		%LootTitle.text = "No loot this time"
	for it in items:
		%Loot.add_child(_loot_row(it, str(r["hero"])))
	_refresh_upgrades()
	# Rewards that wait in camp.
	if win and str(r.get("chest", "")) != "":
		var c: Dictionary = DB.CHESTS[r["chest"]]
		_note("%s earned — open it in camp" % c["name"], c["color"], "locked-chest")
	var ut := int(s.get("unlocked_tier", -1))
	if ut >= 0:
		_note("%s difficulty unlocked" % DB.TIERS[ut]["name"], DB.TIERS[ut]["color"], "padlock-open")
	var uh := str(s.get("unlocked_hero", ""))
	if uh != "":
		_note("%s joins your band" % DB.HEROES[uh]["name"], DB.HEROES[uh]["color"], DB.HEROES[uh]["icon"])
	%Continue.pressed.connect(func():
		Sfx.play("ui_press", -2.0)
		closed.emit())
	Ui.pop_in(%Panel, 0.0, 0.9)
	Ui.pop_in(%Title, 0.15, 1.4)


var _rows: Array = []


## One loot line; gear that beats what the hero wears gets an Equip button.
func _loot_row(it: Dictionary, hero_id: String) -> Control:
	var col := DB.rarity_color(it["rarity"])
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var icon_name: String = DB.UNIQUES[it["unique"]]["icon"] if DB.UNIQUES.has(str(it.get("unique", ""))) else DB.SLOT_ICON.get(it["slot"], "swap-bag")
	row.add_child(Ui.icon_rect(icon_name, 30, col))
	var l := Ui.label(str(it["name"]), "Body")
	l.add_theme_color_override("font_color", col)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	var is_gear: bool = it["slot"] in DB.SLOTS and int(it.get("uid", 0)) > 0
	if is_gear:
		var up := Ui.label("▲", "Value")
		up.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5))
		row.add_child(up)
		var eq := Button.new()
		eq.text = "Equip"
		eq.custom_minimum_size = Vector2(130, 52)
		eq.focus_mode = Control.FOCUS_NONE
		eq.add_theme_font_size_override("font_size", 20)
		eq.pressed.connect(func():
			Game.equip(hero_id, int(it["uid"]))
			Sfx.play("gear_equip", -2.0)
			_refresh_upgrades())
		row.add_child(eq)
		_rows.append({"item": it, "hero": hero_id, "up": up, "btn": eq})
	return row


## Shows the arrow and button only on pieces that still beat the worn one.
func _refresh_upgrades() -> void:
	for e in _rows:
		var it: Dictionary = e["item"]
		var worn: bool = Game.owner_of(int(it["uid"])) == e["hero"]
		var better: bool = Game.is_better(it, e["hero"]) and not worn
		e["up"].visible = better
		var b: Button = e["btn"]
		b.visible = better or worn
		b.disabled = worn
		b.text = "Equipped ✓" if worn else "Equip"


func _stat(title: String, value: String, ic: String) -> void:
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 0)
	var top := HBoxContainer.new()
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_child(Ui.icon_rect(ic, 26, Color(0.9, 0.75, 0.45)))
	var val := Ui.label(value, "Value", HORIZONTAL_ALIGNMENT_CENTER)
	top.add_child(val)
	v.add_child(top)
	v.add_child(Ui.label(title.to_upper(), "Caption", HORIZONTAL_ALIGNMENT_CENTER))
	%Stats.add_child(v)


func _skill_row(sk: String, gained: int, lv: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_child(Ui.icon_rect(DB.SKILL_ICON[sk], 30, Color(0.9, 0.78, 0.5)))
	var n := Ui.label(DB.SKILL_NAME[sk], "Body")
	n.custom_minimum_size = Vector2(130, 0)
	row.add_child(n)
	var xp := Ui.label("+%s xp" % Ui.fmt_num(gained), "Small")
	xp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(xp)
	var level := Game.skill_level(sk)
	var l := Ui.label(("▲ %d" % level) if not lv.is_empty() else ("Lv %d" % level), "Value")
	l.add_theme_font_size_override("font_size", 22)
	if not lv.is_empty():
		l.add_theme_color_override("font_color", Color(0.5, 1.0, 0.6))
	row.add_child(l)
	return row


func _note(text: String, col: Color, ic: String) -> void:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(Ui.icon_rect(ic, 34, col))
	var l := Ui.label(text, "Body")
	l.add_theme_color_override("font_color", col.lightened(0.2))
	row.add_child(l)
	%Notes.add_child(row)
