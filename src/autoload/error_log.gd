extends Logger
## Not a class_name: an over-the-air pack cannot register new global classes
## (the baked IPA's class list is fixed), so users preload it by path.
## Local crash and error log, for playtests without a backend. Every engine and
## script error lands here (deduplicated by place), and a session that never
## closed cleanly counts as a crash. Settings copies it all as one report the
## tester can paste into a message. Kept out of the save on purpose: a broken
## save must not take the log down with it.

const PATH := "user://errors.json"
const MAX := 40

var _mutex := Mutex.new()
## {sessions, crashes, last_crash_build, errors: [{at, kind, where, msg, count, build, first, last}]}
var _d := {"sessions": 0, "crashes": 0, "last_crash_build": 0, "errors": []}
var _build := 0
var _enabled := true
## Set while writing, so an error raised by the write itself can't recurse.
var _busy := false


## Installs the log for this run. Bots and captures stay out of the file.
static func install(enabled: bool) -> Logger:
	var l = load("res://src/autoload/error_log.gd").new()
	l._enabled = enabled
	if enabled:
		l._load()
		l._d["sessions"] = int(l._d["sessions"]) + 1
		# The flag outlives a crash: if it is still here, the last run died.
		if FileAccess.file_exists(l._flag()):
			l._d["crashes"] = int(l._d["crashes"]) + 1
			l._d["last_crash_build"] = int(l._read_flag())
		l.session_open()
		l._write()
	OS.add_logger(l)
	return l


func set_build(b: int) -> void:
	_build = b
	if _enabled:
		session_open()


## Called on start and when the app comes back; iOS kills background apps
## without notice, so a backgrounded app counts as a clean exit.
func session_open() -> void:
	var f := FileAccess.open(_flag(), FileAccess.WRITE)
	if f:
		f.store_string(str(_build))


func session_closed() -> void:
	if _enabled and FileAccess.file_exists(_flag()):
		DirAccess.remove_absolute(_flag())


func _log_error(function: String, file: String, line: int, code: String, rationale: String,
		_editor_notify: bool, error_type: int, script_backtraces: Array[ScriptBacktrace]) -> void:
	if error_type == ERROR_TYPE_WARNING or _busy:
		return
	var kind: String = ["error", "warning", "script", "shader"][clampi(error_type, 0, 3)]
	var where := "%s:%d %s" % [file.get_file(), line, function]
	# push_error and engine errors point at C++; the script line is what helps.
	for bt in script_backtraces:
		if bt.get_frame_count() > 0:
			where = "%s:%d %s" % [bt.get_frame_file(0).get_file(), bt.get_frame_line(0), bt.get_frame_function(0)]
			break
	var msg := rationale if rationale != "" else code
	_add(kind, where, msg)


func _log_message(_message: String, _error: bool) -> void:
	pass


func _add(kind: String, where: String, msg: String) -> void:
	_mutex.lock()
	var now := int(Time.get_unix_time_from_system())
	var list: Array = _d["errors"]
	var hit := false
	for e in list:
		if e["where"] == where and e["msg"] == msg:
			e["count"] = int(e["count"]) + 1
			e["last"] = now
			hit = true
			break
	if not hit:
		list.append({"kind": kind, "where": where, "msg": msg.left(300), "count": 1, "build": _build, "first": now, "last": now})
		while list.size() > MAX:
			list.pop_front()
	_mutex.unlock()
	# Only new errors hit the disk: a loop that errors every frame writes once.
	if not hit:
		_write()


func error_count() -> int:
	_mutex.lock()
	var n := 0
	for e in _d["errors"]:
		n += int(e["count"])
	_mutex.unlock()
	return n


func crash_count() -> int:
	return int(_d["crashes"])


## Everything in plain text, newest error first, ready to paste.
func report(header: String) -> String:
	_mutex.lock()
	var lines := [header, "Device: %s · %s %s" % [OS.get_model_name(), OS.get_name(), OS.get_version()],
		"Sessions: %d · crashes: %d (last on build %d)" % [int(_d["sessions"]), int(_d["crashes"]), int(_d["last_crash_build"])]]
	var list: Array = _d["errors"].duplicate()
	list.reverse()
	if list.is_empty():
		lines.append("No errors logged.")
	for e in list:
		lines.append("[%s] x%d build %d · %s · %s" % [e["kind"], int(e["count"]), int(e["build"]), e["where"], e["msg"]])
	_mutex.unlock()
	return "\n".join(lines)


func clear() -> void:
	_mutex.lock()
	_d["errors"] = []
	_d["crashes"] = 0
	_mutex.unlock()
	_write()


func _flag() -> String:
	return "user://session.flag"


func _read_flag() -> int:
	var f := FileAccess.open(_flag(), FileAccess.READ)
	return int(f.get_as_text()) if f else 0


func _load() -> void:
	if not FileAccess.file_exists(PATH):
		return
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary and parsed.get("errors") is Array:
		_d.merge(parsed, true)


func _write() -> void:
	if not _enabled:
		return
	_busy = true
	_mutex.lock()
	var text := JSON.stringify(_d)
	_mutex.unlock()
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(text)
	_busy = false
