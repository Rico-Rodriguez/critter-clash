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
	var gem := _gem(sim, hero)
	if gem != Vector2.ZERO:
		return gem
	mem["t"] = float(mem.get("t", 0.0)) - 1.0 / 60.0
	if float(mem["t"]) <= 0.0 or not mem.has("field"):
		mem["t"] = 1.0
		var from_hero := sim.map.flow(hero.pos)
		var goal := sim.map.lair
		var best := 1 << 30
		for c in sim.chests:
			if bool(c["open"]):
				continue
			var d := from_hero[sim.map.cell_index(c["pos"])]
			if d >= 0 and d < best:
				best = d
				goal = c["pos"]
		for a in sim.actors:
			if a.alive and a.kind == "minion" and not a.aggro:
				var d := from_hero[sim.map.cell_index(a.pos)]
				if d >= 0 and d < best:
					best = d
					goal = a.pos
		if not mem.has("goal") or (mem["goal"] as Vector2).distance_to(goal) > 60.0:
			mem["goal"] = goal
			mem["field"] = sim.map.flow(goal)
	var goal_at: Vector2 = mem["goal"]
	if hero.pos.distance_to(goal_at) < 120.0:
		return (goal_at - hero.pos).normalized() if hero.pos.distance_to(goal_at) > 30.0 else Vector2.ZERO
	var way := sim.map.downhill(mem["field"], hero.pos)
	if way == Vector2.INF:
		return (goal_at - hero.pos).normalized()
	return (way - hero.pos).normalized()
