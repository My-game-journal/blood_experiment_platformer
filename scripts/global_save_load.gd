extends Node

class_name GlobalSaveLoad

const SAVE_PATH = "user://saved_game.txt"  # Use user:// for writable path!

func save_game_data(position: Vector2, health: int) -> void:
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		var line = "%f,%f,%d" % [position.x, position.y, health]
		file.store_line(line)
		file.close()

func load_game_data() -> Dictionary:
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file:
		if file.get_length() > 0:
			var line = file.get_line()
			var parts = line.split(",")
			if parts.size() == 3:
				return {
					"position": Vector2(parts[0].to_float(), parts[1].to_float()),
					"health": parts[2].to_int()
				}
		file.close()
	return {}  # Empty if fails
