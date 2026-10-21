# Sim check suite

- 2026-10-20 — `tools/zone_check.gd` prints `ZONE CHECK PASSED` — `tools/zone_check.gd`
- 2026-10-20 — A headless import of the whole project exits 0 after the fixes — `godot --headless --import`
- 2026-10-20 — The main harness is `scripts/sim_check.gd`; it drives the sim headlessly and prints one line per failure
- 2026-10-20 — The retired hero ids in the harness were remapped to the new roster (pebble→barbarian, ember→sorceress, juniper→rogue) — `scripts/sim_check.gd`
- 2026-10-20 — The dock check now expects the camp on the left, heroes in the middle and the road on the right — `scripts/sim_check.gd`
- 2026-10-20 — Six failures were left after that work, all of them the pre-existing meadow bot fights — see [[open-issues]]
