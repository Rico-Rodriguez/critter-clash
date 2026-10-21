# Open issues

Each entry says what is wrong, where it is, and the next step. Nothing here is
finished work.

- 2026-10-21 — **The town has no sound of its own.** It plays the home music, but a place with a forge, a market and four people talking needs a bed of ambient noise under it. The project has no town ambience recorded, so this needs either a new sound bed or a set of the existing effects looped quietly. Next step: an ambience bed (wind, fire, a bell), and a music track of its own.
- 2026-10-21 — **The tasks do not chain.** The board gives four tasks and each is judged on its own, so "The road out" hands you nothing. Next step: the first thread — clear the Fringe, and the board points you at the Wilds, then the Deep, then the Abyss, with the road opening as you go.
- 2026-10-21 — **The far side of the river is wood, not country.** The treeline closes the horizon, but there is nothing out there yet. Next step: the south country beyond the Fringe, so the town has ground on both sides of it worth walking into.
- 2026-10-21 — **The whole-world hunt is the old flow and nothing plays it now.** The daily, the seeded gear runs and the bot fights all moved onto the zone flow, and the town is the only way into a hunt. What is left of the world map is its own data and the map checks. Next step: retire `HuntMap.world` once the map checks are folded into the zone checks, or keep it as the daily's ground on purpose and say so in the docs.
- 2026-10-21 — **The bot now clears the fringe and the wilds** (a win at 129 s and 147 s, 35 and 64 kills), so the old meadow failures are gone with the old flow. What is left: the bot's steering still gets caught on thin ground now and then, and the deeper zones are not walked by the bot at all yet. Next step: a bot run in the deep and the abyss, so the whole ladder is proved.

- 2026-10-21 — The town has no quest board and no plot: the business is the stalls, the forge, the slayer master, the road, the stash and the skills. Next step: a quest board in the town and a first thread that sends the hero out to a depth and brings something back.
- 2026-10-21 — The south country beyond the Fringe is not built: the south barrier always leads back to the shallow ground. Next step: a south line of depths, so the town has ground on both sides of it that is worth walking into.
- 2026-10-21 — The README was rewritten to the new game: the camp, the four depths, the zone walks, the six classes and the tappable gates. What is left to describe is the trophy road's exact prices and the collection log's numbers, which still speak of biomes — worth a pass when the road is next touched.
- 2026-10-21 — The camp shows the hero by the fire, but the counter still names him in words; a portrait or a small 3D echo of the hero in the YOUR HERO row would make the choice read at a glance. Next step: a small hero portrait in the row (the sprite bank has no class art yet).
- 2026-10-21 — A gate's challenge is stepped by tapping a small line under the gate, which is easy to miss. Next step: a clearer affordance once the camp flow is settled.
- 2026-10-21 — Scratch files are cleaned up: `tools/_fix_intro.py` (already applied), `tools/_test_intro.gd` and `tools/_test_intro.ps1` (a headless probe that hung) are gone; the tier entry patch was applied and `tools/pending_tier_fix.py` is no longer needed
