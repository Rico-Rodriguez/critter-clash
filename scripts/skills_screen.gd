extends ScreenBase

## Skills are stored as XP only. Gathering is not in the game yet. Each skill
## is a forged plaque: a medallion glyph, the name, level, and an XP bar,
## sealed with a chain tag until gathering opens.


func build() -> void:
	show_nav = true
	nav_tab = ""
	var box := column()
	box.add_child(header())
	box.add_child(h1("Skills"))
	box.add_child(body("Levels 1–99 on the long curve. Gathering opens in a later season."))
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 16)
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(list)
	for entry in Catalog.SKILLS:
		list.add_child(SkillRow.new(str(entry["id"]), str(entry["name"])))
	box.add_child(back_button("home"))


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
