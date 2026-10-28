# Third-party art audit

Written 2026-10-28 (Phase 3 of the plan). Scope: every model under `assets/foes`,
`assets/sidekicks` and `assets/critters` that is not KayKit, Quaternius or made for this
project. The KayKit and Quaternius packs are CC0 from their authors and are not listed.

CC BY 4.0 on a Sketchfab page is the uploader's claim. It is only as good as their right to
license the model. A model lifted from a commercial game, or a re-upload of another artist's
work, carries no real licence, whatever the page says. This audit looks for the signs of that
from the title, the format and what the credit already says. **It could not open the Sketchfab
pages**, so a verdict of "check" means "a person should open the page and look at the
description and the uploader's other work before an App Store build".

## Removed in this audit

| Model | Was | Why | Replaced by |
| --- | --- | --- | --- |
| "The Elder Scrolls Blades Nether Lich" by orangesauceu | Rime Seer | Named after a Bethesda game; almost certainly ripped from it. | KayKit `Skeleton_Mage`, rime skin, staff |
| "Frost Troll" by moonbaby2402 | Rimehollow boss | Its own credit said it was a probable re-upload of "Monster" by itszyx123456789 (same 11,271 faces, same Mixamo rig, no original credited). | The Rime Regent, KayKit `Skeleton_Warrior`, regent skin |
| "Dragonfly Chicken Gun" by babybuttred2 | Cinder Mire dragonfly critter | Named after the commercial mobile game Chicken Gun. | A dragonfly drawn in code from flat primitives |

## Keep, but check before an App Store build

| Model | Used as | Signal | What to look at |
| --- | --- | --- | --- |
| "Bloater" by Vasian-Digital3D | Methane Bloat | "Bloater" is the name of a Last of Us infected. The uploader's "Banshee" (the Wail Wraith) is also a named creature. | Whether the model is a fan recreation of the game's creature. If so, replace it. |
| "Cursed Undead Soldier Rig" by SuperKapoo913 | Frozen Effigy | A "rig" upload with no author notes in the title. | Whether it is the uploader's own mesh. |
| "THE ABOMINABLE SNOWMAN (READ DESC)" by toro ardido modelos 3d | `assets/foes/rime_yeti.tscn`, the Rime Yeti | The title tells readers to read the description, which usually holds a usage condition. | Read the description. The CREDITS note that the shipped yeti is "Lowpoly bigfoot" by Sololopenko, so one of the two entries may be stale. |
| "Parameswara Chronicles: Witch" by Dr Helmi Norman | Mire Hag | Named after a game project. | Whether Dr Norman's project is the source, and whether they made the upload. |
| "FREE Low-poly PSX/PS1 Wendigo/Demon model" by Ultaraga Ultra Ultronus | Winter Caller | PSX-style packs are often recreations of console-game monsters. | Whether it recreates a game character. |
| "Soulthirsty Mawko" by Spinnee | Grave Wisp sidekick | Reads like a game-creature name. The same uploader's "Lich" is used twice (Hexling, Pyre Shaman). | The uploader's other models for a pattern. |

## Low risk (generic subject, a named author, no franchise in the title)

| Model | Author | Used as |
| --- | --- | --- |
| "Low-poly orc" | Riltariki | Cinder Warlord (boss) |
| "WILD WOLF" | jbnotjeebe | Frost Wolf |
| "Lowpoly bigfoot" | Sololopenko | Rime Yeti |
| "Nightmare Creature 1#" | Rodolfoisreal1423 | Frost Imp |
| "Ice golem" | CyberDriger83 | Shardling |
| "Mushroom Guy" | mateuszpyska | Sporecap |
| "Lizardman" | DJMaesen | Bogfin |
| "Imp" | Al (lightningocelot) | Cinder Imp |
| "Monster frog" | Goofy goober bird | Bog Frog |
| "Armored Wasp" | Rodrigo Bento | Ember Wasp |
| "Animated Dragon Three Motion Loops" | LasquetiSpice | Ember Drake / Ash Wyrm |
| "Crow" | Alexei Ostapenko | Storm Crow, crow critter |
| "Treant - Week 2" | Batuhan13 | Thorn Sapling |
| "Bat" | matisosanimation | Night Bat |
| "Mimic_Chest" | Joseph Payeur | Gilded Mimic |
| "Skeleton animated" | danielmclogan | Bonelet |
| "Lich" | Spinnee | Hexling, Pyre Shaman |
| "Plague Doctor" | BeardenInc | Acolyte |
| "Skelet_warrior" | EvgeshQa | Barrow Squire |
| "Wraith" | Mateus Schwaab | Hexbound Shade |
| "Hare (animated)" | bluekiwi.dog | Snow hare critter |
| "Day 20 - Snowy Owl" | Lilly! | Snowy owl critter |
| "Stylized Wolf" | ESO | Ridge wolf critter |
| "Green Frog" | lawtrigg | Bog frog critter |

## Unused scenes

`assets/foes/bloat*` and `spore*` (the code-built models the Blender ones replaced) were removed in Phase 5. The generator is still `tools/art/make_foes.py`.

## Rule for new models

A model goes in only with: a source link, an author, a licence on the page, a check that the
title names no commercial game or character, and a row here. `CLAUDE.md` says so.
