extends "res://src/hunt/hunt_state.gd"
## The hunt, part 2: what falls and what flies. Souls, gold and item drops,
## pickups, level-up cards, and the projectile pool.


# --- Pickups -------------------------------------------------------------

var _label_n := 0
var _soul_mesh: Mesh
var _soul_mat: Material
var _heart_mat: Material


func _drop(kind: String, at: Vector3, value: int) -> void:
	var p := Pickup.new()
	p.kind = kind
	p.value = value
	p.spin = randf() * TAU
	world.add_child(p)
	p.position = at + Vector3(0, 0.8, 0)
	var a := randf() * TAU
	var spd := randf_range(1.5, 4.5) if kind != "gold" or phase != "victory" else randf_range(3.0, 8.0)
	p.vel = Vector3(sin(a) * spd, randf_range(5.0, 8.0), cos(a) * spd)
	p.settle = randf_range(0.45, 0.7)
	match kind:
		"soul", "heart":
			if _soul_mesh == null:
				var sm := SphereMesh.new()
				sm.radius = 0.14
				sm.height = 0.28
				sm.radial_segments = 10
				sm.rings = 6
				_soul_mesh = sm
				var m := StandardMaterial3D.new()
				m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				m.albedo_color = Color(0.6, 0.95, 1.0)
				m.emission_enabled = true
				m.emission = Color(0.35, 0.85, 1.0)
				m.emission_energy_multiplier = 4.0
				_soul_mat = m
				var hm := m.duplicate() as StandardMaterial3D
				hm.albedo_color = Color(1.0, 0.5, 0.5)
				hm.emission = Color(1.0, 0.15, 0.2)
				_heart_mat = hm
			var mi := MeshInstance3D.new()
			mi.mesh = _soul_mesh
			mi.material_override = _soul_mat if kind == "soul" else _heart_mat
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			if kind == "heart":
				mi.scale = Vector3.ONE * 2.0
			p.add_child(mi)
			p.body = mi
		"gold":
			var c := KK.prop("res://assets/kaykit/dungeon/coin.gltf")
			c.scale = Vector3.ONE * 1.5
			c.rotation.x = PI * 0.5
			var holder := Node3D.new()
			holder.add_child(c)
			p.add_child(holder)
			p.body = holder
	pickups.append(p)


func _drop_item(at: Vector3, it: Dictionary) -> void:
	var p := Pickup.new()
	p.kind = "item"
	p.item = it
	world.add_child(p)
	p.position = at + Vector3(0, 1.0, 0)
	var a := randf() * TAU
	var spd := randf_range(2.0, 4.0)
	p.vel = Vector3(sin(a) * spd, 7.0, cos(a) * spd)
	p.settle = 0.75
	var model_path: String = {"weapon": "res://assets/kaykit/weapons/sword_2handed_color.gltf", "helm": "res://assets/kaykit/graveyard/skull.gltf", "chest": "res://assets/kaykit/weapons/shield_badge_color.gltf", "legs": "res://assets/kaykit/weapons/shield_square_color.gltf", "trinket": "res://assets/kaykit/dungeon/key.gltf", "pet": "res://assets/kaykit/graveyard/skull.gltf", "trophy": "res://assets/kaykit/graveyard/skull_candle.gltf"}.get(it["slot"], "res://assets/kaykit/dungeon/coin_stack_small.gltf")
	# A weapon or offhand shows itself; worn pieces keep a stand-in.
	var own_model := ""
	if it["slot"] in ["weapon", "trinket"] and it.has("cls") and GearDB.LINES.has(str(it["cls"])):
		own_model = str(GearDB.look(it)["model"])
	var m := GearLook.prop_for(own_model) if own_model != "" else KK.prop(model_path)
	m.scale = Vector3.ONE * (1.6 if own_model != "" else 1.3)
	m.rotation = Vector3(0, randf() * TAU, PI * 0.5 if it["slot"] == "weapon" else 0.0)
	m.position.y = 0.2
	var holder := Node3D.new()
	holder.add_child(m)
	p.add_child(holder)
	p.body = holder
	var col := DB.gear_color(it)
	get_tree().create_timer(0.7, false).timeout.connect(func():
		if is_instance_valid(p) and p.is_inside_tree():
			p.beam = fx.beam(Vector3(p.position.x, 0, p.position.z), col, 9.0 if it["rarity"] == "legendary" else 6.0)
			var l := Label3D.new()
			# Short and big ("Tier 3 Helm"), stacked so neighbours do not overlap.
			l.text = "Tier %d %s" % [int(it.get("mat", 0)) + 1, DB.SLOT_NAME[it["slot"]]] if str(it.get("unique", "")) == "" and it["slot"] in DB.SLOTS else str(it["name"])
			l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			l.no_depth_test = true
			l.pixel_size = 0.013
			l.font = fx.title_font
			l.font_size = 44
			l.outline_size = 14
			l.modulate = col.lightened(0.15)
			l.outline_modulate = Color(0, 0, 0, 0.9)
			l.position = Vector3(0, 1.6 + 0.55 * (_label_n % 3), 0)
			_label_n += 1
			p.add_child(l)
			p.label = l
			Sfx.play("gear_drop", -2.0)
			if it["rarity"] == "legendary":
				Sfx.play("sparkle", 0.0)
				Ui.buzz(60, 0.6)
				_legendary_moment(Vector3(p.position.x, 0, p.position.z), it)
			if it["rarity"] in ["rare", "legendary"]:
				Sfx.play("rare_chime", 0.0, 0.9 if it["rarity"] == "legendary" else 1.0))
	pickups.append(p)


func _tick_pickups(dt: float) -> void:
	var i := pickups.size() - 1
	while i >= 0:
		var p := pickups[i]
		if not is_instance_valid(p) or not p.tick(dt, self):
			pickups.remove_at(i)
		i -= 1


func _loot_left() -> int:
	var n := 0
	for p in pickups:
		if is_instance_valid(p):
			n += 1
	return n


func collect(p: Pickup) -> void:
	match p.kind:
		"soul":
			_xp_frac += p.value * hero.xp_mult
			run_xp += int(_xp_frac)
			_xp_frac -= int(_xp_frac)
			Sfx.play("gem", -12.0, 1.0 + minf(run_xp % 7, 6) * 0.03)
			fx.flare(hero.flat_pos() + Vector3(0, 0.3, 0), Color(0.3, 0.8, 1.0, 0.5))
			_check_level()
		"gold":
			var g := int(round(p.value * float(tier["gold"]) * hero.gold_mult))
			gold += maxi(g, 1)
			Sfx.play("coin", -10.0)
		"heart":
			hero.hp = minf(hero.hp + hero.max_hp * 0.25, hero.max_hp)
			fx.text(hero.flat_pos(), "+%d" % int(hero.max_hp * 0.25), Color(0.4, 1.0, 0.5))
			Sfx.play("lifesteal", -4.0)
		"item":
			items.append(p.item)
			fx.release_beam(p.beam)
			var col := DB.gear_color(p.item)
			fx.burst(hero.flat_pos(), col, 12, 5.0)
			var better: bool = p.item["slot"] in DB.SLOTS and Game.is_better(p.item, hero_id)
			hud.toast("[color=#%s]%s[/color]" % [col.to_html(false), p.item["name"]], "▲ Upgrade for your %s" % DB.SLOT_NAME[p.item["slot"]].to_lower() if better else "Picked up")
			Sfx.play("gear_pickup", -2.0)
	p.queue_free()


func _check_level() -> void:
	var need := DB.run_level_xp(run_level)
	if run_xp >= need and hero.alive and phase != "defeat":
		run_xp -= need
		run_level += 1
		pending_levels += 1
		if pending_levels == 1:
			_offer_cards()


func _offer_cards() -> void:
	var choices := roll_cards(card_choices())
	if choices.is_empty():
		pending_levels = 0
		return
	Sfx.play("levelup", 0.0)
	Ui.buzz(25, 0.4)
	fx.ring(hero.flat_pos(), 3.0, Color(0.4, 0.9, 1.0), 0.6)
	fx.ring(hero.flat_pos(), 5.0, Color(0.7, 0.95, 1.0), 0.45, 0.2)
	fx.burst(hero.flat_pos() + Vector3(0, 1.0, 0), Color(0.5, 0.9, 1.0), 26, 8.0, 1.6)
	fx.flash_light(hero.flat_pos(), Color(0.5, 0.85, 1.0), 4.0, 8.0, 0.35)
	if bot:
		var pref := ["bladestorm", "tempest", "inferno_heart", "rain", "judgement_day", "armageddon", "heavens", "fault", "deluge", "meteor", "smite", "quake", "axes", "barrage", "frost", "explosive", "blades", "storm", "nova", "might", "haste", "multishot", "wave", "crit", "vigor", "phoenix", "reach", "inferno", "pierce", "regen", "leech", "wrath", "ward", "swift"]
		var best: String = choices[0]
		for c in pref:
			if c in choices:
				best = c
				break
		pick_card(best)
		return
	get_tree().paused = true
	hud.show_levelup(choices, run_level)


## Three choices, four once the hero reaches DB.FOURTH_CARD_LEVEL.
func card_choices() -> int:
	return 4 if Game.combat_level(hero_id) >= DB.FOURTH_CARD_COMBAT else 3


## Removes a card from this hunt's pool and returns a replacement for it (or
## "" when nothing is left to draw).
func banish(id: String, shown: Array) -> String:
	if banishes_left <= 0 or DB.CARDS[id].has("evo"):
		return ""
	banishes_left -= 1
	banished.append(id)
	var fresh := roll_cards(1, shown + banished)
	return "" if fresh.is_empty() else str(fresh[0])


## Redraws the level-up cards, never repeating what was just shown. Evolutions
## stay on offer. Returns [] when no reroll is left.
func reroll_cards(shown: Array) -> Array:
	if rerolls_left <= 0:
		return []
	rerolls_left -= 1
	var out := []
	for id in shown:
		if DB.CARDS[id].has("evo"):
			out.append(id)
	var fresh := roll_cards(shown.size() - out.size(), shown)
	out.append_array(fresh)
	if fresh.is_empty() and out.size() < shown.size():
		rerolls_left += 1
		return []
	return out


func roll_cards(n: int, exclude := []) -> Array:
	var pool := []
	var weights := []
	for id in DB.CARDS:
		var c: Dictionary = DB.CARDS[id]
		if int(cards.get(id, 0)) >= int(c["max"]):
			continue
		if c.has("only") and not str(hero.def["style"]) in c["only"]:
			continue
		if c.has("hero") and not hero_id in c["hero"]:
			continue
		if c["rarity"] == "legendary" and run_level < 5:
			continue
		if c.has("evo") or id in exclude or id in banished:
			continue # evolutions are offered by rule, below
		pool.append(id)
		weights.append(float(DB.CARD_WEIGHT[c["rarity"]]))
	var out := []
	var evos := eligible_evolutions()
	if not evos.is_empty() and exclude.is_empty():
		out.append(evos.pick_random())
	while out.size() < n and not pool.is_empty():
		var total := 0.0
		for w in weights:
			total += w
		var r := randf() * total
		for i in pool.size():
			r -= weights[i]
			if r <= 0.0:
				out.append(pool[i])
				pool.remove_at(i)
				weights.remove_at(i)
				break
	return out


## Evolution cards on offer: the first card of the pair is maxed, the second
## is owned, and the evolution itself is not taken yet.
func eligible_evolutions() -> Array:
	var out := []
	for id in DB.CARDS:
		var c: Dictionary = DB.CARDS[id]
		if not c.has("evo") or int(cards.get(id, 0)) > 0:
			continue
		if c.has("only") and not str(hero.def["style"]) in c["only"]:
			continue
		if c.has("hero") and not hero_id in c["hero"]:
			continue
		var a: String = c["evo"][0]
		var b: String = c["evo"][1]
		# Three stacks of the first card is enough: evolutions should be reachable
		# in a normal hunt, not only in a lucky one.
		if int(cards.get(a, 0)) >= mini(int(DB.CARDS[a]["max"]), 3) and int(cards.get(b, 0)) >= 1:
			out.append(id)
	return out


func pick_card(id: String) -> void:
	cards[id] = int(cards.get(id, 0)) + 1
	hero.recompute()
	if id == "vigor":
		hero.hp = minf(hero.hp + hero.max_hp * 0.3, hero.max_hp)
	pending_levels -= 1
	get_tree().paused = false
	Sfx.play("card_pick", -2.0)
	if pending_levels > 0:
		_offer_cards()
	else:
		_check_level()


## Rolls an item of at least rarity index `min_idx` (tries a few times).
func _roll_good(source: String, min_idx: int) -> Dictionary:
	var it := Game.roll_item(source, tier_i, "", "", loot_bonus)
	for i in 6:
		if DB.RARITIES.find(it["rarity"]) >= min_idx:
			break
		it = Game.roll_item(source, tier_i, "", "", loot_bonus)
	return it


# --- Projectiles ----------------------------------------------------------

func spawn_proj(kind: String, pos: Vector3, vel: Vector3, dmg: float, hits: int, src: Node3D, extra := {}) -> void:
	var pool: Array = _proj_pool.get(kind, [])
	_proj_pool[kind] = pool
	var p: Proj
	if pool.is_empty():
		p = Proj.new()
		p.body = _proj_body(kind)
		p.add_child(p.body)
		world.add_child(p)
	else:
		p = pool.pop_back()
	p.launch(kind, pos, vel, dmg, hits, src, extra)
	projs.append(p)


func _proj_body(kind: String) -> Node3D:
	var root := Node3D.new()
	match kind:
		"arrow":
			var a := KK.prop("res://assets/kaykit/weapons/arrow_bow.gltf")
			a.rotation = Vector3(0, 0, 0)
			a.scale = Vector3.ONE * 1.4
			root.add_child(a)
			root.add_child(_streak(Color(1.0, 0.9, 0.6), 1.8))
		"bolt":
			var b := KK.prop("res://assets/kaykit/weapons/Skeleton_Arrow.gltf")
			b.scale = Vector3.ONE * 1.4
			root.add_child(b)
			root.add_child(_streak(Color(1.0, 0.3, 0.2), 1.6))
		"fireball":
			var s := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.26
			sm.height = 0.52
			s.mesh = sm
			var m := StandardMaterial3D.new()
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.albedo_color = Color(1.0, 0.85, 0.5)
			m.emission_enabled = true
			m.emission = Color(1.0, 0.45, 0.1)
			m.emission_energy_multiplier = 4.0
			s.material_override = m
			s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(s)
			root.add_child(_streak(Color(1.0, 0.5, 0.15), 1.4, 0.7))
		"axe":
			var ax := KK.prop("res://assets/kaykit/weapons/axe_1handed.gltf")
			ax.scale = Vector3.ONE * 1.9
			ax.rotation = Vector3(PI * 0.5, 0, 0)
			ax.position = Vector3(0, 0, -0.55)
			root.add_child(ax)
			root.add_child(_streak(Color(1.0, 0.7, 0.4), 1.0, 0.5))
		"orb":
			var o := MeshInstance3D.new()
			var om := SphereMesh.new()
			om.radius = 0.3
			om.height = 0.6
			o.mesh = om
			var omat := StandardMaterial3D.new()
			omat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			omat.albedo_color = Color(0.9, 0.7, 1.0)
			omat.emission_enabled = true
			omat.emission = Color(0.7, 0.35, 1.0)
			omat.emission_energy_multiplier = 4.0
			o.material_override = omat
			o.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(o)
			root.add_child(_streak(Color(0.7, 0.4, 1.0), 1.4, 0.6))
		"spear":
			var bone := KK.prop("res://assets/kaykit/graveyard/bone_A.gltf")
			bone.scale = Vector3.ONE * 2.2
			bone.rotation = Vector3(0, PI * 0.5, 0)
			root.add_child(bone)
			root.add_child(_streak(Color(0.45, 1.0, 0.7), 1.6, 0.6))
		"wave":
			var w := MeshInstance3D.new()
			w.mesh = fx._arc(100)
			var wm := ShaderMaterial.new()
			wm.shader = Fx.SLASH
			wm.set_shader_parameter("color", Color(0.7, 0.85, 1.0))
			w.material_override = wm
			w.set_instance_shader_parameter("progress", 0.5)
			w.scale = Vector3(1.4, 1, 0.9)
			w.position = Vector3(0, -0.2, -0.6)
			w.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(w)
	return root


func _streak(color: Color, length: float, width := 0.35) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(width, length)
	q.orientation = PlaneMesh.FACE_Y
	mi.mesh = q
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(color.r, color.g, color.b, 0.55)
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0))
	g.set_color(1, Color(1, 1, 1, 1))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0.5, 1.0)
	gt.fill_to = Vector2(0.5, 0.0)
	gt.width = 8
	gt.height = 64
	m.albedo_texture = gt
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	mi.position = Vector3(0, 0, -length * 0.5)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


func _tick_projs(dt: float) -> void:
	var i := projs.size() - 1
	while i >= 0:
		var p := projs[i]
		if not p.tick(dt, self):
			_release_proj(p)
			projs.remove_at(i)
		i -= 1


func _release_proj(p: Proj) -> void:
	p.active = false
	p.visible = false
	_proj_pool[p.kind] = _proj_pool.get(p.kind, [])
	_proj_pool[p.kind].append(p)
