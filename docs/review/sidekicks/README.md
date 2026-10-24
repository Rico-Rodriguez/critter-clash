# Sidekick art audit (2026-10-23)

Art lock: the Paladin / Bone Knight showcase renders — clean, crisp, clear;
artist PBR untouched; grimdark subject, no chibi. Shots come from
`tools/sidekick_sheet.gd` (neutral key + rim light, no fog or post), 600x800 per
model, 30 frames into the clip.

| id | name | model before | tris | draw surfaces | texture | verdict | now |
| --- | --- | --- | --- | --- | --- | --- | --- |
| drake | Ember Drake / Ash Wyrm | Quaternius dragon / wyrm (CC0) | 4.6k / 7.4k | 5 / 5 | flat colours, none | fail: cartoon, big eyes | LasquetiSpice dragon (CC BY 4.0), 19.5k tris, 1 surface, 1024 PBR |
| wisp | Grave Wisp | Quaternius ghost (CC0) | 3.2k | 3 | none | fail: cartoon blob | Spinnee "Soulthirsty Mawko" spectral maw-fish (CC BY 4.0), 5.0k tris, 66 meshes merged to 1 surface, 1024 PBR |
| bonelet | Bonelet | KayKit Skeleton_Minion | 5.3k | 9 | 1024 palette | weak: chibi, but matches KayKit enemies | danielmclogan skeleton (CC BY 4.0), 6.8k tris, 1 surface, 1024 PBR |
| hexling | Hexling | KayKit Skeleton_Mage | 4.6k | 9 | 1024 palette | weak: chibi | Spinnee lich (CC BY 4.0), 5.6k tris, 20 meshes merged to 1 surface, 1024 PBR |
| crow | Storm Crow | Quaternius birb (CC0) | 3.2k | 5 | none | fail: round cartoon bird | Alexei Ostapenko crow (CC BY 4.0), 2.2k tris, 1 surface, 1024 PBR |
| acolyte | Acolyte | KayKit Rogue_Hooded | 7.2k | 8 | 1024 palette | weak: chibi, reads as a hero | BeardenInc plague doctor (CC BY 4.0), 6.0k tris (base removed), 1 surface, 1024 PBR |
| mimic | Gilded Mimic | KayKit chest_gold prop | 1.6k | 2 | 1024 palette | fail: a plain chest, no animation | Joseph Payeur Mimic_Chest (CC BY 4.0), 8.6k tris, 3 surfaces, 1024 PBR, bite clip |
| bat | Night Bat | Quaternius bat (CC0) | 1.0k | 6 | none | fail: cartoon | matisosanimation bat (CC BY 4.0), 5.2k tris, 3 surfaces, 1024 PBR, flap loop |
| barrow_squire | Barrow Squire | KayKit Skeleton_Warrior | 5.9k | 10 | 1024 palette | weak: chibi | EvgeshQa skeleton warrior (CC BY 4.0), 2.6k tris, 9 meshes (6 bone-parented) merged to 3 surfaces, attack clip |
| shade | Hexbound Shade | KayKit Skeleton_Rogue | 5.3k | 10 | 1024 palette | weak: chibi | Mateus Schwaab wraith (CC BY 4.0), 2.4k tris, 2 surfaces, idle + chase clips |
| sapling | Thorn Sapling | custom Blender (`tools/art/make_sapling.py`) | 1.2k | 1 | 128 px palette | fail: cute sprout, low-res | Batuhan13 treant (CC BY 4.0), 5.8k tris, 3 surfaces, 1024 PBR |

Model swaps: sapling (PR 1); drake, crow, bat and mimic (PR 2); wisp, bonelet, hexling, acolyte, barrow_squire and shade (PR 3).

Before/after per model: `drake.jpg`, `drake_evolved.jpg`, `crow.jpg`,
`sapling.jpg`, `bat.jpg`, `mimic.jpg`, `wisp.jpg`, `bonelet.jpg`, `hexling.jpg`,
`acolyte.jpg`, `barrow_squire.jpg`, `shade.jpg` (before | after idle | after move).
In game: `ingame_hexling_hunt.jpg` / `ingame_hexling_crop.jpg` (1179x2556 hunt capture, Hexling following the hero).
