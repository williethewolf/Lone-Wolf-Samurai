extends Node2D

@onready var distance = 0
@onready var twoPlayerCamera = get_node_or_null("HBoxContainer/SubViewportContainer3/SubViewport/Player2Camera")
@onready var level = $HBoxContainer/SubViewportContainer/SubViewport/Level/Map/TileMap
@onready var floorLine = $HBoxContainer/SubViewportContainer/SubViewport/Level/Map/Floorline

var floorLineCoords := 0
var distanceToFloorline

signal distance_to_floor(distance_to_floorline)



#I NEED TO UPDATE THIS USING GROUPS INSTEAD OF HARDCODED PATHS
@onready var players := {
	"1":{
		viewport = $HBoxContainer/SubViewportContainer/SubViewport,
		camera = $HBoxContainer/SubViewportContainer/SubViewport/Player1Camera,
		player = $HBoxContainer/SubViewportContainer/SubViewport/Level/Players/Player1,
		},
	"2":{
		viewport = $HBoxContainer/SubViewportContainer2/SubViewport,
		camera = $HBoxContainer/SubViewportContainer2/SubViewport/Player2Camera,
		player = get_node_or_null("HBoxContainer/SubViewportContainer/SubViewport/Level/Players/Player2"),
		},
}



func _ready():
	floorLineCoords = floorLine.position.y
	if players["2"].player:
		players["2"].viewport.world_2d = players["1"].viewport.world_2d
		for node in players.values():
			var remote_transform := RemoteTransform2D.new()
			remote_transform.remote_path = node.camera.get_path()
			node.player.get_node("character").add_child(remote_transform)
			if node.player.get_node("character").has_signal("grounded_updated"):
				node.player.get_node("character").connect("grounded_updated", Callable(node.camera, "_on_grounded_updated"))
			#add players to the twoplayerCamera - POSSIBLY OBSOLETE AFTER USING GROUPS TO ITERATE
			#$HBoxContainer/SubViewportContainer2/SubViewport/TwoPlayerCamera.add_target($HBoxContainer/SubViewportContainer/SubViewport/TestMap/Player1)
			#$HBoxContainer/SubViewportContainer2/SubViewport/TwoPlayerCamera.add_target($HBoxContainer/SubViewportContainer/SubViewport/TestMap/Player2)
			var tilemapBoundries = level.get_used_rect()
			#$SubViewportContainer3/SubViewport/MultiplayerCamera.limit_left = tilemapBoundries.tile_set.tile_size.x
			#$SubViewportContainer3/SubViewport/MultiplayerCamera.limit_right = tilemapBoundries.tile_set.tile_size.x
			#$SubViewportContainer3/SubViewport/MultiplayerCamera.limit_bottom = tilemapBoundries.endtile_set.tile_size.y
func _physics_process(_delta):
	if players["2"].player:
		distance = players["1"].player.get_node("character").position.distance_to(players["2"].player.get_node("character").position)
		if distance <= 700:
			# Switch to the combined camera
			print("They are close")
			#$SubViewportContainer3/SubViewport/MultiplayerCamera.make_current()
		else:
			print("They are NOT close")
			# Calculate distance to adjsut camera offset
	for node in players.values():
		distanceToFloorline = abs(node.player.get_node("character").position.y - floorLineCoords)
		node.camera._update_camera_offset(distanceToFloorline)
		
