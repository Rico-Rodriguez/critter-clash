# Gathering contract (scripts/gathering_db.gd, class `GatheringDB`)

Gathering is the second skill family: **Woodcutting, Fishing and Mining**. It
is **account-wide**, unlike the six combat skills, which belong to a hero and
live in `GearDB`. One account's Woodcutting level is the same for every hero.

Phase 1 is data, catalog and sim hooks only. There is no gathering UI yet: the
skills screen keeps its "arrive soon" placeholder.

## Skills
- `Catalog.SKILLS` is the catalog: `{"id", "name"}` per skill, in display
  order. The ids are `woodcutting`, `fishing`, `mining`.
- The level curve is the Old School one, shared with the combat skills:
  `Catalog.skill_xp_to_level(level)` and `Catalog.skill_level(xp)`
  (83 XP to level 2, 13,034,431 XP to level 99, `Catalog.MAX_SKILL_LEVEL`).
- `GatheringDB.is_skill(id)` / `skill_name(id)` / `skill_ids()` read the
  catalog, so a skill is added in one place.

## Nodes
`GatheringDB.NODES` is the node list. A node is:

| field | meaning |
| --- | --- |
| `id` | unique key, also its loot table key |
| `skill` | the gathering skill it trains |
| `name` | display name |
| `kind` | `"tree"`, `"spot"` or `"vein"` |
| `biome` | the biome it grows in |
| `level` | the gathering level it asks for |
| `xp` | XP one successful gather pays |
| `respawn` | seconds of sim time before it can be worked again |

Two of each kind per biome, so a biome always offers a starter node and
something to level towards. The XP climbs with the level asked for and the
respawn grows with it: the better nodes are slower to come back.

Lookups: `node(id)`, `has_node(id)`, `nodes()` (by level, then id),
`nodes_for_skill(skill)`, `nodes_for_biome(biome)`, `nodes_for(skill, biome)`,
`skill_of(id)`.

## Resources
`GatheringDB.RESOURCES` maps a material id to `{"name", "skill"}`. The
materials are the same ids the boss drops use, so one bag holds everything
the world gives (`SaveGame.data["materials"]`).

## Drop tables
`LootTable.RESOURCE_TABLES` is keyed by node id. A row is
`{id, weight, amount: [min, max]}`: the material, how likely it is over the
others, and how many a gather takes.

- One row wins by weight; the amount is rolled inside the row's span, so a
  gather always yields exactly one material.
- The lower-weight row is the rarer leftover of the tier below, so a better
  node also pays a little of the worse one.
- `LootTable.roll_resource(rng, node_id)` rolls it. An unknown node pays
  nothing.

## Where the nodes are
- `HuntMap.gathering` holds the nodes of a world: `{node: node_id, pos}`.
- `HuntMap._lay_gathering()` puts the biome's nodes in the open areas, one
  per area, easiest first: the area nearest the start takes the lowest-level
  node. The placement uses the map's seeded rng, so a seed gives the same
  world every time.
- Only the explore world carries them: the duel arena (`HuntMap.for_biome`)
  and the flat test map have none.

## The run
`RunSim` mirrors the combat skill XP pipeline (`skill_xp`):

| step | combat | gathering |
| --- | --- | --- |
| tally | `skill_xp[hero][skill]` | `gather_xp[skill]` |
| drops | `xp_drop` events, one per `XP_DROP_INTERVAL` | `xp_drop` events, same rhythm |
| mid-run level | `skill_level` events | `skill_level` events |
| end of run | `skill_up` events, XP written to `GearDB` | `skill_up` events, XP written to `SaveGame` |

- `RunSim.gather(node_id)` resolves one gather: the account's level in the
  node's skill must meet the node's `level`, the node must be off its
  respawn, then it pays its XP and rolls its table. It returns
  `{ok, reason, node, skill, xp, drops}`.
- `RunSim._step_gathering()` works the nodes a hero has reached, claimed on
  contact like the shrines.
- The level that gates a node is read once, when the run starts, so the
  nodes a run can work never change under it. The XP it earns is banked with
  the rest of the run when it commits (`RunSim.commit_xp`), like the combat
  XP.
- The gathering XP is announced through the same `xp_drop` event as the
  combat XP, so the HUD needs no new plumbing: the skill id is the key, and
  the run screen already falls back to a capitalised name for a skill it does
  not know.
- The material rolls run on their own stream (`RunSim.gather_rng`, seeded
  from the run seed), so working a node never perturbs the loot rolls of the
  chests and bosses.

## Save
`SaveGame.data["skills"]` holds the gathering XP, keyed by skill id:
```
"skills": { "woodcutting": 0, "fishing": 0, "mining": 0 }
```
- `SaveGame.gathering_xp(skill)`, `gathering_level(skill)`,
  `gathering_skills()`, `gathering_reached(skill, level)`.
- `SaveGame.add_gathering_xp(skill, amount)` adds XP and returns the levels
  gained. The curve ends at 99, so XP past it is never banked.
- `SaveGame.add_material(id, amount)` and `add_materials(drops)` put gathered
  resources in the bag.
- Save version 5: the gathering skills are Woodcutting, Fishing and Mining.
  The old placeholder ids (foraging, taming, crafting) never had an XP
  source, so `migrate_gathering_skills()` drops them on load.

## Not in phase 1
- No gathering UI: the skills screen keeps its placeholder, and nothing
  shows the gathering levels, the materials or the nodes.
- No tools, no crafting, no selling: the materials are a bag, nothing reads
  them yet.
- No node art: the nodes are data in the world, not drawn.
