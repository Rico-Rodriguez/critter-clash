# Wilderness zones (scripts/zone_builder.gd, class `ZoneBuilder`)

The Barrow Lands are four depth tiers, not one arena. The Fringe, the
Wilds, the Deep and the Abyss are each a large explorable zone, and the
builder lays them out from the data in `WorldData` (scripts/world_data.gd).

A zone is a place to walk through, not a field to fight in. It is many
times the size of the shipped hunt arena, it has a gate at the south and a
gate at the north, and the hero walks from one to the other.

## The zones

| tier | name | cells | size (sim px) | ground | monsters | elites | resources |
| --- | --- | --- | --- | --- | --- | --- | --- |
| fringe | The Fringe | 4 x 2 | 4480 x 2560 | 11.5 M | 1-10 | 5% | 3 |
| wilds | The Wilds | 4 x 3 | 4480 x 3840 | 17.2 M | 11-25 | 15% | 4 |
| deep | The Deep | 5 x 3 | 5600 x 3840 | 21.5 M | 26-45 | 30% | 5 |
| abyss | The Abyss | 5 x 4 | 5600 x 5120 | 28.7 M | 46-70 | 30% | 6 |

A cell is the biome's own cell (`WorldData.BIOME["cell_size"]`, 1120 x
1280), so a zone is always a whole number of the world's grid squares. The
shipped hunt arena is 1120 x 2236, so even the Fringe is four times its
ground and the Abyss is eleven times.

The four zones stack north to south in tier order. `ZoneBuilder.world_origin`
says where a tier's zone stands in that stack and `ZoneBuilder.world_size`
how big the whole world is. The Fringe's north gate is the Wilds' south
gate, and the Abyss' north gate is the lair.

## What a zone holds

A zone is a `WildernessZone` (scripts/wilderness_zone.gd), which is a
`HuntMap`: the hunt simulation already knows how to walk one. The zone adds
what a depth tier knows that a biome map does not.

| field | what it is |
| --- | --- |
| `tier_id`, `tier_name`, `tier_depth` | the tier the zone is |
| `loot_tier`, `recommended`, `danger` | the tier's own numbers |
| `entry`, `exit` | the south gate and the north gate |
| `nodes` | the open areas: the gates, the clearings, the pockets |
| `segs` | the corridors that join them |
| `camps` | the monster packs, with the skin and the level they hold |
| `patrols` | the groups that drift along the trail |
| `spawns` | every monster spawn point, camps and patrols together |
| `elites` | the elite packs, as markers |
| `gathering` | the resource nodes the tier names |
| `landmarks` | the standing things that block a path |
| `props` | the soft scenery that fills the ground |

### The ground

Two gates, a chain of clearings between them and a few pockets off the
side. The chain of clearings is the route north: each one is a wide open
space joined to the next by a corridor that bends once, so the trail winds
instead of running straight. The pockets are the quiet clearings off the
side of the chain, and they are where the elites and the chests sit.

The zone's own pathing grid is baked from the same ground the hunt uses
(`HuntMap.depth`, `push_inside`, `flow`), so the hero can walk every part
of the zone: the builder checks that every pack, every resource node and
the north gate can be reached from the south gate, and it moves or drops
whatever cannot be.

### The monsters

Spawn points are scaled by the tier's own data:

- **How many** - one pack per `PACK_AREA` (1.2 M) of ground, so the big
  zones hold more of them.
- **How big** - `BASE_PACK` (4) times the tier's `danger.pack_size_mul`:
  three in the Fringe, six in the Abyss.
- **How tough** - a level inside the tier's own range, and it climbs as
  the walk goes north: the packs near the south gate are at the bottom of
  the tier's range and the packs near the north gate at the top of it.
- **Which** - four of the biome's critters to a tier, in tier order
  (`ZoneBuilder.tier_skins`): the barrow beasts in the Fringe, the blight
  ones in the Wilds, the rime ones in the Deep, the ash ones in the Abyss.
- **How many patrol** - the tier's `danger.patrol_density` sets how many
  groups drift along the trail.

### The elites

`elite_chance` is the tier's share of packs that turn elite, and the
builder rolls it. The deep tiers also keep a guaranteed few (one more per
tier of depth), so a zone never rolls no elite at all. The elite packs are
listed apart in `elites`, as markers the map can draw.

### The resources

The tier names its own resource nodes (`WorldData.gathering_nodes`), and the
builder places one per open area, easiest first: the node nearest the
south gate is the first the tier lists, and the better nodes sit further
north.

The world names its nodes in its own words ("copper_vein", "ash_log",
"minnow_pool"). `ZoneBuilder.resolve_gathering` turns a name into a
gathering node:

1. A name the gathering catalog knows is used as it is.
2. A name the catalog does not know falls back to the tier's own node for
   the skill the name implies - a vein is mining, a log is woodcutting, a
   pool is fishing.
3. A name that implies no skill (a nest, a bloom) stays a marker:
   something to find, not something to work.

### The scenery

Each tier wears its own kit (`ZoneBuilder.PROP_KITS`): oaks and barrow
mounds in the Fringe, blight trees and grave markers in the Wilds, dead
trees and standing stones in the Deep, scorched trees and ash pillars in
the Abyss. The scenery stands in clumps in the forest between the
clearings. A kind with a width (a mound, a boulder, a standing stone)
also stands in `landmarks` and blocks a path; the rest are soft, and the
ground under them is still walkable.

## The seed

Every zone is built from a seed, so one seed always builds the same zone.
`ZoneBuilder.build(tier_id, seed)` builds one zone and
`ZoneBuilder.build_all(seed)` builds the four of them, south to north.

## Self-test

```
godot --headless --path . -s res://tools/zone_check.gd
```

It prints `ZONE CHECK PASSED` and exits 0 when every tier builds a zone
that is far bigger than the arena, that carries the tier's own monsters,
elites and resources, that the hero can walk from the south gate to the
north gate, and that one seed always builds the same zone.

## What is not here yet

The builder makes the place. It does not open it: the run that plays the
zone, the fog that hides it, the monsters that walk out of it and the
loot that pays for it come later.
