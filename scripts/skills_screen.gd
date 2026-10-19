class_name SkillsScreen
extends ScreenBase

## Skills splits into three tabs. Combat is per hero: GearDB's six combat skills
## for the hero shown by the local, view-only switcher (it never changes the
## save's featured hero). Each row is a forged plaque with the name, level and
## an XP bar; combat skills fill from hunts. Gathering is account-wide: the
## three skills in Catalog.SKILLS, with the levels the save already banks in
## data["skills"]. Materials is the bag: every gathered resource and boss
## material the account holds, with its count and its price, sold for coins.


## OSRS combat level for a hero's skill levels, keyed by GearDB.SKILL_KEYS.
## This game has no Prayer skill, so callers pass none (the term is zero); the
## optional "prayer" key feeds the canonical base term so the helper lines up
## with the OSRS 1/113/126 vectors.
static func combat_level(levels: Dictionary) -> int:
	var defence := float(levels.get("defence", 1))
	var hitpoints := float(levels.get("hitpoints", 1))
	var attack := float(levels.get("attack", 1))
	var strength := float(levels.get("strength", 1))
	var ranged := float(levels.get("ranged", 1))
	var magic := float(levels.get("magic", 1))
	var prayer := float(levels.get("prayer", 1))
	var base: float = 0.25 * (defence + hitpoints + floorf(prayer / 2.0))
	var melee: float = 0.325 * (attack + strength)
	var range: float = 0.325 * floorf(1.5 * ranged)
	var mage: float = 0.325 * floorf(1.5 * magic)
	return int(floorf(base + maxf(melee, maxf(range, mage))))


## Total combat level for a hero: the six GearDB skill levels summed. This is
## the "Total" half of the header readout ("Total 42 · Combat 7").
static func total_level(hero: String) -> int:
	var total := 0
	for k in GearDB.SKILL_KEYS:
		total += GearDB.level(hero, k)
	return total


## The account's total gathering level: the three gathering skills summed.
## Gathering is account-wide, so this total is the same for every hero.
static func gathering_total() -> int:
	var total := 0
	for entry in Catalog.SKILLS:
		total += SaveGame.gathering_level(str(entry["id"]))
	return total


## The next gear gate for a skill, e.g. "Defence 20: Blackened steel helm,
## chest, boots", or "All gear unlocked" when nothing is gated above the
## current level. Empty when no gear gates on the skill at all, so the row
## can omit the line.
static func next_unlock(hero: String, skill: String) -> String:
	var level := GearDB.level(hero, skill)
	var best := 0
	var slots := {}
	var tier := -1
	var gated := false
	for id in GearDB.all_items(hero):
		var req: Dictionary = GearDB.requirements(id)
		if not req.has(skill):
			continue
		gated = true
		var need := int(req[skill])
		if need <= level:
			continue
		if best == 0 or need < best:
			best = need
			tier = int(GearDB.item(id)["tier"])
			slots = {str(GearDB.item(id)["slot"]): true}
		elif need == best:
			slots[str(GearDB.item(id)["slot"])] = true
	if best == 0:
		return "All gear unlocked" if gated else ""
	var words := PackedStringArray()
	for key in GearDB.SLOT_KEYS:
		if slots.has(key):
			words.append(GearDB.SLOT_NAMES[GearDB.SLOT_KEYS.find(key)].to_lower())
	var tier_name := GearDB.TIER_NAMES[tier].to_lower()
	tier_name = tier_name.substr(0, 1).to_upper() + tier_name.substr(1)
	return "%s %d: %s %s" % [GearDB.SKILL_NAMES[GearDB.SKILL_KEYS.find(skill)], best, tier_name, ", ".join(words)]


## Thousands separators for XP readouts ("13,034,431").
static func _fmt_num(value: int) -> String:
	var digits := str(absi(value))
	var out := ""
	var count := 0
	for i in range(digits.length() - 1, -1, -1):
		out = digits[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "," + out
	return ("-" if value < 0 else "") + out


var _tab_buttons := {}
var _content: VBoxContainer
var _summary: Label
## The currency bar, held so a sale can re-read the coin pill.
var _header: HBoxContainer
## The row of bulk actions under the tab bar. Only the Materials tab uses it.
var _actions: HBoxContainer
## The list the tabs fill, so a rebuilt tab can let touches through again.
var _scroll: ScrollContainer
## The hero the page is showing. Empty follows the featured hero; the switcher
## only moves this local view and never writes the save (TASK).
var _view_hero := ""


## The hero whose combat skills are on screen.
func view_id() -> String:
	if _view_hero != "" and SaveGame.data["heroes"].has(_view_hero):
		return _view_hero
	return SaveGame.featured_id()


## View-only pick: records which hero the page shows and returns the new id.
## Unlocked heroes only. Never touches SaveGame.data["featured"].
func set_view(id: String) -> String:
	if SaveGame.data["heroes"].has(id) and bool(SaveGame.hero(id)["unlocked"]):
		_view_hero = id
	return view_id()


func build() -> void:
	show_nav = true
	nav_tab = ""
	var box := column()
	_header = header_with_back("home")
	box.add_child(_header)
	box.add_child(h1("Skills"))
	_summary = UiKit.label("", 24, Color("e6d8bc"), "x", 4)
	_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_summary)
	box.add_child(_tab_bar())
	# The bulk action of the current tab sits under the tab bar and stays
	# there while the list below it scrolls.
	_actions = HBoxContainer.new()
	_actions.alignment = BoxContainer.ALIGNMENT_CENTER
	_actions.add_theme_constant_override("separation", 14)
	box.add_child(_actions)
	# The combat list can run past the screen once the unlock lines are in, so
	# it scrolls; the tab bar and back chip stay put.
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	_scroll = scroll
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 16)
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_content)
	_show_tab("combat")


func _tab_bar() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	# Three tabs share the portrait width, so each caption shrinks to fit
	# (UiKit.Btn) instead of running off the safe area.
	for entry in [["combat", "Combat"], ["gathering", "Gathering"], ["materials", "Materials"]]:
		var key := str(entry[0])
		var button := UiKit.secondary(str(entry[1]), 210, 88)
		button.toggle_mode = true
		button.pressed.connect(func() -> void: _show_tab(key))
		_tab_buttons[key] = button
		row.add_child(button)
	return row


func _show_tab(tab: String) -> void:
	for key in _tab_buttons:
		var button: Button = _tab_buttons[key]
		button.set_pressed_no_signal(key == tab)
		button.modulate = Color(1.08, 1.02, 0.9) if key == tab else Color(0.6, 0.6, 0.64)
	if _summary != null:
		if tab == "gathering":
			_summary.text = "Gathering total %d" % gathering_total()
		elif tab == "materials":
			_summary.text = "Bag · %d items · %d coins" % [SaveGame.bag_count(), SaveGame.bag_value()]
		else:
			var hero := view_id()
			_summary.text = "Total %d · Combat %d" % [total_level(hero), combat_level(GearDB.skills(hero))]
	if _content == null:
		return
	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()
	for child in _actions.get_children():
		_actions.remove_child(child)
		child.queue_free()
	match tab:
		"combat":
			_combat_tab()
		"materials":
			_materials_tab()
		_:
			_gathering_tab()
	# The rows were built after the screen was ready, so they still swallow
	# touches: let them pass, or the list cannot be dragged.
	pass_through(_scroll)


## Show a tab by id ("combat", "gathering", "materials"). The capture tool
## uses it to shoot the Materials page.
func show_tab(tab: String) -> void:
	_show_tab(tab)


func _combat_tab() -> void:
	var hero := view_id()
	var info := Catalog.critter(hero)
	_content.add_child(_hero_header(hero, info))
	_content.add_child(body("Levels 1–99; combat XP comes from hunts."))
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 16)
	_content.add_child(list)
	for i in GearDB.SKILL_KEYS.size():
		list.add_child(CombatRow.new(hero, GearDB.SKILL_KEYS[i], GearDB.SKILL_NAMES[i]))


## The per-hero block: combat-level crest beside the hero's name and role,
## then the switcher. The switcher is view-only, so the Skills tab may show any
## unlocked hero without stealing the featured slot Home and the hunts use.
func _hero_header(hero: String, info: Dictionary) -> Control:
	var panel := PanelContainer.new()
	var empty := StyleBoxEmpty.new()
	for side in ["left", "right", "top", "bottom"]:
		empty.set("content_margin_" + side, 18)
	panel.add_theme_stylebox_override("panel", empty)
	var metal := UiKit.rarity_metal(UiKit.hero_rarity(hero))
	var fr := UiKit.Frame.new("panel", "leather", {"metal_hi": metal[0], "metal_lo": metal[1]})
	fr.margin = 14.0
	panel.add_child(fr)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	panel.add_child(col)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	col.add_child(row)
	var crest := Crest.new()
	crest.value = combat_level(GearDB.skills(hero))
	crest.caption = "COMBAT"
	crest.custom_minimum_size = Vector2(140, 164)
	crest.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(crest)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 6)
	row.add_child(v)
	v.add_child(UiKit.label(str(info.get("name", hero)).to_upper(), 34, Color("fff1d6"), "x", 6))
	v.add_child(UiKit.label(Catalog.role_name(str(info.get("role", ""))).to_upper(), 22, UiKit.GOLD.lightened(0.15), "x", 4))
	var line := UiKit.label("COMBAT LEVEL %d" % crest.value, 24, Color("e6d8bc"), "b", 4)
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(line)
	col.add_child(_hero_switcher(hero))
	return panel


## One chip per unlocked hero: the shown one is the gold primary (sunk and
## lit), the rest are secondary steel. Tapping is view-only and redraws the
## tab; the save's featured hero is untouched. A FlowContainer wraps the chips
## on a narrow viewport so nothing runs off the safe area.
func _hero_switcher(current: String) -> Control:
	var row := HFlowContainer.new()
	row.alignment = FlowContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("h_separation", 10)
	row.add_theme_constant_override("v_separation", 10)
	for id in Catalog.playable_ids():
		if not bool(SaveGame.hero(str(id))["unlocked"]):
			continue
		var name := str(Catalog.critter(str(id)).get("name", id)).to_upper()
		var on := str(id) == current
		var button := UiKit.button(name, 150, 82) if on else UiKit.secondary(name, 150, 82)
		button.toggle_mode = true
		button.set_pressed_no_signal(on)
		button.pressed.connect(func() -> void: _pick_hero(str(id)))
		row.add_child(button)
	return row


func _pick_hero(id: String) -> void:
	if id == view_id():
		return
	set_view(id)
	AudioDirector.sfx("card_pick")
	AudioDirector.haptic("medium")
	_show_tab("combat")


## The gathering tab: the account's three gathering skills, with the level the
## save already holds and the XP toward the next one. Nothing here writes: the
## XP is banked by the sim (RunSim) and read back from the save.
func _gathering_tab() -> void:
	_content.add_child(_gathering_header())
	_content.add_child(body("Levels 1–99; gathering XP comes from working nodes."))
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 16)
	_content.add_child(list)
	for id in GatheringDB.skill_ids():
		list.add_child(GatheringRow.new(id, GatheringDB.skill_name(id)))


## The account-wide block: the total gathering level on a crest beside the
## three skill names. Gathering belongs to the account, not to a hero, so
## there is no hero switcher here.
func _gathering_header() -> Control:
	var panel := PanelContainer.new()
	var empty := StyleBoxEmpty.new()
	for side in ["left", "right", "top", "bottom"]:
		empty.set("content_margin_" + side, 18)
	panel.add_theme_stylebox_override("panel", empty)
	var fr := UiKit.Frame.new("panel", "leather")
	fr.margin = 14.0
	panel.add_child(fr)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	panel.add_child(col)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	col.add_child(row)
	var crest := Crest.new()
	crest.value = gathering_total()
	crest.caption = "GATHERING"
	crest.custom_minimum_size = Vector2(140, 164)
	crest.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(crest)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 6)
	row.add_child(v)
	v.add_child(UiKit.label("ACCOUNT-WIDE", 34, Color("fff1d6"), "x", 6))
	var line := UiKit.label("Woodcutting, Fishing and Mining are shared by every hero.", 22, UiKit.GOLD.lightened(0.15), "x", 4)
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(line)
	var total := UiKit.label("GATHERING LEVEL %d" % crest.value, 24, Color("e6d8bc"), "b", 4)
	total.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(total)
	return panel


# --- Materials ---------------------------------------------------------------

## The bag: every material the world has given the account, boss drops and
## gathered resources alike, with the count of each and what it sells for. A
## row sells its whole stack; the action under the tab bar sells the lot.
func _materials_tab() -> void:
	_sell_all_action()
	var boss: Array = []
	var gathered: Array = []
	var other: Array = []
	for id in _bag_ids():
		if SaveGame.material_count(id) <= 0:
			continue
		match MaterialDB.kind_of(id):
			"boss":
				boss.append(id)
			"gathered":
				gathered.append(id)
			_:
				other.append(id)
	if boss.is_empty() and gathered.is_empty() and other.is_empty():
		_content.add_child(_empty_bag())
		return
	_content.add_child(body("Everything the wilds have given you. Sell a stack for coins, or empty the bag in one go."))
	if not boss.is_empty():
		_content.add_child(_group_label("FROM THE HUNT"))
		for id in boss:
			_content.add_child(_material_row(str(id)))
	if not gathered.is_empty():
		_content.add_child(_group_label("GATHERED"))
		for id in gathered:
			_content.add_child(_material_row(str(id)))
	if not other.is_empty():
		_content.add_child(_group_label("OTHER"))
		for id in other:
			_content.add_child(_material_row(str(id)))


## Every material the account holds, in a stable order: the known ones (the
## boss spoils, then the gathered resources) and after them anything else the
## save happens to hold, so a material nobody has priced yet is still shown
## rather than sitting in the bag unseen.
func _bag_ids() -> Array:
	var out: Array = []
	var known := {}
	for id in MaterialDB.all_ids():
		known[id] = true
		out.append(id)
	for key in SaveGame.data["materials"].keys():
		var id := str(key)
		if not known.has(id):
			out.append(id)
	return out


## A group head inside the bag list.
func _group_label(text: String) -> Control:
	var l := UiKit.label(text, 22, UiKit.GOLD, "x", 3)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


## One material of the bag: its icon, its name, how many there are and what
## the stack is worth. The button sells the stack.
func _material_row(id: String) -> Control:
	var row := MaterialRow.new()
	row.setup(id, SaveGame.material_count(id), MaterialDB.price(id))
	row.sell.connect(_sell_one)
	return row


## An empty bag: the wilds have given nothing yet.
func _empty_bag() -> Control:
	var l := body("The bag is empty. Work a node in a biome, or bring a boss down, and its spoils land here.")
	l.add_theme_color_override("font_color", UiKit.MUTED)
	return l


## Sells one stack of a material and rebuilds the list around the new count.
func _sell_one(id: String) -> void:
	var coins := SaveGame.sell_material(id)
	if coins <= 0:
		AudioDirector.sfx("ui_error")
		return
	AudioDirector.sfx("coin")
	AudioDirector.haptic("light")
	toast("Sold %s for %d coins" % [MaterialDB.name_of(id), coins])
	_sync_purse()
	_show_tab("materials")


## The bulk action under the tab bar: the whole bag, for coins. It asks once,
## because a sale cannot be undone.
func _sell_all_action() -> void:
	var value := SaveGame.bag_value()
	var button := UiKit.button("SELL ALL", 300, 88)
	# Set before the button enters the tree so its forged skin builds in the
	# grey tone and the caption dims with it (UiKit.Btn reads disabled in _ready).
	button.disabled = value <= 0
	button.pressed.connect(_confirm_sell_all)
	_actions.add_child(button)
	_actions.add_child(UiKit.label("The bag is worth %d coins" % value, 20, UiKit.MUTED, "b", 3))


## Asks before the bulk sale: the sheet names what goes and what it pays.
func _confirm_sell_all() -> void:
	var value := SaveGame.bag_value()
	if value <= 0:
		return
	var sheet := ConfirmSheet.new()
	sheet.total = value
	sheet.items = SaveGame.bag_count()
	sheet.confirmed.connect(func() -> void:
		sheet.queue_free()
		var coins := SaveGame.sell_all_materials()
		AudioDirector.sfx("coin")
		AudioDirector.haptic("medium")
		toast("Sold the bag for %d coins" % coins)
		_sync_purse()
		_show_tab("materials"))
	sheet.cancelled.connect(func() -> void: sheet.queue_free())
	add_child(sheet)


## The coin pill in the currency bar counts up on its own, but a sale changes
## the wallet, so it is re-read here.
func _sync_purse() -> void:
	if _header == null:
		return
	for child in _header.get_children():
		if child is UiKit.Pill and (child as UiKit.Pill).kind == "coin":
			(child as UiKit.Pill).set_amount(str(int(SaveGame.data["coins"])))


## A forged shield crest with a level struck into it.
class Crest extends Control:
	var value := 0
	var caption := "TOTAL"

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _shield(inset: float) -> PackedVector2Array:
		var w := size.x
		var h := size.y
		var pts := PackedVector2Array()
		pts.append(Vector2(inset, inset + 10))
		pts.append(Vector2(w * 0.5, inset))
		pts.append(Vector2(w - inset, inset + 10))
		pts.append(Vector2(w - inset, h * 0.55))
		for i in range(1, 12):
			var t := float(i) / 12.0
			pts.append(Vector2(lerpf(w - inset, w * 0.5, t), lerpf(h * 0.55, h - inset, sin(t * PI * 0.5))))
		pts.append(Vector2(w * 0.5, h - inset))
		for i in range(1, 12):
			var t := 1.0 - float(i) / 12.0
			pts.append(Vector2(lerpf(inset, w * 0.5, t), lerpf(h * 0.55, h - inset, sin(t * PI * 0.5))))
		pts.append(Vector2(inset, h * 0.55))
		return pts

	func _draw() -> void:
		var shadow := _shield(2)
		for i in shadow.size():
			shadow[i] += Vector2(0, 5)
		draw_colored_polygon(shadow, Color(0, 0, 0, 0.55))
		draw_colored_polygon(_shield(2), Color("6e5126"))
		draw_colored_polygon(_shield(6), Color("d9b46a"))
		draw_colored_polygon(_shield(10), Color("4a361a"))
		draw_colored_polygon(_shield(14), Color("2c1610"))
		var face := _shield(20)
		var cols := PackedColorArray()
		for p in face:
			cols.append(Color("5a1c14").lerp(Color("24100c"), clampf(p.y / size.y, 0.0, 1.0)))
		draw_polygon(face, cols)
		var line := _shield(14)
		line.append(line[0])
		draw_polyline(line, Color(1, 0.86, 0.6, 0.25), 1.5, true)
		var c := Vector2(size.x * 0.5, size.y * 0.47)
		for a in [-0.5, 0.5]:
			var d := Vector2.from_angle(PI * 0.5 + a * 1.1)
			draw_line(c - d * 46.0, c - d * 56.0, Color("d9b46a"), 3.0, true)
		var font := UiKit.font_n
		var txt := str(value)
		var fs := 58 if txt.length() < 3 else 46
		var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var base := c + Vector2(-tw * 0.5, fs * 0.36)
		draw_string_outline(font, base + Vector2(0, 3), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 8, Color(0, 0, 0, 0.7))
		draw_string(font, base, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("f6dc9a"))
		var sub := caption
		var sw := font.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		draw_string(font, Vector2(size.x * 0.5 - sw * 0.5, size.y * 0.72), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("c9a25a"))


## A combat skill row for the shown hero: GearDB level, a bar to the next level
## and the next gear gate that level will open.
class CombatRow extends PanelContainer:
	var hero_id := ""
	var skill_id := ""
	var skill_name := ""

	func _init(hero: String, id: String, title: String) -> void:
		hero_id = hero
		skill_id = id
		skill_name = title

	func _ready() -> void:
		custom_minimum_size = Vector2(0, 150)
		var empty := StyleBoxEmpty.new()
		for side in ["left", "right", "top", "bottom"]:
			empty.set("content_margin_" + side, 22)
		add_theme_stylebox_override("panel", empty)
		var metal := UiKit.rarity_metal("common")
		var fr := UiKit.Frame.new("plaque", "leather", {"metal_hi": metal[0], "metal_lo": metal[1]})
		fr.margin = 14.0
		add_child(fr)
		var maxed := GearDB.level(hero_id, skill_id) >= GearDB.MAX_LEVEL
		var xp := GearDB.xp(hero_id, skill_id)
		var level := GearDB.level(hero_id, skill_id)
		var floor_xp := GearDB.xp_for_level(level)
		var next_xp := GearDB.xp_for_level(mini(GearDB.MAX_LEVEL, level + 1))
		var span := maxi(next_xp - floor_xp, 1)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 18)
		add_child(row)
		var med := Glyph.new()
		med.kind = skill_id
		med.custom_minimum_size = Vector2(104, 104)
		med.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(med)
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_theme_constant_override("separation", 4)
		row.add_child(col)
		var top := HBoxContainer.new()
		top.add_child(UiKit.label(skill_name.to_upper(), 32, Color("fff1d6"), "x", 6))
		var gap := Control.new()
		gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top.add_child(gap)
		top.add_child(UiKit.label("LV %d" % level, 28, UiKit.GOLD.lightened(0.15), "x", 6))
		col.add_child(top)
		var bar := XpBar.new()
		bar.ratio = 1.0 if maxed else clampf(float(xp - floor_xp) / float(span), 0.0, 1.0)
		bar.custom_minimum_size = Vector2(0, 26)
		col.add_child(bar)
		var foot := HBoxContainer.new()
		var into := span if maxed else clampi(xp - floor_xp, 0, span)
		foot.add_child(UiKit.label("%s / %s XP" % [SkillsScreen._fmt_num(into), SkillsScreen._fmt_num(span)], 21, Color("e6d8bc"), "b", 4))
		var gap2 := Control.new()
		gap2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		foot.add_child(gap2)
		foot.add_child(UiKit.label("MAX" if maxed else "TO LV %d" % (level + 1), 20, Color("c8b8a0"), "x", 4))
		col.add_child(foot)
		var unlock := SkillsScreen.next_unlock(hero_id, skill_id)
		if unlock != "":
			var all_open := unlock == "All gear unlocked"
			var line := UiKit.label("NEXT UNLOCK · " + unlock, 20, Color("9fe08a") if all_open else Color("d8c8aa"), "b", 4)
			line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			col.add_child(line)


## A gathering skill row for the account: the level the save banks in
## data["skills"], a bar to the next level and the XP banked so far. The
## levels come off the Old School curve in Catalog, the same one the combat
## rows use, so a gathering level is worth the same as a combat one.
class GatheringRow extends PanelContainer:
	var skill_id := ""
	var skill_name := ""

	func _init(id: String, title: String) -> void:
		skill_id = id
		skill_name = title

	func _ready() -> void:
		custom_minimum_size = Vector2(0, 150)
		var empty := StyleBoxEmpty.new()
		for side in ["left", "right", "top", "bottom"]:
			empty.set("content_margin_" + side, 22)
		add_theme_stylebox_override("panel", empty)
		var metal := UiKit.rarity_metal("common")
		var fr := UiKit.Frame.new("plaque", "leather", {"metal_hi": metal[0], "metal_lo": metal[1]})
		fr.margin = 14.0
		add_child(fr)
		var xp := SaveGame.gathering_xp(skill_id)
		var level := Catalog.skill_level(xp)
		var maxed := level >= Catalog.MAX_SKILL_LEVEL
		var floor_xp := Catalog.skill_xp_to_level(level)
		var next_xp := Catalog.skill_xp_to_level(mini(Catalog.MAX_SKILL_LEVEL, level + 1))
		var span := maxi(next_xp - floor_xp, 1)
		if maxed:
			# The curve ends here, so the whole of it is the span: the row
			# reads "13,034,431 / 13,034,431 XP" and MAX, not a 1 XP step.
			floor_xp = 0
			span = maxi(Catalog.skill_xp_to_level(Catalog.MAX_SKILL_LEVEL), 1)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 18)
		add_child(row)
		var med := Glyph.new()
		med.kind = skill_id
		med.custom_minimum_size = Vector2(104, 104)
		med.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(med)
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_theme_constant_override("separation", 4)
		row.add_child(col)
		var top := HBoxContainer.new()
		top.add_child(UiKit.label(skill_name.to_upper(), 32, Color("fff1d6"), "x", 6))
		var gap := Control.new()
		gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top.add_child(gap)
		top.add_child(UiKit.label("LV %d" % level, 28, UiKit.GOLD.lightened(0.15), "x", 6))
		col.add_child(top)
		var bar := XpBar.new()
		bar.ratio = 1.0 if maxed else clampf(float(xp - floor_xp) / float(span), 0.0, 1.0)
		bar.custom_minimum_size = Vector2(0, 26)
		col.add_child(bar)
		var foot := HBoxContainer.new()
		var into := span if maxed else clampi(xp - floor_xp, 0, span)
		foot.add_child(UiKit.label("%s / %s XP" % [SkillsScreen._fmt_num(into), SkillsScreen._fmt_num(span)], 21, Color("e6d8bc"), "b", 4))
		var gap2 := Control.new()
		gap2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		foot.add_child(gap2)
		foot.add_child(UiKit.label("MAX" if maxed else "TO LV %d" % (level + 1), 20, Color("c8b8a0"), "x", 4))
		col.add_child(foot)
		var banked := UiKit.label("%s XP BANKED" % SkillsScreen._fmt_num(xp), 20, Color("d8c8aa"), "b", 4)
		col.add_child(banked)

## One material of the bag: its icon, its name, how many of it there are and
## what the stack is worth. The button sells the whole stack.
class MaterialRow extends PanelContainer:
	signal sell(id: String)
	var id := ""
	var count := 0
	var price := 0

	func setup(material_id: String, have: int, unit: int) -> void:
		id = material_id
		count = have
		price = unit

	func _ready() -> void:
		custom_minimum_size = Vector2(0, 132)
		var empty := StyleBoxEmpty.new()
		for side in ["left", "right", "top", "bottom"]:
			empty.set("content_margin_" + side, 16)
		add_theme_stylebox_override("panel", empty)
		var fr := UiKit.Frame.new("plaque", "leather")
		fr.margin = 14.0
		add_child(fr)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		add_child(row)
		var icon := MaterialIcon.new()
		icon.id = id
		icon.custom_minimum_size = Vector2(92, 92)
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(icon)
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		col.add_theme_constant_override("separation", 4)
		row.add_child(col)
		col.add_child(UiKit.label(MaterialDB.name_of(id).to_upper(), 26, Color("fff1d6"), "x", 5))
		if price > 0:
			col.add_child(UiKit.label("×%d · %d coins each" % [count, price], 20, UiKit.MUTED, "b", 3))
		else:
			col.add_child(UiKit.label("×%d · no price yet" % count, 20, UiKit.MUTED, "b", 3))
		var right := VBoxContainer.new()
		right.alignment = BoxContainer.ALIGNMENT_CENTER
		right.add_theme_constant_override("separation", 6)
		row.add_child(right)
		if price > 0:
			right.add_child(UiKit.label("%d COINS" % (count * price), 21, UiKit.GOLD.lightened(0.15), "x", 3))
			var button := UiKit.button("SELL", 180, 88)
			button.pressed.connect(func() -> void: sell.emit(id))
			right.add_child(button)


## A material's picture: the baked prop when the drop has one, and a carved
## mark of its skill when it does not (the gathered resources have no art
## yet).
class MaterialIcon extends Control:
	var id := ""
	var tex: Texture2D

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var path := MaterialDB.icon_path(id)
		if path != "":
			# Cached: canvas draw commands keep only the RID, so a local
			# texture would be freed after the draw and show as white.
			tex = SpriteBank._load(path, id)
		resized.connect(queue_redraw)

	func _draw() -> void:
		var c := size * 0.5
		var r := maxf(minf(size.x, size.y) * 0.5 - 4.0, 0.0)
		if r <= 0.0:
			return
		if tex != null:
			draw_texture_rect(tex, Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0), false)
			return
		# No art yet: a small medallion with the skill's mark cut into it.
		draw_circle(c + Vector2(0, 3), r, Color(0, 0, 0, 0.5))
		draw_circle(c, r, Color("241a12"))
		draw_arc(c, r - 3, 0, TAU, 40, Color("c9a25a"), 3.0, true)
		_mark(c, r * 0.6)

	func _mark(c: Vector2, r: float) -> void:
		var ink := Color("e8c070")
		match MaterialDB.skill_of(id):
			"woodcutting":
				# A log: a bark bar with a cut ring at each end.
				var bar := Rect2(c.x - r, c.y - r * 0.32, r * 2.0, r * 0.64)
				draw_rect(bar, Color("8a5a2a"))
				draw_rect(bar, Color("4a2c12"), false, 2.0)
				draw_circle(Vector2(c.x - r * 0.56, c.y), r * 0.24, Color("d8b070"))
				draw_circle(Vector2(c.x + r * 0.56, c.y), r * 0.24, Color("d8b070"))
			"fishing":
				# A fish: a body and a tail.
				var body := PackedVector2Array([
					c + Vector2(-r * 0.75, 0), c + Vector2(-r * 0.15, -r * 0.46),
					c + Vector2(r * 0.5, -r * 0.2), c + Vector2(r * 0.5, r * 0.2),
					c + Vector2(-r * 0.15, r * 0.46)])
				draw_colored_polygon(body, Color("7fb6d6"))
				var outline := body.duplicate()
				outline.append(body[0])
				draw_polyline(outline, ink, 2.0, true)
				draw_colored_polygon(PackedVector2Array([
					c + Vector2(-r * 0.7, 0), c + Vector2(-r * 1.15, -r * 0.42),
					c + Vector2(-r * 1.15, r * 0.42)]), Color("7fb6d6"))
			_:
				# An ore chunk: a faceted lump.
				var chunk := PackedVector2Array([
					c + Vector2(-r * 0.72, r * 0.28), c + Vector2(-r * 0.34, -r * 0.62),
					c + Vector2(r * 0.46, -r * 0.5), c + Vector2(r * 0.78, r * 0.32),
					c + Vector2(0, r * 0.72)])
				draw_colored_polygon(chunk, Color("b08a5e"))
				var edge := chunk.duplicate()
				edge.append(chunk[0])
				draw_polyline(edge, ink, 2.0, true)


## A dimmed sheet over the page that asks once before a bulk sale: what goes,
## what it pays, and the two ways out.
class ConfirmSheet extends Control:
	signal confirmed
	signal cancelled
	var total := 0
	var items := 0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var dim := ColorRect.new()
		dim.color = Color(0, 0, 0, 0.62)
		dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		dim.gui_input.connect(func(e: InputEvent) -> void:
			if (e is InputEventMouseButton and e.pressed) or (e is InputEventScreenTouch and e.pressed):
				cancelled.emit())
		add_child(dim)
		var center := CenterContainer.new()
		center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(center)
		var plate := UiKit.Plate.new()
		plate.kind = "panel"
		plate.pad = 24
		center.add_child(plate)
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 14)
		plate.add_child(box)
		var title := UiKit.title("Sell the bag?", 40)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(title)
		var line := UiKit.label("%d materials for %d coins." % [items, total], 22, UiKit.CREAM, "b", 4)
		line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(line)
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 14)
		box.add_child(row)
		var keep := UiKit.secondary("KEEP", 240, 88)
		keep.pressed.connect(func() -> void: cancelled.emit())
		row.add_child(keep)
		var sell := UiKit.confirm("SELL", 240, 88)
		sell.pressed.connect(func() -> void: confirmed.emit())
		row.add_child(sell)


## A forged medallion with a carved glyph for the skill. Every glyph is drawn
## from simple polylines in the bronze/gold palette (no textures), so each
## combat or gathering skill reads at a glance.
class Glyph extends Control:
	var kind := ""

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5 - 2.0
		draw_circle(c + Vector2(0, 3), r, Color(0, 0, 0, 0.5))
		draw_circle(c, r, Color("2a2119"))
		draw_arc(c, r - 3, 0, TAU, 48, Color("c9a25a"), 4.0, true)
		draw_arc(c, r - 8, 0, TAU, 48, Color(0, 0, 0, 0.6), 2.0, true)
		draw_circle(c, r - 10, Color("3a2c20"))
		var ink := Color("e8c070")
		var dark := Color("2a2119")
		match kind:
			"attack":
				# Crossed swords: two blades with a crossguard and pommel.
				for s in [-1.0, 1.0]:
					var low := c + Vector2(-s * 22.0, 26.0)
					var tip := c + Vector2(s * 24.0, -28.0)
					draw_line(low, tip, dark, 11.0, true)
					draw_line(low, tip, ink, 6.0, true)
					var guard := low.lerp(tip, 0.24)
					var perp := Vector2(tip.y - low.y, low.x - tip.x).normalized() * 11.0
					draw_line(guard - perp, guard + perp, ink, 5.0, true)
					draw_circle(low, 5.0, ink)
			"strength":
				# Fist-hammer: a heavy head over a straight haft.
				draw_line(c + Vector2(0, 30), c + Vector2(0, -6), ink, 8.0, true)
				draw_colored_polygon(PackedVector2Array([
					c + Vector2(-26, -28), c + Vector2(22, -28),
					c + Vector2(26, -8), c + Vector2(-22, -8)]), ink)
				draw_line(c + Vector2(-20, -18), c + Vector2(20, -18), dark, 3.0, true)
			"defence":
				# Shield: a heater shape split by a cross.
				draw_colored_polygon(PackedVector2Array([
					c + Vector2(0, -30), c + Vector2(24, -18), c + Vector2(22, 8),
					c + Vector2(0, 30), c + Vector2(-22, 8), c + Vector2(-24, -18)]), ink)
				draw_line(c + Vector2(0, -24), c + Vector2(0, 24), dark, 3.0, true)
				draw_line(c + Vector2(-17, -16), c + Vector2(17, -16), dark, 3.0, true)
			"ranged":
				# Bow and arrow: a curved limb, string and a fletched shaft.
				draw_arc(c + Vector2(-10, 0), 26.0, -0.42 * PI, 0.42 * PI, 24, ink, 5.0, true)
				draw_line(c + Vector2(-2, -26), c + Vector2(-2, 26), ink, 3.0, true)
				draw_line(c + Vector2(-24, 0), c + Vector2(28, 0), ink, 4.0, true)
				draw_colored_polygon(PackedVector2Array([c + Vector2(28, 0), c + Vector2(17, -7), c + Vector2(17, 7)]), ink)
				draw_line(c + Vector2(-24, 0), c + Vector2(-15, -7), ink, 3.0, true)
				draw_line(c + Vector2(-24, 0), c + Vector2(-15, 7), ink, 3.0, true)
			"magic":
				# Rune star: a five-point sigil with a hollow core.
				var star := PackedVector2Array()
				for i in 10:
					var ang := -PI * 0.5 + float(i) * PI / 5.0
					var rad := 30.0 if i % 2 == 0 else 12.0
					star.append(c + Vector2(cos(ang), sin(ang)) * rad)
				draw_colored_polygon(star, ink)
				draw_circle(c, 6.0, Color("3a2c20"))
			"hitpoints":
				# Heart: the classic parametric lobes.
				var heart := PackedVector2Array()
				for i in 28:
					var t := TAU * float(i) / 28.0
					var hx := 16.0 * pow(sin(t), 3.0)
					var hy := 13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t)
					heart.append(c + Vector2(hx, -hy) * 1.35)
				draw_colored_polygon(heart, ink)
			"woodcutting":
				# Axe: a long haft with a broad blade at the head.
				draw_line(c + Vector2(-8, 30), c + Vector2(4, -8), ink, 6.0, true)
				draw_colored_polygon(PackedVector2Array([
					c + Vector2(2, -16), c + Vector2(28, -22), c + Vector2(24, -4), c + Vector2(2, 2)]), ink)
				draw_line(c + Vector2(5, -11), c + Vector2(26, -18), dark, 3.0, true)
			"fishing":
				# Fish: a body with a forked tail and an eye.
				draw_colored_polygon(PackedVector2Array([
					c + Vector2(-22, 0), c + Vector2(-34, -13), c + Vector2(-34, 13)]), ink)
				draw_colored_polygon(PackedVector2Array([
					c + Vector2(-22, 0), c + Vector2(-6, -13), c + Vector2(14, -8),
					c + Vector2(23, 0), c + Vector2(14, 8), c + Vector2(-6, 13)]), ink)
				draw_line(c + Vector2(0, -9), c + Vector2(-6, -19), ink, 4.0, true)
				draw_circle(c + Vector2(13, -2), 2.5, dark)
			"mining":
				# Pickaxe: a haft under a curved double pick.
				draw_line(c + Vector2(-6, 30), c + Vector2(4, -4), ink, 6.0, true)
				draw_arc(c + Vector2(4, -4), 22.0, PI, TAU, 20, ink, 5.0, true)
			_:
				# Haven't drawn this one yet: a plain forged rune.
				draw_colored_polygon(PackedVector2Array([c + Vector2(-22, -24), c + Vector2(10, -24), c + Vector2(14, -14), c + Vector2(-22, -12)]), ink)
				draw_line(c + Vector2(-4, -12), c + Vector2(-4, 30), ink, 7.0)


class XpBar extends Control:
	var ratio := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		UiKit.ch_fill(self, r, 8, Color("0c0806"), Color("0c0806"))
		UiKit.ch_fill(self, r.grow(-3), 6, Color("1e1712"), Color("140f0b"))
		if ratio > 0.0:
			var f := Rect2(r.position + Vector2(3, 3), Vector2((r.size.x - 6) * ratio, r.size.y - 6))
			UiKit.ch_fill(self, f, 6, Color("8fd06a"), Color("3e7a2e"))
		draw_line(Vector2(10, 4), Vector2(size.x - 10, 4), Color(1, 0.9, 0.7, 0.12), 1.0)
