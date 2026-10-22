class_name Pickup
extends Node3D
## Something on the ground to walk over: a soul (XP), gold, a heart, or a
## piece of loot standing in its pillar of light.

var kind := "soul"
var value := 1
var item := {}
var vel := Vector3.ZERO
var t := 0.0
var pulled := false
var beam: Node3D
var label: Label3D
var body: Node3D
var spin := 0.0
var settle := 0.0


func tick(dt: float, h: Hunt) -> bool:
	t += dt
	var hero := h.hero
	var to := hero.flat_pos() - Vector3(position.x, 0, position.z)
	var d := to.length()
	# Pop out of the corpse, then settle.
	if settle > 0.0:
		settle -= dt
		position += vel * dt
		vel.y -= 22.0 * dt
		if position.y < 0.25:
			position.y = 0.25
			vel = Vector3(vel.x * 0.4, absf(vel.y) * 0.35, vel.z * 0.4)
		if settle <= 0.0:
			# Land where the hero can reach: not past a wall or inside a pillar.
			var y := position.y
			position = h.arena.resolve(position, 0.4)
			position.y = y
		if kind == "item":
			return true
	var reach := hero.magnet if kind != "item" else 1.4
	if kind == "heart":
		reach = 1.8
	if hero.alive and (pulled or d < reach) and settle <= 0.0:
		pulled = true
		var spd := 8.0 + t * 4.0 + (20.0 - d) * 0.3
		position += to.normalized() * minf(spd * dt, d)
		position.y = lerpf(position.y, 1.0, 10.0 * dt)
		if d < 0.6:
			h.collect(self)
			return false
	elif settle <= 0.0:
		position.y = 0.35 + sin(t * 3.0 + spin) * 0.12 if kind != "item" else 0.0
	if body:
		body.rotation.y += dt * (5.0 if kind == "gold" else 1.5)
	return true
