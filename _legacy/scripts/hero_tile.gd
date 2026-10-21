class_name HeroTile
extends RefCounted

## One hero in a roster: the face, the name, the level, and the tag of the
## one the player takes into the world. The Heroes tab and the character
## select use the same tile, so a hero reads the same in both.

## The tile for one hero. `selected` is the id the player is looking at;
## `on_pick` is called with the id when the tile is tapped.
static func build(id: String, selected: String, on_pick: Callable) -> Button:
	var info := Catalog.critter(id)
	var row := SaveGame.hero(id)
	var on := id == selected
	var rarity := UiKit.hero_rarity(id)
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.flat = true
	b.custom_minimum_size = Vector2(158, 206)
	var empty := StyleBoxEmpty.new()
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(st, empty)
	var metal := UiKit.rarity_metal(rarity) if not on else [Color("ffe6a8"), Color("6a4416")]
	var frame := UiKit.Frame.new("card", "leather", {
		"metal_hi": metal[0], "metal_lo": metal[1], "frame": 6.0 if on else 4.0,
		"glow_color": Color(1.0, 0.72, 0.3, 0.55) if on else Color(0, 0, 0, 0),
		"face_top": Color("2a2016") if on else Color("16110d"), "face_bot": Color("0c0907"),
	})
	frame.margin = 2.0
	b.add_child(frame)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 4)
	b.add_child(v)
	var medal := UiKit.Medal.new()
	medal.tex = SpriteBank.head(id)
	medal.custom_minimum_size = Vector2(100, 100)
	medal.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(medal)
	var n := UiKit.label(str(info["name"]).to_upper(), 20, UiKit.GOLD.lightened(0.2) if on else UiKit.CREAM, "x", 3)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(n)
	var l := UiKit.label("Level %d" % int(row.get("level", 1)), 17, UiKit.MUTED, "m", 2)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	if id == SaveGame.featured_id():
		var tag := UiKit.label("EQUIPPED", 15, Color("9fe08a"), "x", 3)
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(tag)
	if not on:
		b.modulate = Color(0.78, 0.78, 0.78)
	b.pressed.connect(on_pick.bind(id))
	return b


## The heroes a roster may show: the ones the player owns, in the order
## the roster keeps them.
static func owned() -> Array:
	var out: Array = []
	for id in Catalog.playable_ids():
		if bool(SaveGame.hero(id).get("unlocked", false)):
			out.append(str(id))
	if out.is_empty():
		# A save that owns nobody still needs someone to take into the world.
		out.append("paladin")
	return out
