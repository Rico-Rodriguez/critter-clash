# The shape of the game

A portrait hero-run in Godot 4.7.2, built like a Diablo: you choose a
character, you wake up in a town, and the town is the only safe place in
the world. Everything else is a hunt.

## The flow

1. **Choose your character.** The game opens on the character select: the
   six classes, the one you pick standing on its plinth in 3D wearing what
   you equipped it with, and an ENTER THE TOWN button. Picking here sets
   the hero the whole game uses. This is the front door now, not the town.
2. **You are in town.** Barrow Haven is a place in the middle of the
   Barrow Lands: a plaza with a fire and a well, the two stalls, the critters
   who keep the place, and the town wall with its two gates. Nothing fights
   here. The counter over the town holds the business of the town.
3. **You leave past a barrier.** The town wall has a gate north and a gate
   south. The north gate leads to the deeper grounds; the south gate leads
   to the shallow one. The north barrier opens when the shallow ground is
   cleared, and it always leads to the first depth that is not cleared yet.
4. **You hunt.** A hunt is a walk through a depth zone, from its south gate
   to its far gate, where the guardian of that depth waits. Clear it and
   the next gate opens.

So the map is a town with ground on both sides of it:

```
            the Abyss      (the lair)
               |
            the Deep
               |
            the Wilds
               |
  the Fringe - BARROW HAVEN - (further south, not built)
```

The town sits in the middle of that line, which is the point: the shallow
ground and the deep ground are both a walk from the fire.

## What the town is for

The town is where the business happens: the two stalls (the General Store
and the Material Buyer), the stash, the forge, the slayer master, the
trophy road, the collection log, the skills. A hunter comes back to town
with a chest, spends the money, banks the gear, and walks out again.

## The screens

| screen | what it is |
| --- | --- |
| `char_select` | the character select, the front door — `scripts/char_select.gd` |
| `hub` | the town: the 3D place and the counter over it — `scripts/app.gd` (`HubScreen`), `scripts/hub_scene.gd`, `scripts/hub_view.gd` |
| `heroes` | the heroes tab: the same roster, with the gear sockets — `scripts/hero_screen.gd` |
| `run` | the hunt — `scripts/run_screen.gd` |

The roster tile is shared: `scripts/hero_tile.gd` builds it for both the
character select and the Heroes tab, so a hero reads the same in both.

## What is built, and what is not

Built: the character select, the town (3D, with the wall, the two gates,
the well and the people), the depth zones, the hunts, the business screens.

Not built yet: the town as a walkable place (it is a fixed camera with a
counter over it, the way the camp was), a quest board, the south country
beyond the Fringe, and the Diablo-style "the town is a maze" layout. The
next step is in `.memory/topics/open-issues.md`.
