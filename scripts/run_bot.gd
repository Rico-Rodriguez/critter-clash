class_name RunBot
extends RefCounted

## Steering brain with no scene-tree dependencies.
## The headless fight check uses it. A future duel can call steer() for the rival.


static func steer(sim: RunSim, index: int) -> Vector2:
	if index < 0 or index >= sim.heroes.size():
		return Vector2.ZERO
	var hero: RunSim.Actor = sim.heroes[index]
	if not hero.alive:
		return Vector2.ZERO
	var dodge := _dodge(sim, hero)
	var shots := _shots(sim, hero)
	_roll(sim, index, hero, dodge, shots)
	var crowd := _crowd(sim, hero)
	var aim := _kite(sim, hero)
	var wall := _wall(sim, hero)
	var chosen := aim
	var in_reach := sim.nearest_hostile(hero, hero.range * 0.8)
	if in_reach == null:
		# Nothing to shoot: sweep up dropped gems (they are the XP).
		var gem := _gem(sim, hero)
		if gem != Vector2.ZERO:
			chosen = gem
	if dodge.length() > 0.12:
		chosen = dodge
	elif shots.length() > 0.12:
		chosen = shots
	elif crowd.length() > 0.12 and hero.role != "tank" and hero.still > 0.6:
		# Heroes only fight planted: step out of a crowd after a volley or two.
		chosen = crowd
	elif chosen == Vector2.ZERO or (sim.nearest_hostile(hero, hero.range) != null and hero.still > 0.0 and hero.still < 0.6):
		return Vector2.ZERO
	chosen += wall * 0.9
	if chosen.length() > 1.0:
		return chosen.normalized()
	return chosen


## Modest dodge roll: only when a strike is already about to land on the hero
## (a slap or lane nearly expired, or a shot inside the hit window), never on
## every scare, so the bot fights still read as dangerous rather than perfect.
static func _roll(sim: RunSim, index: int, hero: RunSim.Actor, dodge: Vector2, shots: Vector2) -> void:
	if sim.dodge_ready(index) < 1.0:
		return
	var life := 1.0
	for ping in sim.pings:
		if not ping.alive:
			continue
		if ping.kind == "circle" and hero.pos.distance_to(ping.pos) < ping.radius + 14.0:
			life = minf(life, ping.life)
		elif ping.kind == "lane" and _in_lane(hero.pos, ping.pos, ping.dir, ping.length, ping.width):
			life = minf(life, ping.life)
	var impact := _shot_impact(sim, hero)
	if life >= 0.2 and impact >= 0.2:
		return
	var vec := dodge if dodge.length() > 0.12 else shots
	if vec.length() < 0.12:
		vec = Vector2.RIGHT.rotated(hero.facing + PI * 0.5)
	sim.dodge(index, vec)


static func _shot_impact(sim: RunSim, hero: RunSim.Actor) -> float:
	var best := 1.0
	for shot in sim.shots:
		if not shot.alive or shot.team == hero.team:
			continue
		var speed := shot.vel.length()
		if speed < 8.0:
			continue
		var rel := hero.pos - shot.pos
		if shot.vel.dot(rel) <= 0.0:
			continue
		var t := clampf(rel.length() / speed, 0.0, 1.0)
		if t >= best:
			continue
		var future := shot.pos + shot.vel * t
		if future.distance_to(hero.pos) > shot.radius + hero.radius + 22.0:
			continue
		best = t
	return best


static func _gem(sim: RunSim, hero: RunSim.Actor) -> Vector2:
	var best := Vector2.ZERO
	var best_d := 700.0
	for gem in sim.gems:
		if not gem.alive:
			continue
		var d := hero.pos.distance_to(gem.pos)
		if d < best_d:
			best_d = d
			best = (gem.pos - hero.pos).normalized()
	return best


static func _dodge(sim: RunSim, hero: RunSim.Actor) -> Vector2:
	var best := Vector2.ZERO
	var best_life := 0.95
	for ping in sim.pings:
		if not ping.alive:
			continue
		if ping.kind == "circle":
			var dist := hero.pos.distance_to(ping.pos)
			if dist < ping.radius + 14.0 and ping.life < best_life:
				best_life = ping.life
				var away := hero.pos - ping.pos
				if away.length() < 6.0:
					away = Vector2.RIGHT.rotated(hero.facing + 1.2)
				best = away.normalized()
		elif ping.kind == "lane" and _in_lane(hero.pos, ping.pos, ping.dir, ping.length, ping.width):
			if ping.life < best_life:
				best_life = ping.life
				var rel := hero.pos - ping.pos
				var along := rel.dot(ping.dir)
				var side := rel - ping.dir * along
				if side.length() < 1.0:
					side = Vector2(-ping.dir.y, ping.dir.x)
				best = side.normalized()
	if sim.boss != null and sim.boss.alive and sim.boss.boss_state == "act" and sim.boss.attack == "charge":
		var rel := hero.pos - sim.boss.pos
		var along := rel.dot(sim.boss.boss_dir)
		if along > 0.0 and along < 280.0:
			var side := rel - sim.boss.boss_dir * along
			if side.length() < sim.boss.radius + hero.radius + 10.0:
				if side.length() < 1.0:
					side = Vector2(-sim.boss.boss_dir.y, sim.boss.boss_dir.x)
				best = side.normalized()
	return best


static func _shots(sim: RunSim, hero: RunSim.Actor) -> Vector2:
	var best := Vector2.ZERO
	var best_t := 0.42
	for shot in sim.shots:
		if not shot.alive or shot.team == hero.team:
			continue
		var speed := shot.vel.length()
		if speed < 8.0:
			continue
		var rel := hero.pos - shot.pos
		if shot.vel.dot(rel) <= 0.0:
			continue
		var t := clampf(rel.length() / speed, 0.0, 0.42)
		if t >= best_t:
			continue
		var future := shot.pos + shot.vel * t
		if future.distance_to(hero.pos) > shot.radius + hero.radius + 22.0:
			continue
		best_t = t
		var side := Vector2(-shot.vel.y, shot.vel.x).normalized()
		if side.dot(rel) < 0.0:
			side = -side
		best = side
	return best


static func _crowd(sim: RunSim, hero: RunSim.Actor) -> Vector2:
	var push := Vector2.ZERO
	var close := 0
	for actor in sim.actors:
		if not actor.alive or actor.team == hero.team:
			continue
		var delta := hero.pos - actor.pos
		var dist := delta.length()
		var touch := hero.radius + actor.radius + 36.0
		if dist > touch or dist < 0.001:
			continue
		close += 1
		push += delta / dist * (touch - dist) / touch
	if close == 0:
		return Vector2.ZERO
	return push.normalized()


static func _kite(sim: RunSim, hero: RunSim.Actor) -> Vector2:
	var foe := sim.nearest_hostile(hero, 1400.0)
	if foe == null:
		var center := sim.play.get_center() - hero.pos
		if center.length() < 24.0:
			return Vector2.ZERO
		return center.normalized() * 0.4
	var delta := foe.pos - hero.pos
	var dist := delta.length()
	if dist < 0.001:
		return Vector2.RIGHT
	var dir := delta / dist
	var prefer := hero.range * (0.9 if hero.role == "tank" else 0.78)
	if hero.role == "tank":
		if dist > prefer:
			return dir
		if dist < hero.radius + foe.radius + 14.0:
			return -dir
		# In reach: plant and swing (heroes only attack standing still).
		return Vector2.ZERO
	if dist > prefer + 36.0:
		return dir
	if dist < prefer - 28.0:
		return -dir
	# In the band: plant and shoot.
	return Vector2.ZERO


static func _wall(sim: RunSim, hero: RunSim.Actor) -> Vector2:
	var margin := 78.0
	var push := Vector2.ZERO
	if hero.pos.x < sim.play.position.x + margin:
		push.x += 1.0
	if hero.pos.x > sim.play.end.x - margin:
		push.x -= 1.0
	if hero.pos.y < sim.play.position.y + margin:
		push.y += 1.0
	if hero.pos.y > sim.play.end.y - margin:
		push.y -= 1.0
	return push


static func _in_lane(pos: Vector2, origin: Vector2, dir: Vector2, length: float, width: float) -> bool:
	var rel := pos - origin
	var along := rel.dot(dir)
	if along < -12.0 or along > length:
		return false
	var side := (rel - dir * along).length()
	return side < width + 20.0


## The bot clears camps and chests only for this long before it heads for the
## lair, so a sprawling map never turns into an endless loot detour.
const CLEAR_CAP := 240.0
## A body that barely moves over this window (px) is stalled, not walking.
const PROBE_SECONDS := 1.5
const PROBE_TRAVEL := 45.0
## How long a stalled bot ignores gems so the flow walk can carry it clear.
const DETOUR_SECONDS := 2.5
## Turns sampled when following the flow field: the straight grid step can cut
## through a forest pinch the body cannot cross, so nearby headings are tried.
const TURNS := [0.0, 0.3, -0.3, 0.6, -0.6, 0.95, -0.95, 1.3, -1.3, 1.65, -1.65, 2.0, -2.0, 2.4, -2.4, PI]


## Flow field toward `goal`, memoised per map cell for the life of one fight.
## A field is a pure function of the goal's cell, so a cache hit is bit-for-bit
## the same array the BFS would rebuild; `mem` is per run, so nothing leaks.
static func _goal_field(sim: RunSim, mem: Dictionary, goal: Vector2) -> PackedInt32Array:
	if not mem.has("fields"):
		mem["fields"] = {}
	var fields: Dictionary = mem["fields"]
	var cell := sim.map.cell_index(goal)
	if not fields.has(cell):
		fields[cell] = sim.map.flow(goal)
	return fields[cell]


## Explore bot: fights what is close or has aggro, sweeps gems, and
## otherwise walks the flow field to the nearest live camp or unopened chest,
## then to the boss lair. `mem` keeps its route between calls.
static func explore_steer(sim: RunSim, index: int, mem: Dictionary) -> Vector2:
	if index >= sim.heroes.size() or not sim.heroes[index].alive:
		return Vector2.ZERO
	var hero: RunSim.Actor = sim.heroes[index]
	var threat := false
	for a in sim.actors:
		if a.alive and a.team != hero.team and (a.aggro or a.kind == "boss"):
			var d := a.pos.distance_to(hero.pos)
			if d < 650.0:
				threat = true
				break
	if threat or sim.nearest_hostile(hero, hero.range * 0.9) != null:
		var mv := steer(sim, index)
		if mv != Vector2.ZERO and sim.explore:
			# Don't kite into the trees: blend toward open ground.
			var ahead := hero.pos + mv * 90.0
			if sim.map.depth(ahead) < hero.radius:
				var back := sim.map.push_inside(ahead, hero.radius * 2.0) - hero.pos
				mv = (mv + back.normalized() * 1.2).normalized()
		return mv
	# A stall (a forest pinch, or a gem-versus-goal tug-of-war) is measured from
	# how far the body actually travelled. While detouring, gems are ignored so
	# the flow walk can carry the bot clear.
	var detour := _stuck(hero, mem)
	var gem := _gem(sim, hero)
	if not detour and gem != Vector2.ZERO and _lane_open(sim, hero, gem):
		return gem
	mem["t"] = float(mem.get("t", 0.0)) - 1.0 / 60.0
	if float(mem["t"]) <= 0.0 or not mem.has("goal"):
		mem["t"] = 1.0
		_choose_goal(sim, hero, mem)
	var goal_at: Vector2 = mem["goal"]
	if hero.pos.distance_to(goal_at) < 120.0:
		return (goal_at - hero.pos).normalized() if hero.pos.distance_to(goal_at) > 30.0 else Vector2.ZERO
	var step := _flow_step(sim, hero, mem["field"])
	if step == Vector2.ZERO:
		return (goal_at - hero.pos).normalized()
	return step


## Watch how far the body really travels. A grid pinch or a gem-versus-goal
## tug-of-war can freeze it in place; a stall opens a short gem-free detour so
## the flow walk breaks the loop instead.
static func _stuck(hero: RunSim.Actor, mem: Dictionary) -> bool:
	if float(mem.get("detour", 0.0)) > 0.0:
		mem["detour"] = float(mem["detour"]) - 1.0 / 60.0
		return true
	if not mem.has("probe_pos"):
		mem["probe_pos"] = hero.pos
		mem["probe_t"] = 0.0
		return false
	var t := float(mem.get("probe_t", 0.0)) + 1.0 / 60.0
	mem["probe_t"] = t
	if t < PROBE_SECONDS:
		return false
	var moved := hero.pos.distance_to(mem["probe_pos"] as Vector2)
	mem["probe_pos"] = hero.pos
	mem["probe_t"] = 0.0
	if moved >= PROBE_TRAVEL:
		return false
	mem["detour"] = DETOUR_SECONDS
	return true


## Pick the next objective: the nearest unopened chest or waiting camp while
## there is still time to level, otherwise the boss lair. Goals the flow field
## marks unreachable, or that recently stalled the bot, are skipped.
static func _choose_goal(sim: RunSim, hero: RunSim.Actor, mem: Dictionary) -> void:
	var from_hero := sim.map.flow(hero.pos)
	var goal := sim.map.lair
	var best := 1 << 30
	# A depth zone is a walk: the far gate is the goal, so the bot stops
	# collecting and heads north early. A single-screen hunt has the time
	# to pick everything up first.
	var cap := 60.0 if sim.zone_mode else CLEAR_CAP
	if sim.time < cap:
		for c in sim.chests:
			if bool(c["open"]):
				continue
			# A chest under the hero's own feet is not a walk: skip it, or
			# the bot stands on its goal and never moves again.
			if (c["pos"] as Vector2).distance_to(hero.pos) < 80.0:
				continue
			var d := from_hero[sim.map.cell_index(c["pos"])]
			if d >= 0 and d < best:
				best = d
				goal = c["pos"]
		for a in sim.actors:
			if a.alive and a.kind == "minion" and not a.aggro and not a.goblin:
				if a.pos.distance_to(hero.pos) < 80.0:
					continue
				var d := from_hero[sim.map.cell_index(a.pos)]
				if d >= 0 and d < best:
					best = d
					goal = a.pos
	if not mem.has("goal") or (mem["goal"] as Vector2).distance_to(goal) > 60.0:
		mem["goal"] = goal
		mem["field"] = _goal_field(sim, mem, goal)


## Downhill step along the flow field, but only down a lane the body can really
## cross: sample small turns and take the open heading closest to the flow.
static func _flow_step(sim: RunSim, hero: RunSim.Actor, field: PackedInt32Array) -> Vector2:
	var way := sim.map.downhill(field, hero.pos)
	if way == Vector2.INF:
		return Vector2.ZERO
	var base := (way - hero.pos).normalized()
	var reach := maxf(hero.radius * 2.0, 40.0)
	var best := Vector2.ZERO
	var best_score := 1.0e9
	for turn in TURNS:
		var dir := base.rotated(float(turn))
		if not _lane_open(sim, hero, dir):
			continue
		var f := field[sim.map.cell_index(hero.pos + dir * reach)]
		if f < 0:
			continue
		var score := float(f) + absf(float(turn)) * 1.5
		if score < best_score:
			best_score = score
			best = dir
	if best != Vector2.ZERO:
		return best
	# The pathing does not reach this spot: the body is in a pinch the grid
	# does not know, and every lane the field offers is closed. Walk into
	# the open ground instead, so the body gets out of the pinch and the
	# field can pick it up again.
	return _deepest_dir(sim, hero)


## The heading that leads to the most open ground: the way out of a pinch.
static func _deepest_dir(sim: RunSim, hero: RunSim.Actor) -> Vector2:
	var best := Vector2.ZERO
	var best_depth := sim.map.depth(hero.pos)
	var reach := maxf(hero.radius * 2.0, 40.0)
	for k in 8:
		var dir := Vector2.RIGHT.rotated(TAU * float(k) / 8.0)
		var d := sim.map.depth(hero.pos + dir * reach)
		if d > best_depth:
			best_depth = d
			best = dir
	return best


## True when the next couple of body-lengths along `dir` stay on open ground.
## A body already hugging a pinch gets near-field samples too: a shallow lip
## right in front of it would pin it against push_inside even though the ground
## opens up further along the ray. Bodies in open ground keep the cheap test,
## so normal travel is not slowed down by detours around passable lips.
static func _lane_open(sim: RunSim, hero: RunSim.Actor, dir: Vector2) -> bool:
	var r := hero.radius * 0.8
	var ks := [0.5, 1.0, 1.5, 2.0] if sim.map.depth(hero.pos) > r + 4.0 else [0.15, 0.3, 0.5, 0.8, 1.2, 1.6, 2.0]
	for k in ks:
		if sim.map.depth(hero.pos + dir * (r * float(k))) < r:
			return false
	return true
