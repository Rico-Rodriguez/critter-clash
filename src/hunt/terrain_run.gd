extends RefCounted
## The terrain grid in a hunt: steps its timers each physics tick, turns the
## events into sound and effects, repaints the changed cells, and tells the
## hero and every foe what the ground under them does (grip, speed, drowning,
## burning). Only built for a zone that has terrain cells (`arena.terrain_live`).
## Preloaded by hunt.gd, no class_name.

const T := preload("res://src/hunt/terrain.gd")
const ICE_COL := Color(0.8, 0.92, 1.0, 0.8)
const FIRE_COL := Color(1.0, 0.5, 0.15)
const SPLASH := Color(0.7, 0.85, 1.0, 0.7)
## A boss feels this share of what the ground does to the hero.
const BOSS_WADE := 0.5

var h
var a: Arena
var t: RefCounted
var _burn_t := 0.0
var _embers_t := 0.0
var _hero_burn := 0.0
## Foes drowned and foes burnt away, for the end screen and for tests.
var drowned := 0
var scorched := 0


func setup(hunt) -> void:
	h = hunt
	a = hunt.arena
	t = a.terrain


func tick(dt: float) -> void:
	var ev: Array = t.step(dt)
	ev.append_array(a.terrain_ev)
	a.terrain_ev.clear()
	for e: Dictionary in ev:
		_event(e)
	for i: int in t.active():
		a.tview.paint(Vector2i(i % t.w, i / t.w))
	a.tview.flush()
	if not h.hero.alive:
		return
	_hero(dt)
	_foes(dt)
	_boss()
	_embers(dt)


func _event(e: Dictionary) -> void:
	var c: Vector2i = e["cell"]
	var at: Vector3 = t.center_of(c)
	a.tview.paint(c)
	match str(e["ev"]):
		"thin":
			h.fx.puff(at, ICE_COL, 3, 0.8, 1.2)
		"snap":
			a.reopen(c)
			h.fx.burst(at + Vector3(0, 0.2, 0), ICE_COL, 14, 6.0, 0.9)
			h.fx.puff(at, SPLASH, 5, 1.0, 2.0)
			Sfx.play("quake", -8.0, 1.8)
		"refreeze":
			a.reopen(c)
			h.fx.puff(at, ICE_COL, 2, 0.8, 0.8)
		"warn":
			pass
		"ignite":
			a.reopen(c)
			h.fx.embers_at(at, FIRE_COL, 5, 0.9)
			a.plank_burn(c)
		"burnt":
			h.fx.puff(at, Color(0.25, 0.23, 0.22, 0.6), 3, 1.0, 1.0)
		"fell":
			h.fx.embers_at(at, FIRE_COL, 6, 1.0)
			Sfx.play("thump", -10.0, 0.8)
			a.plank_fall(c)
		"flood":
			h.fx.puff(at, Color(0.2, 0.2, 0.2, 0.4), 2, 0.8, 0.6)
		"wallbreak":
			a.reopen(c)
			h.fx.burst(at + Vector3(0, 0.8, 0), ICE_COL, 22, 8.0, 0.8)
			h.fx.puff(at, SPLASH, 4, 1.2, 2.0)
			Sfx.play("quake", -6.0, 1.3)


func _hero(dt: float) -> void:
	var hero = h.hero
	var p: Vector3 = hero.flat_pos()
	var s: Dictionary = t.surface_at(p)
	hero.t_grip = float(s["grip"])
	hero.t_speed = float(s["speed"])
	hero.t_slide = float(s["slide"])
	if hero.dash_t > 0.0:
		return
	t.stand(t.cell_of(p), hero.mass)
	var fx: Dictionary = t.body_effect(p)
	if bool(fx["chill"]):
		var safe: Vector3 = t.nearest_safe(p)
		h.fx.puff(p, SPLASH, 6, 1.2, 2.5)
		h.fx.burst(p + Vector3(0, 0.3, 0), ICE_COL, 10, 5.0, 0.8)
		Sfx.play("boom", -8.0, 1.5)
		h.damage_hero(T.CHILL_HIT * float(h.tier["dmg"]), null, 0.0)
		hero.position = Vector3(safe.x, hero.position.y, safe.z)
		hero.vel = Vector3.ZERO
		hero.slow_t = maxf(hero.slow_t, 1.5)
		h.tip("water", "Open water chills you and drags you out: stay on the ice", "ice-bolt")
	_hero_burn -= dt
	if float(fx["dps"]) > 0.0:
		if _hero_burn <= 0.0:
			_hero_burn = 0.5
			h.damage_hero(float(fx["dps"]) * 0.5 * float(h.tier["dmg"]), null, 0.06)
			h.tip("burn", "Burning bog hurts: wait for the ash", "campfire")
	elif _hero_burn < 0.0:
		_hero_burn = 0.0


func _foes(dt: float) -> void:
	_burn_t -= dt
	var burn_now := _burn_t <= 0.0
	if burn_now:
		_burn_t = 0.5
	var i: int = h.foes.size() - 1
	while i >= 0:
		if i >= h.foes.size():
			i = h.foes.size() - 1
			if i < 0:
				break
		var f: Enemy = h.foes[i]
		i -= 1
		if not f.alive or f.state == "spawn":
			continue
		var fly := bool(f.def.get("fly", false))
		var p: Vector3 = f.flat_pos()
		var s: Dictionary = t.surface_at(p)
		f.t_speed = 1.0 if fly else float(s["speed"])
		f.t_slide = 1.0 if fly else float(s["slide"])
		if fly:
			continue
		t.stand(t.cell_of(p), f.mass)
		var fx: Dictionary = t.body_effect(p)
		var dweller: bool = str((f.def.get("brain", {}) as Dictionary).get("kind", "")) == "ambush"
		if bool(fx["lethal"]):
			# Bog dwellers (the ambush brains: Bogfin, Bog Frog) swim, so open water is home to them.
			if not dweller:
				_drown(f)
		elif burn_now and float(fx["dps"]) > 0.0 and str(f.def.get("element", "")) != "fire" and not bool(f.def.get("fireproof", false)):
			# The fire that burns their bog hurts the bog dwellers twice as hard.
			h.damage_foe(f, float(f.def.get("hp", 40.0)) * (0.1 if dweller else 0.05), h.hero, Vector3.ZERO, 0.0)
			scorched += 1


## A boss wades: the ground slows it by half what it slows the hero (so a bog or
## a cracked-open hole gives the hero room), and it never drowns or burns.
func _boss() -> void:
	var b = h.boss
	if b == null or not is_instance_valid(b) or not b.alive:
		return
	b.t_speed = lerpf(1.0, float(t.surface_at(b.flat_pos())["speed"]), BOSS_WADE)


func _drown(f: Enemy) -> void:
	var p: Vector3 = f.flat_pos()
	h.fx.puff(p, SPLASH, 6, 1.0, 2.2)
	h.fx.burst(p + Vector3(0, 0.3, 0), SPLASH, 8, 4.0, 0.9)
	Sfx.play("boom", -9.0, 1.6)
	f.hp = 0.0
	f.linger = 0.0
	h._kill(f)
	drowned += 1
	h.tip("drown", "Foes that stop on thin ice, or fall in the water, drown", "ice-bolt")


func _embers(dt: float) -> void:
	if h.low:
		return
	_embers_t -= dt
	if _embers_t > 0.0:
		return
	_embers_t = 0.4
	var hp: Vector3 = h.hero.flat_pos()
	var n := 0
	for i: int in t.active():
		if int(t.kind[i]) != T.BURNING:
			continue
		var at: Vector3 = t.center_of(Vector2i(i % t.w, i / t.w))
		if at.distance_to(hp) < 18.0:
			h.fx.embers_at(at, FIRE_COL, 1, 0.8)
			n += 1
			if n >= 6:
				break
