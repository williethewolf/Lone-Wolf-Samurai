extends Node

# Reference to the character the AI controls
@export var character_path: NodePath
@onready var character : Character = get_node_or_null("../character") as Character

# Reference to the combat module
@onready var combat_module: Node = character.combat_module
@onready var movement_module: Node = character.movement_module

# Main variables for AI decision making
var target_character: Character = null

# Difficulty level of the AI
enum Difficulty {
	EASY,
	MEDIUM,
	HARD,
	EXTREME
}
@export var difficulty_level: Difficulty = Difficulty.MEDIUM

# Reaction time ranges for different difficulty levels (in milliseconds)
var reaction_times: Dictionary = {
	Difficulty.EASY: Vector2(0.2, 0.35),
	Difficulty.MEDIUM: Vector2(0.2, 0.3),
	Difficulty.HARD: Vector2(0.2, 0.25),
	Difficulty.EXTREME: Vector2(0.15, 0.2)
}

# AI SENSORS
@onready var near_view_cone: Area2D = $AISensors/DetectionConeArea2D
@onready var far_view_cone: Area2D = $AISensors/LongDetectionConeArea2D
@onready var alert_radius: Area2D = $AISensors/AlertRadiusArea2D

@onready var attack_range_area: Area2D = character.get_node("AnimatedSprite2DTorso/AttackRange")

# Alert state and timer
signal alerted
var is_alerted: bool = false
var detection_timer: float = 0.0
@onready var exclamation_mark: Sprite2D = $AISensors/ExclamationMark

# This var sets how likely the AI is to act on a condition
var confidence: float = 0.0

# AI states
enum AIState {
	IDLE,
	MOVING,
	CHASING,
	FOOTWORK,
	ATTACKING,
	BLOCKING,
	ALERTED,
	ENGAGED,
	FLEEING,
}
#for debugging
var AIstates_strings: Dictionary = {
	AIState.IDLE : "IDLE",
	AIState.MOVING : "MOVING",
	AIState.CHASING : "CHASING",
	AIState.ATTACKING : "ATTACKING",
	AIState.BLOCKING : "BLOCKING",
	AIState.ALERTED : "ALERTED",
	AIState.ENGAGED : "ENGAGED",
	AIState.FLEEING : "FLEEING"
}

var in_attacking_range : bool = false

# Enums for stances
const Stance = preload("res://scripts/stanceEnum.gd").Stance
var stance_strings: Dictionary = {
	Stance.NONE: "none",
	Stance.TOP: "Top",
	Stance.MID: "Mid",
	Stance.LOW: "Low"
}

var state: AIState = AIState.IDLE

func _ready() -> void:
	print("AIComponent _ready called")
	if not character:
		print("Character not found")
		set_physics_process(false)
		return
	if not character.is_ai_controlled:
		print("Player Control AI Module Disabled")
		set_physics_process(false)
		return
	print("Character found and AI controlled")
	initialize_ai()
	exclamation_mark.visible = false  # Initially hide the exclamation mark

	# Connect detection signals
	near_view_cone.connect("body_entered", Callable(self, "_on_near_view_cone_entered"))
	near_view_cone.connect("body_exited", Callable(self, "_on_near_view_cone_exited"))
	far_view_cone.connect("body_entered", Callable(self, "_on_far_view_cone_entered"))
	far_view_cone.connect("body_exited", Callable(self, "_on_far_view_cone_exited"))
	alert_radius.connect("body_entered", Callable(self, "_on_alert_radius_entered"))
	alert_radius.connect("body_exited", Callable(self, "_on_alert_radius_exited"))
	attack_range_area.connect("body_entered", Callable(self, "_on_attack_range_entered"))
	attack_range_area.connect("body_exited", Callable(self, "_on_attack_range_exited"))

# Initialize AI behavior
func initialize_ai() -> void:
	# Connect signals
	if combat_module:
		combat_module.connect("stance_changed", Callable(self, "_on_stance_changed"))
		combat_module.connect("attack_stance_changed", Callable(self, "_on_attack_stance_changed"))
	else:
		print("Combat module not found")
	# Connect alerted signal
	connect("alerted", Callable(self, "_on_alerted"))

func _physics_process(delta: float) -> void:
	if character and is_instance_valid(character):
		# Handle enemy detection
		handle_detection(delta)
		
		# Add AI movement or other logic here
		if target_character:
			if in_attacking_range:
				# How to fight with player in range
				movement_module.direction = Vector2.ZERO
				execute_ai_combat_logic()
			else:
				# How to act when not in range
				if state == AIState.CHASING or AIState.IDLE:
					move_towards_target(delta)
				#else:
				#	movement_module.direction = Vector2.ZERO  
		else:
			# Default behavior when no target is set
			ai_behavior()
	else:
		print("Character is not valid in _physics_process")
	print(AIstates_strings[state])

func handle_detection(delta: float) -> void:
	# Check for nearby enemies
	if near_view_cone.get_overlapping_bodies().size() > 0:
		if not is_alerted:
			become_alerted()
	elif far_view_cone.get_overlapping_bodies().size() > 0:
		detection_timer += delta
		if detection_timer >= 3.0:
			if not is_alerted:
				become_alerted()
	else:
		detection_timer = 0.0  # Reset timer if player leaves the cone

func become_alerted() -> void:
	is_alerted = true
	detection_timer = 0.0
	exclamation_mark.visible = true  # Show exclamation mark
	emit_signal("alerted")
	await get_tree().create_timer(1.0).timeout  # Show exclamation mark for 1 second
	exclamation_mark.visible = false  # Hide exclamation mark
	alert_nearby_enemies()

func alert_nearby_enemies() -> void:
	for enemy in get_tree().get_nodes_in_group("Enemies"):
		#if enemy.global_position.distance_to(character.global_position) <= alert_radius.shape.radius:
			#enemy.get_node("AIController").become_alerted()  # Alert other enemies
			pass

# AREA DETECTION SIGNALS AND MANAGEMENT
# VISUAL CONE DETECTIONS
func _on_near_view_cone_entered(body: Node) -> void:
	if body.get_parent().is_in_group("Players") and body.name == "HurtboxArea" and not is_alerted:
		print("Player seen!")
		target_character = body  # Set the player as the target character
		become_alerted()

func _on_near_view_cone_exited(body: Node) -> void:
	# Optional: Handle logic for when the player exits the near view cone
	pass

func _on_far_view_cone_entered(body: Node) -> void:
	if body.get_parent().is_in_group("Players") and body.name == "HurtboxArea" and not is_alerted:
		target_character = body  # Set the player as the target character
		print("Player Will be detected in 3 seconds!!")
		start_detection_timer(0.0)

func _on_far_view_cone_exited(body: Node) -> void:
	if body.get_parent().is_in_group("Players") and body.name == "HurtboxArea":
		detection_timer = 0.0  # Reset timer if player leaves the cone

#Close combat detection
func _on_attack_range_entered(body: Node) -> void:
	body = body.get_parent()
	if body.is_in_group("Players") and body.get_node("character") == target_character:
		in_attacking_range = true
		state = AIState.IDLE
		character.velocity = Vector2.ZERO
		print("In attack range of player, stopping")
		
func _on_attack_range_exited(body: Node) -> void:
	body = body.get_parent()
	if body.is_in_group("Players") and body.get_node("character") == target_character:
		in_attacking_range = false
		state = AIState.CHASING
		print("Player exited attack range, resuming chase")
		emit_signal("attack_range_exited", body)
		
#Alert RADIUS
func _on_alert_radius_entered(body: Node) -> void:
	#if body.get_parent().is_in_group("Players"):
	#	alert_nearby_enemies()
	pass

func _on_alert_radius_exited(body: Node) -> void:
	# Optional: Handle logic for when the player exits the alert radius
	pass
#Timer for detection
func start_detection_timer(delta: float) -> void:
	# Start or continue the detection timer
	detection_timer += delta
	if detection_timer >= 3.0:
		if not is_alerted:
			become_alerted()
	else:
		detection_timer = 0.0  # Reset timer if player leaves the cone

# Handle alerted signal
func _on_alerted() -> void:
	print("AI is alerted!")
	target_character = find_closest_player()
	state = AIState.CHASING  # Set state to CHASING to start approaching the player
	print("Chasing player!")
	# Add additional alert behavior if needed

# Handle stance change signal
func _on_stance_changed(new_stance: Stance) -> void:
	# Add AI logic for stance change here
	print("Stance changed to ", stance_strings[new_stance])

# Handle attack stance change signal
func _on_attack_stance_changed(new_attack_stance: Stance) -> void:
	# Add AI logic for attack stance change here
	print("Attack stance changed to ", stance_strings[new_attack_stance])

func ai_behavior() -> void:
	# Example AI behavior loop
	pass
	
func find_closest_player() -> Character:
	var closest_player: Character = null
	var shortest_distance: float = INF
	for player in get_tree().get_nodes_in_group("Players"):
		var player_character : Node = player.get_node("character")
		var distance: float = character.global_position.distance_to(player_character.global_position)
		if distance < shortest_distance:
			shortest_distance = distance
			closest_player = player_character
			print("Closest Player is ", closest_player)
	return closest_player

func move_towards_target(delta: float) -> void:
	if target_character:
		print("Chasing player!")

		# Calculate horizontal direction only
		var direction: Vector2 = character.global_position.direction_to(target_character.global_position)
		direction.y = 0  # Ignore vertical distance for horizontal movement

		# Normalize direction to ensure constant speed
		direction = direction.normalized()

		# Calculate horizontal distance to the target
		var horizontal_distance: float = abs(character.global_position.x - target_character.global_position.x)

		# Stop moving if the enemy is close enough to the player horizontally
		if horizontal_distance < 85.0:
			movement_module.direction = Vector2.ZERO
			state = AIState.IDLE
		else:
			# Update the movement module direction for horizontal movement
			if direction.x > 0:
				movement_module.direction = movement_module.RIGHT
			else:
				movement_module.direction = movement_module.LEFT

		state = AIState.CHASING
	
func execute_ai_combat_logic() -> void:
	match state:
		AIState.IDLE:
			# Determine action
			if target_character.current_stance != combat_module.current_attack_stance and not combat_module.is_attacking:
				state = AIState.ATTACKING
				execute_attack()
			else:
				state = AIState.BLOCKING
				execute_block(target_character.current_stance)

		AIState.ATTACKING, AIState.BLOCKING:
			# Wait for the current action to finish
			if not combat_module.is_attacking:
				state = AIState.IDLE

func execute_attack() -> void:
	if state == AIState.ATTACKING:
		await get_tree().create_timer(AI_reaction_delay()).timeout
		combat_module.perform_attack(Stance.TOP)
		state = AIState.IDLE

func execute_block(target_stance: Stance) -> void:
	if state == AIState.BLOCKING:
		await get_tree().create_timer(AI_reaction_delay()).timeout
		combat_module.set_stance(target_stance)
		state = AIState.IDLE

# Simulate AI reaction delay based on difficulty level
func AI_reaction_delay() -> float:
	var reaction_range: Vector2 = reaction_times[difficulty_level]
	var weight: float = randf()
	var skewed_weight: float = weight * weight
	return reaction_range.x + skewed_weight * (reaction_range.y - reaction_range.x)
