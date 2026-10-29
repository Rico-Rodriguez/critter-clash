# Gravelight — plan

The live work queue. The finished phases (camera, art, gear, feel, zones, the Long Road,
UI passes) are in [PLAN-history.md](PLAN-history.md); what shipped, newest first, is in
[CHANGELOG.md](../CHANGELOG.md). Read `CLAUDE.md` first.

Last reviewed 2026-10-28, after the review of the five grokbot days (see the notes at the end).

## How we work (every bot and every person)

1. **One task, one PR, one commit per task.** Branch `claude/<task>` or `grok/<task>`. Say
   which task in the PR title.
2. **`tools/dev/check.sh` must print `CHECKS PASSED`** before a push, and CI must be green
   before a merge. CI also fails on a `valid=false` `.import`, an engine load error in the
   tests, and an OTA pack over budget (`tools/dev/check_imports.py`, `check_pack.py`).
3. **Visible change means screenshots you have looked at**, taken with `tools/dev/shots.sh`,
   in the PR description. Do not describe a result you have not seen.
4. **Tick the task here in the same PR** and add a `CHANGELOG.md` entry. Two PRs that both
   add an entry conflict on the file: keep both entries.
5. **Merge to `main` only when Rico asks.** A merge ships to every installed phone.
6. **No new third-party model without a row in `docs/art-audit.md`**: source link, author,
   licence on the page, and a check that the title names no commercial game or character.
7. **Never overwrite another bot's open branch.** Rebase or merge `main` into your own.
8. Anything that needs a phone, a secret, or a decision about the game's direction is Rico's.
   Ask once, in the thread, and carry on with the rest.

## Design decisions (2026-10-28 audit)

Rico asked Claude to make every call from `reviews/design-audit-2026-10-28.html`. One PR each,
in this order; tick a line when it merges.

1. [x] **One difficulty ladder for the account**, one win per tier, first-clear trophies once per tier.
2. [~] **Boss Rush and Rift use every boss the player has unlocked** (done). Still to do: merge them into one Boss Rush with the rift key as an optional harder run, and make the Wilderness a weekly event.
3. [x] **Zones are variety, not progress** (audit option B): all six open by 5,000 trophies (Vault 4,100, Frost 4,400, Swamp 5,000), `loot_bonus` flat at 2, each zone keeps its own boss uniques; the Rogue joins at 3,500; every mode opens by 1,200 (the Wilderness at 1,000).
4. [x] **Economy:** the season is tuned so a regular player finishes in about week 5 (240 xp a tier) and the outfit moves to tier 20. Cosmetics stay on gold. Hero levels no longer exist, so there is no hero curve to fix; shards only buy Super ranks.
5. [ ] **Fewer meters:** cut hero rating, slim the results screen to earned / opened / next step, add one next-goal card on camp.
6. [ ] **Small bugs:** Log sheet overflow, the Speed vs Hits/s label, clipped zone and skin names, the first-hunt tip covering its card.

Left for later: local notifications (needs a native plugin and an IPA bump), outfits that change the silhouette, trimming breeding and mutations from the Pets tab.

## Now: needs Rico

| Task | Why it waits |
| --- | --- |
| Playtest on the phone for 30 minutes | The only check for feel, readability and the economy. Note what is confusing or bloated. The audio fix, the Rime Regent, the Long Road and the weekly event are all untested on a device. |
| Look at the six models in `docs/art-audit.md` "Keep, but check" | Needs a person to open the Sketchfab pages. Do this before an App Store build. |
| Move the test server off GitHub Actions to the Oracle VM | `server/setup_vm.sh` exists; it needs the VM and its secrets. |
| Decide whether the 10-tier weekly event track folds into the 30-tier season | Costs players their weekly egg and chest rewards. The sim (`src/economy_tests.gd`) shows casual players earn little already. |
| Share the biome plan | The plan grokbot worked from is not in the repo. `docs/biomes.md` records what the code shows; replace it with the real plan. |

## Next

1. **Economy from the playtest.** Tune `DB` from what the playtest finds; the simulated week
   in `src/economy_tests.gd` is the guard. Casual players currently get 0 gems a week.
2. **Pack size.** The OTA pack is ~186 MiB against a 200 MiB budget. Find unused textures and
   audio with the export's file list (a name search cannot tell: music and foe textures are
   loaded by built names), and cut what nothing loads.
3. **Social go-live.** Deploy the server (`server/README.md`), set `HOST`, `SERVER_KEY` and
   `SUPPORT` in `src/net/net_config.gd`. Then on two phones: chat with the keyboard up, a
   party hunt, an invite from a fresh install, moving to a new phone.
4. **Long Road polish** after the playtest: room count and length, gate readability, the boss
   hall, loot worth the walk. Nightmare and Veteran tuning (`DB.TIERS`).
5. **Foe brains in the older zones.** The Barrow, Crypt, Grove and Vault still use the old
   foes; the rebuilt faction brains exist only for Rimehollow and the Cinder Mire
   (`--old-foes` switches back). See `docs/biomes.md`.

## Later (ideas, ask first)

- Royale hunt, gear set bonuses, a third mode after the Long Road: sketched in
  [PLAN-history.md](PLAN-history.md) under Phase 7 and Phase 10.
- Art direction (A.2/A.3) was skipped on purpose; options in `docs/art-options.md`.

## Done in the 2026-10-28 clean-up

- Restored 93 audio `.import` files that shipped broken, so sound plays again (#139).
- The Trophy Road no longer pays a duplicate first-clear, and pets keep their 8-bone-weight
  rig format (#139).
- CI guards for broken imports, engine load errors and pack size (#140).
- The Frost Troll, the Nether Lich and the Chicken Gun dragonfly are gone (#141).
- `weekly_submit` refuses impossible scores (#144); an omen hunt scores again (#148).
- A recovered hunt says so in camp (#143); main.gd lost its dev modes (#147).
- Reviews: `reviews/grokbot-review-2026-10-28.md` and
  `reviews/grokbot-quality-review-2026-10-28.md`, in the project files.
