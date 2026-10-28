extends RefCounted
## The registry and the three calls Hunt makes (hunt_state.gd `spawn_foe`,
## hunt.gd `_tick_foes`, hunt_combat.gd `_kill`). A foe def with a `brain` dict
## gets a brain object stored in the enemy's meta "brain"; nothing in the
## Lead's files (enemy.gd, actor.gd, hero.gd, arena.gd, boss.gd) changes.

const SCRIPTS := {
	"skitter": preload("res://src/hunt/foe_skitter.gd"),
	"dormant": preload("res://src/hunt/foe_dormant.gd"),
	"kite": preload("res://src/hunt/foe_kite.gd"),
	"caster": preload("res://src/hunt/foe_caster.gd"),
	"pack": preload("res://src/hunt/foe_pack.gd"),
	"yeti": preload("res://src/hunt/foe_yeti.gd"),
	"drift": preload("res://src/hunt/foe_drift.gd"),
	"ambush": preload("res://src/hunt/foe_ambush.gd"),
	"wasp": preload("res://src/hunt/foe_wasp.gd"),
}

## True (the default): zones that have a `faction_next` field it (Rimehollow and the Cinder Mire).
## False: every zone fields its old faction; `--old-foes` turns that on for a run.
static var next := true


static func attach(e: Enemy) -> void:
	var cfg: Dictionary = e.def.get("brain", {})
	if cfg.is_empty():
		return
	var s: GDScript = SCRIPTS.get(str(cfg.get("kind", "")))
	if s == null:
		push_warning("foe %s: unknown brain %s" % [e.kind, cfg.get("kind")])
		return
	var b: RefCounted = s.new()
	b.setup(e)
	e.set_meta("brain", b)


static func of(e: Node) -> RefCounted:
	return e.get_meta("brain") if e.has_meta("brain") else null


## True when a brain ran this foe's tick (so Hunt skips `Enemy.tick`).
static func tick(e: Enemy, dt: float) -> bool:
	var b := of(e)
	return b != null and b.tick(dt)


static func death(e: Enemy) -> void:
	var b := of(e)
	if b != null:
		b.on_death()


## The faction the zone fields right now.
static func faction(zone: Dictionary) -> Dictionary:
	if next and zone.has("faction_next"):
		return zone["faction_next"]
	return zone.get("faction", {})


## The director's per-slot weights for the faction in force.
static func weights(zone: Dictionary) -> Dictionary:
	if next and zone.has("weights_next"):
		return zone["weights_next"]
	return zone["weights"]


## Living foes of a kind, for caps (callers, packs).
static func count(h: Hunt, kind: String) -> int:
	var n := 0
	for f in h.foes:
		if f.alive and f.kind == kind:
			n += 1
	return n
