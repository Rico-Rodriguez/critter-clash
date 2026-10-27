class_name HuntCam
extends Camera3D
## Hunt camera: orbits the focus point at a fixed pitch and distance, keeps the
## hero slightly below screen center, leads in the direction of travel and
## shakes on trauma. Every number is a var so the dev panel can tune it live.

var pitch_deg := 50.0     # angle above the ground (90 = straight down)
var distance := 19.5      # metres from focus to camera
var fov_w := 40.0         # horizontal FOV; portrait keeps width
var anchor := 0.57        # hero's screen height: 0 top, 0.5 center, 1 bottom
var lookahead := 0.35     # seconds of velocity to lead by
var lead_max := 2.6       # metres
var follow_rate := 7.0
var dist_mult := 1.0      # player preset: Close 0.86, Standard 1.0, Wide 1.16
var zoom := 1.0           # dynamic, eased toward zoom_target
var zoom_target := 1.0
var pitch_shift := 0.0    # degrees added to pitch_deg (the boss entrance drops the camera low)
var punch := 0.0          # a quick push in that eases out (supers, big drops); negative pulls back

var target: Node3D
var focus_override: Variant = null
var trauma := 0.0
var shake_enabled := true
var _focus := Vector3.ZERO
var _lead := Vector3.ZERO
var _t := 0.0
var _noise := FastNoiseLite.new()


func _ready() -> void:
	keep_aspect = Camera3D.KEEP_WIDTH
	near = 0.5
	far = 140.0
	_noise.frequency = 2.2


func snap() -> void:
	if target:
		_focus = Vector3(target.global_position.x, 0, target.global_position.z)
		_apply(0.0)


func follow(dt: float, vel: Vector3) -> void:
	if target == null:
		return
	_t += dt
	var want_lead := Vector3(vel.x, 0, vel.z) * lookahead
	_lead = _lead.lerp(want_lead.limit_length(lead_max), 1.0 - exp(-3.0 * dt))
	var f: Vector3 = target.global_position + _lead
	if focus_override != null:
		f = focus_override
	f.y = 0.0
	_focus = _focus.lerp(f, 1.0 - exp(-follow_rate * dt))
	zoom = lerpf(zoom, zoom_target, 1.0 - exp(-2.5 * dt))
	trauma = maxf(trauma - dt * 1.6, 0.0)
	punch = move_toward(punch, 0.0, dt * 0.45)
	_apply(trauma * trauma if shake_enabled else 0.0)


## Recomputed from scratch every frame, so shake never accumulates.
func _apply(shake: float) -> void:
	fov = fov_w
	var p := deg_to_rad(clampf(pitch_deg + pitch_shift, 25.0, 80.0))
	var d := distance * dist_mult * zoom * (1.0 - punch)
	global_position = _focus + Vector3(0, sin(p), cos(p)) * d
	look_at(_focus, Vector3.UP)
	# Tilt so the focus sits at `anchor` instead of the center.
	var vp := get_viewport().get_visible_rect().size
	var aspect := vp.x / maxf(vp.y, 1.0)
	var half_v := atan(tan(deg_to_rad(fov_w) * 0.5) / aspect)
	rotate_object_local(Vector3.RIGHT, atan((anchor - 0.5) * 2.0 * tan(half_v)))
	if shake > 0.0:
		rotate_object_local(Vector3.RIGHT, _noise.get_noise_2d(_t * 40.0, 0.0) * 0.05 * shake)
		rotate_object_local(Vector3.UP, _noise.get_noise_2d(0.0, _t * 40.0) * 0.05 * shake)
		global_position += Vector3(_noise.get_noise_2d(_t * 30.0, 7.0), 0, _noise.get_noise_2d(7.0, _t * 30.0)) * 0.6 * shake


func add_trauma(v: float) -> void:
	trauma = clampf(trauma + v, 0.0, 1.0)
