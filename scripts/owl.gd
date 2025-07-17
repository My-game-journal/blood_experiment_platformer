extends CharacterBody2D

@export var speed: float = 100.0
var direction := Vector2.ZERO
var random_timer: Timer

func _ready():
	randomize()
	var rand_value = randf_range(-1.0, 1.0)
	if rand_value > 0.0:
		direction.x = 1
	else:
		direction.x = -1

	random_timer = Timer.new()
	random_timer.wait_time = 2.0
	random_timer.one_shot = false
	random_timer.connect("timeout", _on_random_timer_timeout)
	add_child(random_timer)
	random_timer.start()

func _physics_process(_delta):
	velocity.x = direction.x * speed
	move_and_slide()

	$AnimatedSprite2D.flip_h = direction.x > 0

	# Detect collision with wall and react
	if is_on_wall():
		var rand_value = randf_range(-1.0, 1.0)
		if rand_value > 0.0:
			direction.x = 1
		else:
			direction.x = -1
		$AnimatedSprite2D.play("fly")

func _on_random_timer_timeout():
	var rand_value = randf_range(-1.0, 1.0)
	if rand_value > 0.0:
		direction.x = 1
	else:
		direction.x = -1
