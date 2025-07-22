extends Node

class_name GlobalSaveLoad

const SAVE_PATH = "user://saved_game.txt"  # Use user:// for writable path!

func save_game_data(position: Vector2, health: int) -> void:
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		var line = "%f,%f,%d" % [position.x, position.y, health]
		file.store_line(line)
		file.close()
		print("Save successful: Position(", position.x, ", ", position.y, "), Health: ", health)
	else:
		print("Error: Could not open file for writing at ", SAVE_PATH)

func load_game_data() -> Dictionary:
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file:
		if file.get_length() > 0:
			var line = file.get_line()
			var parts = line.split(",")
			if parts.size() == 3:
				var result = {
					"position": Vector2(parts[0].to_float(), parts[1].to_float()),
					"health": parts[2].to_int()
				}
				file.close()
				print("Load successful: Position(", result["position"].x, ", ", result["position"].y, "), Health: ", result["health"])
				return result
			else:
				print("Error: Invalid save file format")
		else:
			print("Error: Save file is empty")
		file.close()
	else:
		print("Error: Could not open save file at ", SAVE_PATH)
	return {}  # Empty if fails
