# Multiplayer notes

Design document for adding multiplayer to Critter Clash. Nothing here is
implemented: the game is still single player. The stubs exist so the shapes
are agreed before any transport is written, and the plan at the bottom
breaks the work into phases that can land one at a time.

**Status:** design only (Phase 3 hooks). No sockets, no server, no client
code paths changed.

## What exists today

- `scripts/run_sim.gd` (class `RunSim`) is the hunt: presentation-free,
  seeded, stepped with `step(dt, moves)`. Teams are `0` local heroes,
  `1` wild critters and the biome boss, `2` a duel rival.
- `scripts/session.gd` (class `Session`) describes a run: mode
  (`SOLO`, `COOP`, `DUEL`), biome, hero ids, seed. `Session.coop()` already
  places two heroes on team 0.
- `scripts/network_manager.gd` (class `NetworkManager`) is the future
  transport stub. Every call is a no-op; `connect_to()` returns `false`.
- `scripts/net_packet.gd` (class `NetPacket`) defines the packet shapes and
  JSON encoding.
- `Session.network_id` (added in this phase) carries the id the server
  assigned to a peer. It is `""` in solo play.

## Protocol overview

Three kinds of traffic, all JSON objects tagged with a type.

### State sync - 10 Hz

Every 100 ms the server sends a snapshot of the world: one state packet
per actor that changed, wrapped in a frame that carries the server's tick
counter, so a client can tell what it missed. 10 Hz is the floor, not the
ceiling: the server sends state for an actor only when it changed (moved,
took damage, died, changed team), and sends a full snapshot every second
so a late joiner can catch up.

10 Hz matches the phone budget. The sim runs at `STEP_HINT` (1/60 s) and the
run screen already steps it from an accumulator (up to five fixed steps in
one frame); sending state at 10 Hz and interpolating between snapshots is
what a client should draw.

### Action RPCs - client to server, event driven

Actions are requests, never facts. The client sends an action packet when
the player presses something ("attack", "skill", "move"), and the server
decides whether it happens. Action packets carry the sender's network id,
the action name and the target actor. The server runs the real sim and
turns accepted actions into state changes and events.

### Event stream - server to client, event driven

One-off things the client must see but that do not belong in a snapshot:
a level-up, a crit, a boss entering, a death and respawn, a loot drop.
Events are small, unordered with respect to each other, and always
decorative on the client: the client never derives game state from them.

The order matters: for one actor, state and events are ordered by the
server's tick. Across actors, a client may see a kill before the state
snapshot that removes the actor. The client keeps events for one tick and
applies them after the snapshot of that tick, so presentation never runs
ahead of the world.

## Packet fields

All packets are JSON objects. `t` is the type tag
(`NetPacket.TYPE_STATE` = 1, `TYPE_ACTION` = 2, `TYPE_EVENT` = 3). `id` is
the network id of the actor or peer the packet is about. Positions travel
as a three-float array (`[x, y, z]`) on the wire and are read back as a
`Vector3`.

### State packet - `t = 1`

| field | type | meaning |
| --- | --- | --- |
| `t` | int | packet type, always `1` |
| `id` | string | network id of the actor this snapshot is about |
| `pos` | float[3] | world position |
| `hp` | int | current health |
| `team` | int | team number, `0` heroes, `1` wild, `2` rival |

Made by `NetPacket.make_state(network_id, pos, hp, team)`.

### Action packet - `t = 2`

| field | type | meaning |
| --- | --- | --- |
| `t` | int | packet type, always `2` |
| `id` | string | network id of the sender |
| `action` | string | action name, e.g. `"attack"`, `"skill"`, `"move"` |
| `target` | int | id of the targeted actor, `0` when there is none |

Made by `NetPacket.make_action(network_id, action, target)`. The target is an
actor id, not a network id: `RunSim` hands out integer actor ids, and the
server resolves the target against its own actor list, dropping the action
if the id is out of range.

### Event packet - `t = 3`

| field | type | meaning |
| --- | --- | --- |
| `t` | int | packet type, always `3` |
| `tick` | int | server tick the event belongs to |
| `type` | string | event name, e.g. `"levelup"`, `"fx"`, `"boss_in"` |
| `id` | string | network id of the actor the event is about, if any |
| `data` | dict | event payload, shape depends on `type` |

The `type` and `data` names follow the events the sim already emits
(`scripts/run_sim.gd`): `fx`, `attack`, `hitstop`, `levelup`, `xp_drop`,
`boss_in`, `respawn_done`. Those events are built for local presentation;
on the wire they are forwarded as they are, minus the fields that only
make sense locally (screen shake amounts, camera targets).

## Server architecture

Two options, one recommended.

### Lockstep - every client simulates

Each client runs the same seeded sim and only exchanges inputs. Cheap on
bandwidth and every client sees a perfect world.

The problem is that it needs perfect determinism across every device.
`RunSim` runs on floats: a `lerp`, an angle wrap, a trig call or an
`RNG` draw in a different order is enough to split two clients apart, and
the run never recovers because every later step builds on the wrong
number. Making that safe means a fixed-point sim and a lockstep input
delay, which is a rewrite of the combat core.

### Authoritative server - recommended

The server runs the only real `RunSim`, at a fixed tick. Clients send
actions and draw state snapshots. The sim stays exactly as it is - the
server is a headless Godot process running the same `RunSim` the client
runs, which is the cheapest possible way to get a server that matches the
game.

Client prediction: the client applies its own action locally the moment
the player presses it, keeps that prediction while the snapshot for that
tick is in flight, and snaps to the server state when the snapshot
arrives. Without it every attack would feel like it landed a round-trip
later, which on a phone reads as input lag. With it, only the local hero
is predicted; the rest of the world is server truth drawn one tick late
and interpolated.

The reconciliation rules: the client keeps a short input history, replays
the unacknowledged actions against the server state when a snapshot
arrives, and only rewinds when the prediction actually differs from the
server (a blocked attack, a death). Rewinding on every snapshot would
make the hero stutter.

Cost: one server tick per run, so a run costs the server about as much as
one player costs the game. Bandwidth is one small snapshot per actor per
100 ms, which is a few hundred bytes per tick for four actors - well inside
a mobile connection.

## Cheat resistance

The server is the only authority, so a modified client cannot forge
anything it does not have the authority to decide.

- **Positions.** The client cannot set its position; it sends actions, and
  the server moves the actor. A teleporting client is a client whose
  snapshot does not match its inputs.
- **Health and damage.** The client never sends hp or damage. The server
  computes them from the sim.
- **Loot and drops.** The server decides what drops and owns the run
  result. The client shows loot it was told about; the item ids in the
  end card come from the server's run result, not from the client. A
  client that claims a better drop is a client whose result the server
  overwrites.
- **Cooldowns and costs.** Skills cost and cooldown live in the sim, so
  the server applies them. An action that arrives while the actor is on
  cooldown is dropped.
- **Actions out of order or too fast.** The server keeps a per-peer
  sequence number and drops stale or replayed actions. A peer that sends
  faster than the tick rate is rate-limited, not disconnected, so a bad
  network costs playability, not the session.
- **Build mismatch.** The server sends the content build it runs. A client
  on a different build is asked to update first - the same OTA path the
  game already uses (`docs/ota.md`).

Cheat resistance is not the same as anti-cheat: a client can still read
its own memory, and it can still be modified. The goal is that a modified
client cannot change the outcome of a run, because the server never takes
its word for anything.

## Hooks already in place

- `Session.network_id` (this phase) - the peer's id, empty in solo play.
  The run screen and the sim read it to label an actor.
- `NetPacket` - the packet shapes, the type tags and the JSON encoding.
- `NetworkManager` - the transport surface: `connect_to()`, `disconnect()`,
  `send_state()`, `receive_state()`, plus `connected` and `peer_network_id`.
  A real transport replaces the bodies of these four methods and nothing
  else has to change.
- `Session.Mode.COOP` and `Session.coop()` - two heroes on team 0, which
  is what a co-op session already looks like. A network session is the same
  shape with the second hero's input coming from the network.

The sim itself needs no change for the server side: `RunSim` never touches
the scene tree, so a headless process can run it.

## Rollout plan

Each phase is shippable on its own. Phases 0 to 2 are in the game already;
phase 3 is this change.

### Phase 0 - offline co-op groundwork

`Session.Mode.COOP` with two heroes on team 0 and a second move vector, so
the "two players share a run" shape exists without a network.

### Phase 1 - deterministic sim seeds

A run seed that both ends of a connection can agree on, kept in
`Session.seed`, so a client can rebuild the same world.

### Phase 2 - data-driven balance

Tuning tables moved into data, so a server and a client on different
builds cannot disagree about what a hero does.

### Phase 3 - network hooks (this phase)

`NetworkManager`, `NetPacket`, `Session.network_id` and this document. No
behaviour changes: every stub call is a no-op and solo play is untouched.

### Phase 4 - local transport

A loopback transport that runs the real packets between two `RunSim`s in
one process: one side is fed recorded actions, the other side is fed
snapshots. This is where the protocol is first exercised, and it is
testable without a server.

### Phase 5 - headless server

A headless Godot build that runs `RunSim` on a fixed tick, accepts
actions, and broadcasts snapshots and events. Behind a flag, host mode:
one device starts the session and the others join by address.

### Phase 6 - client integration

`run_screen.gd` splits its local sim into a local view and a network
view: the local hero is predicted, the rest of the world is interpolated
from snapshots. `NetworkManager` grows a real transport behind the same
four methods.

### Phase 7 - prediction and reconciliation

Input history, replay on snapshot arrival, snap-to-server on mismatch.
The hero stops feeling laggy.

### Phase 8 - public lobbies

A lobby service: sessions, addresses, and a stable content build
handshake. Cross-device play, matchmaking, reconnect.

### Phase 9 - hardening

Rate limiting, sequence checks, a cheat policy, logs a moderator can
read, and the server run result becoming the only source of truth for
rewards.
