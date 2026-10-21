extends SceneTree
## Writes res://default_bus_layout.tres: Master, Music (with a low-pass filter
## that is off until the game ducks the music under menus) and SFX.
## godot --headless --path . -s res://tools/build_buses.gd

func _init() -> void:
	AudioServer.add_bus(1)
	AudioServer.set_bus_name(1, "Music")
	AudioServer.set_bus_send(1, "Master")
	var lp := AudioEffectLowPassFilter.new()
	lp.cutoff_hz = 900.0
	AudioServer.add_bus_effect(1, lp, 0)
	AudioServer.set_bus_effect_enabled(1, 0, false)
	AudioServer.add_bus(2)
	AudioServer.set_bus_name(2, "SFX")
	AudioServer.set_bus_send(2, "Master")
	var err := ResourceSaver.save(AudioServer.generate_bus_layout(), "res://default_bus_layout.tres")
	print("buses: ", error_string(err))
	quit(0 if err == OK else 1)
