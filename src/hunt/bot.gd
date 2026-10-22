class_name HuntBot
extends RefCounted
## A simple autopilot for headless checks: kites the dead, walks out of
## telegraphs, picks up souls, dashes when cornered and fires its super into
## crowds. Good enough to prove the hunt can be won (and lost by standing still).

var hunt: Hunt
var idle := false
var _wander := Vector3.ZERO
var _side := 1.0
var _t := 0.0
# Dead-end escape: a wall and a pillar can trap the waypoint walker, which
# then dithers in place forever. Sample progress and sidestep out.
var _check_t := 2.0
var _check_p := Vector3.ZERO
var _escape_t := 0.0
var _escape := Vector3.ZERO
var _skip_loot_t := 0.0


func steer(dt: float) -> Vector2:
	if idle:
		return Vector2.ZERO
	_t -= dt
	var h := hunt.hero
	var p := h.flat_pos()
	_check_t -= dt
	_escape_t -= dt
	_skip_loot_t -= dt
	if _check_t <= 0.0:
		_check_t = 2.5
		var fighting := hunt.boss != null and hunt.boss.alive or hunt.nearest_foe(p, 9.0) != null
		if not fighting and p.distance_to(_check_p) < 1.2:
			# Toward the middle of the hall, with a random lean so a second
			# try differs from the first.
			_escape = Vector3(-signf(p.x) if absf(p.x) > 2.0 else randf_range(-1, 1), 0, randf_range(-0.8, 0.8)).normalized()
			_escape_t = 1.4
			_skip_loot_t = 6.0
		_check_p = p
	if _escape_t > 0.0:
		return Vector2(_escape.x, _escape.z)
	var melee: bool = h.def["style"] == "melee"
	var want := Vector3.ZERO
	var near := 0
	var close: Actor = null
	var cd := 99.0
	for f in hunt.foes:
		if not f.alive or f.state == "spawn":
			continue
		var d := p - f.flat_pos()
		var l := d.length()
		if l < cd:
			cd = l
			close = f
		if l < 3.2:
			near += 1
		var keep := 1.6 if melee else 4.5
		if l < keep + 1.5:
			var w := (keep + 1.5 - l) / (keep + 1.5) * (2.5 if f.state == "windup" else 1.0)
			want += d / maxf(l, 0.1) * w
	if not melee and near > 0:
		# Kite: away from the crowd's center, sliding around it, and back
		# toward open ground when a wall is close.
		var cen := Vector3.ZERO
		var cnt := 0
		for f in hunt.foes:
			if f.alive and f.state != "spawn" and p.distance_to(f.flat_pos()) < 6.0:
				cen += f.flat_pos()
				cnt += 1
		if cnt > 0:
			cen /= cnt
			var away := (p - cen).normalized()
			want += away * 1.5 + away.cross(Vector3.UP) * 0.8
	var mid := Vector3(0, 0, -4) - p
	# (On the Long Road the walls bound the hall; a pull to the middle only
	# fights the waypoint and parks the bot at the edge.)
	if hunt.mode != "trial" and (absf(p.x) > 15.0 or p.z > 15.0 or p.z < -24.0):
		want += mid.normalized() * 1.2
	# The Wilderness: stay inside the closing ring.
	if hunt.mode == "wild":
		var to_c := DB.WILD_CENTER - p
		if to_c.length() > hunt.ring_r - 3.5:
			want += to_c.normalized() * 3.5
	# Walk out of anything red on the ground.
	for e in hunt.fx._live:
		if str(e["kind"]) != "tele":
			continue
		var n: Node3D = e["node"]
		if not is_instance_valid(n) or not n.visible:
			continue
		var c := Vector3(n.position.x, 0, n.position.z)
		var r := maxf(n.scale.x, n.scale.z) + 1.0
		var d2 := p - c
		if d2.length() < r:
			want += d2.normalized() * 3.0
	# Sidestep projectiles that are about to hit, dash through the last ones.
	var threat := 0
	for pr in hunt.projs:
		if pr.team != 1 or not pr.active:
			continue
		var pp := Vector3(pr.position.x, 0, pr.position.z)
		var to_me := p - pp
		var v := Vector3(pr.vel.x, 0, pr.vel.z)
		var along := to_me.dot(v.normalized())
		if along <= 0.0 or along > 7.0:
			continue
		var side := to_me - v.normalized() * along
		if side.length() < 1.3:
			threat += 1
			var away := side.normalized() if side.length() > 0.05 else v.normalized().cross(Vector3.UP)
			want += away * 2.5
			if along < 2.0 and h.dash_cd <= 0.0:
				h.move_input = Vector2(away.x, away.z)
				h.try_dash()
	if hunt.boss and hunt.boss.alive and hunt.boss.state != "intro":
		var b := hunt.boss
		var to := b.flat_pos() - p
		var l2 := to.length()
		var ideal := 3.4 if melee else 8.6
		if b.pattern in ["quake", "cleave"] and b.state == "attack":
			ideal = 7.5
		if l2 > ideal + 0.5:
			want += to.normalized() * 1.2
		elif l2 < ideal - 0.5:
			want -= to.normalized() * 1.6
		want += to.cross(Vector3.UP).normalized() * 0.6
		if b.pattern == "charge" and b.state == "attack":
			want += b.charge_dir.cross(Vector3.UP).normalized() * signf(to.cross(b.charge_dir).y + 0.01) * 2.0
	else:
		# Go to the fight: the nearest foe, or loot.
		var goal: Vector3 = p
		var best := 99.0
		for pk in hunt.pickups:
			if _skip_loot_t <= 0.0 and is_instance_valid(pk) and pk.kind in ["soul", "item", "heart"]:
				var dd := p.distance_to(Vector3(pk.position.x, 0, pk.position.z))
				if dd < best and dd < 9.0 and _clear_line(p, Vector3(pk.position.x, 0, pk.position.z)):
					best = dd
					goal = Vector3(pk.position.x, 0, pk.position.z)
		if best > 8.0 and close:
			goal = close.flat_pos()
		var waypoint := best <= 8.0
		if best > 8.0 and close == null and hunt.mode == "trial":
			goal = hunt.trial_goal()
			waypoint = true
		if goal.distance_to(p) > (0.7 if waypoint else (1.4 if melee else 5.0)):
			var heading := (goal - p).normalized()
			if waypoint:
				heading = _around_obstacles(p, heading)
			want += heading * (1.0 if near < 3 else 0.4)
		if want.length() < 0.2:
			if _t <= 0.0 and hunt.mode != "trial":
				_t = 2.0
				_wander = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
				var center := Vector3(0, 0, -4) - p
				if center.length() > 10.0:
					_wander = center.normalized()
			want += _wander * 0.6
	if h.super_ready() and (near >= 3 or hunt.boss and hunt.boss.alive and hunt.boss.state != "intro" and p.distance_to(hunt.boss.flat_pos()) < 7.0):
		h.try_super()
	if h.hp < h.max_hp * 0.45:
		h.try_potion()
	if (near >= 4 or h.hp < h.max_hp * 0.35 and near >= 1) and h.dash_cd <= 0.0 and want.length() > 0.2:
		h.move_input = Vector2(want.x, want.z).normalized()
		h.try_dash()
	if want.length() > 1.0:
		want = want.normalized()
	return Vector2(want.x, want.z)


## Turns `dir` away from pillars and crates: the first clear heading among a
## fan of angles, keeping to one side so it does not dither.
func _around_obstacles(p: Vector3, dir: Vector3) -> Vector3:
	for a in [0.0, 35.0, 70.0, 105.0, 140.0]:
		for sgn in [_side, -_side]:
			var d := dir.rotated(Vector3.UP, deg_to_rad(a) * sgn)
			if not hunt.arena.blocked(p + d * 1.8, 0.7) and not hunt.arena.blocked(p + d * 3.4, 0.7):
				if a > 0.0:
					_side = sgn
				return d
			if a == 0.0:
				break
	return dir


## True when nothing solid sits between two points: a pickup behind a wall is
## not worth walking into the wall for.
func _clear_line(a: Vector3, b: Vector3) -> bool:
	var d := b - a
	var n := int(d.length() / 1.2)
	for i in range(1, n + 1):
		if hunt.arena.blocked(a + d * (float(i) / n), 0.4):
			return false
	return true
