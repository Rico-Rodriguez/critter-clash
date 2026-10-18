class_name RunSim
extends RefCounted

## Presentation-free hunt. Teams:
##   0 local heroes (solo, or every co-op hero)
##   1 wild critters and the biome boss
##   2 a duel rival
## Hostility is "other team". Moves come from outside, one vector per hero.
## The launch game only feeds team 0 from the thumbstick.
##
## Skill FX hooks (presentation placeholders, drained by run_screen.gd):
##   events.append({"type": "fx", "fx": <name>, "pos": <Vector2>,
##                  "to": <Vector2, optional>, "radius": <float, optional>})
## Unknown names are safe; run_screen picks a colour and sparks.

const STEP_HINT := 1.0 / 60.0

## Per-class feel tuning, keyed by role (never by hero id) so every hero of a
## class inherits it; run_sim only ever reads these through the role.
##   tank   - longer reach, a wall-safe gap-closing charge, a front cleave,
##            damage reduction while swinging, on-hit lifesteal and heavy
##            knockback.
##   archer - quicker plant-to-shot, long-range bonus damage, bonus pierce
##            at range and ricochet that grows with level.
##   mage   - orb splash leaves a slow field, every 4th cast is a larger burst,
##            and the glassiest body (-10% max hp).
const ROLE_TUNING := {
	"tank": {
		"reach_mul": 1.18,
		"hp_mul": 1.0,
		"cleave_arc": 160.0,
		"cleave_mul": 0.85,
		"swing_dr": 0.30,
		"swing_dr_time": 0.35,
		"lifesteal": 0.04,
		## Melee impact: a normal foe is shoved this many px over melee_kb_time
		## seconds; a boss or elite barely budges.
		"melee_kb": 28.0,
		"melee_kb_elite": 5.0,
		"melee_kb_time": 0.12,
		"charge_range": 300.0,
		"charge_time": 0.16,
		"charge_cd": 3.5,
		"charge_aoe": 78.0,
		"charge_stun": 0.35,
	},
	"archer": {
		"hp_mul": 1.0,
		"windup_mul": 0.6,
		"long_frac": 0.6,
		"long_bonus": 0.25,
		"ricochet_level": 0.015,
		"ricochet_cap": 0.30,
	},
	"mage": {
		"hp_mul": 0.9,
		"burst_every": 4,
		"burst_mul": 1.6,
		"slow_life": 1.1,
		"slow_k": 0.35,
	},
}

## Melee hit-stop: a short freeze on a crit or kill that the run screen plays by
## skipping sim steps (never Engine.time_scale, which would stall device-wide
## timers). One per HITSTOP_CD of sim time, so a run of crits reads as impact
## instead of stutter.
const HITSTOP_FREEZE := 0.055
const HITSTOP_CD := 0.25
var _hitstop_at := -1.0e9

var rng := RandomNumberGenerator.new()
## Loot uses its own stream, seeded from the run seed (xor constant) in
## start(), so drops are deterministic for the seed and never perturb combat.
var loot_rng := RandomNumberGenerator.new()
## Item ids earned this run; drop hooks append. The screen calls bank_gear()
## once when it commits the run (never the sim itself, so bots and tests
## never write the real armory).
var gear_found: Array[String] = []
## The last bank result: {"ids", "shards", "coins"} from SaveGame.bank_gear
## (docs/gear.md). Duplicates bank as shards or coins, not a second copy; the
## end card can read the shard/coin totals here. Empty until bank_gear runs.
var gear_bank: Dictionary = {}
var _banked := false
## True once the run's combat XP has been written (bank_gear or commit_xp).
var _xp_committed := false
## Pieces lying on the ground: {key, item, pos, t}. The hero takes one by
## walking near it, or it flies to them after GEAR_MAGNET seconds, so nothing
## earned is ever left behind (docs/gear.md: gear_drop then gear_pickup).
var gear_ground: Array = []
const GEAR_REACH := 90.0
const GEAR_MAGNET := 3.0
var mode := Session.Mode.SOLO
var biome_id := "meadow"
var biome: Dictionary = {}
## The map's difficulty tier (Catalog.Tier): 0 Normal, 1 Veteran, 2 Nightmare.
var difficulty := 0
## Daily run modifiers (Session.modifiers). Empty for normal hunts.
var modifiers: Array = []
var map: HuntMap
var play := Rect2(40, 168, 640, 980)
var time := 0.0
var phase := "hunt"
var result := ""
var paused := false
var enraged := false
var level := 1
var xp := 0
var xp_need := 14
var offer: Array = []
var offer_queue := 0
var stacks: Dictionary = {}
var revive_spent := false
var phoenix_spent := false
var events: Array = []
var actors: Array[Actor] = []
var heroes: Array[Actor] = []
## Solid obstacles (x, y, radius) in sim space: the boss arena's standing
## stones. Everything that walks steers around and slides along them.
var obstacles: Array[Vector3] = []
var shots: Array[Shot] = []
var gems: Array[Gem] = []
var pings: Array[Ping] = []
var fields: Array[Field] = []
var boss: Actor = null
var slain := 0
## Report counters: damage the team-0 heroes took after armor and bulwark,
## and foes (minions and bosses) killed by team 0. Read by the class report.
var dmg_taken := 0.0
var kills := 0
## Combat-skill XP earned this run, by hero id then skill key (floats, rounded
## when the run commits). No GearDB writes happen during the fight; bank_gear()
## writes them once at run end. See SKILL_XP_SCALE for the OSRS scale-down.
var skill_xp := {}
## OSRS-style XP drops: the run's committed combat XP is announced to the HUD a
## skill at a time, at most once per XP_DROP_INTERVAL of sim time, using the
## same rounded totals _commit_skill_xp will write (so the drops always sum to
## what is committed). Keyed by skill, never by hero id. _xp_drop_time holds the
## sim time the drop's window closed, for the one-per-second spacing.
const XP_DROP_INTERVAL := 1.0
var _xp_drop_total := {}
var _xp_drop_time := {}
## Skill levels already announced this run, seeded from GearDB at start() so
## only levels crossed mid-run fire a skill_level event. _skill_base_xp is the
## run hero's GearDB XP before the fight; _skill_run_seen caches the last round
## of its run tally so level_for_xp is not recomputed every step.
var _skill_level := {}
var _skill_base_xp := {}
var _skill_run_seen := {}
var boss_mark := 0
## True once the boss has opened with its first attack; only that first
## telegraph waits until the boss shares the hero's view.
var boss_opened := false
var spawn_cd := 0.35
const MAX_MINIONS := 14
const PACK_SIZE := 8
## Packs are bigger and each critter softer than the old trickle, so a wave
## crowds the screen without changing how much XP a hunt pays.
const MINION_HP := 0.5
const MINION_XP := 0.7
## Combat-skill XP is OSRS-shaped (4 XP per damage to the trained combat skill,
## 1.33 to Hitpoints, the weapon award split between the class skills) scaled
## down by this factor, so a full ~4 minute hunt lands the main skill and the
## Defence gate together around the levels the steel/rune tiers ask for. Fight
## XP is only accumulated here; GearDB is written once when the screen commits
## the run.
const SKILL_XP_SCALE := 0.060
const COMBAT_XP_PER_DAMAGE := 4.0 * SKILL_XP_SCALE
## Hitpoints' share of a combat award (OSRS ~1.33 / 4).
const HP_XP_SHARE := 0.3325
## OSRS-style split of the weapon award: controlled melee gives Attack, Strength
## and Defence a third each; longrange shots and spells give their skill 75%
## and Defence 25%. Each melee row still sums to 1.0, so melee XP per damage is
## the same across the three skills; the longrange rows are then scaled by
## LONGRANGE_PACE.
const MELEE_SHARE := 1.0 / 3.0
const RANGED_MAIN_SHARE := 0.75
const RANGED_DEF_SHARE := 0.25
## Ranged/magic's main skill gets 75% of the award where a controlled melee
## skill gets only a third each, so without this the archer/mage race the
## steel/rune gates the report tracks. Scaling the whole longrange award (the
## main skill and its 25% Defence share) paces them like melee while keeping the
## split; melee is untouched. Tuned so fresh runs reach main 20 around runs
## 8-16 and main 40 around runs 35-60 (XP to 20 is ~4470, to 40 ~37200): the
## archer earns ~588 ranged XP/run, so ~0.53 is the least that still reaches
## 37224 within 60 runs; 0.54 keeps it at run ~59 while holding mage back.
const LONGRANGE_PACE := 0.54
## Ellipse just outside the hunt camera's view, in playfield pixels.
## What the far follow camera frames on the ground, relative to the hero
## (sim px; Stage3D DIST 34, FOV 40, AIM +1.5, pitch 58; tools: viewbox.py). The far edge is
## wider than the near one; the box takes the wider. Packs spawn just past it.
const VIEW_BOX := Rect2(-802.0, -2377.0, 1604.0, 3469.0)
const SPAWN_MARGIN := 24.0
## Heroes fight only when planted: moving is a clean run, and the first shot
## comes this long after the stick is released.
const PLANT := 0.08
## Dodge roll: ~0.18 s dash for ~230 px, brief invulnerability, fixed cooldown.
## dodge_ready() reports progress through DODGE_CD for the HUD's sweep.
const DODGE_DIST := 230.0
const DODGE_TIME := 0.18
const DODGE_CD := 2.2
const DODGE_GRACE := 0.08
var _next_id := 1
var bases: Dictionary = {}

## --- Explore mode (solo and co-op hunts) ---
## The hunt is a map to explore: camps, patrols, elite packs and loot chests
## are placed up front, the boss waits in its lair at the far end, and
## killing it ends the run. No wave spawner and no clock.
var explore := false
## Fog of war on the map's pathing grid: seen stays 1 once revealed, now is
## what the hero can see this moment.
var fog_seen := PackedByteArray()
var fog_now := PackedByteArray()
var fog_dirty := true
const REVEAL := 1200.0
const AGGRO_CAMP := 430.0
const AGGRO_PATROL := 380.0
const LEASH := 1500.0
## Shrines: how close the hero must walk, and how long the buff lasts.
const SHRINE_REACH := 120.0
const SHRINE_SECONDS := 30.0
## Warding's regen surge: hp/s for the first few seconds of the buff.
const WARD_REGEN := 20.0
const WARD_REGEN_TIME := 4.0
## Treasure goblin: one roll on first approach, then a short flight.
const GOBLIN_CHANCE := 0.6
const GOBLIN_SIGHT := 700.0
const GOBLIN_LEASH := 1600.0
const GOBLIN_LIFE := 12.0
## Loot chests on the map: {pos, tier, open}
var chests: Array = []
## Shrines on the map: {pos, kind, used}. Claimed once by walking within
## SHRINE_REACH; the buff stacks on top of _recompute for SHRINE_SECONDS.
var shrines: Array = []
## The run's treasure goblin, if its roll passed, and whether the roll is spent.
var goblin: Actor = null
var goblin_roll := false
var loot_coins := 0
var boss_time := 0.0
## Fancy title for the boss name card, keyed by biome ("Lord of the Lair" else).
var boss_title := ""
## Boss intro beat: once the lair triggers, the boss rises but holds still and
## cannot be hurt or attack for this long, so the reveal can play out.
const BOSS_INTRO := 1.6
## The boss only starts an attack within this range of the hero, so its first
## telegraph ring can never open off-screen; it closes the gap first.
const BOSS_ENGAGE := 900.0
## Phase 2: the boss enrages once below half health. A 0.8 s roar telegraph
## (the HUD boss bar shows ENRAGED) is followed by +20% attack speed and one
## archetype extra pattern. Every phase-2 telegraph stays at
## BOSS_PHASE_TELEGRAPH so the new pattern is always dodgeable (>= 0.7 s).
const BOSS_PHASE_HP := 0.5
const BOSS_ROAR := 0.8
const BOSS_PHASE_TELEGRAPH := 1.0
const BOSS_PHASE_SPEED := 1.2
const BOSS_TITLES := {
	"meadow": "Warden of the Moss",
	"mushroom": "Sovereign of Spores",
	"frost": "The Rime Colossus",
	"volcano": "Tyrant of Ash",
}
var _fog_t := 0.0
var _flow := PackedInt32Array()
var _flow_cell := -1
var _flow_t := 0.0
var _add_t := 0.0


class Actor extends RefCounted:
	var id := 0
	var team := 0
	var kind := "minion"
	var sprite := ""
	var role := ""
	var display := ""
	var archetype := ""
	var pos := Vector2.ZERO
	var prev := Vector2.ZERO
	var vel := Vector2.ZERO
	var facing := 0.0
	var radius := 24.0
	var hp := 1.0
	var max_hp := 1.0
	var speed := 100.0
	var dmg := 1.0
	var armor := 0.0
	var interval := 0.5
	var range := 200.0
	var cd := 0.0
	var touch_cd := 0.0
	var charge_cd := 0.0
	## Tank gap-closer: time left in the leap, its heading and speed.
	var charge_t := 0.0
	var charge_dir := Vector2.RIGHT
	var charge_speed := 0.0
	## Tank swing damage reduction: time left of the post-attack guard.
	var swing_t := 0.0
	## Melee knockback: distance left to travel, its pace and heading. A shove
	## owns the body until kb_left runs out, then normal AI resumes.
	var kb_left := 0.0
	var kb_rate := 0.0
	var kb_dir := Vector2.RIGHT
	var shot_speed := 240.0
	var xp := 1
	var alive := true
	var flash := 0.0
	var iframes := 0.0
	var stats: Dictionary = {}
	var boss_state := ""
	var boss_timer := 0.0
	var boss_dir := Vector2.RIGHT
	## Phase 2: once below half health the boss roars, then strikes faster and
	## unlocks one archetype extra pattern. phase2_pending opens that pattern
	## on the first attack after the roar.
	var phase2 := false
	var phase2_pending := false
	var atk_speed := 1.0
	var attack := ""
	var bias_charge := 0.33
	var bias_aoe := 0.33
	var aoe_dmg := 20.0
	var charge_dmg := 20.0
	var shot_dmg := 10.0
	var aim := 0.0
	var windup := 0.0
	var best_d := 1e9
	var stall_t := 0.0
	var side_t := 0.0
	var side_dir := Vector2.ZERO
	## Seconds since the stick was released (0 while moving).
	var still := 0.0
	# Dodge roll: cooldown left, dash time left, dash heading.
	var dodge_cd := 0.0
	var dodge_t := 0.0
	var dodge_dir := Vector2.RIGHT
	# Explore: camps and patrols wait until the hero comes close.
	var camp := -1
	var home := Vector2.ZERO
	var aggro := true
	var patrol_a := Vector2.INF
	var patrol_b := Vector2.ZERO
	var to_b := true
	var elite := false
	## Elite affixes carried by this actor (fast/shielded/molten/vampiric).
	var affixes: Array = []
	## Damage shield: absorbs damage before hp. Shielded affix only.
	var shield := 0.0
	## Treasure goblin: flees instead of fighting, and drops a rare chest.
	var goblin := false
	var goblin_t := 0.0
	## Temporary shrine buffs by kind, in seconds left.
	var shrine_buffs: Dictionary = {}
	## Warding shrine's short regen surge, in seconds left.
	var regen_burst := 0.0
	## Skill state: status timers, per-target blade ticks and skill cooldowns.
	var slow := 0.0
	var slow_k := 0.0
	var stun := 0.0
	var mark := 0.0
	var weaken := 0.0
	var blade_ang := 0.0
	var blade_cd: Dictionary = {}
	var cds: Dictionary = {}
	var atk_count := 0
	var owner_hero := 0
	var summon_ids: Array = []


class Field extends RefCounted:
	var pos := Vector2.ZERO
	var radius := 40.0
	var life := 2.0
	var delay := 0.0
	var dmg := 5.0
	var tick := 0.35
	var tick_cd := 0.0
	var team := 0
	var owner_id := -1
	var kind := "fire"
	var alive := true


class Shot extends RefCounted:
	var pos := Vector2.ZERO
	var prev := Vector2.ZERO
	var vel := Vector2.ZERO
	var radius := 10.0
	var dmg := 1.0
	var team := 0
	var owner_id := -1
	var alive := true
	var ttl := 1.4
	var splash := 0.0
	var splash_mul := 0.62
	var pierce := 0
	var bounce := 0
	var crit := false
	var kind := "orb"
	var hit_ids: Array = []
	var split := 0
	var did_split := false


class Gem extends RefCounted:
	var pos := Vector2.ZERO
	var prev := Vector2.ZERO
	var value := 1
	var alive := true
	var bob := 0.0


class Ping extends RefCounted:
	var pos := Vector2.ZERO
	var radius := 80.0
	var life := 0.7
	var max_life := 0.7
	var kind := "circle"
	var dir := Vector2.RIGHT
	var length := 280.0
	var width := 70.0
	var dmg := 20.0
	var alive := true


func start(session: Session, stats_for: Dictionary, tier := 0) -> void:
	var run_seed := session.seed if session.seed != 0 else randi()
	rng.seed = run_seed
	loot_rng.seed = run_seed ^ 0x6EA2
	mode = session.mode
	biome_id = session.biome_id
	biome = Catalog.biome(biome_id)
	difficulty = clampi(tier, 0, Catalog.TIER_COUNT - 1)
	modifiers = session.modifiers
	explore = mode != Session.Mode.DUEL
	map = HuntMap.world(biome_id, rng.seed) if explore else HuntMap.for_biome(biome_id)
	play = map.play
	if explore:
		fog_seen.resize(map.grid_w * map.grid_h)
		fog_now.resize(map.grid_w * map.grid_h)
	xp_need = Catalog.xp_for_level(1)
	var count := session.hero_ids.size()
	if mode == Session.Mode.SOLO:
		count = mini(count, 1)
	for i in count:
		var id := str(session.hero_ids[i])
		var stats: Dictionary = stats_for.get(id, Catalog.base_stats(id))
		_spawn_hero(id, stats, i)
	_begin_skill_tracking()


func step(dt: float, moves: Array) -> void:
	if paused or result != "":
		return
	time += dt
	for actor in actors:
		actor.prev = actor.pos
	for shot in shots:
		shot.prev = shot.pos
	for gem in gems:
		gem.prev = gem.pos
	_step_status(dt)
	_move_heroes(dt, moves)
	_step_gems(dt)
	if _halt():
		return
	_step_skills(dt)
	if _halt():
		return
	_step_fields(dt)
	if _halt():
		return
	_hero_attacks()
	if _halt():
		return
	_step_allies(dt)
	if _halt():
		return
	_step_minions(dt)
	if _halt():
		return
	_step_boss(dt)
	if _halt():
		return
	_step_knockback(dt)
	if _halt():
		return
	_step_shots(dt)
	if _halt():
		return
	_step_pings(dt)
	if _halt():
		return
	_separate()
	for actor in actors:
		if actor.alive:
			_clamp_actor(actor)
	if explore:
		_step_shrines(dt)
		_step_explore(dt)
	else:
		_step_spawns(dt)
	_step_gear_pickups()
	_enrage_and_timeout()
	_flush_xp_drops(result != "")
	_compact()


func drain_events() -> Array:
	var out := events
	events = []
	return out


## Reads the run hero's GearDB XP once, so mid-run level crosses can be
## announced from GearDB's totals plus the run's own tally. Read-only: no
## GearDB write ever happens here (the commit still owns the one write).
func _begin_skill_tracking() -> void:
	_skill_base_xp = {}
	_skill_level = {}
	_skill_run_seen = {}
	_xp_drop_total = {}
	_xp_drop_time = {}
	if heroes.is_empty():
		return
	var id := str(heroes[0].sprite)
	for skill in GearDB.SKILL_KEYS:
		var held := GearDB.xp(id, skill)
		_skill_base_xp[skill] = held
		_skill_level[skill] = GearDB.level_for_xp(held)


## Emits xp_drop events for the XP a skill has earned since its last drop. A
## periodic call only fires once XP_DROP_INTERVAL has passed; the final call
## (run end or commit) flushes the remainder, so the drops always total the
## committed XP exactly. The event carries "t", the sim time the drop's window
## closed (the final flush is dated at its interval boundary so spacing holds).
func _flush_xp_drops(final: bool) -> void:
	if heroes.is_empty():
		return
	for skill in GearDB.SKILL_KEYS:
		var target := _skill_run_target(skill)
		var emitted := int(_xp_drop_total.get(skill, 0))
		var delta := target - emitted
		if delta < 1:
			continue
		var last := float(_xp_drop_time.get(skill, -XP_DROP_INTERVAL))
		if not final and time - last < XP_DROP_INTERVAL:
			continue
		var at := time
		if final:
			at = maxf(time, last + XP_DROP_INTERVAL)
		_xp_drop_total[skill] = target
		_xp_drop_time[skill] = at
		events.append({"type": "xp_drop", "skill": skill, "amount": delta, "t": at})
	_flush_skill_levels()


## The XP a skill will have committed, summed across every hero that trained it
## and rounded exactly as _commit_skill_xp does.
func _skill_run_target(skill: String) -> int:
	var total := 0
	for id in skill_xp:
		total += int(round(float(skill_xp[id].get(skill, 0.0))))
	return total


## Announces each level the run hero crosses mid-fight (GearDB's XP plus the
## run tally so far), once per level. Levels are computed, never written.
func _flush_skill_levels() -> void:
	if heroes.is_empty():
		return
	var id := str(heroes[0].sprite)
	var row: Dictionary = skill_xp.get(id, {})
	for skill in GearDB.SKILL_KEYS:
		var amount := int(round(float(row.get(skill, 0.0))))
		if amount == int(_skill_run_seen.get(skill, -1)):
			continue
		_skill_run_seen[skill] = amount
		var reached := GearDB.level_for_xp(int(_skill_base_xp.get(skill, 0)) + amount)
		var seen := int(_skill_level.get(skill, reached))
		while reached > seen:
			seen += 1
			_skill_level[skill] = seen
			events.append({"type": "skill_level", "skill": skill, "level": seen})


## Daily modifier lookup; a modifier may be a name string or a {id, name} dict.
func has_modifier(id: String) -> bool:
	for m in modifiers:
		if typeof(m) == TYPE_DICTIONARY:
			if str(m.get("id", "")) == id:
				return true
		elif str(m) == id:
			return true
	return false


## "Hasty Foes" runs every wild critter 20% faster.
func _foe_speed_mul() -> float:
	return 1.2 if has_modifier("hasty") else 1.0


## The active tier's scaling table (Catalog.TIER_MUL); Normal is all ones, so
## every scaling below leaves a Normal run exactly as it was.
func _diff() -> Dictionary:
	return Catalog.tier_mul(difficulty)


## The map's recommended combat level, for the XP falloff.
func recommended_level() -> int:
	return int(biome.get("recommended_level", Catalog.recommended_level(biome_id)))


## The run hero's OSRS combat level from its committed GearDB skills.
func hero_combat_level() -> int:
	if heroes.is_empty():
		return 1
	return SkillsScreen.combat_level(GearDB.skills(str(heroes[0].sprite)))


## Skill-XP falloff: 1.0 on Veteran/Nightmare and for a hero near the map's
## level; on Normal a hero far above it trains slower. Cached once per run
## (skills do not change mid-fight).
func xp_falloff() -> float:
	if _falloff < 0.0:
		_falloff = Catalog.xp_falloff(hero_combat_level(), recommended_level(), difficulty)
	return _falloff


var _falloff := -1.0


func choose(index: int) -> Array:
	if offer.is_empty():
		return []
	var id := str(offer[clampi(index, 0, offer.size() - 1)])
	var picked := Catalog.card(id)
	if str(picked.get("op", "")) == "heal":
		for hero in heroes:
			if hero.team == 0 and hero.alive:
				hero.hp = minf(hero.max_hp, hero.hp + float(picked.get("n", 20)))
	else:
		stacks[id] = int(stacks.get(id, 0)) + 1
		for hero in heroes:
			if hero.team == 0:
				_recompute(hero)
	offer = []
	offer_queue = maxi(0, offer_queue - 1)
	if offer_queue > 0 and heroes.size() > 0:
		offer = Catalog.roll_offer(str(heroes[0].role), stacks, rng)
		return offer.duplicate()
	paused = false
	return []


func grant_xp(amount: int) -> void:
	_add_xp(amount)


func debug_offer() -> void:
	if heroes.is_empty():
		return
	offer = Catalog.roll_offer(str(heroes[0].role), stacks, rng)
	offer_queue = 1
	paused = true
	events.append({"type": "levelup", "level": level + 1, "offer": offer.duplicate()})


func begin_boss() -> void:
	if phase != "hunt":
		return
	phase = "boss"
	time = maxf(time, Catalog.BOSS_AT)
	_spawn_boss()
	boss_title = _boss_title()
	events.append({"type": "boss_in", "name": boss.display if boss else "Boss", "title": boss_title, "pos": boss.pos if boss != null else map.lair, "shake": 0.5, "stop": 0.06})


func debug_slay_boss() -> void:
	if boss != null and boss.alive:
		_hurt(boss, 999999.0, boss.pos, false, null, false)


## Dodge roll: a short dash with brief invulnerability on a fixed cooldown.
## Cancels an in-progress attack windup and ignores stick input while dashing.
## Returns true when the hero started the dash this call.
func dodge(index: int, dir: Vector2) -> bool:
	if index < 0 or index >= heroes.size():
		return false
	var hero: Actor = heroes[index]
	if not hero.alive or hero.dodge_cd > 0.0:
		return false
	var heading := dir
	if heading.length() < 0.1:
		# facing is an angle: fall back to the hero's nose when idle.
		heading = Vector2.from_angle(hero.facing) if not is_nan(hero.facing) else Vector2.RIGHT
	hero.dodge_dir = heading.normalized()
	hero.dodge_t = DODGE_TIME
	hero.dodge_cd = DODGE_CD
	hero.iframes = maxf(hero.iframes, DODGE_TIME + DODGE_GRACE)
	hero.still = 0.0
	events.append({"type": "dodge", "id": hero.id, "pos": hero.pos, "to": hero.pos + hero.dodge_dir * DODGE_DIST})
	return true


## 1.0 when the dodge is ready, easing back to 0.0 just after it is used
## (readiness fraction; the HUD's cooldown sweep darkens the unused part).
func dodge_ready(index: int) -> float:
	if index < 0 or index >= heroes.size():
		return 0.0
	if heroes[index].dodge_cd <= 0.0:
		return 1.0
	return clampf(1.0 - heroes[index].dodge_cd / DODGE_CD, 0.0, 1.0)


func nearest_hostile(from: Actor, max_range: float) -> Actor:
	var best: Actor = null
	var best_d := max_range
	for actor in actors:
		if not actor.alive or actor == from or actor.team == from.team:
			continue
		var dist := from.pos.distance_to(actor.pos)
		if dist < best_d:
			best = actor
			best_d = dist
	return best


func _spawn_hero(id: String, stats: Dictionary, index: int) -> void:
	var info := Catalog.critter(id)
	var hero := Actor.new()
	hero.id = _nid()
	hero.team = 2 if mode == Session.Mode.DUEL and index > 0 else 0
	hero.kind = "hero"
	hero.sprite = id
	hero.role = str(info.get("role", "mage"))
	hero.display = str(info.get("name", id))
	hero.radius = 32.0
	hero.pos = (map.start if explore else play.get_center()) + Vector2(-70 if index > 0 else 0, 40 if index > 0 else 0)
	hero.prev = hero.pos
	hero.alive = true
	bases[hero.id] = stats.duplicate(true)
	hero.stats = stats.duplicate(true)
	# "Glass": an all-in daily. Bake it into the base stats so card level-ups
	# keep the trade instead of overwriting it on the first _recompute.
	if hero.team == 0 and has_modifier("glass"):
		hero.stats["dmg"] = float(hero.stats["dmg"]) * 1.25
		hero.stats["hp"] = float(hero.stats["hp"]) * 0.75
		bases[hero.id] = hero.stats.duplicate(true)
	_copy_combat(hero)
	hero.hp = hero.max_hp
	actors.append(hero)
	heroes.append(hero)
	if index == 0 and explore:
		_spawn_world()
		_landmark_stones()
	elif index == 0:
		# Open on a pack already closing in, so the first second has a fight.
		_spawn_pack(0, PACK_SIZE, Catalog.WAVES[0]["pool"])


func _copy_combat(hero: Actor) -> void:
	var stats: Dictionary = hero.stats
	var tune: Dictionary = _role_tune(str(hero.role))
	hero.max_hp = float(stats["hp"]) * float(tune.get("hp_mul", 1.0))
	hero.hp = minf(hero.hp if hero.hp > 0.0 else hero.max_hp, hero.max_hp)
	hero.speed = float(stats["speed"])
	hero.dmg = float(stats["dmg"])
	hero.interval = float(stats["interval"])
	hero.range = float(stats["range"]) * float(tune.get("reach_mul", 1.0))
	hero.armor = float(stats["armor"])


## Role tuning for a class, or an empty table for minions and bosses.
func _role_tune(role: String) -> Dictionary:
	return ROLE_TUNING.get(role, {})


## Plant-to-first-shot delay: archers wind up faster than the baseline.
func _plant_time(hero: Actor) -> float:
	return PLANT * float(_role_tune(str(hero.role)).get("windup_mul", 1.0))


func _recompute(hero: Actor) -> void:
	var base: Dictionary = bases[hero.id]
	var dmg_add := 0.0
	var hp_add := 0.0
	var haste := 0.0
	var swift := 0.0
	var crit_add := 0.0
	var regen_add := 0.0
	var magnet_add := 0.0
	var armor_add := 0.0
	var bounce_add := 0
	var shots_add := 0
	var pierce_add := 0
	var splash_add := 0.0
	var splash_mul_add := 0.0
	var thorns_add := 0.0
	var bash_add := 0
	var siphon_add := 0.0
	var revive := 0
	var phoenix := 0
	var skill := {}
	for id in stacks.keys():
		var n := int(stacks[id])
		var card := Catalog.card(str(id))
		var amount := float(card.get("n", 0)) * float(n)
		match str(card.get("op", "")):
			"dmg":
				dmg_add += amount
			"hp":
				hp_add += amount
			"haste":
				haste += amount
			"swift":
				swift += amount
			"crit":
				crit_add += amount
			"regen":
				regen_add += amount
			"magnet":
				magnet_add += amount
			"armor":
				armor_add += amount
			"bounce":
				bounce_add += int(card.get("n", 0)) * n
			"shots":
				shots_add += int(card.get("n", 0)) * n
			"pierce":
				pierce_add += int(card.get("n", 0)) * n
			"splash":
				splash_add += amount
			"splash_mul":
				splash_mul_add += amount
			"thorns":
				thorns_add += amount
			"bash":
				bash_add += int(card.get("n", 0)) * n
			"siphon":
				siphon_add += amount
			"revive":
				revive = 1
			"phoenix":
				phoenix = 1
			"orbit", "chain", "trail", "nova", "aura", "blink", "wolf", "static", "gemburst", "meteor", "volley", "quake", "taunt", "storm":
				skill[str(card.get("op", ""))] = skill.get(str(card.get("op", "")), 0.0) + amount
			"crit_siphon", "ricochet", "execute", "vampkill", "berserk", "mark", "bulwark":
				skill[str(card.get("op", ""))] = skill.get(str(card.get("op", "")), 0.0) + amount
			"split":
				skill["split"] = int(skill.get("split", 0)) + n
				pierce_add += n
	var stats := base.duplicate(true)
	for key in skill.keys():
		stats[str(key)] = skill[key]
	stats["dmg"] = float(base["dmg"]) + dmg_add
	stats["hp"] = float(base["hp"]) + hp_add
	stats["interval"] = maxf(0.16, float(base["interval"]) / (1.0 + haste))
	stats["speed"] = float(base["speed"]) * (1.0 + swift)
	stats["crit"] = minf(0.65, float(base["crit"]) + crit_add)
	stats["regen"] = float(base.get("regen", 0.0)) + regen_add
	stats["magnet"] = float(base["magnet"]) + magnet_add
	stats["armor"] = float(base["armor"]) + armor_add
	stats["bounce"] = int(base["bounce"]) + bounce_add
	stats["shots"] = int(base["shots"]) + shots_add
	stats["pierce"] = int(base["pierce"]) + pierce_add
	stats["splash"] = float(base["splash"]) + splash_add
	stats["splash_mul"] = float(base["splash_mul"]) + splash_mul_add
	stats["thorns"] = minf(0.85, float(base["thorns"]) + thorns_add)
	stats["bash"] = int(base["bash"]) + bash_add
	stats["siphon"] = float(base["siphon"]) + siphon_add
	stats["revive"] = 0 if revive_spent else revive
	stats["phoenix"] = 0 if phoenix_spent else phoenix
	# Shrine buffs sit on top of the rolled stats, so a later level-up
	# (which rebuilds from bases) never wipes a blessing mid-fight.
	for kind in hero.shrine_buffs.keys():
		match str(kind):
			"fury":
				stats["dmg"] = float(stats["dmg"]) * 1.35
			"haste":
				stats["interval"] = maxf(0.16, float(stats["interval"]) / 1.30)
				stats["speed"] = float(stats["speed"]) * 1.30
			"warding":
				stats["armor"] = float(stats["armor"]) + 4.0
			"greed":
				stats["gem_mul"] = float(stats.get("gem_mul", 1.0)) * 1.5
	var old_max := hero.max_hp
	hero.stats = stats
	_copy_combat(hero)
	if hero.max_hp > old_max:
		hero.hp += hero.max_hp - old_max
	hero.hp = minf(hero.hp, hero.max_hp)


## Stick shaping for the player. Heading is the thumb vector with no turn
## smoothing. Speed eases only for a start or a stop, and that ramp is under
## 60ms. A reverse, or any change once already moving, snaps.
static func ease_stick(current: Vector2, want: Vector2, dt: float) -> Vector2:
	# No smoothing: the stick drives velocity directly on the next step.
	# Start and stop feel comes from the visual lean and settle in Stage3D.
	if want.length() > 1.0:
		want = want.normalized()
	return want if want.length() > 0.02 else Vector2.ZERO


func _move_heroes(dt: float, moves: Array) -> void:
	for i in heroes.size():
		var hero: Actor = heroes[i]
		if not hero.alive:
			continue
		var mv := Vector2.ZERO
		if i < moves.size() and moves[i] is Vector2:
			mv = moves[i]
		if mv.length() > 1.0:
			mv = mv.normalized()
		var dashing := hero.dodge_t > 0.0
		var charging := hero.charge_t > 0.0
		if dashing:
			# The roll owns this frame: fixed heading and speed, stick ignored.
			hero.dodge_t = maxf(0.0, hero.dodge_t - dt)
			hero.vel = _slide(hero, hero.dodge_dir * (DODGE_DIST / DODGE_TIME))
		elif charging:
			# The gap-closing leap owns this frame too: fixed heading and speed.
			hero.charge_t = maxf(0.0, hero.charge_t - dt)
			hero.vel = _slide(hero, hero.charge_dir * hero.charge_speed)
		else:
			hero.vel = _slide(hero, mv * hero.speed)
		var was := hero.pos
		hero.pos += hero.vel * dt
		_push_out(hero)
		if explore:
			# Slide along the forest edge; the body's speed is what it really moved.
			hero.pos = map.push_inside(hero.pos, hero.radius * 0.8)
			hero.vel = (hero.pos - was) / maxf(dt, 0.0001)
		if dashing:
			hero.facing = hero.dodge_dir.angle()
			hero.still = 0.0
		elif charging:
			hero.facing = hero.charge_dir.angle()
			hero.still = 0.0
		elif mv.length() > 0.08:
			hero.facing = mv.angle()
			hero.still = 0.0
		else:
			hero.still += dt
		hero.iframes = maxf(0.0, hero.iframes - dt)
		hero.flash = maxf(0.0, hero.flash - dt)
		hero.cd = maxf(0.0, hero.cd - dt)
		hero.dodge_cd = maxf(0.0, hero.dodge_cd - dt)
		hero.charge_cd = maxf(0.0, hero.charge_cd - dt)
		hero.swing_t = maxf(0.0, hero.swing_t - dt)
		var regen := float(hero.stats.get("regen", 0.0))
		if regen > 0.0 and hero.hp < hero.max_hp:
			hero.hp = minf(hero.max_hp, hero.hp + regen * dt)
		_clamp_actor(hero)
		if charging and hero.charge_t <= 0.0:
			_charge_land(hero)


func _hero_attacks() -> void:
	for hero in heroes:
		# Run or fight, never both: no shots and no aim-turning on the move.
		if not hero.alive or hero.cd > 0.0 or hero.still < _plant_time(hero) or hero.dodge_t > 0.0 or hero.charge_t > 0.0:
			continue
		var target := nearest_hostile(hero, hero.range)
		if target == null:
			# Tank: a planted melee hero leaps at a foe just out of reach.
			if hero.role == "tank" and hero.charge_cd <= 0.0:
				var tune: Dictionary = _role_tune("tank")
				var far := nearest_hostile(hero, float(tune.get("charge_range", 300.0)))
				if far != null:
					_start_charge(hero, far)
			continue
		hero.aim = (target.pos - hero.pos).angle()
		hero.facing = hero.aim
		var berserk := float(hero.stats.get("berserk", 0.0))
		var missing := clampf(1.0 - hero.hp / maxf(hero.max_hp, 1.0), 0.0, 1.0)
		hero.cd = hero.interval / (1.0 + berserk * missing)
		hero.atk_count += 1
		events.append({
			"type": "attack",
			"id": hero.id,
			"role": hero.role,
			"pos": hero.pos,
			"facing": hero.aim,
			"range": hero.range,
		})
		if hero.role == "tank":
			hero.swing_t = maxf(hero.swing_t, float(_role_tune("tank").get("swing_dr_time", 0.35)))
			_melee(hero, target)
			if int(hero.stats.get("bash", 0)) > 0:
				_bash(hero)
			var quake := int(hero.stats.get("quake", 0))
			if quake > 0 and rng.randf() < 0.18 + 0.1 * float(quake):
				_quake(hero, quake)
				if result != "":
					return
		else:
			_fan(hero, target)
		var chain := int(hero.stats.get("chain", 0))
		if chain > 0 and hero.atk_count % maxi(2, 5 - chain) == 0:
			_chain(hero, hero.pos, chain, hero.dmg * (0.45 + 0.15 * float(chain)), 280.0)
			if result != "":
				return
		var volley := int(hero.stats.get("volley", 0))
		if volley > 0 and hero.role == "archer" and hero.atk_count % maxi(2, 5 - volley) == 0:
			_volley(hero, target, volley)
			if result != "":
				return
		var static_n := int(hero.stats.get("static", 0))
		if static_n > 0 and hero.still >= 1.0 and float(hero.cds.get("static", 0.0)) <= 0.0:
			hero.cds["static"] = 2.0
			var radius := 80.0 + 15.0 * float(static_n)
			_aoe(hero, hero.pos, radius, hero.dmg * (0.4 + 0.2 * float(static_n)))
			events.append({"type": "fx", "fx": "static_field", "pos": hero.pos, "radius": radius})
			if result != "":
				return


func _melee(hero: Actor, primary: Actor) -> void:
	var crit := rng.randf() < float(hero.stats["crit"])
	var amount := float(hero.stats["dmg"]) * (float(hero.stats["crit_mult"]) if crit else 1.0)
	var ang := (primary.pos - hero.pos).angle()
	var reach := hero.range + 10.0
	var half := 1.2 + float(int(hero.stats.get("shots", 0))) * 0.2
	var cleave := 1.0
	if hero.role == "tank":
		var tune: Dictionary = _role_tune("tank")
		# Never narrower than the shared melee arc: the cleave only widens it.
		half = maxf(half, deg_to_rad(float(tune.get("cleave_arc", 160.0))) * 0.5)
		cleave = float(tune.get("cleave_mul", 0.65))
	var hits := 0
	for actor in actors:
		if not actor.alive or actor.team == hero.team:
			continue
		var delta := actor.pos - hero.pos
		var dist := delta.length()
		if dist > reach + actor.radius:
			continue
		var point_blank := dist < hero.radius + actor.radius + 20.0
		if not point_blank and dist > 0.01 and absf(wrapf(delta.angle() - ang, -PI, PI)) > half:
			continue
		# Cleave: the chosen target takes it all, the rest of the arc less.
		var dmg := amount if actor == primary else amount * cleave
		_hurt(actor, dmg, hero.pos, crit, hero, false)
		hits += 1
		if result != "":
			return
	events.append({"type": "swing", "pos": hero.pos, "facing": ang, "range": reach})
	if hero.role == "tank" and hits > 0:
		events.append({
			"type": "cleave",
			"id": hero.id,
			"pos": hero.pos,
			"facing": ang,
			"range": reach,
			"stop": 0.055 if crit else 0.04,
			"shake": 0.3 if crit else 0.16,
		})


## Queue a tank's melee shove: a normal foe is pushed melee_kb px away over
## melee_kb_time seconds, while a boss or elite only jolts a few px. The shove
## itself is resolved by _step_knockback, which keeps the body out of stones and
## inside the map, so nothing is knocked through a wall or off the nav area.
func _melee_knockback(target: Actor, dir: Vector2) -> void:
	var tune: Dictionary = _role_tune("tank")
	var dist := float(tune.get("melee_kb", 28.0))
	if target.kind == "boss" or target.elite:
		dist = float(tune.get("melee_kb_elite", 5.0))
	var beat := maxf(0.01, float(tune.get("melee_kb_time", 0.12)))
	target.kb_dir = dir
	target.kb_left = dist
	target.kb_rate = dist / beat


## Advance every live melee shove. The push slides out of any stone it meets and
## stays on the walkable map, so a shoved foe can never be forced into geometry.
func _step_knockback(dt: float) -> void:
	for actor in actors:
		if not actor.alive or actor.kb_left <= 0.0:
			continue
		var move := minf(actor.kb_left, actor.kb_rate * dt)
		actor.kb_left = maxf(0.0, actor.kb_left - move)
		actor.pos += actor.kb_dir * move
		_push_out(actor)
		if explore:
			actor.pos = map.push_inside(actor.pos, actor.radius * 0.8)
		actor.pos = _clamp_point(actor.pos, actor.radius)
		if actor.kb_left <= 0.0:
			actor.kb_rate = 0.0


## A melee crit or kill asks the run screen for one short freeze. Rate-limited
## to HITSTOP_CD of sim time so a flurry of crits reads as impact, not stutter;
## the screen skips sim steps for the beat instead of scaling Engine.time_scale.
func _melee_hitstop() -> void:
	if time - _hitstop_at < HITSTOP_CD:
		return
	_hitstop_at = time
	events.append({"type": "hitstop", "stop": HITSTOP_FREEZE, "shake": 0.3})


## Tank gap-closer: dash onto a foe just out of reach. The leap owns movement
## for `charge_time`, then staggers everything under the landing.
func _start_charge(hero: Actor, foe: Actor) -> void:
	var tune: Dictionary = _role_tune("tank")
	var dist := hero.pos.distance_to(foe.pos)
	if dist < 1.0:
		return
	var time := float(tune.get("charge_time", 0.16))
	hero.charge_dir = (foe.pos - hero.pos).normalized()
	hero.charge_t = time
	hero.charge_speed = dist / maxf(time, 0.001)
	hero.charge_cd = float(tune.get("charge_cd", 3.5))
	hero.facing = hero.charge_dir.angle()
	hero.still = 0.0
	events.append({"type": "charge", "id": hero.id, "pos": hero.pos, "to": foe.pos, "shake": 0.18})


func _charge_land(hero: Actor) -> void:
	var tune: Dictionary = _role_tune("tank")
	var radius := float(tune.get("charge_aoe", 78.0))
	var stun := float(tune.get("charge_stun", 0.35))
	for actor in actors:
		if not actor.alive or actor.team == hero.team:
			continue
		if actor.pos.distance_to(hero.pos) > radius + actor.radius:
			continue
		actor.stun = maxf(actor.stun, stun)
		actor.slow = maxf(actor.slow, stun)
		actor.slow_k = maxf(actor.slow_k, 0.25)
	events.append({"type": "charge_land", "pos": hero.pos, "radius": radius, "shake": 0.22, "stop": 0.04})


func _fan(hero: Actor, target: Actor) -> void:
	var count := 1 + int(hero.stats.get("shots", 0))
	var aim := target.pos
	var flight := float(hero.stats["proj_speed"])
	if flight > 1.0:
		var travel := clampf(hero.pos.distance_to(target.pos) / flight, 0.0, 0.42)
		aim = target.pos + target.vel * travel
	var base := (aim - hero.pos).angle()
	# Archer: shots past 60% of range hit harder and punch through one more.
	var range_mul := 1.0
	var extra_pierce := 0
	if hero.role == "archer":
		var atune: Dictionary = _role_tune("archer")
		if hero.pos.distance_to(target.pos) > hero.range * float(atune.get("long_frac", 0.6)):
			range_mul = 1.0 + float(atune.get("long_bonus", 0.25))
			extra_pierce = 1
	# Mage: every 4th cast is a bigger, wider burst.
	var burst := false
	if hero.role == "mage":
		var mtune: Dictionary = _role_tune("mage")
		var every := int(mtune.get("burst_every", 4))
		burst = every > 0 and hero.atk_count % every == 0
	for i in count:
		var ang := base
		if count > 1:
			ang += lerpf(-0.22, 0.22, float(i) / float(count - 1))
		var crit := rng.randf() < float(hero.stats["crit"])
		var amount := float(hero.stats["dmg"]) * range_mul * (float(hero.stats["crit_mult"]) if crit else 1.0)
		var dir := Vector2.RIGHT.rotated(ang)
		var shot := Shot.new()
		shot.team = hero.team
		shot.owner_id = hero.id
		shot.pos = hero.pos + dir * (hero.radius + 8.0)
		shot.prev = shot.pos
		shot.vel = dir * float(hero.stats["proj_speed"])
		shot.dmg = amount
		shot.crit = crit
		shot.radius = 14.0 if hero.role == "mage" else 8.0
		shot.ttl = 1.45
		shot.pierce = int(hero.stats["pierce"]) + extra_pierce
		shot.bounce = int(hero.stats["bounce"])
		shot.kind = "orb" if hero.role == "mage" else "arrow"
		shot.split = int(hero.stats.get("split", 0)) if hero.role == "mage" else 0
		if hero.role == "mage":
			var mtune: Dictionary = _role_tune("mage")
			var splash := float(hero.stats["splash"])
			var splash_mul := float(hero.stats["splash_mul"])
			if burst:
				splash *= float(mtune.get("burst_mul", 1.6))
				splash_mul *= float(mtune.get("burst_mul", 1.6))
			shot.splash = splash
			shot.splash_mul = splash_mul
		else:
			shot.splash = 0.0
			shot.splash_mul = float(hero.stats["splash_mul"])
		shots.append(shot)


func _bash(hero: Actor) -> void:
	var stacks_n := int(hero.stats["bash"])
	var dir := Vector2.RIGHT.rotated(hero.aim)
	var shot := Shot.new()
	shot.team = hero.team
	shot.owner_id = hero.id
	shot.pos = hero.pos + dir * (hero.radius + 8.0)
	shot.prev = shot.pos
	shot.vel = dir * 480.0
	shot.dmg = float(hero.stats["dmg"]) * (0.42 + 0.16 * float(stacks_n))
	shot.radius = 16.0
	shot.ttl = 0.32
	shot.splash = 36.0 + 12.0 * float(stacks_n)
	shot.splash_mul = 1.0
	shot.kind = "bash"
	shots.append(shot)


## Damage every hostile in a circle. All skill damage funnels through _hurt so
## hit numbers, flash, thorns and kill credit stay consistent.
func _aoe(attacker: Actor, at: Vector2, radius: float, amount: float, crit := false) -> void:
	for actor in actors:
		if not actor.alive or actor.team == attacker.team:
			continue
		if actor.pos.distance_to(at) > radius + actor.radius * 0.5:
			continue
		_hurt(actor, amount, at, crit, attacker, false)
		if result != "":
			return


## Arc lightning from `from`, hopping to the nearest hostile not yet struck.
func _chain(hero: Actor, from: Vector2, jumps: int, amount: float, hop: float) -> void:
	var src := from
	var hit := {}
	for _j in jumps:
		var best: Actor = null
		var best_d := hop
		for actor in actors:
			if not actor.alive or actor.team == hero.team or hit.has(actor.id):
				continue
			var dist := src.distance_to(actor.pos)
			if dist < best_d:
				best = actor
				best_d = dist
		if best == null:
			return
		hit[best.id] = true
		events.append({"type": "fx", "fx": "chain_lightning", "pos": src, "to": best.pos})
		_hurt(best, amount, src, false, hero, false)
		if result != "":
			return
		src = best.pos


func _quake(hero: Actor, n: int) -> void:
	var radius := 100.0 + 15.0 * float(n)
	for actor in actors:
		if not actor.alive or actor.team == hero.team:
			continue
		if actor.pos.distance_to(hero.pos) > radius + actor.radius:
			continue
		actor.stun = maxf(actor.stun, 0.45 + 0.15 * float(n))
		_hurt(actor, hero.dmg * (0.15 + 0.1 * float(n)), hero.pos, false, hero, false)
		if result != "":
			return
	events.append({"type": "fx", "fx": "earthquake", "pos": hero.pos, "radius": radius})


func _volley(hero: Actor, target: Actor, n: int) -> void:
	var count := 3 + n
	var base := (target.pos - hero.pos).angle()
	for i in count:
		var ang := base + lerpf(-0.5, 0.5, float(i) / float(count - 1))
		var dir := Vector2.RIGHT.rotated(ang)
		var crit := rng.randf() < float(hero.stats["crit"])
		var amount := hero.dmg * 0.55 * (float(hero.stats["crit_mult"]) if crit else 1.0)
		var shot := Shot.new()
		shot.team = hero.team
		shot.owner_id = hero.id
		shot.pos = hero.pos + dir * (hero.radius + 8.0)
		shot.prev = shot.pos
		shot.vel = dir * float(hero.stats["proj_speed"])
		shot.dmg = amount
		shot.crit = crit
		shot.radius = 8.0
		shot.ttl = 1.3
		shot.kind = "arrow"
		shots.append(shot)
	events.append({"type": "fx", "fx": "volley", "pos": hero.pos, "to": target.pos})


func _slow_mul(actor: Actor) -> float:
	return 1.0 - clampf(actor.slow_k, 0.0, 0.7)


func _step_status(dt: float) -> void:
	for actor in actors:
		if not actor.alive:
			continue
		actor.slow = maxf(0.0, actor.slow - dt)
		if actor.slow <= 0.0:
			actor.slow_k = 0.0
		actor.stun = maxf(0.0, actor.stun - dt)
		actor.mark = maxf(0.0, actor.mark - dt)
		actor.weaken = maxf(0.0, actor.weaken - dt)
		for key in actor.cds.keys():
			actor.cds[key] = maxf(0.0, float(actor.cds[key]) - dt)


## Per-hero skill timers: orbit blades, trail drops, nova/aura pulses, summons,
## meteor, taunt and storm. All dt-driven so a run stays deterministic.
func _step_skills(dt: float) -> void:
	for hero in heroes:
		if not hero.alive:
			continue
		var stats := hero.stats
		var orbit := int(stats.get("orbit", 0))
		if orbit > 0:
			_step_orbit(hero, orbit, dt)
			if result != "":
				return
		var trail := int(stats.get("trail", 0))
		if trail > 0 and hero.vel.length() > 40.0 and float(hero.cds.get("trail", 0.0)) <= 0.0:
			hero.cds["trail"] = 0.32
			_drop_field(hero, hero.pos, 34.0 + 6.0 * float(trail), hero.dmg * (0.12 + 0.05 * float(trail)), 2.2 + 0.4 * float(trail), 0.35, "fire_trail")
		var nova := int(stats.get("nova", 0))
		if nova > 0 and float(hero.cds.get("nova", 0.0)) <= 0.0:
			hero.cds["nova"] = maxf(2.5, 6.5 - 1.2 * float(nova))
			var nr := 110.0 + 25.0 * float(nova)
			for actor in actors:
				if not actor.alive or actor.team == hero.team:
					continue
				if actor.pos.distance_to(hero.pos) > nr + actor.radius:
					continue
				actor.slow = maxf(actor.slow, 1.6 + 0.3 * float(nova))
				actor.slow_k = maxf(actor.slow_k, minf(0.65, 0.3 + 0.1 * float(nova)))
				_hurt(actor, hero.dmg * (0.35 + 0.15 * float(nova)), hero.pos, false, hero, false)
				if result != "":
					return
			events.append({"type": "fx", "fx": "frost_nova", "pos": hero.pos, "radius": nr})
		var aura := int(stats.get("aura", 0))
		if aura > 0 and float(hero.cds.get("aura", 0.0)) <= 0.0:
			hero.cds["aura"] = maxf(1.2, 2.8 - 0.5 * float(aura))
			var ar := 90.0 + 20.0 * float(aura)
			_aoe(hero, hero.pos, ar, hero.dmg * (0.3 + 0.12 * float(aura)))
			events.append({"type": "fx", "fx": "thorns_aura", "pos": hero.pos, "radius": ar})
			if result != "":
				return
		var wolf := int(stats.get("wolf", 0))
		if wolf > 0:
			_step_wolves(hero, wolf)
		var meteor := int(stats.get("meteor", 0))
		if meteor > 0 and float(hero.cds.get("meteor", 0.0)) <= 0.0:
			var foe := nearest_hostile(hero, 520.0)
			if foe != null:
				hero.cds["meteor"] = maxf(3.0, 6.5 - 0.8 * float(meteor))
				var at := foe.pos + Vector2(rng.randf_range(-40.0, 40.0), rng.randf_range(-30.0, 30.0))
				_drop_field(hero, at, 100.0 + 20.0 * float(meteor), hero.dmg * (2.0 + 0.8 * float(meteor)), 0.06, 0.12, "meteor", 0.85)
		var taunt := int(stats.get("taunt", 0))
		if taunt > 0 and float(hero.cds.get("taunt", 0.0)) <= 0.0:
			hero.cds["taunt"] = maxf(3.0, 7.0 - 1.0 * float(taunt))
			var tr := 150.0 + 25.0 * float(taunt)
			for actor in actors:
				if not actor.alive or actor.team == hero.team:
					continue
				if actor.pos.distance_to(hero.pos) > tr + actor.radius:
					continue
				actor.weaken = maxf(actor.weaken, 2.0 + 0.3 * float(taunt))
				var to := hero.pos - actor.pos
				if to.length() > 1.0:
					actor.pos += to.normalized() * minf(26.0, to.length() * 0.12)
			events.append({"type": "fx", "fx": "taunt_roar", "pos": hero.pos, "radius": tr})
		var storm := int(stats.get("storm", 0))
		if storm > 0 and float(hero.cds.get("storm", 0.0)) <= 0.0:
			hero.cds["storm"] = maxf(1.0, 2.4 - 0.3 * float(storm))
			_chain(hero, hero.pos, 1 + storm, hero.dmg * (0.25 + 0.1 * float(storm)), 300.0)
			events.append({"type": "fx", "fx": "storm_crown", "pos": hero.pos})
			if result != "":
				return


func _step_orbit(hero: Actor, n: int, dt: float) -> void:
	hero.blade_ang = fmod(hero.blade_ang + dt * (2.4 + 0.25 * float(n)), TAU)
	var radius := 68.0 + 8.0 * float(n)
	for key in hero.blade_cd.keys():
		hero.blade_cd[key] = maxf(0.0, float(hero.blade_cd[key]) - dt)
	for i in n:
		var ang := hero.blade_ang + TAU * float(i) / float(n)
		var bp := hero.pos + Vector2.from_angle(ang) * radius
		for actor in actors:
			if not actor.alive or actor.team == hero.team:
				continue
			if actor.pos.distance_to(bp) > 20.0 + actor.radius:
				continue
			if float(hero.blade_cd.get(actor.id, 0.0)) > 0.0:
				continue
			hero.blade_cd[actor.id] = 0.45
			_hurt(actor, hero.dmg * (0.2 + 0.1 * float(n)), bp, false, hero, false)
			events.append({"type": "fx", "fx": "orbiting_blades", "pos": bp})
			if result != "":
				return


func _drop_field(hero: Actor, at: Vector2, radius: float, dmg: float, life: float, tick: float, kind: String, delay := 0.0) -> void:
	if fields.size() > 48:
		fields.remove_at(0)
	var f := Field.new()
	f.pos = at
	f.radius = radius
	f.life = life
	f.delay = delay
	f.dmg = dmg
	f.tick = tick
	f.tick_cd = 0.0
	f.team = hero.team
	f.owner_id = hero.id
	f.kind = kind
	fields.append(f)
	events.append({"type": "fx", "fx": kind, "pos": at, "radius": radius})


func _step_fields(dt: float) -> void:
	for f in fields:
		if not f.alive:
			continue
		if f.delay > 0.0:
			f.delay -= dt
			if f.delay > 0.0:
				continue
		f.life -= dt
		f.tick_cd -= dt
		if f.tick_cd <= 0.0:
			f.tick_cd = f.tick
			var owner := _actor_by_id(f.owner_id)
			for actor in actors:
				if not actor.alive or actor.team == f.team:
					continue
				if actor.pos.distance_to(f.pos) > f.radius + actor.radius * 0.4:
					continue
				if f.kind == "orb_slow":
					actor.slow = maxf(actor.slow, 0.6)
					actor.slow_k = maxf(actor.slow_k, 0.35)
				if f.dmg > 0.0:
					_hurt(actor, f.dmg, f.pos, false, owner, false)
				if result != "":
					return
			events.append({"type": "fx", "fx": f.kind, "pos": f.pos, "radius": f.radius})
		if f.life <= 0.0:
			f.alive = false


func _step_wolves(hero: Actor, n: int) -> void:
	var keep: Array = []
	for id in hero.summon_ids:
		var a := _actor_by_id(int(id))
		if a != null and a.alive and a.kind == "ally":
			keep.append(int(id))
	hero.summon_ids = keep
	if keep.size() >= n or float(hero.cds.get("wolf", 0.0)) > 0.0:
		return
	hero.cds["wolf"] = 3.0
	var a := Actor.new()
	a.id = _nid()
	a.team = hero.team
	a.kind = "ally"
	a.sprite = "spirit_wolf"
	a.display = "Spectral Hound"
	a.radius = 22.0
	a.pos = _clamp_point(hero.pos + Vector2.RIGHT.rotated(rng.randf() * TAU) * 64.0, 24.0)
	a.prev = a.pos
	a.speed = 300.0
	a.max_hp = 34.0 + 26.0 * float(n)
	a.hp = a.max_hp
	a.dmg = hero.dmg * (0.3 + 0.12 * float(n))
	a.interval = 0.62
	a.range = 66.0
	a.cd = 0.25
	a.owner_hero = hero.id
	actors.append(a)
	hero.summon_ids.append(a.id)
	events.append({"type": "fx", "fx": "spirit_wolf", "pos": a.pos})


func _step_allies(dt: float) -> void:
	for a in actors:
		if not a.alive or a.kind != "ally":
			continue
		a.flash = maxf(0.0, a.flash - dt)
		a.cd = maxf(0.0, a.cd - dt)
		a.touch_cd = maxf(0.0, a.touch_cd - dt)
		if a.stun > 0.0:
			a.vel = Vector2.ZERO
			continue
		var foe := nearest_hostile(a, 1400.0)
		if foe == null:
			var owner := _actor_by_id(a.owner_hero)
			if owner != null and owner.alive and a.pos.distance_to(owner.pos) > 90.0:
				var to := owner.pos - a.pos
				a.vel = to.normalized() * a.speed * _slow_mul(a)
				a.pos += a.vel * dt
				a.facing = a.vel.angle()
			else:
				a.vel = Vector2.ZERO
			continue
		var delta := foe.pos - a.pos
		var dist := delta.length()
		var dir := delta / dist if dist > 0.001 else Vector2.RIGHT
		a.facing = dir.angle()
		if dist > a.range + foe.radius + 4.0:
			a.vel = _steer(a, dir * a.speed * _slow_mul(a))
			a.pos += a.vel * dt
		else:
			a.vel = Vector2.ZERO
			if a.cd <= 0.0:
				a.cd = a.interval
				_hurt(foe, a.dmg, a.pos, false, a, true)
				events.append({"type": "fx", "fx": "spirit_wolf", "pos": foe.pos})
				if result != "":
					return
		_push_out(a)
		if explore:
			a.pos = map.push_inside(a.pos, a.radius * 0.8)


func _step_minions(dt: float) -> void:
	var target := _focus_hero()
	if target == null:
		return
	for actor in actors:
		if not actor.alive or actor.kind != "minion":
			continue
		if actor.kb_left > 0.0:
			# A melee shove owns the body for its beat; the AI resumes after.
			actor.vel = Vector2.ZERO
			continue
		if actor.goblin:
			_step_goblin(actor, dt, target)
			continue
		actor.flash = maxf(0.0, actor.flash - dt)
		actor.touch_cd = maxf(0.0, actor.touch_cd - dt)
		actor.cd = maxf(0.0, actor.cd - dt)
		if actor.stun > 0.0:
			actor.vel = Vector2.ZERO
			continue
		# While the boss rises, its lair guards hold their ground with it.
		if explore and boss != null and boss.boss_state == "intro" and actor.pos.distance_to(map.lair) < map.lair_r + 200.0:
			actor.vel = Vector2.ZERO
			continue
		var spd := actor.speed * _slow_mul(actor)
		var delta := target.pos - actor.pos
		var dist := delta.length()
		var dir := delta / dist if dist > 0.001 else Vector2.RIGHT
		if explore:
			if not actor.aggro:
				_idle_minion(actor, dt, dist)
				continue
			if actor.pos.distance_to(actor.home) > LEASH and dist > 700.0:
				# Leashed: give up and walk home.
				_set_camp_aggro(actor, false)
				continue
			if dist > 240.0:
				var way := _chase_point(actor, target)
				var to := way - actor.pos
				if to.length() > 1.0:
					dir = to.normalized()
		actor.facing = dir.angle()
		if actor.archetype == "shooter":
			if actor.windup > 0.0:
				# Brace and wind up; the shot leaves on the release frame.
				actor.vel = Vector2.ZERO
				actor.windup -= dt
				if actor.windup <= 0.0:
					_enemy_shot(actor, target, actor.dmg, actor.shot_speed)
					events.append({"type": "attack", "id": actor.id})
					actor.cd = actor.interval
			else:
				if dist > actor.range:
					actor.vel = dir * spd
				elif dist < actor.range * (0.36 if explore else 0.55):
					# Backpedal only when crowded: a melee hero must be able
					# to close in on a shooter (it used to hold just out of reach).
					actor.vel = -dir * spd
				else:
					actor.vel = Vector2(-dir.y, dir.x) * spd * 0.6
				actor.vel = _steer(actor, actor.vel)
				actor.pos += actor.vel * dt
				if dist <= actor.range and actor.cd <= 0.0:
					actor.windup = SHOOT_WINDUP
					events.append({"type": "windup", "id": actor.id, "time": SHOOT_WINDUP})
		else:
			actor.vel = _steer(actor, dir * spd)
			actor.pos += actor.vel * dt
		_push_out(actor)
		if explore:
			actor.pos = map.push_inside(actor.pos, actor.radius * 0.8)
		if actor.pos.distance_to(target.pos) < actor.radius + target.radius and actor.touch_cd <= 0.0:
			actor.touch_cd = 0.74
			events.append({"type": "attack", "id": actor.id})
			_hurt(target, actor.dmg, actor.pos, false, actor, true)
			if result != "":
				return


func _step_boss(dt: float) -> void:
	if boss == null or not boss.alive:
		return
	boss.flash = maxf(0.0, boss.flash - dt)
	boss.boss_timer -= dt
	boss.touch_cd = maxf(0.0, boss.touch_cd - dt)
	boss.charge_cd = maxf(0.0, boss.charge_cd - dt)
	_check_phase2()
	if boss.stun > 0.0:
		boss.vel = Vector2.ZERO
		_clamp_actor(boss)
		return
	if boss.kb_left > 0.0:
		# A shove moves the boss for a beat; its action timers keep ticking.
		boss.vel = Vector2.ZERO
		_clamp_actor(boss)
		return
	if boss.boss_state == "intro":
		# Planted and silent while the reveal plays; the hero moves freely.
		boss.vel = Vector2.ZERO
		if boss.boss_timer <= 0.0:
			boss.boss_state = "idle"
			boss.boss_timer = 0.9
		_clamp_actor(boss)
		return
	if boss.boss_state == "roar":
		# The enrage roar: planted, silent and untouchable for its window,
		# then the phase-2 pattern opens on the first attack back.
		boss.vel = Vector2.ZERO
		if boss.boss_timer <= 0.0:
			boss.boss_state = "idle"
			boss.boss_timer = 0.2
			boss.phase2_pending = true
		_clamp_actor(boss)
		return
	var bspd := boss.speed * _slow_mul(boss)
	if boss.boss_state == "idle":
		var focus := _focus_hero()
		if focus != null:
			var delta := focus.pos - boss.pos
			var d := delta.length()
			if d > 168.0:
				var heading := delta.normalized()
				# While it is closing to open, follow the trail so it does
				# not wedge in the lair's standing stones.
				if _boss_approaching() and not _flow.is_empty():
					var way := _chase_point(boss, focus)
					var to := way - boss.pos
					if to.length() > 1.0:
						heading = to.normalized()
				var want := heading * bspd
				# Unstick: no real progress for half a second means a stone
				# or a wall is in the way, so sidestep along it for a beat.
				boss.stall_t += dt
				if d < boss.best_d - 14.0:
					boss.best_d = d
					boss.stall_t = 0.0
				if boss.stall_t > 0.5 and boss.side_t <= 0.0:
					boss.side_t = 0.6
					boss.side_dir = _open_side(boss, delta.normalized())
					boss.stall_t = 0.0
					boss.best_d = d
				if boss.side_t > 0.0:
					boss.side_t -= dt
					want = (boss.side_dir * 0.85 + delta.normalized() * 0.3).normalized() * bspd
				# Heavy and smooth: velocity eases toward the steered heading
				# (about a quarter second to turn) and the body turns after it.
				boss.vel = boss.vel.lerp(_steer(boss, want), 1.0 - exp(-7.0 * dt))
				boss.pos += boss.vel * dt
				_push_out(boss)
				if explore:
					# Never into the trees: the lair's open ground holds it.
					boss.pos = map.push_inside(boss.pos, boss.radius * 0.6)
				if boss.vel.length() > 8.0:
					boss.facing = lerp_angle(boss.facing, boss.vel.angle(), 1.0 - exp(-9.0 * dt))
			else:
				boss.vel = boss.vel.lerp(Vector2.ZERO, 1.0 - exp(-10.0 * dt))
				boss.pos += boss.vel * dt
				boss.facing = lerp_angle(boss.facing, delta.angle(), 1.0 - exp(-9.0 * dt))
				boss.best_d = d
				boss.stall_t = 0.0
		# No telegraph until the hero and the boss share the frame: if the
		# boss is still far off, the idle walk above closes the gap first.
		if boss.boss_timer <= 0.0 and (boss_opened or _boss_engage()):
			_begin_attack()
	elif boss.boss_state == "windup":
		boss.vel = Vector2.ZERO
		if boss.boss_timer <= 0.0:
			_release_attack()
	elif boss.boss_state == "act":
		if boss.attack == "charge":
			var dash := 680.0 if enraged else 560.0
			boss.vel = boss.boss_dir * dash
			var before := boss.pos + boss.vel * dt
			boss.pos = before
			_push_out(boss)
			if explore:
				boss.pos = map.push_inside(boss.pos, boss.radius * 0.6)
			var clamped := _clamp_point(boss.pos, boss.radius)
			boss.facing = boss.boss_dir.angle()
			if boss.pos.distance_to(before) > 2.0 or clamped.distance_to(boss.pos) > 2.0:
				# Slammed into a stone or the arena edge: end the charge.
				boss.boss_timer = 0.0
			for hero in heroes:
				if hero.alive and boss.pos.distance_to(hero.pos) < boss.radius * 0.82 + hero.radius and boss.charge_cd <= 0.0:
					boss.charge_cd = 0.38
					_hurt(hero, boss.charge_dmg * _rage(), boss.pos, false, boss, true)
					if result != "":
						return
		if boss.boss_timer <= 0.0:
			boss.boss_state = "recover"
			# Phase 2 strikes 20% faster: the between-attack beats shorten.
			boss.boss_timer = (0.42 if enraged else 0.55) / boss.atk_speed
	elif boss.boss_state == "recover":
		if boss.boss_timer <= 0.0:
			boss.boss_state = "idle"
			boss.boss_timer = (0.18 if enraged else 0.42) / boss.atk_speed
	if boss.boss_state != "act" or boss.attack != "charge":
		for hero in heroes:
			if hero.alive and boss.pos.distance_to(hero.pos) < boss.radius * 0.78 + hero.radius and boss.touch_cd <= 0.0:
				boss.touch_cd = 0.85
				_hurt(hero, boss.dmg * _rage(), boss.pos, false, boss, true)
				if result != "":
					return
	_clamp_actor(boss)
	_boss_gems()


func _begin_attack() -> void:
	boss_opened = true
	if boss.phase2_pending:
		# Phase 2 opens with its archetype pattern, then folds into the mix.
		boss.phase2_pending = false
		boss.attack = _phase2_attack()
	else:
		boss.attack = _pick_attack()
	boss.boss_state = "windup"
	events.append({"type": "windup", "id": boss.id, "time": 0.6})
	var focus := _focus_hero()
	if focus == null:
		boss.boss_state = "idle"
		boss.boss_timer = 0.4
		return
	if boss.attack == "aoe":
		boss.boss_timer = 0.76
		var lead := focus.vel * 0.32
		_circle(focus.pos, 88.0, 0.76, boss.aoe_dmg * _rage())
		_circle(focus.pos + lead + Vector2(rng.randf_range(-36, 36), rng.randf_range(-24, 24)), 76.0, 0.76, boss.aoe_dmg * _rage())
		if enraged:
			_circle(focus.pos + Vector2(70, -20), 68.0, 0.76, boss.aoe_dmg * _rage())
	elif boss.attack == "charge":
		boss.boss_timer = 0.5
		var dir := focus.pos - boss.pos
		boss.boss_dir = dir.normalized() if dir.length() > 1.0 else Vector2.DOWN
		var ping := Ping.new()
		ping.kind = "lane"
		ping.pos = boss.pos
		ping.dir = boss.boss_dir
		ping.length = 340.0
		ping.width = boss.radius * 0.92
		ping.life = 0.5
		ping.max_life = 0.5
		pings.append(ping)
	elif boss.attack == "slam":
		# Melee phase 2: a ground-slam ring, telegraphed long enough to roll out.
		boss.boss_timer = BOSS_PHASE_TELEGRAPH
		var at := focus.pos + focus.vel * 0.18
		_circle(at, 130.0, BOSS_PHASE_TELEGRAPH, boss.aoe_dmg * 0.7 * _rage())
	elif boss.attack == "fan2":
		# Ranged phase 2: the five-shot fan, with the same long telegraph.
		boss.boss_timer = BOSS_PHASE_TELEGRAPH
		var base2 := (focus.pos - boss.pos).angle()
		boss.boss_dir = Vector2.RIGHT.rotated(base2)
		for i in 5:
			var ping2 := Ping.new()
			ping2.kind = "lane"
			ping2.dir = Vector2.RIGHT.rotated(base2 + lerpf(-0.58, 0.58, float(i) / 4.0))
			ping2.pos = boss.pos + ping2.dir * boss.radius * 0.7
			ping2.length = 340.0
			ping2.width = 22.0
			ping2.life = BOSS_PHASE_TELEGRAPH
			ping2.max_life = BOSS_PHASE_TELEGRAPH
			pings.append(ping2)
	else:
		# Fan: five thin lanes show where the volley will fly.
		boss.boss_timer = 0.55
		var base := (focus.pos - boss.pos).angle()
		boss.boss_dir = Vector2.RIGHT.rotated(base)
		for i in 5:
			var ping := Ping.new()
			ping.kind = "lane"
			ping.dir = Vector2.RIGHT.rotated(base + lerpf(-0.58, 0.58, float(i) / 4.0))
			ping.pos = boss.pos + ping.dir * boss.radius * 0.7
			ping.length = 300.0
			ping.width = 22.0
			ping.life = 0.55
			ping.max_life = 0.55
			pings.append(ping)


func _release_attack() -> void:
	events.append({"type": "attack", "id": boss.id})
	boss.boss_state = "act"
	if boss.attack == "charge":
		boss.boss_timer = 0.38
		boss.charge_cd = 0.0
		return
	if boss.attack == "fan" or boss.attack == "fan2":
		boss.boss_timer = 0.42
		# Fire along the lanes that were telegraphed.
		var base := boss.boss_dir.angle()
		for i in 5:
			var ang := base + lerpf(-0.58, 0.58, float(i) / 4.0)
			var dir := Vector2.RIGHT.rotated(ang)
			var shot := Shot.new()
			shot.team = boss.team
			shot.owner_id = boss.id
			shot.pos = boss.pos + dir * (boss.radius * 0.7)
			shot.prev = shot.pos
			shot.vel = dir * (320.0 if enraged else 255.0)
			shot.dmg = boss.shot_dmg * _rage() * (0.8 if boss.attack == "fan2" else 1.0)
			shot.radius = 11.0
			shot.ttl = 2.5
			shot.kind = "enemy"
			shots.append(shot)
		return
	boss.boss_timer = 0.12


func _pick_attack() -> String:
	# Once enraged the archetype pattern stays in the mix on top of the base
	# three, so phase 2 reads as a new move rather than a one-off.
	if boss.phase2 and rng.randf() < 0.2:
		return _phase2_attack()
	var roll := rng.randf()
	if roll < boss.bias_charge:
		return "charge"
	if roll < boss.bias_charge + boss.bias_aoe:
		return "aoe"
	return "fan"


func _circle(at: Vector2, radius: float, life: float, dmg: float) -> void:
	var ping := Ping.new()
	ping.kind = "circle"
	ping.pos = _clamp_point(at, 20.0)
	ping.radius = radius
	ping.life = life
	ping.max_life = life
	ping.dmg = dmg
	pings.append(ping)


func _step_shots(dt: float) -> void:
	var spawned: Array = []
	for shot in shots:
		if not shot.alive:
			continue
		shot.ttl -= dt
		shot.pos += shot.vel * dt
		if shot.ttl <= 0.0 or not play.grow(90.0).has_point(shot.pos):
			shot.alive = false
			continue
		for actor in actors:
			if not shot.alive:
				break
			if not actor.alive or actor.team == shot.team:
				continue
			if actor.id in shot.hit_ids:
				continue
			if shot.pos.distance_to(actor.pos) > shot.radius + actor.radius:
				continue
			var owner := _actor_by_id(shot.owner_id)
			_hurt(actor, shot.dmg, shot.pos, shot.crit, owner, true)
			shot.hit_ids.append(actor.id)
			if shot.splash > 0.0:
				for other in actors:
					if not other.alive or other == actor or other.team == shot.team:
						continue
					if other.id in shot.hit_ids:
						continue
					if shot.pos.distance_to(other.pos) <= shot.splash + other.radius * 0.25:
						_hurt(other, shot.dmg * shot.splash_mul, shot.pos, shot.crit, owner, false)
						shot.hit_ids.append(other.id)
				events.append({"type": "boom", "pos": shot.pos, "radius": shot.splash, "shake": 0.28, "stop": 0.02})
				# Mage splash chills the ground it lands on.
				if owner != null and owner.kind == "hero" and str(owner.role) == "mage":
					var mtune: Dictionary = _role_tune("mage")
					_drop_field(owner, shot.pos, shot.splash * 0.9, 0.0, float(mtune.get("slow_life", 1.1)), 0.3, "orb_slow")
			if result != "":
				return
			if shot.split > 0 and not shot.did_split:
				shot.did_split = true
				_split_shot(shot, actor, spawned)
			if shot.pierce > 0:
				shot.pierce -= 1
				continue
			if shot.bounce > 0:
				shot.bounce -= 1
				var nxt := _bounce_target(shot)
				if nxt != null:
					var dir := nxt.pos - shot.pos
					if dir.length() > 1.0:
						shot.vel = dir.normalized() * shot.vel.length()
						shot.ttl = maxf(shot.ttl, 0.35)
						break
			var ricochet := 0.0
			if owner != null and owner.kind == "hero":
				ricochet = float(owner.stats.get("ricochet", 0.0))
				# Archer ricochet grows a little with the run's level.
				if str(owner.role) == "archer":
					var atune: Dictionary = _role_tune("archer")
					ricochet += minf(float(atune.get("ricochet_cap", 0.30)), float(atune.get("ricochet_level", 0.015)) * float(level))
			if ricochet > 0.0 and rng.randf() < ricochet:
				var hop := _bounce_target(shot)
				if hop != null:
					var hdir := hop.pos - shot.pos
					if hdir.length() > 1.0:
						shot.vel = hdir.normalized() * shot.vel.length()
						shot.ttl = maxf(shot.ttl, 0.3)
						events.append({"type": "fx", "fx": "ricochet", "pos": shot.pos, "to": hop.pos})
						break
			shot.alive = false
			break
	for extra in spawned:
		shots.append(extra)
	if shots.size() > 56:
		while shots.size() > 48:
			shots.remove_at(0)


## Arcane Orb: on first impact, peel off a short pair of orbs.
func _split_shot(shot: Shot, at: Actor, out: Array) -> void:
	var n := shot.split
	for i in n:
		var ang := shot.vel.angle() + lerpf(-1.0, 1.0, float(i) / float(maxi(1, n - 1)))
		var dir := Vector2.RIGHT.rotated(ang)
		var child := Shot.new()
		child.team = shot.team
		child.owner_id = shot.owner_id
		child.pos = at.pos
		child.prev = at.pos
		child.vel = dir * maxf(shot.vel.length(), 260.0)
		child.dmg = shot.dmg * 0.45
		child.crit = shot.crit
		child.radius = 10.0
		child.ttl = 0.55
		child.kind = "orb"
		child.splash = 0.0
		child.hit_ids = [at.id]
		out.append(child)
	events.append({"type": "fx", "fx": "arcane_split", "pos": at.pos})


func _bounce_target(shot: Shot) -> Actor:
	var best: Actor = null
	var best_d := 560.0
	for actor in actors:
		if not actor.alive or actor.team == shot.team:
			continue
		if actor.id in shot.hit_ids:
			continue
		var dist := shot.pos.distance_to(actor.pos)
		if dist < best_d:
			best = actor
			best_d = dist
	return best


func _step_pings(dt: float) -> void:
	for ping in pings:
		if not ping.alive:
			continue
		ping.life -= dt
		if ping.life > 0.0:
			continue
		ping.alive = false
		if ping.kind != "circle":
			continue
		for hero in heroes:
			if hero.alive and hero.pos.distance_to(ping.pos) <= ping.radius + hero.radius * 0.2:
				_hurt(hero, ping.dmg, ping.pos, false, boss, true)
				if result != "":
					return
		events.append({"type": "boom", "pos": ping.pos, "radius": ping.radius, "shake": 0.8, "stop": 0.055})


func _step_gems(dt: float) -> void:
	for gem in gems:
		if not gem.alive:
			continue
		gem.bob += dt * 5.0
		var hero := _nearest_living_hero(gem.pos)
		if hero == null:
			continue
		var delta := hero.pos - gem.pos
		var dist := delta.length()
		var magnet := float(hero.stats.get("magnet", 56.0))
		if dist < magnet and dist > 0.001:
			var pull := 90.0 + (magnet - dist) * 7.0
			gem.pos += delta / dist * pull * dt
		if dist < hero.radius + 16.0:
			gem.alive = false
			var mul := float(hero.stats.get("gem_mul", 1.0))
			_add_xp(maxi(1, int(round(float(gem.value) * mul))))
			events.append({"type": "gem", "pos": gem.pos})
			var burst := int(hero.stats.get("gemburst", 0))
			if burst > 0 and rng.randf() < minf(0.6, 0.2 * float(burst)):
				var radius := 60.0 + 10.0 * float(burst)
				_aoe(hero, gem.pos, radius, hero.dmg * (0.2 + 0.1 * float(burst)))
				events.append({"type": "fx", "fx": "gem_burst", "pos": gem.pos, "radius": radius})
				if result != "":
					return


func _step_spawns(dt: float) -> void:
	if phase == "hunt" and time >= Catalog.BOSS_AT:
		phase = "boss"
		_spawn_boss()
		boss_title = _boss_title()
		events.append({"type": "boss_in", "name": boss.display if boss else "Boss", "title": boss_title, "pos": boss.pos if boss != null else play.get_center(), "shake": 0.55, "stop": 0.07})
		return
	if phase != "hunt":
		return
	spawn_cd -= dt
	if spawn_cd > 0.0:
		return
	if _minion_count() >= MAX_MINIONS:
		spawn_cd = 0.28
		return
	var wave := _wave()
	if wave.is_empty():
		spawn_cd = 0.4
		return
	# Critters arrive as packs from one side, so the screen fills in waves
	# instead of one at a time. The pack interval keeps the old pace per critter.
	var pool: Array = wave["pool"]
	var size := mini(PACK_SIZE + int(time / 30.0), MAX_MINIONS - _minion_count())
	size = maxi(1, int(round(float(size) * float(_diff()["density"]))))
	_spawn_pack(int(pool[rng.randi() % pool.size()]), size, pool)
	spawn_cd = float(wave["every"]) * float(maxi(size, 2)) * 0.36


func _spawn_pack(skin_index: int, count: int, pool: Array = []) -> void:
	var center := _spawn_point()
	# Mixed packs: each member draws from the wave's weighted pool, so the
	# species mix per critter is unchanged but no pack is a single species.
	for i in count:
		var skin := skin_index
		if not pool.is_empty() and i > 0:
			skin = int(pool[rng.randi() % pool.size()])
		# Spread along the view edge and outward only, so no member pops in
		# inside the camera's view.
		var hero_at := heroes[0].pos if not heroes.is_empty() else play.get_center()
		var out := (center - hero_at).normalized()
		var offset := out * rng.randf_range(0.0, 40.0) + out.orthogonal() * rng.randf_range(-80.0, 80.0)
		_spawn_minion(skin, _clamp_point(center + offset, 24.0))


func _spawn_minion(skin_index: int, at: Vector2 = Vector2.INF) -> void:
	var skins: Array = biome["skins"]
	var id := str(skins[clampi(skin_index, 0, skins.size() - 1)])
	var info := Catalog.critter(id)
	var actor := Actor.new()
	actor.id = _nid()
	actor.team = 1
	actor.kind = "minion"
	actor.sprite = id
	actor.display = str(info.get("name", id))
	actor.archetype = str(info.get("archetype", "chaser"))
	actor.pos = at if at != Vector2.INF else _spawn_point()
	actor.prev = actor.pos
	actor.radius = float(info.get("radius", 24))
	actor.max_hp = float(info.get("hp", 30)) * float(biome["hp_mul"]) * MINION_HP * float(_diff()["hp"])
	actor.hp = actor.max_hp
	actor.speed = float(info.get("speed", 100)) * _foe_speed_mul()
	actor.dmg = float(info.get("dmg", 8)) * float(biome["dmg_mul"]) * float(_diff()["dmg"])
	actor.xp = maxi(1, int(round(float(info.get("xp", 2)) * MINION_XP)))
	actor.interval = float(info.get("interval", 1.35))
	actor.shot_speed = float(info.get("shot_speed", 240))
	actor.range = float(info.get("shot_range", 280))
	actor.cd = rng.randf_range(0.15, 0.8)
	actor.touch_cd = rng.randf_range(0.0, 0.3)
	actors.append(actor)


func _spawn_boss() -> void:
	var id := str(biome["boss"])
	var info := Catalog.critter(id)
	var mul := float(biome["boss_mul"])
	var dhp := float(_diff()["hp"])
	var ddmg := float(_diff()["dmg"])
	var actor := Actor.new()
	actor.id = _nid()
	actor.team = 1
	actor.kind = "boss"
	actor.sprite = id
	actor.role = str(info.get("role", "tank"))
	actor.display = str(info.get("name", "Boss"))
	actor.radius = float(info.get("boss_radius", 76))
	actor.max_hp = float(info.get("boss_hp", 1400)) * mul * dhp
	actor.hp = actor.max_hp
	actor.speed = float(info.get("boss_speed", 70)) * _foe_speed_mul()
	actor.dmg = float(info.get("boss_touch", 16)) * mul * ddmg
	actor.pos = map.lair if explore else map.boss_spawn(actor.radius)
	actor.prev = actor.pos
	# Rise and hold: the intro beat keeps the boss planted and untouchable
	# until the reveal has played, then normal AI resumes.
	actor.boss_state = "intro"
	actor.boss_timer = BOSS_INTRO
	actor.bias_charge = float(info.get("bias_charge", 0.33))
	actor.bias_aoe = float(info.get("bias_aoe", 0.33))
	actor.aoe_dmg = float(info.get("aoe", 22)) * mul * ddmg
	actor.charge_dmg = float(info.get("charge", 28)) * mul * ddmg
	actor.shot_dmg = float(info.get("shot", 11)) * mul * ddmg
	actors.append(actor)
	boss = actor
	boss_mark = 0
	boss_opened = false
	_build_arena(actor.pos)
	if explore:
		# Anything left in the lair joins the fight; the rest of the map stays put.
		for other in actors:
			if other.kind == "minion" and other.alive and other.pos.distance_to(map.lair) < map.lair_r + 200.0:
				other.aggro = true
		return
	for other in actors:
		if other.kind == "minion" and other.alive:
			other.alive = false
			events.append({"type": "die", "id": other.id, "pos": other.pos, "radius": other.radius, "sprite": other.sprite, "kind": "minion"})


## The boss name card's subtitle: one per biome, a neutral fallback otherwise.
func _boss_title() -> String:
	return str(BOSS_TITLES.get(biome_id, "Lord of the Lair"))


func _hurt(target: Actor, amount: float, from_pos: Vector2, crit: bool, attacker: Actor, allow_thorns: bool) -> void:
	if target == null or not target.alive:
		return
	# The intro and the phase-2 roar are untouchable: no chip damage can skip
	# either telegraph.
	if target.kind == "boss" and (target.boss_state == "intro" or target.boss_state == "roar"):
		return
	if explore and target.kind == "minion" and not target.aggro:
		_set_camp_aggro(target, true)
	if target.kind == "hero" and target.iframes > 0.0:
		return
	var scaled := amount
	if attacker != null and attacker.weaken > 0.0 and attacker.team != target.team:
		scaled *= 0.72
	if attacker != null and attacker.kind == "hero":
		if target.kind != "hero" and target.max_hp > 0.0 and target.hp / target.max_hp <= 0.25:
			scaled *= 1.0 + float(attacker.stats.get("execute", 0.0))
		var mark_bonus := float(attacker.stats.get("mark", 0.0))
		if mark_bonus > 0.0 and target.mark > 0.0:
			scaled *= 1.0 + mark_bonus
	var dealt := maxf(1.0, scaled - target.armor)
	if target.kind == "hero":
		var bulwark := float(target.stats.get("bulwark", 0.0))
		if bulwark > 0.0 and target.still > 0.25:
			dealt = maxf(1.0, dealt * (1.0 - minf(0.5, bulwark)))
		# Tank guard: while swinging (and a beat after) melee takes less.
		if str(target.role) == "tank" and target.swing_t > 0.0:
			dealt = maxf(1.0, dealt * (1.0 - float(_role_tune("tank").get("swing_dr", 0.30))))
		if target.team == 0:
			dmg_taken += dealt
	# A shielded elite soaks damage with its shield first, then its hp.
	if target.shield > 0.0:
		var soaked := minf(target.shield, dealt)
		target.shield -= soaked
		dealt -= soaked
		if target.shield <= 0.0:
			events.append({"type": "shield_break", "pos": target.pos, "id": target.id})
	target.hp -= dealt
	target.flash = 0.1
	_skill_xp_hurt(attacker, target, dealt)
	var kick_dir := target.pos - from_pos
	if kick_dir.length() < 0.01:
		kick_dir = Vector2.RIGHT
	else:
		kick_dir = kick_dir.normalized()
	# A tank's melee shoves its foe away over a beat; any other hit only nudges.
	# Bosses and elites barely budge, so a fight is never a shuffle.
	var tank_melee := attacker != null and attacker.kind == "hero" and str(attacker.role) == "tank" and target.kind != "hero"
	if tank_melee:
		_melee_knockback(target, kick_dir)
	else:
		var kick := 2.0 if target.kind == "boss" else (10.0 if target.kind == "hero" else 16.0)
		target.pos += kick_dir * kick
	# A melee crit staggers: the wind-up is dropped and the attack cycle
	# restarts. Bosses are too big to interrupt.
	if tank_melee and crit and target.kind != "boss":
		target.windup = 0.0
		target.cd = maxf(target.cd, target.interval)
	# Vampiric affix: the attacker drinks a share of the damage it lands.
	if attacker != null and attacker != target and dealt > 0.0 and "vampiric" in attacker.affixes:
		attacker.hp = minf(attacker.max_hp, attacker.hp + dealt * 0.3)
	if attacker != null and attacker.kind == "hero":
		var siphon := float(attacker.stats.get("siphon", 0.0))
		if siphon > 0.0 and attacker.alive:
			attacker.hp = minf(attacker.max_hp, attacker.hp + dealt * siphon)
		# Tank sustain: melee heals a little of what it deals.
		if str(attacker.role) == "tank" and attacker.alive:
			var lifesteal := float(_role_tune("tank").get("lifesteal", 0.04))
			attacker.hp = minf(attacker.max_hp, attacker.hp + dealt * lifesteal)
		var crit_siphon := float(attacker.stats.get("crit_siphon", 0.0))
		if crit and crit_siphon > 0.0 and attacker.alive:
			attacker.hp = minf(attacker.max_hp, attacker.hp + dealt * crit_siphon)
			events.append({"type": "fx", "fx": "crit_siphon", "pos": attacker.pos})
		var mark_bonus := float(attacker.stats.get("mark", 0.0))
		if mark_bonus > 0.0 and target.kind != "hero":
			if target.mark <= 0.0:
				events.append({"type": "fx", "fx": "hunter_mark", "pos": target.pos})
			target.mark = maxf(target.mark, 3.0)
	if target.kind == "hero":
		target.iframes = 0.3
		events.append({
			"type": "hero_hurt",
			"pos": target.pos,
			"amount": dealt,
			"id": target.id,
			"shake": 0.72,
			"stop": 0.05,
		})
	else:
		events.append({
			"type": "hit",
			"pos": target.pos,
			"amount": dealt,
			"crit": crit,
			"id": target.id,
			"shake": 0.48 if crit else 0.2,
			"stop": 0.045 if crit else 0.028,
		})
	if target.kind == "boss":
		_boss_gems()
	if allow_thorns and target.kind == "hero" and attacker != null and attacker.alive and attacker != target:
		var thorns := float(target.stats.get("thorns", 0.0))
		if thorns > 0.0:
			_hurt(attacker, dealt * thorns, target.pos, false, null, false)
	if target.kind == "hero" and target.hp > 0.0:
		_try_blink(target, from_pos)
	var killed := target.hp <= 0.0 and target.alive
	# A melee crit or kill asks the screen for one short freeze (rate-limited).
	if tank_melee and (crit or killed):
		_melee_hitstop()
	if target.hp <= 0.0 and target.alive:
		if attacker != null and attacker.kind == "hero" and attacker.alive and target.kind != "hero":
			if attacker.team == 0:
				kills += 1
			var vamp := float(attacker.stats.get("vampkill", 0.0))
			if vamp > 0.0:
				attacker.hp = minf(attacker.max_hp, attacker.hp + attacker.max_hp * vamp)
				events.append({"type": "fx", "fx": "vampiric_kill", "pos": attacker.pos})
		_kill(target)


## Blink: below 40% health, a hit teleports the hero away on a cooldown.
func _try_blink(target: Actor, from_pos: Vector2) -> void:
	var n := int(target.stats.get("blink", 0))
	if n <= 0 or float(target.cds.get("blink", 0.0)) > 0.0:
		return
	if target.hp / maxf(target.max_hp, 1.0) >= 0.4:
		return
	var away := target.pos - from_pos
	if away.length() < 1.0:
		away = Vector2.RIGHT.rotated(rng.randf() * TAU)
	var dist := 120.0 + 30.0 * float(n)
	var to := _clamp_point(target.pos + away.normalized() * dist, target.radius)
	if explore:
		to = map.push_inside(to, target.radius * 0.8)
	var from := target.pos
	target.pos = to
	target.prev = to
	target.iframes = 0.55
	target.cds["blink"] = maxf(3.0, 8.0 - 1.5 * float(n))
	events.append({"type": "fx", "fx": "blink", "pos": from, "to": to})


func _kill(actor: Actor) -> void:
	actor.alive = false
	actor.hp = 0.0
	events.append({
		"type": "die",
		"id": actor.id,
		"pos": actor.pos,
		"radius": actor.radius,
		"sprite": actor.sprite,
		"kind": actor.kind,
	})
	if actor.kind == "hero":
		var stats: Dictionary = actor.stats
		if int(stats.get("revive", 0)) > 0 and not revive_spent and actor.team == 0:
			revive_spent = true
			stats["revive"] = 0
			actor.stats = stats
			actor.alive = true
			actor.hp = actor.max_hp * 0.5
			actor.iframes = 1.15
			events.append({"type": "revive", "pos": actor.pos, "shake": 0.4, "stop": 0.08})
			return
		if int(stats.get("phoenix", 0)) > 0 and not phoenix_spent and actor.team == 0:
			phoenix_spent = true
			stats["phoenix"] = 0
			actor.stats = stats
			actor.alive = true
			actor.hp = actor.max_hp * 0.6
			actor.iframes = 1.2
			var radius := 190.0
			for other in actors:
				if not other.alive or other.team == actor.team:
					continue
				if other.pos.distance_to(actor.pos) <= radius + other.radius:
					_hurt(other, actor.dmg * 2.4, actor.pos, false, actor, false)
					if result != "":
						break
			events.append({"type": "fx", "fx": "phoenix", "pos": actor.pos, "radius": radius})
			events.append({"type": "revive", "pos": actor.pos, "shake": 0.4, "stop": 0.08})
			return
		if result == "" and _team_wiped(actor.team) and actor.team == 0:
			result = "lose"
			phase = "over"
			paused = true
			events.append({"type": "hero_down"})
		elif result == "" and mode == Session.Mode.DUEL and actor.team == 2 and _team_wiped(2) and not _team_wiped(0):
			result = "win"
			phase = "over"
			paused = true
			events.append({"type": "duel_win"})
		return
	if actor.kind == "boss":
		_gear_roll_drop("boss", actor.pos)
		phase = "over"
		result = "win"
		paused = true
		events.append({"type": "boss_down", "id": actor.sprite, "name": actor.display, "shake": 0.9, "stop": 0.1})
		return
	if "molten" in actor.affixes:
		# Molten death leaves a burning patch behind for the hero to respect.
		_drop_field(actor, actor.pos, 96.0, actor.dmg * 0.6, 3.0, 0.5, "molten")
	if actor.goblin:
		_goblin_loot(actor)
		events.append({"type": "goblin_down", "pos": actor.pos})
		return
	if actor.team == 1:
		slain += 1
		_drop_gem(actor.pos, actor.xp)
		if actor.elite:
			_gear_roll_drop("elite", actor.pos)
		if actor.camp >= 0 and actor.camp < map.camps.size() and not _camp_alive(actor.camp):
			_gear_roll_drop("camp", actor.pos)


## Skill XP from one damage event. The attacker's weapon award is split
## OSRS-style: controlled melee trains Attack/Strength/Defence a third each,
## while a longrange shot or spell gives its skill 75% and Defence 25%, so the
## defensive gate trains alongside the weapon instead of only from damage taken.
## The whole longrange award is scaled by LONGRANGE_PACE so ranged/magic pace
## like melee; a Hitpoints share of the damage dealt rides on top unscaled, and
## a hero still trains Defence for the damage it takes or blocks. Kept in
## skill_xp until the run commits; never writes GearDB mid-fight.
func _skill_xp_hurt(attacker: Actor, target: Actor, dealt: float) -> void:
	if dealt <= 0.0:
		return
	if attacker != null and attacker.kind == "hero" and target.kind != "hero":
		var combat := dealt * COMBAT_XP_PER_DAMAGE * float(_diff()["xp"]) * xp_falloff()
		match _weapon_skill(attacker):
			"magic":
				_add_skill_xp(attacker, "magic", combat * RANGED_MAIN_SHARE * LONGRANGE_PACE)
				_add_skill_xp(attacker, "defence", combat * RANGED_DEF_SHARE * LONGRANGE_PACE)
			"ranged":
				_add_skill_xp(attacker, "ranged", combat * RANGED_MAIN_SHARE * LONGRANGE_PACE)
				_add_skill_xp(attacker, "defence", combat * RANGED_DEF_SHARE * LONGRANGE_PACE)
			_:
				_add_skill_xp(attacker, "attack", combat * MELEE_SHARE)
				_add_skill_xp(attacker, "strength", combat * MELEE_SHARE)
				_add_skill_xp(attacker, "defence", combat * MELEE_SHARE)
		_add_skill_xp(attacker, "hitpoints", combat * HP_XP_SHARE)
	elif target.kind == "hero":
		_add_skill_xp(target, "defence", dealt * COMBAT_XP_PER_DAMAGE)


## The combat skill a hero's weapon trains: the GearDB contract table when it
## lists the hero, else the class default. Never keyed on a hero id in logic.
func _weapon_skill(hero: Actor) -> String:
	var skill := str(GearDB.WEAPON_SKILL.get(str(hero.sprite), ""))
	if skill != "":
		return skill
	match str(hero.role):
		"mage":
			return "magic"
		"archer":
			return "ranged"
		_:
			return "attack"


func _add_skill_xp(hero: Actor, skill: String, amount: float) -> void:
	if amount <= 0.0:
		return
	var id := str(hero.sprite)
	if not skill_xp.has(id):
		skill_xp[id] = {}
	skill_xp[id][skill] = float(skill_xp[id].get(skill, 0.0)) + amount


func _add_xp(amount: int) -> void:
	if amount <= 0 or heroes.is_empty():
		return
	xp += amount
	var role := str(heroes[0].role)
	while xp >= xp_need and level < Catalog.MAX_RUN_LEVEL:
		xp -= xp_need
		level += 1
		xp_need = Catalog.xp_for_level(level)
		offer_queue += 1
	if offer_queue > 0 and offer.is_empty():
		offer = Catalog.roll_offer(role, stacks, rng)
		paused = true
		events.append({"type": "levelup", "level": level, "offer": offer.duplicate()})


func _drop_gem(at: Vector2, value: int) -> void:
	var gem := Gem.new()
	gem.pos = at + Vector2(rng.randf_range(-14, 14), rng.randf_range(-14, 14))
	gem.prev = gem.pos
	gem.value = value
	gem.bob = rng.randf() * TAU
	gems.append(gem)
	if gems.size() > 42:
		var old: Gem = gems[0]
		if old.alive:
			gem.value += old.value
		gems.remove_at(0)


func _boss_gems() -> void:
	if boss == null or boss.max_hp <= 0.0:
		return
	var mark := int((1.0 - boss.hp / boss.max_hp) * 4.0)
	if mark > boss_mark and boss.hp > 0.0:
		boss_mark = mark
		_drop_gem(boss.pos, 8)


func _enemy_shot(actor: Actor, target: Actor, dmg: float, speed: float) -> void:
	var dir := target.pos - actor.pos
	if dir.length() < 1.0:
		return
	dir = dir.normalized()
	var shot := Shot.new()
	shot.team = actor.team
	shot.owner_id = actor.id
	shot.pos = actor.pos + dir * (actor.radius + 6.0)
	shot.prev = shot.pos
	shot.vel = dir * speed
	shot.dmg = dmg
	shot.radius = 9.0
	shot.ttl = 2.3
	shot.kind = "enemy"
	shots.append(shot)


func _separate() -> void:
	var group: Array = []
	for actor in actors:
		if actor.alive and actor.team == 1:
			group.append(actor)
	# Soft personal space around the hero: mobs crowd in but stay at
	# contact range instead of piling on top of it.
	for hero in heroes:
		if not hero.alive:
			continue
		for a in group:
			if a.kind == "boss":
				continue
			var off: Vector2 = a.pos - hero.pos
			var d := off.length()
			var room: float = (hero.radius + a.radius) * 0.85
			if d < room and d > 0.01:
				a.pos += off / d * (room - d) * 0.35
	for i in group.size():
		for j in range(i + 1, group.size()):
			var a: Actor = group[i]
			var b: Actor = group[j]
			var delta := a.pos - b.pos
			var dist := delta.length()
			var need := (a.radius + b.radius) * 0.7
			if dist < need and dist > 0.01:
				var push := delta / dist * (need - dist) * 0.5
				if a.kind != "boss":
					a.pos += push
				if b.kind != "boss":
					b.pos -= push


func _enrage_and_timeout() -> void:
	if explore:
		if phase == "boss" and not enraged and boss_time >= 75.0:
			enraged = true
			events.append({"type": "banner", "text": "The boss is furious"})
		return
	if phase == "boss" and not enraged and time >= 100.0:
		enraged = true
		events.append({"type": "banner", "text": "The boss is furious"})
	if result == "" and time >= 119.0:
		result = "lose"
		phase = "over"
		paused = true
		events.append({"type": "hero_down", "reason": "time"})


func _focus_hero() -> Actor:
	var best: Actor = null
	var best_d := 99999.0
	var origin := boss.pos if boss != null else play.get_center()
	for hero in heroes:
		if not hero.alive:
			continue
		var dist := origin.distance_to(hero.pos)
		if dist < best_d:
			best = hero
			best_d = dist
	return best


## True once the boss is close enough to the focused hero that an attack's
## telegraph ring will read on screen (BOSS_ENGAGE). While the hero is still
## at the lair the boss holds its opening until it is in view; once the hero
## leaves the lair theatre the fight is a normal chase and attacks may start.
func _boss_engage() -> bool:
	if boss == null:
		return false
	var focus := _focus_hero()
	if focus == null:
		return true
	if boss.pos.distance_to(focus.pos) <= BOSS_ENGAGE:
		return true
	return explore and focus.pos.distance_to(map.lair) > map.lair_r * 2.0


## The boss is out of its intro but must still cross to the hero before it
## may open with its first attack.
func _boss_approaching() -> bool:
	return boss != null and boss.alive and boss.boss_state == "idle" and not boss_opened and not _boss_engage()


func _nearest_living_hero(at: Vector2) -> Actor:
	var best: Actor = null
	var best_d := 99999.0
	for hero in heroes:
		if not hero.alive:
			continue
		var dist := at.distance_to(hero.pos)
		if dist < best_d:
			best = hero
			best_d = dist
	return best


func _team_wiped(team: int) -> bool:
	for hero in heroes:
		if hero.team == team and hero.alive:
			return false
	return true


func _minion_count() -> int:
	var n := 0
	for actor in actors:
		if actor.alive and actor.kind == "minion":
			n += 1
	return n


func _wave() -> Dictionary:
	for wave in Catalog.WAVES:
		if time < float(wave["until"]):
			return wave
	return {}


## The zone nearest the hero. Today's map has one zone the size of the
## playfield, so the rim is the same edge the minions used to walk in from.
func _spawn_point() -> Vector2:
	var at := play.get_center()
	if not heroes.is_empty():
		at = heroes[0].pos
	# Just past the edge of the follow camera's view, inside the zone. The
	# playfield is far wider than what the 3D camera frames, so spawning on
	# the zone rim left most of a wave walking in off screen.
	var zone: Rect2 = map.zone_near(at)["rect"]
	var ring := Rect2(at + VIEW_BOX.position, VIEW_BOX.size).grow(SPAWN_MARGIN)
	var perimeter := (ring.size.x + ring.size.y) * 2.0
	for _try in 64:
		var p := _on_rect(ring, rng.randf() * perimeter)
		if zone.grow(-30.0).has_point(p) and play.grow(-30.0).has_point(p):
			return p
	return HuntMap.rim_point(zone, rng)


## A point `d` px along the rectangle's edge, clockwise from the top left.
static func _on_rect(r: Rect2, d: float) -> Vector2:
	if d < r.size.x:
		return Vector2(r.position.x + d, r.position.y)
	d -= r.size.x
	if d < r.size.y:
		return Vector2(r.end.x, r.position.y + d)
	d -= r.size.y
	if d < r.size.x:
		return Vector2(r.end.x - d, r.end.y)
	d -= r.size.x
	return Vector2(r.position.x, r.end.y - d)


func _clamp_actor(actor: Actor) -> void:
	actor.pos = _clamp_point(actor.pos, actor.radius)
	if explore:
		actor.pos = map.push_inside(actor.pos, actor.radius * (0.6 if actor.kind == "boss" else 0.8))


func _clamp_point(at: Vector2, radius: float) -> Vector2:
	return Vector2(
		clampf(at.x, play.position.x + radius, play.end.x - radius),
		clampf(at.y, play.position.y + radius, play.end.y - radius)
	)


func _actor_by_id(id: int) -> Actor:
	if id < 0:
		return null
	for actor in actors:
		if actor.id == id:
			return actor
	return null


func _rage() -> float:
	return 1.32 if enraged else 1.0


## One-shot phase 2 trigger: the first time the boss drops to half health it
## roars (an invulnerable 0.8 s telegraph), then attacks 20% faster with an
## extra archetype pattern. The intro is exempt, so the reveal is never cut.
func _check_phase2() -> void:
	if boss == null or not boss.alive or boss.phase2 or boss.boss_state == "intro":
		return
	if boss.max_hp <= 0.0 or boss.hp / boss.max_hp > BOSS_PHASE_HP:
		return
	boss.phase2 = true
	boss.atk_speed = BOSS_PHASE_SPEED
	boss.boss_state = "roar"
	boss.boss_timer = BOSS_ROAR
	boss.vel = Vector2.ZERO
	events.append({
		"type": "boss_enrage",
		"id": boss.id,
		"name": boss.display,
		"time": BOSS_ROAR,
		"shake": 0.55,
		"stop": 0.06,
	})


## The phase-2 extra pattern, chosen by archetype role: a melee boss slams a
## ring into the ground, a ranged/caster boss fires a five-projectile fan.
func _phase2_attack() -> String:
	return "fan2" if Catalog.is_ranged(str(boss.role)) else "slam"


func _halt() -> bool:
	if paused or result != "":
		_compact()
		if result != "":
			_flush_xp_drops(true)
		return true
	return false


func _compact() -> void:
	var i := 0
	while i < actors.size():
		var actor: Actor = actors[i]
		var keep := actor.alive or actor.kind == "hero"
		if keep:
			i += 1
		else:
			actors.remove_at(i)
	i = 0
	while i < shots.size():
		if shots[i].alive:
			i += 1
		else:
			shots.remove_at(i)
	i = 0
	while i < gems.size():
		if gems[i].alive:
			i += 1
		else:
			gems.remove_at(i)
	i = 0
	while i < pings.size():
		if pings[i].alive:
			i += 1
		else:
			pings.remove_at(i)
	i = 0
	while i < fields.size():
		if fields[i].alive:
			i += 1
		else:
			fields.remove_at(i)


func _nid() -> int:
	var id := _next_id
	_next_id += 1
	return id


const SHOOT_WINDUP := 0.28


## The boss arena: a broken ring of standing stones around the fight,
## centred between the boss's landing spot and the hero, wide enough that
## both stand inside it. Gaps between stones fit the boss, so it weaves
## through rather than walling the hero in. Stage3D renders these.
func _build_arena(boss_at: Vector2) -> void:
	obstacles.clear()
	if explore:
		_landmark_stones()
	var hero_at := boss_at
	if not heroes.is_empty():
		hero_at = heroes[0].pos
	var center := boss_at.lerp(hero_at, 0.5)
	var radius := clampf(boss_at.distance_to(hero_at) * 0.5 + 375.0, 500.0, 650.0)
	var r := RandomNumberGenerator.new()
	r.seed = 7331
	var count := 15
	for i in count:
		var jitter := r.randf_range(-0.08, 0.08)
		var wob := r.randf_range(-20.0, 20.0)
		if i % 5 == 4:
			continue
		var ang := TAU * float(i) / float(count) + jitter
		var at := center + Vector2(cos(ang), sin(ang)) * (radius + wob)
		if play.grow(-50.0).has_point(at) and (not explore or map.depth(at) > ARENA_STONE_R + 20.0):
			obstacles.append(Vector3(at.x, at.y, ARENA_STONE_R))


const ARENA_STONE_R := 40.0


## Obstacle avoidance: look ahead along the wanted velocity and bend it
## away from any stone in the path, and ease off the arena walls.
func _steer(actor: Actor, want: Vector2) -> Vector2:
	var speed := want.length()
	if speed < 0.01:
		return want
	var dir := want / speed
	var out := want
	var body := actor.radius * (0.6 if actor.kind == "boss" else 0.8)
	for o in obstacles:
		var to := Vector2(o.x, o.y) - actor.pos
		var along := to.dot(dir)
		var look := body + o.z + speed * 0.45
		if along <= 0.0 or along > look:
			continue
		var lateral := to - dir * along
		var clear := o.z + body + 8.0
		var ld := lateral.length()
		if ld < clear:
			var away := -lateral / ld if ld > 0.01 else Vector2(-dir.y, dir.x)
			out += away * speed * 1.4 * (1.0 - ld / clear) * (1.0 - along / look * 0.5)
	if actor.kind == "boss":
		var margin := actor.radius + 70.0
		var inward := Vector2.ZERO
		inward.x += maxf(0.0, play.position.x + margin - actor.pos.x) - maxf(0.0, actor.pos.x - (play.end.x - margin))
		inward.y += maxf(0.0, play.position.y + margin - actor.pos.y) - maxf(0.0, actor.pos.y - (play.end.y - margin))
		out += inward * 2.0
	return out.normalized() * speed if out.length() > 0.01 else want


## Running into a stone slides along it instead of sticking: the inward
## part of the velocity is dropped, and a head-on push turns into a glide
## around the side the stick leans toward.
func _slide(actor: Actor, vel: Vector2) -> Vector2:
	var speed := vel.length()
	if speed < 0.01:
		return vel
	var body := actor.radius * 0.8
	for o in obstacles:
		var c := Vector2(o.x, o.y)
		var off := actor.pos - c
		var d := off.length()
		if d > o.z + body + 4.0 or d < 0.01:
			continue
		var n := off / d
		var inward := vel.dot(n)
		if inward >= 0.0:
			continue
		vel -= n * inward
		if vel.length() < speed * 0.35:
			var tangent := Vector2(-n.y, n.x)
			if tangent.dot(vel) < 0.0 or (vel.length() < 1.0 and n.cross(-vel.normalized() if vel.length() > 0.0 else n) < 0.0):
				tangent = -tangent
			vel = tangent * speed * 0.8
	return vel


## Slide out of any stone the actor overlaps.
func _push_out(actor: Actor) -> void:
	var body := actor.radius * (0.6 if actor.kind == "boss" else 0.8)
	for o in obstacles:
		var c := Vector2(o.x, o.y)
		var off := actor.pos - c
		var d := off.length()
		var need := o.z + body
		if d < need:
			actor.pos = c + (off / d if d > 0.01 else Vector2.RIGHT) * need


## Which perpendicular has more open room: away from stones and walls.
func _open_side(actor: Actor, dir: Vector2) -> Vector2:
	var best := Vector2(-dir.y, dir.x)
	var best_score := -1e9
	for side in [Vector2(-dir.y, dir.x), Vector2(dir.y, -dir.x)]:
		var probe: Vector2 = actor.pos + side * 160.0
		var score := 0.0
		if not play.grow(-actor.radius).has_point(probe):
			score -= 1000.0
		for o in obstacles:
			score -= maxf(0.0, 220.0 - probe.distance_to(Vector2(o.x, o.y)))
		if score > best_score:
			best_score = score
			best = side
	return best


# --- Explore ------------------------------------------------------------------

## Places the map's camps, elite packs and patrols. Critters further north
## (closer to the lair) are tougher and pay more.
func _spawn_world() -> void:
	var skins: Array = biome["skins"]
	var density := float(_diff()["density"])
	var elite_chance := float(_diff()["elite"])
	for ci in map.camps.size():
		var camp: Dictionary = map.camps[ci]
		var at: Vector2 = camp["pos"]
		var count: int = camp["count"]
		# "Swarming" thickens every camp by 30%; a raised tier adds density on
		# top. Normal's density is 1.0, so both leave the camp count untouched.
		if has_modifier("swarming"):
			count = int(ceil(float(count) * 1.3))
		count = maxi(1, int(round(float(count) * density)))
		var base := ci % skins.size()
		var affixes: Array = camp.get("affixes", [])
		for k in count:
			var ang := TAU * float(k) / float(count) + rng.randf_range(-0.3, 0.3)
			var p := map.push_inside(at + Vector2.RIGHT.rotated(ang) * rng.randf_range(70.0, 150.0), 30.0)
			var skin := base if k % 2 == 0 else rng.randi() % skins.size()
			var m := _place_minion(skin, p, ci)
			# A raised tier promotes some camp members to elites. Normal rolls
			# nothing (chance 0), so its RNG stream is bit-for-bit unchanged.
			if elite_chance > 0.0 and rng.randf() < elite_chance:
				_make_elite(m)
			_apply_affixes(m, affixes)
		if bool(camp["elite"]):
			var e := _place_minion(rng.randi() % skins.size(), at, ci)
			_make_elite(e)
			_apply_affixes(e, affixes)
		for affix in affixes:
			events.append({"type": "fx", "fx": "affix_" + str(affix), "pos": at})
	for pi in map.patrols.size():
		var pat: Dictionary = map.patrols[pi]
		var a: Vector2 = pat["a"]
		var b: Vector2 = pat["b"]
		var tag := 1000 + pi
		for k in maxi(1, int(round(float(pat["count"]) * density))):
			var m := _place_minion(rng.randi() % skins.size(), a + Vector2(rng.randf_range(-50, 50), rng.randf_range(-50, 50)), tag)
			if elite_chance > 0.0 and rng.randf() < elite_chance:
				_make_elite(m)
			m.patrol_a = a
			m.patrol_b = b
	for c in map.loot:
		chests.append({"pos": c["pos"], "tier": c["tier"], "open": false})
	shrines.clear()
	for s in map.shrines:
		shrines.append({"pos": s["pos"], "kind": s["kind"], "used": false})
	goblin = null
	goblin_roll = false


## Stamps an elite camp's affixes onto one spawned critter. Shielded reads
## max_hp, so it must run after _make_elite() has sized the leader.
func _apply_affixes(m: Actor, affixes: Array) -> void:
	if affixes.is_empty():
		return
	m.affixes = affixes.duplicate()
	for affix in affixes:
		match str(affix):
			"fast":
				m.speed *= 1.45
				m.interval = maxf(0.22, m.interval * 0.8)
			"shielded":
				m.shield = m.max_hp * 0.4


func _place_minion(skin: int, at: Vector2, camp: int) -> Actor:
	_spawn_minion(skin, at)
	var m: Actor = actors[-1]
	m.camp = camp
	m.home = at
	m.aggro = false
	m.facing = rng.randf() * TAU
	var depth := 1.0 - clampf(at.y / maxf(map.size.y, 1.0), 0.0, 1.0)
	m.max_hp *= EXPLORE_HP * (1.0 + depth * 0.9)
	m.hp = m.max_hp
	m.dmg *= 1.0 + depth * 0.5
	m.xp = maxi(1, int(round(float(m.xp) * EXPLORE_XP * (1.0 + depth * 0.6) * float(_diff()["xp"]))))
	return m


const EXPLORE_HP := 1.6
const EXPLORE_XP := 1.25


func _make_elite(m: Actor) -> void:
	m.elite = true
	# The pack leader is a head taller than its pack: +80% on top of the roll.
	m.max_hp *= 5.0 * 1.8
	m.hp = m.max_hp
	m.dmg *= 1.6
	m.radius *= 1.35
	m.xp *= 6
	m.display = "Elite " + m.display


func _idle_minion(actor: Actor, dt: float, dist: float) -> void:
	var reach := AGGRO_PATROL if actor.patrol_a != Vector2.INF else AGGRO_CAMP
	if dist < reach and fog_now.size() > 0:
		_set_camp_aggro(actor, true)
		return
	var goal := actor.home
	var pace := 0.55
	if actor.patrol_a != Vector2.INF:
		goal = actor.patrol_b if actor.to_b else actor.patrol_a
		pace = 0.42
		if actor.pos.distance_to(goal) < 40.0:
			actor.to_b = not actor.to_b
	var to := goal - actor.pos
	if to.length() > 24.0:
		actor.vel = to.normalized() * actor.speed * _slow_mul(actor) * pace
		actor.pos += actor.vel * dt
		actor.facing = actor.vel.angle()
		actor.pos = map.push_inside(actor.pos, actor.radius * 0.8)
	else:
		actor.vel = Vector2.ZERO
		# Back home after a leash: patch up.
		actor.hp = minf(actor.max_hp, actor.hp + actor.max_hp * 0.25 * dt)


func _set_camp_aggro(actor: Actor, on: bool) -> void:
	for a in actors:
		if a.alive and a.kind == "minion" and (a == actor or (actor.camp >= 0 and a.camp == actor.camp)):
			a.aggro = on
			if not on:
				a.vel = Vector2.ZERO
	if on and actor.camp >= 0:
		events.append({"type": "aggro", "id": actor.id, "pos": actor.pos})


## Where a chaser should head: straight at the hero when close, otherwise
## down the shared flow field around the forest.
func _chase_point(actor: Actor, target: Actor) -> Vector2:
	if _flow.is_empty():
		return target.pos
	var way := map.downhill(_flow, actor.pos)
	if way == Vector2.INF:
		return target.pos
	return way


func _step_explore(dt: float) -> void:
	if heroes.is_empty():
		return
	var hero: Actor = heroes[0]
	if phase == "boss":
		boss_time += dt
		_add_t -= dt
		if _add_t <= 0.0 and boss != null and boss.alive and _minion_count() < 6:
			# The boss calls adds from the lair's edge.
			_add_t = 9.0
			var skins: Array = biome["skins"]
			for k in 2:
				var ang := rng.randf() * TAU
				var at := map.push_inside(map.lair + Vector2.RIGHT.rotated(ang) * (map.lair_r - 80.0), 30.0)
				var m := _place_minion(rng.randi() % skins.size(), at, -1)
				m.aggro = true
			events.append({"type": "banner", "text": "Adds incoming"})
	# Shared flow field from the hero, rebuilt when the hero changes cell.
	_flow_t -= dt
	var cell := map.cell_index(hero.pos)
	if cell != _flow_cell or _flow_t <= 0.0:
		_flow_cell = cell
		_flow_t = 0.5
		_flow = map.flow(hero.pos, 34)
	# Fog of war.
	_fog_t -= dt
	if _fog_t <= 0.0:
		_fog_t = 0.1
		_reveal(hero.pos)
	# Loot chests.
	for c in chests:
		if bool(c["open"]) or hero.pos.distance_to(c["pos"]) > hero.radius + 56.0:
			continue
		_claim_chest(c, hero)
	# The treasure goblin: the first time the hero nears its haunt the run
	# rolls once (seeded). Whatever the roll, it never rolls again.
	if goblin == null and not goblin_roll and map.goblin_at != Vector2.INF:
		if hero.pos.distance_to(map.goblin_at) < GOBLIN_SIGHT:
			goblin_roll = true
			if rng.randf() < GOBLIN_CHANCE:
				_spawn_goblin(map.goblin_at)
	# The lair: walk in and the boss rises.
	if phase == "hunt" and hero.pos.distance_to(map.lair) < map.lair_r * 0.72:
		begin_boss()
		_add_t = 6.0


## Opens a chest: coins home, a ring of gems, a sip of health and the loot
## event run_screen turns into a chest sent home. Goblin loot borrows this too.
func _claim_chest(c: Dictionary, hero: Actor) -> void:
	c["open"] = true
	var rare: bool = str(c["tier"]) == "rare"
	var value := (40 if rare else 18) + level * 2
	var coins := 40 if rare else 15
	loot_coins += coins
	for k in (9 if rare else 6):
		_drop_gem(c["pos"] + Vector2.RIGHT.rotated(TAU * k / 6.0) * rng.randf_range(40.0, 90.0), maxi(1, value / (9 if rare else 6)))
	hero.hp = minf(hero.max_hp, hero.hp + hero.max_hp * 0.2)
	events.append({"type": "loot", "pos": c["pos"], "tier": c["tier"], "coins": coins, "shake": 0.25})
	_gear_roll_drop("chest_" + str(c["tier"]), c["pos"])


## Shrine pass: claim any shrine a hero has walked within reach of, tick the
## buffs down, and rebuild the stats the moment one expires.
func _step_shrines(dt: float) -> void:
	for s in shrines:
		if bool(s["used"]):
			continue
		var claimed := false
		for hero in heroes:
			if hero.alive and hero.pos.distance_to(s["pos"]) <= SHRINE_REACH + hero.radius:
				claimed = true
				_activate_shrine(hero, str(s["kind"]), s["pos"])
		if claimed:
			s["used"] = true
	for hero in heroes:
		if not hero.alive:
			continue
		var changed := false
		for kind in hero.shrine_buffs.keys():
			var left := float(hero.shrine_buffs[kind]) - dt
			if left <= 0.0:
				hero.shrine_buffs.erase(kind)
				changed = true
				events.append({"type": "shrine_end", "kind": str(kind), "id": hero.id})
			else:
				hero.shrine_buffs[kind] = left
		if hero.regen_burst > 0.0:
			hero.regen_burst = maxf(0.0, hero.regen_burst - dt)
			hero.hp = minf(hero.max_hp, hero.hp + WARD_REGEN * dt)
		if changed:
			_recompute(hero)


func _activate_shrine(hero: Actor, kind: String, pos: Vector2) -> void:
	hero.shrine_buffs[kind] = SHRINE_SECONDS
	if kind == "warding":
		hero.regen_burst = WARD_REGEN_TIME
	_recompute(hero)
	events.append({"type": "shrine", "kind": kind, "pos": pos, "seconds": SHRINE_SECONDS})


## The treasure goblin: a fragile chaser that never fights, only runs. It
## uses the same slide and open-ground rules as everything else.
func _spawn_goblin(at: Vector2) -> Actor:
	if goblin != null and goblin.alive:
		return goblin
	var skins: Array = biome["skins"]
	var id := str(skins[0])
	var info := Catalog.critter(id)
	var actor := Actor.new()
	actor.id = _nid()
	actor.team = 1
	actor.kind = "minion"
	actor.goblin = true
	actor.sprite = id
	actor.display = "Treasure Goblin"
	actor.archetype = str(info.get("archetype", "chaser"))
	actor.pos = map.push_inside(at, 30.0)
	actor.prev = actor.pos
	actor.radius = 26.0
	actor.max_hp = float(info.get("hp", 30)) * float(biome["hp_mul"]) * MINION_HP * 5.0 * float(_diff()["hp"])
	actor.hp = actor.max_hp
	var base_speed := 150.0
	if not heroes.is_empty() and bases.has(heroes[0].id):
		base_speed = float(bases[heroes[0].id]["speed"])
	actor.speed = base_speed * 1.15
	actor.dmg = 0.0
	actor.interval = 999.0
	actor.range = 0.0
	actor.xp = 3
	actor.aggro = false
	actor.goblin_t = GOBLIN_LIFE
	actors.append(actor)
	goblin = actor
	events.append({"type": "fx", "fx": "goblin_spawn", "pos": actor.pos})
	return actor


func _step_goblin(actor: Actor, dt: float, target: Actor) -> void:
	actor.goblin_t -= dt
	var far := target == null or actor.pos.distance_to(target.pos) > GOBLIN_LEASH
	if actor.goblin_t <= 0.0 or far:
		actor.alive = false
		if goblin == actor:
			goblin = null
		events.append({"type": "goblin_escape", "pos": actor.pos})
		return
	actor.flash = maxf(0.0, actor.flash - dt)
	var away := actor.pos - target.pos
	if away.length() < 1.0:
		away = Vector2.RIGHT.rotated(rng.randf() * TAU)
	var base := away.normalized()
	# Prefer to keep running away, but lean toward whichever heading stays on
	# open ground so the goblin does not wedge itself into the forest.
	var best_dir := base
	var best_score := -1.0e9
	for k in 8:
		var d := base.rotated(TAU * float(k) / 8.0)
		var probe := actor.pos + d * 220.0
		var score := d.dot(base) * 120.0 + map.depth(probe)
		if not play.grow(-actor.radius).has_point(probe):
			score -= 500.0
		for o in obstacles:
			score -= maxf(0.0, 200.0 - probe.distance_to(Vector2(o.x, o.y)))
		if score > best_score:
			best_score = score
			best_dir = d
	actor.facing = best_dir.angle()
	actor.vel = _slide(actor, best_dir * actor.speed * _slow_mul(actor))
	var was := actor.pos
	actor.pos += actor.vel * dt
	actor.pos = map.push_inside(actor.pos, actor.radius * 0.8)
	actor.vel = (actor.pos - was) / maxf(dt, 0.0001)


func _goblin_loot(actor: Actor) -> void:
	goblin = null
	_gear_roll_drop("goblin", actor.pos)
	var chest := {"pos": actor.pos, "tier": "rare", "open": false}
	chests.append(chest)
	var hero := _nearest_living_hero(actor.pos)
	if hero != null:
		_claim_chest(chest, hero)
	for k in 10:
		_drop_gem(actor.pos + Vector2.RIGHT.rotated(TAU * float(k) / 10.0) * rng.randf_range(36.0, 96.0), 2)


## Roll one source into the run's loot list and emit a gear_drop event for the
## reveal UI. Uses the dedicated loot stream, so combat RNG is untouched.
## The hero is the sim's own critter id; LootTable never keys on it directly.
func _gear_roll_drop(source: String, pos: Vector2) -> void:
	var hero := str(heroes[0].sprite) if not heroes.is_empty() else ""
	for id in LootTable.roll(loot_rng, source, hero, _biome_index(), difficulty):
		gear_found.append(id)
		var key := "gear%d" % gear_found.size()
		# Several pieces from one source fan out a little so beams don't overlap.
		var at := pos + Vector2(loot_rng.randf_range(-40.0, 40.0), loot_rng.randf_range(-30.0, 30.0))
		if explore:
			at = _clamp_point(at, 24.0)
		gear_ground.append({"key": key, "item": id, "pos": at, "t": time})
		events.append({"type": "gear_drop", "item": id, "key": key, "tier": int(id.get_slice(".", 2)), "pos": at})


## Ground pieces go to the hero when they walk close or after the magnet delay.
func _step_gear_pickups() -> void:
	if gear_ground.is_empty() or heroes.is_empty():
		return
	var hero: Actor = heroes[0]
	var left: Array = []
	for g in gear_ground:
		if (hero.alive and hero.pos.distance_to(g["pos"]) <= GEAR_REACH) or time - float(g["t"]) >= GEAR_MAGNET:
			events.append({"type": "gear_pickup", "item": g["item"], "key": g["key"], "pos": g["pos"]})
		else:
			left.append(g)
	gear_ground = left


## The biome's place in Catalog.BIOMES; deeper biomes roll higher tiers.
func _biome_index() -> int:
	for i in Catalog.BIOMES.size():
		if str(Catalog.BIOMES[i]["id"]) == biome_id:
			return i
	return 0


## Whether any living critter still belongs to camp id (patrols excluded).
func _camp_alive(camp: int) -> bool:
	for a in actors:
		if a.alive and a.kind == "minion" and a.camp == camp:
			return true
	return false


## Grant the run's earned gear to the armory, once. A win keeps everything; a
## loss keeps half (floor), earliest drops first. A duplicate banks as shards
## (or coins when the tier is complete) via SaveGame.bank_gear, whose
## {"ids", "shards", "coins"} result lands in gear_bank for the end card. Safe
## to call twice; a repeat banks nothing. Returns the granted item ids, so
## existing callers that expect a banked-id list are unchanged.
func bank_gear() -> Array[String]:
	var banked: Array[String] = []
	if _banked:
		return banked
	_banked = true
	var keep := gear_found.size()
	if result == "lose":
		keep = gear_found.size() / 2
	gear_bank = SaveGame.bank_gear(gear_found.slice(0, keep))
	banked.assign(gear_bank.get("ids", []))
	commit_xp()
	return banked


## Writes the run's combat XP without banking gear: fixed-seed dailies never
## bank gear, but the hero still trained, and the XP drops the HUD showed must
## land. Safe to call twice and after bank_gear; the XP is written once.
func commit_xp() -> void:
	if _xp_committed:
		return
	_xp_committed = true
	_commit_skill_xp()


## Writes the run's accumulated combat XP to GearDB, once, and queues a
## skill_up event for every level gained (the end-of-run toast). A lost run
## still trains; only the gear is halved. Runs from bank_gear so a second
## commit is a no-op.
func _commit_skill_xp() -> void:
	_flush_xp_drops(true)
	for hero_id in skill_xp:
		var row: Dictionary = skill_xp[hero_id]
		for skill in GearDB.SKILL_KEYS:
			var amount := int(round(float(row.get(skill, 0.0))))
			if amount <= 0:
				continue
			var gained := GearDB.add_xp(str(hero_id), skill, amount)
			if gained <= 0:
				continue
			var reached := GearDB.level(str(hero_id), skill)
			for step in gained:
				events.append({"type": "skill_up", "skill": skill, "level": reached - gained + step + 1})


func _reveal(at: Vector2) -> void:
	fog_now.fill(0)
	var r := int(ceil(REVEAL / HuntMap.GRID))
	var c := map.cell_index(at)
	var cx := c % map.grid_w
	var cy := c / map.grid_w
	var r2 := (REVEAL / HuntMap.GRID) * (REVEAL / HuntMap.GRID)
	for y in range(maxi(0, cy - r), mini(map.grid_h, cy + r + 1)):
		for x in range(maxi(0, cx - r), mini(map.grid_w, cx + r + 1)):
			var dx := float(x - cx)
			var dy := float(y - cy) * 0.8
			if dx * dx + dy * dy <= r2:
				var i := y * map.grid_w + x
				fog_now[i] = 1
				if fog_seen[i] == 0:
					fog_seen[i] = 1
	fog_dirty = true


func seen_at(p: Vector2) -> bool:
	return not explore or fog_seen[map.cell_index(p)] == 1


func visible_at(p: Vector2) -> bool:
	return not explore or fog_now[map.cell_index(p)] == 1


## Share of the map's open ground revealed so far (0..1).
func explored() -> float:
	if not explore:
		return 1.0
	var open := 0
	var seen := 0
	for i in map.open_cells.size():
		if map.open_cells[i] == 1:
			open += 1
			if fog_seen[i] == 1:
				seen += 1
	return float(seen) / maxf(float(open), 1.0)


## Landmarks (great trees, standing stones, ruins) are solid.
func _landmark_stones() -> void:
	for l in map.landmarks:
		var p: Vector2 = l["pos"]
		obstacles.append(Vector3(p.x, p.y, float(l["r"])))
