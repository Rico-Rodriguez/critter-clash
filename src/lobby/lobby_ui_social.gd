extends "res://src/lobby/lobby_ui_sheets.gd"
## The camp screen, part 4: the Clan tab (clan, friends, chat, parties), the
## profile sheet and the hooks the rest of the camp reads (the clan line under
## the player's name, the Clan tab's dot).


func _social_setup() -> void:
	pass


## Under the player's name: the clan, or "No clan".
func _clan_line() -> String:
	return "No clan"


func _social_dot() -> bool:
	return false


func _social_segments() -> Array:
	return [["Clan", _build_clan_soon], ["Friends", _build_clan_soon]]


func _build_clan_soon(s: Sheet) -> void:
	var l := Ui.label("Clans are coming.", "Body")
	s.body.add_child(l)


## Sheets that belong to the social part; false when `name_` is not one.
func _open_social_sheet(_s: Sheet, _name: String) -> bool:
	return false


func _build_profile(s: Sheet) -> void:
	var b := s.body
	b.add_child(Ui.label(Game.player_name(), "Title"))
	var st: Dictionary = Game.data["stats"]
	b.add_child(Ui.label("Hunts %d · wins %d · kills %s" % [int(st["hunts"]), int(st["wins"]), Ui.fmt_num(int(st["kills"]))], "Body"))
