extends Node

const SCREENS := {
	"char_select": preload("res://scripts/char_select.gd"),
	"home": preload("res://scripts/home_screen.gd"),
	"heroes": preload("res://scripts/hero_screen.gd"),
	"trophy": preload("res://scripts/trophy_screen.gd"),
	"chest": preload("res://scripts/chest_screen.gd"),
	"log": preload("res://scripts/log_screen.gd"),
	"slayer": preload("res://scripts/slayer_screen.gd"),
	"skills": preload("res://scripts/skills_screen.gd"),
	"stash": preload("res://scripts/stash_screen.gd"),
	"forge": preload("res://scripts/forge_screen.gd"),
	"credits": preload("res://scripts/credits_screen.gd"),
	"settings": preload("res://scripts/settings_screen.gd"),
	"run": preload("res://scripts/run_screen.gd"),
}

var current: Node


func _ready() -> void:
	# 0 means "vsync to the display". On ProMotion iPhones the iOS export
	# asks for 120Hz via display/window/ios/allow_high_refresh_rate.
	Engine.max_fps = 0
	Input.use_accumulated_input = false
	if OS.get_cmdline_user_args().has("--balance"):
		SimCheck.balance()
		get_tree().quit()
		return
	if OS.get_cmdline_user_args().has("--sim-check"):
		var code := SimCheck.run()
		get_tree().quit(code)
		return
	if OS.get_cmdline_user_args().has("--bake-portraits"):
		var baker := PortraitBaker.new()
		add_child(baker)
		var only: Array = []
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--only="):
				only = arg.substr(7).split(",")
			if arg.begins_with("--turn="):
				baker._turn_override = float(arg.substr(7))
		await baker.run(only)
		get_tree().quit()
		return
	if OS.get_cmdline_user_args().has("--bake-icons"):
		var icons := IconBaker.new()
		add_child(icons)
		await icons.run()
		get_tree().quit()
		return
	if OS.get_cmdline_user_args().has("--bake-chests"):
		var chests := ChestBaker.new()
		add_child(chests)
		await chests.run()
		get_tree().quit()
		return
	if OS.get_cmdline_user_args().has("--bake-banners"):
		var banners := BannerBaker.new()
		add_child(banners)
		await banners.run()
		get_tree().quit()
		return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--movie="):
			var director := MovieDirector.new()
			add_child(director)
			director.run(self, arg.substr(8))
			return
	if OS.get_cmdline_user_args().has("--capture"):
		_capture()
		return
	if OS.get_cmdline_user_args().has("--ota-probe"):
		_ota_probe()
		return
	# The character select is the front door: the player picks the hero who
	# walks into the world, and the town is where the game opens after that.
	go("char_select")
	_ota_hook()


## OTA content patches (scripts/ota_boot.gd): announce a newly applied pack
## once, and note a staged one. Read through get_node_or_null so this file
## never depends on the bootstrap's script. Update kicks can block boot with
## the tree paused; wait that out before reading the result.
func _ota_hook() -> void:
	var ota := get_node_or_null("/root/Ota")
	if ota == null:
		return
	while bool(ota.get("blocking")):
		await get_tree().process_frame
	if bool(ota.get("just_updated")):
		get_tree().create_timer(0.9).timeout.connect(func() -> void:
			ota_toast("UPDATED TO BUILD %d" % int(ota.get("build")), "New content is live"))
	if ota.has_signal("update_ready"):
		ota.update_ready.connect(func(b: int) -> void:
			if current and current.get_script() != SCREENS["run"]:
				ota_toast("BUILD %d READY" % b, "Applies next time you open the game"))


## Desktop OTA test: boot normally, shoot Settings (build line) and the
## boot screen (the hub), wait for the background check to settle, print the
## state.
func _ota_probe() -> void:
	var t0 := Time.get_ticks_msec()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_shot_dir = arg.substr(6)
	DirAccess.make_dir_recursive_absolute(_shot_dir)
	go("hub")
	_ota_hook()
	await get_tree().process_frame
	print("OTA_PROBE hub_ms=%d" % (Time.get_ticks_msec() - t0))
	await get_tree().create_timer(1.3).timeout
	await _shot("ota_hub")
	go("settings")
	await _settle()
	await _shot("ota_settings")
	var ota := get_node_or_null("/root/Ota")
	while str(ota.status) == "checking" or str(ota.status).begins_with("downloading") or str(ota.status) == "verifying":
		await get_tree().create_timer(0.1).timeout
	await get_tree().create_timer(4.5).timeout
	print("OTA_PROBE state=%s" % JSON.stringify({"baked": ota.baked_build, "ota": ota.ota_build, "build": ota.build,
		"just_updated": ota.just_updated, "rolled_back": ota.rolled_back, "pending": ota.pending_build,
		"status": ota.status, "flag": FileAccess.file_exists("user://ota/booting.flag"),
		"elapsed_ms": Time.get_ticks_msec() - t0, "line": SCREENS["settings"].build_line(ota)}))
	get_tree().quit()


## A forged plaque that drops in under the safe area, holds, then lifts away.
func ota_toast(title: String, sub: String) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 90
	add_child(layer)
	var holder := Control.new()
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(holder)
	var plate := UiKit.Plate.new()
	plate.kind = "plaque"
	plate.pad = 22
	plate.glow = Color(UiKit.GOLD, 0.35)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_child(col)
	var head := UiKit.label(title, 30, UiKit.GOLD.lightened(0.2), "x", 5)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(head)
	var line := UiKit.label(sub, 22, UiKit.CREAM, "b", 4)
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(line)
	holder.add_child(plate)
	var top := float(UiKit.safe_insets()["t"]) + 96.0
	plate.set_anchors_preset(Control.PRESET_CENTER_TOP)
	plate.custom_minimum_size = Vector2(500, 0)
	plate.offset_left = -250
	plate.offset_right = 250
	plate.offset_top = top - 40
	plate.modulate.a = 0.0
	AudioDirector.sfx("ui_toggle")
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(plate, "modulate:a", 1.0, 0.18)
	tw.tween_property(plate, "offset_top", top, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.chain().tween_interval(2.6)
	tw.chain().tween_property(plate, "modulate:a", 0.0, 0.35)
	tw.chain().tween_callback(layer.queue_free)


func go(screen: String, args: Dictionary = {}) -> void:
	call_deferred("_swap", screen, args)


func _swap(screen: String, args: Dictionary) -> void:
	if current:
		if current.has_method("leave") and screen != "run" and current.get_script() != SCREENS["run"]:
			current.leave(ScreenBase.slide_from)
		else:
			current.queue_free()
		current = null
	# The hub is the front door: Barrow Haven is a screen of its own, not
	# one of the menu scripts in the registry.
	if screen == "hub":
		current = HubScreen.new()
	else:
		current = SCREENS[screen].new()
	add_child(current)
	if current.has_signal("travel"):
		current.travel.connect(go)
	if current.has_method("open"):
		current.open(args)


var _shot_dir := "/workspace/captures"
var _want: Array = []


func _capture() -> void:
	print("CAPTURE_START")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			_want = arg.substr(8).split(",")
		if arg.begins_with("--out="):
			_shot_dir = arg.substr(6)
	DirAccess.make_dir_recursive_absolute(_shot_dir)
	SaveGame.reset_new()
	SaveGame.data["trophies"] = 46
	SaveGame.data["coins"] = 135
	# Drawer: one ready, one locked (shows its timer), one unlocking.
	var now := int(Time.get_unix_time_from_system())
	SaveGame.data["chests"].append({"kind": "hunt", "biome": "meadow", "seed": 3, "ready_at": now - 1})
	SaveGame.data["chests"].append({"kind": "scrap", "biome": "meadow", "seed": 4})
	SaveGame.data["chests"].append({"kind": "hunt", "biome": "volcano", "seed": 5, "ready_at": now + 2537})
	# CC_LEFT=1 / CC_REDUCE_FLASH=1: capture with those accessibility settings
	# on (in memory only; the save is not written).
	# Written into the in-memory save too: AudioDirector reloads settings
	# from it (deferred) after start-up.
	for pair in [["CC_LEFT", "left_handed"], ["CC_REDUCE_FLASH", "reduce_flashing"]]:
		if OS.get_environment(pair[0]) == "1":
			var st = SaveGame.data.get("settings", {})
			if not st is Dictionary:
				st = {}
			st[pair[1]] = true
			SaveGame.data["settings"] = st
			AudioDirector.settings[pair[1]] = true
	# CC_HERO equips another hero for the whole capture (home, heroes, hunts).
	var cap_hero := OS.get_environment("CC_HERO")
	if cap_hero != "":
		SaveGame.hero(cap_hero)["unlocked"] = true
		SaveGame.set_featured(cap_hero)
	# Captures show the whole four-knight roster.
	for hid in Catalog.playable_ids():
		SaveGame.hero(hid)["unlocked"] = true
	# CC_DEMO_GEAR: a few earned pieces on the featured hero (iron helm,
	# gloves and weapon on; a blackened chest owned but locked behind
	# Defence 20) so the equip layout shows filled, empty and locked states.
	if OS.get_environment("CC_DEMO_GEAR") != "":
		var fh := SaveGame.featured_id()
		for piece in ["helm.1", "gloves.1", "weapon.1", "chest.2", "boots.1"]:
			GearDB.grant("%s.%s" % [fh, piece])
		for piece in ["helm.1", "gloves.1", "weapon.1"]:
			GearDB.equip(fh, "%s.%s" % [fh, piece])
		# Enough coins to show gear reinforcing as affordable.
		SaveGame.data["coins"] = maxi(int(SaveGame.data["coins"]), 240)
	if _wants("char"):
		go("char_select")
		await _settle()
		await _shot("char")
	if _wants("hub"):
		go("hub")
		await _settle()
		if current != null and current.view != null and current.view.camera != null:
			for gate in current.view.camp.list_gate_markers():
				var at: Vector2 = current.view.camera.unproject_position((gate["pos"] as Vector3) + Vector3(0.0, 1.4, 0.0))
				print("GATE ", str(gate["tier"]), " open=", str(gate["open"]), " screen=", at, " tap=", current.view.gate_at(at))
		await _shot("hub")
	if _wants("hubhero"):
		go("hub")
		await _settle()
		if current != null and current.has_method("_open_hero_sheet"):
			current._open_hero_sheet()
		await _settle()
		await _shot("hubhero")
	if _wants("home"):
		go("home")
		await _settle()
		await _shot("home")
	if _wants("map"):
		go("hub")
		await _settle()
		await _shot("map")
	if _wants("heroes"):
		go("heroes", {"biome": "meadow"})
		await _settle()
		await _shot("heroes")
	if _wants("equip"):
		go("heroes", {"biome": "meadow"})
		await _settle()
		if current != null and current.has_method("open_slot"):
			current.open_slot("chest")
		await _settle()
		await _shot("equip")
	if _wants("progress"):
		# Progression proof from a fresh armory: bare, then a scripted grant
		# sequence standing in for drops (camp), a chest and a boss, each
		# equipped through GearDB so the requirement gates still apply.
		var ph := SaveGame.featured_id()
		SaveGame.data.erase("armory")
		var steps := [
			["progress_0_bare", []],
			["progress_1_camp_iron", ["helm.1", "boots.1", "weapon.1"]],
			["progress_2_chest_iron", ["chest.1", "gloves.1", "pauldrons.1", "offhand.1", "charm.1"]],
			["progress_3_boss_steel", ["helm.2", "chest.2", "pauldrons.2", "gloves.2", "boots.2", "weapon.2", "offhand.2", "charm.2"]],
			["progress_4_rune", ["helm.3", "chest.3", "pauldrons.3", "gloves.3", "boots.3", "weapon.3", "offhand.3", "charm.3"]],
		]
		for st in steps:
			if str(st[0]).ends_with("steel") or str(st[0]).ends_with("rune"):
				var lv := 20 if str(st[0]).ends_with("steel") else 40
				for sk in ["attack", "strength", "defence", "magic", "hitpoints"]:
					GearDB.add_xp(ph, sk, maxi(0, GearDB.xp_for_level(lv) - GearDB.xp(ph, sk)))
			for piece in st[1]:
				var pid := "%s.%s" % [ph, piece]
				if GearDB.is_item(pid):
					GearDB.grant(pid)
					GearDB.equip(ph, pid)
			go("heroes", {"biome": "meadow"})
			await _settle()
			await _shot(str(st[0]))
	SaveGame.hero(SaveGame.featured_id())["cards"] = 8
	if _wants("credits"):
		go("credits")
		await _settle()
		await _shot("credits")
	_seed_log()
	if _wants("log"):
		go("log")
		await _settle()
		await _shot("log")
	if _wants("slayer"):
		go("slayer")
		await _settle()
		await _shot("slayer")
	if _wants("settings"):
		go("settings")
		await _settle()
		await _shot("settings")
	if _wants("skills"):
		go("skills")
		await _settle()
		await _shot("skills")
	if _wants("materials"):
		go("skills")
		await _settle()
		current.show_tab("materials")
		await _settle()
		await _shot("materials")
	if _wants("trophy"):
		go("trophy")
		await _settle()
		# Let the gilded fill finish climbing to the trophy count.
		await get_tree().create_timer(1.3).timeout
		await _shot("trophy")
	if _wants("explore") or _wants("fog") or _wants("minimap") or _wants("lair"):
		var cap_biome := OS.get_environment("CC_BIOME")
		go("run", {"biome": cap_biome if cap_biome != "" else "meadow", "hero": SaveGame.featured_id(), "seed": 11})
		await _settle()
		var run = current
		var sim: RunSim = run.sim
		# Walk out of the start a little so the fog shows a trail behind.
		run.drive = Vector2(0.2, -1).normalized()
		var t0 := sim.time
		while sim.time < t0 + 2.2:
			await get_tree().process_frame
		run.drive = Vector2.ZERO
		if OS.get_cmdline_user_args().has("--debug-wave"):
			var st: Stage3D = run.stage
			print("CAMDBG hero=", sim.heroes[0].pos, " hero3=", st._to3(sim.heroes[0].pos), " look=", st._look, " cam=", st.camera.global_position, " proj=", st.project(sim.heroes[0].pos), " view=", get_viewport().get_visible_rect().size, " vp=", st.viewport.size, " start=", sim.map.start)
			get_tree().quit()
			return
		await _shot("fog")
		if OS.get_environment("CC_FOGONLY") == "1":
			var stg: Stage3D = run.stage
			stg._fog_img.save_png("/tmp/fogimg.png")
			var hc: int = sim.map.cell_index(sim.heroes[0].pos)
			print("FOGDBG hero=", sim.heroes[0].pos, " cell=", hc % sim.map.grid_w, ",", hc / sim.map.grid_w, " grid=", sim.map.grid_w, "x", sim.map.grid_h, " decal=", stg._fog_decal.global_position, " hero3=", stg._to3(sim.heroes[0].pos))
			get_tree().quit()
			return
		# Close on the nearest camp: it notices the hero and the fight starts.
		var hero = sim.heroes[0]
		var best: Dictionary = {}
		for c in sim.map.camps:
			if best.is_empty() or (c["pos"] as Vector2).distance_to(hero.pos) < (best["pos"] as Vector2).distance_to(hero.pos):
				best = c
		var near: Vector2 = sim.map.push_inside((best["pos"] as Vector2) + Vector2(0, 520), 40.0)
		hero.pos = near
		hero.prev = near
		hero.dodge_iframes = 30.0
		t0 = sim.time
		while sim.time < t0 + 2.6:
			await get_tree().process_frame
		# Show the forged stick mid-push, as a thumb would hold it.
		var vsz := get_viewport().get_visible_rect().size
		run._begin_stick(vsz * Vector2(0.5, 0.8))
		run._drag_stick(vsz * Vector2(0.5, 0.8) + Vector2(30, -24))
		run.drive = Vector2.ZERO
		await get_tree().process_frame
		await _shot("explore")
		run._end_stick()
		run.minimap.toggle()
		await get_tree().create_timer(0.4).timeout
		await _shot("minimap")
		run.minimap.toggle()
		await get_tree().create_timer(0.2).timeout
		# The lair, from just outside its rune circle.
		var at: Vector2 = sim.map.push_inside(sim.map.lair + Vector2(0, sim.map.lair_r * 0.95), 40.0)
		hero.pos = at
		hero.prev = at
		t0 = sim.time
		while sim.time < t0 + 1.2:
			await get_tree().process_frame
		await _shot("lair")
		run.drive = Vector2(0, -1)
		t0 = sim.time
		while sim.phase != "boss" and sim.time < t0 + 6.0:
			await get_tree().process_frame
		run.drive = Vector2.ZERO
		t0 = sim.time
		while sim.time < t0 + 2.4:
			await get_tree().process_frame
		await _shot("boss")
		if _want.has("explore") or _want.has("lair"):
			get_tree().quit()
			return
	if _wants("zone") or _wants("zonemap"):
		# A depth zone: the tier's own ground, walked from the south gate.
		go("run", {"biome": "meadow", "hero": SaveGame.featured_id(), "tier": "fringe", "seed": 7})
		await _settle()
		var zrun = current
		var zsim: RunSim = zrun.sim
		zrun.drive = Vector2(0.15, -1).normalized()
		var zt0 := zsim.time
		while zsim.time < zt0 + 3.0:
			await get_tree().process_frame
		zrun.drive = Vector2.ZERO
		await _shot("zone")
		if _wants("zonemap"):
			zrun.minimap.toggle()
			await get_tree().create_timer(0.4).timeout
			await _shot("zonemap")
		get_tree().quit()
		return
	if _wants("hunt") or _wants("boss") or _wants("levelup") or _wants("rare") or _wants("victory") or _wants("defeat"):
		go("run", {"biome": "meadow", "hero": SaveGame.featured_id(), "seed": 11})
		await _settle()
		current.drive = Vector2(0.35, 0.15).normalized()
		# Sim time, not wall time: software rendering runs the hunt slowly.
		# Wait for a pack to close in so the shot shows a real wave.
		var start := Time.get_ticks_msec()
		# Hold until the frame tells the story: 3+ critters in clear view below
		# the HUD, one already wounded (health bar), and one off screen (arrow).
		var staged := false
		while Time.get_ticks_msec() - start < 150000:
			await get_tree().process_frame
			if current.sim.time > 1.0:
				current.drive = Vector2.ZERO
			if current.sim.time < 1.2:
				continue
			if not staged and current.sim.time > 2.5:
				# Packs die at range before they close in, so stage one real
				# wave in view plus two stragglers off screen for the arrows.
				staged = true
				var hero_at: Vector2 = current.sim.heroes[0].pos
				var mix := [0, 1, 2, 0, 1, 3]
				var offs := [Vector2(-160, -190), Vector2(150, -160), Vector2(-130, 220), Vector2(170, 240), Vector2(20, -280), Vector2(-190, 60)]
				for k in offs.size():
					current.sim._spawn_minion(mix[k], current.sim._clamp_point(hero_at + offs[k], 24.0))
				for off in [Vector2(-330, 120), Vector2(310, -540)]:
					current.sim._spawn_minion(1, current.sim._clamp_point(hero_at + off, 24.0))
				if OS.get_environment("CC_DEMO_LOOT") != "":
					# Showcase: one ground drop per tier near the hero.
					var hid := SaveGame.featured_id()
					var drops := [[Vector2(-120, 60), "%s.boots.1" % hid], [Vector2(110, 90), "%s.helm.2" % hid], [Vector2(10, 170), "%s.weapon.3" % hid]]
					for d in drops:
						current.sim.events.append({"type": "gear_drop", "key": d[1], "item": d[1], "pos": current.sim._clamp_point(hero_at + d[0], 24.0)})
			var seen := _framing(current)
			if seen[0] >= 3 and seen[1] >= 1 and seen[2] >= 1:
				break
		var waited := 0.0
		if OS.get_cmdline_user_args().has("--debug-wave"):
			var hero: Vector2 = current.sim.heroes[0].pos
			for actor in current.sim.actors:
				if actor.kind == "minion" and actor.alive:
					var body = current.stage._bodies.get(actor.id)
					print("WAVE rel=", actor.pos - hero, " scr=", current.stage.project(actor.pos), " body=", body != null and body.visible, " sprite=", actor.sprite, " gpos=", body.global_position if body else null)
			print("WAVE cam=", current.stage.camera.global_position, " hero3=", current.stage._to3(hero))
		await _shot("hunt")
		if OS.get_environment("CC_DEMO_LOOT") != "":
			# Pick up the rune drop to show the collapse and streak.
			var hid2 := SaveGame.featured_id()
			current.sim.events.append({"type": "gear_pickup", "key": "%s.weapon.3" % hid2, "item": "%s.weapon.3" % hid2, "pos": current.sim.heroes[0].pos + Vector2(10, 170)})
			await get_tree().create_timer(0.12).timeout
			await _shot("pickup")
		current.sim.debug_offer()
		var show: Array = ["vitality", "magnet", "mage_radius"]
		current.sim.offer = show
		if current.sim.events.size() > 0:
			current.sim.events[current.sim.events.size() - 1]["offer"] = show.duplicate()
		await get_tree().create_timer(0.55).timeout
		await _shot("levelup")
		current._pick(0)
		await _settle()
		current.drive = Vector2(0, -1)
		await get_tree().create_timer(1.05).timeout
		current.drive = Vector2.ZERO
		current.sim.begin_boss()
		var t0: float = current.sim.time
		while current.sim.time < t0 + 2.4 and waited < 180.0:
			await get_tree().create_timer(0.2).timeout
			waited += 0.2
		await _shot("boss")
		if _wants("xray") and current.sim.boss != null:
			# Tuck the hero just behind the boss to show the x-ray rim.
			var hero_actor = current.sim.heroes[0]
			hero_actor.dodge_iframes = 5.0
			# Freeze the sim so knockback can't shove the hero back out.
			current.sim.paused = true
			for i in 24:
				hero_actor.pos = current.sim.boss.pos + Vector2(6, -50)
				hero_actor.prev = hero_actor.pos
				await get_tree().process_frame
			await _shot("xray")
			current.sim.paused = false
		SaveGame.debug_rare = true
		current.sim.debug_slay_boss()
		await _settle()
		await _shot("rare")
		if _wants("victory"):
			current._show_victory(str(Catalog.critter("thistle")["name"]))
			await get_tree().create_timer(2.6 if not current._spoils().is_empty() else 0.8).timeout
			await _shot("victory")
		if _wants("drawer"):
			# Back home: the chest just won drops into the last slot.
			go("home")
			await get_tree().create_timer(0.75).timeout
			await _shot("drawer")
			await get_tree().create_timer(1.2).timeout
			await _shot("drawer_full")
			go("run", {"biome": "meadow", "hero": SaveGame.featured_id(), "seed": 11})
			await _settle()
		if _wants("defeat"):
			SaveGame.last_chest = {"tone": "wood", "rarity": "common", "full": SaveGame.slots_full()}
			current._show_defeat("")
			await get_tree().create_timer(0.8).timeout
			await _shot("defeat")
	if _wants("chest"):
		go("chest", {"index": SaveGame.first_ready()})
		await _settle()
		await _shot("chest")
		current._reveal()
		await get_tree().create_timer(0.45).timeout
		await _shot("burst")
		await get_tree().create_timer(1.2).timeout
		await _shot("loot")
	get_tree().quit()


func _wants(name: String) -> bool:
	return _want.is_empty() or name in _want


## [critters on screen in the clear play area, wounded among them, off screen]
func _framing(run: Node) -> Array:
	var sim: RunSim = run.sim
	var stage: Stage3D = run.stage
	var view := get_viewport().get_visible_rect()
	var pad := UiKit.safe_insets()
	var clear := Rect2(view.position.x + 40.0, view.position.y + float(pad["t"]) + 340.0, view.size.x - 80.0, view.size.y - float(pad["t"]) - float(pad["b"]) - 500.0)
	var on := 0
	var hurt := 0
	var off := 0
	for actor in sim.actors:
		if not actor.alive or actor.team == 0 or actor.kind != "minion":
			continue
		var p: Vector2 = stage.project(actor.pos, 0.0)
		if clear.has_point(p):
			on += 1
			if actor.hp < actor.max_hp:
				hurt += 1
		elif not view.has_point(p):
			off += 1
	return [on, hurt, off]


func _near_minions(sim: RunSim) -> int:
	var n := 0
	var hero: Vector2 = sim.heroes[0].pos if not sim.heroes.is_empty() else Vector2.ZERO
	for actor in sim.actors:
		if actor.alive and actor.kind == "minion" and RunSim.VIEW_BOX.grow(-20.0).has_point(actor.pos - hero):
			n += 1
	return n


func _seed_log() -> void:
	var want := [
		"thistle_purse", "meadow_fiber", "pollen", "thistle_ember_cards", "thistle_claw", "flower_crown", "thistle_pet",
		"caplet_purse", "cap_bits", "caplet_wand", "toad_cap", "caplet_pet",
	]
	for id in want:
		if id not in SaveGame.data["log"]:
			SaveGame.data["log"].append(id)
	SaveGame.data["pets"]["thistle_pet"] = true
	SaveGame.data["active_pet"] = "thistle_pet"
	SaveGame.data["kills"]["thistle"] = 3
	SaveGame.data["skills"]["woodcutting"] = 200
	SaveGame.data["slayer"]["points"] = 55
	SaveGame.data["slayer"]["streak"] = 2
	# A bag with a few materials in it: two boss spoils and three gathered
	# resources, so the Materials tab has rows to show.
	SaveGame.data["materials"] = {
		"meadow_fiber": 4, "flower_crown": 1, "willow_logs": 12,
		"brook_fish": 5, "copper_ore": 3,
	}
	var task := Catalog.slayer_task("meadow_critters").duplicate()
	task["have"] = 18
	SaveGame.data["slayer"]["task"] = task
	SaveGame.data["cosmetic"] = "ribbon"


func _settle() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(0.42).timeout


func _shot(shot_name: String) -> void:
	print("SHOT_START ", shot_name)
	await RenderingServer.frame_post_draw
	print("SHOT_FRAME ", shot_name)
	var image := get_viewport().get_texture().get_image()
	if image == null:
		return
	image.save_png("%s/%s.png" % [_shot_dir, shot_name])
	# Frame budget for the shot (all viewports): compare with the 150 draw /
	# 300k triangle target.
	print("PERF %s draws=%d prims=%d objects=%d" % [shot_name,
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)])
	var vps: Array = [get_viewport()]
	vps.append_array(get_tree().root.find_children("*", "SubViewport", true, false))
	for v in vps:
		var vpt := v as Viewport
		var parts := []
		for t in [["vis", Viewport.RENDER_INFO_TYPE_VISIBLE], ["shadow", Viewport.RENDER_INFO_TYPE_SHADOW], ["canvas", Viewport.RENDER_INFO_TYPE_CANVAS]]:
			var d := vpt.get_render_info(t[1], Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME)
			if d > 0:
				parts.append("%s=%d/%dk" % [t[0], d, vpt.get_render_info(t[1], Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME) / 1000])
		if not parts.is_empty():
			print("PERF %s   vp %s %s" % [shot_name, vpt.name, " ".join(parts)])
		if vpt is SubViewport and vpt.get_camera_3d() != null and OS.get_environment("CC_PERF_DUMP") != "":
			_perf_dump(shot_name, vpt as SubViewport)
	if OS.get_environment("CC_PERF_DUMP") != "" and shot_name in ["lair", "explore"]:
		await _canvas_attrib(shot_name, current, 0)


## Dev aid: canvas draws each HUD branch costs, by hiding it for a frame.
func _canvas_draws() -> int:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	return get_viewport().get_render_info(Viewport.RENDER_INFO_TYPE_CANVAS, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME)


func _canvas_attrib(shot_name: String, node: Node, depth: int) -> void:
	var base: int = await _canvas_draws()
	for child in node.get_children():
		var ci := child as CanvasItem
		if ci == null or not ci.visible or child is SubViewportContainer and false:
			continue
		ci.visible = false
		var without: int = await _canvas_draws()
		ci.visible = true
		var delta := base - without
		if delta >= 4:
			var extra := ""
			if ci.material != null:
				extra += " mat"
			if ci.get_script() != null:
				extra += " " + str(ci.get_script().resource_path.get_file())
			print("CDUMP %s %s%s [%s] %d%s kids=%d" % [shot_name, "  ".repeat(depth), child.name, child.get_class(), delta, extra, child.get_child_count()])
			if delta >= 12 and depth < 5:
				await _canvas_attrib(shot_name, child, depth + 1)


## Dev aid (CC_PERF_DUMP=1): which nodes in the camera frustum cost draws.
func _perf_dump(shot_name: String, sv: SubViewport) -> void:
	var cam := sv.get_camera_3d()
	var planes := cam.get_frustum()
	var groups := {}
	for n in sv.find_children("*", "GeometryInstance3D", true, false):
		var g := n as GeometryInstance3D
		if not g.is_visible_in_tree():
			continue
		var box := g.global_transform * g.get_aabb()
		var inside := true
		for pl in planes:
			var c := box.get_center()
			var e := box.size * 0.5
			var r := absf(pl.normal.x) * e.x + absf(pl.normal.y) * e.y + absf(pl.normal.z) * e.z
			if pl.distance_to(c) > r:
				inside = false
				break
		if not inside:
			continue
		var surf := 1
		var tris := 0
		var mesh: Mesh = null
		var inst := 1
		if g is MeshInstance3D:
			mesh = (g as MeshInstance3D).mesh
		elif g is MultiMeshInstance3D and (g as MultiMeshInstance3D).multimesh != null:
			mesh = (g as MultiMeshInstance3D).multimesh.mesh
			var mm := (g as MultiMeshInstance3D).multimesh
			inst = mm.visible_instance_count if mm.visible_instance_count >= 0 else mm.instance_count
		if mesh != null:
			surf = mesh.get_surface_count()
			if mesh is ArrayMesh:
				for si in surf:
					var idx := (mesh as ArrayMesh).surface_get_array_index_len(si)
					tris += (idx if idx > 0 else (mesh as ArrayMesh).surface_get_array_len(si)) / 3
		var par := g.get_parent()
		var key := "%s %s<%s> sh=%d" % [g.get_class(), String(g.name).rstrip("0123456789@"), String(par.name).rstrip("0123456789@") if par else "", g.cast_shadow]
		if not groups.has(key):
			groups[key] = [0, 0, 0]
		groups[key][0] += 1
		groups[key][1] += surf
		groups[key][2] += tris * inst
	var keys := groups.keys()
	keys.sort_custom(func(a, b): return groups[a][1] > groups[b][1])
	for k in keys:
		print("PDUMP %s nodes=%d surfaces=%d tris=%d  %s" % [shot_name, groups[k][0], groups[k][1], groups[k][2], k])


## The hub: Barrow Haven, the safe camp at the heart of the Barrow Lands.
## The camp itself is the HubScene (scenes/hub_scene.tscn) seen through the
## HubView; the screen over it is the counter: the stalls, the stash, the
## hero and the gates that lead out of the camp.
class HubScreen extends ScreenBase:
	## The camp scene: Barrow Haven itself.
	const CAMP := preload("res://scenes/hub_scene.tscn")
	## How much of the screen the camp takes; the counter sits below it.
	const CAMP_FRACTION := 0.50

	## The camp.
	var hub: HubScene
	## The camp view: the 3D camp and the hero standing in it.
	var view: HubView
	## The stall sheet, while a stall stands open.
	var sheet: Control

	var _stall := ""
	var _stall_title: Label
	var _stall_blurb: Label
	var _stall_coins: Label
	var _stall_result: Label
	var _stall_body: VBoxContainer
	## The hero sheet, while the choice of hero stands open.
	var _hero_sheet: Control

	## The challenge each gate is set to (tier id -> difficulty index).
	var _difficulty_pick: Dictionary = {}

	## The gate strip, so it can be rebuilt when a challenge is changed.
	var _ways_holder: VBoxContainer

	## The hero row: the hero who travels, and the button that changes him.
	var _hero_row: HBoxContainer


	## The camp paints the background, so the stone backdrop would only
	## cover it. This has to be set before the screen is built.
	func _init() -> void:
		paint_bg = false


	func build() -> void:
		# The camp is the top of the screen and the counter is the rest, so
		# the hub reads as a place the player stands in rather than a list
		# of buttons.
		view = HubView.new()
		view.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
		view.anchor_bottom = CAMP_FRACTION
		view.offset_bottom = 0.0
		# A tap on a standing stone in the camp walks the hero through it,
		# and a tap on a place opens the screen that belongs to it.
		view.gate_tapped.connect(func(tier_id: String) -> void: _travel(tier_id))
		view.place_tapped.connect(func(place_id: String) -> void: go(place_id))
		add_child(view)
		hub = view.camp
		# The counter's own dark plate, from the camp's lower edge down.
		var pad := insets()
		var shade := ColorRect.new()
		shade.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		shade.anchor_top = CAMP_FRACTION
		shade.offset_top = 0.0
		shade.color = Color(0.035, 0.03, 0.026, 0.9)
		shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(shade)
		var margin := MarginContainer.new()
		margin.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		margin.anchor_top = CAMP_FRACTION
		margin.offset_top = 0.0
		margin.add_theme_constant_override("margin_left", int(pad["l"]))
		margin.add_theme_constant_override("margin_right", int(pad["r"]))
		margin.add_theme_constant_override("margin_top", 14)
		margin.add_theme_constant_override("margin_bottom", int(pad["b"]))
		add_child(margin)
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 8)
		margin.add_child(box)
		box.add_child(header())
		box.add_child(h1(str(WorldData.hub_data().get("name", "Barrow Haven"))))
		box.add_child(body("The safe town. Nothing fights here."))
		var spacer := Control.new()
		spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
		box.add_child(spacer)
		box.add_child(_hero_row_widget())
		_ways_holder = VBoxContainer.new()
		_ways_holder.add_theme_constant_override("separation", 8)
		_ways_holder.add_child(_ways_out())
		box.add_child(_ways_holder)
		box.add_child(_stall_row())
		box.add_child(_service_row())


	## Who travels: the featured hero, his level, and the button that
	## changes him. The hero in the camp is this one.
	func _hero_row_widget() -> Control:
		_hero_row = HBoxContainer.new()
		_hero_row.add_theme_constant_override("separation", 12)
		var badge := UiKit.Badge.new()
		badge.level = int(SaveGame.hero(SaveGame.featured_id()).get("level", 1))
		badge.custom_minimum_size = Vector2(62, 62)
		_hero_row.add_child(badge)
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_theme_constant_override("separation", -2)
		col.add_child(_hero_name())
		col.add_child(_hero_role())
		_hero_row.add_child(col)
		var choose := UiKit.button("CHOOSE", 170, 78, "blue")
		choose.tooltip_text = "Pick the hero who travels"
		choose.pressed.connect(func() -> void: _open_hero_sheet())
		_hero_row.add_child(choose)
		return _hero_row


	## The featured hero's name.
	func _hero_name() -> Label:
		var info := Catalog.critter(SaveGame.featured_id())
		var label := UiKit.label(str(info.get("name", "Hero")).to_upper(), 30, UiKit.CREAM, "x", 4)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		return label


	## The featured hero's role.
	func _hero_role() -> Label:
		var info := Catalog.critter(SaveGame.featured_id())
		var label := UiKit.label(Catalog.role_name(str(info.get("role", ""))).to_upper(), 18, UiKit.GOLD, "b", 2)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		return label


	## The tier below this one, or "" when this is the shallowest.
	func _tier_below(tier_id: String) -> String:
		var order := WorldData.tier_order()
		for i in order.size():
			if str(order[i]) == tier_id:
				return str(order[i - 1]) if i > 0 else ""
		return ""


	## Why a gate stands shut: the tier below it has to be cleared first.
	func _seal_text(tier_id: String) -> String:
		var below := _tier_below(tier_id)
		if below == "":
			return "Sealed"
		return "Sealed \u00b7 clear %s to unlock" % WorldData.tier_name(below)


	## The ways out of the town: the two barriers in the town wall. The
	## north one leads deeper, the south one to the shallow ground, and a
	## barrier that stands shut says why.
	func _ways_out() -> Control:
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 6)
		for gate in WorldData.town_gates(SaveGame.data.get("tiers_cleared", {})):
			col.add_child(_way_row(gate))
		return col


	## One barrier: the gate, the ground behind it, and the way through.
	func _way_row(gate: Dictionary) -> Control:
		var tier_id := str(gate["tier"])
		var open := bool(gate["open"])
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var text_col := VBoxContainer.new()
		text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text_col.add_theme_constant_override("separation", -2)
		text_col.add_child(UiKit.label(str(gate["name"]).to_upper(), 26, UiKit.GOLD.lightened(0.2) if open else UiKit.MUTED, "x", 3))
		var note := UiKit.label(_way_note(tier_id, open), 17, UiKit.MUTED, "b", 0)
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text_col.add_child(note)
		row.add_child(text_col)
		var button := UiKit.button("LEAVE" if open else "SHUT", 170, 74, "gold" if open else "grey")
		button.disabled = not open
		if open:
			button.pressed.connect(func() -> void: _travel(tier_id))
		else:
			button.tooltip_text = "Clear the ground south of the town first."
		row.add_child(button)
		return row


	## What a barrier says under its name: the ground it leads into, or the
	## rule that keeps it shut.
	func _way_note(tier_id: String, open: bool) -> String:
		if not open:
			return "Shut until the Fringe is cleared."
		var description := WorldData.tier_description(tier_id)
		return description if description != "" else "The way out of the town."


	## A barrier that stands open leads out of the town into a hunt. A shut
	## one starts nothing.
	func _travel(tier_id: String) -> void:
		if not SaveGame.tier_open(tier_id):
			toast("That way is shut.")
			return
		_start_hunt(tier_id)


	## Starting a hunt from a barrier: the depth it leads into, the
	## challenge it is set to, and the hero who stands in the town.
	func _start_hunt(tier_id: String) -> void:
		var biome_id := Catalog.biome_for_tier(tier_id)
		SaveGame.data["last_biome"] = biome_id
		go("run", {
			"biome": biome_id,
			"hero": SaveGame.featured_id(),
			"tier": tier_id,
			"difficulty": _difficulty(tier_id),
		})


	## The challenge a way out is set to. Veteran and Nightmare open when
	## the ground has been cleared on that challenge.
	func _difficulty(tier_id: String) -> int:
		var biome_id := Catalog.biome_for_tier(tier_id)
		var open := SaveGame.difficulty_unlocked(biome_id)
		var picked := int(_difficulty_pick.get(tier_id, 0))
		return clampi(picked, 0, maxi(open, 0))


	## Steps a way out up to the next challenge it has earned.
	func _step_difficulty(tier_id: String) -> void:
		var biome_id := Catalog.biome_for_tier(tier_id)
		var open := SaveGame.difficulty_unlocked(biome_id)
		var now := _difficulty(tier_id)
		var next := now + 1
		if next > open:
			next = 0
		_difficulty_pick[tier_id] = next
		AudioDirector.sfx("ui_tap")
		_refresh_ways()
		toast("%s \u00b7 %s" % [WorldData.tier_name(tier_id), Catalog.TIER_NAMES[next]])


	## Rebuilds the ways out after a challenge was changed.
	func _refresh_ways() -> void:
		if _ways_holder == null:
			return
		for child in _ways_holder.get_children():
			child.queue_free()
		_ways_holder.add_child(_ways_out())



	## The stalls in the camp: one button per shop the hub keeps. The name
	## on the button is the stall's own, as the hub's trade sheet gives it.
	func _stall_row() -> Control:
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 14)
		var shops: Array = WorldData.hub_data().get("shops", [])
		for shop_id in shops:
			var id := str(shop_id)
			var info := hub.open_shop(id)
			var button := UiKit.button(str(info.get("name", id)).to_upper(), 0, 84, "gold")
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button.pressed.connect(func() -> void: _open_stall(id))
			row.add_child(button)
		return row


	## What the camp offers besides the stalls: the stash, the desk (which
	## still holds the skills, the log and the chests) and today's hunt.
	func _service_row() -> Control:
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 10)
		row.add_child(_service_button("STASH", "stash"))
		row.add_child(_service_button("DESK", "home"))
		var daily := UiKit.button("DAILY", 0, 84, "blue")
		daily.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		daily.tooltip_text = "Today's seeded hunt"
		daily.pressed.connect(_start_daily)
		row.add_child(daily)
		return row


	func _service_button(text: String, screen: String) -> Button:
		var button := UiKit.button(text, 0, 84, "blue")
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(func() -> void: go(screen))
		return button


	## Today's seeded challenge, run with the hero the camp holds. The
	## seed, day key and modifiers ride the run args so the run pins the
	## exact same hunt.
	func _start_daily() -> void:
		var key := Daily.today_key(int(Time.get_unix_time_from_system()))
		var biome_id := Daily.biome_for(key)
		SaveGame.data["last_biome"] = biome_id
		go("run", {
			"biome": biome_id,
			"hero": SaveGame.featured_id(),
			"tier": Catalog.tier_for_biome(biome_id),
			"seed": Daily.seed_for(key),
			"daily": key,
			"modifiers": Daily.modifiers_for(key),
		})


	## The hero sheet: the heroes the camp holds, one button each. The
	## chosen one stands in the camp and travels from it.
	func _open_hero_sheet() -> void:
		if _hero_sheet != null:
			return
		AudioDirector.sfx("ui_tap")
		_hero_sheet = Control.new()
		_hero_sheet.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(_hero_sheet)
		var dim := ColorRect.new()
		dim.color = Color(0, 0, 0, 0.7)
		dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		dim.gui_input.connect(func(e: InputEvent) -> void:
			if (e is InputEventMouseButton and e.pressed) or (e is InputEventScreenTouch and e.pressed):
				_close_hero_sheet()
		)
		_hero_sheet.add_child(dim)
		var pad := insets()
		var panel := PanelContainer.new()
		var empty := StyleBoxEmpty.new()
		for side in ["left", "right", "top", "bottom"]:
			empty.set("content_margin_" + side, 20)
		panel.add_theme_stylebox_override("panel", empty)
		panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		panel.offset_left = float(pad["l"]) + 16.0
		panel.offset_right = -float(pad["r"]) - 16.0
		panel.offset_bottom = -float(pad["b"]) - 16.0
		panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
		_hero_sheet.add_child(panel)
		var frame := UiKit.Frame.new("panel", "leather", {})
		frame.margin = 20.0
		panel.add_child(frame)
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 10)
		panel.add_child(box)
		var title := UiKit.title("WHO TRAVELS", 38)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(title)
		var list := VBoxContainer.new()
		list.add_theme_constant_override("separation", 8)
		box.add_child(list)
		for id in Catalog.playable_ids():
			if not bool(SaveGame.hero(id)["unlocked"]):
				continue
			list.add_child(_hero_choice(str(id)))
		var foot := HBoxContainer.new()
		foot.alignment = BoxContainer.ALIGNMENT_CENTER
		foot.add_theme_constant_override("separation", 14)
		var close := UiKit.secondary("Close", 240, 88)
		close.pressed.connect(_close_hero_sheet)
		foot.add_child(close)
		box.add_child(foot)


	## One hero in the sheet: his name, his role and the button that makes
	## him the one who travels.
	func _hero_choice(id: String) -> Control:
		var info := Catalog.critter(id)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_theme_constant_override("separation", -2)
		var name_label := UiKit.label(str(info.get("name", id)).to_upper(), 28, UiKit.CREAM, "x", 4)
		col.add_child(name_label)
		col.add_child(UiKit.label(Catalog.role_name(str(info.get("role", ""))).to_upper(), 17, UiKit.GOLD, "b", 2))
		row.add_child(col)
		if id == SaveGame.featured_id():
			var current := UiKit.button("READY", 170, 76, "grey")
			current.disabled = true
			row.add_child(current)
		else:
			var pick := UiKit.button("PICK", 170, 76, "gold")
			pick.pressed.connect(func() -> void: _pick_hero(id))
			row.add_child(pick)
		return row


	## Makes this hero the one who travels, and puts him in the camp.
	func _pick_hero(id: String) -> void:
		SaveGame.set_featured(id)
		AudioDirector.sfx("card_pick")
		AudioDirector.haptic("medium")
		if view != null:
			view.set_hero(id)
		_refresh_hero_row()
		toast("%s travels from the camp" % str(Catalog.critter(id)["name"]))
		_close_hero_sheet()


	## The hero row after a change: the new name, role and level.
	func _refresh_hero_row() -> void:
		if _hero_row == null:
			return
		for child in _hero_row.get_children():
			child.queue_free()
		var badge := UiKit.Badge.new()
		badge.level = int(SaveGame.hero(SaveGame.featured_id()).get("level", 1))
		badge.custom_minimum_size = Vector2(62, 62)
		_hero_row.add_child(badge)
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_theme_constant_override("separation", -2)
		col.add_child(_hero_name())
		col.add_child(_hero_role())
		_hero_row.add_child(col)
		var choose := UiKit.button("CHOOSE", 170, 78, "blue")
		choose.tooltip_text = "Pick the hero who travels"
		choose.pressed.connect(func() -> void: _open_hero_sheet())
		_hero_row.add_child(choose)


	func _close_hero_sheet() -> void:
		if _hero_sheet != null:
			_hero_sheet.queue_free()
		_hero_sheet = null


	## Opens a stall: the trade sheet the hub hands over, with what the
	## stall sells, what it buys out of the bag and the coins in the purse.
	func _open_stall(shop_id: String) -> void:
		_stall = shop_id
		_close_stall()
		sheet = Control.new()
		sheet.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(sheet)
		var dim := ColorRect.new()
		dim.color = Color(0, 0, 0, 0.62)
		dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		dim.gui_input.connect(func(e: InputEvent) -> void:
			if (e is InputEventMouseButton and e.pressed) or (e is InputEventScreenTouch and e.pressed):
				_close_stall()
		)
		sheet.add_child(dim)
		var pad := UiKit.safe_insets()
		var panel := PanelContainer.new()
		var empty := StyleBoxEmpty.new()
		for side in ["left", "right", "top", "bottom"]:
			empty.set("content_margin_" + side, 22)
		panel.add_theme_stylebox_override("panel", empty)
		panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		panel.offset_left = float(pad["l"]) + 16.0
		panel.offset_right = -float(pad["r"]) - 16.0
		panel.offset_bottom = -float(pad["b"]) - 16.0
		panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
		sheet.add_child(panel)
		var frame := UiKit.Frame.new("panel", "leather", {})
		frame.margin = 22.0
		panel.add_child(frame)
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 10)
		panel.add_child(box)
		_stall_title = UiKit.title("STALL", 40)
		_stall_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(_stall_title)
		_stall_blurb = UiKit.label("", 18, UiKit.CREAM, "b", 0)
		_stall_blurb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(_stall_blurb)
		_stall_coins = UiKit.label("%d coins" % int(SaveGame.data.get("coins", 0)), 20, UiKit.GOLD, "x", 3)
		_stall_coins.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(_stall_coins)
		_stall_result = UiKit.label("", 20, UiKit.MUTED, "x", 3)
		_stall_result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(_stall_result)
		var scroll := ScrollContainer.new()
		scroll.custom_minimum_size = Vector2(0, 420)
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		box.add_child(scroll)
		_stall_body = VBoxContainer.new()
		_stall_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_stall_body.add_theme_constant_override("separation", 8)
		scroll.add_child(_stall_body)
		pass_through(scroll)
		var foot := HBoxContainer.new()
		foot.alignment = BoxContainer.ALIGNMENT_CENTER
		foot.add_theme_constant_override("separation", 14)
		var close := UiKit.secondary("Close", 220, 88)
		close.pressed.connect(_close_stall)
		foot.add_child(close)
		var sell_all := UiKit.button("SELL ALL", 300, 88, "gold")
		sell_all.pressed.connect(func() -> void: _trade("all", -1))
		foot.add_child(sell_all)
		box.add_child(foot)
		_refresh_stall()


	func _close_stall() -> void:
		if sheet != null:
			sheet.queue_free()
		sheet = null
		_stall_body = null


	## Fills the sheet from the hub's trade sheet: what the stall sells,
	## what it buys out of the bag, and the coins in the purse.
	func _refresh_stall() -> void:
		if _stall_body == null:
			return
		for child in _stall_body.get_children():
			child.queue_free()
		var info := hub.open_shop(_stall)
		_stall_title.text = str(info.get("name", _stall)).to_upper()
		_stall_blurb.text = str(info.get("blurb", ""))
		_stall_coins.text = "%d coins" % int(SaveGame.data.get("coins", 0))
		var stock: Array = info.get("stock", [])
		if not stock.is_empty():
			_stall_body.add_child(UiKit.label("SELLS", 20, UiKit.GOLD, "x", 3))
			for entry in stock:
				_stall_body.add_child(_buy_row(entry))
		var bag: Dictionary = SaveGame.data.get("materials", {})
		var rows: Array = []
		var buys: Array = info.get("buys", [])
		for id in buys:
			var count := int(bag.get(str(id), 0))
			if count > 0:
				rows.append({"id": str(id), "count": count, "price": _sell_price(str(info.get("shop", "")), str(id))})
		if not rows.is_empty():
			_stall_body.add_child(UiKit.label("BUYS", 20, UiKit.GOLD, "x", 3))
			for row in rows:
				_stall_body.add_child(_sell_row(row))


	## A thing the stall sells: the name, what it does and what it costs.
	func _buy_row(entry: Dictionary) -> Control:
		var id := str(entry.get("id", ""))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(UiKit.label(str(entry.get("name", id)), 24, UiKit.CREAM, "x", 3))
		var detail := UiKit.label(str(entry.get("detail", "")), 16, UiKit.MUTED, "b", 0)
		detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(detail)
		row.add_child(col)
		var price := int(entry.get("price", 0))
		var button := UiKit.button("BUY %d" % price, 190, 72, "gold")
		button.disabled = int(SaveGame.data.get("coins", 0)) < price
		button.pressed.connect(func() -> void: _trade(id, 1))
		row.add_child(button)
		return row


	## A material in the bag: what the stall pays for it.
	func _sell_row(entry: Dictionary) -> Control:
		var id := str(entry.get("id", ""))
		var count := int(entry.get("count", 0))
		var price := int(entry.get("price", 0))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(UiKit.label(MaterialDB.name_of(id), 24, UiKit.CREAM, "x", 3))
		col.add_child(UiKit.label("%d in the bag \u00b7 %d each" % [count, price], 16, UiKit.MUTED, "b", 0))
		row.add_child(col)
		var button := UiKit.button("SELL", 170, 72, "gold")
		button.pressed.connect(func() -> void: _trade(id, 1))
		row.add_child(button)
		return row


	## What the stall pays for a material: the premium rate at the material
	## buyer, the base rate at the general store.
	func _sell_price(shop: String, id: String) -> int:
		if shop == "material_buyer":
			return ShopDB.material_buyer_price(id)
		return ShopDB.general_buy_price(id)


	## A trade at the stall: the hub runs it and hands back the sheet with
	## the result of the trade in it.
	func _trade(item_id: String, amount: int) -> void:
		var info := hub.open_shop(_stall, item_id, amount)
		if bool(info.get("ok", false)):
			AudioDirector.sfx("card_pick")
			var coins := int(info.get("coins", 0))
			_stall_result.text = "Traded." if coins <= 0 else "Traded \u00b7 %d coins." % coins
		else:
			_stall_result.text = str(info.get("reason", ""))
		_refresh_stall()

