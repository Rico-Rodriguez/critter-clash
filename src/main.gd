extends Node
## App shell: switches between the camp (lobby) and a hunt with a fade.
## Also hosts two command-line modes used for checks:
##   -- --bot [--hero=knight] [--tier=0] [--zone=barrow|depths] [--runs=1] [--idle]   headless autopilot hunts
##   -- --capture --shots=lobby,hunt,... --out=/abs/dir         screenshots
##   -- --check                                                 compile every script and scene

const LOBBY := preload("res://src/lobby/lobby.tscn")

var current: Node
var _fade: ColorRect
var _busy := false
## A chest won in the last hunt, waiting to be opened in camp.
var pending_chest := ""
## Gold when the last hunt began: the camp counts up from it on return.
var gold_seen := -1
## Chests won while playing again without visiting camp, opened in turn.
var chest_queue: Array[String] = []


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
	if args.has("--notch"):
		Ui.forced_inset = Vector4(0, 108, 0, 62)
	if args.has("--check"):
		_check.call_deferred()
	elif args.has("--test"):
		_test.call_deferred()
	elif args.has("--bot"):
		_run_bot.call_deferred(args)
	elif args.has("--capture"):
		_capture.call_deferred(args)
	else:
		# The launch update check holds the camp behind the splash; a connect,
		# not an await, so an in-process update restart can free this node.
		var ota := get_node_or_null("/root/Ota")
		if ota and ota.get("checking") == true and ota.has_signal("boot_done"):
			ota.connect("boot_done", go.bind("lobby"), CONNECT_ONE_SHOT)
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
	if result.get("win", false) or (str(result.get("mode", "")) in ["descent", "wild"] and str(result.get("chest", "")) != ""):
		var c := str(result.get("chest", ""))
		if c != "":
			if pending_chest == "":
				pending_chest = c
			else:
				chest_queue.append(c)
	go("hunt" if result.get("again", false) else "lobby")


## The next waiting chest after one is opened, or "".
func next_chest() -> String:
	pending_chest = chest_queue.pop_front() if not chest_queue.is_empty() else ""
	return pending_chest


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


func _test() -> void:
	var fails := Tests.new().run()
	print("TESTS ", "PASSED" if fails == 0 else "%d FAILED" % fails)
	get_tree().quit(0 if fails == 0 else 1)


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
	var zone := _arg(args, "zone", "barrow")
	var mode := _arg(args, "mode", "horde")
	var ok := true
	# --gear=M: a full set of rare material-M gear and every talent point spent,
	# to test what a geared account sees (the bare bot is a floor, not the norm).
	var gear := int(_arg(args, "gear", "-1"))
	for hid in heroes:
		Game.hero(hid)["unlocked"] = true
		Game.hero(hid)["level"] = levels
		if gear >= 0:
			for sk in DB.SKILLS:
				Game.data["skills"][sk] = maxi(int(Game.data["skills"][sk]), DB.xp_for_level(int(GearDB.REQ[gear])))
			for slot in DB.SLOTS:
				var it := Game.grant_item(Game.make_item(hid, slot, gear, "rare"))
				Game.equip(hid, int(it["uid"]))
			var path := 0
			while Game.talent_points(hid) > 0 and path < 3:
				var learned := false
				for i in TalentDB.paths(hid)[path]["nodes"].size():
					if Game.learn_talent(hid, path, i):
						learned = true
						break
				if not learned:
					path += 1
			var s := Game.hero_stats(hid)
			print("GEAR %s mat=%d power=%d hp=%.0f dmg=%.1f rate=%.2f armor=%.2f regen=%.1f" % [hid, gear, Game.power_score(hid), s["hp"], s["dmg"], s["rate"], s["armor"], s["regen"]])
		for r in runs:
			Game.data["hero"] = hid
			Game.data["tier_unlocked"] = DB.TIERS.size() - 1
			Game.data["mode_tiers"][mode] = DB.TIERS.size() - 1
			Game.data["zone"] = zone
			Game.data["mode"] = mode
			Game.data["tier"] = tier
			var h := Hunt.new()
			add_child(h)
			if idle:
				h._bot.idle = true
			# --limit=N ends the hunt after N seconds of play (the Descent has no end).
			var limit := float(_arg(args, "limit", "0"))
			if limit > 0.0:
				(func():
					while is_instance_valid(h) and not h._ended:
						await get_tree().process_frame
						if is_instance_valid(h) and h.time > limit:
							h._abandon()).call()
			var res: Dictionary = await h.finished
			var boss_left := (h.boss.hp / h.boss.max_hp) if h.boss else 1.0
			print("BOT mode=%s zone=%s hero=%s tier=%d win=%s time=%.1f boss_at=%.1f boss_left=%.2f kills=%d elites=%d level=%d gold=%d items=%d hp=%.0f/%.0f depth=%d rush=%d cards=%s" % [mode, zone, hid, tier, res["win"], res["time"], h.boss_at, boss_left, res["kills"], res["elites"], res["level"], res["gold"], res["items"].size(), h.hero.hp, h.hero.max_hp, h.depth, h.rush_i, h.cards])
			if idle and res["win"]:
				ok = false
			h.queue_free()
			await get_tree().process_frame
			Engine.time_scale = 1.0
	print("BOT DONE ", "PASS" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)


# --- Screenshots ----------------------------------------------------------

var _shots_dir := "/tmp/shots"
## A phone's frame budget: shots over this need a look before they ship.
const BUDGET_DRAWS := 700
const BUDGET_PRIMS := 400000


func _capture(args: PackedStringArray) -> void:
	_shots_dir = _arg(args, "out", _shots_dir)
	DirAccess.make_dir_recursive_absolute(_shots_dir)
	var want := _arg(args, "shots", "lobby").split(",")
	var hid := _arg(args, "hero", "knight")
	Game.data["gold"] = 1240
	Game.data["hero"] = hid
	Game.hero(hid)["shards"] = 9
	Game.data["tier_unlocked"] = 1
	Game.data["mode"] = _arg(args, "mode", "horde")
	Game.data["mode_tiers"][Game.data["mode"]] = 1
	if _arg(args, "zone", "barrow") != "barrow":
		Game.data["tier_unlocked"] = DB.TIERS.size() - 1
		Game.data["mode_tiers"][Game.data["mode"]] = DB.TIERS.size() - 1
		Game.data["zone"] = _arg(args, "zone", "barrow")
	for s in DB.SKILLS:
		Game.data["skills"][s] = DB.xp_for_level({"attack": 32, "strength": 30, "defence": 31, "hitpoints": 30, "ranged": 32, "magic": 32}[s])
	Game.data["log"] = {"tooth": 3, "sigil": 1, "cleaver": 1}
	for i in 5:
		Game.grant_item(Game.roll_item("chest", 1, "", hid))
	Game.grant_item(Game.make_unique({"knight": "crown", "ranger": "shroud", "mage": "gown", "barbarian": "cleaver"}[hid]))
	# Two good pieces per slot so the equipment screen has something to compare.
	for slot in DB.SLOTS:
		for t in 2:
			Game.grant_item(Game.roll_item("boss", 1, slot, hid))
	# --mat=N: a full rare set of material N, to look at what fine gear does.
	var mat := int(_arg(args, "mat", "-1"))
	if mat >= 0:
		for sk in DB.SKILLS:
			Game.data["skills"][sk] = maxi(int(Game.data["skills"][sk]), DB.xp_for_level(int(GearDB.REQ[mat])))
		for slot in DB.SLOTS:
			var mk := Game.make_item(hid, slot, mat, "rare")
			# --set=hexer: the boss set's look; --look=N: a stage's Nth alternative.
			if _arg(args, "set", "") != "":
				mk["set"] = _arg(args, "set", "")
			mk["look"] = int(_arg(args, "look", "0"))
			mk["name"] = GearDB.base_name(mk)
			var it := Game.grant_item(mk)
			Game.equip(hid, int(it["uid"]))
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
			"lobby", "heroes", "skills", "log", "bag", "equip", "chest", "settings", "bounties", "expedition", "talents", "lobbychest", "road", "daily", "season", "feats", "campfire":
				# The new camp systems with something to show.
				Game.data["idle_since"] = int(Time.get_unix_time_from_system()) - 3 * 3600
				Game.season()["xp"] = DB.SEASON_XP * 4 + 60
				Game.season()["claimed"] = 2
				Game.data["stats"]["wins"] = 3
				Game.data["stats"]["hunts"] = 5
				for k in ["camp_hunt", "camp_chest", "camp_gear", "camp_heroes"]:
					Game.data["tips"][k] = true
				Game.hero(hid)["mastery"] = 520
				Game.hero(hid)["mastery_rank"] = 1
				Game.hero(hid)["rating"] = 64
				if shot == "chest" or shot == "lobbychest":
					pending_chest = "gold"
				if shot in ["bounties", "lobby"]:
					Game.refresh_bounties()
					var bl: Array = Game.data["bounties"]["list"]
					bl[0]["progress"] = bl[0]["target"]
					bl[1]["progress"] = int(bl[1]["target"]) / 2
				if shot == "road":
					Game.data["renown"] = DB.road_threshold(3) + 40
					Game.data["road"] = 1
					Game.data["clue"] = {"step": 1, "goals": [{"id": "gold", "hero": "knight"}, {"id": "veteran", "hero": "knight"}, {"id": "elites", "hero": "knight"}]}
				if shot == "talents":
					Game.hero(hid)["level"] = 12
					for n in [[0, 0], [0, 1], [0, 2], [1, 0]]:
						Game.learn_talent(hid, n[0], n[1])
				_set_screen_now("lobby")
				await _wait(1.2)
				if shot == "campfire":
					current.ui._side_pressed("idle")
					await _wait(1.0)
				elif shot != "lobby" and shot != "lobbychest":
					current.open_sheet("bag" if shot == "equip" else shot)
					await _wait(1.0 if shot != "chest" else 2.8)
				await _save(shot)
			"firstcamp":
				# A new player's camp: no side column, a note on the hunt button.
				_set_screen_now("lobby")
				await _wait(2.0)
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
				hh.hud.get_children().back().closed.emit(false)
				await _wait(1.5)
				print("FLOW at ", current.name)
				await _save("flow")
			"parts", "weapons", "dress", "sets", "sets2", "arms":
				await _contact_sheet(shot, _arg(args, "hero", ""))
				await _save(shot)
			"gear":
				# The equipment screen, its bag filtered to one slot, a piece's
				# card and its Improve panel; then the Heroes sheet's other tabs.
				Game.data["gold"] = 14020
				_set_screen_now("lobby")
				await _wait(1.0)
				current.open_sheet("bag")
				await _wait(2.5)
				await _save("gear_slots")
				var eqg: Equipment = current.ui.equipment
				eqg._on_slot("chest")
				await _wait(2.0)
				await _save("gear_bag")
				for it in Game.data["items"]:
					if str(it["cls"]) == eqg.hero_id and it["rarity"] == "rare" and Game.owner_of(int(it["uid"])) == "":
						eqg._select(it)
						break
				await _wait(1.0)
				await _save("gear_card")
				eqg._open_forge(eqg.selected)
				await _wait(0.6)
				await _save("gear_forge")
				eqg._close()
				await _wait(0.8)
				for tab in ["progress", "looks"]:
					current.ui._hero_tab = tab
					current.open_sheet("heroes")
					await _wait(1.2)
					await _save("heroes_" + tab)
					current.ui._sheet.close()
					await _wait(0.6)
			"swipe":
				# Drag gestures through the real GUI: a drag that starts on a
				# row scrolls the list (and does not tap it), a card swipes away.
				_set_screen_now("lobby")
				await _wait(1.0)
				current.open_sheet("bag")
				await _wait(1.0)
				var eq: Equipment = current.ui.equipment
				await _wait(1.0)
				var row: Control = eq._list.get_child(1).get_child(0)
				var at := row.get_global_rect().get_center()
				await _save("swipe_before")
				await _finger(at, at + Vector2(0, -260), 8)
				await _wait(0.3)
				print("SWIPE list scrolled=%d selected=%s" % [eq._scroll.scroll_vertical, not eq.selected.is_empty()])
				await _save("swipe_list")
				await _finger(at, at, 1)
				await _wait(0.4)
				print("SWIPE tap selects=%s card=%s" % [not eq.selected.is_empty(), eq._card != null])
				var c := eq._card.get_global_rect().get_center()
				await _finger(c, c + Vector2(0, 150), 6, false)
				await _save("swipe_card")
				await _finger_up(c + Vector2(0, 150))
				await _wait(0.6)
				print("SWIPE card closed=%s" % (eq._card == null))
				eq._close()
				await _wait(0.8)
				current.open_sheet("skills")
				await _wait(1.0)
				var sh: Sheet = current.ui._sheet
				var hd := sh.title_label.get_global_rect().get_center()
				await _finger(hd, hd + Vector2(0, 260), 8, false)
				await _save("swipe_sheet")
				await _finger_up(hd + Vector2(0, 260))
				await _wait(0.8)
				print("SWIPE sheet closed=%s" % (not is_instance_valid(sh) or not sh.is_inside_tree()))
			"icon":
				_set_screen_now("lobby")
				var lob = current
				lob.ui.visible = false
				lob.cam.fov = 38.0
				lob.cam.look_at_from_position(Vector3(0.45, 1.75, 3.5), Vector3(0, 1.22, 0), Vector3.UP)
				lob.hero.rotation.y = 0.35
				await _wait(1.5)
				await _save("icon")
			"appicon", "splash":
				# The app icon: the hero with a lantern in the dark, in plain
				# polished gear so no rarity glow muddies it at 60 px
				# (tools/app_icon.gd; tools/dev/icon.sh writes assets/icon.png).
				# The splash is the same scene, full length, with dark sky above
				# for the title (tools/dev/splash.sh writes assets/splash.png).
				for slot in DB.SLOTS:
					var pc := Game.make_item(hid, slot, maxi(mat, 0), "common")
					pc["look"] = 0
					Game.equip(hid, int(Game.grant_item(pc)["uid"]))
				_set_screen_now("lobby")
				# By path: tools/ is not exported, and no new class_name may ship in a pack.
				var icam: Camera3D = load("res://tools/app_icon.gd").stage(current)
				if shot == "splash":
					icam.keep_aspect = Camera3D.KEEP_WIDTH
					icam.fov = 46.0
					icam.look_at_from_position(Vector3(0.3, 1.05, 4.3), Vector3(0.1, 1.85, 0), Vector3.UP)
					# The ground runs out to the fog instead of ending in a hard horizon.
					(current.get_node("IconStage").get_child(0).mesh as PlaneMesh).size = Vector2(400, 400)
				await _wait(1.5)
				await _save(shot)
			"depth":
				# The Descent going a level deeper.
				Game.data["mode"] = "descent"
				_set_screen_now("hunt")
				var hdp: Hunt = current
				hdp.hero.invuln = 99.0
				await _wait_sim(hdp, 4.0)
				hdp.depth_t = DB.DESCENT_TIME
				await _wait(float(_arg(args, "after", "0.4")))
				await _save(shot)
			"super", "legendary":
				# The moment a super goes off, or a legendary falls.
				_set_screen_now("hunt")
				var hs: Hunt = current
				hs.hero.invuln = 99.0
				await _wait_sim(hs, 4.0)
				if shot == "super":
					hs.hero.super_charge = 1.0
					hs.hero.try_super()
					await _wait(float(_arg(args, "after", "0.35")))
				else:
					hs._drop_item(hs.hero.flat_pos() + Vector3(2.0, 0, -1.5), Game.make_unique("crown"))
					await _wait(1.0)
				await _save(shot)
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
						eqs._select(it)
						break
				await _wait(0.8)
				await _save("equipdetail")
			"inspect", "inspecthelm", "reveal":
				_set_screen_now("lobby")
				await _wait(1.0)
				current.open_sheet("bag")
				await _wait(0.8)
				var eqi: Equipment = current.ui.equipment
				var want_slot := "helm" if shot == "inspecthelm" else "weapon"
				var pick := {}
				for it in Game.data["items"]:
					if it["slot"] == want_slot and str(it["cls"]) == hid and (pick.is_empty() or Game.item_power(it) > Game.item_power(pick)):
						pick = it
				if shot == "reveal":
					Game.hero(hid)["best_mat"] = 0
					for slot in DB.SLOTS:
						Game.unequip(hid, slot)
					eqi._equip(pick)
					await _wait(0.45)
				else:
					eqi._inspect(pick)
					await _wait(1.2)
				await _save(shot)
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
			"hunt", "levelup", "boss", "victory", "results", "death", "defeat", "hexer", "powers", "descent", "pact", "wild":
				if shot in ["descent", "pact"]:
					Game.data["mode"] = "descent"
				elif shot == "wild":
					Game.data["mode"] = "wild"
				_set_screen_now("hunt")
				var h: Hunt = current
				h.bot = true
				h._bot = HuntBot.new()
				h._bot.hunt = h
				if shot == "hunt":
					await _wait_sim(h, 16.0)
				elif shot == "descent":
					await _wait_sim(h, 70.0)
					h.hero.hp = h.hero.max_hp * 0.4
					await _wait(0.4)
				elif shot == "wild":
					await _wait_sim(h, 12.0)
				elif shot == "pact":
					await _wait_sim(h, 4.0)
					h.bot = false
					h.offer_pact()
					await _wait(0.9)
				elif shot == "levelup":
					await _wait_sim(h, 6.0)
					h.bot = false
					h.run_xp = DB.run_level_xp(h.run_level)
					h._check_level()
					await _wait(0.9)
				elif shot == "powers":
					await _wait_sim(h, 7.0)
					var kit: Dictionary = {"knight": {"smite": 3}, "mage": {"meteor": 3, "frost": 2}, "ranger": {"barrage": 3, "explosive": 2}, "barbarian": {"quake": 3, "axes": 3}}[hid]
					for k in kit:
						h.cards[k] = kit[k]
					h.hero.recompute()
					h.hero.smite_t = 0.05
					h.hero.quake_t = 0.05
					h.hero.axe_t = 0.05
					h.hero.meteor_t = 0.05
					h.hero.frost_t = 0.05
					h.hero.barrage_t = 0.05
					await _wait_sim(h, 0.5 if hid in ["mage", "ranger"] else 0.12)
				elif shot == "hexer":
					await _wait_sim(h, 4.0)
					h.souls = h.souls_goal
					await _wait_sim(h, 9.0)
					h.bot = false
					h.boss._begin("circles")
					await _wait_sim(h, 0.8)
				elif shot in ["boss", "victory", "results"]:
					await _wait_sim(h, 4.0)
					h.souls = h.souls_goal
					await _wait_sim(h, 12.0 if shot == "boss" else 4.0)
					if shot != "boss":
						# Off autopilot first: the loot vacuum can end the win
						# before the shot, and a bot hunt skips the results.
						if shot == "results":
							h.bot = false
						h.damage_foe(h.boss, 999999.0, h.hero, Vector3.ZERO, 0.0)
						await _wait(2.5 if shot == "victory" else 5.0)
						if shot == "results":
							h.bot = false
							h._end(true)
							await _wait(2.2)
				elif shot == "death" or shot == "defeat":
					await _wait_sim(h, 5.0)
					if shot == "defeat":
						h.bot = false
					h.hero.invuln = 0.0
					h.damage_hero(99999.0, null)
					await _wait(1.6 if shot == "death" else 6.0)
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
## A finger pressed at `a` and dragged to `b` over `steps` frames, lifted at
## the end unless `lift` is false.
func _finger(a: Vector2, b: Vector2, steps: int, lift := true) -> void:
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = a
	down.global_position = a
	get_viewport().push_input(down)
	var last := a
	for i in steps:
		await get_tree().process_frame
		var p := a.lerp(b, float(i + 1) / steps)
		var mv := InputEventMouseMotion.new()
		mv.button_mask = MOUSE_BUTTON_MASK_LEFT
		mv.position = p
		mv.global_position = p
		mv.relative = p - last
		last = p
		get_viewport().push_input(mv)
	if lift:
		await _finger_up(b)


func _finger_up(at: Vector2) -> void:
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = at
	up.global_position = at
	get_viewport().push_input(up)
	await get_tree().process_frame


func _wait(sec: float) -> void:
	for i in int(sec * 30.0):
		await get_tree().process_frame


## Software rendering is slow: wait on hunt time, not wall time.
func _wait_sim(h: Hunt, sec: float) -> void:
	var end := h.time + sec
	var guard := Time.get_ticks_msec() + 240000
	while h.time < end and Time.get_ticks_msec() < guard and is_instance_valid(h):
		await get_tree().process_frame


## A lineup of every character (or weapon) on a bare stage, for choosing parts.
func _contact_sheet(kind: String, only := "") -> void:
	if current:
		current.queue_free()
		current = null
	var root := Node3D.new()
	add_child(root)
	current = root
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.18, 0.18, 0.22)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.7, 0.7, 0.8)
	env.ambient_light_energy = 0.8
	we.environment = env
	root.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, -20, 0)
	root.add_child(sun)
	var names: Array = []
	if kind == "dress" or kind.begins_with("sets"):
		var cam2 := Camera3D.new()
		root.add_child(cam2)
		cam2.fov = 30
		# sets: plain T6, its alternative look, then the three boss sets.
		# sets2: alternatives at T3 and T5 (look 1 and 2).
		var cols: Array = [-1, 1, 3, 6]
		if kind == "sets":
			cols = ["a0", "a1", "gravemaw", "hexer", "thorn"]
		elif kind == "sets2":
			cols = ["b1", "b2", "c1", "c2", "a2"]
		for r in DB.HERO_ORDER.size():
			var hid: String = DB.HERO_ORDER[r]
			for c in cols.size():
				var a := Actor.new()
				root.add_child(a)
				a.build_model(DB.HEROES[hid]["model"], {}, Color(0.5, 0.6, 1.0), 0.2)
				a.position = Vector3((c - (cols.size() - 1) * 0.5) * 1.7, -r * 2.2, 0)
				var pre := {}
				for slot in DB.SLOTS:
					var spec = cols[c]
					if spec is int:
						pre[slot] = {} if spec < 0 else Game.make_item(hid, slot, spec, "rare")
						continue
					var mat: int = {"a": 6, "b": 3, "c": 5}.get(str(spec).left(1), 5)
					var it := Game.make_item(hid, slot, mat, "rare")
					it["look"] = int(str(spec).right(1)) if str(spec).length() == 2 else 0
					if DB.SETS.has(str(spec)):
						it["set"] = str(spec)
					pre[slot] = it
				GearLook.apply(a, hid, pre)
				a.play(DB.HEROES[hid]["anim"]["idle"], 0.0)
		cam2.look_at_from_position(Vector3(0, -2.9, 21.0 + (cols.size() - 4) * 4.0), Vector3(0, -2.9, 0), Vector3.UP)
		await _wait(1.0)
		return
	if kind == "arms":
		# Every weapon and offhand look in each hero's hands, one hero a row.
		var cam3 := Camera3D.new()
		root.add_child(cam3)
		cam3.fov = 30
		var most := 0
		var rows: Array = DB.HERO_ORDER if only == "" else [only]
		for r in rows.size():
			var hid: String = rows[r]
			var looks := {}
			for slot in ["weapon", "trinket"]:
				looks[slot] = []
				for st: Dictionary in GearDB.LINES[hid][slot]:
					for k in st.get("alts", []).size() + 1:
						looks[slot].append([int(st["from"]), k])
			var n: int = max(looks["weapon"].size(), looks["trinket"].size())
			most = max(most, n)
			for c in n:
				var a := Actor.new()
				root.add_child(a)
				a.build_model(DB.HEROES[hid]["model"], {}, Color(0.5, 0.6, 1.0), 0.2)
				a.position = Vector3(c * 1.5, -r * 2.4, 0)
				a.rotation.y = 0.5
				var pre := {}
				for slot in DB.SLOTS:
					pre[slot] = Game.make_item(hid, slot, 5, "rare")
					pre[slot]["look"] = 0
				for slot in ["weapon", "trinket"]:
					var lk: Array = looks[slot][min(c, looks[slot].size() - 1)]
					pre[slot] = Game.make_item(hid, slot, lk[0], "rare")
					pre[slot]["look"] = lk[1]
				GearLook.apply(a, hid, pre)
				a.play(DB.HEROES[hid]["anim"]["idle"], 0.0)
				var lb := Label3D.new()
				lb.text = GearDB.base_name(pre["weapon"]) + "\n" + GearDB.base_name(pre["trinket"])
				lb.font_size = 20
				lb.pixel_size = 0.004
				lb.position = a.position + Vector3(0, -0.25, 0.5)
				lb.no_depth_test = true
				root.add_child(lb)
		var mid := Vector3((most - 1) * 0.75, -(rows.size() - 1) * 1.2, 0)
		cam3.look_at_from_position(mid + Vector3(0, 0.9, 1.0 + most * 1.1 + (rows.size() - 1) * 2.5), mid + Vector3(0, 0.9, 0), Vector3.UP)
		await _wait(1.0)
		return
	if kind == "parts":
		names = ["Knight", "Barbarian", "Mage", "Ranger", "Rogue_Hooded", "Skeleton_Warrior", "Skeleton_Mage", "Skeleton_Rogue"]
	else:
		for f in ResourceLoader.list_directory(KK.WEAPON_DIR):
			if f.ends_with(".gltf"):
				names.append(f)
		for k in GearDB.KITS:
			names.append("kit:" + k)
	var cols := 4 if kind == "parts" else 8
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.fov = 30
	var rows := int(ceil(names.size() / float(cols)))
	for i in names.size():
		var pos := Vector3((i % cols - (cols - 1) * 0.5) * (1.7 if kind == "parts" else 1.0), -(i / cols) * (2.2 if kind == "parts" else 1.4), 0)
		if kind == "parts":
			var a := Actor.new()
			root.add_child(a)
			a.build_model(names[i], {}, Color(0.5, 0.6, 1.0), 0.2, Color(0, 0, 0, 0), 1.0)
			a.position = pos
			a.play("Idle_A", 0.0)
		else:
			var w := GearLook.prop_for(names[i])
			w.position = pos
			root.add_child(w)
			var lb := Label3D.new()
			lb.text = str(names[i]).trim_suffix(".gltf")
			lb.font_size = 24
			lb.pixel_size = 0.004
			lb.position = pos + Vector3(0, -0.7, 0)
			lb.no_depth_test = true
			root.add_child(lb)
	var w_total := cols * (1.7 if kind == "parts" else 1.0)
	cam.look_at_from_position(Vector3(0, -(rows - 1) * (1.1 if kind == "parts" else 0.7) + (0.9 if kind == "parts" else 0.0), 11.0 + rows * 1.5), Vector3(0, -(rows - 1) * (1.1 if kind == "parts" else 0.7) + (0.9 if kind == "parts" else 0.0), 0), Vector3.UP)
	await _wait(1.0)


func _save(name_: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [_shots_dir, name_])
	var draws := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var prims := int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	print("SHOT %s draws=%d objects=%d prims=%d nodes=%d" % [name_, draws, Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME), prims, Performance.get_monitor(Performance.OBJECT_NODE_COUNT)])
	if draws > BUDGET_DRAWS or prims > BUDGET_PRIMS:
		print("BUDGET WARNING %s: %d draw calls (limit %d), %d triangles (limit %d)" % [name_, draws, BUDGET_DRAWS, prims, BUDGET_PRIMS])
