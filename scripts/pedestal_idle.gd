class_name PedestalIdle
extends Node3D

## Guaranteed procedural life for the home-screen pedestal hero: a gentle
## vertical bob, a slow turntable sway and a subtle breathing lean, written
## straight onto the hero body's transform each frame. Needs no
## AnimationPlayer, Skeleton3D or model clips, so the hero never reads as a
## statue — even when its idle clip is missing entirely (ember ships none)
## or so shallow at showcase scale that it is invisible (the paladin's baked
## idle shifts its hips by a hair and bends its knees ~2 degrees).
## The node drives its parent body exclusively; the stage's own pedestal
## pose writes were retired for this one.

const REF_METERS := 1.5
const BOB_RISE := 0.04  # total lift of the bob (world units, at REF_METERS)
const BOB_PERIOD := 3.8  # seconds for one rise-and-settle
const SWAY_ARC := 0.35  # rad of the main turntable sweep (about 20 deg)
const SWAY_PERIOD := 12.0
const DRIFT_ARC := 0.07  # slow secondary drift so the turn never repeats exactly
const DRIFT_PERIOD := 9.7
const LEAN_ARC := 0.03  # rad of breathing lean (about 1.7 deg)
const LEAN_PERIOD := 2.9

var _t := 0.0
var _body: Node3D
var _base_y := 0.0
var _base_rot := Vector3.ZERO
var _amp := 1.0


func _ready() -> void:
	_body = get_parent() as Node3D
	if _body == null:
		set_process(false)
		return
	_base_y = _body.position.y
	_base_rot = _body.rotation
	if _body.has_meta("meters"):
		_amp = float(_body.get_meta("meters")) / REF_METERS


func _process(delta: float) -> void:
	if _body == null or not is_instance_valid(_body):
		return
	_t += delta
	# Rise-and-settle: (1 - cos) is flat at the bottom, so the feet lift off
	# the plinth smoothly and never sink below their planted pose.
	var bob := (1.0 - cos(_t * TAU / BOB_PERIOD)) * 0.5 * BOB_RISE * _amp
	# Turntable: one clear sweep plus a lazier drift layered on top.
	var sway := sin(_t * TAU / SWAY_PERIOD) * SWAY_ARC * _amp \
			+ sin(_t * TAU / DRIFT_PERIOD + 1.4) * DRIFT_ARC * _amp
	# Breathing: a lean slightly out of phase with the bob.
	var lean := sin(_t * TAU / LEAN_PERIOD + 0.7) * LEAN_ARC * _amp
	_body.position.y = _base_y + bob
	_body.rotation = Vector3(_base_rot.x + lean * 0.6, _base_rot.y + sway, _base_rot.z + lean)
