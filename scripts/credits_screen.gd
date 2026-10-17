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
	list.add_child(body("CC0: Pixor dragon and owl, Gamideo otter, Quaternius monsters and nature, ambientCG ground, Poly Haven sky, Kenney interface pictures. Godot Engine is MIT. Nunito and Lilita One are SIL Open Font License."))
	box.add_child(back_button("home"))


func _card(entry: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	var frame := UiKit.panel(Color("163e86"), 16)
	frame.content_margin_left = 14
	frame.content_margin_right = 14
	frame.content_margin_top = 10
	frame.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", frame)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	var title := UiKit.label(str(entry["title"]), 22, UiKit.CREAM, "x", 4)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var meta := UiKit.label("%s  ·  %s  ·  %s" % [entry["used"], entry["author"], entry["license"]], 16, Color("ffe08a"), "b", 3)
	meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var url := UiKit.label(str(entry["url"]), 14, Color("d5e6ff"), "m", 2)
	url.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(title)
	box.add_child(meta)
	box.add_child(url)
	panel.add_child(box)
	return panel
