class_name ItemIcons
extends Node
## Gear icons rendered from the piece's own 3D model, so a Crystal Staff looks
## like that staff and not like every other staff. Each look is rendered once,
## off screen, one per frame, and cached for the session; until it is ready
## (and on headless runs) the flat icon stands in.

const SIZE := 160

static var _cache := {}
static var _inst: ItemIcons

var _vp: SubViewport
var _queue: Array = []
var _waiting := {}
var _busy := false


## A TextureRect showing `it`: the flat icon now, its render when ready.
static func rect(it: Dictionary, size_: float, flat_tint: Color) -> TextureRect:
	var t := Ui.icon_rect(GearDB.item_icon(it), size_, flat_tint)
	if DisplayServer.get_name() == "headless" or not it.has("cls") or not (str(it["slot"]) in DB.SLOTS):
		return t
	var k := key(it)
	if _cache.has(k):
		_show(t, _cache[k])
		return t
	_instance().request(it, k, t)
	return t


## Two pieces that would render the same share a key.
static func key(it: Dictionary) -> String:
	return "%s|%s|%d|%s|%s|%s" % [it["cls"], it["slot"], int(it.get("mat", 0)), str(it.get("unique", "")), GearDB.set_of(it), str(GearDB.piece(it))]


static func _show(t: TextureRect, tex: Texture2D) -> void:
	t.texture = tex
	t.modulate = Color.WHITE


static func _instance() -> ItemIcons:
	if _inst == null or not is_instance_valid(_inst):
		_inst = ItemIcons.new()
		(Engine.get_main_loop() as SceneTree).root.add_child.call_deferred(_inst)
	return _inst


func request(it: Dictionary, k: String, t: TextureRect) -> void:
	if not _waiting.has(k):
		_waiting[k] = []
		_queue.append([it.duplicate(true), k])
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


func _process(_dt: float) -> void:
	if not _busy and not _queue.is_empty():
		_render(_queue.pop_front())


func _render(job: Array) -> void:
	_busy = true
	var it: Dictionary = job[0]
	var k: String = job[1]
	Ui.clear(_vp)
	GearStage.light(_vp, false)
	var pivot := Node3D.new()
	pivot.rotation.y = 0.6
	_vp.add_child(pivot)
	var cam := Camera3D.new()
	cam.fov = 30.0
	_vp.add_child(cam)
	# Body armor is framed tighter so the piece, not the hero, fills the icon.
	var slot := str(it["slot"])
	GearStage.show_piece(pivot, cam, it, false, 0.36 if slot in ["chest", "legs"] else 0.62)
	if slot == "chest":
		# The big chibi head sits right above the chest: look a little lower.
		cam.position.y -= 0.22
	_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	# One frame for the pose to apply, one for the draw.
	await RenderingServer.frame_post_draw
	_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	var img := _vp.get_texture().get_image()
	if img != null and not img.is_empty():
		var tex := ImageTexture.create_from_image(img)
		_cache[k] = tex
		for w in _waiting.get(k, []):
			var t = w.get_ref()
			if t != null:
				_show(t, tex)
	_waiting.erase(k)
	Ui.clear(_vp)
	_busy = false
