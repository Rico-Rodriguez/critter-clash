extends Node

const SCREENS := {
	"home": preload("res://scripts/home_screen.gd"),
	"world": preload("res://scripts/world_screen.gd"),
	"heroes": preload("res://scripts/hero_screen.gd"),
	"loadout": preload("res://scripts/loadout_screen.gd"),
	"collection": preload("res://scripts/collection_screen.gd"),
	"trophy": preload("res://scripts/trophy_screen.gd"),
	"chest": preload("res://scripts/chest_screen.gd"),
	"log": preload("res://scripts/log_screen.gd"),
	"slayer": preload("res://scripts/slayer_screen.gd"),
	"skills": preload("res://scripts/skills_screen.gd"),
	"credits": preload("res://scripts/credits_screen.gd"),
	"run": preload("res://scripts/run_screen.gd"),
}

var current: Node


func _ready() -> void:
	# 0 means "vsync to the display". On ProMotion iPhones the iOS export
	# asks for 120Hz via display/window/ios/allow_high_refresh_rate.
	Engine.max_fps = 0
	Input.use_accumulated_input = false
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
	SaveGame.data["chests"].append({"kind": "hunt", "biome": "meadow", "seed": 3})
	SaveGame.data["chests"].append({"kind": "scrap", "biome": "meadow", "seed": 4})
	if _wants("home"):
		go("home")
		await _settle()
		await _shot("home")
	if _wants("map"):
		go("world")
		await _settle()
		await _shot("map")
	if _wants("heroes"):
		go("heroes", {"biome": "meadow"})
		await _settle()
		await _shot("heroes")
	SaveGame.data["heroes"]["ember"]["cards"] = 8
	if _wants("collection"):
		go("collection")
		await _settle()
		await _shot("collection")
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
	if _wants("skills"):
		go("skills")
		await _settle()
		await _shot("skills")
	if _wants("trophy"):
		go("trophy")
		await _settle()
		await _shot("trophy")
	if _wants("loadout"):
		go("loadout", {"hero": "ember", "biome": "meadow"})
		await _settle()
		await _shot("loadout")
	if _wants("hunt") or _wants("boss") or _wants("levelup") or _wants("rare"):
		go("run", {"biome": "meadow", "hero": "ember"})
		await _settle()
		current.drive = Vector2(0.35, 0.15).normalized()
		# Sim time, not wall time: software rendering runs the hunt slowly.
		# Wait for a pack to close in so the shot shows a real wave.
		var start := Time.get_ticks_msec()
		while Time.get_ticks_msec() - start < 120000 and (current.sim.time < 1.2 or _near_minions(current.sim) < 8):
			await get_tree().process_frame
			if current.sim.time > 1.0:
				current.drive = Vector2.ZERO
		var waited := 0.0
		if OS.get_cmdline_user_args().has("--debug-wave"):
			var hero: Vector2 = current.sim.heroes[0].pos
			for actor in current.sim.actors:
				if actor.kind == "minion" and actor.alive:
					var body = current.stage._bodies.get(actor.id)
					print("WAVE rel=", actor.pos - hero, " scr=", current.stage.project(actor.pos), " body=", body != null and body.visible, " sprite=", actor.sprite, " gpos=", body.global_position if body else null)
			print("WAVE cam=", current.stage.camera.global_position, " hero3=", current.stage._to3(hero))
		await _shot("hunt")
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
		SaveGame.debug_rare = true
		current.sim.debug_slay_boss()
		await _settle()
		await _shot("rare")
	if _wants("chest"):
		go("chest")
		await _settle()
		await _shot("chest")
		current._reveal()
		await _settle()
		await _shot("loot")
	get_tree().quit()


func _wants(name: String) -> bool:
	return _want.is_empty() or name in _want


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
