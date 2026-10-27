extends Control
## Opening a chest in camp. Tap and the chest rattles harder and harder while
## light gathers behind it, then it bursts: a flash, a ring and a shake. Each
## reward is dealt face-down as a card whose edge glow hints its rarity; tap
## to flip it. Better cards get a bigger reveal (a flash, a banner, a longer
## wind-up). Cards drop into a tray as you go; the last tap shows them all and
## sends the gold, gems and the rest flying into their counters.

const ItemIcons := preload("res://src/ui/item_icons.gd")
const FxUi := preload("res://src/ui/fx_ui.gd")
const SKDB := preload("res://src/data/sidekick_db.gd")

## 0..4, how special a reward looks. Names are only shown from RARE up.
const TIER_NAME := ["COMMON", "MAGIC", "RARE", "EPIC", "LEGENDARY"]
const CARD_SIZE := Vector2(480, 560)

## Set by screenshots to show every kind of reward without waiting for luck.
static var forced_rewards: Array = []

var ui: LobbyUI
var kind := ""
## -2 for a chest won in a hunt; else bought in the Shop (Game.buy_chest's deal).
var deal := -2
var rewards: Array = []
var idx := -1
var stage := "closed"

var _hint: Label
var _holder: Control
var _scrim: ColorRect
var _rays: TierReveal.Rays
var _flash: ColorRect
var _ring: Ring
var _tray: HBoxContainer
var _slots: Array[PanelContainer] = []
var _bar: MarginContainer
var _gold_chip: PanelContainer
var _gold_label: Label
var _gem_chip: PanelContainer
var _gem_label: Label
var _skip: Button
var _card: Control
var _front: Control
var _back: Control
var _chest_col := Color.WHITE
var _gold0 := 0
var _gems0 := 0
## Bumped when the player skips ahead, so the animation in flight stops itself.
var _gen := 0


func open(u: LobbyUI, k: String) -> void:
	ui = u
	kind = k
	_chest_col = DB.CHESTS[kind]["color"]
	_gold0 = Game.gold()
	_gems0 = _gems_now()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_scrim = ColorRect.new()
	_scrim.color = Color(0.0, 0.0, 0.02, 0.35)
	_scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_scrim)
	_rays = TierReveal.Rays.new()
	_rays.color = _chest_col
	_rays.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rays.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rays)
	FxUi.add_motes(self, Color(_chest_col, 0.5), 16, 40.0)
	_holder = Control.new()
	_holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_holder)
	_build_bar()
	_ring = Ring.new()
	_ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ring)
	_flash = ColorRect.new()
	_flash.color = Color(1, 1, 1, 0)
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)
	_hint = Ui.label("Tap to open your %s" % DB.CHESTS[kind]["name"], "HudTitle", HORIZONTAL_ALIGNMENT_CENTER)
	_hint.add_theme_font_size_override("font_size", 34)
	ui.lobby.center_chest()
	_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_hint.offset_top = -260.0
	_hint.offset_bottom = -200.0
	add_child(_hint)
	FxUi.pulse(_hint, 1.05, 1.1)
	# The chest's light waits behind it, dim, until the first tap.
	var t := create_tween().set_parallel(true)
	t.tween_property(_rays, "reach", 300.0, 0.7).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(_rays, "alpha", 0.16, 0.7)
	Sfx.play("chest_rattle", 0.0)


func _gems_now() -> int:
	return int(Game.data.get("gems", 0))


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		_tap()


func _tap() -> void:
	match stage:
		"closed":
			_charge()
		"facedown":
			_flip()
		"revealed":
			_next_card()
		"summary":
			_collect()


# --- Top bar: what you have, which the rewards count up into ---------------

func _build_bar() -> void:
	_bar = MarginContainer.new()
	_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Ui.apply_safe_area(_bar, 20)
	_bar.add_theme_constant_override("margin_top", int(Ui.safe_insets(0).y) + 14)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 10)
	_bar.add_child(row)
	_skip = Button.new()
	_skip.theme_type_variation = "Ghost"
	_skip.text = "Skip ›"
	_skip.focus_mode = Control.FOCUS_NONE
	_skip.custom_minimum_size = Vector2(120, 62)
	_skip.modulate.a = 0.0
	_skip.disabled = true
	_skip.pressed.connect(_skip_ahead)
	row.add_child(_skip)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(sp)
	var g := _chip("two-coins", Color(1.0, 0.84, 0.4), _gold0)
	_gold_chip = g[0]
	_gold_label = g[1]
	row.add_child(_gold_chip)
	var gm := _chip("gems", Color(0.55, 0.9, 1.0), _gems0)
	_gem_chip = gm[0]
	_gem_label = gm[1]
	_gem_chip.visible = _gems0 > 0
	row.add_child(_gem_chip)
	add_child(_bar)


func _chip(icon: String, tint: Color, amount: int) -> Array:
	var chip := PanelContainer.new()
	chip.theme_type_variation = "Chip"
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(Ui.icon_rect(icon, 30, tint))
	var l := Ui.label(Ui.fmt_num(amount), "Value")
	l.add_theme_font_size_override("font_size", 24)
	l.add_theme_color_override("font_color", tint.lightened(0.3))
	h.add_child(l)
	chip.add_child(h)
	return [chip, l]


# --- The chest: build-up, then the burst -----------------------------------

func _charge() -> void:
	stage = "charging"
	var g := _gen
	Sfx.play("chest_rattle", 0.0)
	Sfx.play("charge", -2.0)
	_hint.text = ""
	FxUi.still(_hint)
	ui.lobby.charge_chest(1.1)
	var t := create_tween().set_parallel(true)
	t.tween_property(_scrim, "color:a", 0.72, 1.1)
	t.tween_property(_rays, "reach", 560.0, 1.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(_rays, "alpha", 0.5, 1.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	# The overlay trembles with it: a little, then a lot.
	t.tween_method(func(v: float) -> void: position = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 7.0 * v * v, 0.0, 1.0, 1.1)
	await get_tree().create_timer(1.1).timeout
	if g != _gen:
		return
	position = Vector2.ZERO
	_burst_open()


func _burst_open() -> void:
	stage = "opening"
	var g := _gen
	rewards = forced_rewards if not forced_rewards.is_empty() else (Game.open_chest(kind) if deal == -2 else Game.buy_chest(kind, deal))
	ui.lobby.open_chest_fx()
	Sfx.play("chest_open", 0.0)
	Sfx.play("boom", -4.0)
	Ui.buzz(40, 0.6)
	_flash_screen(Color(1, 1, 0.92), 0.95, 0.55)
	_shake(14.0, 0.45)
	var c := get_viewport_rect().size * Vector2(0.5, 0.5)
	_ring.fire(c, _chest_col.lightened(0.5), 700.0, 0.7)
	_spray(c, _chest_col.lightened(0.4), 40, 520.0)
	var t := create_tween().set_parallel(true)
	t.tween_property(_rays, "reach", 900.0, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(_rays, "alpha", 0.7, 0.2)
	t.chain().tween_property(_rays, "alpha", 0.22, 0.8)
	_build_tray()
	_skip.disabled = false
	create_tween().tween_property(_skip, "modulate:a", 1.0, 0.3).set_delay(0.5)
	await get_tree().create_timer(0.7).timeout
	if g != _gen:
		return
	_deal(0)


func _build_tray() -> void:
	_tray = HBoxContainer.new()
	_tray.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tray.add_theme_constant_override("separation", 10)
	_tray.alignment = BoxContainer.ALIGNMENT_CENTER
	_tray.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_tray.offset_top = Ui.safe_insets(0).y + 110.0
	_tray.offset_bottom = _tray.offset_top + 56.0
	add_child(_tray)
	for i in rewards.size():
		var s := PanelContainer.new()
		s.custom_minimum_size = Vector2(52, 52)
		s.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var st := StyleBoxFlat.new()
		st.bg_color = Color(0.05, 0.045, 0.07, 0.8)
		st.set_corner_radius_all(26)
		st.set_border_width_all(2)
		st.border_color = Color(1, 1, 1, 0.18)
		s.add_theme_stylebox_override("panel", st)
		_tray.add_child(s)
		_slots.append(s)
	_tray.modulate.a = 0.0
	create_tween().tween_property(_tray, "modulate:a", 1.0, 0.4)


# --- Cards ------------------------------------------------------------------

## How special a reward looks, 0..4.
func _tier(r: Dictionary) -> int:
	match str(r["type"]):
		"item":
			var rar := str(r["item"].get("rarity", "common"))
			return int({"common": 0, "magic": 1, "rare": 2, "epic": 3, "legendary": 4}.get(rar, 0))
		"gems":
			return 1
		"egg":
			var rr := str(SKDB.EGGS[r["egg"]].get("rarity", "common"))
			return {"common": 0, "rare": 2, "bred": 2, "epic": 3, "exotic": 4}.get(rr, 1)
		"unlock":
			return 4
		"gold":
			return 1 if int(r["amount"]) >= 500 else 0
	return 0


func _tier_color(r: Dictionary, tier: int) -> Color:
	if tier >= 4:
		return Color(1.0, 0.78, 0.3)
	if tier == 3:
		return Color(0.75, 0.48, 1.0)
	if str(r["type"]) == "item":
		return DB.gear_color(r["item"])
	return _card_look(r)["col"]


func _deal(i: int) -> void:
	idx = i
	var g := _gen
	if idx >= rewards.size():
		_summary()
		return
	var r: Dictionary = rewards[idx]
	var tier := _tier(r)
	var col := _tier_color(r, tier)
	stage = "dealing"
	Ui.clear(_holder)
	var vp := get_viewport_rect().size
	_card = Control.new()
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.size = CARD_SIZE
	_front = _reward_card(r, tier, col)
	_front.size = CARD_SIZE
	_front.visible = false
	_back = _card_back(tier, col)
	_back.size = CARD_SIZE
	_card.add_child(_front)
	_card.add_child(_back)
	_holder.add_child(_card)
	_card.pivot_offset = CARD_SIZE * 0.5
	var rest := Vector2(vp.x * 0.5 - CARD_SIZE.x * 0.5, vp.y * 0.5 - CARD_SIZE.y * 0.5 - 100.0)
	# It leaps out of the chest: from low and small, with a turn, to the middle.
	_card.position = Vector2(rest.x, rest.y + 420.0)
	_card.scale = Vector2.ONE * 0.25
	_card.rotation_degrees = -14.0 if idx % 2 == 0 else 14.0
	_card.modulate.a = 0.0
	Sfx.play("card_pick", -2.0, 1.0 + minf(idx * 0.04, 0.3))
	var t := create_tween().set_parallel(true).set_ease(Tween.EASE_OUT)
	t.tween_property(_card, "position", rest, 0.5).set_trans(Tween.TRANS_BACK)
	t.tween_property(_card, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BACK)
	t.tween_property(_card, "rotation_degrees", 0.0, 0.5).set_trans(Tween.TRANS_BACK)
	t.tween_property(_card, "modulate:a", 1.0, 0.18)
	# The light behind turns toward this card's color.
	t.tween_property(_rays, "color", col if tier > 0 else _chest_col, 0.4)
	_hint.text = ""
	await t.finished
	if g != _gen or not is_instance_valid(_card):
		return
	# Better cards make you wait a beat: the back trembles and glows.
	if tier >= 3:
		Sfx.play("charge", -6.0)
		_hint.text = ""
		var tr := create_tween()
		for k in 10:
			tr.tween_property(_card, "rotation_degrees", (4.0 if k % 2 == 0 else -4.0) * (0.4 + k * 0.1), 0.05)
		tr.tween_property(_card, "rotation_degrees", 0.0, 0.05)
		await tr.finished
		if g != _gen or not is_instance_valid(_card):
			return
	elif tier == 2:
		FxUi.pulse(_card, 1.04, 0.7)
	stage = "facedown"
	_hint.text = "%d / %d · tap to flip" % [idx + 1, rewards.size()]
	FxUi.pulse(_hint, 1.05, 1.1)


## The face-down side: the edge carries the color, the middle stays a mystery.
func _card_back(tier: int, col: Color) -> Control:
	var p := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.09, 0.08, 0.13)
	st.set_corner_radius_all(24)
	st.set_border_width_all(5)
	var edge := col if tier > 0 else Color(0.62, 0.56, 0.45)
	st.border_color = edge
	st.shadow_color = Color(edge, 0.28 + 0.14 * tier)
	st.shadow_size = 18 + 10 * tier
	p.add_theme_stylebox_override("panel", st)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var c := CenterContainer.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 16)
	var ic := Ui.icon_rect("locked-chest", 190, Color(edge, 0.9))
	ic.size = Vector2(190, 190)
	v.add_child(ic)
	var q := Ui.label("?", "Title", HORIZONTAL_ALIGNMENT_CENTER)
	q.add_theme_font_size_override("font_size", 70)
	q.add_theme_color_override("font_color", Color(edge, 0.85))
	v.add_child(q)
	c.add_child(v)
	p.add_child(c)
	FxUi.gloss(p, 24.0, 0.4, 2.4 if tier >= 2 else 3.6)
	return p


func _flip() -> void:
	stage = "flipping"
	var g := _gen
	var r: Dictionary = rewards[idx]
	var tier := _tier(r)
	var col := _tier_color(r, tier)
	FxUi.still(_card)
	FxUi.still(_hint)
	_hint.text = ""
	Sfx.play("card_flip", 0.0, 1.0 + tier * 0.06)
	var t := create_tween()
	t.tween_property(_card, "scale", Vector2(0.0, 1.06), 0.13).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_callback(func() -> void:
		_back.visible = false
		_front.visible = true)
	t.tween_property(_card, "scale", Vector2(1.0, 1.0), 0.34).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await get_tree().create_timer(0.13).timeout
	if g != _gen or not is_instance_valid(_card):
		return
	_reveal_fx(tier, col)
	_count_up_title(r)
	await get_tree().create_timer(0.34).timeout
	if g != _gen:
		return
	stage = "revealed"
	_hint.text = "%d / %d · tap" % [idx + 1, rewards.size()] if idx + 1 < rewards.size() else "Tap to see everything"
	FxUi.pulse(_hint, 1.05, 1.1)


## The bigger the rarity, the bigger the moment.
func _reveal_fx(tier: int, col: Color) -> void:
	var c := _card.position + CARD_SIZE * 0.5
	_spray(c, col.lightened(0.35), 12 + tier * 10, 260.0 + tier * 70.0)
	if tier >= 1:
		_ring.fire(c, col.lightened(0.3), 360.0 + tier * 90.0, 0.5)
		Sfx.play("sparkle", -2.0)
	if tier >= 2:
		_flash_screen(col.lightened(0.6), 0.28 + 0.1 * tier, 0.4)
		_shake(4.0 + tier * 3.0, 0.3)
		Sfx.play("rare_chime", 0.0)
		Ui.buzz(30 + tier * 10, 0.5)
		var t := create_tween().set_parallel(true)
		t.tween_property(_rays, "reach", 700.0 + tier * 120.0, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		t.tween_property(_rays, "alpha", 0.42 + 0.06 * tier, 0.2)
		t.chain().tween_property(_rays, "alpha", 0.2, 0.9)
		_banner(TIER_NAME[tier] + ("!" if tier == 4 else ""), col)
	if tier >= 3:
		Sfx.play("levelup", -2.0)
	if tier >= 4:
		Sfx.play("sting_victory", -4.0)
		_flash_screen(Color.WHITE, 0.7, 0.6)
		_ring.fire(c, Color.WHITE, 900.0, 0.8)


func _banner(text: String, col: Color) -> void:
	var l := Ui.label(text, "Title", HORIZONTAL_ALIGNMENT_CENTER)
	l.add_theme_font_size_override("font_size", 64)
	l.add_theme_color_override("font_color", col.lightened(0.4))
	l.add_theme_constant_override("outline_size", 14)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.size = Vector2(get_viewport_rect().size.x, 90)
	l.position = Vector2(0, get_viewport_rect().size.y * 0.5 - CARD_SIZE.y * 0.5 - 205.0)
	l.pivot_offset = Vector2(l.size.x * 0.5, 45)
	l.scale = Vector2.ONE * 2.4
	l.modulate.a = 0.0
	add_child(l)
	var t := create_tween().set_parallel(true)
	t.tween_property(l, "scale", Vector2.ONE, 0.36).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(l, "modulate:a", 1.0, 0.12)
	t.chain().tween_interval(1.0)
	t.chain().tween_property(l, "modulate:a", 0.0, 0.4)
	t.chain().tween_callback(l.queue_free)


## Gold, gems and shards run up from zero as the card lands.
func _count_up_title(r: Dictionary) -> void:
	if not _front.has_meta("title"):
		return
	var l: Label = _front.get_meta("title")
	var amount := int(r.get("amount", 0))
	if amount <= 0 or not l.has_meta("fmt"):
		return
	var fmt: String = l.get_meta("fmt")
	var t := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_method(func(v: float) -> void:
		l.text = fmt % int(v), 0.0, float(amount), 0.6)
	t.tween_callback(FxUi.pop.bind(l, 1.2))
	if str(r["type"]) == "gold":
		Sfx.play("coin", -6.0)


func _next_card() -> void:
	stage = "dealing"
	var g := _gen
	FxUi.still(_hint)
	_hint.text = ""
	var r: Dictionary = rewards[idx]
	var tier := _tier(r)
	var col := _tier_color(r, tier)
	var slot := _slots[idx]
	var to := slot.get_global_rect().get_center() - global_position
	Sfx.play("ui_tap", -6.0, 1.0 + idx * 0.05)
	var t := create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(_card, "position", to - CARD_SIZE * 0.5, 0.34)
	t.tween_property(_card, "scale", Vector2.ONE * 0.1, 0.34)
	t.tween_property(_card, "rotation_degrees", 12.0, 0.34)
	t.tween_property(_card, "modulate:a", 0.0, 0.1).set_delay(0.26)
	# Whatever it was now sits in the tray, in its color.
	var fill := func() -> void:
		var st := slot.get_theme_stylebox("panel") as StyleBoxFlat
		st.border_color = col if tier > 0 else Color(0.8, 0.72, 0.55)
		st.bg_color = Color(col, 0.22)
		slot.add_child(_mini_icon(r, 34, col))
		FxUi.pop(slot, 1.3)
	t.chain().tween_callback(fill)
	await t.finished
	if g != _gen:
		return
	_deal(idx + 1)


# --- The reward cards -------------------------------------------------------

## Color, icon, title and subtitle for one reward.
func _card_look(r: Dictionary) -> Dictionary:
	var col := Color(1.0, 0.8, 0.35)
	var icon := "two-coins"
	var title := ""
	var sub := ""
	var fmt := ""
	match str(r["type"]):
		"gold":
			fmt = "+%d gold"
			title = fmt % int(r["amount"])
		"shards":
			var d: Dictionary = DB.HEROES[r["hero"]]
			col = d["color"]
			icon = d["icon"]
			fmt = "+%d " + str(d["name"]) + " shards"
			title = fmt % int(r["amount"])
			var h := Game.hero(r["hero"])
			sub = ("%d shards · buy Super ranks" % int(h["shards"])) if h["unlocked"] else "%d / 20 to unlock" % int(h["shards"])
		"item":
			var it: Dictionary = r["item"]
			col = DB.gear_color(it)
			icon = GearDB.item_icon(it)
			title = str(it["name"])
			sub = "%s · for the %s\n%s" % [Game.item_tag(it), DB.HEROES[it["cls"]]["name"], "\n".join(Game.describe_stats(it))]
		"gems":
			col = Color(0.55, 0.9, 1.0)
			icon = "gems"
			fmt = "+%d gems"
			title = fmt % int(r["amount"])
			sub = "Gems hatch eggs sooner"
		"egg":
			var ed: Dictionary = SKDB.EGGS[r["egg"]]
			col = ed["color"]
			icon = "egg-clutch"
			title = "%s!" % ed["name"]
			sub = "It warms in your hatchery (Sidekicks)"
		"unlock":
			var d2: Dictionary = DB.HEROES[r["hero"]]
			col = d2["color"]
			icon = d2["icon"]
			title = "%s unlocked!" % d2["name"]
			sub = d2["blurb"]
	return {"col": col, "icon": icon, "title": title, "sub": sub, "fmt": fmt}


func _mini_icon(r: Dictionary, size_: float, col: Color) -> Control:
	if str(r["type"]) == "item":
		return ItemIcons.rect(r["item"], size_, col.lightened(0.2))
	return Ui.icon_rect(str(_card_look(r)["icon"]), size_, col.lightened(0.2))


func _reward_card(r: Dictionary, tier: int, col: Color) -> Control:
	var look := _card_look(r)
	var p := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.09, 0.08, 0.11, 0.98)
	st.set_corner_radius_all(24)
	st.set_border_width_all(5)
	st.border_color = col
	st.shadow_color = Color(col, 0.5)
	st.shadow_size = 26 + 8 * tier
	st.content_margin_left = 30
	st.content_margin_right = 30
	st.content_margin_top = 26
	st.content_margin_bottom = 26
	p.add_theme_stylebox_override("panel", st)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# A rarity ribbon from RARE up; below that the card speaks for itself.
	var rib := Ui.label(TIER_NAME[tier] if tier >= 2 else (str(r["type"]).to_upper() if str(r["type"]) != "item" else "ITEM"), "Caption", HORIZONTAL_ALIGNMENT_CENTER)
	rib.add_theme_color_override("font_color", col.lightened(0.3))
	v.add_child(rib)
	var stack := Control.new()
	stack.custom_minimum_size = Vector2(0, 210)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var glow := FxUi.glow_dot(col, 0.55)
	glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stack.add_child(glow)
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cc.add_child(_mini_icon(r, 170 if str(r["type"]) == "item" else 150, col))
	stack.add_child(cc)
	v.add_child(stack)
	var t := Ui.label(str(look["title"]), "Heading", HORIZONTAL_ALIGNMENT_CENTER)
	t.add_theme_font_size_override("font_size", 36)
	t.add_theme_color_override("font_color", col.lightened(0.25))
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(t)
	if str(look["fmt"]) != "":
		t.set_meta("fmt", look["fmt"])
		p.set_meta("title", t)
	if str(look["sub"]) != "":
		var s := Ui.label(str(look["sub"]), "Body", HORIZONTAL_ALIGNMENT_CENTER)
		s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(s)
	p.add_child(v)
	FxUi.gloss(p, 24.0, 0.3, 4.0, 1.0)
	return p


# --- The summary and the collect -------------------------------------------

func _summary() -> void:
	stage = "summary"
	Ui.clear(_holder)
	if _tray:
		create_tween().tween_property(_tray, "modulate:a", 0.0, 0.25)
	create_tween().tween_property(_skip, "modulate:a", 0.0, 0.2)
	_skip.disabled = true
	var vp := get_viewport_rect().size
	var p := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.07, 0.065, 0.09, 0.96)
	st.set_corner_radius_all(26)
	st.set_border_width_all(4)
	st.border_color = _chest_col
	st.shadow_color = Color(_chest_col, 0.4)
	st.shadow_size = 28
	st.content_margin_left = 22
	st.content_margin_right = 22
	st.content_margin_top = 24
	st.content_margin_bottom = 24
	p.add_theme_stylebox_override("panel", st)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(Ui.label(DB.CHESTS[kind]["name"], "Title", HORIZONTAL_ALIGNMENT_CENTER))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for r in rewards:
		grid.add_child(_tile(r))
	v.add_child(grid)
	p.add_child(v)
	p.size = Vector2(vp.x - 70.0, 0)
	var holder := CenterContainer.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(p)
	_holder.add_child(holder)
	Ui.pop_in(p, 0.0, 0.85)
	FxUi.deal_in(grid, 0.07, 0.7)
	Sfx.play("levelup", -8.0)
	_hint.text = "Tap to collect"
	FxUi.pulse(_hint, 1.06, 1.1)
	var t := create_tween().set_parallel(true)
	t.tween_property(_rays, "reach", 700.0, 0.4)
	t.tween_property(_rays, "alpha", 0.2, 0.4)
	t.tween_property(_rays, "color", _chest_col, 0.4)


func _tile(r: Dictionary) -> Control:
	var look := _card_look(r)
	var tier := _tier(r)
	var col := _tier_color(r, tier)
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(190, 168)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var st := StyleBoxFlat.new()
	st.bg_color = Color(col, 0.14)
	st.set_corner_radius_all(16)
	st.set_border_width_all(3)
	st.border_color = col
	st.content_margin_left = 8
	st.content_margin_right = 8
	st.content_margin_top = 10
	st.content_margin_bottom = 8
	p.add_theme_stylebox_override("panel", st)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cc := CenterContainer.new()
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ic := _mini_icon(r, 74, col)
	cc.add_child(ic)
	v.add_child(cc)
	var short := str(look["title"])
	if str(r["type"]) in ["gold", "gems", "shards"]:
		short = "+%s" % Ui.fmt_num(int(r["amount"]))
	var l := Ui.label(short, "Small", HORIZONTAL_ALIGNMENT_CENTER)
	l.add_theme_font_size_override("font_size", 22)
	l.add_theme_color_override("font_color", col.lightened(0.3))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(l)
	p.add_child(v)
	p.set_meta("icon", ic)
	p.set_meta("reward", r)
	return p


func _collect() -> void:
	stage = "done"
	FxUi.still(_hint)
	_hint.text = ""
	Sfx.play("ui_press", -2.0)
	ui.get_node("%NavBar").visible = true
	var grid := _find_grid(_holder)
	var heroes_btn: Control = ui._tab_btns.get("heroes", _bar)
	var delay := 0.0
	var gold_gain := Game.gold() - _gold0
	var gem_gain := _gems_now() - _gems0
	for tile in grid.get_children():
		var r: Dictionary = tile.get_meta("reward")
		var ic: Control = tile.get_meta("icon")
		var target: Control = heroes_btn
		var tint := Color(1.0, 0.84, 0.4)
		match str(r["type"]):
			"gold":
				target = _gold_chip
			"gems":
				target = _gem_chip
				_gem_chip.visible = true
				tint = Color(0.55, 0.9, 1.0)
			_:
				tint = _tier_color(r, _tier(r))
		_fly_icon(ic, target, delay)
		delay += 0.09
	# Counters run up as the icons land.
	var cnt := create_tween()
	cnt.tween_interval(0.55)
	cnt.tween_callback(func() -> void:
		if gold_gain != 0:
			FxUi.count_to(_gold_label, _gold0, Game.gold(), 0.9)
		if gem_gain != 0:
			FxUi.count_to(_gem_label, _gems0, _gems_now(), 0.9))
	var out := create_tween().set_parallel(true)
	out.tween_property(_holder, "modulate:a", 0.0, 0.3).set_delay(0.3)
	out.tween_property(_rays, "alpha", 0.0, 0.5)
	out.tween_property(_scrim, "color:a", 0.0, 0.6).set_delay(0.7)
	await get_tree().create_timer(1.75 if (gold_gain != 0 or gem_gain != 0) else 1.0).timeout
	var t2 := create_tween()
	t2.tween_property(self, "modulate:a", 0.0, 0.25)
	t2.tween_callback(func() -> void:
		ui.chest_done()
		queue_free())


func _find_grid(n: Node) -> GridContainer:
	if n is GridContainer:
		return n
	for c in n.get_children():
		var g := _find_grid(c)
		if g:
			return g
	return null


## A copy of `ic` leaves the summary and lands on `target`.
func _fly_icon(ic: Control, target: Control, delay: float) -> void:
	var tex := ic as TextureRect
	if tex == null:
		return
	var f := TextureRect.new()
	f.texture = tex.texture
	f.modulate = tex.modulate
	f.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	f.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	f.size = tex.size if tex.size.x > 1.0 else Vector2(74, 74)
	var from := tex.get_global_rect().get_center() - global_position
	var end := target.get_global_rect().get_center() - global_position
	f.position = from - f.size * 0.5
	f.pivot_offset = f.size * 0.5
	add_child(f)
	tex.modulate.a = 0.0
	var mid := (from + end) * 0.5 + Vector2(randf_range(-70, 70), -120.0)
	var t := create_tween()
	t.tween_interval(delay)
	t.tween_property(f, "scale", Vector2.ONE * 1.25, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(f, "position", mid - f.size * 0.5, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(f, "scale", Vector2.ONE, 0.2)
	t.tween_property(f, "position", end - f.size * 0.5, 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(f, "scale", Vector2.ONE * 0.45, 0.32)
	t.tween_callback(FxUi.pop.bind(target, 1.18))
	t.tween_callback(Sfx.play.bind("coin", -8.0, 1.0 + delay))
	t.tween_callback(f.queue_free)


func _skip_ahead() -> void:
	if stage in ["summary", "done", "closed", "charging"]:
		return
	_gen += 1
	_skip.disabled = true
	Sfx.play("ui_tap", -4.0)
	_summary()


# --- Effects ----------------------------------------------------------------

func _flash_screen(col: Color, alpha: float, dur: float) -> void:
	_flash.color = Color(col, alpha)
	create_tween().tween_property(_flash, "color:a", 0.0, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## The whole overlay jolts and settles.
func _shake(px: float, dur: float) -> void:
	var t := create_tween()
	t.tween_method(func(v: float) -> void:
		position = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * minf(px, 10.0) * Game.shake_amp() * (1.0 - v), 0.0, 1.0, dur)
	t.tween_callback(func() -> void: position = Vector2.ZERO)


## A one-shot spray of sparks from `at`.
func _spray(at: Vector2, col: Color, n: int, speed: float) -> void:
	var p := CPUParticles2D.new()
	p.texture = FxUi.dot_texture()
	p.position = at
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = n
	p.lifetime = 0.9
	p.direction = Vector2(0, -1)
	p.spread = 180.0
	p.gravity = Vector2(0, 380.0)
	p.initial_velocity_min = speed * 0.35
	p.initial_velocity_max = speed
	p.scale_amount_min = 0.25
	p.scale_amount_max = 0.7
	p.color = col
	var ramp := Gradient.new()
	ramp.set_color(0, Color.WHITE)
	ramp.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = ramp
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	p.material = mat
	add_child(p)
	p.emitting = true
	get_tree().create_timer(1.2).timeout.connect(p.queue_free)


## An expanding ring of light.
class Ring extends Control:
	var center := Vector2.ZERO
	var radius := 0.0
	var alpha := 0.0
	var color := Color.WHITE

	func fire(at: Vector2, col: Color, reach: float, dur: float) -> void:
		center = at
		color = col
		radius = 20.0
		alpha = 0.9
		var t := create_tween().set_parallel(true)
		t.tween_property(self, "radius", reach, dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		t.tween_property(self, "alpha", 0.0, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	func _process(_dt: float) -> void:
		if alpha > 0.0:
			queue_redraw()

	func _draw() -> void:
		if alpha <= 0.0:
			return
		draw_arc(center, radius, 0.0, TAU, 72, Color(color, alpha), 10.0 * alpha + 2.0, true)
