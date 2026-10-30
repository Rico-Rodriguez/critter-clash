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
2. [x] **Boss Rush and Rift use every boss the player has unlocked** (done). The Rift is now a Boss Rush option (a rift key toggle), not its own tile. Dropped, on reflection: making the Wilderness a weekly event. A clock gate would lock players out of a mode they already earned, and with the Rift folded in the Expedition is down to five modes. If playtests show nobody plays it, revisit.
3. [x] **Zones are variety, not progress** (audit option B): all six open by 5,000 trophies (Vault 4,100, Frost 4,400, Swamp 5,000), `loot_bonus` flat at 2, each zone keeps its own boss uniques; the Rogue joins at 3,500; every mode opens by 1,200 (the Wilderness at 1,000).
4. [x] **Economy:** the season is tuned so a regular player finishes in about week 5 (240 xp a tier) and the outfit moves to tier 20. Cosmetics stay on gold. Hero levels no longer exist, so there is no hero curve to fix; shards only buy Super ranks.
5. [x] **Fewer meters:** hero rating is cut and camp shows one next-goal line (`Game.next_goal()`). The results screen is otherwise unchanged: its remaining lines each say something earned, opened or ready, so I did not cut more.
6. [x] **Small bugs:** Log sheet overflow, the Speed vs Hits/s label and the clipped boss names are fixed. The skin-name clipping and the first-hunt tip covering its card did not reproduce in the `equipskins` and `firstcamp` screenshots, so they are not changed.

Left for later: local notifications (needs a native plugin and an IPA bump), outfits that change the silhouette.

## Pets overhaul (Rico, 2026-10-29)

Rico keeps breeding and mutations and wants them clearer. He picked the Breeding Wheel and the
Matchmaker from the mockups, and all four rule changes. One PR each:

1. [x] **Breeding rules:** a flat 8h rest after every litter (was a ladder that stuck at 48h), a
   hybrid pity (a pair's hybrid is certain by its 3rd litter until found), and Release for bred
   pets (+200 gold) so a full stable can't stop breeding. Eggs still always hatch; no lifetime cap.
2. [x] **Pets tab:** the Breeding Wheel (all species on one ring, hybrids between their parents,
   mutations in the hub) with a bestiary and breed pages, and the Matchmaker breeding screen
   (each outcome's chance, the mutation chance with its pity, partners sorted by what they make).

## Talent trees v2 (Rico, 2026-10-29)

Proposal: the "Gravelight Talent Trees" artifact in the project thread. Rico approved it, with
the point cap and refund price left to Claude (22 points, 40 gold a rank).

1. [x] **Trees, not lines:** ranked minors, rows that open at 0/3/6/10/13 points in the path, a
   pick-one node, one keystone at a time with a cost, attunement, rank refunds, two saved builds,
   old talents refunded. One-screen sheet.
2. [ ] **Tune:** autopilot runs with a spent tree per hero against the old talents, so the
   overhaul is a change of shape, not a power spike.

## UI polish audit (2026-10-29)

Full findings with screenshots are in the published report (linked from the PR).

- [x] **Clear wins:** settings credits folded, season and quests fit, log three across, feats sorted, switches, gold Buy, hero sheet, results panel, privacy card.
- [x] Expedition fits one screen (Feats still scrolls about 280 px: 18 feats, sorted, by design).
- [x] Weapon collection: every rung names its set, a padlock marks one you cannot wear yet.
- [x] Loot labels stack over nearby drops instead of piling up.
- [x] Level-up: Reroll and Keep side by side, Banish explained under them.
- [x] The rest from the report: one price style, This Week switch, Daily today and day 7, Talents badge, Profile.

## Polish pass (Rico, 2026-10-30)

From the "Gravelight polish diagnosis" artifact: five reasons the game doesn't look professional yet.
Rico asked for the full pass, all four parts. One PR each:

1. [x] **Look:** heroes get an adult build (smaller head, longer trunk and legs, on the shared
   skeleton), the Knight's starter helm is a nasal helm and not a kettle hat, and every outfit adds
   its own pieces (capes, pauldrons, a helm) instead of only recoloring.
2. [x] **Stages:** Pets, the hero sheet and the shop built around one big lit subject, three
   numbers and one button; gear shown as rarity-lit renders, not silhouettes.
3. [x] **Moments:** the boss kill and the loot get a close camera, hit-stop and a one-at-a-time
   reveal instead of a list.
4. [x] **Focus:** red dots only for something you can do now, camp buttons that open over the first
   hunts, pet extras behind one More.

## Iron & Ember overhaul (Rico, 2026-10-30)

Rico approved the "Iron & Ember" direction artifact (six phone mockups) as the new look for every
screen. Rules: the 3D scene is the background and panels float small and dark over it; one gold
button per screen, everything else a quiet outline; Cormorant SC for names, Barlow Condensed for
buttons and numbers, Barlow for text; iron, gold and ember plus rarity colours, no purple panels;
labels in two or three words; tabs with icons only, the open one named. One PR each:

1. [x] **Theme:** the new palette and fonts in `tools/build_theme.gd`, outline buttons, no purple.
2. [x] **Camp:** the scene is the screen, three side buttons, one gold Hunt card, icon-only tabs.
3. [x] **Hunt HUD:** closer camera, thin XP line, one elite banner, health over the hero, two
   ability buttons.
4. [x] **Hero:** Gear, Talents and Skins as tabs, a big hero, rarity-lit slots, one stats row.
5. [x] **Pets, Shop and Victory** to their mockups.
6. [x] **Every other sheet** (quests, season, road, expedition, settings, clan) swept to the rules.

## Models made in Blender (Rico, 2026-10-30)

Rico approved the plan on the Iron & Ember samples page: the heroes keep their KayKit bodies, and
weapons, armour and props are modelled in Blender to match. Pets get the same treatment at real
proportions (not chibi): each one is built from code in `tools/blender/pets/`, with its own
skeleton, clips and one flat-colour texture, so breeding parts and skins keep working. It replaces
a Sketchfab model and drops that model's credit. One pet per PR:

1. [x] **Ember Drake** (and the Ash Wyrm textures).
2. [x] **Grave Wisp.**
3. [x] **Storm Crow.**
4. [x] **Gilded Mimic.**
   - [x] **Bred pets look like one animal** (Rico chose "one body, inherited colours + trait"):
     a hybrid keeps its body parent's whole model; an inherited head, wings or tail takes the
     other parent's colours and wears a small trait of theirs. Genes, stats and card text unchanged.
5. [x] **Night Bat.**
6. [ ] Bonelet, Hexling, Plague Acolyte, Barrow Squire, Shade, Thorn Sapling.
7. [ ] Hero weapons and armour pieces.

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
