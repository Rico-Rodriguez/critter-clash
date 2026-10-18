extends ScreenBase

## Skills splits into two tabs. Combat is per hero: GearDB's six combat skills
## for the hero selected on Heroes. Gathering is the account-wide
## Catalog.SKILLS list. Each row is a forged plaque with the name, level and an
## XP bar; combat skills fill from hunts, gathering stays sealed.


var _tab_buttons := {}
var _content: VBoxContainer


func build() -> void:
	show_nav = true
	nav_tab = ""
	var box := column()
	box.add_child(header())
	box.add_child(h1("Skills"))
	box.add_child(_tab_bar())
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 16)
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_content)
	box.add_child(back_button("home"))
	_show_tab("combat")


func _tab_bar() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	for entry in [["combat", "Combat"], ["gathering", "Gathering"]]:
		var key := str(entry[0])
		var button := UiKit.secondary(str(entry[1]), 280, 76)
		button.pressed.connect(func() -> void: _show_tab(key))
		_tab_buttons[key] = button
		row.add_child(button)
	return row


func _show_tab(tab: String) -> void:
	for key in _tab_buttons:
		var button: Button = _tab_buttons[key]
		button.modulate = Color(1, 1, 1) if key == tab else Color(0.7, 0.7, 0.7)
	if _content == null:
		return
	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()
	if tab == "combat":
		_combat_tab()
	else:
		_gathering_tab()


func _combat_tab() -> void:
	var hero := SaveGame.featured_id()
	var info := Catalog.critter(hero)
	_content.add_child(body("%s · %s. Levels 1–99; combat XP comes from hunts." % [
		str(info.get("name", hero)).to_upper(), Catalog.role_name(str(info.get("role", ""))).to_upper()]))
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 16)
	_content.add_child(list)
	for i in GearDB.SKILL_KEYS.size():
		list.add_child(CombatRow.new(hero, GearDB.SKILL_KEYS[i], GearDB.SKILL_NAMES[i]))


func _gathering_tab() -> void:
	_content.add_child(body("Levels 1–99 on the long curve. Gathering opens in a later season."))
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 16)
	_content.add_child(list)
	for entry in Catalog.SKILLS:
		list.add_child(SkillRow.new(str(entry["id"]), str(entry["name"])))
	var hold := CenterContainer.new()
	hold.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_child(hold)
	var total := TotalPanel.new()
	total.custom_minimum_size = Vector2(minf(620.0, get_viewport_rect().size.x - 64.0), 0)
	hold.add_child(total)


## Total level across every skill, which seals the milestone rewards. This is
## the long goal on the page: a crest with the total, the next milestone, and
## a line of lore so the page reads as a ledger, not a stub.
const MILESTONES: Array = [
	[10, "Wayfarer's Satchel", "A sturdier pack for the trail."],
	[50, "Warden's Lantern", "Marks rare finds through the fog."],
	[150, "Antler Circlet", "A crown cut from the Elder Stag."],
	[396, "Hearthkeeper's Seal", "Every skill mastered."],
]


class TotalPanel extends PanelContainer:
	func _ready() -> void:
		var empty := StyleBoxEmpty.new()
		for side in ["left", "right"]:
			empty.set("content_margin_" + side, 30)
		for side in ["top", "bottom"]:
			empty.set("content_margin_" + side, 26)
		add_theme_stylebox_override("panel", empty)
		var fr := UiKit.Frame.new("plaque", "leather", {"metal_hi": UiKit.GOLD.lightened(0.1), "metal_lo": UiKit.GOLD.darkened(0.45)})
		fr.margin = 14.0
		add_child(fr)
		var total := 0
		for entry in Catalog.SKILLS:
			total += Catalog.skill_level(int(SaveGame.data["skills"].get(str(entry["id"]), 0)))
		var cap := 99 * Catalog.SKILLS.size()
		var next: Array = MILESTONES[MILESTONES.size() - 1]
		for m in MILESTONES:
			if total < int(m[0]):
				next = m
				break
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 24)
		add_child(row)
		var crest := Crest.new()
		crest.value = total
		crest.custom_minimum_size = Vector2(150, 176)
		crest.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(crest)
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		col.add_theme_constant_override("separation", 6)
		row.add_child(col)
		col.add_child(UiKit.label("TOTAL LEVEL", 30, Color("fff1d6"), "x", 6))
		col.add_child(UiKit.label("%d of %d" % [total, cap], 22, Color("e6d8bc"), "b", 4))
		var rule := ColorRect.new()
		rule.color = Color(0.79, 0.64, 0.35, 0.45)
		rule.custom_minimum_size = Vector2(0, 2)
		col.add_child(rule)
		col.add_child(UiKit.label("NEXT MILESTONE · TOTAL %d" % int(next[0]), 19, UiKit.GOLD.lightened(0.15), "x", 4))
		col.add_child(UiKit.label(str(next[1]), 26, Color("fff1d6"), "x", 5))
		var desc := UiKit.label(str(next[2]), 21, Color("d8c8aa"), "b", 4)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(desc)


## A forged shield crest with the total level struck into it.
class Crest extends Control:
	var value := 0

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
		var sub := "TOTAL"
		var sw := font.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		draw_string(font, Vector2(size.x * 0.5 - sw * 0.5, size.y * 0.72), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("c9a25a"))


class SkillRow extends PanelContainer:
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
		var xp := int(SaveGame.data["skills"].get(skill_id, 0))
		var level := Catalog.skill_level(xp)
		var next_xp := Catalog.skill_xp_to_level(mini(99, level + 1))
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
		bar.ratio = clampf(float(xp) / float(maxi(next_xp, 1)), 0.0, 1.0)
		bar.custom_minimum_size = Vector2(0, 26)
		col.add_child(bar)
		var foot := HBoxContainer.new()
		foot.add_child(UiKit.label("%d / %d XP" % [xp, next_xp if level < 99 else xp], 21, Color("e6d8bc"), "b", 4))
		var gap2 := Control.new()
		gap2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		foot.add_child(gap2)
		foot.add_child(UiKit.label("SEALED", 20, Color("c8b8a0"), "x", 4))
		col.add_child(foot)


## A combat skill row for the selected hero: GearDB level and a bar to the
## next level (the plaque mirrors the gathering rows).
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
		foot.add_child(UiKit.label("%d / %d XP" % [into, span], 21, Color("e6d8bc"), "b", 4))
		var gap2 := Control.new()
		gap2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		foot.add_child(gap2)
		foot.add_child(UiKit.label("MAX" if maxed else "TO LV %d" % (level + 1), 20, Color("c8b8a0"), "x", 4))
		col.add_child(foot)


## A forged medallion with a carved glyph for the skill.
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
		match kind:
			"foraging":
				var pts := PackedVector2Array()
				for i in 13:
					var t := float(i) / 12.0
					pts.append(c + Vector2(sin(t * PI) * 19.0, -28 + t * 52))
				for i in 13:
					var t := 1.0 - float(i) / 12.0
					pts.append(c + Vector2(-sin(t * PI) * 19.0, -28 + t * 52))
				draw_colored_polygon(pts, ink)
				draw_line(c + Vector2(0, -24), c + Vector2(0, 32), Color("3a2c20"), 3.0)
			"fishing":
				draw_line(c + Vector2(8, -30), c + Vector2(8, 10), ink, 5.0)
				draw_arc(c + Vector2(-6, 10), 14, 0.0, PI, 16, ink, 5.0, true)
				draw_colored_polygon(PackedVector2Array([c + Vector2(-20, 10), c + Vector2(-26, 0), c + Vector2(-14, 4)]), ink)
				draw_circle(c + Vector2(8, -30), 5, ink)
			"taming":
				draw_circle(c + Vector2(0, 10), 14, ink)
				for p in [Vector2(-18, -8), Vector2(-7, -20), Vector2(7, -20), Vector2(18, -8)]:
					draw_circle(c + p, 7, ink)
			_:
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
