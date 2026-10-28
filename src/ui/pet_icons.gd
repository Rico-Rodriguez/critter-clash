extends Node
## Not a class_name (see item_icons.gd). A pet's portrait rendered from its own
## 3D model, once per pet and growth stage, off screen and one per frame, then
## cached for the session. Until it is ready (and on headless runs) the pet's
## flat icon stands in.

const SDB := preload("res://src/data/sidekick_db.gd")
const Look := preload("res://src/core/sidekick_look.gd")
const SIZE := 256

static var _cache := {}
static var _inst: Node

var _vp: SubViewport
var _queue: Array = []
var _waiting := {}
var _busy := false


## A TextureRect showing pet `id` at growth `stage` (0 baby, 1 grown, 2 evolved).
static func rect(id: String, stage: int, size_: float) -> TextureRect:
	var d: Dictionary = SDB.def(id)
	var t := Ui.icon_rect(str(d["icon"]), size_, Color(d["color"]))
	if DisplayServer.get_name() == "headless":
		return t
	var k := "%s|%d" % [id, stage]
	if _cache.has(k):
		_show(t, _cache[k])
		return t
	_instance().request(id, stage, k, t)
	return t


static func _show(t: TextureRect, tex: Texture2D) -> void:
	t.texture = tex
	t.modulate = Color.WHITE
	t.self_modulate = Color.WHITE


static func _instance():
	if _inst == null or not is_instance_valid(_inst):
		_inst = load("res://src/ui/pet_icons.gd").new()
		(Engine.get_main_loop() as SceneTree).root.add_child.call_deferred(_inst)
	return _inst


func request(id: String, stage: int, k: String, t: TextureRect) -> void:
	if not _waiting.has(k):
		_waiting[k] = []
		_queue.append([id, stage, k])
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
	var id: String = job[0]
	var stage: int = job[1]
	var k: String = job[2]
	Ui.clear(_vp)
	GearStage.light(_vp, false)
	var d: Dictionary = SDB.def(id)
	var size := maxf(float(d["scale"]) * float(SDB.STAGE_SCALE[stage]), 0.55)
	var fly := float(d.get("fly", 0.0))
	var look := Look.build(id, stage == 2, stage)
	var pivot := Node3D.new()
	pivot.rotation.y = -0.5
	pivot.add_child(look["root"])
	look["root"].position.y = fly * 0.6
	_vp.add_child(pivot)
	Look.play(look, "idle")
	var mid := size * 0.5 + fly * 0.5
	var cam := Camera3D.new()
	cam.fov = 30.0
	_vp.add_child(cam)
	# Close on a small ground pet, wider for a flier whose wings spread.
	var dist := size * 3.1 + 1.0 if fly > 0.0 else size * 2.6 + 0.35
	cam.look_at_from_position(Vector3(0, mid + size * 0.2, dist), Vector3(0, mid, 0), Vector3.UP)
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
