extends "res://src/hunt/ally.gd"
## A party partner: another player's hero, moved by where that player really
## is in their own hunt (relayed about ten times a second, see party_link.gd)
## and fighting the foes near it here. When their updates stop, it walks at
## the hero's side like a companion until they come back.

const STALE_MS := 1500

var uid := ""
var _moves: Dictionary
var _tag: Label3D


func setup_partner(h: Hunt, user: String, info: Dictionary, moves: Dictionary) -> void:
	uid = user
	_moves = moves
	setup(h, str(info.get("hero", "knight")))
	dmg = float(info.get("dmg", dmg / DB.ALLY_DMG)) * DB.PARTNER_DMG
	rate = float(info.get("rate", rate))
	reach = float(info.get("range", reach))
	for c in get_children():
		if c is Label3D:
			_tag = c
	if _tag:
		_tag.text = str(info.get("name", "Partner"))
		_tag.modulate = Color(0.55, 1.0, 0.6)


func tick(dt: float) -> void:
	var m: Dictionary = _moves.get(uid, {})
	if m.is_empty() or Time.get_ticks_msec() - int(m.get("at", 0)) > STALE_MS:
		super(dt)
		return
	tick_common(dt)
	atk_cd -= dt
	var want := Vector3(float(m.get("x", 0.0)), 0.0, float(m.get("z", 0.0)))
	var d := want - position
	d.y = 0.0
	# Far off (a respawn, a new room): jump; near: glide to hide the 10 Hz steps.
	if d.length() > 8.0:
		position = hunt.arena.resolve(want, radius)
	else:
		position = hunt.arena.resolve(position + d * minf(1.0, dt * 10.0), radius)
	var moving := bool(m.get("m", false)) or d.length() > 0.4
	var t := hunt.nearest_foe(position, reach + 0.5)
	if t:
		face(yaw_to(position, t.position), dt, 16.0)
		if atk_cd <= 0.0:
			_attack(t)
	else:
		face(float(m.get("y", rotation.y)), dt, 12.0)
	if atk_cd < 1.0 / rate - 0.35:
		play(def["anim"]["run"] if moving else def["anim"]["idle"], 0.15)
