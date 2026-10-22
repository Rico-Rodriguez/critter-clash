extends Control
## A one-time pointer for a new player: a parchment note with an arrow at the
## one thing worth pressing next. Any tap puts it away; it never blocks the
## tap itself, so pressing the thing it points at just works.

var _target: Control
var _below := false
var _panel: PanelContainer
var _arrow: Polygon2D
var _t := 0.0
var _leaving := false
var _keep: Callable


## `below`: the note hangs under the target (for things near the top).
## `keep`: the note goes away once this returns false (a sheet opened).
func setup(target: Control, title: String, text: String, below: bool, keep: Callable) -> void:
	_target = target
	_keep = keep
	_below = below
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel = PanelContainer.new()
	_panel.theme_type_variation = &"Parchment"
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.custom_minimum_size = Vector2(380, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.add_child(Ui.label(title, "ParchmentTitle"))
	var body := Ui.label(text, "ParchmentText")
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(body)
	_panel.add_child(v)
	add_child(_panel)
	_arrow = Polygon2D.new()
	add_child(_arrow)
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.3).set_delay(0.5)


func _ready() -> void:
	var sb := _panel.get_theme_stylebox("panel")
	_arrow.color = sb.bg_color if sb is StyleBoxFlat else Color(0.93, 0.86, 0.7)


func _process(dt: float) -> void:
	if not is_instance_valid(_target) or not _target.is_visible_in_tree() or not _keep.call():
		dismiss()
		return
	_t += dt
	var r := _target.get_global_rect()
	var bob := sin(_t * 4.0) * 6.0
	var w := clampf(_panel.size.x, 0.0, size.x - 32.0)
	var x := clampf(r.get_center().x - w * 0.5, 16.0, size.x - 16.0 - w)
	var tip_y := r.end.y + 10.0 + bob if _below else r.position.y - 10.0 + bob
	var y := tip_y + 18.0 if _below else tip_y - 18.0 - _panel.size.y
	_panel.position = Vector2(x, y)
	var cx := clampf(r.get_center().x, x + 30.0, x + w - 30.0)
	var s := -1.0 if _below else 1.0
	_arrow.polygon = PackedVector2Array([Vector2(cx - 18.0, tip_y - 20.0 * s), Vector2(cx + 18.0, tip_y - 20.0 * s), Vector2(cx, tip_y)])


func _input(e: InputEvent) -> void:
	if (e is InputEventMouseButton and e.pressed) or (e is InputEventScreenTouch and e.pressed):
		dismiss()


func dismiss() -> void:
	if _leaving:
		return
	_leaving = true
	set_process_input(false)
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.2)
	t.tween_callback(queue_free)
