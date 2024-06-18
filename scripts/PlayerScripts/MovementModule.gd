extends Node

# Constants for movement and controls
const LEFT = Vector2(-1, 0)
const RIGHT = Vector2(1, 0)

# Jump properties
@export var jump_height: float = 200.0  # Jump height in pixels
@export var min_jump_height: float = 50.0  # Minimum jump height in pixels
@export var gravity: float = 5500.0  # Increased gravity strength
@export var jump_speed: float = -1500.0  # Increased initial jump speed (more negative to move up faster)
@export var jump_duration: float = 0.3  # Duration to reach full jump height
var floor_y_position: float = 10

# Movement variables
var direction = Vector2.ZERO
var facing = RIGHT

# Dash variables
var is_dashing = false
@export var dash_speed: float = 1200.0  # Adjusted dash speed
var dash_duration = 0.2
var dash_timer = 0

# Jump variables
var is_jumping = false
var is_falling = false

# Signal for camera help
signal grounded_updated(is_jumping)

func apply_gravity(delta):
	if not get_parent().is_on_floor():
		get_parent().velocity.y += gravity * delta

func jump():
	is_jumping = true
	get_parent().velocity.y = jump_speed  # Set the initial jump speed
	get_parent().animPlayer_legs.play("jump_up")  # Play the first half of the jump animation
	emit_signal("grounded_updated", is_jumping)

func is_close_to_floor() -> bool:
	return get_parent().position.y + 75 >= floor_y_position  # Adjust this threshold as needed

func handle_jump(_delta):
	if get_parent().is_on_floor():
		is_jumping = false
		emit_signal("grounded_updated", is_jumping)
	else:
		is_jumping = true

func move_and_slide():
	get_parent().velocity.x = direction.x * get_parent().speed
	get_parent().move_and_slide()
