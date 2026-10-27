extends Node
## Sound effects and music. Effects are looked up by event name; files named
## <event>_<n>.ogg are variants picked at random. Each event is rate limited
## so a hundred hits in one frame read as one crunch, not a wall of noise.

const SFX_DIR := "res://assets/audio/sfx/"
const MUSIC_DIR := "res://assets/audio/music/"
const VOICES := 24
const MIN_GAP := 0.045

## Sounds stacked under an event so the big moments have body: each entry is
## [event, extra dB, pitch]. "thump" is a low sine drop made in code (no file).
const LAYERS := {
	"hit": [["thump", -13.0, 1.15]],
	"blade_hit": [["thump", -15.0, 1.2]],
	"contact": [["thump", -13.0, 1.0]],
	"crit": [["thump", -5.0, 0.8], ["impact", -10.0, 1.25], ["sparkle", -17.0, 1.5]],
	"enemy_die": [["thump", -11.0, 0.9]],
	"hero_hurt": [["thump", -6.0, 0.75]],
	"boss_hit": [["thump", -5.0, 0.7], ["impact", -9.0, 0.8]],
	"boss_slam": [["thump", 0.0, 0.6], ["boom", -8.0, 0.8]],
	"boss_die": [["thump", 0.0, 0.55], ["boom", -5.0, 0.8]],
	"shield_break": [["thump", -8.0, 0.9]],
}
const LAYER_GAP := 0.07

## How much each fight sound adds to the music's intensity (0..1). Sounds
## stand in for "how hot is the fight", so no combat code has to report it.
const HEAT := {
	"hit": 0.035, "blade_hit": 0.03, "contact": 0.04, "crit": 0.07, "enemy_die": 0.045,
	"hero_hurt": 0.12, "boss_hit": 0.07, "boss_roar": 0.4, "boss_slam": 0.25,
	"boss_windup": 0.1, "aggro": 0.08, "shield_break": 0.1, "impact": 0.03,
	"fire_hit": 0.03, "thunder": 0.1, "meteor": 0.1, "nova": 0.08, "quake": 0.15,
}
## Per track, the intensity the music never drops under (home stays wide open).
const MUSIC_FLOOR := {"home": 1.0, "boss": 0.7, "boss_2": 0.7, "grove_boss": 0.7, "frozen_boss": 0.7, "swamp_boss": 0.7, "rift": 0.6}

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
## 0..1, how heated the fight is; it falls back on its own in a few seconds.
var intensity := 0.0
## When any sound that is not a fight sound last played (ms), so the shared
## button click can tell a button already made its own noise.
var last_menu_ms := 0
var _shown := 0.0
var _last_layer := {}
var _lp: AudioEffectLowPassFilter
var _amp: AudioEffectAmplify
var _tick_acc := 0.0


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
	_variants["thump"] = [_make_thump(40.0, 130.0, 31), _make_thump(46.0, 105.0, 77)]
	_music_a = AudioStreamPlayer.new()
	_music_b = AudioStreamPlayer.new()
	_music_a.bus = "Music" if _has_buses else "Master"
	_music_b.bus = _music_a.bus
	add_child(_music_a)
	add_child(_music_b)
	if _has_buses:
		# Appended after the menu low-pass, so that one keeps its slot (0).
		var bus := AudioServer.get_bus_index("Music")
		_lp = AudioEffectLowPassFilter.new()
		_lp.cutoff_hz = 20500.0
		_lp.resonance = 0.7
		_amp = AudioEffectAmplify.new()
		AudioServer.add_bus_effect(bus, _lp)
		AudioServer.add_bus_effect(bus, _amp)


## A short low drop (a sine that falls from `hi` to `lo` Hz, with a tick at
## the start) to give hits some weight. Seeded, so it is the same every run.
func _make_thump(lo: float, hi: float, seed_: int) -> AudioStreamWAV:
	var rate := 22050
	var n := int(rate * 0.22)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_
	var data := PackedByteArray()
	data.resize(n * 2)
	var phase := 0.0
	for i in n:
		var t := float(i) / rate
		phase += TAU * (lo + (hi - lo) * exp(-t * 26.0)) / rate
		var v := sin(phase) * exp(-t * 15.0) * minf(1.0, t * 500.0) * 0.9
		v += rng.randf_range(-1.0, 1.0) * exp(-t * 140.0) * 0.22
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.data = data
	return w


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
	if HEAT.has(event):
		intensity = minf(1.0, intensity + float(HEAT[event]))
	else:
		last_menu_ms = Time.get_ticks_msec()
	_voice(list, volume, pitch, jitter)
	if LAYERS.has(event) and now - float(_last_layer.get(event, -1.0)) >= LAYER_GAP:
		_last_layer[event] = now
		for l in LAYERS[event]:
			_voice(_variants.get(l[0], []), volume + float(l[1]), pitch * float(l[2]), jitter)


func _voice(list: Array, volume: float, pitch: float, jitter: float) -> void:
	if list.is_empty():
		return
	var p := _players[_next]
	_next = (_next + 1) % VOICES
	var pick = list[randi() % list.size()]
	p.stream = pick if pick is AudioStream else load(pick)
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


func _process(dt: float) -> void:
	tick(dt)


## Lets the fight cool and moves the music toward it: calm hunts sit a little
## darker and quieter, a busy fight opens the filter and lifts the level, and a
## boss or the camp never dips below its floor.
func tick(dt: float) -> void:
	intensity = maxf(0.0, intensity - dt * 0.11)
	var floor_v: float = float(MUSIC_FLOOR.get(_music_name, 0.0))
	var target := maxf(intensity, floor_v)
	# Quick to rise, slow to settle.
	_shown = move_toward(_shown, target, dt * (2.5 if target > _shown else 0.35))
	_tick_acc += dt
	if _tick_acc < 0.1 or _lp == null:
		return
	_tick_acc = 0.0
	var k := clampf(_shown, 0.0, 1.0)
	_lp.cutoff_hz = 5500.0 * pow(20500.0 / 5500.0, k)
	_amp.volume_db = -2.5 + 3.0 * k
	AudioServer.set_bus_effect_enabled(AudioServer.get_bus_index("Music"), 1, k < 0.98)
	AudioServer.set_bus_effect_enabled(AudioServer.get_bus_index("Music"), 2, k < 0.98)


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
