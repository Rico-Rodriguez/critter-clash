extends RefCounted
## The hero's animation tree: blended locomotion, a turn-in-place step,
## personality idles, a per-hero victory pose, and the attack one-shots on
## top. Built on any Actor's model, so the hunt, the camp and captures share
## one set of clips. No class_name (over-the-air packs can't register one).
##
##   idle ─ Blend2 ─ loco(walk↔run, one cycle length, one phase) ─ turn ─ quirk
##        ─ upper-body swing ─ full-body swing ─ stage(play | win 1 | win 2 | win 3)

const UPPER_BONES := ["spine", "chest", "upperarm.l", "lowerarm.l", "wrist.l", "hand.l", "handslot.l", "upperarm.r", "lowerarm.r", "wrist.r", "hand.r", "handslot.r", "head"]
const SKEL := "Rig_Medium/Skeleton3D:"
## Walk and run cycles are stretched to the same length so the feet stay in
## phase while one fades into the other.
const CYCLE := 0.9
## Fraction of full speed that the walk clip stands for.
const WALK_AT := 0.4
## Hero-specific clips. quirk: one-shots that play now and then while standing
## still. win: the pose after a boss falls (clip, clip, then the idle holds).
const CFG := {
	"knight": {"walk": "Walking_A", "quirk": ["Melee_Block", "Interact"], "win": ["Interact", "Cheering"]},
	"ranger": {"walk": "Walking_B", "quirk": ["Ranged_Bow_Draw", "Use_Item"], "win": ["Ranged_Bow_Release_Up", "Cheering"]},
	"mage": {"walk": "Walking_C", "quirk": ["Ranged_Magic_Raise", "Use_Item"], "win": ["Ranged_Magic_Summon", "Waving"]},
	"barbarian": {"walk": "Walking_A", "quirk": ["Interact", "Throw"], "win": ["Melee_2H_Attack_Spin", "Cheering"]},
	"rogue": {"walk": "Walking_B", "quirk": ["Melee_Dualwield_Attack_Slice", "Use_Item"], "win": ["Melee_Dualwield_Attack_Slice", "Waving"]},
}
const DEFAULT := {"walk": "Walking_A", "quirk": ["Interact"], "win": ["Cheering", "Waving"]}

var tree: AnimationTree
var actor: Actor
var cfg: Dictionary
var clips: Dictionary
var _up_anim: AnimationNodeAnimation
var _full_anim: AnimationNodeAnimation
var _quirk_anim: AnimationNodeAnimation
var _win: Array[AnimationNodeAnimation] = []
var _loco := 0.0
var _move := 0.0
var _turn := 0.0
var _quirk_t := 0.0
var _quirk_i := 0
var _quirk_busy := 0.0
var _win_t := -1.0
var _win_step := 0
var _model_pitch := 0.0
var _model_roll := 0.0
## Last yaw, to read how fast the body is turning.
var _yaw := 0.0
var _prev_vel := Vector3.ZERO


## Builds the tree on `a`'s model. `anims` is the hero's clip dictionary
## (idle, run, attack list, super).
func attach(a: Actor, anims: Dictionary, hero_id: String) -> void:
	actor = a
	clips = anims
	cfg = CFG.get(hero_id, DEFAULT)
	_quirk_t = randf_range(4.0, 7.0)
	_yaw = a.rotation.y
	tree = AnimationTree.new()
	a.model.add_child(tree)
	tree.anim_player = tree.get_path_to(a.anim)
	var bt := AnimationNodeBlendTree.new()
	# Locomotion: walk and run share one cycle, the space picks the mix.
	var space := AnimationNodeBlendSpace1D.new()
	space.min_space = 0.0
	space.max_space = 1.3
	space.sync = true
	space.add_blend_point(_looped(str(cfg["walk"]), CYCLE), WALK_AT)
	space.add_blend_point(_looped(str(clips["run"]), CYCLE), 1.0)
	bt.add_node("space", space)
	bt.add_node("loco_ts", AnimationNodeTimeScale.new())
	bt.connect_node("loco_ts", 0, "space")
	var idle := AnimationNodeAnimation.new()
	idle.animation = clips["idle"]
	bt.add_node("idle", idle)
	bt.add_node("move", AnimationNodeBlend2.new())
	bt.connect_node("move", 0, "idle")
	bt.connect_node("move", 1, "loco_ts")
	# Turning on the spot: the walk cycle, so the feet step round.
	var turn_a := AnimationNodeAnimation.new()
	turn_a.animation = cfg["walk"]
	bt.add_node("turn_anim", turn_a)
	bt.add_node("turn_ts", AnimationNodeTimeScale.new())
	bt.connect_node("turn_ts", 0, "turn_anim")
	bt.add_node("turn", AnimationNodeBlend2.new())
	bt.connect_node("turn", 0, "move")
	bt.connect_node("turn", 1, "turn_ts")
	# Personality idle: a whole-body one-shot.
	_quirk_anim = AnimationNodeAnimation.new()
	_quirk_anim.animation = (cfg["quirk"] as Array)[0]
	bt.add_node("quirk_anim", _quirk_anim)
	var quirk := AnimationNodeOneShot.new()
	quirk.fadein_time = 0.3
	quirk.fadeout_time = 0.35
	bt.add_node("quirk", quirk)
	bt.connect_node("quirk", 0, "turn")
	bt.connect_node("quirk", 1, "quirk_anim")
	# Swings: upper body while moving, whole body when planted.
	_up_anim = AnimationNodeAnimation.new()
	_up_anim.animation = (clips["attack"] as Array)[0]
	_full_anim = AnimationNodeAnimation.new()
	_full_anim.animation = (clips["attack"] as Array)[0]
	var up := AnimationNodeOneShot.new()
	up.filter_enabled = true
	for b in UPPER_BONES:
		up.set_filter_path(NodePath(SKEL + b), true)
	up.fadein_time = 0.05
	up.fadeout_time = 0.16
	var full := AnimationNodeOneShot.new()
	full.fadein_time = 0.05
	full.fadeout_time = 0.18
	bt.add_node("up_anim", _up_anim)
	bt.add_node("up_ts", AnimationNodeTimeScale.new())
	bt.add_node("up", up)
	bt.add_node("full_anim", _full_anim)
	bt.add_node("full_ts", AnimationNodeTimeScale.new())
	bt.add_node("full", full)
	bt.connect_node("up_ts", 0, "up_anim")
	bt.connect_node("up", 0, "quirk")
	bt.connect_node("up", 1, "up_ts")
	bt.connect_node("full_ts", 0, "full_anim")
	bt.connect_node("full", 0, "up")
	bt.connect_node("full", 1, "full_ts")
	# The victory stage: play, then the pose, then a second beat that loops.
	var stage := AnimationNodeTransition.new()
	stage.input_count = 3
	stage.xfade_time = 0.3
	stage.allow_transition_to_self = false
	bt.add_node("stage", stage)
	bt.connect_node("stage", 0, "full")
	var wins: Array = cfg["win"]
	for i in 2:
		var w := AnimationNodeAnimation.new()
		w.animation = wins[i] if i < wins.size() else clips["idle"]
		if i == 1:
			w.use_custom_timeline = true
			w.timeline_length = actor.anim_length(w.animation)
			w.loop_mode = Animation.LOOP_LINEAR
		_win.append(w)
		bt.add_node("win%d" % i, w)
		bt.connect_node("stage", i + 1, "win%d" % i)
	bt.connect_node("output", 0, "stage")
	tree.tree_root = bt
	tree.active = true


## A looping clip stretched so one cycle takes `cycle` seconds.
func _looped(clip: String, cycle: float) -> AnimationNode:
	var an := AnimationNodeAnimation.new()
	an.animation = clip
	an.use_custom_timeline = true
	an.timeline_length = cycle
	an.stretch_time_scale = true
	an.loop_mode = Animation.LOOP_LINEAR
	return an


## Plays a clip: on the upper body while running, or the whole body.
func act(clip: String, duration: float, whole: bool, moving: bool) -> void:
	var sc := clampf(actor.anim_length(clip) / maxf(duration, 0.05), 0.4, 3.0)
	_quirk_busy = 0.0
	tree.set("parameters/quirk/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_ABORT)
	if whole or not moving:
		tree.set("parameters/up/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_ABORT)
		_full_anim.animation = clip
		tree.set("parameters/full_ts/scale", sc)
		tree.set("parameters/full/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	else:
		_up_anim.animation = clip
		tree.set("parameters/up_ts/scale", sc)
		tree.set("parameters/up/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	_quirk_t = randf_range(4.0, 7.0)


## Swaps the attack clip a weapon family uses (the swing list stays the hero's).
func set_clips(anims: Dictionary) -> void:
	clips = anims


## Feeds the tree each frame. `speed` is the hero's top speed, `vel` its
## velocity, `yaw` where the body faces now.
func tick(dt: float, vel: Vector3, speed: float, yaw: float, fighting: bool) -> void:
	var moving := vel.length()
	var u := clampf(moving / maxf(speed, 0.1), 0.0, 1.3)
	# Eased, so a stop or start never pops between idle and the cycle.
	_loco = lerpf(_loco, u, 1.0 - exp(-12.0 * dt))
	_move = move_toward(_move, smoothstep(0.04, 0.3, u), 7.0 * dt)
	tree.set("parameters/space/blend_position", maxf(_loco, 0.0))
	tree.set("parameters/move/blend_amount", _move)
	# Cadence: a walk steps 0.94 times a second, a full run 1.25 (CYCLE is 0.9 s).
	var walk_s := 0.85 * clampf(_loco / WALK_AT, 0.6, 1.0)
	var run_s := 1.125 * maxf(1.0, _loco)
	tree.set("parameters/loco_ts/scale", lerpf(walk_s, run_s, smoothstep(WALK_AT, 1.0, _loco)))
	# Turn on the spot: how fast the body swings round when not moving.
	var dyaw := wrapf(yaw - _yaw, -PI, PI)
	_yaw = yaw
	var rate := absf(dyaw) / maxf(dt, 0.001)
	var turning := smoothstep(1.2, 4.0, rate) * (1.0 - smoothstep(0.1, 0.35, u))
	_turn = move_toward(_turn, turning, (5.0 if turning > _turn else 7.0) * dt)
	tree.set("parameters/turn/blend_amount", _turn * 0.9)
	tree.set("parameters/turn_ts/scale", clampf(rate / 5.0, 0.7, 2.0) * 0.9)
	# Personality: while standing at ease, an idle fidget now and then.
	if _quirk_busy > 0.0:
		_quirk_busy -= dt
	if moving < 0.3 and not fighting and _win_t < 0.0 and _quirk_busy <= 0.0:
		_quirk_t -= dt
		if _quirk_t <= 0.0:
			quirk()
	elif moving >= 0.3 or fighting:
		_quirk_t = maxf(_quirk_t, randf_range(3.0, 5.0))
	# Body language: lean into acceleration and bank through turns.
	var acc := (vel - _prev_vel) / maxf(dt, 0.001)
	_prev_vel = vel
	var local_acc := Vector3(acc.x, 0, acc.z).rotated(Vector3.UP, -yaw)
	var want_pitch := clampf(u * 0.1 + local_acc.z * 0.004, -0.12, 0.2)
	var want_roll := clampf(-dyaw / maxf(dt, 0.001) * 0.012 * u, -0.14, 0.14)
	_model_pitch = lerpf(_model_pitch, want_pitch, 1.0 - exp(-10.0 * dt))
	_model_roll = lerpf(_model_roll, want_roll, 1.0 - exp(-8.0 * dt))
	if _win_t < 0.0:
		actor.model.rotation = Vector3(_model_pitch, 0.0, _model_roll)
	# Victory beats chain on a timer.
	if _win_t >= 0.0:
		_win_t -= dt
		if _win_t <= 0.0 and _win_step < 1:
			_win_step += 1
			_go_win()


## A fidget: one of the hero's quirk clips, whole body, eased in and out.
func quirk() -> void:
	var list: Array = cfg["quirk"]
	var clip: String = list[_quirk_i % list.size()]
	_quirk_i += 1
	_quirk_anim.animation = clip
	tree.set("parameters/quirk/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	_quirk_busy = actor.anim_length(clip) + 0.4
	_quirk_t = randf_range(6.0, 10.0)


## The boss is down: this hero's own pose, two beats, then a held idle.
func victory() -> void:
	_win_step = 0
	tree.set("parameters/quirk/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_ABORT)
	_go_win()


func _go_win() -> void:
	tree.set("parameters/stage/transition_request", "state_%d" % (_win_step + 1))
	if _win_step < 1:
		var clip: String = _win[_win_step].animation
		_win_t = maxf(actor.anim_length(clip) - 0.25, 0.4)
	else:
		_win_t = 9999.0


## Back to play (a new boss, or the hero is revived).
func end_victory() -> void:
	_win_t = -1.0
	tree.set("parameters/stage/transition_request", "state_0")


func is_winning() -> bool:
	return _win_t >= 0.0
