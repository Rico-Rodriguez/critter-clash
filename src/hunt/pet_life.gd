extends RefCounted
## The companion's body language, layered on its rig clips and the motor's
## pose (sidekick.gd): a pop-in on arrival, idle fidgets (look round, hop,
## stretch, shake), a wary crouch while a boss wakes, a victory dance and a
## droop in defeat. Every move is a pure function of time that starts and ends
## at the neutral pose, so layers never pop.
##
## A pose is {y, pitch, yaw, roll, sy, s}: lift (m), tilt forward, turn, side
## lean, vertical squash (1 = none) and overall size (1 = none).

const FIDGETS := ["look", "hop", "stretch", "shake"]
const FIDGET_TIME := {"look": 1.6, "hop": 0.7, "stretch": 1.3, "shake": 0.8}
const BORN_TIME := 0.55


static func neutral() -> Dictionary:
	return {"y": 0.0, "pitch": 0.0, "yaw": 0.0, "roll": 0.0, "sy": 1.0, "s": 1.0}


static func new_life(seed_: int) -> Dictionary:
	return {"age": 0.0, "idle_t": 0.0, "next": 3.0 + float(seed_ % 5), "kind": "", "kind_t": 0.0, "n": seed_ % FIDGETS.size(), "beat": 0.0, "cheer_start": 0.2 + float(seed_ % 7) * 0.07}


## Arrival: grows from a point with an overshoot, and a little hop.
static func born(t: float) -> Dictionary:
	var o := neutral()
	var u := clampf(t / BORN_TIME, 0.0, 1.0)
	if u >= 1.0:
		return o
	# easeOutBack on the whole size.
	var c1 := 2.2
	var k := 1.0 + (c1 + 1.0) * pow(u - 1.0, 3.0) + c1 * pow(u - 1.0, 2.0)
	o["s"] = maxf(k, 0.02)
	o["y"] = 0.35 * sin(u * PI) * (1.0 - u)
	o["yaw"] = TAU * 0.5 * (1.0 - u) * (1.0 - u)
	return o


## One idle fidget at u in 0..1; zero at both ends.
static func fidget(kind: String, u: float) -> Dictionary:
	var o := neutral()
	var w := sin(clampf(u, 0.0, 1.0) * PI)
	match kind:
		"look":
			# A glance left, a glance right, back to centre.
			o["yaw"] = sin(u * TAU) * 0.7 * w
			o["pitch"] = -0.08 * w
		"hop":
			o["y"] = 0.28 * sin(clampf(u, 0.0, 1.0) * PI)
			o["sy"] = 1.0 + 0.1 * w
		"stretch":
			# Reach up and back, then settle.
			o["sy"] = 1.0 + 0.14 * w
			o["pitch"] = -0.3 * w
		"shake":
			o["roll"] = sin(u * 26.0) * 0.14 * w
			o["yaw"] = sin(u * 22.0 + 1.0) * 0.12 * w
	return o


## Boss waking: it flattens a little, leans back and trembles.
static func wary(t: float, k: float) -> Dictionary:
	var o := neutral()
	o["sy"] = 1.0 - 0.1 * k
	o["pitch"] = -0.16 * k
	o["roll"] = sin(t * 38.0) * 0.03 * k
	return o


## Victory dance: hops in a steady beat, a spin on every third.
static func cheer(t: float, k: float) -> Dictionary:
	var o := neutral()
	var beat := t * 2.4
	var u := fmod(beat, 1.0)
	var n := int(beat)
	o["y"] = 0.42 * sin(u * PI) * k
	o["sy"] = 1.0 + (0.1 * sin(u * PI) - 0.14 * pow(1.0 - u, 8.0) * float(n > 0)) * k
	o["yaw"] = TAU * ease(u, -1.8) * k if n % 3 == 2 else 0.0
	o["pitch"] = -0.12 * sin(u * PI) * k
	return o


## Beaten: sinks, head down.
static func droop(k: float) -> Dictionary:
	var o := neutral()
	o["sy"] = 1.0 - 0.14 * k
	o["pitch"] = 0.22 * k
	return o


static func add(a: Dictionary, b: Dictionary) -> Dictionary:
	return {"y": float(a["y"]) + float(b["y"]), "pitch": float(a["pitch"]) + float(b["pitch"]), "yaw": float(a["yaw"]) + float(b["yaw"]), "roll": float(a["roll"]) + float(b["roll"]), "sy": float(a["sy"]) * float(b["sy"]), "s": float(a["s"]) * float(b["s"])}


## Advances the life state and returns this frame's pose layer. `idle`: it is
## standing at ease; `mood`: "", "wary", "cheer" or "droop" from the hunt phase.
static func step(life: Dictionary, dt: float, idle: bool, mood: String) -> Dictionary:
	life["age"] = float(life["age"]) + dt
	var out := born(float(life["age"]))
	# Each mood fades in and out, so a phase change never snaps the body.
	var any_mood := false
	for m in ["wary", "cheer", "droop"]:
		var key: String = "k_" + m
		life[key] = move_toward(float(life.get(key, 0.0)), 1.0 if mood == m else 0.0, dt * 4.0)
		if float(life[key]) <= 0.0:
			continue
		any_mood = true
		match m:
			"wary":
				out = add(out, wary(float(life["age"]), float(life[key])))
			"droop":
				out = add(out, droop(float(life[key])))
			"cheer":
				life["beat"] = float(life["beat"]) + dt
				var t: float = float(life["beat"]) - float(life["cheer_start"])
				out = add(out, cheer(maxf(t, 0.0), float(life[key]) if t > 0.0 else 0.0))
	if not any_mood:
		life["beat"] = 0.0
	if idle and not any_mood:
		life["idle_t"] = float(life["idle_t"]) + dt
		if life["kind"] == "" and float(life["idle_t"]) >= float(life["next"]):
			life["kind"] = FIDGETS[int(life["n"]) % FIDGETS.size()]
			life["n"] = int(life["n"]) + 1
			life["kind_t"] = 0.0
	else:
		life["idle_t"] = 0.0
	# A fidget already under way always plays out, so it never pops off.
	if life["kind"] != "":
		life["kind_t"] = float(life["kind_t"]) + dt
		var dur: float = FIDGET_TIME[life["kind"]]
		var u := float(life["kind_t"]) / dur
		if u >= 1.0:
			life["kind"] = ""
			life["idle_t"] = 0.0
			life["next"] = randf_range(4.0, 8.0)
		else:
			out = add(out, fidget(str(life["kind"]), u))
	return out
