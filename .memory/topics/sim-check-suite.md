# Sim check suite

- 2026-10-20 — `tools/zone_check.gd` prints `ZONE CHECK PASSED` — `tools/zone_check.gd`
- 2026-10-20 — A headless import of the whole project exits 0 after the fixes — `godot --headless --import`
- 2026-10-20 — The main harness is `scripts/sim_check.gd`; it drives the sim headlessly and prints one line per failure
- 2026-10-20 — The retired hero ids in the harness were remapped to the new roster (pebble→barbarian, ember→sorceress, juniper→rogue) — `scripts/sim_check.gd`
- 2026-10-20 — The dock check now expects the camp on the left, heroes in the middle and the road on the right — `scripts/sim_check.gd`
- 2026-10-20 — Full run result after the boss-intro fix: `SIM CHECK FAILED 7`, and every one of the seven is the meadow bot family (`sorceress/rogue/barbarian should clear the meadow, got lose`, the same three `time 119.0 s outside the 2.5-5.5 min bot window`, and `the full seeded bot run ended lose`). The boss-intro check and the dock check pass — `out_full.txt` in a local run
- 2026-10-20 — A single check can be run on its own: `godot --headless --path . -- --sim-check --only=boss_intro` — `scripts/sim_check.gd` (`CHECKS`)
