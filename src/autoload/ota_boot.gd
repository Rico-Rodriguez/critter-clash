extends Node

## Over-the-air content bootstrap. This is the FIRST autoload, so its _init
## runs before any other game script or scene is loaded. It mounts the last
## good content pack (a full .pck exported by CI) over the baked IPA content,
## then checks GitHub for a newer pack behind a boot screen (the launch splash
## plus a status line); main.gd waits for `boot_done` before opening the camp.
## When a newer pack exists it is downloaded with a progress bar, mounted, and
## the game is restarted in-process on it (iOS apps cannot relaunch
## themselves): the scene is freed, every loaded script and resource is
## reloaded from the new pack, and the autoloads and main scene are rebuilt.
## Only if the check, download or verification fails does boot continue on the
## current content while a background retry stages a pack for the next launch.
##
## Rules for this file (it is compiled from the baked IPA before any pack is
## mounted, and a pack can never replace the running copy):
## - Never reference another game script, class_name or autoload.
## - Keep it small. Game code reads it only through get_node_or_null("/root/Ota")
##   and the fields below; bump BOOT_VERSION if those ever change.
## - Calls into the game are by name only: an autoload may define
##   _ota_unload() to let go of engine-held objects (loggers) before a reload.
## - Never touch anything outside user://ota/ (saves live in user:// root).

signal update_ready(build: int)
## The launch check is over and the game may open its first screen.
signal boot_done

const BOOT_VERSION := 3
## Native shell version baked into the IPA. Bump it whenever a change needs a
## new IPA (engine version, export preset, plugins, project settings such as
## autoloads or input map). CI stamps it into version.json as min_engine, so
## an older IPA refuses packs that need a newer shell.
const NATIVE_VERSION := 4
const DEFAULT_URL := "https://github.com/Rico-Rodriguez/critter-clash/releases/download/ota/version.json"
const DIR := "user://ota"
const MANIFEST := "user://ota/manifest.json"
const FLAG := "user://ota/booting.flag"
const CHECK_TIMEOUT := 3.0
const DOWNLOAD_TIMEOUT := 1800.0
## Seconds the game must run before a freshly mounted pack counts as good.
const SETTLE := 4.0
## Same image as the iOS launch screen and Godot's boot splash, so boot is one
## continuous picture.
const SPLASH := "res://assets/splash.png"
const FONT := "res://assets/fonts/AlegreyaSans-Medium.ttf"
const INK := Color(0.96, 0.88, 0.72)
const DIM := Color(0.62, 0.68, 0.74)
const EMBER := Color(1.0, 0.62, 0.25)

var enabled := false
var baked_build := 0
var baked_sha := ""
## Build of the mounted pack; 0 means the baked IPA content is running.
var ota_build := 0
## Build players see: the pack if one is mounted, else the baked build.
var build := 0
## True on the first launch that runs a newly applied pack ("Updated to build N").
var just_updated := false
## A pack that crashed during its last boot and was discarded this launch.
var rolled_back := 0
## A pack staged this session by the background fallback; applies next launch.
var pending_build := 0
## True while the boot-blocking Updating screen is up (the tree is paused).
var blocking := false
## True until the launch check is over; main.gd holds the camp until boot_done.
var checking := false
var status := "off"

var _m := {}
var _url := DEFAULT_URL
var _remote := {}
var _http: HTTPRequest
var _hasher: Thread
var _ui: CanvasLayer
var _bar: ProgressBar
var _step: Label
var _note: Label
var _downloading := false
var _shown_at := 0


func _init() -> void:
	baked_build = int(ProjectSettings.get_setting("ota/build", 0))
	baked_sha = str(ProjectSettings.get_setting("ota/sha", ""))
	build = baked_build
	var test := OS.get_environment("CC_OTA_TEST") == "1"
	enabled = (OS.has_feature("template") and OS.get_name() == "iOS") or test
	if OS.get_cmdline_user_args().has("--no-ota"):
		enabled = false
	if OS.get_environment("CC_OTA_URL") != "":
		_url = OS.get_environment("CC_OTA_URL")
	if not enabled:
		return
	DirAccess.make_dir_recursive_absolute(DIR)
	_m = _read_json(MANIFEST)
	for key in ["current", "previous"]:
		if not (_m.get(key) is Dictionary):
			_m[key] = {}
	if not (_m.get("bad") is Array):
		_m["bad"] = []
	# JSON numbers load as floats; keep build ids as ints so `in` matches.
	_m["bad"] = _m["bad"].map(func(x: Variant) -> int: return int(x))
	# The last boot never reached SETTLE seconds with a pack mounted: treat
	# that pack as bad and fall back to the previous good one (or baked).
	if FileAccess.file_exists(FLAG):
		var crashed := int(_read_text(FLAG).strip_edges())
		DirAccess.remove_absolute(FLAG)
		if crashed > 0 and int(_m["current"].get("build", 0)) == crashed:
			rolled_back = crashed
			_discard("current")
			_m["current"] = _m["previous"]
			_m["previous"] = {}
	# A newer IPA (or one built for another shell) wins over stale packs.
	for key in ["previous", "current"]:
		if not _usable(_m[key]):
			_discard(key)
	if _m["current"].is_empty() and not _m["previous"].is_empty():
		_m["current"] = _m["previous"]
		_m["previous"] = {}
	_mount()
	_save_manifest()


func _mount() -> void:
	for attempt in 2:
		var entry: Dictionary = _m["current"]
		if entry.is_empty():
			return
		var path := DIR + "/" + str(entry.get("file", ""))
		var ok := FileAccess.file_exists(path) and _file_size(path) == int(entry.get("size", -1))
		if ok:
			_write_text(FLAG, str(entry["build"]))
			ok = ProjectSettings.load_resource_pack(path, true)
		if ok:
			ota_build = int(entry["build"])
			build = ota_build
			if int(_m.get("last_shown", 0)) != ota_build:
				just_updated = true
				_m["last_shown"] = ota_build
			status = "mounted"
			return
		DirAccess.remove_absolute(FLAG)
		_discard("current")
		_m["current"] = _m["previous"]
		_m["previous"] = {}


func _ready() -> void:
	if not enabled:
		return
	# The Updating screen and the downloads must run while the tree is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_http = HTTPRequest.new()
	_http.use_threads = true
	add_child(_http)
	checking = true
	_open_ui()
	var reloaded: bool = await _boot_update()
	checking = false
	if not reloaded:
		boot_done.emit()
	elif not status.begins_with("updated"):
		return
	# Wait for the first screen to be built before uncovering it.
	for i in 3:
		await get_tree().process_frame
	_close_ui()
	if ota_build > 0:
		get_tree().create_timer(SETTLE).timeout.connect(_settled)


func _notification(what: int) -> void:
	# Leaving on purpose before SETTLE is not a crash.
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		if ota_build > 0:
			_settled()


func _settled() -> void:
	if FileAccess.file_exists(FLAG):
		DirAccess.remove_absolute(FLAG)


func _process(_delta: float) -> void:
	if _step == null:
		return
	if checking and not blocking:
		# A quick check stays a plain splash; a slow one says what it waits on.
		_step.text = "Checking for updates" if Time.get_ticks_msec() - _shown_at > 700 else ""
		return
	if _downloading and _bar:
		var got := float(_http.get_downloaded_bytes())
		_bar.value = minf(got, _bar.max_value)
		_step.text = "Downloading update  %s / %s" % [_mb(got), _mb(_bar.max_value)]
	elif status == "verifying":
		_bar.value = _bar.max_value
		_step.text = "Checking the download"


## Checks GitHub and applies a newer pack before the game becomes usable.
## True when the game was restarted on the new pack (it then opens its own
## first screen, so boot_done is not sent).
func _boot_update() -> bool:
	if not enabled or _http == null:
		return false
	if not await _check():
		return false
	# A newer pack exists: block boot until it is applied.
	var target := int(_remote["build"])
	blocking = true
	get_tree().paused = true
	status = "applying %d" % target
	_show_progress(target)
	var failure: String = await _fetch_pack()
	if failure != "":
		get_tree().paused = false
		blocking = false
		status = failure
		_restage()
		return false
	_mount()
	_save_manifest()
	_bar.value = _bar.max_value
	_step.text = "Applying update"
	var err: String = await _restart_game()
	blocking = false
	if err != "":
		_failed(err)
		return true
	status = "updated %d" % ota_build
	return true


## Requests version.json and accepts it; false when there is nothing to apply.
func _check() -> bool:
	_http.timeout = CHECK_TIMEOUT
	_http.download_file = ""
	status = "checking"
	if _http.request(_url) != OK:
		status = "offline"
		return false
	var res: Array = await _http.request_completed
	if int(res[0]) != HTTPRequest.RESULT_SUCCESS or int(res[1]) != 200:
		status = "offline"
		return false
	var v: Variant = JSON.parse_string((res[3] as PackedByteArray).get_string_from_utf8())
	if not (v is Dictionary):
		status = "bad version.json"
		return false
	_remote = v
	var why := accepts(_remote)
	if why != "":
		status = why
		return false
	return true


## "" when the remote pack should be downloaded, else the reason it is skipped.
func accepts(r: Dictionary) -> String:
	for key in ["build", "pck_url", "sha256", "size", "min_engine"]:
		if not r.has(key):
			return "missing " + key
	var b := int(r["build"])
	if b <= baked_build or b <= ota_build or b <= int(_m["current"].get("build", 0)):
		return "up to date"
	if b in _m["bad"]:
		return "build %d was rolled back" % b
	if int(r["min_engine"]) > NATIVE_VERSION:
		return "needs a newer app (shell %d)" % int(r["min_engine"])
	if r.has("godot") and str(r["godot"]) != _engine():
		return "built for Godot " + str(r["godot"])
	if r.has("platform") and str(r["platform"]) != OS.get_name().to_lower() and OS.get_environment("CC_OTA_TEST") != "1":
		return "built for " + str(r["platform"])
	return ""


## Downloads, verifies and installs _remote's pack into the manifest.
## "" when usable, else a short failure reason.
func _fetch_pack() -> String:
	var tmp := DIR + "/download.tmp"
	_http.timeout = DOWNLOAD_TIMEOUT
	_http.download_file = tmp
	_downloading = true
	if _http.request(str(_remote["pck_url"])) != OK:
		_downloading = false
		_http.download_file = ""
		status = "download failed"
		return status
	var res: Array = await _http.request_completed
	_downloading = false
	_http.download_file = ""
	if int(res[0]) != HTTPRequest.RESULT_SUCCESS or int(res[1]) != 200 or _file_size(tmp) != int(_remote["size"]):
		DirAccess.remove_absolute(tmp)
		status = "download failed"
		return status
	status = "verifying"
	# Hash off the main thread: a full pack is hundreds of MB.
	_hasher = Thread.new()
	_hasher.start(_sha256.bind(tmp))
	while _hasher.is_alive():
		await get_tree().process_frame
	var digest: String = _hasher.wait_to_finish()
	if digest == "" or digest != str(_remote["sha256"]).to_lower():
		DirAccess.remove_absolute(tmp)
		status = "sha256 mismatch"
		return status
	var b := int(_remote["build"])
	var file := "content_%d.pck" % b
	if DirAccess.rename_absolute(tmp, DIR + "/" + file) != OK:
		DirAccess.remove_absolute(tmp)
		status = "rename failed"
		return status
	# Keep the running pack as the fallback; drop the older one.
	var running: Dictionary = _m["current"]
	if not _m["previous"].is_empty() and str(_m["previous"].get("file")) != str(running.get("file")):
		_discard("previous")
	_m["previous"] = running
	_m["current"] = {"build": b, "file": file, "size": int(_remote["size"]), "sha256": digest,
		"min_engine": int(_remote["min_engine"]), "godot": str(_remote.get("godot", _engine())),
		"sha": str(_remote.get("sha", ""))}
	_save_manifest()
	return ""


## The blocking attempt failed: keep the current pack usable and retry in the
## background, staging the pack for the next launch (the old flow).
func _restage() -> void:
	if not await _check():
		return
	if await _fetch_pack() != "":
		return
	pending_build = int(_remote["build"])
	status = "ready %d" % pending_build
	update_ready.emit(pending_build)


## The boot screen: the launch splash, then a status line and a progress bar
## under it while an update downloads. Raw nodes only (no theme or game
## script), since this runs from the IPA under any content pack.
func _open_ui() -> void:
	_shown_at = Time.get_ticks_msec()
	_ui = CanvasLayer.new()
	_ui.layer = 100
	add_child(_ui)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	_ui.add_child(root)
	var shade := ColorRect.new()
	shade.color = ProjectSettings.get_setting("application/boot_splash/bg_color", Color.BLACK)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(shade)
	if ResourceLoader.exists(SPLASH):
		var art := TextureRect.new()
		art.texture = load(SPLASH)
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		# Cover, like the launch screen, so the picture does not jump.
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(art)
	var font: Font = load(FONT) if ResourceLoader.exists(FONT) else null
	var box := VBoxContainer.new()
	box.anchor_left = 0.14
	box.anchor_right = 0.86
	box.anchor_top = 0.865
	box.anchor_bottom = 0.865
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 12)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(box)
	_step = _text(font, 26, INK)
	box.add_child(_step)
	_bar = ProgressBar.new()
	_bar.custom_minimum_size = Vector2(0, 10)
	_bar.show_percentage = false
	_bar.add_theme_stylebox_override("background", _round(Color(0, 0, 0, 0.55), Color(1, 1, 1, 0.12)))
	_bar.add_theme_stylebox_override("fill", _round(EMBER, EMBER.lightened(0.3)))
	_bar.visible = false
	box.add_child(_bar)
	_note = _text(font, 20, DIM)
	box.add_child(_note)


func _show_progress(target: int) -> void:
	if _ui == null:
		_open_ui()
	_bar.max_value = maxf(float(int(_remote.get("size", 1))), 1.0)
	_bar.value = 0.0
	_bar.visible = true
	_step.text = "Downloading update"
	_note.text = "Build %d to %d. Keep Gravelight open." % [build, target]


## The reload failed: the running scripts are torn down, so the only way on
## is a fresh launch (which picks the last good pack).
func _failed(err: String) -> void:
	status = err
	# Not the pack's fault as far as we know: a cold launch mounts it before
	# any script loads, so let it boot normally rather than roll it back.
	_settled()
	if _ui == null:
		_open_ui()
	_bar.visible = false
	_step.text = "Update needs a restart"
	_note.text = "Close Gravelight and open it again."


func _text(font: Font, size: int, color: Color) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if font:
		l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("shadow_offset_y", 2)
	return l


static func _round(fill: Color, edge: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = edge
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(5)
	return sb


static func _mb(bytes: float) -> String:
	return "%.1f MB" % (bytes / 1048576.0)


## Fades the boot screen out over the first screen.
func _close_ui() -> void:
	_downloading = false
	var ui := _ui
	_ui = null
	_bar = null
	_step = null
	_note = null
	blocking = false
	if ui == null:
		return
	var root: CanvasItem = ui.get_child(0)
	var t := create_tween()
	t.tween_property(root, "modulate:a", 0.0, 0.35)
	t.tween_callback(ui.queue_free)


# --- In-process restart --------------------------------------------------------

## Restarts the game on the freshly mounted pack without leaving the app:
## frees the scene, takes the scripts off every autoload, reloads every
## cached script and resource from the pack, then rebuilds the autoloads and
## the main scene. "" on success, else what went wrong.
func _restart_game() -> String:
	var tree := get_tree()
	var root := tree.root
	var autoloads: Array[Node] = []
	var scripts: Array[String] = []
	for p in ProjectSettings.get_property_list():
		var key := str(p["name"])
		if not key.begins_with("autoload/"):
			continue
		var n := root.get_node_or_null(key.trim_prefix("autoload/"))
		if n == null or n == self:
			continue
		var path := str(ProjectSettings.get_setting(key)).trim_prefix("*")
		if not path.ends_with(".gd"):
			return "autoload %s is a scene" % n.name
		autoloads.append(n)
		scripts.append(path)
	# Everything that is not an autoload is the running game.
	for c in root.get_children():
		if c != self and not (c in autoloads):
			c.queue_free()
	await tree.process_frame
	await tree.process_frame
	var spots: Array[int] = []
	for n in autoloads:
		if n.has_method("_ota_unload"):
			n.call("_ota_unload")
		spots.append(n.get_index())
		root.remove_child(n)
		for c in n.get_children():
			c.free()
		n.set_script(null)
	await tree.process_frame
	var bad: String = await _reload_all()
	if bad != "":
		return bad
	# Scripts first, then the tree: each autoload's _ready can see the others,
	# as at launch. The global names still point at these same nodes.
	for i in autoloads.size():
		var s: Script = load(scripts[i])
		if s == null or not s.can_instantiate():
			return "cannot start " + scripts[i]
		autoloads[i].set_script(s)
	for i in autoloads.size():
		autoloads[i].request_ready()
		root.add_child(autoloads[i])
		root.move_child(autoloads[i], mini(spots[i], root.get_child_count() - 1))
	tree.paused = false
	Engine.time_scale = 1.0
	if tree.change_scene_to_file(str(ProjectSettings.get_setting("application/run/main_scene"))) != OK:
		return "cannot open the main scene"
	return ""


## Reloads every cached script (twice: the first pass refreshes what each one
## depends on, the second compiles against it, bases before subclasses), then
## refreshes every other cached resource in place. "" or the first broken script.
func _reload_all() -> String:
	var mine := (get_script() as Script).resource_path
	var gds: Array[String] = []
	var res: Array[String] = []
	for path in _files("res://"):
		if path == mine or not ResourceLoader.has_cached(path):
			continue
		if path.ends_with(".gd"):
			gds.append(path)
		elif not path.ends_with(".uid"):
			res.append(path)
	var bad := ""
	for pass_ in 2:
		if pass_ == 1:
			gds.sort_custom(func(a: String, b: String) -> bool: return _depth(a) < _depth(b))
		bad = ""
		for i in gds.size():
			var s := ResourceLoader.load(gds[i], "", ResourceLoader.CACHE_MODE_IGNORE) as Script
			if (s == null or not s.can_instantiate()) and bad == "":
				bad = "broken script " + gds[i].get_file()
			if i % 24 == 23:
				await get_tree().process_frame
	if bad != "":
		return bad
	for i in res.size():
		if ResourceLoader.has_cached(res[i]):
			ResourceLoader.load(res[i], "", ResourceLoader.CACHE_MODE_REPLACE)
		if i % 24 == 23:
			await get_tree().process_frame
	return ""


static func _depth(path: String) -> int:
	var d := 0
	var s: Script = ResourceLoader.get_cached_ref(path) as Script
	while s != null and d < 32:
		s = s.get_base_script()
		d += 1
	return d


static func _files(dir: String) -> PackedStringArray:
	var out := PackedStringArray()
	for f in ResourceLoader.list_directory(dir):
		if f.ends_with("/"):
			if f.begins_with("."):
				continue
			out.append_array(_files(dir.path_join(f.trim_suffix("/"))))
		else:
			out.append(dir.path_join(f))
	return out


static func _sha256(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	while f.get_position() < f.get_length():
		ctx.update(f.get_buffer(1 << 20))
	return ctx.finish().hex_encode()


func _usable(entry: Dictionary) -> bool:
	if entry.is_empty():
		return true
	return int(entry.get("build", 0)) > baked_build \
		and int(entry.get("min_engine", 1 << 30)) <= NATIVE_VERSION \
		and str(entry.get("godot", _engine())) == _engine() \
		and not (int(entry.get("build", 0)) in _m["bad"])


func _discard(key: String) -> void:
	var entry: Dictionary = _m[key]
	if entry.is_empty():
		return
	if rolled_back == int(entry.get("build", 0)) and not (rolled_back in _m["bad"]):
		_m["bad"].append(rolled_back)
	var file := str(entry.get("file", ""))
	if file != "" and file.get_file() == file:
		DirAccess.remove_absolute(DIR + "/" + file)
	_m[key] = {}


func _save_manifest() -> void:
	var tmp := MANIFEST + ".tmp"
	_write_text(tmp, JSON.stringify(_m, "\t"))
	DirAccess.rename_absolute(tmp, MANIFEST)


static func _engine() -> String:
	var v := Engine.get_version_info()
	return "%d.%d.%d" % [v["major"], v["minor"], v["patch"]]


static func _file_size(path: String) -> int:
	var f := FileAccess.open(path, FileAccess.READ)
	return -1 if f == null else int(f.get_length())


static func _read_text(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	return "" if f == null else f.get_as_text()


static func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var v: Variant = JSON.parse_string(_read_text(path))
	return v if v is Dictionary else {}


static func _write_text(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(text)
		f.flush()
