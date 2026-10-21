extends Control
## End of hunt: what you earned, what you levelled, what you found.

signal closed


func open(r: Dictionary) -> void:
	var win: bool = r["win"]
	var tier: Dictionary = DB.TIERS[int(r["tier"])]
	%Title.text = "Victory" if win else "Defeated"
	%Title.add_theme_color_override("font_color", Color(1.0, 0.82, 0.4) if win else Color(0.9, 0.3, 0.25))
	%Sub.text = "%s · %s · %s" % [DB.HEROES[r["hero"]]["name"], tier["name"], Ui.fmt_time(r["time"])]
	_count(_stat("Kills", "0", "skull-crossed-bones"), int(r["kills"]), "%d")
	_count(_stat("Champions", "0", "crowned-skull"), int(r["elites"]), "%d")
	_count(_stat("Level", "0", "upgrade"), int(r["level"]), "%d")
	_gold = _stat("Gold", "+0", "two-coins")
	_count(_gold, int(r["gold"]), "+%d")
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
	%Continue.disabled = true
	Ui.pop_in(%Panel, 0.0, 0.9)
	Ui.pop_in(%Title, 0.15, 1.4)
	_run_counts()


var _counters: Array = []
var _gold: Label
var _tween: Tween
var _counting := false
var _last_tick := 0.0


func _count(l: Label, to: int, fmt: String) -> void:
	_counters.append({"label": l, "to": to, "fmt": fmt})


## Numbers climb from zero over a short beat; tapping anywhere jumps to the end.
func _run_counts() -> void:
	_counting = true
	_tween = create_tween()
	_tween.tween_interval(0.35)
	_tween.tween_method(_apply_counts, 0.0, 1.0, 0.8)
	_tween.tween_callback(_finish_counts)


func _apply_counts(t: float) -> void:
	var k := 1.0 - pow(1.0 - t, 3.0)
	for c in _counters:
		(c["label"] as Label).text = c["fmt"] % int(round(float(c["to"]) * k))
	for sk in _skill_labels:
		var e: Dictionary = _skill_labels[sk]
		(e["xp"] as Label).text = "+%s xp" % Ui.fmt_num(int(round(float(e["gained"]) * k)))
	var now := Time.get_ticks_msec() / 1000.0
	if t < 1.0 and now - _last_tick > 0.07 and _gold and int(_gold.text.trim_prefix("+")) > 0:
		_last_tick = now
		Sfx.play("coin", -14.0, 1.0 + t * 0.4)


func _finish_counts() -> void:
	if not _counting:
		return
	_counting = false
	if _tween:
		_tween.kill()
	_apply_counts(1.0)
	for sk in _skill_labels:
		var e: Dictionary = _skill_labels[sk]
		if e["leveled"]:
			var l: Label = e["level"]
			l.text = "▲ %d" % Game.skill_level(sk)
			l.add_theme_color_override("font_color", Color(0.5, 1.0, 0.6))
			Ui.pop_in(l, 0.0, 1.6)
			Sfx.play("skill_level", -6.0)
	%Continue.disabled = false


func _input(e: InputEvent) -> void:
	if _counting and ((e is InputEventMouseButton and e.pressed) or (e is InputEventScreenTouch and e.pressed)):
		get_viewport().set_input_as_handled()
		_finish_counts()


var _rows: Array = []
var _skill_labels := {}


## One loot line; gear that beats what the hero wears gets an Equip button.
func _loot_row(it: Dictionary, hero_id: String) -> Control:
	var col := DB.rarity_color(it["rarity"])
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var icon_name: String = GearDB.item_icon(it) if it["slot"] in DB.SLOTS else DB.SLOT_ICON.get(it["slot"], "swap-bag")
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


func _stat(title: String, value: String, ic: String) -> Label:
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
	return val


func _skill_row(sk: String, gained: int, lv: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_child(Ui.icon_rect(DB.SKILL_ICON[sk], 30, Color(0.9, 0.78, 0.5)))
	var n := Ui.label(DB.SKILL_NAME[sk], "Body")
	n.custom_minimum_size = Vector2(130, 0)
	row.add_child(n)
	var xp := Ui.label("+0 xp", "Small")
	xp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(xp)
	var level := Game.skill_level(sk)
	var l := Ui.label("Lv %d" % (int(lv["from"]) if not lv.is_empty() else level), "Value")
	l.add_theme_font_size_override("font_size", 22)
	row.add_child(l)
	_skill_labels[sk] = {"xp": xp, "gained": gained, "level": l, "leveled": not lv.is_empty()}
	return row


func _note(text: String, col: Color, ic: String) -> void:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(Ui.icon_rect(ic, 34, col))
	var l := Ui.label(text, "Body")
	l.add_theme_color_override("font_color", col.lightened(0.2))
	row.add_child(l)
	%Notes.add_child(row)
