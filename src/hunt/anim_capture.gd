extends RefCounted
## Capture-only stages for the animation work (never loaded in play):
##   animclips  one hero in a row of clips, frozen at --fracs of each clip
##   animhero   every hero side by side doing one stage of the animation set
##              (--stage=idle|walk|run|turn|quirk0|quirk1|win0|win1|win2)

const HeroAnim := preload("res://src/hunt/hero_anim.gd")


static func _stage(main: Node) -> Dictionary:
	if main.current:
		main.current.queue_free()
		main.current = null
	var root := Node3D.new()
	main.add_child(root)
	main.current = root
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.2, 0.21, 0.27)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.75, 0.85)
	env.ambient_light_energy = 0.9
	we.environment = env
	root.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, -20, 0)
	root.add_child(sun)
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.fov = 30
	return {"root": root, "cam": cam}


static func shoot(main: Node, shot: String, args: PackedStringArray) -> void:
	var st := _stage(main)
	var root: Node3D = st["root"]
	var cam: Camera3D = st["cam"]
	if shot == "animclips":
		var hid: String = str(main._arg(args, "hero", "knight"))
		var clips: PackedStringArray = str(main._arg(args, "clips", "Idle_A")).split(",")
		var fracs: PackedStringArray = str(main._arg(args, "fracs", "0.2,0.5,0.8")).split(",")
		var per_row: int = int(main._arg(args, "cols", "6"))
		var actors: Array[Actor] = []
		for i in clips.size():
			var a := Actor.new()
			root.add_child(a)
			a.build_model(DB.HEROES[hid]["model"], {}, Color(0.5, 0.6, 1.0), 0.2)
			GearLook.apply(a, hid)
			a.position = Vector3((i % per_row - (per_row - 1) * 0.5) * 2.2, -(i / per_row) * 2.8, 0)
			a.rotation_degrees.y = -15.0
			actors.append(a)
		var rows: int = (clips.size() + per_row - 1) / per_row
		var cy: float = 1.0 - (rows - 1) * 1.4
		var asp: float = main.get_viewport().get_visible_rect().size.aspect()
		var dist: float = maxf(rows * 2.8, per_row * 2.2 / asp) / 0.536 * 1.05
		cam.look_at_from_position(Vector3(0, cy, dist), Vector3(0, cy, 0), Vector3.UP)
		for fi in fracs.size():
			for i in clips.size():
				var a := actors[i]
				var c: String = clips[i].strip_edges()
				if not a.anim.has_animation(c):
					print("NO CLIP ", c)
					continue
				a.anim.play(c)
				a.anim.pause()
				a.anim.seek(float(fracs[fi]) * a.anim.get_animation(c).length, true)
			await main._wait(0.15)
			await main._save("animclips_%s_%d" % [hid, fi])
		print("CLIPS ", ",".join(clips))
	elif shot == "animhero":
		# One hero, one scenario, eight moments side by side: every actor runs the
		# same script on a manual clock up to its own time, then the row is shot.
		var hid2: String = str(main._arg(args, "hero", "knight"))
		var scen: String = str(main._arg(args, "stage", "run"))
		var times: PackedStringArray = str(main._arg(args, "fracs", "0.2,0.45,0.7,1.0,1.4,2.3,2.5,2.8")).split(",")
		var n := times.size()
		for i in n:
			var a := Actor.new()
			root.add_child(a)
			a.build_model(DB.HEROES[hid2]["model"], {}, Color(0.5, 0.6, 1.0), 0.2)
			GearLook.apply(a, hid2)
			a.position = Vector3((i - (n - 1) * 0.5) * 2.2, 0, 0)
			var ha = HeroAnim.new()
			ha.attach(a, GearDB.anims(hid2, Game.weapon_family(hid2)), hid2)
			ha.tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
			var speed := float(DB.HEROES[hid2]["speed"])
			var t := 0.0
			var vel := Vector3.ZERO
			var yaw := 0.0
			var fired := false
			var end := float(times[i])
			while t < end - 0.0001:
				var dt := 1.0 / 60.0
				var want := Vector3.ZERO
				match scen:
					"run":
						want = Vector3(0, 0, speed) if t > 0.3 and t < 2.2 else Vector3.ZERO
					"walk":
						want = Vector3(0, 0, speed * 0.4) if t > 0.3 else Vector3.ZERO
					"turn":
						if t > 0.3:
							yaw = move_toward(yaw, PI, 12.0 * dt)
					"carve":
						want = Vector3(0, 0, speed) if t > 0.2 else Vector3.ZERO
						if t > 1.0 and t < 1.5:
							yaw = move_toward(yaw, 1.6, 7.0 * dt)
					"quirk":
						if t > 0.2 and not fired:
							fired = true
							ha.quirk()
					"victory":
						if t > 0.2 and not fired:
							fired = true
							ha.victory()
				vel = vel.move_toward(want, 60.0 * dt)
				a.rotation.y = yaw + float(main._arg(args, "view", "1.2"))
				ha.tick(dt, vel.rotated(Vector3.UP, yaw), speed, yaw, false)
				ha.tree.advance(dt)
				t += dt
		var asp2: float = main.get_viewport().get_visible_rect().size.aspect()
		cam.look_at_from_position(Vector3(0, 1.1, maxf(3.3, n * 2.2 / asp2) / 0.536 * 1.05), Vector3(0, 1.1, 0), Vector3.UP)
		await main._wait(0.1)
		await main._save("animhero_%s_%s" % [hid2, scen])
