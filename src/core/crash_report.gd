extends Node
## Opt-in crash reporting to a Sentry-compatible endpoint. Not a class_name:
## preload it by path.
##
## The DSN is never committed. It comes from the CC_CRASH_DSN environment
## variable (desktop tests) or the `crash/dsn` project setting that CI stamps
## into the IPA from the CRASH_DSN secret. With no DSN, or without the player's
## yes on the privacy screen, nothing is built or sent: the local error log
## (error_log.gd) is all that exists.
##
## What is sent, once per crash and only on the next launch: the build, Godot
## and OS versions, the device model, session and crash counts, and the logged
## script errors (file, line, message). No save data, name, account or IDs.

const Privacy := preload("res://src/core/privacy.gd")
const TIMEOUT := 8.0

var _http: HTTPRequest


## The configured DSN, or "".
static func dsn() -> String:
	var e := OS.get_environment("CC_CRASH_DSN")
	if e != "":
		return e
	return str(ProjectSettings.get_setting("crash/dsn", ""))


## Splits a DSN `https://<key>@<host>/<project>` into {url, key}. {} when it is
## not a usable https DSN.
static func parse_dsn(d: String) -> Dictionary:
	if not d.begins_with("https://"):
		return {}
	var rest := d.trim_prefix("https://")
	var at := rest.find("@")
	var slash := rest.rfind("/")
	if at <= 0 or slash <= at + 1 or slash == rest.length() - 1:
		return {}
	var key := rest.substr(0, at)
	var host := rest.substr(at + 1, slash - at - 1)
	var project := rest.substr(slash + 1)
	if key.contains(":"):
		key = key.get_slice(":", 0)
	if not project.is_valid_int():
		return {}
	return {"url": "https://%s/api/%s/envelope/" % [host, project], "key": key}


## The event for the last crashed session, from the local error log.
static func event(log_: Object, release: String, build: int) -> Dictionary:
	var values: Array = []
	var errs: Array = log_.recent(5)
	for e: Dictionary in errs:
		values.append({"type": str(e["kind"]), "value": "%s: %s" % [e["where"], e["msg"]]})
	var id := ""
	for i in 32:
		id += "0123456789abcdef"[randi() % 16]
	return {
		"event_id": id,
		"timestamp": Time.get_datetime_string_from_system(true) + "Z",
		"platform": "other",
		"level": "fatal",
		"release": release,
		"environment": "production",
		"message": "Previous session ended unexpectedly",
		"tags": {"build": str(build), "godot": Engine.get_version_info()["string"], "os": OS.get_name()},
		"contexts": {"os": {"name": OS.get_name(), "version": OS.get_version()}, "device": {"model": OS.get_model_name()}},
		"exception": {"values": values},
		"extra": {"sessions": log_.session_count(), "crashes": log_.crash_count()},
	}


## The Sentry envelope body: header, item header, event, newline separated.
static func envelope(d: String, ev: Dictionary) -> String:
	return "%s\n%s\n%s" % [JSON.stringify({"event_id": ev["event_id"], "dsn": d}), JSON.stringify({"type": "event"}), JSON.stringify(ev)]


## Whether a report is due and allowed: a DSN, a yes, and a crash not yet sent.
static func due(log_: Object) -> bool:
	if parse_dsn(dsn()).is_empty() or not Privacy.crash_ok():
		return false
	var rec: Dictionary = Game.data["privacy"]
	var n: int = log_.crash_count()
	if n < int(rec["crash_sent"]):
		rec["crash_sent"] = n
	return n > int(rec["crash_sent"])


## Sends the last crash if one is due. Returns "sent", "failed" or "skipped".
func send_if_due(log_: Object, release: String, build: int) -> String:
	if not due(log_):
		return "skipped"
	var d := dsn()
	var t := parse_dsn(d)
	var ev := event(log_, release, build)
	if _http == null:
		_http = HTTPRequest.new()
		_http.timeout = TIMEOUT
		add_child(_http)
	var headers := PackedStringArray([
		"Content-Type: application/x-sentry-envelope",
		"X-Sentry-Auth: Sentry sentry_version=7, sentry_client=gravelight/1, sentry_key=%s" % t["key"]])
	if _http.request(str(t["url"]), headers, HTTPClient.METHOD_POST, envelope(d, ev)) != OK:
		return "failed"
	var res: Array = await _http.request_completed
	if int(res[0]) != HTTPRequest.RESULT_SUCCESS or int(res[1]) >= 300:
		return "failed"
	Game.data["privacy"]["crash_sent"] = log_.crash_count()
	Game.save()
	return "sent"
