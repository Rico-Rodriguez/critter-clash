extends RefCounted
## The Shop tab (Clash Royale's shop, paid in gold only): today's deals, the
## chest shelf, weapon glows and weapon skins. No class_name (see CLAUDE.md); lobby_ui.gd
## preloads it and passes itself in, so the cards can open sheets and chests.

const ItemIcons := preload("res://src/ui/item_icons.gd")
const GOLD := Color(1.0, 0.82, 0.4)
const FxUi := preload("res://src/ui/fx_ui.gd")
## Tile colors by rarity and by chest.
const RARITY_TILE := {"common": &"TileSlate", "magic": &"TileBlue", "rare": &"TileGold", "epic": &"TilePurple", "legendary": &"TileRed"}
const CHEST_TILE := {"silver": &"TileSlate", "gold": &"TileGold", "crypt": &"TileRed"}

## Gold before the last purchase; the next build counts down from it.
static var _spent_from := -1


static func build(ui, s: Sheet) -> void:
	Game.refresh_shop()
	var b := s.body
	var gold_row := HBoxContainer.new()
	gold_row.alignment = BoxContainer.ALIGNMENT_END
	gold_row.add_theme_constant_override("separation", 8)
	gold_row.add_child(Ui.icon_rect("two-coins", 34, GOLD))
	var gl := Ui.label(Ui.fmt_num(Game.gold()), "Value")
	gl.add_theme_font_size_override("font_size", 30)
	gold_row.add_child(gl)
	b.add_child(gold_row)
	# Back from a purchase: the gold counts down to what is left.
	if _spent_from >= 0:
		FxUi.count_to(gl, _spent_from, Game.gold(), 0.6)
		_spent_from = -1

	b.add_child(_heading("DAILY DEALS", "New in %s" % _until_midnight()))
	# The discounted chest is the day's headline, beside the free gift; the
	# rest of the deals sit two to a row under them.
	var deals := Game.shop_deals()
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	var grid := _grid(2)
	for i in deals.size():
		var d: Dictionary = deals[i]
		var card := _deal_card(ui, s, i, d, gl)
		if str(d["kind"]) == "chest":
			card.size_flags_stretch_ratio = 2.1
			top.add_child(card)
			if not bool(d["bought"]):
				_feature(card)
		elif int(d["price"]) == 0:
			top.add_child(card)
			top.move_child(card, 0)
		else:
			grid.add_child(card)
	b.add_child(top)
	b.add_child(grid)
	FxUi.deal_in(top, 0.06)
	FxUi.deal_in(grid, 0.06)

	b.add_child(_heading("CHESTS", "Gold, shards and gear"))
	var cg := _grid()
	var n := 0
	for k in DB.SHOP_CHESTS:
		cg.add_child(_chest_card(ui, k, n))
		n += 1
	b.add_child(cg)

	var hid := Game.hero_id()
	b.add_child(_heading("WEAPON GLOWS", "For the %s" % DB.HEROES[hid]["name"]))
	var gg := _grid()
	for g in DB.GLOW_ORDER:
		if DB.GLOWS[g].get("gift", false):
			continue
		gg.add_child(_glow_card(ui, s, hid, g))
	b.add_child(gg)

	var skins: Array = DB.WEAPON_SKIN_ORDER.filter(func(k): return hid in DB.WEAPON_SKINS[k]["heroes"])
	if not skins.is_empty():
		b.add_child(_heading("WEAPON SKINS", "For the %s" % DB.HEROES[hid]["name"]))
		var sg := _grid()
		for k: String in skins:
			sg.add_child(_skin_card(ui, s, hid, k))
		b.add_child(sg)


static func _heading(text: String, note: String) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_child(Ui.label(text, "Caption"))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(sp)
	h.add_child(Ui.label(note, "Small"))
	return h


static func _grid(columns := 3) -> GridContainer:
	var g := GridContainer.new()
	g.columns = columns
	g.add_theme_constant_override("h_separation", 12)
	g.add_theme_constant_override("v_separation", 12)
	return g


static func _until_midnight() -> String:
	var t := Time.get_time_dict_from_system()
	var left := 86400 - (int(t["hour"]) * 3600 + int(t["minute"]) * 60 + int(t["second"]))
	return "%dh %dm" % [left / 3600, (left % 3600) / 60]


## A shop tile in its rarity's color: art on top, a name and a line, the
## price on a green plate (slate once it is yours or sold), and a ribbon in
## the corner (-25%). `lit` sets the shine sweeping across it.
static func _card(art: Control, title: String, sub: String, price: String, tile: StringName, tag: String, lit: bool, dim: bool, coin := true) -> Button:
	var btn := Button.new()
	btn.theme_type_variation = tile
	btn.focus_mode = Control.FOCUS_NONE
	btn.custom_minimum_size = Vector2(0, 268)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 10
	v.offset_right = -10
	v.offset_top = 18
	v.offset_bottom = -16
	v.add_theme_constant_override("separation", 0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(v)
	var cc := CenterContainer.new()
	cc.custom_minimum_size = Vector2(0, 108)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cc.add_child(art)
	v.add_child(cc)
	var nm := Ui.label(title, "Value", HORIZONTAL_ALIGNMENT_CENTER)
	nm.add_theme_font_size_override("font_size", 22)
	nm.add_theme_constant_override("outline_size", 6)
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	v.add_child(nm)
	var sl := Ui.label(sub, "Small", HORIZONTAL_ALIGNMENT_CENTER)
	sl.add_theme_color_override("font_color", Color(1, 1, 1, 0.72))
	sl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	v.add_child(sl)
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(sp)
	var plate := PanelContainer.new()
	plate.theme_type_variation = &"PricePlate" if coin else &"OwnedPlate"
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pr := HBoxContainer.new()
	pr.alignment = BoxContainer.ALIGNMENT_CENTER
	pr.add_theme_constant_override("separation", 6)
	pr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if coin and price != "FREE":
		pr.add_child(Ui.icon_rect("two-coins", 26, GOLD))
	pr.add_child(Ui.label(price, "PriceLabel"))
	plate.add_child(pr)
	v.add_child(plate)
	if tag != "":
		var rb := PanelContainer.new()
		rb.theme_type_variation = &"Ribbon"
		rb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rb.add_child(Ui.label(tag, "BadgeLabel"))
		rb.anchor_left = 1.0
		rb.anchor_right = 1.0
		rb.offset_left = 8.0
		rb.offset_right = 8.0
		rb.offset_top = -10.0
		rb.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		rb.rotation_degrees = 6.0
		btn.add_child(rb)
	FxUi.gloss(btn, 16.0, 0.5 if lit else 0.0, 3.4, randf() * 3.0)
	if dim:
		btn.modulate = Color(0.62, 0.6, 0.62)
	return btn


## The day's headline deal: light turning behind its art, a bob, a shine.
static func _feature(card: Button) -> void:
	var cc: Control = card.get_child(0).get_child(0)
	var art: Control = cc.get_child(0)
	FxUi.rays(card, art, Color(1.0, 0.8, 0.4), 2.6, 0.45)
	FxUi.bob(art, 5.0, 2.6)
	FxUi.gloss(card, 16.0, 0.6, 3.0)


static func _deal_card(ui, s: Sheet, i: int, d: Dictionary, gold_label: Label) -> Button:
	var price := int(d["price"])
	var sold: bool = d["bought"]
	var art: Control
	var title := ""
	var sub := ""
	var tag := "" if price == 0 else "-%d%%" % int(round(100 * DB.SHOP_DEAL_OFF))
	var tile := &"TileGreen" if price == 0 else &"TileBlue"
	match str(d["kind"]):
		"gold":
			art = Ui.icon_rect("two-coins", 92, GOLD)
			title = Ui.fmt_num(int(d["amount"]))
			sub = "Gold"
		"shards":
			var hid := str(d["hero"])
			art = ui._portrait(hid, DB.HEROES[hid]["color"], 96)
			title = "%d shards" % int(d["amount"])
			sub = str(DB.HEROES[hid]["name"])
		"gear":
			var it: Dictionary = d["item"]
			art = ItemIcons.rect(it, 92, DB.gear_color(it))
			title = str(it["name"])
			sub = "%s · Tier %d" % [DB.RARITY_NAME[it["rarity"]], int(it.get("mat", 0)) + 1]
			tag = ""
			tile = RARITY_TILE.get(str(it["rarity"]), &"TileSlate")
		"chest":
			var c: Dictionary = DB.CHESTS[d["chest"]]
			art = Ui.icon_rect("locked-chest", 92, c["color"])
			title = str(c["name"])
			sub = "%d gear · %d shards" % [int(c["items"]), int(c["shards"])]
			tag = "-%d%%" % int(round(100 * DB.SHOP_CHEST_OFF))
			tile = CHEST_TILE.get(str(d["chest"]), &"TileSlate")
	var ptxt := "SOLD" if sold else ("FREE" if price == 0 else Ui.fmt_num(price))
	var btn := _card(art, title, sub, ptxt, tile, "" if sold else tag, price == 0 and not sold, sold, not sold)
	if price == 0 and not sold:
		FxUi.bob(art, 4.0, 2.2)
	btn.pressed.connect(func():
		if sold:
			Sfx.play("ui_error", -8.0)
			return
		if price == 0:
			# A gift needs no question.
			var from := Game.gold()
			Game.buy_deal(i)
			Sfx.play("coin", 0.0)
			# Gold flies to the counter and counts up; other gifts just pop.
			if Game.gold() > from:
				FxUi.coin_fly(ui.get_node("%Overlay"), btn.get_global_rect().get_center(), gold_label, 10)
				FxUi.count_to(gold_label, from, Game.gold(), 0.9)
				await btn.get_tree().create_timer(0.95).timeout
			ui.refresh()
			if is_instance_valid(s):
				s.rebuild()
			return
		_confirm(ui, s, d, i))
	return btn


static func _chest_card(ui, kind: String, n: int) -> Button:
	var c: Dictionary = DB.CHESTS[kind]
	var price := Game.shop_chest_price(kind)
	var art := Ui.icon_rect("locked-chest", 92, c["color"])
	var btn := _card(art, str(c["name"]).trim_suffix(" Chest"), "%d gear · %d shards" % [int(c["items"]), int(c["shards"])], Ui.fmt_num(price), CHEST_TILE.get(kind, &"TileSlate"), "", false, false)
	FxUi.bob(art, 4.0, 2.4, n * 0.4)
	btn.pressed.connect(func():
		_confirm(ui, null, {"kind": "chest", "chest": kind, "price": price}, -1))
	return btn


static func _glow_card(ui, s: Sheet, hid: String, g: String) -> Button:
	var gd: Dictionary = DB.GLOWS[g]
	var h := Game.hero(hid)
	var owned: bool = g in h.get("glows", [])
	var worn: bool = str(h.get("glow", "")) == g
	var price := Game.glow_price(g)
	var sale := price < int(gd["gold"])
	var col := Color(gd["color"], 1.0)
	var art: Control = ui._disc("dripping-sword", col, 92)
	var ptxt := "WORN" if worn else ("OWNED" if owned else Ui.fmt_num(price))
	var btn := _card(art, str(gd["name"]), "This week" if sale and not owned else "Weapon glow", ptxt, &"TilePurple", "-%d%%" % int(round(100 * DB.SHOP_GLOW_OFF)) if sale and not owned else "", worn, false, not owned)
	btn.pressed.connect(func():
		if owned:
			Game.set_glow(hid, "" if worn else g)
			Sfx.play("ui_toggle", -4.0)
			ui.lobby.show_hero(hid)
			s.rebuild()
			return
		_confirm(ui, s, {"kind": "glow", "glow": g, "hero": hid, "price": price}, -1))
	return btn


static func _skin_card(ui, s: Sheet, hid: String, k: String) -> Button:
	var sd: Dictionary = DB.WEAPON_SKINS[k]
	var h := Game.hero(hid)
	var owned: bool = k in h.get("skins", [])
	var worn: bool = str(h.get("skin", "")) == k
	var price := Game.skin_price(k)
	var art: Control = ui._disc(str(sd["icon"]), GOLD, 92)
	var ptxt := "WORN" if worn else ("OWNED" if owned else Ui.fmt_num(price))
	var btn := _card(art, str(sd["name"]), "Weapon skin", ptxt, &"TileGold", "", worn, false, not owned)
	btn.pressed.connect(func():
		if owned:
			Game.set_skin(hid, "" if worn else k)
			Sfx.play("ui_toggle", -4.0)
			ui.lobby.show_hero(hid)
			s.rebuild()
			return
		_confirm(ui, s, {"kind": "skin", "skin": k, "hero": hid, "price": price}, -1))
	return btn


## The are-you-sure sheet: what you get, what it costs, and Buy.
static func _confirm(ui, page: Sheet, d: Dictionary, i: int) -> void:
	Sfx.play("ui_tap", -4.0)
	var sh := Sheet.new()
	ui.get_node("%Overlay").add_child(sh)
	var title := "Buy"
	match str(d["kind"]):
		"shards":
			title = "%d %s shards" % [int(d["amount"]), DB.HEROES[d["hero"]]["name"]]
		"gear":
			title = str(d["item"]["name"])
		"chest":
			title = str(DB.CHESTS[d["chest"]]["name"])
		"glow":
			title = "%s glow" % DB.GLOWS[d["glow"]]["name"]
		"skin":
			title = str(DB.WEAPON_SKINS[d["skin"]]["name"])
	sh.open(title, func(cs: Sheet): _confirm_body(ui, page, cs, d, i), 0.6)


static func _confirm_body(ui, page: Sheet, cs: Sheet, d: Dictionary, i: int) -> void:
	var b := cs.body
	var price := int(d["price"])
	var lines := PackedStringArray()
	match str(d["kind"]):
		"shards":
			var h := Game.hero(str(d["hero"]))
			lines.append("Shards upgrade %s and rub XP lamps." % DB.HEROES[d["hero"]]["name"] if h["unlocked"] else "20 shards unlock %s (you have %d)." % [DB.HEROES[d["hero"]]["name"], int(h["shards"])])
		"gear":
			var it: Dictionary = d["item"]
			var cc := CenterContainer.new()
			cc.add_child(ItemIcons.rect(it, 120, DB.gear_color(it)))
			b.add_child(cc)
			var tag := Ui.label(Game.item_tag(it), "Small", HORIZONTAL_ALIGNMENT_CENTER)
			tag.add_theme_color_override("font_color", DB.gear_color(it))
			b.add_child(tag)
			lines.append_array(Game.describe_stats(it))
			var have := Game.owned(it)
			if not have.is_empty():
				lines.append("You own it (Lv %d): this is a copy toward its next level." % int(have.get("lv", 1)))
			var cur := Game.equipped(Game.hero_id(), str(it["slot"]))
			if not cur.is_empty():
				lines.append("Worn now: %s" % cur["name"])
		"chest":
			var c: Dictionary = DB.CHESTS[d["chest"]]
			lines.append("%d–%d gold, %d shards and %d pieces of gear." % [int(c["gold"][0]), int(c["gold"][1]), int(c["shards"]), int(c["items"])])
			lines.append("Opens right away.")
		"glow":
			lines.append("Your %s's weapon glows %s in every hunt." % [DB.HEROES[d["hero"]]["name"], str(DB.GLOWS[d["glow"]]["name"]).to_lower()])
			lines.append("Looks only: it changes no stats.")
		"skin":
			lines.append("Your %s carries the %s in camp and in every hunt." % [DB.HEROES[d["hero"]]["name"], DB.WEAPON_SKINS[d["skin"]]["name"]])
			lines.append("Looks only: your equipped weapon's stats still count.")
	for ln in lines:
		var l := Ui.label(ln, "Body", HORIZONTAL_ALIGNMENT_CENTER)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.add_child(l)
	var short := Game.gold() < price
	var block := Game.shop_block(i) if i >= 0 else ("Not enough gold" if short else "")
	var buy := Button.new()
	buy.theme_type_variation = &"PriceButton"
	buy.focus_mode = Control.FOCUS_NONE
	buy.custom_minimum_size = Vector2(0, 92)
	buy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buy.icon = Ui.icon("two-coins")
	buy.text = block if block != "" else "Buy  %s" % Ui.fmt_num(price)
	buy.disabled = block != ""
	if not buy.disabled:
		FxUi.gloss(buy, 14.0, 0.45, 2.8)
	buy.pressed.connect(func():
		match str(d["kind"]):
			"chest":
				cs.close()
				ui.open_bought_chest(str(d["chest"]), i)
				return
			"glow":
				if not Game.buy_glow(str(d["hero"]), str(d["glow"])):
					Sfx.play("ui_error", -6.0)
					return
				ui.lobby.show_hero(str(d["hero"]))
			"skin":
				if not Game.buy_skin(str(d["hero"]), str(d["skin"])):
					Sfx.play("ui_error", -6.0)
					return
				ui.lobby.show_hero(str(d["hero"]))
			_:
				if Game.buy_deal(i).is_empty():
					Sfx.play("ui_error", -6.0)
					return
		Sfx.play("coin", 0.0)
		ui.refresh()
		cs.close()
		if page and is_instance_valid(page):
			_spent_from = Game.gold() + price
			page.rebuild())
	cs.footer.add_child(buy)
