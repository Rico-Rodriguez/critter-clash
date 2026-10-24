extends Node
## Renders a sidekick's one-shot clips frame by frame for contact sheets.
## godot --rendering-driver opengl3 --resolution 1179x2556 res://tools/art/clip_sheet.tscn -- --sk=wisp,bat --out=DIR
## Writes DIR/<sk>_<state>_<i>.png (state: attack, hit, special, run, idle), five
## frames per clip at 0, 25, 40, 60 and 85% of its length (40% is the hit frame).
const LOOK := preload("res://src/core/sidekick_look.gd")
const FR := [0.0, 0.25, 0.4, 0.6, 0.85]


func _ready() -> void:
	var sks := "wisp"
	var out := "/tmp/clips"
	var states := "attack,hit,special,run,idle"
	var fr: Array = FR.duplicate()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--sk="): sks = a.substr(5)
		if a.begins_with("--out="): out = a.substr(6)
		if a.begins_with("--states="): states = a.substr(9)
		if a.begins_with("--frames="):
			fr.clear()
			var n := int(a.substr(9))
			for i in n:
				fr.append(float(i) / n)
	DirAccess.make_dir_recursive_absolute(out)
	var w := Node3D.new()
	add_child(w)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.16, 0.17, 0.19)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.75, 0.75, 0.8)
	env.environment.ambient_light_energy = 0.7
	w.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 35, 0)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	w.add_child(sun)
	var flr := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(8, 8)
	flr.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.3, 0.29, 0.27)
	flr.material_override = fm
	w.add_child(flr)
	var cam := Camera3D.new()
	cam.fov = 40
	cam.keep_aspect = Camera3D.KEEP_WIDTH
	w.add_child(cam)
	await get_tree().process_frame
	for sid in sks.split(","):
		var lk := LOOK.build(sid)
		var m: Node3D = lk["root"]
		var fly := float(preload("res://src/data/sidekick_db.gd").ROSTER[sid].get("fly", 0.0))
		m.position.y = minf(fly, 0.6)
		w.add_child(m)
		# 3/4 front view, framed on the model's posed bounds.
		var inner: Node3D = m.get_child(m.get_child_count() - 1)
		var bb: AABB = inner.get_meta("posed_aabb", AABB(Vector3(-0.5, 0, -0.5), Vector3.ONE))
		bb = AABB(bb.position * inner.scale.x, bb.size * inner.scale.x)
		var c := m.position + bb.get_center()
		var r := maxf(bb.size.y * 1.15, maxf(bb.size.x, bb.size.z) * 0.62)
		cam.position = c + Vector3(0.45, 0.22, 1.0).normalized() * r * 2.6
		cam.look_at(c, Vector3.UP)
		for st in states.split(","):
			if not LOOK.has(lk, st):
				continue
			var ap: AnimationPlayer = lk["anim"]
			var clip := str(lk[st])
			var L := ap.get_animation(clip).length
			for i in fr.size():
				ap.play(clip, 0.0, 1.0)
				ap.seek(fr[i] * L, true)
				ap.pause()
				for f in 3:
					await get_tree().process_frame
				var img := get_viewport().get_texture().get_image()
				img.save_png("%s/%s_%s_%d.png" % [out, sid, st, i])
			print("SHEET %s %s %s %.2fs" % [sid, st, clip, L])
		m.queue_free()
		await get_tree().process_frame
	get_tree().quit()
