# Gear contract (scripts/gear_db.gd, class `GearDB`)

Heroes start **bare** (base clothes or underlayer). Every piece is **earned**
from camps, elites, bosses, chests and the treasure goblin. Gear is per hero
and per slot, and each piece's tier visibly changes the model when equipped.
The tier sheet (tools/tier_sheet.gd) is for showcase and debugging only.

## Enums
- `GearDB.Slot`: HELM, CHEST, PAULDRONS, GLOVES, BOOTS, WEAPON, OFFHAND, CHARM.
  Keys: `SLOT_KEYS` = helm, chest, pauldrons, gloves, boots, weapon, offhand, charm.
- `GearDB.Tier`: BARE=0 (nothing equipped), IRON=1, STEEL=2 (blackened steel),
  RUNE=3 (cursed rune plate). Keys: `TIER_KEYS`; display: `TIER_NAMES`, `TIER_COLORS`.

## Items
- Id: `"<hero>.<slot>.<tier>"`, e.g. `pebble.helm.2`. Tiers 1–3 only.
- Heroes: pebble (Aldric), bramble (Mordrek), lumen (Gnash), ember (Corvin).
  Slots per hero: `HERO_SLOTS` (Gnash has no off-hand). That gives 93 items.
- `item(id)` returns `{id, hero, slot, tier, name, stats}`.
  - Names come from `NAMES[hero][slot]` with a tier prefix: Iron, Blackened, Runebound.
  - Stats are `SLOT_STATS[slot]` × `TIER_MUL[tier]` (1.0 / 1.7 / 2.6).
  - Stat keys match `SaveGame.build_run_stats`: hp_flat, armor, dmg_pct, haste, crit, speed_pct, regen.
- `all_items(hero := "")` and `stats_for(slot, tier)`.

## Save
`SaveGame.data["armory"]`:
```
{ "v": 1,
  "owned":    { hero_id: { item_id: count } },
  "equipped": { hero_id: { slot_key: item_id } } }   # missing or "" = empty slot
```
The store is created lazily on first access. `GearDB.store_override = {}`
points the API at a scratch dict, for tests.

## API (all static)
| call | result |
|---|---|
| `grant(id) -> bool` | Adds one copy to that hero's stash. Returns false for an unknown id. |
| `equip(hero, id) -> bool` | Equips an item if it is owned and belongs to that hero. Replaces the slot's current item. |
| `unequip(hero, slot)` | Empties the slot. |
| `equipped(hero) -> Dictionary` | `{slot_key: item_id or ""}` for every slot the hero has. |
| `owned(hero) -> Array[String]` | Owned ids, best tier first. |
| `has(hero, id) -> bool` | Whether the hero owns the item. |
| `slot_tier(hero, slot) -> int` / `tiers(hero) -> {slot: tier}` | What the renderer draws. |
| `stats(hero) -> Dictionary` | Summed deltas of everything equipped. |
| `random_item(rng, tier, hero := "")` | Stub for loot owners. Uniform hero and slot. |

## Ownership
- **Visuals (Grok Bot):**
  - Gear3D renders `tiers(hero)`, with a bare underlayer when slots are empty.
  - The Heroes equip UI.
  - Loot beams and pickup VFX by tier.
  - The post-run loot reveal.
- **Helpers:**
  - Drop tables and source weighting (camps, elites, bosses, chests, goblin) in run_sim.
  - Rolling at run end and in chests (calling `grant`).
  - Persistence and migration from the legacy `bag`/weapon/armor/charm uids.
  - Folding `stats(hero)` into `build_run_stats`.
  - sim_check coverage.
- **Legacy:** the bag/weapon/armor/charm uid system in save_game.gd is
  unchanged until the helpers migrate it.

Self-test: `godot --headless --path . -s res://tools/gear_db_test.gd` prints `GEARDB PASS`.
