extends Node
## Not a class_name (see item_icons.gd). A hero wearing an outfit or carrying a
## weapon skin, rendered once per hero and look, off screen and one per frame,
## then cached for the session. Until it is ready (and on headless runs) the
## flat icon stands in. `look` is {"outfit": key} or {"skin": key}.

const SIZE := 256

static var _cache := {}
static var _inst: Node

var _vp: SubViewport
var _queue: Array = []
var _waiting := {}
var _busy := false


static func rect(hero_id: String, look: Dictionary, size_: float, flat: String, flat_tint: Color) -> TextureRect:
	var t := Ui.icon_rect(flat, size_, flat_tint)
	if DisplayServer.get_name() == "headless":
		return t
	var k := "%s|%s|%s" % [hero_id, look.get("outfit", ""), look.get("skin", "")]
	if _cache.has(k):
		_show(t, _cache[k])
		return t
	_instance().request(hero_id, look, k, t)
	return t


static func _show(t: TextureRect, tex: Texture2D) -> void:
	t.texture = tex
	t.modulate = Color.WHITE
	t.self_modulate = Color.WHITE


static func _instance():
	if _inst == null or not is_instance_valid(_inst):
		_inst = load("res://src/ui/look_icons.gd").new()
		(Engine.get_main_loop() as SceneTree).root.add_child.call_deferred(_inst)
	return _inst


func request(hero_id: String, look: Dictionary, k: String, t: TextureRect) -> void:
	if not _waiting.has(k):
		_waiting[k] = []
		_queue.append([hero_id, look.duplicate(), k])
	_waiting[k].append(weakref(t))


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_vp = SubViewport.new()
	_vp.size = Vector2i(SIZE, SIZE)
	_vp.transparent_bg = true
	_vp.own_world_3d = true
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_vp)


## Trims the empty margin to a padded square, so a tiny skeleton and a wide
## dragon both fill their tile.
static func _crop(img: Image) -> Image:
	var r := img.get_used_rect()
	if r.size.x < 4 or r.size.y < 4:
		return img
	var side := int(maxi(r.size.x, r.size.y) * 1.08) + 2
	var c := r.get_center()
	var x := clampi(c.x - side / 2, 0, maxi(img.get_width() - side, 0))
	var y := clampi(c.y - side / 2, 0, maxi(img.get_height() - side, 0))
	var out := img.get_region(Rect2i(x, y, mini(side, img.get_width() - x), mini(side, img.get_height() - y)))
	return out


func _process(_dt: float) -> void:
	if not _busy and not _queue.is_empty():
		_render(_queue.pop_front())


func _render(job: Array) -> void:
	_busy = true
	var hero_id: String = job[0]
	var look: Dictionary = job[1]
	var k: String = job[2]
	Ui.clear(_vp)
	GearStage.light(_vp, false)
	var d: Dictionary = DB.HEROES[hero_id]
	var hero := Actor.new()
	_vp.add_child(hero)
	hero.adult_build = true
	hero.build_model(d["model"], {}, Color(0.55, 0.68, 1.0), 0.5)
	GearLook.look_override = look
	GearLook.apply(hero, hero_id)
	GearLook.look_override = {}
	hero.rotation.y = 0.45
	hero.play(d["anim"]["idle"], 0.0)
	var cam := Camera3D.new()
	cam.fov = 30.0
	_vp.add_child(cam)
	cam.look_at_from_position(Vector3(0.8, 1.35, 4.6), Vector3(0, 0.95, 0), Vector3.UP)
	# One frame for the pose to apply, one for the draw.
	_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	var img := _vp.get_texture().get_image()
	if img != null and not img.is_empty():
		var tex := ImageTexture.create_from_image(_crop(img))
		_cache[k] = tex
		for w in _waiting.get(k, []):
			var t = w.get_ref()
			if t != null:
				_show(t, tex)
	_waiting.erase(k)
	Ui.clear(_vp)
	_busy = false
