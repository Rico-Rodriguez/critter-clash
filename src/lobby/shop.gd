extends RefCounted
## The Shop tab (paid in gold only), one scroll top to bottom: today's gift,
## the deal of the day, the other deals, chests, then Skins (weapon skins and
## glows, the one place cosmetics are bought and put on). No class_name (see CLAUDE.md); lobby_ui.gd
## preloads it and passes itself in, so the cards can open sheets and chests.

const ItemIcons := preload("res://src/ui/item_icons.gd")
const GOLD := Color(1.0, 0.82, 0.4)
const PropIcons := preload("res://src/ui/prop_icons.gd")
const FxUi := preload("res://src/ui/fx_ui.gd")
const LookIcons := preload("res://src/ui/look_icons.gd")
const LookPreview := preload("res://src/lobby/look_preview.gd")
## Tile colors by rarity and by chest.
const RARITY_TILE := {"common": &"TileSlate", "magic": &"TileBlue", "rare": &"TileGold", "epic": &"TilePurple", "legendary": &"TileRed"}
const CHEST_TILE := {"silver": &"TileSlate", "gold": &"TileGold", "crypt": &"TileRed"}

## Each tile style's rim color, for the glow behind its art.
const TILE_COLOR := {&"TileSlate": Color("8d8578"), &"TileGreen": Color("6fd08a"), &"TileBlue": Color("5b8ee8"), &"TilePurple": Color("a970f0"), &"TileGold": Color("f3d58f"), &"TileRed": Color("e8705e")}

## Gold before the last purchase; the next build counts down from it.
static var _spent_from := -1
## The hero whose skins the Skins tab shows ("" = the hero in use).
static var skins_hero := ""

## Where the Skins section starts, so the hero screen's Skins button can land on it.
static var _skins_at: Control


## One page, no tabs: every section is a scroll away and nothing hides.
static func segments(ui) -> Array:
	return [["Shop", func(s: Sheet): build(ui, s)]]


static func build(ui, s: Sheet) -> void:
	var gl := _gold_row(s.body, "")
	build_deals(ui, s, gl)
	build_chests(ui, s)
	build_skins(ui, s)


## Scrolls `page` so the Skins section sits at the top, once it has a layout.
static func focus_skins(page: Sheet) -> void:
	for i in 2:
		await page.get_tree().process_frame
	if is_instance_valid(page) and is_instance_valid(_skins_at):
		page._scroll.scroll_vertical = int(_skins_at.global_position.y - page._scroll.global_position.y) + page._scroll.scroll_vertical - 8


## The gold you hold, top right; after a purchase it counts down.
static func _gold_row(b: VBoxContainer, note: String) -> Label:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var nl := Ui.label(note, "Small")
	nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(nl)
	row.add_child(Ui.icon_rect("two-coins", 30, GOLD))
	var gl := Ui.label(Ui.fmt_num(Game.gold()), "Value")
	gl.add_theme_font_size_override("font_size", 28)
	row.add_child(gl)
	b.add_child(row)
	if _spent_from >= 0:
		FxUi.count_to(gl, _spent_from, Game.gold(), 0.6)
		_spent_from = -1
	return gl


## Deals: today's free gift, one spotlighted deal (the discounted chest), and
## the rest two to a row.
static func build_deals(ui, s: Sheet, gl: Label) -> void:
	Game.refresh_shop()
	var b := s.body
	var deals := Game.shop_deals()
	var grid := _grid(2)
	for i in deals.size():
		var d: Dictionary = deals[i]
		if int(d["price"]) == 0:
			b.add_child(_gift_strip(ui, s, i, d, gl))
		elif str(d["kind"]) == "chest":
			b.add_child(_feature_card(ui, s, i, d))
		else:
			grid.add_child(_deal_card(ui, s, i, d, gl))
	b.add_child(_heading("DAILY DEALS", "New in %s" % _until_midnight(), true))
	b.add_child(grid)
	FxUi.deal_in(grid, 0.06)


## Chests: each with what it holds, bought and opened on the spot.
static func build_chests(ui, s: Sheet) -> void:
	var b := s.body
	b.add_child(_heading("CHESTS", "Opens right away", true))
	var cg := _grid()
	var n := 0
	for k in DB.SHOP_CHESTS:
		cg.add_child(_chest_card(ui, k, n))
		n += 1
	b.add_child(cg)
	FxUi.deal_in(cg, 0.08)


## Skins: pick a hero, then their weapon skins and glows. The only place
## cosmetics are bought and put on (the hero screen's Skins button opens it).
static func build_skins(ui, s: Sheet) -> void:
	var b := s.body
	var hid := skins_hero if skins_hero != "" and Game.hero(skins_hero)["unlocked"] else Game.hero_id()
	_skins_at = _heading("SKINS", "Looks only, never stats", true)
	b.add_child(_skins_at)
	var heroes := HBoxContainer.new()
	heroes.add_theme_constant_override("separation", 12)
	for id in DB.HERO_ORDER:
		if not Game.hero(id)["unlocked"]:
			continue
		var hb := Button.new()
		hb.theme_type_variation = &"Choice"
		hb.toggle_mode = true
		hb.button_pressed = id == hid
		hb.focus_mode = Control.FOCUS_NONE
		hb.custom_minimum_size = Vector2(96, 96)
		var cc := CenterContainer.new()
		cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cc.add_child(ui._portrait(id, DB.HEROES[id]["color"], 76))
		hb.add_child(cc)
		var hero_id: String = id
		hb.pressed.connect(func():
			skins_hero = hero_id
			Sfx.play("ui_toggle", -6.0)
			s.rebuild())
		heroes.add_child(hb)
	b.add_child(heroes)
	var nm := Ui.label(str(DB.HEROES[hid]["name"]).to_upper(), "Caption")
	nm.add_theme_font_size_override("font_size", 22)
	nm.add_theme_color_override("font_color", Color("f6e7c4"))
	b.add_child(nm)
	var outfits: Array = DB.OUTFIT_ORDER.filter(func(k): return hid in DB.OUTFITS[k]["heroes"] and (not DB.OUTFITS[k].get("gift", false) or k in Game.hero(hid)["outfits"]))
	if not outfits.is_empty():
		b.add_child(_heading("OUTFITS", "Dye for the whole look"))
		var og := _grid()
		for k: String in outfits:
			og.add_child(_outfit_card(ui, s, hid, k))
		b.add_child(og)
		FxUi.deal_in(og, 0.05)
	var skins: Array = DB.WEAPON_SKIN_ORDER.filter(func(k): return hid in DB.WEAPON_SKINS[k]["heroes"])
	if not skins.is_empty():
		b.add_child(_heading("WEAPON SKINS", ""))
		var sg := _grid()
		for k: String in skins:
			sg.add_child(_skin_card(ui, s, hid, k))
		b.add_child(sg)
		FxUi.deal_in(sg, 0.05)
	b.add_child(_heading("WEAPON GLOWS", ""))
	var gg := _grid()
	for g in DB.GLOW_ORDER:
		if DB.GLOWS[g].get("gift", false) and not g in Game.hero(hid).get("glows", []):
			continue
		gg.add_child(_glow_card(ui, s, hid, g))
	b.add_child(gg)
	FxUi.deal_in(gg, 0.05)


## A row title; `big` marks the start of a section (Deals, Chests, Skins), with
## a hairline above so the one long page still reads as parts.
static func _heading(text: String, note: String, big := false) -> Control:
	var h := HBoxContainer.new()
	var t := Ui.label(text, "Caption")
	if big:
		t.add_theme_font_size_override("font_size", 24)
		t.add_theme_color_override("font_color", Color("f6e7c4"))
	h.add_child(t)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(sp)
	if note != "":
		h.add_child(Ui.label(note, "Small"))
	if not big:
		return h
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	var line := ColorRect.new()
	line.color = Color(GOLD, 0.22)
	line.custom_minimum_size = Vector2(0, 1)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(Control.new())
	v.add_child(line)
	v.add_child(h)
	return v


static func _grid(columns := 3) -> GridContainer:
	var g := GridContainer.new()
	g.columns = columns
	g.add_theme_constant_override("h_separation", 14)
	g.add_theme_constant_override("v_separation", 14)
	return g


static func _until_midnight() -> String:
	var t := Time.get_time_dict_from_system()
	var left := 86400 - (int(t["hour"]) * 3600 + int(t["minute"]) * 60 + int(t["second"]))
	return "%dh %dm" % [left / 3600, (left % 3600) / 60]


## A shop tile: a dark card edged in its rarity's color, the art glowing in
## that color, a name, a line in the color, and the price on a gold-trimmed
## tag (a faint one once it is yours or sold). A discount sits in the corner.
static func _card(art: Control, title: String, sub: String, price: String, tile: StringName, tag: String, lit: bool, dim: bool, coin := true) -> Button:
	var col: Color = TILE_COLOR.get(tile, GOLD)
	var btn := Button.new()
	btn.theme_type_variation = tile
	btn.focus_mode = Control.FOCUS_NONE
	btn.custom_minimum_size = Vector2(0, 250)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 12
	v.offset_right = -12
	v.offset_top = 16
	v.offset_bottom = -14
	v.add_theme_constant_override("separation", 2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(v)
	var cc := CenterContainer.new()
	cc.custom_minimum_size = Vector2(0, 104)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cc.add_child(art)
	v.add_child(cc)
	FxUi.halo(btn, art, col, 1.7)
	var nm := Ui.label(title, "Value", HORIZONTAL_ALIGNMENT_CENTER)
	nm.add_theme_font_size_override("font_size", 21 if title.length() <= 12 else 18)
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	v.add_child(nm)
	var sl := Ui.label(sub, "Small", HORIZONTAL_ALIGNMENT_CENTER)
	sl.add_theme_color_override("font_color", col.lerp(Color.WHITE, 0.25))
	sl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	v.add_child(sl)
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(sp)
	v.add_child(_price_tag(price, coin))
	if tag != "":
		var tl := Ui.label(tag, "RibbonLabel", HORIZONTAL_ALIGNMENT_RIGHT)
		tl.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		tl.offset_left = -110
		tl.offset_right = -12
		tl.offset_top = 10
		btn.add_child(tl)
	FxUi.gloss(btn, 12.0, 0.3 if lit else 0.0, 4.0, randf() * 3.0)
	if dim:
		btn.modulate = Color(0.6, 0.58, 0.6)
	return btn


## A price on a gold-trimmed tag; `coin` false gives the faint owned tag.
static func _price_tag(price: String, coin := true) -> PanelContainer:
	var plate := PanelContainer.new()
	plate.theme_type_variation = &"PricePlate" if coin else &"OwnedPlate"
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pr := HBoxContainer.new()
	pr.alignment = BoxContainer.ALIGNMENT_CENTER
	pr.add_theme_constant_override("separation", 6)
	pr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if coin and price != "FREE":
		pr.add_child(Ui.icon_rect("two-coins", 22, GOLD))
	var pl := Ui.label(price, "PriceLabel")
	if not coin:
		pl.add_theme_font_override("font", (pl.get_theme_font("font", "RibbonLabel")))
		pl.add_theme_font_size_override("font_size", 16)
	pr.add_child(pl)
	plate.add_child(pr)
	return plate


## Today's free gift: a slim strip with a Claim button, or a note once taken.
static func _gift_strip(ui, s: Sheet, i: int, d: Dictionary, gold_label: Label) -> PanelContainer:
	var c := PanelContainer.new()
	c.theme_type_variation = &"Card"
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	c.add_child(h)
	var art: Control = _deal_art(ui, d, 64)
	h.add_child(art)
	var tv := VBoxContainer.new()
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.add_theme_constant_override("separation", 0)
	tv.alignment = BoxContainer.ALIGNMENT_CENTER
	tv.add_child(Ui.label("TODAY'S GIFT", "Caption"))
	tv.add_child(Ui.label(_deal_title(d), "Value"))
	h.add_child(tv)
	if bool(d["bought"]):
		h.add_child(Ui.label("Back tomorrow", "Small"))
		c.modulate = Color(0.7, 0.68, 0.7)
		return c
	var claim := Button.new()
	claim.theme_type_variation = &"PrimaryButton"
	claim.text = "Claim"
	claim.focus_mode = Control.FOCUS_NONE
	claim.custom_minimum_size = Vector2(150, 64)
	claim.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	claim.add_theme_font_size_override("font_size", 22)
	FxUi.gloss(claim, 12.0, 0.45, 3.0)
	claim.pressed.connect(func():
		var from := Game.gold()
		Game.buy_deal(i)
		Sfx.play("coin", 0.0)
		# Gold flies to the counter and counts up; other gifts just pop.
		if Game.gold() > from:
			FxUi.coin_fly(ui.get_node("%Overlay"), claim.get_global_rect().get_center(), gold_label, 10)
			FxUi.count_to(gold_label, from, Game.gold(), 0.9)
			await claim.get_tree().create_timer(0.95).timeout
		ui.refresh()
		if is_instance_valid(s):
			s.rebuild())
	h.add_child(claim)
	return c


## The spotlighted deal: the art turning in light on the left, the name, the
## old price struck through and the new one on the right.
static func _feature_card(ui, s: Sheet, i: int, d: Dictionary) -> Button:
	var price := int(d["price"])
	var sold: bool = d["bought"]
	var c: Dictionary = DB.CHESTS[d["chest"]]
	var btn := Button.new()
	btn.theme_type_variation = &"TileGold"
	btn.focus_mode = Control.FOCUS_NONE
	btn.custom_minimum_size = Vector2(0, 290)
	var h := HBoxContainer.new()
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 18
	h.offset_right = -22
	h.offset_top = 16
	h.offset_bottom = -18
	h.add_theme_constant_override("separation", 18)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(h)
	var cc := CenterContainer.new()
	cc.custom_minimum_size = Vector2(250, 0)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var art := PropIcons.chest(str(d["chest"]), 170)
	cc.add_child(art)
	h.add_child(cc)
	var tv := VBoxContainer.new()
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.alignment = BoxContainer.ALIGNMENT_CENTER
	tv.add_theme_constant_override("separation", 4)
	tv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(tv)
	tv.add_child(Ui.label("DEAL OF THE DAY", "Caption"))
	var nm := Ui.label(str(c["name"]), "Heading")
	nm.add_theme_color_override("font_color", Color("f6e7c4"))
	tv.add_child(nm)
	tv.add_child(Ui.label("%d gear · %d shards" % [int(c["items"]), int(c["shards"])], "Small"))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 10)
	tv.add_child(gap)
	if sold:
		tv.add_child(_price_tag("SOLD", false))
		btn.modulate = Color(0.62, 0.6, 0.62)
	else:
		# Said in words: "1100 −30%" read as one number with a dash.
		var was := Ui.label("Was %s · %d%% off" % [Ui.fmt_num(Game.shop_chest_price(str(d["chest"]))), int(round(100 * DB.SHOP_CHEST_OFF))], "Small")
		was.add_theme_color_override("font_color", Color("9a8f7c"))
		tv.add_child(was)
		tv.add_child(_price_tag(Ui.fmt_num(price)))
		FxUi.rays(btn, art, Color(1.0, 0.82, 0.45), 1.9, 0.3)
		FxUi.halo(btn, art, c["color"], 1.6)
		FxUi.bob(art, 4.0, 2.6)
		FxUi.gloss(btn, 12.0, 0.35, 4.2)
	btn.pressed.connect(func():
		if sold:
			Sfx.play("ui_error", -8.0)
			return
		_confirm(ui, s, d, i))
	return btn


static func _deal_art(ui, d: Dictionary, size_: float) -> Control:
	match str(d["kind"]):
		"gold":
			return Ui.icon_rect("two-coins", size_, GOLD)
		"shards":
			var hid := str(d["hero"])
			return ui._portrait(hid, DB.HEROES[hid]["color"], size_)
		"gear":
			var it: Dictionary = d["item"]
			return ItemIcons.rect(it, size_, DB.gear_color(it))
		"chest":
			return PropIcons.chest(str(d["chest"]), size_)
	return Control.new()


static func _deal_title(d: Dictionary) -> String:
	match str(d["kind"]):
		"gold":
			return "%s gold" % Ui.fmt_num(int(d["amount"]))
		"shards":
			return "%d %s shards" % [int(d["amount"]), DB.HEROES[str(d["hero"])]["name"]]
		"gear":
			return str(d["item"]["name"])
		"chest":
			return str(DB.CHESTS[d["chest"]]["name"])
	return ""


static func _deal_card(ui, s: Sheet, i: int, d: Dictionary, _gold_label: Label) -> Button:
	var price := int(d["price"])
	var sold: bool = d["bought"]
	var art := _deal_art(ui, d, 92)
	var sub := ""
	var tag := "−%d%%" % int(round(100 * DB.SHOP_DEAL_OFF))
	var tile := &"TileBlue"
	var title := _deal_title(d)
	match str(d["kind"]):
		"shards":
			title = "%d shards" % int(d["amount"])
			sub = str(DB.HEROES[str(d["hero"])]["name"])
		"gear":
			var it: Dictionary = d["item"]
			sub = "%s · Tier %d" % [DB.RARITY_NAME[it["rarity"]], int(it.get("mat", 0)) + 1]
			tag = ""
			tile = RARITY_TILE.get(str(it["rarity"]), &"TileSlate")
	var btn := _card(art, title, sub, "SOLD" if sold else Ui.fmt_num(price), tile, "" if sold else tag, false, sold, not sold)
	btn.pressed.connect(func():
		if sold:
			Sfx.play("ui_error", -8.0)
			return
		_confirm(ui, s, d, i))
	return btn


static func _chest_card(ui, kind: String, n: int) -> Button:
	var c: Dictionary = DB.CHESTS[kind]
	var price := Game.shop_chest_price(kind)
	var art := PropIcons.chest(kind, 110)
	var btn := _card(art, str(c["name"]).trim_suffix(" Chest"), "%d gear · %d shards" % [int(c["items"]), int(c["shards"])], Ui.fmt_num(price), CHEST_TILE.get(kind, &"TileSlate"), "", false, false)
	btn.custom_minimum_size.y = 290
	FxUi.bob(art, 3.0, 2.6, n * 0.4)
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
	var art: Control = Ui.icon_rect("dripping-sword", 84, col.lerp(Color.WHITE, 0.2))
	var ptxt := "EQUIPPED" if worn else ("EQUIP" if owned else Ui.fmt_price(price))
	var btn := _card(art, str(gd["name"]), "Weapon glow", ptxt, &"TilePurple", "−%d%%" % int(round(100 * DB.SHOP_GLOW_OFF)) if sale and not owned else "", worn, false, not owned)
	btn.pressed.connect(func():
		if owned:
			Game.set_glow(hid, "" if worn else g)
			Sfx.play("ui_toggle", -4.0)
			ui.lobby.show_hero(Game.hero_id())
			s.rebuild()
			return
		_confirm(ui, s, {"kind": "glow", "glow": g, "hero": hid, "price": price}, -1))
	return btn


static func _outfit_card(ui, s: Sheet, hid: String, k: String) -> Button:
	var od: Dictionary = DB.OUTFITS[k]
	var h := Game.hero(hid)
	var owned: bool = k in h.get("outfits", [])
	var worn: bool = str(h.get("outfit", "")) == k
	var price := Game.outfit_price(k)
	var art := LookIcons.rect(hid, {"outfit": k}, 96, str(DB.HEROES[hid]["icon"]), Color(od["dye"]).lightened(0.25))
	var ptxt := "EQUIPPED" if worn else ("EQUIP" if owned else Ui.fmt_price(price))
	var tag := "Season outfit" if od.get("gift", false) else "Outfit"
	var btn := _card(art, str(od["name"]), tag, ptxt, &"TileBlue", "", worn, false, not owned)
	btn.pressed.connect(func():
		if owned:
			Game.set_outfit(hid, "" if worn else k)
			Sfx.play("ui_toggle", -4.0)
			ui.lobby.show_hero(Game.hero_id())
			Portraits.rebuild(ui, hid)
			s.rebuild()
			return
		_confirm(ui, s, {"kind": "outfit", "outfit": k, "hero": hid, "price": price}, -1))
	return btn


static func _skin_card(ui, s: Sheet, hid: String, k: String) -> Button:
	var sd: Dictionary = DB.WEAPON_SKINS[k]
	var h := Game.hero(hid)
	var owned: bool = k in h.get("skins", [])
	var worn: bool = str(h.get("skin", "")) == k
	var price := Game.skin_price(k)
	var art := LookIcons.rect(hid, {"skin": k}, 96, str(sd["icon"]), Color("f6e3b4"))
	var ptxt := "EQUIPPED" if worn else ("EQUIP" if owned else Ui.fmt_price(price))
	var btn := _card(art, str(sd["name"]), "Weapon skin", ptxt, &"TileGold", "", worn, false, not owned)
	btn.pressed.connect(func():
		if owned:
			Game.set_skin(hid, "" if worn else k)
			Sfx.play("ui_toggle", -4.0)
			ui.lobby.show_hero(Game.hero_id())
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
		"outfit":
			title = str(DB.OUTFITS[d["outfit"]]["name"])
	sh.open(title, func(cs: Sheet): _confirm_body(ui, page, cs, d, i), 0.85 if str(d["kind"]) in ["outfit", "skin"] else 0.6)


static func _confirm_body(ui, page: Sheet, cs: Sheet, d: Dictionary, i: int) -> void:
	var b := cs.body
	var price := int(d["price"])
	var lines := PackedStringArray()
	match str(d["kind"]):
		"shards":
			var h := Game.hero(str(d["hero"]))
			lines.append("Shards buy %s's Super ranks." % DB.HEROES[d["hero"]]["name"] if h["unlocked"] else "20 shards unlock %s (you have %d)." % [DB.HEROES[d["hero"]]["name"], int(h["shards"])])
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
		"outfit":
			var cp := CenterContainer.new()
			cp.add_child(LookPreview.make(str(d["hero"]), {"outfit": str(d["outfit"])}))
			b.add_child(cp)
			lines.append("Your %s wears the %s outfit in camp and in every hunt." % [DB.HEROES[d["hero"]]["name"], DB.OUTFITS[d["outfit"]]["name"]])
			lines.append("Looks only: the gear you wear still counts.")
		"skin":
			var cs2 := CenterContainer.new()
			cs2.add_child(LookPreview.make(str(d["hero"]), {"skin": str(d["skin"])}))
			b.add_child(cs2)
			lines.append("Your %s carries the %s in camp and in every hunt." % [DB.HEROES[d["hero"]]["name"], DB.WEAPON_SKINS[d["skin"]]["name"]])
			lines.append("Looks only: your equipped weapon's stats still count.")
	for ln in lines:
		var l := Ui.label(ln, "Body", HORIZONTAL_ALIGNMENT_CENTER)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.add_child(l)
	var short := Game.gold() < price
	var block := Game.shop_block(i) if i >= 0 else ("Not enough gold" if short else "")
	var buy := Button.new()
	# Gold when it can be bought, like every other main action; a dark price tag when not.
	buy.theme_type_variation = &"PriceButton" if block != "" else &"GoldButton"
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
			"outfit":
				if not Game.buy_outfit(str(d["hero"]), str(d["outfit"])):
					Sfx.play("ui_error", -6.0)
					return
				ui.lobby.show_hero(str(d["hero"]))
				Portraits.rebuild(ui, str(d["hero"]))
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
