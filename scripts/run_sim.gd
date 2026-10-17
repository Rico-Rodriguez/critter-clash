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
var shots: Array[Shot] = []
var gems: Array[Gem] = []
var pings: Array[Ping] = []
var boss: Actor = null
var boss_mark := 0
var spawn_cd := 0.35
var _next_id := 1
var bases: Dictionary = {}


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
	hero.pos = play.get_center() + Vector2(-70 if index > 0 else 0, 40 if index > 0 else 0)
	hero.prev = hero.pos
	hero.alive = true
	bases[hero.id] = stats.duplicate(true)
	hero.stats = stats.duplicate(true)
	_copy_combat(hero)
	hero.hp = hero.max_hp
	actors.append(hero)
	heroes.append(hero)
	if index == 0:
		_spawn_minion(0)
		_spawn_minion(0)


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
		hero.vel = mv * hero.speed
		hero.pos += hero.vel * dt
		if mv.length() > 0.08:
			hero.facing = mv.angle()
		hero.iframes = maxf(0.0, hero.iframes - dt)
		hero.flash = maxf(0.0, hero.flash - dt)
		hero.cd = maxf(0.0, hero.cd - dt)
		var regen := float(hero.stats.get("regen", 0.0))
		if regen > 0.0 and hero.hp < hero.max_hp:
			hero.hp = minf(hero.max_hp, hero.hp + regen * dt)
		_clamp_actor(hero)


func _hero_attacks() -> void:
	for hero in heroes:
		if not hero.alive or hero.cd > 0.0:
			continue
		var target := nearest_hostile(hero, hero.range)
		if target == null:
			continue
		hero.facing = (target.pos - hero.pos).angle()
		hero.cd = hero.interval
		events.append({
			"type": "attack",
			"id": hero.id,
			"role": hero.role,
			"pos": hero.pos,
			"facing": hero.facing,
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
	var dir := Vector2.RIGHT.rotated(hero.facing)
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
		actor.facing = dir.angle()
		if actor.archetype == "shooter":
			if dist > actor.range:
				actor.vel = dir * actor.speed
			elif dist < actor.range * 0.55:
				actor.vel = -dir * actor.speed
			else:
				actor.vel = Vector2(-dir.y, dir.x) * actor.speed * 0.6
			actor.pos += actor.vel * dt
			if dist <= actor.range and actor.cd <= 0.0:
				_enemy_shot(actor, target, actor.dmg, actor.shot_speed)
				actor.cd = actor.interval
		else:
			actor.vel = dir * actor.speed
			actor.pos += actor.vel * dt
		if actor.pos.distance_to(target.pos) < actor.radius + target.radius and actor.touch_cd <= 0.0:
			actor.touch_cd = 0.74
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
			if delta.length() > 168.0:
				boss.vel = delta.normalized() * boss.speed
				boss.pos += boss.vel * dt
				boss.facing = boss.vel.angle()
			else:
				boss.vel = Vector2.ZERO
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
			boss.pos += boss.vel * dt
			boss.facing = boss.boss_dir.angle()
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
	if _minion_count() >= 8:
		spawn_cd = 0.28
		return
	var wave := _wave()
	if wave.is_empty():
		spawn_cd = 0.4
		return
	var pool: Array = wave["pool"]
	_spawn_minion(int(pool[rng.randi() % pool.size()]))
	spawn_cd = float(wave["every"])


func _spawn_minion(skin_index: int) -> void:
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
	actor.pos = _edge_point()
	actor.prev = actor.pos
	actor.radius = float(info.get("radius", 24))
	actor.max_hp = float(info.get("hp", 30)) * float(biome["hp_mul"])
	actor.hp = actor.max_hp
	actor.speed = float(info.get("speed", 100))
	actor.dmg = float(info.get("dmg", 8)) * float(biome["dmg_mul"])
	actor.xp = int(info.get("xp", 2))
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
	actor.pos = Vector2(play.get_center().x, play.position.y + actor.radius + 8.0)
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
	for other in actors:
		if other.kind == "minion" and other.alive:
			other.alive = false
			events.append({"type": "die", "pos": other.pos, "radius": other.radius, "sprite": other.sprite, "kind": "minion"})


func _hurt(target: Actor, amount: float, from_pos: Vector2, crit: bool, attacker: Actor, allow_thorns: bool) -> void:
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
		phase = "tame"
		result = "win"
		paused = true
		events.append({"type": "boss_down", "id": actor.sprite, "name": actor.display, "shake": 0.9, "stop": 0.1})
		return
	if actor.team == 1:
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


func _edge_point() -> Vector2:
	var side := rng.randi() % 4
	match side:
		0:
			return Vector2(play.position.x + 8.0, rng.randf_range(play.position.y, play.end.y))
		1:
			return Vector2(play.end.x - 8.0, rng.randf_range(play.position.y, play.end.y))
		2:
			return Vector2(rng.randf_range(play.position.x, play.end.x), play.position.y + 8.0)
		_:
			return Vector2(rng.randf_range(play.position.x, play.end.x), play.end.y - 8.0)


func _clamp_actor(actor: Actor) -> void:
	actor.pos = _clamp_point(actor.pos, actor.radius)


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
		var keep := actor.alive or actor.kind == "hero" or (actor.kind == "boss" and phase == "tame")
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
