extends CharacterBody2D

var health := 100
var health_decrease_rate := 5
var health_decrease_interval := 5.0
var time_accumulator := 0.0

func _ready():
	$HealthBar.value = health

func _process(delta):
	time_accumulator += delta
	if time_accumulator >= health_decrease_interval:
		health = max(health - health_decrease_rate, 0)
		$HealthBar.value = health
		time_accumulator = 0.0