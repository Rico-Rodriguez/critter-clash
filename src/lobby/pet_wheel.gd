extends Control
## The Breeding Wheel: every species on one ring (SDB.WHEEL), each hybrid in
## the gap between its two parents, and the mutations you have found in the
## hub. An owned species wears its rarity colour; a gold arc is a pair you own
## both halves of whose hybrid you haven't found yet. Tapping any disc emits
## `picked`. No class_name (see CLAUDE.md): preload it.

signal picked(id: String)

const SDB := preload("res://src/data/sidekick_db.gd")
const SKS := preload("res://src/autoload/sidekicks.gd")
const PetIcons := preload("res://src/ui/pet_icons.gd")
const FxUi := preload("res://src/ui/fx_ui.gd")

const GOLD := Color(0.91, 0.71, 0.35)
const DIM := Color(0.36, 0.33, 0.32)
const DISC_BG := Color(0.1, 0.085, 0.12)

## Ring and disc sizes as a share of the wheel's width.
const R_SPECIES := 0.385
const R_HYBRID := 0.262
const R_HUB := 0.165
const D_SPECIES := 0.14
const D_HYBRID := 0.1

var _own := {}
var _found: Array = []
var _muts: Array = []
## [id, Control, label or null, is hybrid]
var _discs: Array = []
var _hub: VBoxContainer
var _side := 0.0


func setup(d: Dictionary) -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_PASS
	_found = SKS.breeds_found(d)
	_muts = SKS.block(d)["found"]["mutations"]
	for k: String in SDB.WHEEL:
		_own[k] = SKS.owns_species(d, k)
	for i in SDB.WHEEL.size():
		var k: String = SDB.WHEEL[i]
		_add_disc(k, false)
		var h := _gap_hybrid(i)
		if h != "":
			_add_disc(h, true)
	_hub = _make_hub()
	add_child(_hub)
	resized.connect(_layout)


## The hybrid between ring slots i and i + 1, or "".
func _gap_hybrid(i: int) -> String:
	var n := SDB.WHEEL.size()
	return SDB.hybrid_for(str(SDB.WHEEL[i]), str(SDB.WHEEL[(i + 1) % n]))


## Found, ready (both parents owned), or out of reach.
func _hybrid_state(h: String) -> int:
	if _found.has(h):
		return 2
	var p: Array = SDB.BREEDS[h]["pair"]
	return 1 if bool(_own.get(p[0], false)) and bool(_own.get(p[1], false)) else 0


func _ring_color(id: String, hybrid: bool) -> Color:
	if hybrid:
		return [DIM, GOLD, Color(SDB.BREEDS[id]["color"])][_hybrid_state(id)]
	return SDB.GRADE_COLORS[int(SDB.SPECIES_RARITY.get(id, 0))] if bool(_own[id]) else DIM


func _add_disc(id: String, hybrid: bool) -> void:
	var lit := _hybrid_state(id) == 2 if hybrid else bool(_own[id])
	var ring := _ring_color(id, hybrid)
	var btn := Button.new()
	btn.focus_mode = Control.FOCUS_NONE
	var sb := StyleBoxFlat.new()
	sb.bg_color = DISC_BG
	sb.border_color = ring
	sb.set_border_width_all(2 if hybrid else 3)
	sb.set_corner_radius_all(200)
	if lit or (hybrid and _hybrid_state(id) == 1):
		sb.shadow_color = Color(ring, 0.35)
		sb.shadow_size = 8
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		btn.add_theme_stylebox_override(st, sb)
	if hybrid and not lit:
		var q := Ui.label("?", "Heading", HORIZONTAL_ALIGNMENT_CENTER)
		q.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		q.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		q.add_theme_color_override("font_color", ring if _hybrid_state(id) == 1 else Color(0.5, 0.47, 0.44))
		btn.add_child(q)
	else:
		# A species you don't have yet is its own shadow.
		var hold := Control.new()
		hold.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		hold.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if not lit:
			hold.modulate = Color(0, 0, 0, 0.6)
		var pic := PetIcons.rect(id, 1, 64)
		pic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		hold.add_child(pic)
		btn.add_child(hold)
	btn.pressed.connect(func():
		Sfx.play("ui_tap", -4.0)
		picked.emit(id))
	add_child(btn)
	var lbl: Label = null
	if not hybrid or lit:
		lbl = Ui.label(_short(id), "Tiny", HORIZONTAL_ALIGNMENT_CENTER)
		if hybrid:
			lbl.add_theme_color_override("font_color", ring)
		elif not lit:
			lbl.add_theme_color_override("font_color", Color(0.5, 0.47, 0.44))
		add_child(lbl)
	_discs.append([id, btn, lbl, hybrid])
	if hybrid and _hybrid_state(id) == 1:
		FxUi.pulse(btn, 1.08, 1.6)


## The name that fits under a disc: a species' last word, a hybrid's first.
func _short(id: String) -> String:
	var words := str(SDB.def(id)["name"]).split(" ")
	return words[0] if SDB.BREEDS.has(id) else words[words.size() - 1]


func _make_hub() -> VBoxContainer:
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 6)
	v.add_child(Ui.label("MUTATIONS", "Caption", HORIZONTAL_ALIGNMENT_CENTER))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	for m: String in SDB.GEN.MUTATION_ORDER:
		grid.add_child(mutation_dot(m, _muts.has(m), 30))
	v.add_child(grid)
	v.add_child(Ui.label("%d of %d found" % [_muts.size(), SDB.GEN.MUTATION_ORDER.size()], "Tiny", HORIZONTAL_ALIGNMENT_CENTER))
	return v


## A round swatch of a mutation's colour, hollow until found.
static func mutation_dot(m: String, got: bool, size_: float) -> Panel:
	var col := Color("#" + str(SDB.GEN.MUTATIONS[m]["color"]))
	var p := Panel.new()
	p.custom_minimum_size = Vector2(size_, size_)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = col if got else Color(0.08, 0.07, 0.1)
	sb.border_color = col if got else Color(col, 0.45)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(int(size_))
	if got:
		sb.shadow_color = Color(col, 0.45)
		sb.shadow_size = 4
	p.add_theme_stylebox_override("panel", sb)
	return p


func _angle(i: float) -> float:
	return -PI * 0.5 + i * TAU / float(SDB.WHEEL.size())


func _at(i: float, r: float) -> Vector2:
	return Vector2(_side, _side) * 0.5 + Vector2(cos(_angle(i)), sin(_angle(i))) * r * _side


func _layout() -> void:
	if is_equal_approx(size.x, _side):
		return
	_side = size.x
	custom_minimum_size.y = _side
	for e: Array in _discs:
		var hybrid: bool = e[3]
		var id: String = e[0]
		var p: Vector2
		var dsz: float
		if hybrid:
			p = _at(float(_gap_index(id)) + 0.5, R_HYBRID)
			dsz = D_HYBRID * _side
		else:
			p = _at(float(SDB.WHEEL.find(id)), R_SPECIES)
			dsz = D_SPECIES * _side
		var btn: Control = e[1]
		btn.size = Vector2(dsz, dsz)
		btn.position = p - btn.size * 0.5
		btn.pivot_offset = btn.size * 0.5
		var lbl: Label = e[2]
		if lbl != null:
			lbl.size = Vector2(160, 24)
			lbl.position = p + Vector2(-80, dsz * 0.5)
	var hw := R_HUB * 2.0 * _side
	_hub.size = Vector2(hw, hw)
	_hub.position = Vector2(_side, _side) * 0.5 - _hub.size * 0.5
	queue_redraw()


## Which gap a hybrid sits in (its parents' slots are neighbours).
func _gap_index(h: String) -> int:
	for i in SDB.WHEEL.size():
		if _gap_hybrid(i) == h:
			return i
	return -1


func _draw() -> void:
	if _side <= 0.0:
		return
	var c := Vector2(_side, _side) * 0.5
	draw_arc(c, R_SPECIES * _side, 0.0, TAU, 128, Color(1, 1, 1, 0.06), 2.0, true)
	draw_circle(c, R_HUB * _side, Color(0.06, 0.05, 0.08))
	draw_arc(c, R_HUB * _side, 0.0, TAU, 96, Color(0.29, 0.24, 0.16), 2.0, true)
	var n := SDB.WHEEL.size()
	for i in n:
		var h := _gap_hybrid(i)
		if h == "":
			continue
		var a := _at(float(i), R_SPECIES)
		var b := _at(float(i + 1), R_SPECIES)
		var mid := _at(float(i) + 0.5, R_HYBRID)
		# The curve passes through the hybrid's disc: its control point sits past it.
		var ctrl := mid * 2.0 - (a + b) * 0.5
		var pts := PackedVector2Array()
		for t in 25:
			var u := t / 24.0
			pts.append(a.lerp(ctrl, u).lerp(ctrl.lerp(b, u), u))
		var st := _hybrid_state(h)
		var col: Color = [Color(DIM, 0.7), GOLD, Color(SDB.BREEDS[h]["color"])][st]
		draw_polyline(pts, col, 3.0 if st > 0 else 2.0, true)
