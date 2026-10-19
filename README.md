# Critter Clash

A portrait hero-run in Godot 4.7.2. Pick one critter, steer it through a biome, and defeat the boss. Bosses drop loot. They do not become heroes.

The game is free. There are no ads, no in-app purchases, and no paid currency. A critter's role never changes because of where it stands. Roles are fixed on the critter.

This is an original game. It does not use Supercell names, interface layouts, or assets.

## Play

From home, open a biome and pick one unlocked hero. A hunt is one hero in a portrait arena and lasts under two minutes.

Drag anywhere on the lower part of the screen. A thumbstick appears under your finger and the hero follows it. On a desktop, WASD or the arrow keys steer the same way. The hero attacks the nearest wild critter on its own.

Wild critters walk in from the edges. Gems they drop fill a shared XP bar. Each level-up pauses the hunt and offers three upgrade cards. Cards have colored frames: common, rare, epic, and legendary. Some epic cards belong to one role only:

| Role | Exclusive cards |
| --- | --- |
| Mage | Wider splash, hotter splash |
| Archer | Pierce |
| Tank | Thorns, shield bash |

Shared cards cover health, regen, attack speed, ricochet, multishot, move speed, crit, armor, and a legendary second wind.

Around 68 seconds the minions leave and the biome boss arrives. It telegraphs area circles, a charge lane, and a fan of projectiles. Dodge those. Defeat the boss to win. Losing the hero, or still fighting at 119 seconds, ends the hunt.

On a win the boss rolls a drop table and you still bring a hunt chest home. The clear is saved as soon as the boss falls.

## Boss drops

Each boss has a weighted table of common, uncommon, rare, and very rare loot: coins, critter cards, gear, and crafting materials. A boss pet is a separate roll at 1/50 (`Catalog.PET_RATE`). Pets are cosmetic. The active pet follows your hero in a hunt and does not fight. A pet or a very rare drop plays a gold beam and a fanfare before the loot list.

The collection log lists every drop and pet, 48 in all. Unobtained pictures are silhouettes. The header shows an obtained count such as 12/48, and each boss tab shows that boss's kill count.

## Slayer

The slayer master offers tasks such as "Defeat 40 Meadow critters" or "Defeat Gravemaw". Progress counts the critters you defeat in that biome, and a boss task counts that boss. Turning a task in pays slayer points plus 5 points for each task already in the streak. Cancelling a task resets the streak. The points shop sells a rare charm, a trail ribbon for the home pedestal, and a hunt chest.

## Skills

Woodcutting, Fishing and Mining are saved as XP for the account. Levels run from 1 to 99 on the same curve as Old School RuneScape (83 XP to reach level 2, 13,034,431 XP to reach level 99). Gathering is still being built: the worlds now carry resource nodes, walking up to one works it for XP and materials, and the skills screen keeps its "arrive soon" placeholder. The materials it pays, and the boss materials, share one bag: the Skills screen has a Materials tab that lists them and sells them for a few coins each. The contract is in `docs/gathering.md`.

## Heroes

| Critter | Role | How you get them |
| --- | --- | --- |
| Ember, dragon | Mage, fire splash | Starter |
| Juniper, fox | Archer | Starter |
| Pebble, otter | Tank, melee | Starter |
| Lumen, owl | Archer | Trophy road |
| Pip, frog | Mage | Trophy road |
| Bramble, hedgehog | Tank | Trophy road |

Gravemaw (a corrupted barrow troll, id `thistle`), Nightmaw (a blighted rot-wolf, id `caplet`), Nimbus, and Cinder are bosses. They stay in the world.

## World and the road

Biomes open in order. Meadow is open from the start. Mushroom Forest needs a Meadow clear and 30 trophies. Frost Peaks needs Mushroom Forest and 80. Ember Volcano needs Frost Peaks and 150. The first clear of a biome is worth 30 trophies. A repeat clear is worth 16.

The trophy road spends those trophies on coins, a chest, Lumen, Pip, Bramble, and gear.

## Between hunts

A win brings home a hunt chest. A loss brings a smaller pouch. Chests pay coins, critter cards for heroes you already own, and sometimes a piece of gear.

Card level works like a collection card game. Duplicates and coins raise a critter from level 1 to 10. Level 2 costs 2 cards and 15 coins, and each level asks for more. Health and damage grow by 8% per level.

Each critter has a weapon slot, an armor slot, and a charm slot. A piece can only be worn by one critter. Weapons roll damage and attack speed, armor rolls health and armor, charms roll crit, move speed, or regen.

Progress is stored on the device at `user://critter_clash.json`.

## Maps

Each biome is data: a pixel size, a chunk grid, spawn zones, and a boss arena point (`HuntMap`). The hunts you can play today are one screen, 720×1280. That record is a single chunk and a single zone covering the playfield, with the boss at the top of the zone. A later map can be about four screens by four screens — sixteen times the area — by filling the same record. The fight does not assume the zone is the whole screen.

The simulation stores a follow camera for when maps grow. Inside a soft deadzone that camera stays still; past that edge it eases after the hero, and it never slides outside the map. On a one-screen map the view and the map are the same size, so that camera stays put. The picture you see is a separate 3D camera: it always frames the hero from about 55 degrees above, with the same deadzone and the same clamp, even on today's small map. The heads-up display is not parented to the world, so it does not scroll.

Only chunks that overlap the view, plus a small margin, are instanced. The 3D hunt draws one terrain mesh and a MultiMesh of grass and flowers for the whole clearing, and it keeps trees and rocks around the rim. The chunk stream is still in the project for the larger maps. A 4×4 map does not build all sixteen chunks at once.

Wild critters spawn on the rim of the zone nearest the hero, not on the edge of the screen. With one zone, that rim is the edge of the playfield.

## Later modes

The launch build is single-player. The hunt itself does not know about buttons or sprites. `Session` can describe a solo hunt, a co-op pair that shares a team, or a duel. `RunBot.steer` is the stand-in brain for a future rival. The save keeps an unused `clan_id`. None of those modes have a screen yet.

## World in 3D

The hunt and the home pedestal are a 3D view. The fight itself is still the flat simulation, so steering, waves, cards, and clear times are unchanged.

Desktop and the screenshot capture use Forward+. iOS export uses the Mobile renderer and Metal (`--rendering-method mobile --rendering-driver metal`). The camera sits about 55 degrees above the hero. A warm sun casts cascaded shadows (four splits on a desktop GPU, two on iOS and on software renderers). A cool rim light fills the shadow side. The sky is a Poly Haven HDRI. Tonemap is ACES, with a little bloom and height fog. SSAO and SDFGI turn on only for the high tier, which is a real desktop GPU. iPhones and lavapipe stay on the medium tier so the target stays 60fps.

The ground is one shader over a baked blend of ambientCG grass, dirt, and rock, with the height map pushed into the vertices. Grass, flowers, ferns, and clover are MultiMesh instances and do not cast shadows. Trees, bushes, and rocks around the clearing do.

Ember is a dragon, Juniper a fox, Pebble an otter, Lumen an owl, Pip a frog, and Bramble a cactus-hog. Ember, Juniper, and the meadow boss Thistle use CC-BY Sketchfab models (a stylized dragon, the KAI fox, and a mushroom boss). The meadow rim uses the Nature Vegetation Pack. Pebble, Lumen, Pip, and Bramble stay on CC0 meshes. Minions reuse those rigs, tinted with the critter's color. The home screen opens an in-game Credits list with the CC-BY title, author, URL, and license. Footstep dust and hit sparks are GPU particles.

## Run it

Godot 4.7.2. Desktop uses Forward+. iOS uses the Mobile renderer and Metal.

```
godot --path .
```

Headless check of roles, the save, and three Meadow hunts:

```
godot --headless --path . --import --quit
godot --headless --path . -- --sim-check
```

The first command fills the class cache. The second prints `SIM CHECK PASSED` and exits 0 when Ember, Juniper, and Pebble can clear the Meadow inside the hunt window, and a hero who never moves loses.

### iOS

Bundle id `com.rico.critterclash`, display name Critter Clash, minimum iOS 15, version 1.1.0. The export preset writes an Xcode project only (`application/export_project_only`). Team id `ABCDE12345` is a placeholder so Godot will export.

`.github/workflows/ios-ipa.yml` runs on `macos-26` for pushes to `main` and for workflow dispatch. The Godot 4.7.2 iOS template links Metal symbols from the iOS 26 SDK, so an older Xcode cannot archive it. The workflow installs Godot 4.7.2 and the export templates, imports assets headless (10 minute limit), then exports with the Mobile renderer and Metal (20 minute limit). The iOS shader baker is off, because baking the 3D materials hung the export. Shaders compile on device. The job archives with signing turned off, zips `Payload/*.app` into `CritterClash.ipa`, and publishes that file on the `ios-v1` prerelease.

### Web

There is no checked-in web build. With export templates installed:

```
godot --headless --path . --export-release "Web" web/index.html
python3 -m http.server 8941 --directory web
```

## Portraits

The world is the 3D cast in `assets/models/`. Kenney pictures remain only for interface portraits: the hunt medallion, collection cards, the collection log, and the slayer panel. `tools/build_sprites.py` overwrites those portraits with procedural stand-ins, so leave it alone.

Critter ids: `ember`, `juniper`, `pebble`, `lumen`, `pip`, `bramble`, `thistle`, `caplet`, `nimbus`, `cinder`, `sprout`, `beetle`, `moth`, `boarlet`, `capling`, `spore`, `glowmoth`, `puddle`, `snowpup`, `shard`, `icewisp`, `yeti`, `cindling`, `skink`, `ashbat`, `magmash`.

Biome ids: `meadow`, `mushroom`, `frost`, `volcano`.

## Project layout

- `scripts/` hunt simulation, map data, follow camera, chunk stream, 3D stage, screens (including the collection log, slayer master, and skills stub), save, portrait loader
- `assets/models/` licensed critter and nature GLBs
- `assets/textures/` baked ground maps, the sky HDRI, and the dust puff
- `shaders/terrain.gdshader` ground blend
- `assets/sprites/` Kenney portraits and generated interface effects
- `assets/audio/` the licensed effects, the synthesized effects and the music loops
- `assets/fonts/` Nunito for body copy, Lilita One for titles, numbers, and buttons
- `tools/build_sfx.py`, `tools/build_sfx_synth.py`, `tools/check_sfx.py` and `tools/make_icon.py`
- `.github/workflows/ios-ipa.yml` unsigned IPA

## Art and audio rebuild

Sound and the icon are generated:

```
python3 tools/build_sfx.py        # the licensed packs, trimmed and layered
python3 tools/build_sfx_synth.py  # the moments the packs do not cover
python3 tools/check_sfx.py        # every clip exists, is played, and is not silent
python3 tools/make_icon.py
```

`tools/build_sfx.py` needs the source packs downloaded (see `CREDITS.md`);
`tools/build_sfx_synth.py` draws its clips from oscillators and noise, and
leaves any clip already on disk alone so a rebuild does not churn the
resource uids.

Licenses are in `CREDITS.md`.
