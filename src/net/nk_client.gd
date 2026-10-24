extends Node
## A small Nakama client (part 1 of the online layer, see online.gd): REST
## calls, sign-in and the realtime socket. Written here rather than using the
## Nakama Godot SDK because that registers global classes, which an
## over-the-air pack can't add (see CLAUDE.md).

const Cfg := preload("res://src/net/net_config.gd")

## Every socket message that is not a reply to one of our calls.
signal socket_event(env: Dictionary)
signal socket_up_changed(up: bool)

var base := ""
var ws_base := ""
var server_key := Cfg.SERVER_KEY
var token := ""
var token_exp := 0
var user_id := ""
var device_key := ""

var _ws: WebSocketPeer
var _ws_open := false
var _cid := 0
var _waiting := {}


## One pending socket reply.
class Reply extends RefCounted:
	signal done(env: Dictionary)


func _init() -> void:
	set_server(("https://" if Cfg.SSL else "http://") + Cfg.HOST + ":" + str(Cfg.PORT) if Cfg.HOST != "" else "")
	# The last address the config file gave, so a moved test server is found offline-first.
	var cached := _read_cached()
	if cached != "":
		set_server(cached)
	# `-- --server=http://127.0.0.1:7350` points a dev build at a local server.
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--server="):
			_pinned = true
			set_server(a.substr(9))
		elif a.begins_with("--server-key="):
			server_key = a.substr(13)


var _pinned := false
const CACHE := "user://server_url.txt"


## Points the client at `url` ("https://host[:port]"); "" goes offline.
func set_server(url: String) -> void:
	if url == "":
		base = ""
		ws_base = ""
		return
	var ssl := url.begins_with("https")
	var u := url.trim_prefix("https://").trim_prefix("http://").trim_suffix("/")
	var host := u.get_slice(":", 0)
	var port := int(u.get_slice(":", 1)) if u.contains(":") else (443 if ssl else 80)
	base = "%s://%s:%d" % ["https" if ssl else "http", host, port]
	ws_base = "%s://%s:%d" % ["wss" if ssl else "ws", host, port]


static func _read_cached() -> String:
	var f := FileAccess.open(CACHE, FileAccess.READ)
	return f.get_as_text().strip_edges() if f else ""


func _get_json(url: String, headers: Array):
	if url == "":
		return null
	var req := HTTPRequest.new()
	req.timeout = Cfg.TIMEOUT
	add_child(req)
	if req.request(url, PackedStringArray(headers)) != OK:
		req.queue_free()
		return null
	var res: Array = await req.request_completed
	req.queue_free()
	if int(res[0]) != HTTPRequest.RESULT_SUCCESS or int(res[1]) != 200:
		return null
	return JSON.parse_string((res[3] as PackedByteArray).get_string_from_utf8())


## Reads Cfg.CONFIG_URL ({"url": "https://…", "key": "…"}) so the test server
## can move without a new build. Keeps the current address on any failure.
func fetch_config() -> void:
	if Cfg.CONFIG_URL == "" or _pinned:
		return
	# The GitHub contents API first: raw.githubusercontent.com caches for minutes.
	var d = await _get_json(Cfg.CONFIG_API, ["Accept: application/vnd.github.raw+json", "User-Agent: gravelight"])
	if not d is Dictionary:
		d = await _get_json(Cfg.CONFIG_URL + "?t=%d" % Time.get_unix_time_from_system(), [])
	if not d is Dictionary or not str(d.get("url", "")).begins_with("http"):
		return
	set_server(str(d["url"]))
	if str(d.get("key", "")) != "":
		server_key = str(d["key"])
	var f := FileAccess.open(CACHE, FileAccess.WRITE)
	if f:
		f.store_string(str(d["url"]))


func configured() -> bool:
	return base != ""


func signed_in() -> bool:
	return token != "" and Time.get_unix_time_from_system() < token_exp - 60


# --- REST ---------------------------------------------------------------------

## Any REST call. Returns {ok, code, data, error}; never throws, and gives up
## after Cfg.TIMEOUT, so callers can always just read `ok`.
func http(method: int, path: String, body = null, auth := "") -> Dictionary:
	if base == "":
		return {"ok": false, "code": 0, "error": "Offline"}
	var req := HTTPRequest.new()
	req.timeout = Cfg.TIMEOUT
	req.use_threads = false
	add_child(req)
	var headers := PackedStringArray(["Content-Type: application/json", "Accept: application/json"])
	headers.append("Authorization: " + (auth if auth != "" else "Bearer " + token))
	var text: String = "" if body == null else (body if body is String else JSON.stringify(body))
	var err := req.request(base + path, headers, method, text)
	if err != OK:
		req.queue_free()
		return {"ok": false, "code": 0, "error": "Can't reach the server"}
	var res: Array = await req.request_completed
	req.queue_free()
	var code: int = res[1]
	var raw: PackedByteArray = res[3]
	var parsed = JSON.parse_string(raw.get_string_from_utf8()) if raw.size() > 0 else {}
	if int(res[0]) != HTTPRequest.RESULT_SUCCESS:
		return {"ok": false, "code": 0, "error": "Can't reach the server"}
	if code < 200 or code >= 300:
		var msg := "Server error"
		if parsed is Dictionary and parsed.has("message"):
			msg = _clean_error(str(parsed["message"]))
		return {"ok": false, "code": code, "error": msg}
	return {"ok": true, "code": code, "data": parsed if parsed is Dictionary else {}}


## Lua errors arrive wrapped ("...gravelight.lua:123: Message"): keep the message.
static func _clean_error(m: String) -> String:
	var i := m.rfind(".lua:")
	if i >= 0:
		var rest := m.substr(i + 5)
		var j := rest.find(": ")
		if j >= 0:
			m = rest.substr(j + 2)
	return m.get_slice("\nstack traceback", 0).strip_edges()


## A signed-in call: signs in again once when the session has lapsed.
func call_api(method: int, path: String, body = null) -> Dictionary:
	if not signed_in():
		var a := await authenticate(device_key)
		if not a["ok"]:
			return a
	var r := await http(method, path, body)
	if int(r["code"]) == 401:
		var a2 := await authenticate(device_key)
		if not a2["ok"]:
			return a2
		r = await http(method, path, body)
	return r


func get_api(path: String) -> Dictionary:
	return await call_api(HTTPClient.METHOD_GET, path)


func post_api(path: String, body = {}) -> Dictionary:
	return await call_api(HTTPClient.METHOD_POST, path, body)


func delete_api(path: String) -> Dictionary:
	return await call_api(HTTPClient.METHOD_DELETE, path)


## Calls one of our server functions. Returns {ok, data | error}.
func rpc_call(id: String, payload := {}) -> Dictionary:
	# Nakama wants the payload as a JSON string, itself sent as JSON.
	var r := await call_api(HTTPClient.METHOD_POST, "/v2/rpc/" + id, JSON.stringify(JSON.stringify(payload)))
	if not r["ok"]:
		return r
	var inner = JSON.parse_string(str(r["data"].get("payload", "{}")))
	return {"ok": true, "data": inner if inner is Dictionary else {}}


## Signs in with this install's device key, making the account the first time.
func authenticate(key: String) -> Dictionary:
	device_key = key
	var basic := "Basic " + Marshalls.utf8_to_base64(server_key + ":")
	var r := await http(HTTPClient.METHOD_POST, "/v2/account/authenticate/device?create=true", {"id": key}, basic)
	if not r["ok"]:
		return r
	token = str(r["data"].get("token", ""))
	var claims := jwt_claims(token)
	token_exp = int(claims.get("exp", 0))
	user_id = str(claims.get("uid", ""))
	return {"ok": token != ""}


## The claims inside a session token (its middle part, base64url JSON).
static func jwt_claims(t: String) -> Dictionary:
	var parts := t.split(".")
	if parts.size() < 2:
		return {}
	var b := parts[1].replace("-", "+").replace("_", "/")
	while b.length() % 4 != 0:
		b += "="
	var d = JSON.parse_string(Marshalls.base64_to_utf8(b))
	return d if d is Dictionary else {}


# --- Realtime socket -------------------------------------------------------------

func socket_up() -> bool:
	return _ws_open


func open_socket() -> bool:
	if _ws != null or not signed_in():
		return _ws_open
	_ws = WebSocketPeer.new()
	_ws.inbound_buffer_size = 1 << 20
	if _ws.connect_to_url("%s/ws?lang=en&status=true&token=%s" % [ws_base, token]) != OK:
		_ws = null
		return false
	var waited := 0.0
	while is_inside_tree() and _ws != null and _ws.get_ready_state() == WebSocketPeer.STATE_CONNECTING and waited < Cfg.TIMEOUT:
		await get_tree().process_frame
		waited += get_process_delta_time()
	return _ws_open


func close_socket() -> void:
	if _ws:
		_ws.close()
	_ws = null
	_set_open(false)


## Sends a socket message and waits for its reply ({} on timeout).
func socket_call(msg: Dictionary) -> Dictionary:
	if not _ws_open:
		return {"error": {"message": "Not connected"}}
	_cid += 1
	var cid := str(_cid)
	msg["cid"] = cid
	var rep := Reply.new()
	_waiting[cid] = rep
	_ws.send_text(JSON.stringify(msg))
	get_tree().create_timer(Cfg.TIMEOUT).timeout.connect(func():
		if _waiting.has(cid):
			_waiting.erase(cid)
			rep.done.emit({"error": {"message": "No answer from the server"}}))
	var env: Dictionary = await rep.done
	return env


## Sends a socket message without waiting (positions, presence).
func socket_send(msg: Dictionary) -> void:
	if _ws_open:
		_ws.send_text(JSON.stringify(msg))


func _process(_dt: float) -> void:
	if _ws == null:
		return
	_ws.poll()
	var st := _ws.get_ready_state()
	if st == WebSocketPeer.STATE_OPEN:
		if not _ws_open:
			_set_open(true)
		while _ws.get_available_packet_count() > 0:
			var env = JSON.parse_string(_ws.get_packet().get_string_from_utf8())
			if env is Dictionary:
				_route(env)
	elif st == WebSocketPeer.STATE_CLOSED:
		_ws = null
		_set_open(false)


func _route(env: Dictionary) -> void:
	var cid := str(env.get("cid", ""))
	if cid != "" and _waiting.has(cid):
		var rep: Reply = _waiting[cid]
		_waiting.erase(cid)
		rep.done.emit(env)
		return
	socket_event.emit(env)


func _set_open(up: bool) -> void:
	if up == _ws_open:
		return
	_ws_open = up
	if not up:
		for cid in _waiting.keys():
			var rep: Reply = _waiting[cid]
			rep.done.emit({"error": {"message": "Disconnected"}})
		_waiting.clear()
	socket_up_changed.emit(up)
