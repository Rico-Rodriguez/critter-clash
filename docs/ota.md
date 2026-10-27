# Over-the-air updates

Two layers, so most changes reach the phone without sideloading.

## A. In-game content packs (scripts, scenes, assets)

Every push to `main` runs `.github/workflows/ios-ipa.yml`. Besides the IPA it
publishes to the `ota` prerelease (assets replaced in place):

- `critter_clash.pck`: the iOS export's full main pack (every script, scene and
  imported asset, iOS texture formats).
- `version.json`: `{build, sha, pck_url, sha256, size, min_engine, godot, platform, date}`.
  `build` is the workflow run number (monotonic). `min_engine` is
  `NATIVE_VERSION` from `src/autoload/ota_boot.gd`.

`src/autoload/ota_boot.gd` is the first autoload (`Ota`). Its `_init` runs before any
other game script loads, so a mounted pack replaces autoloads, screens and
assets alike:

1. Reads the baked build (`ota/build` project setting, stamped by CI).
2. If `user://ota/booting.flag` exists, the last boot crashed with a pack
   mounted: that pack is deleted, its build is blacklisted, and the previous good
   pack (or the baked content) is used.
3. Mounts `user://ota/manifest.json`'s current pack with
   `ProjectSettings.load_resource_pack(path, true)`, writing the booting flag first.
   The flag is cleared after 4 s of play, or when the app is backgrounded/closed.
   Packs not newer than the baked build, or built for another shell/Godot, are dropped.
4. In `_ready`, fetches `version.json` (3 s timeout). A newer build that passes
   the `min_engine`, Godot and platform checks is applied before the game
   becomes usable: a full-screen Updating panel (build numbers, download
   progress bar) pauses the tree while the pack downloads to
   `user://ota/download.tmp`, is size- and SHA-256-checked on a worker thread,
   renamed to `content_<build>.pck`, and mounted immediately; then the game
   unpauses. If the check, download or verification fails, boot continues on
   the current content while one background retry stages the pack for the next
   launch. The running pack is kept as the fallback; older packs are deleted.

Nothing outside `user://ota/` is touched; saves stay in `user://barrowfall_save.json`.
Settings shows `v1.1.0 · Build <baked> · Content <ota>`, and the first launch on a
new pack shows an "UPDATED TO BUILD N" plaque.

Bump `NATIVE_VERSION` whenever a change needs a new IPA: Godot version, export
preset, native plugins, or project settings (autoloads, input map, rendering
settings). Packs never change project settings.

Desktop test: `CC_OTA_TEST=1 CC_OTA_URL=http://127.0.0.1:8765/version.json`
with `-- --ota-probe --out=<dir>` prints the OTA state and shoots Home and
Settings. `tools/ota_test_pack.gd` builds small test packs. Use a separate
`XDG_DATA_HOME` so tests never share a user:// with real saves.

## B. Native changes: AltStore / SideStore source

Add this source once in AltStore or SideStore:

https://github.com/Rico-Rodriguez/critter-clash/releases/download/ota/altstore.json

CI regenerates it after every IPA (`tools/altstore_source.py`, which also
validates it) with the real IPA size, date and the bundle version `1.1.<run>`, so
the app shows an update whenever a new IPA lands on `ios-v1`.


## C. Forced native update ("Update required")

Packs (A) cannot change the native shell, and a shell below a pack's
`min_engine` quietly keeps its old content. For a build the old shell truly
cannot run, the game can instead refuse to start until the player updates.

- `version.json` also carries `min_native` and `store_url`, both copied from
  `tools/ota_gate.json` by the publish step. `min_native` is compared with the
  installed `Ota.NATIVE_VERSION`; `0` (the default) turns the gate off.
- `src/core/app_gate.gd` fetches `version.json` on launch (after the OTA
  check settles) and every time the app resumes. If the installed shell is
  below `min_native`, a blocking "Update required" screen covers the game, the
  tree is paused and the lobby is never entered. The button opens `store_url`
  ("Open App Store" for an apps.apple.com link, "Get the update" otherwise).
- It fails open: offline, a timeout (3 s), an HTTP error or bad JSON lets the
  player in. Nothing is cached, so the next launch or resume asks again.
- It is a pack script, not part of `ota_boot.gd`, so it reaches installed
  copies over the air and needs no `NATIVE_VERSION` bump. The copy that has
  to carry the gate is therefore the first one that already contains it.
- Content-only builds never set `min_native`, so OTA behaves as before.

To force an update: ship the new native build (bump `NATIVE_VERSION`), then set
`min_native` in `tools/ota_gate.json` to that number and merge. To flip it
without a build, edit `version.json` on the `ota` release by hand
(`gh release upload ota version.json --clobber`). Set `store_url` to the real
App Store page once the app is listed (it points at the sideload release now).

Test it on the desktop: `CC_GATE_URL=http://127.0.0.1:8765/version.json` with a
`min_native` above 3 (serve it as in section A); `-- --no-gate` skips the check.
Capture the screen with `-- --capture --shots=update`.

### App Store link placeholder

Until the app has a listing, `store_url` is the sideload page and the button
says "GET THE UPDATE". When the App Store record exists run
`python3 tools/store/set_app_id.py <numeric id>`: it writes `app_store_id` and
`store_url` (`https://apps.apple.com/app/id<ID>`) into `tools/ota_gate.json`, and
the button becomes "OPEN APP STORE" (`AppGate.is_store_url`). CI publishes the
`app_store_id` link even if `store_url` was left stale. `tools/store/check_store.py`
(in the Game checks workflow) warns while the placeholder is in place and fails
if `min_native` is switched on without a real store link. The full submission
list is `docs/app-store/checklist.md`.
