class_name StatsPanel
extends PanelContainer

## The collapsible Stats and Training panel on the hero screen. Collapsed it is
## one 88 px header row (title, combat level, skill total); tapping it expands
## a scroll of the six skills with their XP bars plus the gear unlock levels.
## It sits below the hero name plaque in normal page flow, never over the 3D
## stage.

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
	var xp: Dictionary = {}
	var all: Dictionary = GearDB._store()["xp"].get(hero_id, {})
	if typeof(all) == TYPE_DICTIONARY:
		xp = all
	var total := 0
	for key in GearDB.SKILL_KEYS:
		total += int(skills[key])
	var caption := UiKit.label("SKILLS", 18, UiKit.MUTED, "x", 2)
	panels.append(caption)
	rows.add_child(caption)
	for i in GearDB.SKILL_KEYS.size():
		var key := str(GearDB.SKILL_KEYS[i])
		var bar := SkillBar.new()
		bar.skill = key
		bar.level = int(skills[key])
		bar.hero = hero_id
		bar.ratio = _progress(key, int(xp.get(key, 0)), int(skills[key]))
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panels.append(bar)
		rows.add_child(bar)
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


## Fraction of the way through the current level of a skill (1.0 at max).
func _progress(skill: String, xp_banked: int, lvl: int) -> float:
	if lvl >= GearDB.MAX_LEVEL:
		return 1.0
	var low := GearDB.xp_for_level(lvl)
	var high := GearDB.xp_for_level(lvl + 1)
	if high <= low:
		return 1.0
	return clampf(float(xp_banked - low) / float(high - low), 0.0, 0.999)


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


## One OSRS-style XP bar: skill name and level on the caption line, the filled
## trough showing progress inside the current level. Same look as CardBar.
class SkillBar extends Control:
	var skill := ""
	var hero := ""
	var level := 1
	var ratio := 0.0
	var pressed := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(0, 56)

	func _draw() -> void:
		UiKit.ensure()
		var r := Rect2(Vector2.ZERO, size)
		UiKit.draw_text(self, UiKit.font_x, Vector2(4, r.size.y * 0.52), GearDB.SKILL_NAMES[GearDB.SKILL_KEYS.find(skill)].to_upper(), 22, UiKit.GOLD.lightened(0.2), Color(0.04, 0.03, 0.02), 3, r.size.x * 0.5)
		UiKit.draw_text(self, UiKit.font_b, Vector2(r.size.x * 0.94, r.size.y * 0.5), "Lv %d" % level, 20, UiKit.CREAM, Color(0.04, 0.03, 0.02), 2, r.size.x)
		var trough := Rect2(0, r.size.y * 0.62, r.size.x, r.size.y * 0.3)
		UiKit.ch_fill(self, trough.grow(1), trough.size.y * 0.5, Color("8a6a3a"), Color("3a2410"))
		UiKit.ch_fill(self, trough.grow(-2), trough.size.y * 0.5 - 1, Color("070504"), Color("1a140f"))
		var inner := Rect2(trough.position + Vector2(2, 2), Vector2(maxf(0.0, (trough.size.x - 4.0) * ratio), maxf(0.0, trough.size.y - 4)))
		if inner.size.x > inner.size.y:
			UiKit.ch_fill(self, inner, inner.size.y * 0.5, Color("ffd23e"), Color("7a4a10"))
			UiKit.ch_fill(self, Rect2(inner.position + Vector2(4, 1), Vector2(inner.size.x - 8, inner.size.y * 0.4)), inner.size.y * 0.2, Color(1, 1, 1, 0.3), Color(1, 1, 1, 0.0))
