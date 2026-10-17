extends ScreenBase

## Skills are stored as XP only. Gathering is not in the game yet.


func build() -> void:
	show_nav = true
	nav_tab = ""
	var box := column()
	box.add_child(header())
	box.add_child(h1("Skills"))
	box.add_child(body("Levels 1–99 use the long curve. Nothing to gather yet."))
	for entry in Catalog.SKILLS:
		box.add_child(SkillRow.new(str(entry["id"]), str(entry["name"])))
	var later := UiKit.secondary("Not open yet", 420, 68)
	later.pressed.connect(func() -> void: toast("Gathering comes later."))
	box.add_child(later)
	box.add_child(back_button("home"))


class SkillRow extends PanelContainer:
	var skill_id := ""
	var skill_name := ""

	func _init(id: String, title: String) -> void:
		skill_id = id
		skill_name = title

	func _ready() -> void:
		custom_minimum_size = Vector2(0, 92)
		var frame := UiKit.panel(Color("163e86"), 16)
		frame.content_margin_left = 14
		frame.content_margin_right = 14
		frame.content_margin_top = 8
		frame.content_margin_bottom = 8
		add_theme_stylebox_override("panel", frame)
		var xp := int(SaveGame.data["skills"].get(skill_id, 0))
		var level := Catalog.skill_level(xp)
		var next_xp := Catalog.skill_xp_to_level(mini(99, level + 1))
		var line := UiKit.label("%s" % skill_name, 26, UiKit.CREAM, "x", 4)
		var meta := UiKit.label("Level %d    %d / %d xp" % [level, xp, next_xp if level < 99 else xp], 18, Color("d5e6ff"), "b", 3)
		var box := VBoxContainer.new()
		box.add_child(line)
		box.add_child(meta)
		add_child(box)
