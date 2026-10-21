# The old trial logic, retired

- 2026-10-20 — The desk (the old Home screen) lost its HUNT button: hunts start at a gate in the camp, not from a menu — `scripts/home_screen.gd`
- 2026-10-21 — The biome map sheet (one row per biome, sealed biomes greyed, START at the foot) is gone with the HUNT button — `scripts/home_screen.gd` (the `MapSheet` class was deleted)
- 2026-10-21 — The daily challenge moved from the map sheet into the camp counter — `scripts/app.gd` (`_start_daily`)
- 2026-10-21 — The dead biome map screen (per-biome banners, difficulty picks) was deleted: nothing reached it since the camp became the front door — `scripts/world_screen.gd` (removed, and its entry in `SCREENS` in `scripts/app.gd`)
- 2026-10-21 — The Veteran and Nightmare challenges are still reachable: every gate carries its own challenge, stepped up by tapping the line under the gate — `scripts/app.gd` (`_difficulty`, `_step_difficulty`), `scripts/save_game.gd` (`difficulty_unlocked`)
- 2026-10-21 — The 3D hero plinth moved out of the desk into its own file, because the Heroes tab and the camp both use it now — `scripts/showcase.gd` (new), `scripts/hero_screen.gd`
- 2026-10-21 — The desk is now the camp's drawer: the plinth, the wordmark, the chest drawer and the tiles for log, slayer, skills, forge, stash and credits — `scripts/home_screen.gd`
