extends Area2D

var triggered = false
@onready var dialog = get_node("/root/world/level_layers/IntroDialog/RichTextLabel")

func _on_body_entered(body):
	if body.name == "player" and not triggered:
		triggered = true
		dialog.visible = true
		await get_tree().create_timer(20.0).timeout
		dialog.visible = false
