extends Node
## Sound effects and music. Effects are looked up by event name; files named
## <event>_<n>.ogg are variants picked at random. Each event is rate limited
## so a hundred hits in one frame read as one crunch, not a wall of noise.

const SFX_DIR := "res://assets/audio/sfx/"
const MUSIC_DIR := "res://assets/audio/music/"
const VOICES := 24
const MIN_GAP := 0.045

var _variants := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _last := {}
var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _music_name := ""
var _music_tween: Tween
## Track name -> its files: "hunt" is hunt.ogg plus hunt_2.ogg, hunt_3.ogg...
var _tracks := {}
## Track name -> the file it played last, so a variant doesn't repeat.
var _track_last := {}
## True when default_bus_layout.tres is loaded (Music and SFX buses exist).
## Without it (an older install taking a content update) volume falls back to
## per-player levels and ducking does nothing.
var _has_buses := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_has_buses = AudioServer.get_bus_index("SFX") >= 0 and AudioServer.get_bus_index("Music") >= 0
	for f in ResourceLoader.list_directory(SFX_DIR):
		if not f.ends_with(".ogg"):
			continue
		var base := f.get_basename()
		var cut := base.rfind("_")
		var key := base.substr(0, cut) if cut > 0 and base.substr(cut + 1).is_valid_int() else base
		if not _variants.has(key):
			_variants[key] = []
		_variants[key].append(SFX_DIR + f)
	for f in ResourceLoader.list_directory(MUSIC_DIR):
		if not f.ends_with(".ogg"):
			continue
		var base := f.get_basename()
		var cut := base.rfind("_")
		var key := base.substr(0, cut) if cut > 0 and base.substr(cut + 1).is_valid_int() else base
		if not _tracks.has(key):
			_tracks[key] = []
		_tracks[key].append(MUSIC_DIR + f)
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX" if _has_buses else "Master"
		add_child(p)
		_players.append(p)
	_music_a = AudioStreamPlayer.new()
	_music_b = AudioStreamPlayer.new()
	_music_a.bus = "Music" if _has_buses else "Master"
	_music_b.bus = _music_a.bus
	add_child(_music_a)
	add_child(_music_b)


func _sfx_db(extra: float) -> float:
	if _has_buses:
		return extra
	var v := float(Game.setting("sfx")) if Game.data.size() > 0 else 1.0
	return linear_to_db(maxf(v, 0.0001)) + extra


func _music_db() -> float:
	if _has_buses:
		return 0.0
	var v := float(Game.setting("music")) if Game.data.size() > 0 else 0.7
	return linear_to_db(maxf(v * 0.8, 0.0001))


## Plays an event. volume in dB relative, pitch is a base multiplier.
func play(event: String, volume := 0.0, pitch := 1.0, jitter := 0.06) -> void:
	var list: Array = _variants.get(event, [])
	if list.is_empty():
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_last.get(event, -1.0)) < MIN_GAP:
		return
	_last[event] = now
	var p := _players[_next]
	_next = (_next + 1) % VOICES
	p.stream = load(list[randi() % list.size()])
	p.volume_db = _sfx_db(volume)
	p.pitch_scale = pitch * (1.0 + randf_range(-jitter, jitter))
	p.play()


func has(event: String) -> bool:
	return _variants.has(event)


## Crossfades to a music track by name ("home", "hunt", "boss"). A track with
## numbered variants plays a different one than last time, so camp and hunt
## don't loop the same two minutes all session.
func music(track: String, fade := 1.2) -> void:
	if track == _music_name:
		return
	_music_name = track
	var incoming := _music_b if _music_a.playing else _music_a
	var outgoing := _music_a if incoming == _music_b else _music_b
	if _music_tween:
		_music_tween.kill()
	_music_tween = create_tween().set_parallel(true)
	if track != "":
		var stream: AudioStream = load(_pick_track(track))
		if stream is AudioStreamOggVorbis:
			stream.loop = true
		incoming.stream = stream
		incoming.volume_db = -40.0
		incoming.play()
		_music_tween.tween_property(incoming, "volume_db", _music_db(), fade)
	if outgoing.playing:
		_music_tween.tween_property(outgoing, "volume_db", -40.0, fade)
		_music_tween.chain().tween_callback(outgoing.stop)


func _pick_track(track: String) -> String:
	var files: Array = _tracks.get(track, [MUSIC_DIR + track + ".ogg"]).duplicate()
	if files.size() > 1:
		files.erase(_track_last.get(track, ""))
	var path: String = files[randi() % files.size()]
	_track_last[track] = path
	return path


## Applies the music and effects sliders to their buses.
func refresh_volume() -> void:
	if _has_buses and Game.data.size() > 0:
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(maxf(float(Game.setting("sfx")), 0.0001)))
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(maxf(float(Game.setting("music")) * 0.8, 0.0001)))
		return
	for p in [_music_a, _music_b]:
		if p.playing and p.volume_db > -39.0:
			p.volume_db = _music_db()


var _ducked := false
var _muffled := false


## Muffles the music (a low-pass on the Music bus) while a menu is open.
func duck(on: bool) -> void:
	_ducked = on
	_apply_lowpass()


## The same low-pass while the hero is close to death: the world goes dull.
func muffle(on: bool) -> void:
	if on == _muffled:
		return
	_muffled = on
	_apply_lowpass()


func _apply_lowpass() -> void:
	if not _has_buses:
		return
	AudioServer.set_bus_effect_enabled(AudioServer.get_bus_index("Music"), 0, _ducked or _muffled)
