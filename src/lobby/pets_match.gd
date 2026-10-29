extends RefCounted
## The Pets tab's Breed page, the Matchmaker: two parent slots, what the pair
## can hatch and how likely each is (the hybrid pity included), the mutation
## chance with its pity, and the partners sorted by what they would make.
## `ui._breed_a` / `ui._breed_b` hold the pair; `ui` is the LobbyUI.

const SKS := preload("res://src/autoload/sidekicks.gd")
const SKDB := preload("res://src/data/sidekick_db.gd")
const Care := preload("res://src/core/pet_care.gd")
const PetIcons := preload("res://src/ui/pet_icons.gd")
const Codex := preload("res://src/lobby/pets_codex.gd")
const PetWheel := preload("res://src/lobby/pet_wheel.gd")
const FxUi := preload("res://src/ui/fx_ui.gd")

const GOLD := Color(1.0, 0.82, 0.4)
const MUT := Color(0.77, 0.55, 1.0)


static func build(ui, s: Sheet) -> void:
	var b := s.body
	var now := int(Time.get_unix_time_from_system())
	var a := str(ui._breed_a)
	var bb := str(ui._breed_b)
	if a != "" and not SKS.is_owned(Game.data, a):
		a = ""
	if bb != "" and not SKS.is_owned(Game.data, bb):
		bb = ""
	ui._breed_a = a
	ui._breed_b = bb
	if str(ui._breed_news) != "":
		var news := Ui.label(str(ui._breed_news), "Heading", HORIZONTAL_ALIGNMENT_CENTER)
		news.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.add_child(news)
		ui._breed_news = ""
	var slots := HBoxContainer.new()
	slots.add_theme_constant_override("separation", 8)
	slots.add_child(_slot(ui, s, a, true, now))
	var plus := Ui.label("+", "Title", HORIZONTAL_ALIGNMENT_CENTER)
	plus.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slots.add_child(plus)
	slots.add_child(_slot(ui, s, bb, false, now))
	b.add_child(slots)
	if a != "" and bb != "":
		_outcomes(b, a, bb)
		b.add_child(_mutation_card(a, bb))
	else:
		var tip := Ui.label("Pick two pets at Bond %d or more. They lay a Nest Egg that always hatches: one parent's breed, or the hybrid the pair makes." % SKDB.BREED_BOND, "Small")
		tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.add_child(tip)
	var why := SKS.breed_block(Game.data, a, bb, now) if a != "" and bb != "" else "Pick two parents"
	var go := Button.new()
	go.theme_type_variation = &"GoldButton"
	go.text = "LAY NEST EGG · %s GOLD" % Ui.fmt_num(SKDB.BREED_GOLD)
	go.focus_mode = Control.FOCUS_NONE
	go.custom_minimum_size = Vector2(0, 76)
	go.disabled = why != ""
	go.pressed.connect(func():
		var e := SKS.breed(Game.data, str(ui._breed_a), str(ui._breed_b), int(Time.get_unix_time_from_system()), randi())
		if e.is_empty():
			return
		ui._breed_a = ""
		ui._breed_b = ""
		ui._breed_news = "A Nest Egg is warming in your hatchery!"
		Game.bounty_note("bred")
		Sfx.play("rare_chime", 0.0)
		Game.save()
		ui._refresh_camp_sidekick()
		s.rebuild())
	b.add_child(go)
	var nest: Dictionary = SKDB.EGGS["nest"]
	var foot := Ui.label(why if why != "" else "Both rest %s · the egg hatches in %dh or %d kills" % [Care.hours_text(Care.rest_secs()), int(nest["secs"]) / 3600, int(nest["kills"])], "Small", HORIZONTAL_ALIGNMENT_CENTER)
	foot.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if why != "":
		foot.add_theme_color_override("font_color", Color(0.95, 0.6, 0.5))
	b.add_child(foot)
	_partners(ui, s, a, bb, now)


## One parent slot: the pet with its bond, rest and any mutation it carries, or
## an invitation to pick one. Tapping a filled slot empties it.
static func _slot(ui, s: Sheet, id: String, first: bool, now: int) -> Control:
	var btn := Button.new()
	btn.theme_type_variation = &"Card"
	btn.focus_mode = Control.FOCUS_NONE
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size = Vector2(0, 236)
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 10)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 2)
	if id == "":
		var q := Ui.icon_rect("egg-clutch", 64, Color(1, 1, 1, 0.22))
		q.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(q)
		var l := Ui.label("Pick %s parent" % ("a first" if first else "a second"), "Small", HORIZONTAL_ALIGNMENT_CENTER)
		v.add_child(l)
		btn.disabled = true
	else:
		btn.add_theme_stylebox_override("normal", _gold_frame())
		var ic := PetIcons.rect(id, SKS.stage(Game.data, id), 120)
		ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(ic)
		var nm := Ui.label(ui._pet_name(id), "Body", HORIZONTAL_ALIGNMENT_CENTER)
		nm.clip_text = true
		v.add_child(nm)
		v.add_child(Ui.label(_status(id, now), "Tiny", HORIZONTAL_ALIGNMENT_CENTER))
		var m := str(SKS.genes_of(Game.data, id).get("mutation", ""))
		if m != "":
			var mu: Dictionary = SKDB.GEN.MUTATIONS[m]
			var ml := Ui.label("Carries %s" % mu["name"], "Tiny", HORIZONTAL_ALIGNMENT_CENTER)
			ml.add_theme_color_override("font_color", Color("#" + str(mu["color"])))
			v.add_child(ml)
		btn.pressed.connect(func():
			Sfx.play("ui_tap", -4.0)
			if first:
				ui._breed_a = ui._breed_b
			ui._breed_b = ""
			s.rebuild())
	for ch in v.get_children():
		(ch as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(v)
	return btn


static func _gold_frame() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.1, 0.14, 0.92)
	sb.border_color = Color(0.91, 0.71, 0.35)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(12)
	sb.shadow_color = Color(0.91, 0.71, 0.35, 0.25)
	sb.shadow_size = 6
	return sb


## "Bond 4 · ready", "Resting 3h 12m", "Bond 1 · needs 3".
static func _status(id: String, now: int) -> String:
	var lv := SKS.bond(Game.data, id)
	var rest := SKS.resting(Game.data, id, now)
	if rest > 0:
		return "Resting %s" % _dur(rest)
	if lv < SKDB.BREED_BOND:
		return "Bond %d · needs %d" % [lv, SKDB.BREED_BOND]
	return "Bond %d · ready" % lv


static func _dur(secs: int) -> String:
	if secs >= 3600:
		return "%dh %02dm" % [secs / 3600, (secs % 3600) / 60]
	return "%dm" % maxi(secs / 60, 1)


## What can hatch: each outcome with its chance, the hybrid in the middle and
## larger, and one bar split by the odds.
static func _outcomes(b: VBoxContainer, a: String, bb: String) -> void:
	var odds := SKS.litter_odds(Game.data, a, bb)
	var hy := SKDB.hybrid_for(SKDB.species(a), SKDB.species(bb))
	var found := SKS.breeds_found(Game.data)
	var left := SKS.hybrid_tries_left(Game.data, a, bb)
	var note := ""
	if hy != "" and not found.has(hy):
		note = "The hybrid is certain this litter" if left == 1 else "The hybrid is certain within %d litters" % left
	b.add_child(Ui.label("WHAT CAN HATCH", "Caption"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	# Parent, hybrid, parent: the prize sits in the middle.
	var order: Array = odds.duplicate()
	if hy != "" and order.size() == 3:
		order = [odds[0], odds[2], odds[1]] if str(odds[1][0]) != hy else odds
	for o: Array in order:
		row.add_child(_outcome_tile(str(o[0]), float(o[1]), str(o[0]) == hy, found.has(str(o[0]))))
	b.add_child(row)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 2)
	bar.custom_minimum_size = Vector2(0, 12)
	for o: Array in order:
		if float(o[1]) <= 0.0:
			continue
		var seg := ColorRect.new()
		seg.color = Color(SKDB.def(str(o[0]))["color"])
		seg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		seg.size_flags_stretch_ratio = float(o[1])
		bar.add_child(seg)
	b.add_child(bar)
	if note != "":
		var nl := Ui.label(note, "Small", HORIZONTAL_ALIGNMENT_CENTER)
		nl.add_theme_color_override("font_color", GOLD)
		b.add_child(nl)


static func _outcome_tile(k: String, p: float, hybrid: bool, got: bool) -> Control:
	var c := PanelContainer.new()
	var col := Color(SKDB.def(k)["color"])
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(col, 0.16) if hybrid else Color(0.12, 0.1, 0.14, 0.9)
	sb.border_color = Color(col, 0.9) if hybrid else Color(1, 1, 1, 0.08)
	sb.set_border_width_all(2 if hybrid else 1)
	sb.set_corner_radius_all(12)
	sb.content_margin_top = 6
	sb.content_margin_bottom = 8
	if hybrid:
		sb.shadow_color = Color(col, 0.3)
		sb.shadow_size = 10
	c.add_theme_stylebox_override("panel", sb)
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.size_flags_stretch_ratio = 1.3 if hybrid else 1.0
	c.size_flags_vertical = Control.SIZE_SHRINK_END
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.add_child(Codex.portrait(k, 132 if hybrid else 92, got or not hybrid))
	var pl := Ui.label("%s%%" % _pct(p), "Value" if not hybrid else "Heading", HORIZONTAL_ALIGNMENT_CENTER)
	if hybrid:
		pl.add_theme_color_override("font_color", col.lightened(0.2))
	v.add_child(pl)
	var nm := Ui.label(str(SKDB.def(k)["name"]) if got or not hybrid else "New hybrid", "Tiny", HORIZONTAL_ALIGNMENT_CENTER)
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(nm)
	c.add_child(v)
	return c


## "32.5", "35", "100".
static func _pct(p: float) -> String:
	var x := snappedf(p * 100.0, 0.1)
	return str(int(x)) if is_equal_approx(x, round(x)) else "%.1f" % x


## The mutation chance for this litter, the pity bar toward a sure one, and
## what the parents carry.
static func _mutation_card(a: String, bb: String) -> Control:
	var c := PanelContainer.new()
	c.theme_type_variation = &"Card"
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	var p := SKS.litter_mutation_chance(Game.data, a, bb)
	var big := Ui.label("%s%%" % _pct(p), "Heading")
	big.add_theme_color_override("font_color", MUT)
	var cap := Ui.label("MUTATION CHANCE", "Caption")
	cap.add_theme_color_override("font_color", MUT)
	var row := HBoxContainer.new()
	row.add_child(cap)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(sp)
	row.add_child(big)
	v.add_child(row)
	var dry := int(SKS.block(Game.data)["dry"].get("mutation", 0))
	var bar := ProgressBar.new()
	bar.theme_type_variation = &"SoulBar"
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 12)
	bar.value = clampf(float(dry) / float(SKDB.MUTATION_PITY), 0.0, 1.0) * 100.0
	v.add_child(bar)
	var lines := ["%d hatches since your last mutation · certain at %d." % [dry, SKDB.MUTATION_PITY]]
	var held := [a, bb].map(func(x): return str(SKS.genes_of(Game.data, str(x)).get("mutation", ""))).filter(func(m): return m != "")
	if not held.is_empty():
		lines.append("A parent passes on its own mutation %d%% of the time." % int(SKDB.GEN.MUTATION_INHERIT * 100.0))
	var l := Ui.label(" ".join(PackedStringArray(lines)), "Small")
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(l)
	var dots := HBoxContainer.new()
	dots.add_theme_constant_override("separation", 8)
	dots.alignment = BoxContainer.ALIGNMENT_CENTER
	var found: Array = SKS.block(Game.data)["found"]["mutations"]
	for m: String in SKDB.GEN.MUTATION_ORDER:
		dots.add_child(PetWheel.mutation_dot(m, found.has(m), 22))
	v.add_child(dots)
	c.add_child(v)
	return c


## The pets to pick from. With a first parent picked, partners that make a
## hybrid come first (with what they make), then the rest; species you don't
## own yet that would make one are listed with where to get them.
static func _partners(ui, s: Sheet, a: String, bb: String, now: int) -> void:
	var b := s.body
	var mine: Array = (SKDB.ORDER + SKS.bred_ids(Game.data)).filter(func(i): return SKS.is_owned(Game.data, str(i)))
	if a == "":
		b.add_child(Ui.label("PICK A PET", "Caption"))
		for id: String in mine:
			b.add_child(_mate_row(ui, s, id, "", now))
		return
	var sa := SKDB.species(a)
	var hy_rows := []
	var rest_rows := []
	for id: String in mine:
		if id == a:
			continue
		if SKDB.hybrid_for(sa, SKDB.species(id)) != "":
			hy_rows.append(id)
		else:
			rest_rows.append(id)
	var missing := []
	for h: String in SKDB.BREED_ORDER:
		var p: Array = SKDB.BREEDS[h]["pair"]
		if p.has(sa):
			var other := str(p[1] if p[0] == sa else p[0])
			if not SKS.owns_species(Game.data, other):
				missing.append(other)
	b.add_child(ui._row([Ui.label("HYBRID PARTNERS", "Caption"), ui._spacer(), Ui.label("for %s" % ui._pet_name(a), "Small")], 8))
	if hy_rows.is_empty() and missing.is_empty():
		b.add_child(Ui.label("No hybrid has %s blood." % SKDB.def(sa)["name"], "Small"))
	for id: String in hy_rows:
		b.add_child(_mate_row(ui, s, id, sa, now))
	for sp: String in missing:
		b.add_child(_missing_row(sa, sp))
	b.add_child(ui._row([Ui.label("OTHER PARTNERS", "Caption"), ui._spacer(), Ui.label("a parent's breed", "Small")], 8))
	for id: String in rest_rows:
		b.add_child(_mate_row(ui, s, id, sa, now))


static func _mate_row(ui, s: Sheet, id: String, with_sp: String, now: int) -> Control:
	var ok := SKS.resting(Game.data, id, now) == 0 and SKS.bond(Game.data, id) >= SKDB.BREED_BOND
	var sel := id == str(ui._breed_a) or id == str(ui._breed_b)
	var btn := Button.new()
	btn.theme_type_variation = &"Card"
	btn.focus_mode = Control.FOCUS_NONE
	btn.custom_minimum_size = Vector2(0, 96)
	if sel:
		btn.add_theme_stylebox_override("normal", _gold_frame())
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 12)
	row.add_child(PetIcons.rect(id, SKS.stage(Game.data, id), 76))
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 0)
	var nm := Ui.label(("✓ " if sel else "") + str(ui._pet_name(id)), "Body")
	nm.clip_text = true
	v.add_child(nm)
	var st := Ui.label(_status(id, now), "Small")
	if not ok:
		st.add_theme_color_override("font_color", Color(0.85, 0.6, 0.45))
	v.add_child(st)
	row.add_child(v)
	if with_sp != "":
		var h := SKDB.hybrid_for(with_sp, SKDB.species(id))
		if h != "":
			var mk := Ui.label("makes", "Small")
			mk.add_theme_color_override("font_color", GOLD)
			mk.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(mk)
			row.add_child(Codex.portrait(h, 64, SKS.breeds_found(Game.data).has(h)))
	for ch in row.get_children():
		(ch as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(row)
	if not ok and not sel:
		btn.modulate = Color(1, 1, 1, 0.6)
	btn.pressed.connect(func():
		Sfx.play("ui_tap", -4.0)
		if id == str(ui._breed_a):
			ui._breed_a = ui._breed_b
			ui._breed_b = ""
		elif id == str(ui._breed_b):
			ui._breed_b = ""
		elif str(ui._breed_a) == "":
			ui._breed_a = id
		else:
			ui._breed_b = id
		s.rebuild())
	return btn


## A partner you don't have yet: its shadow, where to get it, and the hybrid.
static func _missing_row(sa: String, sp: String) -> Control:
	var c := PanelContainer.new()
	c.theme_type_variation = &"Card"
	c.modulate = Color(1, 1, 1, 0.7)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.add_child(Codex.portrait(sp, 76, false))
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(Ui.label(str(SKDB.def(sp)["name"]), "Body"))
	var how := Ui.label("Not yours yet · %s" % SKDB.def(sp)["how"], "Small")
	how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(how)
	row.add_child(v)
	var h := SKDB.hybrid_for(sa, sp)
	row.add_child(Codex.portrait(h, 64, SKS.breeds_found(Game.data).has(h)))
	c.add_child(row)
	return c
