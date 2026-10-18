class_name BladeTrail
extends MeshInstance3D

## An additive ribbon swept by the blade (T3 weapons). Each frame it samples
## the blade's base and tip in world space; fast swings leave a bright arc
## that fades over ~0.18 s, an idle blade leaves nothing.

var blade: Node3D
var base_local := Vector3.ZERO
var tip_local := Vector3.ZERO
var color := Color(1.0, 0.4, 0.1)
var life := 0.18
var _pts: Array = []  # [base, tip, time]
var _im := ImmediateMesh.new()

const SHADER := """shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;
uniform vec4 tint : source_color = vec4(1.0, 0.4, 0.1, 1.0);
void fragment() {
	float a = COLOR.a;
	float edge = smoothstep(0.0, 0.35, UV.y) * (0.35 + 0.65 * UV.y);
	ALBEDO = tint.rgb * 2.6 * a * a * edge;
}
"""


func _ready() -> void:
	top_level = true
	mesh = _im
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var sh := Shader.new()
	sh.code = SHADER
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("tint", color)
	material_override = mat
	global_transform = Transform3D.IDENTITY


## Measures the blade mesh: its long axis from hilt to tip.
func bind(holder: Node3D, c: Color) -> void:
	color = c
	var mi: MeshInstance3D = null
	for n in holder.find_children("*", "MeshInstance3D", true, false):
		mi = n
		break
	if mi == null:
		return
	blade = mi
	var box := mi.mesh.get_aabb()
	var ax := 0
	if box.size.y > box.size[ax]:
		ax = 1
	if box.size.z > box.size[ax]:
		ax = 2
	var c0 := box.get_center()
	var lo := c0
	var hi := c0
	lo[ax] = box.position[ax] + box.size[ax] * 0.3
	hi[ax] = box.position[ax] + box.size[ax]
	# The tip is the end farthest from the hand (holder origin).
	var o := mi.global_transform.affine_inverse() * holder.global_position
	if (lo - o).length() > (hi - o).length():
		lo[ax] = box.position[ax] + box.size[ax] * 0.7
		hi[ax] = box.position[ax]
	base_local = lo
	tip_local = hi


func _process(_delta: float) -> void:
	if not is_instance_valid(blade) or not blade.is_visible_in_tree():
		_im.clear_surfaces()
		return
	var now := Time.get_ticks_msec() * 0.001
	var xf := blade.global_transform
	_pts.push_front([xf * base_local, xf * tip_local, now])
	while _pts.size() > 2 and now - float(_pts[-1][2]) > life:
		_pts.pop_back()
	_im.clear_surfaces()
	if _pts.size() < 3:
		return
	# Skip when the blade barely moves: no smear on idle.
	var sweep := ((_pts[0][1] as Vector3) - (_pts[-1][1] as Vector3)).length()
	var span := ((_pts[0][1] as Vector3) - (_pts[0][0] as Vector3)).length()
	if sweep < span * 0.35:
		return
	_im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in _pts.size():
		var p: Array = _pts[i]
		var a := clampf(1.0 - (now - float(p[2])) / life, 0.0, 1.0)
		_im.surface_set_color(Color(1, 1, 1, a))
		_im.surface_set_uv(Vector2(float(i) / _pts.size(), 0.0))
		_im.surface_add_vertex(p[0])
		_im.surface_set_color(Color(1, 1, 1, a))
		_im.surface_set_uv(Vector2(float(i) / _pts.size(), 1.0))
		_im.surface_add_vertex(p[1])
	_im.surface_end()
