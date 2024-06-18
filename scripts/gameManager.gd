extends Node2D

@onready var distance = 0
@onready var levelScene = get_tree().get_nodes_in_group("Level")[0]  # Get the first node in the "level" group
@onready var level = levelScene.get_node("Map/TileMap")
@onready var floorLine = levelScene.get_node("Map/Floorline")

@onready var line := get_node("ColorRect")

var floorLineCoords := Vector2.ZERO
var distanceToFloorline
var tween
var is_multiplayer_camera_active = false

signal distance_to_floor(distance_to_floorline)

@onready var players := {}

@onready var multiplayer_camera := get_node("SubViewportContainer3/SubViewport/MultiplayerCamera")
@onready var multiplayer_viewport_container := get_node("SubViewportContainer3")

func _ready():
	floorLineCoords = floorLine.global_position
	print("Floorline global position:", floorLineCoords)
	# Gather players into a dictionary
	populate_players()

	# Set up remote transforms and signals
	for node in players.values():
		var remote_transform := RemoteTransform2D.new()
		remote_transform.remote_path = node["camera"].get_path()
		node["player"].get_node("character").add_child(remote_transform)
		if node["player"].get_node("character").has_signal("grounded_updated"):
			node["player"].get_node("character").connect("grounded_updated", Callable(node["camera"], "_on_grounded_updated"))
		print("Connected grounded_updated signal for player", node["player"].get("player_number"))

	# Sync viewports
	if players.has(2):
		players[2]["viewport"].world_2d = players[1]["viewport"].world_2d
		print("Synchronized viewports for Player 2")

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
				"sub_viewport_container": sub_viewport_container,
				"camera": camera,
				"player": player
			}
			print("Initialized player", player_number, "with camera", camera.name)
		else:
			print("SubViewportContainer not found for player " + str(player_number))

func _physics_process(_delta):
	if players.has(1) and players.has(2):
		var player1_pos
		var player2_pos
		
		if players[1] and players[1]["player"] and is_instance_valid(players[1]["player"].get_node_or_null("character")):
			player1_pos = players[1]["player"].get_node("character").global_position
		else:
			player1_pos = null
		
		if players[2] and players[2]["player"] and is_instance_valid(players[2]["player"].get_node_or_null("character")):
			player2_pos = players[2]["player"].get_node("character").global_position
		else:
			player2_pos = null
		
		if player1_pos and player2_pos:
			distance = player1_pos.distance_to(player2_pos)
			#print("Distance between players:", distance)
			if distance <= 650:
				#print("They are close")
				switch_to_multiplayer_camera()
			else:
				#print("They are NOT close")
				switch_to_individual_cameras()

		for player_number in players.keys():
			var node = players[player_number]
			var player_pos
			if node and node["player"] and is_instance_valid(node["player"].get_node_or_null("character")):
				player_pos = node["player"].get_node("character").global_position
				distanceToFloorline = round(abs(player_pos.y - floorLineCoords.y + 88))  # Add offset to normalize
				#print("Player", player_number, "global_position:", player_pos, "distanceToFloorline:", distanceToFloorline)  # Debug: Check distance to floorline
				node["camera"]._update_camera_offset(distanceToFloorline)
				#print("Camera", node["camera"].name, "target_offset_y:", node["camera"].target_offset_y, "current_offset.y:", node["camera"].offset.y)
				update_line_thickness(distance)

			# Update the line thickness even if there's only one player left
			update_line_thickness(distance)

func switch_to_multiplayer_camera():
	# Set both players to use the same world
	if players.has(1):
		players[1]["viewport"].world_2d = multiplayer_camera.get_viewport().world_2d
	if players.has(2):
		players[2]["viewport"].world_2d = multiplayer_camera.get_viewport().world_2d
	
	# Tween out individual viewport containers
	if tween:
		tween.kill()
	tween = create_tween()
	
	# Enable multiplayer viewport container
	tween.tween_callback(multiplayerViewportEnabler.bind(true))
	if players.has(1):
		tween.parallel().tween_property(players[1]["sub_viewport_container"], "modulate:a", 0.0, 0.3)
	if players.has(2):
		tween.parallel().tween_property(players[2]["sub_viewport_container"], "modulate:a", 0.0, 0.3)

	# Disable individual viewport containers
	tween.tween_callback(individualViewportEnabler.bind(false))

func switch_to_individual_cameras():
	# Revert viewports to their original world
	if players.has(1):
		players[1]["viewport"].world_2d = players[1]["camera"].get_viewport().world_2d
	if players.has(2):
		players[2]["viewport"].world_2d = players[2]["camera"].get_viewport().world_2d
	
	# Tween out multiplayer viewport container
	if tween:
		tween.kill()
	tween = create_tween()
	tween.tween_callback(individualViewportEnabler.bind(true))
	if players.has(1):
		tween.parallel().tween_property(players[1]["sub_viewport_container"], "modulate:a", 1.0, 0.3)
	if players.has(2):
		tween.parallel().tween_property(players[2]["sub_viewport_container"], "modulate:a", 1.0, 0.3)
	tween.tween_callback(multiplayerViewportEnabler.bind(false))

func multiplayerViewportEnabler(state):
	multiplayer_viewport_container.visible = state
	if state == true:
		multiplayer_viewport_container.modulate.a = 1

func individualViewportEnabler(state):
	if players.has(1):
		players[1]["sub_viewport_container"].visible = state
	if players.has(2):
		players[2]["sub_viewport_container"].visible = state
	if state == true:
		if players.has(1):
			players[1]["sub_viewport_container"].modulate.a = 0
		if players.has(2):
			players[2]["sub_viewport_container"].modulate.a = 0

func update_line_thickness(distanceBetweenPlayers):
	var target_thickness = lerp(4, 0, clamp((700 - distanceBetweenPlayers) / 50, 0, 1))  # Adjust these values for thickness range
	line.size.x = target_thickness
