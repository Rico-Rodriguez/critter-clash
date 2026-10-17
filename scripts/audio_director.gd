extends Node

var _pool: Array = []
var _music: AudioStreamPlayer
var _next := 0
var _last := {}


func _ready() -> void:
	for i in 8:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_pool.append(p)
	_music = AudioStreamPlayer.new()
	_music.volume_db = -10.0
	add_child(_music)
	var music := load("res://assets/audio/music.ogg")
	if music:
		music = music.duplicate()
		if music is AudioStreamOggVorbis:
			music.loop = true
		_music.stream = music
		_music.play()


func play_music() -> void:
	if _music and not _music.playing:
		_music.play()


func play(name: String, db: float = -2.0) -> void:
	var stream := load("res://assets/audio/%s.wav" % name)
	if stream == null:
		return
	var p: AudioStreamPlayer = _pool[_next % _pool.size()]
	_next += 1
	p.stream = stream
	p.volume_db = db
	p.play()


func play_throttled(name: String, gap: float = 0.05) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if _last.has(name) and now - float(_last[name]) < gap:
		return
	_last[name] = now
	play(name, -6.0)


func haptic(ms: int) -> void:
	Input.vibrate_handheld(ms)
