extends Node2D

@export var character_path: NodePath
var character: Character

func _ready():
	character = get_node(character_path) as Character
	set_process(true)

func _process(delta):
	handle_ai_logic()

func handle_ai_logic():
	# Placeholder for AI logic
	pass
