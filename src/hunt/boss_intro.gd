extends Node
## The boss entrance: a short directed shot (sweep over to the boss, low angle
## push-in, a slam as the name card lands, whip back to the hero), letterbox
## bars, the name card and a SKIP button. The shot is a pure function of the
## hunt's phase clock (`shot`), so skipping just jumps the clock to the whip
## back and the camera glides home instead of cutting. No class_name: preload.

const LENGTH := 3.4     # hunt.phase_t at which the fight starts
const SLAM_AT := 1.2    # the card lands, the camera punches, the sting plays
const WHIP_AT := 2.5    # the camera heads back to the hero
const SKIP_AFTER := 0.5 # taps before this are ignored

## Per boss: sideways drift of the reveal (m), how far the camera drops (deg),
## the hold zoom (smaller = closer).
const STYLE := {
	"gravemaw": {"drift": 1.8, "drop": 18.0, "zoom": 0.80},
	"thorn": {"drift": -1.8, "drop": 12.0, "zoom": 0.84},
	"hexer": {"drift": 0.0, "drop": 20.0, "zoom": 0.76},
	"warden": {"drift": 1.2, "drop": 14.0, "zoom": 0.80},
	"rime": {"drift": -1.2, "drop": 16.0, "zoom": 0.78},
	"cinder": {"drift": 1.5, "drop": 19.0, "zoom": 0.76},
}

var hunt: Node
var boss_id := ""
var _bars: Control
var _top: Control
var _top_bar: ColorRect
var _bot_bar: ColorRect
var _card: VBoxContainer
var _skip: Button
var _slammed := false


## Camera for time `t` of the entrance: {focus: Vector3, zoom: float, pitch: float}
## where pitch is the drop (deg) from the normal angle.
static func shot(id: String, t: float, boss_pos: Vector3, hero_pos: Vector3) -> Dictionary:
	var st: Dictionary = STYLE.get(id, STYLE["gravemaw"])
	var drop: float = st["drop"]
	var hold: float = st["zoom"]
	var home := hero_pos.lerp(boss_pos, 0.25)
	var reveal := smoothstep(0.0, SLAM_AT, t)
	var back := smoothstep(WHIP_AT, LENGTH, t)
	# Push in on the boss, drifting sideways, then creep during the hold.
	var focus := boss_pos + Vector3(float(st["drift"]) * (1.0 - reveal), 0.0, 1.5 * (1.0 - reveal))
	var zoom := lerpf(1.0, hold, reveal) - 0.05 * smoothstep(SLAM_AT, WHIP_AT, t)
	var pitch := drop * reveal
	focus = focus.lerp(home, back)
	zoom = lerpf(zoom, 1.25, back)
	pitch *= 1.0 - back
	return {"focus": focus, "zoom": zoom, "pitch": pitch}


## Letterbox bars: 0 to 1 in, then out as the camera heads back.
static func bars(t: float) -> float:
	return smoothstep(0.0, 0.35, t) * (1.0 - smoothstep(WHIP_AT + 0.2, LENGTH, t))


## The name card's opacity.
static func card_alpha(t: float) -> float:
	return smoothstep(SLAM_AT, SLAM_AT + 0.15, t) * (1.0 - smoothstep(WHIP_AT, WHIP_AT + 0.4, t))


func setup(h: Node, id: String) -> void:
	hunt = h
	boss_id = id
	var bd: Dictionary = DB.boss_def(id)
	var col: Color = Color(bd["color"]).lightened(0.25)
	_bars = Control.new()
	_bars.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_top_bar = ColorRect.new()
	_top_bar.color = Color(0.02, 0.02, 0.04, 0.96)
	_top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bot_bar = ColorRect.new()
	_bot_bar.color = _top_bar.color
	_bot_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bars.add_child(_top_bar)
	_bars.add_child(_bot_bar)
	# Under the HUD, so the pause button and joystick stay on top of the bars.
	h.hud.add_child(_bars)
	h.hud.move_child(_bars, 0)
	_top = Control.new()
	_top.set_anchors_preset(Control.PRESET_FULL_RECT)
	_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.hud.add_child(_top)
	_card = VBoxContainer.new()
	_card.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_card.anchor_left = 0.0
	_card.anchor_right = 1.0
	_card.offset_left = 24.0
	_card.offset_right = -24.0
	_card.anchor_top = 0.62
	_card.anchor_bottom = 0.62
	_card.grow_vertical = Control.GROW_DIRECTION_BOTH
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_theme_constant_override("separation", 4)
	_card.modulate.a = 0.0
	var name_l := Ui.label(str(bd["name"]), "HudTitle", HORIZONTAL_ALIGNMENT_CENTER)
	name_l.add_theme_font_size_override("font_size", 64)
	name_l.add_theme_color_override("font_color", col)
	name_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_card.add_child(name_l)
	var rule := ColorRect.new()
	rule.color = col
	rule.custom_minimum_size = Vector2(0, 3)
	rule.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	rule.custom_minimum_size.x = 260.0
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(rule)
	var title_l := Ui.label(str(bd["title"]), "HudLabel", HORIZONTAL_ALIGNMENT_CENTER)
	title_l.add_theme_font_size_override("font_size", 28)
	title_l.add_theme_color_override("font_color", Color(0.95, 0.9, 0.8))
	_card.add_child(title_l)
	_top.add_child(_card)
	_skip = Button.new()
	_skip.text = "SKIP"
	_skip.focus_mode = Control.FOCUS_NONE
	_skip.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_skip.offset_left = -150.0
	_skip.offset_right = -24.0
	_skip.offset_top = -120.0
	_skip.offset_bottom = -56.0
	# Same plate as the upgrade badge: dark, gold rim, crisp.
	_skip.add_theme_font_size_override("font_size", 22)
	_skip.add_theme_color_override("font_color", Color(1.0, 0.88, 0.5))
	_skip.add_theme_color_override("font_pressed_color", Color(1.0, 0.95, 0.75))
	_skip.add_theme_color_override("font_hover_color", Color(1.0, 0.88, 0.5))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.08, 0.11, 0.94)
	sb.set_corner_radius_all(26)
	sb.set_border_width_all(3)
	sb.border_color = Color(0.95, 0.76, 0.32)
	for k in ["normal", "focus", "hover", "disabled", "pressed"]:
		_skip.add_theme_stylebox_override(k, sb)
	_skip.pressed.connect(skip)
	_skip.modulate.a = 0.0
	_top.add_child(_skip)


## Jumps to the whip back; the camera glides home from wherever it is.
func skip() -> void:
	if hunt and hunt.phase == "boss_intro" and hunt.phase_t < WHIP_AT:
		hunt.phase_t = WHIP_AT


func _unhandled_input(e: InputEvent) -> void:
	if hunt == null or hunt.phase_t < SKIP_AFTER:
		return
	if (e is InputEventScreenTouch and e.pressed) or (e is InputEventMouseButton and e.pressed):
		skip()


func _process(_dt: float) -> void:
	if hunt == null:
		return
	if hunt.phase != "boss_intro":
		_bars.queue_free()
		_top.queue_free()
		queue_free()
		return
	var t: float = hunt.phase_t
	var vp := _bars.get_viewport_rect().size
	var h := vp.y * 0.1 * bars(t)
	_top_bar.position = Vector2(0, 0)
	_top_bar.size = Vector2(vp.x, h)
	_bot_bar.position = Vector2(0, vp.y - h)
	_bot_bar.size = Vector2(vp.x, h)
	var a := card_alpha(t)
	_card.modulate.a = a
	_card.scale = Vector2.ONE * (1.0 + 0.12 * (1.0 - smoothstep(SLAM_AT, SLAM_AT + 0.3, t)))
	_card.pivot_offset = _card.size * 0.5
	_skip.modulate.a = smoothstep(SKIP_AFTER, SKIP_AFTER + 0.3, t) * (1.0 - smoothstep(WHIP_AT - 0.1, WHIP_AT + 0.2, t))
	_skip.disabled = t >= WHIP_AT
	if t >= SLAM_AT and not _slammed:
		_slammed = true
		_slam()


## The beat the name lands on: camera punch and shake, a roar, and the sting
## (an event named boss_sting_<id>, else the shared boss_sting; see
## tools/audio/build_boss_stings.py). It sits 3 dB under the roar's level so the
## two together stay clear of clipping; the SFX slider scales both.
func _slam() -> void:
	hunt.cam.punch = 0.1
	hunt.cam.add_trauma(0.55)
	Sfx.play("boss_roar", 0.0, 0.85)
	for ev in ["boss_sting_" + boss_id, "boss_sting"]:
		if Sfx.has(ev):
			Sfx.play(ev, -3.0, 1.0, 0.0)
			break
