# Toolchain and workflow

- 2026-10-20 — Godot 4.7.2 lives at `C:\Users\rico2\Tools\Godot\Godot_v4.7.2-stable_win64_console.exe`; the main scene is `res://scenes/main.tscn` and it boots `scripts/app.gd`
- 2026-10-20 — The shell is cmd: no `head`, no `tail`, no heredocs. Wrap with `powershell -NoProfile -Command "..."` and use `Select-Object -First/-Last`
- 2026-10-20 — Capture harness: `godot --path . -- --capture --shots=hub,heroes --out=<absolute dir>` writes one PNG per screen
- 2026-10-20 — Repo is `https://github.com/Rico-Rodriguez/critter-clash` on branch `main`; work is committed and pushed with `git push origin main`
- 2026-10-20 — The OTA release branch is `ota` at `fb76a7e`; the deploy flow is written down in `docs/ota.md`
- 2026-10-20 — The project memory lives in `.memory/` inside the repo: `index.md` is the table of contents, `topics/*.md` are the history pages
