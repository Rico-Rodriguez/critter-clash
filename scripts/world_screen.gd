extends ScreenBase

## The map: one framed banner per biome, rendered from the biome's own hunt
## scene (scripts/banner_baker.gd), with the boss's 3D head in a medallion.

## Per-biome tier the player has picked in this visit (biome id -> tier index).
var _pick: Dictionary = {}


func build() -> void:
	show_nav = true
	nav_tab = "world"
	var box := column()
	box.add_child(header_with_back("hub"))
	box.add_child(h1("Biomes"))
	box.add_child(body("Clear them in order. Each boss guards its own drops."))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var pad := MarginContainer.new()
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 14)
	scroll.add_child(pad)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 26)
	pad.add_child(list)
	for entry in Catalog.BIOMES:
		list.add_child(_banner(entry))


func _banner(entry: Dictionary) -> Control:
	var id := str(entry["id"])
	var unlocked := SaveGame.biome_open(id)
	var cleared := SaveGame.biome_cleared(id)
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var empty := StyleBoxEmpty.new()
	for side in ["left", "right", "top", "bottom"]:
		empty.set("content_margin_" + side, 9)
	card.add_theme_stylebox_override("panel", empty)
	var metal := UiKit.rarity_metal("legendary" if unlocked else "common")
	var frame := UiKit.Frame.new("panel", "leather", {
		"metal_hi": metal[0], "metal_lo": metal[1],
		"glow_color": Color(1.0, 0.7, 0.3, 0.22 if unlocked and not cleared else 0.0),
	})
	frame.margin = 18.0
	card.add_child(frame)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 0)
	card.add_child(stack)
	# Banner art with the name set into its lower edge.
	var art_box := Control.new()
	art_box.custom_minimum_size = Vector2(0, 236)
	stack.add_child(art_box)
	var art := TextureRect.new()
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_SCALE
	art.texture = _banner_texture(id)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/ui_art.gdshader")
	mat.set_shader_parameter("radius", 8.0)
	mat.set_shader_parameter("fade_from", 0.45)
	mat.set_shader_parameter("desat", 0.0 if unlocked else 0.85)
	mat.set_shader_parameter("darken", 0.0 if unlocked else 0.45)
	art.material = mat
	art.resized.connect(func() -> void: mat.set_shader_parameter("px", art.size))
	art_box.add_child(art)
	var boss := Catalog.critter(str(entry["boss"]))
	# The name and its boss sit in a bounded caption band, so a long biome
	# or boss name wraps inside the banner instead of running off it.
	var cap := MarginContainer.new()
	cap.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	cap.offset_left = 22
	cap.offset_right = -156
	cap.offset_top = -104
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art_box.add_child(cap)
	var cap_col := VBoxContainer.new()
	cap_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cap_col.add_theme_constant_override("separation", 2)
	cap.add_child(cap_col)
	var name := UiKit.label(str(entry["name"]).to_upper(), 34, UiKit.GOLD.lightened(0.2), "x", 4)
	name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cap_col.add_child(name)
	var sub := UiKit.label("Guarded by %s" % str(boss["name"]), 19, UiKit.CREAM, "b", 0)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cap_col.add_child(sub)
	var medal := Medallion.new()
	medal.tex = SpriteBank.head(str(entry["boss"]))
	medal.locked = not unlocked
	medal.size = Vector2(118, 118)
	medal.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	medal.position = Vector2(0, 0)
	art_box.add_child(medal)
	art_box.resized.connect(func() -> void: medal.position = Vector2(art_box.size.x - 136, 120))
	if not unlocked:
		var lock := LockMark.new()
		lock.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		art_box.add_child(lock)
	# Footer: status on the left, the call to action on the right.
	var foot := MarginContainer.new()
	foot.add_theme_constant_override("margin_left", 14)
	foot.add_theme_constant_override("margin_right", 14)
	foot.add_theme_constant_override("margin_top", 12)
	foot.add_theme_constant_override("margin_bottom", 8)
	stack.add_child(foot)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	foot.add_child(row)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.add_theme_constant_override("separation", 0)
	row.add_child(info)
	if cleared:
		info.add_child(UiKit.label("✦ CLEARED", 18, Color("9fe08a"), "x", 3))
		info.add_child(UiKit.label(Catalog.recommended_text(id) + ". Boss drops still roll on every win.", 15, UiKit.MUTED, "b", 0))
	elif unlocked:
		info.add_child(UiKit.label("BOSS AWAITS", 18, UiKit.GOLD, "x", 3))
		info.add_child(UiKit.label(Catalog.recommended_text(id) + ". Survive the waves to draw it out.", 15, UiKit.MUTED, "b", 0))
	else:
		info.add_child(UiKit.label("SEALED", 18, Color("c89a8a"), "x", 3))
		var why := UiKit.label(SaveGame.biome_lock_text(id) + " to unlock", 15, UiKit.MUTED, "b", 0)
		why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.add_child(why)
		info.add_child(UiKit.label(Catalog.recommended_text(id), 15, UiKit.MUTED, "b", 0))
	if unlocked:
		info.add_child(_tier_row(id))
	if unlocked:
		var button := UiKit.button("HUNT", 220, 88)
		button.pressed.connect(_open_biome.bind(id))
		row.add_child(button)
	else:
		# A disabled call to action that names its own lock, so the reason
		# sits on the button the player reaches for.
		var locked_button := UiKit.button("LOCKED", 220, 88, "grey")
		locked_button.disabled = true
		locked_button.tooltip_text = SaveGame.biome_lock_text(id) + " to unlock"
		row.add_child(locked_button)
	return card


func _banner_texture(id: String) -> Texture2D:
	var path := "res://assets/sprites/arenas/%s_banner.png" % id
	var tex: Texture2D = load(path) if ResourceLoader.exists(path) else SpriteBank.arena(id)
	if tex == null:
		return null
	# Crop to the banner window's aspect so the scale stretch never distorts.
	var crop := AtlasTexture.new()
	crop.atlas = tex
	var w := float(tex.get_width())
	var h := w / 2.85
	crop.region = Rect2(0, maxf(0.0, (float(tex.get_height()) - h) * 0.42), w, minf(h, float(tex.get_height())))
	return crop


## A compact segmented control for the biome's unlocked difficulty tiers. A
## locked tier is disabled and names the clear that opens it. Picking a tier
## only re-skins the row; the HUNT button reads the same `_pick` map.
func _tier_row(id: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var chosen := int(_pick.get(id, 0))
	var entries: Array = []
	for t in Catalog.TIER_COUNT:
		var open_tier := SaveGame.difficulty_open(id, t)
		# 72 keeps the tier chips a full tap target next to the 88 px HUNT
		# call, where 58 read as cramped beside it.
		var b := UiKit.button(Catalog.tier_name(t), 0, 72, "gold" if t == chosen else "grey")
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.disabled = not open_tier
		if not open_tier and t > 0:
			b.tooltip_text = "Clear the boss on %s to open %s" % [Catalog.tier_name(t - 1), Catalog.tier_name(t)]
		entries.append({"btn": b, "tier": t})
		b.pressed.connect(func() -> void:
			_pick[id] = t
			for entry in entries:
				var eb = entry["btn"]
				eb.set_tone("gold" if int(entry["tier"]) == t else "grey"))
		row.add_child(b)
	return row


## Straight into the hunt with the featured hero: the hero is picked on
## the Heroes tab (and shown on Home), not re-chosen before every run.
func _open_biome(id: String) -> void:
	SaveGame.data["last_biome"] = id
	go("run", {"biome": id, "hero": SaveGame.featured_id(), "tier": clampi(int(_pick.get(id, 0)), 0, Catalog.TIER_COUNT - 1)})


## The boss's head in a gilded ring.
class Medallion extends Control:
	var tex: Texture2D
	var locked := false
	var _mat: ShaderMaterial

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var face := TextureRect.new()
		face.texture = tex
		face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		face.stretch_mode = TextureRect.STRETCH_SCALE
		face.position = Vector2(10, 10)
		face.size = size - Vector2(20, 20)
		_mat = ShaderMaterial.new()
		_mat.shader = load("res://shaders/ui_art.gdshader")
		_mat.set_shader_parameter("circle", 1.0)
		_mat.set_shader_parameter("px", face.size)
		_mat.set_shader_parameter("fade_alpha", 0.0)
		_mat.set_shader_parameter("desat", 0.9 if locked else 0.0)
		_mat.set_shader_parameter("darken", 0.6 if locked else 0.0)
		face.material = _mat
		face.show_behind_parent = false
		add_child(face)
		var ring := Ring.new()
		ring.size = size
		add_child(ring)

	func _draw() -> void:
		var c := size * 0.5
		var r := size.x * 0.5
		draw_circle(c + Vector2(0, 4), r, Color(0, 0, 0, 0.55))
		draw_circle(c, r - 6, Color("1a110a"))
		for i in 8:
			draw_circle(c, (r - 10) * (1.0 - i * 0.09), Color(0.55, 0.2, 0.12, 0.08))


class Ring extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size * 0.5
		var r := size.x * 0.5 - 6
		draw_arc(c, r, 0, TAU, 64, Color("120a04"), 11.0, true)
		draw_arc(c, r, 0, TAU, 64, Color("8a5a1a"), 8.0, true)
		draw_arc(c, r, PI * 1.05, PI * 1.95, 32, Color("ffe6a8"), 3.0, true)
		draw_arc(c, r, PI * 0.1, PI * 0.9, 32, Color("4a2e0e"), 3.0, true)
		draw_arc(c, r - 5, 0, TAU, 64, Color(0, 0, 0, 0.6), 2.0, true)
		for k in 4:
			var a := PI * 0.25 + k * PI * 0.5
			var p := c + Vector2.from_angle(a) * r
			draw_circle(p, 5.5, Color("120a04"))
			draw_circle(p, 4.0, Color("f0d08a"))


class LockMark extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var tex := UiKit.icon("lock_closed")
		var px := 72.0
		var c := Vector2(size.x * 0.5, size.y * 0.4)
		draw_circle(c, 56, Color(0, 0, 0, 0.45))
		UiKit.draw_icon(self, tex, Rect2(c - Vector2(px, px) * 0.5, Vector2(px, px)), UiKit.GOLD, Color(0.05, 0.03, 0.02), 2.0)
