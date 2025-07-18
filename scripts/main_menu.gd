extends Control

@onready var start_button = $"VBoxContainer/Nowa gra" as Button
@onready var exit_button = $VBoxContainer/Zamknij as Button 
@onready var options_button = $VBoxContainer/Ustawienia as Button
@onready var options_menu = $OptionsMenu as OptionsMenu
@onready var v_box_container = $VBoxContainer as VBoxContainer

@onready var start_level = preload("res://scenes/world.tscn") as PackedScene
@onready var music_player = $MusicMenuPlayer

func _ready():
	handle_connectiong_signals()

	# 🔁 Muzyka zapętlona z ręcznie ustawionymi punktami pętli
	var stream = music_player.stream
	if stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = 325500
	music_player.play()

func on_start_pressed() -> void:
	get_tree().change_scene_to_packed(start_level)

func _on_wczytaj_pressed() -> void:
	var file = FileAccess.open("user://player_position.json", FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		file.close()

		var json = JSON.new()
		if json.parse(json_string) == OK:
			var save_data = json.get_data()
			var position_data = save_data.get("position", null)
			if position_data:
				var level = preload("res://scenes/world.tscn").instantiate()
				var player = level.get_node("level_layers/player")
				player.position = Vector2(
					position_data.get("x", player.position.x),
					position_data.get("y", player.position.y)
				)

				call_deferred("_switch_scene", level)

func _switch_scene(new_scene: Node) -> void:
	get_tree().root.add_child(new_scene)
	get_tree().current_scene.queue_free()
	get_tree().current_scene = new_scene

func on_options_pressed() -> void:
	v_box_container.visible = false
	options_menu.set_process(true)
	options_menu.visible = true

func on_exit_pressed() -> void:
	get_tree().quit()

func on_exit_options_menu() -> void:
	v_box_container.visible = true
	options_menu.visible = false

func handle_connectiong_signals() -> void:
	start_button.button_down.connect(on_start_pressed)
	options_button.button_down.connect(on_options_pressed)
	exit_button.button_down.connect(on_exit_pressed)
	options_menu.exit_options_menu.connect(on_exit_options_menu)
