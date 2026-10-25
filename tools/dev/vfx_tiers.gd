extends SceneTree
## Review capture: one element at light, skill and big tier on the hunt
## ground, hero for scale. light = three quick basic shots; skill and big =
## cast, travel, impact, nova. Prints peak draw calls over idle per tier.
##   godot --path . --rendering-method gl_compatibility --write-movie out.avi \
##     --fixed-fps 30 -s tools/dev/vfx_tiers.gd -- --el=fire

const VfxLib := preload("res://src/vfx/vfx_lib.gd")
const HERO := Vector3(-3.0, 0, 1.2)
const TGT := Vector3(2.4, 0, -0.6)
const SEG := 2.6
const TIERS := [&"light", &"skill", &"big"]
const NAMES := ["LIGHT: basic attacks (x3)", "SKILL: abilities", "BIG: supers / bosses"]
## --fire: fireball basic vs flame-spray basic + breath vs big wavefront.
const FIRE_NAMES := ["FIREBALL: basic (x3)", "FLAME SPRAY: basic option + breath", "BIG: fire wavefront"]
var fire_cmp := false

var el := &"fire"
var col := Color.WHITE
var vfx: Node3D
var label: Label
var phase_label: Label
var t := -0.6
var seg := -1
var fired := {}
var ups: Array = []
var peak := {}
var idle := 0


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a == "--fire":
			fire_cmp = true
		if a.begins_with("--el="):
			el = StringName(a.substr(5))
	col = VfxLib.COLORS[el]
	var world := Node3D.new()
	root.add_child(world)
	var arena = load("res://src/hunt/arena.gd").new()
	world.add_child(arena)
	arena.build(false, "barrow")
	var hero: Node3D = load("res://assets/kaykit/characters/Knight.glb").instantiate()
	hero.position = HERO
	world.add_child(hero)
	hero.look_at(Vector3(TGT.x, 0, TGT.z), Vector3.UP, true)
	var cam := Camera3D.new()
	cam.keep_aspect = Camera3D.KEEP_WIDTH
	cam.fov = 62
	world.add_child(cam)
	cam.look_at_from_position(Vector3(-0.3, 6.6, 6.8), Vector3(-0.3, 0.3, 0.0))
	vfx = VfxLib.new()
	world.add_child(vfx)
	vfx.warmup(Vector3(0, -5, 0))
	var cl := CanvasLayer.new()
	root.add_child(cl)
	label = _label(cl, 40, 30)
	phase_label = _label(cl, 32, 1180)
	var title := _label(cl, 34, 84)
	title.text = str(el).to_upper()
	title.modulate = col.lightened(0.3)


func _label(cl: CanvasLayer, size: int, y: float) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_constant_override("outline_size", 10)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.position = Vector2(0, y)
	l.size = Vector2(720, 60)
	cl.add_child(l)
	return l


func _process(dt: float) -> bool:
	t += dt
	var draws := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	if t < 0.0:
		idle = draws
		return false
	var s := int(t / SEG)
	if s >= 3:
		print("DRAWS el=%s idle=%d light=+%d skill=+%d big=+%d" % [el, idle, int(peak[0]) - idle, int(peak[1]) - idle, int(peak[2]) - idle])
		return true
	if s != seg:
		seg = s
		fired.clear()
		label.text = (FIRE_NAMES if fire_cmp else NAMES)[s]
	peak[s] = maxi(int(peak.get(s, 0)), draws)
	var lt := t - s * SEG
	var tier: StringName = TIERS[s]
	if fire_cmp:
		if s == 0:
			vfx.fire_basic_spray = false
			for k in 3:
				_at(lt, 0.15 + k * 0.5, "fireball%d" % k, _shot.bind(&"light"))
		elif s == 1:
			vfx.fire_basic_spray = true
			for k in 3:
				_at(lt, 0.15 + k * 0.4, "spray basic%d" % k, _shot.bind(&"light"))
			_at(lt, 1.4, "breath", func(): vfx.spray(&"fire", HERO, TGT - HERO, 5.5, 0.5, 0.55))
		else:
			vfx.fire_basic_spray = false
			_at(lt, 0.2, "wavefront", func(): vfx.nova(&"fire", TGT + Vector3(-1.5, 0, 0.5), 4.2, 0.6, VfxLib.NO_TINT, &"big"))
			_at(lt, 1.4, "impact", func(): vfx.impact(&"fire", TGT, 2.2, VfxLib.NO_TINT, &"big"))
	elif s == 0:
		for k in 3:
			_at(lt, 0.15 + k * 0.45, "shot%d" % k, _shot.bind(tier))
	else:
		_at(lt, 0.0, "cast", func(): vfx.cast(el, HERO, 1.2, VfxLib.NO_TINT, tier))
		_at(lt, 0.3, "travel", _shot.bind(tier))
		_at(lt, 1.45, "nova", func(): vfx.nova(el, TGT, 3.2 if tier == &"skill" else 4.2, 0.6, VfxLib.NO_TINT, tier))
	var i := ups.size() - 1
	while i >= 0:
		var u: Array = ups[i]
		u[1] = float(u[1]) + dt
		if not (u[0] as Callable).call(float(u[1])):
			ups.remove_at(i)
		i -= 1
	return false


func _at(lt: float, when: float, what: String, f: Callable) -> void:
	if lt >= when and not fired.has(what):
		fired[what] = true
		phase_label.text = what.rstrip("012")
		f.call()


## A projectile from the hero's hand to the target (travel cores every
## 0.045 s, like Proj), then the impact.
func _shot(tier: StringName) -> void:
	var dur := 0.35 if tier == &"light" else 0.6
	var acc := [0.0, false]
	ups.append([func(a: float) -> bool:
		var k := clampf(a / dur, 0.0, 1.0)
		var p := (HERO + Vector3(0.4, 1.1, -0.2)).lerp(TGT + Vector3(0, 0.9, 0), k)
		if a - float(acc[0]) >= 0.045 and k < 1.0:
			acc[0] = a
			vfx.travel(el, p, (TGT - HERO) / dur, VfxLib.NO_TINT, tier)
		if k >= 1.0 and not acc[1]:
			acc[1] = true
			phase_label.text = "impact"
			vfx.impact(el, TGT, 1.2 if tier == &"light" else (1.6 if tier == &"skill" else 2.2), VfxLib.NO_TINT, tier)
		return k < 1.0, 0.0])
