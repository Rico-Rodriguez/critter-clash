extends ScreenBase

var title_label: Label
var loot_box: VBoxContainer
var open_button: Button
var home_button: Button
var showing_loot := false
var burst: Burst
var _index := 0

## The loot band's rest height; reveals may grow it into free space above
## the buttons, and _arm() puts it back.
const LOOT_BAND := 300.0
## Reward plates are 200x260; rows wrap and scale as one uniform group.
const TILE := Vector2(200, 260)
const GRID_GAP := 16.0


func build() -> void:
	var box := column()
	box.add_child(header())
	title_label = h1("Chest")
	box.add_child(title_label)
	box.add_child(body("Cards level your heroes. Gear fills weapon, armor, and charm."))
	burst = Burst.new()
	burst.custom_minimum_size = Vector2(0, 560)
	burst.size_flags_vertical = Control.SIZE_EXPAND_FILL
	burst.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(burst)
	loot_box = VBoxContainer.new()
	loot_box.add_theme_constant_override("separation", 14)
	loot_box.alignment = BoxContainer.ALIGNMENT_CENTER
	# Fixed-height loot and button bands, so the chest and its plinth hold
	# the same spot (centred) whether it is closed, bursting or showing loot.
	loot_box.custom_minimum_size = Vector2(0, LOOT_BAND)
	box.add_child(loot_box)
	var foot := VBoxContainer.new()
	foot.custom_minimum_size = Vector2(0, 176)
	foot.alignment = BoxContainer.ALIGNMENT_BEGIN
	foot.add_theme_constant_override("separation", 12)
	box.add_child(foot)
	open_button = UiKit.button("Open", 420, 90)
	open_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	open_button.pressed.connect(_on_open)
	foot.add_child(open_button)
	home_button = UiKit.secondary("Home", 220, 64)
	home_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	home_button.visible = false
	home_button.pressed.connect(func() -> void: go("home"))
	foot.add_child(home_button)


var _want := -1


func open(args: Dictionary = {}) -> void:
	_want = int(args.get("index", -1))
	_arm()


## Only a ready chest reaches this scene (Home starts timers); with none
## ready it says so and points back to the drawer.
func _arm() -> void:
	for child in loot_box.get_children():
		child.queue_free()
	loot_box.custom_minimum_size = Vector2(0, LOOT_BAND)
	home_button.visible = false
	showing_loot = false
	_index = _want if SaveGame.chest_state(_want) == "ready" else SaveGame.first_ready()
	_want = -1
	if _index < 0:
		title_label.text = "No chest ready"
		open_button.visible = false
		home_button.visible = true
		var line := "Win or lose a hunt and one comes home with you." if SaveGame.pending_count() == 0 else "Your chests are still unlocking. Tap one on Home to start its timer."
		loot_box.add_child(body(line))
		burst.empty = SaveGame.pending_count() == 0
		burst.locked = not burst.empty
		burst.tone = SaveGame.chest_tone(0)
		burst.arm()
		return
	var chest: Dictionary = SaveGame.data["chests"][_index]
	var rarity := SaveGame.chest_rarity(_index)
	title_label.text = "%s chest" % rarity.capitalize() if str(chest.get("kind", "hunt")) != "scrap" else "Common pouch"
	open_button.visible = true
	open_button.disabled = false
	open_button.text = "Open"
	burst.tone = SaveGame.chest_tone(_index)
	burst.locked = false
	burst.empty = false
	burst.arm()
	var biome := Catalog.biome(str(chest.get("biome", "meadow")))
	loot_box.add_child(body("From the %s." % str(biome["name"])))


func _on_open() -> void:
	if showing_loot:
		_arm()
		return
	_reveal()


func _reveal() -> void:
	var test := _chest_test_count()
	if _index < 0 and test <= 0:
		return
	var loot: Dictionary
	if test > 0:
		loot = _test_loot(test)
		_index = maxi(_index, 0)
	else:
		loot = SaveGame.open_next(_index)
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
		AudioDirector.sfx("chest_open")
		if burst.tone in ["gold", "magic", "silver"]:
			# Rare and epic chests sparkle as the lid flies.
			get_tree().create_timer(0.18).timeout.connect(AudioDirector.sfx.bind("sparkle"))
			AudioDirector.duck(-8.0, 0.9)
			AudioDirector.haptic("rare")
		else:
			AudioDirector.haptic("medium")
	var rewards: Array = [_reward_coin(int(loot["coins"]))]
	var totals := {}
	for drop in loot["cards"]:
		var id := str(drop["id"])
		totals[id] = int(totals.get(id, 0)) + int(drop["count"])
	for id in totals.keys():
		var info := Catalog.critter(str(id))
		rewards.append(_reward_card(str(id), str(info.get("name", id)), int(totals[id])))
	var reserve := 104.0 if not (loot["gear"] as Dictionary).is_empty() else 0.0
	var laid: Dictionary = _make_grid(loot_box, rewards, reserve)
	var s: float = laid["scale"]
	for i in laid["tiles"].size():
		var tile: Control = laid["tiles"][i]
		tile.modulate.a = 0.0
		tile.pivot_offset = TILE * 0.5
		tile.scale = Vector2(0.6, 0.6)
		var tw := create_tween()
		# Each reward lands when its flyer from the chest arrives.
		tw.tween_interval(0.85 + 0.16 * i)
		tw.tween_property(tile, "modulate:a", 1.0, 0.18)
		tw.parallel().tween_property(tile, "scale", Vector2(s, s), 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_launch_flyers(laid["slots"])
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
	if SaveGame.first_ready() >= 0:
		open_button.visible = true
		open_button.text = "Next chest"
		showing_loot = true


## --chest-test=N, given in user args, fakes a loot result of N rewards
## (coins plus N-1 cards from existing hero ids) without touching the save,
## so captures can stage 1..12 worst cases.
func _chest_test_count() -> int:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--chest-test="):
			return clampi(int(arg.get_slice("=", 1)), 1, 12)
	return -1


## A made-up loot dict: fixed coins, one card per hero id. No save calls.
func _test_loot(count: int) -> Dictionary:
	var loot := {"coins": 128, "cards": [], "gear": {}}
	var ids: Array = Catalog.CRITTERS.keys()
	for i in count - 1:
		loot["cards"].append({"id": str(ids[i % ids.size()]), "count": 1 + (i % 3)})
	return loot


## Width one reward row may use: the loot band's laid-out width, or the
## screen minus safe insets when asked before a layout pass.
func _grid_width() -> float:
	if loot_box != null and loot_box.size.x > 0.0:
		return loot_box.size.x
	var pad := insets()
	return maxf(320.0, get_viewport_rect().size.x - float(int(pad["l"])) - float(int(pad["r"])))


## Height the loot grid may use: the 300 band plus free space above the
## button band, less room kept for the gear plaque. Capped by the column's
## real height so grew rows never reach the safe area.
func _grid_height(reserve: float) -> float:
	if loot_box == null:
		return LOOT_BAND
	var col := loot_box.get_parent() as Container
	if col == null or col.size.y < 1.0:
		return LOOT_BAND
	var others := reserve
	for child in col.get_children():
		if child == loot_box or not (child is Control):
			continue
		others += (child as Control).get_combined_minimum_size().y
	var sep := float(int(col.get_theme_constant("separation")))
	return clampf(col.size.y - others - sep * float(col.get_child_count() - 1), LOOT_BAND, INF)


## Wrapping plan for `n` tiles in a `w` x `h` band: one centred row of all
## n tiles when that fits (4 or fewer), otherwise rows of at most 3, or 4
## when that allows bigger tiles. Tiles shrink as one uniform group, floor
## 0.7. Returns {"per_row", "rows", "scale"}.
func _fit_rows(n: int, w: float, h: float) -> Dictionary:
	if n <= 0:
		return {"per_row": 1, "rows": 1, "scale": 1.0}
	var cands: Array = [mini(n, 3), 4] if n > 3 else [n]
	var best: Dictionary = {}
	var best_s := -1.0
	for c in cands:
		var per_row := int(c)
		var count := int(ceil(float(n) / float(per_row)))
		var s_w := 1.0
		if per_row * TILE.x + float(per_row - 1) * GRID_GAP > w:
			s_w = (w - float(per_row - 1) * GRID_GAP) / (per_row * TILE.x)
		var s_h := 1.0
		if count * TILE.y + float(count - 1) * GRID_GAP > h:
			s_h = (h - float(count - 1) * GRID_GAP) / (count * TILE.y)
		var s := minf(s_w, s_h)
		if s > best_s:
			best_s = s
			best = {"per_row": per_row, "rows": count, "scale": clampf(s, 0.7, 1.0)}
	return best


## Wraps the reward tiles into the loot band: fully centred rows held
## on a grid; slots carry the scaled size so spacing stays the grid gap.
## Returns {"tiles": the tile controls, "slots": the loop targets, "scale"}.
func _make_grid(box: VBoxContainer, tiles: Array, reserve: float) -> Dictionary:
	var n := tiles.size()
	if n <= 0:
		return {"tiles": tiles, "slots": [], "scale": 1.0}
	var fit := _fit_rows(n, _grid_width(), _grid_height(reserve))
	var s: float = fit["scale"]
	var per_row: int = fit["per_row"]
	var row_count: int = fit["rows"]
	var needed := float(row_count) * TILE.y * s + float(row_count - 1) * GRID_GAP
	# The band only grows into free space above the buttons, never past it.
	box.custom_minimum_size = Vector2(0, maxf(LOOT_BAND, minf(needed, _grid_height(reserve))))
	var grid := VBoxContainer.new()
	grid.alignment = BoxContainer.ALIGNMENT_CENTER
	grid.add_theme_constant_override("separation", int(GRID_GAP))
	var slots: Array = []
	var idx := 0
	for _r in row_count:
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", int(GRID_GAP))
		for _c in mini(per_row, n - idx):
			var slot := Control.new()
			slot.custom_minimum_size = TILE * s
			row.add_child(slot)
			var tile: Control = tiles[idx]
			idx += 1
			slot.add_child(tile)
			tile.size = TILE
			# Plate at full size inside a scaled slot: scaling about the
			# pivot keeps the tile covering just the slot, so gaps hold.
			tile.position = -TILE * (1.0 - s) * 0.5
			tile.pivot_offset = TILE * 0.5
			slots.append(slot)
		grid.add_child(row)
	box.add_child(grid)
	return {"tiles": tiles, "slots": slots, "scale": s}


func _launch_flyers(slots: Array) -> void:
	if slots.size() == 0:
		return
	await get_tree().process_frame
	await get_tree().process_frame
	if burst == null:
		return
	for i in slots.size():
		var slot: Control = slots[i]
		if not is_instance_valid(slot):
			continue
		# Slots hold tile centre even for scaled plates.
		var target := slot.global_position + slot.size * 0.5 - burst.global_position
		burst.fly(target, 0.35 + 0.16 * i, "coins" if i == 0 else "card")


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


## The chest stage: a lit stone pedestal under shafts of light, with the
## rendered 3D chest on top. Armed, it rattles and leaks light at the lid;
## opened, the lid swings back, light bursts out and the loot flies to the
## reward cards.
class Burst extends Control:
	var empty := false
	var locked := false
	var tone := "wood"
	var opened := 0.0
	var rays := 0.0
	var flash := 0.0
	var parts: Array[Dictionary] = []
	var flyers: Array[Dictionary] = []
	var shaking := true
	var t := 0.0
	var stage: SubViewportContainer
	var vp: SubViewport
	var cam: Camera3D
	var chest: Chest3D
	var fx: Control
	var key: DirectionalLight3D

	func _ready() -> void:
		stage = SubViewportContainer.new()
		stage.stretch = true
		stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(stage)
		vp = SubViewport.new()
		vp.transparent_bg = true
		vp.own_world_3d = true
		vp.msaa_3d = Viewport.MSAA_4X
		stage.add_child(vp)
		var root := Node3D.new()
		vp.add_child(root)
		var env := Chest3D.stage_env(0.3)
		var we := WorldEnvironment.new()
		we.environment = env
		root.add_child(we)
		# Warm shaft light from above, cool fill from the side, hot rim behind.
		key = DirectionalLight3D.new()
		key.light_color = Color("ffdcae")
		key.light_energy = 2.0
		key.rotation_degrees = Vector3(-58, 24, 0)
		key.shadow_enabled = true
		root.add_child(key)
		var fill := DirectionalLight3D.new()
		fill.light_color = Color("7f96d0")
		fill.light_energy = 0.55
		fill.rotation_degrees = Vector3(-10, -75, 0)
		root.add_child(fill)
		var rim := DirectionalLight3D.new()
		rim.light_color = Color("ffb070")
		rim.light_energy = 1.8
		rim.rotation_degrees = Vector3(-25, 170, 0)
		root.add_child(rim)
		chest = Chest3D.new("wood")
		# A light three-quarter turn: enough to show the side band, not so much
		# that the chest's bulk drifts off the plinth's centre line.
		chest.rotation.y = -0.16
		# The turn swings the near corner left; nudge the body back over the
		# plinth's centre line.
		chest.position.x = 0.06
		root.add_child(chest)
		cam = Camera3D.new()
		cam.fov = 30.0
		cam.position = Vector3(0, 2.2, 4.5)
		root.add_child(cam)
		cam.look_at(Vector3(0, 0.62, 0))
		fx = Control.new()
		fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(fx)
		fx.draw.connect(_draw_fx)
		resized.connect(_layout)
		_layout()

	func _geom() -> Dictionary:
		var cw := minf(size.x * 0.74, size.y * 0.95)
		var k := cw / 400.0
		var c := Vector2(size.x * 0.5, size.y * 0.5 + 30.0 * k)
		var floor_y := c.y + 152.0 * k + 64.0 * k
		return {"k": k, "c": c, "floor": floor_y}

	func _layout() -> void:
		if stage == null:
			return
		var g := _geom()
		var k: float = g["k"]
		var side := 430.0 * k
		stage.position = Vector2(float(g["c"].x) - side * 0.5, float(g["floor"]) - 70.0 * k - side * 0.8)
		stage.size = Vector2(side, side)
		fx.position = Vector2.ZERO
		fx.size = size

	## Where the chest's mouth sits, in this control's coordinates.
	func mouth() -> Vector2:
		if cam == null or stage.size.x <= 0.0:
			return size * 0.5
		var p := cam.unproject_position(chest.global_position + Vector3(0, 0.75, 0.1))
		return stage.position + p * stage.size / Vector2(vp.size)

	func arm() -> void:
		shaking = not empty and not locked
		opened = 0.0
		rays = 0.0
		flash = 0.0
		parts.clear()
		flyers.clear()
		visible = true
		if chest:
			chest.set_tone(tone)
			chest.set_open(0.0)
			chest.set_flash(0.0)
			key.light_energy = 0.8 if empty else 2.0
		set_process(true)

	func _process(delta: float) -> void:
		t += delta
		if chest:
			if shaking:
				# Rattle in bursts; the lid hops and light leaks out.
				var burst_on := maxf(0.0, sin(t * 2.2))
				chest.rotation.z = sin(t * 19.0) * 0.035 * burst_on
				chest.rotation.y = -0.16 + sin(t * 13.0) * 0.03 * burst_on
				chest.set_open(0.05 * burst_on * absf(sin(t * 9.0)))
			else:
				chest.rotation.z = lerpf(chest.rotation.z, 0.0, 0.3)
				# Lid swings back with a little overshoot.
				var e := 1.0 - pow(1.0 - opened, 3.0)
				var over := sin(opened * PI) * 0.12
				chest.set_open(clampf(e + over, 0.0, 1.1))
				chest.set_flash(flash)
		for part in parts:
			part["life"] = float(part["life"]) - delta
			part["p"] = part["p"] + part["v"] * delta
			part["v"] = part["v"] + Vector2(0, 280.0) * delta
		for f in flyers:
			f["t"] = float(f["t"]) + delta
		if not shaking:
			opened = minf(1.0, opened + delta * 2.6)
			rays = minf(1.0, rays + delta * 1.5)
			flash = maxf(0.0, flash - delta * 1.6)
		queue_redraw()
		fx.queue_redraw()

	func pop() -> void:
		shaking = false
		flash = 1.0
		var origin := mouth()
		for i in 40:
			var ang := -PI * 0.5 + randf_range(-1.3, 1.3)
			var speed := randf_range(220.0, 620.0)
			parts.append({
				"p": origin,
				"v": Vector2.from_angle(ang) * speed,
				"life": randf_range(0.5, 0.95),
				"max": 0.8,
				"s": randf_range(5.0, 12.0),
				"c": Color("ffe08a") if i % 3 != 0 else Color("fff6e0"),
			})

	## A coin or card arcs out of the chest to `target` (local coords).
	func fly(target: Vector2, delay: float, kind: String) -> void:
		flyers.append({"from": mouth(), "to": target, "t": -delay, "kind": kind})

	func _draw() -> void:
		var g := _geom()
		var k: float = g["k"]
		var c: Vector2 = g["c"]
		var floor_y: float = g["floor"]
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
			_ellipse(Vector2(c.x, floor_y - 72.0 * k), Vector2((190.0 - i * 9.0) * k, (34.0 - i * 2.5) * k), Color(0, 0, 0, 0.11))
		# Dust motes drifting in the light.
		for i in 26:
			var fx_ := fmod(float(i) * 97.3 + t * (6.0 + float(i % 5)), size.x * 0.7) + size.x * 0.15
			var fy := fmod(float(i) * 53.1 - t * (10.0 + float(i % 4) * 3.0), floor_y)
			if fy < 0.0:
				fy += floor_y
			var flick := 0.5 + 0.5 * sin(t * 2.0 + i)
			draw_circle(Vector2(fx_, fy), (1.5 + float(i % 3)) * k, Color(1.0, 0.88, 0.6, 0.18 + 0.25 * flick * (0.5 + rays)))

	## Drawn over the chest: the light pouring from the mouth, sparks, loot.
	func _draw_fx() -> void:
		var k: float = _geom()["k"]
		var m := mouth()
		var leak := 0.0
		if shaking and chest:
			leak = chest._open * 12.0
		var glow := clampf(opened * 1.4, 0.0, 1.0) * (0.55 + 0.45 * flash) + leak
		if glow > 0.0:
			for i in 18:
				_ellipse_on(fx, m + Vector2(0, -70.0 * k), Vector2(240 - i * 11, 120 - i * 5.5) * k, Color(1.0, 0.82, 0.5, 0.012 * glow))
			# A column of light standing out of the open chest.
			var top := Color(1.0, 0.9, 0.6, 0.0)
			var bot := Color(1.0, 0.86, 0.55, 0.14 * glow)
			fx.draw_polygon(PackedVector2Array([m + Vector2(-150, -420) * k, m + Vector2(150, -420) * k, m + Vector2(110, 0) * k, m + Vector2(-110, 0) * k]),
				PackedColorArray([top, top, bot, bot]))
		if flash > 0.0:
			for i in 10:
				fx.draw_circle(m, (40.0 + i * 26.0) * k * (1.4 - flash * 0.4), Color(1.0, 0.95, 0.8, 0.05 * flash))
		for part in parts:
			var life := float(part["life"])
			if life <= 0.0:
				continue
			var al := clampf(life / float(part["max"]), 0.0, 1.0)
			var col: Color = part["c"]
			col.a = al
			fx.draw_circle(part["p"], float(part["s"]) * al, col)
		for f in flyers:
			var ft := float(f["t"]) / 0.55
			if ft <= 0.0 or ft >= 1.0:
				continue
			var e := ft * ft * (3.0 - 2.0 * ft)
			var a: Vector2 = f["from"]
			var b: Vector2 = f["to"]
			var ctrl := (a + b) * 0.5 + Vector2(0, -260.0 * k)
			var p := a.lerp(ctrl, e).lerp(ctrl.lerp(b, e), e)
			var s := lerpf(0.6, 1.0, e) * 46.0 * k
			for j in 4:
				fx.draw_circle(p, s * (1.4 - j * 0.25), Color(1.0, 0.8, 0.45, 0.08))
			if str(f["kind"]) == "coins":
				UiKit.draw_currency(fx, "coins", Rect2(p - Vector2(s, s) * 0.6, Vector2(s, s) * 1.2))
			else:
				var r := Rect2(p - Vector2(s * 0.5, s * 0.68), Vector2(s, s * 1.36))
				fx.draw_rect(r, Color("3a2416"))
				fx.draw_rect(r.grow(-3.0 * k), Color("c9a25a"), false, 2.0 * k)
				fx.draw_circle(r.get_center(), s * 0.18, Color("ffe08a"))

	func _ellipse(center: Vector2, r: Vector2, col: Color) -> void:
		_ellipse_on(self, center, r, col)

	func _ellipse_on(ci: CanvasItem, center: Vector2, r: Vector2, col: Color) -> void:
		var pts := PackedVector2Array()
		for i in 40:
			var a := TAU * i / 40.0
			pts.append(center + Vector2(cos(a) * r.x, sin(a) * r.y))
		ci.draw_colored_polygon(pts, col)
