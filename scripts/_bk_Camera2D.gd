extends Camera2D


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
	#print("is_jumping:", is_jumping)


func _on_player_samurai_grounded_updated(is_jumping):
	drag_vertical_enabled = is_jumping
	print("is_jumping:", is_jumping)
	print("drag_vertical_enabled:", drag_vertical_enabled)

func print_debug(message: String):
	print(message)


func _on_character_grounded_updated(is_jumping):
	pass # Replace with function body.
