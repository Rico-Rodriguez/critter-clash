extends Node
## Keeps a hunt alive when the app loses focus or goes to the background.
##
## Clash Royale style: leaving pauses the world cleanly (tree paused, hitstop
## ended, audio ducked, stick released) and snapshots what the run has earned
## into the save, so a killed process still pays out on the next boot. Coming
## back within AWAY_LIMIT seconds shows a 3-2-1 countdown and resumes; longer
## than that, the hunt ends as a retreat and its results lead back to the camp.
##
## No class_name: content packs cannot add global classes (see tests.gd).

const AWAY_LIMIT := 60.0
const COUNT_FROM := 3

var hunt: Node
## Unix time the app left, or 0 while focused.
var away_at := 0.0
## True when this guard paused the tree (a menu that paused it keeps it).
var paused_by_us := false
var counting := false
var _layer: CanvasLayer
var _label: Label


func _init(h: Node = null) -> void:
	hunt = h
	process_mode = Node.PROCESS_MODE_ALWAYS


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED:
			suspend(Time.get_unix_time_from_system())
		NOTIFICATION_APPLICATION_FOCUS_IN, NOTIFICATION_APPLICATION_RESUMED:
			_apply(resume(Time.get_unix_time_from_system()))


func _live() -> bool:
	return hunt != null and is_instance_valid(hunt) and not hunt.cards_blocked() and not hunt.bot


## Called on focus loss. Safe to call twice (FOCUS_OUT then PAUSED).
func suspend(now: float) -> void:
	if not _live() or away_at > 0.0:
		return
	away_at = now
	_stop_countdown()
	hunt.end_hitstop()
	Engine.time_scale = 1.0
	if hunt.hud and hunt.hud.has_node("%Stick"):
		hunt.hud.get_node("%Stick").release()
	if is_inside_tree() and not get_tree().paused:
		get_tree().paused = true
		paused_by_us = true
	Sfx.duck(true)
	# Crash safety: if iOS kills us in the background, the next boot pays this.
	var snap: Dictionary = hunt.build_result(false).duplicate(true)
	snap["suspended"] = true
	Game.data["suspended_run"] = snap
	Game.save()


## Called on return. Returns what to do: "none", "countdown" or "lobby".
func resume(now: float) -> String:
	if away_at <= 0.0:
		return "none"
	var away := now - away_at
	away_at = 0.0
	if not _live():
		return "none"
	# Still running: the snapshot is stale and must not pay out later.
	Game.data.erase("suspended_run")
	Game.save()
	if away > AWAY_LIMIT:
		return "lobby"
	if not paused_by_us:
		# A level-up, pact or pause menu was open: it stays and resumes itself.
		Sfx.duck(false)
		return "none"
	return "countdown"


func _apply(action: String) -> void:
	match action:
		"lobby":
			paused_by_us = false
			Sfx.duck(false)
			hunt.tip("away", "You were away too long: the hunt ended and you kept your loot", "hourglass")
			hunt._abandon()
		"countdown":
			_countdown()


func _countdown() -> void:
	counting = true
	if _layer == null:
		_layer = CanvasLayer.new()
		_layer.layer = 90
		_layer.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(_layer)
		var dim := ColorRect.new()
		dim.color = Color(0, 0, 0, 0.35)
		dim.set_anchors_preset(Control.PRESET_FULL_RECT)
		dim.mouse_filter = Control.MOUSE_FILTER_STOP
		_layer.add_child(dim)
		_label = Label.new()
		_label.set_anchors_preset(Control.PRESET_FULL_RECT)
		_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_label.add_theme_font_size_override("font_size", 220)
		_label.add_theme_color_override("font_color", Color(1, 0.86, 0.3))
		_label.add_theme_color_override("font_outline_color", Color(0.12, 0.06, 0.02))
		_label.add_theme_constant_override("outline_size", 36)
		_layer.add_child(_label)
	_layer.visible = true
	for n in range(COUNT_FROM, 0, -1):
		if not counting:
			return
		_label.text = str(n)
		_label.pivot_offset = _label.size * 0.5
		_label.scale = Vector2.ONE * 1.6
		_label.modulate.a = 1.0
		Sfx.play("ui_tap", -6.0)
		var t := _label.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		t.tween_property(_label, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		await get_tree().create_timer(1.0, true, false, true).timeout
	if not counting:
		return
	_finish_countdown()


func _finish_countdown() -> void:
	counting = false
	if _layer:
		_layer.visible = false
	Sfx.duck(false)
	if paused_by_us and is_inside_tree():
		paused_by_us = false
		get_tree().paused = false


func _stop_countdown() -> void:
	counting = false
	if _layer:
		_layer.visible = false
