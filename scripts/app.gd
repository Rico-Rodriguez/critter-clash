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
	if OS.get_cmdline_user_args().has("--capture"):
		_capture()
		return
	go("home")


func go(screen: String, args: Dictionary = {}) -> void:
	call_deferred("_swap", screen, args)


func _swap(screen: String, args: Dictionary) -> void:
	if current:
		current.queue_free()
		current = null
	current = SCREENS[screen].new()
	add_child(current)
	if current.has_signal("travel"):
		current.travel.connect(go)
	if current.has_method("open"):
		current.open(args)


func _capture() -> void:
	DirAccess.make_dir_recursive_absolute("/opt/cursor/artifacts/screenshots")
	DirAccess.make_dir_recursive_absolute("/workspace/captures")
	SaveGame.reset_new()
	go("home")
	await _settle()
	await _shot("home")
	go("world")
	await _settle()
	await _shot("world")
	go("heroes", {"biome": "meadow"})
	await _settle()
	await _shot("heroes")
	SaveGame.data["heroes"]["ember"]["cards"] = 8
	go("collection")
	await _settle()
	await _shot("collection")
	go("credits")
	await _settle()
	await _shot("credits")
	_seed_log()
	go("log")
	await _settle()
	await _shot("log")
	go("slayer")
	await _settle()
	await _shot("slayer")
	go("skills")
	await _settle()
	await _shot("skills")
	go("trophy")
	await _settle()
	await _shot("trophy")
	go("loadout", {"hero": "ember", "biome": "meadow"})
	await _settle()
	await _shot("loadout")
	go("run", {"biome": "meadow", "hero": "ember"})
	await _settle()
	current.drive = Vector2(0.35, 0.15).normalized()
	await get_tree().create_timer(2.6).timeout
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
	current.sim.begin_boss()
	await get_tree().create_timer(0.55).timeout
	await _shot("boss")
	SaveGame.debug_rare = true
	current.sim.debug_slay_boss()
	await _settle()
	await _shot("rare")
	go("chest")
	await _settle()
	await _shot("chest")
	current._reveal()
	await _settle()
	await _shot("loot")
	get_tree().quit()


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
	image.save_png("/opt/cursor/artifacts/screenshots/%s.png" % shot_name)
	image.save_png("/workspace/captures/%s.png" % shot_name)
