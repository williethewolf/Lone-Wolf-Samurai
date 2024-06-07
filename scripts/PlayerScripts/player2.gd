extends Node2D

@export var character_path: NodePath = NodePath("")
var character: Character

#Multiplayer coop control variables
@export var controls: Resource = null

#Jumping vars
@export var jump_height: float = 200.0  # Jump height in pixels
@export var min_jump_height: float = 20.0  # Minimum jump height in pixels
var jump_pressed_duration = 0.0  # Duration for which the jump button is pressed
var jump_duration: float = 0.05  # Duration to reach full jump height

func _ready():
	character = get_node(character_path) as Character
	if not character:
		print("Player 2 node not found!")
	else:
		set_process(true)
		character.player_name = "Player2"

func _process(_delta):
	if character:
		handle_input()

func handle_input():
	character.direction = Vector2.ZERO
	if Input.is_action_pressed(controls.move_left):
		character.direction += character.LEFT
	elif Input.is_action_pressed(controls.move_right):
		character.direction += character.RIGHT

	if Input.is_action_just_pressed(controls.move_left):
		if Time.get_ticks_msec() / 1000.0 - character.last_tap_time_left < character.double_tap_interval:
			character.facing = character.LEFT
			character.legs_sprite.flip_h = true
			character.torso_sprite.flip_h = true
		character.last_tap_time_left = Time.get_ticks_msec() / 1000.0

	if Input.is_action_just_pressed(controls.move_right):
		if Time.get_ticks_msec() / 1000.0 - character.last_tap_time_right < character.double_tap_interval:
			character.facing = character.RIGHT
			character.legs_sprite.flip_h = false
			character.torso_sprite.flip_h = false
		character.last_tap_time_right = Time.get_ticks_msec() / 1000.0

	if Input.is_action_just_pressed(controls.dash):
		character.dash()

	if Input.is_action_just_pressed(controls.jump) and character.is_on_floor():
		character.jump()
	elif Input.is_action_just_released("jump") and character.is_jumping:
		jump_pressed_duration = clamp(jump_pressed_duration, 0.0, jump_duration)
		var jump_ratio = jump_pressed_duration / jump_duration
		character.velocity.y = lerp(min_jump_height, jump_height, jump_ratio)
		character.is_jumping = false

	character.handle_stance_change()
	character.handle_attacks()
