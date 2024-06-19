extends Node2D

@export var character_path: NodePath = NodePath("")
var character: Character
var movement_module: Node
var combat_module: Node

#Multiplayer coop control variables
@export var controls: Resource = null
@export var player_number: int = 1

#Jumping vars
@export var jump_height: float = 200.0  # Jump height in pixels
@export var min_jump_height: float = 20.0  # Minimum jump height in pixels
var jump_pressed_duration = 0.0  # Duration for which the jump button is pressed
var jump_duration: float = 0.05  # Duration to reach full jump height

func _ready():
	character = get_node_or_null(character_path) as Character
	if not character:
		print("Player " + str(player_number) + " node not found!")
	else:
		movement_module = character.get_node_or_null("MovementModule")
		combat_module = character.get_node_or_null("CombatModule")
		set_process(true)
		character.player_name = "Player" + str(player_number)
	#makes sure it is part of the players group
	add_to_group("players")

func _process(_delta):
	if character and is_instance_valid(character):
		handle_input()

func handle_input():
	if character and is_instance_valid(character):
		movement_module.direction = Vector2.ZERO
		if Input.is_action_pressed(controls.move_left):
			movement_module.direction += movement_module.LEFT
		elif Input.is_action_pressed(controls.move_right):
			movement_module.direction += movement_module.RIGHT

		if Input.is_action_just_pressed(controls.move_left):
			if Time.get_ticks_msec() / 1000.0 - character.last_tap_time_left < character.double_tap_interval:
				movement_module.facing = movement_module.LEFT
				character.legs_sprite.scale.x = -1
				character.torso_sprite.scale.x = -1
			character.last_tap_time_left = Time.get_ticks_msec() / 1000.0

		if Input.is_action_just_pressed(controls.move_right):
			if Time.get_ticks_msec() / 1000.0 - character.last_tap_time_right < character.double_tap_interval:
				movement_module.facing = movement_module.RIGHT
				character.legs_sprite.scale.x = 1
				character.torso_sprite.scale.x = 1
			character.last_tap_time_right = Time.get_ticks_msec() / 1000.0

		if Input.is_action_just_pressed(controls.dash):
			movement_module.dash()

		if Input.is_action_just_pressed(controls.jump) and character.is_on_floor():
			movement_module.jump()
		elif Input.is_action_just_released("jump") and movement_module.is_jumping:
			jump_pressed_duration = clamp(jump_pressed_duration, 0.0, jump_duration)
			var jump_ratio = jump_pressed_duration / jump_duration
			character.velocity.y = lerp(min_jump_height, jump_height, jump_ratio)
			#movement_module.is_jumping = false
		character.handle_target_switch()
	if combat_module and is_instance_valid(combat_module):
		combat_module.handle_stance_change()
		combat_module.handle_attacks()
		
