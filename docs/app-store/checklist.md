# App Store readiness checklist

`[x]` is done in the repo, `[ ]` needs the developer or an account. `python3 tools/store/check_store.py` (also in CI) counts the open items.

## In the game (done)

- [x] First-launch privacy screen with consent (`src/core/privacy.gd`); nothing online starts before it
- [x] Crash reports are opt-in, default off; toggles and policy link in Settings > Privacy
- [x] Crash reporting hookup, inert without a DSN (`src/core/crash_report.gd`)
- [x] In-app account deletion (Clan > Account)
- [x] "Update required" gate with an App Store button (`src/core/app_gate.gd`)
- [x] No ads, no tracking SDKs, no IDFA
- [x] Credits for CC BY art, fonts and music in Settings and `CREDITS.md`

## Accounts and decisions (needs you)

- [ ] Apple Developer Program membership ($99/year) and the real team id in `export_presets.cfg` (`ABCDE12345` is a placeholder)
- [ ] App record in App Store Connect with bundle id `com.rico.critterclash`; note its numeric Apple ID
- [ ] Signing: distribution certificate and provisioning profile (the CI IPA is unsigned today)
- [ ] Crash provider account (Sentry or any Sentry-compatible host); add its DSN as the `CRASH_DSN` repo secret. Never commit it
- [ ] Host the privacy policy (`privacy-policy.md`, edit the contact line) and set the URL in `src/core/privacy.gd` and App Store Connect
- [ ] Support URL and support email
- [ ] Approve or edit the listing copy in `listing.md`
- [ ] Approve the screenshots (or retake them from a real device)
- [ ] Server: a production Nakama host with HTTPS (`server/README.md`) and its HOST/SERVER_KEY in `src/net/net_config.gd`

## Wiring the App Store link (after the app record exists)

1. `python3 tools/store/set_app_id.py <numeric Apple ID>`
2. Merge. The next publish puts `https://apps.apple.com/app/id<ID>` in `version.json`, and the update screen says OPEN APP STORE.
3. Turn the gate on only after the App Store build is live: set `min_native` in `tools/ota_gate.json` (see `docs/ota.md`, section C).

## Before each submission

- [ ] `tools/dev/check.sh` passes
- [ ] Version and build bumped (`export_presets.cfg`, CI stamps the build number)
- [ ] Retake screenshots if the UI changed (`tools/store/shots.sh`)
- [ ] App Privacy answers still match `listing.md`
- [ ] TestFlight run on a real device: first launch, privacy screen, offline play, kill mid-hunt and relaunch
