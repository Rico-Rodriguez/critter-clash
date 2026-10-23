extends "res://src/hunt/hunt_loot.gd"
## The hunt, part 3: damage. Hits on foes and the hero, kills, bosses
## falling, hazards that hurt, and the end of the hunt.


# --- Hazards ------------------------------------------------------------------

## A telegraphed blast on the ground: after `delay` it hurts the hero if they
## are still inside, and may slow or root them.
func blast_at(pos: Vector3, r: float, delay: float, amount: float, effect: String, col: Color, mech := 0.5) -> void:
	fx.telegraph(0, pos, 0.0, Vector2(r, 0), delay)
	get_tree().create_timer(delay, false).timeout.connect(func():
		if _ended or not is_instance_valid(hero):
			return
		fx.ring(pos, r, col, 0.35)
		fx.burst(pos, col, 14, 7.0)
		Sfx.play("boom", -10.0, 1.3)
		if hero.alive and hero.flat_pos().distance_to(pos) < r + hero.radius * 0.5:
			damage_hero(amount, null, mech)
			if effect == "slow":
				hero.slow_t = 2.5
			elif effect == "root":
				hero.root_t = 1.2)


## A lane across the ground from `from` along `yaw`: it flashes, then cuts.
func beam_from(from: Vector3, yaw: float, delay: float, amount: float, col: Color, mech := 0.6) -> void:
	fx.telegraph(2, from, yaw, Vector2(0.9, 14.0), delay)
	get_tree().create_timer(delay, false).timeout.connect(func():
		if _ended or not is_instance_valid(hero):
			return
		var fwd := Vector3(sin(yaw), 0, cos(yaw))
		var rel := hero.flat_pos() - from
		var along := rel.dot(fwd)
		var across := (rel - fwd * along).length()
		fx.ring(from + fwd * 6.0, 1.2, col, 0.3)
		if hero.alive and along > 0.0 and along < 14.0 and across < 0.9 + hero.radius * 0.5:
			damage_hero(amount, null, mech))


## A burning patch of ground left by a molten champion. It telegraphs red; the
## hero takes `dps` a second while standing in it.
func add_fire_patch(at: Vector3, r: float, dur: float, dps: float) -> void:
	patches.append({"pos": at, "r": r, "t": dur, "dps": dps, "tick": 0.5, "node": fx.telegraph(0, at, 0.0, Vector2(r, 0), dur)})


## Pyre: burning ground that hurts the dead standing in it.
func add_pyre(at: Vector3, r: float, dur: float, dps: float) -> void:
	pyres.append({"pos": at, "r": r, "t": dur, "dps": dps, "tick": 0.0})
	fx.embers_at(at, Color(1.0, 0.45, 0.1), 8, r * 0.7)


func _tick_pyres(dt: float) -> void:
	var i := pyres.size() - 1
	while i >= 0:
		var pr: Dictionary = pyres[i]
		pr["t"] -= dt
		pr["tick"] -= dt
		if pr["tick"] <= 0.0:
			pr["tick"] = 0.5
			fx.embers_at(pr["pos"], Color(1.0, 0.45, 0.1), 3, float(pr["r"]) * 0.7)
			for f in foes_near(pr["pos"], float(pr["r"])):
				damage_foe(f, float(pr["dps"]) * 0.5, hero, Vector3.ZERO, 0.0)
		if pr["t"] <= 0.0:
			pyres.remove_at(i)
		i -= 1


func _tick_patches(dt: float) -> void:
	var i := patches.size() - 1
	while i >= 0:
		var pt: Dictionary = patches[i]
		pt["t"] -= dt
		pt["tick"] -= dt
		if pt["tick"] <= 0.0:
			pt["tick"] = 0.5
			var d: float = hero.flat_pos().distance_to(pt["pos"])
			if hero.alive and d < float(pt["r"]) + hero.radius * 0.5:
				damage_hero(float(pt["dps"]) * 0.5, null, 0.06)
		if pt["t"] <= 0.0:
			patches.remove_at(i)
		i -= 1


# --- Damage --------------------------------------------------------------

func damage_foe(f: Actor, amount: float, src: Node3D, dir: Vector3, force: float) -> void:
	if not f.alive:
		return
	if f is Enemy and (f as Enemy).state == "spawn":
		return
	if f is Boss and (f as Boss).state == "intro":
		return
	if src == hero:
		amount *= hero.hit_mult()
	if f is Boss and (f as Boss).exposed_t > 0.0:
		amount *= 1.0 + float(DB.EXPOSED["dmg"]) + float(hero.flags.get("exposed", 0.0))
	var crit := randf() < hero.crit
	if crit:
		amount *= 2.0 + float(hero.flags.get("critdmg", 0.0)) + (0.6 if int(cards.get("backstab", 0)) > 0 else 0.0)
	if hero.flags.has("execute") and f.hp <= f.max_hp * 0.3:
		amount *= 1.0 + float(hero.flags["execute"])
	if hero.flags.has("mark") and f is Enemy and (f as Enemy).elite:
		amount *= 1.0 + float(hero.flags["mark"])
	amount = roundf(amount * randf_range(0.92, 1.08))
	if f is Enemy and (f as Enemy).ward_hp > 0.0:
		var e := f as Enemy
		var soak := minf(amount, e.ward_hp)
		e.ward_hp -= soak
		amount -= soak
		if e.ward_hp <= 0.0:
			e.ward_mesh.queue_free()
			e.ward_mesh = null
			fx.burst(f.flat_pos(), Color(0.6, 0.55, 1.0), 16, 7.0)
			Sfx.play("shield_break", -4.0)
		if amount <= 0.0:
			fx.text(f.flat_pos(), "Warded", Color(0.7, 0.65, 1.0), 0.6, 0.6)
			return
	var landed := minf(amount, maxf(f.hp, 0.0))
	f.hp -= amount
	f.hit_flash()
	if f is Enemy and f.hp > 0.0:
		(f as Enemy).stagger()
		if (f as Enemy).kind == "robber":
			for i in randi_range(1, 2):
				_drop("gold", f.flat_pos(), randi_range(2, 5))
	if force > 0.0:
		f.push(dir, force)
	var big := f is Boss
	# Every blow lands with a sound of its own (rate limited in Sfx, so a
	# crowd of hits in one frame is one crunch): bigger foes knock deeper.
	if big:
		Sfx.play("boss_hit", -9.0, 1.15)
	else:
		Sfx.play("contact", -7.0 if amount < hero.dmg * 1.5 else -3.0, 1.12 - minf(f.radius, 1.0) * 0.2)
	fx.number(f.flat_pos() + Vector3(0, 0.6 if big else 0.0, 0), int(amount), Color(1.0, 0.72, 0.25) if crit else Color(1, 1, 1), 1.6 if crit else 1.0, null if crit else f)
	fx.burst(f.flat_pos(), Color(1.0, 0.85, 0.6) if not crit else Color(1.0, 0.6, 0.2), 5 if not crit else 9, 6.0)
	if crit:
		Sfx.play("crit", -6.0)
		if int(cards.get("tempest", 0)) > 0 and not _storming and randf() < 0.2:
			_storming = true
			hero._storm(3, hero.dmg * 0.8)
			_storming = false
	dmg_dealt += landed
	hero.super_charge = minf(hero.super_charge + landed / (hero.dmg * 15.0) * hero.super_rate, 1.0)
	if hero.leech > 0.0 and hero.alive:
		var heal := minf(landed * hero.leech * heal_mult(), hero.leech_pool)
		hero.leech_pool -= heal
		hero.hp = minf(hero.hp + heal, hero.max_hp)
	if f.hp <= 0.0:
		if src == hero and int(cards.get("rampage", 0)) > 0:
			hero.rampage = mini(hero.rampage + 1, 15)
			hero.rampage_t = 6.0
		if f is Boss:
			if phase == "defeat":
				f.hp = 1.0
				return
			_kill_boss()
		else:
			_kill(f as Enemy)


func _kill(f: Enemy) -> void:
	f.die()
	foes.erase(f)
	corpses.append(f)
	kills += 1
	if hero.flags.has("bloodlust"):
		hero.rage = mini(hero.rage + 1, int(hero.flags["bloodlust"]))
		hero.rage_t = 1.5
		hero.recompute()
	streak += 1
	streak_t = DB.STREAK_WINDOW
	if streak in DB.STREAKS:
		run_xp += streak / 3
		gold += streak / 5
		hud.event("Massacre ×%d · +%d souls +%d gold" % [streak, streak / 3, streak / 5], Color(1.0, 0.45, 0.3), "skull-crossed-bones")
		Sfx.play("rare_chime", -2.0, 0.8)
		shake(0.25)
		_check_level()
	var at := f.flat_pos()
	fx.bone_burst(at, 5 if not f.elite else 12, 5.5 if not f.elite else 8.0)
	fx.puff(at, Color(0.4, 0.38, 0.35, 0.5), 3, 0.4, 1.2)
	Sfx.play("enemy_die", -5.0)
	var soul_gain: int = f.xp_value
	if phase == "rise" and mode == "horde":
		souls = mini(souls + (1 if not f.elite else 6), souls_goal)
	# Souls for XP.
	var orbs := clampi(int(ceil(soul_gain / 3.0)), 1, 8)
	for i in orbs:
		_drop("soul", at, int(ceil(float(soul_gain) / orbs)))
	if randf() < 0.22:
		for i in randi_range(1, 2):
			_drop("gold", at, randi_range(1, 3))
	if randf() < 0.012:
		_drop("heart", at, 1)
	if f.kind == "robber":
		for i in 25:
			_drop("gold", at, randi_range(3, 8))
		for i in 2:
			_drop_item(at, _roll_good("elite", 1 if i == 0 else 0))
		hitstop(0.08)
		banner("Grave Robber slain", Color(1.0, 0.85, 0.35), "His hoard spills out")
		Sfx.play("rare_chime", -2.0)
	if f.kind.begins_with("rival_"):
		_rival_down(f)
	if f.elite:
		elites_killed += 1
		hero.potion_cd -= float(DB.POTION["elite_cd"])
		hitstop(0.09)
		shake(0.5)
		# A fountain of coin every time, whatever else drops.
		for i in 16:
			_drop("gold", at, randi_range(2, 5))
		fx.flash_light(at, Color(1.0, 0.82, 0.35), 4.0, 7.0, 0.4)
		fx.burst(at + Vector3(0, 0.8, 0), Color(1.0, 0.82, 0.35), 20, 7.0, 1.8)
		Sfx.play("coin", -2.0, 0.9)
		_drop_item(at, Game.roll_item("elite", tier_i, "", "", loot_bonus))
		for u in Game.roll_uniques("elite", tier_i):
			_drop_item(at, Game.make_unique(u))
		if "molten" in f.affixes:
			fx.telegraph(0, at, 0.0, Vector2(2.6, 0), 1.0)
			get_tree().create_timer(1.0, false).timeout.connect(func():
				fx.ring(at, 2.8, Color(1.0, 0.45, 0.1), 0.4)
				fx.burst(at, Color(1.0, 0.5, 0.15), 18, 8.0)
				if hero.flat_pos().distance_to(at) < 2.6:
					damage_hero(f.dmg * 1.2, null, 0.5))
		banner("%s slain" % f.elite_name, Color(1.0, 0.85, 0.5))
		Sfx.play("rare_chime", -4.0)
	elif randf() < 0.012:
		_drop_item(at, Game.roll_item("trash", tier_i, "", "", loot_bonus))


func _kill_boss() -> void:
	boss_time = minf(boss_time, time - boss_at)
	bosses_killed.append(boss.boss_id)
	if mode == "descent" or (_rushlike() and rush_i < rush_order().size() - 1):
		_boss_down_midway()
		return
	boss.die()
	Ui.buzz(120, 0.9)
	phase = "victory"
	phase_t = 0.0
	_end_time = time
	hud.boss_mode(null)
	hud.victory_mode()
	Engine.time_scale = 0.25
	_real_hitstop = 1.4
	var at := boss.flat_pos()
	fx.bone_burst(at, 20, 10.0)
	fx.ring(at, 9.0, Color(DB.boss_def(cur_boss)["color"]).lightened(0.2), 1.0)
	fx.flash_light(at, Color(DB.boss_def(cur_boss)["color"]).lightened(0.3), 10.0, 18.0, 1.5)
	shake(1.0)
	Sfx.play("boss_die", 2.0)
	Sfx.music("", 2.0)
	get_tree().create_timer(0.35 * 0.25, true).timeout.connect(func(): Sfx.play("sting_victory", 0.0))
	banner("Victory", Color(1.0, 0.85, 0.45), str(DB.boss_def(cur_boss)["fall"]))
	if hero.alive:
		hero.act("Cheering", 1.6, true)
	# The hoard.
	for i in 26:
		_drop("gold", at, randi_range(3, 8))
	for i in randi_range(3, 4):
		_drop_item(at, Game.roll_boss_item(cur_boss, tier_i, loot_bonus))
	if mode == "rift":
		_drop_item(at, Game.make_unique(_rift_unique()))
	for u in Game.roll_uniques(str(DB.boss_def(cur_boss)["source"]), tier_i):
		_drop_item(at, Game.make_unique(u))
	if tier_i >= DB.TIER_ANCIENT:
		for u in Game.roll_uniques("ancient_" + str(DB.boss_def(cur_boss)["source"]), tier_i):
			_drop_item(at, Game.make_unique(u))
	for i in 10:
		_drop("soul", at, 4)
	# Everything left standing crumbles.
	for f in foes.duplicate():
		if f.alive:
			_kill(f)


var _end_time := 0.0


## The rift's prize: a unique from the boss's table, for this hero if one fits.
func _rift_unique() -> String:
	var src := str(DB.boss_def(cur_boss)["source"])
	var mine := []
	var any := []
	for u: String in DB.UNIQUES:
		var ud: Dictionary = DB.UNIQUES[u]
		if str(ud["source"]) != src or not ud["slot"] in DB.SLOTS:
			continue
		any.append(u)
		if str(ud.get("cls", "")) == hero_id:
			mine.append(u)
	var pool := mine if not mine.is_empty() else any
	return str(pool.pick_random()) if not pool.is_empty() else "tooth"


## `mech` marks a telegraphed attack: it also takes that many shares of the
## tier's `mech` fraction of max health, through armor (see DB.TIERS).
func damage_hero(amount: float, src: Node3D, mech := 0.0) -> void:
	if not hero.alive or phase == "victory" or phase == "boss_intro":
		return
	if hero.invuln > 0.0:
		if hero.dash_t > 0.0 or hero.dash_cd > hero.dash_cd_max - 0.4:
			if not hero.perfect_used and amount > 0.0:
				_perfect_dodge()
			else:
				fx.text(hero.flat_pos(), "Dodged", Color(0.7, 0.9, 1.0), 0.6, 0.6)
		return
	if hero.ward_up:
		hero.break_ward()
		return
	# Bulwark: a planted knight takes blows from the front on the shield.
	if int(cards.get("bulwark", 0)) > 0 and hero.still_t > 0.25 and src != null:
		var to := (src as Node3D).global_position - hero.global_position
		if absf(angle_difference(hero.rotation.y, atan2(to.x, to.z))) < deg_to_rad(75.0):
			amount *= 0.4
			fx.text(hero.flat_pos(), "Blocked", Color(0.75, 0.85, 1.0), 0.6, 0.5)
			Sfx.play("shield_break", -12.0, 1.6)
	amount *= 1.0 - DB.armor_dr(hero.armor, float(tier.get("pen", 0.0)))
	amount += hero.max_hp * float(tier.get("mech", 0.0)) * mech
	amount *= 1.0 + pact_sum("dmg_taken")
	amount = roundf(amount * randf_range(0.92, 1.08))
	hero.hp -= amount
	hero.hit_flash()
	hero.invuln = 0.08
	fx.number(hero.flat_pos(), int(amount), Color(1.0, 0.3, 0.25), 0.9)
	hud.hurt(clampf(amount / hero.max_hp * 4.0, 0.25, 1.0))
	Ui.buzz(35, clampf(amount / hero.max_hp * 5.0, 0.3, 1.0))
	shake(0.22)
	Sfx.play("hero_hurt", -3.0)
	if src is Enemy:
		var e := src as Enemy
		if "vampiric" in e.affixes:
			e.hp = minf(e.hp + amount * 2.0, e.max_hp)
			fx.lightning(PackedVector3Array([hero.position + Vector3(0, 1.0, 0), e.position + Vector3(0, 1.0, 0)]), Color(1.0, 0.2, 0.25))
		if hero.thorns > 0.0 and e.def["ai"] == "melee" and e.alive:
			Sfx.play("thorns", -6.0)
			damage_foe(e, amount * hero.thorns * 2.0, hero, (e.flat_pos() - hero.flat_pos()).normalized(), 3.0)
	if hero.hp > 0.0 and hero.flags.has("second_wind") and not hero.wind_used and hero.hp < hero.max_hp * 0.3:
		hero.wind_used = true
		hero.hp = minf(hero.hp + hero.max_hp * float(hero.flags["second_wind"]), hero.max_hp)
		hud.event("Second wind", Color(0.5, 1.0, 0.6), "heart-plus")
		fx.ring(hero.flat_pos(), 4.0, Color(0.5, 1.0, 0.6), 0.5)
		Sfx.play("levelup", -6.0)
	if hero.hp <= 0.0:
		hero.hp = 0.0
		if int(cards.get("phoenix", 0)) > 0 and not hero.revived:
			hero.revive()
			fx.ring(hero.flat_pos(), 6.0, Color(1.0, 0.6, 0.2), 0.6)
			fx.flash_light(hero.flat_pos(), Color(1.0, 0.6, 0.25), 8.0, 12.0, 0.8)
			for f in foes_near(hero.position, 6.0):
				damage_foe(f, hero.dmg * 3.0, hero, (f.flat_pos() - hero.flat_pos()).normalized(), 12.0)
			banner("Undying", Color(1.0, 0.7, 0.3), "You rise again")
			Sfx.play("phoenix", 0.0)
		else:
			_hero_dies()


## The hero dashed through a blow that would have landed: reward the read.
func _perfect_dodge() -> void:
	hero.perfect_used = true
	hero.riposte_t = float(DB.PERFECT_DODGE["time"])
	hero.super_charge = minf(hero.super_charge + float(DB.PERFECT_DODGE["super"]), 1.0)
	perfect_dodges += 1
	if hero.flags.has("dodge_heal"):
		hero.hp = minf(hero.hp + hero.max_hp * float(hero.flags["dodge_heal"]), hero.max_hp)
	fx.text(hero.flat_pos() + Vector3(0, 0.4, 0), "Perfect!", Color(0.55, 0.95, 1.0), 1.2, 0.9)
	tip("perfect", "Perfect dodge: your next hits strike 35% harder", "sprint")
	fx.ring(hero.flat_pos(), 2.6, Color(0.55, 0.9, 1.0), 0.35, 0.16)
	fx.flash_light(hero.flat_pos(), Color(0.5, 0.85, 1.0), 3.0, 6.0, 0.25)
	Sfx.play("unlock_start", -4.0, 1.5)
	Ui.buzz(30, 0.5)
	hitstop(0.07)


func _hero_dies() -> void:
	hero.die_anim()
	Ui.buzz(120, 0.8)
	phase = "defeat"
	phase_t = 0.0
	_end_time = time
	Engine.time_scale = 0.35
	_real_hitstop = 1.2
	Sfx.music("", 1.5)
	Sfx.play("sting_defeat", 0.0)
	banner("You have died", Color(0.85, 0.2, 0.18), str(zone["defeat"]))
	get_tree().create_timer(2.4 * 0.35, true).timeout.connect(func(): _end(false))


## A rival falls: they pay in gold and gear, and the feed counts the rest.
func _rival_down(f: Enemy) -> void:
	var at := f.flat_pos()
	for i in 6:
		_drop("gold", at, randi_range(3, 7))
	if randf() < 0.55:
		_drop_item(at, _roll_good("elite", 1))
	_drop("heart", at, 1)
	Sfx.play("rare_chime", -4.0)
	hud.event("%s down · %d left" % [f.def["name"], rivals_alive()], Color(1.0, 0.6, 0.45), "crossed-swords")


## A boss other than the last falls: loot, a breath, a card, the next one.
func _boss_down_midway() -> void:
	var b := boss
	b.die()
	boss = null
	phase = "rise"
	phase_t = 0.0
	hud.boss_mode(null)
	Ui.buzz(80, 0.7)
	var at := b.flat_pos()
	var col: Color = DB.boss_def(b.boss_id)["color"]
	fx.bone_burst(at, 16, 9.0)
	fx.ring(at, 8.0, Color(col).lightened(0.2), 0.9)
	fx.flash_light(at, Color(col).lightened(0.3), 9.0, 16.0, 1.2)
	shake(0.8)
	Sfx.play("boss_die", 0.0)
	banner("%s falls" % b.display_name, Color(1.0, 0.85, 0.5))
	for i in 12:
		_drop("gold", at, randi_range(3, 8))
	for i in 2 if _rushlike() else 1:
		_drop_item(at, Game.roll_boss_item(b.boss_id, tier_i, loot_bonus))
	for i in 5:
		_drop("soul", at, 3)
	_discard_boss(b)
	for f in foes.duplicate():
		if f.alive:
			_kill(f)
	hero.hp = minf(hero.hp + hero.max_hp * 0.5, hero.max_hp)
	Sfx.music(music_track(), 1.0)
	if mode == "descent":
		depth_t = 0.0
		return
	rush_i += 1
	rush_wait = DB.RUSH_GAP
	var nxt: Array = rush_order()[rush_i]
	banner("Next: %s" % DB.boss_def(str(nxt[0]))["name"], Color(0.85, 0.8, 0.7), "Take a card and a breath")
	run_level += 1
	pending_levels += 1
	if pending_levels == 1:
		_offer_cards()


## The dead boss sinks away; free it and its occluder a moment later.
func _discard_boss(b: Boss) -> void:
	get_tree().create_timer(3.5, false).timeout.connect(func():
		if is_instance_valid(b):
			for o in arena.occluders.duplicate():
				if o.get("node") == b:
					arena.occluders.erase(o)
			b.queue_free())


# --- End -----------------------------------------------------------------

func _abandon() -> void:
	get_tree().paused = false
	_end(false)


## A swept pickup flies to the hero and is gone, taking its beam and label
## with it: left standing, the labels showed through the results screen.
func _sweep(p: Node3D) -> void:
	if p.beam:
		fx.release_beam(p.beam)
		p.beam = null
	var t := p.create_tween().set_parallel(true).set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	t.tween_property(p, "global_position", hero.global_position + Vector3(0, 0.8, 0), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(p, "scale", Vector3.ONE * 0.1, 0.35)
	t.chain().tween_callback(p.queue_free)


func _end(win: bool) -> void:
	if _ended:
		return
	_ended = true
	Engine.time_scale = 1.0
	# Loot still lying around after a win is swept into the bag.
	if win:
		for p in pickups:
			if is_instance_valid(p):
				match p.kind:
					"gold":
						gold += int(round(p.value * float(tier["gold"]) * hero.gold_mult))
					"item":
						items.append(p.item)
				_sweep(p)
		pickups.clear()
	var spent := _end_time if _end_time > 0.0 else time
	result = {
		"win": win, "tier": tier_i, "zone": zone_id, "mode": mode, "rooms_cleared": rooms_cleared, "rooms": trial_rooms,"hero": hero_id, "gold": gold, "xp": skill_xp_gained(),
		"items": items, "kills": kills, "elites": elites_killed, "time": spent,
		"chest": tier["chest"] if win else "", "level": run_level, "souls": souls,
		"depth": depth, "dashes": dashes, "boss_time": boss_time,
		"rivals": rivals_total, "place": 1 if win else rivals_alive() + 1,
		"omen": str(omen.get("id", "")),
		"bosses": bosses_killed, "perfect": perfect_dodges,
	}
	# A won hunt under the weekly omen pays more, and its chest is a grade better.
	if not omen.is_empty() and (win or mode == "descent"):
		result["gold"] = int(round(gold * (1.0 + DB.OMEN_GOLD)))
		var grades := ["silver", "gold", "crypt"]
		var ch := str(result["chest"]) if win else ""
		if ch != "":
			result["chest"] = grades[mini(grades.find(ch) + 1, 2)]
	if not partners.is_empty():
		result["party"] = partners.size()
		result["gold"] = int(round(int(result["gold"]) * (1.0 + DB.PARTY_GOLD)))
	if mode == "wild" and not win and rivals_total > 0 and int(result["place"]) <= 3:
		result["chest"] = "silver"
	if mode == "descent":
		for pair in DB.DESCENT_CHESTS:
			if depth >= int(pair[0]):
				result["chest"] = pair[1]
				break
	var summary := Game.finish_hunt(result)
	result["summary"] = summary
	if bot:
		finished.emit(result)
		return
	hud.show_results(result)
