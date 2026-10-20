class_name NetPacket
extends RefCounted

## The wire format for the future multiplayer transport: small dictionaries
## that encode to JSON and travel to the server and back. The transport is
## not implemented yet (see scripts/network_manager.gd), so this file only
## fixes the packet shapes: the client and the server are written against
## one contract instead of each inventing their own.
##
## A packet carries a type tag ("t"):
##   TYPE_STATE  - one actor's snapshot: position, health, team.
##   TYPE_ACTION - a player intent: an action name and the actor it targets.
##   TYPE_EVENT  - a one-off event from the sim (a hit, a level-up, a death).

const TYPE_STATE := 1
const TYPE_ACTION := 2
const TYPE_EVENT := 3


## A state snapshot for one actor.
static func make_state(network_id: String, pos: Vector3, hp: int, team: int) -> Dictionary:
	return {
		"t": TYPE_STATE,
		"id": network_id,
		"pos": pos,
		"hp": hp,
		"team": team,
	}


## A player action: the name of the action and the actor it targets.
static func make_action(network_id: String, action: String, target: int) -> Dictionary:
	return {
		"t": TYPE_ACTION,
		"id": network_id,
		"action": action,
		"target": target,
	}


## Encodes a packet as JSON. Vectors become plain float arrays, so the
## text is transport-agnostic.
static func encode(d: Dictionary) -> String:
	return JSON.stringify(_to_wire(d))


## Decodes a JSON packet. A "pos" of three floats comes back as a Vector3;
## every other value is left as JSON gave it. Text that is not a JSON
## object decodes to an empty dictionary, so a corrupt packet is dropped
## instead of crashing the caller.
static func decode(s: String) -> Dictionary:
	var v: Variant = JSON.parse_string(s)
	if not (v is Dictionary):
		return {}
	var d: Dictionary = v
	var out: Dictionary = {}
	for key in d.keys():
		var val: Variant = d[key]
		if key == "pos" and val is Array:
			var arr: Array = val
			if arr.size() == 3:
				out[key] = Vector3(float(arr[0]), float(arr[1]), float(arr[2]))
				continue
		out[key] = val
	return out


## A copy of the packet with every Vector3 replaced by its float array.
static func _to_wire(d: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for key in d.keys():
		var val: Variant = d[key]
		if val is Vector3:
			var v: Vector3 = val
			out[key] = [v.x, v.y, v.z]
		else:
			out[key] = val
	return out
