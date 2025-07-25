# World.gd
extends Node

func _ready():
	$ThemePlayer.process_mode = Node.PROCESS_MODE_ALWAYS
	$ThemePlayer.play()

func _input(event):
	# Keyboard pause for testing on laptop
	if event.is_action_pressed("pause_menu_button"):
		$CanvasLayer/PausedMenu.visible = true
		get_tree().paused = true
