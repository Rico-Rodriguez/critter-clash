extends RefCounted
## A pet on a small pedestal in its own 3D viewport: the Pets tab and a pet's
## detail page show it large, drag to turn it, tap to make it perform.
## `PetStage.make(id, height)` returns the Control; nothing to free by hand.

const SDB := preload("res://src/data/sidekick_db.gd")
const SKS := preload("res://src/autoload/sidekicks.gd")
const Look := preload("res://src/core/sidekick_look.gd")
const RAYS := preload("res://src/fx/ui_rays.gdshader")


## `at_stage` >= 0 shows that growth stage instead of the owned one (the
## evolve scene, which shows before and after).
static func make(id: String, h: float, hint := true, at_stage := -1) -> Control:
	var d: Dictionary = SDB.def(id)
	var col: Color = d["color"]
	var stage := at_stage if at_stage >= 0 else (SKS.stage(Game.data, id) if SKS.is_owned(Game.data, id) else 1)
	var size := maxf(float(d["scale"]) * float(SDB.STAGE_SCALE[stage]), 0.55)
	var fly := float(d.get("fly", 0.0))
	var root := Control.new()
	root.custom_minimum_size = Vector2(0, h)
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.clip_contents = true
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# A soft pool of the pet's colour behind it.
	var glow := TextureRect.new()
	var gt := GradientTexture2D.new()
	var g := Gradient.new()
	g.set_color(0, Color(col.r * 0.5, col.g * 0.5, col.b * 0.5, 0.75))
	g.set_color(1, Color(0.04, 0.035, 0.05, 0.0))
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.62)
	gt.fill_to = Vector2(0.5, 0.0)
	gt.width = 256
	gt.height = 256
	glow.texture = gt
	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(glow)
	# Slow rays behind it in its colour: the pet is the hero of this screen.
	var rays := ColorRect.new()
	rays.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rm0 := ShaderMaterial.new()
	rm0.shader = RAYS
	rm0.set_shader_parameter("tint", col.lerp(Color(1.0, 0.85, 0.55), 0.35))
	rm0.set_shader_parameter("strength", 0.22)
	rays.material = rm0
	# A square, so the rays stay round on a wide stage (the stage clips it).
	rays.set_anchors_preset(Control.PRESET_CENTER)
	rays.offset_left = -h * 0.85
	rays.offset_right = h * 0.85
	rays.offset_top = -h * 0.9
	rays.offset_bottom = h * 0.8
	root.add_child(rays)
	var svc := SubViewportContainer.new()
	svc.stretch = true
	svc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	svc.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(svc)
	var vp := SubViewport.new()
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_2X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	svc.add_child(vp)
	GearStage.light(vp, false)
	# The pedestal: a dark disc with a ring in the pet's colour.
	var rad := maxf(0.95, size * 0.8)
	var disc := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = rad
	cyl.bottom_radius = rad * 1.06
	cyl.height = 0.1
	disc.mesh = cyl
	disc.position.y = -0.05
	var dm := StandardMaterial3D.new()
	dm.albedo_color = Color(0.1, 0.085, 0.09)
	dm.roughness = 0.85
	disc.material_override = dm
	vp.add_child(disc)
	# A rim in the pet's colour: a slightly wider disc peeking out underneath.
	var ring := MeshInstance3D.new()
	var rc := CylinderMesh.new()
	rc.top_radius = rad * 1.07
	rc.bottom_radius = rad * 1.1
	rc.height = 0.07
	ring.mesh = rc
	ring.position.y = -0.06
	var rm := StandardMaterial3D.new()
	rm.albedo_color = col
	rm.emission_enabled = true
	rm.emission = col
	rm.emission_energy_multiplier = 1.6
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.material_override = rm
	vp.add_child(ring)
	var spot := OmniLight3D.new()
	spot.light_color = col.lerp(Color.WHITE, 0.35)
	spot.light_energy = 0.9
	spot.omni_range = size * 4.0
	spot.position = Vector3(0, size * 0.6 + fly, size * 1.4)
	vp.add_child(spot)
	var look := Look.build(id, stage == 2, stage)
	var pivot := Node3D.new()
	pivot.rotation.y = -0.5
	pivot.add_child(look["root"])
	look["root"].position.y = fly * 0.6
	vp.add_child(pivot)
	Look.play(look, "idle")
	# Frame the pet and the whole pedestal: aim between the disc and the pet's
	# middle, from a little above, so a flier never leaves its stand off screen.
	var top := fly * 0.6 + size
	var aim := top * 0.42
	var cam := Camera3D.new()
	cam.fov = 30.0
	vp.add_child(cam)
	var dist := maxf(size * 3.4 + 1.2, top * 2.4 + 1.0)
	cam.look_at_from_position(Vector3(0, aim + dist * 0.28, dist), Vector3(0, aim, 0), Vector3.UP)
	# Drag turns it; a tap makes it perform.
	var st := {"x": 0.0, "moved": 0.0, "spin": 0.0, "down": false}
	svc.gui_input.connect(func(e: InputEvent):
		if e is InputEventScreenTouch or e is InputEventMouseButton:
			var pressed: bool = e.pressed
			if pressed:
				st["down"] = true
				st["moved"] = 0.0
				st["x"] = e.position.x
			elif st["down"]:
				st["down"] = false
				if float(st["moved"]) < 14.0:
					_perform(look, id, pivot)
		elif e is InputEventScreenDrag or (e is InputEventMouseMotion and st["down"]):
			var dx: float = e.position.x - float(st["x"])
			st["x"] = e.position.x
			st["moved"] = float(st["moved"]) + absf(dx)
			pivot.rotation.y += dx * 0.012)
	if hint:
		var hl := Ui.label("Drag to turn · tap to play", "Caption", HORIZONTAL_ALIGNMENT_CENTER)
		hl.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
		hl.offset_top = 8.0
		hl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hl.modulate.a = 0.55
		root.add_child(hl)
	# It drifts around slowly on its own, and the stage fades up on entry.
	var tw := root.create_tween().set_loops()
	tw.tween_property(pivot, "scale", Vector3.ONE * 1.015, 1.6).set_trans(Tween.TRANS_SINE)
	tw.tween_property(pivot, "scale", Vector3.ONE, 1.6).set_trans(Tween.TRANS_SINE)
	root.modulate.a = 0.0
	var fi := root.create_tween()
	fi.tween_property(root, "modulate:a", 1.0, 0.3)
	return root


static func _perform(look: Dictionary, id: String, pivot: Node3D) -> void:
	var which := "special" if Look.has(look, "special") else ("attack" if Look.has(look, "attack") else "")
	Sfx.play("ui_tap", -6.0)
	var t := pivot.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(pivot, "position:y", 0.12, 0.12)
	t.tween_property(pivot, "position:y", 0.0, 0.25).set_trans(Tween.TRANS_BOUNCE)
	if which == "":
		return
	Look.play(look, which)
	await pivot.get_tree().create_timer(1.3).timeout
	if is_instance_valid(pivot):
		Look.play(look, "idle", 0.25)
