class_name MovieDirector
extends Node

## Scripted clips for motion review. Run with Godot's movie writer, e.g.
##   godot --write-movie out.avi --fixed-fps 30 --resolution 720x1560 -- --movie=hunt
## Clips: hunt (joystick pivots, moving, a pack fight, gem pickup), boss (the
## slam intro), tour (home -> collection -> road -> home -> HUNT press).

var app: Node


func run(host: Node, clip: String) -> void:
	app = host
	SaveGame.reset_new()
	SaveGame.data["trophies"] = 46
	SaveGame.data["coins"] = 135
	SaveGame.data["heroes"]["ember"]["cards"] = 8
	SaveGame.data["chests"].append({"kind": "hunt", "biome": "meadow", "seed": 3})
	match clip:
		"hunt":
			await _hunt()
		"loot":
			await _loot()
		"boss":
			await _boss()
		"profile":
			await _profile()
		"home":
			await _home()
		"walk_ember", "walk_juniper", "walk_pebble":
			await _walk(clip.trim_prefix("walk_"))
		_:
			await _tour()
	get_tree().quit()


## Home idle: the pedestal hero breathing, wings and UI shimmer, 7 s.
func _home() -> void:
	app.go("home")
	await _wait(7.0)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _run_screen() -> Node:
	var hero := OS.get_environment("CC_HERO") if OS.has_environment("CC_HERO") else "ember"
	if hero != "ember":
		SaveGame.hero(hero)["unlocked"] = true
	app.go("run", {"biome": "meadow", "hero": hero, "seed": 11})
	await _wait(0.6)
	return app.current


# --- Joystick: real touch events into the run screen ------------------------
var _finger_at := Vector2.ZERO
const STICK_HOME := Vector2(360, 1180)


func _touch(run: Node, at: Vector2, down: bool) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = 0
	ev.position = at
	ev.pressed = down
	run._input(ev)
	_finger_at = at


func _drag(run: Node, at: Vector2) -> void:
	var ev := InputEventScreenDrag.new()
	ev.index = 0
	ev.position = at
	ev.relative = at - _finger_at
	run._input(ev)
	_finger_at = at


## Hold the stick toward `dir` for `seconds`, easing the thumb over a few frames.
func _hold(run: Node, dir: Vector2, seconds: float, throw := 70.0) -> void:
	var target := STICK_HOME + dir.normalized() * throw
	var start := _finger_at
	for i in 4:
		_drag(run, start.lerp(target, float(i + 1) / 4.0))
		await get_tree().process_frame
	var t := 0.0
	while t < seconds:
		await get_tree().process_frame
		t += get_process_delta_time()
		_drag(run, target + Vector2(sin(t * 9.0), cos(t * 7.0)) * 1.5)


## Feel log: every frame, the hero's and boss's positions and the stick.
## _feel_report() turns it into slide (distance carried along the old
## heading after a hard reversal) and snag (boss stalled while chasing).
var _log: Array = []
var _logging := false
var _stick_dir := Vector2.ZERO
var _reversals: Array = []
var _release_t: Array = []
## Game time (sums frame deltas) so the log is right under the movie writer.
var _gt := 0.0


func _start_log(run: Node) -> void:
	_logging = true
	_log.clear()
	while _logging and is_instance_valid(run):
		var row := {"t": _gt, "stick": _stick_dir}
		var h = run.sim.heroes[0]
		row["hero"] = h.pos
		row["hero_alive"] = h.alive
		row["cd"] = h.cd
		for a in run.sim.actors:
			if a.kind == "boss" and a.alive:
				row["boss"] = a.pos
				row["boss_state"] = a.boss_state
		_log.append(row)
		await get_tree().process_frame
		_gt += get_process_delta_time()


## Snap the thumb straight across (no easing): a hard 180.
func _snap(run: Node, dir: Vector2, seconds: float) -> void:
	_reversals.append({"t": _gt, "dir": dir.normalized(), "from": _stick_dir})
	_drag(run, STICK_HOME + dir.normalized() * 70.0)
	_stick_dir = dir.normalized()
	var t := 0.0
	while t < seconds:
		await get_tree().process_frame
		t += get_process_delta_time()


func _feel_report() -> void:
	_logging = false
	for rev in _reversals:
		var t0: float = rev["t"]
		var old: Vector2 = rev["from"]
		var start: Vector2 = Vector2.INF
		var carried := 0.0
		var turn_frames := -1
		var prev := Vector2.INF
		var k := 0
		for row in _log:
			if row["t"] < t0:
				continue
			if start == Vector2.INF:
				start = row["hero"]
				prev = start
				continue
			var step: Vector2 = row["hero"] - prev
			prev = row["hero"]
			k += 1
			carried = maxf(carried, (row["hero"] - start).dot(old))
			if turn_frames < 0 and step.length() > 0.5 and step.normalized().dot(rev["dir"]) > 0.95:
				turn_frames = k
			if k > 30:
				break
		print("FEEL reversal dir=%s slide_px=%.1f frames_to_new_heading=%d" % [str(rev["dir"]), carried, turn_frames])
	# Plant: from letting go to the first swing (cd jumps up), and how far
	# the hero carries on after the release.
	for t0 in _release_t:
		var prev_cd := 999.0
		var swing := -1.0
		var p0 := Vector2.INF
		var drift := 0.0
		for row in _log:
			if row["t"] < t0:
				prev_cd = row["cd"]
				continue
			if p0 == Vector2.INF:
				p0 = row["hero"]
			if row["t"] - t0 < 0.5:
				drift = maxf(drift, (row["hero"] - p0).length())
			if swing < 0.0 and float(row["cd"]) > prev_cd + 0.01:
				swing = row["t"] - t0
			prev_cd = row["cd"]
			if row["t"] - t0 > 2.0:
				break
		print("FEEL plant release_to_swing_s=%.3f drift_px=%.1f" % [swing, drift])
	# Boss snag: 0.5 s windows while it is chasing and far from the hero.
	var stalls := 0
	var windows := 0
	var worst := 99999.0
	var i := 0
	while i < _log.size():
		var a: Dictionary = _log[i]
		var j := i
		while j < _log.size() and _log[j]["t"] - a["t"] < 0.5:
			j += 1
		if j >= _log.size():
			break
		var b: Dictionary = _log[j]
		if a.has("boss") and b.has("boss") and str(a["boss_state"]) == "idle" and str(b["boss_state"]) == "idle" and (a["boss"] - a["hero"]).length() > 260.0:
			windows += 1
			var moved: float = (b["boss"] - a["boss"]).length()
			worst = minf(worst, moved)
			if moved < 20.0:
				stalls += 1
		i = j
	print("FEEL boss chase_windows=%d stalls=%d min_move_px=%.1f" % [windows, stalls, worst if windows > 0 else 0.0])


func _hunt() -> void:
	var run := await _run_screen()
	_start_log(run)
	await _wait(0.8)
	_touch(run, STICK_HOME, true)
	await _hold(run, Vector2(0, -1), 1.2)
	_stick_dir = Vector2(0, -1)
	# Hard 180s in the starting clearing: the thumb snaps straight across.
	await _snap(run, Vector2(0, 1), 0.9)
	await _snap(run, Vector2(0, -1), 0.9)
	await _snap(run, Vector2(1, 0), 0.7)
	await _snap(run, Vector2(-1, 0), 0.7)
	# Explore: the thumb follows the bot's route, letting go to fight.
	var mem := {}
	var t := 0.0
	var down := true
	var showed_map := false
	while t < 40.0 and run.sim.heroes[0].alive and run.sim.phase == "hunt":
		if run._modal_up:
			# Level up: read the cards a beat, then take one.
			if down:
				_touch(run, _finger_at, false)
				down = false
			await _wait(1.0)
			run._pick(int(t) % 3)
			await _wait(0.3)
			continue
		if not showed_map and t > 22.0 and not down:
			# Tap the corner map open to show what has been explored, then close.
			showed_map = true
			run.minimap.toggle()
			await _wait(2.5)
			run.minimap.toggle()
			await _wait(0.3)
			continue
		var dir: Vector2 = RunBot.explore_steer(run.sim, 0, mem)
		if dir.length() < 0.2:
			if down:
				_touch(run, _finger_at, false)
				_release_t.append(_gt)
				_stick_dir = Vector2.ZERO
				down = false
		else:
			if not down:
				_touch(run, STICK_HOME, true)
				down = true
			_stick_dir = dir.normalized()
			_drag(run, STICK_HOME + _stick_dir * 70.0)
		await get_tree().process_frame
		t += get_process_delta_time()
	if down:
		_touch(run, _finger_at, false)
	# Skip ahead to the lair mouth and walk in: the boss rises.
	var hero = run.sim.heroes[0]
	var lair: Vector2 = run.sim.map.lair
	hero.pos = run.sim.map.push_inside(lair + (hero.pos - lair).normalized() * run.sim.map.lair_r * 1.15, hero.radius)
	hero.iframes = 3.0
	await _wait(1.0)
	_touch(run, STICK_HOME, true)
	await _hold(run, lair - hero.pos, 1.6)
	_touch(run, _finger_at, false)
	_release_t.append(_gt)
	await _wait(5.0)
	_feel_report()


## ~15 s hunt for the gear proof: a fight, then pieces drop as tier beams
## (iron, blackened steel, rune pillar) ahead of the hero, who walks through
## them and picks them up (collapse + streak + name), then fights on. The
## drops are staged through the sim's own ground-loot list so the real
## pickup rule (reach or magnet delay) fires.
func _loot() -> void:
	var run := await _run_screen()
	await _wait(0.6)
	_touch(run, STICK_HOME, true)
	await _hold(run, Vector2(0.3, -1), 2.2)
	_touch(run, _finger_at, false)
	await _wait(2.0)
	var sim = run.sim
	var hero = sim.heroes[0]
	var hid := str(hero.sprite)
	var ahead := [[Vector2(-70, -150), "%s.boots.1" % hid], [Vector2(60, -230), "%s.helm.2" % hid], [Vector2(0, -330), "%s.weapon.3" % hid]]
	for i in ahead.size():
		var at: Vector2 = sim._clamp_point(hero.pos + ahead[i][0], 24.0)
		var key := "movie%d" % i
		sim.gear_found.append(ahead[i][1])
		# Long magnet delay so the beams stand until the hero walks in.
		sim.gear_ground.append({"key": key, "item": ahead[i][1], "pos": at, "t": sim.time + 30.0})
		sim.events.append({"type": "gear_drop", "item": ahead[i][1], "key": key, "tier": int(str(ahead[i][1]).get_slice(".", 2)), "pos": at})
	await _wait(1.8)
	_touch(run, STICK_HOME, true)
	await _hold(run, Vector2(0, -1), 2.6)
	_touch(run, _finger_at, false)
	await _wait(1.2)
	_touch(run, STICK_HOME, true)
	await _hold(run, Vector2(1, -0.4), 1.6)
	_touch(run, _finger_at, false)
	await _wait(2.4)


## 22 s of unbroken walking on the explore map: the thumb follows the
## route (never let go, so no attacks), with turns and two hard 180s. Each
## frame logs whether the hero is moving and whether its locomotion clip
## is actually advancing, so a clip that stops (the old LOOP_NONE slide)
## shows up as frozen_anim frames.
func _walk(hero_id: String) -> void:
	app.go("run", {"biome": "meadow", "hero": hero_id, "seed": 11})
	await _wait(0.6)
	var run: Node = app.current
	var sim = run.sim
	sim.heroes[0].iframes = 999.0
	var st: Stage3D = run.stage
	var mem := {}
	_touch(run, STICK_HOME, true)
	var t := 0.0
	var frames := 0
	var moving := 0
	var frozen := 0
	var worst_run := 0
	var run_len := 0
	var last_pos := -1.0
	var states := {}
	while t < 22.0:
		var dir: Vector2 = RunBot.explore_steer(sim, 0, mem)
		# Ignore fights: keep walking the route toward the next goal.
		if mem.has("field"):
			var way: Vector2 = sim.map.downhill(mem["field"], sim.heroes[0].pos)
			if way != Vector2.INF:
				dir = (way - sim.heroes[0].pos).normalized()
		if t > 8.0 and t < 8.6 or t > 15.0 and t < 15.6:
			dir = -_stick_dir if _stick_dir != Vector2.ZERO else Vector2(0, 1)
		elif dir.length() > 0.2:
			_stick_dir = dir.normalized()
		else:
			dir = _stick_dir if _stick_dir != Vector2.ZERO else Vector2(0, -1)
		_drag(run, STICK_HOME + dir.normalized() * 70.0)
		await get_tree().process_frame
		t += get_process_delta_time()
		frames += 1
		var h = sim.heroes[0]
		if not st._bodies.has(h.id):
			continue
		var body: Node3D = st._bodies[h.id]
		var player: AnimationPlayer = body.get_meta("player")
		var state := str(body.get_meta("state", ""))
		states[state] = int(states.get(state, 0)) + 1
		if h.vel.length() > 18.0 and t > 0.5:
			moving += 1
			var pos := player.current_animation_position if player != null and player.is_playing() else -2.0
			if player != null and (not player.is_playing() or is_equal_approx(pos, last_pos)):
				frozen += 1
				run_len += 1
				worst_run = maxi(worst_run, run_len)
			else:
				run_len = 0
			last_pos = pos
	_touch(run, _finger_at, false)
	print("FEEL walk hero=%s frames=%d moving=%d frozen_anim=%d worst_frozen_run=%d states=%s" % [hero_id, frames, moving, frozen, worst_run, str(states)])


func _boss() -> void:
	var run := await _run_screen()
	_start_log(run)
	await _wait(0.6)
	run.sim.begin_boss()
	await _wait(4.0)
	# Kite the boss around the ring: it has to steer past the stones.
	_touch(run, STICK_HOME, true)
	for d in [Vector2(-1, 0.3), Vector2(0, 1), Vector2(1, 0.4), Vector2(1, -0.6), Vector2(-0.4, -1), Vector2(-1, 0)]:
		await _hold(run, d, 1.1)
	_touch(run, _finger_at, false)
	await _wait(1.5)
	await _wait(0.6)
	_feel_report()


# --- Tour: real mouse presses on the nav bar and the HUNT button ------------
func _click(at: Vector2, hold := 0.14) -> void:
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.position = at
	down.global_position = at
	down.pressed = true
	Input.parse_input_event(down)
	await _wait(hold)
	var up := down.duplicate() as InputEventMouseButton
	up.pressed = false
	Input.parse_input_event(up)


func _tab(index: int) -> Vector2:
	var view := get_viewport().get_visible_rect().size
	var pad := float(UiKit.safe_insets()["b"])
	return Vector2(view.x / 4.0 * (index + 0.5), view.y - pad - 60.0)


func _find_text(root: Node, text: String) -> Control:
	for child in root.get_children():
		if child is BaseButton and str(child.get("text")) == text:
			return child
		var hit := _find_text(child, text)
		if hit != null:
			return hit
	return null


func _tour() -> void:
	app.go("home")
	await _wait(2.2)
	await _click(_tab(0))
	await _wait(2.0)
	await _click(_tab(2))
	await _wait(2.4)
	await _click(_tab(1))
	await _wait(1.8)
	var hunt := _find_text(app.current, "HUNT")
	if hunt != null:
		await _click(hunt.get_global_rect().get_center(), 0.35)
	await _wait(1.8)


# --- Profile: a pack fight then the boss, sampling render stats each frame --
func _profile() -> void:
	var run := await _run_screen()
	await _wait(1.0)
	var sim = run.sim
	var hero = sim.heroes[0]
	# Explore: walk the route through the dense forest with fog live.
	var e := await _sample_route(run, 6.0)
	# Pack: close on the biggest nearby camp so it aggroes on screen.
	var best: Vector2 = sim.map.camps[0]["pos"]
	for c in sim.map.camps:
		if (c["pos"] as Vector2).distance_to(hero.pos) < best.distance_to(hero.pos) and (c["pos"] as Vector2).distance_to(sim.map.start) > 600.0:
			best = c["pos"]
	hero.pos = sim.map.push_inside(best + Vector2(0, 420), hero.radius)
	hero.iframes = 30.0
	await _wait(0.5)
	_touch(run, STICK_HOME, true)
	var a := await _sample(run, 4.0, Vector2(0.2, -1))
	_touch(run, _finger_at, false)
	_minion_census(run)
	var lair: Vector2 = sim.map.lair
	hero.pos = sim.map.push_inside(lair + Vector2(0, sim.map.lair_r * 0.5), hero.radius)
	await _wait(3.0)
	if sim.phase == "hunt":
		sim.begin_boss()
		await _wait(3.0)
	_touch(run, STICK_HOME, true)
	var b := await _sample(run, 5.0, Vector2(-1, 0.4))
	_touch(run, _finger_at, false)
	var st: Stage3D = run.stage
	var grass := 0
	for node in st._grass_nodes:
		grass += node.multimesh.instance_count if node.multimesh.visible_instance_count < 0 else node.multimesh.visible_instance_count
	var lights := st.world_root.find_children("*", "Light3D", true, false).size()
	var parts := 0
	for p in st.world_root.find_children("*", "GPUParticles3D", true, false):
		parts += (p as GPUParticles3D).amount
	print("PROFILE tier=%s renderer=%s scale=%.2f viewport=%s" % [Quality.level(), RenderingServer.get_current_rendering_method(), st.viewport.scaling_3d_scale, str(st.viewport.size)])
	print("PROFILE scene grass_instances=%d lights=%d particle_amount=%d" % [grass, lights, parts])
	var cam := st.camera
	var rows := {}
	var casters := 0
	for gi in st.world_root.find_children("*", "GeometryInstance3D", true, false):
		var g := gi as GeometryInstance3D
		if not g.is_visible_in_tree():
			continue
		var mesh: Mesh = null
		var inst := 1
		if g is MeshInstance3D:
			mesh = (g as MeshInstance3D).mesh
		elif g is MultiMeshInstance3D and (g as MultiMeshInstance3D).multimesh:
			var mm := (g as MultiMeshInstance3D).multimesh
			mesh = mm.mesh
			inst = mm.instance_count if mm.visible_instance_count < 0 else mm.visible_instance_count
		if mesh == null:
			continue
		var tris := 0
		for si in mesh.get_surface_count():
			var arr := mesh.surface_get_arrays(si)
			var idx = arr[Mesh.ARRAY_INDEX]
			tris += (idx.size() if idx != null else arr[Mesh.ARRAY_VERTEX].size()) / 3
		var key := str(g.get_parent().name) + "/" + str(g.name) if g is MeshInstance3D else "MM:" + str(mesh.resource_name if mesh.resource_name != "" else mesh.get_instance_id())
		if g.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			casters += 1
		var row: Array = rows.get(key, [0, 0, 0])
		row[0] += tris * inst
		row[1] += 1
		row[2] += mesh.get_surface_count()
		rows[key] = row
	var keys := rows.keys()
	keys.sort_custom(func(x, y) -> bool: return rows[x][0] > rows[y][0])
	print("PROFILE geometry nodes=%d shadow_casters=%d" % [rows.size(), casters])
	for k in keys.slice(0, 16):
		print("PROFILE   %-40s tris=%d nodes=%d surfaces=%d" % [k, rows[k][0], rows[k][1], rows[k][2]])
	_report("explore", e)
	_report("pack", a)
	_report("boss", b)


## Where a pack's draws come from: per visible minion, its mesh surfaces,
## extra material passes, and decals.
func _minion_census(run: Node) -> void:
	var st: Stage3D = run.stage
	var bodies := 0
	var surf := 0
	var passes := 0
	var decals := 0
	var per := {}
	for actor in run.sim.actors:
		if actor.kind != "minion" or not actor.alive or not st._bodies.has(actor.id):
			continue
		var body: Node3D = st._bodies[actor.id]
		if not body.is_visible_in_tree():
			continue
		bodies += 1
		var s0 := surf + passes
		for gi in body.find_children("*", "GeometryInstance3D", true, false):
			if not (gi as Node3D).is_visible_in_tree():
				continue
			if gi.has_meta("decal"):
				decals += 1
				continue
			if gi is MeshInstance3D and (gi as MeshInstance3D).mesh:
				var m := gi as MeshInstance3D
				for si in m.mesh.get_surface_count():
					surf += 1
					var mat := m.get_active_material(si)
					while mat and mat.next_pass:
						passes += 1
						mat = mat.next_pass
				if m.material_overlay:
					passes += m.mesh.get_surface_count()
		per[actor.sprite] = surf + passes - s0
	var groups := {}
	for gi in st.find_children("*", "GeometryInstance3D", true, false):
		if not (gi as Node3D).is_visible_in_tree():
			continue
		var top: Node = gi
		while top.get_parent() and top.get_parent() != st and top.get_parent().get_parent() != st:
			top = top.get_parent()
		var key := String(top.name).rstrip("0123456789@")
		var n := 1
		if gi is MeshInstance3D and (gi as MeshInstance3D).mesh:
			n = (gi as MeshInstance3D).mesh.get_surface_count()
			for si in n:
				var mat := (gi as MeshInstance3D).get_active_material(si)
				while mat and mat.next_pass:
					n += 1
					mat = mat.next_pass
		elif gi is MultiMeshInstance3D:
			n = 1
		groups[key] = groups.get(key, 0) + n
	print("PROFILE scene_groups=%s" % str(groups))
	print("PROFILE minions visible=%d surfaces=%d extra_passes=%d decals=%d per_sprite=%s" % [bodies, surf, passes, decals, str(per)])


func _sample(run: Node, seconds: float, dir: Vector2) -> Dictionary:
	var stats := {"dc": [], "prim": [], "obj": [], "ms": [], "dc3d": [], "dcshadow": [], "prim3d": []}
	var rid: RID = (run.stage as Stage3D).viewport.get_viewport_rid()
	var target := STICK_HOME + dir.normalized() * 70.0
	_drag(run, target)
	var t := 0.0
	while t < seconds:
		await get_tree().process_frame
		var d := get_process_delta_time()
		t += d
		_drag(run, target + Vector2(sin(t * 3.0), cos(t * 2.0)) * 20.0)
		stats["dc"].append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		stats["prim"].append(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
		stats["obj"].append(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
		stats["ms"].append(d * 1000.0)
		stats["dc3d"].append(RenderingServer.viewport_get_render_info(rid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME))
		stats["dcshadow"].append(RenderingServer.viewport_get_render_info(rid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_SHADOW, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME))
		stats["prim3d"].append(RenderingServer.viewport_get_render_info(rid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME))
	return stats


## Like _sample, but the thumb follows the bot's explore route.
func _sample_route(run: Node, seconds: float) -> Dictionary:
	var stats := {"dc": [], "prim": [], "obj": [], "ms": [], "dc3d": [], "dcshadow": [], "prim3d": []}
	var rid: RID = (run.stage as Stage3D).viewport.get_viewport_rid()
	var mem := {}
	_touch(run, STICK_HOME, true)
	var t := 0.0
	while t < seconds:
		var dir: Vector2 = RunBot.explore_steer(run.sim, 0, mem)
		_drag(run, STICK_HOME + (dir.normalized() if dir.length() > 0.2 else Vector2(0, -1)) * 70.0)
		await get_tree().process_frame
		var d := get_process_delta_time()
		t += d
		stats["dc"].append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		stats["prim"].append(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
		stats["obj"].append(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
		stats["ms"].append(d * 1000.0)
		stats["dc3d"].append(RenderingServer.viewport_get_render_info(rid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME))
		stats["dcshadow"].append(RenderingServer.viewport_get_render_info(rid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_SHADOW, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME))
		stats["prim3d"].append(RenderingServer.viewport_get_render_info(rid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME))
	_touch(run, _finger_at, false)
	return stats


func _report(label: String, stats: Dictionary) -> void:
	var line := "PROFILE %s frames=%d" % [label, stats["ms"].size()]
	for key in ["dc", "dc3d", "dcshadow", "prim", "prim3d", "obj", "ms"]:
		var arr: Array = stats[key]
		arr.sort()
		var total := 0.0
		for v in arr:
			total += float(v)
		line += "  %s avg=%.0f p95=%.0f max=%.0f" % [key, total / maxf(arr.size(), 1), float(arr[int(arr.size() * 0.95)]), float(arr[-1])]
	print(line)
