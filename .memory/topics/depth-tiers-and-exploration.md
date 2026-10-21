# Depth tiers and exploration

- 2026-10-20 — Four depth tiers with their own gates, requirements and descriptions: fringe, wilds, deep, abyss — `scripts/world_data.gd` (`TIER_GATES`, `tier_gates()`, `tier_gate()`, `next_tier_gate()`)
- 2026-10-20 — `gate_by_id` now scans both the biome gates and the tier gates — `scripts/world_data.gd`
- 2026-10-20 — World map rows map onto the tiers: hub row 6 (south) → fringe row 5 → wilds rows 3-4 → deep rows 1-2 → abyss row 0 (the lair); the map is 4 cols × 7 rows, 4480×8960 sim px — `scripts/tier_bounds.gd`, `scripts/hunt_map.gd`
- 2026-10-20 — `RunSim` gained `tier_id`, `tier_mode` and `tier_tracker`: the critter skin, the elite chance and the monster level follow the band the hero stands in, and only in tier mode — `scripts/run_sim.gd`
- 2026-10-20 — A tier hunt starts at the southern gate of its band instead of the world start — `scripts/hunt_map.gd` (`entry_for_tier`)
- 2026-10-20 — Crossing into the next band says so: the run shows a banner and the map names the tier — `scripts/run_screen.gd` (`tier_change` event, inner `MiniMap.set_tier`)
- 2026-10-20 — Tier progress is stored as `data["tiers_cleared"]` and decides which gates are open — `scripts/save_game.gd` (`tier_open()`, `clear_tier()`, `tier_cleared()`)
- 2026-10-20 — The session carries the tier, and the run reads it from the gate that was used — `scripts/session.gd`, `scripts/app.gd` (`_travel`, `_start_hunt`)
- 2026-10-20 — `Catalog.biome_for_tier()` and `Catalog.tier_for_biome()` translate between the tier a gate stands in and the biome a hunt reports — `scripts/catalog.gd`
- 2026-10-20 — The intended next world model is the per-tier `ZoneBuilder` zone (fringe 4×2, wilds 4×3, deep 5×3, abyss 5×4 cells); the run still plays the old whole-world map — `docs/wilderness.md`, `scripts/zone_builder.gd`
