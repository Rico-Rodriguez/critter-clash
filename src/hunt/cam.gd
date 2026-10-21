class_name HuntCam
extends Camera3D
## Top-down follow camera at about 58 degrees. Leads a little in the
## direction of travel, eases instead of snapping, and shakes on trauma
## (shake = trauma squared, so small hits stay small).

var target: Node3D
var offset := Vector3(0, 14.6, 9.0)
var look_bias := Vector3(0, 0.0, -1.2)
var lead := Vector3.ZERO
var trauma := 0.0
var shake_enabled := true
var focus_override: Variant = null
var zoom := 1.0
var _t := 0.0
var _noise := FastNoiseLite.new()


func _ready() -> void:
	keep_aspect = Camera3D.KEEP_WIDTH
	fov = 42.0
	near = 0.5
	far = 120.0
	_noise.frequency = 2.2


func snap() -> void:
	if target:
		var f := target.global_position
		global_position = f + offset * zoom
		look_at(f + look_bias, Vector3.UP)


func follow(dt: float, vel: Vector3) -> void:
	if target == null:
		return
	_t += dt
	lead = lead.lerp(vel * 0.28, 1.0 - exp(-3.0 * dt))
	var focus: Vector3 = target.global_position + lead
	if focus_override != null:
		focus = focus_override
	focus.y = 0.0
	var want := focus + offset * zoom
	global_position = global_position.lerp(want, 1.0 - exp(-7.0 * dt))
	var look := global_position - offset * zoom + look_bias
	look_at(look, Vector3.UP)
	trauma = maxf(trauma - dt * 1.6, 0.0)
	if shake_enabled and trauma > 0.0:
		var s := trauma * trauma
		rotate_object_local(Vector3.RIGHT, _noise.get_noise_2d(_t * 40.0, 0.0) * 0.05 * s)
		rotate_object_local(Vector3.UP, _noise.get_noise_2d(0.0, _t * 40.0) * 0.05 * s)
		global_position += Vector3(_noise.get_noise_2d(_t * 30.0, 7.0), 0, _noise.get_noise_2d(7.0, _t * 30.0)) * 0.6 * s


func add_trauma(v: float) -> void:
	trauma = clampf(trauma + v, 0.0, 1.0)
