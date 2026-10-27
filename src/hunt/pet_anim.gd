extends RefCounted
## The pet's body language for a move, in the classic three beats: an
## anticipation (it gathers itself: crouch, rear back, wind up), the strike
## on the hit frame (fast, stretched), then a damped follow-through that
## overshoots and settles instead of stopping dead. Every pose is a pure
## function of time since the move began, so it blends with the rig's clips
## and with the motor's locomotion, and it goes on past the move's end.
##
## A pose is {y, z, pitch, spin, roll, sy}: lift (m), shove forward (m), tilt
## forward (rad), turn (rad), side lean (rad) and vertical squash (1 = none).
## Preloaded by path (no class_name: OTA packs).

## Which beat a move uses, by ability kind.
const STYLE_OF := {
	"breath": "rear", "mend": "float", "hex": "float", "thorns": "stomp", "snare": "stomp",
	"storm": "shiver", "bone_toss": "toss", "snap": "lunge", "leech": "dive", "bash": "slam",
	"shadowstrike": "dash",
}
## Anticipation (a) and strike (s) offsets from neutral. `sy` is a delta.
const STYLES := {
	"lunge": {"a": {"z": -0.28, "pitch": -0.30, "sy": -0.2}, "s": {"z": 0.70, "pitch": 0.50, "sy": 0.2, "y": 0.05}},
	"rear": {"a": {"z": -0.15, "pitch": -0.38, "sy": 0.12, "y": 0.18}, "s": {"z": 0.28, "pitch": 0.30, "sy": -0.12}},
	"float": {"a": {"y": 0.30, "sy": 0.10, "spin": 0.7}, "s": {"y": 0.20, "sy": -0.08, "spin": -0.3}},
	"stomp": {"a": {"y": 0.34, "sy": 0.16, "pitch": -0.14}, "s": {"y": -0.04, "sy": -0.26, "pitch": 0.2}},
	"shiver": {"a": {"y": 0.10, "sy": 0.12}, "s": {"pitch": -0.22, "sy": 0.16, "y": 0.1}},
	"toss": {"a": {"spin": 0.65, "roll": -0.22, "z": -0.1, "sy": -0.06}, "s": {"spin": -0.5, "roll": 0.26, "pitch": 0.22, "z": 0.2}},
	"dive": {"a": {"y": 0.28, "pitch": -0.35, "sy": 0.1}, "s": {"y": -0.05, "z": 0.55, "pitch": 0.75, "sy": 0.06}},
	"slam": {"a": {"y": 0.36, "pitch": -0.55, "sy": 0.2}, "s": {"y": -0.06, "z": 0.3, "pitch": 0.55, "sy": -0.3}},
	"dash": {"a": {"z": -0.35, "pitch": -0.22, "sy": -0.24}, "s": {"z": 0.95, "pitch": 0.42, "sy": 0.22}},
}
const KEYS := ["y", "z", "pitch", "spin", "roll", "sy"]
## How long a move's pose lives after the hit frame (s).
const TAIL := 0.8


static func neutral() -> Dictionary:
	return {"y": 0.0, "z": 0.0, "pitch": 0.0, "spin": 0.0, "roll": 0.0, "sy": 1.0}


static func style_for(kind: String) -> String:
	return str(STYLE_OF.get(kind, "lunge"))


## The strike's shape over u (seconds since the hit frame): out fast to 1,
## then a damped swing through zero that rings down.
static func swing(u: float) -> float:
	const PEAK := 0.14
	if u < 0.0:
		return 0.0
	if u < PEAK:
		var x := u / PEAK
		return 1.0 - pow(1.0 - x, 3.0)
	var d := u - PEAK
	return exp(-d * 6.5) * cos(d * 15.0)


## The pose `t` seconds after the move began (hit frame at `windup`). `k`
## scales it (a clip already moves the body, so it adds less).
static func strike(style: String, t: float, windup: float, k := 1.0) -> Dictionary:
	var o := neutral()
	var st: Dictionary = STYLES.get(style, STYLES["lunge"])
	var a: Dictionary = st["a"]
	var s: Dictionary = st["s"]
	var w := maxf(windup, 0.05)
	if t < w:
		# Anticipation eases in and holds, with a tremble that grows.
		var e := smoothstep(0.0, 1.0, t / w)
		for key in a:
			o[key] = float(o.get(key, 0.0)) + float(a[key]) * e * k
		if style == "shiver":
			o["roll"] = sin(t * 52.0) * 0.1 * e * k
		elif style == "stomp" or style == "slam":
			o["y"] = float(o["y"]) + sin(t * 40.0) * 0.012 * e
		return o
	var u := t - w
	if u >= TAIL:
		return o
	var f := swing(u)
	var hold := 1.0 - smoothstep(0.0, 0.1, u)
	var fade := 1.0 - smoothstep(0.45, TAIL, u)
	for key in KEYS:
		var av := float(a.get(key, 0.0))
		var sv := float(s.get(key, 0.0))
		var v := (av * hold + sv * f) * fade * k
		if key == "sy":
			o[key] = 1.0 + v
		else:
			o[key] = v
	if style == "shiver":
		o["roll"] = sin(u * 60.0) * 0.08 * exp(-u * 10.0) * k
	return o


## Blends a layer's poses by adding offsets (sy multiplies).
static func add(a: Dictionary, b: Dictionary) -> Dictionary:
	return {"y": float(a["y"]) + float(b["y"]), "z": float(a["z"]) + float(b["z"]), "pitch": float(a["pitch"]) + float(b["pitch"]),
		"spin": float(a["spin"]) + float(b["spin"]), "roll": float(a["roll"]) + float(b.get("roll", 0.0)), "sy": float(a["sy"]) * float(b["sy"])}


## Leaning into a change of pace: forward acceleration tips it forward, braking
## tips it back, a turn leans it into the curve. `acc` is in the pet's own
## frame (x right, z forward), m/s². Smoothed by the caller.
static func lean(acc: Vector3, spd: float) -> Dictionary:
	var o := neutral()
	o["pitch"] = clampf(acc.z * 0.028, -0.3, 0.28)
	o["roll"] = clampf(-acc.x * 0.022 * minf(spd / 2.0, 1.0), -0.3, 0.3)
	o["sy"] = 1.0 - clampf(absf(acc.z) * 0.004, 0.0, 0.05)
	return o


## Gait: a step bounce that quickens with speed, a stride squash, and a body
## that rolls with each footfall. Flyers flap instead (see `flap`).
static func gait(spd: float, bob: float, top: float) -> Dictionary:
	var o := neutral()
	if spd <= 0.3:
		o["sy"] = 1.0 + 0.02 * sin(bob * 2.2)
		return o
	var rate := 7.0 + clampf(spd, 0.0, top) * 1.1
	var ph := bob * rate
	var amp := minf(spd / 3.0, 1.0)
	o["y"] = absf(sin(ph)) * 0.07 * amp
	o["sy"] = 1.0 - 0.05 * amp * (1.0 - absf(sin(ph)))
	o["roll"] = sin(ph) * 0.06 * amp
	o["pitch"] = clampf(spd * 0.03, 0.0, 0.2)
	return o


## A flyer's wing-beat bob and tilt: quicker and deeper the harder it flies.
static func flap(spd: float, bob: float) -> Dictionary:
	var o := neutral()
	var rate := 9.0 + minf(spd, 6.0) * 0.8
	o["y"] = sin(bob * rate) * (0.03 + 0.012 * minf(spd, 6.0))
	o["pitch"] = clampf(spd * 0.045, 0.0, 0.32) + sin(bob * rate * 0.5) * 0.03
	o["sy"] = 1.0 + 0.02 * sin(bob * rate)
	return o
