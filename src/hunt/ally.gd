class_name Ally
extends Actor
## A companion from the player's band: another hero who walks at your side and
## fights the nearest foe in its own style. The dead hunt the player, not the
## companion, so it never dies; it hits at DB.ALLY_DMG of its own damage.

var id := "ranger"
var def: Dictionary
var dmg := 10.0
var rate := 1.0
var reach := 2.4
var atk_cd := 0.6
var _side := 1.0


func setup(h: Hunt, hero_id: String) -> void:
	hunt = h
	id = hero_id
	def = DB.HEROES[id]
	var st := Game.hero_stats(id)
	dmg = float(st["dmg"]) * DB.ALLY_DMG
	rate = float(st["rate"])
	reach = float(st["range"])
	speed = float(st["speed"]) * 1.05
	radius = 0.45
	adult_build = true
	build_model(def["model"], {}, Color(0.6, 0.9, 1.0), 0.5)
	GearLook.apply(self, id)
	var tag := Label3D.new()
	tag.text = def["name"]
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.no_depth_test = true
	tag.pixel_size = 0.005
	tag.font = h.fx.title_font
	tag.font_size = 40
	tag.outline_size = 12
	tag.modulate = Color(0.6, 0.95, 1.0)
	tag.outline_modulate = Color(0, 0, 0, 0.85)
	tag.position = Vector3(0, 2.5, 0)
	add_child(tag)
	_side = 1.0 if randf() < 0.5 else -1.0


func tick(dt: float) -> void:
	tick_common(dt)
	atk_cd -= dt
	var hero := hunt.hero
	# Keep to the hero's flank, a few metres off; catch up when left behind.
	var want := hero.position + Vector3(_side * 2.2, 0, 1.2).rotated(Vector3.UP, hero.rotation.y)
	var d := want - position
	d.y = 0.0
	var moving := d.length() > 0.6
	if moving:
		var spd := speed * clampf(d.length() / 2.0, 0.6, 1.8)
		position = hunt.arena.resolve(position + d.normalized() * minf(spd * dt, d.length()), radius)
	var t := hunt.nearest_foe(position, reach + 0.5)
	if t:
		face(yaw_to(position, t.position), dt, 16.0)
		if atk_cd <= 0.0:
			_attack(t)
	elif moving:
		face(atan2(d.x, d.z), dt, 10.0)
	if atk_cd < 1.0 / rate - 0.35:
		play(def["anim"]["run"] if moving else def["anim"]["idle"], 0.15)


func _attack(t: Actor) -> void:
	atk_cd = 1.0 / rate
	play(def["anim"]["attack"][0], 0.05, 1.4, true)
	var fwd := (t.flat_pos() - flat_pos()).normalized()
	match str(def["style"]):
		"melee":
			for f in hunt.foes_near(position, reach + 1.0):
				var to: Vector3 = f.flat_pos() - flat_pos()
				if to.length() <= reach + f.radius and fwd.dot(to.normalized()) > 0.2:
					hunt.damage_foe(f, dmg, self, to.normalized(), 4.0)
			hunt.fx.slash(flat_pos(), atan2(fwd.x, fwd.z), reach, float(def.get("arc", 120.0)), Color(0.6, 0.9, 1.0), false, 0.2)
		"bow":
			hunt.spawn_proj("arrow", flat_pos() + fwd * 0.5, fwd * float(def["proj_speed"]), dmg, 2, self)
		"magic":
			hunt.spawn_proj("fireball", flat_pos() + fwd * 0.6, fwd * float(def["proj_speed"]), dmg, 1, self, {"splash": float(def.get("splash", 2.0))})
