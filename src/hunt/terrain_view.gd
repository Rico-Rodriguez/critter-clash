extends RefCounted
## What the terrain cell grid looks like: two small textures (one pixel per
## 2 m cell) that src/fx/terrain_ground.gdshader reads, and the one ground
## plane that wears them. The grid itself (terrain.gd) never draws; the arena
## repaints a cell here whenever its kind changes.

const SHADER := preload("res://src/fx/terrain_ground.gdshader")
const T := preload("res://src/hunt/terrain.gd")

var t: RefCounted
var mat: ShaderMaterial
var _a: Image
var _b: Image
var _tex_a: ImageTexture
var _tex_b: ImageTexture
var _dirty := false


func _init(grid: RefCounted) -> void:
	t = grid
	_a = Image.create(t.w, t.h, false, Image.FORMAT_RGBA8)
	_b = Image.create(t.w, t.h, false, Image.FORMAT_RGBA8)
	_tex_a = ImageTexture.create_from_image(_a)
	_tex_b = ImageTexture.create_from_image(_b)


## The ground plane for this grid. `look` overrides shader parameters
## (base colours and so on); `noise` is [noise_a, noise_b].
func make_ground(arena: Arena, noise: Array, look: Dictionary, size: Vector2, center: Vector3) -> MeshInstance3D:
	mat = ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("noise_a", noise[0])
	mat.set_shader_parameter("noise_b", noise[1])
	mat.set_shader_parameter("lay_a", _tex_a)
	mat.set_shader_parameter("lay_b", _tex_b)
	mat.set_shader_parameter("cell_rect", Vector4(t.origin.x, t.origin.y, t.w * T.CELL, t.h * T.CELL))
	mat.set_shader_parameter("bounds", Vector4(arena.min_x - 1.0, arena.min_z - 1.0, arena.max_x + 1.0, arena.max_z + 1.0))
	for k: String in look:
		mat.set_shader_parameter(k, look[k])
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = size
	mi.mesh = pm
	mi.position = center
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	arena.add_child(mi)
	paint_all()
	return mi


func paint_all() -> void:
	for z in t.h:
		for x in t.w:
			_paint(Vector2i(x, z))
	flush()


## Repaints one cell from the grid (kind, fuse and warning).
func paint(c: Vector2i) -> void:
	if t.in_bounds(c):
		_paint(c)


func _paint(c: Vector2i) -> void:
	var k: int = t.kind_of(c)
	var i: int = t.idx(c)
	var ice := 1.0 if k in [T.ICE, T.THIN_ICE, T.WALL_ICE] else 0.0
	var thin := 1.0 if k == T.THIN_ICE else 0.0
	var water := 1.0 if k == T.WATER else 0.0
	var bog := 1.0 if k in [T.BOG, T.PLANK, T.BURNING, T.ASH] else 0.0
	var burn := 1.0 if k == T.BURNING else 0.0
	var ash := 1.0 if k == T.ASH else 0.0
	var fuse := 0.0
	var fresh := 0.0
	if k == T.THIN_ICE and float(t.timer[i]) > 0.0:
		fuse = 1.0 - float(t.timer[i]) / T.SNAP_DELAY
	elif float(t.warn[i]) > 0.0:
		fuse = 1.0 - float(t.warn[i]) / T.STEP
	if k == T.ASH:
		fresh = clampf(float(t.timer[i]) / T.ASH_TIME, 0.0, 1.0)
	_a.set_pixel(c.x, c.y, Color(ice, thin, water, bog))
	_b.set_pixel(c.x, c.y, Color(burn, ash, clampf(fuse, 0.0, 1.0), fresh))
	_dirty = true


func flush() -> void:
	if _dirty:
		_tex_a.update(_a)
		_tex_b.update(_b)
		_dirty = false
