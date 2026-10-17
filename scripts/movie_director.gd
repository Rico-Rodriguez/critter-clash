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
		"boss":
			await _boss()
		"profile":
			await _profile()
		"home":
			await _home()
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
	app.go("run", {"biome": "meadow", "hero": "ember"})
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


func _start_log(run: Node) -> void:
	_logging = true
	_log.clear()
	while _logging and is_instance_valid(run):
		var row := {"t": Time.get_ticks_msec() / 1000.0, "stick": _stick_dir}
		var h = run.sim.heroes[0]
		row["hero"] = h.pos
		row["hero_alive"] = h.alive
		for a in run.sim.actors:
			if a.kind == "boss" and a.alive:
				row["boss"] = a.pos
				row["boss_state"] = a.boss_state
		_log.append(row)
		await get_tree().process_frame


## Snap the thumb straight across (no easing): a hard 180.
func _snap(run: Node, dir: Vector2, seconds: float) -> void:
	_reversals.append({"t": Time.get_ticks_msec() / 1000.0, "dir": dir.normalized(), "from": _stick_dir})
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
	await _hold(run, Vector2(1, 0), 1.4)
	_stick_dir = Vector2(1, 0)
	# Hard 180s: the thumb snaps straight across, right -> left -> right.
	await _snap(run, Vector2(-1, 0), 1.2)
	await _snap(run, Vector2(1, 0), 0.9)
	await _hold(run, Vector2(0, -1), 1.3)
	# A pack closes in from above while we strafe.
	var hero: Vector2 = run.sim.heroes[0].pos
	for k in 7:
		var off := Vector2(-150 + k * 50, -330 - (k % 2) * 60)
		run.sim._spawn_minion([0, 1, 2][k % 3], run.sim._clamp_point(hero + off, 24.0))
	await _hold(run, Vector2(0, 1), 1.0)
	await _hold(run, Vector2(1, 1), 1.2)
	_touch(run, _finger_at, false)
	# Stand and fight, then sweep through the dropped gems.
	await _wait(2.6)
	_touch(run, STICK_HOME, true)
	await _hold(run, Vector2(0, -1), 1.4)
	await _hold(run, Vector2(-1, -0.4), 1.4)
	_touch(run, _finger_at, false)
	await _wait(0.8)
	# The hero falls: the death topple, then the defeat card.
	var h = run.sim.heroes[0]
	h.stats["revive"] = 0
	run.sim._kill(h)
	await _wait(3.0)
	_feel_report()


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
	var hero: Vector2 = run.sim.heroes[0].pos
	for k in 10:
		var off := Vector2(-220 + k * 50, -300 - (k % 3) * 50)
		run.sim._spawn_minion([0, 1, 2, 3][k % 4], run.sim._clamp_point(hero + off, 24.0))
	_touch(run, STICK_HOME, true)
	var a := await _sample(run, 4.0, Vector2(1, -0.3))
	_touch(run, _finger_at, false)
	_minion_census(run)
	run.sim.begin_boss()
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
