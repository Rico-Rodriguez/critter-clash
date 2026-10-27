extends Node
## Forced native update, like Clash games. Over-the-air content packs keep
## working as before (ota_boot.gd); this only covers builds that need a new
## app. version.json (published next to the pack) may carry:
##   min_native: the lowest native shell (Ota.NATIVE_VERSION) allowed to play
##   store_url:  where the Update button goes (App Store, or the sideload page)
## The check runs on launch and when the app returns from the background.
## If the installed shell is below min_native a blocking "Update required"
## screen covers the game and the tree is paused. Offline, a slow or a broken
## answer lets the player in (fail open); the next launch or resume asks again.
## Lives in the content pack on purpose (no class_name, preloaded by path), so
## installed copies get the gate over the air.

## The gate was cleared (min_native dropped, or the shell caught up).
signal cleared

const URL := "https://github.com/Rico-Rodriguez/critter-clash/releases/download/ota/version.json"
const STORE_URL := "https://github.com/Rico-Rodriguez/critter-clash/releases/tag/ios-v1"
const TIMEOUT := 3.0
const SPLASH := "res://assets/splash.png"

var blocked := false
var have := 0
var need := 0
var store_url := STORE_URL
## Set once the launch check ran, so resuming before it never double-checks.
var started := false

var _http: HTTPRequest
var _checking := false
var _ui: CanvasLayer
var _paused_by_me := false


## The verdict for a version.json answer: {block, have, need, store_url}.
## `have` 0 (unknown shell) never blocks.
static func verdict(remote: Dictionary, have_: int) -> Dictionary:
	var need_ := int(remote.get("min_native", 0))
	var url := str(remote.get("store_url", ""))
	if not (url.begins_with("https://") or url.begins_with("itms-apps://")):
		url = STORE_URL
	return {"block": have_ > 0 and need_ > have_, "have": have_, "need": need_, "store_url": url}


## The parsed version.json, or {} when the request failed or the body is not
## a JSON object: the caller fails open.
static func parse(result: int, code: int, body: PackedByteArray) -> Dictionary:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		return {}
	var v: Variant = JSON.parse_string(body.get_string_from_utf8())
	return v if v is Dictionary else {}


## True for a real App Store page: apps.apple.com or itunes.apple.com (https),
## or an itms-apps:// link. A lookalike host or a link that only mentions
## apps.apple.com in its query is not one.
static func is_store_url(url: String) -> bool:
	for pre in ["https://apps.apple.com/", "https://itunes.apple.com/", "itms-apps://apps.apple.com/", "itms-apps://itunes.apple.com/"]:
		if url.begins_with(pre):
			return true
	return false


## "OPEN APP STORE" for an App Store link, else a plain "GET THE UPDATE": the
## sideload page stays the placeholder until the app is listed (docs/ota.md C).
static func button_text(url: String) -> String:
	return "OPEN APP STORE" if is_store_url(url) else "GET THE UPDATE"


## The installed native shell, from the Ota autoload's baked constant; 0 when
## it can't be read (then nothing is blocked).
func installed() -> int:
	var ota := get_node_or_null("/root/Ota")
	if ota == null:
		return 0
	var consts: Dictionary = (ota.get_script() as Script).get_script_constant_map()
	return int(consts.get("NATIVE_VERSION", 0))


## Asks the server; true when the game must stay closed.
func check() -> bool:
	started = true
	if OS.get_cmdline_user_args().has("--no-gate"):
		return false
	if _checking:
		return blocked
	_checking = true
	var url := OS.get_environment("CC_GATE_URL") if OS.get_environment("CC_GATE_URL") != "" else URL
	if _http == null:
		_http = HTTPRequest.new()
		_http.use_threads = true
		add_child(_http)
	_http.timeout = TIMEOUT
	var remote := {}
	if _http.request(url) == OK:
		var res: Array = await _http.request_completed
		remote = parse(int(res[0]), int(res[1]), res[3])
	_checking = false
	return apply(remote)


## Applies an answer ({} = no answer: fail open). True when blocked.
func apply(remote: Dictionary) -> bool:
	if remote.is_empty():
		# Offline or unreadable: let the player in, ask again next time. A gate
		# already up stays up (the last answer was real).
		return blocked
	var v := verdict(remote, installed())
	have = int(v["have"])
	need = int(v["need"])
	store_url = str(v["store_url"])
	if bool(v["block"]):
		show_required()
	elif blocked:
		hide_required()
	return blocked


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_RESUMED and started:
		check()


## The blocking screen.
func show_required() -> void:
	blocked = true
	if _ui != null:
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not get_tree().paused:
		get_tree().paused = true
		_paused_by_me = true
	_ui = CanvasLayer.new()
	_ui.layer = 150
	add_child(_ui)
	var root := Control.new()
	root.name = "UpdateRequired"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	_ui.add_child(root)
	var shade := ColorRect.new()
	shade.color = Color(0.03, 0.03, 0.05)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(shade)
	# The splash is not an imported texture (boot-splash only), so read the file.
	var img := Image.load_from_file(SPLASH) if FileAccess.file_exists(SPLASH) else null
	if img != null and not img.is_empty():
		var art := TextureRect.new()
		art.texture = ImageTexture.create_from_image(img)
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(art)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.04, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)
	var card := PanelContainer.new()
	card.anchor_left = 0.08
	card.anchor_right = 0.92
	card.anchor_top = 0.5
	card.anchor_bottom = 0.5
	card.grow_vertical = Control.GROW_DIRECTION_BOTH
	root.add_child(card)
	var pad := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 28)
	card.add_child(pad)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	pad.add_child(v)
	v.add_child(_label("UPDATE REQUIRED", "Title"))
	var body := _label("A new version of Gravelight is out and this one can no longer connect. Update to keep hunting; your progress is safe.", "Body")
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(body)
	if have > 0 and need > 0:
		v.add_child(_label("Installed build %d · needed %d" % [have, need], "Small"))
	var go := Button.new()
	go.name = "UpdateButton"
	go.theme_type_variation = &"GoldButton"
	go.text = button_text(store_url)
	go.focus_mode = Control.FOCUS_NONE
	go.custom_minimum_size = Vector2(0, 76)
	go.pressed.connect(func(): OS.shell_open(store_url))
	v.add_child(go)


func hide_required() -> void:
	blocked = false
	if _paused_by_me:
		get_tree().paused = false
	_paused_by_me = false
	if _ui != null:
		_ui.queue_free()
		_ui = null
	cleared.emit()


func _label(text: String, variation: String) -> Label:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = variation
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
