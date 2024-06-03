extends Node2D

@export var character_path: NodePath = NodePath("")
var character: Character

@onready var camera = $Camera2D

func _ready():
	character = get_node(character_path) as Character
	if not character:
		print("Character node not found!")
	else:
		set_process(true)
		character.player_name = "Player1"
		# Connect the grounded_updated signal to the camera
		if camera and not character.is_connected("grounded_updated", Callable(camera, "_on_grounded_updated")):
			character.connect("grounded_updated", Callable(camera, "_on_grounded_updated"))

func _process(delta):
	if character:
		handle_input()
		print("coordenates", transform)

func handle_input():
	character.direction = Vector2.ZERO
	if Input.is_action_pressed("move_left"):
		character.direction += character.LEFT
	elif Input.is_action_pressed("move_right"):
		character.direction += character.RIGHT

	if Input.is_action_just_pressed("move_left"):
		if Time.get_ticks_msec() / 1000.0 - character.last_tap_time_left < character.double_tap_interval:
			character.facing = character.LEFT
			character.legs_sprite.flip_h = true
			character.torso_sprite.flip_h = true
		character.last_tap_time_left = Time.get_ticks_msec() / 1000.0

	if Input.is_action_just_pressed("move_right"):
		if Time.get_ticks_msec() / 1000.0 - character.last_tap_time_right < character.double_tap_interval:
			character.facing = character.RIGHT
			character.legs_sprite.flip_h = false
			character.torso_sprite.flip_h = false
		character.last_tap_time_right = Time.get_ticks_msec() / 1000.0

	if Input.is_action_just_pressed("dash"):
		character.dash()

	if Input.is_action_just_pressed("jump") and character.is_on_floor():
		character.jump()

	character.handle_stance_change()
	character.handle_attacks()
	
func print_debug(message: String):
	print(message)
