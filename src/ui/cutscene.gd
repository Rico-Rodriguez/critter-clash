extends Control
## A short in-engine cutscene: a small 3D stage (the chapter's zone, the hero
## and the boss in their real models), letterbox bars, a caption that types
## out, and a slow camera. Tap to go on, SKIP to leave. Beats come from
## story_db.gd. No class_name: preload it by path.

signal finished

const STORY_DB := preload("res://src/data/story_db.gd")
const G := "res://assets/kaykit/graveyard/"
const D := "res://assets/kaykit/dungeon/"
const BAR_H := 120.0
const TYPE_SPEED := 46.0
const GOLD := Color(0.95, 0.78, 0.4)

## Props per zone: [file, x, z, yaw, scale].
const SETS := {
	"barrow": [[G + "gravestone.gltf", -4.2, -2.0, 0.3, 1.4], [G + "grave_A.gltf", 5.0, -3.0, -0.4, 1.4], [G + "tree_dead_large.gltf", -6.5, -6.0, 0.0, 1.8],
		[G + "lantern_standing.gltf", -2.4, 1.2, 0.0, 1.5], [G + "pillar.gltf", 6.5, -7.0, 0.0, 1.6], [G + "gravestone.gltf", 1.2, -8.0, 0.2, 1.5]],
	"grove": [[G + "tree_pine_orange_large.gltf", -5.5, -4.0, 0.0, 2.0], [G + "tree_pine_yellow_medium.gltf", 6.0, -5.0, 0.0, 2.0], [G + "tree_pine_orange_large.gltf", 1.0, -10.0, 0.0, 2.4],
		[G + "tree_dead_medium.gltf", -2.8, -9.0, 0.0, 1.8], [G + "lantern_standing.gltf", -2.4, 1.2, 0.0, 1.5], [G + "pumpkin_orange_jackolantern.gltf", 3.0, 1.0, 0.4, 1.6]],
	"depths": [[G + "pillar.gltf", -5.0, -3.0, 0.0, 2.0], [G + "pillar.gltf", 5.5, -3.5, 0.0, 2.0], [G + "coffin_decorated.gltf", -3.0, -7.0, 0.6, 1.5],
		[G + "candle_triple.gltf", -1.8, 1.4, 0.0, 2.0], [G + "crypt.gltf", 0.5, -12.0, 0.0, 2.2]],
	"vault": [[D + "chest_gold.gltf", -3.4, -1.0, 0.5, 1.8], [D + "coin_stack_large.gltf", 4.6, -2.0, 0.0, 1.8], [D + "barrel_large_decorated.gltf", -5.5, -4.0, 0.0, 1.8],
		[D + "barrier_column.gltf", 6.0, -6.0, 0.0, 2.0], [D + "coin_stack_medium.gltf", -2.2, 1.2, 0.0, 1.8], [D + "barrier_column.gltf", -7.0, -8.0, 0.0, 2.0]],
}

## Camera presets: [from position, to position, look-at].
const CAMS := {
	"wide": [Vector3(0.9, 3.4, 16.0), Vector3(0.4, 3.0, 14.0), Vector3(0.2, 2.1, -0.6)],
	"hero": [Vector3(-0.3, 1.5, 7.0), Vector3(-0.8, 1.4, 5.8), Vector3(-1.5, 0.85, 0.0)],
	"boss": [Vector3(0.8, 3.0, 14.5), Vector3(1.2, 3.0, 12.8), Vector3(1.9, 2.9, -1.2)],
}

var chapter := {}
var which := "intro"
var hero_id := "knight"
var _beats: Array = []
var _i := -1
var _vp: SubViewport
var _cam: Camera3D
var _hero: Actor
var _boss: Actor
var _name_l: Label
var _line_l: Label
var _hint: Label
var _typing := false
var _type_tw: Tween
var _cam_tw: Tween
var _done := false
var _card: Control
var _box: Control


## Starts the scene for `ch`'s "intro" or "outro" with the player's hero.
func play(ch: Dictionary, which_: String, hero_: String, title := true) -> void:
	chapter = ch
	which = which_
	hero_id = hero_
	_beats = ch[which_]
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_stage()
	_build_ui()
	if which_ == "intro" and title:
		_box.visible = false
		await _title_card()
		_box.visible = true
	_next()


func _build_stage() -> void:
	var zone: Dictionary = DB.zone(str(chapter["zone"]))
	var env: Dictionary = zone["env"]
	var svc := SubViewportContainer.new()
	svc.stretch = true
	svc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	svc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(svc)
	_vp = SubViewport.new()
	_vp.own_world_3d = true
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	svc.add_child(_vp)
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = env["bg"]
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = env["ambient"]
	e.ambient_light_energy = float(env["ambient_e"]) * 1.7
	var we := WorldEnvironment.new()
	we.environment = e
	_vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_color = env["sun"]
	sun.light_energy = float(env["sun_e"]) * 2.4
	sun.rotation_degrees = Vector3(-38, 28, 0)
	sun.shadow_enabled = true
	_vp.add_child(sun)
	var rim := DirectionalLight3D.new()
	rim.light_color = Color(env["motes"]).lerp(Color.WHITE, 0.3)
	rim.light_energy = 0.7
	rim.rotation_degrees = Vector3(-18, 160, 0)
	_vp.add_child(rim)
	var ground := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 22.0
	cyl.bottom_radius = 22.0
	cyl.height = 0.2
	ground.mesh = cyl
	ground.position.y = -0.1
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(env["ambient"]).darkened(0.62)
	gm.roughness = 1.0
	ground.material_override = gm
	_vp.add_child(ground)
	for p: Array in SETS.get(str(chapter["zone"]), SETS["barrow"]):
		if not ResourceLoader.exists(str(p[0])):
			continue
		var n := KK.prop(str(p[0]))
		n.position = Vector3(float(p[1]), 0, float(p[2]))
		n.rotation.y = float(p[3])
		n.scale = Vector3.ONE * float(p[4])
		_vp.add_child(n)
	# A lantern's worth of warm light between them.
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.78, 0.5)
	lamp.light_energy = 2.2
	lamp.omni_range = 9.0
	lamp.position = Vector3(0.4, 2.4, 1.6)
	_vp.add_child(lamp)
	var hd: Dictionary = DB.HEROES[hero_id]
	_hero = Actor.new()
	_vp.add_child(_hero)
	_hero.build_model(hd["model"], hd["weapons"], Color(0.55, 0.68, 1.0), 0.5)
	GearLook.apply(_hero, hero_id)
	_hero.position = Vector3(-1.5, 0, 0)
	_hero.rotation.y = PI * 0.5 - 0.25
	_hero.play(hd["anim"]["idle"], 0.0)
	var bd: Dictionary = STORY_DB.boss_def(DB.boss_def(str(chapter["boss"])), str(chapter["boss"]), chapter)
	var aura: Color = bd["color"]
	_boss = Actor.new()
	_vp.add_child(_boss)
	_boss.build_model(bd["model"], bd["weapons"], aura, 0.55, aura)
	_boss.model.scale = Vector3.ONE * float(bd["scale"])
	_boss.position = Vector3(1.9, 0, -1.2)
	_boss.rotation.y = -PI * 0.5 + 0.3
	_boss.play("Skeletons_Idle" if str(bd["model"]).begins_with("Skeleton") else str(hd["anim"]["idle"]), 0.0)
	var glow := OmniLight3D.new()
	glow.light_color = aura
	glow.light_energy = 1.6
	glow.omni_range = 7.0
	glow.position = Vector3(1.9, 3.6, -0.2)
	_vp.add_child(glow)
	_cam = Camera3D.new()
	_cam.fov = 38.0
	_vp.add_child(_cam)
	_set_cam("wide", false)


func _set_cam(key: String, move := true) -> void:
	var c: Array = CAMS[key]
	if _cam_tw:
		_cam_tw.kill()
	_cam.look_at_from_position(c[0], c[2], Vector3.UP)
	if move:
		_cam_tw = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		var from: Vector3 = c[0]
		var to: Vector3 = c[1]
		var look: Vector3 = c[2]
		_cam_tw.tween_method(func(t: float): _cam.look_at_from_position(from.lerp(to, t), look, Vector3.UP), 0.0, 1.0, 6.0)


func _build_ui() -> void:
	for top in [true, false]:
		var bar := ColorRect.new()
		bar.color = Color.BLACK
		bar.anchor_left = 0.0
		bar.anchor_right = 1.0
		bar.anchor_top = 0.0 if top else 1.0
		bar.anchor_bottom = 0.0 if top else 1.0
		bar.offset_top = 0.0 if top else -BAR_H
		bar.offset_bottom = BAR_H if top else 0.0
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(bar)
	var box := VBoxContainer.new()
	box.anchor_left = 0.06
	box.anchor_right = 0.94
	box.anchor_top = 1.0
	box.anchor_bottom = 1.0
	box.offset_top = -BAR_H - 270.0
	box.offset_bottom = -BAR_H - 24.0
	box.alignment = BoxContainer.ALIGNMENT_END
	box.add_theme_constant_override("separation", 6)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	_box = box
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.03, 0.05, 0.82)
	sb.border_color = Color(GOLD, 0.55)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(22)
	panel.add_theme_stylebox_override("panel", sb)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(panel)
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 8)
	pv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(pv)
	_name_l = Ui.label("", "Heading")
	pv.add_child(_name_l)
	_line_l = Ui.label("", "Body")
	_line_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_line_l.custom_minimum_size = Vector2(0, 110)
	pv.add_child(_line_l)
	_hint = Ui.label("TAP TO CONTINUE", "Caption", HORIZONTAL_ALIGNMENT_RIGHT)
	_hint.modulate.a = 0.0
	pv.add_child(_hint)
	var skip := Button.new()
	skip.name = "Skip"
	skip.text = "SKIP"
	skip.theme_type_variation = &"Ghost"
	skip.focus_mode = Control.FOCUS_NONE
	skip.anchor_left = 1.0
	skip.anchor_right = 1.0
	skip.offset_left = -170.0
	skip.offset_right = -24.0
	skip.offset_top = BAR_H + 18.0
	skip.offset_bottom = BAR_H + 80.0
	skip.pressed.connect(_finish)
	add_child(skip)


func _title_card() -> void:
	_card = Control.new()
	_card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.04, 0.78)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(dim)
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 10)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(v)
	v.add_child(Ui.label("CHAPTER %d" % (STORY_DB.index(str(chapter["id"])) + 1), "Caption", HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(Ui.label(str(chapter["title"]), "Title", HORIZONTAL_ALIGNMENT_CENTER))
	var sub := Ui.label(str(chapter["blurb"]), "Small", HORIZONTAL_ALIGNMENT_CENTER)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.custom_minimum_size = Vector2(560, 0)
	sub.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(sub)
	add_child(_card)
	_card.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_card, "modulate:a", 1.0, 0.6)
	tw.tween_interval(1.7)
	tw.tween_property(_card, "modulate:a", 0.0, 0.8)
	await tw.finished
	_card.queue_free()
	_card = null


func _gui_input(event: InputEvent) -> void:
	var tap: bool = (event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT)
	if tap and not _done and _card == null:
		accept_event()
		if _typing:
			_type_tw.kill()
			_line_l.visible_ratio = 1.0
			_typing = false
			_hint.modulate.a = 1.0
		else:
			_next()


func _next() -> void:
	_i += 1
	if _i >= _beats.size():
		_finish()
		return
	_show(_i)


func _show(i: int) -> void:
	var b: Dictionary = _beats[i]
	var who := str(b["who"])
	match who:
		"hero":
			_name_l.text = str(DB.HEROES[hero_id]["name"]).to_upper()
			_name_l.add_theme_color_override("font_color", Color(0.65, 0.8, 1.0))
		"boss":
			var bd: Dictionary = STORY_DB.boss_def(DB.boss_def(str(chapter["boss"])), str(chapter["boss"]), chapter)
			_name_l.text = str(bd["name"]).to_upper()
			_name_l.add_theme_color_override("font_color", Color(bd["color"]).lightened(0.2))
		_:
			_name_l.text = ""
	_line_l.text = str(b["line"]) if who != "narrator" else str(b["line"])
	_line_l.add_theme_color_override("font_color", Color(0.88, 0.84, 0.76) if who == "narrator" else Color.WHITE)
	_set_cam(str(b.get("cam", "wide")))
	_hint.modulate.a = 0.0
	_typing = true
	_line_l.visible_ratio = 0.0
	if _type_tw:
		_type_tw.kill()
	_type_tw = create_tween()
	_type_tw.tween_property(_line_l, "visible_ratio", 1.0, maxf(_line_l.text.length() / TYPE_SPEED, 0.3))
	_type_tw.finished.connect(func():
		_typing = false
		_hint.modulate.a = 1.0)


func _finish() -> void:
	if _done:
		return
	_done = true
	finished.emit()
	queue_free()
