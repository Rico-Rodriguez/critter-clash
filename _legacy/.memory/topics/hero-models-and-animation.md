# Hero models, gear and animation

- 2026-10-20 — Every playable class points at a real model: `res://assets/models/heroes_new/<class>/<class>.tscn` — `scripts/cast3d.gd` (`HEROES`)
- 2026-10-20 — Class ids: `barbarian, paladin, sorceress, rogue, necromancer, druid` — `scripts/catalog.gd`
- 2026-10-20 — GLB to class map (source rigged meshes, skeleton only, no clips): barbarian `A_hyper_realistic_3D__0209190244.glb`, paladin `Create_a_hyper_realis_0208174531.glb`, sorceress `A_hyper_realistic_3D__0210165820.glb`, rogue `Create_a_hyper_realis_0208065556.glb`, necromancer `Create_a_hyper_realis_0209045850.glb`, druid `Create_a_hyper_realis_0205160341.glb` — `assets/models/heroes_rigged/`
- 2026-10-20 — Retarget tool generalised: source-bone renaming, per-map source lookup, clips read from a file — `tools/retarget.gd`, `tools/hero_clips.json`
- 2026-10-20 — Baked 10 clips per class (idle, walk, run, attack, hit, death, cast, block, bash, dodge) from the paladin source rig onto all six rigs — `assets/models/heroes_new/<class>/<class>_anims.res`
- 2026-10-20 — Wrapper scenes for each class (rigged GLB + `AnimationPlayer` holding the baked library) — `assets/models/heroes_new/<class>/<class>.tscn`
- 2026-10-20 — Verified every hero loads with 1 skeleton and 10 clips, that idle moves the bones, and that the retarget maps 12/12 joints (worst dot 0.99)
- 2026-10-20 — Retired hero ids aligned with `Catalog.RETIRED_HEROES`: juniper→rogue, pip→sorceress, pebble→paladin, ember→sorceress, lumen→barbarian, bramble→necromancer — `scripts/cast3d.gd`
- 2026-10-21 — **The six classes wear their gear.** A gear kit per class hangs the weapon and the off-hand on the rig's own hand bones, and the armor plates hang on the rig's own bones: the helm, chest, pauldrons, gloves and boots, the shield and the blade — `scripts/gear3d.gd` (`NEW_KIT`), `scripts/plate3d.gd` (`NEW_BONES`)
- 2026-10-21 — The new rigs had no hand sockets (the retarget bake needs a hand-slot bone in the source), so the weapon and the shield could not mount. The sockets came from the paladin's own baked library, which the new rigs were retargeted from, with the bone names swapped to the new rigs' `hand.L`/`hand.R` — `assets/models/heroes_new/<class>/<class>_anims.res`
- 2026-10-21 — The plate pieces looked their anchor bones up in the old paladin's bone map, so they hung on nothing on a new rig. The frame now carries the rig it was built for — `scripts/plate3d.gd` (`_frame`, `_bone`)
- 2026-10-21 — The hero in the camp is dressed too, so the camp shows the gear the player equipped — `scripts/hub_view.gd` (`_spawn_hero`)
- 2026-10-21 — A save that owned a retired critter now moves to the class that replaced it, keeps what it earned and unlocks that class; a save with no hero at all gets the paladin. Before this the migration simply erased the retired heroes, which left the hero picker empty and the camp with nobody in it — `scripts/save_game.gd` (`_migrate`, `hero`)
