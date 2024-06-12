extends Node2D

@onready var distance = 0
@onready var levelScene = get_tree().get_nodes_in_group("Level")[0]  # Get the first node in the "level" group
@onready var level = levelScene.get_node("Map/TileMap")
@onready var floorLine = levelScene.get_node("Map/Floorline")


var floorLineCoords := 0
var distanceToFloorline

signal distance_to_floor(distance_to_floorline)

@onready var players := {}



func _ready():
	floorLineCoords = floorLine.position.y
	# Gather players into a dictionary
	populate_players()

	# Set up remote transforms and signals
	for node in players.values():
		var remote_transform := RemoteTransform2D.new()
		remote_transform.remote_path = node["camera"].get_path()
		node["player"].get_node("character").add_child(remote_transform)
		if node["player"].get_node("character").has_signal("grounded_updated"):
			node["player"].get_node("character").connect("grounded_updated", Callable(node["camera"], "_on_grounded_updated"))

	# Sync viewports
	if players.has(2):
		players[2]["viewport"].world_2d = players[1]["viewport"].world_2d

func populate_players():
	# Gather players into a dictionary
	for player in get_tree().get_nodes_in_group("players"):
		var player_number = player.get("player_number")
		print("Found player with number: " + str(player_number))

		# Construct the correct path for the SubViewportContainer and SubViewport nodes
		var sub_viewport_container_path = "HBoxContainer/SubViewportContainer" + str(player_number)
		var sub_viewport_container = get_node(sub_viewport_container_path)
		
		if sub_viewport_container:
			var viewport = sub_viewport_container.get_node("SubViewport")
			var camera = viewport.get_node("Player" + str(player_number) + "Camera")
			
			# Add the player information to the dictionary
			players[player_number] = {
				"viewport": viewport,
				"camera": camera,
				"player": player
			}
		else:
			print("SubViewportContainer not found for player " + str(player_number))
		
func _physics_process(_delta):
	if players.has(2) and players.has(1):
		distance = players[1]["player"].position.distance_to(players[2]["player"].position)
		if distance <= 700:
			print("They are close")
		else:
			print("They are NOT close")
			for node in players.values():
				var player_pos = node["player"].position
				distanceToFloorline = abs(player_pos.y - floorLineCoords)
				node["camera"]._update_camera_offset(distanceToFloorline)
		
