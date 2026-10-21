extends Node

## Over-the-air content bootstrap. This is the FIRST autoload, so its _init
## runs before any other game script or scene is loaded. It mounts the last
## good content pack (a full .pck exported by CI) over the baked IPA content,
## then checks GitHub for a newer pack. When one exists it is downloaded and
## mounted on this launch behind a blocking Updating screen: the tree stays
## paused until the pack is verified and applied, so the game is not usable
## before that. Only if the check, download or verification fails does boot
## continue on the current content while a background retry stages a pack for
## the next launch.
##
## Rules for this file (it is compiled from the baked IPA before any pack is
## mounted, and a pack can never replace the running copy):
## - Never reference another game script, class_name or autoload.
## - Keep it small. Game code reads it only through get_node_or_null("/root/Ota")
##   and the fields below; bump BOOT_VERSION if those ever change.
## - Never touch anything outside user://ota/ (saves live in user:// root).

signal update_ready(build: int)

const BOOT_VERSION := 2
## Native shell version baked into the IPA. Bump it whenever a change needs a
## new IPA (engine version, export preset, plugins, project settings such as
## autoloads or input map). CI stamps it into version.json as min_engine, so
## an older IPA refuses packs that need a newer shell.
const NATIVE_VERSION := 2
const DEFAULT_URL := "https://github.com/Rico-Rodriguez/critter-clash/releases/download/ota/version.json"
const DIR := "user://ota"
const MANIFEST := "user://ota/manifest.json"
const FLAG := "user://ota/booting.flag"
const CHECK_TIMEOUT := 3.0
const DOWNLOAD_TIMEOUT := 1800.0
## Seconds the game must run before a freshly mounted pack counts as good.
const SETTLE := 4.0

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
var status := "off"

var _m := {}
var _url := DEFAULT_URL
var _remote := {}
var _http: HTTPRequest
var _hasher: Thread
var _ui: CanvasLayer
var _bar: ProgressBar
var _step: Label
var _downloading := false


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
	await _boot_update()
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
	if _step:
		_step.text = status
	if _downloading and _bar:
		_bar.value = minf(float(_http.get_downloaded_bytes()), _bar.max_value)


## Checks GitHub and applies a newer pack before the game becomes usable.
func _boot_update() -> void:
	if not enabled or _http == null:
		return
	if not await _check():
		return
	# A newer pack exists: block boot until it is applied.
	var target := int(_remote["build"])
	_open_ui(target)
	get_tree().paused = true
	status = "applying %d" % target
	var failure: String = await _fetch_pack()
	get_tree().paused = false
	_close_ui()
	if failure != "":
		status = failure
		_restage()
		return
	_mount()
	_save_manifest()


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


## A full-screen Updating card built from raw nodes; the pause stops the game.
func _open_ui(target: int) -> void:
	blocking = true
	_ui = CanvasLayer.new()
	_ui.layer = 100
	add_child(_ui)
	var shade := ColorRect.new()
	shade.color = Color(0.03, 0.03, 0.04, 1.0)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	_ui.add_child(shade)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 14)
	shade.add_child(box)
	var head := Label.new()
	head.text = "Updating"
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(head)
	var info := Label.new()
	info.text = "Build %d to %d" % [build, target]
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(info)
	_bar = ProgressBar.new()
	_bar.max_value = maxf(float(int(_remote.get("size", 1))), 1.0)
	box.add_child(_bar)
	_step = Label.new()
	_step.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_step)


func _close_ui() -> void:
	_downloading = false
	if _ui:
		_ui.queue_free()
		_ui = null
	_bar = null
	_step = null
	blocking = false


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
