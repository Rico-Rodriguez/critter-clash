# Godot 4.7 quirks

- 2026-10-20 — `get_meta(name, null)` still errors when the key is missing: the null default cannot be told apart from "not set". Check `has_meta` first (see `Stage3D._player_of`).
- 2026-10-20 — `set_meta(name, null)` deletes the key instead of storing null.
- 2026-10-20 — Godot user arguments have to be handed over as one string in `Start-Process -ArgumentList`; an array loses the value of `--out=`.
- 2026-10-20 — A headless script that builds a `SubViewport` hangs. Scenes like the camp hub can only be verified through the capture harness, never with a headless probe.
- 2026-10-20 — The import step rewrites about 693 `.import` files with newline noise; `git checkout -- "*.import"` puts them back and they are not committed.
- 2026-10-20 — `PointLight3D` does not exist; the class is `OmniLight3D`.
- 2026-10-20 — A headless run that hangs leaves a Godot process behind; check `Get-Process -Name 'Godot*'` and kill the stale ones before starting the next run.
