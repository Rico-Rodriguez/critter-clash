# Camp hub as the front door

- 2026-10-20 — The camp is now the front door: `HubScreen` in `scripts/app.gd` draws a 3D camp over the top 44% of the screen and the counter (header, title, body, stall row, service row, gate list) under it — `scripts/app.gd`
- 2026-10-20 — The camp itself is built in code (ground disc, dirt path, campfire, two stalls, rim props, one gate stone per depth tier) while keeping the original shop and gate API — `scripts/hub_scene.gd`
- 2026-10-20 — `HubView` hosts the camp in a `SubViewport` with its own camera, lights and environment, and spawns the featured hero playing idle; the viewport follows the control's size — `scripts/hub_view.gd`
- 2026-10-20 — Dock is now Camp / Heroes / Road and `home` is no longer a tab: `ScreenBase.NAV_ORDER = ["hub", "heroes", "trophy"]`, `home_screen` shows no nav, and every side screen backs out to `hub` — `scripts/ui_kit.gd`, `scripts/screen_base.gd`
- 2026-10-20 — Hub service row is STASH | HERO | DESK (the desk opens the old home screen) — `scripts/app.gd`
- 2026-10-20 — The hub service row is now STASH | DESK | DAILY; the hero is chosen in the camp itself, so the old HERO button is gone — `scripts/app.gd` (`_service_row`)
- 2026-10-20 — `PointLight3D` in `scenes/hub_scene.tscn` is not a Godot class and it stopped the scene from loading; it is now `OmniLight3D` — `scenes/hub_scene.tscn`
- 2026-10-20 — `Stage3D._player_of()` replaced bare `get_meta("player")` lookups that errored every frame on bodies without a player — `scripts/stage3d.gd`, `scripts/movie_director.gd`, `scripts/portrait_baker.gd`
- 2026-10-20 — Pushed as commit `d9d5978` ("the camp is the front door, and the world has real depth tiers") — `git log`
- 2026-10-20 — The camp now names the hero: a YOUR HERO row with his level, his role and a CHOOSE button that opens a sheet over the camp, where the picked hero steps into the firelight and travels from there — `scripts/app.gd` (`_hero_row_widget`, `_open_hero_sheet`, `_pick_hero`), `scripts/hub_view.gd` (`set_hero`)
- 2026-10-20 — The gates are a strip of four (one tile per depth, with its challenge under it) instead of four tall rows, so the camp keeps the top half of the screen and every way out is visible at once — `scripts/app.gd` (`_gate_strip`, `_gate_tile`)
- 2026-10-20 — The camp takes half the screen and the camera looks down at the fire, so the sky is a band instead of a third of the picture — `scripts/app.gd` (`CAMP_FRACTION`), `scripts/hub_view.gd` (`CAM_POS`, `CAM_LOOK`)
- 2026-10-20 — The daily challenge moved from the desk into the camp counter, next to the gates — `scripts/app.gd` (`_start_daily`)
- 2026-10-21 — The camp's gates are a place now: one standing stone pair per depth tier, the open one lit with a shaft of light, and a tap on the stone walks the hero through it (the counter's buttons stay as the plain path) — `scripts/hub_scene.gd` (`_gates`, `list_gate_markers`), `scripts/hub_view.gd` (`gate_at`, `gate_tapped`), `scripts/app.gd` (`_travel`)
- 2026-10-21 — The daily runs a depth zone now, the same flow a gate opens — `scripts/app.gd` (`_start_daily`)
