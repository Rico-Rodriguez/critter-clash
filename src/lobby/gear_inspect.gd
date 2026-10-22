class_name GearInspect
extends Control
## One piece of gear on its own, big and slowly turning (drag to turn it): a
## weapon or offhand floats alone with its sparks; a worn piece is shown on
## the hero, wearing nothing else, with the camera on that part of the body.
## Swipe down on it to put it away.

## Camera target and distance for a worn piece, by slot.
const FRAME := {
	"helm": [Vector3(0, 1.95, 0), 3.4], "chest": [Vector3(0, 1.25, 0), 4.6],
	"legs": [Vector3(0, 0.6, 0), 4.2], "trinket": [Vector3(0, 1.2, 0), 5.0],
}

var _pivot: Node3D
var _yaw := 0.6
var _spin := 0.7
var _dragging := false
var _swipe: SwipeDismiss
## How a drag on the stage is being read: "" undecided, "turn" or "close".
var _axis := ""
var _from := Vector2.ZERO
var _last := Vector2.ZERO
var _last_t := 0
var _speed := 0.0


func open(it: Dictionary) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_swipe = SwipeDismiss.attach(self, _close, null, false)
	var col := DB.rarity_color(it["rarity"])
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.028, 0.04)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var glow := TextureRect.new()
	var gt := GradientTexture2D.new()
	var g := Gradient.new()
	g.set_color(0, Color(GearDB.accent(it), 0.32))
	g.set_color(1, Color(0, 0, 0, 0))
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(0.5, 0.0)
	glow.texture = gt
	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	glow.offset_bottom = -440
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(glow)
	var safe := MarginContainer.new()
	safe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	safe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Ui.apply_safe_area(safe, 20)
	add_child(safe)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	safe.add_child(v)
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(spacer)
	var x := Button.new()
	x.theme_type_variation = "RoundButton"
	x.text = "✕"
	x.custom_minimum_size = Vector2(64, 64)
	x.focus_mode = Control.FOCUS_NONE
	x.add_theme_font_size_override("font_size", 32)
	x.pressed.connect(_close)
	top.add_child(x)
	v.add_child(top)
	var svc := SubViewportContainer.new()
	svc.stretch = true
	svc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	svc.mouse_filter = Control.MOUSE_FILTER_STOP
	svc.gui_input.connect(_input_stage)
	v.add_child(svc)
	var vp := SubViewport.new()
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_2X
	svc.add_child(vp)
	GearStage.light(vp, false)
	_pivot = Node3D.new()
	vp.add_child(_pivot)
	var cam := Camera3D.new()
	cam.fov = 30.0
	vp.add_child(cam)
	var pc := GearDB.piece(it)
	var model := str(pc.get("model", ""))
	if model != "":
		_show_prop(it, model, cam)
	else:
		_show_worn(it, cam)
	# Words under the piece: what it is, then what it does.
	var nm := Ui.label(str(it["name"]), "Title", HORIZONTAL_ALIGNMENT_CENTER)
	nm.add_theme_font_size_override("font_size", 36)
	nm.add_theme_color_override("font_color", col.lightened(0.25))
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(nm)
	var parts := ["T%d %s" % [int(it.get("mat", 0)) + 1, GearDB.material_name(str(it["cls"]), int(it.get("mat", 0)))], DB.RARITY_NAME[it["rarity"]], "Power %d" % Game.item_power(it)]
	var st := GearDB.set_of(it)
	if st != "":
		parts.insert(2, DB.SETS[st]["name"])
	var sub := Ui.label(" · ".join(parts), "Body", HORIZONTAL_ALIGNMENT_CENTER)
	sub.add_theme_color_override("font_color", Color(0.72, 0.68, 0.62))
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(sub)
	for line in Game.describe_stats(it):
		var l := Ui.label(line, "Body", HORIZONTAL_ALIGNMENT_CENTER)
		l.add_theme_font_size_override("font_size", 21)
		l.add_theme_color_override("font_color", Color(1.0, 0.65, 0.3) if line.begins_with("Start") else (Color(0.45, 1.0, 0.6) if line.begins_with("Set") else Color(0.6, 0.78, 1.0)))
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(l)
	var hint := Ui.label("Drag to turn", "Caption", HORIZONTAL_ALIGNMENT_CENTER)
	hint.modulate.a = 0.5
	v.add_child(hint)
	Sfx.play("sparkle", -8.0)
	modulate.a = 0.0
	_pivot.scale = Vector3.ONE * 0.6
	var t := create_tween().set_parallel(true).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	t.tween_property(self, "modulate:a", 1.0, 0.2)
	t.tween_property(_pivot, "scale", Vector3.ONE, 0.45)


## A weapon or offhand on its own, centered and framed by its size.
func _show_prop(it: Dictionary, model: String, cam: Camera3D) -> void:
	var holder := Actor.new()
	_pivot.add_child(holder)
	var prop := GearLook.prop_for(model)
	holder.add_child(prop)
	holder.restyle(prop)
	var lk := GearDB.look(it)
	for mi in KK.meshes(prop):
		mi.set_instance_shader_parameter("dye", lk["dye"])
		mi.set_instance_shader_parameter("tint", GearLook.glow_of(it, 1.2))
		mi.set_instance_shader_parameter("grade", GearDB.grade(it))
		mi.set_instance_shader_parameter("accent", GearDB.accent(it))
	var box := AABB()
	var first := true
	for mi in KK.meshes(prop):
		var b: AABB = prop.transform.inverse() * mi.global_transform * mi.get_aabb() if mi.is_inside_tree() else mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	prop.position = -box.get_center()
	var big := maxf(box.size.y, maxf(box.size.x, box.size.z))
	cam.look_at_from_position(Vector3(0, big * 0.12, big * 2.6 + 0.6), Vector3.ZERO, Vector3.UP)
	var spark := GearDB.enchant(it)
	if spark.a > 0.0:
		var p := GearLook.emitter(48, 1.2, 0.07 * maxf(big, 1.0))
		var pm := p.process_material as ParticleProcessMaterial
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		pm.emission_box_extents = box.size * 0.45
		pm.gravity = Vector3(0, 0.5, 0)
		pm.initial_velocity_max = 0.3
		pm.spread = 180.0
		pm.color = Color(spark.r, spark.g, spark.b)
		p.local_coords = true
		_pivot.add_child(p)


## A worn piece on the hero, everything else bare.
func _show_worn(it: Dictionary, cam: Camera3D) -> void:
	var cls := str(it["cls"])
	var a := Actor.new()
	_pivot.add_child(a)
	a.build_model(DB.HEROES[cls]["model"], {}, Color(0.55, 0.68, 1.0), 0.5)
	var pre := {}
	for slot in DB.SLOTS:
		pre[slot] = {}
	pre[it["slot"]] = it
	GearLook.apply(a, cls, pre)
	a.play(DB.HEROES[cls]["anim"]["idle"], 0.0)
	var fr: Array = FRAME.get(str(it["slot"]), FRAME["chest"])
	var at: Vector3 = fr[0]
	cam.look_at_from_position(at + Vector3(0, 0.15, float(fr[1])), at, Vector3.UP)


func _process(dt: float) -> void:
	if _pivot == null:
		return
	if not _dragging:
		_yaw += _spin * dt
		_spin = lerpf(_spin, 0.7, 1.0 - exp(-1.5 * dt))
	_pivot.rotation.y = _yaw


func _input_stage(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		_dragging = e.pressed
		if e.pressed:
			_axis = ""
			_from = e.global_position
			_last = _from
			_last_t = Time.get_ticks_usec()
			_speed = 0.0
		elif _axis == "close":
			if Time.get_ticks_usec() - _last_t > 80000:
				_speed = 0.0
			_swipe.release(_last.y - _from.y, _speed)
	elif e is InputEventMouseMotion and _dragging:
		var p: Vector2 = e.global_position
		if _axis == "":
			var d := p - _from
			if d.length() < DragScroll.SLOP:
				return
			_axis = "close" if d.y > absf(d.x) else "turn"
		if _axis == "close":
			var now := Time.get_ticks_usec()
			_speed = lerpf(_speed, (p.y - _last.y) / maxf((now - _last_t) / 1000000.0, 0.001), 0.6)
			_last = p
			_last_t = now
			_swipe.drag(p.y - _from.y)
		else:
			_yaw += e.relative.x * 0.011
			_spin = e.relative.x * 0.4
	elif e is InputEventScreenDrag and _axis == "turn":
		_yaw += e.relative.x * 0.011
		_spin = e.relative.x * 0.4


func _close() -> void:
	Sfx.play("ui_back", -4.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.15)
	t.tween_callback(queue_free)
