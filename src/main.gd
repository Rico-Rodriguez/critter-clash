extends Node
## App shell: switches between the camp (lobby) and a hunt with a fade.
## Also hosts two command-line modes used for checks:
##   -- --bot [--hero=knight] [--tier=0] [--runs=1] [--idle]   headless autopilot hunts
##   -- --capture --shots=lobby,hunt,... --out=/abs/dir         screenshots
##   -- --check                                                 compile every script and scene

const LOBBY := preload("res://src/lobby/lobby.tscn")

var current: Node
var _fade: ColorRect
var _busy := false
## A chest won in the last hunt, waiting to be opened in camp.
var pending_chest := ""


func _ready() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 90
	add_child(layer)
	_fade = ColorRect.new()
	_fade.color = Color(0.01, 0.01, 0.02, 1.0)
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_fade)
	var args := OS.get_cmdline_user_args()
	if args.has("--check"):
		_check.call_deferred()
	elif args.has("--bot"):
		_run_bot.call_deferred(args)
	elif args.has("--capture"):
		_capture.call_deferred(args)
	else:
		go("lobby")


func go(screen: String) -> void:
	if _busy:
		return
	_busy = true
	if current:
		var t := create_tween()
		t.tween_property(_fade, "color:a", 1.0, 0.25)
		await t.finished
		current.queue_free()
		current = null
		await get_tree().process_frame
	get_tree().paused = false
	Engine.time_scale = 1.0
	match screen:
		"lobby":
			var l := LOBBY.instantiate()
			l.main = self
			current = l
			add_child(l)
		"hunt":
			var h := Hunt.new()
			h.finished.connect(_on_hunt_finished)
			current = h
			add_child(h)
	await get_tree().process_frame
	var t2 := create_tween()
	t2.tween_property(_fade, "color:a", 0.0, 0.35)
	_busy = false


func _on_hunt_finished(result: Dictionary) -> void:
	if result.get("win", false):
		pending_chest = str(result.get("chest", ""))
	go("lobby")


# --- Compile check ---------------------------------------------------------

func _check() -> void:
	var bad := 0
	var n := 0
	for path in _walk("res://src"):
		if not (path.ends_with(".gd") or path.ends_with(".tscn") or path.ends_with(".gdshader")):
			continue
		n += 1
		var r = load(path)
		if r == null or r is GDScript and not (r as GDScript).can_instantiate():
			print("FAILED ", path)
			bad += 1
	print("CHECK %d files, %s" % [n, "OK" if bad == 0 else "%d FAILED" % bad])
	get_tree().quit(0 if bad == 0 else 1)


func _walk(dir: String) -> PackedStringArray:
	var out := PackedStringArray()
	for f in ResourceLoader.list_directory(dir):
		if f.ends_with("/"):
			out.append_array(_walk(dir.path_join(f.trim_suffix("/"))))
		else:
			out.append(dir.path_join(f))
	return out


# --- Headless autopilot ---------------------------------------------------

func _arg(args: PackedStringArray, key: String, def: String) -> String:
	for a in args:
		if a.begins_with("--%s=" % key):
			return a.substr(key.length() + 3)
	return def


func _run_bot(args: PackedStringArray) -> void:
	_fade.visible = false
	var runs := int(_arg(args, "runs", "1"))
	var heroes := _arg(args, "hero", "knight").split(",")
	var tier := int(_arg(args, "tier", "0"))
	var idle := args.has("--idle")
	var levels := int(_arg(args, "level", "1"))
	var ok := true
	for hid in heroes:
		Game.hero(hid)["unlocked"] = true
		Game.hero(hid)["level"] = levels
		for r in runs:
			Game.data["hero"] = hid
			Game.data["tier_unlocked"] = 2
			Game.data["tier"] = tier
			var h := Hunt.new()
			add_child(h)
			if idle:
				h._bot.idle = true
			var res: Dictionary = await h.finished
			var boss_left := (h.boss.hp / h.boss.max_hp) if h.boss else 1.0
			print("BOT hero=%s tier=%d win=%s time=%.1f boss_at=%.1f boss_left=%.2f kills=%d elites=%d level=%d gold=%d items=%d hp=%.0f/%.0f cards=%s" % [hid, tier, res["win"], res["time"], h.boss_at, boss_left, res["kills"], res["elites"], res["level"], res["gold"], res["items"].size(), h.hero.hp, h.hero.max_hp, h.cards])
			if idle and res["win"]:
				ok = false
			h.queue_free()
			await get_tree().process_frame
			Engine.time_scale = 1.0
	print("BOT DONE ", "PASS" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)


# --- Screenshots ----------------------------------------------------------

var _shots_dir := "/tmp/shots"


func _capture(args: PackedStringArray) -> void:
	_shots_dir = _arg(args, "out", _shots_dir)
	DirAccess.make_dir_recursive_absolute(_shots_dir)
	var want := _arg(args, "shots", "lobby").split(",")
	var hid := _arg(args, "hero", "knight")
	Game.data["gold"] = 1240
	Game.data["hero"] = hid
	Game.hero(hid)["shards"] = 9
	Game.data["tier_unlocked"] = 1
	for s in DB.SKILLS:
		Game.data["skills"][s] = DB.xp_for_level({"attack": 14, "strength": 17, "defence": 11, "hitpoints": 18, "ranged": 9, "magic": 6}[s])
	Game.data["log"] = {"tooth": 3, "sigil": 1, "cleaver": 1}
	for i in 5:
		Game.grant_item(Game.roll_item("chest", 0))
	Game.grant_item(Game.make_unique("cleaver"))
	# Two good pieces per slot so the equipment screen has something to compare.
	for slot in DB.SLOTS:
		for t in 2:
			Game.grant_item(Game.roll_item("boss", 1, slot))
	if _arg(args, "geared", "0") == "1":
		for slot in DB.SLOTS:
			var best := {}
			for it in Game.data["items"]:
				if it["slot"] == slot and (best.is_empty() or Game.item_score(it) > Game.item_score(best)):
					best = it
			if not best.is_empty():
				Game.equip(hid, int(best["uid"]))
	_fade.visible = false
	for shot in want:
		match shot:
			"lobby", "heroes", "skills", "log", "bag", "equip", "chest", "settings":
				if shot == "chest":
					pending_chest = "gold"
				_set_screen_now("lobby")
				await _wait(1.2)
				if shot != "lobby":
					current.open_sheet("bag" if shot == "equip" else shot)
					await _wait(1.0 if shot != "chest" else 2.8)
				await _save(shot)
			"flow":
				# Exercise the real transitions: camp -> hunt -> camp.
				go("lobby")
				await _wait(1.0)
				go("hunt")
				await _wait(2.0)
				var hh: Hunt = current
				hh._abandon()
				await _wait(0.5)
				hh.hud.get_children().back().closed.emit()
				await _wait(1.5)
				print("FLOW at ", current.name)
				await _save("flow")
			"icon":
				_set_screen_now("lobby")
				var lob = current
				lob.ui.visible = false
				lob.cam.fov = 38.0
				lob.cam.look_at_from_position(Vector3(0.45, 1.75, 3.5), Vector3(0, 1.22, 0), Vector3.UP)
				lob.hero.rotation.y = 0.35
				await _wait(1.5)
				await _save("icon")
			"devpanel":
				_set_screen_now("hunt")
				var hd: Hunt = current
				await _wait_sim(hd, 3.0)
				hd.hud._open_pause()
				await _wait(0.6)
				hd.hud.get_children().back().open_dev_panel()
				await _wait(0.8)
				await _save("devpanel")
			"equipdetail":
				_set_screen_now("lobby")
				await _wait(1.0)
				current.open_sheet("bag")
				await _wait(0.8)
				var eqs: Equipment = current.ui.equipment
				for it in Game.data["items"]:
					if it["slot"] == "weapon" and Game.owner_of(int(it["uid"])) == "" and it["rarity"] != "common":
						eqs._open_detail(it)
						break
				await _wait(0.8)
				await _save("equipdetail")
			"shrine":
				_set_screen_now("hunt")
				var hs: Hunt = current
				hs.bot = true
				hs._bot = HuntBot.new()
				hs._bot.hunt = hs
				hs._bot.idle = true
				await _wait(2.5)
				hs.hero.invuln = 999.0
				hs.hero.position = hs.shrines[0]["pos"] + Vector3(0.2, 0, 0)
				await _wait(2.6)
				await _save("shrine")
			"evolve":
				_set_screen_now("hunt")
				var he: Hunt = current
				he.bot = true
				he._bot = HuntBot.new()
				he._bot.hunt = he
				he._bot.idle = true
				await _wait(2.5)
				he.bot = false
				he.cards["blades"] = 4
				he.cards["haste"] = 1
				he.run_level = 6
				he.run_xp = DB.run_level_xp(he.run_level)
				he._check_level()
				await _wait(1.0)
				await _save("evolve")
			"foes":
				# One of every new foe and every elite affix, standing around the hero.
				_set_screen_now("hunt")
				var hf2: Hunt = current
				hf2.bot = true
				hf2._bot = HuntBot.new()
				hf2._bot.hunt = hf2
				hf2._bot.idle = true
				await _wait(2.5)
				hf2.hero.invuln = 999.0
				hf2.robber_spawned = true
				var base := hf2.hero.flat_pos()
				var lineup := [["bomber", ""], ["necro", ""], ["robber", ""], ["minion", "vampiric"], ["warrior", "swift"], ["warrior", "molten"], ["minion", "warded"]]
				for i in lineup.size():
					var a := -PI * 0.5 + (i - (lineup.size() - 1) * 0.5) * 0.5
					var at := base + Vector3(sin(a), 0, -cos(a)) * 6.0
					hf2.spawn_foe(lineup[i][0], at, lineup[i][1] != "", lineup[i][1])
				await _wait(2.4)
				await _save("foes")
			"film":
				_set_screen_now("hunt")
				var hf: Hunt = current
				hf.bot = true
				hf._bot = HuntBot.new()
				hf._bot.hunt = hf
				await _wait_sim(hf, 14.0)
				for i in 6:
					await _save("film%d" % i)
					await _wait(0.13)
			"hunt", "levelup", "boss", "victory", "results", "death":
				_set_screen_now("hunt")
				var h: Hunt = current
				h.bot = true
				h._bot = HuntBot.new()
				h._bot.hunt = h
				if shot == "hunt":
					await _wait_sim(h, 16.0)
				elif shot == "levelup":
					await _wait_sim(h, 6.0)
					h.bot = false
					h.run_xp = DB.run_level_xp(h.run_level)
					h._check_level()
					await _wait(0.9)
				elif shot in ["boss", "victory", "results"]:
					await _wait_sim(h, 4.0)
					h.souls = h.souls_goal
					await _wait_sim(h, 12.0 if shot == "boss" else 4.0)
					if shot != "boss":
						h.damage_foe(h.boss, 999999.0, h.hero, Vector3.ZERO, 0.0)
						await _wait(2.5 if shot == "victory" else 5.0)
						if shot == "results":
							h.bot = false
							h._end(true)
							await _wait(1.2)
				elif shot == "death":
					await _wait_sim(h, 5.0)
					h.hero.invuln = 0.0
					h.damage_hero(99999.0, null)
					await _wait(1.6)
				await _save(shot)
	get_tree().quit()


func _set_screen_now(screen: String) -> void:
	if current:
		current.queue_free()
		current = null
	get_tree().paused = false
	Engine.time_scale = 1.0
	if screen == "lobby":
		var l := LOBBY.instantiate()
		l.main = self
		current = l
	else:
		var h := Hunt.new()
		h.finished.connect(func(_r): pass)
		current = h
	add_child(current)


## Waits a number of frames (captures run at a fixed frame step, so frames
## are game time).
func _wait(sec: float) -> void:
	for i in int(sec * 30.0):
		await get_tree().process_frame


## Software rendering is slow: wait on hunt time, not wall time.
func _wait_sim(h: Hunt, sec: float) -> void:
	var end := h.time + sec
	var guard := Time.get_ticks_msec() + 240000
	while h.time < end and Time.get_ticks_msec() < guard and is_instance_valid(h):
		await get_tree().process_frame


func _save(name_: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [_shots_dir, name_])
	print("SHOT %s draws=%d objects=%d prims=%d nodes=%d" % [name_, Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME), Performance.get_monitor(Performance.OBJECT_NODE_COUNT)])
