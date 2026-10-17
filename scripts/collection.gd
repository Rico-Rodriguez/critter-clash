class_name Collection
extends Control

signal closed

var app: Node
var species := "ember"
var form := "base"
var stage: Node3D
var spin: Node3D
var name_label: Label
var blurb_label: Label
var stats_label: Label
var form_row: HBoxContainer
var chip_row: HBoxContainer


func setup(owner_app: Node) -> void:
	app = owner_app


func _ready() -> void:
	UiKit.ensure()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var wash := ColorRect.new()
	wash.set_anchors_preset(Control.PRESET_FULL_RECT)
	wash.color = Color("f6e2cf")
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(wash)
	var safe := UiKit.safe_insets()

	var back := UiKit.button("Back", 150, 58)
	back.position = Vector2(safe.l, safe.t)
	back.add_theme_font_size_override("font_size", 22)
	back.pressed.connect(func() -> void: closed.emit())
	add_child(back)
	var title := UiKit.label("Field Guide", 36, Color("3a241c"), "x")
	title.position = Vector2(190, safe.t + 6)
	title.size = Vector2(480, 48)
	add_child(title)

	chip_row = HBoxContainer.new()
	chip_row.position = Vector2(safe.l, safe.t + 74)
	chip_row.size = Vector2(720 - safe.l - safe.r, 64)
	chip_row.add_theme_constant_override("separation", 8)
	chip_row.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(chip_row)

	var frame := SubViewportContainer.new()
	frame.position = Vector2(150, safe.t + 150)
	frame.size = Vector2(420, 420)
	frame.stretch = true
	add_child(frame)
	var vp := SubViewport.new()
	vp.size = Vector2i(640, 640)
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.msaa_3d = Viewport.MSAA_2X
	frame.add_child(vp)
	stage = Node3D.new()
	vp.add_child(stage)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("fff4e8")
	e.ambient_light_energy = 1.0
	env.environment = e
	stage.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-36, 32, 0)
	sun.light_energy = 1.55
	sun.light_color = Color("fff1d6")
	stage.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-12, 150, 0)
	fill.light_energy = 0.4
	fill.light_color = Color("d7e4ff")
	stage.add_child(fill)
	var cam := Camera3D.new()
	cam.fov = 28.0
	cam.position = Vector3(0.9, 1.05, 2.7)
	stage.add_child(cam)
	cam.look_at(Vector3(0, 0.55, 0), Vector3.UP)
	var floor := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.85
	disc.bottom_radius = 0.85
	disc.height = 0.06
	floor.mesh = disc
	floor.position = Vector3(0, -0.02, 0)
	floor.material_override = StyleLib.flat_material(Color("e7c8a4"), 0.35)
	stage.add_child(floor)

	form_row = HBoxContainer.new()
	form_row.position = Vector2(36, safe.t + 584)
	form_row.size = Vector2(648, 72)
	form_row.alignment = BoxContainer.ALIGNMENT_CENTER
	form_row.add_theme_constant_override("separation", 10)
	add_child(form_row)

	name_label = UiKit.label("", 32, Color("3a241c"), "x")
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.position = Vector2(40, safe.t + 668)
	name_label.size = Vector2(640, 44)
	add_child(name_label)
	blurb_label = UiKit.label("", 18, Color("6a4636"), "m")
	blurb_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	blurb_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	blurb_label.position = Vector2(48, safe.t + 714)
	blurb_label.size = Vector2(624, 78)
	add_child(blurb_label)
	stats_label = UiKit.label("", 18, Color("3a241c"), "b")
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stats_label.position = Vector2(40, safe.t + 796)
	stats_label.size = Vector2(640, 120)
	add_child(stats_label)

	_build_chips()
	_select("ember", "base")


func _process(dt: float) -> void:
	if spin:
		spin.rotate_y(dt * 0.7)


func _build_chips() -> void:
	for id in Roster.ORDER:
		var info: Dictionary = Roster.info(id)
		var b := Button.new()
		b.text = info.name
		b.custom_minimum_size = Vector2(104, 54)
		b.add_theme_font_override("font", UiKit.font_b)
		b.add_theme_font_size_override("font_size", 14)
		b.add_theme_color_override("font_color", Color("3a241c"))
		b.add_theme_color_override("font_hover_color", Color("3a241c"))
		b.add_theme_color_override("font_pressed_color", Color("3a241c"))
		var bg: Color = info.card
		b.add_theme_stylebox_override("normal", UiKit.chunky(bg, bg.darkened(0.28)))
		b.add_theme_stylebox_override("hover", UiKit.chunky(bg.lightened(0.08), bg.darkened(0.28)))
		b.add_theme_stylebox_override("pressed", UiKit.chunky(bg.darkened(0.08), bg.darkened(0.35), true))
		b.pressed.connect(_select.bind(id, "base"))
		chip_row.add_child(b)


func _select(next_species: String, next_form: String) -> void:
	species = next_species
	form = next_form
	_build_forms()
	_show_model()
	var stats := Roster.form_stats(species, form)
	name_label.text = "%s   ·   %s" % [stats.name, stats.role]
	blurb_label.text = stats.blurb
	var line := "HP %d    DMG %d    RNG %.1f    SPD %.1f    %d sparks" % [
		int(stats.hp), int(stats.dmg), stats.range, stats.speed, int(stats.cost)
	]
	var extra := _extras(stats)
	stats_label.text = line if extra == "" else line + "\n" + extra


func _build_forms() -> void:
	for child in form_row.get_children():
		child.queue_free()
	var keys: Array = ["base"]
	keys.append_array(Roster.branches(species))
	for key in keys:
		var label := Roster.form_name(species, key)
		var b := Button.new()
		b.text = label
		b.custom_minimum_size = Vector2(200, 64)
		b.add_theme_font_override("font", UiKit.font_x)
		b.add_theme_font_size_override("font_size", 16)
		b.add_theme_color_override("font_color", Color("3a241c"))
		b.add_theme_color_override("font_hover_color", Color("3a241c"))
		b.add_theme_color_override("font_pressed_color", Color("3a241c"))
		var bg := Color("fff6ea") if key == "base" else Roster.habitat_color(key)
		var lip := Color("c4a48a") if key == "base" else bg.darkened(0.32)
		var pressed: bool = String(key) == form
		b.add_theme_stylebox_override("normal", UiKit.chunky(bg, lip, pressed))
		b.add_theme_stylebox_override("hover", UiKit.chunky(bg.lightened(0.06), lip))
		b.add_theme_stylebox_override("pressed", UiKit.chunky(bg.darkened(0.06), lip, true))
		b.pressed.connect(_select.bind(species, key))
		form_row.add_child(b)


func _show_model() -> void:
	if spin and is_instance_valid(spin):
		spin.queue_free()
	spin = Node3D.new()
	stage.add_child(spin)
	var packed: PackedScene = app.arena.packed("%s_%s" % [species, form])
	var model: Node3D = packed.instantiate()
	spin.add_child(model)
	var flag := Color("ffb15a")
	if form != "base":
		flag = Roster.habitat_color(form)
	StyleLib.stylize(model, 0.02, Color.WHITE, flag, true)
	var anim := CritterAnimator.new()
	anim.bind(model, String(Roster.info(species)["gait"]))
	anim.tick(0.2, false)
	app._fit_model(model, 1.35)


func _extras(stats: Dictionary) -> String:
	var bits: PackedStringArray = []
	if bool(stats.get("flying", false)):
		bits.append("Flies")
	if bool(stats.get("hits_air", false)):
		bits.append("Reaches flyers")
	if float(stats.get("splash", 0.0)) > 0.2:
		bits.append("Splash %.1f" % float(stats.splash))
	if bool(stats.get("support", false)):
		bits.append("Heals %d" % int(stats.heal))
	if float(stats.get("reflect", 0.0)) > 0.0:
		bits.append("Reflect %d%%" % int(round(float(stats.reflect) * 100.0)))
	if float(stats.get("slow", 0.0)) > 0.0:
		bits.append("Slow")
	if float(stats.get("burn", 0.0)) > 0.0:
		bits.append("Burn %d" % int(stats.burn))
	if float(stats.get("aura_dps", 0.0)) > 0.0:
		bits.append("Aura %d" % int(stats.aura_dps))
	if float(stats.get("aura_speed", 0.0)) > 0.0:
		bits.append("Haste aura")
	if bits.is_empty():
		return "No extra trick. Just a sturdy body."
	return "  ·  ".join(bits)
