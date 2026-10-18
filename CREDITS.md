# Credits

Critter Clash is an original game. The hunt, the roster, and the interface are original. The world is licensed 3D: critters, nature, ground textures, and a sky. Kenney pictures remain on the interface portraits. Nothing in the game changes a critter's role based on where it stands.

## Code and engine

- Godot Engine 4.7.2 — https://godotengine.org — MIT License.

## Fonts

- Cinzel by Natanael Gama and the Cinzel Project Authors (display type). File: `assets/fonts/Cinzel-Variable.ttf`, plus `CinzelDecorative-Black.ttf`. License: SIL Open Font License 1.1. See `assets/fonts/OFL-Cinzel.txt`. Source: [google/fonts](https://github.com/google/fonts) `ofl/cinzel`, `ofl/cinzeldecorative`.
- Alegreya Sans by Juan Pablo del Peral and Huerta Tipográfica (body text). Files: `assets/fonts/AlegreyaSans-Bold.ttf`, `AlegreyaSans-Medium.ttf`. License: SIL Open Font License 1.1. See `assets/fonts/OFL-AlegreyaSans.txt`. Source: [google/fonts](https://github.com/google/fonts) `ofl/alegreyasans`.

The older fonts below remain in the repository but the interface no longer uses them:

- Nunito by Vernon Adams, Cyreal, Jacques Le Bailly, and other contributors.
- Files: `assets/fonts/Nunito-SemiBold.ttf`, `Nunito-Bold.ttf`, `Nunito-ExtraBold.ttf`.
- License: SIL Open Font License 1.1. See `assets/fonts/OFL.txt`.
- Source: [fontsource Nunito](https://fontsource.org/fonts/nunito) latin weights 600, 700, and 800.
- Lilita One by Juan Montoreano. File: `assets/fonts/LilitaOne-Regular.ttf`.
- License: SIL Open Font License 1.1, reserved font name Lilita. See `assets/fonts/OFL-LilitaOne.txt`.
- Source: [google/fonts](https://github.com/google/fonts) `ofl/lilitaone`.

## 3D models

- Ember the dragon: "Cute Dragon" by shakiller — https://sketchfab.com/3d-models/cute-dragon-df14ec74767c4598920132758dab8a49 — CC-BY 4.0. File `assets/models/sketchfab/ember_cute.glb`, with its own hand-painted scale textures and one idle clip.
- Cinder and Cindling (volcano dragons): "Stylized Dragon" by Stan (Stas_SayHallo) — https://sketchfab.com/3d-models/stylized-dragon-97d00c182fa24fa4838493c41ad8e52c — CC-BY 4.0. File `assets/models/sketchfab/ember.glb`. Clips are wing flaps and a head turn. The CC0 fallback is Pixor's "Small Dragon" — https://pixor.art/library/creatures/dragon-small/ — files `assets/models/ember_*.glb`, used for lava and water variants.
- Juniper the fox: "KAI" — The Little Fox Warrior (Animated) by Realidad Aumentada Empezando Desde Cero — https://sketchfab.com/3d-models/kai-the-little-fox-warrior-animated-aa56e447b578470b8d6b1b9587fd29ac — CC-BY 4.0. File `assets/models/sketchfab/juniper.glb`. Idle, Run, and Punch. The CC0 fallback is Gamideo's fox in `juniper_*.glb`.
- Pebble the otter: "Cozy Animals" by Gamideo — https://dragofive.itch.io/cozy-animals-3d — CC0. File `pebble_*.glb`. No CC0 or CC-BY rigged otter on Sketchfab was a real otter with a walk cycle, so this mesh stays. It is tinted teal-brown in game.
- Lumen the owl: Pixor "Owl" — https://pixor.art/library/creatures/owl/ — CC0. Files `lumen_*.glb`. Searches did not turn up a rigged CC0 or CC-BY owl that was actually an owl.
- Pip the frog and Bramble the cactus-hog, plus minions that share those rigs: Quaternius Ultimate Monsters — https://quaternius.com — CC0. Files `pip_*.glb` (Frog) and `bramble_*.glb` (Cactoro). Clips include Idle, Run, Punch, HitReact, and Death. No rigged CC0 or CC-BY frog or hedgehog cleared the license and character checks.
- Pinecone boar critters (Mossback, Yeti, Magmash; formerly the hero Bramble): "Crazy Critter Crate - Swinecone" by Moped (mopedgames) — https://sketchfab.com/3d-models/crazy-critter-crate-swinecone-bae685e5a9d9442a85e78b1525b08aaf — CC-BY 4.0. File `assets/models/sketchfab/bramble.glb` (the display rock is stripped out). It replaces the sombrero cactus (Quaternius Cactoro), whose `bramble_*.glb` files remain only as unused fallbacks.
- Thistle the meadow boss: "Mushroom Boss - game ready with animations" by iamjohnhult — https://sketchfab.com/3d-models/mushroom-boss-game-ready-with-animations-ee611e4925e94a98baa4cfd3d89d3449 — CC-BY 4.0. File `assets/models/sketchfab/thistle.glb`. Idle, Walk, Attack, and Die. The CC0 fallback is Quaternius "Demon" in `assets/models/thistle_boss.gltf`.
- Meadow trees, bushes, and rocks: "Nature Vegetation Pack" by AnderArts — https://sketchfab.com/3d-models/nature-vegetation-pack-c257b444645542da867fce0cf221e52d — CC-BY 4.0. File `assets/models/sketchfab/nature/grove.glb`. The shipped file keeps one LOD0 of each tree, bush, and rock. The astronaut, ground plane, cliffs, and extra LODs are not included.
- Grass, flowers, mushrooms, pedestal stones, and the trees outside the meadow: Quaternius Stylized Nature MegaKit — https://quaternius.com/packs/stylizednature.html — CC0.

### Enemies and bosses

- Every wild enemy and lair boss uses Quaternius's **Ultimate Monsters** pack (CC0) — https://quaternius.com/packs/ultimatemonsters.html , downloaded via https://poly.pizza (glb, rigged and animated). Files in `assets/models/monsters/`. Hero critter models are no longer reused for enemies. Restyled in-engine (PBR roughness/rim pass in `scripts/cast3d.gd`).

- Sketchfab creatures, all CC-BY 4.0 (https://creativecommons.org/licenses/by/4.0/), files in `assets/models/sketchfab/mon/`, tinted per biome in `scripts/cast3d.gd`:
  - "Golem" by **DWN (dwn76)** — https://sketchfab.com/3d-models/golem-241619b4423148029ceecddbbe691af0 — Cinder and Nimbus lair bosses. Changes: clip times rebased to zero, vein emission mask (`golem_glow.png`), ice repaint for Nimbus (`golem_ice.png`).
  - "fantasy boar animation" by **blam (Blam577895)** — https://sketchfab.com/3d-models/fantasy-boar-animation-a9dd958971ea462fbaab621410c30748 — Snowpup, Magmash.
  - "giant scorpion animation" by **blam (Blam577895)** — https://sketchfab.com/3d-models/giant-scorpion-animation-651c17e0a3784c0386790e5b7c565f1a — Skink, Shard.
  - "Bat Lord" by **Huh (SkibidiSanya)** — https://sketchfab.com/3d-models/bat-lord-8ee898e9c5384493989a5f1cbc38dab3 — Moth, Glowmoth, Ashbat, Icewisp.
- Dark-fantasy pass, all CC-BY 4.0 by **AnimalMesh 3D (AnimalMesh3D)**, files in `assets/models/sketchfab/dark/`, graded darker in `scripts/cast3d.gd`:
  - "Animated Fox 3D Model" — https://sketchfab.com/3d-models/animated-fox-3d-model-7b7d4f07d47a444ab6c08b62adfd4aff — Juniper, the hero fox ranger. Barding (banded steel lames with rivets, neck lamellar, collar pauldrons, brow chamfron, leather girths) is built in-engine by `scripts/armor3d.gd`, textured with ambientCG CC0 scans (Metal032 steel, Metal035 bronze, Leather037 leather → `assets/textures/armor_*`).
  - "Quiver and Arrows" by **Finley Searle (FinleySearle)** — https://sketchfab.com/3d-models/quiver-and-arrows-078aa762143e4c399edcf4529e76340e — CC-BY 4.0. File `assets/models/sketchfab/armor/quiver.glb`, baked into Juniper's barding.
  - "Animated Badger – 3D Animal Model" — https://sketchfab.com/3d-models/animated-badger-3d-animal-model-c495442f215d4f2ba18c29fcd9cc7587 — Rot Badger (id `sprout`).
  - "Animated Realistic Bear – 3D Animal Model" — https://sketchfab.com/3d-models/animated-realistic-bear-3d-animal-model-77a1fcdc92e14db698767da9ee09f84a — Grave Bear (id `boarlet`).
- Caplet (mushroom lair boss) reuses the Mushroom Boss model listed above, dyed violet.
- Enemy portraits in `assets/sprites/portraits/` are re-baked from these models.

### Hunt forest

- "Handpainted Tree Pack" by **rudolfs** — https://sketchfab.com/3d-models/handpainted-tree-pack-d246b8b4439d44c6adc854ebc5ffc5ba — licensed under CC-BY 4.0 (https://creativecommons.org/licenses/by/4.0/). File `assets/models/sketchfab/nature/handpainted.glb`. Changes: colour-graded darker per biome, alpha-scissor leaves, instanced in `scripts/stage3d.gd`.

## Textures and sky

- Ground textures are ambientCG — https://ambientcg.com — CC0:
  - Hunt floor (2K): Grass004 (`ground_grass_*`), Ground037 forest floor (`ground_forest_*`), and Ground078 dirt (`ground_dirt_*`). Ambient occlusion is baked into the colour maps; `*_data.jpg` packs roughness (R) and height (G) for the height-blended splat.
  - Grass004 (`assets/textures/grass_*.jpg`) and Grass001 (`lush_*.jpg`) for the turf.
  - Ground078 (`path_*.jpg`) for the dirt trails.
  - Rock051 color, normal and roughness (`rock_color.jpg`, `rock_normal.jpg`, `rock_rough.jpg`) for the pedestal and field rocks.
  - Moss002 color and normal (`moss_color.jpg`, `moss_normal.jpg`) for moss on the field rocks.
- Collection-log item icons are rendered in-engine from primitives and the game's own models by `scripts/icon_baker.gd`.
- Interface materials are ambientCG — CC0, reduced to 512 px in `assets/textures/ui/`:
  - Rock030 (`ui_stone.jpg`) for the carved-stone backdrop and the tab bar.
  - Marble006 (`ui_marble.jpg`) for the panel faces.
  - Leather037 normal map (`ui_leather_n.jpg`) for the leather bump under the frames.
  - Planks037A (`ui_wood.jpg`).
- The metal frames, bevels, rivets, and glows are procedural (`shaders/ui_frame.gdshader`).
- Ember's painted albedo (`assets/models/sketchfab/ember_paint.png`) is derived from the Stylized Dragon's own textures by `tools/paint_ember.py` (CC-BY 4.0, same credit as the model).
- Sky: Poly Haven `kloofendal_48d_partly_cloudy_puresky` (1k) — https://polyhaven.com/a/kloofendal_48d_partly_cloudy_puresky — CC0. File `assets/textures/sky.hdr`.
- `assets/textures/dust.png` is drawn for this game.

## Knight heroes and gear

All CC-BY 4.0 (https://creativecommons.org/licenses/by/4.0/) unless marked CC0. Gear is re-textured with tier shading in `shaders/gear_tier.gdshader`; the meshes are otherwise unchanged.

- "Paladin" by DJMaesen (bumstrum): https://sketchfab.com/3d-models/paladin-4f1c320f2cec49dc9bf38c6aad2d8ea9 . Used for Aldric, the ashen paladin hero.
- "Skeleton Lord" by DJMaesen (bumstrum): https://sketchfab.com/3d-models/skeleton-lord-a3f7b44275cf4c489ad62c535268ac16 . Used for Mordrek, the Bone Knight hero (finger grip borrowed from the Paladin rig's rest pose).
- Animations: KayKit Adventurers and Skeletons character packs by Kay Lousberg (CC0, https://kaylousberg.itch.io/kaykit-adventurers). They are retargeted onto each hero rig by `tools/retarget.gd`.
- "Reinforced Wooden Shield (game ready asset)" by apariciosilva3D: https://sketchfab.com/3d-models/reinforced-wooden-shield-game-ready-asset-20a4a579371d4b6c86244fad9404a313
- "Medieval Wood Heater Shield" by iedalton: https://sketchfab.com/3d-models/medieval-wood-heater-shield-2a3aba2c1ef041168fab0c595e2e5882
- "Paladin Shield [Free Download]" by Efarys: https://sketchfab.com/3d-models/paladin-shield-free-download-0ae0f62030ad48d88364b327b7cd3fc3
- "Black Blade of Oarimaar" by Pippa (Planetrix23): https://sketchfab.com/3d-models/black-blade-of-oarimaar-d84a41ac0a2a4d9bb39a0a2b7fe1027f

## Interface pictures

- Critter portraits on cards, the collection log, the slayer panel, and the hunt medallion are renders of each critter's own 3D model (credited above), baked by `scripts/portrait_baker.gd` into `assets/sprites/portraits/`. Kenney's [Animal Pack Redux](https://opengameart.org/content/animal-pack-redux) (CC0) stays in `assets/sprites/critters/` only as a fallback.
- Interface icons (`assets/sprites/icons/`) are from Kenney's [Board Game Icons](https://kenney.nl/assets/board-game-icons) and [Game Icons](https://kenney.nl/assets/game-icons), CC0, recoloured to white at 128 px.
- Credit to Kenney (www.kenney.nl) is appreciated and not required.
- `icon.png` is drawn by `tools/make_icon.py`.

## Audio

Built from the sources below by `tools/build_sfx.py` (trim, layer, peak-normalise, OGG). Music is in `assets/audio/music/`, effects in `assets/audio/sfx/`.

### Music (CC-BY 4.0)

- "Achaidh Cheide" (home theme), "Heroic Age" (hunt theme), and "Five Armies" (boss theme) by Kevin MacLeod (incompetech.com). Licensed under Creative Commons: By Attribution 4.0 — https://creativecommons.org/licenses/by/4.0/ . Sources: https://incompetech.com/music/royalty-free/mp3-royaltyfree/Achaidh%20Cheide.mp3 , .../Heroic%20Age.mp3 , .../Five%20Armies.mp3 . Re-encoded to OGG and loudness-matched; otherwise unchanged.
- Victory sting: "Victory Fanfare Short" by cynicmusic — https://opengameart.org/content/victory-fanfare-short — CC0 (trimmed to 8 s).

### Sound effects (CC0)

- Kenney (www.kenney.nl) — CC0: Impact Sounds, Interface Sounds, UI Audio, RPG Audio, Casino Audio, Music Jingles (pizzicato jingles for the level-up and defeat stings). https://kenney.nl/assets
- rubberduck on OpenGameArt — CC0: "80 CC0 RPG SFX" (fire spells, gems, coins, roar, locks) https://opengameart.org/content/80-cc0-rpg-sfx , "80 CC0 creature SFX" (critter squeaks, hurts, spits) https://opengameart.org/content/80-cc0-creature-sfx , "100 CC0 SFX" (bells, slams, plops, gong, box open) https://opengameart.org/content/100-cc0-sfx , "100 CC0 SFX #2" (air whooshes, stones) https://opengameart.org/content/100-cc0-sfx-2
- trazzz123 — "CC0 Deep Monster Roar" — https://opengameart.org/content/cc0-deep-monster-roar — CC0 (boss roar).
- Darsycho — "Monster snarls" — https://opengameart.org/content/monster-snarls — CC0 (boss wind-up).

The earlier synthesized effects from `tools/build_audio.py` are no longer shipped.

## Chest
- Chest model: Kenney Pirate Kit 2.1 (`chest.glb`), www.kenney.nl, CC0. Restyled in-engine (shaders/chest.gdshader, scripts/chest3d.gd).
- Planks012 (wood) and Metal032 (iron normal/roughness): ambientCG, CC0, https://ambientcg.com
