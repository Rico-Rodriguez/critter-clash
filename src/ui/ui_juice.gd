extends Node
## Gives every button the shared press bounce as it enters the tree. Added
## from main.gd at runtime (not an autoload, so content packs can carry it).
## A button opts out with `set_meta("no_juice", true)` before it is added.

const FxUi := preload("res://src/ui/fx_ui.gd")


func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)


func _on_node_added(n: Node) -> void:
	if n is BaseButton and not n.has_meta("no_juice"):
		FxUi.press_bounce(n as BaseButton)
		(n as BaseButton).pressed.connect(_on_pressed.bind(n as BaseButton))


## Every button clicks. A button whose handler plays its own sound (a coin, a
## chime) keeps that one: we look once the handlers have run.
func _on_pressed(b: BaseButton) -> void:
	_click_if_quiet.call_deferred(b, Time.get_ticks_msec())


func _click_if_quiet(b: BaseButton, since: int) -> void:
	if Sfx.last_menu_ms >= since:
		return
	var label := str(b.get("text")).to_lower() if "text" in b else ""
	if b.toggle_mode:
		Sfx.play("ui_toggle", -5.0)
	elif label in ["back", "close", "cancel", "x", "\u2715", "\u00d7", "\u2039", "\u2039 back", "not now", "later"] or b.name.to_lower().contains("close") or b.name.to_lower().contains("back"):
		Sfx.play("ui_back", -6.0)
	else:
		Sfx.play("ui_tap", -5.0)


## Remembers where the last finger went down (see FxUi.last_tap).
func _input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		FxUi.mark_tap(e.position)
