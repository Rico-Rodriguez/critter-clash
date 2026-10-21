# Depth tiers and exploration

- 2026-10-20 — Four depth tiers with their own gates, requirements and descriptions: fringe, wilds, deep, abyss — `scripts/world_data.gd` (`TIER_GATES`, `tier_gates()`, `tier_gate()`, `next_tier_gate()`)
- 2026-10-20 — `gate_by_id` now scans both the biome gates and the tier gates — `scripts/world_data.gd`
- 2026-10-20 — World map rows map onto the tiers: hub row 6 (south) → fringe row 5 → wilds rows 3-4 → deep rows 1-2 → abyss row 0 (the lair); the map is 4 cols × 7 rows, 4480×8960 sim px — `scripts/tier_bounds.gd`, `scripts/hunt_map.gd`
- 2026-10-20 — `RunSim` gained `tier_id`, `tier_mode` and `tier_tracker`: the critter skin, the elite chance and the monster level follow the band the hero stands in, and only in tier mode — `scripts/run_sim.gd`
- 2026-10-20 — A tier hunt starts at the southern gate of its band instead of the world start — `scripts/hunt_map.gd` (`entry_for_tier`)
- 2026-10-21 — **The tier entry was broken and is now fixed.** `entry_for_tier()` was called by the run but had never been written, so travelling through a gate died on a missing method; the nodes also carried no row, so the band could not be found. The nodes record their row now and the entry is the gate of the band — `scripts/hunt_map.gd` (`_add_node`, `entry_for_tier`)
- 2026-10-21 — The run argument `tier` carried the depth tier while the old map screen carried the difficulty under the same key; the difficulty has its own key now (`difficulty`), and the run ignores a tier id it does not know — `scripts/run_screen.gd`, `scripts/app.gd`
- 2026-10-21 — A tier hunt that ends with the boss down clears that depth, which opens the gate above it — `scripts/run_screen.gd` (`boss_down`), `scripts/save_game.gd` (`clear_tier`)
- 2026-10-20 — Crossing into the next band says so: the run shows a banner and the map names the tier — `scripts/run_screen.gd` (`tier_change` event, inner `MiniMap.set_tier`)
- 2026-10-20 — Tier progress is stored as `data["tiers_cleared"]` and decides which gates are open — `scripts/save_game.gd` (`tier_open()`, `clear_tier()`, `tier_cleared()`)
- 2026-10-20 — The session carries the tier, and the run reads it from the gate that was used — `scripts/session.gd`, `scripts/app.gd` (`_travel`, `_start_hunt`)
- 2026-10-20 — `Catalog.biome_for_tier()` and `Catalog.tier_for_biome()` translate between the tier a gate stands in and the biome a hunt reports — `scripts/catalog.gd`
- 2026-10-20 — The intended next world model is the per-tier `ZoneBuilder` zone (fringe 4×2, wilds 4×3, deep 5×3, abyss 5×4 cells); the run still plays the old whole-world map — `docs/wilderness.md`, `scripts/zone_builder.gd`
- 2026-10-20 — Every hunt shares one clock: the lair boss rises at 68 s and the hunt ends at 119 s, so a hero has 51 s to fight it — `scripts/run_sim.gd` (`EXPLORE_BOSS_AT`, `HUNT_LIMIT`)
- 2026-10-20 — The whole-world map is 4480×8960 sim px (4 cols × 7 rows of 1120×1280 cells); the per-tier zones are 4480×2560 or taller per tier, which is what makes them walkable inside that clock — `scripts/hunt_map.gd`, `scripts/zone_builder.gd`
