extends Node

# Reference to the character the AI controls
@export var character_path: NodePath
@onready var character : Character = get_node(character_path) as Character

# Reference to the combat module
@onready var combat_module : Node = character.combat_module

# Main variables for AI decision making
var target_character: Character = null

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
			#How to fight with player
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
	# Example AI logic
	if target_character:
		if target_character.current_stance != combat_module.current_attack_stance:
			# Perform attack or stance change
			combat_module.perform_attack("Top")
		else:
			# Block or change stance to counter
			combat_module.handle_stance_change()

