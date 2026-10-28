extends Node
## App shell: switches between the camp (lobby) and a hunt with a fade.
## Also hosts two command-line modes used for checks:
##   -- --bot [--hero=knight] [--tier=0] [--zone=barrow|depths] [--runs=1] [--idle] [--old-foes] [--sidekick=drake[:kills]]   headless autopilot hunts
##   -- --capture --shots=lobby,hunt,... --out=/abs/dir         screenshots
##   -- --check                                                 compile every script and scene

const LOBBY := preload("res://src/lobby/lobby.tscn")
const Online := preload("res://src/net/online.gd")
const UiJuice := preload("res://src/ui/ui_juice.gd")
const IRIS := preload("res://src/fx/ui_iris.gdshader")
const FxUi := preload("res://src/ui/fx_ui.gd")
const AppGate := preload("res://src/core/app_gate.gd")
const STORY_DB := preload("res://src/data/story_db.gd")
const CUTSCENE := preload("res://src/ui/cutscene.gd")
const Privacy := preload("res://src/core/privacy.gd")
const CrashReport := preload("res://src/core/crash_report.gd")

var current: Node
var _gate: Node
var _fade: ColorRect
var _emblem: TextureRect
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
	_fade.material = ShaderMaterial.new()
	_fade.material.shader = IRIS
	layer.add_child(_fade)
	_iris(1.0, 0.0)
	add_child(UiJuice.new())
	var args := OS.get_cmdline_user_args()
	# The zones field their rebuilt factions (Rimehollow, Cinder Mire); --old-foes brings back the old ones.
	if args.has("--old-foes"):
		preload("res://src/hunt/foe_brains.gd").next = false
	if args.has("--notch"):
		Ui.forced_inset = Vector4(0, 108, 0, 62)
	if args.has("--check"):
		_check.call_deferred()
	elif args.has("--test"):
		_test.call_deferred()
	elif args.has("--bot"):
		_dev.call_deferred("_run_bot", args)
	elif args.has("--nettest"):
		_nettest.call_deferred()
	elif args.has("--capture"):
		# Captures of the social screens sign in to a local test server.
		if not _arg(args, "server", "").is_empty():
			_start_online()
		_dev.call_deferred("_capture", args)
	else:
		# The launch update check holds the camp behind the splash; a connect,
		# not an await, so an in-process update restart can free this node.
		_gate = AppGate.new()
		add_child(_gate)
		_gate.cleared.connect(_gate_cleared)
		var ota := get_node_or_null("/root/Ota")
		if ota and ota.get("checking") == true and ota.has_signal("boot_done"):
			ota.connect("boot_done", _launch, CONNECT_ONE_SHOT)
		else:
			_launch()


## The forced-update gate asks once at launch; a blocked player stays on its
## screen until it clears (see src/core/app_gate.gd).
func _launch() -> void:
	if await _gate.check():
		return
	_enter()


func _gate_cleared() -> void:
	if current == null and not _busy:
		_enter()


## Into the camp: after the privacy screen (first launch or a new policy),
## and only then the online account and the optional crash report.
func _enter() -> void:
	await Privacy.ask(self)
	if Online.inst == null and Privacy.online_ok():
		_start_online()
	var ota := get_node_or_null("/root/Ota")
	var build := int(ota.get("build")) if ota else 0
	var release := "gravelight@%s+%d" % [ProjectSettings.get_setting("application/config/version"), build]
	var cr := CrashReport.new()
	add_child(cr)
	cr.send_if_due(Game.errors, release, build)
	go("lobby")


func _start_online() -> void:
	var o := Online.start(self)
	o.party.start.connect(_on_party_start)


## The party leader started a hunt: follow, if in camp.
func _on_party_start(plan: Dictionary) -> void:
	if _busy or current == null or current is Hunt:
		Online.inst.party.in_hunt = false
		return
	Game.set_mode("horde")
	Game.set_zone(str(plan.get("zone", "barrow")))
	Game.set_tier(int(plan.get("tier", 0)))
	gold_seen = Game.gold()
	go("hunt")


## Closes (to 1.0) or opens (to 0.0) the screen-change curtain around `at`
## (0..1 of the screen). A zero duration just sets it. The emblem shows while
## the curtain is shut.
func _iris(to: float, dur: float, at := Vector2(0.5, 0.5)) -> void:
	var m := _fade.material as ShaderMaterial
	m.set_shader_parameter("view_size", get_viewport().get_visible_rect().size)
	m.set_shader_parameter("center", at)
	if _emblem == null:
		_emblem = Ui.icon_rect("crossed-swords", 150, Color(1.0, 0.8, 0.4, 0.0))
		_emblem.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		_emblem.pivot_offset = Vector2(75, 75)
		_emblem.offset_left = -75.0
		_emblem.offset_right = 75.0
		_emblem.offset_top = -75.0
		_emblem.offset_bottom = 75.0
		_fade.add_child(_emblem)
	var cur = m.get_shader_parameter("closed")
	var from := float(cur) if cur != null else 0.0
	if dur <= 0.0:
		m.set_shader_parameter("closed", to)
		_emblem.modulate.a = to
		return
	Sfx.play("dash", -11.0, 0.7 if to > from else 1.1)
	var t := create_tween().set_ignore_time_scale(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_method(func(v: float) -> void:
		m.set_shader_parameter("closed", v)
		_emblem.modulate.a = clampf((v - 0.7) / 0.3, 0.0, 1.0)
		_emblem.scale = Vector2.ONE * (0.7 + 0.3 * clampf((v - 0.5) * 2.0, 0.0, 1.0)), from, to, dur)
	await t.finished


func go(screen: String) -> void:
	if _busy:
		return
	_busy = true
	if current:
		await _iris(1.0, 0.4, FxUi.recent_tap_uv(1200))
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
	_busy = false
	await _iris(0.0, 0.55, Vector2(0.5, 0.46))


func _on_hunt_finished(result: Dictionary) -> void:
	if Online.inst:
		Online.inst.after_hunt(result)
	if result.get("win", false) or (str(result.get("mode", "")) in ["descent", "wild"] and str(result.get("chest", "")) != ""):
		var c := str(result.get("chest", ""))
		if c != "":
			if pending_chest == "":
				pending_chest = c
			else:
				chest_queue.append(c)
	var again: bool = result.get("again", false)
	var sc: Dictionary = result.get("summary", {}).get("story", {})
	await go("hunt" if again else "lobby")
	# A chapter's first clear closes with its ending, over the camp.
	if not again and bool(sc.get("first", false)):
		_play_story(STORY_DB.chapter(str(sc["id"])), "outro", str(result["hero"]))


## Plays a chapter's "intro" or "outro" scene over whatever is showing.
func _play_story(ch: Dictionary, which: String, hero_id: String, title := true) -> Control:
	var layer := CanvasLayer.new()
	layer.layer = 60
	add_child(layer)
	var cs: Control = CUTSCENE.new()
	layer.add_child(cs)
	cs.finished.connect(layer.queue_free)
	cs.play(ch, which, hero_id, title)
	return cs


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


func _nettest() -> void:
	var t: Node = load("res://src/net/net_test.gd").new()
	add_child(t)
	var fails: int = await t.run(self)
	get_tree().quit(0 if fails == 0 else 1)


func _walk(dir: String) -> PackedStringArray:
	var out := PackedStringArray()
	for f in ResourceLoader.list_directory(dir):
		if f.ends_with("/"):
			out.append_array(_walk(dir.path_join(f.trim_suffix("/"))))
		else:
			out.append(dir.path_join(f))
	return out


func _arg(args: PackedStringArray, key: String, def: String) -> String:
	for a in args:
		if a.begins_with("--%s=" % key):
			return a.substr(key.length() + 3)
	return def


## Dev modes (--bot, --capture) live in src/dev/capture.gd, which the export leaves out.
func _dev(method: String, args: PackedStringArray) -> void:
	var c: Node = load("res://src/dev/capture.gd").new()
	c.main = self
	add_child(c)
	c.call(method, args)
