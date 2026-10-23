extends RefCounted
## A party of up to three hunters (part of the online layer, see online.gd).
## Nakama keeps the party; this keeps who is in it, who is ready, and relays
## each hunter's position during a party hunt so partners walk beside you.
##
## Each phone runs its own hunt (the horde is not shared); partners are
## shown as companions who move where their player moves and fight the foes
## near them. Data messages, by op code:
##   1 plan    leader -> all  {zone, tier, start}
##   2 move    each   -> all  {x, z, y, m}       ~10 times a second in a hunt
##   3 hello   each   -> all  {name, hero, ready, combat, dmg, rate, range}
##   4 over    each   -> all  {win, kills}

const MAX := 3
const MOVE_HZ := 10.0

signal changed
## The leader started: {zone, tier}. The camp starts the hunt.
signal start(plan: Dictionary)

var o: Node
var id := ""
var leader := ""
## user_id -> {name, hero, ready, combat, dmg, rate, range, session, username}
var members := {}
var plan := {}
var in_hunt := false
## user_id -> {x, z, y, m, at} from op 2, read by the hunt's partners.
var moves := {}
var _move_t := 0.0


func _init(online: Node) -> void:
	o = online


func active() -> bool:
	return id != ""


func is_leader() -> bool:
	return leader == o.user_id


func mates() -> Array:
	return members.keys().filter(func(k): return k != o.user_id)


func all_ready() -> bool:
	for k in members:
		if k != leader and not bool(members[k].get("ready", false)):
			return false
	return members.size() >= 2


func create() -> String:
	var r: Dictionary = await o.socket_call({"party_create": {"open": true, "max_size": MAX}})
	if not r.has("party"):
		return _err(r)
	_take(r["party"])
	plan = {"zone": Game.zone_id(), "tier": Game.tier()}
	hello(true)
	return ""


func join(party_id: String) -> String:
	if active():
		leave()
	var r: Dictionary = await o.socket_call({"party_join": {"party_id": party_id}})
	if r.has("error"):
		var m := _err(r)
		return "That party is full or has ended." if m.contains("not found") or m.contains("full") else m
	# The reply to a join is empty; the party itself arrives as an event.
	id = party_id
	hello(false)
	changed.emit()
	return ""


func leave() -> void:
	if id != "":
		o.socket_send({"party_leave": {"party_id": id}})
	_reset()


func _reset() -> void:
	id = ""
	leader = ""
	members.clear()
	moves.clear()
	plan = {}
	in_hunt = false
	changed.emit()


## Posts the party in clan chat so clanmates can tap to join.
func invite_clan() -> String:
	if not active():
		return "Make a party first."
	return await o.send_chat({"t": "invite", "party": id, "mode": "horde", "zone": str(plan.get("zone", Game.zone_id())),
		"tier": int(plan.get("tier", Game.tier())), "hero": Game.hero_id()})


## Tells the party who this player is and whether they are ready.
func hello(ready_: bool) -> void:
	var st := Game.hero_stats(Game.hero_id())
	var me := {"hero": Game.hero_id(), "ready": ready_, "combat": Game.combat_level(),
		"dmg": float(st["dmg"]), "rate": float(st["rate"]), "range": float(st["range"])}
	if members.has(o.user_id):
		members[o.user_id].merge(me, true)
	else:
		members[o.user_id] = me.duplicate()
	members[o.user_id]["name"] = Game.player_name()
	_send(3, me)
	changed.emit()


func set_plan(zone: String, tier: int) -> void:
	plan = {"zone": zone, "tier": tier}
	if is_leader():
		_send(1, plan)
	changed.emit()


## Leader: everyone goes.
func go() -> void:
	if not is_leader():
		return
	var p := plan.duplicate()
	p["start"] = true
	_send(1, p)
	_begin(p)


func _begin(p: Dictionary) -> void:
	in_hunt = true
	moves.clear()
	start.emit(p)


func hunt_over(r: Dictionary) -> void:
	if not in_hunt:
		return
	in_hunt = false
	_send(4, {"win": bool(r.get("win", false)), "kills": int(r.get("kills", 0))})
	for k in members:
		members[k]["ready"] = false
	changed.emit()


## Sends this player's position while a party hunt runs.
func tick(dt: float) -> void:
	if not in_hunt or not o.socket_up():
		return
	_move_t -= dt
	if _move_t > 0.0:
		return
	_move_t = 1.0 / MOVE_HZ
	var main := o.get_parent()
	var h = main.get("current") if main else null
	if h == null or not "hero" in h or h.hero == null or not is_instance_valid(h.hero):
		return
	var p: Vector3 = h.hero.position
	_send(2, {"x": snappedf(p.x, 0.01), "z": snappedf(p.z, 0.01), "y": snappedf(h.hero.rotation.y, 0.01), "m": h.hero.move_input.length() > 0.1})


func _send(op: int, body: Dictionary) -> void:
	if id == "":
		return
	o.socket_send({"party_data_send": {"party_id": id, "op_code": op, "data": Marshalls.utf8_to_base64(JSON.stringify(body))}})


func on_event(env: Dictionary) -> void:
	if env.has("party"):
		_take(env["party"])
		hello(bool(members.get(o.user_id, {}).get("ready", false)))
	elif env.has("party_presence_event"):
		var e: Dictionary = env["party_presence_event"]
		if str(e.get("party_id", "")) != id:
			return
		for p in o._as_list(e.get("joins")):
			_add(p)
		for p in o._as_list(e.get("leaves")):
			members.erase(str(p.get("user_id", "")))
			moves.erase(str(p.get("user_id", "")))
		# Someone new needs to hear who we are.
		if not o._as_list(e.get("joins")).is_empty():
			hello(bool(members.get(o.user_id, {}).get("ready", false)))
			if is_leader() and not plan.is_empty():
				_send(1, plan)
		changed.emit()
	elif env.has("party_leader"):
		var e2: Dictionary = env["party_leader"]
		if str(e2.get("party_id", "")) == id:
			leader = str(e2.get("presence", {}).get("user_id", ""))
			changed.emit()
	elif env.has("party_close"):
		_reset()
	elif env.has("party_data"):
		var d: Dictionary = env["party_data"]
		if str(d.get("party_id", "")) != id:
			return
		var from := str(d.get("presence", {}).get("user_id", ""))
		var body = JSON.parse_string(Marshalls.base64_to_utf8(str(d.get("data", ""))))
		if not body is Dictionary or from == o.user_id:
			return
		_on_data(int(d.get("op_code", 0)), from, body)


func _on_data(op: int, from: String, body: Dictionary) -> void:
	match op:
		1:
			if from != leader:
				return
			plan = {"zone": str(body.get("zone", "barrow")), "tier": int(body.get("tier", 0))}
			if bool(body.get("start", false)):
				_begin(plan)
			changed.emit()
		2:
			body["at"] = Time.get_ticks_msec()
			moves[from] = body
		3:
			if not members.has(from):
				members[from] = {}
			# The name is not taken from here (a player could send anything):
			# it comes from the server, which filtered it.
			for k in ["hero", "ready", "combat", "dmg", "rate", "range"]:
				if body.has(k):
					members[from][k] = body[k]
			if not DB.HEROES.has(str(members[from].get("hero", ""))):
				members[from]["hero"] = "knight"
			# Stats are clamped so a hacked partner can't clear your hunt for you.
			members[from]["dmg"] = clampf(float(members[from].get("dmg", 10.0)), 1.0, 2000.0)
			members[from]["rate"] = clampf(float(members[from].get("rate", 1.0)), 0.2, 4.0)
			members[from]["range"] = clampf(float(members[from].get("range", 2.4)), 1.0, 12.0)
			changed.emit()
		4:
			if members.has(from):
				members[from]["done"] = body
			changed.emit()


func _take(p: Dictionary) -> void:
	id = str(p.get("party_id", id))
	var l = p.get("leader")
	if l is Dictionary:
		leader = str(l.get("user_id", ""))
	for pr in o._as_list(p.get("presences")):
		_add(pr)
	var me = p.get("self")
	if me is Dictionary:
		_add(me)
	changed.emit()


func _add(pr: Dictionary) -> void:
	var uid := str(pr.get("user_id", ""))
	if uid == "" or members.has(uid):
		return
	members[uid] = {"name": "Hunter", "hero": "knight", "ready": false, "username": str(pr.get("username", ""))}
	if uid == o.user_id:
		members[uid]["name"] = Game.player_name()
	else:
		_fetch_name(uid)


func _fetch_name(uid: String) -> void:
	var r: Dictionary = await o.get_api("/v2/user?ids=" + uid.uri_encode())
	if not r["ok"] or not members.has(uid):
		return
	for u in o._as_list(r["data"].get("users")):
		if str(u.get("id", "")) == uid:
			members[uid]["name"] = o._name_of(u)
	changed.emit()


static func _err(r: Dictionary) -> String:
	var e = r.get("error", {})
	return str(e.get("message", "Something went wrong")) if e is Dictionary else "Something went wrong"
