class_name RunSim
extends RefCounted

## Presentation-free hunt. Teams:
##   0 local heroes (solo, or every co-op hero)
##   1 wild critters and the biome boss
##   2 a duel rival
## Hostility is "other team". Moves come from outside, one vector per hero.
## The launch game only feeds team 0 from the thumbstick.

const STEP_HINT := 1.0 / 60.0

var rng := RandomNumberGenerator.new()
var mode := Session.Mode.SOLO
var biome_id := "meadow"
var biome: Dictionary = {}
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
var events: Array = []
var actors: Array[Actor] = []
var heroes: Array[Actor] = []
## Solid obstacles (x, y, radius) in sim space: the boss arena's standing
## stones. Everything that walks steers around and slides along them.
var obstacles: Array[Vector3] = []
var shots: Array[Shot] = []
var gems: Array[Gem] = []
var pings: Array[Ping] = []
var boss: Actor = null
var slain := 0
var boss_mark := 0
var spawn_cd := 0.35
const MAX_MINIONS := 14
const PACK_SIZE := 8
## Packs are bigger and each critter softer than the old trickle, so a wave
## crowds the screen without changing how much XP a hunt pays.
const MINION_HP := 0.5
const MINION_XP := 0.7
## Ellipse just outside the hunt camera's view, in playfield pixels.
## What the far follow camera frames on the ground, relative to the hero
## (sim px; Stage3D DIST 34, FOV 40, AIM +1.5, pitch 58; tools: viewbox.py). The far edge is
## wider than the near one; the box takes the wider. Packs spawn just past it.
const VIEW_BOX := Rect2(-627.0, -1857.0, 1254.0, 2710.0)
const SPAWN_MARGIN := 24.0
## Heroes fight only when planted: moving is a clean run, and the first shot
## comes this long after the stick is released.
const PLANT := 0.08
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
const REVEAL := 980.0
const AGGRO_CAMP := 430.0
const AGGRO_PATROL := 380.0
const LEASH := 1500.0
## Loot chests on the map: {pos, tier, open}
var chests: Array = []
var loot_coins := 0
var boss_time := 0.0
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
	var shot_speed := 240.0
	var xp := 1
	var alive := true
	var flash := 0.0
	var iframes := 0.0
	var stats: Dictionary = {}
	var boss_state := ""
	var boss_timer := 0.0
	var boss_dir := Vector2.RIGHT
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
	# Explore: camps and patrols wait until the hero comes close.
	var camp := -1
	var home := Vector2.ZERO
	var aggro := true
	var patrol_a := Vector2.INF
	var patrol_b := Vector2.ZERO
	var to_b := true
	var elite := false


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


func start(session: Session, stats_for: Dictionary) -> void:
	rng.seed = session.seed if session.seed != 0 else randi()
	mode = session.mode
	biome_id = session.biome_id
	biome = Catalog.biome(biome_id)
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
	_move_heroes(dt, moves)
	_step_gems(dt)
	if _halt():
		return
	_hero_attacks()
	if _halt():
		return
	_step_minions(dt)
	if _halt():
		return
	_step_boss(dt)
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
		_step_explore(dt)
	else:
		_step_spawns(dt)
	_enrage_and_timeout()
	_compact()


func drain_events() -> Array:
	var out := events
	events = []
	return out


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
	events.append({"type": "boss_in", "name": boss.display if boss else "Boss", "shake": 0.5, "stop": 0.06})


func debug_slay_boss() -> void:
	if boss != null and boss.alive:
		_hurt(boss, 999999.0, boss.pos, false, null, false)


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
	hero.max_hp = float(stats["hp"])
	hero.hp = minf(hero.hp if hero.hp > 0.0 else hero.max_hp, hero.max_hp)
	hero.speed = float(stats["speed"])
	hero.dmg = float(stats["dmg"])
	hero.interval = float(stats["interval"])
	hero.range = float(stats["range"])
	hero.armor = float(stats["armor"])


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
	var stats := base.duplicate(true)
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
		hero.vel = _slide(hero, mv * hero.speed)
		var was := hero.pos
		hero.pos += hero.vel * dt
		_push_out(hero)
		if explore:
			# Slide along the forest edge; the body's speed is what it really moved.
			hero.pos = map.push_inside(hero.pos, hero.radius * 0.8)
			hero.vel = (hero.pos - was) / maxf(dt, 0.0001)
		if mv.length() > 0.08:
			hero.facing = mv.angle()
			hero.still = 0.0
		else:
			hero.still += dt
		hero.iframes = maxf(0.0, hero.iframes - dt)
		hero.flash = maxf(0.0, hero.flash - dt)
		hero.cd = maxf(0.0, hero.cd - dt)
		var regen := float(hero.stats.get("regen", 0.0))
		if regen > 0.0 and hero.hp < hero.max_hp:
			hero.hp = minf(hero.max_hp, hero.hp + regen * dt)
		_clamp_actor(hero)


func _hero_attacks() -> void:
	for hero in heroes:
		# Run or fight, never both: no shots and no aim-turning on the move.
		if not hero.alive or hero.cd > 0.0 or hero.still < PLANT:
			continue
		var target := nearest_hostile(hero, hero.range)
		if target == null:
			continue
		hero.aim = (target.pos - hero.pos).angle()
		hero.facing = hero.aim
		hero.cd = hero.interval
		events.append({
			"type": "attack",
			"id": hero.id,
			"role": hero.role,
			"pos": hero.pos,
			"facing": hero.aim,
			"range": hero.range,
		})
		if hero.role == "tank":
			_melee(hero, target)
			if int(hero.stats.get("bash", 0)) > 0:
				_bash(hero)
		else:
			_fan(hero, target)


func _melee(hero: Actor, primary: Actor) -> void:
	var crit := rng.randf() < float(hero.stats["crit"])
	var amount := float(hero.stats["dmg"]) * (float(hero.stats["crit_mult"]) if crit else 1.0)
	var ang := (primary.pos - hero.pos).angle()
	var reach := hero.range + 10.0
	var half := 1.2 + float(int(hero.stats.get("shots", 0))) * 0.2
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
		_hurt(actor, amount, hero.pos, crit, hero, false)
		if result != "":
			return
	events.append({"type": "swing", "pos": hero.pos, "facing": ang, "range": reach})


func _fan(hero: Actor, target: Actor) -> void:
	var count := 1 + int(hero.stats.get("shots", 0))
	var aim := target.pos
	var flight := float(hero.stats["proj_speed"])
	if flight > 1.0:
		var travel := clampf(hero.pos.distance_to(target.pos) / flight, 0.0, 0.42)
		aim = target.pos + target.vel * travel
	var base := (aim - hero.pos).angle()
	for i in count:
		var ang := base
		if count > 1:
			ang += lerpf(-0.22, 0.22, float(i) / float(count - 1))
		var crit := rng.randf() < float(hero.stats["crit"])
		var amount := float(hero.stats["dmg"]) * (float(hero.stats["crit_mult"]) if crit else 1.0)
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
		shot.splash = float(hero.stats["splash"]) if hero.role == "mage" else 0.0
		shot.splash_mul = float(hero.stats["splash_mul"])
		shot.pierce = int(hero.stats["pierce"])
		shot.bounce = int(hero.stats["bounce"])
		shot.kind = "orb" if hero.role == "mage" else "arrow"
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


func _step_minions(dt: float) -> void:
	var target := _focus_hero()
	if target == null:
		return
	for actor in actors:
		if not actor.alive or actor.kind != "minion":
			continue
		actor.flash = maxf(0.0, actor.flash - dt)
		actor.touch_cd = maxf(0.0, actor.touch_cd - dt)
		actor.cd = maxf(0.0, actor.cd - dt)
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
					actor.vel = dir * actor.speed
				elif dist < actor.range * (0.36 if explore else 0.55):
					# Backpedal only when crowded: a melee hero must be able
					# to close in on a shooter (it used to hold just out of reach).
					actor.vel = -dir * actor.speed
				else:
					actor.vel = Vector2(-dir.y, dir.x) * actor.speed * 0.6
				actor.vel = _steer(actor, actor.vel)
				actor.pos += actor.vel * dt
				if dist <= actor.range and actor.cd <= 0.0:
					actor.windup = SHOOT_WINDUP
					events.append({"type": "windup", "id": actor.id, "time": SHOOT_WINDUP})
		else:
			actor.vel = _steer(actor, dir * actor.speed)
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
	if boss.boss_state == "idle":
		var focus := _focus_hero()
		if focus != null:
			var delta := focus.pos - boss.pos
			var d := delta.length()
			if d > 168.0:
				var want := delta.normalized() * boss.speed
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
					want = (boss.side_dir * 0.85 + delta.normalized() * 0.3).normalized() * boss.speed
				boss.vel = _steer(boss, want)
				boss.pos += boss.vel * dt
				_push_out(boss)
				boss.facing = boss.vel.angle()
			else:
				boss.vel = Vector2.ZERO
				boss.best_d = d
				boss.stall_t = 0.0
		if boss.boss_timer <= 0.0:
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
			boss.boss_timer = 0.42 if enraged else 0.55
	elif boss.boss_state == "recover":
		if boss.boss_timer <= 0.0:
			boss.boss_state = "idle"
			boss.boss_timer = 0.18 if enraged else 0.42
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
	boss.attack = _pick_attack()
	boss.boss_state = "windup"
	events.append({"type": "windup", "id": boss.id, "time": 0.5})
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
	else:
		boss.boss_timer = 0.36


func _release_attack() -> void:
	events.append({"type": "attack", "id": boss.id})
	boss.boss_state = "act"
	if boss.attack == "charge":
		boss.boss_timer = 0.38
		boss.charge_cd = 0.0
		return
	if boss.attack == "fan":
		boss.boss_timer = 0.42
		var focus := _focus_hero()
		var origin := focus.pos if focus else boss.pos + Vector2.DOWN * 80.0
		var base := (origin - boss.pos).angle()
		for i in 5:
			var ang := base + lerpf(-0.58, 0.58, float(i) / 4.0)
			var dir := Vector2.RIGHT.rotated(ang)
			var shot := Shot.new()
			shot.team = boss.team
			shot.owner_id = boss.id
			shot.pos = boss.pos + dir * (boss.radius * 0.7)
			shot.prev = shot.pos
			shot.vel = dir * (320.0 if enraged else 255.0)
			shot.dmg = boss.shot_dmg * _rage()
			shot.radius = 11.0
			shot.ttl = 2.5
			shot.kind = "enemy"
			shots.append(shot)
		return
	boss.boss_timer = 0.12


func _pick_attack() -> String:
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
			if result != "":
				return
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
			shot.alive = false
			break
	if shots.size() > 56:
		while shots.size() > 48:
			shots.remove_at(0)


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
			_add_xp(gem.value)
			events.append({"type": "gem", "pos": gem.pos})


func _step_spawns(dt: float) -> void:
	if phase == "hunt" and time >= Catalog.BOSS_AT:
		phase = "boss"
		_spawn_boss()
		events.append({"type": "boss_in", "name": boss.display if boss else "Boss", "shake": 0.55, "stop": 0.07})
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
	actor.max_hp = float(info.get("hp", 30)) * float(biome["hp_mul"]) * MINION_HP
	actor.hp = actor.max_hp
	actor.speed = float(info.get("speed", 100))
	actor.dmg = float(info.get("dmg", 8)) * float(biome["dmg_mul"])
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
	var actor := Actor.new()
	actor.id = _nid()
	actor.team = 1
	actor.kind = "boss"
	actor.sprite = id
	actor.role = str(info.get("role", "tank"))
	actor.display = str(info.get("name", "Boss"))
	actor.radius = float(info.get("boss_radius", 76))
	actor.max_hp = float(info.get("boss_hp", 1400)) * mul
	actor.hp = actor.max_hp
	actor.speed = float(info.get("boss_speed", 70))
	actor.dmg = float(info.get("boss_touch", 16)) * mul
	actor.pos = map.lair if explore else map.boss_spawn(actor.radius)
	actor.prev = actor.pos
	actor.boss_state = "idle"
	actor.boss_timer = 0.9
	actor.bias_charge = float(info.get("bias_charge", 0.33))
	actor.bias_aoe = float(info.get("bias_aoe", 0.33))
	actor.aoe_dmg = float(info.get("aoe", 22)) * mul
	actor.charge_dmg = float(info.get("charge", 28)) * mul
	actor.shot_dmg = float(info.get("shot", 11)) * mul
	actors.append(actor)
	boss = actor
	boss_mark = 0
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


func _hurt(target: Actor, amount: float, from_pos: Vector2, crit: bool, attacker: Actor, allow_thorns: bool) -> void:
	if explore and target.kind == "minion" and not target.aggro:
		_set_camp_aggro(target, true)
	if target == null or not target.alive:
		return
	if target.kind == "hero" and target.iframes > 0.0:
		return
	var dealt := maxf(1.0, amount - target.armor)
	target.hp -= dealt
	target.flash = 0.1
	var kick_dir := target.pos - from_pos
	if kick_dir.length() < 0.01:
		kick_dir = Vector2.RIGHT
	else:
		kick_dir = kick_dir.normalized()
	var kick := 2.0 if target.kind == "boss" else (10.0 if target.kind == "hero" else 16.0)
	target.pos += kick_dir * kick
	if attacker != null and attacker.kind == "hero":
		var siphon := float(attacker.stats.get("siphon", 0.0))
		if siphon > 0.0 and attacker.alive:
			attacker.hp = minf(attacker.max_hp, attacker.hp + dealt * siphon)
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
	if target.hp <= 0.0 and target.alive:
		_kill(target)


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
		phase = "over"
		result = "win"
		paused = true
		events.append({"type": "boss_down", "id": actor.sprite, "name": actor.display, "shake": 0.9, "stop": 0.1})
		return
	if actor.team == 1:
		slain += 1
		_drop_gem(actor.pos, actor.xp)


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


func _halt() -> bool:
	if paused or result != "":
		_compact()
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
	for ci in map.camps.size():
		var camp: Dictionary = map.camps[ci]
		var at: Vector2 = camp["pos"]
		var count: int = camp["count"]
		var base := ci % skins.size()
		for k in count:
			var ang := TAU * float(k) / float(count) + rng.randf_range(-0.3, 0.3)
			var p := map.push_inside(at + Vector2.RIGHT.rotated(ang) * rng.randf_range(70.0, 150.0), 30.0)
			var skin := base if k % 2 == 0 else rng.randi() % skins.size()
			var m := _place_minion(skin, p, ci)
		if bool(camp["elite"]):
			var e := _place_minion(rng.randi() % skins.size(), at, ci)
			_make_elite(e)
	for pi in map.patrols.size():
		var pat: Dictionary = map.patrols[pi]
		var a: Vector2 = pat["a"]
		var b: Vector2 = pat["b"]
		var tag := 1000 + pi
		for k in int(pat["count"]):
			var m := _place_minion(rng.randi() % skins.size(), a + Vector2(rng.randf_range(-50, 50), rng.randf_range(-50, 50)), tag)
			m.patrol_a = a
			m.patrol_b = b
	for c in map.loot:
		chests.append({"pos": c["pos"], "tier": c["tier"], "open": false})


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
	m.xp = maxi(1, int(round(float(m.xp) * EXPLORE_XP * (1.0 + depth * 0.6))))
	return m


const EXPLORE_HP := 1.6
const EXPLORE_XP := 1.25


func _make_elite(m: Actor) -> void:
	m.elite = true
	m.max_hp *= 5.0
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
		actor.vel = to.normalized() * actor.speed * pace
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
		c["open"] = true
		var rare: bool = str(c["tier"]) == "rare"
		var value := (40 if rare else 18) + level * 2
		var coins := 40 if rare else 15
		loot_coins += coins
		for k in (9 if rare else 6):
			_drop_gem(c["pos"] + Vector2.RIGHT.rotated(TAU * k / 6.0) * rng.randf_range(40.0, 90.0), maxi(1, value / (9 if rare else 6)))
		hero.hp = minf(hero.max_hp, hero.hp + hero.max_hp * 0.2)
		events.append({"type": "loot", "pos": c["pos"], "tier": c["tier"], "coins": coins, "shake": 0.25})
	# The lair: walk in and the boss rises.
	if phase == "hunt" and hero.pos.distance_to(map.lair) < map.lair_r * 0.72:
		begin_boss()
		_add_t = 6.0


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
