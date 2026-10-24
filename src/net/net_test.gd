extends Node
## `-- --nettest --server=http://127.0.0.1:7350` walks the game's online layer
## against a test server (server/test/run_local.sh): sign-in, names, the
## reward inbox, referrals, cloud saves, clans, chat, the raid, friends,
## parties and deletion. Prints NETTEST PASSED. Makes accounts, so never point
## it at the live server.

const Online := preload("res://src/net/online.gd")
const NkClient := preload("res://src/net/nk_client.gd")

var fails := 0


func _ok(name_: String, cond: bool, extra = "") -> void:
	print(("OK   " if cond else "FAIL ") + name_ + ("" if cond else "  " + str(extra)))
	if not cond:
		fails += 1


func run(main: Node) -> int:
	Game.data = Game._fresh()
	Game.data["profile"]["name"] = "Testy %d" % (randi() % 1000)
	var o: Node = Online.start(main)
	await _until(func(): return o.state in ["on", "down"], 15.0)
	_ok("signs in", o.state == "on", o.state)
	if o.state != "on":
		return 1
	await _until(func(): return o.socket_up(), 5.0)
	_ok("socket open", o.socket_up())
	_ok("friend code", o.my_code().length() == 6, o.my_code())
	_ok("name sent to server", str((await o.refresh_me())["data"].get("name", "")) == Game.player_name())
	var bad: Dictionary = await o.set_player_name("shit head")
	_ok("rude name refused", not bad["ok"] and str(bad.get("error", "")).length() > 3, bad)

	# A friend brings this player in: welcome gift lands in the save.
	var friend := NkClient.new()
	main.add_child(friend)
	await friend.authenticate(Crypto.new().generate_random_bytes(20).hex_encode())
	var fb: Dictionary = await friend.rpc_call("bootstrap")
	var gold0 := Game.gold()
	var gifts := []
	o.gifts_arrived.connect(func(l): gifts.append_array(l))
	var red: Dictionary = await o.redeem(str(fb["data"]["code"]))
	_ok("redeem friend code", red["ok"], red)
	await _until(func(): return not gifts.is_empty(), 5.0)
	_ok("welcome gift applied", Game.gold() >= gold0 + 2000 and not gifts.is_empty(), [Game.gold(), gifts])
	_ok("welcome chest queued", str(main.pending_chest) != "", main.pending_chest)
	await _until(func(): return not o._grants_busy, 5.0)
	var g2: Dictionary = await o.rpc_call("list_grants")
	_ok("grants acked", Online._as_list(g2["data"].get("grants")).is_empty(), g2)
	var again: Dictionary = await o.redeem(str(fb["data"]["code"]))
	_ok("second redeem refused with a reason", not again["ok"] and str(again["error"]).contains("already"), again)
	var fl: Dictionary = await o.friends()
	_ok("recruiter is a friend", fl["ok"] and fl["data"].size() == 1 and int(fl["data"][0]["state"]) == 0, fl)
	var bad_code: Dictionary = await o.add_friend("ZZZZZ9")
	_ok("unknown friend code refused", not bad_code["ok"], bad_code)

	# Cloud save round trip.
	var sv: Dictionary = await o.cloud_save()
	_ok("cloud save", sv["ok"], sv)
	var peek: Dictionary = await o.cloud_peek()
	_ok("cloud save read back", str(peek.get("data", "")).contains(Game.player_name()), peek.keys())

	# Clans and chat.
	var cname := "Netclan %04d" % (randi() % 10000)
	var cc: Dictionary = await o.create_clan(cname, "Testing", 2, true, 0)
	_ok("clan created", cc["ok"] and o.in_clan(), cc)
	await _until(func(): return o.clan_channel != "", 5.0)
	_ok("clan chat joined", o.clan_channel != "")
	var got := []
	o.chat_message.connect(func(m): got.append(m))
	var err: String = await o.send_chat({"t": "text", "body": "hello fucking clan"})
	_ok("chat sent", err == "", err)
	await _until(func(): return not got.is_empty(), 3.0)
	_ok("chat echoed with name", not got.is_empty() and str(got[0]["name"]) == Game.player_name(), got)
	_ok("rude word masked", not got.is_empty() and not Online.message_text(got[0]).contains("fucking"), got)
	await get_tree().create_timer(1.1).timeout
	err = await o.send_chat({"t": "text", "body": "find me at www.spam.com"})
	_ok("links refused", err != "", err)
	var found: Dictionary = await o.find_clans(cname.left(7))
	_ok("clan search", found["ok"] and found["data"].any(func(c): return c["name"] == cname), found)
	var mc: Dictionary = await o.my_clan()
	_ok("my clan", mc["ok"] and int(mc["data"]["badge"]) == 2, mc)
	var mem: Dictionary = await o.clan_members()
	_ok("members list", mem["ok"] and mem["data"].size() == 1 and int(mem["data"][0]["role"]) == 0, mem)
	var rs: Dictionary = await o.raid_status()
	_ok("raid status", rs["ok"] and int(rs["data"].get("max", 0)) > 0, rs)
	var hp0 := int(rs["data"].get("hp", 0))
	# A won hunt reports progress and hits the raid boss.
	await o.after_hunt({"win": true, "tier": 0, "kills": 100, "elites": 2, "bosses": ["gravemaw"]})
	rs = await o.raid_status()
	_ok("hunt hits the raid boss", int(rs["data"].get("hp", 0)) == hp0 - Online.raid_damage({"win": true, "tier": 0, "kills": 100, "elites": 2, "bosses": ["gravemaw"]}), [hp0, rs])
	var lb: Dictionary = await o.leaderboard("power")
	_ok("leaderboard", lb["ok"], lb)
	# Weekly challenge: a best omen hunt reaches the weekly board.
	Game.data["weekly"] = {"week": Game.week_number(), "best": 4321, "omen": "test", "hero": Game.hero_id()}
	var ws: Dictionary = await o.submit_weekly()
	_ok("weekly submit", ws["ok"] and int(ws["data"].get("score", 0)) == 4321, ws)
	var wl: Dictionary = await o.leaderboard("weekly")
	_ok("weekly board has my score", wl["ok"] and int(wl["mine"].get("score", 0)) == 4321 and int(wl["mine"].get("rank", 0)) >= 1, wl)
	var stale: Dictionary = await o.rpc_call("weekly_submit", {"week": Game.week_number() - 1, "best": 99})
	_ok("last week's score refused", stale["ok"] and bool(stale["data"].get("stale", false)), stale)

	# Parties: the friend joins over their own socket.
	var perr: String = await o.party.create()
	_ok("party made", perr == "" and o.party.active() and o.party.is_leader(), perr)
	await friend.open_socket()
	var fj: Dictionary = await friend.socket_call({"party_join": {"party_id": o.party.id}})
	_ok("friend joins party", not fj.has("error"), fj)
	await _until(func(): return o.party.members.size() == 2, 5.0)
	_ok("party sees two", o.party.members.size() == 2, o.party.members)
	friend.socket_send({"party_data_send": {"party_id": o.party.id, "op_code": 3,
		"data": Marshalls.utf8_to_base64(JSON.stringify({"hero": "mage", "ready": true, "dmg": 99999}))}})
	await _until(func(): return o.party.all_ready(), 5.0)
	_ok("partner ready, stats clamped", o.party.all_ready() and float(o.party.members[friend.user_id]["dmg"]) <= 2000.0, o.party.members)
	var pinv: String = await o.party.invite_clan()
	_ok("party invite posted", pinv == "" or pinv.contains("Slow"), pinv)
	o.party.leave()
	_ok("left party", not o.party.active())

	var lv: Dictionary = await o.leave_clan()
	_ok("left clan", lv["ok"] and not o.in_clan(), lv)
	var tm: Dictionary = await o.transfer_make()
	_ok("transfer code", tm["ok"] and str(tm["data"].get("code", "")).length() == 8, tm)
	var del: Dictionary = await o.delete_account()
	_ok("account deleted, progress reset", del["ok"] and Game.gold() == 0 and str(Game.data["online"]["user_id"]) == "", del)
	friend.close_socket()
	print("NETTEST %s" % ("PASSED" if fails == 0 else "%d FAILED" % fails))
	return fails


func _until(cond: Callable, secs: float) -> void:
	var t := 0.0
	while not cond.call() and t < secs:
		await get_tree().process_frame
		t += get_process_delta_time()
