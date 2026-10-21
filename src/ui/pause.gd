extends Control
## Pause menu over the hunt.

signal resumed
signal abandoned

var _confirm := false


func open(h: Hunt) -> void:
	%Info.text = "%s · %s · %s" % [DB.HEROES[h.hero_id]["name"], h.tier["name"], Ui.fmt_time(h.time)]
	%Resume.pressed.connect(func():
		Sfx.play("ui_back", -4.0)
		resumed.emit())
	%Abandon.pressed.connect(func():
		if not _confirm:
			_confirm = true
			%Abandon.text = "Tap again to leave"
			Sfx.play("ui_error", -6.0)
			return
		abandoned.emit())
	%Settings.add_child(SettingsBox.new())
	Ui.pop_in(%Panel, 0.0, 0.92)
