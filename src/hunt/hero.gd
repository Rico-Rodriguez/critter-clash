class_name Hero
extends Actor
## The player's hero. Moves on the stick, attacks the nearest foe on its own
## (and keeps attacking while it runs: the swing plays on the upper body),
## dashes through danger, and spends a charged super.

const UPPER_BONES := ["spine", "chest", "upperarm.l", "lowerarm.l", "wrist.l", "hand.l", "handslot.l", "upperarm.r", "lowerarm.r", "wrist.r", "hand.r", "handslot.r", "head"]
const DASH_SPEED := 21.0
const DASH_TIME := 0.21

var id := "knight"
var def: Dictionary
var base: Dictionary
# Effective numbers after cards.
var dmg := 20.0
var rate := 1.0
var crit := 0.05
var armor := 0.0
var regen := 0.0
var reach := 2.4
var arc := 120.0
var splash := 0.0
var shots := 1
var pierce := 0
var magnet := 3.0
var dash_cd_max := 2.2
var super_rate := 1.0
var gold_mult := 1.0
var leech := 0.0
var thorns := 0.0

var move_input := Vector2.ZERO
var vel := Vector3.ZERO
var atk_cd := 0.0
var impact_t := -1.0
var target: Actor
var aim_yaw := 0.0
var aim_hold := 0.0
var swing_i := 0
var dash_cd := 0.0
var dash_t := 0.0
var dash_dir := Vector3.ZERO
var invuln := 0.0
var super_charge := 0.0
var super_t := 0.0
var super_kind := ""
var leap_from := Vector3.ZERO
var leap_to := Vector3.ZERO
var whirl_tick := 0.0
var revived := false
var ward_up := false
var ward_t := 0.0
var storm_t := 2.0
var nova_t := 3.0
var blades: Array[Node3D] = []
var blade_angle := 0.0
var light: OmniLight3D
var target_ring: MeshInstance3D
var ward_mesh: MeshInstance3D
var tree: AnimationTree
var _up_anim: AnimationNodeAnimation
var _full_anim: AnimationNodeAnimation


func setup(h: Hunt, hero_id: String, stats: Dictionary) -> void:
	hunt = h
	id = hero_id
	def = DB.HEROES[id]
	base = stats
	radius = 0.5
	mass = 4.0
	build_model(def["model"], def["weapons"], Color(1.0, 0.78, 0.5), 0.35)
	GearLook.apply(self, id)
	_build_tree()
	# The hero carries the light: Diablo's lantern radius.
	light = OmniLight3D.new()
	light.light_color = Color(1.0, 0.72, 0.45)
	light.light_energy = 4.2
	light.omni_range = 11.0
	light.omni_attenuation = 1.6
	light.position = Vector3(0, 3.2, 0.6)
	light.shadow_enabled = false
	add_child(light)
	var ws := Shader.new()
	ws.code = "shader_type spatial;\nrender_mode blend_add, unshaded, cull_back, depth_draw_never, shadows_disabled;\nvoid fragment(){ float f = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.5); ALBEDO = vec3(0.45, 0.75, 1.0) * 2.0; ALPHA = clamp(f * 0.9 + 0.04, 0.0, 1.0); }"
	var wm := ShaderMaterial.new()
	wm.shader = ws
	ward_mesh = MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 1.05
	sph.height = 2.1
	ward_mesh.mesh = sph
	ward_mesh.material_override = wm
	ward_mesh.position = Vector3(0, 0.9, 0)
	ward_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ward_mesh.visible = false
	add_child(ward_mesh)
	target_ring = MeshInstance3D.new()
	var tq := PlaneMesh.new()
	tq.size = Vector2(1.5, 1.5)
	target_ring.mesh = tq
	var tm := ShaderMaterial.new()
	tm.shader = preload("res://src/fx/hero_ring.gdshader")
	tm.set_shader_parameter("color", Color(1.0, 0.28, 0.22))
	tm.set_shader_parameter("intensity", 2.2)
	target_ring.material_override = tm
	target_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	target_ring.visible = false
	h.world.add_child(target_ring)
	var ring := MeshInstance3D.new()
	var rq := PlaneMesh.new()
	rq.size = Vector2(2.1, 2.1)
	ring.mesh = rq
	var rm := ShaderMaterial.new()
	rm.shader = preload("res://src/fx/hero_ring.gdshader")
	ring.material_override = rm
	ring.position.y = 0.05
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)
	recompute()
	hp = max_hp


func _build_tree() -> void:
	tree = AnimationTree.new()
	model.add_child(tree)
	tree.anim_player = tree.get_path_to(anim)
	var a: Dictionary = def["anim"]
	var bt := AnimationNodeBlendTree.new()
	var idle := AnimationNodeAnimation.new()
	idle.animation = a["idle"]
	var run := AnimationNodeAnimation.new()
	run.animation = a["run"]
	_up_anim = AnimationNodeAnimation.new()
	_up_anim.animation = a["attack"][0]
	_full_anim = AnimationNodeAnimation.new()
	_full_anim.animation = a["attack"][0]
	var up := AnimationNodeOneShot.new()
	up.filter_enabled = true
	for b in UPPER_BONES:
		up.set_filter_path(NodePath("Rig_Medium/Skeleton3D:" + b), true)
	up.fadein_time = 0.05
	up.fadeout_time = 0.16
	var full := AnimationNodeOneShot.new()
	full.fadein_time = 0.05
	full.fadeout_time = 0.18
	bt.add_node("idle", idle)
	bt.add_node("run", run)
	bt.add_node("run_ts", AnimationNodeTimeScale.new())
	bt.add_node("move", AnimationNodeBlend2.new())
	bt.add_node("up_anim", _up_anim)
	bt.add_node("up_ts", AnimationNodeTimeScale.new())
	bt.add_node("up", up)
	bt.add_node("full_anim", _full_anim)
	bt.add_node("full_ts", AnimationNodeTimeScale.new())
	bt.add_node("full", full)
	bt.connect_node("run_ts", 0, "run")
	bt.connect_node("move", 0, "idle")
	bt.connect_node("move", 1, "run_ts")
	bt.connect_node("up_ts", 0, "up_anim")
	bt.connect_node("up", 0, "move")
	bt.connect_node("up", 1, "up_ts")
	bt.connect_node("full_ts", 0, "full_anim")
	bt.connect_node("full", 0, "up")
	bt.connect_node("full", 1, "full_ts")
	bt.connect_node("output", 0, "full")
	tree.tree_root = bt
	tree.active = true


## Plays a clip: on the upper body while running, or the whole body.
func act(clip: String, duration: float, whole := false) -> void:
	var len_ := anim_length(clip)
	var sc := clampf(len_ / maxf(duration, 0.05), 0.4, 3.0)
	if whole or vel.length() < 1.0:
		tree.set("parameters/up/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_ABORT)
		_full_anim.animation = clip
		tree.set("parameters/full_ts/scale", sc)
		tree.set("parameters/full/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	else:
		_up_anim.animation = clip
		tree.set("parameters/up_ts/scale", sc)
		tree.set("parameters/up/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)


func recompute() -> void:
	var c := hunt.cards
	var lv := func(k: String) -> int: return int(c.get(k, 0))
	var old_max := max_hp
	dmg = base["dmg"] * (1.0 + 0.18 * lv.call("might"))
	rate = base["rate"] * (1.0 + 0.14 * lv.call("haste"))
	max_hp = base["hp"] * (1.0 + 0.2 * lv.call("vigor"))
	speed = base["speed"] * (1.0 + 0.09 * lv.call("swift"))
	crit = base["crit"] + 0.09 * lv.call("crit")
	armor = base["armor"]
	regen = base["regen"] + max_hp * 0.012 * lv.call("regen")
	reach = base["range"] * (1.0 + 0.25 * lv.call("reach"))
	arc = minf(base["arc"] * (1.0 + 0.25 * lv.call("reach")), 300.0)
	splash = base["splash"] * (1.0 + 0.35 * lv.call("inferno"))
	shots = int(def.get("shots", 1)) + lv.call("multishot")
	pierce = int(def.get("pierce", 0)) + lv.call("pierce")
	magnet = 4.2 * (1.0 + 0.5 * lv.call("magnet"))
	dash_cd_max = 2.2 * (1.0 - 0.2 * lv.call("dash"))
	super_rate = 1.0 + 0.25 * lv.call("wrath")
	gold_mult = base["gold"] * (1.0 + 0.3 * lv.call("greed"))
	leech = 0.03 * lv.call("leech")
	thorns = 0.6 * lv.call("thorns")
	if old_max > 0.0 and max_hp > old_max:
		hp += max_hp - old_max
	hp = minf(hp, max_hp)
	_sync_blades(lv.call("blades"))


func tick(dt: float) -> void:
	if not alive:
		return
	tick_common(dt)
	invuln -= dt
	atk_cd -= dt
	dash_cd -= dt
	aim_hold -= dt
	if regen > 0.0:
		hp = minf(hp + regen * dt, max_hp)
	super_charge = minf(super_charge + dt * 0.012 * super_rate, 1.0)
	_tick_cards(dt)
	if super_t > 0.0:
		_tick_super(dt)
		return
	if dash_t > 0.0:
		dash_t -= dt
		position += dash_dir * DASH_SPEED * dt
		position = hunt.arena.resolve(position, radius)
		if randf() < 0.6:
			hunt.fx.puff(flat_pos(), Color(0.35, 0.3, 0.26, 0.4), 1, 0.2, 0.6)
		return
	# Movement: snappy, but not instant.
	var want := Vector3(move_input.x, 0, move_input.y)
	if want.length() > 1.0:
		want = want.normalized()
	var swing_slow := 0.82 if impact_t > 0.0 and def["style"] == "melee" else 1.0
	var target_vel := want * speed * swing_slow
	var accel := 60.0 if want.length() > 0.1 else 70.0
	vel = vel.move_toward(target_vel, accel * dt)
	position += vel * dt
	position = hunt.arena.resolve(position, radius)
	var moving := vel.length()
	tree.set("parameters/move/blend_amount", clampf(moving / 2.0, 0.0, 1.0))
	tree.set("parameters/run_ts/scale", clampf(moving / speed, 0.6, 1.3))
	# Facing: the target while attacking, else the way we run.
	if aim_hold > 0.0 and target and is_instance_valid(target) and target.alive:
		aim_yaw = yaw_to(position, target.position)
		face(aim_yaw, dt, 20.0)
	elif moving > 0.5:
		face(atan2(vel.x, vel.z), dt, 14.0)
	_tick_attack(dt)
	_tick_target_ring()


## A red ring under whatever the hero is hitting, so you can see your target
## in the crowd.
func _tick_target_ring() -> void:
	var on := aim_hold > 0.0 and target != null and is_instance_valid(target) and target.alive
	target_ring.visible = on
	if on:
		var s := (target.radius * 2.6 + 0.4)
		target_ring.scale = Vector3(s / 1.5, 1.0, s / 1.5)
		target_ring.position = Vector3(target.position.x, 0.06, target.position.z)


func _tick_attack(dt: float) -> void:
	if impact_t > 0.0:
		impact_t -= dt
		if impact_t <= 0.0:
			_impact()
		return
	if atk_cd > 0.0:
		return
	var range_: float = reach
	var t := hunt.nearest_foe(position, range_ + 1.0)
	if t == null or flat_pos().distance_to(t.flat_pos()) > range_ + t.radius:
		return
	target = t
	aim_hold = 0.6
	aim_yaw = yaw_to(position, t.position)
	atk_cd = 1.0 / rate
	var clips: Array = def["anim"]["attack"]
	var clip: String = clips[swing_i % clips.size()]
	swing_i += 1
	var style: String = def["style"]
	var lead := 0.16 if style == "melee" else 0.1
	lead = minf(lead, atk_cd * 0.6)
	impact_t = lead
	act(clip, lead / 0.45)


func _impact() -> void:
	var style: String = def["style"]
	if target and is_instance_valid(target) and target.alive:
		aim_yaw = yaw_to(position, target.position)
	rotation.y = aim_yaw
	var fwd := dir_of(aim_yaw)
	match style:
		"melee":
			var hit := 0
			for f in hunt.foes_near(position, reach + 1.5):
				var to: Vector3 = f.flat_pos() - flat_pos()
				if to.length() > reach + f.radius:
					continue
				if absf(angle_difference(aim_yaw, atan2(to.x, to.z))) > deg_to_rad(arc) * 0.5 + 0.2 and to.length() > 0.9:
					continue
				hunt.damage_foe(f, dmg, self, to.normalized(), 5.5)
				hit += 1
			var col := Color(0.75, 0.88, 1.0) if id == "knight" else Color(1.0, 0.62, 0.3)
			hunt.fx.slash(flat_pos(), aim_yaw, reach * 1.05, arc, col, swing_i % 2 == 0, 0.2)
			Sfx.play("atk_tank" if id == "knight" else "cleave", -4.0)
			Sfx.play("swing", -8.0)
			if hit > 0:
				Sfx.play("hit", -2.0)
				hunt.hitstop(0.035 if hit < 4 else 0.06)
				hunt.shake(0.12 + 0.03 * mini(hit, 5))
			if hunt.cards.get("wave", 0) > 0:
				var wl: int = hunt.cards["wave"]
				hunt.spawn_proj("wave", flat_pos() + fwd * 0.8, fwd * 15.0, dmg * (0.45 + 0.15 * wl), 99, self, {"life": 0.35 + 0.08 * wl, "width": 1.2 + 0.2 * wl})
		"bow":
			var n := shots
			for i in n:
				var a := aim_yaw + (i - (n - 1) * 0.5) * deg_to_rad(7.0)
				var d := dir_of(a)
				hunt.spawn_proj("arrow", flat_pos() + d * 0.5, d * float(base["proj_speed"]), dmg, 1 + pierce, self)
			Sfx.play("atk_archer", -5.0)
		"magic":
			var n2 := shots
			for i in n2:
				var a2 := aim_yaw + (i - (n2 - 1) * 0.5) * deg_to_rad(11.0)
				var d2 := dir_of(a2)
				hunt.spawn_proj("fireball", flat_pos() + d2 * 0.6, d2 * float(base["proj_speed"]), dmg, 1, self, {"splash": splash})
			Sfx.play("atk_mage", -5.0)


# --- Dash and super ------------------------------------------------------

func try_dash() -> bool:
	if dash_cd > 0.0 or dash_t > 0.0 or super_t > 0.0 or not alive:
		return false
	var d := Vector3(move_input.x, 0, move_input.y)
	if d.length() < 0.2:
		d = dir_of(rotation.y)
	dash_dir = d.normalized()
	dash_t = DASH_TIME
	dash_cd = dash_cd_max
	invuln = DASH_TIME + 0.12
	impact_t = -1.0
	rotation.y = atan2(dash_dir.x, dash_dir.z)
	vel = dash_dir * speed
	act("Dodge_Forward", DASH_TIME + 0.15, true)
	hunt.fx.puff(flat_pos(), Color(0.35, 0.3, 0.26, 0.55), 6, 0.5, 2.0)
	Sfx.play("dodge", -3.0)
	Ui.buzz(12, 0.3)
	return true


func super_ready() -> bool:
	return super_charge >= 1.0 and super_t <= 0.0 and alive


func try_super() -> bool:
	if not super_ready():
		return false
	super_charge = 0.0
	Ui.buzz(50, 0.7)
	super_kind = def["super"]
	impact_t = -1.0
	var fwd := Vector3(move_input.x, 0, move_input.y)
	var t := hunt.nearest_foe(position, 9.0)
	if fwd.length() < 0.2:
		fwd = (t.flat_pos() - flat_pos()).normalized() if t else dir_of(rotation.y)
	fwd = fwd.normalized()
	rotation.y = atan2(fwd.x, fwd.z)
	match super_kind:
		"slam":
			super_t = 0.55
			invuln = 0.7
			leap_from = flat_pos()
			var dist := 4.8
			if t and fwd.dot((t.flat_pos() - flat_pos()).normalized()) > 0.7:
				dist = clampf(flat_pos().distance_to(t.flat_pos()), 1.5, 5.5)
			leap_to = hunt.arena.resolve(leap_from + fwd * dist, radius)
			act(def["anim"]["super"], 0.75, true)
			Sfx.play("charge", -2.0)
		"whirlwind":
			super_t = 3.2
			whirl_tick = 0.0
			tree.active = false
			play(def["anim"]["super"], 0.1, 1.6)
			Sfx.play("blades", -2.0)
		"volley":
			super_t = 0.35
			act(def["anim"]["super"], 0.35, true)
			var n := 15
			for i in n:
				var a := rotation.y + (i - (n - 1) * 0.5) * deg_to_rad(6.0)
				var d := dir_of(a)
				hunt.spawn_proj("arrow", flat_pos() + d * 0.5, d * 30.0, dmg * 1.7, 99, self, {"super": true})
			hunt.shake(0.25)
			Sfx.play("volley", 0.0)
		"nova":
			super_t = 0.45
			act(def["anim"]["super"], 0.5, true)
			hunt.fx.ring(flat_pos(), 7.5, Color(0.5, 0.85, 1.0), 0.55, 0.08)
			hunt.fx.ring(flat_pos(), 5.0, Color(0.8, 0.95, 1.0), 0.4, 0.15)
			hunt.fx.burst(flat_pos(), Color(0.6, 0.9, 1.0), 40, 12.0, 0.4)
			hunt.fx.flash_light(flat_pos(), Color(0.5, 0.8, 1.0), 6.0, 12.0, 0.5)
			for f in hunt.foes_near(position, 7.5):
				hunt.damage_foe(f, dmg * 2.4, self, (f.flat_pos() - flat_pos()).normalized(), 9.0)
				if f.alive:
					f.freeze(2.6)
			hunt.shake(0.45)
			hunt.hitstop(0.08)
			Sfx.play("frost", 0.0)
	return true


func _tick_super(dt: float) -> void:
	super_t -= dt
	match super_kind:
		"slam":
			var k := 1.0 - clampf(super_t / 0.55, 0.0, 1.0)
			var p := leap_from.lerp(leap_to, smoothstep(0.0, 1.0, k))
			position = p
			model.position.y = sin(k * PI) * 2.4
			if super_t <= 0.0:
				model.position.y = 0.0
				_slam_land()
		"whirlwind":
			var want := Vector3(move_input.x, 0, move_input.y)
			if want.length() > 1.0:
				want = want.normalized()
			vel = vel.move_toward(want * speed * 1.15, 50.0 * dt)
			position = hunt.arena.resolve(position + vel * dt, radius)
			whirl_tick -= dt
			if whirl_tick <= 0.0:
				whirl_tick = 0.2
				var any := false
				for f in hunt.foes_near(position, 3.2):
					var to: Vector3 = f.flat_pos() - flat_pos()
					hunt.damage_foe(f, dmg * 0.75, self, to.normalized(), 3.0)
					any = true
				hunt.fx.slash(flat_pos(), randf() * TAU, 3.2, 360, Color(1.0, 0.55, 0.25), false, 0.22)
				if any:
					Sfx.play("hit", -6.0)
			if super_t <= 0.0:
				tree.active = true
				cur_anim = ""
	if super_t <= 0.0:
		super_kind = ""


func _slam_land() -> void:
	var at := flat_pos()
	hunt.fx.ring(at, 5.0, Color(1.0, 0.82, 0.4), 0.5, 0.14)
	hunt.fx.ring(at, 3.0, Color(1.0, 0.95, 0.8), 0.3, 0.2)
	hunt.fx.puff(at, Color(0.35, 0.3, 0.25, 0.7), 16, 2.5, 4.0)
	hunt.fx.burst(at, Color(1.0, 0.8, 0.45), 30, 10.0, 0.6)
	hunt.fx.flash_light(at, Color(1.0, 0.8, 0.5), 7.0, 10.0, 0.4)
	for f in hunt.foes_near(position, 4.6):
		var to: Vector3 = f.flat_pos() - at
		hunt.damage_foe(f, dmg * 3.6, self, to.normalized(), 13.0)
		if f.alive:
			f.stun_t = 1.6
	hunt.shake(0.7)
	hunt.hitstop(0.09)
	Ui.buzz(70, 0.8)
	Sfx.play("charge_land", 0.0)
	Sfx.play("meteor", -3.0)


# --- Cards that act on their own -----------------------------------------

func _sync_blades(level: int) -> void:
	var want := 0 if level <= 0 else level + 1
	while blades.size() < want:
		var b := KK.prop("res://assets/kaykit/weapons/sword_1handed.gltf")
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color(0.55, 0.85, 1.0)
		m.emission_enabled = true
		m.emission = Color(0.4, 0.75, 1.0)
		m.emission_energy_multiplier = 2.5
		for mi in b.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).material_override = m
			(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		b.scale = Vector3.ONE * 1.3
		hunt.world.add_child(b)
		blades.append(b)


func _tick_cards(dt: float) -> void:
	var c := hunt.cards
	# Orbiting blades.
	if not blades.is_empty():
		blade_angle += dt * 3.4
		var bl: int = c.get("blades", 0)
		var r := 2.3 + 0.15 * bl
		for i in blades.size():
			var a := blade_angle + TAU * i / blades.size()
			var p := flat_pos() + Vector3(sin(a), 0, cos(a)) * r
			var b := blades[i]
			b.position = p + Vector3(0, 0.9, 0)
			b.rotation = Vector3(0, a + PI * 0.5, PI * 0.5)
			for f in hunt.foes_near(p, 0.9):
				if f.has_method("can_hit") and f.can_hit(1000 + i, 0.45):
					hunt.damage_foe(f, dmg * (0.4 + 0.1 * bl), self, (f.flat_pos() - flat_pos()).normalized(), 4.0)
					hunt.fx.burst(p, Color(0.5, 0.8, 1.0), 4, 4.0)
	# Storm call: chain lightning.
	var sl: int = c.get("storm", 0)
	if sl > 0:
		storm_t -= dt
		if storm_t <= 0.0:
			storm_t = maxf(3.2 - 0.45 * sl, 1.2)
			_storm(2 + sl, dmg * (1.0 + 0.25 * sl))
	# Fire nova.
	var nl: int = c.get("nova", 0)
	if nl > 0:
		nova_t -= dt
		if nova_t <= 0.0:
			nova_t = maxf(5.0 - 0.7 * nl, 2.0)
			var r2 := 3.4 + 0.5 * nl
			hunt.fx.ring(flat_pos(), r2, Color(1.0, 0.5, 0.15), 0.4, 0.12)
			hunt.fx.embers_at(flat_pos(), Color(1.0, 0.5, 0.15), 16, r2 * 0.7)
			hunt.fx.flash_light(flat_pos(), Color(1.0, 0.5, 0.2), 3.0, r2 * 1.6, 0.3)
			for f in hunt.foes_near(position, r2):
				hunt.damage_foe(f, dmg * (1.2 + 0.3 * nl), self, (f.flat_pos() - flat_pos()).normalized(), 7.0)
			Sfx.play("fire_trail", -4.0)
	# Bone ward.
	var wl: int = c.get("ward", 0)
	if wl > 0 and not ward_up:
		ward_t -= dt
		if ward_t <= 0.0:
			ward_up = true
			ward_mesh.visible = true
			Sfx.play("unlock_start", -8.0)
	ward_mesh.visible = ward_up


func _storm(jumps: int, amount: float) -> void:
	var from := flat_pos() + Vector3(0, 1.2, 0)
	var pts := PackedVector3Array([from])
	var hit := {}
	var cur := flat_pos()
	for j in jumps:
		var best: Enemy = null
		var bd := 7.5 if j == 0 else 4.5
		for f in hunt.foes:
			if not f.alive or hit.has(f) or f.state == "spawn":
				continue
			var d := cur.distance_to(f.flat_pos())
			if d < bd:
				bd = d
				best = f
		if best == null:
			break
		hit[best] = true
		cur = best.flat_pos()
		pts.append(cur + Vector3(0, 1.0, 0))
		hunt.damage_foe(best, amount, self, Vector3.ZERO, 0.0)
	if pts.size() > 1:
		hunt.fx.lightning(pts)
		Sfx.play("chain", -4.0)
		Sfx.play("thunder", -10.0)


func break_ward() -> void:
	ward_up = false
	ward_t = 10.0 - 2.0 * int(hunt.cards.get("ward", 0))
	hunt.fx.burst(flat_pos(), Color(0.5, 0.8, 1.0), 18, 7.0)
	Sfx.play("shield_break", -2.0)


func die_anim() -> void:
	alive = false
	target_ring.visible = false
	flash_t = 0.0
	set_flash(0.0)
	tree.active = false
	cur_anim = ""
	play("Death_A", 0.1)
	for b in blades:
		b.visible = false


func revive() -> void:
	alive = true
	revived = true
	hp = max_hp * 0.5
	invuln = 2.0
	tree.active = true
	for b in blades:
		b.visible = true
	act("Spawn_Ground", 0.8, true)
