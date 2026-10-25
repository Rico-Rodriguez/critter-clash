class_name Hero
extends Actor
## The player's hero. Moves on the stick, attacks the nearest foe on its own
## (and keeps attacking while it runs: the swing plays on the upper body),
## dashes through danger, and spends a charged super.

const UPPER_BONES := ["spine", "chest", "upperarm.l", "lowerarm.l", "wrist.l", "hand.l", "handslot.l", "upperarm.r", "lowerarm.r", "wrist.r", "hand.r", "handslot.r", "head"]
const DASH_SPEED := 21.0
const DASH_TIME := 0.21

## Seconds left of a curse that cuts move speed (the Hexer Queen's lane).
var slow_t := 0.0
## Seconds left rooted in place (the Jailer affix).
var root_t := 0.0
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
## Super ranks bought with shards scale every Super's damage.
var super_dmg := 1.0
var gold_mult := 1.0
var leech := 0.0
var thorns := 0.0
## Leech heals at most DB.LEECH_CAP of max health a second; this refills.
var leech_pool := 0.0
## Seconds standing still (steady aim), seconds left of a perfect-dodge
## riposte, and whether this dash already earned one.
var still_t := 0.0
var riposte_t := 0.0
var perfect_used := false
## Rampage stacks (Barbarian signature) and the seconds they last.
var rampage := 0
var rampage_t := 0.0
## Potion charges: a second one at DB.SECOND_POTION_LEVEL.
var potions := 1
var potions_max := 1
var _foot_mat: ShaderMaterial

var move_input := Vector2.ZERO
var vel := Vector3.ZERO
var atk_cd := 0.0
var impact_t := -1.0
var target: Actor
var aim_yaw := 0.0
var aim_hold := 0.0
var swing_i := 0
var dash_cd := 0.0
var potion_cd := 0.0
var dash_t := 0.0
var dash_dir := Vector3.ZERO
var invuln := 0.0
var super_charge := 0.0
## Seconds left before charge can build again after a super.
var super_lock := 0.0
## Damage the current swing may still turn into charge (one swing's worth).
var super_budget := 0.0
var super_t := 0.0
var super_kind := ""
var leap_from := Vector3.ZERO
var leap_to := Vector3.ZERO
var whirl_tick := 0.0
var whirl_n := 0
var revived := false
## Talent rules (see TalentDB), the rage stacks from Bloodlust, and whether
## Second Wind has fired this hunt.
var flags := {}
var xp_mult := 1.0
var rage := 0
var rage_t := 0.0
var wind_used := false
var ward_up := false
var ward_t := 0.0
var storm_t := 2.0
var nova_t := 3.0
var blades: Array[Node3D] = []
var blade_angle := 0.0
var light: OmniLight3D
var target_ring: MeshInstance3D
## Shrine blessings: id -> hunt time they end.
var buffs := {}
var volley_n := 0
var ward_mesh: MeshInstance3D
var tree: AnimationTree
## The weapon family that decides the basic attack ("" = the hero's own), its
## DB.FAMILIES entry, and follow-up hits waiting to land: {t, foe, amount}, or
## {t, swing} for a second swing of a flurry.
var fam := ""
var fdef: Dictionary = {}
var _later: Array = []
var _up_anim: AnimationNodeAnimation
var _full_anim: AnimationNodeAnimation


func setup(h: Hunt, hero_id: String, stats: Dictionary) -> void:
	hunt = h
	id = hero_id
	def = DB.HEROES[id]
	base = stats
	fam = str(stats.get("family", ""))
	if fam != "":
		fdef = DB.FAMILIES[fam]
		def = def.duplicate(true)
		def["anim"] = GearDB.anims(id, fam)
	radius = 0.5
	mass = 4.0
	build_model(def["model"], {}, Color(1.0, 0.78, 0.5), 0.35)
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
	ws.code = "shader_type spatial;\nrender_mode blend_mix, unshaded, cull_back, depth_draw_never, shadows_disabled;\nvoid fragment(){ float f = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0); if (f < 0.55) discard; ALBEDO = f > 0.8 ? vec3(0.16, 0.42, 0.78) : vec3(0.55, 0.85, 1.0); ALPHA = 0.85; }"
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
	_foot_mat = rm
	ring.position.y = 0.05
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)
	recompute()
	hp = max_hp
	potions_max = 2 if Game.combat_level(id) >= DB.SECOND_POTION_COMBAT else 1
	potions = potions_max


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
	shots = maxi(1, int(def.get("shots", 1)) + int(fdef.get("shots", 0)) + lv.call("multishot"))
	pierce = int(def.get("pierce", 0)) + int(fdef.get("pierce", 0)) + lv.call("pierce")
	magnet = 4.2 * (1.0 + 0.5 * lv.call("magnet"))
	flags = base.get("flags", {})
	xp_mult = 1.0 + float(base.get("xp", 0.0)) + hunt.pact_sum("xp")
	rate *= 1.0 + 0.05 * rage
	dash_cd_max = 2.2 * (1.0 - 0.2 * lv.call("dash")) * (1.0 - float(base.get("dash", 0.0)))
	var sm := DB.super_mults(Game.super_rank(id))
	super_dmg = sm.x
	super_rate = DB.super_rate(0.25 * lv.call("wrath") + float(base.get("super", 0.0)) + hunt.pact_sum("super") + (sm.y - 1.0))
	gold_mult = base["gold"] * (1.0 + 0.3 * lv.call("greed"))
	leech = 0.03 * lv.call("leech")
	thorns = 0.6 * lv.call("thorns")
	dmg *= 1.0 + hunt.pact_sum("dmg")
	rate *= 1.0 + hunt.pact_sum("rate")
	max_hp *= 1.0 + hunt.pact_sum("hp")
	armor += hunt.pact_sum("armor")
	gold_mult += hunt.pact_sum("gold")
	for bid: String in buffs:
		var b: Dictionary = DB.SHRINES[bid]
		dmg *= float(b.get("dmg", 1.0))
		rate *= float(b.get("rate", 1.0))
		speed *= float(b.get("speed", 1.0))
		armor += float(b.get("armor", 0.0))
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
	potion_cd -= dt
	if potion_cd <= 0.0 and potions < potions_max:
		potions += 1
		if potions < potions_max:
			potion_cd = float(DB.POTION["cd"])
	aim_hold -= dt
	riposte_t -= dt
	rampage_t -= dt
	if rampage_t <= 0.0:
		rampage = 0
	var was_steady := steady()
	still_t = still_t + dt if vel.length() < 0.6 and dash_t <= 0.0 else 0.0
	if steady() != was_steady:
		# The ring under a planted archer burns gold: you are hitting harder.
		_foot_mat.set_shader_parameter("color", Color(1.0, 0.78, 0.3) if steady() else Color(0.35, 0.75, 1.0))
		_foot_mat.set_shader_parameter("intensity", 2.4 if steady() else 1.6)
	if rage > 0:
		rage_t -= dt
		if rage_t <= 0.0:
			rage = 0
			recompute()
	if regen > 0.0:
		hp = minf(hp + minf(regen, max_hp * DB.REGEN_CAP) * hunt.heal_mult() * dt, max_hp)
	leech_pool = minf(leech_pool + max_hp * DB.LEECH_CAP * dt, max_hp * DB.LEECH_CAP)
	if super_lock > 0.0:
		super_lock = maxf(super_lock - dt, 0.0)
	else:
		super_charge = minf(super_charge + dt * float(DB.SUPER["passive"]) * super_rate, 1.0)
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
	if slow_t > 0.0:
		slow_t -= dt
		swing_slow *= 0.6
	if root_t > 0.0:
		root_t -= dt
		swing_slow = 0.0
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
	_tick_later(dt)
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
	super_budget = dmg
	var clips: Array = def["anim"]["attack"]
	var clip: String = clips[swing_i % clips.size()]
	swing_i += 1
	var style: String = def["style"]
	var lead := 0.16 if style == "melee" else 0.1
	if fam != "":
		lead = float(fdef.get("lead", 0.2 if fdef["attack"] in ["slam", "throw"] else 0.16))
	lead = minf(lead, atk_cd * 0.6)
	impact_t = lead
	act(clip, lead / 0.45)


func _impact() -> void:
	var style: String = def["style"]
	if target and is_instance_valid(target) and target.alive:
		aim_yaw = yaw_to(position, target.position)
	rotation.y = aim_yaw
	var fwd := dir_of(aim_yaw)
	if fam != "" and style == "melee":
		_family_impact(fwd)
		_wave(fwd)
		return
	if fam != "" and str(fdef["attack"]) in ["chain", "lance"]:
		_spell_impact(fwd)
		return
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
			# Fine metal cuts in its own color.
			var wpn := Game.equipped(id, "weapon")
			if not wpn.is_empty() and int(wpn.get("mat", 0)) >= 1:
				col = col.lerp(GearDB.item_color(wpn).lightened(0.25), 0.75)
			hunt.fx.slash(flat_pos(), aim_yaw, reach * 1.05, arc, col, swing_i % 2 == 0, 0.2)
			Sfx.play("atk_tank" if id == "knight" else "cleave", -4.0)
			Sfx.play("swing", -8.0)
			if hit > 0:
				Sfx.play("hit", -2.0)
				hunt.hitstop(0.035 if hit < 4 else 0.06)
				hunt.shake(0.12 + 0.03 * mini(hit, 5))
			_wave(fwd)
		"bow":
			var n := shots
			var spread := deg_to_rad(float(fdef.get("spread", 7.0)))
			var kind := str(fdef.get("proj", "arrow"))
			var ex := {"home": true} if fdef.get("home", false) else {}
			if kind == "knife":
				ex["life"] = reach / float(base["proj_speed"])
			for i in n:
				var a := aim_yaw + (i - (n - 1) * 0.5) * spread
				var d := dir_of(a)
				hunt.spawn_proj(kind, flat_pos() + d * 0.5, d * float(base["proj_speed"]), dmg, 1 + pierce, self, ex.duplicate())
			volley_n += 1
			var exl: int = hunt.cards.get("explosive", 0)
			if exl > 0 and volley_n % maxi(5 - exl, 2) == 0:
				hunt.spawn_proj("fireball", flat_pos() + fwd * 0.6, fwd * float(base["proj_speed"]) * 0.7, dmg * 1.6, 1, self, {"splash": 1.8 + 0.3 * exl})
			if int(hunt.cards.get("rain", 0)) > 0 and volley_n % 3 == 0:
				for i in 12:
					var da := dir_of(TAU * i / 12.0)
					hunt.spawn_proj("arrow", flat_pos() + da * 0.5, da * float(base["proj_speed"]), dmg * 0.8, 1 + pierce, self)
			Sfx.play("atk_archer" if fam == "" else str(fdef["sfx"]), -5.0)
		"magic":
			var n2 := shots
			var spread2 := deg_to_rad(float(fdef.get("spread", 11.0)))
			var kind2 := str(fdef.get("proj", "fireball"))
			for i in n2:
				var a2 := aim_yaw + (i - (n2 - 1) * 0.5) * spread2
				var d2 := dir_of(a2)
				var ex2 := {"splash": splash, "home": fdef.get("home", false)}
				hunt.spawn_proj(kind2, flat_pos() + d2 * 0.6, d2 * float(base["proj_speed"]), dmg, 1, self, ex2)
			Sfx.play("atk_mage", -5.0)


## The Scepter's chain lightning and the Soulstaff's lance.
func _spell_impact(fwd: Vector3) -> void:
	var col := _trail()
	Sfx.play(str(fdef["sfx"]), -5.0)
	match str(fdef["attack"]):
		"chain":
			# From the target (or the nearest foe), leaping to the next nearest
			# it has not struck; each extra shot is one more leap.
			var pts := PackedVector3Array([flat_pos() + fwd * 0.5 + Vector3(0, 1.2, 0)])
			var hit := {}
			var from := flat_pos()
			var amount := dmg
			for j in int(fdef["jumps"]) + shots:
				var best: Actor = null
				var bd := reach + 1.0 if j == 0 else 4.5
				if j == 0 and target and is_instance_valid(target) and target.alive and from.distance_to(target.flat_pos()) < bd:
					best = target
				else:
					for f in hunt.foes_near(from, bd):
						if hit.has(f) or f.state == "spawn" or not f.alive:
							continue
						if from.distance_to(f.flat_pos()) < bd:
							bd = from.distance_to(f.flat_pos())
							best = f
					if hunt.boss and hunt.boss.alive and not hit.has(hunt.boss) and from.distance_to(hunt.boss.flat_pos()) < bd:
						best = hunt.boss
				if best == null:
					break
				hit[best] = true
				var to: Vector3 = best.flat_pos()
				pts.append(to + Vector3(0, 1.0, 0))
				hunt.damage_foe(best, amount, self, (to - from).normalized(), 2.0)
				from = to
				amount *= 0.85
			if pts.size() > 1:
				hunt.fx.lightning(pts, col, &"light")
				Sfx.play("chain", -6.0)
		"lance":
			hunt.spawn_proj("wave", flat_pos() + fwd * 0.8, fwd * 24.0, dmg, 99, self, {"life": reach / 24.0, "width": float(fdef["width"])})
			hunt.fx.slash(flat_pos(), aim_yaw, 1.6, 40, col, false, 0.15)


## The Shockwave card: every melee swing also sends a wave forward.
func _wave(fwd: Vector3) -> void:
	if hunt.cards.get("wave", 0) <= 0:
		return
	var wl: int = hunt.cards["wave"]
	var jd := int(hunt.cards.get("judgement_day", 0)) > 0
	Sfx.play("wave", -7.0, 0.85 if jd else 1.0)
	hunt.spawn_proj("wave", flat_pos() + fwd * 0.8, fwd * 15.0, dmg * (0.45 + 0.15 * wl), 99, self, {"life": 0.35 + 0.08 * wl, "width": (1.2 + 0.2 * wl) * (2.0 if jd else 1.0), "stun": 0.5 if jd else 0.0})


# --- Weapon families ------------------------------------------------------

## The trail a swing leaves: the family's color, pulled toward fine metal's.
func _trail() -> Color:
	var col: Color = fdef["trail"]
	var wpn := Game.equipped(id, "weapon")
	if not wpn.is_empty() and int(wpn.get("mat", 0)) >= 1:
		col = col.lerp(GearDB.item_color(wpn).lightened(0.3), 0.55)
	return col


## Foes in a swing: within `r` and inside `deg` degrees of the aim (close ones
## always count, so nothing hugging the hero is missed).
func _in_arc(r: float, deg: float) -> Array:
	var out := []
	for f in hunt.foes_near(position, r + 1.5):
		var to: Vector3 = f.flat_pos() - flat_pos()
		if to.length() > r + f.radius:
			continue
		if deg < 360.0 and absf(angle_difference(aim_yaw, atan2(to.x, to.z))) > deg_to_rad(deg) * 0.5 + 0.2 and to.length() > 0.9:
			continue
		out.append(f)
	return out


func _hit_feel(hit: int, heavy := false) -> void:
	if hit <= 0:
		return
	Sfx.play("hit", -2.0)
	hunt.hitstop((0.06 if heavy else 0.035) if hit < 4 else (0.08 if heavy else 0.06))
	hunt.shake((0.2 if heavy else 0.12) + 0.03 * mini(hit, 5))


func _family_impact(fwd: Vector3) -> void:
	var col := _trail()
	Sfx.play(str(fdef["sfx"]), -4.0)
	match str(fdef["attack"]):
		"cleave", "rune":
			var hit := 0
			for f in _in_arc(reach, arc):
				hunt.damage_foe(f, dmg, self, (f.flat_pos() - flat_pos()).normalized(), 5.5)
				hit += 1
			hunt.fx.slash(flat_pos(), aim_yaw, reach * 1.05, arc, col, swing_i % 2 == 0, 0.2)
			Sfx.play("swing", -8.0)
			_hit_feel(hit)
			if str(fdef["attack"]) == "rune":
				# A blade of light flies on from every cut.
				hunt.spawn_proj("wave", flat_pos() + fwd * 0.8, fwd * 16.0, dmg * 0.6, 99, self, {"life": 0.5, "width": 1.6})
		"slam":
			# The head lands a step ahead: everything around it is stunned and
			# thrown outward from the blow.
			var at := flat_pos() + fwd * minf(reach * 0.6, 1.6)
			var r := float(fdef["slam_r"]) * reach / maxf(float(DB.HEROES[id]["range"]) * float(fdef["range"]), 0.1)
			var hit := 0
			for f in hunt.foes_near(at, r + 1.5):
				var to: Vector3 = f.flat_pos() - at
				if to.length() > r + f.radius:
					continue
				hunt.damage_foe(f, dmg, self, to.normalized(), float(fdef["knock"]))
				if f.alive:
					f.stun_t = maxf(f.stun_t, float(fdef["stun"]))
				hit += 1
			# Cracked earth and debris kicked out of the blow, not a ring.
			hunt.fx.vfx.nova(&"physical", at, r * 1.1, 0.3, Fx.VfxLib.NO_TINT, &"light")
			hunt.fx.vfx.impact(&"physical", at, r * 0.7, Fx.VfxLib.NO_TINT, &"light")
			Sfx.play("impact", -4.0)
			hunt.shake(0.22)
			_hit_feel(hit, true)
		"sweep":
			# The OSRS scythe: one wide reap, and anything big takes the
			# blade's follow-through twice more.
			var hit := 0
			var echo: Array = fdef["echo"]
			for f in _in_arc(reach, arc):
				hunt.damage_foe(f, dmg, self, (f.flat_pos() - flat_pos()).normalized(), 4.5)
				hit += 1
				if f is Boss or bool(f.get("elite")):
					for k in echo.size():
						_later.append({"t": 0.12 * (k + 1), "foe": f, "amount": dmg * float(echo[k])})
			hunt.fx.slash(flat_pos(), aim_yaw, reach * 1.08, arc, col, false, 0.34)
			hunt.fx.slash(flat_pos(), aim_yaw, reach * 0.8, arc * 0.85, col.lightened(0.3), false, 0.26)
			Sfx.play("swing", -6.0, 0.8)
			_hit_feel(hit)
		"flurry":
			_flurry_swing(swing_i % 2 == 0)
			for k in int(fdef["hits"]) - 1:
				_later.append({"t": 0.11 * (k + 1), "swing": swing_i % 2 != (k % 2)})
		"thrust":
			# A line straight ahead, through everything in it.
			var half := float(fdef["width"]) * 0.5
			var hit := 0
			for f in hunt.foes_near(position, reach + 1.5):
				var to: Vector3 = f.flat_pos() - flat_pos()
				var along := to.dot(fwd)
				if along < -0.4 or along > reach + f.radius:
					continue
				if absf(to.cross(fwd).y) > half + f.radius:
					continue
				hunt.damage_foe(f, dmg, self, fwd, 6.5)
				hit += 1
			hunt.fx.slash(flat_pos() - fwd * 0.4, aim_yaw, reach * 1.1, 30, col, false, 0.18)
			hunt.fx.slash(flat_pos() - fwd * 0.4, aim_yaw, reach * 1.18, 30, Color(1, 1, 1), true, 0.12)
			Sfx.play("swing", -7.0, 1.2)
			_hit_feel(hit)
		"throw":
			var spd := float(fdef["speed"])
			hunt.spawn_proj("throwaxe", flat_pos() + fwd * 0.6, fwd * spd, dmg, 99, self, {"life": reach / spd * 2.0, "back": reach / spd})


func _flurry_swing(left: bool) -> void:
	var hit := 0
	for f in _in_arc(reach, arc):
		hunt.damage_foe(f, dmg, self, (f.flat_pos() - flat_pos()).normalized(), 3.0)
		hit += 1
	hunt.fx.slash(flat_pos(), aim_yaw + (0.25 if left else -0.25), reach * 1.0, arc, _trail(), left, 0.14)
	Sfx.play("swing", -9.0, 1.15 if left else 1.0)
	_hit_feel(hit)


func _tick_later(dt: float) -> void:
	var i := 0
	while i < _later.size():
		var l: Dictionary = _later[i]
		l["t"] = float(l["t"]) - dt
		if float(l["t"]) > 0.0:
			i += 1
			continue
		_later.remove_at(i)
		if l.has("swing"):
			_flurry_swing(bool(l["swing"]))
			continue
		var f: Actor = l["foe"]
		if is_instance_valid(f) and f.alive:
			hunt.damage_foe(f, float(l["amount"]), self, Vector3.ZERO, 0.0)
			hunt.fx.slash(f.flat_pos() - dir_of(aim_yaw) * 1.2, aim_yaw, 1.8, 120, _trail(), randf() < 0.5, 0.16)


# --- Dash and super ------------------------------------------------------

func try_dash() -> bool:
	if dash_cd > 0.0 or dash_t > 0.0 or super_t > 0.0 or not alive or bool(hunt.omen.get("no_dash", false)):
		return false
	hunt.dashes += 1
	perfect_used = false
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
	# Barkbound set: the dash leaves a trail of thorns.
	if flags.has("thorn_dash"):
		hunt.add_pyre(flat_pos(), 1.4, 2.5, dmg * float(flags["thorn_dash"]))
	# Bow and staff dash out of a crowd: the dead at their heels are thrown back.
	if def["style"] != "melee":
		for f in hunt.foes_near(position, 2.6):
			if f is Enemy:
				f.push((f.flat_pos() - flat_pos()).normalized(), 9.0)
	Sfx.play("dash", -4.0)
	Sfx.play("dodge", -8.0)
	Ui.buzz(12, 0.3)
	return true


## Bow and staff heroes standing still aim truer (DB.STEADY).
func steady() -> bool:
	return def["style"] != "melee" and still_t >= float(DB.STEADY["after"])


## Damage multiplier from the hero's own state: riposte and steady aim.
func hit_mult() -> float:
	var m := 1.0
	if riposte_t > 0.0:
		m *= 1.0 + float(DB.PERFECT_DODGE["dmg"])
	if steady():
		m *= 1.0 + float(DB.STEADY["dmg"])
	m *= 1.0 + 0.03 * rampage
	return m


func try_potion() -> bool:
	if potions <= 0 or not alive or hp >= max_hp:
		return false
	potions -= 1
	if potion_cd <= 0.0:
		potion_cd = float(DB.POTION["cd"])
	hp = minf(hp + max_hp * float(DB.POTION["heal"]), max_hp)
	hunt.fx.vfx.impact(&"heal", flat_pos(), 1.4, Fx.VfxLib.NO_TINT, &"skill")
	Sfx.play("levelup", -8.0, 1.3)
	Ui.buzz(20, 0.4)
	return true


func super_ready() -> bool:
	return super_charge >= 1.0 and super_t <= 0.0 and super_lock <= 0.0 and alive


func try_super() -> bool:
	if not super_ready():
		return false
	super_charge = 0.0
	super_lock = float(DB.SUPER["lock"])
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
			whirl_n = 0
			tree.active = false
			play(def["anim"]["super"], 0.1, 1.6)
			Sfx.play("blades", -2.0)
			Sfx.play("fire_trail", -4.0, 0.8)
			# The spin becomes a column of fire.
			hunt.fx.tornado(self, Color(1.0, 0.42, 0.12), super_t)
			hunt.fx.vfx.nova(&"fire", flat_pos(), 3.4, 0.4, Fx.VfxLib.NO_TINT, &"big")
		"volley":
			super_t = 0.35
			act(def["anim"]["super"], 0.35, true)
			var n := 15
			for i in n:
				var a := rotation.y + (i - (n - 1) * 0.5) * deg_to_rad(6.0)
				var d := dir_of(a)
				hunt.spawn_proj("arrow", flat_pos() + d * 0.5, d * 30.0, dmg * 1.7 * super_dmg, 99, self, {"super": true})
			hunt.shake(0.25)
			Sfx.play("volley", 0.0)
			# The sky goes dark with arrows: a dim, and a rain that falls
			# everywhere around (only the volleys on foes do damage).
			for j in 26:
				var cp := flat_pos() + Vector3(randf_range(-9.0, 9.0), 0, randf_range(-9.0, 9.0))
				hunt.fx.fall("arrow", cp, randf_range(0.15, 0.95), 0.28, func(): hunt.fx.puff(cp, Color(0.32, 0.27, 0.22, 0.4), 2, 0.4, 1.0))
			# A second wave from above, onto the foes the fan runs through.
			var rain := _foes_in(12.0, 5)
			for k in rain.size():
				var rp: Vector3 = (rain[k] as Actor).flat_pos()
				for j in 5:
					var ap := rp + Vector3(randf_range(-1.6, 1.6), 0, randf_range(-1.6, 1.6))
					hunt.fx.fall("arrow", ap, 0.25 + 0.05 * (k * 5 + j), 0.28, func(): _arrow_hit(ap, dmg * 0.9 * super_dmg))
		"shadowstep":
			super_t = 0.45
			invuln = 1.0
			act(def["anim"]["super"], 0.5, true)
			Sfx.play("blades", -2.0)
			var marks := _foes_in(9.0, 6)
			for m in marks:
				var mf := m as Actor
				hunt.fx.puff(flat_pos(), Color(0.1, 0.12, 0.1, 0.5), 4, 0.5, 1.0)
				position = hunt.arena.resolve(mf.flat_pos() - dir_of(yaw_to(position, mf.position)) * 0.9, radius)
				hunt.damage_foe(mf, dmg * 2.4 * super_dmg, self, dir_of(yaw_to(position, mf.position)), 2.0)
				hunt.fx.slash(mf.flat_pos(), randf() * TAU, 1.8, 140, Color(0.6, 1.0, 0.7), randf() < 0.5, 0.18)
			if marks.is_empty():
				position = hunt.arena.resolve(flat_pos() + fwd * 4.0, radius)
			hunt.shake(0.2)
		"meteor":
			super_t = 0.5
			act(def["anim"]["super"], 0.6, true)
			hunt.fx.vfx.cast(&"fire", flat_pos(), 1.6, Fx.VfxLib.NO_TINT, &"big")
			var arm := int(hunt.cards.get("armageddon", 0)) > 0
			meteor_shower(14 if arm else 9, dmg * 3.2 * super_dmg, 2.9, 13.0)
			hunt.shake(0.3)
			Sfx.play("charge", -3.0, 0.7)
	# The name goes up where the hero will be (the Knight's leap lands away).
	hunt.super_moment(leap_to if super_kind == "slam" else flat_pos())
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
					hunt.damage_foe(f, dmg * 0.75 * super_dmg, self, to.normalized(), 3.0)
					any = true
				hunt.fx.slash(flat_pos(), randf() * TAU, 3.2, 360, Color(1.0, 0.55, 0.25), false, 0.22)
				hunt.fx.embers_at(flat_pos(), Color(1.0, 0.6, 0.2), 5, 2.4)
				# Each turn of the spin whooshes past, rising as it winds up.
				whirl_n += 1
				Sfx.play("whirl", -5.0, 0.9 + 0.04 * mini(whirl_n, 6))
				if whirl_n % 3 == 0:
					Sfx.play("fire_trail", -9.0, 0.9)
				if any:
					Sfx.play("hit", -6.0)
			if super_t <= 0.0:
				tree.active = true
				cur_anim = ""
	if super_t <= 0.0:
		super_kind = ""


func _slam_land() -> void:
	var at := flat_pos()
	hunt.fx.vfx.nova(&"physical", at, 5.0, 0.45, Fx.VfxLib.NO_TINT, &"big")
	hunt.fx.vfx.impact(&"holy", at, 2.6, Fx.VfxLib.NO_TINT, &"big")
	hunt.fx.puff(at, Color(0.35, 0.3, 0.25, 0.7), 10, 2.5, 4.0)
	for f in hunt.foes_near(position, 4.6):
		var to: Vector3 = f.flat_pos() - at
		hunt.damage_foe(f, dmg * 3.6 * super_dmg, self, to.normalized(), 13.0)
		if f.alive:
			f.stun_t = 1.6
	for f2 in _foes_in(6.5, 6):
		hunt.fx.sky_bolt(f2.flat_pos(), Color(1.0, 0.88, 0.5), 0.22)
		if f2.alive:
			hunt.damage_foe(f2, dmg * 1.5 * super_dmg, self, Vector3.ZERO, 3.0)
	# Judgement: a crown of lightning comes down around the knight.
	for i in 8:
		var bp := at + Vector3.FORWARD.rotated(Vector3.UP, TAU * i / 8.0) * 3.6
		get_tree().create_timer(0.035 * i, false).timeout.connect(func():
			if is_instance_valid(hunt):
				hunt.fx.sky_bolt(bp, Color(0.85, 0.92, 1.0), 0.14, 12.0))
	hunt.cam.punch = maxf(hunt.cam.punch, 0.12)
	hunt.shake(0.7)
	hunt.hitstop(0.09)
	Ui.buzz(70, 0.8)
	Sfx.play("charge_land", 0.0)
	Sfx.play("thunder", -4.0)
	Sfx.play("meteor", -3.0)


# --- Cards that act on their own -----------------------------------------

func _sync_blades(level: int) -> void:
	var blade_model := "axe_1handed.gltf" if id == "barbarian" else "sword_1handed.gltf"
	var want := 0 if level <= 0 else level + 1
	if int(hunt.cards.get("bladestorm", 0)) > 0:
		want *= 2
	while blades.size() < want:
		var b := KK.prop(KK.WEAPON_DIR + blade_model)
		for mi in b.find_children("*", "MeshInstance3D", true, false):
			Fx.toon(mi as MeshInstance3D, Color(0.55, 0.85, 1.0))
		b.scale = Vector3.ONE * 1.3
		hunt.world.add_child(b)
		blades.append(b)


func _tick_cards(dt: float) -> void:
	var c := hunt.cards
	# Orbiting blades.
	if not blades.is_empty():
		blade_angle += dt * 3.4 * (1.6 if int(c.get("bladestorm", 0)) > 0 else 1.0)
		var bl: int = c.get("blades", 0)
		var r := 2.3 + 0.15 * bl
		for i in blades.size():
			var a := blade_angle + TAU * i / blades.size()
			var p := flat_pos() + Vector3(sin(a), 0, cos(a)) * r
			var b := blades[i]
			b.position = p + Vector3(0, 0.9, 0)
			b.rotation = Vector3(0, a + PI * 0.5, PI * 0.5)
			# A solid swipe wake behind each blade.
			if randf() < 0.16:
				hunt.fx.vfx.crescent(flat_pos(), r, a - 0.8, a, 0.2, Color(0.45, 0.8, 1.0), 0.16, 0.9)
			for f in hunt.foes_near(p, 0.9):
				if f.has_method("can_hit") and f.can_hit(1000 + i, 0.45):
					hunt.damage_foe(f, dmg * (0.4 + 0.1 * bl), self, (f.flat_pos() - flat_pos()).normalized(), 4.0)
					hunt.fx.burst(p, Color(0.5, 0.8, 1.0), 6, 5.0)
					Sfx.play("blade_hit", -8.0, randf_range(0.9, 1.2))
	# Storm call: chain lightning.
	var sl: int = c.get("storm", 0)
	if sl > 0:
		storm_t -= dt
		if storm_t <= 0.0:
			storm_t = maxf(3.2 - 0.45 * sl, 1.2)
			_storm(2 + sl + (3 if int(c.get("tempest", 0)) > 0 else 0), dmg * (1.0 + 0.25 * sl))
	# Fire nova.
	var nl: int = c.get("nova", 0)
	if nl > 0:
		nova_t -= dt
		if nova_t <= 0.0:
			nova_t = maxf(5.0 - 0.7 * nl, 2.0)
			var r2 := (3.4 + 0.5 * nl) * (1.5 if int(c.get("inferno_heart", 0)) > 0 else 1.0)
			hunt.fx.flame_burst(flat_pos(), r2, true, Color(1.0, 0.55, 0.18), &"skill")
			hunt.shake(0.15)
			var struck := 0
			for f in hunt.foes_near(position, r2):
				hunt.damage_foe(f, dmg * (1.2 + 0.3 * nl), self, (f.flat_pos() - flat_pos()).normalized(), 7.0)
				struck += 1
			if int(c.get("inferno_heart", 0)) > 0 and struck > 0:
				hp = minf(hp + max_hp * minf(0.03 * struck, 0.10) * hunt.heal_mult(), max_hp)
			Sfx.play("nova", -3.0)
	_tick_wisp(dt, int(c.get("wisp", 0)))
	_tick_powers(dt, c)
	_tick_road_cards(dt, c)
	# Bone ward.
	var wl: int = c.get("ward", 0)
	if wl > 0 and not ward_up:
		ward_t -= dt
		if ward_t <= 0.0:
			ward_up = true
			ward_mesh.visible = true
			Sfx.play("unlock_start", -8.0)
	ward_mesh.visible = ward_up


# --- Hellfire Wisp: a fire spirit at the shoulder, spitting fire bolts --------

var wisp: Node3D
var wisp_t := 1.2
var wisp_angle := 0.0


func _tick_wisp(dt: float, level: int) -> void:
	if level <= 0:
		return
	if wisp == null:
		wisp = hunt.fx.make_wisp()
		hunt.world.add_child(wisp)
		wisp.position = flat_pos() + Vector3(0, 2.3, 0)
		hunt.fx.flame_burst(flat_pos(), 1.6, false, Color(1.0, 0.55, 0.18), &"skill")
	wisp.visible = alive
	wisp_angle += dt * 1.4
	var want := flat_pos() + Vector3(sin(wisp_angle) * 1.1, 2.3 + sin(wisp_angle * 2.3) * 0.2, cos(wisp_angle) * 1.1)
	wisp.position = wisp.position.lerp(want, minf(dt * 8.0, 1.0))
	if randf() < 0.45:
		hunt.fx.embers_at(wisp.position - Vector3(0, 0.6, 0), Color(1.0, 0.5, 0.15), 1, 0.12)
	wisp_t -= dt
	if wisp_t > 0.0:
		return
	wisp_t = maxf(2.0 - 0.3 * level, 0.8)
	# Random foes in reach, not the nearest: the fire goes where it likes.
	var pool := _foes_in(11.0, 14)
	if pool.is_empty():
		wisp_t = 0.4
		return
	pool.shuffle()
	var n := mini(1 + level / 2, pool.size())
	for i in n:
		# By id, not by reference: the foe may be freed before the timer fires.
		var fid: int = (pool[i] as Actor).get_instance_id()
		get_tree().create_timer(0.14 * i, false).timeout.connect(func():
			var foe := instance_from_id(fid) as Actor
			if alive and is_instance_valid(wisp) and foe != null and foe.alive:
				_wisp_bolt(foe, dmg * (0.8 + 0.25 * level), 1.3 + 0.2 * level))


func _wisp_bolt(foe: Actor, amount: float, splash_r: float) -> void:
	var from := Vector3(wisp.position.x, 0, wisp.position.z)
	var d := (foe.flat_pos() - from).normalized()
	hunt.spawn_proj("firebolt", from + d * 0.3, d * 15.0, amount, 1, self, {"splash": splash_r, "home": true, "life": 1.4})
	hunt.fx.flare(wisp.position - Vector3(0, 0.9, 0), Color(1.0, 0.6, 0.2))
	hunt.fx.burst(wisp.position - Vector3(0, 0.9, 0), Color(1.0, 0.6, 0.25), 5, 4.0)
	wisp.scale = Vector3.ONE * 1.35
	wisp.create_tween().tween_property(wisp, "scale", Vector3.ONE, 0.18)
	Sfx.play("firebolt", -5.0)


# --- Class powers: each hero's own signature cards ---------------------------

var smite_t := 3.0
var quake_t := 4.0
var axe_t := 2.0
var meteor_t := 4.0
var frost_t := 5.0
var barrage_t := 5.0
var road_t := {}


## The road epics: each fires one of the class powers above on its own timer.
func _tick_road_cards(dt: float, c: Dictionary) -> void:
	for id: String in ["oath_storm", "shockwave", "rime_trap", "storm_arrows", "skybolt", "rift_quake", "thunder_cry", "skyfall"]:
		var lv: int = c.get(id, 0)
		if lv <= 0:
			continue
		road_t[id] = float(road_t.get(id, 3.0)) - dt
		if float(road_t[id]) > 0.0:
			continue
		match id:
			"oath_storm", "storm_arrows":
				road_t[id] = maxf(3.4 - 0.45 * lv, 1.4)
				_storm(2 + lv, dmg * (0.9 + 0.25 * lv))
			"shockwave", "rift_quake":
				road_t[id] = maxf(4.8 - 0.6 * lv, 2.2)
				_quake(3.4 + 0.5 * lv, dmg * (1.0 + 0.3 * lv), false)
			"rime_trap":
				road_t[id] = maxf(6.0 - 0.8 * lv, 3.0)
				_frost_ring(3.6 + 0.6 * lv, dmg * 0.7)
			"skybolt", "thunder_cry":
				road_t[id] = maxf(3.6 - 0.5 * lv, 1.4)
				_smite(1 + lv, dmg * (1.7 + 0.4 * lv), false)
			"skyfall":
				road_t[id] = maxf(5.2 - 0.7 * lv, 2.4)
				meteor_shower(2 + lv, dmg * (2.0 + 0.45 * lv), 2.2 + 0.2 * lv, 10.0)


func _tick_powers(dt: float, c: Dictionary) -> void:
	var sm: int = c.get("smite", 0)
	if sm > 0:
		smite_t -= dt
		if smite_t <= 0.0:
			smite_t = maxf(3.4 - 0.5 * sm, 1.3)
			_smite(1 + sm + (3 if int(c.get("heavens", 0)) > 0 else 0), dmg * (1.9 + 0.4 * sm), int(c.get("heavens", 0)) > 0)
	var qk: int = c.get("quake", 0)
	if qk > 0:
		quake_t -= dt
		if quake_t <= 0.0:
			quake_t = maxf(4.6 - 0.6 * qk, 2.0)
			_quake(3.8 + 0.5 * qk, dmg * (1.1 + 0.3 * qk), int(c.get("fault", 0)) > 0)
	var ax: int = c.get("axes", 0)
	if ax > 0:
		axe_t -= dt
		if axe_t <= 0.0:
			axe_t = maxf(2.4 - 0.35 * ax, 0.9)
			_throw_axes(1 + ax / 2, dmg * (0.9 + 0.2 * ax))
	var mt: int = c.get("meteor", 0)
	if mt > 0:
		meteor_t -= dt
		if meteor_t <= 0.0:
			meteor_t = maxf(5.0 - 0.7 * mt, 2.2)
			var arm := int(c.get("armageddon", 0)) > 0
			meteor_shower((2 + mt) * (2 if arm else 1), dmg * (2.2 + 0.5 * mt) * (2.0 if arm else 1.0), 2.3 + 0.25 * mt, 11.0)
	var fr: int = c.get("frost", 0)
	if fr > 0:
		frost_t -= dt
		if frost_t <= 0.0:
			frost_t = maxf(6.0 - 0.8 * fr, 3.0)
			_frost_ring(4.0 + 0.6 * fr, dmg * 0.8)
	var br: int = c.get("barrage", 0)
	if br > 0:
		barrage_t -= dt
		if barrage_t <= 0.0:
			barrage_t = maxf(5.5 - 0.8 * br, 2.5)
			var dl := int(c.get("deluge", 0)) > 0
			_arrow_storm(8 + 3 * br, dmg * 0.55, 3.2)
			if dl:
				get_tree().create_timer(0.9).timeout.connect(func():
					if alive and is_instance_valid(hunt):
						_arrow_storm(8 + 3 * br, dmg * 0.55, 3.2))


## Random living foes near the hero, nearest first.
func _foes_in(radius: float, n: int) -> Array:
	var out := []
	for f in hunt.foes_near(position, radius):
		if f.alive and f.state != "spawn":
			out.append(f)
	out.sort_custom(func(a, b): return a.flat_pos().distance_squared_to(flat_pos()) < b.flat_pos().distance_squared_to(flat_pos()))
	return out.slice(0, n)


## Holy lightning from the heavens onto the nearest foes.
func _smite(n: int, amount: float, stun: bool) -> void:
	var targets := _foes_in(10.0, n)
	if targets.is_empty():
		return
	Sfx.play("thunder", -4.0)
	for f: Actor in targets:
		var at := f.flat_pos()
		hunt.fx.sky_bolt(at, Color(1.0, 0.88, 0.5), 0.22)
		for o in hunt.foes_near(at, 1.8):
			hunt.damage_foe(o, amount, self, Vector3.ZERO, 4.0)
			if stun and o.alive:
				o.stun_t = maxf(o.stun_t, 1.0)
	hunt.shake(0.18)


## The ground bursts outward: rocks, dust, and everything near flung back.
func _quake(radius: float, amount: float, wide: bool) -> void:
	var r := radius * (1.7 if wide else 1.0)
	var at := flat_pos()
	hunt.fx.vfx.nova(&"physical", at, r, 0.45, Fx.VfxLib.NO_TINT, &"skill")
	hunt.fx.vfx.impact(&"physical", at, r * 0.6, Fx.VfxLib.NO_TINT, &"skill")
	hunt.fx.bone_burst(at, 6, 8.0)
	for f in hunt.foes_near(position, r):
		var to: Vector3 = f.flat_pos() - at
		hunt.damage_foe(f, amount, self, to.normalized(), 12.0)
		if f.alive:
			f.stun_t = maxf(f.stun_t, 0.5)
	hunt.shake(0.4)
	Sfx.play("quake", -5.0)


func _throw_axes(n: int, amount: float) -> void:
	var targets := _foes_in(10.0, n)
	if targets.is_empty():
		return
	for i in targets.size():
		var d: Vector3 = (targets[i].flat_pos() - flat_pos()).normalized()
		hunt.spawn_proj("axe", flat_pos() + d * 0.6, d * 14.0, amount, 3, self, {"life": 0.85})
	Sfx.play("swing", -4.0, 0.8)


## Meteors on the thickest part of the horde (or just ahead if it is empty).
func meteor_shower(count: int, amount: float, radius: float, reach_: float) -> void:
	var pool := _foes_in(reach_, 20)
	Sfx.play("meteor", -6.0)
	for i in count:
		var at: Vector3
		if pool.is_empty():
			at = hunt.arena.resolve(flat_pos() + dir_of(aim_yaw + randf_range(-0.8, 0.8)) * randf_range(4.0, 8.0), 0.5)
		else:
			at = (pool[randi() % pool.size()] as Actor).flat_pos() + Vector3(randf_range(-1.0, 1.0), 0, randf_range(-1.0, 1.0))
		var delay := 0.12 * i + randf() * 0.1
		hunt.fx.telegraph(0, at, 0.0, Vector2(radius, 0), 0.55 + delay, 0.6, &"fire")
		hunt.fx.fall("meteor", at, delay, 0.55, func(): _meteor_hit(at, amount, radius))


func _meteor_hit(at: Vector3, amount: float, radius: float) -> void:
	if not is_instance_valid(hunt) or hunt.phase == "defeat":
		return
	hunt.fx.flame_burst(at, radius * 1.2, true, Color(1.0, 0.55, 0.18), &"skill")
	hunt.fx.puff(at, Color(0.25, 0.2, 0.17, 0.7), 8, radius * 0.6, 3.0)
	for f in hunt.foes_near(at, radius + 1.0):
		if at.distance_to(f.flat_pos()) <= radius + f.radius:
			hunt.damage_foe(f, amount, self, (f.flat_pos() - at).normalized(), 8.0)
	if hunt.boss and hunt.boss.alive and at.distance_to(hunt.boss.flat_pos()) <= radius + hunt.boss.radius:
		hunt.damage_foe(hunt.boss, amount, self, Vector3.ZERO, 0.0)
	hunt.shake(0.14)
	Sfx.play("boom", -9.0, 1.2)
	Sfx.play("fire_hit", -8.0, 0.85)


func _frost_ring(radius: float, amount: float) -> void:
	var at := flat_pos()
	hunt.fx.vfx.nova(&"frost", at, radius, 0.4, Fx.VfxLib.NO_TINT, &"skill")
	hunt.fx.vfx.impact(&"frost", at, radius * 0.5, Fx.VfxLib.NO_TINT, &"skill")
	for f in hunt.foes_near(position, radius):
		hunt.damage_foe(f, amount, self, (f.flat_pos() - at).normalized(), 4.0)
		if f.alive and f.has_method("freeze"):
			f.freeze(1.8)
	Sfx.play("frost", -5.0)


## A volley of arrows falling on the densest cluster of foes in range.
func _arrow_storm(count: int, amount: float, radius: float) -> void:
	var best: Actor = null
	var best_n := 0
	for f in _foes_in(11.0, 24):
		var n := hunt.foes_near(f.flat_pos(), 2.6).size()
		if n > best_n:
			best_n = n
			best = f
	if best == null:
		return
	var center := best.flat_pos()
	hunt.fx.telegraph(0, center, 0.0, Vector2(radius, 0), 0.6, 0.6, &"physical")
	Sfx.play("volley", -6.0, 1.2)
	for i in count:
		var a := randf() * TAU
		var at := center + Vector3(sin(a), 0, cos(a)) * radius * sqrt(randf())
		var delay := 0.04 * i
		hunt.fx.fall("arrow", at, delay, 0.28, func(): _arrow_hit(at, amount))


func _arrow_hit(at: Vector3, amount: float) -> void:
	if not is_instance_valid(hunt):
		return
	hunt.fx.burst(at, Color(1.0, 0.9, 0.6), 3, 4.0)
	hunt.fx.puff(at, Color(0.4, 0.34, 0.26, 0.5), 2, 0.4, 1.5)
	for f in hunt.foes_near(at, 1.5):
		if at.distance_to(f.flat_pos()) <= 1.2 + f.radius:
			hunt.damage_foe(f, amount, self, Vector3.ZERO, 1.5)


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
		hunt.fx.lightning(pts, Color(0.6, 0.8, 1.0), &"skill")
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
	if wisp:
		wisp.visible = false


func revive() -> void:
	alive = true
	revived = true
	hp = max_hp * 0.5
	invuln = 2.0
	tree.active = true
	for b in blades:
		b.visible = true
	act("Spawn_Ground", 0.8, true)
