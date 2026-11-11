extends CharacterBody2D

@export_group("Movement")
@export var max_speed: float = 240.0
@export var acceleration: float = 1800.0
@export_range(0.0, 1.0) var ground_friction: float = 0.45
@export var ground_braking: float = 3000.0
@export var stop_threshold: float = 5.0

@export_group("Jump")
@export var coyote_time: float = 0.125 # seconds
@export var jump_buffer_time: float = 0.125 # seconds
@export var gravity: float = 1800.0
@export var fall_gravity: float = 2000.0
@export var jump_strength: float = 800.0
@export var jump_cut_multiplier: float = 0.45

@export_group("Wall Jump")
@export var wall_slide_speed: float = 150.0 # maximum downward speed while sliding
@export var wall_jump_upward_speed: float = 800.0
@export var wall_jump_sideways_speed: float = 250.0
@export var wall_jump_control_lock_time: float = 0.02 # seconds
@export var wall_grace_time: float = 0.1 # seconds
@export_range(0.0, 1.0) var minimum_wall_normal_x: float = 0.7

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var last_grounded_time := -INF
var last_jump_pressed_time := -INF
var last_wall_time := -INF
var wall_jump_control_locked_until := -INF

var last_direction := 1 # -1 = left, 1 = right
var last_wall_normal := Vector2.ZERO


func _physics_process(delta: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var on_floor := is_on_floor()

	if on_floor:
		last_grounded_time = now

	if Input.is_action_just_pressed("Up"):
		last_jump_pressed_time = now

	# Apply gravity and limit falling speed while sliding down a wall.
	if not on_floor:
		var current_gravity := fall_gravity if velocity.y > 0.0 else gravity
		velocity.y += current_gravity * delta

		if _can_use_saved_wall() and velocity.y > wall_slide_speed:
			velocity.y = wall_slide_speed

	var direction := Input.get_axis("Left", "Right")
	var wall_jump_control_locked := now < wall_jump_control_locked_until

	# Keep normal horizontal control briefly disabled after a wall kick,
	# so it isn't immediately canceled by input toward the wall.
	if not wall_jump_control_locked:
		if direction != 0.0:
			var reversing_on_ground := (
				on_floor
				and velocity.x != 0.0
				and signf(velocity.x) != signf(direction)
			)

			if reversing_on_ground:
				velocity.x = move_toward(
					velocity.x,
					0.0,
					ground_braking * delta
				)
			else:
				velocity.x = move_toward(
					velocity.x,
					direction * max_speed,
					acceleration * delta
				)

			last_direction = signi(direction)

			if on_floor:
				_play_animation("walk")
		elif on_floor:
			velocity.x *= ground_friction
			if absf(velocity.x) < stop_threshold:
				velocity.x = 0.0
				_play_animation("idle")

	animated_sprite.flip_h = last_direction > 0

	var jump_is_buffered := now - last_jump_pressed_time <= jump_buffer_time
	var can_coyote_jump := now - last_grounded_time <= coyote_time

	if jump_is_buffered and can_coyote_jump:
		velocity.y = -jump_strength
		last_grounded_time = -INF
		last_jump_pressed_time = -INF
		_play_animation("jump")
	elif jump_is_buffered and _can_use_saved_wall():
		# The wall normal points away from the wall, so its X value
		# gives the direction to kick.
		velocity.y = -wall_jump_upward_speed
		velocity.x = last_wall_normal.x * wall_jump_sideways_speed

		last_jump_pressed_time = -INF
		last_grounded_time = -INF
		wall_jump_control_locked_until = now + wall_jump_control_lock_time
		_play_animation("jump")

	if Input.is_action_just_released("Up") and velocity.y < 0.0:
		velocity.y *= jump_cut_multiplier

	move_and_slide()

	# Save wall contact and its normal for use during the next physics frame.
	if is_on_wall():
		var wall_normal := get_wall_normal()
		if absf(wall_normal.x) >= minimum_wall_normal_x:
			last_wall_normal = wall_normal
			last_wall_time = now
		else:
			last_wall_normal = Vector2.ZERO
	else:
		last_wall_normal = Vector2.ZERO


func _can_use_saved_wall() -> bool:
	return (
		last_wall_normal != Vector2.ZERO
		and Time.get_ticks_msec() / 1000.0 - last_wall_time <= wall_grace_time
	)


func _play_animation(animation_name: StringName) -> void:
	if animated_sprite.animation != animation_name:
		animated_sprite.play(animation_name)
