extends CanvasLayer
## First-launch privacy screen and the consent record behind it. Not a
## class_name: preload it by path (packs cannot register global classes).
##
## Nothing leaves the phone before the player taps through this screen: the
## online account (device key, display name, clan, leaderboards) is only started
## afterwards, and crash reports are an opt-in that defaults to OFF. The answer
## is stored in the save as data["privacy"] = {v, crash, online, crash_sent}.
## Bumping VERSION asks everyone again (do it when the policy changes).

signal done

const VERSION := 1
## Where the policy lives. The repo copy works today; point this at the final
## hosted page (the App Store listing needs the same URL) when it exists.
const POLICY_URL := "https://github.com/Rico-Rodriguez/critter-clash/blob/main/docs/app-store/privacy-policy.md"
const SPLASH := "res://assets/splash.png"

var _crash := false
var _online := true


## True until the player has answered the current policy version.
static func needed() -> bool:
	return int(_rec()["v"]) < VERSION


## Crash reports are sent only after an explicit yes.
static func crash_ok() -> bool:
	var r := _rec()
	return int(r["v"]) >= VERSION and bool(r["crash"])


static func online_ok() -> bool:
	var r := _rec()
	return int(r["v"]) >= VERSION and bool(r["online"])


static func _rec() -> Dictionary:
	var r: Variant = Game.data.get("privacy")
	if not (r is Dictionary):
		r = {}
		Game.data["privacy"] = r
	var d: Dictionary = r
	for k in ["v", "crash_sent"]:
		if not d.has(k):
			d[k] = 0
	if not d.has("crash"):
		d["crash"] = false
	if not d.has("online"):
		d["online"] = true
	return d


## Records an answer. The online switch is the same one the clan screen uses.
static func record(crash: bool, online: bool) -> void:
	var r := _rec()
	r["v"] = VERSION
	r["crash"] = crash
	r["online"] = online
	Game.data["online"]["off"] = not online
	Game.save()


## Shows the screen over `host` and returns when the player answered.
static func ask(host: Node) -> void:
	if not needed():
		return
	var p: CanvasLayer = load("res://src/core/privacy.gd").new()
	host.add_child(p)
	p.build()
	await p.done
	p.queue_free()


func build() -> void:
	layer = 140
	var rec := _rec()
	_crash = bool(rec["crash"]) if int(rec["v"]) > 0 else false
	_online = bool(rec["online"])
	var root := Control.new()
	root.name = "Privacy"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	var shade := ColorRect.new()
	shade.color = Color(0.03, 0.03, 0.05)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(shade)
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
	dim.color = Color(0.02, 0.02, 0.04, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)
	var card := PanelContainer.new()
	card.anchor_left = 0.06
	card.anchor_right = 0.94
	card.anchor_top = 0.5
	card.anchor_bottom = 0.5
	card.grow_vertical = Control.GROW_DIRECTION_BOTH
	root.add_child(card)
	var pad := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 26)
	card.add_child(pad)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	pad.add_child(v)
	v.add_child(_label("YOUR PRIVACY", "Title", false))
	v.add_child(_label("Gravelight keeps your progress on this phone. Online play (clans, rankings, parties) uses an anonymous account made from a random key and the hunter name you pick. We never ask for your real name, email, contacts or location, and we show no ads or trackers.", "Body", true))
	v.add_child(HSeparator.new())
	v.add_child(_toggle("Online play", "Clans, rankings and parties.", _online, func(on: bool): _online = on))
	v.add_child(_toggle("Share crash reports", "Optional. If the game crashes, send the error log, device model and OS version so it can be fixed. Off by default.", _crash, func(on: bool): _crash = on))
	var link := Button.new()
	link.name = "PolicyLink"
	link.text = "Read the privacy policy"
	link.theme_type_variation = &"Ghost"
	link.focus_mode = Control.FOCUS_NONE
	link.pressed.connect(func(): OS.shell_open(POLICY_URL))
	v.add_child(link)
	var go := Button.new()
	go.name = "AcceptButton"
	go.theme_type_variation = &"GoldButton"
	go.text = "CONTINUE"
	go.focus_mode = Control.FOCUS_NONE
	go.custom_minimum_size = Vector2(0, 76)
	go.pressed.connect(_accept)
	v.add_child(go)
	v.add_child(_label("You can change both choices any time in Settings.", "Small", true))


func _accept() -> void:
	record(_crash, _online)
	done.emit()


func _toggle(title: String, note: String, on: bool, cb: Callable) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	var t := CheckButton.new()
	t.text = title
	t.button_pressed = on
	t.focus_mode = Control.FOCUS_NONE
	t.toggled.connect(cb)
	box.add_child(t)
	box.add_child(_label(note, "Small", true))
	return box


func _label(text: String, variation: String, wrap: bool) -> Label:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = variation
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if not wrap or variation != "Body" else HORIZONTAL_ALIGNMENT_LEFT
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l
