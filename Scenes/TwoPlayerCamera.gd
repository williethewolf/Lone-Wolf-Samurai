extends Camera2D

###THIS IS A NOTE FOR FUTURE YOU. THERE'S A CHANCE THAT
###THE BETTER APPROACH TO THIS IS TO NOT ADD A 3rd VIEWPORT AND CAMERA 
###BUT TO ADJUST CAMERA 1 and CHANGE THE VIEWPORT AND CAMERA BEHAVIOUR
###TO ACCOMODATE TO BOTH PLAYERS WHILE HIDING THE PLAYER 2 VIEWPORT.

###JUST KEEP IT IN MIND FOR LATER. OR NOT. I'LL REMIND YOU. THAT'S WHY I AM HERE

@export var move_speed = 15
@export var zoom_speed = 2.0
@export var min_zoom = 0.4
@export var max_zoom = 1.0
@export var single_player_zoom = 1  # Adjust this value to set the zoom level for single player
@export var multi_player_zoom = 1.0  # Adjust this value to set the zoom level for multiple players
@export var margin = Vector2(400, 200)

@export var vertical_offset = 75  # Adjust this value based on the character height

@onready var targets = get_tree().get_nodes_in_group("Players")

@onready var screen_size = get_viewport_rect().size

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if targets.size() == 0:
		print("No targets for the multiplayer camera, mang!")
		return
	
	# Center camera between targets
	var p = Vector2.ZERO
	var valid_targets = 0
	for target in targets:
		if target.has_node("character") and is_instance_valid(target.get_node("character")):
			p += target.get_node("character").global_position
			valid_targets += 1

	if valid_targets > 0:
		p /= valid_targets
		p.y += vertical_offset  # Apply vertical offset
		position = lerp(position, p, move_speed * delta)
	
		# Adjust zoom level based on the number of players
		if valid_targets == 1:
			zoom = lerp(zoom, Vector2.ONE * single_player_zoom, zoom_speed * delta)
		else:
			# Find the zoom level fitting all target/players
			var r = Rect2(position, Vector2.ONE)
			for target in targets:
				if target.has_node("character") and is_instance_valid(target.get_node("character")):
					r = r.expand(target.get_node("character").global_position)
			r = r.grow_individual(margin.x, margin.y, margin.x, margin.y)
			var z
			if r.size.x > r.size.y * screen_size.aspect():
				z = 1 / clamp(r.size.x / screen_size.x, min_zoom, max_zoom)
			else:
				z = 1 / clamp(r.size.y / screen_size.y, min_zoom, max_zoom)
			zoom = lerp(zoom, Vector2.ONE * z, zoom_speed * delta)
