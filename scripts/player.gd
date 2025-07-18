extends CharacterBody2D

const SPEED = 150.0
const JUMP_VELOCITY = -250.0
const GRAVITY = 900.0
const ROLL_SPEED = 175.0

enum PlayerState { IDLE, RUNNING, JUMPING, ATTACKING, ROLLING, SHIELDING }
var state = PlayerState.IDLE

var direction := 0.0
var last_direction := 1.0

var health := 100
var health_decrease_rate := 5
var health_decrease_interval := 5.0
var time_accumulator := 0.0

func _ready():
	$AnimatedSprite2D.frame_changed.connect(_on_AnimatedSprite2D_frame_changed)
	$HitBoxAttack0.connect("body_entered", Callable(self, "_on_hitbox_body_entered"))
	$HitBoxAttack1.connect("body_entered", Callable(self, "_on_hitbox_body_entered"))
	$HitBoxAttack2.connect("body_entered", Callable(self, "_on_hitbox_body_entered"))

	var health_bar = get_node_or_null("HealthBar")
	if health_bar:
		health_bar.value = health
	else:
		print("HealthBar node not found!")

func _physics_process(delta: float) -> void:
	handle_gravity(delta)
	handle_inputs()
	handle_movement()
	update_animation()
	move_and_slide()

	time_accumulator += delta
	if time_accumulator >= health_decrease_interval:
		health = max(health - health_decrease_rate, 0)
		var health_bar = get_node_or_null("HealthBar")
		if health_bar:
			health_bar.value = health
		time_accumulator = 0.0

func handle_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		velocity.y = 0

func handle_inputs():
	var can_act = state not in [PlayerState.ATTACKING, PlayerState.ROLLING]

	if Input.is_action_just_pressed("jump_button") and is_on_floor() and can_act:
		velocity.y = JUMP_VELOCITY
		state = PlayerState.JUMPING

	elif Input.is_action_just_pressed("roll_button") and is_on_floor() and can_act:
		start_roll()

	elif Input.is_action_just_pressed("attack_button_0") and can_act:
		start_attack("attack_0", $HitBoxAttack0)

	elif Input.is_action_just_pressed("attack_button_1") and can_act:
		start_attack("attack_1", $HitBoxAttack1)

	elif Input.is_action_just_pressed("attack_button_2") and can_act:
		start_attack("attack_2", $HitBoxAttack2)

	elif Input.is_action_pressed("shield_button") and can_act:
		state = PlayerState.SHIELDING
		$ShieldBox.monitoring = true
		$ShieldBox.get_node("CollisionShape2D").disabled = false
		$ShieldBox.scale.x = -1 if last_direction < 0 else 1
	else:
		if state == PlayerState.SHIELDING:
			$ShieldBox.monitoring = false
			$ShieldBox.get_node("CollisionShape2D").disabled = true
			state = PlayerState.IDLE

func handle_movement():
	direction = Input.get_axis("move_left_button", "move_right_button")
	if direction != 0:
		last_direction = direction

	if state == PlayerState.ROLLING:
		velocity.x = last_direction * ROLL_SPEED
	elif state not in [PlayerState.ATTACKING, PlayerState.SHIELDING]:
		velocity.x = direction * SPEED
	else:
		velocity.x = 0

func update_animation():
	$AnimatedSprite2D.flip_h = last_direction < 0

	if not is_on_floor():
		if state == PlayerState.JUMPING:
			$AnimatedSprite2D.play("jump")
	else:
		match state:
			PlayerState.SHIELDING:
				$AnimatedSprite2D.play("shield")
			PlayerState.ROLLING:
				$AnimatedSprite2D.play("roll")
			PlayerState.ATTACKING:
				pass  # Attack animation is already being handled
			_:
				if direction != 0:
					$AnimatedSprite2D.play("run")
				else:
					$AnimatedSprite2D.play("idle")

func start_roll():
	if state == PlayerState.ROLLING:
		return
	state = PlayerState.ROLLING
	$AnimatedSprite2D.flip_h = last_direction < 0
	$AnimatedSprite2D.play("roll")

func start_attack(anim_name: String, hitbox: Node2D):
	state = PlayerState.ATTACKING
	$AnimatedSprite2D.play(anim_name)
	update_hitbox_flip(hitbox)
	hitbox.monitoring = false
	for child in hitbox.get_children():
		if child is CollisionShape2D or child is CollisionPolygon2D:
			child.disabled = true

func update_hitbox_flip(hitbox: Node2D):
	$AnimatedSprite2D.flip_h = last_direction < 0
	hitbox.scale.x = -1 if last_direction < 0 else 1

func handle_hitbox_frames(hitbox: Node2D, active: bool):
	hitbox.monitoring = active
	for child in hitbox.get_children():
		if child is CollisionShape2D or child is CollisionPolygon2D:
			child.disabled = not active

func is_last_frame(anim_name: String) -> bool:
	return $AnimatedSprite2D.frame == $AnimatedSprite2D.sprite_frames.get_frame_count(anim_name) - 1

func _on_AnimatedSprite2D_frame_changed():
	var anim = $AnimatedSprite2D.animation
	var frame = $AnimatedSprite2D.frame

	match anim:
		"attack_0":
			handle_hitbox_frames($HitBoxAttack0, frame == 5)
			if is_last_frame(anim):
				state = PlayerState.IDLE

		"attack_1":
			handle_hitbox_frames($HitBoxAttack1, frame in [2, 5])
			if is_last_frame(anim):
				state = PlayerState.IDLE

		"attack_2":
			handle_hitbox_frames($HitBoxAttack2, frame in range(2, 6))
			if is_last_frame(anim):
				state = PlayerState.IDLE

		"roll":
			if is_last_frame(anim):
				state = PlayerState.IDLE

func _on_hitbox_body_entered(body):
	if body.is_in_group("enemies"):
		body.vanish()
