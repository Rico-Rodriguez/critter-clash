extends ScreenBase

## CC-BY models have to name the artist. CC0 work is listed too.

const ENTRIES := [
	{
		"title": "\"KAI\" — The Little Fox Warrior (Animated)",
		"used": "Juniper",
		"author": "Realidad Aumentada Empezando Desde Cero",
		"url": "https://sketchfab.com/3d-models/kai-the-little-fox-warrior-animated-aa56e447b578470b8d6b1b9587fd29ac",
		"license": "CC-BY 4.0",
	},
	{
		"title": "Stylized Dragon",
		"used": "Ember",
		"author": "Stan",
		"url": "https://sketchfab.com/3d-models/stylized-dragon-97d00c182fa24fa4838493c41ad8e52c",
		"license": "CC-BY 4.0",
	},
	{
		"title": "Mushroom Boss — game ready with animations",
		"used": "Thistle",
		"author": "iamjohnhult",
		"url": "https://sketchfab.com/3d-models/mushroom-boss-game-ready-with-animations-ee611e4925e94a98baa4cfd3d89d3449",
		"license": "CC-BY 4.0",
	},
	{
		"title": "Nature Vegetation Pack",
		"used": "Meadow trees and rocks",
		"author": "AnderArts",
		"url": "https://sketchfab.com/3d-models/nature-vegetation-pack-c257b444645542da867fce0cf221e52d",
		"license": "CC-BY 4.0",
	},
]


func build() -> void:
	show_nav = true
	nav_tab = ""
	var box := column()
	box.add_child(header())
	box.add_child(h1("Credits"))
	box.add_child(body("CC-BY models keep the artist's name. CC0 models are listed because we use them."))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 10)
	scroll.add_child(list)
	for entry in ENTRIES:
		list.add_child(_card(entry))
	list.add_child(_plain("Also used (CC0 / open licences)", [
		"Pixor — dragon and owl critters",
		"Gamideo — otter critter",
		"Quaternius — monsters and nature kit",
		"ambientCG — ground, rock and moss textures",
		"Poly Haven — sky",
		"Kenney — interface pictures, treasure chest",
		"Godot Engine — MIT",
		"Cinzel, Nunito, Lilita One — SIL Open Font License",
	]))
	box.add_child(back_button("home"))


func _plaque() -> PanelContainer:
	var panel := PanelContainer.new()
	var empty := StyleBoxEmpty.new()
	for side in ["left", "right"]:
		empty.set("content_margin_" + side, 26)
	for side in ["top", "bottom"]:
		empty.set("content_margin_" + side, 20)
	panel.add_theme_stylebox_override("panel", empty)
	var metal := UiKit.rarity_metal("common")
	var fr := UiKit.Frame.new("plaque", "leather", {"metal_hi": metal[0], "metal_lo": metal[1]})
	fr.margin = 12.0
	panel.add_child(fr)
	return panel


func _card(entry: Dictionary) -> PanelContainer:
	var panel := _plaque()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	var title := UiKit.label(str(entry["title"]), 25, Color("fff1d6"), "x", 5)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var used := UiKit.label("Used for %s" % entry["used"], 21, Color("efe4cc"), "b", 4)
	var meta := UiKit.label("by %s  ·  %s" % [entry["author"], entry["license"]], 21, UiKit.GOLD.lightened(0.15), "b", 4)
	meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var url := UiKit.label(str(entry["url"]).replace("https://", ""), 17, Color("bcd0ea"), "m", 3)
	url.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	box.add_child(title)
	box.add_child(used)
	box.add_child(meta)
	box.add_child(url)
	panel.add_child(box)
	return panel


func _plain(heading: String, lines: Array) -> PanelContainer:
	var panel := _plaque()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.add_child(UiKit.label(heading.to_upper(), 21, UiKit.GOLD.lightened(0.15), "x", 4))
	for line in lines:
		var l := UiKit.label("•  " + str(line), 21, Color("efe4cc"), "b", 4)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(l)
	panel.add_child(box)
	return panel
