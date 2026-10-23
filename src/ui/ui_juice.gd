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
