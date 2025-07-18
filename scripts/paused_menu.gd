extends Control

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(true)

	for child in get_children():
		child.process_mode = Node.PROCESS_MODE_ALWAYS

func _on_wróć_do_gry_pressed() -> void:
	$/root/world/CanvasLayer/PausedMenu.visible = false
	get_tree().paused = false

func _on_zapisz_pressed() -> void:
	var player = $/root/world/level_layers/player

	var save_data = {
		"position": {
			"x": player.position.x,
			"y": player.position.y
		}
	}

	var json_string = JSON.stringify(save_data, "\t")

	var file = FileAccess.open("user://player_position.json", FileAccess.WRITE)
	if file:
		file.store_string(json_string)
		file.close()

func _on_wczytaj_pressed() -> void:
	var file = FileAccess.open("user://player_position.json", FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		file.close()

		var json = JSON.new()
		if json.parse(json_string) == OK:
			var save_data = json.get_data()
			var saved_position = save_data.get("position", null)
			if saved_position:
				var player = $/root/world/level_layers/player
				player.position = Vector2(
					saved_position.get("x", player.position.x),
					saved_position.get("y", player.position.y)
				)

func _on_zakończ_pressed() -> void:
	get_tree().quit()
