# The town's asset pack

Every `.glb` in this folder is placed in Barrow Haven by the name of the
file, so a pack of houses, stalls or props can be dropped in and shows up
in the town without a line of code.

The names the town knows, and where each one stands:

| name | where it stands |
| --- | --- |
| `house_a`, `house_b` | the north wall, either side of the bridge |
| `house_c`, `house_d` | the east and west of the plaza |
| `fountain` | the middle of the plaza |
| `statue` | the north-west of the plaza |
| `cart`, `barrel`, `crate`, `anvil` | around the plaza, with the trade |
| `sign` | the road to the bridge |
| `well` | the south-west of the plaza |

Any other name is set on a ring around the plaza, so a pack of anything
still stands in the town.

The models are placed at their own scale (1.0) and their own origin, so
a model that is the right size for a house needs nothing else. A model
that should be smaller or larger than its file says can carry a number
after its name: `house_a_1.4.glb` is set at 1.4 times the size.

Where the models come from is up to you: keep the licence with the model
and add a line to `CREDITS.md` (the in-game credits screen reads that
file). The project already uses CC0 and CC-BY packs for the nature models
and the hero rigs, and the same rule applies here.
