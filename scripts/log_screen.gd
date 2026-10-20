class_name LogScreen
extends ScreenBase

## The Armory is the Collection Log's fifth tab: a progression goal board for
## every gear piece per hero, owned or still to find. boss_id is left untouched
## while it is open, so returning to a biome tab restores exactly that view.

## Sentinel tab id for the Armory page (never a biome boss id).
const ARMORY := "armory"

var grid: GridContainer
var crest: BossCrest
var tabs: FlowContainer
var boss_id := "thistle"
## True while the Armory tab is open.
var armory := false
## The hero the Armory is showing. Empty follows the featured hero; the
## switcher only moves this local view and never writes the save (TASK).
var _armory_view := ""
var armory_head: VBoxContainer
var armory_switch: HFlowContainer
var armory_header: Label


func build() -> void:
	show_nav = true
	nav_tab = ""
	var box := column()
	box.add_child(header_with_back("home"))
	box.add_child(h1("Collection Log"))
	crest = BossCrest.new()
	crest.custom_minimum_size = Vector2(0, 170)
	box.add_child(crest)
	# Five tabs (four biomes + Armory) fit 720 px at 160 px wide; a flow row
	# wraps instead of running off the safe area on anything narrower.
	tabs = HFlowContainer.new()
	tabs.alignment = FlowContainer.ALIGNMENT_CENTER
	tabs.add_theme_constant_override("h_separation", 8)
	tabs.add_theme_constant_override("v_separation", 8)
	box.add_child(tabs)
	# Armory head: a view-only hero switcher and the tier count line, shown
	# only while the Armory tab is open.
	armory_head = VBoxContainer.new()
	armory_head.add_theme_constant_override("separation", 10)
	armory_head.visible = false
	armory_switch = HFlowContainer.new()
	armory_switch.alignment = FlowContainer.ALIGNMENT_CENTER
	armory_switch.add_theme_constant_override("h_separation", 10)
	armory_switch.add_theme_constant_override("v_separation", 10)
	armory_head.add_child(armory_switch)
	armory_header = UiKit.label("", 24, Color("e6d8bc"), "x", 4)
	armory_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	armory_head.add_child(armory_header)
	box.add_child(armory_head)
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
	if id == ARMORY:
		armory = true
	else:
		armory = false
		boss_id = id
	AudioDirector.play("click")
	_fill()


func _fill() -> void:
	_fill_tabs()
	if armory:
		_fill_armory()
	else:
		_fill_biome()


## The tab row: biome tabs then Armory. The open one is gold, the rest iron,
## all 88 px tall like every other tap target.
func _fill_tabs() -> void:
	for child in tabs.get_children():
		child.queue_free()
	for entry in Catalog.BIOMES:
		var id := str(entry["boss"])
		var short := str(entry["name"]).split(" ")[0]
		var on := not armory and id == boss_id
		var button := UiKit.button(short, 160, 88, "gold") if on else UiKit.secondary(short, 160, 88)
		button.pressed.connect(_tab.bind(id))
		tabs.add_child(button)
	var armory_button := UiKit.button("Armory", 160, 88, "gold") if armory else UiKit.secondary("Armory", 160, 88)
	armory_button.pressed.connect(_tab.bind(ARMORY))
	tabs.add_child(armory_button)


func _fill_biome() -> void:
	grid.columns = 3
	crest.visible = true
	armory_head.visible = false
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


## The Armory: every gear piece per hero as a progression goal board. The boss
## crest is hidden and a 4-column grid (slot + Iron / Blackened Steel / Cursed
## Rune Plate) lists owned pieces and what is still to hunt.
func _fill_armory() -> void:
	crest.visible = false
	armory_head.visible = true
	var hero := armory_view_id()
	_build_armory_switch(hero)
	var counts := armory_counts(hero)
	armory_header.text = "Iron %d/%d · Steel %d/%d · Rune %d/%d" % [
		int(counts["iron"]), int(counts["total"]),
		int(counts["steel"]), int(counts["total"]),
		int(counts["rune"]), int(counts["total"]),
	]
	for child in grid.get_children():
		child.queue_free()
	grid.columns = 4
	grid.add_child(_armory_head_cell("Slot", UiKit.MUTED))
	for tier in [GearDB.Tier.IRON, GearDB.Tier.STEEL, GearDB.Tier.RUNE]:
		grid.add_child(_armory_head_cell(GearDB.TIER_NAMES[tier].to_upper(), GearDB.TIER_COLORS[tier]))
	var slots: Array = GearDB.HERO_SLOTS.get(hero, [])
	var owned: Dictionary = GearDB._store()["owned"].get(hero, {})
	for slot in slots:
		var name := UiKit.label(GearDB.SLOT_NAMES[GearDB.SLOT_KEYS.find(str(slot))], 22, Color("e6d8bc"), "b", 4)
		name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(name)
		for tier in [GearDB.Tier.IRON, GearDB.Tier.STEEL, GearDB.Tier.RUNE]:
			var id := GearDB.item_id(hero, str(slot), tier)
			var cell := ArmoryCell.new()
			var owns_any := false
			var best_id := id
			var best_rarity := -1
			for oid in owned:
				if int(owned[oid]) > 0:
					var p := GearDB._parse_id(str(oid))
					if not p.is_empty() and p["slot"] == slot and int(p["tier"]) == tier:
						owns_any = true
						if int(p["rarity"]) > best_rarity:
							best_rarity = int(p["rarity"])
							best_id = str(oid)
						break
			cell.owned = owns_any
			cell.title = str(GearDB.item(best_id).get("name", "?")) if owns_any else "?"
			cell.hint = "" if owns_any else drop_hint(tier)
			cell.req = _req_text(id)
			cell.custom_minimum_size = Vector2(0, 116)
			cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			grid.add_child(cell)
	if slots.is_empty():
		var empty := UiKit.label("No gear slots for this hero.", 24, UiKit.MUTED, "b", 3)
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		grid.add_child(empty)


func _armory_head_cell(text: String, color: Color) -> Label:
	var head := UiKit.label(text, 20, color, "b", 4)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	head.custom_minimum_size = Vector2(0, 44)
	head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return head


## One chip per unlocked hero: the shown one is the gold primary, the rest
## secondary steel. Tapping is view-only and redraws the page; the save's
## featured hero is untouched.
func _build_armory_switch(current: String) -> void:
	for child in armory_switch.get_children():
		child.queue_free()
	for id in Catalog.playable_ids():
		if not bool(SaveGame.hero(str(id))["unlocked"]):
			continue
		var name := str(Catalog.critter(str(id)).get("name", id)).to_upper()
		var on := str(id) == current
		var button := UiKit.button(name, 150, 82) if on else UiKit.secondary(name, 150, 82)
		button.toggle_mode = true
		button.set_pressed_no_signal(on)
		button.pressed.connect(func() -> void: _pick_armory_hero(str(id)))
		armory_switch.add_child(button)


## The hero whose gear the Armory is showing.
func armory_view_id() -> String:
	if _armory_view != "" and SaveGame.data["heroes"].has(_armory_view) and bool(SaveGame.hero(_armory_view)["unlocked"]):
		return _armory_view
	return SaveGame.featured_id()


## View-only pick: records which hero the page shows and returns the new id.
## Unlocked heroes only. Never touches SaveGame.data["featured"].
func set_armory_view(id: String) -> String:
	if SaveGame.data["heroes"].has(id) and bool(SaveGame.hero(id)["unlocked"]):
		_armory_view = id
	return armory_view_id()


func _pick_armory_hero(id: String) -> void:
	if id == armory_view_id() or not bool(SaveGame.hero(id)["unlocked"]):
		return
	set_armory_view(id)
	AudioDirector.sfx("card_pick")
	AudioDirector.haptic("medium")
	_fill()


## {iron, steel, rune, total}: owned pieces per tier and how many each tier
## holds (one per slot), for the Armory header. No hero id is baked in; the
## hero's own slot list drives it.
static func armory_counts(hero: String) -> Dictionary:
	var slots: Array = GearDB.HERO_SLOTS.get(hero, [])
	var counts := {"iron": 0, "steel": 0, "rune": 0, "total": slots.size()}
	var owned: Dictionary = GearDB._store()["owned"].get(hero, {})
	for slot in slots:
		for tier in [GearDB.Tier.IRON, GearDB.Tier.STEEL, GearDB.Tier.RUNE]:
			var owns_any := false
			for oid in owned:
				if int(owned[oid]) > 0:
					var p := GearDB._parse_id(str(oid))
					if not p.is_empty() and p["slot"] == slot and int(p["tier"]) == tier:
						owns_any = true
						break
			if not owns_any:
				continue
			match tier:
				GearDB.Tier.IRON:
					counts["iron"] = int(counts["iron"]) + 1
				GearDB.Tier.STEEL:
					counts["steel"] = int(counts["steel"]) + 1
				GearDB.Tier.RUNE:
					counts["rune"] = int(counts["rune"]) + 1
	return counts


## Where a tier first drops, derived from LootTable.MAX_TIER_BY_DEPTH and
## Catalog.BIOMES: the shallowest biome where any source can roll the tier,
## plus " bosses" when only the deeper sources reach it (cursed rune plate).
static func drop_hint(tier: int) -> String:
	for depth in Catalog.BIOMES.size():
		var any := false
		var all := true
		for source in LootTable.MAX_TIER_BY_DEPTH:
			if LootTable.max_tier(str(source), depth) >= tier:
				any = true
			else:
				all = false
		if any:
			var name := str(Catalog.BIOMES[depth]["name"]).split(" ")[0]
			return "%s+" % name if all else "%s+ bosses" % name
	return ""


## "Defence 20" for the first level gate on an item, or "" when it has none.
static func _req_text(id: String) -> String:
	var req: Dictionary = GearDB.requirements(id)
	for k in GearDB.SKILL_KEYS:
		if req.has(k):
			return "%s %d" % [GearDB.SKILL_NAMES[GearDB.SKILL_KEYS.find(k)], int(req[k])]
	return ""


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


## One Armory cell: a hero's piece for a slot at a tier. Owned pieces sit in a
## gold frame with their real name; unowned pieces are dimmed with where they
## can drop and any level gate. No gear rendering.
class ArmoryCell extends PanelContainer:
	var owned := false
	var title := "?"
	var hint := ""
	var req := ""

	func _ready() -> void:
		add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		var fr: UiKit.Frame
		if owned:
			var metal := UiKit.rarity_metal("legendary")
			fr = UiKit.Frame.new("card", "leather", {
				"metal_hi": metal[0], "metal_lo": metal[1], "frame": 6.0,
				"glow_color": Color(1.0, 0.72, 0.32, 0.2),
				"face_top": Color("241b12"), "face_bot": Color("0c0907"),
			})
		else:
			fr = UiKit.Frame.new("slot", "grey", {"face_top": Color("14100d"), "face_bot": Color("0a0806")})
		fr.margin = 10.0
		add_child(fr)
		var face := ArmoryFace.new()
		face.cell = self
		add_child(face)


class ArmoryFace extends Control:
	var cell: ArmoryCell

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		UiKit.ensure()
		var w := size.x
		var pad := 12.0
		var ink := Color("fff1d6") if cell.owned else Color("8a7e6c")
		var fs := 20
		var tw := UiKit.font_b.get_string_size(cell.title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		while tw > w - pad * 2.0 and fs > 12:
			fs -= 1
			tw = UiKit.font_b.get_string_size(cell.title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string_outline(UiKit.font_b, Vector2(pad, 34), cell.title, HORIZONTAL_ALIGNMENT_LEFT, w - pad * 2.0, fs, 4, Color(0.03, 0.02, 0.01))
		draw_string(UiKit.font_b, Vector2(pad, 34), cell.title, HORIZONTAL_ALIGNMENT_LEFT, w - pad * 2.0, fs, ink)
		if cell.hint != "":
			draw_string(UiKit.font_b, Vector2(pad, 70), cell.hint, HORIZONTAL_ALIGNMENT_LEFT, w - pad * 2.0, 19, Color("b8aa94"))
		if cell.req != "":
			draw_string(UiKit.font_b, Vector2(pad, 98), cell.req, HORIZONTAL_ALIGNMENT_LEFT, w - pad * 2.0, 18, Color("d8a850"))
