# World.gd
extends Node

func _ready():
	# Set ThemePlayer to continue playing even when the game is paused
	$ThemePlayer.process_mode = Node.PROCESS_MODE_ALWAYS
	$ThemePlayer.play()

func _input(event):
	if event.is_action_pressed("pause_menu_button"):
		$CanvasLayer/PausedMenu.visible = true
		get_tree().paused = true
