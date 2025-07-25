extends CharacterBody2D

const SPEED = 150.0
const JUMP_VELOCITY = -250.0
const GRAVITY = 900.0
const ROLL_SPEED = 175.0
const COMBO_TIMEOUT = 0.8  # Czas na kolejny atak w combo

enum PlayerState { IDLE, RUNNING, JUMPING, ATTACKING, ROLLING, SHIELDING }
var state = PlayerState.IDLE

var direction := 0.0
var last_direction := 1.0

var health := 100
var health_decrease_rate := 5
var health_decrease_interval := 5.0
var time_accumulator := 0.0

# Camera smoothing variables
var camera_target_position := Vector2.ZERO
var camera_smooth_speed := 0.5

# Combo system variables - Simplified approach
var combo_sequence = ["attack_0", "attack_1", "attack_2"]
var current_combo_index := 0
var can_combo := false  # Whether we can continue the combo
var combo_timer: Timer

# Attack safety variables
var attack_stuck_timer: Timer
var attack_stuck_timeout := 2.0  # Maximum time to stay in attack state

# Coyote time for better jumping (allows jumping shortly after leaving ground)
var coyote_time := 0.15  # 150ms coyote time
var coyote_timer := 0.0
var was_on_floor := false

# Dynamic gameplay variables
var momentum_multiplier := 1.0
var combo_momentum := 0.0
var air_dash_available := false
var last_ground_time := 0.0
var dynamic_camera_shake := 0.0
var movement_streak := 0
var last_action_time := 0.0

func _ready():
	$AnimatedSprite2D.frame_changed.connect(_on_AnimatedSprite2D_frame_changed)
	$HitBoxAttack0.connect("body_entered", Callable(self, "_on_hitbox_body_entered"))
	$HitBoxAttack1.connect("body_entered", Callable(self, "_on_hitbox_body_entered"))
	$HitBoxAttack2.connect("body_entered", Callable(self, "_on_hitbox_body_entered"))

	var health_bar = get_node_or_null("CanvasLayer/HealthBar")
	if health_bar:
		health_bar.value = health
	
	# Initialize camera target position
	camera_target_position = global_position
	# Disable built-in smoothing to use our custom implementation
	$Camera2D.position_smoothing_enabled = false
	
	# Setup combo timer
	combo_timer = Timer.new()
	combo_timer.wait_time = COMBO_TIMEOUT
	combo_timer.one_shot = true
	combo_timer.connect("timeout", Callable(self, "_on_combo_timeout"))
	add_child(combo_timer)
	
	# Setup attack safety timer
	attack_stuck_timer = Timer.new()
	attack_stuck_timer.wait_time = attack_stuck_timeout
	attack_stuck_timer.one_shot = true
	attack_stuck_timer.connect("timeout", Callable(self, "_on_attack_stuck_timeout"))
	add_child(attack_stuck_timer)
	
	# Initialize dynamic gameplay
	setup_dynamic_features()

func _on_combo_timeout():
	# Reset combo po upływie czasu
	current_combo_index = 0
	can_combo = false

func _on_attack_stuck_timeout():
	# Safety mechanism: force exit from attack state if stuck too long
	if state == PlayerState.ATTACKING:
		state = PlayerState.IDLE
		can_combo = false
		current_combo_index = 0
		velocity.x = 0  # Clear any residual velocity

func _physics_process(delta: float) -> void:
	handle_gravity(delta)
	update_coyote_time(delta)
	update_dynamic_features(delta)
	handle_inputs()
	handle_movement()
	update_animation()
	move_and_slide()
	
	# Snap player position to pixel boundaries
	global_position = Vector2(round(global_position.x), round(global_position.y))
	
	# Custom smooth camera with pixel-perfect positioning and dynamic shake
	update_smooth_camera(delta)

	time_accumulator += delta
	if time_accumulator >= health_decrease_interval:
		health = max(health - health_decrease_rate, 0)
		var health_bar = get_node_or_null("CanvasLayer/HealthBar")
		if health_bar:
			health_bar.value = health
			if health_bar.value <= 0:
				get_tree().reload_current_scene()
		time_accumulator = 0.0

func update_coyote_time(delta: float) -> void:
	# Update coyote time for better jumping feel
	if is_on_floor():
		coyote_timer = coyote_time
		was_on_floor = true
	else:
		if was_on_floor:
			coyote_timer -= delta
		if coyote_timer <= 0:
			was_on_floor = false

func can_coyote_jump() -> bool:
	return coyote_timer > 0 or is_on_floor()

func handle_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		velocity.y = 0

func update_smooth_camera(delta: float) -> void:
	# Dynamic look-ahead based on player state and movement
	var look_ahead_distance = 30.0
	var vertical_offset = 0.0
	var vertical_smoothing_factor = 1.0
	
	# Adjust camera behavior based on player state
	match state:
		PlayerState.RUNNING:
			look_ahead_distance = 60.0
			vertical_smoothing_factor = 0.8  # Slightly less Y smoothing when running
		PlayerState.JUMPING:
			vertical_offset = -25.0  # Look up more when jumping
			look_ahead_distance = 40.0
			vertical_smoothing_factor = 1.5  # More responsive Y movement when jumping
		PlayerState.ROLLING:
			look_ahead_distance = 80.0
			vertical_smoothing_factor = 0.6  # Less Y movement when rolling
		_:
			look_ahead_distance = 30.0
			vertical_smoothing_factor = 1.0
	
	# Calculate target position with both X and Y smoothing
	var target_x = global_position.x
	var target_y = global_position.y + vertical_offset
	
	# Only apply look-ahead when moving horizontally
	if abs(velocity.x) > 10.0:
		target_x += last_direction * look_ahead_distance
	
	# Add subtle Y-axis look-ahead based on vertical velocity
	if abs(velocity.y) > 50.0:  # When falling or jumping fast
		target_y += velocity.y * 0.1  # Small look-ahead in Y direction
	
	camera_target_position = Vector2(target_x, target_y)
	
	# Adaptive smoothing speed based on movement
	var adaptive_speed_x = camera_smooth_speed
	var adaptive_speed_y = camera_smooth_speed * vertical_smoothing_factor
	
	if state == PlayerState.ROLLING:
		adaptive_speed_x = camera_smooth_speed * 1.5  # Faster X for rolls
	elif abs(velocity.x) < 10.0:
		adaptive_speed_x = camera_smooth_speed * 0.7  # Slower X when idle
	
	# Separate interpolation for X and Y axes
	var camera = $Camera2D
	var current_pos = camera.global_position
	
	var new_x = lerp(current_pos.x, camera_target_position.x, adaptive_speed_x * delta)
	var new_y = lerp(current_pos.y, camera_target_position.y, adaptive_speed_y * delta)
	
	# Apply dynamic camera shake
	if dynamic_camera_shake > 0:
		var shake_x = randf_range(-dynamic_camera_shake, dynamic_camera_shake)
		var shake_y = randf_range(-dynamic_camera_shake, dynamic_camera_shake)
		new_x += shake_x
		new_y += shake_y
	
	# Snap camera to pixel boundaries to maintain crispness
	camera.global_position = Vector2(round(new_x), round(new_y))

func setup_dynamic_features():
	# Initialize dynamic gameplay features
	momentum_multiplier = 1.0
	combo_momentum = 0.0
	air_dash_available = false
	movement_streak = 0
	dynamic_camera_shake = 0.0

# Dynamic gameplay functions
func update_movement_streak():
	var current_time = Time.get_time_dict_from_system()["second"]
	if current_time - last_action_time < 2.0:  # Within 2 seconds
		movement_streak += 1
	else:
		movement_streak = 1
	last_action_time = current_time
	
	# Apply momentum bonus based on streak
	momentum_multiplier = min(1.0 + (movement_streak * 0.1), 1.5)

func update_dynamic_features(delta: float):
	# Update combo momentum decay
	if combo_momentum > 0:
		combo_momentum = max(combo_momentum - delta * 2.0, 0.0)
	
	# Update air dash availability
	if is_on_floor():
		air_dash_available = true
		last_ground_time = 0.0
	else:
		last_ground_time += delta
	
	# Update camera shake decay
	if dynamic_camera_shake > 0:
		dynamic_camera_shake = max(dynamic_camera_shake - delta * 8.0, 0.0)
	
	# Reset movement streak if idle too long
	if Time.get_time_dict_from_system()["second"] - last_action_time > 3.0:
		movement_streak = 0
		momentum_multiplier = 1.0

func apply_camera_shake(intensity: float):
	dynamic_camera_shake = intensity

func handle_inputs():
	var can_act = state not in [PlayerState.ATTACKING, PlayerState.JUMPING] and is_on_floor()
	var can_jump = state not in [PlayerState.ATTACKING, PlayerState.SHIELDING]
	var can_roll = state not in [PlayerState.ATTACKING, PlayerState.SHIELDING]  # Remove JUMPING restriction
	
	# Additional check: prevent actions if jump animation is still playing
	var is_jump_animation_playing = $AnimatedSprite2D.animation == "jump" and $AnimatedSprite2D.is_playing()
	if is_jump_animation_playing:
		can_act = false

	# Handle jump input (keyboard only)
	var jump_input = Input.is_action_just_pressed("jump_button")
	# Allow jumping with coyote time for better feel
	if jump_input and can_coyote_jump() and can_jump:
		# Dynamic jump with momentum boost
		var jump_boost = 1.0 + (momentum_multiplier - 1.0) * 0.5
		velocity.y = JUMP_VELOCITY * jump_boost
		coyote_timer = 0  # Consume coyote time
		# Don't change state to JUMPING if already rolling - maintain rolling state
		if state != PlayerState.ROLLING:
			state = PlayerState.JUMPING
		# Add small camera shake for dynamic feel
		apply_camera_shake(0.5)

	# Handle roll input (keyboard only)
	var roll_input = Input.is_action_just_pressed("roll_button")
	# Allow rolling in air and on ground (except when attacking or shielding)
	if roll_input and can_roll:
		if not is_on_floor() and air_dash_available:
			# Air dash mechanic
			start_air_dash()
			air_dash_available = false
		else:
			start_roll()

	# Handle attack input (keyboard only)
	var attack_input = Input.is_action_just_pressed("attack_button")
	if attack_input:
		if can_act:
			# Start new attack if we can act
			start_next_attack()
			combo_momentum += 0.3  # Build combo momentum
		elif state == PlayerState.ATTACKING and can_combo:
			# Start next combo attack immediately if combo window is open
			start_next_attack()
			combo_momentum += 0.5  # More momentum for combo chains

	# Handle shield input (keyboard only)
	var shield_input = Input.is_action_pressed("shield_button")
	if shield_input and can_act and is_on_floor():
		state = PlayerState.SHIELDING
		$ShieldBox.monitoring = true
		$ShieldBox.get_node("CollisionShape2D").disabled = false
		$ShieldBox.scale.x = -1 if last_direction < 0 else 1
	else:
		if state == PlayerState.SHIELDING:
			$ShieldBox.monitoring = false
			$ShieldBox.get_node("CollisionShape2D").disabled = true
			state = PlayerState.IDLE

# IMPROVED: Better attack handling with consistent direction
func start_next_attack():
	# Restart combo timer
	combo_timer.start()
	
	# Start attack safety timer
	attack_stuck_timer.start()
	
	# Disable combo window initially
	can_combo = false
	
	# Set attack direction based on current input or maintain last direction
	var keyboard_direction = Input.get_axis("move_left_button", "move_right_button")
	var current_input_direction = keyboard_direction
	current_input_direction = clamp(current_input_direction, -1.0, 1.0)
	
	# Update attack direction: use input direction if available, otherwise keep last direction
	if current_input_direction != 0:
		last_direction = current_input_direction
	
	# Set the flip direction for this attack
	$AnimatedSprite2D.flip_h = last_direction < 0
	
	# Pobierz nazwę animacji dla obecnego indeksu combo
	var anim_name = combo_sequence[current_combo_index]
	
	# Wybierz odpowiedni hitbox
	var hitbox
	match anim_name:
		"attack_0":
			hitbox = $HitBoxAttack0
		"attack_1":
			hitbox = $HitBoxAttack1
		"attack_2":
			hitbox = $HitBoxAttack2
		_:
			hitbox = $HitBoxAttack0
	
	# Uruchom atak
	state = PlayerState.ATTACKING
	$AnimatedSprite2D.play(anim_name)
	update_hitbox_flip(hitbox)
	hitbox.monitoring = false
	for child in hitbox.get_children():
		if child is CollisionShape2D or child is CollisionPolygon2D:
			child.disabled = true
	
	# Add camera shake based on attack type and combo momentum
	var shake_intensity = 0.5 + (combo_momentum * 0.5)
	match anim_name:
		"attack_0":
			apply_camera_shake(shake_intensity)
		"attack_1":
			apply_camera_shake(shake_intensity * 1.2)
		"attack_2":
			apply_camera_shake(shake_intensity * 1.5)  # Strongest shake for final combo
	
	# Przygotuj następny krok combo
	current_combo_index = (current_combo_index + 1) % combo_sequence.size()

# IMPROVED: Enhanced movement with better attack handling and dynamic features
func handle_movement():
	# Get direction from keyboard only
	var keyboard_direction = Input.get_axis("move_left_button", "move_right_button")
	direction = keyboard_direction
	
	# Clamp to prevent issues
	direction = clamp(direction, -1.0, 1.0)
	
	# Update last_direction for flipping - allow during attacks for better responsiveness
	if direction != 0:
		last_direction = direction

	# Apply movement based on state - allow directional control in most states with dynamic features
	match state:
		PlayerState.ROLLING:
			# Allow directional control during roll + boost speed with momentum
			var roll_speed = ROLL_SPEED * momentum_multiplier
			if direction != 0:
				velocity.x = direction * roll_speed
			else:
				velocity.x = last_direction * roll_speed * 0.7  # Maintain some momentum if no input
		PlayerState.ATTACKING:
			# Reduced movement during attacks - not completely locked, with combo momentum
			var attack_mobility = 0.8 + (combo_momentum * 0.2)
			velocity.x = velocity.x * attack_mobility  # Gradual deceleration with combo bonus
			
			# Update hitbox flipping if direction changed during attack
			if direction != 0:
				var current_hitbox
				var anim_name = combo_sequence[(current_combo_index - 1 + combo_sequence.size()) % combo_sequence.size()]
				match anim_name:
					"attack_0":
						current_hitbox = $HitBoxAttack0
					"attack_1":
						current_hitbox = $HitBoxAttack1
					"attack_2":
						current_hitbox = $HitBoxAttack2
					_:
						current_hitbox = $HitBoxAttack0
				
				if current_hitbox:
					current_hitbox.scale.x = -1 if last_direction < 0 else 1
		PlayerState.SHIELDING:
			# No movement during shielding
			velocity.x = 0
		_:
			# Normal movement for IDLE, RUNNING, JUMPING with momentum multiplier
			var move_speed = SPEED * momentum_multiplier
			velocity.x = direction * move_speed

func update_animation():
	# Allow flipping at any time, including during attacks
	$AnimatedSprite2D.flip_h = last_direction < 0

	if not is_on_floor():
		# In air animations - prioritize jumping if in jumping state
		if state == PlayerState.JUMPING:
			$AnimatedSprite2D.play("jump")
		elif state == PlayerState.ROLLING:
			$AnimatedSprite2D.play("roll")  # Allow roll animation in air
		else:
			$AnimatedSprite2D.play("jump")  # Default air animation
	else:
		# Player just landed - handle state transitions carefully
		if state == PlayerState.JUMPING:
			# Only transition from jumping when the jump animation is near completion or finished
			var current_anim = $AnimatedSprite2D.animation
			if current_anim == "jump":
				# Let jump animation finish before transitioning
				if not $AnimatedSprite2D.is_playing() or is_last_frame("jump"):
					# Jump animation finished, now transition to appropriate state
					if direction != 0:
						state = PlayerState.RUNNING
					else:
						state = PlayerState.IDLE
			else:
				# If not playing jump animation, transition immediately
				if direction != 0:
					state = PlayerState.RUNNING
				else:
					state = PlayerState.IDLE
		
		match state:
			PlayerState.SHIELDING:
				$AnimatedSprite2D.play("shield")
			PlayerState.ROLLING:
				$AnimatedSprite2D.play("roll")
			PlayerState.ATTACKING:
				pass  # Attack animation is already being handled - don't change flip here
			_:
				# For IDLE, RUNNING, JUMPING (when on ground)
				if direction != 0:
					$AnimatedSprite2D.play("run")
					# If we were jumping and now moving on ground, switch to running
					if state == PlayerState.JUMPING:
						state = PlayerState.RUNNING
				else:
					$AnimatedSprite2D.play("idle")
					# If we were moving and now stopped, switch to idle
					if state in [PlayerState.RUNNING, PlayerState.JUMPING]:
						state = PlayerState.IDLE

func start_roll():
	# Allow rolling from any state except attacking and shielding
	if state in [PlayerState.ATTACKING, PlayerState.SHIELDING]:
		return
	
	state = PlayerState.ROLLING
	$AnimatedSprite2D.flip_h = last_direction < 0
	$AnimatedSprite2D.play("roll")
	
	# Add horizontal boost for air rolls
	if not is_on_floor():
		# Air roll gives extra horizontal momentum
		velocity.x = last_direction * ROLL_SPEED * 1.2
	# Ground roll is handled in handle_movement()
	
	# Add camera shake for impact
	apply_camera_shake(1.0)

func start_air_dash():
	# Special air dash with directional control
	state = PlayerState.ROLLING
	$AnimatedSprite2D.flip_h = last_direction < 0
	$AnimatedSprite2D.play("roll")
	
	# Air dash gives strong horizontal momentum and slight upward boost
	velocity.x = last_direction * ROLL_SPEED * 1.5
	velocity.y = min(velocity.y, -50)  # Small upward boost, but don't override downward momentum too much
	
	# Strong camera shake for air dash
	apply_camera_shake(1.5)

func update_hitbox_flip(hitbox: Node2D):
	# Update both sprite and hitbox flipping based on current direction
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
			# Enable combo window in the middle/end of the attack
			can_combo = frame >= 3
			if is_last_frame(anim):
				handle_combo_finish()

		"attack_1":
			handle_hitbox_frames($HitBoxAttack1, frame in [2, 5])
			# Enable combo window in the middle/end of the attack
			can_combo = frame >= 4
			if is_last_frame(anim):
				handle_combo_finish()

		"attack_2":
			handle_hitbox_frames($HitBoxAttack2, frame in range(2, 6))
			# Enable combo window in the middle/end of the attack
			can_combo = frame >= 4
			if is_last_frame(anim):
				handle_combo_finish()

		"roll":
			if is_last_frame(anim):
				# Smart state transition after roll
				if not is_on_floor():
					state = PlayerState.JUMPING  # If in air, transition to jumping
				elif direction != 0:
					state = PlayerState.RUNNING  # If moving, transition to running
				else:
					state = PlayerState.IDLE      # If idle, transition to idle
		
		"jump":
			if is_last_frame(anim) and is_on_floor():
				# Jump animation finished and player is on ground - transition to appropriate state
				if direction != 0:
					state = PlayerState.RUNNING
				else:
					state = PlayerState.IDLE

# IMPROVED: Better combo finish with stuck prevention
func handle_combo_finish():
	# Stop attack safety timer
	attack_stuck_timer.stop()
	
	# Always ensure we exit attack state
	if state == PlayerState.ATTACKING:
		state = PlayerState.IDLE
	
	can_combo = false
	
	# Add safety check: if velocity is very small, make sure we can move again
	if abs(velocity.x) < 1.0:
		velocity.x = 0
	
	# Timer będzie odpowiedzialny za reset combo index

func _on_hitbox_body_entered(body):
	if body.is_in_group("enemies"):
		body.vanish()
		
		# Dynamic feedback for hitting enemies
		combo_momentum += 0.4  # Reward successful hits
		apply_camera_shake(1.2)  # Satisfying impact shake
		
		# Increase movement streak for combat actions
		movement_streak += 2
		momentum_multiplier = min(momentum_multiplier + 0.1, 2.0)
		
		# Time freeze effect for impact
		Engine.time_scale = 0.7
		await get_tree().create_timer(0.05).timeout
		Engine.time_scale = 1.0
