extends Node

# Reference to the character the AI controls
@export var character_path: NodePath
@onready var character : Character = get_node(character_path) as Character

# Reference to the combat module
@onready var combat_module : Node = character.combat_module

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
	Difficulty.EASY: Vector2(0.3, 0.5),
	Difficulty.MEDIUM: Vector2(0.3, 0.4),
	Difficulty.HARD: Vector2(0.25, 0.35),
	Difficulty.EXTREME: Vector2(0.2, 0.25)
}

# AI states
enum AIState {
	IDLE,
	ATTACK,
	BLOCK
}

var state: AIState = AIState.IDLE

func _ready() -> void:
	print("AIComponent _ready called")
	if not character or not character.is_ai_controlled:
		print("Character not found or not AI controlled")
		set_physics_process(false)
		return
	
	print("Character found and AI controlled")
	initialize_ai()
	
# Initialize AI behavior
func initialize_ai() -> void:
	# Connect signals
	if combat_module:
		combat_module.connect("stance_changed", Callable(self, "_on_stance_changed"))
		combat_module.connect("attack_stance_changed", Callable(self, "_on_attack_stance_changed"))
	else:
		print("Combat module not found")


func _physics_process(delta: float) -> void:
	if character and is_instance_valid(character):
		# Check for nearby enemies
		if character.front_ray.is_colliding() and character.front_ray.get_collider() is Character:
			target_character = character.front_ray.get_collider()
		elif character.back_ray.is_colliding() and character.back_ray.get_collider() is Character:
			target_character = character.back_ray.get_collider()
		else:
			target_character = null
		
		# Add AI movement or other logic here
		if target_character:
			#How to fight with player in range
			execute_ai_combat_logic()
		else:
			#how to act when not in range
			ai_behavior()
	else:
		print("Character is not valid in _physics_process")

# Handle stance change signal
func _on_stance_changed(new_stance: String) -> void:
	# Add AI logic for stance change here
	print("Stance changed to ", new_stance)

# Handle attack stance change signal
func _on_attack_stance_changed(new_attack_stance: String) -> void:
	# Add AI logic for attack stance change here
	print("Attack stance changed to ", new_attack_stance)

func ai_behavior() -> void:
	# Example AI behavior loop
	pass

func execute_ai_combat_logic() -> void:
	match state:
		AIState.IDLE:
			# Determine action
			if target_character.current_stance != combat_module.current_attack_stance and not combat_module.is_attacking:
				state = AIState.ATTACK
				execute_attack()
			else:
				state = AIState.BLOCK
				execute_block()

		AIState.ATTACK, AIState.BLOCK:
			# Wait for the current action to finish
			if not combat_module.is_attacking:
				state = AIState.IDLE

func execute_attack() -> void:
	if state == AIState.ATTACK:
		await get_tree().create_timer(AI_reaction_delay()).timeout
		combat_module.perform_attack("Top")
		state = AIState.IDLE

func execute_block() -> void:
	if state == AIState.BLOCK:
		await get_tree().create_timer(AI_reaction_delay()).timeout
		combat_module.handle_stance_change()
		state = AIState.IDLE
		

# Simulate AI reaction delay based on difficulty level
func AI_reaction_delay() -> float:
	var reaction_range: Vector2 = reaction_times[difficulty_level]
	return randf_range(reaction_range.x, reaction_range.y)
