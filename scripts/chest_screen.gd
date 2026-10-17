extends ScreenBase

var title_label: Label
var loot_box: VBoxContainer
var open_button: Button
var home_button: Button
var showing_loot := false
var burst: Burst


func build() -> void:
	var box := column()
	box.add_child(header())
	title_label = h1("Chest")
	box.add_child(title_label)
	box.add_child(body("Cards level your critters. Gear fills weapon, armor, and charm."))
	burst = Burst.new()
	burst.custom_minimum_size = Vector2(0, 560)
	burst.size_flags_vertical = Control.SIZE_EXPAND_FILL
	burst.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(burst)
	loot_box = VBoxContainer.new()
	loot_box.add_theme_constant_override("separation", 14)
	loot_box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(loot_box)
	open_button = UiKit.button("Open", 420, 90)
	open_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	open_button.pressed.connect(_on_open)
	box.add_child(open_button)
	home_button = UiKit.secondary("Home", 220, 64)
	home_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	home_button.visible = false
	home_button.pressed.connect(func() -> void: go("home"))
	box.add_child(home_button)


func open(_args: Dictionary = {}) -> void:
	_arm()


func _arm() -> void:
	for child in loot_box.get_children():
		child.queue_free()
	home_button.visible = false
	showing_loot = false
	if SaveGame.pending_count() <= 0:
		title_label.text = "No chests"
		open_button.visible = false
		home_button.visible = true
		loot_box.add_child(body("Win or lose a hunt and one comes home with you."))
		burst.empty = true
		burst.arm()
		return
	var chest: Dictionary = SaveGame.data["chests"][0]
	var hunt := str(chest.get("kind", "hunt")) == "hunt"
	title_label.text = "Hunt chest" if hunt else "Small pouch"
	open_button.visible = true
	open_button.text = "Open"
	burst.arm()
	var biome := Catalog.biome(str(chest.get("biome", "meadow")))
	loot_box.add_child(body("From the %s." % str(biome["name"])))


func _on_open() -> void:
	if showing_loot:
		_arm()
		return
	_reveal()


func _reveal() -> void:
	var loot := SaveGame.open_next()
	if loot.is_empty():
		_arm()
		return
	for child in loot_box.get_children():
		child.queue_free()
	open_button.visible = false
	home_button.visible = true
	title_label.text = "Yours"
	if burst:
		burst.pop()
		AudioDirector.play("merge")
		AudioDirector.haptic(18)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	loot_box.add_child(row)
	var rewards: Array = [_reward_coin(int(loot["coins"]))]
	var totals := {}
	for drop in loot["cards"]:
		var id := str(drop["id"])
		totals[id] = int(totals.get(id, 0)) + int(drop["count"])
	for id in totals.keys():
		var info := Catalog.critter(str(id))
		rewards.append(_reward_card(str(id), str(info.get("name", id)), int(totals[id])))
	for i in rewards.size():
		var r: Control = rewards[i]
		row.add_child(r)
		r.modulate.a = 0.0
		r.pivot_offset = Vector2(100, 130)
		r.scale = Vector2(0.6, 0.6)
		var tw := create_tween()
		tw.tween_interval(0.25 + 0.14 * i)
		tw.tween_property(r, "modulate:a", 1.0, 0.18)
		tw.parallel().tween_property(r, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var gear: Dictionary = loot["gear"]
	if not gear.is_empty():
		var plate := UiKit.Plate.new()
		plate.kind = "plaque"
		plate.pad = 14
		plate.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var gear_label := UiKit.label(SaveGame.gear_text(gear), 22, UiKit.GOLD.lightened(0.2), "x", 3)
		gear_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		gear_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		gear_label.custom_minimum_size = Vector2(560, 0)
		plate.add_child(gear_label)
		loot_box.add_child(plate)
	if SaveGame.pending_count() > 0:
		open_button.visible = true
		open_button.text = "Next chest"
		showing_loot = true


func _reward_card(id: String, name: String, count: int) -> Control:
	var rarity := UiKit.hero_rarity(id)
	var plate := UiKit.Plate.new()
	plate.kind = "card"
	plate.glow = Color(UiKit.rarity_colors(rarity)["glow"], 0.35)
	plate.pad = 16
	plate.custom_minimum_size = Vector2(200, 260)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 6)
	plate.add_child(v)
	var medal := UiKit.Medal.new()
	medal.tex = SpriteBank.head(id)
	medal.custom_minimum_size = Vector2(130, 130)
	medal.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(medal)
	var n := UiKit.label(name.to_upper(), 20, UiKit.GOLD.lightened(0.2), "x", 3)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(n)
	var c := UiKit.label("+%d cards" % count, 20, UiKit.CREAM, "b", 2)
	c.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(c)
	return plate


func _reward_coin(coins: int) -> Control:
	var plate := UiKit.Plate.new()
	plate.kind = "card"
	plate.glow = Color(1.0, 0.75, 0.3, 0.35)
	plate.pad = 16
	plate.custom_minimum_size = Vector2(200, 260)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 6)
	plate.add_child(v)
	var art := CoinPile.new()
	art.custom_minimum_size = Vector2(130, 130)
	v.add_child(art)
	var n := UiKit.label("COINS", 20, UiKit.GOLD.lightened(0.2), "x", 3)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(n)
	var c := UiKit.label("+%d" % coins, 24, UiKit.CREAM, "b", 2)
	c.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(c)
	return plate


class CoinPile extends Control:
	func _draw() -> void:
		var c := size * 0.5
		for k in 6:
			draw_circle(c, 62.0 - k * 4.0, Color(1.0, 0.75, 0.3, 0.04))
		var spots := [Vector2(-34, 22), Vector2(30, 24), Vector2(-4, 30), Vector2(-20, -4), Vector2(18, 0), Vector2(0, -26)]
		for p in spots:
			UiKit.draw_currency(self, "coins", Rect2(c + p - Vector2(30, 30), Vector2(60, 60)))


## The chest stage: a warm pool of light, a big forged chest that rattles
## while armed, then bursts open with sparks and light rays.
class Burst extends Control:
	var empty := false
	var opened := 0.0
	var rays := 0.0

	func arm() -> void:
		shaking = not empty
		opened = 0.0
		rays = 0.0
		parts.clear()
		visible = true
		set_process(true)

	var parts: Array[Dictionary] = []
	var shaking := true
	var t := 0.0

	func _process(delta: float) -> void:
		t += delta
		if shaking:
			pivot_offset = size * 0.5
			rotation = sin(t * 9.0) * 0.025 * maxf(0.0, sin(t * 2.2))
		var alive := false
		for part in parts:
			part["life"] = float(part["life"]) - delta
			part["p"] = part["p"] + part["v"] * delta
			part["v"] = part["v"] + Vector2(0, 280.0) * delta
			if float(part["life"]) > 0.0:
				alive = true
		if not shaking:
			opened = minf(1.0, opened + delta * 3.0)
			rays = minf(1.0, rays + delta * 1.5)
		queue_redraw()

	func pop() -> void:
		shaking = false
		rotation = 0.0
		var origin := size * 0.5 - Vector2(0, 40)
		for i in 36:
			var ang := float(i) / 36.0 * TAU + randf_range(-0.1, 0.1)
			var speed := randf_range(180.0, 520.0)
			parts.append({
				"p": origin,
				"v": Vector2.from_angle(ang) * speed,
				"life": randf_range(0.45, 0.85),
				"max": 0.7,
				"s": randf_range(6.0, 14.0),
				"c": Color("ffe08a") if i % 3 != 0 else Color("fff6e0"),
			})

	func _draw() -> void:
		var c := size * 0.5 + Vector2(0, 20)
		# Floor light pool.
		for k in 28:
			var w := 380.0 - k * 12.0
			_ellipse(c + Vector2(0, 150), Vector2(w, w * 0.28), Color(1.0, 0.7, 0.35, 0.013 + rays * 0.007))
		if rays > 0.0:
			for k in 12:
				var a := -PI * 0.5 + (k - 5.5) * 0.17 + sin(t * 0.7 + k) * 0.03
				var tip := c - Vector2(0, 40) + Vector2.from_angle(a) * 620.0
				var side := Vector2.from_angle(a + PI * 0.5) * 34.0
				var col := Color(1.0, 0.85, 0.5, 0.10 * rays)
				var clear := Color(1.0, 0.85, 0.5, 0.0)
				draw_polygon(PackedVector2Array([c - Vector2(0, 40), tip + side, tip - side]), PackedColorArray([col, clear, clear]))
		for k in 8:
			_ellipse(c + Vector2(0, 150), Vector2(230 - k * 8, 46 - k * 2), Color(0, 0, 0, 0.09))
		var chest := Rect2(c.x - 200, c.y - 160, 400, 312)
		UiKit.draw_chest(self, chest, "wood", not empty)
		if opened > 0.0:
			for k in 20:
				_ellipse(c - Vector2(0, 90), Vector2(200 - k * 9, 70 - k * 3) * opened, Color(1.0, 0.9, 0.6, 0.035))

		for part in parts:
			var life := float(part["life"])
			if life <= 0.0:
				continue
			var a := clampf(life / float(part["max"]), 0.0, 1.0)
			var col: Color = part["c"]
			col.a = a
			draw_circle(part["p"], float(part["s"]) * a, col)

	func _ellipse(center: Vector2, r: Vector2, col: Color) -> void:
		var pts := PackedVector2Array()
		for i in 40:
			var a := TAU * i / 40.0
			pts.append(center + Vector2(cos(a) * r.x, sin(a) * r.y))
		draw_colored_polygon(pts, col)
