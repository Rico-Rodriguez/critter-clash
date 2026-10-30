# Credits

Barrowfall is an original game. Code, design and shaders are original. Everything
below is free to use under the license given; nothing here was paid for.

## Engine

- Godot Engine 4.7.2 — https://godotengine.org — MIT License.

## 3D art — KayKit by Kay Lousberg (CC0)

All characters, animations, weapons and props are from KayKit by Kay Lousberg
(www.kaylousberg.com), released under Creative Commons Zero (CC0 1.0). Crediting
is not required; we do it anyway. Each pack's license file is kept beside the
files in `assets/kaykit/`.

- KayKit : Adventurers Character Pack 2.0 (Free) — Knight, Ranger, Mage, Barbarian
  and their weapons — https://kaylousberg.itch.io/kaykit-adventurers
- KayKit : Skeletons Character Pack 1.1 (Free) — every enemy, and Gravemaw (the
  Skeleton Warrior at 2.6× scale) — https://kaylousberg.itch.io/kaykit-skeletons
- KayKit : Character Animations 1.1 (Free) — the shared Rig_Medium animation set,
  baked into `assets/kaykit/animations/rig_medium_lib.res` by `tools/bake_anims.gd`
  — https://kaylousberg.itch.io/kaykit-character-animations
- KayKit : Halloween Bits 1.0 (Free) — the graveyard: crypt, graves, fences,
  lanterns, dead trees, bones — https://kaylousberg.itch.io/halloween-bits
- KayKit : Forest Nature Pack 1.0 (Free) — trees, rocks, bushes, grass —
  https://kaylousberg.itch.io/kaykit-forest
- KayKit : Dungeon Pack Remastered 1.1 (Free) — chests, coins, barrels, camp
  props — https://kaylousberg.itch.io/kaykit-dungeon-pack
- KayKit : Fantasy Weapons Bits 1.0 (Free) — hammers, maces, double axes, the
  halberd, claymore, rapier, crystal staff and wand, recurve bows, the plank,
  crest and bulwark shields — https://kaylousberg.itch.io/fantasy-weapons-bits

## 3D art — our own

The weapon skins (Oathbound Blade, Reaper's Scythe) were modeled for this game
by the scripts in `tools/art/`, run with Blender's Python module, and use the
KayKit knight texture above for their colors.

## VFX textures — our own (CC0)

Every sprite, decal and telegraph edge under `assets/vfx/` (flame flipbook,
embers, sparks, ice shards, snowflakes, bubbles, spores, leaves, light rays,
shadow wisps, bone chips, debris, dust, blood, crosses, chevrons, the six
ground decals and the eight telegraph edge strips) is drawn from code by
`tools/art/vfx_textures.py` for this game. No third-party art is used; we
release them under CC0 1.0.

## Icons — game-icons.net (CC BY 3.0)

Interface and card icons in `assets/icons/` are from https://game-icons.net,
licensed under Creative Commons Attribution 3.0
(https://creativecommons.org/licenses/by/3.0/). Downloaded as white SVGs, otherwise
unchanged. Authors:

- Lorc — https://lorcblog.blogspot.com — most icons (crossed-swords, broadsword,
  fireball, magnet, ghost, cog, trophy, scroll-unfurled, sprint, spinning-blades,
  arrow-cluster, lightning-helix, crystal-shine, checked-shield, sword-wound,
  bolt-shield, explosion-rays, barbed-arrow, high-shot, ice-bolt, frozen-orb,
  spinning-sword, battle-axe, wizard-staff, pocket-bow, visored-helm, crowned-skull,
  dripping-sword, hourglass, stopwatch, skull-crossed-bones, bone-gnawer, fire-ring,
  meteor-impact, arrow-flights, heavy-arrow, broken-bone, back-forth, padlock,
  locked-chest, swap-bag, book-cover, rune-stone, castle, gems, diamond-hard,
  gem-pendant, breastplate, crossed-axes, slashed-shield, fist, wolf-head, anvil,
  sword-smithing, strong, muscle-up, fairy-wand, magic-swirl, archery-target,
  arrow-scope, lightning-tear, heart-organ, cloak-dagger, sun, moon, campfire,
  tombstone, glowing-hands, sword-spin, whirlwind, pointy-hat, hood, robe,
  trousers, leather-vest, horned-helm, conversation, two-shadows, magnifying-glass,
  scythe)
- Delapouite — https://delapouite.com — two-coins, running-shoe, upgrade,
  round-star, house, padlock-open
- Skoll — bullseye, open-treasure-chest
- Zeromancer — heart-plus
- Carl Olsen — flame
- Sbed — shield, health-normal
- Guard13007 — pause-button

## Fonts (SIL Open Font License 1.1)

- Cormorant SC by Christian Thalmann (Catharsis Fonts) — names and titles.
  `assets/fonts/CormorantSC-Bold.ttf`, license `assets/fonts/OFL-CormorantSC.txt`.
- Barlow Condensed and Barlow Semi Condensed by Jeremy Tribby — buttons, numbers and body text.
  `assets/fonts/Barlow*.ttf`, license `assets/fonts/OFL-Barlow.txt`. `GravelightCaps-Bold.ttf` is
  Barlow Condensed Bold with lowercase mapped to capitals (`tools/caps_font.py`), same licence.
- Alegreya Sans by Juan Pablo del Peral and Huerta Tipográfica — the boot screen.
  `assets/fonts/AlegreyaSans-Medium.ttf`, license `assets/fonts/OFL-AlegreyaSans.txt`.

## Music (CC BY 4.0)

- "Achaidh Cheide" (camp), "Heroic Age" (hunt) and "Five Armies" (boss) by Kevin
  MacLeod (incompetech.com). Licensed under Creative Commons: By Attribution 4.0 —
  https://creativecommons.org/licenses/by/4.0/ . Re-encoded to OGG and
  loudness-matched; otherwise unchanged.
- "Volatile Reaction" (Endless Descent), "Crypto" (rifts), "Darkest Child" (the
  Hollow Grove) and "Curse of the Scarab" (the Thornmother) by Kevin MacLeod
  (incompetech.com), same license. Trimmed to about 105 s, loudness-matched to
  the other tracks and re-encoded to OGG.
- Second and third camp, hunt and boss tracks (`home_2`, `home_3`, `hunt_2`,
  `hunt_3`, `boss_2`; one is picked per visit, never the same twice running):
  "Teller of the Tales", "Lord of the Land", "Clash Defiant", "Crusade" and
  "Final Battle of the Dark Wizards" by Kevin MacLeod (incompetech.com), same
  license. Trimmed to 2–3 minutes with fades, loudness-matched (−16.5 LUFS)
  and re-encoded to OGG.
- The Frozen Crypt and Burning Swamp (`frozen`, `frozen_boss`, `swamp`, `swamp_boss`),
  all by Kevin MacLeod (incompetech.com), same license: "Night Vigil" (Crypt),
  "Eternal Terminal" (Rime Regent), "Static Motion" (Swamp) and "Burnt Spirit" (Cinder
  Ogre). Cut to loops of 70-98 s with the tail crossfaded into the lead-in so they wrap
  without a seam, loudness-matched (-16.5 LUFS) and re-encoded to OGG by
  `tools/audio/build_biome_music.py`; otherwise unchanged.
- Victory sting: "Victory Fanfare Short" by cynicmusic —
  https://opengameart.org/content/victory-fanfare-short — CC0 (trimmed).

## Boss stings (CC BY 4.0)

The hit that lands with each boss's name card (`boss_sting_<boss>.ogg`) is cut from Kevin
MacLeod's (incompetech.com) "Danse Macabre - Big Hit 1", "Danse Macabre - Big Hit 2" and
"Darkness Speaks", Creative Commons: By Attribution 4.0
(https://creativecommons.org/licenses/by/4.0/). Trimmed, pitched or filtered per boss, with
the CC0 `boom` effects layered under the heavy ones, loudness-matched and re-encoded to OGG by
`tools/audio/build_boss_stings.py`. ("Danse Macabre" is Saint-Saëns, public domain; the
recording is MacLeod's.)

## Sound effects

Licensed (CC0), trimmed and layered:

- Kenney (www.kenney.nl): Impact Sounds, Interface Sounds, UI Audio, RPG Audio,
  Casino Audio, Music Jingles — https://kenney.nl/assets
- rubberduck on OpenGameArt: "80 CC0 RPG SFX", "80 CC0 creature SFX",
  "100 CC0 SFX", "100 CC0 SFX #2" — https://opengameart.org/users/rubberduck
- trazzz123 — "CC0 Deep Monster Roar" — https://opengameart.org/content/cc0-deep-monster-roar
- Darsycho — "Monster snarls" — https://opengameart.org/content/monster-snarls

Some effects (swings, dashes, novas, chain lightning, thorns, hit contacts,
the Barbarian's spin, fire bolts and similar) were
synthesized from oscillators and noise for this project and are original work.
Layered hits and the adaptive music (`src/autoload/sfx.gd`) reuse the files
above. The one new sound, a low "thump" under heavy hits, is synthesized in
code at start-up (a falling sine with a short noise tick): original, no file, no
license. The adaptive music is a low-pass and level on the Music bus driven by
how many fight sounds are playing; it changes no music files.

The scripts that built the audio are are kept in `tools/audio/`.

## Ambience — Rimehollow and the Cinder Mire (CC0)

Beds and one-shots in `assets/audio/ambient/`, cut and loudness-matched by
`tools/audio/build_ambience.py`. All sources are CC0 from OpenGameArt:

- Écrivain — "Icy Heights" (the wind loop): the Rimehollow bed and gusts —
  https://opengameart.org/content/icy-heights
- wipics — "Winter Wind": more gusts — https://opengameart.org/content/winter-wind
- LokiF — "Swamp Environment Audio": the Cinder Mire bed and bubbling —
  https://opengameart.org/content/swamp-environment-audio
- EZduzziteh — "Frog Croaks" and "Ribbit Frog Sounds" —
  https://opengameart.org/content/frog-croaks ,
  https://opengameart.org/content/ribbit-frog-sounds
- zeroisnotnull — "Crow caw" — https://opengameart.org/content/crow-caw
- AntumDeluge — "Fire Crackling" (the ember pops) —
  https://opengameart.org/content/fire-crackling

The ice creaks and drips are synthesized for this project (original work, no
file source). The critters (hares, owls, wolves, frogs, dragonflies, crows,
methane bubbles, fish rings) are drawn in code from flat-coloured primitives.

## Sidekicks

- Ember Drake / Ash Wyrm, Grave Wisp, Storm Crow, Gilded Mimic, Night Bat, Thorn Sapling, Hexbound
  Shade, Acolyte and Barrow Squire: original,
  made for this project in Blender from code (`tools/blender/pets/drake.py`, `wisp.py`, `crow.py`,
  `mimic.py`, `bat.py`, `sapling.py`, `shade.py`, `acolyte.py`, `squire.py`): models,
  skeletons, clips and textures. The traits bred pets wear (horns, crests, lures, crowns...) are
  made the same way (`tools/blender/pets/traits.py`).
- Bonelet: the KayKit Skeleton_Minion (CC0, see the KayKit entry) at the heroes' adult build, with
  KayKit clips, a red mantle and a femur made in Blender (`tools/blender/pets/bonelet.py`).
- Hexling: the KayKit Rogue_Hooded (CC0) at the heroes' adult build, cloth re-dyed violet, with
  KayKit clips and a staff made in Blender (`tools/blender/pets/hexling.py`).
- Icons dragon-head, bat-wing, raven, egg-clutch, thorny-vine and fire-breath by
  Lorc, from game-icons.net, CC BY 3.0.

## Zone prop kits (own work)

- Rimehollow props and set pieces in `assets/kits/rime/rime_kit.glb`: cliffs, boulders, crystals, ice
  blocks, pines, longship, ice-fisher's hut, sled, snow banks, fishing-hole rim, ice arch, frozen
  effigy and the Glacier Throne. Modelled for this project in Blender by script
  (`tools/art/make_rime_kit.py`, `tools/art/kit_lib.py`), no third-party meshes, textures or
  sources; every piece shares one 256 px palette texture generated by the same script. Original work
  of the project, released with it.
- Cinder Mire props and set pieces in `assets/kits/mire/mire_kit.glb`: boardwalk planks (straight, end,
  corner, tee), piles, rail, rope bridge, jetty, boat shed, stilt shacks (whole and burnt), the Pyre
  Tree, the stilted forge with its cauldron and hook post, braziers, reeds, bog stones, dead
  mangroves, charred stumps, a wrecked riverboat and a skull totem. Same method and licence as the
  Rimehollow kit (`tools/art/make_mire_kit.py`), one 256 px palette texture generated by the script.
- Long Road room kits in `assets/kits/rime/road_kit.glb` (glacier wall faces, rock ramparts, gate
  posts, ice pillars, boss-hall crystal spires, a frozen standard, a skull cairn, buried crates, a
  frost beacon) and `assets/kits/mire/road_kit.glb` (scorched rock walls, stake palisades, coal-basket
  gate posts, a burnt watchtower, a gibbet cage, barricades, tar barrels, supply crates, ash rocks,
  dead snags, a fire pit). Same method and licence as the zone kits (`tools/art/make_rime_road_kit.py`,
  `tools/art/make_mire_road_kit.py`), each with its own 256 px generated palette texture.

## Bosses and foes

- Boss and foe models in `assets/foes/`, Creative Commons Attribution 4.0
  (https://creativecommons.org/licenses/by/4.0/), from Sketchfab. Unmodified materials (the artist's
  specular/glossiness PBR is carried over untouched), meshes merged into one draw per material
  (`tools/art/merge_skinned.py`), collapse-decimated for mobile with weights, UVs and clips kept
  (`tools/art/decimate_skinned.py`), each clip moved to start at 0, scaled to size in
  `assets/foes/*.tscn` (`tools/art/wrap_foes.gd`):
  - Cinder Warlord — "Low-poly orc" by Riltariki —
    https://sketchfab.com/3d-models/low-poly-orc-62f1637181cb4f6aa38897f5b7ab5edf
    (decimated from 21.6k to 11.4k tris; textures as shipped, 1024 px)
  (Rimehollow and Cinder Mire foes: CC BY 4.0 from Sketchfab, `tools/art/foe_pipeline.sh`: clips pruned and
  retimed, keyframes reduced, textures shrunk to at most 1024 px, meshes merged and decimated; materials unmodified)
  - Frost Wolf — "WILD WOLF" by jbnotjeebe —
    https://sketchfab.com/3d-models/wild-wolf-eba254adc5d44341b150bb4086d4b662
  - Rime Yeti — "THE ABOMINABLE SNOWMAN (READ DESC)" by toro ardido modelos 3d —
    https://sketchfab.com/3d-models/the-abominable-snowman-read-desc-75699f1d63e94e23b40a73df6a3d65b8
  - Wail Wraith — "Banshee" by Vasian-Digital3D —
    https://sketchfab.com/3d-models/banshee-690b8bb555fc4d20aba4e169c3220bb8
  - Frozen Effigy — "Cursed Undead Soldier Rig" by SuperKapoo913 —
    https://sketchfab.com/3d-models/b2e39de76b834d978adee5716aec814d
  - Winter Caller — "FREE Low-poly PSX/PS1 Wendigo/Demon model" by Ultaraga Ultra Ultronus —
    https://sketchfab.com/3d-models/free-low-poly-psxps1-wendigodemon-model-7c98d2c0a7984df2af2b5096c23e3044
  - Frost Imp — "Nightmare Creature 1#" by Rodolfoisreal1423 —
    https://sketchfab.com/3d-models/9fb509d207d744babeb5d87a486f7de1
  - Shardling — "Ice golem" by CyberDriger83 —
    https://sketchfab.com/3d-models/ice-golem-4070bce587134fe99c99df46d7b44c3a
  - Sporecap — "Mushroom Guy" by mateuszpyska —
    https://sketchfab.com/3d-models/mushroom-guy-231be56a49dc45948f47d267044d3286
  - Bogfin — "Lizardman" by DJMaesen —
    https://sketchfab.com/3d-models/lizardman-a710eb3eaeab4200a2ff83abc9b0c4db
  - Cinder Imp — "Imp" by Al (lightningocelot) —
    https://sketchfab.com/3d-models/imp-ea693fce383d4d859dd510946c5b0d4e
  - Mire Hag — "Parameswara Chronicles: Witch" by Dr Helmi Norman —
    https://sketchfab.com/3d-models/parameswara-chronicles-witch-3aec47eaaeae4f9693a1bb038aa86091
  - Bog Frog — "Monster frog" by Goofy goober bird —
    https://sketchfab.com/3d-models/monster-frog-2638fa13bdd647d195004bf3dc0047a7
  - Methane Bloat — "Bloater" by Vasian-Digital3D —
    https://sketchfab.com/3d-models/bloater-18e00bde1fca4cef9f39188fdfb20b1e
  - Ember Wasp — "Armored Wasp" by Rodrigo Bento —
    https://sketchfab.com/3d-models/armored-wasp-30e45b0f76d64aed8a8c587235d6f6e5

## Ambient critters — Rimehollow and the Cinder Mire (CC BY 4.0)

Animated wildlife in `assets/critters/` (`src/hunt/ambience.gd`), all CC BY 4.0 from Sketchfab, run through
`tools/art/foe_pipeline.sh` (clips pruned, keyframes reduced, textures shrunk, decimated); the game tints the frog's
albedo a shade duller. The dragonflies, methane bubbles and fish rings are drawn in code.

- Snow hare — "Hare (animated)" by bluekiwi.dog —
  https://sketchfab.com/3d-models/hare-animated-948938cd237d49a9868662213fa05543
- Snowy owl — "Day 20 - Snowy Owl" by Lilly! (LillyanneTr) —
  https://sketchfab.com/3d-models/day-20-snowy-owl-745c105544784b9a80bbec49cccd1580
- Ridge wolf — "Stylized Wolf" by ESO (ESOOOO) —
  https://sketchfab.com/3d-models/stylized-wolf-2b369cacbd3a4d19b39353f6cf60b8a9
- Bog frog (critter) — "Green Frog" by lawtrigg —
  https://sketchfab.com/3d-models/green-frog-5902f063c7a4406aa6f93f9da56a0510
- Crow — "Crow" by Alexei Ostapenko (alexanders823) —
  https://sketchfab.com/3d-models/crow-d5a9b0df4da3493688b63ce42c8a83e2
  - Rimehollow foe, Rime Yeti — "Lowpoly bigfoot" by Sololopenko (CC BY 4.0, listed on the Sketchfab API
    2026-10-27) — https://sketchfab.com/3d-models/lowpoly-bigfoot-a85b050494a14d8aa7a5a94c82a6176c
    (decimated from 3.4k to 2.8k tris; its texture as shipped, 1024 px; the shipped take is Idle, the other
    clips — Walk, Run, Attack, Slam, Roar, Hit, Death — are keyframed for this project on its Mixamo rig,
    `tools/art/boss_clips.py`)
- Foe models in `assets/foes/`, public domain (CC0 1.0), no attribution required, credited anyway:
  - Frost Wolf — "Wolf" by Quaternius (via Poly Pizza) — https://poly.pizza/m/P1gU3Qkr9r
  - Wail Wraith (recoloured frost blue) and Pyre Shaman — "Ghost Skull" by Quaternius —
    https://poly.pizza/m/TX8r9WBXpe
  - The Quaternius models are flat-colour factor materials; each is merged to one material with a palette
    texture of the same colours (`tools/art/palette_merge.py`; the Wraith swaps two palette colours),
    decimated to under 3k tris (`tools/art/decimate_skinned.py`), scaled in `assets/foes/*.tscn`.
  - Crystal Shardling, Methane Bloat and Sporecap: custom Blender models for this project, built by
    `tools/art/make_foes.py` (CC0).
