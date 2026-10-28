# Barrowfall — UX review and depth proposal (2026-10-22)

A pass over every screen at iPhone size (720×1560 with `--notch`), plus a read
of the systems behind them. Part 1 is what is wrong with the screens and what
to do about each. Part 2 is how to make the game less repetitive: what to add,
in what order, and why. The tasks are in `docs/PLAN-history.md`, Phases 9 and 10.

The yardstick throughout is the four games the README names:

- **Supercell (Brawl Stars, Clash Royale):** the home screen has one job, "play".
  Everything else is one tap away but not on the main screen. One hero, one
  Play button, one mode card, a trophy road, and red badges that mean "do this".
- **Hunt Royale:** short runs, a clear HP bar on your hero, three numbers on
  screen, nothing in the middle.
- **Diablo:** items read at a glance by color (rarity) and by a single number
  (item power, plus "▲ 42" on an upgrade). Builds come from skill choices, not
  from stats.
- **Old School RuneScape:** every skill is a system with its own activity, not a
  number that goes up on its own.

---

## Part 1 — The screens

### 1.1 Camp (home) — fixed in 9.1

| Before | After | Expedition sheet |
| --- | --- | --- |
| ![](screens/review/camp-before.jpg) | ![](screens/review/camp-after.jpg) | ![](screens/review/expedition.jpg) |

**Before:** between the hero and the Play button there were three captions
(GAME MODE, LOCATION, DIFFICULTY), seven segmented buttons, a mode blurb and an
orange "The Sunken Crypt opens: …" line that read like an error. That is
twelve things to parse before "play", and they are choices a player changes
maybe once a week. The bottom nav had five tabs that opened two different kinds
of screen (a half sheet, or the full-screen equipment takeover), and its
"something new" markers were green squares that looked like placeholders.

**After (shipped in this branch):**

- One **expedition card** above Play: mode icon, `HORDE HUNT`, `The Barrow`,
  and the difficulty in its tier color. Tapping it opens an **Expedition**
  sheet with one card per choice, each saying what it means ("Foes ×2.6
  health, ×2.1 damage · loot ×1.6 · Gold Chest") or, when locked, how to open it
  ("Clear Veteran in the Barrow"). The unlock hint lives on the locked card
  instead of on the home screen.
- **Bounties** left the tab bar for a round button under the top bar with a
  red count badge and a running "Bounties 1 / 3" — dailies are the reason to
  open the game, so they get a spot on the home screen, like Brawl Stars'
  quests button.
- The tab bar is four tabs (Heroes, Gear, Skills, Log). "Bag" is now "Gear"
  (it opens the equipment screen; nobody looks for armor under "Bag").
- Red round **badges** (theme variation `Badge`) replace the green squares.
- The "Locked" line under the hero only shows when the hero is locked.

**Still open:** the hero arrows are the only way to switch hero (a tap on the
hero, or a swipe, should open the roster); the top-left "Combat 35" means
nothing to a new player (make it a profile chip: portrait + name + combat
level, opening Skills and Log); a pending chest still pushes the layout (make
it a chest slot on the right rail, Clash Royale style).

### 1.2 Hunt HUD

![](screens/review/hunt-before.jpg)

What the shot shows: the top quarter of the screen is
four stacked layers — portrait, HP bar, level chip + XP bar + gold, pause +
clock, then a centered SOULS caption and bar, then the kill streak, the
Massacre banner and its "+5 souls +3 gold" line. With the camera leading the
hero upward, that top quarter is where the enemies come from.

Problems, worst first:

1. **Bug (fixed in this branch):** under a notch the "12 KILLS" streak label
   sat on top of the pause button and the clock. It and the shrine-buff label
   used fixed pixel offsets outside the safe area. They now live in a row inside
   the safe-area container.
2. **HP is far from the hero.** Every game in the reference list puts HP over
   the hero's head; here the eye has to leave the fight to check it. Put a
   small world-space HP bar under the hero (with the run level as a chip on
   it) and drop the big top-left bar.
3. **Three look-alike bars.** HP (red), XP (teal) and Souls (light blue) are the
   same shape; XP and Souls are nearly the same color. Souls is the objective;
   XP is "next card". Make XP a ring around the portrait (or a thin line under
   the objective bar) so there is exactly one bar at the top: the objective.
4. **Text events stack in the middle top.** Streak, Massacre, toasts, champion
   names and shrine buffs all appear in the same band. Give them one lane: a
   short feed on the left edge (icon + a few words, fades after 2 s). Keep
   center banners for the four big beats only: champion rises, boss wakes,
   room clear, victory.
5. **Gold is a 20-px number** after the XP bar. Either make it a proper chip by
   the clock or drop it during the hunt (results already count it up).
6. The joystick ghost is always drawn. Show it for the first hunts only (the
   tutorial flag already exists) and when the thumb is down.

Target layout (portrait, top to bottom): a slim top strip `[pause] [objective
bar with icon and "12 / 110" — or the boss bar] [clock]`; a left-edge event
feed; the fight; Super and Dash bottom-right as today. Nothing else.

### 1.3 Equipment (Gear)

| Bag | Item selected |
| --- | --- |
| ![](screens/review/equip.jpg) | ![](screens/review/equip-detail.jpg) |

What the shots show:

1. **Two color systems on every tile.** The icon is tinted by material
   (Mithril blue, Adamant green, Steel white…) and the frame by rarity (Magic
   blue, Rare yellow). A Mithril sword in a yellow frame and an Adamant chest in
   a blue frame side by side cannot be read. Diablo's rule: **color means
   rarity, and only rarity.** Keep the frame and a soft tile background in the
   rarity color; draw icons in one neutral tone; show the material as a short
   tier tag ("T4 Mithril", or a pip row) under the icon.
2. **No number to compare.** Tiles say "Mithril" and nothing else. Show the
   item power on every tile, and on upgrades a green "▲ 42" (the score gain),
   which also replaces today's 10-px ▲ glyph.
3. **"New" markers everywhere.** Every tile from a fresh hunt carries a green
   square, which is the same green as Adamant. Use one small red dot (the camp's
   `Badge`) and clear it on first view of that slot filter.
4. **Slot naming disagrees with itself.** The data slot is `trinket`, the label
   says "Offhand", the paper-doll shows a shield, the filter row shows a
   pendant. Pick one (Offhand + shield, since the Knight's shield is what drops)
   and use it in `DB.SLOT_NAME`, `DB.SLOT_ICON`, the filter row and the Heroes
   sheet.
5. **No stat panel.** You can't see the hero's damage, health and armor here,
   or how an item changes them. Add a stat strip under the hero name (Health,
   Damage, Armor, Attack speed) that previews the change while an item is
   selected: `Damage 33 → 41 ▲`.
6. **The detail panel shoves the screen.** Selecting an item squeezes the 3D
   hero and overlaps the "Drag to turn" hint with the weapon. Show details in a
   bottom sheet over the bag instead, so the hero never moves.
7. "Attack 20" under the item name reads as a stat. It is a requirement: write
   "Requires Attack 20", red when unmet.
8. "Others 0" — hide the tab when there are none; label it "Other heroes".
9. The bag doesn't show its size (`INVENTORY_CAP` is 48). Show "14 / 48" next
   to the filters, red when nearly full.

The screen is also the only big UI built entirely in code (786 lines in
`equipment.gd`). Moving the layout into `equipment.tscn` (as `CLAUDE.md` asks)
makes items 1–9 cheaper and lets the theme style it.

### 1.4 Heroes sheet

- The shard bar reads "9 / 6 shards" — over 100% and overlapping the bar. When
  the upgrade is ready, say "Ready" and fill the bar gold.
- The gear row (five empty circles + an "Equipment" button) duplicates the Gear
  tab. Replace it with the hero's item power and a one-line "Gear: 0 / 5
  slots" link.
- The roster tiles show level only; add the power number and an upgrade badge on
  the tile whose hero can level up.

### 1.5 Sheets in general

Bounties, Skills and Settings sheets open at 70–86% height with half of it
empty. Size sheets to their content (cap at 86%). The Collection Log's
"Record" section is cut off at the bottom with no hint to scroll.

### 1.6 Chest, level-up, results

![](screens/review/levelup.jpg)

- **Level-up** reads well: three big cards in thumb reach, rarity on top, pips
  for stacks. What it lacks is the build. Show the cards you already hold as a
  row of small icons above the offer, and on a card that completes an
  evolution pair say so ("+ Orbiting Blades → Bladestorm"). Evolutions are the
  deepest thing in a run and today the player has to remember the pairs.
  "Reroll (1)" is dim ghost text; make it a real button with the count.
- **Chest:** the reveal is good; the "Tap to open" line sits in a dark band at
  the bottom while the chest is on the right edge — center the chest and the
  prompt.

---

## Part 2 — Depth: making it less repetitive

### Why it repeats today

A run is: auto-attack, move, dash, super, pick a card at each level-up, kill
the boss, open a chest. Between runs the choices are: which hero, "Upgrade"
(one button, +9%), "Equip best", and which of two modes. Skills level on their
own. So after a few hours every run of the same hero is the same build, and
the meta never asks you to decide anything. The fix is **decisions**, at three
time scales:

| Time scale | Today | Add |
| --- | --- | --- |
| Inside a run (seconds) | cards, dash, super | risk choices (cursed shrines, omens), more elite affixes |
| Between runs (minutes) | hero, mode, tier | **talent trees**, **prayer loadout**, a run goal (bounty / slayer task) |
| Across weeks | collection log, 99s | **renown road**, endless depth record, weekly mutator, crafting |

### 2.1 Talent trees (the "skill tree") — recommended first

Each hero gets three paths of about 12 nodes each; a point per hero level (raise
`HERO_MAX_LEVEL` from 10 to 30 so points keep coming). Free respec. Nodes are
of three kinds:

- **Minor:** +4% damage, +6% health, +10% dash recharge.
- **Notable (changes a rule):** Knight *Consecrated Ground* — Judgement leaves a
  holy circle that burns for 4 s. Ranger *Hunter's Mark* — the first arrow on a
  champion marks it, marked foes take +25%. Mage *Glass Cannon* — +30% damage,
  −20% health. Barbarian *Bloodlust* — each kill within 1 s of the last adds
  5% attack speed, stacking to 10.
- **Keystone (one per path, end of path):** card-pool changes — "Crusader: Holy
  Smite is always in your first offer and evolves without Grave Strength".

Paths per hero (the class powers already in the game seed them):

| Hero | Path A | Path B | Path C |
| --- | --- | --- | --- |
| Knight | Bulwark (ward, thorns, armor) | Crusader (Smite, lightning, Judgement) | Vanguard (dash, charge, sword waves) |
| Ranger | Deadeye (crit, pierce, marks) | Stormcaller (Arrow Storm, Deluge) | Trapper (explosive arrows, slows, kiting speed) |
| Mage | Pyromancer (fireball, nova, meteors) | Frostweaver (Frost Ring, freezes, shatter) | Hexbinder (leech, curses, summons) |
| Barbarian | Berserker (attack speed, low-HP rage) | Earthbreaker (Earthshaker, Faultline) | Axethrower (Thrown Axes, whirlwind) |

Why first: it turns "Upgrade" into a choice, gives every hero three builds, and
leans on the card system that already exists (keystones bend card weights and
evolution rules, so little new combat code). Data lives in `db.gd`
(`TALENTS`), effects go through `Game.hero_stats()` and a flag set the hero
reads, the tree is one new sheet.

### 2.2 Make the OSRS skills into systems

Today the six skills are passive bonuses. OSRS works because each skill is an
activity. Three new skills, each a reason to come back to camp:

- **Prayer** (trained by burying the bones skeletons already drop). Prayer
  level unlocks prayers; you take one into a hunt, two from level 40, from an
  OSRS-named list: *Rock Skin* (+armor), *Superhuman Strength* (+melee damage),
  *Eagle Eye*, *Mystic Might*, *Protect from Missiles* (−40% from bolts),
  *Smite* (hits drain the boss's summons), *Redemption* (heal at 10% HP once).
  A small, very OSRS loadout decision before every hunt.
- **Smithing** (the gold and junk sink). Salvage gear into bars of its metal;
  smith bars into a piece of a chosen slot and tier, or reforge one affix on a
  rare (Diablo's enchant). Smithing level gates the tiers, like Defence gates
  wearing them. "Sell junk" becomes "Smelt junk".
- **Slayer** (variety by assignment). A Slayer Master at camp hands out a task:
  "Kill 120 Grave Hounds", "Slay 4 champions in the Crypt". Slayer points buy
  unlocks: superior variants of a foe (a rare tougher spawn with its own drop),
  an extra card reroll, a task skip. It points players at content they would
  skip, which is exactly what repetition needs.

### 2.3 New modes, cheapest first

1. **Endless Descent** (Diablo's Greater Rift). The horde never stops; every
   60 s the depth goes up one tier step and a champion spawns; every 5 depths
   a boss. Score = depth reached, kept as a personal best per hero. Rewards
   scale with depth. Reuses the Horde Hunt almost as is; the best "one more
   run" mode for the least code.
2. **Boss Rush / The Gauntlet.** Gravemaw, then the Hexer Queen, then both
   empowered, with a card pick between fights and no soul phase. Best-time per
   hero. Needs a boss sequencer in `hunt.gd`, nothing new in art.
3. **Weekly Omen** (mutator). One rule twist for a week — "Bombers only",
   "No dash, double super charge", "Every foe is Swift", "Champions explode" —
   with a better chest. A banner on the expedition card.
4. **Treasure Trails** (OSRS clue scrolls). A rare drop that, when read in
   camp, gives a step: "Slay a Swift champion in the Barrow on Veteran", then
   "Win the Long Road without dashing"… ending in a casket with cosmetic gear
   looks and gold. Stacks a goal on top of the existing modes.
5. **The Wilderness** (Hunt Royale style; biggest). A large shrinking map with
   5–7 bot heroes (`HuntBot` is the seed) racing for souls and one boss.
   Placement rewards. Only once 1–4 feel good.

### 2.4 Inside the run

- **Risk choices.** A *Cursed Shrine* among the three: take it and a champion
  pack spawns; survive 20 s for a legendary card. In the Horde Hunt at 50%
  souls, offer an **omen**: two cards, one curse each ("+40% damage, foes +20%
  speed"). Choices with a cost are what make runs feel different.
- **More elite affixes** (Diablo's best variety per line of code): *Frozen*
  (ice orbs that burst), *Jailer* (roots you for 1 s), *Plagued* (poison pools),
  *Arcane* (a rotating beam), *Mortar*. Two affixes on Veteran champions, three
  on Nightmare.
- **A potion.** One health potion with a long cooldown, refilled by globes from
  elites. A third, small button; a real decision under pressure.
- **Boss phases by tier.** Each boss learns one new pattern on Veteran and
  another on Nightmare, so harder tiers are not just bigger numbers.

### 2.5 The long goal: a renown road

Supercell's trophy road, as a single track on the home screen: every hunt
earns renown (more for higher tiers and deeper Descents); the road hands out,
in order, the things that are today unlocked by scattered rules — the Crypt,
Veteran, the Long Road, the Barbarian, talent points, prayer slots, the
Descent, chest upgrades. One bar on the camp screen that always says what the
next reward is.

### Suggested order

1. Phase 9 (UI) — 9.1 is done; 9.2–9.6 next. Every new system needs a clean
   home screen, a readable HUD and a gear screen that can show item power.
2. Talent trees (10.1).
3. Endless Descent (10.2) and Boss Rush (10.3) — cheap modes on the same engine.
4. Prayer (10.4), then Slayer (10.5), then Smithing (10.6).
5. Renown road (10.7), Weekly Omen (10.8), Treasure Trails (10.9).
6. The Wilderness (10.10), when the rest feels good.
