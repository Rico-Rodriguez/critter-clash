class_name Match
extends Node

signal leave_match
signal open_collection

var arena: Arena
var units: Array = []
var player_den: Unit
var enemy_den: Unit
var sparks := Roster.START_SPARKS
var ai_sparks := Roster.START_SPARKS
var time_left := Roster.MATCH_SECONDS
var over := false
var paused := false
var hand: Array = []
var next_card := ""
var pile: Array = []
var ai_hand: Array = []
var ai_next := ""
var ai_pile: Array = []
var ai_clock := 0.6
var player_merges := 0
var ai_merges := 0
var placed_once := false
var merged_once := false
var dusk_announced := false
var hitstop_until := 0
var shots: Array = []

var dragging := false
var drag_index := -1
var drag_species := ""
var quick_lane := 0

var ui: CanvasLayer
var timer_label: Label
var spark_bar: Control
var spark_text: Label
var hint_label: Label
var banner: Panel
var banner_title: Label
var banner_sub: Label
var card_roots: Array = []
var next_portrait: TextureRect
var next_name: Label
var player_bar: Control
var enemy_bar: Control
var p_burrow_l: Label
var p_burrow_r: Label
var e_burrow_l: Label
var e_burrow_r: Label
var flash_rect: ColorRect
var end_layer: Control
var pause_layer: Control
var banner_style: StyleBoxFlat
var _safe := {"l": 16, "t": 22, "r": 16, "b": 20}


func _ready() -> void:
	Engine.time_scale = 1.0
	var deck := _deal()
	hand = deck.hand
	next_card = deck.next
	pile = deck.pile
	var ai := _deal()
	ai_hand = ai.hand
	ai_next = ai.next
	ai_pile = ai.pile
	_spawn_structures()
	_build_ui()
	_refresh_cards()


func _exit_tree() -> void:
	Engine.time_scale = 1.0


func _process(dt: float) -> void:
	if Engine.time_scale < 0.99 and Time.get_ticks_msec() > hitstop_until and not paused:
		Engine.time_scale = 1.0
	if over or paused:
		_update_bars()
		return
	time_left -= dt
	if time_left <= Roster.DUSK_RUSH_AT and not dusk_announced:
		dusk_announced = true
		_popup(Vector3(0, 1.5, 0), "Dusk Rush", Color("ffb15a"))
	var regen := Roster.SPARK_REGEN * (1.4 if time_left <= Roster.DUSK_RUSH_AT else 1.0)
	sparks = minf(Roster.MAX_SPARKS, sparks + regen * dt)
	ai_sparks = minf(Roster.MAX_SPARKS, ai_sparks + regen * dt)
	ai_clock -= dt
	if ai_clock <= 0.0:
		ai_clock = 0.45
		_ai_think()
	for u in units:
		if is_instance_valid(u) and not u.dead:
			u.tick(dt)
	_separate()
	_tick_shots(dt)
	_reap()
	if time_left <= 0.0 and not over:
		_finish(_judge())
	_update_hud()
	if dragging:
		_move_drag(_pointer())


func _unhandled_input(event: InputEvent) -> void:
	if over or paused:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var keys := {KEY_1: 0, KEY_2: 1, KEY_3: 2, KEY_4: 3}
		if keys.has(event.keycode) and not dragging:
			_quick_play(int(keys[event.keycode]))
		elif OS.is_debug_build() and event.keycode == KEY_F:
			Engine.time_scale = 1.0 if Engine.time_scale > 1.5 else 4.0
		elif OS.is_debug_build() and event.keycode == KEY_K and enemy_den and not enemy_den.dying:
			_hurt(enemy_den, 900.0, null, false)


func _input(event: InputEvent) -> void:
	if not dragging or over:
		return
	var pos := Vector2.ZERO
	var ended := false
	if event is InputEventMouseMotion:
		pos = event.position
	elif event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pos = event.position
		ended = true
	elif event is InputEventScreenDrag:
		pos = event.position
	elif event is InputEventScreenTouch and not event.pressed:
		pos = event.position
		ended = true
	else:
		return
	if ended:
		_finish_drag(pos)
	else:
		_move_drag(pos)


func speed_bonus(unit: Unit) -> float:
	var bonus := 0.0
	for other in units:
		if other.team != unit.team or other == unit or other.dying or other.dead:
			continue
		var aura := float(other.stats.get("aura_speed", 0.0))
		if aura <= 0.0:
			continue
		if unit.flat_to(other) <= float(other.stats.get("aura_radius", 0.0)):
			bonus = maxf(bonus, aura)
	return bonus


func pick_target(unit: Unit) -> Unit:
	var best: Unit = null
	var best_d := float(unit.stats["sight"])
	for other in units:
		if other == unit or other.team == unit.team or other.dying or other.dead or other.structure:
			continue
		if not unit._can_hit(other):
			continue
		var d := unit.flat_to(other)
		if d < best_d:
			best_d = d
			best = other
	if best or unit.structure:
		return best
	best_d = float(unit.stats["sight"])
	for other in units:
		if other.team == unit.team or not other.structure or other.dying or other.dead:
			continue
		var d := unit.flat_to(other)
		if d < best_d:
			best_d = d
			best = other
	return best


func best_heal_target(unit: Unit) -> Unit:
	var best: Unit = null
	var best_ratio := 0.985
	var reach := float(unit.stats.get("heal_radius", 2.0)) + 3.4
	for other in units:
		if other.team != unit.team or other == unit or other.structure or other.dying or other.dead:
			continue
		if unit.flat_to(other) > reach:
			continue
		var ratio: float = other.hp / other.max_hp
		if ratio < best_ratio:
			best_ratio = ratio
			best = other
	return best


func enemy_anchor(team: int) -> Vector3:
	var den := enemy_den if team == 0 else player_den
	if den and is_instance_valid(den):
		return den.position
	return Vector3(0, 0, 8.2 if team == 0 else -8.2)


func deliver_attack(attacker: Unit, target: Unit) -> void:
	if attacker == null or attacker.dying or target == null or target.dying or target.dead:
		return
	if bool(attacker.stats.get("projectile", false)):
		_launch(attacker, target)
		AudioDirector.play_throttled("shoot", 0.045)
	else:
		_impact(attacker, target, target.position)


func aura_tick(unit: Unit) -> void:
	var radius := float(unit.stats.get("aura_radius", 1.5))
	var dps := float(unit.stats.get("aura_dps", 0.0))
	for other in units:
		if other.team == unit.team or other.dying or other.dead or other.structure:
			continue
		if unit.flat_to(other) <= radius:
			_hurt(other, dps * 0.25, unit, false)


func announce_death(unit: Unit) -> void:
	if unit.structure:
		AudioDirector.play("den")
		arena.add_shake(0.1 if unit.species == "den" else 0.05)
		if unit.species == "den" and not over:
			_finish("win" if unit.team == 1 else "lose")
		elif not over:
			_popup(unit.position, "Burrow down", Color("fff6ea"))
	else:
		AudioDirector.play_throttled("death", 0.09)
		arena.burst(unit.position, Color("fff1dc"), false)


func refresh_portraits() -> void:
	_refresh_cards()


func _deal() -> Dictionary:
	var bag := Roster.ids()
	bag.shuffle()
	return {"hand": [bag[0], bag[1], bag[2], bag[3]], "next": bag[4], "pile": [bag[5]]}


func _spawn_structures() -> void:
	player_den = _spawn_structure("den", 0, Vector3(0, 0, -8.2))
	enemy_den = _spawn_structure("den", 1, Vector3(0, 0, 8.2))
	_spawn_structure("burrow", 0, Vector3(-2.75, 0, -5.85))
	_spawn_structure("burrow", 0, Vector3(2.75, 0, -5.85))
	_spawn_structure("burrow", 1, Vector3(-2.75, 0, 5.85))
	_spawn_structure("burrow", 1, Vector3(2.75, 0, 5.85))


func _spawn_structure(kind: String, team: int, pos: Vector3) -> Unit:
	var base: Dictionary = Roster.DEN if kind == "den" else Roster.BURROW
	var stats := {
		"species": kind,
		"form": "base",
		"hp": float(base.hp),
		"dmg": float(base.dmg),
		"period": float(base.period),
		"range": float(base.range),
		"radius": float(base.radius),
		"sight": float(base.sight),
		"speed": 0.0,
		"hits_air": true,
		"projectile": true,
		"flying": false,
		"structure": true,
		"splash": 0.0,
		"gait": "walk",
	}
	return _spawn(team, stats, pos)


func _spawn(team: int, stats: Dictionary, pos: Vector3) -> Unit:
	var u := Unit.new()
	arena.units_root.add_child(u)
	u.position = Vector3(pos.x, 0, pos.z)
	u.configure(stats, team, self)
	u.build_visual()
	units.append(u)
	return u


func _spawn_critter(team: int, species: String, form: String, pos: Vector3) -> Unit:
	var stats := Roster.form_stats(species, form)
	var u := _spawn(team, stats, pos)
	u.lane_x = -2.55 if pos.x < 0.15 else 2.55
	return u


func _try_play(team: int, species: String, pos: Vector3) -> bool:
	var cost := Roster.cost(species)
	var energy := sparks if team == 0 else ai_sparks
	if energy + 0.001 < float(cost):
		return false
	var spot: Dictionary = _clamp_spawn(pos, team)
	if not bool(spot.get("ok", false)):
		return false
	var at: Vector3 = spot.pos
	var merge := _merge_near(team, species, at)
	if team == 0:
		sparks -= cost
	else:
		ai_sparks -= cost
	if merge:
		_evolve(merge, species)
	else:
		var nudged := _nudge(at, team)
		var u := _spawn_critter(team, species, "base", nudged)
		AudioDirector.play("deploy")
		AudioDirector.haptic(14)
		arena.burst(u.position, Color("fff8ee"), false)
		if team == 0:
			placed_once = true
	return true


func _evolve(unit: Unit, species: String) -> void:
	var at := unit.position
	var team := unit.team
	var lane := unit.lane_x
	var hab := arena.habitat_at(at)
	var form := Roster.resolve_form(species, hab, at)
	units.erase(unit)
	unit.queue_free()
	var evo := _spawn_critter(team, species, form, at)
	evo.lane_x = lane
	var native := Roster.branches(species).has(hab)
	var title := Roster.form_name(species, form)
	if not native:
		title += "  ·  nearest " + Roster.habitat_label(form)
	arena.burst(at, Roster.habitat_color(form), true)
	arena.add_shake(0.2)
	hitstop_until = Time.get_ticks_msec() + 80
	Engine.time_scale = 0.4
	AudioDirector.play("merge")
	AudioDirector.haptic(34)
	_popup(at + Vector3(0, 1.3, 0), title, Roster.habitat_color(form))
	_flash_screen(Roster.habitat_color(form))
	if team == 0:
		player_merges += 1
		merged_once = true
	else:
		ai_merges += 1


func _clamp_spawn(pos: Vector3, team: int) -> Dictionary:
	if team == 0 and pos.z > -0.2:
		return {"ok": false}
	if team == 1 and pos.z < 0.2:
		return {"ok": false}
	var z0 := -8.35
	var z1 := -0.72
	if team == 1:
		z0 = 0.72
		z1 = 8.35
	var p := Vector3(clampf(pos.x, -4.15, 4.15), 0, clampf(pos.z, z0, z1))
	for u in units:
		if not u.structure or u.team != team or u.dying:
			continue
		var d := Vector2(p.x, p.z).distance_to(Vector2(u.position.x, u.position.z))
		var need := float(u.stats["radius"]) + 0.4
		if d < need:
			var away := Vector3(p.x - u.position.x, 0, p.z - u.position.z)
			if away.length() < 0.05:
				away = Vector3(0.2, 0, -0.5 if team == 0 else 0.5)
			p = u.position + away.normalized() * need
			p.x = clampf(p.x, -4.15, 4.15)
			p.z = clampf(p.z, z0, z1)
	return {"ok": true, "pos": p}


func _nudge(pos: Vector3, team: int) -> Vector3:
	var p := pos
	for u in units:
		if u.team != team or u.dying or u.dead or u.structure:
			continue
		var d := Vector2(p.x, p.z).distance_to(Vector2(u.position.x, u.position.z))
		if d < 0.55:
			var away := Vector3(p.x - u.position.x, 0, p.z - u.position.z)
			if away.length() < 0.01:
				away = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1))
			p = u.position + away.normalized() * 0.62
	return p


func _merge_near(team: int, species: String, pos: Vector3) -> Unit:
	var best: Unit = null
	var best_d := Roster.MERGE_RADIUS
	for u in units:
		if u.team != team or u.species != species or u.form != "base" or u.dying or u.dead or u.structure:
			continue
		var d := Vector2(u.position.x, u.position.z).distance_to(Vector2(pos.x, pos.z))
		if d <= best_d:
			best_d = d
			best = u
	return best


func _launch(attacker: Unit, target: Unit) -> void:
	var hover := 1.5 if bool(attacker.stats.get("flying", false)) else 0.0
	var start := attacker.position + Vector3(0, 0.75 + hover, 0)
	var dest := target.position + Vector3(0, 0.55 + (1.2 if bool(target.stats.get("flying", false)) else 0.0), 0)
	var mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.09
	sphere.height = 0.18
	sphere.radial_segments = 8
	sphere.rings = 4
	mesh.mesh = sphere
	var col := Color("ffb15a") if attacker.team == 0 else Color("c5d4ff")
	mesh.material_override = StyleLib.flat_material(col, 1.6)
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	arena.effects.add_child(mesh)
	shots.append({
		"node": mesh,
		"from": start,
		"to": dest,
		"t": 0.0,
		"dur": maxf(0.1, start.distance_to(dest) / 11.0),
		"attacker": attacker,
		"target": target,
	})


func _tick_shots(dt: float) -> void:
	var keep: Array = []
	for shot in shots:
		shot.t += dt
		var k := clampf(float(shot.t) / float(shot.dur), 0.0, 1.0)
		var pos: Vector3 = shot.from.lerp(shot.to, k)
		pos.y += sin(k * PI) * 0.32
		(shot.node as Node3D).position = pos
		if k >= 1.0:
			var attacker: Unit = null
			var target: Unit = null
			if is_instance_valid(shot.attacker):
				attacker = shot.attacker
			if is_instance_valid(shot.target):
				target = shot.target
			if attacker != null and target != null and not target.dead and not target.dying:
				_impact(attacker, target, target.position)
			if is_instance_valid(shot.node):
				(shot.node as Node3D).queue_free()
		else:
			keep.append(shot)
	shots = keep


func _impact(attacker: Unit, target: Unit, at: Vector3) -> void:
	if attacker == null or not is_instance_valid(attacker):
		return
	var dmg := float(attacker.stats["dmg"])
	_hurt(target, dmg, attacker, true)
	_riders(attacker, target)
	var splash := float(attacker.stats.get("splash", 0.0))
	if splash > 0.25:
		for other in units:
			if other == target or other.team != target.team or other.dying or other.dead:
				continue
			if not is_instance_valid(target):
				break
			if other.flat_to(target) > splash:
				continue
			if bool(other.stats.get("flying", false)) and not bool(attacker.stats.get("hits_air", false)):
				continue
			_hurt(other, dmg * 0.62, attacker, true)
			_riders(attacker, other)
	arena.burst(at, Color("fff6ea"), splash > 1.2)


func _riders(attacker: Unit, victim: Unit) -> void:
	if victim == null or not is_instance_valid(victim) or victim.dead or victim.dying:
		return
	if float(attacker.stats.get("slow", 0.0)) > 0.0:
		victim.apply_slow(float(attacker.stats["slow"]), float(attacker.stats["slow_time"]))
	if float(attacker.stats.get("burn", 0.0)) > 0.0:
		victim.apply_burn(float(attacker.stats["burn"]), float(attacker.stats["burn_time"]))


func _hurt(target: Unit, amount: float, attacker: Unit, procs: bool) -> void:
	if target == null or not is_instance_valid(target) or target.dying or target.dead:
		return
	target.hp -= amount
	target.flash()
	if target.animator:
		target.animator.play_hit()
	if target.structure:
		AudioDirector.play_throttled("den", 0.07)
	else:
		AudioDirector.play_throttled("hit", 0.045)
	if procs and attacker and is_instance_valid(attacker) and float(target.stats.get("reflect", 0.0)) > 0.0:
		_hurt(attacker, amount * float(target.stats["reflect"]), null, false)
	if target.hp <= 0.0:
		target.die()


func _separate() -> void:
	for i in units.size():
		var a: Unit = units[i]
		if a.structure or a.dying or a.dead:
			continue
		for j in range(i + 1, units.size()):
			var b: Unit = units[j]
			if b.structure or b.dying or b.dead:
				continue
			if bool(a.stats.get("flying", false)) != bool(b.stats.get("flying", false)):
				continue
			var delta := Vector3(a.position.x - b.position.x, 0, a.position.z - b.position.z)
			var dist := delta.length()
			var need := (float(a.stats["radius"]) + float(b.stats["radius"])) * 0.7
			if dist < 0.001:
				a.position.x += 0.05
			elif dist < need:
				var push := delta.normalized() * (need - dist) * 0.4
				a.position += push
				b.position -= push


func _reap() -> void:
	var alive: Array = []
	for u in units:
		if not is_instance_valid(u):
			continue
		if u.dead:
			u.queue_free()
			continue
		alive.append(u)
	units = alive


func _ai_think() -> void:
	var best_score := 16.0
	var best_i := -1
	var best_pos := Vector3.ZERO
	for i in ai_hand.size():
		var species: String = ai_hand[i]
		if float(Roster.cost(species)) > ai_sparks:
			continue
		var merge := _best_ai_merge(species)
		var score := 6.0
		var pos := Vector3(-2.55 if randf() < 0.5 else 2.55, 0, 2.1)
		if merge:
			score += 78.0
			pos = merge.position
			if Roster.branches(species).has(arena.habitat_at(merge.position)):
				score += 12.0
		else:
			var left_p := _pressure(-2.55)
			var right_p := _pressure(2.55)
			if maxf(left_p, right_p) > 0.4:
				score += 24.0
				pos = Vector3(-2.55 if left_p >= right_p else 2.55, 0, 4.4)
			elif ai_sparks > 8.2:
				score += 10.0
			if species == "bramble":
				score += 5.0
			if species == "pip" and _team_hurt(1):
				score += 26.0
				pos.z = 5.2
		if score > best_score:
			best_score = score
			best_i = i
			best_pos = pos
	if best_i >= 0:
		var species: String = ai_hand[best_i]
		if _try_play(1, species, best_pos):
			var played: String = species
			ai_hand[best_i] = ai_next
			ai_next = ai_pile.pop_front()
			ai_pile.append(played)


func _best_ai_merge(species: String) -> Unit:
	var best: Unit = null
	var best_s := -999.0
	for u in units:
		if u.team != 1 or u.species != species or u.form != "base" or u.dying or u.dead or u.structure:
			continue
		var score := 4.0
		if Roster.branches(species).has(arena.habitat_at(u.position)):
			score += 8.0
		score += clampf(u.hp / u.max_hp, 0.0, 1.0) * 3.0
		if score > best_s:
			best_s = score
			best = u
	return best


func _pressure(lane: float) -> float:
	var p := 0.0
	for u in units:
		if u.team != 0 or u.dying or u.dead or u.structure:
			continue
		if absf(u.position.x - lane) > 2.1:
			continue
		if u.position.z > -0.3:
			p += 1.0 + maxf(0.0, u.position.z) * 0.2
	return p


func _team_hurt(team: int) -> bool:
	for u in units:
		if u.team == team and not u.structure and not u.dying and u.hp < u.max_hp * 0.85:
			return true
	return false


func _quick_play(index: int) -> void:
	if index >= hand.size():
		return
	var lanes := [-2.7, -0.9, 1.0, 2.7]
	var pos := Vector3(lanes[quick_lane % 4], 0, -2.5)
	quick_lane += 1
	if _try_play(0, hand[index], pos):
		_cycle_player(index)
		_refresh_cards()
	else:
		AudioDirector.play("error")
		_shake_card(index)


func _start_drag(index: int, screen: Vector2) -> void:
	if over or paused or index >= hand.size():
		return
	dragging = true
	drag_index = index
	drag_species = hand[index]
	banner.visible = true
	if index < card_roots.size():
		var card: Control = card_roots[index]
		card.pivot_offset = card.size * 0.5
		var tw := card.create_tween()
		tw.tween_property(card, "scale", Vector2(1.06, 1.06), 0.06)
	_move_drag(screen)


func _move_drag(screen: Vector2) -> void:
	if not dragging:
		return
	var world := _ground_at(screen)
	var spot: Dictionary = _clamp_spawn(world, 0)
	var ok := bool(spot.get("ok", false)) and sparks + 0.001 >= float(Roster.cost(drag_species))
	var preview: Vector3 = spot.pos if ok else world
	var merge := _merge_near(0, drag_species, preview) if ok else null
	var focus: Vector3 = merge.position if merge else preview
	var hab := arena.habitat_at(focus)
	var form := Roster.resolve_form(drag_species, hab, focus)
	var ghost_form := form if merge else "base"
	arena.show_ghost(drag_species, focus if merge else preview, ok, ghost_form)
	var color := Roster.habitat_color(form)
	if not ok:
		color = Color("e05a4f")
	arena.show_ring(focus, color, 1.15 if merge else 1.0)
	var native := Roster.branches(drag_species).has(hab)
	if merge:
		banner_title.text = Roster.form_name(drag_species, form)
		banner_sub.text = "Release to merge  ·  " + Roster.habitat_label(hab)
		if not native:
			banner_sub.text = "Nearest branch  ·  " + Roster.habitat_label(form)
	else:
		banner_title.text = Roster.form_name(drag_species, "base")
		if not ok:
			banner_sub.text = "Your half only" if sparks + 0.001 >= float(Roster.cost(drag_species)) else "Not enough sparks"
		elif native:
			banner_sub.text = "A twin here becomes " + Roster.form_name(drag_species, form)
		else:
			banner_sub.text = Roster.habitat_label(hab) + " follows " + Roster.habitat_label(form)
	if banner_style:
		banner_style.bg_color = Color(color.r, color.g, color.b, 0.92)


func _finish_drag(screen: Vector2) -> void:
	if not dragging:
		return
	var index := drag_index
	var species := drag_species
	dragging = false
	drag_index = -1
	arena.hide_ghost()
	arena.hide_ring()
	banner.visible = false
	if index < card_roots.size() and is_instance_valid(card_roots[index]):
		var tw := (card_roots[index] as Control).create_tween()
		tw.tween_property(card_roots[index], "scale", Vector2.ONE, 0.08)
	var world := _ground_at(screen)
	if _try_play(0, species, world):
		_cycle_player(index)
		_refresh_cards()
	else:
		AudioDirector.play("error")
		AudioDirector.haptic(8)
		_shake_card(index)


func _cycle_player(index: int) -> void:
	var played: String = hand[index]
	hand[index] = next_card
	next_card = str(pile.pop_front())
	pile.append(played)


func _ground_at(screen: Vector2) -> Vector3:
	var origin := arena.camera.project_ray_origin(screen)
	var dir := arena.camera.project_ray_normal(screen)
	if absf(dir.y) < 0.0001:
		return Vector3.ZERO
	var t := -origin.y / dir.y
	return origin + dir * t


func _pointer() -> Vector2:
	return get_viewport().get_mouse_position()


func _judge() -> String:
	var p := player_den.hp if is_instance_valid(player_den) else 0.0
	var e := enemy_den.hp if is_instance_valid(enemy_den) else 0.0
	if absf(p - e) < 2.0:
		p = _side_hp(0)
		e = _side_hp(1)
	if absf(p - e) < 2.0:
		return "draw"
	return "win" if p > e else "lose"


func _side_hp(team: int) -> float:
	var total := 0.0
	for u in units:
		if u.structure and u.team == team and not u.dead:
			total += maxf(u.hp, 0.0)
	return total


func _finish(result: String) -> void:
	if over:
		return
	over = true
	dragging = false
	arena.hide_ghost()
	arena.hide_ring()
	banner.visible = false
	Engine.time_scale = 1.0
	AudioDirector.play("win" if result == "win" else "lose")
	AudioDirector.haptic(48 if result == "win" else 20)
	_show_end(result)


func _show_end(result: String) -> void:
	end_layer = Control.new()
	end_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	end_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	ui.add_child(end_layer)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.15, 0.08, 0.06, 0.45)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	end_layer.add_child(dim)
	var panel := Panel.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -250
	panel.offset_right = 250
	panel.offset_top = -280
	panel.offset_bottom = 280
	panel.add_theme_stylebox_override("panel", UiKit.panel(Color("fff6ea"), 32))
	end_layer.add_child(panel)
	var title := "The den is yours" if result == "win" else ("Shared dusk" if result == "draw" else "Your den fell")
	var subtitle := "Ember would call that a fair sneeze." if result == "draw" else ("Your glade holds." if result == "win" else "The other den is still singing.")
	var h := UiKit.label(title, 40, Color("3a241c"), "x")
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h.position = Vector2(24, 28)
	h.size = Vector2(452, 90)
	h.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(h)
	var s := UiKit.label(subtitle, 20, Color("6a4636"), "m")
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	s.position = Vector2(36, 120)
	s.size = Vector2(428, 70)
	panel.add_child(s)
	var p_hp := 0.0 if not is_instance_valid(player_den) else maxf(player_den.hp, 0.0)
	var e_hp := 0.0 if not is_instance_valid(enemy_den) else maxf(enemy_den.hp, 0.0)
	var stats := UiKit.label("Your den %d%%    Theirs %d%%\nMerges %d    Their merges %d" % [
		int(round(100.0 * p_hp / Roster.DEN.hp)),
		int(round(100.0 * e_hp / Roster.DEN.hp)),
		player_merges, ai_merges
	], 20, Color("3a241c"), "b")
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats.position = Vector2(36, 190)
	stats.size = Vector2(428, 80)
	panel.add_child(stats)
	var again := UiKit.button("Rematch", 360, 74)
	again.position = Vector2(70, 290)
	again.pressed.connect(func() -> void:
		var parent_node := get_parent()
		parent_node.start_match()
	)
	panel.add_child(again)
	var guide := UiKit.button("Field Guide", 360, 64)
	guide.position = Vector2(70, 372)
	guide.add_theme_stylebox_override("normal", UiKit.chunky(Color("d7efc4"), Color("6d8a48")))
	guide.add_theme_stylebox_override("hover", UiKit.chunky(Color("e4f6d4"), Color("6d8a48")))
	guide.add_theme_stylebox_override("pressed", UiKit.chunky(Color("c4e0ae"), Color("547038"), true))
	guide.pressed.connect(func() -> void: open_collection.emit())
	panel.add_child(guide)
	var menu := UiKit.button("Menu", 360, 64)
	menu.position = Vector2(70, 448)
	menu.add_theme_stylebox_override("normal", UiKit.chunky(Color("f3e2cf"), Color("a88868")))
	menu.add_theme_stylebox_override("hover", UiKit.chunky(Color("fff1e2"), Color("a88868")))
	menu.add_theme_stylebox_override("pressed", UiKit.chunky(Color("e6d0b8"), Color("8a6a50"), true))
	menu.pressed.connect(func() -> void: leave_match.emit())
	panel.add_child(menu)


func _build_ui() -> void:
	UiKit.ensure()
	_safe = _read_safe()
	ui = CanvasLayer.new()
	ui.layer = 20
	add_child(ui)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(root)
	flash_rect = ColorRect.new()
	flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash_rect.color = Color(1, 1, 1, 0)
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(flash_rect)

	var leave := Button.new()
	leave.text = "Leave"
	leave.position = Vector2(_safe.l, _safe.t)
	leave.size = Vector2(92, 40)
	leave.add_theme_font_override("font", UiKit.font_b)
	leave.add_theme_font_size_override("font_size", 16)
	leave.add_theme_color_override("font_color", Color("3a241c"))
	leave.add_theme_stylebox_override("normal", UiKit.chunky(Color("fff6ea"), Color("c4a48a")))
	leave.add_theme_stylebox_override("hover", UiKit.chunky(Color("fffaf2"), Color("c4a48a")))
	leave.add_theme_stylebox_override("pressed", UiKit.chunky(Color("f0e0d0"), Color("a88868"), true))
	leave.pressed.connect(_open_pause)
	root.add_child(leave)

	timer_label = UiKit.label("3:00", 32, Color("fff6ea"), "x")
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_label.position = Vector2(250, _safe.t)
	timer_label.size = Vector2(220, 48)
	root.add_child(timer_label)

	enemy_bar = _hp_widget(root, Vector2(150, _safe.t + 52), 420, Color("9eb6f2"))
	player_bar = _hp_widget(root, Vector2(150, 1280 - _safe.b - 292), 420, Color("ffb15a"))
	e_burrow_l = _pip(root, Vector2(78, _safe.t + 58))
	e_burrow_r = _pip(root, Vector2(590, _safe.t + 58))
	p_burrow_l = _pip(root, Vector2(78, 1280 - _safe.b - 286))
	p_burrow_r = _pip(root, Vector2(590, 1280 - _safe.b - 286))

	spark_bar = SparkBar.new()
	spark_bar.position = Vector2(_safe.l + 8, 1280 - _safe.b - 248)
	spark_bar.size = Vector2(720 - _safe.l - _safe.r - 90, 28)
	root.add_child(spark_bar)
	spark_text = UiKit.label("6", 22, Color("fff6ea"), "x")
	spark_text.position = Vector2(640, 1280 - _safe.b - 252)
	spark_text.size = Vector2(60, 36)
	root.add_child(spark_text)

	hint_label = UiKit.label("Drag a card onto your half of the glade.", 16, Color("fff6ea"), "b")
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.position = Vector2(40, 1280 - _safe.b - 214)
	hint_label.size = Vector2(640, 28)
	root.add_child(hint_label)

	banner = Panel.new()
	banner.visible = false
	banner.position = Vector2(120, _safe.t + 110)
	banner.size = Vector2(480, 92)
	banner_style = UiKit.panel(Color("ffb15a"), 22)
	banner.add_theme_stylebox_override("panel", banner_style)
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(banner)
	banner_title = UiKit.label("", 26, Color("3a241c"), "x")
	banner_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_title.position = Vector2(12, 10)
	banner_title.size = Vector2(456, 40)
	banner.add_child(banner_title)
	banner_sub = UiKit.label("", 16, Color("5c3a2c"), "b")
	banner_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_sub.position = Vector2(12, 50)
	banner_sub.size = Vector2(456, 28)
	banner.add_child(banner_sub)

	var next_panel := Panel.new()
	next_panel.position = Vector2(_safe.l, 1280 - _safe.b - 176)
	next_panel.size = Vector2(78, 150)
	next_panel.add_theme_stylebox_override("panel", UiKit.panel(Color(1, 0.95, 0.88, 0.8), 16))
	next_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(next_panel)
	var next_tag := UiKit.label("Next", 12, Color("8a6552"), "b")
	next_tag.position = Vector2(8, 4)
	next_tag.size = Vector2(62, 18)
	next_panel.add_child(next_tag)
	next_portrait = TextureRect.new()
	next_portrait.position = Vector2(8, 24)
	next_portrait.size = Vector2(62, 62)
	next_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	next_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	next_panel.add_child(next_portrait)
	next_name = UiKit.label("", 11, Color("3a241c"), "b")
	next_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	next_name.position = Vector2(4, 92)
	next_name.size = Vector2(70, 48)
	next_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	next_panel.add_child(next_name)

	var left: float = float(_safe.l) + 88.0
	var gap := 8.0
	var width: float = (720.0 - left - float(_safe.r) - gap * 3.0) / 4.0
	for i in 4:
		var card := Panel.new()
		card.position = Vector2(left + i * (width + gap), 1280 - _safe.b - 176)
		card.size = Vector2(width, 160)
		card.add_theme_stylebox_override("panel", UiKit.panel(Color("fff8ee"), 18))
		card.gui_input.connect(_card_input.bind(i))
		root.add_child(card)
		card_roots.append(card)


func _card_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_start_drag(index, event.global_position)
		card_roots[index].accept_event()
	elif event is InputEventScreenTouch and event.pressed:
		_start_drag(index, event.position)
		card_roots[index].accept_event()


func _refresh_cards() -> void:
	var app := get_parent()
	for i in card_roots.size():
		var card: Panel = card_roots[i]
		for child in card.get_children():
			child.queue_free()
		if i >= hand.size():
			continue
		var species: String = hand[i]
		var info: Dictionary = Roster.info(species)
		var affordable := sparks + 0.001 >= float(info.cost)
		var cost := UiKit.label(str(info.cost), 22, Color("3a241c") if affordable else Color("a33b32"), "x")
		cost.position = Vector2(8, 4)
		card.add_child(cost)
		var swatch := ColorRect.new()
		swatch.color = info.card
		swatch.position = Vector2(36, 8)
		swatch.size = Vector2(22, 22)
		swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(swatch)
		var portrait := TextureRect.new()
		portrait.position = Vector2(10, 36)
		portrait.size = Vector2(card.size.x - 20, 72)
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if app and app.has_method("portrait"):
			var tex = app.portrait(species)
			if tex:
				portrait.texture = tex
		card.add_child(portrait)
		var name := UiKit.label(info.name, 16, Color("3a241c"), "x")
		name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name.position = Vector2(4, 112)
		name.size = Vector2(card.size.x - 8, 22)
		card.add_child(name)
		var role := UiKit.label(info.role, 12, Color("8a6552"), "b")
		role.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		role.position = Vector2(4, 134)
		role.size = Vector2(card.size.x - 8, 18)
		card.add_child(role)
		card.modulate = Color(1, 1, 1) if affordable else Color(0.72, 0.68, 0.66)
	var nxt: Dictionary = Roster.info(next_card)
	next_name.text = nxt.name
	if app and app.has_method("portrait"):
		var tex2 = app.portrait(next_card)
		if tex2:
			next_portrait.texture = tex2


func _update_hud() -> void:
	var secs := maxi(0, int(ceil(time_left)))
	timer_label.text = "%d:%02d" % [secs / 60, secs % 60]
	timer_label.add_theme_color_override("font_color", Color("ff8d7a") if secs <= 30 else Color("fff6ea"))
	spark_text.text = str(int(floor(sparks)))
	if spark_bar is SparkBar:
		spark_bar.value = sparks
		spark_bar.queue_redraw()
	_update_bars()
	if not dragging:
		if not placed_once:
			hint_label.text = "Drag a card onto your half of the glade."
		elif not merged_once:
			hint_label.text = "Drop a twin on a match. Forest, water, or lava picks the evolution."
		else:
			hint_label.text = "Dusk Rush — sparks come faster." if time_left <= Roster.DUSK_RUSH_AT else ""


func _update_bars() -> void:
	_set_hp(player_bar, player_den)
	_set_hp(enemy_bar, enemy_den)
	_set_pip(p_burrow_l, 0, -1.0)
	_set_pip(p_burrow_r, 0, 1.0)
	_set_pip(e_burrow_l, 1, -1.0)
	_set_pip(e_burrow_r, 1, 1.0)


func _set_hp(widget: Control, den: Unit) -> void:
	var fill: ColorRect = widget.get_node("Fill")
	var k := 0.0
	if den and is_instance_valid(den):
		k = clampf(den.hp / den.max_hp, 0.0, 1.0)
	fill.size.x = (widget.size.x - 8) * k


func _set_pip(label: Label, team: int, side: float) -> void:
	var hp := 0.0
	var max_hp := Roster.BURROW.hp
	for u in units:
		if u.structure and u.species == "burrow" and u.team == team and signf(u.position.x) == signf(side):
			hp = maxf(u.hp, 0.0)
	label.text = "%d" % int(round(100.0 * hp / max_hp))


func _hp_widget(parent: Control, pos: Vector2, width: float, color: Color) -> Control:
	var box := Control.new()
	box.position = pos
	box.size = Vector2(width, 22)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(box)
	var bg := ColorRect.new()
	bg.color = Color(0.2, 0.12, 0.1, 0.72)
	bg.size = box.size
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(bg)
	var fill := ColorRect.new()
	fill.name = "Fill"
	fill.color = color
	fill.position = Vector2(4, 4)
	fill.size = Vector2(width - 8, 14)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(fill)
	return box


func _pip(parent: Control, pos: Vector2) -> Label:
	var l := UiKit.label("100", 14, Color("fff6ea"), "b")
	l.position = pos
	l.size = Vector2(54, 22)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(l)
	return l


func _popup(world: Vector3, text: String, color: Color) -> void:
	var screen := arena.camera.unproject_position(world + Vector3(0, 0.4, 0))
	var l := UiKit.label(text, 22, color, "x")
	l.position = screen - Vector2(140, 20)
	l.size = Vector2(280, 56)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ui.add_child(l)
	var tw := l.create_tween()
	tw.tween_property(l, "position", l.position + Vector2(0, -46), 0.85)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.85)
	tw.tween_callback(l.queue_free)


func _flash_screen(color: Color) -> void:
	flash_rect.color = Color(color.r, color.g, color.b, 0.28)
	var tw := flash_rect.create_tween()
	tw.tween_property(flash_rect, "color:a", 0.0, 0.28)


func _shake_card(index: int) -> void:
	if index < 0 or index >= card_roots.size():
		return
	var card: Control = card_roots[index]
	var home := card.position
	var tw := card.create_tween()
	tw.tween_property(card, "position", home + Vector2(8, 0), 0.04)
	tw.tween_property(card, "position", home + Vector2(-7, 0), 0.04)
	tw.tween_property(card, "position", home, 0.04)


func _open_pause() -> void:
	if over:
		return
	paused = true
	Engine.time_scale = 0.0
	pause_layer = Control.new()
	pause_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.add_child(pause_layer)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.12, 0.07, 0.05, 0.4)
	pause_layer.add_child(dim)
	var stay := UiKit.button("Keep playing", 360, 74)
	stay.position = Vector2(180, 520)
	stay.pressed.connect(func() -> void:
		paused = false
		Engine.time_scale = 1.0
		pause_layer.queue_free()
	)
	pause_layer.add_child(stay)
	var quit := UiKit.button("Leave match", 360, 64)
	quit.position = Vector2(180, 610)
	quit.pressed.connect(func() -> void: leave_match.emit())
	pause_layer.add_child(quit)


func _read_safe() -> Dictionary:
	var vp := get_viewport().get_visible_rect().size
	var screen := DisplayServer.screen_get_size()
	var safe := DisplayServer.get_display_safe_area()
	var top := 20
	var bot := 18
	var left := 14
	var right := 14
	if screen.y > 0 and safe.size.y > 0 and safe.size.y < screen.y - 2:
		var sy := vp.y / float(screen.y)
		var sx := vp.x / float(maxf(screen.x, 1))
		top = maxi(top, int(safe.position.y * sy) + 6)
		bot = maxi(bot, int((screen.y - (safe.position.y + safe.size.y)) * sy) + 6)
		left = maxi(left, int(safe.position.x * sx) + 6)
		right = maxi(right, int((screen.x - (safe.position.x + safe.size.x)) * sx) + 6)
	if OS.get_name() == "iOS":
		top = maxi(top, 88)
		bot = maxi(bot, 36)
	return {"l": left, "t": top, "r": right, "b": bot}


class SparkBar extends Control:
	var value := 0.0

	func _draw() -> void:
		var n := 10
		var gap := 4.0
		var w := (size.x - gap * float(n - 1)) / float(n)
		for i in n:
			var x := float(i) * (w + gap)
			draw_rect(Rect2(x, 0, w, size.y), Color("3a2a24"), true)
			var amt := clampf(value - float(i), 0.0, 1.0)
			if amt > 0.0:
				draw_rect(Rect2(x, size.y * (1.0 - amt), w, size.y * amt), Color("ffb15a"), true)
				draw_rect(Rect2(x, size.y * (1.0 - amt), w, 3), Color("fff1c9"), true)
