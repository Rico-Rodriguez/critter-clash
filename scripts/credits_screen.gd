extends ScreenBase

## CC-BY models have to name the artist. CC0 work is listed too.

const ENTRIES := [
	{
		"title": "Achaidh Cheide",
		"used": "Home theme",
		"author": "Kevin MacLeod (incompetech.com)",
		"url": "https://incompetech.com/music/royalty-free/mp3-royaltyfree/Achaidh%20Cheide.mp3",
		"license": "CC-BY 4.0",
	},
	{
		"title": "Heroic Age",
		"used": "Hunt theme",
		"author": "Kevin MacLeod (incompetech.com)",
		"url": "https://incompetech.com/music/royalty-free/mp3-royaltyfree/Heroic%20Age.mp3",
		"license": "CC-BY 4.0",
	},
	{
		"title": "Five Armies",
		"used": "Boss theme",
		"author": "Kevin MacLeod (incompetech.com)",
		"url": "https://incompetech.com/music/royalty-free/mp3-royaltyfree/Five%20Armies.mp3",
		"license": "CC-BY 4.0",
	},
	{
		"title": "Cute Dragon",
		"used": "Retired dragon hero (fallback only)",
		"author": "shakiller",
		"url": "https://sketchfab.com/3d-models/cute-dragon-df14ec74767c4598920132758dab8a49",
		"license": "CC-BY 4.0",
	},
	{
		"title": "Crazy Critter Crate - Swinecone",
		"used": "Pinecone boar beasts",
		"author": "Moped (mopedgames)",
		"url": "https://sketchfab.com/3d-models/crazy-critter-crate-swinecone-bae685e5a9d9442a85e78b1525b08aaf",
		"license": "CC-BY 4.0",
	},
	{
		"title": "Stylized Dragon",
		"used": "Cinder and Ash Wyrmling",
		"author": "Stan",
		"url": "https://sketchfab.com/3d-models/stylized-dragon-97d00c182fa24fa4838493c41ad8e52c",
		"license": "CC-BY 4.0",
	},
	{
		"title": "Troll Cave",
		"used": "Gravemaw, the meadow lair boss",
		"author": "Vasian-Digital3D",
		"url": "https://sketchfab.com/3d-models/troll-cave-16eabe8c1e244bc99d87c181a907c58f",
		"license": "CC-BY 4.0",
	},
	{
		"title": "Stylized Nightmarish Werewolf",
		"used": "Nightmaw, the mushroom-forest lair boss",
		"author": "Stylized Builder",
		"url": "https://sketchfab.com/3d-models/stylized-nightmarish-werewolf-53e21af08b8c495cb67a9fbd95750071",
		"license": "CC-BY 4.0",
	},
	{
		"title": "Mushroom Boss — game ready with animations",
		"used": "Former meadow and mushroom bosses (fallback only)",
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
	{
		"title": "Handpainted Tree Pack",
		"used": "Hunt forests: pines, spruces, oaks, dead snags, stumps and bushes",
		"author": "rudolfs",
		"url": "https://sketchfab.com/3d-models/handpainted-tree-pack-d246b8b4439d44c6adc854ebc5ffc5ba",
		"license": "CC-BY 4.0",
	},
	{
		"title": "Animated Fox 3D Model",
		"used": "Spectral Hound (feral fox beasts)",
		"author": "AnimalMesh 3D",
		"url": "https://sketchfab.com/3d-models/animated-fox-3d-model-7b7d4f07d47a444ab6c08b62adfd4aff",
		"license": "CC-BY 4.0",
	},
	{
		"title": "Animated Badger – 3D Animal Model",
		"used": "Rot Badger",
		"author": "AnimalMesh 3D",
		"url": "https://sketchfab.com/3d-models/animated-badger-3d-animal-model-c495442f215d4f2ba18c29fcd9cc7587",
		"license": "CC-BY 4.0",
	},
	{
		"title": "Animated Realistic Bear – 3D Animal Model",
		"used": "Grave Bear",
		"author": "AnimalMesh 3D",
		"url": "https://sketchfab.com/3d-models/animated-realistic-bear-3d-animal-model-77a1fcdc92e14db698767da9ee09f84a",
		"license": "CC-BY 4.0",
	},
	{
		"title": "Golem",
		"used": "Cinder and Nimbus, the volcano and frost lair bosses",
		"author": "DWN (dwn76)",
		"url": "https://sketchfab.com/3d-models/golem-241619b4423148029ceecddbbe691af0",
		"license": "CC-BY 4.0",
	},
	{
		"title": "fantasy boar animation",
		"used": "Rime Stalker and Magma Behemoth",
		"author": "blam (Blam577895)",
		"url": "https://sketchfab.com/3d-models/fantasy-boar-animation-a9dd958971ea462fbaab621410c30748",
		"license": "CC-BY 4.0",
	},
	{
		"title": "giant scorpion animation",
		"used": "Ashrunner and Ice Wraith",
		"author": "blam (Blam577895)",
		"url": "https://sketchfab.com/3d-models/giant-scorpion-animation-651c17e0a3784c0386790e5b7c565f1a",
		"license": "CC-BY 4.0",
	},
	{
		"title": "Bat Lord",
		"used": "Grave Moth, Blight Moth, Ashbat and Frostcaller",
		"author": "Huh (SkibidiSanya)",
		"url": "https://sketchfab.com/3d-models/bat-lord-8ee898e9c5384493989a5f1cbc38dab3",
		"license": "CC-BY 4.0",
	},
	{
		"title": "Paladin",
		"used": "Aldric (hero)",
		"author": "DJMaesen (bumstrum)",
		"url": "https://sketchfab.com/3d-models/paladin-4f1c320f2cec49dc9bf38c6aad2d8ea9",
		"license": "CC-BY 4.0",
	},
	{
		"title": "Skeleton Lord",
		"used": "Mordrek (hero)",
		"author": "DJMaesen (bumstrum)",
		"url": "https://sketchfab.com/3d-models/skeleton-lord-a3f7b44275cf4c489ad62c535268ac16",
		"license": "CC-BY 4.0",
	},
	{
		"title": "Ghoul",
		"used": "Gnash (hero)",
		"author": "DJMaesen (bumstrum)",
		"url": "https://sketchfab.com/3d-models/ghoul-f37f43b23fd541df8a2926571acfce70",
		"license": "CC-BY 4.0",
	},
	{
		"title": "Plague Doctor",
		"used": "Corvin (hero)",
		"author": "BeardenInc",
		"url": "https://sketchfab.com/3d-models/plague-doctor-41f7a1dfd6984135b876f334908e3ca4",
		"license": "CC-BY 4.0",
	},
	{
		"title": "KayKit Adventurers / Skeletons animations",
		"used": "Knight hero animations; Gravemaw and Nightmaw death/hit clips (retargeted)",
		"author": "Kay Lousberg (kaylousberg.com)",
		"url": "https://kaylousberg.itch.io/kaykit-adventurers",
		"license": "CC0",
	},
	{
		"title": "Reinforced Wooden Shield",
		"used": "Iron-tier shield",
		"author": "apariciosilva3D",
		"url": "https://sketchfab.com/3d-models/reinforced-wooden-shield-game-ready-asset-20a4a579371d4b6c86244fad9404a313",
		"license": "CC-BY 4.0",
	},
	{
		"title": "Medieval Wood Heater Shield",
		"used": "Steel-tier shield",
		"author": "iedalton",
		"url": "https://sketchfab.com/3d-models/medieval-wood-heater-shield-2a3aba2c1ef041168fab0c595e2e5882",
		"license": "CC-BY 4.0",
	},
	{
		"title": "Paladin Shield",
		"used": "Runebound-tier shield",
		"author": "Efarys",
		"url": "https://sketchfab.com/3d-models/paladin-shield-free-download-0ae0f62030ad48d88364b327b7cd3fc3",
		"license": "CC-BY 4.0",
	},
	{
		"title": "Black Blade of Oarimaar",
		"used": "Runebound-tier sword",
		"author": "Pippa (Planetrix23)",
		"url": "https://sketchfab.com/3d-models/black-blade-of-oarimaar-d84a41ac0a2a4d9bb39a0a2b7fe1027f",
		"license": "CC-BY 4.0",
	},
	{
		"title": "Ancient Pauldron",
		"used": "Runebound-tier shoulder plates",
		"author": "Ciarán Wilson",
		"url": "https://sketchfab.com/3d-models/ancient-pauldron-8c5cd28345ce487d93c46cb94101fce3",
		"license": "CC-BY 4.0",
	},
	{
		"title": "Ultimate Monsters",
		"used": "Every wild enemy and lair boss",
		"author": "Quaternius",
		"url": "https://quaternius.com/packs/ultimatemonsters.html",
		"license": "CC0",
	},
]


func build() -> void:
	show_nav = true
	nav_tab = ""
	var box := column()
	box.add_child(header_with_back("home"))
	box.add_child(h1("Credits"))
	box.add_child(body("CC-BY music and models keep the artist's name. CC0 work is listed because we use it."))
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
		"Pixor — dragon and owl beasts",
		"Gamideo — otter beast",
		"Quaternius — monsters and nature kit",
		"ambientCG — ground, rock and moss textures",
		"Poly Haven — sky",
		"Kenney — interface pictures, treasure chest, sound effects and jingles",
		"OpenGameArt sound effects (CC0): rubberduck (80 CC0 RPG SFX, 80 CC0 creature SFX, 100 CC0 SFX 1 and 2), trazzz123 (Deep Monster Roar), Darsycho (Monster snarls)",
		"cynicmusic — Victory Fanfare Short (CC0)",
		"Godot Engine — MIT",
		"Cinzel, Nunito, Lilita One — SIL Open Font License",
	]))


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
