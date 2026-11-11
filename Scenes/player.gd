extends CharacterBody2D

const MAX_SPEED := 240.0
const ACCELERATION := 1000.0 # pixels per second²
const GROUND_FRICTION := 0.45 # friction when no input is applied, higher values equal less friction
const GROUND_BRAKING := 3000.0 # friction when input is applied, pixels per second²
const STOP_THRESHOLD := 5.0
const JUMP_VELOCITY := -700.0
const COYOTE_TIME := 0.125 # seconds

@export var gravity: float = 1800.0
@export var fall_gravity: float = 2200.0
@export var jump_strength: float = 650.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var last_grounded_time := -INF
var last_direction := 1 # -1 = left, 1 = right

#var current_gravity = gravity
#if velocity.y > 0.0:
	#current_gravity = fall_gravity
#velocity.y += current_gravity * delta

func _physics_process(delta: float) -> void:
	if is_on_floor():
		last_grounded_time = Time.get_ticks_msec() / 1000.0
	else:
		velocity += get_gravity() * delta

	var direction := Input.get_axis("Left", "Right")

	if direction != 0.0:
		var reversing_on_ground := (
			is_on_floor()
			and velocity.x != 0.0
			and signf(velocity.x) != signf(direction)
		)

		if reversing_on_ground:
			# Brake the old momentum first. Normal acceleration takes over
			# on the next frame once velocity reaches zero.
			velocity.x = move_toward(velocity.x, 0.0, GROUND_BRAKING * delta)
		else:
			velocity.x = move_toward(
				velocity.x,
				direction * MAX_SPEED,
				ACCELERATION * delta
			)

		last_direction = signi(direction)

		if is_on_floor():
			_play_animation("walk")
	else:
		if is_on_floor():
			velocity.x *= GROUND_FRICTION
			if absf(velocity.x) < STOP_THRESHOLD:
				velocity.x = 0.0
				_play_animation("idle")

	# Preserve facing while walking, idle, and airborne.
	animated_sprite.flip_h = last_direction > 0

	var now := Time.get_ticks_msec() / 1000.0
	var can_coyote_jump := now - last_grounded_time <= COYOTE_TIME
	if Input.is_action_just_pressed("Up") and can_coyote_jump:
		velocity.y = JUMP_VELOCITY
		last_grounded_time = -INF
		_play_animation("jump")

	move_and_slide()


func _play_animation(animation_name: StringName) -> void:
	if animated_sprite.animation != animation_name:
		animated_sprite.play(animation_name)
