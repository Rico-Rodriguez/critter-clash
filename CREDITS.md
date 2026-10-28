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

- Cinzel by Natanael Gama and the Cinzel Project Authors — titles and numbers.
  `assets/fonts/Cinzel-Variable.ttf`, license `assets/fonts/OFL-Cinzel.txt`.
- Alegreya Sans by Juan Pablo del Peral and Huerta Tipográfica — body text.
  `assets/fonts/AlegreyaSans-*.ttf`, license `assets/fonts/OFL-AlegreyaSans.txt`.

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

## Sidekicks

- Sidekick models, Creative Commons Attribution 4.0
  (https://creativecommons.org/licenses/by/4.0/), from Sketchfab. Unmodified materials; meshes merged into
  one draw per material (`tools/art/merge_skinned.py`), clips renamed or cut by time, scaled to size in
  `assets/sidekicks/*.tscn` (`tools/art/wrap_sidekicks.gd`). The Attack, Hit, Special, Run, Hover,
  Idle_Loop and Walk_Loop clips are original keyframes made for this project on the authors' own rigs
  (`tools/art/sidekick_clips.py`); the shipped clips are kept as they were:
  - Ember Drake / Ash Wyrm — "Animated Dragon Three Motion Loops" by LasquetiSpice —
    https://sketchfab.com/3d-models/animated-dragon-three-motion-loops-eca98cf6cd084c1596cecf716e110c29
    (decimated to 7.8k tris for mobile; Ash Wyrm textures baked from its base colour)
  - Storm Crow — "Crow" by Alexei Ostapenko (alexanders823) —
    https://sketchfab.com/3d-models/crow-d5a9b0df4da3493688b63ce42c8a83e2
  - Thorn Sapling — "Treant - Week 2" by Batuhan13 —
    https://sketchfab.com/3d-models/treant-week-2-aa60f5de1ed94b2e96e46ad08cde4d5a
  - Night Bat — "Bat" by matisosanimation —
    https://sketchfab.com/3d-models/bat-28af38de4d2c401d809148c7f63a73f9
  - Gilded Mimic — "Mimic_Chest" by Joseph Payeur (joseph.payeur) —
    https://sketchfab.com/3d-models/mimic-chest-a3489678d43a44a194f10f7b2cb929ce
  - Grave Wisp — "Soulthirsty Mawko" by Spinnee —
    https://sketchfab.com/3d-models/soulthirsty-mawko-832701d0918b4e5bb15408d1097b6f13
  - Bonelet — "Skeleton animated" by danielmclogan —
    https://sketchfab.com/3d-models/skeleton-animated-9210377c7a514cf6b48a31b9d3991ff3
  - Hexling — "Lich" by Spinnee —
    https://sketchfab.com/3d-models/lich-4ad4ece50273473ba1d843797b8f4fa6
  - Acolyte — "Plague Doctor" by BeardenInc (display base removed) —
    https://sketchfab.com/3d-models/plague-doctor-41f7a1dfd6984135b876f334908e3ca4
  - Barrow Squire — "Skelet_warrior" by EvgeshQa (uchaikineugene) —
    https://sketchfab.com/3d-models/skelet-warrior-1337edb8b567486aa22f15b519e60c4d
  - Hexbound Shade — "Wraith" by Mateus Schwaab (Mehrus) —
    https://sketchfab.com/3d-models/wraith-37fb72ef0c0642f68c968589fbda60d4
- Icons dragon-head, bat-wing, raven, egg-clutch, thorny-vine and fire-breath by
  Lorc, from game-icons.net, CC BY 3.0.

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
  - Frozen Effigy — "Ice Golem" by Kolbaca —
    https://sketchfab.com/3d-models/ice-golem-b618f7c8f0c7415ab5913ec2d112db62
  - Rime Seer — "Wendingo Idle" by bootlegpanda —
    https://sketchfab.com/3d-models/wendingo-idle-bd0efd5a3b9446d2948e92bd9bdf4c87
  - Winter Caller — "FREE Low-poly PSX/PS1 Wendigo/Demon model" by Ultaraga Ultra Ultronus —
    https://sketchfab.com/3d-models/free-low-poly-psxps1-wendigodemon-model-7c98d2c0a7984df2af2b5096c23e3044
  - Frost Imp — "Goblin Ghoul" by Rodrigo Bento —
    https://sketchfab.com/3d-models/goblin-ghoul-a6c6fffee3d34823b6d87a7054782577
  - Shardling — "Ice golem" by CyberDriger83 —
    https://sketchfab.com/3d-models/ice-golem-4070bce587134fe99c99df46d7b44c3a
  - Sporecap — "Mushroom Guy" by mateuszpyska —
    https://sketchfab.com/3d-models/mushroom-guy-231be56a49dc45948f47d267044d3286
  - Bogfin — "Lizardman" by DJMaesen —
    https://sketchfab.com/3d-models/lizardman-a710eb3eaeab4200a2ff83abc9b0c4db
  - Cinder Imp — "Imp" by Al (lightningocelot) —
    https://sketchfab.com/3d-models/imp-ea693fce383d4d859dd510946c5b0d4e
  - Pyre Shaman — "Lich" by Spinnee —
    https://sketchfab.com/3d-models/lich-4ad4ece50273473ba1d843797b8f4fa6
  - Mire Hag — "Parameswara Chronicles: Witch" by Dr Helmi Norman —
    https://sketchfab.com/3d-models/parameswara-chronicles-witch-3aec47eaaeae4f9693a1bb038aa86091
  - Bog Frog — "Monster frog" by Goofy goober bird —
    https://sketchfab.com/3d-models/monster-frog-2638fa13bdd647d195004bf3dc0047a7
  - Methane Bloat — "Bloater" by Vasian-Digital3D —
    https://sketchfab.com/3d-models/bloater-18e00bde1fca4cef9f39188fdfb20b1e
  - Ember Wasp — "Armored Wasp" by Rodrigo Bento —
    https://sketchfab.com/3d-models/armored-wasp-30e45b0f76d64aed8a8c587235d6f6e5
