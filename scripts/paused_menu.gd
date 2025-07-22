extends Control

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	for child in get_children():
		child.process_mode = Node.PROCESS_MODE_ALWAYS

func _on_wróć_do_gry_pressed() -> void:
	$/root/world/CanvasLayer/PausedMenu.visible = false
	get_tree().paused = false

func _on_zapisz_pressed() -> void:
	var player = get_node_or_null("/root/world/level_layers/player")
	if player:
		# Save the actual player health, not the health bar value
		saveloadglobal.save_game_data(player.position, player.health)
		print("Game saved successfully")

func _on_wczytaj_pressed() -> void:
	var save_data = saveloadglobal.load_game_data()
	if save_data.size() > 0:
		var player = get_node_or_null("/root/world/level_layers/player")
		if player:
			player.position = save_data["position"]
			player.health = save_data["health"]
			# Update health bar to match loaded health
			var health_bar = player.get_node_or_null("CanvasLayer/HealthBar")
			if health_bar:
				health_bar.value = save_data["health"]
			print("Game loaded successfully")
		else:
			print("Player not found")
			return
	else:
		print("No save data found")
		return

func _on_zakończ_pressed() -> void:
	get_tree().quit()
