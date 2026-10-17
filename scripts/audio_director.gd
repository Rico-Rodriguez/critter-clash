extends Node

## Music, effects and haptics, mixed on three buses under a limiter.
## Music: home / hunt / boss loops (Kevin MacLeod, CC-BY 4.0) crossfade on
## two players; victory and defeat stings duck the loop. Effects: event
## names map to 1-4 pre-mixed variants in assets/audio/sfx (tools/
## build_sfx.py); each play picks a variant and jitters pitch and volume,
## and per-event voice caps and gaps keep swarms from piling up and
## clipping. Haptics go through Input.vibrate_handheld, which on iOS 13+
## drives Core Haptics with the amplitude as intensity.

const DEFAULTS := {"music_on": true, "sfx_on": true, "haptics_on": true, "music_vol": 0.8, "sfx_vol": 0.9}

## Per-event mix: base gain (dB), max voices at once, minimum gap (s),
## pitch jitter (+/- ratio), bus.
const EVENTS := {
	"ui_tap": [-8.0, 2, 0.03, 0.04, "UI"],
	"ui_press": [-5.0, 2, 0.04, 0.03, "UI"],
	"ui_back": [-6.0, 1, 0.05, 0.03, "UI"],
	"ui_error": [-6.0, 1, 0.2, 0.0, "UI"],
	"ui_toggle": [-6.0, 1, 0.04, 0.02, "UI"],
	"atk_mage": [-9.0, 3, 0.08, 0.07, "SFX"],
	"atk_archer": [-9.0, 3, 0.06, 0.08, "SFX"],
	"atk_tank": [-7.0, 3, 0.08, 0.06, "SFX"],
	"atk_enemy": [-12.0, 3, 0.07, 0.1, "SFX"],
	"hit": [-10.0, 4, 0.035, 0.09, "SFX"],
	"crit": [-6.0, 2, 0.06, 0.05, "SFX"],
	"hero_hurt": [-5.0, 1, 0.25, 0.05, "SFX"],
	"enemy_die": [-8.0, 3, 0.05, 0.1, "SFX"],
	"boss_roar": [-2.0, 1, 1.0, 0.0, "SFX"],
	"boss_windup": [-5.0, 1, 0.5, 0.03, "SFX"],
	"boss_slam": [-3.0, 2, 0.15, 0.04, "SFX"],
	"boss_hit": [-7.0, 2, 0.06, 0.06, "SFX"],
	"boss_die": [-2.0, 1, 1.0, 0.0, "SFX"],
	"gem": [-11.0, 3, 0.03, 0.0, "SFX"],
	"coin": [-8.0, 2, 0.06, 0.05, "SFX"],
	"levelup": [-3.0, 1, 0.5, 0.0, "SFX"],
	"card_pick": [-4.0, 1, 0.1, 0.03, "UI"],
	"card_flip": [-9.0, 3, 0.04, 0.06, "UI"],
	"chest_land": [-5.0, 2, 0.1, 0.05, "SFX"],
	"chest_rattle": [-9.0, 2, 0.08, 0.08, "SFX"],
	"chest_open": [-3.0, 1, 0.3, 0.0, "SFX"],
	"sparkle": [-6.0, 1, 0.3, 0.02, "SFX"],
	"rare_chime": [-3.0, 1, 0.5, 0.0, "SFX"],
	"unlock_start": [-5.0, 1, 0.2, 0.02, "UI"],
	"sting_victory": [-4.0, 1, 1.0, 0.0, "Music"],
	"sting_defeat": [-3.0, 1, 1.0, 0.0, "Music"],
}

## Old call names from before the event map.
const LEGACY := {"click": "ui_press", "merge": "card_pick", "error": "ui_error", "win": "chest_open", "lose": "sting_defeat", "hit": "hit", "shoot": "atk_enemy", "death": "enemy_die", "deploy": "boss_slam", "den": "boss_roar"}

const MUSIC_DB := -6.0

var settings: Dictionary = DEFAULTS.duplicate()
var _pool: Array[AudioStreamPlayer] = []
var _variants := {}
var _streams := {}
var _last := {}
var _decks: Array[AudioStreamPlayer] = []
var _deck := 0
var _track := ""
var _duck := 0.0
var _duck_tw: Tween
var _chain := 0
var _chain_t := 0.0
var _haptic_t := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_buses()
	for i in 24:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool.append(p)
	for i in 2:
		var d := AudioStreamPlayer.new()
		d.bus = "Music"
		d.volume_db = -80.0
		add_child(d)
		_decks.append(d)
	_variants = SfxManifest.COUNTS
	# SaveGame loads after this autoload; read settings once it has.
	call_deferred("_load_settings")


## Music, SFX and UI buses into Master. Effects get a gentle compressor so
## a swarm of hits stays punchy without stacking into distortion, and the
## master has a hard limiter as the last guard.
func _buses() -> void:
	for name in ["Music", "SFX", "UI"]:
		if AudioServer.get_bus_index(name) < 0:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, name)
			AudioServer.set_bus_send(i, "Master")
	var sfx := AudioServer.get_bus_index("SFX")
	if AudioServer.get_bus_effect_count(sfx) == 0:
		var comp := AudioEffectCompressor.new()
		comp.threshold = -14.0
		comp.ratio = 4.0
		comp.attack_us = 3000.0
		comp.release_ms = 140.0
		comp.gain = 2.0
		AudioServer.add_bus_effect(sfx, comp)
	var master := AudioServer.get_bus_index("Master")
	if AudioServer.get_bus_effect_count(master) == 0:
		var lim := AudioEffectHardLimiter.new()
		lim.ceiling_db = -0.8
		# Mix measured at about -22 LUFS integrated with -2 dB peaks; lift it
		# toward mobile loudness and let the limiter hold the ceiling.
		lim.pre_gain_db = 4.0
		AudioServer.add_bus_effect(master, lim)


func _load_settings() -> void:
	var saved = SaveGame.data.get("settings", {})
	settings = DEFAULTS.duplicate()
	if saved is Dictionary:
		for k in saved:
			settings[k] = saved[k]
	_apply()


func set_setting(key: String, value) -> void:
	settings[key] = value
	SaveGame.data["settings"] = settings.duplicate()
	SaveGame._write()
	_apply()


func _apply() -> void:
	var music := AudioServer.get_bus_index("Music")
	AudioServer.set_bus_mute(music, not bool(settings["music_on"]))
	AudioServer.set_bus_volume_db(music, MUSIC_DB + _lin_db(float(settings["music_vol"])) + _duck)
	for name in ["SFX", "UI"]:
		var i := AudioServer.get_bus_index(name)
		AudioServer.set_bus_mute(i, not bool(settings["sfx_on"]))
		AudioServer.set_bus_volume_db(i, _lin_db(float(settings["sfx_vol"])))


static func _lin_db(v: float) -> float:
	return linear_to_db(maxf(v, 0.001))


# --- Effects -----------------------------------------------------------------

## Play an effect event. db and pitch are offsets on top of the event's mix.
func sfx(event: String, db := 0.0, pitch := 1.0) -> void:
	var spec: Array = EVENTS.get(event, [-8.0, 2, 0.05, 0.05, "SFX"])
	var now := Time.get_ticks_msec() / 1000.0
	if _last.has(event) and now - float(_last[event]) < float(spec[2]):
		return
	var count := int(_variants.get(event, 0))
	if count <= 0:
		return
	# Voice cap: if this event already has its share playing, the oldest
	# instance is cut and reused rather than stacking another layer.
	var mine: Array = []
	for p in _pool:
		if p.playing and p.get_meta("event", "") == event:
			mine.append(p)
	var player: AudioStreamPlayer = null
	if mine.size() >= int(spec[1]):
		mine.sort_custom(func(a, b) -> bool: return a.get_playback_position() > b.get_playback_position())
		player = mine[0]
	else:
		for p in _pool:
			if not p.playing:
				player = p
				break
		if player == null:
			# Everything busy: steal the voice furthest along.
			var best := 0.0
			for p in _pool:
				if p.get_playback_position() >= best:
					best = p.get_playback_position()
					player = p
	_last[event] = now
	var k := randi() % count + 1
	var path := "res://assets/audio/sfx/%s_%d.ogg" % [event, k]
	var stream: AudioStream = _streams.get(path)
	if stream == null:
		stream = load(path)
		_streams[path] = stream
	player.stop()
	player.stream = stream
	player.bus = str(spec[4])
	player.set_meta("event", event)
	var jitter := float(spec[3])
	player.pitch_scale = pitch * (1.0 + randf_range(-jitter, jitter))
	player.volume_db = float(spec[0]) + db + randf_range(-1.2, 1.2)
	player.play()


## Back-compat: old names route to events.
func play(name: String, db: float = 0.0) -> void:
	sfx(str(LEGACY.get(name, name)), minf(db + 2.0, 0.0))


func play_throttled(name: String, _gap: float = 0.05) -> void:
	play(name)


## XP gem pickup: each pickup in a quick chain rises a semitone (up to an
## octave), so sweeping a cluster sounds like a run up a scale.
func gem() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	_chain = mini(_chain + 1, 12) if now - _chain_t < 0.45 else 0
	_chain_t = now
	_last.erase("gem")
	sfx("gem", 0.0, pow(2.0, _chain / 12.0))
	haptic("light")


# --- Music -------------------------------------------------------------------

## Crossfade to a loop: "home", "hunt" or "boss".
func music(track: String, fade := 1.4) -> void:
	if track == _track and _decks[_deck].playing:
		return
	_track = track
	var stream: AudioStream = load("res://assets/audio/music/%s.ogg" % track)
	if stream == null:
		return
	stream = stream.duplicate()
	if stream is AudioStreamOggVorbis:
		stream.loop = true
	var old := _decks[_deck]
	_deck = 1 - _deck
	var nxt := _decks[_deck]
	nxt.stream = stream
	nxt.volume_db = -40.0
	nxt.play()
	var tw := create_tween().set_parallel(true)
	tw.tween_property(nxt, "volume_db", 0.0, fade).set_trans(Tween.TRANS_SINE)
	if old.playing:
		tw.tween_property(old, "volume_db", -60.0, fade).set_trans(Tween.TRANS_SINE)
		tw.chain().tween_callback(old.stop)


## Kept for older call sites.
func play_music() -> void:
	if _track == "":
		music("home")


## Victory / defeat sting: the loop drops out, the sting plays, and the
## home theme returns softly afterwards.
func sting(win: bool) -> void:
	var tw := create_tween()
	tw.tween_property(_decks[_deck], "volume_db", -60.0, 0.35)
	tw.tween_callback(_decks[_deck].stop)
	_track = ""
	sfx("sting_victory" if win else "sting_defeat")
	get_tree().create_timer(7.5 if win else 3.0).timeout.connect(func() -> void:
		if _track == "":
			music("home", 3.0)
	)


## Dip the music under a big moment (boss roar, rare drop, level-up).
func duck(db := -7.0, hold := 0.6, release := 0.9) -> void:
	if _duck_tw:
		_duck_tw.kill()
	_duck_tw = create_tween()
	_duck_tw.tween_method(_set_duck, _duck, db, 0.08)
	_duck_tw.tween_interval(hold)
	_duck_tw.tween_method(_set_duck, db, 0.0, release)


func _set_duck(v: float) -> void:
	_duck = v
	var music := AudioServer.get_bus_index("Music")
	AudioServer.set_bus_volume_db(music, MUSIC_DB + _lin_db(float(settings["music_vol"])) + _duck)


# --- Haptics -----------------------------------------------------------------

## "light" (UI taps, gems), "medium" (hits), "heavy" (crits, boss hits,
## taking damage), or a pattern: "rare", "levelup". An int is a legacy
## duration in ms, mapped to the nearest weight.
func haptic(kind) -> void:
	if not bool(settings.get("haptics_on", true)):
		return
	if kind is int:
		kind = "light" if kind < 14 else ("medium" if kind < 28 else "heavy")
	match str(kind):
		"light":
			_buzz(12, 0.35, 45)
		"medium":
			_buzz(20, 0.6, 60)
		"heavy":
			_buzz(34, 1.0, 70)
		"rare":
			_pattern([[30, 1.0], [90, 0], [22, 0.7], [80, 0], [16, 0.45], [70, 0], [40, 1.0]])
		"levelup":
			_pattern([[14, 0.4], [60, 0], [18, 0.65], [60, 0], [30, 1.0]])


func _buzz(ms: int, amp: float, gap_ms: int) -> void:
	var now := Time.get_ticks_msec()
	if now - _haptic_t < gap_ms:
		return
	_haptic_t = now
	Input.vibrate_handheld(ms, amp)


func _pattern(steps: Array) -> void:
	_haptic_t = Time.get_ticks_msec()
	for s in steps:
		if float(s[1]) > 0.0:
			Input.vibrate_handheld(int(s[0]), float(s[1]))
		await get_tree().create_timer(float(s[0]) / 1000.0, true, false, true).timeout
