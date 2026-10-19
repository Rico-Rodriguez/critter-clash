class_name StatsPanel
extends PanelContainer

## The collapsible Stats and Training panel on the hero screen. Collapsed it is
## one 88 px header row (title, combat level, skill total); tapping it expands
## an OSRS-style 3-column grid of square skill cells (icon, big level number,
## small XP line) followed by the total and the gear unlock levels. The grid is
## data-driven over GearDB.SKILL_KEYS, so future gathering skills slot in
## automatically. It sits below the hero name plaque in normal page flow,
## never over the 3D stage.

## Skill abbreviation used as the icon glyph, derived from the display name so
## future skills (Woodcutting -> WO, Fishing -> FI, Mining -> MI) need no edit.
static var _icon_colors := {
	"attack": Color("d9b64a"),
	"strength": Color("c45536"),
	"defence": Color("6f8fc4"),
	"ranged": Color("7ba05a"),
	"magic": Color("7a6fc4"),
	"hitpoints": Color("c45a6a"),
}

var hero_id := ""
var expanded := false
var head: HeadButton
var scroll: ScrollContainer
var rows: VBoxContainer
var panels: Array = []


func _ready() -> void:
	var empty := StyleBoxEmpty.new()
	empty.content_margin_left = 14
	empty.content_margin_right = 14
	empty.content_margin_top = 10
	empty.content_margin_bottom = 10
	add_theme_stylebox_override("panel", empty)
	add_child(UiKit.Frame.new("panel", "leather"))
	add_theme_constant_override("separation", 0)
	head = HeadButton.new()
	head.set_main(hero_id)
	add_child(head)
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(620, 0)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.visible = false
	add_child(scroll)
	rows = VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 10)
	rows.mouse_filter = Control.MOUSE_FILTER_PASS
	scroll.add_child(rows)
	head.pressed.connect(_toggle)


## Point the panel at a hero and rebuild the readouts for the current state.
func set_hero(id: String) -> void:
	hero_id = id
	head.set_main(id)
	_refresh()


func _toggle() -> void:
	expanded = not expanded
	AudioDirector.sfx("ui_tap")
	AudioDirector.haptic("light")
	scroll.visible = expanded
	_refresh()


func _refresh() -> void:
	head.set_main(hero_id)
	if hero_id == "":
		return
	for node in panels:
		if is_instance_valid(node):
			node.queue_free()
	panels.clear()
	if not expanded:
		return
	var skills := GearDB.skills(hero_id)
	var total := 0
	for key in GearDB.SKILL_KEYS:
		total += int(skills[key])
	var grid := GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	panels.append(grid)
	rows.add_child(grid)
	for i in GearDB.SKILL_KEYS.size():
		var key := str(GearDB.SKILL_KEYS[i])
		var cell := SkillCell.new()
		cell.hero = hero_id
		cell.skill = key
		panels.append(cell)
		grid.add_child(cell)
	var unlocked := UiKit.label("TOTAL %d  ·  TRAIN BY HUNTING" % total, 18, UiKit.GOLD.lightened(0.2), "x", 2)
	unlocked.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panels.append(unlocked)
	rows.add_child(unlocked)
	var gear_cap := UiKit.label("GEAR UNLOCK LEVELS", 18, UiKit.MUTED, "x", 2)
	gear_cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panels.append(gear_cap)
	rows.add_child(gear_cap)
	for line in _gear_gates():
		var row := UiKit.label(line, 20, UiKit.CREAM, "b", 2)
		row.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		panels.append(row)
		rows.add_child(row)
	# Expanded panel is capped so the page below stays reachable by scrolling.
	scroll.custom_minimum_size = Vector2(620, 820)


## "Iron Bascinet — Defence 1", one line per kit piece that gates on a skill.
func _gear_gates() -> Array[String]:
	var out: Array[String] = []
	for slot in GearDB.HERO_SLOTS.get(hero_id, []):
		for tier in range(GearDB.Tier.IRON, GearDB.Tier.RUNE + 1):
			var id := GearDB.item_id(hero_id, str(slot), tier)
			var piece := GearDB.item(id)
			if piece.is_empty():
				continue
			var req: Dictionary = piece["requires"]
			for k in GearDB.SKILL_KEYS:
				if not req.has(k):
					continue
				out.append("%s — %s %d" % [piece["name"], GearDB.SKILL_NAMES[GearDB.SKILL_KEYS.find(k)], int(req[k])])
	return out


## 1234567 -> "1,234,567", for the small XP line in a skill cell.
static func _comma(n: int) -> String:
	var s := str(n)
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return s + out


## Icon accent color for a skill; unknown (future) keys get a stable hue
## derived from the skill name so the grid colors itself as skills are added.
static func _accent(skill: String) -> Color:
	if _icon_colors.has(skill):
		return _icon_colors[skill]
	return Color.from_hsv(float(str(skill).hash() % 360) / 360.0, 0.55, 0.8)


## The collapsed 88 px header row: title, combat level and total, plus a
## chevron showing what a tap will do. A real Button for the tap.
class HeadButton extends Button:
	var hero := ""

	func set_main(id: String) -> void:
		hero = id
		custom_minimum_size = Vector2(620, 88)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		focus_mode = Control.FOCUS_NONE
		tooltip_text = "Stats and training"
		var empty := StyleBoxEmpty.new()
		for st in ["normal", "hover", "pressed", "focus", "disabled"]:
			add_theme_stylebox_override(st, empty)
		queue_redraw()

	func _draw() -> void:
		UiKit.ensure()
		var lvl := 0
		var total := 0
		if hero != "":
			lvl = SaveGame.combat_level(hero)
			var skills := GearDB.skills(hero)
			for key in GearDB.SKILL_KEYS:
				total += int(skills[key])
		var cx := size.x * 0.5
		var cy := size.y * 0.5
		UiKit.draw_text(self, UiKit.font_x, Vector2(cx - size.x * 0.46, size.y * 0.5 + 14), "STATS AND TRAINING", 26, UiKit.GOLD.lightened(0.2), Color(0.04, 0.03, 0.02), 3, size.x * 0.5)
		UiKit.draw_text(self, UiKit.font_b, Vector2(cx + size.x * 0.06, size.y * 0.5 + 12), "Combat %d" % lvl, 24, UiKit.CREAM, Color(0.04, 0.03, 0.02), 2, size.x * 0.2)
		UiKit.draw_text(self, UiKit.font_b, Vector2(cx + size.x * 0.27, size.y * 0.5 + 12), "Total %d" % total, 24, UiKit.CREAM, Color(0.04, 0.03, 0.02), 2, size.x * 0.14)
		var flip := 1.0 if get_parent().expanded else -1.0
		var at := Vector2(cx + size.x * 0.42, cy)
		var w := size.y * 0.09
		var h := size.y * 0.09
		var pts := PackedVector2Array([
			Vector2(at.x - w, at.y - flip * h),
			Vector2(at.x + w, at.y - flip * h),
			Vector2(at.x, at.y + flip * h),
		])
		draw_polyline(pts, Color(0, 0, 0, 0.55), 9.0, true)
		draw_polyline(pts, UiKit.INK, 6.0, true)
		draw_polyline(pts, Color("ffe3a0"), 3.0, true)


## One OSRS-style skill cell: a small square tile with a diamond icon carrying
## the skill's abbreviation top-left, the current level as a big number
## centered, and the banked XP as a small line underneath. Level 99 glows gold.
class SkillCell extends Control:
	var hero := ""
	var skill := ""
	const SIDE := 112.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(SIDE, SIDE)

	func _draw() -> void:
		UiKit.ensure()
		var r := Rect2(Vector2.ZERO, size)
		UiKit.ch_fill(self, r, 14, Color("4a3a22"), Color("241a0e"))
		var accent := StatsPanel._accent(skill)
		var icon := Vector2(22, 22)
		var rad := 12.0
		var pts := PackedVector2Array([
			icon + Vector2(0, -rad),
			icon + Vector2(rad, 0),
			icon + Vector2(0, rad),
			icon + Vector2(-rad, 0),
		])
		draw_colored_polygon(pts, accent)
		draw_polyline(pts + PackedVector2Array([pts[0]]), Color(0.04, 0.03, 0.02, 0.8), 2.0, true)
		var abbr := GearDB.SKILL_NAMES[GearDB.SKILL_KEYS.find(skill)].left(2).to_upper()
		var a_size := 10
		var a_w := UiKit.font_m.get_string_size(abbr, HORIZONTAL_ALIGNMENT_LEFT, -1, a_size).x
		UiKit.draw_text(self, UiKit.font_m, Vector2(icon.x - a_w * 0.5, icon.y + a_size * 0.35), abbr, a_size, Color("241a0e"), accent, 0)
		var lvl := 1
		var banked := 0
		if hero != "":
			lvl = GearDB.level(hero, skill)
			banked = GearDB.xp(hero, skill)
		var maxed := lvl >= GearDB.MAX_LEVEL
		var ink := Color("ffe3a0") if maxed else UiKit.CREAM
		var n := str(lvl)
		var n_px := 36
		var n_w := UiKit.font_x.get_string_size(n, HORIZONTAL_ALIGNMENT_LEFT, -1, n_px).x
		UiKit.draw_text(self, UiKit.font_x, Vector2(size.x * 0.5 - n_w * 0.5, size.y * 0.58), n, n_px, ink, Color(0.04, 0.03, 0.02), 3)
		var xp_line := "MAX XP" if maxed else "%s XP" % StatsPanel._comma(banked)
		var s_px := 13
		var s_w := UiKit.font_m.get_string_size(xp_line, HORIZONTAL_ALIGNMENT_LEFT, -1, s_px).x
		UiKit.draw_text(self, UiKit.font_m, Vector2(size.x * 0.5 - s_w * 0.5, size.y * 0.84), xp_line, s_px, UiKit.MUTED, Color(0.04, 0.03, 0.02), 1)
