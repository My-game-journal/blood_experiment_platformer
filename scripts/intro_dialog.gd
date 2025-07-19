extends RichTextLabel

@onready var label = $/root/world/level_layers/IntroDialog/RichTextLabel

func _ready():
	label.visible = true  # Upewniamy się, że label się pokaże
	await get_tree().create_timer(20.0).timeout
	label.visible = false  # Ukrycie po 5 sekundach
	
