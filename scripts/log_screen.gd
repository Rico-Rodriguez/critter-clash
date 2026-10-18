extends ScreenBase

var grid: GridContainer
var crest: BossCrest
var tabs: HBoxContainer
var boss_id := "thistle"


func build() -> void:
	show_nav = true
	nav_tab = ""
	var box := column()
	box.add_child(header_with_back("home"))
	box.add_child(h1("Collection Log"))
	crest = BossCrest.new()
	crest.custom_minimum_size = Vector2(0, 170)
	box.add_child(crest)
	tabs = HBoxContainer.new()
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs.add_theme_constant_override("separation", 8)
	box.add_child(tabs)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	grid = GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	scroll.add_child(grid)
	_fill()


func _tab(id: String) -> void:
	boss_id = id
	AudioDirector.play("click")
	_fill()


func _fill() -> void:
	# Biome tabs: the open one in gold, the rest in iron.
	for child in tabs.get_children():
		child.queue_free()
	for entry in Catalog.BIOMES:
		var id := str(entry["boss"])
		var short := str(entry["name"]).split(" ")[0]
		# Shared tab shape: 88 px tall like every other tap target.
		var button := UiKit.button(short, 160, 88, "gold") if id == boss_id else UiKit.secondary(short, 160, 88)
		button.pressed.connect(_tab.bind(id))
		tabs.add_child(button)
	# Stable order: biome tab, then rarity, then id (Catalog.log_table), so the
	# grid never reshuffles between visits.
	var table: Array = Catalog.log_table(boss_id)
	var got := 0
	var shown: Array = []
	for entry in table:
		var id := str(entry["id"])
		shown.append(id)
		if SaveGame.has_log(id):
			got += 1
	var boss := Catalog.critter(boss_id)
	crest.boss_id = boss_id
	crest.title = str(boss.get("name", "Boss"))
	crest.kills = SaveGame.boss_kills(boss_id)
	crest.got = got
	crest.total = table.size()
	crest.queue_redraw()
	for child in grid.get_children():
		child.queue_free()
	# New saves stare at pure silhouettes: one friendly grimdark line instead
	# of a bare counter.
	if SaveGame.log_obtained_count() == 0:
		crest.overall = "The log lies blank. Slay a beast and its spoils are inked here."
	else:
		crest.overall = "%d / %d in the whole log" % [SaveGame.log_obtained_count(), Catalog.log_entries().size()]
	crest.queue_redraw()
	for entry in table:
		var id := str(entry["id"])
		var cell := LogCell.new()
		cell.drop = entry
		cell.got = SaveGame.has_log(id)
		cell.is_new = SaveGame.log_is_new(id)
		cell.custom_minimum_size = Vector2(0, 196)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.pressed_pet.connect(_pet)
		grid.add_child(cell)
	# A biome's table is never empty in Catalog, but a stray save with an
	# unknown boss id should show a friendly line, not a blank panel.
	if table.is_empty():
		var empty := UiKit.label("Nothing is catalogued under this ground yet.", 24, UiKit.MUTED, "b", 3)
		empty.custom_minimum_size = Vector2(0, 120)
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		grid.add_child(empty)
	# Showing the tab counts as reading it; the mark is persisted so a find
	# stops being "new" across a restart once it has been seen.
	SaveGame.log_mark_seen(shown)


func _pet(id: String) -> void:
	SaveGame.set_active_pet(id)
	var drop := Catalog.drop_by_id(id)
	toast("%s follows you." % str(drop.get("name", "Pet")))


class LogCell extends PanelContainer:
	signal pressed_pet(id: String)

	var drop: Dictionary = {}
	var got := false
	var is_new := false

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		var rarity := _rarity_key()
		var metal := UiKit.rarity_metal(rarity if got else "common")
		var cols: Dictionary = UiKit.rarity_colors(rarity)
		var fr := UiKit.Frame.new("card", "leather", {
			"metal_hi": metal[0], "metal_lo": metal[1], "frame": 6.0,
			"glow_color": Color(cols["glow"], 0.25 if got else 0.0),
			"face_top": Color("221a14") if got else Color("120e0b"), "face_bot": Color("0c0907"),
		})
		fr.margin = 12.0
		add_child(fr)
		var face := Face.new()
		face.cell = self
		add_child(face)
		gui_input.connect(_on_input)

	func _rarity_key() -> String:
		var r := str(drop.get("rarity", "common"))
		if "legend" in r or "mythic" in r:
			return "legendary"
		if "very" in r or "epic" in r:
			return "epic"
		if "rare" in r or "uncommon" in r:
			return "rare"
		return "common"

	func _on_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and got and str(drop.get("kind", "")) == "pet":
			# A real press: sink, haptic and the shared tap sting before the
			# pet walks to the hero's side.
			pivot_offset = size * 0.5
			var tw := create_tween()
			tw.tween_property(self, "scale", Vector2(0.94, 0.94), 0.05)
			tw.tween_property(self, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			AudioDirector.sfx("ui_tap")
			AudioDirector.haptic("light")
			pressed_pet.emit(str(drop["id"]))

	func paint(ci: Control) -> void:
		var w := ci.size.x
		var center := Vector2(w * 0.5, 74)
		var kind := str(drop.get("kind", ""))
		var cols: Dictionary = UiKit.rarity_colors(_rarity_key())
		# Recessed window with a rarity backlight.
		var win := Rect2(Vector2(16, 16), Vector2(w - 32, 112))
		UiKit.ch_fill(ci, win, 10, Color("0a0806"), Color("15100c"))
		if got:
			for i in 8:
				var k := float(i) / 8.0
				ci.draw_circle(center, 52.0 - k * 40.0, Color(cols["glow"], 0.04 + k * 0.012))
		if kind == "pet":
			var tex := SpriteBank.critter(str(drop.get("sprite", "thistle")))
			if tex:
				var tint := Color.WHITE if got else Color(0.05, 0.05, 0.06, 1)
				ci.draw_texture_rect(tex, Rect2(center.x - 44, center.y - 46, 88, 88), false, tint)
		else:
			# Rendered 3D prop (tools: --bake-icons); unfound items show as a
			# dark silhouette of the same prop.
			var path := "res://assets/sprites/items/%s.png" % str(drop.get("id", ""))
			if ResourceLoader.exists(path):
				# Cached: canvas draw commands keep only the RID, so a local
				# texture would be freed after paint() and draw as white.
				var tex: Texture2D = SpriteBank._load(path, "item")
				var tint := Color.WHITE if got else Color(0.17, 0.14, 0.12, 0.9)
				ci.draw_texture_rect(tex, Rect2(center.x - 52, center.y - 52, 104, 104), false, tint)
			else:
				var col := Color(str(drop.get("color", "f0b429")))
				if not got:
					col = Color(0.08, 0.075, 0.07)
				_icon_on(ci, center, kind, col, got)
		if not got:
			var lk := UiKit.icon("lock_closed")
			if lk:
				UiKit.draw_icon(ci, lk, Rect2(center + Vector2(14, 10), Vector2(28, 28)), Color("c9a25a"), Color(0.05, 0.03, 0.02), 2.0)
		UiKit.ensure()
		# A freshly found entry carries a gold NEW tag until its tab is opened.
		if got and is_new:
			var tag := Rect2(w - 70, 16, 58, 26)
			UiKit.ch_fill(ci, tag, 7, Color("ffd77a"), Color("a86a1e"))
			ci.draw_string(UiKit.font_b, Vector2(tag.position.x, tag.position.y + 19), "NEW", HORIZONTAL_ALIGNMENT_CENTER, tag.size.x, 17, Color("2a1806"))
		var rarity := Catalog.rarity_label(str(drop.get("rarity", "common")))
		var ink := Color("fff1d6") if got else Color("b8aa94")
		var name := str(drop.get("name", "")) if got else "???"
		ci.draw_string_outline(UiKit.font_x, Vector2(6, ci.size.y - 38), name, HORIZONTAL_ALIGNMENT_CENTER, w - 12, 19, 4, Color(0.03, 0.02, 0.01))
		ci.draw_string(UiKit.font_x, Vector2(6, ci.size.y - 38), name, HORIZONTAL_ALIGNMENT_CENTER, w - 12, 19, ink)
		ci.draw_string_outline(UiKit.font_b, Vector2(6, ci.size.y - 15), rarity.to_upper(), HORIZONTAL_ALIGNMENT_CENTER, w - 12, 17, 4, Color(0.03, 0.02, 0.01))
		ci.draw_string(UiKit.font_b, Vector2(6, ci.size.y - 15), rarity.to_upper(), HORIZONTAL_ALIGNMENT_CENTER, w - 12, 17, Color(cols["lip"]).lightened(0.2) if got else Color("8a7e6c"))

	func _icon_on(ci: Control, center: Vector2, kind: String, col: Color, owned: bool) -> void:
		var edge := Color(1, 0.92, 0.75, 0.55) if owned else Color(0.5, 0.45, 0.38, 0.8)
		ci.draw_set_transform(center, 0.0, Vector2(1.4, 1.4))
		center = Vector2.ZERO
		match kind:
			"cards":
				ci.draw_rect(Rect2(center.x - 18, center.y - 24, 36, 48), col, true)
				ci.draw_rect(Rect2(center.x - 18, center.y - 24, 36, 48), edge, false, 3.0)
			"gear":
				var shield := PackedVector2Array([
					center + Vector2(0, -26), center + Vector2(22, -8),
					center + Vector2(16, 20), center + Vector2(0, 28),
					center + Vector2(-16, 20), center + Vector2(-22, -8),
				])
				ci.draw_colored_polygon(shield, col)
				ci.draw_polyline(shield + PackedVector2Array([shield[0]]), edge, 3.0, true)
			"material":
				var gem := PackedVector2Array([
					center + Vector2(0, -26), center + Vector2(20, -6),
					center + Vector2(12, 22), center + Vector2(-12, 22),
					center + Vector2(-20, -6),
				])
				ci.draw_colored_polygon(gem, col)
				ci.draw_polyline(gem + PackedVector2Array([gem[0]]), edge, 3.0, true)
			_:
				ci.draw_circle(center + Vector2(-8, 4), 16, col)
				ci.draw_circle(center + Vector2(8, -2), 14, col.lightened(0.12))
				ci.draw_arc(center + Vector2(-8, 4), 16, 0, TAU, 20, edge, 2.5, true)
				ci.draw_arc(center + Vector2(8, -2), 14, 0, TAU, 18, edge, 2.5, true)
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


class Face extends Control:
	var cell: LogCell

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		cell.paint(self)


## The open boss: portrait in a forged roundel, name, kills, and how much
## of its drop table is found, on a leather plaque.
class BossCrest extends PanelContainer:
	var boss_id := "thistle"
	var title := ""
	var kills := 0
	var got := 0
	var total := 0
	var overall := ""
	var face: CrestFace

	func _ready() -> void:
		add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		var metal := UiKit.rarity_metal("legendary")
		var fr := UiKit.Frame.new("plaque", "leather", {"metal_hi": metal[0], "metal_lo": metal[1]})
		fr.margin = 14.0
		add_child(fr)
		face = CrestFace.new()
		face.crest = self
		add_child(face)

	func queue_redraw_all() -> void:
		if face:
			face.queue_redraw()


class CrestFace extends Control:
	var crest: BossCrest

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		UiKit.ensure()
		var h := size.y
		var c := Vector2(30 + h * 0.36, h * 0.5)
		var r := h * 0.36
		draw_circle(c + Vector2(0, 3), r + 4, Color(0, 0, 0, 0.5))
		draw_circle(c, r + 4, Color("c9a25a"))
		draw_circle(c, r, Color("140e0a"))
		var tex := SpriteBank.critter(crest.boss_id)
		if tex:
			draw_texture_rect(tex, Rect2(c - Vector2(r, r) * 0.9, Vector2(r, r) * 1.8), false)
		var x := c.x + r + 22
		var w := size.x - x - 24
		draw_string_outline(UiKit.font_x, Vector2(x, h * 0.34), crest.title.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, w, 34, 6, Color(0.03, 0.02, 0.01))
		draw_string(UiKit.font_x, Vector2(x, h * 0.34), crest.title.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, w, 34, Color("ffe6a8"))
		draw_string_outline(UiKit.font_b, Vector2(x, h * 0.53), "%d slain   ·   %d / %d found" % [crest.kills, crest.got, crest.total], HORIZONTAL_ALIGNMENT_LEFT, w, 22, 4, Color(0.03, 0.02, 0.01))
		draw_string(UiKit.font_b, Vector2(x, h * 0.53), "%d slain   ·   %d / %d found" % [crest.kills, crest.got, crest.total], HORIZONTAL_ALIGNMENT_LEFT, w, 22, Color("efe4cc"))
		var bar := Rect2(Vector2(x, h * 0.62), Vector2(w, 22))
		UiKit.ch_fill(self, bar, 7, Color("0c0806"), Color("0c0806"))
		UiKit.ch_fill(self, bar.grow(-3), 5, Color("1e1712"), Color("140f0b"))
		var ratio := float(crest.got) / float(maxi(crest.total, 1))
		if ratio > 0.0:
			UiKit.ch_fill(self, Rect2(bar.position + Vector2(3, 3), Vector2((bar.size.x - 6) * ratio, bar.size.y - 6)), 5, Color("ffd77a"), Color("a86a1e"))
		draw_string_outline(UiKit.font_b, Vector2(x, h * 0.88), crest.overall, HORIZONTAL_ALIGNMENT_LEFT, w, 19, 4, Color(0.03, 0.02, 0.01))
		draw_string(UiKit.font_b, Vector2(x, h * 0.88), crest.overall, HORIZONTAL_ALIGNMENT_LEFT, w, 19, Color("c8b8a0"))
