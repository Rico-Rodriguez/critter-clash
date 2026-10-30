extends RefCounted
## The shop's "try it on": the hero drawn in a small studio wearing an outfit or carrying a
## weapon skin they do not own yet. Software GPUs and the headless checks get no image, so
## callers keep a flat icon until it exists.



## A TextureRect that fills with the render once the frame is drawn. `look` is
## {"outfit": key} or {"skin": key}; anything else the hero wears stays as it is.
static func make(hero_id: String, look: Dictionary, size := Vector2(300, 360)) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = size
	if DisplayServer.get_name() == "headless":
		return holder
	var vp := SubViewport.new()
	vp.size = Vector2i(size)
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	GearStage.light(vp)
	var d: Dictionary = DB.HEROES[hero_id]
	var hero := Actor.new()
	vp.add_child(hero)
	hero.adult_build = true
	hero.build_model(d["model"], {}, Color(0.55, 0.68, 1.0), 0.5)
	GearLook.look_override = look
	GearLook.apply(hero, hero_id)
	GearLook.look_override = {}
	hero.rotation.y = 0.45
	hero.play(d["anim"]["idle"], 0.0)
	var cam := Camera3D.new()
	cam.fov = 30.0
	vp.add_child(cam)
	cam.look_at_from_position(Vector3(0.8, 1.35, 4.6), Vector3(0, 0.95, 0), Vector3.UP)
	holder.add_child(vp)
	var tr := TextureRect.new()
	tr.texture = vp.get_texture()
	tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	holder.add_child(tr)
	return holder
