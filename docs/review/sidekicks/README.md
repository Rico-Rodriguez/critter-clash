# Sidekick art audit (2026-10-23)

Art lock: the Paladin / Bone Knight showcase renders — clean, crisp, clear;
artist PBR untouched; grimdark subject, no chibi. Shots come from
`tools/sidekick_sheet.gd` (neutral key + rim light, no fog or post), 600x800 per
model, 30 frames into the clip.

| id | name | model before | tris | draw surfaces | texture | verdict | now |
| --- | --- | --- | --- | --- | --- | --- | --- |
| drake | Ember Drake / Ash Wyrm | Quaternius dragon / wyrm (CC0) | 4.6k / 7.4k | 5 / 5 | flat colours, none | fail: cartoon, big eyes | LasquetiSpice dragon (CC BY 4.0), 19.5k tris, 1 surface, 1024 PBR |
| wisp | Grave Wisp | Quaternius ghost (CC0) | 3.2k | 3 | none | fail: cartoon blob | unchanged (candidate needs mesh merge, see below) |
| bonelet | Bonelet | KayKit Skeleton_Minion | 5.3k | 9 | 1024 palette | weak: chibi, but matches KayKit enemies | unchanged |
| hexling | Hexling | KayKit Skeleton_Mage | 4.6k | 9 | 1024 palette | weak: chibi | unchanged |
| crow | Storm Crow | Quaternius birb (CC0) | 3.2k | 5 | none | fail: round cartoon bird | Alexei Ostapenko crow (CC BY 4.0), 2.2k tris, 1 surface, 1024 PBR |
| acolyte | Acolyte | KayKit Rogue_Hooded | 7.2k | 8 | 1024 palette | weak: chibi, reads as a hero | unchanged |
| mimic | Gilded Mimic | KayKit chest_gold prop | 1.6k | 2 | 1024 palette | fail: a plain chest, no animation | Joseph Payeur Mimic_Chest (CC BY 4.0), 8.6k tris, 3 surfaces, 1024 PBR, bite clip |
| bat | Night Bat | Quaternius bat (CC0) | 1.0k | 6 | none | fail: cartoon | matisosanimation bat (CC BY 4.0), 5.2k tris, 3 surfaces, 1024 PBR, flap loop |
| barrow_squire | Barrow Squire | KayKit Skeleton_Warrior | 5.9k | 10 | 1024 palette | weak: chibi | unchanged |
| shade | Hexbound Shade | KayKit Skeleton_Rogue | 5.3k | 10 | 1024 palette | weak: chibi | unchanged |
| sapling | Thorn Sapling | custom Blender (`tools/art/make_sapling.py`) | 1.2k | 1 | 128 px palette | fail: cute sprout, low-res | Batuhan13 treant (CC BY 4.0), 5.8k tris, 3 surfaces, 1024 PBR |

Model swaps: sapling in this PR; drake, crow, bat and mimic in the stacked follow-up PR.

Before/after per model: `drake.jpg`, `drake_evolved.jpg`, `crow.jpg`,
`sapling.jpg`, `bat.jpg`, `mimic.jpg` (before | after idle | after move).
