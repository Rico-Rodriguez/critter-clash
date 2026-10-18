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
  "equipped": { hero_id: { slot_key: item_id } },   # missing or "" = empty slot
  "xp":       { hero_id: { skill_key: xp } } }     # missing = start level
```
The store is created lazily on first access. `GearDB.store_override = {}`
points the API at a scratch dict, for tests.

`SaveGame.data["gear_shards"]` is the shard wallet (int, default 0; an old
save without the key reconciles to 0). Shards come from duplicate rolls, see
below.

## Tier caps by biome depth
A source may only drop so high a tier at a given biome, so shallow ground
cannot faucet rune. The cap is the biome's position in `Catalog.BIOMES`
(meadow 0, mushroom 1, frost 2, volcano 3):

| source | meadow 0 | mushroom 1 | frost 2 | volcano 3 |
|---|---|---|---|---|
| camp, elite, chest_common | iron | iron+steel | iron+steel | +rune |
| boss, goblin, chest_rare/epic/legendary | iron | iron+steel | +rune | +rune |

`LootTable.MAX_TIER_BY_DEPTH` holds the table, `LootTable.max_tier(source,
biome_idx)` returns one cap, and `LootTable._weights` renormalises: the depth
shift runs first, then weight above the cap is spread back over the allowed
tiers so the total never changes and a roll always lands on an allowed tier.
The run uses the biome it was launched in; drawer chests use the biome
recorded on the chest (`open_next`). A meadow source therefore rolls iron
only, boss included.

## Which hero a drop is for
A run drop rolls the run's hero on a 75% coin flip; the other 25% goes to a
uniformly chosen hero, which can also be the run hero. The effective share is
75% + 25% x 1/4 = **81.25%** for the run hero (sim_check measures ~81%). That is
intended: off-hero pieces are a small pull toward the rest of the roster.

## Duplicates convert to shards or coins
When a rolled piece is already owned by its hero, or an earlier id in the same
bank already granted it, it is not a second copy: it banks as **gear shards**
at `data["gear_shards"]`. If the hero already owns every item of that tier,
the roll pays **coins** instead.

| tier | shards | coins (tier complete) |
|---|---|---|
| iron | 5 | 10 |
| blackened steel | 15 | 25 |
| cursed rune | 40 | 60 |

`SaveGame.GEAR_SHARDS` and `SaveGame.GEAR_DUP_COINS` hold the tables (index =
`GearDB.Tier`). The preference for unowned pieces in `LootTable._pick` is
unchanged, and banking stays deterministic for a seed.

`SaveGame.bank_gear(ids)` grants the list once and returns
`{"ids": [granted item ids], "shards": total, "coins": total}`; the granted
ids are backward compatible with the old banked-id list. `RunSim.bank_gear()`
still returns the granted id array and also stores that result in
`RunSim.gear_bank` for the end card, so it can show the shard/coin spoils.
`RunSim.bank_gear` still guards against a second call, so banking a run twice
pays once. `SaveGame.open_next` (drawer chests) uses the same conversion and
adds `gear_shards` to its loot dictionary (duplicates no longer appear in
`gear_items`).

## The Forge
Shards from duplicate rolls (above) buy the pieces a hunt has not handed over
yet. A tier opens once the player has opened ground deep enough to drop it, so
the Forge cannot shortcut progression: the cap is the boss tier cap at the
deepest open biome (`LootTable.max_tier("boss", depth)`, see the tier table).
A meadow-only player forges iron; blackened steel waits for Mushroom Forest,
cursed rune for Frost Peaks.

| tier | cost (shards) |
|---|---|
| iron | 20 |
| blackened steel | 60 |
| cursed rune | 160 |

`SaveGame.FORGE_COST` holds the table (index = `GearDB.Tier`). Prices sit about
four times the duplicate refund, so forging stays a deliberate sink rather than
the fast road.

| call | result |
|---|---|
| `SaveGame.forge_depth() -> int` | Index of the deepest open biome in `Catalog.BIOMES`. |
| `SaveGame.forge_cap() -> int` | Best tier the Forge can make now (boss cap at that depth). |
| `SaveGame.forge_options(hero) -> Array` | Every **unowned** piece of the hero's kit at or below the cap, best tier first: `{id, slot, tier, cost, ok, reason}`. |
| `SaveGame.forge_skill_gate(hero, id) -> String` | The first untrained wear requirement (`"Requires Defence 20"`), or `""`. Forging respects the same skill gates as equipping. |
| `SaveGame.forge_lock_reason(tier) -> String` | Why a tier is still shut, naming the biome to reach (`"Reach Frost to forge rune"`), or `""` when it is open. |
| `SaveGame.forge(hero, id) -> bool` | Pays the cost, grants the piece and writes once. Refuses an unknown or foreign id, an owned piece, a tier above the cap, an untrained skill gate and an unaffordable price; the wallet never goes negative and a failed grant costs nothing. |

`reason` on an unaffordable option is `"Need %d more shards"`; `ok` is false.

The screen (`scripts/forge_screen.gd`, route `"forge"`, reached from the Home
tile row) groups the options by tier with a shard readout, greys a FORGE button
to its shortfall, and footnotes the closed tiers with their biome lock. Its
hero switcher is view-only, like Skills: it never writes `data["featured"]`.
`sim_check`'s `forge` case covers the 0-shard, meadow-only iron, single grant,
shard deduction, rune gating and wallet-floor rules.

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

## Combat skills (OSRS-style, persistent, per hero)
- `GearDB.Skill`: ATTACK, STRENGTH, DEFENCE, RANGED, MAGIC, HITPOINTS.
  Keys are in `SKILL_KEYS`.
- Levels run 1–99. Hitpoints starts at 10 (1,154 XP). Everything else starts at 1.
- OSRS curve:
  - `xp_for_level(L) = floor(Σ_{l=1}^{L-1} floor(l + 300·2^(l/7)) / 4)`
  - Level 2 needs 83 XP; level 99 needs 13,034,431 XP.
  - `level_for_xp(xp)` is the inverse.
- XP sources (helpers wire these in run_sim):
  - Melee hits: Attack and Strength.
  - Damage taken or blocked: Defence.
  - Ranged hits: Ranged.
  - Spells and bolts: Magic.
  - Damage dealt: Hitpoints (OSRS-style share).
- API: `xp(hero, skill)`, `level(hero, skill)`, `skills(hero)`.
  `add_xp(hero, skill, amount)` returns the levels gained, for toasts.
- Per-level stat hook `level_bonus(hero)`:
  - Attack: +0.05% crit per level.
  - Strength: +0.3% damage per level.
  - Defence: +1 armour per 10 levels.
  - Hitpoints: +2 HP per level over 10.
  - Ranged/Magic: +0.3% damage per level, only for the hero whose weapon uses that skill (Corvin: Magic).
  - `build_run_stats` should fold in both `stats(hero)` and `level_bonus(hero)`.

### Equip gating
- `item(id)["requires"]` and `requirements(id)` return `{skill: level}`.
- Default levels by tier: iron 1 (no requirement), blackened steel 20, cursed rune 40.
- Which skill gates each slot:
  - Helm, chest, boots, off-hand: Defence.
  - Pauldrons, gloves: Strength.
  - Charm: Hitpoints.
  - Weapon: the hero's class skill in `WEAPON_SKILL` (Attack for the three melee knights, Magic for Corvin).
- Per-item exceptions go in `REQ_OVERRIDES[item_id]`.
- Examples:
  - `pebble.helm.2` needs Defence 20.
  - `bramble.weapon.3` needs Attack 40.
  - `ember.weapon.3` needs Magic 40.
- `can_equip(hero, id) -> {ok, reason}`. Possible reasons:
  - "Unknown item"
  - "Not for this hero"
  - "Not owned"
  - "Requires Defence 20"
- `equip()` refuses anything `can_equip` rejects.
- The Heroes equip UI shows a locked badge with the reason on owned items that can't be equipped yet.

### Skills screen
- **Decision:** the Skills screen splits into two tabs.
  - **Combat** is per hero: the six skills for the hero selected on Heroes, with an XP bar to the next level.
  - **Gathering** is account-wide: Foraging, Fishing, Taming and Crafting from `Catalog.SKILLS` and `SaveGame.data["skills"]`, unchanged.
- **Why split:** combat levels belong to a hero and gate that hero's gear, while gathering is shared progress.
- **Owners:** the panel, XP gain and level-up toasts are the helpers' to build.

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

## Loot visuals contract (rendering side, owned by integration)

The hunt renders gear loot from two sim events. Helpers' drop/roll code only
has to emit them; the visuals and the reveal are already wired.

| event `type`   | fields                                   | effect |
|----------------|------------------------------------------|--------|
| `gear_drop`    | `item` (GearDB id), `pos` (Vector2), `key` (optional, unique per drop; defaults to `item`) | Tier light beam on the ground: iron short/warm, steel taller/cool, rune plate a tall pulsing pillar with a rune ring and a rare haptic. |
| `gear_pickup`  | `item`, `pos`, `key` (same as the drop)  | Beam collapses into a tier ring + spark, a streak to the hero, a floating item name. The id is appended to `run_screen.run_gear`. |

End-of-run card ("SPOILS"): `EquipUI.loot_reveal(ids)` shows one face-down
card per piece, flipping in tier order (best last). Ids come from
`run_gear` plus `summary["gear"]` if the save layer's `commit_victory` /
defeat summary returns one. Granting into the armory (`GearDB.grant`) stays
with the loot/persistence helpers; the reveal never grants.

Capture/demo env: `CC_DEMO_LOOT=1` stages one drop per tier in the hunt shot
and adds a `pickup` shot; `CC_DEMO_SPOILS=id,id,...` fills the reveal when a
run earned nothing.
