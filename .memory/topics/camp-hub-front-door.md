# Camp hub as the front door

- 2026-10-20 — The camp is now the front door: `HubScreen` in `scripts/app.gd` draws a 3D camp over the top 44% of the screen and the counter (header, title, body, stall row, service row, gate list) under it — `scripts/app.gd`
- 2026-10-20 — The camp itself is built in code (ground disc, dirt path, campfire, two stalls, rim props, one gate stone per depth tier) while keeping the original shop and gate API — `scripts/hub_scene.gd`
- 2026-10-20 — `HubView` hosts the camp in a `SubViewport` with its own camera, lights and environment, and spawns the featured hero playing idle; the viewport follows the control's size — `scripts/hub_view.gd`
- 2026-10-20 — Dock is now Camp / Heroes / Road and `home` is no longer a tab: `ScreenBase.NAV_ORDER = ["hub", "heroes", "trophy"]`, `home_screen` shows no nav, and every side screen backs out to `hub` — `scripts/ui_kit.gd`, `scripts/screen_base.gd`
- 2026-10-20 — Hub service row is STASH | HERO | DESK (the desk opens the old home screen) — `scripts/app.gd`
- 2026-10-20 — `PointLight3D` in `scenes/hub_scene.tscn` is not a Godot class and it stopped the scene from loading; it is now `OmniLight3D` — `scenes/hub_scene.tscn`
- 2026-10-20 — `Stage3D._player_of()` replaced bare `get_meta("player")` lookups that errored every frame on bodies without a player — `scripts/stage3d.gd`, `scripts/movie_director.gd`, `scripts/portrait_baker.gd`
- 2026-10-20 — Pushed as commit `d9d5978` ("the camp is the front door, and the world has real depth tiers") — `git log`
