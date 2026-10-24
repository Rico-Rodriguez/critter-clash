extends Control
## End of hunt: what you earned, what you levelled, what you found.

## `again`: straight into another hunt with the same setup.
const ItemIcons := preload("res://src/ui/item_icons.gd")

signal closed(again: bool)


func open(r: Dictionary) -> void:
	var win: bool = r["win"]
	var tier: Dictionary = DB.TIERS[int(r["tier"])]
	%Title.text = "Victory" if win else "Defeated"
	%Title.add_theme_color_override("font_color", Color(1.0, 0.82, 0.4) if win else Color(0.9, 0.3, 0.25))
	%Sub.text = "%s · %s · %s" % [DB.HEROES[r["hero"]]["name"], tier["name"], Ui.fmt_time(r["time"])]
	var long_road := str(r.get("mode", "horde")) == "trial"
	var descent := str(r.get("mode", "horde")) == "descent"
	var wild := str(r.get("mode", "horde")) == "wild"
	if long_road:
		%Sub.text = "The Long Road · " + %Sub.text
	elif descent:
		%Title.text = "Depth %d" % int(r["depth"])
		%Title.add_theme_color_override("font_color", Color(1.0, 0.82, 0.4))
		%Sub.text = "Endless Descent · " + %Sub.text
	elif str(r.get("mode", "horde")) == "rush":
		%Sub.text = "Boss Rush · " + %Sub.text
	elif str(r.get("mode", "horde")) == "rift":
		%Sub.text = "Rift · " + %Sub.text
	elif wild:
		%Sub.text = "The Wilderness · " + %Sub.text
		%Title.text = "Last band standing" if win else "Placed %d of %d" % [int(r["place"]), int(r["rivals"]) + 1]
	_count(_stat("Kills", "0", "skull-crossed-bones"), int(r["kills"]), "%d")
	if long_road:
		_count(_stat("Rooms", "0", "castle"), int(r.get("rooms_cleared", 0)), "%d / " + str(int(r.get("rooms", 0))))
	elif descent:
		_count(_stat("Depth", "0", "hourglass"), int(r["depth"]), "%d")
	elif wild:
		_count(_stat("Rivals", "0", "crossed-swords"), int(r["rivals"]) - (0 if win else maxi(int(r["place"]) - 1, 0)), "%d / " + str(int(r["rivals"])))
	else:
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
		%Loot.add_child(_loot_row(it, str(it.get("cls", r["hero"])) if it["slot"] in DB.SLOTS else str(r["hero"]), str(r["hero"])))
	_refresh_upgrades()
	# Rewards that wait in camp.
	if descent and bool(s.get("record", false)):
		_note("New deepest descent for the %s" % DB.HEROES[r["hero"]]["name"], Color(1.0, 0.85, 0.4), "trophy")
	if (win or descent or wild) and str(r.get("chest", "")) != "":
		_chest_card(str(r["chest"]))
	var ut := int(s.get("unlocked_tier", -1))
	if ut >= 0:
		_note("%s unlocked in %s" % [DB.TIERS[ut]["name"], DB.MODES[str(r.get("mode", "horde"))]["short"]], DB.TIERS[ut]["color"], "padlock-open")
	elif win or descent:
		# Say how many more wins open the next difficulty.
		var t_i := int(r.get("tier", 0))
		var md := "descent" if descent else str(r.get("mode", "horde"))
		var got := int(Game.data.get("tier_wins", {}).get("%s:%d" % [md, t_i], 0))
		if got > 0 and got < DB.TIER_WINS and t_i + 1 < DB.TIERS.size() and t_i >= Game.mode_tier_unlocked(md):
			_note("%d of %d wins to open %s" % [got, DB.TIER_WINS, DB.TIERS[t_i + 1]["name"]], DB.TIERS[t_i + 1]["color"], "padlock")
	var uh := str(s.get("unlocked_hero", ""))
	if uh != "":
		_note("%s joins your band" % DB.HEROES[uh]["name"], DB.HEROES[uh]["color"], DB.HEROES[uh]["icon"])
	var rn := int(s.get("renown", 0))
	if rn > 0:
		_road_bar(rn)
	if bool(s.get("first_win", false)):
		_note("First win of the day: double gold, better chest", Color(1.0, 0.85, 0.35), "sun")
	var ms: Dictionary = s.get("mastery", {})
	for title in ms.get("titles", []):
		_note("Mastery rank: %s %s" % [DB.HEROES[r["hero"]]["name"], title], Color(1.0, 0.8, 0.35), "round-star")
	var rt: Dictionary = s.get("rating", {})
	if not rt.is_empty():
		var d := int(rt["delta"])
		_note("Rating %s%d → %d%s" % ["+" if d >= 0 else "", d, int(rt["rating"]), (" · milestone +%d gold" % int(rt["milestone_gold"])) if int(rt["milestone_gold"]) > 0 else ""], Color(0.6, 0.9, 1.0) if d >= 0 else Color(0.85, 0.6, 0.55), "trophy")
	_sidekick_notes(s.get("sidekick", {}))
	if bool(s.get("rift_key", false)):
		_note("A rift key! Open it from the Expedition", Color(0.6, 0.85, 1.0), "crystal-shine")
	if int(s.get("achievements", 0)) > 0:
		_note("%d feat%s ready to claim in camp" % [int(s["achievements"]), "" if int(s["achievements"]) == 1 else "s"], Color(1.0, 0.82, 0.35), "trophy")
	var cl: Dictionary = s.get("clue", {})
	match str(cl.get("event", "")):
		"found":
			_note("You found a clue scroll (see the Log)", Color(1.0, 0.88, 0.5), "scroll-unfurled")
		"step":
			_note("Clue step done: %d of %d" % [int(cl["step"]), DB.CLUE_STEPS], Color(1.0, 0.88, 0.5), "scroll-unfurled")
		"casket":
			_note("Casket opened: %s" % ", ".join(cl["lines"]), Color(1.0, 0.85, 0.4), "open-treasure-chest")
	if str(r.get("omen", "")) != "":
		_note("Weekly omen: bonus paid", Color(0.8, 0.6, 1.0), "moon")
	if not win and not descent and not wild:
		_advice(r, tier)
		%Again.text = "Try again"
	%Continue.pressed.connect(func():
		Sfx.play("ui_press", -2.0)
		closed.emit(false))
	%Again.pressed.connect(func():
		Sfx.play("ui_press", 0.0)
		closed.emit(true))
	%Continue.disabled = true
	%Again.disabled = true
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
		(e["bar"] as ProgressBar).value = _level_frac(int(e["from_xp"]) + int(round(float(e["gained"]) * k))) * 100.0
	if _road:
		_road.value = lerpf(float(_road.get_meta("from")), float(_road.get_meta("to")), k) * 100.0
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
	%Again.disabled = false


func _input(e: InputEvent) -> void:
	if _counting and ((e is InputEventMouseButton and e.pressed) or (e is InputEventScreenTouch and e.pressed)):
		get_viewport().set_input_as_handled()
		_finish_counts()


var _rows: Array = []
var _skill_labels := {}


## Fraction of the way through the current skill level at a total xp.
func _level_frac(xp: int) -> float:
	var lv := DB.level_for_xp(xp)
	if lv >= 99:
		return 1.0
	var lo := DB.xp_for_level(lv)
	return float(xp - lo) / float(DB.xp_for_level(lv + 1) - lo)


var _road: ProgressBar


## The chest, big: the thing a win is for. Side by side with its name, so
## the loot list above keeps room on a short phone.
func _chest_card(kind: String) -> void:
	var c: Dictionary = DB.CHESTS[kind]
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	var ic := Ui.icon_rect("locked-chest", 72, c["color"])
	row.add_child(ic)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 0)
	var l := Ui.label(str(c["name"]), "Heading")
	l.add_theme_color_override("font_color", Color(c["color"]).lightened(0.2))
	v.add_child(l)
	v.add_child(Ui.label("Waiting in camp", "Caption"))
	row.add_child(v)
	%Notes.add_child(row)
	%Notes.move_child(row, 0)
	Ui.pop_in(ic, 0.9, 1.3)


## Trophies earned, as the Trophy Road bar filling toward its next step.
func _road_bar(gained: int) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.add_child(Ui.icon_rect("trophy", 30, Color(0.95, 0.8, 0.5)))
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 2)
	var steps := Game.road_claimable()
	var t := "Trophies +%d · %s" % [gained, "Trophy Road reward ready" if steps > 0 else "next: " + Game.road_reward_text(int(Game.data["road"]) + 1)]
	var l := Ui.label(t, "Body")
	l.add_theme_color_override("font_color", Color(0.95, 0.82, 0.55))
	v.add_child(l)
	_road = ProgressBar.new()
	_road.theme_type_variation = "XPBar"
	_road.show_percentage = false
	_road.custom_minimum_size = Vector2(0, 12)
	var before := Game.renown() - gained
	var from := Game.road_fill_for(before)
	var to := Game.road_fill_for(Game.renown())
	# Crossing a step: fill to the end; the reward waits in camp.
	if to < from:
		to = 1.0
	_road.set_meta("from", from)
	_road.set_meta("to", to)
	_road.value = from * 100.0
	v.add_child(_road)
	row.add_child(v)
	%Notes.add_child(row)


## One loot line. Gear that beats what its hero wears says whose it is and
## gets an Equip button; `played` is the hero of this hunt.
func _loot_row(it: Dictionary, hero_id: String, played := "") -> Control:
	var col := DB.gear_color(it)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	if it["slot"] in DB.SLOTS:
		row.add_child(ItemIcons.rect(it, 44, col))
	else:
		row.add_child(Ui.icon_rect(DB.SLOT_ICON.get(it["slot"], "swap-bag"), 30, col))
	var l := Ui.label(str(it["name"]), "Body")
	l.add_theme_color_override("font_color", col)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	var is_gear: bool = it["slot"] in DB.SLOTS and int(it.get("uid", 0)) > 0
	if is_gear and it.get("dupe", false):
		# A piece already owned: a copy toward its next level.
		var cp := Ui.label("+1 copy", "Value")
		cp.add_theme_color_override("font_color", Color(0.55, 0.75, 1.0))
		row.add_child(cp)
	elif is_gear:
		var up := Ui.label("▲" if hero_id == played else "▲ %s" % DB.HEROES[hero_id]["name"], "Value")
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
	# A thin bar toward the next level, so the grind is visible.
	var from_xp := Game.skill_xp(sk) - gained
	var bar := ProgressBar.new()
	bar.theme_type_variation = "XPBar"
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 8)
	bar.value = _level_frac(from_xp) * 100.0
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	col.add_child(row)
	col.add_child(bar)
	_skill_labels[sk] = {"xp": xp, "gained": gained, "level": l, "leveled": not lv.is_empty(), "bar": bar, "from_xp": from_xp}
	return col


## After a loss, the one thing most likely to win the next try, so the
## defeat screen points somewhere instead of just ending.
func _advice(r: Dictionary, tier: Dictionary) -> void:
	var id := str(r["hero"])
	var col := Color(0.75, 0.88, 1.0)
	for e in _rows:
		if e["hero"] == id and Game.is_better(e["item"], id) and Game.owner_of(int(e["item"]["uid"])) != id:
			_note("Equip the upgrades you found above", col, "breastplate")
			return
	if Game.can_rub_lamp(id):
		_note("Rub an XP lamp in Skills: skills are the %s's health and damage" % DB.HEROES[id]["name"], col, "upgrade")
		return
	var pw := Game.power_score(id)
	var rec := int(tier["power"])
	if pw < rec:
		_note("Power %s of %s suggested: better gear closes the gap" % [Ui.fmt_num(pw), Ui.fmt_num(rec)], col, "breastplate")
		return
	_note(TIPS[int(r["kills"]) % TIPS.size()], col, "round-star")


const TIPS := [
	"Dash through an attack, not away from it: a perfect dodge hits harder",
	"Stand still to aim: planted feet deal 25% more",
	"Champions drop better loot, but kill the crowd around them first",
	"Keep moving: circle the horde instead of backing into a corner",
]


func _note(text: String, col: Color, ic: String) -> void:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(Ui.icon_rect(ic, 34, col))
	var l := Ui.label(text, "Body")
	l.add_theme_color_override("font_color", col.lightened(0.2))
	row.add_child(l)
	%Notes.add_child(row)


## Sidekick news: bond gained (and levels), evolution, eggs, hatches, unlocks.
func _sidekick_notes(sk: Dictionary) -> void:
	if sk.is_empty():
		return
	const SDB := preload("res://src/data/sidekick_db.gd")
	var id := str(sk.get("id", ""))
	if id != "":
		var d: Dictionary = SDB.ROSTER[id]
		var col: Color = d["color"]
		if bool(sk.get("evolved", false)):
			_note("%s evolves into the %s!" % [d["name"], d.get("evolved_name", d["name"])], col, str(d["icon"]))
		elif int(sk["bond_to"]) > int(sk["bond_from"]):
			_note("%s reached Bond %d" % [d["name"], int(sk["bond_to"])], col, str(d["icon"]))
		else:
			_note("%s · +%d bond kills" % [d["name"], int(sk["kills"])], col, str(d["icon"]))
	var egg := str(sk.get("egg", ""))
	if egg != "":
		_note("You found an %s! Kills warm it until it hatches" % SDB.EGGS[egg]["name"], Color(1.0, 0.85, 0.55), "egg-clutch")
	for h in sk.get("hatched", []):
		_note("The egg hatched: %s joins you" % SDB.ROSTER[str(h)]["name"], Color(SDB.ROSTER[str(h)]["color"]), str(SDB.ROSTER[str(h)]["icon"]))
	for u in sk.get("unlocked", []):
		_note("New sidekick: %s (see Sidekicks)" % SDB.ROSTER[str(u)]["name"], Color(SDB.ROSTER[str(u)]["color"]), str(SDB.ROSTER[str(u)]["icon"]))
