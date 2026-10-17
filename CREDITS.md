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
- Thistle the meadow boss: "Mushroom Boss - game ready with animations" by iamjohnhult — https://sketchfab.com/3d-models/mushroom-boss-game-ready-with-animations-ee611e4925e94a98baa4cfd3d89d3449 — CC-BY 4.0. File `assets/models/sketchfab/thistle.glb`. Idle, Walk, Attack, and Die. The CC0 fallback is Quaternius "Demon" in `assets/models/thistle_boss.gltf`.
- Meadow trees, bushes, and rocks: "Nature Vegetation Pack" by AnderArts — https://sketchfab.com/3d-models/nature-vegetation-pack-c257b444645542da867fce0cf221e52d — CC-BY 4.0. File `assets/models/sketchfab/nature/grove.glb`. The shipped file keeps one LOD0 of each tree, bush, and rock. The astronaut, ground plane, cliffs, and extra LODs are not included.
- Grass, flowers, mushrooms, pedestal stones, and the trees outside the meadow: Quaternius Stylized Nature MegaKit — https://quaternius.com/packs/stylizednature.html — CC0.

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

## Interface pictures

- Critter portraits on cards, the collection log, the slayer panel, and the hunt medallion are renders of each critter's own 3D model (credited above), baked by `scripts/portrait_baker.gd` into `assets/sprites/portraits/`. Kenney's [Animal Pack Redux](https://opengameart.org/content/animal-pack-redux) (CC0) stays in `assets/sprites/critters/` only as a fallback.
- Interface icons (`assets/sprites/icons/`) are from Kenney's [Board Game Icons](https://kenney.nl/assets/board-game-icons) and [Game Icons](https://kenney.nl/assets/game-icons), CC0, recoloured to white at 128 px.
- Credit to Kenney (www.kenney.nl) is appreciated and not required.
- `icon.png` is drawn by `tools/make_icon.py`.

## Audio

- Effects and the music loop are synthesized by `tools/build_audio.py`.
- No sampled libraries and no third-party tracks.

## Chest
- Chest model: Kenney Pirate Kit 2.1 (`chest.glb`), www.kenney.nl, CC0. Restyled in-engine (shaders/chest.gdshader, scripts/chest3d.gd).
- Planks012 (wood) and Metal032 (iron normal/roughness): ambientCG, CC0, https://ambientcg.com
