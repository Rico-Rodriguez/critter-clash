# Changelog

Patch notes for Gravelight (formerly Barrowfall), newest first. Each entry lists the commits that
shipped it. What comes next is in [docs/PLAN.md](docs/PLAN.md), under
**Next**.

Version in `project.godot` is still 2.0.0. `NATIVE_VERSION` is 4 (the engine worker pool size changed: reinstall the IPA). Save
version is 7.

---

## Unreleased: the Grave Wisp, made in Blender

The second pet remade in the heroes' style. The Grave Wisp is now an original Blender model
(`tools/blender/pets/wisp.py`): a stone-skinned spirit fish that swims through the air, with a pale
glowing belly, a toothed maw, a lantern lure over its brow, wide spirit fins and a tail that
trails off into spirit flame. It has its own skeleton and five clips (drift, swim, bite, hit and a
rising mend). Bred pets borrow its maw, fins and flame tail as before. The Sketchfab "Mawko" model
and its credit are gone. A content change: ships over the air.

## Unreleased: the Ember Drake, made in Blender

The first pet remade to match the heroes. The drake is now an original model built in Blender from
code (`tools/blender/pets/drake.py`): a young dragon at real proportions with a long neck and tail,
wide wings and a plated belly, in flat colours like the hero kit. It has its own skeleton and five
clips (hover, fast flight, bite, hit and a rearing fire breath). The Ash Wyrm keeps its grey-and-ember
look, now painted for the new model, and its embers glow only in the cracks (the glow used to be
added over the whole body). Bred pets still borrow the drake's head, wings and tail. The Sketchfab
dragon and its credit are gone. A content change: ships over the air.

## Unreleased: Iron & Ember, every other sheet

Part 6 of the overhaul. Body text moves to Barlow Semi Condensed, which sets about as wide as the
old Alegreya Sans, so no sheet's text runs past its edge in the new type (the Story sheet's reward
line did, and now wraps as well). The Trophy Road's backdrop is warm iron like every other page.
Quests, Season, This week, Story, Feats, Daily, Profile, Talents, the Log, Bounties and Settings
were checked in screenshots after the sweep. Also fixed: a Cinder Mire lantern whose fuse ran out after
its hunt had been freed raised a script error. A content change: ships over the air.

## Unreleased: Iron & Ember, pets and shop

Part 5 of the overhaul. Every page's backdrop (Pets, Shop, Clan and the rest) is warm iron with an
ember mist instead of violet. The pet on the Pets page stands in a card edged and lit in its rarity,
with its rarity, element, stage and name over the card's foot. The shop's featured look and the
victory reveal already had their mockup layout and now wear the new palette. A content change: ships
over the air.

## Unreleased: Iron & Ember, hero

Part 4 of the overhaul. Gear, Talents, Skills and Skins are tabs across the top of the hero page
instead of a row of quiet buttons under Equip best, and Gear or Skins lights up for the page you are
on. The power is a large gold number in the condensed face, and the page and its stage are warm iron
instead of violet. A content change: ships over the air.

## Unreleased: Iron & Ember, hunt HUD

Part 3 of the overhaul. The hunt camera sits closer (16.5 m instead of 19.5; Wide is about the old
view). Run XP is a thin gold line along the top edge instead of a ring round the medal. Elites no
longer carry two lines of text over their heads: a small chevron in their affix colour marks them,
and one plate under the top bar names the nearest elite with its affixes and health. The pet's
read-out is its cooldown ring with the seconds left, without the ability name and kill count.
A content change: ships over the air.

## Unreleased: Iron & Ember, camp

Part 2 of the overhaul. The camp's side buttons are one column of dark square tiles with icons only
(Story, Quests, Season with its tier in the corner, This week) instead of seven labelled orbs on both
sides. The campfire's gold hangs as an ember tag under the gold counter, and tapping the counter
collects it. The Trophy Road plate is slimmer, the player chip drops its clan line, the hero's name
is set in Cormorant with the power in gold capitals under it, and the tab bar shows icons with only
the open tab named. A content change: ships over the air.

## Unreleased: Iron & Ember, the new look starts with the theme

The first of six parts of the UI overhaul Rico approved. Every screen gets the new palette and
type: near-black iron panels, gold for value and ember for action, no purple. Names and titles
are set in Cormorant SC, buttons, captions, tabs and numbers in Barlow Condensed, and text in
Barlow; Cinzel and the bold Alegreya Sans are gone. Buttons other than the gold one are quiet
outlines. A content change: ships over the air.

## Unreleased: camp opens up over the first hunts, and a red dot means something

A new player met five tabs, seven round buttons and seven red dots on the first camp screen, so none of the dots meant anything. The camp's side buttons now open over the first hunts: Story from the start, Quests and the Campfire after the first hunt, Season after the third and This week after the fifth. At most two side buttons wear a red dot at once, Story first, then Quests, then Season, and the Campfire shows its gold as its label instead of a dot as well. Pet extras (Breed, the Breeding Wheel and the Podium) already sit behind More on the Pets page. A content change: ships over the air.

---

## Unreleased: the hoard comes out one piece at a time

Killing a boss and seeing the loot should be the best seconds of a run, and it went by as a list. When the boss falls the camera now holds on it longer, closer and lower, then swings to the hoard while it fountains out and lands, and only then returns to the hero as the loot flies in. Loot names over a pile are stacked further apart, because the camera looks down and squeezed them into each other. After a win, the gear comes out one card at a time before the results list, worst first and best last, each in its rarity's light with its 3D render and how much power it adds over what its hero wears, under the boss's name and VICTORY. Dots count the pieces, a tray underneath collects the ones you have seen, and Equip now puts an upgrade on its hero there and then; a tap shows the next, Skip goes straight to the list. On the list, a piece for another hero says so in small type instead of a big green name. A content change: ships over the air.

---

## Unreleased: the things you own take the stage

Pets, gear and looks were lists of text and thumbnails; each page is now built like a stage, with the thing you own big and lit, a few numbers and one button. **Pets** has three tabs, Stable, Eggs (with how many are warming) and More, which holds Breed, the Breeding Wheel and the Podium one tap down. The stable puts one pet on a lit pedestal with slow rays in its colour (the camera keeps the whole stand in view, so a flier no longer floats off its base), its rarity, element and name centered under it, its ability as three numbers (damage, cooldown and the one number that makes it what it is, like burn or bounces), a Bond bar, and one gold button: Take on hunt, or Go hunt when it is already at your side. Underneath, every pet is a portrait in a row you swipe, ringed in its rarity: a tap puts it on the stage, a second tap opens its page, and the ones still to find are dark shapes that open the bestiary. The pet count sits beside the title. **The hero sheet** leads with one Power number and how much the bag would add ("▲ 480 ready to equip"); worn gear sits in slots lit from inside in its rarity and glowing out, with its level in the corner and a green ▲ when the bag holds better; the stats are one slim line; a set bar shows the set you are closest to finishing as pips and its next bonus; Equip best is the one big gold button, and Talents, Skills and Skins are quiet buttons under it; the combat level is a tag by the name. Helms, chests and legs had flat silhouette icons: every piece is now rendered from its own 3D model, so a Barrowsteel cuirass looks like that cuirass in the slot, the bag, the shop, chests and results. **The shop** opens on a featured look: an outfit your hero doesn't own yet, worn by them, big and lit, a different one each day. Weapon skins show the weapon itself instead of a small hero holding it, and outfit and skin cards give the render most of the card. Egg cards put the egg first: big and centered, rocking and lit once it is ready, one line of time and kills, Hatch in gold and Skip in a quiet button; the egg shop's paragraph is now one line of timers. A content change: ships over the air.

---

## Unreleased: heroes look like grown fighters, outfits change the shape

The heroes stood in the dark world like toys: big heads, short legs, and the Knight began in a wide kettle hat that read as a farmer. Every hero now has an adult build on the shared skeleton: the head is about a fifth smaller, the trunk and legs are longer, and the arms keep their size, in the hunt, at camp, on the hero sheet, in portraits and in cutscenes (the dead keep theirs). The Knight's first helm is now a nasal helm in dull iron. Outfits were only dyes, so every look was the same model in a new color; each now adds its own pieces as well: Crimson Guard a red-crested helm, pauldrons and a cape, Gilded Oath the winged helm and pauldrons, the Ranger, Mage and Barbarian outfits their own helms, pauldrons and capes, the Rogue's a cape or cloak and mask, and the season outfits a cape. A content change: ships over the air.

---

## Unreleased: talent trees rebuilt like an ARPG

Each hero's three talent paths were straight lines of eight nodes, so the only choice was which column to fill first, and a maxed hero owned 80% of the tree. Each path is now a small tree: minors take up to 3 ranks, rows open after 3, 6, 10 and 13 points in that path, the middle node is a pick-one upgrade (several change the hero's super), and the path ends in a keystone with a real cost; only one keystone can be active. Every point in a path also adds a little of its theme stat (attunement). Points cap at 22 (combat 113), ranks refund one at a time for 40 gold (free for anything learned since the tree was opened), and each hero has two saved builds. The sheet fits one screen: three path columns of icon nodes and a detail panel with Learn and Refund, so a tap no longer spends a point. Old talents do not map onto the new trees, so every hero's points come back unspent with a one-time camp notice. Also fixed: the Rogue's hero sheet had no icon for Shadowstep. A content change: ships over the air.

---

## Unreleased: the Breeding Wheel and the Matchmaker

The Pets tab's Album becomes the Wheel. All 11 species sit on one ring, ordered so each hybrid's two parents are neighbours and the hybrid sits in the gap between them. Owned species wear their rarity colour, a gold arc marks a pair you own both halves of, and the hub shows the mutations you have found. Under it, a card offers the next hybrid within reach ("Pair" opens the Matchmaker with both picked), then a bestiary of all 19 breeds: hybrids show their parents before you find them, and six pips show which mutations you own on each. Tapping a breed opens its page, with its bloodlines (who to pair it with, and what's missing) and its six mutation slots.

Breed becomes the Matchmaker. Two parent slots show bond, rest and any mutation a parent carries. With a pair picked, it shows what can hatch and how likely each is (32.5 / 35 / 32.5 for a hybrid pair, the hybrid pity included), the litter's mutation chance with its pity bar, and the cost. With one parent picked, partners are listed by what they would make, and missing partners say where to get them. A content change: ships over the air.

---

## Unreleased: the rest of the UI audit

The nine findings the first polish pass left open. The Expedition fits one screen: the five modes share one row, location portraits are smaller, the tier pips that repeated "1 of 8" are gone, and the Hunt button is pinned under the list. Weapon ladders name every set; one you cannot wear yet gets a padlock, and its tile says "Attack 40" in full. A boss's pile of loot stacks its labels instead of printing them on top of each other. Level-up puts Reroll and Keep side by side, with a line saying the ✕ on a card banishes it. Cosmetic prices read 1.75k, 6k, 35k in every row. This Week's rule is a switch. Daily rings today's reward in gold and gives day 7 the full width. The Talents button loses its empty red pill (it already shows the count). Profile shows the record as four numbers and the account link as a real button. Small numbers also lose the ".0" ("12k", not "12.0k"), and the Shop's deal says "Was 1100 · 30% off". A content change: ships over the air.

---

## Unreleased: UI polish pass from the phone-size audit

Every camp sheet and hunt screen was captured at 720×1560 and measured for needless scrolling. Settings fits one screen again: the long art credits sit behind a Credits button. The season list fits without scrolling, the Log's collection is three tiles across (about a third shorter), and Feats lose their repeated heading and list the ones ready to claim first. Quests is a two by two grid. On/off switches are drawn phone-sized, gold when on. The Shop's Buy button is gold when you can afford it, the hero sheet drops its greyed-out "In use" bar, a short hunt's results panel shrinks to its content instead of leaving a blank middle, and the first-launch privacy card no longer covers the game's title. The Log's boss lines say "0 kills" instead of "KC 0 · dry 0 (worst 0)". A content change: ships over the air.

---

## Unreleased: breeding rules, kinder and simpler

Rico's call after the pets review. A parent now rests 8h after every litter; it used to climb 8, 12, 18, 24, 36 and then stay at 48h for good, so a favourite parent was retired after five litters. Rests already running from the old ladder are cut to 8h. A pair that can make a hybrid you haven't found makes it by its third litter at the latest (`BREED_HYBRID_PITY`, counted per pair in the new `hy_dry` save key; a forced litter keeps the seed's genes). Bred and hatched pets can be released from their page for 200 gold, so a full stable (48) no longer stops breeding for good; species pets and the one at your side stay. Eggs still always hatch, and there is no lifetime breeding cap. A content change: ships over the air.

---

## Unreleased: the Rift is a Boss Rush option, not its own mode

From the design audit. The Expedition no longer has a Rift tile. With a rift key in hand, picking Boss Rush shows a "Spend a rift key" toggle that swaps the full rush for one boss at more than twice its strength and a guaranteed unique. Nothing underneath changed: the hunt still runs the `rift` mode, so keys, the Riftwalker feat, stats and saves are untouched. Key rewards now say to spend it on a Boss Rush.

---

## Unreleased: no foe models in the battle warm-up

Rico's iPhone on IPA 399 (16 worker threads) still froze, and the new crash breadcrumb said where: `warm-up foe rh_wraith`. The warm-up no longer loads every foe and the boss up front; each model loads the first time it spawns, at the cost of a hitch the first time each appears. Locally, camp to battle plus 20 s of play passed at 16 threads (3 of 3) and at the old 4 threads (1 of 1; with the warm-up that setup froze 3 of 3). `--battle-start` now stays in the hunt for `--stay=20` seconds so those first spawns are covered. A content change: ships over the air.

---

## Unreleased: camp shows the next goal

From the design audit. `Game.next_goal()` already worked out the nearest thing to chase (a Super rank to buy, a talent point, the next difficulty, the next mastery rank) but nothing on camp showed it. The hunt card now has a "NEXT · ..." line under the place line, hidden when there is no goal.

---

## Unreleased: zones show their boss

The Expedition's location tiles and the Trophy Road's arenas show the zone's boss render instead of text or a flat icon, as a black silhouette while the zone is locked. Heroes already used their portraits.

---

## Unreleased: bounties show what they are about

Each bounty row has a picture: the boss, the hero's portrait, your pet, an egg, or a flat icon for the plain ones (kills, gold, level).

---

## Unreleased: hero rating is gone

From the design audit. Rating was a second per-hero trophy count (+10 a win, -6 a loss) that only the results screen showed, plus a gold-and-shards milestone every 100. Mastery already tracks per-hero progress, so rating and its results line are removed. In the simulated week that is about 150 gold and 7 shards less for the regular player and about 4,200 gold and 90 shards less for the grinder. The save keeps the unused `rating` keys, so no migration.

---

## Unreleased: the Log shows bosses and uniques as renders

The Log's boss rows show each boss in its idle pose (`PropIcons.boss`), and its uniques show the real thing: pets as their own render, weapons and trinkets as their 3D model, armor and trophies keep the flat icon. Uniques you haven't found are black silhouettes.

---

## Unreleased: the "Update required" screen is on

Rico's call (2026-10-29). `tools/ota_gate.json` sets `min_native` 4, so an install whose shell is below `NATIVE_VERSION` 4 (anything before the worker-pool fix) gets the blocking "Update required" screen, linking to the IPA release. `check_store.py` now warns instead of failing when the gate points at the sideload page; switch it to the App Store link before launch.

---

## Unreleased: boss names fit the Expedition location tiles

From the design audit. "The Cinder Warlord", "The Gilded Warden" and "The Thornmother" ran to or past the edge of their location tile; long boss names now use a smaller size.

---

## Unreleased: battles stuck on the crossed swords (reinstall the IPA)

- **Bug:** starting a battle could freeze on the crossed-swords curtain for good (Rico's iPhone, every mode; each stuck battle shows up as a "crash" on the next launch). With a renderer, the hunt's shader warm-up deadlocks the engine: the main thread waits on the shader-compile tasks while every `WorkerThreadPool` thread waits on a lock the main thread holds. The pool is one thread per core by default; at 4 threads it froze 3 runs of 3 locally (and in CI), at 16 it never did. `project.godot` now sets `threading/worker_pool/max_threads=16`.
- That is a project setting, which a content pack cannot carry: `NATIVE_VERSION` is 4, so a shell below 4 keeps its old content until the new IPA is installed. The forced "Update required" gate stays off (`min_native` 0): the store check refuses it while `store_url` is the sideload page.
- A freeze logs no error, so the hunt start now writes its current step to `user://step.txt`; after a crash the next launch's error report gets a `[crash] last step · warm-up foe …` line.
- Leaving camp while hero portraits were still rendering raised a script error (`portraits.gd`); it now stops quietly.
- New check `-- --battle-start` (run with `tools/dev/godot-gpu.sh`): camp, then the Hunt button, with a renderer, as a player does. Bots and captures skip the warm-up, so nothing ran it before. In `check.sh` and CI; it is what caught the freeze again before the pool fix.

---

## Unreleased: the hatch scene uses the real egg and pet

The egg that cracks is the speckled 3D egg render in its kind's colour, and the hatchling is the pet's own render (a black silhouette that floods back to full colour) instead of flat icons.

---

## Unreleased: the season is a little shorter

From the design audit. A tier now costs 240 season xp instead of 400, and the season's outfit is at tier 20 instead of 25 (the second season egg moves from 20 to 25 to swap places). In the simulated week a regular player reaches 6 tiers a week (5 weeks for all 30), a casual player 2, and the grinder 22, still under 30 (`economy_tests`).

---

## Unreleased: the Log fits the screen, Equipment says Hits/s

From the design audit. The Log sheet ran past the right edge because the Evolutions and Sets headings were one unwrapped line; they wrap now. Equipment's "Speed" was really hits per second, the same number the hero sheet calls "Hits/s" (the hero sheet's "Speed" is move speed), so it is renamed.

---

## Unreleased: zones and modes open early, zones stop out-paying each other

From the design audit. Zones never got harder, they only paid more loot, so the newest zone made every older one pointless, and the gates sat 10,500 and 12,500 trophies out (about 23 and 27 weeks for a casual player). Now the zones are variety, not rungs: Vault 4,100, Frozen Crypt 4,400, Burning Swamp 5,000 trophies; the Wilderness opens at 1,000 and the Rogue at 3,500. Every zone now has loot bonus 2 and the Vault's and Swamp's extra gold is gone, so the choice is the boss and its uniques. Done by swapping what the road's steps pay, so step numbers (and the cards gated by them) do not move. `mode_unlocked` now also counts passed steps, like zones do, so a save already past the Wilderness's new step has it. A save loses at most one chest it would have been paid at a step that now pays something else.

---

## Unreleased: Boss Rush and Rift use every boss you have opened

From the design audit. Boss Rush was hard-coded to Gravemaw and the Hexer Queen (twice), and a rift picked one of those two, so four of the six bosses never appeared outside their own zone. The rush now fields the boss of every zone you have opened, once each, in zone order, each 7% stronger than the last (`DB.rush_order_for`); with fewer than four zones open the lap repeats at 1.3x so it is never a two-boss sprint. A rift key opens a random boss from your opened zones, and its unique comes from that boss's table. A bot rush with every zone open beat all six.

---

## Unreleased: one difficulty ladder for the whole account

From the design audit (`reviews/design-audit-2026-10-28.html`). Difficulties used to open per mode, three wins each, so opening Abyss everywhere meant about 105 wins, most far below the player's power. Now a win on your highest difficulty in any mode opens the next one in every mode, and `DB.TIER_WINS` is 1. The first-clear trophy bonus pays once per difficulty for the account (`tier_wins["all:N"]`), not once per mode. Old saves keep the best tier any mode reached (`Game._one_ladder`, safe to repeat, no save version). `mode_tiers` stays in the save, unused. The results screen says "unlocked in every mode".

---

## Unreleased: the dead XP lamp code and tip are gone

The XP lamp screen was removed from Skills earlier, but the results screen still told players to "Rub an XP lamp in Skills" whenever they had 10 shards, and the lamp functions and constants were still there. Removed the tip, `lamp_xp`, `can_rub_lamp`, `rub_lamp`, `DB.LAMP_SHARDS` and `DB.LAMP_XP`, and their tests. Shards now only buy Super ranks.

---

## Unreleased: Season and Daily as picture rows

Each Season tier shows its reward (coins, shards, gems, a real chest, egg or outfit render) with a check on claimed tiers instead of plain text. The Daily login chests are real renders, and the first-win line now mentions the 2 gems.

---

## Unreleased: the Trophy Road shows what you win

The Album's breeds are now a grid of the pets' own portraits (a dark outline until found). The road's chest, egg and pet steps show the real chest, egg or pet render in their icon well (dimmed until reached), and the last player-visible "NEW SIDEKICK" tag now says "NEW PET".

---

## Unreleased: chests and eggs are real renders

Shop chest cards (deal of the day, chest tiles, daily deals), the results chest and the egg shop and hatchery cards now show the actual 3D chest (KayKit, lit in the chest's colour) or a speckled egg built in code (`src/ui/prop_icons.gd`, cached off-screen renders). The egg shop header says one line when both clocks match.

---

## Unreleased: shop look tiles show the look

Outfit and weapon-skin tiles in the shop show the hero wearing the look (`src/ui/look_icons.gd`, same cached off-screen render as the pet portraits) instead of the hero icon, and long names no longer truncate. Weapon skins are still a full-body shot: the weapon is small in it.

---

## Unreleased: pet portraits instead of icons

The Stable and Breed tiles, the breed slots and the rename sheet now show each pet's own 3D portrait (`src/ui/pet_icons.gd`: one render per pet and growth stage, off screen, cropped to the creature, cached for the session) in place of a flat icon. Locked silhouettes keep the icon. First of the "real renders everywhere" passes.

---

## Unreleased: the evolve scene shows the real pet

The evolve sequence used a flat icon. It now stands the real 3D pet (the Pets screen's stage) in its old form, whitens it, and swaps in the new form at the white-out. An evolved pet without its own special look (only the Ash Wyrm has one) now has its coat drawn toward its colour with a faint glow of it, so the grown-up form is visible in the camp and the hunt as well. Screenshots: `evolveseq` for the drake (Ash Wyrm) and the crow.

---

## Unreleased: casual play earns gems

Your call (2026-10-28). The first win of each day pays 2 gems, and the login calendar pays 5 gems on day 3 and 10 on day 7 (shown on the Login sheet and the results screen). Simulated week: casual 27 gems, regular 42, grinder 61. `economy_tests` now claims the login each day and guards that a casual week earns 5 to 40 gems.

---

## Unreleased: "Pets" everywhere

The word "sidekick" is gone from player text (results note, hatchery line, credits, daily quests, breeding error, legendary power lines). Internal ids, save keys and sheet names are unchanged, so no migration.

---

## Unreleased: the shop shows the look before you buy it

The buy sheet for an outfit or a weapon skin now draws your hero wearing it (a small studio render, `src/lobby/look_preview.gd`) instead of repeating the tile's icon and blurb. `GearLook.look_override` lets the preview dress a hero in a look they do not own. `--shots=shoplookbuy` captures it. Glows and gear are not covered yet.

---

## Unreleased: the weekly event folds into the season

Your call (2026-10-28). The 10-tier weekly event track is gone. A hunt under the weekly rule now pays bonus season XP (its score / 60, about 30 for a win), shown on the results screen and in Season. The camp's Event sheet is "This week": the rule, its toggle, and the board. The omen egg moved to season tier 23. A save with earned, unclaimed event tiers this week is paid out once at boot (`Game._fold_event`) and the camp says so once. New save key `folded_event` (default 0); the old `event` key stays, unused. Simulated week: casual 1 season tier, regular 3, grinder 13.

---

## Unreleased: one plan for every bot

`docs/PLAN.md` is rewritten as the live queue (rules for working with other bots, what needs Rico, what is next); the old phases moved to `docs/PLAN-history.md`. New `docs/biomes.md` records which zones are rebuilt. `CLAUDE.md` gains the two-bot rules. Also restored the `---` between changelog entries that the merges dropped.

---

## Unreleased: omen hunts score again, and a simulated economy week

- **Bug:** `Game.weekly_score` ran `int()` on the hunt's list of boss ids, so finishing a hunt under the weekly rule raised a script error and the week's best and event points were not recorded. It now counts the list. No bot ran an omen hunt, which is how it shipped.
- New `src/economy_tests.gd` plays a week for a casual, a regular and a grinder player through the real `finish_hunt` and tier claims, prints an `ECONOMY` line each (casual: ~8k gold, 1 season tier, 2 of 10 event tiers; grinder: ~58k gold, 7 season tiers, all 10 event tiers) and guards the shape.

---

## Unreleased: main.gd loses its dev modes

The autopilot, screenshot, perf and contact-sheet code (1,850 lines) moved from `src/main.gd` to `src/dev/capture.gd`, which the export leaves out. `main.gd` is 270 lines. Behaviour is the same: `--bot`, `--capture` and the shot helpers run through a shim for Main's `current`, `go` and `pending_chest`.

---

## Unreleased: unused foe scenes removed

Deleted `assets/foes/bloat*` and `spore*` (scene, glb, palette): nothing referenced them since the Blender models replaced them. They shipped in every pack.

---

## Unreleased: Godot stops importing docs/

Added `docs/.gdignore` and removed 69 `.import` files for review screenshots and videos. They were never in the pack (`docs/*` is excluded from export) but every import, local and CI, processed them. The media itself is untouched.

---

## Unreleased: the weekly board refuses impossible scores

`weekly_submit` clamped a reported score to 100000, so a cheater still took first place. It now refuses anything above 40000 (`implausible`, logged), a bound taken from the score formula. No game change; the server needs redeploying. `net_test.gd` covers it.

---

## Unreleased: a recovered hunt says so

When the phone kills the app mid-hunt, the next boot pays the hunt out as a retreat. The camp now shows a note ("Your last hunt was saved", with the gold and items kept) once, then clears the `recovered_run` flag. Before, the flag was written and never read. `--shots=recovered` captures it.

---

## Unreleased: pinned tool versions

The test-server workflow downloads cloudflared 2025.9.1 instead of `latest` and runs on
`ubuntu-24.04`, so an upstream release cannot break the server unannounced.

---

## Unreleased: the release gate catches broken imports

No game change. PR #118 shipped 93 broken audio imports and nothing failed,
because a sound that cannot load is only an engine `ERROR` line.

- `tools/dev/check_imports.py` fails on any committed `.import` marked
  `valid=false`, and on `Failed loading resource` / `Invalid array format`
  lines in the test and bot logs. It runs in `tools/dev/check.sh` and in the
  `Game checks` workflow.
- `tools/dev/check_pack.py` opens the exported pack and fails when a sound or
  texture has no imported copy in it, and prints the pack's size against a
  200 MiB ceiling. The IPA workflow runs it before the pack is published.
- `assets/splash.png.import` is valid again (it had the same `valid=false`).

---

## Unreleased: sound is back, and three progression fixes

No save version change: the road fix is safe to repeat on every load.

### Fixed
- **Sound and music on phones.** PR #118 committed 93 broken audio imports
  (`valid=false`), so the content pack shipped without nearly every hit, UI,
  chest and level-up sound and the home, hunt and boss music. The imports are
  restored from before #118.
- **The Rogue joins saves that were far along the road.** The road grew to 42
  steps with the Rogue at step 25. A save that had claimed past 25 on the old
  road got a crypt chest there instead, and never the Rogue. Any hero step a
  save counts as claimed now opens its hero on load.
- **First-clear trophies pay once a difficulty.** They were paid on the first
  win and again on the third (the one that opens the next difficulty).
- **Hybrid pets keep every body surface.** Carving a borrowed part dropped the
  mesh's custom channel formats, so a surface with float custom data was
  refused and went missing.

---

## Unreleased: the Rime Regent and the Rime Seer are back on KayKit

Two models are gone from the pack because their provenance could not be defended
(Phase 3 of the plan).

- **The Rimehollow boss is the Rime Regent again** (the KayKit `Skeleton_Warrior`
  in his `regent` skin, scale 2.6), as he was before PR #121. The Frost Troll
  model's own credit said it was a probable re-upload of someone else's work.
  Everything the Troll's PRs added keeps working: the Rime phase moves, the
  court's cracking ice, and the Long Road boss hall.
- **The Rime Seer is the KayKit `Skeleton_Mage`** in the `rime` skin with a
  staff, as it was before PR #129. The Sketchfab model it used was "The Elder
  Scrolls Blades Nether Lich", ripped from a commercial game. Its brain
  (`caster`, spell `thin`) and numbers are unchanged.
- Removed `assets/foes/frost_troll*` and `rime_seer*` (about 9 MB of glb and
  textures), their credits, and the troll rig from `boss_models.gd`.
- **The Cinder Mire dragonfly is drawn in code** (flat primitives, four beating
  wings) instead of "Dragonfly Chicken Gun", named after a commercial game.
- New `docs/art-audit.md` lists every third-party model with the ones a person
  should check before an App Store build.

---

## Unreleased: Biome rebuild, the Long Road on the kits

The Long Road's frost and mire rooms (`arena_trial_zone.gd`) place the Art kits' meshes instead of code-built
ones. Walls, dividers (glacier ramparts, stake palisades, 2.35 m step along x), gate posts at the gap, room
cover (ice pillars, ash rocks), camp props (banner, cairn, crates, beacon / barricade, barrels, cage, fire
pit, snags), the frost spire ring and the Warlord's watchtower and cage come from `rime_road` / `mire_road`
(#138); pines, crystals, braziers, reeds and the Pyre Tree from the arena kits. `mire_kit.gd` and every
code-built piece in `kit_mesh.gd` are deleted; it keeps only the MultiMesh `batch`. Captures:
/workspace/rebuild-caps/long-road.

---

## Unreleased: Biome rebuild, the last Rimehollow kit pieces

The kit's throne (dais, ice seat and spires; replaces five scaled ice blocks), the six `hole_rim` rings round the
fishing holes, the `ice_arch` over the causeway at the Glacier Gate (its legs are cover), and fifteen `snow_bank`
drifts at the foot of the cliffs and the shore props are placed in `arena_rime.gd`. Before/after:
/workspace/rebuild-caps/rime-pieces.

---

## Unreleased: Biome rebuild, the swamp light lives in db.gd

The Burning Swamp's lift (ambient 1.35 warm-grey, a warm 1.55 sun, ground `grass_a`/`grass_b` 0.36/0.5 browns)
moves from `arena_mire.gd` `_light` into `db.gd`'s swamp env, so night and the day cycle (`hunt_modes.gd` scales
the zone's `ambient_e`/`sun_e`) work from the lifted values instead of the old murky ones. `_light` keeps only
what env has no key for: exposure 1.18 and the cool rim light. The Long Road's mire floor uses the same lighter
soil. Looks the same in the hunt (before/after in /workspace/rebuild-caps/swamp-light).

---

## Unreleased: perf-biomes fails a run that drew nothing

`tools/dev/perf-biomes.sh` now fails when a run reports 0 draw calls or 0 triangles (a blank viewport or a
dead camera used to print `0` and pass the budget). The swamp mobile runs re-measured after the biome
models landed: hunt 252 draws p95, busy 281, boss 203; 150k-240k triangles; 1.6-3.3 ms script frame.

---

## Unreleased: Biome rebuild, the frost water is blue

Open water in Rimehollow rendered black (`water_col` in `terrain_ground.gdshader` was near black, and
there is no sky to mirror), so a fishing hole or a cracked-open floor read as a hole in the world. It
is now a deep blue with a slow lighter ripple, still glossy and unlit by fog or tint.

---

## Biome visual polish (dev/biome-models, round 2)

- Cinder Mire is lit: brighter ground, a warm key, a cool rim light (arena_mire.gd `_light`).
- Rimehollow snow and ice have ripples, a glinting crust and frosted ice shores (`snow_detail` in terrain_ground.gdshader).
- Frost Imp, Frozen Effigy and Rime Seer swapped for darker, higher-fidelity models (Rodolfoisreal1423, SuperKapoo913, orangesauceu; CC BY 4.0); the Winter Caller is the only wendigo.
- FoeModels.DEFS emptied: every Rimehollow and Cinder Mire foe stands on its next_foes.gd model.
- Biome capture shots: knight in Blackguard plate, no tutorial hint, no ground telegraphs.

---

## Unreleased: Biome rebuild, the Rimehollow kit

Rimehollow's cliffs, crystals, ice blocks, pines, longship, hut, sled and
boulders are now the Art kit's Blender meshes (`assets/kits/rime/rime_kit.glb`
via `KitModels.mesh`) instead of the code-built pieces: darker, colder ice and
rock, one palette texture, same sizes, transforms and obstacle circles. Still
code-built: the Long Road's frost rooms (`Kit.cliff` and friends).

---

## Unreleased: Biome rebuild, bog in the flow field and bosses that wade

The foes' flow field now weighs the ground: a step costs the terrain's `cost`
(1 firm, 3 bog, 6 burning), so foes walk round a small bog when a dry way is
not much longer and wade a wide one. Zones without terrain keep the plain step
count. Bosses feel half of what the ground does to the hero (a bog or a cracked
open hole slows the Frost Troll or the Cinder Warlord), and still never drown.

---

## Unreleased: Biome rebuild, the Frost Troll cracks the floor

From his second phase the Frost Troll's court cracks. The break itself cracks a
ring of ice round him; after that a patch just ahead of where you are heading
turns thin every 6.5 s (every 4 s, two at a time, in the third phase), and
Shatter's pillars crack the ice they stand on. Cracked ice snaps to cold open
water after 1.9 s whether you stand on it or not, and freezes over again
(`Terrain.crack`, `crack_disc`, `boss_rime.gd`). Ice only: snow and the Long
Road's firm ground never crack.

---

## Unreleased: Biome rebuild, foe kits wired in

`DB.enemy` now folds the Art foe kits into the foes' defs (`FoeModels.fold`):
Rimehollow's wolf, frost wraith, yeti and shardling and the Cinder Mire's
shaman, bloat and sporecap wear their own models, rigs and clips. Foes without
a kit stay on their skeletons.

---

## Unreleased: Biome rebuild, the Long Road in Rimehollow and the Mire

On the Long Road in Rimehollow or the Burning Swamp the same rooms, gaps and
encounters now stand on the zone's own kit (`src/hunt/arena_trial_zone.gd`): a
tall terrain grid the length of the road, glacier or bog-rock walls, rock
ramparts or pile palisades for the dividers, ice ponds (thin ice, then open
water deeper in) or bog pools with a boardwalk of planks that burns, and the
court of the Frost Troll or the Warlord's deck and Pyre Tree at the end. A firm
line always runs gap to gap. Other zones keep the dungeon. Foes are no longer
placed in open water.

---

## Unreleased: Biome rebuild, the Cinder Mire built from the Art kit

The Mire's boardwalk (with `KitModels.charred("mire")` for burning planks), piles, shacks (one burnt),
Pyre Tree, braziers, bog stones and reeds are now the Art kit's Blender meshes
(`assets/kits/mire/mire_kit.glb` via `KitModels.mesh`) instead of the code-built pieces in `mire_kit.gd`: same sizes, transforms and obstacle circles, one palette
texture. Still code-built: the Long Road's mire rooms (`arena_trial_zone.gd`).

---

## Unreleased: Biome rebuild, the Cinder Mire

The Burning Swamp now paints the terrain grid. `src/hunt/arena_mire.gd` lays out a
black bog (it drags: speed x0.55) with dry islands, ash and a boardwalk of planks
from the landing to the Cinder Warlord's platform, a plank deck ring round it,
and the Pyre Tree as his den. A methane vent or marsh blast now lights the bog
and planks it reaches; fire runs the boardwalk, a burnt plank falls into the bog
(`src/hunt/mire_plank.gd` chars and sinks), burnt bog turns to ash and floods
back. Three shrines, five vents on ash pads, `graves` on firm ground, `perches`
on island shores and `spawn_holes` in open bog. New pieces are code-built
low-poly meshes in `src/hunt/mire_kit.gd` (planks, piles, shacks, Pyre Tree,
braziers, reeds, stones), batched where they can be. `Terrain.fill_ellipse` and
`fill_line` are shared by both zone layouts.

Retired: the old swamp layout (`arena_swamp.gd`), the prop reskin
(`env.skin`, `BiomeArt.recolor`, the four recoloured prop textures and their
script outputs) and the unused mound, crystal, snow-cap, ice-sheet and scorch
helpers in `biome_art.gd`. Tests: `terrain_tests.gd` adds the Mire (a firm route
to the platform, reachability, fire over planks, spawn spots on the right
ground).

---

## Unreleased: Biome rebuild, real models for the foes and the ambient life

All 16 Rimehollow and Cinder Mire foes and the six model-based ambient critters
(hare, owl, wolf, frog, dragonfly, crow) are now real CC BY 4.0 Sketchfab models
instead of KayKit stand-ins and primitive meshes. Sources and authors are in
`CREDITS.md`, `assets/critters/LICENSE-critters.txt` and the in-game credits.
Single-clip rigs get generated move/attack/hit/death clips (`FoeRig`), so they
animate without Mixamo. The owl glides past rather than perching. The swamp's
cells paint in its own dark earth (`biome_ground.gd`); a zone whose own arena has
not painted terrain no longer shows a snow plane. `--capture --shots=biome
--zone=frost|swamp` renders the zone's eight foes and its critters. Bog dwellers
burn harder (x2) in `terrain_run.gd`.

---

## Unreleased: Biome rebuild, the Frost Troll

The Frozen Crypt's boss is now the **Frost Troll** (provisional model by
moonbaby2402, CC BY, see `CREDITS.md`), 5.7 m tall at scale 3.0. `DB.BOSSES["rime"]`
names its rig like the Cinder Warlord does; hitbox radius 1.95, occluder 2.1 x 6.0.
His attacks are the Regent's (cleave, quake, charge, ice lanes, blizzard).

---

## Unreleased: Biome rebuild, the new foes go live

`FoeBrains.next` is now on: Rimehollow and the Cinder Mire field their rebuilt
foes (`--old-foes` brings the old factions back for a bot run). Open water no
longer drowns the swimming ambush foes (Bogfin, Bog Frog), and a submerged one
is never burned. `arena.spawn_holes` and `arena.perches` exist; Rimehollow fills
them (cracks round the court for the Winter Caller's imps, the lake rim for the
wraiths).

---

## Unreleased: Biome rebuild, ambient life and audio

- Rimehollow and the Cinder Mire now have their own ambience (`src/hunt/ambience.gd`):
  snow hares, owls on ice crystals, a watching wolf and visible foe breath in the
  cold; frogs, dragonflies, crows on stumps, methane bubbles that pop into small blue
  flames and fish rings in the bog. All flat-coloured primitives, no particles,
  harmless, capped (two on Low quality) and gone when the hero comes near.
- Each zone has a looping sound bed (ducked under loud fights) and spatial one-shots:
  wind, ice creaks and drips; swamp air, frogs, a crow, bubbles and ember pops.
  CC0 recordings from OpenGameArt, credited in CREDITS.md and the in-game credits;
  the creaks and drips are synthesized. `tools/audio/build_ambience.py` builds them.
- `src/ambience_tests.gd`: assets and credits, caps, flee behaviour, ducking.

---

## Unreleased: Biome rebuild, Rimehollow layout

Rebuild 3. The Frozen Crypt zone (Rimehollow) is a new arena, `arena_rime.gd`,
painted on the terrain engine: a cracked blue lake with thin-ice webs and open
water holes, a causeway to the Troll's court on a ring of ice pillars and a
throne, two ice caverns sealed by breakable ice walls (a dash or heavy hit opens
them) with a shrine inside, a wrecked longship, a hut and a sled on the south
shore, snow-capped cliffs round the whole arena and a pine forest outside it.
The scenery is flat-shaded procedural kit meshes (`kit_mesh.gd`) drawn as
MultiMesh batches. The old frost reskin is no longer used. Hazards are now icefall,
thin ice and gale. `tools/dev/layout-cap.sh` stills any arena from above.
`terrain_tests.gd` proves the throne is reachable on foot and the caverns open
only after the ice breaks.

---

## Unreleased: Biome rebuild, foe AI

- Sixteen new foes (Rimehollow and Cinder Mire) with their own behaviours:
  wolf packs that lunge one at a time, a yeti, a dormant effigy, wail wraith and
  cinder imp kiting, seer, caller, shaman and hag casters, shardling, sporecap
  and bloat drifters, an ambushing bogfin and bog frog, and the ember wasp. Each
  shows a ground telegraph before it can hurt and plays idle, run, attack, hit
  and death clips. They run as brain objects (`src/hunt/foe_*.gd`, defs in
  `src/data/next_foes.gd`), so the zones still field today's foes until
  `FoeBrains.next` is turned on; `-- --bot --next-foes` plays them now.
- `src/brain_tests.gd` drives a real Hunt with a terrain grid and checks the
  telegraphs, pack rules, ambush, fire and ice interplay. check.sh also runs the
  Frozen Crypt and Burning Swamp hunts with `--next-foes`.

---

## Unreleased: Biome rebuild, terrain engine

The Cinder Mire boss is now the **Cinder Warlord**: Riltariki's orc (CC BY, see
`CREDITS.md`), 5.7 m tall at scale 3.0 with its own
clips. `DB.BOSSES["cinder"]` names its rig (`"rig": "cinder_warlord"`) and
`DB.boss_def` folds in the fit, clips and alias from `boss_models.gd`. Hitbox
radius is 1.95 and the occluder 2.1 x 6.0 for the taller body. Story cutscenes
pass the rig to the boss actor so the Warlord shows there too.

Rebuild 2/3. No visible change yet: no zone paints terrain until the Rimehollow
and Cinder Mire layouts land.

- The Arena owns a terrain grid (`arena.terrain`, all dry) and `terrain_begin()`
  turns it on for a zone: one ground plane (`terrain_ground.gdshader`) draws
  ice, thin ice, open water, bog, fire and ash cells from two small textures,
  with hard noisy edges and a real specular on ice and water.
- `terrain_run.gd` steps the grid each tick: thin ice snaps, foes that stop on it
  or fall in water drown, fire spreads and burns bog foes, the hero is chilled
  and dragged out of open water, and every body gets its ground's speed, grip
  and knockback slide (`t_speed`, `t_grip`, `t_slide` on `Actor`).
- Ice walls (`add_ice_wall`) are solid to everything and break to a dash or any
  big blow; the flow field routes round water and walls.

---

## Unreleased: Biome rebuild, test harness

- `src/hunt/terrain.gd`: the terrain cell grid's rules as plain data (nine kinds,
  surface grip and speed, thin ice that snaps after 1.2 s, fire that spreads
  across bog and planks in 1.5 s telegraphed steps, ash that re-floods after
  25 s). Nothing uses it yet; the Arena hooks it in (see
  `biome-rebuild-plan.md`, "Dev hooks").
- `src/terrain_tests.gd` and `src/foe_tests.gd` run inside `-- --test`: surface
  physics, drowning, fire spread and re-flood, and every foe def's six
  animation states against its model.
- `tools/dev/perf-biomes.sh` (and `check.sh --perf`): draw calls, triangles and
  frame ms for the Frozen Crypt and Burning Swamp, hunt, busy and boss scenes.

---

## Unreleased: Phone performance and battery

Code only (OTA-safe, no `project.godot` change, no reinstall). The look is untouched.

- **Frame cap.** On a phone the game now asks for 60 fps (`Game.fps_cap`); an iPhone with a
  120 Hz screen used to draw twice as many frames for no gain in a top-down hunt. New
  Settings row **Frame rate: 60 / 30** (setting `fps`, 30 = battery saver, applies at once).
  At 30 the simulation step ceiling is 1/24 s (`Game.max_step`) so the hunt keeps real-time
  pace. Desktop and the bot checks are not capped.
- **Physics tick 30 Hz** on a phone, at most 2 steps a frame: nothing uses the physics engine.
- **Background.** `NOTIFICATION_APPLICATION_PAUSED` drops the cap to 5 fps until the app resumes
  (the hunt already pauses itself in `focus_guard.gd`).
- **Hunt CPU.** Prop fade checks at 30 Hz with the elapsed time accumulated (no reusable
  array per frame), torch flicker at 20 Hz, foe separation rejects far pairs on plain numbers
  (no vector per pair), the HUD stops restyling the buff label and re-setting the hurt
  shader every frame.
- **Measuring.** `tools/dev/perf.sh [hunt|busy|boss] [zone] [low|high] [frames]` runs the new
  `--shots=perf` capture twice: headless for script time per frame, software Vulkan with the
  mobile renderer at 1179x2556 for draw calls and triangles.
- Already in place and left alone: batched props (MultiMesh), blob shadows for minions, no
  shadows on small props, low-quality particle halving. Mesh LOD threshold was tried (1 to 3)
  and changed under 3% of triangles, so it was not shipped.

---

## Unreleased: Real music for the new zones

The placeholder synth loops for the Frozen Crypt and the Burning Swamp are replaced by
real tracks (Kevin MacLeod, CC BY 4.0): cold choir and bass for the Crypt, a clicking
drone for the Swamp, a waterphone-and-brass march for Rime Regent and a choir-and-anvil
drive for Cinder Ogre. Each loops seamlessly at -16.5 LUFS like the other zones.
`frozen_boss` and `swamp_boss` also get the 0.7 boss intensity floor the other boss
tracks have.

---

## Unreleased: Screen shake intensity

The Screen shake on/off switch is now Off / Low / Medium / High (setting
`shake_level`), in the pause menu and the camp settings. It applies live and is
saved. **Low is the default**, about a third of the old strength. No save-version
change: `Game._migrate_shake` turns an old shake-on into Low and shake-off into
Off on load (safe to repeat).

- One dial in `HuntCam` (`LEVELS`): the rattle, the hit kicks and the punch-in
  (supers, boss slams) all scale by the level, so every `hunt.shake`, VFX tier
  shake, boss and biome hazard call, `cam.kick` and `cam.punch` follow it.
- Lower ceilings at every level, High included: peak shift 0.6 m to 0.45 m,
  rotation 0.05 to 0.025 rad, trauma capped at 0.8, one blow adds at most 0.5,
  kicks cap at 0.3 m, punch-ins at 0.16.
- The camp's jolts (chest open, hatch, evolve) follow the setting too, capped at 10 px.

---

## Unreleased: The Frozen Crypt and the Burning Swamp

Two new zones after the Vault, opened on the Trophy Road (Frozen Crypt at
10500 trophies, Burning Swamp at 12500). No save-version change: the road gains
seven appended steps and `Game.zone_unlocked` also opens a zone for any save
whose `road` already passed its step.

- **Frozen Crypt** (boss: the Rime Regent): a rimed crypt lair on snow, ice
  crystal clusters as cover, snow drifts that slow, a gale that shoves, and
  icicles that fall on a telegraph. Foes: Frostbound Thrall, Rime Guard, Rime
  Archer, Rime Seer, Winter Caller, Rime Hound, Glacier Colossus. Chilling hits
  leave frost patches; bodies shatter.
- **Burning Swamp** (boss: the Cinder Ogre): a scorched crypt, bog pools that
  drag, methane vents that erupt on a telegraph, marsh fire, burning stumps.
  Foes: Bogwalker, Charred Guard, Ember Spitter, Cinder Witch, Pyre Caller,
  Bog Leaper, Methane Bloat (ignites the ground when it dies), Pyre Brute.
- Bosses use the existing entrance (`boss_intro.gd` styles `rime`, `cinder`)
  with new patterns: Rime Regent's Icelances and Blizzard, Cinder Ogre's
  Eruption, Inferno and Bloats; both reuse cleave, quake and charge.
- Loot: five uniques per boss (weapon, armor, boots/robe/cowl, trinket, and an
  Ancient relic at Torment+), a Frost Egg and a Cinder Egg on the road.
- Art: `tools/art/biome_textures.py` recolors the KayKit skeleton, ogre, forest
  and graveyard atlases (unmodified PBR, no fog, no tint wash); `biome_art.gd`
  batches the crystals, drifts, pools and vents.
- Music: `frozen`, `frozen_boss`, `swamp` and `swamp_boss` are cut by
  `tools/audio/build_biome_music.py` from four Kevin MacLeod tracks (CC BY 4.0,
  see CREDITS.md). Snow and embers are crisp round dots.
- Weekly events, pets, power-ups, the living world and the quality toggles work
  as in the other zones; the Long Road gets the zone's lighting and weather,
  and its hazards, but not the static drifts or vents.
- `tools/dev/check.sh` also runs a hunt in each new zone.

---

## Unreleased: The Trophy Road

The feature freeze was lifted once for this, at the user's request. Save
version 7: `renown` is now trophies (same total), `road` counts steps on the
new road, new keys `unlocks` and `start_picked` (`Game._migrate_v6`).
`NATIVE_VERSION` unchanged.

- Hunts earn trophies, which never go down: 30 for a win, +10 per difficulty
  above Normal, +2 per elite (up to 5), +30 for the first win of the day, +50
  for a first clear; a loss pays up to 15; the Descent +4 per depth.
- The renown road becomes the Trophy Road (`src/lobby/trophy_road.gd`), a full
  screen from the trophy button: arena banners, a glowing track that fills to
  your trophies, claim bursts and a reveal for each unlock.
- Unlocks move onto the road: Long Road 150, Boss Rush 550, the Crypt 800,
  Descent 1200, Wilderness 2100, the Grove 2500, Barbarian 3000, a rift key
  3500, then a Crypt chest every 500. Heroes no longer join from shards.
- A new save chooses its first hero (Knight, Ranger or Mage,
  `src/lobby/hero_pick.gd`); the other two are picks at 400 and 1500.
- Old saves keep every hero, mode and zone they had; steps below their
  trophies count as claimed.

---

## Unreleased: Weapon skins

Two weapons modeled from scratch for the shop: the **Oathbound Blade**
(Knight, 6,000 gold) and the **Reaper's Scythe** (Barbarian, 8,000 gold).
A skin changes the model in the hero's hand; stats stay the equipped
weapon's. Built by the Blender scripts in `tools/art/`, colored with the
KayKit palette texture so they match the rest of the art. New per-hero save
keys `skin` and `skins` have defaults; save version unchanged. Look at them
with `--capture --shots=skins`.

---

## Unreleased: Camp tabs and hunting together

The feature freeze was lifted once for this, at the user's request (see
docs/PLAN.md "Next up"). Save version unchanged: new keys `profile` and
`online` have defaults. `NATIVE_VERSION` unchanged: no autoloads or project
settings changed. Online features stay off until the server is deployed and
`src/net/net_config.gd` points at it.

### Added
- **Tabs along the bottom**: Heroes, Hunt and Clan, tapped or swiped like
  the big mobile games, icons only with the open tab named. Hunt is home,
  with a fixed chest slot beside the Hunt button, a player plate with your
  name and clan, and a Journal button for the reward tracks, feats and log.
  Heroes is the gear screen with each hero's skills, talents, looks and ally;
  tap the name for the hero's card.
- **Shop**, the leftmost tab, paid in gold only (nothing costs money). Six
  daily deals that turn over at midnight: a free gift, discounted shards for
  your hero and one other (a locked hero first), two pieces of gear for your
  hero at the best material you've opened, and a chest at 30% off. A chest
  shelf (Silver 400, Gold 1,100, Crypt 2,600 gold; a bought chest opens in
  camp like a won one) and every weapon glow, one of them 30% off each week.
  New save key `shop` has a default.
- **Clans**: search, join or ask to join, start one (name, badge, open or
  closed, minimum combat), members with leader and elder tools, filtered clan
  chat with emotes, and tap any name to report or block.
- **Friends** by 6-letter friend code, with online status, requests and blocks.
- **Bring a friend**: a new player who enters your code in their first week
  gets 2,000 gold, a Gold Chest and 10 shards. You get 500 gold at once and
  more as they play (5 hunts, combat 25, a Veteran win), plus a Kinship weapon
  glow for the first friend, two Crypt Chests at three, 10,000 gold at five
  and 25,000 gold and a Crypt Chest at ten. Rewards are paid by the server as
  the friend really plays, capped at 20 friends.
- **Weekly clan raid boss**: every hunt you finish hits it; when it falls,
  every raider gets 1,500 gold and a Crypt Chest, the top three 20 shards.
- **Parties and co-op hunts**: up to three clanmates; partners walk where
  their player walks and fight beside you, and a party hunt pays 20% more gold.
- **Rankings** by power, **cloud save**, **moving to a new phone** with a
  transfer code, and **account deletion** under Profile › Account.
- `server/`: the game server (Nakama with our rules, Docker, HTTPS, nightly
  backups), its smoke test, and `-- --nettest` for the game's side.

---

## Unreleased: Skills are a hero's power

Save version unchanged (bought levels are refunded on load). `NATIVE_VERSION`
unchanged.

### Changed
- **Each hero has their own skills and combat level.** Hunt XP trains only the
  hero who played. Heroes start fresh at Combat 3.
- **No more bought hero levels.** Damage and health come from skills (+4.5%
  per level for 40 levels, then +1.5%). Every style trains three skills at the
  same pace. Combat counts Ranged and Magic 2x so all heroes top out alike.
- **Combat level earns talent points** (one per 5 levels), a fourth card
  choice at 70 and a second potion at 95.
- **Shards rub XP lamps** in Skills: 10 shards for XP in a trained skill.
- Old saves get back the shards and gold their bought levels cost.

---

## Unreleased: Gear has one quality ladder

Save version unchanged (old item names are rewritten on load). `NATIVE_VERSION`
unchanged.

### Changed
- **Tier is the color.** A piece's frame, name and drop beam show its
  material tier, grey to red, everywhere. Rarity is now pips under the icon
  (how many bonus stats); uniques carry a star.
- **Plain names.** "Barrowborn Steel Greaves" is now "Steel Greaves": the
  random prefixes are gone, and gear already in a bag is renamed.
- **Equipment screen.** The hero stands between the slots, with the stats
  under them and the bag as a grid of tiles below. No power numbers on gear:
  the card says what changes on the hero ("Health 516 → 634") if you wear it.
- **Armor icons** for helms, chests and legs are flat outlines in place of
  tiny renders of a whole hero.

---

## 2026-10-29: First steps, more music, results

No save version change (the new tutorial notes use the existing `tips` key).
`NATIVE_VERSION` unchanged.

### Added
- **First camp is quieter.** Before the first hunt the camp shows the hero,
  the expedition, the big button and the tabs; the side column, bounties and
  the road appear once there is something on them.
- **One-time notes** point at the next thing for a new player: the hunt
  button, the first chest, new gear, a hero ready to level up. Any tap puts
  one away; each shows once per save.
- **Five more music tracks** by Kevin MacLeod: two for camp, two for hunts,
  one for bosses. Camp, hunt and boss pick a different track each visit.
- **Defeat points somewhere.** The defeat screen names the one thing most
  likely to win the next try (equip a found upgrade, level the hero, close a
  power gap, or a tip), and its button reads "Try again".

### Fixed
- Loot left on the ground at a win flies to the hero instead of standing
  there: its floating names showed through the results screen.
- The results chest sits beside its name, so three loot rows fit on a short
  phone instead of one and a half.

---

## Unreleased: Launch splash and in-game updates

`NATIVE_VERSION` 3: needs a new IPA. Installs on shell 2 keep their current
content until reinstalled.

- The launch screen is a Gravelight splash (the app icon's lantern scene, full
  length, with the title) instead of the Godot logo. iOS builds its launch
  screen from `application/boot_splash/image`; with none set it used Godot's.
  `tools/dev/splash.sh` re-renders `assets/splash.png`.
- Boot holds on that splash while the update check runs, then fades into camp.
- An update shows a progress bar over the splash, then restarts the game on the
  new content in-process (scene freed, scripts and resources reloaded,
  autoloads rebuilt), so it applies without closing the app.

---

## 2026-10-28: Release cleanup

Save version 6 (stored item names take the new gear words). `NATIVE_VERSION`
unchanged.

### Changed
- **The game is called Gravelight.** Window title, Settings and the sideload
  listing. The home-screen name changes with the next IPA; bundle id and save
  file are unchanged, so nothing is lost.
- **Original gear names.** Materials no longer borrow Old School RuneScape's:
  metal is Bronze, Iron, Steel, Cobalt, Verdite, Skyiron, Bloodiron; hide is
  Leather, Hard Leather, Studded, Fenscale, Tidescale, Emberscale, Nightscale;
  cloth's Mystic and Infinity are now Sage and Sunwoven. Pieces: Helm, Visored
  Helm, Hauberk, Cuirass, Chausses, Greaves, Warden Shield, Robe, Robe Skirt.
  Gear already in a bag is renamed on load.
- **Level-up scroll** reads "Strength rises! Your Strength is now level 12."

### Added
- **A new app icon.** The Knight, lit from below by a lantern at his feet,
  graves behind him in blue night. Rendered from the game's own models by
  `tools/dev/icon.sh` (`tools/app_icon.gd`, shot `appicon`), so it can be
  re-rendered when the art changes. Shows on the home screen with the next IPA.
- **Error report for playtests.** Every engine and script error is logged
  locally (`user://errors.json`, repeats folded into one line with a count),
  and a run that never closed cleanly counts as a crash. Settings shows
  "Errors N · crashes N" and a **Copy report** button that puts build,
  device and the log on the clipboard, ready to paste into a message.
  Bots and captures don't write it. No backend, nothing leaves the phone.

### Process
- **Feature freeze** until the first real playtest: see `docs/PLAN.md`,
  Next up. Fixes, tuning, feel, art swaps and release work continue.

---

## 2026-10-27: Fantasy Weapons Bits

No save, settings or native changes.

### Added
- **The KayKit Fantasy Weapons Bits pack (CC0)** and new drop looks built from
  it. Knight: Arming Sword, Morning Star, Warhammer, Rapier, Claymore, Halberd,
  Plank, Crest and Bulwark shields. Barbarian: Spiked Club, Bearded Axe,
  Double Axe, Labrys, Maul, Plank Shield, Bulwark. Mage: Crystal Wand, Crystal
  Staff. Ranger: Hunting Bow, Recurve Bow.
- **Bigger boss-set pieces.** The Blackguard Blade is now a black claymore with
  a crest shield, the Dread Axe a labrys with a bulwark, the Shade Bow a
  recurve. The Thorn set gets a katana-thin Thornblade, a plank Grove Shield,
  a spiked Root Club and a hunting-bow Thornbow.
- `--shots=arms --hero=H`: every weapon and offhand look in one hero's hands.

---

## 2026-10-26: More gear looks, a clearer equipment screen, bigger supers

Save version still 5 (one new per-hero key, `best_mat`, defaults in `_fresh()`;
items gain an optional `look` roll, old items show their stage's base look).
`NATIVE_VERSION` unchanged.

### Added
- **Many more gear looks, all KayKit.** Tier stages can roll an alternative
  model: horned helms, war axes, tower and heraldic shields, witch hats, cowls,
  ragged robes, bandit masks, lantern staffs, skull orbs, candelabras,
  phylacteries, hooded cloaks. Each boss set has its own look per hero:
  the Barrow King's **bone** set (horned bone helm, skull shield, ribcage
  harness, bone staff), the Crypt Queen's **blackened** set (Blackguard plate,
  Necromancer robes and Deathlight staff, Shade garb) and the Thornmother's
  **bark** set (bear masks, druid cowls, the Grove Lantern). Uniques got models
  of their own (the Crown is a horned gold helm, the Cleaver a bone axe).
  New weapons are put together from several props (`GearDB.KITS`).
- **Equipment screen, rebuilt.** The bag is a list grouped by what matters:
  Upgrades (sorted by power gained), Wearing, In your bag, Needs more skill,
  and other heroes' gear folded away. Each row says what the piece is in words
  and shows one number: the power it adds. Slots show their material and a
  green arrow when the bag holds an upgrade. Tapping a row tries it on and
  slides up a card with what it replaces and every action.
- **Inspect:** any piece alone, big and turning; weapons float with their
  sparks, worn pieces are shown on the bare hero with the camera on them.
- **New tier reveal:** the first time a hero wears a higher material, light
  wheels out behind them and the material's name punches in.
- **Supers:** the Knight's Judgement brings down a crown of lightning around the
  landing; the Barbarian's Whirlwind becomes a column of fire; the Ranger's
  Hail of Arrows darkens the sky and rains arrows all around.
- **Descent:** each new depth sends a red shockwave out from the hero, embers
  burst from the ground and the camera drops back.

### Fixed
- Hats, hoods and horned helms from the skeleton characters never showed (they
  are pinned to a bone, not skinned). The Barbarian's starting Horned Cap was
  invisible because of it.
- The rarity glow and polish washed whole pieces in color; they stay on the
  edges now, so black reads black and bone reads bone.
- Tall pines on the camera's side of the arena hid fights near the south wall
  (worse when a super pushes the camera in); they fade like the near trees.

---

## 2026-10-25: Playtest fixes, gear that looks its tier, big moments

Save version is now 5 (each mode keeps its own unlocked difficulty; old saves
rebuild them from the wins they already record). `NATIVE_VERSION` unchanged.

### Fixed
- Tapping the campfire crashed the app (a scene node was not marked unique).
  A test now checks every `%Name` lookup against its scene.
- After a boss fell mid-run in the Descent or Boss Rush, the camera stayed
  pinned where the fight had been.
- Winning a difficulty opened it in every mode. Each mode now opens its own;
  the Descent opens its next tier when one of its bosses falls.
- The fallen never left the ground (thousands of bodies deep in the Descent,
  and a growing cost per frame). They now lie 20 s, at most 45 at once.
- Long Road: foes walk through the gap to reach you in another room instead of
  pressing against the wall; a shove can no longer push you through a sealed
  gate past the fight. Loot no longer lands outside the walls.

### Added
- **Gear that looks its tier.** Every material has a finish: bronze and iron
  dull and dirty, steel and mithril clean and gleaming, adamant and rune with
  light running over them, dragon (and Eldritch, black dragonhide) glowing
  from molten seams. Weapons and offhands from the fifth tier shed sparks, and
  a full set from that tier wraps the hero in rising motes. Item icons take
  their metal's color.
- **Weapons in combat:** melee swings take the weapon's metal color, and
  dropped weapons and offhands show their real model on the ground.
- **Super moment:** the camera pushes in, the screen washes in the hero's
  color and the super's name rises over the hero.
- **Legendary moment:** a bolt of light on the drop, a brief slow-down and its
  name in the feed.
- The campfire answers every tap: what it paid, or its rate per hour.

---

## 2026-10-24: Skill over stats, the Hollow Grove, Phase 11

Merged to `main`. Save version
is now 4 (old saves migrate: Veteran becomes tier 3 of 8, Nightmare tier 5).
`NATIVE_VERSION` is unchanged; no project settings changed.

### Why
Stacked gear and cards made every tier AFK-able: a level-12 Mage in material-4
gear stood still for a whole Nightmare hunt and won at full health (armor at
the 60% cap, 36 HP/s regen). The fix is to make *playing well* matter more than
numbers, and to give strong accounts a ladder that keeps going.

### Added
- **Eight difficulty tiers** (Normal, Hard, Veteran, Expert, Nightmare, Hell,
  Torment, Abyss), each about +65% foe health. Every tier lists its recommended
  power; the camp card shows yours against it.
- **Mechanics through armor:** telegraphed attacks also take a share of max
  health (0% Normal to 35% Abyss). You cannot tank them; step out or dash.
- **Grave eruptions:** the ground bursts under and around the hero every few
  seconds (telegraphed). Standing still is always punished.
- **Perfect dodge:** dash through a blow that would have hit for a riposte
  (+35% damage for 3 s) and some super.
- **Steady aim:** bow and staff heroes deal +25% after standing still a moment.
  Moving is safety; standing is damage.
- **Exposed bosses:** Gravemaw charging into a wall, the Hexer Queen blinking
  away from a hero in her face, the Thornmother after her thorn ring: each is
  dazed and takes +50% for a moment.
- **The ritual** (Horde): Grave Callers chant at a sigil. Kill them in 18 s for
  a rare, or a champion brute climbs out and the dead quicken.
- **A mini-boss** (a champion Bone Brute) at the middle champion mark; a second
  wave of champions on Nightmare and up.
- **The Long Road:** dark rooms, timed vaults, cursed altar rooms.
- **The Hollow Grove**, a third zone: an autumn forest, the Grove Cult (hooded
  cutthroats, slingers, thorn shamans that root, brawlers), and **the
  Thornmother**, a boss built around the dash (thorn rings, briar seeds that
  stay, vine sweeps, roots). Three uniques, a pet and a set.
- **Rifts:** reach depth 8 in the Descent for a key; a rift is one boss at 2.6×
  strength with a guaranteed unique.
- **Signature legendaries:** Bulwark (Knight blocks frontal blows standing still),
  Ricochet (Ranger), Pyre (Mage), Rampage (Barbarian).
- **Card banishes** (three a hunt), evolutions from three stacks instead of max,
  a fourth card choice at hero level 15, a second potion at level 20.
- **Gear sets** (Regalia, Raiment, Barkbound) and **ancient** items (+30%, Hell+).
- **Gold sinks:** reforge (reroll extra affixes), temper (raise material),
  paid talent resets after the first, weapon glows.
- **Hero mastery** (titles, gold, shards, glows), **trophy rating** per hero,
  **first win of the day**, a **7-day login calendar**, **campfire** idle gold,
  **feats** (achievements), a free six-week **season** track, boss **kill counts**
  and **dry streaks**, the **Hexling** pet, and a **companion** hero at your side.
- **Results:** Play again, XP bars, the chest shown big, the road bar filling,
  upgrades named by hero. Chests won while playing again wait in camp in order.
- **Victory:** the combat buttons step aside, a white flash, the camera on the
  fall, then the loot flies to the hero; loot labels are short and big.
- Music for the Descent, rifts, the Grove and its boss; the music muffles below
  25% health. Bigger crits, a level-up burst, a coin fountain from champions,
  the Descent darkening with depth, first-time tips for each new mechanic.

### Changed
- Normal: boss health +25%, 150 souls, first surge at 15%.
- Chest shards: 75% to the hero you played (was two random heroes).
- Armor is now a rating with diminishing returns (DB.armor_dr), and foes on
  higher tiers ignore some of it. Regen is capped at 2.5% of health a second and
  leech at 4%; higher tiers cut passive healing.
- Foes and bosses grow with the hunt's level, so a snowballing build still
  meets a real boss.
- Heroes wear their class outfit and starter gear when nothing is equipped.
- Tall props fade while they hide the fight; foreground props half-fade.
- Ranged foes fire a three-bolt spread on Expert and up; hounds hunt in pairs
  on Nightmare and up; bow and staff dashes throw back the crowd.

### Not done
- **Game Center** leaderboards and achievements: the IPA is unsigned and
  installed through AltStore, and Game Center needs an App Store provisioned
  entitlement. Feats and records are kept locally instead.

---

## 2026-10-23: UI pass, talents, new modes (Phase 9 and 10)

On branch `claude/game-codebase-review-m1uchq`, not yet on `main`. Prayer,
Slayer and Smithing were left out on request.

### Added
- **Talent trees:** three paths per hero, eight nodes each, a point per hero
  level, free reset. Hero max level is now 20 (levels past 10 add less raw
  power). Open it from the Heroes sheet.
- **Endless Descent:** the horde never ends; every minute goes a level deeper
  with a champion, every fifth depth a boss. Deepest depth is kept per hero;
  chests by depth.
- **Boss Rush:** Gravemaw and the Hexer Queen, twice, empowered on the second
  lap, with a card and a breath between fights.
- **The Wilderness:** a closing ring and five to seven rival bands (hero-built
  foes) hunting you while the dead rise. Last band standing wins.
- **Pacts** offered mid-hunt (a gain with a price), the **cursed shrine**,
  five more champion affixes (Frozen, Jailer, Mortar, Plagued, Arcane), a
  **health potion** button, and Veteran/Nightmare bosses that learn a blast ring
  and a fan of lances.
- **Renown road** on the camp screen, the **weekly omen** (a rule twist with a
  better chest) and **clue scrolls** (three goals, then a casket) in the Log.

### Changed
- Hunt HUD: health bar under the hero, XP ring on the portrait, one objective
  or boss bar, a left-edge event feed.
- Gear screen: rarity-only colors, item power and tier on every tile, a
  before/after stat strip, a fixed-height detail card, red "new" dots.
- Heroes sheet, sheet sizing, camp follow-ups (profile chip, tap the hero,
  chest on the rail).

### Fixed
- A foe-list index error when a foe's tick removed other foes (bomber blasts).

---

## 2026-10-22: A cleaner camp (UI pass, part 1)

On branch `claude/game-codebase-review-m1uchq`, not yet on `main`.

### Changed
- **Camp screen:** the three choice rows (mode, location, difficulty) are now
  one expedition card above the Play button. Tap it to open the Expedition
  sheet, where each choice says what it means (for example "Foes ×2.6 health,
  ×2.1 damage · loot ×1.6 · Gold Chest") or how to unlock it.
- **Bounties** moved from the tab bar to a button under the top bar, with a red
  badge counting rewards to claim and a "Bounties 1 / 3" line.
- Tab bar: Heroes, Gear (was Bag), Skills, Log.
- "Something new" markers are red round badges instead of green squares.

### Fixed
- On iPhones with a notch, the kill-streak counter covered the pause button
  and the clock.

### Docs
- `docs/review-ux-and-depth.md`: a review of every screen, and a proposal for
  more depth (talent trees, OSRS-style Prayer, Slayer and Smithing, Endless
  Descent and Boss Rush modes, a renown road). Tasks are Phases 9 and 10 in
  `docs/PLAN.md`.

---

## 2026-10-22: The Long Road, class powers, gear v2

Commits on `main`: `2d2254b`, `f6bd479`, `565f234`, `c5ae099`.

### Added

**The Long Road (second mode)**
- Mode picker in camp: **Horde Hunt** or **The Long Road**. The choice is
  saved (`Game.data["mode"]`, default `horde`).
- A seed builds a new dungeon every run. Rooms: 5 on Normal, 6 on Veteran,
  7 on Nightmare, then a boss hall. The boss is the zone's boss (Gravemaw in
  the Barrow, the Hexer Queen in the Sunken Crypt).
- Room kinds: ambush, horde, hunters (crossbows and staves), brutes, elite (a
  champion with an escort), shrine (hearts and a quiet breather), treasure (a
  gold chest guarded by a few foes). Kinds are weighted by depth: early rooms
  favour ambushes and hunters, later rooms favour elites, brutes and hordes.
- Gates: each divider has a gap. A glowing barrier fills the gap when you walk
  in and opens when the room is clear. The boss gate seals behind you.
- Room progress shows in the top bar ("Room 2 / 6"). A banner announces each
  room. The soul meter is replaced by room progress.
- Clearing a room drops gold, hearts and gear. Elite and brute rooms drop a
  better piece. Treasure rooms hold a chest. Shrines are placed in quiet rooms
  and the start.
- Far-behind foes despawn so the dungeon stays readable.
- The Long Road gets +1 loot tier over the zone's base.
- Bot support: `--bot --mode=trial`. Results record `mode` and
  `rooms_cleared`.

**Class powers (each one belongs to one hero, and only that hero sees it)**
- Knight: **Holy Smite** (lightning falls on the nearest foes; evolution
  **Wrath of Heaven** adds three more strikes and a stun). Knight super
  **Judgement** now calls lightning around the landing.
- Barbarian: **Earthshaker** (ground bursts outward, knockback, stun) and
  **Thrown Axes** (spinning axe projectiles). Evolution **Faultline** doubles
  the width. Barbarian's orbiting blades are axes.
- Mage: **Frost Ring** (ice ring that freezes nearby foes) and **Meteor
  Shower** (meteors on the densest crowd). Evolution **Armageddon** doubles the
  meteors. Mage super is now **Meteor Storm** (replaces Frost Nova).
- Ranger: **Arrow Storm** (a hail of arrows on the thickest cluster),
  **Explosive Arrows** (every Nth volley fires a fire arrow). Evolution
  **Deluge** drops a second wave. Ranger's super volley also rains arrows.
- Evolution cards are restricted to their hero class.

**Visual effects**
- `Fx.sky_bolt`: a lightning column that flashes on impact, with a ring and
  sparks.
- `Fx.fall`: falling meteors (with fire trails) and arrows, used by the
  meteor, arrow and super effects.
- Axe projectile (spins in flight).

**Enemies and bosses**
- **Grave Hound**: charges along a telegraphed lane and lunges at you.
- **Bone Brute**: a heavy skeleton with a telegraphed slam and shockwave. It
  does not flinch when hit.
- Foes now lead their target when they chase, and packs fan out so they
  surround instead of queueing.
- Bosses call a court of the dead: after 10 seconds of fighting, then every
  20 seconds (16 on Veteran, 12 on Nightmare). Court size grows with tier.
- Boss berserk comes earlier on harder tiers: after 150 s on Normal, 110 s on
  Veteran, 70 s on Nightmare.

**Gear v2 (class-specific gear)**
- Every piece belongs to one hero class and one material tier. Seven
  tiers: Bronze, Iron, Steel, Mithril, Adamant, Rune, Dragon (metal classes),
  Leather through Black Dragonhide (Ranger), Novice through Eldritch (Mage).
- Gear is built from KayKit parts: a Knight can wear the Mage's hat, a
  Barbarian can wear a Ranger's tunic. Parts are dyed with the material colour
  (`dye` instance uniform in `char.gdshader`).
- A hero with nothing on is a plain man in a tunic with a starter weapon.
- Weapons change shape with the tier (e.g. Knight: Shortsword, Longsword,
  Greatsword).
- Skill requirements gate each tier: Defence for armour and Attack for melee
  weapons (Knight and Barbarian), Magic for mage gear, Ranged for ranger
  gear.
- Drops favour the hero you're playing (65%). Harder content drops better
  material. Uniques have their own class and colour.
- The equipment screen shows a "Needs Magic 20" line on pieces you can't wear
  yet and a lock icon on the tile.
- Save version 3. Old v2 items migrate to the hero wearing them, or to a class
  by item id. Old uniques become class gear.

**Equipment screen (rebuilt)**
- Big 3D hero in the middle. Drag to turn.
- Five slots either side. Tap a slot or a bag piece to try it on: the model
  changes immediately and Equip makes it stick.
- Bag shows this hero's gear first. An "Others" tab shows other heroes' gear.
- Equip best, sell junk and the item detail strip are kept.

**Camp and menus**
- Mode picker row above the zone picker.
- Hunt button text follows the mode ("Take the Long Road").
- Menu sheets keep their content clear of the home bar.

**Capture and tests**
- `--notch` capture flag: simulates iPhone inset padding for screenshots.
- Capture shots: `parts`, `weapons`, `dress` (class lineup), `powers`
  (each hero's power cards on screen).
- `--test` adds gear checks (parts exist, class lock, skill lock, migration,
  material rolls), mode save and validation, tier scaling, and card icons.
- CI and `check.sh` run the Long Road autopilot for Knight and Mage.

### Changed

- Difficulty tiers (scaling is applied to enemy health, damage, speed and
  spawn pressure):
  - Normal: unchanged (1.0 everywhere).
  - Veteran: health 2.6x (was 2.1x), damage 2.1x (was 1.6x), speed 1.08x,
    pressure 1.25x.
  - Nightmare: health 6.5x (was 4.2x), damage 4.6x (was 2.4x), speed 1.17x,
    pressure 1.5x.
- Hunts spawn more foes on harder tiers. Packs sometimes appear ahead of a
  running hero (Veteran and above, or past 35% progress).
- Level-up cards: classes only see their own cards. Storm Call and Fire Nova
  are Mage-only. Orbiting Blades and Thorns are Melee-only. Evolutions obey the
  same rule.
- Starting uniques now grant different cards:
  - Crown of the Barrow King: starts with Holy Smite (was Storm Call).
  - Gown of Thorns: starts with Frost Ring (was Thorns).
- Knight super description updated (Judgement calls lightning).
- Save version 2 → 3 (see Gear v2).
- Bot: waypoint navigation on the Long Road; ignores pickups behind walls; no
  pull toward the arena centre on the Long Road.

### Fixed

- Equipment screen cut off at the top on iPhone. The safe area was read from a
  node not yet in the tree. `Ui.apply_safe_area` now reads the scene root.
- Gear did not show on the model. Parts now swap and dye per item.
- Level-up cards loading slowly the first time. The cards are now drawn once
  behind the start-of-hunt curtain, so the first real level-up doesn't compile
  shaders. Mitigated. Needs a check on device.
- Long Road autopilot stalls: it walked into walls to reach pickups, and it
  parked at the arena edge. Both fixed (`565f234`, `c5ae099`).
- Gate barrier looked like a solid wall. Now a soft gradient at 55%.
- Heavy foes (Brutes) no longer flinch on each hit.

### Removed

- `_legacy/` (the previous project, about 648 MB). The four audio build
  scripts moved to `tools/audio/`. Credits point there now.
- Frost Nova super (replaced by Meteor Storm).

---

## 2.0.0: Barrowfall rebuild and phases 1–6

Earlier entries, in order of shipping. Commit hashes are on `main`.

### Phase 6: housekeeping
- `--test` rule checks (`fce9d9d`).
- Render budget warnings: a shot over 700 draw calls or 400k triangles
  prints `BUDGET WARNING`.
- Ranger autopilot tuned; Sunken Crypt bot added to CI.
- `_legacy/` removed (`421b3c5`).

### Phase 5: second zone
- Zones as data. Barrow and Sunken Crypt share the hunt code (`4087ca3`).
- **The Sunken Crypt**: an indoor dungeon built from KayKit dungeon tiles,
  with a ritual floor and torchlit halls. Unlocks after clearing Veteran in the
  Barrow.
- **The Hexer Queen**: the Crypt's boss. Orb rings, summoning circles, a
  blink, and a cursed lane that slows you.
- Zone picker in camp.
- Crypt-only uniques and drops.

### Phase 4: progression
- Real hero portraits rendered from the 3D models, in the roster and the HUD
  medal (`47543e7`).
- Daily bounties: three per day from a pool of seven. Bounties are seeded from
  the date, so every player gets the same set that day. Claim from the nav
  button in camp.
- Results screen counts up gold, kills and skill XP. Tap to skip.
- Level-up reroll: one per hunt (two on Nightmare).

### Phase 3: depth
- **Grave Robber**: a thief who flees with loot. Catch him before he escapes.
- **Shrines**: three shrines, each giving a timed buff.
- **Card evolutions**: Bladestorm, Tempest, Inferno Heart, Rain of Arrows,
  Judgement Day.
- Visible elite affixes: Warded bubble, Molten fire patches, Swift dust trail.
- New enemies: Pumpkin Bomber (runs in and detonates, hurting other foes),
  Grave Caller (summons minions).
- Surges: "The graves open!" spawns a ring of foes, then a breather
  (`0024550`).

### Phase 2: feel
- Haptics (Vibration toggle in settings).
- Shader warm-up on first use.
- Target ring and stagger on light hits.
- Merged damage numbers.
- Massacre streaks.
- Audio buses (Music and SFX) and ducking when menus open.
- Boss berserk after a long fight (`900ec0c`).

### Gear (G.1–G.4)
- Five gear slots: weapon, helm, chest, legs, trinket.
- Visible gear on heroes.
- Equipment screen with upgrade markers (`d2a99ae`).

### Art
- A.1: KayKit grit pass. Smaller heads, darker palette, dirt in the character
  shader (`94856ef`).
- Art research recorded in [docs/art-options.md](docs/art-options.md).

### Controls and layout
- Action buttons move to the thumb corner. "Buttons" setting: Right or Left.
- Banners moved under the HUD (`1616732`).

### Phase 1: camera
- 1.1: camera rig with pitch, distance, anchor and lookahead (`a5714e3`).
- 1.2: dynamic framing for boss, crowds and victory (`59d4818`).
- 1.3: props fade when they hide the hero or the boss (`aaa66e3`).
- 1.4: camera distance setting: Close, Standard, Wide (`8c05772`).
- 1.5: hidden camera tuning panel: tap the info line five times in pause
  (`67b554d`).
- 1.6: camp camera drift and push-in on hero switch (`599c345`).

### Initial rebuild
- Barrowfall rebuilt on KayKit art with the new hunt loop, camp, skills, collection
  log and save (`557388c`).
- Screenshots, compile check mode, CI checks (`40f7cab`).
- Next-work plan, CLAUDE.md and dev scripts (`8806999`).
