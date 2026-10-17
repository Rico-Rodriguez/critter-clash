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


func _hunt() -> void:
	var run := await _run_screen()
	await _wait(0.8)
	_touch(run, STICK_HOME, true)
	await _hold(run, Vector2(1, 0), 1.4)
	# Instant pivots: right -> left, then up -> down.
	await _hold(run, Vector2(-1, 0), 1.2)
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


func _boss() -> void:
	var run := await _run_screen()
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
