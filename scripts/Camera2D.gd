extends Camera2D

@export var player_path: NodePath
@onready var player = get_node(player_path) as Node2D

# This function is called when the node enters the scene tree for the first time.
func _ready():
	# Assuming the parent node is the player character.
	if get_parent().has_method("connect"):
		var character = get_parent()
		if character and not character.is_connected("grounded_updated", Callable(self, "_on_grounded_updated")):
			character.connect("grounded_updated", Callable(self, "_on_grounded_updated"))
	if player:
		if not player.is_connected("grounded_updated", Callable(self, "_on_grounded_updated")):
			player.connect("grounded_updated",Callable(self, "_on_grounded_updated"))

# This function is called when the grounded_updated signal is emitted.
func _on_grounded_updated(is_jumping):
	drag_vertical_enabled = is_jumping
	print("is_jumping:", is_jumping)
	print("drag_vertical_enabled:", drag_vertical_enabled)

# For debugging
func print_debug(message: String):
	print(message)
