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
		var origin := size * 0.5 - Vector2(0, 60)
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
		# Chest scales to the space: about 72% of the width, centred low.
		var cw := minf(size.x * 0.74, size.y * 0.95)
		var k := cw / 400.0
		var c := Vector2(size.x * 0.5, size.y * 0.5 + 30.0 * k)
		var floor_y := c.y + 152.0 * k + 64.0 * k
		# Shafts from above: always faintly there, flaring when it opens.
		var src := Vector2(c.x + 40.0 * k, -40.0)
		for i in 7:
			var x := c.x + (i - 3) * 64.0 * k + sin(t * 0.4 + i) * 6.0
			var half := (26.0 + (i % 3) * 14.0) * k
			var top_half := half * 0.35
			var aa := (0.1 + 0.06 * float(i % 2)) * (0.75 + rays * 0.8)
			var lit := Color(1.0, 0.86, 0.6, aa)
			var clear := Color(1.0, 0.86, 0.6, 0.0)
			var src_x := src.x + (x - c.x) * 0.25
			draw_polygon(PackedVector2Array([Vector2(src_x - top_half, src.y), Vector2(src_x + top_half, src.y), Vector2(x + half, floor_y), Vector2(x - half, floor_y)]),
				PackedColorArray([clear, clear, lit, lit]))
		# Floor light pool.
		for i in 26:
			var w := (420.0 - i * 14.0) * k
			_ellipse(Vector2(c.x, floor_y), Vector2(w, w * 0.22), Color(1.0, 0.72, 0.38, 0.016 + rays * 0.01))
		# Stone pedestal: two tiers with lit tops, dark faces and a gilt lip.
		var ped_w := 250.0 * k
		var tiers := [[floor_y - 6.0 * k, ped_w * 1.12, 34.0 * k], [floor_y - 40.0 * k, ped_w, 30.0 * k]]
		for tier in tiers:
			var ty: float = tier[0]
			var tw: float = tier[1]
			var th: float = tier[2]
			var face := PackedVector2Array()
			var cols := PackedColorArray()
			for j in 21:
				var aj := PI * j / 20.0
				face.append(Vector2(c.x + cos(aj) * tw, ty + sin(aj) * tw * 0.2))
				cols.append(Color("2a221c").lerp(Color("4a3e32"), 0.5 + 0.5 * cos(aj) * 0.6 + 0.2))
			for j in 21:
				var aj := PI - PI * j / 20.0
				face.append(Vector2(c.x + cos(aj) * tw, ty - th + sin(aj) * tw * 0.2))
				cols.append(Color("3a3028").lerp(Color("6a5a48"), 0.5 + 0.5 * cos(aj) * 0.6 + 0.2))
			draw_polygon(face, cols)
			_ellipse(Vector2(c.x, ty - th), Vector2(tw, tw * 0.2), Color("6e604e"))
			_ellipse(Vector2(c.x - tw * 0.1, ty - th - 2.0 * k), Vector2(tw * 0.8, tw * 0.14), Color(1.0, 0.86, 0.6, 0.12 + rays * 0.08))
			var lip := PackedVector2Array()
			for j in 41:
				var aj := TAU * j / 40.0
				lip.append(Vector2(c.x + cos(aj) * tw, ty - th + sin(aj) * tw * 0.2))
			draw_polyline(lip, Color("c9a25a"), 2.5 * k, true)
		# Contact shadow under the chest.
		for i in 8:
			_ellipse(Vector2(c.x, floor_y - 70.0 * k), Vector2((210.0 - i * 9.0) * k, (40.0 - i * 2.5) * k), Color(0, 0, 0, 0.1))
		var chest := Rect2(c.x - 200.0 * k, floor_y - 70.0 * k - 300.0 * k, 400.0 * k, 312.0 * k)
		UiKit.draw_chest(self, chest, "wood", not empty)
		# Warm rim from the shafts on the lid.
		draw_line(chest.position + Vector2(30.0 * k, 8.0 * k), chest.position + Vector2(chest.size.x - 30.0 * k, 8.0 * k), Color(1.0, 0.9, 0.65, 0.35), 3.0 * k, true)
		if opened > 0.0:
			var mouth := chest.position + Vector2(chest.size.x * 0.5, chest.size.y * 0.32)
			for i in 20:
				_ellipse(mouth, Vector2(200 - i * 9, 70 - i * 3) * k * opened, Color(1.0, 0.9, 0.6, 0.035))
		# Dust motes drifting in the light.
		for i in 26:
			var fx := fmod(float(i) * 97.3 + t * (6.0 + float(i % 5)), size.x * 0.7) + size.x * 0.15
			var fy := fmod(float(i) * 53.1 - t * (10.0 + float(i % 4) * 3.0), floor_y) 
			if fy < 0.0:
				fy += floor_y
			var flick := 0.5 + 0.5 * sin(t * 2.0 + i)
			draw_circle(Vector2(fx, fy), (1.5 + float(i % 3)) * k, Color(1.0, 0.88, 0.6, 0.18 + 0.25 * flick * (0.5 + rays)))

		for part in parts:
			var life := float(part["life"])
			if life <= 0.0:
				continue
			var al := clampf(life / float(part["max"]), 0.0, 1.0)
			var col: Color = part["c"]
			col.a = al
			draw_circle(part["p"], float(part["s"]) * al, col)

	func _ellipse(center: Vector2, r: Vector2, col: Color) -> void:
		var pts := PackedVector2Array()
		for i in 40:
			var a := TAU * i / 40.0
			pts.append(center + Vector2(cos(a) * r.x, sin(a) * r.y))
		draw_colored_polygon(pts, col)
