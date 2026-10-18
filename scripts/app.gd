extends Node

const SCREENS := {
	"home": preload("res://scripts/home_screen.gd"),
	"world": preload("res://scripts/world_screen.gd"),
	"heroes": preload("res://scripts/hero_screen.gd"),
	"trophy": preload("res://scripts/trophy_screen.gd"),
	"chest": preload("res://scripts/chest_screen.gd"),
	"log": preload("res://scripts/log_screen.gd"),
	"slayer": preload("res://scripts/slayer_screen.gd"),
	"skills": preload("res://scripts/skills_screen.gd"),
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
	go("home")


func go(screen: String, args: Dictionary = {}) -> void:
	call_deferred("_swap", screen, args)


func _swap(screen: String, args: Dictionary) -> void:
	if current:
		if current.has_method("leave") and screen != "run" and current.get_script() != SCREENS["run"]:
			current.leave(ScreenBase.slide_from)
		else:
			current.queue_free()
		current = null
	current = SCREENS[screen].new()
	add_child(current)
	if current.has_signal("travel"):
		current.travel.connect(go)
	if current.has_method("open"):
		current.open(args)


var _shot_dir := "/workspace/captures"
var _want: Array = []


func _capture() -> void:
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
		# Enough cards and coins that the Heroes UPGRADE reads as ready.
		SaveGame.hero(fh)["cards"] = maxi(int(SaveGame.hero(fh)["cards"]), SaveGame.cards_needed(int(SaveGame.hero(fh)["level"])) + 1)
		SaveGame.data["coins"] = maxi(int(SaveGame.data["coins"]), 240)
	if _wants("home"):
		go("home")
		await _settle()
		await _shot("home")
	if _wants("map"):
		go("home")
		await _settle()
		current.open_map_sheet()
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
	SaveGame.data["heroes"]["ember"]["cards"] = 8
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
		hero.iframes = 30.0
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
			hero_actor.iframes = 5.0
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
	SaveGame.data["skills"]["foraging"] = 200
	SaveGame.data["slayer"]["points"] = 55
	SaveGame.data["slayer"]["streak"] = 2
	var task := Catalog.slayer_task("meadow_critters").duplicate()
	task["have"] = 18
	SaveGame.data["slayer"]["task"] = task
	SaveGame.data["cosmetic"] = "ribbon"


func _settle() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(0.42).timeout


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
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
