# Critter Clash

A portrait 1v1 arena in Godot 4.7. You spend sparks to drop critters on your half of a glade. Matching babies merge, and the habitat under them picks the evolution.

This is an original game. It does not use Supercell names, interface layouts, or assets.

## Play

A match lasts 3 minutes. You and the glade keeper each own a main den and two side burrows. Destroy the enemy den, or have the healthier den when the clock ends. A near tie is a draw.

Sparks refill on their own, up to 10. You start with 6. In the last 30 seconds, Dusk Rush fills them faster.

Your hand holds 4 cards, with the next card peeking beside them. Drag a card onto your half of the glade. The critter walks its lane and fights on its own. Number keys 1–4 do the same on a desktop.

### Merging

Drop a card on a baby of the same critter and the same tier. They merge. Evolutions do not merge again.

The tile under the merge chooses the branch:

| Habitat | Where |
| --- | --- |
| Water | The river, including the bridges |
| Forest | The west bank, outside the river |
| Lava | The east bank, outside the river |

Each critter has two branches. If you merge on the habitat that is not one of them, the nearest of the two real branches is used. The banner says so before you let go. A valid merge also shows the evolved model under your finger, shakes the view, and plays a short hit-stop.

## Roster

Costs are in sparks. Damage is per hit. Range and speed are in glade units.

| Critter | Role | Cost | Form | HP | Dmg | Hit | Range | Speed | Trick |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Ember | Splash | 4 | Ember | 430 | 66 | 1.18s | 3.15 | 2.20 | Splash 1.5, hits flyers |
| Ember | Splash | 4 | Blaze Drake (lava) | 700 | 92 | 1.12s | 3.35 | 2.30 | Wider splash, burn |
| Ember | Splash | 4 | Mist Drake (water) | 640 | 58 | 1.16s | 3.35 | 2.35 | Splash, slow |
| Pebble | Swarm | 2 | Pebble | 270 | 42 | 0.68s | 1.20 | 3.45 | Cheap and fast |
| Pebble | Swarm | 2 | Tide Otter (water) | 380 | 52 | 0.58s | 1.28 | 3.85 | Faster, small splash, slow |
| Pebble | Swarm | 2 | Moss Otter (forest) | 520 | 46 | 0.76s | 1.22 | 3.05 | Reflect 20% |
| Juniper | Ranged | 3 | Juniper | 310 | 56 | 0.98s | 4.75 | 2.75 | Long toss, hits flyers |
| Juniper | Ranged | 3 | Thorn Fox (forest) | 460 | 68 | 0.96s | 5.25 | 2.80 | Slowing thorns |
| Juniper | Ranged | 3 | Cinder Fox (lava) | 440 | 62 | 0.90s | 4.85 | 2.85 | Splash and burn |
| Bramble | Tank | 5 | Bramble | 1240 | 52 | 1.14s | 1.32 | 1.55 | Soaks burrow fire |
| Bramble | Tank | 5 | Briar Guard (forest) | 1900 | 66 | 1.10s | 1.40 | 1.50 | Reflect 30% |
| Bramble | Tank | 5 | Ember Quill (lava) | 1640 | 60 | 1.06s | 1.38 | 1.60 | Burning aura |
| Lumen | Flyer | 4 | Lumen | 330 | 50 | 1.10s | 3.65 | 2.60 | Airborne, hits flyers |
| Lumen | Flyer | 4 | Grove Owl (forest) | 500 | 62 | 1.04s | 4.35 | 2.65 | Slow, haste aura |
| Lumen | Flyer | 4 | Storm Owl (water) | 470 | 54 | 1.00s | 3.75 | 2.70 | Splash slow |
| Pip | Support | 3 | Pip | 330 | 24 | 1.08s | 2.15 | 2.50 | Heals 42 |
| Pip | Support | 3 | Lily Hopper (water) | 480 | 28 | 0.98s | 2.35 | 2.65 | Heals 70, haste aura |
| Pip | Support | 3 | Spore Frog (forest) | 460 | 34 | 1.02s | 2.45 | 2.40 | Spore splash and aura |

Dens have 3400 HP and shoot for 68. Burrows have 1800 HP and shoot for 40. Ground swings miss Lumen. Dens, burrows, and ranged critters do not.

The opponent spends sparks, answers pressure, and prefers a legal merge when it has a twin on the board.

## Run it

Godot 4.7.2 or newer. The project defaults to the Compatibility renderer so the web build can run. iOS exports with the Mobile renderer (`rendering/renderer/rendering_method.mobile`).

```
godot --path . 
```

### Web

The checked-in build is in `web/`. Threads are off, so a plain static server is enough:

```
python3 -m http.server 8941 --directory web
```

Open `http://127.0.0.1:8941`.

Rebuild with the Godot export templates installed:

```
godot --headless --path . --export-release "Web" web/index.html
```

### iOS

Bundle id `com.rico.critterclash`, display name Critter Clash, minimum iOS 15. The export preset writes an Xcode project only (`application/export_project_only`). Team id `ABCDE12345` is a placeholder so Godot will export; SideInstaller replaces the signature with your Apple ID.

`.github/workflows/ios-ipa.yml` runs on `macos-15`. It installs Godot 4.7.2 and the export templates, exports the Xcode project, archives with `CODE_SIGNING_ALLOWED=NO`, zips `Payload/*.app` into `CritterClash.ipa`, and publishes a prerelease on tag `ios-v1` (workflow dispatch does the same).

This environment cannot produce that IPA. It is Linux, so `xcodebuild` is unavailable, and the git remote is the Cursor origin rather than GitHub. The signed-in forge CLI cannot open `Rico-Rodriguez/critter-clash` or run GitHub Actions. After this project is on GitHub, run the workflow (or push the tag `ios-v1`) and the prerelease asset is `CritterClash.ipa`.

### Art and audio rebuild

Models and sound are generated, not downloaded.

```
blender --background --python tools/build_models.py
python3 tools/build_audio.py
python3 tools/make_icon.py
```

`tools/build_models.py` accepts an optional job name after `--` if you only want one mesh.

## Art pipeline

Every critter and prop is a hand-parameterized mesh built in Blender 4.5 by `tools/build_models.py`. Shapes are constructed with bmesh (spheres, tapered cones, boxes) and then sculpted by vertex transforms: belly squash, cheeks, quills, leaf manes, mist puffs, lily pads. They are not placeholder capsules left in the scene.

Each mesh is painted with vertex colors (top light, belly, blush, spots, tip gradients). Materials are simple clay, foliage, eye, and glow shaders. Eyes, mouth, wings, legs, tails, and quills are separate objects parented to a `Rig`, with a `Forward` marker so the game knows which way the face points. Evolutions add readable upgrades: flame crests, moss, leaf manes, briar plates, storm bolts, mushroom caps.

Godot imports the glTF files and replaces the materials with one toon shader (`shaders/toon.gdshader`): three cel bands, a rim in the emission, and a soft inverted-hull outline. Foliage sways from the wind uniform. The ground, river, and sky are their own shaders. The map is a height-displaced diorama: forest shoulder, lava shoulder, a sunk river, two bridges, dens, and burrows. Fireflies, embers, and petals are CPU particles.

CritterAnimator poses those parts for idle, walk, attack, hit, and death. Gaits are waddle, stomp, hop, fly, and walk. Card portraits are snapshots of the same models.

Audio is original synthesis in `tools/build_audio.py` (WAV effects, one Ogg Vorbis loop). The interface uses Nunito, under the SIL Open Font License. Nothing here is from Kenney, Quaternius, or a generative 3D service. Credits are in `CREDITS.md`.

## Project layout

- `scripts/` match, arena, units, roster, menu, field guide
- `shaders/` toon, outline, ground, water, sky
- `assets/models/` 18 critter forms plus the diorama
- `assets/audio/` effects and the music loop
- `web/` browser build
- `.github/workflows/ios-ipa.yml` unsigned IPA
