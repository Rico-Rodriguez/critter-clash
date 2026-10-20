# Stash contract (scripts/stash_screen.gd, `SaveGame.data["stash"]`)

The **stash** is the Hub's store: the materials the player has parked in the
Hub, kept out of the bag. The bag is the sell pile, the stash is the keep
pile, and that is the whole difference between them.

## Why it exists

The bag (the Materials tab of the Skills screen) has two exits: sell a
stack, or sell the whole bag in one go. A pile of materials the player wants
to keep has no safe place in the bag, because "sell the whole bag" cannot
tell a keeper from a pile of junk. The stash is that place: a stack parked
there is out of reach of the sell button, and it only leaves when the player
takes it back into the bag.

The stash never sells. Nothing in it can be turned into coins by the stash
screen; the bag is still the only pile that pays.

## The save

`SaveGame.data["stash"]` maps a material id to how many of it is parked:

```
"stash": { "willow_logs": 4, "meadow_fiber": 2 }
```

The ids are the same material ids the bag uses (`SaveGame.data["materials"]`,
priced by `MaterialDB`), so a stack moves between the two piles without
renaming and without a second price list.

- Save version 6: the stash is a new key. An old save starts with an empty
  stash, and the reconciliation drops any stack that is not a positive count.
- Every change is written to the save file at once (`SaveGame._write`), so a
  parked stack survives a crash the same way a sold one does.

## The API

| call | what it does |
| --- | --- |
| `stash_count(id)` | How many of a material the stash holds. |
| `stash_total()` | How many items the stash holds, every kind together. |
| `stash_value()` | What the whole stash is worth in coins. |
| `deposit_stash(id, amount)` | Parks a stack from the bag. A negative amount parks the whole stack. Returns how many moved. |
| `withdraw_stash(id, amount)` | Takes a stack back into the bag. A negative amount takes the whole stack. Returns how many moved. |
| `deposit_all_stash()` | Parks the whole bag in one write. Returns how many items moved. |
| `withdraw_all_stash()` | Takes the whole stash into the bag in one write. Returns how many items moved. |

Nothing moves when the pile does not hold the material, and a move of zero
leaves the save alone.

## The screen

The Stash screen is its own page, reached from the **Stash** tile on the
Hub (Home) and from the **STASH** button under the bag on the Skills
screen. It has two tabs:

- **Stash** - what is parked in the Hub. A row takes the stack back into the
  bag.
- **Bag** - what the player is carrying. A row parks the stack in the stash.

The list is split the way the bag is split: the boss spoils, then the
gathered resources, then anything else the save holds that nobody has priced
yet (a stack nobody has priced is still shown, never hidden). The bulk
action under the tab bar takes the lot or parks the lot, in one write.

Neither direction asks first, because both are ways back: a parked stack can
always be taken out again, and nothing is ever sold by either.

The Hub tile carries a dot while the stash holds something, the same way the
Skills tile carries one while the bag holds something worth selling.

## Still to come

- The stash holds materials only. Gear, cards and coins live where they
  live now.
- Nothing buys from the stash and nothing crafts with it yet. It is a store,
  not a workshop.
- The stash is not a second bag: it has no capacity, and it does not fill up.
