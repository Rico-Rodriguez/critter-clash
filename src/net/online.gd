extends "res://src/net/nk_client.gd"
## The online layer (part 2, on nk_client.gd): the account, friend codes and
## referrals, the reward inbox, clan chat, friends, the clan raid, cloud saves
## and parties. One instance lives under main (no autoload, so a content pack
## can ship it); screens reach it through `Online.inst`, which is null in the
## headless checks.
##
## Everything here is offline-safe: every call returns {ok, data | error}, the
## camp draws from the copy kept in the save, and nothing waits on the server.

const PartyLink := preload("res://src/net/party_link.gd")

static var inst: Node

signal state_changed
## Rewards were applied to the save: [{text, grants}].
signal gifts_arrived(list: Array)
signal chat_message(msg: Dictionary)
## Friends, clan membership or requests changed.
signal social_changed
## A short line for the camp to show ("Manz wants to be friends").
signal notice(text: String)

## "off" (no server, or turned off), "connecting", "on", "down".
var state := "off"
## The bootstrap reply: code, name, can_redeem, recruits, clan, muted_until.
var me := {}
var clan_channel := ""
## The last messages in clan chat, oldest first.
var clan_log: Array = []
var blocked := {}
var party: PartyLink
## Rewards applied but not yet shown (the camp pops them up when idle; a
## hunt may be running when they land).
var gifts_pending: Array = []
## The raid boss after this player's last hit (the results screen shows it).
var raid_last := {}

var _retry_at := 0.0
var _retries := 0
var _busy := false
var _last_save := 0
var _grants_busy := false

const EMOTES := ["gg", "hi", "thanks", "wow", "go", "wait", "help", "lol", "sad", "angry"]
const EMOTE_TEXT := {"gg": "GG!", "hi": "Hi!", "thanks": "Thanks!", "wow": "Wow!", "go": "Let's go!",
	"wait": "Wait for me!", "help": "Help!", "lol": "Ha ha!", "sad": "Aww...", "angry": "Grr!"}
const CHAT_KEEP := 80
## How often the full save goes up (also on every hunt end past this gap).
const SAVE_GAP := 120


static func start(parent: Node) -> Node:
	var o: Node = load("res://src/net/online.gd").new()
	o.name = "Online"
	parent.add_child(o)
	return o


func _ready() -> void:
	inst = self
	party = PartyLink.new(self)
	socket_event.connect(_on_event)
	socket_up_changed.connect(func(_up): state_changed.emit())
	if not configured() or bool(online()["off"]):
		return
	connect_now()


func _exit_tree() -> void:
	if inst == self:
		inst = null
	close_socket()


func online() -> Dictionary:
	return Game.data["online"]


func is_on() -> bool:
	return state == "on"


func in_clan() -> bool:
	return str(online()["clan_id"]) != ""


func my_code() -> String:
	return str(online()["ref_code"])


## Turns the online features off (or back on) from Settings.
func set_off(off: bool) -> void:
	online()["off"] = off
	Game.save()
	if off:
		close_socket()
		token = ""
		_set_state("off")
	else:
		connect_now()


func _set_state(s: String) -> void:
	if s != state:
		state = s
		state_changed.emit()


# --- Signing in -------------------------------------------------------------------

func _ensure_key() -> String:
	var k := str(online()["key"])
	if k.length() < 16:
		var c := Crypto.new()
		k = c.generate_random_bytes(20).hex_encode()
		online()["key"] = k
		Game.save()
	return k


func connect_now() -> void:
	if _busy or not configured() or bool(online()["off"]):
		return
	_busy = true
	_set_state("connecting")
	await fetch_config()
	var a := await authenticate(_ensure_key())
	if a["ok"]:
		a = await refresh_me()
	_busy = false
	if not a["ok"]:
		_set_state("down")
		_retries += 1
		_retry_at = Time.get_ticks_msec() / 1000.0 + minf(10.0 * _retries, 30.0)
		return
	_retries = 0
	_set_state("on")
	await _sync_name()
	await open_socket()
	if in_clan():
		join_clan_chat()
	fetch_grants()
	report_progress()


## Reads the account summary and mirrors it into the save.
func refresh_me() -> Dictionary:
	var r := await rpc_call("bootstrap")
	if not r["ok"]:
		return r
	me = r["data"]
	var o := online()
	o["user_id"] = str(me.get("user_id", ""))
	o["ref_code"] = str(me.get("code", ""))
	o["referred"] = bool(me.get("referred", false))
	var clan = me.get("clan")
	var was := str(o["clan_id"])
	if clan is Dictionary and clan.has("id"):
		o["clan_id"] = str(clan["id"])
		o["clan_name"] = str(clan.get("name", ""))
	else:
		o["clan_id"] = ""
		o["clan_name"] = ""
	Game.save()
	if was != str(o["clan_id"]):
		clan_log.clear()
		clan_channel = ""
		if in_clan() and socket_up():
			join_clan_chat()
		social_changed.emit()
	return r


## The name lives in the save; the server keeps a filtered copy. A new phone
## restored from a transfer adopts the server's.
func _sync_name() -> void:
	var local := str(Game.data["profile"]["name"])
	var remote := str(me.get("name", ""))
	if local == "" and remote != "":
		Game.data["profile"]["name"] = remote
		Game.save()
	elif local != "" and local != remote:
		var r := await rpc_call("set_name", {"name": local})
		if not r["ok"]:
			# Refused by the filter: back to the server's (or the default).
			Game.data["profile"]["name"] = remote
			Game.save()


## Sets the player's name. Offline it is kept and sent on the next sign-in.
func set_player_name(n: String) -> Dictionary:
	n = n.strip_edges()
	if n.length() < 3 or n.length() > 16:
		return {"ok": false, "error": "Names are 3 to 16 letters."}
	if is_on():
		var r := await rpc_call("set_name", {"name": n})
		if not r["ok"]:
			return r
		n = str(r["data"].get("name", n))
		me["name"] = n
	Game.data["profile"]["name"] = n
	Game.save()
	return {"ok": true}


func _process(dt: float) -> void:
	super(dt)
	if state == "down" and not _busy and Time.get_ticks_msec() / 1000.0 > _retry_at:
		connect_now()
	elif state == "on" and not _busy and not socket_up() and Time.get_ticks_msec() / 1000.0 > _retry_at:
		_retry_at = Time.get_ticks_msec() / 1000.0 + 10.0
		_reopen()
	party.tick(dt)


func _reopen() -> void:
	_busy = true
	if not signed_in():
		var a := await authenticate(_ensure_key())
		if not a["ok"]:
			_busy = false
			_set_state("down")
			return
	await open_socket()
	_busy = false
	if not socket_up():
		# The test server's tunnel moves: go down so the retry re-reads the config.
		_set_state("down")
		_retry_at = Time.get_ticks_msec() / 1000.0 + 3.0
		return
	if in_clan():
		join_clan_chat()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_RESUMED and state in ["down", "on"]:
		_retry_at = 0.0
		if state == "on":
			fetch_grants()


# --- Reward inbox -------------------------------------------------------------------

## Fetches waiting rewards, applies them to the save, then tells the server.
## Ids already applied are remembered, so a lost reply never pays twice.
func fetch_grants() -> void:
	if _grants_busy or not is_on():
		return
	_grants_busy = true
	var r := await rpc_call("list_grants")
	if not r["ok"]:
		_grants_busy = false
		return
	var seen: Array = online()["grants_seen"]
	var shown := []
	var ids := []
	for g in _as_list(r["data"].get("grants")):
		var id := str(g.get("id", ""))
		ids.append(id)
		if id in seen:
			continue
		var list := _as_list(g.get("grants"))
		for one in list:
			apply_grant(one)
		seen.append(id)
		shown.append({"text": str(g.get("text", "A gift")), "grants": list, "reason": str(g.get("reason", ""))})
	while seen.size() > 200:
		seen.pop_front()
	if not shown.is_empty():
		Game.save()
		gifts_pending.append_array(shown)
		gifts_arrived.emit(shown)
	if not ids.is_empty():
		await rpc_call("ack_grants", {"ids": ids})
	_grants_busy = false


## The Lua runtime sends an empty list as {}: treat anything not a list as none.
static func _as_list(v) -> Array:
	return v if v is Array else []


func apply_grant(g: Dictionary) -> void:
	match str(g.get("kind", "")):
		"gold":
			Game.data["gold"] = Game.gold() + clampi(int(g.get("amount", 0)), 0, 1000000)
		"shards":
			var h := Game.hero(Game.hero_id())
			h["shards"] = int(h["shards"]) + clampi(int(g.get("amount", 0)), 0, 1000)
			Game.unlock_by_shards()
		"chest":
			var c := str(g.get("chest", ""))
			var main := get_parent()
			if DB.CHESTS.has(c) and main and "pending_chest" in main:
				if str(main.pending_chest) == "":
					main.pending_chest = c
				else:
					main.chest_queue.append(c)
		"glow":
			var glow := str(g.get("glow", ""))
			if DB.GLOWS.has(glow):
				for id in DB.HERO_ORDER:
					if not glow in Game.hero(id)["glows"]:
						Game.hero(id)["glows"].append(glow)


## A short line for one grant ("2,000 gold").
## 25000 -> "25,000": rewards read better exact than as "25.0k".
static func commas(n: int) -> String:
	var t := str(absi(n))
	var out := ""
	while t.length() > 3:
		out = "," + t.right(3) + out
		t = t.left(t.length() - 3)
	return ("-" if n < 0 else "") + t + out


static func grant_text(g: Dictionary) -> String:
	match str(g.get("kind", "")):
		"gold":
			return "%s gold" % commas(int(g.get("amount", 0)))
		"shards":
			return "%d hero shards" % int(g.get("amount", 0))
		"chest":
			return "%s" % DB.CHESTS.get(str(g.get("chest", "")), {"name": "Chest"})["name"]
		"glow":
			return "%s weapon glow" % DB.GLOWS.get(str(g.get("glow", "")), {"name": "A"})["name"]
	return "A gift"


# --- After a hunt -------------------------------------------------------------------

## Called by main when a hunt ends: progress for leaderboards and referral
## milestones, a hit on the clan raid boss, the party's end, a cloud save.
func after_hunt(r: Dictionary) -> void:
	if not is_on():
		return
	party.hunt_over(r)
	await report_progress()
	if str(r.get("omen", "")) != "":
		await submit_weekly()
	if in_clan() and not bool(r.get("abandoned", false)):
		var dmg := raid_damage(r)
		if dmg > 0:
			var h := await rpc_call("raid_hit", {"damage": dmg, "tier": int(r.get("tier", 0))})
			if h["ok"]:
				h["data"]["dealt"] = dmg
				raid_last = h["data"]
	var now := int(Time.get_unix_time_from_system())
	if now - _last_save > SAVE_GAP:
		cloud_save()
	fetch_grants()


## What a hunt deals to the clan raid boss (tuning in DB.RAID_HIT).
static func raid_damage(r: Dictionary) -> int:
	var t: Dictionary = DB.RAID_HIT
	var d := int(r.get("kills", 0)) * int(t["kill"]) + int(r.get("elites", 0)) * int(t["elite"])
	d += (r.get("bosses", []) as Array).size() * int(t["boss"])
	if r.get("win", false):
		d += int(t["win"])
	return int(d * (1.0 + float(t["per_tier"]) * int(r.get("tier", 0))))


func best_combat() -> int:
	var best := 3
	for id in DB.HERO_ORDER:
		if Game.hero(id)["unlocked"]:
			best = maxi(best, Game.combat_level(id))
	return best


func report_progress() -> void:
	if not is_on():
		return
	var st: Dictionary = Game.data["stats"]
	await rpc_call("report_progress", {"hunts": int(st["hunts"]), "wins": int(st["wins"]),
		"combat": best_combat(), "power": Game.power_score(Game.hero_id()), "hero": Game.hero_id(),
		"best_tier_won": int(st.get("best_tier_won", 0))})


## Sends this week's best omen-hunt score to the weekly board.
func submit_weekly() -> Dictionary:
	if not is_on():
		return {"ok": false, "error": "offline"}
	var e := Game.weekly_entry()
	if int(e["best"]) <= 0:
		return {"ok": true, "data": {}}
	e["hero"] = str(Game.data.get("weekly", {}).get("hero", ""))
	return await rpc_call("weekly_submit", e)


# --- Cloud save, new phone, deletion ---------------------------------------------------

func cloud_save() -> Dictionary:
	if not is_on():
		return {"ok": false, "error": "Offline"}
	_last_save = int(Time.get_unix_time_from_system())
	var r := await rpc_call("save_put", {"data": JSON.stringify(Game.data), "hunts": int(Game.data["stats"]["hunts"])})
	if r["ok"]:
		online()["synced"] = int(r["data"].get("at", _last_save))
		Game.save()
	return r


## The save on the server, or {} if none: {data (JSON text), at, hunts}.
func cloud_peek() -> Dictionary:
	var r := await rpc_call("save_get")
	return r["data"] if r["ok"] else {}


## Replaces this phone's progress with the cloud copy. The device key is kept
## so this phone stays signed in to the same account.
func cloud_restore(text: String) -> bool:
	var parsed = JSON.parse_string(text)
	if not parsed is Dictionary or not parsed.has("heroes"):
		return false
	var key := str(online()["key"])
	var f := FileAccess.open(Game.SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return false
	parsed["online"]["key"] = key
	parsed["online"]["grants_seen"] = online()["grants_seen"]
	f.store_string(JSON.stringify(parsed))
	f.close()
	Game.load_save()
	Game.save()
	return true


func transfer_make() -> Dictionary:
	return await rpc_call("transfer_make")


## On the new phone: moves this install onto the account the code came from,
## then brings that account's cloud save down.
func transfer_use(code: String) -> Dictionary:
	var r := await rpc_call("transfer_use", {"code": code, "key": _ensure_key()})
	if not r["ok"]:
		return r
	token = ""
	var a := await authenticate(_ensure_key())
	if not a["ok"]:
		return {"ok": false, "error": "Moved, but couldn't sign in. Restart the game."}
	close_socket()
	await refresh_me()
	var save := await cloud_peek()
	if str(save.get("data", "")) != "":
		cloud_restore(str(save["data"]))
	await _sync_name()
	await open_socket()
	if in_clan():
		join_clan_chat()
	return {"ok": true}


## Deletes the online account (Apple requires this in the app). The progress
## on this phone is reset too, so nothing of the player is kept anywhere.
func delete_account() -> Dictionary:
	if is_on():
		var r := await rpc_call("delete_account")
		if not r["ok"]:
			return r
	close_socket()
	token = ""
	var off := bool(online()["off"])
	Game.data = Game._fresh()
	online()["off"] = off
	Game.save()
	me = {}
	clan_log.clear()
	_set_state("off" if off or not configured() else "down")
	_retry_at = 0.0
	return {"ok": true}


# --- Referrals ---------------------------------------------------------------------

func redeem(code: String) -> Dictionary:
	var r := await rpc_call("redeem", {"code": code})
	if r["ok"]:
		online()["referred"] = true
		me["can_redeem"] = false
		Game.save()
		fetch_grants()
	return r


func recruits() -> Dictionary:
	return await rpc_call("recruits")


func can_redeem() -> bool:
	return is_on() and bool(me.get("can_redeem", false)) and not bool(online()["referred"])


# --- Friends -----------------------------------------------------------------------

## [{id, name, code, online, state}] — state 0 friend, 1 asked by me, 2 asking me, 3 blocked.
func friends() -> Dictionary:
	var r := await get_api("/v2/friend?limit=100")
	if not r["ok"]:
		return r
	var out := []
	blocked.clear()
	for f in _as_list(r["data"].get("friends")):
		var u: Dictionary = f.get("user", {})
		var s := int(f.get("state", 0))
		if s == 3:
			blocked[str(u.get("id", ""))] = true
		out.append({"id": str(u.get("id", "")), "name": _name_of(u), "code": str(u.get("username", "")),
			"online": bool(u.get("online", false)), "state": s})
	return {"ok": true, "data": out}


static func _name_of(u: Dictionary) -> String:
	var n := str(u.get("display_name", ""))
	return n if n != "" else "Hunter"


func add_friend(code: String) -> Dictionary:
	code = code.strip_edges().to_upper()
	if code.length() != 6:
		return {"ok": false, "error": "Friend codes are 6 letters and numbers."}
	if code == my_code():
		return {"ok": false, "error": "That's your own code!"}
	var r := await post_api("/v2/friend?usernames=" + code.uri_encode())
	if not r["ok"] and int(r["code"]) == 404:
		return {"ok": false, "error": "No hunter has that code."}
	return r


func accept_friend(id: String) -> Dictionary:
	return await post_api("/v2/friend?ids=" + id.uri_encode())


func remove_friend(id: String) -> Dictionary:
	return await delete_api("/v2/friend?ids=" + id.uri_encode())


func block(id: String) -> Dictionary:
	blocked[id] = true
	return await post_api("/v2/friend/block?ids=" + id.uri_encode())


func report(id: String, reason: String, message := "") -> Dictionary:
	return await rpc_call("report", {"user_id": id, "reason": reason, "message": message})


## Public progress for players: {id: {name, combat, power, hero, hunts, wins}}.
func profiles(ids: Array) -> Dictionary:
	var r := await rpc_call("profiles", {"ids": ids})
	if not r["ok"]:
		return {}
	var p = r["data"].get("profiles")
	return p if p is Dictionary else {}


## The top of a leaderboard ("power", "combat" or "weekly"), plus the player's own row.
func leaderboard(id: String) -> Dictionary:
	var me := str(online()["user_id"])
	var r := await get_api("/v2/leaderboard/%s?limit=50%s" % [id, ("&owner_ids=" + me.uri_encode()) if me != "" else ""])
	if not r["ok"]:
		return r
	var rows := []
	for rec in _as_list(r["data"].get("records")):
		rows.append({"id": str(rec.get("owner_id", "")), "name": str(rec.get("username", "Hunter")),
			"score": int(rec.get("score", 0)), "rank": int(rec.get("rank", 0)),
			"meta": JSON.parse_string(str(rec.get("metadata", "{}")))})
	var mine := {}
	var ow: Array = _as_list(r["data"].get("owner_records"))
	if not ow.is_empty():
		mine = {"rank": int(ow[0].get("rank", 0)), "score": int(ow[0].get("score", 0))}
		# Nakama leaves the rank off owner rows on some boards: take it from the top list.
		for row in rows:
			if int(mine["rank"]) == 0 and row["id"] == str(ow[0].get("owner_id", "")):
				mine["rank"] = row["rank"]
	return {"ok": true, "data": rows, "mine": mine}


# --- Clans --------------------------------------------------------------------------

## Open clans, or clans whose name starts with `query`.
func find_clans(query := "") -> Dictionary:
	var path := "/v2/group?limit=30"
	query = query.strip_edges()
	if query != "":
		path += "&name=" + (query + "%").uri_encode()
	else:
		path += "&open=true"
	var r := await get_api(path)
	if not r["ok"]:
		return r
	var out := []
	for g in _as_list(r["data"].get("groups")):
		out.append(clan_row(g))
	return {"ok": true, "data": out}


static func clan_row(g: Dictionary) -> Dictionary:
	var meta = JSON.parse_string(str(g.get("metadata", "{}")))
	if not meta is Dictionary:
		meta = {}
	return {"id": str(g.get("id", "")), "name": str(g.get("name", "")), "desc": str(g.get("description", "")),
		"members": int(g.get("edge_count", 0)), "max": int(g.get("max_count", 50)), "open": bool(g.get("open", false)),
		"badge": int(meta.get("badge", 0)), "min_combat": int(meta.get("min_combat", 0))}


func my_clan() -> Dictionary:
	if not in_clan():
		return {"ok": false, "error": "No clan"}
	var r := await get_api("/v2/group?limit=1&name=" + str(online()["clan_name"]).uri_encode())
	if r["ok"]:
		for g in _as_list(r["data"].get("groups")):
			if str(g.get("id", "")) == str(online()["clan_id"]):
				return {"ok": true, "data": clan_row(g)}
	return {"ok": false, "error": r.get("error", "Clan not found")}


func create_clan(n: String, desc: String, badge: int, open: bool, min_combat: int) -> Dictionary:
	var r := await rpc_call("clan_create", {"name": n, "desc": desc, "badge": badge, "open": open, "min_combat": min_combat})
	if r["ok"]:
		await refresh_me()
	return r


func edit_clan(fields: Dictionary) -> Dictionary:
	return await rpc_call("clan_edit", fields)


## Joins an open clan, or asks to join a closed one ({ok, asked}).
func join_clan(id: String) -> Dictionary:
	var r := await post_api("/v2/group/%s/join" % id)
	if not r["ok"]:
		return r
	await refresh_me()
	return {"ok": true, "asked": not in_clan()}


func leave_clan() -> Dictionary:
	if not in_clan():
		return {"ok": true}
	var r := await post_api("/v2/group/%s/leave" % online()["clan_id"])
	if r["ok"] or int(r["code"]) == 400:
		if clan_channel != "":
			socket_send({"channel_leave": {"channel_id": clan_channel}})
		await refresh_me()
	return r


## Members: [{id, name, code, online, role}] — role 0 leader, 1 elder, 2 member, 3 asking to join.
func clan_members() -> Dictionary:
	if not in_clan():
		return {"ok": false, "error": "No clan"}
	var r := await get_api("/v2/group/%s/user?limit=100" % online()["clan_id"])
	if not r["ok"]:
		return r
	var out := []
	for gu in _as_list(r["data"].get("group_users")):
		var u: Dictionary = gu.get("user", {})
		out.append({"id": str(u.get("id", "")), "name": _name_of(u), "code": str(u.get("username", "")),
			"online": bool(u.get("online", false)), "role": int(gu.get("state", 2))})
	out.sort_custom(func(a, b): return int(a["role"]) < int(b["role"]) or (int(a["role"]) == int(b["role"]) and bool(a["online"]) and not bool(b["online"])))
	return {"ok": true, "data": out}


## Leader and elder tools: "add" (accept a request), "kick", "promote", "demote".
func clan_manage(action: String, user: String) -> Dictionary:
	return await post_api("/v2/group/%s/%s?user_ids=%s" % [online()["clan_id"], action, user.uri_encode()])


func my_role() -> int:
	var c = me.get("clan")
	return int(c.get("role", 2)) if c is Dictionary else 3


# --- Clan chat ---------------------------------------------------------------------

func join_clan_chat() -> void:
	if not in_clan() or not socket_up():
		return
	var gid := str(online()["clan_id"])
	var r := await socket_call({"channel_join": {"target": gid, "type": 3, "persistence": true, "hidden": false}})
	if not r.has("channel"):
		return
	clan_channel = str(r["channel"].get("id", ""))
	var h := await get_api("/v2/channel/%s?limit=50&forward=false" % clan_channel.uri_encode())
	if h["ok"]:
		var msgs := []
		for m in _as_list(h["data"].get("messages")):
			msgs.push_front(parse_message(m))
		clan_log.assign(msgs)
		_trim_log()
		social_changed.emit()


func parse_message(m: Dictionary) -> Dictionary:
	var c = JSON.parse_string(str(m.get("content", "{}")))
	if not c is Dictionary:
		c = {}
	var sender := str(m.get("sender_id", ""))
	var kind := str(c.get("t", "text"))
	# Joins, leaves and the like come from Nakama itself with code > 0.
	if int(m.get("code", 0)) != 0:
		kind = "system"
	return {"id": str(m.get("message_id", "")), "from": sender, "name": str(c.get("n", "Hunter")),
		"kind": kind, "code": int(m.get("code", 0)), "c": c, "mine": sender == str(online()["user_id"]),
		"at": Time.get_unix_time_from_datetime_string(str(m.get("create_time", "")).get_slice(".", 0).trim_suffix("Z"))}


## What a message says, in one line.
static func message_text(msg: Dictionary) -> String:
	var c: Dictionary = msg["c"]
	match str(msg["kind"]):
		"text":
			return str(c.get("body", ""))
		"emote":
			return EMOTE_TEXT.get(str(c.get("id", "")), "!")
		"invite":
			return "Hunt with me! %s" % DB.TIERS[clampi(int(c.get("tier", 0)), 0, DB.TIERS.size() - 1)]["name"]
		"brag":
			return "Found %s!" % str(c.get("item", "something"))
		"raid":
			return str(c.get("body", ""))
		"system":
			# Nakama's own lines: 3 joined, 4 added, 5 left, 6 kicked,
			# 7 promoted, 8 banned, 9 demoted. They carry no display name.
			return {3: "A new hunter joined the clan", 4: "A new hunter was let in", 5: "A hunter left the clan",
				6: "A hunter was removed", 7: "A hunter became an Elder", 8: "A hunter was banned",
				9: "An Elder stepped down"}.get(int(msg.get("code", 0)), "Clan news")
	return ""


func send_chat(content: Dictionary) -> String:
	if clan_channel == "":
		return "Not connected to clan chat."
	var r := await socket_call({"channel_message_send": {"channel_id": clan_channel, "content": JSON.stringify(content)}})
	if r.has("error"):
		var e = r["error"]
		return _clean_error(str(e.get("message", "Something went wrong")) if e is Dictionary else "Something went wrong")
	return ""


func unread() -> int:
	var seen := int(online()["chat_seen"])
	var n := 0
	for m in clan_log:
		if int(m["at"]) > seen and not bool(m["mine"]):
			n += 1
	return n


func mark_chat_read() -> void:
	if not clan_log.is_empty():
		online()["chat_seen"] = int(clan_log[-1]["at"])
		Game.save()


func _trim_log() -> void:
	while clan_log.size() > CHAT_KEEP:
		clan_log.pop_front()


# --- Clan raid ------------------------------------------------------------------------

func raid_status() -> Dictionary:
	return await rpc_call("raid_status")


# --- Socket events --------------------------------------------------------------------

func _on_event(env: Dictionary) -> void:
	if env.has("channel_message"):
		var m: Dictionary = env["channel_message"]
		if str(m.get("channel_id", "")) == clan_channel:
			var msg := parse_message(m)
			if blocked.has(msg["from"]):
				return
			clan_log.append(msg)
			_trim_log()
			chat_message.emit(msg)
	elif env.has("notifications"):
		for n in _as_list(env["notifications"].get("notifications")):
			_on_notification(n)
	elif env.has("party") or env.has("party_presence_event") or env.has("party_data") or env.has("party_close") or env.has("party_leader"):
		party.on_event(env)


func _on_notification(n: Dictionary) -> void:
	var code := int(n.get("code", 0))
	match code:
		100:
			fetch_grants()
		-2:
			notice.emit(str(n.get("subject", "Someone wants to be friends")))
			social_changed.emit()
		-3:
			notice.emit(str(n.get("subject", "A friend request was accepted")))
			social_changed.emit()
		-4, -5, -6:
			# Clan requests and membership changes.
			await refresh_me()
			social_changed.emit()

