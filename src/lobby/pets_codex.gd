extends RefCounted
## The Pets tab's Wheel page: the Breeding Wheel (pet_wheel.gd), a hint for
## the next hybrid within reach, the bestiary of every breed with its six
## mutation pips, and one breed's page (its bloodlines and mutations). `ui` is
## the LobbyUI; `ui._pet_page` is the breed whose page is open ("" for none).

const SKS := preload("res://src/autoload/sidekicks.gd")
const SKDB := preload("res://src/data/sidekick_db.gd")
const PetIcons := preload("res://src/ui/pet_icons.gd")
const PetWheel := preload("res://src/lobby/pet_wheel.gd")
const FxUi := preload("res://src/ui/fx_ui.gd")

const BREED_SEGMENT := 2


static func build(ui, s: Sheet) -> void:
	if str(ui._pet_page) != "" and SKDB.exists(str(ui._pet_page)):
		build_breed_page(ui, s, str(ui._pet_page))
		return
	ui._pet_page = ""
	var b := s.body
	var all: Array = SKDB.ORDER + SKDB.BREED_ORDER
	var found := SKS.breeds_found(Game.data)
	b.add_child(ui._row([Ui.label("BREEDING WHEEL", "Caption"), ui._spacer(), Ui.label("%d / %d found" % [found.size(), all.size()], "Small")], 8))
	var wheel: Control = PetWheel.new()
	wheel.setup(Game.data)
	wheel.picked.connect(func(id: String):
		ui._pet_page = id
		s.rebuild())
	b.add_child(wheel)
	var how := Ui.label("Neighbours on the ring breed the hybrid between them. Gold means you own both parents.", "Small", HORIZONTAL_ALIGNMENT_CENTER)
	how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.add_child(how)
	var hint := _next_hybrid()
	if not hint.is_empty():
		b.add_child(_pair_card(ui, s, str(hint[0]), str(hint[1]), str(hint[2])))
	b.add_child(Ui.label("BESTIARY", "Caption"))
	var held := SKS.breed_mutations(Game.data)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	for k: String in all:
		grid.add_child(_dex_tile(ui, s, k, found.has(k), held.get(k, [])))
	b.add_child(grid)
	FxUi.deal_in(grid, 0.02)
	var f: Dictionary = SKS.block(Game.data)["found"]
	var traits := Ui.label("Traits found: elements %d / %d · patterns %d / %d · personalities %d / %d · glow %s" % [
		(f["elements"] as Array).size(), SKDB.ELEMENTS.size(), (f["patterns"] as Array).filter(func(p): return p != "plain").size(), SKDB.PATTERNS.size() - 1,
		(f["personalities"] as Array).size(), SKDB.PERSONALITIES.size(), "yes" if bool(f["glow"]) else "not yet"], "Small")
	traits.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.add_child(traits)


## The first unfound hybrid whose parents you own: [species a, species b, hybrid], or [].
static func _next_hybrid() -> Array:
	var found := SKS.breeds_found(Game.data)
	for h: String in SKDB.BREED_ORDER:
		var p: Array = SKDB.BREEDS[h]["pair"]
		if not found.has(h) and SKS.owns_species(Game.data, str(p[0])) and SKS.owns_species(Game.data, str(p[1])):
			return [p[0], p[1], h]
	return []


## "Drake + Bonelet can breed": a card that sets the pair up in the Matchmaker.
static func _pair_card(ui, s: Sheet, a: String, b: String, h: String) -> Control:
	var c: PanelContainer = ui._card()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.add_child(PetIcons.rect(a, 1, 64))
	row.add_child(PetIcons.rect(b, 1, 64))
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 0)
	v.add_child(Ui.label("%s + %s" % [_short(a), _short(b)], "Body"))
	var left := SKS.hybrid_tries_left(Game.data, a, b)
	var sub := Ui.label("An unfound hybrid · certain within %d litter%s" % [left, "" if left == 1 else "s"], "Small")
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(sub)
	row.add_child(v)
	var go := Button.new()
	go.theme_type_variation = &"GoldButton"
	go.text = "PAIR"
	go.focus_mode = Control.FOCUS_NONE
	go.custom_minimum_size = Vector2(120, 64)
	go.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	go.pressed.connect(func(): pair_up(ui, s, a, b))
	row.add_child(go)
	c.add_child(row)
	return c


## Opens the Matchmaker with your best pet of each species picked.
static func pair_up(ui, s: Sheet, a: String, b: String) -> void:
	Sfx.play("ui_tap", -4.0)
	ui._breed_a = SKS.best_of_species(Game.data, a)
	ui._breed_b = SKS.best_of_species(Game.data, b)
	ui._pet_page = ""
	s.show_segment(BREED_SEGMENT)


static func _short(id: String) -> String:
	var w := str(SKDB.def(id)["name"]).split(" ")
	return w[w.size() - 1] if not SKDB.BREEDS.has(id) else str(SKDB.def(id)["name"])


## A portrait, or the pet's shadow when it isn't found yet.
static func portrait(id: String, size_: float, lit: bool) -> Control:
	var hold := Control.new()
	hold.custom_minimum_size = Vector2(size_, size_)
	hold.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	hold.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pic := PetIcons.rect(id, 1, size_)
	pic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hold.add_child(pic)
	if not lit:
		hold.modulate = Color(0, 0, 0, 0.6)
	return hold


## One bestiary card: the breed, its name (a hybrid's stays hidden until
## found, its parents never do), and a pip per mutation you hold on it.
static func _dex_tile(ui, s: Sheet, k: String, got: bool, held: Array) -> Control:
	var hybrid := SKDB.BREEDS.has(k)
	var btn := Button.new()
	btn.theme_type_variation = &"Card"
	btn.focus_mode = Control.FOCUS_NONE
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size = Vector2(0, 236 if hybrid else 206)
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 8)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 2)
	v.add_child(portrait(k, 110, got))
	if hybrid:
		var pr := HBoxContainer.new()
		pr.alignment = BoxContainer.ALIGNMENT_CENTER
		pr.add_theme_constant_override("separation", -8)
		pr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for p in SKDB.BREEDS[k]["pair"]:
			pr.add_child(PetIcons.rect(str(p), 1, 34))
		v.add_child(pr)
	var nm := Ui.label(str(SKDB.def(k)["name"]) if got or not hybrid else "???", "Tiny", HORIZONTAL_ALIGNMENT_CENTER)
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nm.add_theme_color_override("font_color", Color(1.0, 0.88, 0.5) if got else Color(0.55, 0.52, 0.5))
	v.add_child(nm)
	var pips := HBoxContainer.new()
	pips.alignment = BoxContainer.ALIGNMENT_CENTER
	pips.add_theme_constant_override("separation", 4)
	pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for m: String in SKDB.GEN.MUTATION_ORDER:
		pips.add_child(PetWheel.mutation_dot(m, held.has(m), 13))
	v.add_child(pips)
	btn.add_child(v)
	btn.pressed.connect(func():
		Sfx.play("ui_tap", -4.0)
		ui._pet_page = k
		s.rebuild())
	return btn


# --- One breed's page ------------------------------------------------------------

static func build_breed_page(ui, s: Sheet, k: String) -> void:
	var b := s.body
	var d: Dictionary = SKDB.def(k)
	var hybrid := SKDB.BREEDS.has(k)
	var got := SKS.breeds_found(Game.data).has(k)
	var back := Button.new()
	back.theme_type_variation = &"Ghost"
	back.text = "‹ Wheel"
	back.focus_mode = Control.FOCUS_NONE
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back.pressed.connect(func():
		Sfx.play("ui_back", -4.0)
		ui._pet_page = ""
		s.rebuild())
	b.add_child(back)
	var rar := SKDB.rarity(k)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 16)
	head.add_child(portrait(k, 200, got))
	var hv := VBoxContainer.new()
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hv.alignment = BoxContainer.ALIGNMENT_CENTER
	hv.add_theme_constant_override("separation", 4)
	var tag := Ui.label(("HYBRID · " if hybrid else "") + SKDB.GRADES[rar].to_upper(), "Caption")
	tag.add_theme_color_override("font_color", SKDB.GRADE_COLORS[rar])
	hv.add_child(tag)
	var title := Ui.label(str(d["name"]) if got or not hybrid else "Unknown hybrid", "Heading")
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hv.add_child(title)
	hv.add_child(Ui.label("%s · %s" % [d["element"], d["ability"]["name"]], "Small"))
	var how := Ui.label(str(d["how"]), "Small")
	how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hv.add_child(how)
	var n := SKS.count_of_species(Game.data, k)
	if n > 0:
		var own := Ui.label("You have %d" % n, "Small")
		own.add_theme_color_override("font_color", Color(1.0, 0.88, 0.5))
		hv.add_child(own)
	head.add_child(hv)
	b.add_child(head)
	if got:
		var desc := Ui.label(str(d["desc"]), "Small")
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.add_child(desc)
	var lines := []
	if hybrid:
		lines.append(SKDB.BREEDS[k]["pair"])
	else:
		for h: String in SKDB.BREED_ORDER:
			var p: Array = SKDB.BREEDS[h]["pair"]
			if p.has(k):
				lines.append([k, p[1] if p[0] == k else p[0]])
	b.add_child(ui._row([Ui.label("BLOODLINES", "Caption"), ui._spacer(), Ui.label("%d hybrid%s" % [lines.size(), "" if lines.size() == 1 else "s"], "Small")], 8))
	for pair: Array in lines:
		b.add_child(_bloodline(ui, s, str(pair[0]), str(pair[1])))
	var held: Array = SKS.breed_mutations(Game.data).get(k, [])
	b.add_child(ui._row([Ui.label("MUTATIONS", "Caption"), ui._spacer(), Ui.label("%d / %d on this breed" % [held.size(), SKDB.GEN.MUTATION_ORDER.size()], "Small")], 8))
	var strip := GridContainer.new()
	strip.columns = 3
	strip.add_theme_constant_override("h_separation", 8)
	strip.add_theme_constant_override("v_separation", 8)
	for m: String in SKDB.GEN.MUTATION_ORDER:
		strip.add_child(_mutation_tile(k, m, SKS.mutated_one(Game.data, k, m)))
	b.add_child(strip)
	var chance := SKS.mutation_chance(Game.data, "nest")
	var mnote := Ui.label("Any litter can hatch a mutation: %.1f%% on your next Nest Egg, and certain after %d hatches without one." % [chance * 100.0, SKDB.MUTATION_PITY], "Small")
	mnote.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.add_child(mnote)


## "Drake + Bonelet → Cinderbone Drake", with what's missing; tapping it sets
## the pair up when you own both.
static func _bloodline(ui, s: Sheet, a: String, b: String) -> Control:
	var h := SKDB.hybrid_for(a, b)
	var found := SKS.breeds_found(Game.data).has(h)
	var oa := SKS.owns_species(Game.data, a)
	var ob := SKS.owns_species(Game.data, b)
	var btn := Button.new()
	btn.theme_type_variation = &"Card"
	btn.focus_mode = Control.FOCUS_NONE
	btn.custom_minimum_size = Vector2(0, 104)
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 6)
	row.add_child(portrait(a, 76, oa))
	var plus := Ui.label("+", "Heading")
	plus.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(plus)
	row.add_child(portrait(b, 76, ob))
	var arrow := Ui.label("→", "Heading")
	arrow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(arrow)
	row.add_child(portrait(h, 76, found))
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var nm := Ui.label(str(SKDB.BREEDS[h]["name"]) if found else "Unknown hybrid", "Body")
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if found:
		nm.add_theme_color_override("font_color", Color(SKDB.BREEDS[h]["color"]))
	v.add_child(nm)
	var need := [a, b].filter(func(x): return not SKS.owns_species(Game.data, str(x)))
	var st := "Found · %d%% from this pair" % int(SKDB.BREED_HYBRID * 100.0) if found else ("You own both · tap to pair" if need.is_empty() else "Needs a %s" % SKDB.def(str(need[0]))["name"])
	var sl := Ui.label(st, "Small")
	sl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if need.is_empty() and not found:
		sl.add_theme_color_override("font_color", Color(1.0, 0.82, 0.4))
	v.add_child(sl)
	row.add_child(v)
	btn.add_child(row)
	btn.disabled = not need.is_empty()
	btn.pressed.connect(func(): pair_up(ui, s, a, b))
	return btn


## One mutation slot on a breed's page: your mutated pet, or the breed's shadow.
static func _mutation_tile(k: String, m: String, pet: String) -> Control:
	var mu: Dictionary = SKDB.GEN.MUTATIONS[m]
	var col := Color("#" + str(mu["color"]))
	var c := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(col, 0.14) if pet != "" else Color(0.08, 0.07, 0.1, 0.85)
	sb.border_color = Color(col, 0.7) if pet != "" else Color(col, 0.25)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(12)
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	c.add_theme_stylebox_override("panel", sb)
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.add_child(portrait(pet if pet != "" else k, 84, pet != ""))
	var l := Ui.label(str(mu["name"]), "Tiny", HORIZONTAL_ALIGNMENT_CENTER)
	l.add_theme_color_override("font_color", col if pet != "" else Color(col, 0.5))
	v.add_child(l)
	c.add_child(v)
	return c
